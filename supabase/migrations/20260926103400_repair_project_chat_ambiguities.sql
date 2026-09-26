-- PL/pgSQL variables must not share unqualified names with columns referenced
-- by embedded SQL. Keep both public contracts unchanged while making variable
-- binding explicit for runtime and plpgsql_check.

create or replace function private.validate_project_chat_system_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  resolved_project_id uuid;
  source_event private.outbox_events%rowtype;
begin
  select chat.project_id
  into resolved_project_id
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
    or source_event.payload ->> 'project_id'
      is distinct from resolved_project_id::text
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
    where project.id = resolved_project_id
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
      and need.project_id = resolved_project_id
  ) then
    raise exception using
      errcode = '23514',
      message = 'A resource system event must reference its chat Project.';
  end if;

  return new;
end;
$$;

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
  resolved_chat_id uuid;
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
  into resolved_chat_id
  from public.project_group_chats as chat
  where chat.project_id = p_project_id;

  canonical_created_at := clock_timestamp();

  if resolved_chat_id is not null
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
    where event.chat_id = resolved_chat_id;
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

  if resolved_chat_id is null then
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
      resolved_chat_id,
      'requirement_needed_again',
      p_requirement_kind,
      case when p_requirement_kind = 'skill' then p_requirement_id end,
      case when p_requirement_kind = 'resource' then p_requirement_id end,
      source_outbox_event_id,
      canonical_created_at
    )
    returning id into system_event_id;

    realtime_payload := jsonb_build_object(
      'chat_id', resolved_chat_id,
      'project_id', p_project_id,
      'system_event_id', system_event_id,
      'requirement_kind', p_requirement_kind,
      'requirement_id', p_requirement_id,
      'created_at', canonical_created_at
    );
  else
    realtime_payload := jsonb_build_object(
      'chat_id', resolved_chat_id,
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
        resolved_chat_id,
        recipient_profile_id
      ),
      true
    );
  end loop;
end;
$$;

create or replace function public.list_own_project_chat_feed(
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
  resolved_project_id uuid;
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
  into resolved_project_id
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
        resolved_project_id,
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
        resolved_project_id,
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
