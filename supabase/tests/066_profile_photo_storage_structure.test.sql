begin;

select no_plan();

select is(
  (
    select count(*)
    from storage.buckets
    where id = 'profile-photos'
      and name = 'profile-photos'
  ),
  1::bigint,
  'the purpose-specific profile-photos bucket exists exactly once'
);
select is(
  (select public from storage.buckets where id = 'profile-photos'),
  false,
  'the profile-photo bucket is private'
);
select is(
  (select file_size_limit from storage.buckets where id = 'profile-photos'),
  256000::bigint,
  'the bucket hard-limits uploads to 250 KiB'
);
select results_eq(
  $$
    select unnest(allowed_mime_types)
    from storage.buckets
    where id = 'profile-photos'
  $$,
  $$values ('image/webp'::text)$$,
  'the bucket accepts only WebP content'
);

select is(
  (
    select count(*)
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname like 'Profile photo owners can %'
  ),
  3::bigint,
  'profile photos have exactly three owner object policies'
);
select results_eq(
  $$
    select cmd
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname like 'Profile photo owners can %'
    order by cmd
  $$,
  $$values ('DELETE'::text), ('INSERT'::text), ('SELECT'::text)$$,
  'owners receive insert, select, and delete policies but no update policy'
);
select is(
  (
    select count(*)
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname like 'Profile photo owners can %'
      and roles <> array['authenticated']::name[]
  ),
  0::bigint,
  'every profile-photo object policy is authenticated-only'
);
select is(
  (
    select count(*)
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname like 'Profile photo owners can %'
      and coalesce(qual, with_check) not like '%bucket_id = ''profile-photos''%'
  ),
  0::bigint,
  'every object policy is restricted to the profile-photos bucket'
);
select is(
  (
    select count(*)
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname like 'Profile photo owners can %'
      and (
        coalesce(qual, with_check) not like '%owner_id%auth.uid()%'
        or coalesce(qual, with_check) not like '%storage.foldername(name)%'
        or coalesce(qual, with_check) not like '%storage.filename(name)%'
        or coalesce(qual, with_check) not like '%.webp%'
      )
  ),
  0::bigint,
  'every object policy binds current ownership and the exact versioned WebP path shape'
);

