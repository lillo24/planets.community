create table public.project_chat_messages (
  id uuid primary key default gen_random_uuid(),
  chat_id uuid not null
    constraint project_chat_messages_chat_id_fkey
      references public.project_group_chats (id) on delete restrict,
  sender_profile_id uuid not null
    constraint project_chat_messages_sender_profile_id_fkey
      references public.profiles (id) on delete restrict,
  body text not null,
  created_at timestamptz not null default statement_timestamp(),
  constraint project_chat_messages_body_canonical check (
    body = regexp_replace(
      body,
      '^[[:space:]]+|[[:space:]]+$',
      '',
      'g'
    )
    and char_length(body) between 1 and 4000
  )
);

comment on table public.project_chat_messages is
  'Immutable, server-readable plain-text messages for the authenticated Project-chat MVP; PostgreSQL is the durable source of truth.';
comment on column public.project_chat_messages.body is
  'Canonical plain text trimmed of leading/trailing whitespace and bounded to 4,000 Unicode characters; this is not E2EE ciphertext.';
comment on column public.project_chat_messages.created_at is
  'Server-owned creation time assigned after the Project participation lock is acquired by the send RPC.';

create index project_chat_messages_chat_created_idx
  on public.project_chat_messages (chat_id, created_at desc, id desc);
create index project_chat_messages_sender_created_idx
  on public.project_chat_messages (
    sender_profile_id,
    created_at desc,
    id desc
  );

comment on index public.project_chat_messages_chat_created_idx is
  'Supports stable newest-first keyset history and last-visible-message lookup per chat.';
comment on index public.project_chat_messages_sender_created_idx is
  'Indexes the sender foreign key and supports future sender-scoped operational lookup without exposing a client API.';

alter table public.project_chat_messages enable row level security;
revoke all privileges on table public.project_chat_messages
  from public, anon, authenticated, service_role;

create function private.protect_project_chat_message_immutability()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  raise exception using
    errcode = '55000',
    message = 'Project chat messages are immutable.';
end;
$$;

create trigger project_chat_messages_immutable
before update or delete on public.project_chat_messages
for each row execute function private.protect_project_chat_message_immutability();

create function private.latest_project_membership_end(
  p_project_id uuid,
  p_profile_id uuid
)
returns timestamptz
language sql
stable
security definer
set search_path = ''
as $$
  select max(coalesce(membership.left_at, membership.removed_at))
  from public.project_memberships as membership
  where membership.project_id = p_project_id
    and membership.participant_profile_id = p_profile_id
    and coalesce(membership.left_at, membership.removed_at) is not null;
$$;

