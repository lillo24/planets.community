-- MSG01: durable unordered participation pairs. Original request episodes,
-- legacy chat/message IDs, and audit/evidence references remain untouched.
create table public.participation_conversations (
  id uuid primary key default gen_random_uuid(),
  lower_profile_id uuid not null references public.profiles(id) on delete restrict,
  upper_profile_id uuid not null references public.profiles(id) on delete restrict,
  activated_at timestamptz not null,
  constraint participation_conversations_ordered_pair check (lower_profile_id < upper_profile_id),
  constraint participation_conversations_pair_key unique (lower_profile_id, upper_profile_id)
);
create index participation_conversations_upper_idx on public.participation_conversations(upper_profile_id);

create table public.participation_conversation_requests (
  request_id uuid primary key references public.project_join_requests(id) on delete restrict,
  conversation_id uuid not null references public.participation_conversations(id) on delete restrict,
  legacy_chat_id uuid not null unique references public.project_join_request_chats(id) on delete restrict
);
create index participation_conversation_requests_conversation_idx
  on public.participation_conversation_requests(conversation_id, request_id);

create table public.participation_conversation_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.participation_conversations(id) on delete restrict,
  sender_profile_id uuid not null references public.profiles(id) on delete restrict,
  body text not null check (body = regexp_replace(body, '^[[:space:]]+|[[:space:]]+$', '', 'g') and char_length(body) between 1 and 4000),
  created_at timestamptz not null default clock_timestamp()
);
create index participation_conversation_messages_feed_idx
  on public.participation_conversation_messages(conversation_id, created_at desc, id desc);
create index participation_conversation_messages_sender_idx
  on public.participation_conversation_messages(sender_profile_id);

alter table public.participation_conversations enable row level security;
alter table public.participation_conversation_requests enable row level security;
alter table public.participation_conversation_messages enable row level security;
revoke all on public.participation_conversations, public.participation_conversation_requests,
  public.participation_conversation_messages from public, anon, authenticated, service_role;

comment on table public.participation_conversations is
  'One immutable unordered requester/immutable Project Creator pair, established only by canonical participation requests. Resource/group chats remain independent.';
comment on table public.participation_conversation_requests is
  'Immutable no-copy mapping of every request episode and its retained legacy chat to the durable participation pair.';
comment on table public.participation_conversation_messages is
  'Immutable pair follow-ups without an invented request context. Existing messages remain in their original request-scoped tables.';

-- Deterministic upgrade anchor: earliest creation, then original chat UUID.
insert into public.participation_conversations(id, lower_profile_id, upper_profile_id, activated_at)
select distinct on (least(r.requester_profile_id, p.creator_profile_id), greatest(r.requester_profile_id, p.creator_profile_id))
  c.id, least(r.requester_profile_id, p.creator_profile_id), greatest(r.requester_profile_id, p.creator_profile_id), r.created_at
from public.project_join_requests r
join public.projects p on p.id = r.project_id
join public.project_join_request_chats c on c.request_id = r.id
order by least(r.requester_profile_id, p.creator_profile_id), greatest(r.requester_profile_id, p.creator_profile_id), r.created_at, c.id;

insert into public.participation_conversation_requests(request_id, conversation_id, legacy_chat_id)
select r.id, pair.id, c.id
from public.project_join_requests r
join public.projects p on p.id = r.project_id
join public.project_join_request_chats c on c.request_id = r.id
join public.participation_conversations pair
  on pair.lower_profile_id = least(r.requester_profile_id, p.creator_profile_id)
  and pair.upper_profile_id = greatest(r.requester_profile_id, p.creator_profile_id);

do $$
begin
  if exists (select 1 from public.project_join_requests r
    left join public.participation_conversation_requests a on a.request_id=r.id
    where a.request_id is null) then
    raise exception using errcode='55000', message='Participation conversation upgrade found a request without its required legacy anchor.';
  end if;
end;
$$;

create function private.protect_participation_conversation_history()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  raise exception using errcode = '55000', message = 'Participation conversation history is immutable.';
end;
$$;
create trigger participation_conversations_immutable before update or delete on public.participation_conversations
for each row execute function private.protect_participation_conversation_history();
create trigger participation_conversation_requests_immutable before update or delete on public.participation_conversation_requests
for each row execute function private.protect_participation_conversation_history();
create trigger participation_conversation_messages_immutable before update or delete on public.participation_conversation_messages
for each row execute function private.protect_participation_conversation_history();

create function private.associate_participation_conversation()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  requester_id uuid;
  creator_id uuid;
  pair_id uuid;
begin
  select r.requester_profile_id, p.creator_profile_id into requester_id, creator_id
  from public.project_join_requests r join public.projects p on p.id = r.project_id
  where r.id = new.request_id;
  -- No conversation lock before/after Project locks: the unique pair constraint
  -- arbitrates concurrent inserts. ON CONFLICT does not update immutable rows.
  insert into public.participation_conversations(lower_profile_id, upper_profile_id, activated_at)
  values (least(requester_id, creator_id), greatest(requester_id, creator_id), new.activated_at)
  on conflict (lower_profile_id, upper_profile_id) do nothing;
  select id into strict pair_id from public.participation_conversations
  where lower_profile_id = least(requester_id, creator_id) and upper_profile_id = greatest(requester_id, creator_id);
  insert into public.participation_conversation_requests(request_id, conversation_id, legacy_chat_id)
  values (new.request_id, pair_id, new.id);
  return new;
