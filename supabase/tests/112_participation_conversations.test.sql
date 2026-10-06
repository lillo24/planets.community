begin;
select no_plan();
select ok(has_function_privilege('authenticated', 'private.profile_can_receive_participation_conversation_topic(text)', 'execute'), 'the strict pair topic predicate is callable by its RLS policy');

insert into auth.users(id,email) values
 ('fa010000-0000-4000-8000-000000000001','msg01-creator@planets.invalid'),
 ('fa010000-0000-4000-8000-000000000002','msg01-requester@planets.invalid'),
 ('fa010000-0000-4000-8000-000000000003','msg01-delegate@planets.invalid'),
 ('fa010000-0000-4000-8000-000000000004','msg01-unrelated@planets.invalid');
insert into public.profiles(id,display_name)
 select id,'Synthetic pair endpoint' from auth.users where email like 'msg01-%@planets.invalid';
insert into public.profile_photos(profile_id,object_path,audience)
 select id,id::text||'/fa010000-0000-4000-8000-000000000010.webp','interactions'
 from public.profiles where id::text like 'fa010000%';
insert into public.proposals(id,creator_profile_id,lifecycle_state,title,starts_at,ends_at,published_at) values
 ('fa020000-0000-4000-8000-000000000001','fa010000-0000-4000-8000-000000000001','published','MSG01 first',now()+interval '1 day',now()+interval '2 days',now()),
 ('fa020000-0000-4000-8000-000000000002','fa010000-0000-4000-8000-000000000001','published','MSG01 second',now()+interval '1 day',now()+interval '2 days',now()),
 ('fa020000-0000-4000-8000-000000000003','fa010000-0000-4000-8000-000000000002','published','MSG01 opposite',now()+interval '1 day',now()+interval '2 days',now());
insert into public.recurring_activities(id,creator_profile_id,lifecycle_state,title,published_at) values
 ('fa020000-0000-4000-8000-000000000004','fa010000-0000-4000-8000-000000000001','published','MSG01 Tavolo',now());
create temporary table msg01_requests(request_id uuid,project_id uuid,chat_id uuid);
grant all on msg01_requests to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','fa010000-0000-4000-8000-000000000002',true);
insert into msg01_requests(request_id,project_id)
 select public.request_to_join_project('fa010000-0000-4000-8000-000000000002',p,'Original note'),p
 from unnest(array['fa020000-0000-4000-8000-000000000001'::uuid,'fa020000-0000-4000-8000-000000000002','fa020000-0000-4000-8000-000000000004']) p;
select set_config('request.jwt.claim.sub','fa010000-0000-4000-8000-000000000001',true);
insert into msg01_requests(request_id,project_id) values
 (public.request_to_join_project('fa010000-0000-4000-8000-000000000001','fa020000-0000-4000-8000-000000000003','Reverse note'),'fa020000-0000-4000-8000-000000000003');
update msg01_requests f set chat_id=(select c.chat_id from public.get_own_participation_conversation('fa010000-0000-4000-8000-000000000001',f.request_id)c);
select is((select count(distinct chat_id) from msg01_requests),1::bigint,'Projects, Tavolo and opposite-direction requests share one immutable pair');
select is((select count(*) from public.list_own_scoped_conversation_items('fa010000-0000-4000-8000-000000000001','private',1)),1::bigint,'pair grouping precedes the server limit');
select is((select c.pending_count from public.get_own_participation_conversation('fa010000-0000-4000-8000-000000000001',(select request_id from msg01_requests limit 1))c),4,'canonical total includes both request directions');
select is((select count(*) from public.list_own_participation_conversation_items('fa010000-0000-4000-8000-000000000001',(select chat_id from msg01_requests limit 1),50)),4::bigint,'each canonical request is one feed item');
select lives_ok($$select * from public.send_participation_conversation_message('fa010000-0000-4000-8000-000000000001',(select chat_id from msg01_requests limit 1),'Pair-only follow-up')$$,'Creator endpoint sends to the pair');
select is((select count(*) from public.get_own_participation_conversation_requests('fa010000-0000-4000-8000-000000000001',(select chat_id from msg01_requests limit 1),array[(select request_id from msg01_requests where project_id='fa020000-0000-4000-8000-000000000001')])),1::bigint,'exact old request context requires no full history load');
select throws_ok($$select * from public.list_own_participation_conversation_items('fa010000-0000-4000-8000-000000000001',(select chat_id from msg01_requests limit 1),51)$$,'22023',null,'unbounded pages fail');
select throws_ok($$select * from public.list_own_participation_conversation_items('fa010000-0000-4000-8000-000000000001',(select chat_id from msg01_requests limit 1),10,now(),null,null)$$,'22023',null,'partial mixed-kind cursors fail');
select throws_ok($$select * from public.participation_conversation_messages$$,'42501',null,'clients cannot bypass pair message authorization');
select set_config('test.msg01.delegate_token',(select invite_token from public.create_project_delegate_invitation('fa010000-0000-4000-8000-000000000001','fa020000-0000-4000-8000-000000000001')),true);
select set_config('request.jwt.claim.sub','fa010000-0000-4000-8000-000000000003',true);
select set_config('test.msg01.delegate',public.accept_project_delegate_invitation('fa010000-0000-4000-8000-000000000003',current_setting('test.msg01.delegate_token'))::text,true);
select is((select count(*) from public.list_project_join_requests_for_manager('fa010000-0000-4000-8000-000000000003','fa020000-0000-4000-8000-000000000001')),1::bigint,'active delegate retains exact request management');
select throws_ok($$select * from public.get_own_participation_conversation('fa010000-0000-4000-8000-000000000003',(select request_id from msg01_requests limit 1))$$,'42501',null,'active manager cannot open a personal pair');
select throws_ok($$select * from public.get_own_project_join_request_chat('fa010000-0000-4000-8000-000000000003',(select request_id from msg01_requests where project_id='fa020000-0000-4000-8000-000000000001'))$$,'42501',null,'legacy exact RPC has no manager back door');
select throws_ok($$select * from public.send_participation_conversation_message('fa010000-0000-4000-8000-000000000003',(select chat_id from msg01_requests limit 1),'No access')$$,'42501',null,'delegate cannot send personal text');
select is((select count(*) from public.list_own_scoped_conversation_items('fa010000-0000-4000-8000-000000000003','private',50)),0::bigint,'delegate gets no personal preview');
-- Actual legacy author/context remains visible to the pair, never relabelled.
reset role;
insert into public.project_join_request_chat_messages(chat_id,sender_profile_id,body,created_at)
 select c.id,'fa010000-0000-4000-8000-000000000003','Retained earlier organizer reply',r.created_at
 from public.project_join_request_chats c join public.project_join_requests r on r.id=c.request_id
 where r.id=(select request_id from msg01_requests where project_id='fa020000-0000-4000-8000-000000000001');
