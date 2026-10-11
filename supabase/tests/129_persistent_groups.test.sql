begin;
select no_plan();

select has_table('private', name, 'private group domain table') from unnest(array[
  'community_groups','community_group_managers','community_group_command_receipts','community_group_suppression_actions']) name;
select ok(relrowsecurity, relname || ' has RLS') from pg_class where oid in (
  'private.community_groups'::regclass,'private.community_group_managers'::regclass,
  'private.community_group_command_receipts'::regclass,'private.community_group_suppression_actions'::regclass);
select ok(not has_table_privilege(r,t,p),r||' has no direct '||p||' on '||t)
from unnest(array['anon','authenticated','service_role']) r
cross join unnest(array['private.community_groups','private.community_group_managers','private.community_group_command_receipts','private.community_group_suppression_actions']) t
cross join unnest(array['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER']) p;
select ok(has_function_privilege('authenticated',oid,'execute'),proname||' callable by authenticated') from pg_proc where pronamespace='public'::regnamespace and proname in (
  'create_group_draft','recover_group_command','get_own_group','list_own_groups','update_group','set_group_publication_state',
  'set_group_directory_suppression','get_group_staff_context','get_moderation_case_group','list_public_groups','get_public_group');
select ok(not has_function_privilege(r,oid,'execute'),r||' cannot execute '||proname)
from pg_proc cross join unnest(array['anon','service_role']) r where pronamespace='public'::regnamespace and proname in (
  'create_group_draft','recover_group_command','get_own_group','list_own_groups','update_group','set_group_publication_state',
  'set_group_directory_suppression','get_group_staff_context','get_moderation_case_group');
select ok(prosecdef and proconfig @> array['search_path=""'],proname||' safe search path') from pg_proc where pronamespace='public'::regnamespace and proname in (
  'create_group_draft','recover_group_command','get_own_group','list_own_groups','update_group','set_group_publication_state',
  'set_group_directory_suppression','get_group_staff_context','get_moderation_case_group','list_public_groups','get_public_group');
select ok(not has_function_privilege(r,oid,'execute'),r||' cannot execute private '||proname)
from pg_proc cross join unnest(array['anon','authenticated','service_role']) r
where pronamespace='private'::regnamespace and proname in ('normalize_group_content','require_group_actor','group_is_public','lock_group_command','group_command_hash','audit_group_change','protect_community_group_identity','protect_group_manager_authority');

