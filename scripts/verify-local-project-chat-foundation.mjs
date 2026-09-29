import postgres from "postgres";
import { createClient } from "@supabase/supabase-js";

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

const sql = postgres(databaseUrl, { max: 4 });

try {
  await verifyProjectChatFoundation();
} finally {
  await sql.end();
}

async function verifyProjectChatFoundation() {
  const [creator, participantA, participantB, unrelated] = await Promise.all([
    signInWithLocalOtp("chat-foundation-creator@planets.invalid"),
    signInWithLocalOtp("chat-foundation-a@planets.invalid"),
    signInWithLocalOtp("chat-foundation-b@planets.invalid"),
    signInWithLocalOtp("chat-foundation-unrelated@planets.invalid"),
  ]);
  await Promise.all([
    ensureCompleteProfile(creator, "Chat Foundation Creator"),
    ensureCompleteProfile(participantA, "Chat Foundation A"),
    ensureCompleteProfile(participantB, "Chat Foundation B"),
    ensureCompleteProfile(unrelated, "Chat Foundation Unrelated"),
  ]);

  const proposalId = await createProposal(
    creator,
    "Integration Project chat foundation",
  );
  await assertChatUnavailable(creator, proposalId);
  await assertChatCount(proposalId, 0);

  const requestA = await requestToJoin(participantA, proposalId);
  await assertChatCount(proposalId, 0);
  const membershipAOne = await acceptRequest(creator, requestA);
  const creatorChat = await getChat(creator, proposalId);
  const participantAChat = await getChat(participantA, proposalId);
  assertNarrowChat(creatorChat);
  if (
    creatorChat.viewer_role !== "creator" ||
    !creatorChat.has_current_entitlement ||
    !creatorChat.has_history_entitlement ||
    participantAChat.viewer_role !== "current_member" ||
    !participantAChat.has_current_entitlement ||
    !participantAChat.has_history_entitlement ||
    participantAChat.chat_id !== creatorChat.chat_id ||
    creatorChat.project_kind !== "one_time"
  ) {
    throw new Error("First acceptance produced incorrect chat entitlement.");
  }

  const requestB = await requestToJoin(participantB, proposalId);
  const membershipB = await acceptRequest(creator, requestB);
  const participantBChat = await getChat(participantB, proposalId);
  if (
    participantBChat.chat_id !== creatorChat.chat_id ||
    participantBChat.viewer_role !== "current_member"
  ) {
    throw new Error("A later acceptance did not reuse the canonical chat.");
  }
  await assertChatCount(proposalId, 1);

  await leaveMembership(participantA, membershipAOne);
  const formerAfterLeave = await getChat(participantA, proposalId);
  if (
    formerAfterLeave.viewer_role !== "former_member" ||
    formerAfterLeave.has_current_entitlement ||
    !formerAfterLeave.has_history_entitlement
  ) {
    throw new Error("Voluntary leave produced incorrect chat entitlement.");
  }
  await assertEndedInterval(membershipAOne, "left_at");

  const rejoinRequestA = await requestToJoin(participantA, proposalId);
  const membershipATwo = await acceptRequest(creator, rejoinRequestA);
  const rejoinedChat = await getChat(participantA, proposalId);
  if (
    rejoinedChat.chat_id !== creatorChat.chat_id ||
    rejoinedChat.viewer_role !== "current_member" ||
    !rejoinedChat.has_current_entitlement
  ) {
    throw new Error("Rejoin did not restore the existing chat entitlement.");
  }
  await assertMembershipGap(
    proposalId,
    participantA.id,
    membershipAOne,
    membershipATwo,
  );

  await removeMembership(creator, membershipATwo);
  const formerAfterRemoval = await getChat(participantA, proposalId);
  if (
    formerAfterRemoval.viewer_role !== "former_member" ||
    formerAfterRemoval.has_current_entitlement ||
    !formerAfterRemoval.has_history_entitlement
  ) {
    throw new Error("Creator removal produced incorrect chat entitlement.");
  }
  await assertEndedInterval(membershipATwo, "removed_at");

  const existingDenial = await unrelated.client.rpc(
    "get_own_project_group_chat",
    {
      p_expected_profile_id: unrelated.id,
      p_project_id: proposalId,
    },
  );
  const missingDenial = await unrelated.client.rpc(
    "get_own_project_group_chat",
    {
      p_expected_profile_id: unrelated.id,
      p_project_id: "00000000-0000-4000-8000-000000000099",
    },
  );
  if (
    existingDenial.error?.code !== "42501" ||
    missingDenial.error?.code !== "42501" ||
    existingDenial.error.message !== missingDenial.error.message
  ) {
    throw new Error("Unrelated and missing chat reads did not fail uniformly.");
  }

  await removeMembership(creator, membershipB);
  await assertChatCount(proposalId, 1);
  const retainedCreatorChat = await getChat(creator, proposalId);
  if (retainedCreatorChat.chat_id !== creatorChat.chat_id) {
    throw new Error("Ending every participant membership deleted the chat.");
  }

  const raceProposalId = await createProposal(
    creator,
    "Integration Project chat acceptance race",
  );
  const [raceRequestA, raceRequestX] = await Promise.all([
    requestToJoin(participantA, raceProposalId),
    requestToJoin(unrelated, raceProposalId),
  ]);
  const raceAcceptances = await Promise.all([
    creator.client.rpc("accept_project_join_request", {
      p_expected_creator_profile_id: creator.id,
      p_request_id: raceRequestA,
    }),
    creator.client.rpc("accept_project_join_request", {
      p_expected_creator_profile_id: creator.id,
      p_request_id: raceRequestX,
    }),
  ]);
  if (
    raceAcceptances.some(
      (result) => result.error || typeof result.data !== "string",
    )
  ) {
    throw new Error("Concurrent first acceptances did not both commit safely.");
  }
  const [raceCounts] = await sql`
    select
      (select count(*)::integer from public.project_group_chats where project_id = ${raceProposalId}) as chat_count,
      (select count(*)::integer from public.project_memberships where project_id = ${raceProposalId}) as membership_count
  `;
  if (raceCounts.chat_count !== 1 || raceCounts.membership_count !== 2) {
    throw new Error(
      "Concurrent acceptance created duplicate or missing state.",
    );
  }

  const tavoloId = await createTavolo(creator);
  const tavoloRequest = await requestToJoin(participantB, tavoloId);
  await acceptRequest(creator, tavoloRequest);
  const tavoloChat = await getChat(participantB, tavoloId);
  if (
    tavoloChat.project_kind !== "recurring" ||
    tavoloChat.viewer_role !== "current_member"
  ) {
    throw new Error("Tavolo activation did not use the shared Project domain.");
  }
  await transitionTavolo(creator, "pause_recurring_activity", tavoloId);
  await assertChatId(tavoloId, tavoloChat.chat_id);
  await transitionTavolo(creator, "resume_recurring_activity", tavoloId);
  await transitionTavolo(creator, "end_recurring_activity", tavoloId);
  await assertChatId(tavoloId, tavoloChat.chat_id);

  console.log(
    "Confirmed first-accept Project/Tavolo chat activation, one-chat concurrency, creator/current/former entitlement, half-open leave/removal and rejoin intervals, unrelated-user denial, and lifecycle retention.",
  );
}

