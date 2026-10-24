-- PLACE01: stable normalized venue identities; no provider or experiment activation.
set lock_timeout='5s';
set statement_timeout='60s';

create table private.cocreate_places (
 id uuid primary key default gen_random_uuid(),
 snapshot jsonb not null check (snapshot is not null and private.valid_selected_place(snapshot)
  and snapshot->>'kind' in ('amenity','address')),
 fingerprint text not null unique check(fingerprint=private.group_command_hash(snapshot-'verified_at')),
 created_at timestamptz not null default clock_timestamp()
);
create table private.cocreate_room_places (
 room_id uuid primary key references private.cocreate_rooms(id),
 place_id uuid not null references private.cocreate_places(id),
 discoverable boolean not null default false
);
create index cocreate_room_places_place on private.cocreate_room_places(place_id,room_id);
create table private.cocreate_meeting_places (
 meeting_id uuid primary key references private.cocreate_meetings(id),
 place_id uuid not null references private.cocreate_places(id),
 discoverable boolean not null default false
);
create index cocreate_meeting_places_place on private.cocreate_meeting_places(place_id,meeting_id);
create table private.cocreate_place_receipts (
 actor_id uuid not null references public.profiles(id), command_id uuid not null,
 intent_hash text not null, result jsonb not null, primary key(actor_id,command_id)
);
alter table private.cocreate_places enable row level security;
alter table private.cocreate_room_places enable row level security;
alter table private.cocreate_meeting_places enable row level security;
alter table private.cocreate_place_receipts enable row level security;
revoke all on private.cocreate_places,private.cocreate_room_places,
 private.cocreate_meeting_places,private.cocreate_place_receipts from public,anon,authenticated,service_role;
comment on table private.cocreate_places is 'PLANETS-owned venue UUID. Exact admitted normalized snapshot deduplication excludes only verified_at (provenance time). First snapshot stays immutable; no provider IDs, fuzzy matching, GPS or search text.';
comment on table private.cocreate_room_places is 'Optional manager-owned usual place; publication defaults OFF. Does not reserve a venue or rewrite an occurrence.';
comment on table private.cocreate_meeting_places is 'Occurrence place committed atomically with schedule/recruitment. Fixed after scheduling, independent of usual-place publication.';

-- The pre-command scope is an EXISTING General episode, never an invented room.
-- Service-only search receives the actor validated by the existing Edge adapter.
create function private.lock_cocreate_place_scope(p_actor uuid,p_kind text,p_episode uuid)
returns bigint language plpgsql security definer set search_path='' as $$
declare e private.cocreate_room_episodes; r private.cocreate_rooms;
begin
 perform 1 from auth.users where id=p_actor for share;
 perform 1 from public.profiles where id=p_actor for share;
 perform private.require_cocreate_enabled();
 if not private.cocreate_account_available(p_actor) or not exists(
  select 1 from private.policy_acceptances a join private.cocreate_settings s
   on s.singleton and s.policy_bundle_version=a.bundle_version where a.account_id=p_actor
 ) then raise sqlstate '42501' using message='Place selection is unavailable for this account.';end if;
 select * into e from private.cocreate_room_episodes where id=p_episode and actor_id=p_actor and ended_at is null;
 select * into r from private.cocreate_rooms where id=e.room_id;
 if e.id is null then raise sqlstate '42501' using message='The place-selection episode is unavailable.';end if;
 perform private.cocreate_lock_hub(r.hub_id);
 -- Reread after the canonical lock; a late provider response cannot reuse an exit.
 select * into e from private.cocreate_room_episodes where id=p_episode and actor_id=p_actor and ended_at is null;
 select * into r from private.cocreate_rooms where id=e.room_id;
 if e.id is null or not private.cocreate_hub_member(r.hub_id,p_actor)
  or r.archived or r.suppressed or not private.cocreate_hub_public(r.hub_id)
  or (p_kind='cocreate_hub' and r.kind<>'general')
  or (p_kind='cocreate_room' and (r.kind<>'numbered' or r.manager_id<>p_actor))
  or p_kind not in ('cocreate_hub','cocreate_room') then
  raise sqlstate '42501' using message='The place-selection authority changed.';
 end if;
 return case when p_kind='cocreate_hub' then 0 else r.version end;
end; $$;

