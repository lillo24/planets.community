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
    "Local Supabase status is missing the database URL required for resource-chat concurrency and privacy assertions.",
  );
}

const sql = postgres(databaseUrl, { max: 10, onnotice: () => {} });
const openedChannels = [];

try {
  await verifyResourceRequestChat();
} finally {
  await Promise.allSettled(
    openedChannels.map(({ client, channel }) => client.removeChannel(channel)),
  );
  await sql.end({ timeout: 5 });
}

async function verifyResourceRequestChat() {
  const [owner, requester, requesterB, unrelated] = await Promise.all([
    signInWithLocalOtp("resource-chat-owner@planets.invalid"),
    signInWithLocalOtp("resource-chat-requester@planets.invalid"),
    signInWithLocalOtp("resource-chat-requester-b@planets.invalid"),
    signInWithLocalOtp("resource-chat-unrelated@planets.invalid"),
  ]);

  await Promise.all([
    ensureCompleteProfile(owner, "Resource Chat Owner"),
    ensureCompleteProfile(requester, "Resource Chat Requester"),
    ensureCompleteProfile(requesterB, "Resource Chat Requester B"),
    ensureCompleteProfile(unrelated, "Resource Chat Unrelated"),
  ]);
  await Promise.all(
    [owner, requester, requesterB, unrelated].map((user) =>
      ensureLocalProfilePhoto(user),
    ),
  );

  const listingId = await createPublishedListing(
    owner,
    "Resource chat integration item",
  );
  const requestId = await requestListing(requester, listingId);
  await assertAnchorCounts(requestId, 0, 0);
  await acceptRequest(owner, requestId);
  await assertAnchorCounts(requestId, 1, 1);

  const chat = await getChatByRequest(owner, requestId);
  const agreement = await getAgreement(owner, requestId);
  if (
    chat.request_id !== requestId ||
    chat.agreement_id !== agreement.agreement_id ||
    chat.viewer_role !== "owner" ||
    chat.has_send_entitlement !== true
  ) {
    throw new Error("Accepted request anchors did not resolve canonically.");
  }

  const ownerSignals = await subscribeToResourceChat(owner, chat.chat_id);
  const requesterSignals = await subscribeToResourceChat(
    requester,
    chat.chat_id,
  );
  await assertSubscriptionDenied(unrelated, chat.chat_id);

  const messageBody = "Private durable resource-chat integration message";
  const message = await sendMessage(requester, chat.chat_id, messageBody);
  assertCanonicalMessage(message, requester.id, messageBody);
  await assertMessageSignal(ownerSignals, message, requestId);
  await assertMessageSignal(requesterSignals, message, requestId);
  await assertIdentifierOnlyMessageRows(message, 2);
  await assertHistoryContains(
    owner,
    chat.chat_id,
    message.message_id,
    messageBody,
  );

  const privateNote = "Private resource-chat agreement integration note";
  const exchangeSignalsBeforeProposal = ownerSignals.exchange.length;
  const termsId = await proposeGiveTerms(
    owner,
    agreement.agreement_id,
    privateNote,
  );
  await assertExchangeSignal(
    ownerSignals,
    exchangeSignalsBeforeProposal,
    chat.chat_id,
    agreement.agreement_id,
    privateNote,
  );
  await acceptTerms(requester, agreement.agreement_id, termsId);

  await verifyListingClosureKeepsChatOpen(owner, requesterB);

  await milestone(
    owner,
    agreement.agreement_id,
    termsId,
    "owner_resource",
    "resource_provided",
  );
  const ownerSignalsBeforeCompletion = ownerSignals.exchange.length;
  const requesterSignalsBeforeCompletion = requesterSignals.exchange.length;
  const completionEventId = await milestone(
    requester,
    agreement.agreement_id,
    termsId,
    "owner_resource",
    "resource_received",
  );
  await assertExchangeSignal(
    ownerSignals,
    ownerSignalsBeforeCompletion,
    chat.chat_id,
    agreement.agreement_id,
    privateNote,
    completionEventId,
  );
  await assertExchangeSignal(
    requesterSignals,
    requesterSignalsBeforeCompletion,
    chat.chat_id,
    agreement.agreement_id,
    privateNote,
    completionEventId,
  );
  await assertRpcCode(
    requester.client.rpc("send_resource_request_chat_message", {
      p_expected_profile_id: requester.id,
      p_chat_id: chat.chat_id,
      p_body: "This closed-chat send must fail",
    }),
    "PT409",
    "reject a send after automatic completion",
  );
  await assertHistoryContains(
    requester,
    chat.chat_id,
    message.message_id,
    messageBody,
  );
  const closedSummary = await getChat(requester, chat.chat_id);
  if (
    closedSummary.agreement_lifecycle !== "completed" ||
    closedSummary.coordination_closed_at === null ||
    closedSummary.has_send_entitlement !== false
  ) {
    throw new Error(
      "Completed coordination did not remain as a read-only chat.",
    );
  }

  const repeatRequestId = await requestListing(requester, listingId);
  await acceptRequest(owner, repeatRequestId);
  const repeatChat = await getChatByRequest(owner, repeatRequestId);
  if (repeatChat.chat_id === chat.chat_id) {
    throw new Error("A later request episode reused an earlier conversation.");
  }

  await verifySendVersusCancellation(owner, requester);
  await verifySendVersusCompletion(owner, requester);
  await verifyAcceptanceConcurrency(owner, requesterB);
  await assertIdentifierOnlyEvents(
    [messageBody, privateNote],
    [message.message_id],
  );

  console.log(
    "Confirmed real-OTP accepted resource-request conversations: atomic anchors, exact private Realtime topics, identifier-only message/agreement refreshes, durable history, listing-close survival, final read-only state, repeat-request isolation, and deterministic send/cancel/complete/accept serialization.",
  );
}

