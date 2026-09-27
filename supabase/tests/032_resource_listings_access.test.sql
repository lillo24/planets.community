begin;

select no_plan();

insert into auth.users (id, email)
values
  ('a1000000-0000-4000-8000-000000000001', 'listing-a@planets.invalid'),
  ('a2000000-0000-4000-8000-000000000002', 'listing-b@planets.invalid'),
  ('a3000000-0000-4000-8000-000000000003', 'listing-incomplete@planets.invalid');

insert into public.profiles (id, display_name)
values
  ('a1000000-0000-4000-8000-000000000001', 'Listing Owner A'),
  ('a2000000-0000-4000-8000-000000000002', 'Listing Owner B'),
  ('a3000000-0000-4000-8000-000000000003', null);

-- Ordinary legacy listing scenarios are not trust-gate negatives. Dedicated
-- 08A4B coverage exercises missing photos explicitly.
insert into public.profile_photos (profile_id, object_path, audience)
select
  profile.id,
  profile.id::text || '/' || profile.id::text || '.webp',
  'interactions'
from public.profiles as profile
where profile.id in (
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000002',
  'a3000000-0000-4000-8000-000000000003'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a3000000-0000-4000-8000-000000000003',
  true
);

select throws_ok(
  $$
    select public.create_resource_listing_draft(
      'a3000000-0000-4000-8000-000000000003',
      'donate', null, null, null, null, null, null
    )
  $$,
  '55000',
  'A complete profile is required to create or publish a resource listing.',
  'an incomplete profile cannot create a listing draft'
);

select set_config(
  'request.jwt.claim.sub',
  'a1000000-0000-4000-8000-000000000001',
  true
);

select throws_ok(
  $$
    select public.create_resource_listing_draft(
      'a1000000-0000-4000-8000-000000000001',
      'loan', null, null, null, null, null, null
    )
  $$,
  '22023',
  'Resource listing mode must be donate or exchange.',
  'draft creation rejects a transaction-like mode outside donate and exchange'
);

select set_config(
  'test.partial_listing_id',
  public.create_resource_listing_draft(
    'a1000000-0000-4000-8000-000000000001',
    ' DONATE ',
    '  Early item idea  ',
    null,
    null,
    null,
    null,
    null
  )::text,
  true
);

reset role;

select results_eq(
  $$
    select listing_mode, lifecycle_state, title, description
    from public.resource_listings
    where id = current_setting('test.partial_listing_id')::uuid
  $$,
  $$values ('donate'::text, 'draft'::text, 'Early item idea'::text, null::text)$$,
  'a complete-profile owner creates a canonically trimmed incomplete draft'
);
select is(
  (
    select count(*)
    from private.outbox_events
    where payload ->> 'listing_id' = current_setting('test.partial_listing_id')
  ),
  0::bigint,
  'draft creation emits no outbox event'
);

set local role anon;

select is(
  (
    select count(*)
    from public.list_public_resource_listings(20, null, null, null, null, null)
    where listing_id = current_setting('test.partial_listing_id')::uuid
  ),
  0::bigint,
  'draft listings are not publicly discoverable'
);
select is(
  (
    select count(*)
    from public.get_public_resource_listing(
      current_setting('test.partial_listing_id')::uuid
    )
  ),
  0::bigint,
  'draft listings have no public detail'
);
select throws_ok(
  $$select id from public.resource_listings$$,
  '42501',
  'permission denied for table resource_listings',
  'anonymous users cannot read the listing table directly'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a2000000-0000-4000-8000-000000000002',
  true
);

select throws_ok(
  $$
    select public.update_own_resource_listing(
      'a2000000-0000-4000-8000-000000000002',
      current_setting('test.partial_listing_id')::uuid,
      'donate', 'Cross-account edit', null, null, null, null, null
    )
  $$,
  '42501',
  'The current user does not own this resource listing.',
  'another profile cannot edit the owner draft'
);
select throws_ok(
  $$
    select *
    from public.list_own_resource_listings(
      'a1000000-0000-4000-8000-000000000001'
    )
  $$,
  '42501',
  'The authenticated user does not match the expected resource listing owner.',
  'a stale expected owner identity is rejected before owner reads'
);
select is(
  (
    select count(*)
    from public.get_own_resource_listing(
      'a2000000-0000-4000-8000-000000000002',
      current_setting('test.partial_listing_id')::uuid
    )
  ),
  0::bigint,
  'another owner exact-read returns no private listing form'
);
select throws_ok(
  $$select id from public.resource_listings$$,
  '42501',
  'permission denied for table resource_listings',
  'authenticated users cannot bypass owner RPCs with direct table reads'
);

