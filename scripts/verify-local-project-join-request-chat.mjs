import postgres from "postgres";

import { signInLocalOtpUser } from "./lib/local-authenticated-user.mjs";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";

const repositoryRoot = process.cwd();
const mailpitUrl = (
  process.env.MAILPIT_URL ?? "http://127.0.0.1:54324"
).replace(/\/$/, "");
const { apiUrl, publishableKey, databaseUrl } =
  readLocalSupabaseStatus(repositoryRoot);

if (!databaseUrl) {
  throw new Error(
    "Local Supabase status is missing its database URL. Update the project-scoped CLI if the status format has changed.",
  );
}

const sql = postgres(databaseUrl, { max: 6 });
const openedChannels = [];

try {
  await verifyProjectJoinRequestChat();
} finally {
  await Promise.allSettled(
    openedChannels.map(({ client, channel }) => client.removeChannel(channel)),
  );
  await sql.end();
}

async function verifyProjectJoinRequestChat() {
  const [creator, requester, unrelated] = await Promise.all([
    signInWithLocalOtp("request-chat-creator@planets.invalid"),
    signInWithLocalOtp("request-chat-requester@planets.invalid"),
    signInWithLocalOtp("request-chat-unrelated@planets.invalid"),
  ]);
  await Promise.all([
    ensureCompleteProfile(creator, "Request Chat Creator"),
    ensureCompleteProfile(requester, "Request Chat Requester"),
    ensureCompleteProfile(unrelated, "Request Chat Unrelated"),
  ]);

  const projectId = await createProposal(creator);
  const requestId = await requestParticipation(
    requester,
    projectId,
    "A private request note, represented structurally.",
  );
  const requesterExact = await getExactChat(requester, requestId);
  assertExactPending(requesterExact, requester, creator, projectId);
  await assertStructuredRequestStillVisible(requester, requestId);

  const initialFeed = await listFeed(requester, requesterExact.chat_id, 20);
  if (
    initialFeed.length !== 1 ||
    initialFeed[0].item_kind !== "request" ||
    initialFeed[0].request_message !==
      "A private request note, represented structurally." ||
    initialFeed[0].message_id !== null ||
    initialFeed[0].body !== null
  ) {
    throw new Error(
      "The canonical request note was not represented as exactly one structured feed item.",
    );
  }

  await assertUnavailable(unrelated, requestId, requesterExact.chat_id);

  const creatorSignals = await subscribeToChat(creator, requesterExact.chat_id);
  const requesterSignals = await subscribeToChat(
    requester,
    requesterExact.chat_id,
  );
  await assertSubscriptionDenied(unrelated, requesterExact.chat_id);

  const requesterMessage = await sendMessage(
    requester,
    requesterExact.chat_id,
    "  Requester follow-up  ",
  );
  assertCanonicalMessage(requesterMessage, requester.id, "Requester follow-up");
  await assertSignal(creatorSignals, requesterMessage, requesterExact.chat_id);

  const creatorMessage = await sendMessage(
    creator,
    requesterExact.chat_id,
    "Creator follow-up",
  );
  await assertSignal(requesterSignals, creatorMessage, requesterExact.chat_id);
  await assertIdentifierOnlyDurableEvents([
    requesterMessage.message_id,
    creatorMessage.message_id,
  ]);
  await assertIdentifierOnlyRealtimeRows(
    [requesterMessage.message_id, creatorMessage.message_id],
    4,
  );

  const mixedFeed = await listFeed(requester, requesterExact.chat_id, 20);
  assertStrictFeed(mixedFeed, requestId);
  await assertKeysetContinuation(requester, requesterExact.chat_id, mixedFeed);

  let blockedSend;
  let membershipId;
  await sql.begin(async (transaction) => {
    await setAuthenticatedTransaction(transaction, creator.id);
    const rows = await transaction`
      select public.accept_project_join_request(
        ${creator.id}::uuid,
        ${requestId}::uuid
      ) as membership_id
    `;
    membershipId = rows[0]?.membership_id;
    blockedSend = requester.client.rpc(
      "send_project_join_request_chat_message",
      {
        p_expected_profile_id: requester.id,
        p_chat_id: requesterExact.chat_id,
        p_body: "This send waits behind acceptance and must fail",
      },
    );
    await delay(250);
  });

  const blockedResult = await blockedSend;
  if (blockedResult.error?.code !== "PT409" || blockedResult.data !== null) {
    throw new Error(
      "A request-chat send waiting behind acceptance did not fail read-only.",
    );
  }
  if (typeof membershipId !== "string") {
    throw new Error("Acceptance did not create a canonical membership.");
  }

  const resolvedExact = await getExactChat(requester, requestId);
  if (
    resolvedExact.request_status !== "accepted" ||
    resolvedExact.is_read_only !== true ||
    resolvedExact.has_send_entitlement !== false ||
    typeof resolvedExact.accepted_project_group_chat_id !== "string"
  ) {
    throw new Error(
      "Accepted request-chat state did not expose read-only history and the separate Project group chat.",
    );
  }
  const groupChat = await getGroupChat(requester, projectId);
  if (groupChat.chat_id !== resolvedExact.accepted_project_group_chat_id) {
    throw new Error(
      "The accepted request chat did not link to the canonical Project group chat.",
    );
  }

  const resolvedFeed = await listFeed(creator, requesterExact.chat_id, 20);
  assertStrictFeed(resolvedFeed, requestId);
  await assertStructuredRequestStillVisible(creator, requestId);

  console.log(
    "Confirmed atomic request-chat creation, structured note/feed semantics, counterparty-only exact/history access, private identifier-only Realtime, immutable durable messaging, keyset paging, send/accept serialization, resolved read-only history, and accepted Project-chat continuation.",
  );
}

