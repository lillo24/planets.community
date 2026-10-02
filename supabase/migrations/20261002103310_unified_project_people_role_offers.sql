-- 07C4: genuine recipient-accepted, tokenless role offers and current-group reads.
alter table public.project_delegate_invitations
  alter column token_digest drop not null,
  add column target_profile_id uuid references public.profiles(id) on delete restrict,
  add column target_membership_id uuid references public.project_memberships(id) on delete restrict,
  add column declined_at timestamptz,
  drop constraint project_delegate_invitations_status_valid,
  drop constraint project_delegate_invitations_resolution_valid,
  add constraint project_delegate_invitations_status_valid
    check (status in ('pending', 'accepted', 'revoked', 'declined')),
  add constraint project_delegate_invitations_delivery_valid check (
    (token_digest is not null and target_profile_id is null and target_membership_id is null)
    or (token_digest is null and target_profile_id is not null
      and target_membership_id is not null and target_profile_id <> owner_profile_id)
  ),
  add constraint project_delegate_invitations_resolution_valid check (
    (status = 'pending' and accepted_at is null and accepted_by_profile_id is null
      and revoked_at is null and revoked_by_profile_id is null and declined_at is null)
    or (status = 'accepted' and accepted_at is not null and accepted_by_profile_id is not null
      and accepted_at >= created_at and revoked_at is null and revoked_by_profile_id is null
      and declined_at is null
      and (target_profile_id is null or accepted_by_profile_id = target_profile_id))
    or (status = 'revoked' and accepted_at is null and accepted_by_profile_id is null
      and revoked_at >= created_at and revoked_at is not null
      and revoked_by_profile_id is not null and declined_at is null)
    or (status = 'declined' and target_profile_id is not null and declined_at is not null
      and declined_at >= created_at and accepted_at is null and accepted_by_profile_id is null
      and revoked_at is null and revoked_by_profile_id is null)
  );
comment on column public.project_delegate_invitations.target_membership_id is
  'Tokenless targeted role offers bind to one membership episode; leave/rejoin never revives eligibility.';
comment on column public.project_delegate_invitations.target_profile_id is
  'Null for bearer invitations. Non-null fixes the sole profile allowed to accept or decline a tokenless offer.';
create unique index project_delegate_invitations_one_pending_target_idx
  on public.project_delegate_invitations(project_id, target_profile_id)
  where status = 'pending' and target_profile_id is not null;
create index project_delegate_invitations_target_created_idx
  on public.project_delegate_invitations(target_profile_id, created_at desc, id desc)
  where target_profile_id is not null;
create index project_requests_people_page_idx
  on public.project_join_requests(project_id, (status = 'pending') desc, created_at desc, id desc);
create index project_memberships_ended_page_idx
  on public.project_memberships(project_id, joined_at desc, id desc)
  where left_at is not null or removed_at is not null;

-- Team remains the bearer-link surface; targeted offers belong to People.
-- Existing structural mutations capture statement time before acquiring Project
-- locks. An offer committed while they wait must be invalidated at execution time.
create or replace function private.invalidate_project_authority_invitations(
  p_project_id uuid, p_project_kind text, p_issuer_profile_id uuid,
  p_actor_profile_id uuid, p_revoked_at timestamptz
) returns void language plpgsql security definer set search_path = '' as $$
declare invalidated_invitation_id uuid;
  invalidated_at timestamptz := greatest(p_revoked_at, clock_timestamp());
begin
  for invalidated_invitation_id in
    update public.project_delegate_invitations i set status='revoked',
      revoked_at=greatest(invalidated_at, i.created_at), revoked_by_profile_id=p_actor_profile_id
    where i.project_id=p_project_id and i.issuer_profile_id=p_issuer_profile_id and i.status='pending'
    returning i.id
  loop
    perform private.record_project_delegate_event('project.delegate_invite_invalidated',
      p_actor_profile_id,p_project_id,p_project_kind,invalidated_invitation_id,null,p_issuer_profile_id);
  end loop;
