begin;

-- Renumbered during stack integration to preserve globally unique pgTAP order.

select no_plan();

select has_table(
  'public',
  'project_delegate_invitations',
  'delegate invitations have a canonical table'
);
select has_table(
  'public',
  'project_delegates',
  'delegate relationships have a canonical table'
);
select columns_are(
  'public',
  'project_delegate_invitations',
  array[
    'id',
    'project_id',
    'owner_profile_id',
    'token_digest',
    'status',
    'created_at',
    'expires_at',
    'accepted_at',
    'accepted_by_profile_id',
    'revoked_at',
    'revoked_by_profile_id',
    'issuer_profile_id',
    'requested_authority_role'
  ],
  'invites persist only lifecycle metadata and a token digest'
);
select columns_are(
  'public',
  'project_delegates',
  array[
    'id',
    'project_id',
    'owner_profile_id',
    'delegate_profile_id',
    'invitation_id',
    'delegated_at',
    'revoked_at',
    'revoked_by_profile_id',
    'granted_by_profile_id',
    'initial_authority_role',
    'authority_role'
  ],
  'delegate history is distinct from participation membership'
);
select col_is_pk(
  'public',
  'project_delegate_invitations',
  'id',
  'delegate invitations use stable UUID identities'
);
select col_is_pk(
  'public',
  'project_delegates',
  'id',
  'delegate relationships use stable UUID identities'
);
select ok(
  (
    select pg_get_constraintdef(constraint_row.oid)
    from pg_constraint as constraint_row
    where constraint_row.conrelid =
      'public.project_delegate_invitations'::regclass
      and constraint_row.conname =
        'project_delegate_invitations_expiry_valid'
  ) ilike '%created_at +%7 days%',
  'every invite expires exactly seven days after creation'
);
select ok(
  exists (
    select 1
    from pg_indexes
    where schemaname = 'public'
      and tablename = 'project_delegates'
      and indexname = 'project_delegates_one_active_profile_idx'
      and indexdef ilike '%unique%where (revoked_at is null)%'
  ),
  'one profile can have at most one active relationship per Project'
);
select is(
  (
    select bool_and(class.relrowsecurity)
    from pg_class as class
    where class.oid in (
      'public.project_delegate_invitations'::regclass,
      'public.project_delegates'::regclass
    )
  ),
  true,
  'RLS is enabled on both delegate tables'
);
select is(
  (
    select count(*)
    from pg_policies
    where schemaname = 'public'
      and tablename in ('project_delegate_invitations', 'project_delegates')
  ),
  0::bigint,
  'delegate tables are fail-closed without direct client policies'
);
select is(
  (
    select bool_and(
      not has_table_privilege(role_name, table_name, privilege_name)
    )
    from unnest(array['anon', 'authenticated', 'service_role']) as role_name
    cross join unnest(array[
      'public.project_delegate_invitations',
      'public.project_delegates'
    ]) as table_name
    cross join unnest(array['SELECT', 'INSERT', 'UPDATE', 'DELETE'])
      as privilege_name
  ),
  true,
  'client and service roles receive no direct delegate-table privileges'
);

select has_function(
  'public',
  'create_project_delegate_invitation',
  array['uuid', 'uuid'],
  'owners create invitations through a narrow RPC'
);
select has_function(
  'public',
  'preview_project_delegate_invitation',
  array['text'],
  'invite preview has a token-only contract'
);
select has_function(
  'public',
  'accept_project_delegate_invitation',
  array['uuid', 'text'],
  'authenticated profiles explicitly accept an invite token'
);
select has_function(
  'public',
  'revoke_project_delegate',
  array['uuid', 'uuid'],
  'owners revoke a stable delegate relationship'
);
select has_function(
  'private',
  'profile_is_project_manager',
  array['uuid', 'uuid'],
  'manager authorization is centralized'
);
select function_privs_are(
  'public',
  'preview_project_delegate_invitation',
  array['text'],
  'anon',
  array['EXECUTE'],
  'anonymous clients may perform only the safe preview read'
);
select function_privs_are(
  'public',
  'accept_project_delegate_invitation',
  array['uuid', 'text'],
  'authenticated',
  array['EXECUTE'],
  'authenticated clients may explicitly accept invites'
);
select function_privs_are(
  'public',
  'accept_project_delegate_invitation',
  array['uuid', 'text'],
  'anon',
  array[]::text[],
  'anonymous clients cannot accept delegate invites'
);
select function_privs_are(
  'public',
  'list_project_join_requests_for_manager',
  array['uuid', 'uuid'],
  'authenticated',
  array['EXECUTE'],
  'manager-named participation reads are exposed to authenticated clients'
);
select function_privs_are(
  'public',
  'accept_project_join_request_as_manager',
  array['uuid', 'uuid'],
  'authenticated',
  array['EXECUTE'],
  'manager-named participation acceptance is exposed deliberately'
);

select * from finish();
rollback;
