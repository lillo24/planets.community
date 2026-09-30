begin;

-- Renumbered during stack integration to preserve globally unique pgTAP order.

select no_plan();

insert into auth.users (id, email)
values
  ('f1000000-0000-4000-8000-000000000001', 'saved-search-a@planets.invalid'),
  ('f2000000-0000-4000-8000-000000000002', 'saved-search-b@planets.invalid');

insert into public.profiles (id, display_name)
values
  ('f1000000-0000-4000-8000-000000000001', 'Saved Search A'),
  ('f2000000-0000-4000-8000-000000000002', 'Saved Search B');

set local role anon;
select throws_ok(
  $$select public.create_resource_saved_search(null, 'trapano', null, null)$$,
  '42501',
  'permission denied for function create_resource_saved_search',
  'anonymous users cannot create saved searches'
);
select throws_ok(
  $$select * from public.list_own_resource_saved_searches(null, 20, null, null)$$,
  '42501',
  'permission denied for function list_own_resource_saved_searches',
  'anonymous users cannot list private saved searches'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'f1000000-0000-4000-8000-000000000001',
  true
);

select throws_ok(
  $$select public.create_resource_saved_search(
    'f2000000-0000-4000-8000-000000000002', 'trapano', null, null
  )$$,
  '42501',
  'The authenticated user does not match the expected resource listing owner.',
  'stale expected identity is rejected'
);
select throws_ok(
  $$select public.create_resource_saved_search(
    'f1000000-0000-4000-8000-000000000001', '   ', ' ', null
  )$$,
  '22023',
  'A resource saved search must contain at least one filter.',
  'all-empty filters are rejected after normalization'
);
select throws_ok(
  $$select public.create_resource_saved_search(
    'f1000000-0000-4000-8000-000000000001', repeat('q', 121), null, null
  )$$,
  '22023',
  'Resource saved-search query must contain at most 120 characters.',
  'queries longer than 120 characters are rejected'
);
select throws_ok(
  $$select public.create_resource_saved_search(
    'f1000000-0000-4000-8000-000000000001', null, null, repeat('l', 121)
  )$$,
  '22023',
  'Resource saved-search locality must contain at most 120 characters.',
  'localities longer than 120 characters are rejected'
);
select throws_ok(
  $$select public.create_resource_saved_search(
    'f1000000-0000-4000-8000-000000000001', null, 'lend', null
  )$$,
  '22023',
  'Resource saved-search mode must be donate or exchange.',
  'modes outside Dona and Scambia are rejected'
);

select set_config(
  'test.query_saved_search_id',
  public.create_resource_saved_search(
    'f1000000-0000-4000-8000-000000000001',
    '  Trapano  ', null, null
  )::text,
  true
);
select set_config(
  'test.mode_saved_search_id',
  public.create_resource_saved_search(
    'f1000000-0000-4000-8000-000000000001',
    null, ' DONATE ', null
  )::text,
  true
);
select set_config(
  'test.locality_saved_search_id',
  public.create_resource_saved_search(
    'f1000000-0000-4000-8000-000000000001',
    null, null, '  Trento  '
  )::text,
  true
);
select set_config(
  'test.all_saved_search_id',
  public.create_resource_saved_search(
    'f1000000-0000-4000-8000-000000000001',
    '  Bosch 18  ', ' EXCHANGE ', '  Rovereto  '
  )::text,
  true
);