end;
$$;
create or replace function public.list_project_delegate_invitations_for_owner(
  p_expected_owner_profile_id uuid, p_project_id uuid
) returns table (
  invitation_id uuid, status text, created_at timestamptz, expires_at timestamptz,
  accepted_at timestamptz, revoked_at timestamptz, requested_authority_role text,
  issuer_profile_id uuid, issuer_display_name text
) language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.require_project_structural_authority(p_expected_owner_profile_id, p_project_id);
  return query select i.id, i.status, i.created_at, i.expires_at, i.accepted_at,
    i.revoked_at, i.requested_authority_role, i.issuer_profile_id, issuer.display_name
  from public.project_delegate_invitations i
  join public.profiles issuer on issuer.id = i.issuer_profile_id
  where i.project_id = p_project_id and i.target_profile_id is null
  order by i.created_at desc, i.id desc;
end;
$$;

create function private.require_project_people_viewer(
  p_expected_profile_id uuid, p_project_id uuid
) returns uuid language plpgsql stable security definer set search_path = '' as $$
declare actor uuid := private.require_participation_identity(p_expected_profile_id);
begin
  if not private.profile_is_project_manager(p_project_id, actor) and not exists (
    select 1 from public.project_memberships m where m.project_id = p_project_id
      and m.participant_profile_id = actor and m.left_at is null and m.removed_at is null
  ) then
    raise exception using errcode = '42501', message = 'Current Project people access is required.';
  end if;
  return actor;
end;
$$;

create function public.list_current_project_people(
  p_expected_profile_id uuid, p_project_id uuid, p_limit integer default 50,
  p_after_role_rank integer default null, p_after_profile_id uuid default null
) returns table(
  profile_id uuid, display_name text, is_creator boolean, authority_role text,
  delegate_id uuid, current_membership_id uuid, joined_at timestamptz, role_rank integer
) language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.require_project_people_viewer(p_expected_profile_id, p_project_id);
  if p_limit is null or p_limit not between 1 and 50
    or ((p_after_role_rank is null) <> (p_after_profile_id is null))
    or (p_after_role_rank is not null and p_after_role_rank not between 0 and 3) then
    raise exception using errcode = '22023', message = 'Invalid People page or cursor.';
  end if;
  return query
  with identities as (
    select p.creator_profile_id as id from public.projects p where p.id = p_project_id
    union select d.delegate_profile_id from public.project_delegates d
      where d.project_id = p_project_id and d.revoked_at is null
    union select m.participant_profile_id from public.project_memberships m
      where m.project_id = p_project_id and m.left_at is null and m.removed_at is null
  ), roster as (
    select i.id, profile.display_name as name,
      i.id = p.creator_profile_id as creator, d.authority_role as role,
      d.id as authority_id, m.id as membership_id, m.joined_at as joined,
      case when i.id = p.creator_profile_id then 0 when d.authority_role = 'co_creator' then 1
        when d.authority_role = 'co_organizer' then 2 else 3 end as rank
    from identities i join public.profiles profile on profile.id = i.id
    join public.projects p on p.id = p_project_id
    left join public.project_delegates d on d.project_id = p_project_id
      and d.delegate_profile_id = i.id and d.revoked_at is null
    left join public.project_memberships m on m.project_id = p_project_id
      and m.participant_profile_id = i.id and m.left_at is null and m.removed_at is null
  )
  select r.id, r.name, r.creator, r.role, r.authority_id, r.membership_id, r.joined, r.rank
  from roster r where p_after_profile_id is null or (r.rank, r.id) > (p_after_role_rank, p_after_profile_id)
  order by r.rank, r.id limit p_limit;
end;
$$;
comment on function public.list_current_project_people(uuid, uuid, integer, integer, uuid) is
  'Current-group context deliberately exposes display names irrespective of public-profile audience. No bio, skills, photos, history, or pending requests. Rank/UUID keyset; clients reset after authority mutations.';

create function public.create_project_role_offer(
  p_expected_structural_profile_id uuid, p_project_id uuid,
  p_membership_id uuid, p_authority_role text
) returns uuid language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := private.require_participation_identity(p_expected_structural_profile_id);
  project_record record;
  member public.project_memberships%rowtype;
  pending public.project_delegate_invitations%rowtype;
  offer_id uuid;
  offered_at timestamptz;
