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
const sql = postgres(databaseUrl, { max: 6 });

try {
  await verifyProjectChatNotifications();
} finally {
  await sql.end();
}

async function verifyProjectChatNotifications() {
  await acknowledgeExistingEvents();

  const [creator, participantA, participantB] = await Promise.all([
    signInWithLocalOtp("chat-alerts-creator@planets.invalid"),
    signInWithLocalOtp("chat-alerts-a@planets.invalid"),
    signInWithLocalOtp("chat-alerts-b@planets.invalid"),
  ]);
  await Promise.all([
    ensureCompleteProfile(creator, "Chat Alerts Creator"),
    ensureCompleteProfile(participantA, "Chat Alerts A"),
    ensureCompleteProfile(participantB, "Chat Alerts B"),
  ]);
  await Promise.all(
    [creator, participantA, participantB].map((user) =>
      setChatPreference(user, true, true),
    ),
  );

  const proposalId = await createProposal(creator);
  let membershipA = await joinProject(creator, participantA, proposalId);
  const proposalChat = await getChat(creator, proposalId);
  await acknowledgeNonChatEvents();

  const message1 = await sendMessage(
    participantA,
    proposalChat.chat_id,
    "Proposal alert timeline message one",
  );
  const membershipB = await joinProject(creator, participantB, proposalId);
  const message2 = await sendMessage(
    creator,
    proposalChat.chat_id,
    "Proposal alert timeline message two",
  );
  await leaveMembership(participantA, membershipA);
  const message3 = await sendMessage(
    creator,
    proposalChat.chat_id,
    "Proposal alert timeline message three",
  );
  membershipA = await joinProject(creator, participantA, proposalId);
  const message4 = await sendMessage(
    participantB,
    proposalChat.chat_id,
    "Proposal alert timeline message four",
  );
  await leaveMembership(participantA, membershipA);
  const message5 = await sendMessage(
    creator,
    proposalChat.chat_id,
    "Proposal alert timeline message five",
  );
  await acknowledgeNonChatEvents();

  const proposalMessages = [message1, message2, message3, message4, message5];
  assertNotificationBatchTotals(
    await Promise.all([processNotificationBatch(), processNotificationBatch()]),
    { processed: 5, created: 7, suppressed: 0 },
  );
  assertPushBatchTotals(
    await Promise.all([processPushBatch(), processPushBatch()]),
    { processed: 5, created: 7, suppressed: 0 },
  );
  await assertRecipients(message1, [creator.id]);
  await assertRecipients(message2, [participantA.id, participantB.id]);
  await assertRecipients(message3, [participantB.id]);
  await assertRecipients(message4, [creator.id, participantA.id]);
  await assertRecipients(message5, [participantB.id]);
  await assertNoSenderAlerts(proposalMessages);

  membershipA = await joinProject(creator, participantA, proposalId);
  await Promise.all([
    setChatPreference(participantA, true, false),
    setChatPreference(participantB, false, true),
  ]);
  await acknowledgeNonChatEvents();
  const splitPreferenceMessage = await sendMessage(
    creator,
    proposalChat.chat_id,
    "Proposal split preference message",
  );
  assertNotificationBatchTotals([await processNotificationBatch()], {
    processed: 1,
    created: 1,
    suppressed: 1,
  });
  assertPushBatchTotals([await processPushBatch()], {
    processed: 1,
    created: 1,
    suppressed: 1,
  });
  await assertChannelRecipients(
    splitPreferenceMessage.message_id,
    [participantA.id],
    [participantB.id],
  );

  await setChatPreference(participantA, false, false);
  const disabledMessage = await sendMessage(
    participantB,
    proposalChat.chat_id,
    "Proposal disabled preference message",
  );
  assertNotificationBatchTotals([await processNotificationBatch()], {
    processed: 1,
    created: 1,
    suppressed: 1,
  });
  assertPushBatchTotals([await processPushBatch()], {
    processed: 1,
    created: 1,
    suppressed: 1,
  });
  await assertChannelRecipients(
    disabledMessage.message_id,
    [creator.id],
    [creator.id],
  );

  const tavoloId = await createTavolo(creator);
  await setChatPreference(participantA, true, true);
  await joinProject(creator, participantA, tavoloId);
  const tavoloChat = await getChat(creator, tavoloId);
  await acknowledgeNonChatEvents();
  const tavoloMessage = await sendMessage(
    participantA,
    tavoloChat.chat_id,
    "Tavolo alert integration message",
  );
  assertNotificationBatchTotals([await processNotificationBatch()], {
    processed: 1,
    created: 1,
    suppressed: 0,
  });
  assertPushBatchTotals([await processPushBatch()], {
    processed: 1,
    created: 1,
    suppressed: 0,
  });
  await assertRecipients(tavoloMessage, [creator.id], "recurring");

  await assertInboxContext(creator, [
    message1,
    message4,
    disabledMessage,
    tavoloMessage,
  ]);
  await assertIdentifierOnlyAndBodyFreeState([
    ...proposalMessages,
    splitPreferenceMessage,
    disabledMessage,
    tavoloMessage,
  ]);
  await assertReceiptsComplete([
    ...proposalMessages,
    splitPreferenceMessage,
    disabledMessage,
    tavoloMessage,
  ]);

  if (!membershipB) {
    throw new Error("The Proposal participant membership was not retained.");
  }

  console.log(
    "Confirmed Proposal/Tavolo chat-alert fan-out at message time, sender exclusion, late-join/leave/rejoin semantics, independent in-app/push preferences, concurrent idempotent projection, safe inbox context, and body-free alert state.",
  );
}

