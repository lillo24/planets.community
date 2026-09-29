begin;

select no_plan();

select has_table(
  'public',
  'project_shared_workspaces',
  'Projects have one canonical shared-workspace relation'
);
select columns_are(
  'public',
  'project_shared_workspaces',
  array['project_id', 'workspace_url', 'created_at', 'updated_at'],
  'workspace rows contain only the Project, sensitive URL, and timestamps'
);
select col_is_pk(
  'public',
  'project_shared_workspaces',
  'project_id',
  'one workspace row is allowed per Project'
);
select col_type_is(
  'public',
  'project_shared_workspaces',
  'project_id',
  'uuid',
  'workspace Project identifiers are UUIDs'
);
select col_not_null(
  'public',
  'project_shared_workspaces',
  'workspace_url',
  'configured workspaces always have a URL'
);
select ok(
  (
    select pg_get_constraintdef(constraint_row.oid)
    from pg_constraint as constraint_row
    where constraint_row.conrelid =
      'public.project_shared_workspaces'::regclass
      and constraint_row.conname =
        'project_shared_workspaces_project_id_fkey'
  ) ilike '%references projects(id) on delete cascade%',
  'workspace rows share the canonical Project identity and lifecycle'
);
select ok(
  (
    select pg_get_constraintdef(constraint_row.oid)
    from pg_constraint as constraint_row
    where constraint_row.conrelid =
      'public.project_shared_workspaces'::regclass
      and constraint_row.conname =
        'project_shared_workspaces_url_length'
  ) ilike '%2048%',
  'workspace URLs have the canonical maximum length'
);
select ok(
  (
    select pg_get_constraintdef(constraint_row.oid)
    from pg_constraint as constraint_row
    where constraint_row.conrelid =
      'public.project_shared_workspaces'::regclass
      and constraint_row.conname =
        'project_shared_workspaces_url_https'
  ) ilike '%https://%'
    and (
      select pg_get_constraintdef(constraint_row.oid)
      from pg_constraint as constraint_row
      where constraint_row.conrelid =
        'public.project_shared_workspaces'::regclass
        and constraint_row.conname =
          'project_shared_workspaces_url_https'
    ) ilike '%[[:space:][:cntrl:]]%',
  'workspace URLs are absolute HTTPS values without whitespace or controls'
);
select is(
  (
    select relrowsecurity
    from pg_class
    where oid = 'public.project_shared_workspaces'::regclass
  ),
  true,
  'workspace rows have RLS enabled'
);
select is(
  (
    select count(*)
    from pg_policies
    where schemaname = 'public'
      and tablename = 'project_shared_workspaces'
  ),
  0::bigint,
  'workspace rows remain RPC-only with no direct policies'
);
select is(
  (
    select bool_and(
      not has_table_privilege(
        role_name,
        'public.project_shared_workspaces',
        privilege_name
      )
    )
    from unnest(array['anon', 'authenticated', 'service_role']) as role_name
    cross join unnest(array['SELECT', 'INSERT', 'UPDATE', 'DELETE'])
      as privilege_name
  ),
  true,
  'no Data API role has direct workspace-table privileges'
);

select has_function(
  'private',
  'profile_can_read_project_workspace',
  array['uuid', 'uuid'],
  'current workspace read entitlement has one canonical helper'
);
select has_function(
  'public',
  'get_own_project_shared_workspace',
  array['uuid', 'uuid'],
  'workspace reads are identity-bound'
);
select has_function(
  'public',
  'set_project_shared_workspace',
  array['uuid', 'uuid', 'text'],
  'workspace replacement is manager-bound'
);
select has_function(
  'public',
  'clear_project_shared_workspace',
  array['uuid', 'uuid'],
  'workspace clearing is manager-bound'
);
select function_privs_are(
  'public',
  'get_own_project_shared_workspace',
  array['uuid', 'uuid'],
  'authenticated',
  array['EXECUTE'],
  'authenticated callers may reach the protected workspace read boundary'
);
select function_privs_are(
  'public',
  'set_project_shared_workspace',
  array['uuid', 'uuid', 'text'],
  'authenticated',
  array['EXECUTE'],
  'authenticated managers may reach the protected workspace mutation boundary'
);
select function_privs_are(
  'public',
  'clear_project_shared_workspace',
  array['uuid', 'uuid'],
  'authenticated',
  array['EXECUTE'],
  'authenticated managers may reach the protected workspace clear boundary'
);
select function_privs_are(
  'public',
  'get_own_project_shared_workspace',
  array['uuid', 'uuid'],
  'anon',
  array[]::text[],
  'anonymous callers cannot retrieve a private workspace URL'
);
select function_privs_are(
  'private',
  'profile_can_read_project_workspace',
  array['uuid', 'uuid'],
  'authenticated',
  array[]::text[],
  'clients cannot bypass the public workspace RPC'
);
select ok(
  pg_get_functiondef(
    'public.set_project_shared_workspace(uuid,uuid,text)'::regprocedure
  ) ilike '%for update%'
    and pg_get_functiondef(
      'public.set_project_shared_workspace(uuid,uuid,text)'::regprocedure
    ) ilike '%profile_is_project_manager%',
  'workspace replacement locks the Project and rechecks current management'
);
select ok(
  pg_get_functiondef(
    'public.get_own_project_shared_workspace(uuid,uuid)'::regprocedure
  ) ilike '%profile_can_read_project_workspace%'
    and pg_get_functiondef(
      'private.profile_can_read_project_workspace(uuid,uuid)'::regprocedure
    ) ilike '%profile_has_current_project_membership%'
    and pg_get_functiondef(
      'private.profile_can_read_project_workspace(uuid,uuid)'::regprocedure
    ) ilike '%profile_is_project_manager%',
  'workspace reads require current management or current participation'
);
select is(
  (
    select count(*)
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'project_shared_workspaces'
      and column_name in (
        'provider',
        'provider_token',
        'access_token',
        'refresh_token',
        'drive_file_id'
      )
  ),
  0::bigint,
  'workspace storage has no provider or OAuth token columns'
);

select * from finish();
rollback;
