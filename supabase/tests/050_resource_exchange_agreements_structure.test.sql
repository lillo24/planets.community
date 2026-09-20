begin;

select no_plan();

select has_table(
  'public',
  'resource_exchange_agreements',
  'resource exchange agreement anchors exist'
);
select has_table(
  'public',
  'resource_exchange_agreement_terms',
  'immutable resource exchange terms versions exist'
);
select has_table(
  'public',
  'resource_exchange_agreement_events',
  'structured resource exchange timeline events exist'
);

select columns_are(
  'public',
  'resource_exchange_agreements',
  array[
    'id',
    'request_id',
    'lifecycle_state',
    'current_terms_id',
    'pending_terms_id',
    'current_terms_accepted_at',
    'created_at',
    'cancelled_at',
    'cancelled_by_profile_id',
    'completed_at'
  ],
  'agreement anchors contain only lifecycle pointers, actors, and timestamps'
);
select columns_are(
  'public',
  'resource_exchange_agreement_terms',
  array[
    'id',
    'agreement_id',
    'version_number',
    'proposed_by_profile_id',
    'listing_title_snapshot',
    'listing_description_snapshot',
    'owner_transfer_kind',
    'owner_lend_starts_at',
    'owner_lend_ends_at',
    'requester_transfer_kind',
    'requester_resource_description',
    'requester_lend_starts_at',
    'requester_lend_ends_at',
    'private_note',
    'created_at'
  ],
  'terms versions contain the bounded two-leg snapshot model'
);
select columns_are(
  'public',
  'resource_exchange_agreement_events',
  array[
    'id',
    'agreement_id',
    'terms_id',
    'event_kind',
    'leg_kind',
    'actor_profile_id',
    'created_at'
  ],
  'timeline events contain structured identifiers and no arbitrary body'
);

select col_is_pk(
  'public',
  'resource_exchange_agreements',
  'id',
  'agreement IDs are primary keys'
);
select col_is_pk(
  'public',
  'resource_exchange_agreement_terms',
  'id',
  'terms IDs are primary keys'
);
select col_is_pk(
  'public',
  'resource_exchange_agreement_events',
  'id',
  'event IDs are primary keys'
);

select col_type_is(
  'public',
  'resource_exchange_agreements',
  'created_at',
  'timestamp with time zone',
  'agreement creation time is timezone-aware'
);
select col_type_is(
  'public',
  'resource_exchange_agreement_terms',
  'owner_lend_ends_at',
  'timestamp with time zone',
  'owner loan end time is timezone-aware'
);
select col_type_is(
  'public',
  'resource_exchange_agreement_events',
  'created_at',
  'timestamp with time zone',
  'timeline time is timezone-aware'
);

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.resource_exchange_agreements'::regclass
      and conname = 'resource_exchange_agreements_request_id_key'
      and contype = 'u'
  ),
  'one agreement per accepted request is structurally unique'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.resource_exchange_agreements'::regclass
      and conname = 'resource_exchange_agreements_lifecycle_state_valid'
      and pg_get_constraintdef(oid) like '%negotiating%'
      and pg_get_constraintdef(oid) like '%agreed%'
      and pg_get_constraintdef(oid) like '%in_progress%'
      and pg_get_constraintdef(oid) like '%completed%'
      and pg_get_constraintdef(oid) like '%cancelled%'
  ),
  'agreement lifecycle is constrained to the exact five states'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.resource_exchange_agreements'::regclass
      and conname = 'resource_exchange_agreements_lifecycle_shape_valid'
      and contype = 'c'
  ),
  'agreement pointers and terminal timestamps match lifecycle state'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.resource_exchange_agreement_terms'::regclass
      and conname = 'resource_exchange_agreement_terms_agreement_version_key'
      and contype = 'u'
  ),
  'terms version numbers are unique within an agreement'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.resource_exchange_agreement_terms'::regclass
      and conname = 'resource_exchange_agreement_terms_owner_shape_valid'
      and pg_get_constraintdef(oid) like '%owner_lend_ends_at > owner_lend_starts_at%'
  ),
  'owner give/lend shape and increasing bounded period are constrained'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.resource_exchange_agreement_terms'::regclass
      and conname = 'resource_exchange_agreement_terms_requester_shape_valid'
      and pg_get_constraintdef(oid) like '%requester_transfer_kind%none%'
      and pg_get_constraintdef(oid) like '%requester_transfer_kind%give%'
      and pg_get_constraintdef(oid) like '%requester_transfer_kind%lend%'
  ),
  'requester none/give/lend shapes are constrained'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.resource_exchange_agreement_terms'::regclass
      and conname = 'resource_exchange_agreement_terms_private_note_valid'
      and pg_get_constraintdef(oid) like '%1000%'
  ),
  'private terms notes are trimmed and bounded'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.resource_exchange_agreement_events'::regclass
      and conname = 'resource_exchange_agreement_events_shape_valid'
      and pg_get_constraintdef(oid) like '%resource_provided%'
      and pg_get_constraintdef(oid) like '%agreement_completed%'
  ),
  'agreement and resource timeline events have strict structured shape'
);

