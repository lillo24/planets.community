begin;

-- Renumbered during stack integration to preserve globally unique pgTAP order.

select no_plan();

select is(
  (
    select count(*)
    from public.notification_categories
    where slug = 'matching'
      and default_in_app_enabled
      and default_push_enabled
      and user_configurable
  ),
  1::bigint,
  'B1 reuses the one existing globally configurable matching category'
);

select ok(
  (
    select pg_get_constraintdef(oid)
    from pg_constraint
    where conrelid = 'public.notifications'::regclass
      and conname = 'notifications_kind_valid'
  ) like '%matching_available%',
  'matching_available is an allowed notification kind'
);
select ok(
  (
    select pg_get_constraintdef(oid)
    from pg_constraint
    where conrelid = 'public.notifications'::regclass
      and conname = 'notifications_destination_kind_valid'
  ) like '%matching_result%',
  'matching_result is an allowed notification destination'
);
select ok(
  (
    select pg_get_constraintdef(oid)
    from pg_constraint
    where conrelid = 'public.notifications'::regclass
      and conname = 'notifications_category_matches_kind'
  ) like '%category_slug = ''matching''%matching_available%',
  'matching category and kind are coupled'
);
select ok(
  (
    select pg_get_constraintdef(oid)
    from pg_constraint
    where conrelid = 'public.notifications'::regclass
      and conname = 'notifications_destination_matches_kind'
  ) like '%matching_available%matching_result%',
  'matching kind and destination are coupled'
);
select ok(
  (
    select pg_get_constraintdef(oid)
    from pg_constraint
    where conrelid = 'public.notifications'::regclass
      and conname = 'notifications_reference_shape_valid'
  ) like '%category_slug = ''matching''%'
    and (
      select pg_get_constraintdef(oid)
      from pg_constraint
      where conrelid = 'public.notifications'::regclass
        and conname = 'notifications_reference_shape_valid'
    ) like '%actor_profile_id IS NULL%'
    and (
      select pg_get_constraintdef(oid)
      from pg_constraint
      where conrelid = 'public.notifications'::regclass
        and conname = 'notifications_reference_shape_valid'
    ) like '%resource_listing_id IS NOT NULL%',
  'matching notifications require only recipient-owned listing context'
);
select ok(
  (
    select pg_get_constraintdef(oid)
    from pg_constraint
    where conrelid = 'private.push_delivery_jobs'::regclass
      and conname = 'push_delivery_jobs_resource_shape_valid'
  ) like '%category_slug = ''matching''%'
    and (
      select pg_get_constraintdef(oid)
      from pg_constraint
      where conrelid = 'private.push_delivery_jobs'::regclass
        and conname = 'push_delivery_jobs_resource_shape_valid'
    ) like '%resource_listing_id IS NOT NULL%'
    and (
      select pg_get_constraintdef(oid)
      from pg_constraint
      where conrelid = 'private.push_delivery_jobs'::regclass
        and conname = 'push_delivery_jobs_resource_shape_valid'
    ) like '%resource_request_id IS NULL%',
  'matching push jobs require the same listing-only semantic context'
);

select ok(
  to_regclass('public.notifications_matching_recipient_listing_unique')
    is not null,
  'matching notifications have a recipient/listing dedupe index'
);
select ok(
  (
    select indexdef
    from pg_indexes
    where schemaname = 'public'
      and indexname = 'notifications_matching_recipient_listing_unique'
  ) like 'CREATE UNIQUE INDEX%recipient_profile_id, resource_listing_id, notification_kind%WHERE ((category_slug = ''matching''::text) AND (notification_kind = ''matching_available''::text))',
  'notification dedupe is unique and limited to matching delivery'
);
select ok(
  to_regclass(
    'private.push_delivery_jobs_matching_recipient_listing_unique'
  ) is not null,
  'matching push jobs have a recipient/listing dedupe index'
);
select ok(
  (
    select indexdef
    from pg_indexes
    where schemaname = 'private'
      and indexname =
        'push_delivery_jobs_matching_recipient_listing_unique'
  ) like 'CREATE UNIQUE INDEX%recipient_profile_id, resource_listing_id, notification_kind%WHERE ((category_slug = ''matching''::text) AND (notification_kind = ''matching_available''::text))',
  'push dedupe is unique and limited to matching delivery'
);

