import { createClient } from "@supabase/supabase-js";

import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";

const repositoryRoot = process.cwd();
const mailpitUrl = (
  process.env.MAILPIT_URL ?? "http://127.0.0.1:54324"
).replace(/\/$/, "");
const { apiUrl, publishableKey } = readLocalSupabaseStatus(repositoryRoot);

await verifyMessages();

async function verifyMessages() {
  const [creator, requester, unrelated] = await Promise.all([
    signInWithLocalOtp("messages-local-a@planets.invalid"),
    signInWithLocalOtp("messages-local-b@planets.invalid"),
    signInWithLocalOtp("messages-local-c@planets.invalid"),
  ]);
  await Promise.all([
    ensureCompleteProfile(creator, "Messages Creator"),
    ensureCompleteProfile(requester, "Messages Requester"),
    ensureCompleteProfile(unrelated, "Messages Unrelated"),
  ]);

  const anonymous = createClient(apiUrl, publishableKey, {
    auth: { persistSession: false },
  });
  const proposalId = await createProposal(creator);
  const tavoloId = await createTavolo(creator);
  const proposalMessage = "Private Messages proposal request.";
  const tavoloMessage = "Private Messages Tavolo request.";
  const proposalRequestId = await requestToJoin(
    requester,
    proposalId,
    proposalMessage,
  );

  const requesterItem = await getMessageItem(requester, proposalRequestId);
  const creatorItem = await getMessageItem(creator, proposalRequestId);
  if (
    requesterItem.viewer_role !== "requester" ||
    creatorItem.viewer_role !== "creator" ||
    requesterItem.request_message !== proposalMessage ||
    creatorItem.request_message !== proposalMessage ||
    requesterItem.project_kind !== "one_time" ||
    requesterItem.project_title !== "Integration Messages proposal" ||
    requesterItem.requester_display_name !== "Messages Requester" ||
    requesterItem.creator_display_name !== "Messages Creator"
  ) {
    throw new Error(
      "Authorized structured Proposal message context was wrong.",
    );
  }
  assertNarrowItem(requesterItem);

  const { data: unrelatedInbox, error: unrelatedInboxError } =
    await unrelated.client.rpc(
      "list_own_participation_request_message_items",
      messageListParams(unrelated.id),
    );
  if (unrelatedInboxError || unrelatedInbox?.length !== 0) {
    throw new Error("An unrelated user could read a participation message.");
  }
  const existingDenial = await unrelated.client.rpc(
    "get_own_participation_request_message_item",
    {
      p_expected_profile_id: unrelated.id,
      p_request_id: proposalRequestId,
    },
  );
  const missingDenial = await unrelated.client.rpc(
    "get_own_participation_request_message_item",
    {
      p_expected_profile_id: unrelated.id,
      p_request_id: "00000000-0000-4000-8000-000000000099",
    },
  );
  if (
    existingDenial.error?.code !== "42501" ||
    missingDenial.error?.code !== "42501" ||
    existingDenial.error.message !== missingDenial.error.message
  ) {
    throw new Error("Exact Messages lookup did not fail closed uniformly.");
  }

  const { error: anonymousError } = await anonymous.rpc(
    "list_own_participation_request_message_items",
    messageListParams(null),
  );
  if (anonymousError?.code !== "42501") {
    throw new Error("Anonymous Messages access was not denied.");
  }

  const { data: proposalMembershipId, error: acceptError } =
    await creator.client.rpc("accept_project_join_request", {
      p_expected_creator_profile_id: creator.id,
      p_request_id: proposalRequestId,
    });
  if (acceptError || typeof proposalMembershipId !== "string") {
    throw safeDatabaseFailure("accept the Messages request", acceptError);
  }
  const [requesterAcceptedItem, creatorAcceptedItem] = await Promise.all([
    getMessageItem(requester, proposalRequestId),
    getMessageItem(creator, proposalRequestId),
  ]);
  if (
    requesterAcceptedItem.status !== "accepted" ||
    creatorAcceptedItem.status !== "accepted"
  ) {
    throw new Error(
      "An accepted request did not refresh canonically for both participants.",
    );
  }
  await assertMembership(requester, proposalMembershipId, proposalId);

  const tavoloRequestId = await requestToJoin(
    requester,
    tavoloId,
    tavoloMessage,
  );
  const { error: withdrawError } = await requester.client.rpc(
    "withdraw_project_join_request",
    {
      p_expected_requester_profile_id: requester.id,
      p_request_id: tavoloRequestId,
    },
  );
  if (withdrawError) {
    throw safeDatabaseFailure("withdraw the Messages request", withdrawError);
  }
  const [tavoloItem, creatorTavoloItem] = await Promise.all([
    getMessageItem(requester, tavoloRequestId),
    getMessageItem(creator, tavoloRequestId),
  ]);
  if (
    tavoloItem.project_kind !== "recurring" ||
    tavoloItem.project_title !== "Integration Messages Tavolo" ||
    tavoloItem.status !== "withdrawn" ||
    tavoloItem.request_message !== tavoloMessage ||
    creatorTavoloItem.status !== "withdrawn"
  ) {
    throw new Error("Structured Tavolo message history was inconsistent.");
  }

  const { data: requesterInbox, error: requesterInboxError } =
    await requester.client.rpc(
      "list_own_participation_request_message_items",
      messageListParams(requester.id),
    );
  if (
    requesterInboxError ||
    requesterInbox?.length !== 2 ||
    !requesterInbox.every((item) => item.viewer_role === "requester") ||
    requesterInbox[0].request_id !== tavoloRequestId
  ) {
    throw new Error("Requester Messages chronology was inconsistent.");
  }

  const [publicProposal, publicTavolo] = await Promise.all([
    anonymous.rpc("get_public_proposal", {
      p_proposal_id: proposalId,
    }),
    anonymous.rpc("get_public_recurring_activity", {
      p_recurring_activity_id: tavoloId,
      p_occurrence_limit: 3,
      p_reference_time: "2098-01-01T00:00:00.000Z",
    }),
  ]);
  const publicPayload = JSON.stringify([
    publicProposal.data,
    publicTavolo.data,
  ]);
  if (
    publicProposal.error ||
    publicTavolo.error ||
    publicPayload.includes(proposalMessage) ||
    publicPayload.includes(tavoloMessage)
  ) {
    throw new Error("A private request message reached public project data.");
  }

  console.log(
    "Confirmed creator/requester-only structured Messages, fail-closed unrelated and anonymous access, canonical Accept/Withdraw history, Proposal/Tavolo context, stable chronology, and unchanged public privacy.",
  );
}

