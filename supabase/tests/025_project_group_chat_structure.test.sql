begin;

select no_plan();

select has_table(
  'public',
  'project_group_chats',
  'the canonical Project group-chat anchor exists'
);

select results_eq(
  $$
    select column_name::text collate "C"
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'project_group_chats'
    order by ordinal_position
  $$,
  $$values
    ('id'::text collate "C"),
    ('project_id'::text collate "C"),
    ('activated_at'::text collate "C"),
    ('created_at'::text collate "C")
  $$,
  'the chat anchor contains structural state only'
);

select is(
  (
    select data_type::text
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'project_group_chats'
      and column_name = 'id'
  ),
  'uuid',
  'chat identity is an opaque UUID'
);
select like(
  (
    select column_default
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'project_group_chats'
      and column_name = 'id'
  ),
  '%gen_random_uuid()%',
  'chat identity is database-generated'
);
select is(
  (
    select count(*)
    from pg_constraint as constraint_row
    where constraint_row.conrelid = 'public.project_group_chats'::regclass
      and constraint_row.contype = 'p'
      and pg_get_constraintdef(constraint_row.oid) = 'PRIMARY KEY (id)'
  ),
  1::bigint,
  'chat identity is the primary key'
);
select is(
  (
    select count(*)
    from pg_constraint as constraint_row
    where constraint_row.conrelid = 'public.project_group_chats'::regclass
      and constraint_row.contype = 'u'
      and pg_get_constraintdef(constraint_row.oid) = 'UNIQUE (project_id)'
  ),
  1::bigint,
  'the database permits at most one chat per Project'
);
select is(
  (
    select count(*)
    from pg_constraint as constraint_row
    where constraint_row.conrelid = 'public.project_group_chats'::regclass
      and constraint_row.contype = 'f'
      and constraint_row.confrelid = 'public.projects'::regclass
      and constraint_row.confdeltype = 'r'
  ),
  1::bigint,
  'the chat anchor has a restrictive shared-Project foreign key'
);
select ok(
  (
    select pg_get_constraintdef(constraint_row.oid)
    from pg_constraint as constraint_row
    where constraint_row.conrelid = 'public.project_group_chats'::regclass
      and constraint_row.conname =
        'project_group_chats_creation_not_before_activation'
  ) ilike '%created_at >= activated_at%',
  'physical chat creation cannot predate logical activation'
);

select is(
  (
    select class.relrowsecurity
    from pg_class as class
    where class.oid = 'public.project_group_chats'::regclass
  ),
  true,
  'RLS is enabled on the public chat-anchor table'
);
select is(
  (
    select count(*)
    from pg_policies
    where schemaname = 'public'
      and tablename = 'project_group_chats'
  ),
  0::bigint,
  'the chat anchor has no direct client policy'
);

select is(
  (
    select bool_and(
      not has_table_privilege(role_name, 'public.project_group_chats', privilege_name)
    )
    from unnest(array['public', 'anon', 'authenticated', 'service_role'])
      as role_name
    cross join unnest(array['SELECT', 'INSERT', 'UPDATE', 'DELETE'])
      as privilege_name
  ),
  true,
  'public, client, and broad service roles have no direct chat-table privileges'
);

select ok(
  to_regprocedure('private.ensure_project_group_chat(uuid,timestamptz)')
    is not null,
  'the private idempotent chat ensure helper exists'
);
select ok(
  to_regprocedure('private.reconcile_project_group_chats()') is not null,
  'the private deterministic backfill helper exists'
);
select ok(
  to_regprocedure('private.profile_is_project_creator(uuid,uuid)')
    is not null,
  'the private creator primitive exists'
);
select ok(
  to_regprocedure(
    'private.profile_has_current_project_membership(uuid,uuid)'
  ) is not null,
  'the private current-membership primitive exists'
);
select ok(
  to_regprocedure(
    'private.profile_has_project_membership_history(uuid,uuid)'
  ) is not null,
  'the private membership-history primitive exists'
);
select ok(
  to_regprocedure(
    'private.profile_was_project_member_at(uuid,uuid,timestamptz)'
  ) is not null,
  'the private membership-at-time primitive exists'
);
select ok(
  to_regprocedure(
    'private.profile_has_current_project_chat_entitlement(uuid,uuid)'
  ) is not null,
  'the private current-chat entitlement primitive exists'
);
select ok(
  to_regprocedure(
    'private.profile_has_project_chat_history_entitlement(uuid,uuid)'
  ) is not null,
  'the private historical-chat entitlement primitive exists'
);
select ok(
  to_regprocedure('public.get_own_project_group_chat(uuid,uuid)') is not null,
  'the expected-identity chat-anchor read exists'
);

