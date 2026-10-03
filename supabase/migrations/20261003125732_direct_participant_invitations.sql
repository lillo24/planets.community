-- PI01: Project-level bearer admission, distinct from authority invitations.
-- Secrets exist only in the private current-share boundary; generations and
-- identity-bound action receipts retain provenance without retaining old URLs.
create table private.project_participant_invitations (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete restrict,
  issued_by_profile_id uuid not null references public.profiles(id) on delete restrict,
  token_digest bytea not null unique check (octet_length(token_digest) = 32),
  created_at timestamptz not null default clock_timestamp(),
  revoked_at timestamptz,
  revoked_by_profile_id uuid references public.profiles(id) on delete restrict,
  revocation_reason text,
  unique (id, project_id),
  check ((revoked_at is null and revoked_by_profile_id is null and revocation_reason is null)
    or (revoked_at is not null and revoked_at >= created_at and revoked_by_profile_id is not null
      and revocation_reason is not null and revocation_reason in ('revoked', 'replaced')))
);
create unique index project_participant_invitations_one_current_idx
  on private.project_participant_invitations(project_id) where revoked_at is null;
create index project_participant_invitations_history_idx
  on private.project_participant_invitations(project_id, created_at desc, id desc);
create index project_participant_invitations_issuer_idx
  on private.project_participant_invitations(issued_by_profile_id);
create index project_participant_invitations_revoker_idx
  on private.project_participant_invitations(revoked_by_profile_id)
  where revoked_by_profile_id is not null;

create table private.project_participant_invitation_secrets (
  invitation_id uuid primary key references private.project_participant_invitations(id) on delete restrict,
  share_token text not null check (share_token ~ '^[A-Za-z0-9_-]{43}$')
);

alter table public.project_memberships
  alter column originating_request_id drop not null,
  add column originating_participant_invitation_id uuid,
  add constraint project_memberships_participant_invitation_fkey
    foreign key (originating_participant_invitation_id, project_id)
    references private.project_participant_invitations(id, project_id) on delete restrict,
  add constraint project_memberships_exactly_one_origin_check
    check ((originating_request_id is not null) <>
      (originating_participant_invitation_id is not null)),
  add constraint project_memberships_episode_identity_key
    unique (id, project_id, participant_profile_id);
create index project_memberships_participant_invitation_idx
  on public.project_memberships(originating_participant_invitation_id, project_id)
  where originating_participant_invitation_id is not null;
comment on column public.project_memberships.originating_request_id is
  'Organizer-approved request origin; null exactly for a direct participant invitation admission. Never fabricate a request for bearer admission.';
comment on column public.project_memberships.originating_participant_invitation_id is
  'Immutable direct-admission generation, mutually exclusive with request origin. No request offers, triage or commitments are inherited.';

create table private.project_participant_admissions (
  profile_id uuid not null references public.profiles(id) on delete restrict,
  client_action_id uuid not null,
  invitation_id uuid not null,
  project_id uuid not null,
  membership_id uuid,
  outcome text not null check (outcome in ('joined', 'already_joined', 'creator')),
  created_at timestamptz not null default clock_timestamp(),
  primary key (profile_id, client_action_id),
  foreign key (invitation_id, project_id)
    references private.project_participant_invitations(id, project_id) on delete restrict,
  foreign key (membership_id, project_id, profile_id)
    references public.project_memberships(id, project_id, participant_profile_id) on delete restrict,
  check ((outcome = 'creator' and membership_id is null)
    or (outcome in ('joined', 'already_joined') and membership_id is not null))
);
create index project_participant_admissions_invitation_idx
  on private.project_participant_admissions(invitation_id, project_id);
create index project_participant_admissions_membership_idx
  on private.project_participant_admissions(membership_id, project_id, profile_id)
  where membership_id is not null;

