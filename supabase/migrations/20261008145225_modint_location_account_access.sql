-- MODINT01 + MAP01: forward-only service-role account boundary.
-- Never use service-role auth.uid(); authorize the verified/stored human actor.
-- Reserve, cached reuse, resolve, issue and apply all pass this helper.
-- Upstream work already started is not recalled or refunded; issuance after a
-- suspension winner fails before any new receipt/result is published.
create or replace function private.lock_location_item(p_actor uuid,p_kind text,p_item uuid)
returns bigint language plpgsql security definer set search_path = '' as $$
declare owner_id uuid; state text; starts timestamptz; revision bigint;
begin
  if p_actor is null or not exists(select 1 from public.profiles where id=p_actor) then
    raise exception using errcode='42501',message='Location actor unavailable.';
  end if;
  -- Same actor barrier as suspension apply/revoke, before any content lock.
  -- Service Auth is not account authorization. Issue uses the stored batch actor.
  perform private.lock_profile_new_interactions(p_actor);
  perform private.assert_profile_account_active(p_actor);
  if p_kind='one_time' then
    select creator_profile_id,lifecycle_state,starts_at,location_revision into owner_id,state,starts,revision
      from public.proposals where id=p_item for update;
    if owner_id is null or not private.profile_has_project_structural_authority(p_item,p_actor)
      or (state='draft' and owner_id<>p_actor) then
      raise exception using errcode='42501',message='Location edit unavailable.';
    end if;
    if state not in ('draft','published') or (state='published' and starts<=statement_timestamp()) then
      raise exception using errcode='55000',message='Location item is immutable.';
    end if;
  elsif p_kind='recurring' then
    select creator_profile_id,lifecycle_state,location_revision into owner_id,state,revision
      from public.recurring_activities where id=p_item for update;
    if owner_id is null or not private.profile_has_project_structural_authority(p_item,p_actor)
      or (state='draft' and owner_id<>p_actor) then
      raise exception using errcode='42501',message='Location edit unavailable.';
    end if;
    if state='ended' then raise exception using errcode='55000',message='Location item is immutable.'; end if;
  elsif p_kind='resource' then
    select owner_profile_id,lifecycle_state,location_revision into owner_id,state,revision
      from public.resource_listings where id=p_item for update;
    if owner_id is null or owner_id<>p_actor then raise exception using errcode='42501',message='Location edit unavailable.'; end if;
    if state='closed' then raise exception using errcode='55000',message='Location item is immutable.'; end if;
  else raise exception using errcode='22023',message='Invalid location item kind.';
  end if;
  return revision;
end;
$$;
revoke all on function private.lock_location_item(uuid,text,uuid) from public, anon, authenticated, service_role;