create function private.profile_can_read_project_chat_message(
  p_project_id uuid,
  p_profile_id uuid,
  p_message_created_at timestamptz
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    p_project_id is not null
    and p_profile_id is not null
    and p_message_created_at is not null
    and (
      private.profile_is_project_creator(p_project_id, p_profile_id)
      or private.profile_has_current_project_membership(
        p_project_id,
        p_profile_id
      )
      or p_message_created_at <= private.latest_project_membership_end(
        p_project_id,
        p_profile_id
      )
    );
$$;

create function private.require_complete_project_chat_profile(
  p_expected_profile_id uuid
)
returns uuid
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
  if not exists (
    select 1
    from public.profiles as profile
    where profile.id = current_profile_id
      and profile.display_name is not null
  ) then
    raise exception using
      errcode = '55000',
      message = 'A complete profile is required to send Project chat messages.';
  end if;

  return current_profile_id;
end;
$$;

create function private.project_chat_realtime_topic(
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
    'project-chat:%s:profile:%s',
    p_chat_id::text,
    p_profile_id::text
  );
$$;

create function private.profile_can_receive_project_chat_realtime_topic(
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

  if p_topic <> private.project_chat_realtime_topic(
    topic_chat_id,
    topic_profile_id
  ) or topic_profile_id <> current_profile_id then
    return false;
  end if;

  return exists (
    select 1
    from public.project_group_chats as chat
    where chat.id = topic_chat_id
      and private.profile_has_current_project_chat_entitlement(
        chat.project_id,
        current_profile_id
      )
  );
end;
$$;

create policy project_chat_current_profiles_receive_broadcasts
on realtime.messages
for select
to authenticated
using (
  realtime.messages.extension = 'broadcast'
  and private.profile_can_receive_project_chat_realtime_topic(
    (select realtime.topic())
  )
);

create or replace function public.leave_project(
  p_expected_participant_profile_id uuid,
  p_membership_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_participation_identity(
    p_expected_participant_profile_id
  );
  membership_record public.project_memberships%rowtype;
  project_record record;
  transition_time timestamptz;
begin
  select * into membership_record
  from public.project_memberships as membership
  where membership.id = p_membership_id;

  if not found then
    raise exception using errcode = 'P0002', message = 'The membership does not exist.';
  end if;

  select * into project_record
  from private.lock_project_for_participation(membership_record.project_id, false);

  select * into membership_record
  from public.project_memberships as membership
  where membership.id = p_membership_id
  for update;

  if membership_record.participant_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'Only the current participant can leave this membership.';
  end if;

  if membership_record.left_at is not null or membership_record.removed_at is not null then
    raise exception using
      errcode = '55000',
      message = 'Only a current project membership can be left.';
  end if;

  -- Take the canonical boundary only after the shared Project lock. A send that
  -- serialized first is therefore visible to this former member; a later send is denied.
  transition_time := clock_timestamp();

  update public.project_memberships
  set left_at = transition_time
  where id = membership_record.id;

  perform private.record_project_participation_event(
    'project.participant_left',
    current_profile_id,
    membership_record.project_id,
    jsonb_build_object(
      'project_kind', project_record.project_kind,
      'membership_id', membership_record.id,
      'participant_profile_id', current_profile_id,
      'status', 'left'
    )
  );

  return membership_record.id;
end;
$$;

create or replace function public.remove_project_member(
  p_expected_creator_profile_id uuid,
  p_membership_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_participation_identity(
    p_expected_creator_profile_id
  );
  membership_record public.project_memberships%rowtype;
  project_record record;
  transition_time timestamptz;
begin
  select * into membership_record
  from public.project_memberships as membership
  where membership.id = p_membership_id;

  if not found then
    raise exception using errcode = 'P0002', message = 'The membership does not exist.';
  end if;

  select * into project_record
  from private.lock_project_for_participation(membership_record.project_id, false);

  select * into membership_record
  from public.project_memberships as membership
  where membership.id = p_membership_id
  for update;

  if project_record.creator_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'Only the project creator can remove a participant.';
  end if;

  if membership_record.left_at is not null or membership_record.removed_at is not null then
    raise exception using
      errcode = '55000',
      message = 'Only a current project membership can be removed.';
  end if;

  -- Match leave/send serialization: the Project lock orders the transition and
  -- this clock reading records that order for the historical read frontier.
  transition_time := clock_timestamp();

  update public.project_memberships
  set
    removed_at = transition_time,
    removed_by_profile_id = current_profile_id
  where id = membership_record.id;

  perform private.record_project_participation_event(
    'project.participant_removed',
    current_profile_id,
    membership_record.project_id,
    jsonb_build_object(
      'project_kind', project_record.project_kind,
      'membership_id', membership_record.id,
      'participant_profile_id', membership_record.participant_profile_id,
      'status', 'removed'
    )
  );

  return membership_record.id;
end;
$$;

create function public.send_project_chat_message(
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
  current_profile_id uuid := private.require_complete_project_chat_profile(
    p_expected_profile_id
  );
  chat_record record;
  project_record record;
  canonical_body text := regexp_replace(
    coalesce(p_body, ''),
    '^[[:space:]]+|[[:space:]]+$',
    '',
    'g'
  );
  canonical_created_at timestamptz;
  inserted_message public.project_chat_messages%rowtype;
  recipient_profile_id uuid;
begin
  if char_length(canonical_body) < 1 then
    raise exception using
      errcode = '22023',
      message = 'A Project chat message cannot be empty.';
  end if;

  if char_length(canonical_body) > 4000 then
    raise exception using
      errcode = '22023',
      message = 'A Project chat message cannot exceed 4,000 characters.';
  end if;

  select chat.id, chat.project_id
  into chat_record
  from public.project_group_chats as chat
  where chat.id = p_chat_id;

  if not found then
    raise exception using
      errcode = '42501',
      message = 'The project group chat is unavailable for sending.';
  end if;

  select * into project_record
  from private.lock_project_for_participation(chat_record.project_id, false);

  if not private.profile_has_current_project_chat_entitlement(
    chat_record.project_id,
    current_profile_id
  ) then
    raise exception using
      errcode = '42501',
      message = 'The project group chat is unavailable for sending.';
  end if;

  canonical_created_at := clock_timestamp();

  insert into public.project_chat_messages (
    chat_id,
    sender_profile_id,
    body,
    created_at
  )
  values (
    chat_record.id,
    current_profile_id,
    canonical_body,
    canonical_created_at
  )
  returning * into inserted_message;

  insert into private.outbox_events (event_type, payload)
  values (
    'project.chat_message_sent',
    jsonb_build_object(
      'chat_id', chat_record.id,
      'project_id', chat_record.project_id,
      'project_kind', project_record.project_kind,
      'message_id', inserted_message.id,
      'sender_profile_id', current_profile_id
    )
  );

  -- A chat/profile-specific topic prevents cached subscriptions from leaking a
  -- signal after leave/removal: only profiles entitled at this locked send are addressed.
  for recipient_profile_id in
    select project.creator_profile_id
    from public.projects as project
    where project.id = chat_record.project_id

    union

    select membership.participant_profile_id
    from public.project_memberships as membership
    where membership.project_id = chat_record.project_id
      and membership.left_at is null
      and membership.removed_at is null
    order by 1
  loop
    perform realtime.send(
      jsonb_build_object(
        'chat_id', chat_record.id,
        'message_id', inserted_message.id,
        'created_at', inserted_message.created_at
      ),
      'project.chat_message_sent',
      private.project_chat_realtime_topic(
        chat_record.id,
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

create function public.list_own_project_chat_messages(
  p_expected_profile_id uuid,
  p_chat_id uuid,
  p_limit integer,
  p_before_created_at timestamptz default null,
  p_before_message_id uuid default null
)
returns table (
  message_id uuid,
  chat_id uuid,
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
  project_id uuid;
begin
  if p_limit is null or p_limit < 1 or p_limit > 50 then
    raise exception using
      errcode = '22023',
      message = 'The Project chat message page size must be between 1 and 50.';
  end if;

  if (p_before_created_at is null) <> (p_before_message_id is null) then
    raise exception using
      errcode = '22023',
      message = 'Both Project chat message cursor values must be provided together.';
  end if;

  select chat.project_id
  into project_id
  from public.project_group_chats as chat
  where chat.id = p_chat_id
    and private.profile_has_project_chat_history_entitlement(
      chat.project_id,
      current_profile_id
    );

  if not found then
    raise exception using
      errcode = '42501',
      message = 'The project group chat is unavailable.';
  end if;

  return query
  select
    message.id,
    message.chat_id,
    message.sender_profile_id,
    sender.display_name,
    message.body,
    message.created_at
  from public.project_chat_messages as message
  join public.profiles as sender on sender.id = message.sender_profile_id
  where message.chat_id = p_chat_id
    and private.profile_can_read_project_chat_message(
      project_id,
      current_profile_id,
      message.created_at
    )
    and (
      p_before_created_at is null
      or (message.created_at, message.id)
        < (p_before_created_at, p_before_message_id)
    )
  order by message.created_at desc, message.id desc
  limit p_limit;
end;
$$;

create function public.list_own_project_group_chats(
  p_expected_profile_id uuid,
  p_limit integer,
  p_before_activity_at timestamptz default null,
  p_before_chat_id uuid default null
)
returns table (
  chat_id uuid,
  project_id uuid,
  project_kind text,
  project_title text,
  viewer_role text,
  has_current_entitlement boolean,
  has_history_entitlement boolean,
  activated_at timestamptz,
  last_visible_message_id uuid,
  last_visible_message_body text,
  last_visible_message_at timestamptz,
  last_visible_sender_profile_id uuid,
  last_visible_sender_display_name text,
  activity_at timestamptz
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
  if p_limit is null or p_limit < 1 or p_limit > 50 then
    raise exception using
      errcode = '22023',
      message = 'The Project chat list page size must be between 1 and 50.';
  end if;

  if (p_before_activity_at is null) <> (p_before_chat_id is null) then
    raise exception using
      errcode = '22023',
      message = 'Both Project chat-list cursor values must be provided together.';
  end if;

  return query
  with accessible_projects as (
    select project.id
    from public.projects as project
    where project.creator_profile_id = current_profile_id

    union

    select membership.project_id
    from public.project_memberships as membership
    where membership.participant_profile_id = current_profile_id
  ),
  visible_chats as (
    select
      chat.id as chat_id,
      project.id as project_id,
      project.project_kind,
      case project.project_kind
        when 'one_time' then proposal.title
        when 'recurring' then activity.title
      end as project_title,
      case
        when project.creator_profile_id = current_profile_id then 'creator'
        when private.profile_has_current_project_membership(
          project.id,
          current_profile_id
        ) then 'current_member'
        else 'former_member'
      end as viewer_role,
      private.profile_has_current_project_chat_entitlement(
        project.id,
        current_profile_id
      ) as has_current_entitlement,
      true as has_history_entitlement,
      chat.activated_at,
      latest.id as last_visible_message_id,
      latest.body as last_visible_message_body,
      latest.created_at as last_visible_message_at,
      latest.sender_profile_id as last_visible_sender_profile_id,
      latest.sender_display_name as last_visible_sender_display_name,
      coalesce(latest.created_at, chat.activated_at) as activity_at
    from accessible_projects as accessible
    join public.projects as project on project.id = accessible.id
    join public.project_group_chats as chat on chat.project_id = project.id
    left join public.proposals as proposal
      on proposal.id = project.id
      and project.project_kind = 'one_time'
    left join public.recurring_activities as activity
      on activity.id = project.id
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
      where message.chat_id = chat.id
        and private.profile_can_read_project_chat_message(
          project.id,
          current_profile_id,
          message.created_at
        )
      order by message.created_at desc, message.id desc
      limit 1
    ) as latest on true
  )
  select
    visible.chat_id,
    visible.project_id,
    visible.project_kind,
    visible.project_title,
    visible.viewer_role,
    visible.has_current_entitlement,
    visible.has_history_entitlement,
    visible.activated_at,
    visible.last_visible_message_id,
    visible.last_visible_message_body,
    visible.last_visible_message_at,
    visible.last_visible_sender_profile_id,
    visible.last_visible_sender_display_name,
    visible.activity_at
  from visible_chats as visible
  where
    p_before_activity_at is null
    or (visible.activity_at, visible.chat_id)
      < (p_before_activity_at, p_before_chat_id)
  order by visible.activity_at desc, visible.chat_id desc
  limit p_limit;
end;
$$;

revoke all privileges on function private.protect_project_chat_message_immutability()
  from public, anon, authenticated, service_role;
revoke all privileges on function private.latest_project_membership_end(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function private.profile_can_read_project_chat_message(uuid, uuid, timestamptz)
  from public, anon, authenticated, service_role;
revoke all privileges on function private.require_complete_project_chat_profile(uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function private.project_chat_realtime_topic(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function private.profile_can_receive_project_chat_realtime_topic(text)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.send_project_chat_message(uuid, uuid, text)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.list_own_project_chat_messages(uuid, uuid, integer, timestamptz, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.list_own_project_group_chats(uuid, integer, timestamptz, uuid)
  from public, anon, authenticated, service_role;

grant execute on function public.send_project_chat_message(uuid, uuid, text)
  to authenticated;
grant execute on function public.list_own_project_chat_messages(uuid, uuid, integer, timestamptz, uuid)
  to authenticated;
grant execute on function public.list_own_project_group_chats(uuid, integer, timestamptz, uuid)
  to authenticated;

comment on table public.project_group_chats is
  'Canonical structural anchor for one durable server-authorized Project group conversation.';
comment on function private.profile_can_read_project_chat_message(uuid, uuid, timestamptz) is
  'Grants every message to the creator/current member and messages through the latest ended-membership frontier to a former member.';
comment on function private.profile_can_receive_project_chat_realtime_topic(text) is
  'Fail-closed private Broadcast authorization for the authenticated profile current on the chat encoded by its per-profile topic.';
comment on function public.send_project_chat_message(uuid, uuid, text) is
  'Serializes against participation transitions, inserts one canonical plain-text message, emits an identifier-only outbox event, and privately signals currently entitled profiles.';
comment on function public.list_own_project_chat_messages(uuid, uuid, integer, timestamptz, uuid) is
  'Returns stable keyset-paginated durable Project-chat history through the authenticated viewer historical frontier.';
comment on function public.list_own_project_group_chats(uuid, integer, timestamptz, uuid) is
  'Returns keyset-paginated accessible chats with only each viewer last authorized message determining preview and activity.';
