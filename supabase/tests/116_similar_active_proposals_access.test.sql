begin;
select no_plan();
insert into auth.users(id,email) values
 ('e5000000-0000-4000-8000-000000000001','sim01-tap-owner@planets.invalid'),
 ('e5000000-0000-4000-8000-000000000002','sim01-tap-reader@planets.invalid');
insert into public.profiles(id,display_name) values
 ('e5000000-0000-4000-8000-000000000001','SIM01 synthetic owner'),
 ('e5000000-0000-4000-8000-000000000002',null);
insert into public.profile_photos(profile_id,object_path,audience) values
 ('e5000000-0000-4000-8000-000000000001','e5000000-0000-4000-8000-000000000001/e5000000-0000-4000-8000-000000000010.webp','interactions');
create function pg_temp.sim_create(p_title text, p_locality text default 'Trento', p_full boolean default false)
returns uuid language plpgsql security invoker as $$
declare id uuid;
begin
 id := public.create_proposal_draft('e5000000-0000-4000-8000-000000000001',p_title,
 'Public preview','PRIVATE_DESCRIPTION','2098-03-01T10:00:00Z','2098-03-01T12:00:00Z',
 'Europe/Rome','IT',p_locality,'TN',p_locality,'MEETING_SECRET','public',
 array[]::uuid[],array[]::text[],1,p_full);
 perform public.publish_proposal('e5000000-0000-4000-8000-000000000001',id);
 return id;
end; $$;
grant execute on function pg_temp.sim_create(text,text,boolean) to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','e5000000-0000-4000-8000-000000000001',true);
select set_config('test.sim_local',pg_temp.sim_create('Murale comunitario')::text,true);
select set_config('test.sim_far',pg_temp.sim_create('Murale comunitario','Verona')::text,true);
select set_config('test.sim_full',pg_temp.sim_create('Murale comunitario','Trento',true)::text,true);
select set_config('test.sim_unknown',pg_temp.sim_create('Murale comunitario')::text,true);
select set_config('test.sim_repair',pg_temp.sim_create('Repair Café del sabato')::text,true);
select set_config('test.sim_generic',pg_temp.sim_create('Progetto comunitario a Trento')::text,true);
select set_config('test.sim_past',pg_temp.sim_create('Murale comunitario')::text,true);
select set_config('test.sim_cancelled',pg_temp.sim_create('Murale comunitario')::text,true);
select set_config('test.sim_draft',public.create_proposal_draft('e5000000-0000-4000-8000-000000000001',
 'Murale comunitario','','',null,null,'UTC','','','','','','participants',
 array[]::uuid[],array[]::text[],null,false)::text,true);
reset role;
-- Local-only legacy/lifecycle negatives; canonical APIs created/published sources.
update public.projects set registration_capacity=null where id=current_setting('test.sim_unknown')::uuid;
update public.proposals set starts_at='2020-01-01',ends_at='2020-01-02' where id=current_setting('test.sim_past')::uuid;
update public.proposals set lifecycle_state='cancelled',cancelled_at=clock_timestamp() where id=current_setting('test.sim_cancelled')::uuid;
set local role authenticated;
select set_config('request.jwt.claim.sub','e5000000-0000-4000-8000-000000000002',true);
select is((select array_agg(proposal_id) from public.list_similar_active_proposals(
 'e5000000-0000-4000-8000-000000000002','murale',null,' it ',' Trento ',null,10)),
 array[current_setting('test.sim_local')::uuid,current_setting('test.sim_far')::uuid,
 current_setting('test.sim_unknown')::uuid,current_setting('test.sim_full')::uuid],
 'title-only: known availability then locality, unknown then Full; no past/draft/cancelled');
select is((select availability from public.list_similar_active_proposals(
 'e5000000-0000-4000-8000-000000000002','murale') where proposal_id=current_setting('test.sim_full')::uuid),
 'full','organizer-counting On consumes its canonical slot');
select is((select availability from public.list_similar_active_proposals(
 'e5000000-0000-4000-8000-000000000002','murale') where proposal_id=current_setting('test.sim_unknown')::uuid),
 'capacity_unknown','legacy null is explicitly unknown');
select is((select count(*) from public.list_similar_active_proposals(
 'e5000000-0000-4000-8000-000000000002','Repair Café di quartiere')),1::bigint,'repair title reordered/detail words match without skills');
