-- Evolve the existing delegate relationship into the single source of truth for
-- both delegated authority levels. The owner columns continue to identify the
-- immutable original Creator; issuer/grantor columns record the real actor.

alter table public.project_delegate_invitations
  add column issuer_profile_id uuid,
  add column requested_authority_role text not null default 'co_organizer';

update public.project_delegate_invitations
set issuer_profile_id = owner_profile_id;

alter table public.project_delegate_invitations
  alter column issuer_profile_id set not null,
  add constraint project_delegate_invitations_issuer_profile_id_fkey
    foreign key (issuer_profile_id)
      references public.profiles (id) on delete restrict,
  add constraint project_delegate_invitations_requested_role_valid check (
    requested_authority_role in ('co_organizer', 'co_creator')
  );

alter table public.project_delegate_invitations
  drop constraint project_delegate_invitations_resolution_valid,
  add constraint project_delegate_invitations_resolution_valid check (
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
      and revoked_by_profile_id is not null
      and revoked_at >= created_at
    )
  );

create index project_delegate_invitations_issuer_created_idx
  on public.project_delegate_invitations (
    issuer_profile_id,
    created_at desc,
    id
  );
create index project_delegate_invitations_pending_issuer_idx
  on public.project_delegate_invitations (project_id, issuer_profile_id, id)
  where status = 'pending';

alter table public.project_delegates
  add column granted_by_profile_id uuid,
  add column initial_authority_role text not null default 'co_organizer',
  add column authority_role text not null default 'co_organizer';

update public.project_delegates
set granted_by_profile_id = owner_profile_id;

alter table public.project_delegates
  alter column granted_by_profile_id set not null,
  add constraint project_delegates_granted_by_profile_id_fkey
    foreign key (granted_by_profile_id)
      references public.profiles (id) on delete restrict,
  add constraint project_delegates_initial_role_valid check (
    initial_authority_role in ('co_organizer', 'co_creator')
  ),
  add constraint project_delegates_authority_role_valid check (
    authority_role in ('co_organizer', 'co_creator')
  );

alter table public.project_delegates
  drop constraint project_delegates_revocation_valid,
  add constraint project_delegates_revocation_valid check (
    (
      revoked_at is null
      and revoked_by_profile_id is null
    )
    or (
      revoked_at is not null
      and revoked_by_profile_id is not null
      and revoked_at >= delegated_at
    )
  );

create index project_delegates_granted_by_profile_id_idx
  on public.project_delegates (granted_by_profile_id, delegated_at desc, id);
create index project_delegates_active_structural_idx
  on public.project_delegates (project_id, delegate_profile_id)
  where revoked_at is null and authority_role = 'co_creator';

comment on column public.project_delegate_invitations.owner_profile_id is
  'Immutable original Creator for the Project; issuer_profile_id identifies the structural actor who created the invitation.';
comment on column public.project_delegate_invitations.issuer_profile_id is
  'Creator or active Co-creator who actually issued this invitation.';
comment on column public.project_delegate_invitations.requested_authority_role is
  'Delegated authority the invitation grants on acceptance: co_organizer or co_creator.';
comment on column public.project_delegates.owner_profile_id is
  'Immutable original Creator for the Project; this is attribution, not necessarily the actor who granted the relationship.';
comment on column public.project_delegates.granted_by_profile_id is
  'Creator or active Co-creator who issued the accepted invitation that created this relationship.';
comment on column public.project_delegates.initial_authority_role is
  'Role granted by the accepted invitation; immutable provenance for the relationship.';
comment on column public.project_delegates.authority_role is
  'Current active delegated authority: co_organizer or co_creator.';

create table public.project_delegate_role_changes (
  id uuid primary key default gen_random_uuid(),
  delegate_id uuid not null,
  project_id uuid not null,
  delegate_profile_id uuid not null,
  from_authority_role text not null,
  to_authority_role text not null,
  changed_by_profile_id uuid not null
    constraint project_delegate_role_changes_changed_by_profile_id_fkey
      references public.profiles (id) on delete restrict,
  changed_at timestamptz not null default now(),
  constraint project_delegate_role_changes_delegate_identity_fkey
    foreign key (delegate_id, project_id, delegate_profile_id)
      references public.project_delegates (
        id,
        project_id,
        delegate_profile_id
      ) on delete restrict,
  constraint project_delegate_role_changes_from_role_valid check (
    from_authority_role in ('co_organizer', 'co_creator')
  ),
  constraint project_delegate_role_changes_to_role_valid check (
    to_authority_role in ('co_organizer', 'co_creator')
  ),
  constraint project_delegate_role_changes_role_changed check (
    from_authority_role <> to_authority_role
  )
);

