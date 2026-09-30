import postgres from "postgres";
import { createClient } from "@supabase/supabase-js";

import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";
import { ensureLocalProfilePhoto } from "./lib/local-profile-photo.mjs";

const repositoryRoot = process.cwd();
const mailpitUrl = (
  process.env.MAILPIT_URL ?? "http://127.0.0.1:54324"
).replace(/\/$/, "");
const status = readLocalSupabaseStatus(repositoryRoot);
const { apiUrl, publishableKey, serviceRoleKey, databaseUrl } = status;

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
  await verifyNotifications();
} finally {
  await sql.end();
}

async function verifyNotifications() {
  // Earlier integration harnesses intentionally create valid participation events.
  // Drain that known local backlog before establishing this harness's exact counts.
  await drainExistingNotificationEvents();

  const [creator, requester, unrelated] = await Promise.all([
    signInWithLocalOtp("notifications-local-a@planets.invalid"),
    signInWithLocalOtp("notifications-local-b@planets.invalid"),
    signInWithLocalOtp("notifications-local-c@planets.invalid"),
  ]);
  await Promise.all([
    ensureCompleteProfile(creator, "Notification Creator"),
    ensureCompleteProfile(requester, "Notification Requester"),
    ensureCompleteProfile(unrelated, "Notification Other"),
  ]);
  await Promise.all(
    [creator, requester, unrelated].map((user) =>
      ensureLocalProfilePhoto(user),
    ),
  );

  const meetingSecret = "Protected notification integration courtyard";
  const requestSecret = "Private notification integration request";
  const projectId = await createProposal(creator, meetingSecret);
  const requestId = await requestToJoin(requester, projectId, requestSecret);

  const beforeProjection = await listNotifications(creator);
  if (beforeProjection.length !== 0) {
    throw new Error(
      "A notification existed before its source event was projected.",
    );
  }

  const concurrentResults = await Promise.all([
    processNotificationBatch(),
    processNotificationBatch(),
  ]);
  assertBatchTotals(concurrentResults, {
    processed: 1,
    created: 1,
    suppressed: 0,
  });

  const creatorInbox = await listNotifications(creator);
  const requestReceived = creatorInbox.filter(
    (notification) =>
      notification.notification_kind === "participation_request_received" &&
      notification.project_id === projectId,
  );
  if (
    requestReceived.length !== 1 ||
    requestReceived[0].actor_profile_id !== requester.id ||
    requestReceived[0].actor_display_name !== "Notification Requester" ||
    requestReceived[0].project_kind !== "one_time" ||
    requestReceived[0].destination_kind !== "participation_request" ||
    requestReceived[0].request_id !== requestId
  ) {
    throw new Error(
      "Concurrent projection did not create exactly one canonical request notification.",
    );
  }

  const { data: unrelatedData, error: unrelatedError } =
    await unrelated.client.rpc("list_own_notifications", {
      p_expected_profile_id: creator.id,
      p_limit: 20,
      p_cursor_created_at: null,
      p_cursor_id: null,
    });
  if (unrelatedError?.code !== "42501" || unrelatedData !== null) {
    throw new Error("A cross-account inbox read did not fail closed.");
  }

  assertBatchTotals([await processNotificationBatch()], {
    processed: 0,
    created: 0,
    suppressed: 0,
  });

  const membershipId = await acceptRequest(creator, requestId);
  assertBatchTotals([await processNotificationBatch()], {
    processed: 1,
    created: 1,
    suppressed: 0,
  });

  const acceptedInbox = await listNotifications(requester);
  const accepted = acceptedInbox.find(
    (notification) =>
      notification.notification_kind === "participation_request_accepted" &&
      notification.project_id === projectId,
  );
  if (
    !accepted ||
    accepted.actor_profile_id !== creator.id ||
    accepted.actor_display_name !== "Notification Creator" ||
    accepted.project_title !== "Integration notification proposal" ||
    accepted.destination_kind !== "participation_request" ||
    accepted.request_id !== requestId
  ) {
    throw new Error(
      "The accepted notification returned unsafe or incomplete context.",
    );
  }

  const unreadBefore = await unreadCount(requester);
  const { data: readAt, error: markReadError } = await requester.client.rpc(
    "mark_notification_read",
    {
      p_expected_profile_id: requester.id,
      p_notification_id: accepted.notification_id,
    },
  );
  if (markReadError || typeof readAt !== "string") {
    throw safeDatabaseFailure("mark a notification read", markReadError ?? {});
  }
  const unreadAfter = await unreadCount(requester);
  if (unreadBefore !== 1 || unreadAfter !== 0) {
    throw new Error("Notification read state did not update the unread count.");
  }

  await setParticipationPreference(creator, false);
  const suppressedRequestId = await requestToJoin(
    unrelated,
    projectId,
    "A second private request that must stay out of notification state.",
  );
  assertBatchTotals([await processNotificationBatch()], {
    processed: 1,
    created: 0,
    suppressed: 1,
  });
  assertBatchTotals([await processNotificationBatch()], {
    processed: 0,
    created: 0,
    suppressed: 0,
  });

  const [suppressedReceipt] = await sql`
    select
      count(receipt.outbox_event_id)::integer as receipt_count,
      count(notification.id)::integer as notification_count
    from private.outbox_events as event
    left join private.outbox_consumer_receipts as receipt
      on receipt.outbox_event_id = event.id
      and receipt.consumer_key = 'notifications.v1'
    left join public.notifications as notification
      on notification.source_outbox_event_id = event.id
    where event.event_type = 'project.join_requested'
      and event.payload ->> 'request_id' = ${suppressedRequestId}
  `;
  if (
    suppressedReceipt.receipt_count !== 1 ||
    suppressedReceipt.notification_count !== 0
  ) {
    throw new Error(
      "A preference-disabled event was not receipted without a notification.",
    );
  }

  await setParticipationPreference(creator, true);
  await withdrawRequest(unrelated, suppressedRequestId);
  assertBatchTotals([await processNotificationBatch()], {
    processed: 1,
    created: 1,
    suppressed: 0,
  });
  const withdrawn = (await listNotifications(creator)).find(
    (notification) =>
      notification.notification_kind === "participation_request_withdrawn" &&
      notification.request_id === suppressedRequestId,
  );
  if (!withdrawn || withdrawn.destination_kind !== "participation_request") {
    throw new Error(
      "The withdrawal event did not preserve its structured request target.",
    );
  }

  const rejectedRequestId = await requestToJoin(unrelated, projectId, null);
  await rejectRequest(creator, rejectedRequestId);
  assertBatchTotals([await processNotificationBatch()], {
    processed: 2,
    created: 2,
    suppressed: 0,
  });
  const rejectedInbox = await listNotifications(unrelated);
  const rejected = rejectedInbox.filter(
    (notification) =>
      notification.notification_kind === "participation_request_rejected" &&
      notification.request_id === rejectedRequestId,
  );
  if (
    rejected.length !== 1 ||
    rejected[0].destination_kind !== "participation_request"
  ) {
    throw new Error(
      "The rejection event did not map exactly once to its structured request target.",
    );
  }

  await leaveMembership(requester, membershipId);
  assertBatchTotals([await processNotificationBatch()], {
    processed: 1,
    created: 1,
    suppressed: 0,
  });
  const finalCreatorInbox = await listNotifications(creator);
  const participantLeft = finalCreatorInbox.filter(
    (notification) => notification.notification_kind === "participant_left",
  );
  if (
    participantLeft.length !== 1 ||
    participantLeft[0].destination_kind !== "project_participation"
  ) {
    throw new Error("The participant-left event did not map exactly once.");
  }

  const serializedInboxes = JSON.stringify([
    finalCreatorInbox,
    await listNotifications(requester),
    rejectedInbox,
  ]);
  if (
    serializedInboxes.includes(requestSecret) ||
    serializedInboxes.includes(meetingSecret) ||
    serializedInboxes.includes("exact_meeting") ||
    serializedInboxes.includes("request_message") ||
    serializedInboxes.includes("source_outbox") ||
    serializedInboxes.includes("@planets.invalid")
  ) {
    throw new Error("Private source content leaked into an inbox result.");
  }

  const [acceptedEvent] = await sql`
    select id
    from private.outbox_events
    where event_type = 'project.join_request_accepted'
      and payload ->> 'request_id' = ${requestId}
  `;
  if (!acceptedEvent?.id) {
    throw new Error(
      "The accepted event could not be found for receipt verification.",
    );
  }
  await sql`
    insert into private.outbox_consumer_receipts (
      outbox_event_id,
      consumer_key,
      processed_at
    )
    values (${acceptedEvent.id}, 'integration.synthetic.v1', statement_timestamp())
  `;
  const [consumerCount] = await sql`
    select count(*)::integer as count
    from private.outbox_consumer_receipts
    where outbox_event_id = ${acceptedEvent.id}
  `;
  if (consumerCount.count !== 2) {
    throw new Error(
      "An independent consumer receipt could not coexist with notifications.v1.",
    );
  }

  console.log(
    "Confirmed private notification projection, concurrent idempotency, six-event participation mapping, stable request targets, preference suppression, safe inbox context, read state, and independent consumer receipts.",
  );
}

