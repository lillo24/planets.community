begin;

select no_plan();

insert into auth.users (id, email)
values
  ('b6100000-0000-4000-8000-000000000001', 'chat-alert-creator@planets.invalid'),
  ('b6200000-0000-4000-8000-000000000002', 'chat-alert-a@planets.invalid'),
  ('b6300000-0000-4000-8000-000000000003', 'chat-alert-b@planets.invalid');

insert into public.profiles (id, display_name)
values
  ('b6100000-0000-4000-8000-000000000001', 'Chat Alert Creator'),
  ('b6200000-0000-4000-8000-000000000002', 'Chat Alert A'),
  ('b6300000-0000-4000-8000-000000000003', 'Chat Alert B');

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
values
  (
    'c6100000-0000-4000-8000-000000000001',
    'b6100000-0000-4000-8000-000000000001',
    'published',
    'Chat alert timeline',
    '2098-01-01 10:00+00',
    '2098-01-01 12:00+00',
    'Europe/Rome',
    statement_timestamp()
  ),
  (
    'c6200000-0000-4000-8000-000000000002',
    'b6100000-0000-4000-8000-000000000001',
    'published',
    'Chat alert zero recipient',
    '2098-01-02 10:00+00',
    '2098-01-02 12:00+00',
    'Europe/Rome',
    statement_timestamp()
  );

insert into public.project_join_requests (
  id,
  project_id,
  requester_profile_id,
  status,
  created_at,
  resolved_at,
  resolved_by_profile_id
)
values
  (
    'd6100000-0000-4000-8000-000000000001',
    'c6100000-0000-4000-8000-000000000001',
    'b6200000-0000-4000-8000-000000000002',
    'accepted',
    '2026-09-14 07:59+00',
    '2026-09-14 08:00+00',
    'b6100000-0000-4000-8000-000000000001'
  ),
  (
    'd6200000-0000-4000-8000-000000000002',
    'c6100000-0000-4000-8000-000000000001',
    'b6300000-0000-4000-8000-000000000003',
    'accepted',
    '2026-09-14 08:09+00',
    '2026-09-14 08:10+00',
    'b6100000-0000-4000-8000-000000000001'
  ),
  (
    'd6300000-0000-4000-8000-000000000003',
    'c6100000-0000-4000-8000-000000000001',
    'b6200000-0000-4000-8000-000000000002',
    'accepted',
    '2026-09-14 08:59+00',
    '2026-09-14 09:00+00',
    'b6100000-0000-4000-8000-000000000001'
  ),
  (
    'd6400000-0000-4000-8000-000000000004',
    'c6100000-0000-4000-8000-000000000001',
    'b6200000-0000-4000-8000-000000000002',
    'accepted',
    '2026-09-14 09:59+00',
    '2026-09-14 10:00+00',
    'b6100000-0000-4000-8000-000000000001'
  ),
  (
    'd6500000-0000-4000-8000-000000000005',
    'c6200000-0000-4000-8000-000000000002',
    'b6200000-0000-4000-8000-000000000002',
    'accepted',
    '2026-09-14 06:59+00',
    '2026-09-14 07:00+00',
    'b6100000-0000-4000-8000-000000000001'
  );

insert into public.project_memberships (
  id,
  project_id,
  participant_profile_id,
  originating_request_id,
  joined_at,
  left_at
)
values
  (
    'e6100000-0000-4000-8000-000000000001',
    'c6100000-0000-4000-8000-000000000001',
    'b6200000-0000-4000-8000-000000000002',
    'd6100000-0000-4000-8000-000000000001',
    '2026-09-14 08:00+00',
    '2026-09-14 08:30+00'
  ),
  (
    'e6200000-0000-4000-8000-000000000002',
    'c6100000-0000-4000-8000-000000000001',
    'b6300000-0000-4000-8000-000000000003',
    'd6200000-0000-4000-8000-000000000002',
    '2026-09-14 08:10+00',
    null
  ),
  (
    'e6300000-0000-4000-8000-000000000003',
    'c6100000-0000-4000-8000-000000000001',
    'b6200000-0000-4000-8000-000000000002',
    'd6300000-0000-4000-8000-000000000003',
    '2026-09-14 09:00+00',
    '2026-09-14 09:30+00'
  ),
  (
    'e6500000-0000-4000-8000-000000000005',
    'c6200000-0000-4000-8000-000000000002',
    'b6200000-0000-4000-8000-000000000002',
    'd6500000-0000-4000-8000-000000000005',
    '2026-09-14 07:00+00',
    '2026-09-14 07:10+00'
  );

