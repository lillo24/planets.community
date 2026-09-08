begin;

select no_plan();

insert into auth.users (id, email)
values
  ('e1000000-0000-4000-8000-000000000001', 'notification-creator@planets.invalid'),
  ('e2000000-0000-4000-8000-000000000002', 'notification-requester@planets.invalid'),
  ('e3000000-0000-4000-8000-000000000003', 'notification-other@planets.invalid');

insert into public.profiles (id, display_name)
values
  ('e1000000-0000-4000-8000-000000000001', 'Notification Creator'),
  ('e2000000-0000-4000-8000-000000000002', 'Notification Requester'),
  ('e3000000-0000-4000-8000-000000000003', 'Notification Other');

insert into public.proposals (
  id,
  creator_profile_id,
  lifecycle_state,
  title,
  starts_at,
  ends_at,
  published_at,
  cancelled_at
)
values (
  'f1000000-0000-4000-8000-000000000001',
  'e1000000-0000-4000-8000-000000000001',
  'published',
  'Notification proposal',
  statement_timestamp() - interval '1 hour',
  statement_timestamp() + interval '2 hours',
  statement_timestamp() - interval '1 day',
  null
);

insert into public.proposal_meeting_details (
  proposal_id,
  exact_meeting_text,
  exact_location_visibility
)
values (
  'f1000000-0000-4000-8000-000000000001',
  'Secret notification proposal courtyard',
  'participants'
);

insert into public.recurring_activities (
  id,
  creator_profile_id,
  lifecycle_state,
  title,
  published_at,
  paused_at,
  ended_at
)
values (
  'f2000000-0000-4000-8000-000000000002',
  'e1000000-0000-4000-8000-000000000001',
  'published',
  'Notification Tavolo',
  statement_timestamp() - interval '1 day',
  null,
  null
);

