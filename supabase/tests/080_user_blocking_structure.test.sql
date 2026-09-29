begin;

select no_plan();

select has_table(
  'private',
  'user_block_episodes',
  'directional block episodes stay outside the Data API schema'
);

select is(
  (
    select class.relrowsecurity
    from pg_class as class
    join pg_namespace as namespace on namespace.oid = class.relnamespace
    where namespace.nspname = 'private'
      and class.relname = 'user_block_episodes'
  ),
  true,
  'block episodes enable RLS as defense in depth'
);

select is(
  (
    select bool_or(
      has_table_privilege(
        role_name,
        'private.user_block_episodes',
        privilege_name
      )
    )
    from unnest(array['anon', 'authenticated', 'service_role'])
      as roles(role_name)
    cross join unnest(array['SELECT', 'INSERT', 'UPDATE', 'DELETE'])
      as privileges(privilege_name)
  ),
  false,
  'API roles have no direct block-history privileges'
);

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'private.user_block_episodes'::regclass
      and conname = 'user_block_episodes_profiles_differ'
  )
  and exists (
    select 1
    from pg_constraint
    where conrelid = 'private.user_block_episodes'::regclass
      and conname = 'user_block_episodes_interval_valid'
  ),
  'self-block and invalid interval constraints are canonical'
);

select ok(
  exists (
    select 1
    from pg_indexes
    where schemaname = 'private'
      and indexname = 'user_block_episodes_one_active_direction_idx'
      and indexdef like '%UNIQUE%'
      and indexdef like '%unblocked_at IS NULL%'
  ),
  'one partial unique index permits at most one active directional episode'
);

select ok(
  exists (
    select 1
    from pg_indexes
    where schemaname = 'private'
      and indexname = 'user_block_episodes_active_outbound_page_idx'
  )
  and exists (
    select 1
    from pg_indexes
    where schemaname = 'private'
      and indexname = 'user_block_episodes_active_inbound_lookup_idx'
  ),
  'outbound pagination and reverse symmetric lookups are indexed'
);

select ok(
  exists (
    select 1
    from pg_trigger
    where tgrelid = 'private.user_block_episodes'::regclass
      and tgname = 'user_block_episodes_preserve_history'
      and not tgisinternal
  ),
  'block history has an immutable-identity/one-way-close trigger'
);

select ok(
  to_regprocedure('public.block_user(uuid,uuid)') is not null
  and to_regprocedure('public.unblock_user(uuid,uuid)') is not null
  and to_regprocedure(
    'public.list_own_blocked_profiles(uuid,integer,timestamp with time zone,uuid)'
  ) is not null,
  'expected-identity block, unblock, and outbound-list RPCs exist'
);

select ok(
  to_regprocedure(
    'private.has_active_directional_user_block(uuid,uuid)'
  ) is not null
  and to_regprocedure(
    'private.has_active_user_block_between(uuid,uuid)'
  ) is not null
  and to_regprocedure(
    'private.lock_user_interaction_pair(uuid,uuid)'
  ) is not null,
  'directional lookup, symmetric barrier, and pair serialization are centralized'
);

select is(
  (
    select bool_and(
      procedure.prosecdef
      and array_to_string(procedure.proconfig, ',') = 'search_path=""'
    )
    from pg_proc as procedure
    where procedure.oid in (
      'public.block_user(uuid,uuid)'::regprocedure,
      'public.unblock_user(uuid,uuid)'::regprocedure,
      'public.list_own_blocked_profiles(uuid,integer,timestamp with time zone,uuid)'::regprocedure,
      'private.has_active_directional_user_block(uuid,uuid)'::regprocedure,
      'private.has_active_user_block_between(uuid,uuid)'::regprocedure,
      'private.lock_user_interaction_pair(uuid,uuid)'::regprocedure,
      'private.close_pending_direct_requests_for_user_block(uuid,uuid)'::regprocedure
    )
  ),
  true,
  'block authorization and serialization helpers are hardened definers'
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
      'public.block_user(uuid,uuid)'::regprocedure,
      'public.unblock_user(uuid,uuid)'::regprocedure,
      'public.list_own_blocked_profiles(uuid,integer,timestamp with time zone,uuid)'::regprocedure
    )
  ),
  true,
  'only authenticated clients may call user-block RPCs'
);

