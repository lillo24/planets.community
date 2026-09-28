begin;

select no_plan();

select is(
  (select count(*) from storage.buckets where id = 'cover-images'),
  1::bigint,
  'the cover-images bucket exists exactly once'
);
select is(
  (select public from storage.buckets where id = 'cover-images'),
  false,
  'cover images remain in a private bucket'
);
select is(
  (select file_size_limit from storage.buckets where id = 'cover-images'),
  524288::bigint,
  'cover uploads are capped at 512 KiB'
);
select results_eq(
  $$select unnest(allowed_mime_types) from storage.buckets where id = 'cover-images'$$,
  $$values ('image/webp'::text)$$,
  'cover uploads accept only normalized WebP content'
);

select results_eq(
  $$
    select cmd
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname ilike '%cover%'
    order by cmd, policyname
  $$,
  $$values ('DELETE'::text), ('INSERT'::text), ('SELECT'::text), ('SELECT'::text)$$,
  'cover objects have immutable upload, exact read, and delete policies with no update policy'
);
select is(
  (
    select count(*)
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname ilike '%cover%'
      and coalesce(qual, with_check) not like '%bucket_id = ''cover-images''%'
  ),
  0::bigint,
  'every cover object policy is bucket-scoped'
);

select has_table('public', 'project_covers', 'Project canonical cover metadata exists');
select columns_are(
  'public',
  'project_covers',
  array['project_id', 'object_path', 'created_at', 'updated_at'],
  'Project cover metadata stores only identity, provider-independent path, and timestamps'
);
select col_is_pk('public', 'project_covers', 'project_id', 'one canonical cover exists per Project');
select col_is_unique('public', 'project_covers', 'object_path', 'a Project cover path is canonical for only one Project');
select fk_ok('public', 'project_covers', 'project_id', 'public', 'projects', 'id', 'Project covers reference the shared Project identity');
select is(
  (
    select confdeltype::text
    from pg_constraint
    where conrelid = 'public.project_covers'::regclass
      and conname = 'project_covers_project_id_fkey'
  ),
  'c'::text,
  'Project cover metadata cascades with its Project'
);
select ok(
  (
    select pg_get_constraintdef(oid)
    from pg_constraint
    where conrelid = 'public.project_covers'::regclass
      and conname = 'project_covers_object_path_valid'
  ) like '%/projects/%'
    and (
      select pg_get_constraintdef(oid)
      from pg_constraint
      where conrelid = 'public.project_covers'::regclass
        and conname = 'project_covers_object_path_valid'
    ) like '%.webp%',
  'Project canonical metadata enforces the immutable Project WebP path grammar'
);

select has_table('public', 'resource_listing_covers', 'Resource canonical cover metadata exists');
select columns_are(
  'public',
  'resource_listing_covers',
  array['listing_id', 'object_path', 'created_at', 'updated_at'],
  'Resource cover metadata stores only identity, provider-independent path, and timestamps'
);
select col_is_pk('public', 'resource_listing_covers', 'listing_id', 'one canonical cover exists per Resource listing');
select col_is_unique('public', 'resource_listing_covers', 'object_path', 'a Resource cover path is canonical for only one listing');
select fk_ok('public', 'resource_listing_covers', 'listing_id', 'public', 'resource_listings', 'id', 'Resource covers reference their listing');
select is(
  (
    select confdeltype::text
    from pg_constraint
    where conrelid = 'public.resource_listing_covers'::regclass
      and conname = 'resource_listing_covers_listing_id_fkey'
  ),
  'c'::text,
  'Resource cover metadata cascades with its listing'
);
select ok(
  (
    select pg_get_constraintdef(oid)
    from pg_constraint
    where conrelid = 'public.resource_listing_covers'::regclass
      and conname = 'resource_listing_covers_object_path_valid'
  ) like '%/resources/%'
    and (
      select pg_get_constraintdef(oid)
      from pg_constraint
      where conrelid = 'public.resource_listing_covers'::regclass
        and conname = 'resource_listing_covers_object_path_valid'
    ) like '%.webp%',
  'Resource canonical metadata enforces the immutable Resource WebP path grammar'
);

select is(
  (
    select count(*)
    from pg_class
    where oid in ('public.project_covers'::regclass, 'public.resource_listing_covers'::regclass)
      and relrowsecurity
  ),
  2::bigint,
  'both canonical metadata tables have RLS enabled'
);
select is(
  (
    select count(*)
    from pg_policies
    where schemaname = 'public'
      and tablename in ('project_covers', 'resource_listing_covers')
  ),
  0::bigint,
  'canonical metadata remains RPC-only with no direct row policies'
);
select is(
  (
    select bool_or(has_table_privilege(role_name, table_name, privilege_name))
    from unnest(array['anon', 'authenticated', 'service_role']) as roles(role_name)
    cross join unnest(array['public.project_covers', 'public.resource_listing_covers']) as tables(table_name)
    cross join unnest(array['SELECT', 'INSERT', 'UPDATE', 'DELETE']) as privileges(privilege_name)
  ),
  false,
  'API roles receive no direct canonical cover-table privileges'
);

