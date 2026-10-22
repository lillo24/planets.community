-- C03: stable numbered rooms. All operations serialize on the owning hub row.
alter table private.cocreate_hubs add column next_group_number integer not null default 1 check(next_group_number>0);
alter table private.cocreate_settings
 add column max_numbered_memberships integer not null default 50 check(max_numbered_memberships between 1 and 200),
 add column numbered_creations_per_day integer not null default 5 check(numbered_creations_per_day between 1 and 50);
alter table private.cocreate_rooms drop constraint cocreate_room_kind,
 add constraint cocreate_room_kind check(kind in('general','numbered')),
 add column group_number integer,
 add column capacity integer,
 add column manager_id uuid,
 add constraint cocreate_numbered_shape check(
  (kind='general' and num_nonnulls(group_number,capacity,manager_id)=0)
  or (kind='numbered' and num_nonnulls(group_number,capacity,manager_id)=3 and group_number>0 and capacity between 2 and 50));
create unique index cocreate_number_per_hub on private.cocreate_rooms(hub_id,group_number) where kind='numbered';
create index cocreate_numbered_creator_rate on private.cocreate_rooms(manager_id,created_at desc) where kind='numbered';
create table private.cocreate_room_exclusions (
 room_id uuid not null references private.cocreate_rooms(id),actor_id uuid not null,active boolean not null default true,
 primary key(room_id,actor_id)
);
alter table private.cocreate_room_exclusions enable row level security;
revoke all on private.cocreate_room_exclusions from public,anon,authenticated,service_role;

create function private.cocreate_hub_member(p_hub uuid,p_actor uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from private.cocreate_rooms r join private.cocreate_room_episodes e on e.room_id=r.id
  where r.hub_id=p_hub and r.kind='general' and e.actor_id=p_actor and e.ended_at is null)
  and not exists(select 1 from private.cocreate_hub_exclusions where hub_id=p_hub and actor_id=p_actor and active);
$$;
create function private.cocreate_numbered_occupied(p_room uuid) returns integer
language sql stable security definer set search_path='' as $$
 select count(*)::integer from private.cocreate_room_episodes where room_id=p_room and ended_at is null;
$$;
create function private.cocreate_archive_numbered(p_room uuid) returns void
language plpgsql security definer set search_path='' as $$
declare room private.cocreate_rooms;
begin
 select * into room from private.cocreate_rooms where id=p_room and kind='numbered';
 if not found then raise sqlstate '42501' using message='The numbered group is unavailable.';end if;
 update private.cocreate_room_episodes set ended_at=clock_timestamp(),exit_sequence=room.last_sequence
  where room_id=room.id and ended_at is null;
 update private.cocreate_rooms set archived=true,version=version+1 where id=room.id and not archived;
end; $$;
create or replace function private.cocreate_cascade_hub_exit(p_hub uuid,p_actor uuid) returns void
language plpgsql security definer set search_path='' as $$
declare room private.cocreate_rooms;
begin
 if p_hub is null or p_actor is null then raise sqlstate '22023' using message='A scoped hub exit is required.';end if;
 -- Caller owns the hub lock. Every child send/join/exit uses that same lock.
 for room in select r.* from private.cocreate_rooms r where r.hub_id=p_hub and r.kind='numbered' and exists(
   select 1 from private.cocreate_room_episodes e where e.room_id=r.id and e.actor_id=p_actor and e.ended_at is null)
  order by r.id loop
  if room.manager_id=p_actor then perform private.cocreate_archive_numbered(room.id);
  else
   update private.cocreate_room_episodes set ended_at=clock_timestamp(),exit_sequence=room.last_sequence
    where room_id=room.id and actor_id=p_actor and ended_at is null;
   if private.cocreate_numbered_occupied(room.id)=0 then perform private.cocreate_archive_numbered(room.id);
   else update private.cocreate_rooms set version=version+1 where id=room.id;end if;
  end if;
 end loop;
end; $$;

