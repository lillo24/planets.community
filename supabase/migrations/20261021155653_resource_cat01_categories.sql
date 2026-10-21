-- RESOURCE-CAT01: provisional classification only, never a permitted-goods policy.
-- Old RPC signatures and row shapes remain intact. No classification/event backfill.
create function private.is_resource_category_slug(p_value text)
returns boolean language sql immutable set search_path = '' as $$
  select p_value = any(array[
    'tools_diy', 'garden_outdoors', 'home_furniture', 'electronics',
    'clothing_accessories', 'books_learning', 'sports_hobbies', 'materials', 'other'
  ]::text[])
$$;

create function private.normalize_resource_category_slug(p_value text)
returns text language plpgsql immutable set search_path = '' as $$
declare normalized text := pg_catalog.lower(nullif(pg_catalog.btrim(p_value), ''));
begin
  if normalized is not null and not private.is_resource_category_slug(normalized) then
    raise exception using errcode = '22023', message = 'Unsupported resource category.';
  end if;
  return normalized;
end;
$$;
revoke all on function private.is_resource_category_slug(text) from public, anon, authenticated, service_role;
revoke all on function private.normalize_resource_category_slug(text) from public, anon, authenticated, service_role;

alter table public.resource_listings add column category_slug text
  constraint resource_listings_category_slug_valid
  check (category_slug is null or private.is_resource_category_slug(category_slug));
alter table public.resource_saved_searches add column category_slug text
  constraint resource_saved_searches_category_slug_valid
  check (category_slug is null or private.is_resource_category_slug(category_slug));
comment on column public.resource_listings.category_slug is
  'Optional provisional classification; NULL remains unclassified, never Other. Category is independent of eligibility, mode and loan/barter policy.';
comment on column public.resource_saved_searches.category_slug is
  'Optional exact canonical category criterion; NULL includes legacy and categorized listings.';

alter table public.resource_saved_searches drop constraint resource_saved_searches_filter_present;
alter table public.resource_saved_searches add constraint resource_saved_searches_filter_present
  check (query is not null or listing_mode is not null or locality is not null or category_slug is not null);
-- Keep the index name: existing released RPCs map this exact unique violation.
drop index public.resource_saved_searches_profile_filters_unique_idx;
create unique index resource_saved_searches_profile_filters_unique_idx
  on public.resource_saved_searches (
    profile_id, lower(coalesce(query, '')), coalesce(listing_mode, ''),
    lower(coalesce(locality, '')), coalesce(category_slug, '')
  );
-- Mirrors existing published-filter + paired-keyset indexes, scoped to explicit categories.
create index resource_listings_category_published_idx
  on public.resource_listings(category_slug, published_at desc, id desc)
  where lifecycle_state = 'published' and category_slug is not null;