select results_eq(
  $$
    select query, listing_mode, locality
    from public.get_own_resource_saved_search(
      'f1000000-0000-4000-8000-000000000001',
      current_setting('test.query_saved_search_id')::uuid
    )
  $$,
  $$values ('Trapano'::text, null::text, null::text)$$,
  'query-only saved searches are trimmed'
);
select results_eq(
  $$
    select query, listing_mode, locality
    from public.get_own_resource_saved_search(
      'f1000000-0000-4000-8000-000000000001',
      current_setting('test.mode_saved_search_id')::uuid
    )
  $$,
  $$values (null::text, 'donate'::text, null::text)$$,
  'mode-only saved searches are trimmed and lowercased'
);
select results_eq(
  $$
    select query, listing_mode, locality
    from public.get_own_resource_saved_search(
      'f1000000-0000-4000-8000-000000000001',
      current_setting('test.locality_saved_search_id')::uuid
    )
  $$,
  $$values (null::text, null::text, 'Trento'::text)$$,
  'locality-only saved searches are trimmed'
);
select results_eq(
  $$
    select query, listing_mode, locality
    from public.get_own_resource_saved_search(
      'f1000000-0000-4000-8000-000000000001',
      current_setting('test.all_saved_search_id')::uuid
    )
  $$,
  $$values ('Bosch 18'::text, 'exchange'::text, 'Rovereto'::text)$$,
  'all three current browse filters can be saved together'
);

select set_config(
  'test.one_character_saved_search_id',
  public.create_resource_saved_search(
    'f1000000-0000-4000-8000-000000000001', 'x', null, null
  )::text,
  true
);
select is(
  (select query from public.get_own_resource_saved_search(
    'f1000000-0000-4000-8000-000000000001',
    current_setting('test.one_character_saved_search_id')::uuid
  )),
  'x',
  'one-character queries satisfy the 1..120 contract'
);

select throws_ok(
  $$select public.create_resource_saved_search(
    'f1000000-0000-4000-8000-000000000001', '  tRaPaNo ', null, null
  )$$,
  'PT409',
  'That resource saved search already exists.',
  'query case and whitespace do not create a semantic duplicate'
);
select throws_ok(
  $$select public.create_resource_saved_search(
    'f1000000-0000-4000-8000-000000000001', null, 'donate', ' '
  )$$,
  'PT409',
  'That resource saved search already exists.',
  'null and normalized-empty combinations share duplicate semantics'
);
select throws_ok(
  $$select public.create_resource_saved_search(
    'f1000000-0000-4000-8000-000000000001', null, null, ' tRENTO '
  )$$,
  'PT409',
  'That resource saved search already exists.',
  'locality case and whitespace do not create a semantic duplicate'
);

select set_config(
  'test.distinct_saved_search_id',
  public.create_resource_saved_search(
    'f1000000-0000-4000-8000-000000000001',
    'Trapano', 'exchange', null
  )::text,
  true
);
select ok(
  current_setting('test.distinct_saved_search_id')::uuid <>
    current_setting('test.query_saved_search_id')::uuid,
  'a different filter combination remains distinct'
);

select set_config(
  'test.query_created_at',
  (select created_at::text from public.get_own_resource_saved_search(
    'f1000000-0000-4000-8000-000000000001',
    current_setting('test.query_saved_search_id')::uuid
  )),
  true
);
select set_config(
  'test.query_updated_at',
  (select updated_at::text from public.get_own_resource_saved_search(
    'f1000000-0000-4000-8000-000000000001',
    current_setting('test.query_saved_search_id')::uuid
  )),
  true
);
select pg_sleep(0.01);
select is(
  public.update_resource_saved_search(
    'f1000000-0000-4000-8000-000000000001',
    current_setting('test.query_saved_search_id')::uuid,
    '  Trapano Bosch  ', null, null
  ),
  current_setting('test.query_saved_search_id')::uuid,
  'an owner can atomically replace saved filters'
);
select ok(
  (select created_at from public.get_own_resource_saved_search(
    'f1000000-0000-4000-8000-000000000001',
    current_setting('test.query_saved_search_id')::uuid
  )) = current_setting('test.query_created_at')::timestamptz
  and (select updated_at from public.get_own_resource_saved_search(
    'f1000000-0000-4000-8000-000000000001',
    current_setting('test.query_saved_search_id')::uuid
  )) > current_setting('test.query_updated_at')::timestamptz,
  'updates preserve creation time and advance canonical update time'
);

