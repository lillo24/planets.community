begin;

select no_plan();

select has_table(
  'public',
  'project_membership_actual_skill_overrides',
  'skill actual attribution stores only sparse membership-episode overrides'
);
select has_table(
  'public',
  'project_membership_actual_resource_overrides',
  'resource actual attribution stores only sparse membership-episode overrides'
);
select has_table(
  'public',
  'project_membership_actual_effort_markers',
  'Substantial Effort / Energy has a separate canonical marker'
);

select columns_are(
  'public',
  'project_membership_actual_skill_overrides',
  array[
    'membership_id',
    'skill_id',
    'is_included',
    'updated_at',
    'updated_by_profile_id'
  ],
  'skill overrides contain only IDs, sparse truth, and audit metadata'
);
select columns_are(
  'public',
  'project_membership_actual_resource_overrides',
  array[
    'membership_id',
    'resource_need_id',
    'is_included',
    'updated_at',
    'updated_by_profile_id'
  ],
  'resource overrides contain only IDs, sparse truth, and audit metadata'
);
select columns_are(
  'public',
  'project_membership_actual_effort_markers',
  array['membership_id', 'marked_at', 'marked_by_profile_id'],
  'effort is a separate membership marker with actor and server time'
);
select col_type_is(
  'public',
  'project_membership_actual_skill_overrides',
  'is_included',
  'boolean',
  'skill override truth is boolean'
);
select col_not_null(
  'public',
  'project_membership_actual_skill_overrides',
  'is_included',
  'skill override truth cannot be null'
);
select col_type_is(
  'public',
  'project_membership_actual_resource_overrides',
  'is_included',
  'boolean',
  'resource override truth is boolean'
);
select col_not_null(
  'public',
  'project_membership_actual_resource_overrides',
  'is_included',
  'resource override truth cannot be null'
);
select col_type_is(
  'public',
  'project_membership_actual_effort_markers',
  'marked_at',
  'timestamp with time zone',
  'effort marker time is timezone-aware'
);

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid =
      'public.project_membership_actual_skill_overrides'::regclass
      and contype = 'p'
      and pg_get_constraintdef(oid) =
        'PRIMARY KEY (membership_id, skill_id)'
  ),
  'skill overrides have one sparse row per membership and skill'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid =
      'public.project_membership_actual_resource_overrides'::regclass
      and contype = 'p'
      and pg_get_constraintdef(oid) =
        'PRIMARY KEY (membership_id, resource_need_id)'
  ),
  'resource overrides have one sparse row per membership and need'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid =
      'public.project_membership_actual_effort_markers'::regclass
      and contype = 'p'
      and pg_get_constraintdef(oid) = 'PRIMARY KEY (membership_id)'
  ),
  'effort has at most one marker per membership episode'
);
select is(
  (
    select count(*)
    from pg_constraint
    where conrelid in (
      'public.project_membership_actual_skill_overrides'::regclass,
      'public.project_membership_actual_resource_overrides'::regclass,
      'public.project_membership_actual_effort_markers'::regclass
    )
      and contype = 'f'
      and confdeltype = 'r'
  ),
  8::bigint,
  'membership, catalog/need, and actor foreign keys all restrict deletion'
);
select ok(
  to_regclass(
    'public.project_membership_actual_skill_overrides_skill_membership_idx'
  ) is not null,
  'the non-leading skill foreign key has a reverse index'
);
select ok(
  to_regclass(
    'public.project_membership_actual_resource_overrides_need_membership_idx'
  ) is not null,
  'the non-leading resource foreign key has a reverse index'
);
select ok(
  to_regclass(
    'public.project_membership_actual_skill_overrides_updated_by_idx'
  ) is not null
  and to_regclass(
    'public.project_membership_actual_resource_overrides_updated_by_idx'
  ) is not null
  and to_regclass(
    'public.project_membership_actual_effort_markers_marked_by_idx'
  ) is not null,
  'all actor-profile foreign keys are indexed'
);

select is(
  (
    select bool_and(relrowsecurity)
    from pg_class
    where oid in (
      'public.project_membership_actual_skill_overrides'::regclass,
      'public.project_membership_actual_resource_overrides'::regclass,
      'public.project_membership_actual_effort_markers'::regclass
    )
  ),
  true,
  'all actual-contribution storage tables have RLS enabled'
);
select is(
  (
    select count(*)
    from pg_policies
    where schemaname = 'public'
      and tablename in (
        'project_membership_actual_skill_overrides',
        'project_membership_actual_resource_overrides',
        'project_membership_actual_effort_markers'
      )
  ),
  0::bigint,
  'actual-contribution tables fail closed with no direct policies'
);
select is(
  (
    select bool_or(
      has_table_privilege(role_name, table_name, privilege_name)
    )
    from unnest(array['anon', 'authenticated', 'service_role'])
      as roles(role_name)
    cross join unnest(array[
      'public.project_membership_actual_skill_overrides',
      'public.project_membership_actual_resource_overrides',
      'public.project_membership_actual_effort_markers'
    ]) as tables(table_name)
    cross join unnest(array['SELECT', 'INSERT', 'UPDATE', 'DELETE'])
      as privileges(privilege_name)
  ),
  false,
  'client and service roles have no direct actual-contribution privileges'
);