-- A reasoned withdrawal preserves existing request states, offers, chats and
-- notifications. Its actor is the requester, never a fictional approving manager.
alter table public.project_join_requests
  add column resolution_reason text,
  add column superseded_by_membership_id uuid,
  add constraint project_join_requests_superseding_membership_fkey
    foreign key (superseded_by_membership_id, project_id, requester_profile_id)
    references public.project_memberships(id, project_id, participant_profile_id) on delete restrict,
  add constraint project_join_requests_supersession_check check (
    (resolution_reason is null and superseded_by_membership_id is null)
    or (resolution_reason is not null and resolution_reason = 'direct_participant_invitation'
      and superseded_by_membership_id is not null and status = 'withdrawn'
      and resolved_by_profile_id = requester_profile_id)
  );
create index project_join_requests_superseding_membership_idx
  on public.project_join_requests(superseded_by_membership_id, project_id, requester_profile_id)
  where superseded_by_membership_id is not null;
comment on column public.project_join_requests.resolution_reason is
  'direct_participant_invitation marks a requester withdrawal superseded by direct admission; retained offers are not accepted or inherited.';

alter table private.project_participant_invitations enable row level security;
alter table private.project_participant_invitation_secrets enable row level security;
alter table private.project_participant_admissions enable row level security;
revoke all on private.project_participant_invitations,
  private.project_participant_invitation_secrets, private.project_participant_admissions
  from public, anon, authenticated, service_role;
comment on table private.project_participant_invitation_secrets is
  'Current reusable bearer secret, disclosed only by identity-bound current-manager share RPCs; deleted at revoke/rotation. No external encryption credential or service required.';
comment on table private.project_participant_admissions is
  'Append-only expected-account/action receipts. Replay recovers the original episode and never restores ended membership; fresh explicit actions may re-enter.';

create function private.protect_participant_invitation_history()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'DELETE' or old.revoked_at is not null
    or new.id is distinct from old.id or new.project_id is distinct from old.project_id
    or new.issued_by_profile_id is distinct from old.issued_by_profile_id
    or new.token_digest is distinct from old.token_digest
    or new.created_at is distinct from old.created_at or new.revoked_at is null then
    raise sqlstate '55000' using message = 'Participant invitation history is immutable except for its one revocation.';
  end if;
  return new;
end;
$$;
create trigger project_participant_invitations_preserve_history
before update or delete on private.project_participant_invitations
for each row execute function private.protect_participant_invitation_history();

create function private.protect_participant_admission_receipt()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  raise sqlstate '55000' using message = 'Participant admission receipts are immutable.';
end;
$$;
create trigger project_participant_admissions_preserve_history
before update or delete on private.project_participant_admissions
for each row execute function private.protect_participant_admission_receipt();

create function private.protect_project_membership_origin()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.originating_request_id is distinct from old.originating_request_id
    or new.originating_participant_invitation_id is distinct from old.originating_participant_invitation_id then
    raise sqlstate '55000' using message = 'A membership admission origin is immutable.';
  end if;
  return new;
end;
$$;
create trigger project_memberships_preserve_admission_origin
before update on public.project_memberships
for each row execute function private.protect_project_membership_origin();

create function private.project_accepts_participant_invitations(p_project_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.projects p
    left join public.proposals proposal on proposal.id = p.id and p.project_kind = 'one_time'
    left join public.recurring_activities activity on activity.id = p.id and p.project_kind = 'recurring'
    where p.id = p_project_id and (
      (p.project_kind = 'one_time' and proposal.lifecycle_state = 'published'
        and clock_timestamp() < proposal.ends_at)
      or (p.project_kind = 'recurring' and activity.lifecycle_state = 'published')
    )
  );
$$;

-- Every manager operation takes the existing concrete -> shared Project locks,
-- then generation rows. It never acquires an interaction pair after a Project.
create function private.manage_project_participant_invitation(
  p_expected_profile_id uuid, p_project_id uuid, p_operation text,
  p_invitation_id uuid default null
)
returns table (invitation_id uuid, invite_token text, created_at timestamptz)
language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := private.require_participation_identity(p_expected_profile_id);
  generation private.project_participant_invitations%rowtype;
  secret text;
