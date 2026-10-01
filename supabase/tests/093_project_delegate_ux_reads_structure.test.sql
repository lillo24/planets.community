begin;

-- Renumbered during stack integration to preserve globally unique pgTAP order.

select no_plan();

select has_function(
  'public',
  'get_own_project_management_role',
  array['uuid', 'uuid'],
  'clients have one exact Project management-role read'
);
select has_function(
  'public',
  'list_own_delegated_projects',
  array['uuid'],
  'clients have one current-profile co-organized Project projection'
);
select function_returns(
  'public',
  'get_own_project_management_role',
  array['uuid', 'uuid'],
  'text',
  'the management-role read distinguishes Creator and both delegated roles'
);
select function_privs_are(
  'public',
  'get_own_project_management_role',
  array['uuid', 'uuid'],
  'authenticated',
  array['EXECUTE'],
  'only authenticated clients can resolve their own management role'
);
select function_privs_are(
  'public',
  'get_own_project_management_role',
  array['uuid', 'uuid'],
  'anon',
  array[]::text[],
  'anonymous clients cannot resolve management roles'
);
select function_privs_are(
  'public',
  'list_own_delegated_projects',
  array['uuid'],
  'authenticated',
  array['EXECUTE'],
  'authenticated clients can list only their own co-organized Projects'
);
select function_privs_are(
  'public',
  'list_own_delegated_projects',
  array['uuid'],
  'anon',
  array[]::text[],
  'anonymous clients cannot list co-organized Projects'
);

select * from finish();
rollback;
