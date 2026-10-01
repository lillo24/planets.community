-- Cover media uses one private, purpose-specific bucket for Project and
-- Scambio-Dona listing covers. The database stores provider-independent object
-- paths only; Storage API calls remain responsible for object bytes and cleanup.
insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'cover-images',
  'cover-images',
  false,
  524288,
  array['image/webp']::text[]
)
on conflict (id) do update
set
  name = excluded.name,
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create table public.project_covers (
  project_id uuid primary key
    constraint project_covers_project_id_fkey
      references public.projects (id) on delete cascade,
  object_path text not null unique
    constraint project_covers_object_path_valid check (
      object_path ~
        '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/projects/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.webp$'
      and split_part(object_path, '/', 3) = project_id::text
    ),
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp()
    constraint project_covers_updated_at_valid check (
      updated_at >= created_at
    )
);

comment on table public.project_covers is
  'One optional canonical current cover-image path per shared Project identity.';
comment on column public.project_covers.object_path is
  'Provider-independent cover-images object path; never a URL or signed URL.';

create table public.resource_listing_covers (
  listing_id uuid primary key
    constraint resource_listing_covers_listing_id_fkey
      references public.resource_listings (id) on delete cascade,
  object_path text not null unique
    constraint resource_listing_covers_object_path_valid check (
      object_path ~
        '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/resources/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.webp$'
      and split_part(object_path, '/', 3) = listing_id::text
    ),
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp()
    constraint resource_listing_covers_updated_at_valid check (
      updated_at >= created_at
    )
);

comment on table public.resource_listing_covers is
  'One optional canonical current cover-image path per Scambio-Dona Resource listing.';
comment on column public.resource_listing_covers.object_path is
  'Provider-independent cover-images object path; never a URL or signed URL.';

alter table public.project_covers enable row level security;
alter table public.resource_listing_covers enable row level security;

revoke all privileges on table public.project_covers
  from public, anon, authenticated, service_role;
revoke all privileges on table public.resource_listing_covers
  from public, anon, authenticated, service_role;

create function private.set_cover_updated_at()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.object_path is distinct from old.object_path then
    new.updated_at := statement_timestamp();
  else
    new.updated_at := old.updated_at;
  end if;

  return new;
end;
$$;

create trigger project_covers_set_updated_at
before update on public.project_covers
for each row execute function private.set_cover_updated_at();

create trigger resource_listing_covers_set_updated_at
before update on public.resource_listing_covers
for each row execute function private.set_cover_updated_at();

create function private.require_cover_identity(p_expected_profile_id uuid)
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
      message = 'Authentication is required to manage cover media.';
  end if;

  if p_expected_profile_id is null
    or p_expected_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'The authenticated user does not match the expected cover owner.';
  end if;

  return current_profile_id;
end;
$$;

create function private.is_cover_object_path_for_parent(
  p_object_path text,
  p_owner_profile_id uuid,
  p_parent_kind text,
  p_parent_id uuid
)
returns boolean
language sql
immutable
strict
security invoker
set search_path = ''
as $$
  select
    p_parent_kind in ('projects', 'resources')
    and p_object_path ~
      '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/(projects|resources)/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.webp$'
    and split_part(p_object_path, '/', 1) = p_owner_profile_id::text
    and split_part(p_object_path, '/', 2) = p_parent_kind
    and split_part(p_object_path, '/', 3) = p_parent_id::text
$$;

create function private.is_project_cover_editable(
  p_project_id uuid,
  p_creator_profile_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.projects as project
    where project.id = p_project_id
      and project.creator_profile_id = p_creator_profile_id
      and (
        (
          project.project_kind = 'one_time'
          and exists (
            select 1
            from public.proposals as proposal
            where proposal.id = project.id
              and proposal.creator_profile_id = p_creator_profile_id
              and (
                proposal.lifecycle_state = 'draft'
                or (
                  proposal.lifecycle_state = 'published'
                  and proposal.starts_at > statement_timestamp()
                )
              )
          )
        )
        or (
          project.project_kind = 'recurring'
          and exists (
            select 1
            from public.recurring_activities as activity
            where activity.id = project.id
              and activity.creator_profile_id = p_creator_profile_id
              and activity.lifecycle_state in ('draft', 'published', 'paused')
          )
        )
      )
  )
$$;

create function private.is_resource_cover_editable(
  p_listing_id uuid,
  p_owner_profile_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.resource_listings as listing
    where listing.id = p_listing_id
      and listing.owner_profile_id = p_owner_profile_id
      and listing.lifecycle_state in ('draft', 'published')
  )
$$;

create function public.can_manage_cover_image_object(p_object_path text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := (select auth.uid());
  parent_kind text;
  parent_id uuid;
begin
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
$$;

create function public.can_upload_cover_image_object(p_object_path text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := (select auth.uid());
  parent_kind text;
  parent_id uuid;
begin
  if current_profile_id is null
    or not public.can_manage_cover_image_object(p_object_path) then
    return false;
  end if;

  parent_kind := split_part(p_object_path, '/', 2);
  parent_id := split_part(p_object_path, '/', 3)::uuid;

  if parent_kind = 'projects' then
    return private.is_project_cover_editable(
      parent_id,
      current_profile_id
    );
  end if;

  return private.is_resource_cover_editable(
    parent_id,
    current_profile_id
  );
end;
$$;

create function public.can_read_public_cover_image_object(p_object_path text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.project_covers as cover
    where cover.object_path = p_object_path
      and private.is_project_publicly_viewable(cover.project_id)
  ) or exists (
    select 1
    from public.resource_listing_covers as cover
    join public.resource_listings as listing
      on listing.id = cover.listing_id
    where cover.object_path = p_object_path
      and listing.lifecycle_state = 'published'
  )
$$;

comment on function public.can_manage_cover_image_object(text) is
  'Storage-policy helper authorizing only an authenticated owner path bound to an existing owned Project or Resource listing.';
comment on function public.can_upload_cover_image_object(text) is
  'Storage-policy helper authorizing immutable upload only while the owned parent remains editable.';
comment on function public.can_read_public_cover_image_object(text) is
  'Storage-policy helper authorizing exact download of a current canonical cover whose parent passes its public-detail lifecycle boundary.';

create policy "Cover owners can upload immutable versions"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'cover-images'
  and owner_id = (select auth.uid())::text
  and public.can_upload_cover_image_object(name)
);

create policy "Cover owners can read owned versions"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'cover-images'
  and owner_id = (select auth.uid())::text
  and storage.allow_any_operation(
    array['object.get_authenticated_info', 'object.get_authenticated']
  )
  and public.can_manage_cover_image_object(name)
);

create policy "Public readers can read canonical public covers"
on storage.objects
for select
to anon, authenticated
using (
  bucket_id = 'cover-images'
  and storage.allow_any_operation(
    array['object.get_authenticated_info', 'object.get_authenticated']
  )
  and public.can_read_public_cover_image_object(name)
);

create policy "Cover owners can delete owned versions"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'cover-images'
  and owner_id = (select auth.uid())::text
  and public.can_manage_cover_image_object(name)
);

