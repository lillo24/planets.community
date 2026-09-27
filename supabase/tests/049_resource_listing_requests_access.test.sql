begin;

select no_plan();

insert into auth.users (id, email)
values
  ('f4100000-0000-4000-8000-000000000001', 'request-owner@planets.invalid'),
  ('f4100000-0000-4000-8000-000000000002', 'request-a@planets.invalid'),
  ('f4100000-0000-4000-8000-000000000003', 'request-b@planets.invalid'),
  ('f4100000-0000-4000-8000-000000000004', 'request-c@planets.invalid'),
  ('f4100000-0000-4000-8000-000000000005', 'request-d@planets.invalid'),
  ('f4100000-0000-4000-8000-000000000006', 'request-incomplete@planets.invalid'),
  ('f4100000-0000-4000-8000-000000000007', 'request-unrelated@planets.invalid');

insert into public.profiles (id, display_name)
values
  ('f4100000-0000-4000-8000-000000000001', 'Request Owner'),
  ('f4100000-0000-4000-8000-000000000002', 'Requester A'),
  ('f4100000-0000-4000-8000-000000000003', 'Requester B'),
  ('f4100000-0000-4000-8000-000000000004', 'Requester C'),
  ('f4100000-0000-4000-8000-000000000005', 'Requester D'),
  ('f4100000-0000-4000-8000-000000000006', null),
  ('f4100000-0000-4000-8000-000000000007', 'Unrelated User');

-- Existing request-domain scenarios provision canonical photos; missing-photo
-- behavior is isolated in the 08A4B trust tests.
insert into public.profile_photos (profile_id, object_path, audience)
select
  profile.id,
  profile.id::text || '/' || profile.id::text || '.webp',
  'interactions'
from public.profiles as profile
where profile.id::text like 'f4100000-0000-4000-8000-%';

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
  published_at,
  closed_at
)
values
  (
    'f4200000-0000-4000-8000-000000000001',
    'f4100000-0000-4000-8000-000000000001',
    'exchange',
    'published',
    'Shared drill',
    'A drill offered for exchange discovery.',
    'IT',
    'Trento',
    'Trento',
    statement_timestamp(),
    null
  ),
  (
    'f4200000-0000-4000-8000-000000000002',
    'f4100000-0000-4000-8000-000000000001',
    'donate',
    'published',
    'Donation table',
    'A table offered for donation discovery.',
    'IT',
    'Trento',
    'Trento',
    statement_timestamp(),
    null
  ),
  (
    'f4200000-0000-4000-8000-000000000003',
    'f4100000-0000-4000-8000-000000000001',
    'exchange',
    'draft',
    null,
    null,
    null,
    null,
    null,
    null,
    null
  ),
  (
    'f4200000-0000-4000-8000-000000000004',
    'f4100000-0000-4000-8000-000000000001',
    'donate',
    'closed',
    'Closed chair',
    'A no-longer-public chair.',
    'IT',
    'Trento',
    'Trento',
    statement_timestamp() - interval '1 minute',
    statement_timestamp()
  ),
  (
    'f4200000-0000-4000-8000-000000000005',
    'f4100000-0000-4000-8000-000000000001',
    'donate',
    'published',
    'No-request listing',
    'A listing used to prove zero-request closure.',
    'IT',
    'Trento',
    'Trento',
    statement_timestamp(),
    null
  );

set local role anon;
select throws_ok(
  $$
    select public.request_resource_listing(
      'f4100000-0000-4000-8000-000000000002',
      'f4200000-0000-4000-8000-000000000001',
      null
    )
  $$,
  '42501',
  'permission denied for function request_resource_listing',
  'anonymous users cannot create listing requests'
);
select throws_ok(
  $$select id from public.resource_listing_requests$$,
  '42501',
  'permission denied for table resource_listing_requests',
  'anonymous users cannot enumerate private request rows'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'f4100000-0000-4000-8000-000000000006',
  true
);
select throws_ok(
  $$
    select public.request_resource_listing(
      'f4100000-0000-4000-8000-000000000006',
      'f4200000-0000-4000-8000-000000000001',
      null
    )
  $$,
  '55000',
  'A complete profile is required to request a resource listing.',
  'an incomplete profile cannot request a listing'
);

