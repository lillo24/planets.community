begin;

select no_plan();

insert into auth.users (id, email)
values
  ('e1000000-0000-4000-8000-000000000001', 'protocol-recipient@planets.invalid'),
  ('e2000000-0000-4000-8000-000000000002', 'protocol-other@planets.invalid'),
  ('e3000000-0000-4000-8000-000000000003', 'protocol-retry@planets.invalid');

insert into public.profiles (id, display_name)
values
  ('e1000000-0000-4000-8000-000000000001', 'Protocol Recipient'),
  ('e2000000-0000-4000-8000-000000000002', 'Protocol Other'),
  ('e3000000-0000-4000-8000-000000000003', 'Protocol Retry');

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'e1000000-0000-4000-8000-000000000001',
  true
);
select lives_ok(
  $$
    select *
    from public.register_own_push_installation(
      'e1000000-0000-4000-8000-000000000001',
      'a1000000-0000-4000-8000-000000000001',
      'android',
      'protocol-token-a1'
    )
  $$,
  'the first token registration succeeds'
);
select lives_ok(
  $$
    select *
    from public.register_own_push_installation(
      'e1000000-0000-4000-8000-000000000001',
      'a1000000-0000-4000-8000-000000000001',
      'android',
      'protocol-token-a1'
    )
  $$,
  'same-token registration remains idempotent'
);

reset role;
select is(
  (
    select token_version
    from private.push_installations
    where installation_id = 'a1000000-0000-4000-8000-000000000001'
  ),
  1::bigint,
  'same-token registration keeps the token version stable'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'e1000000-0000-4000-8000-000000000001',
  true
);
select lives_ok(
  $$
    select *
    from public.register_own_push_installation(
      'e1000000-0000-4000-8000-000000000001',
      'a1000000-0000-4000-8000-000000000001',
      'android',
      'protocol-token-a2'
    )
  $$,
  'token rotation succeeds'
);

reset role;
select is(
  (
    select token_version
    from private.push_installations
    where installation_id = 'a1000000-0000-4000-8000-000000000001'
  ),
  2::bigint,
  'changing provider token advances the token version once'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'e1000000-0000-4000-8000-000000000001',
  true
);
select is(
  public.unregister_own_push_installation(
    'e1000000-0000-4000-8000-000000000001',
    'a1000000-0000-4000-8000-000000000001'
  ),
  true,
  'unregister clears active token state'
);
select lives_ok(
  $$
    select *
    from public.register_own_push_installation(
      'e1000000-0000-4000-8000-000000000001',
      'a1000000-0000-4000-8000-000000000001',
      'android',
      'protocol-token-a2'
    )
  $$,
  'a disabled installation can reactivate with a provider token'
);

reset role;
select is(
  (
    select token_version
    from private.push_installations
    where installation_id = 'a1000000-0000-4000-8000-000000000001'
  ),
  4::bigint,
  'token removal and reactivation each advance the monotonic generation'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'e2000000-0000-4000-8000-000000000002',
  true
);
select lives_ok(
  $$
    select *
    from public.register_own_push_installation(
      'e2000000-0000-4000-8000-000000000002',
      'a1000000-0000-4000-8000-000000000001',
      'android',
      'protocol-token-a2'
    )
  $$,
  'the same installation and token can transfer to a new account'
);

reset role;
select is(
  (
    select token_version
    from private.push_installations
    where installation_id = 'a1000000-0000-4000-8000-000000000001'
  ),
  4::bigint,
  'same-token account transfer does not create a false token generation'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'e1000000-0000-4000-8000-000000000001',
  true
);
select lives_ok(
  $$
    select *
    from public.register_own_push_installation(
      'e1000000-0000-4000-8000-000000000001',
      'a1000000-0000-4000-8000-000000000001',
      'android',
      'protocol-token-a2'
    )
  $$,
  'the test installation transfers back to its delivery recipient'
);
select lives_ok(
  $$
    select *
    from public.register_own_push_installation(
      'e1000000-0000-4000-8000-000000000001',
      'a2000000-0000-4000-8000-000000000002',
      'ios',
      'protocol-token-b1'
    )
  $$,
  'the recipient can register a second installation'
);

