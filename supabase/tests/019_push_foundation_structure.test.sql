begin;

select no_plan();

select has_table(
  'private',
  'push_installations',
  'private app-installation registration state exists'
);
select has_table(
  'private',
  'push_delivery_jobs',
  'private recipient-level push jobs exist'
);
select ok(
  to_regclass('public.push_installations') is null
    and to_regclass('public.push_delivery_jobs') is null,
  'push operational tables are absent from the exposed public schema'
);

select columns_are(
  'private',
  'push_installations',
  array[
    'installation_id',
    'profile_id',
    'platform',
    'provider',
    'provider_token',
    'created_at',
    'updated_at',
    'last_registered_at',
    'disabled_at',
    'token_version'
  ],
  'installation state is narrow and provider registration remains private'
);
select columns_are(
  'private',
  'push_delivery_jobs',
  array[
    'id',
    'source_outbox_event_id',
    'recipient_profile_id',
    'category_slug',
    'notification_kind',
    'actor_profile_id',
    'project_id',
    'project_kind',
    'request_id',
    'membership_id',
    'destination_kind',
    'created_at',
    'available_at',
    'fanout_at',
    'completed_at',
    'completion_reason',
    'chat_id',
    'message_id',
    'resource_listing_id',
    'resource_request_id',
    'resource_chat_id',
    'resource_chat_message_id',
    'resource_agreement_id',
    'resource_agreement_event_id'
  ],
  'push jobs contain recipient-level semantic identifiers and scheduling only'
);
select col_is_pk(
  'private',
  'push_installations',
  'installation_id',
  'the opaque installation UUID is the stable installation identity'
);
select col_is_pk(
  'private',
  'push_delivery_jobs',
  'id',
  'push jobs have stable UUID identities'
);
select col_is_null(
  'private',
  'push_installations',
  'provider_token',
  'disabled installations can clear their provider token'
);
select col_is_null(
  'private',
  'push_delivery_jobs',
  'project_id',
  'future standalone notification categories are not forced into a project'
);
select col_type_is(
  'private',
  'push_delivery_jobs',
  'available_at',
  'timestamp with time zone',
  'future worker availability is timezone-aware'
);

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'private.push_installations'::regclass
      and conname = 'push_installations_token_state_valid'
      and contype = 'c'
  ),
  'active installation tokens are bounded and disabled rows clear them'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'private.push_delivery_jobs'::regclass
      and conname = 'push_delivery_jobs_participation_shape_valid'
      and contype = 'c'
      and pg_get_constraintdef(oid) like '%participation_request_received%'
      and pg_get_constraintdef(oid) like '%participant_removed%'
  ),
  'all current participation kinds have constrained semantic reference shapes'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'private.push_delivery_jobs'::regclass
      and conname = 'push_delivery_jobs_source_recipient_kind_unique'
      and contype = 'u'
  ),
  'one recipient-level semantic job is enforced per source event'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'private.push_delivery_jobs'::regclass
      and conname = 'push_delivery_jobs_chat_shape_valid'
      and contype = 'c'
      and pg_get_constraintdef(oid) like '%chat_message_received%'
      and pg_get_constraintdef(oid) like '%project_chat%'
  ),
  'chat jobs require their complete provider-neutral semantic shape'
);

select ok(
  to_regclass('private.push_installations_profile_id_idx') is not null,
  'installation profile foreign-key operations are indexed'
);
select ok(
  to_regclass('private.push_installations_active_profile_platform_idx') is not null,
  'future active-installation fan-out has a targeted partial index'
);
select ok(
  to_regclass('private.push_installations_active_provider_token_unique')
    is not null,
  'one active installation owns a provider token'
);
select ok(
  to_regclass('private.push_delivery_jobs_available_idx') is not null,
  'future push workers can scan available jobs efficiently'
);
select ok(
  to_regclass('private.push_delivery_jobs_recipient_created_at_idx') is not null,
  'recipient job history and foreign-key operations are indexed'
);
select ok(
  to_regclass('private.push_delivery_jobs_category_slug_idx') is not null
    and to_regclass('private.push_delivery_jobs_project_id_idx') is not null
    and to_regclass('private.push_delivery_jobs_actor_profile_id_idx') is not null
    and to_regclass('private.push_delivery_jobs_request_id_idx') is not null
    and to_regclass('private.push_delivery_jobs_membership_id_idx') is not null
    and to_regclass('private.push_delivery_jobs_chat_id_idx') is not null
    and to_regclass('private.push_delivery_jobs_message_id_idx') is not null,
  'push-job semantic foreign-key paths are indexed'
);

