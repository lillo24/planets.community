-- Minimal self context for explicit sender disclosure; no other profile fields.
create function public.get_own_group_contact_sender(p_expected_profile_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_group_identity(p_expected_profile_id);
begin
  return (select jsonb_build_object('profile_id',actor,'display_name',p.display_name) from public.profiles p where p.id=actor);
end; $$;
revoke all on function public.get_own_group_contact_sender(uuid) from public,anon,authenticated,service_role;
grant execute on function public.get_own_group_contact_sender(uuid) to authenticated;

create or replace function private.group_contact_identity_access() returns trigger
language plpgsql security definer set search_path='' as $$
declare recipient uuid; subject uuid:=coalesce(new.id,old.id);
begin
  -- The sender form can exist before a first admission, so invalidate its own
  -- name/eligibility context as well. This still carries only the recipient ID.
  perform private.group_contact_access_signal(subject);
  for recipient in select distinct b.profile_id from private.group_contact_admissions a join private.group_contact_admissions b on b.conversation_id=a.conversation_id
    where a.profile_id=subject and b.profile_id<>subject and b.left_at is null order by b.profile_id
  loop perform private.group_contact_access_signal(recipient); end loop;
  return coalesce(new,old);
end; $$;
