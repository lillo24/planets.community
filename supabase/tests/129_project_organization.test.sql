begin;
select no_plan();
insert into auth.users(id,email) values
 ('fc010000-0000-4000-8000-000000000001','check01-pgtap-owner@planets.invalid'),
 ('fc010000-0000-4000-8000-000000000002','check01-pgtap-member@planets.invalid'),
 ('fc010000-0000-4000-8000-000000000003','check01-pgtap-outsider@planets.invalid');
insert into public.profiles(id,display_name) select id,'Synthetic Organization actor' from auth.users where id::text like 'fc010000-%';
insert into public.profile_photos(profile_id,object_path,audience)
 select id,id::text||'/00000000-0000-4000-8000-000000000001.webp','interactions' from public.profiles where id::text like 'fc010000-%';
select ok(not has_table_privilege('authenticated','private.project_organization','select,insert,update,delete'),'private planning has no client table grants');
select ok(not has_table_privilege('service_role','private.project_organization_tasks','select,insert,update,delete'),'no implicit service-role task grants');
select ok(not has_function_privilege('anon','public.get_project_organization_v1(uuid,uuid)','execute'),'anonymous cannot call planner');
select ok(not has_function_privilege('authenticated','private.organization_snapshot(uuid,uuid)','execute'),'private snapshot cannot bypass identity');
select ok(not has_table_privilege('authenticated','private.project_organization_official_writes','insert'),'transaction capability is unforgeable by clients');

create function pg_temp.org(command jsonb) returns jsonb language plpgsql as $$
declare snapshot jsonb; item uuid:=current_setting('test.organization')::uuid;
begin
 snapshot:=public.get_project_organization_v1(auth.uid(),item);
 return public.mutate_project_organization_v1(auth.uid(),item,(snapshot->>'revision')::bigint,gen_random_uuid(),command);
end $$;
grant execute on function pg_temp.org(jsonb) to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','fc010000-0000-4000-8000-000000000001',true);
select set_config('test.organization',public.create_proposal_draft(auth.uid(),'CHECK01 private plan','Collaborate on something meaningful.','Complete description',
 now()+interval '3 days',now()+interval '5 days','Europe/Rome','IT','Trento',null,'Trento',
 'PRIVATE arrival gate','public',array[]::uuid[],array[]::text[],10,false)::text,true);
select lives_ok($$select public.publish_proposal_idea(auth.uid(),current_setting('test.organization')::uuid)$$,'publish moves pre-entered logistics to private proposals');
select is((select locality from public.get_public_proposal_v2(current_setting('test.organization')::uuid)),null::text,'draft city does not become public');
select is((select starts_at from public.get_public_proposal_v2(current_setting('test.organization')::uuid)),null::timestamptz,'draft schedule does not become official');
select is((select registration_capacity from public.list_public_project_capacity_statuses(array[current_setting('test.organization')::uuid])),null::integer,'draft cap does not constrain admissions');
select is(public.get_project_organization_v1(auth.uid(),current_setting('test.organization')::uuid)->'proposals'->'location'->>'text','Trento','creator reads proposed city before chat exists');
select throws_ok($$select public.get_own_project_group_chat(auth.uid(),current_setting('test.organization')::uuid)$$,'42501',null,'planner does not create a chat');
select throws_ok($$select public.get_project_organization_v1('fc010000-0000-4000-8000-000000000003',current_setting('test.organization')::uuid)$$,'42501',null,'expected identity bound');
select lives_ok($$select pg_temp.org('{"action":"confirm_decision","kind":"location"}')$$,'confirm just city');
select is((select locality from public.get_public_proposal_v2(current_setting('test.organization')::uuid)),'Trento','confirmed city public while Idea');
select is((select definition_phase from public.get_public_proposal_v2(current_setting('test.organization')::uuid)),'idea','individual confirmation does not promote');
select is((select starts_at from public.get_public_proposal_v2(current_setting('test.organization')::uuid)),null::timestamptz,'schedule still private');
select is((select count(*) from public.get_public_proposal(current_setting('test.organization')::uuid)),0::bigint,'legacy v1 still excludes Idea');
select lives_ok($$select pg_temp.org('{"action":"save_decision","kind":"location","value":{"text":"Trento o Rovereto"}}')$$,'text-only private suggestion accepted');
select is((select locality from public.get_public_proposal_v2(current_setting('test.organization')::uuid)),'Trento','pending replacement does not overwrite public city');
select throws_ok($$select pg_temp.org('{"action":"confirm_decision","kind":"location"}')$$,'22023',null,'ambiguous suggestion cannot be confirmed');
select throws_ok($$select pg_temp.org('{"action":"save_decision","kind":"location","value":{"text":"Trento","latitude":46,"longitude":11}}')$$,'22023',null,'private city proposal cannot smuggle coordinates');
select throws_ok($$select pg_temp.org('{"action":"save_decision","kind":"location","value":{"text":{},"locality":42}}')$$,'22023',null,'location rejects non-text JSON values');
select throws_ok($$select pg_temp.org('{"action":"save_decision","kind":"schedule","value":{"starts_at":"infinity","ends_at":"infinity","timezone":"Europe/Rome"}}')$$,'22023',null,'finite real schedule required');
select throws_ok($$select pg_temp.org('{"action":"save_decision","kind":"capacity","value":{"limit":0,"count_organizers":false}}')$$,'22023',null,'capacity bounded');
select throws_ok($$select public.mutate_project_organization_v1(auth.uid(),current_setting('test.organization')::uuid,0,gen_random_uuid(),'{"action":"add_task","task_id":"fc011000-0000-4000-8000-000000000099","title":"stale"}')$$,'PT409',null,'stale CAS denied');

