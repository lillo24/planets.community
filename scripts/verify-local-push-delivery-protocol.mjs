import { randomUUID } from "node:crypto";

import postgres from "postgres";

import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";

const repositoryRoot = process.cwd();
const { databaseUrl } = readLocalSupabaseStatus(repositoryRoot);

if (!databaseUrl) {
  throw new Error(
    "Local Supabase status is missing its database URL. Update the project-scoped CLI if the status format has changed.",
  );
}

const sql = postgres(databaseUrl, { max: 6 });

try {
  await verifyPushDeliveryProtocol();
} catch (error) {
  if (error instanceof ProtocolVerificationError) {
    throw error;
  }
  throw safeDatabaseFailure("verify the local push delivery protocol", error);
} finally {
  await sql.end();
}

async function verifyPushDeliveryProtocol() {
  const [initialState] = await sql`
    select count(*)::integer as count
    from private.push_delivery_jobs
    where fanout_at is null
  `;
  if (initialState.count !== 0) {
    throw new ProtocolVerificationError(
      "Push delivery verification requires a freshly reset local database with no unprepared delivery jobs.",
    );
  }

  const fixture = createFixtureIds();
  const tokenOne = `synthetic-protocol-${randomUUID()}`;
  const tokenTwo = `synthetic-protocol-${randomUUID()}`;
  const tokenRotated = `synthetic-protocol-${randomUUID()}`;
  const transferToken = `synthetic-protocol-${randomUUID()}`;

  await createBaseFixture(fixture, {
    tokenOne,
    tokenTwo,
    transferToken,
  });

  const preparationResults = await Promise.all([
    prepareJobs(100),
    prepareJobs(100),
  ]);
  const preparationTotals = sumPreparationResults(preparationResults);
  assert(
    preparationTotals.jobsPrepared === 3 &&
      preparationTotals.targetsCreated === 3 &&
      preparationTotals.jobsWithoutTargets === 1,
    "Concurrent preparation did not fan out each job exactly once.",
  );

  const repeatedPreparation = await prepareJobs(100);
  assert(
    repeatedPreparation.jobs_prepared === 0 &&
      repeatedPreparation.targets_created === 0 &&
      repeatedPreparation.jobs_without_targets === 0,
    "Repeated preparation was not idempotently empty.",
  );

  const primaryTargets = await sql`
    select installation_id
    from private.push_delivery_targets
    where job_id = ${fixture.primaryJobId}
    order by installation_id
  `;
  assert(
    primaryTargets.length === 2,
    "The primary job did not snapshot both active installations.",
  );

  await sql`
    insert into private.push_installations (
      installation_id,
      profile_id,
      platform,
      provider,
      provider_token
    )
    values (
      ${fixture.lateInstallationId},
      ${fixture.recipientProfileId},
      'android',
      'fcm',
      ${`synthetic-protocol-${randomUUID()}`}
    )
  `;
  const [unchangedSnapshot] = await sql`
    select count(*)::integer as count
    from private.push_delivery_targets
    where job_id = ${fixture.primaryJobId}
  `;
  assert(
    unchangedSnapshot.count === 2,
    "A later installation was added to an already prepared historical job.",
  );

  await sql`
    update private.push_installations
    set
      profile_id = ${fixture.otherProfileId},
      updated_at = statement_timestamp(),
      last_registered_at = statement_timestamp()
    where installation_id = ${fixture.transferInstallationId}
  `;

  const [claimA, claimB] = await Promise.all([
    claimTargets("fake-worker-a", 1, 60),
    claimTargets("fake-worker-b", 1, 60),
  ]);
  assert(
    claimA.length === 1 &&
      claimB.length === 1 &&
      claimA[0].target_id !== claimB[0].target_id,
    "Concurrent workers did not receive distinct target leases.",
  );
  assertTrustedClaim(claimA[0], [tokenOne, tokenTwo]);
  assertTrustedClaim(claimB[0], [tokenOne, tokenTwo]);

  await recordResult(claimA[0], "delivered", {
    providerMessageId: "fake-delivery-primary",
  });
  await recordResult(claimB[0], "transient_failure", {
    providerErrorCode: "FAKE_UNAVAILABLE",
    retryAfterSeconds: 60,
  });

  const [scheduledRetry] = await sql`
    select status, available_at > statement_timestamp() as scheduled, lease_id
    from private.push_delivery_targets
    where id = ${claimB[0].target_id}
  `;
  assert(
    scheduledRetry.status === "pending" &&
      scheduledRetry.scheduled === true &&
      scheduledRetry.lease_id === null,
    "Transient failure did not produce an unleased future retry.",
  );
  assert(
    (await claimTargets("fake-worker-too-early", 1, 60)).length === 0,
    "A worker claimed the target before its retry schedule.",
  );

  await sql`
    update private.push_delivery_targets
    set available_at = created_at
    where id = ${claimB[0].target_id}
  `;
  const retryClaim = await claimTargets("fake-worker-retry", 1, 60);
  assert(
    retryClaim.length === 1 &&
      retryClaim[0].target_id === claimB[0].target_id &&
      retryClaim[0].lease_id !== claimB[0].lease_id &&
      retryClaim[0].attempt_number === 2,
    "The due retry did not receive a new lease and attempt.",
  );

  await assertLeaseRejected(claimB[0]);
  await recordResult(retryClaim[0], "delivered", {
    providerMessageId: "fake-delivery-retry",
  });

  const [completedPrimary] = await sql`
    select completion_reason, completed_at is not null as completed
    from private.push_delivery_jobs
    where id = ${fixture.primaryJobId}
  `;
  assert(
    completedPrimary.completed === true &&
      completedPrimary.completion_reason === "delivered_or_terminal",
    "Delivered and retried targets did not complete their aggregate job.",
  );

  const [attemptHistory] = await sql`
    select
      count(*)::integer as count,
      count(*) filter (where outcome = 'transient_failure')::integer
        as transient_count,
      count(*) filter (where outcome = 'delivered')::integer
        as delivered_count,
      bool_and(
        not (to_jsonb(attempt) ? 'provider_token')
        and to_jsonb(attempt)::text not like ${`%${tokenOne}%`}
        and to_jsonb(attempt)::text not like ${`%${tokenTwo}%`}
      ) as safe
    from private.push_delivery_attempts as attempt
    join private.push_delivery_targets as target
      on target.id = attempt.target_id
    where target.job_id = ${fixture.primaryJobId}
  `;
  assert(
    attemptHistory.count === 3 &&
      attemptHistory.transient_count === 1 &&
      attemptHistory.delivered_count === 2 &&
      attemptHistory.safe === true,
    "Attempt history was incomplete or retained private token material.",
  );

  await createRotationJob(fixture);
  const rotationPreparation = await prepareJobs(1);
  assert(
    rotationPreparation.jobs_prepared === 1 &&
      rotationPreparation.targets_created === 1 &&
      rotationPreparation.jobs_without_targets === 0,
    "The token-rotation job did not prepare exactly one target.",
  );
  const staleTokenClaim = await claimTargets("fake-worker-stale-token", 1, 60);
  assert(
    staleTokenClaim.length === 1 &&
      staleTokenClaim[0].job_id === fixture.rotationJobId,
    "The token-rotation scenario could not claim its target.",
  );
  await sql`
    update private.push_installations
    set
      provider_token = ${tokenRotated},
      token_version = token_version + 1,
      updated_at = statement_timestamp(),
      last_registered_at = statement_timestamp()
    where installation_id = ${staleTokenClaim[0].installation_id}
  `;
  await recordResult(staleTokenClaim[0], "invalid_token", {
    providerErrorCode: "FAKE_UNREGISTERED",
  });
  const [rotatedInstallation] = await sql`
    select provider_token, token_version, disabled_at
    from private.push_installations
    where installation_id = ${staleTokenClaim[0].installation_id}
  `;
  assert(
    rotatedInstallation.provider_token === tokenRotated &&
      Number(rotatedInstallation.token_version) ===
        Number(staleTokenClaim[0].token_version) + 1 &&
      rotatedInstallation.disabled_at === null,
    "A stale invalid-token response disabled the rotated current token.",
  );

  const transferClaim = await claimTargets(
    "fake-worker-transfer-check",
    10,
    60,
  );
  assert(
    transferClaim.every((claim) => claim.job_id !== fixture.transferJobId),
    "A transferred installation exposed a provider token for its old recipient.",
  );
  const [transferredTarget] = await sql`
    select status, lease_id
    from private.push_delivery_targets
    where job_id = ${fixture.transferJobId}
  `;
  assert(
    transferredTarget.status === "no_longer_registered" &&
      transferredTarget.lease_id === null,
    "Transfer before claim did not terminate the stale target safely.",
  );

  const [zeroTargetJob] = await sql`
    select completion_reason, completed_at is not null as completed
    from private.push_delivery_jobs
    where id = ${fixture.zeroTargetJobId}
  `;
  assert(
    zeroTargetJob.completed === true &&
      zeroTargetJob.completion_reason === "no_targets",
    "A recipient without installations did not complete as no_targets.",
  );

  console.log(
    "Confirmed one-time fan-out, distinct concurrent leases, fake delivered/transient outcomes, scheduled retry, stale-lease rejection, append-only safe attempts, token-rotation protection, transfer-before-claim handling, and no-target completion.",
  );
}

