import postgres from "postgres";

import { signInLocalOtpUser } from "./lib/local-authenticated-user.mjs";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";
import { ensureLocalProfilePhoto } from "./lib/local-profile-photo.mjs";

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
  await verifyProjectChatMessages();
} finally {
  await Promise.allSettled(
    openedChannels.map(({ client, channel }) => client.removeChannel(channel)),
  );
  await sql.end();
}

async function verifyProjectChatMessages() {
  const [creator, participantA, participantB, unrelated] = await Promise.all([
    signInWithLocalOtp("chat-messages-creator@planets.invalid"),
    signInWithLocalOtp("chat-messages-a@planets.invalid"),
    signInWithLocalOtp("chat-messages-b@planets.invalid"),
    signInWithLocalOtp("chat-messages-unrelated@planets.invalid"),
  ]);
  await Promise.all([
    ensureCompleteProfile(creator, "Chat Messages Creator"),
    ensureCompleteProfile(participantA, "Chat Messages A"),
    ensureCompleteProfile(participantB, "Chat Messages B"),
    ensureCompleteProfile(unrelated, "Chat Messages Unrelated"),
  ]);
  await Promise.all(
    [creator, participantA, participantB, unrelated].map((user) =>
      ensureLocalProfilePhoto(user),
    ),
  );

  const proposalId = await createProposal(
    creator,
    "Integration Project chat messages",
  );
  const membershipA = await joinProject(creator, participantA, proposalId);
  const chat = await getChat(creator, proposalId);

  const creatorSignals = await subscribeToChat(creator, chat.chat_id);
  const participantASignals = await subscribeToChat(participantA, chat.chat_id);
  await assertSubscriptionDenied(unrelated, chat.chat_id);

  const message1 = await sendMessage(
    creator,
    chat.chat_id,
    "  First durable Proposal message  ",
  );
  assertCanonicalMessage(
    message1,
    creator.id,
    "First durable Proposal message",
  );
  await assertSignal(participantASignals, message1, chat.chat_id);
  await assertIdentifierOnlyRealtimeRows(message1, 2);
  await assertDurableMessage(message1);
  await assertHistoryContains(participantA, chat.chat_id, [
    message1.message_id,
  ]);

  const membershipBOne = await joinProject(creator, participantB, proposalId);
  const participantBSignals = await subscribeToChat(participantB, chat.chat_id);
  await assertHistoryContains(participantB, chat.chat_id, [
    message1.message_id,
  ]);

  const message2 = await sendMessage(
    participantA,
    chat.chat_id,
    "Participant A Proposal message",
  );
  await assertSignal(participantBSignals, message2, chat.chat_id);
  await assertHistoryContains(participantB, chat.chat_id, [
    message1.message_id,
    message2.message_id,
  ]);

  await leaveMembership(participantB, membershipBOne);
  const formerBeforeGap = await getChatSummary(participantB, chat.chat_id);
  if (
    formerBeforeGap.viewer_role !== "former_member" ||
    formerBeforeGap.last_visible_message_id !== message2.message_id
  ) {
    throw new Error(
      "Leave did not establish the expected visible history frontier.",
    );
  }

  const formerSignalCount = participantBSignals.length;
  const message3 = await sendMessage(
    creator,
    chat.chat_id,
    "Proposal gap message",
  );
  await assertSignal(creatorSignals, message3, chat.chat_id);
  await assertNoNewSignal(participantBSignals, formerSignalCount);
  await assertHistoryExcludes(participantB, chat.chat_id, [
    message3.message_id,
  ]);
  const formerAfterGap = await getChatSummary(participantB, chat.chat_id);
  if (
    formerAfterGap.last_visible_message_id !== message2.message_id ||
    formerAfterGap.activity_at !== formerBeforeGap.activity_at
  ) {
    throw new Error(
      "An inaccessible message changed the former member preview or activity.",
    );
  }
  await closeSubscription(participantB, participantBSignals.channel);
  await assertSubscriptionDenied(participantB, chat.chat_id);

  const membershipBTwo = await joinProject(creator, participantB, proposalId);
  const rejoinedBSignals = await subscribeToChat(participantB, chat.chat_id);
  await assertHistoryContains(participantB, chat.chat_id, [
    message1.message_id,
    message2.message_id,
    message3.message_id,
  ]);
  const message4 = await sendMessage(
    participantB,
    chat.chat_id,
    "Rejoined Proposal participant message",
  );
  await assertSignal(creatorSignals, message4, chat.chat_id);

  await removeMembership(creator, membershipBTwo);
  const removedSignalCount = rejoinedBSignals.length;
  const message5 = await sendMessage(
    creator,
    chat.chat_id,
    "Proposal message after removal",
  );
  await assertNoNewSignal(rejoinedBSignals, removedSignalCount);
  await assertHistoryContains(participantB, chat.chat_id, [
    message1.message_id,
    message2.message_id,
    message3.message_id,
    message4.message_id,
  ]);
  await assertHistoryExcludes(participantB, chat.chat_id, [
    message5.message_id,
  ]);
  const removedSummary = await getChatSummary(participantB, chat.chat_id);
  if (removedSummary.last_visible_message_id !== message4.message_id) {
    throw new Error("Removal exposed an unauthorized later preview.");
  }

  await assertChatUnavailable(unrelated, chat.chat_id);
  const unrelatedChats = await listChats(unrelated);
  if (unrelatedChats.some((item) => item.chat_id === chat.chat_id)) {
    throw new Error("An unrelated profile received Project chat-list access.");
  }

  const tavoloId = await createTavolo(creator);
  await joinProject(creator, participantA, tavoloId);
  const tavoloChat = await getChat(creator, tavoloId);
  const tavoloCreatorSignals = await subscribeToChat(
    creator,
    tavoloChat.chat_id,
  );
  const tavoloMessage = await sendMessage(
    participantA,
    tavoloChat.chat_id,
    "Durable Tavolo message",
  );
  await assertSignal(tavoloCreatorSignals, tavoloMessage, tavoloChat.chat_id);
  await assertHistoryContains(creator, tavoloChat.chat_id, [
    tavoloMessage.message_id,
  ]);
  await transitionTavolo(creator, "end_recurring_activity", tavoloId);
  await sendMessage(
    participantA,
    tavoloChat.chat_id,
    "Ended Tavolo remains available to current participants",
  );

  await verifySendTransitionConcurrency(creator, participantA);
  await assertIdentifierOnlyOutbox([
    "First durable Proposal message",
    "Proposal gap message",
    "Durable Tavolo message",
  ]);

  if (!membershipA) {
    throw new Error("Proposal participant membership was not retained.");
  }

  console.log(
    "Confirmed durable Proposal/Tavolo chat messages, full history on join, former-member frontiers, rejoin history, private Realtime signals, revocation, identifier-only outbox data, and send/transition serialization.",
  );
}