select set_config('request.jwt.claim.sub','fc010000-0000-4000-8000-000000000003',true);
select throws_ok($$select public.get_project_organization_v1(auth.uid(),current_setting('test.organization')::uuid)$$,'42501',null,'unrelated authenticated read denied');
select set_config('request.jwt.claim.sub','fc010000-0000-4000-8000-000000000002',true);
select set_config('test.org_request',public.request_to_join_project(auth.uid(),current_setting('test.organization')::uuid,null)::text,true);
select throws_ok($$select public.get_project_organization_v1(auth.uid(),current_setting('test.organization')::uuid)$$,'42501',null,'pending requester cannot read proposals');
select set_config('request.jwt.claim.sub','fc010000-0000-4000-8000-000000000001',true);
select set_config('test.org_membership',public.accept_project_join_request(auth.uid(),current_setting('test.org_request')::uuid)::text,true);
select set_config('request.jwt.claim.sub','fc010000-0000-4000-8000-000000000002',true);
select lives_ok($$select public.get_project_organization_v1(auth.uid(),current_setting('test.organization')::uuid)$$,'current member can read proposals');
select throws_ok($$select pg_temp.org('{"action":"confirm_decision","kind":"schedule"}')$$,'42501',null,'participant cannot officialize');
select lives_ok($$select pg_temp.org('{"action":"add_task","task_id":"fc011000-0000-4000-8000-000000000001","title":"Organizzare i materiali"}')$$,'participant adds root');
select throws_ok($$select pg_temp.org('{"action":"add_task","task_id":"fc011000-0000-4000-8000-000000000098","title":{}}')$$,'22023',null,'task title must be JSON text');
select lives_ok($$select pg_temp.org('{"action":"set_task_done","task_id":"fc011000-0000-4000-8000-000000000001","done":true}')$$,'leaf can be checked');
select set_config('request.jwt.claim.sub','fc010000-0000-4000-8000-000000000001',true);
select lives_ok($$select pg_temp.org('{"action":"add_task","task_id":"fc011000-0000-4000-8000-000000000002","parent_id":"fc011000-0000-4000-8000-000000000001","title":"Contattare chi ha gli attrezzi"}')$$,'add child to completed leaf safely reopens parent');
select is((public.get_project_organization_v1(auth.uid(),current_setting('test.organization')::uuid)->'tasks'->0->>'done')::boolean,false,'parent with unchecked child is incomplete');
select throws_ok($$select pg_temp.org('{"action":"set_task_done","task_id":"fc011000-0000-4000-8000-000000000001","done":true}')$$,'22023',null,'derived parent cannot contradict child');
select throws_ok($$select pg_temp.org('{"action":"add_task","task_id":"fc011000-0000-4000-8000-000000000003","parent_id":"fc011000-0000-4000-8000-000000000002","title":"third level"}')$$,'22023',null,'server denies third level');
select throws_ok($$select pg_temp.org('{"action":"add_task","task_id":"fc011000-0000-4000-8000-000000000003","parent_id":"fc011000-0000-4000-8000-000000000003","title":"cycle"}')$$,'22023',null,'server denies self cycle');
select throws_ok($$select pg_temp.org('{"action":"add_task","task_id":"fc011000-0000-4000-8000-000000000003","parent_id":"fc011000-0000-4000-8000-000000000099","title":"foreign parent"}')$$,'22023',null,'server denies unavailable/crossproject parent');
select lives_ok($$select pg_temp.org('{"action":"set_task_done","task_id":"fc011000-0000-4000-8000-000000000002","done":true}')$$,'check child');
select is((public.get_project_organization_v1(auth.uid(),current_setting('test.organization')::uuid)->'tasks'->0->>'done')::boolean,true,'parent derives all children complete');
select set_config('request.jwt.claim.sub','fc010000-0000-4000-8000-000000000002',true);
select throws_ok($$select pg_temp.org('{"action":"remove_task","task_id":"fc011000-0000-4000-8000-000000000001"}')$$,'42501',null,'author cannot cascade another author subtask');
select throws_ok($$select pg_temp.org('{"action":"edit_task","task_id":"fc011000-0000-4000-8000-000000000002","title":"overwrite"}')$$,'42501',null,'participant cannot edit others');
select lives_ok($$select pg_temp.org('{"action":"set_task_done","task_id":"fc011000-0000-4000-8000-000000000002","done":false}')$$,'member can reopen another author child');

