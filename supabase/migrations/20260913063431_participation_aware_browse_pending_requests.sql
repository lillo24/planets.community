create index project_join_requests_requester_pending_created_at_idx
  on public.project_join_requests (
    requester_profile_id,
    created_at desc,
    project_id desc
  )
  where status = 'pending';

create function public.list_own_pending_requested_proposals(
  p_expected_requester_profile_id uuid,
  p_locality text default null,
  p_skill_ids uuid[] default null
)
returns table (
  proposal_id uuid,
  request_id uuid,
  request_created_at timestamptz,
  title text,
  summary text,
  starts_at timestamptz,
  ends_at timestamptz,
  event_timezone text,
  country_code text,
  locality text,
  administrative_area text,
  public_location_label text,
  derived_status text,
  skills jsonb
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_complete_participation_profile(
    p_expected_requester_profile_id
  );
  normalized_locality text := nullif(btrim(p_locality), '');
begin
  if p_skill_ids is not null and array_position(p_skill_ids, null) is not null then
    raise exception using
      errcode = '22023',
      message = 'Requested Proposal skill filters cannot contain null identifiers.';
  end if;

  return query
  select
    proposal.id,
    request.id,
    request.created_at,
    proposal.title,
    proposal.summary,
    proposal.starts_at,
    proposal.ends_at,
    proposal.event_timezone,
    proposal.country_code,
    proposal.locality,
    proposal.administrative_area,
    proposal.public_location_label,
    private.derive_proposal_status(
      proposal.starts_at,
      proposal.ends_at,
      statement_timestamp()
    ),
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', skill.id,
            'slug', skill.slug,
            'label', skill.label,
            'category_id', category.id,
            'category_slug', category.slug,
            'category_label', category.label,
            'importance', proposal_skill.importance
          )
          order by
            case proposal_skill.importance when 'required' then 0 else 1 end,
            category.sort_order,
            skill.sort_order
        )
        from public.proposal_skills as proposal_skill
        join public.skills as skill on skill.id = proposal_skill.skill_id
        join public.skill_categories as category on category.id = skill.category_id
        where proposal_skill.proposal_id = proposal.id
      ),
      '[]'::jsonb
    )
  from public.project_join_requests as request
  join public.proposals as proposal on proposal.id = request.project_id
  where request.requester_profile_id = current_profile_id
    and request.status = 'pending'
    and proposal.lifecycle_state = 'published'
    and proposal.ends_at > statement_timestamp() - interval '24 hours'
    and (
      normalized_locality is null
      or lower(proposal.locality) = lower(normalized_locality)
    )
    and (
      coalesce(cardinality(p_skill_ids), 0) = 0
      or exists (
        select 1
        from public.proposal_skills as filtered_skill
        where filtered_skill.proposal_id = proposal.id
          and filtered_skill.skill_id = any(p_skill_ids)
      )
    )
  order by request.created_at desc, proposal.id desc
  limit 200;
end;
$$;

create function public.list_own_pending_requested_recurring_activities(
  p_expected_requester_profile_id uuid,
  p_reference_time timestamptz,
  p_locality text default null
)
returns table (
  recurring_activity_id uuid,
  request_id uuid,
  request_created_at timestamptz,
  title text,
  summary text,
  topic text,
  country_code text,
  locality text,
  administrative_area text,
  public_location_label text,
  next_starts_at timestamptz,
  next_ends_at timestamptz,
  event_timezone text,
  recurrence_type text,
  weekday smallint,
  day_of_month smallint,
  local_start_time time without time zone,
  duration_minutes integer,
  schedule_effective_from date
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_complete_participation_profile(
    p_expected_requester_profile_id
  );
  normalized_locality text := nullif(btrim(p_locality), '');
begin
  if p_reference_time is null then
    raise exception using
      errcode = '22023',
      message = 'Requested Tavolo discovery requires a reference time.';
  end if;

  return query
  select
    activity.id,
    request.id,
    request.created_at,
    activity.title,
    activity.summary,
    activity.topic,
    activity.country_code,
    activity.locality,
    activity.administrative_area,
    activity.public_location_label,
    next_occurrence.starts_at,
    next_occurrence.ends_at,
    next_occurrence.event_timezone,
    schedule.recurrence_type,
    schedule.weekday,
    schedule.day_of_month,
    schedule.local_start_time,
    schedule.duration_minutes,
    schedule.effective_from
  from public.project_join_requests as request
  join public.recurring_activities as activity
    on activity.id = request.project_id
  cross join lateral private.next_recurring_activity_occurrence(
    activity.id,
    p_reference_time
  ) as next_occurrence
  join public.recurring_activity_schedules as schedule
    on schedule.id = next_occurrence.schedule_version_id
  where request.requester_profile_id = current_profile_id
    and request.status = 'pending'
    and activity.lifecycle_state = 'published'
    and (
      normalized_locality is null
      or lower(activity.locality) = lower(normalized_locality)
    )
  order by request.created_at desc, activity.id desc
  limit 200;
end;
$$;

revoke all privileges on function public.list_own_pending_requested_proposals(
  uuid,
  text,
  uuid[]
) from public, anon, authenticated, service_role;
revoke all privileges on function public.list_own_pending_requested_recurring_activities(
  uuid,
  timestamptz,
  text
) from public, anon, authenticated, service_role;

grant execute on function public.list_own_pending_requested_proposals(
  uuid,
  text,
  uuid[]
) to authenticated;
grant execute on function public.list_own_pending_requested_recurring_activities(
  uuid,
  timestamptz,
  text
) to authenticated;

comment on function public.list_own_pending_requested_proposals(
  uuid,
  text,
  uuid[]
) is
  'Returns at most 200 sanitized, publicly discoverable Proposal cards for the expected identity current pending requests, newest request first.';
comment on function public.list_own_pending_requested_recurring_activities(
  uuid,
  timestamptz,
  text
) is
  'Returns at most 200 sanitized, publicly discoverable Tavolo cards for the expected identity current pending requests, newest request first.';
