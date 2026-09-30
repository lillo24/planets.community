begin;

select no_plan();

select has_table('private', 'moderation_staff_roles', 'staff roles are private');
select has_table('private', 'moderation_cases', 'moderation cases are private');
select has_table('private', 'moderation_reports', 'report evidence is private');
select has_table('private', 'moderation_case_notes', 'staff notes are private');
select has_table('private', 'moderation_case_events', 'case events are private');

select is(
  (
    select bool_and(class.relrowsecurity)
    from pg_class as class
    join pg_namespace as namespace on namespace.oid = class.relnamespace
    where namespace.nspname = 'private'
      and class.relname in (
        'moderation_staff_roles',
        'moderation_cases',
        'moderation_reports',
        'moderation_case_notes',
        'moderation_case_events'
      )
  ),
  true,
  'every private moderation table has RLS enabled as defense in depth'
);

select is(
  (
    select bool_or(
      has_table_privilege(
        role_name,
        format('private.%I', class.relname),
        privilege_name
      )
    )
    from pg_class as class
    join pg_namespace as namespace on namespace.oid = class.relnamespace
    cross join unnest(array['anon', 'authenticated', 'service_role'])
      as roles(role_name)
    cross join unnest(array['SELECT', 'INSERT', 'UPDATE', 'DELETE'])
      as privileges(privilege_name)
    where namespace.nspname = 'private'
      and class.relname in (
        'moderation_staff_roles',
        'moderation_cases',
        'moderation_reports',
        'moderation_case_notes',
        'moderation_case_events'
      )
  ),
  false,
  'no API role has direct moderation table privileges'
);

select ok(
  to_regprocedure(
    'public.submit_moderation_report(uuid,uuid,text,text,text,uuid,text,uuid)'
  ) is not null,
  'the expected-identity-bound report submission operation exists'
);
select ok(
  to_regprocedure(
    'public.list_own_moderation_reports(uuid,integer,timestamptz,uuid)'
  ) is not null,
  'the narrow reporter-owned projection exists'
);
select ok(
  to_regprocedure('public.get_own_moderation_staff_access(uuid)') is not null,
  'the current-staff access check exists'
);
select ok(
  to_regprocedure(
    'public.list_moderation_cases(uuid,text,integer,timestamptz,uuid)'
  ) is not null,
  'the bounded staff queue exists'
);
select ok(
  to_regprocedure('public.get_moderation_case_detail(uuid,uuid)') is not null,
  'the staff case detail exists'
);
select ok(
  to_regprocedure('public.add_moderation_case_note(uuid,uuid,text)') is not null,
  'the append-only staff note operation exists'
);
select ok(
  to_regprocedure(
    'public.transition_moderation_case(uuid,uuid,bigint,text)'
  ) is not null,
  'the compare-and-swap review transition exists'
);

select is(
  (
    select bool_and(procedure.prosecdef)
    from pg_proc as procedure
    where procedure.oid in (
      'public.submit_moderation_report(uuid,uuid,text,text,text,uuid,text,uuid)'::regprocedure,
      'public.list_own_moderation_reports(uuid,integer,timestamptz,uuid)'::regprocedure,
      'public.get_own_moderation_staff_access(uuid)'::regprocedure,
      'public.list_moderation_cases(uuid,text,integer,timestamptz,uuid)'::regprocedure,
      'public.get_moderation_case_detail(uuid,uuid)'::regprocedure,
      'public.add_moderation_case_note(uuid,uuid,text)'::regprocedure,
      'public.transition_moderation_case(uuid,uuid,bigint,text)'::regprocedure
    )
  ),
  true,
  'all moderation operations own their complete authorization boundary'
);

select is(
  (
    select bool_and(array_to_string(procedure.proconfig, ',') = 'search_path=""')
    from pg_proc as procedure
    where procedure.oid in (
      'public.submit_moderation_report(uuid,uuid,text,text,text,uuid,text,uuid)'::regprocedure,
      'public.list_own_moderation_reports(uuid,integer,timestamptz,uuid)'::regprocedure,
      'public.get_own_moderation_staff_access(uuid)'::regprocedure,
      'public.list_moderation_cases(uuid,text,integer,timestamptz,uuid)'::regprocedure,
      'public.get_moderation_case_detail(uuid,uuid)'::regprocedure,
      'public.add_moderation_case_note(uuid,uuid,text)'::regprocedure,
      'public.transition_moderation_case(uuid,uuid,bigint,text)'::regprocedure,
      'private.require_moderation_staff(uuid)'::regprocedure,
      'private.profile_has_project_association(uuid,uuid)'::regprocedure
    )
  ),
  true,
  'every privileged moderation function fixes an empty search path'
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
      'private.require_moderation_identity(uuid,boolean)'::regprocedure,
      'private.require_moderation_staff(uuid)'::regprocedure,
      'private.profile_has_project_association(uuid,uuid)'::regprocedure,
      'private.moderation_target_summary(private.moderation_cases)'::regprocedure,
      'private.moderation_context_summary(private.moderation_cases)'::regprocedure
    )
  ),
  false,
  'private moderation helpers are not callable by API roles'
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
      'public.submit_moderation_report(uuid,uuid,text,text,text,uuid,text,uuid)'::regprocedure,
      'public.list_own_moderation_reports(uuid,integer,timestamptz,uuid)'::regprocedure,
      'public.get_own_moderation_staff_access(uuid)'::regprocedure,
      'public.list_moderation_cases(uuid,text,integer,timestamptz,uuid)'::regprocedure,
      'public.get_moderation_case_detail(uuid,uuid)'::regprocedure,
      'public.add_moderation_case_note(uuid,uuid,text)'::regprocedure,
      'public.transition_moderation_case(uuid,uuid,bigint,text)'::regprocedure
    )
  ),
  true,
  'only authenticated clients can invoke the public moderation operations'
);

select ok(
  pg_get_function_arguments(
    'public.submit_moderation_report(uuid,uuid,text,text,text,uuid,text,uuid)'::regprocedure
  )::text not like '%subject%',
  'the client cannot supply a claimed report subject'
);

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'private.moderation_cases'::regclass
      and conname = 'moderation_cases_one_typed_target'
  ),
  'cases enforce exactly one typed target foreign key'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'private.moderation_reports'::regclass
      and conname = 'moderation_reports_reporter_submission_key'
  ),
  'report retries have a reporter-scoped idempotency key'
);
select ok(
  exists (
    select 1
    from pg_trigger
    where tgrelid = 'private.moderation_reports'::regclass
      and tgname = 'moderation_reports_append_only'
      and not tgisinternal
  ),
  'initial report evidence is append-preserved'
);
select ok(
  exists (
    select 1
    from pg_trigger
    where tgrelid = 'private.moderation_case_notes'::regclass
      and tgname = 'moderation_case_notes_append_only'
      and not tgisinternal
  ),
  'staff notes are append-preserved'
);

select * from finish();

rollback;
