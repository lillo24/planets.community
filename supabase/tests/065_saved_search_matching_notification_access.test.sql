begin;

select no_plan();

insert into auth.users (id, email)
values
  ('f1000000-0000-4000-8000-000000000001', 'matching-alert-a@planets.invalid'),
  ('f2000000-0000-4000-8000-000000000002', 'matching-alert-b@planets.invalid'),
  ('f3000000-0000-4000-8000-000000000003', 'matching-alert-owner@planets.invalid');

insert into public.profiles (id, display_name)
values
  ('f1000000-0000-4000-8000-000000000001', 'Matching Alert A'),
  ('f2000000-0000-4000-8000-000000000002', 'Matching Alert B'),
  ('f3000000-0000-4000-8000-000000000003', 'Matching Listing Owner');

insert into public.resource_saved_searches (
  id, profile_id, query, listing_mode, locality, created_at, updated_at
)
values
  (
    'a1000000-0000-4000-8000-000000000001',
    'f1000000-0000-4000-8000-000000000001',
    'drill', null, null,
    '2026-08-01 08:00:00+00', '2026-08-01 08:00:00+00'
  ),
  (
    'a2000000-0000-4000-8000-000000000002',
    'f1000000-0000-4000-8000-000000000001',
    null, 'donate', null,
    '2026-08-01 08:01:00+00', '2026-08-01 08:01:00+00'
  ),
  (
    'a9000000-0000-4000-8000-000000000009',
    'f2000000-0000-4000-8000-000000000002',
    'historical', null, null,
    '2026-08-01 08:02:00+00', '2026-08-01 08:02:00+00'
  );

insert into public.resource_listings (
  id, owner_profile_id, listing_mode, lifecycle_state, title, description,
  country_code, locality, public_location_label, created_at, updated_at,
  published_at
)
values
  (
    'b1000000-0000-4000-8000-000000000001',
    'f3000000-0000-4000-8000-000000000003',
    'donate', 'published', 'Cordless Drill', 'Battery and charger',
    'IT', 'Trento', 'Trento',
    '2026-08-01 08:30:00+00', '2026-08-01 09:00:00+00',
    '2026-08-01 09:00:00+00'
  ),
  (
    'b9000000-0000-4000-8000-000000000009',
    'f3000000-0000-4000-8000-000000000003',
    'donate', 'published', 'Historical toolbox', 'Historical fixture',
    'IT', 'Trento', 'Trento',
    '2026-08-01 08:20:00+00', '2026-08-01 08:45:00+00',
    '2026-08-01 08:45:00+00'
  );

insert into private.outbox_events (
  id, event_type, payload, created_at, available_at
)
values
  (
    'c1000000-0000-4000-8000-000000000001',
    'resource_listing.published',
    jsonb_build_object(
      'listing_id', 'b1000000-0000-4000-8000-000000000001',
      'owner_profile_id', 'f3000000-0000-4000-8000-000000000003',
      'listing_mode', 'donate'
    ),
    '2026-08-01 09:00:00+00', '2026-08-01 09:00:00+00'
  ),
  (
    'c9000000-0000-4000-8000-000000000009',
    'resource_listing.published',
    jsonb_build_object(
      'listing_id', 'b9000000-0000-4000-8000-000000000009',
      'owner_profile_id', 'f3000000-0000-4000-8000-000000000003',
      'listing_mode', 'donate'
    ),
    '2026-08-01 08:45:00+00', '2026-08-01 08:45:00+00'
  );

insert into private.resource_saved_search_listing_matches (
  id, source_outbox_event_id, saved_search_id, saved_search_updated_at,
  recipient_profile_id, listing_id, matched_at
)
values
  (
    'd1000000-0000-4000-8000-000000000001',
    'c1000000-0000-4000-8000-000000000001',
    'a1000000-0000-4000-8000-000000000001',
    '2026-08-01 08:00:00+00',
    'f1000000-0000-4000-8000-000000000001',
    'b1000000-0000-4000-8000-000000000001',
    '2026-08-01 09:00:00+00'
  ),
  (
    'd2000000-0000-4000-8000-000000000002',
    'c1000000-0000-4000-8000-000000000001',
    'a2000000-0000-4000-8000-000000000002',
    '2026-08-01 08:01:00+00',
    'f1000000-0000-4000-8000-000000000001',
    'b1000000-0000-4000-8000-000000000001',
    '2026-08-01 09:00:00+00'
  ),
  (
    'd9000000-0000-4000-8000-000000000009',
    'c9000000-0000-4000-8000-000000000009',
    'a9000000-0000-4000-8000-000000000009',
    '2026-08-01 08:02:00+00',
    'f2000000-0000-4000-8000-000000000002',
    'b9000000-0000-4000-8000-000000000009',
    '2026-08-01 08:45:00+00'
  );

