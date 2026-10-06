begin;

select plan(60);

select has_table('public', 'skill_categories', 'skill categories exist');
select has_table('public', 'skills', 'skills exist');
select has_table('public', 'profile_skills', 'profile skills exist');
select has_table(
  'public',
  'profile_field_visibility',
  'profile field visibility exists'
);

select columns_are(
  'public',
  'skill_categories',
  array['id', 'slug', 'label', 'sort_order'],
  'skill categories expose only stable catalog fields'
);
select columns_are(
  'public',
  'skills',
  array['id', 'category_id', 'slug', 'label', 'sort_order'],
  'skills expose only stable catalog fields'
);
select columns_are(
  'public',
  'profile_skills',
  array['profile_id', 'skill_id', 'created_at'],
  'profile skills are normalized relations'
);
select columns_are(
  'public',
  'profile_field_visibility',
  array['profile_id', 'field_key', 'audience'],
  'visibility is represented per profile field'
);

select col_is_pk('public', 'skill_categories', 'id', 'category IDs are primary keys');
select col_is_pk('public', 'skills', 'id', 'skill IDs are primary keys');
select has_pk('public', 'profile_skills', 'profile skills have a composite primary key');
select has_pk(
  'public',
  'profile_field_visibility',
  'profile visibility has a composite primary key'
);

select is(
  (select count(*) from public.skill_categories),
  7::bigint,
  'the starter catalog has seven broad categories'
);
select is(
  (select count(*) from public.skills),
  24::bigint,
  'the starter catalog remains deliberately small'
);
select ok(
  (
    select bool_and(found)
    from (
      values
        (exists (select 1 from public.skills where slug = 'musician')),
        (exists (select 1 from public.skills where slug = 'mural-painting')),
        (exists (select 1 from public.skills where slug = 'practical-making'))
    ) as examples(found)
  ),
  'the required musician, mural, and practical examples exist'
);
select is(
  (select count(distinct sort_order) from public.skill_categories),
  7::bigint,
  'category ordering is deterministic and unique'
);

select is(
  (select relrowsecurity from pg_class where oid = 'public.skill_categories'::regclass),
  true,
  'skill categories have RLS enabled'
);
select is(
  (select relrowsecurity from pg_class where oid = 'public.skills'::regclass),
  true,
  'skills have RLS enabled'
);
select is(
  (select relrowsecurity from pg_class where oid = 'public.profile_skills'::regclass),
  true,
  'profile skills have RLS enabled'
);
select is(
  (
    select relrowsecurity
    from pg_class
    where oid = 'public.profile_field_visibility'::regclass
  ),
  true,
  'profile visibility has RLS enabled'
);

select is(
  (select count(*) from pg_policies where schemaname = 'public' and tablename = 'skill_categories'),
  1::bigint,
  'skill categories have one read-only policy'
);
select is(
  (select count(*) from pg_policies where schemaname = 'public' and tablename = 'skills'),
  1::bigint,
  'skills have one read-only policy'
);
select is(
  -- Keep the operation-policy contract; 112 verifies the global account gate.
  (select count(*) from pg_policies where schemaname = 'public' and tablename = 'profile_skills' and policyname <> 'account_active_required'),
  3::bigint,
  'profile skills have explicit select, insert, and delete policies'
);
select is(
  (
    select count(*)
    from pg_policies
    where schemaname = 'public'
      and tablename = 'profile_field_visibility'
      and policyname <> 'account_active_required'
  ),
  3::bigint,
  'profile visibility has explicit select, insert, and update policies'
);
select ok(
  exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'profiles'
      and policyname = 'Authenticated users can update their own profile'
      and cmd = 'UPDATE'
      and roles = array['authenticated']::name[]
  ),
  'profiles have an explicit authenticated update-own policy'
);