async function verifySendTransitionConcurrency(creator, participant) {
  const projectId = await createProposal(
    creator,
    "Integration Project chat send race",
  );
  let membershipId = await joinProject(creator, participant, projectId);
  const chat = await getChat(creator, projectId);

  let blockedSend;
  await sql.begin(async (transaction) => {
    await setAuthenticatedTransaction(transaction, participant.id);
    await transaction`
      select public.leave_project(${participant.id}::uuid, ${membershipId}::uuid)
    `;
    blockedSend = participant.client.rpc("send_project_chat_message", {
      p_expected_profile_id: participant.id,
      p_chat_id: chat.chat_id,
      p_body: "This post-leave race message must fail",
    });
    await delay(250);
  });
  const blockedResult = await blockedSend;
  if (blockedResult.error?.code !== "42501" || blockedResult.data !== null) {
    throw new Error("A send waiting behind leave did not fail closed.");
  }

  membershipId = await joinProject(creator, participant, projectId);
  let pendingRemoval;
  let committedMessageId;
  await sql.begin(async (transaction) => {
    await setAuthenticatedTransaction(transaction, participant.id);
    const rows = await transaction`
      select message_id
      from public.send_project_chat_message(
        ${participant.id}::uuid,
        ${chat.chat_id}::uuid,
        'Serialized before removal'
      )
    `;
    committedMessageId = rows[0]?.message_id;
    pendingRemoval = creator.client.rpc("remove_project_member", {
      p_expected_creator_profile_id: creator.id,
      p_membership_id: membershipId,
    });
    await delay(250);
  });
  const removalResult = await pendingRemoval;
  if (removalResult.error || typeof removalResult.data !== "string") {
    throw safeDatabaseFailure(
      "complete a removal waiting behind send",
      removalResult.error ?? {},
    );
  }
  if (typeof committedMessageId !== "string") {
    throw new Error("The send-first race did not commit its durable message.");
  }
  await assertHistoryContains(participant, chat.chat_id, [committedMessageId]);
}