async function acknowledgeExistingEvents() {
  await sql`
    insert into private.outbox_consumer_receipts (
      outbox_event_id,
      consumer_key,
      processed_at
    )
    select event.id, consumer.consumer_key, statement_timestamp()
    from private.outbox_events as event
    cross join (
      values ('notifications.v1'::text), ('push.v1'::text)
    ) as consumer(consumer_key)
    on conflict (outbox_event_id, consumer_key) do nothing
  `;
}

async function acknowledgeNonChatEvents() {
  await sql`
    insert into private.outbox_consumer_receipts (
      outbox_event_id,
      consumer_key,
      processed_at
    )
    select event.id, consumer.consumer_key, statement_timestamp()
    from private.outbox_events as event
    cross join (
      values ('notifications.v1'::text), ('push.v1'::text)
    ) as consumer(consumer_key)
    where event.event_type <> 'project.chat_message_sent'
    on conflict (outbox_event_id, consumer_key) do nothing
  `;
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
    throw safeDatabaseFailure("process push outbox", error ?? {});
  }
  return result;
}

function assertNotificationBatchTotals(results, expected) {
  const totals = results.reduce(
    (sum, result) => ({
      processed: sum.processed + result.processed_count,
      created: sum.created + result.notifications_created,
      suppressed: sum.suppressed + result.notifications_suppressed,
    }),
    { processed: 0, created: 0, suppressed: 0 },
  );
  assertTotals("Notification", totals, expected);
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
  assertTotals("Push", totals, expected);
}

function assertTotals(label, actual, expected) {
  if (
    actual.processed !== expected.processed ||
    actual.created !== expected.created ||
    actual.suppressed !== expected.suppressed
  ) {
    throw new Error(
      `${label} projector counts were ${actual.processed}/${actual.created}/${actual.suppressed}; expected ${expected.processed}/${expected.created}/${expected.suppressed}.`,
    );
  }
}