function createFixtureIds() {
  return {
    recipientProfileId: randomUUID(),
    otherProfileId: randomUUID(),
    transferProfileId: randomUUID(),
    rotationProfileId: randomUUID(),
    zeroTargetProfileId: randomUUID(),
    installationOneId: randomUUID(),
    installationTwoId: randomUUID(),
    lateInstallationId: randomUUID(),
    transferInstallationId: randomUUID(),
    rotationInstallationId: randomUUID(),
    primaryEventId: randomUUID(),
    rotationEventId: randomUUID(),
    transferEventId: randomUUID(),
    zeroTargetEventId: randomUUID(),
    primaryJobId: randomUUID(),
    rotationJobId: randomUUID(),
    transferJobId: randomUUID(),
    zeroTargetJobId: randomUUID(),
  };
}

async function createBaseFixture(fixture, tokens) {
  await sql`
    insert into auth.users (id, email)
    values
      (
        ${fixture.recipientProfileId},
        ${`push-protocol-${fixture.recipientProfileId}@planets.invalid`}
      ),
      (
        ${fixture.otherProfileId},
        ${`push-protocol-${fixture.otherProfileId}@planets.invalid`}
      ),
      (
        ${fixture.transferProfileId},
        ${`push-protocol-${fixture.transferProfileId}@planets.invalid`}
      ),
      (
        ${fixture.rotationProfileId},
        ${`push-protocol-${fixture.rotationProfileId}@planets.invalid`}
      ),
      (
        ${fixture.zeroTargetProfileId},
        ${`push-protocol-${fixture.zeroTargetProfileId}@planets.invalid`}
      )
  `;
  await sql`
    insert into public.profiles (id, display_name)
    values
      (${fixture.recipientProfileId}, 'Protocol Recipient'),
      (${fixture.otherProfileId}, 'Protocol Other'),
      (${fixture.transferProfileId}, 'Protocol Transfer'),
      (${fixture.rotationProfileId}, 'Protocol Rotation'),
      (${fixture.zeroTargetProfileId}, 'Protocol No Target')
  `;
  await sql`
    insert into private.push_installations (
      installation_id,
      profile_id,
      platform,
      provider,
      provider_token
    )
    values
      (
        ${fixture.installationOneId},
        ${fixture.recipientProfileId},
        'android',
        'fcm',
        ${tokens.tokenOne}
      ),
      (
        ${fixture.installationTwoId},
        ${fixture.recipientProfileId},
        'ios',
        'fcm',
        ${tokens.tokenTwo}
      ),
      (
        ${fixture.transferInstallationId},
        ${fixture.transferProfileId},
        'android',
        'fcm',
        ${tokens.transferToken}
      ),
      (
        ${fixture.rotationInstallationId},
        ${fixture.rotationProfileId},
        'android',
        'fcm',
        ${`synthetic-protocol-${randomUUID()}`}
      )
  `;
  await sql`
    insert into private.outbox_events (
      id,
      event_type,
      payload,
      created_at,
      available_at
    )
    values
      (
        ${fixture.primaryEventId},
        'push.protocol.synthetic',
        '{}'::jsonb,
        statement_timestamp() - interval '4 minutes',
        statement_timestamp() - interval '4 minutes'
      ),
      (
        ${fixture.rotationEventId},
        'push.protocol.synthetic',
        '{}'::jsonb,
        statement_timestamp() - interval '3 minutes',
        statement_timestamp() - interval '3 minutes'
      ),
      (
        ${fixture.transferEventId},
        'push.protocol.synthetic',
        '{}'::jsonb,
        statement_timestamp() - interval '2 minutes',
        statement_timestamp() - interval '2 minutes'
      ),
      (
        ${fixture.zeroTargetEventId},
        'push.protocol.synthetic',
        '{}'::jsonb,
        statement_timestamp() - interval '1 minute',
        statement_timestamp() - interval '1 minute'
      )
  `;
  await sql`
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
        ${fixture.primaryJobId},
        ${fixture.primaryEventId},
        ${fixture.recipientProfileId},
        'matching',
        'matching_available',
        'matching_result',
        statement_timestamp() - interval '4 minutes',
        statement_timestamp()
      ),
      (
        ${fixture.transferJobId},
        ${fixture.transferEventId},
        ${fixture.transferProfileId},
        'matching',
        'matching_available',
        'matching_result',
        statement_timestamp() - interval '2 minutes',
        statement_timestamp()
      ),
      (
        ${fixture.zeroTargetJobId},
        ${fixture.zeroTargetEventId},
        ${fixture.zeroTargetProfileId},
        'matching',
        'matching_available',
        'matching_result',
        statement_timestamp() - interval '1 minute',
        statement_timestamp()
      )
  `;
}

