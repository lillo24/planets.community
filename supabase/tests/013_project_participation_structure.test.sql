begin;

select no_plan();

select has_table('public', 'projects', 'the shared project registry exists');
select has_table(
  'public',
  'project_join_requests',
  'project join-request history exists'
);
select has_table(
  'public',
  'project_memberships',
  'project membership history exists'
);

select columns_are(
  'public',
  'projects',
  array[
    'id',
    'project_kind',
    'creator_profile_id',
    'created_at',
    'people_capacity'
  ],
  'the shared Project registry owns identity and cross-kind capacity only'
);
select columns_are(
  'public',
  'project_join_requests',
  array[
    'id',
    'project_id',
    'requester_profile_id',
    'status',
    'request_message',
    'created_at',
    'resolved_at',
    'resolved_by_profile_id'
  ],
  'join requests preserve private attempt and resolution history'
);
select columns_are(
  'public',
  'project_memberships',
  array[
    'id',
    'project_id',
    'participant_profile_id',
    'originating_request_id',
    'joined_at',
    'left_at',
    'removed_at',
    'removed_by_profile_id'
  ],
  'memberships preserve acceptance and terminal history without invented roles'
);

select col_is_pk('public', 'projects', 'id', 'project IDs are primary keys');
select col_is_pk(
  'public',
  'project_join_requests',
  'id',
  'join-request IDs are stable primary keys'
);
select col_is_pk(
  'public',
  'project_memberships',
  'id',
  'membership IDs are stable primary keys'
);
select col_type_is('public', 'projects', 'id', 'uuid', 'shared project IDs are UUIDs');
select col_type_is(
  'public',
  'project_join_requests',
  'created_at',
  'timestamp with time zone',
  'request creation is timezone-aware'
);
select col_type_is(
  'public',
  'project_memberships',
  'joined_at',
  'timestamp with time zone',
  'membership acceptance is timezone-aware'
);

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.projects'::regclass
      and conname = 'projects_kind_valid'
      and contype = 'c'
  ),
  'project kind is constrained to concrete supported domains'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.project_join_requests'::regclass
      and conname = 'project_join_requests_status_valid'
      and contype = 'c'
  ),
  'request state is constrained'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.project_memberships'::regclass
      and conname = 'project_memberships_originating_request_fkey'
      and contype = 'f'
  ),
  'membership origin must match the same project and participant request'
);

select is(
  (select relrowsecurity from pg_class where oid = 'public.projects'::regclass),
  true,
  'project registry RLS is enabled'
);
select is(
  (
    select relrowsecurity
    from pg_class
    where oid = 'public.project_join_requests'::regclass
  ),
  true,
  'join-request RLS is enabled'
);
select is(
  (
    select relrowsecurity
    from pg_class
    where oid = 'public.project_memberships'::regclass
  ),
  true,
  'membership RLS is enabled'
);
select is(
  (
    select count(*)
    from pg_policies
    where schemaname = 'public'
      and tablename in ('projects', 'project_join_requests', 'project_memberships')
  ),
  0::bigint,
  'participation tables expose no direct client policies'
);

select ok(
  to_regclass('public.projects_creator_profile_id_created_at_idx') is not null,
  'shared project creator lookups and the foreign key are indexed'
);
select ok(
  to_regclass('public.project_join_requests_one_pending_idx') is not null,
  'one pending request per requester and project is indexed and enforced'
);
select ok(
  to_regclass('public.project_memberships_one_current_idx') is not null,
  'one current membership per participant and project is indexed and enforced'
);
select is(
  (
    select lower(pg_get_expr(index_row.indpred, index_row.indrelid))
    from pg_index as index_row
    where index_row.indexrelid =
      'public.project_join_requests_one_pending_idx'::regclass
  ),
  '(status = ''pending''::text)',
  'pending-request uniqueness applies only to pending attempts'
);
select is(
  (
    select lower(pg_get_expr(index_row.indpred, index_row.indrelid))
    from pg_index as index_row
    where index_row.indexrelid =
      'public.project_memberships_one_current_idx'::regclass
  ),
  '((left_at is null) and (removed_at is null))',
  'current-membership uniqueness excludes ended history'
);

select ok(
  exists (
    select 1
    from pg_trigger
    where tgrelid = 'public.proposals'::regclass
      and tgname = 'proposals_register_project'
      and not tgisinternal
  ),
  'future proposal inserts register a shared project identity'
);
select ok(
  exists (
    select 1
    from pg_trigger
    where tgrelid = 'public.recurring_activities'::regclass
      and tgname = 'recurring_activities_register_project'
      and not tgisinternal
  ),
  'future recurring-activity inserts register a shared project identity'
);
select ok(
  exists (
    select 1
    from pg_trigger
    where tgrelid = 'public.proposals'::regclass
      and tgname = 'proposals_unregister_project'
      and not tgisinternal
  ),
  'proposal deletion cannot bypass shared participation history'
);
select ok(
  exists (
    select 1
    from pg_trigger
    where tgrelid = 'public.recurring_activities'::regclass
      and tgname = 'recurring_activities_unregister_project'
      and not tgisinternal
  ),
  'recurring deletion cannot bypass shared participation history'
);