select set_config(
  'request.jwt.claim.sub',
  'a1000000-0000-4000-8000-000000000001',
  true
);

select throws_ok(
  $$
    select public.publish_resource_listing(
      'a1000000-0000-4000-8000-000000000001',
      current_setting('test.partial_listing_id')::uuid
    )
  $$,
  '22023',
  'Published resource listings require a mode, title, description, country, locality, and public location label.',
  'an incomplete draft cannot publish'
);

select lives_ok(
  $$
    select public.update_own_resource_listing(
      'a1000000-0000-4000-8000-000000000001',
      current_setting('test.partial_listing_id')::uuid,
      'donate',
      '  Community table  ',
      '  Solid wood table available for a new home.  ',
      'it',
      '  Trento  ',
      '  Povo  ',
      '  Trento · Povo  '
    )
  $$,
  'the owner can complete an own draft'
);

reset role;

select results_eq(
  $$
    select listing_mode, title, description, country_code, locality,
      administrative_area, public_location_label
    from public.resource_listings
    where id = current_setting('test.partial_listing_id')::uuid
  $$,
  $$
    values (
      'donate'::text,
      'Community table'::text,
      'Solid wood table available for a new home.'::text,
      'IT'::text,
      'Trento'::text,
      'Povo'::text,
      'Trento · Povo'::text
    )
  $$,
  'listing content and rough location are canonically normalized'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a1000000-0000-4000-8000-000000000001',
  true
);

select lives_ok(
  $$
    select public.publish_resource_listing(
      'a1000000-0000-4000-8000-000000000001',
      current_setting('test.partial_listing_id')::uuid
    )
  $$,
  'the owner can publish a valid donate listing'
);
select lives_ok(
  $$
    select public.publish_resource_listing(
      'a1000000-0000-4000-8000-000000000001',
      current_setting('test.partial_listing_id')::uuid
    )
  $$,
  'repeating publication is idempotent'
);

reset role;

select is(
  (
    select count(*)
    from private.audit_events
    where action = 'resource_listing.published'
      and actor_user_id = 'a1000000-0000-4000-8000-000000000001'
      and target_type = 'resource_listing'
      and target_id = current_setting('test.partial_listing_id')::uuid
      and metadata = jsonb_build_object('listing_mode', 'donate')
  ),
  1::bigint,
  'idempotent publication records one identifier-only audit event'
);
select is(
  (
    select count(*)
    from private.outbox_events
    where event_type = 'resource_listing.published'
      and payload = jsonb_build_object(
        'listing_id', current_setting('test.partial_listing_id')::uuid,
        'owner_profile_id', 'a1000000-0000-4000-8000-000000000001'::uuid,
        'listing_mode', 'donate'
      )
  ),
  1::bigint,
  'idempotent publication records one identifier-only outbox event'
);
select is(
  (
    select position('Solid wood' in payload::text)
    from private.outbox_events
    where event_type = 'resource_listing.published'
      and payload ->> 'listing_id' = current_setting('test.partial_listing_id')
  ),
  0,
  'publication outbox state contains no listing description or location text'
);

set local role anon;

select results_eq(
  $$
    select listing_mode, title, country_code, locality, public_location_label
    from public.list_public_resource_listings(
      20, null, null, null, null, null
    )
    where listing_id = current_setting('test.partial_listing_id')::uuid
  $$,
  $$
    values (
      'donate'::text,
      'Community table'::text,
      'IT'::text,
      'Trento'::text,
      'Trento · Povo'::text
    )
  $$,
  'anonymous discovery exposes the safe published card'
);
select results_eq(
  $$
    select owner_profile_id, owner_display_name, title
    from public.get_public_resource_listing(
      current_setting('test.partial_listing_id')::uuid
    )
  $$,
  $$
    values (
      'a1000000-0000-4000-8000-000000000001'::uuid,
      'Listing Owner A'::text,
      'Community table'::text
    )
  $$,
  'public detail includes only the visibility-approved owner display name'
);
select is(
  (
    select position(
      '@planets.invalid' in row_to_json(detail_row)::text
    )
    from public.get_public_resource_listing(
      current_setting('test.partial_listing_id')::uuid
    ) as detail_row
  ),
  0,
  'public detail never exposes the Auth email'
);

reset role;
update public.profile_field_visibility
set audience = 'private'
where profile_id = 'a1000000-0000-4000-8000-000000000001'
  and field_key = 'display_name';

set local role anon;
select is(
  (
    select owner_display_name
    from public.get_public_resource_listing(
      current_setting('test.partial_listing_id')::uuid
    )
  ),
  null,
  'a private profile display name remains hidden on public listing detail'
);

