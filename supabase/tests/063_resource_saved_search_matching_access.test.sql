begin;

select no_plan();

insert into auth.users (id, email)
values
  ('fa000000-0000-4000-8000-000000000001', 'matching-a@planets.invalid'),
  ('fb000000-0000-4000-8000-000000000002', 'matching-b@planets.invalid'),
  ('fc000000-0000-4000-8000-000000000003', 'matching-owner@planets.invalid'),
  ('fd000000-0000-4000-8000-000000000004', 'matching-d@planets.invalid');

insert into public.profiles (id, display_name)
values
  ('fa000000-0000-4000-8000-000000000001', 'Matching A'),
  ('fb000000-0000-4000-8000-000000000002', 'Matching B'),
  ('fc000000-0000-4000-8000-000000000003', 'Listing Owner'),
  ('fd000000-0000-4000-8000-000000000004', 'Matching D');

set local role anon;
select throws_ok(
  $$select * from public.process_resource_saved_search_matching_outbox_batch(1)$$,
  '42501',
  'permission denied for function process_resource_saved_search_matching_outbox_batch',
  'anonymous clients cannot invoke the projector'
);

reset role;
set local role authenticated;
select throws_ok(
  $$select * from public.process_resource_saved_search_matching_outbox_batch(1)$$,
  '42501',
  'permission denied for function process_resource_saved_search_matching_outbox_batch',
  'authenticated clients cannot invoke the projector'
);

reset role;
set local role service_role;
select throws_ok(
  $$select * from public.process_resource_saved_search_matching_outbox_batch(0)$$,
  '22023',
  'Saved-search matching projector batch size must be between 1 and 100.',
  'zero is below the projector batch bound'
);
select throws_ok(
  $$select * from public.process_resource_saved_search_matching_outbox_batch(101)$$,
  '22023',
  'Saved-search matching projector batch size must be between 1 and 100.',
  'values above one hundred exceed the projector batch bound'
);
select throws_ok(
  $$select * from public.process_resource_saved_search_matching_outbox_batch(null)$$,
  '22023',
  'Saved-search matching projector batch size must be between 1 and 100.',
  'a null projector batch bound fails explicitly'
);

reset role;

insert into public.resource_saved_searches (
  id, profile_id, query, listing_mode, locality, created_at, updated_at
)
values
  (
    'a1000000-0000-4000-8000-000000000001',
    'fa000000-0000-4000-8000-000000000001',
    'drill', null, null,
    '2026-01-01 08:00:00+00', '2026-01-01 08:00:00+00'
  ),
  (
    'a2000000-0000-4000-8000-000000000002',
    'fa000000-0000-4000-8000-000000000001',
    null, 'donate', null,
    '2026-01-01 08:01:00+00', '2026-01-01 08:01:00+00'
  ),
  (
    'a3000000-0000-4000-8000-000000000003',
    'fa000000-0000-4000-8000-000000000001',
    null, null, 'Trento',
    '2026-01-01 08:02:00+00', '2026-01-01 08:02:00+00'
  ),
  (
    'a4000000-0000-4000-8000-000000000004',
    'fa000000-0000-4000-8000-000000000001',
    'cordless', 'donate', 'Trento',
    '2026-01-01 08:03:00+00', '2026-01-01 08:03:00+00'
  ),
  (
    'a5000000-0000-4000-8000-000000000005',
    'fa000000-0000-4000-8000-000000000001',
    'saw', null, null,
    '2026-01-01 08:04:00+00', '2026-01-01 08:04:00+00'
  ),
  (
    'a6000000-0000-4000-8000-000000000006',
    'fb000000-0000-4000-8000-000000000002',
    'bosch', null, null,
    '2026-01-01 08:05:00+00', '2026-01-01 08:05:00+00'
  ),
  (
    'a7000000-0000-4000-8000-000000000007',
    'fc000000-0000-4000-8000-000000000003',
    'drill', null, null,
    '2026-01-01 08:06:00+00', '2026-01-01 08:06:00+00'
  );

