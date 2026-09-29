import postgres from "postgres";
import { createClient } from "@supabase/supabase-js";

import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";

const repositoryRoot = process.cwd();
const mailpitUrl = (
  process.env.MAILPIT_URL ?? "http://127.0.0.1:54324"
).replace(/\/$/, "");
const { apiUrl, publishableKey, serviceRoleKey, databaseUrl } =
  readLocalSupabaseStatus(repositoryRoot);

if (!serviceRoleKey || !databaseUrl) {
  throw new Error(
    "Local Supabase status is missing its service-role key or database URL. Update the project-scoped CLI if the status format has changed.",
  );
}

const serviceClient = createClient(apiUrl, serviceRoleKey, {
  auth: { persistSession: false },
});
const sql = postgres(databaseUrl, { max: 2 });

try {
  await verifyPushFoundation();
} finally {
  await sql.end();
}

async function verifyPushFoundation() {
  await drainExistingPushEvents();

  const [creator, requester, other] = await Promise.all([
    signInWithLocalOtp("push-foundation-local-a@planets.invalid"),
    signInWithLocalOtp("push-foundation-local-b@planets.invalid"),
    signInWithLocalOtp("push-foundation-local-c@planets.invalid"),
  ]);
  await Promise.all([
    ensureCompleteProfile(creator, "Push Creator"),
    ensureCompleteProfile(requester, "Push Requester"),
    ensureCompleteProfile(other, "Push Other"),
  ]);

  const installationId = "91000000-0000-4000-8000-000000000001";
  const firstProviderToken = "synthetic-push-token-one";
  const rotatedProviderToken = "synthetic-push-token-two";

  const firstRegistration = await registerInstallation(
    requester,
    installationId,
    "android",
    firstProviderToken,
  );
  assertSafeRegistration(firstRegistration, firstProviderToken);
  assertSafeRegistration(
    await registerInstallation(
      requester,
      installationId,
      "android",
      firstProviderToken,
    ),
    firstProviderToken,
  );
  await registerInstallation(
    requester,
    installationId,
    "android",
    rotatedProviderToken,
  );

  const [rotationState] = await sql`
    select
      count(*) filter (
        where installation_id = ${installationId}
          and profile_id = ${requester.id}
          and provider_token = ${rotatedProviderToken}
          and disabled_at is null
      )::integer as rotated_count,
      count(*) filter (
        where provider_token = ${firstProviderToken}
      )::integer as old_token_count
    from private.push_installations
  `;
  if (
    rotationState.rotated_count !== 1 ||
    rotationState.old_token_count !== 0
  ) {
    throw new Error("Push token rotation did not leave one active assignment.");
  }

  await registerInstallation(
    other,
    installationId,
    "ios",
    rotatedProviderToken,
  );
  const [transferState] = await sql`
    select count(*)::integer as owner_count
    from private.push_installations
    where installation_id = ${installationId}
      and profile_id = ${other.id}
      and platform = 'ios'
      and provider_token = ${rotatedProviderToken}
      and disabled_at is null
  `;
  if (transferState.owner_count !== 1) {
    throw new Error(
      "Account switching did not transfer installation ownership.",
    );
  }

  const crossAccountUnregister = await requester.client.rpc(
    "unregister_own_push_installation",
    {
      p_expected_profile_id: requester.id,
      p_installation_id: installationId,
    },
  );
  if (
    crossAccountUnregister.error?.code !== "42501" ||
    crossAccountUnregister.data !== null
  ) {
    throw new Error(
      "A previous installation owner could unregister a transfer.",
    );
  }

  if (!(await unregisterInstallation(other, installationId))) {
    throw new Error("The current installation owner could not unregister it.");
  }
  if (await unregisterInstallation(other, installationId)) {
    throw new Error("Repeated installation unregister was not idempotent.");
  }
  const [disabledState] = await sql`
    select count(*)::integer as disabled_count
    from private.push_installations
    where installation_id = ${installationId}
      and provider_token is null
      and disabled_at is not null
  `;
  if (disabledState.disabled_count !== 1) {
    throw new Error(
      "Unregister retained a token or failed to disable delivery.",
    );
  }

  await registerInstallation(
    requester,
    installationId,
    "android",
    rotatedProviderToken,
  );

  await setParticipationPreference(creator, false, true);
  const meetingSecret = "Protected push-foundation meeting location";
  const requestSecret = "Private push-foundation request message";
  const projectId = await createProposal(creator, meetingSecret);
  const requestId = await requestToJoin(requester, projectId, requestSecret);

  const notificationProjection = await processNotificationBatch();
  if (
    notificationProjection.processed_count !== 1 ||
    notificationProjection.notifications_created !== 0 ||
    notificationProjection.notifications_suppressed !== 1
  ) {
    throw new Error("The in-app channel was not independently suppressed.");
  }

  const concurrentPushResults = await Promise.all([
    processPushBatch(),
    processPushBatch(),
  ]);
  assertPushBatchTotals(concurrentPushResults, {
    processed: 1,
    created: 1,
    suppressed: 0,
  });

  const [projectedEvent] = await sql`
    select event.id
    from private.outbox_events as event
    where event.event_type = 'project.join_requested'
      and event.payload ->> 'request_id' = ${requestId}
  `;
  if (!projectedEvent?.id) {
    throw new Error("The projected push source event could not be resolved.");
  }

  const [projectionState] = await sql`
    select
      count(distinct job.id)::integer as job_count,
      count(distinct notification.id)::integer as notification_count,
      count(distinct receipt.outbox_event_id) filter (
        where receipt.consumer_key = 'notifications.v1'
      )::integer as notification_receipt_count,
      count(distinct receipt.outbox_event_id) filter (
        where receipt.consumer_key = 'push.v1'
      )::integer as push_receipt_count,
      bool_and(
        not (to_jsonb(job) ? 'provider_token')
        and not (to_jsonb(job) ? 'payload')
        and to_jsonb(job)::text not like ${`%${requestSecret}%`}
        and to_jsonb(job)::text not like ${`%${meetingSecret}%`}
        and to_jsonb(job)::text not like ${`%${rotatedProviderToken}%`}
      ) as safe_job
    from private.outbox_events as event
    left join private.push_delivery_jobs as job
      on job.source_outbox_event_id = event.id
    left join public.notifications as notification
      on notification.source_outbox_event_id = event.id
    left join private.outbox_consumer_receipts as receipt
      on receipt.outbox_event_id = event.id
    where event.id = ${projectedEvent.id}
    group by event.id
  `;
  if (
    projectionState.job_count !== 1 ||
    projectionState.notification_count !== 0 ||
    projectionState.notification_receipt_count !== 1 ||
    projectionState.push_receipt_count !== 1 ||
    projectionState.safe_job !== true
  ) {
    throw new Error(
      "Push projection did not preserve channel independence or job privacy.",
    );
  }

  await sql`
    delete from private.outbox_consumer_receipts
    where outbox_event_id = ${projectedEvent.id}
      and consumer_key = 'push.v1'
  `;
  const retryResult = await processPushBatch();
  if (
    retryResult.processed_count !== 1 ||
    retryResult.jobs_created !== 0 ||
    retryResult.jobs_suppressed !== 0
  ) {
    throw new Error("A push retry did not recover idempotently.");
  }
  const [retryState] = await sql`
    select count(*)::integer as count
    from private.push_delivery_jobs
    where source_outbox_event_id = ${projectedEvent.id}
  `;
  if (retryState.count !== 1) {
    throw new Error("A push retry duplicated its recipient-level job.");
  }

  await setParticipationPreference(creator, false, false);
  await withdrawRequest(requester, requestId);
  const disabledPushResult = await processPushBatch();
  if (
    disabledPushResult.processed_count !== 1 ||
    disabledPushResult.jobs_created !== 0 ||
    disabledPushResult.jobs_suppressed !== 1
  ) {
    throw new Error("A push-disabled event was not suppressed and receipted.");
  }
  const [withdrawnEventState] = await sql`
    select
      count(job.id)::integer as job_count,
      count(receipt.outbox_event_id)::integer as receipt_count
    from private.outbox_events as event
    left join private.push_delivery_jobs as job
      on job.source_outbox_event_id = event.id
    left join private.outbox_consumer_receipts as receipt
      on receipt.outbox_event_id = event.id
      and receipt.consumer_key = 'push.v1'
    where event.event_type = 'project.join_request_withdrawn'
      and event.payload ->> 'request_id' = ${requestId}
    group by event.id
  `;
  if (
    withdrawnEventState.job_count !== 0 ||
    withdrawnEventState.receipt_count !== 1
  ) {
    throw new Error("Push suppression produced a job or missed its receipt.");
  }

  const unsupportedEventId = "cf000000-0000-4000-8000-00000000000f";
  await sql`
    insert into private.outbox_events (id, event_type, payload)
    values (${unsupportedEventId}, 'push.integration_unsupported', '{}'::jsonb)
  `;
  assertPushBatchTotals([await processPushBatch()], {
    processed: 0,
    created: 0,
    suppressed: 0,
  });
  const [unsupportedState] = await sql`
    select count(*)::integer as receipt_count
    from private.outbox_consumer_receipts
    where outbox_event_id = ${unsupportedEventId}
      and consumer_key = 'push.v1'
  `;
  if (unsupportedState.receipt_count !== 0) {
    throw new Error("Push projection receipted an unsupported source event.");
  }

  console.log(
    "Confirmed private installation registration, rotation, account transfer, unregister, independent push projection, safe recipient-level jobs, idempotent retry, preference suppression, and multi-consumer receipts.",
  );
}

