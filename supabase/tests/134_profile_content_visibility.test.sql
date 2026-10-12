begin;
select plan(22);

select has_function('public', 'update_own_profile_content_v1', array['uuid', 'text', 'text', 'uuid[]']);
select is((select prosecdef from pg_proc where oid = 'public.update_own_profile_content_v1(uuid,text,text,uuid[])'::regprocedure), false, 'content RPC uses caller RLS');
select ok(not has_function_privilege('anon', 'public.update_own_profile_content_v1(uuid,text,text,uuid[])', 'EXECUTE'), 'anonymous cannot execute');
select ok(not has_function_privilege('service_role', 'public.update_own_profile_content_v1(uuid,text,text,uuid[])', 'EXECUTE'), 'service role has no added grant');

insert into auth.users (id, email) values
  ('81000000-0000-4000-8000-000000000001', 'partial-profile-a@planets.invalid'),
  ('82000000-0000-4000-8000-000000000002', 'partial-profile-b@planets.invalid');
insert into public.profiles (id) values ('81000000-0000-4000-8000-000000000001');
set local role authenticated;
select set_config('request.jwt.claim.sub', '81000000-0000-4000-8000-000000000001', true);
select lives_ok($$select public.update_own_profile('81000000-0000-4000-8000-000000000001', 'Legacy name', 'Old bio', '{}'::uuid[], 'private', 'public', 'private')$$, 'legacy combined call remains compatible');
select lives_ok($$select public.update_own_profile_content_v1('81000000-0000-4000-8000-000000000001', '  New name  ', '  New bio  ', array['d0000000-0000-4000-8001-000000000001'::uuid,'d0000000-0000-4000-8001-000000000001'::uuid])$$, 'new atomic content call accepts duplicates and trims');
select results_eq($$select display_name,bio from public.profiles$$, $$values ('New name'::text,'New bio'::text)$$, 'content persisted');
select is((select count(*) from public.profile_skills), 1::bigint, 'skills deduplicated');
select results_eq($$select field_key,audience from public.profile_field_visibility order by field_key$$, $$values ('bio'::text,'public'::text),('display_name'::text,'private'::text),('skills'::text,'private'::text)$$, 'content write never overwrites audiences');
select lives_ok($$update public.profile_field_visibility set audience='private' where profile_id='81000000-0000-4000-8000-000000000001' and field_key='bio'$$, 'narrow owner write supported by existing grants');
select results_eq($$select display_name,bio from public.profiles$$, $$values ('New name'::text,'New bio'::text)$$, 'audience write does not change content');
select is((select count(*) from public.profile_skills), 1::bigint, 'audience write does not change skills');
select throws_ok($$select public.update_own_profile_content_v1('81000000-0000-4000-8000-000000000001','X','Overwrite','{}'::uuid[])$$, '22023', 'Display name must contain between 2 and 60 characters.', 'invalid name rejected');
select throws_ok($$select public.update_own_profile_content_v1('81000000-0000-4000-8000-000000000001','Valid',repeat('b',501),'{}'::uuid[])$$, '22023', 'Bio must contain at most 500 characters.', 'invalid bio rejected');
select throws_ok($$select public.update_own_profile_content_v1('81000000-0000-4000-8000-000000000001','Valid','Overwrite',null)$$, '22023', 'Skill identifiers must be a non-null list of known skills.', 'null list rejected');
select throws_ok($$select public.update_own_profile_content_v1('81000000-0000-4000-8000-000000000001','Valid','Overwrite',array[null::uuid])$$, '22023', 'Skill identifiers must be a non-null list of known skills.', 'null skill rejected');
select throws_ok($$select public.update_own_profile_content_v1('81000000-0000-4000-8000-000000000001','Valid','Overwrite',array['ffffffff-ffff-4fff-8fff-ffffffffffff'::uuid])$$, '22023', 'One or more skill identifiers are not in the catalog.', 'unknown skill rejected atomically');
select results_eq($$select display_name,bio from public.profiles$$, $$values ('New name'::text,'New bio'::text)$$, 'invalid calls leave previous content intact');
select set_config('request.jwt.claim.sub', '82000000-0000-4000-8000-000000000002', true);
select throws_ok($$select public.update_own_profile_content_v1('81000000-0000-4000-8000-000000000001','Cross user','Overwrite','{}'::uuid[])$$, '42501', 'The authenticated user does not match the expected profile.', 'stale owner rejected');
select results_eq($$update public.profile_field_visibility set audience='public' where profile_id='81000000-0000-4000-8000-000000000001' returning field_key$$, $$select 'bio'::text where false$$, 'cross user audience write affects zero rows');
select throws_ok($$select public.update_own_profile_content_v1('82000000-0000-4000-8000-000000000002','No anchor','','{}'::uuid[])$$, '55000', 'The current user does not have a profile anchor.', 'missing anchor is explicit failure');
reset role;
set local role anon;
select results_eq($$select display_name,bio,skills::text from public.get_public_profile('81000000-0000-4000-8000-000000000001')$$, $$values (null::text,null::text,'[]'::text)$$, 'public projection honors independent private audiences');
select * from finish();
rollback;
