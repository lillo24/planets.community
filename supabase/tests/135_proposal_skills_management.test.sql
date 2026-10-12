begin;
select no_plan();
select has_function('public', 'update_proposal_skills', array['uuid','uuid','jsonb','uuid[]','text[]']);
select ok(has_function_privilege('authenticated', 'public.update_proposal_skills(uuid,uuid,jsonb,uuid[],text[])', 'EXECUTE'), 'authenticated explicit execution');
select ok(not has_function_privilege('anon', 'public.update_proposal_skills(uuid,uuid,jsonb,uuid[],text[])', 'EXECUTE'), 'anonymous denied');
select ok(not has_function_privilege('service_role', 'public.update_proposal_skills(uuid,uuid,jsonb,uuid[],text[])', 'EXECUTE'), 'no service-role execution');
select ok(not has_table_privilege('authenticated', 'public.proposal_skills', 'INSERT'), 'no direct skill inserts');
select ok(not has_table_privilege('authenticated', 'public.proposal_skills', 'DELETE'), 'no direct skill deletes');
select ok((select prosecdef from pg_proc where oid='public.update_proposal_skills(uuid,uuid,jsonb,uuid[],text[])'::regprocedure), 'narrow canonical definer');
select is((select proconfig::text from pg_proc where oid='public.update_proposal_skills(uuid,uuid,jsonb,uuid[],text[])'::regprocedure), '{"search_path=\"\""}', 'empty search path');
insert into auth.users(id,email) values ('8e010000-0000-4000-8000-000000000001', 'ui02-sql-0@planets.invalid');
insert into public.profiles(id,display_name) values ('8e010000-0000-4000-8000-000000000001', 'UI02 actor 0');
insert into auth.users(id,email) values ('8e010000-0000-4000-8000-000000000002', 'ui02-sql-1@planets.invalid');
insert into public.profiles(id,display_name) values ('8e010000-0000-4000-8000-000000000002', 'UI02 actor 1');
insert into auth.users(id,email) values ('8e010000-0000-4000-8000-000000000003', 'ui02-sql-2@planets.invalid');
insert into public.profiles(id,display_name) values ('8e010000-0000-4000-8000-000000000003', 'UI02 actor 2');
insert into auth.users(id,email) values ('8e010000-0000-4000-8000-000000000004', 'ui02-sql-3@planets.invalid');
insert into public.profiles(id,display_name) values ('8e010000-0000-4000-8000-000000000004', 'UI02 actor 3');
insert into public.profile_photos(profile_id,object_path,audience)
select id, id::text || '/8e030000-0000-4000-8000-000000000001.webp','interactions'
from public.profiles where id in ('8e010000-0000-4000-8000-000000000001','8e010000-0000-4000-8000-000000000002','8e010000-0000-4000-8000-000000000003','8e010000-0000-4000-8000-000000000004');
insert into public.proposals(id,creator_profile_id,lifecycle_state,title,summary,description,
starts_at,ends_at,event_timezone,country_code,locality,public_location_label,published_at)
values ('8e020000-0000-4000-8000-000000000001','8e010000-0000-4000-8000-000000000001','published','UI02 requirements','A complete summary','A complete description',
now()+interval '2 days',now()+interval '3 days','Europe/Rome','IT','Trento','Trento',now());
update public.projects set registration_capacity=12 where id='8e020000-0000-4000-8000-000000000001';
insert into public.proposal_meeting_details(proposal_id,exact_meeting_text,exact_location_visibility)
values ('8e020000-0000-4000-8000-000000000001','Private entrance instructions','participants');
insert into public.proposals(id,creator_profile_id,lifecycle_state,title)
values ('8e020000-0000-4000-8000-000000000002','8e010000-0000-4000-8000-000000000001','draft','UI02 draft');
create temp table ui02_before as select to_jsonb(p)-'updated_at' as data from public.proposals p where id='8e020000-0000-4000-8000-000000000001';
create temp table ui02_meeting_before as select to_jsonb(m)-'updated_at' as data from public.proposal_meeting_details m where proposal_id='8e020000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claim.sub','8e010000-0000-4000-8000-000000000001',true);
select throws_ok($$select public.update_proposal_skills('8e010000-0000-4000-8000-000000000001','8e020000-0000-4000-8000-000000000001','"{}"'::jsonb,'{}'::uuid[],'{}'::text[])$$,'22023',null,'serialized JSON string cannot replace the expected skill object');
select throws_ok($$select public.update_proposal_skills('8e010000-0000-4000-8000-000000000001','8e020000-0000-4000-8000-000000000001',null::jsonb,'{}'::uuid[],'{}'::text[])$$,'22023',null,'missing expected skill object rejected');
select lives_ok($$select public.update_proposal_skills('8e010000-0000-4000-8000-000000000001', '8e020000-0000-4000-8000-000000000001', '{}'::jsonb, array['d0000000-0000-4000-8001-000000000001'::uuid], array['required'])$$, 'Creator changes only skills');
select throws_ok($$select public.update_proposal_skills('8e010000-0000-4000-8000-000000000001', '8e020000-0000-4000-8000-000000000001', '{}'::jsonb, '{}'::uuid[], '{}'::text[])$$, '40001', null, 'stale skill snapshot rejected');
reset role;
select is((select to_jsonb(p)-'updated_at' from public.proposals p where id='8e020000-0000-4000-8000-000000000001'),(select data from ui02_before),'skill write preserves every other Proposal field');
select is((select to_jsonb(m)-'updated_at' from public.proposal_meeting_details m where proposal_id='8e020000-0000-4000-8000-000000000001'),(select data from ui02_meeting_before),'protected meeting content untouched');
select is((select registration_capacity from public.projects where id='8e020000-0000-4000-8000-000000000001'),12,'capacity untouched');
select is((select importance from public.proposal_skills where proposal_id='8e020000-0000-4000-8000-000000000001'),'required','Required value persisted');
select ok(exists(select 1 from private.outbox_events where event_type='proposal.updated' and payload->>'proposal_id'='8e020000-0000-4000-8000-000000000001'),'existing matching refresh event emitted');
set local role authenticated;
select set_config('request.jwt.claim.sub','8e010000-0000-4000-8000-000000000001',true);
select throws_ok($$select public.update_proposal_skills('8e010000-0000-4000-8000-000000000001', '8e020000-0000-4000-8000-000000000001', '{"d0000000-0000-4000-8001-000000000001":"required"}'::jsonb, null, array['useful'])$$, '22023', null, 'null skill list rejected atomically');
select throws_ok($$select public.update_proposal_skills('8e010000-0000-4000-8000-000000000001', '8e020000-0000-4000-8000-000000000001', '{"d0000000-0000-4000-8001-000000000001":"required"}'::jsonb, array['d0000000-0000-4000-8001-000000000001'::uuid], '{}'::text[])$$, '22023', null, 'mismatched arrays rejected atomically');
select throws_ok($$select public.update_proposal_skills('8e010000-0000-4000-8000-000000000001', '8e020000-0000-4000-8000-000000000001', '{"d0000000-0000-4000-8001-000000000001":"required"}'::jsonb, array['d0000000-0000-4000-8001-000000000001'::uuid,'d0000000-0000-4000-8001-000000000001'::uuid], array['required','useful'])$$, '22023', null, 'duplicate IDs rejected atomically');
select throws_ok($$select public.update_proposal_skills('8e010000-0000-4000-8000-000000000001', '8e020000-0000-4000-8000-000000000001', '{"d0000000-0000-4000-8001-000000000001":"required"}'::jsonb, array['d0000000-0000-4000-8001-000000000001'::uuid], array['essential'])$$, '22023', null, 'invalid importance rejected atomically');
select throws_ok($$select public.update_proposal_skills('8e010000-0000-4000-8000-000000000001', '8e020000-0000-4000-8000-000000000001', '{"d0000000-0000-4000-8001-000000000001":"required"}'::jsonb, array['ffffffff-ffff-4fff-8fff-ffffffffffff'::uuid], array['useful'])$$, '22023', null, 'unknown catalog ID rejected atomically');
select throws_ok($$select public.update_proposal_skills('8e010000-0000-4000-8000-000000000001', '8e020000-0000-4000-8000-000000000001', '{"d0000000-0000-4000-8001-000000000001":"required"}'::jsonb, array[null::uuid], array['useful'])$$, '22023', null, 'null skill ID rejected atomically');
select throws_ok($$select public.update_proposal_skills('8e010000-0000-4000-8000-000000000002', '8e020000-0000-4000-8000-000000000001', '{"d0000000-0000-4000-8001-000000000001":"required"}'::jsonb, '{}'::uuid[], '{}'::text[])$$, '42501', null, 'expected identity mismatch denied');
select set_config('ui02.co_token',(select invite_token from public.create_project_delegate_invitation('8e010000-0000-4000-8000-000000000001','8e020000-0000-4000-8000-000000000001','co_creator')),true);
select set_config('ui02.org_token',(select invite_token from public.create_project_delegate_invitation('8e010000-0000-4000-8000-000000000001','8e020000-0000-4000-8000-000000000001','co_organizer')),true);
select set_config('request.jwt.claim.sub','8e010000-0000-4000-8000-000000000002',true);
select set_config('ui02.co_delegate',public.accept_project_delegate_invitation('8e010000-0000-4000-8000-000000000002',current_setting('ui02.co_token'))::text,true);
select lives_ok($$select public.update_proposal_skills('8e010000-0000-4000-8000-000000000002', '8e020000-0000-4000-8000-000000000001', '{"d0000000-0000-4000-8001-000000000001":"required"}'::jsonb, array['d0000000-0000-4000-8001-000000000001'::uuid], array['useful'])$$, 'Co-creator retains structural skill rights');
select throws_ok($$select public.update_proposal_skills('8e010000-0000-4000-8000-000000000002', '8e020000-0000-4000-8000-000000000002', '{}'::jsonb, '{}'::uuid[], '{}'::text[])$$, '42501', null, 'Co-creator cannot edit Creator draft');
select set_config('request.jwt.claim.sub','8e010000-0000-4000-8000-000000000003',true);
select public.accept_project_delegate_invitation('8e010000-0000-4000-8000-000000000003',current_setting('ui02.org_token'));
select throws_ok($$select public.update_proposal_skills('8e010000-0000-4000-8000-000000000003', '8e020000-0000-4000-8000-000000000001', '{"d0000000-0000-4000-8001-000000000001":"useful"}'::jsonb, '{}'::uuid[], '{}'::text[])$$, '42501', null, 'Co-organizer gains no skills privilege');
select set_config('request.jwt.claim.sub','8e010000-0000-4000-8000-000000000004',true);
select throws_ok($$select public.update_proposal_skills('8e010000-0000-4000-8000-000000000004', '8e020000-0000-4000-8000-000000000001', '{"d0000000-0000-4000-8001-000000000001":"useful"}'::jsonb, '{}'::uuid[], '{}'::text[])$$, '42501', null, 'nonmanager gains no skills privilege');
select set_config('request.jwt.claim.sub','8e010000-0000-4000-8000-000000000001',true);
select lives_ok($$select public.update_own_proposal(
'8e010000-0000-4000-8000-000000000001','8e020000-0000-4000-8000-000000000001','Changed content','A complete summary','Concurrent description',
now()+interval '2 days',now()+interval '3 days','Europe/Rome','IT','Trento',null,'Trento',
'Private entrance instructions','participants',null::uuid[],null::text[])$$,
'content-only edit preserves locked current skills');
reset role;
select is((select importance from public.proposal_skills where proposal_id='8e020000-0000-4000-8000-000000000001'),'useful','old content editor cannot revert skills');
select is((select description from public.proposals where id='8e020000-0000-4000-8000-000000000001'),'Concurrent description','content edit still persists');
set local role authenticated;
select set_config('request.jwt.claim.sub','8e010000-0000-4000-8000-000000000001',true);
select lives_ok($$select public.update_proposal_skills('8e010000-0000-4000-8000-000000000001', '8e020000-0000-4000-8000-000000000001', '{"d0000000-0000-4000-8001-000000000001":"useful"}'::jsonb, '{}'::uuid[], '{}'::text[])$$, 'empty lists intentionally clear skills');
select public.revoke_project_delegate('8e010000-0000-4000-8000-000000000001',current_setting('ui02.co_delegate')::uuid);
select set_config('request.jwt.claim.sub','8e010000-0000-4000-8000-000000000002',true);
select throws_ok($$select public.update_proposal_skills('8e010000-0000-4000-8000-000000000002', '8e020000-0000-4000-8000-000000000001', '{}'::jsonb, '{}'::uuid[], '{}'::text[])$$, '42501', null, 'revoked Co-creator cannot save');
select set_config('request.jwt.claim.sub','8e010000-0000-4000-8000-000000000001',true);
select lives_ok($$select public.update_proposal_skills('8e010000-0000-4000-8000-000000000001', '8e020000-0000-4000-8000-000000000002', '{}'::jsonb, '{}'::uuid[], '{}'::text[])$$, 'Creator draft remains editable');
reset role;
update public.proposals set starts_at=now()-interval '1 hour' where id='8e020000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claim.sub','8e010000-0000-4000-8000-000000000001',true);
select throws_ok($$select public.update_proposal_skills('8e010000-0000-4000-8000-000000000001', '8e020000-0000-4000-8000-000000000001', '{}'::jsonb, '{}'::uuid[], '{}'::text[])$$, '55000', null, 'started Proposal is read-only');
reset role;
update public.proposals set lifecycle_state='cancelled',cancelled_at=now() where id='8e020000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claim.sub','8e010000-0000-4000-8000-000000000001',true);
select throws_ok($$select public.update_proposal_skills('8e010000-0000-4000-8000-000000000001', '8e020000-0000-4000-8000-000000000001', '{}'::jsonb, '{}'::uuid[], '{}'::text[])$$, '55000', null, 'cancelled Proposal is read-only');
reset role;
insert into public.proposals(id,creator_profile_id,title,summary,description)
values ('8e020000-0000-4000-8000-000000000003','8e010000-0000-4000-8000-000000000001','UI02 published Idea','An Idea without logistics','Keep the Idea planning boundary');
update public.proposals set definition_phase='idea',lifecycle_state='published',published_at=now()
where id='8e020000-0000-4000-8000-000000000003';
set local role authenticated;
select set_config('request.jwt.claim.sub','8e010000-0000-4000-8000-000000000001',true);
select lives_ok($$select public.update_proposal_skills('8e010000-0000-4000-8000-000000000001','8e020000-0000-4000-8000-000000000003','{}'::jsonb,array['d0000000-0000-4000-8001-000000000001'::uuid],array['required'])$$,'published Idea skills stay editable without logistics');
reset role;
select ok((select starts_at is null and ends_at is null and event_timezone is null and definition_phase='idea' from public.proposals where id='8e020000-0000-4000-8000-000000000003'),'skill write does not define Idea logistics');
select * from finish();
rollback;
