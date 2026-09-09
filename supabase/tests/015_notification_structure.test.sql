begin;

select no_plan();

select has_table(
  'public',
  'notification_categories',
  'the controlled notification category catalog exists'
);
select has_table(
  'public',
  'profile_notification_preferences',
  'per-profile notification overrides exist'
);
select has_table(
  'public',
  'notifications',
  'recipient-owned notification state exists'
);
select has_table(
  'private',
  'outbox_consumer_receipts',
  'generic private outbox consumer receipts exist'
);

select columns_are(
  'public',
  'notification_categories',
  array[
    'slug',
    'sort_order',
    'default_in_app_enabled',
    'default_push_enabled',
    'user_configurable'
  ],
  'category state is narrow and channel-ready'
);
select columns_are(
  'public',
  'profile_notification_preferences',
  array[
    'profile_id',
    'category_slug',
    'in_app_enabled',
    'push_enabled',
    'created_at',
    'updated_at'
  ],
  'preference overrides contain only owner, category, channels, and timestamps'
);
select columns_are(
  'public',
  'notifications',
  array[
    'id',
    'recipient_profile_id',
    'category_slug',
    'notification_kind',
    'source_outbox_event_id',
    'project_id',
    'actor_profile_id',
    'request_id',
    'membership_id',
    'destination_kind',
    'created_at',
    'read_at'
  ],
  'notification rows persist semantic identifiers and read state only'
);
select columns_are(
  'private',
  'outbox_consumer_receipts',
  array['outbox_event_id', 'consumer_key', 'processed_at'],
  'consumer receipts stay generic and minimal'
);

select col_is_pk(
  'public',
  'notification_categories',
  'slug',
  'category slugs are stable primary keys'
);
select col_is_pk('public', 'notifications', 'id', 'notification IDs are stable');
select col_type_is(
  'public',
  'notifications',
  'created_at',
  'timestamp with time zone',
  'notification chronology is timezone-aware'
);
select col_type_is(
  'public',
  'notifications',
  'read_at',
  'timestamp with time zone',
  'notification read state is timezone-aware'
);

select is(
  (
    select count(*)
    from public.notification_categories
  ),
  5::bigint,
  'the initial controlled category set contains exactly five entries'
);
select set_eq(
  $$
    select slug
    from public.notification_categories
  $$,
  $$
    values
      ('participation'::text),
      ('project_activity'::text),
      ('matching'::text),
      ('chat'::text),
      ('resources'::text)
  $$,
  'the accepted category slugs are centralized without fabricated events'
);
select is(
  (
    select bool_and(
      default_in_app_enabled
      and default_push_enabled
      and user_configurable
    )
    from public.notification_categories
  ),
  true,
  'the initial catalog defaults both future channels on and permits overrides'
);

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.profile_notification_preferences'::regclass
      and conname = 'profile_notification_preferences_pkey'
      and contype = 'p'
  ),
  'one profile/category has at most one preference override'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.notifications'::regclass
      and conname = 'notifications_source_recipient_kind_unique'
      and contype = 'u'
  ),
  'notification source, recipient, and kind are database-unique'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.notifications'::regclass
      and conname = 'notifications_destination_kind_valid'
      and contype = 'c'
      and pg_get_constraintdef(oid) like '%participation_request%'
  ),
  'semantic destination kinds include the structured participation-request target'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.notifications'::regclass
      and conname = 'notifications_destination_matches_kind'
      and contype = 'c'
      and pg_get_constraintdef(oid) like '%participation_request%'
  ),
  'notification kinds are constrained to their canonical semantic destination'
);
select ok(
  pg_get_function_result(
    'public.list_own_notifications(uuid,integer,timestamptz,uuid)'::regprocedure
  ) like '%request_id uuid%',
  'the inbox contract returns the canonical request target identifier'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.notifications'::regclass
      and conname = 'notifications_source_outbox_event_id_fkey'
      and contype = 'f'
  ),
  'notifications retain canonical private outbox provenance'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'private.outbox_consumer_receipts'::regclass
      and conname = 'outbox_consumer_receipts_pkey'
      and contype = 'p'
  ),
  'one event/consumer receipt is enforced'
);

select is(
  (
    select relrowsecurity
    from pg_class
    where oid = 'public.notification_categories'::regclass
  ),
  true,
  'category catalog RLS is enabled'
);
select is(
  (
    select relrowsecurity
    from pg_class
    where oid = 'public.profile_notification_preferences'::regclass
  ),
  true,
  'preference RLS is enabled'
);
select is(
  (
    select relrowsecurity
    from pg_class
    where oid = 'public.notifications'::regclass
  ),
  true,
  'notification RLS is enabled'
);
select is(
  (
    select count(*)
    from pg_policy
    where polrelid in (
      'public.notification_categories'::regclass,
      'public.profile_notification_preferences'::regclass,
      'public.notifications'::regclass
    )
  ),
  0::bigint,
  'notification tables rely on narrow RPCs instead of direct policies'
);

