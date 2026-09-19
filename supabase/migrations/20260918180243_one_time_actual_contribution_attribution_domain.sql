create table public.project_membership_actual_skill_overrides (
  membership_id uuid not null
    constraint project_membership_actual_skill_overrides_membership_id_fkey
      references public.project_memberships (id) on delete restrict,
  skill_id uuid not null
    constraint project_membership_actual_skill_overrides_skill_id_fkey
      references public.skills (id) on delete restrict,
  is_included boolean not null,
  updated_at timestamptz not null default now(),
  updated_by_profile_id uuid not null
    constraint project_membership_actual_skill_overrides_updated_by_fkey
      references public.profiles (id) on delete restrict,
  primary key (membership_id, skill_id)
);

comment on table public.project_membership_actual_skill_overrides is
  'Sparse creator corrections to the frozen final-skill-commitment baseline for one ended one-time Project membership episode.';
comment on column public.project_membership_actual_skill_overrides.is_included is
  'Effective truth only when it differs from the automatic final-commitment baseline.';

create index project_membership_actual_skill_overrides_skill_membership_idx
  on public.project_membership_actual_skill_overrides (
    skill_id,
    membership_id
  );
create index project_membership_actual_skill_overrides_updated_by_idx
  on public.project_membership_actual_skill_overrides (
    updated_by_profile_id
  );

create table public.project_membership_actual_resource_overrides (
  membership_id uuid not null
    constraint project_membership_actual_resource_overrides_membership_id_fkey
      references public.project_memberships (id) on delete restrict,
  resource_need_id uuid not null
    constraint project_membership_actual_resource_overrides_need_id_fkey
      references public.project_resource_needs (id) on delete restrict,
  is_included boolean not null,
  updated_at timestamptz not null default now(),
  updated_by_profile_id uuid not null
    constraint project_membership_actual_resource_overrides_updated_by_fkey
      references public.profiles (id) on delete restrict,
  primary key (membership_id, resource_need_id)
);

comment on table public.project_membership_actual_resource_overrides is
  'Sparse creator corrections to the frozen final-resource-commitment baseline for one ended one-time Project membership episode.';
comment on column public.project_membership_actual_resource_overrides.is_included is
  'Effective truth only when it differs from the automatic final-commitment baseline.';

create index project_membership_actual_resource_overrides_need_membership_idx
  on public.project_membership_actual_resource_overrides (
    resource_need_id,
    membership_id
  );
create index project_membership_actual_resource_overrides_updated_by_idx
  on public.project_membership_actual_resource_overrides (
    updated_by_profile_id
  );

create table public.project_membership_actual_effort_markers (
  membership_id uuid primary key
    constraint project_membership_actual_effort_markers_membership_id_fkey
      references public.project_memberships (id) on delete restrict,
  marked_at timestamptz not null default now(),
  marked_by_profile_id uuid not null
    constraint project_membership_actual_effort_markers_marked_by_fkey
      references public.profiles (id) on delete restrict
);

comment on table public.project_membership_actual_effort_markers is
  'Built-in Substantial Effort / Energy attribution for one membership episode; it is not a skill, resource need, matching item, or coverage source.';

create index project_membership_actual_effort_markers_marked_by_idx
  on public.project_membership_actual_effort_markers (marked_by_profile_id);

alter table public.project_membership_actual_skill_overrides
  enable row level security;
alter table public.project_membership_actual_resource_overrides
  enable row level security;
alter table public.project_membership_actual_effort_markers
  enable row level security;

revoke all privileges on table
  public.project_membership_actual_skill_overrides
  from public, anon, authenticated, service_role;
revoke all privileges on table
  public.project_membership_actual_resource_overrides
  from public, anon, authenticated, service_role;
revoke all privileges on table
  public.project_membership_actual_effort_markers
  from public, anon, authenticated, service_role;

