begin;

select no_plan();

select has_table(
  'private',
  'moderation_evidence_requests',
  'corroboration invitations stay outside the Data API'
);
select has_table(
  'private',
  'moderation_evidence_responses',
  'corroboration responses stay outside the Data API'
);

select is(
  (
    select bool_and(class.relrowsecurity)
    from pg_class as class
    join pg_namespace as namespace on namespace.oid = class.relnamespace
    where namespace.nspname = 'private'
      and class.relname in (
        'moderation_evidence_requests',
        'moderation_evidence_responses'
      )
  ),
  true,
  'private evidence tables enable RLS as defense in depth'
);

select is(
  (
    select bool_or(
      has_table_privilege(
        role_name,
        format('private.%I', class.relname),
        privilege_name
      )
    )
    from pg_class as class
    join pg_namespace as namespace on namespace.oid = class.relnamespace
    cross join unnest(array['anon', 'authenticated', 'service_role'])
      as roles(role_name)
    cross join unnest(array['SELECT', 'INSERT', 'UPDATE', 'DELETE'])
      as privileges(privilege_name)
    where namespace.nspname = 'private'
      and class.relname in (
        'moderation_evidence_requests',
        'moderation_evidence_responses'
      )
  ),
  false,
  'API roles have no direct evidence-table privileges'
);

select ok(
  to_regprocedure(
    'public.list_own_group_corroboration_requests(uuid,boolean,integer,timestamptz,uuid)'
  ) is not null,
  'the bounded recipient-owned list operation exists'
);
select ok(
  to_regprocedure(
    'public.get_own_group_corroboration_request(uuid,uuid)'
  ) is not null,
  'the exact recipient-owned detail operation exists'
);
select ok(
  to_regprocedure(
    'public.submit_group_corroboration_response(uuid,uuid,uuid,text,text)'
  ) is not null,
  'the final response operation exists'
);
select ok(
  to_regprocedure(
    'public.get_moderation_case_corroboration(uuid,uuid)'
  ) is not null,
  'the staff evidence operation exists'
);

select is(
  (
    select bool_and(
      procedure.prosecdef
      and array_to_string(procedure.proconfig, ',') = 'search_path=""'
    )
    from pg_proc as procedure
    where procedure.oid in (
      'public.list_own_group_corroboration_requests(uuid,boolean,integer,timestamptz,uuid)'::regprocedure,
      'public.get_own_group_corroboration_request(uuid,uuid)'::regprocedure,
      'public.submit_group_corroboration_response(uuid,uuid,uuid,text,text)'::regprocedure,
      'public.get_moderation_case_corroboration(uuid,uuid)'::regprocedure,
      'private.snapshot_group_corroboration_requests()'::regprocedure
    )
  ),
  true,
  'every corroboration authorization boundary is definer-owned with an empty search path'
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
      'public.list_own_group_corroboration_requests(uuid,boolean,integer,timestamptz,uuid)'::regprocedure,
      'public.get_own_group_corroboration_request(uuid,uuid)'::regprocedure,
      'public.submit_group_corroboration_response(uuid,uuid,uuid,text,text)'::regprocedure,
      'public.get_moderation_case_corroboration(uuid,uuid)'::regprocedure
    )
  ),
  true,
  'only authenticated clients may call corroboration RPCs'
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
      'private.snapshot_group_corroboration_requests()'::regprocedure
  ),
  false,
  'the snapshot trigger helper is not client-callable'
);

select ok(
  pg_get_function_result(
    'public.list_own_group_corroboration_requests(uuid,boolean,integer,timestamptz,uuid)'::regprocedure
  )::text not like '%reporter%'
  and pg_get_function_result(
    'public.list_own_group_corroboration_requests(uuid,boolean,integer,timestamptz,uuid)'::regprocedure
  )::text not like '%responder_profile_id%'
  and pg_get_function_result(
    'public.get_own_group_corroboration_request(uuid,uuid)'::regprocedure
  )::text not like '%reporter%'
  and pg_get_function_result(
    'public.get_own_group_corroboration_request(uuid,uuid)'::regprocedure
  )::text not like '%subject_profile_id%',
  'recipient projections cannot return reporter identity, subject IDs, peer identities, or aggregates'
);

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'private.moderation_evidence_requests'::regclass
      and conname = 'moderation_evidence_requests_case_kind_recipient_key'
  ),
  'one invitation exists per case, kind, and recipient'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'private.moderation_evidence_responses'::regclass
      and conname = 'moderation_evidence_responses_request_id_key'
  ),
  'one final response exists per invitation'
);
select ok(
  exists (
    select 1
    from pg_trigger
    where tgrelid = 'private.moderation_reports'::regclass
      and tgname = 'moderation_reports_snapshot_group_corroboration'
      and not tgisinternal
  ),
  'qualifying report creation snapshots the cohort in the same transaction'
);
select ok(
  exists (
    select 1
    from pg_trigger
    where tgrelid = 'private.moderation_evidence_requests'::regclass
      and tgname = 'moderation_evidence_requests_append_only'
      and not tgisinternal
  ) and exists (
    select 1
    from pg_trigger
    where tgrelid = 'private.moderation_evidence_responses'::regclass
      and tgname = 'moderation_evidence_responses_append_only'
      and not tgisinternal
  ),
  'invitations and responses are append-preserved'
);

select * from finish();

rollback;
