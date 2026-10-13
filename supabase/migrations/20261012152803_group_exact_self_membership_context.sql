-- Exact self state, independent of public eligibility and history pagination.
-- No names/content from private groups, and never another person's request.
create function public.get_own_group_membership_context(p_expected_profile_id uuid, p_group_id uuid)
returns table(authority_role text, delegate_id uuid, current_membership_id uuid,
  membership_status text, pending_request_id uuid, pending_note text,
  latest_request_id uuid, latest_request_status text, latest_membership_id uuid,
  latest_membership_status text)
language plpgsql stable security definer set search_path = '' as $$
declare actor uuid := private.require_group_identity(p_expected_profile_id);
begin
  return query select private.group_authority_role(p_group_id, actor), d.id, m.id,
    case when m.id is not null then 'current' end, r.id, r.note, lr.id, lr.status,
    lm.id, coalesce(lm.end_reason, case when lm.id is not null then 'current' end)
  from (select 1) seed
  left join lateral (select x.id from private.group_delegates x where x.group_id=p_group_id and x.profile_id=actor and x.revoked_at is null) d on true
  left join lateral (select x.id from private.group_memberships x where x.group_id=p_group_id and x.profile_id=actor and x.ended_at is null) m on true
  left join lateral (select x.id,x.note from private.group_join_requests x where x.group_id=p_group_id and x.requester_id=actor and x.status='pending') r on true
  left join lateral (select x.id,x.status from private.group_join_requests x where x.group_id=p_group_id and x.requester_id=actor order by x.created_at desc,x.id desc limit 1) lr on true
  left join lateral (select x.id,x.end_reason from private.group_memberships x where x.group_id=p_group_id and x.profile_id=actor order by x.joined_at desc,x.id desc limit 1) lm on true;
end;
$$;
revoke all on function public.get_own_group_membership_context(uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.get_own_group_membership_context(uuid,uuid) to authenticated;