function assertExactPending(exact, requester, creator, projectId) {
  const expectedKeys = [
    "accepted_project_group_chat_id",
    "activated_at",
    "chat_id",
    "creator_display_name",
    "creator_profile_id",
    "has_send_entitlement",
    "is_read_only",
    "project_id",
    "project_kind",
    "project_title",
    "request_created_at",
    "request_id",
    "request_message",
    "request_status",
    "requester_display_name",
    "requester_profile_id",
    "resolved_at",
    "viewer_role",
  ];
  if (
    JSON.stringify(Object.keys(exact).sort()) !==
      JSON.stringify(expectedKeys) ||
    exact.project_id !== projectId ||
    exact.project_kind !== "one_time" ||
    exact.viewer_role !== "requester" ||
    exact.requester_profile_id !== requester.id ||
    exact.creator_profile_id !== creator.id ||
    exact.request_status !== "pending" ||
    exact.request_created_at !== exact.activated_at ||
    exact.is_read_only !== false ||
    exact.has_send_entitlement !== true ||
    exact.accepted_project_group_chat_id !== null
  ) {
    throw new Error(
      "The exact pending request-chat contract was not canonical.",
    );
  }
}

function assertStrictFeed(items, requestId) {
  const requestItems = items.filter((item) => item.item_kind === "request");
  const messages = items.filter((item) => item.item_kind === "message");
  if (requestItems.length !== 1 || messages.length !== 2) {
    throw new Error(
      "The mixed request-chat feed had an unexpected item count.",
    );
  }
  const request = requestItems[0];
  if (
    request.item_id !== requestId ||
    request.message_id !== null ||
    request.sender_profile_id !== null ||
    request.sender_display_name !== null ||
    request.body !== null ||
    request.project_id === null ||
    request.request_status === null
  ) {
    throw new Error("The feed Request discriminator was not strict.");
  }
  if (
    messages.some(
      (message) =>
        message.item_id !== message.message_id ||
        message.sender_profile_id === null ||
        message.sender_display_name === null ||
        message.body === null ||
        message.project_id !== null ||
        message.project_kind !== null ||
        message.project_title !== null ||
        message.request_status !== null ||
        message.request_message !== null ||
        message.requester_profile_id !== null ||
        message.requester_display_name !== null,
    )
  ) {
    throw new Error(
      "A feed Message discriminator exposed Request-only fields.",
    );
  }
}

