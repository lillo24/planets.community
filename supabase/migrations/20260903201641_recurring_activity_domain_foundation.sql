create table public.recurring_activities (
  id uuid primary key default gen_random_uuid(),
  creator_profile_id uuid not null
    constraint recurring_activities_creator_profile_id_fkey
      references public.profiles (id) on delete restrict,
  lifecycle_state text not null default 'draft'
    constraint recurring_activities_lifecycle_state_valid check (
      lifecycle_state in ('draft', 'published', 'paused', 'ended')
    ),
  title text
    constraint recurring_activities_title_valid check (
      title is null
      or (title = btrim(title) and char_length(title) between 2 and 100)
    ),
  summary text
    constraint recurring_activities_summary_valid check (
      summary is null
      or (summary = btrim(summary) and char_length(summary) between 1 and 240)
    ),
  description text
    constraint recurring_activities_description_valid check (
      description is null
      or (description = btrim(description) and char_length(description) between 1 and 5000)
    ),
  topic text
    constraint recurring_activities_topic_valid check (
      topic is null
      or (topic = btrim(topic) and char_length(topic) between 1 and 80)
    ),
  country_code text
    constraint recurring_activities_country_code_valid check (
      country_code is null or country_code ~ '^[A-Z]{2}$'
    ),
  locality text
    constraint recurring_activities_locality_valid check (
      locality is null
      or (locality = btrim(locality) and char_length(locality) between 1 and 120)
    ),
  administrative_area text
    constraint recurring_activities_administrative_area_valid check (
      administrative_area is null
      or (
        administrative_area = btrim(administrative_area)
        and char_length(administrative_area) between 1 and 120
      )
    ),
  public_location_label text
    constraint recurring_activities_public_location_label_valid check (
      public_location_label is null
      or (
        public_location_label = btrim(public_location_label)
        and char_length(public_location_label) between 1 and 180
      )
    ),
  approximate_location extensions.geography(point, 4326),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  published_at timestamptz,
  paused_at timestamptz,
  resumed_at timestamptz,
  ended_at timestamptz,
  constraint recurring_activities_lifecycle_timestamps_valid check (
    (
      lifecycle_state = 'draft'
      and published_at is null
      and paused_at is null
      and resumed_at is null
      and ended_at is null
    )
    or (
      lifecycle_state = 'published'
      and published_at is not null
      and paused_at is null
      and ended_at is null
      and (resumed_at is null or resumed_at >= published_at)
    )
    or (
      lifecycle_state = 'paused'
      and published_at is not null
      and paused_at is not null
      and paused_at >= published_at
      and ended_at is null
      and (resumed_at is null or resumed_at between published_at and paused_at)
    )
    or (
      lifecycle_state = 'ended'
      and published_at is not null
      and ended_at is not null
      and ended_at >= published_at
      and (paused_at is null or paused_at between published_at and ended_at)
      and (resumed_at is null or resumed_at between published_at and ended_at)
    )
  )
);

comment on table public.recurring_activities is
  'Persistent creator-owned recurring activity definitions, separate from one-time proposals.';
comment on column public.recurring_activities.lifecycle_state is
  'Explicit open-ended series state; meeting time never completes a recurring activity automatically.';
comment on column public.recurring_activities.approximate_location is
  'Optional rough map-ready point; exact meeting coordinates remain in the protected meeting record.';

create table public.recurring_activity_meeting_details (
  recurring_activity_id uuid primary key
    constraint recurring_activity_meeting_details_activity_id_fkey
      references public.recurring_activities (id) on delete cascade,
  exact_meeting_text text
    constraint recurring_activity_meeting_details_text_valid check (
      exact_meeting_text is null
      or (
        exact_meeting_text = btrim(exact_meeting_text)
        and char_length(exact_meeting_text) between 1 and 1000
      )
    ),
  exact_location_visibility text not null default 'participants'
    constraint recurring_activity_meeting_details_visibility_valid check (
      exact_location_visibility in ('public', 'participants')
    ),
  exact_location extensions.geography(point, 4326),
  updated_at timestamptz not null default now()
);

comment on table public.recurring_activity_meeting_details is
  'One-to-one exact recurring meeting information, physically separated from public rough location.';
comment on column public.recurring_activity_meeting_details.exact_location_visibility is
  'Public exposes exact text through detail; participants reserves a future participant-authorized boundary.';

create table public.recurring_activity_schedules (
  id uuid primary key default gen_random_uuid(),
  recurring_activity_id uuid not null
    constraint recurring_activity_schedules_activity_id_fkey
      references public.recurring_activities (id) on delete cascade,
  recurrence_type text not null
    constraint recurring_activity_schedules_recurrence_type_valid check (
      recurrence_type in ('weekly', 'monthly')
    ),
  weekday smallint,
  day_of_month smallint,
  local_start_time time without time zone not null,
  duration_minutes integer not null
    constraint recurring_activity_schedules_duration_valid check (
      duration_minutes between 15 and 1440
    ),
  event_timezone text not null
    constraint recurring_activity_schedules_timezone_shape_valid check (
      event_timezone = btrim(event_timezone)
      and char_length(event_timezone) between 1 and 100
    ),
  effective_from date not null,
  effective_until date,
  created_at timestamptz not null default now(),
  superseded_at timestamptz,
  constraint recurring_activity_schedules_pattern_valid check (
    (
      recurrence_type = 'weekly'
      and weekday between 1 and 7
      and day_of_month is null
    )
    or (
      recurrence_type = 'monthly'
      and weekday is null
      and day_of_month between 1 and 28
    )
  ),
  constraint recurring_activity_schedules_effective_range_valid check (
    effective_until is null or effective_until > effective_from
  ),
  constraint recurring_activity_schedules_supersession_valid check (
    (effective_until is null and superseded_at is null)
    or (effective_until is not null and superseded_at is not null)
  ),
  constraint recurring_activity_schedules_effective_from_key
    unique (recurring_activity_id, effective_from)
);