comment on table public.project_delegate_role_changes is
  'Append-only delegated-authority role-change history. Initial grant provenance remains on the accepted invitation and delegate relationship.';

create index project_delegate_role_changes_delegate_changed_idx
  on public.project_delegate_role_changes (
    delegate_id,
    changed_at desc,
    id
  );
create index project_delegate_role_changes_project_changed_idx
  on public.project_delegate_role_changes (
    project_id,
    changed_at desc,
    id
  );
create index project_delegate_role_changes_actor_changed_idx
  on public.project_delegate_role_changes (
    changed_by_profile_id,
    changed_at desc,
    id
  );

alter table public.project_delegate_role_changes enable row level security;
revoke all privileges on table public.project_delegate_role_changes
  from public, anon, authenticated, service_role;

create or replace function private.validate_project_delegate_relationship()
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
    or invitation_record.issuer_profile_id <> new.granted_by_profile_id
    or invitation_record.requested_authority_role
      <> new.initial_authority_role
    or invitation_record.accepted_by_profile_id <> new.delegate_profile_id
    or invitation_record.accepted_at <> new.delegated_at then
    raise exception using
      errcode = '23514',
      message = 'A Project delegated-authority relationship must match its accepted invitation.';
  end if;

  return new;
end;
$$;

drop trigger project_delegates_validate_invitation
  on public.project_delegates;
create trigger project_delegates_validate_invitation
before insert or update of project_id, owner_profile_id, delegate_profile_id,
  invitation_id, delegated_at, granted_by_profile_id, initial_authority_role
on public.project_delegates
for each row execute function private.validate_project_delegate_relationship();

create or replace function private.profile_is_project_manager(
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
            and delegate.authority_role in ('co_organizer', 'co_creator')
        )
      )
  );
$$;

create function private.profile_has_project_structural_authority(
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
            and delegate.authority_role = 'co_creator'
        )
      )
  );
$$;

create function private.require_project_structural_authority(
  p_expected_profile_id uuid,
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
    p_expected_profile_id
  );
begin
  if not private.profile_has_project_structural_authority(
    p_project_id,
    current_profile_id
  ) then
    raise exception using
      errcode = '42501',
      message = 'Only a current Project structural actor can perform this operation.';
  end if;

  return current_profile_id;
end;
$$;