begin
  if p_authority_role is null or p_authority_role not in ('co_organizer','co_creator') then
    raise exception using errcode = '22023', message = 'Unsupported Project role.';
  end if;
  select * into project_record from private.lock_project_for_delegate_management(p_project_id, true);
  if not private.profile_has_project_structural_authority(p_project_id, actor) then
    raise exception using errcode = '42501', message = 'Structural authority is required.';
  end if;
  select * into member from public.project_memberships m where m.id = p_membership_id for update;
  if not found or member.project_id <> p_project_id or member.left_at is not null
    or member.removed_at is not null or member.participant_profile_id = project_record.owner_profile_id
    or not exists (select 1 from public.profiles p where p.id = member.participant_profile_id and p.display_name is not null)
    or private.profile_is_project_manager(p_project_id, member.participant_profile_id) then
    raise exception using errcode = 'PT409', message = 'This participant is no longer eligible for a role offer.';
  end if;
  offered_at := clock_timestamp();
  select * into pending from public.project_delegate_invitations i
    where i.project_id = p_project_id and i.target_profile_id = member.participant_profile_id
      and i.status = 'pending' for update;
  if found then
    if pending.expires_at <= offered_at or pending.target_membership_id <> member.id then
      update public.project_delegate_invitations set status = 'revoked', revoked_at = offered_at,
        revoked_by_profile_id = actor where id = pending.id;
      perform private.record_project_delegate_event('project.delegate_invite_invalidated', actor,
        p_project_id, project_record.project_kind, pending.id, null, member.participant_profile_id);
    elsif pending.issuer_profile_id = actor and pending.requested_authority_role = p_authority_role then
      return pending.id;
    else
      raise exception using errcode = 'PT409', message = 'This participant already has a pending role offer.';
    end if;
  end if;
  insert into public.project_delegate_invitations(
    project_id, owner_profile_id, token_digest, issuer_profile_id, requested_authority_role,
    target_profile_id, target_membership_id, created_at, expires_at
  ) values(p_project_id, project_record.owner_profile_id, null, actor, p_authority_role,
    member.participant_profile_id, member.id, offered_at, offered_at + interval '7 days')
  returning id into offer_id;
  perform private.record_project_delegate_event('project.delegate_role_offered', actor, p_project_id,
    project_record.project_kind, offer_id, null, member.participant_profile_id);
  return offer_id;
end;
$$;

create function public.accept_project_role_offer(
  p_expected_profile_id uuid, p_offer_id uuid
) returns uuid language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := private.require_complete_participation_profile(p_expected_profile_id);
  invitation public.project_delegate_invitations%rowtype;
  project_record record;
  relationship_id uuid;
  accepted_time timestamptz;
begin
  select * into invitation from public.project_delegate_invitations i
    where i.id = p_offer_id and i.target_profile_id = actor;
  if not found then
    raise exception using errcode = '42501', message = 'The role offer is unavailable.';
  end if;
  select * into project_record from private.lock_project_for_delegate_management(invitation.project_id, true);
  select * into invitation from public.project_delegate_invitations i where i.id = p_offer_id for update;
  if invitation.status = 'accepted' then
    select d.id into relationship_id from public.project_delegates d where d.invitation_id = invitation.id
      and d.delegate_profile_id = actor;
    if relationship_id is null then
      raise exception using errcode = '55000', message = 'The accepted role offer has no relationship.';
    end if;
    return relationship_id;
  end if;
  accepted_time := clock_timestamp();
  if invitation.status <> 'pending' or invitation.expires_at <= accepted_time
    or not private.profile_has_project_structural_authority(invitation.project_id, invitation.issuer_profile_id)
    or private.profile_is_project_manager(invitation.project_id, actor)
    or not exists (select 1 from public.project_memberships m
      where m.id = invitation.target_membership_id and m.project_id = invitation.project_id
        and m.participant_profile_id = actor and m.left_at is null and m.removed_at is null) then
    raise exception using errcode = 'PT409', message = 'This role offer is no longer eligible for acceptance.';
  end if;
  update public.project_delegate_invitations set status = 'accepted', accepted_at = accepted_time,
    accepted_by_profile_id = actor where id = p_offer_id;
  insert into public.project_delegates(project_id, owner_profile_id, delegate_profile_id, invitation_id,
    delegated_at, granted_by_profile_id, initial_authority_role, authority_role)
  values(invitation.project_id, invitation.owner_profile_id, actor, invitation.id, accepted_time,
    invitation.issuer_profile_id, invitation.requested_authority_role, invitation.requested_authority_role)
  returning id into relationship_id;
  perform private.record_project_delegate_event('project.delegate_added', actor, invitation.project_id,
    project_record.project_kind, invitation.id, relationship_id, actor);
  return relationship_id;
