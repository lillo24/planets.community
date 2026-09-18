begin;

select no_plan();

select has_table(
  'public',
  'project_chat_system_events',
  'structured Project-chat system events exist separately from human messages'
);
select columns_are(
  'public',
  'project_chat_system_events',
  array[
    'id',
    'chat_id',
    'event_kind',
    'requirement_kind',
    'skill_id',
    'resource_need_id',
    'source_outbox_event_id',
    'created_at'
  ],
  'system events store identifiers and provenance without localized copy'
);

select is(
  (
    select pg_get_constraintdef(constraint_row.oid)
    from pg_constraint as constraint_row
    where constraint_row.conrelid =
      'public.project_chat_system_events'::regclass
      and constraint_row.conname =
        'project_chat_system_events_kind_supported'
  ),
  'CHECK ((event_kind = ''requirement_needed_again''::text))',
  'only requirement-needed-again is a durable system-event kind'
);
select ok(
  (
    select pg_get_constraintdef(constraint_row.oid)
    from pg_constraint as constraint_row
    where constraint_row.conrelid =
      'public.project_chat_system_events'::regclass
      and constraint_row.conname =
        'project_chat_system_events_requirement_reference'
  ) ilike '%requirement_kind%skill%skill_id is not null%resource_need_id is null%'
    and (
      select pg_get_constraintdef(constraint_row.oid)
      from pg_constraint as constraint_row
      where constraint_row.conrelid =
        'public.project_chat_system_events'::regclass
        and constraint_row.conname =
          'project_chat_system_events_requirement_reference'
    ) ilike '%requirement_kind%resource%skill_id is null%resource_need_id is not null%',
  'skill and resource references have one strict discriminated shape'
);
select results_eq(
  $$
    select
      referenced.relname::text collate "C",
      constraint_row.confdeltype::text collate "C"
    from pg_constraint as constraint_row
    join pg_class as referenced on referenced.oid = constraint_row.confrelid
    where constraint_row.conrelid =
      'public.project_chat_system_events'::regclass
      and constraint_row.contype = 'f'
    order by referenced.relname collate "C"
  $$,
  $$values
    ('outbox_events'::text collate "C", 'r'::text collate "C"),
    ('project_group_chats'::text collate "C", 'r'::text collate "C"),
    ('project_resource_needs'::text collate "C", 'r'::text collate "C"),
    ('skills'::text collate "C", 'r'::text collate "C")
  $$,
  'system events retain restrictive chat, requirement, and source provenance'
);
select is(
  (
    select count(*)
    from pg_constraint as constraint_row
    where constraint_row.conrelid =
      'public.project_chat_system_events'::regclass
      and constraint_row.contype = 'u'
      and pg_get_constraintdef(constraint_row.oid)
        = 'UNIQUE (source_outbox_event_id)'
  ),
  1::bigint,
  'one source outbox transition can create at most one system event'
);
select ok(
  (
    select indexdef
    from pg_indexes
    where schemaname = 'public'
      and tablename = 'project_chat_system_events'
      and indexname = 'project_chat_system_events_chat_created_idx'
  ) ilike '%(chat_id, created_at desc, id desc)%',
  'system history has the exact descending chat chronology index'
);
select is(
  (
    select count(*)
    from pg_trigger as trigger_row
    where trigger_row.tgrelid =
      'public.project_chat_system_events'::regclass
      and trigger_row.tgname in (
        'project_chat_system_events_validate',
        'project_chat_system_events_immutable'
      )
      and not trigger_row.tgisinternal
  ),
  2::bigint,
  'system-event provenance is validated and every stored event is immutable'
);

select has_table(
  'public',
  'project_chat_requirement_attention_receipts',
  'persistent Project-chat requirement-attention receipts exist'
);
select columns_are(
  'public',
  'project_chat_requirement_attention_receipts',
  array[
    'chat_id',
    'profile_id',
    'acknowledged_through_created_at',
    'acknowledged_through_event_id',
    'updated_at'
  ],
  'attention receipts persist a complete deterministic system-event cursor'
);
select is(
  (
    select array_agg(attribute.attname order by key_column.ordinality)
    from pg_constraint as constraint_row
    cross join lateral unnest(constraint_row.conkey)
      with ordinality as key_column(attnum, ordinality)
    join pg_attribute as attribute
      on attribute.attrelid = constraint_row.conrelid
      and attribute.attnum = key_column.attnum
    where constraint_row.conrelid =
      'public.project_chat_requirement_attention_receipts'::regclass
      and constraint_row.contype = 'p'
  ),
  array['chat_id', 'profile_id']::name[],
  'attention has one durable cursor per chat and profile'
);
select is(
  (
    select pg_get_constraintdef(constraint_row.oid)
    from pg_constraint as constraint_row
    where constraint_row.conrelid =
      'public.project_chat_requirement_attention_receipts'::regclass
      and constraint_row.conname =
        'project_chat_requirement_attention_receipts_event_cursor_fkey'
  ),
  'FOREIGN KEY (chat_id, acknowledged_through_created_at, acknowledged_through_event_id) REFERENCES project_chat_system_events(chat_id, created_at, id) ON DELETE RESTRICT',
  'the acknowledgement timestamp and UUID must identify one event in the same chat'
);
select is(
  (
    select bool_and(column_row.is_nullable = 'NO')
    from information_schema.columns as column_row
    where column_row.table_schema = 'public'
      and column_row.table_name =
        'project_chat_requirement_attention_receipts'
  ),
  true,
  'every persisted attention cursor field is required'
);