async function verifyListingClosureKeepsChatOpen(owner, requester) {
  const { listingId, chatId } = await createAcceptedChat(
    owner,
    requester,
    "Resource chat listing-close item",
  );
  await closeListing(owner, listingId);
  const message = await sendMessage(
    requester,
    chatId,
    "Accepted coordination survives listing closure",
  );
  const summary = await getChat(owner, chatId);
  if (
    message.chat_id !== chatId ||
    summary.has_send_entitlement !== true ||
    summary.agreement_lifecycle !== "negotiating"
  ) {
    throw new Error("Listing closure disabled an accepted open conversation.");
  }
}

async function verifySendVersusCancellation(owner, requester) {
  const cancellationFirst = await createAcceptedChat(
    owner,
    requester,
    "Resource chat cancel-first race",
  );
  let blockedSend;
  await sql.begin(async (transaction) => {
    await setAuthenticatedTransaction(transaction, owner.id);
    await transaction`
      select public.cancel_resource_exchange_agreement(
        ${owner.id}::uuid,
        ${cancellationFirst.agreementId}::uuid
      )
    `;
    blockedSend = track(
      requester.client.rpc("send_resource_request_chat_message", {
        p_expected_profile_id: requester.id,
        p_chat_id: cancellationFirst.chatId,
        p_body: "Cancellation-first race body",
      }),
    );
    await assertBlocked(blockedSend, "send behind cancellation");
  });
  await assertTrackedRpcCode(
    blockedSend,
    "PT409",
    "reject a send serialized after cancellation",
  );

  const sendFirst = await createAcceptedChat(
    owner,
    requester,
    "Resource chat send-first cancellation race",
  );
  let blockedCancellation;
  let committedMessageId;
  await sql.begin(async (transaction) => {
    await setAuthenticatedTransaction(transaction, requester.id);
    const rows = await transaction`
      select message_id
      from public.send_resource_request_chat_message(
        ${requester.id}::uuid,
        ${sendFirst.chatId}::uuid,
        'Send-first cancellation race body'
      )
    `;
    committedMessageId = rows[0]?.message_id;
    blockedCancellation = track(
      owner.client.rpc("cancel_resource_exchange_agreement", {
        p_expected_profile_id: owner.id,
        p_agreement_id: sendFirst.agreementId,
      }),
    );
    await assertBlocked(blockedCancellation, "cancellation behind send");
  });
  await assertTrackedRpcValue(
    blockedCancellation,
    "complete cancellation serialized after a send",
  );
  if (typeof committedMessageId !== "string") {
    throw new Error(
      "The send-first cancellation race lost its durable message.",
    );
  }
  await assertHistoryHasId(owner, sendFirst.chatId, committedMessageId);
}