select is(
  (
    select bool_and(procedure.prosecdef)
    from pg_proc as procedure
    where procedure.oid in (
      'private.ensure_project_group_chat(uuid,timestamptz)'::regprocedure,
      'private.reconcile_project_group_chats()'::regprocedure,
      'private.profile_is_project_creator(uuid,uuid)'::regprocedure,
      'private.profile_has_current_project_membership(uuid,uuid)'::regprocedure,
      'private.profile_has_project_membership_history(uuid,uuid)'::regprocedure,
      'private.profile_was_project_member_at(uuid,uuid,timestamptz)'::regprocedure,
      'private.profile_has_current_project_chat_entitlement(uuid,uuid)'::regprocedure,
      'private.profile_has_project_chat_history_entitlement(uuid,uuid)'::regprocedure,
      'public.get_own_project_group_chat(uuid,uuid)'::regprocedure
    )
  ),
  true,
  'chat helpers and the narrow read are deliberate security-definer boundaries'
);
select is(
  (
    select bool_and(array_to_string(procedure.proconfig, ',') = 'search_path=""')
    from pg_proc as procedure
    where procedure.oid in (
      'private.ensure_project_group_chat(uuid,timestamptz)'::regprocedure,
      'private.reconcile_project_group_chats()'::regprocedure,
      'private.profile_is_project_creator(uuid,uuid)'::regprocedure,
      'private.profile_has_current_project_membership(uuid,uuid)'::regprocedure,
      'private.profile_has_project_membership_history(uuid,uuid)'::regprocedure,
      'private.profile_was_project_member_at(uuid,uuid,timestamptz)'::regprocedure,
      'private.profile_has_current_project_chat_entitlement(uuid,uuid)'::regprocedure,
      'private.profile_has_project_chat_history_entitlement(uuid,uuid)'::regprocedure,
      'public.get_own_project_group_chat(uuid,uuid)'::regprocedure
    )
  ),
  true,
  'all chat security definers fix an empty search path'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.get_own_project_group_chat(uuid,uuid)',
    'EXECUTE'
  ),
  true,
  'authenticated clients may execute only the narrow chat-anchor read'
);
select is(
  (
    select bool_and(
      not has_function_privilege(
        role_name,
        'public.get_own_project_group_chat(uuid,uuid)',
        'EXECUTE'
      )
    )
    from unnest(array['public', 'anon', 'service_role']) as role_name
  ),
  true,
  'the public chat read is denied to unauthenticated and broad service roles'
);
select is(
  (
    select bool_and(
      not has_function_privilege(role_name, helper.oid, 'EXECUTE')
    )
    from unnest(array['public', 'anon', 'authenticated', 'service_role'])
      as role_name
    cross join lateral (
      select procedure.oid
      from pg_proc as procedure
      join pg_namespace as namespace on namespace.oid = procedure.pronamespace
      where namespace.nspname = 'private'
        and procedure.proname in (
          'ensure_project_group_chat',
          'reconcile_project_group_chats',
          'profile_is_project_creator',
          'profile_has_current_project_membership',
          'profile_has_project_membership_history',
          'profile_was_project_member_at',
          'profile_has_current_project_chat_entitlement',
          'profile_has_project_chat_history_entitlement'
        )
    ) as helper
  ),
  true,
  'private chat helpers are not client- or service-executable'
);

select ok(
  exists (
    select 1
    from pg_trigger as trigger_row
    where trigger_row.tgrelid = 'public.project_memberships'::regclass
      and trigger_row.tgname = 'project_memberships_ensure_group_chat'
      and not trigger_row.tgisinternal
  ),
  'canonical membership insertion transactionally ensures the chat anchor'
);
select ok(
  pg_get_function_result(
    'public.get_own_project_group_chat(uuid,uuid)'::regprocedure
  ) = 'TABLE(chat_id uuid, project_id uuid, project_kind text, activated_at timestamp with time zone, viewer_role text, has_current_entitlement boolean, has_history_entitlement boolean)',
  'the client contract exposes only safe structural and entitlement state'
);

select ok(
  to_regclass('public.project_group_chat_members') is null
    and to_regclass('public.project_chat_messages') is null
    and to_regclass('public.chat_messages') is null,
  '07B1 adds neither a chat-member mirror nor a message table'
);
select is(
  (
    select count(*)
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'project_group_chats'
      and column_name ~ '(body|message|cipher|encrypt|key|participant|member|attachment|reaction)'
  ),
  0::bigint,
  'the chat anchor stores no message, key, participant, attachment, or reaction placeholder'
);
select is(
  (
    select count(*)
    from pg_publication_tables
    where schemaname = 'public'
      and tablename = 'project_group_chats'
  ),
  0::bigint,
  '07B1 does not publish the chat anchor through Realtime'
);

select * from finish();

rollback;
