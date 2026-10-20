-- Synthetic review candidate. This is not founder approval of personal lifetime policy.
begin;
select no_plan();
-- Canonical Block keeps Project/Resource closure before the ONE complete sorted
-- Group reservation, and member cleanup runs only after predecessor convergence.
create temp table block_order as select
  pg_get_functiondef('private.close_pending_direct_requests_for_user_block(uuid,uuid)'::regprocedure) outer_body,
  pg_get_functiondef('private.member_contact_previous_block_convergence(uuid,uuid)'::regprocedure) predecessor_body;
select ok(strpos(outer_body,'private.community_groups')=0
  and strpos(outer_body,'perform private.member_contact_previous_block_convergence(')>0
  and strpos(outer_body,'perform private.member_contact_previous_block_convergence(')<strpos(outer_body,'for pair in select'),
  'member Block delegates before pair cleanup and acquires no premature Group lock') from block_order;
select ok(strpos(predecessor_body,'perform private.close_pending_project_resource_requests_for_user_block(')>0
  and strpos(predecessor_body,'perform private.close_pending_project_resource_requests_for_user_block(')<strpos(predecessor_body,'select array_agg(distinct g order by g)'),
  'legacy Project/Resource closure precedes complete Group reservation') from block_order;
select ok(strpos(predecessor_body,'private.group_join_requests')>0
  and strpos(predecessor_body,'private.group_join_requests')<strpos(predecessor_body,') affected;')
  and strpos(predecessor_body,'private.group_contact_requests')>0
  and strpos(predecessor_body,'private.group_contact_requests')<strpos(predecessor_body,') affected;')
  and strpos(predecessor_body,'union all select s.group_id from private.group_coordination_proposals')>0
  and strpos(predecessor_body,'union all select s.group_id from private.group_coordination_proposals')<strpos(predecessor_body,') affected;')
  and strpos(predecessor_body,'union all select p.group_id from private.member_contact_pairs')>0
  and strpos(predecessor_body,'union all select p.group_id from private.member_contact_pairs')<strpos(predecessor_body,') affected;')
  and strpos(predecessor_body,') affected;')<strpos(predecessor_body,'order by g.id for update')
  and strpos(predecessor_body,'order by g.id for update')<strpos(predecessor_body,'perform private.group_contact_legacy_block_convergence('),
  'legacy, representative, coordination and member Groups share the existing sorted reservation') from block_order;
select is((length(predecessor_body)-length(replace(predecessor_body,'select array_agg(distinct g order by g)','')))/length('select array_agg(distinct g order by g)'),
  1,'one complete affected Group union remains the reservation owner') from block_order;
select ok(not has_function_privilege(r,f,'execute'),r||' cannot invoke private Block hook '||f)
from unnest(array['anon','authenticated','service_role']) r
cross join unnest(array['private.close_pending_direct_requests_for_user_block(uuid,uuid)',
  'private.member_contact_previous_block_convergence(uuid,uuid)']) f;
