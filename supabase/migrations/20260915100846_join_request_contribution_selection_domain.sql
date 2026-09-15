create table public.project_join_request_skill_selections (
  request_id uuid not null
    constraint project_join_request_skill_selections_request_id_fkey
      references public.project_join_requests (id) on delete restrict,
  skill_id uuid not null
    constraint project_join_request_skill_selections_skill_id_fkey
      references public.skills (id) on delete restrict,
  selected_at timestamptz not null default now(),
  primary key (request_id, skill_id)
);

comment on table public.project_join_request_skill_selections is
  'Immutable historical skill selections made for one Project join-request attempt; labels remain canonical in the skill catalog.';

create index project_join_request_skill_selections_skill_request_idx
  on public.project_join_request_skill_selections (skill_id, request_id);

create table public.project_join_request_resource_selections (
  request_id uuid not null
    constraint project_join_request_resource_selections_request_id_fkey
      references public.project_join_requests (id) on delete restrict,
  resource_need_id uuid not null
    constraint project_join_request_resource_selections_need_id_fkey
      references public.project_resource_needs (id) on delete restrict,
  selected_at timestamptz not null default now(),
  primary key (request_id, resource_need_id)
);

comment on table public.project_join_request_resource_selections is
  'Immutable historical resource-need selections made for one Project join-request attempt; current need titles resolve by stable ID.';

create index project_join_request_resource_selections_need_request_idx
  on public.project_join_request_resource_selections (resource_need_id, request_id);

alter table public.project_join_request_skill_selections enable row level security;
alter table public.project_join_request_resource_selections enable row level security;

revoke all privileges on table public.project_join_request_skill_selections
  from public, anon, authenticated, service_role;
revoke all privileges on table public.project_join_request_resource_selections
  from public, anon, authenticated, service_role;

drop function public.request_to_join_project(uuid, uuid, text);