begin
  perform 1 from private.lock_project_for_participation(p_project_id, false);
  if not private.profile_is_project_manager(p_project_id, actor) then
    raise sqlstate '42501' using message = 'Only a current Project manager can manage participant links.';
  end if;
  select * into generation from private.project_participant_invitations i
    where i.project_id = p_project_id and i.revoked_at is null for update;
  if p_operation = 'revoke' then
    if generation.id is null or p_invitation_id is distinct from generation.id then
      raise sqlstate 'PT409' using message = 'This participant link is no longer current.';
    end if;
  elsif p_operation in ('create', 'regenerate') then
    if (p_operation = 'regenerate' or generation.id is null)
      and not private.project_accepts_participant_invitations(p_project_id) then
      raise sqlstate 'PT409' using message = 'This Project is not accepting participant invitations.';
    end if;
  elsif p_operation <> 'current' then
    raise sqlstate '22023' using message = 'Unsupported participant link operation.';
  end if;

  if p_operation in ('revoke', 'regenerate') and generation.id is not null then
    update private.project_participant_invitations i
      set revoked_at = clock_timestamp(), revoked_by_profile_id = actor,
        revocation_reason = case when p_operation = 'regenerate' then 'replaced' else 'revoked' end
      where i.id = generation.id;
    delete from private.project_participant_invitation_secrets s where s.invitation_id = generation.id;
    perform private.record_project_participation_event('project.participant_invitation_revoked', actor,
      p_project_id, jsonb_build_object('invitation_id', generation.id, 'reason', p_operation));
    if p_operation = 'revoke' then
      return query select generation.id, null::text, generation.created_at;
      return;
    end if;
    generation := null;
  end if;
  if generation.id is null and p_operation in ('create', 'regenerate') then
    secret := translate(rtrim(encode(extensions.gen_random_bytes(32), 'base64'), '='), '+/', '-_');
    insert into private.project_participant_invitations(project_id, issued_by_profile_id, token_digest)
      values (p_project_id, actor, extensions.digest(secret, 'sha256')) returning * into generation;
    insert into private.project_participant_invitation_secrets(invitation_id, share_token)
      values (generation.id, secret);
    perform private.record_project_participation_event('project.participant_invitation_created', actor,
      p_project_id, jsonb_build_object('invitation_id', generation.id));
  end if;
  if generation.id is not null then
    select s.share_token into strict secret from private.project_participant_invitation_secrets s
      where s.invitation_id = generation.id;
    if extensions.digest(secret, 'sha256') <> generation.token_digest then
      raise sqlstate '55000' using message = 'The current participant sharing secret is inconsistent.';
    end if;
    return query select generation.id, secret, generation.created_at;
  end if;
end;
$$;

create function public.create_project_participant_invitation(p_expected_profile_id uuid, p_project_id uuid)
returns table (invitation_id uuid, invite_token text, created_at timestamptz)
language sql security definer set search_path = '' as $$
  select * from private.manage_project_participant_invitation(p_expected_profile_id, p_project_id, 'create');
$$;
create function public.get_current_project_participant_invitation(p_expected_profile_id uuid, p_project_id uuid)
returns table (invitation_id uuid, invite_token text, created_at timestamptz)
language sql security definer set search_path = '' as $$
  select * from private.manage_project_participant_invitation(p_expected_profile_id, p_project_id, 'current');
$$;
create function public.regenerate_project_participant_invitation(p_expected_profile_id uuid, p_project_id uuid)
returns table (invitation_id uuid, invite_token text, created_at timestamptz)
language sql security definer set search_path = '' as $$
  select * from private.manage_project_participant_invitation(p_expected_profile_id, p_project_id, 'regenerate');
$$;
create function public.revoke_project_participant_invitation(
  p_expected_profile_id uuid, p_project_id uuid, p_invitation_id uuid
)
returns uuid language sql security definer set search_path = '' as $$
  select invitation_id from private.manage_project_participant_invitation(
    p_expected_profile_id, p_project_id, 'revoke', p_invitation_id);
$$;

create function public.list_project_participant_invitation_history(
  p_expected_profile_id uuid, p_project_id uuid, p_limit integer default 20,
  p_before_created_at timestamptz default null, p_before_invitation_id uuid default null
)
returns table (invitation_id uuid, issued_by_profile_id uuid, created_at timestamptz,
  revoked_at timestamptz, revoked_by_profile_id uuid, revocation_reason text)
