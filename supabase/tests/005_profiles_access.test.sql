begin;

select plan(14);

insert into auth.users (id, email)
values
  ('10000000-0000-4000-8000-000000000001', 'profile-a@planets.invalid'),
  ('20000000-0000-4000-8000-000000000002', 'profile-b@planets.invalid');

set local role anon;

select throws_ok(
  'select id from public.profiles',
  '42501',
  'permission denied for table profiles',
  'anon cannot read profile anchors'
);

select throws_ok(
  $$insert into public.profiles (id) values ('10000000-0000-4000-8000-000000000001')$$,
  '42501',
  'permission denied for table profiles',
  'anon cannot create profile anchors'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '10000000-0000-4000-8000-000000000001',
  true
);

select lives_ok(
  $$insert into public.profiles (id) values ('10000000-0000-4000-8000-000000000001')$$,
  'authenticated user A can create A''s profile anchor'
);

select throws_ok(
  $$insert into public.profiles (id) values ('20000000-0000-4000-8000-000000000002')$$,
  '42501',
  'new row violates row-level security policy for table "profiles"',
  'authenticated user A cannot create B''s profile anchor'
);

select throws_ok(
  $$
    insert into public.profiles (id, created_at)
    values ('10000000-0000-4000-8000-000000000001', '2000-01-01 00:00:00+00')
  $$,
  '42501',
  'permission denied for table profiles',
  'authenticated users cannot override the canonical creation time'
);

select throws_ok(
  $$insert into public.profiles (id) values ('10000000-0000-4000-8000-000000000001')$$,
  '23505',
  'duplicate key value violates unique constraint "profiles_pkey"',
  'duplicate profile creation fails deterministically'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '20000000-0000-4000-8000-000000000002',
  true
);

select lives_ok(
  $$insert into public.profiles (id) values ('20000000-0000-4000-8000-000000000002')$$,
  'authenticated user B can create B''s profile anchor'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '10000000-0000-4000-8000-000000000001',
  true
);

select results_eq(
  'select id from public.profiles order by id',
  $$values ('10000000-0000-4000-8000-000000000001'::uuid)$$,
  'authenticated user A sees A''s anchor but not B''s'
);

select throws_ok(
  $$
    update public.profiles
    set created_at = created_at
    where id = '10000000-0000-4000-8000-000000000001'
  $$,
  '42501',
  'permission denied for table profiles',
  'authenticated users cannot update profile anchors'
);

select throws_ok(
  $$delete from public.profiles where id = '10000000-0000-4000-8000-000000000001'$$,
  '42501',
  'permission denied for table profiles',
  'authenticated users cannot delete profile anchors'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '20000000-0000-4000-8000-000000000002',
  true
);

select results_eq(
  'select id from public.profiles order by id',
  $$values ('20000000-0000-4000-8000-000000000002'::uuid)$$,
  'authenticated user B sees B''s anchor but not A''s'
);

reset role;

select throws_ok(
  $$delete from auth.users where id = '10000000-0000-4000-8000-000000000001'$$,
  '23503',
  'update or delete on table "users" violates foreign key constraint "profiles_id_fkey" on table "profiles"',
  'raw Auth deletion is blocked while an application profile exists'
);

select is(
  (
    select count(*)
    from public.profiles
    where id = '10000000-0000-4000-8000-000000000001'
  ),
  1::bigint,
  'the failed Auth deletion leaves the profile anchor intact'
);

select is(
  (
    select count(*)
    from public.profiles
    where created_at is not null
      and created_at <= now()
  ),
  2::bigint,
  'PostgreSQL supplies canonical creation timestamps for both anchors'
);

select * from finish();

rollback;