end;
$$;
create trigger project_join_request_chats_associate_pair after insert on public.project_join_request_chats
for each row execute function private.associate_participation_conversation();

create function private.profile_can_access_participation_conversation(p_conversation_id uuid, p_profile_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select p_profile_id is not null and exists (
    select 1 from public.participation_conversations c
    where c.id = p_conversation_id and p_profile_id in (c.lower_profile_id, c.upper_profile_id)
  );
$$;

-- Deliberately supersedes the former manager permission, including retained RPCs
-- and their private topic authorization. Request management RPCs are unchanged.
create or replace function private.profile_can_access_project_join_request_chat(p_chat_id uuid, p_profile_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.participation_conversation_requests a
    where a.legacy_chat_id = p_chat_id
      and private.profile_can_access_participation_conversation(a.conversation_id, p_profile_id));
$$;

create function private.participation_request_allows_conversation_send(p_request_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.project_join_requests r
    where r.id = p_request_id and r.status = 'pending'
      and not exists (
        select 1 from private.current_project_manager_profile_ids(r.project_id) m
        where private.has_active_user_block_between(r.requester_profile_id, m.profile_id)
      )
  );
$$;

create function private.participation_conversation_feed(p_conversation_id uuid)
returns table (
  item_kind text, item_id uuid, chat_id uuid, request_id uuid, message_id uuid,
  project_id uuid, project_kind text, project_title text, request_status text,
  request_message text, requester_profile_id uuid, requester_display_name text,
  sender_profile_id uuid, sender_display_name text, body text, created_at timestamptz,
  resolved_at timestamptz, accepted_project_group_chat_id uuid
)
language sql stable security definer set search_path = '' as $$
  select 'request'::text, r.id, a.conversation_id, r.id, null::uuid,
    r.project_id, p.project_kind, coalesce(proposal.title, tavolo.title), r.status,
    r.request_message, r.requester_profile_id, requester.display_name,
    null::uuid, null::text, null::text, r.created_at, r.resolved_at,
    case when r.status = 'accepted' then g.id end
  from public.participation_conversation_requests a
  join public.project_join_requests r on r.id = a.request_id
  join public.projects p on p.id = r.project_id
  join public.profiles requester on requester.id = r.requester_profile_id
  left join public.proposals proposal on proposal.id = p.id and p.project_kind = 'one_time'
  left join public.recurring_activities tavolo on tavolo.id = p.id and p.project_kind = 'recurring'
  left join public.project_group_chats g on g.project_id = p.id
  where a.conversation_id = p_conversation_id
  union all
  select 'legacy_message', m.id, a.conversation_id, a.request_id, m.id,
    null::uuid, null::text, null::text, null::text, null::text, null::uuid, null::text,
    m.sender_profile_id, author.display_name, m.body, m.created_at, null::timestamptz, null::uuid
  from public.participation_conversation_requests a
  join public.project_join_request_chat_messages m on m.chat_id = a.legacy_chat_id
  join public.profiles author on author.id = m.sender_profile_id
  where a.conversation_id = p_conversation_id
  union all
  select 'message', m.id, m.conversation_id, null::uuid, m.id,
    null::uuid, null::text, null::text, null::text, null::text, null::uuid, null::text,
    m.sender_profile_id, author.display_name, m.body, m.created_at, null::timestamptz, null::uuid
  from public.participation_conversation_messages m
  join public.profiles author on author.id = m.sender_profile_id
  where m.conversation_id = p_conversation_id;
$$;

create function public.list_own_participation_conversation_items(
  p_expected_profile_id uuid, p_chat_id uuid, p_limit integer,
  p_before_created_at timestamptz default null, p_before_item_kind text default null,
  p_before_item_id uuid default null, p_only_pending boolean default false
)
returns table (
  item_kind text, item_id uuid, chat_id uuid, request_id uuid, message_id uuid,
  project_id uuid, project_kind text, project_title text, request_status text,
  request_message text, requester_profile_id uuid, requester_display_name text,
  sender_profile_id uuid, sender_display_name text, body text, created_at timestamptz,
  resolved_at timestamptz, accepted_project_group_chat_id uuid
)
language plpgsql stable security definer set search_path = '' as $$
declare
  actor uuid := private.require_participation_identity(p_expected_profile_id);
  cursor_order integer;
begin
  if not private.profile_can_access_participation_conversation(p_chat_id, actor) then
    raise exception using errcode = '42501', message = 'The participation-request chat is unavailable.';
  end if;
  if p_limit is null or p_limit not between 1 and 50 or p_only_pending is null
    or num_nonnulls(p_before_created_at, p_before_item_kind, p_before_item_id) not in (0, 3) then
    raise exception using errcode = '22023', message = 'Invalid conversation page or complete cursor.';
  end if;
  cursor_order := case p_before_item_kind when 'request' then 0 when 'legacy_message' then 1 when 'message' then 2 end;
  if p_before_item_kind is not null and (cursor_order is null or (p_only_pending and cursor_order <> 0)) then
    raise exception using errcode = '22023', message = 'Unsupported conversation cursor kind.';
  end if;
  return query select f.* from private.participation_conversation_feed(p_chat_id) f
  where (not p_only_pending or (f.item_kind = 'request' and f.request_status = 'pending'))
    and (p_before_created_at is null or
      (f.created_at, case f.item_kind when 'request' then 0 when 'legacy_message' then 1 else 2 end, f.item_id)
      < (p_before_created_at, cursor_order, p_before_item_id))
  order by f.created_at desc, case f.item_kind when 'request' then 0 when 'legacy_message' then 1 else 2 end desc, f.item_id desc
  limit p_limit;
end;
$$;

create function public.get_own_participation_conversation_requests(
  p_expected_profile_id uuid, p_chat_id uuid, p_request_ids uuid[]
)
returns table (
  item_kind text, item_id uuid, chat_id uuid, request_id uuid, message_id uuid,
  project_id uuid, project_kind text, project_title text, request_status text,
  request_message text, requester_profile_id uuid, requester_display_name text,
  sender_profile_id uuid, sender_display_name text, body text, created_at timestamptz,
  resolved_at timestamptz, accepted_project_group_chat_id uuid
)
language plpgsql stable security definer set search_path = '' as $$
declare actor uuid := private.require_participation_identity(p_expected_profile_id);
begin
  if not private.profile_can_access_participation_conversation(p_chat_id, actor) then
    raise exception using errcode = '42501', message = 'The participation-request chat is unavailable.';
  end if;
  if p_request_ids is null or cardinality(p_request_ids) not between 1 and 50 then
    raise exception using errcode = '22023', message = 'Request context lookup requires 1 through 50 identifiers.';
  end if;
  return query select f.* from private.participation_conversation_feed(p_chat_id) f
  where f.item_kind = 'request' and f.request_id = any(p_request_ids);
end;
$$;

create function public.get_own_participation_conversation(p_expected_profile_id uuid, p_request_id uuid)
returns table (
  chat_id uuid, request_id uuid, project_id uuid, project_kind text, project_title text,
  viewer_role text, requester_profile_id uuid, requester_display_name text,
  creator_profile_id uuid, creator_display_name text, request_status text, request_message text,
  request_created_at timestamptz, resolved_at timestamptz, activated_at timestamptz,
  is_read_only boolean, has_send_entitlement boolean, accepted_project_group_chat_id uuid,
  pending_count integer, pending_items jsonb
)
language plpgsql stable security definer set search_path = '' as $$
declare
  actor uuid := private.require_participation_identity(p_expected_profile_id);
  pair_id uuid;
begin
  select a.conversation_id into pair_id from public.participation_conversation_requests a
  where a.request_id = p_request_id and private.profile_can_access_participation_conversation(a.conversation_id, actor);
  if pair_id is null then
    raise exception using errcode = '42501', message = 'The participation-request chat is unavailable.';
  end if;
  return query
  select pair.id, r.id, p.id, p.project_kind, coalesce(proposal.title, tavolo.title),
    case when r.requester_profile_id = actor then 'requester' else 'creator' end,
    r.requester_profile_id, requester.display_name, p.creator_profile_id, creator.display_name,
    r.status, r.request_message, r.created_at, r.resolved_at, pair.activated_at,
    not entitlement.allowed, entitlement.allowed, case when r.status = 'accepted' then g.id end,
    summary.pending_count, coalesce(summary.pending_items, '[]'::jsonb)
  from public.project_join_requests r
  join public.projects p on p.id = r.project_id
  join public.participation_conversations pair on pair.id = pair_id
  join public.profiles requester on requester.id = r.requester_profile_id
  join public.profiles creator on creator.id = p.creator_profile_id
  left join public.proposals proposal on proposal.id = p.id and p.project_kind = 'one_time'
  left join public.recurring_activities tavolo on tavolo.id = p.id and p.project_kind = 'recurring'
  left join public.project_group_chats g on g.project_id = p.id
  cross join lateral (
    select exists (select 1 from public.participation_conversation_requests a
      where a.conversation_id = pair_id and private.participation_request_allows_conversation_send(a.request_id)) as allowed
  ) entitlement
  cross join lateral (
    select (select count(*)::integer from public.participation_conversation_requests a
      join public.project_join_requests pending on pending.id = a.request_id
      where a.conversation_id = pair_id and pending.status = 'pending') as pending_count,
      (select jsonb_agg(to_jsonb(f)) from public.list_own_participation_conversation_items(actor, pair_id, 30, null, null, null, true) f) as pending_items
  ) summary
  where r.id = p_request_id;
end;
$$;

create function private.participation_conversation_topic(p_chat_id uuid, p_profile_id uuid)
returns text language sql immutable security definer set search_path = '' as $$
  select format('participation-conversation:%s:profile:%s', p_chat_id, p_profile_id);
$$;
create function private.profile_can_receive_participation_conversation_topic(p_topic text)
returns boolean language plpgsql stable security definer set search_path = '' as $$
declare actor uuid := (select auth.uid()); chat uuid; recipient uuid;
begin
  begin
    chat := split_part(p_topic, ':', 2)::uuid;
    recipient := split_part(p_topic, ':', 4)::uuid;
  exception when invalid_text_representation then return false;
  end;
  return actor = recipient and p_topic = private.participation_conversation_topic(chat, recipient)
    and private.profile_can_access_participation_conversation(chat, actor);
end;
$$;
create policy participation_pair_receive_broadcasts on realtime.messages for select to authenticated
using (realtime.messages.extension = 'broadcast'
  and private.profile_can_receive_participation_conversation_topic((select realtime.topic())));

create function private.signal_participation_conversation(p_chat_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare recipient uuid;
begin
  -- Address only immutable endpoints. Previously authorized delegate sockets
  -- never receive a new pair signal, even if Realtime cached their old grant.
  for recipient in select c.lower_profile_id from public.participation_conversations c where c.id = p_chat_id
    union all select c.upper_profile_id from public.participation_conversations c where c.id = p_chat_id
  loop
    perform realtime.send(jsonb_build_object('chat_id', p_chat_id), 'participation.conversation_changed',
      private.participation_conversation_topic(p_chat_id, recipient), true);
  end loop;
end;
$$;

create function private.signal_participation_request_change()
returns trigger language plpgsql security definer set search_path = '' as $$
declare pair_id uuid;
begin
  select a.conversation_id into pair_id from public.participation_conversation_requests a where a.request_id = new.id;
  if pair_id is not null then perform private.signal_participation_conversation(pair_id); end if;
  return new;
end;
$$;
create trigger project_join_requests_signal_pair after insert or update of status on public.project_join_requests
for each row execute function private.signal_participation_request_change();

create function private.signal_participation_message_change()
returns trigger language plpgsql security definer set search_path = '' as $$
declare pair_id uuid;
begin
  if tg_table_name = 'participation_conversation_messages' then pair_id := new.conversation_id;
  else select a.conversation_id into pair_id from public.participation_conversation_requests a where a.legacy_chat_id = new.chat_id;
  end if;
  perform private.signal_participation_conversation(pair_id);
  return new;
end;
$$;
create trigger participation_conversation_messages_signal after insert on public.participation_conversation_messages
for each row execute function private.signal_participation_message_change();
create trigger project_join_request_chat_messages_signal_pair after insert on public.project_join_request_chat_messages
for each row execute function private.signal_participation_message_change();

create function public.send_participation_conversation_message(p_expected_profile_id uuid, p_chat_id uuid, p_body text)
returns table (message_id uuid, chat_id uuid, sender_profile_id uuid, created_at timestamptz, body text)
language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := private.require_participation_identity(p_expected_profile_id);
  candidate record;
  message public.participation_conversation_messages%rowtype;
  canonical_body text := regexp_replace(coalesce(p_body, ''), '^[[:space:]]+|[[:space:]]+$', '', 'g');
  identifiers jsonb;
begin
  if not private.profile_can_access_participation_conversation(p_chat_id, actor) then
    raise exception using errcode = '42501', message = 'The participation-request chat is unavailable.';
  end if;
  if char_length(canonical_body) not between 1 and 4000 then
    raise exception using errcode = '22023', message = 'Conversation messages require 1 through 4,000 characters.';
  end if;
  select r.id, r.project_id, r.requester_profile_id into candidate
  from public.participation_conversation_requests a join public.project_join_requests r on r.id = a.request_id
  where a.conversation_id = p_chat_id and private.participation_request_allows_conversation_send(r.id)
  order by r.id limit 1;
  if not found then raise sqlstate 'PT409' using message = 'This conversation is read-only.'; end if;
  -- Use exactly the canonical request lock order: ordered requester/manager
  -- interaction locks, concrete Project, shared Project, request. Never hold a
  -- pair-row lock and then acquire a Project. Only ONE eligibility witness is
  -- locked: after a race, fail explicitly and let a fresh canonical read choose
  -- another request instead of taking another Project's locks out of order.
  perform private.lock_project_manager_interactions(candidate.project_id, candidate.requester_profile_id);
  perform 1 from public.project_join_requests r where r.id = candidate.id for update;
  if not private.participation_request_allows_conversation_send(candidate.id) then
    raise sqlstate 'PT409' using message = 'Conversation eligibility changed; refresh before sending.';
  end if;
  insert into public.participation_conversation_messages(conversation_id, sender_profile_id, body, created_at)
  values (p_chat_id, actor, canonical_body, clock_timestamp()) returning * into message;
  identifiers := jsonb_build_object('chat_id', p_chat_id, 'message_id', message.id, 'sender_profile_id', actor);
  insert into private.audit_events(action, actor_user_id, target_type, target_id, metadata, created_at)
  values ('participation.conversation_message_sent', actor, 'participation_conversation', p_chat_id, identifiers, message.created_at);
  insert into private.outbox_events(event_type, payload, created_at, available_at)
  values ('participation.conversation_message_sent', identifiers, message.created_at, message.created_at);
  return query select message.id, message.conversation_id, message.sender_profile_id, message.created_at, message.body;
end;
$$;

revoke all on function private.protect_participation_conversation_history(), private.associate_participation_conversation(),
  private.profile_can_access_participation_conversation(uuid, uuid), private.participation_request_allows_conversation_send(uuid),
  private.participation_conversation_feed(uuid), private.participation_conversation_topic(uuid, uuid),
  private.profile_can_receive_participation_conversation_topic(text), private.signal_participation_conversation(uuid),
  private.signal_participation_request_change(), private.signal_participation_message_change()
  from public, anon, authenticated, service_role;
revoke all on function public.list_own_participation_conversation_items(uuid, uuid, integer, timestamptz, text, uuid, boolean),
  public.get_own_participation_conversation_requests(uuid, uuid, uuid[]), public.get_own_participation_conversation(uuid, uuid),
  public.send_participation_conversation_message(uuid, uuid, text) from public, anon, authenticated, service_role;
grant execute on function public.list_own_participation_conversation_items(uuid, uuid, integer, timestamptz, text, uuid, boolean),
  public.get_own_participation_conversation_requests(uuid, uuid, uuid[]), public.get_own_participation_conversation(uuid, uuid),
  public.send_participation_conversation_message(uuid, uuid, text) to authenticated;
-- The RLS policy invokes this one strict predicate in the authenticated role.
-- Its implementation remains SECURITY DEFINER; the other helpers stay private.
grant execute on function private.profile_can_receive_participation_conversation_topic(text) to authenticated;

-- Explicit request-scoped old-client sends retain the caller-selected provenance;
-- current clients send on the pair itself. Legacy reads never return other requests.
create or replace function public.send_project_join_request_chat_message(
  p_expected_profile_id uuid,
  p_chat_id uuid,
  p_body text
)
returns table (
  message_id uuid,
  chat_id uuid,
  sender_profile_id uuid,
  created_at timestamptz,
  body text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_participation_identity(
    p_expected_profile_id
  );
  request_project_id uuid;
  request_record public.project_join_requests%rowtype;
  project_record record;
  canonical_body text := regexp_replace(
    coalesce(p_body, ''),
    '^[[:space:]]+|[[:space:]]+$',
    '',
    'g'
  );
  canonical_created_at timestamptz;
  inserted_message public.project_join_request_chat_messages%rowtype;
  identifier_payload jsonb;
  realtime_payload jsonb;
  recipient_profile_id uuid;
begin
  if char_length(canonical_body) < 1 then
    raise exception using
      errcode = '22023',
      message = 'A participation-request chat message cannot be empty.';
  end if;

  if char_length(canonical_body) > 4000 then
    raise exception using
      errcode = '22023',
      message = 'A participation-request chat message cannot exceed 4,000 characters.';
  end if;

  select request.project_id into request_project_id
  from public.project_join_request_chats as chat
  join public.project_join_requests as request on request.id = chat.request_id
  where chat.id = p_chat_id;

  if not found then
    raise exception using
      errcode = '42501',
      message = 'The participation-request chat is unavailable.';
  end if;

  if not private.profile_can_access_project_join_request_chat(p_chat_id, current_profile_id) then
    raise exception using errcode = '42501', message = 'The participation-request chat is unavailable.';
  end if;
  perform private.lock_project_manager_interactions(request_project_id,
    (select r.requester_profile_id from public.project_join_requests r
     join public.project_join_request_chats c on c.request_id = r.id where c.id = p_chat_id));
  select * into project_record from private.lock_project_for_participation(request_project_id, false);

  select request.* into request_record
  from public.project_join_request_chats as chat
  join public.project_join_requests as request on request.id = chat.request_id
  where chat.id = p_chat_id
  for update of request;

  if not found or (
    request_record.requester_profile_id <> current_profile_id
    and not private.profile_is_project_manager(
      request_record.project_id,
      current_profile_id
    )
  ) then
    raise exception using
      errcode = '42501',
      message = 'The participation-request chat is unavailable.';
  end if;

  if request_record.status <> 'pending' then
    raise sqlstate 'PT409'
      using message = 'The participation-request chat is read-only because the request is resolved.';
  end if;

  canonical_created_at := clock_timestamp();

  insert into public.project_join_request_chat_messages (
    chat_id,
    sender_profile_id,
    body,
    created_at
  )
  values (
    p_chat_id,
    current_profile_id,
    canonical_body,
    canonical_created_at
  )
  returning * into inserted_message;

  identifier_payload := jsonb_build_object(
    'chat_id', p_chat_id,
    'request_id', request_record.id,
    'project_id', request_record.project_id,
    'project_kind', project_record.project_kind,
    'message_id', inserted_message.id,
    'sender_profile_id', current_profile_id
  );

  insert into private.audit_events (
    action,
    actor_user_id,
    target_type,
    target_id,
    metadata,
    created_at
  )
  values (
    'project.join_request_chat_message_sent',
    current_profile_id,
    'project_join_request_chat',
    p_chat_id,
    identifier_payload,
    canonical_created_at
  );

  insert into private.outbox_events (
    event_type,
    payload,
    created_at,
    available_at
  )
  values (
    'project.join_request_chat_message_sent',
    identifier_payload,
    canonical_created_at,
    canonical_created_at
  );

  realtime_payload := jsonb_build_object(
    'chat_id', p_chat_id,
    'request_id', request_record.id,
    'message_id', inserted_message.id,
    'created_at', inserted_message.created_at
  );

  for recipient_profile_id in
    select request_record.requester_profile_id

    union

    select project_record.creator_profile_id

    order by 1
  loop
    perform realtime.send(
      realtime_payload,
      'project.join_request_chat_message_sent',
      private.project_join_request_chat_realtime_topic(
        p_chat_id,
        recipient_profile_id
      ),
      true
    );
  end loop;

  return query
  select
    inserted_message.id,
    inserted_message.chat_id,
    inserted_message.sender_profile_id,
    inserted_message.created_at,
    inserted_message.body;
end;
$$;

create or replace function private.list_own_scoped_message_chat_items_base(
  p_expected_profile_id uuid,
  p_scope text,
  p_limit integer,
  p_cursor_activity_at timestamptz default null,
  p_cursor_item_kind text default null,
  p_cursor_chat_id uuid default null
)
returns table (
  item_kind text,
  chat_id uuid,
  activity_at timestamptz,
  display_title text,
  viewer_role text,
  is_read_only boolean,
  last_visible_message_id uuid,
  last_visible_message_body text,
  last_visible_message_at timestamptz,
  last_visible_sender_profile_id uuid,
  last_visible_sender_display_name text,
  project_id uuid,
  project_kind text,
  resource_request_id uuid,
  resource_agreement_id uuid,
  resource_listing_id uuid,
  agreement_lifecycle text,
  coordination_closed_at timestamptz,
  project_request_id uuid,
  project_request_project_id uuid,
  project_request_project_kind text,
  project_request_project_title text,
  project_request_counterparty_profile_id uuid,
  project_request_counterparty_display_name text,
  project_request_status text,
  project_request_message text,
  project_request_resolved_at timestamptz,
  accepted_project_group_chat_id uuid
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_participation_identity(
    p_expected_profile_id
  );
  cursor_kind_order integer;
begin
  if p_scope is null or p_scope not in ('private', 'groups', 'all') then
    raise exception using
      errcode = '22023',
      message = 'The unified chat scope must be private, groups, or all.';
  end if;

  if p_limit is null or p_limit not between 1 and 50 then
    raise exception using
      errcode = '22023',
      message = 'The unified chat page size must be between 1 and 50.';
  end if;

  if num_nonnulls(
    p_cursor_activity_at,
    p_cursor_item_kind,
    p_cursor_chat_id
  ) not in (0, 3) then
    raise exception using
      errcode = '22023',
      message = 'All unified chat cursor values must be provided together.';
  end if;

  if p_cursor_item_kind is not null then
    cursor_kind_order := case p_cursor_item_kind
      when 'project_chat' then 0
      when 'resource_chat' then 1
      when 'project_request_chat' then 2
      else null
    end;

    if cursor_kind_order is null
      or (p_scope = 'private' and p_cursor_item_kind = 'project_chat')
      or (p_scope = 'groups' and p_cursor_item_kind <> 'project_chat') then
      raise exception using
        errcode = '22023',
        message = 'The unified chat cursor item kind is unsupported for this scope.';
    end if;
  end if;

  return query
  with accessible_projects as (
    select project.id
    from public.projects as project
    where project.creator_profile_id = current_profile_id

    union

    select delegate.project_id
    from public.project_delegates as delegate
    where delegate.delegate_profile_id = current_profile_id
      and delegate.revoked_at is null

    union

    select membership.project_id
    from public.project_memberships as membership
    where membership.participant_profile_id = current_profile_id
  ),
  chat_items as (
    select
      'project_chat'::text as resolved_item_kind,
      0 as item_kind_order,
      project_chat.id as resolved_chat_id,
      greatest(
        project_chat.activated_at,
        coalesce(latest_message.created_at, project_chat.activated_at),
        coalesce(latest_system_event.created_at, project_chat.activated_at)
      ) as resolved_activity_at,
      case project.project_kind
        when 'one_time' then proposal.title
        when 'recurring' then recurring.title
      end as resolved_display_title,
      case
        when project.creator_profile_id = current_profile_id then 'creator'
        when exists (
          select 1
          from public.project_delegates as delegate
          where delegate.project_id = project.id
            and delegate.delegate_profile_id = current_profile_id
            and delegate.revoked_at is null
        ) then 'delegate'
        when private.profile_has_current_project_membership(
          project.id,
          current_profile_id
        ) then 'current_member'
        else 'former_member'
      end as resolved_viewer_role,
      not private.profile_has_current_project_chat_entitlement(
        project.id,
        current_profile_id
      ) as resolved_is_read_only,
      latest_message.id as resolved_last_visible_message_id,
      latest_message.body as resolved_last_visible_message_body,
      latest_message.created_at as resolved_last_visible_message_at,
      latest_message.sender_profile_id
        as resolved_last_visible_sender_profile_id,
      latest_message.sender_display_name
        as resolved_last_visible_sender_display_name,
      project.id as resolved_project_id,
      project.project_kind as resolved_project_kind,
      null::uuid as resolved_resource_request_id,
      null::uuid as resolved_resource_agreement_id,
      null::uuid as resolved_resource_listing_id,
      null::text as resolved_agreement_lifecycle,
      null::timestamptz as resolved_coordination_closed_at,
      null::uuid as resolved_project_request_id,
      null::uuid as resolved_project_request_project_id,
      null::text as resolved_project_request_project_kind,
      null::text as resolved_project_request_project_title,
      null::uuid as resolved_project_request_counterparty_profile_id,
      null::text as resolved_project_request_counterparty_display_name,
      null::text as resolved_project_request_status,
      null::text as resolved_project_request_message,
      null::timestamptz as resolved_project_request_resolved_at,
      null::uuid as resolved_accepted_project_group_chat_id
    from accessible_projects as accessible
    join public.projects as project on project.id = accessible.id
    join public.project_group_chats as project_chat
      on project_chat.project_id = project.id
    left join public.proposals as proposal
      on proposal.id = project.id
      and project.project_kind = 'one_time'
    left join public.recurring_activities as recurring
      on recurring.id = project.id
      and project.project_kind = 'recurring'
    left join lateral (
      select
        message.id,
        message.body,
        message.created_at,
        message.sender_profile_id,
        sender.display_name as sender_display_name
      from public.project_chat_messages as message
      join public.profiles as sender on sender.id = message.sender_profile_id
      where message.chat_id = project_chat.id
        and private.profile_can_read_project_chat_message(
          project.id,
          current_profile_id,
          message.created_at
        )
      order by message.created_at desc, message.id desc
      limit 1
    ) as latest_message on true
    left join lateral (
      select system_event.created_at
      from public.project_chat_system_events as system_event
      where system_event.chat_id = project_chat.id
        and private.profile_can_read_project_chat_message(
          project.id,
          current_profile_id,
          system_event.created_at
        )
      order by system_event.created_at desc, system_event.id desc
      limit 1
    ) as latest_system_event on true
    where p_scope in ('groups', 'all')

    union all

    select
      'resource_chat'::text,
      1,
      resource_chat.id,
      greatest(
        resource_chat.activated_at,
        coalesce(latest_message.created_at, resource_chat.activated_at),
        coalesce(latest_event.created_at, resource_chat.activated_at)
      ),
      listing.title,
      case
        when listing.owner_profile_id = current_profile_id then 'owner'
        else 'requester'
      end,
      not (
        resource_request.status = 'accepted'
        and resource_request.coordination_closed_at is null
        and agreement.lifecycle_state not in ('completed', 'cancelled')
      ),
      latest_message.id,
      latest_message.body,
      latest_message.created_at,
      latest_message.sender_profile_id,
      latest_message.sender_display_name,
      null::uuid,
      null::text,
      resource_request.id,
      agreement.id,
      listing.id,
      agreement.lifecycle_state,
      resource_request.coordination_closed_at,
      null::uuid,
      null::uuid,
      null::text,
      null::text,
      null::uuid,
      null::text,
      null::text,
      null::text,
      null::timestamptz,
      null::uuid
    from public.resource_request_chats as resource_chat
    join public.resource_listing_requests as resource_request
      on resource_request.id = resource_chat.request_id
    join public.resource_listings as listing
      on listing.id = resource_request.listing_id
    join public.resource_exchange_agreements as agreement
      on agreement.request_id = resource_request.id
    left join lateral (
      select
        message.id,
        message.body,
        message.created_at,
        message.sender_profile_id,
        sender.display_name as sender_display_name
      from public.resource_request_chat_messages as message
      join public.profiles as sender on sender.id = message.sender_profile_id
      where message.chat_id = resource_chat.id
      order by message.created_at desc, message.id desc
      limit 1
    ) as latest_message on true
    left join lateral (
      select agreement_event.created_at
      from public.resource_exchange_agreement_events as agreement_event
      where agreement_event.agreement_id = agreement.id
      order by agreement_event.created_at desc, agreement_event.id desc
      limit 1
    ) as latest_event on true
    where p_scope in ('private', 'all')
      and current_profile_id in (
        listing.owner_profile_id,
        resource_request.requester_profile_id
      )

    union all

    select
      'project_request_chat'::text, 2, pair.id,
      greatest(pair.activated_at, activity.last_at, coalesce(latest_message.created_at, pair.activated_at)),
      case when current_profile_id = request.requester_profile_id then creator.display_name else requester.display_name end,
      case when current_profile_id = request.requester_profile_id then 'requester' else 'creator' end,
      not exists (select 1 from public.participation_conversation_requests eligible
        where eligible.conversation_id = pair.id and private.participation_request_allows_conversation_send(eligible.request_id)),
      case when latest_message.created_at >= request.created_at then latest_message.message_id end,
      case when latest_message.created_at >= request.created_at then latest_message.body end,
      case when latest_message.created_at >= request.created_at then latest_message.created_at end,
      case when latest_message.created_at >= request.created_at then latest_message.sender_profile_id end,
      case when latest_message.created_at >= request.created_at then latest_message.sender_display_name end,
      null::uuid, null::text, null::uuid, null::uuid, null::uuid, null::text, null::timestamptz,
      request.id, project.id, project.project_kind, coalesce(proposal.title, recurring.title),
      case when current_profile_id = pair.lower_profile_id then pair.upper_profile_id else pair.lower_profile_id end,
      case when current_profile_id = request.requester_profile_id then creator.display_name else requester.display_name end,
      request.status, request.request_message, request.resolved_at,
      case when request.status = 'accepted' then group_chat.id end
    from public.participation_conversations pair
    join lateral (
      select r.* from public.participation_conversation_requests a
      join public.project_join_requests r on r.id = a.request_id
      where a.conversation_id = pair.id order by r.created_at desc, r.id desc limit 1
    ) request on true
    join public.projects project on project.id = request.project_id
    join public.profiles requester on requester.id = request.requester_profile_id
    join public.profiles creator on creator.id = project.creator_profile_id
    left join public.proposals proposal on proposal.id = project.id and project.project_kind = 'one_time'
    left join public.recurring_activities recurring on recurring.id = project.id and project.project_kind = 'recurring'
    left join public.project_group_chats group_chat on group_chat.project_id = project.id
    join lateral (
      select max(greatest(r.created_at, coalesce(r.resolved_at, r.created_at))) as last_at
      from public.participation_conversation_requests a join public.project_join_requests r on r.id = a.request_id
      where a.conversation_id = pair.id
    ) activity on true
    left join lateral (
      select f.* from private.participation_conversation_feed(pair.id) f
      where f.item_kind in ('message', 'legacy_message')
      order by f.created_at desc, case f.item_kind when 'legacy_message' then 1 else 2 end desc, f.item_id desc limit 1
    ) latest_message on true
    where p_scope in ('private', 'all') and current_profile_id in (pair.lower_profile_id, pair.upper_profile_id)

  )
  select
    item.resolved_item_kind,
    item.resolved_chat_id,
    item.resolved_activity_at,
    item.resolved_display_title,
    item.resolved_viewer_role,
    item.resolved_is_read_only,
    item.resolved_last_visible_message_id,
    item.resolved_last_visible_message_body,
    item.resolved_last_visible_message_at,
    item.resolved_last_visible_sender_profile_id,
    item.resolved_last_visible_sender_display_name,
    item.resolved_project_id,
    item.resolved_project_kind,
    item.resolved_resource_request_id,
    item.resolved_resource_agreement_id,
    item.resolved_resource_listing_id,
    item.resolved_agreement_lifecycle,
    item.resolved_coordination_closed_at,
    item.resolved_project_request_id,
    item.resolved_project_request_project_id,
    item.resolved_project_request_project_kind,
    item.resolved_project_request_project_title,
    item.resolved_project_request_counterparty_profile_id,
    item.resolved_project_request_counterparty_display_name,
    item.resolved_project_request_status,
    item.resolved_project_request_message,
    item.resolved_project_request_resolved_at,
    item.resolved_accepted_project_group_chat_id
  from chat_items as item
  where p_cursor_activity_at is null
    or (
      item.resolved_activity_at,
      item.item_kind_order,
      item.resolved_chat_id
    ) < (
      p_cursor_activity_at,
      cursor_kind_order,
      p_cursor_chat_id
    )
  order by
    item.resolved_activity_at desc,
    item.item_kind_order desc,
    item.resolved_chat_id desc
  limit p_limit;
end;
$$;

create function public.list_own_scoped_conversation_items(
  p_expected_profile_id uuid, p_scope text, p_limit integer,
  p_cursor_activity_at timestamptz default null, p_cursor_item_kind text default null,
  p_cursor_chat_id uuid default null
)
returns table (
  item_kind text,
  chat_id uuid,
  activity_at timestamptz,
  display_title text,
  viewer_role text,
  is_read_only boolean,
  last_visible_message_id uuid,
  last_visible_message_body text,
  last_visible_message_at timestamptz,
  last_visible_sender_profile_id uuid,
  last_visible_sender_display_name text,
  project_id uuid,
  project_kind text,
  resource_request_id uuid,
  resource_agreement_id uuid,
  resource_listing_id uuid,
  resource_counterparty_profile_id uuid,
  resource_counterparty_display_name text,
  agreement_lifecycle text,
  coordination_closed_at timestamptz,
  project_request_id uuid,
  project_request_project_id uuid,
  project_request_project_kind text,
  project_request_project_title text,
  project_request_counterparty_profile_id uuid,
  project_request_counterparty_display_name text,
  project_request_status text,
  project_request_message text,
  project_request_resolved_at timestamptz,
  accepted_project_group_chat_id uuid,
  pending_count integer
)
language sql stable security definer set search_path = '' as $$
  select item.*, case when item.item_kind = 'project_request_chat' then
    (select count(*)::integer from public.participation_conversation_requests a
      join public.project_join_requests r on r.id = a.request_id
      where a.conversation_id = item.chat_id and r.status = 'pending') end
  from public.list_own_scoped_message_chat_items(p_expected_profile_id, p_scope, p_limit,
    p_cursor_activity_at, p_cursor_item_kind, p_cursor_chat_id) item;
$$;
revoke all on function public.list_own_scoped_conversation_items(uuid, text, integer, timestamptz, text, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.list_own_scoped_conversation_items(uuid, text, integer, timestamptz, text, uuid) to authenticated;
comment on function public.list_own_scoped_conversation_items(uuid, text, integer, timestamptz, text, uuid) is
  'MSG01 grouped-before-pagination pair rows, with canonical pending totals. Representative request fields are navigation context, never a conversation-wide role or send witness.';

create function private.validate_participation_conversation_reference()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_table_name = 'participation_conversation_requests' then
    if not exists (
      select 1 from public.project_join_requests r join public.projects p on p.id=r.project_id
      join public.project_join_request_chats legacy on legacy.request_id=r.id
      join public.participation_conversations pair on pair.id=new.conversation_id
      where r.id=new.request_id and legacy.id=new.legacy_chat_id
        and pair.lower_profile_id=least(r.requester_profile_id,p.creator_profile_id)
        and pair.upper_profile_id=greatest(r.requester_profile_id,p.creator_profile_id)
    ) then raise exception using errcode='22023',message='Invalid canonical request association.'; end if;
  elsif not private.profile_can_access_participation_conversation(new.conversation_id,new.sender_profile_id) then
    raise exception using errcode='42501',message='The participation-request chat is unavailable.';
  end if;
  return new;
end;
$$;
create trigger participation_conversation_requests_validate before insert on public.participation_conversation_requests
for each row execute function private.validate_participation_conversation_reference();
create trigger participation_conversation_messages_validate before insert on public.participation_conversation_messages
for each row execute function private.validate_participation_conversation_reference();

create function private.signal_delegate_participation_conversations()
returns trigger language plpgsql security definer set search_path = '' as $$
declare pair_id uuid;
begin
  for pair_id in select distinct a.conversation_id from public.participation_conversation_requests a
    join public.project_join_requests r on r.id=a.request_id where r.project_id=new.project_id and r.status='pending'
  loop perform private.signal_participation_conversation(pair_id); end loop;
  return new;
end;
$$;
create trigger project_delegates_signal_participation_pairs after insert or update of revoked_at, authority_role on public.project_delegates
for each row execute function private.signal_delegate_participation_conversations();
revoke all on function private.validate_participation_conversation_reference(),private.signal_delegate_participation_conversations()
from public,anon,authenticated,service_role;
comment on function private.profile_can_access_project_join_request_chat(uuid,uuid) is
  'MSG01 requester/immutable Creator only, including retained request-scoped reads and subscriptions. Ordinary delegate authority grants request management, never personal history.';