select set_config(
  'request.jwt.claim.sub',
  'f4100000-0000-4000-8000-000000000001',
  true
);
select throws_ok(
  $$
    select public.request_resource_listing(
      'f4100000-0000-4000-8000-000000000001',
      'f4200000-0000-4000-8000-000000000001',
      null
    )
  $$,
  '22023',
  'A listing owner cannot request their own resource listing.',
  'an owner cannot request their own listing'
);

select set_config(
  'request.jwt.claim.sub',
  'f4100000-0000-4000-8000-000000000002',
  true
);
select throws_ok(
  $$
    select public.request_resource_listing(
      'f4100000-0000-4000-8000-000000000002',
      'f4200000-0000-4000-8000-000000000003',
      null
    )
  $$,
  '55000',
  'Only a published resource listing can be requested.',
  'draft listings cannot be requested'
);
select throws_ok(
  $$
    select public.request_resource_listing(
      'f4100000-0000-4000-8000-000000000002',
      'f4200000-0000-4000-8000-000000000004',
      null
    )
  $$,
  '55000',
  'Only a published resource listing can be requested.',
  'closed listings cannot be requested'
);
select throws_ok(
  $$
    select public.request_resource_listing(
      'f4100000-0000-4000-8000-000000000002',
      'f4200000-0000-4000-8000-000000000001',
      repeat('x', 501)
    )
  $$,
  '22023',
  'Resource listing request message must contain at most 500 characters.',
  'private request messages are bounded'
);

select set_config(
  'test.request_a',
  public.request_resource_listing(
    'f4100000-0000-4000-8000-000000000002',
    'f4200000-0000-4000-8000-000000000001',
    '  I can coordinate locally.  '
  )::text,
  true
);
select throws_ok(
  $$
    select public.request_resource_listing(
      'f4100000-0000-4000-8000-000000000002',
      'f4200000-0000-4000-8000-000000000001',
      null
    )
  $$,
  'PT409',
  'An active request already exists for this resource listing.',
  'a duplicate active request returns the stable application conflict'
);

select set_config(
  'request.jwt.claim.sub',
  'f4100000-0000-4000-8000-000000000003',
  true
);
select set_config(
  'test.request_b_donate',
  public.request_resource_listing(
    'f4100000-0000-4000-8000-000000000003',
    'f4200000-0000-4000-8000-000000000002',
    '   '
  )::text,
  true
);

select set_config(
  'request.jwt.claim.sub',
  'f4100000-0000-4000-8000-000000000004',
  true
);
select set_config(
  'test.request_c',
  public.request_resource_listing(
    'f4100000-0000-4000-8000-000000000004',
    'f4200000-0000-4000-8000-000000000001',
    null
  )::text,
  true
);

select set_config(
  'request.jwt.claim.sub',
  'f4100000-0000-4000-8000-000000000005',
  true
);
select set_config(
  'test.request_d_rejected',
  public.request_resource_listing(
    'f4100000-0000-4000-8000-000000000005',
    'f4200000-0000-4000-8000-000000000001',
    'Private D context'
  )::text,
  true
);

reset role;
select results_eq(
  $$
    select status, request_message, resolved_at, resolved_by_profile_id
    from public.resource_listing_requests
    where id = current_setting('test.request_a')::uuid
  $$,
  $$
    values (
      'pending'::text,
      'I can coordinate locally.'::text,
      null::timestamptz,
      null::uuid
    )
  $$,
  'request creation normalizes the private message and starts pending'
);
select is(
  (
    select request_message
    from public.resource_listing_requests
    where id = current_setting('test.request_b_donate')::uuid
  ),
  null,
  'a blank request message normalizes to null'
);