select is(
  (
    select bool_or(
      has_function_privilege(role_name, procedure.oid, 'EXECUTE')
    )
    from pg_proc as procedure
    cross join unnest(array['anon', 'authenticated', 'service_role'])
      as roles(role_name)
    where procedure.oid in (
      'private.has_active_directional_user_block(uuid,uuid)'::regprocedure,
      'private.has_active_user_block_between(uuid,uuid)'::regprocedure,
      'private.lock_user_interaction_pair(uuid,uuid)'::regprocedure,
      'private.close_pending_direct_requests_for_user_block(uuid,uuid)'::regprocedure,
      'private.request_to_join_project_without_block(uuid,uuid,text,uuid[],uuid[])'::regprocedure,
      'private.accept_project_join_request_without_block(uuid,uuid,uuid[],uuid[],uuid[],uuid[],uuid[],uuid[])'::regprocedure,
      'private.request_resource_listing_without_block(uuid,uuid,text)'::regprocedure,
      'private.accept_resource_listing_request_without_block(uuid,uuid)'::regprocedure
    )
  ),
  false,
  'block helpers and preserved domain cores are never client-callable'
);

select ok(
  pg_get_function_result(
    'public.list_own_blocked_profiles(uuid,integer,timestamp with time zone,uuid)'::regprocedure
  )::text like '%blocked_profile_id%'
  and pg_get_function_result(
    'public.list_own_blocked_profiles(uuid,integer,timestamp with time zone,uuid)'::regprocedure
  )::text like '%blocked_display_name%'
  and pg_get_function_result(
    'public.list_own_blocked_profiles(uuid,integer,timestamp with time zone,uuid)'::regprocedure
  )::text not like '%blocker_profile_id%'
  and pg_get_function_result(
    'public.list_own_blocked_profiles(uuid,integer,timestamp with time zone,uuid)'::regprocedure
  )::text not like '%email%'
  and pg_get_function_result(
    'public.list_own_blocked_profiles(uuid,integer,timestamp with time zone,uuid)'::regprocedure
  )::text not like '%reciprocal%'
  and pg_get_function_result(
    'public.list_own_blocked_profiles(uuid,integer,timestamp with time zone,uuid)'::regprocedure
  )::text not like '%inbound%',
  'the only block read exposes safe outbound management fields'
);

select ok(
  pg_get_functiondef(
    'public.request_to_join_project(uuid,uuid,text,uuid[],uuid[])'::regprocedure
  ) like '%lock_user_interaction_pair%'
  and pg_get_functiondef(
    'public.request_to_join_project(uuid,uuid,text,uuid[],uuid[])'::regprocedure
  ) like '%assert_user_interaction_available%'
  and pg_get_functiondef(
    'public.accept_project_join_request(uuid,uuid,uuid[],uuid[],uuid[],uuid[],uuid[],uuid[])'::regprocedure
  ) like '%lock_user_interaction_pair%'
  and pg_get_functiondef(
    'public.accept_project_join_request(uuid,uuid,uuid[],uuid[],uuid[],uuid[],uuid[],uuid[])'::regprocedure
  ) like '%assert_user_interaction_available%',
  'Project creation and canonical acceptance share the pair lock and barrier'
);

select ok(
  pg_get_functiondef(
    'public.request_resource_listing(uuid,uuid,text)'::regprocedure
  ) like '%lock_user_interaction_pair%'
  and pg_get_functiondef(
    'public.request_resource_listing(uuid,uuid,text)'::regprocedure
  ) like '%assert_user_interaction_available%'
  and pg_get_functiondef(
    'public.accept_resource_listing_request(uuid,uuid)'::regprocedure
  ) like '%lock_user_interaction_pair%'
  and pg_get_functiondef(
    'public.accept_resource_listing_request(uuid,uuid)'::regprocedure
  ) like '%assert_user_interaction_available%',
  'Resource creation and acceptance share the pair lock and barrier'
);

select ok(
  pg_get_functiondef(
    'private.can_view_profile_photo(uuid,uuid)'::regprocedure
  ) like '%has_active_user_block_between%'
  and pg_get_functiondef(
    'public.get_project_creator_profile_photo_for_viewer(uuid)'::regprocedure
  ) like '%has_active_user_block_between%'
  and pg_get_functiondef(
    'public.get_resource_listing_owner_profile_photo_for_viewer(uuid)'::regprocedure
  ) like '%has_active_user_block_between%'
  and pg_get_functiondef(
    'public.can_read_public_project_creator_photo_object(text)'::regprocedure
  ) like '%has_active_user_block_between%'
  and pg_get_functiondef(
    'public.can_read_public_resource_listing_owner_photo_object(text)'::regprocedure
  ) like '%has_active_user_block_between%',
  'generic, contextual, and Storage photo authorization share the block barrier'
);

select ok(
  pg_get_function_result('public.get_public_profile(uuid)'::regprocedure)::text
    not like '%block%'
  and pg_get_function_result(
    'public.list_public_resource_listings(integer,timestamp with time zone,uuid,text,text,text)'::regprocedure
  )::text not like '%block%',
  'public profile and Resource discovery contracts expose no block state'
);

select * from finish();

rollback;
