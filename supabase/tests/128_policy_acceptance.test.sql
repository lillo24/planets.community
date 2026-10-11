begin;
select no_plan();

select has_table('private', 'policy_bundle_versions');
select has_table('private', 'policy_acceptances');
select columns_are('private', 'policy_acceptances', array['account_id','bundle_version','accepted_at']);
select ok((select relrowsecurity from pg_class where oid = 'private.policy_acceptances'::regclass), 'acceptances have RLS defense in depth');
select ok((select relrowsecurity from pg_class where oid = 'private.policy_bundle_versions'::regclass), 'registry has RLS defense in depth');
select is((select count(*) from private.policy_bundle_versions where bundle_version = 'POLICY01-2026-10-08-v1'), 1::bigint, 'current published version registered');

select ok(not has_table_privilege(role_name, table_name, privilege_name), role_name || ' has no direct ' || privilege_name || ' on ' || table_name)
from unnest(array['anon','authenticated','service_role']) as role_name
cross join unnest(array['private.policy_acceptances','private.policy_bundle_versions']) as table_name
cross join unnest(array['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER']) as privilege_name;

select ok(has_function_privilege('authenticated', function_name, 'EXECUTE'), 'authenticated can call ' || function_name)
from unnest(array['public.get_policy_acceptance(uuid,text)','public.accept_policy_bundle(uuid,text)']) as function_name;
select ok(not has_function_privilege(role_name, function_name, 'EXECUTE'), role_name || ' cannot call ' || function_name)
from unnest(array['anon','service_role']) as role_name
cross join unnest(array['public.get_policy_acceptance(uuid,text)','public.accept_policy_bundle(uuid,text)']) as function_name;
select ok(not has_function_privilege('authenticated', 'private.require_policy_acceptance_account(uuid,text)', 'EXECUTE'), 'private validator is not a client operation');
select ok(prosecdef and proconfig @> array['search_path=""'], proname || ' fixes empty search path and security definer')
from pg_proc where oid in ('public.get_policy_acceptance(uuid,text)'::regprocedure, 'public.accept_policy_bundle(uuid,text)'::regprocedure);

insert into auth.users (id, email) values
 ('e6000000-0000-4000-8000-000000000001','policy-tap-a@planets.invalid'),
 ('e6000000-0000-4000-8000-000000000002','policy-tap-b@planets.invalid');
insert into public.profiles (id) values ('e6000000-0000-4000-8000-000000000002');
-- Synthetic future version exists only inside this rolled-back test transaction.
insert into private.policy_bundle_versions values ('POLICY_TEST_FUTURE');

