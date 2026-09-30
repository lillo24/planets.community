-- Profile photos use a private, purpose-specific Supabase Storage bucket. The
-- application persists only provider-independent object paths and never writes
-- object metadata directly; uploads and deletes remain Storage API operations.
insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'profile-photos',
  'profile-photos',
  false,
  256000,
  array['image/webp']::text[]
)
on conflict (id) do update
set
  name = excluded.name,
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy "Profile photo owners can upload immutable versions"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'profile-photos'
  and owner_id = (select auth.uid())::text
  and storage.foldername(name) = array[(select auth.uid())::text]
  and storage.filename(name) ~
    '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.webp$'
);

create policy "Profile photo owners can read their objects"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'profile-photos'
  and owner_id = (select auth.uid())::text
  and storage.foldername(name) = array[(select auth.uid())::text]
  and storage.filename(name) ~
    '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.webp$'
);

create policy "Profile photo owners can delete their objects"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'profile-photos'
  and owner_id = (select auth.uid())::text
  and storage.foldername(name) = array[(select auth.uid())::text]
  and storage.filename(name) ~
    '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.webp$'
);

create table public.profile_photos (
  profile_id uuid primary key
    constraint profile_photos_profile_id_fkey
      references public.profiles (id) on delete cascade,
  object_path text not null unique
    constraint profile_photos_object_path_valid check (
      object_path ~
        '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.webp$'
      and split_part(object_path, '/', 1) = profile_id::text
    ),
  audience text not null default 'interactions'
    constraint profile_photos_audience_valid check (
      audience in ('public', 'interactions')
    ),
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp()
    constraint profile_photos_updated_at_valid check (
      updated_at >= created_at
    )
);

comment on table public.profile_photos is
  'One canonical current profile-photo object path and purpose-specific audience per profile.';
comment on column public.profile_photos.object_path is
  'Provider-independent profile-photos object path; never a URL or signed URL.';
comment on column public.profile_photos.audience is
  'Photo audience: public or interactions (Only people I interact with). Non-owner delivery begins in 08A3.';

create function private.is_profile_photo_object_path_for_profile(
  p_object_path text,
  p_profile_id uuid
)
returns boolean
language sql
immutable
strict
security invoker
set search_path = ''
as $$
  select
    p_object_path ~
      '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.webp$'
    and split_part(p_object_path, '/', 1) = p_profile_id::text
$$;

create function private.require_profile_photo_identity(
  p_expected_profile_id uuid
)
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
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

  return current_profile_id;
end;
$$;

create function private.set_profile_photo_updated_at()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.object_path is distinct from old.object_path
    or new.audience is distinct from old.audience then
    new.updated_at := statement_timestamp();
  else
    new.updated_at := old.updated_at;
  end if;

  return new;
end;
$$;

create trigger profile_photos_set_updated_at
before update on public.profile_photos
for each row
execute function private.set_profile_photo_updated_at();

alter table public.profile_photos enable row level security;

revoke all privileges on table public.profile_photos
  from public, anon, authenticated, service_role;

