-- Add moderation predicates at canonical boundaries before pagination and after
-- serialization. Preserve all current signatures, cover fields, capacity policy,
-- manager convergence, and existing accepted/private relationships.

create or replace function private.lock_project_manager_interactions(
  p_project_id uuid,
  p_requester_profile_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  manager_profile_ids uuid[];
  locked_manager_profile_ids uuid[];
  manager_profile_id uuid;
begin
  if p_project_id is null or p_requester_profile_id is null then
    raise exception using
      errcode = '22023',
      message = 'A Project interaction requires Project and requester identifiers.';
  end if;

  perform private.lock_profile_new_interactions(p_requester_profile_id);

  select coalesce(
    array_agg(manager.profile_id order by manager.profile_id::text),
    '{}'::uuid[]
  )
  into manager_profile_ids
  from private.current_project_manager_profile_ids(p_project_id) as manager;

  if cardinality(manager_profile_ids) = 0 then
    raise exception using
      errcode = 'P0002',
      message = 'The requested project does not exist.';
  end if;

  -- Every multi-manager interaction acquires the same canonical pair keys in
  -- the same global order before touching concrete/shared Project rows.
  for manager_profile_id in
    select candidate.profile_id
    from unnest(manager_profile_ids) as candidate(profile_id)
    where candidate.profile_id <> p_requester_profile_id
    order by
      least(candidate.profile_id::text, p_requester_profile_id::text),
      greatest(candidate.profile_id::text, p_requester_profile_id::text)
  loop
    perform private.lock_user_interaction_pair(
      p_requester_profile_id,
      manager_profile_id
    );
  end loop;

  perform 1
  from private.lock_project_for_participation(p_project_id, false);

  select coalesce(
    array_agg(manager.profile_id order by manager.profile_id::text),
    '{}'::uuid[]
  )
  into locked_manager_profile_ids
  from private.current_project_manager_profile_ids(p_project_id) as manager;

  if manager_profile_ids is distinct from locked_manager_profile_ids then
    raise sqlstate 'PT409'
      using message = 'This interaction is unavailable.';
  end if;

  perform private.assert_profile_new_interactions_available(p_requester_profile_id);
  if private.project_has_active_content_hide(p_project_id) then
    raise sqlstate 'PT409' using message = 'This interaction is unavailable.';
  end if;

  foreach manager_profile_id in array locked_manager_profile_ids
  loop
    perform private.assert_user_interaction_available(
      p_requester_profile_id,
      manager_profile_id
    );
  end loop;
end;
$$;

create or replace function public.request_resource_listing(
  p_expected_requester_profile_id uuid,
  p_listing_id uuid,
  p_message text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_resource_listing_request_identity(
    p_expected_requester_profile_id,
    true
  );
  owner_profile_id uuid;
begin
  select listing.owner_profile_id into owner_profile_id
  from public.resource_listings as listing
  where listing.id = p_listing_id;

  if owner_profile_id is null then
    raise exception using
      errcode = 'P0002',
      message = 'The resource listing does not exist.';
  end if;

  perform private.lock_profile_new_interactions(current_profile_id);
  perform private.lock_user_interaction_pair(
    current_profile_id,
    owner_profile_id
  );
  perform private.assert_user_interaction_available(
    current_profile_id,
    owner_profile_id
  );

  perform 1 from public.resource_listings as locked_listing
    where locked_listing.id = p_listing_id for update;
  perform private.assert_profile_new_interactions_available(current_profile_id);
  if private.resource_listing_has_active_content_hide(p_listing_id) then
    raise sqlstate 'PT409' using message = 'This interaction is unavailable.';
  end if;

  return private.request_resource_listing_without_block(
    p_expected_requester_profile_id,
    p_listing_id,
    p_message
  );
end;
$$;

create or replace function public.accept_resource_listing_request(
  p_expected_owner_profile_id uuid,
  p_request_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_resource_listing_request_identity(
    p_expected_owner_profile_id,
    false
  );
  owner_profile_id uuid;
  requester_profile_id uuid;
begin
  select
    listing.owner_profile_id,
    request.requester_profile_id
  into owner_profile_id, requester_profile_id
  from public.resource_listing_requests as request
  join public.resource_listings as listing on listing.id = request.listing_id
  where request.id = p_request_id;

  if requester_profile_id is null then
    raise exception using
      errcode = 'P0002',
      message = 'The resource listing request does not exist.';
  end if;

  if owner_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'Only the listing owner can accept this resource listing request.';
  end if;

  perform private.lock_profile_new_interactions(requester_profile_id);
  perform private.lock_user_interaction_pair(
    owner_profile_id,
    requester_profile_id
  );
  perform private.assert_user_interaction_available(
    owner_profile_id,
    requester_profile_id
  );

  perform 1 from public.resource_listings as locked_listing
    where locked_listing.id = (select listing_id from public.resource_listing_requests where id = p_request_id) for update;
  perform private.assert_profile_new_interactions_available(requester_profile_id);
  if private.resource_listing_has_active_content_hide((select listing_id from public.resource_listing_requests where id = p_request_id)) then
    raise sqlstate 'PT409' using message = 'This interaction is unavailable.';
  end if;

  return private.accept_resource_listing_request_without_block(
    p_expected_owner_profile_id,
    p_request_id
  );
end;
$$;

create or replace function private.is_project_publicly_viewable(p_project_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.projects as project
    where project.id = p_project_id
      and not private.project_has_active_content_hide(project.id)
      and (
        (
          project.project_kind = 'one_time'
          and exists (
            select 1
            from public.proposals as proposal
            where proposal.id = project.id
              and proposal.lifecycle_state = 'published'
          )
        )
        or (
          project.project_kind = 'recurring'
          and exists (
            select 1
            from public.recurring_activities as activity
            where activity.id = project.id
              and activity.lifecycle_state in ('published', 'paused', 'ended')
          )
        )
      )
  )
$$;

create or replace function public.list_public_proposals(
  p_limit integer default 20,
  p_cursor_starts_at timestamptz default null,
  p_cursor_id uuid default null,
  p_locality text default null,
  p_skill_ids uuid[] default null,
  p_query text default null
)
returns table (
  proposal_id uuid,
  cover_object_path text,
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
  normalized_locality text := nullif(btrim(p_locality), '');
  normalized_query text := nullif(lower(btrim(p_query)), '');
begin
  if p_limit is null or p_limit not between 1 and 50 then
    raise exception using
      errcode = '22023',
      message = 'Proposal page size must be between 1 and 50.';
  end if;

  if (p_cursor_starts_at is null) <> (p_cursor_id is null) then
    raise exception using
      errcode = '22023',
      message = 'Proposal cursor values must be supplied together.';
  end if;

  if p_skill_ids is not null and array_position(p_skill_ids, null) is not null then
    raise exception using
      errcode = '22023',
      message = 'Proposal skill filters cannot contain null identifiers.';
  end if;

  if normalized_query is not null and char_length(normalized_query) > 120 then
    raise exception using
      errcode = '22023',
      message = 'Proposal search query must contain at most 120 characters.';
  end if;

  return query
  select
    proposal.id,
    cover.object_path,
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
  from public.proposals as proposal
  left join public.project_covers as cover on cover.project_id = proposal.id
  where proposal.lifecycle_state = 'published'
    and not private.project_has_active_content_hide(proposal.id)
    and proposal.ends_at > statement_timestamp() - interval '24 hours'
    and (
      normalized_query is null
      or position(normalized_query in lower(proposal.title)) > 0
      or position(normalized_query in lower(proposal.summary)) > 0
      or position(normalized_query in lower(proposal.description)) > 0
    )
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
    and (
      p_cursor_starts_at is null
      or (proposal.starts_at, proposal.id) > (p_cursor_starts_at, p_cursor_id)
    )
  order by proposal.starts_at, proposal.id
  limit p_limit;
end;
$$;

create or replace function public.get_public_proposal(p_proposal_id uuid)
returns table (
  proposal_id uuid,
  cover_object_path text,
  creator_profile_id uuid,
  creator_display_name text,
  title text,
  summary text,
  description text,
  starts_at timestamptz,
  ends_at timestamptz,
  event_timezone text,
  country_code text,
  locality text,
  administrative_area text,
  public_location_label text,
  derived_status text,
  skills jsonb,
  exact_meeting_text text,
  exact_location_restricted boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    proposal.id,
    cover.object_path,
    proposal.creator_profile_id,
    case
      when display_visibility.audience = 'public' then creator.display_name
      else null
    end,
    proposal.title,
    proposal.summary,
    proposal.description,
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
    ),
    case
      when meeting.exact_location_visibility = 'public'
        then meeting.exact_meeting_text
      else null
    end,
    meeting.exact_location_visibility = 'participants'
  from public.proposals as proposal
  join public.profiles as creator on creator.id = proposal.creator_profile_id
  left join public.profile_field_visibility as display_visibility
    on display_visibility.profile_id = creator.id
    and display_visibility.field_key = 'display_name'
  join public.proposal_meeting_details as meeting
    on meeting.proposal_id = proposal.id
  left join public.project_covers as cover on cover.project_id = proposal.id
  where proposal.id = p_proposal_id
    and not private.project_has_active_content_hide(proposal.id)
    and proposal.lifecycle_state = 'published'
$$;

create or replace function public.list_public_recurring_activities(
  p_reference_time timestamptz,
  p_limit integer default 20,
  p_cursor_next_starts_at timestamptz default null,
  p_cursor_id uuid default null,
  p_locality text default null
)
returns table (
  recurring_activity_id uuid,
  cover_object_path text,
  title text,
  summary text,
  topic text,
  country_code text,
  locality text,
  administrative_area text,
  public_location_label text,
  next_starts_at timestamptz,
  next_ends_at timestamptz,
  event_timezone text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  normalized_locality text := nullif(btrim(p_locality), '');
begin
  if p_limit is null or p_limit not between 1 and 50 then
    raise exception using
      errcode = '22023',
      message = 'Recurring activity page size must be between 1 and 50.';
  end if;

  if (p_cursor_next_starts_at is null) <> (p_cursor_id is null) then
    raise exception using
      errcode = '22023',
      message = 'Recurring activity cursor values must be supplied together.';
  end if;

  if p_reference_time is null then
    raise exception using
      errcode = '22023',
      message = 'Recurring activity discovery requires a reference time.';
  end if;

  return query
  select
    activity.id,
    cover.object_path,
    activity.title,
    activity.summary,
    activity.topic,
    activity.country_code,
    activity.locality,
    activity.administrative_area,
    activity.public_location_label,
    next_occurrence.starts_at,
    next_occurrence.ends_at,
    next_occurrence.event_timezone
  from public.recurring_activities as activity
  cross join lateral private.next_recurring_activity_occurrence(
    activity.id,
    p_reference_time
  ) as next_occurrence
  left join public.project_covers as cover on cover.project_id = activity.id
  where activity.lifecycle_state = 'published'
    and not private.project_has_active_content_hide(activity.id)
    and (
      normalized_locality is null
      or lower(activity.locality) = lower(normalized_locality)
    )
    and (
      p_cursor_next_starts_at is null
      or (next_occurrence.starts_at, activity.id)
        > (p_cursor_next_starts_at, p_cursor_id)
    )
  order by next_occurrence.starts_at, activity.id
  limit p_limit;
end;
$$;

create or replace function public.get_public_recurring_activity(
  p_recurring_activity_id uuid,
  p_occurrence_limit integer default 5,
  p_reference_time timestamptz default statement_timestamp()
)
returns table (
  recurring_activity_id uuid,
  cover_object_path text,
  creator_profile_id uuid,
  creator_display_name text,
  lifecycle_state text,
  title text,
  summary text,
  description text,
  topic text,
  country_code text,
  locality text,
  administrative_area text,
  public_location_label text,
  recurrence_type text,
  weekday smallint,
  day_of_month smallint,
  local_start_time time without time zone,
  duration_minutes integer,
  event_timezone text,
  schedule_effective_from date,
  next_occurrences jsonb,
  exact_meeting_text text,
  exact_location_restricted boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if p_occurrence_limit is null or p_occurrence_limit not between 1 and 20 then
    raise exception using
      errcode = '22023',
      message = 'Public recurring activity occurrence limits must be between 1 and 20.';
  end if;

  if p_reference_time is null then
    raise exception using
      errcode = '22023',
      message = 'Recurring activity detail requires a reference time.';
  end if;

  return query
  select
    activity.id,
    cover.object_path,
    activity.creator_profile_id,
    case
      when display_visibility.audience = 'public' then creator.display_name
      else null
    end,
    activity.lifecycle_state,
    activity.title,
    activity.summary,
    activity.description,
    activity.topic,
    activity.country_code,
    activity.locality,
    activity.administrative_area,
    activity.public_location_label,
    selected_schedule.recurrence_type,
    selected_schedule.weekday,
    selected_schedule.day_of_month,
    selected_schedule.local_start_time,
    selected_schedule.duration_minutes,
    selected_schedule.event_timezone,
    selected_schedule.effective_from,
    case
      when activity.lifecycle_state = 'published'
        and next_occurrence.starts_at is not null then coalesce(
          (
            select jsonb_agg(
              jsonb_build_object(
                'local_starts_at', occurrence.local_starts_at,
                'starts_at', occurrence.starts_at,
                'ends_at', occurrence.ends_at,
                'event_timezone', occurrence.event_timezone
              )
              order by occurrence.starts_at
            )
            from private.derive_recurring_activity_occurrences(
              activity.id,
              next_occurrence.starts_at,
              next_occurrence.starts_at + interval '5 years',
              p_occurrence_limit
            ) as occurrence
          ),
          '[]'::jsonb
        )
      else '[]'::jsonb
    end,
    case
      when meeting.exact_location_visibility = 'public'
        then meeting.exact_meeting_text
      else null
    end,
    meeting.exact_location_visibility = 'participants'
  from public.recurring_activities as activity
  join public.profiles as creator on creator.id = activity.creator_profile_id
  left join public.profile_field_visibility as display_visibility
    on display_visibility.profile_id = creator.id
    and display_visibility.field_key = 'display_name'
  join public.recurring_activity_meeting_details as meeting
    on meeting.recurring_activity_id = activity.id
  left join public.project_covers as cover on cover.project_id = activity.id
  left join lateral private.next_recurring_activity_occurrence(
    activity.id,
    p_reference_time
  ) as next_occurrence on activity.lifecycle_state = 'published'
  left join lateral (
    select schedule.id
    from public.recurring_activity_schedules as schedule
    where schedule.recurring_activity_id = activity.id
      and schedule.effective_until is null
    limit 1
  ) as latest_schedule on true
  join public.recurring_activity_schedules as selected_schedule
    on selected_schedule.id = coalesce(
      next_occurrence.schedule_version_id,
      latest_schedule.id
    )
  where activity.id = p_recurring_activity_id
    and not private.project_has_active_content_hide(activity.id)
    and activity.lifecycle_state in ('published', 'paused', 'ended');
end;
$$;

create or replace function public.list_public_recurring_activity_occurrences(
  p_recurring_activity_id uuid,
  p_from timestamptz,
  p_until timestamptz,
  p_limit integer default 50
)
returns table (
  recurring_activity_id uuid,
  local_starts_at timestamp without time zone,
  starts_at timestamptz,
  ends_at timestamptz,
  event_timezone text
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    activity.id,
    occurrence.local_starts_at,
    occurrence.starts_at,
    occurrence.ends_at,
    occurrence.event_timezone
  from public.recurring_activities as activity
  cross join lateral private.derive_recurring_activity_occurrences(
    activity.id,
    p_from,
    p_until,
    p_limit
  ) as occurrence
  where activity.id = p_recurring_activity_id
    and not private.project_has_active_content_hide(activity.id)
    and activity.lifecycle_state = 'published'
$$;

create or replace function public.list_public_project_capacity_statuses(
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
  where not private.project_has_active_content_hide(requested.id)
    and exists (
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

create or replace function public.list_public_project_resource_needs(
  p_project_id uuid
)
returns table (
  resource_need_id uuid,
  title text,
  details text,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    need.id,
    need.title,
    need.details,
    need.created_at
  from public.project_resource_needs as need
  join public.projects as project on project.id = need.project_id
  left join public.proposals as proposal
    on proposal.id = project.id
    and project.project_kind = 'one_time'
  left join public.recurring_activities as activity
    on activity.id = project.id
    and project.project_kind = 'recurring'
  where need.project_id = p_project_id
    and not private.project_has_active_content_hide(project.id)
    and need.state = 'open'
    and (
      (
        project.project_kind = 'one_time'
        and proposal.lifecycle_state = 'published'
        and proposal.ends_at is not null
        and statement_timestamp() < proposal.ends_at
      )
      or (
        project.project_kind = 'recurring'
        and activity.lifecycle_state = 'published'
      )
    )
  order by need.created_at, need.id
$$;

create or replace function public.list_public_resource_listings(
  p_limit integer default 20,
  p_cursor_published_at timestamptz default null,
  p_cursor_id uuid default null,
  p_listing_mode text default null,
  p_locality text default null,
  p_query text default null
)
returns table (
  listing_id uuid,
  cover_object_path text,
  listing_mode text,
  title text,
  description text,
  country_code text,
  locality text,
  administrative_area text,
  public_location_label text,
  published_at timestamptz,
  active_request_count bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  normalized_listing_mode text := lower(nullif(btrim(p_listing_mode), ''));
  normalized_locality text := nullif(btrim(p_locality), '');
  normalized_query text := nullif(btrim(p_query), '');
begin
  if p_limit is null or p_limit not between 1 and 50 then
    raise exception using
      errcode = '22023',
      message = 'Resource listing page size must be between 1 and 50.';
  end if;

  if (p_cursor_published_at is null) <> (p_cursor_id is null) then
    raise exception using
      errcode = '22023',
      message = 'Resource listing cursor values must be supplied together.';
  end if;

  if normalized_listing_mode is not null
    and normalized_listing_mode not in ('donate', 'exchange') then
    raise exception using
      errcode = '22023',
      message = 'Resource listing mode filter must be donate or exchange.';
  end if;

  if normalized_locality is not null
    and char_length(normalized_locality) > 120 then
    raise exception using
      errcode = '22023',
      message = 'Resource listing locality filter must contain at most 120 characters.';
  end if;

  if normalized_query is not null and char_length(normalized_query) > 120 then
    raise exception using
      errcode = '22023',
      message = 'Resource listing query must contain at most 120 characters.';
  end if;

  return query
  select
    listing.id,
    cover.object_path,
    listing.listing_mode,
    listing.title,
    listing.description,
    listing.country_code,
    listing.locality,
    listing.administrative_area,
    listing.public_location_label,
    listing.published_at,
    (
      select count(*)
      from public.resource_listing_requests as request
      where request.listing_id = listing.id
        and (
          request.status = 'pending'
          or (
            request.status = 'accepted'
            and request.coordination_closed_at is null
          )
        )
    )
  from public.resource_listings as listing
  left join public.resource_listing_covers as cover
    on cover.listing_id = listing.id
  where listing.lifecycle_state = 'published'
      and not private.resource_listing_has_active_content_hide(listing.id)
    and (
      normalized_listing_mode is null
      or listing.listing_mode = normalized_listing_mode
    )
    and (
      normalized_locality is null
      or lower(listing.locality) = lower(normalized_locality)
    )
    and (
      normalized_query is null
      or strpos(lower(listing.title), lower(normalized_query)) > 0
      or strpos(lower(listing.description), lower(normalized_query)) > 0
    )
    and (
      p_cursor_published_at is null
      or (listing.published_at, listing.id)
        < (p_cursor_published_at, p_cursor_id)
    )
  order by listing.published_at desc, listing.id desc
  limit p_limit;
end;
$$;

create or replace function public.get_public_resource_listing(p_listing_id uuid)
returns table (
  listing_id uuid,
  cover_object_path text,
  listing_mode text,
  title text,
  description text,
  country_code text,
  locality text,
  administrative_area text,
  public_location_label text,
  published_at timestamptz,
  owner_profile_id uuid,
  owner_display_name text,
  active_request_count bigint
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    listing.id,
    cover.object_path,
    listing.listing_mode,
    listing.title,
    listing.description,
    listing.country_code,
    listing.locality,
    listing.administrative_area,
    listing.public_location_label,
    listing.published_at,
    listing.owner_profile_id,
    case
      when display_visibility.audience = 'public' then owner.display_name
      else null
    end,
    (
      select count(*)
      from public.resource_listing_requests as request
      where request.listing_id = listing.id
        and (
          request.status = 'pending'
          or (
            request.status = 'accepted'
            and request.coordination_closed_at is null
          )
        )
    )
  from public.resource_listings as listing
  join public.profiles as owner on owner.id = listing.owner_profile_id
  left join public.profile_field_visibility as display_visibility
    on display_visibility.profile_id = owner.id
    and display_visibility.field_key = 'display_name'
  left join public.resource_listing_covers as cover
    on cover.listing_id = listing.id
  where listing.id = p_listing_id
    and listing.lifecycle_state = 'published'
      and not private.resource_listing_has_active_content_hide(listing.id)
$$;

create or replace function public.can_read_public_cover_image_object(p_object_path text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.project_covers as cover
    where cover.object_path = p_object_path
      and private.is_project_publicly_viewable(cover.project_id)
  ) or exists (
    select 1
    from public.resource_listing_covers as cover
    join public.resource_listings as listing
      on listing.id = cover.listing_id
    where cover.object_path = p_object_path
      and listing.lifecycle_state = 'published'
      and not private.resource_listing_has_active_content_hide(listing.id)
  )
$$;

create or replace function private.has_public_resource_listing_owner_photo_context(
  p_owner_profile_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    p_owner_profile_id is not null
    and exists (
      select 1
      from public.resource_listings as listing
      where listing.owner_profile_id = p_owner_profile_id
        and listing.lifecycle_state = 'published'
      and not private.resource_listing_has_active_content_hide(listing.id)
    )
$$;

create or replace function public.get_resource_listing_owner_profile_photo_for_viewer(
  p_listing_id uuid
)
returns table (
  profile_id uuid,
  object_path text,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    photo.profile_id,
    photo.object_path,
    photo.updated_at
  from public.resource_listings as listing
  join public.profile_photos as photo
    on photo.profile_id = listing.owner_profile_id
  where listing.id = p_listing_id
    and (
      listing.owner_profile_id = (select auth.uid())
      or (
        listing.lifecycle_state = 'published'
      and not private.resource_listing_has_active_content_hide(listing.id)
        and (
          photo.audience = 'public'
          or not private.has_active_user_block_between(
            (select auth.uid()),
            photo.profile_id
          )
        )
      )
    )
$$;

create or replace function public.list_project_resource_need_listing_matches(
  p_expected_creator_profile_id uuid,
  p_resource_need_id uuid,
  p_location_scope text,
  p_limit integer default 20,
  p_listing_mode text default null,
  p_cursor_text_match_kind text default null,
  p_cursor_location_match_kind text default null,
  p_cursor_published_at timestamptz default null,
  p_cursor_listing_id uuid default null
)
returns table (
  resource_need_id uuid,
  listing_id uuid,
  cover_object_path text,
  listing_mode text,
  title text,
  description text,
  country_code text,
  locality text,
  administrative_area text,
  public_location_label text,
  published_at timestamptz,
  active_request_count bigint,
  text_match_kind text,
  location_match_kind text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_participation_identity(
    p_expected_creator_profile_id
  );
  resource_need public.project_resource_needs%rowtype;
  project_record public.projects%rowtype;
  source_state text;
  source_ends_at timestamptz;
  source_country_code text;
  source_locality text;
  source_administrative_area text;
  normalized_mode text := pg_catalog.lower(pg_catalog.btrim(p_listing_mode));
  cursor_text_rank integer;
  cursor_location_rank integer;
begin
  if p_location_scope is null or p_location_scope not in (
    'same_locality', 'same_administrative_area', 'same_country', 'anywhere'
  ) then
    raise exception using errcode = '22023',
      message = 'An explicit valid Project resource matching location scope is required.';
  end if;

  if p_limit is null or p_limit not between 1 and 50 then
    raise exception using errcode = '22023',
      message = 'Project resource matching page size must be between 1 and 50.';
  end if;

  if normalized_mode is not null
    and normalized_mode not in ('donate', 'exchange') then
    raise exception using errcode = '22023',
      message = 'Project resource matching mode must be donate or exchange.';
  end if;

  if num_nonnulls(
    p_cursor_text_match_kind,
    p_cursor_location_match_kind,
    p_cursor_published_at,
    p_cursor_listing_id
  ) not in (0, 4) then
    raise exception using errcode = '22023',
      message = 'All Project resource matching cursor values must be supplied together.';
  end if;

  cursor_text_rank := case p_cursor_text_match_kind
    when 'title_phrase' then 1
    when 'need_title_in_listing_title' then 2
    when 'need_title_in_listing_description' then 3
    when 'need_details_in_listing_title' then 4
    when 'need_details_in_listing_description' then 5
  end;
  cursor_location_rank := case p_cursor_location_match_kind
    when 'same_locality' then 1
    when 'same_administrative_area' then 2
    when 'same_country' then 3
    when 'other_or_unknown' then 4
  end;

  if p_cursor_listing_id is not null and (
    cursor_text_rank is null or cursor_location_rank is null
  ) then
    raise exception using errcode = '22023',
      message = 'Project resource matching cursor reasons are invalid.';
  end if;

  select * into resource_need
  from public.project_resource_needs as need
  where need.id = p_resource_need_id;

  if not found then
    raise exception using errcode = 'P0002',
      message = 'The Project resource need does not exist.';
  end if;

  select * into project_record
  from public.projects as project
  where project.id = resource_need.project_id;

  if not found or project_record.creator_profile_id <> current_profile_id then
    raise exception using errcode = '42501',
      message = 'Only the Project creator can match its resource need.';
  end if;

  if resource_need.state <> 'open' then
    raise exception using errcode = '55000',
      message = 'Only an open Project resource need can be matched.';
  end if;

  if project_record.project_kind = 'one_time' then
    select
      proposal.lifecycle_state,
      proposal.ends_at,
      proposal.country_code,
      proposal.locality,
      proposal.administrative_area
    into
      source_state,
      source_ends_at,
      source_country_code,
      source_locality,
      source_administrative_area
    from public.proposals as proposal
    where proposal.id = project_record.id
      and proposal.creator_profile_id = current_profile_id;

    if not found then
      raise exception using errcode = '55000',
        message = 'The Project registry does not match its Proposal.';
    end if;

    if not (
      source_state = 'draft'
      or (source_state = 'published' and source_ends_at > statement_timestamp())
    ) then
      raise exception using errcode = '55000',
        message = 'The Proposal is no longer eligible for resource matching.';
    end if;
  elsif project_record.project_kind = 'recurring' then
    select
      activity.lifecycle_state,
      activity.country_code,
      activity.locality,
      activity.administrative_area
    into
      source_state,
      source_country_code,
      source_locality,
      source_administrative_area
    from public.recurring_activities as activity
    where activity.id = project_record.id
      and activity.creator_profile_id = current_profile_id;

    if not found then
      raise exception using errcode = '55000',
        message = 'The Project registry does not match its Tavolo.';
    end if;

    if source_state not in ('draft', 'published', 'paused') then
      raise exception using errcode = '55000',
        message = 'The Tavolo is no longer eligible for resource matching.';
    end if;
  else
    raise exception using errcode = '55000',
      message = 'The Project kind is not eligible for resource matching.';
  end if;

  if (source_locality is null and p_location_scope = 'same_locality')
    or (
      (source_country_code is null or source_administrative_area is null)
      and p_location_scope = 'same_administrative_area'
    )
    or (source_country_code is null and p_location_scope = 'same_country') then
    raise exception using errcode = '55000',
      message = 'The Project lacks rough geography required by the selected matching scope.';
  end if;

  return query
  with source_terms as materialized (
    select
      private.project_resource_match_or_query(resource_need.title) as title_query,
      private.project_resource_match_or_query(resource_need.details) as details_query,
      pg_catalog.lower(pg_catalog.regexp_replace(
        pg_catalog.btrim(resource_need.title), '\s+', ' ', 'g'
      )) as normalized_title
  ), candidates as (
    select
      listing.id,
      listing.published_at,
      reason.text_match_kind,
      reason.location_match_kind,
      case reason.text_match_kind
        when 'title_phrase' then 1
        when 'need_title_in_listing_title' then 2
        when 'need_title_in_listing_description' then 3
        when 'need_details_in_listing_title' then 4
        else 5
      end as text_rank,
      case reason.location_match_kind
        when 'same_locality' then 1
        when 'same_administrative_area' then 2
        when 'same_country' then 3
        else 4
      end as location_rank
    from public.resource_listings as listing
    cross join source_terms as terms
    cross join lateral private.evaluate_project_resource_listing_match(
      resource_need.title,
      resource_need.details,
      source_country_code,
      source_locality,
      source_administrative_area,
      listing.title,
      listing.description,
      listing.country_code,
      listing.locality,
      listing.administrative_area
    ) as reason
    where listing.lifecycle_state = 'published'
      and not private.resource_listing_has_active_content_hide(listing.id)
      and (normalized_mode is null or listing.listing_mode = normalized_mode)
      and (
        (
          terms.normalized_title <> ''
          and pg_catalog.strpos(
            pg_catalog.lower(pg_catalog.regexp_replace(
              pg_catalog.btrim(listing.title), '\s+', ' ', 'g'
            )),
            terms.normalized_title
          ) > 0
        )
        or (
          terms.title_query is not null
          and (
            pg_catalog.to_tsvector(
              'italian'::regconfig,
              coalesce(listing.title, '')
            ) @@ terms.title_query
            or pg_catalog.to_tsvector(
              'italian'::regconfig,
              coalesce(listing.description, '')
            ) @@ terms.title_query
          )
        )
        or (
          terms.details_query is not null
          and (
            pg_catalog.to_tsvector(
              'italian'::regconfig,
              coalesce(listing.title, '')
            ) @@ terms.details_query
            or pg_catalog.to_tsvector(
              'italian'::regconfig,
              coalesce(listing.description, '')
            ) @@ terms.details_query
          )
        )
      )
      and reason.is_match
      and (
        p_location_scope = 'anywhere'
        or (
          p_location_scope = 'same_locality'
          and pg_catalog.lower(pg_catalog.btrim(listing.locality)) =
            pg_catalog.lower(pg_catalog.btrim(source_locality))
        )
        or (
          p_location_scope = 'same_administrative_area'
          and listing.country_code = source_country_code
          and pg_catalog.lower(pg_catalog.btrim(listing.administrative_area)) =
            pg_catalog.lower(pg_catalog.btrim(source_administrative_area))
        )
        or (
          p_location_scope = 'same_country'
          and listing.country_code = source_country_code
        )
      )
  )
  select
    resource_need.id,
    candidate.id,
    public_listing.cover_object_path,
    public_listing.listing_mode,
    public_listing.title,
    public_listing.description,
    public_listing.country_code,
    public_listing.locality,
    public_listing.administrative_area,
    public_listing.public_location_label,
    candidate.published_at,
    public_listing.active_request_count,
    candidate.text_match_kind,
    candidate.location_match_kind
  from candidates as candidate
  cross join lateral public.get_public_resource_listing(candidate.id)
    as public_listing
  where p_cursor_listing_id is null
    or candidate.text_rank > cursor_text_rank
    or (
      candidate.text_rank = cursor_text_rank
      and candidate.location_rank > cursor_location_rank
    )
    or (
      candidate.text_rank = cursor_text_rank
      and candidate.location_rank = cursor_location_rank
      and candidate.published_at < p_cursor_published_at
    )
    or (
      candidate.text_rank = cursor_text_rank
      and candidate.location_rank = cursor_location_rank
      and candidate.published_at = p_cursor_published_at
      and candidate.id < p_cursor_listing_id
    )
  order by
    candidate.text_rank,
    candidate.location_rank,
    candidate.published_at desc,
    candidate.id desc
  limit p_limit;
end;
$$;

create or replace function public.process_resource_saved_search_matching_outbox_batch(
  p_limit integer default 100
)
returns table (
  processed_count integer,
  matches_created integer,
  matches_suppressed integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  source_event private.outbox_events%rowtype;
  listing public.resource_listings%rowtype;
  saved_search public.resource_saved_searches%rowtype;
  new_match_id uuid;
  v_processed_count integer := 0;
  v_matches_created integer := 0;
  v_matches_suppressed integer := 0;
begin
  if p_limit is null or p_limit not between 1 and 100 then
    raise exception using
      errcode = '22023',
      message = 'Saved-search matching projector batch size must be between 1 and 100.';
  end if;

  for source_event in
    select event.*
    from private.outbox_events as event
    where event.event_type = 'resource_listing.published'
      and event.available_at <= statement_timestamp()
      and not exists (
        select 1
        from private.outbox_consumer_receipts as receipt
        where receipt.outbox_event_id = event.id
          and receipt.consumer_key = 'saved-search-matching.v1'
      )
    order by event.created_at, event.id
    limit p_limit
    for update of event skip locked
  loop
    select canonical_listing.* into listing
    from public.resource_listings as canonical_listing
    where canonical_listing.id = (source_event.payload ->> 'listing_id')::uuid
    for share of canonical_listing;

    if listing.id is null
      or (source_event.payload ->> 'owner_profile_id')::uuid
        is distinct from listing.owner_profile_id
      or source_event.payload ->> 'listing_mode'
        is distinct from listing.listing_mode then
      raise exception using
        errcode = '55000',
        message = format(
          'Saved-search matching could not validate outbox event %s against its canonical resource listing.',
          source_event.id
        );
    end if;

    if listing.lifecycle_state = 'published'
      and not private.resource_listing_has_active_content_hide(listing.id) then
      for saved_search in
        select candidate.*
        from public.resource_saved_searches as candidate
        where candidate.updated_at <= source_event.created_at
        order by candidate.id
        for share of candidate
      loop
        if saved_search.profile_id = listing.owner_profile_id
          or not private.resource_listing_matches_saved_search_filters(
            listing.listing_mode,
            listing.title,
            listing.description,
            listing.locality,
            saved_search.listing_mode,
            saved_search.query,
            saved_search.locality
          ) then
          v_matches_suppressed := v_matches_suppressed + 1;
          continue;
        end if;

        new_match_id := null;

        insert into private.resource_saved_search_listing_matches (
          source_outbox_event_id,
          saved_search_id,
          saved_search_updated_at,
          recipient_profile_id,
          listing_id,
          matched_at
        )
        values (
          source_event.id,
          saved_search.id,
          saved_search.updated_at,
          saved_search.profile_id,
          listing.id,
          source_event.created_at
        )
        on conflict do nothing
        returning id into new_match_id;

        if new_match_id is null then
          v_matches_suppressed := v_matches_suppressed + 1;
          continue;
        end if;

        insert into private.outbox_events (
          event_type,
          payload,
          created_at,
          available_at
        )
        values (
          'resource_saved_search.matched',
          jsonb_build_object(
            'saved_search_match_id', new_match_id,
            'saved_search_id', saved_search.id,
            'recipient_profile_id', saved_search.profile_id,
            'listing_id', listing.id
          ),
          source_event.created_at,
          source_event.created_at
        );

        v_matches_created := v_matches_created + 1;
      end loop;
    end if;

    insert into private.outbox_consumer_receipts (
      outbox_event_id,
      consumer_key,
      processed_at
    )
    values (
      source_event.id,
      'saved-search-matching.v1',
      statement_timestamp()
    )
    on conflict do nothing;

    v_processed_count := v_processed_count + 1;
  end loop;

  return query select
    v_processed_count,
    v_matches_created,
    v_matches_suppressed;
end;
$$;

-- VOLATILE is intentional: acquiring the listing share lock must be allowed,
-- and the hide predicate must see a fresh snapshot after waiting for its holder.
-- The lock survives until notification projection commits; prior delivery stays history.
create or replace function private.resolve_saved_search_matching_notification_event(
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
volatile
security definer
set search_path = ''
as $$
declare
  source_event private.outbox_events%rowtype;
  match_fact private.resource_saved_search_listing_matches%rowtype;
  saved_search public.resource_saved_searches%rowtype;
  listing public.resource_listings%rowtype;
  payload_match_id uuid;
  payload_saved_search_id uuid;
  payload_recipient_profile_id uuid;
  payload_listing_id uuid;
begin
  select event.* into source_event
  from private.outbox_events as event
  where event.id = p_outbox_event_id
    and event.event_type = 'resource_saved_search.matched';

  if not found then
    raise exception using
      errcode = '55000',
      message = format(
        'Saved-search matching notification event %s is unavailable or unsupported.',
        p_outbox_event_id
      );
  end if;

  if jsonb_typeof(source_event.payload) is distinct from 'object'
    or (
      select count(*)
      from jsonb_object_keys(source_event.payload)
    ) <> 4
    or not source_event.payload ?& array[
      'saved_search_match_id',
      'saved_search_id',
      'recipient_profile_id',
      'listing_id'
    ] then
    raise exception using
      errcode = '55000',
      message = format(
        'Saved-search matching notification event %s has invalid identifier-only payload shape.',
        source_event.id
      );
  end if;

  begin
    payload_match_id :=
      (source_event.payload ->> 'saved_search_match_id')::uuid;
    payload_saved_search_id :=
      (source_event.payload ->> 'saved_search_id')::uuid;
    payload_recipient_profile_id :=
      (source_event.payload ->> 'recipient_profile_id')::uuid;
    payload_listing_id := (source_event.payload ->> 'listing_id')::uuid;
  exception
    when invalid_text_representation then
      raise exception using
        errcode = '55000',
        message = format(
          'Saved-search matching notification event %s has invalid identifiers.',
          source_event.id
        );
  end;

  if payload_match_id is null
    or payload_saved_search_id is null
    or payload_recipient_profile_id is null
    or payload_listing_id is null then
    raise exception using
      errcode = '55000',
      message = format(
        'Saved-search matching notification event %s has invalid identifiers.',
        source_event.id
      );
  end if;

  select fact.* into match_fact
  from private.resource_saved_search_listing_matches as fact
  where fact.id = payload_match_id;

  if not found then
    if exists (
      select 1
      from public.resource_saved_searches as current_search
      where current_search.id = payload_saved_search_id
    ) then
      raise exception using
        errcode = '55000',
        message = format(
          'Saved-search matching notification event %s references no canonical match fact for its current saved search.',
          source_event.id
        );
    end if;

    return;
  end if;

  if payload_saved_search_id is distinct from match_fact.saved_search_id
    or payload_recipient_profile_id
      is distinct from match_fact.recipient_profile_id
    or payload_listing_id is distinct from match_fact.listing_id
    or source_event.created_at is distinct from match_fact.matched_at then
    raise exception using
      errcode = '55000',
      message = format(
        'Saved-search matching notification event %s diverges from its canonical match fact.',
        source_event.id
      );
  end if;

  select current_search.* into saved_search
  from public.resource_saved_searches as current_search
  where current_search.id = match_fact.saved_search_id;

  select current_listing.* into listing
  from public.resource_listings as current_listing
  where current_listing.id = match_fact.listing_id for share;

  if saved_search.id is null
    or listing.id is null
    or saved_search.profile_id
      is distinct from match_fact.recipient_profile_id then
    raise exception using
      errcode = '55000',
      message = format(
        'Saved-search matching notification event %s has inconsistent canonical context.',
        source_event.id
      );
  end if;

  if saved_search.profile_id = listing.owner_profile_id then
    raise exception using
      errcode = '55000',
      message = format(
        'Saved-search matching notification event %s violates self-owner suppression.',
        source_event.id
      );
  end if;

  if saved_search.updated_at is distinct from match_fact.saved_search_updated_at
    or listing.lifecycle_state <> 'published'
    or private.resource_listing_has_active_content_hide(listing.id)
    or not private.resource_listing_matches_saved_search_filters(
      listing.listing_mode,
      listing.title,
      listing.description,
      listing.locality,
      saved_search.listing_mode,
      saved_search.query,
      saved_search.locality
    ) then
    return;
  end if;

  return query
  select
    'matching'::text,
    'matching_available'::text,
    match_fact.recipient_profile_id,
    null::uuid,
    null::uuid,
    null::text,
    null::uuid,
    null::uuid,
    null::uuid,
    null::uuid,
    match_fact.listing_id,
    null::uuid,
    null::uuid,
    null::uuid,
    null::uuid,
    null::uuid,
    'matching_result'::text,
    source_event.created_at;
end;
$$;