async function setAuthenticatedTransaction(transaction, profileId) {
  await transaction`set local role authenticated`;
  await transaction`
    select set_config('request.jwt.claim.sub', ${profileId}, true)
  `;
}

async function subscribeToChat(user, chatId) {
  const signals = [];
  const channel = user.client.channel(projectChatTopic(chatId, user.id), {
    config: { private: true },
  });
  signals.channel = channel;
  channel.on("broadcast", { event: "project.chat_message_sent" }, (event) =>
    signals.push(event.payload ?? event),
  );
  openedChannels.push({ client: user.client, channel });
  await waitForSubscription(channel, true);
  return signals;
}

async function assertSubscriptionDenied(user, chatId) {
  const channel = user.client.channel(projectChatTopic(chatId, user.id), {
    config: { private: true },
  });
  openedChannels.push({ client: user.client, channel });
  await waitForSubscription(channel, false);
  await closeSubscription(user, channel);
}

function waitForSubscription(channel, shouldSucceed) {
  return new Promise((resolve, reject) => {
    const timeout = setTimeout(() => {
      reject(
        new Error(
          shouldSucceed
            ? "An authorized private Realtime subscription timed out."
            : "An unauthorized private Realtime subscription did not fail.",
        ),
      );
    }, 10_000);
    channel.subscribe((status) => {
      if (status === "SUBSCRIBED") {
        clearTimeout(timeout);
        if (shouldSucceed) {
          resolve();
        } else {
          reject(new Error("An unauthorized profile subscribed to a chat."));
        }
      } else if (
        status === "CHANNEL_ERROR" ||
        status === "TIMED_OUT" ||
        status === "CLOSED"
      ) {
        clearTimeout(timeout);
        if (shouldSucceed) {
          reject(new Error("An authorized private chat subscription failed."));
        } else {
          resolve();
        }
      }
    });
  });
}

async function closeSubscription(user, channel) {
  await user.client.removeChannel(channel);
  const index = openedChannels.findIndex((entry) => entry.channel === channel);
  if (index >= 0) {
    openedChannels.splice(index, 1);
  }
}

async function assertSignal(signals, message, chatId) {
  const deadline = Date.now() + 5_000;
  while (Date.now() < deadline) {
    const signal = signals.find(
      (candidate) => candidate.message_id === message.message_id,
    );
    if (signal) {
      const keys = Object.keys(signal).sort();
      const expectedKeys = ["chat_id", "created_at", "id", "message_id"];
      if (
        signal.chat_id !== chatId ||
        signal.created_at !== message.created_at ||
        typeof signal.id !== "string" ||
        JSON.stringify(keys) !== JSON.stringify(expectedKeys)
      ) {
        throw new Error(
          `Realtime exposed a non-canonical or unsafe signal (${JSON.stringify({
            keys,
            chatIdMatches: signal.chat_id === chatId,
            valueTypes: Object.fromEntries(
              keys.map((key) => [key, typeof signal[key]]),
            ),
          })}).`,
        );
      }
      return;
    }
    await delay(25);
  }
  throw new Error("An authorized client did not receive the message signal.");
}

async function assertIdentifierOnlyRealtimeRows(message, expectedRecipients) {
  const rows = await sql`
    select payload
    from realtime.messages
    where extension = 'broadcast'
      and event = 'project.chat_message_sent'
      and payload ->> 'message_id' = ${message.message_id}
  `;
  const expectedKeys = ["chat_id", "created_at", "id", "message_id"];
  if (rows.length !== expectedRecipients) {
    throw new Error("Realtime fan-out did not address every entitled profile.");
  }
  for (const row of rows) {
    if (
      typeof row.payload.id !== "string" ||
      JSON.stringify(Object.keys(row.payload).sort()) !==
        JSON.stringify(expectedKeys)
    ) {
      throw new Error("A persisted Realtime payload was not identifier-only.");
    }
  }
}