insert into auth.users(id,email) select ('e0500000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'member-tap-'||n||'@planets.invalid' from generate_series(1,7) n;
insert into public.profiles(id,display_name) select id,'Fictional member '||right(id::text,1) from auth.users where email like 'member-tap-%';
insert into private.community_groups(id,name,description,group_kind,volunteering_focus,publication_state,original_actor_id)
select ('e0510000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'Fictional member context '||n,'A fictional shared Group for consent verification.','informal',false,'published','e0500000-0000-4000-8000-000000000001' from generate_series(1,2) n;
insert into private.community_group_managers(group_id,profile_id,appointed_by_actor_id)
select id,original_actor_id,original_actor_id from private.community_groups where id::text like 'e051%';
insert into private.group_memberships(id,group_id,profile_id,admitted_by)
select ('e0520000-0000-4000-8000-'||lpad((g*10+n)::text,12,'0'))::uuid,('e0510000-0000-4000-8000-'||lpad(g::text,12,'0'))::uuid,
  ('e0500000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'e0500000-0000-4000-8000-000000000001' from generate_series(1,2) g cross join generate_series(2,3) n;
insert into private.group_delegates(id,group_id,profile_id,initial_role,delegate_role,granted_by)
values('e0530000-0000-4000-8000-000000000001','e0510000-0000-4000-8000-000000000001','e0500000-0000-4000-8000-000000000004','co_organizer','co_organizer','e0500000-0000-4000-8000-000000000001');
insert into private.group_join_requests(group_id,requester_id) values('e0510000-0000-4000-8000-000000000001','e0500000-0000-4000-8000-000000000006');
insert into private.moderation_staff_roles(profile_id,staff_role) values('e0500000-0000-4000-8000-000000000007','moderator');
create temp table member_result(k text primary key,v jsonb); grant all on member_result to authenticated;
select ok(not has_table_privilege(r,'private.member_contact_messages','select'),r||' has no raw personal message grant') from unnest(array['anon','authenticated','service_role']) r;
select ok(not has_function_privilege(r,'private.member_contact_command(uuid,uuid,text,uuid,jsonb)','execute'),r||' cannot invoke private command') from unnest(array['anon','authenticated','service_role']) r;
select ok(not has_function_privilege('anon','public.get_own_member_contact_feed(uuid,uuid,integer,bigint,uuid)','execute'),'guest cannot read personal feed');
select ok(not exists(select 1 from pg_constraint where conrelid in(select oid from pg_class where relnamespace='private'::regnamespace and relname like 'member_contact_%') and contype='f' and confrelid in('auth.users'::regclass,'public.profiles'::regclass)),'no new account erasure blockers');
set local role authenticated;
select set_config('request.jwt.claim.sub','e0500000-0000-4000-8000-000000000002',true);
select is(public.get_own_member_contact_context('e0500000-0000-4000-8000-000000000002','e0510000-0000-4000-8000-000000000001','e0500000-0000-4000-8000-000000000003')->>'can_request','true','ordinary People pair can request');
select throws_ok($$select public.get_own_member_contact_context('e0500000-0000-4000-8000-000000000001','e0510000-0000-4000-8000-000000000001','e0500000-0000-4000-8000-000000000003')$$,'42501',null,'expected actor cannot be spoofed');
select throws_ok($$select public.submit_member_contact_request('e0500000-0000-4000-8000-000000000002',gen_random_uuid(),'e0510000-0000-4000-8000-000000000001','e0500000-0000-4000-8000-000000000005')$$,'42501',null,'arbitrary outsider ID denied');
select throws_ok($$select public.submit_member_contact_request('e0500000-0000-4000-8000-000000000002',gen_random_uuid(),'e0510000-0000-4000-8000-000000000001','e0500000-0000-4000-8000-000000000006')$$,'42501',null,'pending Group applicant denied');
select throws_ok($$select public.submit_member_contact_request('e0500000-0000-4000-8000-000000000002',gen_random_uuid(),'e0510000-0000-4000-8000-000000000001','e0500000-0000-4000-8000-000000000002')$$,'42501',null,'self contact denied');
select throws_ok($$select public.submit_member_contact_request('e0500000-0000-4000-8000-000000000002',gen_random_uuid(),'e0510000-0000-4000-8000-000000000001','e0500000-0000-4000-8000-000000000003',repeat('x',501))$$,'22023',null,'note bound enforced');
insert into member_result values('request',public.submit_member_contact_request('e0500000-0000-4000-8000-000000000002','e0540000-0000-4000-8000-000000000001','e0510000-0000-4000-8000-000000000001','e0500000-0000-4000-8000-000000000003',' A fictional introduction '));
select is(public.submit_member_contact_request('e0500000-0000-4000-8000-000000000002','e0540000-0000-4000-8000-000000000001','e0510000-0000-4000-8000-000000000001','e0500000-0000-4000-8000-000000000003',' A fictional introduction ')->>'replayed','true','lost submit response recovers exact request');
select throws_ok($$select public.submit_member_contact_request('e0500000-0000-4000-8000-000000000002','e0540000-0000-4000-8000-000000000001','e0510000-0000-4000-8000-000000000001','e0500000-0000-4000-8000-000000000003','A fictional introduction')$$,'PT409',null,'exact intent includes submitted whitespace');
select throws_ok($$select public.accept_member_contact_request('e0500000-0000-4000-8000-000000000002',gen_random_uuid(),(select (v->>'request_id')::uuid from member_result where k='request'))$$,'42501',null,'sender cannot accept own request');
select is(jsonb_array_length(public.list_own_scoped_conversation_items_v7('e0500000-0000-4000-8000-000000000002','private',20)),0,'pending request is not an empty conversation');
select set_config('request.jwt.claim.sub','e0500000-0000-4000-8000-000000000003',true);
select throws_ok($$select public.submit_member_contact_request('e0500000-0000-4000-8000-000000000003',gen_random_uuid(),'e0510000-0000-4000-8000-000000000001','e0500000-0000-4000-8000-000000000002')$$,'PT409',null,'reversed pending request cannot duplicate pair');
select is(public.get_own_member_contact_request('e0500000-0000-4000-8000-000000000003',(select (v->>'request_id')::uuid from member_result where k='request'))->>'request_message','A fictional introduction','named recipient deliberately reads normalized note');
insert into member_result values('request_report',to_jsonb(public.submit_moderation_report('e0500000-0000-4000-8000-000000000003',gen_random_uuid(),'spam','A fictional note report.','member_contact_request',(select (v->>'request_id')::uuid from member_result where k='request'))));
insert into member_result values('chat',public.accept_member_contact_request('e0500000-0000-4000-8000-000000000003','e0540000-0000-4000-8000-000000000002',(select (v->>'request_id')::uuid from member_result where k='request')));
select is(public.accept_member_contact_request('e0500000-0000-4000-8000-000000000003','e0540000-0000-4000-8000-000000000002',(select (v->>'request_id')::uuid from member_result where k='request'))->>'chat_id',(select v->>'chat_id' from member_result where k='chat'),'duplicate accept preserves conversation');
select throws_ok($$select public.accept_member_contact_request('e0500000-0000-4000-8000-000000000003',gen_random_uuid(),(select (v->>'request_id')::uuid from member_result where k='request'))$$,'PT409',null,'new accept after resolution is not another episode');
select set_config('request.jwt.claim.sub','e0500000-0000-4000-8000-000000000001',true);
select throws_ok($$select public.get_own_member_contact_request('e0500000-0000-4000-8000-000000000001',(select (v->>'request_id')::uuid from member_result where k='request'))$$,'42501',null,'Group Creator cannot triage personal requests');
select throws_ok($$select public.get_own_member_contact_conversation('e0500000-0000-4000-8000-000000000001',(select (v->>'chat_id')::uuid from member_result where k='chat'))$$,'42501',null,'Group Creator has no personal history oversight');
select set_config('request.jwt.claim.sub','e0500000-0000-4000-8000-000000000004',true);
select throws_ok($$select public.get_own_member_contact_feed('e0500000-0000-4000-8000-000000000004',(select (v->>'chat_id')::uuid from member_result where k='chat'))$$,'42501',null,'Co-organizer has no personal history oversight');
select set_config('request.jwt.claim.sub','e0500000-0000-4000-8000-000000000007',true);
select throws_ok($$select public.get_own_member_contact_feed('e0500000-0000-4000-8000-000000000007',(select (v->>'chat_id')::uuid from member_result where k='chat'))$$,'42501',null,'staff cannot browse personal history');
select is(public.get_moderation_case_group_contact('e0500000-0000-4000-8000-000000000007',(select (v->>'case_id')::uuid from member_result where k='request_report'))->>'body','A fictional introduction','staff sees exact reported note only');
select set_config('request.jwt.claim.sub','e0500000-0000-4000-8000-000000000002',true);
insert into member_result values('message',public.send_member_contact_message('e0500000-0000-4000-8000-000000000002','e0540000-0000-4000-8000-000000000003',(select (v->>'chat_id')::uuid from member_result where k='chat'),(select (v->>'episode_id')::uuid from member_result where k='chat'),' First fictional hello '));
select is(public.send_member_contact_message('e0500000-0000-4000-8000-000000000002','e0540000-0000-4000-8000-000000000003',(select (v->>'chat_id')::uuid from member_result where k='chat'),(select (v->>'episode_id')::uuid from member_result where k='chat'),' First fictional hello ')->>'replayed','true','send retry cannot duplicate message');
select is(public.get_own_message_unread_summary_v3('e0500000-0000-4000-8000-000000000002')->>'private','0','sender is never incoming unread');
select set_config('request.jwt.claim.sub','e0500000-0000-4000-8000-000000000003',true);
select is(public.get_own_message_unread_summary_v3('e0500000-0000-4000-8000-000000000003')->>'private','1','personal incoming counts once in Private');
select is(public.get_own_message_unread_summary_v2('e0500000-0000-4000-8000-000000000003')->>'private','0','old client unread excludes unsupported kind');
select is(jsonb_array_length(public.list_own_structured_request_message_items_v3('e0500000-0000-4000-8000-000000000003',20)),0,'old Requests reader excludes member kind');
select is(jsonb_array_length(public.list_own_scoped_conversation_items_v6('e0500000-0000-4000-8000-000000000003','private',20)),0,'old Chats reader excludes member kind');
select is(jsonb_array_length(public.list_own_scoped_conversation_items_v7('e0500000-0000-4000-8000-000000000003','private',20)),1,'new Private reader includes one canonical anchor');
select is(jsonb_array_length(public.list_own_scoped_conversation_items_v7('e0500000-0000-4000-8000-000000000003','groups',20)),0,'personal chat is not a Group room');
insert into member_result values('feed',public.get_own_member_contact_feed('e0500000-0000-4000-8000-000000000003',(select (v->>'chat_id')::uuid from member_result where k='chat')));
select is((select v->'items'->0->>'body' from member_result where k='feed'),'First fictional hello','feed returns immutable normalized body');
select is(public.set_member_contact_muted('e0500000-0000-4000-8000-000000000003',gen_random_uuid(),(select (v->>'chat_id')::uuid from member_result where k='chat'),true)->>'outcome','muted','mute is deliberate');
select is(public.get_own_message_unread_summary_v3('e0500000-0000-4000-8000-000000000003')->>'private','1','mute does not read human history');
reset role;
select ok(not private.member_contact_message_notice_allowed((select (v->>'chat_id')::uuid from member_result where k='chat'),'e0500000-0000-4000-8000-000000000003'),'mute suppresses message notices');
select is((select count(*) from private.member_contact_messages where pair_id=(select (v->>'chat_id')::uuid from member_result where k='chat')),1::bigint,'exact send receipt creates one message');
select ok(not exists(select 1 from private.outbox_events where event_type='member_contact.request_created' and payload ? 'note'),'outbox contains no private note');
select ok(not exists(select 1 from realtime.messages where event like 'member.contact%' and payload-'id'<>jsonb_build_object('profile_id',split_part(topic,':',3))),'private signals contain only recipient identity');
-- A member who also represents the Group retains People when membership ends.
insert into private.group_delegates(group_id,profile_id,initial_role,delegate_role,granted_by)
values('e0510000-0000-4000-8000-000000000001','e0500000-0000-4000-8000-000000000003','co_creator','co_creator','e0500000-0000-4000-8000-000000000001');
update private.group_memberships set ended_at=clock_timestamp(),ended_by=profile_id,end_reason='left' where id='e0520000-0000-4000-8000-000000000013';
select ok(private.member_contact_pair_current((select (v->>'chat_id')::uuid from member_result where k='chat')),'last qualifying union grant, not exact membership, owns lifetime');
select is((select count(*) from private.member_contact_episodes where pair_id=(select (v->>'chat_id')::uuid from member_result where k='chat') and ended_at is null),1::bigint,'membership leave alone does not end manager personal episode');
update private.group_delegates set revoked_at=clock_timestamp(),revoked_by='e0500000-0000-4000-8000-000000000001' where group_id='e0510000-0000-4000-8000-000000000001' and profile_id='e0500000-0000-4000-8000-000000000003';
select is((select ended_reason from private.member_contact_episodes where id=(select (v->>'episode_id')::uuid from member_result where k='chat')),'context_ended','last Group relationship loss seals episode');
set local role authenticated;
select set_config('request.jwt.claim.sub','e0500000-0000-4000-8000-000000000003',true);
select is(public.get_own_member_contact_conversation('e0500000-0000-4000-8000-000000000003',(select (v->>'chat_id')::uuid from member_result where k='chat'))->>'is_read_only','true','former person retains authorized history read-only');
select is(jsonb_array_length(public.get_own_member_contact_feed('e0500000-0000-4000-8000-000000000003',(select (v->>'chat_id')::uuid from member_result where k='chat'))->'items'),1,'pre-exit message remains readable');
select throws_ok($$select public.acknowledge_member_contact_read('e0500000-0000-4000-8000-000000000003',(select (v->>'chat_id')::uuid from member_result where k='chat'),(select (v->>'read_boundary')::uuid from member_result where k='feed'))$$,'42501',null,'old read token invalidated by context exit');
insert into member_result values('message_report',to_jsonb(public.submit_moderation_report('e0500000-0000-4000-8000-000000000003',gen_random_uuid(),'spam','A fictional message report.','member_contact_message',(select (v->>'message_id')::uuid from member_result where k='message'),'member_contact_chat',(select (v->>'chat_id')::uuid from member_result where k='chat'))));
select is((select count(*) from public.list_own_moderation_reports_v4('e0500000-0000-4000-8000-000000000003',20)),2::bigint,'known content reports remain available after exit');
select is((select count(*) from public.list_own_moderation_reports_v3('e0500000-0000-4000-8000-000000000003',20)),0::bigint,'old report readers exclude new kinds');
reset role;
insert into private.group_memberships(group_id,profile_id,admitted_by) values('e0510000-0000-4000-8000-000000000001','e0500000-0000-4000-8000-000000000003','e0500000-0000-4000-8000-000000000001');
set local role authenticated;
select set_config('request.jwt.claim.sub','e0500000-0000-4000-8000-000000000002',true);
select throws_ok($$select public.send_member_contact_message('e0500000-0000-4000-8000-000000000002',gen_random_uuid(),(select (v->>'chat_id')::uuid from member_result where k='chat'),(select (v->>'episode_id')::uuid from member_result where k='chat'),'No silent rejoin')$$,'PT409',null,'rejoin cannot silently revive old consent');
insert into member_result values('second_request',public.submit_member_contact_request('e0500000-0000-4000-8000-000000000002',gen_random_uuid(),'e0510000-0000-4000-8000-000000000001','e0500000-0000-4000-8000-000000000003'));
insert into member_result values('other_origin',public.submit_member_contact_request('e0500000-0000-4000-8000-000000000002',gen_random_uuid(),'e0510000-0000-4000-8000-000000000002','e0500000-0000-4000-8000-000000000003'));
select set_config('request.jwt.claim.sub','e0500000-0000-4000-8000-000000000003',true);
insert into member_result values('second_chat',public.accept_member_contact_request('e0500000-0000-4000-8000-000000000003',gen_random_uuid(),(select (v->>'request_id')::uuid from member_result where k='second_request')));
select is((select v->>'chat_id' from member_result where k='second_chat'),(select v->>'chat_id' from member_result where k='chat'),'fresh consent reuses same pair+origin anchor');
select isnt((select v->>'episode_id' from member_result where k='second_chat'),(select v->>'episode_id' from member_result where k='chat'),'fresh consent has a new explicit episode');
select public.close_member_contact_conversation('e0500000-0000-4000-8000-000000000003',gen_random_uuid(),(select (v->>'chat_id')::uuid from member_result where k='second_chat'),(select (v->>'episode_id')::uuid from member_result where k='second_chat'));
select is(jsonb_array_length(public.get_own_member_contact_feed('e0500000-0000-4000-8000-000000000003',(select (v->>'chat_id')::uuid from member_result where k='chat'))->'items'),1,'Close retains earlier human history');
insert into member_result values('other_chat',public.accept_member_contact_request('e0500000-0000-4000-8000-000000000003',gen_random_uuid(),(select (v->>'request_id')::uuid from member_result where k='other_origin')));
select isnt((select v->>'chat_id' from member_result where k='other_chat'),(select v->>'chat_id' from member_result where k='chat'),'second shared Group never merges consent scopes');
select is(jsonb_array_length(public.get_own_member_contact_feed('e0500000-0000-4000-8000-000000000003',(select (v->>'chat_id')::uuid from member_result where k='other_chat'))->'items'),0,'other-origin chat inherits no messages');
select public.block_user('e0500000-0000-4000-8000-000000000003','e0500000-0000-4000-8000-000000000002');
select throws_ok($$select public.send_member_contact_message('e0500000-0000-4000-8000-000000000003',gen_random_uuid(),(select (v->>'chat_id')::uuid from member_result where k='other_chat'),(select (v->>'episode_id')::uuid from member_result where k='other_chat'),'Blocked send')$$,'42501',null,'block stops current personal sending');
select public.leave_member_contact_conversation('e0500000-0000-4000-8000-000000000003',gen_random_uuid(),(select (v->>'chat_id')::uuid from member_result where k='other_chat'),(select (v->>'episode_id')::uuid from member_result where k='other_chat'));
select is(public.get_own_member_contact_conversation('e0500000-0000-4000-8000-000000000003',(select (v->>'chat_id')::uuid from member_result where k='other_chat'))->>'ended_reason','left','safe Leave works while blocked and retains own history');
reset role;
select is((select count(*) from private.member_contact_pairs where group_id::text like 'e051%'),2::bigint,'one pair anchor per deliberate origin');
select is((select count(*) from private.group_memberships where group_id::text like 'e051%'),5::bigint,'member contact creates no extra Group membership');
select * from finish();
rollback;
