begin;

select no_plan();

insert into auth.users (id, email) values
  ('f5600000-0000-4000-8000-000000000001', 'loan-owner@planets.invalid'),
  ('f5600000-0000-4000-8000-000000000002', 'loan-a@planets.invalid'),
  ('f5600000-0000-4000-8000-000000000003', 'loan-b@planets.invalid'),
  ('f5600000-0000-4000-8000-000000000004', 'loan-c@planets.invalid'),
  ('f5600000-0000-4000-8000-000000000005', 'loan-d@planets.invalid'),
  ('f5600000-0000-4000-8000-000000000006', 'loan-unrelated@planets.invalid');

insert into public.profiles (id, display_name) values
  ('f5600000-0000-4000-8000-000000000001', 'Loan Owner'),
  ('f5600000-0000-4000-8000-000000000002', 'Loan A'),
  ('f5600000-0000-4000-8000-000000000003', 'Loan B'),
  ('f5600000-0000-4000-8000-000000000004', 'Loan C'),
  ('f5600000-0000-4000-8000-000000000005', 'Loan D'),
  ('f5600000-0000-4000-8000-000000000006', 'Loan Unrelated');

insert into public.resource_listings (
  id, owner_profile_id, listing_mode, lifecycle_state, title, description,
  country_code, locality, public_location_label, published_at
) values
  (
    'f5610000-0000-4000-8000-000000000001',
    'f5600000-0000-4000-8000-000000000001',
    'exchange', 'published', 'Loan tool one', 'One lending unit.',
    'IT', 'Trento', 'Trento', statement_timestamp()
  ),
  (
    'f5610000-0000-4000-8000-000000000002',
    'f5600000-0000-4000-8000-000000000001',
    'exchange', 'published', 'Loan tool two', 'Independent lending unit.',
    'IT', 'Trento', 'Trento', statement_timestamp()
  );

insert into public.resource_listing_requests (
  id, listing_id, requester_profile_id, status, resolved_at,
  resolved_by_profile_id
) values
  ('f5620000-0000-4000-8000-000000000001',
   'f5610000-0000-4000-8000-000000000001',
   'f5600000-0000-4000-8000-000000000002', 'accepted',
   statement_timestamp(), 'f5600000-0000-4000-8000-000000000001'),
  ('f5620000-0000-4000-8000-000000000002',
   'f5610000-0000-4000-8000-000000000001',
   'f5600000-0000-4000-8000-000000000003', 'accepted',
   statement_timestamp(), 'f5600000-0000-4000-8000-000000000001'),
  ('f5620000-0000-4000-8000-000000000003',
   'f5610000-0000-4000-8000-000000000001',
   'f5600000-0000-4000-8000-000000000004', 'accepted',
   statement_timestamp(), 'f5600000-0000-4000-8000-000000000001'),
  ('f5620000-0000-4000-8000-000000000004',
   'f5610000-0000-4000-8000-000000000002',
   'f5600000-0000-4000-8000-000000000005', 'accepted',
   statement_timestamp(), 'f5600000-0000-4000-8000-000000000001');

insert into public.resource_listing_requests (
  id, listing_id, requester_profile_id
) values (
  'f5620000-0000-4000-8000-000000000005',
  'f5610000-0000-4000-8000-000000000001',
  'f5600000-0000-4000-8000-000000000006'
);

insert into public.resource_exchange_agreements (id, request_id) values
  ('f5630000-0000-4000-8000-000000000001',
   'f5620000-0000-4000-8000-000000000001'),
  ('f5630000-0000-4000-8000-000000000002',
   'f5620000-0000-4000-8000-000000000002'),
  ('f5630000-0000-4000-8000-000000000003',
   'f5620000-0000-4000-8000-000000000003'),
  ('f5630000-0000-4000-8000-000000000004',
   'f5620000-0000-4000-8000-000000000004');

select is(
  (select count(*) from private.active_resource_listing_loan_reservations()),
  0::bigint,
  'pending and accepted requests without accepted terms do not reserve'
);

select set_config(
  'test.loan_t0',
  date_trunc('day', statement_timestamp())::text,
  true
);

