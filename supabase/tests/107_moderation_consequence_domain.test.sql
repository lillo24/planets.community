begin;
select no_plan();
insert into auth.users(id,email) select format('fc100000-0000-4000-8000-%s', lpad(n::text,12,'0'))::uuid,
  'consequence-' || n || '@planets.invalid' from generate_series(1,5) as n;
insert into public.profiles(id,display_name) select id, 'Consequence fixture' from auth.users
  where id::text like 'fc100000-%';
insert into private.moderation_staff_roles(profile_id,staff_role) values
  ('fc100000-0000-4000-8000-000000000001','moderator'), ('fc100000-0000-4000-8000-000000000002','admin');
insert into private.moderation_cases(id,state,subject_profile_id,target_kind,target_profile_id,completed_at) values
  ('fc200000-0000-4000-8000-000000000001','received','fc100000-0000-4000-8000-000000000003','profile','fc100000-0000-4000-8000-000000000003',null),
  ('fc200000-0000-4000-8000-000000000002','under_review','fc100000-0000-4000-8000-000000000003','profile','fc100000-0000-4000-8000-000000000003',null),
  ('fc200000-0000-4000-8000-000000000003','completed','fc100000-0000-4000-8000-000000000003','profile','fc100000-0000-4000-8000-000000000003',statement_timestamp());
set local role authenticated;
set local request.jwt.claim.sub = 'fc100000-0000-4000-8000-000000000003';
select throws_ok($$select public.apply_moderation_consequence('fc100000-0000-4000-8000-000000000003','fc200000-0000-4000-8000-000000000002','safety_notice','Reason','Internal')$$,'42501',null,'Ordinary subject cannot apply');
set local request.jwt.claim.sub = 'fc100000-0000-4000-8000-000000000001';
select throws_ok($$select public.apply_moderation_consequence('fc100000-0000-4000-8000-000000000002','fc200000-0000-4000-8000-000000000002','safety_notice','Reason','Internal')$$,'42501',null,'Expected identity is bound');
select throws_ok($$select public.apply_moderation_consequence('fc100000-0000-4000-8000-000000000001','fc200000-0000-4000-8000-000000000001','safety_notice','Reason','Internal')$$,'PT409',null,'Received case cannot apply');
select throws_ok($$select public.apply_moderation_consequence('fc100000-0000-4000-8000-000000000001','fc200000-0000-4000-8000-000000000002','safety_notice','   ','Internal')$$,'22023',null,'Blank user reason denied');
select throws_ok($$select public.apply_moderation_consequence('fc100000-0000-4000-8000-000000000001','fc200000-0000-4000-8000-000000000002','safety_notice',repeat('a',2001),'Internal')$$,'22023',null,'Oversized user reason denied');
select throws_ok($$select public.apply_moderation_consequence('fc100000-0000-4000-8000-000000000001','fc200000-0000-4000-8000-000000000002','safety_notice','Reason',' ')$$,'22023',null,'Blank internal note denied');
select throws_ok($$select public.apply_moderation_consequence('fc100000-0000-4000-8000-000000000001','fc200000-0000-4000-8000-000000000002','safety_notice','Reason',repeat('a',4001))$$,'22023',null,'Oversized internal note denied');
select throws_ok($$select public.apply_moderation_consequence('fc100000-0000-4000-8000-000000000001','fc200000-0000-4000-8000-000000000002','content_hide','Reason','Internal')$$,'22023',null,'Profile cannot be content-hidden');
create temporary table episode as select public.apply_moderation_consequence(
  'fc100000-0000-4000-8000-000000000001','fc200000-0000-4000-8000-000000000002','safety_notice', E' \nPrivate user reason\t ', ' Private internal note ') as id;
