begin;

select no_plan();

select ok(exists (
  select 1 from supabase_migrations.schema_migrations
  where version = '20260922120000'
), 'forward matching migration was applied');

select ok(
  to_regprocedure('private.project_resource_match_or_query(text)') is not null
  and to_regprocedure('private.evaluate_project_resource_listing_match(text,text,text,text,text,text,text,text,text,text)') is not null
  and to_regprocedure('public.list_project_resource_need_listing_matches(uuid,uuid,text,integer,text,text,text,timestamptz,uuid)') is not null,
  'private lexical helpers and creator RPC exist'
);

select is((
  select bool_and(prosecdef and proconfig @> array['search_path=""'])
  from pg_proc
  where oid in (
    'private.project_resource_match_or_query(text)'::regprocedure,
    'private.evaluate_project_resource_listing_match(text,text,text,text,text,text,text,text,text,text)'::regprocedure,
    'public.list_project_resource_need_listing_matches(uuid,uuid,text,integer,text,text,text,timestamptz,uuid)'::regprocedure
  )
), true, 'new functions pin empty search paths and definer execution');

select is((
  select bool_and(not has_function_privilege(role_name, procedure_oid, 'EXECUTE'))
  from unnest(array['anon', 'authenticated', 'service_role']) roles(role_name)
  cross join unnest(array[
    'private.project_resource_match_or_query(text)'::regprocedure,
    'private.evaluate_project_resource_listing_match(text,text,text,text,text,text,text,text,text,text)'::regprocedure
  ]) procedures(procedure_oid)
), true, 'private matching helpers have no client execute grant');

select ok(
  has_function_privilege('authenticated',
    'public.list_project_resource_need_listing_matches(uuid,uuid,text,integer,text,text,text,timestamptz,uuid)', 'EXECUTE')
  and not has_function_privilege('anon',
    'public.list_project_resource_need_listing_matches(uuid,uuid,text,integer,text,text,text,timestamptz,uuid)', 'EXECUTE')
  and not has_function_privilege('service_role',
    'public.list_project_resource_need_listing_matches(uuid,uuid,text,integer,text,text,text,timestamptz,uuid)', 'EXECUTE'),
  'creator RPC is authenticated-only'
);

select is((
  select count(*) from pg_indexes
  where schemaname = 'public' and tablename = 'resource_listings'
    and indexname in (
      'resource_listings_published_title_italian_fts_idx',
      'resource_listings_published_description_italian_fts_idx'
    ) and indexdef like '%USING gin%'
      and indexdef like '%italian%'
      and indexdef like '%published%'
), 2::bigint, 'published title and description have Italian GIN indexes');

select is((
  select count(*) from pg_class
  where relname like '%project_resource_match%'
    and relkind in ('r', 'p', 'm')
), 0::bigint, 'Project resource matching persists no table or materialized view');

select ok(
  pg_get_functiondef(
    'public.list_project_resource_need_listing_matches(uuid,uuid,text,integer,text,text,text,timestamptz,uuid)'::regprocedure
  ) not ilike '%loan_reservation%'
  and pg_get_functiondef(
    'public.list_project_resource_need_listing_matches(uuid,uuid,text,integer,text,text,text,timestamptz,uuid)'::regprocedure
  ) not ilike '%resource_exchange_agreement%'
  and pg_get_functiondef(
    'public.list_project_resource_need_listing_matches(uuid,uuid,text,integer,text,text,text,timestamptz,uuid)'::regprocedure
  ) like '%public.get_public_resource_listing%',
  'matching cannot consult loan reservations and reuses the public listing projection'
);

select is((
  select pg_get_function_result(
    'public.list_project_resource_need_listing_matches(uuid,uuid,text,integer,text,text,text,timestamptz,uuid)'::regprocedure
  )
), 'TABLE(resource_need_id uuid, listing_id uuid, listing_mode text, title text, description text, country_code text, locality text, administrative_area text, public_location_label text, published_at timestamp with time zone, active_request_count bigint, text_match_kind text, location_match_kind text)',
  'RPC result includes public-safe listing fields and two reasons only');

select finish();
rollback;
