begin;

select no_plan();

insert into auth.users (id, email)
values
  ('54000000-0000-4000-8000-000000000001', 'unified-owner@planets.invalid'),
  ('54000000-0000-4000-8000-000000000002', 'unified-requester@planets.invalid'),
  ('54000000-0000-4000-8000-000000000003', 'unified-unrelated@planets.invalid');

insert into public.profiles (id, display_name)
values
  ('54000000-0000-4000-8000-000000000001', 'Unified Owner'),
  ('54000000-0000-4000-8000-000000000002', 'Unified Requester'),
  ('54000000-0000-4000-8000-000000000003', 'Unified Unrelated');

insert into public.proposals (
  id,
  creator_profile_id,
  lifecycle_state,
  title,
  starts_at,
  ends_at,
  event_timezone,
  published_at
)
values (
  '54000000-0000-4000-8000-000000000010',
  '54000000-0000-4000-8000-000000000001',
  'published',
  'Unified Project chat',
  '2098-01-01 10:00+00',
  '2098-01-01 12:00+00',
  'Europe/Rome',
  statement_timestamp()
);

insert into public.project_join_requests (
  id,
  project_id,
  requester_profile_id,
  status,
  request_message,
  created_at,
  resolved_at,
  resolved_by_profile_id
)
values (
  '54000000-0000-4000-8000-000000000100',
  '54000000-0000-4000-8000-000000000010',
  '54000000-0000-4000-8000-000000000002',
  'accepted',
  'Private Project request text',
  '2026-09-20 08:00+00',
  '2026-09-20 09:00+00',
  '54000000-0000-4000-8000-000000000001'
);

insert into public.project_memberships (
  id,
  project_id,
  participant_profile_id,
  originating_request_id,
  joined_at
)
values (
  '54000000-0000-4000-8000-000000000110',
  '54000000-0000-4000-8000-000000000010',
  '54000000-0000-4000-8000-000000000002',
  '54000000-0000-4000-8000-000000000100',
  '2026-09-20 09:00+00'
);

insert into public.resource_listings (
  id,
  owner_profile_id,
  listing_mode,
  lifecycle_state,
  title,
  description,
  country_code,
  locality,
  public_location_label,
  published_at
)
values (
  '54000000-0000-4000-8000-000000000020',
  '54000000-0000-4000-8000-000000000001',
  'exchange',
  'published',
  'Unified Resource item',
  'Private-enough source description that must not enter alerts.',
  'IT',
  'Trento',
  'Trento',
  statement_timestamp()
);

insert into public.resource_listing_requests (
  id,
  listing_id,
  requester_profile_id,
  status,
  request_message,
  created_at,
  resolved_at,
  resolved_by_profile_id
)
values (
  '54000000-0000-4000-8000-000000000100',
  '54000000-0000-4000-8000-000000000020',
  '54000000-0000-4000-8000-000000000002',
  'accepted',
  'Private Resource request text',
  '2026-09-20 08:00+00',
  '2026-09-20 09:00+00',
  '54000000-0000-4000-8000-000000000001'
);

select set_config(
  'test.resource_agreement_id',
  private.ensure_resource_exchange_agreement_for_request(
    '54000000-0000-4000-8000-000000000100',
    '54000000-0000-4000-8000-000000000001',
    '2026-09-20 09:00+00'
  )::text,
  true
);
select set_config(
  'test.resource_chat_id',
  private.ensure_resource_request_chat_for_request(
    '54000000-0000-4000-8000-000000000100',
    '2026-09-20 09:00+00'
  )::text,
  true
);

set local role anon;
select throws_ok(
  $$
    select *
    from public.list_own_structured_request_message_items(
      null,
      20,
      null,
      null,
      null
    )
  $$,
  '42501',
  'permission denied for function list_own_structured_request_message_items',
  'anonymous clients cannot list unified private requests'
);
reset role;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '54000000-0000-4000-8000-000000000002',
  true
);

