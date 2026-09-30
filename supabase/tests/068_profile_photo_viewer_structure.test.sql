begin;

select no_plan();

select ok(
  to_regprocedure(
    'private.has_profile_photo_organizer_interaction(uuid,uuid)'
  ) is not null,
  'the directional organizer-interaction helper exists'
);
select ok(
  to_regprocedure('private.can_view_profile_photo(uuid,uuid)') is not null,
  'the canonical viewer authorization helper exists'
);
select ok(
  to_regprocedure('public.get_profile_photo_for_viewer(uuid)') is not null,
  'the exact viewer metadata RPC exists'
);
select ok(
  to_regprocedure('public.list_profile_photos_for_viewer(uuid[])') is not null,
  'the bounded batch viewer metadata RPC exists'
);

select is(
  (
    select bool_and(procedure.prosecdef)
    from pg_proc as procedure
    where procedure.oid in (
      'private.has_profile_photo_organizer_interaction(uuid,uuid)'::regprocedure,
      'private.can_view_profile_photo(uuid,uuid)'::regprocedure,
      'public.get_profile_photo_for_viewer(uuid)'::regprocedure,
      'public.list_profile_photos_for_viewer(uuid[])'::regprocedure
    )
  ),
  true,
  'viewer helpers and RPCs cross private RLS only as security definers'
);
select is(
  (
    select bool_and(array_to_string(procedure.proconfig, ',') = 'search_path=""')
    from pg_proc as procedure
    where procedure.oid in (
      'private.has_profile_photo_organizer_interaction(uuid,uuid)'::regprocedure,
      'private.can_view_profile_photo(uuid,uuid)'::regprocedure,
      'public.get_profile_photo_for_viewer(uuid)'::regprocedure,
      'public.list_profile_photos_for_viewer(uuid[])'::regprocedure
    )
  ),
  true,
  'every viewer helper and RPC fixes an empty search path'
);
select is(
  (
    select bool_and(procedure.provolatile = 's')
    from pg_proc as procedure
    where procedure.oid in (
      'private.has_profile_photo_organizer_interaction(uuid,uuid)'::regprocedure,
      'private.can_view_profile_photo(uuid,uuid)'::regprocedure,
      'public.get_profile_photo_for_viewer(uuid)'::regprocedure,
      'public.list_profile_photos_for_viewer(uuid[])'::regprocedure
    )
  ),
  true,
  'viewer authorization routines are stable reads'
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
      'private.has_profile_photo_organizer_interaction(uuid,uuid)'::regprocedure,
      'private.can_view_profile_photo(uuid,uuid)'::regprocedure
    )
  ),
  false,
  'private viewer helpers have no direct API-role execute grant'
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
      'public.get_profile_photo_for_viewer(uuid)'::regprocedure,
      'public.list_profile_photos_for_viewer(uuid[])'::regprocedure
    )
  ),
  true,
  'only anon and authenticated can execute the viewer RPC boundaries'
);

select is(
  pg_get_function_result(
    'public.get_profile_photo_for_viewer(uuid)'::regprocedure
  ),
  'TABLE(profile_id uuid, object_path text, updated_at timestamp with time zone)',
  'the exact viewer RPC returns only path identity and freshness metadata'
);
select is(
  pg_get_function_result(
    'public.list_profile_photos_for_viewer(uuid[])'::regprocedure
  ),
  'TABLE(profile_id uuid, object_path text, updated_at timestamp with time zone)',
  'the batch viewer RPC returns no audience or relationship reason'
);

select is(
  (
    select count(*)
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'Authorized viewers can read canonical profile photos'
      and cmd = 'SELECT'
      and roles = array['anon', 'authenticated']::name[]
  ),
  1::bigint,
  'one anon/authenticated read-only viewer policy protects profile photos'
);
select ok(
  (
    select qual
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'Authorized viewers can read canonical profile photos'
  ) like '%bucket_id = ''profile-photos''%'
    and (
      select qual
      from pg_policies
      where schemaname = 'storage'
        and tablename = 'objects'
        and policyname = 'Authorized viewers can read canonical profile photos'
    ) like '%allow_any_operation%'
    and (
      select qual
      from pg_policies
      where schemaname = 'storage'
        and tablename = 'objects'
        and policyname = 'Authorized viewers can read canonical profile photos'
    ) like '%get_profile_photo_for_viewer%'
    and (
      select qual
      from pg_policies
      where schemaname = 'storage'
        and tablename = 'objects'
        and policyname = 'Authorized viewers can read canonical profile photos'
    ) like '%visible.object_path = objects.name%'
  ,
  'Storage reads use exact-download operations and canonical viewer metadata'
);
select is(
  (
    select count(*)
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'Authorized viewers can read canonical profile photos'
      and cmd <> 'SELECT'
  ),
  0::bigint,
  'the viewer policy introduces no cross-user write or delete access'
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
  'viewer delivery adds no direct profile_photos table grants'
);

select ok(
  to_regprocedure('public.get_own_profile_photo(uuid)') is not null
    and to_regprocedure(
      'public.set_own_profile_photo(uuid,text,text)'
    ) is not null
    and to_regprocedure(
      'public.set_own_profile_photo_audience(uuid,text)'
    ) is not null
    and to_regprocedure('public.clear_own_profile_photo(uuid)') is not null,
  'all 08A1 owner RPC signatures remain unchanged'
);
select ok(
  to_regprocedure('public.get_public_profile(uuid)') is not null,
  'the scalar public-profile boundary remains separate and unchanged'
);

select * from finish();

rollback;
