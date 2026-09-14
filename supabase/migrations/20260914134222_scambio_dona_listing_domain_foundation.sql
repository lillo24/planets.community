create table public.resource_listings (
  id uuid primary key default gen_random_uuid(),
  owner_profile_id uuid not null
    constraint resource_listings_owner_profile_id_fkey
      references public.profiles (id) on delete restrict,
  listing_mode text not null
    constraint resource_listings_listing_mode_valid check (
      listing_mode in ('donate', 'exchange')
    ),
  lifecycle_state text not null default 'draft'
    constraint resource_listings_lifecycle_state_valid check (
      lifecycle_state in ('draft', 'published', 'closed')
    ),
  title text
    constraint resource_listings_title_valid check (
      title is null
      or (title = btrim(title) and char_length(title) between 2 and 120)
    ),
  description text
    constraint resource_listings_description_valid check (
      description is null
      or (
        description = btrim(description)
        and char_length(description) between 1 and 5000
      )
    ),
  country_code text
    constraint resource_listings_country_code_valid check (
      country_code is null or country_code ~ '^[A-Z]{2}$'
    ),
  locality text
    constraint resource_listings_locality_valid check (
      locality is null
      or (locality = btrim(locality) and char_length(locality) between 1 and 120)
    ),
  administrative_area text
    constraint resource_listings_administrative_area_valid check (
      administrative_area is null
      or (
        administrative_area = btrim(administrative_area)
        and char_length(administrative_area) between 1 and 120
      )
    ),
  public_location_label text
    constraint resource_listings_public_location_label_valid check (
      public_location_label is null
      or (
        public_location_label = btrim(public_location_label)
        and char_length(public_location_label) between 1 and 180
      )
    ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  published_at timestamptz,
  closed_at timestamptz,
  constraint resource_listings_lifecycle_timestamps_valid check (
    (
      lifecycle_state = 'draft'
      and published_at is null
      and closed_at is null
    )
    or (
      lifecycle_state = 'published'
      and published_at is not null
      and closed_at is null
    )
    or (
      lifecycle_state = 'closed'
      and published_at is not null
      and closed_at is not null
      and closed_at >= published_at
    )
  )
);

comment on table public.resource_listings is
  'Owner-managed Scambio-Dona discovery listings with draft, published, and terminal closed lifecycle.';
comment on column public.resource_listings.listing_mode is
  'Discovery intent only: donate selects Dona and exchange selects Scambia; no transfer, loan, barter, payment, return, reservation, or handoff semantics are implied.';
comment on column public.resource_listings.public_location_label is
  'Owner-authored rough public location label; exact handoff and contact information do not belong in this domain.';
comment on column public.resource_listings.closed_at is
  'When the listing stopped being publicly available; closure does not assert a successful donation or exchange.';

create index resource_listings_owner_created_at_id_idx
  on public.resource_listings (owner_profile_id, created_at desc, id desc);

create index resource_listings_published_at_id_idx
  on public.resource_listings (published_at desc, id desc)
  where lifecycle_state = 'published';

create index resource_listings_published_mode_at_id_idx
  on public.resource_listings (listing_mode, published_at desc, id desc)
  where lifecycle_state = 'published';

create index resource_listings_published_locality_at_id_idx
  on public.resource_listings (
    lower(locality),
    published_at desc,
    id desc
  )
  where lifecycle_state = 'published';

create function private.set_resource_listing_updated_at()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger resource_listings_set_updated_at
before update on public.resource_listings
for each row
execute function private.set_resource_listing_updated_at();

alter table public.resource_listings enable row level security;

revoke all privileges on table public.resource_listings
  from public, anon, authenticated, service_role;

create function private.require_resource_listing_identity(
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

  return current_profile_id;
end;
$$;

create function private.require_complete_resource_listing_identity(
  p_expected_profile_id uuid
)
returns uuid
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
  if not exists (
    select 1
    from public.profiles as profile
    where profile.id = current_profile_id
      and profile.display_name is not null
  ) then
    raise exception using
      errcode = '55000',
      message = 'A complete profile is required to create or publish a resource listing.';
  end if;

  return current_profile_id;
end;
$$;

create function private.replace_resource_listing_content(
  p_listing_id uuid,
  p_listing_mode text,
  p_title text,
  p_description text,
  p_country_code text,
  p_locality text,
  p_administrative_area text,
  p_public_location_label text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
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

create function private.assert_resource_listing_publishable(
  p_listing_id uuid
)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  listing public.resource_listings%rowtype;
begin
  select * into listing
  from public.resource_listings
  where id = p_listing_id;

  if listing.id is null
    or listing.listing_mode not in ('donate', 'exchange')
    or listing.title is null
    or listing.description is null
    or listing.country_code is null
    or listing.locality is null
    or listing.public_location_label is null then
    raise exception using
      errcode = '22023',
      message = 'Published resource listings require a mode, title, description, country, locality, and public location label.';
  end if;
end;
$$;

create function public.create_resource_listing_draft(
  p_expected_owner_profile_id uuid,
  p_listing_mode text,
  p_title text,
  p_description text,
  p_country_code text,
  p_locality text,
  p_administrative_area text,
  p_public_location_label text
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

  perform private.replace_resource_listing_content(
    listing_id,
    normalized_listing_mode,
    p_title,
    p_description,
    p_country_code,
    p_locality,
    p_administrative_area,
    p_public_location_label
  );

  return listing_id;
end;
$$;

create function public.update_own_resource_listing(
  p_expected_owner_profile_id uuid,
  p_listing_id uuid,
  p_listing_mode text,
  p_title text,
  p_description text,
  p_country_code text,
  p_locality text,
  p_administrative_area text,
  p_public_location_label text
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

  perform private.replace_resource_listing_content(
    p_listing_id,
    p_listing_mode,
    p_title,
    p_description,
    p_country_code,
    p_locality,
    p_administrative_area,
    p_public_location_label
  );

  if listing.lifecycle_state = 'published' then
    perform private.assert_resource_listing_publishable(p_listing_id);
  end if;

  return p_listing_id;
end;
$$;

create function public.publish_resource_listing(
  p_expected_owner_profile_id uuid,
  p_listing_id uuid
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

  if listing.lifecycle_state = 'published' then
    return listing.id;
  end if;

  if listing.lifecycle_state <> 'draft' then
    raise exception using
      errcode = '55000',
      message = 'Only a draft resource listing can be published.';
  end if;

  perform private.assert_resource_listing_publishable(p_listing_id);

  update public.resource_listings
  set
    lifecycle_state = 'published',
    published_at = statement_timestamp()
  where id = p_listing_id;

  insert into private.audit_events (
    action,
    actor_user_id,
    target_type,
    target_id,
    metadata
  )
  values (
    'resource_listing.published',
    current_profile_id,
    'resource_listing',
    p_listing_id,
    jsonb_build_object('listing_mode', listing.listing_mode)
  );

  insert into private.outbox_events (event_type, payload)
  values (
    'resource_listing.published',
    jsonb_build_object(
      'listing_id', p_listing_id,
      'owner_profile_id', current_profile_id,
      'listing_mode', listing.listing_mode
    )
  );

  return p_listing_id;
end;
$$;

create function public.close_resource_listing(
  p_expected_owner_profile_id uuid,
  p_listing_id uuid
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

  if listing.lifecycle_state <> 'published' then
    raise exception using
      errcode = '55000',
      message = 'Only a published resource listing can be closed.';
  end if;

  update public.resource_listings
  set
    lifecycle_state = 'closed',
    closed_at = statement_timestamp()
  where id = p_listing_id;

  insert into private.audit_events (
    action,
    actor_user_id,
    target_type,
    target_id,
    metadata
  )
  values (
    'resource_listing.closed',
    current_profile_id,
    'resource_listing',
    p_listing_id,
    jsonb_build_object('listing_mode', listing.listing_mode)
  );

  insert into private.outbox_events (event_type, payload)
  values (
    'resource_listing.closed',
    jsonb_build_object(
      'listing_id', p_listing_id,
      'owner_profile_id', current_profile_id,
      'listing_mode', listing.listing_mode
    )
  );

  return p_listing_id;
end;
$$;

create function public.list_own_resource_listings(
  p_expected_owner_profile_id uuid
)
returns table (
  listing_id uuid,
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
  listing_mode text,
  title text,
  description text,
  country_code text,
  locality text,
  administrative_area text,
  public_location_label text,
  published_at timestamptz
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
    listing.listing_mode,
    listing.title,
    listing.description,
    listing.country_code,
    listing.locality,
    listing.administrative_area,
    listing.public_location_label,
    listing.published_at
  from public.resource_listings as listing
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

create function public.get_public_resource_listing(
  p_listing_id uuid
)
returns table (
  listing_id uuid,
  listing_mode text,
  title text,
  description text,
  country_code text,
  locality text,
  administrative_area text,
  public_location_label text,
  published_at timestamptz,
  owner_profile_id uuid,
  owner_display_name text
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    listing.id,
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
    end
  from public.resource_listings as listing
  join public.profiles as owner on owner.id = listing.owner_profile_id
  left join public.profile_field_visibility as display_visibility
    on display_visibility.profile_id = owner.id
    and display_visibility.field_key = 'display_name'
  where listing.id = p_listing_id
    and listing.lifecycle_state = 'published'
$$;

comment on function public.create_resource_listing_draft(uuid, text, text, text, text, text, text, text) is
  'Creates an incomplete-capable Scambio-Dona draft for the expected complete profile.';
comment on function public.update_own_resource_listing(uuid, uuid, text, text, text, text, text, text, text) is
  'Updates an own draft or published listing atomically; mode changes alter discovery intent only, and published content remains publishable.';
comment on function public.publish_resource_listing(uuid, uuid) is
  'Idempotently publishes a valid own draft and records identifier-only audit/outbox state.';
comment on function public.close_resource_listing(uuid, uuid) is
  'Terminally removes an own published listing from availability without asserting any transfer outcome.';
comment on function public.list_own_resource_listings(uuid) is
  'Returns the expected owner complete draft, published, and closed listing history.';
comment on function public.get_own_resource_listing(uuid, uuid) is
  'Returns one expected owner resource listing for management.';
comment on function public.list_public_resource_listings(integer, timestamptz, uuid, text, text, text) is
  'Returns published rough-location listings newest-first with paired keyset, mode, locality, and literal case-insensitive keyword filtering.';
comment on function public.get_public_resource_listing(uuid) is
  'Returns exact-ID published listing detail with visibility-sanitized owner display name.';

revoke all privileges on function private.set_resource_listing_updated_at()
  from public, anon, authenticated, service_role;
revoke all privileges on function private.require_resource_listing_identity(uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function private.require_complete_resource_listing_identity(uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function private.replace_resource_listing_content(uuid, text, text, text, text, text, text, text)
  from public, anon, authenticated, service_role;
revoke all privileges on function private.assert_resource_listing_publishable(uuid)
  from public, anon, authenticated, service_role;

revoke all privileges on function public.create_resource_listing_draft(uuid, text, text, text, text, text, text, text)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.update_own_resource_listing(uuid, uuid, text, text, text, text, text, text, text)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.publish_resource_listing(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.close_resource_listing(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.list_own_resource_listings(uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.get_own_resource_listing(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.list_public_resource_listings(integer, timestamptz, uuid, text, text, text)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.get_public_resource_listing(uuid)
  from public, anon, authenticated, service_role;

grant execute on function public.create_resource_listing_draft(uuid, text, text, text, text, text, text, text)
  to authenticated;
grant execute on function public.update_own_resource_listing(uuid, uuid, text, text, text, text, text, text, text)
  to authenticated;
grant execute on function public.publish_resource_listing(uuid, uuid)
  to authenticated;
grant execute on function public.close_resource_listing(uuid, uuid)
  to authenticated;
grant execute on function public.list_own_resource_listings(uuid)
  to authenticated;
grant execute on function public.get_own_resource_listing(uuid, uuid)
  to authenticated;
grant execute on function public.list_public_resource_listings(integer, timestamptz, uuid, text, text, text)
  to anon, authenticated;
grant execute on function public.get_public_resource_listing(uuid)
  to anon, authenticated;