select results_eq(
  $$
    select item_kind, request_id, viewer_role
    from public.list_own_structured_request_message_items(
      '54000000-0000-4000-8000-000000000002',
      20,
      null,
      null,
      null
    )
    order by item_kind
  $$,
  $$
    values
      (
        'participation_request'::text,
        '54000000-0000-4000-8000-000000000100'::uuid,
        'requester'::text
      ),
      (
        'resource_request'::text,
        '54000000-0000-4000-8000-000000000100'::uuid,
        'requester'::text
      )
  $$,
  'the same UUID in both request domains is returned exactly once per discriminator'
);
select results_eq(
  $$
    select item_kind, request_id
    from public.list_own_structured_request_message_items(
      '54000000-0000-4000-8000-000000000002',
      1,
      null,
      null,
      null
    )
  $$,
  $$values (
    'resource_request'::text,
    '54000000-0000-4000-8000-000000000100'::uuid
  )$$,
  'the cross-domain request kind order resolves an exact timestamp and UUID tie'
);
select results_eq(
  $$
    select item_kind, request_id
    from public.list_own_structured_request_message_items(
      '54000000-0000-4000-8000-000000000002',
      1,
      '2026-09-20 09:00+00',
      'resource_request',
      '54000000-0000-4000-8000-000000000100'
    )
  $$,
  $$values (
    'participation_request'::text,
    '54000000-0000-4000-8000-000000000100'::uuid
  )$$,
  'the complete request cursor neither skips nor repeats the tied Project row'
);
select results_eq(
  $$
    select
      item_kind,
      project_id is null,
      resource_listing_id,
      resource_chat_id,
      resource_agreement_id
    from public.get_own_structured_request_message_item(
      '54000000-0000-4000-8000-000000000002',
      'resource_request',
      '54000000-0000-4000-8000-000000000100'
    )
  $$,
  format(
    $$values (
      'resource_request'::text,
      true,
      '54000000-0000-4000-8000-000000000020'::uuid,
      %L::uuid,
      %L::uuid
    )$$,
    current_setting('test.resource_chat_id'),
    current_setting('test.resource_agreement_id')
  ),
  'the exact Resource request read agrees with canonical accepted anchors and XOR'
);

select results_eq(
  $$
    select item_kind, is_read_only
    from public.list_own_message_chat_items(
      '54000000-0000-4000-8000-000000000002',
      20,
      null,
      null,
      null
    )
    order by item_kind
  $$,
  $$values
    ('project_chat'::text, false),
    ('resource_chat'::text, false)
  $$,
  'unified Chats preserves current Project and Resource send state'
);
select results_eq(
  $$
    select item_kind
    from public.list_own_message_chat_items(
      '54000000-0000-4000-8000-000000000002',
      1,
      null,
      null,
      null
    )
  $$,
  $$values ('resource_chat'::text)$$,
  'the cross-domain chat kind order resolves an exact activity tie'
);
select results_eq(
  $$
    select item_kind
    from public.list_own_message_chat_items(
      '54000000-0000-4000-8000-000000000002',
      1,
      '2026-09-20 09:00+00',
      'resource_chat',
      current_setting('test.resource_chat_id')::uuid
    )
  $$,
  $$values ('project_chat'::text)$$,
  'the complete chat cursor returns the tied Project chat without duplication'
);

select set_config(
  'request.jwt.claim.sub',
  '54000000-0000-4000-8000-000000000003',
  true
);
select throws_ok(
  $$
    select *
    from public.get_own_structured_request_message_item(
      '54000000-0000-4000-8000-000000000003',
      'resource_request',
      '54000000-0000-4000-8000-000000000100'
    )
  $$,
  '42501',
  'The structured request message item is unavailable.',
  'an unrelated user cannot enumerate a Resource request through exact read'
);
select throws_ok(
  $$
    select *
    from public.get_own_structured_request_message_item(
      '54000000-0000-4000-8000-000000000003',
      'unknown_request',
      '54000000-0000-4000-8000-000000000100'
    )
  $$,
  '42501',
  'The structured request message item is unavailable.',
  'unknown discriminators fail with the same non-enumerating response'
);
reset role;

insert into public.resource_request_chat_messages (
  id,
  chat_id,
  sender_profile_id,
  body,
  created_at
)
values (
  '54000000-0000-4000-8000-000000000120',
  current_setting('test.resource_chat_id')::uuid,
  '54000000-0000-4000-8000-000000000001',
  'Private Resource message body',
  '2026-09-20 10:00+00'
);

insert into public.resource_exchange_agreement_terms (
  id,
  agreement_id,
  version_number,
  proposed_by_profile_id,
  listing_title_snapshot,
  listing_description_snapshot,
  owner_transfer_kind,
  requester_transfer_kind,
  private_note,
  created_at
)
values (
  '54000000-0000-4000-8000-000000000130',
  current_setting('test.resource_agreement_id')::uuid,
  1,
  '54000000-0000-4000-8000-000000000001',
  'Unified Resource item',
  'Private terms description snapshot',
  'give',
  'none',
  'Private terms note',
  '2026-09-20 10:01+00'
);

insert into private.outbox_events (
  id,
  event_type,
  payload,
  created_at,
  available_at
)
select
  source.event_id,
  source.event_type,
  jsonb_build_object(
    'request_id', '54000000-0000-4000-8000-000000000100'::uuid,
    'listing_id', '54000000-0000-4000-8000-000000000020'::uuid,
    'owner_profile_id', '54000000-0000-4000-8000-000000000001'::uuid,
    'requester_profile_id', '54000000-0000-4000-8000-000000000002'::uuid,
    'actor_profile_id', source.actor_profile_id
  ),
  source.created_at,
  source.created_at
