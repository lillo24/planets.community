-- C01: curated hubs and General. No native Group/Project grant is reused.
alter table private.cocreate_settings
 add column room_messages_per_minute integer not null default 30 check(room_messages_per_minute between 1 and 120),
 add column max_hub_memberships integer not null default 50 check(max_hub_memberships between 1 and 100);
create table private.cocreate_hubs (
 id uuid primary key default gen_random_uuid(),
 topic_id uuid not null references private.cocreate_topics(id),
 locality text not null check(char_length(btrim(locality)) between 1 and 100 and locality=btrim(locality)),
 active boolean not null default false, suppressed boolean not null default false,
 version bigint not null default 1 check(version>0),
 created_at timestamptz not null default clock_timestamp(),
 unique(topic_id,locality)
);
create index cocreate_hubs_public on private.cocreate_hubs(created_at desc,id desc) where active and not suppressed;
create table private.cocreate_rooms (
 id uuid primary key default gen_random_uuid(),
 hub_id uuid not null references private.cocreate_hubs(id),
 kind text not null default 'general' constraint cocreate_room_kind check(kind='general'),
 archived boolean not null default false, suppressed boolean not null default false,
 last_sequence bigint not null default 0 check(last_sequence>=0),
 version bigint not null default 1 check(version>0),
 created_at timestamptz not null default clock_timestamp()
);
create unique index cocreate_general_per_hub on private.cocreate_rooms(hub_id) where kind='general';
create table private.cocreate_room_episodes (
 id uuid primary key default gen_random_uuid(),room_id uuid not null references private.cocreate_rooms(id),
 actor_id uuid not null,joined_at timestamptz not null default clock_timestamp(),
 ended_at timestamptz,exit_sequence bigint,
 read_sequence bigint not null default 0 check(read_sequence>=0),muted boolean not null default false,
 read_secret uuid not null default gen_random_uuid(),
 check((ended_at is null)=(exit_sequence is null)),check(exit_sequence>=0)
);
create unique index cocreate_room_current_episode on private.cocreate_room_episodes(room_id,actor_id) where ended_at is null;
create index cocreate_room_actor_episodes on private.cocreate_room_episodes(actor_id,joined_at desc,id desc);
create table private.cocreate_hub_exclusions (
 hub_id uuid not null references private.cocreate_hubs(id),actor_id uuid not null,
 active boolean not null default true,primary key(hub_id,actor_id)
);
create table private.cocreate_room_messages (
 id uuid primary key default gen_random_uuid(),room_id uuid not null references private.cocreate_rooms(id),
 sender_id uuid not null,sequence bigint not null check(sequence>0),
 body text not null check(char_length(btrim(body)) between 1 and 2000 and body=btrim(body)),
 created_at timestamptz not null default clock_timestamp(),unique(room_id,sequence)
);
create index cocreate_room_sender_rate on private.cocreate_room_messages(sender_id,created_at desc);
create table private.cocreate_room_receipts (
 actor_id uuid not null,command_id uuid not null,intent_hash text not null,result jsonb not null,
 primary key(actor_id,command_id)
);
create trigger cocreate_room_messages_immutable before update or delete on private.cocreate_room_messages
 for each row execute function private.cocreate_immutable();
create trigger cocreate_room_receipts_immutable before update or delete on private.cocreate_room_receipts
 for each row execute function private.cocreate_immutable();
do $$ declare t text; begin
 foreach t in array array['cocreate_hubs','cocreate_rooms','cocreate_room_episodes','cocreate_hub_exclusions','cocreate_room_messages','cocreate_room_receipts'] loop
  execute format('alter table private.%I enable row level security',t);
  execute format('revoke all on private.%I from public,anon,authenticated,service_role',t);
 end loop;
end; $$;

create function private.cocreate_hub_public(p_hub uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from private.cocreate_hubs h join private.cocreate_topics t on t.id=h.topic_id
  where h.id=p_hub and h.active and not h.suppressed and t.active);