reset role;
insert into private.outbox_events (id, event_type, payload, created_at, available_at)
values
  (
    'b1000000-0000-4000-8000-000000000001',
    'push.protocol.synthetic',
    '{}'::jsonb,
    statement_timestamp() - interval '2 minutes',
    statement_timestamp() - interval '2 minutes'
  ),
  (
    'b2000000-0000-4000-8000-000000000002',
    'push.protocol.synthetic',
    '{}'::jsonb,
    statement_timestamp() - interval '1 minute',
    statement_timestamp() - interval '1 minute'
  );

insert into private.push_delivery_jobs (
  id,
  source_outbox_event_id,
  recipient_profile_id,
  category_slug,
  notification_kind,
  destination_kind,
  created_at,
  available_at
)
values
  (
    'c1000000-0000-4000-8000-000000000001',
    'b1000000-0000-4000-8000-000000000001',
    'e1000000-0000-4000-8000-000000000001',
    'matching',
    'matching_available',
    'matching_result',
    statement_timestamp() - interval '2 minutes',
    statement_timestamp()
  ),
  (
    'c2000000-0000-4000-8000-000000000002',
    'b2000000-0000-4000-8000-000000000002',
    'e2000000-0000-4000-8000-000000000002',
    'matching',
    'matching_available',
    'matching_result',
    statement_timestamp() - interval '1 minute',
    statement_timestamp()
  );

set local role service_role;
select throws_ok(
  'select * from private.prepare_push_delivery_jobs(0)',
  '22023',
  'Push delivery preparation batch size must be between 1 and 100.',
  'fan-out rejects an unbounded empty batch'
);
select throws_ok(
  $$select * from private.claim_push_delivery_targets('', 1, 60)$$,
  '22023',
  'Push delivery worker ID must contain 1 to 128 trimmed characters.',
  'claim requires a bounded non-empty worker identity'
);
select throws_ok(
  $$select * from private.claim_push_delivery_targets('worker-a', 101, 60)$$,
  '22023',
  'Push delivery claim batch size must be between 1 and 100.',
  'claim rejects an oversized batch'
);
select throws_ok(
  $$select * from private.claim_push_delivery_targets('worker-a', 1, 0)$$,
  '22023',
  'Push delivery lease must be between 1 and 3600 seconds.',
  'claim rejects a non-positive lease'
);
select results_eq(
  $$
    select jobs_prepared, targets_created, jobs_without_targets
    from private.prepare_push_delivery_jobs(100)
  $$,
  $$values (2, 2, 1)$$,
  'fan-out prepares two jobs, snapshots two installations, and completes the zero-target job'
);
select results_eq(
  $$
    select jobs_prepared, targets_created, jobs_without_targets
    from private.prepare_push_delivery_jobs(100)
  $$,
  $$values (0, 0, 0)$$,
  'repeated fan-out is idempotently empty'
);

reset role;
select is(
  (
    select count(*)
    from private.push_delivery_targets
    where job_id = 'c1000000-0000-4000-8000-000000000001'
  ),
  2::bigint,
  'one target was snapshotted for each active installation'
);
select ok(
  (
    select fanout_at is not null
      and completed_at is null
      and completion_reason is null
    from private.push_delivery_jobs
    where id = 'c1000000-0000-4000-8000-000000000001'
  ),
  'a prepared job with pending targets remains incomplete'
);
select ok(
  (
    select fanout_at is not null
      and completed_at is not null
      and completion_reason = 'no_targets'
    from private.push_delivery_jobs
    where id = 'c2000000-0000-4000-8000-000000000002'
  ),
  'a zero-target job completes explicitly without inventing a send'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'e1000000-0000-4000-8000-000000000001',
  true
);
select lives_ok(
  $$
    select *
    from public.register_own_push_installation(
      'e1000000-0000-4000-8000-000000000001',
      'a3000000-0000-4000-8000-000000000003',
      'android',
      'protocol-token-c1'
    )
  $$,
  'a later installation can register normally'
);

reset role;
select is(
  (
    select count(*)
    from private.push_delivery_targets
    where job_id = 'c1000000-0000-4000-8000-000000000001'
  ),
  2::bigint,
  'an installation registered after fan-out does not receive the historical job'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'e2000000-0000-4000-8000-000000000002',
  true
);
select lives_ok(
  $$
    select *
    from public.register_own_push_installation(
      'e2000000-0000-4000-8000-000000000002',
      'a2000000-0000-4000-8000-000000000002',
      'ios',
      'protocol-token-b1'
    )
  $$,
  'a snapshotted installation can transfer before claim'
);