insert into private.outbox_events (
  id, event_type, payload, created_at, available_at
)
values
  (
    'e1000000-0000-4000-8000-000000000001',
    'resource_saved_search.matched',
    jsonb_build_object(
      'saved_search_match_id', 'd1000000-0000-4000-8000-000000000001',
      'saved_search_id', 'a1000000-0000-4000-8000-000000000001',
      'recipient_profile_id', 'f1000000-0000-4000-8000-000000000001',
      'listing_id', 'b1000000-0000-4000-8000-000000000001'
    ),
    '2026-08-01 09:00:00+00', '2026-08-01 09:00:00+00'
  ),
  (
    'e2000000-0000-4000-8000-000000000002',
    'resource_saved_search.matched',
    jsonb_build_object(
      'saved_search_match_id', 'd2000000-0000-4000-8000-000000000002',
      'saved_search_id', 'a2000000-0000-4000-8000-000000000002',
      'recipient_profile_id', 'f1000000-0000-4000-8000-000000000001',
      'listing_id', 'b1000000-0000-4000-8000-000000000001'
    ),
    '2026-08-01 09:00:00+00', '2026-08-01 09:00:00+00'
  ),
  (
    'e9000000-0000-4000-8000-000000000009',
    'resource_saved_search.matched',
    jsonb_build_object(
      'saved_search_match_id', 'd9000000-0000-4000-8000-000000000009',
      'saved_search_id', 'a9000000-0000-4000-8000-000000000009',
      'recipient_profile_id', 'f2000000-0000-4000-8000-000000000002',
      'listing_id', 'b9000000-0000-4000-8000-000000000009'
    ),
    '2026-08-01 08:45:00+00', '2026-08-01 08:45:00+00'
  );

-- Simulates the migration-time no-backfill boundary.
insert into private.outbox_consumer_receipts (
  outbox_event_id, consumer_key, processed_at
)
values
  (
    'e9000000-0000-4000-8000-000000000009',
    'notifications.v1',
    '2026-08-01 10:00:00+00'
  ),
  (
    'e9000000-0000-4000-8000-000000000009',
    'push.v1',
    '2026-08-01 10:00:00+00'
  );

select results_eq(
  $$
    select
      category_slug,
      notification_kind,
      recipient_profile_id,
      actor_profile_id,
      project_id,
      project_kind,
      request_id,
      membership_id,
      chat_id,
      message_id,
      resource_listing_id,
      resource_request_id,
      resource_chat_id,
      resource_chat_message_id,
      resource_agreement_id,
      resource_agreement_event_id,
      destination_kind,
      source_created_at
    from private.resolve_saved_search_matching_notification_event(
      'e1000000-0000-4000-8000-000000000001'
    )
  $$,
  $$
    values (
      'matching'::text,
      'matching_available'::text,
      'f1000000-0000-4000-8000-000000000001'::uuid,
      null::uuid,
      null::uuid,
      null::text,
      null::uuid,
      null::uuid,
      null::uuid,
      null::uuid,
      'b1000000-0000-4000-8000-000000000001'::uuid,
      null::uuid,
      null::uuid,
      null::uuid,
      null::uuid,
      null::uuid,
      'matching_result'::text,
      '2026-08-01 09:00:00+00'::timestamptz
    )
  $$,
  'a valid current match resolves to one listing-only semantic row'
);

set local role service_role;
select results_eq(
  $$select * from public.process_notification_outbox_batch(100)$$,
  $$values (2, 1, 1)$$,
  'two same-listing match events create one immediate notification and suppress one duplicate'
);
select results_eq(
  $$select * from public.process_push_outbox_batch(100)$$,
  $$values (2, 1, 1)$$,
  'two same-listing match events create one immediate push job and suppress one duplicate'
);

