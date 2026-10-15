-- D-M00/M01 PROVISIONAL REVIEW ONLY. Named personal pair + selected Group;
-- explicit consent episodes, bounded retained history, no manager oversight.
-- This source must remain isolated until the founder approves the lifetime policy.
create table private.member_contact_pairs (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references private.community_groups(id) on delete restrict,
  low_profile_id uuid not null,
  high_profile_id uuid not null,
  created_at timestamptz not null default clock_timestamp(),
  last_ordinal bigint not null default 0 check(last_ordinal>=0),
  check(low_profile_id<high_profile_id),
  unique(group_id,low_profile_id,high_profile_id)
);
create index member_contact_pair_low on private.member_contact_pairs(low_profile_id,group_id,id);
create index member_contact_pair_high on private.member_contact_pairs(high_profile_id,group_id,id);
create table private.member_contact_requests (
  id uuid primary key default gen_random_uuid(),
  pair_id uuid not null references private.member_contact_pairs(id) on delete restrict,
  sender_profile_id uuid not null,
  recipient_profile_id uuid not null,
  group_name text not null,
  sender_display_name text not null,
  recipient_display_name text not null,
  note text check(note is null or char_length(note) between 1 and 500),
  status text not null default 'pending' check(status in ('pending','accepted','declined','withdrawn','expired','unavailable')),
  created_at timestamptz not null default clock_timestamp(),
  activity_at timestamptz not null default clock_timestamp(),
  expires_at timestamptz not null default(clock_timestamp()+interval '7 days'),
  resolved_at timestamptz,
  resolved_by uuid,
  check(sender_profile_id<>recipient_profile_id),
  check((status='pending')=(resolved_at is null)),
  check(expires_at>created_at)
);
create unique index member_contact_one_pending on private.member_contact_requests(pair_id) where status='pending';
create index member_contact_request_sender on private.member_contact_requests(sender_profile_id,activity_at desc,id desc);
create index member_contact_request_recipient on private.member_contact_requests(recipient_profile_id,activity_at desc,id desc);
create index member_contact_request_pair on private.member_contact_requests(pair_id,created_at desc,id desc);
create table private.member_contact_episodes (
  id uuid primary key default gen_random_uuid(),
  pair_id uuid not null references private.member_contact_pairs(id) on delete restrict,
  request_id uuid not null unique references private.member_contact_requests(id) on delete restrict,
  accepted_at timestamptz not null default clock_timestamp(),
  first_ordinal bigint not null check(first_ordinal>0),
  ended_at timestamptz,
  end_ordinal bigint,
  ended_reason text check(ended_reason in ('context_ended','closed','left')),
  ended_by uuid,
  check((ended_at is null)=(end_ordinal is null)),
  check((ended_at is null)=(ended_reason is null)),
  check(end_ordinal is null or end_ordinal>=first_ordinal-1)
);
create unique index member_contact_one_active on private.member_contact_episodes(pair_id) where ended_at is null;
create index member_contact_episode_pair on private.member_contact_episodes(pair_id,accepted_at desc,id desc);
create table private.member_contact_messages (
  id uuid primary key default gen_random_uuid(),
  pair_id uuid not null references private.member_contact_pairs(id) on delete restrict,
  episode_id uuid not null references private.member_contact_episodes(id) on delete restrict,
  sender_profile_id uuid not null,
  sender_display_name text not null,
  body text not null check(char_length(body) between 1 and 4000),
  ordinal bigint not null check(ordinal>0),
  created_at timestamptz not null default clock_timestamp(),
  unique(pair_id,ordinal)
);
create index member_contact_message_page on private.member_contact_messages(pair_id,ordinal desc,id desc);
create index member_contact_message_episode on private.member_contact_messages(episode_id);
create index member_contact_message_rate on private.member_contact_messages(sender_profile_id,created_at desc);
create table private.member_contact_receipts (
  profile_id uuid not null,
  action_id uuid not null,
  intent_hash text not null,
  result jsonb not null,
  created_at timestamptz not null default clock_timestamp(),
  primary key(profile_id,action_id)
);
create table private.member_contact_preferences (
  profile_id uuid not null,
  pair_id uuid not null references private.member_contact_pairs(id) on delete restrict,
  muted boolean not null default false,
  primary key(profile_id,pair_id)
);
create table private.member_contact_seen_requests (
  profile_id uuid not null,
  request_id uuid not null references private.member_contact_requests(id) on delete restrict,
  primary key(profile_id,request_id)
);
create index member_contact_seen_request_idx on private.member_contact_seen_requests(request_id);
create table private.member_contact_incoming (
  profile_id uuid not null,
  pair_id uuid not null references private.member_contact_pairs(id) on delete restrict,
  ordinal bigint not null,
  primary key(profile_id,pair_id,ordinal),
  foreign key(pair_id,ordinal) references private.member_contact_messages(pair_id,ordinal) on delete restrict
);
create index member_contact_incoming_pair on private.member_contact_incoming(pair_id,ordinal);
create table private.member_contact_read_frontiers (
  profile_id uuid not null,
  pair_id uuid not null references private.member_contact_pairs(id) on delete restrict,
  ordinal bigint not null check(ordinal>=0),
  primary key(profile_id,pair_id)
);
create table private.member_contact_read_snapshots (
  token uuid primary key default gen_random_uuid(),
  profile_id uuid not null,
  pair_id uuid not null references private.member_contact_pairs(id) on delete restrict,
  ordinal bigint not null check(ordinal>=0),
  issued_at timestamptz not null default clock_timestamp(),
  unique(profile_id,pair_id,ordinal)
);
create index member_contact_snapshot_pair on private.member_contact_read_snapshots(pair_id);

