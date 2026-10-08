begin;
select no_plan();


insert into auth.users(id,email) values
 ('fa010000-0000-4000-8000-000000000001','msg01-creator@planets.invalid'),
 ('fa010000-0000-4000-8000-000000000002','msg01-requester@planets.invalid'),
 ('fa010000-0000-4000-8000-000000000003','msg01-delegate@planets.invalid'),
 ('fa010000-0000-4000-8000-000000000004','msg01-unrelated@planets.invalid');
insert into public.profiles(id,display_name)
 select id,'Synthetic pair endpoint' from auth.users where id in (
 'fa010000-0000-4000-8000-000000000001','fa010000-0000-4000-8000-000000000002',
 'fa010000-0000-4000-8000-000000000003','fa010000-0000-4000-8000-000000000004');
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

select is(public.list_own_scoped_conversation_items_v4('fa010000-0000-4000-8000-000000000001','private',50)->0->>'latest_request_activity_status','pending','request-only pair has a truthful pending preview');
select public.send_participation_conversation_message('fa010000-0000-4000-8000-000000000001',(select chat_id from msg01_requests limit 1),'Older human preview');
select is(public.list_own_scoped_conversation_items_v4('fa010000-0000-4000-8000-000000000001','private',50)->0->>'latest_request_activity_status',null,'human preview is latest after a new message');
select public.reject_project_join_request_as_manager('fa010000-0000-4000-8000-000000000001',(select min(request_id::text)::uuid from msg01_requests where project_id<>'fa020000-0000-4000-8000-000000000003'));
select is(public.list_own_scoped_conversation_items_v3('fa010000-0000-4000-8000-000000000001','private',50)->0->>'project_request_status','pending','route context remains a different newer pending request');
select is(public.list_own_scoped_conversation_items_v4('fa010000-0000-4000-8000-000000000001','private',50)->0->>'latest_request_activity_status','rejected','older request resolution overrides stale human and route context');
select is(public.list_own_scoped_conversation_items_v4('fa010000-0000-4000-8000-000000000001','private',50)->0->>'last_visible_message_body','Older human preview','existing human body is neither copied nor mutated');
select is((public.list_own_scoped_conversation_items_v4('fa010000-0000-4000-8000-000000000001','private',50)->0)-array['latest_request_activity_status','latest_group_system_event_label'], public.list_own_scoped_conversation_items_v3('fa010000-0000-4000-8000-000000000001','private',50)->0,'v4 minus two preview fields is exactly v3');
select is((select count(*) from jsonb_object_keys(public.list_own_scoped_conversation_items_v3('fa010000-0000-4000-8000-000000000001','private',50)->0)),32::bigint,'released v3 key count unchanged');
select is((select count(*) from jsonb_object_keys(public.list_own_scoped_conversation_items_v4('fa010000-0000-4000-8000-000000000001','private',50)->0)),34::bigint,'v4 adds only two nullable preview fields');
select throws_ok($$select public.list_own_scoped_conversation_items_v4('fa010000-0000-4000-8000-000000000002','private',50)$$,'42501',null,'expected foreign identity fails closed');
select throws_ok($$select public.list_own_scoped_conversation_items_v4('fa010000-0000-4000-8000-000000000001','private',0)$$,'22023',null,'v4 preserves invalid limit rejection');
select throws_ok($$select public.list_own_scoped_conversation_items_v4('fa010000-0000-4000-8000-000000000001','private',1,now(),null,null)$$,'22023',null,'partial cursor rejected');
select set_config('request.jwt.claim.sub','fa010000-0000-4000-8000-000000000003',true);
select is(public.list_own_scoped_conversation_items_v4('fa010000-0000-4000-8000-000000000003','private',50),'[]'::jsonb,'non-endpoint sees no pair preview');
select set_config('request.jwt.claim.sub','fa010000-0000-4000-8000-000000000004',true);
select public.request_to_join_project('fa010000-0000-4000-8000-000000000004','fa020000-0000-4000-8000-000000000001','Second pair');
select set_config('request.jwt.claim.sub','fa010000-0000-4000-8000-000000000001',true);
select is(jsonb_array_length(public.list_own_scoped_conversation_items_v4('fa010000-0000-4000-8000-000000000001','private',1)),1,'limit is applied before projection');
create temporary table preview_cursor as select public.list_own_scoped_conversation_items_v4('fa010000-0000-4000-8000-000000000001','private',1)->0 as row;
select is((select jsonb_array_length(public.list_own_scoped_conversation_items_v4('fa010000-0000-4000-8000-000000000001','private',1,(row->>'activity_at')::timestamptz,row->>'item_kind',(row->>'chat_id')::uuid)) from preview_cursor),1,'complete cursor yields remaining pair');
select isnt((select public.list_own_scoped_conversation_items_v4('fa010000-0000-4000-8000-000000000001','private',1,(row->>'activity_at')::timestamptz,row->>'item_kind',(row->>'chat_id')::uuid)->0->>'chat_id' from preview_cursor),(select row->>'chat_id' from preview_cursor),'cursor never repeats the first pair');
select is((select jsonb_agg(row.value-array['latest_request_activity_status','latest_group_system_event_label'] order by row.ordinality) from jsonb_array_elements(public.list_own_scoped_conversation_items_v4('fa010000-0000-4000-8000-000000000001','private',50)) with ordinality row(value,ordinality)),public.list_own_scoped_conversation_items_v3('fa010000-0000-4000-8000-000000000001','private',50),'full ordered page and unread are v3 compatible');
reset role;
select ok(not has_function_privilege('anon','public.list_own_scoped_conversation_items_v4(uuid,text,integer,timestamptz,text,uuid)','execute'),'anon has no v4 grant');
select ok(not has_function_privilege('service_role','public.list_own_scoped_conversation_items_v4(uuid,text,integer,timestamptz,text,uuid)','execute'),'service role has no own-state impersonation grant');
select * from finish();
rollback;