create function private.lock_owned_editable_project_cover_parent(
  p_creator_profile_id uuid,
  p_project_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  parent_project_kind text;
  source_creator_profile_id uuid;
  source_is_editable boolean;
begin
  select project.project_kind
  into parent_project_kind
  from public.projects as project
  where project.id = p_project_id;

  if parent_project_kind = 'one_time' then
    select
      proposal.creator_profile_id,
      proposal.lifecycle_state = 'draft'
        or (
          proposal.lifecycle_state = 'published'
          and proposal.starts_at > statement_timestamp()
        )
    into source_creator_profile_id, source_is_editable
    from public.proposals as proposal
    where proposal.id = p_project_id
    for update;
  elsif parent_project_kind = 'recurring' then
    select
      activity.creator_profile_id,
      activity.lifecycle_state in ('draft', 'published', 'paused')
    into source_creator_profile_id, source_is_editable
    from public.recurring_activities as activity
    where activity.id = p_project_id
    for update;
  end if;

  if parent_project_kind is null
    or source_creator_profile_id is null
    or source_creator_profile_id <> p_creator_profile_id then
    raise exception using
      errcode = '42501',
      message = 'The current user does not own this Project.';
  end if;

  if not source_is_editable then
    raise exception using
      errcode = '55000',
      message = 'This Project cover can no longer be edited.';
  end if;

  perform 1
  from public.projects as project
  where project.id = p_project_id
    and project.project_kind = parent_project_kind
    and project.creator_profile_id = p_creator_profile_id
  for update;

  if not found then
    raise exception using
      errcode = '55000',
      message = 'The Project registry is inconsistent with its concrete activity.';
  end if;
end;
$$;

create function private.lock_owned_editable_resource_cover_parent(
  p_owner_profile_id uuid,
  p_listing_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  listing_owner_profile_id uuid;
  listing_lifecycle_state text;
begin
  select listing.owner_profile_id, listing.lifecycle_state
  into listing_owner_profile_id, listing_lifecycle_state
  from public.resource_listings as listing
  where listing.id = p_listing_id
  for update;

  if listing_owner_profile_id is null
    or listing_owner_profile_id <> p_owner_profile_id then
    raise exception using
      errcode = '42501',
      message = 'The current user does not own this Resource listing.';
  end if;

  if listing_lifecycle_state not in ('draft', 'published') then
    raise exception using
      errcode = '55000',
      message = 'This Resource listing cover can no longer be edited.';
  end if;
end;
$$;

create function public.get_own_project_cover(
  p_expected_creator_profile_id uuid,
  p_project_id uuid
)
returns table (
  project_id uuid,
  object_path text,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_cover_identity(
    p_expected_creator_profile_id
  );
begin
  return query
  select
    cover.project_id,
    cover.object_path,
    cover.created_at,
    cover.updated_at
  from public.project_covers as cover
  join public.projects as project on project.id = cover.project_id
  where cover.project_id = p_project_id
    and project.creator_profile_id = current_profile_id;
end;
$$;

create function public.set_own_project_cover(
  p_expected_creator_profile_id uuid,
  p_project_id uuid,
  p_object_path text
)
returns table (
  current_object_path text,
  previous_object_path text,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_cover_identity(
    p_expected_creator_profile_id
  );
  storage_owner_id text;
  storage_mime_type text;
  existing_object_path text;
  replaced_object_path text;
begin
  if p_object_path is null
    or not private.is_cover_object_path_for_parent(
      p_object_path,
      current_profile_id,
      'projects',
      p_project_id
    ) then
    raise exception using
      errcode = '22023',
      message = 'The cover object path is invalid for the expected Project.';
  end if;

  perform private.lock_owned_editable_project_cover_parent(
    current_profile_id,
    p_project_id
  );

  select object.owner_id, object.metadata ->> 'mimetype'
  into storage_owner_id, storage_mime_type
  from storage.objects as object
  where object.bucket_id = 'cover-images'
    and object.name = p_object_path;

  if not found then
    raise exception using
      errcode = '55000',
      message = 'The uploaded cover object is unavailable.';
  end if;

  if storage_owner_id is distinct from current_profile_id::text then
    raise exception using
      errcode = '42501',
      message = 'The uploaded cover object is not owned by the expected profile.';
  end if;

  if storage_mime_type is distinct from 'image/webp' then
    raise exception using
      errcode = '22023',
      message = 'The uploaded cover object is not a normalized WebP image.';
  end if;

  select cover.object_path
  into existing_object_path
  from public.project_covers as cover
  where cover.project_id = p_project_id;

  replaced_object_path := case
    when existing_object_path is distinct from p_object_path
      then existing_object_path
    else null
  end;

  insert into public.project_covers (project_id, object_path)
  values (p_project_id, p_object_path)
  on conflict (project_id) do update
  set object_path = excluded.object_path;

  return query
  select cover.object_path, replaced_object_path, cover.updated_at
  from public.project_covers as cover
  where cover.project_id = p_project_id;
end;
$$;

create function public.clear_own_project_cover(
  p_expected_creator_profile_id uuid,
  p_project_id uuid
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_cover_identity(
    p_expected_creator_profile_id
  );
  cleared_object_path text;
begin
  perform private.lock_owned_editable_project_cover_parent(
    current_profile_id,
    p_project_id
  );

  delete from public.project_covers as cover
  where cover.project_id = p_project_id
  returning cover.object_path into cleared_object_path;

  return cleared_object_path;
end;
$$;

create function public.get_own_resource_listing_cover(
  p_expected_owner_profile_id uuid,
  p_listing_id uuid
)
returns table (
  listing_id uuid,
  object_path text,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_cover_identity(
    p_expected_owner_profile_id
  );
begin
  return query
  select
    cover.listing_id,
    cover.object_path,
    cover.created_at,
    cover.updated_at
  from public.resource_listing_covers as cover
  join public.resource_listings as listing on listing.id = cover.listing_id
  where cover.listing_id = p_listing_id
    and listing.owner_profile_id = current_profile_id;
end;
$$;

create function public.set_own_resource_listing_cover(
  p_expected_owner_profile_id uuid,
  p_listing_id uuid,
  p_object_path text
)
returns table (
  current_object_path text,
  previous_object_path text,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_cover_identity(
    p_expected_owner_profile_id
  );
  storage_owner_id text;
  storage_mime_type text;
  existing_object_path text;
  replaced_object_path text;
begin
  if p_object_path is null
    or not private.is_cover_object_path_for_parent(
      p_object_path,
      current_profile_id,
      'resources',
      p_listing_id
    ) then
    raise exception using
      errcode = '22023',
      message = 'The cover object path is invalid for the expected Resource listing.';
  end if;

  perform private.lock_owned_editable_resource_cover_parent(
    current_profile_id,
    p_listing_id
  );

  select object.owner_id, object.metadata ->> 'mimetype'
  into storage_owner_id, storage_mime_type
  from storage.objects as object
  where object.bucket_id = 'cover-images'
    and object.name = p_object_path;

  if not found then
    raise exception using
      errcode = '55000',
      message = 'The uploaded cover object is unavailable.';
  end if;

  if storage_owner_id is distinct from current_profile_id::text then
    raise exception using
      errcode = '42501',
      message = 'The uploaded cover object is not owned by the expected profile.';
  end if;

  if storage_mime_type is distinct from 'image/webp' then
    raise exception using
      errcode = '22023',
      message = 'The uploaded cover object is not a normalized WebP image.';
  end if;

  select cover.object_path
  into existing_object_path
  from public.resource_listing_covers as cover
  where cover.listing_id = p_listing_id;

  replaced_object_path := case
    when existing_object_path is distinct from p_object_path
      then existing_object_path
    else null
  end;

  insert into public.resource_listing_covers (listing_id, object_path)
  values (p_listing_id, p_object_path)
  on conflict (listing_id) do update
  set object_path = excluded.object_path;

  return query
  select cover.object_path, replaced_object_path, cover.updated_at
  from public.resource_listing_covers as cover
  where cover.listing_id = p_listing_id;
end;
$$;

create function public.clear_own_resource_listing_cover(
  p_expected_owner_profile_id uuid,
  p_listing_id uuid
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_cover_identity(
    p_expected_owner_profile_id
  );
  cleared_object_path text;
begin
  perform private.lock_owned_editable_resource_cover_parent(
    current_profile_id,
    p_listing_id
  );

  delete from public.resource_listing_covers as cover
  where cover.listing_id = p_listing_id
  returning cover.object_path into cleared_object_path;

  return cleared_object_path;
end;
$$;

comment on function public.get_own_project_cover(uuid, uuid) is
  'Returns zero or one canonical Project cover path for the expected creator; no URL is generated.';
comment on function public.set_own_project_cover(uuid, uuid, text) is
  'Commits an uploaded immutable Project cover and returns any replaced path for separate Storage cleanup.';
comment on function public.clear_own_project_cover(uuid, uuid) is
  'Clears editable Project canonical cover metadata and returns its path for separate Storage cleanup.';
comment on function public.get_own_resource_listing_cover(uuid, uuid) is
  'Returns zero or one canonical Resource-listing cover path for the expected owner; no URL is generated.';
comment on function public.set_own_resource_listing_cover(uuid, uuid, text) is
  'Commits an uploaded immutable Resource-listing cover and returns any replaced path for separate Storage cleanup.';
comment on function public.clear_own_resource_listing_cover(uuid, uuid) is
  'Clears editable Resource-listing canonical cover metadata and returns its path for separate Storage cleanup.';

-- RETURNS TABLE row shapes cannot be changed in place. Recreate the canonical
-- Proposal reads with one nullable provider-independent cover path while
-- preserving every existing argument, filter, field, order, and visibility rule.
drop function public.get_own_proposal(uuid, uuid);
drop function public.list_own_proposals(uuid);
drop function public.get_public_proposal(uuid);
drop function public.list_public_proposals(integer, timestamptz, uuid, text, uuid[], text);
drop function public.list_own_pending_requested_proposals(uuid, text, uuid[], text);

create function public.list_public_proposals(
  p_limit integer default 20,
  p_cursor_starts_at timestamptz default null,
  p_cursor_id uuid default null,
  p_locality text default null,
  p_skill_ids uuid[] default null,
  p_query text default null
)
returns table (
  proposal_id uuid,
  cover_object_path text,
  title text,
  summary text,
  starts_at timestamptz,
  ends_at timestamptz,
  event_timezone text,
  country_code text,
  locality text,
  administrative_area text,
  public_location_label text,
  derived_status text,
  skills jsonb
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  normalized_locality text := nullif(btrim(p_locality), '');
  normalized_query text := nullif(lower(btrim(p_query)), '');
begin
  if p_limit is null or p_limit not between 1 and 50 then
    raise exception using
      errcode = '22023',
      message = 'Proposal page size must be between 1 and 50.';
  end if;

  if (p_cursor_starts_at is null) <> (p_cursor_id is null) then
    raise exception using
      errcode = '22023',
      message = 'Proposal cursor values must be supplied together.';
  end if;

  if p_skill_ids is not null and array_position(p_skill_ids, null) is not null then
    raise exception using
      errcode = '22023',
      message = 'Proposal skill filters cannot contain null identifiers.';
  end if;

  if normalized_query is not null and char_length(normalized_query) > 120 then
    raise exception using
      errcode = '22023',
      message = 'Proposal search query must contain at most 120 characters.';
  end if;

  return query
  select
    proposal.id,
    cover.object_path,
    proposal.title,
    proposal.summary,
    proposal.starts_at,
    proposal.ends_at,
    proposal.event_timezone,
    proposal.country_code,
    proposal.locality,
    proposal.administrative_area,
    proposal.public_location_label,
    private.derive_proposal_status(
      proposal.starts_at,
      proposal.ends_at,
      statement_timestamp()
    ),
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', skill.id,
            'slug', skill.slug,
            'label', skill.label,
            'category_id', category.id,
            'category_slug', category.slug,
            'category_label', category.label,
            'importance', proposal_skill.importance
          )
          order by
            case proposal_skill.importance when 'required' then 0 else 1 end,
            category.sort_order,
            skill.sort_order
        )
        from public.proposal_skills as proposal_skill
        join public.skills as skill on skill.id = proposal_skill.skill_id
        join public.skill_categories as category on category.id = skill.category_id
        where proposal_skill.proposal_id = proposal.id
      ),
      '[]'::jsonb
    )
  from public.proposals as proposal
  left join public.project_covers as cover on cover.project_id = proposal.id
  where proposal.lifecycle_state = 'published'
    and proposal.ends_at > statement_timestamp() - interval '24 hours'
    and (
      normalized_query is null
      or position(normalized_query in lower(proposal.title)) > 0
      or position(normalized_query in lower(proposal.summary)) > 0
      or position(normalized_query in lower(proposal.description)) > 0
    )
    and (
      normalized_locality is null
      or lower(proposal.locality) = lower(normalized_locality)
    )
    and (
      coalesce(cardinality(p_skill_ids), 0) = 0
      or exists (
        select 1
        from public.proposal_skills as filtered_skill
        where filtered_skill.proposal_id = proposal.id
          and filtered_skill.skill_id = any(p_skill_ids)
      )
    )
    and (
      p_cursor_starts_at is null
      or (proposal.starts_at, proposal.id) > (p_cursor_starts_at, p_cursor_id)
    )
  order by proposal.starts_at, proposal.id
  limit p_limit;
end;
$$;

create function public.get_public_proposal(p_proposal_id uuid)
returns table (
  proposal_id uuid,
  cover_object_path text,
  creator_profile_id uuid,
  creator_display_name text,
  title text,
  summary text,
  description text,
  starts_at timestamptz,
  ends_at timestamptz,
  event_timezone text,
  country_code text,
  locality text,
  administrative_area text,
  public_location_label text,
  derived_status text,
  skills jsonb,
  exact_meeting_text text,
  exact_location_restricted boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    proposal.id,
    cover.object_path,
    proposal.creator_profile_id,
    case
      when display_visibility.audience = 'public' then creator.display_name
      else null
    end,
    proposal.title,
    proposal.summary,
    proposal.description,
    proposal.starts_at,
    proposal.ends_at,
    proposal.event_timezone,
    proposal.country_code,
    proposal.locality,
    proposal.administrative_area,
    proposal.public_location_label,
    private.derive_proposal_status(
      proposal.starts_at,
      proposal.ends_at,
      statement_timestamp()
    ),
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', skill.id,
            'slug', skill.slug,
            'label', skill.label,
            'category_id', category.id,
            'category_slug', category.slug,
            'category_label', category.label,
            'importance', proposal_skill.importance
          )
          order by
            case proposal_skill.importance when 'required' then 0 else 1 end,
            category.sort_order,
            skill.sort_order
        )
        from public.proposal_skills as proposal_skill
        join public.skills as skill on skill.id = proposal_skill.skill_id
        join public.skill_categories as category on category.id = skill.category_id
        where proposal_skill.proposal_id = proposal.id
      ),
      '[]'::jsonb
    ),
    case
      when meeting.exact_location_visibility = 'public'
        then meeting.exact_meeting_text
      else null
    end,
    meeting.exact_location_visibility = 'participants'
  from public.proposals as proposal
  join public.profiles as creator on creator.id = proposal.creator_profile_id
  left join public.profile_field_visibility as display_visibility
    on display_visibility.profile_id = creator.id
    and display_visibility.field_key = 'display_name'
  join public.proposal_meeting_details as meeting
    on meeting.proposal_id = proposal.id
  left join public.project_covers as cover on cover.project_id = proposal.id
  where proposal.id = p_proposal_id
    and proposal.lifecycle_state = 'published'
$$;

create function public.list_own_proposals(p_expected_creator_profile_id uuid)
returns table (
  proposal_id uuid,
  cover_object_path text,
  lifecycle_state text,
  title text,
  summary text,
  description text,
  starts_at timestamptz,
  ends_at timestamptz,
  event_timezone text,
  country_code text,
  locality text,
  administrative_area text,
  public_location_label text,
  derived_status text,
  skills jsonb,
  exact_meeting_text text,
  exact_location_visibility text,
  created_at timestamptz,
  updated_at timestamptz,
  published_at timestamptz,
  cancelled_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_expected_identity(
    p_expected_creator_profile_id
  );
begin
  return query
  select
    proposal.id,
    cover.object_path,
    proposal.lifecycle_state,
    proposal.title,
    proposal.summary,
    proposal.description,
    proposal.starts_at,
    proposal.ends_at,
    proposal.event_timezone,
    proposal.country_code,
    proposal.locality,
    proposal.administrative_area,
    proposal.public_location_label,
    case
      when proposal.lifecycle_state = 'published'
        then private.derive_proposal_status(
          proposal.starts_at,
          proposal.ends_at,
          statement_timestamp()
        )
      else null
    end,
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', skill.id,
            'slug', skill.slug,
            'label', skill.label,
            'category_id', category.id,
            'category_slug', category.slug,
            'category_label', category.label,
            'importance', proposal_skill.importance
          )
          order by
            case proposal_skill.importance when 'required' then 0 else 1 end,
            category.sort_order,
            skill.sort_order
        )
        from public.proposal_skills as proposal_skill
        join public.skills as skill on skill.id = proposal_skill.skill_id
        join public.skill_categories as category on category.id = skill.category_id
        where proposal_skill.proposal_id = proposal.id
      ),
      '[]'::jsonb
    ),
    meeting.exact_meeting_text,
    meeting.exact_location_visibility,
    proposal.created_at,
    proposal.updated_at,
    proposal.published_at,
    proposal.cancelled_at
  from public.proposals as proposal
  join public.proposal_meeting_details as meeting
    on meeting.proposal_id = proposal.id
  left join public.project_covers as cover on cover.project_id = proposal.id
  where proposal.creator_profile_id = current_profile_id
  order by proposal.created_at desc, proposal.id;