async function verifySendVersusCompletion(owner, requester) {
  const completionFirst = await createCompletableChat(
    owner,
    requester,
    "Resource chat completion-first race",
  );
  let blockedSend;
  await sql.begin(async (transaction) => {
    await setAuthenticatedTransaction(transaction, requester.id);
    await transaction`
      select public.record_resource_exchange_milestone(
        ${requester.id}::uuid,
        ${completionFirst.agreementId}::uuid,
        ${completionFirst.termsId}::uuid,
        'owner_resource',
        'resource_received'
      )
    `;
    blockedSend = track(
      owner.client.rpc("send_resource_request_chat_message", {
        p_expected_profile_id: owner.id,
        p_chat_id: completionFirst.chatId,
        p_body: "Completion-first race body",
      }),
    );
    await assertBlocked(blockedSend, "send behind automatic completion");
  });
  await assertTrackedRpcCode(
    blockedSend,
    "PT409",
    "reject a send serialized after automatic completion",
  );

  const sendFirst = await createCompletableChat(
    owner,
    requester,
    "Resource chat send-first completion race",
  );
  let blockedCompletion;
  let committedMessageId;
  await sql.begin(async (transaction) => {
    await setAuthenticatedTransaction(transaction, owner.id);
    const rows = await transaction`
      select message_id
      from public.send_resource_request_chat_message(
        ${owner.id}::uuid,
        ${sendFirst.chatId}::uuid,
        'Send-first completion race body'
      )
    `;
    committedMessageId = rows[0]?.message_id;
    blockedCompletion = track(
      requester.client.rpc("record_resource_exchange_milestone", {
        p_expected_profile_id: requester.id,
        p_agreement_id: sendFirst.agreementId,
        p_expected_terms_id: sendFirst.termsId,
        p_leg_kind: "owner_resource",
        p_event_kind: "resource_received",
      }),
    );
    await assertBlocked(blockedCompletion, "automatic completion behind send");
  });
  await assertTrackedRpcValue(
    blockedCompletion,
    "complete the agreement serialized after a send",
  );
  if (typeof committedMessageId !== "string") {
    throw new Error("The send-first completion race lost its durable message.");
  }
  await assertHistoryHasId(requester, sendFirst.chatId, committedMessageId);
  const summary = await getChat(owner, sendFirst.chatId);
  if (summary.agreement_lifecycle !== "completed") {
    throw new Error(
      "The send-first completion race did not close coordination.",
    );
  }
}

async function verifyAcceptanceConcurrency(owner, requester) {
  const listingId = await createPublishedListing(
    owner,
    "Resource chat acceptance race",
  );
  const requestId = await requestListing(requester, listingId);
  let blockedAcceptance;
  await sql.begin(async (transaction) => {
    await setAuthenticatedTransaction(transaction, owner.id);
    await transaction`
      select public.accept_resource_listing_request(
        ${owner.id}::uuid,
        ${requestId}::uuid
      )
    `;
    blockedAcceptance = track(
      owner.client.rpc("accept_resource_listing_request", {
        p_expected_owner_profile_id: owner.id,
        p_request_id: requestId,
      }),
    );
    await assertBlocked(blockedAcceptance, "competing request acceptance");
  });
  await assertTrackedRpcCode(
    blockedAcceptance,
    "PT409",
    "reject the later competing request acceptance",
  );
  await assertAnchorCounts(requestId, 1, 1);
  const [{ status }] = await sql`
    select status
    from public.resource_listing_requests
    where id = ${requestId}::uuid
  `;
  if (status !== "accepted") {
    throw new Error("The acceptance race did not retain canonical acceptance.");
  }
}

