create table public.projects (
  id uuid primary key,
  project_kind text not null
    constraint projects_kind_valid check (project_kind in ('one_time', 'recurring')),
  creator_profile_id uuid not null
    constraint projects_creator_profile_id_fkey
      references public.profiles (id) on delete restrict,
  created_at timestamptz not null
);

comment on table public.projects is
  'Private cross-domain identity anchor; concrete proposal and recurring-activity rows remain authoritative for content and lifecycle.';
comment on column public.projects.creator_profile_id is
  'Synchronized from the concrete source row; ownership transfer is not supported.';

create index projects_creator_profile_id_created_at_idx
  on public.projects (creator_profile_id, created_at desc, id);

alter table public.projects enable row level security;
revoke all privileges on table public.projects
  from public, anon, authenticated, service_role;

do $$
begin
  if exists (
    select 1
    from public.proposals as proposal
    join public.recurring_activities as activity on activity.id = proposal.id
  ) then
    raise exception using
      errcode = '23505',
      message = 'A project UUID exists in both proposals and recurring activities.';
  end if;
end;
$$;

insert into public.projects (id, project_kind, creator_profile_id, created_at)
select id, 'one_time', creator_profile_id, created_at
from public.proposals;

insert into public.projects (id, project_kind, creator_profile_id, created_at)
select id, 'recurring', creator_profile_id, created_at
from public.recurring_activities;

create function private.register_project_source()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  source_kind text := tg_argv[0];
  existing_project public.projects%rowtype;
begin
  select * into existing_project
  from public.projects as project
  where project.id = new.id;

  if found then
    raise exception using
      errcode = '23505',
      message = format(
        'Project UUID %s is already registered as %s.',
        new.id,
        existing_project.project_kind
      );
  end if;

  insert into public.projects (id, project_kind, creator_profile_id, created_at)
  values (new.id, source_kind, new.creator_profile_id, new.created_at);

  return new;
end;
$$;

create function private.protect_project_source_identity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.id <> old.id or new.creator_profile_id <> old.creator_profile_id then
    raise exception using
      errcode = '55000',
      message = 'Project IDs and creators are immutable.';
  end if;

  return new;
end;
$$;

create function private.unregister_project_source()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  source_kind text := tg_argv[0];
begin
  if exists (
    select 1
    from public.project_join_requests as request
    where request.project_id = old.id
  ) or exists (
    select 1
    from public.project_memberships as membership
    where membership.project_id = old.id
  ) then
    raise exception using
      errcode = '23503',
      message = 'A project with participation history cannot be deleted.';
  end if;

  delete from public.projects as project
  where project.id = old.id
    and project.project_kind = source_kind;

  if not found then
    raise exception using
      errcode = '55000',
      message = 'The concrete activity has no matching project identity.';
  end if;

  return old;
end;
$$;

create trigger proposals_register_project
after insert on public.proposals
for each row execute function private.register_project_source('one_time');

create trigger proposals_protect_project_identity
before update of id, creator_profile_id on public.proposals
for each row execute function private.protect_project_source_identity();

create trigger proposals_unregister_project
after delete on public.proposals
for each row execute function private.unregister_project_source('one_time');

create trigger recurring_activities_register_project
after insert on public.recurring_activities
for each row execute function private.register_project_source('recurring');

create trigger recurring_activities_protect_project_identity
before update of id, creator_profile_id on public.recurring_activities
for each row execute function private.protect_project_source_identity();

create trigger recurring_activities_unregister_project
after delete on public.recurring_activities
for each row execute function private.unregister_project_source('recurring');