select throws_ok(
  format(
    'select public.update_resource_saved_search(%L, %L, %L, null, null)',
    'f1000000-0000-4000-8000-000000000001',
    current_setting('test.mode_saved_search_id'),
    'Trapano Bosch'
  ),
  'PT409',
  'That resource saved search already exists.',
  'updates toward an existing semantic tuple return PT409'
);
select results_eq(
  $$
    select query, listing_mode, locality
    from public.get_own_resource_saved_search(
      'f1000000-0000-4000-8000-000000000001',
      current_setting('test.mode_saved_search_id')::uuid
    )
  $$,
  $$values (null::text, 'donate'::text, null::text)$$,
  'a conflicting update leaves the original definition intact'
);

select set_config(
  'request.jwt.claim.sub',
  'f2000000-0000-4000-8000-000000000002',
  true
);
select set_config(
  'test.other_saved_search_id',
  public.create_resource_saved_search(
    'f2000000-0000-4000-8000-000000000002',
    'Trapano Bosch', null, null
  )::text,
  true
);
select is((
  select count(*)
  from public.get_own_resource_saved_search(
    'f2000000-0000-4000-8000-000000000002',
    current_setting('test.query_saved_search_id')::uuid
  )
), 0::bigint, 'another profile cannot exact-read a guessed saved-search UUID');
select is((
  select count(*)
  from public.list_own_resource_saved_searches(
    'f2000000-0000-4000-8000-000000000002', 20, null, null
  )
), 1::bigint, 'another profile lists only its own saved searches');
select throws_ok(
  format(
    'select public.update_resource_saved_search(%L, %L, %L, null, null)',
    'f2000000-0000-4000-8000-000000000002',
    current_setting('test.query_saved_search_id'),
    'Cross-account edit'
  ),
  '42501',
  'The current user does not own this resource saved search.',
  'another profile cannot update a guessed saved-search UUID'
);
select throws_ok(
  format(
    'select public.delete_resource_saved_search(%L, %L)',
    'f2000000-0000-4000-8000-000000000002',
    current_setting('test.query_saved_search_id')
  ),
  '42501',
  'The current user does not own this resource saved search.',
  'another profile cannot delete a guessed saved-search UUID'
);
select throws_ok(
  $$select public.delete_resource_saved_search(
    'f2000000-0000-4000-8000-000000000002',
    'ffffffff-ffff-4fff-8fff-ffffffffffff'
  )$$,
  '42501',
  'The current user does not own this resource saved search.',
  'unknown UUIDs fail with the same ownership error'
);
select throws_ok(
  $$select id from public.resource_saved_searches$$,
  '42501',
  'permission denied for table resource_saved_searches',
  'authenticated users cannot bypass private RPCs with direct reads'
);

select set_config(
  'request.jwt.claim.sub',
  'f1000000-0000-4000-8000-000000000001',
  true
);
select throws_ok(
  $$select * from public.list_own_resource_saved_searches(
    'f1000000-0000-4000-8000-000000000001', 0, null, null
  )$$,
  '22023',
  'Resource saved-search page size must be between 1 and 50.',
  'zero page size is rejected'
);
select throws_ok(
  $$select * from public.list_own_resource_saved_searches(
    'f1000000-0000-4000-8000-000000000001', 51, null, null
  )$$,
  '22023',
  'Resource saved-search page size must be between 1 and 50.',
  'page sizes above 50 are rejected'
);
select throws_ok(
  $$select * from public.list_own_resource_saved_searches(
    'f1000000-0000-4000-8000-000000000001',
    20, statement_timestamp(), null
  )$$,
  '22023',
  'Resource saved-search cursor values must be supplied together.',
  'partial descending cursors are rejected'
);