async function registerInstallation(user, installationId, platform, token) {
  const { data, error } = await user.client.rpc(
    "register_own_push_installation",
    {
      p_expected_profile_id: user.id,
      p_installation_id: installationId,
      p_platform: platform,
      p_provider_token: token,
    },
  );
  if (error || !Array.isArray(data) || data.length !== 1) {
    throw safeDatabaseFailure("register a push installation", error ?? {});
  }
  return data[0];
}

function assertSafeRegistration(registration, token) {
  if (
    registration.provider !== "fcm" ||
    typeof registration.installation_id !== "string" ||
    typeof registration.last_registered_at !== "string" ||
    Object.hasOwn(registration, "provider_token") ||
    JSON.stringify(registration).includes(token)
  ) {
    throw new Error(
      "Push registration returned unsafe or incomplete metadata.",
    );
  }
}

async function unregisterInstallation(user, installationId) {
  const { data, error } = await user.client.rpc(
    "unregister_own_push_installation",
    {
      p_expected_profile_id: user.id,
      p_installation_id: installationId,
    },
  );
  if (error || typeof data !== "boolean") {
    throw safeDatabaseFailure("unregister a push installation", error ?? {});
  }
  return data;
}

async function processPushBatch() {
  const { data, error } = await serviceClient.rpc("process_push_outbox_batch", {
    p_limit: 100,
  });
  const result = data?.[0];
  if (
    error ||
    !result ||
    !Number.isInteger(result.processed_count) ||
    !Number.isInteger(result.jobs_created) ||
    !Number.isInteger(result.jobs_suppressed)
  ) {
    throw safeDatabaseFailure("process the push outbox", error ?? {});
  }
  return result;
}

