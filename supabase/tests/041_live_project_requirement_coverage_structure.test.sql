begin;

select no_plan();

select has_table(
  'public',
  'project_membership_skill_coverages',
  'participant skill coverage exists'
);
select has_table(
  'public',
  'project_membership_resource_coverages',
  'participant resource coverage exists'
);
select has_table(
  'public',
  'project_manual_skill_coverages',
  'manual skill coverage exists'
);
select has_table(
  'public',
  'project_manual_resource_coverages',
  'manual resource coverage exists'
);

select columns_are(
  'public',
  'project_membership_skill_coverages',
  array['membership_id', 'skill_id', 'covered_at'],
  'participant skill coverage stores only its source identity and time'
);
select columns_are(
  'public',
  'project_membership_resource_coverages',
  array['membership_id', 'resource_need_id', 'covered_at'],
  'participant resource coverage stores only its source identity and time'
);
select columns_are(
  'public',
  'project_manual_skill_coverages',
  array[
    'project_id',
    'skill_id',
    'marked_at',
    'marked_by_profile_id',
    'originating_request_id'
  ],
  'manual skill coverage preserves creator and optional request provenance'
);
select columns_are(
  'public',
  'project_manual_resource_coverages',
  array[
    'resource_need_id',
    'marked_at',
    'marked_by_profile_id',
    'originating_request_id'
  ],
  'manual resource coverage preserves creator and optional request provenance'
);

select is(
  (
    select array_agg(attribute.attname order by key_column.ordinality)
    from pg_constraint as constraint_row
    cross join lateral unnest(constraint_row.conkey)
      with ordinality as key_column(attnum, ordinality)
    join pg_attribute as attribute
      on attribute.attrelid = constraint_row.conrelid
      and attribute.attnum = key_column.attnum
    where constraint_row.conrelid =
      'public.project_membership_skill_coverages'::regclass
      and constraint_row.contype = 'p'
  ),
  array['membership_id', 'skill_id']::name[],
  'participant skill coverage has one source per membership and skill'
);
select is(
  (
    select array_agg(attribute.attname order by key_column.ordinality)
    from pg_constraint as constraint_row
    cross join lateral unnest(constraint_row.conkey)
      with ordinality as key_column(attnum, ordinality)
    join pg_attribute as attribute
      on attribute.attrelid = constraint_row.conrelid
      and attribute.attnum = key_column.attnum
    where constraint_row.conrelid =
      'public.project_membership_resource_coverages'::regclass
      and constraint_row.contype = 'p'
  ),
  array['membership_id', 'resource_need_id']::name[],
  'participant resource coverage has one source per membership and need'
);
select is(
  (
    select array_agg(attribute.attname order by key_column.ordinality)
    from pg_constraint as constraint_row
    cross join lateral unnest(constraint_row.conkey)
      with ordinality as key_column(attnum, ordinality)
    join pg_attribute as attribute
      on attribute.attrelid = constraint_row.conrelid
      and attribute.attnum = key_column.attnum
    where constraint_row.conrelid =
      'public.project_manual_skill_coverages'::regclass
      and constraint_row.contype = 'p'
  ),
  array['project_id', 'skill_id']::name[],
  'manual skill coverage has one current marker per Project skill'
);
select is(
  (
    select array_agg(attribute.attname order by key_column.ordinality)
    from pg_constraint as constraint_row
    cross join lateral unnest(constraint_row.conkey)
      with ordinality as key_column(attnum, ordinality)
    join pg_attribute as attribute
      on attribute.attrelid = constraint_row.conrelid
      and attribute.attnum = key_column.attnum
    where constraint_row.conrelid =
      'public.project_manual_resource_coverages'::regclass
      and constraint_row.contype = 'p'
  ),
  array['resource_need_id']::name[],
  'manual resource coverage has one current marker per stable need'
);

