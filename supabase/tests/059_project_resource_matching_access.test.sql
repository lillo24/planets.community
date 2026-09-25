begin;

select no_plan();

insert into auth.users (id, email) values
  ('e1100000-0000-4000-8000-000000000001', 'matching-creator@planets.invalid'),
  ('e1200000-0000-4000-8000-000000000002', 'matching-other@planets.invalid');
insert into public.profiles (id, display_name) values
  ('e1100000-0000-4000-8000-000000000001', 'Matching Creator'),
  ('e1200000-0000-4000-8000-000000000002', 'Matching Other');

insert into public.proposals (
  id, creator_profile_id, lifecycle_state, title, country_code,
  locality, administrative_area, starts_at, ends_at, published_at
) values
  ('e1300000-0000-4000-8000-000000000003',
    'e1100000-0000-4000-8000-000000000001', 'draft', 'Matching draft',
    'IT', 'Roma', 'Lazio', null, null, null),
  ('e1400000-0000-4000-8000-000000000004',
    'e1100000-0000-4000-8000-000000000001', 'published', 'Matching live',
    'IT', 'Roma', 'Lazio', statement_timestamp() + interval '1 day',
    statement_timestamp() + interval '2 days', statement_timestamp() - interval '1 day'),
  ('e1500000-0000-4000-8000-000000000005',
    'e1100000-0000-4000-8000-000000000001', 'published', 'Matching expired',
    'IT', 'Roma', 'Lazio', statement_timestamp() - interval '2 days',
    statement_timestamp() - interval '1 day', statement_timestamp() - interval '3 days'),
  ('e1600000-0000-4000-8000-000000000006',
    'e1100000-0000-4000-8000-000000000001', 'draft', 'Matching no location',
    null, null, null, null, null, null);

insert into public.recurring_activities (
  id, creator_profile_id, lifecycle_state, title, country_code,
  locality, administrative_area, published_at, paused_at, ended_at
) values
  ('e1700000-0000-4000-8000-000000000007',
    'e1100000-0000-4000-8000-000000000001', 'paused', 'Matching paused Tavolo',
    'IT', 'Roma', 'Lazio', statement_timestamp() - interval '2 days',
    statement_timestamp() - interval '1 day', null),
  ('e1800000-0000-4000-8000-000000000008',
    'e1100000-0000-4000-8000-000000000001', 'ended', 'Matching ended Tavolo',
    'IT', 'Roma', 'Lazio', statement_timestamp() - interval '2 days',
    null, statement_timestamp() - interval '1 day');

insert into public.project_resource_needs (
  id, project_id, title, details, state, closed_at, created_at, updated_at
)
values
  ('e1900000-0000-4000-8000-000000000009',
    'e1300000-0000-4000-8000-000000000003', 'Trapano a percussione', 'Bosch',
    'open', null, statement_timestamp(), statement_timestamp()),
  ('e1a00000-0000-4000-8000-00000000000a',
    'e1300000-0000-4000-8000-000000000003', 'Trapano a percussione', null,
    'closed', statement_timestamp(),
    statement_timestamp() - interval '1 day', statement_timestamp()),
  ('e1b00000-0000-4000-8000-00000000000b',
    'e1400000-0000-4000-8000-000000000004', 'Trapano a percussione', null,
    'open', null, statement_timestamp(), statement_timestamp()),
  ('e1c00000-0000-4000-8000-00000000000c',
    'e1500000-0000-4000-8000-000000000005', 'Trapano a percussione', null,
    'open', null, statement_timestamp(), statement_timestamp()),
  ('e1d00000-0000-4000-8000-00000000000d',
    'e1600000-0000-4000-8000-000000000006', 'Trapano a percussione', null,
    'open', null, statement_timestamp(), statement_timestamp()),
  ('e1e00000-0000-4000-8000-00000000000e',
    'e1700000-0000-4000-8000-000000000007', 'Trapano a percussione', null,
    'open', null, statement_timestamp(), statement_timestamp()),
  ('e1f00000-0000-4000-8000-00000000000f',
    'e1800000-0000-4000-8000-000000000008', 'Trapano a percussione', null,
    'open', null, statement_timestamp(), statement_timestamp());

