-- Explanation-only current own state. Never authorizes a request or discloses
-- another profile, target, case, staff identity, reason or block relationship.
create function public.get_own_interaction_restriction_status(
  p_expected_profile_id uuid
)
returns boolean
language plpgsql stable security definer set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_moderation_identity(
    p_expected_profile_id, false
  );
begin
  return private.profile_has_active_interaction_restriction(current_profile_id);
end;
$$;

revoke all on function public.get_own_interaction_restriction_status(uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.get_own_interaction_restriction_status(uuid)
  to authenticated;
comment on function public.get_own_interaction_restriction_status(uuid) is
  'Fresh minimal own-state explanation projection; expected Auth identity, profile anchor and active-account guards. Denied while suspended. Canonical request mutations remain authoritative.';
