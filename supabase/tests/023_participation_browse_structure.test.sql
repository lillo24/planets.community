begin;

select no_plan();

select ok(
  to_regprocedure('public.list_own_pending_requested_proposals(uuid,text,uuid[])')
    is not null,
  'the requester-private Proposal card read exists'
);
select ok(
  to_regprocedure(
    'public.list_own_pending_requested_recurring_activities(uuid,timestamptz,text)'
  ) is not null,
  'the requester-private Tavolo card read exists'
);

select is(
  (
    select bool_and(procedure.prosecdef)
    from pg_proc as procedure
    where procedure.oid in (
      'public.list_own_pending_requested_proposals(uuid,text,uuid[])'::regprocedure,
      'public.list_own_pending_requested_recurring_activities(uuid,timestamptz,text)'::regprocedure
    )
  ),
  true,
  'personalized Browse reads are deliberate security-definer boundaries'
);
select is(
  (
    select bool_and(array_to_string(procedure.proconfig, ',') = 'search_path=""')
    from pg_proc as procedure
    where procedure.oid in (
      'public.list_own_pending_requested_proposals(uuid,text,uuid[])'::regprocedure,
      'public.list_own_pending_requested_recurring_activities(uuid,timestamptz,text)'::regprocedure
    )
  ),
  true,
  'personalized Browse security definers fix an empty search path'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.list_own_pending_requested_proposals(uuid,text,uuid[])',
    'EXECUTE'
  ),
  true,
  'authenticated clients can read their requested Proposal cards'
);
select is(
  has_function_privilege(
    'authenticated',
    'public.list_own_pending_requested_recurring_activities(uuid,timestamptz,text)',
    'EXECUTE'
  ),
  true,
  'authenticated clients can read their requested Tavolo cards'
);
select is(
  has_function_privilege(
    'anon',
    'public.list_own_pending_requested_proposals(uuid,text,uuid[])',
    'EXECUTE'
  ),
  false,
  'anonymous clients cannot execute personalized Proposal discovery'
);
select is(
  has_function_privilege(
    'anon',
    'public.list_own_pending_requested_recurring_activities(uuid,timestamptz,text)',
    'EXECUTE'
  ),
  false,
  'anonymous clients cannot execute personalized Tavolo discovery'
);
select is(
  has_function_privilege(
    'service_role',
    'public.list_own_pending_requested_proposals(uuid,text,uuid[])',
    'EXECUTE'
  ),
  false,
  'service-role clients do not receive the user-scoped Proposal read accidentally'
);
select is(
  has_function_privilege(
    'service_role',
    'public.list_own_pending_requested_recurring_activities(uuid,timestamptz,text)',
    'EXECUTE'
  ),
  false,
  'service-role clients do not receive the user-scoped Tavolo read accidentally'
);

select ok(
  to_regclass(
    'public.project_join_requests_requester_pending_created_at_idx'
  ) is not null,
  'pending requests have a requester-first projection index'
);
select is(
  (
    select lower(pg_get_expr(index_row.indpred, index_row.indrelid))
    from pg_index as index_row
    where index_row.indexrelid =
      'public.project_join_requests_requester_pending_created_at_idx'::regclass
  ),
  '(status = ''pending''::text)',
  'the projection index contains only current pending requests'
);
select ok(
  pg_get_indexdef(
    'public.project_join_requests_requester_pending_created_at_idx'::regclass
  ) ilike '%(requester_profile_id, created_at desc, project_id desc)%',
  'the projection index supports deterministic newest-request ordering'
);

select ok(
  to_regprocedure(
    'public.list_public_proposals(integer,timestamptz,uuid,text,uuid[])'
  ) is not null,
  'the existing anonymous Proposal page contract remains present'
);
select ok(
  to_regprocedure(
    'public.list_public_recurring_activities(timestamptz,integer,timestamptz,uuid,text)'
  ) is not null,
  'the existing anonymous Tavolo page contract remains present'
);

select ok(
  pg_get_function_result(
    'public.list_own_pending_requested_proposals(uuid,text,uuid[])'::regprocedure
  ) not ilike all (
    array['%description%', '%exact%', '%meeting%', '%creator%', '%request_message%']
  ),
  'the requested Proposal projection exposes only sanitized card fields'
);
select ok(
  pg_get_function_result(
    'public.list_own_pending_requested_recurring_activities(uuid,timestamptz,text)'::regprocedure
  ) not ilike all (
    array['%description%', '%exact%', '%meeting%', '%creator%', '%request_message%']
  ),
  'the requested Tavolo projection exposes only sanitized card and schedule fields'
);

select * from finish();

rollback;
