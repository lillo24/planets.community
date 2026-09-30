-- A read-time lexical matcher: no private reservation or persisted match state.
create index resource_listings_published_title_italian_fts_idx
  on public.resource_listings using gin (
    to_tsvector('italian'::regconfig, coalesce(title, ''))
  ) where lifecycle_state = 'published';

create index resource_listings_published_description_italian_fts_idx
  on public.resource_listings using gin (
    to_tsvector('italian'::regconfig, coalesce(description, ''))
  ) where lifecycle_state = 'published';

create index resource_listings_published_area_idx
  on public.resource_listings (
    country_code, lower(administrative_area), published_at desc, id desc
  ) where lifecycle_state = 'published';

create index resource_listings_published_country_idx
  on public.resource_listings (country_code, published_at desc, id desc)
  where lifecycle_state = 'published';

-- to_tsvector supplies escaped, stemmed, stopword-filtered lexemes. Render each
-- through plainto_tsquery before OR-combining; user text is never tsquery syntax.
create function private.project_resource_match_or_query(p_source text)
returns tsquery
language sql
immutable
security definer
set search_path = ''
as $$
  select string_agg(
    pg_catalog.plainto_tsquery('italian'::regconfig, lexeme)::text,
    ' | '
    order by lexeme
  )::tsquery
  from unnest(
    pg_catalog.tsvector_to_array(
      pg_catalog.to_tsvector('italian'::regconfig, coalesce(p_source, ''))
    )
  ) as words(lexeme);
$$;

