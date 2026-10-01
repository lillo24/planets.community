create table public.resource_listing_requests (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null
    constraint resource_listing_requests_listing_id_fkey
      references public.resource_listings (id) on delete restrict,
  requester_profile_id uuid not null
    constraint resource_listing_requests_requester_profile_id_fkey
      references public.profiles (id) on delete restrict,
  status text not null default 'pending'
    constraint resource_listing_requests_status_valid check (
      status in (
        'pending',
        'accepted',
        'rejected',
        'withdrawn',
        'listing_closed'
      )
    ),
  request_message text
    constraint resource_listing_requests_message_valid check (
      request_message is null
      or (
        request_message = btrim(request_message)
        and char_length(request_message) between 1 and 500
      )
    ),
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  resolved_by_profile_id uuid
    constraint resource_listing_requests_resolved_by_profile_id_fkey
      references public.profiles (id) on delete restrict,
  constraint resource_listing_requests_resolution_valid check (
    (
      status = 'pending'
      and resolved_at is null
      and resolved_by_profile_id is null
    )
    or (
      status <> 'pending'
      and resolved_at is not null
      and resolved_by_profile_id is not null
      and resolved_at >= created_at
    )
  )
);

comment on table public.resource_listing_requests is
  'Private episode-based interest requests for published Scambio-Dona listings; accepted means willingness to coordinate, not reservation, handoff, or completion.';
comment on column public.resource_listing_requests.status is
  'Request decision state: pending, accepted, rejected, withdrawn, or listing_closed. Accepted remains active interest and does not reserve the listing.';
comment on column public.resource_listing_requests.request_message is
  'Optional private initial context visible only through requester/owner RPCs; never project it into public reads or events.';
comment on column public.resource_listing_requests.resolved_by_profile_id is
  'Profile that made the terminal 04C4A request decision: owner for accepted/rejected/listing_closed, requester for withdrawn.';

create unique index resource_listing_requests_active_requester_listing_idx
  on public.resource_listing_requests (listing_id, requester_profile_id)
  where status in ('pending', 'accepted');

create index resource_listing_requests_listing_created_at_id_idx
  on public.resource_listing_requests (listing_id, created_at desc, id desc);

create index resource_listing_requests_requester_created_at_id_idx
  on public.resource_listing_requests (
    requester_profile_id,
    created_at desc,
    id desc
  );

create index resource_listing_requests_resolved_by_profile_id_idx
  on public.resource_listing_requests (resolved_by_profile_id)
  where resolved_by_profile_id is not null;

alter table public.resource_listing_requests enable row level security;

revoke all privileges on table public.resource_listing_requests
  from public, anon, authenticated, service_role;

create function private.require_resource_listing_request_identity(
  p_expected_profile_id uuid,
  p_require_complete_profile boolean
)
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
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

  return current_profile_id;
end;
$$;

