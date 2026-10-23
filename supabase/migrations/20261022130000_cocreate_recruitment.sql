-- D01: immutable structured General messages; mutable recruitment lifecycle is
-- separate. Default expiry 7 days is experimental, not a retention promise.
alter table private.cocreate_settings add column recruitment_lifetime_days integer not null default 7
 check(recruitment_lifetime_days between 1 and 30);
create table private.cocreate_recruitments (
 id uuid primary key default gen_random_uuid(), room_id uuid not null references private.cocreate_rooms(id),
 general_room_id uuid not null references private.cocreate_rooms(id),message_id uuid not null unique references private.cocreate_room_messages(id) deferrable initially deferred,
 creator_id uuid not null,created_at timestamptz not null default clock_timestamp(),
 expires_at timestamptz not null,retracted_at timestamptz,check(expires_at>created_at)
);
create unique index cocreate_one_active_recruitment on private.cocreate_recruitments(room_id) where retracted_at is null;
create index cocreate_recruitment_history on private.cocreate_recruitments(room_id,created_at desc,id desc);
alter table private.cocreate_recruitments enable row level security;
revoke all on private.cocreate_recruitments from public,anon,authenticated,service_role;
alter table private.cocreate_room_messages
 add column kind text not null default 'human' check(kind in('human','recruitment')),
 add column recruitment_id uuid references private.cocreate_recruitments(id) deferrable initially deferred,
 add constraint cocreate_message_structure check((kind='human')=(recruitment_id is null));