insert into public.recurring_activity_meeting_details (
  recurring_activity_id,
  exact_meeting_text,
  exact_location_visibility
)
values (
  'f2000000-0000-4000-8000-000000000002',
  'Secret notification Tavolo room',
  'participants'
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
values
  (
    'a1000000-0000-4000-8000-000000000001',
    'f1000000-0000-4000-8000-000000000001',
    'e2000000-0000-4000-8000-000000000002',
    'pending',
    'Private request message must never enter an inbox.',
    statement_timestamp() - interval '12 hours',
    null,
    null
  ),
  (
    'a2000000-0000-4000-8000-000000000002',
    'f2000000-0000-4000-8000-000000000002',
    'e2000000-0000-4000-8000-000000000002',
    'withdrawn',
    null,
    statement_timestamp() - interval '11 hours',
    statement_timestamp() - interval '10 hours 50 minutes',
    'e2000000-0000-4000-8000-000000000002'
  ),
  (
    'a3000000-0000-4000-8000-000000000003',
    'f1000000-0000-4000-8000-000000000001',
    'e2000000-0000-4000-8000-000000000002',
    'accepted',
    null,
    statement_timestamp() - interval '10 hours',
    statement_timestamp() - interval '9 hours 50 minutes',
    'e1000000-0000-4000-8000-000000000001'
  ),
  (
    'a4000000-0000-4000-8000-000000000004',
    'f2000000-0000-4000-8000-000000000002',
    'e2000000-0000-4000-8000-000000000002',
    'rejected',
    null,
    statement_timestamp() - interval '9 hours',
    statement_timestamp() - interval '8 hours 50 minutes',
    'e1000000-0000-4000-8000-000000000001'
  ),
  (
    'a5000000-0000-4000-8000-000000000005',
    'f1000000-0000-4000-8000-000000000001',
    'e2000000-0000-4000-8000-000000000002',
    'accepted',
    null,
    statement_timestamp() - interval '8 hours',
    statement_timestamp() - interval '7 hours 50 minutes',
    'e1000000-0000-4000-8000-000000000001'
  ),
  (
    'a6000000-0000-4000-8000-000000000006',
    'f2000000-0000-4000-8000-000000000002',
    'e2000000-0000-4000-8000-000000000002',
    'accepted',
    null,
    statement_timestamp() - interval '7 hours',
    statement_timestamp() - interval '6 hours 50 minutes',
    'e1000000-0000-4000-8000-000000000001'
  );

insert into public.project_memberships (
  id,
  project_id,
  participant_profile_id,
  originating_request_id,
  joined_at,
  left_at,
  removed_at,
  removed_by_profile_id
)
values
  (
    'b3000000-0000-4000-8000-000000000003',
    'f1000000-0000-4000-8000-000000000001',
    'e2000000-0000-4000-8000-000000000002',
    'a3000000-0000-4000-8000-000000000003',
    statement_timestamp() - interval '9 hours 50 minutes',
    null,
    null,
    null
  ),
  (
    'b5000000-0000-4000-8000-000000000005',
    'f1000000-0000-4000-8000-000000000001',
    'e2000000-0000-4000-8000-000000000002',
    'a5000000-0000-4000-8000-000000000005',
    statement_timestamp() - interval '7 hours 50 minutes',
    statement_timestamp() - interval '7 hours 40 minutes',
    null,
    null
  ),
  (
    'b6000000-0000-4000-8000-000000000006',
    'f2000000-0000-4000-8000-000000000002',
    'e2000000-0000-4000-8000-000000000002',
    'a6000000-0000-4000-8000-000000000006',
    statement_timestamp() - interval '6 hours 50 minutes',
    null,
    statement_timestamp() - interval '6 hours 40 minutes',
    'e1000000-0000-4000-8000-000000000001'
  );

insert into private.outbox_events (id, event_type, payload, created_at, available_at)
values
  (
    'c1000000-0000-4000-8000-000000000001',
    'project.join_requested',
    jsonb_build_object(
      'project_id', 'f1000000-0000-4000-8000-000000000001',
      'project_kind', 'one_time',
      'actor_profile_id', 'e2000000-0000-4000-8000-000000000002',
      'request_id', 'a1000000-0000-4000-8000-000000000001',
      'requester_profile_id', 'e2000000-0000-4000-8000-000000000002',
      'status', 'pending'
    ),
    statement_timestamp() - interval '6 hours',
    statement_timestamp() - interval '6 hours'
  ),
  (
    'c2000000-0000-4000-8000-000000000002',
    'project.join_request_withdrawn',
    jsonb_build_object(
      'project_id', 'f2000000-0000-4000-8000-000000000002',
      'project_kind', 'recurring',
      'actor_profile_id', 'e2000000-0000-4000-8000-000000000002',
      'request_id', 'a2000000-0000-4000-8000-000000000002',
      'requester_profile_id', 'e2000000-0000-4000-8000-000000000002',
      'status', 'withdrawn'
    ),
    statement_timestamp() - interval '5 hours',
    statement_timestamp() - interval '5 hours'
  ),
  (
    'c3000000-0000-4000-8000-000000000003',
    'project.join_request_accepted',
    jsonb_build_object(
      'project_id', 'f1000000-0000-4000-8000-000000000001',
      'project_kind', 'one_time',
      'actor_profile_id', 'e1000000-0000-4000-8000-000000000001',
      'request_id', 'a3000000-0000-4000-8000-000000000003',
      'requester_profile_id', 'e2000000-0000-4000-8000-000000000002',
      'membership_id', 'b3000000-0000-4000-8000-000000000003',
      'status', 'accepted'
    ),
    statement_timestamp() - interval '4 hours',
    statement_timestamp() - interval '4 hours'
  ),
  (
    'c4000000-0000-4000-8000-000000000004',
    'project.join_request_rejected',
    jsonb_build_object(
      'project_id', 'f2000000-0000-4000-8000-000000000002',
      'project_kind', 'recurring',
      'actor_profile_id', 'e1000000-0000-4000-8000-000000000001',
      'request_id', 'a4000000-0000-4000-8000-000000000004',
      'requester_profile_id', 'e2000000-0000-4000-8000-000000000002',
      'status', 'rejected'
    ),
    statement_timestamp() - interval '3 hours',
    statement_timestamp() - interval '3 hours'
  ),
  (
    'c5000000-0000-4000-8000-000000000005',
    'project.participant_left',
    jsonb_build_object(
      'project_id', 'f1000000-0000-4000-8000-000000000001',
      'project_kind', 'one_time',
      'actor_profile_id', 'e2000000-0000-4000-8000-000000000002',
      'membership_id', 'b5000000-0000-4000-8000-000000000005',
      'participant_profile_id', 'e2000000-0000-4000-8000-000000000002',
      'status', 'left'
    ),
    statement_timestamp() - interval '2 hours',
    statement_timestamp() - interval '2 hours'
  ),
  (
    'c6000000-0000-4000-8000-000000000006',
    'project.participant_removed',
    jsonb_build_object(
      'project_id', 'f2000000-0000-4000-8000-000000000002',
      'project_kind', 'recurring',
      'actor_profile_id', 'e1000000-0000-4000-8000-000000000001',
      'membership_id', 'b6000000-0000-4000-8000-000000000006',
      'participant_profile_id', 'e2000000-0000-4000-8000-000000000002',
      'status', 'removed'
    ),
    statement_timestamp() - interval '1 hour',
    statement_timestamp() - interval '1 hour'
  ),
  (
    'c9000000-0000-4000-8000-000000000009',
    'proposal.published',
    jsonb_build_object('proposal_id', 'f1000000-0000-4000-8000-000000000001'),
    statement_timestamp() - interval '30 minutes',
    statement_timestamp() - interval '30 minutes'
  );

set local role anon;
select throws_ok(
  $$
    select *
    from public.list_own_notifications(null, 20, null, null)
  $$,
  '42501',
  'permission denied for function list_own_notifications',
  'anonymous clients cannot invoke the inbox boundary'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'e2000000-0000-4000-8000-000000000002',
  true
);
select is(
  (
    select count(*)
    from public.list_own_notification_preferences(
      'e2000000-0000-4000-8000-000000000002'
    )
  ),
  5::bigint,
  'all category defaults are readable without override rows'
);
select is(
  (
    select count(*)
    from public.list_own_notification_preferences(
      'e2000000-0000-4000-8000-000000000002'
    ) as preference
    where preference.in_app_enabled
      and preference.push_enabled
      and not preference.has_override
  ),
  5::bigint,
  'effective defaults do not require materialized profile rows'
);
select lives_ok(
  $$
    select public.set_own_notification_preference(
      'e2000000-0000-4000-8000-000000000002',
      'chat',
      false,
      true
    )
  $$,
  'an owner can update one configurable category'
);
select is(
  (
    select count(*)
    from public.list_own_notification_preferences(
      'e2000000-0000-4000-8000-000000000002'
    ) as preference
    where preference.has_override
  ),
  1::bigint,
  'updating one category does not materialize or alter the others'
);
select throws_ok(
  $$
    select *
    from public.list_own_notification_preferences(
      'e1000000-0000-4000-8000-000000000001'
    )
  $$,
  '42501',
  'The authenticated user does not match the expected notification identity.',
  'cross-account preference reads fail at the expected-identity boundary'
);
select throws_ok(
  $$
    select public.set_own_notification_preference(
      'e1000000-0000-4000-8000-000000000001',
      'participation',
      false,
      false
    )
  $$,
  '42501',
  'The authenticated user does not match the expected notification identity.',
  'cross-account preference mutations fail'
);
select throws_ok(
  $$
    select public.set_own_notification_preference(
      'e2000000-0000-4000-8000-000000000002',
      'unknown',
      false,
      false
    )
  $$,
  '22023',
  'The notification category is unknown or not user-configurable.',
  'unknown preference categories fail explicitly'
);
select throws_ok(
  'select * from public.process_notification_outbox_batch(100)',
  '42501',
  'permission denied for function process_notification_outbox_batch',
  'authenticated clients cannot run the projector'
);

set local role service_role;
select results_eq(
  $$
    select processed_count, notifications_created, notifications_suppressed
    from public.process_notification_outbox_batch(100)
  $$,
  $$values (6, 6, 0)$$,
  'the first trusted batch projects all six supported events'
);

reset role;
select results_eq(
  $$
    select
      notification.notification_kind,
      notification.recipient_profile_id,
      notification.actor_profile_id,
      notification.destination_kind,
      project.project_kind
    from public.notifications as notification
    join public.projects as project on project.id = notification.project_id
    order by notification.notification_kind
  $$,
  $$
    values
      (
        'participant_left'::text,
        'e1000000-0000-4000-8000-000000000001'::uuid,
        'e2000000-0000-4000-8000-000000000002'::uuid,
        'project_participation'::text,
        'one_time'::text
      ),
      (
        'participant_removed'::text,
        'e2000000-0000-4000-8000-000000000002'::uuid,
        'e1000000-0000-4000-8000-000000000001'::uuid,
        'project_detail'::text,
        'recurring'::text
      ),
      (
        'participation_request_accepted'::text,
        'e2000000-0000-4000-8000-000000000002'::uuid,
        'e1000000-0000-4000-8000-000000000001'::uuid,
        'project_detail'::text,
        'one_time'::text
      ),
      (
        'participation_request_received'::text,
        'e1000000-0000-4000-8000-000000000001'::uuid,
        'e2000000-0000-4000-8000-000000000002'::uuid,
        'project_participation'::text,
        'one_time'::text
      ),
      (
        'participation_request_rejected'::text,
        'e2000000-0000-4000-8000-000000000002'::uuid,
        'e1000000-0000-4000-8000-000000000001'::uuid,
        'project_detail'::text,
        'recurring'::text
      ),
      (
        'participation_request_withdrawn'::text,
        'e1000000-0000-4000-8000-000000000001'::uuid,
        'e2000000-0000-4000-8000-000000000002'::uuid,
        'project_participation'::text,
        'recurring'::text
      )
  $$,
  'every current event has the canonical recipient, actor, destination, and project kind'
);
select is(
  (
    select count(*)
    from private.outbox_consumer_receipts
    where consumer_key = 'notifications.v1'
  ),
  6::bigint,
  'each supported source event has one stable notification-consumer receipt'
);
select is(
  (
    select count(*)
    from private.outbox_consumer_receipts
    where outbox_event_id = 'c9000000-0000-4000-8000-000000000009'
  ),
  0::bigint,
  'unsupported outbox events remain untouched by the notification consumer'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'e2000000-0000-4000-8000-000000000002',
  true
);
select is(
  public.get_own_unread_notification_count(
    'e2000000-0000-4000-8000-000000000002'
  ),
  3::bigint,
  'the requester sees three unread decision/removal notifications'
);
select is(
  (
    select count(*)
    from public.list_own_notifications(
      'e2000000-0000-4000-8000-000000000002',
      20,
      null,
      null
    )
  ),
  3::bigint,
  'an inbox lists only its owner notifications'
);
select ok(
  exists (
    select 1
    from public.list_own_notifications(
      'e2000000-0000-4000-8000-000000000002',
      20,
      null,
      null
    ) as notification
    where notification.notification_kind = 'participation_request_accepted'
      and notification.project_title = 'Notification proposal'
      and notification.project_kind = 'one_time'
      and notification.actor_display_name = 'Notification Creator'
      and notification.destination_kind = 'project_detail'
  ),
  'the inbox resolves authorized actor and structured current project context'
);
select ok(
  not exists (
    select 1
    from public.list_own_notifications(
      'e2000000-0000-4000-8000-000000000002',
      20,
      null,
      null
    ) as notification
    where to_jsonb(notification)::text like '%Private request message%'
      or to_jsonb(notification)::text like '%Secret notification%'
      or to_jsonb(notification)::text like '%@planets.invalid%'
      or to_jsonb(notification) ? 'source_outbox_event_id'
  ),
  'inbox output contains no request message, meeting secret, email, or source payload identity'
);
select is(
  (
    with first_page as (
      select *
      from public.list_own_notifications(
        'e2000000-0000-4000-8000-000000000002',
        1,
        null,
        null
      )
    )
    select count(*)
    from first_page
    cross join lateral public.list_own_notifications(
      'e2000000-0000-4000-8000-000000000002',
      1,
      first_page.created_at,
      first_page.notification_id
    ) as second_page
    where second_page.notification_id <> first_page.notification_id
  ),
  1::bigint,
  'keyset pagination advances without repeating the cursor row'
);
select throws_ok(
  $$
    select *
    from public.list_own_notifications(
      'e2000000-0000-4000-8000-000000000002',
      20,
      statement_timestamp(),
      null
    )
  $$,
  '22023',
  'Notification pagination requires both cursor timestamp and cursor ID.',
  'partial notification cursors fail explicitly'
);
select lives_ok(
  $$
    select public.mark_notification_read(
      'e2000000-0000-4000-8000-000000000002',
      (
        select notification_id
        from public.list_own_notifications(
          'e2000000-0000-4000-8000-000000000002',
          20,
          null,
          null
        )
        where notification_kind = 'participation_request_accepted'
      )
    )
  $$,
  'the owner can mark one notification read'
);
select is(
  public.get_own_unread_notification_count(
    'e2000000-0000-4000-8000-000000000002'
  ),
  2::bigint,
  'marking one read decrements unread count'
);
select is(
  public.mark_notification_read(
    'e2000000-0000-4000-8000-000000000002',
    (
      select notification_id
      from public.list_own_notifications(
        'e2000000-0000-4000-8000-000000000002',
        20,
        null,
        null
      )
      where notification_kind = 'participation_request_accepted'
    )
  ),
  (
    select read_at
    from public.list_own_notifications(
      'e2000000-0000-4000-8000-000000000002',
      20,
      null,
      null
    )
    where notification_kind = 'participation_request_accepted'
  ),
  'marking an already-read notification is idempotent'
);
select is(
  public.mark_all_notifications_read(
    'e2000000-0000-4000-8000-000000000002'
  ),
  2,
  'mark-all updates only remaining unread notifications'
);
select is(
  public.mark_all_notifications_read(
    'e2000000-0000-4000-8000-000000000002'
  ),
  0,
  'repeating mark-all is idempotent'
);

reset role;
select set_config(
  'test.requester_notification_id',
  (
    select id::text
    from public.notifications
    where recipient_profile_id = 'e2000000-0000-4000-8000-000000000002'
    order by created_at, id
    limit 1
  ),
  true
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'e1000000-0000-4000-8000-000000000001',
  true
);
select throws_ok(
  $$
    select *
    from public.list_own_notifications(
      'e2000000-0000-4000-8000-000000000002',
      20,
      null,
      null
    )
  $$,
  '42501',
  'The authenticated user does not match the expected notification identity.',
  'a creator cannot impersonate another inbox identity'
);
select throws_ok(
  $$
    select public.mark_notification_read(
      'e1000000-0000-4000-8000-000000000001',
      current_setting('test.requester_notification_id')::uuid
    )
  $$,
  '42501',
  'The notification is unavailable to the authenticated identity.',
  'cross-user mark-read does not reveal or mutate the notification'
);
select lives_ok(
  $$
    select public.set_own_notification_preference(
      'e1000000-0000-4000-8000-000000000001',
      'participation',
      false,
      true
    )
  $$,
  'the creator can disable future in-app participation projection'
);

reset role;
insert into public.project_join_requests (
  id,
  project_id,
  requester_profile_id,
  status,
  request_message,
  created_at
)
values (
  'a7000000-0000-4000-8000-000000000007',
  'f2000000-0000-4000-8000-000000000002',
  'e3000000-0000-4000-8000-000000000003',
  'pending',
  null,
  statement_timestamp() - interval '20 minutes'
);
insert into private.outbox_events (id, event_type, payload, created_at, available_at)
values (
  'c7000000-0000-4000-8000-000000000007',
  'project.join_requested',
  jsonb_build_object(
    'project_id', 'f2000000-0000-4000-8000-000000000002',
    'project_kind', 'recurring',
    'actor_profile_id', 'e3000000-0000-4000-8000-000000000003',
    'request_id', 'a7000000-0000-4000-8000-000000000007',
    'requester_profile_id', 'e3000000-0000-4000-8000-000000000003',
    'status', 'pending'
  ),
  statement_timestamp() - interval '20 minutes',
  statement_timestamp() - interval '20 minutes'
);

set local role service_role;
select results_eq(
  $$
    select processed_count, notifications_created, notifications_suppressed
    from public.process_notification_outbox_batch(100)
  $$,
  $$values (1, 0, 1)$$,
  'a disabled in-app event is suppressed but processed'
);

reset role;
select is(
  (
    select count(*)
    from private.outbox_consumer_receipts
    where outbox_event_id = 'c7000000-0000-4000-8000-000000000007'
      and consumer_key = 'notifications.v1'
  ),
  1::bigint,
  'a preference-suppressed event is receipted exactly once'
);
select is(
  (
    select count(*)
    from public.notifications
    where source_outbox_event_id = 'c7000000-0000-4000-8000-000000000007'
  ),
  0::bigint,
  'suppression does not create a notification row'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'e1000000-0000-4000-8000-000000000001',
  true
);
select lives_ok(
  $$
    select public.set_own_notification_preference(
      'e1000000-0000-4000-8000-000000000001',
      'participation',
      true,
      true
    )
  $$,
  're-enabling participation affects future events'
);

reset role;
update public.project_join_requests
set
  status = 'withdrawn',
  resolved_at = statement_timestamp() - interval '10 minutes',
  resolved_by_profile_id = 'e3000000-0000-4000-8000-000000000003'
where id = 'a7000000-0000-4000-8000-000000000007';
insert into private.outbox_events (id, event_type, payload, created_at, available_at)
values (
  'c8000000-0000-4000-8000-000000000008',
  'project.join_request_withdrawn',
  jsonb_build_object(
    'project_id', 'f2000000-0000-4000-8000-000000000002',
    'project_kind', 'recurring',
    'actor_profile_id', 'e3000000-0000-4000-8000-000000000003',
    'request_id', 'a7000000-0000-4000-8000-000000000007',
    'requester_profile_id', 'e3000000-0000-4000-8000-000000000003',
    'status', 'withdrawn'
  ),
  statement_timestamp() - interval '10 minutes',
  statement_timestamp() - interval '10 minutes'
);

set local role service_role;
select results_eq(
  $$
    select processed_count, notifications_created, notifications_suppressed
    from public.process_notification_outbox_batch(100)
  $$,
  $$values (1, 1, 0)$$,
  're-enabled preferences permit only the later event notification'
);

reset role;
insert into private.outbox_consumer_receipts (
  outbox_event_id,
  consumer_key,
  processed_at
)
values (
  'c3000000-0000-4000-8000-000000000003',
  'chat.v1',
  statement_timestamp()
);
select is(
  (
    select count(*)
    from private.outbox_consumer_receipts
    where outbox_event_id = 'c3000000-0000-4000-8000-000000000003'
  ),
  2::bigint,
  'a future independent consumer can receipt the same accepted event'
);

delete from private.outbox_consumer_receipts
where outbox_event_id = 'c1000000-0000-4000-8000-000000000001'
  and consumer_key = 'notifications.v1';

set local role service_role;
select results_eq(
  $$
    select processed_count, notifications_created, notifications_suppressed
    from public.process_notification_outbox_batch(100)
  $$,
  $$values (1, 0, 0)$$,
  'a lost success response can be retried without duplicating a notification'
);
select results_eq(
  $$
    select processed_count, notifications_created, notifications_suppressed
    from public.process_notification_outbox_batch(100)
  $$,
  $$values (0, 0, 0)$$,
  'a fully receipted batch is idempotently empty'
);

reset role;
select is(
  (
    select count(*)
    from public.notifications
    where source_outbox_event_id = 'c1000000-0000-4000-8000-000000000001'
  ),
  1::bigint,
  'database uniqueness keeps a retried source event singular'
);
select is(
  (
    select count(*)
    from private.outbox_consumer_receipts
    where outbox_event_id = 'c9000000-0000-4000-8000-000000000009'
      and consumer_key = 'notifications.v1'
  ),
  0::bigint,
  'unsupported outbox state is still available to future owning plans'
);

insert into private.outbox_events (id, event_type, payload, created_at, available_at)
values (
  'ca000000-0000-4000-8000-000000000010',
  'project.join_requested',
  jsonb_build_object(
    'project_id', 'f1000000-0000-4000-8000-000000000001',
    'project_kind', 'one_time',
    'actor_profile_id', 'e3000000-0000-4000-8000-000000000003',
    'request_id', 'aa000000-0000-4000-8000-000000000010',
    'requester_profile_id', 'e3000000-0000-4000-8000-000000000003',
    'status', 'pending'
  ),
  statement_timestamp() - interval '5 minutes',
  statement_timestamp() - interval '5 minutes'
);

set local role service_role;
select throws_ok(
  'select * from public.process_notification_outbox_batch(100)',
  '55000',
  'Notification projection could not validate outbox event ca000000-0000-4000-8000-000000000010 against its canonical join request.',
  'an impossible recipient mapping fails visibly instead of guessing'
);

reset role;
select is(
  (
    select count(*)
    from private.outbox_consumer_receipts
    where outbox_event_id = 'ca000000-0000-4000-8000-000000000010'
  ),
  0::bigint,
  'a failed projection never records success-shaped receipt state'
);

select * from finish();

rollback;