select ok(
  to_regclass('public.resource_exchange_agreement_events_milestone_key')
    is not null,
  'milestone uniqueness invariant exists'
);
select is(
  (
    select indisunique
    from pg_index
    where indexrelid =
      'public.resource_exchange_agreement_events_milestone_key'::regclass
  ),
  true,
  'milestone invariant is unique'
);
select ok(
  (
    select lower(pg_get_expr(indpred, indrelid))
      like '%resource_provided%resource_return_received%'
    from pg_index
    where indexrelid =
      'public.resource_exchange_agreement_events_milestone_key'::regclass
  ),
  'milestone uniqueness covers all four resource statement kinds'
);

select ok(
  'coordination_closed_at' = any(
    array(
      select column_name::text
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'resource_listing_requests'
    )
  ),
  'requests record agreement coordination closure separately from status'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.resource_listing_requests'::regclass
      and conname = 'resource_listing_requests_coordination_close_valid'
      and contype = 'c'
  ),
  'request coordination-close shape is constrained'
);
select ok(
  (
    select lower(pg_get_expr(indpred, indrelid))
      like '%coordination_closed_at is null%'
    from pg_index
    where indexrelid =
      'public.resource_listing_requests_active_requester_listing_idx'::regclass
  ),
  'active request uniqueness excludes coordination-closed accepted history'
);

select is(
  (
    select count(*)
    from pg_trigger
    where tgrelid in (
      'public.resource_exchange_agreement_terms'::regclass,
      'public.resource_exchange_agreement_events'::regclass
    )
      and not tgisinternal
      and tgname in (
        'resource_exchange_agreement_terms_immutable',
        'resource_exchange_agreement_events_immutable'
      )
  ),
  2::bigint,
  'terms and timeline rows have immutable update/delete guards'
);

select is(
  (
    select bool_and(relrowsecurity)
    from pg_class
    where oid in (
      'public.resource_exchange_agreements'::regclass,
      'public.resource_exchange_agreement_terms'::regclass,
      'public.resource_exchange_agreement_events'::regclass
    )
  ),
  true,
  'all agreement-domain tables have RLS enabled'
);
select is(
  (
    select count(*)
    from pg_policies
    where schemaname = 'public'
      and tablename in (
        'resource_exchange_agreements',
        'resource_exchange_agreement_terms',
        'resource_exchange_agreement_events'
      )
  ),
  0::bigint,
  'agreement-domain tables expose no direct row policies'
);
select is(
  (
    select bool_or(
      has_table_privilege(role_name, table_name, privilege_name)
    )
    from unnest(array['anon', 'authenticated', 'service_role'])
      as roles(role_name)
    cross join unnest(array[
      'public.resource_exchange_agreements',
      'public.resource_exchange_agreement_terms',
      'public.resource_exchange_agreement_events'
    ]) as tables(table_name)
    cross join unnest(array['SELECT', 'INSERT', 'UPDATE', 'DELETE'])
      as privileges(privilege_name)
  ),
  false,
  'client and service roles have no direct agreement-domain table access'
);

select ok(
  to_regprocedure(
    'public.propose_resource_exchange_terms(uuid,uuid,uuid,uuid,text,timestamptz,timestamptz,text,text,timestamptz,timestamptz,text)'
  ) is not null,
  'terms proposal CAS RPC exists'
);
select ok(
  to_regprocedure(
    'public.accept_resource_exchange_terms(uuid,uuid,uuid)'
  ) is not null,
  'terms acceptance RPC exists'
);
select ok(
  to_regprocedure(
    'public.reject_resource_exchange_terms(uuid,uuid,uuid)'
  ) is not null,
  'terms rejection RPC exists'
);
select ok(
  to_regprocedure(
    'public.withdraw_resource_exchange_terms(uuid,uuid,uuid)'
  ) is not null,
  'terms withdrawal RPC exists'
);
select ok(
  to_regprocedure(
    'public.record_resource_exchange_milestone(uuid,uuid,uuid,text,text)'
  ) is not null,
  'centralized milestone RPC exists'
);
select ok(
  to_regprocedure(
    'public.cancel_resource_exchange_agreement(uuid,uuid)'
  ) is not null,
  'agreement cancellation RPC exists'
);
select ok(
  to_regprocedure(
    'public.get_resource_exchange_agreement(uuid,uuid)'
  ) is not null,
  'counterparty agreement read exists'
);
select ok(
  to_regprocedure(
    'public.list_resource_exchange_agreement_terms(uuid,uuid)'
  ) is not null,
  'counterparty terms-history read exists'
);
select is(
  (
    select provolatile = 's'
      and prosecdef
      and proretset
      and array_to_string(proconfig, ',') = 'search_path=""'
    from pg_proc
    where oid =
      'public.list_resource_exchange_agreement_terms(uuid,uuid)'::regprocedure
  ),
  true,
  'terms-history projection remains stable, set-returning, and hardened'
);
select is(
  (
    select regexp_count(lower(pg_get_functiondef(oid)), 'coalesce[(]') = 2
      and lower(pg_get_functiondef(oid)) like
        '%coalesce(terms.id = agreement.current_terms_id, false)%'
      and lower(pg_get_functiondef(oid)) like
        '%coalesce(terms.id = agreement.pending_terms_id, false)%'
    from pg_proc
    where oid =
      'public.list_resource_exchange_agreement_terms(uuid,uuid)'::regprocedure
  ),
  true,
  'terms-history current and pending flags are explicitly non-null booleans'
);
select ok(
  to_regprocedure(
    'public.list_resource_exchange_agreement_events(uuid,uuid)'
  ) is not null,
  'counterparty timeline read exists'
);