end;
$$;

create function public.decline_project_role_offer(p_expected_profile_id uuid, p_offer_id uuid)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := private.require_participation_identity(p_expected_profile_id);
  invitation public.project_delegate_invitations%rowtype;
  project_record record;
begin
  select * into invitation from public.project_delegate_invitations i
    where i.id = p_offer_id and i.target_profile_id = actor;
  if not found then
    raise exception using errcode = '42501', message = 'The role offer is unavailable.';
  end if;
  select * into project_record from private.lock_project_for_delegate_management(invitation.project_id, false);
  select * into invitation from public.project_delegate_invitations i where i.id = p_offer_id for update;
  if invitation.status = 'declined' then return invitation.id; end if;
  if invitation.status <> 'pending' then
    raise exception using errcode = 'PT409', message = 'The role offer has already been resolved.';
  end if;
  update public.project_delegate_invitations set status = 'declined', declined_at = clock_timestamp()
    where id = invitation.id;
  perform private.record_project_delegate_event('project.delegate_role_declined', actor, invitation.project_id,
    project_record.project_kind, invitation.id, null, actor);
  return invitation.id;
end;
$$;

create function public.step_down_project_authority(p_expected_profile_id uuid, p_delegate_id uuid)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := private.require_participation_identity(p_expected_profile_id);
  delegation public.project_delegates%rowtype;
  project_record record;
  ended_time timestamptz;
begin
  select * into delegation from public.project_delegates d where d.id = p_delegate_id
    and d.delegate_profile_id = actor;
  if not found then
    raise exception using errcode = '42501', message = 'Only your own delegated role can be stepped down.';
  end if;
  select * into project_record from private.lock_project_for_delegate_management(delegation.project_id, false);
  select * into delegation from public.project_delegates d where d.id = p_delegate_id for update;
  if delegation.revoked_at is not null then return delegation.id; end if;
  ended_time := clock_timestamp();
  -- The canonical AFTER trigger rejects over-capacity conversion; membership is never altered.
  update public.project_delegates set revoked_at = ended_time, revoked_by_profile_id = actor
    where id = delegation.id;
  if delegation.authority_role = 'co_creator' then
    perform private.invalidate_project_authority_invitations(delegation.project_id,
      project_record.project_kind, actor, actor, ended_time);
  end if;
  perform private.record_project_delegate_event('project.delegate_stepped_down', actor, delegation.project_id,
    project_record.project_kind, delegation.invitation_id, delegation.id, actor);
  return delegation.id;
end;
$$;

create function public.list_project_role_offers(
  p_expected_profile_id uuid, p_project_id uuid, p_limit integer default 50,
  p_after_created_at timestamptz default null, p_after_id uuid default null
) returns table(offer_id uuid, target_profile_id uuid, target_display_name text,
  issuer_profile_id uuid, issuer_display_name text, requested_authority_role text,
  created_at timestamptz, expires_at timestamptz, target_membership_id uuid)