select ok(
  to_regprocedure(
    'public.list_project_membership_actual_contributions(uuid,uuid)'
  ) is not null,
  'the participant-and-creator actual-contribution read exists'
);
select ok(
  to_regprocedure(
    'public.list_project_membership_actual_contribution_options(uuid,uuid)'
  ) is not null,
  'the creator-only correction-options read exists'
);
select ok(
  to_regprocedure(
    'public.replace_project_membership_actual_contributions(uuid,uuid,uuid[],uuid[],boolean,uuid[],uuid[],boolean)'
  ) is not null,
  'the creator-only compare-and-swap full-set replacement exists'
);
select ok(
  to_regprocedure(
    'public.replace_project_membership_actual_contributions(uuid,uuid,uuid[],uuid[],uuid[],uuid[])'
  ) is null,
  'no overload can omit expected or desired effort state'
);
select is(
  (
    select pronargdefaults
    from pg_proc
    where oid =
      'public.replace_project_membership_actual_contributions(uuid,uuid,uuid[],uuid[],boolean,uuid[],uuid[],boolean)'::regprocedure
  ),
  0::smallint,
  'all expected and desired replacement arguments are required'
);
select is(
  (
    select proargnames[1:8]
    from pg_proc
    where oid =
      'public.replace_project_membership_actual_contributions(uuid,uuid,uuid[],uuid[],boolean,uuid[],uuid[],boolean)'::regprocedure
  ),
  array[
    'p_expected_creator_profile_id',
    'p_membership_id',
    'p_expected_skill_ids',
    'p_expected_resource_need_ids',
    'p_expected_substantial_effort',
    'p_skill_ids',
    'p_resource_need_ids',
    'p_substantial_effort'
  ]::text[],
  'the CAS signature names expected and desired skill/resource/effort truth'
);
select is(
  pg_get_function_result(
    'public.list_project_membership_actual_contributions(uuid,uuid)'::regprocedure
  ),
  'TABLE(contribution_kind text, contribution_id uuid, label text, attribution_source text)'::text,
  'the read returns a strict normalized actual-contribution row set'
);
select is(
  pg_get_function_result(
    'public.list_project_membership_actual_contribution_options(uuid,uuid)'::regprocedure
  ),
  'TABLE(option_kind text, option_id uuid, label text)'::text,
  'the options read returns only canonical kind, ID, and label rows'
);

select is(
  (
    select bool_and(prosecdef)
    from pg_proc
    where oid in (
      'private.lock_project_for_actual_contribution_mutation(uuid)'::regprocedure,
      'private.record_project_actual_contributions_updated_event(uuid,uuid,uuid,uuid)'::regprocedure,
      'public.list_project_membership_actual_contributions(uuid,uuid)'::regprocedure,
      'public.list_project_membership_actual_contribution_options(uuid,uuid)'::regprocedure,
      'public.replace_project_membership_actual_contributions(uuid,uuid,uuid[],uuid[],boolean,uuid[],uuid[],boolean)'::regprocedure
    )
  ),
  true,
  'all actual-contribution trust boundaries deliberately use security definer'
);
select is(
  (
    select bool_and(array_to_string(proconfig, ',') = 'search_path=""')
    from pg_proc
    where oid in (
      'private.lock_project_for_actual_contribution_mutation(uuid)'::regprocedure,
      'private.record_project_actual_contributions_updated_event(uuid,uuid,uuid,uuid)'::regprocedure,
      'public.list_project_membership_actual_contributions(uuid,uuid)'::regprocedure,
      'public.list_project_membership_actual_contribution_options(uuid,uuid)'::regprocedure,
      'public.replace_project_membership_actual_contributions(uuid,uuid,uuid[],uuid[],boolean,uuid[],uuid[],boolean)'::regprocedure
    )
  ),
  true,
  'all actual-contribution trust boundaries pin an empty search path'
);
select is(
  (
    select bool_and(
      has_function_privilege('authenticated', function_name, 'EXECUTE')
    )
    from unnest(array[
      'public.list_project_membership_actual_contributions(uuid,uuid)',
      'public.list_project_membership_actual_contribution_options(uuid,uuid)',
      'public.replace_project_membership_actual_contributions(uuid,uuid,uuid[],uuid[],boolean,uuid[],uuid[],boolean)'
    ]) as functions(function_name)
  ),
  true,
  'authenticated clients can invoke only the guarded public APIs'
);
select is(
  (
    select bool_or(
      has_function_privilege(role_name, function_name, 'EXECUTE')
    )
    from unnest(array['anon', 'service_role']) as roles(role_name)
    cross join unnest(array[
      'public.list_project_membership_actual_contributions(uuid,uuid)',
      'public.list_project_membership_actual_contribution_options(uuid,uuid)',
      'public.replace_project_membership_actual_contributions(uuid,uuid,uuid[],uuid[],boolean,uuid[],uuid[],boolean)'
    ]) as functions(function_name)
  ),
  false,
  'anonymous and service roles receive no actual-contribution API grant'
);
select is(
  (
    select bool_or(
      has_function_privilege('authenticated', function_name, 'EXECUTE')
    )
    from unnest(array[
      'private.lock_project_for_actual_contribution_mutation(uuid)',
      'private.record_project_actual_contributions_updated_event(uuid,uuid,uuid,uuid)'
    ]) as functions(function_name)
  ),
  false,
  'authenticated clients cannot execute private actual-contribution helpers'
);

