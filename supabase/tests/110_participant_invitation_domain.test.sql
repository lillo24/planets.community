begin;
select no_plan();

select ok(not has_table_privilege('authenticated', 'private.project_participant_invitation_secrets', 'SELECT'), 'sharing secrets have no direct client access');
select ok(not has_table_privilege('service_role', 'private.project_participant_invitations', 'SELECT'), 'generic service role cannot enumerate generations');
select ok(not has_function_privilege('anon', 'public.accept_project_participant_invitation(uuid,text,uuid)', 'EXECUTE'), 'signed-out users can only preview');
select ok(has_function_privilege('anon', 'public.get_project_participant_invitation_preview(text)', 'EXECUTE'), 'signed-out preview is deliberate');
select col_is_null('public', 'project_memberships', 'originating_request_id', 'membership request origin now permits direct admission');

insert into auth.users(id,email)
select format('fa010000-0000-4000-8000-%s',lpad(n::text,12,'0'))::uuid,
  'pi01-' || n || '@planets.invalid' from generate_series(1,8) n;
insert into public.profiles(id,display_name)
select id, case when right(id::text,1) = '8' then null else 'PI01 ' || right(id::text,1) end
from auth.users where id between 'fa010000-0000-4000-8000-000000000001'::uuid
  and 'fa010000-0000-4000-8000-000000000008'::uuid;
insert into public.proposals(id,creator_profile_id,lifecycle_state,title,starts_at,ends_at,published_at)
select format('fa020000-0000-4000-8000-%s',lpad(n::text,12,'0'))::uuid,
  'fa010000-0000-4000-8000-000000000001','published','Invitation fixture ' || n,
  now()+interval '1 day',now()+interval '2 days',now() from generate_series(1,2) n;
insert into public.recurring_activities(id,creator_profile_id,lifecycle_state,title,published_at)
values ('fa020000-0000-4000-8000-000000000003','fa010000-0000-4000-8000-000000000001','published','Invitation Tavolo',now());
insert into public.proposals(id,creator_profile_id,title,summary,description,starts_at,ends_at,event_timezone,country_code,locality,public_location_label)
values ('fa020000-0000-4000-8000-000000000004','fa010000-0000-4000-8000-000000000002','Photo-free draft',
  'Synthetic draft summary','Synthetic draft description',now()+interval '1 day',now()+interval '2 days','Europe/Rome','IT','Trento','Trento');
insert into public.proposal_meeting_details(proposal_id,exact_meeting_text,exact_location_visibility)
values ('fa020000-0000-4000-8000-000000000004','Synthetic private workshop','participants');
update public.projects set registration_capacity=10 where id='fa020000-0000-4000-8000-000000000004';
update public.projects set registration_capacity=10 where creator_profile_id='fa010000-0000-4000-8000-000000000001';
insert into public.project_join_requests(id,project_id,requester_profile_id,request_message)
values ('fa030000-0000-4000-8000-000000000001','fa020000-0000-4000-8000-000000000001',
  'fa010000-0000-4000-8000-000000000002','Retain this private offer');
insert into public.project_join_request_skill_selections(request_id,skill_id)
select 'fa030000-0000-4000-8000-000000000001',id from public.skills order by id limit 1;
insert into public.project_resource_needs(id,project_id,title)
values ('fa050000-0000-4000-8000-000000000001','fa020000-0000-4000-8000-000000000001','Synthetic garden tools');
insert into public.project_join_request_resource_selections(request_id,resource_need_id)
values ('fa030000-0000-4000-8000-000000000001','fa050000-0000-4000-8000-000000000001');
create temp table pi01_links(project_id uuid primary key, invitation_id uuid, invite_token text, created_at timestamptz);
grant all on pi01_links to authenticated;

set local role authenticated;
select set_config('request.jwt.claim.sub','fa010000-0000-4000-8000-000000000001',true);
insert into pi01_links select 'fa020000-0000-4000-8000-000000000001',* from public.create_project_participant_invitation(
  'fa010000-0000-4000-8000-000000000001','fa020000-0000-4000-8000-000000000001');
insert into pi01_links select 'fa020000-0000-4000-8000-000000000002',* from public.create_project_participant_invitation(
  'fa010000-0000-4000-8000-000000000001','fa020000-0000-4000-8000-000000000002');