async function assertRecipients(message, expected, projectKind = "one_time") {
  await assertChannelRecipients(message.message_id, expected, expected);
  const [context] = await sql`
    select
      count(*)::integer as notification_count,
      min(notification.project_kind) as notification_project_kind,
      min(job.project_kind) as job_project_kind,
      min(notification.chat_id::text) as notification_chat_id,
      min(job.chat_id::text) as job_chat_id
    from public.notifications as notification
    join private.push_delivery_jobs as job
      on job.source_outbox_event_id = notification.source_outbox_event_id
      and job.recipient_profile_id = notification.recipient_profile_id
    where notification.message_id = ${message.message_id}
  `;
  if (
    context.notification_count !== expected.length ||
    context.notification_project_kind !== projectKind ||
    context.job_project_kind !== projectKind ||
    context.notification_chat_id !== message.chat_id ||
    context.job_chat_id !== message.chat_id
  ) {
    throw new Error(
      "Chat-alert semantic context was incomplete or mismatched.",
    );
  }
}

async function assertChannelRecipients(messageId, notificationIds, pushIds) {
  const notificationRows = await sql`
    select recipient_profile_id::text as recipient_profile_id
    from public.notifications
    where message_id = ${messageId}
    order by recipient_profile_id
  `;
  const pushRows = await sql`
    select recipient_profile_id::text as recipient_profile_id
    from private.push_delivery_jobs
    where message_id = ${messageId}
    order by recipient_profile_id
  `;
  assertIds(
    "notification",
    notificationRows.map((row) => row.recipient_profile_id),
    notificationIds,
  );
  assertIds(
    "push job",
    pushRows.map((row) => row.recipient_profile_id),
    pushIds,
  );
}

function assertIds(label, actual, expected) {
  const normalizedActual = [...actual].sort();
  const normalizedExpected = [...expected].sort();
  if (JSON.stringify(normalizedActual) !== JSON.stringify(normalizedExpected)) {
    throw new Error(
      `Unexpected ${label} recipients: ${normalizedActual.length}; expected ${normalizedExpected.length}.`,
    );
  }
}

async function assertNoSenderAlerts(messages) {
  const messageIds = messages.map((message) => message.message_id);
  const [result] = await sql`
    select
      count(notification.id)::integer as notification_count,
      count(job.id)::integer as job_count
    from public.project_chat_messages as message
    left join public.notifications as notification
      on notification.message_id = message.id
      and notification.recipient_profile_id = message.sender_profile_id
    left join private.push_delivery_jobs as job
      on job.message_id = message.id
      and job.recipient_profile_id = message.sender_profile_id
    where message.id = any(${messageIds}::uuid[])
  `;
  if (result.notification_count !== 0 || result.job_count !== 0) {
    throw new Error("A chat-message sender received their own alert.");
  }
}

async function assertInboxContext(user, messages) {
  const { data, error } = await user.client.rpc("list_own_notifications", {
    p_expected_profile_id: user.id,
    p_limit: 100,
    p_cursor_created_at: null,
    p_cursor_id: null,
  });
  if (error || !Array.isArray(data)) {
    throw safeDatabaseFailure("list chat-alert inbox", error ?? {});
  }
  for (const message of messages) {
    const item = data.find(
      (candidate) => candidate.message_id === message.message_id,
    );
    if (
      !item ||
      item.notification_kind !== "chat_message_received" ||
      item.destination_kind !== "project_chat" ||
      item.chat_id !== message.chat_id ||
      Object.hasOwn(item, "body")
    ) {
      throw new Error(
        "The inbox omitted safe chat/message destination context.",
      );
    }
  }
  if (JSON.stringify(data).includes("integration message")) {
    throw new Error("A message body leaked through the notification inbox.");
  }
}

