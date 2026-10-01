create table public.project_join_request_skill_acceptance_decisions (
  request_id uuid not null,
  skill_id uuid not null,
  disposition text not null
    constraint project_join_request_skill_acceptance_disposition_valid check (
      disposition in ('needed', 'already_found', 'extra')
    ),
  decided_at timestamptz not null,
  decided_by_profile_id uuid not null
    constraint project_join_request_skill_acceptance_decided_by_fkey
      references public.profiles (id) on delete restrict,
  constraint project_join_request_skill_acceptance_decisions_pkey
    primary key (request_id, skill_id),
  constraint project_join_request_skill_acceptance_selection_fkey
    foreign key (request_id, skill_id)
      references public.project_join_request_skill_selections (
        request_id,
        skill_id
      )
      on delete restrict
);

comment on table public.project_join_request_skill_acceptance_decisions is
  'Immutable creator triage of each skill offered in one accepted join-request attempt; this history is distinct from mutable membership commitments and future coverage.';

create index project_join_request_skill_acceptance_decided_by_idx
  on public.project_join_request_skill_acceptance_decisions (
    decided_by_profile_id
  );

create table public.project_join_request_resource_acceptance_decisions (
  request_id uuid not null,
  resource_need_id uuid not null,
  disposition text not null
    constraint project_join_request_resource_acceptance_disposition_valid check (
      disposition in ('needed', 'already_found', 'extra')
    ),
  decided_at timestamptz not null,
  decided_by_profile_id uuid not null
    constraint project_join_request_resource_acceptance_decided_by_fkey
      references public.profiles (id) on delete restrict,
  constraint project_join_request_resource_acceptance_decisions_pkey
    primary key (request_id, resource_need_id),
  constraint project_join_request_resource_acceptance_selection_fkey
    foreign key (request_id, resource_need_id)
      references public.project_join_request_resource_selections (
        request_id,
        resource_need_id
      )
      on delete restrict
);

comment on table public.project_join_request_resource_acceptance_decisions is
  'Immutable creator triage of each resource offered in one accepted join-request attempt; needed and extra seed commitments while already_found does not.';

create index project_join_request_resource_acceptance_decided_by_idx
  on public.project_join_request_resource_acceptance_decisions (
    decided_by_profile_id
  );

alter table public.project_join_request_skill_acceptance_decisions
  enable row level security;
alter table public.project_join_request_resource_acceptance_decisions
  enable row level security;

revoke all privileges on table
  public.project_join_request_skill_acceptance_decisions
  from public, anon, authenticated, service_role;
revoke all privileges on table
  public.project_join_request_resource_acceptance_decisions
  from public, anon, authenticated, service_role;

-- Accepted membership history predates explicit triage. Preserve the old
-- all-selections-seed-commitments meaning without rewriting current sets.
insert into public.project_join_request_skill_acceptance_decisions (
  request_id,
  skill_id,
  disposition,
  decided_at,
  decided_by_profile_id
)
select
  membership.originating_request_id,
  selection.skill_id,
  'needed',
  membership.joined_at,
  request.resolved_by_profile_id
from public.project_memberships as membership
join public.project_join_requests as request
  on request.id = membership.originating_request_id
join public.project_join_request_skill_selections as selection
  on selection.request_id = membership.originating_request_id
where request.status = 'accepted';

insert into public.project_join_request_resource_acceptance_decisions (
  request_id,
  resource_need_id,
  disposition,
  decided_at,
  decided_by_profile_id
)
select
  membership.originating_request_id,
  selection.resource_need_id,
  'needed',
  membership.joined_at,
  request.resolved_by_profile_id
from public.project_memberships as membership
join public.project_join_requests as request
  on request.id = membership.originating_request_id
join public.project_join_request_resource_selections as selection
  on selection.request_id = membership.originating_request_id
where request.status = 'accepted';

create function private.prevent_project_join_request_acceptance_decision_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception using
    errcode = '55000',
    message = 'Project join-request acceptance decisions are immutable.';
end;
$$;

create trigger project_join_request_skill_acceptance_decisions_immutable
before update or delete
on public.project_join_request_skill_acceptance_decisions
for each row execute function
  private.prevent_project_join_request_acceptance_decision_mutation();

create trigger project_join_request_resource_acceptance_decisions_immutable
before update or delete
on public.project_join_request_resource_acceptance_decisions
for each row execute function
  private.prevent_project_join_request_acceptance_decision_mutation();

