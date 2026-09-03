create table public.proposals (
  id uuid primary key default gen_random_uuid(),
  creator_profile_id uuid not null
    constraint proposals_creator_profile_id_fkey
      references public.profiles (id) on delete restrict,
  lifecycle_state text not null default 'draft'
    constraint proposals_lifecycle_state_valid check (
      lifecycle_state in ('draft', 'published', 'cancelled')
    ),
  title text
    constraint proposals_title_valid check (
      title is null
      or (title = btrim(title) and char_length(title) between 2 and 100)
    ),
  summary text
    constraint proposals_summary_valid check (
      summary is null
      or (summary = btrim(summary) and char_length(summary) between 1 and 240)
    ),
  description text
    constraint proposals_description_valid check (
      description is null
      or (description = btrim(description) and char_length(description) between 1 and 5000)
    ),
  starts_at timestamptz,
  ends_at timestamptz,
  event_timezone text
    constraint proposals_event_timezone_valid check (
      event_timezone is null
      or (
        event_timezone = btrim(event_timezone)
        and char_length(event_timezone) between 1 and 100
      )
    ),
  country_code text
    constraint proposals_country_code_valid check (
      country_code is null or country_code ~ '^[A-Z]{2}$'
    ),
  locality text
    constraint proposals_locality_valid check (
      locality is null
      or (locality = btrim(locality) and char_length(locality) between 1 and 120)
    ),
  administrative_area text
    constraint proposals_administrative_area_valid check (
      administrative_area is null
      or (
        administrative_area = btrim(administrative_area)
        and char_length(administrative_area) between 1 and 120
      )
    ),
  public_location_label text
    constraint proposals_public_location_label_valid check (
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
  cancelled_at timestamptz,
  constraint proposals_schedule_order_valid check (
    starts_at is null or ends_at is null or ends_at > starts_at
  ),
  constraint proposals_lifecycle_timestamps_valid check (
    (
      lifecycle_state = 'draft'
      and published_at is null
      and cancelled_at is null
    )
    or (
      lifecycle_state = 'published'
      and published_at is not null
      and cancelled_at is null
    )
    or (
      lifecycle_state = 'cancelled'
      and published_at is not null
      and cancelled_at is not null
      and cancelled_at >= published_at
    )
  )
);

comment on table public.proposals is
  'Canonical one-time proposal records with explicit business lifecycle and public rough location.';
comment on column public.proposals.lifecycle_state is
  'Stored business state only; upcoming, happening, just-finished, and completed are time-derived.';
comment on column public.proposals.event_timezone is
  'IANA time-zone identifier validated when a proposal is published.';
comment on column public.proposals.approximate_location is
  'Optional rough map-ready point; exact meeting coordinates never belong in this column.';

create table public.proposal_meeting_details (
  proposal_id uuid primary key
    constraint proposal_meeting_details_proposal_id_fkey
      references public.proposals (id) on delete cascade,
  exact_meeting_text text
    constraint proposal_meeting_details_text_valid check (
      exact_meeting_text is null
      or (
        exact_meeting_text = btrim(exact_meeting_text)
        and char_length(exact_meeting_text) between 1 and 1000
      )
    ),
  exact_location_visibility text not null default 'participants'
    constraint proposal_meeting_details_visibility_valid check (
      exact_location_visibility in ('public', 'participants')
    ),
  exact_location extensions.geography(point, 4326),
  updated_at timestamptz not null default now()
);

comment on table public.proposal_meeting_details is
  'One-to-one exact meeting information, physically separated from public rough location.';
comment on column public.proposal_meeting_details.exact_location_visibility is
  'Public exposes exact details; participants is reserved for the accepted-participant read path in plan 05.';

create table public.proposal_skills (
  proposal_id uuid not null
    constraint proposal_skills_proposal_id_fkey
      references public.proposals (id) on delete cascade,
  skill_id uuid not null
    constraint proposal_skills_skill_id_fkey
      references public.skills (id) on delete restrict,
  importance text not null
    constraint proposal_skills_importance_valid check (
      importance in ('required', 'useful')
    ),
  created_at timestamptz not null default now(),
  primary key (proposal_id, skill_id)
);

comment on table public.proposal_skills is
  'Required or useful proposal capabilities from the canonical controlled skill catalog.';

create index proposals_creator_profile_id_created_at_idx
  on public.proposals (creator_profile_id, created_at desc, id);

create index proposals_published_starts_at_id_idx
  on public.proposals (starts_at, id)
  where lifecycle_state = 'published';

create index proposals_published_locality_starts_at_id_idx
  on public.proposals (locality, starts_at, id)
  where lifecycle_state = 'published';

create index proposal_skills_skill_id_proposal_id_idx
  on public.proposal_skills (skill_id, proposal_id);

create function private.set_proposal_updated_at()
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

create trigger proposals_set_updated_at
before update on public.proposals
for each row
execute function private.set_proposal_updated_at();

create trigger proposal_meeting_details_set_updated_at
before update on public.proposal_meeting_details
for each row
execute function private.set_proposal_updated_at();

alter table public.proposals enable row level security;
alter table public.proposal_meeting_details enable row level security;
alter table public.proposal_skills enable row level security;

create policy "Creators can read their own proposals"
on public.proposals
for select
to authenticated
using ((select auth.uid()) = creator_profile_id);

create policy "Creators can read their own meeting details"
on public.proposal_meeting_details
for select
to authenticated
using (
  exists (
    select 1
    from public.proposals as proposal
    where proposal.id = proposal_meeting_details.proposal_id
      and proposal.creator_profile_id = (select auth.uid())
  )
);

create policy "Creators can read their own proposal skills"
on public.proposal_skills
for select
to authenticated
using (
  exists (
    select 1
    from public.proposals as proposal
    where proposal.id = proposal_skills.proposal_id
      and proposal.creator_profile_id = (select auth.uid())
  )
);

grant select on table public.proposals to authenticated;
grant select on table public.proposal_meeting_details to authenticated;
grant select on table public.proposal_skills to authenticated;

create function private.require_expected_identity(p_expected_profile_id uuid)
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
      message = 'Authentication is required to manage a proposal.';
  end if;

  if p_expected_profile_id is null
    or p_expected_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'The authenticated user does not match the expected proposal creator.';
  end if;

  return current_profile_id;
end;
$$;

create function private.require_complete_profile(p_expected_profile_id uuid)
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_expected_identity(p_expected_profile_id);
begin
  if not exists (
    select 1
    from public.profiles as profile
    where profile.id = current_profile_id
      and profile.display_name is not null
  ) then
    raise exception using
      errcode = '55000',
      message = 'A complete profile is required to create or publish a proposal.';
  end if;

  return current_profile_id;
end;
$$;

create function private.derive_proposal_status(
  p_starts_at timestamptz,
  p_ends_at timestamptz,
  p_reference_time timestamptz
)
returns text
language sql
immutable
security invoker
set search_path = ''
as $$
  select case
    when p_reference_time < p_starts_at then 'upcoming'
    when p_reference_time < p_ends_at then 'happening'
    when p_reference_time < p_ends_at + interval '24 hours' then 'just_finished'
    else 'completed'
  end
$$;

create function private.replace_proposal_content(
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
  p_skill_importances text[]
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
  normalized_timezone text := nullif(btrim(p_event_timezone), '');
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
      message = 'Proposal title must contain between 2 and 100 characters.';
  end if;

  if normalized_summary is not null and char_length(normalized_summary) > 240 then
    raise exception using
      errcode = '22023',
      message = 'Proposal summary must contain at most 240 characters.';
  end if;

  if normalized_description is not null and char_length(normalized_description) > 5000 then
    raise exception using
      errcode = '22023',
      message = 'Proposal description must contain at most 5000 characters.';
  end if;

  if normalized_timezone is not null and char_length(normalized_timezone) > 100 then
    raise exception using
      errcode = '22023',
      message = 'Proposal time zone is invalid.';
  end if;

  if normalized_country_code is not null
    and normalized_country_code !~ '^[A-Z]{2}$' then
    raise exception using
      errcode = '22023',
      message = 'Proposal country code must contain two letters.';
  end if;

  if normalized_locality is not null and char_length(normalized_locality) > 120 then
    raise exception using
      errcode = '22023',
      message = 'Proposal locality must contain at most 120 characters.';
  end if;

  if normalized_administrative_area is not null
    and char_length(normalized_administrative_area) > 120 then
    raise exception using
      errcode = '22023',
      message = 'Proposal administrative area must contain at most 120 characters.';
  end if;

  if normalized_public_location_label is not null
    and char_length(normalized_public_location_label) > 180 then
    raise exception using
      errcode = '22023',
      message = 'Proposal public location label must contain at most 180 characters.';
  end if;

  if normalized_exact_meeting_text is not null
    and char_length(normalized_exact_meeting_text) > 1000 then
    raise exception using
      errcode = '22023',
      message = 'Exact meeting information must contain at most 1000 characters.';
  end if;

  if normalized_visibility not in ('public', 'participants') then
    raise exception using
      errcode = '22023',
      message = 'Exact location visibility must be public or participants.';
  end if;

  if p_starts_at is not null and p_ends_at is not null and p_ends_at <= p_starts_at then
    raise exception using
      errcode = '22023',
      message = 'Proposal end time must be later than its start time.';
  end if;

  if p_skill_ids is null
    or p_skill_importances is null
    or cardinality(p_skill_ids) <> cardinality(p_skill_importances)
    or array_position(p_skill_ids, null) is not null
    or array_position(p_skill_importances, null) is not null then
    raise exception using
      errcode = '22023',
      message = 'Proposal skills and importance values must be matching non-null lists.';
  end if;

  if cardinality(p_skill_ids) <> (
    select count(distinct requested.skill_id)
    from unnest(p_skill_ids) as requested(skill_id)
  ) then
    raise exception using
      errcode = '22023',
      message = 'A proposal skill may be selected only once.';
  end if;

  if exists (
    select 1
    from unnest(p_skill_importances) as requested(importance)
    where requested.importance not in ('required', 'useful')
  ) then
    raise exception using
      errcode = '22023',
      message = 'Proposal skill importance must be required or useful.';
  end if;

  if exists (
    select 1
    from unnest(p_skill_ids) as requested(skill_id)
    left join public.skills as skill on skill.id = requested.skill_id
    where skill.id is null
  ) then
    raise exception using
      errcode = '22023',
      message = 'One or more proposal skills are not in the catalog.';
  end if;

  update public.proposals
  set
    title = normalized_title,
    summary = normalized_summary,
    description = normalized_description,
    starts_at = p_starts_at,
    ends_at = p_ends_at,
    event_timezone = normalized_timezone,
    country_code = normalized_country_code,
    locality = normalized_locality,
    administrative_area = normalized_administrative_area,
    public_location_label = normalized_public_location_label
  where id = p_proposal_id;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'The proposal does not exist.';
  end if;

  insert into public.proposal_meeting_details (
    proposal_id,
    exact_meeting_text,
    exact_location_visibility
  )
  values (
    p_proposal_id,
    normalized_exact_meeting_text,
    normalized_visibility
  )
  on conflict (proposal_id)
  do update set
    exact_meeting_text = excluded.exact_meeting_text,
    exact_location_visibility = excluded.exact_location_visibility;

  delete from public.proposal_skills
  where proposal_id = p_proposal_id;

  insert into public.proposal_skills (proposal_id, skill_id, importance)
  select
    p_proposal_id,
    requested.skill_id,
    requested.importance
  from unnest(p_skill_ids, p_skill_importances) as requested(skill_id, importance);
end;
$$;

create function private.assert_proposal_publishable(
  p_proposal_id uuid,
  p_require_future_start boolean
)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  proposal public.proposals%rowtype;
  meeting public.proposal_meeting_details%rowtype;
begin
  select * into proposal
  from public.proposals
  where id = p_proposal_id;

  select * into meeting
  from public.proposal_meeting_details
  where proposal_id = p_proposal_id;

  if proposal.title is null
    or proposal.summary is null
    or proposal.description is null
    or proposal.starts_at is null
    or proposal.ends_at is null
    or proposal.event_timezone is null
    or proposal.country_code is null
    or proposal.locality is null
    or proposal.public_location_label is null
    or meeting.proposal_id is null
    or meeting.exact_meeting_text is null then
    raise exception using
      errcode = '22023',
      message = 'Published proposals require complete content, schedule, rough location, and exact meeting information.';
  end if;

  if proposal.ends_at <= proposal.starts_at then
    raise exception using
      errcode = '22023',
      message = 'Proposal end time must be later than its start time.';
  end if;

  if proposal.ends_at <= statement_timestamp() then
    raise exception using
      errcode = '22023',
      message = 'A proposal cannot be published after it has ended.';
  end if;

  if p_require_future_start and proposal.starts_at <= statement_timestamp() then
    raise exception using
      errcode = '55000',
      message = 'A published proposal cannot be edited after it starts.';
  end if;

  if not exists (
    select 1
    from pg_catalog.pg_timezone_names as time_zone
    where time_zone.name = proposal.event_timezone
  ) then
    raise exception using
      errcode = '22023',
      message = 'Proposal time zone must be a recognized IANA identifier.';
  end if;
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
  p_skill_importances text[]
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_complete_profile(
    p_expected_creator_profile_id
  );
  proposal_id uuid;
begin
  insert into public.proposals (creator_profile_id)
  values (current_profile_id)
  returning id into proposal_id;

  perform private.replace_proposal_content(
    proposal_id,
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

  return proposal_id;
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
  p_skill_importances text[]
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_expected_identity(
    p_expected_creator_profile_id
  );
  proposal public.proposals%rowtype;
begin
  select * into proposal
  from public.proposals
  where id = p_proposal_id
  for update;

  if proposal.id is null or proposal.creator_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'The current user does not own this proposal.';
  end if;

  if proposal.lifecycle_state = 'published'
    and proposal.starts_at <= statement_timestamp() then
    raise exception using
      errcode = '55000',
      message = 'A published proposal cannot be edited after it starts.';
  end if;

  if proposal.lifecycle_state not in ('draft', 'published') then
    raise exception using
      errcode = '55000',
      message = 'This proposal can no longer be edited.';
  end if;

  perform private.replace_proposal_content(
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

  if proposal.lifecycle_state = 'published' then
    perform private.assert_proposal_publishable(p_proposal_id, true);
  end if;

  return p_proposal_id;
end;
$$;

create function public.publish_proposal(
  p_expected_creator_profile_id uuid,
  p_proposal_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_complete_profile(
    p_expected_creator_profile_id
  );
  proposal public.proposals%rowtype;
begin
  select * into proposal
  from public.proposals
  where id = p_proposal_id
  for update;

  if proposal.id is null or proposal.creator_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'The current user does not own this proposal.';
  end if;

  if proposal.lifecycle_state = 'published' then
    return proposal.id;
  end if;

  if proposal.lifecycle_state <> 'draft' then
    raise exception using
      errcode = '55000',
      message = 'Only a draft proposal can be published.';
  end if;

  perform private.assert_proposal_publishable(p_proposal_id, false);

  update public.proposals
  set
    lifecycle_state = 'published',
    published_at = statement_timestamp()
  where id = p_proposal_id;

  insert into private.audit_events (
    action,
    actor_user_id,
    target_type,
    target_id
  )
  values (
    'proposal.published',
    current_profile_id,
    'proposal',
    p_proposal_id
  );

  insert into private.outbox_events (event_type, payload)
  values (
    'proposal.published',
    jsonb_build_object(
      'proposal_id', p_proposal_id,
      'actor_id', current_profile_id
    )
  );

  return p_proposal_id;
end;
$$;

create function public.cancel_proposal(
  p_expected_creator_profile_id uuid,
  p_proposal_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_expected_identity(
    p_expected_creator_profile_id
  );
  proposal public.proposals%rowtype;
begin
  select * into proposal
  from public.proposals
  where id = p_proposal_id
  for update;

  if proposal.id is null or proposal.creator_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'The current user does not own this proposal.';
  end if;

  if proposal.lifecycle_state <> 'published' then
    raise exception using
      errcode = '55000',
      message = 'Only a published proposal can be cancelled.';
  end if;

  if proposal.ends_at <= statement_timestamp() then
    raise exception using
      errcode = '55000',
      message = 'A proposal cannot be cancelled after it ends.';
  end if;

  update public.proposals
  set
    lifecycle_state = 'cancelled',
    cancelled_at = statement_timestamp()
  where id = p_proposal_id;

  insert into private.audit_events (
    action,
    actor_user_id,
    target_type,
    target_id
  )
  values (
    'proposal.cancelled',
    current_profile_id,
    'proposal',
    p_proposal_id
  );

  insert into private.outbox_events (event_type, payload)
  values (
    'proposal.cancelled',
    jsonb_build_object(
      'proposal_id', p_proposal_id,
      'actor_id', current_profile_id
    )
  );

  return p_proposal_id;
end;
$$;

create function public.list_public_proposals(
  p_limit integer default 20,
  p_cursor_starts_at timestamptz default null,
  p_cursor_id uuid default null,
  p_locality text default null,
  p_skill_ids uuid[] default null
)
returns table (
  proposal_id uuid,
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

  return query
  select
    proposal.id as proposal_id,
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
    ) as derived_status,
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
    ) as skills
  from public.proposals as proposal
  where proposal.lifecycle_state = 'published'
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
    and (
      p_cursor_starts_at is null
      or (proposal.starts_at, proposal.id) > (p_cursor_starts_at, p_cursor_id)
    )
  order by proposal.starts_at, proposal.id
  limit p_limit;
end;
$$;

create function public.get_public_proposal(p_proposal_id uuid)
returns table (
  proposal_id uuid,
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
    proposal.id as proposal_id,
    proposal.creator_profile_id,
    case
      when display_visibility.audience = 'public' then creator.display_name
      else null
    end as creator_display_name,
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
    ) as derived_status,
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
    ) as skills,
    case
      when meeting.exact_location_visibility = 'public' then meeting.exact_meeting_text
      else null
    end as exact_meeting_text,
    meeting.exact_location_visibility = 'participants' as exact_location_restricted
  from public.proposals as proposal
  join public.profiles as creator on creator.id = proposal.creator_profile_id
  left join public.profile_field_visibility as display_visibility
    on display_visibility.profile_id = creator.id
    and display_visibility.field_key = 'display_name'
  join public.proposal_meeting_details as meeting on meeting.proposal_id = proposal.id
  where proposal.id = p_proposal_id
    and proposal.lifecycle_state = 'published'
$$;

create function public.list_own_proposals(p_expected_creator_profile_id uuid)
returns table (
  proposal_id uuid,
  lifecycle_state text,
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
  exact_location_visibility text,
  created_at timestamptz,
  updated_at timestamptz,
  published_at timestamptz,
  cancelled_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_expected_identity(
    p_expected_creator_profile_id
  );
begin
  return query
  select
    proposal.id as proposal_id,
    proposal.lifecycle_state,
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
    case
      when proposal.lifecycle_state = 'published' then private.derive_proposal_status(
        proposal.starts_at,
        proposal.ends_at,
        statement_timestamp()
      )
      else null
    end as derived_status,
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
    ) as skills,
    meeting.exact_meeting_text,
    meeting.exact_location_visibility,
    proposal.created_at,
    proposal.updated_at,
    proposal.published_at,
    proposal.cancelled_at
  from public.proposals as proposal
  join public.proposal_meeting_details as meeting on meeting.proposal_id = proposal.id
  where proposal.creator_profile_id = current_profile_id
  order by proposal.created_at desc, proposal.id;
end;
$$;

create function public.get_own_proposal(
  p_expected_creator_profile_id uuid,
  p_proposal_id uuid
)
returns table (
  proposal_id uuid,
  lifecycle_state text,
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
  exact_location_visibility text,
  created_at timestamptz,
  updated_at timestamptz,
  published_at timestamptz,
  cancelled_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select *
  from public.list_own_proposals(p_expected_creator_profile_id)
  where proposal_id = p_proposal_id
$$;

comment on function private.derive_proposal_status(timestamptz, timestamptz, timestamptz) is
  'Derives upcoming, happening, just-finished, or completed without persisting clock-driven state.';
comment on function public.create_proposal_draft(uuid, text, text, text, timestamptz, timestamptz, text, text, text, text, text, text, text, uuid[], text[]) is
  'Atomically creates a complete-profile owner draft and its meeting/skill records.';
comment on function public.update_own_proposal(uuid, uuid, text, text, text, timestamptz, timestamptz, text, text, text, text, text, text, text, uuid[], text[]) is
  'Atomically updates the expected creator own editable draft or future published proposal.';
comment on function public.publish_proposal(uuid, uuid) is
  'Validates and idempotently publishes an own draft while recording minimal audit/outbox events.';
comment on function public.cancel_proposal(uuid, uuid) is
  'Terminally cancels an own published proposal before its end time.';
comment on function public.list_public_proposals(integer, timestamptz, uuid, text, uuid[]) is
  'Returns a cursor-paginated sanitized public discovery page with rough location only.';
comment on function public.get_public_proposal(uuid) is
  'Returns exact-ID published detail while withholding participant-restricted meeting information.';
comment on function public.list_own_proposals(uuid) is
  'Returns the expected current creator complete proposal history, including private draft/meeting data.';
comment on function public.get_own_proposal(uuid, uuid) is
  'Returns one expected current creator proposal for editing.';

revoke all privileges on function private.set_proposal_updated_at()
  from public, anon, authenticated, service_role;
revoke all privileges on function private.require_expected_identity(uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function private.require_complete_profile(uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function private.derive_proposal_status(timestamptz, timestamptz, timestamptz)
  from public, anon, authenticated, service_role;
revoke all privileges on function private.replace_proposal_content(uuid, text, text, text, timestamptz, timestamptz, text, text, text, text, text, text, text, uuid[], text[])
  from public, anon, authenticated, service_role;
revoke all privileges on function private.assert_proposal_publishable(uuid, boolean)
  from public, anon, authenticated, service_role;

revoke all privileges on function public.create_proposal_draft(uuid, text, text, text, timestamptz, timestamptz, text, text, text, text, text, text, text, uuid[], text[])
  from public, anon, authenticated, service_role;
revoke all privileges on function public.update_own_proposal(uuid, uuid, text, text, text, timestamptz, timestamptz, text, text, text, text, text, text, text, uuid[], text[])
  from public, anon, authenticated, service_role;
revoke all privileges on function public.publish_proposal(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.cancel_proposal(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.list_public_proposals(integer, timestamptz, uuid, text, uuid[])
  from public, anon, authenticated, service_role;
revoke all privileges on function public.get_public_proposal(uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.list_own_proposals(uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.get_own_proposal(uuid, uuid)
  from public, anon, authenticated, service_role;

grant execute on function public.create_proposal_draft(uuid, text, text, text, timestamptz, timestamptz, text, text, text, text, text, text, text, uuid[], text[])
  to authenticated;
grant execute on function public.update_own_proposal(uuid, uuid, text, text, text, timestamptz, timestamptz, text, text, text, text, text, text, text, uuid[], text[])
  to authenticated;
grant execute on function public.publish_proposal(uuid, uuid)
  to authenticated;
grant execute on function public.cancel_proposal(uuid, uuid)
  to authenticated;
grant execute on function public.list_own_proposals(uuid)
  to authenticated;
grant execute on function public.get_own_proposal(uuid, uuid)
  to authenticated;
grant execute on function public.list_public_proposals(integer, timestamptz, uuid, text, uuid[])
  to anon, authenticated;
grant execute on function public.get_public_proposal(uuid)
  to anon, authenticated;
