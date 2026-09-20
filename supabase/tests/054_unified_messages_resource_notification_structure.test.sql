begin;

select no_plan();

select ok(
  to_regprocedure(
    'public.list_own_structured_request_message_items(uuid,integer,timestamptz,text,uuid)'
  ) is not null,
  'the unified structured-request list exists'
);
select ok(
  to_regprocedure(
    'public.get_own_structured_request_message_item(uuid,text,uuid)'
  ) is not null,
  'the discriminator-aware exact request read exists'
);
select ok(
  to_regprocedure(
    'public.list_own_message_chat_items(uuid,integer,timestamptz,text,uuid)'
  ) is not null,
  'the unified chat list exists'
);

select ok(
  pg_get_function_result(
    'public.list_own_structured_request_message_items(uuid,integer,timestamptz,text,uuid)'::regprocedure
  ) like '%item_kind text%'
    and pg_get_function_result(
      'public.list_own_structured_request_message_items(uuid,integer,timestamptz,text,uuid)'::regprocedure
    ) like '%resource_agreement_id uuid%'
    and pg_get_function_result(
      'public.list_own_structured_request_message_items(uuid,integer,timestamptz,text,uuid)'::regprocedure
    ) like '%project_creator_profile_id uuid%',
  'the unified request row exposes a strict discriminator and both domain branches'
);
select ok(
  pg_get_functiondef(
    'public.list_own_structured_request_message_items(uuid,integer,timestamptz,text,uuid)'::regprocedure
  ) ilike '%resolved_activity_at%item_kind_order%resolved_request_id%'
    and pg_get_functiondef(
      'public.list_own_structured_request_message_items(uuid,integer,timestamptz,text,uuid)'::regprocedure
    ) ilike '%greatest%coordination_closed_at%'
    and pg_get_functiondef(
      'public.list_own_structured_request_message_items(uuid,integer,timestamptz,text,uuid)'::regprocedure
    ) ilike '%coalesce%project_request.resolved_at%project_request.created_at%',
  'the unified request list uses the complete cursor and canonical per-domain activity'
);
select ok(
  pg_get_functiondef(
    'public.list_own_message_chat_items(uuid,integer,timestamptz,text,uuid)'::regprocedure
  ) ilike '%resolved_activity_at%item_kind_order%resolved_chat_id%'
    and pg_get_functiondef(
      'public.list_own_message_chat_items(uuid,integer,timestamptz,text,uuid)'::regprocedure
    ) ilike '%profile_can_read_project_chat_message%'
    and pg_get_functiondef(
      'public.list_own_message_chat_items(uuid,integer,timestamptz,text,uuid)'::regprocedure
    ) ilike '%resource_exchange_agreement_events%',
  'the unified chat list preserves both history frontiers and a complete cursor'
);

