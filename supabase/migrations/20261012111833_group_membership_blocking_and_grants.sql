-- Extend the canonical block convergence hook after its existing Project and
-- Resource work. Copy its current definition verbatim under a private name,
-- then replace the original IN PLACE: warmed PostgREST/PLpgSQL plans retain
-- that original function OID and must invoke the new group hook after upgrade.
do $$
declare definition text := pg_get_functiondef('private.close_pending_direct_requests_for_user_block(uuid,uuid)'::regprocedure);
begin
  if strpos(definition,'FUNCTION private.close_pending_direct_requests_for_user_block(')=0 then
    raise exception 'The canonical blocking hook definition is unavailable.';
  end if;
  execute replace(definition,'FUNCTION private.close_pending_direct_requests_for_user_block(',
    'FUNCTION private.close_pending_project_resource_requests_for_user_block(');
end;
$$;
create or replace function private.close_pending_direct_requests_for_user_block(p_blocker_profile_id uuid,p_blocked_profile_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare candidate record; request private.group_join_requests%rowtype; outcome text;
begin
  perform private.close_pending_project_resource_requests_for_user_block(p_blocker_profile_id,p_blocked_profile_id);
  -- block_user already holds the canonical pair lock. Group commands never
  -- acquire Project/Resource rows; visit groups/requests in immutable ID order.
  for candidate in select r.id,r.group_id from private.group_join_requests r where r.status='pending'
    and ((r.requester_id=p_blocker_profile_id and private.group_authority_role(r.group_id,p_blocked_profile_id) is not null)
      or (r.requester_id=p_blocked_profile_id and private.group_authority_role(r.group_id,p_blocker_profile_id) is not null))
    order by r.group_id,r.id
  loop
    perform 1 from private.community_groups where id=candidate.group_id for update;
    select * into request from private.group_join_requests where id=candidate.id for update;
    if request.status<>'pending' then continue; end if;
    if request.requester_id=p_blocker_profile_id and private.group_authority_role(request.group_id,p_blocked_profile_id) is not null then outcome:='withdrawn';
    elsif request.requester_id=p_blocked_profile_id and private.group_authority_role(request.group_id,p_blocker_profile_id) is not null then outcome:='rejected';
    else continue; end if;
    update private.group_join_requests set status=outcome,resolved_at=clock_timestamp(),resolved_by=p_blocker_profile_id,resolution_reason='blocking' where id=request.id;
    perform private.audit_group_relationship('group.request_'||outcome,p_blocker_profile_id,request.group_id,request.id);
  end loop;
end;
$$;

-- Private helpers are never directly callable, even with a service-role JWT.
do $$
declare object record;
begin
  for object in select p.oid::regprocedure as signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='private' and p.proname in ('protect_group_relationship_provenance','require_group_identity',
      'group_has_accountable_identity','group_authority_role','current_group_manager_profile_ids','require_group_manager',
      'lock_group_interactions','audit_group_relationship','invalidate_group_authority_invitations','group_relationship_result','group_can_read_relationship_history',
      'group_relationship_command','read_group_participant_link','validate_group_page','require_group_people_viewer',
      'group_structural_command','close_pending_direct_requests_for_user_block','close_pending_project_resource_requests_for_user_block')
  loop execute format('revoke all on function %s from public,anon,authenticated,service_role',object.signature); end loop;
end;
$$;
do $$
declare object record;
begin
  for object in select p.oid::regprocedure as signature,p.proname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname=any(array['create_group_join_request','withdraw_group_join_request','accept_group_join_request','reject_group_join_request','leave_group','remove_group_member','create_group_authority_invitation','create_group_role_offer','accept_group_role_offer','decline_group_role_offer','revoke_group_authority_invitation','change_group_delegate_role','revoke_group_delegate','step_down_group_authority','accept_group_authority_invitation','accept_group_participant_invitation','recover_group_relationship_command','create_group_participant_invitation','regenerate_group_participant_invitation','revoke_group_participant_invitation','get_current_group_participant_invitation','get_group_participant_invitation_preview','get_group_authority_invitation_preview','get_own_group_role','list_current_group_people','list_own_group_join_requests','list_own_group_memberships','list_group_join_requests','list_group_membership_history','list_group_delegates','list_group_delegate_role_history','list_group_authority_invitations','list_own_group_role_offers','list_group_participant_invitation_history','list_managed_groups','get_group_structural_context','update_managed_group','set_managed_group_publication_state','recover_group_structural_command'])
  loop
    execute format('revoke all on function %s from public,anon,authenticated,service_role',object.signature);
    execute format('grant execute on function %s to authenticated',object.signature);
    if object.proname in ('get_group_participant_invitation_preview','get_group_authority_invitation_preview') then
      execute format('grant execute on function %s to anon',object.signature);
    end if;
  end loop;
end;
$$;
notify pgrst,'reload schema';