create function public.get_own_profile_photo(
  p_expected_profile_id uuid
)
returns table (
  profile_id uuid,
  object_path text,
  audience text,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_profile_photo_identity(
    p_expected_profile_id
  );
begin
  return query
  select
    photo.profile_id,
    photo.object_path,
    photo.audience,
    photo.created_at,
    photo.updated_at
  from public.profile_photos as photo
  where photo.profile_id = current_profile_id;
end;
$$;

comment on function public.get_own_profile_photo(uuid) is
  'Returns only the expected authenticated owner current profile-photo metadata; it generates no URL.';

create function public.set_own_profile_photo(
  p_expected_profile_id uuid,
  p_object_path text,
  p_audience text
)
returns table (
  current_object_path text,
  previous_object_path text,
  audience text,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_profile_photo_identity(
    p_expected_profile_id
  );
  storage_owner_id text;
  existing_object_path text;
  replaced_object_path text;
begin
  if p_audience is null
    or p_audience not in ('public', 'interactions') then
    raise exception using
      errcode = '22023',
      message = 'Profile photo audience must be public or interactions.';
  end if;

  if p_object_path is null
    or not private.is_profile_photo_object_path_for_profile(
      p_object_path,
      current_profile_id
    ) then
    raise exception using
      errcode = '22023',
      message = 'Profile photo object path is invalid for the expected profile.';
  end if;

  -- The profile row is a stable serialization anchor even before the first
  -- profile_photos row exists, so concurrent first commits are deterministic.
  perform 1
  from public.profiles as profile
  where profile.id = current_profile_id
  for update;

  if not found then
    raise exception using
      errcode = '55000',
      message = 'The current user does not have a profile anchor.';
  end if;

  select object.owner_id
  into storage_owner_id
  from storage.objects as object
  where object.bucket_id = 'profile-photos'
    and object.name = p_object_path;

  if not found then
    raise exception using
      errcode = '55000',
      message = 'The uploaded profile photo object is unavailable.';
  end if;

  if storage_owner_id is distinct from current_profile_id::text then
    raise exception using
      errcode = '42501',
      message = 'The uploaded profile photo object is not owned by the expected profile.';
  end if;

  select photo.object_path
  into existing_object_path
  from public.profile_photos as photo
  where photo.profile_id = current_profile_id;

  replaced_object_path := case
    when existing_object_path is distinct from p_object_path
      then existing_object_path
    else null
  end;

  insert into public.profile_photos (
    profile_id,
    object_path,
    audience
  )
  values (
    current_profile_id,
    p_object_path,
    p_audience
  )
  on conflict (profile_id) do update
  set
    object_path = excluded.object_path,
    audience = excluded.audience;

  return query
  select
    photo.object_path,
    replaced_object_path,
    photo.audience,
    photo.updated_at
  from public.profile_photos as photo
  where photo.profile_id = current_profile_id;
end;
$$;

comment on function public.set_own_profile_photo(uuid, text, text) is
  'Commits an already-uploaded owner-owned immutable profile-photo object path and returns any replaced path for Storage API cleanup.';

create function public.set_own_profile_photo_audience(
  p_expected_profile_id uuid,
  p_audience text
)
returns table (
  profile_id uuid,
  object_path text,
  audience text,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_profile_photo_identity(
    p_expected_profile_id
  );
begin
  if p_audience is null
    or p_audience not in ('public', 'interactions') then
    raise exception using
      errcode = '22023',
      message = 'Profile photo audience must be public or interactions.';
  end if;

  return query
  update public.profile_photos as photo
  set audience = p_audience
  where photo.profile_id = current_profile_id
  returning
    photo.profile_id,
    photo.object_path,
    photo.audience,
    photo.updated_at;

  if not found then
    raise exception using
      errcode = '55000',
      message = 'The current profile does not have a canonical photo.';
  end if;
end;
$$;

comment on function public.set_own_profile_photo_audience(uuid, text) is
  'Changes only the expected authenticated owner current photo audience.';

create function public.clear_own_profile_photo(
  p_expected_profile_id uuid
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_profile_photo_identity(
    p_expected_profile_id
  );
  cleared_object_path text;
begin
  delete from public.profile_photos as photo
  where photo.profile_id = current_profile_id
  returning photo.object_path into cleared_object_path;

  return cleared_object_path;
end;
$$;

comment on function public.clear_own_profile_photo(uuid) is
  'Clears the canonical profile-photo reference and returns the object path for separate Storage API deletion.';

revoke all privileges on function private.is_profile_photo_object_path_for_profile(text, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function private.require_profile_photo_identity(uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function private.set_profile_photo_updated_at()
  from public, anon, authenticated, service_role;
revoke all privileges on function public.get_own_profile_photo(uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.set_own_profile_photo(uuid, text, text)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.set_own_profile_photo_audience(uuid, text)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.clear_own_profile_photo(uuid)
  from public, anon, authenticated, service_role;

grant execute on function public.get_own_profile_photo(uuid)
  to authenticated;
grant execute on function public.set_own_profile_photo(uuid, text, text)
  to authenticated;
grant execute on function public.set_own_profile_photo_audience(uuid, text)
  to authenticated;
grant execute on function public.clear_own_profile_photo(uuid)
  to authenticated;