reset role;
update public.profile_field_visibility
set audience = 'public'
where profile_id = 'a1000000-0000-4000-8000-000000000001'
  and field_key = 'display_name';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a1000000-0000-4000-8000-000000000001',
  true
);

select set_config(
  'test.exchange_listing_id',
  public.create_resource_listing_draft(
    'a1000000-0000-4000-8000-000000000001',
    'exchange',
    'Cordless drill',
    'Battery and charger included for a practical exchange.',
    'IT',
    'Rovereto',
    null,
    'Rovereto'
  )::text,
  true
);
select lives_ok(
  $$
    select public.publish_resource_listing(
      'a1000000-0000-4000-8000-000000000001',
      current_setting('test.exchange_listing_id')::uuid
    )
  $$,
  'the owner can publish an exchange-intent listing without defining transaction mechanics'
);

reset role;
set local role anon;

select results_eq(
  $$
    select listing_id
    from public.list_public_resource_listings(
      20, null, null, ' donate ', null, null
    )
  $$,
  $$values (current_setting('test.partial_listing_id')::uuid)$$,
  'the donate filter selects only Dona discovery intent'
);
select results_eq(
  $$
    select listing_id
    from public.list_public_resource_listings(
      20, null, null, 'exchange', null, null
    )
  $$,
  $$values (current_setting('test.exchange_listing_id')::uuid)$$,
  'the exchange filter selects only Scambia discovery intent'
);
select results_eq(
  $$
    select listing_id
    from public.list_public_resource_listings(
      20, null, null, null, ' trento ', null
    )
  $$,
  $$values (current_setting('test.partial_listing_id')::uuid)$$,
  'locality filtering uses trimmed case-insensitive equality'
);
select results_eq(
  $$
    select listing_id
    from public.list_public_resource_listings(
      20, null, null, null, null, 'CORDLESS'
    )
  $$,
  $$values (current_setting('test.exchange_listing_id')::uuid)$$,
  'keyword discovery matches title substrings case-insensitively'
);
select results_eq(
  $$
    select listing_id
    from public.list_public_resource_listings(
      20, null, null, null, null, 'charger included'
    )
  $$,
  $$values (current_setting('test.exchange_listing_id')::uuid)$$,
  'keyword discovery matches description substrings case-insensitively'
);
select is(
  (
    select count(*)
    from public.list_public_resource_listings(
      20, null, null, null, null, 'not-present-anywhere'
    )
  ),
  0::bigint,
  'nonmatching keywords are excluded'
);
select throws_ok(
  $$
    select *
    from public.list_public_resource_listings(
      20, null, null, 'loan', null, null
    )
  $$,
  '22023',
  'Resource listing mode filter must be donate or exchange.',
  'invalid mode filters fail explicitly'
);
select throws_ok(
  $$
    select *
    from public.list_public_resource_listings(
      20, statement_timestamp(), null, null, null, null
    )
  $$,
  '22023',
  'Resource listing cursor values must be supplied together.',
  'partial keyset cursors fail explicitly'
);
select throws_ok(
  $$
    select *
    from public.list_public_resource_listings(
      51, null, null, null, null, null
    )
  $$,
  '22023',
  'Resource listing page size must be between 1 and 50.',
  'excessive public page sizes fail explicitly'
);
select throws_ok(
  $$
    select *
    from public.list_public_resource_listings(
      20, null, null, null, null, repeat('q', 121)
    )
  $$,
  '22023',
  'Resource listing query must contain at most 120 characters.',
  'keyword queries are bounded'
);

select results_eq(
  $$
    select listing_id
    from public.list_public_resource_listings(1, null, null, null, null, null)
  $$,
  $$values (current_setting('test.exchange_listing_id')::uuid)$$,
  'public discovery returns newest publication first'
);
select set_config(
  'test.cursor_published_at',
  (
    select published_at::text
    from public.list_public_resource_listings(1, null, null, null, null, null)
  ),
  true
);
select set_config(
  'test.cursor_listing_id',
  (
    select listing_id::text
    from public.list_public_resource_listings(1, null, null, null, null, null)
  ),
  true
);
select results_eq(
  $$
    select listing_id
    from public.list_public_resource_listings(
      1,
      current_setting('test.cursor_published_at')::timestamptz,
      current_setting('test.cursor_listing_id')::uuid,
      null,
      null,
      null
    )
  $$,
  $$values (current_setting('test.partial_listing_id')::uuid)$$,
  'paired descending timestamp and UUID pagination is stable'
);
select set_config(
  'test.anon_public_rows',
  (
    select jsonb_agg(to_jsonb(public_row) order by published_at desc, listing_id desc)::text
    from public.list_public_resource_listings(20, null, null, null, null, null)
      as public_row
  ),
  true
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a2000000-0000-4000-8000-000000000002',
  true
);
select is(
  (
    select jsonb_agg(to_jsonb(public_row) order by published_at desc, listing_id desc)::text
    from public.list_public_resource_listings(20, null, null, null, null, null)
      as public_row
  ),
  current_setting('test.anon_public_rows'),
  'anonymous and authenticated discovery return the same public listing data'
);

