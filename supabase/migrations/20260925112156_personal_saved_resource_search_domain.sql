create table public.resource_saved_searches (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null
    constraint resource_saved_searches_profile_id_fkey
      references public.profiles (id) on delete cascade,
  query text
    constraint resource_saved_searches_query_valid check (
      query is null
      or (query = btrim(query) and char_length(query) between 1 and 120)
    ),
  listing_mode text
    constraint resource_saved_searches_listing_mode_valid check (
      listing_mode is null or listing_mode in ('donate', 'exchange')
    ),
  locality text
    constraint resource_saved_searches_locality_valid check (
      locality is null
      or (locality = btrim(locality) and char_length(locality) between 1 and 120)
    ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint resource_saved_searches_filter_present check (
    query is not null or listing_mode is not null or locality is not null
  ),
  constraint resource_saved_searches_timestamps_valid check (
    updated_at >= created_at
  )
);

comment on table public.resource_saved_searches is
  'Private per-profile saved definitions of current public Resource browse filters; results and notification behavior are not persisted.';
comment on column public.resource_saved_searches.query is
  'Optional canonical literal case-insensitive substring filter over listing title or description.';
comment on column public.resource_saved_searches.listing_mode is
  'Optional Dona/Scambia discovery filter: donate or exchange.';
comment on column public.resource_saved_searches.locality is
  'Optional canonical case-insensitive exact listing-locality filter.';

create unique index resource_saved_searches_profile_filters_unique_idx
  on public.resource_saved_searches (
    profile_id,
    lower(coalesce(query, '')),
    coalesce(listing_mode, ''),
    lower(coalesce(locality, ''))
  );

create index resource_saved_searches_profile_updated_at_id_idx
  on public.resource_saved_searches (profile_id, updated_at desc, id desc);

create function private.set_resource_saved_search_updated_at()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.updated_at := statement_timestamp();
  return new;
end;
$$;

create trigger resource_saved_searches_set_updated_at
before update on public.resource_saved_searches
for each row
execute function private.set_resource_saved_search_updated_at();

alter table public.resource_saved_searches enable row level security;

revoke all privileges on table public.resource_saved_searches
  from public, anon, authenticated, service_role;

create function private.resource_listing_matches_saved_search_filters(
  p_listing_mode text,
  p_listing_title text,
  p_listing_description text,
  p_listing_locality text,
  p_saved_listing_mode text,
  p_saved_query text,
  p_saved_locality text
)
returns boolean
language sql
immutable
security definer
set search_path = ''
as $$
  select coalesce((
    (
      p_saved_listing_mode is null
      or p_listing_mode = p_saved_listing_mode
    )
    and (
      p_saved_locality is null
      or pg_catalog.lower(p_listing_locality) = pg_catalog.lower(p_saved_locality)
    )
    and (
      p_saved_query is null
      or pg_catalog.strpos(
        pg_catalog.lower(coalesce(p_listing_title, '')),
        pg_catalog.lower(p_saved_query)
      ) > 0
      or pg_catalog.strpos(
        pg_catalog.lower(coalesce(p_listing_description, '')),
        pg_catalog.lower(p_saved_query)
      ) > 0
    )
  ), false)
$$;

create function public.create_resource_saved_search(
  p_expected_profile_id uuid,
  p_query text,
  p_listing_mode text,
  p_locality text
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
    and normalized_locality is null then
    raise exception using
      errcode = '22023',
      message = 'A resource saved search must contain at least one filter.';
  end if;

  begin
    insert into public.resource_saved_searches (
      profile_id,
      query,
      listing_mode,
      locality
    )
    values (
      current_profile_id,
      normalized_query,
      normalized_listing_mode,
      normalized_locality
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

create function public.update_resource_saved_search(
  p_expected_profile_id uuid,
  p_saved_search_id uuid,
  p_query text,
  p_listing_mode text,
  p_locality text
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
    and normalized_locality is null then
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
      locality = normalized_locality
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

create function public.delete_resource_saved_search(
  p_expected_profile_id uuid,
  p_saved_search_id uuid
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
  saved_search_profile_id uuid;
begin
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

  delete from public.resource_saved_searches
  where id = p_saved_search_id;

  return p_saved_search_id;
end;
$$;

create function public.get_own_resource_saved_search(
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
    and saved_search.profile_id = current_profile_id;
end;
$$;

create function public.list_own_resource_saved_searches(
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
    and (
      p_cursor_updated_at is null
      or (saved_search.updated_at, saved_search.id)
        < (p_cursor_updated_at, p_cursor_id)
    )
  order by saved_search.updated_at desc, saved_search.id desc
  limit p_limit;
end;
$$;

comment on function private.resource_listing_matches_saved_search_filters(
  text, text, text, text, text, text, text
) is 'Field-only saved-search predicate mirroring current Resource browse mode, literal substring, and exact-locality semantics; listing lifecycle remains the caller''s responsibility.';
comment on function public.create_resource_saved_search(uuid, text, text, text) is
  'Creates one private personal Resource browse-filter definition; semantic duplicates return PT409.';
comment on function public.update_resource_saved_search(uuid, uuid, text, text, text) is
  'Atomically replaces one owned saved-search definition after row locking; semantic duplicates return PT409.';
comment on function public.delete_resource_saved_search(uuid, uuid) is
  'Hard-deletes one owned personal Resource saved search after row locking.';
comment on function public.get_own_resource_saved_search(uuid, uuid) is
  'Returns one owned private Resource saved-search definition or no row.';
comment on function public.list_own_resource_saved_searches(
  uuid, integer, timestamptz, uuid
) is 'Returns private personal Resource saved searches newest-update first with a complete descending keyset.';

revoke all privileges on function private.set_resource_saved_search_updated_at()
  from public, anon, authenticated, service_role;
revoke all privileges on function private.resource_listing_matches_saved_search_filters(
  text, text, text, text, text, text, text
) from public, anon, authenticated, service_role;
revoke all privileges on function public.create_resource_saved_search(
  uuid, text, text, text
) from public, anon, authenticated, service_role;
revoke all privileges on function public.update_resource_saved_search(
  uuid, uuid, text, text, text
) from public, anon, authenticated, service_role;
revoke all privileges on function public.delete_resource_saved_search(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.get_own_resource_saved_search(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.list_own_resource_saved_searches(
  uuid, integer, timestamptz, uuid
) from public, anon, authenticated, service_role;

grant execute on function public.create_resource_saved_search(
  uuid, text, text, text
) to authenticated;
grant execute on function public.update_resource_saved_search(
  uuid, uuid, text, text, text
) to authenticated;
grant execute on function public.delete_resource_saved_search(uuid, uuid)
  to authenticated;
grant execute on function public.get_own_resource_saved_search(uuid, uuid)
  to authenticated;
grant execute on function public.list_own_resource_saved_searches(
  uuid, integer, timestamptz, uuid
) to authenticated;