create function public.mutate_cocreate_numbered_group(p_expected_profile_id uuid,p_command_id uuid,p_hub_id uuid,p_operation text,
 p_room_id uuid default null,p_episode_id uuid default null,p_capacity integer default null,
 p_target_profile_id uuid default null,p_expected_version bigint default null,p_muted boolean default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid;hub private.cocreate_hubs;room private.cocreate_rooms;episode private.cocreate_room_episodes;
 target private.cocreate_room_episodes;prior private.cocreate_room_receipts;manager uuid;intent text;result jsonb;
begin
 actor:=case when p_operation='leave' then private.require_cocreate_identity(p_expected_profile_id)
  else private.require_cocreate_actor(p_expected_profile_id) end;
 if p_command_id is null or p_hub_id is null or p_operation is null
  or p_operation not in('create','join','leave','capacity','remove','restore_member','archive','mute')
  or (p_operation='create')<>(p_room_id is null)
  or (p_operation in('create','join'))<>(p_episode_id is null)
  or (p_capacity is not null and (p_operation not in('create','capacity') or p_capacity not between 2 and 50))
  or (p_operation='capacity' and p_capacity is null)
  or (p_operation in('remove','restore_member'))<>(p_target_profile_id is not null)
  or (p_operation='mute')<>(p_muted is not null)
  or (p_operation in('capacity','remove','restore_member','archive'))<>(p_expected_version is not null) then
   raise sqlstate '22023' using message='Invalid numbered-group command.';end if;
 if p_room_id is not null then
  select * into room from private.cocreate_rooms where id=p_room_id and hub_id=p_hub_id and kind='numbered';
  if not found then raise sqlstate '42501' using message='The numbered group is unavailable.';end if;
  manager:=room.manager_id;
 else manager:=actor;end if;
 if p_operation<>'leave' then
  -- Sorted identity locks precede the canonical blocked-pair lock and hub lock.
  perform 1 from auth.users where id in(actor,manager) order by id for share;
  perform 1 from public.profiles where id in(actor,manager) order by id for share;
  perform private.require_cocreate_actor(actor);
 end if;
 perform pg_advisory_xact_lock(hashtextextended('cocreate.room.actor:'||actor::text,0));
 if p_operation='join' and actor<>manager then perform private.lock_user_interaction_pair(actor,manager);end if;
 hub:=private.cocreate_lock_hub(p_hub_id);
 if p_room_id is not null then select * into room from private.cocreate_rooms where id=p_room_id;end if;
 intent:=private.group_command_hash(jsonb_build_array('numbered',p_hub_id,p_operation,p_room_id,p_episode_id,p_capacity,p_target_profile_id,p_expected_version,p_muted));
 select * into prior from private.cocreate_room_receipts where actor_id=actor and command_id=p_command_id;
 if found then
  if prior.intent_hash<>intent then raise sqlstate '22023' using message='The room command intent differs.';end if;
  return prior.result;
 end if;
 if p_operation<>'leave' and (not private.cocreate_hub_public(hub.id) or not private.cocreate_hub_member(hub.id,actor)) then
  raise sqlstate '42501' using message='Explicit current hub membership is required.';end if;
 if p_operation in('create','join') and not exists(select 1 from private.cocreate_room_episodes where room_id=room.id and actor_id=actor and ended_at is null)
  and (select count(*) from private.cocreate_room_episodes e join private.cocreate_rooms r on r.id=e.room_id
   where e.actor_id=actor and e.ended_at is null and r.kind='numbered')>=(select max_numbered_memberships from private.cocreate_settings) then
  raise sqlstate 'PT429' using message='The numbered membership limit was reached.';end if;
 if p_operation='create' then
  if (select count(*) from private.cocreate_rooms where kind='numbered' and manager_id=actor and created_at>clock_timestamp()-interval '24 hours')
   >=(select numbered_creations_per_day from private.cocreate_settings) then raise sqlstate 'PT429' using message='The numbered creation limit was reached.';end if;
  if hub.next_group_number=2147483647 then raise sqlstate '54000' using message='The hub numbering range is exhausted.';end if;
  insert into private.cocreate_rooms(hub_id,kind,group_number,capacity,manager_id)
   values(hub.id,'numbered',hub.next_group_number,coalesce(p_capacity,5),actor) returning * into room;
  update private.cocreate_hubs set next_group_number=next_group_number+1 where id=hub.id;
  insert into private.cocreate_room_episodes(room_id,actor_id,read_sequence) values(room.id,actor,0) returning * into episode;
 elsif p_operation='join' then
  if room.archived or room.suppressed or not private.cocreate_account_available(room.manager_id)
   or private.has_active_user_block_between(actor,room.manager_id)
   or exists(select 1 from private.cocreate_room_exclusions where room_id=room.id and actor_id=actor and active) then
   raise sqlstate '42501' using message='Numbered group admission is unavailable.';end if;
  select * into episode from private.cocreate_room_episodes where room_id=room.id and actor_id=actor and ended_at is null;
  if not found then
   if private.cocreate_numbered_occupied(room.id)>=room.capacity then raise sqlstate 'PT409' using message='The numbered group is full.';end if;
   insert into private.cocreate_room_episodes(room_id,actor_id,read_sequence) values(room.id,actor,room.last_sequence) returning * into episode;
   update private.cocreate_rooms set version=version+1 where id=room.id returning * into room;
  end if;
 else
  select * into episode from private.cocreate_room_episodes where id=p_episode_id and room_id=room.id and actor_id=actor and ended_at is null;
  if not found then raise sqlstate 'PT409' using message='Review the current numbered membership.';end if;
  if p_operation='leave' then
   if room.manager_id=actor then perform private.cocreate_archive_numbered(room.id);
   else
    update private.cocreate_room_episodes set ended_at=clock_timestamp(),exit_sequence=room.last_sequence where id=episode.id;
    if private.cocreate_numbered_occupied(room.id)=0 then perform private.cocreate_archive_numbered(room.id);
    else update private.cocreate_rooms set version=version+1 where id=room.id;end if;
   end if;
  elsif p_operation='mute' then
   if room.archived or room.suppressed then raise sqlstate '42501' using message='The numbered group is unavailable.';end if;
   update private.cocreate_room_episodes set muted=p_muted where id=episode.id;
  else
   if room.manager_id<>actor or room.archived or room.suppressed then raise sqlstate '42501' using message='Only this active group creator manages it.';end if;
   if room.version<>p_expected_version then raise sqlstate 'PT409' using message='The numbered group changed.';end if;
   if p_operation='capacity' then
    if p_capacity<private.cocreate_numbered_occupied(room.id) then raise sqlstate 'PT409' using message='Capacity cannot be smaller than occupied seats.';end if;
    update private.cocreate_rooms set capacity=p_capacity,version=version+1 where id=room.id;
   elsif p_operation='archive' then perform private.cocreate_archive_numbered(room.id);
   elsif p_operation='remove' then
    if p_target_profile_id=actor then raise sqlstate '22023' using message='Use explicit leave for your own membership.';end if;
    select * into target from private.cocreate_room_episodes where room_id=room.id and actor_id=p_target_profile_id and ended_at is null;
    if not found then raise sqlstate 'PT409' using message='The target is no longer a current member.';end if;
    update private.cocreate_room_episodes set ended_at=clock_timestamp(),exit_sequence=room.last_sequence where id=target.id;
    insert into private.cocreate_room_exclusions values(room.id,p_target_profile_id,true)
     on conflict(room_id,actor_id) do update set active=true;
    update private.cocreate_rooms set version=version+1 where id=room.id;
   else
    update private.cocreate_room_exclusions set active=false where room_id=room.id and actor_id=p_target_profile_id and active;
    if not found then raise sqlstate 'PT409' using message='No active removal barrier exists.';end if;
    update private.cocreate_rooms set version=version+1 where id=room.id;
   end if;
  end if;
  select * into room from private.cocreate_rooms where id=room.id;
 end if;
 result:=jsonb_build_object('operation',p_operation,'hub_id',hub.id,'room_id',room.id,'episode_id',episode.id,
  'number',room.group_number,'capacity',room.capacity,'version',room.version,'archived',room.archived);
 insert into private.cocreate_room_receipts values(actor,p_command_id,intent,result);
 insert into private.audit_events(action,target_type,target_id,metadata) values('cocreate.numbered.'||p_operation,'cocreate_room',room.id,
  jsonb_build_object('actor_id',actor,'version',room.version,'target_profile_id',p_target_profile_id));
 perform private.cocreate_signal(actor);
 return result;
end; $$;

create function private.cocreate_numbered_public(p_room uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from private.cocreate_rooms r where r.id=p_room and r.kind='numbered'
  and not r.archived and not r.suppressed and private.cocreate_hub_public(r.hub_id));
$$;
create function private.cocreate_numbered_projection(p_room uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object('room_id',r.id,'hub_id',r.hub_id,'number',r.group_number,'capacity',r.capacity,
  'occupied',private.cocreate_numbered_occupied(r.id),'available',private.cocreate_numbered_occupied(r.id)<r.capacity,'created_at',r.created_at)
 from private.cocreate_rooms r where r.id=p_room and r.kind='numbered';
$$;
create function public.list_cocreate_numbered_groups(p_hub_id uuid,p_open_seats_only boolean default false,
 p_limit integer default 25,p_after_number integer default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 perform private.require_cocreate_enabled();
 if p_limit is null or p_limit not between 1 and 50 or p_open_seats_only is null or p_after_number<1 then
  raise sqlstate '22023' using message='Invalid numbered group page.';end if;
 return (select coalesce(jsonb_agg(private.cocreate_numbered_projection(r.id) order by r.group_number),'[]'::jsonb) from (
  select r.* from private.cocreate_rooms r where r.hub_id=p_hub_id and private.cocreate_numbered_public(r.id)
   and (not p_open_seats_only or private.cocreate_numbered_occupied(r.id)<r.capacity)
   and (p_after_number is null or r.group_number>p_after_number) order by r.group_number limit p_limit)r);
end; $$;
create function public.get_cocreate_numbered_group(p_room_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 perform private.require_cocreate_enabled();
 if private.cocreate_numbered_public(p_room_id) then return private.cocreate_numbered_projection(p_room_id);end if;
 return null;
end; $$;
create function public.get_own_cocreate_numbered_membership(p_expected_profile_id uuid,p_room_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_cocreate_actor(p_expected_profile_id);episode private.cocreate_room_episodes;
begin
 select e.* into episode from private.cocreate_room_episodes e join private.cocreate_rooms r on r.id=e.room_id
  where e.room_id=p_room_id and e.actor_id=actor and r.kind='numbered' order by e.joined_at desc,e.id desc limit 1;
 if not found then return null;end if;
 perform private.require_cocreate_room_episode(actor,p_room_id,episode.id);
 return (select jsonb_build_object('hub_id',r.hub_id,'room_id',r.id,'episode_id',episode.id,
  'active',episode.ended_at is null,'muted',episode.muted) from private.cocreate_rooms r where r.id=p_room_id);
end; $$;
create function public.get_cocreate_numbered_context(p_expected_profile_id uuid,p_hub_id uuid,p_room_id uuid,p_episode_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_cocreate_actor(p_expected_profile_id);
 episode private.cocreate_room_episodes:=private.require_cocreate_room_episode(actor,p_room_id,p_episode_id);
 result jsonb;
begin
 select jsonb_build_object('profile_id',actor,'hub_id',h.id,'room_id',r.id,'episode_id',episode.id,
  'topic_label',t.label,'locality',h.locality,'closed',episode.ended_at is not null,'muted',episode.muted,
  'number',r.group_number,'capacity',r.capacity,'occupied',private.cocreate_numbered_occupied(r.id),
  'version',r.version,'archived',r.archived,'manager_profile_id',r.manager_id,
  'is_manager',r.manager_id=actor and episode.ended_at is null and not r.archived and private.cocreate_hub_member(h.id,actor)) into result
 from private.cocreate_rooms r join private.cocreate_hubs h on h.id=r.hub_id join private.cocreate_topics t on t.id=h.topic_id
 where r.id=p_room_id and h.id=p_hub_id and r.kind='numbered';
 if result is null then raise sqlstate '42501' using message='The numbered route context is unavailable.';end if;
 return result;
end; $$;
create function public.list_own_cocreate_rooms_v2(p_expected_profile_id uuid,p_limit integer default 25,
 p_before_joined_at timestamptz default null,p_before_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_cocreate_actor(p_expected_profile_id);
begin
 perform private.cocreate_page(p_limit,p_before_joined_at,p_before_id);
 return (select coalesce(jsonb_agg(to_jsonb(t) order by t.joined_at desc,t.episode_id desc),'[]'::jsonb) from (
  select r.id room_id,r.hub_id,t.label topic_label,h.locality,e.id episode_id,
   e.ended_at is not null closed,e.muted,e.joined_at,private.cocreate_room_unread(e::private.cocreate_room_episodes) unread_count,
   r.kind,r.group_number number
  from private.cocreate_rooms r join private.cocreate_hubs h on h.id=r.hub_id join private.cocreate_topics t on t.id=h.topic_id
  join lateral(select * from private.cocreate_room_episodes e where e.room_id=r.id and e.actor_id=actor order by e.joined_at desc,e.id desc limit 1)e on true
  where not r.suppressed and not h.suppressed
   and (p_before_id is null or (e.joined_at,e.id)<(p_before_joined_at,p_before_id))
  order by e.joined_at desc,e.id desc limit p_limit)t);
end; $$;
-- Retain the installed General-only shape; numbered rows use the versioned reader.
do $$ declare source text:=pg_get_functiondef('public.list_own_cocreate_rooms(uuid,integer,timestamptz,uuid)'::regprocedure);begin
 if strpos(source,'where not r.suppressed and not h.suppressed')=0 then raise exception 'Unknown General list predecessor.';end if;
 execute replace(source,'where not r.suppressed and not h.suppressed','where r.kind=''general'' and not r.suppressed and not h.suppressed');
end; $$;
create function public.list_own_cocreate_numbered_exits(p_expected_profile_id uuid,p_limit integer default 25,
 p_before_joined_at timestamptz default null,p_before_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_cocreate_identity(p_expected_profile_id);
begin
 perform private.cocreate_page(p_limit,p_before_joined_at,p_before_id);
 return (select coalesce(jsonb_agg(to_jsonb(t) order by t.joined_at desc,t.episode_id desc),'[]'::jsonb) from (
  select r.hub_id,r.id room_id,e.id episode_id,e.joined_at from private.cocreate_room_episodes e join private.cocreate_rooms r on r.id=e.room_id
  where e.actor_id=actor and e.ended_at is null and r.kind='numbered'
   and (p_before_id is null or (e.joined_at,e.id)<(p_before_joined_at,p_before_id))
  order by e.joined_at desc,e.id desc limit p_limit)t);
end; $$;

create or replace function private.require_cocreate_room_episode(p_actor uuid,p_room uuid,p_episode uuid,p_sending boolean default false)
returns private.cocreate_room_episodes language plpgsql stable security definer set search_path='' as $$
declare episode private.cocreate_room_episodes;room private.cocreate_rooms;hub private.cocreate_hubs;
begin
 perform private.require_cocreate_actor(p_actor);
 select * into room from private.cocreate_rooms where id=p_room;
 select * into hub from private.cocreate_hubs where id=room.hub_id;
 select * into episode from private.cocreate_room_episodes where id=p_episode and actor_id=p_actor and room_id=p_room;
 if episode.id is null or room.suppressed or hub.suppressed
  or (p_sending and (episode.ended_at is not null or room.archived or not private.cocreate_hub_public(hub.id)
   or (room.kind='numbered' and not private.cocreate_hub_member(hub.id,p_actor)))) then
   raise sqlstate '42501' using message='The room or membership episode is unavailable.';end if;
 return episode;
end; $$;
create function public.moderate_cocreate_numbered_group(p_expected_staff_profile_id uuid,p_command_id uuid,p_case_id uuid,
 p_expected_version bigint,p_operation text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=p_expected_staff_profile_id;room private.cocreate_rooms;evidence jsonb;subject uuid;
 prior private.cocreate_room_receipts;intent text;result jsonb;
begin
 perform private.require_moderation_staff(actor);
 if p_command_id is null or p_case_id is null or p_expected_version is null or p_operation is null
  or p_operation not in('suppress','restore','remove_sender','allow_sender','archive') then raise sqlstate '22023' using message='Invalid numbered moderation command.';end if;
 perform pg_advisory_xact_lock(hashtextextended('cocreate.room.actor:'||actor::text,0));
 perform private.require_moderation_staff(actor);
 select cocreate_evidence into evidence from private.moderation_cases where id=p_case_id and target_kind='cocreate_room_message';
 if evidence is null then raise sqlstate '42501' using message='The room report evidence is unavailable.';end if;
 select * into room from private.cocreate_rooms where id=(evidence->>'room_id')::uuid and kind='numbered';
 if not found then raise sqlstate '42501' using message='The scoped numbered group is unavailable.';end if;
 perform private.cocreate_lock_hub(room.hub_id);
 select * into room from private.cocreate_rooms where id=room.id;
 subject:=(evidence->>'sender_id')::uuid;
 intent:=private.group_command_hash(jsonb_build_array('numbered moderation',p_case_id,p_expected_version,p_operation));
 select * into prior from private.cocreate_room_receipts where actor_id=actor and command_id=p_command_id;
 if found then
  if prior.intent_hash<>intent then raise sqlstate '22023' using message='The room command intent differs.';end if;
  return prior.result;
 end if;
 if room.version<>p_expected_version then raise sqlstate 'PT409' using message='The numbered group changed.';end if;
 if p_operation in('suppress','restore') then
  update private.cocreate_rooms set suppressed=p_operation='suppress',version=version+1 where id=room.id;
 elsif p_operation='archive' then perform private.cocreate_archive_numbered(room.id);
 elsif p_operation='remove_sender' then
  if room.manager_id=subject then perform private.cocreate_archive_numbered(room.id);
  else
   update private.cocreate_room_episodes set ended_at=clock_timestamp(),exit_sequence=room.last_sequence
    where room_id=room.id and actor_id=subject and ended_at is null;
   update private.cocreate_rooms set version=version+1 where id=room.id;
  end if;
  insert into private.cocreate_room_exclusions values(room.id,subject,true) on conflict(room_id,actor_id) do update set active=true;
 else
  update private.cocreate_room_exclusions set active=false where room_id=room.id and actor_id=subject;
  update private.cocreate_rooms set version=version+1 where id=room.id;
 end if;
 select * into room from private.cocreate_rooms where id=room.id;
 result:=jsonb_build_object('room_id',room.id,'version',room.version,'operation',p_operation);
 insert into private.cocreate_room_receipts values(actor,p_command_id,intent,result);
 insert into private.audit_events(action,target_type,target_id,metadata) values('cocreate.numbered.moderated','cocreate_room',room.id,
  jsonb_build_object('actor_id',actor,'case_id',p_case_id,'version',room.version,'operation',p_operation));
 perform private.cocreate_signal(subject);
 return result;
end; $$;

-- A permanently erased identity vacates its existing memberships. This changes
-- access/lifecycle only, never erases retained content or invents retention.
-- Temporary suspension reserves membership/seats while denying account actions.
create function private.cocreate_end_erased_memberships(p_actor uuid) returns void
language plpgsql security definer set search_path='' as $$
declare hub uuid;general private.cocreate_rooms;
begin
 for hub in select distinct r.hub_id from private.cocreate_room_episodes e join private.cocreate_rooms r on r.id=e.room_id
  where e.actor_id=p_actor and e.ended_at is null order by r.hub_id loop
  perform private.cocreate_lock_hub(hub);
  perform private.cocreate_cascade_hub_exit(hub,p_actor);
  select * into general from private.cocreate_rooms where hub_id=hub and kind='general';
  update private.cocreate_room_episodes set ended_at=clock_timestamp(),exit_sequence=general.last_sequence
   where room_id=general.id and actor_id=p_actor and ended_at is null;
 end loop;
end; $$;
do $$ declare name text;canonical oid;source text;definition text;permissions aclitem[];addition text;begin
 foreach name in array array['cocreate_access_change_signal','cocreate_deleted_account_signal']loop
  canonical:=to_regprocedure('private.'||name||'()');
  select prosrc,proacl into source,permissions from pg_proc where oid=canonical;
  if canonical is null or strpos(source,E'begin\n')=0 or strpos(source,'cocreate_end_erased_memberships')>0 then raise exception 'Unknown co-creation identity predecessor: %',name;end if;
  if name='cocreate_access_change_signal' then
   addition:=E'begin\n if tg_table_name=''users'' then\n  if new.deleted_at is not null and old.deleted_at is null then perform private.cocreate_end_erased_memberships(new.id);end if;\n end if;\n';
  else addition:=E'begin\n perform private.cocreate_end_erased_memberships(old.id);\n';end if;
  definition:=pg_get_functiondef(canonical);
  execute replace(definition,source,replace(source,E'begin\n',addition));
  if (select proacl from pg_proc where oid=canonical) is distinct from permissions then raise exception 'Identity hook grants changed.';end if;
 end loop;
end; $$;

do $$ declare fn regprocedure;begin
 for fn in select p.oid::regprocedure from pg_proc p where p.pronamespace='private'::regnamespace and p.proname like '%cocreate%'
 loop execute format('revoke all on function %s from public,anon,authenticated,service_role',fn);end loop;
 for fn in select p.oid::regprocedure from pg_proc p where p.pronamespace='public'::regnamespace and p.proname in(
  'mutate_cocreate_numbered_group','list_cocreate_numbered_groups','get_cocreate_numbered_group',
  'get_own_cocreate_numbered_membership','get_cocreate_numbered_context','list_own_cocreate_rooms_v2',
  'list_own_cocreate_numbered_exits','moderate_cocreate_numbered_group') loop
  execute format('revoke all on function %s from public,anon,authenticated,service_role',fn);
  execute format('grant execute on function %s to authenticated',fn);
 end loop;
end; $$;
grant execute on function public.list_cocreate_numbered_groups(uuid,boolean,integer,integer),public.get_cocreate_numbered_group(uuid) to anon;