insert into pi01_links select 'fa020000-0000-4000-8000-000000000003',* from public.create_project_participant_invitation(
  'fa010000-0000-4000-8000-000000000001','fa020000-0000-4000-8000-000000000003');
select ok((select invite_token ~ '^[A-Za-z0-9_-]{43}$' from pi01_links order by project_id limit 1), 'tokens are opaque 256-bit URL-safe values');
select is((select invitation_id from public.create_project_participant_invitation('fa010000-0000-4000-8000-000000000001','fa020000-0000-4000-8000-000000000001')),
  (select invitation_id from pi01_links where project_id='fa020000-0000-4000-8000-000000000001'), 'ordinary resharing does not rotate');
select is((select invitation_id from public.get_current_project_participant_invitation('fa010000-0000-4000-8000-000000000001','fa020000-0000-4000-8000-000000000001')),
  (select invitation_id from pi01_links where project_id='fa020000-0000-4000-8000-000000000001'), 'current URL is retrievable by the manager');
select throws_ok($$select * from public.list_project_participant_invitation_history('fa010000-0000-4000-8000-000000000001','fa020000-0000-4000-8000-000000000001',51)$$,
  '22023', 'Use a limit from 1 to 50 and a complete history cursor.', 'history is bounded');

select set_config('request.jwt.claim.sub','fa010000-0000-4000-8000-000000000004',true);
select throws_ok($$select * from public.get_current_project_participant_invitation('fa010000-0000-4000-8000-000000000004','fa020000-0000-4000-8000-000000000001')$$,
  '42501','Only a current Project manager can manage participant links.','outsider cannot retrieve the sharing secret');
select throws_ok($$select * from public.create_project_participant_invitation('fa010000-0000-4000-8000-000000000001','fa020000-0000-4000-8000-000000000001')$$,
  '42501','The authenticated user does not match the expected participant identity.','stale manager identity fails');
select throws_ok($$select public.request_to_join_project('fa010000-0000-4000-8000-000000000004','fa020000-0000-4000-8000-000000000001')$$,
  'PT422','A current profile photo is required for this trust-sensitive action.','ordinary joining still requires a photo');
select throws_ok($$select * from public.accept_project_participant_invitation('fa010000-0000-4000-8000-000000000004','invalid',gen_random_uuid())$$,
  'PT409','This participant invitation is unavailable.','malformed tokens do not get the photo exception');
select results_eq($$select * from public.get_project_participant_invitation_preview('invalid')$$,
  $$select false,null::uuid,null::text,null::text$$,'invalid previews disclose no activity');
select results_eq($$select available,project_id,project_kind,project_title from public.get_project_participant_invitation_preview(
  (select invite_token from pi01_links where project_id='fa020000-0000-4000-8000-000000000001'))$$,
  $$select true,'fa020000-0000-4000-8000-000000000001'::uuid,'one_time'::text,'Invitation fixture 1'::text$$,'preview contains only public identity/kind/title');
do $$ begin
  perform set_config('pi01.preview_token',(select invite_token from pi01_links where project_id='fa020000-0000-4000-8000-000000000001'),true);
end; $$;
set local role anon;
select is((select available from public.get_project_participant_invitation_preview(current_setting('pi01.preview_token'))),true,'anonymous callers can preview without an account');
select throws_ok($$select * from private.project_participant_invitation_secrets$$,'42501',null,'anonymous preview grants no secret-table access');
reset role;
select is((select count(*) from public.project_memberships where project_id='fa020000-0000-4000-8000-000000000001'),0::bigint,'preview creates no membership');

set local role authenticated;
select set_config('request.jwt.claim.sub','fa010000-0000-4000-8000-000000000008',true);
select throws_ok($$select * from public.accept_project_participant_invitation('fa010000-0000-4000-8000-000000000008',
  (select invite_token from pi01_links where project_id='fa020000-0000-4000-8000-000000000001'),gen_random_uuid())$$,
  '55000','A complete profile is required to request project participation.','non-photo profile remains required');
select set_config('request.jwt.claim.sub','fa010000-0000-4000-8000-000000000002',true);
select set_config('pi01.first_membership',(select membership_id::text from public.accept_project_participant_invitation(
  'fa010000-0000-4000-8000-000000000002',(select invite_token from pi01_links where project_id='fa020000-0000-4000-8000-000000000001'),
  'fa040000-0000-4000-8000-000000000001')),true);
