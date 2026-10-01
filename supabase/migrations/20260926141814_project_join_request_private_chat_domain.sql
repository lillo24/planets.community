create table public.project_join_request_chats (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null
    constraint project_join_request_chats_request_id_fkey
      references public.project_join_requests (id) on delete restrict,
  activated_at timestamptz not null,
  constraint project_join_request_chats_request_id_key unique (request_id)
);

comment on table public.project_join_request_chats is
  'Permanent private requester-to-creator conversation anchor for one Project participation-request episode.';
comment on column public.project_join_request_chats.activated_at is
  'Canonical request creation time; resolving the request never deletes or replaces its conversation anchor.';

alter table public.project_join_request_chats enable row level security;
revoke all privileges on table public.project_join_request_chats
  from public, anon, authenticated, service_role;

create function private.validate_project_join_request_chat_anchor()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  request_record public.project_join_requests%rowtype;
begin
  if tg_op = 'UPDATE' then
    raise exception using
      errcode = '55000',
      message = 'Project participation-request chat anchors are immutable.';
  end if;

  select * into request_record
  from public.project_join_requests
  where id = new.request_id;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'The participation request does not exist.';
  end if;

  if new.activated_at is distinct from request_record.created_at then
    raise exception using
      errcode = '22023',
      message = 'Participation-request chat activation must equal request creation.';
  end if;

  return new;
end;
$$;

create trigger project_join_request_chats_validate_anchor
before insert or update on public.project_join_request_chats
for each row execute function
  private.validate_project_join_request_chat_anchor();

insert into public.project_join_request_chats (request_id, activated_at)
select request.id, request.created_at
from public.project_join_requests as request
order by request.id;

create function private.create_project_join_request_chat()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.project_join_request_chats (request_id, activated_at)
  values (new.id, new.created_at);

  return new;
end;
$$;

create trigger project_join_requests_create_private_chat
after insert on public.project_join_requests
for each row execute function private.create_project_join_request_chat();

create table public.project_join_request_chat_messages (
  id uuid primary key default gen_random_uuid(),
  chat_id uuid not null
    constraint project_join_request_chat_messages_chat_id_fkey
      references public.project_join_request_chats (id) on delete restrict,
  sender_profile_id uuid not null
    constraint project_join_request_chat_messages_sender_profile_id_fkey
      references public.profiles (id) on delete restrict,
  body text not null,
  created_at timestamptz not null default statement_timestamp(),
  constraint project_join_request_chat_messages_body_canonical check (
    body = regexp_replace(
      body,
      '^[[:space:]]+|[[:space:]]+$',
      '',
      'g'
    )
    and char_length(body) between 1 and 4000
  )
);

comment on table public.project_join_request_chat_messages is
  'Immutable human-authored plain-text messages for one private Project participation-request conversation.';
comment on column public.project_join_request_chat_messages.body is
  'Canonical plain text trimmed of surrounding whitespace and bounded to 4,000 Unicode characters.';
comment on column public.project_join_request_chat_messages.created_at is
  'Server-owned creation time assigned after the Project and request serialization locks are acquired.';

create index project_join_request_chat_messages_chat_created_idx
  on public.project_join_request_chat_messages (
    chat_id,
    created_at desc,
    id desc
  );
create index project_join_request_chat_messages_sender_created_idx
  on public.project_join_request_chat_messages (
    sender_profile_id,
    created_at desc,
    id desc
  );

alter table public.project_join_request_chat_messages enable row level security;
revoke all privileges on table public.project_join_request_chat_messages
  from public, anon, authenticated, service_role;

create function private.protect_project_join_request_chat_message_immutability()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  raise exception using
    errcode = '55000',
    message = 'Project participation-request chat messages are immutable.';
end;
$$;

create trigger project_join_request_chat_messages_immutable
before update or delete on public.project_join_request_chat_messages
for each row execute function
  private.protect_project_join_request_chat_message_immutability();

create function private.project_join_request_chat_realtime_topic(
  p_chat_id uuid,
  p_profile_id uuid
)
returns text
language sql
immutable
security definer
set search_path = ''
as $$
  select format(
    'project-request-chat:%s:profile:%s',
    p_chat_id::text,
    p_profile_id::text
  );
$$;