insert into public.resource_listings (
  id,
  owner_profile_id,
  listing_mode,
  lifecycle_state,
  title,
  description,
  country_code,
  locality,
  public_location_label,
  created_at,
  updated_at,
  published_at
)
values (
  'b1000000-0000-4000-8000-000000000001',
  'fc000000-0000-4000-8000-000000000003',
  'donate',
  'published',
  'Cordless Drill',
  'Bosch battery and charger',
  'IT',
  'Trento',
  'Trento',
  '2026-01-01 09:00:00+00',
  '2026-01-02 09:00:00+00',
  '2026-01-02 09:00:00+00'
);

-- This event represents the migration-time historical boundary: the rollout
-- receipt exists before the projector runs, so it must never create matches.
insert into private.outbox_events (
  id, event_type, payload, created_at, available_at
)
values (
  'c0000000-0000-4000-8000-000000000000',
  'resource_listing.published',
  jsonb_build_object(
    'listing_id', 'b1000000-0000-4000-8000-000000000001',
    'owner_profile_id', 'fc000000-0000-4000-8000-000000000003',
    'listing_mode', 'donate'
  ),
  '2026-01-02 08:59:00+00',
  '2026-01-02 08:59:00+00'
);
insert into private.outbox_consumer_receipts (
  outbox_event_id, consumer_key, processed_at
)
values (
  'c0000000-0000-4000-8000-000000000000',
  'saved-search-matching.v1',
  '2026-01-02 09:30:00+00'
);

insert into private.outbox_events (
  id, event_type, payload, created_at, available_at
)
values (
  'c1000000-0000-4000-8000-000000000001',
  'resource_listing.published',
  jsonb_build_object(
    'listing_id', 'b1000000-0000-4000-8000-000000000001',
    'owner_profile_id', 'fc000000-0000-4000-8000-000000000003',
    'listing_mode', 'donate'
  ),
  '2026-01-02 09:00:00+00',
  '2026-01-02 09:00:00+00'
);
insert into private.outbox_consumer_receipts (
  outbox_event_id, consumer_key, processed_at
)
values
  (
    'c1000000-0000-4000-8000-000000000001',
    'notifications.v1',
    '2026-01-02 09:01:00+00'
  ),
  (
    'c1000000-0000-4000-8000-000000000001',
    'push.v1',
    '2026-01-02 09:01:00+00'
  );

set local role service_role;
select results_eq(
  $$
    select processed_count, matches_created, matches_suppressed
    from public.process_resource_saved_search_matching_outbox_batch(100)
  $$,
  $$values (1, 5, 2)$$,
  'query, mode, locality, all-filter, and second-recipient searches match once while nonmatch and owner are suppressed'
);

