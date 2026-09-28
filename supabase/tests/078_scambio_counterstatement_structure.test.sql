begin;

select no_plan();

select has_table(
  'private',
  'moderation_counterstatements',
  'counterparty statements stay outside the Data API'
);

select is(
  (
    select class.relrowsecurity
    from pg_class as class
    join pg_namespace as namespace on namespace.oid = class.relnamespace
    where namespace.nspname = 'private'
      and class.relname = 'moderation_counterstatements'
  ),
  true,
  'the private counterstatement table enables RLS as defense in depth'
);

select is(
  (
    select bool_or(
      has_table_privilege(
        role_name,
        'private.moderation_counterstatements',
        privilege_name
      )
    )
    from unnest(array['anon', 'authenticated', 'service_role'])
      as roles(role_name)
    cross join unnest(array['SELECT', 'INSERT', 'UPDATE', 'DELETE'])
      as privileges(privilege_name)
  ),
  false,
  'API roles have no direct counterstatement-table privileges'
);

select ok(
  pg_get_constraintdef(
    (
      select candidate.oid
      from pg_constraint as candidate
      where candidate.conrelid =
        'private.moderation_evidence_requests'::regclass
        and candidate.conname =
          'moderation_evidence_requests_kind_valid'
    )
  ) like '%group_corroboration%'
  and pg_get_constraintdef(
    (
      select candidate.oid
      from pg_constraint as candidate
      where candidate.conrelid =
        'private.moderation_evidence_requests'::regclass
        and candidate.conname =
          'moderation_evidence_requests_kind_valid'
    )
  ) like '%resource_counterstatement%',
  'evidence requests support both explicit evidence kinds'
);

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'private.moderation_evidence_responses'::regclass
      and conname =
        'moderation_evidence_responses_request_recipient_kind_fkey'
  )
  and exists (
    select 1
    from pg_constraint
    where conrelid = 'private.moderation_counterstatements'::regclass
      and conname =
        'moderation_counterstatements_request_recipient_kind_fkey'
  ),
  'each response shape is bound to its matching request kind'
);

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'private.moderation_evidence_responses'::regclass
      and conname = 'moderation_evidence_responses_choice_valid'
      and pg_get_constraintdef(oid) like '%agree%disagree%unsure%'
  ),
  'group corroboration retains its exact choice semantics'
);

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'private.moderation_counterstatements'::regclass
      and conname = 'moderation_counterstatements_statement_valid'
      and pg_get_constraintdef(oid) like '%4000%'
  ),
  'counterstatements are canonically trimmed and bounded'
);

select ok(
  to_regprocedure(
    'public.list_own_moderation_evidence_requests(uuid,boolean,integer)'
  ) is not null,
  'the bounded discriminated recipient list operation exists'
);
select ok(
  to_regprocedure(
    'public.get_own_resource_counterstatement_request(uuid,uuid)'
  ) is not null,
  'the exact recipient-owned counterstatement detail operation exists'
);
select ok(
  to_regprocedure(
    'public.submit_resource_counterstatement(uuid,uuid,uuid,text)'
  ) is not null,
  'the final counterstatement operation exists'
);
select ok(
  to_regprocedure(
    'public.get_moderation_case_counterstatement(uuid,uuid)'
  ) is not null,
  'the staff counterstatement evidence operation exists'
);

select is(
  (
    select bool_and(
      procedure.prosecdef
      and array_to_string(procedure.proconfig, ',') = 'search_path=""'
    )
    from pg_proc as procedure
    where procedure.oid in (
      'public.list_own_moderation_evidence_requests(uuid,boolean,integer)'::regprocedure,
      'public.get_own_resource_counterstatement_request(uuid,uuid)'::regprocedure,
      'public.submit_resource_counterstatement(uuid,uuid,uuid,text)'::regprocedure,
      'public.get_moderation_case_counterstatement(uuid,uuid)'::regprocedure,
      'private.snapshot_resource_counterstatement_request()'::regprocedure
    )
  ),
  true,
  'every counterstatement authorization boundary is definer-owned with an empty search path'
);

select is(
  (
    select bool_and(
      has_function_privilege('authenticated', procedure.oid, 'EXECUTE')
      and not has_function_privilege('anon', procedure.oid, 'EXECUTE')
      and not has_function_privilege('service_role', procedure.oid, 'EXECUTE')
      and not exists (
        select 1
        from aclexplode(
          coalesce(procedure.proacl, acldefault('f', procedure.proowner))
        ) as acl
        where acl.grantee = 0
          and acl.privilege_type = 'EXECUTE'
      )
    )
    from pg_proc as procedure
    where procedure.oid in (
      'public.list_own_moderation_evidence_requests(uuid,boolean,integer)'::regprocedure,
      'public.get_own_resource_counterstatement_request(uuid,uuid)'::regprocedure,
      'public.submit_resource_counterstatement(uuid,uuid,uuid,text)'::regprocedure,
      'public.get_moderation_case_counterstatement(uuid,uuid)'::regprocedure
    )
  ),
  true,
  'only authenticated clients may call counterstatement RPCs'
);

select is(
  (
    select bool_or(
      has_function_privilege(role_name, procedure.oid, 'EXECUTE')
    )
    from pg_proc as procedure
    cross join unnest(array['anon', 'authenticated', 'service_role'])
      as roles(role_name)
    where procedure.oid =
      'private.snapshot_resource_counterstatement_request()'::regprocedure
  ),
  false,
  'the snapshot trigger helper is not client-callable'
);

select ok(
  pg_get_function_result(
    'public.list_own_moderation_evidence_requests(uuid,boolean,integer)'::regprocedure
  )::text not like '%reporter%'
  and pg_get_function_result(
    'public.get_own_resource_counterstatement_request(uuid,uuid)'::regprocedure
  )::text not like '%reporter%'
  and pg_get_function_result(
    'public.get_own_resource_counterstatement_request(uuid,uuid)'::regprocedure
  )::text not like '%reporter_profile_id%'
  and pg_get_function_result(
    'public.get_own_resource_counterstatement_request(uuid,uuid)'::regprocedure
  )::text not like '%recipient_profile_id%',
  'recipient projections expose no reporter identity or recipient identifiers'
);

select ok(
  exists (
    select 1
    from pg_trigger
    where tgrelid = 'private.moderation_reports'::regclass
      and tgname = 'moderation_reports_snapshot_resource_counterstatement'
      and not tgisinternal
  ),
  'qualifying report creation snapshots the counterstatement request in the same transaction'
);
select ok(
  exists (
    select 1
    from pg_trigger
    where tgrelid = 'private.moderation_counterstatements'::regclass
      and tgname = 'moderation_counterstatements_append_only'
      and not tgisinternal
  ),
  'counterstatements are append-preserved'
);

select * from finish();

rollback;