reset role;
select is(
  (
    select count(*)
    from public.notifications
    where category_slug = 'matching'
      and recipient_profile_id =
        'f1000000-0000-4000-8000-000000000001'
      and resource_listing_id =
        'b1000000-0000-4000-8000-000000000001'
  ),
  1::bigint,
  'same-listing saved-search matches deduplicate only at in-app delivery'
);
select is(
  (
    select count(*)
    from private.push_delivery_jobs
    where category_slug = 'matching'
      and recipient_profile_id =
        'f1000000-0000-4000-8000-000000000001'
      and resource_listing_id =
        'b1000000-0000-4000-8000-000000000001'
  ),
  1::bigint,
  'same-listing saved-search matches deduplicate only at push eligibility'
);
select is(
  (
    select count(*)
    from private.resource_saved_search_listing_matches
    where listing_id = 'b1000000-0000-4000-8000-000000000001'
  ),
  2::bigint,
  'both underlying match facts remain intact'
);
select is(
  (
    select count(*)
    from private.outbox_events
    where id in (
      'e1000000-0000-4000-8000-000000000001',
      'e2000000-0000-4000-8000-000000000002'
    )
      and event_type = 'resource_saved_search.matched'
  ),
  2::bigint,
  'both underlying match events remain intact'
);
select is(
  (
    select count(*)
    from private.outbox_consumer_receipts
    where outbox_event_id in (
      'e1000000-0000-4000-8000-000000000001',
      'e2000000-0000-4000-8000-000000000002'
    )
      and consumer_key in ('notifications.v1', 'push.v1')
  ),
  4::bigint,
  'each duplicate source is independently receipted by both channels'
);
select ok(
  exists (
    select 1
    from public.notifications
    where category_slug = 'matching'
      and notification_kind = 'matching_available'
      and destination_kind = 'matching_result'
      and created_at = '2026-08-01 09:00:00+00'
      and actor_profile_id is null
      and project_id is null
      and request_id is null
      and membership_id is null
      and chat_id is null
      and message_id is null
      and resource_listing_id =
        'b1000000-0000-4000-8000-000000000001'
      and resource_request_id is null
      and resource_chat_id is null
      and resource_chat_message_id is null
      and resource_agreement_id is null
      and resource_agreement_event_id is null
  ),
  'the notification stores exact matching semantics and source chronology'
);
select ok(
  exists (
    select 1
    from private.push_delivery_jobs
    where category_slug = 'matching'
      and notification_kind = 'matching_available'
      and destination_kind = 'matching_result'
      and created_at = '2026-08-01 09:00:00+00'
      and available_at >= created_at
      and actor_profile_id is null
      and project_id is null
      and project_kind is null
      and request_id is null
      and membership_id is null
      and chat_id is null
      and message_id is null
      and resource_listing_id =
        'b1000000-0000-4000-8000-000000000001'
      and resource_request_id is null
      and resource_chat_id is null
      and resource_chat_message_id is null
      and resource_agreement_id is null
      and resource_agreement_event_id is null
  ),
  'the immediately available push job stores the same body-free context'
);
select is(
  (
    select count(*)
    from public.notifications
    where source_outbox_event_id =
      'e9000000-0000-4000-8000-000000000009'
  ) + (
    select count(*)
    from private.push_delivery_jobs
    where source_outbox_event_id =
      'e9000000-0000-4000-8000-000000000009'
  ),
  0::bigint,
  'pre-receipted historical match events create no alert or push job'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'f1000000-0000-4000-8000-000000000001',
  true
);
select results_eq(
  $$
    select
      category_slug,
      notification_kind,
      destination_kind,
      resource_listing_id,
      resource_listing_title,
      actor_profile_id,
      project_id,
      request_id,
      resource_request_id,
      resource_agreement_id
    from public.list_own_notifications(
      'f1000000-0000-4000-8000-000000000001',
      20,
      null,
      null
    )
    where category_slug = 'matching'
  $$,
  $$
    values (
      'matching'::text,
      'matching_available'::text,
      'matching_result'::text,
      'b1000000-0000-4000-8000-000000000001'::uuid,
      'Cordless Drill'::text,
      null::uuid,
      null::uuid,
      null::uuid,
      null::uuid,
      null::uuid
    )
  $$,
  'the existing inbox returns current safe listing context and no unrelated references'
);

reset role;

-- A second listing remains a distinct alert for the same saved search.
insert into public.resource_listings (
  id, owner_profile_id, listing_mode, lifecycle_state, title, description,
  country_code, locality, public_location_label, created_at, updated_at,
  published_at
)
values (
  'b2000000-0000-4000-8000-000000000002',
  'f3000000-0000-4000-8000-000000000003',
  'donate', 'published', 'Garden Drill', 'Second listing fixture',
  'IT', 'Trento', 'Trento',
  '2026-08-01 09:30:00+00', '2026-08-01 10:00:00+00',
  '2026-08-01 10:00:00+00'
);
insert into private.outbox_events (
  id, event_type, payload, created_at, available_at
)
values
  (
    'c3000000-0000-4000-8000-000000000003',
    'resource_listing.published', '{}'::jsonb,
    '2026-08-01 10:00:00+00', '2026-08-01 10:00:00+00'
  ),
  (
    'e3000000-0000-4000-8000-000000000003',
    'resource_saved_search.matched',
    jsonb_build_object(
      'saved_search_match_id', 'd3000000-0000-4000-8000-000000000003',
      'saved_search_id', 'a1000000-0000-4000-8000-000000000001',
      'recipient_profile_id', 'f1000000-0000-4000-8000-000000000001',
      'listing_id', 'b2000000-0000-4000-8000-000000000002'
    ),
    '2026-08-01 10:00:00+00', '2026-08-01 10:00:00+00'
  );
insert into private.resource_saved_search_listing_matches (
  id, source_outbox_event_id, saved_search_id, saved_search_updated_at,
  recipient_profile_id, listing_id, matched_at
)
values (
  'd3000000-0000-4000-8000-000000000003',
  'c3000000-0000-4000-8000-000000000003',
  'a1000000-0000-4000-8000-000000000001',
  '2026-08-01 08:00:00+00',
  'f1000000-0000-4000-8000-000000000001',
  'b2000000-0000-4000-8000-000000000002',
  '2026-08-01 10:00:00+00'
);

set local role service_role;
select results_eq(
  $$select * from public.process_notification_outbox_batch(100)$$,
  $$values (1, 1, 0)$$,
  'a different matching listing creates its own notification'
);
select results_eq(
  $$select * from public.process_push_outbox_batch(100)$$,
  $$values (1, 1, 0)$$,
  'a different matching listing creates its own push job'
);
select results_eq(
  $$select * from public.process_notification_outbox_batch(100)$$,
  $$values (0, 0, 0)$$,
  'notification projection is idempotent after receipts'
);
select results_eq(
  $$select * from public.process_push_outbox_batch(100)$$,
  $$values (0, 0, 0)$$,
  'push projection is idempotent after receipts'
);

reset role;
select is(
  (
    select count(*)
    from public.notifications
    where recipient_profile_id =
      'f1000000-0000-4000-8000-000000000001'
      and category_slug = 'matching'
  ),
  2::bigint,
  'recipient/listing dedupe does not collapse different listings'
);