language plpgsql stable security definer set search_path = '' as $$
declare actor uuid := private.require_participation_identity(p_expected_profile_id);
begin
  if not private.profile_is_project_manager(p_project_id, actor) then
    raise sqlstate '42501' using message = 'Only a current Project manager can read participant link history.';
  end if;
  if p_limit is null or p_limit not between 1 and 50
    or (p_before_created_at is null) <> (p_before_invitation_id is null) then
    raise sqlstate '22023' using message = 'Use a limit from 1 to 50 and a complete history cursor.';
  end if;
  return query select i.id, i.issued_by_profile_id, i.created_at, i.revoked_at,
    i.revoked_by_profile_id, i.revocation_reason
  from private.project_participant_invitations i where i.project_id = p_project_id
    and (p_before_created_at is null or (i.created_at, i.id) < (p_before_created_at, p_before_invitation_id))
  order by i.created_at desc, i.id desc limit p_limit;
end;
$$;

create function public.get_project_participant_invitation_preview(p_token text)
returns table (available boolean, project_id uuid, project_kind text, project_title text)
language sql stable security definer set search_path = '' as $$
  with preview as (
    select p.id, p.project_kind,
      case p.project_kind when 'one_time' then proposal.title when 'recurring' then activity.title end as title
    from private.project_participant_invitations i join public.projects p on p.id = i.project_id
    left join public.proposals proposal on proposal.id = p.id and p.project_kind = 'one_time'
    left join public.recurring_activities activity on activity.id = p.id and p.project_kind = 'recurring'
    where p_token ~ '^[A-Za-z0-9_-]{43}$' and i.token_digest = extensions.digest(p_token, 'sha256')
      and i.revoked_at is null and private.project_accepts_participant_invitations(p.id)
  )
  select true, id, preview.project_kind, title from preview
  union all select false, null::uuid, null::text, null::text where not exists (select 1 from preview);
$$;

create function public.accept_project_participant_invitation(
  p_expected_profile_id uuid, p_token text, p_client_action_id uuid
)
returns table (project_id uuid, membership_id uuid, outcome text, membership_status text, replayed boolean)
language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := private.require_participation_identity(p_expected_profile_id);
  generation private.project_participant_invitations%rowtype;
  receipt private.project_participant_admissions%rowtype;
  member public.project_memberships%rowtype;
  pending_request public.project_join_requests%rowtype;
  result_outcome text;
  project_record record;
  admission_time timestamptz;