insert into auth.users(id,email) select ('e7000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'grp-tap-'||n||'@planets.invalid' from generate_series(1,6) n;
insert into public.profiles(id,display_name) select id,'Fictional GRP '||right(id::text,1) from auth.users where email like 'grp-tap-%' and email<>'grp-tap-3@planets.invalid';
insert into private.moderation_staff_roles(profile_id,staff_role,is_active,deactivated_at) values
 ('e7000000-0000-4000-8000-000000000004','moderator',true,null),
 ('e7000000-0000-4000-8000-000000000005','admin',false,clock_timestamp());
select set_config('test.group_content','{"name":"Fictional garden","description":"Fictional people planting a local garden.","group_kind":"informal","locality":"Trento","volunteering_focus":true}',true);
set local role anon;
select is((select count(*) from public.list_public_groups()),0::bigint,'new directory contains no official template identities');
select throws_ok($$select public.create_group_draft('e7000000-0000-4000-8000-000000000001',gen_random_uuid(),current_setting('test.group_content')::jsonb)$$,'42501',null,'guest cannot register');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','e7000000-0000-4000-8000-000000000003',true);
select throws_ok($$select public.create_group_draft('e7000000-0000-4000-8000-000000000003',gen_random_uuid(),current_setting('test.group_content')::jsonb)$$,'55000',null,'profile-free Auth cannot register');
select set_config('request.jwt.claim.sub','e7000000-0000-4000-8000-000000000001',true);
select throws_ok($$select public.create_group_draft('e7000000-0000-4000-8000-000000000002',gen_random_uuid(),current_setting('test.group_content')::jsonb)$$,'42501',null,'expected identity mismatch');
select throws_ok($$select public.create_group_draft('e7000000-0000-4000-8000-000000000001',gen_random_uuid(),current_setting('test.group_content')::jsonb||'{"verified_ets":true}')$$,'22023',null,'verification injection rejected');
select throws_ok($$select public.create_group_draft('e7000000-0000-4000-8000-000000000001',gen_random_uuid(),current_setting('test.group_content')::jsonb||'{"name":"PLANETS Community Official"}')$$,'22023',null,'official identity reserved');
select set_config('test.group_id',public.create_group_draft('e7000000-0000-4000-8000-000000000001','e7100000-0000-4000-8000-000000000001',current_setting('test.group_content')::jsonb)::text,true);
select is(public.create_group_draft('e7000000-0000-4000-8000-000000000001','e7100000-0000-4000-8000-000000000001',current_setting('test.group_content')::jsonb)::text,current_setting('test.group_id'),'create retry same destination');
select throws_ok($$select public.create_group_draft('e7000000-0000-4000-8000-000000000001','e7100000-0000-4000-8000-000000000001',current_setting('test.group_content')::jsonb||'{"name":"Changed"}')$$,'22023',null,'changed creation intent fails');
select is((select count(*) from public.list_own_groups('e7000000-0000-4000-8000-000000000001')),1::bigint,'owner lists draft');
select is((select count(*) from public.get_public_group(current_setting('test.group_id')::uuid)),0::bigint,'draft detail unavailable');
select is(public.set_group_publication_state('e7000000-0000-4000-8000-000000000001',current_setting('test.group_id')::uuid,'e7100000-0000-4000-8000-000000000002',1,'published'),2::bigint,'owner explicitly publishes without photo');
select is(public.set_group_publication_state('e7000000-0000-4000-8000-000000000001',current_setting('test.group_id')::uuid,'e7100000-0000-4000-8000-000000000002',1,'published'),2::bigint,'lost publication response recovers');
select throws_ok($$select public.update_group('e7000000-0000-4000-8000-000000000001',current_setting('test.group_id')::uuid,gen_random_uuid(),1,current_setting('test.group_content')::jsonb)$$,'PT409',null,'stale edit rejected');
select throws_ok($$select public.set_group_directory_suppression('e7000000-0000-4000-8000-000000000001',current_setting('test.group_id')::uuid,gen_random_uuid(),2,true,'A private reason')$$,'42501',null,'owner cannot suppress or restore');
select set_config('request.jwt.claim.sub','e7000000-0000-4000-8000-000000000002',true);
select throws_ok($$select public.get_own_group('e7000000-0000-4000-8000-000000000002',current_setting('test.group_id')::uuid)$$,'42501',null,'other person cannot edit');
select set_config('test.group_case',(select case_id::text from public.submit_moderation_report('e7000000-0000-4000-8000-000000000002','e7100000-0000-4000-8000-000000000003','other','Fictional report for manual review','group',current_setting('test.group_id')::uuid)),true);
select is((select count(*) from public.list_own_moderation_reports('e7000000-0000-4000-8000-000000000002')),1::bigint,'reporter has genuine group report');
select throws_ok($$select public.get_group_staff_context('e7000000-0000-4000-8000-000000000002',current_setting('test.group_id')::uuid)$$,'42501',null,'ordinary person cannot inspect staff context');
select set_config('request.jwt.claim.sub','e7000000-0000-4000-8000-000000000005',true);
select throws_ok($$select public.get_group_staff_context('e7000000-0000-4000-8000-000000000005',current_setting('test.group_id')::uuid)$$,'42501',null,'inactive staff denied');
select set_config('request.jwt.claim.sub','e7000000-0000-4000-8000-000000000004',true);
select is(public.get_moderation_case_group('e7000000-0000-4000-8000-000000000004',current_setting('test.group_case')::uuid)->>'manager_profile_id','e7000000-0000-4000-8000-000000000001','staff context derives accountable person');
select is(public.set_group_directory_suppression('e7000000-0000-4000-8000-000000000004',current_setting('test.group_id')::uuid,gen_random_uuid(),2,true,'A protected staff reason'),3::bigint,'active staff hides');
select is((select count(*) from public.get_public_group(current_setting('test.group_id')::uuid)),0::bigint,'suppressed group unavailable');
select set_config('request.jwt.claim.sub','e7000000-0000-4000-8000-000000000001',true);
select is(public.update_group('e7000000-0000-4000-8000-000000000001',current_setting('test.group_id')::uuid,gen_random_uuid(),3,current_setting('test.group_content')::jsonb||'{"name":"Edited group"}'),4::bigint,'owner may edit hidden page');
select is((select count(*) from public.get_public_group(current_setting('test.group_id')::uuid)),0::bigint,'edit cannot bypass hiding');
select is(public.set_group_publication_state('e7000000-0000-4000-8000-000000000001',current_setting('test.group_id')::uuid,gen_random_uuid(),4,'draft'),5::bigint,'owner can unpublish');
select set_config('request.jwt.claim.sub','e7000000-0000-4000-8000-000000000004',true);
select is(public.set_group_directory_suppression('e7000000-0000-4000-8000-000000000004',current_setting('test.group_id')::uuid,gen_random_uuid(),5,false,'Reviewed and restored'),6::bigint,'staff restores suppression only');
select is((select count(*) from public.get_public_group(current_setting('test.group_id')::uuid)),0::bigint,'staff restore does not publish draft');
reset role;
select is((select subject_profile_id from private.moderation_cases where id=current_setting('test.group_case')::uuid),'e7000000-0000-4000-8000-000000000001'::uuid,'report subject canonical');
select is((select count(*) from private.moderation_evidence_requests where case_id=current_setting('test.group_case')::uuid),0::bigint,'no Project corroboration for group');
select is((select count(*) from private.moderation_evidence_requests where case_id=current_setting('test.group_case')::uuid and request_kind='resource_counterstatement'),0::bigint,'no Resource counterstatement for group');
select is((select count(*) from private.audit_events where target_id=current_setting('test.group_id')::uuid and action='group.created'),1::bigint,'creation audit deduplicated');
select ok(not exists(select 1 from private.audit_events where target_id=current_setting('test.group_id')::uuid and (metadata::text like '%Fictional%' or metadata::text like '%reason%')),'no prose in generic audit');
select throws_ok($$update private.community_groups set original_actor_id=gen_random_uuid() where id=current_setting('test.group_id')::uuid$$,'55000',null,'original provenance immutable');
select throws_ok($$update private.moderation_cases set target_group_id=gen_random_uuid() where id=current_setting('test.group_case')::uuid$$,'55000',null,'report identity append-preserved');
-- An unreported group by a person with no other product relationships can survive
-- profile AND Auth removal; GRP01's relationships and audits add no erasure FK.
set local role authenticated;
select set_config('request.jwt.claim.sub','e7000000-0000-4000-8000-000000000006',true);
select set_config('test.orphan_group',public.create_group_draft('e7000000-0000-4000-8000-000000000006',gen_random_uuid(),current_setting('test.group_content')::jsonb)::text,true);
select public.set_group_publication_state('e7000000-0000-4000-8000-000000000006',current_setting('test.orphan_group')::uuid,gen_random_uuid(),1,'published');
reset role;
select lives_ok($$delete from public.profiles where id='e7000000-0000-4000-8000-000000000006'$$,'group relationships do not prevent profile removal');
select lives_ok($$delete from auth.users where id='e7000000-0000-4000-8000-000000000006'$$,'group provenance receipts audits do not block Auth removal');
select is((select count(*) from private.community_groups where id=current_setting('test.orphan_group')::uuid),1::bigint,'orphan content retained');
select is((select count(*) from private.audit_events where target_id=current_setting('test.orphan_group')::uuid and action='group.manager_unavailable'),1::bigint,'lost manager authority audited without account FK');
select throws_ok($$update private.community_group_managers set profile_id='e7000000-0000-4000-8000-000000000001' where group_id=current_setting('test.orphan_group')::uuid$$,'55000',null,'orphan authority cannot be reassigned incidentally');
select is((select count(*) from public.get_public_group(current_setting('test.orphan_group')::uuid)),0::bigint,'orphan public read fails closed');
set local role authenticated;
select throws_ok($$select public.get_own_group('e7000000-0000-4000-8000-000000000006',current_setting('test.orphan_group')::uuid)$$,'55000',null,'stale identity denied after deletion');
reset role;
set local role anon;
select throws_ok($$select public.list_public_groups(p_group_kind=>'verified_ets')$$,'22023',null,'future filters fail explicitly');
select throws_ok($$select public.list_public_groups(p_before_id=>gen_random_uuid())$$,'22023',null,'partial cursor rejected');
select throws_ok($$select public.list_public_groups(p_before_created_at=>'infinity',p_before_id=>gen_random_uuid())$$,'22023',null,'infinite cursor rejected');
select throws_ok($$select public.list_public_groups(p_limit=>51)$$,'22023',null,'bounded pages enforced');
select throws_ok($$select public.list_public_groups(p_locality=>E'Trento\t')$$,'22023',null,'locality filter rejects trailing whitespace');
select is((select count(*) from public.get_public_group(gen_random_uuid())),0::bigint,'missing uses same unavailable shape');
reset role;
select * from finish();
rollback;