async function assertKeysetContinuation(user, chatId, completeFeed) {
  const firstPage = await listFeed(user, chatId, 1);
  const boundary = firstPage[0];
  const laterPage = await listFeed(user, chatId, 20, boundary);
  if (
    laterPage.length !== completeFeed.length - 1 ||
    laterPage.some((item) => item.item_id === boundary.item_id)
  ) {
    throw new Error(
      "Request-chat keyset pagination repeated or skipped items.",
    );
  }
}

async function assertStructuredRequestStillVisible(user, requestId) {
  const { data, error } = await user.client.rpc(
    "list_own_structured_request_message_items",
    {
      p_expected_profile_id: user.id,
      p_limit: 50,
      p_cursor_activity_at: null,
      p_cursor_item_kind: null,
      p_cursor_request_id: null,
    },
  );
  if (
    error ||
    !Array.isArray(data) ||
    !data.some(
      (item) =>
        item.item_kind === "participation_request" &&
        item.request_id === requestId,
    )
  ) {
    throw safeDatabaseFailure(
      "retain the structured Requests projection",
      error ?? {},
    );
  }
}

async function assertUnavailable(user, requestId, chatId) {
  const exact = await user.client.rpc("get_own_project_join_request_chat", {
    p_expected_profile_id: user.id,
    p_request_id: requestId,
  });
  const feed = await user.client.rpc(
    "list_own_project_join_request_chat_items",
    {
      p_expected_profile_id: user.id,
      p_chat_id: chatId,
      p_limit: 20,
      p_before_created_at: null,
      p_before_item_kind: null,
      p_before_item_id: null,
    },
  );
  const send = await user.client.rpc("send_project_join_request_chat_message", {
    p_expected_profile_id: user.id,
    p_chat_id: chatId,
    p_body: "Forbidden",
  });
  if (
    exact.error?.code !== "42501" ||
    feed.error?.code !== "42501" ||
    send.error?.code !== "42501" ||
    exact.data !== null ||
    feed.data !== null ||
    send.data !== null
  ) {
    throw new Error("An unrelated profile received request-chat access.");
  }
}

async function subscribeToChat(user, chatId) {
  const signals = [];
  const channel = user.client.channel(requestChatTopic(chatId, user.id), {
    config: { private: true },
  });
  signals.channel = channel;
  channel.on(
    "broadcast",
    { event: "project.join_request_chat_message_sent" },
    (event) => signals.push(event.payload ?? event),
  );
  openedChannels.push({ client: user.client, channel });
  await waitForSubscription(channel, true);
  return signals;
}

async function assertSubscriptionDenied(user, chatId) {
  const channel = user.client.channel(requestChatTopic(chatId, user.id), {
    config: { private: true },
  });
  openedChannels.push({ client: user.client, channel });
  await waitForSubscription(channel, false);
}

function waitForSubscription(channel, shouldSucceed) {
  return new Promise((resolve, reject) => {
    const timeout = setTimeout(() => {
      reject(
        new Error(
          shouldSucceed
            ? "An authorized request-chat subscription timed out."
            : "An unauthorized request-chat subscription did not fail.",
        ),
      );
    }, 10_000);
    channel.subscribe((status) => {
      if (status === "SUBSCRIBED") {
        clearTimeout(timeout);
        if (shouldSucceed) {
          resolve();
        } else {
          reject(
            new Error("An unrelated profile subscribed to a request chat."),
          );
        }
      } else if (["CHANNEL_ERROR", "TIMED_OUT", "CLOSED"].includes(status)) {
        clearTimeout(timeout);
        if (shouldSucceed) {
          reject(new Error("An authorized request-chat subscription failed."));
        } else {
          resolve();
        }
      }
    });
  });
}

