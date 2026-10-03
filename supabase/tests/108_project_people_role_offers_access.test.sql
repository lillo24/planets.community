begin;
select no_plan();
insert into auth.users(id,email) select
  ('7c410000-0000-4000-8000-' || lpad(n::text,12,'0'))::uuid,
  'role-person-' || n || '@planets.invalid' from generate_series(1,6) n;
insert into public.profiles(id,display_name)
  select id,'Role person ' || right(id::text,1) from auth.users
  where id::text like '7c410000-%';
insert into public.proposals(id,creator_profile_id,lifecycle_state,title,summary,description,
  starts_at,ends_at,event_timezone,country_code,locality,public_location_label,published_at)
values('7c440000-0000-4000-8000-000000000001','7c410000-0000-4000-8000-000000000001','published','People fixture','People fixture summary',
  'People fixture description',now()+interval '2 days',now()+interval '3 days',
  'Europe/Rome','IT','Rome','Rome',now()-interval '2 days');
update public.projects set registration_capacity=2 where id='7c440000-0000-4000-8000-000000000001';
insert into public.project_join_requests(id,project_id,requester_profile_id,status,created_at,resolved_at,resolved_by_profile_id)
values ('7c430000-0000-4000-8000-000000000002','7c440000-0000-4000-8000-000000000001','7c410000-0000-4000-8000-000000000002','accepted',now()-interval '3 days',now()-interval '2 days','7c410000-0000-4000-8000-000000000001'),
('7c430000-0000-4000-8000-000000000003','7c440000-0000-4000-8000-000000000001','7c410000-0000-4000-8000-000000000003','accepted',now()-interval '3 days',now()-interval '2 days','7c410000-0000-4000-8000-000000000001'),
('7c430000-0000-4000-8000-000000000004','7c440000-0000-4000-8000-000000000001','7c410000-0000-4000-8000-000000000004','accepted',now()-interval '3 days',now()-interval '2 days','7c410000-0000-4000-8000-000000000001');
insert into public.project_memberships(id,project_id,participant_profile_id,originating_request_id,joined_at,left_at)
values ('7c420000-0000-4000-8000-000000000002','7c440000-0000-4000-8000-000000000001','7c410000-0000-4000-8000-000000000002','7c430000-0000-4000-8000-000000000002',now()-interval '2 days',null),
('7c420000-0000-4000-8000-000000000003','7c440000-0000-4000-8000-000000000001','7c410000-0000-4000-8000-000000000003','7c430000-0000-4000-8000-000000000003',now()-interval '2 days',null),
('7c420000-0000-4000-8000-000000000004','7c440000-0000-4000-8000-000000000001','7c410000-0000-4000-8000-000000000004','7c430000-0000-4000-8000-000000000004',now()-interval '2 days',now()-interval '1 day');
update public.profile_field_visibility set audience='private' where profile_id='7c410000-0000-4000-8000-000000000002' and field_key='display_name';

select ok(not has_function_privilege('anon','public.list_current_project_people(uuid,uuid,integer,integer,uuid)','execute'),'anonymous roster RPC denied');
select ok(not has_table_privilege('authenticated','public.project_delegate_invitations','insert'),'no direct invitation writes');
select ok(not has_function_privilege('authenticated','private.require_project_people_viewer(uuid,uuid)','execute'),'private viewer helper not callable');