create function private.record_resource_listing_request_event(
  p_action text,
  p_request_id uuid,
  p_listing_id uuid,
  p_owner_profile_id uuid,
  p_requester_profile_id uuid,
  p_actor_profile_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  event_payload jsonb;
begin
  if p_action not in (
    'resource_listing.request_created',
    'resource_listing.request_accepted',
    'resource_listing.request_rejected',
    'resource_listing.request_withdrawn',
    'resource_listing.request_closed'
  ) then
    raise exception using
      errcode = '22023',
      message = 'Unsupported resource listing request event.';
  end if;

  event_payload := jsonb_build_object(
    'request_id', p_request_id,
    'listing_id', p_listing_id,
    'owner_profile_id', p_owner_profile_id,
    'requester_profile_id', p_requester_profile_id,
    'actor_profile_id', p_actor_profile_id
  );

  insert into private.audit_events (
    action,
    actor_user_id,
    target_type,
    target_id,
    metadata
  )
  values (
    p_action,
    p_actor_profile_id,
    'resource_listing_request',
    p_request_id,
    event_payload
  );

  insert into private.outbox_events (event_type, payload)
  values (p_action, event_payload);
end;
$$;

create function public.request_resource_listing(
  p_expected_requester_profile_id uuid,
  p_listing_id uuid,
  p_message text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_resource_listing_request_identity(
    p_expected_requester_profile_id,
    true
  );
  normalized_message text := nullif(btrim(p_message), '');
  listing public.resource_listings%rowtype;
  request_id uuid;
begin
  if normalized_message is not null
    and char_length(normalized_message) > 500 then
    raise exception using
      errcode = '22023',
      message = 'Resource listing request message must contain at most 500 characters.';
  end if;

  select * into listing
  from public.resource_listings
  where id = p_listing_id
  for update;

  if listing.id is null then
    raise exception using
      errcode = 'P0002',
      message = 'The resource listing does not exist.';
  end if;

  if listing.lifecycle_state <> 'published' then
    raise exception using
      errcode = '55000',
      message = 'Only a published resource listing can be requested.';
  end if;

  if listing.owner_profile_id = current_profile_id then
    raise exception using
      errcode = '22023',
      message = 'A listing owner cannot request their own resource listing.';
  end if;

  if exists (
    select 1
    from public.resource_listing_requests as existing_request
    where existing_request.listing_id = p_listing_id
      and existing_request.requester_profile_id = current_profile_id
      and existing_request.status in ('pending', 'accepted')
  ) then
    raise sqlstate 'PT409'
      using message = 'An active request already exists for this resource listing.';
  end if;

  insert into public.resource_listing_requests (
    listing_id,
    requester_profile_id,
    request_message
  )
  values (p_listing_id, current_profile_id, normalized_message)
  returning id into request_id;

  perform private.record_resource_listing_request_event(
    'resource_listing.request_created',
    request_id,
    listing.id,
    listing.owner_profile_id,
    current_profile_id,
    current_profile_id
  );

  return request_id;
end;
$$;

create function public.withdraw_resource_listing_request(
  p_expected_requester_profile_id uuid,
  p_request_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_resource_listing_request_identity(
    p_expected_requester_profile_id,
    false
  );
  request_listing_id uuid;
  listing public.resource_listings%rowtype;
  request public.resource_listing_requests%rowtype;
begin
  select candidate.listing_id into request_listing_id
  from public.resource_listing_requests as candidate
  where candidate.id = p_request_id;

  if request_listing_id is null then
    raise exception using
      errcode = 'P0002',
      message = 'The resource listing request does not exist.';
  end if;

  select * into listing
  from public.resource_listings
  where id = request_listing_id
  for update;

  select * into request
  from public.resource_listing_requests
  where id = p_request_id
  for update;

  if request.requester_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'Only the requester can withdraw this resource listing request.';
  end if;

  if request.status <> 'pending' then
    raise sqlstate 'PT409'
      using message = 'The resource listing request is no longer pending.';
  end if;

  update public.resource_listing_requests
  set
    status = 'withdrawn',
    resolved_at = statement_timestamp(),
    resolved_by_profile_id = current_profile_id
  where id = p_request_id;

  perform private.record_resource_listing_request_event(
    'resource_listing.request_withdrawn',
    request.id,
    listing.id,
    listing.owner_profile_id,
    request.requester_profile_id,
    current_profile_id
  );

  return p_request_id;
end;
$$;

create function public.accept_resource_listing_request(
  p_expected_owner_profile_id uuid,
  p_request_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_resource_listing_request_identity(
    p_expected_owner_profile_id,
    false
  );
  request_listing_id uuid;
  listing public.resource_listings%rowtype;
  request public.resource_listing_requests%rowtype;
begin
  select candidate.listing_id into request_listing_id
  from public.resource_listing_requests as candidate
  where candidate.id = p_request_id;

  if request_listing_id is null then
    raise exception using
      errcode = 'P0002',
      message = 'The resource listing request does not exist.';
  end if;

  select * into listing
  from public.resource_listings
  where id = request_listing_id
  for update;

  select * into request
  from public.resource_listing_requests
  where id = p_request_id
  for update;

  if listing.owner_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'Only the listing owner can accept this resource listing request.';
  end if;

  if request.status <> 'pending' then
    raise sqlstate 'PT409'
      using message = 'The resource listing request is no longer pending.';
  end if;

  update public.resource_listing_requests
  set
    status = 'accepted',
    resolved_at = statement_timestamp(),
    resolved_by_profile_id = current_profile_id
  where id = p_request_id;

  perform private.record_resource_listing_request_event(
    'resource_listing.request_accepted',
    request.id,
    listing.id,
    listing.owner_profile_id,
    request.requester_profile_id,
    current_profile_id
  );

  return p_request_id;
end;
$$;

create function public.reject_resource_listing_request(
  p_expected_owner_profile_id uuid,
  p_request_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_resource_listing_request_identity(
    p_expected_owner_profile_id,
    false
  );
  request_listing_id uuid;
  listing public.resource_listings%rowtype;
  request public.resource_listing_requests%rowtype;
begin
  select candidate.listing_id into request_listing_id
  from public.resource_listing_requests as candidate
  where candidate.id = p_request_id;

  if request_listing_id is null then
    raise exception using
      errcode = 'P0002',
      message = 'The resource listing request does not exist.';
  end if;

  select * into listing
  from public.resource_listings
  where id = request_listing_id
  for update;

  select * into request
  from public.resource_listing_requests
  where id = p_request_id
  for update;

  if listing.owner_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'Only the listing owner can reject this resource listing request.';
  end if;

  if request.status <> 'pending' then
    raise sqlstate 'PT409'
      using message = 'The resource listing request is no longer pending.';
  end if;

  update public.resource_listing_requests
  set
    status = 'rejected',
    resolved_at = statement_timestamp(),
    resolved_by_profile_id = current_profile_id
  where id = p_request_id;

  perform private.record_resource_listing_request_event(
    'resource_listing.request_rejected',
    request.id,
    listing.id,
    listing.owner_profile_id,
    request.requester_profile_id,
    current_profile_id
  );

  return p_request_id;
end;
$$;

create or replace function public.close_resource_listing(
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
  closed_request record;
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

  for closed_request in
    update public.resource_listing_requests
    set
      status = 'listing_closed',
      resolved_at = statement_timestamp(),
      resolved_by_profile_id = current_profile_id
    where listing_id = p_listing_id
      and status = 'pending'
    returning id, requester_profile_id
  loop
    perform private.record_resource_listing_request_event(
      'resource_listing.request_closed',
      closed_request.id,
      listing.id,
      listing.owner_profile_id,
      closed_request.requester_profile_id,
      current_profile_id
    );
  end loop;

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

drop function public.list_public_resource_listings(
  integer,
  timestamptz,
  uuid,
  text,
  text,
  text
);

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
        and request.status in ('pending', 'accepted')
    )
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

drop function public.get_public_resource_listing(uuid);

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
        and request.status in ('pending', 'accepted')
    )
  from public.resource_listings as listing
  join public.profiles as owner on owner.id = listing.owner_profile_id
  left join public.profile_field_visibility as display_visibility
    on display_visibility.profile_id = owner.id
    and display_visibility.field_key = 'display_name'
  where listing.id = p_listing_id
    and listing.lifecycle_state = 'published'
$$;

create function public.list_resource_listing_requests(
  p_expected_owner_profile_id uuid,
  p_listing_id uuid
)
returns table (
  request_id uuid,
  requester_profile_id uuid,
  requester_display_name text,
  status text,
  request_message text,
  created_at timestamptz,
  resolved_at timestamptz,
  resolved_by_profile_id uuid
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_resource_listing_request_identity(
    p_expected_owner_profile_id,
    false
  );
begin
  if not exists (
    select 1
    from public.resource_listings as listing
    where listing.id = p_listing_id
      and listing.owner_profile_id = current_profile_id
  ) then
    raise exception using
      errcode = '42501',
      message = 'The current user does not own this resource listing.';
  end if;

  return query
  select
    request.id,
    request.requester_profile_id,
    requester.display_name,
    request.status,
    request.request_message,
    request.created_at,
    request.resolved_at,
    request.resolved_by_profile_id
  from public.resource_listing_requests as request
  join public.profiles as requester
    on requester.id = request.requester_profile_id
  where request.listing_id = p_listing_id
  order by request.created_at desc, request.id desc;
end;
$$;

create function public.list_own_resource_listing_requests(
  p_expected_requester_profile_id uuid
)
returns table (
  request_id uuid,
  listing_id uuid,
  listing_mode text,
  listing_title text,
  listing_lifecycle text,
  owner_profile_id uuid,
  owner_display_name text,
  status text,
  request_message text,
  created_at timestamptz,
  resolved_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_resource_listing_request_identity(
    p_expected_requester_profile_id,
    false
  );
begin
  return query
  select
    request.id,
    listing.id,
    listing.listing_mode,
    listing.title,
    listing.lifecycle_state,
    listing.owner_profile_id,
    owner.display_name,
    request.status,
    request.request_message,
    request.created_at,
    request.resolved_at
  from public.resource_listing_requests as request
  join public.resource_listings as listing on listing.id = request.listing_id
  join public.profiles as owner on owner.id = listing.owner_profile_id
  where request.requester_profile_id = current_profile_id
  order by request.created_at desc, request.id desc;
end;
$$;

create function public.get_resource_listing_request(
  p_expected_profile_id uuid,
  p_request_id uuid
)
returns table (
  request_id uuid,
  listing_id uuid,
  listing_mode text,
  listing_title text,
  listing_lifecycle text,
  owner_profile_id uuid,
  owner_display_name text,
  requester_profile_id uuid,
  requester_display_name text,
  status text,
  request_message text,
  created_at timestamptz,
  resolved_at timestamptz,
  resolved_by_profile_id uuid
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_resource_listing_request_identity(
    p_expected_profile_id,
    false
  );
begin
  return query
  select
    request.id,
    listing.id,
    listing.listing_mode,
    listing.title,
    listing.lifecycle_state,
    listing.owner_profile_id,
    owner.display_name,
    request.requester_profile_id,
    requester.display_name,
    request.status,
    request.request_message,
    request.created_at,
    request.resolved_at,
    request.resolved_by_profile_id
  from public.resource_listing_requests as request
  join public.resource_listings as listing on listing.id = request.listing_id
  join public.profiles as owner on owner.id = listing.owner_profile_id
  join public.profiles as requester
    on requester.id = request.requester_profile_id
  where request.id = p_request_id
    and (
      request.requester_profile_id = current_profile_id
      or listing.owner_profile_id = current_profile_id
    );
end;
$$;

comment on function public.request_resource_listing(uuid, uuid, text) is
  'Creates one private pending interest request for a published listing after locking its lifecycle; accepted is not reservation or handoff.';
comment on function public.withdraw_resource_listing_request(uuid, uuid) is
  'Lets only the requester serialize a pending request to withdrawn.';
comment on function public.accept_resource_listing_request(uuid, uuid) is
  'Lets only the listing owner serialize a pending request to accepted without changing the listing or other requests.';
comment on function public.reject_resource_listing_request(uuid, uuid) is
  'Lets only the listing owner serialize a pending request to rejected.';
comment on function public.close_resource_listing(uuid, uuid) is
  'Terminally closes an own published listing and atomically closes only its pending requests; accepted history remains unchanged.';
comment on function public.list_public_resource_listings(integer, timestamptz, uuid, text, text, text) is
  'Returns published rough-location listings newest-first with filters and a derived pending-plus-accepted active interest count.';
comment on function public.get_public_resource_listing(uuid) is
  'Returns exact-ID published listing detail with visibility-sanitized owner display name and no request data beyond the active interest count.';
comment on function public.list_resource_listing_requests(uuid, uuid) is
  'Returns one listing owner private request history newest-first, including private initial messages.';
comment on function public.list_own_resource_listing_requests(uuid) is
  'Returns the expected requester private cross-listing request history newest-first.';
comment on function public.get_resource_listing_request(uuid, uuid) is
  'Returns one request only to its requester or canonical listing owner.';

revoke all privileges on function private.require_resource_listing_request_identity(uuid, boolean)
  from public, anon, authenticated, service_role;
revoke all privileges on function private.record_resource_listing_request_event(text, uuid, uuid, uuid, uuid, uuid)
  from public, anon, authenticated, service_role;

revoke all privileges on function public.request_resource_listing(uuid, uuid, text)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.withdraw_resource_listing_request(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.accept_resource_listing_request(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.reject_resource_listing_request(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.list_resource_listing_requests(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.list_own_resource_listing_requests(uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.get_resource_listing_request(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.list_public_resource_listings(integer, timestamptz, uuid, text, text, text)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.get_public_resource_listing(uuid)
  from public, anon, authenticated, service_role;

grant execute on function public.request_resource_listing(uuid, uuid, text)
  to authenticated;
grant execute on function public.withdraw_resource_listing_request(uuid, uuid)
  to authenticated;
grant execute on function public.accept_resource_listing_request(uuid, uuid)
  to authenticated;
grant execute on function public.reject_resource_listing_request(uuid, uuid)
  to authenticated;
grant execute on function public.list_resource_listing_requests(uuid, uuid)
  to authenticated;
grant execute on function public.list_own_resource_listing_requests(uuid)
  to authenticated;
grant execute on function public.get_resource_listing_request(uuid, uuid)
  to authenticated;
grant execute on function public.list_public_resource_listings(integer, timestamptz, uuid, text, text, text)
  to anon, authenticated;
grant execute on function public.get_public_resource_listing(uuid)
  to anon, authenticated;