set local role anon;
select results_eq(
  $$
    select active_request_count
    from public.get_public_resource_listing(
      'f4200000-0000-4000-8000-000000000001'
    )
  $$,
  $$values (3::bigint)$$,
  'public detail exposes only the pending-plus-accepted active interest count'
);
select ok(
  (
    select not (to_jsonb(public_row) ? 'requester_profile_id')
      and not (to_jsonb(public_row) ? 'request_message')
      and not (to_jsonb(public_row) ? 'request_id')
    from public.list_public_resource_listings(
      20,
      null,
      null,
      null,
      null,
      null
    ) as public_row
    where public_row.listing_id =
      'f4200000-0000-4000-8000-000000000001'
  ),
  'public listing reads expose no request identity, ID, or message'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'f4100000-0000-4000-8000-000000000001',
  true
);
select results_eq(
  $$
    select requester_profile_id, requester_display_name, request_message
    from public.list_resource_listing_requests(
      'f4100000-0000-4000-8000-000000000001',
      'f4200000-0000-4000-8000-000000000001'
    )
    where request_id = current_setting('test.request_a')::uuid
  $$,
  $$
    values (
      'f4100000-0000-4000-8000-000000000002'::uuid,
      'Requester A'::text,
      'I can coordinate locally.'::text
    )
  $$,
  'the owner reads requester identity and private message through the narrow RPC'
);

select lives_ok(
  format(
    'select public.accept_resource_listing_request(%L, %L)',
    'f4100000-0000-4000-8000-000000000001',
    current_setting('test.request_a')
  ),
  'the owner accepts one pending request'
);
select lives_ok(
  format(
    'select public.accept_resource_listing_request(%L, %L)',
    'f4100000-0000-4000-8000-000000000001',
    current_setting('test.request_c')
  ),
  'the owner accepts a second request without reserving the listing'
);
select lives_ok(
  format(
    'select public.reject_resource_listing_request(%L, %L)',
    'f4100000-0000-4000-8000-000000000001',
    current_setting('test.request_d_rejected')
  ),
  'the owner rejects another pending request independently'
);

select set_config(
  'request.jwt.claim.sub',
  'f4100000-0000-4000-8000-000000000003',
  true
);
select lives_ok(
  format(
    'select public.withdraw_resource_listing_request(%L, %L)',
    'f4100000-0000-4000-8000-000000000003',
    current_setting('test.request_b_donate')
  ),
  'the requester withdraws their pending request'
);

set local role anon;
select results_eq(
  $$
    select active_request_count
    from public.get_public_resource_listing(
      'f4200000-0000-4000-8000-000000000001'
    )
  $$,
  $$values (2::bigint)$$,
  'two accepted requests remain active interest'
);
select results_eq(
  $$
    select active_request_count
    from public.get_public_resource_listing(
      'f4200000-0000-4000-8000-000000000002'
    )
  $$,
  $$values (0::bigint)$$,
  'withdrawn requests no longer contribute to active interest'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'f4100000-0000-4000-8000-000000000002',
  true
);
select results_eq(
  $$
    select listing_id, owner_profile_id, owner_display_name, status,
      request_message
    from public.list_own_resource_listing_requests(
      'f4100000-0000-4000-8000-000000000002'
    )
    where request_id = current_setting('test.request_a')::uuid
  $$,
  $$
    values (
      'f4200000-0000-4000-8000-000000000001'::uuid,
      'f4100000-0000-4000-8000-000000000001'::uuid,
      'Request Owner'::text,
      'accepted'::text,
      'I can coordinate locally.'::text
    )
  $$,
  'the requester sees private canonical history and counterpart display name'
);
select results_eq(
  $$
    select requester_profile_id, requester_display_name, status
    from public.get_resource_listing_request(
      'f4100000-0000-4000-8000-000000000002',
      current_setting('test.request_a')::uuid
    )
  $$,
  $$
    values (
      'f4100000-0000-4000-8000-000000000002'::uuid,
      'Requester A'::text,
      'accepted'::text
    )
  $$,
  'the requester can read their own request by ID'
);

