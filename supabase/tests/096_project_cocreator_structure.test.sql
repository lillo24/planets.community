begin;

-- Renumbered during stack integration to preserve globally unique pgTAP order.

select no_plan();

select has_table(
  'public',
  'project_delegate_role_changes',
  'delegated authority role changes have append-only history'
);
select columns_are(
  'public',
  'project_delegate_role_changes',
  array[
    'id',
    'delegate_id',
    'project_id',
    'delegate_profile_id',
    'from_authority_role',
    'to_authority_role',
    'changed_by_profile_id',
    'changed_at'
  ],
  'role history retains the relationship, target, transition, actor, and time'
);
select col_not_null(
  'public',
  'project_delegate_invitations',
  'issuer_profile_id',
  'every invitation preserves its real issuer'
);
select col_not_null(
  'public',
  'project_delegate_invitations',
  'requested_authority_role',
  'every invitation requests one explicit delegated role'
);
select col_not_null(
  'public',
  'project_delegates',
  'granted_by_profile_id',
  'every delegated relationship preserves its real grantor'
);
select col_not_null(
  'public',
  'project_delegates',
  'authority_role',
  'every delegated relationship has one current role'
);
select is(
  (
    select column_default
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'project_delegate_invitations'
      and column_name = 'requested_authority_role'
  ),
  '''co_organizer''::text',
  'legacy invitation inserts default to Co-organizer'
);
select is(
  (
    select column_default
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'project_delegates'
      and column_name = 'authority_role'
  ),
  '''co_organizer''::text',
  'legacy delegated relationships default to Co-organizer'
);
select ok(
  (
    select pg_get_constraintdef(constraint_row.oid)
    from pg_constraint as constraint_row
    where constraint_row.conrelid =
      'public.project_delegate_invitations'::regclass
      and constraint_row.conname =
        'project_delegate_invitations_requested_role_valid'
  ) ilike '%co_organizer%co_creator%',
  'invitation roles fail closed outside the two delegated levels'
);
select ok(
  (
    select pg_get_constraintdef(constraint_row.oid)
    from pg_constraint as constraint_row
    where constraint_row.conrelid = 'public.project_delegates'::regclass
      and constraint_row.conname = 'project_delegates_authority_role_valid'
  ) ilike '%co_organizer%co_creator%',
  'active authority roles fail closed outside the two delegated levels'
);
select is(
  (
    select relrowsecurity
    from pg_class
    where oid = 'public.project_delegate_role_changes'::regclass
  ),
  true,
  'role-change history has RLS enabled'
);
select is(
  (
    select count(*)
    from pg_policies
    where schemaname = 'public'
      and tablename = 'project_delegate_role_changes'
  ),
  0::bigint,
  'role-change history remains RPC-only with no client policy'
);
select is(
  (
    select bool_and(
      not has_table_privilege(
        role_name,
        'public.project_delegate_role_changes',
        privilege_name
      )
    )
    from unnest(array['anon', 'authenticated', 'service_role']) as role_name
    cross join unnest(array['SELECT', 'INSERT', 'UPDATE', 'DELETE'])
      as privilege_name
  ),
  true,
  'no API role receives direct role-history privileges'
);

select has_function(
  'private',
  'profile_has_project_structural_authority',
  array['uuid', 'uuid'],
  'structural authority has one canonical helper'
);
select has_function(
  'public',
  'create_project_delegate_invitation',
  array['uuid', 'uuid', 'text'],
  'role-aware invitation creation is explicit'
);
select has_function(
  'public',
  'create_project_delegate_invitation',
  array['uuid', 'uuid'],
  'the 07C2B Co-organizer invitation signature remains available'
);
select has_function(
  'public',
  'change_project_delegate_role',
  array['uuid', 'uuid', 'text'],
  'promotion and demotion use one atomic RPC'
);
select function_privs_are(
  'public',
  'change_project_delegate_role',
  array['uuid', 'uuid', 'text'],
  'authenticated',
  array['EXECUTE'],
  'authenticated callers may reach the identity-bound role-change boundary'
);
select function_privs_are(
  'public',
  'change_project_delegate_role',
  array['uuid', 'uuid', 'text'],
  'anon',
  array[]::text[],
  'anonymous callers cannot change delegated authority'
);
select function_privs_are(
  'private',
  'profile_has_project_structural_authority',
  array['uuid', 'uuid'],
  'authenticated',
  array[]::text[],
  'clients cannot bypass the public structural-authority boundaries'
);
select ok(
  pg_get_functiondef(
    'public.accept_project_delegate_invitation(uuid,text)'::regprocedure
  ) ilike '%lock_project_for_delegate_management%'
    and pg_get_functiondef(
      'public.accept_project_delegate_invitation(uuid,text)'::regprocedure
    ) ilike '%for update%'
    and pg_get_functiondef(
      'public.accept_project_delegate_invitation(uuid,text)'::regprocedure
    ) ilike '%profile_has_project_structural_authority%',
  'acceptance serializes on the Project and invite then rechecks issuer authority'
);
select ok(
  pg_get_functiondef(
    'public.change_project_delegate_role(uuid,uuid,text)'::regprocedure
  ) ilike '%lock_project_for_delegate_management%'
    and pg_get_functiondef(
      'public.change_project_delegate_role(uuid,uuid,text)'::regprocedure
    ) ilike '%for update%'
    and pg_get_functiondef(
      'public.change_project_delegate_role(uuid,uuid,text)'::regprocedure
    ) ilike '%invalidate_project_authority_invitations%',
  'role changes share the Project lock order and invalidate demoted issuer grants'
);

select * from finish();
rollback;