async function createCompletableChat(owner, requester, title) {
  const accepted = await createAcceptedChat(owner, requester, title);
  const termsId = await proposeGiveTerms(owner, accepted.agreementId, null);
  await acceptTerms(requester, accepted.agreementId, termsId);
  await milestone(
    owner,
    accepted.agreementId,
    termsId,
    "owner_resource",
    "resource_provided",
  );
  return { ...accepted, termsId };
}

async function createAcceptedChat(owner, requester, title) {
  const listingId = await createPublishedListing(owner, title);
  const requestId = await requestListing(requester, listingId);
  await acceptRequest(owner, requestId);
  const chat = await getChatByRequest(owner, requestId);
  return {
    listingId,
    requestId,
    chatId: chat.chat_id,
    agreementId: chat.agreement_id,
  };
}

async function createPublishedListing(owner, title) {
  const listingId = await rpcValue(
    owner,
    "create_resource_listing_draft",
    {
      p_expected_owner_profile_id: owner.id,
      p_listing_mode: "exchange",
      p_title: title,
      p_description:
        "Deterministic listing used only by the local resource-chat verifier.",
      p_country_code: "IT",
      p_locality: "Trento",
      p_administrative_area: null,
      p_public_location_label: "Trento",
    },
    "create a resource-chat verifier listing",
  );
  const publishedId = await rpcValue(
    owner,
    "publish_resource_listing",
    {
      p_expected_owner_profile_id: owner.id,
      p_listing_id: listingId,
    },
    "publish a resource-chat verifier listing",
  );
  if (publishedId !== listingId) {
    throw new Error("Listing publication returned the wrong identifier.");
  }
  return listingId;
}

async function requestListing(requester, listingId) {
  return rpcValue(
    requester,
    "request_resource_listing",
    {
      p_expected_requester_profile_id: requester.id,
      p_listing_id: listingId,
      p_message: null,
    },
    "request a resource-chat verifier listing",
  );
}

async function acceptRequest(owner, requestId) {
  const acceptedId = await rpcValue(
    owner,
    "accept_resource_listing_request",
    {
      p_expected_owner_profile_id: owner.id,
      p_request_id: requestId,
    },
    "accept a resource-chat verifier request",
  );
  if (acceptedId !== requestId) {
    throw new Error("Request acceptance returned the wrong identifier.");
  }
}

async function closeListing(owner, listingId) {
  const closedId = await rpcValue(
    owner,
    "close_resource_listing",
    {
      p_expected_owner_profile_id: owner.id,
      p_listing_id: listingId,
    },
    "close a resource-chat verifier listing",
  );
  if (closedId !== listingId) {
    throw new Error("Listing closure returned the wrong identifier.");
  }
}

async function getAgreement(actor, requestId) {
  const { data, error } = await actor.client.rpc(
    "get_resource_exchange_agreement",
    { p_expected_profile_id: actor.id, p_request_id: requestId },
  );
  if (error || data?.length !== 1) {
    throw safeDatabaseFailure("read a resource exchange agreement", error);
  }
  return data[0];
}

async function getChatByRequest(actor, requestId) {
  const rows = await sql`
    select id
    from public.resource_request_chats
    where request_id = ${requestId}::uuid
  `;
  if (rows.length !== 1) {
    throw new Error("An accepted request did not own exactly one chat.");
  }
  return getChat(actor, rows[0].id);
}