language plpgsql stable security definer set search_path = '' as $$
declare actor uuid := private.require_project_people_viewer(p_expected_profile_id, p_project_id);
begin
  if p_limit is null or p_limit not between 1 and 50
    or ((p_after_created_at is null) <> (p_after_id is null)) then
    raise exception using errcode = '22023', message = 'Invalid role offer page or cursor.';
  end if;
  return query select i.id, i.target_profile_id, target.display_name, i.issuer_profile_id,
    issuer.display_name, i.requested_authority_role, i.created_at, i.expires_at, i.target_membership_id
  from public.project_delegate_invitations i
  join public.profiles target on target.id = i.target_profile_id
  join public.profiles issuer on issuer.id = i.issuer_profile_id
  join public.project_memberships m on m.id = i.target_membership_id
  where i.project_id = p_project_id and i.status = 'pending' and i.expires_at > statement_timestamp()
    and private.project_allows_delegate_collaboration(p_project_id)
    and m.project_id = p_project_id and m.participant_profile_id = i.target_profile_id
    and m.left_at is null and m.removed_at is null
    and private.profile_has_project_structural_authority(p_project_id, i.issuer_profile_id)
    and not private.profile_is_project_manager(p_project_id, i.target_profile_id)
    and (i.target_profile_id = actor or private.profile_has_project_structural_authority(p_project_id, actor))
    and (p_after_id is null or (i.created_at, i.id) < (p_after_created_at, p_after_id))
  order by i.created_at desc, i.id desc limit p_limit;
end;
$$;

-- Existing compatibility reads retain their signatures; the People UI uses these bounded endpoints.
create function public.page_project_requests_for_manager(
  p_expected_profile_id uuid, p_project_id uuid, p_limit integer default 50,
  p_after_pending boolean default null, p_after_created_at timestamptz default null, p_after_id uuid default null
) returns table(request_id uuid, requester_profile_id uuid, requester_display_name text,
  requester_is_organizer boolean, status text, request_message text, created_at timestamptz,
  resolved_at timestamptz, resolved_by_profile_id uuid)
language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.require_project_manager(p_expected_profile_id, p_project_id);
  if p_limit is null or p_limit not between 1 and 50
    or ((p_after_id is null) <> (p_after_created_at is null))
    or ((p_after_id is null) <> (p_after_pending is null)) then
    raise exception using errcode = '22023', message = 'Invalid request page or cursor.';
  end if;
  return query select r.id, r.requester_profile_id, p.display_name,
    private.profile_is_project_manager(p_project_id, r.requester_profile_id), r.status, r.request_message,
    r.created_at, r.resolved_at, r.resolved_by_profile_id
  from public.project_join_requests r join public.profiles p on p.id = r.requester_profile_id
  where r.project_id = p_project_id and (p_after_id is null
    or (p_after_pending and r.status <> 'pending')
    or ((r.status = 'pending') = p_after_pending and (r.created_at, r.id) < (p_after_created_at, p_after_id)))
  order by (r.status = 'pending') desc, r.created_at desc, r.id desc limit p_limit;
end;
$$;

create function public.page_project_history_for_manager(
  p_expected_profile_id uuid, p_project_id uuid, p_limit integer default 50,
  p_after_joined_at timestamptz default null, p_after_id uuid default null
) returns table(membership_id uuid, participant_profile_id uuid, participant_display_name text,
  originating_request_id uuid, membership_status text, joined_at timestamptz, left_at timestamptz,
  removed_at timestamptz, removed_by_profile_id uuid)
language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.require_project_manager(p_expected_profile_id, p_project_id);
  if p_limit is null or p_limit not between 1 and 50
    or ((p_after_id is null) <> (p_after_joined_at is null)) then
    raise exception using errcode = '22023', message = 'Invalid history page or cursor.';
  end if;
  return query select m.id, m.participant_profile_id, p.display_name, m.originating_request_id,
    case when m.left_at is not null then 'left' else 'removed' end,
    m.joined_at, m.left_at, m.removed_at, m.removed_by_profile_id
  from public.project_memberships m join public.profiles p on p.id = m.participant_profile_id
  where m.project_id = p_project_id and (m.left_at is not null or m.removed_at is not null)
    and (p_after_id is null or (m.joined_at, m.id) < (p_after_joined_at, p_after_id))
  order by m.joined_at desc, m.id desc limit p_limit;
end;
$$;

