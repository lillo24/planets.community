begin;

select no_plan();

select has_table(
  'public',
  'project_join_request_skill_acceptance_decisions',
  'skill acceptance decisions exist as durable history'
);
select has_table(
  'public',
  'project_join_request_resource_acceptance_decisions',
  'resource acceptance decisions exist as durable history'
);

select columns_are(
  'public',
  'project_join_request_skill_acceptance_decisions',
  array[
    'request_id',
    'skill_id',
    'disposition',
    'decided_at',
    'decided_by_profile_id'
  ],
  'skill decisions keep only immutable request-scoped triage facts'
);
select columns_are(
  'public',
  'project_join_request_resource_acceptance_decisions',
  array[
    'request_id',
    'resource_need_id',
    'disposition',
    'decided_at',
    'decided_by_profile_id'
  ],
  'resource decisions keep only immutable request-scoped triage facts'
);

select col_type_is(
  'public',
  'project_join_request_skill_acceptance_decisions',
  'decided_at',
  'timestamp with time zone',
  'skill decision time is timezone-aware'
);
select col_type_is(
  'public',
  'project_join_request_resource_acceptance_decisions',
  'decided_at',
  'timestamp with time zone',
  'resource decision time is timezone-aware'
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
      'public.project_join_request_skill_acceptance_decisions'::regclass
      and constraint_row.contype = 'p'
  ),
  array['request_id', 'skill_id']::name[],
  'skill decisions use the immutable selection identity as their primary key'
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
      'public.project_join_request_resource_acceptance_decisions'::regclass
      and constraint_row.contype = 'p'
  ),
  array['request_id', 'resource_need_id']::name[],
  'resource decisions use the immutable selection identity as their primary key'
);

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid =
      'public.project_join_request_skill_acceptance_decisions'::regclass
      and conname =
        'project_join_request_skill_acceptance_selection_fkey'
      and confrelid =
        'public.project_join_request_skill_selections'::regclass
      and contype = 'f'
  ),
  'skill decisions have a composite foreign key to request selections'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid =
      'public.project_join_request_resource_acceptance_decisions'::regclass
      and conname =
        'project_join_request_resource_acceptance_selection_fkey'
      and confrelid =
        'public.project_join_request_resource_selections'::regclass
      and contype = 'f'
  ),
  'resource decisions have a composite foreign key to request selections'
);
select is(
  (
    select count(*)
    from pg_constraint
    where conrelid in (
      'public.project_join_request_skill_acceptance_decisions'::regclass,
      'public.project_join_request_resource_acceptance_decisions'::regclass
    )
      and confrelid = 'public.profiles'::regclass
      and contype = 'f'
  ),
  2::bigint,
  'both decision kinds preserve the deciding creator profile'
);

select is(
  (
    select count(*)
    from pg_constraint
    where conrelid in (
      'public.project_join_request_skill_acceptance_decisions'::regclass,
      'public.project_join_request_resource_acceptance_decisions'::regclass
    )
      and contype = 'c'
      and pg_get_constraintdef(oid) like
        '%disposition = ANY (ARRAY[''needed''::text, ''already_found''::text, ''extra''::text])%'
  ),
  2::bigint,
  'both decision kinds allow exactly needed, already_found, and extra'
);

select is(
  (
    select bool_and(relrowsecurity)
    from pg_class
    where oid in (
      'public.project_join_request_skill_acceptance_decisions'::regclass,
      'public.project_join_request_resource_acceptance_decisions'::regclass
    )
  ),
  true,
  'both decision tables enable RLS'
);
select is(
  (
    select count(*)
    from pg_policies
    where schemaname = 'public'
      and tablename in (
        'project_join_request_skill_acceptance_decisions',
        'project_join_request_resource_acceptance_decisions'
      )
  ),
  0::bigint,
  'decision tables expose no client policies'
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
      ('public.project_join_request_skill_acceptance_decisions'::regclass),
      ('public.project_join_request_resource_acceptance_decisions'::regclass)
    ) as decision_table(table_oid)
    cross join (values
      ('SELECT'::text),
      ('INSERT'::text),
      ('UPDATE'::text),
      ('DELETE'::text)
    ) as privilege(privilege_name)
    where has_table_privilege(
      client.role_name,
      decision_table.table_oid,
      privilege.privilege_name
    )
  ),
  0::bigint,
  'decision tables have no direct client or service-role grants'
);

