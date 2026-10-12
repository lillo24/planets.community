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
 ('fa020000-0000-4000-8000-000000000001','fa010000-0000-4000-8000-000000000001','published','GROUPCOVER01 first',now()+interval '1 day',now()+interval '2 days',now()),
 ('fa020000-0000-4000-8000-000000000002','fa010000-0000-4000-8000-000000000001','published','GROUPCOVER01 second',now()+interval '1 day',now()+interval '2 days',now()),
 ('fa020000-0000-4000-8000-000000000003','fa010000-0000-4000-8000-000000000002','published','GROUPCOVER01 opposite',now()+interval '1 day',now()+interval '2 days',now());
insert into public.recurring_activities(id,creator_profile_id,lifecycle_state,title,published_at) values
 ('fa020000-0000-4000-8000-000000000004','fa010000-0000-4000-8000-000000000001','published','GROUPCOVER01 Tavolo',now());

create temporary table cover_requests(request_id uuid, project_id uuid, membership_id uuid);
grant all on cover_requests to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','fa010000-0000-4000-8000-000000000002',true);
insert into cover_requests(request_id,project_id)
 select public.request_to_join_project('fa010000-0000-4000-8000-000000000002',p,'Cover member'),p
 from unnest(array['fa020000-0000-4000-8000-000000000001'::uuid,'fa020000-0000-4000-8000-000000000002','fa020000-0000-4000-8000-000000000004'])p;
select set_config('request.jwt.claim.sub','fa010000-0000-4000-8000-000000000001',true);
update cover_requests set membership_id=public.accept_project_join_request_as_manager('fa010000-0000-4000-8000-000000000001',request_id);
reset role;
insert into public.project_covers(project_id,object_path)
 select p,'fa010000-0000-4000-8000-000000000001/projects/'||p::text||'/fa030000-0000-4000-8000-000000000001.webp'
 from unnest(array['fa020000-0000-4000-8000-000000000001'::uuid,'fa020000-0000-4000-8000-000000000004'])p;
