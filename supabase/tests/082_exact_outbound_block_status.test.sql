begin;

select no_plan();

insert into auth.users (id, email)
values
  ('b9200000-0000-4000-8000-000000000001', 'blocking-status-a@planets.invalid'),
  ('b9200000-0000-4000-8000-000000000002', 'blocking-status-b@planets.invalid'),
  ('b9200000-0000-4000-8000-000000000003', 'blocking-status-c@planets.invalid');

insert into public.profiles (id, display_name)
values
  ('b9200000-0000-4000-8000-000000000001', 'Status A'),
  ('b9200000-0000-4000-8000-000000000002', 'Status B'),
  ('b9200000-0000-4000-8000-000000000003', 'Status C');

select ok(
  to_regprocedure('public.get_own_blocked_profile_status(uuid,uuid)') is not null,
  'the exact outbound-only status RPC exists'
);

select is(
  (
    select procedure.prosecdef
      and array_to_string(procedure.proconfig, ',') = 'search_path=""'
    from pg_proc as procedure
    where procedure.oid =
      'public.get_own_blocked_profile_status(uuid,uuid)'::regprocedure
  ),
  true,
  'the status RPC is a hardened security definer'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.get_own_blocked_profile_status(uuid,uuid)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'anon',
    'public.get_own_blocked_profile_status(uuid,uuid)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'service_role',
    'public.get_own_blocked_profile_status(uuid,uuid)',
    'EXECUTE'
  ),
  true,
  'only authenticated clients may call the exact status RPC'
);

select ok(
  pg_get_function_result(
    'public.get_own_blocked_profile_status(uuid,uuid)'::regprocedure
  )::text like '%blocked_profile_id%'
  and pg_get_function_result(
    'public.get_own_blocked_profile_status(uuid,uuid)'::regprocedure
  )::text not like '%blocker_profile_id%'
  and pg_get_function_result(
    'public.get_own_blocked_profile_status(uuid,uuid)'::regprocedure
  )::text not like '%inbound%'
  and pg_get_function_result(
    'public.get_own_blocked_profile_status(uuid,uuid)'::regprocedure
  )::text not like '%reciprocal%',
  'the return contract contains only safe outbound fields'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'b9200000-0000-4000-8000-000000000002',
  true
);
select public.block_user(
  'b9200000-0000-4000-8000-000000000002',
  'b9200000-0000-4000-8000-000000000001'
);

select set_config(
  'request.jwt.claim.sub',
  'b9200000-0000-4000-8000-000000000001',
  true
);
select is(
  (
    select count(*)
    from public.get_own_blocked_profile_status(
      'b9200000-0000-4000-8000-000000000001',
      'b9200000-0000-4000-8000-000000000002'
    )
  ),
  0::bigint,
  'an inbound-only block is indistinguishable from no outbound block'
);

select public.block_user(
  'b9200000-0000-4000-8000-000000000001',
  'b9200000-0000-4000-8000-000000000002'
);
select results_eq(
  $$
    select blocked_profile_id, blocked_display_name
    from public.get_own_blocked_profile_status(
      'b9200000-0000-4000-8000-000000000001',
      'b9200000-0000-4000-8000-000000000002'
    )
  $$,
  $$ values (
    'b9200000-0000-4000-8000-000000000002'::uuid,
    'Status B'::text
  ) $$,
  'the caller sees exactly their own active outbound block'
);

select is(
  (
    select count(*)
    from public.get_own_blocked_profile_status(
      'b9200000-0000-4000-8000-000000000001',
      'b9200000-0000-4000-8000-000000000003'
    )
  ),
  0::bigint,
  'an unrelated target returns no row'
);

select throws_ok(
  $$
    select *
    from public.get_own_blocked_profile_status(
      'b9200000-0000-4000-8000-000000000003',
      'b9200000-0000-4000-8000-000000000002'
    )
  $$,
  '42501',
  'The authenticated user does not match the expected blocking profile.',
  'a caller cannot inspect another profile outbound state'
);

select throws_ok(
  $$
    select * from private.user_block_episodes
  $$,
  '42501',
  'permission denied for schema private',
  'authenticated clients still cannot inspect the private block table'
);

select set_config(
  'request.jwt.claim.sub',
  'b9200000-0000-4000-8000-000000000001',
  true
);
select public.unblock_user(
  'b9200000-0000-4000-8000-000000000001',
  'b9200000-0000-4000-8000-000000000002'
);
select is(
  (
    select count(*)
    from public.get_own_blocked_profile_status(
      'b9200000-0000-4000-8000-000000000001',
      'b9200000-0000-4000-8000-000000000002'
    )
  ),
  0::bigint,
  'unblocking removes the caller-owned status row without revealing the inbound block'
);

select * from finish();

rollback;
