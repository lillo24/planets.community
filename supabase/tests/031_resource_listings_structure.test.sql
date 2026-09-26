begin;

select no_plan();

select has_table(
  'public',
  'resource_listings',
  'standalone Scambio-Dona resource listings exist'
);

select columns_are(
  'public',
  'resource_listings',
  array[
    'id',
    'owner_profile_id',
    'listing_mode',
    'lifecycle_state',
    'title',
    'description',
    'country_code',
    'locality',
    'administrative_area',
    'public_location_label',
    'created_at',
    'updated_at',
    'published_at',
    'closed_at'
  ],
  'listing rows contain only owner, discovery intent, lifecycle, content, and rough location'
);

select col_is_pk(
  'public',
  'resource_listings',
  'id',
  'resource listing IDs are primary keys'
);
select col_type_is(
  'public',
  'resource_listings',
  'id',
  'uuid',
  'resource listing IDs are UUIDs'
);
select col_type_is(
  'public',
  'resource_listings',
  'created_at',
  'timestamp with time zone',
  'resource listing creation time is timezone-aware'
);
select col_type_is(
  'public',
  'resource_listings',
  'published_at',
  'timestamp with time zone',
  'resource listing publication time is timezone-aware'
);
select col_type_is(
  'public',
  'resource_listings',
  'closed_at',
  'timestamp with time zone',
  'resource listing closure time is timezone-aware'
);

select ok(
  exists (
    select 1
    from pg_constraint as constraint_row
    where constraint_row.conrelid = 'public.resource_listings'::regclass
      and constraint_row.contype = 'f'
      and constraint_row.confrelid = 'public.profiles'::regclass
      and constraint_row.conname = 'resource_listings_owner_profile_id_fkey'
      and constraint_row.confdeltype = 'r'
  ),
  'listing owners use a restrictive profile foreign key'
);

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.resource_listings'::regclass
      and conname = 'resource_listings_listing_mode_valid'
      and contype = 'c'
      and pg_get_constraintdef(oid) like '%donate%'
      and pg_get_constraintdef(oid) like '%exchange%'
  ),
  'listing modes are constrained to the two discovery intents'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.resource_listings'::regclass
      and conname = 'resource_listings_lifecycle_state_valid'
      and contype = 'c'
      and pg_get_constraintdef(oid) like '%draft%'
      and pg_get_constraintdef(oid) like '%published%'
      and pg_get_constraintdef(oid) like '%closed%'
  ),
  'listing lifecycle is constrained to draft, published, and closed'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.resource_listings'::regclass
      and conname = 'resource_listings_lifecycle_timestamps_valid'
      and contype = 'c'
  ),
  'listing lifecycle timestamps are constrained'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.resource_listings'::regclass
      and conname = 'resource_listings_title_valid'
      and contype = 'c'
      and pg_get_constraintdef(oid) like '%char_length(title)%2%120%'
  ),
  'listing titles are canonical and bounded'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.resource_listings'::regclass
      and conname = 'resource_listings_description_valid'
      and contype = 'c'
      and pg_get_constraintdef(oid) like '%char_length(description)%1%5000%'
  ),
  'listing descriptions are canonical and bounded'
);
select ok(
  (
    select count(*) = 4
    from pg_constraint
    where conrelid = 'public.resource_listings'::regclass
      and conname in (
        'resource_listings_country_code_valid',
        'resource_listings_locality_valid',
        'resource_listings_administrative_area_valid',
        'resource_listings_public_location_label_valid'
      )
      and contype = 'c'
  ),
  'rough public location values are canonical and bounded'
);

select is(
  (
    select relrowsecurity
    from pg_class
    where oid = 'public.resource_listings'::regclass
  ),
  true,
  'resource listings have RLS enabled'
);
select is(
  (
    select count(*)
    from pg_policies
    where schemaname = 'public'
      and tablename = 'resource_listings'
  ),
  0::bigint,
  'resource listings expose no direct row policies'
);
select is(
  (
    select bool_or(
      has_table_privilege(role_name, 'public.resource_listings', privilege_name)
    )
    from unnest(array['anon', 'authenticated', 'service_role']) as roles(role_name)
    cross join unnest(array['SELECT', 'INSERT', 'UPDATE', 'DELETE']) as privileges(privilege_name)
  ),
  false,
  'client and service roles receive no direct listing-table privileges'
);

select ok(
  to_regclass('public.resource_listings_owner_created_at_id_idx') is not null,
  'owner history has a supporting foreign-key and newest-first index'
);
select ok(
  to_regclass('public.resource_listings_published_at_id_idx') is not null,
  'public listing order has a partial keyset index'
);
select ok(
  to_regclass('public.resource_listings_published_mode_at_id_idx') is not null,
  'published mode filtering has a partial keyset index'
);
select ok(
  to_regclass('public.resource_listings_published_locality_at_id_idx') is not null,
  'case-insensitive published locality filtering has a partial keyset index'
);
select is(
  (
    select lower(pg_get_expr(index_row.indpred, index_row.indrelid))
    from pg_index as index_row
    where index_row.indexrelid =
      'public.resource_listings_published_at_id_idx'::regclass
  ),
  '(lifecycle_state = ''published''::text)',
  'the public keyset index contains only published listings'
);