create function private.evaluate_project_resource_listing_match(
  p_need_title text,
  p_need_details text,
  p_project_country_code text,
  p_project_locality text,
  p_project_administrative_area text,
  p_listing_title text,
  p_listing_description text,
  p_listing_country_code text,
  p_listing_locality text,
  p_listing_administrative_area text
)
returns table (is_match boolean, text_match_kind text, location_match_kind text)
language sql
immutable
security definer
set search_path = ''
as $$
  with source as (
    select
      pg_catalog.lower(pg_catalog.regexp_replace(
        pg_catalog.btrim(coalesce(p_need_title, '')), '\s+', ' ', 'g'
      )) as normalized_title,
      private.project_resource_match_or_query(p_need_title) as title_query,
      private.project_resource_match_or_query(p_need_details) as details_query,
      pg_catalog.to_tsvector('italian'::regconfig, coalesce(p_listing_title, ''))
        as listing_title_vector,
      pg_catalog.to_tsvector('italian'::regconfig, coalesce(p_listing_description, ''))
        as listing_description_vector
  ), reasons as (
    select
      case
        when source.normalized_title <> '' and pg_catalog.strpos(
          pg_catalog.lower(pg_catalog.regexp_replace(
            pg_catalog.btrim(coalesce(p_listing_title, '')), '\s+', ' ', 'g'
          )), source.normalized_title
        ) > 0 then 'title_phrase'
        when source.title_query is not null
          and source.listing_title_vector @@ source.title_query
          then 'need_title_in_listing_title'
        when source.title_query is not null
          and source.listing_description_vector @@ source.title_query
          then 'need_title_in_listing_description'
        when source.details_query is not null
          and source.listing_title_vector @@ source.details_query
          then 'need_details_in_listing_title'
        when source.details_query is not null
          and source.listing_description_vector @@ source.details_query
          then 'need_details_in_listing_description'
      end as text_kind,
      case
        when p_project_locality is not null
          and pg_catalog.lower(pg_catalog.btrim(p_listing_locality)) =
            pg_catalog.lower(pg_catalog.btrim(p_project_locality))
          then 'same_locality'
        when p_project_country_code is not null
          and p_listing_country_code = p_project_country_code
          and p_project_administrative_area is not null
          and pg_catalog.lower(pg_catalog.btrim(p_listing_administrative_area)) =
            pg_catalog.lower(pg_catalog.btrim(p_project_administrative_area))
          then 'same_administrative_area'
        when p_project_country_code is not null
          and p_listing_country_code = p_project_country_code
          then 'same_country'
        else 'other_or_unknown'
      end as location_kind
    from source
  )
  select reasons.text_kind is not null, reasons.text_kind, reasons.location_kind
  from reasons;
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

  if normalized_mode is not null and normalized_mode not in ('donate', 'exchange') then
    raise exception using errcode = '22023',
      message = 'Project resource matching mode must be donate or exchange.';
  end if;

  if num_nonnulls(
    p_cursor_text_match_kind, p_cursor_location_match_kind,
    p_cursor_published_at, p_cursor_listing_id
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
    select proposal.lifecycle_state, proposal.ends_at, proposal.country_code,
      proposal.locality, proposal.administrative_area
    into source_state, source_ends_at, source_country_code,
      source_locality, source_administrative_area
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
    select activity.lifecycle_state, activity.country_code,
      activity.locality, activity.administrative_area
    into source_state, source_country_code,
      source_locality, source_administrative_area
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
    or ((source_country_code is null or source_administrative_area is null)
      and p_location_scope = 'same_administrative_area')
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
    select listing.id, listing.published_at,
      reason.text_match_kind, reason.location_match_kind,
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
      resource_need.title, resource_need.details,
      source_country_code, source_locality, source_administrative_area,
      listing.title, listing.description,
      listing.country_code, listing.locality, listing.administrative_area
    ) as reason
    where listing.lifecycle_state = 'published'
      and (normalized_mode is null or listing.listing_mode = normalized_mode)
      and (
        (terms.normalized_title <> '' and pg_catalog.strpos(
          pg_catalog.lower(pg_catalog.regexp_replace(
            pg_catalog.btrim(listing.title), '\s+', ' ', 'g'
          )), terms.normalized_title
        ) > 0)
        or (terms.title_query is not null and (
          pg_catalog.to_tsvector('italian'::regconfig, coalesce(listing.title, ''))
            @@ terms.title_query
          or pg_catalog.to_tsvector('italian'::regconfig, coalesce(listing.description, ''))
            @@ terms.title_query
        ))
        or (terms.details_query is not null and (
          pg_catalog.to_tsvector('italian'::regconfig, coalesce(listing.title, ''))
            @@ terms.details_query
          or pg_catalog.to_tsvector('italian'::regconfig, coalesce(listing.description, ''))
            @@ terms.details_query
        ))
      )
      and reason.is_match
      and (p_location_scope = 'anywhere'
        or (p_location_scope = 'same_locality'
          and pg_catalog.lower(pg_catalog.btrim(listing.locality)) =
            pg_catalog.lower(pg_catalog.btrim(source_locality)))
        or (p_location_scope = 'same_administrative_area'
          and listing.country_code = source_country_code
          and pg_catalog.lower(pg_catalog.btrim(listing.administrative_area)) =
            pg_catalog.lower(pg_catalog.btrim(source_administrative_area)))
        or (p_location_scope = 'same_country'
          and listing.country_code = source_country_code))
  )
  select resource_need.id, candidate.id, public_listing.listing_mode,
    public_listing.title, public_listing.description,
    public_listing.country_code, public_listing.locality,
    public_listing.administrative_area,
    public_listing.public_location_label, candidate.published_at,
    public_listing.active_request_count,
    candidate.text_match_kind, candidate.location_match_kind
  from candidates as candidate
  -- Reuse the public detail projection verbatim, including its active-count rule.
  cross join lateral public.get_public_resource_listing(candidate.id) as public_listing
  where p_cursor_listing_id is null
    or candidate.text_rank > cursor_text_rank
    or (candidate.text_rank = cursor_text_rank
      and candidate.location_rank > cursor_location_rank)
    or (candidate.text_rank = cursor_text_rank
      and candidate.location_rank = cursor_location_rank
      and candidate.published_at < p_cursor_published_at)
    or (candidate.text_rank = cursor_text_rank
      and candidate.location_rank = cursor_location_rank
      and candidate.published_at = p_cursor_published_at
      and candidate.id < p_cursor_listing_id)
  order by candidate.text_rank, candidate.location_rank,
    candidate.published_at desc, candidate.id desc
  limit p_limit;
end;
$$;

comment on function public.list_project_resource_need_listing_matches(
  uuid, uuid, text, integer, text, text, text, timestamptz, uuid
) is 'Creator-only, read-time Italian lexical match of one open Project need to public published listings. Scope is explicit; reasons and full keyset are stable enums, not availability or confidence.';

revoke all on function private.project_resource_match_or_query(text)
  from public, anon, authenticated, service_role;
revoke all on function private.evaluate_project_resource_listing_match(
  text, text, text, text, text, text, text, text, text, text
) from public, anon, authenticated, service_role;
revoke all on function public.list_project_resource_need_listing_matches(
  uuid, uuid, text, integer, text, text, text, timestamptz, uuid
) from public, anon, authenticated, service_role;
grant execute on function public.list_project_resource_need_listing_matches(
  uuid, uuid, text, integer, text, text, text, timestamptz, uuid
) to authenticated;