create function public.request_to_join_project(
  p_expected_requester_profile_id uuid,
  p_project_id uuid,
  p_request_message text default null,
  p_skill_ids uuid[] default '{}'::uuid[],
  p_resource_need_ids uuid[] default '{}'::uuid[]
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_complete_participation_profile(
    p_expected_requester_profile_id
  );
  project_record record;
  normalized_message text := nullif(btrim(p_request_message), '');
  normalized_skill_ids uuid[] := coalesce(p_skill_ids, '{}'::uuid[]);
  normalized_resource_need_ids uuid[] := coalesce(
    p_resource_need_ids,
    '{}'::uuid[]
  );
  locked_resource_need record;
  locked_resource_need_count integer := 0;
  new_request_id uuid;
begin
  if normalized_message is not null and char_length(normalized_message) > 500 then
    raise exception using
      errcode = '22023',
      message = 'A participation request message must contain at most 500 characters.';
  end if;

  if cardinality(normalized_skill_ids) > 50 then
    raise exception using
      errcode = '22023',
      message = 'A participation request may select at most 50 Project skills.';
  end if;

  if cardinality(normalized_resource_need_ids) > 50 then
    raise exception using
      errcode = '22023',
      message = 'A participation request may select at most 50 Project resource needs.';
  end if;

  if exists (
    select 1
    from unnest(normalized_skill_ids) as selected(skill_id)
    where selected.skill_id is null
  ) then
    raise exception using
      errcode = '22023',
      message = 'Project skill selections cannot contain null identifiers.';
  end if;

  if exists (
    select 1
    from unnest(normalized_resource_need_ids) as selected(resource_need_id)
    where selected.resource_need_id is null
  ) then
    raise exception using
      errcode = '22023',
      message = 'Project resource selections cannot contain null identifiers.';
  end if;

  if cardinality(normalized_skill_ids) <> (
    select count(distinct selected.skill_id)
    from unnest(normalized_skill_ids) as selected(skill_id)
  ) then
    raise exception using
      errcode = '22023',
      message = 'Project skill selections cannot contain duplicate identifiers.';
  end if;

  if cardinality(normalized_resource_need_ids) <> (
    select count(distinct selected.resource_need_id)
    from unnest(normalized_resource_need_ids) as selected(resource_need_id)
  ) then
    raise exception using
      errcode = '22023',
      message = 'Project resource selections cannot contain duplicate identifiers.';
  end if;

  select * into project_record
  from private.lock_project_for_participation(p_project_id, true);

  if project_record.creator_profile_id = current_profile_id then
    raise exception using
      errcode = '55000',
      message = 'A project creator cannot request to join their own project.';
  end if;

  if exists (
    select 1
    from public.project_memberships as membership
    where membership.project_id = p_project_id
      and membership.participant_profile_id = current_profile_id
      and membership.left_at is null
      and membership.removed_at is null
  ) then
    raise exception using
      errcode = '55000',
      message = 'The requester is already a current project participant.';
  end if;

  if exists (
    select 1
    from public.project_join_requests as request
    where request.project_id = p_project_id
      and request.requester_profile_id = current_profile_id
      and request.status = 'pending'
  ) then
    raise exception using
      errcode = '55000',
      message = 'The requester already has a pending request for this project.';
  end if;

  if project_record.project_kind = 'recurring'
    and cardinality(normalized_skill_ids) > 0 then
    raise exception using
      errcode = '22023',
      message = 'Recurring Projects do not currently define selectable skill requirements.';
  end if;

  if project_record.project_kind = 'one_time'
    and exists (
      select 1
      from unnest(normalized_skill_ids) as selected(skill_id)
      left join public.proposal_skills as requested_skill
        on requested_skill.proposal_id = p_project_id
        and requested_skill.skill_id = selected.skill_id
      where requested_skill.skill_id is null
    ) then
    raise exception using
      errcode = '22023',
      message = 'Every selected skill must be a current requirement of this Proposal.';
  end if;

  -- The participation helper already holds concrete Project then shared Project.
  -- Lock resource rows in UUID order after those anchors so 04C3A update/close
  -- operations serialize without reversing the established lock hierarchy.
  for locked_resource_need in
    select need.id, need.project_id, need.state
    from public.project_resource_needs as need
    where need.id = any(normalized_resource_need_ids)
    order by need.id
    for share
  loop
    locked_resource_need_count := locked_resource_need_count + 1;

    if locked_resource_need.project_id <> p_project_id
      or locked_resource_need.state <> 'open' then
      raise exception using
        errcode = '22023',
        message = 'Every selected resource need must be open and belong to this Project.';
    end if;
  end loop;

  if locked_resource_need_count <> cardinality(normalized_resource_need_ids) then
    raise exception using
      errcode = '22023',
      message = 'Every selected resource need must be open and belong to this Project.';
  end if;

  insert into public.project_join_requests (
    project_id,
    requester_profile_id,
    request_message
  )
  values (p_project_id, current_profile_id, normalized_message)
  returning id into new_request_id;

  insert into public.project_join_request_skill_selections (
    request_id,
    skill_id
  )
  select new_request_id, selected.skill_id
  from unnest(normalized_skill_ids) as selected(skill_id);

  insert into public.project_join_request_resource_selections (
    request_id,
    resource_need_id
  )
  select new_request_id, selected.resource_need_id
  from unnest(normalized_resource_need_ids) as selected(resource_need_id);

  perform private.record_project_participation_event(
    'project.join_requested',
    current_profile_id,
    p_project_id,
    jsonb_build_object(
      'project_kind', project_record.project_kind,
      'request_id', new_request_id,
      'requester_profile_id', current_profile_id,
      'status', 'pending'
    )
  );

  return new_request_id;
end;
$$;

create function public.list_own_project_join_request_contribution_selections(
  p_expected_profile_id uuid,
  p_request_id uuid
)
returns table (
  selection_kind text,
  selection_id uuid,
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
  request_record public.project_join_requests%rowtype;
  project_creator_profile_id uuid;
begin
  select * into request_record
  from public.project_join_requests as request
  where request.id = p_request_id;

  if not found then
    raise exception using
      errcode = '42501',
      message = 'The participation request contribution selections are unavailable.';
  end if;

  select project.creator_profile_id into project_creator_profile_id
  from public.projects as project
  where project.id = request_record.project_id;

  if request_record.requester_profile_id <> current_profile_id
    and project_creator_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'The participation request contribution selections are unavailable.';
  end if;

  return query
  with ordered_selections as (
    select
      'skill'::text as resolved_kind,
      selected_skill.skill_id as resolved_id,
      skill.label as resolved_label,
      0::smallint as kind_order,
      category.sort_order as category_order,
      skill.sort_order as item_order,
      null::timestamptz as resource_created_at
    from public.project_join_request_skill_selections as selected_skill
    join public.skills as skill on skill.id = selected_skill.skill_id
    join public.skill_categories as category on category.id = skill.category_id
    where selected_skill.request_id = p_request_id

    union all

    select
      'resource'::text,
      selected_resource.resource_need_id,
      resource_need.title,
      1::smallint,
      0::smallint,
      0::smallint,
      resource_need.created_at
    from public.project_join_request_resource_selections as selected_resource
    join public.project_resource_needs as resource_need
      on resource_need.id = selected_resource.resource_need_id
    where selected_resource.request_id = p_request_id
  )
  select
    ordered.resolved_kind,
    ordered.resolved_id,
    ordered.resolved_label
  from ordered_selections as ordered
  order by
    ordered.kind_order,
    ordered.category_order,
    ordered.item_order,
    ordered.resource_created_at,
    ordered.resolved_id;
end;
$$;

revoke all privileges on function public.request_to_join_project(
  uuid,
  uuid,
  text,
  uuid[],
  uuid[]
) from public, anon, authenticated, service_role;
revoke all privileges on function
  public.list_own_project_join_request_contribution_selections(uuid, uuid)
  from public, anon, authenticated, service_role;

grant execute on function public.request_to_join_project(
  uuid,
  uuid,
  text,
  uuid[],
  uuid[]
) to authenticated;
grant execute on function
  public.list_own_project_join_request_contribution_selections(uuid, uuid)
  to authenticated;

comment on function public.request_to_join_project(
  uuid,
  uuid,
  text,
  uuid[],
  uuid[]
) is
  'Atomically creates one private pending join request with optional canonical Proposal-skill and open Project-resource selections; trailing defaults preserve earlier callers.';
comment on function
  public.list_own_project_join_request_contribution_selections(uuid, uuid)
is
  'Returns current canonical labels for one request historical ID selections to its requester or Project creator only.';