async function drainExistingNotificationEvents() {
  for (let batch = 0; batch < 20; batch += 1) {
    const result = await processNotificationBatch();
    if (result.processed_count === 0) {
      return;
    }
  }
  throw new Error(
    "The local notification backlog did not drain within 20 projector batches.",
  );
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
    throw safeDatabaseFailure("process notification outbox", error ?? {});
  }
  return result;
}

function assertBatchTotals(results, expected) {
  const totals = results.reduce(
    (sum, result) => ({
      processed: sum.processed + result.processed_count,
      created: sum.created + result.notifications_created,
      suppressed: sum.suppressed + result.notifications_suppressed,
    }),
    { processed: 0, created: 0, suppressed: 0 },
  );
  if (
    totals.processed !== expected.processed ||
    totals.created !== expected.created ||
    totals.suppressed !== expected.suppressed
  ) {
    throw new Error(
      `Notification projector counts were ${totals.processed}/${totals.created}/${totals.suppressed}; expected ${expected.processed}/${expected.created}/${expected.suppressed}.`,
    );
  }
}

async function listNotifications(user) {
  const { data, error } = await user.client.rpc("list_own_notifications", {
    p_expected_profile_id: user.id,
    p_limit: 100,
    p_cursor_created_at: null,
    p_cursor_id: null,
  });
  if (error || !Array.isArray(data)) {
    throw safeDatabaseFailure("list own notifications", error ?? {});
  }
  return data;
}