select set_config(
  'request.jwt.claim.sub',
  'f4100000-0000-4000-8000-000000000007',
  true
);
select is(
  (
    select count(*)
    from public.get_resource_listing_request(
      'f4100000-0000-4000-8000-000000000007',
      current_setting('test.request_a')::uuid
    )
  ),
  0::bigint,
  'an unrelated user cannot read another request by ID'
);
select throws_ok(
  $$select id from public.resource_listing_requests$$,
  '42501',
  'permission denied for table resource_listing_requests',
  'authenticated users cannot bypass request RPCs with direct reads'
);

select set_config(
  'request.jwt.claim.sub',
  'f4100000-0000-4000-8000-000000000002',
  true
);
select throws_ok(
  format(
    'select public.withdraw_resource_listing_request(%L, %L)',
    'f4100000-0000-4000-8000-000000000002',
    current_setting('test.request_a')
  ),
  'PT409',
  'The resource listing request is no longer pending.',
  'accepted requests cannot be withdrawn in 04C4A'
);

select set_config(
  'request.jwt.claim.sub',
  'f4100000-0000-4000-8000-000000000001',
  true
);
select throws_ok(
  format(
    'select public.accept_resource_listing_request(%L, %L)',
    'f4100000-0000-4000-8000-000000000001',
    current_setting('test.request_d_rejected')
  ),
  'PT409',
  'The resource listing request is no longer pending.',
  'rejected requests cannot be accepted later'
);
select throws_ok(
  format(
    'select public.reject_resource_listing_request(%L, %L)',
    'f4100000-0000-4000-8000-000000000001',
    current_setting('test.request_a')
  ),
  'PT409',
  'The resource listing request is no longer pending.',
  'accepted requests cannot be rejected later'
);
select throws_ok(
  format(
    'select public.accept_resource_listing_request(%L, %L)',
    'f4100000-0000-4000-8000-000000000001',
    current_setting('test.request_b_donate')
  ),
  'PT409',
  'The resource listing request is no longer pending.',
  'withdrawn requests cannot be accepted later'
);

select set_config(
  'request.jwt.claim.sub',
  'f4100000-0000-4000-8000-000000000005',
  true
);
select set_config(
  'test.request_d_pending',
  public.request_resource_listing(
    'f4100000-0000-4000-8000-000000000005',
    'f4200000-0000-4000-8000-000000000001',
    null
  )::text,
  true
);
select set_config(
  'request.jwt.claim.sub',
  'f4100000-0000-4000-8000-000000000003',
  true
);
select set_config(
  'test.request_b_withdrawn',
  public.request_resource_listing(
    'f4100000-0000-4000-8000-000000000003',
    'f4200000-0000-4000-8000-000000000001',
    null
  )::text,
  true
);
select public.withdraw_resource_listing_request(
  'f4100000-0000-4000-8000-000000000003',
  current_setting('test.request_b_withdrawn')::uuid
);

select set_config(
  'request.jwt.claim.sub',
  'f4100000-0000-4000-8000-000000000001',
  true
);
select lives_ok(
  $$
    select public.close_resource_listing(
      'f4100000-0000-4000-8000-000000000001',
      'f4200000-0000-4000-8000-000000000001'
    )
  $$,
  'closing a listing atomically resolves its pending requests'
);
select lives_ok(
  $$
    select public.close_resource_listing(
      'f4100000-0000-4000-8000-000000000001',
      'f4200000-0000-4000-8000-000000000005'
    )
  $$,
  'closing a published listing with zero requests still succeeds'
);