create or replace function private.seed_project_membership_commitments()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (
    select 1
    from public.project_join_request_skill_selections as selection
    left join public.project_join_request_skill_acceptance_decisions as decision
      on decision.request_id = selection.request_id
      and decision.skill_id = selection.skill_id
    where selection.request_id = new.originating_request_id
      and decision.request_id is null
  ) or exists (
    select 1
    from public.project_join_request_resource_selections as selection
    left join public.project_join_request_resource_acceptance_decisions as decision
      on decision.request_id = selection.request_id
      and decision.resource_need_id = selection.resource_need_id
    where selection.request_id = new.originating_request_id
      and decision.request_id is null
  ) then
    raise exception using
      errcode = '55000',
      message = 'Contribution triage must be complete before membership creation.';
  end if;

  insert into public.project_membership_skill_commitments (
    membership_id,
    skill_id,
    committed_at
  )
  select new.id, decision.skill_id, new.joined_at
  from public.project_join_request_skill_acceptance_decisions as decision
  where decision.request_id = new.originating_request_id
    and decision.disposition in ('needed', 'extra')
  on conflict (membership_id, skill_id) do nothing;

  insert into public.project_membership_resource_commitments (
    membership_id,
    resource_need_id,
    committed_at
  )
  select new.id, decision.resource_need_id, new.joined_at
  from public.project_join_request_resource_acceptance_decisions as decision
  where decision.request_id = new.originating_request_id
    and decision.disposition in ('needed', 'extra')
  on conflict (membership_id, resource_need_id) do nothing;

  return new;
end;
$$;

comment on function private.seed_project_membership_commitments() is
  'Fails closed unless every originating request selection has immutable acceptance triage, then seeds only needed and extra commitments in the acceptance transaction.';

