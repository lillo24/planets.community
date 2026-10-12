-- GRP03A. Group relationships are independent of content versions and Projects.
-- Auth UUIDs below are immutable provenance, deliberately without account FKs:
-- account erasure retains history and never transfers the accountable anchor.
create table private.group_join_requests (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references private.community_groups(id) on delete restrict,
  requester_id uuid not null,
  note text check (char_length(note) <= 500),
  status text not null default 'pending' check (status in ('pending','accepted','rejected','withdrawn')),
  created_at timestamptz not null default clock_timestamp(),
  resolved_at timestamptz,
  resolved_by uuid,
  resolution_reason text check (resolution_reason in ('review','withdrawal','blocking','direct_participant_invitation')),
  superseded_by_membership_id uuid,
  check ((status = 'pending') = (resolved_at is null)),
  check ((resolved_at is null) = (resolved_by is null))
);
create unique index group_requests_pending_unique on private.group_join_requests(group_id,requester_id) where status='pending';
create index group_requests_owner_page on private.group_join_requests(requester_id,created_at desc,id desc);
create index group_requests_manager_page on private.group_join_requests(group_id,created_at desc,id desc);
create table private.group_memberships (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references private.community_groups(id) on delete restrict,
  profile_id uuid not null,
  originating_request_id uuid references private.group_join_requests(id) on delete restrict,
  joined_at timestamptz not null default clock_timestamp(),
  admitted_by uuid not null,
  ended_at timestamptz,
  ended_by uuid,
  end_reason text check (end_reason in ('left','removed')),
  check ((ended_at is null) = (ended_by is null)),
  check ((ended_at is null) = (end_reason is null)),
  check (ended_at is null or ended_at >= joined_at)
);
alter table private.group_join_requests add foreign key (superseded_by_membership_id) references private.group_memberships(id) on delete restrict;
create unique index group_memberships_current_unique on private.group_memberships(group_id,profile_id) where ended_at is null;
create index group_memberships_owner_page on private.group_memberships(profile_id,joined_at desc,id desc);
create index group_memberships_manager_page on private.group_memberships(group_id,joined_at desc,id desc);
create index group_memberships_request_idx on private.group_memberships(originating_request_id);
create index group_requests_superseded_idx on private.group_join_requests(superseded_by_membership_id);
create table private.group_delegates (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references private.community_groups(id) on delete restrict,
  profile_id uuid not null,
  initial_role text not null check (initial_role in ('co_creator','co_organizer')),
  delegate_role text not null check (delegate_role in ('co_creator','co_organizer')),
  granted_by uuid not null,
  granted_at timestamptz not null default clock_timestamp(),
  revoked_at timestamptz,
  revoked_by uuid,
  check ((revoked_at is null) = (revoked_by is null))
);
create unique index group_delegates_active_unique on private.group_delegates(group_id,profile_id) where revoked_at is null;
create index group_delegates_owner_idx on private.group_delegates(profile_id,granted_at desc,id desc);
create table private.group_role_changes (
  id uuid primary key default gen_random_uuid(),
  delegate_id uuid not null references private.group_delegates(id) on delete restrict,
  from_role text not null check (from_role in ('co_creator','co_organizer')),
  to_role text not null check (to_role in ('co_creator','co_organizer')),
  actor_id uuid not null,
  created_at timestamptz not null default clock_timestamp(),
  check (from_role <> to_role)
);
create index group_role_changes_delegate_page on private.group_role_changes(delegate_id,created_at desc,id desc);
create table private.group_authority_invitations (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references private.community_groups(id) on delete restrict,
  issuer_id uuid not null,
  offered_role text not null check (offered_role in ('co_creator','co_organizer')),
  token_digest text unique check (token_digest ~ '^[0-9a-f]{64}$'),
  target_profile_id uuid,
  target_membership_id uuid references private.group_memberships(id) on delete restrict,
  status text not null default 'pending' check (status in ('pending','accepted','declined','revoked')),
  created_at timestamptz not null default clock_timestamp(),
  expires_at timestamptz not null default (clock_timestamp()+interval '7 days'),
  resolved_at timestamptz,
  resolved_by uuid,
  accepted_delegate_id uuid references private.group_delegates(id) on delete restrict,
  check ((token_digest is not null and target_profile_id is null and target_membership_id is null)
    or (token_digest is null and target_profile_id is not null and target_membership_id is not null)),
  check ((status='pending') = (resolved_at is null)),
  check ((resolved_at is null) = (resolved_by is null)),
  check ((status='accepted') = (accepted_delegate_id is not null)),
  check (expires_at > created_at)
);
create unique index group_role_offers_pending_unique on private.group_authority_invitations(group_id,target_profile_id) where status='pending' and target_profile_id is not null;
create index group_authority_group_page on private.group_authority_invitations(group_id,created_at desc,id desc);
create index group_authority_target_page on private.group_authority_invitations(target_profile_id,created_at desc,id desc);
create index group_authority_member_idx on private.group_authority_invitations(target_membership_id);
create index group_authority_delegate_idx on private.group_authority_invitations(accepted_delegate_id);
create table private.group_participant_invitations (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references private.community_groups(id) on delete restrict,
  issuer_id uuid not null,
  token_digest text not null unique check (token_digest ~ '^[0-9a-f]{64}$'),
  created_at timestamptz not null default clock_timestamp(),
  revoked_at timestamptz,
  revoked_by uuid,
  check ((revoked_at is null) = (revoked_by is null))
);
create unique index group_participant_current_unique on private.group_participant_invitations(group_id) where revoked_at is null;
create index group_participant_history_page on private.group_participant_invitations(group_id,created_at desc,id desc);
create table private.group_participant_invitation_secrets (
  invitation_id uuid primary key references private.group_participant_invitations(id) on delete restrict,
  token text not null check (token ~ '^[A-Za-z0-9_-]{43}$')
);
create table private.group_relationship_receipts (
  actor_id uuid not null,
  client_request_id uuid not null,
  group_id uuid not null references private.community_groups(id) on delete restrict,
  intent_hash text not null check (intent_hash ~ '^[0-9a-f]{64}$'),
  result jsonb not null check (jsonb_typeof(result)='object' and not (result ? 'invite_token')),
  accepted_at timestamptz not null default clock_timestamp(),
  primary key(actor_id,client_request_id)
);
create index group_relationship_receipts_group_idx on private.group_relationship_receipts(group_id);
create trigger group_relationship_receipts_append_only before update or delete on private.group_relationship_receipts
  for each row execute function private.protect_moderation_append_only();