select set_config(
  'test.chat_id',
  (
    select id::text
    from public.project_group_chats
    where project_id = 'c6100000-0000-4000-8000-000000000001'
  ),
  true
);
select set_config(
  'test.zero_chat_id',
  (
    select id::text
    from public.project_group_chats
    where project_id = 'c6200000-0000-4000-8000-000000000002'
  ),
  true
);

insert into public.project_chat_messages (
  id,
  chat_id,
  sender_profile_id,
  body,
  created_at
)
values
  (
    'a6100000-0000-4000-8000-000000000001',
    current_setting('test.chat_id')::uuid,
    'b6200000-0000-4000-8000-000000000002',
    'Timeline M1 private body',
    '2026-09-14 08:05+00'
  ),
  (
    'a6100000-0000-4000-8000-000000000002',
    current_setting('test.chat_id')::uuid,
    'b6100000-0000-4000-8000-000000000001',
    'Timeline M2 private body',
    '2026-09-14 08:20+00'
  ),
  (
    'a6100000-0000-4000-8000-000000000003',
    current_setting('test.chat_id')::uuid,
    'b6100000-0000-4000-8000-000000000001',
    'Timeline M3 private body',
    '2026-09-14 08:40+00'
  ),
  (
    'a6100000-0000-4000-8000-000000000004',
    current_setting('test.chat_id')::uuid,
    'b6300000-0000-4000-8000-000000000003',
    'Timeline M4 private body',
    '2026-09-14 09:10+00'
  ),
  (
    'a6100000-0000-4000-8000-000000000005',
    current_setting('test.chat_id')::uuid,
    'b6100000-0000-4000-8000-000000000001',
    'Timeline M5 private body',
    '2026-09-14 09:40+00'
  );

insert into private.outbox_events (
  id,
  event_type,
  payload,
  created_at,
  available_at
)
select
  ('96100000-0000-4000-8000-' || lpad(ordinal::text, 12, '0'))::uuid,
  'project.chat_message_sent',
  jsonb_build_object(
    'chat_id', current_setting('test.chat_id')::uuid,
    'project_id', 'c6100000-0000-4000-8000-000000000001'::uuid,
    'project_kind', 'one_time',
    'message_id', message.id,
    'sender_profile_id', message.sender_profile_id
  ),
  message.created_at,
  message.created_at
from (
  values
    (1, 'a6100000-0000-4000-8000-000000000001'::uuid),
    (2, 'a6100000-0000-4000-8000-000000000002'::uuid),
    (3, 'a6100000-0000-4000-8000-000000000003'::uuid),
    (4, 'a6100000-0000-4000-8000-000000000004'::uuid),
    (5, 'a6100000-0000-4000-8000-000000000005'::uuid)
) as source(ordinal, message_id)
join public.project_chat_messages as message on message.id = source.message_id;

set local role service_role;
select results_eq(
  $$
    select processed_count, notifications_created, notifications_suppressed
    from public.process_notification_outbox_batch(100)
  $$,
  $$values (5, 0, 7)$$,
  'notifications.v1 consumes five ordinary events and suppresses seven recipients'
);
select results_eq(
  $$
    select processed_count, jobs_created, jobs_suppressed
    from public.process_push_outbox_batch(100)
  $$,
  $$values (5, 7, 0)$$,
  'push.v1 independently fans five messages out to seven recipients'
);