select results_eq($$select outcome,membership_status,replayed from public.accept_project_participant_invitation(
  'fa010000-0000-4000-8000-000000000002',(select invite_token from pi01_links where project_id='fa020000-0000-4000-8000-000000000001'),
  'fa040000-0000-4000-8000-000000000001')$$,$$select 'joined'::text,'current'::text,true$$,'lost-response replay recovers the original join');
select results_eq($$select outcome,replayed from public.accept_project_participant_invitation(
  'fa010000-0000-4000-8000-000000000002',(select invite_token from pi01_links where project_id='fa020000-0000-4000-8000-000000000001'),
  'fa040000-0000-4000-8000-000000000002')$$,$$select 'already_joined'::text,false$$,'fresh action for current participant is a no-op');
select results_eq($$select * from public.get_project_join_request_resolution_context('fa010000-0000-4000-8000-000000000002','fa030000-0000-4000-8000-000000000001')$$,
  $$select 'direct_participant_invitation'::text,current_setting('pi01.first_membership')::uuid$$,'requester can read truthful supersession');
select results_eq($$select viewer_role,has_current_entitlement,has_history_entitlement from public.get_own_project_group_chat(
  'fa010000-0000-4000-8000-000000000002','fa020000-0000-4000-8000-000000000001')$$,
  $$select 'current_member'::text,true,true$$,'photo-free direct member has canonical chat entitlement');
select is((select count(*) from public.list_current_project_people('fa010000-0000-4000-8000-000000000002','fa020000-0000-4000-8000-000000000001')),2::bigint,'direct member appears with Creator in canonical People');
select throws_ok($$select public.publish_proposal('fa010000-0000-4000-8000-000000000002','fa020000-0000-4000-8000-000000000004')$$,
  'PT422','A current profile photo is required for this trust-sensitive action.','invited membership does not exempt publication from its photo gate');
select set_config('request.jwt.claim.sub','fa010000-0000-4000-8000-000000000003',true);
select is((select outcome from public.accept_project_participant_invitation('fa010000-0000-4000-8000-000000000003',
  (select invite_token from pi01_links where project_id='fa020000-0000-4000-8000-000000000001'),gen_random_uuid())),'joined','another photo-free account can use the same token');
select throws_ok($$select * from public.accept_project_participant_invitation('fa010000-0000-4000-8000-000000000002',
  current_setting('pi01.preview_token'),'fa040000-0000-4000-8000-000000000001')$$,
  '42501','The authenticated user does not match the expected participant identity.','account switching cannot recover another account action');
select is((select count(*) from public.get_project_join_request_resolution_context('fa010000-0000-4000-8000-000000000003','fa030000-0000-4000-8000-000000000001')),0::bigint,'other participants cannot read private request resolution');
reset role;
select is((select count(*) from public.project_memberships where project_id='fa020000-0000-4000-8000-000000000001'),2::bigint,'repeats create no duplicate episodes');
select ok((select originating_request_id is null and originating_participant_invitation_id is not null from public.project_memberships where id=current_setting('pi01.first_membership')::uuid),'direct origin is truthful');
select is((select count(*) from public.project_membership_skill_commitments where membership_id=current_setting('pi01.first_membership')::uuid),0::bigint,'pending skills create no commitments');
select is((select count(*) from public.project_membership_resource_commitments where membership_id=current_setting('pi01.first_membership')::uuid),0::bigint,'direct admission creates no resource commitments');
select is((select count(*) from public.project_membership_skill_coverages where membership_id=current_setting('pi01.first_membership')::uuid),0::bigint,'no automatic skill coverage');
select is((select count(*) from public.project_join_request_skill_selections where request_id='fa030000-0000-4000-8000-000000000001'),1::bigint,'old contribution offers remain history');
select is((select count(*) from public.project_join_request_resource_selections where request_id='fa030000-0000-4000-8000-000000000001'),1::bigint,'old resource offers remain history');
select is((select count(*) from public.project_membership_resource_coverages where membership_id=current_setting('pi01.first_membership')::uuid),0::bigint,'no automatic resource coverage');
select ok((select status='withdrawn' and resolved_by_profile_id=requester_profile_id and request_message='Retain this private offer' from public.project_join_requests where id='fa030000-0000-4000-8000-000000000001'),'pending request is withdrawn by the requester without fake triage');
select is((select count(*) from public.project_join_request_skill_acceptance_decisions where request_id='fa030000-0000-4000-8000-000000000001'),0::bigint,'no organizer acceptance decisions are fabricated');
select is((select count(*) from public.project_join_request_chats where request_id='fa030000-0000-4000-8000-000000000001'),1::bigint,'the request chat is preserved');
select is((select count(*) from public.project_group_chats where project_id='fa020000-0000-4000-8000-000000000001'),1::bigint,'canonical group chat activates once');
select throws_ok($$insert into public.project_memberships(project_id,participant_profile_id,joined_at)
  values ('fa020000-0000-4000-8000-000000000001','fa010000-0000-4000-8000-000000000004',statement_timestamp())$$,
  '23514',null,'a membership cannot have no admission origin');