async function assertIdentifierOnlyAndBodyFreeState(messages) {
  const messageIds = messages.map((message) => message.message_id);
  const eventRows = await sql`
    select payload
    from private.outbox_events
    where event_type = 'project.chat_message_sent'
      and payload ->> 'message_id' = any(${messageIds}::text[])
  `;
  const expectedKeys = [
    "chat_id",
    "message_id",
    "project_id",
    "project_kind",
    "sender_profile_id",
  ];
  if (eventRows.length !== messages.length) {
    throw new Error(
      "The chat-alert integration did not find every source event.",
    );
  }
  for (const row of eventRows) {
    if (
      JSON.stringify(Object.keys(row.payload).sort()) !==
      JSON.stringify(expectedKeys)
    ) {
      throw new Error("A chat source event was not identifier-only.");
    }
  }
  const [columns] = await sql`
    select
      count(*) filter (
        where table_schema = 'public'
          and table_name = 'notifications'
          and column_name ilike '%body%'
      )::integer as notification_body_columns,
      count(*) filter (
        where table_schema = 'private'
          and table_name in (
            'push_delivery_jobs',
            'push_delivery_targets',
            'push_delivery_attempts'
          )
          and column_name ilike '%body%'
      )::integer as push_body_columns
    from information_schema.columns
  `;
  if (
    columns.notification_body_columns !== 0 ||
    columns.push_body_columns !== 0
  ) {
    throw new Error("Alert projection state exposed a message-body column.");
  }
}

async function assertReceiptsComplete(messages) {
  const messageIds = messages.map((message) => message.message_id);
  const [result] = await sql`
    select count(*)::integer as receipt_count
    from private.outbox_events as event
    join private.outbox_consumer_receipts as receipt
      on receipt.outbox_event_id = event.id
    where event.event_type = 'project.chat_message_sent'
      and event.payload ->> 'message_id' = any(${messageIds}::text[])
      and receipt.consumer_key in ('notifications.v1', 'push.v1')
  `;
  if (result.receipt_count !== messages.length * 2) {
    throw new Error(
      "A projected chat event lacked a complete consumer receipt set.",
    );
  }
}

async function setChatPreference(user, inAppEnabled, pushEnabled) {
  const { error } = await user.client.rpc("set_own_notification_preference", {
    p_expected_profile_id: user.id,
    p_category_slug: "chat",
    p_in_app_enabled: inAppEnabled,
    p_push_enabled: pushEnabled,
  });
  if (error) {
    throw safeDatabaseFailure("update chat notification channels", error);
  }
}

async function sendMessage(user, chatId, body) {
  const { data, error } = await user.client.rpc("send_project_chat_message", {
    p_expected_profile_id: user.id,
    p_chat_id: chatId,
    p_body: body,
  });
  if (error || data?.length !== 1) {
    throw safeDatabaseFailure("send a Project chat message", error ?? {});
  }
  return data[0];
}

async function getChat(user, projectId) {
  const { data, error } = await user.client.rpc("get_own_project_group_chat", {
    p_expected_profile_id: user.id,
    p_project_id: projectId,
  });
  if (error || data?.length !== 1) {
    throw safeDatabaseFailure("resolve the Project group chat", error ?? {});
  }
  return data[0];
}

async function joinProject(creator, participant, projectId) {
  const { data: requestId, error: requestError } = await participant.client.rpc(
    "request_to_join_project",
    {
      p_expected_requester_profile_id: participant.id,
      p_project_id: projectId,
      p_request_message: null,
    },
  );
  if (requestError || typeof requestId !== "string") {
    throw safeDatabaseFailure(
      "request Project participation",
      requestError ?? {},
    );
  }
  const { data: membershipId, error: acceptanceError } =
    await creator.client.rpc("accept_project_join_request", {
      p_expected_creator_profile_id: creator.id,
      p_request_id: requestId,
    });
  if (acceptanceError || typeof membershipId !== "string") {
    throw safeDatabaseFailure(
      "accept Project participation",
      acceptanceError ?? {},
    );
  }
  return membershipId;
}

async function leaveMembership(user, membershipId) {
  const { error } = await user.client.rpc("leave_project", {
    p_expected_participant_profile_id: user.id,
    p_membership_id: membershipId,
  });
  if (error) {
    throw safeDatabaseFailure("leave a Project membership", error);
  }
}

