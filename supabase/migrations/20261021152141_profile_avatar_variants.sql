-- IMG01: optional immutable small object, bound to the exact canonical full
-- version. Existing full-only metadata/RPCs and every audience rule stay intact.
create table private.profile_photo_thumbnails (
  profile_id uuid primary key references public.profile_photos(profile_id) on delete cascade,
  full_object_path text not null,
  thumbnail_object_path text not null unique,
  constraint profile_photo_thumbnail_paths_valid check (
    private.is_profile_photo_object_path_for_profile(full_object_path, profile_id)
    and private.is_profile_photo_object_path_for_profile(thumbnail_object_path, profile_id)
    and thumbnail_object_path <> full_object_path
  )
);
alter table private.profile_photo_thumbnails enable row level security;
revoke all on private.profile_photo_thumbnails from public, anon, authenticated, service_role;
comment on table private.profile_photo_thumbnails is
  'Optional 160px WebP (32768-byte ceiling), authorized only through its current canonical full photo. Legacy photos have no thumbnail; no backfill or originals.';

create function private.clear_replaced_profile_photo_thumbnail()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.object_path is distinct from old.object_path then
    delete from private.profile_photo_thumbnails where profile_id = new.profile_id;
  end if;
  return new;
end;
$$;
revoke all on function private.clear_replaced_profile_photo_thumbnail() from public, anon, authenticated, service_role;
create trigger profile_photo_thumbnail_replacement
after update of object_path on public.profile_photos for each row
execute function private.clear_replaced_profile_photo_thumbnail();

create function public.get_own_profile_photo_v2(p_expected_profile_id uuid)
returns table(profile_id uuid, object_path text, audience text, created_at timestamptz, updated_at timestamptz, thumbnail_object_path text)
language sql stable security definer set search_path = '' as $$
  select p.*, t.thumbnail_object_path from public.get_own_profile_photo(p_expected_profile_id) p
  left join private.profile_photo_thumbnails t on t.profile_id=p.profile_id and t.full_object_path=p.object_path
$$;

create function public.set_own_profile_photo_v2(p_expected_profile_id uuid, p_object_path text, p_audience text, p_thumbnail_object_path text)
returns table(current_object_path text, previous_object_path text, audience text, updated_at timestamptz, previous_thumbnail_object_path text)
language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := private.require_profile_photo_identity(p_expected_profile_id);
  previous_thumbnail text;
  committed record;
begin
  perform 1 from public.profiles where id=actor for update;
  if p_thumbnail_object_path is null
     or not private.is_profile_photo_object_path_for_profile(p_thumbnail_object_path, actor)
     or p_thumbnail_object_path = p_object_path then
    raise exception using errcode='22023', message='A distinct owner-bound thumbnail object is required.';
  end if;
  if not exists (
    select 1 from storage.objects o where o.bucket_id='profile-photos'
    and o.name=p_thumbnail_object_path and o.owner_id=actor::text
    and o.metadata->>'mimetype'='image/webp'
    and case when o.metadata->>'size' ~ '^[0-9]{1,9}$'
      then (o.metadata->>'size')::integer between 1 and 32768 else false end
  ) then
    raise exception using errcode='22023', message='The uploaded thumbnail must be owner-owned WebP of at most 32768 bytes.';
  end if;
  select t.thumbnail_object_path into previous_thumbnail from private.profile_photo_thumbnails t where t.profile_id=actor;
  select * into committed from public.set_own_profile_photo(actor, p_object_path, p_audience);
  insert into private.profile_photo_thumbnails(profile_id, full_object_path, thumbnail_object_path)
  values(actor, p_object_path, p_thumbnail_object_path)
  on conflict(profile_id) do update set full_object_path=excluded.full_object_path, thumbnail_object_path=excluded.thumbnail_object_path;
  return query select committed.current_object_path, committed.previous_object_path, committed.audience, committed.updated_at,
    case when previous_thumbnail is distinct from p_thumbnail_object_path then previous_thumbnail else null end;
end;
$$;

