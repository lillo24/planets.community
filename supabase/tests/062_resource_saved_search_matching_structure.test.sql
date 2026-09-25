begin;

select no_plan();

select has_table(
  'private',
  'resource_saved_search_listing_matches',
  'saved-search listing matches are durable private projection facts'
);
select ok(
  to_regclass('public.resource_saved_search_listing_matches') is null,
  'match facts are absent from the exposed public schema'
);
select columns_are(
  'private',
  'resource_saved_search_listing_matches',
  array[
    'id',
    'source_outbox_event_id',
    'saved_search_id',
    'saved_search_updated_at',
    'recipient_profile_id',
    'listing_id',
    'matched_at'
  ],
  'match facts retain only identifiers, chronology, and the search version token'
);
select col_is_pk(
  'private',
  'resource_saved_search_listing_matches',
  'id',
  'match facts have a stable UUID primary key'
);

select is(
  (
    select constraint_row.confdeltype::text
    from pg_constraint as constraint_row
    where constraint_row.conrelid =
      'private.resource_saved_search_listing_matches'::regclass
      and constraint_row.conname =
        'resource_saved_search_listing_matches_source_event_fkey'
  ),
  'r',
  'source outbox provenance is delete-restricted'
);
select is(
  (
    select constraint_row.confdeltype::text
    from pg_constraint as constraint_row
    where constraint_row.conrelid =
      'private.resource_saved_search_listing_matches'::regclass
      and constraint_row.conname =
        'resource_saved_search_listing_matches_saved_search_fkey'
  ),
  'c',
  'deleting a saved search cascades its private pending match facts'
);
select is(
  (
    select constraint_row.confdeltype::text
    from pg_constraint as constraint_row
    where constraint_row.conrelid =
      'private.resource_saved_search_listing_matches'::regclass
      and constraint_row.conname =
        'resource_saved_search_listing_matches_recipient_fkey'
  ),
  'c',
  'deleting a profile cascades its private pending match facts'
);
select is(
  (
    select constraint_row.confdeltype::text
    from pg_constraint as constraint_row
    where constraint_row.conrelid =
      'private.resource_saved_search_listing_matches'::regclass
      and constraint_row.conname =
        'resource_saved_search_listing_matches_listing_fkey'
  ),
  'r',
  'canonical listing provenance is delete-restricted'
);

select ok(
  exists (
    select 1
    from pg_constraint as constraint_row
    where constraint_row.conrelid =
      'private.resource_saved_search_listing_matches'::regclass
      and constraint_row.conname =
        'resource_saved_search_listing_matches_search_listing_unique'
      and constraint_row.contype = 'u'
  ),
  'one fact per saved-search/listing pair is enforced'
);
select ok(
  exists (
    select 1
    from pg_constraint as constraint_row
    where constraint_row.conrelid =
      'private.resource_saved_search_listing_matches'::regclass
      and constraint_row.conname =
        'resource_saved_search_listing_matches_source_search_unique'
      and constraint_row.contype = 'u'
  ),
  'one fact per source-event/saved-search pair is enforced'
);
select ok(
  exists (
    select 1
    from pg_constraint as constraint_row
    where constraint_row.conrelid =
      'private.resource_saved_search_listing_matches'::regclass
      and constraint_row.conname =
        'resource_saved_search_listing_matches_version_valid'
      and constraint_row.contype = 'c'
  ),
  'the captured search version cannot postdate match chronology'
);

select ok(
  to_regclass(
    'private.resource_saved_search_listing_matches_recipient_idx'
  ) is not null
    and to_regclass(
      'private.resource_saved_search_listing_matches_listing_idx'
    ) is not null,
  'cascade/restrict lookup columns have supporting indexes'
);
select ok(
  to_regclass(
    'private.outbox_events_saved_search_matching_available_idx'
  ) is not null,
  'the independent consumer has a partial source-event scan index'
);