end;
$$;

create function public.get_own_proposal(
  p_expected_creator_profile_id uuid,
  p_proposal_id uuid
)
returns table (
  proposal_id uuid,
  cover_object_path text,
  lifecycle_state text,
  title text,
  summary text,
  description text,
  starts_at timestamptz,
  ends_at timestamptz,
  event_timezone text,
  country_code text,
  locality text,
  administrative_area text,
  public_location_label text,
  derived_status text,
  skills jsonb,
  exact_meeting_text text,
  exact_location_visibility text,
  created_at timestamptz,
  updated_at timestamptz,
  published_at timestamptz,
  cancelled_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select *
  from public.list_own_proposals(p_expected_creator_profile_id)
  where proposal_id = p_proposal_id
$$;

create function public.list_own_pending_requested_proposals(
  p_expected_requester_profile_id uuid,
  p_locality text default null,
  p_skill_ids uuid[] default null,
  p_query text default null
)
returns table (
  proposal_id uuid,
  cover_object_path text,
  request_id uuid,
  request_created_at timestamptz,
  title text,
  summary text,
  starts_at timestamptz,
  ends_at timestamptz,
  event_timezone text,
  country_code text,
  locality text,
  administrative_area text,
  public_location_label text,
  derived_status text,
  skills jsonb
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_complete_participation_profile(
    p_expected_requester_profile_id
  );
  normalized_locality text := nullif(btrim(p_locality), '');
  normalized_query text := nullif(lower(btrim(p_query)), '');
begin
  if p_skill_ids is not null and array_position(p_skill_ids, null) is not null then
    raise exception using
      errcode = '22023',
      message = 'Requested Proposal skill filters cannot contain null identifiers.';
  end if;

  if normalized_query is not null and char_length(normalized_query) > 120 then
    raise exception using
      errcode = '22023',
      message = 'Proposal search query must contain at most 120 characters.';
  end if;

  return query
  select
    proposal.id,
    cover.object_path,
    request.id,
    request.created_at,
    proposal.title,
    proposal.summary,
    proposal.starts_at,
    proposal.ends_at,
    proposal.event_timezone,
    proposal.country_code,
    proposal.locality,
    proposal.administrative_area,
    proposal.public_location_label,
    private.derive_proposal_status(
      proposal.starts_at,
      proposal.ends_at,
      statement_timestamp()
    ),
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', skill.id,
            'slug', skill.slug,
            'label', skill.label,
            'category_id', category.id,
            'category_slug', category.slug,
            'category_label', category.label,
            'importance', proposal_skill.importance
          )
          order by
            case proposal_skill.importance when 'required' then 0 else 1 end,
            category.sort_order,
            skill.sort_order
        )
        from public.proposal_skills as proposal_skill
        join public.skills as skill on skill.id = proposal_skill.skill_id
        join public.skill_categories as category on category.id = skill.category_id
        where proposal_skill.proposal_id = proposal.id
      ),
      '[]'::jsonb
    )
  from public.project_join_requests as request
  join public.proposals as proposal on proposal.id = request.project_id
  left join public.project_covers as cover on cover.project_id = proposal.id
  where request.requester_profile_id = current_profile_id
    and request.status = 'pending'
    and proposal.lifecycle_state = 'published'
    and proposal.ends_at > statement_timestamp() - interval '24 hours'
    and (
      normalized_query is null
      or position(normalized_query in lower(proposal.title)) > 0
      or position(normalized_query in lower(proposal.summary)) > 0
      or position(normalized_query in lower(proposal.description)) > 0
    )
    and (
      normalized_locality is null
      or lower(proposal.locality) = lower(normalized_locality)
    )
    and (
      coalesce(cardinality(p_skill_ids), 0) = 0
      or exists (
        select 1
        from public.proposal_skills as filtered_skill
        where filtered_skill.proposal_id = proposal.id
          and filtered_skill.skill_id = any(p_skill_ids)
      )
    )
  order by request.created_at desc, proposal.id desc
  limit 200;
