begin;

-- Renumbered during stack integration to preserve globally unique pgTAP order.

select no_plan();

select ok(exists (
  select 1 from supabase_migrations.schema_migrations
  where version = '20260925112156'
), 'forward saved-search migration was applied');

select has_table(
  'public',
  'resource_saved_searches',
  'private personal Resource saved searches exist'
);

select columns_are(
  'public',
  'resource_saved_searches',
  array[
    'id',
    'profile_id',
    'query',
    'listing_mode',
    'locality',
    'created_at',
    'updated_at'
  ],
  'saved searches persist only owner, current browse filters, and timestamps'
);

select col_is_pk(
  'public', 'resource_saved_searches', 'id',
  'saved-search IDs are primary keys'
);
select col_type_is(
  'public', 'resource_saved_searches', 'id', 'uuid',
  'saved-search IDs are UUIDs'
);
select col_type_is(
  'public', 'resource_saved_searches', 'created_at',
  'timestamp with time zone',
  'saved-search creation time is timezone-aware'
);
select col_type_is(
  'public', 'resource_saved_searches', 'updated_at',
  'timestamp with time zone',
  'saved-search update time is timezone-aware'
);

select ok(exists (
  select 1
  from pg_constraint as constraint_row
  where constraint_row.conrelid = 'public.resource_saved_searches'::regclass
    and constraint_row.contype = 'f'
    and constraint_row.confrelid = 'public.profiles'::regclass
    and constraint_row.conname = 'resource_saved_searches_profile_id_fkey'
    and constraint_row.confdeltype = 'c'
), 'saved searches belong to one profile and follow its deletion');

select is((
  select count(*)
  from pg_constraint
  where conrelid = 'public.resource_saved_searches'::regclass
    and conname in (
      'resource_saved_searches_query_valid',
      'resource_saved_searches_listing_mode_valid',
      'resource_saved_searches_locality_valid',
      'resource_saved_searches_filter_present',
      'resource_saved_searches_timestamps_valid'
    )
    and contype = 'c'
), 5::bigint, 'canonical filters, non-empty meaning, and timestamps are constrained');

select ok(
  pg_get_constraintdef((
    select oid from pg_constraint
    where conrelid = 'public.resource_saved_searches'::regclass
      and conname = 'resource_saved_searches_listing_mode_valid'
  )) like '%donate%'
  and pg_get_constraintdef((
    select oid from pg_constraint
    where conrelid = 'public.resource_saved_searches'::regclass
      and conname = 'resource_saved_searches_listing_mode_valid'
  )) like '%exchange%',
  'saved listing mode is limited to Dona and Scambia'
);

select is((
  select relrowsecurity
  from pg_class
  where oid = 'public.resource_saved_searches'::regclass
), true, 'saved searches have RLS enabled');
select is((
  select count(*)
  from pg_policies
  where schemaname = 'public'
    and tablename = 'resource_saved_searches'
), 0::bigint, 'saved searches expose no direct row policies');
select is((
  select bool_or(has_table_privilege(
    role_name,
    'public.resource_saved_searches',
    privilege_name
  ))
  from unnest(array['anon', 'authenticated', 'service_role']) roles(role_name)
  cross join unnest(array['SELECT', 'INSERT', 'UPDATE', 'DELETE'])
    privileges(privilege_name)
), false, 'client and service roles have no direct saved-search table privilege');

select ok(
  to_regclass('public.resource_saved_searches_profile_filters_unique_idx')
    is not null
  and (
    select indexdef
    from pg_indexes
    where schemaname = 'public'
      and indexname = 'resource_saved_searches_profile_filters_unique_idx'
  ) like 'CREATE UNIQUE INDEX%lower(COALESCE(query, %COALESCE(listing_mode, %lower(COALESCE(locality, %',
  'semantic duplicate prevention is database-enforced per profile'
);
select ok(
  to_regclass('public.resource_saved_searches_profile_updated_at_id_idx')
    is not null,
  'profile ownership and descending update keyset have a supporting index'
);

select ok(exists (
  select 1
  from pg_trigger
  where tgrelid = 'public.resource_saved_searches'::regclass
    and tgname = 'resource_saved_searches_set_updated_at'
    and not tgisinternal
), 'saved searches have a canonical updated-at trigger');

select ok(
  to_regprocedure(
    'private.resource_listing_matches_saved_search_filters(text,text,text,text,text,text,text)'
  ) is not null,
  'the field-only browse-parity predicate exists'
);
select is((
  select provolatile
  from pg_proc
  where oid =
    'private.resource_listing_matches_saved_search_filters(text,text,text,text,text,text,text)'::regprocedure
), 'i', 'the field-only browse-parity predicate is immutable');

select ok(
  to_regprocedure(
    'public.create_resource_saved_search(uuid,text,text,text)'
  ) is not null
  and to_regprocedure(
    'public.update_resource_saved_search(uuid,uuid,text,text,text)'
  ) is not null
  and to_regprocedure(
    'public.delete_resource_saved_search(uuid,uuid)'
  ) is not null
  and to_regprocedure(
    'public.get_own_resource_saved_search(uuid,uuid)'
  ) is not null
  and to_regprocedure(
    'public.list_own_resource_saved_searches(uuid,integer,timestamptz,uuid)'
  ) is not null,
  'the complete saved-search CRUD and keyset RPC surface exists'
);