async function unreadCount(user) {
  const { data, error } = await user.client.rpc(
    "get_own_unread_notification_count",
    { p_expected_profile_id: user.id },
  );
  if (error || !Number.isInteger(data)) {
    throw safeDatabaseFailure("read notification unread count", error ?? {});
  }
  return data;
}

async function setParticipationPreference(user, inAppEnabled) {
  const { error } = await user.client.rpc("set_own_notification_preference", {
    p_expected_profile_id: user.id,
    p_category_slug: "participation",
    p_in_app_enabled: inAppEnabled,
    p_push_enabled: true,
  });
  if (error) {
    throw safeDatabaseFailure("update notification preference", error);
  }
}

async function createProposal(creator, exactMeetingText) {
  const { data, error } = await creator.client.rpc("create_proposal_draft", {
    p_expected_creator_profile_id: creator.id,
    p_title: "Integration notification proposal",
    p_summary: "A deterministic proposal for notification verification.",
    p_description:
      "This proposal verifies private outbox projection and inbox context.",
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
  });
  if (error || typeof data !== "string") {
    throw safeDatabaseFailure("create notification proposal", error ?? {});
  }
  const { error: publishError } = await creator.client.rpc("publish_proposal", {
    p_expected_creator_profile_id: creator.id,
    p_proposal_id: data,
  });
  if (publishError) {
    throw safeDatabaseFailure("publish notification proposal", publishError);
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
    throw safeDatabaseFailure("request notification project", error ?? {});
  }
  return data;
}

async function withdrawRequest(user, requestId) {
  const { error } = await user.client.rpc("withdraw_project_join_request", {
    p_expected_requester_profile_id: user.id,
    p_request_id: requestId,
  });
  if (error) {
    throw safeDatabaseFailure("withdraw notification request", error);
  }
}

async function acceptRequest(creator, requestId) {
  const { data, error } = await creator.client.rpc(
    "accept_project_join_request",
    {
      p_expected_creator_profile_id: creator.id,
      p_request_id: requestId,
    },
  );
  if (error || typeof data !== "string") {
    throw safeDatabaseFailure("accept notification request", error ?? {});
  }
  return data;
}

async function rejectRequest(creator, requestId) {
  const { error } = await creator.client.rpc("reject_project_join_request", {
    p_expected_creator_profile_id: creator.id,
    p_request_id: requestId,
  });
  if (error) {
    throw safeDatabaseFailure("reject notification request", error);
  }
}

async function leaveMembership(user, membershipId) {
  const { error } = await user.client.rpc("leave_project", {
    p_expected_participant_profile_id: user.id,
    p_membership_id: membershipId,
  });
  if (error) {
    throw safeDatabaseFailure("leave notification membership", error);
  }
}

async function ensureCompleteProfile(user, displayName) {
  const { error: anchorError } = await user.client
    .from("profiles")
    .insert({ id: user.id });
  if (anchorError) {
    const diagnostic = `${anchorError.message ?? ""} ${anchorError.details ?? ""}`;
    if (anchorError.code !== "23505" || !diagnostic.includes("profiles_pkey")) {
      throw safeDatabaseFailure("create notification profile", anchorError);
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
    throw safeDatabaseFailure("complete notification profile", updateError);
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
    throw safeDatabaseFailure("request a local notification OTP", requestError);
  }

  const messageId = await waitForNewMessage(
    email,
    existingMessageIds,
    requestStartedAt,
  );
  const message = await fetchJson(
    `${mailpitUrl}/api/v1/message/${encodeURIComponent(messageId)}`,
    {},
    "read a local notification OTP email",
  );
  const messageBody = `${message.Text ?? ""} ${message.HTML ?? ""}`;
  const token = messageBody.match(/(?:^|\D)(\d{6})(?:\D|$)/)?.[1];
  if (!token) {
    throw new Error(
      "A local notification email did not contain a 6-digit token.",
    );
  }

  const { data: verification, error: verificationError } =
    await client.auth.verifyOtp({ email, token, type: "email" });
  if (verificationError || !verification.user?.id || !verification.session) {
    throw safeDatabaseFailure(
      "verify a local notification OTP",
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
  throw new Error(
    "Mailpit did not receive a notification OTP within 15 seconds.",
  );
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
