-- PROFILEPRIV01: independent content and visibility writes.
create function public.update_own_profile_content_v1(
  p_expected_profile_id uuid,
  p_display_name text,
  p_bio text,
  p_skill_ids uuid[]
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  current_profile_id uuid := (select auth.uid());
  normalized_display_name text := btrim(coalesce(p_display_name, ''));
  normalized_bio text := nullif(btrim(p_bio), '');
begin
  if current_profile_id is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication is required to update a profile.';
  end if;

  if p_expected_profile_id is null
    or p_expected_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'The authenticated user does not match the expected profile.';
  end if;

  if char_length(normalized_display_name) not between 2 and 60 then
    raise exception using
      errcode = '22023',
      message = 'Display name must contain between 2 and 60 characters.';
  end if;

  if normalized_bio is not null and char_length(normalized_bio) > 500 then
    raise exception using
      errcode = '22023',
      message = 'Bio must contain at most 500 characters.';
  end if;

  if p_skill_ids is null or array_position(p_skill_ids, null) is not null then
    raise exception using
      errcode = '22023',
      message = 'Skill identifiers must be a non-null list of known skills.';
  end if;

  if exists (
    select 1
    from unnest(p_skill_ids) as requested(skill_id)
    left join public.skills as skill on skill.id = requested.skill_id
    where skill.id is null
  ) then
    raise exception using
      errcode = '22023',
      message = 'One or more skill identifiers are not in the catalog.';
  end if;

  update public.profiles
  set
    display_name = normalized_display_name,
    bio = normalized_bio
  where id = current_profile_id;

  if not found then
    raise exception using
      errcode = '55000',
      message = 'The current user does not have a profile anchor.';
  end if;

  delete from public.profile_skills
  where profile_id = current_profile_id
    and not (skill_id = any(p_skill_ids));

  insert into public.profile_skills (profile_id, skill_id)
  select current_profile_id, requested.skill_id
  from (
    select distinct skill_id
    from unnest(p_skill_ids) as selected(skill_id)
  ) as requested
  on conflict (profile_id, skill_id) do nothing;

end;
$$;

revoke all privileges on function public.update_own_profile_content_v1(uuid, text, text, uuid[])
  from public, anon, authenticated, service_role;
grant execute on function public.update_own_profile_content_v1(uuid, text, text, uuid[])
  to authenticated;
comment on function public.update_own_profile_content_v1(uuid, text, text, uuid[]) is
  'Owner-bound atomic content/skills update; never reads or writes field audiences. Legacy combined RPC remains compatible.';