insert into public.resource_listings (
  id, owner_profile_id, listing_mode, lifecycle_state, title, description,
  country_code, locality, administrative_area, public_location_label,
  published_at, closed_at
) values
  ('e2100000-0000-4000-8000-000000000001',
    'e1200000-0000-4000-8000-000000000002', 'donate', 'published',
    'Trapano a percussione 18V', 'Disponibile', 'IT', 'ROMA', 'lazio', 'Roma',
    statement_timestamp() - interval '3 days', null),
  ('e2200000-0000-4000-8000-000000000002',
    'e1200000-0000-4000-8000-000000000002', 'exchange', 'published',
    'Trapano a percussione Bosch', 'Disponibile', 'IT', 'Milano', 'Lombardia', 'Milano',
    statement_timestamp() - interval '1 day', null),
  ('e2300000-0000-4000-8000-000000000003',
    'e1200000-0000-4000-8000-000000000002', 'donate', 'published',
    'Trapano Bosch', 'Disponibile', 'IT', 'Viterbo', 'Lazio', 'Viterbo',
    statement_timestamp() - interval '2 days', null),
  ('e2400000-0000-4000-8000-000000000004',
    'e1200000-0000-4000-8000-000000000002', 'exchange', 'published',
    'Utensile elettrico', 'Trapano disponibile', 'IT', 'Roma', 'Lazio', 'Roma',
    statement_timestamp() - interval '2 days', null),
  ('e2500000-0000-4000-8000-000000000005',
    'e1200000-0000-4000-8000-000000000002', 'donate', 'published',
    'Kit Bosch', 'Disponibile', 'FR', 'Paris', 'Île-de-France', 'Paris',
    statement_timestamp() - interval '2 days', null),
  ('e2600000-0000-4000-8000-000000000006',
    'e1200000-0000-4000-8000-000000000002', 'exchange', 'published',
    'Kit utensili', 'Bosch incluso', 'IT', 'Roma', 'Lazio', 'Roma',
    statement_timestamp() - interval '2 days', null),
  ('e2700000-0000-4000-8000-000000000007',
    'e1200000-0000-4000-8000-000000000002', 'donate', 'published',
    'Scala in alluminio', 'Disponibile', 'IT', 'Roma', 'Lazio', 'Roma',
    statement_timestamp() - interval '2 days', null),
  ('e2800000-0000-4000-8000-000000000008',
    'e1200000-0000-4000-8000-000000000002', 'donate', 'draft',
    'Trapano a percussione nascosto', 'Disponibile', 'IT', 'Roma', 'Lazio', 'Roma', null, null),
  ('e2900000-0000-4000-8000-000000000009',
    'e1200000-0000-4000-8000-000000000002', 'donate', 'closed',
    'Trapano a percussione chiuso', 'Disponibile', 'IT', 'Roma', 'Lazio', 'Roma',
    statement_timestamp() - interval '4 days',
    statement_timestamp() - interval '1 day');

select is((
  select text_match_kind from private.evaluate_project_resource_listing_match(
    '  Trapano   a percussione ', null, 'IT', 'Roma', 'Lazio',
    'TRAPANO a   PERCUSSIONE Bosch', null, 'IT', 'Roma', 'Lazio'
  )
), 'title_phrase', 'phrase tier ignores repeated whitespace and case');
select is((
  select text_match_kind from private.evaluate_project_resource_listing_match(
    'Pennelli', null, 'IT', 'Roma', 'Lazio',
    'Pennello Bosch', null, 'IT', 'Roma', 'Lazio'
  )
), 'need_title_in_listing_title', 'Italian stemming matches a plural title variant');
select is((
  select text_match_kind from private.evaluate_project_resource_listing_match(
    'Trapano', null, 'IT', 'Roma', 'Lazio',
    'Utensile', 'Trapano disponibile', 'IT', 'Roma', 'Lazio'
  )
), 'need_title_in_listing_description', 'title lexeme in description has the third tier');
select is((
  select text_match_kind from private.evaluate_project_resource_listing_match(
    'Percussione', 'Bosch', 'IT', 'Roma', 'Lazio',
    'Kit Bosch', null, 'IT', 'Roma', 'Lazio'
  )
), 'need_details_in_listing_title', 'details fallback matches listing title');
select is((
  select text_match_kind from private.evaluate_project_resource_listing_match(
    'Percussione', 'Bosch', 'IT', 'Roma', 'Lazio',
    'Kit', 'Bosch incluso', 'IT', 'Roma', 'Lazio'
  )
), 'need_details_in_listing_description', 'details fallback matches description');
select is((
  select is_match from private.evaluate_project_resource_listing_match(
    'Trapano', null, 'IT', 'Roma', 'Lazio',
    'Scala', 'Alluminio', 'IT', 'Roma', 'Lazio'
  )
), false, 'geography alone never creates a candidate');
select is((
  select is_match from private.evaluate_project_resource_listing_match(
    'il e con', null, 'IT', 'Roma', 'Lazio',
    'Scala', 'Alluminio', 'IT', 'Roma', 'Lazio'
  )
), false, 'stopword-only title contributes no keyword tier');
select ok(private.project_resource_match_or_query('Bosch 18V: (x) OR o''clock') is not null,
  'punctuation, model tokens, and tsquery-looking input remain safe text');