-- Channel preferences remain global to Matching and independent.
insert into public.profile_notification_preferences (
  profile_id, category_slug, in_app_enabled, push_enabled
)
values (
  'f2000000-0000-4000-8000-000000000002',
  'matching', false, true
);
insert into public.resource_saved_searches (
  id, profile_id, query, created_at, updated_at
)
values (
  'a4000000-0000-4000-8000-000000000004',
  'f2000000-0000-4000-8000-000000000002',
  'wrench',
  '2026-08-02 08:00:00+00', '2026-08-02 08:00:00+00'
);
insert into public.resource_listings (
  id, owner_profile_id, listing_mode, lifecycle_state, title, description,
  country_code, locality, public_location_label, created_at, updated_at,
  published_at
)
values
  (
    'b3000000-0000-4000-8000-000000000003',
    'f3000000-0000-4000-8000-000000000003',
    'exchange', 'published', 'Steel Wrench', 'Channel fixture one',
    'IT', 'Torino', 'Torino',
    '2026-08-02 08:30:00+00', '2026-08-02 09:00:00+00',
    '2026-08-02 09:00:00+00'
  ),
  (
    'b4000000-0000-4000-8000-000000000004',
    'f3000000-0000-4000-8000-000000000003',
    'exchange', 'published', 'Socket Wrench', 'Channel fixture two',
    'IT', 'Torino', 'Torino',
    '2026-08-02 09:30:00+00', '2026-08-02 10:00:00+00',
    '2026-08-02 10:00:00+00'
  );
insert into private.outbox_events (
  id, event_type, payload, created_at, available_at
)
values
  ('c4000000-0000-4000-8000-000000000004', 'resource_listing.published', '{}'::jsonb, '2026-08-02 09:00:00+00', '2026-08-02 09:00:00+00'),
  ('c5000000-0000-4000-8000-000000000005', 'resource_listing.published', '{}'::jsonb, '2026-08-02 10:00:00+00', '2026-08-02 10:00:00+00');
insert into private.resource_saved_search_listing_matches (
  id, source_outbox_event_id, saved_search_id, saved_search_updated_at,
  recipient_profile_id, listing_id, matched_at
)
values
  ('d4000000-0000-4000-8000-000000000004', 'c4000000-0000-4000-8000-000000000004', 'a4000000-0000-4000-8000-000000000004', '2026-08-02 08:00:00+00', 'f2000000-0000-4000-8000-000000000002', 'b3000000-0000-4000-8000-000000000003', '2026-08-02 09:00:00+00'),
  ('d5000000-0000-4000-8000-000000000005', 'c5000000-0000-4000-8000-000000000005', 'a4000000-0000-4000-8000-000000000004', '2026-08-02 08:00:00+00', 'f2000000-0000-4000-8000-000000000002', 'b4000000-0000-4000-8000-000000000004', '2026-08-02 10:00:00+00');
insert into private.outbox_events (
  id, event_type, payload, created_at, available_at
)
values (
  'e4000000-0000-4000-8000-000000000004',
  'resource_saved_search.matched',
  jsonb_build_object(
    'saved_search_match_id', 'd4000000-0000-4000-8000-000000000004',
    'saved_search_id', 'a4000000-0000-4000-8000-000000000004',
    'recipient_profile_id', 'f2000000-0000-4000-8000-000000000002',
    'listing_id', 'b3000000-0000-4000-8000-000000000003'
  ),
  '2026-08-02 09:00:00+00', '2026-08-02 09:00:00+00'
);

set local role service_role;
select results_eq(
  $$select * from public.process_notification_outbox_batch(100)$$,
  $$values (1, 0, 1)$$,
  'disabled Matching in-app preference suppresses and receipts immediately'
);
select results_eq(
  $$select * from public.process_push_outbox_batch(100)$$,
  $$values (1, 1, 0)$$,
  'enabled Matching push preference remains independent'
);

reset role;
update public.profile_notification_preferences
set in_app_enabled = true, push_enabled = false
where profile_id = 'f2000000-0000-4000-8000-000000000002'
  and category_slug = 'matching';
insert into private.outbox_events (
  id, event_type, payload, created_at, available_at
)
values (
  'e5000000-0000-4000-8000-000000000005',
  'resource_saved_search.matched',
  jsonb_build_object(
    'saved_search_match_id', 'd5000000-0000-4000-8000-000000000005',
    'saved_search_id', 'a4000000-0000-4000-8000-000000000004',
    'recipient_profile_id', 'f2000000-0000-4000-8000-000000000002',
    'listing_id', 'b4000000-0000-4000-8000-000000000004'
  ),
  '2026-08-02 10:00:00+00', '2026-08-02 10:00:00+00'
);

set local role service_role;
select results_eq(
  $$select * from public.process_notification_outbox_batch(100)$$,
  $$values (1, 1, 0)$$,
  'enabled Matching in-app preference creates the next listing alert'
);
select results_eq(
  $$select * from public.process_push_outbox_batch(100)$$,
  $$values (1, 0, 1)$$,
  'disabled Matching push preference suppresses independently'
);