from (
  values
    (
      '54000000-0000-4000-8000-000000000201'::uuid,
      'resource_listing.request_created'::text,
      '54000000-0000-4000-8000-000000000002'::uuid,
      '2026-09-20 10:02+00'::timestamptz
    ),
    (
      '54000000-0000-4000-8000-000000000202'::uuid,
      'resource_listing.request_withdrawn'::text,
      '54000000-0000-4000-8000-000000000002'::uuid,
      '2026-09-20 10:03+00'::timestamptz
    ),
    (
      '54000000-0000-4000-8000-000000000203'::uuid,
      'resource_listing.request_accepted'::text,
      '54000000-0000-4000-8000-000000000001'::uuid,
      '2026-09-20 10:04+00'::timestamptz
    ),
    (
      '54000000-0000-4000-8000-000000000204'::uuid,
      'resource_listing.request_rejected'::text,
      '54000000-0000-4000-8000-000000000001'::uuid,
      '2026-09-20 10:05+00'::timestamptz
    ),
    (
      '54000000-0000-4000-8000-000000000205'::uuid,
      'resource_listing.request_closed'::text,
      '54000000-0000-4000-8000-000000000001'::uuid,
      '2026-09-20 10:06+00'::timestamptz
    )
) as source(event_id, event_type, actor_profile_id, created_at);

insert into private.outbox_events (
  id,
  event_type,
  payload,
  created_at,
  available_at
)
values (
  '54000000-0000-4000-8000-000000000206',
  'resource_chat.message_sent',
  jsonb_build_object(
    'chat_id', current_setting('test.resource_chat_id')::uuid,
    'request_id', '54000000-0000-4000-8000-000000000100'::uuid,
    'agreement_id', current_setting('test.resource_agreement_id')::uuid,
    'listing_id', '54000000-0000-4000-8000-000000000020'::uuid,
    'owner_profile_id', '54000000-0000-4000-8000-000000000001'::uuid,
    'requester_profile_id', '54000000-0000-4000-8000-000000000002'::uuid,
    'message_id', '54000000-0000-4000-8000-000000000120'::uuid,
    'sender_profile_id', '54000000-0000-4000-8000-000000000001'::uuid
  ),
  '2026-09-20 10:00+00',
  '2026-09-20 10:00+00'
);

select set_config(
  'test.terms_proposed_event',
  private.record_resource_exchange_agreement_event(
    'terms_proposed',
    current_setting('test.resource_agreement_id')::uuid,
    '54000000-0000-4000-8000-000000000130',
    null,
    '54000000-0000-4000-8000-000000000001',
    '2026-09-20 09:10+00'
  )::text,
  true
);
select private.record_resource_exchange_agreement_event(
  'terms_accepted',
  current_setting('test.resource_agreement_id')::uuid,
  '54000000-0000-4000-8000-000000000130',
  null,
  '54000000-0000-4000-8000-000000000002',
  '2026-09-20 09:11+00'
);
select private.record_resource_exchange_agreement_event(
  'terms_rejected',
  current_setting('test.resource_agreement_id')::uuid,
  '54000000-0000-4000-8000-000000000130',
  null,
  '54000000-0000-4000-8000-000000000002',
  '2026-09-20 09:12+00'
);
select private.record_resource_exchange_agreement_event(
  'terms_withdrawn',
  current_setting('test.resource_agreement_id')::uuid,
  '54000000-0000-4000-8000-000000000130',
  null,
  '54000000-0000-4000-8000-000000000001',
  '2026-09-20 09:13+00'
);
select set_config(
  'test.milestone_event',
  private.record_resource_exchange_agreement_event(
    'resource_provided',
    current_setting('test.resource_agreement_id')::uuid,
    '54000000-0000-4000-8000-000000000130',
    'owner_resource',
    '54000000-0000-4000-8000-000000000001',
    '2026-09-20 09:14+00'
  )::text,
  true
);
select private.record_resource_exchange_agreement_event(
  'agreement_cancelled',
  current_setting('test.resource_agreement_id')::uuid,
  null,
  null,
  '54000000-0000-4000-8000-000000000002',
  '2026-09-20 09:15+00'
);
select private.record_resource_exchange_agreement_event(
  'agreement_completed',
  current_setting('test.resource_agreement_id')::uuid,
  '54000000-0000-4000-8000-000000000130',
  null,
  '54000000-0000-4000-8000-000000000001',
  '2026-09-20 09:16+00'
);
select private.record_resource_exchange_agreement_event(
  'terms_superseded',
  current_setting('test.resource_agreement_id')::uuid,
  '54000000-0000-4000-8000-000000000130',
  null,
  '54000000-0000-4000-8000-000000000001',
  '2026-09-20 09:17+00'
);

