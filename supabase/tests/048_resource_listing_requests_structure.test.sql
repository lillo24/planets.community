begin;

select no_plan();

select has_table(
  'public',
  'resource_listing_requests',
  'canonical Scambio-Dona resource listing requests exist'
);

select columns_are(
  'public',
  'resource_listing_requests',
  array[
    'id',
    'listing_id',
    'requester_profile_id',
    'status',
    'request_message',
    'created_at',
    'resolved_at',
    'resolved_by_profile_id'
  ],
  'request rows contain only identities, lifecycle, private message, and timestamps'
);

select col_is_pk(
  'public',
  'resource_listing_requests',
  'id',
  'resource listing request IDs are primary keys'
);
select col_type_is(
  'public',
  'resource_listing_requests',
  'id',
  'uuid',
  'resource listing request IDs are UUIDs'
);
select col_type_is(
  'public',
  'resource_listing_requests',
  'created_at',
  'timestamp with time zone',
  'request creation time is timezone-aware'
);
select col_type_is(
  'public',
  'resource_listing_requests',
  'resolved_at',
  'timestamp with time zone',
  'request resolution time is timezone-aware'
);

select is(
  (
    select count(*)
    from pg_constraint as constraint_row
    where constraint_row.conrelid =
      'public.resource_listing_requests'::regclass
      and constraint_row.contype = 'f'
      and constraint_row.confdeltype = 'r'
      and constraint_row.conname in (
        'resource_listing_requests_listing_id_fkey',
        'resource_listing_requests_requester_profile_id_fkey',
        'resource_listing_requests_resolved_by_profile_id_fkey'
      )
  ),
  3::bigint,
  'listing, requester, and resolver use restrictive foreign keys'
);

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.resource_listing_requests'::regclass
      and conname = 'resource_listing_requests_status_valid'
      and contype = 'c'
      and pg_get_constraintdef(oid) like '%pending%'
      and pg_get_constraintdef(oid) like '%accepted%'
      and pg_get_constraintdef(oid) like '%rejected%'
      and pg_get_constraintdef(oid) like '%withdrawn%'
      and pg_get_constraintdef(oid) like '%listing_closed%'
  ),
  'request status is constrained to the exact five-state lifecycle'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.resource_listing_requests'::regclass
      and conname = 'resource_listing_requests_message_valid'
      and contype = 'c'
      and pg_get_constraintdef(oid) like '%btrim(request_message)%'
      and pg_get_constraintdef(oid) like '%char_length(request_message)%500%'
  ),
  'private request messages are canonical and bounded to 500 characters'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.resource_listing_requests'::regclass
      and conname = 'resource_listing_requests_resolution_valid'
      and contype = 'c'
  ),
  'pending and resolved request timestamps/actors are structurally consistent'
);

select ok(
  to_regclass(
    'public.resource_listing_requests_active_requester_listing_idx'
  ) is not null,
  'one-active-request hard invariant exists'
);
select is(
  (
    select index_row.indisunique
    from pg_index as index_row
    where index_row.indexrelid =
      'public.resource_listing_requests_active_requester_listing_idx'::regclass
  ),
  true,
  'the active requester/listing invariant is unique'
);
select ok(
  (
    select lower(pg_get_expr(index_row.indpred, index_row.indrelid))
      like '%status%pending%accepted%'
    from pg_index as index_row
    where index_row.indexrelid =
      'public.resource_listing_requests_active_requester_listing_idx'::regclass
  ),
  'active uniqueness applies only to pending and accepted requests'
);
select ok(
  to_regclass(
    'public.resource_listing_requests_requester_created_at_id_idx'
  ) is not null,
  'requester newest-first history is indexed'
);
select ok(
  to_regclass(
    'public.resource_listing_requests_listing_created_at_id_idx'
  ) is not null,
  'owner listing-request history and listing foreign-key lookup are indexed'
);
select ok(
  to_regclass(
    'public.resource_listing_requests_resolved_by_profile_id_idx'
  ) is not null,
  'resolution-actor foreign-key lookup is indexed'
);

select is(
  (
    select relrowsecurity
    from pg_class
    where oid = 'public.resource_listing_requests'::regclass
  ),
  true,
  'resource listing requests have RLS enabled'
);
select is(
  (
    select count(*)
    from pg_policies
    where schemaname = 'public'
      and tablename = 'resource_listing_requests'
  ),
  0::bigint,
  'resource listing requests expose no direct row policies'
);
select is(
  (
    select bool_or(
      has_table_privilege(
        role_name,
        'public.resource_listing_requests',
        privilege_name
      )
    )
    from unnest(array['anon', 'authenticated', 'service_role'])
      as roles(role_name)
    cross join unnest(array['SELECT', 'INSERT', 'UPDATE', 'DELETE'])
      as privileges(privilege_name)
  ),
  false,
  'client and service roles receive no direct request-table privileges'
);

