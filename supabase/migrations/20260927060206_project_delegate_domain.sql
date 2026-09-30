alter table public.projects
  add constraint projects_id_creator_unique
  unique (id, creator_profile_id);

create table public.project_delegate_invitations (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null,
  owner_profile_id uuid not null,
  token_digest bytea not null unique,
  status text not null default 'pending'
    constraint project_delegate_invitations_status_valid check (
      status in ('pending', 'accepted', 'revoked')
    ),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  accepted_at timestamptz,
  accepted_by_profile_id uuid
    constraint project_delegate_invitations_accepted_by_profile_id_fkey
      references public.profiles (id) on delete restrict,
  revoked_at timestamptz,
  revoked_by_profile_id uuid
    constraint project_delegate_invitations_revoked_by_profile_id_fkey
      references public.profiles (id) on delete restrict,
  constraint project_delegate_invitations_project_owner_fkey
    foreign key (project_id, owner_profile_id)
      references public.projects (id, creator_profile_id) on delete restrict,
  constraint project_delegate_invitations_expiry_valid check (
    expires_at = created_at + interval '7 days'
  ),
  constraint project_delegate_invitations_resolution_valid check (
    (
      status = 'pending'
      and accepted_at is null
      and accepted_by_profile_id is null
      and revoked_at is null
      and revoked_by_profile_id is null
    )
    or (
      status = 'accepted'
      and accepted_at is not null
      and accepted_by_profile_id is not null
      and accepted_at >= created_at
      and revoked_at is null
      and revoked_by_profile_id is null
    )
    or (
      status = 'revoked'
      and accepted_at is null
      and accepted_by_profile_id is null
      and revoked_at is not null
      and revoked_by_profile_id = owner_profile_id
      and revoked_at >= created_at
    )
  ),
  constraint project_delegate_invitations_owner_not_accepter check (
    accepted_by_profile_id is null
    or accepted_by_profile_id <> owner_profile_id
  )
);

comment on table public.project_delegate_invitations is
  'Owner-created, seven-day, single-use Project delegate invitations. Only a SHA-256 digest of the bearer token is retained.';
comment on column public.project_delegate_invitations.token_digest is
  'SHA-256 digest of the 256-bit base64url bearer token; reusable plaintext is returned only by the creation RPC and is never persisted.';

create index project_delegate_invitations_project_created_idx
  on public.project_delegate_invitations (project_id, created_at desc, id);
create index project_delegate_invitations_owner_created_idx
  on public.project_delegate_invitations (
    owner_profile_id,
    created_at desc,
    id
  );
create index project_delegate_invitations_project_owner_idx
  on public.project_delegate_invitations (project_id, owner_profile_id);
create index project_delegate_invitations_accepted_by_profile_id_idx
  on public.project_delegate_invitations (accepted_by_profile_id)
  where accepted_by_profile_id is not null;
create index project_delegate_invitations_revoked_by_profile_id_idx
  on public.project_delegate_invitations (revoked_by_profile_id)
  where revoked_by_profile_id is not null;
create index project_delegate_invitations_pending_expiry_idx
  on public.project_delegate_invitations (expires_at, id)
  where status = 'pending';

create table public.project_delegates (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null,
  owner_profile_id uuid not null,
  delegate_profile_id uuid not null
    constraint project_delegates_delegate_profile_id_fkey
      references public.profiles (id) on delete restrict,
  invitation_id uuid not null unique
    constraint project_delegates_invitation_id_fkey
      references public.project_delegate_invitations (id) on delete restrict,
  delegated_at timestamptz not null,
  revoked_at timestamptz,
  revoked_by_profile_id uuid
    constraint project_delegates_revoked_by_profile_id_fkey
      references public.profiles (id) on delete restrict,
  constraint project_delegates_project_owner_fkey
    foreign key (project_id, owner_profile_id)
      references public.projects (id, creator_profile_id) on delete restrict,
  constraint project_delegates_owner_not_delegate check (
    owner_profile_id <> delegate_profile_id
  ),
  constraint project_delegates_revocation_valid check (
    (
      revoked_at is null
      and revoked_by_profile_id is null
    )
    or (
      revoked_at is not null
      and revoked_by_profile_id = owner_profile_id
      and revoked_at >= delegated_at
    )
  ),
  constraint project_delegates_identity_unique
    unique (id, project_id, delegate_profile_id)
);

comment on table public.project_delegates is
  'Append-preserving Project co-organizer history. Active rows authorize operational management without creating a participant membership.';

create unique index project_delegates_one_active_profile_idx
  on public.project_delegates (project_id, delegate_profile_id)
  where revoked_at is null;
create index project_delegates_project_delegated_idx
  on public.project_delegates (project_id, delegated_at desc, id);
create index project_delegates_profile_delegated_idx
  on public.project_delegates (
    delegate_profile_id,
    delegated_at desc,
    id
  );
create index project_delegates_project_owner_idx
  on public.project_delegates (project_id, owner_profile_id);
create index project_delegates_revoked_by_profile_id_idx
  on public.project_delegates (revoked_by_profile_id)
  where revoked_by_profile_id is not null;

alter table public.project_delegate_invitations enable row level security;
alter table public.project_delegates enable row level security;

revoke all privileges on table public.project_delegate_invitations
  from public, anon, authenticated, service_role;
revoke all privileges on table public.project_delegates
  from public, anon, authenticated, service_role;

create function private.validate_project_delegate_relationship()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  invitation_record public.project_delegate_invitations%rowtype;
begin
  select * into invitation_record
  from public.project_delegate_invitations as invitation
  where invitation.id = new.invitation_id;

  if not found
    or invitation_record.status <> 'accepted'
    or invitation_record.project_id <> new.project_id
    or invitation_record.owner_profile_id <> new.owner_profile_id
    or invitation_record.accepted_by_profile_id <> new.delegate_profile_id
    or invitation_record.accepted_at <> new.delegated_at then
    raise exception using
      errcode = '23514',
      message = 'A Project delegate relationship must match its accepted invitation.';
  end if;

  return new;
end;
$$;

create trigger project_delegates_validate_invitation
before insert or update of project_id, owner_profile_id, delegate_profile_id,
  invitation_id, delegated_at
on public.project_delegates
for each row execute function private.validate_project_delegate_relationship();