insert into public.resource_exchange_agreement_terms (
  id, agreement_id, version_number, proposed_by_profile_id,
  listing_title_snapshot, listing_description_snapshot,
  owner_transfer_kind, owner_lend_starts_at, owner_lend_ends_at,
  requester_transfer_kind
) values
  ('f5640000-0000-4000-8000-000000000001',
   'f5630000-0000-4000-8000-000000000001', 1,
   'f5600000-0000-4000-8000-000000000001', 'Loan tool one', 'One lending unit.',
   'lend', current_setting('test.loan_t0')::timestamptz - interval '4 days',
   current_setting('test.loan_t0')::timestamptz - interval '1 day', 'none'),
  ('f5640000-0000-4000-8000-000000000002',
   'f5630000-0000-4000-8000-000000000002', 1,
   'f5600000-0000-4000-8000-000000000001', 'Loan tool one', 'One lending unit.',
   'lend', current_setting('test.loan_t0')::timestamptz - interval '1 day',
   current_setting('test.loan_t0')::timestamptz + interval '2 days', 'none'),
  ('f5640000-0000-4000-8000-000000000003',
   'f5630000-0000-4000-8000-000000000003', 1,
   'f5600000-0000-4000-8000-000000000001', 'Loan tool one', 'One lending unit.',
   'lend', current_setting('test.loan_t0')::timestamptz - interval '3 days',
   current_setting('test.loan_t0')::timestamptz - interval '2 days', 'none'),
  ('f5640000-0000-4000-8000-000000000004',
   'f5630000-0000-4000-8000-000000000004', 1,
   'f5600000-0000-4000-8000-000000000001', 'Loan tool two', 'Independent lending unit.',
   'give', null, null, 'none');

update public.resource_exchange_agreements as agreement
set pending_terms_id = terms.id
from public.resource_exchange_agreement_terms as terms
where terms.agreement_id = agreement.id
  and terms.version_number = 1;

select is(
  (select count(*) from private.active_resource_listing_loan_reservations()),
  0::bigint,
  'accepted requests and pending LEND proposals do not reserve'
);

set local role anon;
select throws_ok(
  $$select * from public.list_owned_resource_listing_loan_schedule(
    'f5600000-0000-4000-8000-000000000001',
    'f5610000-0000-4000-8000-000000000001'
  )$$,
  '42501', 'permission denied for function list_owned_resource_listing_loan_schedule',
  'anonymous schedule read is denied'
);
select throws_ok(
  $$select * from public.check_resource_exchange_pending_loan_availability(
    'f5600000-0000-4000-8000-000000000002',
    'f5630000-0000-4000-8000-000000000001',
    'f5640000-0000-4000-8000-000000000001'
  )$$,
  '42501', 'permission denied for function check_resource_exchange_pending_loan_availability',
  'anonymous pending availability is denied'
);

set local role authenticated;
select set_config('request.jwt.claim.sub',
  'f5600000-0000-4000-8000-000000000006', true);
select throws_ok(
  $$select * from public.list_owned_resource_listing_loan_schedule(
    'f5600000-0000-4000-8000-000000000006',
    'f5610000-0000-4000-8000-000000000001'
  )$$,
  '42501', 'The current user does not own this resource listing.',
  'unrelated user cannot see owner schedule'
);
select throws_ok(
  $$select * from public.check_resource_exchange_pending_loan_availability(
    'f5600000-0000-4000-8000-000000000006',
    'f5630000-0000-4000-8000-000000000001',
    'f5640000-0000-4000-8000-000000000001'
  )$$,
  '42501', 'The pending agreement is unavailable to this profile.',
  'unrelated user cannot probe pending availability'
);

select set_config('request.jwt.claim.sub',
  'f5600000-0000-4000-8000-000000000001', true);
select is(
  (select is_available from public.check_resource_exchange_pending_loan_availability(
    'f5600000-0000-4000-8000-000000000001',
    'f5630000-0000-4000-8000-000000000001',
    'f5640000-0000-4000-8000-000000000001'
  )), true, 'owner sees pending LEND as available before acceptance'
);
select is(
  (select is_lend = false and is_available = true
   from public.check_resource_exchange_pending_loan_availability(
    'f5600000-0000-4000-8000-000000000001',
    'f5630000-0000-4000-8000-000000000004',
    'f5640000-0000-4000-8000-000000000004'
  )), true, 'pending GIVE is always informationally available'
);

select set_config('request.jwt.claim.sub',
  'f5600000-0000-4000-8000-000000000002', true);
