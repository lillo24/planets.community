alter table public.resource_listing_requests
  add column coordination_closed_at timestamptz,
  add column coordination_closed_by_profile_id uuid
    constraint resource_listing_requests_coordination_closed_by_fkey
      references public.profiles (id) on delete restrict;

alter table public.resource_listing_requests
  add constraint resource_listing_requests_coordination_close_valid check (
    (
      status = 'accepted'
      and (
        (
          coordination_closed_at is null
          and coordination_closed_by_profile_id is null
        )
        or (
          coordination_closed_at is not null
          and coordination_closed_by_profile_id is not null
          and coordination_closed_at >= resolved_at
        )
      )
    )
    or (
      status <> 'accepted'
      and coordination_closed_at is null
      and coordination_closed_by_profile_id is null
    )
  );

comment on column public.resource_listing_requests.coordination_closed_at is
  'When the accepted request stopped being active coordination because its separate agreement completed or was cancelled; request status remains accepted history.';
comment on column public.resource_listing_requests.coordination_closed_by_profile_id is
  'Counterparty whose cancellation or final milestone closed this accepted coordination episode.';

drop index public.resource_listing_requests_active_requester_listing_idx;

create unique index resource_listing_requests_active_requester_listing_idx
  on public.resource_listing_requests (listing_id, requester_profile_id)
  where status = 'pending'
    or (status = 'accepted' and coordination_closed_at is null);

create index resource_listing_requests_coordination_closed_by_profile_id_idx
  on public.resource_listing_requests (coordination_closed_by_profile_id)
  where coordination_closed_by_profile_id is not null;

create table public.resource_exchange_agreements (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null
    constraint resource_exchange_agreements_request_id_fkey
      references public.resource_listing_requests (id) on delete restrict,
  lifecycle_state text not null default 'negotiating'
    constraint resource_exchange_agreements_lifecycle_state_valid check (
      lifecycle_state in (
        'negotiating',
        'agreed',
        'in_progress',
        'completed',
        'cancelled'
      )
    ),
  current_terms_id uuid,
  pending_terms_id uuid,
  current_terms_accepted_at timestamptz,
  created_at timestamptz not null default now(),
  cancelled_at timestamptz,
  cancelled_by_profile_id uuid
    constraint resource_exchange_agreements_cancelled_by_profile_id_fkey
      references public.profiles (id) on delete restrict,
  completed_at timestamptz,
  constraint resource_exchange_agreements_request_id_key unique (request_id),
  constraint resource_exchange_agreements_current_acceptance_valid check (
    (current_terms_id is null and current_terms_accepted_at is null)
    or (
      current_terms_id is not null
      and current_terms_accepted_at is not null
      and current_terms_accepted_at >= created_at
    )
  ),
  constraint resource_exchange_agreements_lifecycle_shape_valid check (
    (
      lifecycle_state = 'negotiating'
      and current_terms_id is null
      and cancelled_at is null
      and cancelled_by_profile_id is null
      and completed_at is null
    )
    or (
      lifecycle_state = 'agreed'
      and current_terms_id is not null
      and cancelled_at is null
      and cancelled_by_profile_id is null
      and completed_at is null
    )
    or (
      lifecycle_state = 'in_progress'
      and current_terms_id is not null
      and pending_terms_id is null
      and cancelled_at is null
      and cancelled_by_profile_id is null
      and completed_at is null
    )
    or (
      lifecycle_state = 'completed'
      and current_terms_id is not null
      and pending_terms_id is null
      and cancelled_at is null
      and cancelled_by_profile_id is null
      and completed_at is not null
      and completed_at >= current_terms_accepted_at
    )
    or (
      lifecycle_state = 'cancelled'
      and pending_terms_id is null
      and cancelled_at is not null
      and cancelled_by_profile_id is not null
      and completed_at is null
      and cancelled_at >= created_at
    )
  )
);

comment on table public.resource_exchange_agreements is
  'Private coordination anchor created atomically for each accepted listing request; lifecycle completion/cancellation closes coordination without rewriting accepted request history.';
comment on column public.resource_exchange_agreements.lifecycle_state is
  'Agreement coordination lifecycle: negotiating, agreed, in_progress, completed, or cancelled.';
comment on column public.resource_exchange_agreements.current_terms_id is
  'Latest mutually accepted immutable terms version; terms may be replaced only before the first resource milestone.';
comment on column public.resource_exchange_agreements.pending_terms_id is
  'Current immutable proposal awaiting the other counterparty; a counter-proposal supersedes this pointer without deleting history.';

create table public.resource_exchange_agreement_terms (
  id uuid primary key default gen_random_uuid(),
  agreement_id uuid not null
    constraint resource_exchange_agreement_terms_agreement_id_fkey
      references public.resource_exchange_agreements (id) on delete restrict,
  version_number integer not null
    constraint resource_exchange_agreement_terms_version_positive check (
      version_number > 0
    ),
  proposed_by_profile_id uuid not null
    constraint resource_exchange_agreement_terms_proposer_fkey
      references public.profiles (id) on delete restrict,
  listing_title_snapshot text not null
    constraint resource_exchange_agreement_terms_title_valid check (
      listing_title_snapshot = btrim(listing_title_snapshot)
      and char_length(listing_title_snapshot) between 2 and 120
    ),
  listing_description_snapshot text not null
    constraint resource_exchange_agreement_terms_description_valid check (
      listing_description_snapshot = btrim(listing_description_snapshot)
      and char_length(listing_description_snapshot) between 1 and 5000
    ),
  owner_transfer_kind text not null
    constraint resource_exchange_agreement_terms_owner_kind_valid check (
      owner_transfer_kind in ('give', 'lend')
    ),
  owner_lend_starts_at timestamptz,
  owner_lend_ends_at timestamptz,
  requester_transfer_kind text not null
    constraint resource_exchange_agreement_terms_requester_kind_valid check (
      requester_transfer_kind in ('none', 'give', 'lend')
    ),
  requester_resource_description text,
  requester_lend_starts_at timestamptz,
  requester_lend_ends_at timestamptz,
  private_note text
    constraint resource_exchange_agreement_terms_private_note_valid check (
      private_note is null
      or (
        private_note = btrim(private_note)
        and char_length(private_note) between 1 and 1000
      )
    ),
  created_at timestamptz not null default now(),
  constraint resource_exchange_agreement_terms_agreement_version_key
    unique (agreement_id, version_number),
  constraint resource_exchange_agreement_terms_agreement_id_id_key
    unique (agreement_id, id),
  constraint resource_exchange_agreement_terms_owner_shape_valid check (
    (
      owner_transfer_kind = 'give'
      and owner_lend_starts_at is null
      and owner_lend_ends_at is null
    )
    or (
      owner_transfer_kind = 'lend'
      and owner_lend_starts_at is not null
      and owner_lend_ends_at is not null
      and owner_lend_ends_at > owner_lend_starts_at
    )
  ),
  constraint resource_exchange_agreement_terms_requester_shape_valid check (
    (
      requester_transfer_kind = 'none'
      and requester_resource_description is null
      and requester_lend_starts_at is null
      and requester_lend_ends_at is null
    )
    or (
      requester_transfer_kind = 'give'
      and requester_resource_description is not null
      and requester_resource_description = btrim(requester_resource_description)
      and char_length(requester_resource_description) between 2 and 500
      and requester_lend_starts_at is null
      and requester_lend_ends_at is null
    )
    or (
      requester_transfer_kind = 'lend'
      and requester_resource_description is not null
      and requester_resource_description = btrim(requester_resource_description)
      and char_length(requester_resource_description) between 2 and 500
      and requester_lend_starts_at is not null
      and requester_lend_ends_at is not null
      and requester_lend_ends_at > requester_lend_starts_at
    )
  )
);