select set_config('request.jwt.claim.sub','7c410000-0000-4000-8000-000000000003',true);
set local role authenticated;
select is((select count(*)::integer from public.list_current_project_people('7c410000-0000-4000-8000-000000000003','7c440000-0000-4000-8000-000000000001')),3,'current group union includes Creator and two current participants');
select is((select display_name from public.list_current_project_people('7c410000-0000-4000-8000-000000000003','7c440000-0000-4000-8000-000000000001') where profile_id='7c410000-0000-4000-8000-000000000002'),'Role person 2','private public-profile name is deliberately visible inside current group');
select is((select display_name from public.get_public_profile('7c410000-0000-4000-8000-000000000002')),null::text,'public name privacy is unchanged');
select is((select count(*)::integer from public.list_current_project_people('7c410000-0000-4000-8000-000000000003','7c440000-0000-4000-8000-000000000001',1)),1,'bounded roster first page');
select is((select profile_id from public.list_current_project_people('7c410000-0000-4000-8000-000000000003','7c440000-0000-4000-8000-000000000001',1,0,'7c410000-0000-4000-8000-000000000001')),'7c410000-0000-4000-8000-000000000002'::uuid,'complete rank/UUID cursor advances');
select throws_ok($$select public.list_current_project_people('7c410000-0000-4000-8000-000000000003','7c440000-0000-4000-8000-000000000001',51)$$,'22023','Invalid People page or cursor.','page size cannot exceed bound');
select throws_ok($$select public.page_project_requests_for_manager('7c410000-0000-4000-8000-000000000003','7c440000-0000-4000-8000-000000000001')$$,'42501',null,'ordinary participant cannot read requests');
select throws_ok($$select public.create_project_role_offer('7c410000-0000-4000-8000-000000000003','7c440000-0000-4000-8000-000000000001','7c420000-0000-4000-8000-000000000002','co_creator')$$,'42501','Structural authority is required.','ordinary participant cannot offer roles');
select throws_ok($$select public.list_current_project_people('7c410000-0000-4000-8000-000000000002','7c440000-0000-4000-8000-000000000001')$$,'42501',null,'identity spoof rejected');
reset role;
select set_config('request.jwt.claim.sub','7c410000-0000-4000-8000-000000000004',true);
set local role authenticated;
select throws_ok($$select public.list_current_project_people('7c410000-0000-4000-8000-000000000004','7c440000-0000-4000-8000-000000000001')$$,'42501','Current Project people access is required.','former member is not a current roster viewer');
reset role;
select set_config('request.jwt.claim.sub','7c410000-0000-4000-8000-000000000005',true);
set local role authenticated;
select throws_ok($$select public.list_current_project_people('7c410000-0000-4000-8000-000000000005','7c440000-0000-4000-8000-000000000001')$$,'42501','Current Project people access is required.','outsider denied');
reset role;
select set_config('request.jwt.claim.sub','7c410000-0000-4000-8000-000000000001',true);
set local role authenticated;
select set_config('test.offer',public.create_project_role_offer('7c410000-0000-4000-8000-000000000001','7c440000-0000-4000-8000-000000000001','7c420000-0000-4000-8000-000000000002','co_organizer')::text,true);
select is(public.create_project_role_offer('7c410000-0000-4000-8000-000000000001','7c440000-0000-4000-8000-000000000001','7c420000-0000-4000-8000-000000000002','co_organizer'),current_setting('test.offer')::uuid,'same pending role offer is idempotent');
select throws_ok($$select public.create_project_role_offer('7c410000-0000-4000-8000-000000000001','7c440000-0000-4000-8000-000000000001','7c420000-0000-4000-8000-000000000002','co_creator')$$,'PT409','This participant already has a pending role offer.','conflicting role offer cannot overwrite pending consent');
select is((select organizer_count from public.get_project_capacity_for_manager('7c410000-0000-4000-8000-000000000001','7c440000-0000-4000-8000-000000000001')),1,'offering authority does not activate it');
select is((select count(*)::integer from public.list_project_role_offers('7c410000-0000-4000-8000-000000000001','7c440000-0000-4000-8000-000000000001')),1,'structural actor sees targeted offer');
select throws_ok($$select public.accept_project_role_offer('7c410000-0000-4000-8000-000000000001',current_setting('test.offer')::uuid)$$,'42501','The role offer is unavailable.','issuer cannot accept on target behalf');
reset role;
select ok((select token_digest is null and accepted_at is null from public.project_delegate_invitations where id=current_setting('test.offer')::uuid),'pending offer has no bearer token or fake acceptance');
select public.process_notification_outbox_batch(100);
select is((select count(*)::integer from public.notifications where recipient_profile_id='7c410000-0000-4000-8000-000000000002' and notification_kind='project_role_offered'),1,'recipient receives the canonical in-app role offer alert');
select public.process_notification_outbox_batch(100);
select is((select count(*)::integer from public.notifications where recipient_profile_id='7c410000-0000-4000-8000-000000000002' and notification_kind='project_role_offered'),1,'offer alert projection is idempotent');
select set_config('request.jwt.claim.sub','7c410000-0000-4000-8000-000000000002',true);
set local role authenticated;
select is((select count(*)::integer from public.list_project_role_offers('7c410000-0000-4000-8000-000000000002','7c440000-0000-4000-8000-000000000001')),1,'recipient sees own offer');
select set_config('test.delegate',public.accept_project_role_offer('7c410000-0000-4000-8000-000000000002',current_setting('test.offer')::uuid)::text,true);
select is(public.accept_project_role_offer('7c410000-0000-4000-8000-000000000002',current_setting('test.offer')::uuid),current_setting('test.delegate')::uuid,'repeated acceptance returns original relationship');
select is((select count(*)::integer from public.list_current_project_people('7c410000-0000-4000-8000-000000000002','7c440000-0000-4000-8000-000000000001')),3,'participant plus organizer is deduplicated');
select is(public.get_own_project_management_role('7c410000-0000-4000-8000-000000000002','7c440000-0000-4000-8000-000000000001'),'co_organizer','recipient acceptance activates requested role');
select throws_ok($$select public.create_project_role_offer('7c410000-0000-4000-8000-000000000002','7c440000-0000-4000-8000-000000000001','7c420000-0000-4000-8000-000000000003','co_creator')$$,'42501','Structural authority is required.','Co-organizer cannot create role offers');
reset role;
select ok((select accepted_by_profile_id='7c410000-0000-4000-8000-000000000002' and issuer_profile_id='7c410000-0000-4000-8000-000000000001'
  and accepted_at is not null and token_digest is null from public.project_delegate_invitations
  where id=current_setting('test.offer')::uuid),'provenance truthfully distinguishes offer issuer and accepter');