select set_config(
  'test.tie_one_id',
  public.create_resource_saved_search(
    'f1000000-0000-4000-8000-000000000001', 'Tie one', null, null
  )::text,
  true
);
select set_config(
  'test.tie_two_id',
  public.create_resource_saved_search(
    'f1000000-0000-4000-8000-000000000001', 'Tie two', null, null
  )::text,
  true
);

reset role;
update public.resource_saved_searches
set query = query
where id in (
  current_setting('test.tie_one_id')::uuid,
  current_setting('test.tie_two_id')::uuid
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'f1000000-0000-4000-8000-000000000001',
  true
);
select set_config(
  'test.first_tie_id',
  (select saved_search_id::text
   from public.list_own_resource_saved_searches(
     'f1000000-0000-4000-8000-000000000001', 1, null, null
   )),
  true
);
select set_config(
  'test.first_tie_updated_at',
  (select updated_at::text
   from public.list_own_resource_saved_searches(
     'f1000000-0000-4000-8000-000000000001', 1, null, null
   )),
  true
);
select is(
  current_setting('test.first_tie_id')::uuid,
  greatest(
    current_setting('test.tie_one_id')::uuid,
    current_setting('test.tie_two_id')::uuid
  ),
  'equal update timestamps tie-break by UUID descending'
);
select is(
  (select saved_search_id
   from public.list_own_resource_saved_searches(
     'f1000000-0000-4000-8000-000000000001',
     1,
     current_setting('test.first_tie_updated_at')::timestamptz,
     current_setting('test.first_tie_id')::uuid
   )),
  least(
    current_setting('test.tie_one_id')::uuid,
    current_setting('test.tie_two_id')::uuid
  ),
  'the complete descending cursor reaches the other tied row exactly once'
);

select is(
  public.delete_resource_saved_search(
    'f1000000-0000-4000-8000-000000000001',
    current_setting('test.one_character_saved_search_id')::uuid
  ),
  current_setting('test.one_character_saved_search_id')::uuid,
  'an owner can hard-delete a saved search'
);
select is((
  select count(*)
  from public.get_own_resource_saved_search(
    'f1000000-0000-4000-8000-000000000001',
    current_setting('test.one_character_saved_search_id')::uuid
  )
), 0::bigint, 'hard delete removes the saved-search definition');

reset role;

insert into public.resource_listings (
  id, owner_profile_id, listing_mode, lifecycle_state,
  title, description, country_code, locality,
  public_location_label, published_at, closed_at
)
values
  (
    'f1aa0000-0000-4000-8000-000000000001',
    'f2000000-0000-4000-8000-000000000002',
    'donate', 'published', 'Trapano Bosch', 'Modello Bosch 18V',
    'IT', 'Trento', 'Trento', '2090-01-04T12:00:00Z', null
  ),
  (
    'f1aa0000-0000-4000-8000-000000000002',
    'f2000000-0000-4000-8000-000000000002',
    'exchange', 'published', 'Trapano manuale', 'Utensile semplice',
    'IT', 'Trento', 'Trento', '2090-01-03T12:00:00Z', null
  ),
  (
    'f1aa0000-0000-4000-8000-000000000003',
    'f2000000-0000-4000-8000-000000000002',
    'donate', 'published', 'Sega circolare', 'Motore Bosch 18V',
    'IT', 'Rovereto', 'Rovereto', '2090-01-02T12:00:00Z', null
  ),
  (
    'f1aa0000-0000-4000-8000-000000000004',
    'f2000000-0000-4000-8000-000000000002',
    'exchange', 'published', 'Martello', 'Manico in legno',
    'IT', 'Bolzano', 'Bolzano', '2090-01-01T12:00:00Z', null
  ),
  (
    'f1aa0000-0000-4000-8000-000000000005',
    'f2000000-0000-4000-8000-000000000002',
    'donate', 'draft', 'Trapano da banco', 'Bosch 18V',
    'IT', 'Trento', 'Trento', null, null
  ),
  (
    'f1aa0000-0000-4000-8000-000000000006',
    'f2000000-0000-4000-8000-000000000002',
    'donate', 'closed', 'Trapano chiuso', 'Bosch 18V',
    'IT', 'Trento', 'Trento',
    '2089-01-01T12:00:00Z', '2089-01-02T12:00:00Z'
  );