async function createRotationJob(fixture) {
  await sql`
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
      ${fixture.rotationJobId},
      ${fixture.rotationEventId},
      ${fixture.rotationProfileId},
      'matching',
      'matching_available',
      'matching_result',
      statement_timestamp() - interval '3 minutes',
      statement_timestamp()
    )
  `;
}

async function prepareJobs(limit) {
  return sql.begin(async (transaction) => {
    await transaction`set local role service_role`;
    const [result] = await transaction`
      select * from private.prepare_push_delivery_jobs(${limit})
    `;
    return result;
  });
}

async function claimTargets(workerId, limit, leaseSeconds) {
  return sql.begin(async (transaction) => {
    await transaction`set local role service_role`;
    return transaction`
      select *
      from private.claim_push_delivery_targets(
        ${workerId},
        ${limit},
        ${leaseSeconds}
      )
    `;
  });
}

async function recordResult(claim, outcome, options = {}) {
  const {
    providerMessageId = null,
    providerErrorCode = null,
    retryAfterSeconds = null,
  } = options;
  return sql.begin(async (transaction) => {
    await transaction`set local role service_role`;
    const [result] = await transaction`
      select private.record_push_delivery_result(
        ${claim.target_id},
        ${claim.lease_id},
        ${claim.token_version},
        ${outcome},
        ${providerMessageId},
        ${providerErrorCode},
        ${retryAfterSeconds}
      ) as outcome
    `;
    return result.outcome;
  });
}

