begin;
select no_plan();
select ok(relrowsecurity,relname||' has RLS') from pg_class where relnamespace='private'::regnamespace and relname like 'cocreate_%' and relkind='r';
select ok(not has_table_privilege(r,c.oid,p),r||' cannot '||p||' '||c.relname)
from pg_class c cross join unnest(array['anon','authenticated','service_role'])r cross join unnest(array['SELECT','INSERT','UPDATE','DELETE'])p
where c.relnamespace='private'::regnamespace and c.relname like 'cocreate_%' and c.relkind='r';
select ok(not has_function_privilege('authenticated',oid,'execute'),proname||' is private')
from pg_proc where pronamespace='private'::regnamespace and proname like '%cocreate%';
select throws_ok($$select public.list_cocreate_hubs()$$,'42501',null,'Disabled hub discovery denies direct call');
update private.cocreate_settings set enabled=true;
insert into private.cocreate_topics(id,label,active) values('cc010000-0000-4000-8000-000000000001','Synthetic topic',true);
insert into private.cocreate_hubs(id,topic_id,locality,active) values
 ('cc010000-0000-4000-8000-000000000002','cc010000-0000-4000-8000-000000000001','Trento',true),
 ('cc010000-0000-4000-8000-000000000003','cc010000-0000-4000-8000-000000000001','Rovereto',true);
select set_config('cocreate.hub','cc010000-0000-4000-8000-000000000002',true);
select set_config('cocreate.room',(select id::text from private.cocreate_rooms where hub_id=current_setting('cocreate.hub')::uuid),true);
select is((select count(*) from private.cocreate_rooms where hub_id=current_setting('cocreate.hub')::uuid),1::bigint,'One canonical General created transactionally');
select is(jsonb_array_length(public.list_cocreate_hubs('synthetic','trento')),1,'Hub filters before pagination');
select is(jsonb_array_length(public.list_cocreate_hubs('%')),0,'Hub search wildcard is literal');
select ok(not(public.get_cocreate_hub(current_setting('cocreate.hub')::uuid)?|array['roster','messages','room_id','participants']),'Anonymous hub detail has no roster/transcript');
select throws_ok($$select public.list_cocreate_hubs('','',null,0)$$,'22023',null,'Invalid hub page bound denies');
insert into auth.users(id,email) values
 ('cc010000-0000-4000-8000-000000000004','cocreate-hub-a@planets.invalid'),
 ('cc010000-0000-4000-8000-000000000005','cocreate-hub-b@planets.invalid'),
 ('cc010000-0000-4000-8000-000000000006','cocreate-hub-staff@planets.invalid');
insert into public.profiles(id,display_name) select id,'Synthetic hub person' from auth.users where id in(
 'cc010000-0000-4000-8000-000000000004','cc010000-0000-4000-8000-000000000005','cc010000-0000-4000-8000-000000000006')
 on conflict(id) do nothing;
insert into private.policy_acceptances(account_id,bundle_version)
 select id,'POLICY01-2026-10-08-v1' from auth.users where id in(
 'cc010000-0000-4000-8000-000000000004','cc010000-0000-4000-8000-000000000005','cc010000-0000-4000-8000-000000000006');
select set_config('request.jwt.claim.sub','cc010000-0000-4000-8000-000000000004',true);
select throws_ok($$select public.get_cocreate_room_page('cc010000-0000-4000-8000-000000000004',current_setting('cocreate.room')::uuid,gen_random_uuid())$$,
 '42501',null,'Prejoin transcript denies even with guessed room');
select set_config('cocreate.join_key',gen_random_uuid()::text,true);
select set_config('cocreate.a_episode',(public.mutate_cocreate_hub('cc010000-0000-4000-8000-000000000004',current_setting('cocreate.join_key')::uuid,
 current_setting('cocreate.hub')::uuid,'join')->>'episode_id'),true);
select is(public.mutate_cocreate_hub('cc010000-0000-4000-8000-000000000004',current_setting('cocreate.join_key')::uuid,
 current_setting('cocreate.hub')::uuid,'join')->>'episode_id',current_setting('cocreate.a_episode'),'Exact admission retry returns same episode');