select is(
  (
    select bool_and(class.relrowsecurity)
    from pg_class as class
    where class.oid in (
      'public.project_chat_system_events'::regclass,
      'public.project_chat_requirement_attention_receipts'::regclass
    )
  ),
  true,
  'both exposed-schema tables enable RLS'
);
select is(
  (
    select count(*)
    from pg_policies
    where schemaname = 'public'
      and tablename in (
        'project_chat_system_events',
        'project_chat_requirement_attention_receipts'
      )
  ),
  0::bigint,
  'system history and attention expose no direct client policies'
);
select is(
  (
    select count(*)
    from (values
      ('anon'::name),
      ('authenticated'::name),
      ('service_role'::name)
    ) as client(role_name)
    cross join (values
      ('public.project_chat_system_events'::regclass),
      ('public.project_chat_requirement_attention_receipts'::regclass)
    ) as protected_table(table_oid)
    cross join (values
      ('SELECT'::text),
      ('INSERT'::text),
      ('UPDATE'::text),
      ('DELETE'::text)
    ) as privilege(privilege_name)
    where has_table_privilege(
      client.role_name,
      protected_table.table_oid,
      privilege.privilege_name
    )
  ),
  0::bigint,
  'system history and attention have no direct client or service grants'
);

select ok(
  to_regprocedure(
    'public.list_own_project_chat_feed(uuid,uuid,integer,timestamptz,text,uuid)'
  ) is not null,
  'the canonical mixed Project-chat feed exists'
);
select ok(
  to_regprocedure(
    'public.get_own_project_requirement_attention(uuid,uuid)'
  ) is not null,
  'the current-group attention read exists'
);
select ok(
  to_regprocedure(
    'public.acknowledge_project_requirement_attention(uuid,uuid,uuid)'
  ) is not null,
  'the explicit-frontier acknowledgement mutation exists'
);
select ok(
  to_regprocedure(
    'public.list_own_project_chat_messages(uuid,uuid,integer,timestamptz,uuid)'
  ) is not null,
  'the old human-message-only history RPC remains available'
);
select is(
  (
    select proargnames
    from pg_proc
    where oid =
      'public.list_own_project_chat_feed(uuid,uuid,integer,timestamptz,text,uuid)'::regprocedure
  ),
  array[
    'p_expected_profile_id',
    'p_chat_id',
    'p_limit',
    'p_before_created_at',
    'p_before_item_kind',
    'p_before_item_id',
    'item_kind',
    'item_id',
    'chat_id',
    'created_at',
    'sender_profile_id',
    'sender_display_name',
    'body',
    'system_event_kind',
    'requirement_kind',
    'requirement_id',
    'requirement_label'
  ]::text[],
  'the mixed feed exposes the complete discriminated row and cursor shape'
);
select ok(
  pg_get_function_result(
    'public.get_own_project_requirement_attention(uuid,uuid)'::regprocedure
  ) = 'TABLE(chat_id uuid, has_unseen_resurfaced_need boolean, latest_unseen_event_id uuid, latest_unseen_event_at timestamp with time zone)',
  'attention read returns only its canonical current-state summary'
);
select ok(
  pg_get_function_result(
    'public.acknowledge_project_requirement_attention(uuid,uuid,uuid)'::regprocedure
  ) = 'uuid',
  'acknowledgement returns its effective seen-through event UUID'
);