select is(
  public.accept_resource_exchange_terms(
    'f5600000-0000-4000-8000-000000000002',
    'f5630000-0000-4000-8000-000000000001',
    'f5640000-0000-4000-8000-000000000001'
  ),
  'f5640000-0000-4000-8000-000000000001'::uuid,
  'first LEND activates a reservation'
);
select throws_ok(
  $$select * from public.list_owned_resource_listing_loan_schedule(
    'f5600000-0000-4000-8000-000000000002',
    'f5610000-0000-4000-8000-000000000001'
  )$$,
  '42501', 'The current user does not own this resource listing.',
  'requester cannot see owner schedule'
);

reset role;
select is(
  (select count(*) from private.active_resource_listing_loan_reservations()),
  1::bigint,
  'only accepted current LEND is active'
);
select is(
  private.resource_listing_loan_period_conflicts(
    'f5610000-0000-4000-8000-000000000001',
    'f5630000-0000-4000-8000-000000000003',
    current_setting('test.loan_t0')::timestamptz - interval '5 days',
    current_setting('test.loan_t0')::timestamptz - interval '4 days'
  ), false, 'adjacent before is compatible'
);
select is(
  private.resource_listing_loan_period_conflicts(
    'f5610000-0000-4000-8000-000000000001',
    'f5630000-0000-4000-8000-000000000003',
    current_setting('test.loan_t0')::timestamptz - interval '1 day',
    current_setting('test.loan_t0')::timestamptz
  ), false, 'adjacent after is compatible'
);
select is(
  private.resource_listing_loan_period_conflicts(
    'f5610000-0000-4000-8000-000000000001',
    'f5630000-0000-4000-8000-000000000003',
    current_setting('test.loan_t0')::timestamptz - interval '5 days',
    current_setting('test.loan_t0')::timestamptz - interval '3 days'
  ), true, 'candidate end inside conflicts'
);
select is(
  private.resource_listing_loan_period_conflicts(
    'f5610000-0000-4000-8000-000000000001',
    'f5630000-0000-4000-8000-000000000003',
    current_setting('test.loan_t0')::timestamptz - interval '3 days',
    current_setting('test.loan_t0')::timestamptz
  ), true, 'candidate start inside conflicts'
);
select is(
  private.resource_listing_loan_period_conflicts(
    'f5610000-0000-4000-8000-000000000001',
    'f5630000-0000-4000-8000-000000000003',
    current_setting('test.loan_t0')::timestamptz - interval '5 days',
    current_setting('test.loan_t0')::timestamptz
  ), true, 'candidate containing existing conflicts'
);
select is(
  private.resource_listing_loan_period_conflicts(
    'f5610000-0000-4000-8000-000000000001',
    'f5630000-0000-4000-8000-000000000003',
    current_setting('test.loan_t0')::timestamptz - interval '3 days',
    current_setting('test.loan_t0')::timestamptz - interval '2 days'
  ), true, 'existing containing candidate conflicts'
);
select is(
  private.resource_listing_loan_period_conflicts(
    'f5610000-0000-4000-8000-000000000001',
    'f5630000-0000-4000-8000-000000000003',
    current_setting('test.loan_t0')::timestamptz - interval '4 days',
    current_setting('test.loan_t0')::timestamptz - interval '1 day'
  ), true, 'exact same period conflicts'
);
select is(
  private.resource_listing_loan_period_conflicts(
    'f5610000-0000-4000-8000-000000000001',
    'f5630000-0000-4000-8000-000000000001',
    current_setting('test.loan_t0')::timestamptz - interval '4 days',
    current_setting('test.loan_t0')::timestamptz - interval '1 day'
  ), false, 'same agreement is excluded for replacement'
);
select is(
  private.resource_listing_loan_period_conflicts(
    'f5610000-0000-4000-8000-000000000002',
    'f5630000-0000-4000-8000-000000000004',
    current_setting('test.loan_t0')::timestamptz - interval '4 days',
    current_setting('test.loan_t0')::timestamptz - interval '1 day'
  ), false, 'a different listing is independent'
);

set local role authenticated;
select set_config('request.jwt.claim.sub',
  'f5600000-0000-4000-8000-000000000004', true);