select set_config('cocreate.send_key',gen_random_uuid()::text,true);
select set_config('cocreate.message',(public.send_cocreate_room_message('cc010000-0000-4000-8000-000000000004',current_setting('cocreate.send_key')::uuid,
 current_setting('cocreate.room')::uuid,current_setting('cocreate.a_episode')::uuid,'Synthetic first message')->>'message_id'),true);
select is(public.send_cocreate_room_message('cc010000-0000-4000-8000-000000000004',current_setting('cocreate.send_key')::uuid,
 current_setting('cocreate.room')::uuid,current_setting('cocreate.a_episode')::uuid,'Synthetic first message')->>'message_id',current_setting('cocreate.message'),'Send retry creates no second human message');
select throws_ok($$select public.send_cocreate_room_message('cc010000-0000-4000-8000-000000000004',current_setting('cocreate.send_key')::uuid,
 current_setting('cocreate.room')::uuid,current_setting('cocreate.a_episode')::uuid,'Changed intent')$$,'22023',null,'Changed send intent rejects');
select set_config('request.jwt.claim.sub','cc010000-0000-4000-8000-000000000005',true);
select throws_ok($$select public.list_cocreate_room_people('cc010000-0000-4000-8000-000000000005',current_setting('cocreate.room')::uuid,gen_random_uuid())$$,
 '42501',null,'Prejoin People denies');
select set_config('cocreate.b_episode',(public.mutate_cocreate_hub('cc010000-0000-4000-8000-000000000005',gen_random_uuid(),current_setting('cocreate.hub')::uuid,'join')->>'episode_id'),true);
select is(jsonb_array_length(public.get_cocreate_room_page('cc010000-0000-4000-8000-000000000005',current_setting('cocreate.room')::uuid,current_setting('cocreate.b_episode')::uuid)->'messages'),1,'Active member explicitly admitted to earlier General history');
select is(public.list_own_cocreate_rooms('cc010000-0000-4000-8000-000000000005')->0->>'unread_count','0','Admission does not fabricate historical unread');
select set_config('request.jwt.claim.sub','cc010000-0000-4000-8000-000000000004',true);
select public.send_cocreate_room_message('cc010000-0000-4000-8000-000000000004',gen_random_uuid(),current_setting('cocreate.room')::uuid,current_setting('cocreate.a_episode')::uuid,'Synthetic second message');
select set_config('request.jwt.claim.sub','cc010000-0000-4000-8000-000000000005',true);
select is(public.get_own_message_unread_summary_with_cocreate('cc010000-0000-4000-8000-000000000005')->>'groups','1','General appears once in Groups unread');
select set_config('cocreate.token',public.get_cocreate_room_page('cc010000-0000-4000-8000-000000000005',current_setting('cocreate.room')::uuid,current_setting('cocreate.b_episode')::uuid)->>'read_token',true);
select is(public.get_cocreate_room_page('cc010000-0000-4000-8000-000000000005',current_setting('cocreate.room')::uuid,current_setting('cocreate.b_episode')::uuid,30,2)->>'read_token',null::text,'Older page cannot ACK newest');
select public.acknowledge_cocreate_room('cc010000-0000-4000-8000-000000000005',current_setting('cocreate.room')::uuid,current_setting('cocreate.b_episode')::uuid,current_setting('cocreate.token'));
select is(public.get_own_message_unread_summary_with_cocreate('cc010000-0000-4000-8000-000000000005')->>'groups','0','Rendered General frontier clears canonical count');
select public.mutate_cocreate_hub('cc010000-0000-4000-8000-000000000005',gen_random_uuid(),current_setting('cocreate.hub')::uuid,'leave',current_setting('cocreate.b_episode')::uuid);
delete from realtime.messages where event='cocreate.changed';
select set_config('request.jwt.claim.sub','cc010000-0000-4000-8000-000000000004',true);
select public.send_cocreate_room_message('cc010000-0000-4000-8000-000000000004',gen_random_uuid(),current_setting('cocreate.room')::uuid,current_setting('cocreate.a_episode')::uuid,'Synthetic future message');
select ok(not exists(select 1 from realtime.messages where event='cocreate.changed' and topic='cocreate:profile:cc010000-0000-4000-8000-000000000005'),'Former member gets no future room activity hint');
select ok(not exists(select 1 from realtime.messages where event='cocreate.changed'
 and payload-'id'<>jsonb_build_object('profile_id',split_part(topic,':',3))),
 'Private hints contain only recipient identity plus the pinned transport delivery ID');