reset role;
create temporary table claimed_primary as
select *
from private.claim_push_delivery_targets('worker-a', 100, 60)
with no data;
grant all privileges on table claimed_primary to service_role;

set local role service_role;
insert into claimed_primary
select * from private.claim_push_delivery_targets('worker-a', 100, 60);
select is(
  (select count(*) from claimed_primary),
  1::bigint,
  'claim returns only the still-owned installation and its trusted token'
);
select ok(
  (
    select provider_token = 'protocol-token-a2'
      and token_version = 4
      and lease_id is not null
      and attempt_number = 1
    from claimed_primary
  ),
  'claim returns current token generation with a new bounded lease and attempt'
);
select is(
  (
    select count(*)
    from private.claim_push_delivery_targets('worker-b', 100, 60)
  ),
  0::bigint,
  'another worker cannot claim an actively leased target'
);
select is(
  (
    select private.record_push_delivery_result(
      target_id,
      lease_id,
      token_version,
      'delivered',
      'provider-message-primary'
    )
    from claimed_primary
  ),
  'delivered',
  'the current lease can record a delivered terminal result'
);
select throws_ok(
  $$
    select private.record_push_delivery_result(
      target_id,
      lease_id,
      token_version,
      'delivered'
    )
    from claimed_primary
  $$,
  '55000',
  'Push delivery lease is unavailable, expired, or superseded.',
  'a completed lease cannot replay its result'
);

reset role;
select is(
  (
    select count(*)
    from private.push_delivery_targets
    where job_id = 'c1000000-0000-4000-8000-000000000001'
      and status = 'no_longer_registered'
      and lease_id is null
  ),
  1::bigint,
  'account transfer before claim becomes terminal without exposing a token'
);
select is(
  (
    select count(*)
    from private.push_delivery_attempts as attempt
    join private.push_delivery_targets as target
      on target.id = attempt.target_id
    where target.job_id = 'c1000000-0000-4000-8000-000000000001'
  ),
  1::bigint,
  'no provider attempt is fabricated for the transferred installation'
);
select ok(
  (
    select completed_at is not null
      and completion_reason = 'delivered_or_terminal'
    from private.push_delivery_jobs
    where id = 'c1000000-0000-4000-8000-000000000001'
  ),
  'mixed delivered and no-longer-registered targets complete their job'
);

insert into private.push_installations (
  installation_id,
  profile_id,
  platform,
  provider,
  provider_token
)
values (
  'a4000000-0000-4000-8000-000000000004',
  'e3000000-0000-4000-8000-000000000003',
  'android',
  'fcm',
  'protocol-token-d1'
);
insert into private.outbox_events (id, event_type, payload, created_at, available_at)
values (
  'b3000000-0000-4000-8000-000000000003',
  'push.protocol.synthetic',
  '{}'::jsonb,
  statement_timestamp() - interval '1 minute',
  statement_timestamp() - interval '1 minute'
);
insert into private.push_delivery_jobs (
  id,
  source_outbox_event_id,
  recipient_profile_id,
  category_slug,
  notification_kind,
  destination_kind,
  created_at,
  available_at
)
values (
  'c3000000-0000-4000-8000-000000000003',
  'b3000000-0000-4000-8000-000000000003',
  'e3000000-0000-4000-8000-000000000003',
  'matching',
  'matching_available',
  'matching_result',
  statement_timestamp() - interval '1 minute',
  statement_timestamp()
);
insert into private.outbox_consumer_receipts (
  outbox_event_id,
  consumer_key,
  processed_at
)
values (
  'b3000000-0000-4000-8000-000000000003',
  'push.v1',
  statement_timestamp()
);

set local role service_role;
select results_eq(
  $$
    select jobs_prepared, targets_created, jobs_without_targets
    from private.prepare_push_delivery_jobs(100)
  $$,
  $$values (1, 1, 0)$$,
  'a retry scenario fans out to one active installation'
);

