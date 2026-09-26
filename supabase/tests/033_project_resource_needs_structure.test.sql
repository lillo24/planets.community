begin;

select no_plan();

select has_table(
  'public',
  'project_resource_needs',
  'the shared Project resource-need table exists'
);

select columns_are(
  'public',
  'project_resource_needs',
  array[
    'id',
    'project_id',
    'title',
    'details',
    'state',
    'created_at',
    'updated_at',
    'closed_at'
  ],
  'needs contain only stable Project identity, plain text, lifecycle, and timestamps'
);

select col_is_pk(
  'public',
  'project_resource_needs',
  'id',
  'resource-need IDs are primary keys'
);
select col_type_is(
  'public',
  'project_resource_needs',
  'id',
  'uuid',
  'resource-need IDs are UUIDs'
);
select col_type_is(
  'public',
  'project_resource_needs',
  'created_at',
  'timestamp with time zone',
  'resource-need creation time is timezone-aware'
);
select col_type_is(
  'public',
  'project_resource_needs',
  'updated_at',
  'timestamp with time zone',
  'resource-need update time is timezone-aware'
);
select col_type_is(
  'public',
  'project_resource_needs',
  'closed_at',
  'timestamp with time zone',
  'resource-need closure time is timezone-aware'
);

select ok(
  exists (
    select 1
    from pg_constraint as constraint_row
    where constraint_row.conrelid = 'public.project_resource_needs'::regclass
      and constraint_row.contype = 'f'
      and constraint_row.confrelid = 'public.projects'::regclass
      and constraint_row.conname = 'project_resource_needs_project_id_fkey'
      and constraint_row.confdeltype = 'r'
  ),
  'every need belongs restrictively to the shared Project identity'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.project_resource_needs'::regclass
      and conname = 'project_resource_needs_state_valid'
      and contype = 'c'
      and pg_get_constraintdef(oid) like '%open%'
      and pg_get_constraintdef(oid) like '%closed%'
      and pg_get_constraintdef(oid) not like '%fulfilled%'
  ),
  'need state is constrained to open and closed without fulfillment semantics'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.project_resource_needs'::regclass
      and conname = 'project_resource_needs_title_valid'
      and contype = 'c'
      and pg_get_constraintdef(oid) like '%char_length(title)%2%160%'
  ),
  'need titles are trimmed and bounded to 2 through 160 characters'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.project_resource_needs'::regclass
      and conname = 'project_resource_needs_details_valid'
      and contype = 'c'
      and pg_get_constraintdef(oid) like '%char_length(details)%1%1000%'
  ),
  'optional details are trimmed and bounded to 1 through 1000 characters'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.project_resource_needs'::regclass
      and conname = 'project_resource_needs_timestamps_valid'
      and contype = 'c'
  ),
  'state and timestamps have one canonical consistency constraint'
);

select is(
  (
    select relrowsecurity
    from pg_class
    where oid = 'public.project_resource_needs'::regclass
  ),
  true,
  'resource needs have RLS enabled'
);
select is(
  (
    select count(*)
    from pg_policies
    where schemaname = 'public'
      and tablename = 'project_resource_needs'
  ),
  0::bigint,
  'resource needs expose no direct row policies'
);
select is(
  (
    select bool_or(
      has_table_privilege(
        role_name,
        'public.project_resource_needs',
        privilege_name
      )
    )
    from unnest(array['anon', 'authenticated', 'service_role']) as roles(role_name)
    cross join unnest(array['SELECT', 'INSERT', 'UPDATE', 'DELETE']) as privileges(privilege_name)
  ),
  false,
  'client and service roles receive no direct resource-need table privileges'
);

select ok(
  to_regclass('public.project_resource_needs_project_created_at_id_idx') is not null,
  'Project history ordering has a supporting foreign-key index'
);
select ok(
  to_regclass('public.project_resource_needs_open_project_created_at_id_idx') is not null,
  'open Project needs have a partial public-order index'
);
select is(
  (
    select lower(pg_get_expr(index_row.indpred, index_row.indrelid))
    from pg_index as index_row
    where index_row.indexrelid =
      'public.project_resource_needs_open_project_created_at_id_idx'::regclass
  ),
  '(state = ''open''::text)',
  'the public-order index contains only open needs'
);

