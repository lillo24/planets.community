create table public.project_membership_skill_coverages (
  membership_id uuid not null,
  skill_id uuid not null,
  covered_at timestamptz not null default now(),
  constraint project_membership_skill_coverages_pkey
    primary key (membership_id, skill_id),
  constraint project_membership_skill_coverages_commitment_fkey
    foreign key (membership_id, skill_id)
      references public.project_membership_skill_commitments (
        membership_id,
        skill_id
      )
      on delete restrict
);

comment on table public.project_membership_skill_coverages is
  'Current participant-supplied live coverage for Proposal skill requirements; coverage implies, but is distinct from, a membership commitment.';

create index project_membership_skill_coverages_skill_membership_idx
  on public.project_membership_skill_coverages (skill_id, membership_id);

create table public.project_membership_resource_coverages (
  membership_id uuid not null,
  resource_need_id uuid not null,
  covered_at timestamptz not null default now(),
  constraint project_membership_resource_coverages_pkey
    primary key (membership_id, resource_need_id),
  constraint project_membership_resource_coverages_commitment_fkey
    foreign key (membership_id, resource_need_id)
      references public.project_membership_resource_commitments (
        membership_id,
        resource_need_id
      )
      on delete restrict
);

comment on table public.project_membership_resource_coverages is
  'Current participant-supplied live coverage for open Project resource needs; coverage implies, but is distinct from, a membership commitment.';

create index project_membership_resource_coverages_need_membership_idx
  on public.project_membership_resource_coverages (
    resource_need_id,
    membership_id
  );

create table public.project_manual_skill_coverages (
  project_id uuid not null
    constraint project_manual_skill_coverages_project_id_fkey
      references public.projects (id) on delete restrict,
  skill_id uuid not null
    constraint project_manual_skill_coverages_skill_id_fkey
      references public.skills (id) on delete restrict,
  marked_at timestamptz not null default now(),
  marked_by_profile_id uuid not null
    constraint project_manual_skill_coverages_marked_by_fkey
      references public.profiles (id) on delete restrict,
  originating_request_id uuid
    constraint project_manual_skill_coverages_request_id_fkey
      references public.project_join_requests (id) on delete restrict,
  constraint project_manual_skill_coverages_pkey
    primary key (project_id, skill_id)
);

comment on table public.project_manual_skill_coverages is
  'Creator-recorded external coverage for a current Proposal skill requirement, optionally originating from an accepted already_found decision.';

create index project_manual_skill_coverages_marked_by_idx
  on public.project_manual_skill_coverages (marked_by_profile_id);
create index project_manual_skill_coverages_request_idx
  on public.project_manual_skill_coverages (originating_request_id)
  where originating_request_id is not null;

create table public.project_manual_resource_coverages (
  resource_need_id uuid not null
    constraint project_manual_resource_coverages_need_id_fkey
      references public.project_resource_needs (id) on delete restrict,
  marked_at timestamptz not null default now(),
  marked_by_profile_id uuid not null
    constraint project_manual_resource_coverages_marked_by_fkey
      references public.profiles (id) on delete restrict,
  originating_request_id uuid
    constraint project_manual_resource_coverages_request_id_fkey
      references public.project_join_requests (id) on delete restrict,
  constraint project_manual_resource_coverages_pkey
    primary key (resource_need_id)
);

comment on table public.project_manual_resource_coverages is
  'Creator-recorded external coverage for an open Project resource need, optionally originating from an accepted already_found decision.';

create index project_manual_resource_coverages_marked_by_idx
  on public.project_manual_resource_coverages (marked_by_profile_id);
create index project_manual_resource_coverages_request_idx
  on public.project_manual_resource_coverages (originating_request_id)
  where originating_request_id is not null;

alter table public.project_membership_skill_coverages enable row level security;
alter table public.project_membership_resource_coverages enable row level security;
alter table public.project_manual_skill_coverages enable row level security;
alter table public.project_manual_resource_coverages enable row level security;

revoke all privileges on table public.project_membership_skill_coverages
  from public, anon, authenticated, service_role;
revoke all privileges on table public.project_membership_resource_coverages
  from public, anon, authenticated, service_role;
revoke all privileges on table public.project_manual_skill_coverages
  from public, anon, authenticated, service_role;
revoke all privileges on table public.project_manual_resource_coverages
  from public, anon, authenticated, service_role;

