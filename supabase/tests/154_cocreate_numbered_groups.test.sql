begin;
select no_plan();
select ok(not has_table_privilege(r,'private.cocreate_room_exclusions',p),r||' cannot '||p||' removal barriers')
 from unnest(array['anon','authenticated','service_role'])r cross join unnest(array['SELECT','INSERT','UPDATE','DELETE'])p;
select ok(not has_function_privilege('authenticated',oid,'execute'),proname||' helper is private')
 from pg_proc where pronamespace='private'::regnamespace and proname like '%cocreate%';
select ok((select prosrc not like '%public.%' and prosrc not like '%auth.%' from pg_proc
 where oid='private.cocreate_end_erased_memberships(uuid)'::regprocedure),'Erasure convergence touches no profile/Auth/bootstrap state');
update private.cocreate_settings set enabled=true;
insert into private.cocreate_topics(id,label,active) values('cc030000-0000-4000-8000-000000000001','Synthetic numbered',true);
insert into private.cocreate_hubs(id,topic_id,locality,active) values
 ('cc030000-0000-4000-8000-000000000002','cc030000-0000-4000-8000-000000000001','Trento',true),
 ('cc030000-0000-4000-8000-000000000003','cc030000-0000-4000-8000-000000000001','Rovereto',true);
insert into auth.users(id,email) values
 ('cc030000-0000-4000-8000-000000000010','cocreate-number-a@planets.invalid'),
 ('cc030000-0000-4000-8000-000000000011','cocreate-number-b@planets.invalid'),
 ('cc030000-0000-4000-8000-000000000012','cocreate-number-c@planets.invalid'),
 ('cc030000-0000-4000-8000-000000000013','cocreate-number-staff@planets.invalid');
insert into public.profiles(id,display_name) select id,'Synthetic numbered person' from auth.users where id::text like 'cc030000%';
insert into private.policy_acceptances(account_id,bundle_version) select id,'POLICY01-2026-10-08-v1' from auth.users where id::text like 'cc030000%';
select set_config('cocreate.number.hub','cc030000-0000-4000-8000-000000000002',true);
select set_config('request.jwt.claim.sub','cc030000-0000-4000-8000-000000000010',true);
select throws_ok($$select public.mutate_cocreate_numbered_group('cc030000-0000-4000-8000-000000000010',gen_random_uuid(),current_setting('cocreate.number.hub')::uuid,'create')$$,
 '42501',null,'Creating a numbered group never auto-joins its hub');
select set_config('cocreate.number.hub_a',(public.mutate_cocreate_hub('cc030000-0000-4000-8000-000000000010',gen_random_uuid(),current_setting('cocreate.number.hub')::uuid,'join')->>'episode_id'),true);
select set_config('cocreate.number.create',gen_random_uuid()::text,true);
select set_config('cocreate.number.first',public.mutate_cocreate_numbered_group('cc030000-0000-4000-8000-000000000010',current_setting('cocreate.number.create')::uuid,current_setting('cocreate.number.hub')::uuid,'create')::text,true);
select is((current_setting('cocreate.number.first')::jsonb->>'number'),'1','Stable first number allocated by locked hub');
select is((current_setting('cocreate.number.first')::jsonb->>'capacity'),'5','Experimental creation defaults to capacity five');
select is(public.mutate_cocreate_numbered_group('cc030000-0000-4000-8000-000000000010',current_setting('cocreate.number.create')::uuid,current_setting('cocreate.number.hub')::uuid,'create'),current_setting('cocreate.number.first')::jsonb,'Exact create retry returns same room/number/episode');
select throws_ok($$select public.mutate_cocreate_numbered_group('cc030000-0000-4000-8000-000000000010',current_setting('cocreate.number.create')::uuid,current_setting('cocreate.number.hub')::uuid,'create',null,null,4)$$,
 '22023',null,'Changed capacity intent cannot reuse a creation UUID');
select set_config('cocreate.number.room',(current_setting('cocreate.number.first')::jsonb->>'room_id'),true);
select set_config('cocreate.number.a_episode',(current_setting('cocreate.number.first')::jsonb->>'episode_id'),true);
select is(public.get_cocreate_numbered_group(current_setting('cocreate.number.room')::uuid)->>'occupied','1','Creator counts toward occupied capacity');
select ok(not(public.get_cocreate_numbered_group(current_setting('cocreate.number.room')::uuid)?|array['manager_id','manager_profile_id','episode_id','members','messages']),'Public capacity has no roster/manager/transcript');
select set_config('cocreate.number.second',public.mutate_cocreate_numbered_group('cc030000-0000-4000-8000-000000000010',gen_random_uuid(),current_setting('cocreate.number.hub')::uuid,'create',null,null,2)::text,true);
select is(current_setting('cocreate.number.second')::jsonb->>'number','2','Second creation never derives number from visible length');
select set_config('request.jwt.claim.sub','cc030000-0000-4000-8000-000000000011',true);
select throws_ok($$select public.mutate_cocreate_numbered_group('cc030000-0000-4000-8000-000000000011',gen_random_uuid(),current_setting('cocreate.number.hub')::uuid,'join',current_setting('cocreate.number.room')::uuid)$$,
 '42501',null,'Numbered admission requires separate explicit hub membership');