select is(
  (select is_lend and not is_available
   from public.check_resource_exchange_pending_loan_availability(
     'f5600000-0000-4000-8000-000000000004',
     'f5630000-0000-4000-8000-000000000003',
     'f5640000-0000-4000-8000-000000000003'
   )), true, 'requester sees conflict boolean but no other reservation details'
);
select throws_ok(
  $$select public.accept_resource_exchange_terms(
    'f5600000-0000-4000-8000-000000000004',
    'f5630000-0000-4000-8000-000000000003',
    'f5640000-0000-4000-8000-000000000003'
  )$$,
  'PT409', 'The listing already has an accepted loan for that period.',
  'overlapping accepted loan is rejected before pointer or event mutation'
);
select throws_ok(
  $$select * from public.check_resource_exchange_pending_loan_availability(
    'f5600000-0000-4000-8000-000000000004',
    'f5630000-0000-4000-8000-000000000003',
    'f5640000-0000-4000-8000-000000000001'
  )$$,
  'PT409', 'The pending resource exchange terms changed since they were loaded.',
  'wrong pending version fails closed'
);
reset role;
select is(
  (select current_terms_id is null and
    pending_terms_id = 'f5640000-0000-4000-8000-000000000003'::uuid
   from public.resource_exchange_agreements
   where id = 'f5630000-0000-4000-8000-000000000003'),
  true, 'conflict preserves current and pending pointers'
);
select is(
  (select count(*) from public.resource_exchange_agreement_events
   where agreement_id = 'f5630000-0000-4000-8000-000000000003'
     and event_kind = 'terms_accepted'),
  0::bigint, 'conflict emits no accepted event'
);
select is(
  (select count(*) from private.outbox_events
   where event_type = 'resource_exchange.terms_accepted'
     and payload->>'agreement_id' =
       'f5630000-0000-4000-8000-000000000003'),
  0::bigint, 'conflict emits no accepted outbox event'
);

set local role authenticated;
select set_config('request.jwt.claim.sub',
  'f5600000-0000-4000-8000-000000000003', true);
select is(
  public.accept_resource_exchange_terms(
    'f5600000-0000-4000-8000-000000000003',
    'f5630000-0000-4000-8000-000000000002',
    'f5640000-0000-4000-8000-000000000002'
  ),
  'f5640000-0000-4000-8000-000000000002'::uuid,
  'adjacent LEND acceptance succeeds'
);

select set_config('request.jwt.claim.sub',
  'f5600000-0000-4000-8000-000000000001', true);
select is(
  (select count(*) from public.list_owned_resource_listing_loan_schedule(
     'f5600000-0000-4000-8000-000000000001',
     'f5610000-0000-4000-8000-000000000001'
   )), 2::bigint, 'owner schedule shows active reservations only'
);
select is(
  (select bool_and(requester_display_name in ('Loan A', 'Loan B'))
   from public.list_owned_resource_listing_loan_schedule(
     'f5600000-0000-4000-8000-000000000001',
     'f5610000-0000-4000-8000-000000000001'
   )), true, 'owner receives only accepted counterpart display context'
);
select is(
  (select is_overdue from public.list_owned_resource_listing_loan_schedule(
     'f5600000-0000-4000-8000-000000000001',
     'f5610000-0000-4000-8000-000000000001'
   ) where agreement_id = 'f5630000-0000-4000-8000-000000000001'),
  true, 'earlier unreturned LEND is overdue'
);
select is(
  (select owner_lend_return_overdue
   from public.get_resource_exchange_agreement(
     'f5600000-0000-4000-8000-000000000001',
     'f5620000-0000-4000-8000-000000000001'
   )),
  (select is_overdue
   from public.list_owned_resource_listing_loan_schedule(
     'f5600000-0000-4000-8000-000000000001',
     'f5610000-0000-4000-8000-000000000001'
   ) where agreement_id = 'f5630000-0000-4000-8000-000000000001'),
  'agreement read and owner schedule share overdue truth'
);
select is(
  (select is_at_risk from public.list_owned_resource_listing_loan_schedule(
     'f5600000-0000-4000-8000-000000000001',
     'f5610000-0000-4000-8000-000000000001'
   ) where agreement_id = 'f5630000-0000-4000-8000-000000000002'),
  true, 'later compatible reservation is derived at risk'
);

select public.record_resource_exchange_milestone(
  'f5600000-0000-4000-8000-000000000001',
  'f5630000-0000-4000-8000-000000000001',
  'f5640000-0000-4000-8000-000000000001',
  'owner_resource', 'resource_provided'
);
select is(
  (select count(*) from public.list_owned_resource_listing_loan_schedule(
     'f5600000-0000-4000-8000-000000000001',
     'f5610000-0000-4000-8000-000000000001'
   )), 2::bigint, 'in-progress LEND remains reserved'
);
select set_config('request.jwt.claim.sub',
  'f5600000-0000-4000-8000-000000000002', true);