reset role;
select is(
  (
    select count(*)
    from public.notifications
    where source_outbox_event_id =
      'e4000000-0000-4000-8000-000000000004'
  ),
  0::bigint,
  're-enabling in-app matching does not backfill an already receipted source'
);
select is(
  (
    select count(*)
    from private.outbox_consumer_receipts
    where outbox_event_id in (
      'e4000000-0000-4000-8000-000000000004',
      'e5000000-0000-4000-8000-000000000005'
    )
      and consumer_key in ('notifications.v1', 'push.v1')
  ),
  4::bigint,
  'both preference outcomes produce both independent receipts'
);

-- Stale search versions resolve to zero and are still successfully receipted.
insert into public.resource_saved_searches (
  id, profile_id, query, created_at, updated_at
)
values (
  'a6000000-0000-4000-8000-000000000006',
  'f1000000-0000-4000-8000-000000000001',
  'plane',
  '2026-08-03 08:00:00+00', '2026-08-03 08:00:00+00'
);
insert into public.resource_listings (
  id, owner_profile_id, listing_mode, lifecycle_state, title, description,
  country_code, locality, public_location_label, created_at, updated_at,
  published_at
)
values (
  'b6000000-0000-4000-8000-000000000006',
  'f3000000-0000-4000-8000-000000000003',
  'donate', 'published', 'Wood Plane', 'Stale version fixture',
  'IT', 'Roma', 'Roma',
  '2026-08-03 08:30:00+00', '2026-08-03 09:00:00+00',
  '2026-08-03 09:00:00+00'
);
insert into private.outbox_events (id, event_type, payload, created_at, available_at)
values ('c6000000-0000-4000-8000-000000000006', 'resource_listing.published', '{}'::jsonb, '2026-08-03 09:00:00+00', '2026-08-03 09:00:00+00');
insert into private.resource_saved_search_listing_matches (
  id, source_outbox_event_id, saved_search_id, saved_search_updated_at,
  recipient_profile_id, listing_id, matched_at
)
values ('d6000000-0000-4000-8000-000000000006', 'c6000000-0000-4000-8000-000000000006', 'a6000000-0000-4000-8000-000000000006', '2026-08-03 08:00:00+00', 'f1000000-0000-4000-8000-000000000001', 'b6000000-0000-4000-8000-000000000006', '2026-08-03 09:00:00+00');
insert into private.outbox_events (id, event_type, payload, created_at, available_at)
values (
  'e6000000-0000-4000-8000-000000000006',
  'resource_saved_search.matched',
  jsonb_build_object(
    'saved_search_match_id', 'd6000000-0000-4000-8000-000000000006',
    'saved_search_id', 'a6000000-0000-4000-8000-000000000006',
    'recipient_profile_id', 'f1000000-0000-4000-8000-000000000001',
    'listing_id', 'b6000000-0000-4000-8000-000000000006'
  ),
  '2026-08-03 09:00:00+00', '2026-08-03 09:00:00+00'
);
update public.resource_saved_searches
set updated_at = '2026-08-03 09:01:00+00'
where id = 'a6000000-0000-4000-8000-000000000006';

select is_empty(
  $$
    select *
    from private.resolve_saved_search_matching_notification_event(
      'e6000000-0000-4000-8000-000000000006'
    )
  $$,
  'an edited search suppresses a fact captured for its prior version'
);

set local role service_role;
select results_eq(
  $$select processed_count, notifications_created from public.process_notification_outbox_batch(100)$$,
  $$values (1, 0)$$,
  'stale search notification projection is a successful zero-row source'
);
select results_eq(
  $$select processed_count, jobs_created from public.process_push_outbox_batch(100)$$,
  $$values (1, 0)$$,
  'stale search push projection is a successful zero-row source'
);

reset role;

-- Deleted searches cascade the fact; the resolver must not reconstruct payload context.
insert into public.resource_saved_searches (
  id, profile_id, query, created_at, updated_at
)
values ('a7000000-0000-4000-8000-000000000007', 'f1000000-0000-4000-8000-000000000001', 'deleted', '2026-08-04 08:00:00+00', '2026-08-04 08:00:00+00');
insert into public.resource_listings (
  id, owner_profile_id, listing_mode, lifecycle_state, title, description,
  country_code, locality, public_location_label, created_at, updated_at,
  published_at
)
values ('b7000000-0000-4000-8000-000000000007', 'f3000000-0000-4000-8000-000000000003', 'donate', 'published', 'Deleted fixture', 'Deleted search fixture', 'IT', 'Roma', 'Roma', '2026-08-04 08:30:00+00', '2026-08-04 09:00:00+00', '2026-08-04 09:00:00+00');
insert into private.outbox_events (id, event_type, payload, created_at, available_at)
values ('c7000000-0000-4000-8000-000000000007', 'resource_listing.published', '{}'::jsonb, '2026-08-04 09:00:00+00', '2026-08-04 09:00:00+00');
insert into private.resource_saved_search_listing_matches (
  id, source_outbox_event_id, saved_search_id, saved_search_updated_at,
  recipient_profile_id, listing_id, matched_at
)
values ('d7000000-0000-4000-8000-000000000007', 'c7000000-0000-4000-8000-000000000007', 'a7000000-0000-4000-8000-000000000007', '2026-08-04 08:00:00+00', 'f1000000-0000-4000-8000-000000000001', 'b7000000-0000-4000-8000-000000000007', '2026-08-04 09:00:00+00');
insert into private.outbox_events (id, event_type, payload, created_at, available_at)
values ('e7000000-0000-4000-8000-000000000007', 'resource_saved_search.matched', jsonb_build_object('saved_search_match_id', 'd7000000-0000-4000-8000-000000000007', 'saved_search_id', 'a7000000-0000-4000-8000-000000000007', 'recipient_profile_id', 'f1000000-0000-4000-8000-000000000001', 'listing_id', 'b7000000-0000-4000-8000-000000000007'), '2026-08-04 09:00:00+00', '2026-08-04 09:00:00+00');
delete from public.resource_saved_searches
where id = 'a7000000-0000-4000-8000-000000000007';