select is(
  (
    select bool_and(prosecdef)
      and bool_and(array_to_string(proconfig, ',') = 'search_path=""')
    from pg_proc
    where oid in (
      'public.propose_resource_exchange_terms(uuid,uuid,uuid,uuid,text,timestamptz,timestamptz,text,text,timestamptz,timestamptz,text)'::regprocedure,
      'public.accept_resource_exchange_terms(uuid,uuid,uuid)'::regprocedure,
      'public.reject_resource_exchange_terms(uuid,uuid,uuid)'::regprocedure,
      'public.withdraw_resource_exchange_terms(uuid,uuid,uuid)'::regprocedure,
      'public.record_resource_exchange_milestone(uuid,uuid,uuid,text,text)'::regprocedure,
      'public.cancel_resource_exchange_agreement(uuid,uuid)'::regprocedure,
      'public.get_resource_exchange_agreement(uuid,uuid)'::regprocedure,
      'public.list_resource_exchange_agreement_terms(uuid,uuid)'::regprocedure,
      'public.list_resource_exchange_agreement_events(uuid,uuid)'::regprocedure,
      'public.accept_resource_listing_request(uuid,uuid)'::regprocedure,
      'public.request_resource_listing(uuid,uuid,text)'::regprocedure
    )
  ),
  true,
  'all evolved agreement/request boundaries are hardened security definers'
);
select is(
  (
    select bool_and(
      has_function_privilege('authenticated', procedure_oid, 'EXECUTE')
      and not has_function_privilege('anon', procedure_oid, 'EXECUTE')
      and not has_function_privilege('service_role', procedure_oid, 'EXECUTE')
    )
    from unnest(array[
      'public.propose_resource_exchange_terms(uuid,uuid,uuid,uuid,text,timestamptz,timestamptz,text,text,timestamptz,timestamptz,text)'::regprocedure,
      'public.accept_resource_exchange_terms(uuid,uuid,uuid)'::regprocedure,
      'public.reject_resource_exchange_terms(uuid,uuid,uuid)'::regprocedure,
      'public.withdraw_resource_exchange_terms(uuid,uuid,uuid)'::regprocedure,
      'public.record_resource_exchange_milestone(uuid,uuid,uuid,text,text)'::regprocedure,
      'public.cancel_resource_exchange_agreement(uuid,uuid)'::regprocedure,
      'public.get_resource_exchange_agreement(uuid,uuid)'::regprocedure,
      'public.list_resource_exchange_agreement_terms(uuid,uuid)'::regprocedure,
      'public.list_resource_exchange_agreement_events(uuid,uuid)'::regprocedure
    ]) as procedures(procedure_oid)
  ),
  true,
  'only authenticated clients can execute agreement APIs'
);
select is(
  (
    select bool_and(
      not has_function_privilege(role_name, procedure_oid, 'EXECUTE')
    )
    from unnest(array['anon', 'authenticated', 'service_role'])
      as roles(role_name)
    cross join unnest(array[
      'private.protect_resource_exchange_terms_immutability()'::regprocedure,
      'private.protect_resource_exchange_events_immutability()'::regprocedure,
      'private.record_resource_exchange_agreement_event(text,uuid,uuid,text,uuid,timestamptz)'::regprocedure,
      'private.ensure_resource_exchange_agreement_for_request(uuid,uuid,timestamptz)'::regprocedure
    ]) as procedures(procedure_oid)
  ),
  true,
  'agreement helpers are not client or service executable'
);

select ok(
  pg_get_functiondef(
    'public.accept_resource_listing_request(uuid,uuid)'::regprocedure
  ) like '%ensure_resource_exchange_agreement_for_request%',
  'request acceptance atomically ensures its agreement anchor'
);
select ok(
  pg_get_functiondef(
    'public.list_public_resource_listings(integer,timestamptz,uuid,text,text,text)'::regprocedure
  ) like '%coordination_closed_at is null%',
  'public active-interest count excludes coordination-closed acceptance'
);
select ok(
  pg_get_functiondef(
    'public.get_resource_exchange_agreement(uuid,uuid)'::regprocedure
  ) like '%resource_return_received%'
  and pg_get_functiondef(
    'public.get_resource_exchange_agreement(uuid,uuid)'::regprocedure
  ) like '%owner_lend_return_overdue%',
  'authorized agreement read derives both return-overdue indicators'
);

select * from finish();

rollback;