async function processNotificationBatch() {
  const { data, error } = await serviceClient.rpc(
    "process_notification_outbox_batch",
    { p_limit: 100 },
  );
  const result = data?.[0];
  if (
    error ||
    !result ||
    !Number.isInteger(result.processed_count) ||
    !Number.isInteger(result.notifications_created) ||
    !Number.isInteger(result.notifications_suppressed)
  ) {
    throw safeDatabaseFailure("process the notification outbox", error ?? {});
  }
  return result;
}

function assertPushBatchTotals(results, expected) {
  const totals = results.reduce(
    (sum, result) => ({
      processed: sum.processed + result.processed_count,
      created: sum.created + result.jobs_created,
      suppressed: sum.suppressed + result.jobs_suppressed,
    }),
    { processed: 0, created: 0, suppressed: 0 },
  );
  if (
    totals.processed !== expected.processed ||
    totals.created !== expected.created ||
    totals.suppressed !== expected.suppressed
  ) {
    throw new Error(
      `Push projector counts were ${totals.processed}/${totals.created}/${totals.suppressed}; expected ${expected.processed}/${expected.created}/${expected.suppressed}.`,
    );
  }
}

async function drainExistingPushEvents() {
  for (let batch = 0; batch < 20; batch += 1) {
    const result = await processPushBatch();
    if (result.processed_count === 0) {
      return;
    }
  }
  throw new Error("The local push backlog did not drain within 20 batches.");
}

async function setParticipationPreference(user, inAppEnabled, pushEnabled) {
  const { error } = await user.client.rpc("set_own_notification_preference", {
    p_expected_profile_id: user.id,
    p_category_slug: "participation",
    p_in_app_enabled: inAppEnabled,
    p_push_enabled: pushEnabled,
  });
  if (error) {
    throw safeDatabaseFailure("update participation channels", error);
  }
}

async function createProposal(creator, exactMeetingText) {
  const { data, error } = await creator.client.rpc("create_proposal_draft", {
    p_expected_creator_profile_id: creator.id,
    p_title: "Integration push-foundation proposal",
    p_summary: "A deterministic proposal for push-foundation verification.",
    p_description:
      "This proposal verifies provider-independent push delivery jobs.",
    p_starts_at: "2098-01-02T10:00:00.000Z",
    p_ends_at: "2098-01-02T14:00:00.000Z",
    p_event_timezone: "Europe/Rome",
    p_country_code: "IT",
    p_locality: "Trento",
    p_administrative_area: "Povo",
    p_public_location_label: "Trento · Povo",
    p_exact_meeting_text: exactMeetingText,
    p_exact_location_visibility: "participants",
    p_skill_ids: [],
    p_skill_importances: [],
    p_people_capacity: 20,
  });
  if (error || typeof data !== "string") {
    throw safeDatabaseFailure(
      "create a push verification proposal",
      error ?? {},
    );
  }
  const { error: publishError } = await creator.client.rpc("publish_proposal", {
    p_expected_creator_profile_id: creator.id,
    p_proposal_id: data,
  });
  if (publishError) {
    throw safeDatabaseFailure(
      "publish a push verification proposal",
      publishError,
    );
  }
  return data;
}