create table public.project_join_requests (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null
    constraint project_join_requests_project_id_fkey
      references public.projects (id) on delete restrict,
  requester_profile_id uuid not null
    constraint project_join_requests_requester_profile_id_fkey
      references public.profiles (id) on delete restrict,
  status text not null default 'pending'
    constraint project_join_requests_status_valid check (
      status in ('pending', 'accepted', 'rejected', 'withdrawn')
    ),
  request_message text
    constraint project_join_requests_message_valid check (
      request_message is null
      or (
        request_message = btrim(request_message)
        and char_length(request_message) between 1 and 500
      )
    ),
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  resolved_by_profile_id uuid
    constraint project_join_requests_resolved_by_profile_id_fkey
      references public.profiles (id) on delete restrict,
  constraint project_join_requests_resolution_valid check (
    (
      status = 'pending'
      and resolved_at is null
      and resolved_by_profile_id is null
    )
    or (
      status <> 'pending'
      and resolved_at is not null
      and resolved_by_profile_id is not null
      and resolved_at >= created_at
    )
  ),
  constraint project_join_requests_withdraw_actor_valid check (
    status <> 'withdrawn' or resolved_by_profile_id = requester_profile_id
  ),
  constraint project_join_requests_identity_unique
    unique (id, project_id, requester_profile_id)
);

comment on table public.project_join_requests is
  'Private append-preserving attempts to join a one-time or recurring project.';
comment on column public.project_join_requests.request_message is
  'Optional private requester-to-organizer message, canonically trimmed and limited to 500 characters.';

create unique index project_join_requests_one_pending_idx
  on public.project_join_requests (project_id, requester_profile_id)
  where status = 'pending';
create index project_join_requests_project_created_at_idx
  on public.project_join_requests (project_id, created_at desc, id);
create index project_join_requests_requester_created_at_idx
  on public.project_join_requests (requester_profile_id, created_at desc, id);
create index project_join_requests_resolved_by_profile_id_idx
  on public.project_join_requests (resolved_by_profile_id)
  where resolved_by_profile_id is not null;

alter table public.project_join_requests enable row level security;
revoke all privileges on table public.project_join_requests
  from public, anon, authenticated, service_role;

create table public.project_memberships (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null
    constraint project_memberships_project_id_fkey
      references public.projects (id) on delete restrict,
  participant_profile_id uuid not null
    constraint project_memberships_participant_profile_id_fkey
      references public.profiles (id) on delete restrict,
  originating_request_id uuid not null unique,
  joined_at timestamptz not null,
  left_at timestamptz,
  removed_at timestamptz,
  removed_by_profile_id uuid
    constraint project_memberships_removed_by_profile_id_fkey
      references public.profiles (id) on delete restrict,
  constraint project_memberships_end_state_valid check (
    not (left_at is not null and removed_at is not null)
    and (left_at is null or left_at >= joined_at)
    and (removed_at is null or removed_at >= joined_at)
    and (
      (removed_at is null and removed_by_profile_id is null)
      or (removed_at is not null and removed_by_profile_id is not null)
    )
  ),
  constraint project_memberships_originating_request_fkey
    foreign key (originating_request_id, project_id, participant_profile_id)
      references public.project_join_requests (
        id,
        project_id,
        requester_profile_id
      )
      on delete restrict
);

comment on table public.project_memberships is
  'Canonical accepted participation history; rows are ended, never deleted, when a participant leaves or is removed.';

create unique index project_memberships_one_current_idx
  on public.project_memberships (project_id, participant_profile_id)
  where left_at is null and removed_at is null;
create index project_memberships_project_joined_at_idx
  on public.project_memberships (project_id, joined_at desc, id);
create index project_memberships_participant_joined_at_idx
  on public.project_memberships (participant_profile_id, joined_at desc, id);
create index project_memberships_removed_by_profile_id_idx
  on public.project_memberships (removed_by_profile_id)
  where removed_by_profile_id is not null;

alter table public.project_memberships enable row level security;
revoke all privileges on table public.project_memberships
  from public, anon, authenticated, service_role;

create function private.require_participation_identity(p_expected_profile_id uuid)
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
      message = 'Authentication is required for project participation.';
  end if;

  if p_expected_profile_id is null or p_expected_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'The authenticated user does not match the expected participant identity.';
  end if;

  return current_profile_id;
