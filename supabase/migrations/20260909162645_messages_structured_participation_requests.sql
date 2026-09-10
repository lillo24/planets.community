create index project_join_requests_requester_activity_idx
  on public.project_join_requests (
    requester_profile_id,
    (coalesce(resolved_at, created_at)) desc,
    id desc
  );

create index project_join_requests_project_activity_idx
  on public.project_join_requests (
    project_id,
    (coalesce(resolved_at, created_at)) desc,
    id desc
  );

comment on index public.project_join_requests_requester_activity_idx is
  'Supports keyset-paginated outgoing structured participation messages.';
comment on index public.project_join_requests_project_activity_idx is
  'Supports keyset-paginated incoming structured participation messages.';

create function public.list_own_participation_request_message_items(
  p_expected_profile_id uuid,
  p_limit integer,
  p_cursor_activity_at timestamptz default null,
  p_cursor_request_id uuid default null
)
returns table (
  request_id uuid,
  project_id uuid,
  project_kind text,
  project_title text,
  viewer_role text,
  requester_profile_id uuid,
  requester_display_name text,
  creator_profile_id uuid,
  creator_display_name text,
  request_message text,
  status text,
  created_at timestamptz,
  resolved_at timestamptz,
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
      message = 'The message page size must be between 1 and 50.';
  end if;

  if (p_cursor_activity_at is null) <> (p_cursor_request_id is null) then
    raise exception using
      errcode = '22023',
      message = 'Both message cursor values must be provided together.';
  end if;

  return query
  with authorized_requests as (
    select
      outgoing.id,
      outgoing.project_id,
      outgoing.requester_profile_id,
      outgoing.status,
      outgoing.request_message,
      outgoing.created_at,
      outgoing.resolved_at,
      coalesce(outgoing.resolved_at, outgoing.created_at) as activity_at,
      'requester'::text as viewer_role
    from public.project_join_requests as outgoing
    where outgoing.requester_profile_id = current_profile_id
      and (
        p_cursor_activity_at is null
        or (
          coalesce(outgoing.resolved_at, outgoing.created_at),
          outgoing.id
        ) < (p_cursor_activity_at, p_cursor_request_id)
      )

    union all

    select
      incoming.id,
      incoming.project_id,
      incoming.requester_profile_id,
      incoming.status,
      incoming.request_message,
      incoming.created_at,
      incoming.resolved_at,
      coalesce(incoming.resolved_at, incoming.created_at) as activity_at,
      'creator'::text as viewer_role
    from public.project_join_requests as incoming
    join public.projects as owned_project
      on owned_project.id = incoming.project_id
    where owned_project.creator_profile_id = current_profile_id
      and (
        p_cursor_activity_at is null
        or (
          coalesce(incoming.resolved_at, incoming.created_at),
          incoming.id
        ) < (p_cursor_activity_at, p_cursor_request_id)
      )
  )
  select
    authorized.id,
    project.id,
    project.project_kind,
    case project.project_kind
      when 'one_time' then proposal.title
      when 'recurring' then activity.title
    end,
    authorized.viewer_role,
    authorized.requester_profile_id,
    requester.display_name,
    project.creator_profile_id,
    creator.display_name,
    authorized.request_message,
    authorized.status,
    authorized.created_at,
    authorized.resolved_at,
    authorized.activity_at
  from authorized_requests as authorized
  join public.projects as project on project.id = authorized.project_id
  join public.profiles as requester
    on requester.id = authorized.requester_profile_id
  join public.profiles as creator on creator.id = project.creator_profile_id
  left join public.proposals as proposal
    on proposal.id = project.id
    and project.project_kind = 'one_time'
  left join public.recurring_activities as activity
    on activity.id = project.id
    and project.project_kind = 'recurring'
  order by authorized.activity_at desc, authorized.id desc
  limit p_limit;
end;
$$;

create function public.get_own_participation_request_message_item(
  p_expected_profile_id uuid,
  p_request_id uuid
)
returns table (
  request_id uuid,
  project_id uuid,
  project_kind text,
  project_title text,
  viewer_role text,
  requester_profile_id uuid,
  requester_display_name text,
  creator_profile_id uuid,
  creator_display_name text,
  request_message text,
  status text,
  created_at timestamptz,
  resolved_at timestamptz,
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
  if p_request_id is null or not exists (
    select 1
    from public.project_join_requests as request
    join public.projects as project on project.id = request.project_id
    where request.id = p_request_id
      and (
        request.requester_profile_id = current_profile_id
        or project.creator_profile_id = current_profile_id
      )
  ) then
    raise exception using
      errcode = '42501',
      message = 'The participation request message item is unavailable.';
  end if;

  return query
  select
    request.id,
    project.id,
    project.project_kind,
    case project.project_kind
      when 'one_time' then proposal.title
      when 'recurring' then activity.title
    end,
    case
      when request.requester_profile_id = current_profile_id then 'requester'
      else 'creator'
    end,
    request.requester_profile_id,
    requester.display_name,
    project.creator_profile_id,
    creator.display_name,
    request.request_message,
    request.status,
    request.created_at,
    request.resolved_at,
    coalesce(request.resolved_at, request.created_at)
  from public.project_join_requests as request
  join public.projects as project on project.id = request.project_id
  join public.profiles as requester
    on requester.id = request.requester_profile_id
  join public.profiles as creator on creator.id = project.creator_profile_id
  left join public.proposals as proposal
    on proposal.id = project.id
    and project.project_kind = 'one_time'
  left join public.recurring_activities as activity
    on activity.id = project.id
    and project.project_kind = 'recurring'
  where request.id = p_request_id;
end;
$$;

revoke all privileges on function
  public.list_own_participation_request_message_items(
    uuid,
    integer,
    timestamptz,
    uuid
  )
  from public, anon, authenticated, service_role;
revoke all privileges on function
  public.get_own_participation_request_message_item(uuid, uuid)
  from public, anon, authenticated, service_role;

grant execute on function
  public.list_own_participation_request_message_items(
    uuid,
    integer,
    timestamptz,
    uuid
  )
  to authenticated;
grant execute on function
  public.get_own_participation_request_message_item(uuid, uuid)
  to authenticated;

comment on function public.list_own_participation_request_message_items(
  uuid,
  integer,
  timestamptz,
  uuid
) is
  'Returns a bounded, keyset-paginated structured participation-request inbox to the requester or project creator only.';
comment on function public.get_own_participation_request_message_item(uuid, uuid)
is
  'Returns one structured participation-request message to its requester or project creator, failing closed for all other lookups.';
