begin;

select plan(12);

select has_schema('private', 'private schema exists');

select is(
  has_schema_privilege('anon', 'private', 'USAGE'),
  false,
  'anon cannot use the private schema'
);

select is(
  has_schema_privilege('authenticated', 'private', 'USAGE'),
  false,
  'authenticated cannot use the private schema'
);

select is(
  has_schema_privilege('service_role', 'private', 'USAGE'),
  true,
  'service_role can resolve explicitly granted private worker routines'
);

select is(
  has_schema_privilege('anon', 'private', 'CREATE'),
  false,
  'anon cannot create objects in the private schema'
);

select is(
  has_schema_privilege('authenticated', 'private', 'CREATE'),
  false,
  'authenticated cannot create objects in the private schema'
);

select is(
  has_schema_privilege('service_role', 'private', 'CREATE'),
  false,
  'service_role cannot create objects in the private schema'
);

select ok(
  exists (select 1 from pg_extension where extname = 'postgis'),
  'PostGIS is installed'
);

select is(
  (
    select n.nspname::text
    from pg_extension as e
    join pg_namespace as n on n.oid = e.extnamespace
    where e.extname = 'postgis'
  ),
  'extensions',
  'PostGIS is installed outside the public API schema'
);

select has_type('extensions', 'geometry', 'PostGIS geometry type is available in extensions');

select is(
  extensions.st_astext(extensions.st_point(12.5, 41.9)),
  'POINT(12.5 41.9)',
  'a basic PostGIS geometry operation works'
);

select is(
  (
    select count(*)
    from pg_class as c
    join pg_namespace as n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind in ('r', 'p')
      and not c.relrowsecurity
      and not exists (
        select 1
        from pg_depend as d
        where d.classid = 'pg_class'::regclass
          and d.objid = c.oid
          and d.deptype = 'e'
      )
  ),
  0::bigint,
  'every ordinary PLANETS table in public has row-level security enabled'
);

select diag('PostGIS library version: ' || extensions.postgis_lib_version());

select * from finish();

rollback;