select is(
  (
    select bool_and(procedure.prosecdef)
    from pg_proc as procedure
    where procedure.oid in (
      'public.list_own_project_chat_feed(uuid,uuid,integer,timestamptz,text,uuid)'::regprocedure,
      'public.get_own_project_requirement_attention(uuid,uuid)'::regprocedure,
      'public.acknowledge_project_requirement_attention(uuid,uuid,uuid)'::regprocedure,
      'private.validate_project_chat_system_event()'::regprocedure,
      'private.protect_project_chat_system_event_immutability()'::regprocedure
    )
  ),
  true,
  'public contracts and trusted helpers use explicit security-definer boundaries'
);
select is(
  (
    select bool_and(array_to_string(procedure.proconfig, ',') = 'search_path=""')
    from pg_proc as procedure
    where procedure.oid in (
      'public.list_own_project_chat_feed(uuid,uuid,integer,timestamptz,text,uuid)'::regprocedure,
      'public.get_own_project_requirement_attention(uuid,uuid)'::regprocedure,
      'public.acknowledge_project_requirement_attention(uuid,uuid,uuid)'::regprocedure,
      'private.validate_project_chat_system_event()'::regprocedure,
      'private.protect_project_chat_system_event_immutability()'::regprocedure
    )
  ),
  true,
  'every new trusted function fixes an empty search path'
);
select is(
  (
    select count(*)
    from (values
      ('public.list_own_project_chat_feed(uuid,uuid,integer,timestamptz,text,uuid)'::regprocedure),
      ('public.get_own_project_requirement_attention(uuid,uuid)'::regprocedure),
      ('public.acknowledge_project_requirement_attention(uuid,uuid,uuid)'::regprocedure)
    ) as routine(oid)
    where has_function_privilege('authenticated', routine.oid, 'EXECUTE')
  ),
  3::bigint,
  'authenticated clients can call the three D3B1 public contracts'
);
select is(
  (
    select count(*)
    from (values ('anon'::name), ('service_role'::name)) as client(role_name)
    cross join (values
      ('public.list_own_project_chat_feed(uuid,uuid,integer,timestamptz,text,uuid)'::regprocedure),
      ('public.get_own_project_requirement_attention(uuid,uuid)'::regprocedure),
      ('public.acknowledge_project_requirement_attention(uuid,uuid,uuid)'::regprocedure)
    ) as routine(oid)
    where has_function_privilege(client.role_name, routine.oid, 'EXECUTE')
  ),
  0::bigint,
  'anonymous and broad service roles cannot call D3B1 APIs'
);
select is(
  (
    select count(*)
    from (values
      ('anon'::name),
      ('authenticated'::name),
      ('service_role'::name)
    ) as client(role_name)
    cross join (values
      ('private.validate_project_chat_system_event()'::regprocedure),
      ('private.protect_project_chat_system_event_immutability()'::regprocedure)
    ) as helper(oid)
    where has_function_privilege(client.role_name, helper.oid, 'EXECUTE')
  ),
  0::bigint,
  'new private helpers cannot be invoked by client or service roles'
);

select ok(
  position(
    'realtime.send' in pg_get_functiondef(
      'private.record_project_requirement_coverage_event(text,uuid,uuid,text,text,uuid,uuid)'::regprocedure
    )
  ) > 0
    and position(
      'project_chat_system_events' in pg_get_functiondef(
        'private.record_project_requirement_coverage_event(text,uuid,uuid,text,text,uuid,uuid)'::regprocedure
      )
    ) > 0,
  'the canonical D3A transition helper owns synchronous projection and signals'
);
select ok(
  position(
    '''project.requirement_needed_again''' in pg_get_functiondef(
      'private.record_project_requirement_coverage_event(text,uuid,uuid,text,text,uuid,uuid)'::regprocedure
    )
  ) > 0
    and position(
      '''project.requirement_covered''' in pg_get_functiondef(
        'private.record_project_requirement_coverage_event(text,uuid,uuid,text,text,uuid,uuid)'::regprocedure
      )
    ) > 0,
  'needed-again and covered transitions reuse the existing private chat topic'
);
select ok(
  (
    select (trigger_row.tgtype & 2) = 0
      and (trigger_row.tgtype & 16) = 16
    from pg_trigger as trigger_row
    where trigger_row.tgrelid = 'public.project_memberships'::regclass
      and trigger_row.tgname = 'project_memberships_release_ended_coverage'
      and not trigger_row.tgisinternal
  ),
  'membership coverage release runs after the membership-end frontier persists'
);

select is(
  (
    select is_nullable
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'project_chat_messages'
      and column_name = 'sender_profile_id'
  ),
  'NO',
  'human chat messages still require a real sender'
);
select is(
  (
    select count(*)
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'project_chat_messages'
      and column_name in (
        'event_kind',
        'requirement_kind',
        'skill_id',
        'resource_need_id',
        'source_outbox_event_id'
      )
  ),
  0::bigint,
  'structured system fields do not weaken the human-message relation'
);

select * from finish();

rollback;