create function private.cocreate_recruitment_projection(p_id uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object('recruitment_id',c.id,'hub_id',r.hub_id,'room_id',r.id,'number',r.group_number,
  'capacity',case when private.cocreate_numbered_public(r.id) then r.capacity end,
  'occupied',case when private.cocreate_numbered_public(r.id) then private.cocreate_numbered_occupied(r.id) end,
  'available',c.retracted_at is null and c.expires_at>statement_timestamp() and private.cocreate_numbered_public(r.id)
   and private.cocreate_numbered_occupied(r.id)<r.capacity,
  'state',case when c.expires_at<=statement_timestamp() then 'expired' when c.retracted_at is not null then 'retracted'
   when not private.cocreate_numbered_public(r.id) then 'unavailable'
   when private.cocreate_numbered_occupied(r.id)>=r.capacity then 'full' else 'open' end,
  'expires_at',c.expires_at)
 from private.cocreate_recruitments c join private.cocreate_rooms r on r.id=c.room_id where c.id=p_id;
$$;
create function private.cocreate_recruitment_signal(p_room uuid) returns void
language plpgsql security definer set search_path='' as $$
declare person uuid;
begin
 for person in select distinct e.actor_id from private.cocreate_room_episodes e
  join private.cocreate_recruitments c on c.general_room_id=e.room_id
  where c.room_id=p_room and e.ended_at is null
 loop perform private.cocreate_signal(person);end loop;
end; $$;
create function private.cocreate_recruitment_change_signal() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if tg_table_name='cocreate_rooms' then perform private.cocreate_recruitment_signal(new.id);
 else perform private.cocreate_recruitment_signal(new.room_id);end if;
 return null;
end; $$;
create trigger cocreate_recruitment_signal after insert or update on private.cocreate_recruitments
 for each row execute function private.cocreate_recruitment_change_signal();
create trigger cocreate_recruitment_capacity_signal after update of capacity,archived,suppressed on private.cocreate_rooms
 for each row execute function private.cocreate_recruitment_change_signal();
create trigger cocreate_recruitment_seat_signal after insert or update of ended_at on private.cocreate_room_episodes
 for each row execute function private.cocreate_recruitment_change_signal();
create function public.mutate_cocreate_recruitment(p_expected_profile_id uuid,p_command_id uuid,p_hub_id uuid,
 p_room_id uuid,p_operation text,p_episode_id uuid default null,p_recruitment_id uuid default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid;room private.cocreate_rooms;general private.cocreate_rooms;entry private.cocreate_recruitments;
 prior private.cocreate_room_receipts;intent text;result jsonb;recruitment uuid:=gen_random_uuid();message uuid:=gen_random_uuid();
begin
 actor:=case when p_operation='retract' then private.require_cocreate_identity(p_expected_profile_id)
  else private.require_cocreate_actor(p_expected_profile_id) end;
 if p_command_id is null or p_hub_id is null or p_room_id is null or p_operation is null
  or p_operation not in('post','retract') or (p_operation='post')<>(p_episode_id is not null)
  or (p_operation='retract')<>(p_recruitment_id is not null)
 then raise sqlstate '22023' using message='Invalid recruitment command.';end if;
 perform 1 from auth.users where id=actor for share;
 perform 1 from public.profiles where id=actor for share;
 if p_operation='post' then perform private.require_cocreate_actor(actor);end if;
 perform pg_advisory_xact_lock(hashtextextended('cocreate.room.actor:'||actor::text,0));
 perform private.cocreate_lock_hub(p_hub_id);
 select * into room from private.cocreate_rooms where id=p_room_id and hub_id=p_hub_id and kind='numbered' and manager_id=actor;
 if not found then raise sqlstate '42501' using message='Only the numbered group creator manages recruitment.';end if;
 intent:=private.group_command_hash(jsonb_build_array('recruitment',p_hub_id,p_room_id,p_operation,p_episode_id,p_recruitment_id));
 select * into prior from private.cocreate_room_receipts where actor_id=actor and command_id=p_command_id;
 if found then
  if prior.intent_hash<>intent then raise sqlstate '22023' using message='The recruitment command intent differs.';end if;
  return prior.result;
 end if;
 if p_operation='post' then
  perform private.require_cocreate_room_episode(actor,room.id,p_episode_id,true);
  if not private.cocreate_numbered_public(room.id) or private.cocreate_numbered_occupied(room.id)>=room.capacity
   then raise sqlstate 'PT409' using message='Only an available current group can recruit.';end if;
  if exists(select 1 from private.cocreate_recruitments where room_id=room.id and retracted_at is null and expires_at>statement_timestamp())
   then raise sqlstate 'PT409' using message='This group already has active recruitment.';end if;
  if exists(select 1 from private.cocreate_recruitments where room_id=room.id and created_at>clock_timestamp()-make_interval(secs=>(select recruitment_cooldown_seconds from private.cocreate_settings)))
   then raise sqlstate 'PT429' using message='Review the recruitment cooldown before posting again.';end if;
  update private.cocreate_recruitments set retracted_at=clock_timestamp() where room_id=room.id and retracted_at is null;
  select * into general from private.cocreate_rooms where hub_id=p_hub_id and kind='general';
  update private.cocreate_rooms set last_sequence=last_sequence+1 where id=general.id returning * into general;
  -- Deferred FK insertion creates the immutable message and reference atomically.
  insert into private.cocreate_room_messages(id,room_id,sender_id,sequence,body,kind,recruitment_id)
   values(message,general.id,actor,general.last_sequence,'Group '||room.group_number||' recruitment','recruitment',recruitment);
  insert into private.cocreate_recruitments(id,room_id,general_room_id,message_id,creator_id,expires_at)
   values(recruitment,room.id,general.id,message,actor,clock_timestamp()+make_interval(days=>(select recruitment_lifetime_days from private.cocreate_settings))) returning * into entry;
  -- The message is immutable even to this function; the circular reference is
  -- populated at INSERT via deferred constraints, never by rewriting its body.
 else
  update private.cocreate_recruitments set retracted_at=clock_timestamp()
   where id=p_recruitment_id and room_id=room.id and creator_id=actor and retracted_at is null returning * into entry;
  if not found then raise sqlstate 'PT409' using message='There is no current recruitment to retract.';end if;
  message:=entry.message_id;recruitment:=entry.id;
 end if;
 result:=jsonb_build_object('operation',p_operation,'hub_id',p_hub_id,'room_id',room.id,'message_id',message,'recruitment_id',recruitment);
 insert into private.cocreate_room_receipts values(actor,p_command_id,intent,result);
 return result;
end; $$;

-- Preserve ordinary human evidence exactly. Structured evidence adds only the
-- exact reported card snapshot; staff still receives no transcript grant.
do $$ declare source text:=pg_get_functiondef('public.submit_cocreate_room_report(uuid,uuid,uuid,text,text)'::regprocedure);
 needle text:='''sender_id'',message.sender_id,''sequence'',message.sequence,''body'',message.body,''created_at'',message.created_at);';
begin
 if strpos(source,needle)=0 then raise exception 'Unknown room report predecessor.';end if;
 source:=replace(source,needle,needle||' if message.kind=''recruitment'' then evidence:=evidence||jsonb_build_object(''kind'',''recruitment'',''recruitment'',private.cocreate_recruitment_projection(message.recruitment_id));end if;');
 execute source;
end; $$;

-- Join uses the canonical C03 transaction. The outer command binds the card ID
-- as well, so neither an expired card nor changed-card retry can create a grant.
create function public.join_cocreate_recruitment(p_expected_profile_id uuid,p_command_id uuid,p_hub_id uuid,p_room_id uuid,p_recruitment_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_cocreate_actor(p_expected_profile_id);manager uuid;
 prior private.cocreate_room_receipts;intent text;result jsonb;
begin
 if p_command_id is null or p_hub_id is null or p_room_id is null or p_recruitment_id is null then
  raise sqlstate '22023' using message='Invalid recruitment admission.';end if;
 select manager_id into manager from private.cocreate_rooms where id=p_room_id and hub_id=p_hub_id and kind='numbered';
 if manager is null then raise sqlstate '42501' using message='The recruitment destination is unavailable.';end if;
 -- Same sorted Auth/profile -> actor -> blocked pair -> hub order as C03.
 perform 1 from auth.users where id in(actor,manager) order by id for share;
 perform 1 from public.profiles where id in(actor,manager) order by id for share;
 perform private.require_cocreate_actor(actor);
 perform pg_advisory_xact_lock(hashtextextended('cocreate.room.actor:'||actor::text,0));
 if actor<>manager then perform private.lock_user_interaction_pair(actor,manager);end if;
 perform private.cocreate_lock_hub(p_hub_id);
 intent:=private.group_command_hash(jsonb_build_array('recruitment_join',p_hub_id,p_room_id,p_recruitment_id));
 select * into prior from private.cocreate_room_receipts where actor_id=actor and command_id=p_command_id;
 if found then
  if prior.intent_hash<>intent then raise sqlstate '22023' using message='The recruitment admission intent differs.';end if;
  return prior.result;
 end if;
 if not exists(select 1 from private.cocreate_recruitments where id=p_recruitment_id and room_id=p_room_id and retracted_at is null and expires_at>statement_timestamp())
 then raise sqlstate 'PT409' using message='This recruitment is no longer actionable.';end if;
 result:=public.mutate_cocreate_numbered_group(actor,gen_random_uuid(),p_hub_id,'join',p_room_id);
 insert into private.cocreate_room_receipts values(actor,p_command_id,intent,result);
 return result;
end; $$;

create function public.get_own_cocreate_recruitment(p_expected_profile_id uuid,p_room_id uuid,p_episode_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_cocreate_actor(p_expected_profile_id);result jsonb;
begin
 perform private.require_cocreate_room_episode(actor,p_room_id,p_episode_id,true);
 if not exists(select 1 from private.cocreate_rooms where id=p_room_id and manager_id=actor and kind='numbered') then
  raise sqlstate '42501' using message='Only this current numbered creator can review recruitment.';end if;
 select private.cocreate_recruitment_projection(c.id) into result from private.cocreate_recruitments c
  where c.room_id=p_room_id order by c.created_at desc,c.id desc limit 1;
 return result;
end; $$;

create function public.get_cocreate_recruitment(p_expected_profile_id uuid,p_general_room_id uuid,p_episode_id uuid,p_recruitment_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_cocreate_actor(p_expected_profile_id);
 episode private.cocreate_room_episodes:=private.require_cocreate_room_episode(actor,p_general_room_id,p_episode_id);
 result jsonb;
begin
 select private.cocreate_recruitment_projection(c.id) into result from private.cocreate_recruitments c
  join private.cocreate_room_messages m on m.id=c.message_id join private.cocreate_rooms r on r.id=m.room_id
  where c.id=p_recruitment_id and c.general_room_id=p_general_room_id
   and m.sequence<=coalesce(episode.exit_sequence,r.last_sequence);
 if result is null then raise sqlstate '42501' using message='This recruitment is outside the admitted history.';end if;
 return result;
end; $$;

create function public.get_cocreate_room_page_v2(p_expected_profile_id uuid,p_room_id uuid,p_episode_id uuid,
 p_limit integer default 30,p_before_sequence bigint default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_cocreate_actor(p_expected_profile_id);
 episode private.cocreate_room_episodes:=private.require_cocreate_room_episode(actor,p_room_id,p_episode_id);
 cap bigint;messages jsonb;
begin
 if p_limit is null or p_limit not between 1 and 50 or p_before_sequence<1 then raise sqlstate '22023' using message='Invalid room page.';end if;
 select coalesce(episode.exit_sequence,r.last_sequence) into cap from private.cocreate_rooms r where r.id=p_room_id;
 select coalesce(jsonb_agg(to_jsonb(m) order by m.sequence desc),'[]'::jsonb) into messages from (
  select m.id message_id,m.sender_id,m.sequence,m.body,m.created_at,m.kind,
   case when private.cocreate_account_available(m.sender_id) then p.display_name end sender_name,
   case when m.kind='recruitment' then private.cocreate_recruitment_projection(m.recruitment_id) end recruitment
  from private.cocreate_room_messages m left join public.profiles p on p.id=m.sender_id
  where m.room_id=p_room_id and m.sequence<=cap and (p_before_sequence is null or m.sequence<p_before_sequence)
  order by m.sequence desc limit p_limit)m;
 return jsonb_build_object('profile_id',actor,'room_id',p_room_id,'episode_id',episode.id,
  'closed',episode.ended_at is not null,'messages',messages,'read_token',case when p_before_sequence is null and cap>0
   then private.cocreate_room_token(p_room_id,episode,cap) else null end);
end; $$;

create or replace function private.cocreate_room_unread(p_episode private.cocreate_room_episodes) returns bigint
language sql stable security definer set search_path='' as $$
 select count(*) from private.cocreate_room_messages m join private.cocreate_rooms r on r.id=m.room_id
 where m.room_id=p_episode.room_id and m.kind='human' and m.sender_id<>p_episode.actor_id and m.sequence>p_episode.read_sequence
  and m.sequence<=coalesce(p_episode.exit_sequence,r.last_sequence);
$$;
-- Preserve the installed human-only reader and its exact newest-human frontier.
do $$ declare source text:=pg_get_functiondef('public.get_cocreate_room_page(uuid,uuid,uuid,integer,bigint)'::regprocedure);begin
 if strpos(source,'select coalesce(episode.exit_sequence,r.last_sequence) into cap')=0
  or strpos(source,'where room_id=p_room_id and sequence<=cap')=0 then raise exception 'Unknown human room reader predecessor.';end if;
 source:=replace(source,'where room_id=p_room_id and sequence<=cap','where kind=''human'' and room_id=p_room_id and sequence<=cap');
 source:=replace(source,'select coalesce(episode.exit_sequence,r.last_sequence) into cap from private.cocreate_rooms r where r.id=p_room_id;',
  'select coalesce(max(m.sequence),0) into cap from private.cocreate_room_messages m join private.cocreate_rooms r on r.id=m.room_id where m.room_id=p_room_id and m.kind=''human'' and m.sequence<=coalesce(episode.exit_sequence,r.last_sequence);');
 execute source;
end; $$;

do $$ declare signature text;begin
 foreach signature in array array[
  'public.mutate_cocreate_recruitment(uuid,uuid,uuid,uuid,text,uuid,uuid)',
  'public.join_cocreate_recruitment(uuid,uuid,uuid,uuid,uuid)',
  'public.get_own_cocreate_recruitment(uuid,uuid,uuid)',
  'public.get_cocreate_recruitment(uuid,uuid,uuid,uuid)',
  'public.get_cocreate_room_page_v2(uuid,uuid,uuid,integer,bigint)'] loop
  execute 'revoke all on function '||signature||' from public,anon,authenticated';
  execute 'grant execute on function '||signature||' to authenticated';
 end loop;
end; $$;
revoke all on function private.cocreate_recruitment_projection(uuid),private.cocreate_recruitment_signal(uuid),
 private.cocreate_recruitment_change_signal() from public,anon,authenticated,service_role;