select is_empty(
  $$select * from private.resolve_saved_search_matching_notification_event('e7000000-0000-4000-8000-000000000007')$$,
  'a deleted search and cascaded fact produce no guessed semantic row'
);

set local role service_role;
select results_eq(
  $$select processed_count, notifications_created from public.process_notification_outbox_batch(100)$$,
  $$values (1, 0)$$,
  'deleted search notification source is receipted without reconstruction'
);
select results_eq(
  $$select processed_count, jobs_created from public.process_push_outbox_batch(100)$$,
  $$values (1, 0)$$,
  'deleted search push source is receipted without reconstruction'
);

reset role;

-- Current listing edits and closure suppress delivery before projection.
insert into public.resource_saved_searches (
  id, profile_id, query, created_at, updated_at
)
values
  ('a8000000-0000-4000-8000-000000000008', 'f1000000-0000-4000-8000-000000000001', 'needle', '2026-08-05 08:00:00+00', '2026-08-05 08:00:00+00'),
  ('aa000000-0000-4000-8000-00000000000a', 'f1000000-0000-4000-8000-000000000001', 'closed saw', '2026-08-05 08:01:00+00', '2026-08-05 08:01:00+00');
insert into public.resource_listings (
  id, owner_profile_id, listing_mode, lifecycle_state, title, description,
  country_code, locality, public_location_label, created_at, updated_at,
  published_at, closed_at
)
values
  ('b8000000-0000-4000-8000-000000000008', 'f3000000-0000-4000-8000-000000000003', 'donate', 'published', 'Needle set', 'Before-edit match', 'IT', 'Roma', 'Roma', '2026-08-05 08:30:00+00', '2026-08-05 09:00:00+00', '2026-08-05 09:00:00+00', null),
  ('ba000000-0000-4000-8000-00000000000a', 'f3000000-0000-4000-8000-000000000003', 'donate', 'closed', 'Closed Saw', 'Closed fixture', 'IT', 'Roma', 'Roma', '2026-08-05 08:31:00+00', '2026-08-05 09:05:00+00', '2026-08-05 09:00:00+00', '2026-08-05 09:05:00+00');
insert into private.outbox_events (id, event_type, payload, created_at, available_at)
values
  ('c8000000-0000-4000-8000-000000000008', 'resource_listing.published', '{}'::jsonb, '2026-08-05 09:00:00+00', '2026-08-05 09:00:00+00'),
  ('ca000000-0000-4000-8000-00000000000a', 'resource_listing.published', '{}'::jsonb, '2026-08-05 09:00:00+00', '2026-08-05 09:00:00+00');
insert into private.resource_saved_search_listing_matches (
  id, source_outbox_event_id, saved_search_id, saved_search_updated_at,
  recipient_profile_id, listing_id, matched_at
)
values
  ('d8000000-0000-4000-8000-000000000008', 'c8000000-0000-4000-8000-000000000008', 'a8000000-0000-4000-8000-000000000008', '2026-08-05 08:00:00+00', 'f1000000-0000-4000-8000-000000000001', 'b8000000-0000-4000-8000-000000000008', '2026-08-05 09:00:00+00'),
  ('da000000-0000-4000-8000-00000000000a', 'ca000000-0000-4000-8000-00000000000a', 'aa000000-0000-4000-8000-00000000000a', '2026-08-05 08:01:00+00', 'f1000000-0000-4000-8000-000000000001', 'ba000000-0000-4000-8000-00000000000a', '2026-08-05 09:00:00+00');
insert into private.outbox_events (id, event_type, payload, created_at, available_at)
values
  ('e8000000-0000-4000-8000-000000000008', 'resource_saved_search.matched', jsonb_build_object('saved_search_match_id', 'd8000000-0000-4000-8000-000000000008', 'saved_search_id', 'a8000000-0000-4000-8000-000000000008', 'recipient_profile_id', 'f1000000-0000-4000-8000-000000000001', 'listing_id', 'b8000000-0000-4000-8000-000000000008'), '2026-08-05 09:00:00+00', '2026-08-05 09:00:00+00'),
  ('ea000000-0000-4000-8000-00000000000a', 'resource_saved_search.matched', jsonb_build_object('saved_search_match_id', 'da000000-0000-4000-8000-00000000000a', 'saved_search_id', 'aa000000-0000-4000-8000-00000000000a', 'recipient_profile_id', 'f1000000-0000-4000-8000-000000000001', 'listing_id', 'ba000000-0000-4000-8000-00000000000a'), '2026-08-05 09:00:00+00', '2026-08-05 09:00:00+00');
