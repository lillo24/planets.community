-- 09C1B: a reversible account-access gate, not a content/membership lifecycle.
-- Existing immutable episodes/actions and active-profile uniqueness are reused.
alter table private.moderation_consequences
  drop constraint moderation_consequences_consequence_type_check,
  drop constraint moderation_consequences_check1,
  add constraint moderation_consequences_consequence_type_check check (
    consequence_type in ('safety_notice', 'interaction_restriction', 'content_hide', 'account_suspension')
  ),
  add constraint moderation_consequences_target_check check (
    (consequence_type in ('safety_notice', 'interaction_restriction', 'account_suspension')
      and project_id is null and resource_listing_id is null)
    or (consequence_type = 'content_hide' and num_nonnulls(project_id, resource_listing_id) = 1)
  );

create function private.profile_has_active_account_suspension(p_profile_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from private.moderation_consequences
    where affected_profile_id = p_profile_id and consequence_type = 'account_suspension'
      and revoked_at is null)
$$;

create function private.assert_profile_account_active(p_profile_id uuid)
returns void language plpgsql stable security definer set search_path = '' as $$
begin
  if p_profile_id is null then
    raise exception using errcode = '42501', message = 'Authentication is required.';
  end if;
  if private.profile_has_active_account_suspension(p_profile_id) then
    raise sqlstate 'PT403' using message = 'Account access is suspended.';
  end if;
end;
$$;

-- No caller-supplied identity: safe for RLS and SECURITY INVOKER profile edits.
create function private.current_account_is_active()
returns boolean language sql stable security definer set search_path = '' as $$
  select (select auth.uid()) is not null
    and not private.profile_has_active_account_suspension((select auth.uid()))
$$;

create function public.assert_own_account_active()
returns void language sql stable security definer set search_path = '' as $$
  select private.assert_profile_account_active((select auth.uid()))
$$;

create function public.get_own_account_suspension_status(p_expected_profile_id uuid)
returns table (is_suspended boolean, consequence_id uuid, applied_at timestamptz, user_reason text)
language plpgsql stable security definer set search_path = '' as $$
declare
  current_profile_id uuid := (select auth.uid());
begin
  -- Deliberately bypass account-active and profile-anchor requirements. This is
  -- the only account-data bootstrap exception, including brand-new identities.
  if current_profile_id is null or p_expected_profile_id is distinct from current_profile_id then
    raise exception using errcode = '42501', message = 'The account identity is unavailable.';
  end if;
  return query select true, episode.id, episode.applied_at, action.user_reason
  from private.moderation_consequences as episode
  join private.moderation_consequence_actions as action
    on action.consequence_id = episode.id and action.action_kind = 'applied'
  where episode.affected_profile_id = current_profile_id
    and episode.consequence_type = 'account_suspension' and episode.revoked_at is null;
  if not found then
    -- Corrupt/incomplete trusted history must not masquerade as an inactive
    -- account. Normal apply writes the episode and action in one transaction.
    if private.profile_has_active_account_suspension(current_profile_id) then
      raise exception using errcode = '55000', message = 'The account suspension status is unavailable.';
    end if;
    return query select false, null::uuid, null::timestamptz, null::text;
  end if;
end;
$$;

create function public.apply_account_suspension(
  p_expected_staff_profile_id uuid, p_case_id uuid,
  p_user_reason text, p_internal_note text
)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  moderation_case private.moderation_cases%rowtype;
  locked_profile_id uuid;
  episode_id uuid;
  action_id uuid;
  linked_note_id uuid;
  normalized_reason text := regexp_replace(coalesce(p_user_reason, ''), '^[[:space:]]+|[[:space:]]+$', '', 'g');