select ok(
  to_regclass('public.notifications_recipient_created_at_idx') is not null,
  'inbox keyset pagination has a recipient chronology index'
);
select ok(
  to_regclass('public.notifications_recipient_unread_idx') is not null,
  'unread counts have a recipient partial index'
);
select ok(
  to_regclass('private.outbox_events_notification_sources_available_idx')
    is not null,
  'the projector can skip unsupported outbox events efficiently'
);
select ok(
  to_regclass('private.outbox_consumer_receipts_consumer_processed_idx')
    is not null,
  'consumer-specific receipt inspection is indexed'
);

select ok(
  to_regprocedure('public.list_own_notification_preferences(uuid)') is not null,
  'the effective preference read exists'
);
select ok(
  to_regprocedure(
    'public.set_own_notification_preference(uuid,text,boolean,boolean)'
  ) is not null,
  'the single-category preference mutation exists'
);
select ok(
  to_regprocedure(
    'public.list_own_notifications(uuid,integer,timestamptz,uuid)'
  ) is not null,
  'the paginated inbox read exists'
);
select ok(
  to_regprocedure('public.get_own_unread_notification_count(uuid)') is not null,
  'the unread count operation exists'
);
select ok(
  to_regprocedure('public.mark_notification_read(uuid,uuid)') is not null,
  'the single-notification read operation exists'
);
select ok(
  to_regprocedure('public.mark_all_notifications_read(uuid)') is not null,
  'the mark-all operation exists'
);
select ok(
  to_regprocedure('public.process_notification_outbox_batch(integer)') is not null,
  'the service projector boundary exists'
);

select is(
  (
    select bool_and(procedure.prosecdef)
    from pg_proc as procedure
    where procedure.oid in (
      'public.list_own_notification_preferences(uuid)'::regprocedure,
      'public.set_own_notification_preference(uuid,text,boolean,boolean)'::regprocedure,
      'public.list_own_notifications(uuid,integer,timestamptz,uuid)'::regprocedure,
      'public.get_own_unread_notification_count(uuid)'::regprocedure,
      'public.mark_notification_read(uuid,uuid)'::regprocedure,
      'public.mark_all_notifications_read(uuid)'::regprocedure,
      'public.process_notification_outbox_batch(integer)'::regprocedure
    )
  ),
  true,
  'notification client and service boundaries deliberately use security definer'
);
select is(
  (
    select bool_and(array_to_string(procedure.proconfig, ',') = 'search_path=""')
    from pg_proc as procedure
    where procedure.oid in (
      'public.list_own_notification_preferences(uuid)'::regprocedure,
      'public.set_own_notification_preference(uuid,text,boolean,boolean)'::regprocedure,
      'public.list_own_notifications(uuid,integer,timestamptz,uuid)'::regprocedure,
      'public.get_own_unread_notification_count(uuid)'::regprocedure,
      'public.mark_notification_read(uuid,uuid)'::regprocedure,
      'public.mark_all_notifications_read(uuid)'::regprocedure,
      'public.process_notification_outbox_batch(integer)'::regprocedure
    )
  ),
  true,
  'all notification security definers fix an empty search path'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.list_own_notifications(uuid,integer,timestamptz,uuid)',
    'EXECUTE'
  ),
  true,
  'authenticated clients can use the inbox boundary'
);
select is(
  has_function_privilege(
    'anon',
    'public.list_own_notifications(uuid,integer,timestamptz,uuid)',
    'EXECUTE'
  ),
  false,
  'anonymous clients cannot use the inbox boundary'
);
select is(
  has_function_privilege(
    'authenticated',
    'public.process_notification_outbox_batch(integer)',
    'EXECUTE'
  ),
  false,
  'authenticated clients cannot execute the trusted projector'
);
select is(
  has_function_privilege(
    'anon',
    'public.process_notification_outbox_batch(integer)',
    'EXECUTE'
  ),
  false,
  'anonymous clients cannot execute the trusted projector'
);
select is(
  has_function_privilege(
    'service_role',
    'public.process_notification_outbox_batch(integer)',
    'EXECUTE'
  ),
  true,
  'only the service role receives the projector grant'
);
select is(
  has_table_privilege('authenticated', 'public.notifications', 'SELECT'),
  false,
  'authenticated clients cannot bypass the normalized inbox read'
);
select is(
  has_table_privilege('authenticated', 'public.notifications', 'INSERT'),
  false,
  'authenticated clients cannot fabricate notifications'
);
select is(
  has_table_privilege(
    'authenticated',
    'public.profile_notification_preferences',
    'UPDATE'
  ),
  false,
  'authenticated clients cannot bypass expected-identity preference updates'
);
select is(
  has_table_privilege(
    'service_role',
    'private.outbox_consumer_receipts',
    'INSERT'
  ),
  false,
  'service credentials cannot write arbitrary receipts outside the projector'
);
select is(
  has_function_privilege(
    'authenticated',
    'private.require_notification_identity(uuid)',
    'EXECUTE'
  ),
  false,
  'clients cannot invoke private notification helpers'
);

select * from finish();

rollback;
