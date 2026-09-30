-- Application conflicts use PostgREST's explicit HTTP 409 SQLSTATE. SQLSTATE
-- 40001 remains reserved for genuine PostgreSQL serialization failures.

create or replace function public.replace_project_membership_commitments(
  p_expected_actor_profile_id uuid,
  p_membership_id uuid,
  p_expected_skill_ids uuid[],
  p_expected_resource_need_ids uuid[],
  p_skill_ids uuid[],
  p_resource_need_ids uuid[]
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_participation_identity(
    p_expected_actor_profile_id
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
  locked_resource_need record;
  expected_new_resource_count integer;
  locked_resource_need_count integer := 0;
  skill_set_changed boolean;
  resource_set_changed boolean;
begin
  if cardinality(normalized_expected_skill_ids) > 50 then
    raise exception using
      errcode = '22023',
      message = 'An expected membership snapshot may contain at most 50 Project skills.';
  end if;

  if cardinality(normalized_expected_resource_need_ids) > 50 then
    raise exception using
      errcode = '22023',
      message = 'An expected membership snapshot may contain at most 50 Project resource needs.';
  end if;

  if exists (
    select 1
    from unnest(normalized_expected_skill_ids) as expected(skill_id)
    where expected.skill_id is null
  ) then
    raise exception using
      errcode = '22023',
      message = 'Expected Project skill commitments cannot contain null identifiers.';
  end if;

  if exists (
    select 1
    from unnest(normalized_expected_resource_need_ids) as expected(resource_need_id)
    where expected.resource_need_id is null
  ) then
    raise exception using
      errcode = '22023',
      message = 'Expected Project resource commitments cannot contain null identifiers.';
  end if;

  if cardinality(normalized_expected_skill_ids) <> (
    select count(distinct expected.skill_id)
    from unnest(normalized_expected_skill_ids) as expected(skill_id)
  ) then
    raise exception using
      errcode = '22023',
      message = 'Expected Project skill commitments cannot contain duplicate identifiers.';
  end if;

  if cardinality(normalized_expected_resource_need_ids) <> (
    select count(distinct expected.resource_need_id)
    from unnest(normalized_expected_resource_need_ids)
      as expected(resource_need_id)
  ) then
    raise exception using
      errcode = '22023',
      message = 'Expected Project resource commitments cannot contain duplicate identifiers.';
  end if;

  select * into membership_record
  from public.project_memberships as membership
  where membership.id = p_membership_id;

  if not found then
    raise exception using errcode = 'P0002', message = 'The membership does not exist.';
  end if;

  select * into project_record
  from private.lock_project_for_membership_commitment_mutation(
    membership_record.project_id
  );

  select * into membership_record
  from public.project_memberships as membership
  where membership.id = p_membership_id
  for update;

  if membership_record.participant_profile_id <> current_profile_id
    and project_record.creator_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'Only the participant or Project creator can manage this membership commitment set.';
  end if;

  if membership_record.left_at is not null
    or membership_record.removed_at is not null then
    raise exception using
      errcode = '55000',
      message = 'Only a current membership can change its commitments.';
  end if;

  if exists (
    select commitment.skill_id
    from public.project_membership_skill_commitments as commitment
    where commitment.membership_id = p_membership_id
    except
    select expected.skill_id
    from unnest(normalized_expected_skill_ids) as expected(skill_id)
  ) or exists (
    select expected.skill_id
    from unnest(normalized_expected_skill_ids) as expected(skill_id)
    except
    select commitment.skill_id
    from public.project_membership_skill_commitments as commitment
    where commitment.membership_id = p_membership_id
  ) or exists (
    select commitment.resource_need_id
    from public.project_membership_resource_commitments as commitment
    where commitment.membership_id = p_membership_id
    except
    select expected.resource_need_id
    from unnest(normalized_expected_resource_need_ids)
      as expected(resource_need_id)
  ) or exists (
    select expected.resource_need_id
    from unnest(normalized_expected_resource_need_ids)
      as expected(resource_need_id)
    except
    select commitment.resource_need_id
    from public.project_membership_resource_commitments as commitment
    where commitment.membership_id = p_membership_id
  ) then
    raise sqlstate 'PT409'
      using message = 'Membership commitments changed since they were loaded.';
  end if;

  if cardinality(normalized_skill_ids) > 50 then
    raise exception using
      errcode = '22023',
      message = 'A membership may commit to at most 50 Project skills.';
  end if;

  if cardinality(normalized_resource_need_ids) > 50 then
    raise exception using
      errcode = '22023',
      message = 'A membership may commit to at most 50 Project resource needs.';
  end if;

  if exists (
    select 1
    from unnest(normalized_skill_ids) as desired(skill_id)
    where desired.skill_id is null
  ) then
    raise exception using
      errcode = '22023',
      message = 'Project skill commitments cannot contain null identifiers.';
  end if;

  if exists (
    select 1
    from unnest(normalized_resource_need_ids) as desired(resource_need_id)
    where desired.resource_need_id is null
  ) then
    raise exception using
      errcode = '22023',
      message = 'Project resource commitments cannot contain null identifiers.';
  end if;

  if cardinality(normalized_skill_ids) <> (
    select count(distinct desired.skill_id)
    from unnest(normalized_skill_ids) as desired(skill_id)
  ) then
    raise exception using
      errcode = '22023',
      message = 'Project skill commitments cannot contain duplicate identifiers.';
  end if;

  if cardinality(normalized_resource_need_ids) <> (
    select count(distinct desired.resource_need_id)
    from unnest(normalized_resource_need_ids) as desired(resource_need_id)
  ) then
    raise exception using
      errcode = '22023',
      message = 'Project resource commitments cannot contain duplicate identifiers.';
  end if;

  select exists (
    select commitment.skill_id
    from public.project_membership_skill_commitments as commitment
    where commitment.membership_id = p_membership_id
    except
    select desired.skill_id
    from unnest(normalized_skill_ids) as desired(skill_id)
  ) or exists (
    select desired.skill_id
    from unnest(normalized_skill_ids) as desired(skill_id)
    except
    select commitment.skill_id
    from public.project_membership_skill_commitments as commitment
    where commitment.membership_id = p_membership_id
  ) into skill_set_changed;

  select exists (
    select commitment.resource_need_id
    from public.project_membership_resource_commitments as commitment
    where commitment.membership_id = p_membership_id
    except
    select desired.resource_need_id
    from unnest(normalized_resource_need_ids) as desired(resource_need_id)
  ) or exists (
    select desired.resource_need_id
    from unnest(normalized_resource_need_ids) as desired(resource_need_id)
    except
    select commitment.resource_need_id
    from public.project_membership_resource_commitments as commitment
    where commitment.membership_id = p_membership_id
  ) into resource_set_changed;

  if project_record.project_kind = 'recurring'
    and exists (
      select 1
      from unnest(normalized_skill_ids) as desired(skill_id)
      where not exists (
        select 1
        from public.project_membership_skill_commitments as commitment
        where commitment.membership_id = p_membership_id
          and commitment.skill_id = desired.skill_id
      )
    ) then
    raise exception using
      errcode = '22023',
      message = 'Recurring Projects do not currently define new skill commitments.';
  end if;

  if project_record.project_kind = 'one_time'
    and exists (
      select 1
      from unnest(normalized_skill_ids) as desired(skill_id)
      where not exists (
        select 1
        from public.project_membership_skill_commitments as commitment
        where commitment.membership_id = p_membership_id
          and commitment.skill_id = desired.skill_id
      )
        and not exists (
          select 1
          from public.proposal_skills as required_skill
          where required_skill.proposal_id = membership_record.project_id
            and required_skill.skill_id = desired.skill_id
        )
    ) then
    raise exception using
      errcode = '22023',
      message = 'Every new skill commitment must be a current requirement of this Proposal.';
  end if;

  select count(*) into expected_new_resource_count
  from unnest(normalized_resource_need_ids) as desired(resource_need_id)
  where not exists (
    select 1
    from public.project_membership_resource_commitments as commitment
    where commitment.membership_id = p_membership_id
      and commitment.resource_need_id = desired.resource_need_id
  );

  for locked_resource_need in
    select need.id, need.project_id, need.state
    from public.project_resource_needs as need
    where need.id = any(normalized_resource_need_ids)
      and not exists (
        select 1
        from public.project_membership_resource_commitments as commitment
        where commitment.membership_id = p_membership_id
          and commitment.resource_need_id = need.id
      )
    order by need.id
    for share of need
  loop
    locked_resource_need_count := locked_resource_need_count + 1;

    if locked_resource_need.project_id <> membership_record.project_id
      or locked_resource_need.state <> 'open' then
      raise exception using
        errcode = '22023',
        message = 'Every new resource commitment must be open and belong to this Project.';
    end if;
  end loop;

  if locked_resource_need_count <> expected_new_resource_count then
    raise exception using
      errcode = '22023',
      message = 'Every new resource commitment must be open and belong to this Project.';
  end if;

  if not skill_set_changed and not resource_set_changed then
    return membership_record.id;
  end if;

  delete from public.project_membership_skill_commitments as commitment
  where commitment.membership_id = p_membership_id
    and not (commitment.skill_id = any(normalized_skill_ids));

  insert into public.project_membership_skill_commitments (
    membership_id,
    skill_id
  )
  select p_membership_id, desired.skill_id
  from unnest(normalized_skill_ids) as desired(skill_id)
  on conflict (membership_id, skill_id) do nothing;

  delete from public.project_membership_resource_commitments as commitment
  where commitment.membership_id = p_membership_id
    and not (
      commitment.resource_need_id = any(normalized_resource_need_ids)
    );

  insert into public.project_membership_resource_commitments (
    membership_id,
    resource_need_id
  )
  select p_membership_id, desired.resource_need_id
  from unnest(normalized_resource_need_ids) as desired(resource_need_id)
  on conflict (membership_id, resource_need_id) do nothing;

  perform private.record_project_membership_commitment_event(
    current_profile_id,
    membership_record.project_id,
    project_record.project_kind,
    membership_record.id,
    membership_record.participant_profile_id
  );

  return membership_record.id;
end;
$$;

create or replace function public.replace_project_membership_actual_contributions(
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
    raise sqlstate 'PT409'
      using message = 'Actual contributions changed since they were loaded.';
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

create or replace function public.claim_project_requirement(
  p_expected_participant_profile_id uuid,
  p_project_id uuid,
  p_requirement_kind text,
  p_requirement_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_participation_identity(
    p_expected_participant_profile_id
  );
  normalized_requirement_kind text := lower(btrim(p_requirement_kind));
  membership_record public.project_memberships%rowtype;
  project_record record;
  resource_need public.project_resource_needs%rowtype;
  commitment_created boolean := false;
begin
  if normalized_requirement_kind is null
    or normalized_requirement_kind not in ('skill', 'resource')
    or p_requirement_id is null then
    raise exception using
      errcode = '22023',
      message = 'A live requirement claim must identify one skill or resource.';
  end if;

  select * into membership_record
  from public.project_memberships as membership
  where membership.project_id = p_project_id
    and membership.participant_profile_id = current_profile_id
    and membership.left_at is null
    and membership.removed_at is null;

  if not found then
    raise exception using
      errcode = '42501',
      message = 'Only a current accepted participant can claim a Project requirement.';
  end if;

  select * into project_record
  from private.lock_project_for_live_requirement_coverage(p_project_id, true);

  select * into membership_record
  from public.project_memberships as membership
  where membership.id = membership_record.id
  for update;

  if membership_record.left_at is not null
    or membership_record.removed_at is not null
    or membership_record.participant_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'Only a current accepted participant can claim a Project requirement.';
  end if;

  if normalized_requirement_kind = 'skill' then
    if project_record.project_kind <> 'one_time' then
      raise exception using
        errcode = '22023',
        message = 'Recurring Projects do not define skill requirements.';
    end if;

    if not exists (
      select 1
      from public.proposal_skills as proposal_skill
      where proposal_skill.proposal_id = p_project_id
        and proposal_skill.skill_id = p_requirement_id
    ) then
      raise exception using
        errcode = '22023',
        message = 'The skill is not a current requirement of this Proposal.';
    end if;
  else
    select * into resource_need
    from public.project_resource_needs as need
    where need.id = p_requirement_id
    for share;

    if not found
      or resource_need.project_id <> p_project_id
      or resource_need.state <> 'open' then
      raise exception using
        errcode = '22023',
        message = 'The resource is not an open requirement of this Project.';
    end if;
  end if;

  if private.project_requirement_live_source_count(
    p_project_id,
    normalized_requirement_kind,
    p_requirement_id
  ) > 0 then
    raise sqlstate 'PT409'
      using message = 'The Project requirement is already covered.';
  end if;

  if normalized_requirement_kind = 'skill' then
    if not exists (
      select 1
      from public.project_membership_skill_commitments as commitment
      where commitment.membership_id = membership_record.id
        and commitment.skill_id = p_requirement_id
    ) then
      if (
        select count(*)
        from public.project_membership_skill_commitments as commitment
        where commitment.membership_id = membership_record.id
      ) >= 50 then
        raise exception using
          errcode = '22023',
          message = 'A membership may commit to at most 50 Project skills.';
      end if;

      insert into public.project_membership_skill_commitments (
        membership_id,
        skill_id
      )
      values (membership_record.id, p_requirement_id);

      commitment_created := true;
    end if;

    insert into public.project_membership_skill_coverages (
      membership_id,
      skill_id
    )
    values (membership_record.id, p_requirement_id);
  else
    if not exists (
      select 1
      from public.project_membership_resource_commitments as commitment
      where commitment.membership_id = membership_record.id
        and commitment.resource_need_id = p_requirement_id
    ) then
      if (
        select count(*)
        from public.project_membership_resource_commitments as commitment
        where commitment.membership_id = membership_record.id
      ) >= 50 then
        raise exception using
          errcode = '22023',
          message = 'A membership may commit to at most 50 Project resource needs.';
      end if;

      insert into public.project_membership_resource_commitments (
        membership_id,
        resource_need_id
      )
      values (membership_record.id, p_requirement_id);

      commitment_created := true;
    end if;

    insert into public.project_membership_resource_coverages (
      membership_id,
      resource_need_id
    )
    values (membership_record.id, p_requirement_id);
  end if;

  if commitment_created then
    perform private.record_project_membership_commitment_event(
      current_profile_id,
      p_project_id,
      project_record.project_kind,
      membership_record.id,
      membership_record.participant_profile_id
    );
  end if;

  perform private.record_project_requirement_coverage_event(
    'project.requirement_covered',
    current_profile_id,
    p_project_id,
    project_record.project_kind,
    normalized_requirement_kind,
    p_requirement_id,
    membership_record.id
  );

  return membership_record.id;
end;
$$;