comment on table public.recurring_activity_schedules is
  'Non-overlapping local-date schedule versions that preserve past recurring meeting rules.';
comment on column public.recurring_activity_schedules.weekday is
  'ISO weekday from 1 Monday through 7 Sunday for weekly recurrence.';
comment on column public.recurring_activity_schedules.effective_until is
  'Exclusive local-date boundary; null marks the latest open-ended schedule version.';

create index recurring_activities_creator_created_at_idx
  on public.recurring_activities (creator_profile_id, created_at desc, id);

create index recurring_activities_published_locality_id_idx
  on public.recurring_activities (locality, id)
  where lifecycle_state = 'published';

create index recurring_activity_schedules_activity_effective_idx
  on public.recurring_activity_schedules (
    recurring_activity_id,
    effective_from desc,
    id
  );

create unique index recurring_activity_schedules_one_open_idx
  on public.recurring_activity_schedules (recurring_activity_id)
  where effective_until is null;

create function private.set_recurring_activity_updated_at()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger recurring_activities_set_updated_at
before update on public.recurring_activities
for each row
execute function private.set_recurring_activity_updated_at();

create trigger recurring_activity_meeting_details_set_updated_at
before update on public.recurring_activity_meeting_details
for each row
execute function private.set_recurring_activity_updated_at();

create function private.prevent_recurring_schedule_overlap()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform 1
  from public.recurring_activities as activity
  where activity.id = new.recurring_activity_id
  for update;

  if exists (
    select 1
    from public.recurring_activity_schedules as existing
    where existing.recurring_activity_id = new.recurring_activity_id
      and existing.id <> new.id
      and daterange(
        existing.effective_from,
        existing.effective_until,
        '[)'
      ) && daterange(new.effective_from, new.effective_until, '[)')
  ) then
    raise exception using
      errcode = '23P01',
      message = 'Recurring activity schedule versions cannot overlap.';
  end if;

  return new;
end;
$$;

create trigger recurring_activity_schedules_prevent_overlap
before insert or update on public.recurring_activity_schedules
for each row
execute function private.prevent_recurring_schedule_overlap();

alter table public.recurring_activities enable row level security;
alter table public.recurring_activity_meeting_details enable row level security;
alter table public.recurring_activity_schedules enable row level security;

create policy "Creators can read their own recurring activities"
on public.recurring_activities
for select
to authenticated
using ((select auth.uid()) = creator_profile_id);

create policy "Creators can read their own recurring meeting details"
on public.recurring_activity_meeting_details
for select
to authenticated
using (
  exists (
    select 1
    from public.recurring_activities as activity
    where activity.id = recurring_activity_meeting_details.recurring_activity_id
      and activity.creator_profile_id = (select auth.uid())
  )
);

create policy "Creators can read their own recurring schedules"
on public.recurring_activity_schedules
for select
to authenticated
using (
  exists (
    select 1
    from public.recurring_activities as activity
    where activity.id = recurring_activity_schedules.recurring_activity_id
      and activity.creator_profile_id = (select auth.uid())
  )
);

grant select on table public.recurring_activities to authenticated;
grant select on table public.recurring_activity_meeting_details to authenticated;
grant select on table public.recurring_activity_schedules to authenticated;

create function private.require_expected_recurring_activity_identity(
  p_expected_profile_id uuid
)
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := (select auth.uid());
begin
  if current_profile_id is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication is required to manage a recurring activity.';
  end if;

  if p_expected_profile_id is null
    or p_expected_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'The authenticated user does not match the expected recurring activity creator.';
  end if;

  return current_profile_id;
end;
$$;