reset role;
select results_eq(
  $$
    select notification.message_id, notification.recipient_profile_id
    from public.notifications as notification
    where notification.category_slug = 'chat'
    order by notification.message_id, notification.recipient_profile_id
  $$,
  $$select null::uuid, null::uuid where false
  $$,
  'late join, leave, rejoin, and second leave follow canonical half-open intervals'
);
select results_eq(
  $$
    select job.message_id, job.recipient_profile_id
    from private.push_delivery_jobs as job
    where job.category_slug = 'chat'
    order by job.message_id, job.recipient_profile_id
  $$,
  $$
    values
      ('a6100000-0000-4000-8000-000000000001'::uuid, 'b6100000-0000-4000-8000-000000000001'::uuid),
      ('a6100000-0000-4000-8000-000000000002'::uuid, 'b6200000-0000-4000-8000-000000000002'::uuid),
      ('a6100000-0000-4000-8000-000000000002'::uuid, 'b6300000-0000-4000-8000-000000000003'::uuid),
      ('a6100000-0000-4000-8000-000000000003'::uuid, 'b6300000-0000-4000-8000-000000000003'::uuid),
      ('a6100000-0000-4000-8000-000000000004'::uuid, 'b6100000-0000-4000-8000-000000000001'::uuid),
      ('a6100000-0000-4000-8000-000000000004'::uuid, 'b6200000-0000-4000-8000-000000000002'::uuid),
      ('a6100000-0000-4000-8000-000000000005'::uuid, 'b6300000-0000-4000-8000-000000000003'::uuid)
  $$,
  'push fan-out uses the same canonical recipient timeline'
);
select is(
  (
    select count(*)
    from public.notifications as notification
    join public.project_chat_messages as message
      on message.id = notification.message_id
    where notification.recipient_profile_id = message.sender_profile_id
  ),
  0::bigint,
  'senders never receive their own in-app alert'
);
select is(
  (
    select count(*)
    from private.push_delivery_jobs as job
    join public.project_chat_messages as message on message.id = job.message_id
    where job.recipient_profile_id = message.sender_profile_id
  ),
  0::bigint,
  'senders never receive their own push job'
);
select is(
  (
    select count(*)
    from public.notifications as notification
    join public.project_chat_messages as message
      on message.id = notification.message_id
    where notification.created_at = message.created_at
  ),
  0::bigint,
  'ordinary message alerts are suppressed while canonical source timestamps remain intact'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'b6200000-0000-4000-8000-000000000002',
  true
);
select results_eq(
  $$
    select chat_id, message_id, project_title
    from public.list_own_notifications(
      'b6200000-0000-4000-8000-000000000002',
      20,
      null,
      null
    )
    where notification_kind = 'chat_message_received'
    order by message_id
  $$,
  $$select null::uuid, null::uuid, null::text where false
  $$,
  'the recipient activity inbox excludes ordinary messages before pagination'
);

reset role;
select ok(
  not exists (
    select 1
    from public.notifications as notification
    where to_jsonb(notification)::text like '%private body%'
      or to_jsonb(notification) ? 'body'
  ) and not exists (
    select 1
    from private.push_delivery_jobs as job
    where to_jsonb(job)::text like '%private body%'
      or to_jsonb(job) ? 'body'
  ) and not exists (
    select 1
    from private.outbox_events as event
    where event.event_type = 'project.chat_message_sent'
      and (
        to_jsonb(event.payload)::text like '%private body%'
        or event.payload ? 'body'
      )
  ),
  'message bodies remain only in canonical chat storage'
);

delete from private.outbox_consumer_receipts
where outbox_event_id = '96100000-0000-4000-8000-000000000002'
  and consumer_key in ('notifications.v1', 'push.v1');

set local role service_role;
select results_eq(
  $$
    select processed_count, notifications_created, notifications_suppressed
    from public.process_notification_outbox_batch(100)
  $$,
  $$values (1, 0, 2)$$,
  'a lost notification response retries a multi-recipient event without duplicates'
);
select results_eq(
  $$
    select processed_count, jobs_created, jobs_suppressed
    from public.process_push_outbox_batch(100)
  $$,
  $$values (1, 0, 0)$$,
  'a lost push response retries a multi-recipient event without duplicate jobs'
);

reset role;
delete from private.outbox_consumer_receipts
where outbox_event_id = '96100000-0000-4000-8000-000000000002'
  and consumer_key = 'notifications.v1';
delete from public.notifications
where source_outbox_event_id = '96100000-0000-4000-8000-000000000002'
  and recipient_profile_id = 'b6200000-0000-4000-8000-000000000002';

set local role service_role;
select results_eq(
  $$
    select processed_count, notifications_created, notifications_suppressed
    from public.process_notification_outbox_batch(100)
  $$,
  $$values (1, 0, 2)$$,
  'retry restores one missing recipient without duplicating the existing recipient'
);

reset role;
select is(
  (
    select count(*)
    from public.notifications
    where source_outbox_event_id = '96100000-0000-4000-8000-000000000002'
  ),
  0::bigint,
  'retry preserves ordinary message suppression without recreating rows'
);

delete from private.outbox_consumer_receipts
where outbox_event_id = '96100000-0000-4000-8000-000000000002'
  and consumer_key = 'push.v1';
delete from private.push_delivery_jobs
where source_outbox_event_id = '96100000-0000-4000-8000-000000000002'
  and recipient_profile_id = 'b6200000-0000-4000-8000-000000000002';

set local role service_role;
select results_eq(
  $$
    select processed_count, jobs_created, jobs_suppressed
    from public.process_push_outbox_batch(100)
  $$,
  $$values (1, 1, 0)$$,
  'push retry restores one missing recipient without duplicating another job'
);