select set_config('cocreate.number.hub_b',(public.mutate_cocreate_hub('cc030000-0000-4000-8000-000000000011',gen_random_uuid(),current_setting('cocreate.number.hub')::uuid,'join')->>'episode_id'),true);
select throws_ok($$select public.get_cocreate_room_page('cc030000-0000-4000-8000-000000000011',current_setting('cocreate.number.room')::uuid,current_setting('cocreate.number.a_episode')::uuid)$$,
 '42501',null,'Hub membership grants no child transcript');
select set_config('cocreate.number.b_episode',(public.mutate_cocreate_numbered_group('cc030000-0000-4000-8000-000000000011',gen_random_uuid(),current_setting('cocreate.number.hub')::uuid,'join',current_setting('cocreate.number.room')::uuid)->>'episode_id'),true);
select set_config('request.jwt.claim.sub','cc030000-0000-4000-8000-000000000012',true);
select public.mutate_cocreate_hub('cc030000-0000-4000-8000-000000000012',gen_random_uuid(),current_setting('cocreate.number.hub')::uuid,'join');
select set_config('cocreate.number.c_episode',(public.mutate_cocreate_numbered_group('cc030000-0000-4000-8000-000000000012',gen_random_uuid(),current_setting('cocreate.number.hub')::uuid,'join',current_setting('cocreate.number.room')::uuid)->>'episode_id'),true);
select set_config('request.jwt.claim.sub','cc030000-0000-4000-8000-000000000010',true);
select throws_ok($$select public.mutate_cocreate_numbered_group('cc030000-0000-4000-8000-000000000010',gen_random_uuid(),current_setting('cocreate.number.hub')::uuid,'capacity',
 current_setting('cocreate.number.room')::uuid,current_setting('cocreate.number.a_episode')::uuid,2,null,3)$$,'PT409',null,'Capacity cannot shrink below three occupied seats');
select lives_ok($$select public.mutate_cocreate_numbered_group('cc030000-0000-4000-8000-000000000010',gen_random_uuid(),current_setting('cocreate.number.hub')::uuid,'capacity',
 current_setting('cocreate.number.room')::uuid,current_setting('cocreate.number.a_episode')::uuid,3,null,3)$$,'Creator may set capacity equal to occupied seats');
select is(public.get_cocreate_numbered_group(current_setting('cocreate.number.room')::uuid)->>'available','false','Full is a live availability state, not archival');
select public.send_cocreate_room_message('cc030000-0000-4000-8000-000000000010',gen_random_uuid(),current_setting('cocreate.number.room')::uuid,current_setting('cocreate.number.a_episode')::uuid,'Synthetic before removal');
select public.mutate_cocreate_numbered_group('cc030000-0000-4000-8000-000000000010',gen_random_uuid(),current_setting('cocreate.number.hub')::uuid,'remove',
 current_setting('cocreate.number.room')::uuid,current_setting('cocreate.number.a_episode')::uuid,null,'cc030000-0000-4000-8000-000000000011',4);
select set_config('request.jwt.claim.sub','cc030000-0000-4000-8000-000000000011',true);
select throws_ok($$select public.mutate_cocreate_numbered_group('cc030000-0000-4000-8000-000000000011',gen_random_uuid(),current_setting('cocreate.number.hub')::uuid,'join',current_setting('cocreate.number.room')::uuid)$$,
 '42501',null,'Removed numbered member cannot self-rejoin');
select is(jsonb_array_length(public.get_cocreate_room_page('cc030000-0000-4000-8000-000000000011',current_setting('cocreate.number.room')::uuid,current_setting('cocreate.number.b_episode')::uuid)->'messages'),1,'Removed history freezes at committed removal sequence');
select set_config('request.jwt.claim.sub','cc030000-0000-4000-8000-000000000010',true);
select public.send_cocreate_room_message('cc030000-0000-4000-8000-000000000010',gen_random_uuid(),current_setting('cocreate.number.room')::uuid,current_setting('cocreate.number.a_episode')::uuid,'Synthetic future after removal');
select public.mutate_cocreate_numbered_group('cc030000-0000-4000-8000-000000000010',gen_random_uuid(),current_setting('cocreate.number.hub')::uuid,'restore_member',
 current_setting('cocreate.number.room')::uuid,current_setting('cocreate.number.a_episode')::uuid,null,'cc030000-0000-4000-8000-000000000011',5);