create function public.accept_project_join_request(
  p_expected_creator_profile_id uuid,
  p_request_id uuid,
  p_needed_skill_ids uuid[],
  p_already_found_skill_ids uuid[],
  p_extra_skill_ids uuid[],
  p_needed_resource_need_ids uuid[],
  p_already_found_resource_need_ids uuid[],
  p_extra_resource_need_ids uuid[]
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
  request_record public.project_join_requests%rowtype;
  project_record record;
  transition_time timestamptz := statement_timestamp();
  classified_skill_ids uuid[];
  classified_resource_need_ids uuid[];
  locked_resource_need record;
  locked_resource_need_count integer := 0;
  new_membership_id uuid;
begin
  if p_needed_skill_ids is null
    or p_already_found_skill_ids is null
    or p_extra_skill_ids is null
    or p_needed_resource_need_ids is null
    or p_already_found_resource_need_ids is null
    or p_extra_resource_need_ids is null then
    raise exception using
      errcode = '22023',
      message = 'All contribution-triage arrays are required.';
  end if;

  classified_skill_ids :=
    p_needed_skill_ids || p_already_found_skill_ids || p_extra_skill_ids;
  classified_resource_need_ids :=
    p_needed_resource_need_ids
    || p_already_found_resource_need_ids
    || p_extra_resource_need_ids;

  if cardinality(classified_skill_ids) > 50 then
    raise exception using
      errcode = '22023',
      message = 'Contribution triage may classify at most 50 Project skills.';
  end if;

  if cardinality(classified_resource_need_ids) > 50 then
    raise exception using
      errcode = '22023',
      message = 'Contribution triage may classify at most 50 Project resource needs.';
  end if;

  if exists (
    select 1
    from unnest(classified_skill_ids) as classified(skill_id)
    where classified.skill_id is null
  ) then
    raise exception using
      errcode = '22023',
      message = 'Skill contribution triage cannot contain null identifiers.';
  end if;

  if exists (
    select 1
    from unnest(classified_resource_need_ids) as classified(resource_need_id)
    where classified.resource_need_id is null
  ) then
    raise exception using
      errcode = '22023',
      message = 'Resource contribution triage cannot contain null identifiers.';
  end if;

  if cardinality(p_needed_skill_ids) <>
    (select count(distinct classified.skill_id)
     from unnest(p_needed_skill_ids) as classified(skill_id))
    or cardinality(p_already_found_skill_ids) <>
    (select count(distinct classified.skill_id)
     from unnest(p_already_found_skill_ids) as classified(skill_id))
    or cardinality(p_extra_skill_ids) <>
    (select count(distinct classified.skill_id)
     from unnest(p_extra_skill_ids) as classified(skill_id)) then
    raise exception using
      errcode = '22023',
      message = 'Each skill disposition array must contain unique identifiers.';
  end if;

  if cardinality(p_needed_resource_need_ids) <>
    (select count(distinct classified.resource_need_id)
     from unnest(p_needed_resource_need_ids) as classified(resource_need_id))
    or cardinality(p_already_found_resource_need_ids) <>
    (select count(distinct classified.resource_need_id)
     from unnest(p_already_found_resource_need_ids) as classified(resource_need_id))
    or cardinality(p_extra_resource_need_ids) <>
    (select count(distinct classified.resource_need_id)
     from unnest(p_extra_resource_need_ids) as classified(resource_need_id)) then
    raise exception using
      errcode = '22023',
      message = 'Each resource disposition array must contain unique identifiers.';
  end if;

  if cardinality(classified_skill_ids) <>
    (select count(distinct classified.skill_id)
     from unnest(classified_skill_ids) as classified(skill_id)) then
    raise exception using
      errcode = '22023',
      message = 'A skill cannot appear in more than one acceptance disposition.';
  end if;

  if cardinality(classified_resource_need_ids) <>
    (select count(distinct classified.resource_need_id)
     from unnest(classified_resource_need_ids) as classified(resource_need_id)) then
    raise exception using
      errcode = '22023',
      message = 'A resource need cannot appear in more than one acceptance disposition.';
  end if;

  select * into request_record
  from public.project_join_requests as request
  where request.id = p_request_id;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'The join request does not exist.';
  end if;

  select * into project_record
  from private.lock_project_for_participation(request_record.project_id, true);

  select * into request_record
  from public.project_join_requests as request
  where request.id = p_request_id
  for update;

  if project_record.creator_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'Only the project creator can accept join requests.';
  end if;

  if request_record.status <> 'pending' then
    raise exception using
      errcode = '55000',
      message = 'Only a pending join request can be accepted.';
  end if;

  if request_record.requester_profile_id = project_record.creator_profile_id then
    raise exception using
      errcode = '55000',
      message = 'A project creator cannot become a participant through a join request.';
  end if;

  if not exists (
    select 1
    from public.profiles as profile
    where profile.id = request_record.requester_profile_id
      and profile.display_name is not null
  ) then
    raise exception using
      errcode = '55000',
      message = 'The requester no longer has a complete profile.';
  end if;

  if exists (
    select 1
    from public.project_memberships as membership
    where membership.project_id = request_record.project_id
      and membership.participant_profile_id = request_record.requester_profile_id
      and membership.left_at is null
      and membership.removed_at is null
  ) then
    raise exception using
      errcode = '55000',
      message = 'The requester is already a current project participant.';
  end if;

  if cardinality(classified_skill_ids) <> (
    select count(*)
    from public.project_join_request_skill_selections as selection
    where selection.request_id = request_record.id
  ) or exists (
    select classified.skill_id
    from unnest(classified_skill_ids) as classified(skill_id)
    except
    select selection.skill_id
    from public.project_join_request_skill_selections as selection
    where selection.request_id = request_record.id
  ) or exists (
    select selection.skill_id
    from public.project_join_request_skill_selections as selection
    where selection.request_id = request_record.id
    except
    select classified.skill_id
    from unnest(classified_skill_ids) as classified(skill_id)
  ) then
    raise exception using
      errcode = '22023',
      message = 'Skill contribution triage must exactly partition the request selections.';
  end if;

  if cardinality(classified_resource_need_ids) <> (
    select count(*)
    from public.project_join_request_resource_selections as selection
    where selection.request_id = request_record.id
  ) or exists (
    select classified.resource_need_id
    from unnest(classified_resource_need_ids)
      as classified(resource_need_id)
    except
    select selection.resource_need_id
    from public.project_join_request_resource_selections as selection
    where selection.request_id = request_record.id
  ) or exists (
    select selection.resource_need_id
    from public.project_join_request_resource_selections as selection
    where selection.request_id = request_record.id
    except
    select classified.resource_need_id
    from unnest(classified_resource_need_ids)
      as classified(resource_need_id)
  ) then
    raise exception using
      errcode = '22023',
      message = 'Resource contribution triage must exactly partition the request selections.';
  end if;

  if project_record.project_kind = 'recurring'
    and cardinality(classified_skill_ids) > 0 then
    raise exception using
      errcode = '22023',
      message = 'Recurring Projects do not define skill contribution triage.';
  end if;

  if project_record.project_kind = 'one_time'
    and exists (
      select 1
      from unnest(p_needed_skill_ids) as needed(skill_id)
      left join public.proposal_skills as proposal_skill
        on proposal_skill.proposal_id = request_record.project_id
        and proposal_skill.skill_id = needed.skill_id
      where proposal_skill.skill_id is null
    ) then
    raise exception using
      errcode = '22023',
      message = 'Every needed skill must remain a current Proposal requirement.';
  end if;

  -- The participation helper already holds the concrete Project then shared
  -- Project rows. Lock only needed resources in UUID order after those anchors,
  -- matching resource-need mutation order and serializing close versus accept.
  for locked_resource_need in
    select need.id, need.project_id, need.state
    from public.project_resource_needs as need
    where need.id = any(p_needed_resource_need_ids)
    order by need.id
    for share
  loop
    locked_resource_need_count := locked_resource_need_count + 1;

    if locked_resource_need.project_id <> request_record.project_id
      or locked_resource_need.state <> 'open' then
      raise exception using
        errcode = '22023',
        message = 'Every needed resource must remain open and belong to this Project.';
    end if;
  end loop;

  if locked_resource_need_count <>
    cardinality(p_needed_resource_need_ids) then
    raise exception using
      errcode = '22023',
      message = 'Every needed resource must remain open and belong to this Project.';
  end if;

  insert into public.project_join_request_skill_acceptance_decisions (
    request_id,
    skill_id,
    disposition,
    decided_at,
    decided_by_profile_id
  )
  select
    request_record.id,
    triage.skill_id,
    triage.disposition,
    transition_time,
    current_profile_id
  from (
    select needed.skill_id, 'needed'::text as disposition
    from unnest(p_needed_skill_ids) as needed(skill_id)
    union all
    select already_found.skill_id, 'already_found'::text
    from unnest(p_already_found_skill_ids) as already_found(skill_id)
    union all
    select extra.skill_id, 'extra'::text
    from unnest(p_extra_skill_ids) as extra(skill_id)
  ) as triage;

  insert into public.project_join_request_resource_acceptance_decisions (
    request_id,
    resource_need_id,
    disposition,
    decided_at,
    decided_by_profile_id
  )
  select
    request_record.id,
    triage.resource_need_id,
    triage.disposition,
    transition_time,
    current_profile_id
  from (
    select needed.resource_need_id, 'needed'::text as disposition
    from unnest(p_needed_resource_need_ids) as needed(resource_need_id)
    union all
    select already_found.resource_need_id, 'already_found'::text
    from unnest(p_already_found_resource_need_ids)
      as already_found(resource_need_id)
    union all
    select extra.resource_need_id, 'extra'::text
    from unnest(p_extra_resource_need_ids) as extra(resource_need_id)
  ) as triage;

  update public.project_join_requests
  set
    status = 'accepted',
    resolved_at = transition_time,
    resolved_by_profile_id = current_profile_id
  where id = request_record.id;

  insert into public.project_memberships (
    project_id,
    participant_profile_id,
    originating_request_id,
    joined_at
  )
  values (
    request_record.project_id,
    request_record.requester_profile_id,
    request_record.id,
    transition_time
  )
  returning id into new_membership_id;

  perform private.record_project_participation_event(
    'project.join_request_accepted',
    current_profile_id,
    request_record.project_id,
    jsonb_build_object(
      'project_kind', project_record.project_kind,
      'request_id', request_record.id,
      'requester_profile_id', request_record.requester_profile_id,
      'membership_id', new_membership_id,
      'status', 'accepted'
    )
  );

  return new_membership_id;
end;
$$;

create or replace function public.accept_project_join_request(
  p_expected_creator_profile_id uuid,
  p_request_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
begin
  return public.accept_project_join_request(
    p_expected_creator_profile_id,
    p_request_id,
    '{}'::uuid[],
    '{}'::uuid[],
    '{}'::uuid[],
    '{}'::uuid[],
    '{}'::uuid[],
    '{}'::uuid[]
  );
end;
$$;

revoke all privileges on function
  private.prevent_project_join_request_acceptance_decision_mutation()
  from public, anon, authenticated, service_role;
revoke all privileges on function public.accept_project_join_request(
  uuid,
  uuid,
  uuid[],
  uuid[],
  uuid[],
  uuid[],
  uuid[],
  uuid[]
) from public, anon, authenticated, service_role;
revoke all privileges on function public.accept_project_join_request(uuid, uuid)
  from public, anon, authenticated, service_role;

grant execute on function public.accept_project_join_request(
  uuid,
  uuid,
  uuid[],
  uuid[],
  uuid[],
  uuid[],
  uuid[],
  uuid[]
) to authenticated;
grant execute on function public.accept_project_join_request(uuid, uuid)
  to authenticated;

comment on function public.accept_project_join_request(
  uuid,
  uuid,
  uuid[],
  uuid[],
  uuid[],
  uuid[],
  uuid[],
  uuid[]
) is
  'Atomically accepts one pending request only after exact needed/already_found/extra triage; needed and extra seed commitments while the identifier-only acceptance event and chat activation remain unchanged.';
comment on function public.accept_project_join_request(uuid, uuid) is
  'Compatibility acceptance for zero-selection requests only; selected contributions fail exact triage and require the explicit eight-argument overload.';
