begin;

select no_plan();

select has_table(
  'public',
  'project_chat_messages',
  'the durable Project chat message table exists'
);

select results_eq(
  $$
    select column_name::text collate "C"
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'project_chat_messages'
    order by ordinal_position
  $$,
  $$values
    ('id'::text collate "C"),
    ('chat_id'::text collate "C"),
    ('sender_profile_id'::text collate "C"),
    ('body'::text collate "C"),
    ('created_at'::text collate "C")
  $$,
  'the message table contains only the MVP plain-text domain fields'
);

select results_eq(
  $$
    select column_name::text, data_type::text, is_nullable::text
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'project_chat_messages'
    order by ordinal_position
  $$,
  $$values
    ('id'::text, 'uuid'::text, 'NO'::text),
    ('chat_id'::text, 'uuid'::text, 'NO'::text),
    ('sender_profile_id'::text, 'uuid'::text, 'NO'::text),
    ('body'::text, 'text'::text, 'NO'::text),
    ('created_at'::text, 'timestamp with time zone'::text, 'NO'::text)
  $$,
  'message field types and nullability are canonical'
);

select ok(
  (
    select column_default like '%gen_random_uuid()%'
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'project_chat_messages'
      and column_name = 'id'
  ),
  'message IDs are database-generated UUIDs'
);
select ok(
  (
    select column_default like '%statement_timestamp()%'
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'project_chat_messages'
      and column_name = 'created_at'
  ),
  'message timestamps have a server-owned default'
);

select is(
  (
    select count(*)
    from pg_constraint as constraint_row
    where constraint_row.conrelid = 'public.project_chat_messages'::regclass
      and constraint_row.contype = 'p'
      and pg_get_constraintdef(constraint_row.oid) = 'PRIMARY KEY (id)'
  ),
  1::bigint,
  'message identity is the primary key'
);
select is(
  (
    select count(*)
    from pg_constraint as constraint_row
    where constraint_row.conrelid = 'public.project_chat_messages'::regclass
      and constraint_row.contype = 'f'
      and constraint_row.confrelid = 'public.project_group_chats'::regclass
      and constraint_row.confdeltype = 'r'
  ),
  1::bigint,
  'messages restrict deletion of their canonical chat anchor'
);
select is(
  (
    select count(*)
    from pg_constraint as constraint_row
    where constraint_row.conrelid = 'public.project_chat_messages'::regclass
      and constraint_row.contype = 'f'
      and constraint_row.confrelid = 'public.profiles'::regclass
      and constraint_row.confdeltype = 'r'
  ),
  1::bigint,
  'messages retain a restrictive sender-profile reference'
);
select ok(
  (
    select pg_get_constraintdef(constraint_row.oid)
    from pg_constraint as constraint_row
    where constraint_row.conrelid = 'public.project_chat_messages'::regclass
      and constraint_row.conname = 'project_chat_messages_body_canonical'
  ) ilike '%char_length(body)%between 1 and 4000%',
  'the database bounds canonical bodies to 4,000 Unicode characters'
);

select ok(
  to_regprocedure(
    'private.protect_project_chat_message_immutability()'
  ) is not null
    and exists (
      select 1
      from pg_trigger as trigger_row
      where trigger_row.tgrelid = 'public.project_chat_messages'::regclass
        and trigger_row.tgname = 'project_chat_messages_immutable'
        and not trigger_row.tgisinternal
    ),
  'a database trigger protects every persisted message from update or deletion'
);

select results_eq(
  $$
    select indexname::text collate "C"
    from pg_indexes
    where schemaname = 'public'
      and tablename = 'project_chat_messages'
      and indexname <> 'project_chat_messages_pkey'
    order by indexname collate "C"
  $$,
  $$values
    ('project_chat_messages_chat_created_idx'::text collate "C"),
    ('project_chat_messages_sender_created_idx'::text collate "C")
  $$,
  'message indexes cover history ordering and both foreign-key paths'
);
select ok(
  (
    select indexdef
    from pg_indexes
    where schemaname = 'public'
      and tablename = 'project_chat_messages'
      and indexname = 'project_chat_messages_chat_created_idx'
  ) ilike '%(chat_id, created_at desc, id desc)%',
  'the history index exactly matches descending keyset pagination'
);

select is(
  (
    select class.relrowsecurity
    from pg_class as class
    where class.oid = 'public.project_chat_messages'::regclass
  ),
  true,
  'RLS is enabled on the exposed-schema message table'
);
select is(
  (
    select count(*)
    from pg_policies
    where schemaname = 'public'
      and tablename = 'project_chat_messages'
  ),
  0::bigint,
  'messages have no direct client RLS policy because access is RPC-only'
);
select is(
  (
    select bool_and(
      not has_table_privilege(
        role_name,
        'public.project_chat_messages',
        privilege_name
      )
    )
    from unnest(array['anon', 'authenticated', 'service_role'])
      as role_name
    cross join unnest(array['SELECT', 'INSERT', 'UPDATE', 'DELETE'])
      as privilege_name
  ),
  true,
  'anon, authenticated, and broad service roles have no direct message privileges'
);

