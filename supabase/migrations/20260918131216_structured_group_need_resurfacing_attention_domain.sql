create table public.project_chat_system_events (
  id uuid primary key default gen_random_uuid(),
  chat_id uuid not null
    constraint project_chat_system_events_chat_id_fkey
      references public.project_group_chats (id) on delete restrict,
  event_kind text not null,
  requirement_kind text not null,
  skill_id uuid
    constraint project_chat_system_events_skill_id_fkey
      references public.skills (id) on delete restrict,
  resource_need_id uuid
    constraint project_chat_system_events_resource_need_id_fkey
      references public.project_resource_needs (id) on delete restrict,
  source_outbox_event_id uuid not null
    constraint project_chat_system_events_source_outbox_event_id_fkey
      references private.outbox_events (id) on delete restrict,
  created_at timestamptz not null,
  constraint project_chat_system_events_kind_supported check (
    event_kind = 'requirement_needed_again'
  ),
  constraint project_chat_system_events_requirement_kind_supported check (
    requirement_kind in ('skill', 'resource')
  ),
  constraint project_chat_system_events_requirement_reference check (
    (
      requirement_kind = 'skill'
      and skill_id is not null
      and resource_need_id is null
    )
    or (
      requirement_kind = 'resource'
      and skill_id is null
      and resource_need_id is not null
    )
  ),
  constraint project_chat_system_events_source_outbox_event_id_key
    unique (source_outbox_event_id),
  constraint project_chat_system_events_chat_created_id_key
    unique (chat_id, created_at, id)
);

comment on table public.project_chat_system_events is
  'Immutable structured Project-chat history projected synchronously from canonical requirement-needed-again outbox transitions.';
comment on column public.project_chat_system_events.source_outbox_event_id is
  'Unique provenance anchor for the exact project.requirement_needed_again transition that produced this item.';
comment on column public.project_chat_system_events.created_at is
  'Canonical server-owned transition time shared with the source outbox event.';

create index project_chat_system_events_chat_created_idx
  on public.project_chat_system_events (chat_id, created_at desc, id desc);
create index project_chat_system_events_skill_id_idx
  on public.project_chat_system_events (skill_id)
  where skill_id is not null;
create index project_chat_system_events_resource_need_id_idx
  on public.project_chat_system_events (resource_need_id)
  where resource_need_id is not null;

create table public.project_chat_requirement_attention_receipts (
  chat_id uuid not null
    constraint project_chat_requirement_attention_receipts_chat_id_fkey
      references public.project_group_chats (id) on delete restrict,
  profile_id uuid not null
    constraint project_chat_requirement_attention_receipts_profile_id_fkey
      references public.profiles (id) on delete restrict,
  acknowledged_through_created_at timestamptz not null,
  acknowledged_through_event_id uuid not null,
  updated_at timestamptz not null default statement_timestamp(),
  constraint project_chat_requirement_attention_receipts_pkey
    primary key (chat_id, profile_id),
  constraint project_chat_requirement_attention_receipts_event_cursor_fkey
    foreign key (
      chat_id,
      acknowledged_through_created_at,
      acknowledged_through_event_id
    )
      references public.project_chat_system_events (chat_id, created_at, id)
      on delete restrict
);

comment on table public.project_chat_requirement_attention_receipts is
  'Per-profile durable seen-through cursors for current Project-group resurfaced-requirement attention.';
comment on column
  public.project_chat_requirement_attention_receipts.acknowledged_through_event_id
is
  'UUID tie-break paired with the canonical event timestamp so acknowledgement never swallows a concurrent later event.';

create index project_chat_requirement_attention_receipts_profile_chat_idx
  on public.project_chat_requirement_attention_receipts (profile_id, chat_id);

alter table public.project_chat_system_events enable row level security;
alter table public.project_chat_requirement_attention_receipts
  enable row level security;

revoke all privileges on table public.project_chat_system_events
  from public, anon, authenticated, service_role;
revoke all privileges on table
  public.project_chat_requirement_attention_receipts
  from public, anon, authenticated, service_role;

create function private.validate_project_chat_system_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  project_id uuid;
  source_event private.outbox_events%rowtype;