set local role authenticated;
select set_config('request.jwt.claim.sub','e6000000-0000-4000-8000-000000000001',true);
select is((select count(*) from public.get_policy_acceptance('e6000000-0000-4000-8000-000000000001','POLICY01-2026-10-08-v1')), 0::bigint, 'no record means explicit acceptance required');
select is((select count(*) from public.accept_policy_bundle('e6000000-0000-4000-8000-000000000001','POLICY01-2026-10-08-v1')), 1::bigint, 'account without profile can accept');
select ok((select account_id = 'e6000000-0000-4000-8000-000000000001'::uuid and bundle_version = 'POLICY01-2026-10-08-v1' and accepted_at between transaction_timestamp() and clock_timestamp() from public.get_policy_acceptance('e6000000-0000-4000-8000-000000000001','POLICY01-2026-10-08-v1')), 'confirmation contains exact identity/version and server time');
select set_config('test.policy_first', (select accepted_at::text from public.get_policy_acceptance('e6000000-0000-4000-8000-000000000001','POLICY01-2026-10-08-v1')),true);
select is((select accepted_at::text from public.accept_policy_bundle('e6000000-0000-4000-8000-000000000001','POLICY01-2026-10-08-v1')), current_setting('test.policy_first'), 'duplicate keeps first server timestamp');
select is((select count(*) from public.get_policy_acceptance('e6000000-0000-4000-8000-000000000001','POLICY_TEST_FUTURE')), 0::bigint, 'old acceptance does not satisfy a new version');
select lives_ok($$select public.accept_policy_bundle('e6000000-0000-4000-8000-000000000001','POLICY_TEST_FUTURE')$$, 'new registered version may be explicitly accepted');
select is((select accepted_at::text from public.get_policy_acceptance('e6000000-0000-4000-8000-000000000001','POLICY01-2026-10-08-v1')), current_setting('test.policy_first'), 'prior version and timestamp preserved');
select throws_ok($$select public.get_policy_acceptance('e6000000-0000-4000-8000-000000000002','POLICY01-2026-10-08-v1')$$,'42501',null,'cannot read another account');
select throws_ok($$select public.accept_policy_bundle('e6000000-0000-4000-8000-000000000002','POLICY01-2026-10-08-v1')$$,'42501',null,'cannot accept for another account');
select throws_ok($$select public.accept_policy_bundle(null,'POLICY01-2026-10-08-v1')$$,'42501',null,'null expected identity fails closed');
select throws_ok($$select public.get_policy_acceptance('e6000000-0000-4000-8000-000000000001','unregistered')$$,'22023',null,'unregistered read is an error');
select throws_ok($$select public.accept_policy_bundle('e6000000-0000-4000-8000-000000000001','unregistered')$$,'22023',null,'unregistered write rejected');
select throws_ok($$select public.accept_policy_bundle('e6000000-0000-4000-8000-000000000001',null)$$,'22023',null,'null version rejected');
select throws_ok($$select public.accept_policy_bundle('e6000000-0000-4000-8000-000000000001',' POLICY01-2026-10-08-v1')$$,'22023',null,'version is exact, not silently normalized');
select throws_ok($$insert into private.policy_acceptances values ('e6000000-0000-4000-8000-000000000001','POLICY01-2026-10-08-v1','2000-01-01')$$,'42501',null,'direct forged timestamp rejected');
select throws_ok($$update private.policy_acceptances set accepted_at = '2000-01-01'$$,'42501',null,'prior timestamp cannot be edited');
select throws_ok($$delete from private.policy_acceptances$$,'42501',null,'client cannot remove prior acceptance');
select throws_ok($$insert into private.policy_bundle_versions values ('client-published')$$,'42501',null,'client cannot register a policy version');
select set_config('request.jwt.claim.sub','e6000000-0000-4000-8000-000000000002',true);
select is((select count(*) from public.get_policy_acceptance('e6000000-0000-4000-8000-000000000002','POLICY01-2026-10-08-v1')),0::bigint,'another session/account cannot inherit acceptance');
select lives_ok($$select public.accept_policy_bundle('e6000000-0000-4000-8000-000000000002','POLICY01-2026-10-08-v1')$$,'incomplete profile can accept');
select set_config('request.jwt.claim.sub','',true);
select throws_ok($$select public.get_policy_acceptance('e6000000-0000-4000-8000-000000000001','POLICY01-2026-10-08-v1')$$,'42501',null,'authenticated role without a session cannot read');
select throws_ok($$select public.accept_policy_bundle('e6000000-0000-4000-8000-000000000001','POLICY01-2026-10-08-v1')$$,'42501',null,'authenticated role without a session cannot write');
select set_config('request.jwt.claim.sub','e6000000-0000-4000-8000-000000000099',true);
select throws_ok($$select public.get_policy_acceptance('e6000000-0000-4000-8000-000000000099','POLICY01-2026-10-08-v1')$$,'42501',null,'absent Auth account cannot be acknowledged');
reset role;
set local role anon;
select throws_ok($$select public.get_policy_acceptance('e6000000-0000-4000-8000-000000000001','POLICY01-2026-10-08-v1')$$,'42501',null,'anon read denied');
select throws_ok($$select public.accept_policy_bundle('e6000000-0000-4000-8000-000000000001','POLICY01-2026-10-08-v1')$$,'42501',null,'anon mutation denied');
reset role;
select is((select count(*) from private.policy_acceptances where account_id = 'e6000000-0000-4000-8000-000000000001'),2::bigint,'one record per accepted version');
select is((select count(*) from public.profiles where id = 'e6000000-0000-4000-8000-000000000001'),0::bigint,'acceptance creates no profile anchor');
delete from auth.users where id = 'e6000000-0000-4000-8000-000000000001';
select is((select count(*) from private.policy_acceptances where account_id = 'e6000000-0000-4000-8000-000000000001'),0::bigint,'no new Auth deletion blocker or retention exemption');
select * from finish();
rollback;