select ok(
  to_regprocedure(
    'public.request_resource_listing(uuid,uuid,text)'
  ) is not null,
  'the resource request creation operation exists'
);
select ok(
  to_regprocedure(
    'public.withdraw_resource_listing_request(uuid,uuid)'
  ) is not null,
  'the requester withdrawal operation exists'
);
select ok(
  to_regprocedure(
    'public.accept_resource_listing_request(uuid,uuid)'
  ) is not null,
  'the owner acceptance operation exists'
);
select ok(
  to_regprocedure(
    'public.reject_resource_listing_request(uuid,uuid)'
  ) is not null,
  'the owner rejection operation exists'
);
select ok(
  to_regprocedure(
    'public.list_resource_listing_requests(uuid,uuid)'
  ) is not null,
  'the owner request-history read exists'
);
select ok(
  to_regprocedure(
    'public.list_own_resource_listing_requests(uuid)'
  ) is not null,
  'the requester history read exists'
);
select ok(
  to_regprocedure(
    'public.get_resource_listing_request(uuid,uuid)'
  ) is not null,
  'the request-specific authorized read exists'
);
select is(
  (
    select pronargdefaults
    from pg_proc
    where oid =
      'public.request_resource_listing(uuid,uuid,text)'::regprocedure
  ),
  1::smallint,
  'the private initial message defaults to null'
);

select is(
  (
    select bool_and(prosecdef)
      and bool_and(array_to_string(proconfig, ',') = 'search_path=""')
    from pg_proc
    where oid in (
      'public.request_resource_listing(uuid,uuid,text)'::regprocedure,
      'public.withdraw_resource_listing_request(uuid,uuid)'::regprocedure,
      'public.accept_resource_listing_request(uuid,uuid)'::regprocedure,
      'public.reject_resource_listing_request(uuid,uuid)'::regprocedure,
      'public.list_resource_listing_requests(uuid,uuid)'::regprocedure,
      'public.list_own_resource_listing_requests(uuid)'::regprocedure,
      'public.get_resource_listing_request(uuid,uuid)'::regprocedure,
      'public.list_public_resource_listings(integer,timestamptz,uuid,text,text,text)'::regprocedure,
      'public.get_public_resource_listing(uuid)'::regprocedure,
      'public.close_resource_listing(uuid,uuid)'::regprocedure
    )
  ),
  true,
  'all request and evolved listing boundaries are hardened security definers'
);

select is(
  (
    select bool_and(
      has_function_privilege('authenticated', procedure_oid, 'EXECUTE')
      and not has_function_privilege('anon', procedure_oid, 'EXECUTE')
      and not has_function_privilege('service_role', procedure_oid, 'EXECUTE')
    )
    from unnest(array[
      'public.request_resource_listing(uuid,uuid,text)'::regprocedure,
      'public.withdraw_resource_listing_request(uuid,uuid)'::regprocedure,
      'public.accept_resource_listing_request(uuid,uuid)'::regprocedure,
      'public.reject_resource_listing_request(uuid,uuid)'::regprocedure,
      'public.list_resource_listing_requests(uuid,uuid)'::regprocedure,
      'public.list_own_resource_listing_requests(uuid)'::regprocedure,
      'public.get_resource_listing_request(uuid,uuid)'::regprocedure
    ]) as procedures(procedure_oid)
  ),
  true,
  'only authenticated clients can execute private request APIs'
);
select is(
  (
    select bool_and(
      not has_function_privilege(role_name, procedure_oid, 'EXECUTE')
    )
    from unnest(array['anon', 'authenticated', 'service_role'])
      as roles(role_name)
    cross join unnest(array[
      'private.require_resource_listing_request_identity(uuid,boolean)'::regprocedure,
      'private.record_resource_listing_request_event(text,uuid,uuid,uuid,uuid,uuid)'::regprocedure
    ]) as procedures(procedure_oid)
  ),
  true,
  'request helpers are not directly executable by client or service roles'
);

select ok(
  (
    select 'active_request_count' = any(proargnames)
    from pg_proc
    where oid =
      'public.list_public_resource_listings(integer,timestamptz,uuid,text,text,text)'::regprocedure
  ),
  'public listing cards include only a derived active request count'
);
select ok(
  (
    select 'active_request_count' = any(proargnames)
    from pg_proc
    where oid = 'public.get_public_resource_listing(uuid)'::regprocedure
  ),
  'public listing detail includes only a derived active request count'
);
select ok(
  (
    select pg_get_functiondef(
      'public.close_resource_listing(uuid,uuid)'::regprocedure
    ) like '%status = ''listing_closed''%'
  ),
  'the canonical close operation terminally resolves pending requests'
);

select * from finish();

rollback;
