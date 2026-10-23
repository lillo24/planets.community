-- FILL01: a meeting reserves places independently of persistent chat membership.
-- All admission/attendance/card changes hold the existing canonical hub lock.
create table private.cocreate_meetings (
 id uuid primary key default gen_random_uuid(),
 room_id uuid not null references private.cocreate_rooms(id),
 creator_id uuid not null,
 starts_at timestamptz not null,
 capacity integer not null check(capacity between 2 and 50),
 created_at timestamptz not null default clock_timestamp(),
 cancelled_at timestamptz,
 check(starts_at>created_at)
);
create index cocreate_meetings_room on private.cocreate_meetings(room_id,created_at desc,id desc);
create table private.cocreate_meeting_attendance (
 meeting_id uuid not null references private.cocreate_meetings(id),
 actor_id uuid not null, episode_id uuid not null references private.cocreate_room_episodes(id),
 attending boolean not null default true,
 primary key(meeting_id,actor_id)
);
create index cocreate_meeting_attendance_episode on private.cocreate_meeting_attendance(episode_id);
alter table private.cocreate_recruitments add column meeting_id uuid references private.cocreate_meetings(id);
create index cocreate_recruitment_meeting on private.cocreate_recruitments(meeting_id);
alter table private.cocreate_meetings enable row level security;
alter table private.cocreate_meeting_attendance enable row level security;
revoke all on private.cocreate_meetings,private.cocreate_meeting_attendance from public,anon,authenticated,service_role;

create function private.cocreate_meeting_occupied(p_meeting uuid) returns integer
language sql stable security definer set search_path='' as $$
 select count(*)::integer from private.cocreate_meeting_attendance a
 join private.cocreate_room_episodes e on e.id=a.episode_id
 where a.meeting_id=p_meeting and a.attending and e.ended_at is null;
$$;