update public.resource_listings
set title = 'Hammer set', description = 'No matching word remains'
where id = 'b8000000-0000-4000-8000-000000000008';

select is_empty(
  $$select * from private.resolve_saved_search_matching_notification_event('e8000000-0000-4000-8000-000000000008')$$,
  'a current listing edit that no longer matches suppresses delivery'
);
select is_empty(
  $$select * from private.resolve_saved_search_matching_notification_event('ea000000-0000-4000-8000-00000000000a')$$,
  'a listing closed before projection suppresses delivery'
);

set local role service_role;
select results_eq(
  $$select processed_count, notifications_created from public.process_notification_outbox_batch(100)$$,
  $$values (2, 0)$$,
  'edited and closed notification sources are both consumed without alerts'
);
select results_eq(
  $$select processed_count, jobs_created from public.process_push_outbox_batch(100)$$,
  $$values (2, 0)$$,
  'edited and closed push sources are both consumed without jobs'
);

reset role;

-- A created notification remains historical after its search is deleted and listing closes.
delete from public.resource_saved_searches
where id in (
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000002'
);
update public.resource_listings
set lifecycle_state = 'closed', closed_at = '2026-08-06 09:00:00+00'
where id = 'b1000000-0000-4000-8000-000000000001';
select is(
  (
    select count(*)
    from public.notifications
    where recipient_profile_id =
      'f1000000-0000-4000-8000-000000000001'
      and resource_listing_id =
        'b1000000-0000-4000-8000-000000000001'
  ),
  1::bigint,
  'validly created notification history survives later search deletion and listing closure'
);

-- Payload mismatches fail visibly and receive no success receipt.
insert into private.outbox_events (id, event_type, payload, created_at, available_at)
values (
  'eb000000-0000-4000-8000-00000000000b',
  'resource_saved_search.matched',
  jsonb_build_object(
    'saved_search_match_id', 'd9000000-0000-4000-8000-000000000009',
    'saved_search_id', 'a9000000-0000-4000-8000-000000000009',
    'recipient_profile_id', 'f1000000-0000-4000-8000-000000000001',
    'listing_id', 'b2000000-0000-4000-8000-000000000002'
  ),
  '2026-08-01 10:00:00+00', '2026-08-01 10:00:00+00'
);

select throws_ok(
  $$select * from private.resolve_saved_search_matching_notification_event('eb000000-0000-4000-8000-00000000000b')$$,
  '55000',
  'Saved-search matching notification event eb000000-0000-4000-8000-00000000000b diverges from its canonical match fact.',
  'a mismatched saved-search identifier fails canonical validation'
);
set local role service_role;
select throws_ok(
  $$select * from public.process_notification_outbox_batch(100)$$,
  '55000',
  'Saved-search matching notification event eb000000-0000-4000-8000-00000000000b diverges from its canonical match fact.',
  'projector failure remains visible for an inconsistent source'
);
reset role;
select is(
  (
    select count(*)
    from private.outbox_consumer_receipts
    where outbox_event_id = 'eb000000-0000-4000-8000-00000000000b'
  ),
  0::bigint,
  'an inconsistent source receives no channel receipt'
);
delete from private.outbox_events
where id = 'eb000000-0000-4000-8000-00000000000b';

insert into private.outbox_events (id, event_type, payload, created_at, available_at)
values
  (
    'ec000000-0000-4000-8000-00000000000c',
    'resource_saved_search.matched',
    jsonb_build_object(
      'saved_search_match_id', 'd3000000-0000-4000-8000-000000000003',
      'saved_search_id', 'a9000000-0000-4000-8000-000000000009',
      'recipient_profile_id', 'f1000000-0000-4000-8000-000000000001',
      'listing_id', 'b2000000-0000-4000-8000-000000000002',
      'query', 'private leak'
    ),
    '2026-08-01 10:00:00+00', '2026-08-01 10:00:00+00'
  ),
  (
    'ed000000-0000-4000-8000-00000000000d',
    'resource_saved_search.matched',
    jsonb_build_object(
      'saved_search_match_id', 'd3000000-0000-4000-8000-000000000003',
      'saved_search_id', 'a1000000-0000-4000-8000-000000000001',
      'recipient_profile_id', 'f1000000-0000-4000-8000-000000000001'
    ),
    '2026-08-01 10:00:00+00', '2026-08-01 10:00:00+00'
  ),
  (
    'ee000000-0000-4000-8000-00000000000e',
    'resource_saved_search.matched',
    jsonb_build_object(
      'saved_search_match_id', 'ffffffff-ffff-4fff-8fff-ffffffffffff',
      'saved_search_id', 'a9000000-0000-4000-8000-000000000009',
      'recipient_profile_id', 'f1000000-0000-4000-8000-000000000001',
      'listing_id', 'b2000000-0000-4000-8000-000000000002'
    ),
    '2026-08-01 10:00:00+00', '2026-08-01 10:00:00+00'
  ),
  (
    'e6100000-0000-4000-8000-000000000061',
    'resource_saved_search.matched',
    jsonb_build_object(
      'saved_search_match_id', 'not-a-uuid',
      'saved_search_id', 'a9000000-0000-4000-8000-000000000009',
      'recipient_profile_id', 'f1000000-0000-4000-8000-000000000001',
      'listing_id', 'b2000000-0000-4000-8000-000000000002'
    ),
    '2026-08-01 10:00:00+00', '2026-08-01 10:00:00+00'
  ),
  (
    'e6200000-0000-4000-8000-000000000062',
    'resource_saved_search.matched',
    jsonb_build_object(
      'saved_search_match_id', null,
      'saved_search_id', 'a9000000-0000-4000-8000-000000000009',
      'recipient_profile_id', 'f1000000-0000-4000-8000-000000000001',
      'listing_id', 'b2000000-0000-4000-8000-000000000002'
    ),
    '2026-08-01 10:00:00+00', '2026-08-01 10:00:00+00'
  );

