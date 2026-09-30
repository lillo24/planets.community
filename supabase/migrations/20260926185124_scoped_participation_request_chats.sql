create function public.list_own_scoped_message_chat_items(
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
      'project_request_chat'::text,
      2,
      request_chat.id,
      greatest(
        request_chat.activated_at,
        request.created_at,
        coalesce(request.resolved_at, request.created_at),
        coalesce(latest_message.created_at, request.created_at)
      ),
      case
        when current_profile_id = request.requester_profile_id
          then creator.display_name
        else requester.display_name
      end,
      case
        when current_profile_id = request.requester_profile_id
          then 'requester'
        else 'creator'
      end,
      request.status <> 'pending',
      latest_message.id,
      latest_message.body,
      latest_message.created_at,
      latest_message.sender_profile_id,
      latest_message.sender_display_name,
      null::uuid,
      null::text,
      null::uuid,
      null::uuid,
      null::uuid,
      null::text,
      null::timestamptz,
      request.id,
      project.id,
      project.project_kind,
      case project.project_kind
        when 'one_time' then proposal.title
        when 'recurring' then recurring.title
      end,
      case
        when current_profile_id = request.requester_profile_id
          then project.creator_profile_id
        else request.requester_profile_id
      end,
      case
        when current_profile_id = request.requester_profile_id
          then creator.display_name
        else requester.display_name
      end,
      request.status,
      request.request_message,
      request.resolved_at,
      case when request.status = 'accepted' then group_chat.id end
    from public.project_join_request_chats as request_chat
    join public.project_join_requests as request
      on request.id = request_chat.request_id
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
    left join lateral (
      select
        message.id,
        message.body,
        message.created_at,
        message.sender_profile_id,
        sender.display_name as sender_display_name
      from public.project_join_request_chat_messages as message
      join public.profiles as sender on sender.id = message.sender_profile_id
      where message.chat_id = request_chat.id
      order by message.created_at desc, message.id desc
      limit 1
    ) as latest_message on true
    where p_scope in ('private', 'all')
      and current_profile_id in (
        request.requester_profile_id,
        project.creator_profile_id
      )
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

revoke all privileges on function
  public.list_own_scoped_message_chat_items(
    uuid,
    text,
    integer,
    timestamptz,
    text,
    uuid
  ) from public, anon, authenticated, service_role;

grant execute on function
  public.list_own_scoped_message_chat_items(
    uuid,
    text,
    integer,
    timestamptz,
    text,
    uuid
  ) to authenticated;

comment on function public.list_own_scoped_message_chat_items(
  uuid,
  text,
  integer,
  timestamptz,
  text,
  uuid
) is
  'Returns an independently keyset-paginated private, group, or compatibility chat page, including authorized participation-request conversations.';