select ok(exists(select 1 from private.audit_events where action='project.delegate_added'
  and actor_user_id='7c410000-0000-4000-8000-000000000002' and metadata->>'issuer_profile_id'='7c410000-0000-4000-8000-000000000001'),'acceptance audit attributes recipient actor and actual issuer');
select is((select capacity_used_count from private.project_registration_capacity_snapshot('7c440000-0000-4000-8000-000000000001')),1,'acceptance frees one excluded-organizer slot');
select is((select social_people_count from private.project_registration_capacity_snapshot('7c440000-0000-4000-8000-000000000001')),3,'social count unchanged by promotion');
insert into public.project_join_requests(id,project_id,requester_profile_id,status,created_at,resolved_at,resolved_by_profile_id)
values('7c430000-0000-4000-8000-000000000005','7c440000-0000-4000-8000-000000000001','7c410000-0000-4000-8000-000000000005','accepted',now()-interval '3 days',now()-interval '2 days','7c410000-0000-4000-8000-000000000001');
insert into public.project_memberships(id,project_id,participant_profile_id,originating_request_id,joined_at)
values('7c420000-0000-4000-8000-000000000005','7c440000-0000-4000-8000-000000000001','7c410000-0000-4000-8000-000000000005','7c430000-0000-4000-8000-000000000005',now()-interval '2 days');
select set_config('request.jwt.claim.sub','7c410000-0000-4000-8000-000000000002',true);
set local role authenticated;
select throws_ok($$select public.step_down_project_authority('7c410000-0000-4000-8000-000000000002',current_setting('test.delegate')::uuid)$$,
 'PT409','Project capacity cannot revoke this organizer while their participant membership is current.','step-down does not bypass capacity guard');
reset role;
select ok((select revoked_at is null from public.project_delegates where id=current_setting('test.delegate')::uuid),'failed step-down rolls back authority');
select ok((select left_at is null and removed_at is null from public.project_memberships where id='7c420000-0000-4000-8000-000000000002'),'failed step-down never silently ends membership');
select set_config('request.jwt.claim.sub','7c410000-0000-4000-8000-000000000001',true);
set local role authenticated;
select throws_ok($$select public.revoke_project_delegate('7c410000-0000-4000-8000-000000000001',current_setting('test.delegate')::uuid)$$,
 'PT409','Project capacity cannot revoke this organizer while their participant membership is current.','manager revocation shares capacity conflict');
