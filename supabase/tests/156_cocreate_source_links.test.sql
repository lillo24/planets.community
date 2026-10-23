begin;
select no_plan();
select ok(not has_table_privilege(r,t,p),r||' cannot '||p||' '||t)
 from unnest(array['anon','authenticated','service_role'])r cross join unnest(array['private.cocreate_post_groups','private.cocreate_project_sources'])t
 cross join unnest(array['SELECT','INSERT','UPDATE','DELETE'])p;
select ok(not has_function_privilege('authenticated',oid,'execute'),proname||' remains private') from pg_proc
 where pronamespace='private'::regnamespace and proname in('cocreate_linked_group','cocreate_post_group_signal','cocreate_source_change_signal');
update private.cocreate_settings set enabled=true;
insert into private.cocreate_topics(id,label,active) values('cd020000-0000-4000-8000-000000000001','Synthetic source links',true);
insert into private.cocreate_hubs(id,topic_id,locality,active) values('cd020000-0000-4000-8000-000000000002','cd020000-0000-4000-8000-000000000001','Synthetic sources',true);
insert into auth.users(id,email) values
 ('cd020000-0000-4000-8000-000000000010','cocreate-source-a@planets.invalid'),
 ('cd020000-0000-4000-8000-000000000011','cocreate-source-b@planets.invalid'),
 ('cd020000-0000-4000-8000-000000000012','cocreate-source-c@planets.invalid');
insert into public.profiles(id,display_name) select id,'Synthetic source person' from auth.users where id::text like 'cd020000%';
insert into private.policy_acceptances(account_id,bundle_version) select id,'POLICY01-2026-10-08-v1' from auth.users where id::text like 'cd020000%';
insert into private.cocreate_posts(id,author_id,title,body,locality,topic_id,state,expires_at) values
 ('cd020000-0000-4000-8000-000000000003','cd020000-0000-4000-8000-000000000010','Synthetic source post','Public text only','Synthetic sources','cd020000-0000-4000-8000-000000000001','open',clock_timestamp()+interval '30 days');