select ok(
  to_regprocedure(
    'private.profile_can_read_project_chat_message(uuid,uuid,timestamptz)'
  ) is not null
    and to_regprocedure(
      'private.latest_project_membership_end(uuid,uuid)'
    ) is not null,
  'dedicated private message-read and history-frontier primitives exist'
);
select ok(
  to_regprocedure('public.send_project_chat_message(uuid,uuid,text)')
    is not null,
  'the expected-identity send RPC exists'
);
select ok(
  to_regprocedure(
    'public.list_own_project_chat_messages(uuid,uuid,integer,timestamptz,uuid)'
  ) is not null,
  'the keyset message-history RPC exists'
);
select ok(
  to_regprocedure(
    'public.list_own_project_group_chats(uuid,integer,timestamptz,uuid)'
  ) is not null,
  'the keyset accessible-chat-list RPC exists'
);
select ok(
  to_regprocedure('public.get_project_chat_message(uuid,uuid)') is null
    and to_regprocedure('public.update_project_chat_message(uuid,text)') is null
    and to_regprocedure('public.delete_project_chat_message(uuid)') is null,
  'there is no exact-read, edit, or delete client RPC'
);

select ok(
  pg_get_function_result(
    'public.send_project_chat_message(uuid,uuid,text)'::regprocedure
  ) = 'TABLE(message_id uuid, chat_id uuid, sender_profile_id uuid, created_at timestamp with time zone, body text)',
  'send returns only canonical reconciliation fields'
);
select ok(
  pg_get_function_result(
    'public.list_own_project_chat_messages(uuid,uuid,integer,timestamptz,uuid)'::regprocedure
  ) = 'TABLE(message_id uuid, chat_id uuid, sender_profile_id uuid, sender_display_name text, body text, created_at timestamp with time zone)',
  'history returns only message and public-safe sender display fields'
);
select ok(
  pg_get_function_result(
    'public.list_own_project_group_chats(uuid,integer,timestamptz,uuid)'::regprocedure
  ) = 'TABLE(chat_id uuid, project_id uuid, project_kind text, project_title text, viewer_role text, has_current_entitlement boolean, has_history_entitlement boolean, activated_at timestamp with time zone, last_visible_message_id uuid, last_visible_message_body text, last_visible_message_at timestamp with time zone, last_visible_sender_profile_id uuid, last_visible_sender_display_name text, activity_at timestamp with time zone)',
  'chat summaries expose only the viewer last visible message and entitlement state'
);

select is(
  (
    select bool_and(
      has_function_privilege(
        'authenticated',
        procedure_oid,
        'EXECUTE'
      )
      and not has_function_privilege('anon', procedure_oid, 'EXECUTE')
      and not has_function_privilege('service_role', procedure_oid, 'EXECUTE')
    )
    from unnest(array[
      'public.send_project_chat_message(uuid,uuid,text)'::regprocedure,
      'public.list_own_project_chat_messages(uuid,uuid,integer,timestamptz,uuid)'::regprocedure,
      'public.list_own_project_group_chats(uuid,integer,timestamptz,uuid)'::regprocedure
    ]) as procedure_oid
  ),
  true,
  'only authenticated clients can execute the three public chat-message APIs'
);
select is(
  (
    select bool_and(
      not has_function_privilege(role_name, procedure_oid, 'EXECUTE')
    )
    from unnest(array['anon', 'authenticated', 'service_role'])
      as role_name
    cross join unnest(array[
      'private.protect_project_chat_message_immutability()'::regprocedure,
      'private.latest_project_membership_end(uuid,uuid)'::regprocedure,
      'private.profile_can_read_project_chat_message(uuid,uuid,timestamptz)'::regprocedure,
      'private.require_complete_project_chat_profile(uuid)'::regprocedure,
      'private.project_chat_realtime_topic(uuid,uuid)'::regprocedure,
      'private.profile_can_receive_project_chat_realtime_topic(text)'::regprocedure
    ]) as procedure_oid
  ),
  true,
  'private chat-message helpers are not directly executable by client roles'
);

select results_eq(
  $$
    select policyname::text, cmd::text, roles::text
    from pg_policies
    where schemaname = 'realtime'
      and tablename = 'messages'
      and policyname = 'project_chat_current_profiles_receive_broadcasts'
  $$,
  $$values (
    'project_chat_current_profiles_receive_broadcasts'::text,
    'SELECT'::text,
    '{authenticated}'::text
  )$$,
  'private Broadcast has one authenticated receive-only authorization policy'
);
select is(
  (
    select qual ilike '%profile_can_receive_project_chat_realtime_topic%'
      and qual ilike '%realtime.topic%'
      and qual ilike '%extension%broadcast%'
    from pg_policies
    where schemaname = 'realtime'
      and tablename = 'messages'
      and policyname = 'project_chat_current_profiles_receive_broadcasts'
  ),
  true,
  'Realtime policy binds the private topic to current Project-chat entitlement'
);
select is(
  (
    select count(*)
    from pg_policies
    where schemaname = 'realtime'
      and tablename = 'messages'
      and policyname like 'project_chat%'
      and cmd in ('INSERT', 'UPDATE', 'DELETE', 'ALL')
  ),
  0::bigint,
  'clients receive database signals but cannot publish Project-chat Broadcasts'
);
select is(
  (
    select count(*)
    from pg_publication_tables
    where schemaname = 'public'
      and tablename = 'project_chat_messages'
  ),
  0::bigint,
  'message rows are not broadly exposed through Postgres Changes'
);

select is(
  (
    select count(*)
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'project_chat_messages'
      and column_name ~ '(cipher|encrypt|key|epoch|device|attachment|reaction|reply|read|delivery|delete|edit|html|json)'
  ),
  0::bigint,
  'the MVP schema adds no E2EE or deferred chat-feature placeholders'
);

select * from finish();

rollback;