reset role;
select is(
  (
    select count(*)
    from private.resource_saved_search_listing_matches
    where source_outbox_event_id =
      'c0000000-0000-4000-8000-000000000000'
  ),
  0::bigint,
  'a pre-receipted historical publication creates no retroactive match facts'
);
select is(
  (
    select count(*)
    from private.resource_saved_search_listing_matches
    where source_outbox_event_id =
      'c1000000-0000-4000-8000-000000000001'
  ),
  5::bigint,
  'one publication may match multiple searches and recipients without per-user collapse'
);
select is(
  (
    select count(distinct recipient_profile_id)
    from private.resource_saved_search_listing_matches
    where source_outbox_event_id =
      'c1000000-0000-4000-8000-000000000001'
  ),
  2::bigint,
  'matching facts retain both eligible recipients'
);
select is(
  (
    select count(*)
    from private.resource_saved_search_listing_matches
    where source_outbox_event_id =
      'c1000000-0000-4000-8000-000000000001'
      and recipient_profile_id =
        'fc000000-0000-4000-8000-000000000003'
  ),
  0::bigint,
  'a listing owner never receives a match for their own publication'
);
select is(
  (
    select count(*)
    from private.resource_saved_search_listing_matches
    where source_outbox_event_id =
      'c1000000-0000-4000-8000-000000000001'
      and matched_at = '2026-01-02 09:00:00+00'
      and saved_search_updated_at <= matched_at
  ),
  5::bigint,
  'facts use source chronology and capture only definitions existing by publication time'
);
select is(
  (
    select count(*)
    from private.outbox_events as event
    where event.event_type = 'resource_saved_search.matched'
      and event.payload ->> 'listing_id' =
        'b1000000-0000-4000-8000-000000000001'
      and event.created_at = '2026-01-02 09:00:00+00'
  ),
  5::bigint,
  'each new fact emits one derived event at the source publication chronology'
);
select ok(
  not exists (
    select 1
    from private.outbox_events as event
    where event.event_type = 'resource_saved_search.matched'
      and event.payload ->> 'listing_id' =
        'b1000000-0000-4000-8000-000000000001'
      and (
        (select count(*) from jsonb_object_keys(event.payload)) <> 4
        or not event.payload ? 'saved_search_match_id'
        or not event.payload ? 'saved_search_id'
        or not event.payload ? 'recipient_profile_id'
        or not event.payload ? 'listing_id'
        or event.payload::text ilike '%drill%'
        or event.payload::text ilike '%bosch%'
        or event.payload::text ilike '%trento%'
      )
  ),
  'derived payloads contain exactly the four allowed identifiers and no search/listing text'
);
select is(
  (
    select count(*)
    from private.outbox_consumer_receipts
    where outbox_event_id =
      'c1000000-0000-4000-8000-000000000001'
  ),
  3::bigint,
  'matching receipts coexist independently with notifications.v1 and push.v1'
);
select is(
  (
    select count(*)
    from public.notifications
    where source_outbox_event_id =
      'c1000000-0000-4000-8000-000000000001'
  ),
  0::bigint,
  'F3A creates no in-app notification row'
);
select is(
  (
    select count(*)
    from private.push_delivery_jobs
    where source_outbox_event_id =
      'c1000000-0000-4000-8000-000000000001'
  ),
  0::bigint,
  'F3A creates no push-delivery job'
);

set local role service_role;
select results_eq(
  $$
    select processed_count, matches_created, matches_suppressed
    from public.process_resource_saved_search_matching_outbox_batch(100)
  $$,
  $$values (0, 0, 0)$$,
  'a committed source receipt makes the normal retry a no-op'
);

reset role;
delete from private.outbox_consumer_receipts
where outbox_event_id = 'c1000000-0000-4000-8000-000000000001'
  and consumer_key = 'saved-search-matching.v1';

set local role service_role;
select results_eq(
  $$
    select processed_count, matches_created, matches_suppressed
    from public.process_resource_saved_search_matching_outbox_batch(100)
  $$,
  $$values (1, 0, 7)$$,
  'uniqueness is defense in depth when a committed receipt is lost'
);

reset role;
select is(
  (
    select count(*)
    from private.outbox_events
    where event_type = 'resource_saved_search.matched'
      and payload ->> 'listing_id' =
        'b1000000-0000-4000-8000-000000000001'
  ),
  5::bigint,
  'receipt-loss retry emits no duplicate derived events'
);

delete from public.resource_saved_searches;

-- A search created after publication is ineligible even if it exists before
-- delayed processing.
insert into public.resource_listings (
  id, owner_profile_id, listing_mode, lifecycle_state, title, description,
  country_code, locality, public_location_label, created_at, updated_at,
  published_at
)
values (
  'b2000000-0000-4000-8000-000000000002',
  'fc000000-0000-4000-8000-000000000003',
  'exchange', 'published', 'Retro Needle', 'Retro-only fixture', 'IT',
  'Milano', 'Milano',
  '2026-02-01 09:00:00+00', '2026-02-02 09:00:00+00',
  '2026-02-02 09:00:00+00'
);
insert into private.outbox_events (
  id, event_type, payload, created_at, available_at
)
values (
  'c2000000-0000-4000-8000-000000000002',
  'resource_listing.published',
  jsonb_build_object(
    'listing_id', 'b2000000-0000-4000-8000-000000000002',
    'owner_profile_id', 'fc000000-0000-4000-8000-000000000003',
    'listing_mode', 'exchange'
  ),
  '2026-02-02 09:00:00+00', '2026-02-02 09:00:00+00'
);
insert into public.resource_saved_searches (
  id, profile_id, query, created_at, updated_at
)
values (
  'a8000000-0000-4000-8000-000000000008',
  'fa000000-0000-4000-8000-000000000001',
  'Retro Needle',
  '2026-02-02 09:01:00+00', '2026-02-02 09:01:00+00'
);