select has_table(
  'public',
  'profile_photos',
  'canonical profile-photo metadata exists'
);
select columns_are(
  'public',
  'profile_photos',
  array['profile_id', 'object_path', 'audience', 'created_at', 'updated_at'],
  'profile-photo metadata contains no URL, bytes, provider, or original-photo field'
);
select col_is_pk(
  'public',
  'profile_photos',
  'profile_id',
  'one canonical photo row is enforced per profile'
);
select col_is_unique(
  'public',
  'profile_photos',
  'object_path',
  'one canonical row can reference an object path'
);
select fk_ok(
  'public',
  'profile_photos',
  'profile_id',
  'public',
  'profiles',
  'id',
  'profile photos reference the profile anchor'
);
select is(
  (
    select confdeltype::text
    from pg_constraint
    where conrelid = 'public.profile_photos'::regclass
      and conname = 'profile_photos_profile_id_fkey'
  ),
  'c'::text,
  'profile-photo metadata cascades when its profile row is deleted'
);
select ok(
  (
    select pg_get_constraintdef(oid)
    from pg_constraint
    where conrelid = 'public.profile_photos'::regclass
      and conname = 'profile_photos_object_path_valid'
  ) like '%profile_id%'
    and (
      select pg_get_constraintdef(oid)
      from pg_constraint
      where conrelid = 'public.profile_photos'::regclass
        and conname = 'profile_photos_object_path_valid'
    ) like '%.webp%',
  'canonical metadata enforces the profile-prefixed immutable WebP path grammar'
);
select ok(
  (
    select pg_get_constraintdef(oid)
    from pg_constraint
    where conrelid = 'public.profile_photos'::regclass
      and conname = 'profile_photos_audience_valid'
  ) like '%public%'
    and (
      select pg_get_constraintdef(oid)
      from pg_constraint
      where conrelid = 'public.profile_photos'::regclass
        and conname = 'profile_photos_audience_valid'
    ) like '%interactions%',
  'photo audience is constrained to public or interactions'
);
select is(
  (
    select pg_get_expr(default_value.adbin, default_value.adrelid)
    from pg_attrdef as default_value
    join pg_attribute as attribute
      on attribute.attrelid = default_value.adrelid
      and attribute.attnum = default_value.adnum
    where default_value.adrelid = 'public.profile_photos'::regclass
      and attribute.attname = 'audience'
  ),
  '''interactions''::text',
  'interactions is the privacy-preserving default audience'
);
select col_type_is(
  'public',
  'profile_photos',
  'created_at',
  'timestamp with time zone',
  'photo creation time is timezone-aware'
);
select col_type_is(
  'public',
  'profile_photos',
  'updated_at',
  'timestamp with time zone',
  'photo update time is timezone-aware'
);
select ok(
  exists (
    select 1
    from pg_trigger
    where tgrelid = 'public.profile_photos'::regclass
      and tgname = 'profile_photos_set_updated_at'
      and not tgisinternal
  ),
  'canonical photo changes maintain updated_at through a trigger'
);
select is(
  (
    select relrowsecurity
    from pg_class
    where oid = 'public.profile_photos'::regclass
  ),
  true,
  'profile-photo metadata has RLS enabled'
);
select is(
  (
    select count(*)
    from pg_policies
    where schemaname = 'public'
      and tablename = 'profile_photos'
  ),
  0::bigint,
  'profile-photo metadata is RPC-only with no direct row policy'
);
select is(
  (
    select bool_or(
      has_table_privilege(role_name, 'public.profile_photos', privilege_name)
    )
    from unnest(array['anon', 'authenticated', 'service_role']) as roles(role_name)
    cross join unnest(array['SELECT', 'INSERT', 'UPDATE', 'DELETE'])
      as privileges(privilege_name)
  ),
  false,
  'API roles receive no direct profile-photo table privileges'
);

select ok(
  to_regprocedure('public.get_own_profile_photo(uuid)') is not null,
  'the owner photo read RPC exists'
);
select ok(
  to_regprocedure('public.set_own_profile_photo(uuid,text,text)') is not null,
  'the canonical set/replace RPC exists'
);
select ok(
  to_regprocedure('public.set_own_profile_photo_audience(uuid,text)') is not null,
  'the audience-only RPC exists'
);
select ok(
  to_regprocedure('public.clear_own_profile_photo(uuid)') is not null,
  'the clear-photo RPC exists'
);
select is(
  (
    select bool_and(procedure.prosecdef)
    from pg_proc as procedure
    where procedure.oid in (
      'private.require_profile_photo_identity(uuid)'::regprocedure,
      'public.get_own_profile_photo(uuid)'::regprocedure,
      'public.set_own_profile_photo(uuid,text,text)'::regprocedure,
      'public.set_own_profile_photo_audience(uuid,text)'::regprocedure,
      'public.clear_own_profile_photo(uuid)'::regprocedure
    )
  ),
  true,
  'owner RPC boundaries are security definers'
);
select is(
  (
    select bool_and(array_to_string(procedure.proconfig, ',') = 'search_path=""')
    from pg_proc as procedure
    where procedure.oid in (
      'private.is_profile_photo_object_path_for_profile(text,uuid)'::regprocedure,
      'private.require_profile_photo_identity(uuid)'::regprocedure,
      'private.set_profile_photo_updated_at()'::regprocedure,
      'public.get_own_profile_photo(uuid)'::regprocedure,
      'public.set_own_profile_photo(uuid,text,text)'::regprocedure,
      'public.set_own_profile_photo_audience(uuid,text)'::regprocedure,
      'public.clear_own_profile_photo(uuid)'::regprocedure
    )
  ),
  true,
  'every profile-photo helper and RPC fixes an empty search path'
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
      'public.get_own_profile_photo(uuid)'::regprocedure,
      'public.set_own_profile_photo(uuid,text,text)'::regprocedure,
      'public.set_own_profile_photo_audience(uuid,text)'::regprocedure,
      'public.clear_own_profile_photo(uuid)'::regprocedure
    )
  ),
  true,
  'photo RPC execution is authenticated-only with no PUBLIC or service convenience grant'
);
select is(
  (
    select count(*)
    from pg_proc as procedure
    join pg_namespace as namespace on namespace.oid = procedure.pronamespace
    where namespace.nspname = 'public'
      and procedure.proname like '%profile%photo%'
      and has_function_privilege('anon', procedure.oid, 'EXECUTE')
  ),
  0::bigint,
  '08A1 exposes no anonymous profile-photo read routine'
);

select ok(
  (
    select pg_get_constraintdef(oid)
    from pg_constraint
    where conrelid = 'public.profile_field_visibility'::regclass
      and conname = 'profile_field_visibility_field_key_valid'
  ) not like '%photo%'
    and (
      select pg_get_constraintdef(oid)
      from pg_constraint
      where conrelid = 'public.profile_field_visibility'::regclass
        and conname = 'profile_field_visibility_audience_valid'
    ) not like '%interactions%',
  'the existing three-field public/private visibility contract is unchanged'
);
select ok(
  to_regprocedure(
    'public.update_own_profile(uuid,text,text,uuid[],text,text,text)'
  ) is not null
    and to_regprocedure('public.get_public_profile(uuid)') is not null,
  'existing profile API signatures remain compatible'
);

select * from finish();

rollback;