-- Provenance is immutable. Episode termination is one-way, including after rejoin.
create trigger member_contact_pair_provenance before update or delete on private.member_contact_pairs
  for each row execute function private.protect_group_relationship_provenance('last_ordinal');
create trigger member_contact_request_provenance before update or delete on private.member_contact_requests
  for each row execute function private.protect_group_relationship_provenance('status','activity_at','resolved_at','resolved_by');
create trigger member_contact_message_provenance before update or delete on private.member_contact_messages
  for each row execute function private.protect_moderation_append_only();
create trigger member_contact_receipt_provenance before update or delete on private.member_contact_receipts
  for each row execute function private.protect_moderation_append_only();
create function private.member_contact_protect_episode() returns trigger language plpgsql set search_path='' as $$
begin
  if tg_op='DELETE' or (to_jsonb(new)-array['ended_at','end_ordinal','ended_reason','ended_by']) is distinct from
    (to_jsonb(old)-array['ended_at','end_ordinal','ended_reason','ended_by']) or old.ended_at is not null then
    raise sqlstate '55000' using message='Member consent history is immutable.';
  end if;
  return new;
end; $$;
create trigger member_contact_episode_provenance before update or delete on private.member_contact_episodes
  for each row execute function private.member_contact_protect_episode();
do $$ declare t record;
begin
  for t in select tablename from pg_tables where schemaname='private' and tablename like 'member_contact_%'
  loop
    execute format('alter table private.%I enable row level security',t.tablename);
    execute format('revoke all on private.%I from public,anon,authenticated,service_role',t.tablename);
  end loop;
end; $$;
create function private.member_contact_limits() returns jsonb language sql immutable set search_path='' as $$
  select '{"note":500,"message":4000,"page":50,"expiry_days":7,"decline_cooldown_days":7,"actor_daily":20,"messages_per_minute":30}'::jsonb;
$$;
comment on function private.member_contact_limits() is 'Provisional operational bounds, not a permanent rejection policy. Unicode PostgreSQL character counts; exits, recovery, reports and ACK are not rate-limited.';