set local role service_role;
select results_eq(
  $$select * from public.process_resource_saved_search_matching_outbox_batch(100)$$,
  $$values (1, 0, 0)$$,
  'a saved search created after publication is not matched retroactively'
);

reset role;
delete from public.resource_saved_searches;

-- An edit after publication moves the definition beyond the event-time
-- boundary; only a later publication may match the new definition.
insert into public.resource_saved_searches (
  id, profile_id, query, created_at, updated_at
)
values (
  'a9000000-0000-4000-8000-000000000009',
  'fa000000-0000-4000-8000-000000000001',
  'Old Definition',
  '2026-03-01 08:00:00+00', '2026-03-01 08:00:00+00'
);
insert into public.resource_listings (
  id, owner_profile_id, listing_mode, lifecycle_state, title, description,
  country_code, locality, public_location_label, created_at, updated_at,
  published_at
)
values (
  'b3000000-0000-4000-8000-000000000003',
  'fc000000-0000-4000-8000-000000000003',
  'donate', 'published', 'New Definition', 'Boundary fixture', 'IT',
  'Roma', 'Roma',
  '2026-03-01 09:00:00+00', '2026-03-02 09:00:00+00',
  '2026-03-02 09:00:00+00'
);
insert into private.outbox_events (
  id, event_type, payload, created_at, available_at
)
values (
  'c3000000-0000-4000-8000-000000000003',
  'resource_listing.published',
  jsonb_build_object(
    'listing_id', 'b3000000-0000-4000-8000-000000000003',
    'owner_profile_id', 'fc000000-0000-4000-8000-000000000003',
    'listing_mode', 'donate'
  ),
  '2026-03-02 09:00:00+00', '2026-03-02 09:00:00+00'
);
update public.resource_saved_searches
set query = 'New Definition'
where id = 'a9000000-0000-4000-8000-000000000009';

set local role service_role;
select results_eq(
  $$select * from public.process_resource_saved_search_matching_outbox_batch(100)$$,
  $$values (1, 0, 0)$$,
  'an edited search does not apply its newer definition to an older source event'
);

reset role;
insert into public.resource_listings (
  id, owner_profile_id, listing_mode, lifecycle_state, title, description,
  country_code, locality, public_location_label, created_at, updated_at,
  published_at
)
values (
  'b4000000-0000-4000-8000-000000000004',
  'fc000000-0000-4000-8000-000000000003',
  'donate', 'published', 'New Definition', 'Future boundary fixture', 'IT',
  'Roma', 'Roma',
  statement_timestamp(), statement_timestamp(), statement_timestamp()
);
insert into private.outbox_events (
  id, event_type, payload, created_at, available_at
)
values (
  'c4000000-0000-4000-8000-000000000004',
  'resource_listing.published',
  jsonb_build_object(
    'listing_id', 'b4000000-0000-4000-8000-000000000004',
    'owner_profile_id', 'fc000000-0000-4000-8000-000000000003',
    'listing_mode', 'donate'
  ),
  statement_timestamp(), statement_timestamp()
);

set local role service_role;
select results_eq(
  $$select * from public.process_resource_saved_search_matching_outbox_batch(100)$$,
  $$values (1, 1, 0)$$,
  'a later publication can match the edited saved-search definition'
);

reset role;
select is(
  (
    select match.saved_search_updated_at
    from private.resource_saved_search_listing_matches as match
    where match.listing_id = 'b4000000-0000-4000-8000-000000000004'
  ),
  (
    select saved_search.updated_at
    from public.resource_saved_searches as saved_search
    where saved_search.id = 'a9000000-0000-4000-8000-000000000009'
  ),
  'the fact captures the exact current search version token'
);

