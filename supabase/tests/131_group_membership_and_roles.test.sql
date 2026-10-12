begin;
select no_plan();
select has_table('private',name,'group relationship table') from unnest(array['group_join_requests','group_memberships','group_delegates','group_role_changes','group_authority_invitations','group_participant_invitations','group_participant_invitation_secrets','group_relationship_receipts']) name;
select ok(relrowsecurity,relname||' enables RLS') from pg_class where relnamespace='private'::regnamespace and relname=any(array['group_join_requests','group_memberships','group_delegates','group_role_changes','group_authority_invitations','group_participant_invitations','group_participant_invitation_secrets','group_relationship_receipts']);
select ok(not has_table_privilege(r,t,p),r||' cannot directly '||p||' '||t)
from unnest(array['anon','authenticated','service_role']) r
cross join unnest(array['private.group_join_requests','private.group_memberships','private.group_delegates','private.group_role_changes','private.group_authority_invitations','private.group_participant_invitations','private.group_participant_invitation_secrets','private.group_relationship_receipts']) t
cross join unnest(array['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER']) p;
select ok(prosecdef and proconfig @> array['search_path=""'],proname||' definer fixes search path')
from pg_proc where pronamespace='public'::regnamespace and proname=any(array['create_group_join_request','withdraw_group_join_request','accept_group_join_request','reject_group_join_request','leave_group','remove_group_member','create_group_authority_invitation','create_group_role_offer','accept_group_role_offer','decline_group_role_offer','revoke_group_authority_invitation','change_group_delegate_role','revoke_group_delegate','step_down_group_authority','accept_group_authority_invitation','accept_group_participant_invitation','recover_group_relationship_command','create_group_participant_invitation','regenerate_group_participant_invitation','revoke_group_participant_invitation','get_current_group_participant_invitation','get_group_participant_invitation_preview','get_group_authority_invitation_preview','get_own_group_role','list_current_group_people','list_own_group_join_requests','list_own_group_memberships','list_group_join_requests','list_group_membership_history','list_group_delegates','list_group_delegate_role_history','list_group_authority_invitations','list_own_group_role_offers','list_group_participant_invitation_history','list_managed_groups','get_group_structural_context','update_managed_group','set_managed_group_publication_state','recover_group_structural_command']);
select ok(has_function_privilege('authenticated',oid,'execute'),proname||' authenticated grant')
from pg_proc where pronamespace='public'::regnamespace and proname=any(array['create_group_join_request','withdraw_group_join_request','accept_group_join_request','reject_group_join_request','leave_group','remove_group_member','create_group_authority_invitation','create_group_role_offer','accept_group_role_offer','decline_group_role_offer','revoke_group_authority_invitation','change_group_delegate_role','revoke_group_delegate','step_down_group_authority','accept_group_authority_invitation','accept_group_participant_invitation','recover_group_relationship_command','create_group_participant_invitation','regenerate_group_participant_invitation','revoke_group_participant_invitation','get_current_group_participant_invitation','get_group_participant_invitation_preview','get_group_authority_invitation_preview','get_own_group_role','list_current_group_people','list_own_group_join_requests','list_own_group_memberships','list_group_join_requests','list_group_membership_history','list_group_delegates','list_group_delegate_role_history','list_group_authority_invitations','list_own_group_role_offers','list_group_participant_invitation_history','list_managed_groups','get_group_structural_context','update_managed_group','set_managed_group_publication_state','recover_group_structural_command']);
select ok(not has_function_privilege('service_role',oid,'execute'),proname||' denies service role bypass')
from pg_proc where pronamespace='public'::regnamespace and proname=any(array['create_group_join_request','withdraw_group_join_request','accept_group_join_request','reject_group_join_request','leave_group','remove_group_member','create_group_authority_invitation','create_group_role_offer','accept_group_role_offer','decline_group_role_offer','revoke_group_authority_invitation','change_group_delegate_role','revoke_group_delegate','step_down_group_authority','accept_group_authority_invitation','accept_group_participant_invitation','recover_group_relationship_command','create_group_participant_invitation','regenerate_group_participant_invitation','revoke_group_participant_invitation','get_current_group_participant_invitation','get_group_participant_invitation_preview','get_group_authority_invitation_preview','get_own_group_role','list_current_group_people','list_own_group_join_requests','list_own_group_memberships','list_group_join_requests','list_group_membership_history','list_group_delegates','list_group_delegate_role_history','list_group_authority_invitations','list_own_group_role_offers','list_group_participant_invitation_history','list_managed_groups','get_group_structural_context','update_managed_group','set_managed_group_publication_state','recover_group_structural_command']);
select ok(not has_function_privilege('anon',oid,'execute'),proname||' denies guest')
from pg_proc where pronamespace='public'::regnamespace and proname=any(array['create_group_join_request','withdraw_group_join_request','accept_group_join_request','reject_group_join_request','leave_group','remove_group_member','create_group_authority_invitation','create_group_role_offer','accept_group_role_offer','decline_group_role_offer','revoke_group_authority_invitation','change_group_delegate_role','revoke_group_delegate','step_down_group_authority','accept_group_authority_invitation','accept_group_participant_invitation','recover_group_relationship_command','create_group_participant_invitation','regenerate_group_participant_invitation','revoke_group_participant_invitation','get_current_group_participant_invitation','get_own_group_role','list_current_group_people','list_own_group_join_requests','list_own_group_memberships','list_group_join_requests','list_group_membership_history','list_group_delegates','list_group_delegate_role_history','list_group_authority_invitations','list_own_group_role_offers','list_group_participant_invitation_history','list_managed_groups','get_group_structural_context','update_managed_group','set_managed_group_publication_state','recover_group_structural_command']);
select ok(not has_function_privilege(r,oid,'execute'),r||' cannot execute private '||proname)
from pg_proc cross join unnest(array['anon','authenticated','service_role']) r where pronamespace='private'::regnamespace
and proname in ('require_group_identity','group_authority_role','lock_group_interactions','group_relationship_command','read_group_participant_link','group_structural_command','require_group_people_viewer');
select ok(not exists(select 1 from pg_constraint where contype='f' and conrelid=any(array['private.group_join_requests'::regclass,'private.group_memberships'::regclass,'private.group_delegates'::regclass,'private.group_role_changes'::regclass,'private.group_authority_invitations'::regclass,'private.group_participant_invitations'::regclass,'private.group_participant_invitation_secrets'::regclass,'private.group_relationship_receipts'::regclass]) and confrelid in ('auth.users'::regclass,'public.profiles'::regclass)),'new account provenance cannot block account erasure');
insert into auth.users(id,email) select ('e7a00000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'grp03-tap-'||n||'@planets.invalid' from generate_series(1,9) n;
insert into public.profiles(id,display_name) select id,case when email='grp03-tap-9@planets.invalid' then null else 'Fictional GRP03 '||right(id::text,1) end from auth.users where email like 'grp03-tap-%';
insert into private.community_groups(id,name,description,group_kind,volunteering_focus,publication_state,original_actor_id)
values('e7a10000-0000-4000-8000-000000000001','Fictional Garden','Fictional people cultivating a local garden.','informal',true,'published','e7a00000-0000-4000-8000-000000000001');
insert into private.community_group_managers(group_id,profile_id,appointed_by_actor_id) values('e7a10000-0000-4000-8000-000000000001','e7a00000-0000-4000-8000-000000000001','e7a00000-0000-4000-8000-000000000001');
insert into private.group_delegates(id,group_id,profile_id,initial_role,delegate_role,granted_by) select
('e7a20000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'e7a10000-0000-4000-8000-000000000001',
('e7a00000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,case when n=2 then 'co_creator' else 'co_organizer' end,
case when n=2 then 'co_creator' else 'co_organizer' end,'e7a00000-0000-4000-8000-000000000001' from generate_series(2,3) n;
insert into private.moderation_staff_roles(profile_id,staff_role,is_active) values('e7a00000-0000-4000-8000-000000000008','moderator',true);
select set_config('test.group','e7a10000-0000-4000-8000-000000000001',true);
select set_config('test.actor','e7a00000-0000-4000-8000-000000000004',true);
set local role anon;
select is((select available from public.get_group_participant_invitation_preview('bad')),false,'invalid participant preview neutral');
select is((select available from public.get_group_authority_invitation_preview('bad')),false,'invalid authority preview neutral');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub',current_setting('test.actor'),true);
select throws_ok($$select public.list_current_group_people(current_setting('test.actor')::uuid,current_setting('test.group')::uuid)$$,'42501',null,'unrelated account denied roster');
select throws_ok($$select public.create_group_join_request(current_setting('test.actor')::uuid,current_setting('test.group')::uuid,gen_random_uuid())$$,'55000',null,'ordinary request requires canonical photo');
reset role;
insert into public.profile_photos(profile_id,object_path,audience) values('e7a00000-0000-4000-8000-000000000004','e7a00000-0000-4000-8000-000000000004/e7af0000-0000-4000-8000-000000000001.webp','interactions');
set local role authenticated;
select set_config('test.request',(select relationship_id::text from public.create_group_join_request(current_setting('test.actor')::uuid,current_setting('test.group')::uuid,gen_random_uuid(),'Private fictional note')),true);
select throws_ok($$select public.list_current_group_people(current_setting('test.actor')::uuid,current_setting('test.group')::uuid)$$,'42501',null,'pending requester denied roster');
select throws_ok($$select public.list_group_join_requests(current_setting('test.actor')::uuid,current_setting('test.group')::uuid)$$,'42501',null,'pending requester denied manager history');
select is((select count(*) from public.list_own_group_join_requests(current_setting('test.actor')::uuid)),1::bigint,'requester reads own history');
select set_config('request.jwt.claim.sub','e7a00000-0000-4000-8000-000000000003',true);
select throws_ok($$select public.get_group_structural_context('e7a00000-0000-4000-8000-000000000003',current_setting('test.group')::uuid)$$,'42501',null,'co-organizer has no editor projection');
select throws_ok($$select public.create_group_authority_invitation('e7a00000-0000-4000-8000-000000000003',current_setting('test.group')::uuid,gen_random_uuid(),'co_creator')$$,'42501',null,'co-organizer cannot issue authority');
select set_config('test.member',(select relationship_id::text from public.accept_group_join_request('e7a00000-0000-4000-8000-000000000003',current_setting('test.request')::uuid,gen_random_uuid())),true);
select set_config('request.jwt.claim.sub',current_setting('test.actor'),true);
select is((select count(*) from public.list_current_group_people(current_setting('test.actor')::uuid,current_setting('test.group')::uuid)),4::bigint,'member sees Creator delegates and member once');
select throws_ok($$select public.list_group_membership_history(current_setting('test.actor')::uuid,current_setting('test.group')::uuid)$$,'42501',null,'member denied other history');
select throws_ok($$select public.list_current_group_people(current_setting('test.actor')::uuid,current_setting('test.group')::uuid,p_after_role_rank=>1)$$,'22023',null,'roster cursor paired');
select throws_ok($$select public.list_current_group_people(current_setting('test.actor')::uuid,current_setting('test.group')::uuid,p_limit=>51)$$,'22023',null,'roster bounded');
select public.leave_group(current_setting('test.actor')::uuid,current_setting('test.member')::uuid,gen_random_uuid());
select throws_ok($$select public.list_current_group_people(current_setting('test.actor')::uuid,current_setting('test.group')::uuid)$$,'42501',null,'former member denied roster');
select is((select membership_status from public.list_own_group_memberships(current_setting('test.actor')::uuid)),'left','own ended interval retained');
select set_config('request.jwt.claim.sub','e7a00000-0000-4000-8000-000000000008',true);
select throws_ok($$select public.list_current_group_people('e7a00000-0000-4000-8000-000000000008',current_setting('test.group')::uuid)$$,'42501',null,'staff status grants no People access');
select set_config('request.jwt.claim.sub','e7a00000-0000-4000-8000-000000000002',true);
select throws_ok($$select public.get_own_group('e7a00000-0000-4000-8000-000000000002',current_setting('test.group')::uuid)$$,'42501',null,'legacy Creator projection remains Creator only');
select lives_ok($$select public.get_group_structural_context('e7a00000-0000-4000-8000-000000000002',current_setting('test.group')::uuid)$$,'co-creator gets separate published structural context');
select throws_ok($$select public.change_group_delegate_role('e7a00000-0000-4000-8000-000000000002','e7a20000-0000-4000-8000-000000000002',gen_random_uuid(),'co_organizer')$$,'42501',null,'generic self role change forbidden');
select throws_ok($$select public.revoke_group_delegate('e7a00000-0000-4000-8000-000000000002','e7a20000-0000-4000-8000-000000000002',gen_random_uuid())$$,'42501',null,'generic self revoke forbidden');
select lives_ok($$select public.step_down_group_authority('e7a00000-0000-4000-8000-000000000002','e7a20000-0000-4000-8000-000000000002',gen_random_uuid())$$,'explicit Step down allowed');
select throws_ok($$select public.list_current_group_people('e7a00000-0000-4000-8000-000000000002',current_setting('test.group')::uuid)$$,'42501',null,'revoked delegate without membership denied roster');
select set_config('request.jwt.claim.sub','e7a00000-0000-4000-8000-000000000009',true);
select throws_ok($$select public.create_group_join_request('e7a00000-0000-4000-8000-000000000009',current_setting('test.group')::uuid,gen_random_uuid())$$,'55000',null,'incomplete profile denied new request');
select set_config('request.jwt.claim.sub','e7a00000-0000-4000-8000-000000000001',true);
select set_config('test.token',(select invite_token from public.create_group_participant_invitation('e7a00000-0000-4000-8000-000000000001',current_setting('test.group')::uuid,gen_random_uuid())),true);
select set_config('request.jwt.claim.sub','e7a00000-0000-4000-8000-000000000005',true);
select set_config('test.action',gen_random_uuid()::text,true);
select set_config('test.direct',(select relationship_id::text from public.accept_group_participant_invitation('e7a00000-0000-4000-8000-000000000005',current_setting('test.token'),current_setting('test.action')::uuid)),true);
select is((select current_status from public.accept_group_participant_invitation('e7a00000-0000-4000-8000-000000000005',current_setting('test.token'),current_setting('test.action')::uuid)),'current','photo-free direct acceptance recovers status');
select public.leave_group('e7a00000-0000-4000-8000-000000000005',current_setting('test.direct')::uuid,gen_random_uuid());
select is((select current_status from public.accept_group_participant_invitation('e7a00000-0000-4000-8000-000000000005',current_setting('test.token'),current_setting('test.action')::uuid)),'left','exact retry cannot resurrect departed episode');
reset role;
select is((select version from private.community_groups where id=current_setting('test.group')::uuid),1::bigint,'relationships do not bump content version');
select is((select count(*) from private.group_memberships where group_id=current_setting('test.group')::uuid and profile_id='e7a00000-0000-4000-8000-000000000001'),0::bigint,'Creator has no manufactured membership');
select throws_ok($$update private.group_delegates set initial_role='co_creator' where id='e7a20000-0000-4000-8000-000000000003'$$,'55000',null,'initial authority provenance immutable');
select ok(not exists(select 1 from private.group_relationship_receipts where result::text like '%'||current_setting('test.token')||'%'),'receipts contain no raw token');
select ok(not exists(select 1 from private.audit_events where target_id=current_setting('test.group')::uuid and (metadata::text like '%'||current_setting('test.token')||'%' or metadata::text like '%Private fictional%')),'audit excludes secrets and notes');
select lives_ok($$delete from public.profiles where id='e7a00000-0000-4000-8000-000000000005'$$,'relationship history does not prevent profile erasure');
select lives_ok($$delete from auth.users where id='e7a00000-0000-4000-8000-000000000005'$$,'relationship history does not prevent Auth erasure');
select is((select count(*) from private.group_memberships where id=current_setting('test.direct')::uuid),1::bigint,'erasure retains immutable episode provenance');
select * from finish();
rollback;