select is((
  select pg_get_function_result(
    'public.get_own_resource_saved_search(uuid,uuid)'::regprocedure
  )
), 'TABLE(saved_search_id uuid, query text, listing_mode text, locality text, created_at timestamp with time zone, updated_at timestamp with time zone)',
  'exact read returns only the private saved definition and timestamps'
);
select is((
  select pg_get_function_result(
    'public.list_own_resource_saved_searches(uuid,integer,timestamptz,uuid)'::regprocedure
  )
), 'TABLE(saved_search_id uuid, query text, listing_mode text, locality text, created_at timestamp with time zone, updated_at timestamp with time zone)',
  'list read returns only private saved definitions and timestamps'
);

select is((
  select bool_and(prosecdef and proconfig @> array['search_path=""'])
  from pg_proc
  where oid in (
    'private.set_resource_saved_search_updated_at()'::regprocedure,
    'private.resource_listing_matches_saved_search_filters(text,text,text,text,text,text,text)'::regprocedure,
    'public.create_resource_saved_search(uuid,text,text,text)'::regprocedure,
    'public.update_resource_saved_search(uuid,uuid,text,text,text)'::regprocedure,
    'public.delete_resource_saved_search(uuid,uuid)'::regprocedure,
    'public.get_own_resource_saved_search(uuid,uuid)'::regprocedure,
    'public.list_own_resource_saved_searches(uuid,integer,timestamptz,uuid)'::regprocedure
  )
), true, 'saved-search functions use hardened definer execution and empty search paths');

select is((
  select bool_and(not has_function_privilege(
    role_name, procedure_oid, 'EXECUTE'
  ))
  from unnest(array['anon', 'authenticated', 'service_role']) roles(role_name)
  cross join unnest(array[
    'private.set_resource_saved_search_updated_at()'::regprocedure,
    'private.resource_listing_matches_saved_search_filters(text,text,text,text,text,text,text)'::regprocedure
  ]) procedures(procedure_oid)
), true, 'private trigger and predicate helpers have no client execute grant');

select is((
  select bool_and(
    has_function_privilege('authenticated', procedure_oid, 'EXECUTE')
    and not has_function_privilege('anon', procedure_oid, 'EXECUTE')
    and not has_function_privilege('service_role', procedure_oid, 'EXECUTE')
  )
  from unnest(array[
    'public.create_resource_saved_search(uuid,text,text,text)'::regprocedure,
    'public.update_resource_saved_search(uuid,uuid,text,text,text)'::regprocedure,
    'public.delete_resource_saved_search(uuid,uuid)'::regprocedure,
    'public.get_own_resource_saved_search(uuid,uuid)'::regprocedure,
    'public.list_own_resource_saved_searches(uuid,integer,timestamptz,uuid)'::regprocedure
  ]) procedures(procedure_oid)
), true, 'public saved-search RPCs are authenticated-only');

select ok((
  select bool_and(
    pg_get_functiondef(procedure_oid) like
      '%private.require_resource_listing_identity%'
  )
  from unnest(array[
    'public.create_resource_saved_search(uuid,text,text,text)'::regprocedure,
    'public.update_resource_saved_search(uuid,uuid,text,text,text)'::regprocedure,
    'public.delete_resource_saved_search(uuid,uuid)'::regprocedure,
    'public.get_own_resource_saved_search(uuid,uuid)'::regprocedure,
    'public.list_own_resource_saved_searches(uuid,integer,timestamptz,uuid)'::regprocedure
  ]) procedures(procedure_oid)
), 'all public RPCs reuse the established authenticated Resource identity boundary');

select ok(
  pg_get_functiondef(
    'public.update_resource_saved_search(uuid,uuid,text,text,text)'::regprocedure
  ) ilike '%for update%'
  and pg_get_functiondef(
    'public.delete_resource_saved_search(uuid,uuid)'::regprocedure
  ) ilike '%for update%',
  'update and delete serialize on the saved-search row'
);

select ok(
  pg_get_functiondef(
    'public.create_resource_saved_search(uuid,text,text,text)'::regprocedure
  ) like '%PT409%'
  and pg_get_functiondef(
    'public.update_resource_saved_search(uuid,uuid,text,text,text)'::regprocedure
  ) like '%PT409%',
  'create and update map semantic uniqueness races to PT409'
);

select is((
  select count(*)
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'resource_saved_searches'
    and column_name in (
      'project_id',
      'resource_need_id',
      'resource_request_id',
      'resource_exchange_agreement_id',
      'loan_reservation_id',
      'notification_enabled',
      'notification_frequency',
      'display_name',
      'matched_listing_ids',
      'match_snapshot'
    )
), 0::bigint, 'saved definitions contain no Project, transaction, notification, name, or result state');

select is((
  select count(*)
  from pg_constraint
  where conrelid = 'public.resource_saved_searches'::regclass
    and contype = 'f'
    and confrelid <> 'public.profiles'::regclass
), 0::bigint, 'the domain has no Project or Scambio transaction foreign key');

select ok(
  pg_get_functiondef(
    'public.create_resource_saved_search(uuid,text,text,text)'::regprocedure
  ) not ilike '%outbox%'
  and pg_get_functiondef(
    'public.update_resource_saved_search(uuid,uuid,text,text,text)'::regprocedure
  ) not ilike '%outbox%'
  and pg_get_functiondef(
    'public.delete_resource_saved_search(uuid,uuid)'::regprocedure
  ) not ilike '%outbox%'
  and pg_get_functiondef(
    'public.create_resource_saved_search(uuid,text,text,text)'::regprocedure
  ) not ilike '%audit_events%',
  'saved-search CRUD emits no audit or outbox event'
);

select is(
  to_regprocedure('public.run_resource_saved_search(uuid,uuid)')::text,
  null,
  'F1 exposes no run-saved-search RPC'
);

select * from finish();
rollback;