comment on table public.resource_exchange_agreement_terms is
  'Immutable versioned two-leg Scambio terms with server-owned listing snapshots and no payment, contact, or exact-location fields.';
comment on column public.resource_exchange_agreement_terms.owner_transfer_kind is
  'Required listing-owner leg: give or bounded-period lend.';
comment on column public.resource_exchange_agreement_terms.requester_transfer_kind is
  'Optional counterparty leg: none, give, or bounded-period lend.';
comment on column public.resource_exchange_agreement_terms.private_note is
  'Optional private bounded agreement context; never exposed publicly or copied into identifier-only events.';

alter table public.resource_exchange_agreements
  add constraint resource_exchange_agreements_current_terms_fkey
    foreign key (id, current_terms_id)
      references public.resource_exchange_agreement_terms (agreement_id, id)
      on delete restrict,
  add constraint resource_exchange_agreements_pending_terms_fkey
    foreign key (id, pending_terms_id)
      references public.resource_exchange_agreement_terms (agreement_id, id)
      on delete restrict;

create table public.resource_exchange_agreement_events (
  id uuid primary key default gen_random_uuid(),
  agreement_id uuid not null
    constraint resource_exchange_agreement_events_agreement_id_fkey
      references public.resource_exchange_agreements (id) on delete restrict,
  terms_id uuid,
  event_kind text not null
    constraint resource_exchange_agreement_events_kind_valid check (
      event_kind in (
        'agreement_created',
        'terms_proposed',
        'terms_superseded',
        'terms_accepted',
        'terms_rejected',
        'terms_withdrawn',
        'resource_provided',
        'resource_received',
        'resource_returned',
        'resource_return_received',
        'agreement_cancelled',
        'agreement_completed'
      )
    ),
  leg_kind text
    constraint resource_exchange_agreement_events_leg_kind_valid check (
      leg_kind is null
      or leg_kind in ('owner_resource', 'requester_resource')
    ),
  actor_profile_id uuid not null
    constraint resource_exchange_agreement_events_actor_profile_id_fkey
      references public.profiles (id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint resource_exchange_agreement_events_agreement_terms_fkey
    foreign key (agreement_id, terms_id)
      references public.resource_exchange_agreement_terms (agreement_id, id)
      on delete restrict,
  constraint resource_exchange_agreement_events_shape_valid check (
    (
      event_kind = 'agreement_created'
      and terms_id is null
      and leg_kind is null
    )
    or (
      event_kind in (
        'terms_proposed',
        'terms_superseded',
        'terms_accepted',
        'terms_rejected',
        'terms_withdrawn',
        'agreement_completed'
      )
      and terms_id is not null
      and leg_kind is null
    )
    or (
      event_kind in (
        'resource_provided',
        'resource_received',
        'resource_returned',
        'resource_return_received'
      )
      and terms_id is not null
      and leg_kind is not null
    )
    or (
      event_kind = 'agreement_cancelled'
      and terms_id is null
      and leg_kind is null
    )
  )
);

comment on table public.resource_exchange_agreement_events is
  'Immutable structured counterparty timeline; milestones are user statements and not independent PLANETS verification of physical events.';

create index resource_exchange_agreements_cancelled_by_profile_id_idx
  on public.resource_exchange_agreements (cancelled_by_profile_id)
  where cancelled_by_profile_id is not null;
create index resource_exchange_agreement_terms_proposer_created_idx
  on public.resource_exchange_agreement_terms (
    proposed_by_profile_id,
    created_at desc,
    id desc
  );
create index resource_exchange_agreement_events_agreement_created_idx
  on public.resource_exchange_agreement_events (
    agreement_id,
    created_at,
    id
  );
create index resource_exchange_agreement_events_actor_created_idx
  on public.resource_exchange_agreement_events (
    actor_profile_id,
    created_at desc,
    id desc
  );

create unique index resource_exchange_agreement_events_milestone_key
  on public.resource_exchange_agreement_events (
    agreement_id,
    terms_id,
    leg_kind,
    event_kind
  )
  where event_kind in (
    'resource_provided',
    'resource_received',
    'resource_returned',
    'resource_return_received'
  );
create unique index resource_exchange_agreement_events_created_once_idx
  on public.resource_exchange_agreement_events (agreement_id)
  where event_kind = 'agreement_created';
create unique index resource_exchange_agreement_events_cancelled_once_idx
  on public.resource_exchange_agreement_events (agreement_id)
  where event_kind = 'agreement_cancelled';
create unique index resource_exchange_agreement_events_completed_once_idx
  on public.resource_exchange_agreement_events (agreement_id)
  where event_kind = 'agreement_completed';

alter table public.resource_exchange_agreements enable row level security;
alter table public.resource_exchange_agreement_terms enable row level security;
alter table public.resource_exchange_agreement_events enable row level security;

revoke all privileges on table public.resource_exchange_agreements
  from public, anon, authenticated, service_role;
revoke all privileges on table public.resource_exchange_agreement_terms
  from public, anon, authenticated, service_role;
revoke all privileges on table public.resource_exchange_agreement_events
  from public, anon, authenticated, service_role;

create function private.protect_resource_exchange_terms_immutability()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  raise exception using
    errcode = '55000',
    message = 'Resource exchange agreement terms are immutable.';
end;
$$;

create function private.protect_resource_exchange_events_immutability()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  raise exception using
    errcode = '55000',
    message = 'Resource exchange agreement events are immutable.';
end;
$$;

create trigger resource_exchange_agreement_terms_immutable
before update or delete on public.resource_exchange_agreement_terms
for each row execute function
  private.protect_resource_exchange_terms_immutability();

create trigger resource_exchange_agreement_events_immutable
before update or delete on public.resource_exchange_agreement_events
for each row execute function
  private.protect_resource_exchange_events_immutability();

create function private.record_resource_exchange_agreement_event(
  p_event_kind text,
  p_agreement_id uuid,
  p_terms_id uuid,
  p_leg_kind text,
  p_actor_profile_id uuid,
  p_created_at timestamptz default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  agreement_event_id uuid;
  request_id uuid;
  listing_id uuid;
  owner_profile_id uuid;
  requester_profile_id uuid;
  canonical_created_at timestamptz := coalesce(
    p_created_at,
    clock_timestamp()
  );
  external_event_type text;
  identifier_payload jsonb;
begin
  if p_event_kind not in (
    'agreement_created',
    'terms_proposed',
    'terms_superseded',
    'terms_accepted',
    'terms_rejected',
    'terms_withdrawn',
    'resource_provided',
    'resource_received',
    'resource_returned',
    'resource_return_received',
    'agreement_cancelled',
    'agreement_completed'
  ) then
    raise exception using
      errcode = '22023',
      message = 'Unsupported resource exchange agreement event.';
  end if;

  select
    request.id,
    request.listing_id,
    listing.owner_profile_id,
    request.requester_profile_id
  into
    request_id,
    listing_id,
    owner_profile_id,
    requester_profile_id
  from public.resource_exchange_agreements as agreement
  join public.resource_listing_requests as request
    on request.id = agreement.request_id
  join public.resource_listings as listing
    on listing.id = request.listing_id
  where agreement.id = p_agreement_id;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'The resource exchange agreement does not exist.';
  end if;

  insert into public.resource_exchange_agreement_events (
    agreement_id,
    terms_id,
    event_kind,
    leg_kind,
    actor_profile_id,
    created_at
  )
  values (
    p_agreement_id,
    p_terms_id,
    p_event_kind,
    p_leg_kind,
    p_actor_profile_id,
    canonical_created_at
  )
  returning id into agreement_event_id;

  external_event_type := case
    when p_event_kind in (
      'resource_provided',
      'resource_received',
      'resource_returned',
      'resource_return_received'
    ) then 'resource_exchange.milestone_recorded'
    else 'resource_exchange.' || p_event_kind
  end;

  identifier_payload := jsonb_strip_nulls(jsonb_build_object(
    'agreement_id', p_agreement_id,
    'request_id', request_id,
    'listing_id', listing_id,
    'owner_profile_id', owner_profile_id,
    'requester_profile_id', requester_profile_id,
    'terms_id', p_terms_id,
    'agreement_event_id', agreement_event_id,
    'actor_profile_id', p_actor_profile_id
  ));

  insert into private.audit_events (
    action,
    actor_user_id,
    target_type,
    target_id,
    metadata,
    created_at
  )
  values (
    external_event_type,
    p_actor_profile_id,
    'resource_exchange_agreement',
    p_agreement_id,
    identifier_payload,
    canonical_created_at
  );

  insert into private.outbox_events (
    event_type,
    payload,
    created_at,
    available_at
  )
  values (
    external_event_type,
    identifier_payload,
    canonical_created_at,
    canonical_created_at
  );

  return agreement_event_id;
end;
$$;

create function private.ensure_resource_exchange_agreement_for_request(
  p_request_id uuid,
  p_actor_profile_id uuid,
  p_created_at timestamptz default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  request public.resource_listing_requests%rowtype;
  agreement_id uuid;
  agreement_created boolean := false;
  canonical_created_at timestamptz;
begin
  select * into request
  from public.resource_listing_requests
  where id = p_request_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'The resource listing request does not exist.';
  end if;

  if request.status <> 'accepted' then
    raise exception using
      errcode = '55000',
      message = 'Only an accepted resource listing request can own an agreement.';
  end if;

  canonical_created_at := coalesce(
    p_created_at,
    request.resolved_at,
    statement_timestamp()
  );

  insert into public.resource_exchange_agreements (
    request_id,
    created_at
  )
  values (
    p_request_id,
    canonical_created_at
  )
  on conflict (request_id) do nothing
  returning id into agreement_id;

  agreement_created := found;

  if not agreement_created then
    select agreement.id into agreement_id
    from public.resource_exchange_agreements as agreement
    where agreement.request_id = p_request_id;
  end if;

  if agreement_created then
    perform private.record_resource_exchange_agreement_event(
      'agreement_created',
      agreement_id,
      null,
      null,
      p_actor_profile_id,
      canonical_created_at
    );
  end if;

  return agreement_id;
end;
$$;

do $$
declare
  accepted_request record;
begin
  for accepted_request in
    select
      request.id,
      coalesce(
        request.resolved_by_profile_id,
        listing.owner_profile_id
      ) as actor_profile_id,
      coalesce(request.resolved_at, request.created_at) as created_at
    from public.resource_listing_requests as request
    join public.resource_listings as listing on listing.id = request.listing_id
    where request.status = 'accepted'
    order by request.id
  loop
    perform private.ensure_resource_exchange_agreement_for_request(
      accepted_request.id,
      accepted_request.actor_profile_id,
      accepted_request.created_at
    );
  end loop;
end;
$$;

create or replace function public.accept_resource_listing_request(
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
  transition_time timestamptz := statement_timestamp();
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
    resolved_at = transition_time,
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

  perform private.ensure_resource_exchange_agreement_for_request(
    p_request_id,
    current_profile_id,
    transition_time
  );

  return p_request_id;
end;
$$;

create or replace function public.request_resource_listing(
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
      and (
        existing_request.status = 'pending'
        or (
          existing_request.status = 'accepted'
          and existing_request.coordination_closed_at is null
        )
      )
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

create or replace function public.list_public_resource_listings(
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
        and (
          request.status = 'pending'
          or (
            request.status = 'accepted'
            and request.coordination_closed_at is null
          )
        )
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

create or replace function public.get_public_resource_listing(
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
  where listing.id = p_listing_id
    and listing.lifecycle_state = 'published'
$$;

create function public.propose_resource_exchange_terms(
  p_expected_profile_id uuid,
  p_agreement_id uuid,
  p_expected_current_terms_id uuid,
  p_expected_pending_terms_id uuid,
  p_owner_transfer_kind text,
  p_owner_lend_starts_at timestamptz,
  p_owner_lend_ends_at timestamptz,
  p_requester_transfer_kind text,
  p_requester_resource_description text,
  p_requester_lend_starts_at timestamptz,
  p_requester_lend_ends_at timestamptz,
  p_private_note text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_resource_listing_request_identity(
    p_expected_profile_id,
    false
  );
  agreement public.resource_exchange_agreements%rowtype;
  request public.resource_listing_requests%rowtype;
  listing public.resource_listings%rowtype;
  normalized_owner_kind text := lower(nullif(btrim(p_owner_transfer_kind), ''));
  normalized_requester_kind text := lower(
    nullif(btrim(p_requester_transfer_kind), '')
  );
  normalized_requester_description text := nullif(
    btrim(p_requester_resource_description),
    ''
  );
  normalized_private_note text := nullif(btrim(p_private_note), '');
  next_version integer;
  old_pending_terms_id uuid;
  new_terms_id uuid;
begin
  select * into agreement
  from public.resource_exchange_agreements
  where id = p_agreement_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'The resource exchange agreement does not exist.';
  end if;

  select * into request
  from public.resource_listing_requests
  where id = agreement.request_id;

  select * into listing
  from public.resource_listings
  where id = request.listing_id;

  if current_profile_id not in (
    listing.owner_profile_id,
    request.requester_profile_id
  ) then
    raise exception using
      errcode = '42501',
      message = 'Only the agreement counterparties may propose terms.';
  end if;

  if agreement.current_terms_id is distinct from p_expected_current_terms_id
    or agreement.pending_terms_id is distinct from p_expected_pending_terms_id then
    raise sqlstate 'PT409'
      using message = 'The resource exchange agreement terms changed since they were loaded.';
  end if;

  if agreement.lifecycle_state not in ('negotiating', 'agreed')
    or exists (
      select 1
      from public.resource_exchange_agreement_events as event
      where event.agreement_id = agreement.id
        and event.event_kind in (
          'resource_provided',
          'resource_received',
          'resource_returned',
          'resource_return_received'
        )
    ) then
    raise sqlstate 'PT409'
      using message = 'Agreement terms are frozen after handoff begins or coordination closes.';
  end if;

  if normalized_owner_kind is null
    or normalized_owner_kind not in ('give', 'lend') then
    raise exception using
      errcode = '22023',
      message = 'Owner transfer kind must be give or lend.';
  end if;

  if normalized_owner_kind = 'give'
    and (
      p_owner_lend_starts_at is not null
      or p_owner_lend_ends_at is not null
    ) then
    raise exception using
      errcode = '22023',
      message = 'A give owner leg cannot contain lending dates.';
  end if;

  if normalized_owner_kind = 'lend'
    and (
      p_owner_lend_starts_at is null
      or p_owner_lend_ends_at is null
      or p_owner_lend_ends_at <= p_owner_lend_starts_at
    ) then
    raise exception using
      errcode = '22023',
      message = 'A lend owner leg requires a bounded increasing period.';
  end if;

  if normalized_requester_kind is null
    or normalized_requester_kind not in ('none', 'give', 'lend') then
    raise exception using
      errcode = '22023',
      message = 'Requester transfer kind must be none, give, or lend.';
  end if;

  if normalized_requester_kind = 'none'
    and (
      normalized_requester_description is not null
      or p_requester_lend_starts_at is not null
      or p_requester_lend_ends_at is not null
    ) then
    raise exception using
      errcode = '22023',
      message = 'A none requester leg cannot contain a resource or lending dates.';
  end if;

  if normalized_requester_kind in ('give', 'lend')
    and (
      normalized_requester_description is null
      or char_length(normalized_requester_description) not between 2 and 500
    ) then
    raise exception using
      errcode = '22023',
      message = 'A requester resource description must contain 2 to 500 characters.';
  end if;

  if normalized_requester_kind = 'give'
    and (
      p_requester_lend_starts_at is not null
      or p_requester_lend_ends_at is not null
    ) then
    raise exception using
      errcode = '22023',
      message = 'A give requester leg cannot contain lending dates.';
  end if;

  if normalized_requester_kind = 'lend'
    and (
      p_requester_lend_starts_at is null
      or p_requester_lend_ends_at is null
      or p_requester_lend_ends_at <= p_requester_lend_starts_at
    ) then
    raise exception using
      errcode = '22023',
      message = 'A lend requester leg requires a bounded increasing period.';
  end if;

  if normalized_private_note is not null
    and char_length(normalized_private_note) > 1000 then
    raise exception using
      errcode = '22023',
      message = 'A private agreement note must contain at most 1000 characters.';
  end if;

  if listing.title is null or listing.description is null then
    raise exception using
      errcode = '55000',
      message = 'The resource listing does not have publishable snapshot content.';
  end if;

  select coalesce(max(terms.version_number), 0) + 1
  into next_version
  from public.resource_exchange_agreement_terms as terms
  where terms.agreement_id = agreement.id;

  old_pending_terms_id := agreement.pending_terms_id;

  insert into public.resource_exchange_agreement_terms (
    agreement_id,
    version_number,
    proposed_by_profile_id,
    listing_title_snapshot,
    listing_description_snapshot,
    owner_transfer_kind,
    owner_lend_starts_at,
    owner_lend_ends_at,
    requester_transfer_kind,
    requester_resource_description,
    requester_lend_starts_at,
    requester_lend_ends_at,
    private_note
  )
  values (
    agreement.id,
    next_version,
    current_profile_id,
    listing.title,
    listing.description,
    normalized_owner_kind,
    p_owner_lend_starts_at,
    p_owner_lend_ends_at,
    normalized_requester_kind,
    normalized_requester_description,
    p_requester_lend_starts_at,
    p_requester_lend_ends_at,
    normalized_private_note
  )
  returning id into new_terms_id;

  update public.resource_exchange_agreements
  set pending_terms_id = new_terms_id
  where id = agreement.id;

  if old_pending_terms_id is not null then
    perform private.record_resource_exchange_agreement_event(
      'terms_superseded',
      agreement.id,
      old_pending_terms_id,
      null,
      current_profile_id
    );
  end if;

  perform private.record_resource_exchange_agreement_event(
    'terms_proposed',
    agreement.id,
    new_terms_id,
    null,
    current_profile_id
  );

  return new_terms_id;
end;
$$;

create function public.accept_resource_exchange_terms(
  p_expected_profile_id uuid,
  p_agreement_id uuid,
  p_expected_pending_terms_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_resource_listing_request_identity(
    p_expected_profile_id,
    false
  );
  agreement public.resource_exchange_agreements%rowtype;
  request public.resource_listing_requests%rowtype;
  listing public.resource_listings%rowtype;
  pending_terms public.resource_exchange_agreement_terms%rowtype;
  transition_time timestamptz := statement_timestamp();
begin
  select * into agreement
  from public.resource_exchange_agreements
  where id = p_agreement_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'The resource exchange agreement does not exist.';
  end if;

  select * into request
  from public.resource_listing_requests
  where id = agreement.request_id;
  select * into listing
  from public.resource_listings
  where id = request.listing_id;

  if current_profile_id not in (
    listing.owner_profile_id,
    request.requester_profile_id
  ) then
    raise exception using
      errcode = '42501',
      message = 'Only the agreement counterparties may accept terms.';
  end if;

  if agreement.pending_terms_id is distinct from p_expected_pending_terms_id
    or agreement.pending_terms_id is null then
    raise sqlstate 'PT409'
      using message = 'The pending resource exchange terms changed since they were loaded.';
  end if;

  if agreement.lifecycle_state not in ('negotiating', 'agreed')
    or exists (
      select 1
      from public.resource_exchange_agreement_events as event
      where event.agreement_id = agreement.id
        and event.event_kind in (
          'resource_provided',
          'resource_received',
          'resource_returned',
          'resource_return_received'
        )
    ) then
    raise sqlstate 'PT409'
      using message = 'Agreement terms are frozen after handoff begins or coordination closes.';
  end if;

  select * into pending_terms
  from public.resource_exchange_agreement_terms
  where id = agreement.pending_terms_id
    and agreement_id = agreement.id;

  if pending_terms.proposed_by_profile_id = current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'A terms proposer cannot accept their own proposal.';
  end if;

  update public.resource_exchange_agreements
  set
    current_terms_id = pending_terms.id,
    pending_terms_id = null,
    current_terms_accepted_at = transition_time,
    lifecycle_state = 'agreed'
  where id = agreement.id;

  perform private.record_resource_exchange_agreement_event(
    'terms_accepted',
    agreement.id,
    pending_terms.id,
    null,
    current_profile_id,
    transition_time
  );

  return pending_terms.id;
end;
$$;

create function public.reject_resource_exchange_terms(
  p_expected_profile_id uuid,
  p_agreement_id uuid,
  p_expected_pending_terms_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_resource_listing_request_identity(
    p_expected_profile_id,
    false
  );
  agreement public.resource_exchange_agreements%rowtype;
  request public.resource_listing_requests%rowtype;
  listing public.resource_listings%rowtype;
  pending_terms public.resource_exchange_agreement_terms%rowtype;
begin
  select * into agreement
  from public.resource_exchange_agreements
  where id = p_agreement_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'The resource exchange agreement does not exist.';
  end if;

  select * into request
  from public.resource_listing_requests
  where id = agreement.request_id;
  select * into listing
  from public.resource_listings
  where id = request.listing_id;

  if current_profile_id not in (
    listing.owner_profile_id,
    request.requester_profile_id
  ) then
    raise exception using
      errcode = '42501',
      message = 'Only the agreement counterparties may reject terms.';
  end if;

  if agreement.pending_terms_id is distinct from p_expected_pending_terms_id
    or agreement.pending_terms_id is null then
    raise sqlstate 'PT409'
      using message = 'The pending resource exchange terms changed since they were loaded.';
  end if;

  if agreement.lifecycle_state not in ('negotiating', 'agreed') then
    raise sqlstate 'PT409'
      using message = 'Agreement terms can no longer be rejected.';
  end if;

  select * into pending_terms
  from public.resource_exchange_agreement_terms
  where id = agreement.pending_terms_id
    and agreement_id = agreement.id;

  if pending_terms.proposed_by_profile_id = current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'A terms proposer cannot reject their own proposal.';
  end if;

  update public.resource_exchange_agreements
  set pending_terms_id = null
  where id = agreement.id;

  perform private.record_resource_exchange_agreement_event(
    'terms_rejected',
    agreement.id,
    pending_terms.id,
    null,
    current_profile_id
  );

  return pending_terms.id;
end;
$$;

create function public.withdraw_resource_exchange_terms(
  p_expected_profile_id uuid,
  p_agreement_id uuid,
  p_expected_pending_terms_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_resource_listing_request_identity(
    p_expected_profile_id,
    false
  );
  agreement public.resource_exchange_agreements%rowtype;
  request public.resource_listing_requests%rowtype;
  listing public.resource_listings%rowtype;
  pending_terms public.resource_exchange_agreement_terms%rowtype;
begin
  select * into agreement
  from public.resource_exchange_agreements
  where id = p_agreement_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'The resource exchange agreement does not exist.';
  end if;

  select * into request
  from public.resource_listing_requests
  where id = agreement.request_id;
  select * into listing
  from public.resource_listings
  where id = request.listing_id;

  if current_profile_id not in (
    listing.owner_profile_id,
    request.requester_profile_id
  ) then
    raise exception using
      errcode = '42501',
      message = 'Only the agreement counterparties may withdraw terms.';
  end if;

  if agreement.pending_terms_id is distinct from p_expected_pending_terms_id
    or agreement.pending_terms_id is null then
    raise sqlstate 'PT409'
      using message = 'The pending resource exchange terms changed since they were loaded.';
  end if;

  if agreement.lifecycle_state not in ('negotiating', 'agreed') then
    raise sqlstate 'PT409'
      using message = 'Agreement terms can no longer be withdrawn.';
  end if;

  select * into pending_terms
  from public.resource_exchange_agreement_terms
  where id = agreement.pending_terms_id
    and agreement_id = agreement.id;

  if pending_terms.proposed_by_profile_id <> current_profile_id then
    raise exception using
      errcode = '42501',
      message = 'Only the terms proposer may withdraw this proposal.';
  end if;

  update public.resource_exchange_agreements
  set pending_terms_id = null
  where id = agreement.id;

  perform private.record_resource_exchange_agreement_event(
    'terms_withdrawn',
    agreement.id,
    pending_terms.id,
    null,
    current_profile_id
  );

  return pending_terms.id;
end;
$$;

create function public.record_resource_exchange_milestone(
  p_expected_profile_id uuid,
  p_agreement_id uuid,
  p_expected_terms_id uuid,
  p_leg_kind text,
  p_event_kind text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_resource_listing_request_identity(
    p_expected_profile_id,
    false
  );
  agreement public.resource_exchange_agreements%rowtype;
  request public.resource_listing_requests%rowtype;
  listing public.resource_listings%rowtype;
  current_terms public.resource_exchange_agreement_terms%rowtype;
  normalized_leg_kind text := lower(nullif(btrim(p_leg_kind), ''));
  normalized_event_kind text := lower(nullif(btrim(p_event_kind), ''));
  expected_actor_profile_id uuid;
  existing_event_id uuid;
  milestone_event_id uuid;
  owner_leg_complete boolean;
  requester_leg_complete boolean;
  transition_time timestamptz := statement_timestamp();
begin
  select * into agreement
  from public.resource_exchange_agreements
  where id = p_agreement_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'The resource exchange agreement does not exist.';
  end if;

  select * into request
  from public.resource_listing_requests
  where id = agreement.request_id;
  select * into listing
  from public.resource_listings
  where id = request.listing_id;

  if current_profile_id not in (
    listing.owner_profile_id,
    request.requester_profile_id
  ) then
    raise exception using
      errcode = '42501',
      message = 'Only the agreement counterparties may record milestones.';
  end if;

  if agreement.current_terms_id is distinct from p_expected_terms_id
    or agreement.current_terms_id is null then
    raise sqlstate 'PT409'
      using message = 'The accepted resource exchange terms changed since they were loaded.';
  end if;

  select * into current_terms
  from public.resource_exchange_agreement_terms
  where id = agreement.current_terms_id
    and agreement_id = agreement.id;

  if normalized_leg_kind is null
    or normalized_leg_kind not in ('owner_resource', 'requester_resource')
    or normalized_event_kind is null
    or normalized_event_kind not in (
      'resource_provided',
      'resource_received',
      'resource_returned',
      'resource_return_received'
    ) then
    raise exception using
      errcode = '22023',
      message = 'The resource exchange milestone shape is unsupported.';
  end if;

  if normalized_leg_kind = 'owner_resource' then
    expected_actor_profile_id := case normalized_event_kind
      when 'resource_provided' then listing.owner_profile_id
      when 'resource_received' then request.requester_profile_id
      when 'resource_returned' then request.requester_profile_id
      when 'resource_return_received' then listing.owner_profile_id
    end;

    if normalized_event_kind in (
      'resource_returned',
      'resource_return_received'
    ) and current_terms.owner_transfer_kind <> 'lend' then
      raise exception using
        errcode = '22023',
        message = 'Return milestones require a lend owner resource leg.';
    end if;
  else
    if current_terms.requester_transfer_kind = 'none' then
      raise exception using
        errcode = '22023',
        message = 'The agreement has no requester resource leg.';
    end if;

    expected_actor_profile_id := case normalized_event_kind
      when 'resource_provided' then request.requester_profile_id
      when 'resource_received' then listing.owner_profile_id
      when 'resource_returned' then listing.owner_profile_id
      when 'resource_return_received' then request.requester_profile_id
    end;

    if normalized_event_kind in (
      'resource_returned',
      'resource_return_received'
    ) and current_terms.requester_transfer_kind <> 'lend' then
      raise exception using
        errcode = '22023',
        message = 'Return milestones require a lend requester resource leg.';
    end if;
  end if;

  if current_profile_id <> expected_actor_profile_id then
    raise exception using
      errcode = '42501',
      message = 'Only the provider or recipient assigned to this milestone may record it.';
  end if;

  select event.id into existing_event_id
  from public.resource_exchange_agreement_events as event
  where event.agreement_id = agreement.id
    and event.terms_id = current_terms.id
    and event.leg_kind = normalized_leg_kind
    and event.event_kind = normalized_event_kind;

  if existing_event_id is not null then
    return existing_event_id;
  end if;

  if agreement.lifecycle_state not in ('agreed', 'in_progress')
    or agreement.pending_terms_id is not null then
    raise sqlstate 'PT409'
      using message = 'A milestone requires settled current terms and open coordination.';
  end if;

  milestone_event_id := private.record_resource_exchange_agreement_event(
    normalized_event_kind,
    agreement.id,
    current_terms.id,
    normalized_leg_kind,
    current_profile_id,
    transition_time
  );

  if agreement.lifecycle_state = 'agreed' then
    update public.resource_exchange_agreements
    set lifecycle_state = 'in_progress'
    where id = agreement.id;
  end if;

  owner_leg_complete :=
    exists (
      select 1
      from public.resource_exchange_agreement_events as event
      where event.agreement_id = agreement.id
        and event.terms_id = current_terms.id
        and event.leg_kind = 'owner_resource'
        and event.event_kind = 'resource_provided'
    )
    and exists (
      select 1
      from public.resource_exchange_agreement_events as event
      where event.agreement_id = agreement.id
        and event.terms_id = current_terms.id
        and event.leg_kind = 'owner_resource'
        and event.event_kind = 'resource_received'
    )
    and (
      current_terms.owner_transfer_kind = 'give'
      or (
        exists (
          select 1
          from public.resource_exchange_agreement_events as event
          where event.agreement_id = agreement.id
            and event.terms_id = current_terms.id
            and event.leg_kind = 'owner_resource'
            and event.event_kind = 'resource_returned'
        )
        and exists (
          select 1
          from public.resource_exchange_agreement_events as event
          where event.agreement_id = agreement.id
            and event.terms_id = current_terms.id
            and event.leg_kind = 'owner_resource'
            and event.event_kind = 'resource_return_received'
        )
      )
    );

  requester_leg_complete := current_terms.requester_transfer_kind = 'none'
    or (
      exists (
        select 1
        from public.resource_exchange_agreement_events as event
        where event.agreement_id = agreement.id
          and event.terms_id = current_terms.id
          and event.leg_kind = 'requester_resource'
          and event.event_kind = 'resource_provided'
      )
      and exists (
        select 1
        from public.resource_exchange_agreement_events as event
        where event.agreement_id = agreement.id
          and event.terms_id = current_terms.id
          and event.leg_kind = 'requester_resource'
          and event.event_kind = 'resource_received'
      )
      and (
        current_terms.requester_transfer_kind = 'give'
        or (
          exists (
            select 1
            from public.resource_exchange_agreement_events as event
            where event.agreement_id = agreement.id
              and event.terms_id = current_terms.id
              and event.leg_kind = 'requester_resource'
              and event.event_kind = 'resource_returned'
          )
          and exists (
            select 1
            from public.resource_exchange_agreement_events as event
            where event.agreement_id = agreement.id
              and event.terms_id = current_terms.id
              and event.leg_kind = 'requester_resource'
              and event.event_kind = 'resource_return_received'
          )
        )
      )
    );

  if owner_leg_complete and requester_leg_complete then
    update public.resource_exchange_agreements
    set
      lifecycle_state = 'completed',
      completed_at = transition_time
    where id = agreement.id;

    update public.resource_listing_requests
    set
      coordination_closed_at = transition_time,
      coordination_closed_by_profile_id = current_profile_id
    where id = request.id
      and status = 'accepted'
      and coordination_closed_at is null;

    if not found then
      raise sqlstate 'PT409'
        using message = 'The accepted request coordination is already closed.';
    end if;

    perform private.record_resource_exchange_agreement_event(
      'agreement_completed',
      agreement.id,
      current_terms.id,
      null,
      current_profile_id,
      transition_time + interval '1 microsecond'
    );
  end if;

  return milestone_event_id;
end;
$$;

create function public.cancel_resource_exchange_agreement(
  p_expected_profile_id uuid,
  p_agreement_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile_id uuid := private.require_resource_listing_request_identity(
    p_expected_profile_id,
    false
  );
  agreement public.resource_exchange_agreements%rowtype;
  request public.resource_listing_requests%rowtype;
  listing public.resource_listings%rowtype;
  transition_time timestamptz := statement_timestamp();
begin
  select * into agreement
  from public.resource_exchange_agreements
  where id = p_agreement_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'The resource exchange agreement does not exist.';
  end if;

  select * into request
  from public.resource_listing_requests
  where id = agreement.request_id
  for update;
  select * into listing
  from public.resource_listings
  where id = request.listing_id;

  if current_profile_id not in (
    listing.owner_profile_id,
    request.requester_profile_id
  ) then
    raise exception using
      errcode = '42501',
      message = 'Only the agreement counterparties may cancel coordination.';
  end if;

  if agreement.lifecycle_state not in ('negotiating', 'agreed')
    or exists (
      select 1
      from public.resource_exchange_agreement_events as event
      where event.agreement_id = agreement.id
        and event.event_kind in (
          'resource_provided',
          'resource_received',
          'resource_returned',
          'resource_return_received'
        )
    ) then
    raise sqlstate 'PT409'
      using message = 'An agreement cannot be cancelled after handoff begins or coordination closes.';
  end if;

  if request.status <> 'accepted'
    or request.coordination_closed_at is not null then
    raise sqlstate 'PT409'
      using message = 'The accepted request coordination is already closed.';
  end if;

  update public.resource_exchange_agreements
  set
    lifecycle_state = 'cancelled',
    pending_terms_id = null,
    cancelled_at = transition_time,
    cancelled_by_profile_id = current_profile_id
  where id = agreement.id;

  update public.resource_listing_requests
  set
    coordination_closed_at = transition_time,
    coordination_closed_by_profile_id = current_profile_id
  where id = request.id;

  perform private.record_resource_exchange_agreement_event(
    'agreement_cancelled',
    agreement.id,
    null,
    null,
    current_profile_id,
    transition_time
  );

  return agreement.id;
end;
$$;

create function public.get_resource_exchange_agreement(
  p_expected_profile_id uuid,
  p_request_id uuid
)
returns table (
  agreement_id uuid,
  request_id uuid,
  listing_id uuid,
  owner_profile_id uuid,
  requester_profile_id uuid,
  lifecycle_state text,
  current_terms_id uuid,
  pending_terms_id uuid,
  current_terms_accepted_at timestamptz,
  created_at timestamptz,
  cancelled_at timestamptz,
  cancelled_by_profile_id uuid,
  completed_at timestamptz,
  owner_lend_return_overdue boolean,
  requester_lend_return_overdue boolean
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
    agreement.id,
    request.id,
    request.listing_id,
    listing.owner_profile_id,
    request.requester_profile_id,
    agreement.lifecycle_state,
    agreement.current_terms_id,
    agreement.pending_terms_id,
    agreement.current_terms_accepted_at,
    agreement.created_at,
    agreement.cancelled_at,
    agreement.cancelled_by_profile_id,
    agreement.completed_at,
    coalesce(
      current_terms.owner_transfer_kind = 'lend'
      and statement_timestamp() > current_terms.owner_lend_ends_at
      and agreement.lifecycle_state not in ('cancelled', 'completed')
      and not exists (
        select 1
        from public.resource_exchange_agreement_events as owner_return_event
        where owner_return_event.agreement_id = agreement.id
          and owner_return_event.terms_id = current_terms.id
          and owner_return_event.leg_kind = 'owner_resource'
          and owner_return_event.event_kind = 'resource_return_received'
      ),
      false
    ),
    coalesce(
      current_terms.requester_transfer_kind = 'lend'
      and statement_timestamp() > current_terms.requester_lend_ends_at
      and agreement.lifecycle_state not in ('cancelled', 'completed')
      and not exists (
        select 1
        from public.resource_exchange_agreement_events as requester_return_event
        where requester_return_event.agreement_id = agreement.id
          and requester_return_event.terms_id = current_terms.id
          and requester_return_event.leg_kind = 'requester_resource'
          and requester_return_event.event_kind = 'resource_return_received'
      ),
      false
    )
  from public.resource_exchange_agreements as agreement
  join public.resource_listing_requests as request
    on request.id = agreement.request_id
  join public.resource_listings as listing
    on listing.id = request.listing_id
  left join public.resource_exchange_agreement_terms as current_terms
    on current_terms.id = agreement.current_terms_id
    and current_terms.agreement_id = agreement.id
  where agreement.request_id = p_request_id
    and current_profile_id in (
      listing.owner_profile_id,
      request.requester_profile_id
    );
end;
$$;

create function public.list_resource_exchange_agreement_terms(
  p_expected_profile_id uuid,
  p_agreement_id uuid
)
returns table (
  terms_id uuid,
  version_number integer,
  proposed_by_profile_id uuid,
  listing_title_snapshot text,
  listing_description_snapshot text,
  owner_transfer_kind text,
  owner_lend_starts_at timestamptz,
  owner_lend_ends_at timestamptz,
  requester_transfer_kind text,
  requester_resource_description text,
  requester_lend_starts_at timestamptz,
  requester_lend_ends_at timestamptz,
  private_note text,
  created_at timestamptz,
  is_current boolean,
  is_pending boolean
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
  agreement public.resource_exchange_agreements%rowtype;
begin
  select candidate.* into agreement
  from public.resource_exchange_agreements as candidate
  join public.resource_listing_requests as request
    on request.id = candidate.request_id
  join public.resource_listings as listing
    on listing.id = request.listing_id
  where candidate.id = p_agreement_id
    and current_profile_id in (
      listing.owner_profile_id,
      request.requester_profile_id
    );

  if not found then
    raise exception using
      errcode = '42501',
      message = 'The current user cannot read this resource exchange agreement.';
  end if;

  return query
  select
    terms.id,
    terms.version_number,
    terms.proposed_by_profile_id,
    terms.listing_title_snapshot,
    terms.listing_description_snapshot,
    terms.owner_transfer_kind,
    terms.owner_lend_starts_at,
    terms.owner_lend_ends_at,
    terms.requester_transfer_kind,
    terms.requester_resource_description,
    terms.requester_lend_starts_at,
    terms.requester_lend_ends_at,
    terms.private_note,
    terms.created_at,
    terms.id = agreement.current_terms_id,
    terms.id = agreement.pending_terms_id
  from public.resource_exchange_agreement_terms as terms
  where terms.agreement_id = agreement.id
  order by terms.version_number desc;
end;
$$;

create function public.list_resource_exchange_agreement_events(
  p_expected_profile_id uuid,
  p_agreement_id uuid
)
returns table (
  event_id uuid,
  event_kind text,
  terms_id uuid,
  leg_kind text,
  actor_profile_id uuid,
  actor_display_name text,
  created_at timestamptz
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
  if not exists (
    select 1
    from public.resource_exchange_agreements as agreement
    join public.resource_listing_requests as request
      on request.id = agreement.request_id
    join public.resource_listings as listing
      on listing.id = request.listing_id
    where agreement.id = p_agreement_id
      and current_profile_id in (
        listing.owner_profile_id,
        request.requester_profile_id
      )
  ) then
    raise exception using
      errcode = '42501',
      message = 'The current user cannot read this resource exchange agreement.';
  end if;

  return query
  select
    event.id,
    event.event_kind,
    event.terms_id,
    event.leg_kind,
    event.actor_profile_id,
    actor.display_name,
    event.created_at
  from public.resource_exchange_agreement_events as event
  join public.profiles as actor on actor.id = event.actor_profile_id
  where event.agreement_id = p_agreement_id
  order by event.created_at, event.id;
end;
$$;

drop function public.list_resource_listing_requests(uuid, uuid);

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
  resolved_by_profile_id uuid,
  coordination_closed_at timestamptz,
  coordination_closed_by_profile_id uuid
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
    request.resolved_by_profile_id,
    request.coordination_closed_at,
    request.coordination_closed_by_profile_id
  from public.resource_listing_requests as request
  join public.profiles as requester
    on requester.id = request.requester_profile_id
  where request.listing_id = p_listing_id
  order by request.created_at desc, request.id desc;
end;
$$;

drop function public.list_own_resource_listing_requests(uuid);

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
  resolved_at timestamptz,
  coordination_closed_at timestamptz,
  coordination_closed_by_profile_id uuid
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
    request.resolved_at,
    request.coordination_closed_at,
    request.coordination_closed_by_profile_id
  from public.resource_listing_requests as request
  join public.resource_listings as listing on listing.id = request.listing_id
  join public.profiles as owner on owner.id = listing.owner_profile_id
  where request.requester_profile_id = current_profile_id
  order by request.created_at desc, request.id desc;
end;
$$;

drop function public.get_resource_listing_request(uuid, uuid);

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
  resolved_by_profile_id uuid,
  coordination_closed_at timestamptz,
  coordination_closed_by_profile_id uuid
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
    request.resolved_by_profile_id,
    request.coordination_closed_at,
    request.coordination_closed_by_profile_id
  from public.resource_listing_requests as request
  join public.resource_listings as listing on listing.id = request.listing_id
  join public.profiles as owner on owner.id = listing.owner_profile_id
  join public.profiles as requester
    on requester.id = request.requester_profile_id
  where request.id = p_request_id
    and current_profile_id in (
      request.requester_profile_id,
      listing.owner_profile_id
    );
end;
$$;

comment on function public.accept_resource_listing_request(uuid, uuid) is
  'Atomically accepts one pending listing request and creates its single negotiating resource exchange agreement anchor.';
comment on function public.request_resource_listing(uuid, uuid, text) is
  'Creates one pending request when no pending or coordination-open accepted episode exists for the requester/listing pair.';
comment on function public.list_public_resource_listings(integer, timestamptz, uuid, text, text, text) is
  'Returns published listings with a derived count of pending plus coordination-open accepted requests and no counterparty data.';
comment on function public.get_public_resource_listing(uuid) is
  'Returns one published listing with a derived count of pending plus coordination-open accepted requests and no agreement data.';
comment on function public.propose_resource_exchange_terms(uuid, uuid, uuid, uuid, text, timestamptz, timestamptz, text, text, timestamptz, timestamptz, text) is
  'Creates an immutable server-snapshotted two-leg terms proposal after exact current/pending pointer CAS; either counterparty may propose before handoff.';
comment on function public.accept_resource_exchange_terms(uuid, uuid, uuid) is
  'Lets only the non-proposer accept the exact pending immutable terms before handoff.';
comment on function public.reject_resource_exchange_terms(uuid, uuid, uuid) is
  'Lets only the non-proposer reject the exact pending terms while preserving immutable history and any prior current terms.';
comment on function public.withdraw_resource_exchange_terms(uuid, uuid, uuid) is
  'Lets only the proposer withdraw the exact pending terms while preserving immutable history.';
comment on function public.record_resource_exchange_milestone(uuid, uuid, uuid, text, text) is
  'Records one actor-authorized idempotent milestone against frozen current terms and automatically completes fully confirmed agreements.';
comment on function public.cancel_resource_exchange_agreement(uuid, uuid) is
  'Lets either counterparty cancel negotiating/agreed coordination only before any resource milestone, retaining all history.';
comment on function public.get_resource_exchange_agreement(uuid, uuid) is
  'Returns one request agreement only to its counterparties, including derived current lend-overdue indicators.';
comment on function public.list_resource_exchange_agreement_terms(uuid, uuid) is
  'Returns immutable private agreement terms versions newest-first only to the two counterparties.';
comment on function public.list_resource_exchange_agreement_events(uuid, uuid) is
  'Returns the private structured agreement timeline with counterpart display names only to the two counterparties.';
comment on function public.list_resource_listing_requests(uuid, uuid) is
  'Returns owner-private request history including accepted coordination closure without exposing agreement terms.';
comment on function public.list_own_resource_listing_requests(uuid) is
  'Returns requester-private history including accepted coordination closure without exposing agreement terms.';
comment on function public.get_resource_listing_request(uuid, uuid) is
  'Returns one request to its requester or listing owner, including accepted coordination closure.';

revoke all privileges on function private.protect_resource_exchange_terms_immutability()
  from public, anon, authenticated, service_role;
revoke all privileges on function private.protect_resource_exchange_events_immutability()
  from public, anon, authenticated, service_role;
revoke all privileges on function private.record_resource_exchange_agreement_event(text, uuid, uuid, text, uuid, timestamptz)
  from public, anon, authenticated, service_role;
revoke all privileges on function private.ensure_resource_exchange_agreement_for_request(uuid, uuid, timestamptz)
  from public, anon, authenticated, service_role;

revoke all privileges on function public.propose_resource_exchange_terms(uuid, uuid, uuid, uuid, text, timestamptz, timestamptz, text, text, timestamptz, timestamptz, text)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.accept_resource_exchange_terms(uuid, uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.reject_resource_exchange_terms(uuid, uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.withdraw_resource_exchange_terms(uuid, uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.record_resource_exchange_milestone(uuid, uuid, uuid, text, text)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.cancel_resource_exchange_agreement(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.get_resource_exchange_agreement(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.list_resource_exchange_agreement_terms(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.list_resource_exchange_agreement_events(uuid, uuid)
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

grant execute on function public.propose_resource_exchange_terms(uuid, uuid, uuid, uuid, text, timestamptz, timestamptz, text, text, timestamptz, timestamptz, text)
  to authenticated;
grant execute on function public.accept_resource_exchange_terms(uuid, uuid, uuid)
  to authenticated;
grant execute on function public.reject_resource_exchange_terms(uuid, uuid, uuid)
  to authenticated;
grant execute on function public.withdraw_resource_exchange_terms(uuid, uuid, uuid)
  to authenticated;
grant execute on function public.record_resource_exchange_milestone(uuid, uuid, uuid, text, text)
  to authenticated;
grant execute on function public.cancel_resource_exchange_agreement(uuid, uuid)
  to authenticated;
grant execute on function public.get_resource_exchange_agreement(uuid, uuid)
  to authenticated;
grant execute on function public.list_resource_exchange_agreement_terms(uuid, uuid)
  to authenticated;
grant execute on function public.list_resource_exchange_agreement_events(uuid, uuid)
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