async function getChat(actor, chatId) {
  const { data, error } = await actor.client.rpc(
    "get_own_resource_request_chat",
    { p_expected_profile_id: actor.id, p_chat_id: chatId },
  );
  if (error || data?.length !== 1) {
    throw safeDatabaseFailure("read an exact resource request chat", error);
  }
  return data[0];
}

async function listHistory(actor, chatId) {
  const { data, error } = await actor.client.rpc(
    "list_own_resource_request_chat_messages",
    {
      p_expected_profile_id: actor.id,
      p_chat_id: chatId,
      p_limit: 50,
      p_before_created_at: null,
      p_before_message_id: null,
    },
  );
  if (error || !Array.isArray(data)) {
    throw safeDatabaseFailure("list resource request chat history", error);
  }
  return data;
}

async function sendMessage(actor, chatId, body) {
  const { data, error } = await actor.client.rpc(
    "send_resource_request_chat_message",
    {
      p_expected_profile_id: actor.id,
      p_chat_id: chatId,
      p_body: body,
    },
  );
  if (error || data?.length !== 1) {
    throw safeDatabaseFailure("send a resource request chat message", error);
  }
  return data[0];
}

async function proposeGiveTerms(actor, agreementId, privateNote) {
  return rpcValue(
    actor,
    "propose_resource_exchange_terms",
    {
      p_expected_profile_id: actor.id,
      p_agreement_id: agreementId,
      p_expected_current_terms_id: null,
      p_expected_pending_terms_id: null,
      p_owner_transfer_kind: "give",
      p_owner_lend_starts_at: null,
      p_owner_lend_ends_at: null,
      p_requester_transfer_kind: "none",
      p_requester_resource_description: null,
      p_requester_lend_starts_at: null,
      p_requester_lend_ends_at: null,
      p_private_note: privateNote,
    },
    "propose resource exchange terms",
  );
}

async function acceptTerms(actor, agreementId, termsId) {
  const acceptedId = await rpcValue(
    actor,
    "accept_resource_exchange_terms",
    {
      p_expected_profile_id: actor.id,
      p_agreement_id: agreementId,
      p_expected_pending_terms_id: termsId,
    },
    "accept resource exchange terms",
  );
  if (acceptedId !== termsId) {
    throw new Error("Terms acceptance returned the wrong identifier.");
  }
}

async function milestone(actor, agreementId, termsId, legKind, eventKind) {
  return rpcValue(
    actor,
    "record_resource_exchange_milestone",
    {
      p_expected_profile_id: actor.id,
      p_agreement_id: agreementId,
      p_expected_terms_id: termsId,
      p_leg_kind: legKind,
      p_event_kind: eventKind,
    },
    "record a resource exchange milestone",
  );
}

async function subscribeToResourceChat(user, chatId) {
  const signals = { message: [], exchange: [] };
  const channel = user.client.channel(resourceChatTopic(chatId, user.id), {
    config: { private: true },
  });
  channel.on("broadcast", { event: "resource.chat_message_sent" }, (event) =>
    signals.message.push(event.payload ?? event),
  );
  channel.on("broadcast", { event: "resource.exchange_changed" }, (event) =>
    signals.exchange.push(event.payload ?? event),
  );
  openedChannels.push({ client: user.client, channel });
  await waitForSubscription(channel, true);
  return signals;
}