select ok(
  to_regprocedure('public.create_project_resource_need(uuid,uuid,text,text)') is not null,
  'the creator need-create operation exists'
);
select ok(
  to_regprocedure('public.update_project_resource_need(uuid,uuid,text,text)') is not null,
  'the open need-update operation exists'
);
select ok(
  to_regprocedure('public.close_project_resource_need(uuid,uuid)') is not null,
  'the terminal need-close operation exists'
);
select ok(
  to_regprocedure('public.list_own_project_resource_needs(uuid,uuid)') is not null,
  'the creator need-history operation exists'
);
select ok(
  to_regprocedure('public.list_public_project_resource_needs(uuid)') is not null,
  'the public current-Project need operation exists'
);
select ok(
  to_regprocedure('public.delete_project_resource_need(uuid,uuid)') is null,
  '04C3A exposes no hard-delete operation'
);
select ok(
  to_regprocedure('public.reopen_project_resource_need(uuid,uuid)') is null,
  '04C3A exposes no reopen operation'
);

select is(
  (
    select bool_and(prosecdef)
    from pg_proc
    where oid in (
      'public.create_project_resource_need(uuid,uuid,text,text)'::regprocedure,
      'public.update_project_resource_need(uuid,uuid,text,text)'::regprocedure,
      'public.close_project_resource_need(uuid,uuid)'::regprocedure,
      'public.list_own_project_resource_needs(uuid,uuid)'::regprocedure,
      'public.list_public_project_resource_needs(uuid)'::regprocedure
    )
  ),
  true,
  'resource-need APIs use hardened security-definer boundaries'
);
select is(
  (
    select bool_and(array_to_string(proconfig, ',') = 'search_path=""')
    from pg_proc
    where oid in (
      'private.set_project_resource_need_updated_at()'::regprocedure,
      'private.lock_project_for_resource_need_mutation(uuid)'::regprocedure,
      'private.record_project_resource_need_event(text,uuid,uuid,text,uuid)'::regprocedure,
      'public.create_project_resource_need(uuid,uuid,text,text)'::regprocedure,
      'public.update_project_resource_need(uuid,uuid,text,text)'::regprocedure,
      'public.close_project_resource_need(uuid,uuid)'::regprocedure,
      'public.list_own_project_resource_needs(uuid,uuid)'::regprocedure,
      'public.list_public_project_resource_needs(uuid)'::regprocedure
    )
  ),
  true,
  'every resource-need helper and API has an empty fixed search path'
);

select is(
  has_function_privilege(
    'anon',
    'public.list_public_project_resource_needs(uuid)',
    'EXECUTE'
  ),
  true,
  'anonymous users can read public current-Project needs'
);
select is(
  has_function_privilege(
    'authenticated',
    'public.create_project_resource_need(uuid,uuid,text,text)',
    'EXECUTE'
  ),
  true,
  'authenticated users can invoke creator-bound need creation'
);
select is(
  has_function_privilege(
    'anon',
    'public.create_project_resource_need(uuid,uuid,text,text)',
    'EXECUTE'
  ),
  false,
  'anonymous users cannot create Project needs'
);
select is(
  has_function_privilege(
    'service_role',
    'public.list_public_project_resource_needs(uuid)',
    'EXECUTE'
  ),
  false,
  'service role receives no convenience Project-need API grant'
);
select is(
  (
    select bool_or(
      has_function_privilege(
        role_name,
        'private.lock_project_for_resource_need_mutation(uuid)',
        'EXECUTE'
      )
    )
    from unnest(array['anon', 'authenticated', 'service_role']) as roles(role_name)
  ),
  false,
  'the lifecycle lock helper remains unavailable to client and service roles'
);

select is(
  (
    select count(*)
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'project_resource_needs'
      and column_name in (
        'category_id',
        'resource_type',
        'quantity',
        'unit',
        'condition',
        'priority',
        'required_boolean',
        'minimum_amount',
        'maximum_amount',
        'price',
        'currency',
        'due_date',
        'contributor_profile_id',
        'join_request_id',
        'membership_id',
        'resource_listing_id',
        'fulfilled_at',
        'verified_at',
        'metadata',
        'sort_order'
      )
  ),
  0::bigint,
  'needs contain no taxonomy, quantity, price, priority, contributor, participation, listing, fulfillment, metadata, or reorder fields'
);
select is(
  to_regclass('public.project_resource_contribution_offers'),
  null,
  '04C3A adds no contribution-offer table'
);
select is(
  to_regclass('public.project_resource_need_listings'),
  null,
  '04C3A adds no Scambio-Dona linkage table'
);
select ok(
  lower(
    pg_get_functiondef(
      'private.record_project_resource_need_event(text,uuid,uuid,text,uuid)'::regprocedure
    )
  ) not like '%title%',
  'the event writer cannot accept or serialize need titles'
);
select ok(
  lower(
    pg_get_functiondef(
      'private.record_project_resource_need_event(text,uuid,uuid,text,uuid)'::regprocedure
    )
  ) not like '%details%',
  'the event writer cannot accept or serialize need details'
);

select * from finish();

rollback;
