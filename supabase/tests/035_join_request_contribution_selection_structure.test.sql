begin;

select no_plan();

select has_table(
  'public',
  'project_join_request_skill_selections',
  'join-request attempts have a historical skill-selection table'
);
select has_table(
  'public',
  'project_join_request_resource_selections',
  'join-request attempts have a historical resource-selection table'
);

select columns_are(
  'public',
  'project_join_request_skill_selections',
  array['request_id', 'skill_id', 'selected_at'],
  'skill selections persist only stable canonical IDs and selection time'
);
select columns_are(
  'public',
  'project_join_request_resource_selections',
  array['request_id', 'resource_need_id', 'selected_at'],
  'resource selections persist only stable canonical IDs and selection time'
);
select col_type_is(
  'public',
  'project_join_request_skill_selections',
  'selected_at',
  'timestamp with time zone',
  'skill-selection history uses a timezone-aware server timestamp'
);
select col_type_is(
  'public',
  'project_join_request_resource_selections',
  'selected_at',
  'timestamp with time zone',
  'resource-selection history uses a timezone-aware server timestamp'
);

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid =
      'public.project_join_request_skill_selections'::regclass
      and contype = 'p'
      and pg_get_constraintdef(oid) = 'PRIMARY KEY (request_id, skill_id)'
  ),
  'one skill can be selected at most once per request attempt'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid =
      'public.project_join_request_resource_selections'::regclass
      and contype = 'p'
      and pg_get_constraintdef(oid) =
        'PRIMARY KEY (request_id, resource_need_id)'
  ),
  'one resource need can be selected at most once per request attempt'
);

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid =
      'public.project_join_request_skill_selections'::regclass
      and confrelid = 'public.project_join_requests'::regclass
      and contype = 'f'
      and confdeltype = 'r'
  ),
  'skill history restrictively belongs to a join-request attempt'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid =
      'public.project_join_request_skill_selections'::regclass
      and confrelid = 'public.skills'::regclass
      and contype = 'f'
      and confdeltype = 'r'
  ),
  'skill selections retain canonical catalog identity'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid =
      'public.project_join_request_resource_selections'::regclass
      and confrelid = 'public.project_join_requests'::regclass
      and contype = 'f'
      and confdeltype = 'r'
  ),
  'resource history restrictively belongs to a join-request attempt'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid =
      'public.project_join_request_resource_selections'::regclass
      and confrelid = 'public.project_resource_needs'::regclass
      and contype = 'f'
      and confdeltype = 'r'
  ),
  'resource selections retain canonical need identity'
);

select ok(
  to_regclass(
    'public.project_join_request_skill_selections_skill_request_idx'
  ) is not null,
  'the non-leading skill foreign key has a supporting reverse index'
);
select ok(
  to_regclass(
    'public.project_join_request_resource_selections_need_request_idx'
  ) is not null,
  'the non-leading resource foreign key has a supporting reverse index'
);

select is(
  (
    select bool_and(relrowsecurity)
    from pg_class
    where oid in (
      'public.project_join_request_skill_selections'::regclass,
      'public.project_join_request_resource_selections'::regclass
    )
  ),
  true,
  'both private selection tables have RLS enabled'
);
select is(
  (
    select count(*)
    from pg_policies
    where schemaname = 'public'
      and tablename in (
        'project_join_request_skill_selections',
        'project_join_request_resource_selections'
      )
  ),
  0::bigint,
  'selection tables are fail-closed with no direct row policies'
);
select is(
  (
    select bool_or(
      has_table_privilege(role_name, table_name, privilege_name)
    )
    from unnest(array['anon', 'authenticated', 'service_role'])
      as roles(role_name)
    cross join unnest(array[
      'public.project_join_request_skill_selections',
      'public.project_join_request_resource_selections'
    ]) as tables(table_name)
    cross join unnest(array['SELECT', 'INSERT', 'UPDATE', 'DELETE'])
      as privileges(privilege_name)
  ),
  false,
  'client and service roles receive no direct selection-table privileges'
);