async function assertChatCount(projectId, expectedCount) {
  const [result] = await sql`
    select count(*)::integer as chat_count
    from public.project_group_chats
    where project_id = ${projectId}
  `;
  if (result.chat_count !== expectedCount) {
    throw new Error("Project chat count did not match its lifecycle state.");
  }
}

async function assertChatId(projectId, expectedChatId) {
  const [result] = await sql`
    select id
    from public.project_group_chats
    where project_id = ${projectId}
  `;
  if (result?.id !== expectedChatId) {
    throw new Error("Project lifecycle changed the canonical chat identity.");
  }
}

async function assertEndedInterval(membershipId, endColumn) {
  if (endColumn !== "left_at" && endColumn !== "removed_at") {
    throw new Error("Unsupported membership end column in chat verification.");
  }
  const [result] = await sql`
    select
      private.profile_was_project_member_at(
        membership.project_id,
        membership.participant_profile_id,
        membership.joined_at - interval '1 microsecond'
      ) as before_join,
      private.profile_was_project_member_at(
        membership.project_id,
        membership.participant_profile_id,
        membership.joined_at
      ) as at_join,
      private.profile_was_project_member_at(
        membership.project_id,
        membership.participant_profile_id,
        coalesce(membership.left_at, membership.removed_at)
      ) as at_end,
      membership.left_at is not null as was_left,
      membership.removed_at is not null as was_removed
    from public.project_memberships as membership
    where membership.id = ${membershipId}
  `;
  const expectedLeft = endColumn === "left_at";
  if (
    !result ||
    result.before_join ||
    !result.at_join ||
    result.at_end ||
    result.was_left !== expectedLeft ||
    result.was_removed === expectedLeft
  ) {
    throw new Error(
      "Ended membership did not use half-open interval semantics.",
    );
  }
}

async function assertMembershipGap(
  projectId,
  profileId,
  firstMembershipId,
  secondMembershipId,
) {
  const [result] = await sql`
    select
      first_membership.left_at < second_membership.joined_at as has_gap,
      private.profile_was_project_member_at(
        ${projectId},
        ${profileId},
        first_membership.left_at + (
          (second_membership.joined_at - first_membership.left_at) / 2
        )
      ) as member_in_gap,
      private.profile_was_project_member_at(
        ${projectId},
        ${profileId},
        second_membership.joined_at
      ) as member_at_rejoin
    from public.project_memberships as first_membership
    join public.project_memberships as second_membership
      on second_membership.id = ${secondMembershipId}
    where first_membership.id = ${firstMembershipId}
  `;
  if (!result?.has_gap || result.member_in_gap || !result.member_at_rejoin) {
    throw new Error(
      "Rejoin did not preserve a distinguishable membership gap.",
    );
  }
}

async function getChat(user, projectId) {
  const { data, error } = await user.client.rpc("get_own_project_group_chat", {
    p_expected_profile_id: user.id,
    p_project_id: projectId,
  });
  if (error || data?.length !== 1) {
    throw safeDatabaseFailure("resolve own Project group chat", error ?? {});
  }
  return data[0];
}