select is(
  (
    select count(*)
    from pg_constraint
    where conrelid in (
      'public.project_membership_skill_coverages'::regclass,
      'public.project_membership_resource_coverages'::regclass
    )
      and contype = 'f'
      and array_length(conkey, 1) = 2
      and confrelid in (
        'public.project_membership_skill_commitments'::regclass,
        'public.project_membership_resource_commitments'::regclass
      )
  ),
  2::bigint,
  'participant coverage requires its matching composite commitment identity'
);
select col_is_null(
  'public',
  'project_manual_skill_coverages',
  'originating_request_id',
  'manual skill coverage request provenance is optional'
);
select col_is_null(
  'public',
  'project_manual_resource_coverages',
  'originating_request_id',
  'manual resource coverage request provenance is optional'
);
select is(
  (
    select count(*)
    from pg_constraint
    where conrelid in (
      'public.project_manual_skill_coverages'::regclass,
      'public.project_manual_resource_coverages'::regclass
    )
      and confrelid = 'public.project_join_requests'::regclass
      and contype = 'f'
  ),
  2::bigint,
  'both manual marker kinds support restrictive request provenance'
);

select is(
  (
    select bool_and(relrowsecurity)
    from pg_class
    where oid in (
      'public.project_membership_skill_coverages'::regclass,
      'public.project_membership_resource_coverages'::regclass,
      'public.project_manual_skill_coverages'::regclass,
      'public.project_manual_resource_coverages'::regclass
    )
  ),
  true,
  'all coverage tables enable RLS'
);
select is(
  (
    select count(*)
    from pg_policies
    where schemaname = 'public'
      and tablename in (
        'project_membership_skill_coverages',
        'project_membership_resource_coverages',
        'project_manual_skill_coverages',
        'project_manual_resource_coverages'
      )
  ),
  0::bigint,
  'coverage tables expose no direct client policies'
);
select is(
  (
    select count(*)
    from (values
      ('anon'::name),
      ('authenticated'::name),
      ('service_role'::name)
    ) as client(role_name)
    cross join (values
      ('public.project_membership_skill_coverages'::regclass),
      ('public.project_membership_resource_coverages'::regclass),
      ('public.project_manual_skill_coverages'::regclass),
      ('public.project_manual_resource_coverages'::regclass)
    ) as coverage_table(table_oid)
    cross join (values
      ('SELECT'::text),
      ('INSERT'::text),
      ('UPDATE'::text),
      ('DELETE'::text)
    ) as privilege(privilege_name)
    where has_table_privilege(
      client.role_name,
      coverage_table.table_oid,
      privilege.privilege_name
    )
  ),
  0::bigint,
  'coverage tables have no direct client or service-role privileges'
);

select ok(
  to_regprocedure(
    'public.claim_project_requirement(uuid,uuid,text,uuid)'
  ) is not null,
  'participant claim RPC exists'
);
select ok(
  to_regprocedure(
    'public.set_project_requirement_manual_coverage(uuid,uuid,text,uuid,boolean)'
  ) is not null,
  'creator manual coverage RPC exists'
);
select ok(
  to_regprocedure(
    'public.list_project_live_requirement_coverage(uuid,uuid)'
  ) is not null,
  'authorized live coverage read exists'
);
select is(
  (
    select proargnames
    from pg_proc
    where oid =
      'public.claim_project_requirement(uuid,uuid,text,uuid)'::regprocedure
  ),
  array[
    'p_expected_participant_profile_id',
    'p_project_id',
    'p_requirement_kind',
    'p_requirement_id'
  ]::text[],
  'claim RPC has the expected identity-bound signature'
);
select is(
  (
    select proargnames
    from pg_proc
    where oid =
      'public.set_project_requirement_manual_coverage(uuid,uuid,text,uuid,boolean)'::regprocedure
  ),
  array[
    'p_expected_creator_profile_id',
    'p_project_id',
    'p_requirement_kind',
    'p_requirement_id',
    'p_is_covered'
  ]::text[],
  'manual coverage RPC has the expected identity-bound signature'
);
select is(
  (
    select proargnames
    from pg_proc
    where oid =
      'public.list_project_live_requirement_coverage(uuid,uuid)'::regprocedure
  ),
  array[
    'p_expected_profile_id',
    'p_project_id',
    'requirement_kind',
    'requirement_id',
    'label',
    'importance',
    'is_covered',
    'viewer_is_covering',
    'is_manually_covered'
  ]::text[],
  'coverage read exposes the normalized D3B handoff shape'
);

