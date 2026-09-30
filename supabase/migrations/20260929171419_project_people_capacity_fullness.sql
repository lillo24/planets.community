-- PLANETS 05E: one cross-kind total-people capacity, derived occupancy, and
-- serialized fullness enforcement. The immutable Creator is the first person;
-- current memberships are the remaining people.

alter table public.projects
  add column people_capacity integer;

alter table public.projects
  add constraint projects_people_capacity_bounds_check
  check (people_capacity is null or people_capacity between 1 and 100000);

comment on column public.projects.people_capacity is
  'Maximum total people in the Project, including the immutable original Creator. Null is allowed only for drafts and legacy published Projects whose capacity has not yet been set.';

comment on table public.projects is
  'Private cross-domain Project registry and shared participation configuration. It anchors immutable kind/Creator identity and the optional canonical total-people capacity for Proposals and Tavoli.';

create index project_memberships_current_project_idx
  on public.project_memberships (project_id)
  where left_at is null and removed_at is null;

create function private.project_capacity_snapshot(p_project_id uuid)
returns table (
  people_capacity integer,
  current_participant_count integer,
  current_people_count integer,
  spots_remaining integer,
  is_full boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  with occupancy as (
    select
      project.people_capacity,
      count(membership.id)::integer as participant_count
    from public.projects as project
    left join public.project_memberships as membership
      on membership.project_id = project.id
      and membership.left_at is null
      and membership.removed_at is null
    where project.id = p_project_id
    group by project.id, project.people_capacity
  )
  select
    occupancy.people_capacity,
    occupancy.participant_count,
    1 + occupancy.participant_count,
    case
      when occupancy.people_capacity is null then null
      else greatest(
        occupancy.people_capacity - (1 + occupancy.participant_count),
        0
      )
    end,
    occupancy.people_capacity is not null
      and 1 + occupancy.participant_count >= occupancy.people_capacity
  from occupancy;
$$;

revoke all on function private.project_capacity_snapshot(uuid) from public;

create function private.assert_project_has_membership_capacity(
  p_project_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  capacity_record record;
begin
  -- Canonical participation callers already hold this row. Reacquiring it is
  -- intentional: the trigger also protects any future membership writer.
  perform 1
  from public.projects as project
  where project.id = p_project_id
  for update;

  select * into capacity_record
  from private.project_capacity_snapshot(p_project_id);

  if capacity_record.people_capacity is not null
    and capacity_record.is_full then
    raise exception using
      errcode = 'PT409',
      message = 'This Project is full.';
  end if;
end;
$$;

revoke all on function private.assert_project_has_membership_capacity(uuid)
  from public;

create function private.enforce_join_request_capacity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'pending' then
    perform private.assert_project_has_membership_capacity(new.project_id);
  end if;
  return new;
end;
$$;

revoke all on function private.enforce_join_request_capacity() from public;

create trigger project_join_requests_enforce_capacity
before insert on public.project_join_requests
for each row execute function private.enforce_join_request_capacity();

create function private.enforce_membership_capacity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.left_at is null
    and new.removed_at is null
    and (
      tg_op = 'INSERT'
      or old.left_at is not null
      or old.removed_at is not null
    ) then
    perform private.assert_project_has_membership_capacity(new.project_id);
  end if;
  return new;
end;
$$;

revoke all on function private.enforce_membership_capacity() from public;

create trigger project_memberships_enforce_capacity
before insert or update of left_at, removed_at on public.project_memberships
for each row execute function private.enforce_membership_capacity();

create function private.set_project_people_capacity_for_structural_edit(
  p_expected_profile_id uuid,
  p_project_id uuid,
  p_people_capacity integer
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_expected_identity(
    p_expected_profile_id
  );
  resolved_project_kind text;
  resolved_creator_profile_id uuid;
  resolved_lifecycle_state text;
  resolved_starts_at timestamptz;
  current_people_count integer;
begin
  if p_people_capacity is not null
    and p_people_capacity not between 1 and 100000 then
    raise exception using
      errcode = '22023',
      message = 'People capacity must be between 1 and 100,000.';
  end if;

  select project.project_kind into resolved_project_kind
  from public.projects as project
  where project.id = p_project_id;

  if resolved_project_kind = 'one_time' then
    select
      proposal.creator_profile_id,
      proposal.lifecycle_state,
      proposal.starts_at
    into resolved_creator_profile_id, resolved_lifecycle_state, resolved_starts_at
    from public.proposals as proposal
    where proposal.id = p_project_id
    for update;

    if not found
      or (
        resolved_creator_profile_id <> current_profile_id
        and not private.profile_has_project_structural_authority(
          p_project_id,
          current_profile_id
        )
      ) then
      raise exception using
        errcode = '42501',
        message = 'The Project capacity is unavailable.';
    end if;

    if resolved_creator_profile_id <> current_profile_id
      and resolved_lifecycle_state = 'draft' then
      raise exception using
        errcode = '42501',
        message = 'Only the original Creator can edit a Project draft.';
    end if;

    if resolved_lifecycle_state = 'published'
      and resolved_starts_at <= statement_timestamp() then
      raise exception using
        errcode = '55000',
        message = 'A published Proposal capacity cannot be edited after it starts.';
    end if;

    if resolved_lifecycle_state not in ('draft', 'published') then
      raise exception using
        errcode = '55000',
        message = 'This Proposal capacity can no longer be edited.';
    end if;
  elsif resolved_project_kind = 'recurring' then
    select
      activity.creator_profile_id,
      activity.lifecycle_state
    into resolved_creator_profile_id, resolved_lifecycle_state
    from public.recurring_activities as activity
    where activity.id = p_project_id
    for update;

    if not found
      or (
        resolved_creator_profile_id <> current_profile_id
        and not private.profile_has_project_structural_authority(
          p_project_id,
          current_profile_id
        )
      ) then
      raise exception using
        errcode = '42501',
        message = 'The Project capacity is unavailable.';
    end if;

    if resolved_creator_profile_id <> current_profile_id
      and resolved_lifecycle_state = 'draft' then
      raise exception using
        errcode = '42501',
        message = 'Only the original Creator can edit a Project draft.';
    end if;

    if resolved_lifecycle_state = 'ended' then
      raise exception using
        errcode = '55000',
        message = 'An ended Tavolo capacity is immutable.';
    end if;
  else
    raise exception using
      errcode = '42501',
      message = 'The Project capacity is unavailable.';
  end if;

  -- Preserve the established concrete-Project -> shared-Project lock order.
  perform 1
  from public.projects as project
  where project.id = p_project_id
    and project.project_kind = resolved_project_kind
    and project.creator_profile_id = resolved_creator_profile_id
  for update;

  if not found then
    raise exception using
      errcode = '42501',
      message = 'The Project capacity is unavailable.';
  end if;

  select snapshot.current_people_count into current_people_count
  from private.project_capacity_snapshot(p_project_id) as snapshot;

  if resolved_lifecycle_state <> 'draft' and p_people_capacity is null then
    raise exception using
      errcode = '22023',
      message = 'People capacity is required for a published Project.';
  end if;

  if p_people_capacity is not null
    and p_people_capacity < current_people_count then
    raise exception using
      errcode = '22023',
      message = 'People capacity cannot be lower than the current people count.';
  end if;

  update public.projects
  set people_capacity = p_people_capacity
  where id = p_project_id;
end;
$$;

revoke all on function private.set_project_people_capacity_for_structural_edit(
  uuid,
  uuid,
  integer
) from public;

create function private.require_capacity_for_project_publication()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  configured_capacity integer;
begin
  if old.lifecycle_state = 'draft' and new.lifecycle_state = 'published' then
    select project.people_capacity into configured_capacity
    from public.projects as project
    where project.id = new.id
    for update;

    if configured_capacity is null then
      raise exception using
        errcode = '22023',
        message = 'People capacity is required before publication.';
    end if;
  end if;
  return new;
end;
$$;

revoke all on function private.require_capacity_for_project_publication()
  from public;

create trigger proposals_require_capacity_for_publication
before update of lifecycle_state on public.proposals
for each row execute function private.require_capacity_for_project_publication();

create trigger recurring_activities_require_capacity_for_publication
before update of lifecycle_state on public.recurring_activities
for each row execute function private.require_capacity_for_project_publication();

create function private.require_capacity_for_legacy_structural_edit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_project_id uuid;
  target_lifecycle text;
  configured_capacity integer;
begin
  if tg_table_name = 'proposals' then
    target_project_id := new.id;
    target_lifecycle := new.lifecycle_state;
  elsif tg_table_name = 'recurring_activities' then
    target_project_id := new.id;
    target_lifecycle := new.lifecycle_state;
  elsif tg_table_name = 'proposal_skills' then
    target_project_id := coalesce(new.proposal_id, old.proposal_id);
    select proposal.lifecycle_state into target_lifecycle
    from public.proposals as proposal
    where proposal.id = target_project_id;
  else
    target_project_id := coalesce(
      new.recurring_activity_id,
      old.recurring_activity_id
    );
    select activity.lifecycle_state into target_lifecycle
    from public.recurring_activities as activity
    where activity.id = target_project_id;
  end if;

  if target_lifecycle in ('published', 'paused') then
    select project.people_capacity into configured_capacity
    from public.projects as project
    where project.id = target_project_id;

    if configured_capacity is null then
      raise exception using
        errcode = '22023',
        message = 'Set people capacity before saving structural changes to this legacy Project.';
    end if;
  end if;

  return coalesce(new, old);
end;
$$;

revoke all on function private.require_capacity_for_legacy_structural_edit()
  from public;

create trigger proposals_require_capacity_for_structural_edit
before update of
  title,
  summary,
  description,
  starts_at,
  ends_at,
  event_timezone,
  country_code,
  locality,
  administrative_area,
  public_location_label
on public.proposals
for each row execute function private.require_capacity_for_legacy_structural_edit();

create trigger recurring_activities_require_capacity_for_structural_edit
before update of
  title,
  summary,
  description,
  topic,
  country_code,
  locality,
  administrative_area,
  public_location_label
on public.recurring_activities
for each row execute function private.require_capacity_for_legacy_structural_edit();

create function public.create_proposal_draft(
  p_expected_creator_profile_id uuid,
  p_title text,
  p_summary text,
  p_description text,
  p_starts_at timestamptz,
  p_ends_at timestamptz,
  p_event_timezone text,
  p_country_code text,
  p_locality text,
  p_administrative_area text,
  p_public_location_label text,
  p_exact_meeting_text text,
  p_exact_location_visibility text,
  p_skill_ids uuid[],
  p_skill_importances text[],
  p_people_capacity integer
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  new_project_id uuid;
begin
  if p_people_capacity is not null
    and p_people_capacity not between 1 and 100000 then
    raise exception using
      errcode = '22023',
      message = 'People capacity must be between 1 and 100,000.';
  end if;

  new_project_id := public.create_proposal_draft(
    p_expected_creator_profile_id,
    p_title,
    p_summary,
    p_description,
    p_starts_at,
    p_ends_at,
    p_event_timezone,
    p_country_code,
    p_locality,
    p_administrative_area,
    p_public_location_label,
    p_exact_meeting_text,
    p_exact_location_visibility,
    p_skill_ids,
    p_skill_importances
  );

  update public.projects
  set people_capacity = p_people_capacity
  where id = new_project_id;

  return new_project_id;
end;
$$;

create function public.update_own_proposal(
  p_expected_creator_profile_id uuid,
  p_proposal_id uuid,
  p_title text,
  p_summary text,
  p_description text,
  p_starts_at timestamptz,
  p_ends_at timestamptz,
  p_event_timezone text,
  p_country_code text,
  p_locality text,
  p_administrative_area text,
  p_public_location_label text,
  p_exact_meeting_text text,
  p_exact_location_visibility text,
  p_skill_ids uuid[],
  p_skill_importances text[],
  p_people_capacity integer
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.set_project_people_capacity_for_structural_edit(
    p_expected_creator_profile_id,
    p_proposal_id,
    p_people_capacity
  );

  return public.update_own_proposal(
    p_expected_creator_profile_id,
    p_proposal_id,
    p_title,
    p_summary,
    p_description,
    p_starts_at,
    p_ends_at,
    p_event_timezone,
    p_country_code,
    p_locality,
    p_administrative_area,
    p_public_location_label,
    p_exact_meeting_text,
    p_exact_location_visibility,
    p_skill_ids,
    p_skill_importances
  );
end;
$$;

create function public.create_recurring_activity_draft(
  p_expected_creator_profile_id uuid,
  p_title text,
  p_summary text,
  p_description text,
  p_topic text,
  p_country_code text,
  p_locality text,
  p_administrative_area text,
  p_public_location_label text,
  p_exact_meeting_text text,
  p_exact_location_visibility text,
  p_recurrence_type text,
  p_weekday integer,
  p_day_of_month integer,
  p_local_start_time time without time zone,
  p_duration_minutes integer,
  p_event_timezone text,
  p_effective_from date,
  p_people_capacity integer
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  new_project_id uuid;
begin
  if p_people_capacity is not null
    and p_people_capacity not between 1 and 100000 then
    raise exception using
      errcode = '22023',
      message = 'People capacity must be between 1 and 100,000.';
  end if;

  new_project_id := public.create_recurring_activity_draft(
    p_expected_creator_profile_id,
    p_title,
    p_summary,
    p_description,
    p_topic,
    p_country_code,
    p_locality,
    p_administrative_area,
    p_public_location_label,
    p_exact_meeting_text,
    p_exact_location_visibility,
    p_recurrence_type,
    p_weekday,
    p_day_of_month,
    p_local_start_time,
    p_duration_minutes,
    p_event_timezone,
    p_effective_from
  );

  update public.projects
  set people_capacity = p_people_capacity
  where id = new_project_id;

  return new_project_id;
end;
$$;

create function public.update_own_recurring_activity(
  p_expected_creator_profile_id uuid,
  p_recurring_activity_id uuid,
  p_title text,
  p_summary text,
  p_description text,
  p_topic text,
  p_country_code text,
  p_locality text,
  p_administrative_area text,
  p_public_location_label text,
  p_exact_meeting_text text,
  p_exact_location_visibility text,
  p_recurrence_type text,
  p_weekday integer,
  p_day_of_month integer,
  p_local_start_time time without time zone,
  p_duration_minutes integer,
  p_event_timezone text,
  p_effective_from date,
  p_people_capacity integer
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.set_project_people_capacity_for_structural_edit(
    p_expected_creator_profile_id,
    p_recurring_activity_id,
    p_people_capacity
  );

  return public.update_own_recurring_activity(
    p_expected_creator_profile_id,
    p_recurring_activity_id,
    p_title,
    p_summary,
    p_description,
    p_topic,
    p_country_code,
    p_locality,
    p_administrative_area,
    p_public_location_label,
    p_exact_meeting_text,
    p_exact_location_visibility,
    p_recurrence_type,
    p_weekday,
    p_day_of_month,
    p_local_start_time,
    p_duration_minutes,
    p_event_timezone,
    p_effective_from
  );
end;
$$;

create function public.list_public_project_capacity_statuses(
  p_project_ids uuid[]
)
returns table (
  project_id uuid,
  people_capacity integer,
  current_participant_count integer,
  current_people_count integer,
  spots_remaining integer,
  is_full boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  normalized_ids uuid[] := coalesce(p_project_ids, '{}'::uuid[]);
begin
  if cardinality(normalized_ids) > 100
    or cardinality(normalized_ids) <> (
      select count(distinct requested.id)
      from unnest(normalized_ids) as requested(id)
    ) then
    raise exception using
      errcode = '22023',
      message = 'Capacity reads require at most 100 unique Project identifiers.';
  end if;

  return query
  select
    requested.id,
    snapshot.people_capacity,
    snapshot.current_participant_count,
    snapshot.current_people_count,
    snapshot.spots_remaining,
    snapshot.is_full
  from unnest(normalized_ids) with ordinality as requested(id, position)
  cross join lateral private.project_capacity_snapshot(requested.id) as snapshot
  where exists (
    select 1
    from public.proposals as proposal
    where proposal.id = requested.id
      and proposal.lifecycle_state = 'published'
    union all
    select 1
    from public.recurring_activities as activity
    where activity.id = requested.id
      and activity.lifecycle_state in ('published', 'paused', 'ended')
  )
  order by requested.position;
end;
$$;

create function public.list_project_capacity_statuses_for_structural_actor(
  p_expected_profile_id uuid,
  p_project_ids uuid[]
)
returns table (
  project_id uuid,
  people_capacity integer,
  current_participant_count integer,
  current_people_count integer,
  spots_remaining integer,
  is_full boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_expected_identity(
    p_expected_profile_id
  );
  normalized_ids uuid[] := coalesce(p_project_ids, '{}'::uuid[]);
begin
  if cardinality(normalized_ids) > 100
    or cardinality(normalized_ids) <> (
      select count(distinct requested.id)
      from unnest(normalized_ids) as requested(id)
    ) then
    raise exception using
      errcode = '22023',
      message = 'Capacity reads require at most 100 unique Project identifiers.';
  end if;

  return query
  select
    requested.id,
    snapshot.people_capacity,
    snapshot.current_participant_count,
    snapshot.current_people_count,
    snapshot.spots_remaining,
    snapshot.is_full
  from unnest(normalized_ids) with ordinality as requested(id, position)
  join public.projects as project on project.id = requested.id
  cross join lateral private.project_capacity_snapshot(requested.id) as snapshot
  where (
    project.creator_profile_id = current_profile_id
    or private.profile_has_project_structural_authority(
      project.id,
      current_profile_id
    )
  )
  and not (
    project.creator_profile_id <> current_profile_id
    and (
      exists (
        select 1 from public.proposals as proposal
        where proposal.id = project.id and proposal.lifecycle_state = 'draft'
      )
      or exists (
        select 1 from public.recurring_activities as activity
        where activity.id = project.id and activity.lifecycle_state = 'draft'
      )
    )
  )
  order by requested.position;
end;
$$;

create function public.get_project_capacity_for_manager(
  p_expected_manager_profile_id uuid,
  p_project_id uuid
)
returns table (
  project_id uuid,
  people_capacity integer,
  current_participant_count integer,
  current_people_count integer,
  spots_remaining integer,
  is_full boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_participation_identity(
    p_expected_manager_profile_id
  );
begin
  if not private.profile_is_project_manager(
    p_project_id,
    current_profile_id
  ) then
    raise exception using
      errcode = '42501',
      message = 'The Project capacity status is unavailable.';
  end if;

  return query
  select
    p_project_id,
    snapshot.people_capacity,
    snapshot.current_participant_count,
    snapshot.current_people_count,
    snapshot.spots_remaining,
    snapshot.is_full
  from private.project_capacity_snapshot(p_project_id) as snapshot;
end;
$$;

revoke all on function public.create_proposal_draft(
  uuid, text, text, text, timestamptz, timestamptz, text, text, text, text,
  text, text, text, uuid[], text[], integer
) from public, anon;
grant execute on function public.create_proposal_draft(
  uuid, text, text, text, timestamptz, timestamptz, text, text, text, text,
  text, text, text, uuid[], text[], integer
) to authenticated;

revoke all on function public.update_own_proposal(
  uuid, uuid, text, text, text, timestamptz, timestamptz, text, text, text,
  text, text, text, text, uuid[], text[], integer
) from public, anon;
grant execute on function public.update_own_proposal(
  uuid, uuid, text, text, text, timestamptz, timestamptz, text, text, text,
  text, text, text, text, uuid[], text[], integer
) to authenticated;

revoke all on function public.create_recurring_activity_draft(
  uuid, text, text, text, text, text, text, text, text, text, text, text,
  integer, integer, time without time zone, integer, text, date, integer
) from public, anon;
grant execute on function public.create_recurring_activity_draft(
  uuid, text, text, text, text, text, text, text, text, text, text, text,
  integer, integer, time without time zone, integer, text, date, integer
) to authenticated;

revoke all on function public.update_own_recurring_activity(
  uuid, uuid, text, text, text, text, text, text, text, text, text, text, text,
  integer, integer, time without time zone, integer, text, date, integer
) from public, anon;
grant execute on function public.update_own_recurring_activity(
  uuid, uuid, text, text, text, text, text, text, text, text, text, text, text,
  integer, integer, time without time zone, integer, text, date, integer
) to authenticated;

revoke all on function public.list_public_project_capacity_statuses(uuid[])
  from public;
grant execute on function public.list_public_project_capacity_statuses(uuid[])
  to anon, authenticated;

revoke all on function public.list_project_capacity_statuses_for_structural_actor(
  uuid,
  uuid[]
) from public, anon;
grant execute on function public.list_project_capacity_statuses_for_structural_actor(
  uuid,
  uuid[]
) to authenticated;

revoke all on function public.get_project_capacity_for_manager(uuid, uuid)
  from public, anon;
grant execute on function public.get_project_capacity_for_manager(uuid, uuid)
  to authenticated;

comment on function public.list_public_project_capacity_statuses(uuid[]) is
  'Returns aggregate-only capacity and occupancy for publicly readable Projects; no membership or request identities are exposed.';
comment on function public.list_project_capacity_statuses_for_structural_actor(uuid, uuid[]) is
  'Returns canonical capacity and occupancy for Projects structurally manageable by the expected Creator or current Co-creator.';
comment on function public.get_project_capacity_for_manager(uuid, uuid) is
  'Returns canonical capacity and occupancy to a current Project manager for participation management.';