begin
  if p_client_action_id is null then
    raise sqlstate '22023' using message = 'An explicit participant admission action identifier is required.';
  end if;
  if p_token is null or p_token !~ '^[A-Za-z0-9_-]{43}$' then
    raise sqlstate 'PT409' using message = 'This participant invitation is unavailable.';
  end if;
  -- One action lock precedes the canonical pair -> concrete -> Project order.
  -- It also serializes one account's reuse of an action across different Projects.
  perform pg_advisory_xact_lock(hashtextextended(
    'participant-admission:' || actor::text || ':' || p_client_action_id::text, 0));
  select * into receipt from private.project_participant_admissions a
    where a.profile_id = actor and a.client_action_id = p_client_action_id;
  if found then
    if not exists (select 1 from private.project_participant_invitations i
      where i.id = receipt.invitation_id and i.token_digest = extensions.digest(p_token, 'sha256')) then
      raise sqlstate 'PT409' using message = 'This admission action belongs to a different invitation.';
    end if;
    -- Recovery is read-only: no new admission, capacity use, event or entitlement.
    select * into member from public.project_memberships m where m.id = receipt.membership_id;
    return query select receipt.project_id, receipt.membership_id, receipt.outcome,
      case when member.id is null then null::text when member.left_at is not null then 'left'
        when member.removed_at is not null then 'removed' else 'current' end, true;
    return;
  end if;
  perform private.require_complete_participation_profile(actor); -- Deliberately no photo gate.
  select * into generation from private.project_participant_invitations i
    where i.token_digest = extensions.digest(p_token, 'sha256') and i.revoked_at is null;
  if not found then
    raise sqlstate 'PT409' using message = 'This participant invitation is unavailable.';
  end if;
  perform private.lock_project_manager_interactions(generation.project_id, actor);
  select * into project_record from private.lock_project_for_participation(generation.project_id, false);
  select * into generation from private.project_participant_invitations i where i.id = generation.id for update;
  if generation.revoked_at is not null
    or not private.project_accepts_participant_invitations(generation.project_id) then
    raise sqlstate 'PT409' using message = 'This participant invitation is unavailable.';
  end if;
  select * into member from public.project_memberships m
    where m.project_id = generation.project_id and m.participant_profile_id = actor
      and m.left_at is null and m.removed_at is null for update;
  if member.id is not null then
    result_outcome := 'already_joined';
  elsif project_record.creator_profile_id = actor then
    result_outcome := 'creator'; -- The Creator's distinct role is not a participant episode.
  else
    perform private.assert_project_has_membership_capacity(generation.project_id, actor);
    -- Match canonical membership/chat statement-time provenance. Chat creation
    -- defaults to statement_timestamp(), which must not precede joined_at.
    admission_time := statement_timestamp();
    insert into public.project_memberships(project_id, participant_profile_id,
      originating_participant_invitation_id, joined_at)
      values (generation.project_id, actor, generation.id, admission_time) returning * into member;
    result_outcome := 'joined';
    select * into pending_request from public.project_join_requests r
      where r.project_id = generation.project_id and r.requester_profile_id = actor
        and r.status = 'pending' for update;
    if found then
      update public.project_join_requests r set status = 'withdrawn', resolved_at = admission_time,
        resolved_by_profile_id = actor, resolution_reason = 'direct_participant_invitation',
        superseded_by_membership_id = member.id where r.id = pending_request.id;
      perform private.record_project_participation_event('project.join_request_withdrawn', actor,
        generation.project_id, jsonb_build_object('project_kind', project_record.project_kind,
          'request_id', pending_request.id, 'requester_profile_id', actor, 'status', 'withdrawn',
          'reason', 'direct_participant_invitation', 'membership_id', member.id));
    end if;
    perform private.record_project_participation_event('project.participant_invitation_joined', actor,
      generation.project_id, jsonb_build_object('project_kind', project_record.project_kind,
        'invitation_id', generation.id, 'membership_id', member.id, 'participant_profile_id', actor));
  end if;
  insert into private.project_participant_admissions(profile_id, client_action_id, invitation_id,
    project_id, membership_id, outcome)
    values (actor, p_client_action_id, generation.id, generation.project_id, member.id, result_outcome);
  return query select generation.project_id, member.id, result_outcome,
    case when member.id is null then null::text else 'current' end, false;
end;
$$;

-- Existing history RPC shapes remain intact. This exact-request read explains
-- a superseding withdrawal to its requester/current managers without a new list.
create function public.get_project_join_request_resolution_context(p_expected_profile_id uuid, p_request_id uuid)
returns table (resolution_reason text, superseded_by_membership_id uuid)
language plpgsql stable security definer set search_path = '' as $$
declare actor uuid := private.require_participation_identity(p_expected_profile_id);
begin
  return query select r.resolution_reason, r.superseded_by_membership_id
    from public.project_join_requests r where r.id = p_request_id
      and (r.requester_profile_id = actor or private.profile_is_project_manager(r.project_id, actor));
end;
$$;

revoke all on function private.protect_participant_invitation_history(),
  private.protect_participant_admission_receipt(), private.protect_project_membership_origin(),
  private.project_accepts_participant_invitations(uuid),
  private.manage_project_participant_invitation(uuid, uuid, text, uuid) from public, anon, authenticated, service_role;
revoke all on function public.create_project_participant_invitation(uuid, uuid),
  public.get_current_project_participant_invitation(uuid, uuid),
  public.regenerate_project_participant_invitation(uuid, uuid),
  public.revoke_project_participant_invitation(uuid, uuid, uuid),
  public.list_project_participant_invitation_history(uuid, uuid, integer, timestamptz, uuid),
  public.accept_project_participant_invitation(uuid, text, uuid),
  public.get_project_join_request_resolution_context(uuid, uuid),
  public.get_project_participant_invitation_preview(text) from public, anon, authenticated, service_role;