-- Mirrors canonical Group People UNION; never a manager-only or public-directory grant.
create function private.member_contact_person(p_group uuid,p_person uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select private.group_has_accountable_identity(p_group)
    and exists(select 1 from auth.users a join public.profiles p on p.id=a.id where a.id=p_person)
    and (private.group_authority_role(p_group,p_person) is not null or
      exists(select 1 from private.group_memberships m where m.group_id=p_group and m.profile_id=p_person and m.ended_at is null));
$$;
create function private.member_contact_pair_current(p_pair uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select coalesce((select private.member_contact_person(p.group_id,p.low_profile_id)
    and private.member_contact_person(p.group_id,p.high_profile_id) from private.member_contact_pairs p where p.id=p_pair),false);
$$;
create function private.member_contact_can_read(p_pair uuid,p_actor uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select exists(select 1 from private.member_contact_pairs p where p.id=p_pair and p_actor in(p.low_profile_id,p.high_profile_id)
    and exists(select 1 from auth.users a join public.profiles u on u.id=a.id where a.id=p_actor)
    and exists(select 1 from private.member_contact_episodes e where e.pair_id=p.id));
$$;
create function private.member_contact_can_send(p_pair uuid,p_actor uuid,p_episode uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select private.member_contact_can_read(p_pair,p_actor) and private.member_contact_pair_current(p_pair)
    and exists(select 1 from private.member_contact_episodes e where e.id=p_episode and e.pair_id=p_pair and e.ended_at is null)
    and not exists(select 1 from private.member_contact_pairs p where p.id=p_pair and private.has_active_user_block_between(p.low_profile_id,p.high_profile_id));
$$;
create function private.member_contact_lock(p_group uuid,p_low uuid,p_high uuid) returns void
language plpgsql security definer set search_path='' as $$
begin
  perform private.lock_user_interaction_pair(p_low,p_high);
  perform 1 from private.community_groups where id=p_group for update;
  -- Identity deletes need no Group lock in their invalidation trigger. Taking
  -- these shares before a pair/episode row serializes erasure without lock inversion.
  perform 1 from auth.users where id in(p_low,p_high) or id in
    (select profile_id from private.community_group_managers where group_id=p_group) order by id for share;
  perform 1 from public.profiles where id in(p_low,p_high) or id in
    (select profile_id from private.community_group_managers where group_id=p_group) order by id for share;
end; $$;
create function private.member_contact_signal(p_actor uuid,p_access boolean default false) returns void
language plpgsql security definer set search_path='' as $$
begin
  if exists(select 1 from auth.users u join public.profiles p on p.id=u.id where u.id=p_actor) then
    perform realtime.send(jsonb_build_object('profile_id',p_actor),
      case when p_access then 'member.contact_access_changed' else 'member.contact_changed' end,
      'member-contact:profile:'||p_actor::text,true);
  end if;
end; $$;
create function public.can_receive_member_contact_signal(p_topic text) returns boolean
language sql stable security definer set search_path='' as $$
  select auth.uid() is not null and p_topic='member-contact:profile:'||auth.uid()::text
    and exists(select 1 from auth.users u join public.profiles p on p.id=u.id where u.id=auth.uid());
$$;
create policy member_contact_signal_receive on realtime.messages for select to authenticated
  using(extension='broadcast' and public.can_receive_member_contact_signal((select realtime.topic())));

-- Only loss of the LAST qualifying relationship ends consent. A later regrant
-- cannot erase this boundary. Request and message operations use the same Group lock.
create function private.member_contact_end_unavailable(p_group uuid default null,p_person uuid default null) returns void
language plpgsql security definer set search_path='' as $$
declare pair private.member_contact_pairs; affected boolean;
begin
  for pair in select p.* from private.member_contact_pairs p where
    (p_group is null or p.group_id=p_group) and (p_person is null or p_person in(p.low_profile_id,p.high_profile_id)
      or exists(select 1 from private.community_group_managers g where g.group_id=p.group_id and g.profile_id=p_person))
    and not private.member_contact_pair_current(p.id) order by p.id for update
  loop
    affected:=false;
    update private.member_contact_episodes set ended_at=clock_timestamp(),end_ordinal=pair.last_ordinal,ended_reason='context_ended'
      where pair_id=pair.id and ended_at is null;
    affected:=found;
    update private.member_contact_requests set status='unavailable',resolved_at=clock_timestamp(),activity_at=clock_timestamp()
      where pair_id=pair.id and status='pending';
    affected:=affected or found;
    if affected then
      delete from private.member_contact_read_snapshots where pair_id=pair.id;
      perform private.member_contact_signal(pair.low_profile_id,true);
      perform private.member_contact_signal(pair.high_profile_id,true);
    end if;
  end loop;
end; $$;
create function private.member_contact_relationship_changed() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  perform private.member_contact_end_unavailable(coalesce(new.group_id,old.group_id),coalesce(new.profile_id,old.profile_id));
  return coalesce(new,old);
end; $$;
create trigger member_contact_membership_ended after update of ended_at on private.group_memberships
  for each row when(old.ended_at is distinct from new.ended_at) execute function private.member_contact_relationship_changed();
create trigger member_contact_delegate_ended after update of revoked_at on private.group_delegates
  for each row when(old.revoked_at is distinct from new.revoked_at) execute function private.member_contact_relationship_changed();
create function private.member_contact_identity_changed() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  perform private.member_contact_end_unavailable(null,coalesce(new.id,old.id));
  return coalesce(new,old);
end; $$;
create trigger member_contact_profile_changed after update of display_name on public.profiles
  for each row when(old.display_name is distinct from new.display_name) execute function private.member_contact_identity_changed();
create trigger member_contact_profile_deleted after delete on public.profiles
  for each row execute function private.member_contact_identity_changed();
-- Compose the installed Auth deletion hook; do not create another Auth trigger.
do $$ declare definition text:=pg_get_functiondef('private.group_contact_identity_access()'::regprocedure);
begin
  if strpos(definition,'perform private.group_contact_access_signal(subject);')=0 then raise exception 'Review Auth contact invalidation hook.'; end if;
  execute replace(definition,'perform private.group_contact_access_signal(subject);',
    'perform private.group_contact_access_signal(subject); perform private.member_contact_end_unavailable(null,subject);');
end; $$;

create function private.member_contact_status(p_request private.member_contact_requests) returns text
language sql stable set search_path='' as $$
  select case when p_request.status='pending' and p_request.expires_at<=statement_timestamp() then 'expired' else p_request.status end;
$$;
create function private.member_contact_request_actionable(p_request private.member_contact_requests) returns boolean
language sql stable security definer set search_path='' as $$
  select p_request.status='pending' and p_request.expires_at>statement_timestamp() and private.member_contact_pair_current(p_request.pair_id)
    and not private.has_active_user_block_between(p_request.sender_profile_id,p_request.recipient_profile_id);
$$;
create function private.member_contact_request_projection(p_request private.member_contact_requests,p_actor uuid,p_note boolean default false) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare pair private.member_contact_pairs; episode uuid; actionable boolean;
begin
  if p_actor not in(p_request.sender_profile_id,p_request.recipient_profile_id) then
    raise sqlstate '42501' using message='The personal request is unavailable.';
  end if;
  select * into pair from private.member_contact_pairs where id=p_request.pair_id;
  select id into episode from private.member_contact_episodes where request_id=p_request.id;
  actionable:=private.member_contact_request_actionable(p_request);
  return jsonb_build_object('item_kind','member_contact_request','request_id',p_request.id,'group_id',pair.group_id,'group_name',p_request.group_name,
    'sender_profile_id',p_request.sender_profile_id,'sender_display_name',p_request.sender_display_name,
    'recipient_profile_id',p_request.recipient_profile_id,'recipient_display_name',p_request.recipient_display_name,
    'request_message',case when p_actor=p_request.sender_profile_id or p_note then p_request.note else null end,
    'status',private.member_contact_status(p_request),'created_at',p_request.created_at,'activity_at',p_request.activity_at,'expires_at',p_request.expires_at,
    'chat_id',case when episode is not null then pair.id else null end,'episode_id',episode,
    'can_accept',actionable and p_actor=p_request.recipient_profile_id,
    'can_decline',p_request.status='pending' and p_actor=p_request.recipient_profile_id,
    'can_withdraw',p_request.status='pending' and p_actor=p_request.sender_profile_id);
end; $$;
create function public.get_own_member_contact_request(p_expected_profile_id uuid,p_request_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id); r private.member_contact_requests; disclose boolean;
begin
  select * into r from private.member_contact_requests where id=p_request_id;
  if r.id is null or actor not in(r.sender_profile_id,r.recipient_profile_id) then
    raise sqlstate '42501' using message='The personal request is unavailable.';
  end if;
  disclose:=actor=r.sender_profile_id or private.member_contact_request_actionable(r) or r.status='accepted'
    or exists(select 1 from private.member_contact_seen_requests where profile_id=actor and request_id=r.id);
  if disclose and actor=r.recipient_profile_id then
    insert into private.member_contact_seen_requests values(actor,r.id) on conflict do nothing;
  end if;
  return private.member_contact_request_projection(r,actor,disclose);
end; $$;
create function public.get_own_member_contact_context(p_expected_profile_id uuid,p_group_id uuid,p_recipient_profile_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id); pair uuid; person_name text; group_name text; available boolean;
begin
  if p_recipient_profile_id is null or actor=p_recipient_profile_id or not private.member_contact_person(p_group_id,actor)
    or not private.member_contact_person(p_group_id,p_recipient_profile_id) or private.has_active_user_block_between(actor,p_recipient_profile_id) then
    raise sqlstate '42501' using message='This personal contact context is unavailable.';
  end if;
  select display_name into person_name from public.profiles where id=p_recipient_profile_id;
  if person_name is null then raise sqlstate '42501' using message='This personal contact context is unavailable.'; end if;
  select name into group_name from private.community_groups where id=p_group_id;
  select id into pair from private.member_contact_pairs where group_id=p_group_id and low_profile_id=least(actor,p_recipient_profile_id) and high_profile_id=greatest(actor,p_recipient_profile_id);
  available:=not exists(select 1 from private.member_contact_episodes where pair_id=pair and ended_at is null)
    and not exists(select 1 from private.member_contact_requests where pair_id=pair and
      ((status='pending' and expires_at>statement_timestamp()) or (status='declined' and resolved_at>statement_timestamp()-make_interval(days=>(private.member_contact_limits()->>'decline_cooldown_days')::integer))));
  return jsonb_build_object('group_id',p_group_id,'group_name',group_name,'recipient_profile_id',p_recipient_profile_id,'recipient_display_name',person_name,'can_request',available);
end; $$;
create function private.member_contact_receipt_result(p_result jsonb,p_replayed boolean) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare status text; request uuid:=(p_result->>'request_id')::uuid; chat uuid:=(p_result->>'chat_id')::uuid; episode uuid;
begin
  if request is not null then select private.member_contact_status(r) into status from private.member_contact_requests r where r.id=request;
  elsif chat is not null then
    select id into episode from private.member_contact_episodes where pair_id=chat and ended_at is null;
    status:=case when private.member_contact_can_send(chat,auth.uid(),episode) then 'active' else 'read_only' end;
  end if;
  return p_result||jsonb_build_object('current_status',status,'replayed',p_replayed);
end; $$;
create function public.recover_member_contact_action(p_expected_profile_id uuid,p_action_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id); result jsonb;
begin
  if p_action_id is null then raise sqlstate '22023' using message='The action identity is required.'; end if;
  select r.result into result from private.member_contact_receipts r where r.profile_id=actor and r.action_id=p_action_id;
  return case when result is null then null else private.member_contact_receipt_result(result,true) end;
end; $$;
create function private.member_contact_command(p_expected uuid,p_action uuid,p_operation text,p_target uuid,p_intent jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected); hash text; prior private.member_contact_receipts; pair private.member_contact_pairs;
  r private.member_contact_requests; episode private.member_contact_episodes; message private.member_contact_messages; result jsonb;
  recipient uuid; target_group uuid; text_value text; sender_name text; target_name text; group_name text; next_ordinal bigint;
begin
  if p_action is null or p_target is null then raise sqlstate '22023' using message='The action identity and context are required.'; end if;
  perform pg_advisory_xact_lock(hashtextextended('member-contact-actor:'||actor::text,0));
  perform pg_advisory_xact_lock(hashtextextended('member-contact-action:'||actor::text||':'||p_action::text,0));
  hash:=private.group_command_hash(jsonb_build_object('operation',p_operation,'target',p_target,'intent',p_intent));
  select * into prior from private.member_contact_receipts where profile_id=actor and action_id=p_action;
  if found then
    if prior.intent_hash<>hash then raise sqlstate 'PT409' using message='This action has different submitted intent.'; end if;
    return private.member_contact_receipt_result(prior.result,true);
  end if;
  if p_operation='request' then
    target_group:=p_target; recipient:=(p_intent->>'recipient')::uuid;
    if recipient is null or recipient=actor then raise sqlstate '42501' using message='This personal contact context is unavailable.'; end if;
    perform private.member_contact_lock(target_group,least(actor,recipient),greatest(actor,recipient));
    perform private.require_group_identity(actor);
    if not private.member_contact_person(target_group,actor) or not private.member_contact_person(target_group,recipient)
      or private.has_active_user_block_between(actor,recipient) then raise sqlstate '42501' using message='This personal contact context is unavailable.'; end if;
    select display_name into sender_name from public.profiles where id=actor;
    select display_name into target_name from public.profiles where id=recipient;
    if sender_name is null or target_name is null then raise sqlstate '42501' using message='This personal contact context is unavailable.'; end if;
    text_value:=nullif(regexp_replace(coalesce(p_intent->>'note',''),'^[[:space:]]+|[[:space:]]+$','','g'),'');
    if char_length(text_value)>(private.member_contact_limits()->>'note')::integer then raise sqlstate '22023' using message='The introduction is too long.'; end if;
    if (select count(*) from private.member_contact_requests where sender_profile_id=actor and created_at>clock_timestamp()-interval '1 day')>=(private.member_contact_limits()->>'actor_daily')::integer then
      raise sqlstate 'PT429' using message='The personal request limit has been reached.'; end if;
    insert into private.member_contact_pairs(group_id,low_profile_id,high_profile_id) values(target_group,least(actor,recipient),greatest(actor,recipient))
      on conflict(group_id,low_profile_id,high_profile_id) do nothing;
    select * into pair from private.member_contact_pairs p where p.group_id=target_group and p.low_profile_id=least(actor,recipient) and p.high_profile_id=greatest(actor,recipient) for update;
    update private.member_contact_requests set status='expired',resolved_at=clock_timestamp(),activity_at=clock_timestamp()
      where pair_id=pair.id and status='pending' and expires_at<=clock_timestamp();
    if exists(select 1 from private.member_contact_episodes where pair_id=pair.id and ended_at is null)
      or exists(select 1 from private.member_contact_requests where pair_id=pair.id and
        (status='pending' or (status='declined' and resolved_at>clock_timestamp()-make_interval(days=>(private.member_contact_limits()->>'decline_cooldown_days')::integer)))) then
      raise sqlstate 'PT409' using message='A personal request or conversation already applies. Refresh the context.'; end if;
    select name into group_name from private.community_groups where id=target_group;
    insert into private.member_contact_requests(pair_id,sender_profile_id,recipient_profile_id,group_name,sender_display_name,recipient_display_name,note,expires_at)
      values(pair.id,actor,recipient,group_name,sender_name,target_name,text_value,clock_timestamp()+make_interval(days=>(private.member_contact_limits()->>'expiry_days')::integer)) returning * into r;
    insert into private.outbox_events(event_type,payload) values('member_contact.request_created',jsonb_build_object('request_id',r.id,'recipient_profile_id',recipient));
    result:=jsonb_build_object('group_id',target_group,'request_id',r.id,'chat_id',null,'episode_id',null,'message_id',null,'outcome','requested');
  elsif p_operation in ('accept','decline','withdraw') then
    select * into r from private.member_contact_requests where id=p_target;
    if r.id is null or actor not in(r.sender_profile_id,r.recipient_profile_id) or
      (p_operation='withdraw' and actor<>r.sender_profile_id) or (p_operation<>'withdraw' and actor<>r.recipient_profile_id) then
      raise sqlstate '42501' using message='The personal request is unavailable.'; end if;
    select * into pair from private.member_contact_pairs where id=r.pair_id;
    perform private.member_contact_lock(pair.group_id,pair.low_profile_id,pair.high_profile_id);
    perform private.require_group_identity(actor);
    select * into pair from private.member_contact_pairs where id=pair.id for update;
    select * into r from private.member_contact_requests where id=p_target for update;
    if r.status<>'pending' then raise sqlstate 'PT409' using message='The personal request has already ended.'; end if;
    if p_operation='accept' then
      if r.expires_at<=clock_timestamp() or not private.member_contact_request_actionable(r) then
        raise sqlstate 'PT409' using message='The personal request is no longer available.'; end if;
      insert into private.member_contact_episodes(pair_id,request_id,first_ordinal) values(pair.id,r.id,pair.last_ordinal+1) returning * into episode;
    end if;
    update private.member_contact_requests set status=case p_operation when 'accept' then 'accepted' when 'decline' then 'declined' else 'withdrawn' end,
      resolved_at=clock_timestamp(),resolved_by=actor,activity_at=clock_timestamp() where id=r.id returning * into r;
    result:=jsonb_build_object('group_id',pair.group_id,'request_id',r.id,'chat_id',case when episode.id is not null then pair.id else null end,
      'episode_id',episode.id,'message_id',null,'outcome',r.status);
  else
    select * into pair from private.member_contact_pairs where id=p_target;
    if pair.id is null or actor not in(pair.low_profile_id,pair.high_profile_id) then raise sqlstate '42501' using message='The personal conversation is unavailable.'; end if;
    perform private.member_contact_lock(pair.group_id,pair.low_profile_id,pair.high_profile_id);
    perform private.require_group_identity(actor);
    select * into pair from private.member_contact_pairs where id=p_target for update;
    if not private.member_contact_can_read(pair.id,actor) then raise sqlstate '42501' using message='The personal conversation is unavailable.'; end if;
    if p_operation='mute' then
      if jsonb_typeof(p_intent->'muted') is distinct from 'boolean' then raise sqlstate '22023' using message='The mute setting is required.'; end if;
      insert into private.member_contact_preferences(profile_id,pair_id,muted) values(actor,pair.id,(p_intent->>'muted')::boolean)
        on conflict(profile_id,pair_id) do update set muted=excluded.muted;
    else
      select * into episode from private.member_contact_episodes where id=(p_intent->>'episode')::uuid and pair_id=pair.id;
      if episode.id is null or episode.ended_at is not null then raise sqlstate 'PT409' using message='The personal consent episode has ended. Refresh the conversation.'; end if;
      if p_operation='send' then
        if not private.member_contact_can_send(pair.id,actor,episode.id) then raise sqlstate '42501' using message='Sending is unavailable. Refresh the conversation.'; end if;
        text_value:=regexp_replace(coalesce(p_intent->>'body',''),'^[[:space:]]+|[[:space:]]+$','','g');
        if char_length(text_value) not between 1 and (private.member_contact_limits()->>'message')::integer then raise sqlstate '22023' using message='The personal message length is invalid.'; end if;
        if (select count(*) from private.member_contact_messages where sender_profile_id=actor and created_at>clock_timestamp()-interval '1 minute')>=(private.member_contact_limits()->>'messages_per_minute')::integer then
          raise sqlstate 'PT429' using message='The message limit has been reached.'; end if;
        select case when sender_profile_id=actor then sender_display_name else recipient_display_name end into sender_name from private.member_contact_requests where id=episode.request_id;
        update private.member_contact_pairs set last_ordinal=last_ordinal+1 where id=pair.id returning last_ordinal into next_ordinal;
        insert into private.member_contact_messages(pair_id,episode_id,sender_profile_id,sender_display_name,body,ordinal)
          values(pair.id,episode.id,actor,sender_name,text_value,next_ordinal) returning * into message;
        recipient:=case when actor=pair.low_profile_id then pair.high_profile_id else pair.low_profile_id end;
        insert into private.member_contact_incoming values(recipient,pair.id,next_ordinal);
      elsif p_operation in ('close','leave') then
        update private.member_contact_episodes set ended_at=clock_timestamp(),end_ordinal=pair.last_ordinal,
          ended_reason=case when p_operation='close' then 'closed' else 'left' end,ended_by=actor where id=episode.id;
        delete from private.member_contact_read_snapshots where pair_id=pair.id;
      else raise sqlstate '22023' using message='Unsupported personal contact operation.'; end if;
    end if;
    result:=jsonb_build_object('group_id',pair.group_id,'request_id',null,'chat_id',pair.id,'episode_id',episode.id,'message_id',message.id,
      'outcome',case p_operation when 'send' then 'sent' when 'close' then 'closed' when 'leave' then 'left'
        else case when (p_intent->>'muted')::boolean then 'muted' else 'unmuted' end end);
  end if;
  insert into private.member_contact_receipts(profile_id,action_id,intent_hash,result) values(actor,p_action,hash,result);
  perform private.member_contact_signal(actor,p_operation in ('close','leave'));
  if p_operation<>'mute' then
    recipient:=case when actor=pair.low_profile_id then pair.high_profile_id else pair.low_profile_id end;
    perform private.member_contact_signal(recipient,p_operation in ('close','leave'));
  end if;
  return private.member_contact_receipt_result(result,false);
end; $$;
create function public.submit_member_contact_request(p_expected_profile_id uuid,p_action_id uuid,p_group_id uuid,p_recipient_profile_id uuid,p_note text default null) returns jsonb
language sql security definer set search_path='' as $$ select private.member_contact_command(p_expected_profile_id,p_action_id,'request',p_group_id,jsonb_build_object('recipient',p_recipient_profile_id,'note',p_note)); $$;
create function public.accept_member_contact_request(p_expected_profile_id uuid,p_action_id uuid,p_request_id uuid) returns jsonb
language sql security definer set search_path='' as $$ select private.member_contact_command(p_expected_profile_id,p_action_id,'accept',p_request_id,'{}'); $$;
create function public.decline_member_contact_request(p_expected_profile_id uuid,p_action_id uuid,p_request_id uuid) returns jsonb
language sql security definer set search_path='' as $$ select private.member_contact_command(p_expected_profile_id,p_action_id,'decline',p_request_id,'{}'); $$;
create function public.withdraw_member_contact_request(p_expected_profile_id uuid,p_action_id uuid,p_request_id uuid) returns jsonb
language sql security definer set search_path='' as $$ select private.member_contact_command(p_expected_profile_id,p_action_id,'withdraw',p_request_id,'{}'); $$;
create function public.send_member_contact_message(p_expected_profile_id uuid,p_action_id uuid,p_chat_id uuid,p_episode_id uuid,p_body text) returns jsonb
language sql security definer set search_path='' as $$ select private.member_contact_command(p_expected_profile_id,p_action_id,'send',p_chat_id,jsonb_build_object('episode',p_episode_id,'body',p_body)); $$;
create function public.close_member_contact_conversation(p_expected_profile_id uuid,p_action_id uuid,p_chat_id uuid,p_episode_id uuid) returns jsonb
language sql security definer set search_path='' as $$ select private.member_contact_command(p_expected_profile_id,p_action_id,'close',p_chat_id,jsonb_build_object('episode',p_episode_id)); $$;
create function public.leave_member_contact_conversation(p_expected_profile_id uuid,p_action_id uuid,p_chat_id uuid,p_episode_id uuid) returns jsonb
language sql security definer set search_path='' as $$ select private.member_contact_command(p_expected_profile_id,p_action_id,'leave',p_chat_id,jsonb_build_object('episode',p_episode_id)); $$;
create function public.set_member_contact_muted(p_expected_profile_id uuid,p_action_id uuid,p_chat_id uuid,p_muted boolean) returns jsonb
language sql security definer set search_path='' as $$ select private.member_contact_command(p_expected_profile_id,p_action_id,'mute',p_chat_id,jsonb_build_object('muted',p_muted)); $$;

create function private.member_contact_message_projection(p_message private.member_contact_messages) returns jsonb
language sql stable set search_path='' as $$
  select jsonb_build_object('id',p_message.id,'chat_id',p_message.pair_id,'episode_id',p_message.episode_id,
    'sender_profile_id',p_message.sender_profile_id,'sender_display_name',p_message.sender_display_name,
    'body',p_message.body,'ordinal',p_message.ordinal,'created_at',p_message.created_at);
$$;
create function private.member_contact_message_readable(p_message private.member_contact_messages,p_actor uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select private.member_contact_can_read(p_message.pair_id,p_actor) and exists(select 1 from private.member_contact_episodes e
    where e.id=p_message.episode_id and e.pair_id=p_message.pair_id and p_message.ordinal>=e.first_ordinal
      and (e.end_ordinal is null or p_message.ordinal<=e.end_ordinal));
$$;
create function private.member_contact_unread(p_actor uuid,p_pair uuid) returns bigint
language sql stable security definer set search_path='' as $$
  select count(*) from private.member_contact_incoming i join private.member_contact_messages m on m.pair_id=i.pair_id and m.ordinal=i.ordinal
    where i.profile_id=p_actor and i.pair_id=p_pair and private.member_contact_message_readable(m,p_actor)
    and i.ordinal>coalesce((select ordinal from private.member_contact_read_frontiers where profile_id=p_actor and pair_id=p_pair),0);
$$;
create function private.member_contact_chat_projection(p_pair uuid,p_actor uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare pair private.member_contact_pairs; episode private.member_contact_episodes; request private.member_contact_requests; message private.member_contact_messages;
begin
  if not private.member_contact_can_read(p_pair,p_actor) then raise sqlstate '42501' using message='The personal conversation is unavailable.'; end if;
  select * into pair from private.member_contact_pairs where id=p_pair;
  select * into episode from private.member_contact_episodes where pair_id=p_pair order by accepted_at desc,id desc limit 1;
  select * into request from private.member_contact_requests where id=episode.request_id;
  select * into message from private.member_contact_messages m where m.pair_id=p_pair and private.member_contact_message_readable(m,p_actor) order by ordinal desc,id desc limit 1;
  return jsonb_build_object('item_kind','member_contact_chat','chat_id',p_pair,'group_id',pair.group_id,'group_name',request.group_name,
    'peer_profile_id',case when p_actor=pair.low_profile_id then pair.high_profile_id else pair.low_profile_id end,
    'peer_display_name',case when p_actor=request.sender_profile_id then request.recipient_display_name else request.sender_display_name end,
    'created_at',pair.created_at,'activity_at',greatest(episode.accepted_at,coalesce(message.created_at,episode.accepted_at)),
    'is_read_only',not private.member_contact_can_send(p_pair,p_actor,episode.id),'current_episode_id',case when episode.ended_at is null then episode.id else null end,
    'ended_reason',episode.ended_reason,'muted',coalesce((select muted from private.member_contact_preferences where profile_id=p_actor and pair_id=p_pair),false),
    'latest_message',case when message.id is null then null else private.member_contact_message_projection(message) end,'unread_count',private.member_contact_unread(p_actor,p_pair));
end; $$;
create function public.get_own_member_contact_conversation(p_expected_profile_id uuid,p_chat_id uuid) returns jsonb
language sql stable security definer set search_path='' as $$ select private.member_contact_chat_projection(p_chat_id,private.require_group_identity(p_expected_profile_id)); $$;
create function public.get_own_member_contact_feed(p_expected_profile_id uuid,p_chat_id uuid,p_limit integer default 20,p_before_ordinal bigint default null,p_before_id uuid default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id); items jsonb; boundary uuid; frontier bigint;
begin
  if not private.member_contact_can_read(p_chat_id,actor) then raise sqlstate '42501' using message='The personal conversation is unavailable.'; end if;
  if p_limit is null or p_limit not between 1 and 50 or (p_before_ordinal is null)<>(p_before_id is null) or p_before_ordinal<=0 then
    raise sqlstate '22023' using message='Invalid personal history page or cursor.'; end if;
  -- One statement snapshot ties the token to exactly the returned committed page.
  select coalesce(jsonb_agg(private.member_contact_message_projection(m) order by m.ordinal desc,m.id desc),'[]'),coalesce(max(m.ordinal),0) into items,frontier
    from (select m.* from private.member_contact_messages m where m.pair_id=p_chat_id and private.member_contact_message_readable(m,actor)
      and (p_before_id is null or (m.ordinal,m.id)<(p_before_ordinal,p_before_id)) order by m.ordinal desc,m.id desc limit p_limit) m;
  if p_before_id is null then
    delete from private.member_contact_read_snapshots where profile_id=actor and issued_at<clock_timestamp()-interval '7 days';
    insert into private.member_contact_read_snapshots(profile_id,pair_id,ordinal) values(actor,p_chat_id,frontier)
      on conflict(profile_id,pair_id,ordinal) do update set issued_at=clock_timestamp() returning token into boundary;
  end if;
  return jsonb_build_object('items',items,'read_boundary',boundary);
end; $$;
create function public.acknowledge_member_contact_read(p_expected_profile_id uuid,p_chat_id uuid,p_boundary uuid) returns void
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id); snapshot private.member_contact_read_snapshots;
begin
  perform 1 from private.member_contact_pairs where id=p_chat_id for share;
  select * into snapshot from private.member_contact_read_snapshots where token=p_boundary and profile_id=actor and pair_id=p_chat_id and issued_at>=clock_timestamp()-interval '7 days';
  if snapshot.token is null or not private.member_contact_can_read(p_chat_id,actor) then raise sqlstate '42501' using message='The personal read boundary is unavailable.'; end if;
  insert into private.member_contact_read_frontiers values(actor,p_chat_id,snapshot.ordinal) on conflict(profile_id,pair_id)
    do update set ordinal=greatest(private.member_contact_read_frontiers.ordinal,excluded.ordinal);
  perform private.member_contact_signal(actor);
end; $$;

-- Delivery dispatcher owned by shared notifications calls these current checks.
-- No body, roster, Group ID or arbitrary destination is included in the outbox.
create function private.member_contact_notice_allowed(p_request uuid,p_recipient uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select exists(select 1 from private.member_contact_requests r where r.id=p_request and r.recipient_profile_id=p_recipient
    and private.member_contact_request_actionable(r));
$$;
create function private.member_contact_notice_projection(p_request uuid,p_recipient uuid) returns jsonb
language sql stable security definer set search_path='' as $$
  select jsonb_build_object('request_id',r.id,'recipient_profile_id',r.recipient_profile_id,'actor_profile_id',r.sender_profile_id,
    'created_at',r.created_at,'destination_kind','member_contact_request') from private.member_contact_requests r
    where r.id=p_request and private.member_contact_notice_allowed(r.id,p_recipient);
$$;
create function private.member_contact_message_notice_allowed(p_chat uuid,p_recipient uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select exists(select 1 from private.member_contact_episodes e where e.pair_id=p_chat and e.ended_at is null
    and private.member_contact_can_send(p_chat,p_recipient,e.id)) and not coalesce((select muted from private.member_contact_preferences where pair_id=p_chat and profile_id=p_recipient),false);
$$;
do $$ declare f record;
begin
  for f in select p.oid::regprocedure signature,n.nspname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where (n.nspname='private' and p.proname like 'member_contact_%') or (n.nspname='public' and p.proname like '%member_contact%')
  loop execute format('revoke all on function %s from public,anon,authenticated,service_role',f.signature);
    if f.nspname='public' then execute format('grant execute on function %s to authenticated',f.signature); end if;
  end loop;
end; $$;
