begin;
select no_plan();
select ok(not has_table_privilege(r,'private.'||t,p),r||' cannot '||p||' '||t)
 from unnest(array['anon','authenticated','service_role'])r
 cross join unnest(array['cocreate_categories','cocreate_community_proposals','cocreate_community_interests','cocreate_community_identity','cocreate_meetings','cocreate_meeting_attendance','cocreate_filling_notifications','cocreate_filling_progress'])t
 cross join unnest(array['SELECT','INSERT','UPDATE','DELETE'])p;
select ok(relrowsecurity,relname||' has RLS') from pg_class where relnamespace='private'::regnamespace
 and relname in('cocreate_categories','cocreate_community_proposals','cocreate_community_interests','cocreate_community_identity','cocreate_meetings','cocreate_meeting_attendance','cocreate_filling_notifications','cocreate_filling_progress');
select ok(not has_function_privilege(r,oid,'EXECUTE'),r||' cannot execute private '||proname)
 from pg_proc cross join unnest(array['anon','authenticated','service_role'])r where pronamespace='private'::regnamespace
 and (proname like 'cocreate_%' or proname='process_cocreate_filling_batch');
select ok(not has_function_privilege('anon',signature,'EXECUTE'),'guest cannot mutate/read own '||signature)
 from unnest(array['public.propose_cocreate_community(uuid,uuid,text,text,text,text)',
 'public.mutate_cocreate_community_interest(uuid,uuid,uuid,text)','public.list_own_cocreate_community_interests(uuid,integer,timestamptz,uuid)',
 'public.schedule_cocreate_meeting(uuid,uuid,uuid,timestamptz,integer,uuid,uuid)',
 'public.mutate_cocreate_meeting(uuid,uuid,uuid,uuid,uuid,uuid,text)',
 'public.get_cocreate_current_meeting(uuid,uuid,uuid)',
 'public.list_own_notifications_with_cocreate(uuid,integer,timestamptz,uuid)',
 'public.moderate_cocreate_community_proposal(uuid,uuid,uuid,bigint,text)'])signature;
select is(private.cocreate_normalize(E'  VaLoRaNt\t  Community  '),'valorant community','case and whitespace normalize consistently');
select is((select community_activation_threshold from private.cocreate_settings),3,'three eligible distinct supporters by default');
select is((select count(*)::int from private.cocreate_categories),7,'small bounded curated starter directory');
select ok(not (select enabled from private.cocreate_settings),'new schema never enables server gate');
select throws_ok($$select public.list_cocreate_categories()$$,'42501',null,'gate OFF denies directory');
select throws_ok($$select public.list_cocreate_communities('videogames')$$,'42501',null,'gate OFF denies nested discovery');
select ok(pg_get_functiondef('public.process_notification_outbox_batch(integer)'::regprocedure) like '%private.process_cocreate_filling_batch%'
 and pg_get_functiondef('public.process_notification_outbox_batch(integer)'::regprocedure) like '%private.resolve_notification_event(source_event.id)%'
 and pg_get_functiondef('public.process_notification_outbox_batch(integer)'::regprocedure) like '%get diagnostics inserted_count = row_count;%','worker composes filling and preserves atomic legacy claim');
update private.cocreate_settings set enabled=true;
select is(jsonb_array_length(public.list_cocreate_categories()),7,'active categories can be browsed');
select throws_ok($$select public.list_cocreate_communities('videogames',p_limit=>51)$$,'22023',null,'directory remains bounded');
select throws_ok($$select public.list_cocreate_communities('videogames',p_before_id=>gen_random_uuid())$$,'22023',null,'partial cursor denied');
insert into auth.users(id,email) values
 ('cc080000-0000-4000-8000-000000000001','community-a@planets.invalid'),
 ('cc080000-0000-4000-8000-000000000002','community-b@planets.invalid'),
 ('cc080000-0000-4000-8000-000000000003','community-c@planets.invalid');