end;
$$;

create function private.require_complete_participation_profile(
  p_expected_profile_id uuid
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
  if not exists (
    select 1
    from public.profiles as profile
    where profile.id = current_profile_id
      and profile.display_name is not null
  ) then
    raise exception using
      errcode = '55000',
      message = 'A complete profile is required to request project participation.';
  end if;

  return current_profile_id;
end;
$$;

create function private.lock_project_for_participation(
  p_project_id uuid,
  p_require_joinable boolean
)
returns table (project_kind text, creator_profile_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
declare
  registry public.projects%rowtype;
  source_creator_profile_id uuid;
  source_is_joinable boolean;
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
    into source_creator_profile_id, source_is_joinable
    from public.proposals as proposal
    where proposal.id = registry.id
    for share;
  elsif registry.project_kind = 'recurring' then
    select
      activity.creator_profile_id,
      activity.lifecycle_state = 'published'
    into source_creator_profile_id, source_is_joinable
    from public.recurring_activities as activity
    where activity.id = registry.id
    for share;
  end if;

  if not found or source_creator_profile_id <> registry.creator_profile_id then
    raise exception using
      errcode = '55000',
      message = 'The project registry is inconsistent with its concrete activity.';
  end if;

  if p_require_joinable and not source_is_joinable then
    raise exception using
      errcode = '55000',
      message = 'This project is not accepting participation requests.';
  end if;

  -- Every participation transition locks the concrete row first and the shared row second.
  -- This prevents lifecycle changes from crossing a request/accept decision boundary.
  select * into registry
  from public.projects as project
  where project.id = p_project_id
  for update;

  return query select registry.project_kind, registry.creator_profile_id;
end;
$$;

create function private.require_project_creator(
  p_expected_creator_profile_id uuid,
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
    p_expected_creator_profile_id
  );
begin
  if not exists (
    select 1
    from public.projects as project
    where project.id = p_project_id
      and project.creator_profile_id = current_profile_id
  ) then
    raise exception using
      errcode = '42501',
      message = 'Only the project creator can perform this operation.';
  end if;

  return current_profile_id;
end;
$$;

create function private.record_project_participation_event(
  p_event_type text,
  p_actor_profile_id uuid,
  p_project_id uuid,
  p_metadata jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
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
    p_metadata
  );

  insert into private.outbox_events (event_type, payload)
  values (
    p_event_type,
    p_metadata || jsonb_build_object(
      'project_id', p_project_id,
      'actor_profile_id', p_actor_profile_id
    )
  );
end;
$$;

create function public.request_to_join_project(
  p_expected_requester_profile_id uuid,
  p_project_id uuid,
  p_request_message text default null
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
  new_request_id uuid;
begin
  if normalized_message is not null and char_length(normalized_message) > 500 then
    raise exception using
      errcode = '22023',
      message = 'A participation request message must contain at most 500 characters.';
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

  insert into public.project_join_requests (
    project_id,
    requester_profile_id,
    request_message
  )
  values (p_project_id, current_profile_id, normalized_message)
  returning id into new_request_id;

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

create function public.withdraw_project_join_request(
  p_expected_requester_profile_id uuid,
  p_request_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_participation_identity(
    p_expected_requester_profile_id
  );
  request_record public.project_join_requests%rowtype;
  project_record record;
  transition_time timestamptz := statement_timestamp();
begin
  select * into request_record
  from public.project_join_requests as request
  where request.id = p_request_id;

  if not found then
    raise exception using errcode = 'P0002', message = 'The join request does not exist.';
  end if;

  select * into project_record
  from private.lock_project_for_participation(request_record.project_id, false);

  select * into request_record
  from public.project_join_requests as request
  where request.id = p_request_id
  for update;

  if request_record.requester_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'Only the requester can withdraw this join request.';
  end if;

  if request_record.status <> 'pending' then
    raise exception using
      errcode = '55000',
      message = 'Only a pending join request can be withdrawn.';
  end if;

  update public.project_join_requests
  set
    status = 'withdrawn',
    resolved_at = transition_time,
    resolved_by_profile_id = current_profile_id
  where id = request_record.id;

  perform private.record_project_participation_event(
    'project.join_request_withdrawn',
    current_profile_id,
    request_record.project_id,
    jsonb_build_object(
      'project_kind', project_record.project_kind,
      'request_id', request_record.id,
      'requester_profile_id', current_profile_id,
      'status', 'withdrawn'
    )
  );

  return request_record.id;
end;
$$;

create function public.accept_project_join_request(
  p_expected_creator_profile_id uuid,
  p_request_id uuid
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
  new_membership_id uuid;
begin
  select * into request_record
  from public.project_join_requests as request
  where request.id = p_request_id;

  if not found then
    raise exception using errcode = 'P0002', message = 'The join request does not exist.';
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

create function public.reject_project_join_request(
  p_expected_creator_profile_id uuid,
  p_request_id uuid
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
begin
  select * into request_record
  from public.project_join_requests as request
  where request.id = p_request_id;

  if not found then
    raise exception using errcode = 'P0002', message = 'The join request does not exist.';
  end if;

  select * into project_record
  from private.lock_project_for_participation(request_record.project_id, false);

  select * into request_record
  from public.project_join_requests as request
  where request.id = p_request_id
  for update;

  if project_record.creator_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'Only the project creator can reject join requests.';
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

create function public.leave_project(
  p_expected_participant_profile_id uuid,
  p_membership_id uuid
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
  membership_record public.project_memberships%rowtype;
  project_record record;
  transition_time timestamptz := statement_timestamp();
begin
  select * into membership_record
  from public.project_memberships as membership
  where membership.id = p_membership_id;

  if not found then
    raise exception using errcode = 'P0002', message = 'The membership does not exist.';
  end if;

  select * into project_record
  from private.lock_project_for_participation(membership_record.project_id, false);

  select * into membership_record
  from public.project_memberships as membership
  where membership.id = p_membership_id
  for update;

  if membership_record.participant_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'Only the current participant can leave this membership.';
  end if;

  if membership_record.left_at is not null or membership_record.removed_at is not null then
    raise exception using
      errcode = '55000',
      message = 'Only a current project membership can be left.';
  end if;

  update public.project_memberships
  set left_at = transition_time
  where id = membership_record.id;

  perform private.record_project_participation_event(
    'project.participant_left',
    current_profile_id,
    membership_record.project_id,
    jsonb_build_object(
      'project_kind', project_record.project_kind,
      'membership_id', membership_record.id,
      'participant_profile_id', current_profile_id,
      'status', 'left'
    )
  );

  return membership_record.id;
end;
$$;

create function public.remove_project_member(
  p_expected_creator_profile_id uuid,
  p_membership_id uuid
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
  membership_record public.project_memberships%rowtype;
  project_record record;
  transition_time timestamptz := statement_timestamp();
begin
  select * into membership_record
  from public.project_memberships as membership
  where membership.id = p_membership_id;

  if not found then
    raise exception using errcode = 'P0002', message = 'The membership does not exist.';
  end if;

  select * into project_record
  from private.lock_project_for_participation(membership_record.project_id, false);

  select * into membership_record
  from public.project_memberships as membership
  where membership.id = p_membership_id
  for update;

  if project_record.creator_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'Only the project creator can remove a participant.';
  end if;

  if membership_record.left_at is not null or membership_record.removed_at is not null then
    raise exception using
      errcode = '55000',
      message = 'Only a current project membership can be removed.';
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

create function public.list_own_project_join_requests(
  p_expected_requester_profile_id uuid
)
returns table (
  request_id uuid,
  project_id uuid,
  project_kind text,
  status text,
  request_message text,
  created_at timestamptz,
  resolved_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_participation_identity(
    p_expected_requester_profile_id
  );
begin
  return query
  select
    request.id,
    request.project_id,
    project.project_kind,
    request.status,
    request.request_message,
    request.created_at,
    request.resolved_at
  from public.project_join_requests as request
  join public.projects as project on project.id = request.project_id
  where request.requester_profile_id = current_profile_id
  order by request.created_at desc, request.id;
end;
$$;

create function public.list_project_join_requests(
  p_expected_creator_profile_id uuid,
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
  perform private.require_project_creator(
    p_expected_creator_profile_id,
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

create function public.list_own_project_memberships(
  p_expected_participant_profile_id uuid
)
returns table (
  membership_id uuid,
  project_id uuid,
  project_kind text,
  originating_request_id uuid,
  membership_status text,
  joined_at timestamptz,
  left_at timestamptz,
  removed_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_participation_identity(
    p_expected_participant_profile_id
  );
begin
  return query
  select
    membership.id,
    membership.project_id,
    project.project_kind,
    membership.originating_request_id,
    case
      when membership.left_at is not null then 'left'
      when membership.removed_at is not null then 'removed'
      else 'current'
    end,
    membership.joined_at,
    membership.left_at,
    membership.removed_at
  from public.project_memberships as membership
  join public.projects as project on project.id = membership.project_id
  where membership.participant_profile_id = current_profile_id
  order by membership.joined_at desc, membership.id;
end;
$$;

create function public.list_project_members(
  p_expected_creator_profile_id uuid,
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
  perform private.require_project_creator(
    p_expected_creator_profile_id,
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
  join public.profiles as profile on profile.id = membership.participant_profile_id
  where membership.project_id = p_project_id
  order by membership.joined_at desc, membership.id;
end;
$$;

create function public.get_project_participant_meeting_details(
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
    raise exception using errcode = 'P0002', message = 'The project does not exist.';
  end if;

  if registry.creator_profile_id <> current_profile_id
    and not exists (
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

revoke all privileges on function private.register_project_source()
  from public, anon, authenticated, service_role;
revoke all privileges on function private.protect_project_source_identity()
  from public, anon, authenticated, service_role;
revoke all privileges on function private.unregister_project_source()
  from public, anon, authenticated, service_role;
revoke all privileges on function private.require_participation_identity(uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function private.require_complete_participation_profile(uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function private.lock_project_for_participation(uuid, boolean)
  from public, anon, authenticated, service_role;
revoke all privileges on function private.require_project_creator(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function private.record_project_participation_event(text, uuid, uuid, jsonb)
  from public, anon, authenticated, service_role;

grant execute on function public.request_to_join_project(uuid, uuid, text)
  to authenticated;
grant execute on function public.withdraw_project_join_request(uuid, uuid)
  to authenticated;
grant execute on function public.accept_project_join_request(uuid, uuid)
  to authenticated;
grant execute on function public.reject_project_join_request(uuid, uuid)
  to authenticated;
grant execute on function public.leave_project(uuid, uuid)
  to authenticated;
grant execute on function public.remove_project_member(uuid, uuid)
  to authenticated;
grant execute on function public.list_own_project_join_requests(uuid)
  to authenticated;
grant execute on function public.list_project_join_requests(uuid, uuid)
  to authenticated;
grant execute on function public.list_own_project_memberships(uuid)
  to authenticated;
grant execute on function public.list_project_members(uuid, uuid)
  to authenticated;
grant execute on function public.get_project_participant_meeting_details(uuid, uuid)
  to authenticated;

comment on function public.request_to_join_project(uuid, uuid, text) is
  'Creates one private pending request for the expected complete-profile identity while the concrete project is joinable.';
comment on function public.accept_project_join_request(uuid, uuid) is
  'Atomically accepts a pending request and creates one current membership; its outbox event is the stable Plan 07 chat-trigger candidate.';
comment on function public.get_project_participant_meeting_details(uuid, uuid) is
  'Returns protected operational meeting information only to the creator or a current accepted participant.';
