begin;

select no_plan();

select ok(
  to_regprocedure('private.current_project_manager_profile_ids(uuid)')
    is not null
  and to_regprocedure(
    'private.lock_project_manager_interactions(uuid,uuid)'
  ) is not null
  and to_regprocedure(
    'private.accept_project_join_request_as_manager_without_block(uuid,uuid,uuid[],uuid[],uuid[],uuid[],uuid[],uuid[])'
  ) is not null,
  'the cumulative blocking boundary owns one current-manager source, lock helper, and preserved manager-acceptance core'
);

select ok(
  pg_get_functiondef(
    'private.current_project_manager_profile_ids(uuid)'::regprocedure
  ) ilike '%creator_profile_id%'
  and pg_get_functiondef(
    'private.current_project_manager_profile_ids(uuid)'::regprocedure
  ) ilike '%project_delegates%'
  and pg_get_functiondef(
    'private.current_project_manager_profile_ids(uuid)'::regprocedure
  ) ilike '%revoked_at is null%'
  and pg_get_functiondef(
    'private.current_project_manager_profile_ids(uuid)'::regprocedure
  ) ilike '%co_creator%'
  and pg_get_functiondef(
    'private.current_project_manager_profile_ids(uuid)'::regprocedure
  ) ilike '%co_organizer%',
  'the manager set is Creator plus active Co-creator and Co-organizer authority'
);

select ok(
  pg_get_functiondef(
    'private.profile_is_project_manager(uuid,uuid)'::regprocedure
  ) like '%current_project_manager_profile_ids%',
  'the established manager predicate delegates to the canonical manager set'
);

select ok(
  pg_get_functiondef(
    'private.lock_project_manager_interactions(uuid,uuid)'::regprocedure
  ) like '%lock_user_interaction_pair%'
  and pg_get_functiondef(
    'private.lock_project_manager_interactions(uuid,uuid)'::regprocedure
  ) like '%lock_project_for_participation%'
  and pg_get_functiondef(
    'private.lock_project_manager_interactions(uuid,uuid)'::regprocedure
  ) ilike '%is distinct from%'
  and pg_get_functiondef(
    'private.lock_project_manager_interactions(uuid,uuid)'::regprocedure
  ) like '%assert_user_interaction_available%',
  'manager pairs lock before the Project and the manager set and block barrier are revalidated'
);

select ok(
  pg_get_functiondef(
    'public.request_to_join_project(uuid,uuid,text,uuid[],uuid[])'::regprocedure
  ) like '%lock_project_manager_interactions%'
  and pg_get_functiondef(
    'public.accept_project_join_request(uuid,uuid,uuid[],uuid[],uuid[],uuid[],uuid[],uuid[])'::regprocedure
  ) like '%lock_project_manager_interactions%'
  and pg_get_functiondef(
    'public.accept_project_join_request_as_manager(uuid,uuid,uuid[],uuid[],uuid[],uuid[],uuid[],uuid[])'::regprocedure
  ) like '%lock_project_manager_interactions%',
  'request, Creator compatibility acceptance, and delegated-manager acceptance share one blocking boundary'
);

select is(
  (
    select bool_and(
      procedure.prosecdef
      and array_to_string(procedure.proconfig, ',') = 'search_path=""'
    )
    from pg_proc as procedure
    where procedure.oid in (
      'private.current_project_manager_profile_ids(uuid)'::regprocedure,
      'private.lock_project_manager_interactions(uuid,uuid)'::regprocedure,
      'public.accept_project_join_request_as_manager(uuid,uuid,uuid[],uuid[],uuid[],uuid[],uuid[],uuid[])'::regprocedure
    )
  ),
  true,
  'the new helper and public manager wrapper are hardened definers'
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
      'private.current_project_manager_profile_ids(uuid)'::regprocedure,
      'private.lock_project_manager_interactions(uuid,uuid)'::regprocedure,
      'private.accept_project_join_request_as_manager_without_block(uuid,uuid,uuid[],uuid[],uuid[],uuid[],uuid[],uuid[])'::regprocedure
    )
  ),
  false,
  'manager enumeration, locking, and preserved mutation cores are not client-callable'
);

select is(
  (
    select
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
    from pg_proc as procedure
    where procedure.oid =
      'public.accept_project_join_request_as_manager(uuid,uuid,uuid[],uuid[],uuid[],uuid[],uuid[],uuid[])'::regprocedure
  ),
  true,
  'only authenticated clients may call delegated-manager acceptance'
);

select ok(
  pg_get_function_result(
    'public.request_to_join_project(uuid,uuid,text,uuid[],uuid[])'::regprocedure
  ) = 'uuid'
  and pg_get_function_result(
    'public.accept_project_join_request_as_manager(uuid,uuid,uuid[],uuid[],uuid[],uuid[],uuid[],uuid[])'::regprocedure
  ) = 'uuid',
  'public request and acceptance results expose no manager or block graph'
);

select * from finish();

rollback;