async function assertSignal(signals, message, chatId) {
  const deadline = Date.now() + 5_000;
  while (Date.now() < deadline) {
    const signal = signals.find(
      (candidate) => candidate.message_id === message.message_id,
    );
    if (signal) {
      const expectedKeys = [
        "chat_id",
        "created_at",
        "id",
        "message_id",
        "request_id",
      ];
      if (
        signal.chat_id !== chatId ||
        signal.created_at !== message.created_at ||
        typeof signal.id !== "string" ||
        JSON.stringify(Object.keys(signal).sort()) !==
          JSON.stringify(expectedKeys)
      ) {
        throw new Error("Realtime returned a non-canonical request-chat hint.");
      }
      return;
    }
    await delay(25);
  }
  throw new Error("An authorized client did not receive a request-chat hint.");
}

async function assertIdentifierOnlyDurableEvents(messageIds) {
  const rows = await sql`
    select payload
    from private.outbox_events
    where event_type = 'project.join_request_chat_message_sent'
      and payload ->> 'message_id' = any(${messageIds})
  `;
  const expectedKeys = [
    "chat_id",
    "message_id",
    "project_id",
    "project_kind",
    "request_id",
    "sender_profile_id",
  ];
  if (
    rows.length !== messageIds.length ||
    rows.some(
      ({ payload }) =>
        JSON.stringify(Object.keys(payload).sort()) !==
        JSON.stringify(expectedKeys),
    )
  ) {
    throw new Error("A durable request-chat event was not identifier-only.");
  }
}

async function assertIdentifierOnlyRealtimeRows(messageIds, expectedCount) {
  const rows = await sql`
    select payload
    from realtime.messages
    where extension = 'broadcast'
      and event = 'project.join_request_chat_message_sent'
      and payload ->> 'message_id' = any(${messageIds})
  `;
  const expectedKeys = [
    "chat_id",
    "created_at",
    "id",
    "message_id",
    "request_id",
  ];
  if (
    rows.length !== expectedCount ||
    rows.some(
      ({ payload }) =>
        JSON.stringify(Object.keys(payload).sort()) !==
        JSON.stringify(expectedKeys),
    )
  ) {
    throw new Error("A persisted request-chat Realtime hint was unsafe.");
  }
}

async function requestParticipation(user, projectId, note) {
  const { data, error } = await user.client.rpc("request_to_join_project", {
    p_expected_requester_profile_id: user.id,
    p_project_id: projectId,
    p_request_message: note,
    p_skill_ids: [],
    p_resource_need_ids: [],
  });
  if (error || typeof data !== "string") {
    throw safeDatabaseFailure("create a participation request", error ?? {});
  }
  return data;
}

async function getExactChat(user, requestId) {
  const { data, error } = await user.client.rpc(
    "get_own_project_join_request_chat",
    {
      p_expected_profile_id: user.id,
      p_request_id: requestId,
    },
  );
  if (error || data?.length !== 1) {
    throw safeDatabaseFailure(
      "resolve a participation-request chat",
      error ?? {},
    );
  }
  return data[0];
}

async function listFeed(user, chatId, limit, cursor = null) {
  const { data, error } = await user.client.rpc(
    "list_own_project_join_request_chat_items",
    {
      p_expected_profile_id: user.id,
      p_chat_id: chatId,
      p_limit: limit,
      p_before_created_at: cursor?.created_at ?? null,
      p_before_item_kind: cursor?.item_kind ?? null,
      p_before_item_id: cursor?.item_id ?? null,
    },
  );
  if (error || !Array.isArray(data)) {
    throw safeDatabaseFailure("list a participation-request chat", error ?? {});
  }
  return data;
}

