begin;

select plan(40);

insert into auth.users (id, email)
values
  ('81000000-0000-4000-8000-000000000001', 'profile-access-a@planets.invalid'),
  ('82000000-0000-4000-8000-000000000002', 'profile-access-b@planets.invalid');

set local role anon;

select throws_ok(
  'select id from public.profiles',
  '42501',
  'permission denied for table profiles',
  'anonymous users cannot read profiles directly'
);
select is(
  (select count(*) from public.skill_categories),
  7::bigint,
  'anonymous users can read the controlled category catalog'
);
select is(
  (select count(*) from public.skills),
  24::bigint,
  'anonymous users can read the controlled skill catalog'
);
select throws_ok(
  $$
    insert into public.skill_categories (id, slug, label, sort_order)
    values ('ffffffff-ffff-4fff-8fff-ffffffffffff', 'invented', 'Invented', 99)
  $$,
  '42501',
  'permission denied for table skill_categories',
  'anonymous users cannot mutate the catalog'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '81000000-0000-4000-8000-000000000001',
  true
);

select lives_ok(
  $$insert into public.profiles (id) values ('81000000-0000-4000-8000-000000000001')$$,
  'user A can create an own skeletal profile anchor'
);
select is(
  (
    select display_name
    from public.profiles
    where id = '81000000-0000-4000-8000-000000000001'
  ),
  null::text,
  'a skeletal anchor is incomplete because display name is null'
);
select is(
  (
    select exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'profiles'
        and column_name = 'is_complete'
    )
  ),
  false,
  'profile completion is derived rather than stored in a writable flag'
);
select throws_ok(
  $$
    update public.profiles
    set display_name = ' A '
    where id = '81000000-0000-4000-8000-000000000001'
  $$,
  '23514',
  'new row for relation "profiles" violates check constraint "profiles_display_name_valid"',
  'direct writes cannot store an untrimmed display name'
);
select throws_ok(
  $$
    update public.profiles
    set bio = '   '
    where id = '81000000-0000-4000-8000-000000000001'
  $$,
  '23514',
  'new row for relation "profiles" violates check constraint "profiles_bio_valid"',
  'direct writes cannot store a whitespace-only bio'
);

select lives_ok(
  $$
    select public.update_own_profile(
      '  Casey Artist  ',
      '  Helps neighbors create public art.  ',
      array[
        'd0000000-0000-4000-8001-000000000001'::uuid,
        'd0000000-0000-4000-8002-000000000001'::uuid,
        'd0000000-0000-4000-8002-000000000001'::uuid
      ],
      'private',
      'public',
      'private'
    )
  $$,
  'user A can atomically complete the own profile with mixed visibility'
);
select results_eq(
  $$
    select display_name, bio
    from public.profiles
    where id = '81000000-0000-4000-8000-000000000001'
  $$,
  $$values ('Casey Artist'::text, 'Helps neighbors create public art.'::text)$$,
  'the canonical update trims surrounding whitespace without changing content casing'
);
select is(
  (
    select count(*)
    from public.profile_skills
    where profile_id = '81000000-0000-4000-8000-000000000001'
  ),
  2::bigint,
  'duplicate input skill IDs canonicalize to unique profile skills'
);
select results_eq(
  $$
    select field_key, audience
    from public.profile_field_visibility
    where profile_id = '81000000-0000-4000-8000-000000000001'
    order by field_key
  $$,
  $$
    values
      ('bio'::text, 'public'::text),
      ('display_name'::text, 'private'::text),
      ('skills'::text, 'private'::text)
  $$,
  'the canonical update stores each visibility choice independently'
);
select col_not_null(
  'public',
  'profiles',
  'updated_at',
  'the completed profile retains a database-managed timestamp'
);

select throws_ok(
  $$
    select public.update_own_profile(
      'Changed Name',
      'Changed bio',
      array['ffffffff-ffff-4fff-8fff-ffffffffffff'::uuid],
      'public',
      'public',
      'public'
    )
  $$,
  '22023',
  'One or more skill identifiers are not in the catalog.',
  'the atomic operation rejects unknown skill IDs'
);
select is(
  (
    select display_name
    from public.profiles
    where id = '81000000-0000-4000-8000-000000000001'
  ),
  'Casey Artist',
  'a rejected update leaves the previous scalar profile intact'
);
select throws_ok(
  $$
    select public.update_own_profile(
      'Casey Artist',
      null,
      array[]::uuid[],
      'organizers',
      'public',
      'public'
    )
  $$,
  '22023',
  'Profile audiences must be public or private.',
  'the atomic operation rejects deferred audience values'
);
select throws_ok(
  $$
    select public.update_own_profile(
      'X',
      null,
      array[]::uuid[],
      'public',
      'public',
      'public'
    )
  $$,
  '22023',
  'Display name must contain between 2 and 60 characters.',
  'the atomic operation rejects an incomplete display name'
);
select throws_ok(
  $$
    select public.update_own_profile(
      'Casey Artist',
      repeat('b', 501),
      array[]::uuid[],
      'public',
      'public',
      'public'
    )
  $$,
  '22023',
  'Bio must contain at most 500 characters.',
  'the atomic operation rejects an oversized bio'
);