revoke all on function private.require_project_people_viewer(uuid, uuid) from public, anon, authenticated, service_role;
revoke all on function public.list_current_project_people(uuid, uuid, integer, integer, uuid) from public, anon, authenticated, service_role;
grant execute on function public.list_current_project_people(uuid, uuid, integer, integer, uuid) to authenticated;
revoke all on function public.create_project_role_offer(uuid, uuid, uuid, text) from public, anon, authenticated, service_role;
grant execute on function public.create_project_role_offer(uuid, uuid, uuid, text) to authenticated;
revoke all on function public.accept_project_role_offer(uuid, uuid) from public, anon, authenticated, service_role;
grant execute on function public.accept_project_role_offer(uuid, uuid) to authenticated;
revoke all on function public.decline_project_role_offer(uuid, uuid) from public, anon, authenticated, service_role;
grant execute on function public.decline_project_role_offer(uuid, uuid) to authenticated;
revoke all on function public.step_down_project_authority(uuid, uuid) from public, anon, authenticated, service_role;
grant execute on function public.step_down_project_authority(uuid, uuid) to authenticated;
revoke all on function public.list_project_role_offers(uuid, uuid, integer, timestamptz, uuid) from public, anon, authenticated, service_role;
grant execute on function public.list_project_role_offers(uuid, uuid, integer, timestamptz, uuid) to authenticated;
revoke all on function public.page_project_requests_for_manager(uuid, uuid, integer, boolean, timestamptz, uuid) from public, anon, authenticated, service_role;
grant execute on function public.page_project_requests_for_manager(uuid, uuid, integer, boolean, timestamptz, uuid) to authenticated;
revoke all on function public.page_project_history_for_manager(uuid, uuid, integer, timestamptz, uuid) from public, anon, authenticated, service_role;
grant execute on function public.page_project_history_for_manager(uuid, uuid, integer, timestamptz, uuid) to authenticated;

-- Extend each existing notification constraint with one complete narrow offer shape;
-- preserve the old predicate verbatim rather than broadening other event kinds.
do $$
declare constraint_name text; original_predicate text;
begin
  foreach constraint_name in array array[
    'notifications_kind_valid', 'notifications_category_matches_kind',
    'notifications_destination_matches_kind', 'notifications_reference_shape_valid'
  ] loop
    select pg_get_expr(c.conbin, c.conrelid) into original_predicate
    from pg_constraint c where c.conrelid = 'public.notifications'::regclass
      and c.conname = constraint_name;
    if original_predicate is null then
      raise exception 'Missing notification invariant %', constraint_name;
    end if;
    execute format('alter table public.notifications drop constraint %I', constraint_name);
    execute format(
      'alter table public.notifications add constraint %I check ((%s) or (
        notification_kind = ''project_role_offered'' and category_slug = ''participation''
        and destination_kind = ''project_participation'' and project_id is not null
        and actor_profile_id is not null and membership_id is not null
        and request_id is null and chat_id is null and message_id is null
        and resource_listing_id is null and resource_request_id is null
        and resource_chat_id is null and resource_chat_message_id is null
        and resource_agreement_id is null and resource_agreement_event_id is null))',
      constraint_name, original_predicate);
  end loop;
end;
$$;

create index outbox_events_role_offer_sources_available_idx
  on private.outbox_events(available_at, created_at, id)
  where event_type = 'project.delegate_role_offered';

alter function private.resolve_notification_event(uuid) rename to resolve_notification_event_without_role_offers;
revoke all on function private.resolve_notification_event_without_role_offers(uuid)
  from public, anon, authenticated, service_role;