select is(
  (
    select bool_and(prosecdef)
    from pg_proc
    where oid in (
      'public.claim_project_requirement(uuid,uuid,text,uuid)'::regprocedure,
      'public.set_project_requirement_manual_coverage(uuid,uuid,text,uuid,boolean)'::regprocedure,
      'public.list_project_live_requirement_coverage(uuid,uuid)'::regprocedure,
      'private.record_project_requirement_coverage_event(text,uuid,uuid,text,text,uuid,uuid)'::regprocedure
    )
  ),
  true,
  'coverage RPCs and event helper use deliberate trusted boundaries'
);
select is(
  (
    select bool_and(array_to_string(proconfig, ',') = 'search_path=""')
    from pg_proc
    where oid in (
      'public.claim_project_requirement(uuid,uuid,text,uuid)'::regprocedure,
      'public.set_project_requirement_manual_coverage(uuid,uuid,text,uuid,boolean)'::regprocedure,
      'public.list_project_live_requirement_coverage(uuid,uuid)'::regprocedure,
      'private.record_project_requirement_coverage_event(text,uuid,uuid,text,text,uuid,uuid)'::regprocedure
    )
  ),
  true,
  'coverage security definers fix an empty search path'
);
select is(
  (
    select count(*)
    from (values
      ('public.claim_project_requirement(uuid,uuid,text,uuid)'::regprocedure),
      ('public.set_project_requirement_manual_coverage(uuid,uuid,text,uuid,boolean)'::regprocedure),
      ('public.list_project_live_requirement_coverage(uuid,uuid)'::regprocedure)
    ) as routine(oid)
    where has_function_privilege('authenticated', routine.oid, 'EXECUTE')
  ),
  3::bigint,
  'authenticated clients can call only the three public coverage contracts'
);
select is(
  (
    select count(*)
    from (values ('anon'::name), ('service_role'::name)) as client(role_name)
    cross join (values
      ('public.claim_project_requirement(uuid,uuid,text,uuid)'::regprocedure),
      ('public.set_project_requirement_manual_coverage(uuid,uuid,text,uuid,boolean)'::regprocedure),
      ('public.list_project_live_requirement_coverage(uuid,uuid)'::regprocedure)
    ) as routine(oid)
    where has_function_privilege(client.role_name, routine.oid, 'EXECUTE')
  ),
  0::bigint,
  'anonymous and service roles have no coverage RPC grant'
);
select is(
  (
    select count(*)
    from (values
      ('anon'::name),
      ('authenticated'::name),
      ('service_role'::name)
    ) as client(role_name)
    cross join (values
      ('private.project_requirement_live_source_count(uuid,text,uuid)'::regprocedure),
      ('private.record_project_requirement_coverage_event(text,uuid,uuid,text,text,uuid,uuid)'::regprocedure),
      ('private.initialize_project_membership_live_coverage()'::regprocedure)
    ) as helper(oid)
    where has_function_privilege(client.role_name, helper.oid, 'EXECUTE')
  ),
  0::bigint,
  'coverage helpers cannot be executed directly by client or service roles'
);

select ok(
  position(
    'project.requirement_covered' in pg_get_functiondef(
      'private.record_project_requirement_coverage_event(text,uuid,uuid,text,text,uuid,uuid)'::regprocedure
    )
  ) > 0
  and position(
    'project.requirement_needed_again' in pg_get_functiondef(
      'private.record_project_requirement_coverage_event(text,uuid,uuid,text,text,uuid,uuid)'::regprocedure
    )
  ) > 0,
  'the event helper permits only the two canonical coverage transitions'
);
select ok(
  position(
    'jsonb_strip_nulls' in pg_get_functiondef(
      'private.record_project_requirement_coverage_event(text,uuid,uuid,text,text,uuid,uuid)'::regprocedure
    )
  ) > 0
  and position(
    '''requirement_id''' in pg_get_functiondef(
      'private.record_project_requirement_coverage_event(text,uuid,uuid,text,text,uuid,uuid)'::regprocedure
    )
  ) > 0,
  'coverage events are assembled from identifiers only'
);
select is(
  (
    select count(*)
    from pg_trigger
    where tgname in (
      'project_memberships_z_initialize_live_coverage',
      'project_memberships_release_ended_coverage',
      'project_membership_skill_commitments_release_coverage',
      'project_membership_resource_commitments_release_coverage',
      'proposal_skills_lock_project_before_coverage_cleanup',
      'proposal_skills_clear_removed_live_coverage',
      'project_resource_needs_clear_closed_live_coverage'
    )
      and not tgisinternal
  ),
  7::bigint,
  'canonical acceptance, commitment, membership, and requirement lifecycles own cleanup triggers'
);

select * from finish();

rollback;
