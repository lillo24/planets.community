create table private.resource_saved_search_listing_matches (
  id uuid primary key default gen_random_uuid(),
  source_outbox_event_id uuid not null
    constraint resource_saved_search_listing_matches_source_event_fkey
      references private.outbox_events (id) on delete restrict,
  saved_search_id uuid not null
    constraint resource_saved_search_listing_matches_saved_search_fkey
      references public.resource_saved_searches (id) on delete cascade,
  saved_search_updated_at timestamptz not null,
  recipient_profile_id uuid not null
    constraint resource_saved_search_listing_matches_recipient_fkey
      references public.profiles (id) on delete cascade,
  listing_id uuid not null
    constraint resource_saved_search_listing_matches_listing_fkey
      references public.resource_listings (id) on delete restrict,
  matched_at timestamptz not null,
  constraint resource_saved_search_listing_matches_version_valid check (
    saved_search_updated_at <= matched_at
  ),
  constraint resource_saved_search_listing_matches_search_listing_unique
    unique (saved_search_id, listing_id),
  constraint resource_saved_search_listing_matches_source_search_unique
    unique (source_outbox_event_id, saved_search_id)
);

comment on table private.resource_saved_search_listing_matches is
  'Frequency-neutral private facts proving that one saved-search definition matched one newly published Resource listing.';
comment on column private.resource_saved_search_listing_matches.saved_search_updated_at is
  'Saved-search version token captured at match time; later delivery must require the current search to retain this updated_at.';
comment on column private.resource_saved_search_listing_matches.matched_at is
  'Canonical source resource_listing.published event chronology, never projector wall-clock time.';

create index resource_saved_search_listing_matches_recipient_idx
  on private.resource_saved_search_listing_matches (
    recipient_profile_id,
    matched_at desc,
    id
  );

create index resource_saved_search_listing_matches_listing_idx
  on private.resource_saved_search_listing_matches (listing_id, saved_search_id);

create index outbox_events_saved_search_matching_available_idx
  on private.outbox_events (available_at, created_at, id)
  where event_type = 'resource_listing.published';

revoke all privileges on table private.resource_saved_search_listing_matches
  from public, anon, authenticated, service_role;

-- Saved searches begin observing newly published listings at this rollout boundary.
-- Existing publication events are acknowledged without retroactive match creation.
insert into private.outbox_consumer_receipts (
  outbox_event_id,
  consumer_key,
  processed_at
)
select
  event.id,
  'saved-search-matching.v1',
  statement_timestamp()
from private.outbox_events as event
where event.event_type = 'resource_listing.published'
on conflict do nothing;

create function public.process_resource_saved_search_matching_outbox_batch(
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
          or not private.resource_listing_matches_saved_search_filters(
            listing.listing_mode,
            listing.title,
            listing.description,
            listing.locality,
            saved_search.listing_mode,
            saved_search.query,
            saved_search.locality
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

revoke all privileges on function
  public.process_resource_saved_search_matching_outbox_batch(integer)
  from public, anon, authenticated, service_role;

grant execute on function
  public.process_resource_saved_search_matching_outbox_batch(integer)
  to service_role;

comment on function
  public.process_resource_saved_search_matching_outbox_batch(integer) is
  'Service-only, concurrency-safe saved-search-matching.v1 projector for new Resource publications; it creates private versioned facts and identifier-only match events without notifications.';