reset role;
create temporary table crashed_claim as
select *
from private.claim_push_delivery_targets('worker-crashed', 1, 60)
with no data;
grant all privileges on table crashed_claim to service_role;
set local role service_role;
insert into crashed_claim
select * from private.claim_push_delivery_targets('worker-crashed', 1, 60);

reset role;
update private.push_delivery_targets
set
  updated_at = created_at,
  lease_expires_at = created_at + interval '1 microsecond'
where id = (select target_id from crashed_claim);
select ok(
  (
    select lease_expires_at <= statement_timestamp()
    from private.push_delivery_targets
    where id = (select target_id from crashed_claim)
  ),
  'the test deterministically simulates an expired worker lease'
);

set local role service_role;
select throws_ok(
  $$
    select private.record_push_delivery_result(
      target_id,
      lease_id,
      token_version,
      'delivered'
    )
    from crashed_claim
  $$,
  '55000',
  'Push delivery lease is unavailable, expired, or superseded.',
  'an expired lease result is rejected even before reclaim'
);

reset role;
create temporary table reclaimed_claim as
select *
from private.claim_push_delivery_targets('worker-retry', 1, 60)
with no data;
grant all privileges on table reclaimed_claim to service_role;
set local role service_role;
insert into reclaimed_claim
select * from private.claim_push_delivery_targets('worker-retry', 1, 60);
select ok(
  (
    select reclaimed.attempt_number = 2
      and reclaimed.lease_id <> crashed.lease_id
    from reclaimed_claim as reclaimed
    cross join crashed_claim as crashed
  ),
  'expired work is reclaimed under a new lease and attempt number'
);
select throws_ok(
  $$
    select private.record_push_delivery_result(
      target_id,
      lease_id,
      token_version,
      'delivered'
    )
    from crashed_claim
  $$,
  '55000',
  'Push delivery lease is unavailable, expired, or superseded.',
  'a stale response cannot overwrite a reclaimed target'
);
select is(
  (
    select private.record_push_delivery_result(
      target_id,
      lease_id,
      token_version,
      'transient_failure',
      null,
      'UNAVAILABLE',
      60
    )
    from reclaimed_claim
  ),
  'transient_failure',
  'a transient failure records safe metadata and schedules a bounded retry'
);
select is(
  (
    select count(*)
    from private.claim_push_delivery_targets('worker-too-early', 1, 60)
  ),
  0::bigint,
  'a transient target cannot be reclaimed before its retry time'
);

reset role;
select ok(
  (
    select status = 'pending'
      and available_at > statement_timestamp()
      and lease_id is null
    from private.push_delivery_targets
    where id = (select target_id from reclaimed_claim)
  ),
  'transient failure returns the target to an unleased future schedule'
);
update private.push_delivery_targets
set available_at = statement_timestamp() - interval '1 second'
where id = (select target_id from reclaimed_claim);

create temporary table retry_claim as
select *
from private.claim_push_delivery_targets('worker-final', 1, 60)
with no data;
grant all privileges on table retry_claim to service_role;
set local role service_role;
insert into retry_claim
select * from private.claim_push_delivery_targets('worker-final', 1, 60);
select is(
  (select attempt_number from retry_claim),
  3,
  'the due transient retry creates the next append-only attempt'
);
select is(
  (
    select private.record_push_delivery_result(
      target_id,
      lease_id,
      token_version,
      'delivered',
      'provider-message-retry'
    )
    from retry_claim
  ),
  'delivered',
  'the current retry lease can finish delivery'
);

reset role;
select ok(
  (
    select completed_at is not null
      and completion_reason = 'delivered_or_terminal'
    from private.push_delivery_jobs
    where id = 'c3000000-0000-4000-8000-000000000003'
  ),
  'a retried target completes its aggregate job'
);
select is(
  (
    select count(*)
    from private.push_delivery_attempts
    where target_id = (select target_id from retry_claim)
  ),
  3::bigint,
  'crashed, transient, and delivered attempts remain observable'
);
select ok(
  (
    select count(*) filter (
      where finished_at is null and outcome is null
    ) = 1
      and count(*) filter (
        where outcome = 'transient_failure'
          and provider_error_code = 'UNAVAILABLE'
          and retry_available_at is not null
      ) = 1
      and count(*) filter (where outcome = 'delivered') = 1
    from private.push_delivery_attempts
    where target_id = (select target_id from retry_claim)
  ),
  'attempt history distinguishes crash, retry, and terminal delivery safely'
);
select is(
  (
    select count(*)
    from private.outbox_consumer_receipts
    where outbox_event_id = 'b3000000-0000-4000-8000-000000000003'
      and consumer_key = 'push.v1'
  ),
  1::bigint,
  'delivery outcomes never rewrite the push.v1 projection receipt'
);

