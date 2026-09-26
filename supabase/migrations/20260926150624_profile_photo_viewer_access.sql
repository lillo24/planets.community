-- Profile-photo visibility is deliberately directional in 08A3: a Project
-- creator may see a pending requester or current participant. Historical
-- participation, co-participation, and the reverse direction do not qualify.
create function private.has_profile_photo_organizer_interaction(
  p_viewer_profile_id uuid,
  p_subject_profile_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    p_viewer_profile_id is not null
    and p_subject_profile_id is not null
    and p_viewer_profile_id <> p_subject_profile_id
    and exists (
      select 1
      from public.projects as project
      where project.creator_profile_id = p_viewer_profile_id
        and (
          exists (
            select 1
            from public.project_join_requests as request
            where request.project_id = project.id
              and request.requester_profile_id = p_subject_profile_id
              and request.status = 'pending'
          )
          or exists (
            select 1
            from public.project_memberships as membership
            where membership.project_id = project.id
              and membership.participant_profile_id = p_subject_profile_id
              and membership.left_at is null
              and membership.removed_at is null
          )
        )
    )
$$;

comment on function private.has_profile_photo_organizer_interaction(uuid, uuid) is
  'Returns whether the viewer creates any Project with a pending request or current membership for the subject; historical and peer relationships do not qualify.';

create function private.can_view_profile_photo(
  p_viewer_profile_id uuid,
  p_subject_profile_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profile_photos as photo
    where photo.profile_id = p_subject_profile_id
      and (
        p_viewer_profile_id = p_subject_profile_id
        or photo.audience = 'public'
        or (
          photo.audience = 'interactions'
          and p_viewer_profile_id is not null
          and private.has_profile_photo_organizer_interaction(
            p_viewer_profile_id,
            p_subject_profile_id
          )
        )
      )
  )
$$;

comment on function private.can_view_profile_photo(uuid, uuid) is
  'Authorizes only the current canonical photo for its owner, the public audience, or the initial organizer-to-requester/current-participant interaction set.';

create function public.get_profile_photo_for_viewer(
  p_profile_id uuid
)
returns table (
  profile_id uuid,
  object_path text,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    photo.profile_id,
    photo.object_path,
    photo.updated_at
  from public.profile_photos as photo
  where photo.profile_id = p_profile_id
    and private.can_view_profile_photo(
      (select auth.uid()),
      photo.profile_id
    )
$$;

comment on function public.get_profile_photo_for_viewer(uuid) is
  'Returns zero or one authorized canonical photo path for an exact profile ID without disclosing absence, audience, or relationship reason.';

create function public.list_profile_photos_for_viewer(
  p_profile_ids uuid[]
)
returns table (
  profile_id uuid,
  object_path text,
  updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if p_profile_ids is null
    or cardinality(p_profile_ids) < 1
    or cardinality(p_profile_ids) > 50 then
    raise exception using
      errcode = '22023',
      message = 'Profile photo viewer batches require between 1 and 50 target IDs.';
  end if;

  if array_position(p_profile_ids, null) is not null then
    raise exception using
      errcode = '22023',
      message = 'Profile photo viewer batches cannot contain null target IDs.';
  end if;

  return query
  select
    photo.profile_id,
    photo.object_path,
    photo.updated_at
  from (
    select distinct target.profile_id
    from unnest(p_profile_ids) as target(profile_id)
  ) as requested
  join public.profile_photos as photo
    on photo.profile_id = requested.profile_id
  where private.can_view_profile_photo(
    (select auth.uid()),
    photo.profile_id
  )
  order by photo.profile_id;
end;
$$;

comment on function public.list_profile_photos_for_viewer(uuid[]) is
  'Returns authorized canonical photo paths for 1..50 target IDs, deduplicated and ordered by profile_id; omitted IDs reveal no absence or denial reason.';

-- The public viewer RPC is also the single authorization source used by
-- Storage. Comparing its canonical returned path prevents a guessed or stale
-- version from becoming readable. Operation filtering permits exact object
-- downloads while deliberately withholding bucket-listing access.
create policy "Authorized viewers can read canonical profile photos"
on storage.objects
for select
to anon, authenticated
using (
  bucket_id = 'profile-photos'
  and storage.allow_any_operation(
    array['object.get_authenticated_info', 'object.get_authenticated']
  )
  and name ~
    '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.webp$'
  and exists (
    select 1
    from public.get_profile_photo_for_viewer(
      case
        when name ~
          '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/'
          then split_part(name, '/', 1)::uuid
        else null
      end
    ) as visible
    where visible.object_path = storage.objects.name
  )
);

comment on column public.profile_photos.audience is
  'Photo audience: public, or interactions meaning a Project organizer with a pending request/current membership from the subject in 08A3; this is the first, not exhaustive, interaction set.';

revoke all privileges on function private.has_profile_photo_organizer_interaction(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function private.can_view_profile_photo(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.get_profile_photo_for_viewer(uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.list_profile_photos_for_viewer(uuid[])
  from public, anon, authenticated, service_role;

grant execute on function public.get_profile_photo_for_viewer(uuid)
  to anon, authenticated;
grant execute on function public.list_profile_photos_for_viewer(uuid[])
  to anon, authenticated;