reset role;
select set_config('request.jwt.claim.sub','7c410000-0000-4000-8000-000000000002',true);
set local role authenticated;
select public.leave_project('7c410000-0000-4000-8000-000000000002','7c420000-0000-4000-8000-000000000002');
select is(public.get_own_project_management_role('7c410000-0000-4000-8000-000000000002','7c440000-0000-4000-8000-000000000001'),'co_organizer','acceptance-first then leave preserves independent authority');
select public.step_down_project_authority('7c410000-0000-4000-8000-000000000002',current_setting('test.delegate')::uuid);
select is(public.get_own_project_management_role('7c410000-0000-4000-8000-000000000002','7c440000-0000-4000-8000-000000000001'),'none','authority-only organizer can step down');
select throws_ok($$select public.list_current_project_people('7c410000-0000-4000-8000-000000000002','7c440000-0000-4000-8000-000000000001')$$,
 '42501','Current Project people access is required.','step-down clears roster entitlement when membership already ended');
reset role;
update public.projects set registration_capacity=3 where id='7c440000-0000-4000-8000-000000000001';
insert into public.project_join_requests(id,project_id,requester_profile_id,status,created_at,resolved_at,resolved_by_profile_id)
values('7c430000-0000-4000-8000-000000000012','7c440000-0000-4000-8000-000000000001','7c410000-0000-4000-8000-000000000002','accepted',now()-interval '3 days',now()-interval '2 days','7c410000-0000-4000-8000-000000000001');
insert into public.project_memberships(id,project_id,participant_profile_id,originating_request_id,joined_at)
values('7c420000-0000-4000-8000-000000000012','7c440000-0000-4000-8000-000000000001','7c410000-0000-4000-8000-000000000002','7c430000-0000-4000-8000-000000000012',now()-interval '1 day');
select set_config('request.jwt.claim.sub','7c410000-0000-4000-8000-000000000001',true);
set local role authenticated;
select set_config('test.offer',public.create_project_role_offer('7c410000-0000-4000-8000-000000000001','7c440000-0000-4000-8000-000000000001','7c420000-0000-4000-8000-000000000012','co_creator')::text,true);
reset role;
select set_config('request.jwt.claim.sub','7c410000-0000-4000-8000-000000000002',true);
set local role authenticated;
select public.decline_project_role_offer('7c410000-0000-4000-8000-000000000002',current_setting('test.offer')::uuid);
select public.decline_project_role_offer('7c410000-0000-4000-8000-000000000002',current_setting('test.offer')::uuid);
select throws_ok($$select public.accept_project_role_offer('7c410000-0000-4000-8000-000000000002',current_setting('test.offer')::uuid)$$,'PT409','This role offer is no longer eligible for acceptance.','declined offer cannot grant authority');
reset role;
select set_config('request.jwt.claim.sub','7c410000-0000-4000-8000-000000000001',true);
set local role authenticated;
select set_config('test.offer',public.create_project_role_offer('7c410000-0000-4000-8000-000000000001','7c440000-0000-4000-8000-000000000001','7c420000-0000-4000-8000-000000000012','co_creator')::text,true);
reset role;
select set_config('request.jwt.claim.sub','7c410000-0000-4000-8000-000000000002',true);
set local role authenticated;
select set_config('test.delegate',public.accept_project_role_offer('7c410000-0000-4000-8000-000000000002',current_setting('test.offer')::uuid)::text,true);
select set_config('test.peer_offer',public.create_project_role_offer('7c410000-0000-4000-8000-000000000002','7c440000-0000-4000-8000-000000000001','7c420000-0000-4000-8000-000000000003','co_organizer')::text,true);
select public.step_down_project_authority('7c410000-0000-4000-8000-000000000002',current_setting('test.delegate')::uuid);
select is(public.get_own_project_management_role('7c410000-0000-4000-8000-000000000002','7c440000-0000-4000-8000-000000000001'),'none','Co-creator can explicitly step down without generic self-demotion');
reset role;
select ok((select status='revoked' from public.project_delegate_invitations where id=current_setting('test.peer_offer')::uuid),'Co-creator step-down invalidates issued pending offers');
select ok((select left_at is null and removed_at is null from public.project_memberships where id='7c420000-0000-4000-8000-000000000012'),'successful step-down preserves participant membership');
select set_config('request.jwt.claim.sub','7c410000-0000-4000-8000-000000000003',true);
set local role authenticated;
select throws_ok($$select public.accept_project_role_offer('7c410000-0000-4000-8000-000000000003',current_setting('test.peer_offer')::uuid)$$,
 'PT409','This role offer is no longer eligible for acceptance.','former structural issuer cannot grant authority through stale offer');