select throws_ok(
  $$select * from private.resolve_saved_search_matching_notification_event('ec000000-0000-4000-8000-00000000000c')$$,
  '55000',
  'Saved-search matching notification event ec000000-0000-4000-8000-00000000000c has invalid identifier-only payload shape.',
  'additional payload keys fail closed'
);
select throws_ok(
  $$select * from private.resolve_saved_search_matching_notification_event('ed000000-0000-4000-8000-00000000000d')$$,
  '55000',
  'Saved-search matching notification event ed000000-0000-4000-8000-00000000000d has invalid identifier-only payload shape.',
  'missing payload keys fail closed'
);
select throws_ok(
  $$select * from private.resolve_saved_search_matching_notification_event('ee000000-0000-4000-8000-00000000000e')$$,
  '55000',
  'Saved-search matching notification event ee000000-0000-4000-8000-00000000000e references no canonical match fact for its current saved search.',
  'an unknown match fact for a current saved search fails visibly'
);
select throws_ok(
  $$select * from private.resolve_saved_search_matching_notification_event('e6100000-0000-4000-8000-000000000061')$$,
  '55000',
  'Saved-search matching notification event e6100000-0000-4000-8000-000000000061 has invalid identifiers.',
  'a non-UUID payload identifier fails closed'
);
select throws_ok(
  $$select * from private.resolve_saved_search_matching_notification_event('e6200000-0000-4000-8000-000000000062')$$,
  '55000',
  'Saved-search matching notification event e6200000-0000-4000-8000-000000000062 has invalid identifiers.',
  'a null payload identifier fails closed'
);
delete from private.outbox_events
where id in (
  'ec000000-0000-4000-8000-00000000000c',
  'ed000000-0000-4000-8000-00000000000d',
  'ee000000-0000-4000-8000-00000000000e',
  'e6100000-0000-4000-8000-000000000061',
  'e6200000-0000-4000-8000-000000000062'
);

-- An inconsistent self-owned fact is rejected rather than delivered.
insert into public.resource_saved_searches (
  id, profile_id, query, created_at, updated_at
)
values ('ab000000-0000-4000-8000-00000000000b', 'f3000000-0000-4000-8000-000000000003', 'self owned', '2026-08-07 08:00:00+00', '2026-08-07 08:00:00+00');
insert into public.resource_listings (
  id, owner_profile_id, listing_mode, lifecycle_state, title, description,
  country_code, locality, public_location_label, created_at, updated_at,
  published_at
)
values ('bb000000-0000-4000-8000-00000000000b', 'f3000000-0000-4000-8000-000000000003', 'donate', 'published', 'Self owned fixture', 'Invariant fixture', 'IT', 'Roma', 'Roma', '2026-08-07 08:30:00+00', '2026-08-07 09:00:00+00', '2026-08-07 09:00:00+00');
insert into private.outbox_events (id, event_type, payload, created_at, available_at)
values ('cb000000-0000-4000-8000-00000000000b', 'resource_listing.published', '{}'::jsonb, '2026-08-07 09:00:00+00', '2026-08-07 09:00:00+00');
insert into private.resource_saved_search_listing_matches (
  id, source_outbox_event_id, saved_search_id, saved_search_updated_at,
  recipient_profile_id, listing_id, matched_at
)
values ('db000000-0000-4000-8000-00000000000b', 'cb000000-0000-4000-8000-00000000000b', 'ab000000-0000-4000-8000-00000000000b', '2026-08-07 08:00:00+00', 'f3000000-0000-4000-8000-000000000003', 'bb000000-0000-4000-8000-00000000000b', '2026-08-07 09:00:00+00');
insert into private.outbox_events (id, event_type, payload, created_at, available_at)
values ('ef000000-0000-4000-8000-00000000000f', 'resource_saved_search.matched', jsonb_build_object('saved_search_match_id', 'db000000-0000-4000-8000-00000000000b', 'saved_search_id', 'ab000000-0000-4000-8000-00000000000b', 'recipient_profile_id', 'f3000000-0000-4000-8000-000000000003', 'listing_id', 'bb000000-0000-4000-8000-00000000000b'), '2026-08-07 09:00:00+00', '2026-08-07 09:00:00+00');

select throws_ok(
  $$select * from private.resolve_saved_search_matching_notification_event('ef000000-0000-4000-8000-00000000000f')$$,
  '55000',
  'Saved-search matching notification event ef000000-0000-4000-8000-00000000000f violates self-owner suppression.',
  'self-owner inconsistency fails visibly'
);

select * from finish();

rollback;