async function sendMessage(user, chatId, body) {
  const { data, error } = await user.client.rpc(
    "send_project_join_request_chat_message",
    {
      p_expected_profile_id: user.id,
      p_chat_id: chatId,
      p_body: body,
    },
  );
  if (error || data?.length !== 1) {
    throw safeDatabaseFailure(
      "send a participation-request chat message",
      error ?? {},
    );
  }
  return data[0];
}

function assertCanonicalMessage(message, senderId, body) {
  const expectedKeys = [
    "body",
    "chat_id",
    "created_at",
    "message_id",
    "sender_profile_id",
  ];
  if (
    JSON.stringify(Object.keys(message).sort()) !==
      JSON.stringify(expectedKeys) ||
    message.sender_profile_id !== senderId ||
    message.body !== body
  ) {
    throw new Error("Send returned a non-canonical request-chat message.");
  }
}

async function getGroupChat(user, projectId) {
  const { data, error } = await user.client.rpc("get_own_project_group_chat", {
    p_expected_profile_id: user.id,
    p_project_id: projectId,
  });
  if (error || data?.length !== 1) {
    throw safeDatabaseFailure("resolve the accepted Project chat", error ?? {});
  }
  return data[0];
}

async function createProposal(creator) {
  const { data, error } = await creator.client.rpc("create_proposal_draft", {
    p_expected_creator_profile_id: creator.id,
    p_title: "Integration participation-request chat",
    p_summary: "A deterministic Proposal for request-chat verification.",
    p_description:
      "This Project verifies the private conversation for one participation request.",
    p_starts_at: "2098-01-02T10:00:00.000Z",
    p_ends_at: "2098-01-02T14:00:00.000Z",
    p_event_timezone: "Europe/Rome",
    p_country_code: "IT",
    p_locality: "Trento",
    p_administrative_area: "Povo",
    p_public_location_label: "Trento · Povo",
    p_exact_meeting_text: "Private request-chat verification location",
    p_exact_location_visibility: "participants",
    p_skill_ids: [],
    p_skill_importances: [],
  });
  if (error || typeof data !== "string") {
    throw safeDatabaseFailure("create a request-chat Proposal", error ?? {});
  }
  const { error: publishError } = await creator.client.rpc("publish_proposal", {
    p_expected_creator_profile_id: creator.id,
    p_proposal_id: data,
  });
  if (publishError) {
    throw safeDatabaseFailure("publish a request-chat Proposal", publishError);
  }
  return data;
}

async function setAuthenticatedTransaction(transaction, profileId) {
  await transaction`set local role authenticated`;
  await transaction`
    select set_config('request.jwt.claim.sub', ${profileId}, true)
  `;
}

async function ensureCompleteProfile(user, displayName) {
  const { error: anchorError } = await user.client
    .from("profiles")
    .insert({ id: user.id });
  if (anchorError) {
    const diagnostic = `${anchorError.message ?? ""} ${anchorError.details ?? ""}`;
    if (anchorError.code !== "23505" || !diagnostic.includes("profiles_pkey")) {
      throw safeDatabaseFailure("create a request-chat profile", anchorError);
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
    throw safeDatabaseFailure("complete a request-chat profile", updateError);
  }
}

function requestChatTopic(chatId, profileId) {
  return `project-request-chat:${chatId}:profile:${profileId}`;
}

function signInWithLocalOtp(email) {
  return signInLocalOtpUser({
    apiUrl,
    publishableKey,
    mailpitUrl,
    email,
    verifierName: "project-join-request-chat",
  });
}

function safeDatabaseFailure(action, error) {
  const code =
    typeof error?.code === "string" && /^[a-z0-9_]+$/iu.test(error.code)
      ? error.code
      : "unknown";
  return new Error(`Failed to ${action} (code ${code}).`);
}

function delay(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}