create function private.project_has_live_coverage_lifecycle(
  p_project_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case project.project_kind
    when 'one_time' then exists (
      select 1
      from public.proposals as proposal
      where proposal.id = project.id
        and proposal.lifecycle_state = 'published'
        and proposal.ends_at is not null
        and statement_timestamp() < proposal.ends_at
    )
    when 'recurring' then exists (
      select 1
      from public.recurring_activities as activity
      where activity.id = project.id
        and activity.lifecycle_state in ('published', 'paused')
    )
    else false
  end
  from public.projects as project
  where project.id = p_project_id
$$;

create function private.lock_project_for_live_requirement_coverage(
  p_project_id uuid,
  p_require_operational boolean default true
)
returns table (project_kind text, creator_profile_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
declare
  registry public.projects%rowtype;
  source_creator_profile_id uuid;
  source_is_operational boolean;
begin
  select * into registry
  from public.projects as project
  where project.id = p_project_id;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'The requested project does not exist.';
  end if;

  if registry.project_kind = 'one_time' then
    select
      proposal.creator_profile_id,
      proposal.lifecycle_state = 'published'
        and proposal.ends_at is not null
        and statement_timestamp() < proposal.ends_at
    into source_creator_profile_id, source_is_operational
    from public.proposals as proposal
    where proposal.id = registry.id
    for share;
  elsif registry.project_kind = 'recurring' then
    select
      activity.creator_profile_id,
      activity.lifecycle_state in ('published', 'paused')
    into source_creator_profile_id, source_is_operational
    from public.recurring_activities as activity
    where activity.id = registry.id
    for share;
  end if;

  if not found or source_creator_profile_id <> registry.creator_profile_id then
    raise exception using
      errcode = '55000',
      message = 'The project registry is inconsistent with its concrete activity.';
  end if;

  if p_require_operational and source_is_operational is not true then
    raise exception using
      errcode = '55000',
      message = 'Live requirement coverage is available only while the Project is operational.';
  end if;

  -- Preserve the established global order: concrete Proposal/Tavolo, shared
  -- Project, membership when applicable, then resource need when applicable.
  select * into registry
  from public.projects as project
  where project.id = p_project_id
  for update;

  return query select registry.project_kind, registry.creator_profile_id;
end;
$$;

create function private.project_requirement_is_current(
  p_project_id uuid,
  p_requirement_kind text,
  p_requirement_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case p_requirement_kind
    when 'skill' then exists (
      select 1
      from public.projects as project
      join public.proposal_skills as proposal_skill
        on proposal_skill.proposal_id = project.id
      where project.id = p_project_id
        and project.project_kind = 'one_time'
        and proposal_skill.skill_id = p_requirement_id
    )
    when 'resource' then exists (
      select 1
      from public.project_resource_needs as need
      where need.id = p_requirement_id
        and need.project_id = p_project_id
        and need.state = 'open'
    )
    else false
  end
$$;

create function private.project_requirement_live_source_count(
  p_project_id uuid,
  p_requirement_kind text,
  p_requirement_id uuid
)
returns bigint
language sql
stable
security definer
set search_path = ''
as $$
  select case p_requirement_kind
    when 'skill' then
      (
        select count(*)
        from public.project_membership_skill_coverages as coverage
        join public.project_memberships as membership
          on membership.id = coverage.membership_id
        where membership.project_id = p_project_id
          and membership.left_at is null
          and membership.removed_at is null
          and coverage.skill_id = p_requirement_id
      ) + (
        select count(*)
        from public.project_manual_skill_coverages as coverage
        where coverage.project_id = p_project_id
          and coverage.skill_id = p_requirement_id
      )
    when 'resource' then
      (
        select count(*)
        from public.project_membership_resource_coverages as coverage
        join public.project_memberships as membership
          on membership.id = coverage.membership_id
        where membership.project_id = p_project_id
          and membership.left_at is null
          and membership.removed_at is null
          and coverage.resource_need_id = p_requirement_id
      ) + (
        select count(*)
        from public.project_manual_resource_coverages as coverage
        join public.project_resource_needs as need
          on need.id = coverage.resource_need_id
        where need.project_id = p_project_id
          and coverage.resource_need_id = p_requirement_id
      )
    else 0::bigint
  end
$$;

create function private.record_project_requirement_coverage_event(
  p_event_type text,
  p_actor_profile_id uuid,
  p_project_id uuid,
  p_project_kind text,
  p_requirement_kind text,
  p_requirement_id uuid,
  p_membership_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  identifier_payload jsonb := jsonb_strip_nulls(jsonb_build_object(
    'project_id', p_project_id,
    'project_kind', p_project_kind,
    'requirement_kind', p_requirement_kind,
    'requirement_id', p_requirement_id,
    'actor_profile_id', p_actor_profile_id,
    'membership_id', p_membership_id
  ));
begin
  if p_event_type not in (
    'project.requirement_covered',
    'project.requirement_needed_again'
  ) then
    raise exception using
      errcode = '22023',
      message = 'Unsupported Project requirement coverage event type.';
  end if;

  insert into private.audit_events (
    action,
    actor_user_id,
    target_type,
    target_id,
    metadata
  )
  values (
    p_event_type,
    p_actor_profile_id,
    'project_requirement',
    p_requirement_id,
    identifier_payload
  );

  insert into private.outbox_events (event_type, payload)
  values (p_event_type, identifier_payload);
end;
$$;

create function private.release_removed_project_membership_coverages(
  p_membership_id uuid,
  p_actor_profile_id uuid,
  p_project_id uuid,
  p_project_kind text,
  p_retained_skill_ids uuid[],
  p_retained_resource_need_ids uuid[]
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  removed_requirement record;
begin
  for removed_requirement in
    delete from public.project_membership_skill_coverages as coverage
    where coverage.membership_id = p_membership_id
      and not (
        coverage.skill_id = any(coalesce(p_retained_skill_ids, '{}'::uuid[]))
      )
    returning coverage.skill_id as requirement_id
  loop
    if private.project_requirement_live_source_count(
      p_project_id,
      'skill',
      removed_requirement.requirement_id
    ) = 0
      and private.project_requirement_is_current(
        p_project_id,
        'skill',
        removed_requirement.requirement_id
      )
      and private.project_has_live_coverage_lifecycle(p_project_id) then
      perform private.record_project_requirement_coverage_event(
        'project.requirement_needed_again',
        p_actor_profile_id,
        p_project_id,
        p_project_kind,
        'skill',
        removed_requirement.requirement_id,
        p_membership_id
      );
    end if;
  end loop;

  for removed_requirement in
    delete from public.project_membership_resource_coverages as coverage
    where coverage.membership_id = p_membership_id
      and not (
        coverage.resource_need_id = any(
          coalesce(p_retained_resource_need_ids, '{}'::uuid[])
        )
      )
    returning coverage.resource_need_id as requirement_id
  loop
    if private.project_requirement_live_source_count(
      p_project_id,
      'resource',
      removed_requirement.requirement_id
    ) = 0
      and private.project_requirement_is_current(
        p_project_id,
        'resource',
        removed_requirement.requirement_id
      )
      and private.project_has_live_coverage_lifecycle(p_project_id) then
      perform private.record_project_requirement_coverage_event(
        'project.requirement_needed_again',
        p_actor_profile_id,
        p_project_id,
        p_project_kind,
        'resource',
        removed_requirement.requirement_id,
        p_membership_id
      );
    end if;
  end loop;
end;
$$;

create function private.release_coverage_before_skill_commitment_delete()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  membership_record public.project_memberships%rowtype;
  project_kind text;
  actor_profile_id uuid;
begin
  if not exists (
    select 1
    from public.project_membership_skill_coverages as coverage
    where coverage.membership_id = old.membership_id
      and coverage.skill_id = old.skill_id
  ) then
    return old;
  end if;

  select * into membership_record
  from public.project_memberships as membership
  where membership.id = old.membership_id;

  select project.project_kind into project_kind
  from public.projects as project
  where project.id = membership_record.project_id;

  actor_profile_id := coalesce(
    (select auth.uid()),
    membership_record.participant_profile_id
  );

  delete from public.project_membership_skill_coverages
  where membership_id = old.membership_id
    and skill_id = old.skill_id;

  if private.project_requirement_live_source_count(
    membership_record.project_id,
    'skill',
    old.skill_id
  ) = 0
    and private.project_requirement_is_current(
      membership_record.project_id,
      'skill',
      old.skill_id
    )
    and private.project_has_live_coverage_lifecycle(
      membership_record.project_id
    ) then
    perform private.record_project_requirement_coverage_event(
      'project.requirement_needed_again',
      actor_profile_id,
      membership_record.project_id,
      project_kind,
      'skill',
      old.skill_id,
      old.membership_id
    );
  end if;

  return old;
end;
$$;

create function private.release_coverage_before_resource_commitment_delete()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  membership_record public.project_memberships%rowtype;
  project_kind text;
  actor_profile_id uuid;
begin
  if not exists (
    select 1
    from public.project_membership_resource_coverages as coverage
    where coverage.membership_id = old.membership_id
      and coverage.resource_need_id = old.resource_need_id
  ) then
    return old;
  end if;

  select * into membership_record
  from public.project_memberships as membership
  where membership.id = old.membership_id;

  select project.project_kind into project_kind
  from public.projects as project
  where project.id = membership_record.project_id;

  actor_profile_id := coalesce(
    (select auth.uid()),
    membership_record.participant_profile_id
  );

  delete from public.project_membership_resource_coverages
  where membership_id = old.membership_id
    and resource_need_id = old.resource_need_id;

  if private.project_requirement_live_source_count(
    membership_record.project_id,
    'resource',
    old.resource_need_id
  ) = 0
    and private.project_requirement_is_current(
      membership_record.project_id,
      'resource',
      old.resource_need_id
    )
    and private.project_has_live_coverage_lifecycle(
      membership_record.project_id
    ) then
    perform private.record_project_requirement_coverage_event(
      'project.requirement_needed_again',
      actor_profile_id,
      membership_record.project_id,
      project_kind,
      'resource',
      old.resource_need_id,
      old.membership_id
    );
  end if;

  return old;
end;
$$;

create trigger project_membership_skill_commitments_release_coverage
before delete on public.project_membership_skill_commitments
for each row execute function
  private.release_coverage_before_skill_commitment_delete();

create trigger project_membership_resource_commitments_release_coverage
before delete on public.project_membership_resource_commitments
for each row execute function
  private.release_coverage_before_resource_commitment_delete();

create function private.release_ended_project_membership_coverage()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  project_kind text;
  actor_profile_id uuid;
begin
  if (old.left_at is not null or old.removed_at is not null)
    or (new.left_at is null and new.removed_at is null) then
    return new;
  end if;

  select project.project_kind into project_kind
  from public.projects as project
  where project.id = old.project_id;

  actor_profile_id := coalesce(
    new.removed_by_profile_id,
    (select auth.uid()),
    old.participant_profile_id
  );

  perform private.release_removed_project_membership_coverages(
    old.id,
    actor_profile_id,
    old.project_id,
    project_kind,
    '{}'::uuid[],
    '{}'::uuid[]
  );

  return new;
end;
$$;

create trigger project_memberships_release_ended_coverage
before update of left_at, removed_at on public.project_memberships
for each row execute function
  private.release_ended_project_membership_coverage();

create function private.lock_project_before_proposal_skill_delete()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Canonical Proposal replacement already holds the concrete Proposal row;
  -- take the shared Project anchor before any coverage source can disappear.
  perform 1
  from public.projects as project
  where project.id = old.proposal_id
  for update;

  return old;
end;
$$;

create trigger proposal_skills_lock_project_before_coverage_cleanup
before delete on public.proposal_skills
for each row execute function
  private.lock_project_before_proposal_skill_delete();

create function private.clear_removed_proposal_skill_coverage()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Deferred execution distinguishes a true removal from the canonical
  -- delete/reinsert replacement of a skill that remains selected.
  if exists (
    select 1
    from public.proposal_skills as current_skill
    where current_skill.proposal_id = old.proposal_id
      and current_skill.skill_id = old.skill_id
  ) then
    return old;
  end if;

  delete from public.project_membership_skill_coverages as coverage
  using public.project_memberships as membership
  where membership.id = coverage.membership_id
    and membership.project_id = old.proposal_id
    and coverage.skill_id = old.skill_id;

  delete from public.project_manual_skill_coverages
  where project_id = old.proposal_id
    and skill_id = old.skill_id;

  return old;
end;
$$;

create constraint trigger proposal_skills_clear_removed_live_coverage
after delete on public.proposal_skills
deferrable initially deferred
for each row execute function private.clear_removed_proposal_skill_coverage();

create function private.clear_closed_resource_need_coverage()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.state = 'open' and new.state = 'closed' then
    delete from public.project_membership_resource_coverages
    where resource_need_id = new.id;

    delete from public.project_manual_resource_coverages
    where resource_need_id = new.id;
  end if;

  return new;
end;
$$;

create trigger project_resource_needs_clear_closed_live_coverage
after update of state on public.project_resource_needs
for each row execute function private.clear_closed_resource_need_coverage();

-- Existing D1 decisions are immutable history. Seed only current membership
-- episodes whose needed decisions still match a current operational requirement.
insert into public.project_membership_skill_coverages (
  membership_id,
  skill_id,
  covered_at
)
select
  membership.id,
  decision.skill_id,
  decision.decided_at
from public.project_join_request_skill_acceptance_decisions as decision
join public.project_memberships as membership
  on membership.originating_request_id = decision.request_id
join public.project_membership_skill_commitments as commitment
  on commitment.membership_id = membership.id
  and commitment.skill_id = decision.skill_id
join public.projects as project on project.id = membership.project_id
join public.proposals as proposal on proposal.id = project.id
join public.proposal_skills as proposal_skill
  on proposal_skill.proposal_id = project.id
  and proposal_skill.skill_id = decision.skill_id
where decision.disposition = 'needed'
  and membership.left_at is null
  and membership.removed_at is null
  and project.project_kind = 'one_time'
  and proposal.lifecycle_state = 'published'
  and proposal.ends_at is not null
  and statement_timestamp() < proposal.ends_at
on conflict (membership_id, skill_id) do nothing;

insert into public.project_membership_resource_coverages (
  membership_id,
  resource_need_id,
  covered_at
)
select
  membership.id,
  decision.resource_need_id,
  decision.decided_at
from public.project_join_request_resource_acceptance_decisions as decision
join public.project_memberships as membership
  on membership.originating_request_id = decision.request_id
join public.project_membership_resource_commitments as commitment
  on commitment.membership_id = membership.id
  and commitment.resource_need_id = decision.resource_need_id
join public.projects as project on project.id = membership.project_id
join public.project_resource_needs as need
  on need.id = decision.resource_need_id
  and need.project_id = project.id
  and need.state = 'open'
left join public.proposals as proposal
  on proposal.id = project.id
  and project.project_kind = 'one_time'
left join public.recurring_activities as activity
  on activity.id = project.id
  and project.project_kind = 'recurring'
where decision.disposition = 'needed'
  and membership.left_at is null
  and membership.removed_at is null
  and (
    (
      project.project_kind = 'one_time'
      and proposal.lifecycle_state = 'published'
      and proposal.ends_at is not null
      and statement_timestamp() < proposal.ends_at
    )
    or (
      project.project_kind = 'recurring'
      and activity.lifecycle_state in ('published', 'paused')
    )
  )
on conflict (membership_id, resource_need_id) do nothing;

with latest_current_already_found as (
  select distinct on (request.project_id, decision.skill_id)
    request.project_id,
    decision.skill_id,
    decision.decided_at,
    decision.decided_by_profile_id,
    decision.request_id
  from public.project_join_request_skill_acceptance_decisions as decision
  join public.project_join_requests as request
    on request.id = decision.request_id
    and request.status = 'accepted'
  join public.projects as project on project.id = request.project_id
  join public.proposals as proposal on proposal.id = project.id
  join public.proposal_skills as proposal_skill
    on proposal_skill.proposal_id = project.id
    and proposal_skill.skill_id = decision.skill_id
  where decision.disposition = 'already_found'
    and project.project_kind = 'one_time'
    and proposal.lifecycle_state = 'published'
    and proposal.ends_at is not null
    and statement_timestamp() < proposal.ends_at
  order by
    request.project_id,
    decision.skill_id,
    decision.decided_at desc,
    decision.request_id desc
)
insert into public.project_manual_skill_coverages (
  project_id,
  skill_id,
  marked_at,
  marked_by_profile_id,
  originating_request_id
)
select
  candidate.project_id,
  candidate.skill_id,
  candidate.decided_at,
  candidate.decided_by_profile_id,
  candidate.request_id
from latest_current_already_found as candidate
where private.project_requirement_live_source_count(
  candidate.project_id,
  'skill',
  candidate.skill_id
) = 0
on conflict (project_id, skill_id) do nothing;

with latest_current_already_found as (
  select distinct on (request.project_id, decision.resource_need_id)
    request.project_id,
    decision.resource_need_id,
    decision.decided_at,
    decision.decided_by_profile_id,
    decision.request_id
  from public.project_join_request_resource_acceptance_decisions as decision
  join public.project_join_requests as request
    on request.id = decision.request_id
    and request.status = 'accepted'
  join public.projects as project on project.id = request.project_id
  join public.project_resource_needs as need
    on need.id = decision.resource_need_id
    and need.project_id = project.id
    and need.state = 'open'
  left join public.proposals as proposal
    on proposal.id = project.id
    and project.project_kind = 'one_time'
  left join public.recurring_activities as activity
    on activity.id = project.id
    and project.project_kind = 'recurring'
  where decision.disposition = 'already_found'
    and (
      (
        project.project_kind = 'one_time'
        and proposal.lifecycle_state = 'published'
        and proposal.ends_at is not null
        and statement_timestamp() < proposal.ends_at
      )
      or (
        project.project_kind = 'recurring'
        and activity.lifecycle_state in ('published', 'paused')
      )
    )
  order by
    request.project_id,
    decision.resource_need_id,
    decision.decided_at desc,
    decision.request_id desc
)
insert into public.project_manual_resource_coverages (
  resource_need_id,
  marked_at,
  marked_by_profile_id,
  originating_request_id
)
select
  candidate.resource_need_id,
  candidate.decided_at,
  candidate.decided_by_profile_id,
  candidate.request_id
from latest_current_already_found as candidate
where private.project_requirement_live_source_count(
  candidate.project_id,
  'resource',
  candidate.resource_need_id
) = 0
on conflict (resource_need_id) do nothing;

create function private.initialize_project_membership_live_coverage()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  project_record record;
  decision_record record;
  inserted_count integer;
  source_count_before bigint;
begin
  select * into project_record
  from private.lock_project_for_live_requirement_coverage(
    new.project_id,
    true
  );

  for decision_record in
    select decision.skill_id as requirement_id
    from public.project_join_request_skill_acceptance_decisions as decision
    join public.project_membership_skill_commitments as commitment
      on commitment.membership_id = new.id
      and commitment.skill_id = decision.skill_id
    join public.proposal_skills as proposal_skill
      on proposal_skill.proposal_id = new.project_id
      and proposal_skill.skill_id = decision.skill_id
    where decision.request_id = new.originating_request_id
      and decision.disposition = 'needed'
    order by decision.skill_id
  loop
    source_count_before := private.project_requirement_live_source_count(
      new.project_id,
      'skill',
      decision_record.requirement_id
    );

    insert into public.project_membership_skill_coverages (
      membership_id,
      skill_id,
      covered_at
    )
    values (new.id, decision_record.requirement_id, new.joined_at)
    on conflict (membership_id, skill_id) do nothing;

    get diagnostics inserted_count = row_count;

    if inserted_count = 1 and source_count_before = 0 then
      perform private.record_project_requirement_coverage_event(
        'project.requirement_covered',
        project_record.creator_profile_id,
        new.project_id,
        project_record.project_kind,
        'skill',
        decision_record.requirement_id,
        new.id
      );
    end if;
  end loop;

  for decision_record in
    select decision.resource_need_id as requirement_id
    from public.project_join_request_resource_acceptance_decisions as decision
    join public.project_membership_resource_commitments as commitment
      on commitment.membership_id = new.id
      and commitment.resource_need_id = decision.resource_need_id
    join public.project_resource_needs as need
      on need.id = decision.resource_need_id
      and need.project_id = new.project_id
      and need.state = 'open'
    where decision.request_id = new.originating_request_id
      and decision.disposition = 'needed'
    order by decision.resource_need_id
  loop
    source_count_before := private.project_requirement_live_source_count(
      new.project_id,
      'resource',
      decision_record.requirement_id
    );

    insert into public.project_membership_resource_coverages (
      membership_id,
      resource_need_id,
      covered_at
    )
    values (new.id, decision_record.requirement_id, new.joined_at)
    on conflict (membership_id, resource_need_id) do nothing;

    get diagnostics inserted_count = row_count;

    if inserted_count = 1 and source_count_before = 0 then
      perform private.record_project_requirement_coverage_event(
        'project.requirement_covered',
        project_record.creator_profile_id,
        new.project_id,
        project_record.project_kind,
        'resource',
        decision_record.requirement_id,
        new.id
      );
    end if;
  end loop;

  for decision_record in
    select decision.skill_id as requirement_id
    from public.project_join_request_skill_acceptance_decisions as decision
    join public.proposal_skills as proposal_skill
      on proposal_skill.proposal_id = new.project_id
      and proposal_skill.skill_id = decision.skill_id
    where decision.request_id = new.originating_request_id
      and decision.disposition = 'already_found'
    order by decision.skill_id
  loop
    if private.project_requirement_live_source_count(
      new.project_id,
      'skill',
      decision_record.requirement_id
    ) = 0 then
      insert into public.project_manual_skill_coverages (
        project_id,
        skill_id,
        marked_at,
        marked_by_profile_id,
        originating_request_id
      )
      values (
        new.project_id,
        decision_record.requirement_id,
        new.joined_at,
        project_record.creator_profile_id,
        new.originating_request_id
      )
      on conflict (project_id, skill_id) do nothing;

      get diagnostics inserted_count = row_count;

      if inserted_count = 1 then
        perform private.record_project_requirement_coverage_event(
          'project.requirement_covered',
          project_record.creator_profile_id,
          new.project_id,
          project_record.project_kind,
          'skill',
          decision_record.requirement_id,
          null
        );
      end if;
    end if;
  end loop;

  for decision_record in
    select decision.resource_need_id as requirement_id
    from public.project_join_request_resource_acceptance_decisions as decision
    join public.project_resource_needs as need
      on need.id = decision.resource_need_id
      and need.project_id = new.project_id
      and need.state = 'open'
    where decision.request_id = new.originating_request_id
      and decision.disposition = 'already_found'
    order by decision.resource_need_id
  loop
    if private.project_requirement_live_source_count(
      new.project_id,
      'resource',
      decision_record.requirement_id
    ) = 0 then
      insert into public.project_manual_resource_coverages (
        resource_need_id,
        marked_at,
        marked_by_profile_id,
        originating_request_id
      )
      values (
        decision_record.requirement_id,
        new.joined_at,
        project_record.creator_profile_id,
        new.originating_request_id
      )
      on conflict (resource_need_id) do nothing;

      get diagnostics inserted_count = row_count;

      if inserted_count = 1 then
        perform private.record_project_requirement_coverage_event(
          'project.requirement_covered',
          project_record.creator_profile_id,
          new.project_id,
          project_record.project_kind,
          'resource',
          decision_record.requirement_id,
          null
        );
      end if;
    end if;
  end loop;

  return new;
end;
$$;

-- PostgreSQL fires same-timing triggers alphabetically. The z-prefixed trigger
-- must run after project_memberships_seed_commitments so coverage's composite
-- foreign keys always see the needed commitment rows in the same transaction.
create trigger project_memberships_z_initialize_live_coverage
after insert on public.project_memberships
for each row execute function
  private.initialize_project_membership_live_coverage();

create function public.claim_project_requirement(
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
    raise exception using
      errcode = '40001',
      message = 'The Project requirement is already covered.';
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

create function public.set_project_requirement_manual_coverage(
  p_expected_creator_profile_id uuid,
  p_project_id uuid,
  p_requirement_kind text,
  p_requirement_id uuid,
  p_is_covered boolean
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
  normalized_requirement_kind text := lower(btrim(p_requirement_kind));
  project_record record;
  resource_need public.project_resource_needs%rowtype;
  source_count_before bigint;
  changed_count integer;
begin
  if normalized_requirement_kind is null
    or normalized_requirement_kind not in ('skill', 'resource')
    or p_requirement_id is null
    or p_is_covered is null then
    raise exception using
      errcode = '22023',
      message = 'Manual coverage requires one skill or resource and a coverage value.';
  end if;

  select * into project_record
  from private.lock_project_for_live_requirement_coverage(p_project_id, true);

  if project_record.creator_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'Only the Project creator can manage manual requirement coverage.';
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

  source_count_before := private.project_requirement_live_source_count(
    p_project_id,
    normalized_requirement_kind,
    p_requirement_id
  );

  if p_is_covered then
    if normalized_requirement_kind = 'skill' then
      insert into public.project_manual_skill_coverages (
        project_id,
        skill_id,
        marked_by_profile_id
      )
      values (p_project_id, p_requirement_id, current_profile_id)
      on conflict (project_id, skill_id) do nothing;
    else
      insert into public.project_manual_resource_coverages (
        resource_need_id,
        marked_by_profile_id
      )
      values (p_requirement_id, current_profile_id)
      on conflict (resource_need_id) do nothing;
    end if;

    get diagnostics changed_count = row_count;

    if changed_count = 1 and source_count_before = 0 then
      perform private.record_project_requirement_coverage_event(
        'project.requirement_covered',
        current_profile_id,
        p_project_id,
        project_record.project_kind,
        normalized_requirement_kind,
        p_requirement_id,
        null
      );
    end if;
  else
    if normalized_requirement_kind = 'skill' then
      delete from public.project_manual_skill_coverages
      where project_id = p_project_id
        and skill_id = p_requirement_id;
    else
      delete from public.project_manual_resource_coverages
      where resource_need_id = p_requirement_id;
    end if;

    get diagnostics changed_count = row_count;

    if changed_count = 1
      and private.project_requirement_live_source_count(
        p_project_id,
        normalized_requirement_kind,
        p_requirement_id
      ) = 0 then
      perform private.record_project_requirement_coverage_event(
        'project.requirement_needed_again',
        current_profile_id,
        p_project_id,
        project_record.project_kind,
        normalized_requirement_kind,
        p_requirement_id,
        null
      );
    end if;
  end if;

  return p_requirement_id;
end;
$$;

create function public.list_project_live_requirement_coverage(
  p_expected_profile_id uuid,
  p_project_id uuid
)
returns table (
  requirement_kind text,
  requirement_id uuid,
  label text,
  importance text,
  is_covered boolean,
  viewer_is_covering boolean,
  is_manually_covered boolean
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
  registry public.projects%rowtype;
begin
  select * into registry
  from public.projects as project
  where project.id = p_project_id;

  if not found
    or (
      registry.creator_profile_id <> current_profile_id
      and not exists (
        select 1
        from public.project_memberships as membership
        where membership.project_id = p_project_id
          and membership.participant_profile_id = current_profile_id
          and membership.left_at is null
          and membership.removed_at is null
      )
    ) then
    raise exception using
      errcode = '42501',
      message = 'Live Project requirement coverage is unavailable.';
  end if;

  if not private.project_has_live_coverage_lifecycle(p_project_id) then
    raise exception using
      errcode = '55000',
      message = 'Live requirement coverage is available only while the Project is operational.';
  end if;

  return query
  with current_requirements as (
    select
      'skill'::text as resolved_kind,
      proposal_skill.skill_id as resolved_id,
      skill.label as resolved_label,
      proposal_skill.importance as resolved_importance,
      0::smallint as kind_order,
      category.sort_order as category_order,
      skill.sort_order as item_order,
      null::timestamptz as resource_created_at
    from public.proposal_skills as proposal_skill
    join public.skills as skill on skill.id = proposal_skill.skill_id
    join public.skill_categories as category on category.id = skill.category_id
    where registry.project_kind = 'one_time'
      and proposal_skill.proposal_id = p_project_id

    union all

    select
      'resource'::text,
      need.id,
      need.title,
      null::text,
      1::smallint,
      0::smallint,
      0::smallint,
      need.created_at
    from public.project_resource_needs as need
    where need.project_id = p_project_id
      and need.state = 'open'
  )
  select
    requirement.resolved_kind,
    requirement.resolved_id,
    requirement.resolved_label,
    requirement.resolved_importance,
    private.project_requirement_live_source_count(
      p_project_id,
      requirement.resolved_kind,
      requirement.resolved_id
    ) > 0,
    case requirement.resolved_kind
      when 'skill' then exists (
        select 1
        from public.project_membership_skill_coverages as coverage
        join public.project_memberships as membership
          on membership.id = coverage.membership_id
        where membership.project_id = p_project_id
          and membership.participant_profile_id = current_profile_id
          and membership.left_at is null
          and membership.removed_at is null
          and coverage.skill_id = requirement.resolved_id
      )
      when 'resource' then exists (
        select 1
        from public.project_membership_resource_coverages as coverage
        join public.project_memberships as membership
          on membership.id = coverage.membership_id
        where membership.project_id = p_project_id
          and membership.participant_profile_id = current_profile_id
          and membership.left_at is null
          and membership.removed_at is null
          and coverage.resource_need_id = requirement.resolved_id
      )
      else false
    end,
    case requirement.resolved_kind
      when 'skill' then exists (
        select 1
        from public.project_manual_skill_coverages as coverage
        where coverage.project_id = p_project_id
          and coverage.skill_id = requirement.resolved_id
      )
      when 'resource' then exists (
        select 1
        from public.project_manual_resource_coverages as coverage
        where coverage.resource_need_id = requirement.resolved_id
      )
      else false
    end
  from current_requirements as requirement
  order by
    requirement.kind_order,
    requirement.category_order,
    requirement.item_order,
    requirement.resource_created_at,
    requirement.resolved_id;
end;
$$;

revoke all privileges on function private.project_has_live_coverage_lifecycle(uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function
  private.lock_project_for_live_requirement_coverage(uuid, boolean)
  from public, anon, authenticated, service_role;
revoke all privileges on function
  private.project_requirement_is_current(uuid, text, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function
  private.project_requirement_live_source_count(uuid, text, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function
  private.record_project_requirement_coverage_event(
    text,
    uuid,
    uuid,
    text,
    text,
    uuid,
    uuid
  )
  from public, anon, authenticated, service_role;
revoke all privileges on function
  private.release_removed_project_membership_coverages(
    uuid,
    uuid,
    uuid,
    text,
    uuid[],
    uuid[]
  )
  from public, anon, authenticated, service_role;
revoke all privileges on function
  private.release_coverage_before_skill_commitment_delete()
  from public, anon, authenticated, service_role;
revoke all privileges on function
  private.release_coverage_before_resource_commitment_delete()
  from public, anon, authenticated, service_role;
revoke all privileges on function
  private.release_ended_project_membership_coverage()
  from public, anon, authenticated, service_role;
revoke all privileges on function
  private.lock_project_before_proposal_skill_delete()
  from public, anon, authenticated, service_role;
revoke all privileges on function
  private.clear_removed_proposal_skill_coverage()
  from public, anon, authenticated, service_role;
revoke all privileges on function
  private.clear_closed_resource_need_coverage()
  from public, anon, authenticated, service_role;
revoke all privileges on function
  private.initialize_project_membership_live_coverage()
  from public, anon, authenticated, service_role;
revoke all privileges on function
  public.claim_project_requirement(uuid, uuid, text, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function
  public.set_project_requirement_manual_coverage(
    uuid,
    uuid,
    text,
    uuid,
    boolean
  )
  from public, anon, authenticated, service_role;
revoke all privileges on function
  public.list_project_live_requirement_coverage(uuid, uuid)
  from public, anon, authenticated, service_role;

grant execute on function
  public.claim_project_requirement(uuid, uuid, text, uuid)
  to authenticated;
grant execute on function
  public.set_project_requirement_manual_coverage(
    uuid,
    uuid,
    text,
    uuid,
    boolean
  )
  to authenticated;
grant execute on function
  public.list_project_live_requirement_coverage(uuid, uuid)
  to authenticated;

comment on function private.project_has_live_coverage_lifecycle(uuid) is
  'Reports whether a Proposal or Tavolo currently supports live coordination without treating ended Projects as uncovered transitions.';
comment on function
  private.lock_project_for_live_requirement_coverage(uuid, boolean)
is
  'Locks the concrete Proposal/Tavolo then shared Project row to serialize every live-coverage source transition.';
comment on function
  private.project_requirement_is_current(uuid, text, uuid)
is
  'Checks current Proposal-skill or open resource-need identity without treating coverage as the requirement lifecycle.';
comment on function
  private.project_requirement_live_source_count(uuid, text, uuid)
is
  'Counts current participant and independent manual sources for one Project requirement.';
comment on function
  private.record_project_requirement_coverage_event(
    text,
    uuid,
    uuid,
    text,
    text,
    uuid,
    uuid
  )
is
  'Emits only identifier metadata for exact uncovered-to-covered or covered-to-uncovered Project requirement transitions.';
comment on function private.initialize_project_membership_live_coverage() is
  'Maps needed acceptance decisions to participant coverage and conservatively maps current already_found decisions to a manual source in the acceptance transaction.';
comment on function
  public.claim_project_requirement(uuid, uuid, text, uuid)
is
  'Lets one current participant atomically claim one uncovered operational requirement, creating a missing commitment within the existing 50/50 limits.';
comment on function
  public.set_project_requirement_manual_coverage(
    uuid,
    uuid,
    text,
    uuid,
    boolean
  )
is
  'Lets the canonical Project creator idempotently add or clear one independent external coverage marker while emitting only real total-source transitions.';
comment on function
  public.list_project_live_requirement_coverage(uuid, uuid)
is
  'Returns current operational requirement labels and coverage booleans to the Project creator or a current participant without exposing provider identities.';