async function assertNoNewSignal(signals, startingCount) {
  await delay(750);
  if (signals.length !== startingCount) {
    throw new Error("A former participant received a new live chat signal.");
  }
}

function projectChatTopic(chatId, profileId) {
  return `project-chat:${chatId}:profile:${profileId}`;
}

async function assertDurableMessage(message) {
  const rows = await sql`
    select id, chat_id, sender_profile_id, body, created_at
    from public.project_chat_messages
    where id = ${message.message_id}
  `;
  if (
    rows.length !== 1 ||
    rows[0].chat_id !== message.chat_id ||
    rows[0].sender_profile_id !== message.sender_profile_id ||
    rows[0].body !== message.body
  ) {
    throw new Error("The Realtime signal did not correspond to a durable row.");
  }
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
    throw new Error("Send returned a non-canonical message contract.");
  }
}

async function assertHistoryContains(user, chatId, messageIds) {
  const messages = await listHistory(user, chatId);
  const actualIds = new Set(messages.map((message) => message.message_id));
  if (messageIds.some((messageId) => !actualIds.has(messageId))) {
    throw new Error("Authorized durable history was incomplete.");
  }
}

async function assertHistoryExcludes(user, chatId, messageIds) {
  const messages = await listHistory(user, chatId);
  const actualIds = new Set(messages.map((message) => message.message_id));
  if (messageIds.some((messageId) => actualIds.has(messageId))) {
    throw new Error("Durable history exposed a message beyond the frontier.");
  }
}

async function listHistory(user, chatId) {
  const { data, error } = await user.client.rpc(
    "list_own_project_chat_messages",
    {
      p_expected_profile_id: user.id,
      p_chat_id: chatId,
      p_limit: 50,
      p_before_created_at: null,
      p_before_message_id: null,
    },
  );
  if (error || !Array.isArray(data)) {
    throw safeDatabaseFailure("list durable Project chat history", error ?? {});
  }
  return data;
}

async function listChats(user) {
  const { data, error } = await user.client.rpc(
    "list_own_project_group_chats",
    {
      p_expected_profile_id: user.id,
      p_limit: 50,
      p_before_activity_at: null,
      p_before_chat_id: null,
    },
  );
  if (error || !Array.isArray(data)) {
    throw safeDatabaseFailure("list accessible Project chats", error ?? {});
  }
  return data;
}

async function getChatSummary(user, chatId) {
  const chats = await listChats(user);
  const chat = chats.find((candidate) => candidate.chat_id === chatId);
  if (!chat) {
    throw new Error("An accessible chat was absent from the chat list.");
  }
  return chat;
}

async function assertChatUnavailable(user, chatId) {
  const { data, error } = await user.client.rpc(
    "list_own_project_chat_messages",
    {
      p_expected_profile_id: user.id,
      p_chat_id: chatId,
      p_limit: 20,
      p_before_created_at: null,
      p_before_message_id: null,
    },
  );
  if (error?.code !== "42501" || data !== null) {
    throw new Error("An unrelated profile received durable chat history.");
  }
}