select is((select count(*) from public.list_similar_active_proposals(
 'e5000000-0000-4000-8000-000000000002','Progetto comunitario a Trento',null,'IT','Trento')),0::bigint,'locality plus generic words is empty');
select is((select count(*) from public.list_similar_active_proposals(
 'e5000000-0000-4000-8000-000000000002','Progetto comunitario a Trento')),0::bigint,'candidate geography alone cannot admit even without a hint');
select is((select count(*) from public.list_similar_active_proposals(
 'e5000000-0000-4000-8000-000000000002','!!! the con di')),0::bigint,'valid weak input returns no catalog');
select is((select count(*) from public.list_similar_active_proposals(
 'e5000000-0000-4000-8000-000000000002','')),0::bigint,'empty intermediate editor title is safe');
select is((select count(*) from public.list_similar_active_proposals(
 'e5000000-0000-4000-8000-000000000002','murale',null,null,null,current_setting('test.sim_local')::uuid)),3::bigint,'current destination excluded');
select throws_ok($$select public.list_similar_active_proposals(null,'murale')$$,'42501',null,'expected actor required');
select throws_ok($$select public.list_similar_active_proposals('e5000000-0000-4000-8000-000000000001','murale')$$,'42501',null,'different actor rejected');
select throws_ok($$select public.list_similar_active_proposals('e5000000-0000-4000-8000-000000000002',null)$$,'22023',null,'null title rejected');
select throws_ok($$select public.list_similar_active_proposals('e5000000-0000-4000-8000-000000000002',repeat('a',101))$$,'22023',null,'oversized title rejected');
select throws_ok($$select public.list_similar_active_proposals('e5000000-0000-4000-8000-000000000002','',array[null]::uuid[])$$,'22023',null,'null skill rejected even for weak input');
select throws_ok($$select public.list_similar_active_proposals('e5000000-0000-4000-8000-000000000002','',array['ffffffff-ffff-4fff-8fff-ffffffffffff']::uuid[])$$,'22023',null,'unknown skill rejected');
select throws_ok($$select public.list_similar_active_proposals('e5000000-0000-4000-8000-000000000002','',null,'')$$,'22023',null,'supplied empty country is invalid');
select throws_ok($$select public.list_similar_active_proposals('e5000000-0000-4000-8000-000000000002','',null,'ITA')$$,'22023',null,'country length validated');
select throws_ok($$select public.list_similar_active_proposals('e5000000-0000-4000-8000-000000000002','',null,null,repeat('x',121))$$,'22023',null,'locality bound validated');
select throws_ok($$select public.list_similar_active_proposals('e5000000-0000-4000-8000-000000000002','',null,null,null,null,11)$$,'22023',null,'limit upper bound');
select lives_ok($$select public.list_similar_active_proposals('e5000000-0000-4000-8000-000000000002',repeat('a',100),array[]::uuid[],null,repeat('x',120),null,10)$$,'maximum valid bounds accepted without saved draft or photo');
reset role;
select is(private.derive_proposal_status(now(),now()+interval '1 hour',now()),'happening','canonical exact-start boundary');
create function pg_temp.sim_at_start(p_delta interval default interval '0') returns bigint language plpgsql as $$
declare total bigint;
begin
 update public.proposals set starts_at=statement_timestamp()+p_delta, ends_at=statement_timestamp()+interval '1 hour' where id=current_setting('test.sim_local')::uuid;
 perform set_config('request.jwt.claim.sub','e5000000-0000-4000-8000-000000000002',true);
 select count(*) into total from public.list_similar_active_proposals('e5000000-0000-4000-8000-000000000002','murale')
 where proposal_id=current_setting('test.sim_local')::uuid;
 return total;
end; $$;
select is(pg_temp.sim_at_start(interval '0.000001 seconds'),1::bigint,'just before start is Upcoming at the statement clock');
select is(pg_temp.sim_at_start(),0::bigint,'exact start is excluded by the real lookup at one statement clock');
set local role anon;
select throws_ok($$select public.list_similar_active_proposals('e5000000-0000-4000-8000-000000000002','murale')$$,'42501',null,'anonymous execution rejected');
reset role;
select * from finish();
rollback;
