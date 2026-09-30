begin;

select no_plan();

select ok(
  to_regprocedure('private.has_current_profile_photo(uuid)') is not null,
  'the canonical-photo presence helper exists'
);
select ok(
  to_regprocedure('private.is_project_publicly_viewable(uuid)') is not null,
  'the canonical Project public-detail visibility helper exists'
);
select ok(
  to_regprocedure(
    'private.has_public_project_creator_photo_context(uuid)'
  ) is not null,
  'the public Project creator-context helper exists'
);
select ok(
  to_regprocedure(
    'public.can_read_public_project_creator_photo_object(text)'
  ) is not null,
  'the exact Storage operation guard exists'
);
select ok(
  to_regprocedure(
    'public.get_project_creator_profile_photo_for_viewer(uuid)'
  ) is not null,
  'the exact Project-context organizer-photo RPC exists'
);

select is(
  (
    select bool_and(procedure.prosecdef)
    from pg_proc as procedure
    where procedure.oid in (
      'private.has_current_profile_photo(uuid)'::regprocedure,
      'private.is_project_publicly_viewable(uuid)'::regprocedure,
      'private.has_public_project_creator_photo_context(uuid)'::regprocedure,
      'public.can_read_public_project_creator_photo_object(text)'::regprocedure,
      'public.get_project_creator_profile_photo_for_viewer(uuid)'::regprocedure
    )
  ),
  true,
  'trust helpers and public boundaries use security definer only for canonical private reads'
);
select is(
  (
    select bool_and(array_to_string(procedure.proconfig, ',') = 'search_path=""')
    from pg_proc as procedure
    where procedure.oid in (
      'private.has_current_profile_photo(uuid)'::regprocedure,
      'private.is_project_publicly_viewable(uuid)'::regprocedure,
      'private.has_public_project_creator_photo_context(uuid)'::regprocedure,
      'public.can_read_public_project_creator_photo_object(text)'::regprocedure,
      'public.get_project_creator_profile_photo_for_viewer(uuid)'::regprocedure,
      'public.publish_proposal(uuid,uuid)'::regprocedure,
      'public.publish_recurring_activity(uuid,uuid)'::regprocedure,
      'public.request_to_join_project(uuid,uuid,text,uuid[],uuid[])'::regprocedure
    )
  ),
  true,
  'every modified privileged function fixes an empty search path'
);
select is(
  (
    select bool_and(procedure.provolatile = 's')
    from pg_proc as procedure
    where procedure.oid in (
      'private.has_current_profile_photo(uuid)'::regprocedure,
      'private.is_project_publicly_viewable(uuid)'::regprocedure,
      'private.has_public_project_creator_photo_context(uuid)'::regprocedure,
      'public.can_read_public_project_creator_photo_object(text)'::regprocedure,
      'public.get_project_creator_profile_photo_for_viewer(uuid)'::regprocedure
    )
  ),
  true,
  'all new authorization reads are stable'
);

select is(
  (
    select bool_or(
      has_function_privilege(role_name, procedure.oid, 'EXECUTE')
    )
    from pg_proc as procedure
    cross join unnest(
      array['anon', 'authenticated', 'service_role']
    ) as roles(role_name)
    where procedure.oid in (
      'private.has_current_profile_photo(uuid)'::regprocedure,
      'private.is_project_publicly_viewable(uuid)'::regprocedure,
      'private.has_public_project_creator_photo_context(uuid)'::regprocedure
    )
  ),
  false,
  'private trust helpers have no direct API-role execute grant'
);
select is(
  (
    select bool_and(
      has_function_privilege('anon', procedure.oid, 'EXECUTE')
      and has_function_privilege('authenticated', procedure.oid, 'EXECUTE')
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
      'public.can_read_public_project_creator_photo_object(text)'::regprocedure,
      'public.get_project_creator_profile_photo_for_viewer(uuid)'::regprocedure
    )
  ),
  true,
  'only anon and authenticated can execute the exact context delivery boundaries'
);
select is(
  pg_get_function_result(
    'public.get_project_creator_profile_photo_for_viewer(uuid)'::regprocedure
  ),
  'TABLE(profile_id uuid, object_path text, updated_at timestamp with time zone)',
  'Project-context metadata returns no audience or authorization reason'
);

select is(
  (
    select count(*)
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname =
        'Public Project context can read canonical organizer photos'
      and cmd = 'SELECT'
      and roles = array['anon', 'authenticated']::name[]
  ),
  1::bigint,
  'one read-only context policy protects organizer-photo delivery'
);
select ok(
  (
    select qual
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname =
        'Public Project context can read canonical organizer photos'
  ) like '%bucket_id = ''profile-photos''%'
    and (
      select qual
      from pg_policies
      where schemaname = 'storage'
        and tablename = 'objects'
        and policyname =
          'Public Project context can read canonical organizer photos'
    ) like '%allow_any_operation%'
    and (
      select qual
      from pg_policies
      where schemaname = 'storage'
        and tablename = 'objects'
        and policyname =
          'Public Project context can read canonical organizer photos'
    ) like '%can_read_public_project_creator_photo_object%'
  ,
  'context Storage reads remain exact-operation and canonical-object guarded'
);

select is(
  (
    select bool_or(
      has_table_privilege(role_name, 'public.profile_photos', privilege_name)
    )
    from unnest(array['anon', 'authenticated', 'service_role'])
      as roles(role_name)
    cross join unnest(array['SELECT', 'INSERT', 'UPDATE', 'DELETE'])
      as privileges(privilege_name)
  ),
  false,
  '08A4A adds no direct profile_photos table grants'
);
select ok(
  to_regprocedure('public.get_profile_photo_for_viewer(uuid)') is not null
    and to_regprocedure(
      'public.list_profile_photos_for_viewer(uuid[])'
    ) is not null,
  'the generic 08A3 exact and batch viewer boundaries remain separate'
);

select * from finish();

rollback;
