-- PLANETS 05E1: distinguish registration-capacity usage from the unique
-- public/social headcount. The Creator and active delegated actors are
-- organizers; current memberships held by organizers are never double-counted.

alter table public.projects
  rename column people_capacity to registration_capacity;

alter table public.projects
  rename constraint projects_people_capacity_bounds_check
  to projects_registration_capacity_bounds_check;

alter table public.projects
  add column count_organizers_toward_capacity boolean not null default false;

comment on column public.projects.registration_capacity is
  'Maximum registration/capacity slots used by ordinary participants and, when configured, the unique active organizer set. Null is allowed only for drafts and legacy published Projects whose capacity has not yet been set.';
comment on column public.projects.count_organizers_toward_capacity is
  'When true, the Creator plus active Co-creators and Co-organizers each consume one registration-capacity slot; organizer/participant overlap still counts once.';
comment on table public.projects is
  'Private cross-domain Project registry and shared participation configuration. It anchors immutable kind/Creator identity, optional registration capacity, and whether the unique organizer set consumes capacity.';

create function private.project_registration_capacity_snapshot(
  p_project_id uuid
)
returns table (
  registration_capacity integer,
  count_organizers_toward_capacity boolean,
  current_participant_count integer,
  ordinary_participant_count integer,
  organizer_count integer,
  capacity_used_count integer,
  social_people_count integer,
  spots_remaining integer,
  is_full boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  with project_config as (
    select
      project.id,
      project.creator_profile_id,
      project.registration_capacity,
      project.count_organizers_toward_capacity
    from public.projects as project
    where project.id = p_project_id
  ),
  organizer_profiles as (
    select config.creator_profile_id as profile_id
    from project_config as config
    union
    select delegate.delegate_profile_id
    from public.project_delegates as delegate
    join project_config as config on config.id = delegate.project_id
    where delegate.revoked_at is null
  ),
  participant_profiles as (
    select membership.participant_profile_id as profile_id
    from public.project_memberships as membership
    join project_config as config on config.id = membership.project_id
    where membership.left_at is null
      and membership.removed_at is null
  ),
  counts as (
    select
      config.registration_capacity,
      config.count_organizers_toward_capacity,
      (select count(*)::integer from participant_profiles) as participant_count,
      (
        select count(*)::integer
        from participant_profiles as participant
        where not exists (
          select 1
          from organizer_profiles as organizer
          where organizer.profile_id = participant.profile_id
        )
      ) as ordinary_count,
      (select count(*)::integer from organizer_profiles) as organizers
    from project_config as config
  ),
  derived as (
    select
      counts.*,
      counts.ordinary_count + counts.organizers as social_count,
      counts.ordinary_count + case
        when counts.count_organizers_toward_capacity then counts.organizers
        else 0
      end as used_count
    from counts
  )
  select
    derived.registration_capacity,
    derived.count_organizers_toward_capacity,
    derived.participant_count,
    derived.ordinary_count,
    derived.organizers,
    derived.used_count,
    derived.social_count,
    case
      when derived.registration_capacity is null then null
      else greatest(derived.registration_capacity - derived.used_count, 0)
    end,
    derived.registration_capacity is not null
      and derived.used_count >= derived.registration_capacity
  from derived;
$$;

revoke all on function private.project_registration_capacity_snapshot(uuid)
  from public;

comment on function private.project_registration_capacity_snapshot(uuid) is
  'Derives raw current memberships, unique organizers, ordinary participants, registration-capacity usage, and unique social headcount without storing mutable counters.';

-- Keep the original private shape available to older repository-owned code
-- while all canonical enforcement and client reads move to the explicit model.
create or replace function private.project_capacity_snapshot(p_project_id uuid)
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
  select
    snapshot.registration_capacity,
    snapshot.current_participant_count,
    snapshot.social_people_count,
    snapshot.spots_remaining,
    snapshot.is_full
  from private.project_registration_capacity_snapshot(p_project_id) as snapshot;
$$;

comment on function private.project_capacity_snapshot(uuid) is
  'Compatibility projection. people_capacity maps to registration_capacity and current_people_count maps to the unique social headcount; new code must use project_registration_capacity_snapshot.';

create or replace function private.assert_project_has_membership_capacity(
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
  perform 1
  from public.projects as project
  where project.id = p_project_id
  for update;

  select * into capacity_record
  from private.project_registration_capacity_snapshot(p_project_id);

  if capacity_record.registration_capacity is not null
    and capacity_record.is_full then
    raise exception using
      errcode = 'PT409',
      message = 'This Project is full.';
  end if;
end;
$$;

create function private.assert_project_has_membership_capacity(
  p_project_id uuid,
  p_participant_profile_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  capacity_record record;
  participant_is_organizer boolean;
begin
  perform 1
  from public.projects as project
  where project.id = p_project_id
  for update;

  select * into capacity_record
  from private.project_registration_capacity_snapshot(p_project_id);

  select exists (
    select 1
    from public.projects as project
    where project.id = p_project_id
      and project.creator_profile_id = p_participant_profile_id
    union all
    select 1
    from public.project_delegates as delegate
    where delegate.project_id = p_project_id
      and delegate.delegate_profile_id = p_participant_profile_id
      and delegate.revoked_at is null
  ) into participant_is_organizer;

  -- A current organizer can add an independent membership without consuming
  -- another slot: OFF excludes the organizer; ON already counts them once.
  if not participant_is_organizer
    and capacity_record.registration_capacity is not null
    and capacity_record.is_full then
    raise exception using
      errcode = 'PT409',
      message = 'This Project is full.';
  end if;
end;
$$;

revoke all on function private.assert_project_has_membership_capacity(
  uuid,
  uuid
) from public;

create or replace function private.enforce_join_request_capacity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'pending' then
    perform private.assert_project_has_membership_capacity(
      new.project_id,
      new.requester_profile_id
    );
  end if;
  return new;
end;
$$;

create or replace function private.enforce_membership_capacity()
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
    perform private.assert_project_has_membership_capacity(
      new.project_id,
      new.participant_profile_id
    );
  end if;
  return new;
end;
$$;

create function private.set_project_registration_capacity_for_structural_edit(
  p_expected_profile_id uuid,
  p_project_id uuid,
  p_registration_capacity integer,
  p_count_organizers_toward_capacity boolean
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
  prior_count_organizers boolean;
  capacity_record record;
  proposed_capacity_used integer;
begin
  if p_registration_capacity is not null
    and p_registration_capacity not between 1 and 100000 then
    raise exception using
      errcode = '22023',
      message = 'Registration capacity must be between 1 and 100,000.';
  end if;

  if p_count_organizers_toward_capacity is null then
    raise exception using
      errcode = '22023',
      message = 'The organizer-capacity setting is required.';
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

  select project.count_organizers_toward_capacity
  into prior_count_organizers
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

  select * into capacity_record
  from private.project_registration_capacity_snapshot(p_project_id);

  proposed_capacity_used := capacity_record.ordinary_participant_count + case
    when p_count_organizers_toward_capacity then capacity_record.organizer_count
    else 0
  end;

  if resolved_lifecycle_state <> 'draft'
    and p_registration_capacity is null then
    raise exception using
      errcode = '22023',
      message = 'Registration capacity is required for a published Project.';
  end if;

  if p_registration_capacity is not null
    and p_registration_capacity < proposed_capacity_used then
    if p_count_organizers_toward_capacity and not prior_count_organizers then
      raise exception using
        errcode = 'PT409',
        message = 'Increase registration capacity before counting organizers toward capacity.';
    end if;
    raise exception using
      errcode = '22023',
      message = 'Registration capacity cannot be lower than current capacity usage.';
  end if;

  update public.projects
  set
    registration_capacity = p_registration_capacity,
    count_organizers_toward_capacity = p_count_organizers_toward_capacity
  where id = p_project_id;
end;
$$;

revoke all on function private.set_project_registration_capacity_for_structural_edit(
  uuid,
  uuid,
  integer,
  boolean
) from public;

create or replace function private.set_project_people_capacity_for_structural_edit(
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
  current_count_organizers boolean;
begin
  select project.count_organizers_toward_capacity
  into current_count_organizers
  from public.projects as project
  where project.id = p_project_id;

  perform private.set_project_registration_capacity_for_structural_edit(
    p_expected_profile_id,
    p_project_id,
    p_people_capacity,
    coalesce(current_count_organizers, false)
  );
end;
$$;

comment on function private.set_project_people_capacity_for_structural_edit(
  uuid,
  uuid,
  integer
) is
  'Compatibility helper that updates registration capacity while preserving the organizer-counting setting.';

create or replace function private.require_capacity_for_project_publication()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  configured_capacity integer;
begin
  if old.lifecycle_state = 'draft' and new.lifecycle_state = 'published' then
    select project.registration_capacity into configured_capacity
    from public.projects as project
    where project.id = new.id
    for update;

    if configured_capacity is null then
      raise exception using
        errcode = '22023',
        message = 'Registration capacity is required before publication.';
    end if;
  end if;
  return new;
end;
$$;

create or replace function private.require_capacity_for_legacy_structural_edit()
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
    select project.registration_capacity into configured_capacity
    from public.projects as project
    where project.id = target_project_id;

    if configured_capacity is null then
      raise exception using
        errcode = '22023',
        message = 'Set registration capacity before saving structural changes to this legacy Project.';
    end if;
  end if;

  return coalesce(new, old);
end;
$$;

create function private.enforce_project_delegate_capacity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  capacity_record record;
begin
  if (
    tg_op = 'INSERT' and new.revoked_at is null
  ) or (
    tg_op = 'UPDATE' and old.revoked_at is null and new.revoked_at is not null
  ) then
    perform 1
    from public.projects as project
    where project.id = new.project_id
    for update;

    select * into capacity_record
    from private.project_registration_capacity_snapshot(new.project_id);

    if capacity_record.registration_capacity is not null
      and capacity_record.capacity_used_count
        > capacity_record.registration_capacity then
      raise exception using
        errcode = 'PT409',
        message = case
          when tg_op = 'INSERT' then
            'Project capacity cannot add another organizer.'
          else
            'Project capacity cannot revoke this organizer while their participant membership is current.'
        end;
    end if;
  end if;
  return new;
end;
$$;

revoke all on function private.enforce_project_delegate_capacity() from public;

create trigger project_delegates_enforce_capacity
after insert or update of revoked_at on public.project_delegates
for each row execute function private.enforce_project_delegate_capacity();

-- Existing capacity-aware overloads remain callable by stacked scripts. They
-- now write registration capacity; draft creation keeps the new setting OFF,
-- while structural updates preserve its current value.
create or replace function public.create_proposal_draft(
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
      message = 'Registration capacity must be between 1 and 100,000.';
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
  set registration_capacity = p_people_capacity
  where id = new_project_id;

  return new_project_id;
end;
$$;

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
  p_registration_capacity integer,
  p_count_organizers_toward_capacity boolean
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  new_project_id uuid;
begin
  if p_count_organizers_toward_capacity is null then
    raise exception using
      errcode = '22023',
      message = 'The organizer-capacity setting is required.';
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
    p_skill_importances,
    p_registration_capacity
  );

  update public.projects
  set count_organizers_toward_capacity = p_count_organizers_toward_capacity
  where id = new_project_id;

  return new_project_id;
end;
$$;

create or replace function public.update_own_proposal(
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
  p_registration_capacity integer,
  p_count_organizers_toward_capacity boolean
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.set_project_registration_capacity_for_structural_edit(
    p_expected_creator_profile_id,
    p_proposal_id,
    p_registration_capacity,
    p_count_organizers_toward_capacity
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

create or replace function public.create_recurring_activity_draft(
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
      message = 'Registration capacity must be between 1 and 100,000.';
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
  set registration_capacity = p_people_capacity
  where id = new_project_id;

  return new_project_id;
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
  p_registration_capacity integer,
  p_count_organizers_toward_capacity boolean
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  new_project_id uuid;
begin
  if p_count_organizers_toward_capacity is null then
    raise exception using
      errcode = '22023',
      message = 'The organizer-capacity setting is required.';
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
    p_effective_from,
    p_registration_capacity
  );

  update public.projects
  set count_organizers_toward_capacity = p_count_organizers_toward_capacity
  where id = new_project_id;

  return new_project_id;
end;
$$;

create or replace function public.update_own_recurring_activity(
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
  p_registration_capacity integer,
  p_count_organizers_toward_capacity boolean
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.set_project_registration_capacity_for_structural_edit(
    p_expected_creator_profile_id,
    p_recurring_activity_id,
    p_registration_capacity,
    p_count_organizers_toward_capacity
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

drop function public.list_public_project_capacity_statuses(uuid[]);
drop function public.list_project_capacity_statuses_for_structural_actor(
  uuid,
  uuid[]
);
drop function public.get_project_capacity_for_manager(uuid, uuid);
drop function public.list_project_join_requests_for_manager(uuid, uuid);

create function public.list_project_join_requests_for_manager(
  p_expected_manager_profile_id uuid,
  p_project_id uuid
)
returns table (
  request_id uuid,
  requester_profile_id uuid,
  requester_display_name text,
  requester_is_organizer boolean,
  status text,
  request_message text,
  created_at timestamptz,
  resolved_at timestamptz,
  resolved_by_profile_id uuid
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform private.require_project_manager(
    p_expected_manager_profile_id,
    p_project_id
  );

  return query
  select
    request.id,
    request.requester_profile_id,
    profile.display_name,
    exists (
      select 1
      from public.projects as project
      where project.id = request.project_id
        and project.creator_profile_id = request.requester_profile_id
      union all
      select 1
      from public.project_delegates as delegate
      where delegate.project_id = request.project_id
        and delegate.delegate_profile_id = request.requester_profile_id
        and delegate.revoked_at is null
    ),
    request.status,
    request.request_message,
    request.created_at,
    request.resolved_at,
    request.resolved_by_profile_id
  from public.project_join_requests as request
  join public.profiles as profile on profile.id = request.requester_profile_id
  where request.project_id = p_project_id
  order by request.created_at desc, request.id;
end;
$$;

create function public.list_public_project_capacity_statuses(
  p_project_ids uuid[]
)
returns table (
  project_id uuid,
  registration_capacity integer,
  count_organizers_toward_capacity boolean,
  current_participant_count integer,
  ordinary_participant_count integer,
  organizer_count integer,
  capacity_used_count integer,
  social_people_count integer,
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
    snapshot.registration_capacity,
    snapshot.count_organizers_toward_capacity,
    snapshot.current_participant_count,
    snapshot.ordinary_participant_count,
    snapshot.organizer_count,
    snapshot.capacity_used_count,
    snapshot.social_people_count,
    snapshot.spots_remaining,
    snapshot.is_full
  from unnest(normalized_ids) with ordinality as requested(id, position)
  cross join lateral private.project_registration_capacity_snapshot(
    requested.id
  ) as snapshot
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
  registration_capacity integer,
  count_organizers_toward_capacity boolean,
  current_participant_count integer,
  ordinary_participant_count integer,
  organizer_count integer,
  capacity_used_count integer,
  social_people_count integer,
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
    snapshot.registration_capacity,
    snapshot.count_organizers_toward_capacity,
    snapshot.current_participant_count,
    snapshot.ordinary_participant_count,
    snapshot.organizer_count,
    snapshot.capacity_used_count,
    snapshot.social_people_count,
    snapshot.spots_remaining,
    snapshot.is_full
  from unnest(normalized_ids) with ordinality as requested(id, position)
  join public.projects as project on project.id = requested.id
  cross join lateral private.project_registration_capacity_snapshot(
    requested.id
  ) as snapshot
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
  registration_capacity integer,
  count_organizers_toward_capacity boolean,
  current_participant_count integer,
  ordinary_participant_count integer,
  organizer_count integer,
  capacity_used_count integer,
  social_people_count integer,
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
    snapshot.registration_capacity,
    snapshot.count_organizers_toward_capacity,
    snapshot.current_participant_count,
    snapshot.ordinary_participant_count,
    snapshot.organizer_count,
    snapshot.capacity_used_count,
    snapshot.social_people_count,
    snapshot.spots_remaining,
    snapshot.is_full
  from private.project_registration_capacity_snapshot(p_project_id) as snapshot;
end;
$$;

revoke all on function public.create_proposal_draft(
  uuid, text, text, text, timestamptz, timestamptz, text, text, text, text,
  text, text, text, uuid[], text[], integer, boolean
) from public, anon;
grant execute on function public.create_proposal_draft(
  uuid, text, text, text, timestamptz, timestamptz, text, text, text, text,
  text, text, text, uuid[], text[], integer, boolean
) to authenticated;

revoke all on function public.update_own_proposal(
  uuid, uuid, text, text, text, timestamptz, timestamptz, text, text, text,
  text, text, text, text, uuid[], text[], integer, boolean
) from public, anon;
grant execute on function public.update_own_proposal(
  uuid, uuid, text, text, text, timestamptz, timestamptz, text, text, text,
  text, text, text, text, uuid[], text[], integer, boolean
) to authenticated;

revoke all on function public.create_recurring_activity_draft(
  uuid, text, text, text, text, text, text, text, text, text, text, text,
  integer, integer, time without time zone, integer, text, date, integer,
  boolean
) from public, anon;
grant execute on function public.create_recurring_activity_draft(
  uuid, text, text, text, text, text, text, text, text, text, text, text,
  integer, integer, time without time zone, integer, text, date, integer,
  boolean
) to authenticated;

revoke all on function public.update_own_recurring_activity(
  uuid, uuid, text, text, text, text, text, text, text, text, text, text, text,
  integer, integer, time without time zone, integer, text, date, integer,
  boolean
) from public, anon;
grant execute on function public.update_own_recurring_activity(
  uuid, uuid, text, text, text, text, text, text, text, text, text, text, text,
  integer, integer, time without time zone, integer, text, date, integer,
  boolean
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

revoke all on function public.list_project_join_requests_for_manager(uuid, uuid)
  from public, anon;
grant execute on function public.list_project_join_requests_for_manager(uuid, uuid)
  to authenticated;

comment on function public.list_public_project_capacity_statuses(uuid[]) is
  'Returns aggregate-only registration capacity, organizer breakdown, and unique social headcount for publicly readable Projects; no identities are exposed.';
comment on function public.list_project_capacity_statuses_for_structural_actor(uuid, uuid[]) is
  'Returns organizer-aware registration capacity and social headcount for Projects structurally manageable by the expected Creator or current Co-creator.';
comment on function public.get_project_capacity_for_manager(uuid, uuid) is
  'Returns organizer-aware registration capacity and social headcount to a current Project manager for participation management.';