reset role;
select set_config('request.jwt.claim.sub','7c410000-0000-4000-8000-000000000001',true);
set local role authenticated;
select set_config('test.offer',public.create_project_role_offer('7c410000-0000-4000-8000-000000000001','7c440000-0000-4000-8000-000000000001','7c420000-0000-4000-8000-000000000012','co_organizer')::text,true);
reset role;
select set_config('request.jwt.claim.sub','7c410000-0000-4000-8000-000000000002',true);
set local role authenticated;
select public.leave_project('7c410000-0000-4000-8000-000000000002','7c420000-0000-4000-8000-000000000012');
select throws_ok($$select public.accept_project_role_offer('7c410000-0000-4000-8000-000000000002',current_setting('test.offer')::uuid)$$,'PT409','This role offer is no longer eligible for acceptance.','leave-first rejects acceptance');
reset role;
insert into public.project_join_requests(id,project_id,requester_profile_id,status,created_at,resolved_at,resolved_by_profile_id)
values('7c430000-0000-4000-8000-000000000022','7c440000-0000-4000-8000-000000000001','7c410000-0000-4000-8000-000000000002','accepted',now()-interval '3 days',now()-interval '2 days','7c410000-0000-4000-8000-000000000001');
insert into public.project_memberships(id,project_id,participant_profile_id,originating_request_id,joined_at)
values('7c420000-0000-4000-8000-000000000022','7c440000-0000-4000-8000-000000000001','7c410000-0000-4000-8000-000000000002','7c430000-0000-4000-8000-000000000022',now());
select set_config('request.jwt.claim.sub','7c410000-0000-4000-8000-000000000002',true);
set local role authenticated;
select throws_ok($$select public.accept_project_role_offer('7c410000-0000-4000-8000-000000000002',current_setting('test.offer')::uuid)$$,'PT409','This role offer is no longer eligible for acceptance.','leave/rejoin does not revive earlier membership offer');
reset role;
select set_config('request.jwt.claim.sub','7c410000-0000-4000-8000-000000000001',true);
set local role authenticated;
select is((select count(*)::integer from public.page_project_history_for_manager('7c410000-0000-4000-8000-000000000001','7c440000-0000-4000-8000-000000000001',1)),1,'membership history has independent bounded page');
select is((select count(*)::integer from public.page_project_requests_for_manager('7c410000-0000-4000-8000-000000000001','7c440000-0000-4000-8000-000000000001',1)),1,'request history has independent bounded page');
select is((select count(*)::integer from public.page_project_requests_for_manager('7c410000-0000-4000-8000-000000000001','7c440000-0000-4000-8000-000000000001')),6,'resolved requests are retained');
select set_config('test.offer',public.create_project_role_offer('7c410000-0000-4000-8000-000000000001','7c440000-0000-4000-8000-000000000001','7c420000-0000-4000-8000-000000000022','co_organizer')::text,true);
reset role;
update public.project_delegate_invitations set created_at=now()-interval '8 days',expires_at=now()-interval '1 day'
  where id=current_setting('test.offer')::uuid;
select set_config('request.jwt.claim.sub','7c410000-0000-4000-8000-000000000002',true);
set local role authenticated;
select throws_ok($$select public.accept_project_role_offer('7c410000-0000-4000-8000-000000000002',current_setting('test.offer')::uuid)$$,'PT409','This role offer is no longer eligible for acceptance.','expired offer cannot activate authority');
reset role;