function messageListParams(expectedProfileId) {
  return {
    p_expected_profile_id: expectedProfileId,
    p_limit: 20,
    p_cursor_activity_at: null,
    p_cursor_request_id: null,
  };
}

async function getMessageItem(user, requestId) {
  const { data, error } = await user.client.rpc(
    "get_own_participation_request_message_item",
    { p_expected_profile_id: user.id, p_request_id: requestId },
  );
  if (error || data?.length !== 1) {
    throw safeDatabaseFailure("read a structured Messages item", error ?? {});
  }
  return data[0];
}

async function assertMembership(user, membershipId, projectId) {
  const { data, error } = await user.client.rpc(
    "list_own_project_memberships",
    {
      p_expected_participant_profile_id: user.id,
    },
  );
  const matches = data?.filter(
    (membership) =>
      membership.membership_id === membershipId &&
      membership.project_id === projectId &&
      membership.membership_status === "current",
  );
  if (error || matches?.length !== 1) {
    throw new Error(
      "Messages acceptance did not produce one current membership.",
    );
  }
}

function assertNarrowItem(item) {
  const expectedKeys = [
    "activity_at",
    "created_at",
    "creator_display_name",
    "creator_profile_id",
    "project_id",
    "project_kind",
    "project_title",
    "request_id",
    "request_message",
    "requester_display_name",
    "requester_profile_id",
    "resolved_at",
    "status",
    "viewer_role",
  ];
  const keys = Object.keys(item).sort();
  if (JSON.stringify(keys) !== JSON.stringify(expectedKeys)) {
    throw new Error("The Messages item exposed an unexpected field.");
  }
}