create function private.resolve_notification_event(p_outbox_event_id uuid)
returns table (
  category_slug text, notification_kind text, recipient_profile_id uuid, actor_profile_id uuid,
  project_id uuid, project_kind text, request_id uuid, membership_id uuid, chat_id uuid, message_id uuid,
  resource_listing_id uuid, resource_request_id uuid, resource_chat_id uuid, resource_chat_message_id uuid,
  resource_agreement_id uuid, resource_agreement_event_id uuid, destination_kind text, source_created_at timestamptz
) language plpgsql stable security definer set search_path = '' as $$
declare source private.outbox_events%rowtype; invitation public.project_delegate_invitations%rowtype;
begin
  select * into source from private.outbox_events e where e.id = p_outbox_event_id;
  if not found then
    raise exception using errcode = '55000', message = 'Notification source is unavailable.';
  end if;
  if source.event_type <> 'project.delegate_role_offered' then
    return query select * from private.resolve_notification_event_without_role_offers(p_outbox_event_id);
    return;
  end if;
  select * into invitation from public.project_delegate_invitations i
    where i.id = (source.payload->>'invitation_id')::uuid
      and i.project_id = (source.payload->>'project_id')::uuid
      and i.target_profile_id = (source.payload->>'delegate_profile_id')::uuid
      and i.issuer_profile_id = (source.payload->>'actor_profile_id')::uuid;
  if not found then
    raise exception using errcode = '55000', message = 'Role offer notification provenance is invalid.';
  end if;
  -- Resolved, expired, ended-episode, and former-issuer offers legitimately have no actionable alert.
  return query select 'participation'::text, 'project_role_offered'::text, i.target_profile_id,
    i.issuer_profile_id, i.project_id, p.project_kind, null::uuid, i.target_membership_id,
    null::uuid, null::uuid, null::uuid, null::uuid, null::uuid, null::uuid, null::uuid, null::uuid,
    'project_participation'::text, source.created_at
  from public.project_delegate_invitations i join public.projects p on p.id = i.project_id
  join public.project_memberships m on m.id = i.target_membership_id
  where i.id = invitation.id and i.status = 'pending' and i.expires_at > statement_timestamp()
    and private.project_allows_delegate_collaboration(i.project_id)
    and m.project_id = i.project_id and m.participant_profile_id = i.target_profile_id
    and m.left_at is null and m.removed_at is null
    and private.profile_has_project_structural_authority(i.project_id, i.issuer_profile_id)
    and not private.profile_is_project_manager(i.project_id, i.target_profile_id);
end;
$$;
revoke all on function private.resolve_notification_event(uuid) from public, anon, authenticated, service_role;
comment on function private.resolve_notification_event(uuid) is
  'Canonical recipient-level alert resolver, extended with genuine targeted Project role offers. No email or push expansion.';