create trigger group_role_changes_append_only before update or delete on private.group_role_changes
  for each row execute function private.protect_moderation_append_only();

create function private.protect_group_relationship_provenance() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if (to_jsonb(new)-tg_argv) is distinct from (to_jsonb(old)-tg_argv) then
    raise exception using errcode='55000',message='Group relationship provenance is immutable.';
  end if;
  return new;
end;
$$;
create trigger group_delegate_provenance before update on private.group_delegates for each row
  execute function private.protect_group_relationship_provenance('delegate_role','revoked_at','revoked_by');
create trigger group_membership_provenance before update on private.group_memberships for each row
  execute function private.protect_group_relationship_provenance('ended_at','ended_by','end_reason');
create trigger group_request_provenance before update on private.group_join_requests for each row
  execute function private.protect_group_relationship_provenance('status','resolved_at','resolved_by','resolution_reason','superseded_by_membership_id');
create trigger group_authority_provenance before update on private.group_authority_invitations for each row
  execute function private.protect_group_relationship_provenance('status','resolved_at','resolved_by','accepted_delegate_id');
create trigger group_participant_invitation_provenance before update on private.group_participant_invitations for each row
  execute function private.protect_group_relationship_provenance('revoked_at','revoked_by');

create function private.require_group_identity(p_expected_profile_id uuid) returns uuid
language plpgsql stable security definer set search_path='' as $$
declare actor uuid := private.require_participation_identity(p_expected_profile_id);
begin
  if not exists(select 1 from auth.users a join public.profiles p on p.id=a.id where a.id=actor) then
    raise exception using errcode='42501',message='The group identity is unavailable.';
  end if;
  return actor;