create temporary table test_saved_filter_combinations (
  saved_query text,
  saved_mode text,
  saved_locality text
) on commit drop;

insert into test_saved_filter_combinations
values
  ('Trapano', null, null),
  (null, 'donate', null),
  (null, null, 'Trento'),
  ('Trapano', 'donate', null),
  ('Trapano', null, 'Trento'),
  (null, 'donate', 'Trento'),
  ('Trapano', 'donate', 'Trento');

select is((
  select count(*)
  from test_saved_filter_combinations
), 7::bigint, 'the parity matrix covers all seven non-empty filter combinations');

select is((
  select bool_and(
    array(
      select public_row.listing_id
      from public.list_public_resource_listings(
        50,
        null,
        null,
        combination.saved_mode,
        combination.saved_locality,
        combination.saved_query
      ) as public_row
      order by public_row.listing_id
    ) = array(
      select listing.id
      from public.resource_listings as listing
      where listing.lifecycle_state = 'published'
        and private.resource_listing_matches_saved_search_filters(
          listing.listing_mode,
          listing.title,
          listing.description,
          listing.locality,
          combination.saved_mode,
          combination.saved_query,
          combination.saved_locality
        )
      order by listing.id
    )
  )
  from test_saved_filter_combinations as combination
), true, 'the private predicate exactly matches current browse semantics for all combinations');

select is(
  private.resource_listing_matches_saved_search_filters(
    'donate', 'Trapano Bosch', 'Modello Bosch 18V', 'Trento',
    null, 'trapano', null
  ),
  true,
  'literal query matching is case-insensitive in the title'
);
select is(
  private.resource_listing_matches_saved_search_filters(
    'donate', 'Trapano Bosch', 'Modello Bosch 18V', 'Trento',
    null, 'drill', null
  ),
  false,
  'literal matching does not introduce English synonyms or lexical expansion'
);
select is(
  private.resource_listing_matches_saved_search_filters(
    'donate', 'Trapano Bosch', 'Modello Bosch 18V', 'Trento',
    null, 'Bosch 18', null
  ),
  true,
  'literal query matching includes description substrings'
);
select is((
  select count(*)
  from public.list_public_resource_listings(
    50, null, null, null, null, 'drill'
  )
  where listing_id = 'f1aa0000-0000-4000-8000-000000000001'
), 0::bigint, 'public browse shares the same literal-not-lexical behavior');

select is((
  select count(*)
  from public.resource_listings as listing
  where listing.id in (
    'f1aa0000-0000-4000-8000-000000000005',
    'f1aa0000-0000-4000-8000-000000000006'
  )
    and private.resource_listing_matches_saved_search_filters(
      listing.listing_mode,
      listing.title,
      listing.description,
      listing.locality,
      'donate',
      'Trapano',
      'Trento'
    )
), 2::bigint, 'the field-only predicate is deliberately lifecycle-independent');
select is((
  select count(*)
  from public.list_public_resource_listings(
    50, null, null, 'donate', 'Trento', 'Trapano'
  )
  where listing_id in (
    'f1aa0000-0000-4000-8000-000000000005',
    'f1aa0000-0000-4000-8000-000000000006'
  )
), 0::bigint, 'current public browse still applies the published lifecycle boundary');

select is((
  select count(*)
  from private.audit_events
  where target_type = 'resource_saved_search'
), 0::bigint, 'saved-search CRUD emits no audit history');
select is((
  select count(*)
  from private.outbox_events
  where event_type like 'resource_saved_search.%'
), 0::bigint, 'saved-search CRUD emits no outbox events or notifications');

select * from finish();
rollback;