select is((
  select location_match_kind from private.evaluate_project_resource_listing_match(
    'Trapano', null, null, 'Roma', null,
    'Trapano', null, 'US', ' roma ', 'New York'
  )
), 'same_locality', 'locality comparison is case-insensitive and needs no country');
select is((
  select location_match_kind from private.evaluate_project_resource_listing_match(
    'Trapano', null, 'IT', 'Roma', 'Lazio',
    'Trapano', null, 'IT', 'Viterbo', ' LAZIO '
  )
), 'same_administrative_area', 'area comparison requires the same country');
select is((
  select location_match_kind from private.evaluate_project_resource_listing_match(
    'Trapano', null, 'IT', 'Roma', 'Lazio',
    'Trapano', null, 'IT', 'Milano', 'Lombardia'
  )
), 'same_country', 'same country is used when locality and area differ');
select is((
  select location_match_kind from private.evaluate_project_resource_listing_match(
    'Trapano', null, 'IT', 'Roma', 'Lazio',
    'Trapano', null, null, null, null
  )
), 'other_or_unknown', 'missing or outside listing geography remains explicit');

select set_config('test.match_cursor_at', (
  select published_at::text from public.resource_listings
  where id = 'e2300000-0000-4000-8000-000000000003'
), true);

set local role anon;
select throws_ok(
  $$select * from public.list_project_resource_need_listing_matches(
    'e1100000-0000-4000-8000-000000000001',
    'e1900000-0000-4000-8000-000000000009', 'anywhere')$$,
  '42501', null, 'anonymous matching is denied'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', 'e1200000-0000-4000-8000-000000000002', true);
select throws_ok(
  $$select * from public.list_project_resource_need_listing_matches(
    'e1200000-0000-4000-8000-000000000002',
    'e1900000-0000-4000-8000-000000000009', 'anywhere')$$,
  '42501', 'Only the Project creator can match its resource need.',
  'unrelated profile cannot use the need as a search oracle'
);
select set_config('request.jwt.claim.sub', 'e1100000-0000-4000-8000-000000000001', true);
select throws_ok(
  $$select * from public.list_project_resource_need_listing_matches(
    'e1200000-0000-4000-8000-000000000002',
    'e1900000-0000-4000-8000-000000000009', 'anywhere')$$,
  '42501', null, 'expected creator must equal authenticated profile'
);
select throws_ok(
  $$select * from public.list_project_resource_need_listing_matches(
    'e1100000-0000-4000-8000-000000000001',
    'e1a00000-0000-4000-8000-00000000000a', 'anywhere')$$,
  '55000', 'Only an open Project resource need can be matched.',
  'closed needs cannot be matched'
);
select throws_ok(
  $$select * from public.list_project_resource_need_listing_matches(
    'e1100000-0000-4000-8000-000000000001',
    'e1c00000-0000-4000-8000-00000000000c', 'anywhere')$$,
  '55000', 'The Proposal is no longer eligible for resource matching.',
  'time-completed Proposal cannot be matched'
);
select throws_ok(
  $$select * from public.list_project_resource_need_listing_matches(
    'e1100000-0000-4000-8000-000000000001',
    'e1f00000-0000-4000-8000-00000000000f', 'anywhere')$$,
  '55000', 'The Tavolo is no longer eligible for resource matching.',
  'ended Tavolo cannot be matched'
);
select is((select count(*) from public.list_project_resource_need_listing_matches(
  'e1100000-0000-4000-8000-000000000001',
  'e1b00000-0000-4000-8000-00000000000b', 'anywhere')),
  4::bigint, 'active published Proposal may match');
select is((select count(*) from public.list_project_resource_need_listing_matches(
  'e1100000-0000-4000-8000-000000000001',
  'e1e00000-0000-4000-8000-00000000000e', 'anywhere')),
  4::bigint, 'paused Tavolo may match');
select is((select count(*) from public.list_project_resource_need_listing_matches(
  'e1100000-0000-4000-8000-000000000001',
  'e1900000-0000-4000-8000-000000000009', 'anywhere')),
  6::bigint, 'draft creator sees six lexical candidates, not drafts/closed/no-match');
select results_eq(
  $$select listing_id from public.list_project_resource_need_listing_matches(
    'e1100000-0000-4000-8000-000000000001',
    'e1900000-0000-4000-8000-000000000009', 'anywhere')$$,
  $$values
    ('e2100000-0000-4000-8000-000000000001'::uuid),
    ('e2200000-0000-4000-8000-000000000002'::uuid),
    ('e2300000-0000-4000-8000-000000000003'::uuid),
    ('e2400000-0000-4000-8000-000000000004'::uuid),
    ('e2500000-0000-4000-8000-000000000005'::uuid),
    ('e2600000-0000-4000-8000-000000000006'::uuid)$$,
  'text strength precedes geography and recency'
);
select is((select count(*) from public.list_project_resource_need_listing_matches(
  'e1100000-0000-4000-8000-000000000001',
  'e1900000-0000-4000-8000-000000000009', 'same_locality')),
  3::bigint, 'same-locality scope excludes remote lexical candidates');
select is((select count(*) from public.list_project_resource_need_listing_matches(
  'e1100000-0000-4000-8000-000000000001',
  'e1900000-0000-4000-8000-000000000009', 'same_administrative_area')),
  4::bigint, 'same-area scope requires the actual area and country');
select is((select count(*) from public.list_project_resource_need_listing_matches(
  'e1100000-0000-4000-8000-000000000001',
  'e1900000-0000-4000-8000-000000000009', 'same_country')),
  5::bigint, 'same-country scope excludes France');
select is((select count(*) from public.list_project_resource_need_listing_matches(
  'e1100000-0000-4000-8000-000000000001',
  'e1900000-0000-4000-8000-000000000009', 'anywhere', 20, 'donate')),
  3::bigint, 'donate mode returns only Dona');
select is((select count(*) from public.list_project_resource_need_listing_matches(
  'e1100000-0000-4000-8000-000000000001',
  'e1900000-0000-4000-8000-000000000009', 'anywhere', 20, 'exchange')),
  3::bigint, 'exchange mode returns only Scambia');
select throws_ok(
  $$select * from public.list_project_resource_need_listing_matches(
    'e1100000-0000-4000-8000-000000000001',
    'e1900000-0000-4000-8000-000000000009', 'anywhere', 20, 'lend')$$,
  '22023', 'Project resource matching mode must be donate or exchange.',
  'invalid mode fails explicitly'
);
select throws_ok(
  $$select * from public.list_project_resource_need_listing_matches(
    'e1100000-0000-4000-8000-000000000001',
    'e1d00000-0000-4000-8000-00000000000d', 'same_country')$$,
  '55000', 'The Project lacks rough geography required by the selected matching scope.',
  'missing required Project geography does not broaden the search'
);
select is((select count(*) from public.list_project_resource_need_listing_matches(
  'e1100000-0000-4000-8000-000000000001',
  'e1d00000-0000-4000-8000-00000000000d', 'anywhere')),
  4::bigint, 'anywhere is usable without Project geography');
select throws_ok(
  $$select * from public.list_project_resource_need_listing_matches(
    'e1100000-0000-4000-8000-000000000001',
    'e1900000-0000-4000-8000-000000000009', null)$$,
  '22023', 'An explicit valid Project resource matching location scope is required.',
  'location scope is required'
);
select throws_ok(
  $$select * from public.list_project_resource_need_listing_matches(
    'e1100000-0000-4000-8000-000000000001',
    'e1900000-0000-4000-8000-000000000009', 'anywhere', 0)$$,
  '22023', 'Project resource matching page size must be between 1 and 50.',
  'page size has a lower bound'
);
select throws_ok(
  $$select * from public.list_project_resource_need_listing_matches(
    'e1100000-0000-4000-8000-000000000001',
    'e1900000-0000-4000-8000-000000000009', 'anywhere', 51)$$,
  '22023', 'Project resource matching page size must be between 1 and 50.',
  'page size has an upper bound'
);
select throws_ok(
  $$select * from public.list_project_resource_need_listing_matches(
    'e1100000-0000-4000-8000-000000000001',
    'e1900000-0000-4000-8000-000000000009', 'anywhere', 20, null,
    'title_phrase')$$,
  '22023', 'All Project resource matching cursor values must be supplied together.',
  'partial keyset cursor fails explicitly'
);
select is((select count(*) from public.list_project_resource_need_listing_matches(
  'e1100000-0000-4000-8000-000000000001',
  'e1900000-0000-4000-8000-000000000009', 'anywhere', 2, null,
  'need_title_in_listing_title', 'same_administrative_area',
  current_setting('test.match_cursor_at')::timestamptz,
  'e2300000-0000-4000-8000-000000000003')),
  2::bigint, 'complete keyset resumes after the title-keyword/area candidate');
select is((
  select bool_and(matches.active_request_count = detail.active_request_count)
  from public.list_project_resource_need_listing_matches(
    'e1100000-0000-4000-8000-000000000001',
    'e1900000-0000-4000-8000-000000000009', 'anywhere') matches
  join lateral public.get_public_resource_listing(matches.listing_id) detail on true
), true, 'active-request counts exactly match the public detail projection');

reset role;
insert into public.resource_listings (
  id, owner_profile_id, listing_mode, lifecycle_state, title, description,
  country_code, locality, administrative_area, public_location_label,
  published_at
) values
  ('e2a00000-0000-4000-8000-00000000000a',
   'e1200000-0000-4000-8000-000000000002', 'exchange', 'published',
   'Trapano a percussione gemello', 'Disponibile', 'IT', 'Roma', 'Lazio',
   'Roma', statement_timestamp() - interval '5 days'),
  ('e2b00000-0000-4000-8000-00000000000b',
   'e1200000-0000-4000-8000-000000000002', 'exchange', 'published',
   'Trapano a percussione gemello', 'Disponibile', 'IT', 'Roma', 'Lazio',
   'Roma', statement_timestamp() - interval '5 days');
insert into public.resource_listing_requests (
  id, listing_id, requester_profile_id, status, resolved_at,
  resolved_by_profile_id
) values (
  'e2c00000-0000-4000-8000-00000000000c',
  'e2a00000-0000-4000-8000-00000000000a',
  'e1100000-0000-4000-8000-000000000001', 'accepted',
  statement_timestamp(), 'e1200000-0000-4000-8000-000000000002'
);
insert into public.resource_exchange_agreements (id, request_id) values (
  'e2d00000-0000-4000-8000-00000000000d',
  'e2c00000-0000-4000-8000-00000000000c'
);
insert into public.resource_exchange_agreement_terms (
  id, agreement_id, version_number, proposed_by_profile_id,
  listing_title_snapshot, listing_description_snapshot,
  owner_transfer_kind, owner_lend_starts_at, owner_lend_ends_at,
  requester_transfer_kind
) values (
  'e2e00000-0000-4000-8000-00000000000e',
  'e2d00000-0000-4000-8000-00000000000d', 1,
  'e1200000-0000-4000-8000-000000000002',
  'Trapano a percussione gemello', 'Disponibile', 'lend',
  statement_timestamp() + interval '1 day',
  statement_timestamp() + interval '2 days', 'none'
);
update public.resource_exchange_agreements
set lifecycle_state = 'agreed',
  current_terms_id = 'e2e00000-0000-4000-8000-00000000000e',
  current_terms_accepted_at = statement_timestamp()
where id = 'e2d00000-0000-4000-8000-00000000000d';
select is((
  select count(*) from private.active_resource_listing_loan_reservations(
    'e2a00000-0000-4000-8000-00000000000a'
  )
), 1::bigint, 'one otherwise-identical listing has a private active LEND reservation');

set local role authenticated;
select set_config('request.jwt.claim.sub', 'e1100000-0000-4000-8000-000000000001', true);
select results_eq(
  $$select listing_id, text_match_kind, location_match_kind
    from public.list_project_resource_need_listing_matches(
      'e1100000-0000-4000-8000-000000000001',
      'e1900000-0000-4000-8000-000000000009', 'same_locality', 50,
      'exchange'
    )
    where listing_id in (
      'e2a00000-0000-4000-8000-00000000000a',
      'e2b00000-0000-4000-8000-00000000000b'
    )$$,
  $$values
    ('e2b00000-0000-4000-8000-00000000000b'::uuid,
      'title_phrase'::text, 'same_locality'::text),
    ('e2a00000-0000-4000-8000-00000000000a'::uuid,
      'title_phrase'::text, 'same_locality'::text)$$,
  'private reservation does not change match eligibility or reason rank'
);

select finish();
rollback;
