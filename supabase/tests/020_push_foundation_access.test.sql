begin;

select no_plan();

insert into auth.users (id, email)
values
  ('d1000000-0000-4000-8000-000000000001', 'push-creator@planets.invalid'),
  ('d2000000-0000-4000-8000-000000000002', 'push-requester@planets.invalid'),
  ('d3000000-0000-4000-8000-000000000003', 'push-other@planets.invalid');

insert into public.profiles (id, display_name)
values
  ('d1000000-0000-4000-8000-000000000001', 'Push Creator'),
  ('d2000000-0000-4000-8000-000000000002', 'Push Requester'),
  ('d3000000-0000-4000-8000-000000000003', 'Push Other');

set local role anon;
select throws_ok(
  $$
    select *
    from public.register_own_push_installation(
      null,
      '91000000-0000-4000-8000-000000000001',
      'android',
      'synthetic-token-1'
    )
  $$,
  '42501',
  'permission denied for function register_own_push_installation',
  'anonymous clients cannot register an installation'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'd2000000-0000-4000-8000-000000000002',
  true
);
select throws_ok(
  $$
    select *
    from public.register_own_push_installation(
      'd1000000-0000-4000-8000-000000000001',
      '91000000-0000-4000-8000-000000000001',
      'android',
      'synthetic-token-1'
    )
  $$,
  '42501',
  'The authenticated user does not match the expected push-registration identity.',
  'registration rejects a stale cross-account expected identity'
);
select throws_ok(
  $$
    select *
    from public.register_own_push_installation(
      'd2000000-0000-4000-8000-000000000002',
      '91000000-0000-4000-8000-000000000001',
      'web',
      'synthetic-token-1'
    )
  $$,
  '22023',
  'Push platform must be android or ios.',
  'registration accepts only the current Android and iOS platforms'
);
select throws_ok(
  $$
    select *
    from public.register_own_push_installation(
      'd2000000-0000-4000-8000-000000000002',
      '91000000-0000-4000-8000-000000000001',
      'android',
      ''
    )
  $$,
  '22023',
  'A valid push provider token is required.',
  'empty provider tokens fail without reflecting token text'
);
select throws_ok(
  $$
    select *
    from public.register_own_push_installation(
      'd2000000-0000-4000-8000-000000000002',
      '91000000-0000-4000-8000-000000000001',
      'android',
      repeat('x', 4097)
    )
  $$,
  '22023',
  'A valid push provider token is required.',
  'oversized provider tokens fail with a content-free error'
);
select lives_ok(
  $$
    select *
    from public.register_own_push_installation(
      'd2000000-0000-4000-8000-000000000002',
      '91000000-0000-4000-8000-000000000001',
      'android',
      'synthetic-token-1'
    )
  $$,
  'an authenticated profile can register one Android installation'
);
select ok(
  (
    select to_jsonb(registration)::text
    from public.register_own_push_installation(
      'd2000000-0000-4000-8000-000000000002',
      '91000000-0000-4000-8000-000000000001',
      'android',
      'synthetic-token-1'
    ) as registration
  ) not like '%synthetic-token-1%'
    and (
      select to_jsonb(registration) ? 'provider_token'
      from public.register_own_push_installation(
        'd2000000-0000-4000-8000-000000000002',
        '91000000-0000-4000-8000-000000000001',
        'android',
        'synthetic-token-1'
      ) as registration
    ) is false,
  'idempotent registration returns safe metadata without token material'
);
select lives_ok(
  $$
    select *
    from public.register_own_push_installation(
      'd2000000-0000-4000-8000-000000000002',
      '91000000-0000-4000-8000-000000000001',
      'android',
      'synthetic-token-2'
    )
  $$,
  'the installation can rotate to a new provider token'
);