async function assertSubscriptionDenied(user, chatId) {
  const channel = user.client.channel(resourceChatTopic(chatId, user.id), {
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
            ? "An authorized private resource-chat subscription timed out."
            : "An unauthorized private resource-chat subscription did not fail.",
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
            new Error("An unrelated profile subscribed to a resource chat."),
          );
        }
      } else if (
        status === "CHANNEL_ERROR" ||
        status === "TIMED_OUT" ||
        status === "CLOSED"
      ) {
        clearTimeout(timeout);
        if (shouldSucceed) {
          reject(
            new Error(
              "An authorized private resource-chat subscription failed.",
            ),
          );
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

async function assertMessageSignal(signals, message, requestId) {
  const signal = await waitForSignal(
    signals.message,
    0,
    (candidate) => candidate.message_id === message.message_id,
    "resource-chat message signal",
  );
  const expectedKeys = [
    "chat_id",
    "created_at",
    "id",
    "message_id",
    "request_id",
    "sender_profile_id",
  ];
  if (
    signal.chat_id !== message.chat_id ||
    signal.request_id !== requestId ||
    signal.sender_profile_id !== message.sender_profile_id ||
    signal.created_at !== message.created_at ||
    typeof signal.id !== "string" ||
    JSON.stringify(Object.keys(signal).sort()) !== JSON.stringify(expectedKeys)
  ) {
    throw new Error("Realtime exposed a non-canonical message signal.");
  }
}

async function assertExchangeSignal(
  signals,
  startingIndex,
  chatId,
  agreementId,
  forbiddenText,
  expectedEventId = null,
) {
  const signal = await waitForSignal(
    signals.exchange,
    startingIndex,
    (candidate) =>
      candidate.chat_id === chatId &&
      candidate.agreement_id === agreementId &&
      (expectedEventId === null ||
        candidate.agreement_event_id === expectedEventId),
    "resource exchange refresh signal",
  );
  const allowedKeys = new Set([
    "agreement_event_id",
    "agreement_id",
    "chat_id",
    "created_at",
    "id",
    "request_id",
    "terms_id",
  ]);
  if (
    typeof signal.id !== "string" ||
    Object.keys(signal).some((key) => !allowedKeys.has(key)) ||
    (forbiddenText !== null && JSON.stringify(signal).includes(forbiddenText))
  ) {
    throw new Error(
      "Realtime exposed private or non-canonical agreement data.",
    );
  }
}

async function waitForSignal(signals, startingIndex, predicate, label) {
  const deadline = Date.now() + 5_000;
  while (Date.now() < deadline) {
    const signal = signals.slice(startingIndex).find(predicate);
    if (signal) {
      return signal;
    }
    await delay(25);
  }
  throw new Error(`An authorized client did not receive the ${label}.`);
}

async function assertIdentifierOnlyMessageRows(message, expectedRecipients) {
  const rows = await sql`
    select payload
    from realtime.messages
    where extension = 'broadcast'
      and event = 'resource.chat_message_sent'
      and payload ->> 'message_id' = ${message.message_id}
  `;
  const expectedKeys = [
    "chat_id",
    "created_at",
    "id",
    "message_id",
    "request_id",
    "sender_profile_id",
  ];
  if (rows.length !== expectedRecipients) {
    throw new Error("Resource-chat Realtime fan-out missed a counterparty.");
  }
  for (const row of rows) {
    if (
      typeof row.payload.id !== "string" ||
      JSON.stringify(Object.keys(row.payload).sort()) !==
        JSON.stringify(expectedKeys)
    ) {
      throw new Error(
        "A resource-chat Realtime payload was not identifier-only.",
      );
    }
  }
}

async function assertIdentifierOnlyEvents(forbiddenTexts, messageIds) {
  const rows = await sql`
    select payload
    from private.outbox_events
    where event_type = 'resource_chat.message_sent'
      and payload ->> 'message_id' = any(${sql.array(messageIds)}::text[])
  `;
  const expectedKeys = [
    "agreement_id",
    "chat_id",
    "listing_id",
    "message_id",
    "owner_profile_id",
    "request_id",
    "requester_profile_id",
    "sender_profile_id",
  ];
  if (rows.length !== messageIds.length) {
    throw new Error("A resource-chat message did not record one outbox event.");
  }
  for (const row of rows) {
    const serialized = JSON.stringify(row.payload);
    if (
      JSON.stringify(Object.keys(row.payload).sort()) !==
        JSON.stringify(expectedKeys) ||
      forbiddenTexts.some((text) => serialized.includes(text))
    ) {
      throw new Error("A resource-chat outbox event exposed private content.");
    }
  }

  const [{ leaked_count: leakedCount }] = await sql`
    select count(*)::integer as leaked_count
    from private.audit_events
    where position(${forbiddenTexts[0]} in metadata::text) > 0
       or position(${forbiddenTexts[1]} in metadata::text) > 0
  `;
  if (leakedCount !== 0) {
    throw new Error(
      "Private resource-chat content leaked into audit metadata.",
    );
  }
}

async function assertAnchorCounts(
  requestId,
  expectedChats,
  expectedAgreements,
) {
  const [row] = await sql`
    select
      (select count(*)::integer
       from public.resource_request_chats
       where request_id = ${requestId}::uuid) as chat_count,
      (select count(*)::integer
       from public.resource_exchange_agreements
       where request_id = ${requestId}::uuid) as agreement_count
  `;
  if (
    row.chat_count !== expectedChats ||
    row.agreement_count !== expectedAgreements
  ) {
    throw new Error("A request owned a non-canonical anchor count.");
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
    throw new Error("Send returned a non-canonical resource-chat message.");
  }
}

async function assertHistoryContains(actor, chatId, messageId, body) {
  const messages = await listHistory(actor, chatId);
  const message = messages.find(
    (candidate) => candidate.message_id === messageId,
  );
  if (!message || message.body !== body) {
    throw new Error("Authorized resource-chat history was incomplete.");
  }
}

async function assertHistoryHasId(actor, chatId, messageId) {
  const messages = await listHistory(actor, chatId);
  if (!messages.some((message) => message.message_id === messageId)) {
    throw new Error("A serialized resource-chat message was not durable.");
  }
}

function resourceChatTopic(chatId, profileId) {
  return `resource-chat:${chatId}:profile:${profileId}`;
}

async function rpcValue(actor, operation, args, action) {
  const { data, error } = await actor.client.rpc(operation, args);
  if (error || typeof data !== "string") {
    throw safeDatabaseFailure(action, error);
  }
  return data;
}

async function assertRpcCode(pendingResult, expectedCode, action) {
  const result = await pendingResult;
  if (result.data !== null || result.error?.code !== expectedCode) {
    throw new Error(`Failed to ${action} with the expected database error.`);
  }
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
      throw safeDatabaseFailure("create a resource-chat profile", anchorError);
    }
  }
  const { error } = await user.client.rpc("update_own_profile", {
    p_expected_profile_id: user.id,
    p_display_name: displayName,
    p_bio: null,
    p_skill_ids: [],
    p_display_name_audience: "private",
    p_bio_audience: "private",
    p_skills_audience: "private",
  });
  if (error) {
    throw safeDatabaseFailure("complete a resource-chat profile", error);
  }
}

function signInWithLocalOtp(email) {
  return signInLocalOtpUser({
    apiUrl,
    publishableKey,
    mailpitUrl,
    email,
    verifierName: "resource request chat verifier",
  });
}

function track(pendingResult) {
  const tracked = { settled: false, promise: undefined };
  tracked.promise = Promise.resolve(pendingResult).then(
    (result) => {
      tracked.settled = true;
      return result;
    },
    (error) => {
      tracked.settled = true;
      throw error;
    },
  );
  return tracked;
}

async function assertBlocked(tracked, action) {
  await delay(250);
  if (tracked.settled) {
    throw new Error(`The ${action} operation did not wait for its lock.`);
  }
}

async function assertTrackedRpcCode(tracked, expectedCode, action) {
  const result = await tracked.promise;
  if (result.data !== null || result.error?.code !== expectedCode) {
    throw new Error(`Failed to ${action} with the expected database error.`);
  }
}

async function assertTrackedRpcValue(tracked, action) {
  const result = await tracked.promise;
  if (result.error || typeof result.data !== "string") {
    throw safeDatabaseFailure(action, result.error);
  }
  return result.data;
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