select set_config('request.jwt.claim.sub','cc030000-0000-4000-8000-000000000011',true);
select is(jsonb_array_length(public.get_cocreate_room_page('cc030000-0000-4000-8000-000000000011',current_setting('cocreate.number.room')::uuid,current_setting('cocreate.number.b_episode')::uuid)->'messages'),1,'Reversal itself grants no future history');
select set_config('cocreate.number.b_new',(public.mutate_cocreate_numbered_group('cc030000-0000-4000-8000-000000000011',gen_random_uuid(),current_setting('cocreate.number.hub')::uuid,'join',current_setting('cocreate.number.room')::uuid)->>'episode_id'),true);
select isnt(current_setting('cocreate.number.b_new'),current_setting('cocreate.number.b_episode'),'Fresh numbered admission creates a new episode');
select set_config('request.jwt.claim.sub','cc030000-0000-4000-8000-000000000010',true);
select public.mutate_cocreate_numbered_group('cc030000-0000-4000-8000-000000000010',gen_random_uuid(),current_setting('cocreate.number.hub')::uuid,'leave',current_setting('cocreate.number.room')::uuid,current_setting('cocreate.number.a_episode')::uuid);
select is(public.get_cocreate_numbered_group(current_setting('cocreate.number.room')::uuid),null::jsonb,'Creator departure archives the orphaned group');
select is((select count(*) from private.cocreate_room_episodes where room_id=current_setting('cocreate.number.room')::uuid and ended_at is null),0::bigint,'Orphan archival atomically freezes every participant');
select set_config('cocreate.number.third',public.mutate_cocreate_numbered_group('cc030000-0000-4000-8000-000000000010',gen_random_uuid(),current_setting('cocreate.number.hub')::uuid,'create')::text,true);
select is(current_setting('cocreate.number.third')::jsonb->>'number','3','Archived number one is never reused');
select set_config('request.jwt.claim.sub','cc030000-0000-4000-8000-000000000011',true);
select public.mutate_cocreate_numbered_group('cc030000-0000-4000-8000-000000000011',gen_random_uuid(),current_setting('cocreate.number.hub')::uuid,'join',(current_setting('cocreate.number.second')::jsonb->>'room_id')::uuid);
select set_config('cocreate.number.b_managed',public.mutate_cocreate_numbered_group('cc030000-0000-4000-8000-000000000011',gen_random_uuid(),current_setting('cocreate.number.hub')::uuid,'create')::text,true);
select public.mutate_cocreate_hub('cc030000-0000-4000-8000-000000000011',gen_random_uuid(),'cc030000-0000-4000-8000-000000000003','join');
select public.mutate_cocreate_hub('cc030000-0000-4000-8000-000000000011',gen_random_uuid(),current_setting('cocreate.number.hub')::uuid,'leave',current_setting('cocreate.number.hub_b')::uuid);
select is((select count(*) from private.cocreate_room_episodes e join private.cocreate_rooms r on r.id=e.room_id
 where e.actor_id='cc030000-0000-4000-8000-000000000011' and e.ended_at is null and r.hub_id=current_setting('cocreate.number.hub')::uuid),0::bigint,'Hub exit atomically ends General and all child memberships');
select is((public.get_own_cocreate_hub_membership('cc030000-0000-4000-8000-000000000011','cc030000-0000-4000-8000-000000000003')->>'active'),'true','Other hub remains untouched');
select is(public.get_cocreate_numbered_group((current_setting('cocreate.number.second')::jsonb->>'room_id')::uuid)->>'available','true','Ordinary hub departure reopens its numbered seat');
select is(public.get_cocreate_numbered_group((current_setting('cocreate.number.b_managed')::jsonb->>'room_id')::uuid),null::jsonb,'Hub departure archives the creator own child group');
update auth.users set deleted_at=clock_timestamp() where id='cc030000-0000-4000-8000-000000000010';
select is(public.get_cocreate_numbered_group((current_setting('cocreate.number.second')::jsonb->>'room_id')::uuid),null::jsonb,'Erased creator archives its remaining group without transferring authority');
select is(public.get_cocreate_numbered_group((current_setting('cocreate.number.third')::jsonb->>'room_id')::uuid),null::jsonb,'Erasure convergence covers every owned child');
select * from finish();
rollback;