update public.resource_saved_searches
set query = 'Edited Again'
where id = 'a9000000-0000-4000-8000-000000000009';
select ok(
  exists (
    select 1
    from private.resource_saved_search_listing_matches as match
    join public.resource_saved_searches as saved_search
      on saved_search.id = match.saved_search_id
    where match.listing_id = 'b4000000-0000-4000-8000-000000000004'
      and match.saved_search_updated_at <> saved_search.updated_at
  ),
  'editing after match creation retains the old versioned fact for F3B suppression'
);

update public.resource_listings
set lifecycle_state = 'closed', closed_at = statement_timestamp()
where id = 'b4000000-0000-4000-8000-000000000004';
select is(
  (
    select count(*)
    from private.resource_saved_search_listing_matches
    where listing_id = 'b4000000-0000-4000-8000-000000000004'
  ),
  1::bigint,
  'closing a listing after fact creation retains provenance for F3B lifecycle suppression'
);

delete from public.resource_saved_searches
where id = 'a9000000-0000-4000-8000-000000000009';
select is(
  (
    select count(*)
    from private.resource_saved_search_listing_matches
    where listing_id = 'b4000000-0000-4000-8000-000000000004'
  ),
  0::bigint,
  'deleting a search after matching cascades the private fact'
);
select is(
  (
    select count(*)
    from private.outbox_events
    where event_type = 'resource_saved_search.matched'
      and payload ->> 'listing_id' =
        'b4000000-0000-4000-8000-000000000004'
  ),
  1::bigint,
  'the identifier-only event may remain for F3B to suppress after fact deletion'
);

-- Deletion before source processing leaves no definition to reconstruct.
insert into public.resource_saved_searches (
  id, profile_id, query, created_at, updated_at
)
values (
  'aa000000-0000-4000-8000-00000000000a',
  'fa000000-0000-4000-8000-000000000001',
  'Deleted Before',
  '2026-04-01 08:00:00+00', '2026-04-01 08:00:00+00'
);
insert into public.resource_listings (
  id, owner_profile_id, listing_mode, lifecycle_state, title, description,
  country_code, locality, public_location_label, created_at, updated_at,
  published_at
)
values (
  'b5000000-0000-4000-8000-000000000005',
  'fc000000-0000-4000-8000-000000000003',
  'donate', 'published', 'Deleted Before', 'Deletion fixture', 'IT',
  'Torino', 'Torino',
  '2026-04-01 09:00:00+00', '2026-04-02 09:00:00+00',
  '2026-04-02 09:00:00+00'
);
insert into private.outbox_events (
  id, event_type, payload, created_at, available_at
)
values (
  'c5000000-0000-4000-8000-000000000005',
  'resource_listing.published',
  jsonb_build_object(
    'listing_id', 'b5000000-0000-4000-8000-000000000005',
    'owner_profile_id', 'fc000000-0000-4000-8000-000000000003',
    'listing_mode', 'donate'
  ),
  '2026-04-02 09:00:00+00', '2026-04-02 09:00:00+00'
);
delete from public.resource_saved_searches
where id = 'aa000000-0000-4000-8000-00000000000a';

set local role service_role;
select results_eq(
  $$select * from public.process_resource_saved_search_matching_outbox_batch(100)$$,
  $$values (1, 0, 0)$$,
  'a saved search deleted before processing creates no match'
);

reset role;

-- Closing before delayed processing is a valid zero-match success.
insert into public.resource_saved_searches (
  id, profile_id, query, created_at, updated_at
)
values (
  'ab000000-0000-4000-8000-00000000000b',
  'fa000000-0000-4000-8000-000000000001',
  'Closed Before',
  '2026-05-01 08:00:00+00', '2026-05-01 08:00:00+00'
);
insert into public.resource_listings (
  id, owner_profile_id, listing_mode, lifecycle_state, title, description,
  country_code, locality, public_location_label, created_at, updated_at,
  published_at, closed_at
)
values (
  'b6000000-0000-4000-8000-000000000006',
  'fc000000-0000-4000-8000-000000000003',
  'exchange', 'closed', 'Closed Before', 'Closed fixture', 'IT',
  'Bologna', 'Bologna',
  '2026-05-01 09:00:00+00', '2026-05-02 10:00:00+00',
  '2026-05-02 09:00:00+00', '2026-05-02 10:00:00+00'
);
insert into private.outbox_events (
  id, event_type, payload, created_at, available_at
)
values (
  'c6000000-0000-4000-8000-000000000006',
  'resource_listing.published',
  jsonb_build_object(
    'listing_id', 'b6000000-0000-4000-8000-000000000006',
    'owner_profile_id', 'fc000000-0000-4000-8000-000000000003',
    'listing_mode', 'exchange'
  ),
  '2026-05-02 09:00:00+00', '2026-05-02 09:00:00+00'
);