select ok(
  to_regprocedure(
    'private.resolve_participation_notification_event(uuid)'
  ) is not null,
  'the shared participation notification resolver exists'
);
select ok(
  to_regprocedure(
    'private.resolve_chat_message_notification_event(uuid)'
  ) is not null
    and to_regprocedure('private.resolve_notification_event(uuid)') is not null,
  'chat fan-out and shared multi-recipient notification resolvers exist'
);
select ok(
  to_regprocedure(
    'public.register_own_push_installation(uuid,uuid,text,text)'
  ) is not null,
  'the expected-identity-bound registration RPC exists'
);
select ok(
  to_regprocedure(
    'public.unregister_own_push_installation(uuid,uuid)'
  ) is not null,
  'the expected-identity-bound unregister RPC exists'
);
select ok(
  to_regprocedure('public.process_push_outbox_batch(integer)') is not null,
  'the push.v1 service projector exists'
);
select ok(
  pg_get_function_result(
    'public.register_own_push_installation(uuid,uuid,text,text)'::regprocedure
  ) not ilike '%token%',
  'registration output does not expose the provider token'
);
select ok(
  pg_get_function_result(
    'private.resolve_participation_notification_event(uuid)'::regprocedure
  ) like '%source_created_at timestamp with time zone%',
  'the shared resolver returns canonical semantic facts and source chronology'
);

select ok(
  pg_get_functiondef(
    'public.process_notification_outbox_batch(integer)'::regprocedure
  ) ilike '%private.resolve_notification_event%'
    and pg_get_functiondef(
      'public.process_notification_outbox_batch(integer)'::regprocedure
    ) not ilike '%source_event.payload%',
  'notifications.v1 now consumes the shared resolver without duplicating payload mapping'
);
select ok(
  pg_get_functiondef(
    'public.process_push_outbox_batch(integer)'::regprocedure
  ) ilike '%private.resolve_notification_event%'
    and pg_get_functiondef(
      'public.process_push_outbox_batch(integer)'::regprocedure
    ) ilike '%preference.push_enabled%'
    and pg_get_functiondef(
      'public.process_push_outbox_batch(integer)'::regprocedure
    ) not ilike '%preference.in_app_enabled%'
    and pg_get_functiondef(
      'public.process_push_outbox_batch(integer)'::regprocedure
    ) not ilike '%public.notifications%'
    and pg_get_functiondef(
      'public.process_push_outbox_batch(integer)'::regprocedure
    ) not ilike '%push_installations%'
    and pg_get_functiondef(
      'public.process_push_outbox_batch(integer)'::regprocedure
    ) ilike '%for update of event skip locked%'
    and pg_get_functiondef(
      'public.process_push_outbox_batch(integer)'::regprocedure
    ) ilike '%push.v1%',
  'push.v1 is channel-independent, installation-independent, and concurrency-safe'
);

select is(
  (
    select count(*)
    from information_schema.columns
    where table_schema = 'public'
      and column_name = 'provider_token'
  ),
  0::bigint,
  'provider tokens are absent from the generated public-schema surface'
);
select is(
  (
    select count(*)
    from information_schema.columns
    where table_schema = 'private'
      and table_name = 'push_delivery_jobs'
      and column_name in ('provider_token', 'payload', 'request_message')
  ),
  0::bigint,
  'push jobs cannot copy tokens, raw source payloads, or request messages'
);