insert into public.profile_notification_preferences (
  profile_id,
  category_slug,
  in_app_enabled,
  push_enabled
)
values (
  '54000000-0000-4000-8000-000000000002',
  'resources',
  true,
  false
);

set local role service_role;
select results_eq(
  $$
    select processed_count, notifications_created, notifications_suppressed
    from public.process_notification_outbox_batch(100)
  $$,
  $$values (13, 13, 0)$$,
  'all thirteen supported Resource events create exactly one in-app alert'
);
select results_eq(
  $$
    select processed_count, jobs_created, jobs_suppressed
    from public.process_push_outbox_batch(100)
  $$,
  $$values (13, 5, 8)$$,
  'the Resources push preference suppresses only the requester recipient jobs'
);
select results_eq(
  $$
    select processed_count, notifications_created, notifications_suppressed
    from public.process_notification_outbox_batch(100)
  $$,
  $$values (0, 0, 0)$$,
  'notification projection is receipt-idempotent'
);
select results_eq(
  $$
    select processed_count, jobs_created, jobs_suppressed
    from public.process_push_outbox_batch(100)
  $$,
  $$values (0, 0, 0)$$,
  'push projection is independently receipt-idempotent'
);
reset role;

select is(
  (
    select count(*)
    from public.notifications
    where category_slug = 'resources'
      and recipient_profile_id = actor_profile_id
  ),
  0::bigint,
  'Resource chat and agreement actors never receive their own alert'
);
select is(
  (
    select count(*)
    from public.notifications
    where category_slug = 'resources'
      and (
        project_id is not null
        or request_id is not null
        or membership_id is not null
        or chat_id is not null
        or message_id is not null
      )
  ),
  0::bigint,
  'every Resource alert keeps all Project reference columns null'
);
select is(
  (
    select count(*)
    from public.notifications
    where source_outbox_event_id in (
      select id
      from private.outbox_events
      where event_type in (
        'resource_exchange.agreement_created',
        'resource_exchange.terms_superseded'
      )
    )
  ),
  0::bigint,
  'agreement creation and terms supersession do not produce alerts'
);
select is(
  (
    select count(*)
    from private.outbox_consumer_receipts as receipt
    join private.outbox_events as event
      on event.id = receipt.outbox_event_id
    where event.event_type in (
      'resource_exchange.agreement_created',
      'resource_exchange.terms_superseded'
    )
      and receipt.consumer_key in ('notifications.v1', 'push.v1')
  ),
  0::bigint,
  'unsupported Resource events remain available to other consumers'
);
select is(
  (
    select count(*)
    from private.push_delivery_jobs
    where category_slug = 'resources'
      and (
        project_id is not null
        or project_kind is not null
        or request_id is not null
        or membership_id is not null
        or chat_id is not null
        or message_id is not null
      )
  ),
  0::bigint,
  'Resource push jobs are body-free and contain no Project references'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '54000000-0000-4000-8000-000000000002',
  true
);
select results_eq(
  format(
    $$
      select
        notification_kind,
        resource_agreement_event_id,
        resource_exchange_event_kind,
        resource_exchange_leg_kind
      from public.list_own_notifications(
        '54000000-0000-4000-8000-000000000002',
        100,
        null,
        null
      )
      where notification_kind = 'resource_exchange_milestone_recorded'
    $$
  ),
  format(
    $$values (
      'resource_exchange_milestone_recorded'::text,
      %L::uuid,
      'resource_provided'::text,
      'owner_resource'::text
    )$$,
    current_setting('test.milestone_event')
  ),
  'the recipient inbox resolves canonical milestone kind and leg metadata'
);
select is(
  (
    select count(*)
    from public.list_own_notifications(
      '54000000-0000-4000-8000-000000000002',
      100,
      null,
      null
    ) as notification
    where notification.resource_listing_title = 'Unified Resource item'
      and notification.category_slug = 'resources'
  ),
  8::bigint,
  'the requester sees only their eight expected Resource alerts with safe title context'
);
reset role;

select is(
  (
    select count(*)
    from public.notifications as notification
    cross join lateral jsonb_each_text(to_jsonb(notification)) as field
    where field.value in (
      'Private Project request text',
      'Private Resource request text',
      'Private Resource message body',
      'Private terms description snapshot',
      'Private terms note'
    )
  ),
  0::bigint,
  'notification rows contain none of the request, message, or agreement private copy'
);
select is(
  (
    select count(*)
    from private.push_delivery_jobs as job
    cross join lateral jsonb_each_text(to_jsonb(job)) as field
    where field.value in (
      'Private Resource request text',
      'Private Resource message body',
      'Private terms description snapshot',
      'Private terms note'
    )
  ),
  0::bigint,
  'provider-neutral jobs contain no request, message, or terms copy'
);

select * from finish();

rollback;