insert into public.profiles(id,display_name) select id,'Synthetic community tester' from auth.users where id::text like 'cc080000%';
insert into private.policy_acceptances(account_id,bundle_version) select id,'POLICY01-2026-10-08-v1' from auth.users where id::text like 'cc080000%';
select set_config('request.jwt.claim.sub','cc080000-0000-4000-8000-000000000001',true);
select throws_ok($$select public.propose_cocreate_community('cc080000-0000-4000-8000-000000000002',gen_random_uuid(),'videogames','Synthetic','Trento')$$,'42501',null,'actor cannot impersonate another proposer');
select set_config('cc.proposed',public.propose_cocreate_community('cc080000-0000-4000-8000-000000000001',gen_random_uuid(),'videogames','Synthetic Valorant','Synthetic Trento')::text,true);
select set_config('cc.proposal',current_setting('cc.proposed')::jsonb->>'proposal_id',true);
select is(public.get_cocreate_community_proposal(current_setting('cc.proposal')::uuid)->>'interested_count','1','initial proposer contributes exactly once');
select ok(not (public.get_cocreate_community_proposal(current_setting('cc.proposal')::uuid) ? 'proposer_id'),'public proposal omits actor identity');
select ok(not (public.get_cocreate_community_proposal(current_setting('cc.proposal')::uuid) ? 'supporters'),'public proposal omits supporter roster');
select set_config('request.jwt.claim.sub','cc080000-0000-4000-8000-000000000002',true);
select public.mutate_cocreate_community_interest('cc080000-0000-4000-8000-000000000002',gen_random_uuid(),current_setting('cc.proposal')::uuid,'interest');
select is(public.get_cocreate_community_proposal(current_setting('cc.proposal')::uuid)->>'state','pending','one additional supporter is insufficient');
select set_config('cc.case',(select case_id::text from public.submit_moderation_report('cc080000-0000-4000-8000-000000000002',gen_random_uuid(),'spam','Synthetic proposal report evidence','cocreate_community_proposal',current_setting('cc.proposal')::uuid)),true);
select is((select cocreate_evidence->>'proposal_id' from private.moderation_cases where id=current_setting('cc.case')::uuid),current_setting('cc.proposal'),'report snapshots the exact proposal');
select throws_ok($$select public.get_moderation_case_cocreate_proposal('cc080000-0000-4000-8000-000000000002',current_setting('cc.case')::uuid)$$,'42501',null,'ordinary supporter gains no staff access');
select set_config('request.jwt.claim.sub','cc080000-0000-4000-8000-000000000003',true);
select public.mutate_cocreate_community_interest('cc080000-0000-4000-8000-000000000003',gen_random_uuid(),current_setting('cc.proposal')::uuid,'interest');
select set_config('cc.hub',public.get_cocreate_community_proposal(current_setting('cc.proposal')::uuid)->>'hub_id',true);
select is((select count(*)::int from private.cocreate_rooms where hub_id=current_setting('cc.hub')::uuid and kind='general'),1,'activation creates exactly one General');
select is((select count(*)::int from private.cocreate_room_episodes e join private.cocreate_rooms r on r.id=e.room_id where r.hub_id=current_setting('cc.hub')::uuid),0,'activation never enrolls supporters');
select is((select count(*)::int from private.cocreate_rooms where hub_id=current_setting('cc.hub')::uuid and kind='numbered'),0,'activation never creates a numbered group');
select set_config('request.jwt.claim.sub','cc080000-0000-4000-8000-000000000001',true);
select set_config('cc.ha',public.mutate_cocreate_hub('cc080000-0000-4000-8000-000000000001',gen_random_uuid(),current_setting('cc.hub')::uuid,'join')::text,true);
select throws_ok($$select public.schedule_cocreate_meeting('cc080000-0000-4000-8000-000000000001',gen_random_uuid(),current_setting('cc.hub')::uuid,clock_timestamp()-interval '1 hour',5)$$,'22023',null,'past meeting denied');
select throws_ok($$select public.schedule_cocreate_meeting('cc080000-0000-4000-8000-000000000001',gen_random_uuid(),current_setting('cc.hub')::uuid,clock_timestamp()+interval '400 days',5)$$,'22023',null,'unbounded future meeting denied');
select throws_ok($$select public.schedule_cocreate_meeting('cc080000-0000-4000-8000-000000000001',gen_random_uuid(),current_setting('cc.hub')::uuid,clock_timestamp()+interval '1 day',1)$$,'22023',null,'meeting capacity includes creator and retains 2-50 bounds');
select set_config('cc.meeting',public.schedule_cocreate_meeting('cc080000-0000-4000-8000-000000000001',gen_random_uuid(),current_setting('cc.hub')::uuid,clock_timestamp()+interval '1 day',3)::text,true);
select is(private.cocreate_recruitment_projection((current_setting('cc.meeting')::jsonb->>'recruitment_id')::uuid)->>'capacity','3','card counts meeting places');
select is(private.cocreate_recruitment_projection((current_setting('cc.meeting')::jsonb->>'recruitment_id')::uuid)->>'occupied','1','creator attends initial meeting');
select ok(private.cocreate_recruitment_projection((current_setting('cc.meeting')::jsonb->>'recruitment_id')::uuid) ? 'starts_at','card carries scheduled time');
select is((select capacity from private.cocreate_rooms where id=(current_setting('cc.meeting')::jsonb->>'room_id')::uuid),50,'persistent chat capacity is independent');
select throws_ok($$select public.mutate_cocreate_numbered_group('cc080000-0000-4000-8000-000000000001',gen_random_uuid(),current_setting('cc.hub')::uuid,'capacity',(current_setting('cc.meeting')::jsonb->>'room_id')::uuid,(current_setting('cc.meeting')::jsonb->>'episode_id')::uuid,3,null,(select version from private.cocreate_rooms where id=(current_setting('cc.meeting')::jsonb->>'room_id')::uuid))$$,'PT409',null,'legacy capacity controls cannot introduce a second RSVP limit');
select is((select count(*)::int from private.outbox_events where event_type='cocreate.filling_posted' and payload->>'recruitment_id'=current_setting('cc.meeting')::jsonb->>'recruitment_id'),1,'one identifier-only outbox event per card');
select is((select (select count(*)::int from jsonb_object_keys(payload)) from private.outbox_events where event_type='cocreate.filling_posted' and payload->>'recruitment_id'=current_setting('cc.meeting')::jsonb->>'recruitment_id'),1,'no body, roster or time in outbox payload');
select set_config('cc.negative',public.propose_cocreate_community('cc080000-0000-4000-8000-000000000001',gen_random_uuid(),'art','Synthetic privacy proposal','Synthetic Trento')::text,true);
select set_config('cc.pending',current_setting('cc.negative')::jsonb->>'proposal_id',true);
update private.cocreate_categories set active=false where id='art';
select is(public.get_cocreate_community_proposal(current_setting('cc.pending')::uuid),null::jsonb,'disabled category hides pending proposals');
select throws_ok($$select public.propose_cocreate_community('cc080000-0000-4000-8000-000000000001',gen_random_uuid(),'art','Synthetic disabled','Synthetic Trento')$$,'42501',null,'disabled category cannot accept a new proposal');
update private.cocreate_categories set active=true where id='art';
select set_config('request.jwt.claim.sub','cc080000-0000-4000-8000-000000000002',true);
update auth.users set banned_until=clock_timestamp()+interval '1 day' where id='cc080000-0000-4000-8000-000000000002';
select throws_ok($$select public.mutate_cocreate_community_interest('cc080000-0000-4000-8000-000000000002',gen_random_uuid(),current_setting('cc.pending')::uuid,'interest')$$,'42501',null,'banned actor cannot support');
update auth.users set banned_until=null where id='cc080000-0000-4000-8000-000000000002';
select public.block_user('cc080000-0000-4000-8000-000000000002','cc080000-0000-4000-8000-000000000001');
select throws_ok($$select public.mutate_cocreate_community_interest('cc080000-0000-4000-8000-000000000002',gen_random_uuid(),current_setting('cc.pending')::uuid,'interest')$$,'42501',null,'blocked pair cannot support');
select is(public.get_cocreate_community_proposal(current_setting('cc.pending')::uuid),null::jsonb,'blocked actor loses proposal detail');
select public.unblock_user('cc080000-0000-4000-8000-000000000002','cc080000-0000-4000-8000-000000000001');
delete from private.policy_acceptances where account_id='cc080000-0000-4000-8000-000000000002';
select throws_ok($$select public.mutate_cocreate_community_interest('cc080000-0000-4000-8000-000000000002',gen_random_uuid(),current_setting('cc.pending')::uuid,'interest')$$,'42501',null,'unaccepted policy cannot support');
insert into private.policy_acceptances(account_id,bundle_version) values('cc080000-0000-4000-8000-000000000002','POLICY01-2026-10-08-v1');
select public.mutate_cocreate_community_interest('cc080000-0000-4000-8000-000000000002',gen_random_uuid(),current_setting('cc.pending')::uuid,'interest');
select public.mutate_cocreate_community_interest('cc080000-0000-4000-8000-000000000002',gen_random_uuid(),current_setting('cc.pending')::uuid,'withdraw');
select is(public.get_cocreate_community_proposal(current_setting('cc.pending')::uuid)->>'interested_count','1','withdrawn supporter no longer counts');
select throws_ok($$select public.mutate_cocreate_community_interest('cc080000-0000-4000-8000-000000000002',gen_random_uuid(),current_setting('cc.pending')::uuid,'cancel')$$,'42501',null,'supporter cannot cancel someone else’s proposal');
select set_config('request.jwt.claim.sub','cc080000-0000-4000-8000-000000000001',true);
update private.cocreate_community_proposals set expires_at=clock_timestamp()-interval '1 second',created_at=clock_timestamp()-interval '2 days' where id=current_setting('cc.pending')::uuid;
select is(public.get_cocreate_community_proposal(current_setting('cc.pending')::uuid),null::jsonb,'expired pending text is not public');
select throws_ok($$select public.mutate_cocreate_community_interest('cc080000-0000-4000-8000-000000000001',gen_random_uuid(),current_setting('cc.pending')::uuid,'interest')$$,'PT409',null,'expired proposal cannot activate');
select * from finish();
rollback;