select ok(
  to_regprocedure(
    'public.process_resource_saved_search_matching_outbox_batch(integer)'
  ) is not null,
  'the bounded saved-search matching processor exists'
);
select is(
  (
    select procedure.prosecdef
    from pg_proc as procedure
    where procedure.oid =
      'public.process_resource_saved_search_matching_outbox_batch(integer)'
        ::regprocedure
  ),
  true,
  'the service processor is an explicit security-definer boundary'
);
select is(
  (
    select array_to_string(procedure.proconfig, ',')
    from pg_proc as procedure
    where procedure.oid =
      'public.process_resource_saved_search_matching_outbox_batch(integer)'
        ::regprocedure
  ),
  'search_path=""',
  'the service processor fixes an empty search path'
);
select is(
  has_function_privilege(
    'service_role',
    'public.process_resource_saved_search_matching_outbox_batch(integer)',
    'EXECUTE'
  ),
  true,
  'service_role can invoke the trusted processor'
);
select is(
  has_function_privilege(
    'authenticated',
    'public.process_resource_saved_search_matching_outbox_batch(integer)',
    'EXECUTE'
  ),
  false,
  'authenticated clients cannot invoke the trusted processor'
);
select is(
  has_function_privilege(
    'anon',
    'public.process_resource_saved_search_matching_outbox_batch(integer)',
    'EXECUTE'
  ),
  false,
  'anonymous clients cannot invoke the trusted processor'
);

select is(
  (
    select bool_or(
      has_table_privilege(
        role_name,
        'private.resource_saved_search_listing_matches',
        privilege_name
      )
    )
    from unnest(array['anon', 'authenticated', 'service_role'])
      as role_name
    cross join unnest(array['SELECT', 'INSERT', 'UPDATE', 'DELETE'])
      as privilege_name
  ),
  false,
  'API roles have no direct match-fact table privileges'
);
select is(
  (
    select count(*)
    from pg_proc as procedure
    join pg_namespace as namespace
      on namespace.oid = procedure.pronamespace
    where namespace.nspname = 'public'
      and procedure.proname like '%resource_saved_search%match%'
      and procedure.proname <>
        'process_resource_saved_search_matching_outbox_batch'
  ),
  0::bigint,
  'F3A exposes no public match-history read RPC'
);

select ok(
  lower(
    pg_get_functiondef(
      'public.process_resource_saved_search_matching_outbox_batch(integer)'
        ::regprocedure
    )
  ) like '%saved-search-matching.v1%',
  'the processor owns its independent consumer key'
);
select ok(
  lower(
    pg_get_functiondef(
      'public.process_resource_saved_search_matching_outbox_batch(integer)'
        ::regprocedure
    )
  ) like '%resource_saved_search.matched%',
  'the processor emits the frequency-neutral derived event type'
);
select ok(
  lower(
    pg_get_functiondef(
      'public.process_resource_saved_search_matching_outbox_batch(integer)'
        ::regprocedure
    )
  ) like '%for update of event skip locked%',
  'workers use non-blocking source-event row claims'
);
select ok(
  lower(
    pg_get_functiondef(
      'public.process_resource_saved_search_matching_outbox_batch(integer)'
        ::regprocedure
    )
  ) not like '%public.notifications%',
  'F3A does not create in-app notifications'
);
select ok(
  lower(
    pg_get_functiondef(
      'public.process_resource_saved_search_matching_outbox_batch(integer)'
        ::regprocedure
    )
  ) not like '%private.push_delivery_jobs%',
  'F3A does not create push jobs'
);
select ok(
  lower(
    pg_get_functiondef(
      'public.process_resource_saved_search_matching_outbox_batch(integer)'
        ::regprocedure
    )
  ) not like '%profile_notification_preferences%',
  'F3A does not consult notification preferences or frequency policy'
);

select is(
  (
    select count(*)
    from public.notification_categories
    where slug = 'matching'
  ),
  1::bigint,
  'the existing matching category remains available without F3A catalog changes'
);

select * from finish();

rollback;
