-- 09C1B: keep existing domain contracts, identity checks and lock hierarchy.
-- Explicit replacements of the exact 09C1A base; no runtime source rewriting.
CREATE OR REPLACE FUNCTION private.require_cover_identity(p_expected_profile_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  current_profile_id uuid := (select auth.uid());
begin
  if current_profile_id is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication is required to manage cover media.';
  end if;

  if p_expected_profile_id is null
    or p_expected_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'The authenticated user does not match the expected cover owner.';
  end if;

  perform private.assert_profile_account_active(current_profile_id);
  return current_profile_id;
end;
$function$;

CREATE OR REPLACE FUNCTION private.require_expected_identity(p_expected_profile_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  current_profile_id uuid := (select auth.uid());
begin
  if current_profile_id is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication is required to manage a proposal.';
  end if;

  if p_expected_profile_id is null
    or p_expected_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'The authenticated user does not match the expected proposal creator.';
  end if;

  perform private.assert_profile_account_active(current_profile_id);
  return current_profile_id;
end;
$function$;

CREATE OR REPLACE FUNCTION private.require_expected_recurring_activity_identity(p_expected_profile_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  current_profile_id uuid := (select auth.uid());
begin
  if current_profile_id is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication is required to manage a recurring activity.';
  end if;

  if p_expected_profile_id is null
    or p_expected_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'The authenticated user does not match the expected recurring activity creator.';
  end if;

  perform private.assert_profile_account_active(current_profile_id);
  return current_profile_id;
end;
$function$;

CREATE OR REPLACE FUNCTION private.require_moderation_identity(p_expected_profile_id uuid, p_require_complete boolean DEFAULT true)
 RETURNS uuid
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  current_profile_id uuid := (select auth.uid());
  current_display_name text;
begin
  if current_profile_id is null
    or p_expected_profile_id is null
    or p_expected_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'The moderation identity is unavailable.';
  end if;

  select profile.display_name into current_display_name
  from public.profiles as profile
  where profile.id = current_profile_id;

  if not found or (p_require_complete and current_display_name is null) then
    raise exception using
      errcode = '42501',
      message = 'The moderation identity is unavailable.';
  end if;

  perform private.assert_profile_account_active(current_profile_id);
  return current_profile_id;
end;
$function$;

CREATE OR REPLACE FUNCTION private.require_notification_identity(p_expected_profile_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  current_profile_id uuid := (select auth.uid());
begin
  if current_profile_id is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication is required for notifications.';
  end if;

  if p_expected_profile_id is null or p_expected_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'The authenticated user does not match the expected notification identity.';
  end if;

  if not exists (
    select 1
    from public.profiles as profile
    where profile.id = current_profile_id
  ) then
    raise exception using
      errcode = '42501',
      message = 'The authenticated user has no profile identity.';
  end if;

  perform private.assert_profile_account_active(current_profile_id);
  return current_profile_id;
end;
$function$;

CREATE OR REPLACE FUNCTION private.require_participation_identity(p_expected_profile_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  current_profile_id uuid := (select auth.uid());
begin
  if current_profile_id is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication is required for project participation.';
  end if;

  if p_expected_profile_id is null or p_expected_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'The authenticated user does not match the expected participant identity.';
  end if;

  perform private.assert_profile_account_active(current_profile_id);
  return current_profile_id;
end;
$function$;

CREATE OR REPLACE FUNCTION private.require_profile_photo_identity(p_expected_profile_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  current_profile_id uuid := (select auth.uid());
begin
  if current_profile_id is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication is required to manage a profile photo.';
  end if;

  if p_expected_profile_id is null
    or p_expected_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'The authenticated user does not match the expected profile.';
  end if;

  perform private.assert_profile_account_active(current_profile_id);
  return current_profile_id;
end;
$function$;

CREATE OR REPLACE FUNCTION private.require_push_identity(p_expected_profile_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  current_profile_id uuid := (select auth.uid());
begin
  if current_profile_id is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication is required for push registration.';
  end if;

  if p_expected_profile_id is null or p_expected_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'The authenticated user does not match the expected push-registration identity.';
  end if;

  if not exists (
    select 1
    from public.profiles as profile
    where profile.id = current_profile_id
  ) then
    raise exception using
      errcode = '42501',
      message = 'The authenticated user has no profile identity.';
  end if;

  perform private.assert_profile_account_active(current_profile_id);
  return current_profile_id;
end;
$function$;

CREATE OR REPLACE FUNCTION private.require_resource_listing_identity(p_expected_profile_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  current_profile_id uuid := (select auth.uid());
begin
  if current_profile_id is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication is required to manage a resource listing.';
  end if;

  if p_expected_profile_id is null
    or p_expected_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'The authenticated user does not match the expected resource listing owner.';
  end if;

  if not exists (
    select 1
    from public.profiles as profile
    where profile.id = current_profile_id
  ) then
    raise exception using
      errcode = '55000',
      message = 'The current user does not have a profile anchor.';
  end if;

  perform private.assert_profile_account_active(current_profile_id);
  return current_profile_id;
end;
$function$;

CREATE OR REPLACE FUNCTION private.require_resource_listing_request_identity(p_expected_profile_id uuid, p_require_complete_profile boolean)
 RETURNS uuid
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  current_profile_id uuid := (select auth.uid());
  current_display_name text;
begin
  if current_profile_id is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication is required to manage a resource listing request.';
  end if;

  if p_expected_profile_id is null
    or p_expected_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'The authenticated user does not match the expected resource listing request profile.';
  end if;

  select profile.display_name into current_display_name
  from public.profiles as profile
  where profile.id = current_profile_id;

  if not found then
    raise exception using
      errcode = '55000',
      message = 'The current user does not have a profile anchor.';
  end if;

  if p_require_complete_profile and current_display_name is null then
    raise exception using
      errcode = '55000',
      message = 'A complete profile is required to request a resource listing.';
  end if;

  perform private.assert_profile_account_active(current_profile_id);
  return current_profile_id;
end;
$function$;

CREATE OR REPLACE FUNCTION private.assert_profile_new_interactions_available(p_profile_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  perform private.assert_profile_account_active(p_profile_id);
  if private.profile_has_active_interaction_restriction(p_profile_id) then
    raise sqlstate 'PT409' using message = 'This interaction is unavailable.';
  end if;
end;
$function$;

CREATE OR REPLACE FUNCTION public.update_own_profile(p_expected_profile_id uuid, p_display_name text, p_bio text, p_skill_ids uuid[], p_display_name_audience text, p_bio_audience text, p_skills_audience text)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
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

  perform public.assert_own_account_active();

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

  if p_display_name_audience is null
    or p_bio_audience is null
    or p_skills_audience is null
    or p_display_name_audience not in ('public', 'private')
    or p_bio_audience not in ('public', 'private')
    or p_skills_audience not in ('public', 'private') then
    raise exception using
      errcode = '22023',
      message = 'Profile audiences must be public or private.';
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

  insert into public.profile_field_visibility (profile_id, field_key, audience)
  values
    (current_profile_id, 'display_name', p_display_name_audience),
    (current_profile_id, 'bio', p_bio_audience),
    (current_profile_id, 'skills', p_skills_audience)
  on conflict (profile_id, field_key)
  do update set audience = excluded.audience;
end;
$function$;

CREATE OR REPLACE FUNCTION public.can_manage_cover_image_object(p_object_path text)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  current_profile_id uuid := (select auth.uid());
  parent_kind text;
  parent_id uuid;
begin
  if not private.current_account_is_active() then return false; end if;
  if current_profile_id is null
    or p_object_path is null
    or p_object_path !~
      '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/(projects|resources)/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.webp$'
    or split_part(p_object_path, '/', 1) <> current_profile_id::text then
    return false;
  end if;

  parent_kind := split_part(p_object_path, '/', 2);
  parent_id := split_part(p_object_path, '/', 3)::uuid;

  if parent_kind = 'projects' then
    return exists (
      select 1
      from public.projects as project
      where project.id = parent_id
        and project.creator_profile_id = current_profile_id
    );
  end if;

  return exists (
    select 1
    from public.resource_listings as listing
    where listing.id = parent_id
      and listing.owner_profile_id = current_profile_id
  );
end;
$function$;

CREATE OR REPLACE FUNCTION private.can_view_profile_photo(p_viewer_profile_id uuid, p_subject_profile_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select exists (
    select 1
    from public.profile_photos as photo
    where photo.profile_id = p_subject_profile_id
      and (
        (p_viewer_profile_id = p_subject_profile_id
          and not private.profile_has_active_account_suspension(p_viewer_profile_id))
        or photo.audience = 'public'
        or (
          photo.audience = 'interactions'
          and p_viewer_profile_id is not null
          and not private.profile_has_active_account_suspension(p_viewer_profile_id)
          and not private.has_active_user_block_between(
            p_viewer_profile_id,
            p_subject_profile_id
          )
          and (
            private.has_current_project_profile_photo_interaction(
              p_viewer_profile_id,
              p_subject_profile_id
            )
            or private.has_resource_profile_photo_interaction(
              p_viewer_profile_id,
              p_subject_profile_id
            )
          )
        )
      )
  )
$function$;

CREATE OR REPLACE FUNCTION public.revoke_moderation_consequence(p_expected_staff_profile_id uuid, p_consequence_id uuid, p_user_reason text, p_internal_note text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
  if episode.consequence_type = 'account_suspension' then
    raise exception using errcode = '42501', message = 'Use the admin-only account suspension revocation operation.';
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
$function$;

-- Defense in depth for direct private table reads/writes (catalogs stay public).
CREATE OR REPLACE FUNCTION private.require_complete_blocking_profile(p_expected_profile_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  current_profile_id uuid := (select auth.uid());
begin
  if current_profile_id is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication is required to manage user blocks.';
  end if;

  if p_expected_profile_id is null
    or p_expected_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'The authenticated user does not match the expected blocking profile.';
  end if;

  if not exists (
    select 1
    from public.profiles as profile
    where profile.id = current_profile_id
      and profile.display_name is not null
  ) then
    raise exception using
      errcode = '55000',
      message = 'A complete profile is required to manage user blocks.';
  end if;

  perform private.assert_profile_account_active(current_profile_id);
  return current_profile_id;
end;
$function$;

create policy account_active_required on public.profiles
  as restrictive for all to authenticated
  using ((select private.current_account_is_active()))
  with check ((select private.current_account_is_active()));
create policy account_active_required on public.profile_skills
  as restrictive for all to authenticated
  using ((select private.current_account_is_active()))
  with check ((select private.current_account_is_active()));
create policy account_active_required on public.profile_field_visibility
  as restrictive for all to authenticated
  using ((select private.current_account_is_active()))
  with check ((select private.current_account_is_active()));
create policy account_active_required on public.proposals
  as restrictive for all to authenticated
  using ((select private.current_account_is_active()))
  with check ((select private.current_account_is_active()));
create policy account_active_required on public.proposal_meeting_details
  as restrictive for all to authenticated
  using ((select private.current_account_is_active()))
  with check ((select private.current_account_is_active()));
create policy account_active_required on public.proposal_skills
  as restrictive for all to authenticated
  using ((select private.current_account_is_active()))
  with check ((select private.current_account_is_active()));
create policy account_active_required on public.recurring_activities
  as restrictive for all to authenticated
  using ((select private.current_account_is_active()))
  with check ((select private.current_account_is_active()));
create policy account_active_required on public.recurring_activity_meeting_details
  as restrictive for all to authenticated
  using ((select private.current_account_is_active()))
  with check ((select private.current_account_is_active()));
create policy account_active_required on public.recurring_activity_schedules
  as restrictive for all to authenticated
  using ((select private.current_account_is_active()))
  with check ((select private.current_account_is_active()));

-- Storage covers have explicit public and owner branches; only owner management
-- is gated above. Public canonical covers/photos remain anonymously readable.
-- Restrict owner profile-photo paths, but retain the deliberate public branch.
alter policy "Profile photo owners can read their objects" on storage.objects
  using (bucket_id = 'profile-photos' and owner_id = (select auth.uid())::text
    and storage.foldername(name) = array[(select auth.uid())::text]
    and storage.filename(name) ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.webp$'
    and (select private.current_account_is_active()));

-- Public contextual-photo readers must not retain their private owner shortcut.
CREATE OR REPLACE FUNCTION public.get_project_creator_profile_photo_for_viewer(p_project_id uuid)
 RETURNS TABLE(profile_id uuid, object_path text, updated_at timestamp with time zone)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select
    photo.profile_id,
    photo.object_path,
    photo.updated_at
  from public.projects as project
  join public.profile_photos as photo
    on photo.profile_id = project.creator_profile_id
  where project.id = p_project_id
    and (
      (project.creator_profile_id = (select auth.uid())
        and private.current_account_is_active())
      or (
        private.is_project_publicly_viewable(project.id)
        and (
          photo.audience = 'public'
          or not private.has_active_user_block_between(
            (select auth.uid()),
            photo.profile_id
          )
        )
      )
    )
$function$
;

CREATE OR REPLACE FUNCTION public.get_resource_listing_owner_profile_photo_for_viewer(p_listing_id uuid)
 RETURNS TABLE(profile_id uuid, object_path text, updated_at timestamp with time zone)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select
    photo.profile_id,
    photo.object_path,
    photo.updated_at
  from public.resource_listings as listing
  join public.profile_photos as photo
    on photo.profile_id = listing.owner_profile_id
  where listing.id = p_listing_id
    and (
      (listing.owner_profile_id = (select auth.uid())
        and private.current_account_is_active())
      or (
        listing.lifecycle_state = 'published'
      and not private.resource_listing_has_active_content_hide(listing.id)
        and (
          photo.audience = 'public'
          or not private.has_active_user_block_between(
            (select auth.uid()),
            photo.profile_id
          )
        )
      )
    )
$function$
;


alter policy "Profile photo owners can upload immutable versions" on storage.objects
  with check (bucket_id = 'profile-photos' and owner_id = (select auth.uid())::text
    and storage.foldername(name) = array[(select auth.uid())::text]
    and storage.filename(name) ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.webp$'
    and (select private.current_account_is_active()));
alter policy "Profile photo owners can delete their objects" on storage.objects
  using (bucket_id = 'profile-photos' and owner_id = (select auth.uid())::text
    and storage.foldername(name) = array[(select auth.uid())::text]
    and storage.filename(name) ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.webp$'
    and (select private.current_account_is_active()));