insert into private.outbox_events (id, event_type, payload, created_at, available_at)
values (
  'b4000000-0000-4000-8000-000000000004',
  'push.protocol.synthetic',
  '{}'::jsonb,
  statement_timestamp() - interval '1 minute',
  statement_timestamp() - interval '1 minute'
);
insert into private.push_delivery_jobs (
  id,
  source_outbox_event_id,
  recipient_profile_id,
  category_slug,
  notification_kind,
  destination_kind,
  created_at,
  available_at
)
values (
  'c4000000-0000-4000-8000-000000000004',
  'b4000000-0000-4000-8000-000000000004',
  'e3000000-0000-4000-8000-000000000003',
  'matching',
  'matching_available',
  'matching_result',
  statement_timestamp() - interval '1 minute',
  statement_timestamp()
);

set local role service_role;
select * from private.prepare_push_delivery_jobs(1);

reset role;
create temporary table stale_token_claim as
select *
from private.claim_push_delivery_targets('worker-stale-token', 1, 60)
with no data;
grant all privileges on table stale_token_claim to service_role;
set local role service_role;
insert into stale_token_claim
select * from private.claim_push_delivery_targets('worker-stale-token', 1, 60);

reset role;
select is(
  (select token_version from stale_token_claim),
  1::bigint,
  'the invalid-token race starts from the original generation'
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'e3000000-0000-4000-8000-000000000003',
  true
);
select lives_ok(
  $$
    select *
    from public.register_own_push_installation(
      'e3000000-0000-4000-8000-000000000003',
      'a4000000-0000-4000-8000-000000000004',
      'android',
      'protocol-token-d2'
    )
  $$,
  'the installation rotates while an old-token attempt is in flight'
);

reset role;
set local role service_role;
select is(
  (
    select private.record_push_delivery_result(
      target_id,
      lease_id,
      token_version,
      'invalid_token',
      null,
      'UNREGISTERED'
    )
    from stale_token_claim
  ),
  'invalid_token',
  'the claimed old-token attempt records its terminal provider outcome'
);

reset role;
select ok(
  (
    select provider_token = 'protocol-token-d2'
      and token_version = 2
      and disabled_at is null
    from private.push_installations
    where installation_id = 'a4000000-0000-4000-8000-000000000004'
  ),
  'a stale invalid-token result cannot clear the rotated current token'
);

insert into private.outbox_events (id, event_type, payload, created_at, available_at)
values (
  'b5000000-0000-4000-8000-000000000005',
  'push.protocol.synthetic',
  '{}'::jsonb,
  statement_timestamp() - interval '1 minute',
  statement_timestamp() - interval '1 minute'
);
insert into private.push_delivery_jobs (
  id,
  source_outbox_event_id,
  recipient_profile_id,
  category_slug,
  notification_kind,
  destination_kind,
  created_at,
  available_at
)
values (
  'c5000000-0000-4000-8000-000000000005',
  'b5000000-0000-4000-8000-000000000005',
  'e3000000-0000-4000-8000-000000000003',
  'matching',
  'matching_available',
  'matching_result',
  statement_timestamp() - interval '1 minute',
  statement_timestamp()
);

set local role service_role;
select * from private.prepare_push_delivery_jobs(1);

reset role;
create temporary table invalid_claim as
select *
from private.claim_push_delivery_targets('worker-invalid', 1, 60)
with no data;
grant all privileges on table invalid_claim to service_role;
set local role service_role;
insert into invalid_claim
select * from private.claim_push_delivery_targets('worker-invalid', 1, 60);
select is(
  (
    select private.record_push_delivery_result(
      target_id,
      lease_id,
      token_version,
      'invalid_token',
      null,
      'UNREGISTERED'
    )
    from invalid_claim
  ),
  'invalid_token',
  'a current invalid-token result becomes terminal'
);