select ok(
  to_regprocedure(
    'private.resolve_saved_search_matching_notification_event(uuid)'
  ) is not null,
  'the private saved-search matching resolver exists'
);
select is(
  (
    select procedure.prosecdef
    from pg_proc as procedure
    where procedure.oid =
      'private.resolve_saved_search_matching_notification_event(uuid)'
        ::regprocedure
  ),
  true,
  'the resolver is an explicit privileged boundary'
);
select is(
  (
    select array_to_string(procedure.proconfig, ',')
    from pg_proc as procedure
    where procedure.oid =
      'private.resolve_saved_search_matching_notification_event(uuid)'
        ::regprocedure
  ),
  'search_path=""',
  'the resolver fixes an empty search path'
);
select is(
  has_function_privilege(
    'service_role',
    'private.resolve_saved_search_matching_notification_event(uuid)',
    'EXECUTE'
  ) or has_function_privilege(
    'authenticated',
    'private.resolve_saved_search_matching_notification_event(uuid)',
    'EXECUTE'
  ) or has_function_privilege(
    'anon',
    'private.resolve_saved_search_matching_notification_event(uuid)',
    'EXECUTE'
  ),
  false,
  'the private resolver has no direct API-role execute grant'
);

select ok(
  pg_get_functiondef(
    'private.resolve_saved_search_matching_notification_event(uuid)'
      ::regprocedure
  ) like '%jsonb_object_keys%'
    and pg_get_functiondef(
      'private.resolve_saved_search_matching_notification_event(uuid)'
        ::regprocedure
    ) like '%resource_saved_search_listing_matches%'
    and pg_get_functiondef(
      'private.resolve_saved_search_matching_notification_event(uuid)'
        ::regprocedure
    ) like '%resource_listing_matches_saved_search_filters%',
  'the resolver validates exact payloads, private provenance, and current F1 filters'
);
select ok(
  pg_get_functiondef(
    'private.resolve_notification_event(uuid)'::regprocedure
  ) like '%resource_saved_search.matched%resolve_saved_search_matching_notification_event%',
  'the shared provider-neutral resolver routes saved-search match events'
);
select ok(
  pg_get_indexdef(
    'private.outbox_events_notification_sources_available_idx'::regclass
  ) like '%resource_saved_search.matched%',
  'the notification-source partial index includes saved-search matches'
);
select ok(
  pg_get_functiondef(
    'public.process_notification_outbox_batch(integer)'::regprocedure
  ) like '%resource_saved_search.matched%'
    and pg_get_functiondef(
      'public.process_push_outbox_batch(integer)'::regprocedure
    ) like '%resource_saved_search.matched%',
  'both independent projectors consume future saved-search match events'
);
select ok(
  pg_get_functiondef(
    'public.process_notification_outbox_batch(integer)'::regprocedure
  ) like '%if resolved_event.category_slug = ''matching''%on conflict do nothing%'
    and pg_get_functiondef(
      'public.process_push_outbox_batch(integer)'::regprocedure
    ) like '%if resolved_event.category_slug = ''matching''%on conflict do nothing%',
  'only matching inserts use cross-source conflict suppression'
);
select ok(
  pg_get_functiondef(
    'public.process_notification_outbox_batch(integer)'::regprocedure
  ) like '%for update of event skip locked%'
    and pg_get_functiondef(
      'public.process_push_outbox_batch(integer)'::regprocedure
    ) like '%for update of event skip locked%',
  'both projectors retain non-blocking worker claims'
);

select is(
  (
    select count(*)
    from information_schema.columns
    where table_schema in ('public', 'private')
      and table_name in ('notifications', 'push_delivery_jobs')
      and column_name in (
        'saved_search_id',
        'saved_search_match_id',
        'query',
        'locality',
        'description',
        'body'
      )
  ),
  0::bigint,
  'delivery state stores no saved-search identifiers or private/search copy'
);
select ok(
  pg_get_function_result(
    'public.list_own_notifications(uuid,integer,timestamptz,uuid)'::regprocedure
  ) like '%resource_listing_id uuid%'
    and pg_get_function_result(
      'public.list_own_notifications(uuid,integer,timestamptz,uuid)'::regprocedure
    ) like '%resource_listing_title text%'
    and pg_get_function_result(
      'public.list_own_notifications(uuid,integer,timestamptz,uuid)'::regprocedure
    ) not like '%saved_search%',
  'the existing inbox contract already exposes only safe listing context'
);

select * from finish();

rollback;