create function public.list_cocreate_places_v1(p_expected_profile_id uuid,p_hub_id uuid,p_episode_id uuid,
 p_limit integer default 25,p_after_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_cocreate_actor(p_expected_profile_id);rows jsonb;next_id uuid;
begin
 perform private.require_cocreate_places_hub(actor,p_hub_id,p_episode_id);
 if p_limit is null or p_limit not between 1 and 50 then raise sqlstate '22023' using message='Invalid Places page.';end if;
 with a as materialized (select * from private.cocreate_place_associations(actor,p_hub_id)),
 grouped as (
  select place_id,count(distinct room_id) filter(where usual)::integer groups,
   count(distinct meeting->>'meeting_id')::integer meetings,
   coalesce(bool_or((meeting->>'can_join')::boolean or (meeting->>'can_confirm')::boolean),false) available
  from a where p_after_id is null or place_id>p_after_id group by place_id order by place_id limit p_limit+1
 ) select coalesce(jsonb_agg(jsonb_build_object('place',private.cocreate_place_projection(place_id),
  'groups',groups,'meetings',meetings,'available',available) order by place_id),'[]'::jsonb) into rows from grouped;
 if jsonb_array_length(rows)>p_limit then rows:=rows-p_limit;next_id:=(rows->(p_limit-1)->'place'->>'place_id')::uuid;end if;
 return jsonb_build_object('profile_id',actor,'hub_id',p_hub_id,'episode_id',p_episode_id,
  'places',rows,'next_cursor',next_id);
end; $$;

create function public.get_cocreate_place_detail_v1(p_expected_profile_id uuid,p_hub_id uuid,p_episode_id uuid,
 p_place_id uuid,p_limit integer default 25,p_after_number integer default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_cocreate_actor(p_expected_profile_id);rows jsonb;next_number integer;
begin
 perform private.require_cocreate_places_hub(actor,p_hub_id,p_episode_id);
 if p_place_id is null or p_limit is null or p_limit not between 1 and 50 or p_after_number<1 then
  raise sqlstate '22023' using message='Invalid Place detail page.';end if;
 -- The exact current-member meeting panel may retain a past/cancelled venue.
 -- It can open an honestly empty upcoming list without adding discovery counts.
 if not exists(select 1 from private.cocreate_place_associations(actor,p_hub_id) a where a.place_id=p_place_id)
  and not exists(select 1 from private.cocreate_meeting_places mp
   join private.cocreate_meetings m on m.id=mp.meeting_id join private.cocreate_rooms r on r.id=m.room_id
   join private.cocreate_room_episodes e on e.room_id=r.id and e.actor_id=actor and e.ended_at is null
   where mp.place_id=p_place_id and r.hub_id=p_hub_id and private.cocreate_numbered_public(r.id)
    and m.id=(select latest.id from private.cocreate_meetings latest where latest.room_id=r.id order by latest.created_at desc,latest.id desc limit 1)) then
  raise sqlstate '42501' using message='This Place is unavailable in the current community.';end if;
 with grouped as (
  select room_id,number,bool_or(usual) usual,
   (jsonb_agg(meeting) filter(where meeting is not null))->0 meeting
  from private.cocreate_place_associations(actor,p_hub_id) a
  where place_id=p_place_id and (p_after_number is null or number>p_after_number)
  group by room_id,number order by number limit p_limit+1
 ) select coalesce(jsonb_agg(jsonb_build_object('room_id',room_id,'number',number,'usual',usual,'meeting',meeting)
  order by number),'[]'::jsonb) into rows from grouped;
 if jsonb_array_length(rows)>p_limit then rows:=rows-p_limit;next_number:=(rows->(p_limit-1)->>'number')::integer;end if;
 return jsonb_build_object('profile_id',actor,'hub_id',p_hub_id,'episode_id',p_episode_id,
  'place',private.cocreate_place_projection(p_place_id),'groups',rows,'next_number',next_number);
end; $$;

create function public.list_discoverable_cocreate_places_v1(p_expected_profile_id uuid,
 p_limit integer default 25,p_after_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_cocreate_actor(p_expected_profile_id);rows jsonb;next_id uuid;
begin
 if p_limit is null or p_limit not between 1 and 50 then raise sqlstate '22023' using message='Invalid discovery Places page.';end if;
 with grouped as (
  select place_id,count(distinct room_id) filter(where usual)::integer groups,
   count(distinct meeting->>'meeting_id')::integer meetings,
   coalesce(bool_or((meeting->>'can_join')::boolean or (meeting->>'can_confirm')::boolean),false) available
  from private.cocreate_place_associations(actor,null,true) a
  where p_after_id is null or place_id>p_after_id group by place_id order by place_id limit p_limit+1
 ) select coalesce(jsonb_agg(jsonb_build_object('place',private.cocreate_place_projection(place_id),
  'groups',groups,'meetings',meetings,'available',available) order by place_id),'[]'::jsonb) into rows from grouped;
 if jsonb_array_length(rows)>p_limit then rows:=rows-p_limit;next_id:=(rows->(p_limit-1)->'place'->>'place_id')::uuid;end if;
 return jsonb_build_object('profile_id',actor,'places',rows,'next_cursor',next_id);
end; $$;

-- Versioned read contracts: installed strict DTOs/OIDs/results remain untouched.
create function public.get_cocreate_current_meeting_v2(p_expected_profile_id uuid,p_room_id uuid,p_episode_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;place uuid;
begin
 result:=public.get_cocreate_current_meeting(p_expected_profile_id,p_room_id,p_episode_id);
 if result is null then return null;end if;
 select place_id into place from private.cocreate_meeting_places where meeting_id=(result->>'meeting_id')::uuid;
 return result||jsonb_build_object('place',private.cocreate_place_projection(place));
end; $$;

create function public.get_cocreate_recruitment_review_v2(p_expected_profile_id uuid,p_general_room_id uuid,
 p_episode_id uuid,p_recruitment_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;place uuid;
begin
 result:=public.get_cocreate_recruitment_review_v1(p_expected_profile_id,p_general_room_id,p_episode_id,p_recruitment_id);
 select a.place_id into place from private.cocreate_place_associations(p_expected_profile_id,(result->>'hub_id')::uuid) a
  where a.meeting->>'meeting_id'=result->'recruitment'->>'meeting_id' limit 1;
 return result||jsonb_build_object('place',private.cocreate_place_projection(place));
end; $$;

create function public.get_cocreate_calendar_v2(p_expected_profile_id uuid,p_hub_id uuid,p_general_room_id uuid,
 p_episode_id uuid,p_window_start timestamptz,p_window_end timestamptz,
 p_limit integer default 25,p_cursor text default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;rows jsonb;row jsonb;place uuid;
begin
 result:=public.get_cocreate_calendar_v1(p_expected_profile_id,p_hub_id,p_general_room_id,p_episode_id,p_window_start,p_window_end,p_limit,p_cursor);
 rows:='[]'::jsonb;
 for row in select value from jsonb_array_elements(result->'meetings') loop
  place:=null;
  if row->>'episode_id' is not null then
   select place_id into place from private.cocreate_meeting_places where meeting_id=(row->>'meeting_id')::uuid;
  else
   select a.place_id into place from private.cocreate_place_associations(p_expected_profile_id,p_hub_id) a
    where a.meeting->>'meeting_id'=row->>'meeting_id' limit 1;
  end if;
  rows:=rows||jsonb_build_array(row||jsonb_build_object('place',private.cocreate_place_projection(place)));
 end loop;
 return jsonb_set(result,'{meetings}',rows);
end; $$;

create function private.cocreate_place_from_selection(p_actor uuid,p_kind text,p_episode uuid,
 p_revision bigint,p_receipt uuid,p_command uuid) returns uuid
language plpgsql security definer set search_path='' as $$
declare selected jsonb; identity_snapshot jsonb; hash text; result uuid; stored jsonb;
begin
 if private.lock_cocreate_place_scope(p_actor,p_kind,p_episode) is distinct from p_revision then
  raise sqlstate '22023' using message='Place selection is stale; select again.';end if;
 selected:=private.consume_location_receipt(p_actor,p_kind,p_episode,p_revision,'exact',p_receipt,p_command);
 if selected->>'kind' not in ('amenity','address') then
  raise sqlstate '22023' using message='A reusable place requires a verified venue or address.';end if;
 identity_snapshot:=selected-'verified_at';
 hash:=private.group_command_hash(identity_snapshot);
 insert into private.cocreate_places(snapshot,fingerprint) values(selected,hash)
  on conflict(fingerprint) do nothing returning id into result;
 if result is null then
  select id,snapshot-'verified_at' into result,stored from private.cocreate_places where fingerprint=hash;
  if stored is distinct from identity_snapshot then
   raise sqlstate '22023' using message='Place fingerprint collision.';end if;
 end if;
 return result;
end; $$;

create function private.cocreate_place_projection(p_place uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object('place_id',id,'selection',snapshot) from private.cocreate_places where id=p_place;
$$;

-- Current-member access follows CAL01-FIX01 even after symmetric blocking.
-- Newcomer place visibility is stricter: explicit publication and amenity only.
-- Address/off associations stay inside current numbered membership.
create function private.cocreate_place_associations(p_actor uuid,p_hub uuid,p_discovery boolean default false)
returns table(place_id uuid,room_id uuid,hub_id uuid,number integer,usual boolean,meeting jsonb)
language sql stable security definer set search_path='' as $$
 with rooms as materialized (
  select r.*,e.id member_episode,g.id general_room,ge.id general_episode,
   ge.exit_sequence,g.last_sequence general_frontier,
   private.cocreate_account_available(r.manager_id)
    and not private.has_active_user_block_between(p_actor,r.manager_id) newcomer
  from private.cocreate_rooms r
  join private.cocreate_rooms g on g.hub_id=r.hub_id and g.kind='general' and not g.archived and not g.suppressed
  left join private.cocreate_room_episodes ge on ge.room_id=g.id and ge.actor_id=p_actor and ge.ended_at is null
  left join private.cocreate_room_episodes e on e.room_id=r.id and e.actor_id=p_actor and e.ended_at is null
   and private.cocreate_hub_member(r.hub_id,p_actor)
  where (p_hub is null or r.hub_id=p_hub) and private.cocreate_numbered_public(r.id)
   and (p_discovery or (ge.id is not null and private.cocreate_hub_member(r.hub_id,p_actor)))
 ), meetings as (
  select r.*,m.id meeting_id,m.starts_at,m.capacity meeting_capacity,
   private.cocreate_meeting_occupied(m.id) occupied,c.id card_id,
   exists(select 1 from private.cocreate_meeting_attendance a
    where a.meeting_id=m.id and a.actor_id=p_actor and a.episode_id=r.member_episode and a.attending) attending,
   mp.place_id,mp.discoverable,p.snapshot->>'kind' place_kind
  from rooms r join private.cocreate_meetings m on m.room_id=r.id
  join private.cocreate_meeting_places mp on mp.meeting_id=m.id
  join private.cocreate_places p on p.id=mp.place_id
  left join lateral (
   select c.id from private.cocreate_recruitments c
   join private.cocreate_room_messages msg on msg.id=c.message_id
   where c.meeting_id=m.id and c.general_room_id=r.general_room
    and c.retracted_at is null and c.expires_at>statement_timestamp()
    and msg.sequence<=coalesce(r.exit_sequence,r.general_frontier)
   order by c.created_at desc,c.id desc limit 1
  ) c on true
  where m.cancelled_at is null and m.starts_at>statement_timestamp()
   and m.id=(select last.id from private.cocreate_meetings last
    where last.room_id=r.id order by last.created_at desc,last.id desc limit 1)
 )
 select rp.place_id,r.id,r.hub_id,r.group_number,true,null::jsonb
 from rooms r join private.cocreate_room_places rp on rp.room_id=r.id
 join private.cocreate_places p on p.id=rp.place_id
 where (not p_discovery and r.member_episode is not null)
  or (rp.discoverable and p.snapshot->>'kind'='amenity' and r.newcomer)
 union all
 select m.place_id,m.id,m.hub_id,m.group_number,false,jsonb_build_object(
  'meeting_id',m.meeting_id,'room_id',m.id,'number',m.group_number,'starts_at',m.starts_at,
  'capacity',m.meeting_capacity,'occupied',m.occupied,'state','scheduled','attending',m.attending,
  'episode_id',m.member_episode,'recruitment_id',m.card_id,
  'can_confirm',m.member_episode is not null and m.occupied<m.meeting_capacity,
  'can_join',m.member_episode is null and m.general_episode is not null and m.card_id is not null
    and private.cocreate_can_join_recruitment(p_actor,m.card_id))
 from meetings m where (not p_discovery and m.member_episode is not null)
  or (m.discoverable and m.place_kind='amenity' and m.newcomer and m.card_id is not null);
$$;

create function private.require_cocreate_places_hub(p_actor uuid,p_hub uuid,p_episode uuid) returns void
language plpgsql stable security definer set search_path='' as $$
begin
 if not exists(select 1 from private.cocreate_room_episodes e join private.cocreate_rooms r on r.id=e.room_id
  where e.id=p_episode and e.actor_id=p_actor and e.ended_at is null and r.kind='general'
   and r.hub_id=p_hub and not r.archived and not r.suppressed)
  or not private.cocreate_hub_public(p_hub) or not private.cocreate_hub_member(p_hub,p_actor) then
  raise sqlstate '42501' using message='Current community admission is required for Places.';end if;
end; $$;

create function public.get_cocreate_place_context_v1(p_expected_profile_id uuid,p_hub_id uuid,
 p_room_id uuid default null,p_episode_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_cocreate_actor(p_expected_profile_id);e private.cocreate_room_episodes;
 r private.cocreate_rooms;rp private.cocreate_room_places;
begin
 if (p_room_id is null)<>(p_episode_id is null) then raise sqlstate '22023' using message='Exact group scope required.';end if;
 if p_room_id is null then
  select * into r from private.cocreate_rooms where hub_id=p_hub_id and kind='general';
  select * into e from private.cocreate_room_episodes where room_id=r.id and actor_id=actor and ended_at is null;
  perform private.require_cocreate_places_hub(actor,p_hub_id,e.id);
 else
  e:=private.require_cocreate_room_episode(actor,p_room_id,p_episode_id,true);
  select * into r from private.cocreate_rooms where id=p_room_id and hub_id=p_hub_id and kind='numbered';
  if not found then raise sqlstate '42501' using message='The scoped group is unavailable.';end if;
  select * into rp from private.cocreate_room_places where room_id=r.id;
 end if;
 return jsonb_build_object('profile_id',actor,'hub_id',p_hub_id,'room_id',p_room_id,
  'episode_id',e.id,'version',case when p_room_id is null then 0 else r.version end,
  'is_manager',p_room_id is null or r.manager_id=actor,
  'usual_place',private.cocreate_place_projection(rp.place_id),'usual_discoverable',coalesce(rp.discoverable,false));
end; $$;

create function public.set_cocreate_usual_place_v1(p_expected_profile_id uuid,p_command_id uuid,
 p_hub_id uuid,p_room_id uuid,p_episode_id uuid,p_expected_version bigint,
 p_place_id uuid default null,p_selection_receipt uuid default null,p_discoverable boolean default false) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_cocreate_actor(p_expected_profile_id);r private.cocreate_rooms;
 prior private.cocreate_place_receipts;intent text;selected uuid:=p_place_id;result jsonb;
begin
 if num_nulls(p_command_id,p_hub_id,p_room_id,p_episode_id,p_expected_version,p_discoverable)>0
  or num_nonnulls(p_place_id,p_selection_receipt)>1 then raise sqlstate '22023' using message='Invalid usual-place intent.';end if;
 perform 1 from auth.users where id=actor for share;
 perform 1 from public.profiles where id=actor for share;
 perform private.require_cocreate_actor(actor);
 perform pg_advisory_xact_lock(hashtextextended('cocreate.room.actor:'||actor::text,0));
 perform private.cocreate_lock_hub(p_hub_id);
 intent:=private.group_command_hash(jsonb_build_array('usual_place',p_hub_id,p_room_id,p_episode_id,p_expected_version,p_place_id,p_selection_receipt,p_discoverable));
 select * into prior from private.cocreate_place_receipts where actor_id=actor and command_id=p_command_id;
 if found then
  if prior.intent_hash<>intent then raise sqlstate '22023' using message='The place command intent differs.';end if;
  return prior.result;
 end if;
 perform private.require_cocreate_room_episode(actor,p_room_id,p_episode_id,true);
 select * into r from private.cocreate_rooms where id=p_room_id and hub_id=p_hub_id and manager_id=actor and kind='numbered';
 if not found then raise sqlstate '42501' using message='Only the current manager can change the usual place.';end if;
 if r.version<>p_expected_version then raise sqlstate 'PT409' using message='The group changed; review its usual place.';end if;
 if p_selection_receipt is not null then
  selected:=private.cocreate_place_from_selection(actor,'cocreate_room',p_episode_id,r.version,p_selection_receipt,p_command_id);
 elsif selected is not null and not exists(select 1 from private.cocreate_place_associations(actor,p_hub_id) a where a.place_id=selected) then
  raise sqlstate '42501' using message='This existing Place is unavailable in the community.';
 end if;
 if p_discoverable and (selected is null or not exists(select 1 from private.cocreate_places
  where id=selected and snapshot->>'kind'='amenity')) then
  raise sqlstate '22023' using message='Discovery requires a verified public venue.';end if;
 if selected is null then delete from private.cocreate_room_places where room_id=r.id;
 else insert into private.cocreate_room_places values(r.id,selected,p_discoverable)
  on conflict(room_id) do update set place_id=excluded.place_id,discoverable=excluded.discoverable;end if;
 update private.cocreate_rooms set version=version+1 where id=r.id returning * into r;
 result:=jsonb_build_object('operation','usual_place','hub_id',p_hub_id,'room_id',r.id,
  'episode_id',p_episode_id,'place_id',selected,'discoverable',p_discoverable,'version',r.version);
 insert into private.cocreate_place_receipts values(actor,p_command_id,intent,result);
 perform private.cocreate_signal(actor);
 return result;
end; $$;

create function public.schedule_cocreate_meeting_v2(p_expected_profile_id uuid,p_command_id uuid,p_hub_id uuid,
 p_starts_at timestamptz,p_capacity integer,p_room_id uuid default null,p_episode_id uuid default null,
 p_place_id uuid default null,p_selection_receipt uuid default null,p_scope_episode_id uuid default null,
 p_scope_revision bigint default null,p_discoverable boolean default false) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_cocreate_actor(p_expected_profile_id);prior private.cocreate_place_receipts;
 intent text;result jsonb;selected uuid:=p_place_id;kind text;
begin
 if num_nulls(p_command_id,p_hub_id,p_starts_at,p_capacity,p_discoverable)>0
  or num_nonnulls(p_place_id,p_selection_receipt)>1 or (p_room_id is null)<>(p_episode_id is null) then
  raise sqlstate '22023' using message='Invalid scheduled-place intent.';end if;
 perform 1 from auth.users where id=actor for share;
 perform 1 from public.profiles where id=actor for share;
 perform private.require_cocreate_actor(actor);
 perform pg_advisory_xact_lock(hashtextextended('cocreate.room.actor:'||actor::text,0));
 perform private.cocreate_lock_hub(p_hub_id);
 intent:=private.group_command_hash(jsonb_build_array('schedule_meeting_v2',p_hub_id,p_starts_at,p_capacity,
  p_room_id,p_episode_id,p_place_id,p_selection_receipt,p_scope_episode_id,p_scope_revision,p_discoverable));
 select * into prior from private.cocreate_place_receipts where actor_id=actor and command_id=p_command_id;
 if found then
  if prior.intent_hash<>intent then raise sqlstate '22023' using message='The meeting-place intent differs.';end if;
  return prior.result;
 end if;
 if p_selection_receipt is not null then
  kind:=case when p_room_id is null then 'cocreate_hub' else 'cocreate_room' end;
  perform 1 from private.cocreate_rooms r join private.cocreate_room_episodes e on e.room_id=r.id
   where e.id=p_scope_episode_id and e.actor_id=actor and e.ended_at is null and r.hub_id=p_hub_id
    and (p_room_id is null or (r.id=p_room_id and e.id=p_episode_id));
  if not found then raise sqlstate '42501' using message='The place-selection target changed.';end if;
  selected:=private.cocreate_place_from_selection(actor,kind,p_scope_episode_id,p_scope_revision,p_selection_receipt,p_command_id);
 elsif selected is not null and not exists(select 1 from private.cocreate_place_associations(actor,p_hub_id) a where a.place_id=selected) then
  raise sqlstate '42501' using message='This existing Place is unavailable in the community.';
 end if;
 if p_discoverable and (selected is null or not exists(select 1 from private.cocreate_places
  where id=selected and snapshot->>'kind'='amenity')) then
  raise sqlstate '22023' using message='Discovery requires a verified public venue.';end if;
 -- The installed atomic scheduler remains the sole admission/attendance writer.
 -- A private child command and the outer immutable intent commit together.
 result:=public.schedule_cocreate_meeting(actor,gen_random_uuid(),p_hub_id,p_starts_at,p_capacity,p_room_id,p_episode_id);
 if selected is not null then insert into private.cocreate_meeting_places values((result->>'meeting_id')::uuid,selected,p_discoverable);end if;
 result:=result||jsonb_build_object('place_id',selected,'discoverable',p_discoverable);
 insert into private.cocreate_place_receipts values(actor,p_command_id,intent,result);
 return result;
end; $$;

-- Extend only the scope dispatch; preserve the existing meters/cache/provider ledger.
alter table private.location_search_batches drop constraint location_search_batches_item_kind_check;
alter table private.location_search_batches add constraint location_search_batches_item_kind_check
 check(item_kind in ('one_time','recurring','resource','cocreate_hub','cocreate_room'));
create or replace function private.lock_location_item(p_actor uuid,p_kind text,p_item uuid)
returns bigint language plpgsql security definer set search_path = '' as $$
declare owner_id uuid; state text; starts timestamptz; revision bigint;
begin
  if p_kind in ('cocreate_hub','cocreate_room') then
    return private.lock_cocreate_place_scope(p_actor,p_kind,p_item);
  end if;
  if p_actor is null or not exists(select 1 from public.profiles where id=p_actor) then
    raise exception using errcode='42501',message='Location actor unavailable.';
  end if;
  if p_kind='one_time' then
    select creator_profile_id,lifecycle_state,starts_at,location_revision into owner_id,state,starts,revision
      from public.proposals where id=p_item for update;
    if owner_id is null or not private.profile_has_project_structural_authority(p_item,p_actor)
      or (state='draft' and owner_id<>p_actor) then
      raise exception using errcode='42501',message='Location edit unavailable.';
    end if;
    if state not in ('draft','published') or (state='published' and starts<=statement_timestamp()) then
      raise exception using errcode='55000',message='Location item is immutable.';
    end if;
  elsif p_kind='recurring' then
    select creator_profile_id,lifecycle_state,location_revision into owner_id,state,revision
      from public.recurring_activities where id=p_item for update;
    if owner_id is null or not private.profile_has_project_structural_authority(p_item,p_actor)
      or (state='draft' and owner_id<>p_actor) then
      raise exception using errcode='42501',message='Location edit unavailable.';
    end if;
    if state='ended' then raise exception using errcode='55000',message='Location item is immutable.'; end if;
  elsif p_kind='resource' then
    select owner_profile_id,lifecycle_state,location_revision into owner_id,state,revision
      from public.resource_listings where id=p_item for update;
    if owner_id is null or owner_id<>p_actor then raise exception using errcode='42501',message='Location edit unavailable.'; end if;
    if state='closed' then raise exception using errcode='55000',message='Location item is immutable.'; end if;
  else raise exception using errcode='22023',message='Invalid location item kind.';
  end if;
  return revision;
end;
$$;
create or replace function public.reserve_location_search_v1(p_actor uuid,p_kind text,p_item uuid,p_revision bigint,p_slot text,p_session uuid,p_query_hash text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare cfg private.location_search_config%rowtype; batch private.location_search_batches%rowtype;
  current_revision bigint; daily timestamptz := date_trunc('day',statement_timestamp() at time zone 'UTC') at time zone 'UTC';
  minute timestamptz := date_trunc('minute',statement_timestamp()); used_count integer;
 provider_status text;
begin
  current_revision := private.lock_location_item(p_actor,p_kind,p_item);
  if p_revision is distinct from current_revision then return jsonb_build_object('status','stale_selection'); end if;
  if p_session is null or p_query_hash is null or p_query_hash !~ '^[a-f0-9]{64}$'
    or (p_kind in ('cocreate_hub','cocreate_room') and p_slot is distinct from 'exact')
    or p_slot is null or (p_slot='place' and p_kind<>'one_time') or (p_kind='resource' and p_slot<>'public') or (p_kind<>'resource' and p_slot not in ('area','exact','place')) then
    raise exception using errcode='22023',message='Invalid location search scope.';
  end if;
  select * into cfg from private.location_search_config where singleton for update;
  if not found or not cfg.enabled then return jsonb_build_object('status','disabled'); end if;
  provider_status := private.reserve_location_provider_v1('editor',p_actor,false);
  if provider_status<>'ok' then return jsonb_build_object('status',provider_status); end if;
  -- Remove expired derived data without retaining provider responses/search text.
  delete from private.location_search_batches where expires_at<=statement_timestamp();
  delete from private.location_search_budgets where bucket<daily;
  select * into batch from private.location_search_batches
    where actor=p_actor and item_kind=p_kind and item_id=p_item and revision=p_revision
      and slot=p_slot and session_id=p_session and query_hash=p_query_hash and expires_at>statement_timestamp()
    order by expires_at desc limit 1;
  if found then
    if not batch.ready then return jsonb_build_object('status','search_pending'); end if;
    return jsonb_build_object('status','ok','cached',true,'suggestions',coalesce(
      (select jsonb_agg(jsonb_build_object('id',r.id,'place',r.place,'expires_at',batch.expires_at) order by r.id)
       from private.location_selection_receipts r where r.batch_id=batch.id and r.used_request is null),'[]'::jsonb));
  end if;
  -- Rendering shares an account ceiling with autocomplete. The search-config
  -- row lock above serializes both meters; cache hits consume no new credits.
  if not exists(select 1 from private.location_preview_config where singleton) then
    return jsonb_build_object('status','metering_unavailable');
  end if;
  if exists(select 1 from private.location_preview_config c where singleton
    and (c.enabled or c.account_daily_credit_limit>0)
    and coalesce((select used from private.location_preview_usage where scope='credits:global' and bucket=daily),0)
      +coalesce((select used from private.location_search_budgets where scope='global' and bucket=daily),0)+1
      >c.account_daily_credit_limit) then
    return jsonb_build_object('status','budget_exhausted');
  end if;
  select used into used_count from private.location_search_budgets where scope='global' and bucket=daily;
  if coalesce(used_count,0)>=cfg.global_daily then return jsonb_build_object('status','budget_exhausted'); end if;
  select used into used_count from private.location_search_budgets where scope='actor:'||p_actor and bucket=daily;
  if coalesce(used_count,0)>=cfg.actor_daily then return jsonb_build_object('status','budget_exhausted'); end if;
  select used into used_count from private.location_search_budgets where scope='minute:'||p_actor and bucket=minute;
  if coalesce(used_count,0)>=cfg.actor_minute then return jsonb_build_object('status','rate_limited'); end if;
  provider_status := private.reserve_location_provider_v1('editor',p_actor,true);
  if provider_status<>'ok' then return jsonb_build_object('status',provider_status); end if;
  insert into private.location_search_budgets(scope,bucket,used) values ('global',daily,1),('actor:'||p_actor,daily,1),('minute:'||p_actor,minute,1)
    on conflict(scope,bucket) do update set used=private.location_search_budgets.used+1;
  insert into private.location_search_batches(actor,item_kind,item_id,revision,slot,session_id,query_hash)
    values(p_actor,p_kind,p_item,p_revision,p_slot,p_session,p_query_hash) returning * into batch;
  return jsonb_build_object('status','ok','cached',false,'batch_id',batch.id);
end;
$$;


do $permissions$ declare f record; begin
 for f in select p.oid::regprocedure signature,n.nspname schema from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where (n.nspname='private' and p.proname in ('lock_cocreate_place_scope','cocreate_place_from_selection',
  'cocreate_place_projection','cocreate_place_associations','require_cocreate_places_hub'))
 or (n.nspname='public' and p.proname in ('get_cocreate_place_context_v1','set_cocreate_usual_place_v1',
  'schedule_cocreate_meeting_v2','list_cocreate_places_v1','get_cocreate_place_detail_v1',
  'list_discoverable_cocreate_places_v1','get_cocreate_calendar_v2','get_cocreate_current_meeting_v2','get_cocreate_recruitment_review_v2')) loop
  execute 'revoke all on function '||f.signature||' from public,anon,authenticated,service_role';
  if f.schema='public' then execute 'grant execute on function '||f.signature||' to authenticated';end if;
 end loop;
end; $permissions$;
reset lock_timeout;
reset statement_timeout;