select set_config('request.jwt.claim.sub','fc010000-0000-4000-8000-000000000001',true);
select lives_ok($$select pg_temp.org('{"action":"save_decision","kind":"capacity","value":{"limit":1,"count_organizers":true}}')$$,'proposed insufficient cap does not affect occupancy');
select throws_ok($$select pg_temp.org('{"action":"confirm_decision","kind":"capacity"}')$$,'PT409',null,'confirmation preserves canonical organizer-counting conflict');
select is((select registration_capacity from public.list_public_project_capacity_statuses(array[current_setting('test.organization')::uuid])),null::integer,'failed confirmation is atomic');
select lives_ok($$select pg_temp.org('{"action":"save_decision","kind":"capacity","value":{"limit":2,"count_organizers":true}}')$$,'choose valid cap');
select lives_ok($$select pg_temp.org('{"action":"confirm_decision","kind":"capacity"}')$$,'confirm valid cap');
select lives_ok($$select pg_temp.org('{"action":"confirm_decision","kind":"schedule"}')$$,'confirm multi-day dates');
select is((public.get_proposal_promotion_requirements(auth.uid(),current_setting('test.organization')::uuid)->>'can_promote')::boolean,true,'promotion only relies on official fields');
select lives_ok($$select public.promote_proposal_idea(auth.uid(),current_setting('test.organization')::uuid)$$,'promote with same Project identity');
select lives_ok($$select pg_temp.org('{"action":"add_task","task_id":"fc011000-0000-4000-8000-000000000004","title":"Locandina"}')$$,'Defined keeps custom tasks');
select throws_ok($$select pg_temp.org('{"action":"confirm_decision","kind":"location"}')$$,'42501',null,'Defined planner decisions collapse/read only');
reset role;
update public.proposals set starts_at=now()-interval '2 days',ends_at=now()-interval '1 day' where id=current_setting('test.organization')::uuid;
set local role authenticated;
select throws_ok($$select pg_temp.org('{"action":"set_task_done","task_id":"fc011000-0000-4000-8000-000000000004","done":true}')$$,'55000',null,'end freezes custom mutations');
select lives_ok($$select public.get_project_organization_v1(auth.uid(),current_setting('test.organization')::uuid)$$,'creator reads ended archive');
select set_config('request.jwt.claim.sub','fc010000-0000-4000-8000-000000000002',true);
select lives_ok($$select public.get_project_organization_v1(auth.uid(),current_setting('test.organization')::uuid)$$,'current member reads ended archive');
select lives_ok($$select public.leave_project(auth.uid(),current_setting('test.org_membership')::uuid)$$,'member leaves');
select throws_ok($$select public.get_project_organization_v1(auth.uid(),current_setting('test.organization')::uuid)$$,'42501',null,'historical chat entitlement cannot read current planner');
reset role;
select throws_ok($$update private.project_organization_tasks set parent_id='fc011000-0000-4000-8000-000000000002' where project_id=current_setting('test.organization')::uuid and id='fc011000-0000-4000-8000-000000000001'$$,'22023',null,'direct reparenting cannot create an indirect cycle');
select throws_ok($$update private.project_organization_tasks set title=repeat('x',161) where project_id=current_setting('test.organization')::uuid$$,'23514',null,'task title length is bounded at the table');
insert into private.project_organization_tasks(project_id,id,title,position,author_id,updated_by)
 select current_setting('test.organization')::uuid,gen_random_uuid(),'Synthetic bounded task',n,
 'fc010000-0000-4000-8000-000000000001','fc010000-0000-4000-8000-000000000001'
 from generate_series(1,120-(select count(*)::integer from private.project_organization_tasks where project_id=current_setting('test.organization')::uuid)) n;
select throws_ok($$insert into private.project_organization_tasks(project_id,id,title,position,author_id,updated_by) values(current_setting('test.organization')::uuid,gen_random_uuid(),'Task 121',121,'fc010000-0000-4000-8000-000000000001','fc010000-0000-4000-8000-000000000001')$$,'22023',null,'server enforces 120 total tasks including children');
select * from finish();
rollback;