create function private.profile_is_project_manager(
  p_project_id uuid,
  p_profile_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_profile_id is not null and exists (
    select 1
    from public.projects as project
    where project.id = p_project_id
      and (
        project.creator_profile_id = p_profile_id
        or exists (
          select 1
          from public.project_delegates as delegate
          where delegate.project_id = project.id
            and delegate.delegate_profile_id = p_profile_id
            and delegate.revoked_at is null
        )
      )
  );
$$;

create function private.require_project_manager(
  p_expected_manager_profile_id uuid,
  p_project_id uuid
)
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_participation_identity(
    p_expected_manager_profile_id
  );
begin
  if not private.profile_is_project_manager(
    p_project_id,
    current_profile_id
  ) then
    raise exception using
      errcode = '42501',
      message = 'Only a current Project manager can perform this operation.';
  end if;

  return current_profile_id;
end;
$$;

create function private.project_allows_delegate_collaboration(
  p_project_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  registry public.projects%rowtype;
begin
  select * into registry
  from public.projects as project
  where project.id = p_project_id;

  if not found then
    return false;
  end if;

  if registry.project_kind = 'one_time' then
    return exists (
      select 1
      from public.proposals as proposal
      where proposal.id = registry.id
        and proposal.creator_profile_id = registry.creator_profile_id
        and proposal.lifecycle_state = 'published'
        and proposal.ends_at is not null
        and statement_timestamp() < proposal.ends_at
    );
  end if;

  return exists (
    select 1
    from public.recurring_activities as activity
    where activity.id = registry.id
      and activity.creator_profile_id = registry.creator_profile_id
      and activity.lifecycle_state in ('published', 'paused')
  );
end;
$$;

create function private.lock_project_for_delegate_management(
  p_project_id uuid,
  p_require_operational boolean
)
returns table (project_kind text, owner_profile_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
declare
  registry public.projects%rowtype;
  source_owner_profile_id uuid;
  source_is_operational boolean;
begin
  select * into registry
  from public.projects as project
  where project.id = p_project_id;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'The Project does not exist.';
  end if;

  if registry.project_kind = 'one_time' then
    select
      proposal.creator_profile_id,
      proposal.lifecycle_state = 'published'
        and proposal.ends_at is not null
        and statement_timestamp() < proposal.ends_at
    into source_owner_profile_id, source_is_operational
    from public.proposals as proposal
    where proposal.id = registry.id
    for share;
  else
    select
      activity.creator_profile_id,
      activity.lifecycle_state in ('published', 'paused')
    into source_owner_profile_id, source_is_operational
    from public.recurring_activities as activity
    where activity.id = registry.id
    for share;
  end if;

  if not found or source_owner_profile_id <> registry.creator_profile_id then
    raise exception using
      errcode = '55000',
      message = 'The Project registry is inconsistent with its concrete activity.';
  end if;

  if p_require_operational and source_is_operational is not true then
    raise exception using
      errcode = '55000',
      message = 'Delegate collaboration is unavailable for this Project lifecycle.';
  end if;

  select * into registry
  from public.projects as project
  where project.id = p_project_id
  for update;

  return query
  select registry.project_kind, registry.creator_profile_id;
end;
$$;

create function private.record_project_delegate_event(
  p_event_type text,
  p_actor_profile_id uuid,
  p_project_id uuid,
  p_project_kind text,
  p_invitation_id uuid default null,
  p_delegate_id uuid default null,
  p_delegate_profile_id uuid default null
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
    'invitation_id', p_invitation_id,
    'delegate_id', p_delegate_id,
    'delegate_profile_id', p_delegate_profile_id,
    'actor_profile_id', p_actor_profile_id
  ));
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
    p_actor_profile_id,
    'project',
    p_project_id,
    identifier_payload
  );

  insert into private.outbox_events (event_type, payload)
  values (p_event_type, identifier_payload);
end;
$$;

create function public.create_project_delegate_invitation(
  p_expected_owner_profile_id uuid,
  p_project_id uuid
)
returns table (
  invitation_id uuid,
  invite_token text,
  expires_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_participation_identity(
    p_expected_owner_profile_id
  );
  project_record record;
  raw_token text;
  canonical_created_at timestamptz := statement_timestamp();
  inserted_invitation public.project_delegate_invitations%rowtype;
begin
  select * into project_record
  from private.lock_project_for_delegate_management(p_project_id, true);

  if project_record.owner_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'Only the Project owner can create delegate invitations.';
  end if;

  raw_token := translate(
    rtrim(encode(extensions.gen_random_bytes(32), 'base64'), '='),
    '+/',
    '-_'
  );

  insert into public.project_delegate_invitations (
    project_id,
    owner_profile_id,
    token_digest,
    created_at,
    expires_at
  )
  values (
    p_project_id,
    current_profile_id,
    extensions.digest(raw_token, 'sha256'),
    canonical_created_at,
    canonical_created_at + interval '7 days'
  )
  returning * into inserted_invitation;

  perform private.record_project_delegate_event(
    'project.delegate_invite_created',
    current_profile_id,
    p_project_id,
    project_record.project_kind,
    inserted_invitation.id
  );

  return query
  select
    inserted_invitation.id,
    raw_token,
    inserted_invitation.expires_at;
end;
$$;

create function public.revoke_project_delegate_invitation(
  p_expected_owner_profile_id uuid,
  p_invitation_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_participation_identity(
    p_expected_owner_profile_id
  );
  invitation_record public.project_delegate_invitations%rowtype;
  project_record record;
  canonical_revoked_at timestamptz := statement_timestamp();
begin
  select * into invitation_record
  from public.project_delegate_invitations as invitation
  where invitation.id = p_invitation_id;

  if not found then
    raise exception using
      errcode = '42501',
      message = 'The delegate invitation is unavailable.';
  end if;

  select * into project_record
  from private.lock_project_for_delegate_management(
    invitation_record.project_id,
    false
  );

  select * into invitation_record
  from public.project_delegate_invitations as invitation
  where invitation.id = p_invitation_id
  for update;

  if not found
    or invitation_record.owner_profile_id <> current_profile_id
    or project_record.owner_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'The delegate invitation is unavailable.';
  end if;

  if invitation_record.status = 'revoked' then
    return invitation_record.id;
  end if;

  if invitation_record.status <> 'pending' then
    raise sqlstate 'PT409'
      using message = 'Only a pending delegate invitation can be revoked.';
  end if;

  update public.project_delegate_invitations
  set
    status = 'revoked',
    revoked_at = canonical_revoked_at,
    revoked_by_profile_id = current_profile_id
  where id = invitation_record.id;

  perform private.record_project_delegate_event(
    'project.delegate_invite_revoked',
    current_profile_id,
    invitation_record.project_id,
    project_record.project_kind,
    invitation_record.id
  );

  return invitation_record.id;
end;
$$;

create function public.preview_project_delegate_invitation(p_token text)
returns table (
  is_available boolean,
  project_id uuid,
  project_kind text,
  project_title text,
  owner_display_name text,
  expires_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  invitation_record public.project_delegate_invitations%rowtype;
begin
  if p_token is null or p_token !~ '^[A-Za-z0-9_-]{43}$' then
    return query
    select false, null::uuid, null::text, null::text, null::text,
      null::timestamptz;
    return;
  end if;

  select * into invitation_record
  from public.project_delegate_invitations as invitation
  where invitation.token_digest = extensions.digest(p_token, 'sha256')
    and invitation.status = 'pending'
    and statement_timestamp() < invitation.expires_at
    and private.project_allows_delegate_collaboration(invitation.project_id);

  if not found then
    return query
    select false, null::uuid, null::text, null::text, null::text,
      null::timestamptz;
    return;
  end if;

  return query
  select
    true,
    project.id,
    project.project_kind,
    case project.project_kind
      when 'one_time' then proposal.title
      when 'recurring' then activity.title
    end,
    case when visibility.audience = 'public' then owner.display_name end,
    invitation_record.expires_at
  from public.projects as project
  join public.profiles as owner on owner.id = project.creator_profile_id
  left join public.profile_field_visibility as visibility
    on visibility.profile_id = owner.id
    and visibility.field_key = 'display_name'
  left join public.proposals as proposal
    on proposal.id = project.id
    and project.project_kind = 'one_time'
  left join public.recurring_activities as activity
    on activity.id = project.id
    and project.project_kind = 'recurring'
  where project.id = invitation_record.project_id;
end;
$$;

create function public.accept_project_delegate_invitation(
  p_expected_delegate_profile_id uuid,
  p_token text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_complete_participation_profile(
    p_expected_delegate_profile_id
  );
  invitation_project_id uuid;
  invitation_record public.project_delegate_invitations%rowtype;
  project_record record;
  canonical_accepted_at timestamptz := statement_timestamp();
  delegate_id uuid;
begin
  if p_token is null or p_token !~ '^[A-Za-z0-9_-]{43}$' then
    raise exception using
      errcode = '42501',
      message = 'The delegate invitation is unavailable.';
  end if;

  select invitation.project_id into invitation_project_id
  from public.project_delegate_invitations as invitation
  where invitation.token_digest = extensions.digest(p_token, 'sha256');

  if not found then
    raise exception using
      errcode = '42501',
      message = 'The delegate invitation is unavailable.';
  end if;

  select * into project_record
  from private.lock_project_for_delegate_management(
    invitation_project_id,
    true
  );

  select * into invitation_record
  from public.project_delegate_invitations as invitation
  where invitation.token_digest = extensions.digest(p_token, 'sha256')
  for update;

  if not found or invitation_record.project_id <> invitation_project_id then
    raise exception using
      errcode = '42501',
      message = 'The delegate invitation is unavailable.';
  end if;

  if invitation_record.status = 'accepted' then
    if invitation_record.accepted_by_profile_id <> current_profile_id then
      raise exception using
        errcode = '42501',
        message = 'The delegate invitation is unavailable.';
    end if;

    select delegate.id into delegate_id
    from public.project_delegates as delegate
    where delegate.invitation_id = invitation_record.id
      and delegate.delegate_profile_id = current_profile_id;

    if delegate_id is null then
      raise exception using
        errcode = '55000',
        message = 'The accepted delegate invitation has no matching relationship.';
    end if;

    return delegate_id;
  end if;

  if invitation_record.status <> 'pending'
    or statement_timestamp() >= invitation_record.expires_at
    or invitation_record.owner_profile_id <> project_record.owner_profile_id then
    raise exception using
      errcode = '42501',
      message = 'The delegate invitation is unavailable.';
  end if;

  if invitation_record.owner_profile_id = current_profile_id then
    raise exception using
      errcode = '55000',
      message = 'A Project owner cannot accept their own delegate invitation.';
  end if;

  if exists (
    select 1
    from public.project_delegates as delegate
    where delegate.project_id = invitation_record.project_id
      and delegate.delegate_profile_id = current_profile_id
      and delegate.revoked_at is null
  ) then
    raise exception using
      errcode = '55000',
      message = 'This profile is already an active delegate for the Project.';
  end if;

  update public.project_delegate_invitations
  set
    status = 'accepted',
    accepted_at = canonical_accepted_at,
    accepted_by_profile_id = current_profile_id
  where id = invitation_record.id;

  insert into public.project_delegates (
    project_id,
    owner_profile_id,
    delegate_profile_id,
    invitation_id,
    delegated_at
  )
  values (
    invitation_record.project_id,
    invitation_record.owner_profile_id,
    current_profile_id,
    invitation_record.id,
    canonical_accepted_at
  )
  returning id into delegate_id;

  perform private.record_project_delegate_event(
    'project.delegate_added',
    current_profile_id,
    invitation_record.project_id,
    project_record.project_kind,
    invitation_record.id,
    delegate_id,
    current_profile_id
  );

  return delegate_id;
end;
$$;

create function public.list_project_delegates_for_owner(
  p_expected_owner_profile_id uuid,
  p_project_id uuid
)
returns table (
  delegate_id uuid,
  delegate_profile_id uuid,
  delegate_display_name text,
  delegated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform private.require_project_creator(
    p_expected_owner_profile_id,
    p_project_id
  );

  return query
  select
    delegate.id,
    delegate.delegate_profile_id,
    profile.display_name,
    delegate.delegated_at
  from public.project_delegates as delegate
  join public.profiles as profile on profile.id = delegate.delegate_profile_id
  where delegate.project_id = p_project_id
    and delegate.revoked_at is null
  order by delegate.delegated_at, delegate.id;
end;
$$;

create function public.list_project_delegate_invitations_for_owner(
  p_expected_owner_profile_id uuid,
  p_project_id uuid
)
returns table (
  invitation_id uuid,
  status text,
  created_at timestamptz,
  expires_at timestamptz,
  accepted_at timestamptz,
  revoked_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform private.require_project_creator(
    p_expected_owner_profile_id,
    p_project_id
  );

  return query
  select
    invitation.id,
    invitation.status,
    invitation.created_at,
    invitation.expires_at,
    invitation.accepted_at,
    invitation.revoked_at
  from public.project_delegate_invitations as invitation
  where invitation.project_id = p_project_id
  order by invitation.created_at desc, invitation.id desc;
end;
$$;

create function public.revoke_project_delegate(
  p_expected_owner_profile_id uuid,
  p_delegate_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_participation_identity(
    p_expected_owner_profile_id
  );
  delegate_record public.project_delegates%rowtype;
  project_record record;
  canonical_revoked_at timestamptz := statement_timestamp();
begin
  select * into delegate_record
  from public.project_delegates as delegate
  where delegate.id = p_delegate_id;

  if not found then
    raise exception using
      errcode = '42501',
      message = 'The Project delegate is unavailable.';
  end if;

  select * into project_record
  from private.lock_project_for_delegate_management(
    delegate_record.project_id,
    false
  );

  select * into delegate_record
  from public.project_delegates as delegate
  where delegate.id = p_delegate_id
  for update;

  if not found
    or delegate_record.owner_profile_id <> current_profile_id
    or project_record.owner_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'The Project delegate is unavailable.';
  end if;

  if delegate_record.revoked_at is not null then
    return delegate_record.id;
  end if;

  update public.project_delegates
  set
    revoked_at = canonical_revoked_at,
    revoked_by_profile_id = current_profile_id
  where id = delegate_record.id;

  perform private.record_project_delegate_event(
    'project.delegate_revoked',
    current_profile_id,
    delegate_record.project_id,
    project_record.project_kind,
    delegate_record.invitation_id,
    delegate_record.id,
    delegate_record.delegate_profile_id
  );

  return delegate_record.id;
end;
$$;

create function public.accept_project_join_request_as_manager(
  p_expected_manager_profile_id uuid,
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
    p_expected_manager_profile_id
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

  if not private.profile_is_project_manager(
    request_record.project_id,
    current_profile_id
  ) then
    raise exception using
      errcode = '42501',
      message = 'Only a current Project manager can accept join requests.';
  end if;

  if request_record.status <> 'pending' then
    raise exception using
      errcode = '55000',
      message = 'Only a pending join request can be accepted.';
  end if;

  if request_record.requester_profile_id = project_record.creator_profile_id then
    raise exception using
      errcode = '55000',
      message = 'A Project owner cannot become a participant through a join request.';
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
      message = 'The requester is already a current Project participant.';
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

create function public.accept_project_join_request_as_manager(
  p_expected_manager_profile_id uuid,
  p_request_id uuid
)
returns uuid
language sql
security definer
set search_path = ''
as $$
  select public.accept_project_join_request_as_manager(
    p_expected_manager_profile_id,
    p_request_id,
    '{}'::uuid[],
    '{}'::uuid[],
    '{}'::uuid[],
    '{}'::uuid[],
    '{}'::uuid[],
    '{}'::uuid[]
  );
$$;

create or replace function public.accept_project_join_request(
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

create function public.reject_project_join_request_as_manager(
  p_expected_manager_profile_id uuid,
  p_request_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_participation_identity(
    p_expected_manager_profile_id
  );
  request_record public.project_join_requests%rowtype;
  project_record record;
  transition_time timestamptz := statement_timestamp();
begin
  select * into request_record
  from public.project_join_requests as request
  where request.id = p_request_id;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'The join request does not exist.';
  end if;

  select * into project_record
  from private.lock_project_for_participation(request_record.project_id, false);

  select * into request_record
  from public.project_join_requests as request
  where request.id = p_request_id
  for update;

  if not private.profile_is_project_manager(
    request_record.project_id,
    current_profile_id
  ) then
    raise exception using
      errcode = '42501',
      message = 'Only a current Project manager can reject join requests.';
  end if;

  if request_record.status <> 'pending' then
    raise exception using
      errcode = '55000',
      message = 'Only a pending join request can be rejected.';
  end if;

  update public.project_join_requests
  set
    status = 'rejected',
    resolved_at = transition_time,
    resolved_by_profile_id = current_profile_id
  where id = request_record.id;

  perform private.record_project_participation_event(
    'project.join_request_rejected',
    current_profile_id,
    request_record.project_id,
    jsonb_build_object(
      'project_kind', project_record.project_kind,
      'request_id', request_record.id,
      'requester_profile_id', request_record.requester_profile_id,
      'status', 'rejected'
    )
  );

  return request_record.id;
end;
$$;

create function public.remove_project_member_as_manager(
  p_expected_manager_profile_id uuid,
  p_membership_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_participation_identity(
    p_expected_manager_profile_id
  );
  membership_record public.project_memberships%rowtype;
  project_record record;
  transition_time timestamptz := statement_timestamp();
begin
  select * into membership_record
  from public.project_memberships as membership
  where membership.id = p_membership_id;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'The membership does not exist.';
  end if;

  select * into project_record
  from private.lock_project_for_participation(
    membership_record.project_id,
    false
  );

  select * into membership_record
  from public.project_memberships as membership
  where membership.id = p_membership_id
  for update;

  if not private.profile_is_project_manager(
    membership_record.project_id,
    current_profile_id
  ) then
    raise exception using
      errcode = '42501',
      message = 'Only a current Project manager can remove a participant.';
  end if;

  if membership_record.left_at is not null
    or membership_record.removed_at is not null then
    raise exception using
      errcode = '55000',
      message = 'Only a current Project membership can be removed.';
  end if;

  update public.project_memberships
  set
    removed_at = transition_time,
    removed_by_profile_id = current_profile_id
  where id = membership_record.id;

  perform private.record_project_participation_event(
    'project.participant_removed',
    current_profile_id,
    membership_record.project_id,
    jsonb_build_object(
      'project_kind', project_record.project_kind,
      'membership_id', membership_record.id,
      'participant_profile_id', membership_record.participant_profile_id,
      'status', 'removed'
    )
  );

  return membership_record.id;
end;
$$;

create function public.list_project_join_requests_for_manager(
  p_expected_manager_profile_id uuid,
  p_project_id uuid
)
returns table (
  request_id uuid,
  requester_profile_id uuid,
  requester_display_name text,
  status text,
  request_message text,
  created_at timestamptz,
  resolved_at timestamptz,
  resolved_by_profile_id uuid
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform private.require_project_manager(
    p_expected_manager_profile_id,
    p_project_id
  );

  return query
  select
    request.id,
    request.requester_profile_id,
    profile.display_name,
    request.status,
    request.request_message,
    request.created_at,
    request.resolved_at,
    request.resolved_by_profile_id
  from public.project_join_requests as request
  join public.profiles as profile on profile.id = request.requester_profile_id
  where request.project_id = p_project_id
  order by request.created_at desc, request.id;
end;
$$;

create function public.list_project_members_for_manager(
  p_expected_manager_profile_id uuid,
  p_project_id uuid
)
returns table (
  membership_id uuid,
  participant_profile_id uuid,
  participant_display_name text,
  originating_request_id uuid,
  membership_status text,
  joined_at timestamptz,
  left_at timestamptz,
  removed_at timestamptz,
  removed_by_profile_id uuid
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform private.require_project_manager(
    p_expected_manager_profile_id,
    p_project_id
  );

  return query
  select
    membership.id,
    membership.participant_profile_id,
    profile.display_name,
    membership.originating_request_id,
    case
      when membership.left_at is not null then 'left'
      when membership.removed_at is not null then 'removed'
      else 'current'
    end,
    membership.joined_at,
    membership.left_at,
    membership.removed_at,
    membership.removed_by_profile_id
  from public.project_memberships as membership
  join public.profiles as profile
    on profile.id = membership.participant_profile_id
  where membership.project_id = p_project_id
  order by membership.joined_at desc, membership.id;
end;
$$;

create or replace function public.get_project_participant_meeting_details(
  p_expected_profile_id uuid,
  p_project_id uuid
)
returns table (
  project_id uuid,
  project_kind text,
  exact_meeting_text text,
  exact_location extensions.geography
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

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'The Project does not exist.';
  end if;

  if not private.profile_is_project_manager(
    registry.id,
    current_profile_id
  ) and not exists (
    select 1
    from public.project_memberships as membership
    where membership.project_id = registry.id
      and membership.participant_profile_id = current_profile_id
      and membership.left_at is null
      and membership.removed_at is null
  ) then
    raise exception using
      errcode = '42501',
      message = 'Only the project creator or a current participant can read protected meeting information.';
  end if;

  if registry.project_kind = 'one_time' then
    return query
    select
      registry.id,
      registry.project_kind,
      meeting.exact_meeting_text,
      meeting.exact_location
    from public.proposal_meeting_details as meeting
    where meeting.proposal_id = registry.id;
  else
    return query
    select
      registry.id,
      registry.project_kind,
      meeting.exact_meeting_text,
      meeting.exact_location
    from public.recurring_activity_meeting_details as meeting
    where meeting.recurring_activity_id = registry.id;
  end if;
end;
$$;

create or replace function
  public.list_own_project_join_request_contribution_selections(
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
begin
  select * into request_record
  from public.project_join_requests as request
  where request.id = p_request_id;

  if not found
    or (
      request_record.requester_profile_id <> current_profile_id
      and not private.profile_is_project_manager(
        request_record.project_id,
        current_profile_id
      )
    ) then
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

create or replace function public.list_own_project_membership_commitments(
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
begin
  select * into membership_record
  from public.project_memberships as membership
  where membership.id = p_membership_id;

  if not found
    or (
      membership_record.participant_profile_id <> current_profile_id
      and not private.profile_is_project_manager(
        membership_record.project_id,
        current_profile_id
      )
    ) then
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

create or replace function
  public.list_own_project_membership_commitment_options(
    p_expected_profile_id uuid,
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
    p_expected_profile_id
  );
  membership_record public.project_memberships%rowtype;
  registry public.projects%rowtype;
  source_owner_profile_id uuid;
  source_is_operational boolean;
begin
  select * into membership_record
  from public.project_memberships as membership
  where membership.id = p_membership_id;

  if not found then
    raise exception using
      errcode = '42501',
      message = 'The membership commitment options are unavailable.';
  end if;

  select * into registry
  from public.projects as project
  where project.id = membership_record.project_id;

  if not found
    or (
      membership_record.participant_profile_id <> current_profile_id
      and not private.profile_is_project_manager(
        membership_record.project_id,
        current_profile_id
      )
    ) then
    raise exception using
      errcode = '42501',
      message = 'The membership commitment options are unavailable.';
  end if;

  if membership_record.left_at is not null
    or membership_record.removed_at is not null then
    raise exception using
      errcode = '55000',
      message = 'Only a current membership can list commitment options.';
  end if;

  if registry.project_kind = 'one_time' then
    select
      proposal.creator_profile_id,
      proposal.lifecycle_state = 'published'
        and proposal.ends_at is not null
        and statement_timestamp() < proposal.ends_at
    into source_owner_profile_id, source_is_operational
    from public.proposals as proposal
    where proposal.id = registry.id;
  else
    select
      activity.creator_profile_id,
      activity.lifecycle_state in ('published', 'paused')
    into source_owner_profile_id, source_is_operational
    from public.recurring_activities as activity
    where activity.id = registry.id;
  end if;

  if not found or source_owner_profile_id <> registry.creator_profile_id then
    raise exception using
      errcode = '55000',
      message = 'The Project registry is inconsistent with its concrete activity.';
  end if;

  if source_is_operational is not true then
    raise exception using
      errcode = '55000',
      message = 'Membership commitments can only change while the Project is operational.';
  end if;

  return query
  with ordered_options as (
    select
      'skill'::text as resolved_kind,
      available_skill.skill_id as resolved_id,
      skill.label as resolved_label,
      0::smallint as kind_order,
      category.sort_order as category_order,
      skill.sort_order as item_order,
      null::timestamptz as resource_created_at
    from public.proposal_skills as available_skill
    join public.skills as skill on skill.id = available_skill.skill_id
    join public.skill_categories as category on category.id = skill.category_id
    where registry.project_kind = 'one_time'
      and available_skill.proposal_id = membership_record.project_id

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
      and resource_need.state = 'open'
  )
  select
    ordered.resolved_kind,
    ordered.resolved_id,
    ordered.resolved_label
  from ordered_options as ordered
  order by
    ordered.kind_order,
    ordered.category_order,
    ordered.item_order,
    ordered.resource_created_at,
    ordered.resolved_id;
end;
$$;

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
    from unnest(normalized_expected_resource_need_ids)
      as expected(resource_need_id)
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
    raise exception using
      errcode = 'P0002',
      message = 'The membership does not exist.';
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
    and not private.profile_is_project_manager(
      membership_record.project_id,
      current_profile_id
    ) then
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

create function public.set_project_requirement_manual_coverage_as_manager(
  p_expected_manager_profile_id uuid,
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
    p_expected_manager_profile_id
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

  if not private.profile_is_project_manager(
    p_project_id,
    current_profile_id
  ) then
    raise exception using
      errcode = '42501',
      message = 'Only a current Project manager can manage manual requirement coverage.';
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

create or replace function public.list_project_live_requirement_coverage(
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
      not private.profile_is_project_manager(
        p_project_id,
        current_profile_id
      )
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

create or replace function private.profile_has_current_project_chat_entitlement(
  p_project_id uuid,
  p_profile_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    private.profile_is_project_manager(p_project_id, p_profile_id)
    or private.profile_has_current_project_membership(
      p_project_id,
      p_profile_id
    );
$$;

create or replace function private.profile_has_project_chat_history_entitlement(
  p_project_id uuid,
  p_profile_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    private.profile_is_project_manager(p_project_id, p_profile_id)
    or private.profile_has_project_membership_history(
      p_project_id,
      p_profile_id
    );
$$;

create or replace function private.profile_can_read_project_chat_message(
  p_project_id uuid,
  p_profile_id uuid,
  p_message_created_at timestamptz
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    p_project_id is not null
    and p_profile_id is not null
    and p_message_created_at is not null
    and (
      private.profile_is_project_manager(p_project_id, p_profile_id)
      or private.profile_has_current_project_membership(
        p_project_id,
        p_profile_id
      )
      or p_message_created_at <= private.latest_project_membership_end(
        p_project_id,
        p_profile_id
      )
    );
$$;

create or replace function public.get_own_project_group_chat(
  p_expected_profile_id uuid,
  p_project_id uuid
)
returns table (
  chat_id uuid,
  project_id uuid,
  project_kind text,
  activated_at timestamptz,
  viewer_role text,
  has_current_entitlement boolean,
  has_history_entitlement boolean
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
begin
  if p_project_id is null or not exists (
    select 1
    from public.project_group_chats as chat
    where chat.project_id = p_project_id
      and private.profile_has_project_chat_history_entitlement(
        chat.project_id,
        current_profile_id
      )
  ) then
    raise exception using
      errcode = '42501',
      message = 'The project group chat is unavailable.';
  end if;

  return query
  select
    chat.id,
    project.id,
    project.project_kind,
    chat.activated_at,
    case
      when project.creator_profile_id = current_profile_id then 'creator'
      when exists (
        select 1
        from public.project_delegates as delegate
        where delegate.project_id = project.id
          and delegate.delegate_profile_id = current_profile_id
          and delegate.revoked_at is null
      ) then 'delegate'
      when private.profile_has_current_project_membership(
        project.id,
        current_profile_id
      ) then 'current_member'
      else 'former_member'
    end,
    private.profile_has_current_project_chat_entitlement(
      project.id,
      current_profile_id
    ),
    private.profile_has_project_chat_history_entitlement(
      project.id,
      current_profile_id
    )
  from public.project_group_chats as chat
  join public.projects as project on project.id = chat.project_id
  where chat.project_id = p_project_id;
end;
$$;

create or replace function public.send_project_chat_message(
  p_expected_profile_id uuid,
  p_chat_id uuid,
  p_body text
)
returns table (
  message_id uuid,
  chat_id uuid,
  sender_profile_id uuid,
  created_at timestamptz,
  body text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_complete_project_chat_profile(
    p_expected_profile_id
  );
  chat_record record;
  project_record record;
  canonical_body text := regexp_replace(
    coalesce(p_body, ''),
    '^[[:space:]]+|[[:space:]]+$',
    '',
    'g'
  );
  canonical_created_at timestamptz;
  inserted_message public.project_chat_messages%rowtype;
  recipient_profile_id uuid;
begin
  if char_length(canonical_body) < 1 then
    raise exception using
      errcode = '22023',
      message = 'A Project chat message cannot be empty.';
  end if;

  if char_length(canonical_body) > 4000 then
    raise exception using
      errcode = '22023',
      message = 'A Project chat message cannot exceed 4,000 characters.';
  end if;

  select chat.id, chat.project_id
  into chat_record
  from public.project_group_chats as chat
  where chat.id = p_chat_id;

  if not found then
    raise exception using
      errcode = '42501',
      message = 'The project group chat is unavailable for sending.';
  end if;

  select * into project_record
  from private.lock_project_for_participation(chat_record.project_id, false);

  if not private.profile_has_current_project_chat_entitlement(
    chat_record.project_id,
    current_profile_id
  ) then
    raise exception using
      errcode = '42501',
      message = 'The project group chat is unavailable for sending.';
  end if;

  canonical_created_at := clock_timestamp();

  insert into public.project_chat_messages (
    chat_id,
    sender_profile_id,
    body,
    created_at
  )
  values (
    chat_record.id,
    current_profile_id,
    canonical_body,
    canonical_created_at
  )
  returning * into inserted_message;

  insert into private.outbox_events (event_type, payload)
  values (
    'project.chat_message_sent',
    jsonb_build_object(
      'chat_id', chat_record.id,
      'project_id', chat_record.project_id,
      'project_kind', project_record.project_kind,
      'message_id', inserted_message.id,
      'sender_profile_id', current_profile_id
    )
  );

  -- Existing connections cache topic authorization. Addressing only current
  -- managers/members makes revocation effective for subsequent durable sends.
  for recipient_profile_id in
    select project.creator_profile_id
    from public.projects as project
    where project.id = chat_record.project_id

    union

    select delegate.delegate_profile_id
    from public.project_delegates as delegate
    where delegate.project_id = chat_record.project_id
      and delegate.revoked_at is null

    union

    select membership.participant_profile_id
    from public.project_memberships as membership
    where membership.project_id = chat_record.project_id
      and membership.left_at is null
      and membership.removed_at is null
    order by 1
  loop
    perform realtime.send(
      jsonb_build_object(
        'chat_id', chat_record.id,
        'message_id', inserted_message.id,
        'created_at', inserted_message.created_at
      ),
      'project.chat_message_sent',
      private.project_chat_realtime_topic(
        chat_record.id,
        recipient_profile_id
      ),
      true
    );
  end loop;

  return query
  select
    inserted_message.id,
    inserted_message.chat_id,
    inserted_message.sender_profile_id,
    inserted_message.created_at,
    inserted_message.body;
end;
$$;

create or replace function private.record_project_requirement_coverage_event(
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
  canonical_created_at timestamptz;
  source_outbox_event_id uuid;
  resolved_chat_id uuid;
  system_event_id uuid;
  recipient_profile_id uuid;
  realtime_payload jsonb;
begin
  if p_event_type not in (
    'project.requirement_covered',
    'project.requirement_needed_again'
  ) then
    raise exception using
      errcode = '22023',
      message = 'Unsupported Project requirement coverage event type.';
  end if;

  select chat.id
  into resolved_chat_id
  from public.project_group_chats as chat
  where chat.project_id = p_project_id;

  canonical_created_at := clock_timestamp();

  if resolved_chat_id is not null
    and p_event_type = 'project.requirement_needed_again' then
    select greatest(
      canonical_created_at,
      coalesce(
        max(event.created_at) + interval '1 microsecond',
        canonical_created_at
      )
    )
    into canonical_created_at
    from public.project_chat_system_events as event
    where event.chat_id = resolved_chat_id;
  end if;

  insert into private.audit_events (
    action,
    actor_user_id,
    target_type,
    target_id,
    metadata,
    created_at
  )
  values (
    p_event_type,
    p_actor_profile_id,
    'project_requirement',
    p_requirement_id,
    identifier_payload,
    canonical_created_at
  );

  insert into private.outbox_events (
    event_type,
    payload,
    created_at,
    available_at
  )
  values (
    p_event_type,
    identifier_payload,
    canonical_created_at,
    canonical_created_at
  )
  returning id into source_outbox_event_id;

  if resolved_chat_id is null then
    return;
  end if;

  if p_event_type = 'project.requirement_needed_again' then
    insert into public.project_chat_system_events (
      chat_id,
      event_kind,
      requirement_kind,
      skill_id,
      resource_need_id,
      source_outbox_event_id,
      created_at
    )
    values (
      resolved_chat_id,
      'requirement_needed_again',
      p_requirement_kind,
      case when p_requirement_kind = 'skill' then p_requirement_id end,
      case when p_requirement_kind = 'resource' then p_requirement_id end,
      source_outbox_event_id,
      canonical_created_at
    )
    returning id into system_event_id;

    realtime_payload := jsonb_build_object(
      'chat_id', resolved_chat_id,
      'project_id', p_project_id,
      'system_event_id', system_event_id,
      'requirement_kind', p_requirement_kind,
      'requirement_id', p_requirement_id,
      'created_at', canonical_created_at
    );
  else
    realtime_payload := jsonb_build_object(
      'chat_id', resolved_chat_id,
      'project_id', p_project_id,
      'requirement_kind', p_requirement_kind,
      'requirement_id', p_requirement_id,
      'created_at', canonical_created_at
    );
  end if;

  for recipient_profile_id in
    select project.creator_profile_id
    from public.projects as project
    where project.id = p_project_id

    union

    select delegate.delegate_profile_id
    from public.project_delegates as delegate
    where delegate.project_id = p_project_id
      and delegate.revoked_at is null

    union

    select membership.participant_profile_id
    from public.project_memberships as membership
    where membership.project_id = p_project_id
      and membership.left_at is null
      and membership.removed_at is null
    order by 1
  loop
    perform realtime.send(
      realtime_payload,
      p_event_type,
      private.project_chat_realtime_topic(
        resolved_chat_id,
        recipient_profile_id
      ),
      true
    );
  end loop;
end;
$$;

create or replace function public.list_own_project_group_chats(
  p_expected_profile_id uuid,
  p_limit integer,
  p_before_activity_at timestamptz default null,
  p_before_chat_id uuid default null
)
returns table (
  chat_id uuid,
  project_id uuid,
  project_kind text,
  project_title text,
  viewer_role text,
  has_current_entitlement boolean,
  has_history_entitlement boolean,
  activated_at timestamptz,
  last_visible_message_id uuid,
  last_visible_message_body text,
  last_visible_message_at timestamptz,
  last_visible_sender_profile_id uuid,
  last_visible_sender_display_name text,
  activity_at timestamptz
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
begin
  if p_limit is null or p_limit < 1 or p_limit > 50 then
    raise exception using
      errcode = '22023',
      message = 'The Project chat list page size must be between 1 and 50.';
  end if;

  if (p_before_activity_at is null) <> (p_before_chat_id is null) then
    raise exception using
      errcode = '22023',
      message = 'Both Project chat-list cursor values must be provided together.';
  end if;

  return query
  with accessible_projects as (
    select project.id
    from public.projects as project
    where project.creator_profile_id = current_profile_id

    union

    select delegate.project_id
    from public.project_delegates as delegate
    where delegate.delegate_profile_id = current_profile_id
      and delegate.revoked_at is null

    union

    select membership.project_id
    from public.project_memberships as membership
    where membership.participant_profile_id = current_profile_id
  ),
  visible_chats as (
    select
      chat.id as chat_id,
      project.id as project_id,
      project.project_kind,
      case project.project_kind
        when 'one_time' then proposal.title
        when 'recurring' then activity.title
      end as project_title,
      case
        when project.creator_profile_id = current_profile_id then 'creator'
        when exists (
          select 1
          from public.project_delegates as delegate
          where delegate.project_id = project.id
            and delegate.delegate_profile_id = current_profile_id
            and delegate.revoked_at is null
        ) then 'delegate'
        when private.profile_has_current_project_membership(
          project.id,
          current_profile_id
        ) then 'current_member'
        else 'former_member'
      end as viewer_role,
      private.profile_has_current_project_chat_entitlement(
        project.id,
        current_profile_id
      ) as has_current_entitlement,
      true as has_history_entitlement,
      chat.activated_at,
      latest_message.id as last_visible_message_id,
      latest_message.body as last_visible_message_body,
      latest_message.created_at as last_visible_message_at,
      latest_message.sender_profile_id as last_visible_sender_profile_id,
      latest_message.sender_display_name as last_visible_sender_display_name,
      greatest(
        chat.activated_at,
        coalesce(latest_message.created_at, chat.activated_at),
        coalesce(latest_system_event.created_at, chat.activated_at)
      ) as activity_at
    from accessible_projects as accessible
    join public.projects as project on project.id = accessible.id
    join public.project_group_chats as chat on chat.project_id = project.id
    left join public.proposals as proposal
      on proposal.id = project.id
      and project.project_kind = 'one_time'
    left join public.recurring_activities as activity
      on activity.id = project.id
      and project.project_kind = 'recurring'
    left join lateral (
      select
        message.id,
        message.body,
        message.created_at,
        message.sender_profile_id,
        sender.display_name as sender_display_name
      from public.project_chat_messages as message
      join public.profiles as sender on sender.id = message.sender_profile_id
      where message.chat_id = chat.id
        and private.profile_can_read_project_chat_message(
          project.id,
          current_profile_id,
          message.created_at
        )
      order by message.created_at desc, message.id desc
      limit 1
    ) as latest_message on true
    left join lateral (
      select event.created_at
      from public.project_chat_system_events as event
      where event.chat_id = chat.id
        and private.profile_can_read_project_chat_message(
          project.id,
          current_profile_id,
          event.created_at
        )
      order by event.created_at desc, event.id desc
      limit 1
    ) as latest_system_event on true
  )
  select
    visible.chat_id,
    visible.project_id,
    visible.project_kind,
    visible.project_title,
    visible.viewer_role,
    visible.has_current_entitlement,
    visible.has_history_entitlement,
    visible.activated_at,
    visible.last_visible_message_id,
    visible.last_visible_message_body,
    visible.last_visible_message_at,
    visible.last_visible_sender_profile_id,
    visible.last_visible_sender_display_name,
    visible.activity_at
  from visible_chats as visible
  where p_before_activity_at is null
    or (visible.activity_at, visible.chat_id)
      < (p_before_activity_at, p_before_chat_id)
  order by visible.activity_at desc, visible.chat_id desc
  limit p_limit;
end;
$$;

create function private.profile_can_access_project_join_request_chat(
  p_chat_id uuid,
  p_profile_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_profile_id is not null and exists (
    select 1
    from public.project_join_request_chats as chat
    join public.project_join_requests as request
      on request.id = chat.request_id
    where chat.id = p_chat_id
      and (
        request.requester_profile_id = p_profile_id
        or private.profile_is_project_manager(
          request.project_id,
          p_profile_id
        )
      )
  );
$$;

create or replace function
  private.profile_can_receive_project_join_request_chat_topic(p_topic text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := (select auth.uid());
  topic_chat_id uuid;
  topic_profile_id uuid;
begin
  if current_profile_id is null or p_topic is null then
    return false;
  end if;

  begin
    topic_chat_id := split_part(p_topic, ':', 2)::uuid;
    topic_profile_id := split_part(p_topic, ':', 4)::uuid;
  exception
    when invalid_text_representation then
      return false;
  end;

  if p_topic <> private.project_join_request_chat_realtime_topic(
    topic_chat_id,
    topic_profile_id
  ) or topic_profile_id <> current_profile_id then
    return false;
  end if;

  return private.profile_can_access_project_join_request_chat(
    topic_chat_id,
    current_profile_id
  );
end;
$$;

create or replace function public.send_project_join_request_chat_message(
  p_expected_profile_id uuid,
  p_chat_id uuid,
  p_body text
)
returns table (
  message_id uuid,
  chat_id uuid,
  sender_profile_id uuid,
  created_at timestamptz,
  body text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_participation_identity(
    p_expected_profile_id
  );
  request_project_id uuid;
  request_record public.project_join_requests%rowtype;
  project_record record;
  canonical_body text := regexp_replace(
    coalesce(p_body, ''),
    '^[[:space:]]+|[[:space:]]+$',
    '',
    'g'
  );
  canonical_created_at timestamptz;
  inserted_message public.project_join_request_chat_messages%rowtype;
  identifier_payload jsonb;
  realtime_payload jsonb;
  recipient_profile_id uuid;
begin
  if char_length(canonical_body) < 1 then
    raise exception using
      errcode = '22023',
      message = 'A participation-request chat message cannot be empty.';
  end if;

  if char_length(canonical_body) > 4000 then
    raise exception using
      errcode = '22023',
      message = 'A participation-request chat message cannot exceed 4,000 characters.';
  end if;

  select request.project_id into request_project_id
  from public.project_join_request_chats as chat
  join public.project_join_requests as request on request.id = chat.request_id
  where chat.id = p_chat_id;

  if not found then
    raise exception using
      errcode = '42501',
      message = 'The participation-request chat is unavailable.';
  end if;

  select * into project_record
  from private.lock_project_for_participation(request_project_id, false);

  select request.* into request_record
  from public.project_join_request_chats as chat
  join public.project_join_requests as request on request.id = chat.request_id
  where chat.id = p_chat_id
  for update of request;

  if not found or (
    request_record.requester_profile_id <> current_profile_id
    and not private.profile_is_project_manager(
      request_record.project_id,
      current_profile_id
    )
  ) then
    raise exception using
      errcode = '42501',
      message = 'The participation-request chat is unavailable.';
  end if;

  if request_record.status <> 'pending' then
    raise sqlstate 'PT409'
      using message = 'The participation-request chat is read-only because the request is resolved.';
  end if;

  canonical_created_at := clock_timestamp();

  insert into public.project_join_request_chat_messages (
    chat_id,
    sender_profile_id,
    body,
    created_at
  )
  values (
    p_chat_id,
    current_profile_id,
    canonical_body,
    canonical_created_at
  )
  returning * into inserted_message;

  identifier_payload := jsonb_build_object(
    'chat_id', p_chat_id,
    'request_id', request_record.id,
    'project_id', request_record.project_id,
    'project_kind', project_record.project_kind,
    'message_id', inserted_message.id,
    'sender_profile_id', current_profile_id
  );

  insert into private.audit_events (
    action,
    actor_user_id,
    target_type,
    target_id,
    metadata,
    created_at
  )
  values (
    'project.join_request_chat_message_sent',
    current_profile_id,
    'project_join_request_chat',
    p_chat_id,
    identifier_payload,
    canonical_created_at
  );

  insert into private.outbox_events (
    event_type,
    payload,
    created_at,
    available_at
  )
  values (
    'project.join_request_chat_message_sent',
    identifier_payload,
    canonical_created_at,
    canonical_created_at
  );

  realtime_payload := jsonb_build_object(
    'chat_id', p_chat_id,
    'request_id', request_record.id,
    'message_id', inserted_message.id,
    'created_at', inserted_message.created_at
  );

  for recipient_profile_id in
    select request_record.requester_profile_id

    union

    select project_record.creator_profile_id

    union

    select delegate.delegate_profile_id
    from public.project_delegates as delegate
    where delegate.project_id = request_record.project_id
      and delegate.revoked_at is null
    order by 1
  loop
    perform realtime.send(
      realtime_payload,
      'project.join_request_chat_message_sent',
      private.project_join_request_chat_realtime_topic(
        p_chat_id,
        recipient_profile_id
      ),
      true
    );
  end loop;

  return query
  select
    inserted_message.id,
    inserted_message.chat_id,
    inserted_message.sender_profile_id,
    inserted_message.created_at,
    inserted_message.body;
end;
$$;

create or replace function public.get_own_project_join_request_chat(
  p_expected_profile_id uuid,
  p_request_id uuid
)
returns table (
  chat_id uuid,
  request_id uuid,
  project_id uuid,
  project_kind text,
  project_title text,
  viewer_role text,
  requester_profile_id uuid,
  requester_display_name text,
  creator_profile_id uuid,
  creator_display_name text,
  request_status text,
  request_message text,
  request_created_at timestamptz,
  resolved_at timestamptz,
  activated_at timestamptz,
  is_read_only boolean,
  has_send_entitlement boolean,
  accepted_project_group_chat_id uuid
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
  resolved_chat_id uuid;
begin
  select chat.id into resolved_chat_id
  from public.project_join_request_chats as chat
  where chat.request_id = p_request_id
    and private.profile_can_access_project_join_request_chat(
      chat.id,
      current_profile_id
    );

  if resolved_chat_id is null then
    raise exception using
      errcode = '42501',
      message = 'The participation-request chat is unavailable.';
  end if;

  return query
  select
    chat.id,
    request.id,
    project.id,
    project.project_kind,
    case project.project_kind
      when 'one_time' then proposal.title
      when 'recurring' then recurring.title
    end,
    case
      when current_profile_id = request.requester_profile_id then 'requester'
      when current_profile_id = project.creator_profile_id then 'creator'
      else 'delegate'
    end,
    request.requester_profile_id,
    requester.display_name,
    project.creator_profile_id,
    creator.display_name,
    request.status,
    request.request_message,
    request.created_at,
    request.resolved_at,
    chat.activated_at,
    request.status <> 'pending',
    request.status = 'pending',
    case when request.status = 'accepted' then group_chat.id end
  from public.project_join_requests as request
  join public.project_join_request_chats as chat
    on chat.request_id = request.id
  join public.projects as project on project.id = request.project_id
  join public.profiles as requester
    on requester.id = request.requester_profile_id
  join public.profiles as creator on creator.id = project.creator_profile_id
  left join public.proposals as proposal
    on proposal.id = project.id
    and project.project_kind = 'one_time'
  left join public.recurring_activities as recurring
    on recurring.id = project.id
    and project.project_kind = 'recurring'
  left join public.project_group_chats as group_chat
    on group_chat.project_id = project.id
  where request.id = p_request_id;
end;
$$;

create or replace function public.list_own_project_join_request_chat_items(
  p_expected_profile_id uuid,
  p_chat_id uuid,
  p_limit integer,
  p_before_created_at timestamptz default null,
  p_before_item_kind text default null,
  p_before_item_id uuid default null
)
returns table (
  item_kind text,
  item_id uuid,
  chat_id uuid,
  request_id uuid,
  message_id uuid,
  project_id uuid,
  project_kind text,
  project_title text,
  request_status text,
  request_message text,
  requester_profile_id uuid,
  requester_display_name text,
  sender_profile_id uuid,
  sender_display_name text,
  body text,
  created_at timestamptz
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
  cursor_kind_order integer;
begin
  if p_limit is null or p_limit not between 1 and 50 then
    raise exception using
      errcode = '22023',
      message = 'The participation-request chat page size must be between 1 and 50.';
  end if;

  if num_nonnulls(
    p_before_created_at,
    p_before_item_kind,
    p_before_item_id
  ) not in (0, 3) then
    raise exception using
      errcode = '22023',
      message = 'All participation-request chat cursor values must be provided together.';
  end if;

  if p_before_item_kind is not null then
    cursor_kind_order := case p_before_item_kind
      when 'request' then 0
      when 'message' then 1
      else null
    end;

    if cursor_kind_order is null then
      raise exception using
        errcode = '22023',
        message = 'The participation-request chat cursor item kind is unsupported.';
    end if;
  end if;

  if not private.profile_can_access_project_join_request_chat(
    p_chat_id,
    current_profile_id
  ) then
    raise exception using
      errcode = '42501',
      message = 'The participation-request chat is unavailable.';
  end if;

  return query
  with authorized_items as (
    select
      'request'::text as resolved_item_kind,
      0 as kind_order,
      request.id as resolved_item_id,
      chat.id as resolved_chat_id,
      request.id as resolved_request_id,
      null::uuid as resolved_message_id,
      project.id as resolved_project_id,
      project.project_kind as resolved_project_kind,
      case project.project_kind
        when 'one_time' then proposal.title
        when 'recurring' then recurring.title
      end as resolved_project_title,
      request.status as resolved_request_status,
      request.request_message as resolved_request_message,
      request.requester_profile_id as resolved_requester_profile_id,
      requester.display_name as resolved_requester_display_name,
      null::uuid as resolved_sender_profile_id,
      null::text as resolved_sender_display_name,
      null::text as resolved_body,
      request.created_at as resolved_created_at
    from public.project_join_request_chats as chat
    join public.project_join_requests as request on request.id = chat.request_id
    join public.projects as project on project.id = request.project_id
    join public.profiles as requester
      on requester.id = request.requester_profile_id
    left join public.proposals as proposal
      on proposal.id = project.id
      and project.project_kind = 'one_time'
    left join public.recurring_activities as recurring
      on recurring.id = project.id
      and project.project_kind = 'recurring'
    where chat.id = p_chat_id

    union all

    select
      'message'::text,
      1,
      message.id,
      message.chat_id,
      chat.request_id,
      message.id,
      null::uuid,
      null::text,
      null::text,
      null::text,
      null::text,
      null::uuid,
      null::text,
      message.sender_profile_id,
      sender.display_name,
      message.body,
      message.created_at
    from public.project_join_request_chat_messages as message
    join public.project_join_request_chats as chat on chat.id = message.chat_id
    join public.profiles as sender on sender.id = message.sender_profile_id
    where message.chat_id = p_chat_id
  )
  select
    item.resolved_item_kind,
    item.resolved_item_id,
    item.resolved_chat_id,
    item.resolved_request_id,
    item.resolved_message_id,
    item.resolved_project_id,
    item.resolved_project_kind,
    item.resolved_project_title,
    item.resolved_request_status,
    item.resolved_request_message,
    item.resolved_requester_profile_id,
    item.resolved_requester_display_name,
    item.resolved_sender_profile_id,
    item.resolved_sender_display_name,
    item.resolved_body,
    item.resolved_created_at
  from authorized_items as item
  where p_before_created_at is null
    or (
      item.resolved_created_at,
      item.kind_order,
      item.resolved_item_id
    ) < (
      p_before_created_at,
      cursor_kind_order,
      p_before_item_id
    )
  order by
    item.resolved_created_at desc,
    item.kind_order desc,
    item.resolved_item_id desc
  limit p_limit;
end;
$$;

create or replace function public.list_own_structured_request_message_items(
  p_expected_profile_id uuid,
  p_limit integer,
  p_cursor_activity_at timestamptz default null,
  p_cursor_item_kind text default null,
  p_cursor_request_id uuid default null
)
returns table (
  item_kind text,
  request_id uuid,
  viewer_role text,
  requester_profile_id uuid,
  requester_display_name text,
  status text,
  request_message text,
  created_at timestamptz,
  resolved_at timestamptz,
  activity_at timestamptz,
  project_id uuid,
  project_kind text,
  project_title text,
  project_creator_profile_id uuid,
  project_creator_display_name text,
  resource_listing_id uuid,
  resource_listing_mode text,
  resource_listing_title text,
  resource_listing_lifecycle text,
  resource_owner_profile_id uuid,
  resource_owner_display_name text,
  resource_chat_id uuid,
  resource_agreement_id uuid,
  coordination_closed_at timestamptz
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
  cursor_kind_order integer;
begin
  if p_limit is null or p_limit not between 1 and 50 then
    raise exception using
      errcode = '22023',
      message = 'The unified request page size must be between 1 and 50.';
  end if;

  if num_nonnulls(
    p_cursor_activity_at,
    p_cursor_item_kind,
    p_cursor_request_id
  ) not in (0, 3) then
    raise exception using
      errcode = '22023',
      message = 'All unified request cursor values must be provided together.';
  end if;

  if p_cursor_item_kind is not null then
    cursor_kind_order := case p_cursor_item_kind
      when 'participation_request' then 0
      when 'resource_request' then 1
      else null
    end;

    if cursor_kind_order is null then
      raise exception using
        errcode = '22023',
        message = 'The unified request cursor item kind is unsupported.';
    end if;
  end if;

  return query
  with authorized_items as (
    select
      'participation_request'::text as resolved_item_kind,
      0 as item_kind_order,
      project_request.id as resolved_request_id,
      case
        when project_request.requester_profile_id = current_profile_id
          then 'requester'::text
        when project.creator_profile_id = current_profile_id
          then 'creator'::text
        else 'delegate'::text
      end as resolved_viewer_role,
      project_request.requester_profile_id,
      requester.display_name as requester_display_name,
      project_request.status,
      project_request.request_message,
      project_request.created_at,
      project_request.resolved_at,
      coalesce(
        project_request.resolved_at,
        project_request.created_at
      ) as resolved_activity_at,
      project.id as resolved_project_id,
      project.project_kind as resolved_project_kind,
      case project.project_kind
        when 'one_time' then proposal.title
        when 'recurring' then recurring.title
      end as resolved_project_title,
      project.creator_profile_id as resolved_project_creator_profile_id,
      creator.display_name as resolved_project_creator_display_name,
      null::uuid as resolved_resource_listing_id,
      null::text as resolved_resource_listing_mode,
      null::text as resolved_resource_listing_title,
      null::text as resolved_resource_listing_lifecycle,
      null::uuid as resolved_resource_owner_profile_id,
      null::text as resolved_resource_owner_display_name,
      null::uuid as resolved_resource_chat_id,
      null::uuid as resolved_resource_agreement_id,
      null::timestamptz as resolved_coordination_closed_at
    from public.project_join_requests as project_request
    join public.projects as project on project.id = project_request.project_id
    join public.profiles as requester
      on requester.id = project_request.requester_profile_id
    join public.profiles as creator on creator.id = project.creator_profile_id
    left join public.proposals as proposal
      on proposal.id = project.id
      and project.project_kind = 'one_time'
    left join public.recurring_activities as recurring
      on recurring.id = project.id
      and project.project_kind = 'recurring'
    where project_request.requester_profile_id = current_profile_id
      or private.profile_is_project_manager(
        project_request.project_id,
        current_profile_id
      )

    union all

    select
      'resource_request'::text,
      1,
      resource_request.id,
      case
        when resource_request.requester_profile_id = current_profile_id
          then 'requester'::text
        else 'owner'::text
      end,
      resource_request.requester_profile_id,
      requester.display_name,
      resource_request.status,
      resource_request.request_message,
      resource_request.created_at,
      resource_request.resolved_at,
      greatest(
        resource_request.created_at,
        coalesce(resource_request.resolved_at, resource_request.created_at),
        coalesce(
          resource_request.coordination_closed_at,
          resource_request.created_at
        )
      ),
      null::uuid,
      null::text,
      null::text,
      null::uuid,
      null::text,
      listing.id,
      listing.listing_mode,
      listing.title,
      listing.lifecycle_state,
      listing.owner_profile_id,
      owner.display_name,
      resource_chat.id,
      agreement.id,
      resource_request.coordination_closed_at
    from public.resource_listing_requests as resource_request
    join public.resource_listings as listing
      on listing.id = resource_request.listing_id
    join public.profiles as requester
      on requester.id = resource_request.requester_profile_id
    join public.profiles as owner on owner.id = listing.owner_profile_id
    left join public.resource_request_chats as resource_chat
      on resource_chat.request_id = resource_request.id
    left join public.resource_exchange_agreements as agreement
      on agreement.request_id = resource_request.id
    where current_profile_id in (
      resource_request.requester_profile_id,
      listing.owner_profile_id
    )
  )
  select
    item.resolved_item_kind,
    item.resolved_request_id,
    item.resolved_viewer_role,
    item.requester_profile_id,
    item.requester_display_name,
    item.status,
    item.request_message,
    item.created_at,
    item.resolved_at,
    item.resolved_activity_at,
    item.resolved_project_id,
    item.resolved_project_kind,
    item.resolved_project_title,
    item.resolved_project_creator_profile_id,
    item.resolved_project_creator_display_name,
    item.resolved_resource_listing_id,
    item.resolved_resource_listing_mode,
    item.resolved_resource_listing_title,
    item.resolved_resource_listing_lifecycle,
    item.resolved_resource_owner_profile_id,
    item.resolved_resource_owner_display_name,
    item.resolved_resource_chat_id,
    item.resolved_resource_agreement_id,
    item.resolved_coordination_closed_at
  from authorized_items as item
  where p_cursor_activity_at is null
    or (
      item.resolved_activity_at,
      item.item_kind_order,
      item.resolved_request_id
    ) < (
      p_cursor_activity_at,
      cursor_kind_order,
      p_cursor_request_id
    )
  order by
    item.resolved_activity_at desc,
    item.item_kind_order desc,
    item.resolved_request_id desc
  limit p_limit;
end;
$$;

create or replace function public.get_own_structured_request_message_item(
  p_expected_profile_id uuid,
  p_item_kind text,
  p_request_id uuid
)
returns table (
  item_kind text,
  request_id uuid,
  viewer_role text,
  requester_profile_id uuid,
  requester_display_name text,
  status text,
  request_message text,
  created_at timestamptz,
  resolved_at timestamptz,
  activity_at timestamptz,
  project_id uuid,
  project_kind text,
  project_title text,
  project_creator_profile_id uuid,
  project_creator_display_name text,
  resource_listing_id uuid,
  resource_listing_mode text,
  resource_listing_title text,
  resource_listing_lifecycle text,
  resource_owner_profile_id uuid,
  resource_owner_display_name text,
  resource_chat_id uuid,
  resource_agreement_id uuid,
  coordination_closed_at timestamptz
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
begin
  if p_item_kind not in ('participation_request', 'resource_request')
    or p_request_id is null then
    raise exception using
      errcode = '42501',
      message = 'The structured request message item is unavailable.';
  end if;

  if p_item_kind = 'participation_request' then
    if not exists (
      select 1
      from public.project_join_requests as project_request
      where project_request.id = p_request_id
        and (
          project_request.requester_profile_id = current_profile_id
          or private.profile_is_project_manager(
            project_request.project_id,
            current_profile_id
          )
        )
    ) then
      raise exception using
        errcode = '42501',
        message = 'The structured request message item is unavailable.';
    end if;

    return query
    select
      'participation_request'::text,
      project_request.id,
      case
        when project_request.requester_profile_id = current_profile_id
          then 'requester'::text
        when project.creator_profile_id = current_profile_id
          then 'creator'::text
        else 'delegate'::text
      end,
      project_request.requester_profile_id,
      requester.display_name,
      project_request.status,
      project_request.request_message,
      project_request.created_at,
      project_request.resolved_at,
      coalesce(project_request.resolved_at, project_request.created_at),
      project.id,
      project.project_kind,
      case project.project_kind
        when 'one_time' then proposal.title
        when 'recurring' then recurring.title
      end,
      project.creator_profile_id,
      creator.display_name,
      null::uuid,
      null::text,
      null::text,
      null::text,
      null::uuid,
      null::text,
      null::uuid,
      null::uuid,
      null::timestamptz
    from public.project_join_requests as project_request
    join public.projects as project on project.id = project_request.project_id
    join public.profiles as requester
      on requester.id = project_request.requester_profile_id
    join public.profiles as creator on creator.id = project.creator_profile_id
    left join public.proposals as proposal
      on proposal.id = project.id
      and project.project_kind = 'one_time'
    left join public.recurring_activities as recurring
      on recurring.id = project.id
      and project.project_kind = 'recurring'
    where project_request.id = p_request_id;
    return;
  end if;

  if not exists (
    select 1
    from public.resource_listing_requests as resource_request
    join public.resource_listings as listing
      on listing.id = resource_request.listing_id
    where resource_request.id = p_request_id
      and current_profile_id in (
        resource_request.requester_profile_id,
        listing.owner_profile_id
      )
  ) then
    raise exception using
      errcode = '42501',
      message = 'The structured request message item is unavailable.';
  end if;

  return query
  select
    'resource_request'::text,
    resource_request.id,
    case
      when resource_request.requester_profile_id = current_profile_id
        then 'requester'::text
      else 'owner'::text
    end,
    resource_request.requester_profile_id,
    requester.display_name,
    resource_request.status,
    resource_request.request_message,
    resource_request.created_at,
    resource_request.resolved_at,
    greatest(
      resource_request.created_at,
      coalesce(resource_request.resolved_at, resource_request.created_at),
      coalesce(
        resource_request.coordination_closed_at,
        resource_request.created_at
      )
    ),
    null::uuid,
    null::text,
    null::text,
    null::uuid,
    null::text,
    listing.id,
    listing.listing_mode,
    listing.title,
    listing.lifecycle_state,
    listing.owner_profile_id,
    owner.display_name,
    resource_chat.id,
    agreement.id,
    resource_request.coordination_closed_at
  from public.resource_listing_requests as resource_request
  join public.resource_listings as listing
    on listing.id = resource_request.listing_id
  join public.profiles as requester
    on requester.id = resource_request.requester_profile_id
  join public.profiles as owner on owner.id = listing.owner_profile_id
  left join public.resource_request_chats as resource_chat
    on resource_chat.request_id = resource_request.id
  left join public.resource_exchange_agreements as agreement
    on agreement.request_id = resource_request.id
  where resource_request.id = p_request_id;
end;
$$;

create or replace function public.list_own_scoped_message_chat_items(
  p_expected_profile_id uuid,
  p_scope text,
  p_limit integer,
  p_cursor_activity_at timestamptz default null,
  p_cursor_item_kind text default null,
  p_cursor_chat_id uuid default null
)
returns table (
  item_kind text,
  chat_id uuid,
  activity_at timestamptz,
  display_title text,
  viewer_role text,
  is_read_only boolean,
  last_visible_message_id uuid,
  last_visible_message_body text,
  last_visible_message_at timestamptz,
  last_visible_sender_profile_id uuid,
  last_visible_sender_display_name text,
  project_id uuid,
  project_kind text,
  resource_request_id uuid,
  resource_agreement_id uuid,
  resource_listing_id uuid,
  agreement_lifecycle text,
  coordination_closed_at timestamptz,
  project_request_id uuid,
  project_request_project_id uuid,
  project_request_project_kind text,
  project_request_project_title text,
  project_request_counterparty_profile_id uuid,
  project_request_counterparty_display_name text,
  project_request_status text,
  project_request_message text,
  project_request_resolved_at timestamptz,
  accepted_project_group_chat_id uuid
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
  cursor_kind_order integer;
begin
  if p_scope is null or p_scope not in ('private', 'groups', 'all') then
    raise exception using
      errcode = '22023',
      message = 'The unified chat scope must be private, groups, or all.';
  end if;

  if p_limit is null or p_limit not between 1 and 50 then
    raise exception using
      errcode = '22023',
      message = 'The unified chat page size must be between 1 and 50.';
  end if;

  if num_nonnulls(
    p_cursor_activity_at,
    p_cursor_item_kind,
    p_cursor_chat_id
  ) not in (0, 3) then
    raise exception using
      errcode = '22023',
      message = 'All unified chat cursor values must be provided together.';
  end if;

  if p_cursor_item_kind is not null then
    cursor_kind_order := case p_cursor_item_kind
      when 'project_chat' then 0
      when 'resource_chat' then 1
      when 'project_request_chat' then 2
      else null
    end;

    if cursor_kind_order is null
      or (p_scope = 'private' and p_cursor_item_kind = 'project_chat')
      or (p_scope = 'groups' and p_cursor_item_kind <> 'project_chat') then
      raise exception using
        errcode = '22023',
        message = 'The unified chat cursor item kind is unsupported for this scope.';
    end if;
  end if;

  return query
  with accessible_projects as (
    select project.id
    from public.projects as project
    where project.creator_profile_id = current_profile_id

    union

    select delegate.project_id
    from public.project_delegates as delegate
    where delegate.delegate_profile_id = current_profile_id
      and delegate.revoked_at is null

    union

    select membership.project_id
    from public.project_memberships as membership
    where membership.participant_profile_id = current_profile_id
  ),
  chat_items as (
    select
      'project_chat'::text as resolved_item_kind,
      0 as item_kind_order,
      project_chat.id as resolved_chat_id,
      greatest(
        project_chat.activated_at,
        coalesce(latest_message.created_at, project_chat.activated_at),
        coalesce(latest_system_event.created_at, project_chat.activated_at)
      ) as resolved_activity_at,
      case project.project_kind
        when 'one_time' then proposal.title
        when 'recurring' then recurring.title
      end as resolved_display_title,
      case
        when project.creator_profile_id = current_profile_id then 'creator'
        when exists (
          select 1
          from public.project_delegates as delegate
          where delegate.project_id = project.id
            and delegate.delegate_profile_id = current_profile_id
            and delegate.revoked_at is null
        ) then 'delegate'
        when private.profile_has_current_project_membership(
          project.id,
          current_profile_id
        ) then 'current_member'
        else 'former_member'
      end as resolved_viewer_role,
      not private.profile_has_current_project_chat_entitlement(
        project.id,
        current_profile_id
      ) as resolved_is_read_only,
      latest_message.id as resolved_last_visible_message_id,
      latest_message.body as resolved_last_visible_message_body,
      latest_message.created_at as resolved_last_visible_message_at,
      latest_message.sender_profile_id
        as resolved_last_visible_sender_profile_id,
      latest_message.sender_display_name
        as resolved_last_visible_sender_display_name,
      project.id as resolved_project_id,
      project.project_kind as resolved_project_kind,
      null::uuid as resolved_resource_request_id,
      null::uuid as resolved_resource_agreement_id,
      null::uuid as resolved_resource_listing_id,
      null::text as resolved_agreement_lifecycle,
      null::timestamptz as resolved_coordination_closed_at,
      null::uuid as resolved_project_request_id,
      null::uuid as resolved_project_request_project_id,
      null::text as resolved_project_request_project_kind,
      null::text as resolved_project_request_project_title,
      null::uuid as resolved_project_request_counterparty_profile_id,
      null::text as resolved_project_request_counterparty_display_name,
      null::text as resolved_project_request_status,
      null::text as resolved_project_request_message,
      null::timestamptz as resolved_project_request_resolved_at,
      null::uuid as resolved_accepted_project_group_chat_id
    from accessible_projects as accessible
    join public.projects as project on project.id = accessible.id
    join public.project_group_chats as project_chat
      on project_chat.project_id = project.id
    left join public.proposals as proposal
      on proposal.id = project.id
      and project.project_kind = 'one_time'
    left join public.recurring_activities as recurring
      on recurring.id = project.id
      and project.project_kind = 'recurring'
    left join lateral (
      select
        message.id,
        message.body,
        message.created_at,
        message.sender_profile_id,
        sender.display_name as sender_display_name
      from public.project_chat_messages as message
      join public.profiles as sender on sender.id = message.sender_profile_id
      where message.chat_id = project_chat.id
        and private.profile_can_read_project_chat_message(
          project.id,
          current_profile_id,
          message.created_at
        )
      order by message.created_at desc, message.id desc
      limit 1
    ) as latest_message on true
    left join lateral (
      select system_event.created_at
      from public.project_chat_system_events as system_event
      where system_event.chat_id = project_chat.id
        and private.profile_can_read_project_chat_message(
          project.id,
          current_profile_id,
          system_event.created_at
        )
      order by system_event.created_at desc, system_event.id desc
      limit 1
    ) as latest_system_event on true
    where p_scope in ('groups', 'all')

    union all

    select
      'resource_chat'::text,
      1,
      resource_chat.id,
      greatest(
        resource_chat.activated_at,
        coalesce(latest_message.created_at, resource_chat.activated_at),
        coalesce(latest_event.created_at, resource_chat.activated_at)
      ),
      listing.title,
      case
        when listing.owner_profile_id = current_profile_id then 'owner'
        else 'requester'
      end,
      not (
        resource_request.status = 'accepted'
        and resource_request.coordination_closed_at is null
        and agreement.lifecycle_state not in ('completed', 'cancelled')
      ),
      latest_message.id,
      latest_message.body,
      latest_message.created_at,
      latest_message.sender_profile_id,
      latest_message.sender_display_name,
      null::uuid,
      null::text,
      resource_request.id,
      agreement.id,
      listing.id,
      agreement.lifecycle_state,
      resource_request.coordination_closed_at,
      null::uuid,
      null::uuid,
      null::text,
      null::text,
      null::uuid,
      null::text,
      null::text,
      null::text,
      null::timestamptz,
      null::uuid
    from public.resource_request_chats as resource_chat
    join public.resource_listing_requests as resource_request
      on resource_request.id = resource_chat.request_id
    join public.resource_listings as listing
      on listing.id = resource_request.listing_id
    join public.resource_exchange_agreements as agreement
      on agreement.request_id = resource_request.id
    left join lateral (
      select
        message.id,
        message.body,
        message.created_at,
        message.sender_profile_id,
        sender.display_name as sender_display_name
      from public.resource_request_chat_messages as message
      join public.profiles as sender on sender.id = message.sender_profile_id
      where message.chat_id = resource_chat.id
      order by message.created_at desc, message.id desc
      limit 1
    ) as latest_message on true
    left join lateral (
      select agreement_event.created_at
      from public.resource_exchange_agreement_events as agreement_event
      where agreement_event.agreement_id = agreement.id
      order by agreement_event.created_at desc, agreement_event.id desc
      limit 1
    ) as latest_event on true
    where p_scope in ('private', 'all')
      and current_profile_id in (
        listing.owner_profile_id,
        resource_request.requester_profile_id
      )

    union all

    select
      'project_request_chat'::text,
      2,
      request_chat.id,
      greatest(
        request_chat.activated_at,
        request.created_at,
        coalesce(request.resolved_at, request.created_at),
        coalesce(latest_message.created_at, request.created_at)
      ),
      case
        when current_profile_id = request.requester_profile_id
          then creator.display_name
        else requester.display_name
      end,
      case
        when current_profile_id = request.requester_profile_id
          then 'requester'
        when current_profile_id = project.creator_profile_id
          then 'creator'
        else 'delegate'
      end,
      request.status <> 'pending',
      latest_message.id,
      latest_message.body,
      latest_message.created_at,
      latest_message.sender_profile_id,
      latest_message.sender_display_name,
      null::uuid,
      null::text,
      null::uuid,
      null::uuid,
      null::uuid,
      null::text,
      null::timestamptz,
      request.id,
      project.id,
      project.project_kind,
      case project.project_kind
        when 'one_time' then proposal.title
        when 'recurring' then recurring.title
      end,
      case
        when current_profile_id = request.requester_profile_id
          then project.creator_profile_id
        else request.requester_profile_id
      end,
      case
        when current_profile_id = request.requester_profile_id
          then creator.display_name
        else requester.display_name
      end,
      request.status,
      request.request_message,
      request.resolved_at,
      case when request.status = 'accepted' then group_chat.id end
    from public.project_join_request_chats as request_chat
    join public.project_join_requests as request
      on request.id = request_chat.request_id
    join public.projects as project on project.id = request.project_id
    join public.profiles as requester
      on requester.id = request.requester_profile_id
    join public.profiles as creator on creator.id = project.creator_profile_id
    left join public.proposals as proposal
      on proposal.id = project.id
      and project.project_kind = 'one_time'
    left join public.recurring_activities as recurring
      on recurring.id = project.id
      and project.project_kind = 'recurring'
    left join public.project_group_chats as group_chat
      on group_chat.project_id = project.id
    left join lateral (
      select
        message.id,
        message.body,
        message.created_at,
        message.sender_profile_id,
        sender.display_name as sender_display_name
      from public.project_join_request_chat_messages as message
      join public.profiles as sender on sender.id = message.sender_profile_id
      where message.chat_id = request_chat.id
      order by message.created_at desc, message.id desc
      limit 1
    ) as latest_message on true
    where p_scope in ('private', 'all')
      and (
        request.requester_profile_id = current_profile_id
        or private.profile_is_project_manager(
          request.project_id,
          current_profile_id
        )
      )
  )
  select
    item.resolved_item_kind,
    item.resolved_chat_id,
    item.resolved_activity_at,
    item.resolved_display_title,
    item.resolved_viewer_role,
    item.resolved_is_read_only,
    item.resolved_last_visible_message_id,
    item.resolved_last_visible_message_body,
    item.resolved_last_visible_message_at,
    item.resolved_last_visible_sender_profile_id,
    item.resolved_last_visible_sender_display_name,
    item.resolved_project_id,
    item.resolved_project_kind,
    item.resolved_resource_request_id,
    item.resolved_resource_agreement_id,
    item.resolved_resource_listing_id,
    item.resolved_agreement_lifecycle,
    item.resolved_coordination_closed_at,
    item.resolved_project_request_id,
    item.resolved_project_request_project_id,
    item.resolved_project_request_project_kind,
    item.resolved_project_request_project_title,
    item.resolved_project_request_counterparty_profile_id,
    item.resolved_project_request_counterparty_display_name,
    item.resolved_project_request_status,
    item.resolved_project_request_message,
    item.resolved_project_request_resolved_at,
    item.resolved_accepted_project_group_chat_id
  from chat_items as item
  where p_cursor_activity_at is null
    or (
      item.resolved_activity_at,
      item.item_kind_order,
      item.resolved_chat_id
    ) < (
      p_cursor_activity_at,
      cursor_kind_order,
      p_cursor_chat_id
    )
  order by
    item.resolved_activity_at desc,
    item.item_kind_order desc,
    item.resolved_chat_id desc
  limit p_limit;
end;
$$;

revoke all privileges on function
  private.validate_project_delegate_relationship()
  from public, anon, authenticated, service_role;
revoke all privileges on function
  private.profile_is_project_manager(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function
  private.require_project_manager(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function
  private.project_allows_delegate_collaboration(uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function
  private.lock_project_for_delegate_management(uuid, boolean)
  from public, anon, authenticated, service_role;
revoke all privileges on function
  private.record_project_delegate_event(
    text,
    uuid,
    uuid,
    text,
    uuid,
    uuid,
    uuid
  ) from public, anon, authenticated, service_role;
revoke all privileges on function
  private.profile_can_access_project_join_request_chat(uuid, uuid)
  from public, anon, authenticated, service_role;

revoke all privileges on function
  public.create_project_delegate_invitation(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function
  public.revoke_project_delegate_invitation(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function
  public.preview_project_delegate_invitation(text)
  from public, anon, authenticated, service_role;
revoke all privileges on function
  public.accept_project_delegate_invitation(uuid, text)
  from public, anon, authenticated, service_role;
revoke all privileges on function
  public.list_project_delegates_for_owner(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function
  public.list_project_delegate_invitations_for_owner(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function
  public.revoke_project_delegate(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function
  public.accept_project_join_request_as_manager(
    uuid,
    uuid,
    uuid[],
    uuid[],
    uuid[],
    uuid[],
    uuid[],
    uuid[]
  ) from public, anon, authenticated, service_role;
revoke all privileges on function
  public.accept_project_join_request_as_manager(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function
  public.reject_project_join_request_as_manager(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function
  public.remove_project_member_as_manager(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function
  public.list_project_join_requests_for_manager(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function
  public.list_project_members_for_manager(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function
  public.set_project_requirement_manual_coverage_as_manager(
    uuid,
    uuid,
    text,
    uuid,
    boolean
  ) from public, anon, authenticated, service_role;

grant execute on function public.create_project_delegate_invitation(uuid, uuid)
  to authenticated;
grant execute on function public.revoke_project_delegate_invitation(uuid, uuid)
  to authenticated;
grant execute on function public.preview_project_delegate_invitation(text)
  to anon, authenticated;
grant execute on function public.accept_project_delegate_invitation(uuid, text)
  to authenticated;
grant execute on function public.list_project_delegates_for_owner(uuid, uuid)
  to authenticated;
grant execute on function
  public.list_project_delegate_invitations_for_owner(uuid, uuid)
  to authenticated;
grant execute on function public.revoke_project_delegate(uuid, uuid)
  to authenticated;
grant execute on function public.accept_project_join_request_as_manager(
  uuid,
  uuid,
  uuid[],
  uuid[],
  uuid[],
  uuid[],
  uuid[],
  uuid[]
) to authenticated;
grant execute on function
  public.accept_project_join_request_as_manager(uuid, uuid)
  to authenticated;
grant execute on function
  public.reject_project_join_request_as_manager(uuid, uuid)
  to authenticated;
grant execute on function public.remove_project_member_as_manager(uuid, uuid)
  to authenticated;
grant execute on function
  public.list_project_join_requests_for_manager(uuid, uuid)
  to authenticated;
grant execute on function public.list_project_members_for_manager(uuid, uuid)
  to authenticated;
grant execute on function
  public.set_project_requirement_manual_coverage_as_manager(
    uuid,
    uuid,
    text,
    uuid,
    boolean
  ) to authenticated;

comment on function private.profile_is_project_manager(uuid, uuid) is
  'Central current-manager authorization: immutable Project owner or an active, non-revoked delegate for the exact shared Project identity.';
comment on function private.project_allows_delegate_collaboration(uuid) is
  'Allows delegate collaboration for published not-ended Proposals and published or paused Tavoli; drafts, cancelled/ended history, and elapsed Proposals fail closed.';
comment on function public.create_project_delegate_invitation(uuid, uuid) is
  'Owner-only creation of one seven-day single-use invitation. Returns the 256-bit bearer token once and persists only its SHA-256 digest.';
comment on function public.preview_project_delegate_invitation(text) is
  'Non-mutating minimal invite preview. Invalid, consumed, revoked, expired, and non-operational invitations share one unavailable shape.';
comment on function public.accept_project_delegate_invitation(uuid, text) is
  'Atomically consumes one valid invite for the expected complete profile, with same-accepter retry idempotency and row-lock race protection.';
comment on function public.revoke_project_delegate(uuid, uuid) is
  'Owner-only idempotent revocation of one active delegate relationship; subsequent manager checks fail immediately.';
comment on function
  public.accept_project_join_request_as_manager(
    uuid,
    uuid,
    uuid[],
    uuid[],
    uuid[],
    uuid[],
    uuid[],
    uuid[]
  ) is
  'Manager-named contribution-triage acceptance boundary for an owner or active delegate; the creator-named compatibility overload remains owner-only.';
comment on function
  public.reject_project_join_request_as_manager(uuid, uuid) is
  'Rejects one pending participation request as the owner or an active delegate.';
comment on function public.remove_project_member_as_manager(uuid, uuid) is
  'Ends one current membership as the owner or an active delegate.';
comment on function
  public.set_project_requirement_manual_coverage_as_manager(
    uuid,
    uuid,
    text,
    uuid,
    boolean
  ) is
  'Lets a current Project manager set or clear the existing external/manual coverage marker without editing requirement definitions.';
comment on function
  private.profile_can_access_project_join_request_chat(uuid, uuid) is
  'Authorizes the requester or any current Project manager for one permanent participation-request chat without copying its history.';

-- Keep the legacy unified Project/resource chat projection delegate-aware.
create or replace FUNCTION public.list_own_message_chat_items(p_expected_profile_id uuid, p_limit integer, p_cursor_activity_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_cursor_item_kind text DEFAULT NULL::text, p_cursor_chat_id uuid DEFAULT NULL::uuid)
 RETURNS TABLE(item_kind text, chat_id uuid, activity_at timestamp with time zone, display_title text, viewer_role text, is_read_only boolean, last_visible_message_id uuid, last_visible_message_body text, last_visible_message_at timestamp with time zone, last_visible_sender_profile_id uuid, last_visible_sender_display_name text, project_id uuid, project_kind text, resource_request_id uuid, resource_agreement_id uuid, resource_listing_id uuid, agreement_lifecycle text, coordination_closed_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $$
declare
  current_profile_id uuid := private.require_participation_identity(
    p_expected_profile_id
  );
  cursor_kind_order integer;
begin
  if p_limit is null or p_limit not between 1 and 50 then
    raise exception using
      errcode = '22023',
      message = 'The unified chat page size must be between 1 and 50.';
  end if;

  if num_nonnulls(
    p_cursor_activity_at,
    p_cursor_item_kind,
    p_cursor_chat_id
  ) not in (0, 3) then
    raise exception using
      errcode = '22023',
      message = 'All unified chat cursor values must be provided together.';
  end if;

  if p_cursor_item_kind is not null then
    cursor_kind_order := case p_cursor_item_kind
      when 'project_chat' then 0
      when 'resource_chat' then 1
      else null
    end;

    if cursor_kind_order is null then
      raise exception using
        errcode = '22023',
        message = 'The unified chat cursor item kind is unsupported.';
    end if;
  end if;

  return query
  with accessible_projects as (
    select project.id
    from public.projects as project
    where project.creator_profile_id = current_profile_id

    union

    select delegate.project_id
    from public.project_delegates as delegate
    where delegate.delegate_profile_id = current_profile_id
      and delegate.revoked_at is null

    union

    select membership.project_id
    from public.project_memberships as membership
    where membership.participant_profile_id = current_profile_id
  ),
  chat_items as (
    select
      'project_chat'::text as resolved_item_kind,
      0 as item_kind_order,
      project_chat.id as resolved_chat_id,
      greatest(
        project_chat.activated_at,
        coalesce(latest_message.created_at, project_chat.activated_at),
        coalesce(latest_system_event.created_at, project_chat.activated_at)
      ) as resolved_activity_at,
      case project.project_kind
        when 'one_time' then proposal.title
        when 'recurring' then recurring.title
      end as resolved_display_title,
      case
        when project.creator_profile_id = current_profile_id then 'creator'
        when exists (
          select 1
          from public.project_delegates as delegate
          where delegate.project_id = project.id
            and delegate.delegate_profile_id = current_profile_id
            and delegate.revoked_at is null
        ) then 'delegate'
        when private.profile_has_current_project_membership(
          project.id,
          current_profile_id
        ) then 'current_member'
        else 'former_member'
      end as resolved_viewer_role,
      not private.profile_has_current_project_chat_entitlement(
        project.id,
        current_profile_id
      ) as resolved_is_read_only,
      latest_message.id as resolved_last_visible_message_id,
      latest_message.body as resolved_last_visible_message_body,
      latest_message.created_at as resolved_last_visible_message_at,
      latest_message.sender_profile_id
        as resolved_last_visible_sender_profile_id,
      latest_message.sender_display_name
        as resolved_last_visible_sender_display_name,
      project.id as resolved_project_id,
      project.project_kind as resolved_project_kind,
      null::uuid as resolved_resource_request_id,
      null::uuid as resolved_resource_agreement_id,
      null::uuid as resolved_resource_listing_id,
      null::text as resolved_agreement_lifecycle,
      null::timestamptz as resolved_coordination_closed_at
    from accessible_projects as accessible
    join public.projects as project on project.id = accessible.id
    join public.project_group_chats as project_chat
      on project_chat.project_id = project.id
    left join public.proposals as proposal
      on proposal.id = project.id
      and project.project_kind = 'one_time'
    left join public.recurring_activities as recurring
      on recurring.id = project.id
      and project.project_kind = 'recurring'
    left join lateral (
      select
        message.id,
        message.body,
        message.created_at,
        message.sender_profile_id,
        sender.display_name as sender_display_name
      from public.project_chat_messages as message
      join public.profiles as sender on sender.id = message.sender_profile_id
      where message.chat_id = project_chat.id
        and private.profile_can_read_project_chat_message(
          project.id,
          current_profile_id,
          message.created_at
        )
      order by message.created_at desc, message.id desc
      limit 1
    ) as latest_message on true
    left join lateral (
      select system_event.created_at
      from public.project_chat_system_events as system_event
      where system_event.chat_id = project_chat.id
        and private.profile_can_read_project_chat_message(
          project.id,
          current_profile_id,
          system_event.created_at
        )
      order by system_event.created_at desc, system_event.id desc
      limit 1
    ) as latest_system_event on true

    union all

    select
      'resource_chat'::text,
      1,
      resource_chat.id,
      greatest(
        resource_chat.activated_at,
        coalesce(latest_message.created_at, resource_chat.activated_at),
        coalesce(latest_event.created_at, resource_chat.activated_at)
      ),
      listing.title,
      case
        when listing.owner_profile_id = current_profile_id then 'owner'
        else 'requester'
      end,
      not (
        resource_request.status = 'accepted'
        and resource_request.coordination_closed_at is null
        and agreement.lifecycle_state not in ('completed', 'cancelled')
      ),
      latest_message.id,
      latest_message.body,
      latest_message.created_at,
      latest_message.sender_profile_id,
      latest_message.sender_display_name,
      null::uuid,
      null::text,
      resource_request.id,
      agreement.id,
      listing.id,
      agreement.lifecycle_state,
      resource_request.coordination_closed_at
    from public.resource_request_chats as resource_chat
    join public.resource_listing_requests as resource_request
      on resource_request.id = resource_chat.request_id
    join public.resource_listings as listing
      on listing.id = resource_request.listing_id
    join public.resource_exchange_agreements as agreement
      on agreement.request_id = resource_request.id
    left join lateral (
      select
        message.id,
        message.body,
        message.created_at,
        message.sender_profile_id,
        sender.display_name as sender_display_name
      from public.resource_request_chat_messages as message
      join public.profiles as sender on sender.id = message.sender_profile_id
      where message.chat_id = resource_chat.id
      order by message.created_at desc, message.id desc
      limit 1
    ) as latest_message on true
    left join lateral (
      select agreement_event.created_at
      from public.resource_exchange_agreement_events as agreement_event
      where agreement_event.agreement_id = agreement.id
      order by agreement_event.created_at desc, agreement_event.id desc
      limit 1
    ) as latest_event on true
    where current_profile_id in (
      listing.owner_profile_id,
      resource_request.requester_profile_id
    )
  )
  select
    item.resolved_item_kind,
    item.resolved_chat_id,
    item.resolved_activity_at,
    item.resolved_display_title,
    item.resolved_viewer_role,
    item.resolved_is_read_only,
    item.resolved_last_visible_message_id,
    item.resolved_last_visible_message_body,
    item.resolved_last_visible_message_at,
    item.resolved_last_visible_sender_profile_id,
    item.resolved_last_visible_sender_display_name,
    item.resolved_project_id,
    item.resolved_project_kind,
    item.resolved_resource_request_id,
    item.resolved_resource_agreement_id,
    item.resolved_resource_listing_id,
    item.resolved_agreement_lifecycle,
    item.resolved_coordination_closed_at
  from chat_items as item
  where p_cursor_activity_at is null
    or (
      item.resolved_activity_at,
      item.item_kind_order,
      item.resolved_chat_id
    ) < (
      p_cursor_activity_at,
      cursor_kind_order,
      p_cursor_chat_id
    )
  order by
    item.resolved_activity_at desc,
    item.item_kind_order desc,
    item.resolved_chat_id desc
  limit p_limit;
end;
$$;

-- Delegates can inspect and manage ended Proposal contribution attribution without
-- weakening the legacy creator-named mutation contract.
create or replace FUNCTION public.list_project_membership_actual_contributions(p_expected_profile_id uuid, p_membership_id uuid)
 RETURNS TABLE(contribution_kind text, contribution_id uuid, label text, attribution_source text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $$
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
      and not private.profile_is_project_manager(
        membership_record.project_id,
        current_profile_id
      )
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

create or replace FUNCTION public.list_project_membership_actual_contribution_options_for_manager(p_expected_manager_profile_id uuid, p_membership_id uuid)
 RETURNS TABLE(option_kind text, option_id uuid, label text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $$
declare
  current_profile_id uuid := private.require_participation_identity(
    p_expected_manager_profile_id
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

  if not found or not private.profile_is_project_manager(
    membership_record.project_id,
    current_profile_id
  ) then
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

create or replace FUNCTION public.replace_project_membership_actual_contributions_as_manager(p_expected_manager_profile_id uuid, p_membership_id uuid, p_expected_skill_ids uuid[], p_expected_resource_need_ids uuid[], p_expected_substantial_effort boolean, p_skill_ids uuid[], p_resource_need_ids uuid[], p_substantial_effort boolean)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $$
declare
  current_profile_id uuid := private.require_participation_identity(
    p_expected_manager_profile_id
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

  if not private.profile_is_project_manager(
    membership_record.project_id,
    current_profile_id
  ) then
    raise exception using
      errcode = '42501',
      message = 'Only a current Project manager can manage actual contributions.';
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

revoke all on function
  public.list_project_membership_actual_contribution_options_for_manager(uuid, uuid)
  from public, anon, authenticated;
revoke all on function
  public.replace_project_membership_actual_contributions_as_manager(
    uuid,
    uuid,
    uuid[],
    uuid[],
    boolean,
    uuid[],
    uuid[],
    boolean
  ) from public, anon, authenticated;
grant execute on function
  public.list_project_membership_actual_contribution_options_for_manager(uuid, uuid)
  to authenticated;
grant execute on function
  public.replace_project_membership_actual_contributions_as_manager(
    uuid,
    uuid,
    uuid[],
    uuid[],
    boolean,
    uuid[],
    uuid[],
    boolean
  ) to authenticated;

comment on function
  public.list_project_membership_actual_contribution_options_for_manager(uuid, uuid) is
  'Lists ended-Proposal attribution options for an owner or active delegate.';
comment on function
  public.replace_project_membership_actual_contributions_as_manager(
    uuid,
    uuid,
    uuid[],
    uuid[],
    boolean,
    uuid[],
    uuid[],
    boolean
  ) is
  'CAS-protected ended-Proposal attribution mutation for an owner or active delegate.';

create or replace function public.accept_project_join_request(
  p_expected_creator_profile_id uuid,
  p_request_id uuid
)
returns uuid
language sql
security definer
set search_path = ''
as $$
  select public.accept_project_join_request(
    p_expected_creator_profile_id,
    p_request_id,
    '{}'::uuid[],
    '{}'::uuid[],
    '{}'::uuid[],
    '{}'::uuid[],
    '{}'::uuid[],
    '{}'::uuid[]
  );
$$;
