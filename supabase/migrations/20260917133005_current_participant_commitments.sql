create table public.project_membership_skill_commitments (
  membership_id uuid not null
    constraint project_membership_skill_commitments_membership_id_fkey
      references public.project_memberships (id) on delete restrict,
  skill_id uuid not null
    constraint project_membership_skill_commitments_skill_id_fkey
      references public.skills (id) on delete restrict,
  committed_at timestamptz not null default now(),
  primary key (membership_id, skill_id)
);

comment on table public.project_membership_skill_commitments is
  'Mutable skill commitments owned by one accepted membership episode; ended memberships retain their final set as history.';

create index project_membership_skill_commitments_skill_membership_idx
  on public.project_membership_skill_commitments (skill_id, membership_id);

create table public.project_membership_resource_commitments (
  membership_id uuid not null
    constraint project_membership_resource_commitments_membership_id_fkey
      references public.project_memberships (id) on delete restrict,
  resource_need_id uuid not null
    constraint project_membership_resource_commitments_need_id_fkey
      references public.project_resource_needs (id) on delete restrict,
  committed_at timestamptz not null default now(),
  primary key (membership_id, resource_need_id)
);

comment on table public.project_membership_resource_commitments is
  'Mutable resource-need commitments owned by one accepted membership episode; commitment is not fulfillment, delivery, verification, or credit.';

create index project_membership_resource_commitments_need_membership_idx
  on public.project_membership_resource_commitments (
    resource_need_id,
    membership_id
  );

alter table public.project_membership_skill_commitments enable row level security;
alter table public.project_membership_resource_commitments enable row level security;

revoke all privileges on table public.project_membership_skill_commitments
  from public, anon, authenticated, service_role;
revoke all privileges on table public.project_membership_resource_commitments
  from public, anon, authenticated, service_role;

create function private.seed_project_membership_commitments()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.project_membership_skill_commitments (
    membership_id,
    skill_id,
    committed_at
  )
  select new.id, selection.skill_id, new.joined_at
  from public.project_join_request_skill_selections as selection
  where selection.request_id = new.originating_request_id
  on conflict (membership_id, skill_id) do nothing;

  insert into public.project_membership_resource_commitments (
    membership_id,
    resource_need_id,
    committed_at
  )
  select new.id, selection.resource_need_id, new.joined_at
  from public.project_join_request_resource_selections as selection
  where selection.request_id = new.originating_request_id
  on conflict (membership_id, resource_need_id) do nothing;

  return new;
end;
$$;

comment on function private.seed_project_membership_commitments() is
  'Seeds one newly accepted membership episode from its immutable request selections in the acceptance transaction without emitting an event.';

create trigger project_memberships_seed_commitments
after insert on public.project_memberships
for each row
execute function private.seed_project_membership_commitments();

-- Existing membership episodes predate the trigger. Backfill both current and ended
-- rows from their immutable originating request without changing request history.
insert into public.project_membership_skill_commitments (
  membership_id,
  skill_id,
  committed_at
)
select membership.id, selection.skill_id, membership.joined_at
from public.project_memberships as membership
join public.project_join_request_skill_selections as selection
  on selection.request_id = membership.originating_request_id
on conflict (membership_id, skill_id) do nothing;

insert into public.project_membership_resource_commitments (
  membership_id,
  resource_need_id,
  committed_at
)
select membership.id, selection.resource_need_id, membership.joined_at
from public.project_memberships as membership
join public.project_join_request_resource_selections as selection
  on selection.request_id = membership.originating_request_id
on conflict (membership_id, resource_need_id) do nothing;

