begin;

select no_plan();

select has_table(
  'public',
  'project_membership_skill_commitments',
  'accepted membership episodes own mutable skill commitments'
);
select has_table(
  'public',
  'project_membership_resource_commitments',
  'accepted membership episodes own mutable resource commitments'
);

select columns_are(
  'public',
  'project_membership_skill_commitments',
  array['membership_id', 'skill_id', 'committed_at'],
  'skill commitments store only stable IDs and server commitment time'
);
select columns_are(
  'public',
  'project_membership_resource_commitments',
  array['membership_id', 'resource_need_id', 'committed_at'],
  'resource commitments store only stable IDs and server commitment time'
);
select col_type_is(
  'public',
  'project_membership_skill_commitments',
  'committed_at',
  'timestamp with time zone',
  'skill commitments use timezone-aware server time'
);
select col_type_is(
  'public',
  'project_membership_resource_commitments',
  'committed_at',
  'timestamp with time zone',
  'resource commitments use timezone-aware server time'
);

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid =
      'public.project_membership_skill_commitments'::regclass
      and contype = 'p'
      and pg_get_constraintdef(oid) =
        'PRIMARY KEY (membership_id, skill_id)'
  ),
  'one skill can be committed at most once per membership episode'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid =
      'public.project_membership_resource_commitments'::regclass
      and contype = 'p'
      and pg_get_constraintdef(oid) =
        'PRIMARY KEY (membership_id, resource_need_id)'
  ),
  'one resource need can be committed at most once per membership episode'
);

select is(
  (
    select count(*)
    from pg_constraint
    where conrelid in (
      'public.project_membership_skill_commitments'::regclass,
      'public.project_membership_resource_commitments'::regclass
    )
      and contype = 'f'
      and confdeltype = 'r'
  ),
  4::bigint,
  'all membership, skill, and resource foreign keys restrict deletion'
);
select ok(
  to_regclass(
    'public.project_membership_skill_commitments_skill_membership_idx'
  ) is not null,
  'the non-leading skill foreign key has a reverse index'
);
select ok(
  to_regclass(
    'public.project_membership_resource_commitments_need_membership_idx'
  ) is not null,
  'the non-leading resource foreign key has a reverse index'
);

select is(
  (
    select bool_and(relrowsecurity)
    from pg_class
    where oid in (
      'public.project_membership_skill_commitments'::regclass,
      'public.project_membership_resource_commitments'::regclass
    )
  ),
  true,
  'both commitment tables have RLS enabled'
);
select is(
  (
    select count(*)
    from pg_policies
    where schemaname = 'public'
      and tablename in (
        'project_membership_skill_commitments',
        'project_membership_resource_commitments'
      )
  ),
  0::bigint,
  'commitment tables fail closed with no direct policies'
);
select is(
  (
    select bool_or(
      has_table_privilege(role_name, table_name, privilege_name)
    )
    from unnest(array['anon', 'authenticated', 'service_role'])
      as roles(role_name)
    cross join unnest(array[
      'public.project_membership_skill_commitments',
      'public.project_membership_resource_commitments'
    ]) as tables(table_name)
    cross join unnest(array['SELECT', 'INSERT', 'UPDATE', 'DELETE'])
      as privileges(privilege_name)
  ),
  false,
  'client and service roles have no direct commitment-table privileges'
);

select ok(
  to_regprocedure(
    'public.replace_project_membership_commitments(uuid,uuid,uuid[],uuid[],uuid[],uuid[])'
  ) is not null,
  'the compare-and-swap full-set replacement RPC exists'
);
select ok(
  to_regprocedure(
    'public.replace_project_membership_commitments(uuid,uuid,uuid[],uuid[])'
  ) is null,
  'the unsafe four-argument replacement overload is absent'
);
select ok(
  to_regprocedure(
    'public.list_own_project_membership_commitments(uuid,uuid)'
  ) is not null,
  'the participant-and-creator authorized read RPC exists'
);
select ok(
  to_regprocedure(
    'public.list_own_project_membership_commitment_options(uuid,uuid)'
  ) is not null,
  'the current-membership addable-options RPC exists'
);
select is(
  (
    select pronargdefaults
    from pg_proc
    where oid =
      'public.replace_project_membership_commitments(uuid,uuid,uuid[],uuid[],uuid[],uuid[])'::regprocedure
  ),
  0::smallint,
  'expected and desired snapshots are all required explicitly'
);
select is(
  (
    select proargnames[1:6]
    from pg_proc
    where oid =
      'public.replace_project_membership_commitments(uuid,uuid,uuid[],uuid[],uuid[],uuid[])'::regprocedure
  ),
  array[
    'p_expected_actor_profile_id',
    'p_membership_id',
    'p_expected_skill_ids',
    'p_expected_resource_need_ids',
    'p_skill_ids',
    'p_resource_need_ids'
  ]::text[],
  'the replacement signature distinguishes expected and desired sets explicitly'
);
select is(
  (
    select pg_get_function_result(
      'public.list_own_project_membership_commitments(uuid,uuid)'::regprocedure
    )
  ),
  'TABLE(commitment_kind text, commitment_id uuid, label text)'::text,
  'the read returns only normalized kind, ID, and current label rows'
);
select is(
  (
    select pg_get_function_result(
      'public.list_own_project_membership_commitment_options(uuid,uuid)'::regprocedure
    )
  ),
  'TABLE(option_kind text, option_id uuid, label text)'::text,
  'the options read returns only normalized kind, ID, and current label rows'
);
select is(
  (
    select provolatile::text
    from pg_proc
    where oid =
      'public.list_own_project_membership_commitment_options(uuid,uuid)'::regprocedure
  ),
  's'::text,
  'the advisory options snapshot is stable and does not reserve options'
);

