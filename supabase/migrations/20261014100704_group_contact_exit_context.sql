-- Own original-admission metadata supports safe exit after authority loss.
-- This grants no body, audience, group identity, preview or unread permission.
create function public.has_own_group_contact_admission(p_expected_profile_id uuid,p_chat_id uuid) returns boolean
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id);
begin
  return exists(select 1 from private.group_contact_admissions a where
    a.conversation_id=p_chat_id and a.profile_id=actor and a.left_at is null);
end; $$;
revoke all on function public.has_own_group_contact_admission(uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.has_own_group_contact_admission(uuid,uuid) to authenticated;