select throws_ok($$insert into public.project_memberships(project_id,participant_profile_id,originating_participant_invitation_id,joined_at)
  select 'fa020000-0000-4000-8000-000000000002','fa010000-0000-4000-8000-000000000004',invitation_id,statement_timestamp()
  from pi01_links where project_id='fa020000-0000-4000-8000-000000000001'$$,
  '23503',null,'invitation origin is bound to its Project');
select is((select count(*) from private.outbox_events where event_type='project.participant_invitation_joined' and payload->>'project_id'='fa020000-0000-4000-8000-000000000001'),2::bigint,'one truthful join event per new episode');
select ok(not exists(select 1 from private.audit_events a cross join pi01_links l where a.metadata::text like '%'||l.invite_token||'%'),'audit has no raw tokens');
select ok(not exists(select 1 from private.outbox_events e cross join pi01_links l where e.payload::text like '%'||l.invite_token||'%'),'outbox has no raw tokens');
set local role authenticated;
select set_config('request.jwt.claim.sub','fa010000-0000-4000-8000-000000000001',true);
select set_config('pi01.case_id',(select case_id::text from public.submit_moderation_report(
  'fa010000-0000-4000-8000-000000000001',gen_random_uuid(),'harassment_abuse','Synthetic reported Project conduct.',
  'profile','fa010000-0000-4000-8000-000000000002','project','fa020000-0000-4000-8000-000000000001')),true);
reset role;
select is((select count(*) from private.moderation_evidence_requests
  where case_id=current_setting('pi01.case_id')::uuid and recipient_profile_id='fa010000-0000-4000-8000-000000000003'),1::bigint,
  'moderation snapshots include direct members without request origins');
select throws_ok($$update public.project_memberships set originating_request_id='fa030000-0000-4000-8000-000000000001',originating_participant_invitation_id=null where id=current_setting('pi01.first_membership')::uuid$$,
  '55000','A membership admission origin is immutable.','admission origins cannot be rewritten');

set local role authenticated;
select set_config('request.jwt.claim.sub','fa010000-0000-4000-8000-000000000002',true);
select lives_ok($$select public.leave_project('fa010000-0000-4000-8000-000000000002',current_setting('pi01.first_membership')::uuid)$$,'photo-free member can leave');
select results_eq($$select outcome,membership_status,replayed from public.accept_project_participant_invitation(
  'fa010000-0000-4000-8000-000000000002',(select invite_token from pi01_links where project_id='fa020000-0000-4000-8000-000000000001'),
  'fa040000-0000-4000-8000-000000000001')$$,$$select 'joined'::text,'left'::text,true$$,'old action after departure does not restore membership');
select set_config('pi01.second_membership',(select membership_id::text from public.accept_project_participant_invitation(
  'fa010000-0000-4000-8000-000000000002',(select invite_token from pi01_links where project_id='fa020000-0000-4000-8000-000000000001'),
  'fa040000-0000-4000-8000-000000000003')),true);
