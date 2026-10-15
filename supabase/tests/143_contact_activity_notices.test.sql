begin;
select no_plan();

create function pg_temp.person(n integer) returns uuid language sql as $$
 select ('d1430000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid $$;
create function pg_temp.grp(n integer) returns uuid language sql as $$
 select ('d1431000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid $$;
insert into auth.users(id,email) select pg_temp.person(n),'d-notice-'||n||'@planets.invalid' from generate_series(1,31) n;
insert into public.profiles(id,display_name) select pg_temp.person(n),'Fictional notice person '||n from generate_series(1,31) n;
insert into private.community_groups(id,name,description,group_kind,volunteering_focus,publication_state,original_actor_id)
select pg_temp.grp(n),'Fictional notice group '||n,'Synthetic notice authorization fixture.','informal',false,'published',pg_temp.person(n) from generate_series(1,2) n;
insert into private.community_group_managers(group_id,profile_id,appointed_by_actor_id)
select pg_temp.grp(n),pg_temp.person(n),pg_temp.person(n) from generate_series(1,2) n;
insert into private.group_delegates(group_id,profile_id,initial_role,delegate_role,granted_by)
select pg_temp.grp(2),pg_temp.person(n),'co_organizer','co_organizer',pg_temp.person(2) from generate_series(3,30) n;
insert into public.profile_notification_preferences(profile_id,category_slug,in_app_enabled,push_enabled)
values(pg_temp.person(30),'participation',false,false);
create temp table notice_result(kind text primary key,value jsonb);
grant all on notice_result to authenticated;
create function pg_temp.result(kind text,key text) returns uuid language sql as $$
select (value->>key)::uuid from notice_result r where r.kind=$1 $$;
grant execute on function pg_temp.person(integer),pg_temp.grp(integer),pg_temp.result(text,text) to authenticated;

set local role authenticated;
select set_config('request.jwt.claim.sub',pg_temp.person(1)::text,true);
insert into notice_result values('request',public.submit_group_contact_request(pg_temp.person(1),gen_random_uuid(),pg_temp.grp(1),pg_temp.grp(2),'collaboration','Private fixture title','Private fixture note.'));
select throws_ok($$select * from private.contact_activity_notifications$$,'42501',null,'direct notice table is inaccessible');
select throws_ok($$select * from public.process_notification_outbox_batch(1)$$,'42501',null,'clients cannot drive projection');
reset role;

select is((select notifications_created from private.process_contact_activity_batch(1)),25,'one page expands at most 25 recipients');
select is((select count(*) from private.contact_activity_progress),1::bigint,'partial fanout retains durable cursor');
select is((select count(*) from private.outbox_consumer_receipts r join private.contact_activity_events e on e.outbox_event_id=r.outbox_event_id where e.target_id=pg_temp.result('request','request_id')),0::bigint,'partial fanout is not marked complete');
select is((select notifications_created from private.process_contact_activity_batch(1)),3,'second page respects recipient in-app opt-out');
select is((select processed_count from private.process_contact_activity_batch(1)),0,'completed fanout is idempotent');
select is((select count(*) from private.contact_activity_notifications where target_id=pg_temp.result('request','request_id')),28::bigint,'eligible target managers receive one row each subject to preferences');
select is((select count(*) from private.contact_activity_notifications where recipient_profile_id in (pg_temp.person(1),pg_temp.person(31))),0::bigint,'sender and outsider are not recipients');
update private.group_delegates set revoked_at=clock_timestamp(),revoked_by=pg_temp.person(2)
where group_id=pg_temp.grp(2) and profile_id=pg_temp.person(3);

set local role authenticated;
select set_config('request.jwt.claim.sub',pg_temp.person(3)::text,true);
select is(public.get_own_unread_notification_count_with_contacts(pg_temp.person(3)),0::bigint,'already-projected notice rechecks revoked recipient access');
select is(jsonb_array_length(public.list_own_notifications_with_contacts(pg_temp.person(3),1)),0,'revocation is filtered before page limit');
select set_config('request.jwt.claim.sub',pg_temp.person(2)::text,true);
select is(public.get_own_unread_notification_count_with_contacts(pg_temp.person(2)),1::bigint,'pending action counts in activity');
select is(jsonb_array_length(public.list_own_notifications_with_contacts(pg_temp.person(2),1)),1,'authorized notice is returned');
select is((public.list_own_notifications_with_contacts(pg_temp.person(2),1)->0)->>'contact_target_id',pg_temp.result('request','request_id')::text,'notice uses typed target');
select ok(not ((public.list_own_notifications_with_contacts(pg_temp.person(2),1)->0) ?| array['body','title','actor_profile_id','source_chat_id','request_message']),'notice discloses no protected body or human/source context');
select is((select count(*) from public.list_own_notifications(pg_temp.person(2),10)),0::bigint,'legacy reader excludes new notice kind');
insert into notice_result values('accepted',public.accept_group_contact_request(pg_temp.person(2),gen_random_uuid(),pg_temp.result('request','request_id')));
select is(public.get_own_unread_notification_count_with_contacts(pg_temp.person(2)),0::bigint,'resolved request disappears before unread count');
select is(jsonb_array_length(public.list_own_notifications_with_contacts(pg_temp.person(2),1)),0,'resolved request disappears before page limit');
select is(public.get_own_group_contact_preferences(pg_temp.person(2),pg_temp.result('accepted','chat_id'))->>'muted','false','new conversation defaults explicitly to unmuted');
select set_config('request.jwt.claim.sub',pg_temp.person(1)::text,true);
select public.send_group_contact_message(pg_temp.person(1),gen_random_uuid(),pg_temp.result('accepted','chat_id'),'An unread synthetic message.');
select set_config('request.jwt.claim.sub',pg_temp.person(2)::text,true);
insert into notice_result values('unread_before',public.get_own_message_unread_summary_v2(pg_temp.person(2)));
select is(((select value from notice_result where kind='unread_before')->>'groups')::integer,1,'incoming message remains genuinely unread before mute');
select is(public.set_group_contact_muted(pg_temp.person(2),'d1432000-0000-4000-8000-000000000001',pg_temp.result('accepted','chat_id'),true)->>'outcome','muted','current participant can mute');
select is(public.set_group_contact_muted(pg_temp.person(2),'d1432000-0000-4000-8000-000000000001',pg_temp.result('accepted','chat_id'),true)->>'replayed','true','lost response retry uses original receipt');
select throws_ok($$select public.set_group_contact_muted(pg_temp.person(2),'d1432000-0000-4000-8000-000000000001',pg_temp.result('accepted','chat_id'),false)$$,'PT409',null,'same action cannot change mute intent');
select is(public.get_own_message_unread_summary_v2(pg_temp.person(2)),(select value from notice_result where kind='unread_before'),'mute does not acknowledge or alter unread');
select set_config('request.jwt.claim.sub',pg_temp.person(3)::text,true);
select throws_ok($$select public.get_own_group_contact_preferences(pg_temp.person(3),pg_temp.result('accepted','chat_id'))$$,'42501',null,'other manager cannot read accepted conversation preference');
select set_config('request.jwt.claim.sub',pg_temp.person(2)::text,true);
reset role;
select ok(not private.group_contact_message_notice_allowed(pg_temp.result('accepted','chat_id'),pg_temp.person(2)),'mute suppresses message alert eligibility');
select ok(private.group_contact_message_notice_allowed(pg_temp.result('accepted','chat_id'),pg_temp.person(1)),'peer preference remains independent');

-- An expired queued source still completes, without creating a success-shaped
-- empty payload or leaving the worker permanently stuck on zero candidates.
set local role authenticated;
select set_config('request.jwt.claim.sub',pg_temp.person(1)::text,true);
select public.close_group_contact_conversation(pg_temp.person(1),gen_random_uuid(),pg_temp.result('accepted','chat_id'));
reset role;
select ok(not private.group_contact_message_notice_allowed(pg_temp.result('accepted','chat_id'),pg_temp.person(1)),'closed read-only history does not receive new-message alerts');
insert into private.outbox_events(event_type,payload) values('contact.activity_requested',jsonb_build_object('kind','group_contact_request','target_id',gen_random_uuid(),'audience_version',0));
select is((select processed_count from private.process_contact_activity_batch(1)),1,'empty recipient page completes safely');
select is((select processed_count from private.process_contact_activity_batch(1)),0,'empty event has a completion receipt');

insert into private.group_memberships(group_id,profile_id,admitted_by) values(pg_temp.grp(1),pg_temp.person(31),pg_temp.person(1));
set local role authenticated;
select set_config('request.jwt.claim.sub',pg_temp.person(1)::text,true);
insert into notice_result values('personal',public.submit_member_contact_request(pg_temp.person(1),gen_random_uuid(),pg_temp.grp(1),pg_temp.person(31),'A private synthetic introduction.'));
reset role;
select is((select notifications_created from private.process_contact_activity_batch(1)),1,'member event projects only its named recipient');
select is((select count(*) from private.contact_activity_notifications where target_id=pg_temp.result('personal','request_id')),1::bigint,'personal notice never expands to managers');
set local role authenticated;
select set_config('request.jwt.claim.sub',pg_temp.person(31)::text,true);
select is(public.get_own_unread_notification_count_with_contacts(pg_temp.person(31)),1::bigint,'member request is actionable activity');
select is((public.get_own_message_unread_summary_v3(pg_temp.person(31))->>'total')::integer,0,'member invitation adds no human-message unread');
reset role;
update private.group_memberships set ended_at=clock_timestamp(),ended_by=profile_id,end_reason='left'
where group_id=pg_temp.grp(1) and profile_id=pg_temp.person(31);
set local role authenticated;
select set_config('request.jwt.claim.sub',pg_temp.person(31)::text,true);
select is(jsonb_array_length(public.list_own_notifications_with_contacts(pg_temp.person(31),1)),0,'member context loss removes projected notice');
select is(public.get_own_unread_notification_count_with_contacts(pg_temp.person(31)),0::bigint,'member context loss removes activity count');
reset role;

select * from finish();
rollback;