begin
  perform private.require_consequence_staff(p_expected_staff_profile_id);
  if private.require_moderation_staff(p_expected_staff_profile_id) <> 'admin' then
    raise exception using errcode = '42501', message = 'Active admin access is required.';
  end if;
  select * into moderation_case from private.moderation_cases where id = p_case_id for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'The moderation case does not exist.';
  end if;
  if moderation_case.state not in ('under_review', 'completed') then
    raise sqlstate 'PT409' using message = 'The case must be reviewed before applying a consequence.';
  end if;
  if moderation_case.subject_profile_id = p_expected_staff_profile_id then
    raise exception using errcode = '42501', message = 'An admin cannot suspend their own account.';
  end if;
  if char_length(normalized_reason) not between 1 and 2000 then
    raise exception using errcode = '22023', message = 'A reason of 1 to 2,000 characters is required.';
  end if;
  -- Same case -> profile -> domain ordering as 09C1A. Sorting both identities
  -- prevents reciprocal-admin suspension from acquiring opposite profile locks.
  for locked_profile_id in
    select distinct profile_id from unnest(array[p_expected_staff_profile_id, moderation_case.subject_profile_id]) as ids(profile_id)
    order by profile_id
  loop
    perform private.lock_profile_new_interactions(locked_profile_id);
  end loop;
  -- A waiting admin may itself have been suspended by the winning transaction.
  perform private.assert_profile_account_active(p_expected_staff_profile_id);
  if private.profile_has_active_account_suspension(moderation_case.subject_profile_id) then
    raise sqlstate 'PT409' using message = 'An active account suspension already exists.';
  end if;
  select note_id into linked_note_id from public.add_moderation_case_note(p_expected_staff_profile_id, p_case_id, p_internal_note);
  insert into private.moderation_consequences(case_id, consequence_type, affected_profile_id, applied_at)
    values(p_case_id, 'account_suspension', moderation_case.subject_profile_id, clock_timestamp()) returning id into episode_id;
  insert into private.moderation_consequence_actions(consequence_id, action_kind, actor_profile_id, note_id, user_reason)
    values(episode_id, 'applied', p_expected_staff_profile_id, linked_note_id, normalized_reason) returning id into action_id;
  perform private.withdraw_pending_outbound_requests_for_restriction(moderation_case.subject_profile_id);
  perform private.record_moderation_consequence_event(episode_id, action_id);
  return episode_id;
end;
$$;

create function public.revoke_account_suspension(
  p_expected_staff_profile_id uuid, p_consequence_id uuid,
  p_user_reason text, p_internal_note text
)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  episode private.moderation_consequences%rowtype;
  locked_profile_id uuid;
  action_id uuid;
  linked_note_id uuid;
  normalized_reason text := regexp_replace(coalesce(p_user_reason, ''), '^[[:space:]]+|[[:space:]]+$', '', 'g');
begin
  perform private.require_consequence_staff(p_expected_staff_profile_id);
  if private.require_moderation_staff(p_expected_staff_profile_id) <> 'admin' then
    raise exception using errcode = '42501', message = 'Active admin access is required.';
  end if;
  select * into episode from private.moderation_consequences where id = p_consequence_id;
  if not found or episode.consequence_type <> 'account_suspension' then
    raise exception using errcode = 'P0002', message = 'The account suspension does not exist.';
  end if;
  if char_length(normalized_reason) not between 1 and 2000 then
    raise exception using errcode = '22023', message = 'A revocation reason of 1 to 2,000 characters is required.';
  end if;
  perform 1 from private.moderation_cases where id = episode.case_id for update;
  for locked_profile_id in
    select distinct profile_id from unnest(array[p_expected_staff_profile_id, episode.affected_profile_id]) as ids(profile_id)
    order by profile_id
  loop
    perform private.lock_profile_new_interactions(locked_profile_id);
  end loop;
  perform private.assert_profile_account_active(p_expected_staff_profile_id);
  select * into episode from private.moderation_consequences where id = p_consequence_id for update;
  if episode.revoked_at is not null then
    raise sqlstate 'PT409' using message = 'The account suspension is no longer active.';
  end if;
  select note_id into linked_note_id from public.add_moderation_case_note(p_expected_staff_profile_id, episode.case_id, p_internal_note);
  insert into private.moderation_consequence_actions(consequence_id, action_kind, actor_profile_id, note_id, user_reason)
    values(episode.id, 'revoked', p_expected_staff_profile_id, linked_note_id, normalized_reason) returning id into action_id;
  -- Capture closure after the lock wait; preserve temporal validity even if the
  -- local wall clock steps backwards. No memberships/roles/requests resurrect.
  update private.moderation_consequences set revoked_at = greatest(applied_at, clock_timestamp()) where id = episode.id;
  perform private.record_moderation_consequence_event(episode.id, action_id);
  return episode.id;
end;
$$;

revoke all on function private.profile_has_active_account_suspension(uuid),
  private.assert_profile_account_active(uuid), private.current_account_is_active(), public.assert_own_account_active(),
  public.get_own_account_suspension_status(uuid), public.apply_account_suspension(uuid,uuid,text,text),
  public.revoke_account_suspension(uuid,uuid,text,text)
  from public, anon, authenticated, service_role;
grant execute on function private.current_account_is_active(), public.assert_own_account_active(),
  public.get_own_account_suspension_status(uuid), public.apply_account_suspension(uuid,uuid,text,text),
  public.revoke_account_suspension(uuid,uuid,text,text) to authenticated;
comment on function public.get_own_account_suspension_status(uuid) is
  'Own-identity suspension bootstrap exception: active ID/time/apply reason only; no case, staff, evidence, other consequence or note fields.';
