begin;

select no_plan();

select ok(
  to_regprocedure(
    'private.has_resource_profile_photo_interaction(uuid,uuid)'
  ) is not null,
  'the private Scambio-Dona interaction helper exists'
);
select ok(
  to_regprocedure(
    'private.has_public_resource_listing_owner_photo_context(uuid)'
  ) is not null,
  'the public Resource listing owner-context helper exists'
);
select ok(
  to_regprocedure(
    'public.can_read_public_resource_listing_owner_photo_object(text)'
  ) is not null,
  'the Resource listing exact-object guard exists'
);
select ok(
  to_regprocedure(
    'public.get_resource_listing_owner_profile_photo_for_viewer(uuid)'
  ) is not null,
  'the exact Resource listing owner-photo RPC exists'
);

select is(
  (
    select bool_and(procedure.prosecdef)
    from pg_proc as procedure
    where procedure.oid in (
      'private.has_resource_profile_photo_interaction(uuid,uuid)'::regprocedure,
      'private.has_public_resource_listing_owner_photo_context(uuid)'::regprocedure,
      'public.can_read_public_resource_listing_owner_photo_object(text)'::regprocedure,
      'public.get_resource_listing_owner_profile_photo_for_viewer(uuid)'::regprocedure
    )
  ),
  true,
  'new trust helpers and delivery boundaries are security definer functions'
);
select is(
  (
    select bool_and(array_to_string(procedure.proconfig, ',') = 'search_path=""')
    from pg_proc as procedure
    where procedure.oid in (
      'private.has_resource_profile_photo_interaction(uuid,uuid)'::regprocedure,
      'private.has_public_resource_listing_owner_photo_context(uuid)'::regprocedure,
      'public.can_read_public_resource_listing_owner_photo_object(text)'::regprocedure,
      'public.get_resource_listing_owner_profile_photo_for_viewer(uuid)'::regprocedure,
      'public.publish_resource_listing(uuid,uuid)'::regprocedure,
      'public.request_resource_listing(uuid,uuid,text)'::regprocedure
    )
  ),
  true,
  'every new or replaced privileged function fixes an empty search path'
);
select is(
  (
    select bool_and(procedure.provolatile = 's')
    from pg_proc as procedure
    where procedure.oid in (
      'private.has_resource_profile_photo_interaction(uuid,uuid)'::regprocedure,
      'private.has_public_resource_listing_owner_photo_context(uuid)'::regprocedure,
      'public.can_read_public_resource_listing_owner_photo_object(text)'::regprocedure,
      'public.get_resource_listing_owner_profile_photo_for_viewer(uuid)'::regprocedure
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
      'private.has_resource_profile_photo_interaction(uuid,uuid)'::regprocedure,
      'private.has_public_resource_listing_owner_photo_context(uuid)'::regprocedure
    )
  ),
  false,
  'private Resource trust helpers have no direct API-role execute grant'
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
      'public.can_read_public_resource_listing_owner_photo_object(text)'::regprocedure,
      'public.get_resource_listing_owner_profile_photo_for_viewer(uuid)'::regprocedure
    )
  ),
  true,
  'only anon and authenticated can execute the exact Resource context boundaries'
);
select is(
  pg_get_function_result(
    'public.get_resource_listing_owner_profile_photo_for_viewer(uuid)'::regprocedure
  ),
  'TABLE(profile_id uuid, object_path text, updated_at timestamp with time zone)',
  'Resource listing context metadata returns no audience or authorization reason'
);

select is(
  (
    select count(*)
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname =
        'Public Resource listing context can read canonical owner photos'
      and cmd = 'SELECT'
      and roles = array['anon', 'authenticated']::name[]
  ),
  1::bigint,
  'one read-only context policy protects Resource owner-photo delivery'
);
select ok(
  (
    select qual
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname =
        'Public Resource listing context can read canonical owner photos'
  ) like '%bucket_id = ''profile-photos''%'
    and (
      select qual
      from pg_policies
      where schemaname = 'storage'
        and tablename = 'objects'
        and policyname =
          'Public Resource listing context can read canonical owner photos'
    ) like '%allow_any_operation%'
    and (
      select qual
      from pg_policies
      where schemaname = 'storage'
        and tablename = 'objects'
        and policyname =
          'Public Resource listing context can read canonical owner photos'
    ) like '%can_read_public_resource_listing_owner_photo_object%',
  'Resource context Storage reads are exact-operation and canonical-object guarded'
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
  '08A4B adds no direct profile_photos table grants'
);

select * from finish();

rollback;