begin
  select chat.project_id
  into project_id
  from public.project_group_chats as chat
  where chat.id = new.chat_id;

  if not found then
    raise exception using
      errcode = '23514',
      message = 'A Project chat system event requires a canonical chat.';
  end if;

  select * into source_event
  from private.outbox_events as event
  where event.id = new.source_outbox_event_id;

  if not found
    or source_event.event_type <> 'project.requirement_needed_again'
    or source_event.created_at is distinct from new.created_at
    or source_event.payload ->> 'project_id' is distinct from project_id::text
    or source_event.payload ->> 'requirement_kind'
      is distinct from new.requirement_kind
    or source_event.payload ->> 'requirement_id' is distinct from coalesce(
      new.skill_id,
      new.resource_need_id
    )::text then
    raise exception using
      errcode = '23514',
      message = 'Project chat system-event provenance is inconsistent.';
  end if;

  if new.requirement_kind = 'skill' and not exists (
    select 1
    from public.projects as project
    where project.id = project_id
      and project.project_kind = 'one_time'
  ) then
    raise exception using
      errcode = '23514',
      message = 'Only a Proposal chat may reference a skill requirement.';
  end if;

  if new.requirement_kind = 'resource' and not exists (
    select 1
    from public.project_resource_needs as need
    where need.id = new.resource_need_id
      and need.project_id = project_id
  ) then
    raise exception using
      errcode = '23514',
      message = 'A resource system event must reference its chat Project.';
  end if;

  return new;
end;
$$;

create function private.protect_project_chat_system_event_immutability()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  raise exception using
    errcode = '55000',
    message = 'Project chat system events are immutable.';
end;
$$;

create trigger project_chat_system_events_validate
before insert on public.project_chat_system_events
for each row execute function private.validate_project_chat_system_event();

create trigger project_chat_system_events_immutable
before update or delete on public.project_chat_system_events
for each row execute function
  private.protect_project_chat_system_event_immutability();

-- Persist the membership boundary before D3A releases coverage. The coverage
-- helper can then exclude the departing profile from the private broadcast and
-- assign the system item a time strictly after the half-open history frontier.
drop trigger project_memberships_release_ended_coverage
  on public.project_memberships;

create trigger project_memberships_release_ended_coverage
after update of left_at, removed_at on public.project_memberships
for each row execute function
  private.release_ended_project_membership_coverage();