create or replace function private.record_project_delegate_event(
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
  invitation_issuer_profile_id uuid;
  invitation_requested_role text;
  relationship_grantor_profile_id uuid;
  relationship_authority_role text;
  identifier_payload jsonb;
begin
  if p_invitation_id is not null then
    select
      invitation.issuer_profile_id,
      invitation.requested_authority_role
    into invitation_issuer_profile_id, invitation_requested_role
    from public.project_delegate_invitations as invitation
    where invitation.id = p_invitation_id;
  end if;

  if p_delegate_id is not null then
    select
      delegate.granted_by_profile_id,
      delegate.authority_role
    into relationship_grantor_profile_id, relationship_authority_role
    from public.project_delegates as delegate
    where delegate.id = p_delegate_id;
  end if;

  identifier_payload := jsonb_strip_nulls(jsonb_build_object(
    'project_id', p_project_id,
    'project_kind', p_project_kind,
    'invitation_id', p_invitation_id,
    'delegate_id', p_delegate_id,
    'delegate_profile_id', p_delegate_profile_id,
    'actor_profile_id', p_actor_profile_id,
    'issuer_profile_id', invitation_issuer_profile_id,
    'requested_authority_role', invitation_requested_role,
    'granted_by_profile_id', relationship_grantor_profile_id,
    'authority_role', relationship_authority_role
  ));

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

create function private.invalidate_project_authority_invitations(
  p_project_id uuid,
  p_project_kind text,
  p_issuer_profile_id uuid,
  p_actor_profile_id uuid,
  p_revoked_at timestamptz
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  invalidated_invitation_id uuid;
begin
  for invalidated_invitation_id in
    update public.project_delegate_invitations as invitation
    set
      status = 'revoked',
      revoked_at = p_revoked_at,
      revoked_by_profile_id = p_actor_profile_id
    where invitation.project_id = p_project_id
      and invitation.issuer_profile_id = p_issuer_profile_id
      and invitation.status = 'pending'
    returning invitation.id
  loop
    perform private.record_project_delegate_event(
      'project.delegate_invite_invalidated',
      p_actor_profile_id,
      p_project_id,
      p_project_kind,
      invalidated_invitation_id,
      null,
      p_issuer_profile_id
    );
  end loop;
end;
$$;

create function public.create_project_delegate_invitation(
  p_expected_owner_profile_id uuid,
  p_project_id uuid,
  p_requested_authority_role text
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
  if p_requested_authority_role is null
    or p_requested_authority_role not in ('co_organizer', 'co_creator') then
    raise exception using
      errcode = '22023',
      message = 'The requested Project authority role is unsupported.';
  end if;

  select * into project_record
  from private.lock_project_for_delegate_management(p_project_id, true);

  if not private.profile_has_project_structural_authority(
    p_project_id,
    current_profile_id
  ) then
    raise exception using
      errcode = '42501',
      message = 'Only a current Project structural actor can create authority invitations.';
  end if;

  raw_token := translate(
    rtrim(encode(extensions.gen_random_bytes(32), 'base64'), '='),
    '+/',
    '-_'
  );

  insert into public.project_delegate_invitations (
    project_id,
    owner_profile_id,
    issuer_profile_id,
    requested_authority_role,
    token_digest,
    created_at,
    expires_at
  )
  values (
    p_project_id,
    project_record.owner_profile_id,
    current_profile_id,
    p_requested_authority_role,
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

create or replace function public.create_project_delegate_invitation(
  p_expected_owner_profile_id uuid,
  p_project_id uuid
)
returns table (
  invitation_id uuid,
  invite_token text,
  expires_at timestamptz
)
language sql
security definer
set search_path = ''
as $$
  select *
  from public.create_project_delegate_invitation(
    p_expected_owner_profile_id,
    p_project_id,
    'co_organizer'
  )
$$;

create or replace function public.revoke_project_delegate_invitation(
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
      message = 'The delegated-authority invitation is unavailable.';
  end if;

  select * into project_record
  from private.lock_project_for_delegate_management(
    invitation_record.project_id,
    false
  );

  if not private.profile_has_project_structural_authority(
    invitation_record.project_id,
    current_profile_id
  ) then
    raise exception using
      errcode = '42501',
      message = 'The delegated-authority invitation is unavailable.';
  end if;

  select * into invitation_record
  from public.project_delegate_invitations as invitation
  where invitation.id = p_invitation_id
  for update;

  if not found then
    raise exception using
      errcode = '42501',
      message = 'The delegated-authority invitation is unavailable.';
  end if;

  if invitation_record.status = 'revoked' then
    return invitation_record.id;
  end if;

  if invitation_record.status <> 'pending' then
    raise sqlstate 'PT409'
      using message = 'Only a pending delegated-authority invitation can be revoked.';
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

drop function public.preview_project_delegate_invitation(text);
create function public.preview_project_delegate_invitation(p_token text)
returns table (
  is_available boolean,
  project_id uuid,
  project_kind text,
  project_title text,
  owner_display_name text,
  expires_at timestamptz,
  requested_authority_role text,
  issuer_display_name text
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
      null::timestamptz, null::text, null::text;
    return;
  end if;

  select * into invitation_record
  from public.project_delegate_invitations as invitation
  where invitation.token_digest = extensions.digest(p_token, 'sha256')
    and invitation.status = 'pending'
    and statement_timestamp() < invitation.expires_at
    and private.project_allows_delegate_collaboration(invitation.project_id)
    and private.profile_has_project_structural_authority(
      invitation.project_id,
      invitation.issuer_profile_id
    );

  if not found then
    return query
    select false, null::uuid, null::text, null::text, null::text,
      null::timestamptz, null::text, null::text;
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
    invitation_record.expires_at,
    invitation_record.requested_authority_role,
    case
      when issuer_visibility.audience = 'public' then issuer.display_name
    end
  from public.projects as project
  join public.profiles as owner on owner.id = project.creator_profile_id
  join public.profiles as issuer
    on issuer.id = invitation_record.issuer_profile_id
  left join public.profile_field_visibility as visibility
    on visibility.profile_id = owner.id
    and visibility.field_key = 'display_name'
  left join public.profile_field_visibility as issuer_visibility
    on issuer_visibility.profile_id = issuer.id
    and issuer_visibility.field_key = 'display_name'
  left join public.proposals as proposal
    on proposal.id = project.id
    and project.project_kind = 'one_time'
  left join public.recurring_activities as activity
    on activity.id = project.id
    and project.project_kind = 'recurring'
  where project.id = invitation_record.project_id;
end;
$$;

create or replace function public.accept_project_delegate_invitation(
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
      message = 'The delegated-authority invitation is unavailable.';
  end if;

  select invitation.project_id into invitation_project_id
  from public.project_delegate_invitations as invitation
  where invitation.token_digest = extensions.digest(p_token, 'sha256');

  if not found then
    raise exception using
      errcode = '42501',
      message = 'The delegated-authority invitation is unavailable.';
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
      message = 'The delegated-authority invitation is unavailable.';
  end if;

  if invitation_record.status = 'accepted' then
    if invitation_record.accepted_by_profile_id <> current_profile_id then
      raise exception using
        errcode = '42501',
        message = 'The delegated-authority invitation is unavailable.';
    end if;

    select delegate.id into delegate_id
    from public.project_delegates as delegate
    where delegate.invitation_id = invitation_record.id
      and delegate.delegate_profile_id = current_profile_id;

    if delegate_id is null then
      raise exception using
        errcode = '55000',
        message = 'The accepted delegated-authority invitation has no matching relationship.';
    end if;

    return delegate_id;
  end if;

  if invitation_record.status <> 'pending'
    or statement_timestamp() >= invitation_record.expires_at
    or invitation_record.owner_profile_id <> project_record.owner_profile_id
    or not private.profile_has_project_structural_authority(
      invitation_record.project_id,
      invitation_record.issuer_profile_id
    ) then
    raise exception using
      errcode = '42501',
      message = 'The delegated-authority invitation is unavailable.';
  end if;

  if invitation_record.owner_profile_id = current_profile_id then
    raise exception using
      errcode = '55000',
      message = 'The original Project Creator cannot accept delegated authority.';
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
      message = 'This profile already has active delegated authority for the Project.';
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
    delegated_at,
    granted_by_profile_id,
    initial_authority_role,
    authority_role
  )
  values (
    invitation_record.project_id,
    invitation_record.owner_profile_id,
    current_profile_id,
    invitation_record.id,
    canonical_accepted_at,
    invitation_record.issuer_profile_id,
    invitation_record.requested_authority_role,
    invitation_record.requested_authority_role
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

drop function public.list_project_delegates_for_owner(uuid, uuid);
create function public.list_project_delegates_for_owner(
  p_expected_owner_profile_id uuid,
  p_project_id uuid
)
returns table (
  delegate_id uuid,
  delegate_profile_id uuid,
  delegate_display_name text,
  delegated_at timestamptz,
  authority_role text,
  granted_by_profile_id uuid,
  granted_by_display_name text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform private.require_project_structural_authority(
    p_expected_owner_profile_id,
    p_project_id
  );

  return query
  select
    delegate.id,
    delegate.delegate_profile_id,
    profile.display_name,
    delegate.delegated_at,
    delegate.authority_role,
    delegate.granted_by_profile_id,
    grantor.display_name
  from public.project_delegates as delegate
  join public.profiles as profile on profile.id = delegate.delegate_profile_id
  join public.profiles as grantor on grantor.id = delegate.granted_by_profile_id
  where delegate.project_id = p_project_id
    and delegate.revoked_at is null
  order by delegate.delegated_at, delegate.id;
end;
$$;

drop function public.list_project_delegate_invitations_for_owner(uuid, uuid);
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
  revoked_at timestamptz,
  requested_authority_role text,
  issuer_profile_id uuid,
  issuer_display_name text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform private.require_project_structural_authority(
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
    invitation.revoked_at,
    invitation.requested_authority_role,
    invitation.issuer_profile_id,
    issuer.display_name
  from public.project_delegate_invitations as invitation
  join public.profiles as issuer on issuer.id = invitation.issuer_profile_id
  where invitation.project_id = p_project_id
  order by invitation.created_at desc, invitation.id desc;
end;
$$;

create or replace function public.revoke_project_delegate(
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
      message = 'The Project delegated authority is unavailable.';
  end if;

  select * into project_record
  from private.lock_project_for_delegate_management(
    delegate_record.project_id,
    false
  );

  if not private.profile_has_project_structural_authority(
    delegate_record.project_id,
    current_profile_id
  ) then
    raise exception using
      errcode = '42501',
      message = 'The Project delegated authority is unavailable.';
  end if;

  select * into delegate_record
  from public.project_delegates as delegate
  where delegate.id = p_delegate_id
  for update;

  if not found then
    raise exception using
      errcode = '42501',
      message = 'The Project delegated authority is unavailable.';
  end if;

  if delegate_record.revoked_at is not null then
    return delegate_record.id;
  end if;

  update public.project_delegates
  set
    revoked_at = canonical_revoked_at,
    revoked_by_profile_id = current_profile_id
  where id = delegate_record.id;

  if delegate_record.authority_role = 'co_creator' then
    perform private.invalidate_project_authority_invitations(
      delegate_record.project_id,
      project_record.project_kind,
      delegate_record.delegate_profile_id,
      current_profile_id,
      canonical_revoked_at
    );
  end if;

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

create function public.change_project_delegate_role(
  p_expected_structural_profile_id uuid,
  p_delegate_id uuid,
  p_authority_role text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_participation_identity(
    p_expected_structural_profile_id
  );
  delegate_record public.project_delegates%rowtype;
  project_record record;
  changed_at timestamptz := statement_timestamp();
  role_change_id uuid;
  event_payload jsonb;
begin
  if p_authority_role is null
    or p_authority_role not in ('co_organizer', 'co_creator') then
    raise exception using
      errcode = '22023',
      message = 'The requested Project authority role is unsupported.';
  end if;

  select * into delegate_record
  from public.project_delegates as delegate
  where delegate.id = p_delegate_id;

  if not found then
    raise exception using
      errcode = '42501',
      message = 'The Project delegated authority is unavailable.';
  end if;

  select * into project_record
  from private.lock_project_for_delegate_management(
    delegate_record.project_id,
    false
  );

  if not private.profile_has_project_structural_authority(
    delegate_record.project_id,
    current_profile_id
  ) then
    raise exception using
      errcode = '42501',
      message = 'The Project delegated authority is unavailable.';
  end if;

  select * into delegate_record
  from public.project_delegates as delegate
  where delegate.id = p_delegate_id
  for update;

  if not found or delegate_record.revoked_at is not null then
    raise exception using
      errcode = '42501',
      message = 'The Project delegated authority is unavailable.';
  end if;

  if delegate_record.authority_role = p_authority_role then
    return delegate_record.id;
  end if;

  update public.project_delegates
  set authority_role = p_authority_role
  where id = delegate_record.id;

  insert into public.project_delegate_role_changes (
    delegate_id,
    project_id,
    delegate_profile_id,
    from_authority_role,
    to_authority_role,
    changed_by_profile_id,
    changed_at
  )
  values (
    delegate_record.id,
    delegate_record.project_id,
    delegate_record.delegate_profile_id,
    delegate_record.authority_role,
    p_authority_role,
    current_profile_id,
    changed_at
  )
  returning id into role_change_id;

  if delegate_record.authority_role = 'co_creator'
    and p_authority_role = 'co_organizer' then
    perform private.invalidate_project_authority_invitations(
      delegate_record.project_id,
      project_record.project_kind,
      delegate_record.delegate_profile_id,
      current_profile_id,
      changed_at
    );
  end if;

  event_payload := jsonb_build_object(
    'project_id', delegate_record.project_id,
    'project_kind', project_record.project_kind,
    'delegate_id', delegate_record.id,
    'delegate_profile_id', delegate_record.delegate_profile_id,
    'actor_profile_id', current_profile_id,
    'role_change_id', role_change_id,
    'from_authority_role', delegate_record.authority_role,
    'to_authority_role', p_authority_role
  );

  insert into private.audit_events (
    action,
    actor_user_id,
    target_type,
    target_id,
    metadata
  ) values (
    'project.delegate_role_changed',
    current_profile_id,
    'project',
    delegate_record.project_id,
    event_payload
  );

  insert into private.outbox_events (event_type, payload)
  values ('project.delegate_role_changed', event_payload);

  return delegate_record.id;
end;
$$;

create or replace function public.get_own_project_management_role(
  p_expected_profile_id uuid,
  p_project_id uuid
)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_participation_identity(
    p_expected_profile_id
  );
  management_role text;
begin
  select case
    when project.creator_profile_id = current_profile_id then 'creator'
    else coalesce(
      (
        select delegate.authority_role
        from public.project_delegates as delegate
        where delegate.project_id = project.id
          and delegate.delegate_profile_id = current_profile_id
          and delegate.revoked_at is null
      ),
      'none'
    )
  end
  into management_role
  from public.projects as project
  where project.id = p_project_id;

  return coalesce(management_role, 'none');
end;
$$;

drop function public.list_own_delegated_projects(uuid);
create function public.list_own_delegated_projects(
  p_expected_profile_id uuid
)
returns table (
  project_id uuid,
  project_kind text,
  project_title text,
  project_status text,
  delegated_at timestamptz,
  authority_role text
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
  return query
  select
    project.id,
    project.project_kind,
    case project.project_kind
      when 'one_time' then proposal.title
      when 'recurring' then activity.title
    end,
    case project.project_kind
      when 'one_time' then case
        when proposal.lifecycle_state = 'cancelled' then 'cancelled'
        when proposal.ends_at <= statement_timestamp() then 'completed'
        else proposal.lifecycle_state
      end
      when 'recurring' then activity.lifecycle_state
    end,
    delegate.delegated_at,
    delegate.authority_role
  from public.project_delegates as delegate
  join public.projects as project on project.id = delegate.project_id
  left join public.proposals as proposal
    on proposal.id = project.id
    and project.project_kind = 'one_time'
  left join public.recurring_activities as activity
    on activity.id = project.id
    and project.project_kind = 'recurring'
  where delegate.delegate_profile_id = current_profile_id
    and delegate.revoked_at is null
    and delegate.authority_role in ('co_organizer', 'co_creator')
    and (
      (
        project.project_kind = 'one_time'
        and proposal.id is not null
        and proposal.lifecycle_state <> 'draft'
      )
      or (
        project.project_kind = 'recurring'
        and activity.id is not null
        and activity.lifecycle_state <> 'draft'
      )
    )
  order by delegate.delegated_at desc, project.id;
end;
$$;

create or replace function public.update_own_proposal(
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

  if proposal.id is null
    or (
      proposal.creator_profile_id <> current_profile_id
      and not private.profile_has_project_structural_authority(
        p_proposal_id,
        current_profile_id
      )
    ) then
    raise exception using
      errcode = '42501',
      message = 'The current user does not own this proposal.';
  end if;

  if proposal.creator_profile_id <> current_profile_id
    and proposal.lifecycle_state = 'draft' then
    raise exception using
      errcode = '42501',
      message = 'Only the original Creator can edit a proposal draft.';
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

  insert into private.audit_events (
    action,
    actor_user_id,
    target_type,
    target_id
  ) values (
    'proposal.updated',
    current_profile_id,
    'proposal',
    p_proposal_id
  );

  insert into private.outbox_events (event_type, payload)
  values (
    'proposal.updated',
    jsonb_build_object(
      'proposal_id', p_proposal_id,
      'actor_id', current_profile_id
    )
  );

  return p_proposal_id;
end;
$$;

create or replace function public.cancel_proposal(
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

  if proposal.id is null
    or not private.profile_has_project_structural_authority(
      p_proposal_id,
      current_profile_id
    ) then
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
  ) values (
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

create or replace function public.get_own_proposal(
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
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_expected_identity(
    p_expected_creator_profile_id
  );
  proposal_record public.proposals%rowtype;
begin
  select * into proposal_record
  from public.proposals as proposal
  where proposal.id = p_proposal_id;

  if not found
    or (
      proposal_record.creator_profile_id <> current_profile_id
      and not private.profile_has_project_structural_authority(
        p_proposal_id,
        current_profile_id
      )
    )
    or (
      proposal_record.creator_profile_id <> current_profile_id
      and proposal_record.lifecycle_state = 'draft'
    ) then
    raise exception using
      errcode = '42501',
      message = 'The proposal management record is unavailable.';
  end if;

  return query
  select
    proposal.id,
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
    end,
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
    ),
    meeting.exact_meeting_text,
    meeting.exact_location_visibility,
    proposal.created_at,
    proposal.updated_at,
    proposal.published_at,
    proposal.cancelled_at
  from public.proposals as proposal
  join public.proposal_meeting_details as meeting
    on meeting.proposal_id = proposal.id
  where proposal.id = p_proposal_id;
end;
$$;

create or replace function public.update_own_recurring_activity(
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

  if activity.id is null
    or (
      activity.creator_profile_id <> current_profile_id
      and not private.profile_has_project_structural_authority(
        p_recurring_activity_id,
        current_profile_id
      )
    ) then
    raise exception using
      errcode = '42501',
      message = 'The current user does not own this recurring activity.';
  end if;

  if activity.creator_profile_id <> current_profile_id
    and activity.lifecycle_state = 'draft' then
    raise exception using
      errcode = '42501',
      message = 'Only the original Creator can edit a recurring activity draft.';
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

  insert into private.audit_events (
    action,
    actor_user_id,
    target_type,
    target_id
  ) values (
    'recurring_activity.updated',
    current_profile_id,
    'recurring_activity',
    p_recurring_activity_id
  );

  insert into private.outbox_events (event_type, payload)
  values (
    'recurring_activity.updated',
    jsonb_build_object(
      'recurring_activity_id', p_recurring_activity_id,
      'actor_id', current_profile_id
    )
  );

  return p_recurring_activity_id;
end;
$$;

create or replace function public.pause_recurring_activity(
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

  if activity.id is null
    or not private.profile_has_project_structural_authority(
      p_recurring_activity_id,
      current_profile_id
    ) then
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
  ) values (
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

create or replace function public.resume_recurring_activity(
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

  if activity.id is null
    or not private.profile_has_project_structural_authority(
      p_recurring_activity_id,
      current_profile_id
    ) then
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
  ) values (
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

create or replace function public.end_recurring_activity(
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

  if activity.id is null
    or not private.profile_has_project_structural_authority(
      p_recurring_activity_id,
      current_profile_id
    ) then
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
  ) values (
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

create or replace function public.get_own_recurring_activity(
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
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_expected_recurring_activity_identity(
    p_expected_creator_profile_id
  );
  activity_record public.recurring_activities%rowtype;
begin
  select * into activity_record
  from public.recurring_activities as activity
  where activity.id = p_recurring_activity_id;

  if not found
    or (
      activity_record.creator_profile_id <> current_profile_id
      and not private.profile_has_project_structural_authority(
        p_recurring_activity_id,
        current_profile_id
      )
    )
    or (
      activity_record.creator_profile_id <> current_profile_id
      and activity_record.lifecycle_state = 'draft'
    ) then
    raise exception using
      errcode = '42501',
      message = 'The recurring activity management record is unavailable.';
  end if;

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
  where activity.id = p_recurring_activity_id;
end;
$$;

revoke all privileges on function
  private.profile_has_project_structural_authority(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function
  private.require_project_structural_authority(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function
  private.invalidate_project_authority_invitations(
    uuid,
    text,
    uuid,
    uuid,
    timestamptz
  ) from public, anon, authenticated, service_role;

revoke all privileges on function
  public.create_project_delegate_invitation(uuid, uuid, text)
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
  public.change_project_delegate_role(uuid, uuid, text)
  from public, anon, authenticated, service_role;
revoke all privileges on function
  public.get_own_project_management_role(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function
  public.list_own_delegated_projects(uuid)
  from public, anon, authenticated, service_role;

grant execute on function
  public.create_project_delegate_invitation(uuid, uuid, text)
  to authenticated;
grant execute on function
  public.create_project_delegate_invitation(uuid, uuid)
  to authenticated;
grant execute on function
  public.revoke_project_delegate_invitation(uuid, uuid)
  to authenticated;
grant execute on function public.preview_project_delegate_invitation(text)
  to anon, authenticated;
grant execute on function
  public.accept_project_delegate_invitation(uuid, text)
  to authenticated;
grant execute on function
  public.list_project_delegates_for_owner(uuid, uuid)
  to authenticated;
grant execute on function
  public.list_project_delegate_invitations_for_owner(uuid, uuid)
  to authenticated;
grant execute on function public.revoke_project_delegate(uuid, uuid)
  to authenticated;
grant execute on function
  public.change_project_delegate_role(uuid, uuid, text)
  to authenticated;
grant execute on function
  public.get_own_project_management_role(uuid, uuid)
  to authenticated;
grant execute on function public.list_own_delegated_projects(uuid)
  to authenticated;

comment on function private.profile_is_project_manager(uuid, uuid) is
  'Canonical operational authority: original Creator, active Co-creator, or active Co-organizer.';
comment on function
  private.profile_has_project_structural_authority(uuid, uuid) is
  'Canonical structural authority: immutable original Creator or an active Co-creator; Co-organizers fail closed.';
comment on function
  private.require_project_structural_authority(uuid, uuid) is
  'Identity-bound guard for Project role management and other structural operations.';
comment on function
  private.invalidate_project_authority_invitations(
    uuid,
    text,
    uuid,
    uuid,
    timestamptz
  ) is
  'Atomically revokes every pending invitation issued by a Co-creator who loses structural authority and records each invalidation.';
comment on function
  public.create_project_delegate_invitation(uuid, uuid, text) is
  'Structural-actor creation of a seven-day Co-organizer or Co-creator bearer invitation; plaintext is returned once and only its digest is stored.';
comment on function
  public.create_project_delegate_invitation(uuid, uuid) is
  'Backward-compatible Co-organizer invitation overload for existing 07C2B clients.';
comment on function public.preview_project_delegate_invitation(text) is
  'Minimal fail-closed preview including the requested role; stale issuer authority is treated as unavailable.';
comment on function
  public.accept_project_delegate_invitation(uuid, text) is
  'Atomically grants the requested delegated role while preserving original-Creator attribution and truthful issuer provenance.';
comment on function
  public.list_project_delegates_for_owner(uuid, uuid) is
  'Lists active delegated authority and grant provenance for a current structural actor.';
comment on function
  public.list_project_delegate_invitations_for_owner(uuid, uuid) is
  'Lists role-aware invitation history and issuer provenance for a current structural actor.';
comment on function public.revoke_project_delegate(uuid, uuid) is
  'Structurally revokes delegated authority without changing participation; Co-creator-issued pending grants are invalidated atomically.';
comment on function
  public.change_project_delegate_role(uuid, uuid, text) is
  'Atomically promotes or demotes active delegated authority, appends role history, and invalidates grants issued by a demoted Co-creator.';
comment on function
  public.get_own_project_management_role(uuid, uuid) is
  'Identity-bound creator/co_creator/co_organizer/none result for one exact Project; no roster or participation state is disclosed.';
comment on function public.list_own_delegated_projects(uuid) is
  'Lists the current profile non-draft delegated Projects with its co_creator or co_organizer role; original ownership is never fabricated.';
comment on function
  public.update_own_proposal(uuid, uuid, text, text, text, timestamptz, timestamptz, text, text, text, text, text, text, text, uuid[], text[]) is
  'Updates an original-Creator draft or a lifecycle-eligible published Proposal as Creator/Co-creator and attributes the actual actor.';
comment on function public.cancel_proposal(uuid, uuid) is
  'Terminally cancels a lifecycle-eligible published Proposal as Creator/Co-creator without deleting history.';
comment on function public.get_own_proposal(uuid, uuid) is
  'Returns exact management content to the Creator, or to an active Co-creator only after publication.';
comment on function
  public.update_own_recurring_activity(uuid, uuid, text, text, text, text, text, text, text, text, text, text, text, integer, integer, time, integer, text, date) is
  'Updates an original-Creator draft or a non-ended published/paused Tavolo as Creator/Co-creator and attributes the actual actor.';
comment on function public.pause_recurring_activity(uuid, uuid) is
  'Pauses a published Tavolo as Creator/Co-creator without changing original-Creator attribution.';
comment on function public.resume_recurring_activity(uuid, uuid) is
  'Resumes a paused Tavolo as Creator/Co-creator after existing schedule validation.';
comment on function public.end_recurring_activity(uuid, uuid) is
  'Ends a published or paused Tavolo as Creator/Co-creator while retaining canonical history.';
comment on function public.get_own_recurring_activity(uuid, uuid) is
  'Returns exact management content to the Creator, or to an active Co-creator only after publication.';