$$;
create function private.cocreate_hub_projection(p_hub uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object('hub_id',h.id,'topic_id',h.topic_id,'topic_label',t.label,
  'locality',h.locality,'created_at',h.created_at)
 from private.cocreate_hubs h join private.cocreate_topics t on t.id=h.topic_id where h.id=p_hub;
$$;
create function public.list_cocreate_hubs(p_search text default '',p_locality text default '',p_topic_id uuid default null,
 p_limit integer default 25,p_before_created_at timestamptz default null,p_before_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 perform private.require_cocreate_enabled();perform private.cocreate_page(p_limit,p_before_created_at,p_before_id);
 if p_search is null or char_length(p_search)>120 or p_locality is null or char_length(p_locality)>100 then
  raise sqlstate '22023' using message='Invalid hub filters.'; end if;
 return (select coalesce(jsonb_agg(private.cocreate_hub_projection(h.id) order by h.created_at desc,h.id desc),'[]'::jsonb)
 from (select h.* from private.cocreate_hubs h join private.cocreate_topics t on t.id=h.topic_id
  where private.cocreate_hub_public(h.id) and (p_topic_id is null or h.topic_id=p_topic_id)
   and (btrim(p_locality)='' or lower(h.locality)=lower(btrim(p_locality)))
   and (btrim(p_search)='' or strpos(lower(t.label||' '||h.locality),lower(btrim(p_search)))>0)
   and (p_before_id is null or (h.created_at,h.id)<(p_before_created_at,p_before_id))
  order by h.created_at desc,h.id desc limit p_limit) h);
end; $$;
create function public.get_cocreate_hub(p_hub_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 perform private.require_cocreate_enabled();
 if private.cocreate_hub_public(p_hub_id) then return private.cocreate_hub_projection(p_hub_id);end if;
 return null;
end; $$;

-- C03 replaces this transaction extension point. The caller holds the hub row
-- lock; child admission/send/exit must acquire that SAME lock before mutation.
create function private.cocreate_cascade_hub_exit(p_hub uuid,p_actor uuid) returns void
language plpgsql security definer set search_path='' as $$ begin
 if p_hub is null or p_actor is null then raise sqlstate '22023' using message='A scoped hub exit is required.';end if;
 return;
end; $$;
create function private.cocreate_lock_hub(p_hub uuid) returns private.cocreate_hubs
language plpgsql security definer set search_path='' as $$
declare hub private.cocreate_hubs;
begin
 select * into hub from private.cocreate_hubs where id=p_hub for update;
 if not found then raise sqlstate '42501' using message='The hub is unavailable.';end if;
 return hub;
end; $$;
create function public.mutate_cocreate_hub(p_expected_profile_id uuid,p_command_id uuid,p_hub_id uuid,
 p_operation text,p_episode_id uuid default null,p_muted boolean default false) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid;hub private.cocreate_hubs;room private.cocreate_rooms;
 episode private.cocreate_room_episodes;prior private.cocreate_room_receipts;intent text;result jsonb;
begin
 actor:=case when p_operation='leave' then private.require_cocreate_identity(p_expected_profile_id)
  else private.require_cocreate_actor(p_expected_profile_id) end;
 if p_operation<>'leave' then
  perform 1 from auth.users where id=actor for share;
  perform 1 from public.profiles where id=actor for share;
  perform private.require_cocreate_actor(actor);
 end if;
 if p_command_id is null or p_hub_id is null or p_operation is null or p_operation not in('join','leave','mute')
  or p_muted is null or (p_operation<>'mute' and p_muted) or (p_operation='join' and p_episode_id is not null)
  or (p_operation<>'join' and p_episode_id is null) then raise sqlstate '22023' using message='Invalid hub command.';end if;
 perform pg_advisory_xact_lock(hashtextextended('cocreate.room.actor:'||actor::text,0));
 hub:=private.cocreate_lock_hub(p_hub_id);
 select * into room from private.cocreate_rooms where hub_id=hub.id and kind='general';
 if not found then raise sqlstate '42501' using message='The hub General is unavailable.';end if;
 intent:=private.group_command_hash(jsonb_build_array('hub',p_hub_id,p_operation,p_episode_id,p_muted));
 select * into prior from private.cocreate_room_receipts where actor_id=actor and command_id=p_command_id;
 if found then
  if prior.intent_hash<>intent then raise sqlstate '22023' using message='The room command intent differs.';end if;
  return prior.result;
 end if;
 if p_operation='join' then
  if not private.cocreate_hub_public(hub.id) or room.archived or room.suppressed
   or exists(select 1 from private.cocreate_hub_exclusions where hub_id=hub.id and actor_id=actor and active) then
    raise sqlstate '42501' using message='Hub admission is unavailable.';end if;
  select * into episode from private.cocreate_room_episodes where room_id=room.id and actor_id=actor and ended_at is null;
  if not found then
   if (select count(*) from private.cocreate_room_episodes e join private.cocreate_rooms r on r.id=e.room_id
     where e.actor_id=actor and e.ended_at is null and r.kind='general')>=(select max_hub_memberships from private.cocreate_settings) then
     raise sqlstate 'PT429' using message='The hub membership limit was reached.';end if;
   insert into private.cocreate_room_episodes(room_id,actor_id,read_sequence)
    values(room.id,actor,room.last_sequence) returning * into episode;
  end if;
 else
  select * into episode from private.cocreate_room_episodes where id=p_episode_id and room_id=room.id and actor_id=actor;
  if not found or episode.ended_at is not null then raise sqlstate 'PT409' using message='Review the current hub membership.';end if;
  if p_operation='leave' then
   update private.cocreate_room_episodes set ended_at=clock_timestamp(),exit_sequence=room.last_sequence where id=episode.id;
   perform private.cocreate_cascade_hub_exit(hub.id,actor);
  else
   if hub.suppressed or room.suppressed then raise sqlstate '42501' using message='The hub is unavailable.';end if;
   update private.cocreate_room_episodes set muted=p_muted where id=episode.id;
  end if;
 end if;
 result:=jsonb_build_object('operation',p_operation,'hub_id',hub.id,'room_id',room.id,'episode_id',episode.id);
 insert into private.cocreate_room_receipts values(actor,p_command_id,intent,result);
 perform private.cocreate_signal(actor);
 return result;
end; $$;

create function private.require_cocreate_room_episode(p_actor uuid,p_room uuid,p_episode uuid,p_sending boolean default false)
returns private.cocreate_room_episodes language plpgsql stable security definer set search_path='' as $$
declare episode private.cocreate_room_episodes;room private.cocreate_rooms;hub private.cocreate_hubs;
begin
 perform private.require_cocreate_actor(p_actor);
 select * into room from private.cocreate_rooms where id=p_room;
 select * into hub from private.cocreate_hubs where id=room.hub_id;
 select * into episode from private.cocreate_room_episodes where id=p_episode and actor_id=p_actor and room_id=p_room;
 if episode.id is null or room.suppressed or hub.suppressed
  or (p_sending and (episode.ended_at is not null or room.archived or not private.cocreate_hub_public(hub.id))) then
  raise sqlstate '42501' using message='The room or membership episode is unavailable.';end if;
 return episode;
end; $$;
create function private.cocreate_room_token(p_room uuid,p_episode private.cocreate_room_episodes,p_sequence bigint) returns text
language sql immutable security invoker set search_path='' as $$
 select p_sequence::text||'.'||encode(extensions.hmac(p_room::text||':'||p_episode.id::text||':'||p_episode.actor_id::text||':'||p_sequence::text,
 p_episode.read_secret::text,'sha256'),'hex');
$$;
create function public.get_cocreate_room_page(p_expected_profile_id uuid,p_room_id uuid,p_episode_id uuid,
 p_limit integer default 30,p_before_sequence bigint default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_cocreate_actor(p_expected_profile_id);
 episode private.cocreate_room_episodes:=private.require_cocreate_room_episode(actor,p_room_id,p_episode_id);
 cap bigint;messages jsonb;
begin
 if p_limit is null or p_limit not between 1 and 50 or p_before_sequence<1 then raise sqlstate '22023' using message='Invalid room page.';end if;
 select coalesce(episode.exit_sequence,r.last_sequence) into cap from private.cocreate_rooms r where r.id=p_room_id;
 select coalesce(jsonb_agg(to_jsonb(m) order by m.sequence desc),'[]'::jsonb) into messages from (
  select id message_id,sender_id,sequence,body,created_at from private.cocreate_room_messages
  where room_id=p_room_id and sequence<=cap and (p_before_sequence is null or sequence<p_before_sequence)
  order by sequence desc limit p_limit) m;
 return jsonb_build_object('profile_id',actor,'room_id',p_room_id,'episode_id',episode.id,
  'closed',episode.ended_at is not null,'messages',messages,'read_token',case when p_before_sequence is null and cap>0
   then private.cocreate_room_token(p_room_id,episode,cap) else null end);
end; $$;
create function public.send_cocreate_room_message(p_expected_profile_id uuid,p_command_id uuid,p_room_id uuid,p_episode_id uuid,p_body text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_cocreate_actor(p_expected_profile_id);room private.cocreate_rooms;
 episode private.cocreate_room_episodes;prior private.cocreate_room_receipts;intent text;message uuid;result jsonb;
begin
 if p_command_id is null or p_body is null or char_length(btrim(p_body)) not between 1 and 2000 then
  raise sqlstate '22023' using message='Invalid room message.';end if;
 perform 1 from auth.users where id=actor for share;
 perform 1 from public.profiles where id=actor for share;
 perform private.require_cocreate_actor(actor);
 perform pg_advisory_xact_lock(hashtextextended('cocreate.room.actor:'||actor::text,0));
 select * into room from private.cocreate_rooms where id=p_room_id;
 perform private.cocreate_lock_hub(room.hub_id);
 episode:=private.require_cocreate_room_episode(actor,p_room_id,p_episode_id,true);
 intent:=private.group_command_hash(jsonb_build_array('send',p_room_id,p_episode_id,p_body));
 select * into prior from private.cocreate_room_receipts where actor_id=actor and command_id=p_command_id;
 if found then
  if prior.intent_hash<>intent then raise sqlstate '22023' using message='The room command intent differs.';end if;
  return prior.result;
 end if;
 if (select count(*) from private.cocreate_room_messages where sender_id=actor and created_at>clock_timestamp()-interval '1 minute')
   >=(select room_messages_per_minute from private.cocreate_settings) then raise sqlstate 'PT429' using message='The room message limit was reached.';end if;
 update private.cocreate_rooms set last_sequence=last_sequence+1 where id=p_room_id returning * into room;
 insert into private.cocreate_room_messages(room_id,sender_id,sequence,body) values(room.id,actor,room.last_sequence,btrim(p_body)) returning id into message;
 result:=jsonb_build_object('room_id',room.id,'episode_id',episode.id,'message_id',message);
 insert into private.cocreate_room_receipts values(actor,p_command_id,intent,result);
 return result;
end; $$;
create function public.acknowledge_cocreate_room(p_expected_profile_id uuid,p_room_id uuid,p_episode_id uuid,p_read_token text) returns void
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_cocreate_actor(p_expected_profile_id);episode private.cocreate_room_episodes;
 room private.cocreate_rooms;sequence bigint;cap bigint;
begin
 perform 1 from auth.users where id=actor for share;
 perform 1 from public.profiles where id=actor for share;
 perform private.require_cocreate_actor(actor);
 select * into room from private.cocreate_rooms where id=p_room_id;
 perform private.cocreate_lock_hub(room.hub_id);
 episode:=private.require_cocreate_room_episode(actor,p_room_id,p_episode_id);
 select * into room from private.cocreate_rooms where id=p_room_id;
 cap:=coalesce(episode.exit_sequence,room.last_sequence);
 if p_read_token is null or p_read_token !~ '^[0-9]{1,18}\.[0-9a-f]{64}$' then raise sqlstate '22023' using message='Invalid rendered room receipt.';end if;
 sequence:=split_part(p_read_token,'.',1)::bigint;
 if sequence<1 or sequence>cap or p_read_token<>private.cocreate_room_token(p_room_id,episode,sequence) then
  raise sqlstate '42501' using message='Invalid rendered room receipt.';end if;
 update private.cocreate_room_episodes set read_sequence=sequence where id=episode.id and read_sequence<sequence;
end; $$;
create function public.get_own_cocreate_hub_membership(p_expected_profile_id uuid,p_hub_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_cocreate_actor(p_expected_profile_id);result jsonb;
begin
 if exists(select 1 from private.cocreate_hubs where id=p_hub_id and suppressed) then raise sqlstate '42501' using message='Hub unavailable.';end if;
 select jsonb_build_object('hub_id',r.hub_id,'room_id',r.id,'episode_id',e.id,'active',e.ended_at is null,'muted',e.muted) into result
 from private.cocreate_rooms r join private.cocreate_room_episodes e on e.room_id=r.id
 where r.hub_id=p_hub_id and r.kind='general' and e.actor_id=actor order by e.joined_at desc,e.id desc limit 1;
 return result;
end; $$;
create function public.list_cocreate_room_people(p_expected_profile_id uuid,p_room_id uuid,p_episode_id uuid,
 p_limit integer default 25,p_after_profile_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_cocreate_actor(p_expected_profile_id);
begin
 perform private.require_cocreate_room_episode(actor,p_room_id,p_episode_id,true);
 if p_limit is null or p_limit not between 1 and 50 then raise sqlstate '22023' using message='Invalid People page.';end if;
 return (select coalesce(jsonb_agg(to_jsonb(p) order by p.profile_id),'[]'::jsonb) from (
  select e.actor_id profile_id,p.display_name from private.cocreate_room_episodes e join public.profiles p on p.id=e.actor_id
  where e.room_id=p_room_id and e.ended_at is null and private.cocreate_account_available(e.actor_id)
   and (p_after_profile_id is null or e.actor_id>p_after_profile_id) order by e.actor_id limit p_limit) p);
end; $$;

create function private.cocreate_create_general() returns trigger
language plpgsql security definer set search_path='' as $$
begin insert into private.cocreate_rooms(hub_id) values(new.id);return null;end; $$;
create trigger cocreate_hub_general after insert on private.cocreate_hubs
 for each row execute function private.cocreate_create_general();
create function private.cocreate_room_unread(p_episode private.cocreate_room_episodes) returns bigint
language sql stable security definer set search_path='' as $$
 select count(*) from private.cocreate_room_messages m join private.cocreate_rooms r on r.id=m.room_id
 where m.room_id=p_episode.room_id and m.sender_id<>p_episode.actor_id and m.sequence>p_episode.read_sequence
  and m.sequence<=coalesce(p_episode.exit_sequence,r.last_sequence);
$$;
create function public.list_own_cocreate_rooms(p_expected_profile_id uuid,p_limit integer default 25,
 p_before_joined_at timestamptz default null,p_before_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_cocreate_actor(p_expected_profile_id);
begin
 perform private.cocreate_page(p_limit,p_before_joined_at,p_before_id);
 return (select coalesce(jsonb_agg(to_jsonb(t) order by t.joined_at desc,t.episode_id desc),'[]'::jsonb) from (
  select r.id room_id,r.hub_id,t.label topic_label,h.locality,e.id episode_id,
   e.ended_at is not null closed,e.muted,e.joined_at,private.cocreate_room_unread(e::private.cocreate_room_episodes) unread_count
  from private.cocreate_rooms r join private.cocreate_hubs h on h.id=r.hub_id
  join private.cocreate_topics t on t.id=h.topic_id
  join lateral(select * from private.cocreate_room_episodes e where e.room_id=r.id and e.actor_id=actor
   order by e.joined_at desc,e.id desc limit 1) e on true
  where not r.suppressed and not h.suppressed
   and (p_before_id is null or (e.joined_at,e.id)<(p_before_joined_at,p_before_id))
  order by e.joined_at desc,e.id desc limit p_limit) t);
end; $$;
create function public.list_own_cocreate_hub_exits(p_expected_profile_id uuid,p_limit integer default 25,
 p_before_joined_at timestamptz default null,p_before_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_cocreate_identity(p_expected_profile_id);
begin
 perform private.cocreate_page(p_limit,p_before_joined_at,p_before_id);
 return (select coalesce(jsonb_agg(to_jsonb(t) order by t.joined_at desc,t.episode_id desc),'[]'::jsonb) from (
  select r.hub_id,e.id episode_id,e.joined_at from private.cocreate_room_episodes e
  join private.cocreate_rooms r on r.id=e.room_id where e.actor_id=actor and e.ended_at is null and r.kind='general'
   and (p_before_id is null or (e.joined_at,e.id)<(p_before_joined_at,p_before_id))
  order by e.joined_at desc,e.id desc limit p_limit) t);
end; $$;
create function private.cocreate_room_change_signal() returns trigger
language plpgsql security definer set search_path='' as $$
declare room uuid;person uuid;
begin
 room:=new.room_id;
 for person in select actor_id from private.cocreate_room_episodes where room_id=room and ended_at is null
 loop perform private.cocreate_signal(person);end loop;
 if tg_table_name='cocreate_room_episodes' then perform private.cocreate_signal(new.actor_id);end if;
 return null;
end; $$;
create trigger cocreate_general_message_signal after insert on private.cocreate_room_messages
 for each row execute function private.cocreate_room_change_signal();
create trigger cocreate_episode_signal after insert or update on private.cocreate_room_episodes
 for each row execute function private.cocreate_room_change_signal();
create function private.cocreate_hub_change_signal() returns trigger
language plpgsql security definer set search_path='' as $$
declare person uuid;
begin
 for person in select distinct e.actor_id from private.cocreate_room_episodes e join private.cocreate_rooms r on r.id=e.room_id
  where r.hub_id=new.id and e.ended_at is null
 loop perform private.cocreate_signal(person);end loop;
 return null;
end; $$;
create trigger cocreate_hub_signal after update on private.cocreate_hubs
 for each row execute function private.cocreate_hub_change_signal();

-- Extend identifier-only access invalidation to C actors, without taking room
-- locks or changing Auth/profile/retention state. Existing exact Auth-trigger
-- assertions continue to reject SQL INSERT/UPDATE/DELETE in these helpers.
create or replace function private.cocreate_access_change_signal() returns trigger
language plpgsql security definer set search_path='' as $$
declare person uuid;
begin
 if tg_table_name='cocreate_settings' then
  for person in select author_id from private.cocreate_posts union select requester_id from private.cocreate_interests
   union select actor_id from private.cocreate_room_episodes
  loop perform private.cocreate_signal(person);end loop;
 else
  if not exists(select 1 from private.cocreate_posts where author_id=new.id)
   and not exists(select 1 from private.cocreate_interests where requester_id=new.id)
   and not exists(select 1 from private.cocreate_contacts where new.id in(author_id,requester_id))
   and not exists(select 1 from private.cocreate_room_episodes where actor_id=new.id) then return null;end if;
  perform private.cocreate_signal(new.id);
  for person in select case when c.author_id=new.id then c.requester_id else c.author_id end
   from private.cocreate_contacts c where new.id in(c.author_id,c.requester_id)
   union select e.actor_id from private.cocreate_room_episodes e where e.ended_at is null and exists(
    select 1 from private.cocreate_room_episodes mine where mine.room_id=e.room_id and mine.actor_id=new.id and mine.ended_at is null)
  loop perform private.cocreate_signal(person);end loop;
 end if;
 return null;
end; $$;
create or replace function private.cocreate_deleted_account_signal() returns trigger
language plpgsql security definer set search_path='' as $$
declare person uuid;
begin
 for person in select case when c.author_id=old.id then c.requester_id else c.author_id end
  from private.cocreate_contacts c where old.id in(c.author_id,c.requester_id)
  union select e.actor_id from private.cocreate_room_episodes e where e.ended_at is null and exists(
   select 1 from private.cocreate_room_episodes mine where mine.room_id=e.room_id and mine.actor_id=old.id and mine.ended_at is null)
 loop perform private.cocreate_signal(person);end loop;
 return null;
end; $$;

create function private.cocreate_unread_room_count(p_actor uuid) returns bigint
language sql stable security definer set search_path='' as $$
 select count(*) from private.cocreate_rooms r join private.cocreate_hubs h on h.id=r.hub_id
 join lateral(select * from private.cocreate_room_episodes e where e.room_id=r.id and e.actor_id=p_actor
  order by e.joined_at desc,e.id desc limit 1)e on true
 where not r.suppressed and not h.suppressed and private.cocreate_room_unread(e::private.cocreate_room_episodes)>0;
$$;
create or replace function public.get_own_message_unread_summary_with_cocreate(p_expected_profile_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id);legacy jsonb;contacts bigint:=0;rooms bigint:=0;
begin
 legacy:=public.get_own_message_unread_summary_with_contacts_and_discussions(actor);
 if exists(select 1 from private.cocreate_settings c join private.policy_acceptances a
   on a.bundle_version=c.policy_bundle_version and a.account_id=actor where c.enabled)
   and private.cocreate_account_available(actor) then
  select count(*) into contacts from private.cocreate_contacts c
  left join private.cocreate_contact_reads r on r.contact_id=c.id and r.actor_id=actor
  where actor in(c.author_id,c.requester_id)
   and private.cocreate_account_available(c.author_id) and private.cocreate_account_available(c.requester_id)
   and not private.has_active_user_block_between(c.author_id,c.requester_id)
   and not exists(select 1 from private.cocreate_posts p where p.id=c.post_id and p.suppressed)
   and exists(select 1 from private.cocreate_contact_messages m where m.contact_id=c.id
    and m.sender_id<>actor and m.sequence>coalesce(r.read_sequence,0));
  rooms:=private.cocreate_unread_room_count(actor);
 end if;
 -- Mute affects delivery preferences, never silently acknowledges human unread.
 return jsonb_build_object('total',(legacy->>'total')::bigint+contacts+rooms,
  'private',(legacy->>'private')::bigint+contacts,'groups',(legacy->>'groups')::bigint+rooms);
end; $$;

alter table private.moderation_cases drop constraint moderation_cases_cocreate_shape,
 add constraint moderation_cases_cocreate_shape check(
  (target_kind in('cocreate_post','cocreate_interest','cocreate_contact_message','cocreate_room_message'))=(target_cocreate_id is not null)
  and (target_cocreate_id is null)=(cocreate_evidence is null));
do $$ declare name text;expression text;begin
 foreach name in array array['moderation_cases_target_kind_valid','moderation_cases_target_shape_valid','moderation_cases_context_shape_valid'] loop
  select pg_get_expr(conbin,conrelid) into expression from pg_constraint where conrelid='private.moderation_cases'::regclass and conname=name;
  if expression is null then raise exception 'Missing moderation predecessor: %',name;end if;
  expression:='('||expression||') or (target_kind=''cocreate_room_message'' and num_nonnulls(project_context_id,resource_listing_context_id,resource_request_context_id,resource_chat_context_id)=0)';
  execute format('alter table private.moderation_cases drop constraint %I, add constraint %I check (%s)',name,name,expression);
 end loop;
end; $$;
create function public.submit_cocreate_room_report(p_expected_reporter_profile_id uuid,p_client_submission_id uuid,
 p_target_id uuid,p_category text,p_explanation text)
returns table(report_id uuid,case_id uuid,state text,created_at timestamptz)
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_moderation_identity(p_expected_reporter_profile_id,true);
 explanation text:=btrim(p_explanation);message private.cocreate_room_messages;room private.cocreate_rooms;
 prior record;evidence jsonb;new_case private.moderation_cases;new_report private.moderation_reports;
begin
 if p_client_submission_id is null or p_target_id is null or p_category is null
  or p_category not in('safety_concern','harassment_abuse','fraud_scam','inappropriate_content_conduct','spam','other')
  or explanation is null or char_length(explanation) not between 10 and 4000 then raise sqlstate '22023' using message='Invalid room report.';end if;
 perform pg_advisory_xact_lock(hashtextextended('moderation.report:'||actor::text||':'||p_client_submission_id::text,0));
 select r.id,r.case_id,c.state,r.created_at,r.category,r.explanation,c.target_kind,c.target_cocreate_id into prior
 from private.moderation_reports r join private.moderation_cases c on c.id=r.case_id
 where r.reporter_profile_id=actor and r.client_submission_id=p_client_submission_id;
 if found then
  if prior.target_kind<>'cocreate_room_message' or prior.target_cocreate_id is distinct from p_target_id
   or prior.category<>p_category or prior.explanation<>explanation then raise sqlstate '22023' using message='The report identity was reused.';end if;
  return query select prior.id,prior.case_id,prior.state,prior.created_at;return;
 end if;
 select * into message from private.cocreate_room_messages where id=p_target_id;
 select * into room from private.cocreate_rooms where id=message.room_id;
 if message.id is null or not exists(select 1 from private.cocreate_room_episodes e
  where e.room_id=room.id and e.actor_id=actor and message.sequence<=coalesce(e.exit_sequence,room.last_sequence)) then
  raise sqlstate '42501' using message='The reported room message is unavailable.';end if;
 if message.sender_id=actor then raise sqlstate '22023' using message='A profile cannot report itself.';end if;
 if not exists(select 1 from public.profiles p join auth.users a on a.id=p.id
  where p.id=message.sender_id and p.display_name is not null and a.deleted_at is null) then
  raise sqlstate '42501' using message='The report target is unavailable.';end if;
 evidence:=jsonb_build_object('message_id',message.id,'room_id',room.id,'hub_id',room.hub_id,
  'sender_id',message.sender_id,'sequence',message.sequence,'body',message.body,'created_at',message.created_at);
 insert into private.moderation_cases(subject_profile_id,target_kind,target_cocreate_id,cocreate_evidence)
  values(message.sender_id,'cocreate_room_message',message.id,evidence) returning * into new_case;
 insert into private.moderation_reports(case_id,reporter_profile_id,client_submission_id,category,explanation,created_at)
  values(new_case.id,actor,p_client_submission_id,p_category,explanation,new_case.created_at) returning * into new_report;
 insert into private.moderation_case_events(case_id,actor_profile_id,event_kind,to_state,state_version,created_at)
  values(new_case.id,actor,'report_received','received',0,new_case.created_at);
 insert into private.audit_events(action,target_type,target_id,metadata) values('moderation.report_submitted','moderation_case',new_case.id,
  jsonb_build_object('actor_id',actor,'report_id',new_report.id,'target_kind','cocreate_room_message'));
 return query select new_report.id,new_case.id,new_case.state,new_report.created_at;
end; $$;
create function public.get_moderation_case_cocreate_room(p_expected_staff_profile_id uuid,p_case_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare evidence jsonb;hub private.cocreate_hubs;room private.cocreate_rooms;
begin
 perform private.require_moderation_staff(p_expected_staff_profile_id);
 select cocreate_evidence into evidence from private.moderation_cases where id=p_case_id and target_kind='cocreate_room_message';
 if evidence is null then raise sqlstate '42501' using message='The room report evidence is unavailable.';end if;
 select * into hub from private.cocreate_hubs where id=(evidence->>'hub_id')::uuid;
 select * into room from private.cocreate_rooms where id=(evidence->>'room_id')::uuid;
 return jsonb_build_object('evidence',evidence,'hub_version',hub.version,'hub_suppressed',hub.suppressed,
  'room_version',room.version,'room_suppressed',room.suppressed);
end; $$;
create function public.moderate_cocreate_hub(p_expected_staff_profile_id uuid,p_command_id uuid,p_case_id uuid,
 p_expected_version bigint,p_operation text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=p_expected_staff_profile_id;hub private.cocreate_hubs;room private.cocreate_rooms;
 evidence jsonb;subject uuid;prior private.cocreate_room_receipts;intent text;result jsonb;person uuid;
begin
 perform private.require_moderation_staff(actor);
 if p_command_id is null or p_case_id is null or p_expected_version is null or p_operation is null
  or p_operation not in('suppress','restore','remove_sender','allow_sender','archive') then raise sqlstate '22023' using message='Invalid hub moderation command.';end if;
 perform pg_advisory_xact_lock(hashtextextended('cocreate.room.actor:'||actor::text,0));
 perform private.require_moderation_staff(actor);
 select cocreate_evidence into evidence from private.moderation_cases where id=p_case_id and target_kind='cocreate_room_message';
 if evidence is null then raise sqlstate '42501' using message='The room report evidence is unavailable.';end if;
 select * into room from private.cocreate_rooms where id=(evidence->>'room_id')::uuid and kind='general';
 if not found then raise sqlstate '42501' using message='The scoped General is unavailable.';end if;
 hub:=private.cocreate_lock_hub(room.hub_id);subject:=(evidence->>'sender_id')::uuid;
 intent:=private.group_command_hash(jsonb_build_array('hub moderation',p_case_id,p_expected_version,p_operation));
 select * into prior from private.cocreate_room_receipts where actor_id=actor and command_id=p_command_id;
 if found then
  if prior.intent_hash<>intent then raise sqlstate '22023' using message='The room command intent differs.';end if;
  return prior.result;
 end if;
 if hub.version<>p_expected_version then raise sqlstate 'PT409' using message='The hub changed.';end if;
 if p_operation in('suppress','restore') then
  update private.cocreate_hubs set suppressed=p_operation='suppress' where id=hub.id;
 elsif p_operation='remove_sender' then
  update private.cocreate_room_episodes set ended_at=clock_timestamp(),exit_sequence=room.last_sequence
   where room_id=room.id and actor_id=subject and ended_at is null;
  perform private.cocreate_cascade_hub_exit(hub.id,subject);
  insert into private.cocreate_hub_exclusions values(hub.id,subject,true)
   on conflict(hub_id,actor_id) do update set active=true;
 elsif p_operation='allow_sender' then
  update private.cocreate_hub_exclusions set active=false where hub_id=hub.id and actor_id=subject;
 else
  update private.cocreate_hubs set active=false where id=hub.id;
  for person in select actor_id from private.cocreate_room_episodes where room_id=room.id and ended_at is null order by actor_id loop
   update private.cocreate_room_episodes set ended_at=clock_timestamp(),exit_sequence=room.last_sequence
    where room_id=room.id and actor_id=person and ended_at is null;
   perform private.cocreate_cascade_hub_exit(hub.id,person);
  end loop;
  update private.cocreate_rooms set archived=true where id=room.id;
 end if;
 update private.cocreate_hubs set version=version+1 where id=hub.id returning * into hub;
 result:=jsonb_build_object('hub_id',hub.id,'version',hub.version,'operation',p_operation);
 insert into private.cocreate_room_receipts values(actor,p_command_id,intent,result);
 insert into private.audit_events(action,target_type,target_id,metadata) values('cocreate.hub.moderated','cocreate_hub',hub.id,
  jsonb_build_object('actor_id',actor,'case_id',p_case_id,'version',hub.version,'operation',p_operation));
 perform private.cocreate_signal(subject);
 return result;
end; $$;

do $$ declare fn regprocedure;begin
 for fn in select p.oid::regprocedure from pg_proc p where p.pronamespace='private'::regnamespace and p.proname like '%cocreate%'
 loop execute format('revoke all on function %s from public,anon,authenticated,service_role',fn);end loop;
 for fn in select p.oid::regprocedure from pg_proc p where p.pronamespace='public'::regnamespace and p.proname in(
  'list_cocreate_hubs','get_cocreate_hub','mutate_cocreate_hub','get_cocreate_room_page','send_cocreate_room_message',
  'acknowledge_cocreate_room','get_own_cocreate_hub_membership','list_cocreate_room_people','list_own_cocreate_rooms',
  'list_own_cocreate_hub_exits','submit_cocreate_room_report','get_moderation_case_cocreate_room','moderate_cocreate_hub') loop
  execute format('revoke all on function %s from public,anon,authenticated,service_role',fn);
  execute format('grant execute on function %s to authenticated',fn);
 end loop;
end; $$;
grant execute on function public.list_cocreate_hubs(text,text,uuid,integer,timestamptz,uuid),public.get_cocreate_hub(uuid) to anon;
