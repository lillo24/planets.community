begin;

select no_plan();

select ok(
  to_regprocedure(
    'public.list_own_participation_request_message_items(uuid,integer,timestamptz,uuid)'
  ) is not null,
  'the bounded structured Messages inbox RPC exists'
);
select ok(
  to_regprocedure(
    'public.get_own_participation_request_message_item(uuid,uuid)'
  ) is not null,
  'the exact structured participation-request message RPC exists'
);
select is(
  pg_get_function_result(
    'public.list_own_participation_request_message_items(uuid,integer,timestamptz,uuid)'::regprocedure
  ),
  'TABLE(request_id uuid, project_id uuid, project_kind text, project_title text, viewer_role text, requester_profile_id uuid, requester_display_name text, creator_profile_id uuid, creator_display_name text, request_message text, status text, created_at timestamp with time zone, resolved_at timestamp with time zone, activity_at timestamp with time zone)',
  'the inbox exposes only the structured participation presentation contract'
);
select is(
  pg_get_function_result(
    'public.get_own_participation_request_message_item(uuid,uuid)'::regprocedure
  ),
  pg_get_function_result(
    'public.list_own_participation_request_message_items(uuid,integer,timestamptz,uuid)'::regprocedure
  ),
  'list and exact reads share one stable item shape'
);
select is(
  (
    select bool_and(procedure.prosecdef)
    from pg_proc as procedure
    where procedure.oid in (
      'public.list_own_participation_request_message_items(uuid,integer,timestamptz,uuid)'::regprocedure,
      'public.get_own_participation_request_message_item(uuid,uuid)'::regprocedure
    )
  ),
  true,
  'Messages reads deliberately cross private tables through security definer'
);
select is(
  (
    select bool_and(array_to_string(procedure.proconfig, ',') = 'search_path=""')
    from pg_proc as procedure
    where procedure.oid in (
      'public.list_own_participation_request_message_items(uuid,integer,timestamptz,uuid)'::regprocedure,
      'public.get_own_participation_request_message_item(uuid,uuid)'::regprocedure
    )
  ),
  true,
  'all Messages security definers fix an empty search path'
);
select is(
  has_function_privilege(
    'authenticated',
    'public.list_own_participation_request_message_items(uuid,integer,timestamptz,uuid)',
    'EXECUTE'
  ),
  true,
  'authenticated clients can use the Messages inbox boundary'
);
select is(
  has_function_privilege(
    'anon',
    'public.list_own_participation_request_message_items(uuid,integer,timestamptz,uuid)',
    'EXECUTE'
  ),
  false,
  'anonymous clients cannot use the Messages inbox boundary'
);
select is(
  has_function_privilege(
    'anon',
    'public.get_own_participation_request_message_item(uuid,uuid)',
    'EXECUTE'
  ),
  false,
  'anonymous clients cannot use the exact Messages boundary'
);
select is(
  has_function_privilege(
    'service_role',
    'public.list_own_participation_request_message_items(uuid,integer,timestamptz,uuid)',
    'EXECUTE'
  ),
  false,
  'service credentials receive no ambient Messages inbox privilege'
);
select is(
  has_function_privilege(
    'service_role',
    'public.get_own_participation_request_message_item(uuid,uuid)',
    'EXECUTE'
  ),
  false,
  'service credentials receive no ambient Messages read privilege'
);
select ok(
  to_regclass('public.project_join_requests_requester_activity_idx') is not null,
  'outgoing activity keyset reads have a supporting index'
);
select ok(
  to_regclass('public.project_join_requests_project_activity_idx') is not null,
  'incoming activity keyset reads have a supporting index'
);
select ok(
  position(
    'offset' in lower(
      pg_get_functiondef(
        'public.list_own_participation_request_message_items(uuid,integer,timestamptz,uuid)'::regprocedure
      )
    )
  ) = 0,
  'Messages pagination does not use offset'
);
select ok(
  position(
    'order by authorized.activity_at desc, authorized.id desc' in lower(
      pg_get_functiondef(
        'public.list_own_participation_request_message_items(uuid,integer,timestamptz,uuid)'::regprocedure
      )
    )
  ) > 0,
  'Messages pagination has a deterministic descending composite order'
);
select is(
  to_regclass('public.messages'),
  null::regclass,
  'Plan 07A does not introduce a generic messages table'
);
select is(
  to_regclass('public.message_threads'),
  null::regclass,
  'Plan 07A does not introduce chat threads'
);
select is(
  (
    select count(*)
    from information_schema.columns
    where table_schema = 'public'
      and column_name = 'request_message'
      and table_name not in (
        'project_join_requests',
        'resource_listing_requests'
      )
  ),
  0::bigint,
  'private request notes remain only on their canonical request rows'
);

select * from finish();

rollback;