async function assertChatUnavailable(user, projectId) {
  const { data, error } = await user.client.rpc("get_own_project_group_chat", {
    p_expected_profile_id: user.id,
    p_project_id: projectId,
  });
  if (error?.code !== "42501" || data !== null) {
    throw new Error("A chat was available before its first accepted member.");
  }
}

function assertNarrowChat(chat) {
  const expectedKeys = [
    "activated_at",
    "chat_id",
    "has_current_entitlement",
    "has_history_entitlement",
    "project_id",
    "project_kind",
    "viewer_role",
  ];
  if (
    JSON.stringify(Object.keys(chat).sort()) !== JSON.stringify(expectedKeys)
  ) {
    throw new Error("The chat anchor exposed an unexpected field.");
  }
}

async function createProposal(creator, title) {
  const { data, error } = await creator.client.rpc("create_proposal_draft", {
    p_expected_creator_profile_id: creator.id,
    p_title: title,
    p_summary: "A deterministic Proposal for chat foundation verification.",
    p_description:
      "This Project verifies lifecycle-derived group chat authorization.",
    p_starts_at: "2098-01-02T10:00:00.000Z",
    p_ends_at: "2098-01-02T14:00:00.000Z",
    p_event_timezone: "Europe/Rome",
    p_country_code: "IT",
    p_locality: "Trento",
    p_administrative_area: "Povo",
    p_public_location_label: "Trento · Povo",
    p_exact_meeting_text: "Private chat-foundation meeting location",
    p_exact_location_visibility: "participants",
    p_skill_ids: [],
    p_skill_importances: [],
    p_people_capacity: 20,
  });
  if (error || typeof data !== "string") {
    throw safeDatabaseFailure("create a chat-foundation Proposal", error ?? {});
  }
  const { error: publishError } = await creator.client.rpc("publish_proposal", {
    p_expected_creator_profile_id: creator.id,
    p_proposal_id: data,
  });
  if (publishError) {
    throw safeDatabaseFailure(
      "publish a chat-foundation Proposal",
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
      p_title: "Integration Project chat Tavolo",
      p_summary: "A deterministic Tavolo for chat foundation verification.",
      p_description:
        "This recurring Project verifies shared group-chat authorization.",
      p_topic: "Community",
      p_country_code: "IT",
      p_locality: "Trento",
      p_administrative_area: "Povo",
      p_public_location_label: "Trento · Povo",
      p_exact_meeting_text: "Private Tavolo chat-foundation location",
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
    throw safeDatabaseFailure("create a chat-foundation Tavolo", error ?? {});
  }
  await transitionTavolo(creator, "publish_recurring_activity", data);
  return data;
}

async function requestToJoin(user, projectId) {
  const { data, error } = await user.client.rpc("request_to_join_project", {
    p_expected_requester_profile_id: user.id,
    p_project_id: projectId,
    p_request_message: null,
  });
  if (error || typeof data !== "string") {
    throw safeDatabaseFailure(
      "request chat-foundation participation",
      error ?? {},
    );
  }
  return data;
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
    throw safeDatabaseFailure(
      "accept chat-foundation participation",
      error ?? {},
    );
  }
  return data;
}

async function leaveMembership(user, membershipId) {
  const { error } = await user.client.rpc("leave_project", {
    p_expected_participant_profile_id: user.id,
    p_membership_id: membershipId,
  });
  if (error) {
    throw safeDatabaseFailure("leave a chat-foundation membership", error);
  }
}

async function removeMembership(creator, membershipId) {
  const { error } = await creator.client.rpc("remove_project_member", {
    p_expected_creator_profile_id: creator.id,
    p_membership_id: membershipId,
  });
  if (error) {
    throw safeDatabaseFailure("remove a chat-foundation membership", error);
  }
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

async function ensureCompleteProfile(user, displayName) {
  const { error: anchorError } = await user.client
    .from("profiles")
    .insert({ id: user.id });
  if (anchorError) {
    const diagnostic = `${anchorError.message ?? ""} ${anchorError.details ?? ""}`;
    if (anchorError.code !== "23505" || !diagnostic.includes("profiles_pkey")) {
      throw safeDatabaseFailure(
        "create a chat-foundation profile",
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
      "complete a chat-foundation profile",
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
      "request a local chat-foundation OTP",
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
    "read a local chat-foundation OTP email",
  );
  const messageBody = `${message.Text ?? ""} ${message.HTML ?? ""}`;
  const token = messageBody.match(/(?:^|\D)(\d{6})(?:\D|$)/)?.[1];
  if (!token) {
    throw new Error(
      "A local chat-foundation email did not contain a 6-digit token.",
    );
  }

  const { data: verification, error: verificationError } =
    await client.auth.verifyOtp({ email, token, type: "email" });
  if (verificationError || !verification.user?.id || !verification.session) {
    throw safeDatabaseFailure(
      "verify a local chat-foundation OTP",
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
    "Mailpit did not receive a chat-foundation OTP within 15 seconds.",
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