select public.record_resource_exchange_milestone(
  'f5600000-0000-4000-8000-000000000002',
  'f5630000-0000-4000-8000-000000000001',
  'f5640000-0000-4000-8000-000000000001',
  'owner_resource', 'resource_received'
);
select public.record_resource_exchange_milestone(
  'f5600000-0000-4000-8000-000000000002',
  'f5630000-0000-4000-8000-000000000001',
  'f5640000-0000-4000-8000-000000000001',
  'owner_resource', 'resource_returned'
);
select set_config('request.jwt.claim.sub',
  'f5600000-0000-4000-8000-000000000001', true);
select public.record_resource_exchange_milestone(
  'f5600000-0000-4000-8000-000000000001',
  'f5630000-0000-4000-8000-000000000001',
  'f5640000-0000-4000-8000-000000000001',
  'owner_resource', 'resource_return_received'
);
select is(
  (select is_at_risk from public.list_owned_resource_listing_loan_schedule(
     'f5600000-0000-4000-8000-000000000001',
     'f5610000-0000-4000-8000-000000000001'
   ) where agreement_id = 'f5630000-0000-4000-8000-000000000002'),
  false, 'canonical return/completion clears later at-risk derivation'
);
select is(
  (select count(*) from public.list_owned_resource_listing_loan_schedule(
     'f5600000-0000-4000-8000-000000000001',
     'f5610000-0000-4000-8000-000000000001'
   )), 1::bigint, 'completed LEND leaves the active owner schedule'
);

select set_config('request.jwt.claim.sub',
  'f5600000-0000-4000-8000-000000000004', true);
select is(
  (select is_available from public.check_resource_exchange_pending_loan_availability(
     'f5600000-0000-4000-8000-000000000004',
     'f5630000-0000-4000-8000-000000000003',
     'f5640000-0000-4000-8000-000000000003'
   )), true, 'completed reservation no longer blocks its old period'
);
select is(
  public.accept_resource_exchange_terms(
    'f5600000-0000-4000-8000-000000000004',
    'f5630000-0000-4000-8000-000000000003',
    'f5640000-0000-4000-8000-000000000003'
  ),
  'f5640000-0000-4000-8000-000000000003'::uuid,
  'released period may be accepted without automatic promotion'
);

reset role;
insert into public.resource_exchange_agreement_terms (
  id, agreement_id, version_number, proposed_by_profile_id,
  listing_title_snapshot, listing_description_snapshot,
  owner_transfer_kind, owner_lend_starts_at, owner_lend_ends_at,
  requester_transfer_kind
) values
  ('f5640000-0000-4000-8000-000000000005',
   'f5630000-0000-4000-8000-000000000003', 2,
   'f5600000-0000-4000-8000-000000000001', 'Loan tool one', 'One lending unit.',
   'lend', current_setting('test.loan_t0')::timestamptz + interval '1 day',
   current_setting('test.loan_t0')::timestamptz + interval '3 days', 'none'),
  ('f5640000-0000-4000-8000-000000000006',
   'f5630000-0000-4000-8000-000000000003', 3,
   'f5600000-0000-4000-8000-000000000001', 'Loan tool one', 'One lending unit.',
   'lend', current_setting('test.loan_t0')::timestamptz - interval '3 days',
   current_setting('test.loan_t0')::timestamptz - interval '1 day', 'none'),
  ('f5640000-0000-4000-8000-000000000007',
   'f5630000-0000-4000-8000-000000000003', 4,
   'f5600000-0000-4000-8000-000000000001', 'Loan tool one', 'One lending unit.',
   'give', null, null, 'none'),
  ('f5640000-0000-4000-8000-000000000008',
   'f5630000-0000-4000-8000-000000000004', 2,
   'f5600000-0000-4000-8000-000000000001', 'Loan tool two', 'Independent lending unit.',
   'lend', current_setting('test.loan_t0')::timestamptz - interval '1 day',
   current_setting('test.loan_t0')::timestamptz + interval '2 days', 'none');