select set_config(
  'request.jwt.claim.sub',
  'a1000000-0000-4000-8000-000000000001',
  true
);
select lives_ok(
  $$
    select public.update_own_resource_listing(
      'a1000000-0000-4000-8000-000000000001',
      current_setting('test.partial_listing_id')::uuid,
      'exchange',
      'Updated community table',
      'Solid wood table available for a practical exchange.',
      'IT',
      'Trento',
      'Povo',
      'Trento · Povo'
    )
  $$,
  'a published listing can change discovery intent while staying publishable'
);
select throws_ok(
  $$
    select public.update_own_resource_listing(
      'a1000000-0000-4000-8000-000000000001',
      current_setting('test.partial_listing_id')::uuid,
      'exchange',
      'Invalid published edit',
      null,
      'IT',
      'Trento',
      'Povo',
      'Trento · Povo'
    )
  $$,
  '22023',
  'Published resource listings require a mode, title, description, country, locality, and public location label.',
  'a published update cannot leave the listing unpublishable'
);

select results_eq(
  $$
    select lifecycle_state, listing_mode, title
    from public.get_own_resource_listing(
      'a1000000-0000-4000-8000-000000000001',
      current_setting('test.partial_listing_id')::uuid
    )
  $$,
  $$values ('published'::text, 'exchange'::text, 'Updated community table'::text)$$,
  'failed published edits roll back atomically and valid edits remain visible to the owner'
);
select lives_ok(
  $$
    select public.close_resource_listing(
      'a1000000-0000-4000-8000-000000000001',
      current_setting('test.partial_listing_id')::uuid
    )
  $$,
  'the owner can terminally close an own published listing'
);
select throws_ok(
  $$
    select public.close_resource_listing(
      'a1000000-0000-4000-8000-000000000001',
      current_setting('test.partial_listing_id')::uuid
    )
  $$,
  '55000',
  'Only a published resource listing can be closed.',
  'closing an already closed listing follows deterministic terminal behavior'
);
select throws_ok(
  $$
    select public.update_own_resource_listing(
      'a1000000-0000-4000-8000-000000000001',
      current_setting('test.partial_listing_id')::uuid,
      'exchange', 'Reopened title', 'No reopen', 'IT', 'Trento', null, 'Trento'
    )
  $$,
  '55000',
  'This resource listing can no longer be edited.',
  'closed listings are immutable and cannot be reopened through update'
);
select results_eq(
  $$
    select lifecycle_state, published_at is not null, closed_at is not null
    from public.get_own_resource_listing(
      'a1000000-0000-4000-8000-000000000001',
      current_setting('test.partial_listing_id')::uuid
    )
  $$,
  $$values ('closed'::text, true, true)$$,
  'closed listings remain in owner history with lifecycle timestamps'
);
select is(
  (
    select count(*)
    from public.list_own_resource_listings(
      'a1000000-0000-4000-8000-000000000001'
    )
  ),
  2::bigint,
  'owner history includes both closed and published listings'
);

reset role;

select is(
  (
    select count(*)
    from private.audit_events
    where action = 'resource_listing.closed'
      and actor_user_id = 'a1000000-0000-4000-8000-000000000001'
      and target_type = 'resource_listing'
      and target_id = current_setting('test.partial_listing_id')::uuid
      and metadata = jsonb_build_object('listing_mode', 'exchange')
  ),
  1::bigint,
  'closure records one identifier-only audit event'
);
select is(
  (
    select count(*)
    from private.outbox_events
    where event_type = 'resource_listing.closed'
      and payload = jsonb_build_object(
        'listing_id', current_setting('test.partial_listing_id')::uuid,
        'owner_profile_id', 'a1000000-0000-4000-8000-000000000001'::uuid,
        'listing_mode', 'exchange'
      )
  ),
  1::bigint,
  'closure records one identifier-only outbox event without a transfer outcome'
);

set local role anon;
select is(
  (
    select count(*)
    from public.list_public_resource_listings(20, null, null, null, null, null)
    where listing_id = current_setting('test.partial_listing_id')::uuid
  ),
  0::bigint,
  'closed listings disappear from public discovery'
);
select is(
  (
    select count(*)
    from public.get_public_resource_listing(
      current_setting('test.partial_listing_id')::uuid
    )
  ),
  0::bigint,
  'closed listings disappear from public exact detail'
);

select * from finish();

rollback;