select ok(
  to_regprocedure(
    'public.request_to_join_project(uuid,uuid,text,uuid[],uuid[])'
  ) is not null,
  'the canonical request operation exists'
);
select ok(
  to_regprocedure('public.withdraw_project_join_request(uuid,uuid)') is not null,
  'the canonical withdrawal operation exists'
);
select ok(
  to_regprocedure('public.accept_project_join_request(uuid,uuid)') is not null,
  'the canonical acceptance operation exists'
);
select ok(
  to_regprocedure('public.reject_project_join_request(uuid,uuid)') is not null,
  'the canonical rejection operation exists'
);
select ok(
  to_regprocedure('public.leave_project(uuid,uuid)') is not null,
  'the canonical leave operation exists'
);
select ok(
  to_regprocedure('public.remove_project_member(uuid,uuid)') is not null,
  'the canonical removal operation exists'
);
select ok(
  to_regprocedure('public.list_own_project_join_requests(uuid)') is not null,
  'the requester-private history read exists'
);
select ok(
  to_regprocedure('public.list_project_join_requests(uuid,uuid)') is not null,
  'the creator-private request review read exists'
);
select ok(
  to_regprocedure('public.list_own_project_memberships(uuid)') is not null,
  'the participant-private membership read exists'
);
select ok(
  to_regprocedure('public.list_project_members(uuid,uuid)') is not null,
  'the creator-private member history read exists'
);
select ok(
  to_regprocedure('public.get_project_participant_meeting_details(uuid,uuid)')
    is not null,
  'the participant-authorized operational meeting read exists'
);

select is(
  (
    select bool_and(procedure.prosecdef)
    from pg_proc as procedure
    where procedure.oid in (
      'public.request_to_join_project(uuid,uuid,text,uuid[],uuid[])'::regprocedure,
      'public.withdraw_project_join_request(uuid,uuid)'::regprocedure,
      'public.accept_project_join_request(uuid,uuid)'::regprocedure,
      'public.reject_project_join_request(uuid,uuid)'::regprocedure,
      'public.leave_project(uuid,uuid)'::regprocedure,
      'public.remove_project_member(uuid,uuid)'::regprocedure,
      'public.list_own_project_join_requests(uuid)'::regprocedure,
      'public.list_project_join_requests(uuid,uuid)'::regprocedure,
      'public.list_own_project_memberships(uuid)'::regprocedure,
      'public.list_project_members(uuid,uuid)'::regprocedure,
      'public.get_project_participant_meeting_details(uuid,uuid)'::regprocedure
    )
  ),
  true,
  'all client participation operations use deliberate security-definer boundaries'
);
select is(
  (
    select bool_and(array_to_string(procedure.proconfig, ',') = 'search_path=""')
    from pg_proc as procedure
    where procedure.oid in (
      'public.request_to_join_project(uuid,uuid,text,uuid[],uuid[])'::regprocedure,
      'public.withdraw_project_join_request(uuid,uuid)'::regprocedure,
      'public.accept_project_join_request(uuid,uuid)'::regprocedure,
      'public.reject_project_join_request(uuid,uuid)'::regprocedure,
      'public.leave_project(uuid,uuid)'::regprocedure,
      'public.remove_project_member(uuid,uuid)'::regprocedure,
      'public.list_own_project_join_requests(uuid)'::regprocedure,
      'public.list_project_join_requests(uuid,uuid)'::regprocedure,
      'public.list_own_project_memberships(uuid)'::regprocedure,
      'public.list_project_members(uuid,uuid)'::regprocedure,
      'public.get_project_participant_meeting_details(uuid,uuid)'::regprocedure
    )
  ),
  true,
  'all client participation security definers fix an empty search path'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.request_to_join_project(uuid,uuid,text,uuid[],uuid[])',
    'EXECUTE'
  ),
  true,
  'authenticated clients can execute the request boundary'
);
select is(
  has_function_privilege(
    'anon',
    'public.request_to_join_project(uuid,uuid,text,uuid[],uuid[])',
    'EXECUTE'
  ),
  false,
  'anonymous clients cannot execute participation mutations'
);
select is(
  has_table_privilege('authenticated', 'public.projects', 'SELECT'),
  false,
  'authenticated clients cannot enumerate the registry directly'
);
select is(
  has_table_privilege('authenticated', 'public.project_join_requests', 'SELECT'),
  false,
  'authenticated clients cannot enumerate private join requests directly'
);
select is(
  has_table_privilege('authenticated', 'public.project_memberships', 'SELECT'),
  false,
  'authenticated clients cannot enumerate private memberships directly'
);

select * from finish();

rollback;
