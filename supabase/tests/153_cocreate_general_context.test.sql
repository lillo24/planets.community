begin;
select no_plan();
select ok(not has_function_privilege('anon','public.get_cocreate_general_context(uuid,uuid,uuid,uuid)','execute'),'Anon cannot read admitted context');
update private.cocreate_settings set enabled=true;
insert into private.cocreate_topics(id,label,active) values('cc020000-0000-4000-8000-000000000001','Synthetic context',true);
insert into private.cocreate_hubs(id,topic_id,locality,active) values
 ('cc020000-0000-4000-8000-000000000002','cc020000-0000-4000-8000-000000000001','Trento',true),
 ('cc020000-0000-4000-8000-000000000003','cc020000-0000-4000-8000-000000000001','Rovereto',true);
insert into auth.users(id,email) values('cc020000-0000-4000-8000-000000000004','cocreate-context@planets.invalid');
insert into public.profiles(id,display_name) values('cc020000-0000-4000-8000-000000000004','Synthetic context person');
insert into private.policy_acceptances(account_id,bundle_version) values('cc020000-0000-4000-8000-000000000004','POLICY01-2026-10-08-v1');
select set_config('request.jwt.claim.sub','cc020000-0000-4000-8000-000000000004',true);
select set_config('cocreate.context_room',(select id::text from private.cocreate_rooms where hub_id='cc020000-0000-4000-8000-000000000002'),true);
select throws_ok($$select public.get_cocreate_general_context('cc020000-0000-4000-8000-000000000004',
 'cc020000-0000-4000-8000-000000000002',current_setting('cocreate.context_room')::uuid,gen_random_uuid())$$,'42501',null,'Prejoin context denies');
select set_config('cocreate.context_episode',(public.mutate_cocreate_hub('cc020000-0000-4000-8000-000000000004',gen_random_uuid(),
 'cc020000-0000-4000-8000-000000000002','join')->>'episode_id'),true);
select is(public.get_cocreate_general_context('cc020000-0000-4000-8000-000000000004','cc020000-0000-4000-8000-000000000002',
 current_setting('cocreate.context_room')::uuid,current_setting('cocreate.context_episode')::uuid)->>'topic_label','Synthetic context','Admitted context uses canonical topic');
select throws_ok($$select public.get_cocreate_general_context('cc020000-0000-4000-8000-000000000004',
 'cc020000-0000-4000-8000-000000000003',current_setting('cocreate.context_room')::uuid,current_setting('cocreate.context_episode')::uuid)$$,
 '42501',null,'Forged hub/room association denies');
select is((select read_sequence from private.cocreate_room_episodes where id=current_setting('cocreate.context_episode')::uuid),0::bigint,'Context never acknowledges history');
select public.mutate_cocreate_hub('cc020000-0000-4000-8000-000000000004',gen_random_uuid(),'cc020000-0000-4000-8000-000000000002','leave',current_setting('cocreate.context_episode')::uuid);
update private.cocreate_hubs set active=false where id='cc020000-0000-4000-8000-000000000002';
select is(public.get_cocreate_hub('cc020000-0000-4000-8000-000000000002'),null::jsonb,'Retired hub leaves public discovery');
select is(public.get_cocreate_general_context('cc020000-0000-4000-8000-000000000004','cc020000-0000-4000-8000-000000000002',
 current_setting('cocreate.context_room')::uuid,current_setting('cocreate.context_episode')::uuid)->>'closed','true','Frozen former history retains its canonical context');
update private.cocreate_settings set enabled=false;
select throws_ok($$select public.get_cocreate_general_context('cc020000-0000-4000-8000-000000000004',
 'cc020000-0000-4000-8000-000000000002',current_setting('cocreate.context_room')::uuid,current_setting('cocreate.context_episode')::uuid)$$,'42501',null,'Gate OFF denies retained context');
select * from finish();
rollback;