async function createProposal(creator) {
  const { data, error } = await creator.client.rpc("create_proposal_draft", {
    p_expected_creator_profile_id: creator.id,
    p_title: "Integration Project chat notifications",
    p_summary: "A deterministic Proposal for chat-alert verification.",
    p_description:
      "This Project verifies server-authorized notification fan-out.",
    p_starts_at: "2098-01-02T10:00:00.000Z",
    p_ends_at: "2098-01-02T14:00:00.000Z",
    p_event_timezone: "Europe/Rome",
    p_country_code: "IT",
    p_locality: "Trento",
    p_administrative_area: "Povo",
    p_public_location_label: "Trento · Povo",
    p_exact_meeting_text: "Private chat-alert Proposal location",
    p_exact_location_visibility: "participants",
    p_skill_ids: [],
    p_skill_importances: [],
  });
  if (error || typeof data !== "string") {
    throw safeDatabaseFailure("create a chat-alert Proposal", error ?? {});
  }
  const { error: publishError } = await creator.client.rpc("publish_proposal", {
    p_expected_creator_profile_id: creator.id,
    p_proposal_id: data,
  });
  if (publishError) {
    throw safeDatabaseFailure("publish a chat-alert Proposal", publishError);
  }
  return data;
}

async function createTavolo(creator) {
  const { data, error } = await creator.client.rpc(
    "create_recurring_activity_draft",
    {
      p_expected_creator_profile_id: creator.id,
      p_title: "Integration Project chat notification Tavolo",
      p_summary: "A deterministic Tavolo for chat-alert verification.",
      p_description:
        "This recurring Project verifies chat notification projection.",
      p_topic: "Community",
      p_country_code: "IT",
      p_locality: "Trento",
      p_administrative_area: "Povo",
      p_public_location_label: "Trento · Povo",
      p_exact_meeting_text: "Private chat-alert Tavolo location",
      p_exact_location_visibility: "participants",
      p_recurrence_type: "weekly",
      p_weekday: 4,
      p_day_of_month: null,
      p_local_start_time: "19:00:00",
      p_duration_minutes: 90,
      p_event_timezone: "Europe/Rome",
      p_effective_from: "2098-01-01",
    },
  );
  if (error || typeof data !== "string") {
    throw safeDatabaseFailure("create a chat-alert Tavolo", error ?? {});
  }
  const { error: publishError } = await creator.client.rpc(
    "publish_recurring_activity",
    {
      p_expected_creator_profile_id: creator.id,
      p_recurring_activity_id: data,
    },
  );
  if (publishError) {
    throw safeDatabaseFailure("publish a chat-alert Tavolo", publishError);
  }
  return data;
}

async function ensureCompleteProfile(user, displayName) {
  const { error: anchorError } = await user.client
    .from("profiles")
    .insert({ id: user.id });
  if (anchorError) {
    const diagnostic = `${anchorError.message ?? ""} ${anchorError.details ?? ""}`;
    if (anchorError.code !== "23505" || !diagnostic.includes("profiles_pkey")) {
      throw safeDatabaseFailure("create a chat-alert profile", anchorError);
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
    throw safeDatabaseFailure("complete a chat-alert profile", updateError);
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
    throw safeDatabaseFailure("request a local chat-alert OTP", requestError);
  }
  const messageId = await waitForNewMessage(
    email,
    existingMessageIds,
    requestStartedAt,
  );
  const message = await fetchJson(
    `${mailpitUrl}/api/v1/message/${encodeURIComponent(messageId)}`,
    {},
    "read a local chat-alert OTP email",
  );
  const messageBody = `${message.Text ?? ""} ${message.HTML ?? ""}`;
  const token = messageBody.match(/(?:^|\D)(\d{6})(?:\D|$)/)?.[1];
  if (!token) {
    throw new Error("A local chat-alert email lacked a 6-digit token.");
  }
  const { data: verification, error: verificationError } =
    await client.auth.verifyOtp({ email, token, type: "email" });
  if (verificationError || !verification.user?.id || !verification.session) {
    throw safeDatabaseFailure(
      "verify a local chat-alert OTP",
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
    if (message) return message.ID;
    await delay(250);
  }
  throw new Error(
    "Mailpit did not receive a chat-alert OTP within 15 seconds.",
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

function delay(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}