create function private.require_complete_recurring_activity_profile(
  p_expected_profile_id uuid
)
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_expected_recurring_activity_identity(
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
      message = 'A complete profile is required to create, publish, or resume a recurring activity.';
  end if;

  return current_profile_id;
end;
$$;

create function private.replace_recurring_activity_content(
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
  p_exact_location_visibility text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  normalized_title text := nullif(btrim(p_title), '');
  normalized_summary text := nullif(btrim(p_summary), '');
  normalized_description text := nullif(btrim(p_description), '');
  normalized_topic text := nullif(btrim(p_topic), '');
  normalized_country_code text := nullif(upper(btrim(p_country_code)), '');
  normalized_locality text := nullif(btrim(p_locality), '');
  normalized_administrative_area text := nullif(btrim(p_administrative_area), '');
  normalized_public_location_label text := nullif(btrim(p_public_location_label), '');
  normalized_exact_meeting_text text := nullif(btrim(p_exact_meeting_text), '');
  normalized_visibility text := coalesce(
    nullif(btrim(p_exact_location_visibility), ''),
    'participants'
  );
begin
  if normalized_title is not null
    and char_length(normalized_title) not between 2 and 100 then
    raise exception using
      errcode = '22023',
      message = 'Recurring activity title must contain between 2 and 100 characters.';
  end if;

  if normalized_summary is not null and char_length(normalized_summary) > 240 then
    raise exception using
      errcode = '22023',
      message = 'Recurring activity summary must contain at most 240 characters.';
  end if;

  if normalized_description is not null and char_length(normalized_description) > 5000 then
    raise exception using
      errcode = '22023',
      message = 'Recurring activity description must contain at most 5000 characters.';
  end if;

  if normalized_topic is not null and char_length(normalized_topic) > 80 then
    raise exception using
      errcode = '22023',
      message = 'Recurring activity topic must contain at most 80 characters.';
  end if;

  if normalized_country_code is not null
    and normalized_country_code !~ '^[A-Z]{2}$' then
    raise exception using
      errcode = '22023',
      message = 'Recurring activity country code must contain two letters.';
  end if;

  if normalized_locality is not null and char_length(normalized_locality) > 120 then
    raise exception using
      errcode = '22023',
      message = 'Recurring activity locality must contain at most 120 characters.';
  end if;

  if normalized_administrative_area is not null
    and char_length(normalized_administrative_area) > 120 then
    raise exception using
      errcode = '22023',
      message = 'Recurring activity administrative area must contain at most 120 characters.';
  end if;

  if normalized_public_location_label is not null
    and char_length(normalized_public_location_label) > 180 then
    raise exception using
      errcode = '22023',
      message = 'Recurring activity public location label must contain at most 180 characters.';
  end if;

  if normalized_exact_meeting_text is not null
    and char_length(normalized_exact_meeting_text) > 1000 then
    raise exception using
      errcode = '22023',
      message = 'Recurring activity exact meeting information must contain at most 1000 characters.';
  end if;

  if normalized_visibility not in ('public', 'participants') then
    raise exception using
      errcode = '22023',
      message = 'Exact location visibility must be public or participants.';
  end if;

  update public.recurring_activities
  set
    title = normalized_title,
    summary = normalized_summary,
    description = normalized_description,
    topic = normalized_topic,
    country_code = normalized_country_code,
    locality = normalized_locality,
    administrative_area = normalized_administrative_area,
    public_location_label = normalized_public_location_label
  where id = p_recurring_activity_id;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'The recurring activity does not exist.';
  end if;

  insert into public.recurring_activity_meeting_details (
    recurring_activity_id,
    exact_meeting_text,
    exact_location_visibility
  )
  values (
    p_recurring_activity_id,
    normalized_exact_meeting_text,
    normalized_visibility
  )
  on conflict (recurring_activity_id)
  do update set
    exact_meeting_text = excluded.exact_meeting_text,
    exact_location_visibility = excluded.exact_location_visibility;
end;
$$;

create function private.apply_recurring_activity_schedule(
  p_recurring_activity_id uuid,
  p_lifecycle_state text,
  p_recurrence_type text,
  p_weekday integer,
  p_day_of_month integer,
  p_local_start_time time without time zone,
  p_duration_minutes integer,
  p_event_timezone text,
  p_effective_from date
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  normalized_recurrence_type text := nullif(lower(btrim(p_recurrence_type)), '');
  normalized_timezone text := nullif(btrim(p_event_timezone), '');
  current_schedule public.recurring_activity_schedules%rowtype;
  new_schedule_id uuid;
  current_local_date date;
begin
  if normalized_recurrence_type is null
    and p_weekday is null
    and p_day_of_month is null
    and p_local_start_time is null
    and p_duration_minutes is null
    and normalized_timezone is null
    and p_effective_from is null then
    if p_lifecycle_state <> 'draft' then
      raise exception using
        errcode = '22023',
        message = 'Published or paused recurring activities require a complete schedule.';
    end if;

    delete from public.recurring_activity_schedules
    where recurring_activity_id = p_recurring_activity_id;
    return null;
  end if;

  if normalized_recurrence_type not in ('weekly', 'monthly')
    or p_local_start_time is null
    or p_duration_minutes is null
    or normalized_timezone is null
    or p_effective_from is null then
    raise exception using
      errcode = '22023',
      message = 'A recurring schedule requires type, local start time, duration, time zone, and effective date.';
  end if;

  if normalized_recurrence_type = 'weekly'
    and (p_weekday is null or p_weekday not between 1 and 7 or p_day_of_month is not null) then
    raise exception using
      errcode = '22023',
      message = 'A weekly schedule requires one ISO weekday from 1 through 7.';
  end if;

  if normalized_recurrence_type = 'monthly'
    and (p_day_of_month is null or p_day_of_month not between 1 and 28 or p_weekday is not null) then
    raise exception using
      errcode = '22023',
      message = 'A monthly schedule requires one calendar day from 1 through 28.';
  end if;

  if p_duration_minutes not between 15 and 1440 then
    raise exception using
      errcode = '22023',
      message = 'Recurring activity duration must be between 15 and 1440 minutes.';
  end if;

  if not exists (
    select 1
    from pg_catalog.pg_timezone_names as time_zone
    where time_zone.name = normalized_timezone
  ) then
    raise exception using
      errcode = '22023',
      message = 'Recurring activity time zone must be a recognized IANA identifier.';
  end if;

  if p_lifecycle_state = 'draft' then
    delete from public.recurring_activity_schedules
    where recurring_activity_id = p_recurring_activity_id;

    insert into public.recurring_activity_schedules (
      recurring_activity_id,
      recurrence_type,
      weekday,
      day_of_month,
      local_start_time,
      duration_minutes,
      event_timezone,
      effective_from
    )
    values (
      p_recurring_activity_id,
      normalized_recurrence_type,
      p_weekday,
      p_day_of_month,
      p_local_start_time,
      p_duration_minutes,
      normalized_timezone,
      p_effective_from
    )
    returning id into new_schedule_id;

    return new_schedule_id;
  end if;

  select * into current_schedule
  from public.recurring_activity_schedules as schedule
  where schedule.recurring_activity_id = p_recurring_activity_id
    and schedule.effective_until is null
  for update;

  if current_schedule.id is null then
    raise exception using
      errcode = '55000',
      message = 'The recurring activity has no current schedule to supersede.';
  end if;

  if current_schedule.recurrence_type = normalized_recurrence_type
    and current_schedule.weekday is not distinct from p_weekday
    and current_schedule.day_of_month is not distinct from p_day_of_month
    and current_schedule.local_start_time = p_local_start_time
    and current_schedule.duration_minutes = p_duration_minutes
    and current_schedule.event_timezone = normalized_timezone then
    return current_schedule.id;
  end if;

  current_local_date := (
    statement_timestamp() at time zone current_schedule.event_timezone
  )::date;

  if p_effective_from <= current_local_date
    or p_effective_from <= current_schedule.effective_from then
    raise exception using
      errcode = '22023',
      message = 'A published schedule change must begin on a future local date after the current version.';
  end if;

  update public.recurring_activity_schedules
  set
    effective_until = p_effective_from,
    superseded_at = statement_timestamp()
  where id = current_schedule.id;

  insert into public.recurring_activity_schedules (
    recurring_activity_id,
    recurrence_type,
    weekday,
    day_of_month,
    local_start_time,
    duration_minutes,
    event_timezone,
    effective_from
  )
  values (
    p_recurring_activity_id,
    normalized_recurrence_type,
    p_weekday,
    p_day_of_month,
    p_local_start_time,
    p_duration_minutes,
    normalized_timezone,
    p_effective_from
  )
  returning id into new_schedule_id;

  insert into private.audit_events (
    action,
    actor_user_id,
    target_type,
    target_id,
    metadata
  )
  values (
    'recurring_activity.schedule_changed',
    (select auth.uid()),
    'recurring_activity',
    p_recurring_activity_id,
    jsonb_build_object(
      'previous_schedule_id', current_schedule.id,
      'schedule_id', new_schedule_id,
      'effective_from', p_effective_from
    )
  );

  insert into private.outbox_events (event_type, payload)
  values (
    'recurring_activity.schedule_changed',
    jsonb_build_object(
      'recurring_activity_id', p_recurring_activity_id,
      'actor_id', (select auth.uid()),
      'schedule_id', new_schedule_id,
      'effective_from', p_effective_from
    )
  );

  return new_schedule_id;
end;
$$;

create function private.next_recurring_activity_occurrence(
  p_recurring_activity_id uuid,
  p_reference_time timestamptz
)
returns table (
  schedule_version_id uuid,
  local_starts_at timestamp without time zone,
  starts_at timestamptz,
  ends_at timestamptz,
  event_timezone text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  schedule public.recurring_activity_schedules%rowtype;
  reference_local timestamp without time zone;
  anchor_date date;
  candidate_date date;
  candidate_local timestamp without time zone;
  candidate_start timestamptz;
  best_schedule_id uuid;
  best_local_start timestamp without time zone;
  best_start timestamptz;
  best_end timestamptz;
  best_timezone text;
  next_month date;
begin
  if p_reference_time is null then
    raise exception using
      errcode = '22023',
      message = 'A reference time is required to derive the next recurring occurrence.';
  end if;

  for schedule in
    select candidate.*
    from public.recurring_activity_schedules as candidate
    where candidate.recurring_activity_id = p_recurring_activity_id
    order by candidate.effective_from, candidate.id
  loop
    reference_local := p_reference_time at time zone schedule.event_timezone;
    anchor_date := greatest(reference_local::date, schedule.effective_from);

    if schedule.recurrence_type = 'weekly' then
      candidate_date := anchor_date + (
        (schedule.weekday - extract(isodow from anchor_date)::integer + 7) % 7
      );
      candidate_local := candidate_date + schedule.local_start_time;
      candidate_start := candidate_local at time zone schedule.event_timezone;

      if candidate_start < p_reference_time then
        candidate_date := candidate_date + 7;
        candidate_local := candidate_date + schedule.local_start_time;
        candidate_start := candidate_local at time zone schedule.event_timezone;
      end if;
    else
      candidate_date := make_date(
        extract(year from anchor_date)::integer,
        extract(month from anchor_date)::integer,
        schedule.day_of_month
      );

      if candidate_date < anchor_date then
        next_month := (date_trunc('month', anchor_date) + interval '1 month')::date;
        candidate_date := make_date(
          extract(year from next_month)::integer,
          extract(month from next_month)::integer,
          schedule.day_of_month
        );
      end if;

      candidate_local := candidate_date + schedule.local_start_time;
      candidate_start := candidate_local at time zone schedule.event_timezone;

      if candidate_start < p_reference_time then
        next_month := (date_trunc('month', candidate_date) + interval '1 month')::date;
        candidate_date := make_date(
          extract(year from next_month)::integer,
          extract(month from next_month)::integer,
          schedule.day_of_month
        );
        candidate_local := candidate_date + schedule.local_start_time;
        candidate_start := candidate_local at time zone schedule.event_timezone;
      end if;
    end if;

    if candidate_date >= schedule.effective_from
      and (
        schedule.effective_until is null
        or candidate_date < schedule.effective_until
      )
      and (best_start is null or candidate_start < best_start) then
      best_schedule_id := schedule.id;
      best_local_start := candidate_local;
      best_start := candidate_start;
      best_end := candidate_start + make_interval(mins => schedule.duration_minutes);
      best_timezone := schedule.event_timezone;
    end if;
  end loop;

  if best_schedule_id is not null then
    return query
    select
      best_schedule_id,
      best_local_start,
      best_start,
      best_end,
      best_timezone;
  end if;
end;
$$;

create function private.derive_recurring_activity_occurrences(
  p_recurring_activity_id uuid,
  p_from timestamptz,
  p_until timestamptz,
  p_limit integer
)
returns table (
  schedule_version_id uuid,
  local_starts_at timestamp without time zone,
  starts_at timestamptz,
  ends_at timestamptz,
  event_timezone text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if p_from is null or p_until is null or p_until <= p_from then
    raise exception using
      errcode = '22023',
      message = 'Occurrence windows require an increasing [from, until) range.';
  end if;

  if p_until > p_from + interval '5 years' then
    raise exception using
      errcode = '22023',
      message = 'Occurrence windows cannot exceed five years.';
  end if;

  if p_limit is null or p_limit not between 1 and 100 then
    raise exception using
      errcode = '22023',
      message = 'Occurrence limits must be between 1 and 100.';
  end if;

  return query
  with schedule_dates as (
    select
      schedule.id as schedule_id,
      schedule.recurrence_type,
      schedule.weekday,
      schedule.day_of_month,
      schedule.local_start_time,
      schedule.duration_minutes,
      schedule.event_timezone,
      generated.local_date::date as local_date
    from public.recurring_activity_schedules as schedule
    cross join lateral generate_series(
      greatest(
        schedule.effective_from,
        (p_from at time zone schedule.event_timezone)::date
      )::timestamp,
      least(
        coalesce(
          schedule.effective_until - 1,
          (p_until at time zone schedule.event_timezone)::date
        ),
        (p_until at time zone schedule.event_timezone)::date
      )::timestamp,
      interval '1 day'
    ) as generated(local_date)
    where schedule.recurring_activity_id = p_recurring_activity_id
  ),
  matching_dates as (
    select
      schedule_date.*,
      schedule_date.local_date + schedule_date.local_start_time as local_start
    from schedule_dates as schedule_date
    where (
      schedule_date.recurrence_type = 'weekly'
      and extract(isodow from schedule_date.local_date)::smallint = schedule_date.weekday
    ) or (
      schedule_date.recurrence_type = 'monthly'
      and extract(day from schedule_date.local_date)::smallint = schedule_date.day_of_month
    )
  ),
  occurrences as (
    select
      matching.schedule_id,
      matching.local_start,
      matching.local_start at time zone matching.event_timezone as starts_at,
      matching.duration_minutes,
      matching.event_timezone
    from matching_dates as matching
  )
  select
    occurrence.schedule_id,
    occurrence.local_start,
    occurrence.starts_at,
    occurrence.starts_at + make_interval(mins => occurrence.duration_minutes),
    occurrence.event_timezone
  from occurrences as occurrence
  where occurrence.starts_at >= p_from
    and occurrence.starts_at < p_until
  order by occurrence.starts_at, occurrence.schedule_id
  limit p_limit;
end;
$$;

create function private.assert_recurring_activity_publishable(
  p_recurring_activity_id uuid
)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  activity public.recurring_activities%rowtype;
  meeting public.recurring_activity_meeting_details%rowtype;
begin
  select * into activity
  from public.recurring_activities
  where id = p_recurring_activity_id;

  select * into meeting
  from public.recurring_activity_meeting_details
  where recurring_activity_id = p_recurring_activity_id;

  if activity.title is null
    or activity.summary is null
    or activity.description is null
    or activity.country_code is null
    or activity.locality is null
    or activity.public_location_label is null
    or meeting.recurring_activity_id is null
    or meeting.exact_meeting_text is null then
    raise exception using
      errcode = '22023',
      message = 'Published recurring activities require complete content, rough location, and exact meeting information.';
  end if;

  if not exists (
    select 1
    from public.recurring_activity_schedules as schedule
    where schedule.recurring_activity_id = p_recurring_activity_id
      and schedule.effective_until is null
      and exists (
        select 1
        from pg_catalog.pg_timezone_names as time_zone
        where time_zone.name = schedule.event_timezone
      )
  ) then
    raise exception using
      errcode = '22023',
      message = 'Published recurring activities require a valid current schedule.';
  end if;

  if not exists (
    select 1
    from private.next_recurring_activity_occurrence(
      p_recurring_activity_id,
      statement_timestamp()
    )
  ) then
    raise exception using
      errcode = '22023',
      message = 'The recurring activity schedule cannot generate a future occurrence.';
  end if;
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
  p_effective_from date
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_complete_recurring_activity_profile(
    p_expected_creator_profile_id
  );
  recurring_activity_id uuid;
begin
  insert into public.recurring_activities (creator_profile_id)
  values (current_profile_id)
  returning id into recurring_activity_id;

  perform private.replace_recurring_activity_content(
    recurring_activity_id,
    p_title,
    p_summary,
    p_description,
    p_topic,
    p_country_code,
    p_locality,
    p_administrative_area,
    p_public_location_label,
    p_exact_meeting_text,
    p_exact_location_visibility
  );

  perform private.apply_recurring_activity_schedule(
    recurring_activity_id,
    'draft',
    p_recurrence_type,
    p_weekday,
    p_day_of_month,
    p_local_start_time,
    p_duration_minutes,
    p_event_timezone,
    p_effective_from
  );

  return recurring_activity_id;
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
  p_effective_from date
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_expected_recurring_activity_identity(
    p_expected_creator_profile_id
  );
  activity public.recurring_activities%rowtype;
begin
  select * into activity
  from public.recurring_activities
  where id = p_recurring_activity_id
  for update;

  if activity.id is null or activity.creator_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'The current user does not own this recurring activity.';
  end if;

  if activity.lifecycle_state = 'ended' then
    raise exception using
      errcode = '55000',
      message = 'An ended recurring activity is immutable.';
  end if;

  perform private.replace_recurring_activity_content(
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
    p_exact_location_visibility
  );

  perform private.apply_recurring_activity_schedule(
    p_recurring_activity_id,
    activity.lifecycle_state,
    p_recurrence_type,
    p_weekday,
    p_day_of_month,
    p_local_start_time,
    p_duration_minutes,
    p_event_timezone,
    p_effective_from
  );

  if activity.lifecycle_state in ('published', 'paused') then
    perform private.assert_recurring_activity_publishable(p_recurring_activity_id);
  end if;

  return p_recurring_activity_id;
end;
$$;

create function public.publish_recurring_activity(
  p_expected_creator_profile_id uuid,
  p_recurring_activity_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_complete_recurring_activity_profile(
    p_expected_creator_profile_id
  );
  activity public.recurring_activities%rowtype;
begin
  select * into activity
  from public.recurring_activities
  where id = p_recurring_activity_id
  for update;

  if activity.id is null or activity.creator_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'The current user does not own this recurring activity.';
  end if;

  if activity.lifecycle_state = 'published' then
    return activity.id;
  end if;

  if activity.lifecycle_state <> 'draft' then
    raise exception using
      errcode = '55000',
      message = 'Only a draft recurring activity can be published.';
  end if;

  perform private.assert_recurring_activity_publishable(p_recurring_activity_id);

  update public.recurring_activities
  set
    lifecycle_state = 'published',
    published_at = statement_timestamp()
  where id = p_recurring_activity_id;

  insert into private.audit_events (
    action,
    actor_user_id,
    target_type,
    target_id
  )
  values (
    'recurring_activity.published',
    current_profile_id,
    'recurring_activity',
    p_recurring_activity_id
  );

  insert into private.outbox_events (event_type, payload)
  values (
    'recurring_activity.published',
    jsonb_build_object(
      'recurring_activity_id', p_recurring_activity_id,
      'actor_id', current_profile_id
    )
  );

  return p_recurring_activity_id;
end;
$$;

create function public.pause_recurring_activity(
  p_expected_creator_profile_id uuid,
  p_recurring_activity_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_expected_recurring_activity_identity(
    p_expected_creator_profile_id
  );
  activity public.recurring_activities%rowtype;
begin
  select * into activity
  from public.recurring_activities
  where id = p_recurring_activity_id
  for update;

  if activity.id is null or activity.creator_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'The current user does not own this recurring activity.';
  end if;

  if activity.lifecycle_state = 'paused' then
    return activity.id;
  end if;

  if activity.lifecycle_state <> 'published' then
    raise exception using
      errcode = '55000',
      message = 'Only a published recurring activity can be paused.';
  end if;

  update public.recurring_activities
  set
    lifecycle_state = 'paused',
    paused_at = statement_timestamp()
  where id = p_recurring_activity_id;

  insert into private.audit_events (
    action,
    actor_user_id,
    target_type,
    target_id
  )
  values (
    'recurring_activity.paused',
    current_profile_id,
    'recurring_activity',
    p_recurring_activity_id
  );

  insert into private.outbox_events (event_type, payload)
  values (
    'recurring_activity.paused',
    jsonb_build_object(
      'recurring_activity_id', p_recurring_activity_id,
      'actor_id', current_profile_id
    )
  );

  return p_recurring_activity_id;
end;
$$;

create function public.resume_recurring_activity(
  p_expected_creator_profile_id uuid,
  p_recurring_activity_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_complete_recurring_activity_profile(
    p_expected_creator_profile_id
  );
  activity public.recurring_activities%rowtype;
begin
  select * into activity
  from public.recurring_activities
  where id = p_recurring_activity_id
  for update;

  if activity.id is null or activity.creator_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'The current user does not own this recurring activity.';
  end if;

  if activity.lifecycle_state = 'published' then
    return activity.id;
  end if;

  if activity.lifecycle_state <> 'paused' then
    raise exception using
      errcode = '55000',
      message = 'Only a paused recurring activity can be resumed.';
  end if;

  perform private.assert_recurring_activity_publishable(p_recurring_activity_id);

  update public.recurring_activities
  set
    lifecycle_state = 'published',
    paused_at = null,
    resumed_at = statement_timestamp()
  where id = p_recurring_activity_id;

  insert into private.audit_events (
    action,
    actor_user_id,
    target_type,
    target_id
  )
  values (
    'recurring_activity.resumed',
    current_profile_id,
    'recurring_activity',
    p_recurring_activity_id
  );

  insert into private.outbox_events (event_type, payload)
  values (
    'recurring_activity.resumed',
    jsonb_build_object(
      'recurring_activity_id', p_recurring_activity_id,
      'actor_id', current_profile_id
    )
  );

  return p_recurring_activity_id;
end;
$$;

create function public.end_recurring_activity(
  p_expected_creator_profile_id uuid,
  p_recurring_activity_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_expected_recurring_activity_identity(
    p_expected_creator_profile_id
  );
  activity public.recurring_activities%rowtype;
begin
  select * into activity
  from public.recurring_activities
  where id = p_recurring_activity_id
  for update;

  if activity.id is null or activity.creator_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'The current user does not own this recurring activity.';
  end if;

  if activity.lifecycle_state = 'ended' then
    return activity.id;
  end if;

  if activity.lifecycle_state not in ('published', 'paused') then
    raise exception using
      errcode = '55000',
      message = 'Only a published or paused recurring activity can be ended.';
  end if;

  update public.recurring_activities
  set
    lifecycle_state = 'ended',
    ended_at = statement_timestamp()
  where id = p_recurring_activity_id;

  insert into private.audit_events (
    action,
    actor_user_id,
    target_type,
    target_id
  )
  values (
    'recurring_activity.ended',
    current_profile_id,
    'recurring_activity',
    p_recurring_activity_id
  );

  insert into private.outbox_events (event_type, payload)
  values (
    'recurring_activity.ended',
    jsonb_build_object(
      'recurring_activity_id', p_recurring_activity_id,
      'actor_id', current_profile_id
    )
  );

  return p_recurring_activity_id;
end;
$$;

create function public.list_public_recurring_activities(
  p_limit integer default 20,
  p_cursor_next_starts_at timestamptz default null,
  p_cursor_id uuid default null,
  p_locality text default null,
  p_reference_time timestamptz default statement_timestamp()
)
returns table (
  recurring_activity_id uuid,
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
  where activity.lifecycle_state = 'published'
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

create function public.list_public_recurring_activity_occurrences(
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
    and activity.lifecycle_state = 'published'
$$;

create function public.get_public_recurring_activity(
  p_recurring_activity_id uuid,
  p_occurrence_limit integer default 5,
  p_reference_time timestamptz default statement_timestamp()
)
returns table (
  recurring_activity_id uuid,
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
      when meeting.exact_location_visibility = 'public' then meeting.exact_meeting_text
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
    and activity.lifecycle_state in ('published', 'paused', 'ended');
end;
$$;

create function public.list_own_recurring_activities(
  p_expected_creator_profile_id uuid
)
returns table (
  recurring_activity_id uuid,
  lifecycle_state text,
  title text,
  summary text,
  description text,
  topic text,
  country_code text,
  locality text,
  administrative_area text,
  public_location_label text,
  current_schedule jsonb,
  schedule_history jsonb,
  exact_meeting_text text,
  exact_location_visibility text,
  created_at timestamptz,
  updated_at timestamptz,
  published_at timestamptz,
  paused_at timestamptz,
  resumed_at timestamptz,
  ended_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_expected_recurring_activity_identity(
    p_expected_creator_profile_id
  );
begin
  return query
  select
    activity.id,
    activity.lifecycle_state,
    activity.title,
    activity.summary,
    activity.description,
    activity.topic,
    activity.country_code,
    activity.locality,
    activity.administrative_area,
    activity.public_location_label,
    case
      when current_schedule.id is null then null
      else jsonb_build_object(
        'id', current_schedule.id,
        'recurrence_type', current_schedule.recurrence_type,
        'weekday', current_schedule.weekday,
        'day_of_month', current_schedule.day_of_month,
        'local_start_time', current_schedule.local_start_time,
        'duration_minutes', current_schedule.duration_minutes,
        'event_timezone', current_schedule.event_timezone,
        'effective_from', current_schedule.effective_from
      )
    end,
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', schedule.id,
            'recurrence_type', schedule.recurrence_type,
            'weekday', schedule.weekday,
            'day_of_month', schedule.day_of_month,
            'local_start_time', schedule.local_start_time,
            'duration_minutes', schedule.duration_minutes,
            'event_timezone', schedule.event_timezone,
            'effective_from', schedule.effective_from,
            'effective_until', schedule.effective_until,
            'created_at', schedule.created_at,
            'superseded_at', schedule.superseded_at
          )
          order by schedule.effective_from, schedule.id
        )
        from public.recurring_activity_schedules as schedule
        where schedule.recurring_activity_id = activity.id
      ),
      '[]'::jsonb
    ),
    meeting.exact_meeting_text,
    meeting.exact_location_visibility,
    activity.created_at,
    activity.updated_at,
    activity.published_at,
    activity.paused_at,
    activity.resumed_at,
    activity.ended_at
  from public.recurring_activities as activity
  join public.recurring_activity_meeting_details as meeting
    on meeting.recurring_activity_id = activity.id
  left join lateral (
    select schedule.*
    from public.recurring_activity_schedules as schedule
    where schedule.recurring_activity_id = activity.id
      and schedule.effective_until is null
    limit 1
  ) as current_schedule on true
  where activity.creator_profile_id = current_profile_id
  order by activity.created_at desc, activity.id;
end;
$$;

create function public.get_own_recurring_activity(
  p_expected_creator_profile_id uuid,
  p_recurring_activity_id uuid
)
returns table (
  recurring_activity_id uuid,
  lifecycle_state text,
  title text,
  summary text,
  description text,
  topic text,
  country_code text,
  locality text,
  administrative_area text,
  public_location_label text,
  current_schedule jsonb,
  schedule_history jsonb,
  exact_meeting_text text,
  exact_location_visibility text,
  created_at timestamptz,
  updated_at timestamptz,
  published_at timestamptz,
  paused_at timestamptz,
  resumed_at timestamptz,
  ended_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select *
  from public.list_own_recurring_activities(p_expected_creator_profile_id)
  where recurring_activity_id = p_recurring_activity_id
$$;

comment on function private.next_recurring_activity_occurrence(uuid, timestamptz) is
  'Finds one future occurrence without expanding an unbounded recurring series.';
comment on function private.derive_recurring_activity_occurrences(uuid, timestamptz, timestamptz, integer) is
  'Derives a finite occurrence window, capped at five years and 100 rows, from local wall-clock schedules.';
comment on function public.create_recurring_activity_draft(uuid, text, text, text, text, text, text, text, text, text, text, text, integer, integer, time, integer, text, date) is
  'Creates a complete-profile owner draft with optional complete weekly/monthly schedule configuration.';
comment on function public.update_own_recurring_activity(uuid, uuid, text, text, text, text, text, text, text, text, text, text, text, integer, integer, time, integer, text, date) is
  'Updates expected-owner content and creates a future schedule version when a published or paused schedule changes.';
comment on function public.publish_recurring_activity(uuid, uuid) is
  'Validates and idempotently publishes an own recurring draft with one minimal audit/outbox event.';
comment on function public.pause_recurring_activity(uuid, uuid) is
  'Idempotently pauses an own published recurring activity and removes it from normal discovery.';
comment on function public.resume_recurring_activity(uuid, uuid) is
  'Idempotently resumes an own paused recurring activity after revalidating its future schedule.';
comment on function public.end_recurring_activity(uuid, uuid) is
  'Idempotently ends an own published or paused recurring activity while retaining canonical history.';
comment on function public.list_public_recurring_activities(integer, timestamptz, uuid, text, timestamptz) is
  'Returns bounded sanitized published Tavoli ordered by derived next occurrence and rough location.';
comment on function public.list_public_recurring_activity_occurrences(uuid, timestamptz, timestamptz, integer) is
  'Returns a bounded public occurrence window only for an active published recurring activity.';
comment on function public.get_public_recurring_activity(uuid, integer, timestamptz) is
  'Returns sanitized exact-ID published, paused, or ended detail with bounded active occurrences.';
comment on function public.list_own_recurring_activities(uuid) is
  'Returns complete expected-owner recurring activity content, latest schedule, schedule history, and exact meeting data.';
comment on function public.get_own_recurring_activity(uuid, uuid) is
  'Returns one complete expected-owner recurring activity for later management UI.';

revoke all privileges on function private.set_recurring_activity_updated_at()
  from public, anon, authenticated, service_role;
revoke all privileges on function private.prevent_recurring_schedule_overlap()
  from public, anon, authenticated, service_role;
revoke all privileges on function private.require_expected_recurring_activity_identity(uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function private.require_complete_recurring_activity_profile(uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function private.replace_recurring_activity_content(uuid, text, text, text, text, text, text, text, text, text, text)
  from public, anon, authenticated, service_role;
revoke all privileges on function private.apply_recurring_activity_schedule(uuid, text, text, integer, integer, time, integer, text, date)
  from public, anon, authenticated, service_role;
revoke all privileges on function private.next_recurring_activity_occurrence(uuid, timestamptz)
  from public, anon, authenticated, service_role;
revoke all privileges on function private.derive_recurring_activity_occurrences(uuid, timestamptz, timestamptz, integer)
  from public, anon, authenticated, service_role;
revoke all privileges on function private.assert_recurring_activity_publishable(uuid)
  from public, anon, authenticated, service_role;

revoke all privileges on function public.create_recurring_activity_draft(uuid, text, text, text, text, text, text, text, text, text, text, text, integer, integer, time, integer, text, date)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.update_own_recurring_activity(uuid, uuid, text, text, text, text, text, text, text, text, text, text, text, integer, integer, time, integer, text, date)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.publish_recurring_activity(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.pause_recurring_activity(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.resume_recurring_activity(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.end_recurring_activity(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.list_public_recurring_activities(integer, timestamptz, uuid, text, timestamptz)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.list_public_recurring_activity_occurrences(uuid, timestamptz, timestamptz, integer)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.get_public_recurring_activity(uuid, integer, timestamptz)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.list_own_recurring_activities(uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.get_own_recurring_activity(uuid, uuid)
  from public, anon, authenticated, service_role;

grant execute on function public.create_recurring_activity_draft(uuid, text, text, text, text, text, text, text, text, text, text, text, integer, integer, time, integer, text, date)
  to authenticated;
grant execute on function public.update_own_recurring_activity(uuid, uuid, text, text, text, text, text, text, text, text, text, text, text, integer, integer, time, integer, text, date)
  to authenticated;
grant execute on function public.publish_recurring_activity(uuid, uuid)
  to authenticated;
grant execute on function public.pause_recurring_activity(uuid, uuid)
  to authenticated;
grant execute on function public.resume_recurring_activity(uuid, uuid)
  to authenticated;
grant execute on function public.end_recurring_activity(uuid, uuid)
  to authenticated;
grant execute on function public.list_own_recurring_activities(uuid)
  to authenticated;
grant execute on function public.get_own_recurring_activity(uuid, uuid)
  to authenticated;
grant execute on function public.list_public_recurring_activities(integer, timestamptz, uuid, text, timestamptz)
  to anon, authenticated;
grant execute on function public.list_public_recurring_activity_occurrences(uuid, timestamptz, timestamptz, integer)
  to anon, authenticated;
grant execute on function public.get_public_recurring_activity(uuid, integer, timestamptz)
  to anon, authenticated;
