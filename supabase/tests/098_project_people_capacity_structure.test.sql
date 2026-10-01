begin;

-- Renumbered during stack integration to preserve globally unique pgTAP order.

select no_plan();

select has_column(
  'public',
  'projects',
  'registration_capacity',
  'the shared Project registry owns canonical registration capacity'
);
select col_type_is(
  'public',
  'projects',
  'registration_capacity',
  'integer',
  'registration capacity uses an integer domain'
);
select is(
  (
    select column_default
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'projects'
      and column_name = 'registration_capacity'
  ),
  null,
  'capacity defaults to the legacy/draft unspecified state'
);
select has_column(
  'public',
  'projects',
  'count_organizers_toward_capacity',
  'the shared Project registry owns the organizer counting policy'
);
select col_type_is(
  'public',
  'projects',
  'count_organizers_toward_capacity',
  'boolean',
  'the organizer counting policy is boolean'
);
select col_default_is(
  'public',
  'projects',
  'count_organizers_toward_capacity',
  'false',
  'existing and new Projects exclude organizers by default'
);
select col_not_null(
  'public',
  'projects',
  'count_organizers_toward_capacity',
  'the organizer counting policy cannot be ambiguous'
);
select ok(
  exists (
    select 1
    from pg_catalog.pg_constraint as constraint_record
    where constraint_record.conrelid = 'public.projects'::regclass
      and constraint_record.conname = 'projects_registration_capacity_bounds_check'
      and constraint_record.contype = 'c'
  ),
  'capacity has a database bounds constraint'
);
select has_index(
  'public',
  'project_memberships',
  'project_memberships_current_project_idx',
  'current occupancy counts have a project-scoped partial index'
);
select has_trigger(
  'public',
  'project_join_requests',
  'project_join_requests_enforce_capacity',
  'new pending requests enforce fullness'
);
select has_trigger(
  'public',
  'project_memberships',
  'project_memberships_enforce_capacity',
  'every current-membership insertion enforces fullness'
);
select has_trigger(
  'public',
  'project_delegates',
  'project_delegates_enforce_capacity',
  'delegate activation and revocation preserve registration capacity'
);
select has_trigger(
  'public',
  'proposals',
  'proposals_require_capacity_for_publication',
  'Proposal publication requires capacity'
);
select has_trigger(
  'public',
  'recurring_activities',
  'recurring_activities_require_capacity_for_publication',
  'Tavolo publication requires capacity'
);

select function_privs_are(
  'public',
  'list_public_project_capacity_statuses',
  array['uuid[]'],
  'anon',
  array['EXECUTE'],
  'anonymous users can read aggregate public capacity only through the RPC'
);
select function_privs_are(
  'public',
  'get_project_capacity_for_manager',
  array['uuid', 'uuid'],
  'anon',
  array[]::text[],
  'anonymous users cannot use manager capacity reads'
);

select is(
  (
    select count(*)
    from information_schema.role_column_grants
    where table_schema = 'public'
      and table_name = 'projects'
      and grantee in ('anon', 'authenticated')
  ),
  0::bigint,
  'capacity adds no direct client grants on public.projects'
);

select * from finish();
rollback;