select ok(
  exists (
    select 1 from pg_constraint
    where conrelid = 'public.profiles'::regclass
      and conname = 'profiles_display_name_valid'
      and contype = 'c'
  ),
  'display names have a database check constraint'
);
select ok(
  exists (
    select 1 from pg_constraint
    where conrelid = 'public.profiles'::regclass
      and conname = 'profiles_bio_valid'
      and contype = 'c'
  ),
  'bios have a database check constraint'
);
select col_type_is(
  'public',
  'profiles',
  'updated_at',
  'timestamp with time zone',
  'profile update time is timezone-aware'
);
select col_not_null(
  'public',
  'profiles',
  'updated_at',
  'profile update time is required'
);
select is(
  (
    select pg_get_expr(d.adbin, d.adrelid)
    from pg_attrdef as d
    join pg_attribute as a
      on a.attrelid = d.adrelid and a.attnum = d.adnum
    where d.adrelid = 'public.profiles'::regclass
      and a.attname = 'updated_at'
  ),
  'now()',
  'profile update time has a database default'
);
select ok(
  exists (
    select 1 from pg_trigger
    where tgrelid = 'public.profiles'::regclass
      and tgname = 'profiles_set_updated_at'
      and not tgisinternal
  ),
  'profile scalar updates maintain updated_at through a trigger'
);
select ok(
  exists (
    select 1 from pg_trigger
    where tgrelid = 'public.profiles'::regclass
      and tgname = 'profiles_initialize_visibility'
      and not tgisinternal
  ),
  'new profile anchors initialize visibility through a trigger'
);

insert into auth.users (id, email)
values ('70000000-0000-4000-8000-000000000007', 'profile-structure@planets.invalid');
insert into public.profiles (id)
values ('70000000-0000-4000-8000-000000000007');

select is(
  (
    select count(*)
    from public.profile_field_visibility
    where profile_id = '70000000-0000-4000-8000-000000000007'
  ),
  3::bigint,
  'every new profile gets exactly three visibility rows'
);
select is(
  (
    select count(*)
    from public.profile_field_visibility
    where profile_id = '70000000-0000-4000-8000-000000000007'
      and audience = 'public'
  ),
  3::bigint,
  'new profile visibility defaults to public'
);
select results_eq(
  $$
    select field_key
    from public.profile_field_visibility
    where profile_id = '70000000-0000-4000-8000-000000000007'
    order by field_key
  $$,
  $$values ('bio'::text), ('display_name'::text), ('skills'::text)$$,
  'new profiles receive every supported field key once'
);

