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
  await verifyProjectNeedResurfacing();
} finally {
  await Promise.allSettled(
    openedChannels.map(({ client, channel }) => client.removeChannel(channel)),
  );
  await sql.end();
}

async function verifyProjectNeedResurfacing() {
  const [creator, participant, former, unrelated] = await Promise.all([
    signIn("need-resurfacing-creator@planets.invalid"),
    signIn("need-resurfacing-participant@planets.invalid"),
    signIn("need-resurfacing-former@planets.invalid"),
    signIn("need-resurfacing-unrelated@planets.invalid"),
  ]);
  await Promise.all([
    ensureCompleteProfile(creator, "Need Resurfacing Creator"),
    ensureCompleteProfile(participant, "Need Resurfacing Participant"),
    ensureCompleteProfile(former, "Need Resurfacing Former"),
    ensureCompleteProfile(unrelated, "Need Resurfacing Unrelated"),
  ]);
  await Promise.all(
    [creator, participant, former, unrelated].map((user) =>
      ensureLocalProfilePhoto(user),
    ),
  );

  const projectId = await createProposal(creator);
  const firstNeedId = await createNeed(creator, projectId);
  const laterNeedId = await createNeed(creator, projectId);
  await publishProposal(creator, projectId);

  const participantMembershipId = await joinProject(
    creator,
    participant,
    projectId,
  );
  const formerMembershipId = await joinProject(creator, former, projectId);
  const chat = await getChat(creator, projectId);

  const creatorSignals = await subscribeToChat(creator, chat.chat_id);
  const participantSignals = await subscribeToChat(participant, chat.chat_id);
  const formerSignals = await subscribeToChat(former, chat.chat_id);
  await assertSubscriptionDenied(unrelated, chat.chat_id);

  await leaveMembership(former, formerMembershipId);
  const formerSignalCount = formerSignals.length;

  await setManualCoverage(creator, projectId, firstNeedId, true);
  const coveredPreparation = await waitForSignal(
    participantSignals,
    "project.requirement_covered",
    firstNeedId,
  );
  assertCoveredPayload(
    coveredPreparation,
    chat.chat_id,
    projectId,
    firstNeedId,
  );

  const systemCountBefore = await countSystemEvents(chat.chat_id);
  await setManualCoverage(creator, projectId, firstNeedId, false);
  const neededSignal = await waitForSignal(
    participantSignals,
    "project.requirement_needed_again",
    firstNeedId,
  );
  const creatorNeededSignal = await waitForSignal(
    creatorSignals,
    "project.requirement_needed_again",
    firstNeedId,
  );
  assertNeededPayload(neededSignal, chat.chat_id, projectId, firstNeedId);
  assertNeededPayload(
    creatorNeededSignal,
    chat.chat_id,
    projectId,
    firstNeedId,
  );
  if (neededSignal.system_event_id !== creatorNeededSignal.system_event_id) {
    throw new Error(
      "Current recipients did not receive one canonical system item.",
    );
  }
  await assertNoNewSignal(formerSignals, formerSignalCount);
  await closeSubscription(former, formerSignals.channel);
  await assertSubscriptionDenied(former, chat.chat_id);
  await assertRealtimeFanout(
    "project.requirement_needed_again",
    firstNeedId,
    2,
    true,
    neededSignal.created_at,
  );

  if ((await countSystemEvents(chat.chat_id)) !== systemCountBefore + 1) {
    throw new Error(
      "A needed-again transition did not create one system item.",
    );
  }
  await assertFeedSystemEvent(
    participant,
    chat.chat_id,
    neededSignal.system_event_id,
    firstNeedId,
  );
  await assertAttention(
    participant,
    projectId,
    true,
    neededSignal.system_event_id,
  );

  const participantClaimSignalStart = participantSignals.length;
  const creatorClaimSignalStart = creatorSignals.length;
  await claimRequirement(
    participant,
    projectId,
    firstNeedId,
    participantMembershipId,
  );
  const coveredSignal = await waitForSignal(
    participantSignals,
    "project.requirement_covered",
    firstNeedId,
    participantClaimSignalStart,
  );
  assertCoveredPayload(coveredSignal, chat.chat_id, projectId, firstNeedId);
  await waitForSignal(
    creatorSignals,
    "project.requirement_covered",
    firstNeedId,
    creatorClaimSignalStart,
  );
  await assertRealtimeFanout(
    "project.requirement_covered",
    firstNeedId,
    2,
    false,
    coveredSignal.created_at,
  );
  await assertAttention(participant, projectId, false, null);
  await assertFeedSystemEvent(
    participant,
    chat.chat_id,
    neededSignal.system_event_id,
    firstNeedId,
  );

  const humanSignalStart = participantSignals.length;
  const humanMessage = await sendMessage(creator, chat.chat_id);
  const humanSignal = await waitForSignal(
    participantSignals,
    "project.chat_message_sent",
    humanMessage.message_id,
    humanSignalStart,
  );
  assertHumanPayload(humanSignal, chat.chat_id, humanMessage.message_id);

  const acknowledgedEventId = await acknowledgeAttention(
    participant,
    projectId,
    neededSignal.system_event_id,
  );
  if (acknowledgedEventId !== neededSignal.system_event_id) {
    throw new Error(
      "Attention did not persist the explicit seen-through event.",
    );
  }

  await setManualCoverage(creator, projectId, laterNeedId, true);
  await waitForSignal(
    participantSignals,
    "project.requirement_covered",
    laterNeedId,
  );

  let blockedAcknowledgement;
  await sql.begin(async (transaction) => {
    await setAuthenticatedTransaction(transaction, creator.id);
    await transaction`
      select public.set_project_requirement_manual_coverage(
        ${creator.id}::uuid,
        ${projectId}::uuid,
        'resource',
        ${laterNeedId}::uuid,
        false
      )
    `;
    blockedAcknowledgement = track(
      participant.client.rpc("acknowledge_project_requirement_attention", {
        p_expected_profile_id: participant.id,
        p_project_id: projectId,
        p_through_system_event_id: neededSignal.system_event_id,
      }),
    );
    await assertBlocked(
      blockedAcknowledgement,
      "acknowledgement behind a newer resurfacing transition",
    );
  });

  const acknowledgementResult = await blockedAcknowledgement.promise;
  if (
    acknowledgementResult.error ||
    acknowledgementResult.data !== neededSignal.system_event_id
  ) {
    throw safeDatabaseFailure(
      "preserve the older acknowledgement frontier",
      acknowledgementResult.error ?? {},
    );
  }

  const laterSignal = await waitForSignal(
    participantSignals,
    "project.requirement_needed_again",
    laterNeedId,
  );
  assertNeededPayload(laterSignal, chat.chat_id, projectId, laterNeedId);
  await assertAttention(
    participant,
    projectId,
    true,
    laterSignal.system_event_id,
  );

  const [receipt] = await sql`
    select acknowledged_through_event_id
    from public.project_chat_requirement_attention_receipts
    where chat_id = ${chat.chat_id}::uuid
      and profile_id = ${participant.id}::uuid
  `;
  if (receipt?.acknowledged_through_event_id !== neededSignal.system_event_id) {
    throw new Error(
      "A concurrent newer event was swallowed by acknowledgement.",
    );
  }

  const feed = await listFeed(participant, chat.chat_id);
  const systemIds = new Set(
    feed
      .filter((item) => item.item_kind === "system_requirement_needed_again")
      .map((item) => item.item_id),
  );
  if (
    !systemIds.has(neededSignal.system_event_id) ||
    !systemIds.has(laterSignal.system_event_id)
  ) {
    throw new Error("Mixed history omitted a durable resurfacing item.");
  }

  await assertIdentifierOnlyOutboxAndSystemRows(projectId);

  console.log(
    "Confirmed structured need resurfacing, mixed history, current-only private signals, persistent frontier attention, re-cover clearing, human-message Realtime regression, and acknowledgement/new-event serialization.",
  );
}