end;
$$;

comment on function public.list_public_proposals(integer, timestamptz, uuid, text, uuid[], text) is
  'Returns a cursor-paginated sanitized public discovery page with rough location, optional literal query, and the nullable canonical cover path.';
comment on function public.get_public_proposal(uuid) is
  'Returns exact-ID published detail, nullable canonical cover path, and no participant-restricted meeting information.';
comment on function public.list_own_proposals(uuid) is
  'Returns the expected creator complete proposal history with nullable canonical cover paths.';
comment on function public.get_own_proposal(uuid, uuid) is
  'Returns one expected creator proposal with its nullable canonical cover path.';
comment on function public.list_own_pending_requested_proposals(uuid, text, uuid[], text) is
  'Returns at most 200 public Proposal cards with pending-request context, optional literal query, and nullable canonical cover paths.';

drop function public.get_own_recurring_activity(uuid, uuid);
drop function public.list_own_recurring_activities(uuid);
drop function public.get_public_recurring_activity(uuid, integer, timestamptz);
drop function public.list_public_recurring_activities(timestamptz, integer, timestamptz, uuid, text);
drop function public.list_own_pending_requested_recurring_activities(uuid, timestamptz, text);

create function public.list_public_recurring_activities(
  p_reference_time timestamptz,
  p_limit integer default 20,
  p_cursor_next_starts_at timestamptz default null,
  p_cursor_id uuid default null,
  p_locality text default null
)
returns table (
  recurring_activity_id uuid,
  cover_object_path text,
  title text,
  summary text,
  topic text,
  country_code text,
  locality text,
  administrative_area text,
  public_location_label text,
  next_starts_at timestamptz,
  next_ends_at timestamptz,
  event_timezone text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  normalized_locality text := nullif(btrim(p_locality), '');
begin
  if p_limit is null or p_limit not between 1 and 50 then
    raise exception using
      errcode = '22023',
      message = 'Recurring activity page size must be between 1 and 50.';
  end if;

  if (p_cursor_next_starts_at is null) <> (p_cursor_id is null) then
    raise exception using
      errcode = '22023',
      message = 'Recurring activity cursor values must be supplied together.';
  end if;

  if p_reference_time is null then
    raise exception using
      errcode = '22023',
      message = 'Recurring activity discovery requires a reference time.';
  end if;

  return query
  select
    activity.id,
    cover.object_path,
    activity.title,
    activity.summary,
    activity.topic,
    activity.country_code,
    activity.locality,
    activity.administrative_area,
    activity.public_location_label,
    next_occurrence.starts_at,
    next_occurrence.ends_at,
    next_occurrence.event_timezone
  from public.recurring_activities as activity
  cross join lateral private.next_recurring_activity_occurrence(
    activity.id,
    p_reference_time
  ) as next_occurrence
  left join public.project_covers as cover on cover.project_id = activity.id
  where activity.lifecycle_state = 'published'
    and (
      normalized_locality is null
      or lower(activity.locality) = lower(normalized_locality)
    )
    and (
      p_cursor_next_starts_at is null
      or (next_occurrence.starts_at, activity.id)
        > (p_cursor_next_starts_at, p_cursor_id)
    )
  order by next_occurrence.starts_at, activity.id
  limit p_limit;
end;
$$;

create function public.get_public_recurring_activity(
  p_recurring_activity_id uuid,
  p_occurrence_limit integer default 5,
  p_reference_time timestamptz default statement_timestamp()
)
returns table (
  recurring_activity_id uuid,
  cover_object_path text,
  creator_profile_id uuid,
  creator_display_name text,
  lifecycle_state text,
  title text,
  summary text,
  description text,
  topic text,
  country_code text,
  locality text,
  administrative_area text,
  public_location_label text,
  recurrence_type text,
  weekday smallint,
  day_of_month smallint,
  local_start_time time without time zone,
  duration_minutes integer,
  event_timezone text,
  schedule_effective_from date,
  next_occurrences jsonb,
  exact_meeting_text text,
  exact_location_restricted boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if p_occurrence_limit is null or p_occurrence_limit not between 1 and 20 then
    raise exception using
      errcode = '22023',
      message = 'Public recurring activity occurrence limits must be between 1 and 20.';
  end if;

  if p_reference_time is null then
    raise exception using
      errcode = '22023',
      message = 'Recurring activity detail requires a reference time.';
  end if;

  return query
  select
    activity.id,
    cover.object_path,
    activity.creator_profile_id,
    case
      when display_visibility.audience = 'public' then creator.display_name
      else null
    end,
    activity.lifecycle_state,
    activity.title,
    activity.summary,
    activity.description,
    activity.topic,
    activity.country_code,
    activity.locality,
    activity.administrative_area,
    activity.public_location_label,
    selected_schedule.recurrence_type,
    selected_schedule.weekday,
    selected_schedule.day_of_month,
    selected_schedule.local_start_time,
    selected_schedule.duration_minutes,
    selected_schedule.event_timezone,
    selected_schedule.effective_from,
    case
      when activity.lifecycle_state = 'published'
        and next_occurrence.starts_at is not null then coalesce(
          (
            select jsonb_agg(
              jsonb_build_object(
                'local_starts_at', occurrence.local_starts_at,
                'starts_at', occurrence.starts_at,
                'ends_at', occurrence.ends_at,
                'event_timezone', occurrence.event_timezone
              )
              order by occurrence.starts_at
            )
            from private.derive_recurring_activity_occurrences(
              activity.id,
              next_occurrence.starts_at,
              next_occurrence.starts_at + interval '5 years',
              p_occurrence_limit
            ) as occurrence
          ),
          '[]'::jsonb
        )
      else '[]'::jsonb
    end,
    case
      when meeting.exact_location_visibility = 'public'
        then meeting.exact_meeting_text
      else null
    end,
    meeting.exact_location_visibility = 'participants'
  from public.recurring_activities as activity
  join public.profiles as creator on creator.id = activity.creator_profile_id
  left join public.profile_field_visibility as display_visibility
    on display_visibility.profile_id = creator.id
    and display_visibility.field_key = 'display_name'
  join public.recurring_activity_meeting_details as meeting
    on meeting.recurring_activity_id = activity.id
  left join public.project_covers as cover on cover.project_id = activity.id
  left join lateral private.next_recurring_activity_occurrence(
    activity.id,
    p_reference_time
  ) as next_occurrence on activity.lifecycle_state = 'published'
  left join lateral (
    select schedule.id
    from public.recurring_activity_schedules as schedule
    where schedule.recurring_activity_id = activity.id
      and schedule.effective_until is null
    limit 1
  ) as latest_schedule on true
  join public.recurring_activity_schedules as selected_schedule
    on selected_schedule.id = coalesce(
      next_occurrence.schedule_version_id,
      latest_schedule.id
    )
  where activity.id = p_recurring_activity_id
    and activity.lifecycle_state in ('published', 'paused', 'ended');
end;
$$;

create function public.list_own_recurring_activities(
  p_expected_creator_profile_id uuid
)
returns table (
  recurring_activity_id uuid,
  cover_object_path text,
  lifecycle_state text,
  title text,
  summary text,
  description text,
  topic text,
  country_code text,
  locality text,
  administrative_area text,
  public_location_label text,
  current_schedule jsonb,
  schedule_history jsonb,
  exact_meeting_text text,
  exact_location_visibility text,
  created_at timestamptz,
  updated_at timestamptz,
  published_at timestamptz,
  paused_at timestamptz,
  resumed_at timestamptz,
  ended_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_expected_recurring_activity_identity(
    p_expected_creator_profile_id
  );
begin
  return query
  select
    activity.id,
    cover.object_path,
    activity.lifecycle_state,
    activity.title,
    activity.summary,
    activity.description,
    activity.topic,
    activity.country_code,
    activity.locality,
    activity.administrative_area,
    activity.public_location_label,
    case
      when current_schedule.id is null then null
      else jsonb_build_object(
        'id', current_schedule.id,
        'recurrence_type', current_schedule.recurrence_type,
        'weekday', current_schedule.weekday,
        'day_of_month', current_schedule.day_of_month,
        'local_start_time', current_schedule.local_start_time,
        'duration_minutes', current_schedule.duration_minutes,
        'event_timezone', current_schedule.event_timezone,
        'effective_from', current_schedule.effective_from
      )
    end,
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', schedule.id,
            'recurrence_type', schedule.recurrence_type,
            'weekday', schedule.weekday,
            'day_of_month', schedule.day_of_month,
            'local_start_time', schedule.local_start_time,
            'duration_minutes', schedule.duration_minutes,
            'event_timezone', schedule.event_timezone,
            'effective_from', schedule.effective_from,
            'effective_until', schedule.effective_until,
            'created_at', schedule.created_at,
            'superseded_at', schedule.superseded_at
          )
          order by schedule.effective_from, schedule.id
        )
        from public.recurring_activity_schedules as schedule
        where schedule.recurring_activity_id = activity.id
      ),
      '[]'::jsonb
    ),
    meeting.exact_meeting_text,
    meeting.exact_location_visibility,
    activity.created_at,
    activity.updated_at,
    activity.published_at,
    activity.paused_at,
    activity.resumed_at,
    activity.ended_at
  from public.recurring_activities as activity
  join public.recurring_activity_meeting_details as meeting
    on meeting.recurring_activity_id = activity.id
  left join public.project_covers as cover on cover.project_id = activity.id
  left join lateral (
    select schedule.*
    from public.recurring_activity_schedules as schedule
    where schedule.recurring_activity_id = activity.id
      and schedule.effective_until is null
    limit 1
  ) as current_schedule on true
  where activity.creator_profile_id = current_profile_id
  order by activity.created_at desc, activity.id;