async function createProposal(creator) {
  const { data, error } = await creator.client.rpc("create_proposal_draft", {
    p_expected_creator_profile_id: creator.id,
    p_title: "Integration Messages proposal",
    p_summary: "A deterministic proposal for Messages verification.",
    p_description:
      "This project verifies structured participation request Messages.",
    p_starts_at: "2098-01-02T10:00:00.000Z",
    p_ends_at: "2098-01-02T14:00:00.000Z",
    p_event_timezone: "Europe/Rome",
    p_country_code: "IT",
    p_locality: "Trento",
    p_administrative_area: "Povo",
    p_public_location_label: "Trento · Povo",
    p_exact_meeting_text: "Private proposal meeting location",
    p_exact_location_visibility: "participants",
    p_skill_ids: [],
    p_skill_importances: [],
  });
  if (error || typeof data !== "string") {
    throw safeDatabaseFailure("create the Messages proposal", error ?? {});
  }
  const { error: publishError } = await creator.client.rpc("publish_proposal", {
    p_expected_creator_profile_id: creator.id,
    p_proposal_id: data,
  });
  if (publishError) {
    throw safeDatabaseFailure("publish the Messages proposal", publishError);
  }
  return data;
}

async function createTavolo(creator) {
  const { data, error } = await creator.client.rpc(
    "create_recurring_activity_draft",
    {
      p_expected_creator_profile_id: creator.id,
      p_title: "Integration Messages Tavolo",
      p_summary: "A deterministic Tavolo for Messages verification.",
      p_description:
        "This recurring project verifies structured participation Messages.",
      p_topic: "Community",
      p_country_code: "IT",
      p_locality: "Trento",
      p_administrative_area: "Povo",
      p_public_location_label: "Trento · Povo",
      p_exact_meeting_text: "Private Tavolo meeting location",
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
    throw safeDatabaseFailure("create the Messages Tavolo", error ?? {});
  }
  const { error: publishError } = await creator.client.rpc(
    "publish_recurring_activity",
    {
      p_expected_creator_profile_id: creator.id,
      p_recurring_activity_id: data,
    },
  );
  if (publishError) {
    throw safeDatabaseFailure("publish the Messages Tavolo", publishError);
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
      "request participation for Messages",
      error ?? {},
    );
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
      throw safeDatabaseFailure("create a Messages profile", anchorError);
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
    throw safeDatabaseFailure("complete a Messages profile", updateError);
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
    throw safeDatabaseFailure("request a local Messages OTP", requestError);
  }
  const messageId = await waitForNewMessage(
    email,
    existingMessageIds,
    requestStartedAt,
  );
  const message = await fetchJson(
    `${mailpitUrl}/api/v1/message/${encodeURIComponent(messageId)}`,
    {},
    "read a local Messages OTP email",
  );
  const body = `${message.Text ?? ""} ${message.HTML ?? ""}`;
  const token = body.match(/(?:^|\D)(\d{6})(?:\D|$)/)?.[1];
  if (!token) {
    throw new Error("A local Messages email did not contain a 6-digit token.");
  }
  const { data: verification, error: verificationError } =
    await client.auth.verifyOtp({ email, token, type: "email" });
  if (verificationError || !verification.user?.id || !verification.session) {
    throw safeDatabaseFailure(
      "verify a local Messages OTP",
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
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
  throw new Error("Mailpit did not receive a Messages OTP within 15 seconds.");
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