reset role;
select is(
  (
    select count(*)
    from private.push_delivery_jobs
    where source_outbox_event_id = '96100000-0000-4000-8000-000000000002'
  ),
  2::bigint,
  'the repaired multi-recipient push fan-out is complete exactly once'
);

insert into public.profile_notification_preferences (
  profile_id,
  category_slug,
  in_app_enabled,
  push_enabled
)
values
  (
    'b6200000-0000-4000-8000-000000000002',
    'chat',
    true,
    false
  ),
  (
    'b6300000-0000-4000-8000-000000000003',
    'chat',
    false,
    true
  );

insert into public.project_chat_messages (
  id,
  chat_id,
  sender_profile_id,
  body,
  created_at
)
values (
  'a6100000-0000-4000-8000-000000000006',
  current_setting('test.chat_id')::uuid,
  'b6100000-0000-4000-8000-000000000001',
  'Preference FT private body',
  '2026-09-14 09:45+00'
);
insert into private.outbox_events (
  id,
  event_type,
  payload,
  created_at,
  available_at
)
values (
  '96100000-0000-4000-8000-000000000006',
  'project.chat_message_sent',
  jsonb_build_object(
    'chat_id', current_setting('test.chat_id')::uuid,
    'project_id', 'c6100000-0000-4000-8000-000000000001'::uuid,
    'project_kind', 'one_time',
    'message_id', 'a6100000-0000-4000-8000-000000000006'::uuid,
    'sender_profile_id', 'b6100000-0000-4000-8000-000000000001'::uuid
  ),
  '2026-09-14 09:45+00',
  '2026-09-14 09:45+00'
);

set local role service_role;
select results_eq(
  $$select * from public.process_notification_outbox_batch(100)$$,
  $$values (1, 0, 1)$$,
  'in-app false suppresses B without suppressing B push'
);
select results_eq(
  $$select * from public.process_push_outbox_batch(100)$$,
  $$values (1, 1, 0)$$,
  'push true creates B job independently of in-app suppression'
);

reset role;
insert into public.project_memberships (
  id,
  project_id,
  participant_profile_id,
  originating_request_id,
  joined_at,
  left_at
)
values (
  'e6400000-0000-4000-8000-000000000004',
  'c6100000-0000-4000-8000-000000000001',
  'b6200000-0000-4000-8000-000000000002',
  'd6400000-0000-4000-8000-000000000004',
  '2026-09-14 10:00+00',
  null
);
insert into public.project_chat_messages (
  id,
  chat_id,
  sender_profile_id,
  body,
  created_at
)
values (
  'a6100000-0000-4000-8000-000000000007',
  current_setting('test.chat_id')::uuid,
  'b6300000-0000-4000-8000-000000000003',
  'Preference TF private body',
  '2026-09-14 10:10+00'
);
insert into private.outbox_events (
  id,
  event_type,
  payload,
  created_at,
  available_at
)
values (
  '96100000-0000-4000-8000-000000000007',
  'project.chat_message_sent',
  jsonb_build_object(
    'chat_id', current_setting('test.chat_id')::uuid,
    'project_id', 'c6100000-0000-4000-8000-000000000001'::uuid,
    'project_kind', 'one_time',
    'message_id', 'a6100000-0000-4000-8000-000000000007'::uuid,
    'sender_profile_id', 'b6300000-0000-4000-8000-000000000003'::uuid
  ),
  '2026-09-14 10:10+00',
  '2026-09-14 10:10+00'
);

set local role service_role;
select results_eq(
  $$select * from public.process_notification_outbox_batch(100)$$,
  $$values (1, 0, 2)$$,
  'true/true creator and true/false A both receive in-app rows'
);
select results_eq(
  $$select * from public.process_push_outbox_batch(100)$$,
  $$values (1, 1, 1)$$,
  'true/false A is suppressed only from push while creator push remains'
);

reset role;
update public.profile_notification_preferences
set
  in_app_enabled = false,
  push_enabled = false
where profile_id = 'b6200000-0000-4000-8000-000000000002'
  and category_slug = 'chat';