create or replace function private.record_project_requirement_coverage_event(
  p_event_type text,
  p_actor_profile_id uuid,
  p_project_id uuid,
  p_project_kind text,
  p_requirement_kind text,
  p_requirement_id uuid,
  p_membership_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  identifier_payload jsonb := jsonb_strip_nulls(jsonb_build_object(
    'project_id', p_project_id,
    'project_kind', p_project_kind,
    'requirement_kind', p_requirement_kind,
    'requirement_id', p_requirement_id,
    'actor_profile_id', p_actor_profile_id,
    'membership_id', p_membership_id
  ));
  canonical_created_at timestamptz;
  source_outbox_event_id uuid;
  chat_id uuid;
  system_event_id uuid;
  recipient_profile_id uuid;
  realtime_payload jsonb;
begin
  if p_event_type not in (
    'project.requirement_covered',
    'project.requirement_needed_again'
  ) then
    raise exception using
      errcode = '22023',
      message = 'Unsupported Project requirement coverage event type.';
  end if;

  select chat.id
  into chat_id
  from public.project_group_chats as chat
  where chat.project_id = p_project_id;

  canonical_created_at := clock_timestamp();

  if chat_id is not null
    and p_event_type = 'project.requirement_needed_again' then
    -- Project-level transition locking serializes this lookup. Advancing by one
    -- microsecond on a clock collision makes the attention cursor monotonic by
    -- actual transition order instead of relying on random UUID ordering.
    select greatest(
      canonical_created_at,
      coalesce(
        max(event.created_at) + interval '1 microsecond',
        canonical_created_at
      )
    )
    into canonical_created_at
    from public.project_chat_system_events as event
    where event.chat_id = chat_id;
  end if;

  insert into private.audit_events (
    action,
    actor_user_id,
    target_type,
    target_id,
    metadata,
    created_at
  )
  values (
    p_event_type,
    p_actor_profile_id,
    'project_requirement',
    p_requirement_id,
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
    p_event_type,
    identifier_payload,
    canonical_created_at,
    canonical_created_at
  )
  returning id into source_outbox_event_id;

  if chat_id is null then
    return;
  end if;

  if p_event_type = 'project.requirement_needed_again' then
    insert into public.project_chat_system_events (
      chat_id,
      event_kind,
      requirement_kind,
      skill_id,
      resource_need_id,
      source_outbox_event_id,
      created_at
    )
    values (
      chat_id,
      'requirement_needed_again',
      p_requirement_kind,
      case when p_requirement_kind = 'skill' then p_requirement_id end,
      case when p_requirement_kind = 'resource' then p_requirement_id end,
      source_outbox_event_id,
      canonical_created_at
    )
    returning id into system_event_id;

    realtime_payload := jsonb_build_object(
      'chat_id', chat_id,
      'project_id', p_project_id,
      'system_event_id', system_event_id,
      'requirement_kind', p_requirement_kind,
      'requirement_id', p_requirement_id,
      'created_at', canonical_created_at
    );
  else
    realtime_payload := jsonb_build_object(
      'chat_id', chat_id,
      'project_id', p_project_id,
      'requirement_kind', p_requirement_kind,
      'requirement_id', p_requirement_id,
      'created_at', canonical_created_at
    );
  end if;

  for recipient_profile_id in
    select project.creator_profile_id
    from public.projects as project
    where project.id = p_project_id

    union

    select membership.participant_profile_id
    from public.project_memberships as membership
    where membership.project_id = p_project_id
      and membership.left_at is null
      and membership.removed_at is null
    order by 1
  loop
    perform realtime.send(
      realtime_payload,
      p_event_type,
      private.project_chat_realtime_topic(
        chat_id,
        recipient_profile_id
      ),
      true
    );
  end loop;
end;
$$;

create function public.list_own_project_chat_feed(
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
  created_at timestamptz,
  sender_profile_id uuid,
  sender_display_name text,
  body text,
  system_event_kind text,
  requirement_kind text,
  requirement_id uuid,
  requirement_label text
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
  cursor_kind_order smallint;
begin
  if p_limit is null or p_limit < 1 or p_limit > 50 then
    raise exception using
      errcode = '22023',
      message = 'The Project chat feed page size must be between 1 and 50.';
  end if;

  if num_nonnulls(
    p_before_created_at,
    p_before_item_kind,
    p_before_item_id
  ) not in (0, 3) then
    raise exception using
      errcode = '22023',
      message = 'All Project chat feed cursor values must be provided together.';
  end if;

  if p_before_item_kind is not null then
    cursor_kind_order := case p_before_item_kind
      when 'message' then 1
      when 'system_requirement_needed_again' then 0
      else null
    end;

    if cursor_kind_order is null then
      raise exception using
        errcode = '22023',
        message = 'The Project chat feed cursor kind is unsupported.';
    end if;
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
  with feed as (
    select
      'message'::text as resolved_item_kind,
      1::smallint as kind_order,
      message.id as resolved_item_id,
      message.chat_id as resolved_chat_id,
      message.created_at as resolved_created_at,
      message.sender_profile_id as resolved_sender_profile_id,
      sender.display_name as resolved_sender_display_name,
      message.body as resolved_body,
      null::text as resolved_system_event_kind,
      null::text as resolved_requirement_kind,
      null::uuid as resolved_requirement_id,
      null::text as resolved_requirement_label
    from public.project_chat_messages as message
    join public.profiles as sender on sender.id = message.sender_profile_id
    where message.chat_id = p_chat_id
      and private.profile_can_read_project_chat_message(
        project_id,
        current_profile_id,
        message.created_at
      )

    union all

    select
      'system_requirement_needed_again'::text,
      0::smallint,
      event.id,
      event.chat_id,
      event.created_at,
      null::uuid,
      null::text,
      null::text,
      event.event_kind,
      event.requirement_kind,
      coalesce(event.skill_id, event.resource_need_id),
      case event.requirement_kind
        when 'skill' then skill.label
        when 'resource' then need.title
      end
    from public.project_chat_system_events as event
    left join public.skills as skill on skill.id = event.skill_id
    left join public.project_resource_needs as need
      on need.id = event.resource_need_id
    where event.chat_id = p_chat_id
      and private.profile_can_read_project_chat_message(
        project_id,
        current_profile_id,
        event.created_at
      )
  )
  select
    feed.resolved_item_kind,
    feed.resolved_item_id,
    feed.resolved_chat_id,
    feed.resolved_created_at,
    feed.resolved_sender_profile_id,
    feed.resolved_sender_display_name,
    feed.resolved_body,
    feed.resolved_system_event_kind,
    feed.resolved_requirement_kind,
    feed.resolved_requirement_id,
    feed.resolved_requirement_label
  from feed
  where p_before_created_at is null
    or (
      feed.resolved_created_at,
      feed.kind_order,
      feed.resolved_item_id
    ) < (
      p_before_created_at,
      cursor_kind_order,
      p_before_item_id
    )
  order by
    feed.resolved_created_at desc,
    feed.kind_order desc,
    feed.resolved_item_id desc
  limit p_limit;
end;
$$;

create or replace function public.list_own_project_group_chats(
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
      latest_message.id as last_visible_message_id,
      latest_message.body as last_visible_message_body,
      latest_message.created_at as last_visible_message_at,
      latest_message.sender_profile_id as last_visible_sender_profile_id,
      latest_message.sender_display_name as last_visible_sender_display_name,
      greatest(
        chat.activated_at,
        coalesce(latest_message.created_at, chat.activated_at),
        coalesce(latest_system_event.created_at, chat.activated_at)
      ) as activity_at
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
    ) as latest_message on true
    left join lateral (
      select event.created_at
      from public.project_chat_system_events as event
      where event.chat_id = chat.id
        and private.profile_can_read_project_chat_message(
          project.id,
          current_profile_id,
          event.created_at
        )
      order by event.created_at desc, event.id desc
      limit 1
    ) as latest_system_event on true
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
  where p_before_activity_at is null
    or (visible.activity_at, visible.chat_id)
      < (p_before_activity_at, p_before_chat_id)
  order by visible.activity_at desc, visible.chat_id desc
  limit p_limit;
end;
$$;

create function public.get_own_project_requirement_attention(
  p_expected_profile_id uuid,
  p_project_id uuid
)
returns table (
  chat_id uuid,
  has_unseen_resurfaced_need boolean,
  latest_unseen_event_id uuid,
  latest_unseen_event_at timestamptz
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
  resolved_chat_id uuid;
  latest_event record;
begin
  select chat.id
  into resolved_chat_id
  from public.project_group_chats as chat
  where chat.project_id = p_project_id
    and private.profile_has_current_project_chat_entitlement(
      chat.project_id,
      current_profile_id
    );

  if not found then
    raise exception using
      errcode = '42501',
      message = 'Current Project requirement attention is unavailable.';
  end if;

  select event.id, event.created_at
  into latest_event
  from public.project_chat_system_events as event
  left join public.project_chat_requirement_attention_receipts as receipt
    on receipt.chat_id = event.chat_id
    and receipt.profile_id = current_profile_id
  where event.chat_id = resolved_chat_id
    and (
      receipt.profile_id is null
      or (event.created_at, event.id) > (
        receipt.acknowledged_through_created_at,
        receipt.acknowledged_through_event_id
      )
    )
    and private.project_has_live_coverage_lifecycle(p_project_id)
    and private.project_requirement_is_current(
      p_project_id,
      event.requirement_kind,
      coalesce(event.skill_id, event.resource_need_id)
    )
    and private.project_requirement_live_source_count(
      p_project_id,
      event.requirement_kind,
      coalesce(event.skill_id, event.resource_need_id)
    ) = 0
  order by event.created_at desc, event.id desc
  limit 1;

  return query
  select
    resolved_chat_id,
    latest_event.id is not null,
    latest_event.id,
    latest_event.created_at;
end;
$$;

create function public.acknowledge_project_requirement_attention(
  p_expected_profile_id uuid,
  p_project_id uuid,
  p_through_system_event_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_participation_identity(
    p_expected_profile_id
  );
  project_record record;
  event_record record;
  acknowledged_event_id uuid;
begin
  select
    event.id,
    event.chat_id,
    event.created_at,
    chat.project_id,
    event.event_kind
  into event_record
  from public.project_chat_system_events as event
  join public.project_group_chats as chat on chat.id = event.chat_id
  where event.id = p_through_system_event_id
    and chat.project_id = p_project_id;

  if not found then
    raise exception using
      errcode = '42501',
      message = 'The Project requirement-attention frontier is unavailable.';
  end if;

  select * into project_record
  from private.lock_project_for_live_requirement_coverage(p_project_id, true);

  select
    event.id,
    event.chat_id,
    event.created_at,
    chat.project_id,
    event.event_kind
  into event_record
  from public.project_chat_system_events as event
  join public.project_group_chats as chat on chat.id = event.chat_id
  where event.id = p_through_system_event_id
    and chat.project_id = p_project_id;

  if not found
    or event_record.event_kind <> 'requirement_needed_again'
    or not private.profile_has_current_project_chat_entitlement(
      p_project_id,
      current_profile_id
    ) then
    raise exception using
      errcode = '42501',
      message = 'The Project requirement-attention frontier is unavailable.';
  end if;

  insert into public.project_chat_requirement_attention_receipts (
    chat_id,
    profile_id,
    acknowledged_through_created_at,
    acknowledged_through_event_id,
    updated_at
  )
  values (
    event_record.chat_id,
    current_profile_id,
    event_record.created_at,
    event_record.id,
    clock_timestamp()
  )
  on conflict (chat_id, profile_id) do update
  set
    acknowledged_through_created_at =
      excluded.acknowledged_through_created_at,
    acknowledged_through_event_id = excluded.acknowledged_through_event_id,
    updated_at = excluded.updated_at
  where (
    public.project_chat_requirement_attention_receipts.acknowledged_through_created_at,
    public.project_chat_requirement_attention_receipts.acknowledged_through_event_id
  ) < (
    excluded.acknowledged_through_created_at,
    excluded.acknowledged_through_event_id
  )
  returning acknowledged_through_event_id into acknowledged_event_id;

  if acknowledged_event_id is null then
    select receipt.acknowledged_through_event_id
    into acknowledged_event_id
    from public.project_chat_requirement_attention_receipts as receipt
    where receipt.chat_id = event_record.chat_id
      and receipt.profile_id = current_profile_id;
  end if;

  return acknowledged_event_id;
end;
$$;

revoke all privileges on function
  private.validate_project_chat_system_event()
  from public, anon, authenticated, service_role;
revoke all privileges on function
  private.protect_project_chat_system_event_immutability()
  from public, anon, authenticated, service_role;
revoke all privileges on function
  public.list_own_project_chat_feed(
    uuid,
    uuid,
    integer,
    timestamptz,
    text,
    uuid
  )
  from public, anon, authenticated, service_role;
revoke all privileges on function
  public.get_own_project_requirement_attention(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function
  public.acknowledge_project_requirement_attention(uuid, uuid, uuid)
  from public, anon, authenticated, service_role;

grant execute on function
  public.list_own_project_chat_feed(
    uuid,
    uuid,
    integer,
    timestamptz,
    text,
    uuid
  )
  to authenticated;
grant execute on function
  public.get_own_project_requirement_attention(uuid, uuid)
  to authenticated;
grant execute on function
  public.acknowledge_project_requirement_attention(uuid, uuid, uuid)
  to authenticated;

comment on function
  private.record_project_requirement_coverage_event(
    text,
    uuid,
    uuid,
    text,
    text,
    uuid,
    uuid
  )
is
  'Records one identifier-only coverage transition and, when a chat exists, synchronously projects needed-again history plus private current-member Realtime signals.';
comment on function
  public.list_own_project_chat_feed(
    uuid,
    uuid,
    integer,
    timestamptz,
    text,
    uuid
  )
is
  'Returns one historically authorized mixed Project-chat chronology using created time, message-before-system kind order, and item UUID as its complete keyset cursor.';
comment on function
  public.list_own_project_group_chats(uuid, integer, timestamptz, uuid)
is
  'Returns accessible chats with honest human-message previews while visible message or needed-again system activity determines ordering.';
comment on function
  public.get_own_project_requirement_attention(uuid, uuid)
is
  'Returns the latest unacknowledged resurfacing event that still references one current uncovered requirement of an operational Project.';
comment on function
  public.acknowledge_project_requirement_attention(uuid, uuid, uuid)
is
  'Monotonically advances a current Project-group profile seen-through cursor to one explicitly supplied system event without acknowledging later concurrent events.';