create function private.lock_project_for_membership_commitment_mutation(
  p_project_id uuid
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

  if source_is_operational is not true then
    raise exception using
      errcode = '55000',
      message = 'Membership commitments can only change while the Project is operational.';
  end if;

  -- Match participation/resource transitions: concrete Project first, shared
  -- Project second. The caller then locks membership and resource rows.
  select * into registry
  from public.projects as project
  where project.id = p_project_id
  for update;

  return query select registry.project_kind, registry.creator_profile_id;
end;
$$;

create function private.record_project_membership_commitment_event(
  p_actor_profile_id uuid,
  p_project_id uuid,
  p_project_kind text,
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
    'project_kind', p_project_kind,
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
    'project.membership_commitments_updated',
    p_actor_profile_id,
    'project_membership',
    p_membership_id,
    identifier_payload
  );

  insert into private.outbox_events (event_type, payload)
  values ('project.membership_commitments_updated', identifier_payload);
end;
$$;

create function public.replace_project_membership_commitments(
  p_expected_actor_profile_id uuid,
  p_membership_id uuid,
  p_skill_ids uuid[] default '{}'::uuid[],
  p_resource_need_ids uuid[] default '{}'::uuid[]
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

create function public.list_own_project_membership_commitments(
  p_expected_profile_id uuid,
  p_membership_id uuid
)
returns table (
  commitment_kind text,
  commitment_id uuid,
  label text
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
  project_creator_profile_id uuid;
begin
  select * into membership_record
  from public.project_memberships as membership
  where membership.id = p_membership_id;

  if not found then
    raise exception using
      errcode = '42501',
      message = 'The membership commitments are unavailable.';
  end if;

  select project.creator_profile_id into project_creator_profile_id
  from public.projects as project
  where project.id = membership_record.project_id;

  if membership_record.participant_profile_id <> current_profile_id
    and project_creator_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'The membership commitments are unavailable.';
  end if;

  return query
  with ordered_commitments as (
    select
      'skill'::text as resolved_kind,
      commitment.skill_id as resolved_id,
      skill.label as resolved_label,
      0::smallint as kind_order,
      category.sort_order as category_order,
      skill.sort_order as item_order,
      null::timestamptz as resource_created_at
    from public.project_membership_skill_commitments as commitment
    join public.skills as skill on skill.id = commitment.skill_id
    join public.skill_categories as category on category.id = skill.category_id
    where commitment.membership_id = p_membership_id

    union all

    select
      'resource'::text,
      commitment.resource_need_id,
      resource_need.title,
      1::smallint,
      0::smallint,
      0::smallint,
      resource_need.created_at
    from public.project_membership_resource_commitments as commitment
    join public.project_resource_needs as resource_need
      on resource_need.id = commitment.resource_need_id
    where commitment.membership_id = p_membership_id
  )
  select
    ordered.resolved_kind,
    ordered.resolved_id,
    ordered.resolved_label
  from ordered_commitments as ordered
  order by
    ordered.kind_order,
    ordered.category_order,
    ordered.item_order,
    ordered.resource_created_at,
    ordered.resolved_id;
end;
$$;

revoke all privileges on function private.seed_project_membership_commitments()
  from public, anon, authenticated, service_role;
revoke all privileges on function
  private.lock_project_for_membership_commitment_mutation(uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function
  private.record_project_membership_commitment_event(uuid, uuid, text, uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function
  public.replace_project_membership_commitments(uuid, uuid, uuid[], uuid[])
  from public, anon, authenticated, service_role;
revoke all privileges on function
  public.list_own_project_membership_commitments(uuid, uuid)
  from public, anon, authenticated, service_role;

grant execute on function
  public.replace_project_membership_commitments(uuid, uuid, uuid[], uuid[])
  to authenticated;
grant execute on function
  public.list_own_project_membership_commitments(uuid, uuid)
  to authenticated;

comment on function
  private.lock_project_for_membership_commitment_mutation(uuid)
is
  'Locks an operational concrete Proposal/Tavolo then its shared Project row before membership-commitment mutation.';
comment on function
  private.record_project_membership_commitment_event(uuid, uuid, text, uuid, uuid)
is
  'Emits the identifier-only audit/outbox event for one real membership-commitment replacement.';
comment on function
  public.replace_project_membership_commitments(uuid, uuid, uuid[], uuid[])
is
  'Replaces the full skill/resource desired set for one current membership; only new IDs require current Project validity.';
comment on function public.list_own_project_membership_commitments(uuid, uuid) is
  'Returns current canonical labels for one current or ended membership final commitment IDs to its participant or Project creator.';