create or replace function public.process_notification_outbox_batch(
  p_limit integer default 100
)
returns table (
  processed_count integer,
  notifications_created integer,
  notifications_suppressed integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  source_event private.outbox_events%rowtype;
  resolved_event record;
  in_app_enabled boolean;
  resolved_processed_count integer := 0;
  resolved_notifications_created integer := 0;
  resolved_notifications_suppressed integer := 0;
  inserted_count integer;
begin
  if p_limit is null or p_limit not between 1 and 100 then
    raise exception using
      errcode = '22023',
      message = 'Notification projector batch size must be between 1 and 100.';
  end if;

  for source_event in
    select event.*
    from private.outbox_events as event
    where event.event_type in (
      'project.join_requested',
      'project.join_request_withdrawn',
      'project.join_request_accepted',
      'project.join_request_rejected',
      'project.participant_left',
      'project.participant_removed',
      'project.chat_message_sent',
      'resource_listing.request_created',
      'resource_listing.request_withdrawn',
      'resource_listing.request_accepted',
      'resource_listing.request_rejected',
      'resource_listing.request_closed',
      'resource_chat.message_sent',
      'resource_exchange.terms_proposed',
      'resource_exchange.terms_accepted',
      'resource_exchange.terms_rejected',
      'resource_exchange.terms_withdrawn',
      'resource_exchange.milestone_recorded',
      'resource_exchange.agreement_cancelled',
      'resource_exchange.agreement_completed',
      'resource_saved_search.matched',
      'project.delegate_role_offered'
    )
      and event.available_at <= statement_timestamp()
      and not exists (
        select 1
        from private.outbox_consumer_receipts as receipt
        where receipt.outbox_event_id = event.id
          and receipt.consumer_key = 'notifications.v1'
      )
    order by event.created_at, event.id
    limit p_limit
    for update of event skip locked
  loop
    for resolved_event in
      select *
      from private.resolve_notification_event(source_event.id)
    loop
      select coalesce(
        preference.in_app_enabled,
        category.default_in_app_enabled
      )
      into in_app_enabled
      from public.notification_categories as category
      left join public.profile_notification_preferences as preference
        on preference.profile_id = resolved_event.recipient_profile_id
        and preference.category_slug = category.slug
      where category.slug = resolved_event.category_slug;

      if in_app_enabled is null then
        raise exception using
          errcode = '55000',
          message = 'The resolved notification category is unavailable.';
      end if;

      if in_app_enabled then
        if resolved_event.category_slug = 'matching'
          and resolved_event.notification_kind = 'matching_available' then
          insert into public.notifications (
            recipient_profile_id,
            category_slug,
            notification_kind,
            source_outbox_event_id,
            project_id,
            actor_profile_id,
            request_id,
            membership_id,
            destination_kind,
            created_at,
            chat_id,
            message_id,
            resource_listing_id,
            resource_request_id,
            resource_chat_id,
            resource_chat_message_id,
            resource_agreement_id,
            resource_agreement_event_id
          )
          values (
            resolved_event.recipient_profile_id,
            resolved_event.category_slug,
            resolved_event.notification_kind,
            source_event.id,
            resolved_event.project_id,
            resolved_event.actor_profile_id,
            resolved_event.request_id,
            resolved_event.membership_id,
            resolved_event.destination_kind,
            resolved_event.source_created_at,
            resolved_event.chat_id,
            resolved_event.message_id,
            resolved_event.resource_listing_id,
            resolved_event.resource_request_id,
            resolved_event.resource_chat_id,
            resolved_event.resource_chat_message_id,
            resolved_event.resource_agreement_id,
            resolved_event.resource_agreement_event_id
          )
          on conflict do nothing;

          get diagnostics inserted_count = row_count;
          if inserted_count = 0 then
            resolved_notifications_suppressed :=
              resolved_notifications_suppressed + 1;
          else
            resolved_notifications_created :=
              resolved_notifications_created + inserted_count;
          end if;
        else
          insert into public.notifications (
            recipient_profile_id,
            category_slug,
            notification_kind,
            source_outbox_event_id,
            project_id,
            actor_profile_id,
            request_id,
            membership_id,
            destination_kind,
            created_at,
            chat_id,
            message_id,
            resource_listing_id,
            resource_request_id,
            resource_chat_id,
            resource_chat_message_id,
            resource_agreement_id,
            resource_agreement_event_id
          )
          values (
            resolved_event.recipient_profile_id,
            resolved_event.category_slug,
            resolved_event.notification_kind,
            source_event.id,
            resolved_event.project_id,
            resolved_event.actor_profile_id,
            resolved_event.request_id,
            resolved_event.membership_id,
            resolved_event.destination_kind,
            resolved_event.source_created_at,
            resolved_event.chat_id,
            resolved_event.message_id,
            resolved_event.resource_listing_id,
            resolved_event.resource_request_id,
            resolved_event.resource_chat_id,
            resolved_event.resource_chat_message_id,
            resolved_event.resource_agreement_id,
            resolved_event.resource_agreement_event_id
          )
          on conflict (
            source_outbox_event_id,
            recipient_profile_id,
            notification_kind
          ) do nothing;

          get diagnostics inserted_count = row_count;
          resolved_notifications_created :=
            resolved_notifications_created + inserted_count;
        end if;
      else
        resolved_notifications_suppressed :=
          resolved_notifications_suppressed + 1;
      end if;
    end loop;

    insert into private.outbox_consumer_receipts (
      outbox_event_id,
      consumer_key,
      processed_at
    )
    values (source_event.id, 'notifications.v1', statement_timestamp())
    on conflict do nothing;

    resolved_processed_count := resolved_processed_count + 1;
  end loop;

  return query select
    resolved_processed_count,
    resolved_notifications_created,
    resolved_notifications_suppressed;
end;
$$;


comment on function public.process_notification_outbox_batch(integer) is
  'Shared bounded, chronological notifications.v1 projector. Targeted role offers use participation preferences; inbox data stays in People if alerts are disabled. No new delivery provider.';
