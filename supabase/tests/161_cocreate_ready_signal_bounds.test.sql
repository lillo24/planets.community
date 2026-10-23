begin;
-- Count real broadcast rows for these synthetic actors in this transaction.
-- No helper, security check or delivery function is replaced by the test.
select no_plan();
select ok(not (select enabled from private.cocreate_settings), 'new migration never enables the experiment');
update private.cocreate_settings set enabled=true;

-- All supporters enter through the canonical command. Temporarily withdrawing
-- the proposer deliberately exercises a roster larger than one signal budget.
insert into auth.users(id,email)
select ('cc100000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 'bounded-ready-'||n||'@planets.invalid' from generate_series(1,36)n;
insert into public.profiles(id,display_name)
select id,'Synthetic ready invitation' from auth.users where id::text like 'cc100000%';
insert into private.policy_acceptances(account_id,bundle_version)
select id,'POLICY01-2026-10-08-v1' from auth.users where id::text like 'cc100000%';

select set_config('request.jwt.claim.sub','cc100000-0000-4000-8000-000000000001',true);
select set_config('bounded.proposal',(public.propose_cocreate_community(
 'cc100000-0000-4000-8000-000000000001',gen_random_uuid(),'videogames',
 'Synthetic bounded ready','Synthetic locality')->>'proposal_id'),true);
select public.mutate_cocreate_community_interest('cc100000-0000-4000-8000-000000000001',
 gen_random_uuid(),current_setting('bounded.proposal')::uuid,'withdraw');
do $$ declare person uuid; begin
 for person in select id from auth.users where id::text like 'cc100000%' and
  id<>'cc100000-0000-4000-8000-000000000001'::uuid order by id loop
  perform set_config('request.jwt.claim.sub',person::text,true);
  perform public.mutate_cocreate_community_interest(person,gen_random_uuid(),
   current_setting('bounded.proposal')::uuid,'interest');
 end loop;
end; $$;

select is((select state from private.cocreate_community_proposals where
 id=current_setting('bounded.proposal')::uuid),'pending','proposer interest is required despite 35 other interested actors');
select is(private.cocreate_proposal_support(current_setting('bounded.proposal')::uuid),35,
 'the stress case has genuinely exceeded the ordinary three-person threshold');
select set_config('bounded.before_signals',(select count(*)::text from realtime.messages
 where event='cocreate.changed' and topic like 'cocreate:profile:cc100000%'),true);
select set_config('bounded.command',gen_random_uuid()::text,true);
select set_config('request.jwt.claim.sub','cc100000-0000-4000-8000-000000000001',true);
select set_config('bounded.result',public.mutate_cocreate_community_interest(
 'cc100000-0000-4000-8000-000000000001',current_setting('bounded.command')::uuid,
 current_setting('bounded.proposal')::uuid,'interest')::text,true);
select is((select state from private.cocreate_community_proposals where
 id=current_setting('bounded.proposal')::uuid),'activated','the proposer can deliberately reactivate interest');
select is(private.cocreate_proposal_support(current_setting('bounded.proposal')::uuid),36,
 'bounding refresh signals never discards a supporter');
select ok((select count(*)-current_setting('bounded.before_signals')::bigint between 3 and 26
 from realtime.messages where event='cocreate.changed' and topic like 'cocreate:profile:cc100000%'),
 'activation sends at most 25 recipient invalidations plus its one actor response');
select set_config('bounded.after_signals',(select count(*)::text from realtime.messages
 where event='cocreate.changed' and topic like 'cocreate:profile:cc100000%'),true);
select is(public.mutate_cocreate_community_interest('cc100000-0000-4000-8000-000000000001',
 current_setting('bounded.command')::uuid,current_setting('bounded.proposal')::uuid,'interest')::text,
 current_setting('bounded.result'),'lost-reply retry recovers the same canonical activation');
select is((select count(*)::text from realtime.messages where event='cocreate.changed'
 and topic like 'cocreate:profile:cc100000%'),current_setting('bounded.after_signals'),
 'retry emits no repeated recipient invalidations');

create temporary table bounded_invitations(actor_id uuid, ready boolean);
do $$ declare person uuid; item jsonb; begin
 for person in select id from auth.users where id::text like 'cc100000%' order by id loop
  perform set_config('request.jwt.claim.sub',person::text,true);
  select value into item from jsonb_array_elements(public.list_own_cocreate_community_interests(person))
   where value->'proposal'->>'proposal_id'=current_setting('bounded.proposal');
  insert into bounded_invitations values(person,coalesce((item->>'ready_to_join')::boolean,false));
 end loop;
end; $$;
select is((select count(*)::integer from bounded_invitations where ready),36,
 'all 36 actors retrieve their durable ready-to-join invitation, including beyond the signal budget');
select is((select count(*)::integer from private.cocreate_room_episodes e
 join private.cocreate_rooms r on r.id=e.room_id where
 r.hub_id=(current_setting('bounded.result')::jsonb->>'hub_id')::uuid),0,
 'activation and invalidations never enroll supporters in the hub');
select is((select count(*)::integer from private.cocreate_rooms where
 hub_id=(current_setting('bounded.result')::jsonb->>'hub_id')::uuid and kind='general'),1,
 'one canonical General is created');
select is((select count(*)::integer from private.cocreate_rooms where
 hub_id=(current_setting('bounded.result')::jsonb->>'hub_id')::uuid and kind='numbered'),0,
 'no numbered group is created');
select * from finish();
rollback;
