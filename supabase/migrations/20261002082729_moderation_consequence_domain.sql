-- 09C1A: manual, reversible episodes. Evidence review and owner lifecycles stay
-- independent. API roles have no direct access, including service_role.
create table private.moderation_consequences (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references private.moderation_cases(id) on delete restrict,
  consequence_type text not null check (
    consequence_type in ('safety_notice', 'interaction_restriction', 'content_hide')
  ),
  affected_profile_id uuid not null references public.profiles(id) on delete restrict,
  project_id uuid references public.projects(id) on delete restrict,
  resource_listing_id uuid references public.resource_listings(id) on delete restrict,
  applied_at timestamptz not null default statement_timestamp(),
  revoked_at timestamptz,
  check (revoked_at is null or revoked_at >= applied_at),
  check (
    (consequence_type in ('safety_notice', 'interaction_restriction')
      and project_id is null and resource_listing_id is null)
    or (consequence_type = 'content_hide'
      and num_nonnulls(project_id, resource_listing_id) = 1)
  )
);
create unique index moderation_consequences_active_profile_idx
  on private.moderation_consequences(affected_profile_id, consequence_type)
  where revoked_at is null and consequence_type <> 'content_hide';
create unique index moderation_consequences_active_project_idx
  on private.moderation_consequences(project_id)
  where revoked_at is null and consequence_type = 'content_hide' and project_id is not null;
create unique index moderation_consequences_active_resource_idx
  on private.moderation_consequences(resource_listing_id)
  where revoked_at is null and consequence_type = 'content_hide' and resource_listing_id is not null;
create index moderation_consequences_case_idx on private.moderation_consequences(case_id);
create index moderation_consequences_affected_history_idx
  on private.moderation_consequences(affected_profile_id, applied_at desc, id desc);
create index moderation_consequences_project_idx on private.moderation_consequences(project_id);
create index moderation_consequences_resource_idx on private.moderation_consequences(resource_listing_id);

create table private.moderation_consequence_actions (
  id uuid primary key default gen_random_uuid(),
  consequence_id uuid not null references private.moderation_consequences(id) on delete restrict,
  action_kind text not null check (action_kind in ('applied', 'revoked')),
  actor_profile_id uuid not null references public.profiles(id) on delete restrict,
  note_id uuid not null references private.moderation_case_notes(id) on delete restrict,
  user_reason text not null check (
    user_reason = regexp_replace(user_reason, '^[[:space:]]+|[[:space:]]+$', '', 'g')
    and char_length(user_reason) between 1 and 2000
  ),
  created_at timestamptz not null default statement_timestamp(),
  unique(consequence_id, action_kind)
);
create index moderation_consequence_actions_actor_idx on private.moderation_consequence_actions(actor_profile_id);
create index moderation_consequence_actions_note_idx on private.moderation_consequence_actions(note_id);
alter table private.moderation_consequences enable row level security;
alter table private.moderation_consequence_actions enable row level security;
revoke all on private.moderation_consequences, private.moderation_consequence_actions
  from public, anon, authenticated, service_role;

create function private.protect_moderation_consequence_history()
returns trigger language plpgsql set search_path = '' as $$
begin
  if tg_op = 'DELETE' then
    raise exception using errcode = '55000', message = 'Consequence history cannot be deleted.';
  end if;
  if (to_jsonb(new) - 'revoked_at') is distinct from (to_jsonb(old) - 'revoked_at')
    or old.revoked_at is not null or new.revoked_at is null then
    raise exception using errcode = '55000', message = 'Only an active consequence may be closed once.';
  end if;
  return new;
end;
$$;
create trigger moderation_consequences_preserve_history
  before update or delete on private.moderation_consequences
  for each row execute function private.protect_moderation_consequence_history();
create trigger moderation_consequence_actions_append_only
  before update or delete on private.moderation_consequence_actions
  for each row execute function private.protect_moderation_append_only();

