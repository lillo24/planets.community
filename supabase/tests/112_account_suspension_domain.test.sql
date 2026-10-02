begin;
select no_plan();
select is((select array_agg(tablename::text order by tablename) from pg_policies
  where schemaname='public' and policyname='account_active_required'
    and permissive='RESTRICTIVE' and cmd='ALL' and roles=array['authenticated']::name[]
    and qual like '%private.current_account_is_active()%'
    and with_check like '%private.current_account_is_active()%'),
  array['profile_field_visibility','profile_skills','profiles','proposal_meeting_details','proposal_skills','proposals',
    'recurring_activities','recurring_activity_meeting_details','recurring_activity_schedules'],
  'All nine direct private surfaces require the restrictive account gate for reads and writes');
select ok(exists(select 1 from pg_policies where schemaname='realtime' and tablename='messages'
  and policyname='account_active_required' and permissive='RESTRICTIVE' and cmd='SELECT'
  and roles=array['authenticated']::name[] and qual like '%private.current_account_is_active()%'),
  'Private Realtime receives require the restrictive account gate');
select ok(pg_get_functiondef('private.send_account_active_realtime(jsonb,text,text,boolean)'::regprocedure)
  like '%private.profile_has_active_account_suspension(recipient_id)%'
  and pg_get_functiondef('private.send_account_active_realtime(jsonb,text,text,boolean)'::regprocedure)
  like '%realtime.send%', 'Canonical Broadcast wrapper checks suspension before publication');
select ok(not has_function_privilege('authenticated','private.send_account_active_realtime(jsonb,text,text,boolean)','execute'),
  'Clients cannot bypass broadcasters through the recipient wrapper');
insert into auth.users(id,email) select format('fb100000-0000-4000-8000-%s', lpad(n::text,12,'0'))::uuid,
  'suspension-' || n || '@planets.invalid' from generate_series(1,6) as n;
insert into public.profiles(id,display_name) select id, 'Suspension fixture' from auth.users
  where id::text like 'fb100000-%' and id <> 'fb100000-0000-4000-8000-000000000006';
insert into private.moderation_staff_roles(profile_id,staff_role) values
  ('fb100000-0000-4000-8000-000000000001','admin'),
  ('fb100000-0000-4000-8000-000000000002','moderator'),
  ('fb100000-0000-4000-8000-000000000004','admin');
insert into private.moderation_cases(id,state,subject_profile_id,target_kind,target_profile_id) values
  ('fb200000-0000-4000-8000-000000000001','under_review','fb100000-0000-4000-8000-000000000003','profile','fb100000-0000-4000-8000-000000000003'),
  ('fb200000-0000-4000-8000-000000000002','received','fb100000-0000-4000-8000-000000000003','profile','fb100000-0000-4000-8000-000000000003'),
  ('fb200000-0000-4000-8000-000000000003','under_review','fb100000-0000-4000-8000-000000000001','profile','fb100000-0000-4000-8000-000000000001');
set local role authenticated;
set local request.jwt.claim.sub = 'fb100000-0000-4000-8000-000000000002';
select throws_ok($$select public.apply_account_suspension('fb100000-0000-4000-8000-000000000002','fb200000-0000-4000-8000-000000000001','Reason','Internal')$$,'42501',null,'Moderator cannot suspend');
set local request.jwt.claim.sub = 'fb100000-0000-4000-8000-000000000003';
select throws_ok($$select public.apply_account_suspension('fb100000-0000-4000-8000-000000000003','fb200000-0000-4000-8000-000000000001','Reason','Internal')$$,'42501',null,'Ordinary identity cannot suspend');
set local request.jwt.claim.sub = 'fb100000-0000-4000-8000-000000000001';
select throws_ok($$select public.apply_account_suspension('fb100000-0000-4000-8000-000000000001','fb200000-0000-4000-8000-000000000003','Reason','Internal')$$,'42501',null,'Admin cannot self-suspend');
select throws_ok($$select public.apply_account_suspension('fb100000-0000-4000-8000-000000000001','fb200000-0000-4000-8000-000000000002','Reason','Internal')$$,'PT409',null,'Received case is insufficient');
select throws_ok($$select public.apply_account_suspension('fb100000-0000-4000-8000-000000000001','fb200000-0000-4000-8000-000000000001',' ','Internal')$$,'22023',null,'Blank reason denied');
select throws_ok($$select public.apply_account_suspension('fb100000-0000-4000-8000-000000000001','fb200000-0000-4000-8000-000000000001',repeat('x',2001),'Internal')$$,'22023',null,'Oversized reason denied');
select throws_ok($$select public.apply_account_suspension('fb100000-0000-4000-8000-000000000001','fb200000-0000-4000-8000-000000000001','Reason',' ')$$,'22023',null,'Blank note denied');
select throws_ok($$select public.apply_account_suspension('fb100000-0000-4000-8000-000000000001','fb200000-0000-4000-8000-000000000001','Reason',repeat('x',4001))$$,'22023',null,'Oversized note denied');
create temporary table episode as select public.apply_account_suspension(
  'fb100000-0000-4000-8000-000000000001','fb200000-0000-4000-8000-000000000001', E' \nSafe subject reason\t ', 'Private suspension note') as id;