select throws_ok($$select public.apply_moderation_consequence('fc100000-0000-4000-8000-000000000001','fc200000-0000-4000-8000-000000000003','safety_notice','Reason','Internal')$$,'PT409',null,'Second case cannot duplicate active episode');
reset role;
select ok(private.profile_has_active_safety_notice('fc100000-0000-4000-8000-000000000003'),'Safety notice active');
select ok(not private.profile_has_active_interaction_restriction('fc100000-0000-4000-8000-000000000003'),'Safety notice has no restriction');
select is((select state from private.moderation_cases where id = 'fc200000-0000-4000-8000-000000000002'),'under_review','Apply leaves case review unchanged');
select is((select user_reason from private.moderation_consequence_actions where consequence_id = (select id from episode)),'Private user reason','Trimmed user reason');
select is((select count(*)::int from private.moderation_consequences where affected_profile_id = 'fc100000-0000-4000-8000-000000000003'),1,'Failed commands leave no partial episodes');
select is((select count(*)::int from private.moderation_case_notes where case_id = 'fc200000-0000-4000-8000-000000000002'),1,'Failed commands leave no partial notes');
select throws_ok($$delete from private.moderation_consequences where id = (select id from episode)$$,'55000',null,'Episode cannot be deleted');
select throws_ok($$update private.moderation_consequence_actions set user_reason = 'Changed' where consequence_id = (select id from episode)$$,'55000',null,'Actions cannot be rewritten');
select throws_ok($$insert into private.moderation_consequences(case_id,consequence_type,affected_profile_id) values('fc200000-0000-4000-8000-000000000002','suspension','fc100000-0000-4000-8000-000000000003')$$,'23514',null,'Suspension is excluded');
select throws_ok($$insert into private.moderation_consequences(case_id,consequence_type,affected_profile_id) values('fc200000-0000-4000-8000-000000000002','content_hide','fc100000-0000-4000-8000-000000000003')$$,'23514',null,'Content target required');
set local role authenticated;
set local request.jwt.claim.sub = 'fc100000-0000-4000-8000-000000000003';
select is((select apply_reason from public.list_own_moderation_consequences('fc100000-0000-4000-8000-000000000003')),'Private user reason','Subject owns user-facing reason');
select is((select count(*)::int from public.get_public_profile('fc100000-0000-4000-8000-000000000003')),1,'Safety notice preserves public profile');
select throws_ok($$select * from public.list_own_moderation_consequences('fc100000-0000-4000-8000-000000000004')$$,'42501',null,'Own read rejects identity mismatch');
select throws_ok($$select * from public.list_own_moderation_consequences('fc100000-0000-4000-8000-000000000003',0)$$,'22023',null,'Own history rejects an unbounded/invalid page');
select throws_ok($$select * from public.list_own_moderation_consequences('fc100000-0000-4000-8000-000000000003',20,statement_timestamp(),null)$$,'22023',null,'Own history requires a complete cursor');
select throws_ok($$select * from public.list_moderation_case_consequence_history('fc100000-0000-4000-8000-000000000003','fc200000-0000-4000-8000-000000000002')$$,'42501',null,'Subject cannot read staff history');
set local request.jwt.claim.sub = 'fc100000-0000-4000-8000-000000000004';
select is_empty($$select * from public.list_own_moderation_consequences('fc100000-0000-4000-8000-000000000004')$$,'Unrelated user sees no history');
set local request.jwt.claim.sub = 'fc100000-0000-4000-8000-000000000002';
select throws_ok($$select public.revoke_moderation_consequence('fc100000-0000-4000-8000-000000000002',(select id from episode),' ','Internal')$$,'22023',null,'Revoke reason required');
select throws_ok($$select public.revoke_moderation_consequence('fc100000-0000-4000-8000-000000000002',(select id from episode),'Revoke',' ')$$,'22023',null,'Revoke note required');
select is(public.revoke_moderation_consequence('fc100000-0000-4000-8000-000000000002',(select id from episode),'Revocation reason','Private revoke note'),(select id from episode),'Admin revokes stable episode');
select throws_ok($$select public.revoke_moderation_consequence('fc100000-0000-4000-8000-000000000002',(select id from episode),'Again','Internal')$$,'PT409',null,'Closed episode cannot be revoked twice');
create temporary table reapplied as select public.apply_moderation_consequence('fc100000-0000-4000-8000-000000000002','fc200000-0000-4000-8000-000000000003','safety_notice','New episode','New private note') as id;
select isnt((select id from reapplied),(select id from episode),'Reapply from completed case creates a new episode');
select is((select count(*)::int from public.list_moderation_case_consequence_history('fc100000-0000-4000-8000-000000000002','fc200000-0000-4000-8000-000000000002')),2,'Current admin reads both immutable case actions');
reset role;
select is((select state from private.moderation_cases where id='fc200000-0000-4000-8000-000000000003'),'completed','Apply from completed case leaves completion unchanged');
select throws_ok($$update private.moderation_consequences set revoked_at = null where id = (select id from episode)$$,'55000',null,'Historical episode cannot reopen');
select is((select count(*)::int from private.moderation_consequence_actions where consequence_id = (select id from episode)),2,'Apply/revoke preserved');
select ok(not exists(select 1 from private.audit_events where metadata::text like '%Private user reason%' or metadata::text like '%Private internal note%'),'Audit carries no reason/note bodies');
select ok(not exists(select 1 from private.outbox_events where payload::text like '%Private user reason%' or payload::text like '%Private internal note%'),'Outbox carries no reason/note bodies');
select is((select count(*)::int from private.outbox_events where event_type like 'moderation.safety_notice_%'),3,'Dedicated apply/revoke source events');
update private.moderation_staff_roles set is_active = false, deactivated_at = statement_timestamp() where profile_id = 'fc100000-0000-4000-8000-000000000001';
set local role authenticated;
set local request.jwt.claim.sub = 'fc100000-0000-4000-8000-000000000001';
select throws_ok($$select public.apply_moderation_consequence('fc100000-0000-4000-8000-000000000001','fc200000-0000-4000-8000-000000000002','interaction_restriction','Reason','Internal')$$,'42501',null,'Revoked staff cannot apply');
select throws_ok($$select public.revoke_moderation_consequence('fc100000-0000-4000-8000-000000000001',(select id from reapplied),'Reason','Internal')$$,'42501',null,'Revoked staff cannot revoke');
select * from finish();
rollback;