select is(
  (
    select bool_and(prosecdef)
    from pg_proc
    where oid in (
      'private.seed_project_membership_commitments()'::regprocedure,
      'private.lock_project_for_membership_commitment_mutation(uuid)'::regprocedure,
      'private.record_project_membership_commitment_event(uuid,uuid,text,uuid,uuid)'::regprocedure,
      'public.replace_project_membership_commitments(uuid,uuid,uuid[],uuid[],uuid[],uuid[])'::regprocedure,
      'public.list_own_project_membership_commitments(uuid,uuid)'::regprocedure,
      'public.list_own_project_membership_commitment_options(uuid,uuid)'::regprocedure
    )
  ),
  true,
  'all commitment trust boundaries deliberately use security definer'
);
select is(
  (
    select bool_and(array_to_string(proconfig, ',') = 'search_path=""')
    from pg_proc
    where oid in (
      'private.seed_project_membership_commitments()'::regprocedure,
      'private.lock_project_for_membership_commitment_mutation(uuid)'::regprocedure,
      'private.record_project_membership_commitment_event(uuid,uuid,text,uuid,uuid)'::regprocedure,
      'public.replace_project_membership_commitments(uuid,uuid,uuid[],uuid[],uuid[],uuid[])'::regprocedure,
      'public.list_own_project_membership_commitments(uuid,uuid)'::regprocedure,
      'public.list_own_project_membership_commitment_options(uuid,uuid)'::regprocedure
    )
  ),
  true,
  'all commitment trust boundaries pin an empty search path'
);
select is(
  has_function_privilege(
    'authenticated',
    'public.replace_project_membership_commitments(uuid,uuid,uuid[],uuid[],uuid[],uuid[])',
    'EXECUTE'
  ),
  true,
  'authenticated users can invoke the guarded replacement RPC'
);
select is(
  has_function_privilege(
    'authenticated',
    'public.list_own_project_membership_commitments(uuid,uuid)',
    'EXECUTE'
  ),
  true,
  'authenticated users can invoke the guarded read RPC'
);
select is(
  has_function_privilege(
    'authenticated',
    'public.list_own_project_membership_commitment_options(uuid,uuid)',
    'EXECUTE'
  ),
  true,
  'authenticated users can invoke the guarded addable-options RPC'
);
select is(
  (
    select bool_or(
      has_function_privilege(role_name, function_name, 'EXECUTE')
    )
    from unnest(array['anon', 'service_role']) as roles(role_name)
    cross join unnest(array[
      'public.replace_project_membership_commitments(uuid,uuid,uuid[],uuid[],uuid[],uuid[])',
      'public.list_own_project_membership_commitments(uuid,uuid)',
      'public.list_own_project_membership_commitment_options(uuid,uuid)'
    ]) as functions(function_name)
  ),
  false,
  'anonymous and service roles receive no commitment API grants'
);
select unlike(
  lower(
    pg_get_functiondef(
      'public.list_own_project_membership_commitment_options(uuid,uuid)'::regprocedure
    )
  ),
  '%audit_events%',
  'the advisory options read writes no audit event'
);
select unlike(
  lower(
    pg_get_functiondef(
      'public.list_own_project_membership_commitment_options(uuid,uuid)'::regprocedure
    )
  ),
  '%outbox_events%',
  'the advisory options read writes no outbox event'
);
select is(
  (
    select bool_or(
      has_function_privilege('authenticated', function_name, 'EXECUTE')
    )
    from unnest(array[
      'private.seed_project_membership_commitments()',
      'private.lock_project_for_membership_commitment_mutation(uuid)',
      'private.record_project_membership_commitment_event(uuid,uuid,text,uuid,uuid)'
    ]) as functions(function_name)
  ),
  false,
  'authenticated users cannot invoke private commitment helpers'
);