select ok(
  to_regprocedure(
    'public.accept_project_join_request(uuid,uuid,uuid[],uuid[],uuid[],uuid[],uuid[],uuid[])'
  ) is not null,
  'the required triaged acceptance overload exists'
);
select ok(
  to_regprocedure('public.accept_project_join_request(uuid,uuid)') is not null,
  'the zero-selection compatibility overload remains available'
);
select is(
  (
    select proargnames
    from pg_proc
    where oid =
      'public.accept_project_join_request(uuid,uuid,uuid[],uuid[],uuid[],uuid[],uuid[],uuid[])'::regprocedure
  ),
  array[
    'p_expected_creator_profile_id',
    'p_request_id',
    'p_needed_skill_ids',
    'p_already_found_skill_ids',
    'p_extra_skill_ids',
    'p_needed_resource_need_ids',
    'p_already_found_resource_need_ids',
    'p_extra_resource_need_ids'
  ]::text[],
  'triaged acceptance exposes unambiguous argument names'
);
select is(
  (
    select pronargdefaults
    from pg_proc
    where oid =
      'public.accept_project_join_request(uuid,uuid,uuid[],uuid[],uuid[],uuid[],uuid[],uuid[])'::regprocedure
  ),
  0::smallint,
  'triage arrays are required and have no defaults'
);
select is(
  (
    select bool_and(prosecdef)
    from pg_proc
    where oid in (
      'public.accept_project_join_request(uuid,uuid)'::regprocedure,
      'public.accept_project_join_request(uuid,uuid,uuid[],uuid[],uuid[],uuid[],uuid[],uuid[])'::regprocedure,
      'private.seed_project_membership_commitments()'::regprocedure
    )
  ),
  true,
  'acceptance and membership seeding use deliberate trusted boundaries'
);
select is(
  (
    select bool_and(array_to_string(proconfig, ',') = 'search_path=""')
    from pg_proc
    where oid in (
      'public.accept_project_join_request(uuid,uuid)'::regprocedure,
      'public.accept_project_join_request(uuid,uuid,uuid[],uuid[],uuid[],uuid[],uuid[],uuid[])'::regprocedure,
      'private.seed_project_membership_commitments()'::regprocedure
    )
  ),
  true,
  'all triage security definers fix an empty search path'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.accept_project_join_request(uuid,uuid,uuid[],uuid[],uuid[],uuid[],uuid[],uuid[])',
    'EXECUTE'
  ),
  true,
  'authenticated creators can execute triaged acceptance'
);
select is(
  (
    select count(*)
    from (values ('anon'::name), ('service_role'::name)) as client(role_name)
    where has_function_privilege(
      client.role_name,
      'public.accept_project_join_request(uuid,uuid,uuid[],uuid[],uuid[],uuid[],uuid[],uuid[])',
      'EXECUTE'
    )
  ),
  0::bigint,
  'triaged acceptance has no anonymous or service-role execute grant'
);

select is(
  (
    select count(*)
    from pg_trigger
    where tgrelid in (
      'public.project_join_request_skill_acceptance_decisions'::regclass,
      'public.project_join_request_resource_acceptance_decisions'::regclass
    )
      and tgname like '%_immutable'
      and not tgisinternal
  ),
  2::bigint,
  'both decision histories reject updates and deletes through immutable triggers'
);
select ok(
  position(
    'must be complete before membership creation' in lower(
      pg_get_functiondef(
        'private.seed_project_membership_commitments()'::regprocedure
      )
    )
  ) > 0,
  'membership seeding fails closed when acceptance decisions are incomplete'
);
select ok(
  position(
    'p_needed_skill_ids' in pg_get_functiondef(
      'public.accept_project_join_request(uuid,uuid,uuid[],uuid[],uuid[],uuid[],uuid[],uuid[])'::regprocedure
    )
  ) > 0
  and position(
    'exactly partition' in pg_get_functiondef(
      'public.accept_project_join_request(uuid,uuid,uuid[],uuid[],uuid[],uuid[],uuid[],uuid[])'::regprocedure
    )
  ) > 0,
  'triaged acceptance implements explicit exact-partition validation'
);

select * from finish();

rollback;
