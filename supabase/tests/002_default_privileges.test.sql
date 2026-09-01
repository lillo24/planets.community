begin;

select plan(14);

create table public.planets_security_probe (
  id bigint generated always as identity primary key
);

create sequence public.planets_security_probe_sequence;

create function public.planets_security_probe_function()
returns integer
language sql
immutable
as $$
  select 1
$$;

select is(current_user, 'postgres', 'security probes use the future migration creator role');

select is(
  (
    select pg_get_userbyid(c.relowner)
    from pg_class as c
    where c.oid = 'public.planets_security_probe'::regclass
  ),
  'postgres',
  'probe table is owned by the migration creator'
);

select is(
  (
    select pg_get_userbyid(c.relowner)
    from pg_class as c
    where c.oid = 'public.planets_security_probe_sequence'::regclass
  ),
  'postgres',
  'probe sequence is owned by the migration creator'
);

select is(
  (
    select pg_get_userbyid(p.proowner)
    from pg_proc as p
    where p.oid = 'public.planets_security_probe_function()'::regprocedure
  ),
  'postgres',
  'probe function is owned by the migration creator'
);

select is(
  (
    select bool_or(
      has_table_privilege('anon', 'public.planets_security_probe', privilege_name)
    )
    from unnest(
      array['SELECT', 'INSERT', 'UPDATE', 'DELETE', 'TRUNCATE', 'REFERENCES', 'TRIGGER', 'MAINTAIN']
    ) as privileges(privilege_name)
  ),
  false,
  'anon receives no implicit privilege on a new public table'
);

select is(
  (
    select bool_or(
      has_table_privilege('authenticated', 'public.planets_security_probe', privilege_name)
    )
    from unnest(
      array['SELECT', 'INSERT', 'UPDATE', 'DELETE', 'TRUNCATE', 'REFERENCES', 'TRIGGER', 'MAINTAIN']
    ) as privileges(privilege_name)
  ),
  false,
  'authenticated receives no implicit privilege on a new public table'
);

select is(
  (
    select bool_or(
      has_table_privilege('service_role', 'public.planets_security_probe', privilege_name)
    )
    from unnest(
      array['SELECT', 'INSERT', 'UPDATE', 'DELETE', 'TRUNCATE', 'REFERENCES', 'TRIGGER', 'MAINTAIN']
    ) as privileges(privilege_name)
  ),
  false,
  'service_role receives no implicit privilege on a new public table'
);

select is(
  (
    select bool_or(
      has_sequence_privilege('anon', 'public.planets_security_probe_sequence', privilege_name)
    )
    from unnest(array['USAGE', 'SELECT', 'UPDATE']) as privileges(privilege_name)
  ),
  false,
  'anon receives no implicit privilege on a new public sequence'
);

select is(
  (
    select bool_or(
      has_sequence_privilege(
        'authenticated',
        'public.planets_security_probe_sequence',
        privilege_name
      )
    )
    from unnest(array['USAGE', 'SELECT', 'UPDATE']) as privileges(privilege_name)
  ),
  false,
  'authenticated receives no implicit privilege on a new public sequence'
);

select is(
  (
    select bool_or(
      has_sequence_privilege(
        'service_role',
        'public.planets_security_probe_sequence',
        privilege_name
      )
    )
    from unnest(array['USAGE', 'SELECT', 'UPDATE']) as privileges(privilege_name)
  ),
  false,
  'service_role receives no implicit privilege on a new public sequence'
);

select is(
  has_function_privilege('anon', 'public.planets_security_probe_function()', 'EXECUTE'),
  false,
  'anon cannot execute a new public function through direct or PUBLIC privileges'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.planets_security_probe_function()',
    'EXECUTE'
  ),
  false,
  'authenticated cannot execute a new public function through direct or PUBLIC privileges'
);

select is(
  has_function_privilege(
    'service_role',
    'public.planets_security_probe_function()',
    'EXECUTE'
  ),
  false,
  'service_role cannot execute a new public function through direct or PUBLIC privileges'
);

select is(
  (
    select exists (
      select 1
      from aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) as acl
      where acl.grantee = 0
        and acl.privilege_type = 'EXECUTE'
    )
    from pg_proc as p
    where p.oid = 'public.planets_security_probe_function()'::regprocedure
  ),
  false,
  'PostgreSQL PUBLIC receives no default EXECUTE privilege on a new function'
);

select * from finish();

rollback;