select ok(
  to_regprocedure('public.create_resource_listing_draft(uuid,text,text,text,text,text,text,text)') is not null,
  'the listing draft operation exists'
);
select ok(
  to_regprocedure('public.update_own_resource_listing(uuid,uuid,text,text,text,text,text,text,text)') is not null,
  'the atomic own-listing update operation exists'
);
select ok(
  to_regprocedure('public.publish_resource_listing(uuid,uuid)') is not null,
  'the listing publish operation exists'
);
select ok(
  to_regprocedure('public.close_resource_listing(uuid,uuid)') is not null,
  'the terminal listing close operation exists'
);
select ok(
  to_regprocedure('public.list_own_resource_listings(uuid)') is not null,
  'the owner listing-history operation exists'
);
select ok(
  to_regprocedure('public.get_own_resource_listing(uuid,uuid)') is not null,
  'the exact owner listing operation exists'
);
select ok(
  to_regprocedure('public.list_public_resource_listings(integer,timestamptz,uuid,text,text,text)') is not null,
  'the sanitized public listing operation exists'
);
select ok(
  to_regprocedure('public.get_public_resource_listing(uuid)') is not null,
  'the sanitized public listing detail operation exists'
);
select ok(
  to_regprocedure('public.delete_resource_listing(uuid,uuid)') is null,
  '04C1 exposes no hard-delete operation'
);

select is(
  (
    select bool_and(prosecdef)
    from pg_proc
    where oid in (
      'public.create_resource_listing_draft(uuid,text,text,text,text,text,text,text)'::regprocedure,
      'public.update_own_resource_listing(uuid,uuid,text,text,text,text,text,text,text)'::regprocedure,
      'public.publish_resource_listing(uuid,uuid)'::regprocedure,
      'public.close_resource_listing(uuid,uuid)'::regprocedure,
      'public.list_own_resource_listings(uuid)'::regprocedure,
      'public.get_own_resource_listing(uuid,uuid)'::regprocedure,
      'public.list_public_resource_listings(integer,timestamptz,uuid,text,text,text)'::regprocedure,
      'public.get_public_resource_listing(uuid)'::regprocedure
    )
  ),
  true,
  'listing APIs deliberately use hardened security-definer boundaries'
);
select is(
  (
    select bool_and(array_to_string(proconfig, ',') = 'search_path=""')
    from pg_proc
    where oid in (
      'public.create_resource_listing_draft(uuid,text,text,text,text,text,text,text)'::regprocedure,
      'public.update_own_resource_listing(uuid,uuid,text,text,text,text,text,text,text)'::regprocedure,
      'public.publish_resource_listing(uuid,uuid)'::regprocedure,
      'public.close_resource_listing(uuid,uuid)'::regprocedure,
      'public.list_own_resource_listings(uuid)'::regprocedure,
      'public.get_own_resource_listing(uuid,uuid)'::regprocedure,
      'public.list_public_resource_listings(integer,timestamptz,uuid,text,text,text)'::regprocedure,
      'public.get_public_resource_listing(uuid)'::regprocedure
    )
  ),
  true,
  'every listing API has an empty fixed search path'
);

select is(
  has_function_privilege(
    'anon',
    'public.list_public_resource_listings(integer,timestamptz,uuid,text,text,text)',
    'EXECUTE'
  ),
  true,
  'anonymous users can call public listing discovery'
);
select is(
  has_function_privilege(
    'authenticated',
    'public.get_public_resource_listing(uuid)',
    'EXECUTE'
  ),
  true,
  'authenticated users can call public listing detail'
);
select is(
  has_function_privilege(
    'anon',
    'public.create_resource_listing_draft(uuid,text,text,text,text,text,text,text)',
    'EXECUTE'
  ),
  false,
  'anonymous users cannot create listing drafts'
);
select is(
  has_function_privilege(
    'authenticated',
    'public.create_resource_listing_draft(uuid,text,text,text,text,text,text,text)',
    'EXECUTE'
  ),
  true,
  'authenticated users can create listing drafts'
);
select is(
  has_function_privilege(
    'service_role',
    'public.get_public_resource_listing(uuid)',
    'EXECUTE'
  ),
  false,
  'service role receives no convenience listing API grant'
);

select is(
  to_regclass('public.resource_listing_requests'),
  'public.resource_listing_requests'::regclass,
  'later request workflow state stays in its dedicated table'
);
select is(to_regclass('public.resource_transactions'), null, 'no resource transaction table exists');
select is(to_regclass('public.resource_listing_media'), null, 'no listing media table exists');
select is(to_regclass('public.project_resource_listings'), null, 'no Project-listing linkage table exists');
select is(
  (
    select count(*)
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'resource_listings'
      and column_name in (
        'project_id',
        'requester_profile_id',
        'recipient_profile_id',
        'price',
        'quantity',
        'return_due_at',
        'handoff_address',
        'image_url',
        'category_id'
      )
  ),
  0::bigint,
  'listing rows contain no transaction, Project, taxonomy, media, price, stock, return, or exact-handoff fields'
);

select * from finish();

rollback;