select ok(
  exists (
    select 1
    from pg_trigger
    where tgrelid = 'public.project_memberships'::regclass
      and tgname = 'project_memberships_seed_commitments'
      and not tgisinternal
      and (tgtype & 2) = 0
  ),
  'membership insertion has an AFTER trigger for atomic selection seeding'
);
select like(
  lower(
    pg_get_functiondef(
      'public.replace_project_membership_commitments(uuid,uuid,uuid[],uuid[],uuid[],uuid[])'::regprocedure
    )
  ),
  '%cardinality(normalized_skill_ids) > 50%',
  'skill commitment input is explicitly bounded at 50'
);
select like(
  lower(
    pg_get_functiondef(
      'public.replace_project_membership_commitments(uuid,uuid,uuid[],uuid[],uuid[],uuid[])'::regprocedure
    )
  ),
  '%cardinality(normalized_resource_need_ids) > 50%',
  'resource commitment input is explicitly bounded at 50'
);
select like(
  lower(
    pg_get_functiondef(
      'public.replace_project_membership_commitments(uuid,uuid,uuid[],uuid[],uuid[],uuid[])'::regprocedure
    )
  ),
  '%cardinality(normalized_expected_skill_ids) > 50%',
  'the expected skill snapshot is explicitly bounded at 50'
);
select like(
  lower(
    pg_get_functiondef(
      'public.replace_project_membership_commitments(uuid,uuid,uuid[],uuid[],uuid[],uuid[])'::regprocedure
    )
  ),
  '%cardinality(normalized_expected_resource_need_ids) > 50%',
  'the expected resource snapshot is explicitly bounded at 50'
);
select like(
  lower(
    pg_get_functiondef(
      'public.replace_project_membership_commitments(uuid,uuid,uuid[],uuid[],uuid[],uuid[])'::regprocedure
    )
  ),
  '%errcode = ''40001''%',
  'stale commitment snapshots use a stable serialization-conflict SQLSTATE'
);
select like(
  lower(
    pg_get_functiondef(
      'private.record_project_membership_commitment_event(uuid,uuid,text,uuid,uuid)'::regprocedure
    )
  ),
  '%project.membership_commitments_updated%',
  'real replacements use the dedicated audit/outbox event'
);
select unlike(
  lower(
    pg_get_functiondef(
      'private.record_project_membership_commitment_event(uuid,uuid,text,uuid,uuid)'::regprocedure
    )
  ),
  '%skill_ids%',
  'the event helper exposes no skill arrays'
);
select unlike(
  lower(
    pg_get_functiondef(
      'private.record_project_membership_commitment_event(uuid,uuid,text,uuid,uuid)'::regprocedure
    )
  ),
  '%resource_need_ids%',
  'the event helper exposes no resource arrays'
);
select unlike(
  lower(
    pg_get_functiondef(
      'private.record_project_membership_commitment_event(uuid,uuid,text,uuid,uuid)'::regprocedure
    )
  ),
  '%label%',
  'the event helper exposes no labels'
);
select unlike(
  lower(
    pg_get_functiondef(
      'private.record_project_membership_commitment_event(uuid,uuid,text,uuid,uuid)'::regprocedure
    )
  ),
  '%count%',
  'the event helper exposes no counts'
);

select is(
  (
    select count(*)
    from information_schema.columns
    where table_schema = 'public'
      and table_name in (
        'project_membership_skill_commitments',
        'project_membership_resource_commitments'
      )
      and column_name in (
        'label',
        'message',
        'quantity',
        'unit',
        'fulfilled_at',
        'delivered_at',
        'verified_at',
        'credited_at',
        'delegate_profile_id'
      )
  ),
  0::bigint,
  'commitments add no copied text, quantity, fulfillment, verification, credit, or delegate semantics'
);
select is(
  (
    select count(*)
    from information_schema.tables
    where table_schema = 'public'
      and table_name in (
        'project_contribution_fulfillments',
        'project_contribution_verifications',
        'project_commitment_delegates'
      )
  ),
  0::bigint,
  'C1 introduces no fulfillment, verification, or delegation subsystem'
);

select * from finish();

rollback;