create function private.profile_has_active_safety_notice(p_profile_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from private.moderation_consequences
    where affected_profile_id = p_profile_id and consequence_type = 'safety_notice' and revoked_at is null)
$$;
create function private.profile_has_active_interaction_restriction(p_profile_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from private.moderation_consequences
    where affected_profile_id = p_profile_id and consequence_type = 'interaction_restriction' and revoked_at is null)
$$;
create function private.project_has_active_content_hide(p_project_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from private.moderation_consequences
    where project_id = p_project_id and consequence_type = 'content_hide' and revoked_at is null)
$$;
create function private.resource_listing_has_active_content_hide(p_listing_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from private.moderation_consequences
    where resource_listing_id = p_listing_id and consequence_type = 'content_hide' and revoked_at is null)
$$;
create function private.lock_profile_new_interactions(p_profile_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if p_profile_id is null then
    raise exception using errcode = '22023', message = 'An interaction profile is required.';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    'planets.moderation.new-interactions:' || p_profile_id::text, 0
  ));
end;
$$;
create function private.assert_profile_new_interactions_available(p_profile_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if private.profile_has_active_interaction_restriction(p_profile_id) then
    raise sqlstate 'PT409' using message = 'This interaction is unavailable.';
  end if;
end;
$$;
create function private.require_consequence_staff(p_expected_profile_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_moderation_staff(p_expected_profile_id);
  -- Role removal serializes with the complete mutation, not a stale JWT.
  perform 1 from private.moderation_staff_roles
  where profile_id = p_expected_profile_id and is_active
    and staff_role in ('moderator', 'admin') for share;
  if not found then
    raise exception using errcode = '42501', message = 'Moderation staff access is required.';
  end if;
end;
$$;

create function private.withdraw_pending_outbound_requests_for_restriction(p_profile_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  candidate record;
  project_record record;
  project_request public.project_join_requests%rowtype;
  listing public.resource_listings%rowtype;
  resource_request public.resource_listing_requests%rowtype;
begin
  -- The profile barrier is held. No pair locks are needed: block cleanup and
  -- withdrawals only take concrete/shared/request rows in the existing order.
  for candidate in select id, project_id from public.project_join_requests
    where requester_profile_id = p_profile_id and status = 'pending'
    order by project_id, id
  loop
    select * into project_record from private.lock_project_for_participation(candidate.project_id, false);
    select * into project_request from public.project_join_requests
      where id = candidate.id for update;
    if project_request.status <> 'pending' then continue; end if;
    update public.project_join_requests set status = 'withdrawn',
      resolved_at = statement_timestamp(), resolved_by_profile_id = p_profile_id
      where id = candidate.id;
    perform private.record_project_participation_event(
      'project.join_request_withdrawn', p_profile_id, candidate.project_id,
      jsonb_build_object('project_kind', project_record.project_kind,
        'request_id', candidate.id, 'requester_profile_id', p_profile_id, 'status', 'withdrawn')
    );
  end loop;
  for candidate in select id, listing_id from public.resource_listing_requests
    where requester_profile_id = p_profile_id and status = 'pending'
    order by listing_id, id
  loop
    select * into listing from public.resource_listings where id = candidate.listing_id for update;
    select * into resource_request from public.resource_listing_requests where id = candidate.id for update;
    if resource_request.status <> 'pending' then continue; end if;
    update public.resource_listing_requests set status = 'withdrawn',
      resolved_at = statement_timestamp(), resolved_by_profile_id = p_profile_id
      where id = candidate.id;
    perform private.record_resource_listing_request_event(
      'resource_listing.request_withdrawn', candidate.id, listing.id,
      listing.owner_profile_id, p_profile_id, p_profile_id
    );
  end loop;
end;
$$;

create function private.record_moderation_consequence_event(p_consequence_id uuid, p_action_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  episode private.moderation_consequences%rowtype;
  command private.moderation_consequence_actions%rowtype;
  event_payload jsonb;
  event_type_value text;
begin
  select * into strict episode from private.moderation_consequences where id = p_consequence_id;
  select * into strict command from private.moderation_consequence_actions
    where id = p_action_id and consequence_id = episode.id;
  event_type_value := 'moderation.' || episode.consequence_type || '_' || command.action_kind;
  event_payload := jsonb_strip_nulls(jsonb_build_object(
    'consequence_id', episode.id, 'consequence_action_id', command.id,
    'case_id', episode.case_id, 'affected_profile_id', episode.affected_profile_id,
    'project_id', episode.project_id, 'resource_listing_id', episode.resource_listing_id
  ));
  insert into private.audit_events(action, actor_user_id, target_type, target_id, metadata)
    values(event_type_value, command.actor_profile_id, 'moderation_consequence', episode.id, event_payload);
  insert into private.outbox_events(event_type, payload) values(event_type_value, event_payload);
end;
$$;

create function public.apply_moderation_consequence(
  p_expected_staff_profile_id uuid, p_case_id uuid, p_consequence_type text,
  p_user_reason text, p_internal_note text
)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  moderation_case private.moderation_cases%rowtype;
  v_affected_profile_id uuid;
  target_project_id uuid;
  target_listing_id uuid;
  episode_id uuid;
  action_id uuid;
  linked_note_id uuid;
  normalized_reason text := regexp_replace(coalesce(p_user_reason, ''), '^[[:space:]]+|[[:space:]]+$', '', 'g');
begin
  perform private.require_consequence_staff(p_expected_staff_profile_id);
  select * into moderation_case from private.moderation_cases where id = p_case_id for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'The moderation case does not exist.';
  end if;
  if moderation_case.state not in ('under_review', 'completed') then
    raise sqlstate 'PT409' using message = 'The case must be reviewed before applying a consequence.';
  end if;
  if p_consequence_type is null or p_consequence_type not in ('safety_notice', 'interaction_restriction', 'content_hide')
    or char_length(normalized_reason) not between 1 and 2000 then
    raise exception using errcode = '22023', message = 'A valid consequence type and reason of 1 to 2,000 characters are required.';
  end if;
  if p_consequence_type = 'content_hide' then
    if moderation_case.target_kind = 'project' then
      target_project_id := moderation_case.target_project_id;
      perform 1 from private.lock_project_for_participation(target_project_id, false);
      select creator_profile_id into v_affected_profile_id from public.projects where id = target_project_id;
    elsif moderation_case.target_kind = 'resource_listing' then
      target_listing_id := moderation_case.target_resource_listing_id;
      select owner_profile_id into v_affected_profile_id from public.resource_listings where id = target_listing_id for update;
    else
      raise exception using errcode = '22023', message = 'Content hide requires a Project or Resource listing case.';
    end if;
  else
    v_affected_profile_id := moderation_case.subject_profile_id;
    perform private.lock_profile_new_interactions(v_affected_profile_id);
  end if;
  if exists (select 1 from private.moderation_consequences as episode
    where episode.revoked_at is null and episode.consequence_type = p_consequence_type
      and ((p_consequence_type <> 'content_hide' and episode.affected_profile_id = v_affected_profile_id)
        or episode.project_id = target_project_id or episode.resource_listing_id = target_listing_id)) then
    raise sqlstate 'PT409' using message = 'An active consequence already exists for this target.';
  end if;
  select note_id into linked_note_id from public.add_moderation_case_note(p_expected_staff_profile_id, p_case_id, p_internal_note);
  insert into private.moderation_consequences(case_id, consequence_type, affected_profile_id, project_id, resource_listing_id)
    values(p_case_id, p_consequence_type, v_affected_profile_id, target_project_id, target_listing_id) returning id into episode_id;
  insert into private.moderation_consequence_actions(consequence_id, action_kind, actor_profile_id, note_id, user_reason)
    values(episode_id, 'applied', p_expected_staff_profile_id, linked_note_id, normalized_reason) returning id into action_id;
  if p_consequence_type = 'interaction_restriction' then
    perform private.withdraw_pending_outbound_requests_for_restriction(v_affected_profile_id);
  end if;
  perform private.record_moderation_consequence_event(episode_id, action_id);
  return episode_id;
end;
$$;

create function public.revoke_moderation_consequence(
  p_expected_staff_profile_id uuid, p_consequence_id uuid,
  p_user_reason text, p_internal_note text
)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  episode private.moderation_consequences%rowtype;
  action_id uuid;
  linked_note_id uuid;
  normalized_reason text := regexp_replace(coalesce(p_user_reason, ''), '^[[:space:]]+|[[:space:]]+$', '', 'g');
begin
  perform private.require_consequence_staff(p_expected_staff_profile_id);
  select * into episode from private.moderation_consequences where id = p_consequence_id;
  if not found then
    raise exception using errcode = 'P0002', message = 'The moderation consequence does not exist.';
  end if;
  if char_length(normalized_reason) not between 1 and 2000 then
    raise exception using errcode = '22023', message = 'A revocation reason of 1 to 2,000 characters is required.';
  end if;
  perform 1 from private.moderation_cases where id = episode.case_id for update;
  if episode.project_id is not null then
    perform 1 from private.lock_project_for_participation(episode.project_id, false);
  elsif episode.resource_listing_id is not null then
    perform 1 from public.resource_listings where id = episode.resource_listing_id for update;
  else
    perform private.lock_profile_new_interactions(episode.affected_profile_id);
  end if;
  select * into episode from private.moderation_consequences where id = p_consequence_id for update;
  if episode.revoked_at is not null then
    raise sqlstate 'PT409' using message = 'The consequence is no longer active.';
  end if;
  select note_id into linked_note_id from public.add_moderation_case_note(p_expected_staff_profile_id, episode.case_id, p_internal_note);
  insert into private.moderation_consequence_actions(consequence_id, action_kind, actor_profile_id, note_id, user_reason)
    values(episode.id, 'revoked', p_expected_staff_profile_id, linked_note_id, normalized_reason) returning id into action_id;
  update private.moderation_consequences set revoked_at = statement_timestamp() where id = episode.id;
  perform private.record_moderation_consequence_event(episode.id, action_id);
  return episode.id;
end;
$$;

create function public.list_own_moderation_consequences(
  p_expected_profile_id uuid, p_limit integer default 20,
  p_before_applied_at timestamptz default null, p_before_consequence_id uuid default null
)
returns table(consequence_id uuid, consequence_type text, is_active boolean,
  applied_at timestamptz, apply_reason text, revoked_at timestamptz, revoke_reason text,
  content_kind text, content_id uuid, content_title text)
language plpgsql stable security definer set search_path = '' as $$
declare
  current_profile_id uuid := private.require_moderation_identity(p_expected_profile_id, false);
begin
  if p_limit is null or p_limit not between 1 and 50
    or (p_before_applied_at is null) <> (p_before_consequence_id is null) then
    raise exception using errcode = '22023', message = 'A bounded page and complete consequence cursor are required.';
  end if;
  return query select episode.id, episode.consequence_type, episode.revoked_at is null,
    episode.applied_at, applied.user_reason, episode.revoked_at, revoked.user_reason,
    case when episode.project_id is not null then project.project_kind
      when episode.resource_listing_id is not null then 'resource_listing' end,
    coalesce(episode.project_id, episode.resource_listing_id),
    coalesce(proposal.title, activity.title, listing.title)
  from private.moderation_consequences as episode
  join private.moderation_consequence_actions as applied
    on applied.consequence_id = episode.id and applied.action_kind = 'applied'
  left join private.moderation_consequence_actions as revoked
    on revoked.consequence_id = episode.id and revoked.action_kind = 'revoked'
  left join public.projects as project on project.id = episode.project_id
  left join public.proposals as proposal on proposal.id = episode.project_id
  left join public.recurring_activities as activity on activity.id = episode.project_id
  left join public.resource_listings as listing on listing.id = episode.resource_listing_id
  where episode.affected_profile_id = current_profile_id
    and (p_before_applied_at is null or (episode.applied_at, episode.id) < (p_before_applied_at, p_before_consequence_id))
  order by episode.applied_at desc, episode.id desc limit p_limit;
end;
$$;
create function public.list_moderation_case_consequence_history(p_expected_staff_profile_id uuid, p_case_id uuid)
returns table(consequence_id uuid, consequence_type text, affected_profile_id uuid,
  project_id uuid, resource_listing_id uuid, applied_at timestamptz, revoked_at timestamptz,
  action_id uuid, action_kind text, user_reason text, note_id uuid, actor_profile_id uuid, action_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.require_moderation_staff(p_expected_staff_profile_id);
  return query select episode.id, episode.consequence_type, episode.affected_profile_id,
    episode.project_id, episode.resource_listing_id, episode.applied_at, episode.revoked_at,
    command.id, command.action_kind, command.user_reason, command.note_id, command.actor_profile_id, command.created_at
  from private.moderation_consequences as episode
  join private.moderation_consequence_actions as command on command.consequence_id = episode.id
  where episode.case_id = p_case_id order by episode.applied_at, episode.id, command.created_at, command.action_kind;
end;
$$;

revoke all on function private.protect_moderation_consequence_history(),
  private.profile_has_active_safety_notice(uuid), private.profile_has_active_interaction_restriction(uuid),
  private.project_has_active_content_hide(uuid), private.resource_listing_has_active_content_hide(uuid),
  private.lock_profile_new_interactions(uuid), private.assert_profile_new_interactions_available(uuid),
  private.require_consequence_staff(uuid), private.withdraw_pending_outbound_requests_for_restriction(uuid),
  private.record_moderation_consequence_event(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.apply_moderation_consequence(uuid, uuid, text, text, text),
  public.revoke_moderation_consequence(uuid, uuid, text, text),
  public.list_own_moderation_consequences(uuid, integer, timestamptz, uuid),
  public.list_moderation_case_consequence_history(uuid, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.apply_moderation_consequence(uuid, uuid, text, text, text),
  public.revoke_moderation_consequence(uuid, uuid, text, text),
  public.list_own_moderation_consequences(uuid, integer, timestamptz, uuid),
  public.list_moderation_case_consequence_history(uuid, uuid) to authenticated;
comment on table private.moderation_consequences is
  'Manual reversible consequence episodes with immutable canonical targets. Only revoke closes an episode; reapply creates a new ID. No evidence automation or retention policy.';
comment on table private.moderation_consequence_actions is
  'Append-only apply/revoke reasons linked to staff-only case notes. Bodies are absent from audit/outbox/Realtime.';
comment on function public.apply_moderation_consequence(uuid, uuid, text, text, text) is
  'Active-staff, identity-bound atomic manual apply. Targets derive from a reviewed case; duplicates conflict with PT409. No idempotency key is supported.';
comment on function public.revoke_moderation_consequence(uuid, uuid, text, text) is
  'Active-staff atomic revoke with required user reason and private note. Restores only future eligibility/visibility; does not reopen requests or owner lifecycles.';
comment on function public.list_own_moderation_consequences(uuid, integer, timestamptz, uuid) is
  'Affected-user-only bounded history. Content-hide reasons belong solely to the immutable Creator or listing owner, never delegated managers.';
comment on function private.record_moderation_consequence_event(uuid, uuid) is
  'Identifier-only moderation.{safety_notice,interaction_restriction,content_hide}_{applied,revoked} source events, intentionally unconsumed until 09C2.';