-- Targeted offers do not appear as anonymous bearer links in Team.
select set_config('request.jwt.claim.sub','7c410000-0000-4000-8000-000000000001',true);
set local role authenticated;
select is((select count(*)::integer from public.list_project_delegate_invitations_for_owner('7c410000-0000-4000-8000-000000000001','7c440000-0000-4000-8000-000000000001')),0,'Team bearer invitation read excludes targeted offers');
select set_config('test.offer',public.create_project_role_offer('7c410000-0000-4000-8000-000000000001','7c440000-0000-4000-8000-000000000001','7c420000-0000-4000-8000-000000000022','co_organizer')::text,true);
select public.revoke_project_delegate_invitation('7c410000-0000-4000-8000-000000000001',current_setting('test.offer')::uuid);
reset role;
select set_config('request.jwt.claim.sub','7c410000-0000-4000-8000-000000000002',true);
set local role authenticated;
select throws_ok($$select public.accept_project_role_offer('7c410000-0000-4000-8000-000000000002',current_setting('test.offer')::uuid)$$,'PT409','This role offer is no longer eligible for acceptance.','withdrawn targeted offer cannot activate authority');
select throws_ok($$select public.step_down_project_authority('7c410000-0000-4000-8000-000000000002','7c420000-0000-4000-8000-000000000003')$$,'42501','Only your own delegated role can be stepped down.','step-down cannot target someone else');
reset role;
update public.projects set registration_capacity=4,count_organizers_toward_capacity=true where id='7c440000-0000-4000-8000-000000000001';
select set_config('request.jwt.claim.sub','7c410000-0000-4000-8000-000000000001',true);
set local role authenticated;
select public.block_user('7c410000-0000-4000-8000-000000000001','7c410000-0000-4000-8000-000000000002');
select set_config('test.offer',public.create_project_role_offer('7c410000-0000-4000-8000-000000000001','7c440000-0000-4000-8000-000000000001','7c420000-0000-4000-8000-000000000022','co_organizer')::text,true);
reset role;
select set_config('request.jwt.claim.sub','7c410000-0000-4000-8000-000000000002',true);
set local role authenticated;
select set_config('test.delegate',public.accept_project_role_offer('7c410000-0000-4000-8000-000000000002',current_setting('test.offer')::uuid)::text,true);
select is((select capacity_used_count from public.get_project_capacity_for_manager('7c410000-0000-4000-8000-000000000002','7c440000-0000-4000-8000-000000000001')),4,'organizer counting ON does not double-count a participant accepting authority');
select is((select count(*)::integer from public.list_current_project_people('7c410000-0000-4000-8000-000000000002','7c440000-0000-4000-8000-000000000001')),4,'blocking does not erase accepted shared-group access or names');
select public.step_down_project_authority('7c410000-0000-4000-8000-000000000002',current_setting('test.delegate')::uuid);
reset role;
select ok((select left_at is null and removed_at is null from public.project_memberships where id='7c420000-0000-4000-8000-000000000022'),'step-down with organizer counting ON preserves participation');
select set_config('request.jwt.claim.sub','7c410000-0000-4000-8000-000000000001',true);
set local role authenticated;
select is((select capacity_used_count from public.get_project_capacity_for_manager('7c410000-0000-4000-8000-000000000001','7c440000-0000-4000-8000-000000000001')),4,'step-down with counting ON leaves unique capacity usage unchanged');
select set_config('test.offer',public.create_project_role_offer('7c410000-0000-4000-8000-000000000001','7c440000-0000-4000-8000-000000000001','7c420000-0000-4000-8000-000000000022','co_creator')::text,true);
reset role;
update public.proposals set lifecycle_state='cancelled',cancelled_at=now() where id='7c440000-0000-4000-8000-000000000001';
select set_config('request.jwt.claim.sub','7c410000-0000-4000-8000-000000000002',true);
set local role authenticated;
select is((select count(*)::integer from public.list_project_role_offers('7c410000-0000-4000-8000-000000000002','7c440000-0000-4000-8000-000000000001')),0,'cancelled Project offers are not presented as actionable');
select throws_ok($$select public.accept_project_role_offer('7c410000-0000-4000-8000-000000000002',current_setting('test.offer')::uuid)$$,'55000',null,'cancelled Project cannot activate offered authority');
reset role;
select * from finish();
rollback;
