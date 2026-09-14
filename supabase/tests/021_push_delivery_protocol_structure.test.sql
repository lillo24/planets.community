begin;

select no_plan();

select has_table(
  'private',
  'push_delivery_targets',
  'private per-installation delivery targets exist'
);
select has_table(
  'private',
  'push_delivery_attempts',
  'private append-only delivery attempts exist'
);
select ok(
  to_regclass('public.push_delivery_targets') is null
    and to_regclass('public.push_delivery_attempts') is null,
  'delivery protocol tables remain outside the exposed public schema'
);

select columns_are(
  'private',
  'push_delivery_targets',
  array[
    'id',
    'job_id',
    'installation_id',
    'platform',
    'provider',
    'status',
    'available_at',
    'attempt_count',
    'lease_owner',
    'lease_id',
    'lease_expires_at',
    'created_at',
    'updated_at',
    'completed_at'
  ],
  'targets contain only snapshot identity, lifecycle, schedule, and lease state'
);
select columns_are(
  'private',
  'push_delivery_attempts',
  array[
    'id',
    'target_id',
    'attempt_number',
    'lease_id',
    'worker_id',
    'token_version',
    'started_at',
    'finished_at',
    'outcome',
    'provider_message_id',
    'provider_error_code',
    'retry_available_at'
  ],
  'attempts retain bounded provider facts without token or content copies'
);

select col_type_is(
  'private',
  'push_installations',
  'token_version',
  'bigint',
  'installation token generation is a durable bigint'
);
select col_not_null(
  'private',
  'push_installations',
  'token_version',
  'every installation has a token generation'
);
select col_type_is(
  'private',
  'push_delivery_jobs',
  'fanout_at',
  'timestamp with time zone',
  'job fan-out chronology is timezone-aware'
);
select col_type_is(
  'private',
  'push_delivery_targets',
  'lease_expires_at',
  'timestamp with time zone',
  'lease expiry is timezone-aware'
);

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'private.push_delivery_targets'::regclass
      and conname = 'push_delivery_targets_job_installation_unique'
      and contype = 'u'
  ),
  'one target per job and installation is enforced'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'private.push_delivery_attempts'::regclass
      and conname = 'push_delivery_attempts_target_attempt_unique'
      and contype = 'u'
  ),
  'attempt numbers are unique within a target'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'private.push_delivery_attempts'::regclass
      and conname = 'push_delivery_attempts_lease_unique'
      and contype = 'u'
  ),
  'one attempt owns each opaque lease identity'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'private.push_delivery_jobs'::regclass
      and conname = 'push_delivery_jobs_lifecycle_valid'
      and pg_get_constraintdef(oid) like '%delivered_or_terminal%'
      and pg_get_constraintdef(oid) like '%no_targets%'
  ),
  'job lifecycle accepts only the two aggregate completion reasons'
);

select ok(
  to_regclass('private.push_delivery_jobs_pending_fanout_idx') is not null,
  'unprepared jobs have a targeted partial queue index'
);
select ok(
  to_regclass('private.push_delivery_targets_job_id_idx') is not null
    and to_regclass('private.push_delivery_targets_installation_id_idx') is not null,
  'both target foreign-key paths are indexed'
);
select ok(
  to_regclass('private.push_delivery_targets_claimable_idx') is not null
    and to_regclass('private.push_delivery_targets_expiring_lease_idx') is not null,
  'pending and expiring target queue scans are indexed'
);
select ok(
  to_regclass('private.push_delivery_attempts_target_id_idx') is not null,
  'attempt history lookup and foreign-key operations are indexed'
);

select ok(
  to_regprocedure('private.prepare_push_delivery_jobs(integer)') is not null,
  'the trusted one-time fan-out routine exists'
);
select ok(
  to_regprocedure(
    'private.claim_push_delivery_targets(text,integer,integer)'
  ) is not null,
  'the trusted claim and lease routine exists'
);
select ok(
  to_regprocedure(
    'private.record_push_delivery_result(uuid,uuid,bigint,text,text,text,integer)'
  ) is not null,
  'the trusted result routine exists'
);
select ok(
  pg_get_function_result(
    'private.prepare_push_delivery_jobs(integer)'::regprocedure
  ) not ilike '%token%'
    and pg_get_function_result(
      'private.claim_push_delivery_targets(text,integer,integer)'::regprocedure
    ) ilike '%provider_token text%'
    and pg_get_function_result(
      'private.claim_push_delivery_targets(text,integer,integer)'::regprocedure
    ) ilike '%chat_id uuid%'
    and pg_get_function_result(
      'private.claim_push_delivery_targets(text,integer,integer)'::regprocedure
    ) ilike '%message_id uuid%'
    and pg_get_function_result(
      'private.record_push_delivery_result(uuid,uuid,bigint,text,text,text,integer)'::regprocedure
    ) = 'text',
  'only the trusted claim boundary can return provider-token material'
);
select ok(
  pg_get_functiondef(
    'private.prepare_push_delivery_jobs(integer)'::regprocedure
  ) ilike '%for update of job skip locked%'
    and pg_get_functiondef(
      'private.claim_push_delivery_targets(text,integer,integer)'::regprocedure
    ) ilike '%for update of target, installation skip locked%'
    and pg_get_functiondef(
      'private.claim_push_delivery_targets(text,integer,integer)'::regprocedure
    ) ilike '%push_delivery_attempts%'
    and pg_get_functiondef(
      'private.record_push_delivery_result(uuid,uuid,bigint,text,text,text,integer)'::regprocedure
    ) ilike '%attempt_record.token_version <> p_token_version%',
  'fan-out, claims, attempt creation, and stale-token rejection are encoded atomically'
);