async function assertLeaseRejected(staleClaim) {
  try {
    await recordResult(staleClaim, "delivered");
  } catch (error) {
    if (error?.code === "55000") {
      return;
    }
    throw error;
  }
  throw new ProtocolVerificationError(
    "A stale lease result overwrote a reclaimed delivery target.",
  );
}

function assertTrustedClaim(claim, expectedTokens) {
  assert(
    typeof claim.target_id === "string" &&
      typeof claim.job_id === "string" &&
      typeof claim.lease_id === "string" &&
      typeof claim.provider_token === "string" &&
      expectedTokens.includes(claim.provider_token) &&
      Number.isInteger(claim.attempt_number) &&
      Number.isSafeInteger(Number(claim.token_version)),
    "A trusted claim omitted required token, lease, version, or semantic context.",
  );
}

function sumPreparationResults(results) {
  return results.reduce(
    (totals, result) => ({
      jobsPrepared: totals.jobsPrepared + result.jobs_prepared,
      targetsCreated: totals.targetsCreated + result.targets_created,
      jobsWithoutTargets:
        totals.jobsWithoutTargets + result.jobs_without_targets,
    }),
    { jobsPrepared: 0, targetsCreated: 0, jobsWithoutTargets: 0 },
  );
}

function assert(condition, message) {
  if (!condition) {
    throw new ProtocolVerificationError(message);
  }
}

function safeDatabaseFailure(action, error) {
  const code =
    typeof error?.code === "string" && /^[a-z0-9_]+$/iu.test(error.code)
      ? error.code
      : "unknown";
  return new Error(`Failed to ${action} (code ${code}).`);
}

class ProtocolVerificationError extends Error {}