select ok(not private.profile_can_access_project_join_request_chat((select c.id from public.project_join_request_chats c where c.request_id=(select request_id from msg01_requests limit 1)),'fa010000-0000-4000-8000-000000000003'),'legacy history permission is endpoint-only');
select ok(not exists(select 1 from realtime.messages where topic like '%:profile:fa010000-0000-4000-8000-000000000003' and event='participation.conversation_changed'),'no new personal broadcast addresses a delegate socket');
select ok(not has_function_privilege('anon','public.get_own_participation_conversation(uuid,uuid)','execute'),'anonymous callers have no pair RPC grant');
select throws_ok($$update public.participation_conversations set upper_profile_id='fa010000-0000-4000-8000-000000000004'$$,'55000',null,'pair endpoints are immutable');
select throws_ok($$update public.participation_conversation_messages set body='Reassigned'$$,'55000',null,'new messages are immutable');
set local role authenticated;
select set_config('request.jwt.claim.sub','fa010000-0000-4000-8000-000000000001',true);
select is((select sender_profile_id from public.list_own_participation_conversation_items('fa010000-0000-4000-8000-000000000001',(select chat_id from msg01_requests limit 1),50)where item_kind='legacy_message'),'fa010000-0000-4000-8000-000000000003'::uuid,'legacy replies retain the actual delegate author');
select is((select request_id from public.list_own_participation_conversation_items('fa010000-0000-4000-8000-000000000001',(select chat_id from msg01_requests limit 1),50)where item_kind='message'),null::uuid,'new free text has no invented request provenance');
select public.reject_project_join_request_as_manager('fa010000-0000-4000-8000-000000000001',(select request_id from msg01_requests where project_id='fa020000-0000-4000-8000-000000000001'));
select lives_ok($$select * from public.send_participation_conversation_message('fa010000-0000-4000-8000-000000000001',(select chat_id from msg01_requests limit 1),'Another pending request keeps this writable')$$,'resolving one request preserves other pending entitlement');
select public.reject_project_join_request_as_manager('fa010000-0000-4000-8000-000000000001',request_id)from msg01_requests where project_id in('fa020000-0000-4000-8000-000000000002','fa020000-0000-4000-8000-000000000004');
select public.withdraw_project_join_request('fa010000-0000-4000-8000-000000000001',(select request_id from msg01_requests where project_id='fa020000-0000-4000-8000-000000000003'));
select throws_ok($$select * from public.send_participation_conversation_message('fa010000-0000-4000-8000-000000000001',(select chat_id from msg01_requests limit 1),'Too late')$$,'PT409',null,'final resolution closes sending');
select set_config('request.jwt.claim.sub','fa010000-0000-4000-8000-000000000002',true);
select set_config('test.msg01.new_request',public.request_to_join_project('fa010000-0000-4000-8000-000000000002','fa020000-0000-4000-8000-000000000002','New episode')::text,true);
select is((select chat_id from public.get_own_participation_conversation('fa010000-0000-4000-8000-000000000002',current_setting('test.msg01.new_request')::uuid)),(select chat_id from msg01_requests limit 1),'fresh request reuses and reactivates the same conversation');
select is((select count(*) from public.list_own_participation_conversation_items('fa010000-0000-4000-8000-000000000002',(select chat_id from msg01_requests limit 1),50)where item_kind='request'),5::bigint,'repeated request remains a separate bubble');
-- A failed enclosing transaction cannot leave a request, association or pair.
do $$ declare rollback_request uuid; begin
  perform set_config('request.jwt.claim.sub','fa010000-0000-4000-8000-000000000004',true);
  rollback_request := public.request_to_join_project('fa010000-0000-4000-8000-000000000004','fa020000-0000-4000-8000-000000000001','Synthetic rollback');
  if not exists (select 1 from public.get_own_participation_conversation('fa010000-0000-4000-8000-000000000004',rollback_request)) then
    raise exception using errcode='55000', message='Rollback fixture did not establish its association.';
  end if;
  raise exception 'intentional enclosing transaction failure';
exception when raise_exception then null; end $$;
reset role;
select ok(not exists(select 1 from public.participation_conversations where 'fa010000-0000-4000-8000-000000000004'::uuid in(lower_profile_id,upper_profile_id)), 'failed request transaction leaves no orphan pair');
select ok(not exists(select 1 from public.participation_conversation_requests a join public.project_join_requests r on r.id=a.request_id where r.requester_profile_id='fa010000-0000-4000-8000-000000000004'), 'failed request transaction leaves no partial association');
select * from finish();
rollback;