-- Preserve the exact legacy card shape. Only scheduled cards add meeting fields.
alter function private.cocreate_recruitment_projection(uuid) rename to cocreate_recruitment_before_meetings;
create function private.cocreate_recruitment_projection(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare c private.cocreate_recruitments; m private.cocreate_meetings; r private.cocreate_rooms;
 occupied integer; state text; visible boolean;
begin
 select * into c from private.cocreate_recruitments where id=p_id;
 if c.meeting_id is null then return private.cocreate_recruitment_before_meetings(p_id);end if;
 select * into m from private.cocreate_meetings where id=c.meeting_id;
 select * into r from private.cocreate_rooms where id=c.room_id;
 occupied:=private.cocreate_meeting_occupied(m.id);
 visible:=private.cocreate_numbered_public(r.id);
 state:=case when m.cancelled_at is not null or c.retracted_at is not null then 'retracted'
  when m.starts_at<=statement_timestamp() or c.expires_at<=statement_timestamp() then 'expired'
  when not visible then 'unavailable'
  when occupied>=m.capacity then 'full' else 'open' end;
 return jsonb_build_object('recruitment_id',c.id,'hub_id',r.hub_id,'room_id',r.id,'number',r.group_number,
  'capacity',case when visible then m.capacity end,'occupied',case when visible then occupied end,
  'available',state='open','state',state,'expires_at',c.expires_at,
  'meeting_id',m.id,'starts_at',m.starts_at);
end; $$;

create function private.cocreate_publish_meeting(p_actor uuid,p_meeting uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare m private.cocreate_meetings; r private.cocreate_rooms; general private.cocreate_rooms;
 card uuid:=gen_random_uuid(); message uuid:=gen_random_uuid();
begin
 select * into m from private.cocreate_meetings where id=p_meeting;
 select * into r from private.cocreate_rooms where id=m.room_id;
 if r.manager_id<>p_actor or not private.cocreate_numbered_public(r.id)
  or m.cancelled_at is not null or m.starts_at<=clock_timestamp()
  or private.cocreate_meeting_occupied(m.id)>=m.capacity then
  raise sqlstate 'PT409' using message='This meeting cannot request more people.';end if;
 if exists(select 1 from private.cocreate_recruitments where room_id=r.id
  and created_at>clock_timestamp()-make_interval(secs=>(select recruitment_cooldown_seconds from private.cocreate_settings))) then
  raise sqlstate 'PT429' using message='Review the recruitment cooldown before posting again.';end if;
 update private.cocreate_recruitments set retracted_at=clock_timestamp() where room_id=r.id and retracted_at is null;
 select * into general from private.cocreate_rooms where hub_id=r.hub_id and kind='general';
 update private.cocreate_rooms set last_sequence=last_sequence+1 where id=general.id returning * into general;
 insert into private.cocreate_room_messages(id,room_id,sender_id,sequence,body,kind,recruitment_id)
  values(message,general.id,p_actor,general.last_sequence,'Group '||r.group_number||' meeting recruitment','recruitment',card);
 insert into private.cocreate_recruitments(id,room_id,general_room_id,message_id,creator_id,expires_at,meeting_id)
  values(card,r.id,general.id,message,p_actor,least(m.starts_at,clock_timestamp()+make_interval(days=>(select recruitment_lifetime_days from private.cocreate_settings))),m.id);
 return jsonb_build_object('meeting_id',m.id,'recruitment_id',card,'message_id',message);
end; $$;

create function public.schedule_cocreate_meeting(p_expected_profile_id uuid,p_command_id uuid,p_hub_id uuid,
 p_starts_at timestamptz,p_capacity integer,p_room_id uuid default null,p_episode_id uuid default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_cocreate_actor(p_expected_profile_id); r private.cocreate_rooms;
 prior private.cocreate_room_receipts; intent text; result jsonb; member jsonb; meeting uuid:=gen_random_uuid(); episode uuid;
begin
 if p_command_id is null or p_hub_id is null or p_starts_at is null or not isfinite(p_starts_at)
  or p_capacity is null or p_capacity not between 2 and 50 or (p_room_id is null)<>(p_episode_id is null) then
  raise sqlstate '22023' using message='A meeting time, capacity and exact optional group episode are required.';end if;
 perform 1 from auth.users where id=actor for share;
 perform 1 from public.profiles where id=actor for share;
 perform private.require_cocreate_actor(actor);
 perform pg_advisory_xact_lock(hashtextextended('cocreate.room.actor:'||actor::text,0));
 perform private.cocreate_lock_hub(p_hub_id);
 intent:=private.group_command_hash(jsonb_build_array('schedule_meeting',p_hub_id,p_starts_at,p_capacity,p_room_id,p_episode_id));
 select * into prior from private.cocreate_room_receipts where actor_id=actor and command_id=p_command_id;
 if found then
  if prior.intent_hash<>intent then raise sqlstate '22023' using message='The meeting command intent differs.';end if;
  return prior.result;
 end if;
 if p_starts_at<=clock_timestamp() or p_starts_at>clock_timestamp()+interval '366 days' then
  raise sqlstate '22023' using message='Meeting time must be in the next 366 days.';end if;
 if p_room_id is null then
  member:=public.mutate_cocreate_numbered_group(actor,gen_random_uuid(),p_hub_id,'create',p_capacity=>50);
  select * into r from private.cocreate_rooms where id=(member->>'room_id')::uuid;
  episode:=(member->>'episode_id')::uuid;
 else
  perform private.require_cocreate_room_episode(actor,p_room_id,p_episode_id,true);
  select * into r from private.cocreate_rooms where id=p_room_id and hub_id=p_hub_id and manager_id=actor and kind='numbered';
  if not found then raise sqlstate '42501' using message='Only this group creator can schedule its next meeting.';end if;
  if exists(select 1 from private.cocreate_meetings where room_id=r.id and cancelled_at is null and starts_at>clock_timestamp()) then
   raise sqlstate 'PT409' using message='Review or cancel the current meeting before scheduling another.';end if;
  -- Explicit scheduling UI discloses a persistent chat, distinct from meeting places.
  update private.cocreate_rooms set capacity=50,version=version+1 where id=r.id and capacity<>50;
  episode:=p_episode_id;
 end if;
 insert into private.cocreate_meetings(id,room_id,creator_id,starts_at,capacity) values(meeting,r.id,actor,p_starts_at,p_capacity);
 insert into private.cocreate_meeting_attendance(meeting_id,actor_id,episode_id) values(meeting,actor,episode);
 result:=private.cocreate_publish_meeting(actor,meeting)||jsonb_build_object('operation','schedule','hub_id',p_hub_id,'room_id',r.id,'episode_id',episode);
 insert into private.cocreate_room_receipts values(actor,p_command_id,intent,result);
 perform private.cocreate_signal(actor);
 return result;
end; $$;

-- Canonical C03 chat admission and the meeting place commit or roll back together.
-- The outer existing join wrapper already owns sorted identities, pair and hub locks.
create function private.cocreate_join_meeting(p_actor uuid,p_hub uuid,p_room uuid,p_card uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare m private.cocreate_meetings; result jsonb;
begin
 select meeting.* into m from private.cocreate_meetings meeting join private.cocreate_recruitments c on c.meeting_id=meeting.id
  where c.id=p_card and c.room_id=p_room and c.retracted_at is null and c.expires_at>clock_timestamp();
 if m.id is null or m.cancelled_at is not null or m.starts_at<=clock_timestamp() then
  raise sqlstate 'PT409' using message='This meeting is no longer accepting people.';end if;
 if not exists(select 1 from private.cocreate_meeting_attendance a join private.cocreate_room_episodes e on e.id=a.episode_id
  where a.meeting_id=m.id and a.actor_id=p_actor and a.attending and e.ended_at is null)
  and private.cocreate_meeting_occupied(m.id)>=m.capacity then
  raise sqlstate 'PT409' using message='The meeting is full.';end if;
 result:=public.mutate_cocreate_numbered_group(p_actor,gen_random_uuid(),p_hub,'join',p_room);
 insert into private.cocreate_meeting_attendance(meeting_id,actor_id,episode_id,attending)
  values(m.id,p_actor,(result->>'episode_id')::uuid,true)
  on conflict(meeting_id,actor_id) do update set episode_id=excluded.episode_id,attending=true;
 perform private.cocreate_recruitment_signal(p_room);
 return result;
end; $$;
do $$ declare source text:=pg_get_functiondef('public.join_cocreate_recruitment(uuid,uuid,uuid,uuid,uuid)'::regprocedure);
 needle text:='result:=public.mutate_cocreate_numbered_group(actor,gen_random_uuid(),p_hub_id,''join'',p_room_id);';
begin
 if strpos(source,needle)=0 then raise exception 'Unknown recruitment admission predecessor.';end if;
 execute replace(source,needle,'if exists(select 1 from private.cocreate_recruitments where id=p_recruitment_id and meeting_id is not null) then result:=private.cocreate_join_meeting(actor,p_hub_id,p_room_id,p_recruitment_id);else '||needle||'end if;');
end; $$;

create function public.mutate_cocreate_meeting(p_expected_profile_id uuid,p_command_id uuid,p_hub_id uuid,
 p_room_id uuid,p_episode_id uuid,p_meeting_id uuid,p_operation text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid; m private.cocreate_meetings; r private.cocreate_rooms;
 prior private.cocreate_room_receipts; intent text; result jsonb;
begin
 actor:=case when p_operation in('decline','cancel') then private.require_cocreate_identity(p_expected_profile_id)
  else private.require_cocreate_actor(p_expected_profile_id) end;
 if num_nulls(p_command_id,p_hub_id,p_room_id,p_episode_id,p_meeting_id,p_operation)>0 or p_operation not in('attend','decline','cancel','repost') then
  raise sqlstate '22023' using message='Invalid scoped meeting command.';end if;
 -- Exact own withdrawal/cancellation remains possible with gate OFF/outdated policy.
 perform 1 from auth.users where id=actor for share;
 perform 1 from public.profiles where id=actor for share;
 perform pg_advisory_xact_lock(hashtextextended('cocreate.room.actor:'||actor::text,0));
 perform private.cocreate_lock_hub(p_hub_id);
 intent:=private.group_command_hash(jsonb_build_array('meeting',p_hub_id,p_room_id,p_episode_id,p_meeting_id,p_operation));
 select * into prior from private.cocreate_room_receipts where actor_id=actor and command_id=p_command_id;
 if found then
  if prior.intent_hash<>intent then raise sqlstate '22023' using message='The meeting command intent differs.';end if;
  return prior.result;
 end if;
 select * into r from private.cocreate_rooms where id=p_room_id and hub_id=p_hub_id and kind='numbered';
 select * into m from private.cocreate_meetings where id=p_meeting_id and room_id=r.id;
 if m.id is null or not exists(select 1 from private.cocreate_room_episodes where id=p_episode_id and room_id=r.id and actor_id=actor) then
  raise sqlstate '42501' using message='The meeting membership is unavailable.';end if;
 if p_operation in('cancel','repost') and r.manager_id<>actor then raise sqlstate '42501' using message='Only the group creator manages filling.';end if;
 if p_operation='attend' then
  perform private.require_cocreate_room_episode(actor,r.id,p_episode_id,true);
  if m.cancelled_at is not null or m.starts_at<=clock_timestamp() then raise sqlstate 'PT409' using message='This meeting is no longer accepting attendance.';end if;
  if not exists(select 1 from private.cocreate_meeting_attendance where meeting_id=m.id and actor_id=actor and episode_id=p_episode_id and attending)
   and private.cocreate_meeting_occupied(m.id)>=m.capacity then raise sqlstate 'PT409' using message='This meeting is full.';end if;
  insert into private.cocreate_meeting_attendance(meeting_id,actor_id,episode_id,attending) values(m.id,actor,p_episode_id,true)
   on conflict(meeting_id,actor_id) do update set episode_id=excluded.episode_id,attending=true;
 elsif p_operation='decline' then
  update private.cocreate_meeting_attendance set attending=false where meeting_id=m.id and actor_id=actor and episode_id=p_episode_id;
 elsif p_operation='cancel' then
  update private.cocreate_meetings set cancelled_at=coalesce(cancelled_at,clock_timestamp()) where id=m.id;
  update private.cocreate_recruitments set retracted_at=coalesce(retracted_at,clock_timestamp()) where meeting_id=m.id;
 else
  perform private.require_cocreate_room_episode(actor,r.id,p_episode_id,true);
  perform private.cocreate_publish_meeting(actor,m.id);
 end if;
 result:=jsonb_build_object('operation',p_operation,'hub_id',p_hub_id,'room_id',r.id,'episode_id',p_episode_id,'meeting_id',m.id);
 insert into private.cocreate_room_receipts values(actor,p_command_id,intent,result);
 perform private.cocreate_recruitment_signal(r.id);perform private.cocreate_signal(actor);
 return result;
end; $$;

-- Meeting place limits belong to each occurrence. The disclosed persistent-chat
-- ceiling cannot later be lowered by an old client into a second RSVP limit.
do $$ declare source text:=pg_get_functiondef('public.mutate_cocreate_numbered_group(uuid,uuid,uuid,text,uuid,uuid,integer,uuid,bigint,boolean)'::regprocedure);
 needle text:='if p_operation=''capacity'' then';
begin
 if strpos(source,needle)=0 then raise exception 'Unknown numbered capacity predecessor.';end if;
 execute replace(source,needle,needle||' if p_capacity<>50 and exists(select 1 from private.cocreate_meetings where room_id=room.id) then raise sqlstate ''PT409'' using message=''Meeting places are separate; this persistent chat retains its 50-member ceiling.'';end if;');
end; $$;

create function public.get_cocreate_current_meeting(p_expected_profile_id uuid,p_room_id uuid,p_episode_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_cocreate_actor(p_expected_profile_id); result jsonb;
begin
 perform private.require_cocreate_room_episode(actor,p_room_id,p_episode_id,true);
 select jsonb_build_object('meeting_id',m.id,'starts_at',m.starts_at,'capacity',m.capacity,
  'occupied',private.cocreate_meeting_occupied(m.id),'cancelled',m.cancelled_at is not null,
  'attending',exists(select 1 from private.cocreate_meeting_attendance a where a.meeting_id=m.id and a.actor_id=actor and a.episode_id=p_episode_id and a.attending),
  'recruitment', (select private.cocreate_recruitment_projection(c.id) from private.cocreate_recruitments c where c.meeting_id=m.id order by c.created_at desc,c.id desc limit 1)) into result
 from private.cocreate_meetings m where m.room_id=p_room_id order by m.created_at desc,m.id desc limit 1;
 return result;
end; $$;

do $$ declare signature text;begin
 foreach signature in array array[
  'public.schedule_cocreate_meeting(uuid,uuid,uuid,timestamptz,integer,uuid,uuid)',
  'public.mutate_cocreate_meeting(uuid,uuid,uuid,uuid,uuid,uuid,text)',
  'public.get_cocreate_current_meeting(uuid,uuid,uuid)'] loop
  execute 'revoke all on function '||signature||' from public,anon,authenticated,service_role';
  execute 'grant execute on function '||signature||' to authenticated';
 end loop;
 foreach signature in array array[
  'private.cocreate_meeting_occupied(uuid)','private.cocreate_recruitment_before_meetings(uuid)',
  'private.cocreate_recruitment_projection(uuid)','private.cocreate_publish_meeting(uuid,uuid)',
  'private.cocreate_join_meeting(uuid,uuid,uuid,uuid)'] loop
  execute 'revoke all on function '||signature||' from public,anon,authenticated,service_role';
 end loop;
end; $$;