select set_config('request.jwt.claim.sub','cc010000-0000-4000-8000-000000000005',true);
select is(jsonb_array_length(public.get_cocreate_room_page('cc010000-0000-4000-8000-000000000005',current_setting('cocreate.room')::uuid,current_setting('cocreate.b_episode')::uuid)->'messages'),2,'Former history is frozen at committed exit sequence');
select throws_ok($$select public.send_cocreate_room_message('cc010000-0000-4000-8000-000000000005',gen_random_uuid(),current_setting('cocreate.room')::uuid,current_setting('cocreate.b_episode')::uuid,'No future grant')$$,'42501',null,'Former episode cannot send');
select set_config('cocreate.b_new_episode',(public.mutate_cocreate_hub('cc010000-0000-4000-8000-000000000005',gen_random_uuid(),current_setting('cocreate.hub')::uuid,'join')->>'episode_id'),true);
select isnt(current_setting('cocreate.b_new_episode'),current_setting('cocreate.b_episode'),'Rejoin creates a new independent admission episode');
select throws_ok($$select public.acknowledge_cocreate_room('cc010000-0000-4000-8000-000000000005',current_setting('cocreate.room')::uuid,current_setting('cocreate.b_new_episode')::uuid,current_setting('cocreate.token'))$$,'42501',null,'Old read receipt grants nothing in new episode');
select throws_ok($$select public.mutate_cocreate_hub('cc010000-0000-4000-8000-000000000005',gen_random_uuid(),current_setting('cocreate.hub')::uuid,'leave',current_setting('cocreate.b_episode')::uuid)$$,'PT409',null,'Stale leave cannot end a new episode');
select set_config('cocreate.case',(select case_id::text from public.submit_cocreate_room_report('cc010000-0000-4000-8000-000000000005',gen_random_uuid(),current_setting('cocreate.message')::uuid,'other','Synthetic scoped room report')),true);
insert into private.moderation_staff_roles(profile_id,staff_role) values('cc010000-0000-4000-8000-000000000006','moderator');
select set_config('request.jwt.claim.sub','cc010000-0000-4000-8000-000000000006',true);
select is(public.get_moderation_case_cocreate_room('cc010000-0000-4000-8000-000000000006',current_setting('cocreate.case')::uuid)->'evidence'->>'body','Synthetic first message','Staff read exact reported evidence only');
select throws_ok($$select public.get_cocreate_room_page('cc010000-0000-4000-8000-000000000006',current_setting('cocreate.room')::uuid,current_setting('cocreate.a_episode')::uuid)$$,'42501',null,'Staff role grants no transcript');
select public.moderate_cocreate_hub('cc010000-0000-4000-8000-000000000006',gen_random_uuid(),current_setting('cocreate.case')::uuid,1,'remove_sender');
select set_config('request.jwt.claim.sub','cc010000-0000-4000-8000-000000000004',true);
select throws_ok($$select public.mutate_cocreate_hub('cc010000-0000-4000-8000-000000000004',gen_random_uuid(),current_setting('cocreate.hub')::uuid,'join')$$,'42501',null,'Removed member cannot self-rejoin');
select set_config('request.jwt.claim.sub','cc010000-0000-4000-8000-000000000006',true);
select public.moderate_cocreate_hub('cc010000-0000-4000-8000-000000000006',gen_random_uuid(),current_setting('cocreate.case')::uuid,2,'suppress');
select set_config('request.jwt.claim.sub','cc010000-0000-4000-8000-000000000005',true);
select throws_ok($$select public.get_cocreate_room_page('cc010000-0000-4000-8000-000000000005',current_setting('cocreate.room')::uuid,current_setting('cocreate.b_new_episode')::uuid)$$,'42501',null,'Suppression denies retained current/previous rooms');
update private.cocreate_settings set enabled=false;
select is(jsonb_array_length(public.list_own_cocreate_hub_exits('cc010000-0000-4000-8000-000000000005')),1,'Own exit metadata remains available with gate OFF');
select lives_ok($$select public.mutate_cocreate_hub('cc010000-0000-4000-8000-000000000005',gen_random_uuid(),current_setting('cocreate.hub')::uuid,'leave',current_setting('cocreate.b_new_episode')::uuid)$$,'Own hub leave works while suppressed and disabled');
select * from finish();
rollback;