create function public.get_profile_photo_for_viewer_v2(p_profile_id uuid)
returns table(profile_id uuid, object_path text, updated_at timestamptz, thumbnail_object_path text)
language sql stable security definer set search_path = '' as $$
  select p.*, t.thumbnail_object_path from public.get_profile_photo_for_viewer(p_profile_id) p
  left join private.profile_photo_thumbnails t on t.profile_id=p.profile_id and t.full_object_path=p.object_path
$$;
create function public.list_profile_photos_for_viewer_v2(p_profile_ids uuid[])
returns table(profile_id uuid, object_path text, updated_at timestamptz, thumbnail_object_path text)
language sql stable security definer set search_path = '' as $$
  select p.*, t.thumbnail_object_path from public.list_profile_photos_for_viewer(p_profile_ids) p
  left join private.profile_photo_thumbnails t on t.profile_id=p.profile_id and t.full_object_path=p.object_path
  order by p.profile_id
$$;
create function public.get_project_creator_profile_photo_for_viewer_v2(p_project_id uuid)
returns table(profile_id uuid, object_path text, updated_at timestamptz, thumbnail_object_path text)
language sql stable security definer set search_path = '' as $$
  select p.*, t.thumbnail_object_path from public.get_project_creator_profile_photo_for_viewer(p_project_id) p
  left join private.profile_photo_thumbnails t on t.profile_id=p.profile_id and t.full_object_path=p.object_path
$$;
create function public.get_resource_listing_owner_profile_photo_for_viewer_v2(p_listing_id uuid)
returns table(profile_id uuid, object_path text, updated_at timestamptz, thumbnail_object_path text)
language sql stable security definer set search_path = '' as $$
  select p.*, t.thumbnail_object_path from public.get_resource_listing_owner_profile_photo_for_viewer(p_listing_id) p
  left join private.profile_photo_thumbnails t on t.profile_id=p.profile_id and t.full_object_path=p.object_path
$$;

-- Reuse the full object's exact authorization, including the separate public
-- Project/Resource context rules and block checks. No bucket listing or upsert.
create function public.can_read_profile_photo_thumbnail_object(p_object_path text)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from private.profile_photo_thumbnails t
    join public.profile_photos p on p.profile_id=t.profile_id and p.object_path=t.full_object_path
    where t.thumbnail_object_path=p_object_path and (
      private.can_view_profile_photo((select auth.uid()), p.profile_id)
      or public.can_read_public_project_creator_photo_object(p.object_path)
      or public.can_read_public_resource_listing_owner_photo_object(p.object_path)
    )
  )
$$;
create policy "Authorized viewers can read canonical profile thumbnails"
on storage.objects for select to anon, authenticated using (
  bucket_id='profile-photos'
  and storage.allow_any_operation(array['object.get_authenticated_info','object.get_authenticated'])
  and public.can_read_profile_photo_thumbnail_object(name)
);

revoke all on function public.get_own_profile_photo_v2(uuid) from public, anon, authenticated, service_role;
revoke all on function public.set_own_profile_photo_v2(uuid,text,text,text) from public, anon, authenticated, service_role;
grant execute on function public.get_own_profile_photo_v2(uuid), public.set_own_profile_photo_v2(uuid,text,text,text) to authenticated;
revoke all on function public.get_profile_photo_for_viewer_v2(uuid), public.list_profile_photos_for_viewer_v2(uuid[]), public.get_project_creator_profile_photo_for_viewer_v2(uuid), public.get_resource_listing_owner_profile_photo_for_viewer_v2(uuid), public.can_read_profile_photo_thumbnail_object(text) from public, anon, authenticated, service_role;
grant execute on function public.get_profile_photo_for_viewer_v2(uuid), public.list_profile_photos_for_viewer_v2(uuid[]), public.get_project_creator_profile_photo_for_viewer_v2(uuid), public.get_resource_listing_owner_profile_photo_for_viewer_v2(uuid), public.can_read_profile_photo_thumbnail_object(text) to anon, authenticated;