select ok(to_regprocedure('public.get_own_project_cover(uuid,uuid)') is not null, 'the Project owner read RPC exists');
select ok(to_regprocedure('public.set_own_project_cover(uuid,uuid,text)') is not null, 'the Project canonical commit RPC exists');
select ok(to_regprocedure('public.clear_own_project_cover(uuid,uuid)') is not null, 'the Project clear RPC exists');
select ok(to_regprocedure('public.get_own_resource_listing_cover(uuid,uuid)') is not null, 'the Resource owner read RPC exists');
select ok(to_regprocedure('public.set_own_resource_listing_cover(uuid,uuid,text)') is not null, 'the Resource canonical commit RPC exists');
select ok(to_regprocedure('public.clear_own_resource_listing_cover(uuid,uuid)') is not null, 'the Resource clear RPC exists');
select is(
  (
    select bool_and(prosecdef and coalesce(proconfig, array[]::text[]) @> array['search_path=""'])
    from pg_proc
    where oid in (
      'public.get_own_project_cover(uuid,uuid)'::regprocedure,
      'public.set_own_project_cover(uuid,uuid,text)'::regprocedure,
      'public.clear_own_project_cover(uuid,uuid)'::regprocedure,
      'public.get_own_resource_listing_cover(uuid,uuid)'::regprocedure,
      'public.set_own_resource_listing_cover(uuid,uuid,text)'::regprocedure,
      'public.clear_own_resource_listing_cover(uuid,uuid)'::regprocedure
    )
  ),
  true,
  'all owner cover RPCs are security definers with a fixed empty search path'
);
select is(
  (
    select bool_and(has_function_privilege('authenticated', oid, 'EXECUTE'))
      and not bool_or(has_function_privilege('anon', oid, 'EXECUTE'))
    from pg_proc
    where oid in (
      'public.get_own_project_cover(uuid,uuid)'::regprocedure,
      'public.set_own_project_cover(uuid,uuid,text)'::regprocedure,
      'public.clear_own_project_cover(uuid,uuid)'::regprocedure,
      'public.get_own_resource_listing_cover(uuid,uuid)'::regprocedure,
      'public.set_own_resource_listing_cover(uuid,uuid,text)'::regprocedure,
      'public.clear_own_resource_listing_cover(uuid,uuid)'::regprocedure
    )
  ),
  true,
  'owner cover RPCs are authenticated-only'
);

select is(
  (
    select count(*)
    from pg_proc
    where oid in (
      'public.list_public_proposals(integer,timestamptz,uuid,text,uuid[])'::regprocedure,
      'public.get_public_proposal(uuid)'::regprocedure,
      'public.list_own_proposals(uuid)'::regprocedure,
      'public.get_own_proposal(uuid,uuid)'::regprocedure,
      'public.list_own_pending_requested_proposals(uuid,text,uuid[])'::regprocedure,
      'public.list_public_recurring_activities(timestamptz,integer,timestamptz,uuid,text)'::regprocedure,
      'public.get_public_recurring_activity(uuid,integer,timestamptz)'::regprocedure,
      'public.list_own_recurring_activities(uuid)'::regprocedure,
      'public.get_own_recurring_activity(uuid,uuid)'::regprocedure,
      'public.list_own_pending_requested_recurring_activities(uuid,timestamptz,text)'::regprocedure,
      'public.list_public_resource_listings(integer,timestamptz,uuid,text,text,text)'::regprocedure,
      'public.get_public_resource_listing(uuid)'::regprocedure,
      'public.list_own_resource_listings(uuid)'::regprocedure,
      'public.get_own_resource_listing(uuid,uuid)'::regprocedure,
      'public.list_project_resource_need_listing_matches(uuid,uuid,text,integer,text,text,text,timestamptz,uuid)'::regprocedure
    )
      and 'cover_object_path' = any(proargnames)
  ),
  15::bigint,
  'every canonical Proposal, Tavolo, Resource, pending-request, and match read exposes the nullable cover path'
);
select is(
  (
    select count(*)
    from information_schema.columns
    where table_schema = 'public'
      and table_name in ('project_covers', 'resource_listing_covers')
      and column_name ilike '%url%'
  ),
  0::bigint,
  'canonical cover metadata contains no provider URL column'
);

select * from finish();
rollback;