select ok(
  to_regprocedure('public.update_own_profile(uuid,text,text,uuid[],text,text,text)') is not null,
  'the atomic owner update operation exists'
);
select ok(
  to_regprocedure('public.get_public_profile(uuid)') is not null,
  'the exact-ID sanitized public read operation exists'
);
select is(
  (
    select prosecdef
    from pg_proc
    where oid = 'public.update_own_profile(uuid,text,text,uuid[],text,text,text)'::regprocedure
  ),
  false,
  'the owner update operation remains security invoker'
);
select is(
  (
    select prosecdef
    from pg_proc
    where oid = 'public.get_public_profile(uuid)'::regprocedure
  ),
  true,
  'the sanitized public read deliberately uses security definer'
);
select is(
  (
    select array_to_string(proconfig, ',')
    from pg_proc
    where oid = 'public.update_own_profile(uuid,text,text,uuid[],text,text,text)'::regprocedure
  ),
  'search_path=""',
  'the update operation has an empty fixed search path'
);
select is(
  (
    select array_to_string(proconfig, ',')
    from pg_proc
    where oid = 'public.get_public_profile(uuid)'::regprocedure
  ),
  'search_path=""',
  'the public read has an empty fixed search path'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.update_own_profile(uuid,text,text,uuid[],text,text,text)',
    'EXECUTE'
  ),
  true,
  'authenticated users can execute the canonical owner update'
);
select is(
  has_function_privilege(
    'anon',
    'public.update_own_profile(uuid,text,text,uuid[],text,text,text)',
    'EXECUTE'
  ),
  false,
  'anonymous users cannot execute the owner update'
);
select is(
  has_function_privilege(
    'service_role',
    'public.update_own_profile(uuid,text,text,uuid[],text,text,text)',
    'EXECUTE'
  ),
  false,
  'service role receives no convenience owner-update grant'
);
select is(
  has_function_privilege('anon', 'public.get_public_profile(uuid)', 'EXECUTE'),
  true,
  'anonymous users can call the narrow public read'
);
select is(
  has_function_privilege(
    'authenticated',
    'public.get_public_profile(uuid)',
    'EXECUTE'
  ),
  true,
  'authenticated users can call the narrow public read'
);
select is(
  has_function_privilege('service_role', 'public.get_public_profile(uuid)', 'EXECUTE'),
  false,
  'service role receives no convenience public-read grant'
);
select is(
  (
    select exists (
      select 1
      from aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) as acl
      where acl.grantee = 0 and acl.privilege_type = 'EXECUTE'
    )
    from pg_proc as p
    where p.oid = 'public.update_own_profile(uuid,text,text,uuid[],text,text,text)'::regprocedure
  ),
  false,
  'PostgreSQL PUBLIC cannot execute the owner update'
);
select is(
  (
    select exists (
      select 1
      from aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) as acl
      where acl.grantee = 0 and acl.privilege_type = 'EXECUTE'
    )
    from pg_proc as p
    where p.oid = 'public.get_public_profile(uuid)'::regprocedure
  ),
  false,
  'PostgreSQL PUBLIC cannot execute the sanitized read'
);

select is(
  has_table_privilege('anon', 'public.skill_categories', 'INSERT'),
  false,
  'anonymous users cannot mutate skill categories'
);
select is(
  has_table_privilege('authenticated', 'public.skills', 'INSERT'),
  false,
  'authenticated users cannot mutate the skill catalog'
);
select is(
  has_table_privilege('authenticated', 'public.profile_skills', 'INSERT'),
  false,
  'profile skill insertion is not table-wide'
);
select is(
  has_column_privilege('authenticated', 'public.profile_skills', 'profile_id', 'INSERT'),
  true,
  'authenticated users may supply their own profile ID for a selected skill'
);
select is(
  has_column_privilege('authenticated', 'public.profile_skills', 'created_at', 'INSERT'),
  false,
  'authenticated users cannot supply profile-skill creation timestamps'
);
select ok(
  to_regclass('public.profile_skills_skill_id_profile_id_idx') is not null,
  'profile skills have a reverse foreign-key lookup index'
);
select is(
  has_function_privilege('authenticated', 'private.set_profile_updated_at()', 'EXECUTE'),
  false,
  'clients cannot execute the private timestamp trigger function'
);
select is(
  has_function_privilege(
    'authenticated',
    'private.initialize_profile_visibility()',
    'EXECUTE'
  ),
  false,
  'clients cannot execute the private visibility trigger function'
);
select is(
  has_table_privilege('service_role', 'public.skills', 'SELECT'),
  false,
  'service role receives no convenience catalog grant'
);
select is(
  (
    select bool_or(
      has_table_privilege('anon', 'public.profile_field_visibility', privilege_name)
    )
    from unnest(array['SELECT', 'INSERT', 'UPDATE', 'DELETE']) as privileges(privilege_name)
  ),
  false,
  'anonymous users receive no visibility-table privilege'
);
select is(
  (
    select bool_or(
      has_table_privilege('anon', 'public.profile_skills', privilege_name)
    )
    from unnest(array['SELECT', 'INSERT', 'UPDATE', 'DELETE']) as privileges(privilege_name)
  ),
  false,
  'anonymous users receive no profile-skill privilege'
);

select * from finish();

rollback;
