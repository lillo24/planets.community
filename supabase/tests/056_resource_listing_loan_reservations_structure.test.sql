begin;

select no_plan();

select ok(
  exists (
    select 1 from supabase_migrations.schema_migrations
    where version = '20260922090000'
  ),
  'forward reservation migration was applied'
);

select is(
  (
    select count(*) from pg_class
    where relname like '%loan_reservation%'
      and relkind in ('r', 'p')
  ),
  0::bigint,
  'reservation truth has no duplicate mutable ledger'
);

select ok(
  to_regprocedure('private.active_resource_listing_loan_reservations(uuid)')
    is not null
  and to_regprocedure(
    'private.resource_listing_loan_period_conflicts(uuid,uuid,timestamptz,timestamptz)'
  ) is not null
  and to_regprocedure(
    'private.resource_exchange_owner_lend_is_overdue(uuid,uuid,text,timestamptz,text,timestamptz)'
  ) is not null,
  'canonical active-set, half-open conflict, and overdue helpers exist'
);

select is(
  (
    select bool_and(prosecdef and array_to_string(proconfig, ',') =
      'search_path=""')
    from pg_proc
    where oid in (
      'private.active_resource_listing_loan_reservations(uuid)'::regprocedure,
      'private.resource_listing_loan_period_conflicts(uuid,uuid,timestamptz,timestamptz)'::regprocedure,
      'private.resource_exchange_owner_lend_is_overdue(uuid,uuid,text,timestamptz,text,timestamptz)'::regprocedure,
      'public.list_owned_resource_listing_loan_schedule(uuid,uuid)'::regprocedure,
      'public.check_resource_exchange_pending_loan_availability(uuid,uuid,uuid)'::regprocedure
    )
  ),
  true,
  'all new helper and RPC functions pin an empty search path'
);

select is(
  (select provolatile from pg_proc where oid =
    'private.resource_listing_loan_period_conflicts(uuid,uuid,timestamptz,timestamptz)'::regprocedure),
  'v'::"char",
  'post-lock conflict checks use a fresh volatile snapshot'
);

select is(
  (
    select bool_and(
      not has_function_privilege(role_name, procedure_oid, 'EXECUTE')
    )
    from unnest(array['anon', 'authenticated', 'service_role'])
      as roles(role_name)
    cross join unnest(array[
      'private.active_resource_listing_loan_reservations(uuid)'::regprocedure,
      'private.resource_listing_loan_period_conflicts(uuid,uuid,timestamptz,timestamptz)'::regprocedure,
      'private.resource_exchange_owner_lend_is_overdue(uuid,uuid,text,timestamptz,text,timestamptz)'::regprocedure
    ]) as procedures(procedure_oid)
  ),
  true,
  'private helpers cannot be executed by client or service roles'
);

select is(
  (
    select bool_and(
      has_function_privilege('authenticated', procedure_oid, 'EXECUTE')
      and not has_function_privilege('anon', procedure_oid, 'EXECUTE')
      and not has_function_privilege('service_role', procedure_oid, 'EXECUTE')
    )
    from unnest(array[
      'public.list_owned_resource_listing_loan_schedule(uuid,uuid)'::regprocedure,
      'public.check_resource_exchange_pending_loan_availability(uuid,uuid,uuid)'::regprocedure
    ]) as procedures(procedure_oid)
  ),
  true,
  'new public RPCs are authenticated-only'
);

select ok(
  lower(pg_get_functiondef(
    'public.accept_resource_exchange_terms(uuid,uuid,uuid)'::regprocedure
  )) like '%from public.resource_listings%for update%'
  and lower(pg_get_functiondef(
    'public.accept_resource_exchange_terms(uuid,uuid,uuid)'::regprocedure
  )) like '%resource_listing_loan_period_conflicts%'
  and lower(pg_get_functiondef(
    'public.accept_resource_exchange_terms(uuid,uuid,uuid)'::regprocedure
  )) like '%pt409%',
  'acceptance locks the listing and rejects conflicts before promotion'
);

select ok(
  lower(pg_get_functiondef(
    'public.cancel_resource_exchange_agreement(uuid,uuid)'::regprocedure
  )) like '%from public.resource_listings%for update%'
  and lower(pg_get_functiondef(
    'public.record_resource_exchange_milestone(uuid,uuid,uuid,text,text)'::regprocedure
  )) like '%from public.resource_listings%for update%',
  'cancellation and milestone closure share listing serialization'
);

select ok(
  pg_get_functiondef(
    'public.get_resource_exchange_agreement(uuid,uuid)'::regprocedure
  ) like '%resource_exchange_owner_lend_is_overdue%'
  and pg_get_functiondef(
    'public.list_owned_resource_listing_loan_schedule(uuid,uuid)'::regprocedure
  ) like '%resource_exchange_owner_lend_is_overdue%',
  'agreement and owner schedule share overdue semantics'
);

select ok(
  to_regclass('public.resource_listing_requests_listing_created_at_id_idx')
    is not null
  and to_regclass('public.resource_exchange_agreements_request_id_key')
    is not null
  and to_regclass('public.resource_exchange_agreement_terms_pkey')
    is not null
  and to_regclass('public.resource_exchange_agreement_events_milestone_key')
    is not null,
  'existing listing/request/terms/event indexes support active and overdue joins'
);

select is(
  (
    select count(*)
    from pg_proc
    where oid in (
      'public.accept_resource_exchange_terms(uuid,uuid,uuid)'::regprocedure,
      'private.resource_listing_loan_period_conflicts(uuid,uuid,timestamptz,timestamptz)'::regprocedure
    )
      and pg_get_functiondef(oid) like '%40001%'
  ),
  0::bigint,
  'reservation domain does not fabricate serialization SQLSTATE 40001'
);

select * from finish();
rollback;