select ok(
  lower(pg_get_functiondef(
    'public.replace_project_membership_actual_contributions(uuid,uuid,uuid[],uuid[],boolean,uuid[],uuid[],boolean)'::regprocedure
  )) like '%raise sqlstate ''pt409''%',
  'stale actual-contribution snapshots use the explicit PostgREST conflict SQLSTATE'
);
select ok(
  lower(pg_get_functiondef(
    'public.replace_project_membership_actual_contributions(uuid,uuid,uuid[],uuid[],boolean,uuid[],uuid[],boolean)'::regprocedure
  )) like '%cardinality(normalized_skill_ids) > 50%',
  'desired actual skills are independently bounded at 50'
);
select ok(
  lower(pg_get_functiondef(
    'public.replace_project_membership_actual_contributions(uuid,uuid,uuid[],uuid[],boolean,uuid[],uuid[],boolean)'::regprocedure
  )) like '%cardinality(normalized_resource_need_ids) > 50%',
  'desired actual resources are independently bounded at 50'
);
select ok(
  lower(pg_get_functiondef(
    'private.record_project_actual_contributions_updated_event(uuid,uuid,uuid,uuid)'::regprocedure
  )) like '%project.actual_contributions_updated%',
  'real corrections use the dedicated update event'
);
select ok(
  lower(pg_get_functiondef(
    'private.record_project_actual_contributions_updated_event(uuid,uuid,uuid,uuid)'::regprocedure
  )) not like '%skill_ids%',
  'the update event contains no skill array'
);
select ok(
  lower(pg_get_functiondef(
    'private.record_project_actual_contributions_updated_event(uuid,uuid,uuid,uuid)'::regprocedure
  )) not like '%resource_need_ids%',
  'the update event contains no resource array'
);
select ok(
  lower(pg_get_functiondef(
    'private.record_project_actual_contributions_updated_event(uuid,uuid,uuid,uuid)'::regprocedure
  )) not like '%label%',
  'the update event contains no contribution label'
);
select ok(
  lower(pg_get_functiondef(
    'public.list_project_membership_actual_contributions(uuid,uuid)'::regprocedure
  )) not like '%project_membership_skill_coverages%',
  'effective actual attribution does not derive from skill coverage history'
);
select ok(
  lower(pg_get_functiondef(
    'public.list_project_membership_actual_contributions(uuid,uuid)'::regprocedure
  )) not like '%project_membership_resource_coverages%',
  'effective actual attribution does not derive from resource coverage history'
);
select ok(
  lower(pg_get_functiondef(
    'public.replace_project_membership_actual_contributions(uuid,uuid,uuid[],uuid[],boolean,uuid[],uuid[],boolean)'::regprocedure
  )) not like '%insert into public.skills%',
  'actual attribution never creates a fake skill catalog row'
);
select ok(
  lower(pg_get_functiondef(
    'public.replace_project_membership_actual_contributions(uuid,uuid,uuid[],uuid[],boolean,uuid[],uuid[],boolean)'::regprocedure
  )) not like '%insert into public.project_resource_needs%',
  'actual attribution never creates a fake Project resource need'
);
select ok(
  lower(pg_get_functiondef(
    'public.replace_project_membership_actual_contributions(uuid,uuid,uuid[],uuid[],boolean,uuid[],uuid[],boolean)'::regprocedure
  )) not like '%project_membership_skill_coverages%',
  'actual attribution mutation does not create skill coverage'
);
select ok(
  lower(pg_get_functiondef(
    'public.replace_project_membership_actual_contributions(uuid,uuid,uuid[],uuid[],boolean,uuid[],uuid[],boolean)'::regprocedure
  )) not like '%project_membership_resource_coverages%',
  'actual attribution mutation does not create resource coverage'
);

select is(
  (
    select count(*)
    from information_schema.tables
    where table_schema in ('public', 'private')
      and table_name in (
        'project_membership_actual_baselines',
        'project_actual_contribution_snapshots',
        'project_actual_contribution_reviews',
        'project_actual_contribution_disputes'
      )
  ),
  0::bigint,
  '05C1 adds no copied baseline, review, or dispute subsystem'
);
select * from finish();

rollback;