grant execute on function public.create_project_participant_invitation(uuid, uuid),
  public.get_current_project_participant_invitation(uuid, uuid),
  public.regenerate_project_participant_invitation(uuid, uuid),
  public.revoke_project_participant_invitation(uuid, uuid, uuid),
  public.list_project_participant_invitation_history(uuid, uuid, integer, timestamptz, uuid),
  public.accept_project_participant_invitation(uuid, text, uuid),
  public.get_project_join_request_resolution_context(uuid, uuid) to authenticated;
grant execute on function public.get_project_participant_invitation_preview(text) to anon, authenticated;
comment on function public.create_project_participant_invitation(uuid, uuid) is
  'Get-or-create the current reusable participant link as a current manager. Resharing never rotates it; first creation requires current joinability.';
comment on function public.regenerate_project_participant_invitation(uuid, uuid) is
  'Explicit atomic rotation: old generation is revoked, its secret deleted, and a new current token returned only to the expected current manager.';
comment on function public.accept_project_participant_invitation(uuid, text, uuid) is
  'Explicit identity/action-bound direct admission with non-photo profile, manager block locks and canonical capacity/chat hooks. Replay returns the original outcome plus current episode status; a fresh action may re-enter.';
comment on function public.get_project_participant_invitation_preview(text) is
  'Non-mutating minimal public identity/kind/title only. Malformed, revoked, replaced and non-joinable links share the same unavailable shape.';

-- Direct members belong to the same creation-time moderation cohort.
create or replace function private.snapshot_group_corroboration_requests()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  moderation_case private.moderation_cases%rowtype;
  invitation_count integer;
begin
  select * into moderation_case
  from private.moderation_cases as candidate
  where candidate.id = new.case_id;

  if moderation_case.project_context_id is null
    or moderation_case.target_kind not in ('profile', 'project_chat_message') then
    return new;
  end if;

  -- Participation mutations use this same concrete-row/project-row lock order.
  -- Taking it before the membership query makes the creation-time cohort exact.
  perform 1
  from private.lock_project_for_participation(
    moderation_case.project_context_id,
    false
  );

  with eligible_recipients as (
    select project.creator_profile_id as profile_id
    from public.projects as project
    where project.id = moderation_case.project_context_id

    union

    select membership.participant_profile_id
    from public.project_memberships as membership
    left join public.project_join_requests as originating_request
      on originating_request.id = membership.originating_request_id
      and originating_request.project_id = membership.project_id
      and originating_request.requester_profile_id =
        membership.participant_profile_id
      and originating_request.status = 'accepted'
    where (originating_request.id is not null or membership.originating_participant_invitation_id is not null)
      and membership.project_id = moderation_case.project_context_id
      and membership.joined_at <= moderation_case.created_at
      and moderation_case.created_at < coalesce(
        membership.left_at,
        membership.removed_at,
        'infinity'::timestamptz
      )
  ), inserted as (
    insert into private.moderation_evidence_requests (
      case_id,
      request_kind,
      recipient_profile_id,
      created_at
    )
    select
      moderation_case.id,
      'group_corroboration',
      eligible.profile_id,
      moderation_case.created_at
    from eligible_recipients as eligible
    where eligible.profile_id not in (
      new.reporter_profile_id,
      moderation_case.subject_profile_id
    )
    on conflict (case_id, request_kind, recipient_profile_id) do nothing
    returning id
  )
  select count(*)::integer into invitation_count from inserted;

  insert into private.audit_events (
    action,
    actor_user_id,
    target_type,
    target_id,
    metadata,
    created_at
  )
  values (
    'moderation.group_corroboration_snapshotted',
    new.reporter_profile_id,
    'moderation_case',
    moderation_case.id,
    jsonb_build_object(
      'case_id', moderation_case.id,
      'request_count', invitation_count
    ),
    moderation_case.created_at
  );

  return new;
end;
$$;