async function subscribeToChat(user, chatId) {
  const signals = [];
  const channel = user.client.channel(projectChatTopic(chatId, user.id), {
    config: { private: true },
  });
  signals.channel = channel;
  for (const eventKind of [
    "project.chat_message_sent",
    "project.requirement_needed_again",
    "project.requirement_covered",
  ]) {
    channel.on("broadcast", { event: eventKind }, (event) =>
      signals.push({ eventKind, payload: event.payload ?? event }),
    );
  }
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

async function waitForSignal(
  signals,
  eventKind,
  identifier,
  startingIndex = 0,
) {
  const deadline = Date.now() + 5_000;
  while (Date.now() < deadline) {
    const signal = signals
      .slice(startingIndex)
      .find(
        (candidate) =>
          candidate.eventKind === eventKind &&
          (candidate.payload.requirement_id === identifier ||
            candidate.payload.message_id === identifier),
      );
    if (signal) {
      return signal.payload;
    }
    await delay(25);
  }
  throw new Error("An authorized profile did not receive a private signal.");
}

function assertNeededPayload(payload, chatId, projectId, requirementId) {
  const expectedKeys = [
    "chat_id",
    "created_at",
    "id",
    "project_id",
    "requirement_id",
    "requirement_kind",
    "system_event_id",
  ];
  if (
    payload.chat_id !== chatId ||
    payload.project_id !== projectId ||
    payload.requirement_id !== requirementId ||
    payload.requirement_kind !== "resource" ||
    typeof payload.system_event_id !== "string" ||
    typeof payload.created_at !== "string" ||
    typeof payload.id !== "string" ||
    JSON.stringify(Object.keys(payload).sort()) !== JSON.stringify(expectedKeys)
  ) {
    throw new Error("A needed-again signal exposed a non-canonical payload.");
  }
}

function assertCoveredPayload(payload, chatId, projectId, requirementId) {
  const expectedKeys = [
    "chat_id",
    "created_at",
    "id",
    "project_id",
    "requirement_id",
    "requirement_kind",
  ];
  if (
    payload.chat_id !== chatId ||
    payload.project_id !== projectId ||
    payload.requirement_id !== requirementId ||
    payload.requirement_kind !== "resource" ||
    typeof payload.created_at !== "string" ||
    typeof payload.id !== "string" ||
    JSON.stringify(Object.keys(payload).sort()) !== JSON.stringify(expectedKeys)
  ) {
    throw new Error("A covered signal exposed a non-canonical payload.");
  }
}

function assertHumanPayload(payload, chatId, messageId) {
  const expectedKeys = ["chat_id", "created_at", "id", "message_id"];
  if (
    payload.chat_id !== chatId ||
    payload.message_id !== messageId ||
    typeof payload.created_at !== "string" ||
    typeof payload.id !== "string" ||
    JSON.stringify(Object.keys(payload).sort()) !== JSON.stringify(expectedKeys)
  ) {
    throw new Error("Human-message Realtime behavior changed unexpectedly.");
  }
}

async function assertNoNewSignal(signals, startingCount) {
  await delay(750);
  if (signals.length !== startingCount) {
    throw new Error("A former participant received post-membership activity.");
  }
}

async function assertRealtimeFanout(
  eventKind,
  requirementId,
  expectedRecipients,
  expectsSystemEvent,
  createdAt,
) {
  const rows = await sql`
    select payload
    from realtime.messages
    where extension = 'broadcast'
      and event = ${eventKind}
      and payload ->> 'requirement_id' = ${requirementId}
      and payload ->> 'created_at' = ${createdAt}
  `;
  if (rows.length !== expectedRecipients) {
    throw new Error("Realtime fan-out did not match current entitlement.");
  }
  for (const row of rows) {
    const forbiddenKeys = [
      "label",
      "title",
      "display_name",
      "request_message",
      "provider_profile_id",
    ];
    if (
      forbiddenKeys.some((key) => Object.hasOwn(row.payload, key)) ||
      Object.hasOwn(row.payload, "system_event_id") !== expectsSystemEvent
    ) {
      throw new Error("A persisted Realtime row exposed private context.");
    }
  }
}

async function assertFeedSystemEvent(
  user,
  chatId,
  systemEventId,
  requirementId,
) {
  const feed = await listFeed(user, chatId);
  const item = feed.find((candidate) => candidate.item_id === systemEventId);
  const keys = item ? Object.keys(item).sort() : [];
  const expectedKeys = [
    "body",
    "chat_id",
    "created_at",
    "item_id",
    "item_kind",
    "requirement_id",
    "requirement_kind",
    "requirement_label",
    "sender_display_name",
    "sender_profile_id",
    "system_event_kind",
  ].sort();
  if (
    !item ||
    item.item_kind !== "system_requirement_needed_again" ||
    item.system_event_kind !== "requirement_needed_again" ||
    item.requirement_kind !== "resource" ||
    item.requirement_id !== requirementId ||
    typeof item.requirement_label !== "string" ||
    item.sender_profile_id !== null ||
    item.sender_display_name !== null ||
    item.body !== null ||
    JSON.stringify(keys) !== JSON.stringify(expectedKeys)
  ) {
    throw new Error("Mixed history returned a non-canonical system item.");
  }
}

async function listFeed(user, chatId) {
  const { data, error } = await user.client.rpc("list_own_project_chat_feed", {
    p_expected_profile_id: user.id,
    p_chat_id: chatId,
    p_limit: 50,
    p_before_created_at: null,
    p_before_item_kind: null,
    p_before_item_id: null,
  });
  if (error || !Array.isArray(data)) {
    throw safeDatabaseFailure("list mixed Project-chat history", error ?? {});
  }
  return data;
}

async function assertAttention(
  user,
  projectId,
  expectedState,
  expectedEventId,
) {
  const { data, error } = await user.client.rpc(
    "get_own_project_requirement_attention",
    {
      p_expected_profile_id: user.id,
      p_project_id: projectId,
    },
  );
  if (
    error ||
    data?.length !== 1 ||
    data[0].has_unseen_resurfaced_need !== expectedState ||
    data[0].latest_unseen_event_id !== expectedEventId ||
    (expectedState && typeof data[0].latest_unseen_event_at !== "string") ||
    (!expectedState && data[0].latest_unseen_event_at !== null)
  ) {
    throw safeDatabaseFailure(
      "read canonical Project requirement attention",
      error ?? {},
    );
  }
}

async function acknowledgeAttention(user, projectId, systemEventId) {
  const { data, error } = await user.client.rpc(
    "acknowledge_project_requirement_attention",
    {
      p_expected_profile_id: user.id,
      p_project_id: projectId,
      p_through_system_event_id: systemEventId,
    },
  );
  if (error || typeof data !== "string") {
    throw safeDatabaseFailure(
      "acknowledge Project requirement attention",
      error ?? {},
    );
  }
  return data;
}

async function countSystemEvents(chatId) {
  const [row] = await sql`
    select count(*)::integer as event_count
    from public.project_chat_system_events
    where chat_id = ${chatId}::uuid
  `;
  return row.event_count;
}

async function assertIdentifierOnlyOutboxAndSystemRows(projectId) {
  const rows = await sql`
    select payload
    from private.outbox_events
    where event_type in (
      'project.requirement_needed_again',
      'project.requirement_covered'
    )
      and payload ->> 'project_id' = ${projectId}
  `;
  if (rows.length === 0) {
    throw new Error("Coverage transition outbox history was absent.");
  }
  const forbiddenKeys = [
    "label",
    "title",
    "body",
    "display_name",
    "request_message",
    "email",
  ];
  if (
    rows.some((row) =>
      forbiddenKeys.some((key) => Object.hasOwn(row.payload, key)),
    )
  ) {
    throw new Error("Coverage outbox history exposed private content.");
  }
}

async function createProposal(creator) {
  const { data, error } = await creator.client.rpc("create_proposal_draft", {
    p_expected_creator_profile_id: creator.id,
    p_title: "Integration need resurfacing",
    p_summary: "Deterministic structured group attention verification.",
    p_description:
      "This Project verifies durable system history and private signals.",
    p_starts_at: "2098-01-02T10:00:00.000Z",
    p_ends_at: "2098-01-02T14:00:00.000Z",
    p_event_timezone: "Europe/Rome",
    p_country_code: "IT",
    p_locality: "Trento",
    p_administrative_area: "Povo",
    p_public_location_label: "Trento · Povo",
    p_exact_meeting_text: null,
    p_exact_location_visibility: "participants",
    p_skill_ids: [],
    p_skill_importances: [],
    p_people_capacity: 20,
  });
  if (error || typeof data !== "string") {
    throw safeDatabaseFailure("create a resurfacing Proposal", error ?? {});
  }
  return data;
}

async function publishProposal(creator, projectId) {
  const { data, error } = await creator.client.rpc("publish_proposal", {
    p_expected_creator_profile_id: creator.id,
    p_proposal_id: projectId,
  });
  if (error || data !== projectId) {
    throw safeDatabaseFailure("publish a resurfacing Proposal", error ?? {});
  }
}

async function createNeed(creator, projectId) {
  const { data, error } = await creator.client.rpc(
    "create_project_resource_need",
    {
      p_expected_creator_profile_id: creator.id,
      p_project_id: projectId,
      p_title: "Structured integration requirement",
      p_details: null,
    },
  );
  if (error || typeof data !== "string") {
    throw safeDatabaseFailure("create a Project resource need", error ?? {});
  }
  return data;
}

async function joinProject(creator, participant, projectId) {
  const { data: requestId, error: requestError } = await participant.client.rpc(
    "request_to_join_project",
    {
      p_expected_requester_profile_id: participant.id,
      p_project_id: projectId,
      p_request_message: null,
      p_skill_ids: [],
      p_resource_need_ids: [],
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
      p_needed_skill_ids: [],
      p_already_found_skill_ids: [],
      p_extra_skill_ids: [],
      p_needed_resource_need_ids: [],
      p_already_found_resource_need_ids: [],
      p_extra_resource_need_ids: [],
    });
  if (acceptanceError || typeof membershipId !== "string") {
    throw safeDatabaseFailure(
      "accept Project participation",
      acceptanceError ?? {},
    );
  }
  return membershipId;
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

async function leaveMembership(user, membershipId) {
  const { data, error } = await user.client.rpc("leave_project", {
    p_expected_participant_profile_id: user.id,
    p_membership_id: membershipId,
  });
  if (error || data !== membershipId) {
    throw safeDatabaseFailure("leave a Project membership", error ?? {});
  }
}

async function setManualCoverage(creator, projectId, requirementId, isCovered) {
  const { data, error } = await creator.client.rpc(
    "set_project_requirement_manual_coverage",
    {
      p_expected_creator_profile_id: creator.id,
      p_project_id: projectId,
      p_requirement_kind: "resource",
      p_requirement_id: requirementId,
      p_is_covered: isCovered,
    },
  );
  if (error || data !== requirementId) {
    throw safeDatabaseFailure("set manual Project coverage", error ?? {});
  }
}

async function claimRequirement(
  participant,
  projectId,
  requirementId,
  expectedMembershipId,
) {
  const { data, error } = await participant.client.rpc(
    "claim_project_requirement",
    {
      p_expected_participant_profile_id: participant.id,
      p_project_id: projectId,
      p_requirement_kind: "resource",
      p_requirement_id: requirementId,
    },
  );
  if (error || data !== expectedMembershipId) {
    throw safeDatabaseFailure("claim a Project requirement", error ?? {});
  }
}

async function sendMessage(user, chatId) {
  const { data, error } = await user.client.rpc("send_project_chat_message", {
    p_expected_profile_id: user.id,
    p_chat_id: chatId,
    p_body: "Human signal regression",
  });
  if (error || data?.length !== 1) {
    throw safeDatabaseFailure("send a human Project-chat message", error ?? {});
  }
  return data[0];
}

async function ensureCompleteProfile(user, displayName) {
  const { error: anchorError } = await user.client
    .from("profiles")
    .insert({ id: user.id });
  if (anchorError) {
    const diagnostic = `${anchorError.message ?? ""} ${anchorError.details ?? ""}`;
    if (anchorError.code !== "23505" || !diagnostic.includes("profiles_pkey")) {
      throw safeDatabaseFailure("create a resurfacing profile", anchorError);
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
    throw safeDatabaseFailure("complete a resurfacing profile", updateError);
  }
}

async function setAuthenticatedTransaction(transaction, profileId) {
  await transaction`set local role authenticated`;
  await transaction`
    select set_config('request.jwt.claim.sub', ${profileId}, true)
  `;
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

function projectChatTopic(chatId, profileId) {
  return `project-chat:${chatId}:profile:${profileId}`;
}

function signIn(email) {
  return signInLocalOtpUser({
    apiUrl,
    publishableKey,
    mailpitUrl,
    email,
    verifierName: "Project need-resurfacing verifier",
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
