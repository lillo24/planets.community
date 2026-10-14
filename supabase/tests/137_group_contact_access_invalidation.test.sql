begin;
select no_plan();
insert into auth.users(id,email) select ('d1100000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'d-chat-tap-'||n||'@planets.invalid' from generate_series(1,4) n;
insert into public.profiles(id,display_name) select id,'Fictional D representative' from auth.users where email like 'd-chat-tap-%';
insert into private.community_groups(id,name,description,group_kind,volunteering_focus,publication_state,original_actor_id)
select ('d1110000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'Fictional contact group '||n,'A fictional group description for local tests.','informal',false,'published',('d1100000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid from generate_series(1,2) n;
insert into private.community_group_managers(group_id,profile_id,appointed_by_actor_id)
select id,original_actor_id,original_actor_id from private.community_groups where id::text like 'd111%';
insert into private.group_delegates(id,group_id,profile_id,initial_role,delegate_role,granted_by)
values('d1120000-0000-4000-8000-000000000001','d1110000-0000-4000-8000-000000000002','d1100000-0000-4000-8000-000000000003','co_organizer','co_organizer','d1100000-0000-4000-8000-000000000002');
create temp table d_chat_result(kind text,value jsonb); grant all on d_chat_result to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','d1100000-0000-4000-8000-000000000001',true);
select is(public.get_own_group_contact_sender('d1100000-0000-4000-8000-000000000001'),jsonb_build_object('profile_id','d1100000-0000-4000-8000-000000000001','display_name','Fictional D representative'),'sender context contains only exact self identity and name');
select throws_ok($$select public.get_own_group_contact_sender('d1100000-0000-4000-8000-000000000002')$$,'42501',null,'sender context cannot query another person');
insert into d_chat_result values('request',public.submit_group_contact_request('d1100000-0000-4000-8000-000000000001',gen_random_uuid(),'d1110000-0000-4000-8000-000000000001','d1110000-0000-4000-8000-000000000002','collaboration','Fictional collaboration','A private fictional contact summary.'));
select set_config('request.jwt.claim.sub','d1100000-0000-4000-8000-000000000003',true);
insert into d_chat_result values('chat',public.accept_group_contact_request('d1100000-0000-4000-8000-000000000003','d1130000-0000-4000-8000-000000000001',(select (value->>'request_id')::uuid from d_chat_result where kind='request')));
reset role;
select ok(not has_function_privilege(r,'private.group_contact_access_signal(uuid)','execute'),r||' cannot forge access hints') from unnest(array['anon','authenticated','service_role']) r;
select ok(not exists(select 1 from private.group_contact_admissions where group_id::text like 'd111%' and profile_id='d1100000-0000-4000-8000-000000000002'),'other manager has no admission');
delete from realtime.messages where event='group.contact_access_changed';
update private.group_delegates set revoked_at=clock_timestamp(),revoked_by='d1100000-0000-4000-8000-000000000002' where id='d1120000-0000-4000-8000-000000000001';
select ok(exists(select 1 from realtime.messages where event='group.contact_access_changed' and topic='group-contact:profile:d1100000-0000-4000-8000-000000000003'),'former own socket receives content-clearing hint');
select ok(exists(select 1 from realtime.messages where event='group.contact_access_changed' and topic='group-contact:profile:d1100000-0000-4000-8000-000000000001'),'other admitted participant revalidates read-only context');
select ok(not exists(select 1 from realtime.messages where event='group.contact_access_changed' and payload-'id'<>jsonb_build_object('profile_id',split_part(topic,':',3))), 'access hint contains only own recipient identity plus Realtime transport id');
set local role authenticated;
select set_config('request.jwt.claim.sub','d1100000-0000-4000-8000-000000000003',true);
select throws_ok($$select public.get_own_group_contact_conversation('d1100000-0000-4000-8000-000000000003',(select (value->>'chat_id')::uuid from d_chat_result where kind='chat'))$$,'42501',null,'hint cannot restore revoked body access');
select is(public.has_own_group_contact_admission('d1100000-0000-4000-8000-000000000003',(select (value->>'chat_id')::uuid from d_chat_result where kind='chat')),true,'former own admission metadata preserves safe leave');
select throws_ok($$select public.has_own_group_contact_admission('d1100000-0000-4000-8000-000000000002',(select (value->>'chat_id')::uuid from d_chat_result where kind='chat'))$$,'42501',null,'own metadata cannot impersonate another actor');
select set_config('request.jwt.claim.sub','d1100000-0000-4000-8000-000000000001',true);
select is(public.get_own_group_contact_request('d1100000-0000-4000-8000-000000000001',(select (value->>'request_id')::uuid from d_chat_result where kind='request'))->>'public_project_title',null::text,'request without public reference contains no reference title');
select set_config('request.jwt.claim.sub','d1100000-0000-4000-8000-000000000002',true);
select is(public.has_own_group_contact_admission('d1100000-0000-4000-8000-000000000002',(select (value->>'chat_id')::uuid from d_chat_result where kind='chat')),false,'another manager cannot acquire an own seat');
reset role;
insert into private.group_delegates(group_id,profile_id,initial_role,delegate_role,granted_by)
values('d1110000-0000-4000-8000-000000000002','d1100000-0000-4000-8000-000000000003','co_creator','co_creator','d1100000-0000-4000-8000-000000000002');
select ok(not private.group_contact_can_read((select (value->>'chat_id')::uuid from d_chat_result where kind='chat'),'d1100000-0000-4000-8000-000000000003'),'new grant hint never restores old episode');
delete from realtime.messages where event='group.contact_access_changed';
update public.profiles set display_name='Updated fictional representative' where id='d1100000-0000-4000-8000-000000000001';
select ok(exists(select 1 from realtime.messages where event='group.contact_access_changed' and topic='group-contact:profile:d1100000-0000-4000-8000-000000000003'),'identity update invalidates already displayed sender labels');
select ok(not exists(select 1 from realtime.messages where event='group.contact_access_changed' and payload::text like '%Updated%'),'hint contains no display name');
-- Seed an already elapsed immutable episode, rather than rewriting provenance.
with expired as(insert into private.group_contact_requests(source_group_id,target_group_id,submitter_id,purpose,title,note,created_at,expires_at)
  values('d1110000-0000-4000-8000-000000000001','d1110000-0000-4000-8000-000000000002','d1100000-0000-4000-8000-000000000001','idea','Expiring synthetic proposal','A synthetic proposal with an elapsed deadline.',clock_timestamp()-interval '8 days',clock_timestamp()-interval '1 day') returning id)
insert into d_chat_result select 'expires',jsonb_build_object('request_id',id) from expired;
set local role authenticated;
select set_config('request.jwt.claim.sub','d1100000-0000-4000-8000-000000000001',true);
select is(public.get_own_group_contact_request('d1100000-0000-4000-8000-000000000001',(select (value->>'request_id')::uuid from d_chat_result where kind='expires'))->>'status','expired','expiry is a canonical clock state');
select is(public.get_own_group_contact_request('d1100000-0000-4000-8000-000000000001',(select (value->>'request_id')::uuid from d_chat_result where kind='expires'))->>'can_withdraw','true','own safe withdrawal remains available after triage expiry');
select lives_ok($$select public.withdraw_group_contact_request('d1100000-0000-4000-8000-000000000001',gen_random_uuid(),(select (value->>'request_id')::uuid from d_chat_result where kind='expires'))$$,'expired safe exit agrees with projection');
reset role;
select * from finish();
rollback;