set local role service_role;
select results_eq(
  $$select * from public.process_resource_saved_search_matching_outbox_batch(100)$$,
  $$values (1, 0, 0)$$,
  'a listing closed before processing is receipted without a stale match'
);

reset role;
select is(
  (
    select count(*)
    from private.outbox_consumer_receipts
    where outbox_event_id = 'c6000000-0000-4000-8000-000000000006'
      and consumer_key = 'saved-search-matching.v1'
  ),
  1::bigint,
  'closed-before-processing is a successful zero-match source receipt'
);

-- Canonical identity inconsistencies fail atomically and remain retryable.
insert into public.resource_listings (
  id, owner_profile_id, listing_mode, lifecycle_state, title, description,
  country_code, locality, public_location_label, created_at, updated_at,
  published_at
)
values (
  'b7000000-0000-4000-8000-000000000007',
  'fc000000-0000-4000-8000-000000000003',
  'donate', 'published', 'Payload Guard', 'Identity fixture', 'IT',
  'Genova', 'Genova',
  '2026-06-01 09:00:00+00', '2026-06-02 09:00:00+00',
  '2026-06-02 09:00:00+00'
);
insert into private.outbox_events (
  id, event_type, payload, created_at, available_at
)
values (
  'c7000000-0000-4000-8000-000000000007',
  'resource_listing.published',
  jsonb_build_object(
    'listing_id', 'b7000000-0000-4000-8000-000000000007',
    'owner_profile_id', 'fb000000-0000-4000-8000-000000000002',
    'listing_mode', 'donate'
  ),
  '2026-06-02 09:00:00+00', '2026-06-02 09:00:00+00'
);

set local role service_role;
select throws_ok(
  $$select * from public.process_resource_saved_search_matching_outbox_batch(100)$$,
  '55000',
  'Saved-search matching could not validate outbox event c7000000-0000-4000-8000-000000000007 against its canonical resource listing.',
  'a wrong payload owner fails visibly'
);

reset role;
select is(
  (
    select count(*)
    from private.outbox_consumer_receipts
    where outbox_event_id = 'c7000000-0000-4000-8000-000000000007'
      and consumer_key = 'saved-search-matching.v1'
  ),
  0::bigint,
  'a wrong payload owner is not success-receipted'
);
delete from private.outbox_events
where id = 'c7000000-0000-4000-8000-000000000007';

insert into private.outbox_events (
  id, event_type, payload, created_at, available_at
)
values (
  'c8000000-0000-4000-8000-000000000008',
  'resource_listing.published',
  jsonb_build_object(
    'listing_id', 'b7000000-0000-4000-8000-000000000007',
    'owner_profile_id', 'fc000000-0000-4000-8000-000000000003',
    'listing_mode', 'exchange'
  ),
  '2026-06-02 09:01:00+00', '2026-06-02 09:01:00+00'
);

set local role service_role;
select throws_ok(
  $$select * from public.process_resource_saved_search_matching_outbox_batch(100)$$,
  '55000',
  'Saved-search matching could not validate outbox event c8000000-0000-4000-8000-000000000008 against its canonical resource listing.',
  'a wrong payload mode fails visibly'
);