update public.resource_exchange_agreements
set pending_terms_id = 'f5640000-0000-4000-8000-000000000005'
where id = 'f5630000-0000-4000-8000-000000000003';
set local role authenticated;
select set_config('request.jwt.claim.sub',
  'f5600000-0000-4000-8000-000000000004', true);
select throws_ok(
  $$select public.accept_resource_exchange_terms(
    'f5600000-0000-4000-8000-000000000004',
    'f5630000-0000-4000-8000-000000000003',
    'f5640000-0000-4000-8000-000000000005'
  )$$,
  'PT409', 'The listing already has an accepted loan for that period.',
  'conflicting LEND replacement cannot replace current reservation'
);
reset role;
update public.resource_exchange_agreements
set pending_terms_id = 'f5640000-0000-4000-8000-000000000006'
where id = 'f5630000-0000-4000-8000-000000000003';
set local role authenticated;
select set_config('request.jwt.claim.sub',
  'f5600000-0000-4000-8000-000000000004', true);
select is(
  public.accept_resource_exchange_terms(
    'f5600000-0000-4000-8000-000000000004',
    'f5630000-0000-4000-8000-000000000003',
    'f5640000-0000-4000-8000-000000000006'
  ),
  'f5640000-0000-4000-8000-000000000006'::uuid,
  'compatible same-agreement replacement excludes its old period'
);
reset role;
update public.resource_exchange_agreements
set pending_terms_id = 'f5640000-0000-4000-8000-000000000007'
where id = 'f5630000-0000-4000-8000-000000000003';
set local role authenticated;
select set_config('request.jwt.claim.sub',
  'f5600000-0000-4000-8000-000000000004', true);
select public.accept_resource_exchange_terms(
  'f5600000-0000-4000-8000-000000000004',
  'f5630000-0000-4000-8000-000000000003',
  'f5640000-0000-4000-8000-000000000007'
);
reset role;
select is(
  (select count(*) from private.active_resource_listing_loan_reservations()
   where agreement_id = 'f5630000-0000-4000-8000-000000000003'),
  0::bigint, 'LEND to GIVE replacement releases reservation'
);

set local role authenticated;
select set_config('request.jwt.claim.sub',
  'f5600000-0000-4000-8000-000000000005', true);
select public.accept_resource_exchange_terms(
  'f5600000-0000-4000-8000-000000000005',
  'f5630000-0000-4000-8000-000000000004',
  'f5640000-0000-4000-8000-000000000004'
);
reset role;
select is(
  (select count(*) from private.active_resource_listing_loan_reservations()
   where agreement_id = 'f5630000-0000-4000-8000-000000000004'),
  0::bigint, 'accepted GIVE does not reserve'
);
update public.resource_exchange_agreements
set pending_terms_id = 'f5640000-0000-4000-8000-000000000008'
where id = 'f5630000-0000-4000-8000-000000000004';
set local role authenticated;
select set_config('request.jwt.claim.sub',
  'f5600000-0000-4000-8000-000000000005', true);
select public.accept_resource_exchange_terms(
  'f5600000-0000-4000-8000-000000000005',
  'f5630000-0000-4000-8000-000000000004',
  'f5640000-0000-4000-8000-000000000008'
);
reset role;
select is(
  (select count(*) from private.active_resource_listing_loan_reservations()
   where agreement_id = 'f5630000-0000-4000-8000-000000000004'),
  1::bigint, 'GIVE to LEND replacement activates other listing independently'
);
set local role authenticated;
select set_config('request.jwt.claim.sub',
  'f5600000-0000-4000-8000-000000000001', true);
select public.close_resource_listing(
  'f5600000-0000-4000-8000-000000000001',
  'f5610000-0000-4000-8000-000000000002'
);
select is(
  (select count(*) from public.list_owned_resource_listing_loan_schedule(
     'f5600000-0000-4000-8000-000000000001',
     'f5610000-0000-4000-8000-000000000002'
   )), 1::bigint, 'listing closure preserves agreed LEND reservation'
);
select public.cancel_resource_exchange_agreement(
  'f5600000-0000-4000-8000-000000000001',
  'f5630000-0000-4000-8000-000000000004'
);
select is(
  (select count(*) from public.list_owned_resource_listing_loan_schedule(
     'f5600000-0000-4000-8000-000000000001',
     'f5610000-0000-4000-8000-000000000002'
   )), 0::bigint, 'pre-handoff cancellation releases even a closed listing'
);

select * from finish();
rollback;
