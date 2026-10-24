begin;
select no_plan();
create function pg_temp.pl_actor(n integer) returns uuid language sql immutable as $$
 select ('ca050000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid;
$$;
create function pg_temp.pl_as(n integer) returns uuid language plpgsql as $$
begin perform set_config('request.jwt.claim.sub',pg_temp.pl_actor(n)::text,true);return pg_temp.pl_actor(n);end; $$;
insert into auth.users(id,email) select pg_temp.pl_actor(n),'place-'||n||'@planets.invalid' from generate_series(1,5)n;
insert into public.profiles(id,display_name) select pg_temp.pl_actor(n),'Synthetic Place tester '||n from generate_series(1,5)n;
insert into private.policy_acceptances(account_id,bundle_version) select pg_temp.pl_actor(n),'POLICY01-2026-10-08-v1' from generate_series(1,5)n;
update private.cocreate_settings set enabled=true;
select set_config('pl.proposal',public.propose_cocreate_community(pg_temp.pl_as(1),gen_random_uuid(),'sports','Synthetic Place football','Synthetic Place locality')->>'proposal_id',true);
select public.mutate_cocreate_community_interest(pg_temp.pl_as(2),gen_random_uuid(),current_setting('pl.proposal')::uuid,'interest');
select public.mutate_cocreate_community_interest(pg_temp.pl_as(3),gen_random_uuid(),current_setting('pl.proposal')::uuid,'interest');
select set_config('pl.hub',public.get_cocreate_community_proposal(current_setting('pl.proposal')::uuid)->>'hub_id',true);
create temp table pl_hubs(n integer primary key,m jsonb);
insert into pl_hubs select n,public.mutate_cocreate_hub(pg_temp.pl_as(n),gen_random_uuid(),current_setting('pl.hub')::uuid,'join') from generate_series(1,4)n;
create temp table pl_groups(key text primary key,r jsonb);
insert into pl_groups values('a',public.mutate_cocreate_numbered_group(pg_temp.pl_as(1),gen_random_uuid(),current_setting('pl.hub')::uuid,'create',p_capacity=>50));
insert into pl_groups values('b',public.mutate_cocreate_numbered_group(pg_temp.pl_as(3),gen_random_uuid(),current_setting('pl.hub')::uuid,'create',p_capacity=>50));
create function pg_temp.pl_context(n integer,k text default null) returns jsonb language plpgsql as $$
declare g jsonb;e uuid;begin
 select r into g from pl_groups where key=k;
 if g is not null then select id into e from private.cocreate_room_episodes where room_id=(g->>'room_id')::uuid and actor_id=pg_temp.pl_actor(n) and ended_at is null;end if;
 return public.get_cocreate_place_context_v1(pg_temp.pl_as(n),current_setting('pl.hub')::uuid,(g->>'room_id')::uuid,e);
end; $$;
create function pg_temp.pl_snapshot(label text default 'Synthetic football field',kind text default 'amenity',lon numeric default 11.1) returns jsonb language sql as $$
 select jsonb_build_object('provider','geoapify','kind',kind,'result_type',case when kind='address' then 'building' when kind='locality' then 'city' else 'amenity' end,
 'label',label,'country_code','IT','locality','Synthetic locality','administrative_area','Synthetic region','latitude',46.1,'longitude',lon,'confidence',0.9,
 'source','openstreetmap','attribution','Powered by Geoapify | © OpenStreetMap contributors','source_license','https://www.openstreetmap.org/copyright');
$$;
create function pg_temp.pl_receipt(n integer,k text,snapshot jsonb default pg_temp.pl_snapshot()) returns uuid language plpgsql as $$
declare c jsonb;batch jsonb;issued jsonb;begin
 c:=pg_temp.pl_context(n,k);
 batch:=public.reserve_location_search_v1(pg_temp.pl_actor(n),case when k is null then 'cocreate_hub' else 'cocreate_room' end,
  (c->>'episode_id')::uuid,(c->>'version')::bigint,'exact',gen_random_uuid(),repeat('a',32)||replace(gen_random_uuid()::text,'-',''));
 if batch->>'status'<>'ok' then raise exception 'Selection reservation failed: %',batch;end if;
 issued:=public.issue_location_selections_v1((batch->>'batch_id')::uuid,jsonb_build_array(snapshot));
 return (issued->'suggestions'->0->>'id')::uuid;
end; $$;
create function pg_temp.pl_set(n integer,k text,p uuid default null,receipt uuid default null,publish boolean default false,command uuid default gen_random_uuid()) returns jsonb language plpgsql as $$
declare c jsonb;begin c:=pg_temp.pl_context(n,k);
 return public.set_cocreate_usual_place_v1(pg_temp.pl_as(n),command,current_setting('pl.hub')::uuid,(c->>'room_id')::uuid,
 (c->>'episode_id')::uuid,(c->>'version')::bigint,p,receipt,publish);end; $$;
create function pg_temp.pl_list(n integer) returns jsonb language plpgsql as $$
declare m jsonb;begin select pl_hubs.m into m from pl_hubs where pl_hubs.n=pl_list.n;
 return public.list_cocreate_places_v1(pg_temp.pl_as(n),current_setting('pl.hub')::uuid,(m->>'episode_id')::uuid);end; $$;
create function pg_temp.pl_discover(n integer) returns jsonb language plpgsql as $$
begin return public.list_discoverable_cocreate_places_v1(pg_temp.pl_as(n));end; $$;

select ok(not has_table_privilege(role,'private.cocreate_places','SELECT'),role||' cannot read Places directly') from unnest(array['anon','authenticated','service_role']) role;
select ok((select relrowsecurity from pg_class where oid='private.cocreate_places'::regclass),'Place table has RLS defense');
select ok(not has_function_privilege('authenticated','private.cocreate_place_associations(uuid,uuid,boolean)','EXECUTE'),'internal association helper is private');
select is(pg_temp.pl_context(1,'a')->'usual_place','null'::jsonb,'a group is valid without a usual Place');
select is(jsonb_array_length(pg_temp.pl_list(2)->'places'),0,'locationless community has no invented venue');
select is(public.reserve_location_search_v1(pg_temp.pl_actor(1),'cocreate_hub',((select m->>'episode_id' from pl_hubs where n=1))::uuid,0,'exact',gen_random_uuid(),repeat('d',64))->>'status','disabled','disabled provider selection performs no reservation');
update private.location_search_config set enabled=true;
update private.location_provider_config set enabled=true,daily_units_limit=8000;

select set_config('pl.receipt',pg_temp.pl_receipt(1,'a')::text,true);
select set_config('pl.command',gen_random_uuid()::text,true);
select set_config('pl.version',pg_temp.pl_context(1,'a')->>'version',true);
select set_config('pl.set',pg_temp.pl_set(1,'a',receipt=>current_setting('pl.receipt')::uuid,command=>current_setting('pl.command')::uuid)::text,true);
select set_config('pl.field',current_setting('pl.set')::jsonb->>'place_id',true);
select is((select count(*)::integer from private.cocreate_places),1,'server-issued selection creates one stable PLANETS Place');
select is(pg_temp.pl_context(1,'a')->>'usual_discoverable','false','publication defaults OFF');
select is(jsonb_array_length(pg_temp.pl_list(2)->'places'),0,'unpublished usual place reveals no newcomer count');
select is(jsonb_array_length(pg_temp.pl_discover(5)->'places'),0,'unpublished usual Place is absent across communities');
select is(public.set_cocreate_usual_place_v1(pg_temp.pl_as(1),current_setting('pl.command')::uuid,current_setting('pl.hub')::uuid,
 ((select r->>'room_id' from pl_groups where key='a'))::uuid,((select r->>'episode_id' from pl_groups where key='a'))::uuid,
 current_setting('pl.version')::bigint,null,current_setting('pl.receipt')::uuid,false),current_setting('pl.set')::jsonb,'reply-loss retry returns exact receipt after version/selection consumption');
select throws_ok($$select public.set_cocreate_usual_place_v1(pg_temp.pl_as(1),current_setting('pl.command')::uuid,current_setting('pl.hub')::uuid,
 ((select r->>'room_id' from pl_groups where key='a'))::uuid,((select r->>'episode_id' from pl_groups where key='a'))::uuid,current_setting('pl.version')::bigint,null,current_setting('pl.receipt')::uuid,true)$$,'22023',null,'same command cannot change discovery intent');
select public.mutate_cocreate_numbered_group(pg_temp.pl_as(2),gen_random_uuid(),current_setting('pl.hub')::uuid,'join',((select r->>'room_id' from pl_groups where key='a'))::uuid);
select throws_ok($$select pg_temp.pl_set(2,'a',current_setting('pl.field')::uuid)$$,'42501',null,'ordinary current group member has no structural Place authority');
select throws_ok($$select public.get_cocreate_place_context_v1(pg_temp.pl_as(5),current_setting('pl.hub')::uuid)$$,'42501',null,'outsider gets no pre-command selection scope');
select throws_ok($$select pg_temp.pl_set(3,'b',current_setting('pl.field')::uuid)$$,'42501',null,'unguessable UUID alone is no private Place grant');

select pg_temp.pl_set(3,'b',receipt=>pg_temp.pl_receipt(3,'b'));
select is((select count(*)::integer from private.cocreate_places),1,'equal normalized snapshots reuse one UUID despite new verification times');
select pg_temp.pl_set(1,'a',current_setting('pl.field')::uuid,publish=>true);
select pg_temp.pl_set(3,'b',current_setting('pl.field')::uuid,publish=>true);
select is((pg_temp.pl_discover(5)->'places'->0->>'groups')::integer,2,'two explicitly published groups aggregate at one Place');
select is(pg_temp.pl_list(2)->'places'->0->'place'->>'place_id',current_setting('pl.field'),'hub-admitted user sees the published venue');
select set_config('pl.near',pg_temp.pl_receipt(3,'b',pg_temp.pl_snapshot(lon=>11.1000001))::text,true);
select set_config('pl.other',(pg_temp.pl_set(3,'b',receipt=>current_setting('pl.near')::uuid)->>'place_id'),true);
select isnt(current_setting('pl.other'),current_setting('pl.field'),'nearby equal-label snapshots NEVER fuzzy merge');
select pg_temp.pl_set(3,'b',current_setting('pl.field')::uuid,publish=>true);

create temp table pl_meetings(key text primary key,r jsonb);
insert into pl_meetings select 'a',public.schedule_cocreate_meeting_v2(pg_temp.pl_as(1),gen_random_uuid(),current_setting('pl.hub')::uuid,
 clock_timestamp()+interval '2 days',7,(r->>'room_id')::uuid,(r->>'episode_id')::uuid,current_setting('pl.field')::uuid,p_discoverable=>true) from pl_groups where key='a';
insert into pl_meetings select 'b',public.schedule_cocreate_meeting_v2(pg_temp.pl_as(3),gen_random_uuid(),current_setting('pl.hub')::uuid,
 clock_timestamp()+interval '3 days',2,(r->>'room_id')::uuid,(r->>'episode_id')::uuid,
 p_selection_receipt=>pg_temp.pl_receipt(3,'b',pg_temp.pl_snapshot(lon=>11.1000001)),
 p_scope_episode_id=>(r->>'episode_id')::uuid,p_scope_revision=>(pg_temp.pl_context(3,'b')->>'version')::bigint,p_discoverable=>true) from pl_groups where key='b';
select is((select place_id::text from private.cocreate_meeting_places where meeting_id=((select r->>'meeting_id' from pl_meetings where key='b'))::uuid),current_setting('pl.other'),'meeting occurrence can differ from usual Place');
select is(pg_temp.pl_context(3,'b')->'usual_place'->>'place_id',current_setting('pl.field'),'occurrence Place does not rewrite usual Place');
update private.cocreate_settings set max_numbered_memberships=1;
select is(public.get_cocreate_place_detail_v1(pg_temp.pl_as(2),current_setting('pl.hub')::uuid,
 ((select m->>'episode_id' from pl_hubs where n=2))::uuid,current_setting('pl.other')::uuid)->'groups'->0->'meeting'->>'can_join','false',
 'Place meeting projection reuses canonical numbered-membership limit');
update private.cocreate_settings set max_numbered_memberships=50;
select public.mutate_cocreate_numbered_group(pg_temp.pl_as(4),gen_random_uuid(),current_setting('pl.hub')::uuid,'join',((select r->>'room_id' from pl_groups where key='b'))::uuid);
update private.cocreate_rooms set capacity=2 where id=((select r->>'room_id' from pl_groups where key='b'))::uuid;
select is(public.get_cocreate_place_detail_v1(pg_temp.pl_as(1),current_setting('pl.hub')::uuid,
 ((select m->>'episode_id' from pl_hubs where n=1))::uuid,current_setting('pl.other')::uuid)->'groups'->0->'meeting'->>'can_join','false',
 'full persistent chat with spare meeting capacity is not available to newcomer');
select is(public.get_cocreate_place_detail_v1(pg_temp.pl_as(1),current_setting('pl.hub')::uuid,
 ((select m->>'episode_id' from pl_hubs where n=1))::uuid,current_setting('pl.other')::uuid)->'groups'->0->'meeting'->>'occupied','1',
 'ineligible newcomer still sees actual meeting occupancy');
select throws_ok($$select public.join_cocreate_recruitment(pg_temp.pl_as(1),gen_random_uuid(),current_setting('pl.hub')::uuid,
 ((select r->>'room_id' from pl_groups where key='b'))::uuid,((select r->>'recruitment_id' from pl_meetings where key='b'))::uuid)$$,'PT409',null,
 'direct admission remains final authority at full chat capacity');
select is((public.get_cocreate_place_detail_v1(pg_temp.pl_as(2),current_setting('pl.hub')::uuid,((select m->>'episode_id' from pl_hubs where n=2))::uuid,current_setting('pl.field')::uuid)->'groups'->0->'meeting'->>'can_confirm'),'true','current nonattending member gets canonical attendance path');
select pg_temp.pl_set(1,'a',current_setting('pl.field')::uuid,publish=>false);
select is((select count(*)::integer from private.cocreate_place_associations(pg_temp.pl_actor(5),null,true) where place_id=current_setting('pl.field')::uuid and meeting is not null),1,'meeting publication is independent of usual publication');

select set_config('pl.address_receipt',pg_temp.pl_receipt(1,'a',pg_temp.pl_snapshot('Synthetic private address','address'))::text,true);
select set_config('pl.address',pg_temp.pl_set(1,'a',receipt=>current_setting('pl.address_receipt')::uuid)->>'place_id',true);
select throws_ok($$select pg_temp.pl_set(1,'a',current_setting('pl.address')::uuid,publish=>true)$$,'22023',null,'exact private address cannot be discovery-published');
select is((select count(*)::integer from jsonb_array_elements(pg_temp.pl_discover(5)->'places') p where p->'place'->>'place_id'=current_setting('pl.address')),0,'address cannot leak through discovery counts');
select is((public.get_cocreate_current_meeting_v2(pg_temp.pl_as(1),((select r->>'room_id' from pl_groups where key='a'))::uuid,((select r->>'episode_id' from pl_groups where key='a'))::uuid)->'place'->>'place_id'),current_setting('pl.field'),'usual-place change never moves scheduled meeting');
select pg_temp.pl_set(1,'a');
select is(pg_temp.pl_context(1,'a')->'usual_place','null'::jsonb,'manager can clear the usual association');
select is((select count(*)::integer from private.cocreate_places where id=current_setting('pl.address')::uuid),1,'clearing preserves stable Place/history');
select ok(pg_temp.pl_receipt(1,null,pg_temp.pl_snapshot(kind=>'locality')) is null,'locality cannot masquerade as a reusable exact venue');

select set_config('pl.scope',pg_temp.pl_context(1)::text,true);
select set_config('pl.new_receipt',pg_temp.pl_receipt(1,null,pg_temp.pl_snapshot('Synthetic second football field'))::text,true);
select set_config('pl.new_command',gen_random_uuid()::text,true);
select set_config('pl.instant',(clock_timestamp()+interval '4 days')::text,true);
insert into pl_meetings values('new',public.schedule_cocreate_meeting_v2(pg_temp.pl_as(1),current_setting('pl.new_command')::uuid,current_setting('pl.hub')::uuid,
 current_setting('pl.instant')::timestamptz,3,p_selection_receipt=>current_setting('pl.new_receipt')::uuid,
 p_scope_episode_id=>(current_setting('pl.scope')::jsonb->>'episode_id')::uuid,p_scope_revision=>0,p_discoverable=>true));
select ok((select r->>'place_id' from pl_meetings where key='new') is not null,'new group scheduling uses a real General-episode selection atomically');
select is(public.schedule_cocreate_meeting_v2(pg_temp.pl_as(1),current_setting('pl.new_command')::uuid,current_setting('pl.hub')::uuid,
 current_setting('pl.instant')::timestamptz,3,p_selection_receipt=>current_setting('pl.new_receipt')::uuid,
 p_scope_episode_id=>(current_setting('pl.scope')::jsonb->>'episode_id')::uuid,p_scope_revision=>0,p_discoverable=>true),
 (select r from pl_meetings where key='new'),'scheduled Place/group/meeting exact retry does not duplicate');

select set_config('pl.discovery_page',public.list_discoverable_cocreate_places_v1(pg_temp.pl_as(5),1)::text,true);
select is(jsonb_array_length(current_setting('pl.discovery_page')::jsonb->'places'),1,'discovery response is bounded');
select ok(current_setting('pl.discovery_page')::jsonb->>'next_cursor' is not null,'deterministic UUID continuation exists');
select isnt(public.list_discoverable_cocreate_places_v1(pg_temp.pl_as(5),1,(current_setting('pl.discovery_page')::jsonb->>'next_cursor')::uuid)->'places'->0->'place'->>'place_id',
 current_setting('pl.discovery_page')::jsonb->'places'->0->'place'->>'place_id','continuation advances without repeating Place identity');
select throws_ok($$select public.list_discoverable_cocreate_places_v1(pg_temp.pl_as(5),51)$$,'22023',null,'unbounded Place pages are rejected');
select throws_ok($$select public.list_discoverable_cocreate_places_v1(pg_temp.pl_actor(3))$$,'42501',null,'forged actor cannot read another discovery scope');
select set_config('pl.stale_receipt',pg_temp.pl_receipt(3,'b')::text,true);
select set_config('pl.stale_scope',pg_temp.pl_context(3,'b')::text,true);
select pg_temp.pl_set(3,'b',current_setting('pl.field')::uuid,publish=>false);
select throws_ok($$select public.set_cocreate_usual_place_v1(pg_temp.pl_as(3),gen_random_uuid(),current_setting('pl.hub')::uuid,
 (current_setting('pl.stale_scope')::jsonb->>'room_id')::uuid,(current_setting('pl.stale_scope')::jsonb->>'episode_id')::uuid,
 (current_setting('pl.stale_scope')::jsonb->>'version')::bigint,p_selection_receipt=>current_setting('pl.stale_receipt')::uuid)$$,'PT409',null,'stale structural scope rejects selection');
select set_config('pl.expired',pg_temp.pl_receipt(3,'b')::text,true);
update private.location_search_batches set expires_at=statement_timestamp()-interval '1 second' where id=(select batch_id from private.location_selection_receipts where id=current_setting('pl.expired')::uuid);
select throws_ok($$select pg_temp.pl_set(3,'b',receipt=>current_setting('pl.expired')::uuid)$$,'22023',null,'expired receipt is not a Place identity');
select set_config('pl.replaced',pg_temp.pl_receipt(4,null)::text,true);
select set_config('pl.old_episode',(select m->>'episode_id' from pl_hubs where n=4),true);
select public.mutate_cocreate_hub(pg_temp.pl_as(4),gen_random_uuid(),current_setting('pl.hub')::uuid,'leave',((select m->>'episode_id' from pl_hubs where n=4))::uuid);
select throws_ok($$select private.lock_cocreate_place_scope(pg_temp.pl_actor(4),'cocreate_hub',current_setting('pl.old_episode')::uuid)$$,'42501',null,'exited/replaced General episode cannot accept late selection');

select set_config('pl.acks',(select jsonb_agg(jsonb_build_array(id,read_sequence) order by id)::text from private.cocreate_room_episodes),true);
select pg_temp.pl_list(2);select pg_temp.pl_discover(2);
select is((select jsonb_agg(jsonb_build_array(id,read_sequence) order by id)::text from private.cocreate_room_episodes),current_setting('pl.acks'),'Place reads create no transcript ACK/unread writes');
select public.block_user(pg_temp.pl_as(2),pg_temp.pl_actor(1));
select is((select count(*)::integer from private.cocreate_place_associations(pg_temp.pl_actor(2),null,true) where room_id=((select r->>'room_id' from pl_meetings where key='new'))::uuid),0,'blocked newcomers disappear from rows/counts');
select is((public.get_cocreate_current_meeting_v2(pg_temp.pl_as(2),((select r->>'room_id' from pl_groups where key='a'))::uuid,
 (select id from private.cocreate_room_episodes where room_id=((select r->>'room_id' from pl_groups where key='a'))::uuid and actor_id=pg_temp.pl_actor(2) and ended_at is null))->'place'->>'place_id'),current_setting('pl.field'),'current-member Place review preserves FIX01 blocking parity');
update private.cocreate_rooms set suppressed=true where id=((select r->>'room_id' from pl_groups where key='b'))::uuid;
select is((select count(*)::integer from private.cocreate_place_associations(pg_temp.pl_actor(5),null,true) where room_id=((select r->>'room_id' from pl_groups where key='b'))::uuid),0,'suppression removes discovery associations');
select public.mutate_cocreate_meeting(pg_temp.pl_as(1),gen_random_uuid(),current_setting('pl.hub')::uuid,
 ((select r->>'room_id' from pl_meetings where key='new'))::uuid,((select r->>'episode_id' from pl_meetings where key='new'))::uuid,
 ((select r->>'meeting_id' from pl_meetings where key='new'))::uuid,'cancel');
select is((select count(*)::integer from private.cocreate_place_associations(pg_temp.pl_actor(5),null,true) where room_id=((select r->>'room_id' from pl_meetings where key='new'))::uuid),0,'cancelled meeting disappears from discovery');
select is(jsonb_array_length(public.get_cocreate_place_detail_v1(pg_temp.pl_as(1),current_setting('pl.hub')::uuid,
 ((select m->>'episode_id' from pl_hubs where n=1))::uuid,((select r->>'place_id' from pl_meetings where key='new'))::uuid)->'groups'),0,
 'authorized current-member cancelled venue opens an honest empty upcoming detail');
select throws_ok($$select public.get_cocreate_place_detail_v1(pg_temp.pl_as(3),current_setting('pl.hub')::uuid,
 ((select m->>'episode_id' from pl_hubs where n=3))::uuid,((select r->>'place_id' from pl_meetings where key='new'))::uuid)$$,'42501',null,
 'cancelled historical venue is not a new hub-member grant');
update private.cocreate_rooms set suppressed=false where id=((select r->>'room_id' from pl_groups where key='b'))::uuid;
select is((select count(*)::integer from private.cocreate_place_associations(pg_temp.pl_actor(5),null,true) where place_id=current_setting('pl.other')::uuid),1,'restoring group restores only eligible explicit occurrence');
update private.cocreate_recruitments set retracted_at=clock_timestamp() where meeting_id=((select r->>'meeting_id' from pl_meetings where key='b'))::uuid;
select is((select count(*)::integer from private.cocreate_place_associations(pg_temp.pl_actor(5),null,true) where place_id=current_setting('pl.other')::uuid),0,'retracted recruitment removes newcomer discovery');
update private.cocreate_meetings set created_at=clock_timestamp()-interval '2 days',starts_at=clock_timestamp()-interval '1 day' where id=((select r->>'meeting_id' from pl_meetings where key='a'))::uuid;
select is((select count(*)::integer from private.cocreate_place_associations(pg_temp.pl_actor(5),null,true) where place_id=current_setting('pl.field')::uuid and meeting is not null),0,'past occurrence is absent from discovery');
select public.mutate_cocreate_numbered_group(pg_temp.pl_as(3),gen_random_uuid(),current_setting('pl.hub')::uuid,'archive',((select r->>'room_id' from pl_groups where key='b'))::uuid,((select r->>'episode_id' from pl_groups where key='b'))::uuid,
 p_expected_version=>(pg_temp.pl_context(3,'b')->>'version')::bigint);
select is((select count(*)::integer from private.cocreate_place_associations(pg_temp.pl_actor(3),current_setting('pl.hub')::uuid) where room_id=((select r->>'room_id' from pl_groups where key='b'))::uuid),0,'archival removes stale private and discovery associations');
select set_config('pl.legacy',public.schedule_cocreate_meeting(pg_temp.pl_as(3),gen_random_uuid(),current_setting('pl.hub')::uuid,clock_timestamp()+interval '5 days',5)::text,true);
select is(public.get_cocreate_current_meeting_v2(pg_temp.pl_as(3),(current_setting('pl.legacy')::jsonb->>'room_id')::uuid,
 (current_setting('pl.legacy')::jsonb->>'episode_id')::uuid)->'place','null'::jsonb,'installed client still schedules without Place fields');
update private.location_search_config set enabled=false;
update private.location_provider_config set enabled=false;
select is(public.schedule_cocreate_meeting_v2(pg_temp.pl_as(3),gen_random_uuid(),current_setting('pl.hub')::uuid,
 clock_timestamp()+interval '6 days',5)->'place_id','null'::jsonb,'provider OFF does not block versioned locationless scheduling');
update private.cocreate_hubs set suppressed=true where id=current_setting('pl.hub')::uuid;
select is(jsonb_array_length(pg_temp.pl_discover(5)->'places'),0,'suppressed hub leaks no Place counts');
select throws_ok($$select pg_temp.pl_list(2)$$,'42501',null,'hub suppression revokes scoped Place reads');
update private.cocreate_settings set enabled=false;
select throws_ok($$select pg_temp.pl_discover(5)$$,'42501',null,'disabled experiment fails closed');
select * from finish();
rollback;