reset role;
delete from private.outbox_events
where id = 'c8000000-0000-4000-8000-000000000008';
insert into private.outbox_events (
  id, event_type, payload, created_at, available_at
)
values (
  'c9000000-0000-4000-8000-000000000009',
  'resource_listing.published',
  jsonb_build_object(
    'listing_id', 'b9000000-0000-4000-8000-000000000009',
    'owner_profile_id', 'fc000000-0000-4000-8000-000000000003',
    'listing_mode', 'donate'
  ),
  '2026-06-02 09:02:00+00', '2026-06-02 09:02:00+00'
);

set local role service_role;
select throws_ok(
  $$select * from public.process_resource_saved_search_matching_outbox_batch(100)$$,
  '55000',
  'Saved-search matching could not validate outbox event c9000000-0000-4000-8000-000000000009 against its canonical resource listing.',
  'an unknown payload listing identity fails visibly'
);

reset role;
select is(
  (
    select count(*)
    from private.outbox_consumer_receipts
    where outbox_event_id = 'c9000000-0000-4000-8000-000000000009'
      and consumer_key = 'saved-search-matching.v1'
  ),
  0::bigint,
  'an unknown payload listing remains retryable without a receipt'
);
delete from private.outbox_events
where id = 'c9000000-0000-4000-8000-000000000009';

-- Batch size one preserves source chronology; size one hundred accepts the
-- remainder. No searches remain that can match these fixtures.
delete from public.resource_saved_searches;
insert into public.resource_listings (
  id, owner_profile_id, listing_mode, lifecycle_state, title, description,
  country_code, locality, public_location_label, created_at, updated_at,
  published_at
)
values
  (
    'b8000000-0000-4000-8000-000000000008',
    'fc000000-0000-4000-8000-000000000003',
    'donate', 'published', 'Batch First', 'Batch fixture', 'IT',
    'Pisa', 'Pisa',
    '2026-07-01 09:00:00+00', '2026-07-02 09:00:00+00',
    '2026-07-02 09:00:00+00'
  ),
  (
    'b9000000-0000-4000-8000-000000000009',
    'fc000000-0000-4000-8000-000000000003',
    'donate', 'published', 'Batch Second', 'Batch fixture', 'IT',
    'Pisa', 'Pisa',
    '2026-07-01 09:01:00+00', '2026-07-02 09:01:00+00',
    '2026-07-02 09:01:00+00'
  );
insert into private.outbox_events (
  id, event_type, payload, created_at, available_at
)
values
  (
    'ca000000-0000-4000-8000-00000000000a',
    'resource_listing.published',
    jsonb_build_object(
      'listing_id', 'b8000000-0000-4000-8000-000000000008',
      'owner_profile_id', 'fc000000-0000-4000-8000-000000000003',
      'listing_mode', 'donate'
    ),
    '2026-07-02 09:00:00+00', '2026-07-02 09:00:00+00'
  ),
  (
    'cb000000-0000-4000-8000-00000000000b',
    'resource_listing.published',
    jsonb_build_object(
      'listing_id', 'b9000000-0000-4000-8000-000000000009',
      'owner_profile_id', 'fc000000-0000-4000-8000-000000000003',
      'listing_mode', 'donate'
    ),
    '2026-07-02 09:01:00+00', '2026-07-02 09:01:00+00'
  );

set local role service_role;
select results_eq(
  $$select * from public.process_resource_saved_search_matching_outbox_batch(1)$$,
  $$values (1, 0, 0)$$,
  'the lower valid batch bound processes one source'
);

reset role;
select ok(
  exists (
    select 1
    from private.outbox_consumer_receipts
    where outbox_event_id = 'ca000000-0000-4000-8000-00000000000a'
      and consumer_key = 'saved-search-matching.v1'
  )
  and not exists (
    select 1
    from private.outbox_consumer_receipts
    where outbox_event_id = 'cb000000-0000-4000-8000-00000000000b'
      and consumer_key = 'saved-search-matching.v1'
  ),
  'batch size one receipts the oldest available source first'
);

set local role service_role;
select results_eq(
  $$select * from public.process_resource_saved_search_matching_outbox_batch(100)$$,
  $$values (1, 0, 0)$$,
  'the upper valid batch bound processes the remaining source'
);

select * from finish();

rollback;