async function requestToJoin(user, projectId, requestMessage) {
  const { data, error } = await user.client.rpc("request_to_join_project", {
    p_expected_requester_profile_id: user.id,
    p_project_id: projectId,
    p_request_message: requestMessage,
  });
  if (error || typeof data !== "string") {
    throw safeDatabaseFailure(
      "create a push verification request",
      error ?? {},
    );
  }
  return data;
}

async function withdrawRequest(user, requestId) {
  const { error } = await user.client.rpc("withdraw_project_join_request", {
    p_expected_requester_profile_id: user.id,
    p_request_id: requestId,
  });
  if (error) {
    throw safeDatabaseFailure("withdraw a push verification request", error);
  }
}

async function ensureCompleteProfile(user, displayName) {
  const { error: anchorError } = await user.client
    .from("profiles")
    .insert({ id: user.id });
  if (anchorError) {
    const diagnostic = `${anchorError.message ?? ""} ${anchorError.details ?? ""}`;
    if (anchorError.code !== "23505" || !diagnostic.includes("profiles_pkey")) {
      throw safeDatabaseFailure(
        "create a push verification profile",
        anchorError,
      );
    }
  }

  const { error: updateError } = await user.client.rpc("update_own_profile", {
    p_expected_profile_id: user.id,
    p_display_name: displayName,
    p_bio: null,
    p_skill_ids: [],
    p_display_name_audience: "private",
    p_bio_audience: "private",
    p_skills_audience: "private",
  });
  if (updateError) {
    throw safeDatabaseFailure(
      "complete a push verification profile",
      updateError,
    );
  }
}

async function signInWithLocalOtp(email) {
  const client = createClient(apiUrl, publishableKey, {
    auth: { persistSession: false },
  });
  const existingMessageIds = await findMessageIds(email);
  const requestStartedAt = Date.now();
  const { error: requestError } = await client.auth.signInWithOtp({
    email,
    options: { shouldCreateUser: true },
  });
  if (requestError) {
    throw safeDatabaseFailure(
      "request a local push-foundation OTP",
      requestError,
    );
  }

  const messageId = await waitForNewMessage(
    email,
    existingMessageIds,
    requestStartedAt,
  );
  const message = await fetchJson(
    `${mailpitUrl}/api/v1/message/${encodeURIComponent(messageId)}`,
    {},
    "read a local push-foundation OTP email",
  );
  const messageBody = `${message.Text ?? ""} ${message.HTML ?? ""}`;
  const token = messageBody.match(/(?:^|\D)(\d{6})(?:\D|$)/)?.[1];
  if (!token) {
    throw new Error("A local push-foundation email had no 6-digit token.");
  }

  const { data: verification, error: verificationError } =
    await client.auth.verifyOtp({ email, token, type: "email" });
  if (verificationError || !verification.user?.id || !verification.session) {
    throw safeDatabaseFailure(
      "verify a local push-foundation OTP",
      verificationError ?? {},
    );
  }
  return { client, id: verification.user.id };
}

async function findMessageIds(email) {
  const result = await fetchJson(
    `${mailpitUrl}/api/v1/search?query=${encodeURIComponent(`to:${email}`)}&limit=50`,
    {},
    "search the local mailbox",
  );
  return new Set(
    Array.isArray(result.messages)
      ? result.messages
          .map((message) => message.ID)
          .filter((id) => typeof id === "string")
      : [],
  );
}

async function waitForNewMessage(email, existingIds, requestStartedAt) {
  const deadline = requestStartedAt + 15_000;
  while (Date.now() < deadline) {
    const result = await fetchJson(
      `${mailpitUrl}/api/v1/search?query=${encodeURIComponent(`to:${email}`)}&limit=10`,
      {},
      "search the local mailbox",
    );
    const messages = Array.isArray(result.messages) ? result.messages : [];
    const message = messages.find(
      (candidate) =>
        typeof candidate.ID === "string" && !existingIds.has(candidate.ID),
    );
    if (message) {
      return message.ID;
    }
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
  throw new Error("Mailpit did not receive a push-foundation OTP in time.");
}

function safeDatabaseFailure(action, error) {
  const code =
    typeof error?.code === "string" && /^[a-z0-9_]+$/iu.test(error.code)
      ? error.code
      : "unknown";
  return new Error(`Failed to ${action} (code ${code}).`);
}

async function fetchJson(url, options, action) {
  const response = await fetch(url, options);
  if (!response.ok) {
    throw new Error(`Failed to ${action} (HTTP ${response.status}).`);
  }
  try {
    return await response.json();
  } catch {
    throw new Error(`Failed to ${action}: the response was not valid JSON.`);
  }
}