set local role authenticated;
select set_config('request.jwt.claim.sub','fa010000-0000-4000-8000-000000000001',true);
select is(jsonb_array_length(public.list_own_scoped_conversation_items_v5('fa010000-0000-4000-8000-000000000001','groups',50)),3,'creator gets exactly the authorized group page');
select is((select count(*) from jsonb_array_elements(public.list_own_scoped_conversation_items_v5('fa010000-0000-4000-8000-000000000001','groups',50))r where r->>'group_cover_object_path' is not null),2::bigint,'published Project and Tavolo expose current covers; legacy/no-cover row is null');
select is((select jsonb_agg(r.value-'group_cover_object_path' order by r.ordinality) from jsonb_array_elements(public.list_own_scoped_conversation_items_v5('fa010000-0000-4000-8000-000000000001','groups',50))with ordinality r(value,ordinality)),public.list_own_scoped_conversation_items_v4('fa010000-0000-4000-8000-000000000001','groups',50),'v4 shape, order, activity and unread remain identical');
select ok((select bool_and(r->>'group_cover_object_path' is null) from jsonb_array_elements(public.list_own_scoped_conversation_items_v5('fa010000-0000-4000-8000-000000000001','private',50))r),'all Private kinds have null cover');
select is((select count(*) from jsonb_object_keys(public.list_own_scoped_conversation_items_v5('fa010000-0000-4000-8000-000000000001','groups',50)->0)),(select count(*)+1 from jsonb_object_keys(public.list_own_scoped_conversation_items_v4('fa010000-0000-4000-8000-000000000001','groups',50)->0)),'v5 adds exactly one nullable field');
create temporary table cover_cursor as select public.list_own_scoped_conversation_items_v5('fa010000-0000-4000-8000-000000000001','groups',1)->0 row;
select is((select jsonb_array_length(public.list_own_scoped_conversation_items_v5('fa010000-0000-4000-8000-000000000001','groups',50,(row->>'activity_at')::timestamptz,row->>'item_kind',(row->>'chat_id')::uuid))from cover_cursor),2,'pagination applies before cover projection without repeats');
select throws_ok($$select public.list_own_scoped_conversation_items_v5('fa010000-0000-4000-8000-000000000002','groups',50)$$,'42501',null,'foreign expected identity rejected');
select throws_ok($$select public.list_own_scoped_conversation_items_v5('fa010000-0000-4000-8000-000000000001','groups',0)$$,'22023',null,'invalid limit rejected');
select throws_ok($$select public.list_own_scoped_conversation_items_v5('fa010000-0000-4000-8000-000000000001','groups',1,now(),null,null)$$,'22023',null,'partial cursor rejected');
select set_config('test.cover_invite',(select invite_token from public.create_project_delegate_invitation('fa010000-0000-4000-8000-000000000001','fa020000-0000-4000-8000-000000000001')),true);
select set_config('request.jwt.claim.sub','fa010000-0000-4000-8000-000000000003',true);
select set_config('test.cover_delegate',public.accept_project_delegate_invitation('fa010000-0000-4000-8000-000000000003',current_setting('test.cover_invite'))::text,true);
select is((select r->>'group_cover_object_path' from jsonb_array_elements(public.list_own_scoped_conversation_items_v5('fa010000-0000-4000-8000-000000000003','groups',50))r where r->>'project_id'='fa020000-0000-4000-8000-000000000001'),'fa010000-0000-4000-8000-000000000001/projects/fa020000-0000-4000-8000-000000000001/fa030000-0000-4000-8000-000000000001.webp','active delegate gets only authorized group cover');
select set_config('request.jwt.claim.sub','fa010000-0000-4000-8000-000000000001',true);
select public.revoke_project_delegate('fa010000-0000-4000-8000-000000000001',current_setting('test.cover_delegate')::uuid);
select set_config('request.jwt.claim.sub','fa010000-0000-4000-8000-000000000003',true);
select is(public.list_own_scoped_conversation_items_v5('fa010000-0000-4000-8000-000000000003','groups',50),'[]'::jsonb,'revoked delegate gets no group metadata or image hints');
select set_config('request.jwt.claim.sub','fa010000-0000-4000-8000-000000000004',true);
select is(public.list_own_scoped_conversation_items_v5('fa010000-0000-4000-8000-000000000004','groups',50),'[]'::jsonb,'unrelated account gets no group metadata or image hints');
select set_config('request.jwt.claim.sub','fa010000-0000-4000-8000-000000000002',true);
select is((select count(*) from jsonb_array_elements(public.list_own_scoped_conversation_items_v5('fa010000-0000-4000-8000-000000000002','groups',50))r where r->>'group_cover_object_path' is not null),2::bigint,'current member receives same authorized covers');
reset role;
update public.proposals set lifecycle_state='cancelled',cancelled_at=now() where id='fa020000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claim.sub','fa010000-0000-4000-8000-000000000002',true);
select ok(not exists(select 1 from jsonb_array_elements(public.list_own_scoped_conversation_items_v5('fa010000-0000-4000-8000-000000000002','groups',50))r where r->>'project_id'='fa020000-0000-4000-8000-000000000001' and r->>'group_cover_object_path' is not null),'cancelled/protected source does not gain public cover access through chat');
reset role;
update public.proposals set lifecycle_state='draft',published_at=null,cancelled_at=null where id='fa020000-0000-4000-8000-000000000001';
select ok(not public.can_read_public_cover_image_object('fa010000-0000-4000-8000-000000000001/projects/fa020000-0000-4000-8000-000000000001/fa030000-0000-4000-8000-000000000001.webp'),'unpublished source is still denied by existing cover policy');
delete from public.project_covers where project_id='fa020000-0000-4000-8000-000000000004';
set local role authenticated;
select set_config('request.jwt.claim.sub','fa010000-0000-4000-8000-000000000002',true);
select ok(not exists(select 1 from jsonb_array_elements(public.list_own_scoped_conversation_items_v5('fa010000-0000-4000-8000-000000000002','groups',50))r where r->>'group_cover_object_path' is not null),'removed current covers and protected sources produce only nulls');
select public.leave_project('fa010000-0000-4000-8000-000000000002',membership_id) from cover_requests;
select ok(not exists(select 1 from jsonb_array_elements(public.list_own_scoped_conversation_items_v5('fa010000-0000-4000-8000-000000000002','groups',50))r where r->>'group_cover_object_path' is not null),'archived/left membership rows never restore denied covers');
reset role;
select ok(not has_function_privilege('anon','public.list_own_scoped_conversation_items_v5(uuid,text,integer,timestamptz,text,uuid)','EXECUTE'),'anonymous has no new grant');
select ok(not has_function_privilege('service_role','public.list_own_scoped_conversation_items_v5(uuid,text,integer,timestamptz,text,uuid)','EXECUTE'),'service role has no impersonation grant');
select * from finish();
rollback;