end;
$$;

create function public.get_own_recurring_activity(
  p_expected_creator_profile_id uuid,
  p_recurring_activity_id uuid
)
returns table (
  recurring_activity_id uuid,
  cover_object_path text,
  lifecycle_state text,
  title text,
  summary text,
  description text,
  topic text,
  country_code text,
  locality text,
  administrative_area text,
  public_location_label text,
  current_schedule jsonb,
  schedule_history jsonb,
  exact_meeting_text text,
  exact_location_visibility text,
  created_at timestamptz,
  updated_at timestamptz,
  published_at timestamptz,
  paused_at timestamptz,
  resumed_at timestamptz,
  ended_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select *
  from public.list_own_recurring_activities(p_expected_creator_profile_id)
  where recurring_activity_id = p_recurring_activity_id
$$;

create function public.list_own_pending_requested_recurring_activities(
  p_expected_requester_profile_id uuid,
  p_reference_time timestamptz,
  p_locality text default null
)
returns table (
  recurring_activity_id uuid,
  cover_object_path text,
  request_id uuid,
  request_created_at timestamptz,
  title text,
  summary text,
  topic text,
  country_code text,
  locality text,
  administrative_area text,
  public_location_label text,
  next_starts_at timestamptz,
  next_ends_at timestamptz,
  event_timezone text,
  recurrence_type text,
  weekday smallint,
  day_of_month smallint,
  local_start_time time without time zone,
  duration_minutes integer,
  schedule_effective_from date
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_complete_participation_profile(
    p_expected_requester_profile_id
  );
  normalized_locality text := nullif(btrim(p_locality), '');
begin
  if p_reference_time is null then
    raise exception using
      errcode = '22023',
      message = 'Requested Tavolo discovery requires a reference time.';
  end if;

  return query
  select
    activity.id,
    cover.object_path,
    request.id,
    request.created_at,
    activity.title,
    activity.summary,
    activity.topic,
    activity.country_code,
    activity.locality,
    activity.administrative_area,
    activity.public_location_label,
    next_occurrence.starts_at,
    next_occurrence.ends_at,
    next_occurrence.event_timezone,
    schedule.recurrence_type,
    schedule.weekday,
    schedule.day_of_month,
    schedule.local_start_time,
    schedule.duration_minutes,
    schedule.effective_from
  from public.project_join_requests as request
  join public.recurring_activities as activity
    on activity.id = request.project_id
  cross join lateral private.next_recurring_activity_occurrence(
    activity.id,
    p_reference_time
  ) as next_occurrence
  join public.recurring_activity_schedules as schedule
    on schedule.id = next_occurrence.schedule_version_id
  left join public.project_covers as cover on cover.project_id = activity.id
  where request.requester_profile_id = current_profile_id
    and request.status = 'pending'
    and activity.lifecycle_state = 'published'
    and (
      normalized_locality is null
      or lower(activity.locality) = lower(normalized_locality)
    )
  order by request.created_at desc, activity.id desc
  limit 200;
end;
$$;

comment on function public.list_public_recurring_activities(timestamptz, integer, timestamptz, uuid, text) is
  'Returns published Tavoli with rough location, derived occurrence, and nullable canonical cover path.';
comment on function public.get_public_recurring_activity(uuid, integer, timestamptz) is
  'Returns exact-ID published, paused, or ended Tavolo detail with its nullable canonical cover path.';
comment on function public.list_own_recurring_activities(uuid) is
  'Returns complete expected-owner Tavolo history with nullable canonical cover paths.';
comment on function public.get_own_recurring_activity(uuid, uuid) is
  'Returns one complete expected-owner Tavolo with its nullable canonical cover path.';
comment on function public.list_own_pending_requested_recurring_activities(uuid, timestamptz, text) is
  'Returns at most 200 public Tavolo cards with pending-request context and nullable canonical cover paths.';

drop function public.list_project_resource_need_listing_matches(
  uuid, uuid, text, integer, text, text, text, timestamptz, uuid
);
drop function public.get_own_resource_listing(uuid, uuid);
drop function public.list_own_resource_listings(uuid);
drop function public.get_public_resource_listing(uuid);
drop function public.list_public_resource_listings(integer, timestamptz, uuid, text, text, text);

create function public.list_own_resource_listings(
  p_expected_owner_profile_id uuid
)
returns table (
  listing_id uuid,
  cover_object_path text,
  owner_profile_id uuid,
  listing_mode text,
  lifecycle_state text,
  title text,
  description text,
  country_code text,
  locality text,
  administrative_area text,
  public_location_label text,
  created_at timestamptz,
  updated_at timestamptz,
  published_at timestamptz,
  closed_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_resource_listing_identity(
    p_expected_owner_profile_id
  );
begin
  return query
  select
    listing.id,
    cover.object_path,
    listing.owner_profile_id,
    listing.listing_mode,
    listing.lifecycle_state,
    listing.title,
    listing.description,
    listing.country_code,
    listing.locality,
    listing.administrative_area,
    listing.public_location_label,
    listing.created_at,
    listing.updated_at,
    listing.published_at,
    listing.closed_at
  from public.resource_listings as listing
  left join public.resource_listing_covers as cover
    on cover.listing_id = listing.id
  where listing.owner_profile_id = current_profile_id
  order by listing.created_at desc, listing.id desc;
end;
$$;

create function public.get_own_resource_listing(
  p_expected_owner_profile_id uuid,
  p_listing_id uuid
)
returns table (
  listing_id uuid,
  cover_object_path text,
  owner_profile_id uuid,
  listing_mode text,
  lifecycle_state text,
  title text,
  description text,
  country_code text,
  locality text,
  administrative_area text,
  public_location_label text,
  created_at timestamptz,
  updated_at timestamptz,
  published_at timestamptz,
  closed_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select *
  from public.list_own_resource_listings(p_expected_owner_profile_id)
  where listing_id = p_listing_id
$$;

create function public.list_public_resource_listings(
  p_limit integer default 20,
  p_cursor_published_at timestamptz default null,
  p_cursor_id uuid default null,
  p_listing_mode text default null,
  p_locality text default null,
  p_query text default null
)
returns table (
  listing_id uuid,
  cover_object_path text,
  listing_mode text,
  title text,
  description text,
  country_code text,
  locality text,
  administrative_area text,
  public_location_label text,
  published_at timestamptz,
  active_request_count bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  normalized_listing_mode text := lower(nullif(btrim(p_listing_mode), ''));
  normalized_locality text := nullif(btrim(p_locality), '');
  normalized_query text := nullif(btrim(p_query), '');
begin
  if p_limit is null or p_limit not between 1 and 50 then
    raise exception using
      errcode = '22023',
      message = 'Resource listing page size must be between 1 and 50.';
  end if;

  if (p_cursor_published_at is null) <> (p_cursor_id is null) then
    raise exception using
      errcode = '22023',
      message = 'Resource listing cursor values must be supplied together.';
  end if;

  if normalized_listing_mode is not null
    and normalized_listing_mode not in ('donate', 'exchange') then
    raise exception using
      errcode = '22023',
      message = 'Resource listing mode filter must be donate or exchange.';
  end if;

  if normalized_locality is not null
    and char_length(normalized_locality) > 120 then
    raise exception using
      errcode = '22023',
      message = 'Resource listing locality filter must contain at most 120 characters.';
  end if;

  if normalized_query is not null and char_length(normalized_query) > 120 then
    raise exception using
      errcode = '22023',
      message = 'Resource listing query must contain at most 120 characters.';
  end if;

  return query
  select
    listing.id,
    cover.object_path,
    listing.listing_mode,
    listing.title,
    listing.description,
    listing.country_code,
    listing.locality,
    listing.administrative_area,
    listing.public_location_label,
    listing.published_at,
    (
      select count(*)
      from public.resource_listing_requests as request
      where request.listing_id = listing.id
        and (
          request.status = 'pending'
          or (
            request.status = 'accepted'
            and request.coordination_closed_at is null
          )
        )
    )
  from public.resource_listings as listing
  left join public.resource_listing_covers as cover
    on cover.listing_id = listing.id
  where listing.lifecycle_state = 'published'
    and (
      normalized_listing_mode is null
      or listing.listing_mode = normalized_listing_mode
    )
    and (
      normalized_locality is null
      or lower(listing.locality) = lower(normalized_locality)
    )
    and (
      normalized_query is null
      or strpos(lower(listing.title), lower(normalized_query)) > 0
      or strpos(lower(listing.description), lower(normalized_query)) > 0
    )
    and (
      p_cursor_published_at is null
      or (listing.published_at, listing.id)
        < (p_cursor_published_at, p_cursor_id)
    )
  order by listing.published_at desc, listing.id desc
  limit p_limit;
end;
$$;

create function public.get_public_resource_listing(p_listing_id uuid)
returns table (
  listing_id uuid,
  cover_object_path text,
  listing_mode text,
  title text,
  description text,
  country_code text,
  locality text,
  administrative_area text,
  public_location_label text,
  published_at timestamptz,
  owner_profile_id uuid,
  owner_display_name text,
  active_request_count bigint
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    listing.id,
    cover.object_path,
    listing.listing_mode,
    listing.title,
    listing.description,
    listing.country_code,
    listing.locality,
    listing.administrative_area,
    listing.public_location_label,
    listing.published_at,
    listing.owner_profile_id,
    case
      when display_visibility.audience = 'public' then owner.display_name
      else null
    end,
    (
      select count(*)
      from public.resource_listing_requests as request
      where request.listing_id = listing.id
        and (
          request.status = 'pending'
          or (
            request.status = 'accepted'
            and request.coordination_closed_at is null
          )
        )
    )
  from public.resource_listings as listing
  join public.profiles as owner on owner.id = listing.owner_profile_id
  left join public.profile_field_visibility as display_visibility
    on display_visibility.profile_id = owner.id
    and display_visibility.field_key = 'display_name'
  left join public.resource_listing_covers as cover
    on cover.listing_id = listing.id
  where listing.id = p_listing_id
    and listing.lifecycle_state = 'published'
$$;

create function public.list_project_resource_need_listing_matches(
  p_expected_creator_profile_id uuid,
  p_resource_need_id uuid,
  p_location_scope text,
  p_limit integer default 20,
  p_listing_mode text default null,
  p_cursor_text_match_kind text default null,
  p_cursor_location_match_kind text default null,
  p_cursor_published_at timestamptz default null,
  p_cursor_listing_id uuid default null
)
returns table (
  resource_need_id uuid,
  listing_id uuid,
  cover_object_path text,
  listing_mode text,
  title text,
  description text,
  country_code text,
  locality text,
  administrative_area text,
  public_location_label text,
  published_at timestamptz,
  active_request_count bigint,
  text_match_kind text,
  location_match_kind text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_participation_identity(
    p_expected_creator_profile_id
  );
  resource_need public.project_resource_needs%rowtype;
  project_record public.projects%rowtype;
  source_state text;
  source_ends_at timestamptz;
  source_country_code text;
  source_locality text;
  source_administrative_area text;
  normalized_mode text := pg_catalog.lower(pg_catalog.btrim(p_listing_mode));
  cursor_text_rank integer;
  cursor_location_rank integer;
begin
  if p_location_scope is null or p_location_scope not in (
    'same_locality', 'same_administrative_area', 'same_country', 'anywhere'
  ) then
    raise exception using errcode = '22023',
      message = 'An explicit valid Project resource matching location scope is required.';
  end if;

  if p_limit is null or p_limit not between 1 and 50 then
    raise exception using errcode = '22023',
      message = 'Project resource matching page size must be between 1 and 50.';
  end if;

  if normalized_mode is not null
    and normalized_mode not in ('donate', 'exchange') then
    raise exception using errcode = '22023',
      message = 'Project resource matching mode must be donate or exchange.';
  end if;

  if num_nonnulls(
    p_cursor_text_match_kind,
    p_cursor_location_match_kind,
    p_cursor_published_at,
    p_cursor_listing_id
  ) not in (0, 4) then
    raise exception using errcode = '22023',
      message = 'All Project resource matching cursor values must be supplied together.';
  end if;

  cursor_text_rank := case p_cursor_text_match_kind
    when 'title_phrase' then 1
    when 'need_title_in_listing_title' then 2
    when 'need_title_in_listing_description' then 3
    when 'need_details_in_listing_title' then 4
    when 'need_details_in_listing_description' then 5
  end;
  cursor_location_rank := case p_cursor_location_match_kind
    when 'same_locality' then 1
    when 'same_administrative_area' then 2
    when 'same_country' then 3
    when 'other_or_unknown' then 4
  end;

  if p_cursor_listing_id is not null and (
    cursor_text_rank is null or cursor_location_rank is null
  ) then
    raise exception using errcode = '22023',
      message = 'Project resource matching cursor reasons are invalid.';
  end if;

  select * into resource_need
  from public.project_resource_needs as need
  where need.id = p_resource_need_id;

  if not found then
    raise exception using errcode = 'P0002',
      message = 'The Project resource need does not exist.';
  end if;

  select * into project_record
  from public.projects as project
  where project.id = resource_need.project_id;

  if not found or project_record.creator_profile_id <> current_profile_id then
    raise exception using errcode = '42501',
      message = 'Only the Project creator can match its resource need.';
  end if;

  if resource_need.state <> 'open' then
    raise exception using errcode = '55000',
      message = 'Only an open Project resource need can be matched.';
  end if;

  if project_record.project_kind = 'one_time' then
    select
      proposal.lifecycle_state,
      proposal.ends_at,
      proposal.country_code,
      proposal.locality,
      proposal.administrative_area
    into
      source_state,
      source_ends_at,
      source_country_code,
      source_locality,
      source_administrative_area
    from public.proposals as proposal
    where proposal.id = project_record.id
      and proposal.creator_profile_id = current_profile_id;

    if not found then
      raise exception using errcode = '55000',
        message = 'The Project registry does not match its Proposal.';
    end if;

    if not (
      source_state = 'draft'
      or (source_state = 'published' and source_ends_at > statement_timestamp())
    ) then
      raise exception using errcode = '55000',
        message = 'The Proposal is no longer eligible for resource matching.';
    end if;
  elsif project_record.project_kind = 'recurring' then
    select
      activity.lifecycle_state,
      activity.country_code,
      activity.locality,
      activity.administrative_area
    into
      source_state,
      source_country_code,
      source_locality,
      source_administrative_area
    from public.recurring_activities as activity
    where activity.id = project_record.id
      and activity.creator_profile_id = current_profile_id;

    if not found then
      raise exception using errcode = '55000',
        message = 'The Project registry does not match its Tavolo.';
    end if;

    if source_state not in ('draft', 'published', 'paused') then
      raise exception using errcode = '55000',
        message = 'The Tavolo is no longer eligible for resource matching.';
    end if;
  else
    raise exception using errcode = '55000',
      message = 'The Project kind is not eligible for resource matching.';
  end if;

  if (source_locality is null and p_location_scope = 'same_locality')
    or (
      (source_country_code is null or source_administrative_area is null)
      and p_location_scope = 'same_administrative_area'
    )
    or (source_country_code is null and p_location_scope = 'same_country') then
    raise exception using errcode = '55000',
      message = 'The Project lacks rough geography required by the selected matching scope.';
  end if;

  return query
  with source_terms as materialized (
    select
      private.project_resource_match_or_query(resource_need.title) as title_query,
      private.project_resource_match_or_query(resource_need.details) as details_query,
      pg_catalog.lower(pg_catalog.regexp_replace(
        pg_catalog.btrim(resource_need.title), '\s+', ' ', 'g'
      )) as normalized_title
  ), candidates as (
    select
      listing.id,
      listing.published_at,
      reason.text_match_kind,
      reason.location_match_kind,
      case reason.text_match_kind
        when 'title_phrase' then 1
        when 'need_title_in_listing_title' then 2
        when 'need_title_in_listing_description' then 3
        when 'need_details_in_listing_title' then 4
        else 5
      end as text_rank,
      case reason.location_match_kind
        when 'same_locality' then 1
        when 'same_administrative_area' then 2
        when 'same_country' then 3
        else 4
      end as location_rank
    from public.resource_listings as listing
    cross join source_terms as terms
    cross join lateral private.evaluate_project_resource_listing_match(
      resource_need.title,
      resource_need.details,
      source_country_code,
      source_locality,
      source_administrative_area,
      listing.title,
      listing.description,
      listing.country_code,
      listing.locality,
      listing.administrative_area
    ) as reason
    where listing.lifecycle_state = 'published'
      and (normalized_mode is null or listing.listing_mode = normalized_mode)
      and (
        (
          terms.normalized_title <> ''
          and pg_catalog.strpos(
            pg_catalog.lower(pg_catalog.regexp_replace(
              pg_catalog.btrim(listing.title), '\s+', ' ', 'g'
            )),
            terms.normalized_title
          ) > 0
        )
        or (
          terms.title_query is not null
          and (
            pg_catalog.to_tsvector(
              'italian'::regconfig,
              coalesce(listing.title, '')
            ) @@ terms.title_query
            or pg_catalog.to_tsvector(
              'italian'::regconfig,
              coalesce(listing.description, '')
            ) @@ terms.title_query
          )
        )
        or (
          terms.details_query is not null
          and (
            pg_catalog.to_tsvector(
              'italian'::regconfig,
              coalesce(listing.title, '')
            ) @@ terms.details_query
            or pg_catalog.to_tsvector(
              'italian'::regconfig,
              coalesce(listing.description, '')
            ) @@ terms.details_query
          )
        )
      )
      and reason.is_match
      and (
        p_location_scope = 'anywhere'
        or (
          p_location_scope = 'same_locality'
          and pg_catalog.lower(pg_catalog.btrim(listing.locality)) =
            pg_catalog.lower(pg_catalog.btrim(source_locality))
        )
        or (
          p_location_scope = 'same_administrative_area'
          and listing.country_code = source_country_code
          and pg_catalog.lower(pg_catalog.btrim(listing.administrative_area)) =
            pg_catalog.lower(pg_catalog.btrim(source_administrative_area))
        )
        or (
          p_location_scope = 'same_country'
          and listing.country_code = source_country_code
        )
      )
  )
  select
    resource_need.id,
    candidate.id,
    public_listing.cover_object_path,
    public_listing.listing_mode,
    public_listing.title,
    public_listing.description,
    public_listing.country_code,
    public_listing.locality,
    public_listing.administrative_area,
    public_listing.public_location_label,
    candidate.published_at,
    public_listing.active_request_count,
    candidate.text_match_kind,
    candidate.location_match_kind
  from candidates as candidate
  cross join lateral public.get_public_resource_listing(candidate.id)
    as public_listing
  where p_cursor_listing_id is null
    or candidate.text_rank > cursor_text_rank
    or (
      candidate.text_rank = cursor_text_rank
      and candidate.location_rank > cursor_location_rank
    )
    or (
      candidate.text_rank = cursor_text_rank
      and candidate.location_rank = cursor_location_rank
      and candidate.published_at < p_cursor_published_at
    )
    or (
      candidate.text_rank = cursor_text_rank
      and candidate.location_rank = cursor_location_rank
      and candidate.published_at = p_cursor_published_at
      and candidate.id < p_cursor_listing_id
    )
  order by
    candidate.text_rank,
    candidate.location_rank,
    candidate.published_at desc,
    candidate.id desc
  limit p_limit;
end;
$$;

comment on function public.list_own_resource_listings(uuid) is
  'Returns the expected owner complete Resource-listing history with nullable canonical cover paths.';
comment on function public.get_own_resource_listing(uuid, uuid) is
  'Returns one expected owner Resource listing with its nullable canonical cover path.';
comment on function public.list_public_resource_listings(integer, timestamptz, uuid, text, text, text) is
  'Returns published Resource cards with existing filters, active-request counts, and nullable canonical cover paths.';
comment on function public.get_public_resource_listing(uuid) is
  'Returns exact-ID published Resource detail with sanitized owner context and nullable canonical cover path.';
comment on function public.list_project_resource_need_listing_matches(
  uuid, uuid, text, integer, text, text, text, timestamptz, uuid
) is
  'Returns creator-only explainable public Resource matches with nullable canonical cover paths and the existing stable keyset.';

revoke all privileges on function private.set_cover_updated_at()
  from public, anon, authenticated, service_role;
revoke all privileges on function private.require_cover_identity(uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function private.is_cover_object_path_for_parent(text, uuid, text, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function private.is_project_cover_editable(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function private.is_resource_cover_editable(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function private.lock_owned_editable_project_cover_parent(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function private.lock_owned_editable_resource_cover_parent(uuid, uuid)
  from public, anon, authenticated, service_role;

revoke all privileges on function public.can_manage_cover_image_object(text)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.can_upload_cover_image_object(text)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.can_read_public_cover_image_object(text)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.get_own_project_cover(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.set_own_project_cover(uuid, uuid, text)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.clear_own_project_cover(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.get_own_resource_listing_cover(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.set_own_resource_listing_cover(uuid, uuid, text)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.clear_own_resource_listing_cover(uuid, uuid)
  from public, anon, authenticated, service_role;

revoke all privileges on function public.list_public_proposals(integer, timestamptz, uuid, text, uuid[], text)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.get_public_proposal(uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.list_own_proposals(uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.get_own_proposal(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.list_own_pending_requested_proposals(uuid, text, uuid[], text)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.list_public_recurring_activities(timestamptz, integer, timestamptz, uuid, text)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.get_public_recurring_activity(uuid, integer, timestamptz)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.list_own_recurring_activities(uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.get_own_recurring_activity(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.list_own_pending_requested_recurring_activities(uuid, timestamptz, text)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.list_public_resource_listings(integer, timestamptz, uuid, text, text, text)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.get_public_resource_listing(uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.list_own_resource_listings(uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.get_own_resource_listing(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.list_project_resource_need_listing_matches(
  uuid, uuid, text, integer, text, text, text, timestamptz, uuid
) from public, anon, authenticated, service_role;

grant execute on function public.can_manage_cover_image_object(text)
  to authenticated;
grant execute on function public.can_upload_cover_image_object(text)
  to authenticated;
grant execute on function public.can_read_public_cover_image_object(text)
  to anon, authenticated;
grant execute on function public.get_own_project_cover(uuid, uuid)
  to authenticated;
grant execute on function public.set_own_project_cover(uuid, uuid, text)
  to authenticated;
grant execute on function public.clear_own_project_cover(uuid, uuid)
  to authenticated;
grant execute on function public.get_own_resource_listing_cover(uuid, uuid)
  to authenticated;
grant execute on function public.set_own_resource_listing_cover(uuid, uuid, text)
  to authenticated;
grant execute on function public.clear_own_resource_listing_cover(uuid, uuid)
  to authenticated;

grant execute on function public.list_public_proposals(integer, timestamptz, uuid, text, uuid[], text)
  to anon, authenticated;
grant execute on function public.get_public_proposal(uuid)
  to anon, authenticated;
grant execute on function public.list_own_proposals(uuid)
  to authenticated;
grant execute on function public.get_own_proposal(uuid, uuid)
  to authenticated;
grant execute on function public.list_own_pending_requested_proposals(uuid, text, uuid[], text)
  to authenticated;
grant execute on function public.list_public_recurring_activities(timestamptz, integer, timestamptz, uuid, text)
  to anon, authenticated;
grant execute on function public.get_public_recurring_activity(uuid, integer, timestamptz)
  to anon, authenticated;
grant execute on function public.list_own_recurring_activities(uuid)
  to authenticated;
grant execute on function public.get_own_recurring_activity(uuid, uuid)
  to authenticated;
grant execute on function public.list_own_pending_requested_recurring_activities(uuid, timestamptz, text)
  to authenticated;
grant execute on function public.list_public_resource_listings(integer, timestamptz, uuid, text, text, text)
  to anon, authenticated;
grant execute on function public.get_public_resource_listing(uuid)
  to anon, authenticated;
grant execute on function public.list_own_resource_listings(uuid)
  to authenticated;
grant execute on function public.get_own_resource_listing(uuid, uuid)
  to authenticated;
grant execute on function public.list_project_resource_need_listing_matches(
  uuid, uuid, text, integer, text, text, text, timestamptz, uuid
) to authenticated;