select set_config('cs.hub','cd020000-0000-4000-8000-000000000002',true);
select set_config('cs.post','cd020000-0000-4000-8000-000000000003',true);
select set_config('request.jwt.claim.sub','cd020000-0000-4000-8000-000000000010',true);
select public.mutate_cocreate_hub('cd020000-0000-4000-8000-000000000010',gen_random_uuid(),current_setting('cs.hub')::uuid,'join');
select set_config('cs.group',public.mutate_cocreate_numbered_group('cd020000-0000-4000-8000-000000000010',gen_random_uuid(),current_setting('cs.hub')::uuid,'create')::text,true);
select set_config('cs.room',current_setting('cs.group')::jsonb->>'room_id',true);
select set_config('cs.ep',current_setting('cs.group')::jsonb->>'episode_id',true);
select is(jsonb_array_length(public.list_own_cocreate_manageable_groups('cd020000-0000-4000-8000-000000000010')),1,'Only current managed numbered groups are selectable');
select set_config('cs.link_command',gen_random_uuid()::text,true);
select set_config('cs.link',public.mutate_cocreate_post_group('cd020000-0000-4000-8000-000000000010',current_setting('cs.link_command')::uuid,current_setting('cs.post')::uuid,1,'link',current_setting('cs.hub')::uuid,current_setting('cs.room')::uuid,current_setting('cs.ep')::uuid)::text,true);
select is(public.mutate_cocreate_post_group('cd020000-0000-4000-8000-000000000010',current_setting('cs.link_command')::uuid,current_setting('cs.post')::uuid,1,'link',current_setting('cs.hub')::uuid,current_setting('cs.room')::uuid,current_setting('cs.ep')::uuid),current_setting('cs.link')::jsonb,'Exact source retry returns one reference/version');
select throws_ok($$select public.mutate_cocreate_post_group('cd020000-0000-4000-8000-000000000010',current_setting('cs.link_command')::uuid,current_setting('cs.post')::uuid,1,'clear')$$,'22023',null,'Source command UUID cannot change intent');
select throws_ok($$select public.mutate_cocreate_post_group('cd020000-0000-4000-8000-000000000010',gen_random_uuid(),current_setting('cs.post')::uuid,1,'clear')$$,'PT409',null,'Source CAS rejects stale post version');
select is(public.get_own_cocreate_post_link('cd020000-0000-4000-8000-000000000010',current_setting('cs.post')::uuid)->'link'->'group'->>'occupied','1','Linking copies no membership');
select set_config('request.jwt.claim.sub','cd020000-0000-4000-8000-000000000011',true);
select throws_ok($$select public.get_own_cocreate_post_link('cd020000-0000-4000-8000-000000000011',current_setting('cs.post')::uuid)$$,'42501',null,'Another author cannot inspect/manage source context');
select set_config('cs.interest',(public.mutate_cocreate_interest('cd020000-0000-4000-8000-000000000011',gen_random_uuid(),current_setting('cs.post')::uuid,'request',null,'Private note must stay private')->>'interest_id'),true);
select set_config('request.jwt.claim.sub','cd020000-0000-4000-8000-000000000010',true);
select set_config('cs.contact',(public.mutate_cocreate_interest('cd020000-0000-4000-8000-000000000010',gen_random_uuid(),current_setting('cs.post')::uuid,'accept',current_setting('cs.interest')::uuid)->>'contact_id'),true);
select set_config('request.jwt.claim.sub','cd020000-0000-4000-8000-000000000011',true);
select is(public.get_cocreate_contact_group('cd020000-0000-4000-8000-000000000011',current_setting('cs.contact')::uuid)->'link'->'group'->>'room_id',current_setting('cs.room'),'Accepted contact gets only a reviewed source option');
select is((select count(*) from private.cocreate_room_episodes where actor_id='cd020000-0000-4000-8000-000000000011'),0::bigint,'Acceptance and source linking enroll nobody');
select throws_ok($$select public.create_cocreate_project_draft('cd020000-0000-4000-8000-000000000011',gen_random_uuid(),current_setting('cs.hub')::uuid,current_setting('cs.room')::uuid,current_setting('cs.ep')::uuid)$$,'42501',null,'A source reference grants no creator authority');
select set_config('request.jwt.claim.sub','cd020000-0000-4000-8000-000000000012',true);
select throws_ok($$select public.get_cocreate_contact_group('cd020000-0000-4000-8000-000000000012',current_setting('cs.contact')::uuid)$$,'42501',null,'Outsider cannot use contact link reader');
select set_config('request.jwt.claim.sub','cd020000-0000-4000-8000-000000000010',true);
select set_config('cs.draft_command',gen_random_uuid()::text,true);
select set_config('cs.draft',public.create_cocreate_project_draft('cd020000-0000-4000-8000-000000000010',current_setting('cs.draft_command')::uuid,current_setting('cs.hub')::uuid,current_setting('cs.room')::uuid,current_setting('cs.ep')::uuid)::text,true);
select is(public.create_cocreate_project_draft('cd020000-0000-4000-8000-000000000010',current_setting('cs.draft_command')::uuid,current_setting('cs.hub')::uuid,current_setting('cs.room')::uuid,current_setting('cs.ep')::uuid),current_setting('cs.draft')::jsonb,'Lost draft reply creates no second Project');
select is((select creator_profile_id from public.proposals where id=(current_setting('cs.draft')::jsonb->>'proposal_id')::uuid),'cd020000-0000-4000-8000-000000000010'::uuid,'Native personal owner is unchanged');
select set_config('cs.foreign_command',gen_random_uuid()::text,true);
select public.create_editor_proposal_draft('cd020000-0000-4000-8000-000000000010',current_setting('cs.foreign_command')::uuid,null,null,null,null,null,'Europe/Rome',null,null,null,null,null,'participants',array[]::uuid[],array[]::text[],null,false);
select throws_ok($$select public.create_cocreate_project_draft('cd020000-0000-4000-8000-000000000010',current_setting('cs.foreign_command')::uuid,current_setting('cs.hub')::uuid,current_setting('cs.room')::uuid,current_setting('cs.ep')::uuid)$$,'22023',null,'An unrelated native draft command cannot be repurposed to a source reference');
select ok(not exists(select 1 from public.proposals where id=(current_setting('cs.draft')::jsonb->>'proposal_id')::uuid and (title is not null or description is not null or locality is not null)),'No source title/private text/locality copied to native draft');
select is((select exact_meeting_text from public.get_own_proposal('cd020000-0000-4000-8000-000000000010',(current_setting('cs.draft')::jsonb->>'proposal_id')::uuid)),null::text,'No private meeting text copied to native draft');
select is(jsonb_array_length(public.list_cocreate_group_projects('cd020000-0000-4000-8000-000000000010',current_setting('cs.room')::uuid,current_setting('cs.ep')::uuid)),0,'Personal unpublished draft is not listed to the group');
select is((select count(*) from private.cocreate_project_sources where room_id=current_setting('cs.room')::uuid),1::bigint,'Only minimal private correlation is stored');
select is((select count(*) from private.cocreate_room_episodes where room_id=current_setting('cs.room')::uuid and ended_at is null),1::bigint,'Native draft creation copies no crew');
select public.mutate_cocreate_post_group('cd020000-0000-4000-8000-000000000010',gen_random_uuid(),current_setting('cs.post')::uuid,2,'clear');
select is(public.get_own_cocreate_post_link('cd020000-0000-4000-8000-000000000010',current_setting('cs.post')::uuid)->'link','null'::jsonb,'Explicit unlink leaves ordinary post/contact intact');
select public.mutate_cocreate_post_group('cd020000-0000-4000-8000-000000000010',gen_random_uuid(),current_setting('cs.post')::uuid,3,'link',current_setting('cs.hub')::uuid,current_setting('cs.room')::uuid,current_setting('cs.ep')::uuid);
select public.mutate_cocreate_numbered_group('cd020000-0000-4000-8000-000000000010',gen_random_uuid(),current_setting('cs.hub')::uuid,'leave',current_setting('cs.room')::uuid,current_setting('cs.ep')::uuid);
select is(public.get_own_cocreate_post_link('cd020000-0000-4000-8000-000000000010',current_setting('cs.post')::uuid)->'link',jsonb_build_object('state','unavailable'),'Archived source keeps a non-actionable reference without current counts');
select is(public.create_cocreate_project_draft('cd020000-0000-4000-8000-000000000010',current_setting('cs.draft_command')::uuid,current_setting('cs.hub')::uuid,current_setting('cs.room')::uuid,current_setting('cs.ep')::uuid),current_setting('cs.draft')::jsonb,'Source departure does not lose an already-created personal draft');
select throws_ok($$select public.create_cocreate_project_draft('cd020000-0000-4000-8000-000000000010',gen_random_uuid(),current_setting('cs.hub')::uuid,current_setting('cs.room')::uuid,current_setting('cs.ep')::uuid)$$,'42501',null,'An old creator episode cannot create another draft');
update private.cocreate_settings set enabled=false;
select throws_ok($$select public.get_own_cocreate_post_link('cd020000-0000-4000-8000-000000000010',current_setting('cs.post')::uuid)$$,'42501',null,'Gate OFF denies source metadata without changing native draft authority');
select * from finish();
rollback;