select is(
  (
    select bool_and(procedure.prosecdef)
    from pg_proc as procedure
    where procedure.oid in (
      'private.require_push_identity(uuid)'::regprocedure,
      'private.resolve_participation_notification_event(uuid)'::regprocedure,
      'private.resolve_chat_message_notification_event(uuid)'::regprocedure,
      'private.resolve_notification_event(uuid)'::regprocedure,
      'public.register_own_push_installation(uuid,uuid,text,text)'::regprocedure,
      'public.unregister_own_push_installation(uuid,uuid)'::regprocedure,
      'public.process_notification_outbox_batch(integer)'::regprocedure,
      'public.process_push_outbox_batch(integer)'::regprocedure
    )
  ),
  true,
  'all privileged push and shared-resolution boundaries are security definers'
);
select is(
  (
    select bool_and(array_to_string(procedure.proconfig, ',') = 'search_path=""')
    from pg_proc as procedure
    where procedure.oid in (
      'private.require_push_identity(uuid)'::regprocedure,
      'private.resolve_participation_notification_event(uuid)'::regprocedure,
      'private.resolve_chat_message_notification_event(uuid)'::regprocedure,
      'private.resolve_notification_event(uuid)'::regprocedure,
      'public.register_own_push_installation(uuid,uuid,text,text)'::regprocedure,
      'public.unregister_own_push_installation(uuid,uuid)'::regprocedure,
      'public.process_notification_outbox_batch(integer)'::regprocedure,
      'public.process_push_outbox_batch(integer)'::regprocedure
    )
  ),
  true,
  'all privileged push and shared-resolution functions fix an empty search path'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.register_own_push_installation(uuid,uuid,text,text)',
    'EXECUTE'
  ),
  true,
  'authenticated clients can register their installation'
);
select is(
  has_function_privilege(
    'anon',
    'public.register_own_push_installation(uuid,uuid,text,text)',
    'EXECUTE'
  ),
  false,
  'anonymous clients cannot register installations'
);
select is(
  has_function_privilege(
    'authenticated',
    'public.unregister_own_push_installation(uuid,uuid)',
    'EXECUTE'
  ),
  true,
  'authenticated clients can unregister only through the narrow RPC'
);
select is(
  has_function_privilege(
    'authenticated',
    'public.process_push_outbox_batch(integer)',
    'EXECUTE'
  ),
  false,
  'authenticated clients cannot execute the push projector'
);
select is(
  has_function_privilege(
    'service_role',
    'public.process_push_outbox_batch(integer)',
    'EXECUTE'
  ),
  true,
  'the service role can execute only the narrow push projector boundary'
);
select is(
  has_function_privilege(
    'service_role',
    'private.resolve_participation_notification_event(uuid)',
    'EXECUTE'
  ) or has_function_privilege(
    'service_role',
    'private.resolve_chat_message_notification_event(uuid)',
    'EXECUTE'
  ) or has_function_privilege(
    'service_role',
    'private.resolve_notification_event(uuid)',
    'EXECUTE'
  ),
  false,
  'service credentials cannot bypass the public projectors through private resolvers'
);

select is(
  has_table_privilege(
    'authenticated',
    'private.push_installations',
    'SELECT'
  ),
  false,
  'authenticated clients cannot enumerate private provider registrations'
);
select is(
  has_table_privilege(
    'service_role',
    'private.push_installations',
    'SELECT'
  ),
  false,
  'service credentials receive no broad installation-table access'
);
select is(
  has_table_privilege(
    'authenticated',
    'private.push_delivery_jobs',
    'SELECT'
  ),
  false,
  'authenticated clients cannot read private push jobs'
);
select is(
  has_table_privilege(
    'service_role',
    'private.push_delivery_jobs',
    'INSERT'
  ),
  false,
  'service credentials cannot fabricate push jobs outside the projector'
);

select * from finish();

rollback;