reset role;
select is(
  (
    select count(*)
    from private.push_installations
    where installation_id = '91000000-0000-4000-8000-000000000001'
      and profile_id = 'd2000000-0000-4000-8000-000000000002'
      and provider = 'fcm'
      and platform = 'android'
      and provider_token = 'synthetic-token-2'
      and disabled_at is null
  ),
  1::bigint,
  'same-installation registration is idempotent and token rotation is singular'
);
select is(
  (
    select count(*)
    from private.push_installations
    where provider_token = 'synthetic-token-1'
  ),
  0::bigint,
  'the superseded provider token is no longer active or retained'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'd3000000-0000-4000-8000-000000000003',
  true
);
select lives_ok(
  $$
    select *
    from public.register_own_push_installation(
      'd3000000-0000-4000-8000-000000000003',
      '91000000-0000-4000-8000-000000000001',
      'ios',
      'synthetic-token-2'
    )
  $$,
  'registering the same installation under a new account transfers ownership'
);

reset role;
select is(
  (
    select count(*)
    from private.push_installations
    where installation_id = '91000000-0000-4000-8000-000000000001'
      and profile_id = 'd3000000-0000-4000-8000-000000000003'
      and platform = 'ios'
      and provider_token = 'synthetic-token-2'
      and disabled_at is null
  ),
  1::bigint,
  'the transferred installation has exactly one current profile and platform'
);
select is(
  (
    select count(*)
    from private.push_installations
    where installation_id = '91000000-0000-4000-8000-000000000001'
      and profile_id = 'd2000000-0000-4000-8000-000000000002'
  ),
  0::bigint,
  'the previous profile no longer owns the transferred installation'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'd2000000-0000-4000-8000-000000000002',
  true
);
select throws_ok(
  $$
    select public.unregister_own_push_installation(
      'd2000000-0000-4000-8000-000000000002',
      '91000000-0000-4000-8000-000000000001'
    )
  $$,
  '42501',
  'The push installation is unavailable to the authenticated identity.',
  'the previous profile cannot unregister a transferred installation'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'd3000000-0000-4000-8000-000000000003',
  true
);
select is(
  public.unregister_own_push_installation(
    'd3000000-0000-4000-8000-000000000003',
    '91000000-0000-4000-8000-000000000001'
  ),
  true,
  'the current owner can unregister its installation'
);
select is(
  public.unregister_own_push_installation(
    'd3000000-0000-4000-8000-000000000003',
    '91000000-0000-4000-8000-000000000001'
  ),
  false,
  'repeating owner unregister is safely idempotent'
);

reset role;
select ok(
  exists (
    select 1
    from private.push_installations
    where installation_id = '91000000-0000-4000-8000-000000000001'
      and provider_token is null
      and disabled_at is not null
  ),
  'unregister clears private token material and disables future eligibility'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'd2000000-0000-4000-8000-000000000002',
  true
);
select lives_ok(
  $$
    select *
    from public.register_own_push_installation(
      'd2000000-0000-4000-8000-000000000002',
      '92000000-0000-4000-8000-000000000002',
      'android',
      'synthetic-shared-token'
    )
  $$,
  'a second Android installation can register'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'd3000000-0000-4000-8000-000000000003',
  true
);
select throws_ok(
  $$
    select public.unregister_own_push_installation(
      'd3000000-0000-4000-8000-000000000003',
      '92000000-0000-4000-8000-000000000002'
    )
  $$,
  '42501',
  'The push installation is unavailable to the authenticated identity.',
  'an unrelated profile cannot unregister another active installation'
);
select lives_ok(
  $$
    select *
    from public.register_own_push_installation(
      'd3000000-0000-4000-8000-000000000003',
      '93000000-0000-4000-8000-000000000003',
      'ios',
      'synthetic-shared-token'
    )
  $$,
  'reusing a provider token transfers active token ownership atomically'
);

