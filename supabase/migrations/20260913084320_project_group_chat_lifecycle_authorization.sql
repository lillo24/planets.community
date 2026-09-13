create table public.project_group_chats (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null
    constraint project_group_chats_project_id_fkey
      references public.projects (id) on delete restrict,
  activated_at timestamptz not null,
  created_at timestamptz not null default statement_timestamp(),
  constraint project_group_chats_project_id_key unique (project_id),
  constraint project_group_chats_creation_not_before_activation check (
    created_at >= activated_at
  )
);

comment on table public.project_group_chats is
  'Canonical structural anchor for one Project group conversation; message persistence and transport are deferred to Plan 07B2.';
comment on column public.project_group_chats.activated_at is
  'Logical activation time: the earliest canonical accepted membership joined_at for the Project.';

alter table public.project_group_chats enable row level security;
revoke all privileges on table public.project_group_chats
  from public, anon, authenticated, service_role;

create function private.validate_project_group_chat_anchor()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  expected_activated_at timestamptz;
begin
  if tg_op = 'UPDATE' and (
    new.id is distinct from old.id
    or new.project_id is distinct from old.project_id
    or new.created_at is distinct from old.created_at
  ) then
    raise exception using
      errcode = '55000',
      message = 'Project group-chat identity and creation time are immutable.';
  end if;

  select min(membership.joined_at)
  into expected_activated_at
  from public.project_memberships as membership
  where membership.project_id = new.project_id;

  if expected_activated_at is null then
    raise exception using
      errcode = '23514',
      message = 'A Project group chat requires accepted membership history.';
  end if;

  if new.activated_at is distinct from expected_activated_at then
    raise exception using
      errcode = '23514',
      message = 'Project group-chat activation must match the earliest accepted membership.';
  end if;

  return new;
end;
$$;

create trigger project_group_chats_validate_anchor
before insert or update on public.project_group_chats
for each row execute function private.validate_project_group_chat_anchor();

create function private.ensure_project_group_chat(
  p_project_id uuid,
  p_membership_joined_at timestamptz
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  ensured_chat_id uuid;
  earliest_membership_joined_at timestamptz;
begin
  if p_project_id is null or p_membership_joined_at is null then
    raise exception using
      errcode = '22004',
      message = 'Project and membership time are required to ensure a group chat.';
  end if;

  select min(membership.joined_at)
  into earliest_membership_joined_at
  from public.project_memberships as membership
  where membership.project_id = p_project_id;

  if earliest_membership_joined_at is null then
    raise exception using
      errcode = '23514',
      message = 'A Project group chat requires accepted membership history.';
  end if;

  insert into public.project_group_chats (project_id, activated_at)
  values (p_project_id, earliest_membership_joined_at)
  on conflict (project_id) do update
  set activated_at = least(
    public.project_group_chats.activated_at,
    excluded.activated_at
  )
  returning id into ensured_chat_id;

  return ensured_chat_id;
end;
$$;

create function private.ensure_project_group_chat_for_membership()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.ensure_project_group_chat(new.project_id, new.joined_at);
  return new;
end;
$$;

create trigger project_memberships_ensure_group_chat
after insert on public.project_memberships
for each row execute function private.ensure_project_group_chat_for_membership();

create function private.reconcile_project_group_chats()
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  reconciled_count bigint;
begin
  insert into public.project_group_chats (project_id, activated_at)
  select membership.project_id, min(membership.joined_at)
  from public.project_memberships as membership
  group by membership.project_id
  on conflict (project_id) do update
  set activated_at = excluded.activated_at
  where public.project_group_chats.activated_at is distinct from excluded.activated_at;

  get diagnostics reconciled_count = row_count;
  return reconciled_count;
end;
$$;

select private.reconcile_project_group_chats();

create function private.profile_is_project_creator(
  p_project_id uuid,
  p_profile_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.projects as project
    where project.id = p_project_id
      and project.creator_profile_id = p_profile_id
  );
$$;

create function private.profile_has_current_project_membership(
  p_project_id uuid,
  p_profile_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.project_memberships as membership
    where membership.project_id = p_project_id
      and membership.participant_profile_id = p_profile_id
      and membership.left_at is null
      and membership.removed_at is null
  );
$$;

create function private.profile_has_project_membership_history(
  p_project_id uuid,
  p_profile_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.project_memberships as membership
    where membership.project_id = p_project_id
      and membership.participant_profile_id = p_profile_id
  );
$$;

create function private.profile_was_project_member_at(
  p_project_id uuid,
  p_profile_id uuid,
  p_at timestamptz
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_at is not null and exists (
    select 1
    from public.project_memberships as membership
    where membership.project_id = p_project_id
      and membership.participant_profile_id = p_profile_id
      and membership.joined_at <= p_at
      and (
        (membership.left_at is null and membership.removed_at is null)
        or p_at < coalesce(membership.left_at, membership.removed_at)
      )
  );
$$;

create function private.profile_has_current_project_chat_entitlement(
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
    private.profile_is_project_creator(p_project_id, p_profile_id)
    or private.profile_has_current_project_membership(
      p_project_id,
      p_profile_id
    );
$$;

create function private.profile_has_project_chat_history_entitlement(
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
    private.profile_is_project_creator(p_project_id, p_profile_id)
    or private.profile_has_project_membership_history(
      p_project_id,
      p_profile_id
    );
$$;

create function public.get_own_project_group_chat(
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
      when private.profile_is_project_creator(
        project.id,
        current_profile_id
      ) then 'creator'
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

revoke all privileges on function private.validate_project_group_chat_anchor()
  from public, anon, authenticated, service_role;
revoke all privileges on function private.ensure_project_group_chat(uuid, timestamptz)
  from public, anon, authenticated, service_role;
revoke all privileges on function private.ensure_project_group_chat_for_membership()
  from public, anon, authenticated, service_role;
revoke all privileges on function private.reconcile_project_group_chats()
  from public, anon, authenticated, service_role;
revoke all privileges on function private.profile_is_project_creator(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function private.profile_has_current_project_membership(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function private.profile_has_project_membership_history(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function private.profile_was_project_member_at(uuid, uuid, timestamptz)
  from public, anon, authenticated, service_role;
revoke all privileges on function private.profile_has_current_project_chat_entitlement(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function private.profile_has_project_chat_history_entitlement(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.get_own_project_group_chat(uuid, uuid)
  from public, anon, authenticated, service_role;

grant execute on function public.get_own_project_group_chat(uuid, uuid)
  to authenticated;

comment on function private.ensure_project_group_chat(uuid, timestamptz) is
  'Transactionally ensures the one canonical Project chat anchor and preserves the earliest accepted membership time.';
comment on function private.reconcile_project_group_chats() is
  'Idempotently backfills or repairs chat anchors from canonical accepted membership history.';
comment on function private.profile_was_project_member_at(uuid, uuid, timestamptz) is
  'Answers participant membership at one instant using separate half-open accepted membership intervals.';
comment on function public.get_own_project_group_chat(uuid, uuid) is
  'Returns one structural chat anchor only to its expected creator, current member, or former member; missing and unauthorized lookups fail identically.';
comment on function public.accept_project_join_request(uuid, uuid) is
  'Atomically accepts a pending request, creates one current membership, and ensures the canonical Project group-chat anchor in the same transaction.';