select is(
  (
    select bool_and(procedure.prosecdef)
      and bool_and(array_to_string(procedure.proconfig, ',') = 'search_path=""')
    from pg_proc as procedure
    where procedure.oid in (
      'public.list_own_structured_request_message_items(uuid,integer,timestamptz,text,uuid)'::regprocedure,
      'public.get_own_structured_request_message_item(uuid,text,uuid)'::regprocedure,
      'public.list_own_message_chat_items(uuid,integer,timestamptz,text,uuid)'::regprocedure,
      'private.resolve_resource_request_notification_event(uuid)'::regprocedure,
      'private.resolve_resource_chat_notification_event(uuid)'::regprocedure,
      'private.resolve_resource_exchange_notification_event(uuid)'::regprocedure,
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
    'authenticated',
    'public.list_own_structured_request_message_items(uuid,integer,timestamptz,text,uuid)',
    'EXECUTE'
  ) and has_function_privilege(
    'authenticated',
    'public.get_own_structured_request_message_item(uuid,text,uuid)',
    'EXECUTE'
  ) and has_function_privilege(
    'authenticated',
    'public.list_own_message_chat_items(uuid,integer,timestamptz,text,uuid)',
    'EXECUTE'
  ),
  true,
  'authenticated clients may use the three unified read boundaries'
);
select is(
  has_function_privilege(
    'anon',
    'public.list_own_structured_request_message_items(uuid,integer,timestamptz,text,uuid)',
    'EXECUTE'
  ) or has_function_privilege(
    'anon',
    'public.get_own_structured_request_message_item(uuid,text,uuid)',
    'EXECUTE'
  ) or has_function_privilege(
    'anon',
    'public.list_own_message_chat_items(uuid,integer,timestamptz,text,uuid)',
    'EXECUTE'
  ),
  false,
  'anonymous clients cannot use unified private Messages reads'
);

select is(
  (
    select count(*)
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'notifications'
      and column_name in (
        'resource_listing_id',
        'resource_request_id',
        'resource_chat_id',
        'resource_chat_message_id',
        'resource_agreement_id',
        'resource_agreement_event_id'
      )
      and data_type = 'uuid'
  ),
  6::bigint,
  'notifications expose six explicit nullable Resource reference columns'
);
select is(
  (
    select count(*)
    from information_schema.columns
    where table_schema = 'private'
      and table_name = 'push_delivery_jobs'
      and column_name in (
        'resource_listing_id',
        'resource_request_id',
        'resource_chat_id',
        'resource_chat_message_id',
        'resource_agreement_id',
        'resource_agreement_event_id'
      )
      and data_type = 'uuid'
  ),
  6::bigint,
  'provider-neutral push jobs expose the same six Resource references'
);
select is(
  (
    select count(*)
    from pg_constraint
    where (
      conrelid = 'public.notifications'::regclass
      and conname like 'notifications_resource_%_fkey'
      and confdeltype = 'r'
    ) or (
      conrelid = 'private.push_delivery_jobs'::regclass
      and conname like 'push_delivery_jobs_resource_%_fkey'
      and confdeltype = 'r'
    )
  ),
  12::bigint,
  'all Resource notification and push references use restrictive foreign keys'
);
select ok(
  (
    select pg_get_constraintdef(oid)
    from pg_constraint
    where conrelid = 'public.notifications'::regclass
      and conname = 'notifications_reference_shape_valid'
  ) ilike '%resource_listing_id IS NOT NULL%'
    and (
      select pg_get_constraintdef(oid)
      from pg_constraint
      where conrelid = 'public.notifications'::regclass
        and conname = 'notifications_reference_shape_valid'
    ) ilike '%project_id IS NULL%'
    and (
      select pg_get_constraintdef(oid)
      from pg_constraint
      where conrelid = 'public.notifications'::regclass
        and conname = 'notifications_reference_shape_valid'
    ) ilike '%resource_agreement_event_id IS NOT NULL%',
  'notification constraints enforce strict Project/Resource and event shapes'
);
select ok(
  (
    select pg_get_constraintdef(oid)
    from pg_constraint
    where conrelid = 'private.push_delivery_jobs'::regclass
      and conname = 'push_delivery_jobs_resource_shape_valid'
  ) ilike '%category_slug%resources%'
    and (
      select pg_get_constraintdef(oid)
      from pg_constraint
      where conrelid = 'private.push_delivery_jobs'::regclass
        and conname = 'push_delivery_jobs_resource_shape_valid'
    ) ilike '%resource_chat_message_id IS NOT NULL%',
  'push jobs mirror strict body-free Resource destination shapes'
);

select ok(
  to_regprocedure(
    'private.resolve_resource_request_notification_event(uuid)'
  ) is not null
    and to_regprocedure(
      'private.resolve_resource_chat_notification_event(uuid)'
    ) is not null
    and to_regprocedure(
      'private.resolve_resource_exchange_notification_event(uuid)'
    ) is not null,
  'the three canonical Resource event resolvers exist'
);
select ok(
  pg_get_functiondef(
    'private.resolve_resource_request_notification_event(uuid)'::regprocedure
  ) ilike '%jsonb_object_keys%'
    and pg_get_functiondef(
      'private.resolve_resource_chat_notification_event(uuid)'::regprocedure
    ) ilike '%resource_request_chat_messages%'
    and pg_get_functiondef(
      'private.resolve_resource_exchange_notification_event(uuid)'::regprocedure
    ) ilike '%resource_exchange_agreement_events%',
  'Resource resolvers validate exact payloads against canonical source rows'
);
select is(
  has_function_privilege(
    'service_role',
    'private.resolve_resource_request_notification_event(uuid)',
    'EXECUTE'
  ) or has_function_privilege(
    'authenticated',
    'private.resolve_resource_request_notification_event(uuid)',
    'EXECUTE'
  ) or has_function_privilege(
    'service_role',
    'private.resolve_resource_chat_notification_event(uuid)',
    'EXECUTE'
  ) or has_function_privilege(
    'service_role',
    'private.resolve_resource_exchange_notification_event(uuid)',
    'EXECUTE'
  ),
  false,
  'Resource resolvers are not directly exposed to client or broad service roles'
);

select ok(
  pg_get_indexdef(
    'private.outbox_events_notification_sources_available_idx'::regclass
  ) like '%resource_listing.request_created%'
    and pg_get_indexdef(
      'private.outbox_events_notification_sources_available_idx'::regclass
    ) like '%resource_chat.message_sent%'
    and pg_get_indexdef(
      'private.outbox_events_notification_sources_available_idx'::regclass
    ) like '%resource_exchange.agreement_completed%'
    and pg_get_indexdef(
      'private.outbox_events_notification_sources_available_idx'::regclass
    ) not like '%resource_exchange.agreement_created%'
    and pg_get_indexdef(
      'private.outbox_events_notification_sources_available_idx'::regclass
    ) not like '%resource_exchange.terms_superseded%',
  'the partial projector index contains exactly supported Resource source families'
);
select ok(
  pg_get_functiondef(
    'public.process_notification_outbox_batch(integer)'::regprocedure
  ) ilike '%for update of event skip locked%'
    and pg_get_functiondef(
      'public.process_push_outbox_batch(integer)'::regprocedure
    ) ilike '%for update of event skip locked%'
    and pg_get_functiondef(
      'public.process_notification_outbox_batch(integer)'::regprocedure
    ) ilike '%notifications.v1%'
    and pg_get_functiondef(
      'public.process_push_outbox_batch(integer)'::regprocedure
    ) ilike '%push.v1%',
  'both expanded projectors remain bounded, independently receipted, and lock-safe'
);
select ok(
  pg_get_function_result(
    'public.list_own_notifications(uuid,integer,timestamptz,uuid)'::regprocedure
  ) like '%resource_listing_title text%'
    and pg_get_function_result(
      'public.list_own_notifications(uuid,integer,timestamptz,uuid)'::regprocedure
    ) like '%resource_exchange_event_kind text%'
    and pg_get_function_result(
      'public.list_own_notifications(uuid,integer,timestamptz,uuid)'::regprocedure
    ) not ilike '%body%'
    and pg_get_function_result(
      'public.list_own_notifications(uuid,integer,timestamptz,uuid)'::regprocedure
    ) not ilike '%private_note%',
  'the inbox returns safe Resource context without private text'
);
select ok(
  pg_get_function_result(
    'private.claim_push_delivery_targets(text,integer,integer)'::regprocedure
  ) like '%resource_agreement_event_id uuid%'
    and pg_get_function_result(
      'private.claim_push_delivery_targets(text,integer,integer)'::regprocedure
    ) not ilike '%body%'
    and pg_get_function_result(
      'private.claim_push_delivery_targets(text,integer,integer)'::regprocedure
    ) not ilike '%terms%',
  'the trusted worker receives Resource routing identifiers without private content'
);
select is(
  (
    select count(*)
    from information_schema.columns
    where table_schema in ('public', 'private')
      and table_name in ('notifications', 'push_delivery_jobs')
      and column_name in (
        'body',
        'message_body',
        'request_message',
        'private_note',
        'payload',
        'provider_token'
      )
  ),
  0::bigint,
  'notification and semantic push rows contain no private content or provider token'
);

select * from finish();

rollback;