select throws_ok($$select public.apply_account_suspension('fb100000-0000-4000-8000-000000000001','fb200000-0000-4000-8000-000000000001','Reason','Internal')$$,'PT409',null,'Only one active episode per subject');
set local request.jwt.claim.sub = 'fb100000-0000-4000-8000-000000000002';
select throws_ok($$select public.revoke_account_suspension('fb100000-0000-4000-8000-000000000002',(select id from episode),'Reason','Internal')$$,'42501',null,'Moderator cannot unsuspend');
select throws_ok($$select public.revoke_moderation_consequence('fb100000-0000-4000-8000-000000000002',(select id from episode),'Reason','Internal')$$,'42501',null,'Generic revoke cannot bypass admin boundary');
set local request.jwt.claim.sub = 'fb100000-0000-4000-8000-000000000003';
select is((select consequence_id from public.get_own_account_suspension_status('fb100000-0000-4000-8000-000000000003')),(select id from episode),'Own exception returns active stable ID');
select is((select user_reason from public.get_own_account_suspension_status('fb100000-0000-4000-8000-000000000003')),'Safe subject reason','Own exception returns trimmed user reason');
select is((select array_agg(key order by key) from jsonb_object_keys((select to_jsonb(status) from public.get_own_account_suspension_status('fb100000-0000-4000-8000-000000000003') as status)) as key),array['applied_at','consequence_id','is_suspended','user_reason'],'Status has exactly four safe fields');
select throws_ok($$select * from public.get_own_account_suspension_status('fb100000-0000-4000-8000-000000000005')$$,'42501',null,'Own status is expected-identity bound');
select throws_ok($$select * from public.list_own_moderation_consequences('fb100000-0000-4000-8000-000000000003')$$,'PT403',null,'Ordinary consequence history not allowlisted');
select throws_ok($$select public.update_own_profile('fb100000-0000-4000-8000-000000000003','Changed',null,'{}','public','private','private')$$,'PT403',null,'Invoker profile edit gated');
select throws_ok($$select * from public.list_own_notifications('fb100000-0000-4000-8000-000000000003')$$,'PT403',null,'Notification inbox gated');
select throws_ok($$select * from public.list_own_notification_preferences('fb100000-0000-4000-8000-000000000003')$$,'PT403',null,'Notification preferences gated');
select throws_ok($$select * from public.list_own_moderation_reports('fb100000-0000-4000-8000-000000000003')$$,'PT403',null,'Ordinary moderation reads gated');
select throws_ok($$select * from public.list_own_moderation_evidence_requests('fb100000-0000-4000-8000-000000000003')$$,'PT403',null,'Evidence not allowlisted');
select throws_ok($$select * from public.list_own_blocked_profiles('fb100000-0000-4000-8000-000000000003')$$,'PT403',null,'Blocking reads gated');
select throws_ok($$select * from public.get_own_profile_photo('fb100000-0000-4000-8000-000000000003')$$,'PT403',null,'Private media metadata gated');
select is_empty($$select * from public.profiles$$,'Direct private profile read gated by restrictive RLS');
select is_empty($$update public.profiles set display_name='Changed' where id='fb100000-0000-4000-8000-000000000003' returning id$$,'Direct profile edit cannot bypass RLS');
reset role;
select is((select display_name from public.profiles where id='fb100000-0000-4000-8000-000000000003'),'Suspension fixture','Profile preserved');
select is((select count(*)::int from private.moderation_cases where id='fb200000-0000-4000-8000-000000000001' and state='under_review'),1,'Case state unchanged');
select ok(not exists(select 1 from private.audit_events where metadata::text like '%Safe subject reason%' or metadata::text like '%Private suspension note%'),'Audit has no sensitive bodies');
select ok(not exists(select 1 from private.outbox_events where payload::text like '%Safe subject reason%' or payload::text like '%Private suspension note%'),'Outbox has no sensitive bodies');
select is((select count(*)::int from private.outbox_events where event_type='moderation.account_suspension_applied'),1,'Dedicated identifier-only source event');
select throws_ok($$delete from private.moderation_consequences where id=(select id from episode)$$,'55000',null,'Suspension history immutable');
select ok(not has_function_privilege('authenticated','private.profile_has_active_account_suspension(uuid)','execute'),'Arbitrary-subject predicate not exposed');
set local role anon;
select throws_ok($$select * from public.get_own_account_suspension_status('fb100000-0000-4000-8000-000000000003')$$,'42501',null,'Anonymous cannot read status');
select is((select count(*)::int from public.get_public_profile('fb100000-0000-4000-8000-000000000003')),1,'Suspension is not public content-hide');
set local role authenticated;
set local request.jwt.claim.sub = 'fb100000-0000-4000-8000-000000000006';
select is((select is_suspended from public.get_own_account_suspension_status('fb100000-0000-4000-8000-000000000006')),false,'New Auth user without anchor safely inactive');
set local request.jwt.claim.sub = 'fb100000-0000-4000-8000-000000000001';
select throws_ok($$select public.revoke_account_suspension('fb100000-0000-4000-8000-000000000001',(select id from episode),' ','Internal')$$,'22023',null,'Revoke reason required');
select throws_ok($$select public.revoke_account_suspension('fb100000-0000-4000-8000-000000000001',(select id from episode),'Reason',' ')$$,'22023',null,'Revoke note required');
select is(public.revoke_account_suspension('fb100000-0000-4000-8000-000000000001',(select id from episode),'Access restored','Private revocation note'),(select id from episode),'Admin revokes stable episode');
select throws_ok($$select public.revoke_account_suspension('fb100000-0000-4000-8000-000000000001',(select id from episode),'Again','Internal')$$,'PT409',null,'Revoked episode cannot reopen');
create temporary table reapplied as select public.apply_account_suspension('fb100000-0000-4000-8000-000000000001','fb200000-0000-4000-8000-000000000001','New reason','Internal') as id;
select isnt((select id from episode),(select id from reapplied),'Reapply creates distinct episode');
select is(public.revoke_account_suspension('fb100000-0000-4000-8000-000000000001',(select id from reapplied),'Restored','Internal'),(select id from reapplied),'Reapplied episode revocable');
set local request.jwt.claim.sub = 'fb100000-0000-4000-8000-000000000003';
select is((select is_suspended from public.get_own_account_suspension_status('fb100000-0000-4000-8000-000000000003')),false,'Revoke restores safe inactive status');
select lives_ok($$select * from public.list_own_notifications('fb100000-0000-4000-8000-000000000003')$$,'Ordinary access restored');
reset role;
select is((select count(*)::int from private.moderation_consequence_actions where consequence_id=(select id from episode)),2,'Apply and revoke both retained');
update private.moderation_staff_roles set is_active=false, deactivated_at=clock_timestamp()
  where profile_id='fb100000-0000-4000-8000-000000000004';
set local role authenticated;
set local request.jwt.claim.sub = 'fb100000-0000-4000-8000-000000000004';
select throws_ok($$select public.apply_account_suspension('fb100000-0000-4000-8000-000000000004','fb200000-0000-4000-8000-000000000001','Reason','Internal')$$,'42501',null,'Inactive admin cannot suspend');
reset role;
-- Simulate incomplete trusted SQL history, not a valid API-created episode.
insert into private.moderation_consequences(case_id,consequence_type,affected_profile_id)
  values('fb200000-0000-4000-8000-000000000001','account_suspension','fb100000-0000-4000-8000-000000000005');
set local role authenticated;
set local request.jwt.claim.sub = 'fb100000-0000-4000-8000-000000000005';
select throws_ok($$select * from public.get_own_account_suspension_status('fb100000-0000-4000-8000-000000000005')$$,'55000',null,'Incomplete suspension history fails closed rather than inactive');
reset role;
select * from finish();
rollback;