reset role;
select is(
  (
    select count(*)
    from private.push_installations
    where provider = 'fcm'
      and provider_token = 'synthetic-shared-token'
      and disabled_at is null
  ),
  1::bigint,
  'one provider token remains assigned to one active installation'
);
select ok(
  exists (
    select 1
    from private.push_installations
    where installation_id = '92000000-0000-4000-8000-000000000002'
      and provider_token is null
      and disabled_at is not null
  ),
  'the displaced token owner is disabled and no longer retains the token'
);

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
  'd1000000-0000-4000-8000-000000000001',
  'published',
  'Push proposal',
  statement_timestamp() - interval '1 hour',
  statement_timestamp() + interval '2 hours',
  statement_timestamp() - interval '1 day',
  null
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
  'd1000000-0000-4000-8000-000000000001',
  'published',
  'Push Tavolo',
  statement_timestamp() - interval '1 day',
  null,
  null
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
    'd2000000-0000-4000-8000-000000000002',
    'pending',
    'Private push request message',
    statement_timestamp() - interval '12 hours',
    null,
    null
  ),
  (
    'a2000000-0000-4000-8000-000000000002',
    'f2000000-0000-4000-8000-000000000002',
    'd2000000-0000-4000-8000-000000000002',
    'withdrawn',
    null,
    statement_timestamp() - interval '11 hours',
    statement_timestamp() - interval '10 hours 50 minutes',
    'd2000000-0000-4000-8000-000000000002'
  ),
  (
    'a3000000-0000-4000-8000-000000000003',
    'f1000000-0000-4000-8000-000000000001',
    'd2000000-0000-4000-8000-000000000002',
    'accepted',
    null,
    statement_timestamp() - interval '10 hours',
    statement_timestamp() - interval '9 hours 50 minutes',
    'd1000000-0000-4000-8000-000000000001'
  ),
  (
    'a4000000-0000-4000-8000-000000000004',
    'f2000000-0000-4000-8000-000000000002',
    'd2000000-0000-4000-8000-000000000002',
    'rejected',
    null,
    statement_timestamp() - interval '9 hours',
    statement_timestamp() - interval '8 hours 50 minutes',
    'd1000000-0000-4000-8000-000000000001'
  ),
  (
    'a5000000-0000-4000-8000-000000000005',
    'f1000000-0000-4000-8000-000000000001',
    'd2000000-0000-4000-8000-000000000002',
    'accepted',
    null,
    statement_timestamp() - interval '8 hours',
    statement_timestamp() - interval '7 hours 50 minutes',
    'd1000000-0000-4000-8000-000000000001'
  ),
  (
    'a6000000-0000-4000-8000-000000000006',
    'f2000000-0000-4000-8000-000000000002',
    'd2000000-0000-4000-8000-000000000002',
    'accepted',
    null,
    statement_timestamp() - interval '7 hours',
    statement_timestamp() - interval '6 hours 50 minutes',
    'd1000000-0000-4000-8000-000000000001'
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
    'd2000000-0000-4000-8000-000000000002',
    'a3000000-0000-4000-8000-000000000003',
    statement_timestamp() - interval '9 hours 50 minutes',
    null,
    null,
    null
  ),
  (
    'b5000000-0000-4000-8000-000000000005',
    'f1000000-0000-4000-8000-000000000001',
    'd2000000-0000-4000-8000-000000000002',
    'a5000000-0000-4000-8000-000000000005',
    statement_timestamp() - interval '7 hours 50 minutes',
    statement_timestamp() - interval '7 hours 40 minutes',
    null,
    null
  ),
  (
    'b6000000-0000-4000-8000-000000000006',
    'f2000000-0000-4000-8000-000000000002',
    'd2000000-0000-4000-8000-000000000002',
    'a6000000-0000-4000-8000-000000000006',
    statement_timestamp() - interval '6 hours 50 minutes',
    null,
    statement_timestamp() - interval '6 hours 40 minutes',
    'd1000000-0000-4000-8000-000000000001'
  );