select isnt(current_setting('pi01.second_membership'),current_setting('pi01.first_membership'),'deliberate re-entry creates a fresh episode');
select set_config('request.jwt.claim.sub','fa010000-0000-4000-8000-000000000001',true);
select lives_ok($$select public.remove_project_member_as_manager('fa010000-0000-4000-8000-000000000001',current_setting('pi01.second_membership')::uuid)$$,'manager can remove direct member');
select set_config('request.jwt.claim.sub','fa010000-0000-4000-8000-000000000002',true);
select is((select membership_status from public.accept_project_participant_invitation('fa010000-0000-4000-8000-000000000002',
  (select invite_token from pi01_links where project_id='fa020000-0000-4000-8000-000000000001'),'fa040000-0000-4000-8000-000000000003')),'removed','replay after removal does not undo removal');
select is((select outcome from public.accept_project_participant_invitation('fa010000-0000-4000-8000-000000000002',
  (select invite_token from pi01_links where project_id='fa020000-0000-4000-8000-000000000001'),'fa040000-0000-4000-8000-000000000004')),'joined','fresh action can re-enter after removal');
select throws_ok($$select * from public.accept_project_participant_invitation('fa010000-0000-4000-8000-000000000002',
  (select invite_token from pi01_links where project_id='fa020000-0000-4000-8000-000000000002'),'fa040000-0000-4000-8000-000000000001')$$,
  'PT409','This admission action belongs to a different invitation.','actions are bound to their original generation');
select set_config('request.jwt.claim.sub','fa010000-0000-4000-8000-000000000001',true);
select results_eq($$select outcome,membership_id from public.accept_project_participant_invitation('fa010000-0000-4000-8000-000000000001',
  (select invite_token from pi01_links where project_id='fa020000-0000-4000-8000-000000000001'),gen_random_uuid())$$,
  $$select 'creator'::text,null::uuid$$,'Creator remains a distinct role');
select lives_ok($$select * from public.regenerate_project_participant_invitation('fa010000-0000-4000-8000-000000000001','fa020000-0000-4000-8000-000000000001')$$,'manager explicitly rotates the token');
select is((select available from public.get_project_participant_invitation_preview((select invite_token from pi01_links where project_id='fa020000-0000-4000-8000-000000000001'))),false,'replaced token preview is unavailable');
select set_config('request.jwt.claim.sub','fa010000-0000-4000-8000-000000000002',true);
select is((select replayed from public.accept_project_participant_invitation('fa010000-0000-4000-8000-000000000002',
  (select invite_token from pi01_links where project_id='fa020000-0000-4000-8000-000000000001'),'fa040000-0000-4000-8000-000000000001')),true,'committed outcomes remain recoverable after rotation');
select throws_ok($$select * from public.accept_project_participant_invitation('fa010000-0000-4000-8000-000000000002',
  (select invite_token from pi01_links where project_id='fa020000-0000-4000-8000-000000000001'),gen_random_uuid())$$,
  'PT409','This participant invitation is unavailable.','old token cannot create a new admission');
reset role;
select is((select count(*) from private.project_participant_invitation_secrets where invitation_id=(select invitation_id from pi01_links where project_id='fa020000-0000-4000-8000-000000000001')),0::bigint,'rotation deletes the old sharing secret');

update public.recurring_activities set lifecycle_state='paused',paused_at=clock_timestamp() where id='fa020000-0000-4000-8000-000000000003';
select is((select available from public.get_project_participant_invitation_preview((select invite_token from pi01_links where project_id='fa020000-0000-4000-8000-000000000003'))),false,'paused Tavolo does not admit');
update public.recurring_activities set lifecycle_state='published',paused_at=null,resumed_at=clock_timestamp() where id='fa020000-0000-4000-8000-000000000003';
select is((select available from public.get_project_participant_invitation_preview((select invite_token from pi01_links where project_id='fa020000-0000-4000-8000-000000000003'))),true,'same unrevoked Tavolo link resumes');
update public.proposals set starts_at=now()-interval '2 days',ends_at=now()-interval '1 day' where id='fa020000-0000-4000-8000-000000000002';
select is((select available from public.get_project_participant_invitation_preview((select invite_token from pi01_links where project_id='fa020000-0000-4000-8000-000000000002'))),false,'Proposal uses current end time');
update public.proposals set ends_at=now()+interval '3 days' where id='fa020000-0000-4000-8000-000000000002';
select is((select available from public.get_project_participant_invitation_preview((select invite_token from pi01_links where project_id='fa020000-0000-4000-8000-000000000002'))),true,'edited current end reopens admission');

select * from finish();
rollback;