create function private.lock_project_for_actual_contribution_mutation(
  p_project_id uuid
)
returns table (creator_profile_id uuid, project_ends_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare
  registry public.projects%rowtype;
  source_creator_profile_id uuid;
  source_lifecycle_state text;
  source_ends_at timestamptz;
begin
  select * into registry
  from public.projects as project
  where project.id = p_project_id;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'The requested project does not exist.';
  end if;

  if registry.project_kind <> 'one_time' then
    raise exception using
      errcode = '55000',
      message = 'Actual contributions are available only for ended one-time Proposals.';
  end if;

  -- Preserve the established order: concrete Proposal, shared Project,
  -- membership in the caller, then resource rows when desired IDs require it.
  select
    proposal.creator_profile_id,
    proposal.lifecycle_state,
    proposal.ends_at
  into
    source_creator_profile_id,
    source_lifecycle_state,
    source_ends_at
  from public.proposals as proposal
  where proposal.id = registry.id
  for share;

  if not found or source_creator_profile_id <> registry.creator_profile_id then
    raise exception using
      errcode = '55000',
      message = 'The project registry is inconsistent with its concrete activity.';
  end if;

  if source_lifecycle_state <> 'published'
    or source_ends_at is null
    or statement_timestamp() < source_ends_at then
    raise exception using
      errcode = '55000',
      message = 'Actual contributions are available only for ended published one-time Proposals.';
  end if;

  select * into registry
  from public.projects as project
  where project.id = p_project_id
  for update;

  return query select registry.creator_profile_id, source_ends_at;
end;
$$;

create function private.record_project_actual_contributions_updated_event(
  p_actor_profile_id uuid,
  p_project_id uuid,
  p_membership_id uuid,
  p_participant_profile_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  identifier_payload jsonb := jsonb_build_object(
    'project_id', p_project_id,
    'project_kind', 'one_time',
    'membership_id', p_membership_id,
    'participant_profile_id', p_participant_profile_id,
    'actor_profile_id', p_actor_profile_id
  );
begin
  insert into private.audit_events (
    action,
    actor_user_id,
    target_type,
    target_id,
    metadata
  )
  values (
    'project.actual_contributions_updated',
    p_actor_profile_id,
    'project_membership',
    p_membership_id,
    identifier_payload
  );

  insert into private.outbox_events (event_type, payload)
  values ('project.actual_contributions_updated', identifier_payload);
end;
$$;

create function public.list_project_membership_actual_contributions(
  p_expected_profile_id uuid,
  p_membership_id uuid
)
returns table (
  contribution_kind text,
  contribution_id uuid,
  label text,
  attribution_source text
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
  membership_record public.project_memberships%rowtype;
  registry public.projects%rowtype;
  proposal_record public.proposals%rowtype;
  baseline_eligible boolean;
begin
  select * into membership_record
  from public.project_memberships as membership
  where membership.id = p_membership_id;

  if not found then
    raise exception using
      errcode = '42501',
      message = 'The actual contributions are unavailable.';
  end if;

  select * into registry
  from public.projects as project
  where project.id = membership_record.project_id;

  if not found
    or (
      membership_record.participant_profile_id <> current_profile_id
      and registry.creator_profile_id <> current_profile_id
    ) then
    raise exception using
      errcode = '42501',
      message = 'The actual contributions are unavailable.';
  end if;

  if registry.project_kind <> 'one_time' then
    raise exception using
      errcode = '55000',
      message = 'Actual contributions are available only for ended one-time Proposals.';
  end if;

  select * into proposal_record
  from public.proposals as proposal
  where proposal.id = registry.id;

  if not found or proposal_record.creator_profile_id <> registry.creator_profile_id then
    raise exception using
      errcode = '55000',
      message = 'The project registry is inconsistent with its concrete activity.';
  end if;

  if proposal_record.lifecycle_state <> 'published'
    or proposal_record.ends_at is null
    or statement_timestamp() < proposal_record.ends_at then
    raise exception using
      errcode = '55000',
      message = 'Actual contributions are available only for ended published one-time Proposals.';
  end if;

  baseline_eligible :=
    membership_record.joined_at <= proposal_record.ends_at
    and (
      coalesce(membership_record.left_at, membership_record.removed_at) is null
      or proposal_record.ends_at < coalesce(
        membership_record.left_at,
        membership_record.removed_at
      )
    );

  return query
  with baseline_skills as (
    select commitment.skill_id
    from public.project_membership_skill_commitments as commitment
    where baseline_eligible
      and commitment.membership_id = p_membership_id
  ),
  skill_candidates as (
    select baseline.skill_id from baseline_skills as baseline
    union
    select override_row.skill_id
    from public.project_membership_actual_skill_overrides as override_row
    where override_row.membership_id = p_membership_id
  ),
  effective_skills as (
    select
      candidate.skill_id,
      baseline.skill_id is not null as is_baseline
    from skill_candidates as candidate
    left join baseline_skills as baseline on baseline.skill_id = candidate.skill_id
    left join public.project_membership_actual_skill_overrides as override_row
      on override_row.membership_id = p_membership_id
      and override_row.skill_id = candidate.skill_id
    where coalesce(
      override_row.is_included,
      baseline.skill_id is not null
    )
  ),
  baseline_resources as (
    select commitment.resource_need_id
    from public.project_membership_resource_commitments as commitment
    where baseline_eligible
      and commitment.membership_id = p_membership_id
  ),
  resource_candidates as (
    select baseline.resource_need_id from baseline_resources as baseline
    union
    select override_row.resource_need_id
    from public.project_membership_actual_resource_overrides as override_row
    where override_row.membership_id = p_membership_id
  ),
  effective_resources as (
    select
      candidate.resource_need_id,
      baseline.resource_need_id is not null as is_baseline
    from resource_candidates as candidate
    left join baseline_resources as baseline
      on baseline.resource_need_id = candidate.resource_need_id
    left join public.project_membership_actual_resource_overrides as override_row
      on override_row.membership_id = p_membership_id
      and override_row.resource_need_id = candidate.resource_need_id
    where coalesce(
      override_row.is_included,
      baseline.resource_need_id is not null
    )
  ),
  ordered_contributions as (
    select
      'skill'::text as resolved_kind,
      effective.skill_id as resolved_id,
      skill.label as resolved_label,
      case
        when effective.is_baseline then 'final_commitment'::text
        else 'creator_added'::text
      end as resolved_source,
      0::smallint as kind_order,
      category.sort_order as category_order,
      skill.sort_order as item_order,
      null::timestamptz as resource_created_at
    from effective_skills as effective
    join public.skills as skill on skill.id = effective.skill_id
    join public.skill_categories as category on category.id = skill.category_id

    union all

    select
      'resource'::text,
      effective.resource_need_id,
      resource_need.title,
      case
        when effective.is_baseline then 'final_commitment'::text
        else 'creator_added'::text
      end,
      1::smallint,
      0::smallint,
      0::smallint,
      resource_need.created_at
    from effective_resources as effective
    join public.project_resource_needs as resource_need
      on resource_need.id = effective.resource_need_id

    union all

    select
      'substantial_effort'::text,
      null::uuid,
      null::text,
      'substantial_effort'::text,
      2::smallint,
      0::smallint,
      0::smallint,
      marker.marked_at
    from public.project_membership_actual_effort_markers as marker
    where marker.membership_id = p_membership_id
  )
  select
    contribution.resolved_kind,
    contribution.resolved_id,
    contribution.resolved_label,
    contribution.resolved_source
  from ordered_contributions as contribution
  order by
    contribution.kind_order,
    contribution.category_order,
    contribution.item_order,
    contribution.resource_created_at,
    contribution.resolved_id;
end;
$$;

create function public.list_project_membership_actual_contribution_options(
  p_expected_creator_profile_id uuid,
  p_membership_id uuid
)
returns table (
  option_kind text,
  option_id uuid,
  label text
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
  membership_record public.project_memberships%rowtype;
  registry public.projects%rowtype;
  proposal_record public.proposals%rowtype;
  baseline_eligible boolean;
begin
  select * into membership_record
  from public.project_memberships as membership
  where membership.id = p_membership_id;

  if not found then
    raise exception using
      errcode = '42501',
      message = 'The actual-contribution options are unavailable.';
  end if;

  select * into registry
  from public.projects as project
  where project.id = membership_record.project_id;

  if not found or registry.creator_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'The actual-contribution options are unavailable.';
  end if;

  if registry.project_kind <> 'one_time' then
    raise exception using
      errcode = '55000',
      message = 'Actual contributions are available only for ended one-time Proposals.';
  end if;

  select * into proposal_record
  from public.proposals as proposal
  where proposal.id = registry.id;

  if not found or proposal_record.creator_profile_id <> registry.creator_profile_id then
    raise exception using
      errcode = '55000',
      message = 'The project registry is inconsistent with its concrete activity.';
  end if;

  if proposal_record.lifecycle_state <> 'published'
    or proposal_record.ends_at is null
    or statement_timestamp() < proposal_record.ends_at then
    raise exception using
      errcode = '55000',
      message = 'Actual contributions are available only for ended published one-time Proposals.';
  end if;

  baseline_eligible :=
    membership_record.joined_at <= proposal_record.ends_at
    and (
      coalesce(membership_record.left_at, membership_record.removed_at) is null
      or proposal_record.ends_at < coalesce(
        membership_record.left_at,
        membership_record.removed_at
      )
    );

  return query
  with available_skills as (
    select proposal_skill.skill_id
    from public.proposal_skills as proposal_skill
    where proposal_skill.proposal_id = membership_record.project_id

    union

    select commitment.skill_id
    from public.project_membership_skill_commitments as commitment
    where baseline_eligible
      and commitment.membership_id = p_membership_id
  ),
  ordered_options as (
    select
      'skill'::text as resolved_kind,
      available.skill_id as resolved_id,
      skill.label as resolved_label,
      0::smallint as kind_order,
      category.sort_order as category_order,
      skill.sort_order as item_order,
      null::timestamptz as resource_created_at
    from available_skills as available
    join public.skills as skill on skill.id = available.skill_id
    join public.skill_categories as category on category.id = skill.category_id

    union all

    select
      'resource'::text,
      resource_need.id,
      resource_need.title,
      1::smallint,
      0::smallint,
      0::smallint,
      resource_need.created_at
    from public.project_resource_needs as resource_need
    where resource_need.project_id = membership_record.project_id
  )
  select
    option_row.resolved_kind,
    option_row.resolved_id,
    option_row.resolved_label
  from ordered_options as option_row
  order by
    option_row.kind_order,
    option_row.category_order,
    option_row.item_order,
    option_row.resource_created_at,
    option_row.resolved_id;
end;
$$;

create function public.replace_project_membership_actual_contributions(
  p_expected_creator_profile_id uuid,
  p_membership_id uuid,
  p_expected_skill_ids uuid[],
  p_expected_resource_need_ids uuid[],
  p_expected_substantial_effort boolean,
  p_skill_ids uuid[],
  p_resource_need_ids uuid[],
  p_substantial_effort boolean
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_participation_identity(
    p_expected_creator_profile_id
  );
  normalized_expected_skill_ids uuid[] := coalesce(
    p_expected_skill_ids,
    '{}'::uuid[]
  );
  normalized_expected_resource_need_ids uuid[] := coalesce(
    p_expected_resource_need_ids,
    '{}'::uuid[]
  );
  normalized_skill_ids uuid[] := coalesce(p_skill_ids, '{}'::uuid[]);
  normalized_resource_need_ids uuid[] := coalesce(
    p_resource_need_ids,
    '{}'::uuid[]
  );
  membership_record public.project_memberships%rowtype;
  project_record record;
  baseline_eligible boolean;
  baseline_skill_ids uuid[] := '{}'::uuid[];
  baseline_resource_need_ids uuid[] := '{}'::uuid[];
  current_skill_ids uuid[] := '{}'::uuid[];
  current_resource_need_ids uuid[] := '{}'::uuid[];
  current_substantial_effort boolean;
  locked_resource_need record;
  locked_resource_need_count integer := 0;
  mutation_time timestamptz := statement_timestamp();
begin
  if cardinality(normalized_expected_skill_ids) > 50
    or cardinality(normalized_expected_resource_need_ids) > 50 then
    raise exception using
      errcode = '22023',
      message = 'An expected actual-contribution snapshot may contain at most 50 skills and 50 resources.';
  end if;

  if p_expected_substantial_effort is null then
    raise exception using
      errcode = '22023',
      message = 'Expected Substantial Effort / Energy state is required.';
  end if;

  if exists (
    select 1
    from unnest(normalized_expected_skill_ids) as expected(skill_id)
    where expected.skill_id is null
  ) or exists (
    select 1
    from unnest(normalized_expected_resource_need_ids)
      as expected(resource_need_id)
    where expected.resource_need_id is null
  ) then
    raise exception using
      errcode = '22023',
      message = 'Expected actual-contribution identifiers cannot be null.';
  end if;

  if cardinality(normalized_expected_skill_ids) <> (
    select count(distinct expected.skill_id)
    from unnest(normalized_expected_skill_ids) as expected(skill_id)
  ) or cardinality(normalized_expected_resource_need_ids) <> (
    select count(distinct expected.resource_need_id)
    from unnest(normalized_expected_resource_need_ids)
      as expected(resource_need_id)
  ) then
    raise exception using
      errcode = '22023',
      message = 'Expected actual-contribution identifiers cannot contain duplicates.';
  end if;

  select coalesce(array_agg(expected.skill_id order by expected.skill_id), '{}')
  into normalized_expected_skill_ids
  from unnest(normalized_expected_skill_ids) as expected(skill_id);

  select coalesce(
    array_agg(expected.resource_need_id order by expected.resource_need_id),
    '{}'
  )
  into normalized_expected_resource_need_ids
  from unnest(normalized_expected_resource_need_ids)
    as expected(resource_need_id);

  select * into membership_record
  from public.project_memberships as membership
  where membership.id = p_membership_id;

  if not found then
    raise exception using errcode = 'P0002', message = 'The membership does not exist.';
  end if;

  select * into project_record
  from private.lock_project_for_actual_contribution_mutation(
    membership_record.project_id
  );

  select * into membership_record
  from public.project_memberships as membership
  where membership.id = p_membership_id
  for update;

  if project_record.creator_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'Only the Project creator can manage actual contributions.';
  end if;

  baseline_eligible :=
    membership_record.joined_at <= project_record.project_ends_at
    and (
      coalesce(membership_record.left_at, membership_record.removed_at) is null
      or project_record.project_ends_at < coalesce(
        membership_record.left_at,
        membership_record.removed_at
      )
    );

  if baseline_eligible then
    select coalesce(array_agg(commitment.skill_id order by commitment.skill_id), '{}')
    into baseline_skill_ids
    from public.project_membership_skill_commitments as commitment
    where commitment.membership_id = p_membership_id;

    select coalesce(
      array_agg(commitment.resource_need_id order by commitment.resource_need_id),
      '{}'
    )
    into baseline_resource_need_ids
    from public.project_membership_resource_commitments as commitment
    where commitment.membership_id = p_membership_id;
  end if;

  with candidates as (
    select baseline.skill_id
    from unnest(baseline_skill_ids) as baseline(skill_id)
    union
    select override_row.skill_id
    from public.project_membership_actual_skill_overrides as override_row
    where override_row.membership_id = p_membership_id
  )
  select coalesce(array_agg(candidate.skill_id order by candidate.skill_id), '{}')
  into current_skill_ids
  from candidates as candidate
  left join public.project_membership_actual_skill_overrides as override_row
    on override_row.membership_id = p_membership_id
    and override_row.skill_id = candidate.skill_id
  where coalesce(
    override_row.is_included,
    candidate.skill_id = any(baseline_skill_ids)
  );

  with candidates as (
    select baseline.resource_need_id
    from unnest(baseline_resource_need_ids) as baseline(resource_need_id)
    union
    select override_row.resource_need_id
    from public.project_membership_actual_resource_overrides as override_row
    where override_row.membership_id = p_membership_id
  )
  select coalesce(
    array_agg(candidate.resource_need_id order by candidate.resource_need_id),
    '{}'
  )
  into current_resource_need_ids
  from candidates as candidate
  left join public.project_membership_actual_resource_overrides as override_row
    on override_row.membership_id = p_membership_id
    and override_row.resource_need_id = candidate.resource_need_id
  where coalesce(
    override_row.is_included,
    candidate.resource_need_id = any(baseline_resource_need_ids)
  );

  select exists (
    select 1
    from public.project_membership_actual_effort_markers as marker
    where marker.membership_id = p_membership_id
  ) into current_substantial_effort;

  if current_skill_ids <> normalized_expected_skill_ids
    or current_resource_need_ids <> normalized_expected_resource_need_ids
    or current_substantial_effort is distinct from p_expected_substantial_effort then
    raise exception using
      errcode = '40001',
      message = 'Actual contributions changed since they were loaded.';
  end if;

  if cardinality(normalized_skill_ids) > 50
    or cardinality(normalized_resource_need_ids) > 50 then
    raise exception using
      errcode = '22023',
      message = 'Actual contributions may contain at most 50 skills and 50 resources.';
  end if;

  if p_substantial_effort is null then
    raise exception using
      errcode = '22023',
      message = 'Substantial Effort / Energy state is required.';
  end if;

  if exists (
    select 1
    from unnest(normalized_skill_ids) as desired(skill_id)
    where desired.skill_id is null
  ) or exists (
    select 1
    from unnest(normalized_resource_need_ids) as desired(resource_need_id)
    where desired.resource_need_id is null
  ) then
    raise exception using
      errcode = '22023',
      message = 'Actual-contribution identifiers cannot be null.';
  end if;

  if cardinality(normalized_skill_ids) <> (
    select count(distinct desired.skill_id)
    from unnest(normalized_skill_ids) as desired(skill_id)
  ) or cardinality(normalized_resource_need_ids) <> (
    select count(distinct desired.resource_need_id)
    from unnest(normalized_resource_need_ids) as desired(resource_need_id)
  ) then
    raise exception using
      errcode = '22023',
      message = 'Actual-contribution identifiers cannot contain duplicates.';
  end if;

  select coalesce(array_agg(desired.skill_id order by desired.skill_id), '{}')
  into normalized_skill_ids
  from unnest(normalized_skill_ids) as desired(skill_id);

  select coalesce(
    array_agg(desired.resource_need_id order by desired.resource_need_id),
    '{}'
  )
  into normalized_resource_need_ids
  from unnest(normalized_resource_need_ids) as desired(resource_need_id);

  if exists (
    select 1
    from unnest(normalized_skill_ids) as desired(skill_id)
    where not (desired.skill_id = any(baseline_skill_ids))
      and not exists (
        select 1
        from public.proposal_skills as proposal_skill
        where proposal_skill.proposal_id = membership_record.project_id
          and proposal_skill.skill_id = desired.skill_id
      )
  ) then
    raise exception using
      errcode = '22023',
      message = 'Every added actual skill must be a final Proposal skill or automatic-baseline skill.';
  end if;

  for locked_resource_need in
    select resource_need.id, resource_need.project_id
    from public.project_resource_needs as resource_need
    where resource_need.id = any(normalized_resource_need_ids)
    order by resource_need.id
    for share of resource_need
  loop
    locked_resource_need_count := locked_resource_need_count + 1;
    if locked_resource_need.project_id <> membership_record.project_id then
      raise exception using
        errcode = '22023',
        message = 'Every actual resource must belong to this Project.';
    end if;
  end loop;

  if locked_resource_need_count <> cardinality(normalized_resource_need_ids) then
    raise exception using
      errcode = '22023',
      message = 'Every actual resource must belong to this Project.';
  end if;

  if current_skill_ids = normalized_skill_ids
    and current_resource_need_ids = normalized_resource_need_ids
    and current_substantial_effort = p_substantial_effort then
    return membership_record.id;
  end if;

  delete from public.project_membership_actual_skill_overrides as override_row
  where override_row.membership_id = p_membership_id
    and (
      override_row.skill_id = any(baseline_skill_ids)
    ) = (
      override_row.skill_id = any(normalized_skill_ids)
    );

  insert into public.project_membership_actual_skill_overrides (
    membership_id,
    skill_id,
    is_included,
    updated_at,
    updated_by_profile_id
  )
  select
    p_membership_id,
    candidate.skill_id,
    candidate.skill_id = any(normalized_skill_ids),
    mutation_time,
    current_profile_id
  from (
    select baseline.skill_id
    from unnest(baseline_skill_ids) as baseline(skill_id)
    union
    select desired.skill_id
    from unnest(normalized_skill_ids) as desired(skill_id)
  ) as candidate
  where (candidate.skill_id = any(baseline_skill_ids)) <>
    (candidate.skill_id = any(normalized_skill_ids))
  on conflict (membership_id, skill_id) do update
  set
    is_included = excluded.is_included,
    updated_at = excluded.updated_at,
    updated_by_profile_id = excluded.updated_by_profile_id
  where project_membership_actual_skill_overrides.is_included
    is distinct from excluded.is_included;

  delete from public.project_membership_actual_resource_overrides
    as override_row
  where override_row.membership_id = p_membership_id
    and (
      override_row.resource_need_id = any(baseline_resource_need_ids)
    ) = (
      override_row.resource_need_id = any(normalized_resource_need_ids)
    );

  insert into public.project_membership_actual_resource_overrides (
    membership_id,
    resource_need_id,
    is_included,
    updated_at,
    updated_by_profile_id
  )
  select
    p_membership_id,
    candidate.resource_need_id,
    candidate.resource_need_id = any(normalized_resource_need_ids),
    mutation_time,
    current_profile_id
  from (
    select baseline.resource_need_id
    from unnest(baseline_resource_need_ids) as baseline(resource_need_id)
    union
    select desired.resource_need_id
    from unnest(normalized_resource_need_ids) as desired(resource_need_id)
  ) as candidate
  where (candidate.resource_need_id = any(baseline_resource_need_ids)) <>
    (candidate.resource_need_id = any(normalized_resource_need_ids))
  on conflict (membership_id, resource_need_id) do update
  set
    is_included = excluded.is_included,
    updated_at = excluded.updated_at,
    updated_by_profile_id = excluded.updated_by_profile_id
  where project_membership_actual_resource_overrides.is_included
    is distinct from excluded.is_included;

  if p_substantial_effort then
    insert into public.project_membership_actual_effort_markers (
      membership_id,
      marked_at,
      marked_by_profile_id
    )
    values (p_membership_id, mutation_time, current_profile_id)
    on conflict (membership_id) do nothing;
  else
    delete from public.project_membership_actual_effort_markers as marker
    where marker.membership_id = p_membership_id;
  end if;

  perform private.record_project_actual_contributions_updated_event(
    current_profile_id,
    membership_record.project_id,
    membership_record.id,
    membership_record.participant_profile_id
  );

  return membership_record.id;
end;
$$;

revoke all privileges on function
  private.lock_project_for_actual_contribution_mutation(uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function
  private.record_project_actual_contributions_updated_event(
    uuid,
    uuid,
    uuid,
    uuid
  )
  from public, anon, authenticated, service_role;
revoke all privileges on function
  public.list_project_membership_actual_contributions(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function
  public.list_project_membership_actual_contribution_options(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function
  public.replace_project_membership_actual_contributions(
    uuid,
    uuid,
    uuid[],
    uuid[],
    boolean,
    uuid[],
    uuid[],
    boolean
  )
  from public, anon, authenticated, service_role;

grant execute on function
  public.list_project_membership_actual_contributions(uuid, uuid)
  to authenticated;
grant execute on function
  public.list_project_membership_actual_contribution_options(uuid, uuid)
  to authenticated;
grant execute on function
  public.replace_project_membership_actual_contributions(
    uuid,
    uuid,
    uuid[],
    uuid[],
    boolean,
    uuid[],
    uuid[],
    boolean
  )
  to authenticated;

comment on function
  private.lock_project_for_actual_contribution_mutation(uuid)
is
  'Locks one ended published concrete Proposal and then its shared Project row before the caller locks a membership episode and desired resource rows.';
comment on function
  private.record_project_actual_contributions_updated_event(
    uuid,
    uuid,
    uuid,
    uuid
  )
is
  'Emits exactly one identifier-only audit/outbox event for a real creator actual-contribution correction.';
comment on function
  public.list_project_membership_actual_contributions(uuid, uuid)
is
  'Returns effective actual skills, resources, and built-in effort for one ended one-time Project membership to its participant or creator.';
comment on function
  public.list_project_membership_actual_contribution_options(uuid, uuid)
is
  'Returns creator-only final Proposal skills plus automatic-baseline stale skills and every same-Project resource need for post-end correction.';
comment on function
  public.replace_project_membership_actual_contributions(
    uuid,
    uuid,
    uuid[],
    uuid[],
    boolean,
    uuid[],
    uuid[],
    boolean
  )
is
  'Creator-only compare-and-swap replacement of effective actual contribution truth, normalized to sparse overrides and one optional effort marker.';