insert into private.outbox_events (id, event_type, payload, created_at, available_at)
values
  (
    'c1000000-0000-4000-8000-000000000001',
    'project.join_requested',
    jsonb_build_object(
      'project_id', 'f1000000-0000-4000-8000-000000000001',
      'project_kind', 'one_time',
      'actor_profile_id', 'd2000000-0000-4000-8000-000000000002',
      'request_id', 'a1000000-0000-4000-8000-000000000001',
      'requester_profile_id', 'd2000000-0000-4000-8000-000000000002'
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
      'actor_profile_id', 'd2000000-0000-4000-8000-000000000002',
      'request_id', 'a2000000-0000-4000-8000-000000000002',
      'requester_profile_id', 'd2000000-0000-4000-8000-000000000002'
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
      'actor_profile_id', 'd1000000-0000-4000-8000-000000000001',
      'request_id', 'a3000000-0000-4000-8000-000000000003',
      'requester_profile_id', 'd2000000-0000-4000-8000-000000000002',
      'membership_id', 'b3000000-0000-4000-8000-000000000003'
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
      'actor_profile_id', 'd1000000-0000-4000-8000-000000000001',
      'request_id', 'a4000000-0000-4000-8000-000000000004',
      'requester_profile_id', 'd2000000-0000-4000-8000-000000000002'
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
      'actor_profile_id', 'd2000000-0000-4000-8000-000000000002',
      'membership_id', 'b5000000-0000-4000-8000-000000000005',
      'participant_profile_id', 'd2000000-0000-4000-8000-000000000002'
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
      'actor_profile_id', 'd1000000-0000-4000-8000-000000000001',
      'membership_id', 'b6000000-0000-4000-8000-000000000006',
      'participant_profile_id', 'd2000000-0000-4000-8000-000000000002'
    ),
    statement_timestamp() - interval '1 hour',
    statement_timestamp() - interval '1 hour'
  ),
  (
    'cf000000-0000-4000-8000-00000000000f',
    'project.unsupported_for_push',
    '{}'::jsonb,
    statement_timestamp() - interval '30 minutes',
    statement_timestamp() - interval '30 minutes'
  );

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'd1000000-0000-4000-8000-000000000001',
  true
);
select throws_ok(
  'select * from public.process_push_outbox_batch(100)',
  '42501',
  'permission denied for function process_push_outbox_batch',
  'authenticated clients cannot run the push projector'
);

set local role service_role;
select results_eq(
  $$
    select processed_count, jobs_created, jobs_suppressed
    from public.process_push_outbox_batch(100)
  $$,
  $$values (6, 6, 0)$$,
  'push.v1 projects all six supported semantic events by default'
);
select results_eq(
  $$
    select processed_count, notifications_created, notifications_suppressed
    from public.process_notification_outbox_batch(100)
  $$,
  $$values (6, 6, 0)$$,
  'the refactored notifications.v1 projector preserves all six mappings'
);