reset role;
select ok(
  (
    select provider_token is null
      and disabled_at is not null
      and token_version = 3
    from private.push_installations
    where installation_id = 'a4000000-0000-4000-8000-000000000004'
  ),
  'current-generation invalid-token cleanup disables and advances the installation'
);
select ok(
  (
    select completed_at is not null
      and completion_reason = 'delivered_or_terminal'
    from private.push_delivery_jobs
    where id = 'c5000000-0000-4000-8000-000000000005'
  ),
  'a current invalid-token target completes its aggregate job'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'e3000000-0000-4000-8000-000000000003',
  true
);
select lives_ok(
  $$
    select *
    from public.register_own_push_installation(
      'e3000000-0000-4000-8000-000000000003',
      'a4000000-0000-4000-8000-000000000004',
      'android',
      'protocol-token-d3'
    )
  $$,
  'the test installation can reactivate after invalid-token cleanup'
);

reset role;
insert into private.outbox_events (id, event_type, payload, created_at, available_at)
values (
  'b6000000-0000-4000-8000-000000000006',
  'push.protocol.synthetic',
  '{}'::jsonb,
  statement_timestamp() - interval '1 minute',
  statement_timestamp() - interval '1 minute'
);
insert into private.push_delivery_jobs (
  id,
  source_outbox_event_id,
  recipient_profile_id,
  category_slug,
  notification_kind,
  destination_kind,
  created_at,
  available_at
)
values (
  'c6000000-0000-4000-8000-000000000006',
  'b6000000-0000-4000-8000-000000000006',
  'e3000000-0000-4000-8000-000000000003',
  'matching',
  'matching_available',
  'matching_result',
  statement_timestamp() - interval '1 minute',
  statement_timestamp()
);

set local role service_role;
select * from private.prepare_push_delivery_jobs(1);

reset role;
create temporary table permanent_claim as
select *
from private.claim_push_delivery_targets('worker-permanent', 1, 60)
with no data;
grant all privileges on table permanent_claim to service_role;
set local role service_role;
insert into permanent_claim
select * from private.claim_push_delivery_targets('worker-permanent', 1, 60);
select throws_ok(
  $$
    select private.record_push_delivery_result(
      target_id,
      lease_id,
      token_version + 1,
      'permanent_failure',
      null,
      'INVALID_ARGUMENT'
    )
    from permanent_claim
  $$,
  '55000',
  'Push delivery attempt is unavailable or uses a stale token version.',
  'result recording rejects a token version not returned by the claim'
);
select throws_ok(
  $$
    select private.record_push_delivery_result(
      target_id,
      lease_id,
      token_version,
      'permanent_failure',
      null,
      repeat('x', 129)
    )
    from permanent_claim
  $$,
  '22023',
  'Provider error code must contain 1 to 128 trimmed characters.',
  'provider metadata is bounded before it reaches attempt history'
);
select is(
  (
    select private.record_push_delivery_result(
      target_id,
      lease_id,
      token_version,
      'permanent_failure',
      null,
      'INVALID_ARGUMENT'
    )
    from permanent_claim
  ),
  'permanent_failure',
  'a permanent provider failure terminates the target'
);

reset role;
select ok(
  (
    select target.status = 'permanent_failure'
      and target.completed_at is not null
      and job.completion_reason = 'delivered_or_terminal'
      and installation.provider_token = 'protocol-token-d3'
      and installation.disabled_at is null
    from private.push_delivery_targets as target
    join private.push_delivery_jobs as job
      on job.id = target.job_id
    join private.push_installations as installation
      on installation.installation_id = target.installation_id
    where target.id = (select target_id from permanent_claim)
  ),
  'permanent failure completes history without disabling a valid installation'
);
select ok(
  not exists (
    select 1
    from information_schema.columns
    where table_schema = 'private'
      and table_name = 'push_delivery_attempts'
      and column_name = 'provider_token'
  )
    and not exists (
      select 1
      from private.push_delivery_attempts
      where to_jsonb(push_delivery_attempts)::text like '%protocol-token-%'
    ),
  'attempt history never persists raw provider tokens'
);

select * from finish();

rollback;