async function sendMessage(user, chatId, body) {
  const { data, error } = await user.client.rpc("send_project_chat_message", {
    p_expected_profile_id: user.id,
    p_chat_id: chatId,
    p_body: body,
  });
  if (error || data?.length !== 1) {
    throw safeDatabaseFailure(
      "send a durable Project chat message",
      error ?? {},
    );
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

async function removeMembership(creator, membershipId) {
  const { error } = await creator.client.rpc("remove_project_member", {
    p_expected_creator_profile_id: creator.id,
    p_membership_id: membershipId,
  });
  if (error) {
    throw safeDatabaseFailure("remove a Project membership", error);
  }
}

async function createProposal(creator, title) {
  const { data, error } = await creator.client.rpc("create_proposal_draft", {
    p_expected_creator_profile_id: creator.id,
    p_title: title,
    p_summary: "A deterministic Proposal for message-domain verification.",
    p_description:
      "This Project verifies durable server-authorized group chat messages.",
    p_starts_at: "2098-01-02T10:00:00.000Z",
    p_ends_at: "2098-01-02T14:00:00.000Z",
    p_event_timezone: "Europe/Rome",
    p_country_code: "IT",
    p_locality: "Trento",
    p_administrative_area: "Povo",
    p_public_location_label: "Trento · Povo",
    p_exact_meeting_text: "Private message-domain meeting location",
    p_exact_location_visibility: "participants",
    p_skill_ids: [],
    p_skill_importances: [],
    p_people_capacity: 20,
  });
  if (error || typeof data !== "string") {
    throw safeDatabaseFailure("create a message-domain Proposal", error ?? {});
  }
  const { error: publishError } = await creator.client.rpc("publish_proposal", {
    p_expected_creator_profile_id: creator.id,
    p_proposal_id: data,
  });
  if (publishError) {
    throw safeDatabaseFailure(
      "publish a message-domain Proposal",
      publishError,
    );
  }
  return data;
}

async function createTavolo(creator) {
  const { data, error } = await creator.client.rpc(
    "create_recurring_activity_draft",
    {
      p_expected_creator_profile_id: creator.id,
      p_title: "Integration Project chat message Tavolo",
      p_summary: "A deterministic Tavolo for message-domain verification.",
      p_description:
        "This recurring Project verifies durable group chat transport.",
      p_topic: "Community",
      p_country_code: "IT",
      p_locality: "Trento",
      p_administrative_area: "Povo",
      p_public_location_label: "Trento · Povo",
      p_exact_meeting_text: "Private Tavolo message-domain location",
      p_exact_location_visibility: "participants",
      p_recurrence_type: "weekly",
      p_weekday: 4,
      p_day_of_month: null,
      p_local_start_time: "19:00:00",
      p_duration_minutes: 90,
      p_event_timezone: "Europe/Rome",
      p_effective_from: "2098-01-01",
      p_people_capacity: 20,
    },
  );
  if (error || typeof data !== "string") {
    throw safeDatabaseFailure("create a message-domain Tavolo", error ?? {});
  }
  await transitionTavolo(creator, "publish_recurring_activity", data);
  return data;
}

async function transitionTavolo(creator, operation, tavoloId) {
  const { error } = await creator.client.rpc(operation, {
    p_expected_creator_profile_id: creator.id,
    p_recurring_activity_id: tavoloId,
  });
  if (error) {
    throw safeDatabaseFailure(operation.replaceAll("_", " "), error);
  }
}

async function assertIdentifierOnlyOutbox(forbiddenBodies) {
  const rows = await sql`
    select event_type, payload
    from private.outbox_events
    where event_type = 'project.chat_message_sent'
  `;
  if (rows.length === 0) {
    throw new Error("No chat-message outbox events were recorded.");
  }
  const expectedKeys = [
    "chat_id",
    "message_id",
    "project_id",
    "project_kind",
    "sender_profile_id",
  ];
  for (const row of rows) {
    if (
      JSON.stringify(Object.keys(row.payload).sort()) !==
      JSON.stringify(expectedKeys)
    ) {
      throw new Error("A chat-message outbox event exposed unsafe context.");
    }
    const serialized = JSON.stringify(row.payload);
    if (forbiddenBodies.some((body) => serialized.includes(body))) {
      throw new Error("A message body leaked into outbox state.");
    }
  }
}

async function ensureCompleteProfile(user, displayName) {
  const { error: anchorError } = await user.client
    .from("profiles")
    .insert({ id: user.id });
  if (anchorError) {
    const diagnostic = `${anchorError.message ?? ""} ${anchorError.details ?? ""}`;
    if (anchorError.code !== "23505" || !diagnostic.includes("profiles_pkey")) {
      throw safeDatabaseFailure("create a message-domain profile", anchorError);
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
    throw safeDatabaseFailure("complete a message-domain profile", updateError);
  }
}

async function signInWithLocalOtp(email) {
  return signInLocalOtpUser({
    apiUrl,
    publishableKey,
    mailpitUrl,
    email,
    verifierName: "message-domain",
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