end;
$$;
create function private.group_has_accountable_identity(p_group_id uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select exists(select 1 from private.community_group_managers m join public.profiles p on p.id=m.profile_id
    join auth.users a on a.id=p.id where m.group_id=p_group_id and p.display_name is not null);
$$;
create function private.group_authority_role(p_group_id uuid,p_profile_id uuid) returns text
language sql stable security definer set search_path='' as $$
  select case when exists(select 1 from private.community_group_managers where group_id=p_group_id and profile_id=p_profile_id)
    then 'creator' else (select d.delegate_role from private.group_delegates d where d.group_id=p_group_id
      and d.profile_id=p_profile_id and d.revoked_at is null) end
  where private.group_has_accountable_identity(p_group_id)
    and exists(select 1 from auth.users a join public.profiles p on p.id=a.id where a.id=p_profile_id and p.display_name is not null);
$$;
create function private.current_group_manager_profile_ids(p_group_id uuid) returns table(profile_id uuid)
language sql stable security definer set search_path='' as $$
  select m.profile_id from private.community_group_managers m where m.group_id=p_group_id
    and private.group_authority_role(p_group_id,m.profile_id) is not null
  union
  select d.profile_id from private.group_delegates d where d.group_id=p_group_id and d.revoked_at is null
    and private.group_authority_role(p_group_id,d.profile_id) is not null;
$$;
create function private.require_group_manager(p_group_id uuid,p_actor uuid,p_structural boolean default false) returns text
language plpgsql stable security definer set search_path='' as $$
declare authority text := private.group_authority_role(p_group_id,p_actor);
begin
  if authority is null or (p_structural and authority='co_organizer')
    or (authority <> 'creator' and exists(select 1 from private.community_groups where id=p_group_id and publication_state='draft')) then
    raise exception using errcode='42501',message='The group is unavailable.';
  end if;
  return authority;
end;
$$;
-- Command advisory -> sorted canonical block pairs -> group row -> relationship.
-- Never acquire new pair locks after the group lock: changed manager set retries.
create function private.lock_group_interactions(p_group_id uuid,p_subject uuid) returns void
language plpgsql security definer set search_path='' as $$
declare before_ids uuid[]; after_ids uuid[]; manager uuid;
begin
  select coalesce(array_agg(profile_id order by profile_id),'{}') into before_ids from private.current_group_manager_profile_ids(p_group_id);
  for manager in select x from unnest(before_ids) x where x<>p_subject
    order by least(x::text,p_subject::text),greatest(x::text,p_subject::text)
  loop perform private.lock_user_interaction_pair(p_subject,manager); end loop;
  perform 1 from private.community_groups where id=p_group_id for update;
  select coalesce(array_agg(profile_id order by profile_id),'{}') into after_ids from private.current_group_manager_profile_ids(p_group_id);
  if before_ids<>after_ids then raise sqlstate 'PT409' using message='This interaction is unavailable.'; end if;
  foreach manager in array after_ids loop perform private.assert_user_interaction_available(p_subject,manager); end loop;
end;
$$;
create function private.audit_group_relationship(p_action text,p_actor uuid,p_group uuid,p_relationship uuid) returns void
language sql security definer set search_path='' as $$
  insert into private.audit_events(action,target_type,target_id,metadata)
    values(p_action,'community_group',p_group,jsonb_build_object('actor_id',p_actor,'group_id',p_group,'relationship_id',p_relationship));
$$;
create function private.invalidate_group_authority_invitations(p_group uuid,p_issuer uuid,p_actor uuid) returns void
language plpgsql security definer set search_path='' as $$
declare invitation uuid;
begin
  for invitation in update private.group_authority_invitations set status='revoked',resolved_at=clock_timestamp(),resolved_by=p_actor
    where group_id=p_group and issuer_id=p_issuer and status='pending' returning id
  loop perform private.audit_group_relationship('group.authority_invitation_revoked',p_actor,p_group,invitation); end loop;
end;
$$;
create function private.group_relationship_result(p_result jsonb,p_replayed boolean) returns jsonb
language sql stable security definer set search_path='' as $$
  select p_result || jsonb_build_object('replayed',p_replayed,'current_status',case p_result->>'relationship_kind'
    when 'membership' then (select coalesce(end_reason,'current') from private.group_memberships where id=(p_result->>'relationship_id')::uuid)
    when 'request' then (select status from private.group_join_requests where id=(p_result->>'relationship_id')::uuid)
    when 'delegate' then (select case when revoked_at is null then delegate_role else 'revoked' end from private.group_delegates where id=(p_result->>'relationship_id')::uuid)
    when 'authority_invitation' then (select case when status='pending' and expires_at<=clock_timestamp() then 'expired' else status end from private.group_authority_invitations where id=(p_result->>'relationship_id')::uuid)
    else null end);
$$;

-- One group-domain dispatcher owns serialization/receipts. Only narrow public
-- wrappers are granted. Tokens are hashed in intent and never stored in results.
create function private.group_relationship_command(p_expected uuid,p_key uuid,p_group uuid,p_operation text,p_arguments jsonb default '{}') returns jsonb
language plpgsql security definer set search_path='' as $$
declare
  actor uuid := private.require_group_identity(p_expected);
  intent text := private.group_command_hash(jsonb_build_array(p_group,p_operation,p_arguments));
  receipt private.group_relationship_receipts%rowtype;
  request private.group_join_requests%rowtype;
  membership private.group_memberships%rowtype;
  delegate private.group_delegates%rowtype;
  invitation private.group_authority_invitations%rowtype;
  participant_link private.group_participant_invitations%rowtype;
  relationship uuid := (p_arguments->>'id')::uuid;
  subject uuid;
  authority text;
  offered_role text := p_arguments->>'role';
  note text := nullif(regexp_replace(p_arguments->>'note','^[[:space:]]+|[[:space:]]+$','','g'),'');
  secret text;
  outcome text;
  kind text;
  result jsonb;
  changed boolean := true;
begin
  if p_key is null then raise exception using errcode='22023',message='A group relationship command ID is required.'; end if;
  perform pg_advisory_xact_lock(hashtextextended('group.relationship.command:'||actor::text||':'||p_key::text,0));
  select * into receipt from private.group_relationship_receipts where actor_id=actor and client_request_id=p_key;
  if found then
    if receipt.intent_hash<>intent then raise sqlstate 'PT409' using message='The accepted command intent differs.'; end if;
    return private.group_relationship_result(receipt.result,true);
  end if;
  -- Resolve only enough protected identity to choose locks; authorization follows
  -- the lock and all mutable relationship/issuer predicates are re-read below.
  if p_operation in ('request','accept_participant') then subject:=actor;
  elsif p_operation='accept_authority' then
    if not exists(select 1 from private.group_authority_invitations where group_id=p_group and status='accepted' and resolved_by=actor
      and ((p_arguments ? 'digest' and token_digest=p_arguments->>'digest') or id=relationship)) then subject:=actor; end if;
  elsif p_operation='accept_request' then select requester_id into subject from private.group_join_requests where id=relationship and group_id=p_group;
  elsif p_operation='offer' then select profile_id into subject from private.group_memberships where id=relationship and group_id=p_group;
  elsif p_operation='change_role' then select profile_id into subject from private.group_delegates where id=relationship and group_id=p_group;
  end if;
  if subject is not null then perform private.lock_group_interactions(p_group,subject);
  else perform 1 from private.community_groups where id=p_group for update; end if;
  perform private.require_group_identity(p_expected);
  if not exists(select 1 from private.community_groups where id=p_group) then
    raise exception using errcode='42501',message='The group is unavailable.';
  end if;

  if p_operation='request' then
    perform private.require_group_actor(actor);
    if not private.group_is_public(p_group) then raise sqlstate 'PT409' using message='This interaction is unavailable.'; end if;
    if not private.has_current_profile_photo(actor) then raise exception using errcode='55000',message='A profile photo is required to request participation.'; end if;
    if char_length(note)>500 then raise exception using errcode='22023',message='A request note may contain at most 500 characters.'; end if;
    if private.group_authority_role(p_group,actor)='creator' or exists(select 1 from private.group_memberships where group_id=p_group and profile_id=actor and ended_at is null) then
      raise sqlstate 'PT409' using message='A current relationship already exists.';
    end if;
    if exists(select 1 from private.group_join_requests where group_id=p_group and requester_id=actor and status='pending') then
      raise sqlstate 'PT409' using message='A pending request already exists.';
    end if;
    insert into private.group_join_requests(group_id,requester_id,note) values(p_group,actor,note) returning id into relationship;
    kind:='request'; outcome:='requested';
  elsif p_operation in ('withdraw_request','accept_request','reject_request') then
    select * into request from private.group_join_requests where id=relationship and group_id=p_group for update;
    if request.id is null then raise exception using errcode='42501',message='The request is unavailable.'; end if;
    if p_operation='withdraw_request' then
      if request.requester_id<>actor then raise exception using errcode='42501',message='The request is unavailable.'; end if;
      if request.status='withdrawn' then outcome:='withdrawn'; changed:=false;
      elsif request.status='pending' then
        update private.group_join_requests set status='withdrawn',resolved_at=clock_timestamp(),resolved_by=actor,resolution_reason='withdrawal' where id=relationship;
        outcome:='withdrawn';
      else raise sqlstate 'PT409' using message='The request has already been resolved.'; end if;
      kind:='request';
    else
      perform private.require_group_manager(p_group,actor);
      if request.requester_id=actor then raise exception using errcode='42501',message='Self review is unavailable.'; end if;
      if request.status<>'pending' then raise sqlstate 'PT409' using message='The request has already been resolved.'; end if;
      if p_operation='accept_request' then
        if not private.group_is_public(p_group) or not exists(select 1 from auth.users a join public.profiles p on p.id=a.id where p.id=request.requester_id and p.display_name is not null) then
          raise sqlstate 'PT409' using message='This interaction is unavailable.';
        end if;
        insert into private.group_memberships(group_id,profile_id,originating_request_id,admitted_by)
          values(p_group,request.requester_id,relationship,actor) returning * into membership;
        update private.group_join_requests set status='accepted',resolved_at=clock_timestamp(),resolved_by=actor,resolution_reason='review' where id=relationship;
        relationship:=membership.id; kind:='membership'; outcome:='joined';
      else
        update private.group_join_requests set status='rejected',resolved_at=clock_timestamp(),resolved_by=actor,resolution_reason='review' where id=relationship;
        kind:='request'; outcome:='rejected';
      end if;
    end if;
  elsif p_operation in ('leave','remove') then
    select * into membership from private.group_memberships where id=relationship and group_id=p_group for update;
    if membership.id is null then raise exception using errcode='42501',message='The membership is unavailable.'; end if;
    if p_operation='leave' then
      if membership.profile_id<>actor then raise exception using errcode='42501',message='The membership is unavailable.'; end if;
      outcome:='left';
    else
      perform private.require_group_manager(p_group,actor);
      if membership.profile_id=actor then raise exception using errcode='42501',message='Use Leave for your own participation.'; end if;
      outcome:='removed';
    end if;
    if membership.ended_at is not null then raise sqlstate 'PT409' using message='The membership has ended.'; end if;
    update private.group_memberships set ended_at=clock_timestamp(),ended_by=actor,end_reason=outcome where id=relationship;
    -- An exact ended episode can never accept its outstanding role offers.
    for invitation in update private.group_authority_invitations set status='revoked',resolved_at=clock_timestamp(),resolved_by=actor
      where target_membership_id=relationship and status='pending' returning *
    loop perform private.audit_group_relationship('group.authority_invitation_revoked',actor,p_group,invitation.id); end loop;
    kind:='membership';
  elsif p_operation in ('create_participant_link','regenerate_participant_link','revoke_participant_link') then
    perform private.require_group_manager(p_group,actor);
    select * into participant_link from private.group_participant_invitations where group_id=p_group and revoked_at is null for update;
    if p_operation='revoke_participant_link' then
      if participant_link.id is distinct from relationship then raise sqlstate 'PT409' using message='The sharing link changed.'; end if;
    elsif p_operation='create_participant_link' and participant_link.id is not null then
      relationship:=participant_link.id; outcome:='current'; changed:=false;
    else
      if not private.group_is_public(p_group) then raise sqlstate 'PT409' using message='This interaction is unavailable.'; end if;
    end if;
    if p_operation in ('regenerate_participant_link','revoke_participant_link') and participant_link.id is not null then
      update private.group_participant_invitations set revoked_at=clock_timestamp(),revoked_by=actor where id=participant_link.id;
      delete from private.group_participant_invitation_secrets where invitation_id=participant_link.id;
      perform private.audit_group_relationship('group.participant_link_revoked',actor,p_group,participant_link.id);
    end if;
    if p_operation='regenerate_participant_link' or (p_operation='create_participant_link' and participant_link.id is null) then
      secret:=translate(rtrim(encode(extensions.gen_random_bytes(32),'base64'),'='),'+/','-_');
      insert into private.group_participant_invitations(group_id,issuer_id,token_digest)
        values(p_group,actor,encode(extensions.digest(secret,'sha256'),'hex')) returning id into relationship;
      insert into private.group_participant_invitation_secrets(invitation_id,token) values(relationship,secret);
      -- Participant secrets are retrieved separately with current manager checks.
      secret:=null; outcome:='current';
    elsif p_operation='revoke_participant_link' then outcome:='revoked'; end if;
    kind:='participant_invitation';
  elsif p_operation='accept_participant' then
    perform private.require_group_actor(actor);
    select * into participant_link from private.group_participant_invitations where group_id=p_group and token_digest=p_arguments->>'digest' for update;
    if participant_link.id is null or participant_link.revoked_at is not null or not private.group_is_public(p_group) then
      raise sqlstate 'PT409' using message='This interaction is unavailable.';
    end if;
    select * into membership from private.group_memberships where group_id=p_group and profile_id=actor and ended_at is null;
    if membership.id is not null then relationship:=membership.id; outcome:='already_joined'; kind:='membership';
    elsif private.group_authority_role(p_group,actor)='creator' then relationship:=null; outcome:='creator'; kind:='creator';
    else
      insert into private.group_memberships(group_id,profile_id,admitted_by) values(p_group,actor,actor) returning id into relationship;
      outcome:='joined'; kind:='membership';
      for request in update private.group_join_requests set status='withdrawn',resolved_at=clock_timestamp(),resolved_by=actor,
        resolution_reason='direct_participant_invitation',superseded_by_membership_id=relationship
        where group_id=p_group and requester_id=actor and status='pending' returning *
      loop perform private.audit_group_relationship('group.request_superseded',actor,p_group,request.id); end loop;
    end if;
  elsif p_operation in ('invite_authority','offer') then
    perform private.require_group_manager(p_group,actor,true);
    if offered_role is null or offered_role not in ('co_creator','co_organizer') then raise exception using errcode='22023',message='Invalid group authority role.'; end if;
    if not private.group_is_public(p_group) then raise sqlstate 'PT409' using message='This interaction is unavailable.'; end if;
    if p_operation='offer' then
      select * into membership from private.group_memberships where id=relationship and group_id=p_group for update;
      if membership.id is null or membership.ended_at is not null or membership.profile_id=actor
        or private.group_authority_role(p_group,membership.profile_id) is not null
        or not exists(select 1 from auth.users a join public.profiles p on p.id=a.id where p.id=membership.profile_id and p.display_name is not null) then
        raise sqlstate 'PT409' using message='This interaction is unavailable.';
      end if;
      for invitation in update private.group_authority_invitations set status='revoked',resolved_at=clock_timestamp(),resolved_by=actor
        where group_id=p_group and target_profile_id=membership.profile_id and status='pending' and expires_at<=clock_timestamp() returning *
      loop perform private.audit_group_relationship('group.authority_invitation_revoked',actor,p_group,invitation.id); end loop;
      if exists(select 1 from private.group_authority_invitations where group_id=p_group and target_profile_id=membership.profile_id and status='pending') then
        raise sqlstate 'PT409' using message='A pending role offer already exists.';
      end if;
      insert into private.group_authority_invitations(group_id,issuer_id,offered_role,target_profile_id,target_membership_id)
        values(p_group,actor,offered_role,membership.profile_id,membership.id) returning * into invitation;
    else
      secret:=translate(rtrim(encode(extensions.gen_random_bytes(32),'base64'),'='),'+/','-_');
      insert into private.group_authority_invitations(group_id,issuer_id,offered_role,token_digest)
        values(p_group,actor,offered_role,encode(extensions.digest(secret,'sha256'),'hex')) returning * into invitation;
    end if;
    relationship:=invitation.id; kind:='authority_invitation'; outcome:='offered';
  elsif p_operation in ('accept_authority','decline_offer','revoke_authority_invitation') then
    select * into invitation from private.group_authority_invitations where group_id=p_group
      and ((p_operation='accept_authority' and p_arguments ? 'digest' and token_digest=p_arguments->>'digest') or id=relationship) for update;
    if invitation.id is null then raise exception using errcode='42501',message='The invitation is unavailable.'; end if;
    if p_operation='revoke_authority_invitation' then
      perform private.require_group_manager(p_group,actor,true);
      if invitation.status<>'pending' then raise sqlstate 'PT409' using message='The invitation has already been resolved.'; end if;
      update private.group_authority_invitations set status='revoked',resolved_at=clock_timestamp(),resolved_by=actor where id=invitation.id;
      relationship:=invitation.id; kind:='authority_invitation'; outcome:='revoked';
    else
      if invitation.target_profile_id is not null and invitation.target_profile_id<>actor then raise exception using errcode='42501',message='The invitation is unavailable.'; end if;
      if invitation.status='accepted' and invitation.resolved_by=actor and p_operation='accept_authority' then
        relationship:=invitation.accepted_delegate_id; kind:='delegate'; outcome:='accepted'; changed:=false;
      elsif invitation.status='declined' and invitation.resolved_by=actor and p_operation='decline_offer' then
        relationship:=invitation.id; kind:='authority_invitation'; outcome:='declined'; changed:=false;
      else
        if invitation.status<>'pending' or invitation.expires_at<=clock_timestamp() then raise sqlstate 'PT409' using message='This interaction is unavailable.'; end if;
        if p_operation='decline_offer' then
          if invitation.target_profile_id is null then raise exception using errcode='42501',message='The invitation is unavailable.'; end if;
          update private.group_authority_invitations set status='declined',resolved_at=clock_timestamp(),resolved_by=actor where id=invitation.id;
          relationship:=invitation.id; kind:='authority_invitation'; outcome:='declined';
        else
          perform private.require_group_actor(actor);
          if not private.group_is_public(p_group) or private.group_authority_role(p_group,invitation.issuer_id) is null
            or private.group_authority_role(p_group,invitation.issuer_id)='co_organizer'
            or private.group_authority_role(p_group,actor) is not null
            or (invitation.target_membership_id is not null and not exists(select 1 from private.group_memberships where id=invitation.target_membership_id and profile_id=actor and ended_at is null)) then
            raise sqlstate 'PT409' using message='This interaction is unavailable.';
          end if;
          insert into private.group_delegates(group_id,profile_id,initial_role,delegate_role,granted_by)
            values(p_group,actor,invitation.offered_role,invitation.offered_role,invitation.issuer_id) returning id into relationship;
          update private.group_authority_invitations set status='accepted',resolved_at=clock_timestamp(),resolved_by=actor,accepted_delegate_id=relationship where id=invitation.id;
          kind:='delegate'; outcome:='accepted';
        end if;
      end if;
    end if;
  elsif p_operation in ('change_role','revoke_delegate','step_down') then
    select * into delegate from private.group_delegates where id=relationship and group_id=p_group for update;
    if delegate.id is null then raise exception using errcode='42501',message='The authority is unavailable.'; end if;
    if p_operation='step_down' then
      if delegate.profile_id<>actor then raise exception using errcode='42501',message='The authority is unavailable.'; end if;
    else
      perform private.require_group_manager(p_group,actor,true);
      if delegate.profile_id=actor then raise exception using errcode='42501',message='Use Step down for your own authority.'; end if;
    end if;
    if delegate.revoked_at is not null then
      if p_operation<>'step_down' then raise sqlstate 'PT409' using message='The authority has ended.'; end if;
      outcome:='revoked'; changed:=false;
    elsif p_operation='change_role' then
      if offered_role is null or offered_role not in ('co_creator','co_organizer') then raise exception using errcode='22023',message='Invalid group authority role.'; end if;
      if not private.group_is_public(p_group) or not exists(select 1 from auth.users a join public.profiles p on p.id=a.id where a.id=delegate.profile_id and p.display_name is not null) then
        raise sqlstate 'PT409' using message='This interaction is unavailable.';
      end if;
      if delegate.delegate_role<>offered_role then
        insert into private.group_role_changes(delegate_id,from_role,to_role,actor_id) values(relationship,delegate.delegate_role,offered_role,actor);
        update private.group_delegates set delegate_role=offered_role where id=relationship;
        if delegate.delegate_role='co_creator' then perform private.invalidate_group_authority_invitations(p_group,delegate.profile_id,actor); end if;
      else changed:=false;
      end if;
      outcome:=offered_role;
    else
      update private.group_delegates set revoked_at=clock_timestamp(),revoked_by=actor where id=relationship;
      if delegate.delegate_role='co_creator' then perform private.invalidate_group_authority_invitations(p_group,delegate.profile_id,actor); end if;
      outcome:='revoked';
    end if;
    kind:='delegate';
  else raise exception using errcode='22023',message='Invalid group relationship operation.';
  end if;
  result:=jsonb_build_object('group_id',p_group,'relationship_id',relationship,'relationship_kind',kind,'outcome',outcome);
  if kind='authority_invitation' then result:=result||jsonb_build_object('expires_at',invitation.expires_at); end if;
  insert into private.group_relationship_receipts(actor_id,client_request_id,group_id,intent_hash,result) values(actor,p_key,p_group,intent,result);
  if changed then perform private.audit_group_relationship('group.'||p_operation,actor,p_group,relationship); end if;
  result:=private.group_relationship_result(result,false);
  if secret is not null then result:=result||jsonb_build_object('invite_token',secret); end if;
  return result;
end;
$$;
-- Defense in depth: no direct client/service access, including secret tables.
do $$
declare object_name text;
begin
  foreach object_name in array array['group_join_requests','group_memberships','group_delegates','group_role_changes',
    'group_authority_invitations','group_participant_invitations','group_participant_invitation_secrets','group_relationship_receipts']
  loop
    execute format('alter table private.%I enable row level security',object_name);
    execute format('revoke all on private.%I from public,anon,authenticated,service_role',object_name);
  end loop;
end;
$$;
