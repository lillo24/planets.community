create index resource_listing_requests_requester_activity_idx
  on public.resource_listing_requests (
    requester_profile_id,
    (greatest(
      created_at,
      coalesce(resolved_at, created_at),
      coalesce(coordination_closed_at, created_at)
    )) desc,
    id desc
  );

create index resource_listing_requests_listing_activity_idx
  on public.resource_listing_requests (
    listing_id,
    (greatest(
      created_at,
      coalesce(resolved_at, created_at),
      coalesce(coordination_closed_at, created_at)
    )) desc,
    id desc
  );

comment on index public.resource_listing_requests_requester_activity_idx is
  'Supports the unified structured Requests keyset for a resource requester.';
comment on index public.resource_listing_requests_listing_activity_idx is
  'Supports the unified structured Requests keyset for a resource listing owner.';

create function public.list_own_structured_request_message_items(
  p_expected_profile_id uuid,
  p_limit integer,
  p_cursor_activity_at timestamptz default null,
  p_cursor_item_kind text default null,
  p_cursor_request_id uuid default null
)
returns table (
  item_kind text,
  request_id uuid,
  viewer_role text,
  requester_profile_id uuid,
  requester_display_name text,
  status text,
  request_message text,
  created_at timestamptz,
  resolved_at timestamptz,
  activity_at timestamptz,
  project_id uuid,
  project_kind text,
  project_title text,
  project_creator_profile_id uuid,
  project_creator_display_name text,
  resource_listing_id uuid,
  resource_listing_mode text,
  resource_listing_title text,
  resource_listing_lifecycle text,
  resource_owner_profile_id uuid,
  resource_owner_display_name text,
  resource_chat_id uuid,
  resource_agreement_id uuid,
  coordination_closed_at timestamptz
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
      message = 'The unified request page size must be between 1 and 50.';
  end if;

  if num_nonnulls(
    p_cursor_activity_at,
    p_cursor_item_kind,
    p_cursor_request_id
  ) not in (0, 3) then
    raise exception using
      errcode = '22023',
      message = 'All unified request cursor values must be provided together.';
  end if;

  if p_cursor_item_kind is not null then
    cursor_kind_order := case p_cursor_item_kind
      when 'participation_request' then 0
      when 'resource_request' then 1
      else null
    end;

    if cursor_kind_order is null then
      raise exception using
        errcode = '22023',
        message = 'The unified request cursor item kind is unsupported.';
    end if;
  end if;

  return query
  with authorized_items as (
    select
      'participation_request'::text as resolved_item_kind,
      0 as item_kind_order,
      project_request.id as resolved_request_id,
      case
        when project_request.requester_profile_id = current_profile_id
          then 'requester'::text
        else 'creator'::text
      end as resolved_viewer_role,
      project_request.requester_profile_id,
      requester.display_name as requester_display_name,
      project_request.status,
      project_request.request_message,
      project_request.created_at,
      project_request.resolved_at,
      coalesce(
        project_request.resolved_at,
        project_request.created_at
      ) as resolved_activity_at,
      project.id as resolved_project_id,
      project.project_kind as resolved_project_kind,
      case project.project_kind
        when 'one_time' then proposal.title
        when 'recurring' then recurring.title
      end as resolved_project_title,
      project.creator_profile_id as resolved_project_creator_profile_id,
      creator.display_name as resolved_project_creator_display_name,
      null::uuid as resolved_resource_listing_id,
      null::text as resolved_resource_listing_mode,
      null::text as resolved_resource_listing_title,
      null::text as resolved_resource_listing_lifecycle,
      null::uuid as resolved_resource_owner_profile_id,
      null::text as resolved_resource_owner_display_name,
      null::uuid as resolved_resource_chat_id,
      null::uuid as resolved_resource_agreement_id,
      null::timestamptz as resolved_coordination_closed_at
    from public.project_join_requests as project_request
    join public.projects as project on project.id = project_request.project_id
    join public.profiles as requester
      on requester.id = project_request.requester_profile_id
    join public.profiles as creator on creator.id = project.creator_profile_id
    left join public.proposals as proposal
      on proposal.id = project.id
      and project.project_kind = 'one_time'
    left join public.recurring_activities as recurring
      on recurring.id = project.id
      and project.project_kind = 'recurring'
    where current_profile_id in (
      project_request.requester_profile_id,
      project.creator_profile_id
    )

    union all

    select
      'resource_request'::text,
      1,
      resource_request.id,
      case
        when resource_request.requester_profile_id = current_profile_id
          then 'requester'::text
        else 'owner'::text
      end,
      resource_request.requester_profile_id,
      requester.display_name,
      resource_request.status,
      resource_request.request_message,
      resource_request.created_at,
      resource_request.resolved_at,
      greatest(
        resource_request.created_at,
        coalesce(resource_request.resolved_at, resource_request.created_at),
        coalesce(
          resource_request.coordination_closed_at,
          resource_request.created_at
        )
      ),
      null::uuid,
      null::text,
      null::text,
      null::uuid,
      null::text,
      listing.id,
      listing.listing_mode,
      listing.title,
      listing.lifecycle_state,
      listing.owner_profile_id,
      owner.display_name,
      resource_chat.id,
      agreement.id,
      resource_request.coordination_closed_at
    from public.resource_listing_requests as resource_request
    join public.resource_listings as listing
      on listing.id = resource_request.listing_id
    join public.profiles as requester
      on requester.id = resource_request.requester_profile_id
    join public.profiles as owner on owner.id = listing.owner_profile_id
    left join public.resource_request_chats as resource_chat
      on resource_chat.request_id = resource_request.id
    left join public.resource_exchange_agreements as agreement
      on agreement.request_id = resource_request.id
    where current_profile_id in (
      resource_request.requester_profile_id,
      listing.owner_profile_id
    )
  )
  select
    item.resolved_item_kind,
    item.resolved_request_id,
    item.resolved_viewer_role,
    item.requester_profile_id,
    item.requester_display_name,
    item.status,
    item.request_message,
    item.created_at,
    item.resolved_at,
    item.resolved_activity_at,
    item.resolved_project_id,
    item.resolved_project_kind,
    item.resolved_project_title,
    item.resolved_project_creator_profile_id,
    item.resolved_project_creator_display_name,
    item.resolved_resource_listing_id,
    item.resolved_resource_listing_mode,
    item.resolved_resource_listing_title,
    item.resolved_resource_listing_lifecycle,
    item.resolved_resource_owner_profile_id,
    item.resolved_resource_owner_display_name,
    item.resolved_resource_chat_id,
    item.resolved_resource_agreement_id,
    item.resolved_coordination_closed_at
  from authorized_items as item
  where p_cursor_activity_at is null
    or (
      item.resolved_activity_at,
      item.item_kind_order,
      item.resolved_request_id
    ) < (
      p_cursor_activity_at,
      cursor_kind_order,
      p_cursor_request_id
    )
  order by
    item.resolved_activity_at desc,
    item.item_kind_order desc,
    item.resolved_request_id desc
  limit p_limit;
end;
$$;

create function public.get_own_structured_request_message_item(
  p_expected_profile_id uuid,
  p_item_kind text,
  p_request_id uuid
)
returns table (
  item_kind text,
  request_id uuid,
  viewer_role text,
  requester_profile_id uuid,
  requester_display_name text,
  status text,
  request_message text,
  created_at timestamptz,
  resolved_at timestamptz,
  activity_at timestamptz,
  project_id uuid,
  project_kind text,
  project_title text,
  project_creator_profile_id uuid,
  project_creator_display_name text,
  resource_listing_id uuid,
  resource_listing_mode text,
  resource_listing_title text,
  resource_listing_lifecycle text,
  resource_owner_profile_id uuid,
  resource_owner_display_name text,
  resource_chat_id uuid,
  resource_agreement_id uuid,
  coordination_closed_at timestamptz
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
  if p_item_kind not in ('participation_request', 'resource_request')
    or p_request_id is null then
    raise exception using
      errcode = '42501',
      message = 'The structured request message item is unavailable.';
  end if;

  if p_item_kind = 'participation_request' then
    if not exists (
      select 1
      from public.project_join_requests as project_request
      join public.projects as project
        on project.id = project_request.project_id
      where project_request.id = p_request_id
        and current_profile_id in (
          project_request.requester_profile_id,
          project.creator_profile_id
        )
    ) then
      raise exception using
        errcode = '42501',
        message = 'The structured request message item is unavailable.';
    end if;

    return query
    select
      'participation_request'::text,
      project_request.id,
      case
        when project_request.requester_profile_id = current_profile_id
          then 'requester'::text
        else 'creator'::text
      end,
      project_request.requester_profile_id,
      requester.display_name,
      project_request.status,
      project_request.request_message,
      project_request.created_at,
      project_request.resolved_at,
      coalesce(project_request.resolved_at, project_request.created_at),
      project.id,
      project.project_kind,
      case project.project_kind
        when 'one_time' then proposal.title
        when 'recurring' then recurring.title
      end,
      project.creator_profile_id,
      creator.display_name,
      null::uuid,
      null::text,
      null::text,
      null::text,
      null::uuid,
      null::text,
      null::uuid,
      null::uuid,
      null::timestamptz
    from public.project_join_requests as project_request
    join public.projects as project on project.id = project_request.project_id
    join public.profiles as requester
      on requester.id = project_request.requester_profile_id
    join public.profiles as creator on creator.id = project.creator_profile_id
    left join public.proposals as proposal
      on proposal.id = project.id
      and project.project_kind = 'one_time'
    left join public.recurring_activities as recurring
      on recurring.id = project.id
      and project.project_kind = 'recurring'
    where project_request.id = p_request_id;
    return;
  end if;

  if not exists (
    select 1
    from public.resource_listing_requests as resource_request
    join public.resource_listings as listing
      on listing.id = resource_request.listing_id
    where resource_request.id = p_request_id
      and current_profile_id in (
        resource_request.requester_profile_id,
        listing.owner_profile_id
      )
  ) then
    raise exception using
      errcode = '42501',
      message = 'The structured request message item is unavailable.';
  end if;

  return query
  select
    'resource_request'::text,
    resource_request.id,
    case
      when resource_request.requester_profile_id = current_profile_id
        then 'requester'::text
      else 'owner'::text
    end,
    resource_request.requester_profile_id,
    requester.display_name,
    resource_request.status,
    resource_request.request_message,
    resource_request.created_at,
    resource_request.resolved_at,
    greatest(
      resource_request.created_at,
      coalesce(resource_request.resolved_at, resource_request.created_at),
      coalesce(
        resource_request.coordination_closed_at,
        resource_request.created_at
      )
    ),
    null::uuid,
    null::text,
    null::text,
    null::uuid,
    null::text,
    listing.id,
    listing.listing_mode,
    listing.title,
    listing.lifecycle_state,
    listing.owner_profile_id,
    owner.display_name,
    resource_chat.id,
    agreement.id,
    resource_request.coordination_closed_at
  from public.resource_listing_requests as resource_request
  join public.resource_listings as listing
    on listing.id = resource_request.listing_id
  join public.profiles as requester
    on requester.id = resource_request.requester_profile_id
  join public.profiles as owner on owner.id = listing.owner_profile_id
  left join public.resource_request_chats as resource_chat
    on resource_chat.request_id = resource_request.id
  left join public.resource_exchange_agreements as agreement
    on agreement.request_id = resource_request.id
  where resource_request.id = p_request_id;
end;
$$;

create function public.list_own_message_chat_items(
  p_expected_profile_id uuid,
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
  coordination_closed_at timestamptz
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
      else null
    end;

    if cursor_kind_order is null then
      raise exception using
        errcode = '22023',
        message = 'The unified chat cursor item kind is unsupported.';
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
      null::timestamptz as resolved_coordination_closed_at
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
      resource_request.coordination_closed_at
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
    where current_profile_id in (
      listing.owner_profile_id,
      resource_request.requester_profile_id
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
    item.resolved_coordination_closed_at
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
  public.list_own_structured_request_message_items(
    uuid,
    integer,
    timestamptz,
    text,
    uuid
  ) from public, anon, authenticated, service_role;
revoke all privileges on function
  public.get_own_structured_request_message_item(uuid, text, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function
  public.list_own_message_chat_items(uuid, integer, timestamptz, text, uuid)
  from public, anon, authenticated, service_role;

grant execute on function
  public.list_own_structured_request_message_items(
    uuid,
    integer,
    timestamptz,
    text,
    uuid
  ) to authenticated;
grant execute on function
  public.get_own_structured_request_message_item(uuid, text, uuid)
  to authenticated;
grant execute on function
  public.list_own_message_chat_items(uuid, integer, timestamptz, text, uuid)
  to authenticated;

comment on function public.list_own_structured_request_message_items(
  uuid,
  integer,
  timestamptz,
  text,
  uuid
) is
  'Returns one complete cross-domain keyset page of authorized Project participation and Resource requests using strict discriminated rows.';
comment on function public.get_own_structured_request_message_item(
  uuid,
  text,
  uuid
) is
  'Returns one authorized Project participation or Resource request selected by its explicit discriminator and fails closed otherwise.';
comment on function public.list_own_message_chat_items(
  uuid,
  integer,
  timestamptz,
  text,
  uuid
) is
  'Returns one complete cross-domain keyset page of authorized Project and Resource chat summaries while preserving each domain history frontier.';

alter table public.notifications
  add column resource_listing_id uuid
    constraint notifications_resource_listing_id_fkey
      references public.resource_listings (id) on delete restrict,
  add column resource_request_id uuid
    constraint notifications_resource_request_id_fkey
      references public.resource_listing_requests (id) on delete restrict,
  add column resource_chat_id uuid
    constraint notifications_resource_chat_id_fkey
      references public.resource_request_chats (id) on delete restrict,
  add column resource_chat_message_id uuid
    constraint notifications_resource_chat_message_id_fkey
      references public.resource_request_chat_messages (id) on delete restrict,
  add column resource_agreement_id uuid
    constraint notifications_resource_agreement_id_fkey
      references public.resource_exchange_agreements (id) on delete restrict,
  add column resource_agreement_event_id uuid
    constraint notifications_resource_agreement_event_id_fkey
      references public.resource_exchange_agreement_events (id)
      on delete restrict;

alter table public.notifications
  drop constraint notifications_kind_valid,
  drop constraint notifications_destination_kind_valid,
  drop constraint notifications_category_matches_kind,
  drop constraint notifications_current_participation_project_required,
  drop constraint notifications_destination_matches_kind,
  drop constraint notifications_reference_shape_valid;

alter table public.notifications
  add constraint notifications_kind_valid check (
    notification_kind in (
      'participation_request_received',
      'participation_request_withdrawn',
      'participation_request_accepted',
      'participation_request_rejected',
      'participant_left',
      'participant_removed',
      'chat_message_received',
      'resource_request_received',
      'resource_request_withdrawn',
      'resource_request_accepted',
      'resource_request_rejected',
      'resource_request_listing_closed',
      'resource_chat_message_received',
      'resource_exchange_terms_proposed',
      'resource_exchange_terms_accepted',
      'resource_exchange_terms_rejected',
      'resource_exchange_terms_withdrawn',
      'resource_exchange_milestone_recorded',
      'resource_exchange_cancelled',
      'resource_exchange_completed'
    )
  ),
  add constraint notifications_destination_kind_valid check (
    destination_kind in (
      'participation_request',
      'project_participation',
      'project_detail',
      'project_chat',
      'resource_request',
      'resource_chat'
    )
  ),
  add constraint notifications_category_matches_kind check (
    (
      category_slug = 'participation'
      and notification_kind in (
        'participation_request_received',
        'participation_request_withdrawn',
        'participation_request_accepted',
        'participation_request_rejected',
        'participant_left',
        'participant_removed'
      )
    )
    or (
      category_slug = 'chat'
      and notification_kind = 'chat_message_received'
    )
    or (
      category_slug = 'resources'
      and notification_kind like 'resource_%'
    )
  ),
  add constraint notifications_destination_matches_kind check (
    (
      notification_kind in (
        'participation_request_received',
        'participation_request_withdrawn',
        'participation_request_accepted',
        'participation_request_rejected'
      )
      and destination_kind = 'participation_request'
    )
    or (
      notification_kind = 'participant_left'
      and destination_kind = 'project_participation'
    )
    or (
      notification_kind = 'participant_removed'
      and destination_kind = 'project_detail'
    )
    or (
      notification_kind = 'chat_message_received'
      and destination_kind = 'project_chat'
    )
    or (
      notification_kind in (
        'resource_request_received',
        'resource_request_withdrawn',
        'resource_request_rejected',
        'resource_request_listing_closed'
      )
      and destination_kind = 'resource_request'
    )
    or (
      notification_kind in (
        'resource_request_accepted',
        'resource_chat_message_received',
        'resource_exchange_terms_proposed',
        'resource_exchange_terms_accepted',
        'resource_exchange_terms_rejected',
        'resource_exchange_terms_withdrawn',
        'resource_exchange_milestone_recorded',
        'resource_exchange_cancelled',
        'resource_exchange_completed'
      )
      and destination_kind = 'resource_chat'
    )
  ),
  add constraint notifications_reference_shape_valid check (
    (
      resource_listing_id is null
      and resource_request_id is null
      and resource_chat_id is null
      and resource_chat_message_id is null
      and resource_agreement_id is null
      and resource_agreement_event_id is null
      and project_id is not null
      and (
        (
          notification_kind in (
            'participation_request_received',
            'participation_request_withdrawn',
            'participation_request_rejected'
          )
          and request_id is not null
          and membership_id is null
          and chat_id is null
          and message_id is null
        )
        or (
          notification_kind = 'participation_request_accepted'
          and request_id is not null
          and membership_id is not null
          and chat_id is null
          and message_id is null
        )
        or (
          notification_kind in ('participant_left', 'participant_removed')
          and request_id is null
          and membership_id is not null
          and chat_id is null
          and message_id is null
        )
        or (
          notification_kind = 'chat_message_received'
          and actor_profile_id is not null
          and request_id is null
          and membership_id is null
          and chat_id is not null
          and message_id is not null
        )
      )
    )
    or (
      category_slug = 'resources'
      and project_id is null
      and request_id is null
      and membership_id is null
      and chat_id is null
      and message_id is null
      and actor_profile_id is not null
      and resource_listing_id is not null
      and resource_request_id is not null
      and (
        (
          notification_kind in (
            'resource_request_received',
            'resource_request_withdrawn',
            'resource_request_rejected',
            'resource_request_listing_closed'
          )
          and resource_chat_id is null
          and resource_chat_message_id is null
          and resource_agreement_id is null
          and resource_agreement_event_id is null
        )
        or (
          notification_kind = 'resource_request_accepted'
          and resource_chat_id is not null
          and resource_chat_message_id is null
          and resource_agreement_id is not null
          and resource_agreement_event_id is null
        )
        or (
          notification_kind = 'resource_chat_message_received'
          and resource_chat_id is not null
          and resource_chat_message_id is not null
          and resource_agreement_id is not null
          and resource_agreement_event_id is null
        )
        or (
          notification_kind like 'resource_exchange_%'
          and resource_chat_id is not null
          and resource_chat_message_id is null
          and resource_agreement_id is not null
          and resource_agreement_event_id is not null
        )
      )
    )
  );

comment on column public.notifications.resource_listing_id is
  'Canonical Resource listing context; never copied listing content.';
comment on column public.notifications.resource_request_id is
  'Canonical Resource request context; never copied request text.';
comment on column public.notifications.resource_chat_id is
  'Canonical Resource chat destination for accepted coordination alerts.';
comment on column public.notifications.resource_chat_message_id is
  'Canonical Resource chat message provenance; message bodies are never copied.';
comment on column public.notifications.resource_agreement_id is
  'Canonical Resource agreement context; private terms are never copied.';
comment on column public.notifications.resource_agreement_event_id is
  'Canonical structured Resource agreement event used for localized recipient-owned inbox context.';

create index notifications_resource_listing_id_idx
  on public.notifications (resource_listing_id)
  where resource_listing_id is not null;
create index notifications_resource_request_id_idx
  on public.notifications (resource_request_id)
  where resource_request_id is not null;
create index notifications_resource_chat_id_idx
  on public.notifications (resource_chat_id)
  where resource_chat_id is not null;
create index notifications_resource_chat_message_id_idx
  on public.notifications (resource_chat_message_id)
  where resource_chat_message_id is not null;
create index notifications_resource_agreement_id_idx
  on public.notifications (resource_agreement_id)
  where resource_agreement_id is not null;
create index notifications_resource_agreement_event_id_idx
  on public.notifications (resource_agreement_event_id)
  where resource_agreement_event_id is not null;

alter table private.push_delivery_jobs
  add column resource_listing_id uuid
    constraint push_delivery_jobs_resource_listing_id_fkey
      references public.resource_listings (id) on delete restrict,
  add column resource_request_id uuid
    constraint push_delivery_jobs_resource_request_id_fkey
      references public.resource_listing_requests (id) on delete restrict,
  add column resource_chat_id uuid
    constraint push_delivery_jobs_resource_chat_id_fkey
      references public.resource_request_chats (id) on delete restrict,
  add column resource_chat_message_id uuid
    constraint push_delivery_jobs_resource_chat_message_id_fkey
      references public.resource_request_chat_messages (id) on delete restrict,
  add column resource_agreement_id uuid
    constraint push_delivery_jobs_resource_agreement_id_fkey
      references public.resource_exchange_agreements (id) on delete restrict,
  add column resource_agreement_event_id uuid
    constraint push_delivery_jobs_resource_agreement_event_id_fkey
      references public.resource_exchange_agreement_events (id)
      on delete restrict,
  add constraint push_delivery_jobs_resource_shape_valid check (
    (
      category_slug <> 'resources'
      and resource_listing_id is null
      and resource_request_id is null
      and resource_chat_id is null
      and resource_chat_message_id is null
      and resource_agreement_id is null
      and resource_agreement_event_id is null
    )
    or (
      category_slug = 'resources'
      and project_id is null
      and project_kind is null
      and request_id is null
      and membership_id is null
      and chat_id is null
      and message_id is null
      and actor_profile_id is not null
      and resource_listing_id is not null
      and resource_request_id is not null
      and (
        (
          notification_kind in (
            'resource_request_received',
            'resource_request_withdrawn',
            'resource_request_rejected',
            'resource_request_listing_closed'
          )
          and destination_kind = 'resource_request'
          and resource_chat_id is null
          and resource_chat_message_id is null
          and resource_agreement_id is null
          and resource_agreement_event_id is null
        )
        or (
          notification_kind = 'resource_request_accepted'
          and destination_kind = 'resource_chat'
          and resource_chat_id is not null
          and resource_chat_message_id is null
          and resource_agreement_id is not null
          and resource_agreement_event_id is null
        )
        or (
          notification_kind = 'resource_chat_message_received'
          and destination_kind = 'resource_chat'
          and resource_chat_id is not null
          and resource_chat_message_id is not null
          and resource_agreement_id is not null
          and resource_agreement_event_id is null
        )
        or (
          notification_kind in (
            'resource_exchange_terms_proposed',
            'resource_exchange_terms_accepted',
            'resource_exchange_terms_rejected',
            'resource_exchange_terms_withdrawn',
            'resource_exchange_milestone_recorded',
            'resource_exchange_cancelled',
            'resource_exchange_completed'
          )
          and destination_kind = 'resource_chat'
          and resource_chat_id is not null
          and resource_chat_message_id is null
          and resource_agreement_id is not null
          and resource_agreement_event_id is not null
        )
      )
    )
  );

comment on column private.push_delivery_jobs.resource_listing_id is
  'Provider-neutral Resource listing context without listing content.';
comment on column private.push_delivery_jobs.resource_request_id is
  'Provider-neutral Resource request context without request text.';
comment on column private.push_delivery_jobs.resource_chat_id is
  'Provider-neutral Resource chat destination.';
comment on column private.push_delivery_jobs.resource_chat_message_id is
  'Provider-neutral Resource message provenance without its body.';
comment on column private.push_delivery_jobs.resource_agreement_id is
  'Provider-neutral Resource agreement context without terms.';
comment on column private.push_delivery_jobs.resource_agreement_event_id is
  'Provider-neutral structured Resource event provenance.';

create index push_delivery_jobs_resource_listing_id_idx
  on private.push_delivery_jobs (resource_listing_id)
  where resource_listing_id is not null;
create index push_delivery_jobs_resource_request_id_idx
  on private.push_delivery_jobs (resource_request_id)
  where resource_request_id is not null;
create index push_delivery_jobs_resource_chat_id_idx
  on private.push_delivery_jobs (resource_chat_id)
  where resource_chat_id is not null;
create index push_delivery_jobs_resource_chat_message_id_idx
  on private.push_delivery_jobs (resource_chat_message_id)
  where resource_chat_message_id is not null;
create index push_delivery_jobs_resource_agreement_id_idx
  on private.push_delivery_jobs (resource_agreement_id)
  where resource_agreement_id is not null;
create index push_delivery_jobs_resource_agreement_event_id_idx
  on private.push_delivery_jobs (resource_agreement_event_id)
  where resource_agreement_event_id is not null;

create function private.resolve_resource_request_notification_event(
  p_outbox_event_id uuid
)
returns table (
  category_slug text,
  notification_kind text,
  recipient_profile_id uuid,
  actor_profile_id uuid,
  project_id uuid,
  project_kind text,
  request_id uuid,
  membership_id uuid,
  chat_id uuid,
  message_id uuid,
  resource_listing_id uuid,
  resource_request_id uuid,
  resource_chat_id uuid,
  resource_chat_message_id uuid,
  resource_agreement_id uuid,
  resource_agreement_event_id uuid,
  destination_kind text,
  source_created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  source_event private.outbox_events%rowtype;
  canonical record;
  payload_request_id uuid;
  payload_listing_id uuid;
  payload_owner_profile_id uuid;
  payload_requester_profile_id uuid;
  payload_actor_profile_id uuid;
  resolved_notification_kind text;
  resolved_recipient_profile_id uuid;
  resolved_destination_kind text;
begin
  select event.* into source_event
  from private.outbox_events as event
  where event.id = p_outbox_event_id
    and event.event_type in (
      'resource_listing.request_created',
      'resource_listing.request_withdrawn',
      'resource_listing.request_accepted',
      'resource_listing.request_rejected',
      'resource_listing.request_closed'
    );

  if not found then
    raise exception using
      errcode = '55000',
      message = format(
        'Resource request notification event %s is unavailable or unsupported.',
        p_outbox_event_id
      );
  end if;

  if jsonb_typeof(source_event.payload) is distinct from 'object'
    or (
      select count(*)
      from jsonb_object_keys(source_event.payload)
    ) <> 5
    or not source_event.payload ?& array[
      'request_id',
      'listing_id',
      'owner_profile_id',
      'requester_profile_id',
      'actor_profile_id'
    ] then
    raise exception using
      errcode = '55000',
      message = format(
        'Resource request notification event %s has invalid identifier-only payload shape.',
        source_event.id
      );
  end if;

  begin
    payload_request_id := (source_event.payload ->> 'request_id')::uuid;
    payload_listing_id := (source_event.payload ->> 'listing_id')::uuid;
    payload_owner_profile_id :=
      (source_event.payload ->> 'owner_profile_id')::uuid;
    payload_requester_profile_id :=
      (source_event.payload ->> 'requester_profile_id')::uuid;
    payload_actor_profile_id :=
      (source_event.payload ->> 'actor_profile_id')::uuid;
  exception
    when invalid_text_representation then
      raise exception using
        errcode = '55000',
        message = format(
          'Resource request notification event %s has invalid identifiers.',
          source_event.id
        );
  end;

  select
    resource_request.id as request_id,
    listing.id as listing_id,
    listing.owner_profile_id,
    resource_request.requester_profile_id,
    resource_chat.id as chat_id,
    agreement.id as agreement_id
  into canonical
  from public.resource_listing_requests as resource_request
  join public.resource_listings as listing
    on listing.id = resource_request.listing_id
  join public.profiles as owner on owner.id = listing.owner_profile_id
  join public.profiles as requester
    on requester.id = resource_request.requester_profile_id
  left join public.resource_request_chats as resource_chat
    on resource_chat.request_id = resource_request.id
  left join public.resource_exchange_agreements as agreement
    on agreement.request_id = resource_request.id
  where resource_request.id = payload_request_id;

  if not found
    or payload_listing_id is distinct from canonical.listing_id
    or payload_owner_profile_id is distinct from canonical.owner_profile_id
    or payload_requester_profile_id
      is distinct from canonical.requester_profile_id
    or (
      source_event.event_type in (
        'resource_listing.request_created',
        'resource_listing.request_withdrawn'
      )
      and payload_actor_profile_id
        is distinct from canonical.requester_profile_id
    )
    or (
      source_event.event_type in (
        'resource_listing.request_accepted',
        'resource_listing.request_rejected',
        'resource_listing.request_closed'
      )
      and payload_actor_profile_id is distinct from canonical.owner_profile_id
    )
    or (
      source_event.event_type = 'resource_listing.request_accepted'
      and (canonical.chat_id is null or canonical.agreement_id is null)
    ) then
    raise exception using
      errcode = '55000',
      message = format(
        'Resource request notification event %s does not match canonical request state.',
        source_event.id
      );
  end if;

  resolved_notification_kind := case source_event.event_type
    when 'resource_listing.request_created' then 'resource_request_received'
    when 'resource_listing.request_withdrawn' then 'resource_request_withdrawn'
    when 'resource_listing.request_accepted' then 'resource_request_accepted'
    when 'resource_listing.request_rejected' then 'resource_request_rejected'
    when 'resource_listing.request_closed'
      then 'resource_request_listing_closed'
  end;
  resolved_recipient_profile_id := case
    when source_event.event_type in (
      'resource_listing.request_created',
      'resource_listing.request_withdrawn'
    ) then canonical.owner_profile_id
    else canonical.requester_profile_id
  end;
  resolved_destination_kind := case
    when source_event.event_type = 'resource_listing.request_accepted'
      then 'resource_chat'
    else 'resource_request'
  end;

  return query select
    'resources'::text,
    resolved_notification_kind,
    resolved_recipient_profile_id,
    payload_actor_profile_id,
    null::uuid,
    null::text,
    null::uuid,
    null::uuid,
    null::uuid,
    null::uuid,
    canonical.listing_id,
    canonical.request_id,
    case
      when source_event.event_type = 'resource_listing.request_accepted'
        then canonical.chat_id
      else null::uuid
    end,
    null::uuid,
    case
      when source_event.event_type = 'resource_listing.request_accepted'
        then canonical.agreement_id
      else null::uuid
    end,
    null::uuid,
    resolved_destination_kind,
    source_event.created_at;
end;
$$;

create function private.resolve_resource_chat_notification_event(
  p_outbox_event_id uuid
)
returns table (
  category_slug text,
  notification_kind text,
  recipient_profile_id uuid,
  actor_profile_id uuid,
  project_id uuid,
  project_kind text,
  request_id uuid,
  membership_id uuid,
  chat_id uuid,
  message_id uuid,
  resource_listing_id uuid,
  resource_request_id uuid,
  resource_chat_id uuid,
  resource_chat_message_id uuid,
  resource_agreement_id uuid,
  resource_agreement_event_id uuid,
  destination_kind text,
  source_created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  source_event private.outbox_events%rowtype;
  canonical record;
  payload_chat_id uuid;
  payload_request_id uuid;
  payload_agreement_id uuid;
  payload_listing_id uuid;
  payload_owner_profile_id uuid;
  payload_requester_profile_id uuid;
  payload_message_id uuid;
  payload_sender_profile_id uuid;
begin
  select event.* into source_event
  from private.outbox_events as event
  where event.id = p_outbox_event_id
    and event.event_type = 'resource_chat.message_sent';

  if not found then
    raise exception using
      errcode = '55000',
      message = format(
        'Resource chat notification event %s is unavailable or unsupported.',
        p_outbox_event_id
      );
  end if;

  if jsonb_typeof(source_event.payload) is distinct from 'object'
    or (
      select count(*)
      from jsonb_object_keys(source_event.payload)
    ) <> 8
    or not source_event.payload ?& array[
      'chat_id',
      'request_id',
      'agreement_id',
      'listing_id',
      'owner_profile_id',
      'requester_profile_id',
      'message_id',
      'sender_profile_id'
    ] then
    raise exception using
      errcode = '55000',
      message = format(
        'Resource chat notification event %s has invalid identifier-only payload shape.',
        source_event.id
      );
  end if;

  begin
    payload_chat_id := (source_event.payload ->> 'chat_id')::uuid;
    payload_request_id := (source_event.payload ->> 'request_id')::uuid;
    payload_agreement_id := (source_event.payload ->> 'agreement_id')::uuid;
    payload_listing_id := (source_event.payload ->> 'listing_id')::uuid;
    payload_owner_profile_id :=
      (source_event.payload ->> 'owner_profile_id')::uuid;
    payload_requester_profile_id :=
      (source_event.payload ->> 'requester_profile_id')::uuid;
    payload_message_id := (source_event.payload ->> 'message_id')::uuid;
    payload_sender_profile_id :=
      (source_event.payload ->> 'sender_profile_id')::uuid;
  exception
    when invalid_text_representation then
      raise exception using
        errcode = '55000',
        message = format(
          'Resource chat notification event %s has invalid identifiers.',
          source_event.id
        );
  end;

  select
    message.id as message_id,
    message.sender_profile_id,
    message.created_at,
    resource_chat.id as chat_id,
    resource_request.id as request_id,
    agreement.id as agreement_id,
    listing.id as listing_id,
    listing.owner_profile_id,
    resource_request.requester_profile_id
  into canonical
  from public.resource_request_chat_messages as message
  join public.resource_request_chats as resource_chat
    on resource_chat.id = message.chat_id
  join public.resource_listing_requests as resource_request
    on resource_request.id = resource_chat.request_id
  join public.resource_listings as listing
    on listing.id = resource_request.listing_id
  join public.resource_exchange_agreements as agreement
    on agreement.request_id = resource_request.id
  join public.profiles as sender on sender.id = message.sender_profile_id
  where message.id = payload_message_id;

  if not found
    or payload_chat_id is distinct from canonical.chat_id
    or payload_request_id is distinct from canonical.request_id
    or payload_agreement_id is distinct from canonical.agreement_id
    or payload_listing_id is distinct from canonical.listing_id
    or payload_owner_profile_id is distinct from canonical.owner_profile_id
    or payload_requester_profile_id
      is distinct from canonical.requester_profile_id
    or payload_sender_profile_id is distinct from canonical.sender_profile_id
    or canonical.sender_profile_id not in (
      canonical.owner_profile_id,
      canonical.requester_profile_id
    ) then
    raise exception using
      errcode = '55000',
      message = format(
        'Resource chat notification event %s does not match its canonical message.',
        source_event.id
      );
  end if;

  return query select
    'resources'::text,
    'resource_chat_message_received'::text,
    case
      when canonical.sender_profile_id = canonical.owner_profile_id
        then canonical.requester_profile_id
      else canonical.owner_profile_id
    end,
    canonical.sender_profile_id,
    null::uuid,
    null::text,
    null::uuid,
    null::uuid,
    null::uuid,
    null::uuid,
    canonical.listing_id,
    canonical.request_id,
    canonical.chat_id,
    canonical.message_id,
    canonical.agreement_id,
    null::uuid,
    'resource_chat'::text,
    canonical.created_at;
end;
$$;

create function private.resolve_resource_exchange_notification_event(
  p_outbox_event_id uuid
)
returns table (
  category_slug text,
  notification_kind text,
  recipient_profile_id uuid,
  actor_profile_id uuid,
  project_id uuid,
  project_kind text,
  request_id uuid,
  membership_id uuid,
  chat_id uuid,
  message_id uuid,
  resource_listing_id uuid,
  resource_request_id uuid,
  resource_chat_id uuid,
  resource_chat_message_id uuid,
  resource_agreement_id uuid,
  resource_agreement_event_id uuid,
  destination_kind text,
  source_created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  source_event private.outbox_events%rowtype;
  canonical record;
  payload_agreement_id uuid;
  payload_request_id uuid;
  payload_listing_id uuid;
  payload_owner_profile_id uuid;
  payload_requester_profile_id uuid;
  payload_terms_id uuid;
  payload_agreement_event_id uuid;
  payload_actor_profile_id uuid;
  expected_event_kind text;
  resolved_notification_kind text;
  expected_payload_key_count integer;
begin
  select event.* into source_event
  from private.outbox_events as event
  where event.id = p_outbox_event_id
    and event.event_type in (
      'resource_exchange.terms_proposed',
      'resource_exchange.terms_accepted',
      'resource_exchange.terms_rejected',
      'resource_exchange.terms_withdrawn',
      'resource_exchange.milestone_recorded',
      'resource_exchange.agreement_cancelled',
      'resource_exchange.agreement_completed'
    );

  if not found then
    raise exception using
      errcode = '55000',
      message = format(
        'Resource exchange notification event %s is unavailable or unsupported.',
        p_outbox_event_id
      );
  end if;

  expected_payload_key_count := case
    when source_event.event_type = 'resource_exchange.agreement_cancelled'
      then 7
    else 8
  end;

  if jsonb_typeof(source_event.payload) is distinct from 'object'
    or (
      select count(*)
      from jsonb_object_keys(source_event.payload)
    ) <> expected_payload_key_count
    or not source_event.payload ?& array[
      'agreement_id',
      'request_id',
      'listing_id',
      'owner_profile_id',
      'requester_profile_id',
      'agreement_event_id',
      'actor_profile_id'
    ]
    or (
      expected_payload_key_count = 8
      and not source_event.payload ? 'terms_id'
    )
    or (
      expected_payload_key_count = 7
      and source_event.payload ? 'terms_id'
    ) then
    raise exception using
      errcode = '55000',
      message = format(
        'Resource exchange notification event %s has invalid identifier-only payload shape.',
        source_event.id
      );
  end if;

  begin
    payload_agreement_id :=
      (source_event.payload ->> 'agreement_id')::uuid;
    payload_request_id := (source_event.payload ->> 'request_id')::uuid;
    payload_listing_id := (source_event.payload ->> 'listing_id')::uuid;
    payload_owner_profile_id :=
      (source_event.payload ->> 'owner_profile_id')::uuid;
    payload_requester_profile_id :=
      (source_event.payload ->> 'requester_profile_id')::uuid;
    payload_terms_id := (source_event.payload ->> 'terms_id')::uuid;
    payload_agreement_event_id :=
      (source_event.payload ->> 'agreement_event_id')::uuid;
    payload_actor_profile_id :=
      (source_event.payload ->> 'actor_profile_id')::uuid;
  exception
    when invalid_text_representation then
      raise exception using
        errcode = '55000',
        message = format(
          'Resource exchange notification event %s has invalid identifiers.',
          source_event.id
        );
  end;

  select
    agreement_event.id as agreement_event_id,
    agreement_event.event_kind,
    agreement_event.terms_id,
    agreement_event.actor_profile_id,
    agreement_event.created_at,
    agreement.id as agreement_id,
    resource_request.id as request_id,
    listing.id as listing_id,
    listing.owner_profile_id,
    resource_request.requester_profile_id,
    resource_chat.id as chat_id
  into canonical
  from public.resource_exchange_agreement_events as agreement_event
  join public.resource_exchange_agreements as agreement
    on agreement.id = agreement_event.agreement_id
  join public.resource_listing_requests as resource_request
    on resource_request.id = agreement.request_id
  join public.resource_listings as listing
    on listing.id = resource_request.listing_id
  join public.resource_request_chats as resource_chat
    on resource_chat.request_id = resource_request.id
  where agreement_event.id = payload_agreement_event_id;

  expected_event_kind := case source_event.event_type
    when 'resource_exchange.terms_proposed' then 'terms_proposed'
    when 'resource_exchange.terms_accepted' then 'terms_accepted'
    when 'resource_exchange.terms_rejected' then 'terms_rejected'
    when 'resource_exchange.terms_withdrawn' then 'terms_withdrawn'
    when 'resource_exchange.agreement_cancelled' then 'agreement_cancelled'
    when 'resource_exchange.agreement_completed' then 'agreement_completed'
    else canonical.event_kind
  end;

  if not found
    or payload_agreement_id is distinct from canonical.agreement_id
    or payload_request_id is distinct from canonical.request_id
    or payload_listing_id is distinct from canonical.listing_id
    or payload_owner_profile_id is distinct from canonical.owner_profile_id
    or payload_requester_profile_id
      is distinct from canonical.requester_profile_id
    or payload_terms_id is distinct from canonical.terms_id
    or payload_actor_profile_id is distinct from canonical.actor_profile_id
    or canonical.event_kind is distinct from expected_event_kind
    or (
      source_event.event_type = 'resource_exchange.milestone_recorded'
      and canonical.event_kind not in (
        'resource_provided',
        'resource_received',
        'resource_returned',
        'resource_return_received'
      )
    )
    or canonical.actor_profile_id not in (
      canonical.owner_profile_id,
      canonical.requester_profile_id
    ) then
    raise exception using
      errcode = '55000',
      message = format(
        'Resource exchange notification event %s does not match its canonical agreement event.',
        source_event.id
      );
  end if;

  resolved_notification_kind := case source_event.event_type
    when 'resource_exchange.terms_proposed'
      then 'resource_exchange_terms_proposed'
    when 'resource_exchange.terms_accepted'
      then 'resource_exchange_terms_accepted'
    when 'resource_exchange.terms_rejected'
      then 'resource_exchange_terms_rejected'
    when 'resource_exchange.terms_withdrawn'
      then 'resource_exchange_terms_withdrawn'
    when 'resource_exchange.milestone_recorded'
      then 'resource_exchange_milestone_recorded'
    when 'resource_exchange.agreement_cancelled'
      then 'resource_exchange_cancelled'
    when 'resource_exchange.agreement_completed'
      then 'resource_exchange_completed'
  end;

  return query select
    'resources'::text,
    resolved_notification_kind,
    case
      when canonical.actor_profile_id = canonical.owner_profile_id
        then canonical.requester_profile_id
      else canonical.owner_profile_id
    end,
    canonical.actor_profile_id,
    null::uuid,
    null::text,
    null::uuid,
    null::uuid,
    null::uuid,
    null::uuid,
    canonical.listing_id,
    canonical.request_id,
    canonical.chat_id,
    null::uuid,
    canonical.agreement_id,
    canonical.agreement_event_id,
    'resource_chat'::text,
    canonical.created_at;
end;
$$;

drop function private.resolve_notification_event(uuid);

create function private.resolve_notification_event(
  p_outbox_event_id uuid
)
returns table (
  category_slug text,
  notification_kind text,
  recipient_profile_id uuid,
  actor_profile_id uuid,
  project_id uuid,
  project_kind text,
  request_id uuid,
  membership_id uuid,
  chat_id uuid,
  message_id uuid,
  resource_listing_id uuid,
  resource_request_id uuid,
  resource_chat_id uuid,
  resource_chat_message_id uuid,
  resource_agreement_id uuid,
  resource_agreement_event_id uuid,
  destination_kind text,
  source_created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  resolved_event_type text;
begin
  select event.event_type into resolved_event_type
  from private.outbox_events as event
  where event.id = p_outbox_event_id;

  if not found then
    raise exception using
      errcode = '55000',
      message = format('Notification event %s is unavailable.', p_outbox_event_id);
  end if;

  if resolved_event_type = 'project.chat_message_sent' then
    return query
    select
      resolved.category_slug,
      resolved.notification_kind,
      resolved.recipient_profile_id,
      resolved.actor_profile_id,
      resolved.project_id,
      resolved.project_kind,
      resolved.request_id,
      resolved.membership_id,
      resolved.chat_id,
      resolved.message_id,
      null::uuid,
      null::uuid,
      null::uuid,
      null::uuid,
      null::uuid,
      null::uuid,
      resolved.destination_kind,
      resolved.source_created_at
    from private.resolve_chat_message_notification_event(
      p_outbox_event_id
    ) as resolved;
    return;
  end if;

  if resolved_event_type in (
    'project.join_requested',
    'project.join_request_withdrawn',
    'project.join_request_accepted',
    'project.join_request_rejected',
    'project.participant_left',
    'project.participant_removed'
  ) then
    return query
    select
      resolved.category_slug,
      resolved.notification_kind,
      resolved.recipient_profile_id,
      resolved.actor_profile_id,
      resolved.project_id,
      resolved.project_kind,
      resolved.request_id,
      resolved.membership_id,
      null::uuid,
      null::uuid,
      null::uuid,
      null::uuid,
      null::uuid,
      null::uuid,
      null::uuid,
      null::uuid,
      resolved.destination_kind,
      resolved.source_created_at
    from private.resolve_participation_notification_event(
      p_outbox_event_id
    ) as resolved;
    return;
  end if;

  if resolved_event_type like 'resource_listing.request_%' then
    return query
    select *
    from private.resolve_resource_request_notification_event(
      p_outbox_event_id
    );
    return;
  end if;

  if resolved_event_type = 'resource_chat.message_sent' then
    return query
    select *
    from private.resolve_resource_chat_notification_event(
      p_outbox_event_id
    );
    return;
  end if;

  if resolved_event_type in (
    'resource_exchange.terms_proposed',
    'resource_exchange.terms_accepted',
    'resource_exchange.terms_rejected',
    'resource_exchange.terms_withdrawn',
    'resource_exchange.milestone_recorded',
    'resource_exchange.agreement_cancelled',
    'resource_exchange.agreement_completed'
  ) then
    return query
    select *
    from private.resolve_resource_exchange_notification_event(
      p_outbox_event_id
    );
    return;
  end if;

  raise exception using
    errcode = '55000',
    message = format('Notification event %s is unsupported.', p_outbox_event_id);
end;
$$;

revoke all privileges on function
  private.resolve_resource_request_notification_event(uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function
  private.resolve_resource_chat_notification_event(uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function
  private.resolve_resource_exchange_notification_event(uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function private.resolve_notification_event(uuid)
  from public, anon, authenticated, service_role;

comment on function private.resolve_resource_request_notification_event(uuid)
is
  'Validates an identifier-only Resource request event against canonical request/listing state and derives its single legitimate recipient.';
comment on function private.resolve_resource_chat_notification_event(uuid) is
  'Validates an identifier-only Resource chat event against its canonical body-free message context and derives the opposite counterparty.';
comment on function private.resolve_resource_exchange_notification_event(uuid)
is
  'Validates a supported identifier-only Resource exchange event and derives its single opposite counterparty without copying private terms.';
comment on function private.resolve_notification_event(uuid) is
  'Normalizes supported Project and Resource outbox sources into provider-neutral, recipient-level semantic alerts.';

-- Resource events that predate this projection are deliberately acknowledged
-- without creating retrospective in-app notifications or push jobs.
insert into private.outbox_consumer_receipts (
  outbox_event_id,
  consumer_key,
  processed_at
)
select
  event.id,
  consumer.consumer_key,
  statement_timestamp()
from private.outbox_events as event
cross join (
  values ('notifications.v1'::text), ('push.v1'::text)
) as consumer(consumer_key)
where event.event_type in (
  'resource_listing.request_created',
  'resource_listing.request_withdrawn',
  'resource_listing.request_accepted',
  'resource_listing.request_rejected',
  'resource_listing.request_closed',
  'resource_chat.message_sent',
  'resource_exchange.terms_proposed',
  'resource_exchange.terms_accepted',
  'resource_exchange.terms_rejected',
  'resource_exchange.terms_withdrawn',
  'resource_exchange.milestone_recorded',
  'resource_exchange.agreement_cancelled',
  'resource_exchange.agreement_completed'
)
on conflict do nothing;

drop index private.outbox_events_notification_sources_available_idx;
create index outbox_events_notification_sources_available_idx
  on private.outbox_events (available_at, created_at, id)
  where event_type in (
    'project.join_requested',
    'project.join_request_withdrawn',
    'project.join_request_accepted',
    'project.join_request_rejected',
    'project.participant_left',
    'project.participant_removed',
    'project.chat_message_sent',
    'resource_listing.request_created',
    'resource_listing.request_withdrawn',
    'resource_listing.request_accepted',
    'resource_listing.request_rejected',
    'resource_listing.request_closed',
    'resource_chat.message_sent',
    'resource_exchange.terms_proposed',
    'resource_exchange.terms_accepted',
    'resource_exchange.terms_rejected',
    'resource_exchange.terms_withdrawn',
    'resource_exchange.milestone_recorded',
    'resource_exchange.agreement_cancelled',
    'resource_exchange.agreement_completed'
  );

create or replace function public.process_notification_outbox_batch(
  p_limit integer default 100
)
returns table (
  processed_count integer,
  notifications_created integer,
  notifications_suppressed integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  source_event private.outbox_events%rowtype;
  resolved_event record;
  in_app_enabled boolean;
  resolved_processed_count integer := 0;
  resolved_notifications_created integer := 0;
  resolved_notifications_suppressed integer := 0;
  inserted_count integer;
begin
  if p_limit is null or p_limit not between 1 and 100 then
    raise exception using
      errcode = '22023',
      message = 'Notification projector batch size must be between 1 and 100.';
  end if;

  for source_event in
    select event.*
    from private.outbox_events as event
    where event.event_type in (
      'project.join_requested',
      'project.join_request_withdrawn',
      'project.join_request_accepted',
      'project.join_request_rejected',
      'project.participant_left',
      'project.participant_removed',
      'project.chat_message_sent',
      'resource_listing.request_created',
      'resource_listing.request_withdrawn',
      'resource_listing.request_accepted',
      'resource_listing.request_rejected',
      'resource_listing.request_closed',
      'resource_chat.message_sent',
      'resource_exchange.terms_proposed',
      'resource_exchange.terms_accepted',
      'resource_exchange.terms_rejected',
      'resource_exchange.terms_withdrawn',
      'resource_exchange.milestone_recorded',
      'resource_exchange.agreement_cancelled',
      'resource_exchange.agreement_completed'
    )
      and event.available_at <= statement_timestamp()
      and not exists (
        select 1
        from private.outbox_consumer_receipts as receipt
        where receipt.outbox_event_id = event.id
          and receipt.consumer_key = 'notifications.v1'
      )
    order by event.created_at, event.id
    limit p_limit
    for update of event skip locked
  loop
    for resolved_event in
      select *
      from private.resolve_notification_event(source_event.id)
    loop
      select coalesce(
        preference.in_app_enabled,
        category.default_in_app_enabled
      )
      into in_app_enabled
      from public.notification_categories as category
      left join public.profile_notification_preferences as preference
        on preference.profile_id = resolved_event.recipient_profile_id
        and preference.category_slug = category.slug
      where category.slug = resolved_event.category_slug;

      if in_app_enabled is null then
        raise exception using
          errcode = '55000',
          message = 'The resolved notification category is unavailable.';
      end if;

      if in_app_enabled then
        insert into public.notifications (
          recipient_profile_id,
          category_slug,
          notification_kind,
          source_outbox_event_id,
          project_id,
          actor_profile_id,
          request_id,
          membership_id,
          destination_kind,
          created_at,
          chat_id,
          message_id,
          resource_listing_id,
          resource_request_id,
          resource_chat_id,
          resource_chat_message_id,
          resource_agreement_id,
          resource_agreement_event_id
        )
        values (
          resolved_event.recipient_profile_id,
          resolved_event.category_slug,
          resolved_event.notification_kind,
          source_event.id,
          resolved_event.project_id,
          resolved_event.actor_profile_id,
          resolved_event.request_id,
          resolved_event.membership_id,
          resolved_event.destination_kind,
          resolved_event.source_created_at,
          resolved_event.chat_id,
          resolved_event.message_id,
          resolved_event.resource_listing_id,
          resolved_event.resource_request_id,
          resolved_event.resource_chat_id,
          resolved_event.resource_chat_message_id,
          resolved_event.resource_agreement_id,
          resolved_event.resource_agreement_event_id
        )
        on conflict (
          source_outbox_event_id,
          recipient_profile_id,
          notification_kind
        ) do nothing;

        get diagnostics inserted_count = row_count;
        resolved_notifications_created :=
          resolved_notifications_created + inserted_count;
      else
        resolved_notifications_suppressed :=
          resolved_notifications_suppressed + 1;
      end if;
    end loop;

    insert into private.outbox_consumer_receipts (
      outbox_event_id,
      consumer_key,
      processed_at
    )
    values (source_event.id, 'notifications.v1', statement_timestamp())
    on conflict do nothing;

    resolved_processed_count := resolved_processed_count + 1;
  end loop;

  return query select
    resolved_processed_count,
    resolved_notifications_created,
    resolved_notifications_suppressed;
end;
$$;

create or replace function public.process_push_outbox_batch(
  p_limit integer default 100
)
returns table (
  processed_count integer,
  jobs_created integer,
  jobs_suppressed integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  source_event private.outbox_events%rowtype;
  resolved_event record;
  push_enabled boolean;
  resolved_processed_count integer := 0;
  resolved_jobs_created integer := 0;
  resolved_jobs_suppressed integer := 0;
  inserted_count integer;
begin
  if p_limit is null or p_limit not between 1 and 100 then
    raise exception using
      errcode = '22023',
      message = 'Push projector batch size must be between 1 and 100.';
  end if;

  for source_event in
    select event.*
    from private.outbox_events as event
    where event.event_type in (
      'project.join_requested',
      'project.join_request_withdrawn',
      'project.join_request_accepted',
      'project.join_request_rejected',
      'project.participant_left',
      'project.participant_removed',
      'project.chat_message_sent',
      'resource_listing.request_created',
      'resource_listing.request_withdrawn',
      'resource_listing.request_accepted',
      'resource_listing.request_rejected',
      'resource_listing.request_closed',
      'resource_chat.message_sent',
      'resource_exchange.terms_proposed',
      'resource_exchange.terms_accepted',
      'resource_exchange.terms_rejected',
      'resource_exchange.terms_withdrawn',
      'resource_exchange.milestone_recorded',
      'resource_exchange.agreement_cancelled',
      'resource_exchange.agreement_completed'
    )
      and event.available_at <= statement_timestamp()
      and not exists (
        select 1
        from private.outbox_consumer_receipts as receipt
        where receipt.outbox_event_id = event.id
          and receipt.consumer_key = 'push.v1'
      )
    order by event.created_at, event.id
    limit p_limit
    for update of event skip locked
  loop
    for resolved_event in
      select *
      from private.resolve_notification_event(source_event.id)
    loop
      select coalesce(
        preference.push_enabled,
        category.default_push_enabled
      )
      into push_enabled
      from public.notification_categories as category
      left join public.profile_notification_preferences as preference
        on preference.profile_id = resolved_event.recipient_profile_id
        and preference.category_slug = category.slug
      where category.slug = resolved_event.category_slug;

      if push_enabled is null then
        raise exception using
          errcode = '55000',
          message = 'The resolved notification category is unavailable.';
      end if;

      if push_enabled then
        insert into private.push_delivery_jobs (
          source_outbox_event_id,
          recipient_profile_id,
          category_slug,
          notification_kind,
          actor_profile_id,
          project_id,
          project_kind,
          request_id,
          membership_id,
          destination_kind,
          created_at,
          available_at,
          chat_id,
          message_id,
          resource_listing_id,
          resource_request_id,
          resource_chat_id,
          resource_chat_message_id,
          resource_agreement_id,
          resource_agreement_event_id
        )
        values (
          source_event.id,
          resolved_event.recipient_profile_id,
          resolved_event.category_slug,
          resolved_event.notification_kind,
          resolved_event.actor_profile_id,
          resolved_event.project_id,
          resolved_event.project_kind,
          resolved_event.request_id,
          resolved_event.membership_id,
          resolved_event.destination_kind,
          resolved_event.source_created_at,
          statement_timestamp(),
          resolved_event.chat_id,
          resolved_event.message_id,
          resolved_event.resource_listing_id,
          resolved_event.resource_request_id,
          resolved_event.resource_chat_id,
          resolved_event.resource_chat_message_id,
          resolved_event.resource_agreement_id,
          resolved_event.resource_agreement_event_id
        )
        on conflict (
          source_outbox_event_id,
          recipient_profile_id,
          notification_kind
        ) do nothing;

        get diagnostics inserted_count = row_count;
        resolved_jobs_created := resolved_jobs_created + inserted_count;
      else
        resolved_jobs_suppressed := resolved_jobs_suppressed + 1;
      end if;
    end loop;

    insert into private.outbox_consumer_receipts (
      outbox_event_id,
      consumer_key,
      processed_at
    )
    values (source_event.id, 'push.v1', statement_timestamp())
    on conflict do nothing;

    resolved_processed_count := resolved_processed_count + 1;
  end loop;

  return query select
    resolved_processed_count,
    resolved_jobs_created,
    resolved_jobs_suppressed;
end;
$$;

drop function public.list_own_notifications(uuid, integer, timestamptz, uuid);

create function public.list_own_notifications(
  p_expected_profile_id uuid,
  p_limit integer default 20,
  p_cursor_created_at timestamptz default null,
  p_cursor_id uuid default null
)
returns table (
  notification_id uuid,
  category_slug text,
  notification_kind text,
  created_at timestamptz,
  read_at timestamptz,
  project_id uuid,
  project_kind text,
  destination_kind text,
  request_id uuid,
  chat_id uuid,
  message_id uuid,
  project_title text,
  actor_profile_id uuid,
  actor_display_name text,
  resource_listing_id uuid,
  resource_listing_title text,
  resource_request_id uuid,
  resource_chat_id uuid,
  resource_chat_message_id uuid,
  resource_agreement_id uuid,
  resource_agreement_event_id uuid,
  resource_exchange_event_kind text,
  resource_exchange_leg_kind text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_notification_identity(
    p_expected_profile_id
  );
begin
  if p_limit is null or p_limit not between 1 and 100 then
    raise exception using
      errcode = '22023',
      message = 'Notification page size must be between 1 and 100.';
  end if;

  if (p_cursor_created_at is null) <> (p_cursor_id is null) then
    raise exception using
      errcode = '22023',
      message = 'Notification pagination requires both cursor timestamp and cursor ID.';
  end if;

  return query
  select
    notification.id,
    notification.category_slug,
    notification.notification_kind,
    notification.created_at,
    notification.read_at,
    notification.project_id,
    project.project_kind,
    notification.destination_kind,
    notification.request_id,
    notification.chat_id,
    notification.message_id,
    case
      when project.project_kind = 'one_time' then proposal.title
      when project.project_kind = 'recurring' then recurring.title
    end,
    notification.actor_profile_id,
    actor.display_name,
    notification.resource_listing_id,
    listing.title,
    notification.resource_request_id,
    notification.resource_chat_id,
    notification.resource_chat_message_id,
    notification.resource_agreement_id,
    notification.resource_agreement_event_id,
    agreement_event.event_kind,
    agreement_event.leg_kind
  from public.notifications as notification
  left join public.projects as project on project.id = notification.project_id
  left join public.proposals as proposal
    on proposal.id = project.id
    and project.project_kind = 'one_time'
  left join public.recurring_activities as recurring
    on recurring.id = project.id
    and project.project_kind = 'recurring'
  left join public.resource_listings as listing
    on listing.id = notification.resource_listing_id
  left join public.resource_exchange_agreement_events as agreement_event
    on agreement_event.id = notification.resource_agreement_event_id
  left join public.profiles as actor on actor.id = notification.actor_profile_id
  where notification.recipient_profile_id = current_profile_id
    and (
      p_cursor_created_at is null
      or (notification.created_at, notification.id)
        < (p_cursor_created_at, p_cursor_id)
    )
  order by notification.created_at desc, notification.id desc
  limit p_limit;
end;
$$;

revoke all privileges on function
  public.list_own_notifications(uuid, integer, timestamptz, uuid)
  from public, anon, authenticated, service_role;
grant execute on function
  public.list_own_notifications(uuid, integer, timestamptz, uuid)
  to authenticated;

comment on function public.list_own_notifications(
  uuid,
  integer,
  timestamptz,
  uuid
) is
  'Returns recipient-owned semantic alerts with safe Project or Resource identifiers, title, and structured event metadata, never request/chat/terms content.';

drop function private.claim_push_delivery_targets(text, integer, integer);

create function private.claim_push_delivery_targets(
  p_worker_id text,
  p_limit integer,
  p_lease_seconds integer
)
returns table (
  target_id uuid,
  job_id uuid,
  lease_id uuid,
  lease_expires_at timestamptz,
  attempt_number integer,
  installation_id uuid,
  platform text,
  provider text,
  provider_token text,
  token_version bigint,
  category_slug text,
  notification_kind text,
  recipient_profile_id uuid,
  actor_profile_id uuid,
  project_id uuid,
  project_kind text,
  request_id uuid,
  membership_id uuid,
  chat_id uuid,
  message_id uuid,
  resource_listing_id uuid,
  resource_request_id uuid,
  resource_chat_id uuid,
  resource_chat_message_id uuid,
  resource_agreement_id uuid,
  resource_agreement_event_id uuid,
  destination_kind text,
  source_created_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  stale_target record;
  candidate record;
  new_lease_id uuid;
  claim_time timestamptz;
  claim_expires_at timestamptz;
  new_attempt_number integer;
begin
  if p_worker_id is null
    or p_worker_id <> btrim(p_worker_id)
    or char_length(p_worker_id) not between 1 and 128 then
    raise exception using
      errcode = '22023',
      message = 'Push delivery worker ID must contain 1 to 128 trimmed characters.';
  end if;

  if p_limit is null or p_limit not between 1 and 100 then
    raise exception using
      errcode = '22023',
      message = 'Push delivery claim batch size must be between 1 and 100.';
  end if;

  if p_lease_seconds is null or p_lease_seconds not between 1 and 3600 then
    raise exception using
      errcode = '22023',
      message = 'Push delivery lease must be between 1 and 3600 seconds.';
  end if;

  for stale_target in
    select
      target.id as candidate_target_id,
      target.job_id as candidate_job_id
    from private.push_delivery_targets as target
    join private.push_delivery_jobs as job on job.id = target.job_id
    left join private.push_installations as installation
      on installation.installation_id = target.installation_id
      and installation.profile_id = job.recipient_profile_id
      and installation.disabled_at is null
      and installation.provider_token is not null
    where target.status = 'pending'
      and target.available_at <= statement_timestamp()
      and (
        target.lease_id is null
        or target.lease_expires_at <= statement_timestamp()
      )
      and installation.installation_id is null
    order by target.available_at, target.created_at, target.id
    limit p_limit
    for update of target skip locked
  loop
    update private.push_delivery_targets as target
    set
      status = 'no_longer_registered',
      lease_owner = null,
      lease_id = null,
      lease_expires_at = null,
      updated_at = statement_timestamp(),
      completed_at = statement_timestamp()
    where target.id = stale_target.candidate_target_id;

    perform private.complete_push_delivery_job_if_terminal(
      stale_target.candidate_job_id
    );
  end loop;

  for candidate in
    select
      target.id as candidate_target_id,
      target.job_id as candidate_job_id,
      target.installation_id as candidate_installation_id,
      installation.platform as candidate_platform,
      installation.provider as candidate_provider,
      installation.provider_token as candidate_provider_token,
      installation.token_version as candidate_token_version,
      job.category_slug as candidate_category_slug,
      job.notification_kind as candidate_notification_kind,
      job.recipient_profile_id as candidate_recipient_profile_id,
      job.actor_profile_id as candidate_actor_profile_id,
      job.project_id as candidate_project_id,
      job.project_kind as candidate_project_kind,
      job.request_id as candidate_request_id,
      job.membership_id as candidate_membership_id,
      job.chat_id as candidate_chat_id,
      job.message_id as candidate_message_id,
      job.resource_listing_id as candidate_resource_listing_id,
      job.resource_request_id as candidate_resource_request_id,
      job.resource_chat_id as candidate_resource_chat_id,
      job.resource_chat_message_id as candidate_resource_chat_message_id,
      job.resource_agreement_id as candidate_resource_agreement_id,
      job.resource_agreement_event_id
        as candidate_resource_agreement_event_id,
      job.destination_kind as candidate_destination_kind,
      job.created_at as candidate_source_created_at
    from private.push_delivery_targets as target
    join private.push_delivery_jobs as job on job.id = target.job_id
    join private.push_installations as installation
      on installation.installation_id = target.installation_id
      and installation.profile_id = job.recipient_profile_id
      and installation.disabled_at is null
      and installation.provider_token is not null
    where target.status = 'pending'
      and target.available_at <= statement_timestamp()
      and (
        target.lease_id is null
        or target.lease_expires_at <= statement_timestamp()
      )
    order by target.available_at, target.created_at, target.id
    limit p_limit
    for update of target, installation skip locked
  loop
    claim_time := statement_timestamp();
    claim_expires_at := claim_time
      + pg_catalog.make_interval(secs => p_lease_seconds);
    new_lease_id := gen_random_uuid();

    update private.push_delivery_targets as target
    set
      attempt_count = target.attempt_count + 1,
      lease_owner = p_worker_id,
      lease_id = new_lease_id,
      lease_expires_at = claim_expires_at,
      updated_at = claim_time
    where target.id = candidate.candidate_target_id
    returning target.attempt_count into new_attempt_number;

    insert into private.push_delivery_attempts (
      target_id,
      attempt_number,
      lease_id,
      worker_id,
      token_version,
      started_at
    )
    values (
      candidate.candidate_target_id,
      new_attempt_number,
      new_lease_id,
      p_worker_id,
      candidate.candidate_token_version,
      claim_time
    );

    return query select
      candidate.candidate_target_id,
      candidate.candidate_job_id,
      new_lease_id,
      claim_expires_at,
      new_attempt_number,
      candidate.candidate_installation_id,
      candidate.candidate_platform,
      candidate.candidate_provider,
      candidate.candidate_provider_token,
      candidate.candidate_token_version,
      candidate.candidate_category_slug,
      candidate.candidate_notification_kind,
      candidate.candidate_recipient_profile_id,
      candidate.candidate_actor_profile_id,
      candidate.candidate_project_id,
      candidate.candidate_project_kind,
      candidate.candidate_request_id,
      candidate.candidate_membership_id,
      candidate.candidate_chat_id,
      candidate.candidate_message_id,
      candidate.candidate_resource_listing_id,
      candidate.candidate_resource_request_id,
      candidate.candidate_resource_chat_id,
      candidate.candidate_resource_chat_message_id,
      candidate.candidate_resource_agreement_id,
      candidate.candidate_resource_agreement_event_id,
      candidate.candidate_destination_kind,
      candidate.candidate_source_created_at;
  end loop;
end;
$$;

revoke all privileges on function
  private.claim_push_delivery_targets(text, integer, integer)
  from public, anon, authenticated, service_role;
grant execute on function
  private.claim_push_delivery_targets(text, integer, integer)
  to service_role;

comment on function private.claim_push_delivery_targets(
  text,
  integer,
  integer
) is
  'Claims due delivery targets and returns private provider credentials plus body-free Project or Resource semantic destination context only to service_role.';