select is(
  (
    select bool_and(procedure.prosecdef)
    from pg_proc as procedure
    where procedure.oid in (
      'private.complete_push_delivery_job_if_terminal(uuid)'::regprocedure,
      'private.prepare_push_delivery_jobs(integer)'::regprocedure,
      'private.claim_push_delivery_targets(text,integer,integer)'::regprocedure,
      'private.record_push_delivery_result(uuid,uuid,bigint,text,text,text,integer)'::regprocedure
    )
  ),
  true,
  'all delivery protocol routines are security definers'
);
select is(
  (
    select bool_and(array_to_string(procedure.proconfig, ',') = 'search_path=""')
    from pg_proc as procedure
    where procedure.oid in (
      'private.complete_push_delivery_job_if_terminal(uuid)'::regprocedure,
      'private.prepare_push_delivery_jobs(integer)'::regprocedure,
      'private.claim_push_delivery_targets(text,integer,integer)'::regprocedure,
      'private.record_push_delivery_result(uuid,uuid,bigint,text,text,text,integer)'::regprocedure
    )
  ),
  true,
  'all delivery protocol routines fix an empty search path'
);

select is(
  has_schema_privilege('service_role', 'private', 'USAGE'),
  true,
  'the trusted database role can resolve only explicitly granted private routines'
);
select is(
  has_schema_privilege('authenticated', 'private', 'USAGE'),
  false,
  'ordinary authenticated clients cannot resolve the private worker schema'
);
select is(
  has_function_privilege(
    'service_role',
    'private.prepare_push_delivery_jobs(integer)',
    'EXECUTE'
  )
    and has_function_privilege(
      'service_role',
      'private.claim_push_delivery_targets(text,integer,integer)',
      'EXECUTE'
    )
    and has_function_privilege(
      'service_role',
      'private.record_push_delivery_result(uuid,uuid,bigint,text,text,text,integer)',
      'EXECUTE'
    ),
  true,
  'service_role receives only the three worker protocol entrypoints'
);
select is(
  has_function_privilege(
    'service_role',
    'private.complete_push_delivery_job_if_terminal(uuid)',
    'EXECUTE'
  ),
  false,
  'service_role cannot invoke the internal aggregate-completion helper'
);
select is(
  has_function_privilege(
    'anon',
    'private.claim_push_delivery_targets(text,integer,integer)',
    'EXECUTE'
  )
    or has_function_privilege(
      'authenticated',
      'private.claim_push_delivery_targets(text,integer,integer)',
      'EXECUTE'
    ),
  false,
  'no ordinary client role can claim a provider token'
);

select is(
  has_table_privilege(
    'service_role',
    'private.push_delivery_targets',
    'SELECT,INSERT,UPDATE,DELETE'
  )
    or has_table_privilege(
      'service_role',
      'private.push_delivery_attempts',
      'SELECT,INSERT,UPDATE,DELETE'
    ),
  false,
  'service credentials have no direct delivery-protocol table access'
);
select is(
  has_table_privilege(
    'authenticated',
    'private.push_delivery_targets',
    'SELECT'
  )
    or has_table_privilege(
      'authenticated',
      'private.push_delivery_attempts',
      'SELECT'
    ),
  false,
  'ordinary clients cannot enumerate delivery state or attempt history'
);

select is(
  (
    select count(*)
    from information_schema.columns
    where table_schema in ('public', 'private')
      and table_name in (
        'push_delivery_jobs',
        'push_delivery_targets',
        'push_delivery_attempts'
      )
      and column_name in (
        'provider_token',
        'payload',
        'request_message',
        'body',
        'exact_meeting_text',
        'raw_response'
      )
  ),
  0::bigint,
  'jobs, targets, and attempts copy no token, raw payload, private message, exact location, or raw provider response'
);

select ok(
  (
    select relrowsecurity
    from pg_class
    where oid = 'private.push_delivery_targets'::regclass
  )
    and (
      select relrowsecurity
      from pg_class
      where oid = 'private.push_delivery_attempts'::regclass
    ),
  'private delivery tables enable RLS as defense in depth'
);

select * from finish();

rollback;