create function private.profile_can_receive_project_join_request_chat_topic(
  p_topic text
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := (select auth.uid());
  topic_chat_id uuid;
  topic_profile_id uuid;
begin
  if current_profile_id is null or p_topic is null then
    return false;
  end if;

  begin
    topic_chat_id := split_part(p_topic, ':', 2)::uuid;
    topic_profile_id := split_part(p_topic, ':', 4)::uuid;
  exception
    when invalid_text_representation then
      return false;
  end;

  if p_topic <> private.project_join_request_chat_realtime_topic(
    topic_chat_id,
    topic_profile_id
  ) or topic_profile_id <> current_profile_id then
    return false;
  end if;

  return exists (
    select 1
    from public.project_join_request_chats as chat
    join public.project_join_requests as request
      on request.id = chat.request_id
    join public.projects as project on project.id = request.project_id
    where chat.id = topic_chat_id
      and current_profile_id in (
        request.requester_profile_id,
        project.creator_profile_id
      )
  );
end;
$$;

create policy project_join_request_chat_counterparties_receive_broadcasts
on realtime.messages
for select
to authenticated
using (
  realtime.messages.extension = 'broadcast'
  and private.profile_can_receive_project_join_request_chat_topic(
    (select realtime.topic())
  )
);

create function public.send_project_join_request_chat_message(
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

  -- Request resolution uses this same concrete-Project, shared-Project, then
  -- request-row order. A waiting send therefore evaluates the committed status.
  select * into project_record
  from private.lock_project_for_participation(request_project_id, false);

  select request.* into request_record
  from public.project_join_request_chats as chat
  join public.project_join_requests as request on request.id = chat.request_id
  where chat.id = p_chat_id
  for update of request;

  if not found or current_profile_id not in (
    request_record.requester_profile_id,
    project_record.creator_profile_id
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
    select profile_id
    from (
      values
        (project_record.creator_profile_id),
        (request_record.requester_profile_id)
    ) as counterparty(profile_id)
    order by profile_id
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

create function public.get_own_project_join_request_chat(
  p_expected_profile_id uuid,
  p_request_id uuid
)
returns table (
  chat_id uuid,
  request_id uuid,
  project_id uuid,
  project_kind text,
  project_title text,
  viewer_role text,
  requester_profile_id uuid,
  requester_display_name text,
  creator_profile_id uuid,
  creator_display_name text,
  request_status text,
  request_message text,
  request_created_at timestamptz,
  resolved_at timestamptz,
  activated_at timestamptz,
  is_read_only boolean,
  has_send_entitlement boolean,
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
begin
  if p_request_id is null or not exists (
    select 1
    from public.project_join_requests as request
    join public.projects as project on project.id = request.project_id
    where request.id = p_request_id
      and current_profile_id in (
        request.requester_profile_id,
        project.creator_profile_id
      )
  ) then
    raise exception using
      errcode = '42501',
      message = 'The participation-request chat is unavailable.';
  end if;

  return query
  select
    chat.id,
    request.id,
    project.id,
    project.project_kind,
    case project.project_kind
      when 'one_time' then proposal.title
      when 'recurring' then recurring.title
    end,
    case
      when current_profile_id = request.requester_profile_id then 'requester'
      else 'creator'
    end,
    request.requester_profile_id,
    requester.display_name,
    project.creator_profile_id,
    creator.display_name,
    request.status,
    request.request_message,
    request.created_at,
    request.resolved_at,
    chat.activated_at,
    request.status <> 'pending',
    request.status = 'pending',
    case when request.status = 'accepted' then group_chat.id end
  from public.project_join_requests as request
  join public.project_join_request_chats as chat
    on chat.request_id = request.id
  join public.projects as project on project.id = request.project_id
  join public.profiles as requester
    on requester.id = request.requester_profile_id
  join public.profiles as creator on creator.id = project.creator_profile_id
  left join public.proposals as proposal
    on proposal.id = project.id
    and project.project_kind = 'one_time'
  left join public.recurring_activities as recurring
    on recurring.id = project.id
    and project.project_kind = 'recurring'
  left join public.project_group_chats as group_chat
    on group_chat.project_id = project.id
  where request.id = p_request_id;
end;
$$;

create function public.list_own_project_join_request_chat_items(
  p_expected_profile_id uuid,
  p_chat_id uuid,
  p_limit integer,
  p_before_created_at timestamptz default null,
  p_before_item_kind text default null,
  p_before_item_id uuid default null
)
returns table (
  item_kind text,
  item_id uuid,
  chat_id uuid,
  request_id uuid,
  message_id uuid,
  project_id uuid,
  project_kind text,
  project_title text,
  request_status text,
  request_message text,
  requester_profile_id uuid,
  requester_display_name text,
  sender_profile_id uuid,
  sender_display_name text,
  body text,
  created_at timestamptz
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
  if p_limit is null or p_limit not between 1 and 50 then
    raise exception using
      errcode = '22023',
      message = 'The participation-request chat page size must be between 1 and 50.';
  end if;

  if num_nonnulls(
    p_before_created_at,
    p_before_item_kind,
    p_before_item_id
  ) not in (0, 3) then
    raise exception using
      errcode = '22023',
      message = 'All participation-request chat cursor values must be provided together.';
  end if;

  if p_before_item_kind is not null then
    cursor_kind_order := case p_before_item_kind
      when 'request' then 0
      when 'message' then 1
      else null
    end;

    if cursor_kind_order is null then
      raise exception using
        errcode = '22023',
        message = 'The participation-request chat cursor item kind is unsupported.';
    end if;
  end if;

  if not exists (
    select 1
    from public.project_join_request_chats as chat
    join public.project_join_requests as request on request.id = chat.request_id
    join public.projects as project on project.id = request.project_id
    where chat.id = p_chat_id
      and current_profile_id in (
        request.requester_profile_id,
        project.creator_profile_id
      )
  ) then
    raise exception using
      errcode = '42501',
      message = 'The participation-request chat is unavailable.';
  end if;

  return query
  with authorized_items as (
    select
      'request'::text as resolved_item_kind,
      0 as kind_order,
      request.id as resolved_item_id,
      chat.id as resolved_chat_id,
      request.id as resolved_request_id,
      null::uuid as resolved_message_id,
      project.id as resolved_project_id,
      project.project_kind as resolved_project_kind,
      case project.project_kind
        when 'one_time' then proposal.title
        when 'recurring' then recurring.title
      end as resolved_project_title,
      request.status as resolved_request_status,
      request.request_message as resolved_request_message,
      request.requester_profile_id as resolved_requester_profile_id,
      requester.display_name as resolved_requester_display_name,
      null::uuid as resolved_sender_profile_id,
      null::text as resolved_sender_display_name,
      null::text as resolved_body,
      request.created_at as resolved_created_at
    from public.project_join_request_chats as chat
    join public.project_join_requests as request on request.id = chat.request_id
    join public.projects as project on project.id = request.project_id
    join public.profiles as requester
      on requester.id = request.requester_profile_id
    left join public.proposals as proposal
      on proposal.id = project.id
      and project.project_kind = 'one_time'
    left join public.recurring_activities as recurring
      on recurring.id = project.id
      and project.project_kind = 'recurring'
    where chat.id = p_chat_id

    union all

    select
      'message'::text,
      1,
      message.id,
      message.chat_id,
      chat.request_id,
      message.id,
      null::uuid,
      null::text,
      null::text,
      null::text,
      null::text,
      null::uuid,
      null::text,
      message.sender_profile_id,
      sender.display_name,
      message.body,
      message.created_at
    from public.project_join_request_chat_messages as message
    join public.project_join_request_chats as chat on chat.id = message.chat_id
    join public.profiles as sender on sender.id = message.sender_profile_id
    where message.chat_id = p_chat_id
  )
  select
    item.resolved_item_kind,
    item.resolved_item_id,
    item.resolved_chat_id,
    item.resolved_request_id,
    item.resolved_message_id,
    item.resolved_project_id,
    item.resolved_project_kind,
    item.resolved_project_title,
    item.resolved_request_status,
    item.resolved_request_message,
    item.resolved_requester_profile_id,
    item.resolved_requester_display_name,
    item.resolved_sender_profile_id,
    item.resolved_sender_display_name,
    item.resolved_body,
    item.resolved_created_at
  from authorized_items as item
  where p_before_created_at is null
    or (
      item.resolved_created_at,
      item.kind_order,
      item.resolved_item_id
    ) < (
      p_before_created_at,
      cursor_kind_order,
      p_before_item_id
    )
  order by
    item.resolved_created_at desc,
    item.kind_order desc,
    item.resolved_item_id desc
  limit p_limit;
end;
$$;

comment on function private.project_join_request_chat_realtime_topic(uuid, uuid) is
  'Builds the canonical private participation-request chat topic for one exact counterparty profile.';
comment on function private.profile_can_receive_project_join_request_chat_topic(text) is
  'Strictly parses a private participation-request chat topic and authorizes only the episode requester or Project creator.';
comment on function public.send_project_join_request_chat_message(uuid, uuid, text) is
  'Serializes with participation transitions, persists one canonical human message while the request is pending, and emits identifier-only durable and Realtime events.';
comment on function public.get_own_project_join_request_chat(uuid, uuid) is
  'Returns the exact counterparty-authorized private conversation for one participation-request episode, including current read-only/send entitlement and any accepted Project group chat.';
comment on function public.list_own_project_join_request_chat_items(uuid, uuid, integer, timestamptz, text, uuid) is
  'Returns the canonical structured Request item plus human messages using a complete newest-first discriminator-aware keyset cursor.';
comment on function public.request_to_join_project(uuid, uuid, text, uuid[], uuid[]) is
  'Atomically creates one private pending join request, its permanent private chat anchor, and optional canonical Proposal-skill and open Project-resource selections; trailing defaults preserve earlier callers.';

revoke all privileges on function private.validate_project_join_request_chat_anchor()
  from public, anon, authenticated, service_role;
revoke all privileges on function private.create_project_join_request_chat()
  from public, anon, authenticated, service_role;
revoke all privileges on function private.protect_project_join_request_chat_message_immutability()
  from public, anon, authenticated, service_role;
revoke all privileges on function private.project_join_request_chat_realtime_topic(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function private.profile_can_receive_project_join_request_chat_topic(text)
  from public, anon, authenticated, service_role;

grant execute on function private.profile_can_receive_project_join_request_chat_topic(text)
  to authenticated;

revoke all privileges on function public.send_project_join_request_chat_message(uuid, uuid, text)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.get_own_project_join_request_chat(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.list_own_project_join_request_chat_items(uuid, uuid, integer, timestamptz, text, uuid)
  from public, anon, authenticated, service_role;

grant execute on function public.send_project_join_request_chat_message(uuid, uuid, text)
  to authenticated;
grant execute on function public.get_own_project_join_request_chat(uuid, uuid)
  to authenticated;
grant execute on function public.list_own_project_join_request_chat_items(uuid, uuid, integer, timestamptz, text, uuid)
  to authenticated;
