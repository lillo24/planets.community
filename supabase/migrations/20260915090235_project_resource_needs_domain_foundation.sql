create table public.project_resource_needs (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null
    constraint project_resource_needs_project_id_fkey
      references public.projects (id) on delete restrict,
  title text not null
    constraint project_resource_needs_title_valid check (
      title = btrim(title)
      and char_length(title) between 2 and 160
    ),
  details text
    constraint project_resource_needs_details_valid check (
      details is null
      or (
        details = btrim(details)
        and char_length(details) between 1 and 1000
      )
    ),
  state text not null default 'open'
    constraint project_resource_needs_state_valid check (
      state in ('open', 'closed')
    ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  closed_at timestamptz,
  constraint project_resource_needs_timestamps_valid check (
    updated_at >= created_at
    and (
      (state = 'open' and closed_at is null)
      or (
        state = 'closed'
        and closed_at is not null
        and closed_at between created_at and updated_at
      )
    )
  )
);

comment on table public.project_resource_needs is
  'Stable Project-owned plain-text needs, separate from participation, contribution offers, and standalone Scambio-Dona listings.';
comment on column public.project_resource_needs.state is
  'Open means the Project is still asking; terminal closed means it is no longer asking and does not assert fulfillment, delivery, verification, or credit.';
comment on column public.project_resource_needs.details is
  'Optional plain-text clarification with no parsed taxonomy, quantity, unit, price, priority, or condition semantics.';

create index project_resource_needs_project_created_at_id_idx
  on public.project_resource_needs (project_id, created_at, id);

create index project_resource_needs_open_project_created_at_id_idx
  on public.project_resource_needs (project_id, created_at, id)
  where state = 'open';

create function private.set_project_resource_need_updated_at()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.updated_at := statement_timestamp();
  return new;
end;
$$;

create trigger project_resource_needs_set_updated_at
before update on public.project_resource_needs
for each row
execute function private.set_project_resource_need_updated_at();

alter table public.project_resource_needs enable row level security;

revoke all privileges on table public.project_resource_needs
  from public, anon, authenticated, service_role;

create function private.lock_project_for_resource_need_mutation(
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
  source_is_mutable boolean;
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
      proposal.lifecycle_state = 'draft'
        or (
          proposal.lifecycle_state = 'published'
          and proposal.starts_at is not null
          and statement_timestamp() < proposal.starts_at
        )
    into source_creator_profile_id, source_is_mutable
    from public.proposals as proposal
    where proposal.id = registry.id
    for share;
  elsif registry.project_kind = 'recurring' then
    select
      activity.creator_profile_id,
      activity.lifecycle_state in ('draft', 'published', 'paused')
    into source_creator_profile_id, source_is_mutable
    from public.recurring_activities as activity
    where activity.id = registry.id
    for share;
  end if;

  if not found or source_creator_profile_id <> registry.creator_profile_id then
    raise exception using
      errcode = '55000',
      message = 'The project registry is inconsistent with its concrete activity.';
  end if;

  if source_is_mutable is not true then
    raise exception using
      errcode = '55000',
      message = 'This project can no longer manage resource needs.';
  end if;

  -- Keep the established transition order: concrete Proposal/Tavolo first,
  -- then the shared Project row, before locking a resource-need row.
  select * into registry
  from public.projects as project
  where project.id = p_project_id
  for update;

  return query select registry.project_kind, registry.creator_profile_id;
end;
$$;

create function private.record_project_resource_need_event(
  p_event_type text,
  p_creator_profile_id uuid,
  p_project_id uuid,
  p_project_kind text,
  p_resource_need_id uuid
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
    'resource_need_id', p_resource_need_id,
    'creator_profile_id', p_creator_profile_id
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
    p_event_type,
    p_creator_profile_id,
    'project_resource_need',
    p_resource_need_id,
    identifier_payload
  );

  insert into private.outbox_events (event_type, payload)
  values (p_event_type, identifier_payload);
end;
$$;

create function public.create_project_resource_need(
  p_expected_creator_profile_id uuid,
  p_project_id uuid,
  p_title text,
  p_details text default null
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
  normalized_title text := nullif(btrim(p_title), '');
  normalized_details text := nullif(btrim(p_details), '');
  project_record record;
  new_resource_need_id uuid;
begin
  if normalized_title is null
    or char_length(normalized_title) not between 2 and 160 then
    raise exception using
      errcode = '22023',
      message = 'A Project resource-need title must contain between 2 and 160 characters.';
  end if;

  if normalized_details is not null
    and char_length(normalized_details) > 1000 then
    raise exception using
      errcode = '22023',
      message = 'Project resource-need details must contain at most 1000 characters.';
  end if;

  select * into project_record
  from private.lock_project_for_resource_need_mutation(p_project_id);

  if project_record.creator_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'Only the project creator can manage its resource needs.';
  end if;

  insert into public.project_resource_needs (
    project_id,
    title,
    details
  )
  values (
    p_project_id,
    normalized_title,
    normalized_details
  )
  returning id into new_resource_need_id;

  perform private.record_project_resource_need_event(
    'project.resource_need_created',
    current_profile_id,
    p_project_id,
    project_record.project_kind,
    new_resource_need_id
  );

  return new_resource_need_id;
end;
$$;

create function public.update_project_resource_need(
  p_expected_creator_profile_id uuid,
  p_resource_need_id uuid,
  p_title text,
  p_details text default null
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
  normalized_title text := nullif(btrim(p_title), '');
  normalized_details text := nullif(btrim(p_details), '');
  resource_need public.project_resource_needs%rowtype;
  project_record record;
begin
  if normalized_title is null
    or char_length(normalized_title) not between 2 and 160 then
    raise exception using
      errcode = '22023',
      message = 'A Project resource-need title must contain between 2 and 160 characters.';
  end if;

  if normalized_details is not null
    and char_length(normalized_details) > 1000 then
    raise exception using
      errcode = '22023',
      message = 'Project resource-need details must contain at most 1000 characters.';
  end if;

  select * into resource_need
  from public.project_resource_needs as need
  where need.id = p_resource_need_id;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'The Project resource need does not exist.';
  end if;

  select * into project_record
  from private.lock_project_for_resource_need_mutation(resource_need.project_id);

  select * into resource_need
  from public.project_resource_needs as need
  where need.id = p_resource_need_id
  for update;

  if project_record.creator_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'Only the project creator can manage its resource needs.';
  end if;

  if resource_need.state <> 'open' then
    raise exception using
      errcode = '55000',
      message = 'Only an open Project resource need can be updated.';
  end if;

  update public.project_resource_needs
  set
    title = normalized_title,
    details = normalized_details
  where id = resource_need.id;

  perform private.record_project_resource_need_event(
    'project.resource_need_updated',
    current_profile_id,
    resource_need.project_id,
    project_record.project_kind,
    resource_need.id
  );

  return resource_need.id;
end;
$$;

create function public.close_project_resource_need(
  p_expected_creator_profile_id uuid,
  p_resource_need_id uuid
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
  resource_need public.project_resource_needs%rowtype;
  project_record record;
  transition_time timestamptz := statement_timestamp();
begin
  select * into resource_need
  from public.project_resource_needs as need
  where need.id = p_resource_need_id;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'The Project resource need does not exist.';
  end if;

  select * into project_record
  from private.lock_project_for_resource_need_mutation(resource_need.project_id);

  select * into resource_need
  from public.project_resource_needs as need
  where need.id = p_resource_need_id
  for update;

  if project_record.creator_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'Only the project creator can manage its resource needs.';
  end if;

  if resource_need.state <> 'open' then
    raise exception using
      errcode = '55000',
      message = 'Only an open Project resource need can be closed.';
  end if;

  update public.project_resource_needs
  set
    state = 'closed',
    closed_at = transition_time
  where id = resource_need.id;

  perform private.record_project_resource_need_event(
    'project.resource_need_closed',
    current_profile_id,
    resource_need.project_id,
    project_record.project_kind,
    resource_need.id
  );

  return resource_need.id;
end;
$$;

create function public.list_own_project_resource_needs(
  p_expected_creator_profile_id uuid,
  p_project_id uuid
)
returns table (
  resource_need_id uuid,
  project_id uuid,
  project_kind text,
  title text,
  details text,
  state text,
  created_at timestamptz,
  updated_at timestamptz,
  closed_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_project_creator(
    p_expected_creator_profile_id,
    p_project_id
  );
begin
  return query
  select
    need.id,
    need.project_id,
    project.project_kind,
    need.title,
    need.details,
    need.state,
    need.created_at,
    need.updated_at,
    need.closed_at
  from public.project_resource_needs as need
  join public.projects as project on project.id = need.project_id
  where need.project_id = p_project_id
    and project.creator_profile_id = current_profile_id
  order by need.created_at, need.id;
end;
$$;

create function public.list_public_project_resource_needs(
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

comment on function private.lock_project_for_resource_need_mutation(uuid) is
  'Serializes resource-need mutations concrete-row first and shared-Project second, rejecting Proposal/Tavolo terminal owner-immutable states.';
comment on function private.record_project_resource_need_event(text, uuid, uuid, text, uuid) is
  'Writes one identifier-only audit/outbox pair for a Project resource-need transition.';
comment on function public.create_project_resource_need(uuid, uuid, text, text) is
  'Creates one stable open plain-text need for an expected-identity-bound Project creator while the concrete Project remains owner-mutable.';
comment on function public.update_project_resource_need(uuid, uuid, text, text) is
  'Updates one open Project need without changing its stable identity or introducing contribution semantics.';
comment on function public.close_project_resource_need(uuid, uuid) is
  'Terminally closes one Project need without asserting fulfillment, delivery, verification, or credit.';
comment on function public.list_own_project_resource_needs(uuid, uuid) is
  'Returns the expected creator complete open/closed need history in stable creation order, including for historical Projects.';
comment on function public.list_public_project_resource_needs(uuid) is
  'Returns only open needs for a currently joinable Proposal/Tavolo, with unavailable Projects producing an empty non-enumerating result.';

revoke all privileges on function private.set_project_resource_need_updated_at()
  from public, anon, authenticated, service_role;
revoke all privileges on function private.lock_project_for_resource_need_mutation(uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function private.record_project_resource_need_event(text, uuid, uuid, text, uuid)
  from public, anon, authenticated, service_role;

revoke all privileges on function public.create_project_resource_need(uuid, uuid, text, text)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.update_project_resource_need(uuid, uuid, text, text)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.close_project_resource_need(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.list_own_project_resource_needs(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.list_public_project_resource_needs(uuid)
  from public, anon, authenticated, service_role;

grant execute on function public.create_project_resource_need(uuid, uuid, text, text)
  to authenticated;
grant execute on function public.update_project_resource_need(uuid, uuid, text, text)
  to authenticated;
grant execute on function public.close_project_resource_need(uuid, uuid)
  to authenticated;
grant execute on function public.list_own_project_resource_needs(uuid, uuid)
  to authenticated;
grant execute on function public.list_public_project_resource_needs(uuid)
  to anon, authenticated;