select ok(
  to_regprocedure(
    'public.request_to_join_project(uuid,uuid,text,uuid[],uuid[])'
  ) is not null,
  'the request mutation has one optional-selection signature'
);
select ok(
  to_regprocedure('public.request_to_join_project(uuid,uuid,text)') is null,
  'the old exact signature is removed so defaults cannot create ambiguity'
);
select is(
  (
    select pronargdefaults
    from pg_proc
    where oid =
      'public.request_to_join_project(uuid,uuid,text,uuid[],uuid[])'::regprocedure
  ),
  3::smallint,
  'message, skill IDs, and resource IDs are trailing optional arguments'
);
select ok(
  to_regprocedure(
    'public.list_own_project_join_request_contribution_selections(uuid,uuid)'
  ) is not null,
  'the requester-and-creator authorized contribution read exists'
);

select is(
  (
    select bool_and(prosecdef)
    from pg_proc
    where oid in (
      'public.request_to_join_project(uuid,uuid,text,uuid[],uuid[])'::regprocedure,
      'public.list_own_project_join_request_contribution_selections(uuid,uuid)'::regprocedure
    )
  ),
  true,
  'selection mutation and read use deliberate security-definer boundaries'
);
select is(
  (
    select bool_and(array_to_string(proconfig, ',') = 'search_path=""')
    from pg_proc
    where oid in (
      'public.request_to_join_project(uuid,uuid,text,uuid[],uuid[])'::regprocedure,
      'public.list_own_project_join_request_contribution_selections(uuid,uuid)'::regprocedure
    )
  ),
  true,
  'selection mutation and read fix an empty search path'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.request_to_join_project(uuid,uuid,text,uuid[],uuid[])',
    'EXECUTE'
  ),
  true,
  'authenticated users can create contribution-aware requests'
);
select is(
  has_function_privilege(
    'authenticated',
    'public.list_own_project_join_request_contribution_selections(uuid,uuid)',
    'EXECUTE'
  ),
  true,
  'authenticated requesters and creators can invoke the private read'
);
select is(
  (
    select bool_or(
      has_function_privilege(
        role_name,
        function_name,
        'EXECUTE'
      )
    )
    from unnest(array['anon', 'service_role']) as roles(role_name)
    cross join unnest(array[
      'public.request_to_join_project(uuid,uuid,text,uuid[],uuid[])',
      'public.list_own_project_join_request_contribution_selections(uuid,uuid)'
    ]) as functions(function_name)
  ),
  false,
  'anonymous and service roles receive no selection API grants'
);

select unlike(
  lower(
    pg_get_functiondef(
      'public.request_to_join_project(uuid,uuid,text,uuid[],uuid[])'::regprocedure
    )
  ),
  '%''skill_ids''%',
  'the unchanged join-request event has no skill-array payload key'
);
select unlike(
  lower(
    pg_get_functiondef(
      'public.request_to_join_project(uuid,uuid,text,uuid[],uuid[])'::regprocedure
    )
  ),
  '%''resource_need_ids''%',
  'the unchanged join-request event has no resource-array payload key'
);
select unlike(
  lower(
    pg_get_functiondef(
      'public.request_to_join_project(uuid,uuid,text,uuid[],uuid[])'::regprocedure
    )
  ),
  '%''request_message''%',
  'the unchanged join-request event has no request-message payload key'
);

select is(
  (
    select count(*)
    from information_schema.columns
    where table_schema = 'public'
      and table_name in (
        'project_join_request_skill_selections',
        'project_join_request_resource_selections'
      )
      and column_name in (
        'label',
        'message',
        'quantity',
        'unit',
        'price',
        'currency',
        'accepted_at',
        'fulfilled_at',
        'resource_listing_id'
      )
  ),
  0::bigint,
  'historical selections add no copied labels, text, quantities, prices, fulfillment, or listing links'
);
select is(
  (
    select count(*)
    from information_schema.tables
    where table_schema = 'public'
      and table_name in (
        'project_contribution_commitments',
        'project_member_contributions',
        'project_contribution_offers'
      )
  ),
  0::bigint,
  '04C3B1 adds no mutable accepted commitments or unsolicited offers'
);

select * from finish();

rollback;
