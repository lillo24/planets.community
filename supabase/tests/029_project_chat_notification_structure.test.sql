begin;

select no_plan();

select col_type_is(
  'public',
  'notifications',
  'chat_id',
  'uuid',
  'in-app chat alerts retain a canonical chat identifier'
);
select col_type_is(
  'public',
  'notifications',
  'message_id',
  'uuid',
  'in-app chat alerts retain a canonical message identifier'
);
select col_is_null(
  'public',
  'notifications',
  'chat_id',
  'participation notifications remain valid without chat context'
);
select col_is_null(
  'public',
  'notifications',
  'message_id',
  'participation notifications remain valid without message context'
);
select col_type_is(
  'private',
  'push_delivery_jobs',
  'chat_id',
  'uuid',
  'provider-neutral jobs retain the chat destination identifier'
);
select col_type_is(
  'private',
  'push_delivery_jobs',
  'message_id',
  'uuid',
  'provider-neutral jobs retain the canonical message identifier'
);

select ok(
  (
    select count(*) = 4
    from pg_constraint
    where (
      conrelid = 'public.notifications'::regclass
      and conname in (
        'notifications_chat_id_fkey',
        'notifications_message_id_fkey'
      )
    ) or (
      conrelid = 'private.push_delivery_jobs'::regclass
      and conname in (
        'push_delivery_jobs_chat_id_fkey',
        'push_delivery_jobs_message_id_fkey'
      )
    )
  ),
  'notification and push chat/message references are foreign-key protected'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.notifications'::regclass
      and conname = 'notifications_category_matches_kind'
      and pg_get_constraintdef(oid) like '%chat_message_received%'
      and pg_get_constraintdef(oid) like '%category_slug%chat%'
  ),
  'the public notification category and chat kind cannot drift'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.notifications'::regclass
      and conname = 'notifications_reference_shape_valid'
      and pg_get_constraintdef(oid) like '%chat_id IS NOT NULL%'
      and pg_get_constraintdef(oid) like '%message_id IS NOT NULL%'
      and pg_get_constraintdef(oid) like '%request_id IS NULL%'
      and pg_get_constraintdef(oid) like '%membership_id IS NULL%'
  ),
  'chat notifications require chat/message context and prohibit participation references'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'private.push_delivery_jobs'::regclass
      and conname = 'push_delivery_jobs_chat_shape_valid'
      and pg_get_constraintdef(oid) like '%actor_profile_id IS NOT NULL%'
      and pg_get_constraintdef(oid) like '%project_chat%'
  ),
  'chat push jobs require actor, project, chat, message, and destination semantics'
);

select ok(
  to_regclass('public.notifications_chat_id_idx') is not null
    and to_regclass('public.notifications_message_id_idx') is not null
    and to_regclass('private.push_delivery_jobs_chat_id_idx') is not null
    and to_regclass('private.push_delivery_jobs_message_id_idx') is not null,
  'all new foreign-key lookup paths are indexed'
);
select ok(
  pg_get_indexdef(
    'private.outbox_events_notification_sources_available_idx'::regclass
  ) like '%project.chat_message_sent%',
  'the bounded projector source index includes only the newly supported chat event'
);