create function private.replace_resource_listing_content_v2(
  p_listing_id uuid,
  p_listing_mode text,
  p_title text,
  p_description text,
  p_country_code text,
  p_locality text,
  p_administrative_area text,
  p_public_location_label text,
  p_category_slug text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  normalized_category text := private.normalize_resource_category_slug(p_category_slug);
  normalized_listing_mode text := lower(nullif(btrim(p_listing_mode), ''));
  normalized_title text := nullif(btrim(p_title), '');
  normalized_description text := nullif(btrim(p_description), '');
  normalized_country_code text := nullif(upper(btrim(p_country_code)), '');
  normalized_locality text := nullif(btrim(p_locality), '');
  normalized_administrative_area text := nullif(btrim(p_administrative_area), '');
  normalized_public_location_label text := nullif(btrim(p_public_location_label), '');
begin
  if normalized_listing_mode is null
    or normalized_listing_mode not in ('donate', 'exchange') then
    raise exception using
      errcode = '22023',
      message = 'Resource listing mode must be donate or exchange.';
  end if;

  if normalized_title is not null
    and char_length(normalized_title) not between 2 and 120 then
    raise exception using
      errcode = '22023',
      message = 'Resource listing title must contain between 2 and 120 characters.';
  end if;

  if normalized_description is not null
    and char_length(normalized_description) > 5000 then
    raise exception using
      errcode = '22023',
      message = 'Resource listing description must contain at most 5000 characters.';
  end if;

  if normalized_country_code is not null
    and normalized_country_code !~ '^[A-Z]{2}$' then
    raise exception using
      errcode = '22023',
      message = 'Resource listing country code must contain two letters.';
  end if;

  if normalized_locality is not null
    and char_length(normalized_locality) > 120 then
    raise exception using
      errcode = '22023',
      message = 'Resource listing locality must contain at most 120 characters.';
  end if;

  if normalized_administrative_area is not null
    and char_length(normalized_administrative_area) > 120 then
    raise exception using
      errcode = '22023',
      message = 'Resource listing administrative area must contain at most 120 characters.';
  end if;

  if normalized_public_location_label is not null
    and char_length(normalized_public_location_label) > 180 then
    raise exception using
      errcode = '22023',
      message = 'Resource listing public location label must contain at most 180 characters.';
  end if;

  update public.resource_listings
  set
    listing_mode = normalized_listing_mode,
    category_slug = normalized_category,
    title = normalized_title,
    description = normalized_description,
    country_code = normalized_country_code,
    locality = normalized_locality,
    administrative_area = normalized_administrative_area,
    public_location_label = normalized_public_location_label
  where id = p_listing_id;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'The resource listing does not exist.';
  end if;
end;
$$;

revoke all on function private.replace_resource_listing_content_v2(uuid, text, text, text, text, text, text, text, text) from public, anon, authenticated, service_role;

create function public.create_resource_listing_draft_v2(
  p_expected_owner_profile_id uuid,
  p_listing_mode text,
  p_title text,
  p_description text,
  p_country_code text,
  p_locality text,
  p_administrative_area text,
  p_public_location_label text,
  p_category_slug text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_complete_resource_listing_identity(
    p_expected_owner_profile_id
  );
  normalized_listing_mode text := lower(nullif(btrim(p_listing_mode), ''));
  listing_id uuid;
begin
  if normalized_listing_mode is null
    or normalized_listing_mode not in ('donate', 'exchange') then
    raise exception using
      errcode = '22023',
      message = 'Resource listing mode must be donate or exchange.';
  end if;

  insert into public.resource_listings (owner_profile_id, listing_mode)
  values (current_profile_id, normalized_listing_mode)
  returning id into listing_id;

  perform private.replace_resource_listing_content_v2(
    listing_id,
    normalized_listing_mode,
    p_title,
    p_description,
    p_country_code,
    p_locality,
    p_administrative_area,
    p_public_location_label,
    p_category_slug
  );

  return listing_id;
end;
$$;

revoke all on function public.create_resource_listing_draft_v2(uuid, text, text, text, text, text, text, text, text) from public, anon, authenticated, service_role;

grant execute on function public.create_resource_listing_draft_v2(uuid, text, text, text, text, text, text, text, text) to authenticated;

create function public.update_own_resource_listing_v2(
  p_expected_owner_profile_id uuid,
  p_listing_id uuid,
  p_listing_mode text,
  p_title text,
  p_description text,
  p_country_code text,
  p_locality text,
  p_administrative_area text,
  p_public_location_label text,
  p_category_slug text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_resource_listing_identity(
    p_expected_owner_profile_id
  );
  listing public.resource_listings%rowtype;
begin
  select * into listing
  from public.resource_listings
  where id = p_listing_id
  for update;

  if listing.id is null or listing.owner_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'The current user does not own this resource listing.';
  end if;

  if listing.lifecycle_state not in ('draft', 'published') then
    raise exception using
      errcode = '55000',
      message = 'This resource listing can no longer be edited.';
  end if;

  perform private.replace_resource_listing_content_v2(
    p_listing_id,
    p_listing_mode,
    p_title,
    p_description,
    p_country_code,
    p_locality,
    p_administrative_area,
    p_public_location_label,
    p_category_slug
  );

  if listing.lifecycle_state = 'published' then
    perform private.assert_resource_listing_publishable(p_listing_id);
  end if;

  return p_listing_id;
end;
$$;

revoke all on function public.update_own_resource_listing_v2(uuid, uuid, text, text, text, text, text, text, text, text) from public, anon, authenticated, service_role;

grant execute on function public.update_own_resource_listing_v2(uuid, uuid, text, text, text, text, text, text, text, text) to authenticated;

-- The immutable first-creation receipt includes category; recovery keeps the same ID API.

create function public.create_editor_resource_listing_draft_v2(
 p_expected_owner_profile_id uuid, p_client_request_id uuid,
 p_listing_mode text, p_title text, p_description text, p_country_code text, p_locality text, p_administrative_area text, p_public_location_label text, p_category_slug text
) returns uuid language plpgsql security definer set search_path = '' set timezone = 'UTC'
as $$
declare
 actor uuid := private.require_expected_identity(p_expected_owner_profile_id);
 receipt private.resource_draft_creations%rowtype;
 intent_hash text;
 destination uuid;
begin
 if p_client_request_id is null then
  raise exception using errcode='22023', message='A draft creation request ID is required.';
 end if;
 intent_hash := encode(extensions.digest(jsonb_build_array(p_listing_mode, p_title, p_description, p_country_code, p_locality, p_administrative_area, p_public_location_label, private.normalize_resource_category_slug(p_category_slug))::text, 'sha256'), 'hex');
 perform pg_advisory_xact_lock(hashtextextended('resource_listing.draft_create:' || actor::text || ':' || p_client_request_id::text, 0));
 perform private.require_expected_identity(p_expected_owner_profile_id);
 select * into receipt from private.resource_draft_creations
  where actor_profile_id=actor and client_request_id=p_client_request_id;
 if found then
  if receipt.accepted_intent_hash <> intent_hash then
   raise exception using errcode='22023', message='The recorded draft creation intent differs.';
  end if;
  if not exists(select 1 from public.resource_listings where id=receipt.item_id and owner_profile_id=actor) then
   raise exception using errcode='P0002', message='The recorded draft destination is unavailable.';
  end if;
  return receipt.item_id;
 end if;
 destination := public.create_resource_listing_draft_v2(p_expected_owner_profile_id, p_listing_mode, p_title, p_description, p_country_code, p_locality, p_administrative_area, p_public_location_label, p_category_slug);
 insert into private.resource_draft_creations values(actor,p_client_request_id,destination,intent_hash,clock_timestamp());
 return destination;
end;
$$;

revoke all on function public.create_editor_resource_listing_draft_v2(uuid, uuid, text, text, text, text, text, text, text, text) from public, anon, authenticated, service_role;

grant execute on function public.create_editor_resource_listing_draft_v2(uuid, uuid, text, text, text, text, text, text, text, text) to authenticated;

create function public.list_own_resource_listings_v2(
  p_expected_owner_profile_id uuid
)
returns table (
  listing_id uuid,
  cover_object_path text,
  owner_profile_id uuid,
  listing_mode text,
  category_slug text,
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
    listing.category_slug,
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

revoke all on function public.list_own_resource_listings_v2(uuid) from public, anon, authenticated, service_role;

grant execute on function public.list_own_resource_listings_v2(uuid) to authenticated;

create function public.get_own_resource_listing_v2(
  p_expected_owner_profile_id uuid,
  p_listing_id uuid
)
returns table (
  listing_id uuid,
  cover_object_path text,
  owner_profile_id uuid,
  listing_mode text,
  category_slug text,
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
  from public.list_own_resource_listings_v2(p_expected_owner_profile_id)
  where listing_id = p_listing_id
$$;

revoke all on function public.get_own_resource_listing_v2(uuid, uuid) from public, anon, authenticated, service_role;

grant execute on function public.get_own_resource_listing_v2(uuid, uuid) to authenticated;

create function public.list_public_resource_listings_v2(
  p_limit integer default 20,
  p_cursor_published_at timestamptz default null,
  p_cursor_id uuid default null,
  p_listing_mode text default null,
  p_locality text default null,
  p_query text default null,
  p_category_slug text default null
)
returns table (
  listing_id uuid,
  cover_object_path text,
  listing_mode text,
  category_slug text,
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
  normalized_category text := private.normalize_resource_category_slug(p_category_slug);
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
    listing.category_slug,
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
    and (normalized_category is null or listing.category_slug = normalized_category)
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

revoke all on function public.list_public_resource_listings_v2(integer, timestamptz, uuid, text, text, text, text) from public, anon, authenticated, service_role;

grant execute on function public.list_public_resource_listings_v2(integer, timestamptz, uuid, text, text, text, text) to anon, authenticated;

create function public.get_public_resource_listing_v2(p_listing_id uuid)
returns table (
  listing_id uuid,
  cover_object_path text,
  listing_mode text,
  category_slug text,
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
    listing.category_slug,
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

revoke all on function public.get_public_resource_listing_v2(uuid) from public, anon, authenticated, service_role;

grant execute on function public.get_public_resource_listing_v2(uuid) to anon, authenticated;

create function public.create_resource_saved_search_v2(
  p_expected_profile_id uuid,
  p_query text,
  p_listing_mode text,
  p_locality text,
  p_category_slug text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_resource_listing_identity(
    p_expected_profile_id
  );
  normalized_category text := private.normalize_resource_category_slug(p_category_slug);
  normalized_query text := nullif(pg_catalog.btrim(p_query), '');
  normalized_listing_mode text := pg_catalog.lower(
    nullif(pg_catalog.btrim(p_listing_mode), '')
  );
  normalized_locality text := nullif(
    pg_catalog.btrim(p_locality), ''
  );
  saved_search_id uuid;
  violation_constraint text;
begin
  if normalized_query is not null
    and pg_catalog.char_length(normalized_query) > 120 then
    raise exception using
      errcode = '22023',
      message = 'Resource saved-search query must contain at most 120 characters.';
  end if;

  if normalized_listing_mode is not null
    and normalized_listing_mode not in ('donate', 'exchange') then
    raise exception using
      errcode = '22023',
      message = 'Resource saved-search mode must be donate or exchange.';
  end if;

  if normalized_locality is not null
    and pg_catalog.char_length(normalized_locality) > 120 then
    raise exception using
      errcode = '22023',
      message = 'Resource saved-search locality must contain at most 120 characters.';
  end if;

  if normalized_query is null
    and normalized_listing_mode is null
    and normalized_locality is null
    and normalized_category is null then
    raise exception using
      errcode = '22023',
      message = 'A resource saved search must contain at least one filter.';
  end if;

  begin
    insert into public.resource_saved_searches (
      profile_id,
      query,
      listing_mode,
      locality,
      category_slug
    )
    values (
      current_profile_id,
      normalized_query,
      normalized_listing_mode,
      normalized_locality,
      normalized_category
    )
    returning id into saved_search_id;
  exception
    when unique_violation then
      get stacked diagnostics violation_constraint = constraint_name;
      if violation_constraint =
        'resource_saved_searches_profile_filters_unique_idx' then
        raise exception using
          errcode = 'PT409',
          message = 'That resource saved search already exists.';
      end if;
      raise;
  end;

  return saved_search_id;
end;
$$;

revoke all on function public.create_resource_saved_search_v2(uuid, text, text, text, text) from public, anon, authenticated, service_role;

grant execute on function public.create_resource_saved_search_v2(uuid, text, text, text, text) to authenticated;

create function public.update_resource_saved_search_v2(
  p_expected_profile_id uuid,
  p_saved_search_id uuid,
  p_query text,
  p_listing_mode text,
  p_locality text,
  p_category_slug text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_resource_listing_identity(
    p_expected_profile_id
  );
  normalized_category text := private.normalize_resource_category_slug(p_category_slug);
  normalized_query text := nullif(pg_catalog.btrim(p_query), '');
  normalized_listing_mode text := pg_catalog.lower(
    nullif(pg_catalog.btrim(p_listing_mode), '')
  );
  normalized_locality text := nullif(
    pg_catalog.btrim(p_locality), ''
  );
  saved_search_profile_id uuid;
  violation_constraint text;
begin
  if normalized_query is not null
    and pg_catalog.char_length(normalized_query) > 120 then
    raise exception using
      errcode = '22023',
      message = 'Resource saved-search query must contain at most 120 characters.';
  end if;

  if normalized_listing_mode is not null
    and normalized_listing_mode not in ('donate', 'exchange') then
    raise exception using
      errcode = '22023',
      message = 'Resource saved-search mode must be donate or exchange.';
  end if;

  if normalized_locality is not null
    and pg_catalog.char_length(normalized_locality) > 120 then
    raise exception using
      errcode = '22023',
      message = 'Resource saved-search locality must contain at most 120 characters.';
  end if;

  if normalized_query is null
    and normalized_listing_mode is null
    and normalized_locality is null
    and normalized_category is null then
    raise exception using
      errcode = '22023',
      message = 'A resource saved search must contain at least one filter.';
  end if;

  select saved_search.profile_id into saved_search_profile_id
  from public.resource_saved_searches as saved_search
  where saved_search.id = p_saved_search_id
  for update;

  if saved_search_profile_id is null
    or saved_search_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'The current user does not own this resource saved search.';
  end if;

  begin
    update public.resource_saved_searches
    set
      query = normalized_query,
      listing_mode = normalized_listing_mode,
      locality = normalized_locality,
      category_slug = normalized_category
    where id = p_saved_search_id;
  exception
    when unique_violation then
      get stacked diagnostics violation_constraint = constraint_name;
      if violation_constraint =
        'resource_saved_searches_profile_filters_unique_idx' then
        raise exception using
          errcode = 'PT409',
          message = 'That resource saved search already exists.';
      end if;
      raise;
  end;

  return p_saved_search_id;
end;
$$;

revoke all on function public.update_resource_saved_search_v2(uuid, uuid, text, text, text, text) from public, anon, authenticated, service_role;

grant execute on function public.update_resource_saved_search_v2(uuid, uuid, text, text, text, text) to authenticated;

create function public.get_own_resource_saved_search_v2(
  p_expected_profile_id uuid,
  p_saved_search_id uuid
)
returns table (
  saved_search_id uuid,
  query text,
  listing_mode text,
  category_slug text,
  locality text,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_resource_listing_identity(
    p_expected_profile_id
  );
begin
  return query
  select
    saved_search.id,
    saved_search.query,
    saved_search.listing_mode,
    saved_search.category_slug,
    saved_search.locality,
    saved_search.created_at,
    saved_search.updated_at
  from public.resource_saved_searches as saved_search
  where saved_search.id = p_saved_search_id
    and saved_search.profile_id = current_profile_id;
end;
$$;

revoke all on function public.get_own_resource_saved_search_v2(uuid, uuid) from public, anon, authenticated, service_role;

grant execute on function public.get_own_resource_saved_search_v2(uuid, uuid) to authenticated;

create function public.list_own_resource_saved_searches_v2(
  p_expected_profile_id uuid,
  p_limit integer default 20,
  p_cursor_updated_at timestamptz default null,
  p_cursor_id uuid default null
)
returns table (
  saved_search_id uuid,
  query text,
  listing_mode text,
  category_slug text,
  locality text,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_resource_listing_identity(
    p_expected_profile_id
  );
begin
  if p_limit is null or p_limit not between 1 and 50 then
    raise exception using
      errcode = '22023',
      message = 'Resource saved-search page size must be between 1 and 50.';
  end if;

  if (p_cursor_updated_at is null) <> (p_cursor_id is null) then
    raise exception using
      errcode = '22023',
      message = 'Resource saved-search cursor values must be supplied together.';
  end if;

  return query
  select
    saved_search.id,
    saved_search.query,
    saved_search.listing_mode,
    saved_search.category_slug,
    saved_search.locality,
    saved_search.created_at,
    saved_search.updated_at
  from public.resource_saved_searches as saved_search
  where saved_search.profile_id = current_profile_id
    and (
      p_cursor_updated_at is null
      or (saved_search.updated_at, saved_search.id)
        < (p_cursor_updated_at, p_cursor_id)
    )
  order by saved_search.updated_at desc, saved_search.id desc
  limit p_limit;
end;
$$;

revoke all on function public.list_own_resource_saved_searches_v2(uuid, integer, timestamptz, uuid) from public, anon, authenticated, service_role;

grant execute on function public.list_own_resource_saved_searches_v2(uuid, integer, timestamptz, uuid) to authenticated;

-- Legacy saved-search readers return only definitions their filter tuple can represent.

create or replace function public.get_own_resource_saved_search(
  p_expected_profile_id uuid,
  p_saved_search_id uuid
)
returns table (
  saved_search_id uuid,
  query text,
  listing_mode text,
  locality text,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_resource_listing_identity(
    p_expected_profile_id
  );
begin
  return query
  select
    saved_search.id,
    saved_search.query,
    saved_search.listing_mode,
    saved_search.locality,
    saved_search.created_at,
    saved_search.updated_at
  from public.resource_saved_searches as saved_search
  where saved_search.id = p_saved_search_id
    and saved_search.profile_id = current_profile_id
    and saved_search.category_slug is null;
end;
$$;

-- Legacy saved-search readers return only definitions their filter tuple can represent.

create or replace function public.list_own_resource_saved_searches(
  p_expected_profile_id uuid,
  p_limit integer default 20,
  p_cursor_updated_at timestamptz default null,
  p_cursor_id uuid default null
)
returns table (
  saved_search_id uuid,
  query text,
  listing_mode text,
  locality text,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_resource_listing_identity(
    p_expected_profile_id
  );
begin
  if p_limit is null or p_limit not between 1 and 50 then
    raise exception using
      errcode = '22023',
      message = 'Resource saved-search page size must be between 1 and 50.';
  end if;

  if (p_cursor_updated_at is null) <> (p_cursor_id is null) then
    raise exception using
      errcode = '22023',
      message = 'Resource saved-search cursor values must be supplied together.';
  end if;

  return query
  select
    saved_search.id,
    saved_search.query,
    saved_search.listing_mode,
    saved_search.locality,
    saved_search.created_at,
    saved_search.updated_at
  from public.resource_saved_searches as saved_search
  where saved_search.profile_id = current_profile_id
    and saved_search.category_slug is null
    and (
      p_cursor_updated_at is null
      or (saved_search.updated_at, saved_search.id)
        < (p_cursor_updated_at, p_cursor_id)
    )
  order by saved_search.updated_at desc, saved_search.id desc
  limit p_limit;
end;
$$;

-- Keep the seven-argument legacy predicate; only current projection callers use v2.
create function private.resource_listing_matches_saved_search_filters_v2(
  p_listing_mode text, p_listing_title text, p_listing_description text,
  p_listing_locality text, p_saved_listing_mode text, p_saved_query text,
  p_saved_locality text, p_listing_category text, p_saved_category text
) returns boolean language sql immutable security definer set search_path = '' as $$
  select private.resource_listing_matches_saved_search_filters(
    p_listing_mode, p_listing_title, p_listing_description, p_listing_locality,
    p_saved_listing_mode, p_saved_query, p_saved_locality
  ) and coalesce(p_saved_category is null or p_listing_category = p_saved_category, false)
$$;

revoke all on function private.resource_listing_matches_saved_search_filters_v2(text, text, text, text, text, text, text, text, text) from public, anon, authenticated, service_role;

-- Preserve chronology, version tokens, suppression, identifiers and delivery deduplication.

create or replace function public.process_resource_saved_search_matching_outbox_batch(
  p_limit integer default 100
)
returns table (
  processed_count integer,
  matches_created integer,
  matches_suppressed integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  source_event private.outbox_events%rowtype;
  listing public.resource_listings%rowtype;
  saved_search public.resource_saved_searches%rowtype;
  new_match_id uuid;
  v_processed_count integer := 0;
  v_matches_created integer := 0;
  v_matches_suppressed integer := 0;
begin
  if p_limit is null or p_limit not between 1 and 100 then
    raise exception using
      errcode = '22023',
      message = 'Saved-search matching projector batch size must be between 1 and 100.';
  end if;

  for source_event in
    select event.*
    from private.outbox_events as event
    where event.event_type = 'resource_listing.published'
      and event.available_at <= statement_timestamp()
      and not exists (
        select 1
        from private.outbox_consumer_receipts as receipt
        where receipt.outbox_event_id = event.id
          and receipt.consumer_key = 'saved-search-matching.v1'
      )
    order by event.created_at, event.id
    limit p_limit
    for update of event skip locked
  loop
    select canonical_listing.* into listing
    from public.resource_listings as canonical_listing
    where canonical_listing.id = (source_event.payload ->> 'listing_id')::uuid
    for share of canonical_listing;

    if listing.id is null
      or (source_event.payload ->> 'owner_profile_id')::uuid
        is distinct from listing.owner_profile_id
      or source_event.payload ->> 'listing_mode'
        is distinct from listing.listing_mode then
      raise exception using
        errcode = '55000',
        message = format(
          'Saved-search matching could not validate outbox event %s against its canonical resource listing.',
          source_event.id
        );
    end if;

    if listing.lifecycle_state = 'published' then
      for saved_search in
        select candidate.*
        from public.resource_saved_searches as candidate
        where candidate.updated_at <= source_event.created_at
        order by candidate.id
        for share of candidate
      loop
        if saved_search.profile_id = listing.owner_profile_id
          or not private.resource_listing_matches_saved_search_filters_v2(
            listing.listing_mode,
            listing.title,
            listing.description,
            listing.locality,
            saved_search.listing_mode,
            saved_search.query,
            saved_search.locality,
      listing.category_slug,
      saved_search.category_slug
          ) then
          v_matches_suppressed := v_matches_suppressed + 1;
          continue;
        end if;

        new_match_id := null;

        insert into private.resource_saved_search_listing_matches (
          source_outbox_event_id,
          saved_search_id,
          saved_search_updated_at,
          recipient_profile_id,
          listing_id,
          matched_at
        )
        values (
          source_event.id,
          saved_search.id,
          saved_search.updated_at,
          saved_search.profile_id,
          listing.id,
          source_event.created_at
        )
        on conflict do nothing
        returning id into new_match_id;

        if new_match_id is null then
          v_matches_suppressed := v_matches_suppressed + 1;
          continue;
        end if;

        insert into private.outbox_events (
          event_type,
          payload,
          created_at,
          available_at
        )
        values (
          'resource_saved_search.matched',
          jsonb_build_object(
            'saved_search_match_id', new_match_id,
            'saved_search_id', saved_search.id,
            'recipient_profile_id', saved_search.profile_id,
            'listing_id', listing.id
          ),
          source_event.created_at,
          source_event.created_at
        );

        v_matches_created := v_matches_created + 1;
      end loop;
    end if;

    insert into private.outbox_consumer_receipts (
      outbox_event_id,
      consumer_key,
      processed_at
    )
    values (
      source_event.id,
      'saved-search-matching.v1',
      statement_timestamp()
    )
    on conflict do nothing;

    v_processed_count := v_processed_count + 1;
  end loop;

  return query select
    v_processed_count,
    v_matches_created,
    v_matches_suppressed;
end;
$$;

-- Preserve chronology, version tokens, suppression, identifiers and delivery deduplication.

create or replace function private.resolve_saved_search_matching_notification_event(
  p_outbox_event_id uuid
)
returns table (
  category_slug text,
  notification_kind text,
  recipient_profile_id uuid,
  actor_profile_id uuid,
  project_id uuid,
  project_kind text,
  request_id uuid,
  membership_id uuid,
  chat_id uuid,
  message_id uuid,
  resource_listing_id uuid,
  resource_request_id uuid,
  resource_chat_id uuid,
  resource_chat_message_id uuid,
  resource_agreement_id uuid,
  resource_agreement_event_id uuid,
  destination_kind text,
  source_created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  source_event private.outbox_events%rowtype;
  match_fact private.resource_saved_search_listing_matches%rowtype;
  saved_search public.resource_saved_searches%rowtype;
  listing public.resource_listings%rowtype;
  payload_match_id uuid;
  payload_saved_search_id uuid;
  payload_recipient_profile_id uuid;
  payload_listing_id uuid;
begin
  select event.* into source_event
  from private.outbox_events as event
  where event.id = p_outbox_event_id
    and event.event_type = 'resource_saved_search.matched';

  if not found then
    raise exception using
      errcode = '55000',
      message = format(
        'Saved-search matching notification event %s is unavailable or unsupported.',
        p_outbox_event_id
      );
  end if;

  if jsonb_typeof(source_event.payload) is distinct from 'object'
    or (
      select count(*)
      from jsonb_object_keys(source_event.payload)
    ) <> 4
    or not source_event.payload ?& array[
      'saved_search_match_id',
      'saved_search_id',
      'recipient_profile_id',
      'listing_id'
    ] then
    raise exception using
      errcode = '55000',
      message = format(
        'Saved-search matching notification event %s has invalid identifier-only payload shape.',
        source_event.id
      );
  end if;

  begin
    payload_match_id :=
      (source_event.payload ->> 'saved_search_match_id')::uuid;
    payload_saved_search_id :=
      (source_event.payload ->> 'saved_search_id')::uuid;
    payload_recipient_profile_id :=
      (source_event.payload ->> 'recipient_profile_id')::uuid;
    payload_listing_id := (source_event.payload ->> 'listing_id')::uuid;
  exception
    when invalid_text_representation then
      raise exception using
        errcode = '55000',
        message = format(
          'Saved-search matching notification event %s has invalid identifiers.',
          source_event.id
        );
  end;

  if payload_match_id is null
    or payload_saved_search_id is null
    or payload_recipient_profile_id is null
    or payload_listing_id is null then
    raise exception using
      errcode = '55000',
      message = format(
        'Saved-search matching notification event %s has invalid identifiers.',
        source_event.id
      );
  end if;

  select fact.* into match_fact
  from private.resource_saved_search_listing_matches as fact
  where fact.id = payload_match_id;

  if not found then
    if exists (
      select 1
      from public.resource_saved_searches as current_search
      where current_search.id = payload_saved_search_id
    ) then
      raise exception using
        errcode = '55000',
        message = format(
          'Saved-search matching notification event %s references no canonical match fact for its current saved search.',
          source_event.id
        );
    end if;

    return;
  end if;

  if payload_saved_search_id is distinct from match_fact.saved_search_id
    or payload_recipient_profile_id
      is distinct from match_fact.recipient_profile_id
    or payload_listing_id is distinct from match_fact.listing_id
    or source_event.created_at is distinct from match_fact.matched_at then
    raise exception using
      errcode = '55000',
      message = format(
        'Saved-search matching notification event %s diverges from its canonical match fact.',
        source_event.id
      );
  end if;

  select current_search.* into saved_search
  from public.resource_saved_searches as current_search
  where current_search.id = match_fact.saved_search_id;

  select current_listing.* into listing
  from public.resource_listings as current_listing
  where current_listing.id = match_fact.listing_id;

  if saved_search.id is null
    or listing.id is null
    or saved_search.profile_id
      is distinct from match_fact.recipient_profile_id then
    raise exception using
      errcode = '55000',
      message = format(
        'Saved-search matching notification event %s has inconsistent canonical context.',
        source_event.id
      );
  end if;

  if saved_search.profile_id = listing.owner_profile_id then
    raise exception using
      errcode = '55000',
      message = format(
        'Saved-search matching notification event %s violates self-owner suppression.',
        source_event.id
      );
  end if;

  if saved_search.updated_at is distinct from match_fact.saved_search_updated_at
    or listing.lifecycle_state <> 'published'
    or not private.resource_listing_matches_saved_search_filters_v2(
      listing.listing_mode,
      listing.title,
      listing.description,
      listing.locality,
      saved_search.listing_mode,
      saved_search.query,
      saved_search.locality,
      listing.category_slug,
      saved_search.category_slug
    ) then
    return;
  end if;

  return query
  select
    'matching'::text,
    'matching_available'::text,
    match_fact.recipient_profile_id,
    null::uuid,
    null::uuid,
    null::text,
    null::uuid,
    null::uuid,
    null::uuid,
    null::uuid,
    match_fact.listing_id,
    null::uuid,
    null::uuid,
    null::uuid,
    null::uuid,
    null::uuid,
    'matching_result'::text,
    source_event.created_at;
end;
$$;

-- Category is tested before candidate caps/pagination, exclusively in Resource branches.

CREATE OR REPLACE FUNCTION private.geo_public_candidates_v1(p_query jsonb, p_reference timestamp with time zone, p_after_kind text, p_after_id uuid)
 RETURNS TABLE(kind text, item_id uuid)
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare v_center extensions.geography; v_box extensions.geometry;
begin
  if p_query->>'mode'='radius' then
    v_center:=extensions.st_setsrid(extensions.st_makepoint((p_query->>'longitude')::double precision,(p_query->>'latitude')::double precision),4326)::extensions.geography;
    return query
    (select 'one_time'::text, p.id from public.proposals p
    where p.lifecycle_state='published' and p.definition_phase='defined' and p.published_at<=p_reference
      and p.approximate_location is not null and p.selected_public_place is not null
      and private.valid_selected_place(p.selected_public_place)
      and p_query->'kinds' ? 'one_time'
      and (p_after_kind is null or ('one_time'::text,p.id)>(p_after_kind,p_after_id))
      and p.ends_at > p_reference - interval '24 hours' and p.ends_at > statement_timestamp() - interval '24 hours'
      and (p_query->>'proposal_locality' is null or lower(p.locality)=p_query->>'proposal_locality')
      and (p_query->>'proposal_keyword' is null or strpos(lower(p.title),p_query->>'proposal_keyword')>0 or strpos(lower(p.summary),p_query->>'proposal_keyword')>0 or strpos(lower(p.description),p_query->>'proposal_keyword')>0)
      and (jsonb_array_length(p_query->'proposal_skill_ids')=0 or exists(select 1 from public.proposal_skills s where s.proposal_id=p.id and s.skill_id in (select value::uuid from jsonb_array_elements_text(p_query->'proposal_skill_ids'))))
      and extensions.st_dwithin(p.approximate_location,v_center,(p_query->>'radius_m')::double precision)
    order by p.id limit 2001)
    union all
    (select 'recurring'::text, p.id from public.recurring_activities p
    where p.lifecycle_state='published' and p.published_at<=p_reference
      and p.approximate_location is not null and p.selected_public_place is not null
      and private.valid_selected_place(p.selected_public_place)
      and p_query->'kinds' ? 'recurring'
      and (p_after_kind is null or ('recurring'::text,p.id)>(p_after_kind,p_after_id))
      and (p_query->>'tavolo_locality' is null or lower(p.locality)=p_query->>'tavolo_locality')
      and extensions.st_dwithin(p.approximate_location,v_center,(p_query->>'radius_m')::double precision)
    order by p.id limit 2001)
    union all
    (select 'resource'::text, p.id from public.resource_listings p
    where p.lifecycle_state='published' and p.published_at<=p_reference
      and p.public_location is not null and p.selected_public_place is not null
      and private.valid_selected_place(p.selected_public_place)
      and p_query->'kinds' ? 'resource'
      and (p_after_kind is null or ('resource'::text,p.id)>(p_after_kind,p_after_id))
      and (p_query->>'resource_locality' is null or lower(p.locality)=p_query->>'resource_locality')
      and (p_query->>'resource_mode' is null or p.listing_mode=p_query->>'resource_mode')
      and (p_query->>'resource_category_slug' is null or p.category_slug=p_query->>'resource_category_slug')
      and (p_query->>'resource_keyword' is null or strpos(lower(p.title),p_query->>'resource_keyword')>0 or strpos(lower(p.description),p_query->>'resource_keyword')>0)
      and extensions.st_dwithin(p.public_location,v_center,(p_query->>'radius_m')::double precision)
    order by p.id limit 2001);
  else
    v_box:=extensions.st_makeenvelope((p_query->>'west')::double precision,(p_query->>'south')::double precision,(p_query->>'east')::double precision,(p_query->>'north')::double precision,4326);
    return query
    (select 'one_time'::text, p.id from public.proposals p
    where p.lifecycle_state='published' and p.definition_phase='defined' and p.published_at<=p_reference
      and p.approximate_location is not null and p.selected_public_place is not null
      and private.valid_selected_place(p.selected_public_place)
      and p_query->'kinds' ? 'one_time'
      and (p_after_kind is null or ('one_time'::text,p.id)>(p_after_kind,p_after_id))
      and p.ends_at > p_reference - interval '24 hours' and p.ends_at > statement_timestamp() - interval '24 hours'
      and (p_query->>'proposal_locality' is null or lower(p.locality)=p_query->>'proposal_locality')
      and (p_query->>'proposal_keyword' is null or strpos(lower(p.title),p_query->>'proposal_keyword')>0 or strpos(lower(p.summary),p_query->>'proposal_keyword')>0 or strpos(lower(p.description),p_query->>'proposal_keyword')>0)
      and (jsonb_array_length(p_query->'proposal_skill_ids')=0 or exists(select 1 from public.proposal_skills s where s.proposal_id=p.id and s.skill_id in (select value::uuid from jsonb_array_elements_text(p_query->'proposal_skill_ids'))))
      and (p.approximate_location::extensions.geometry) operator(extensions.&&) v_box
    order by p.id limit 2001)
    union all
    (select 'recurring'::text, p.id from public.recurring_activities p
    where p.lifecycle_state='published' and p.published_at<=p_reference
      and p.approximate_location is not null and p.selected_public_place is not null
      and private.valid_selected_place(p.selected_public_place)
      and p_query->'kinds' ? 'recurring'
      and (p_after_kind is null or ('recurring'::text,p.id)>(p_after_kind,p_after_id))
      and (p_query->>'tavolo_locality' is null or lower(p.locality)=p_query->>'tavolo_locality')
      and (p.approximate_location::extensions.geometry) operator(extensions.&&) v_box
    order by p.id limit 2001)
    union all
    (select 'resource'::text, p.id from public.resource_listings p
    where p.lifecycle_state='published' and p.published_at<=p_reference
      and p.public_location is not null and p.selected_public_place is not null
      and private.valid_selected_place(p.selected_public_place)
      and p_query->'kinds' ? 'resource'
      and (p_after_kind is null or ('resource'::text,p.id)>(p_after_kind,p_after_id))
      and (p_query->>'resource_locality' is null or lower(p.locality)=p_query->>'resource_locality')
      and (p_query->>'resource_mode' is null or p.listing_mode=p_query->>'resource_mode')
      and (p_query->>'resource_category_slug' is null or p.category_slug=p_query->>'resource_category_slug')
      and (p_query->>'resource_keyword' is null or strpos(lower(p.title),p_query->>'resource_keyword')>0 or strpos(lower(p.description),p_query->>'resource_keyword')>0)
      and (p.public_location::extensions.geometry) operator(extensions.&&) v_box
    order by p.id limit 2001);
  end if;
end;
$function$;

-- Optional JSON input only: existing response shape and null-category query hashes remain stable.

create or replace function public.search_public_geography_v1(
  p_query jsonb, p_limit integer default 20, p_cursor jsonb default null
) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare
  q jsonb; v_mode text; v_key text; v_reference timestamptz;
  v_reference_text text; v_after_kind text; v_after_id uuid;
  v_kinds jsonb; v_skills jsonb; v_candidates jsonb; v_rows jsonb; v_items jsonb;
  v_more boolean; v_next jsonb; v_last jsonb; k text; n double precision;
  v_south double precision; v_north double precision; v_west double precision; v_east double precision;
begin
  if p_query is null or jsonb_typeof(p_query)<>'object' or pg_column_size(p_query)>8192
    or p_limit is null or p_limit not between 1 and 50 then
    raise exception using errcode='22023',message='Geographic query must be an object <=8192 bytes; page size must be 1..50.';
  end if;
  if (p_query-array['mode','latitude','longitude','radius_m','south','west','north','east','kinds',
      'proposal_keyword','proposal_locality','proposal_skill_ids','tavolo_locality',
      'resource_keyword','resource_locality','resource_mode','resource_category_slug','reference_time'])<>'{}'::jsonb then
    raise exception using errcode='22023',message='Unsupported geographic query fields.';
  end if;
  v_mode:=p_query->>'mode';
  if v_mode is null or v_mode not in ('radius','bounds') then
    raise exception using errcode='22023',message='Geographic mode must be radius or bounds.';
  end if;
  if v_mode='radius' then
    if p_query ?| array['south','west','north','east'] then
      raise exception using errcode='22023',message='Radius and bounds inputs are mutually exclusive.';
    end if;
    foreach k in array array['latitude','longitude','radius_m'] loop
      if jsonb_typeof(p_query->k) is distinct from 'number' then
        raise exception using errcode='22023',message='Radius requires numeric latitude, longitude and radius_m.';
      end if;
      n:=(p_query->>k)::double precision;
      if (k='latitude' and not(n between -90 and 90))
        or (k='longitude' and not(n between -180 and 180))
        or (k='radius_m' and not(n between 1 and 100000)) then
        raise exception using errcode='22023',message='Invalid center or radius; radius_m must be 1..100000.';
      end if;
    end loop;
    q:=jsonb_build_object('mode',v_mode,'latitude',(p_query->>'latitude')::double precision,
      'longitude',(p_query->>'longitude')::double precision,'radius_m',(p_query->>'radius_m')::double precision);
  else
    if p_query ?| array['latitude','longitude','radius_m'] then
      raise exception using errcode='22023',message='Radius and bounds inputs are mutually exclusive.';
    end if;
    foreach k in array array['south','west','north','east'] loop
      if jsonb_typeof(p_query->k) is distinct from 'number' then
        raise exception using errcode='22023',message='Bounds require numeric south, west, north and east.';
      end if;
    end loop;
    v_south:=(p_query->>'south')::double precision; v_north:=(p_query->>'north')::double precision;
    v_west:=(p_query->>'west')::double precision; v_east:=(p_query->>'east')::double precision;
    if not(v_south between -85 and 85 and v_north between -85 and 85
      and v_west between -180 and 180 and v_east between -180 and 180
      and v_south<v_north and v_west<v_east and v_north-v_south<=4 and v_east-v_west<=4) then
      raise exception using errcode='22023',message='Invalid bounds: no poles/antimeridian; ordered spans must be >0 and <=4 degrees.';
    end if;
    if extensions.st_area(extensions.st_makeenvelope(v_west,v_south,v_east,v_north,4326)::extensions.geography)>50000000000 then
      raise exception using errcode='22023',message='Viewport exceeds 50000 square kilometers; narrow the area.';
    end if;
    q:=jsonb_build_object('mode',v_mode,'south',v_south,'west',v_west,'north',v_north,'east',v_east);
  end if;
  v_kinds:=coalesce(p_query->'kinds','["one_time","recurring","resource"]'::jsonb);
  if jsonb_typeof(v_kinds)<>'array' or jsonb_array_length(v_kinds) not between 1 and 3
    or exists(select 1 from jsonb_array_elements(v_kinds) x where jsonb_typeof(x)<>'string' or x#>>'{}' not in ('one_time','recurring','resource')) then
    raise exception using errcode='22023',message='Kinds must contain 1..3 supported families.';
  end if;
  select jsonb_agg(x order by x) into v_kinds from (select distinct value x from jsonb_array_elements_text(v_kinds)) s;
  v_skills:=coalesce(p_query->'proposal_skill_ids','[]'::jsonb);
  if jsonb_typeof(v_skills)<>'array' or jsonb_array_length(v_skills)>20
    or exists(select 1 from jsonb_array_elements(v_skills) x where jsonb_typeof(x)<>'string'
      or (x#>>'{}')!~*'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') then
    raise exception using errcode='22023',message='Proposal skills must contain at most 20 UUID strings.';
  end if;
  select coalesce(jsonb_agg(x order by x),'[]'::jsonb) into v_skills from (select distinct value::uuid x from jsonb_array_elements_text(v_skills)) s;
  q:=q||jsonb_build_object('kinds',v_kinds,'proposal_skill_ids',v_skills);
  foreach k in array array['proposal_keyword','proposal_locality','tavolo_locality','resource_keyword','resource_locality','resource_mode','resource_category_slug'] loop
    if p_query ? k and p_query->k<>'null'::jsonb and
      (jsonb_typeof(p_query->k)<>'string' or char_length(p_query->>k)>120 or (p_query->>k)~'[[:cntrl:]]') then
      raise exception using errcode='22023',message='Geographic filters must be strings <=120 characters without controls.';
    end if;
    q:=q||jsonb_build_object(k,nullif(lower(btrim(p_query->>k)),''));
  end loop;
  if q->>'resource_mode' is not null and q->>'resource_mode' not in ('donate','exchange') then
    raise exception using errcode='22023',message='Resource mode must be donate or exchange.';
  end if;
  if q->>'resource_category_slug' is not null then
    q := q || jsonb_build_object('resource_category_slug',
      private.normalize_resource_category_slug(q->>'resource_category_slug'));
  end if;
  if p_cursor is not null then
    if jsonb_typeof(p_cursor)<>'object' or pg_column_size(p_cursor)>1024
      or p_cursor-array['query_key','reference_time','kind','item_id']<>'{}'::jsonb
      or not(p_cursor ?& array['query_key','reference_time','kind','item_id'])
      or coalesce(p_cursor->>'query_key','')!~'^[0-9a-f]{64}$'
      or coalesce(p_cursor->>'kind','') not in ('one_time','recurring','resource')
      or coalesce(p_cursor->>'item_id','')!~*'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      or exists(select 1 from jsonb_each(p_cursor) x where jsonb_typeof(x.value)<>'string') then
      raise exception using errcode='22023',message='Malformed geographic cursor.';
    end if;
    v_after_kind:=p_cursor->>'kind'; v_after_id:=(p_cursor->>'item_id')::uuid;
  end if;
  if p_query ? 'reference_time' and jsonb_typeof(p_query->'reference_time')<>'string' then
    raise exception using errcode='22023',message='Reference time must be an ISO timestamp.';
  end if;
  v_reference:=coalesce(p_query->>'reference_time',p_cursor->>'reference_time',statement_timestamp()::text)::timestamptz;
  if not isfinite(v_reference) or v_reference<statement_timestamp()-interval '15 minutes'
    or v_reference>statement_timestamp()+interval '1 minute' then
    raise exception using errcode='22023',message='Reference time expired or future; refresh geographic search.';
  end if;
  v_reference_text:=to_char(v_reference at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"');
  q:=jsonb_strip_nulls(q||jsonb_build_object('reference_time',v_reference_text));
  v_key:=encode(extensions.digest(q::text,'sha256'),'hex');
  if p_cursor is not null and (p_cursor->>'query_key'<>v_key
    or (p_cursor->>'reference_time')::timestamptz<>v_reference
    or not(v_kinds ? v_after_kind)) then
    raise exception using errcode='22023',message='Cursor does not belong to this geographic query; refresh.';
  end if;

  select coalesce(jsonb_agg(to_jsonb(c)),'[]'::jsonb) into v_candidates
    from private.geo_public_candidates_v1(q,v_reference,v_after_kind,v_after_id) c;
  if jsonb_array_length(v_candidates)>2000 then
    raise exception using errcode='54000',message='More than 2000 spatial candidates; narrow the area or filters.';
  end if;
  with ids as materialized (select * from jsonb_to_recordset(v_candidates) as x(kind text,item_id uuid)),
  cards as (
    select 'one_time'::text kind,p.id item_id,p.approximate_location point,p.selected_public_place place,
      p.title,cover.object_path cover_object_path,p.starts_at,p.ends_at,p.event_timezone,
      private.derive_proposal_status(p.starts_at,p.ends_at,v_reference) derived_status,null::text listing_mode
    from ids join public.proposals p on ids.kind='one_time' and p.id=ids.item_id
    left join public.project_covers cover on cover.project_id=p.id
    union all
    select 'recurring',p.id,p.approximate_location,p.selected_public_place,p.title,cover.object_path,
      occurrence.starts_at,occurrence.ends_at,occurrence.event_timezone,null::text,null::text
    from ids join public.recurring_activities p on ids.kind='recurring' and p.id=ids.item_id
    cross join lateral private.next_recurring_activity_occurrence(p.id,v_reference) occurrence
    left join public.project_covers cover on cover.project_id=p.id
    union all
    select 'resource',p.id,p.public_location,p.selected_public_place,p.title,cover.object_path,
      null::timestamptz,null::timestamptz,null::text,null::text,p.listing_mode
    from ids join public.resource_listings p on ids.kind='resource' and p.id=ids.item_id
    left join public.resource_listing_covers cover on cover.listing_id=p.id
  ), page as (select * from cards order by kind,item_id limit p_limit+1)
  select coalesce(jsonb_agg(jsonb_build_object(
    'kind',kind,'item_id',item_id,'latitude',extensions.st_y(point::extensions.geometry),
    'longitude',extensions.st_x(point::extensions.geometry),'precision',place->>'kind',
    'is_approximate',place->>'kind'='locality',
    'match_precision',case when place->>'kind'='locality' then 'locality_reference' else 'public_point' end,
    'title',title,'cover_object_path',cover_object_path,'public_location_label',place->>'label',
    'starts_at',starts_at,'ends_at',ends_at,'event_timezone',event_timezone,
    'derived_status',derived_status,'listing_mode',listing_mode) order by kind,item_id),'[]'::jsonb)
    into v_rows from page;
  v_more:=jsonb_array_length(v_rows)>p_limit;
  select coalesce(jsonb_agg(value order by ordinality),'[]'::jsonb) into v_items
    from jsonb_array_elements(v_rows) with ordinality where ordinality<=p_limit;
  if v_more then
    v_last:=v_items->(p_limit-1);
    v_next:=jsonb_build_object('query_key',v_key,'reference_time',v_reference_text,
      'kind',v_last->>'kind','item_id',v_last->>'item_id');
  end if;
  return jsonb_build_object('query_key',v_key,'reference_time',v_reference_text,'items',v_items,
    'has_more',v_more,'next_cursor',v_next,'attribution',jsonb_build_object(
      'geoapify_url','https://www.geoapify.com/','openstreetmap_url','https://www.openstreetmap.org/copyright'));
exception when invalid_text_representation or invalid_datetime_format or datetime_field_overflow or numeric_value_out_of_range then
  raise exception using errcode='22023',message='Malformed geographic coordinates, filters, cursor or reference time.';
end;
$$;

comment on function public.list_public_resource_listings_v2(integer,timestamptz,uuid,text,text,text,text) is
  'Category-aware successor to the unchanged legacy listing read; conjunctive filters run before the paired published_at/id keyset limit.';
comment on function public.search_public_geography_v1(jsonb,integer,jsonb) is
  'Public bounded geographic discovery; optional resource_category_slug filters Resource candidates only, including All-family queries. Null/absent category preserves legacy query identity.';