select lives_ok(
  $$
    insert into public.profile_skills (profile_id, skill_id)
    values (
      '81000000-0000-4000-8000-000000000001',
      'd0000000-0000-4000-8003-000000000003'
    )
  $$,
  'user A can add an own controlled skill directly'
);
select lives_ok(
  $$
    delete from public.profile_skills
    where profile_id = '81000000-0000-4000-8000-000000000001'
      and skill_id = 'd0000000-0000-4000-8003-000000000003'
  $$,
  'user A can remove an own controlled skill directly'
);
select lives_ok(
  $$
    update public.profile_field_visibility
    set audience = 'private'
    where profile_id = '81000000-0000-4000-8000-000000000001'
      and field_key = 'bio'
  $$,
  'user A can update an own visibility setting directly'
);

reset role;
set local role anon;

select is(
  (
    select count(*)
    from public.get_public_profile('81000000-0000-4000-8000-000000000001')
  ),
  1::bigint,
  'anonymous users can fetch one completed profile by exact ID'
);
select is(
  (
    select display_name
    from public.get_public_profile('81000000-0000-4000-8000-000000000001')
  ),
  null::text,
  'the sanitized read hides a private display name'
);
select is(
  (
    select bio
    from public.get_public_profile('81000000-0000-4000-8000-000000000001')
  ),
  null::text,
  'the sanitized read hides a private bio'
);
select is(
  (
    select skills
    from public.get_public_profile('81000000-0000-4000-8000-000000000001')
  ),
  '[]'::jsonb,
  'the sanitized read hides private skills'
);
reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '82000000-0000-4000-8000-000000000002',
  true
);

select lives_ok(
  $$insert into public.profiles (id) values ('82000000-0000-4000-8000-000000000002')$$,
  'user B can create the own profile anchor'
);
select results_eq(
  'select id from public.profiles order by id',
  $$values ('82000000-0000-4000-8000-000000000002'::uuid)$$,
  'user B cannot directly read user A profile data'
);
select throws_ok(
  $$
    insert into public.profile_skills (profile_id, skill_id)
    values (
      '81000000-0000-4000-8000-000000000001',
      'd0000000-0000-4000-8003-000000000003'
    )
  $$,
  '42501',
  'new row violates row-level security policy for table "profile_skills"',
  'user B cannot add skills to user A'
);
select lives_ok(
  $$
    update public.profile_field_visibility
    set audience = 'public'
    where profile_id = '81000000-0000-4000-8000-000000000001'
  $$,
  'a cross-user visibility update matches no RLS-visible rows'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '81000000-0000-4000-8000-000000000001',
  true
);

select is(
  (
    select count(*)
    from public.profile_field_visibility
    where profile_id = '81000000-0000-4000-8000-000000000001'
      and audience = 'public'
  ),
  0::bigint,
  'user B could not change user A visibility rows'
);
select lives_ok(
  $$
    select public.update_own_profile(
      'Casey Artist',
      'Private owner note',
      array[
        'd0000000-0000-4000-8001-000000000001'::uuid,
        'd0000000-0000-4000-8002-000000000001'::uuid
      ],
      'public',
      'private',
      'public'
    )
  $$,
  'user A can change the own mixed visibility atomically'
);
select is(
  (
    select bio
    from public.profiles
    where id = '81000000-0000-4000-8000-000000000001'
  ),
  'Private owner note',
  'the owner still reads the full private bio directly'
);
select is(
  (
    select count(*)
    from public.profile_skills
    where profile_id = '81000000-0000-4000-8000-000000000001'
  ),
  2::bigint,
  'the owner still reads all own selected skills directly'
);

reset role;
set local role anon;

select results_eq(
  $$
    select display_name, bio
    from public.get_public_profile('81000000-0000-4000-8000-000000000001')
  $$,
  $$values ('Casey Artist'::text, null::text)$$,
  'the public surface reveals only scalar fields currently marked public'
);
select is(
  (
    select jsonb_array_length(skills)
    from public.get_public_profile('81000000-0000-4000-8000-000000000001')
  ),
  2,
  'the public surface returns selected skills only when skills are public'
);
select ok(
  (
    select skills @> '[{"slug":"mural-painting"},{"slug":"musician"}]'::jsonb
    from public.get_public_profile('81000000-0000-4000-8000-000000000001')
  ),
  'the public skill payload contains the selected controlled skills'
);
select is(
  (
    select position('Private owner note' in row_to_json(public_profile)::text)
    from public.get_public_profile(
      '81000000-0000-4000-8000-000000000001'
    ) as public_profile
  ),
  0,
  'hidden scalar values do not appear anywhere in the sanitized payload'
);
select is(
  (
    select position('profile-access-a@planets.invalid' in row_to_json(public_profile)::text)
    from public.get_public_profile(
      '81000000-0000-4000-8000-000000000001'
    ) as public_profile
  ),
  0,
  'Auth email data never appears in the sanitized payload'
);
select is(
  (
    select count(*)
    from public.get_public_profile('82000000-0000-4000-8000-000000000002')
  ),
  0::bigint,
  'incomplete profiles are absent from the public surface'
);

select * from finish();

rollback;