select ok(
  to_regprocedure(
    'private.resolve_chat_message_notification_event(uuid)'
  ) is not null,
  'the canonical Project chat notification resolver exists'
);
select ok(
  pg_get_function_result(
    'private.resolve_chat_message_notification_event(uuid)'::regprocedure
  ) like '%chat_id uuid%'
    and pg_get_function_result(
      'private.resolve_chat_message_notification_event(uuid)'::regprocedure
    ) like '%message_id uuid%'
    and pg_get_function_result(
      'private.resolve_chat_message_notification_event(uuid)'::regprocedure
    ) like '%source_created_at timestamp with time zone%',
  'the resolver emits complete semantic references and canonical chronology'
);
select ok(
  pg_get_functiondef(
    'private.resolve_chat_message_notification_event(uuid)'::regprocedure
  ) ilike '%project_chat_messages%'
    and pg_get_functiondef(
      'private.resolve_chat_message_notification_event(uuid)'::regprocedure
    ) ilike '%project_group_chats%'
    and pg_get_functiondef(
      'private.resolve_chat_message_notification_event(uuid)'::regprocedure
    ) ilike '%membership.joined_at <= message_record.created_at%'
    and pg_get_functiondef(
      'private.resolve_chat_message_notification_event(uuid)'::regprocedure
    ) ilike '%message_record.created_at < coalesce%'
    and pg_get_functiondef(
      'private.resolve_chat_message_notification_event(uuid)'::regprocedure
    ) ilike '%<> message_record.sender_profile_id%',
  'canonical message state, half-open membership intervals, and sender exclusion drive fan-out'
);
select ok(
  pg_get_functiondef(
    'public.process_notification_outbox_batch(integer)'::regprocedure
  ) ilike '%project.chat_message_sent%'
    and pg_get_functiondef(
      'public.process_notification_outbox_batch(integer)'::regprocedure
    ) ilike '%for resolved_event in%'
    and pg_get_functiondef(
      'public.process_notification_outbox_batch(integer)'::regprocedure
    ) ilike '%for update of event skip locked%',
  'notifications.v1 uses bounded locked multi-recipient processing'
);
select ok(
  pg_get_functiondef(
    'public.process_push_outbox_batch(integer)'::regprocedure
  ) ilike '%project.chat_message_sent%'
    and pg_get_functiondef(
      'public.process_push_outbox_batch(integer)'::regprocedure
    ) ilike '%for resolved_event in%'
    and pg_get_functiondef(
      'public.process_push_outbox_batch(integer)'::regprocedure
    ) ilike '%preference.push_enabled%'
    and pg_get_functiondef(
      'public.process_push_outbox_batch(integer)'::regprocedure
    ) not ilike '%preference.in_app_enabled%',
  'push.v1 performs independent multi-recipient preference evaluation'
);

select ok(
  pg_get_function_result(
    'public.list_own_notifications(uuid,integer,timestamptz,uuid)'::regprocedure
  ) like '%chat_id uuid%'
    and pg_get_function_result(
      'public.list_own_notifications(uuid,integer,timestamptz,uuid)'::regprocedure
    ) like '%message_id uuid%'
    and pg_get_function_result(
      'public.list_own_notifications(uuid,integer,timestamptz,uuid)'::regprocedure
    ) not ilike '%body%',
  'the inbox exposes chat/message identifiers without message content'
);
select ok(
  pg_get_function_result(
    'private.claim_push_delivery_targets(text,integer,integer)'::regprocedure
  ) like '%chat_id uuid%'
    and pg_get_function_result(
      'private.claim_push_delivery_targets(text,integer,integer)'::regprocedure
    ) like '%message_id uuid%'
    and pg_get_function_result(
      'private.claim_push_delivery_targets(text,integer,integer)'::regprocedure
    ) not ilike '%body%',
  'the trusted provider claim receives semantic chat context without message content'
);

select is(
  (
    select count(*)
    from information_schema.columns
    where table_schema in ('public', 'private')
      and table_name in (
        'notifications',
        'push_delivery_jobs',
        'push_delivery_targets',
        'push_delivery_attempts'
      )
      and column_name in ('body', 'message_body', 'payload')
  ),
  0::bigint,
  'alert infrastructure has no message-body or raw-payload column'
);

select is(
  (
    select bool_and(procedure.prosecdef)
      and bool_and(array_to_string(procedure.proconfig, ',') = 'search_path=""')
    from pg_proc as procedure
    where procedure.oid in (
      'private.resolve_chat_message_notification_event(uuid)'::regprocedure,
      'private.resolve_notification_event(uuid)'::regprocedure,
      'public.process_notification_outbox_batch(integer)'::regprocedure,
      'public.process_push_outbox_batch(integer)'::regprocedure,
      'public.list_own_notifications(uuid,integer,timestamptz,uuid)'::regprocedure,
      'private.claim_push_delivery_targets(text,integer,integer)'::regprocedure
    )
  ),
  true,
  'every new or replaced privileged boundary fixes an empty search path'
);
select is(
  has_function_privilege(
    'service_role',
    'private.resolve_chat_message_notification_event(uuid)',
    'EXECUTE'
  ) or has_function_privilege(
    'authenticated',
    'private.resolve_chat_message_notification_event(uuid)',
    'EXECUTE'
  ),
  false,
  'private semantic resolvers are not directly callable by client or service credentials'
);

select * from finish();

rollback;