reset role;
select results_eq(
  $$
    select id, status
    from public.resource_listing_requests
    where id in (
      current_setting('test.request_a')::uuid,
      current_setting('test.request_c')::uuid,
      current_setting('test.request_d_rejected')::uuid,
      current_setting('test.request_d_pending')::uuid,
      current_setting('test.request_b_withdrawn')::uuid
    )
    order by id
  $$,
  format(
    $expected$
      values
        (%L::uuid, 'accepted'::text),
        (%L::uuid, 'accepted'::text),
        (%L::uuid, 'rejected'::text),
        (%L::uuid, 'listing_closed'::text),
        (%L::uuid, 'withdrawn'::text)
      order by 1
    $expected$,
    current_setting('test.request_a'),
    current_setting('test.request_c'),
    current_setting('test.request_d_rejected'),
    current_setting('test.request_d_pending'),
    current_setting('test.request_b_withdrawn')
  ),
  'close preserves accepted/rejected/withdrawn history and closes only pending requests'
);

set local role anon;
select is(
  (
    select count(*)
    from public.get_public_resource_listing(
      'f4200000-0000-4000-8000-000000000001'
    )
  ),
  0::bigint,
  'a closed listing disappears from public detail'
);
select is(
  (
    select count(*)
    from public.get_public_resource_listing(
      'f4200000-0000-4000-8000-000000000005'
    )
  ),
  0::bigint,
  'a zero-request closed listing also disappears publicly'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'f4100000-0000-4000-8000-000000000005',
  true
);
select results_eq(
  $$
    select listing_lifecycle, status
    from public.list_own_resource_listing_requests(
      'f4100000-0000-4000-8000-000000000005'
    )
    where request_id = current_setting('test.request_d_pending')::uuid
  $$,
  $$values ('closed'::text, 'listing_closed'::text)$$,
  'requester history remains readable after listing closure'
);

select set_config(
  'request.jwt.claim.sub',
  'f4100000-0000-4000-8000-000000000001',
  true
);
select results_eq(
  $$
    select status
    from public.list_resource_listing_requests(
      'f4100000-0000-4000-8000-000000000001',
      'f4200000-0000-4000-8000-000000000001'
    )
    where request_id = current_setting('test.request_d_pending')::uuid
  $$,
  $$values ('listing_closed'::text)$$,
  'owner request history remains readable after listing closure'
);
select throws_ok(
  format(
    'select public.accept_resource_listing_request(%L, %L)',
    'f4100000-0000-4000-8000-000000000001',
    current_setting('test.request_d_pending')
  ),
  'PT409',
  'The resource listing request is no longer pending.',
  'listing-closed requests cannot be accepted'
);

reset role;
select is(
  (
    select count(*)
    from private.outbox_events as event
    where event_type in (
      'resource_listing.request_created',
      'resource_listing.request_accepted',
      'resource_listing.request_rejected',
      'resource_listing.request_withdrawn',
      'resource_listing.request_closed'
    )
      and (
        event.payload ? 'request_id'
        and event.payload ? 'listing_id'
        and event.payload ? 'owner_profile_id'
        and event.payload ? 'requester_profile_id'
        and event.payload ? 'actor_profile_id'
        and (
          select count(*)
          from jsonb_object_keys(event.payload)
        ) = 5
      )
  ),
  (
    select count(*)
    from private.outbox_events
    where event_type in (
      'resource_listing.request_created',
      'resource_listing.request_accepted',
      'resource_listing.request_rejected',
      'resource_listing.request_withdrawn',
      'resource_listing.request_closed'
    )
  ),
  'every request outbox event contains exactly five identifiers'
);
select is(
  (
    select count(*)
    from private.outbox_events
    where event_type like 'resource_listing.request_%'
      and (
        payload::text like '%I can coordinate locally%'
        or payload::text like '%Private D context%'
        or payload ? 'request_message'
        or payload ? 'listing_title'
        or payload ? 'display_name'
      )
  ),
  0::bigint,
  'request outbox events contain no message, title, or display name'
);
select is(
  (
    select count(*)
    from private.audit_events
    where action like 'resource_listing.request_%'
      and (
        metadata::text like '%I can coordinate locally%'
        or metadata::text like '%Private D context%'
        or metadata ? 'request_message'
        or metadata ? 'listing_title'
        or metadata ? 'display_name'
      )
  ),
  0::bigint,
  'request audit metadata contains identifiers only'
);

select * from finish();

rollback;