reset role;
select results_eq(
  $$
    select
      job.notification_kind,
      job.recipient_profile_id,
      job.actor_profile_id,
      job.destination_kind,
      job.project_kind
    from private.push_delivery_jobs as job
    order by job.notification_kind
  $$,
  $$
    values
      (
        'participant_left'::text,
        'd1000000-0000-4000-8000-000000000001'::uuid,
        'd2000000-0000-4000-8000-000000000002'::uuid,
        'project_participation'::text,
        'one_time'::text
      ),
      (
        'participant_removed'::text,
        'd2000000-0000-4000-8000-000000000002'::uuid,
        'd1000000-0000-4000-8000-000000000001'::uuid,
        'project_detail'::text,
        'recurring'::text
      ),
      (
        'participation_request_accepted'::text,
        'd2000000-0000-4000-8000-000000000002'::uuid,
        'd1000000-0000-4000-8000-000000000001'::uuid,
        'participation_request'::text,
        'one_time'::text
      ),
      (
        'participation_request_received'::text,
        'd1000000-0000-4000-8000-000000000001'::uuid,
        'd2000000-0000-4000-8000-000000000002'::uuid,
        'participation_request'::text,
        'one_time'::text
      ),
      (
        'participation_request_rejected'::text,
        'd2000000-0000-4000-8000-000000000002'::uuid,
        'd1000000-0000-4000-8000-000000000001'::uuid,
        'participation_request'::text,
        'recurring'::text
      ),
      (
        'participation_request_withdrawn'::text,
        'd1000000-0000-4000-8000-000000000001'::uuid,
        'd2000000-0000-4000-8000-000000000002'::uuid,
        'participation_request'::text,
        'recurring'::text
      )
  $$,
  'push and in-app share the canonical six-event recipient and destination mapping'
);
select is(
  (
    select count(*)
    from private.push_installations
    where profile_id = 'd1000000-0000-4000-8000-000000000001'
      and disabled_at is null
  ),
  0::bigint,
  'the creator has no active installation'
);
select is(
  (
    select count(*)
    from private.push_delivery_jobs
    where recipient_profile_id = 'd1000000-0000-4000-8000-000000000001'
  ),
  3::bigint,
  'recipient-level jobs exist even when the recipient currently has no target installation'
);
select ok(
  not exists (
    select 1
    from private.push_delivery_jobs as job
    where to_jsonb(job)::text like '%synthetic-%'
      or to_jsonb(job)::text like '%Private push request message%'
      or to_jsonb(job) ? 'payload'
      or to_jsonb(job) ? 'provider_token'
  ),
  'jobs contain no provider token, request message, or raw source payload'
);
select is(
  (
    select count(*)
    from private.outbox_consumer_receipts
    where consumer_key = 'notifications.v1'
  ),
  6::bigint,
  'notifications.v1 independently receipts all six events'
);
select is(
  (
    select count(*)
    from private.outbox_consumer_receipts
    where consumer_key = 'push.v1'
  ),
  6::bigint,
  'push.v1 independently receipts all six events'
);
select is(
  (
    select count(*)
    from private.outbox_consumer_receipts
    where outbox_event_id = 'cf000000-0000-4000-8000-00000000000f'
  ),
  0::bigint,
  'unsupported events remain untouched for future consumers'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'd1000000-0000-4000-8000-000000000001',
  true
);
select lives_ok(
  $$
    select public.set_own_notification_preference(
      'd1000000-0000-4000-8000-000000000001',
      'participation',
      false,
      true
    )
  $$,
  'the creator can select in-app false and push true independently'
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
  'f1000000-0000-4000-8000-000000000001',
  'd3000000-0000-4000-8000-000000000003',
  'pending',
  'Private independently suppressed request',
  statement_timestamp() - interval '20 minutes'
);
insert into private.outbox_events (id, event_type, payload, created_at, available_at)
values (
  'c7000000-0000-4000-8000-000000000007',
  'project.join_requested',
  jsonb_build_object(
    'project_id', 'f1000000-0000-4000-8000-000000000001',
    'project_kind', 'one_time',
    'actor_profile_id', 'd3000000-0000-4000-8000-000000000003',
    'request_id', 'a7000000-0000-4000-8000-000000000007',
    'requester_profile_id', 'd3000000-0000-4000-8000-000000000003'
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
  'in-app false suppresses only the in-app projection'
);
select results_eq(
  $$
    select processed_count, jobs_created, jobs_suppressed
    from public.process_push_outbox_batch(100)
  $$,
  $$values (1, 1, 0)$$,
  'in-app false with push true still creates a push job'
);

reset role;
select ok(
  exists (
    select 1
    from private.push_delivery_jobs
    where source_outbox_event_id = 'c7000000-0000-4000-8000-000000000007'
  )
    and not exists (
      select 1
      from public.notifications
      where source_outbox_event_id = 'c7000000-0000-4000-8000-000000000007'
    ),
  'channel independence does not rely on a public notification row'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'd1000000-0000-4000-8000-000000000001',
  true
);
select public.set_own_notification_preference(
  'd1000000-0000-4000-8000-000000000001',
  'participation',
  true,
  false
);

reset role;
update public.project_join_requests
set
  status = 'withdrawn',
  resolved_at = statement_timestamp() - interval '15 minutes',
  resolved_by_profile_id = 'd3000000-0000-4000-8000-000000000003'
where id = 'a7000000-0000-4000-8000-000000000007';
insert into private.outbox_events (id, event_type, payload, created_at, available_at)
values (
  'c8000000-0000-4000-8000-000000000008',
  'project.join_request_withdrawn',
  jsonb_build_object(
    'project_id', 'f1000000-0000-4000-8000-000000000001',
    'project_kind', 'one_time',
    'actor_profile_id', 'd3000000-0000-4000-8000-000000000003',
    'request_id', 'a7000000-0000-4000-8000-000000000007',
    'requester_profile_id', 'd3000000-0000-4000-8000-000000000003'
  ),
  statement_timestamp() - interval '15 minutes',
  statement_timestamp() - interval '15 minutes'
);

set local role service_role;
select results_eq(
  $$
    select processed_count, notifications_created, notifications_suppressed
    from public.process_notification_outbox_batch(100)
  $$,
  $$values (1, 1, 0)$$,
  'in-app true still creates its notification when push is disabled'
);
select results_eq(
  $$
    select processed_count, jobs_created, jobs_suppressed
    from public.process_push_outbox_batch(100)
  $$,
  $$values (1, 0, 1)$$,
  'push false creates no job but successfully receipts push.v1'
);

reset role;
select ok(
  not exists (
    select 1
    from private.push_delivery_jobs
    where source_outbox_event_id = 'c8000000-0000-4000-8000-000000000008'
  )
    and exists (
      select 1
      from public.notifications
      where source_outbox_event_id = 'c8000000-0000-4000-8000-000000000008'
    )
    and exists (
      select 1
      from private.outbox_consumer_receipts
      where outbox_event_id = 'c8000000-0000-4000-8000-000000000008'
        and consumer_key = 'push.v1'
    ),
  'push-disabled projection records success without a job or affecting in-app'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'd1000000-0000-4000-8000-000000000001',
  true
);
select public.set_own_notification_preference(
  'd1000000-0000-4000-8000-000000000001',
  'participation',
  false,
  false
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
  'a8000000-0000-4000-8000-000000000008',
  'f1000000-0000-4000-8000-000000000001',
  'd3000000-0000-4000-8000-000000000003',
  'pending',
  'Private both-disabled request',
  statement_timestamp() - interval '10 minutes'
);
insert into private.outbox_events (id, event_type, payload, created_at, available_at)
values (
  'c9000000-0000-4000-8000-000000000009',
  'project.join_requested',
  jsonb_build_object(
    'project_id', 'f1000000-0000-4000-8000-000000000001',
    'project_kind', 'one_time',
    'actor_profile_id', 'd3000000-0000-4000-8000-000000000003',
    'request_id', 'a8000000-0000-4000-8000-000000000008',
    'requester_profile_id', 'd3000000-0000-4000-8000-000000000003'
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
  $$values (1, 0, 1)$$,
  'both-disabled preference suppresses the in-app projection'
);
select results_eq(
  $$
    select processed_count, jobs_created, jobs_suppressed
    from public.process_push_outbox_batch(100)
  $$,
  $$values (1, 0, 1)$$,
  'both-disabled preference suppresses the push projection'
);

reset role;
select ok(
  not exists (
    select 1
    from public.notifications
    where source_outbox_event_id = 'c9000000-0000-4000-8000-000000000009'
  )
    and not exists (
      select 1
      from private.push_delivery_jobs
      where source_outbox_event_id = 'c9000000-0000-4000-8000-000000000009'
    )
    and (
      select count(*)
      from private.outbox_consumer_receipts
      where outbox_event_id = 'c9000000-0000-4000-8000-000000000009'
        and consumer_key in ('notifications.v1', 'push.v1')
    ) = 2,
  'both-disabled preference records both channel receipts without delivery rows'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'd1000000-0000-4000-8000-000000000001',
  true
);
select public.set_own_notification_preference(
  'd1000000-0000-4000-8000-000000000001',
  'participation',
  true,
  true
);

reset role;
update public.project_join_requests
set
  status = 'withdrawn',
  resolved_at = statement_timestamp() - interval '5 minutes',
  resolved_by_profile_id = 'd3000000-0000-4000-8000-000000000003'
where id = 'a8000000-0000-4000-8000-000000000008';
insert into private.outbox_events (id, event_type, payload, created_at, available_at)
values (
  'ca000000-0000-4000-8000-00000000000a',
  'project.join_request_withdrawn',
  jsonb_build_object(
    'project_id', 'f1000000-0000-4000-8000-000000000001',
    'project_kind', 'one_time',
    'actor_profile_id', 'd3000000-0000-4000-8000-000000000003',
    'request_id', 'a8000000-0000-4000-8000-000000000008',
    'requester_profile_id', 'd3000000-0000-4000-8000-000000000003'
  ),
  statement_timestamp() - interval '5 minutes',
  statement_timestamp() - interval '5 minutes'
);

set local role service_role;
select results_eq(
  $$
    select processed_count, notifications_created, notifications_suppressed
    from public.process_notification_outbox_batch(100)
  $$,
  $$values (1, 1, 0)$$,
  'both-enabled preference creates the in-app projection'
);
select results_eq(
  $$
    select processed_count, jobs_created, jobs_suppressed
    from public.process_push_outbox_batch(100)
  $$,
  $$values (1, 1, 0)$$,
  'both-enabled preference creates the push projection'
);

reset role;
select ok(
  exists (
    select 1
    from public.notifications
    where source_outbox_event_id = 'ca000000-0000-4000-8000-00000000000a'
  )
    and exists (
      select 1
      from private.push_delivery_jobs
      where source_outbox_event_id = 'ca000000-0000-4000-8000-00000000000a'
    ),
  'both-enabled preference creates one delivery row for each channel'
);

insert into private.outbox_consumer_receipts (
  outbox_event_id,
  consumer_key,
  processed_at
)
values (
  'c7000000-0000-4000-8000-000000000007',
  'future.consumer.v1',
  statement_timestamp()
);
select is(
  (
    select count(*)
    from private.outbox_consumer_receipts
    where outbox_event_id = 'c7000000-0000-4000-8000-000000000007'
  ),
  3::bigint,
  'notifications.v1, push.v1, and a future consumer can receipt one source event'
);

delete from private.outbox_consumer_receipts
where outbox_event_id = 'c1000000-0000-4000-8000-000000000001'
  and consumer_key = 'push.v1';

set local role service_role;
select results_eq(
  $$
    select processed_count, jobs_created, jobs_suppressed
    from public.process_push_outbox_batch(100)
  $$,
  $$values (1, 0, 0)$$,
  'a lost success response can retry without duplicating a push job'
);
select results_eq(
  $$
    select processed_count, jobs_created, jobs_suppressed
    from public.process_push_outbox_batch(100)
  $$,
  $$values (0, 0, 0)$$,
  'a fully receipted push batch is idempotently empty'
);

reset role;
select is(
  (
    select count(*)
    from private.push_delivery_jobs
    where source_outbox_event_id = 'c1000000-0000-4000-8000-000000000001'
  ),
  1::bigint,
  'database uniqueness keeps a retried recipient-level job singular'
);

insert into private.outbox_events (id, event_type, payload, created_at, available_at)
values (
  'ce000000-0000-4000-8000-00000000000e',
  'project.join_requested',
  jsonb_build_object(
    'project_id', 'f1000000-0000-4000-8000-000000000001',
    'project_kind', 'one_time',
    'actor_profile_id', 'd3000000-0000-4000-8000-000000000003',
    'request_id', 'ae000000-0000-4000-8000-00000000000e',
    'requester_profile_id', 'd3000000-0000-4000-8000-000000000003'
  ),
  statement_timestamp() - interval '5 minutes',
  statement_timestamp() - interval '5 minutes'
);

set local role service_role;
select throws_ok(
  'select * from public.process_push_outbox_batch(100)',
  '55000',
  'Notification projection could not validate outbox event ce000000-0000-4000-8000-00000000000e against its canonical join request.',
  'invalid semantic source state fails visibly instead of guessing a recipient'
);

reset role;
select ok(
  not exists (
    select 1
    from private.outbox_consumer_receipts
    where outbox_event_id = 'ce000000-0000-4000-8000-00000000000e'
      and consumer_key = 'push.v1'
  )
    and not exists (
      select 1
      from private.push_delivery_jobs
      where source_outbox_event_id = 'ce000000-0000-4000-8000-00000000000e'
    ),
  'failed push resolution creates neither a success receipt nor a job'
);

select * from finish();

rollback;