insert into public.project_chat_messages (
  id,
  chat_id,
  sender_profile_id,
  body,
  created_at
)
values (
  'a6100000-0000-4000-8000-000000000008',
  current_setting('test.chat_id')::uuid,
  'b6300000-0000-4000-8000-000000000003',
  'Preference FF private body',
  '2026-09-14 10:20+00'
);
insert into private.outbox_events (
  id,
  event_type,
  payload,
  created_at,
  available_at
)
values (
  '96100000-0000-4000-8000-000000000008',
  'project.chat_message_sent',
  jsonb_build_object(
    'chat_id', current_setting('test.chat_id')::uuid,
    'project_id', 'c6100000-0000-4000-8000-000000000001'::uuid,
    'project_kind', 'one_time',
    'message_id', 'a6100000-0000-4000-8000-000000000008'::uuid,
    'sender_profile_id', 'b6300000-0000-4000-8000-000000000003'::uuid
  ),
  '2026-09-14 10:20+00',
  '2026-09-14 10:20+00'
);

set local role service_role;
select results_eq(
  $$select * from public.process_notification_outbox_batch(100)$$,
  $$values (1, 0, 2)$$,
  'false/false A is suppressed while true/true creator remains independent'
);
select results_eq(
  $$select * from public.process_push_outbox_batch(100)$$,
  $$values (1, 1, 1)$$,
  'false/false A is independently suppressed from push as well'
);

reset role;
insert into public.project_chat_messages (
  id,
  chat_id,
  sender_profile_id,
  body,
  created_at
)
values (
  'a6200000-0000-4000-8000-000000000001',
  current_setting('test.zero_chat_id')::uuid,
  'b6100000-0000-4000-8000-000000000001',
  'Zero-recipient private body',
  '2026-09-14 07:20+00'
);
insert into private.outbox_events (
  id,
  event_type,
  payload,
  created_at,
  available_at
)
values (
  '96200000-0000-4000-8000-000000000001',
  'project.chat_message_sent',
  jsonb_build_object(
    'chat_id', current_setting('test.zero_chat_id')::uuid,
    'project_id', 'c6200000-0000-4000-8000-000000000002'::uuid,
    'project_kind', 'one_time',
    'message_id', 'a6200000-0000-4000-8000-000000000001'::uuid,
    'sender_profile_id', 'b6100000-0000-4000-8000-000000000001'::uuid
  ),
  '2026-09-14 07:20+00',
  '2026-09-14 07:20+00'
);

set local role service_role;
select results_eq(
  $$select * from public.process_notification_outbox_batch(100)$$,
  $$values (1, 0, 0)$$,
  'a zero-recipient chat event is safely acknowledged by notifications.v1'
);
select results_eq(
  $$select * from public.process_push_outbox_batch(100)$$,
  $$values (1, 0, 0)$$,
  'a zero-recipient chat event is safely acknowledged by push.v1'
);

reset role;
select is(
  (
    select count(*)
    from private.outbox_consumer_receipts
    where outbox_event_id = '96200000-0000-4000-8000-000000000001'
      and consumer_key in ('notifications.v1', 'push.v1')
  ),
  2::bigint,
  'zero-recipient processing writes both independent consumer receipts'
);

insert into private.outbox_events (
  id,
  event_type,
  payload,
  created_at,
  available_at
)
values (
  '96900000-0000-4000-8000-000000000099',
  'project.chat_message_sent',
  jsonb_build_object(
    'chat_id', current_setting('test.zero_chat_id')::uuid,
    'project_id', 'c6100000-0000-4000-8000-000000000001'::uuid,
    'project_kind', 'one_time',
    'message_id', 'a6100000-0000-4000-8000-000000000001'::uuid,
    'sender_profile_id', 'b6200000-0000-4000-8000-000000000002'::uuid
  ),
  statement_timestamp(),
  statement_timestamp()
);

set local role service_role;
select throws_ok(
  'select * from public.process_notification_outbox_batch(100)',
  '55000',
  'Project chat notification event 96900000-0000-4000-8000-000000000099 does not match its canonical message.',
  'mismatched chat payload fails notifications.v1 visibly'
);
select throws_ok(
  'select * from public.process_push_outbox_batch(100)',
  '55000',
  'Project chat notification event 96900000-0000-4000-8000-000000000099 does not match its canonical message.',
  'mismatched chat payload fails push.v1 visibly'
);

reset role;
select ok(
  not exists (
    select 1
    from private.outbox_consumer_receipts
    where outbox_event_id = '96900000-0000-4000-8000-000000000099'
  ) and not exists (
    select 1
    from public.notifications
    where source_outbox_event_id = '96900000-0000-4000-8000-000000000099'
  ) and not exists (
    select 1
    from private.push_delivery_jobs
    where source_outbox_event_id = '96900000-0000-4000-8000-000000000099'
  ),
  'failed fan-out creates no receipt or success-shaped projection row'
);

select * from finish();

rollback;
