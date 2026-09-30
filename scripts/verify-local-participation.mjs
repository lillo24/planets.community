import { createClient } from "@supabase/supabase-js";

import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";
import { ensureLocalProfilePhoto } from "./lib/local-profile-photo.mjs";

const repositoryRoot = process.cwd();
const mailpitUrl = (
  process.env.MAILPIT_URL ?? "http://127.0.0.1:54324"
).replace(/\/$/, "");
const { apiUrl, publishableKey } = readLocalSupabaseStatus(repositoryRoot);
const referenceTime = "2098-01-01T00:00:00.000Z";

await verifyParticipation();

async function verifyParticipation() {
  const [creator, requester, unrelated] = await Promise.all([
    signInWithLocalOtp("participation-local-a@planets.invalid"),
    signInWithLocalOtp("participation-local-b@planets.invalid"),
    signInWithLocalOtp("participation-local-c@planets.invalid"),
  ]);
  await Promise.all([
    ensureCompleteProfile(creator, "Participation Creator"),
    ensureCompleteProfile(requester, "Participation Requester"),
    ensureCompleteProfile(unrelated, "Participation Unrelated"),
  ]);
  await Promise.all(
    [creator, requester, unrelated].map((user) =>
      ensureLocalProfilePhoto(user),
    ),
  );

  const anonymous = createClient(apiUrl, publishableKey, {
    auth: { persistSession: false },
  });
  const proposalSecret = "Protected one-time meeting instructions";
  const tavoloSecret = "Protected recurring meeting instructions";
  const proposalId = await createProposal(creator, proposalSecret);
  const tavoloId = await createTavolo(creator, tavoloSecret);

  await assertAnonymousBoundaries(
    anonymous,
    proposalId,
    tavoloId,
    proposalSecret,
    tavoloSecret,
  );

  const proposalRequestId = await requestToJoin(
    requester,
    proposalId,
    "I can help with this project.",
  );
  await assertOwnRequest(requester, proposalRequestId, "one_time", "pending");

  const { data: unrelatedRequests, error: unrelatedRequestsError } =
    await unrelated.client.rpc("list_own_project_join_requests", {
      p_expected_requester_profile_id: unrelated.id,
    });
  if (unrelatedRequestsError || unrelatedRequests?.length !== 0) {
    throw new Error(
      "An unrelated user could read another user's join request.",
    );
  }
  const { error: unrelatedCreatorReadError } = await unrelated.client.rpc(
    "list_project_join_requests",
    {
      p_expected_creator_profile_id: unrelated.id,
      p_project_id: proposalId,
    },
  );
  if (unrelatedCreatorReadError?.code !== "42501") {
    throw new Error("An unrelated user could read creator-private requests.");
  }
  const { error: staleWithdrawError } = await unrelated.client.rpc(
    "withdraw_project_join_request",
    {
      p_expected_requester_profile_id: requester.id,
      p_request_id: proposalRequestId,
    },
  );
  if (staleWithdrawError?.code !== "42501") {
    throw new Error("A stale requester identity was not rejected.");
  }

  const { data: creatorRequests, error: creatorRequestsError } =
    await creator.client.rpc("list_project_join_requests", {
      p_expected_creator_profile_id: creator.id,
      p_project_id: proposalId,
    });
  const creatorRequest = creatorRequests?.find(
    (request) => request.request_id === proposalRequestId,
  );
  if (
    creatorRequestsError ||
    !creatorRequest ||
    creatorRequest.requester_profile_id !== requester.id ||
    creatorRequest.requester_display_name !== "Participation Requester" ||
    creatorRequest.request_message !== "I can help with this project."
  ) {
    throw new Error("The creator could not review the private request safely.");
  }

  const proposalMembershipId = await acceptRequestRace(
    creator,
    proposalRequestId,
  );
  await assertOneMembership(requester, proposalMembershipId, proposalId);
  await assertMeetingAccess(requester, proposalId, proposalSecret, true);

  const { error: staleRemovalError } = await unrelated.client.rpc(
    "remove_project_member",
    {
      p_expected_creator_profile_id: creator.id,
      p_membership_id: proposalMembershipId,
    },
  );
  if (staleRemovalError?.code !== "42501") {
    throw new Error("A stale creator identity was not rejected.");
  }

  await leaveMembership(requester, proposalMembershipId);
  await assertMeetingAccess(requester, proposalId, proposalSecret, false);
  const proposalRetryId = await requestToJoin(requester, proposalId, null);
  const { error: rejectError } = await creator.client.rpc(
    "reject_project_join_request",
    {
      p_expected_creator_profile_id: creator.id,
      p_request_id: proposalRetryId,
    },
  );
  if (rejectError) {
    throw safeDatabaseFailure(
      "reject a repeated proposal request",
      rejectError,
    );
  }
  await assertOwnRequest(requester, proposalRetryId, "one_time", "rejected");

  const tavoloRequestId = await requestToJoin(requester, tavoloId, null);
  const tavoloMembershipId = await acceptRequest(creator, tavoloRequestId);
  await assertOneMembership(requester, tavoloMembershipId, tavoloId);
  await assertMeetingAccess(requester, tavoloId, tavoloSecret, true);

  await transitionTavolo(creator, "pause_recurring_activity", tavoloId);
  const { error: pausedRequestError } = await unrelated.client.rpc(
    "request_to_join_project",
    {
      p_expected_requester_profile_id: unrelated.id,
      p_project_id: tavoloId,
      p_request_message: null,
    },
  );
  if (pausedRequestError?.code !== "55000") {
    throw new Error("A paused Tavolo accepted a new participation request.");
  }
  await assertMeetingAccess(requester, tavoloId, tavoloSecret, true);

  await transitionTavolo(creator, "resume_recurring_activity", tavoloId);
  await assertOneMembership(requester, tavoloMembershipId, tavoloId);
  const { error: removeError } = await creator.client.rpc(
    "remove_project_member",
    {
      p_expected_creator_profile_id: creator.id,
      p_membership_id: tavoloMembershipId,
    },
  );
  if (removeError) {
    throw safeDatabaseFailure("remove a Tavolo participant", removeError);
  }
  await assertMeetingAccess(requester, tavoloId, tavoloSecret, false);
  const postRemovalRequestId = await requestToJoin(requester, tavoloId, null);
  await assertOwnRequest(
    requester,
    postRemovalRequestId,
    "recurring",
    "pending",
  );

  await transitionTavolo(creator, "end_recurring_activity", tavoloId);
  const { data: tavoloHistory, error: tavoloHistoryError } =
    await requester.client.rpc("list_own_project_memberships", {
      p_expected_participant_profile_id: requester.id,
    });
  const endedMembership = tavoloHistory?.find(
    (membership) => membership.membership_id === tavoloMembershipId,
  );
  if (
    tavoloHistoryError ||
    !endedMembership ||
    endedMembership.membership_status !== "removed"
  ) {
    throw new Error("Ending a Tavolo did not preserve participation history.");
  }
  const { error: endedRequestError } = await unrelated.client.rpc(
    "request_to_join_project",
    {
      p_expected_requester_profile_id: unrelated.id,
      p_project_id: tavoloId,
      p_request_message: null,
    },
  );
  if (endedRequestError?.code !== "55000") {
    throw new Error("An ended Tavolo accepted a new participation request.");
  }

  console.log(
    "Confirmed private multi-user participation, lifecycle-safe requests and decisions, retained membership history, protected meeting access, stale-identity rejection, and unchanged anonymous discovery for Proposals and Tavoli.",
  );
}

async function createProposal(creator, exactMeetingText) {
  const { data, error } = await creator.client.rpc("create_proposal_draft", {
    p_expected_creator_profile_id: creator.id,
    p_title: "Integration participation proposal",
    p_summary: "A deterministic proposal for participation verification.",
    p_description:
      "This project verifies request, membership, and meeting authorization rules.",
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
    throw safeDatabaseFailure("create the participation proposal", error ?? {});
  }
  const { error: publishError } = await creator.client.rpc("publish_proposal", {
    p_expected_creator_profile_id: creator.id,
    p_proposal_id: data,
  });
  if (publishError) {
    throw safeDatabaseFailure(
      "publish the participation proposal",
      publishError,
    );
  }
  return data;
}

async function createTavolo(creator, exactMeetingText) {
  const { data, error } = await creator.client.rpc(
    "create_recurring_activity_draft",
    {
      p_expected_creator_profile_id: creator.id,
      p_title: "Integration participation Tavolo",
      p_summary: "A deterministic Tavolo for participation verification.",
      p_description:
        "This recurring project verifies shared participation authorization.",
      p_topic: "Community",
      p_country_code: "IT",
      p_locality: "Trento",
      p_administrative_area: "Povo",
      p_public_location_label: "Trento · Povo",
      p_exact_meeting_text: exactMeetingText,
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
    throw safeDatabaseFailure("create the participation Tavolo", error ?? {});
  }
  await transitionTavolo(creator, "publish_recurring_activity", data);
  return data;
}

async function requestToJoin(user, projectId, requestMessage) {
  const { data, error } = await user.client.rpc("request_to_join_project", {
    p_expected_requester_profile_id: user.id,
    p_project_id: projectId,
    p_request_message: requestMessage,
  });
  if (error || typeof data !== "string") {
    throw safeDatabaseFailure("request project participation", error ?? {});
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
    throw safeDatabaseFailure("accept a participation request", error ?? {});
  }
  return data;
}

async function acceptRequestRace(creator, requestId) {
  const attempts = await Promise.all(
    [0, 1].map(() =>
      creator.client.rpc("accept_project_join_request", {
        p_expected_creator_profile_id: creator.id,
        p_request_id: requestId,
      }),
    ),
  );
  const successes = attempts.filter(
    (attempt) => !attempt.error && typeof attempt.data === "string",
  );
  const rejected = attempts.filter(
    (attempt) => attempt.error?.code === "55000",
  );
  if (successes.length !== 1 || rejected.length !== 1) {
    throw new Error("Concurrent acceptance did not resolve to one membership.");
  }
  return successes[0].data;
}

async function leaveMembership(user, membershipId) {
  const { error } = await user.client.rpc("leave_project", {
    p_expected_participant_profile_id: user.id,
    p_membership_id: membershipId,
  });
  if (error) {
    throw safeDatabaseFailure("leave a project membership", error);
  }
}

async function assertOwnRequest(user, requestId, projectKind, status) {
  const { data, error } = await user.client.rpc(
    "list_own_project_join_requests",
    { p_expected_requester_profile_id: user.id },
  );
  const request = data?.find((candidate) => candidate.request_id === requestId);
  if (
    error ||
    !request ||
    request.project_kind !== projectKind ||
    request.status !== status
  ) {
    throw new Error("Own participation request history was inconsistent.");
  }
}

async function assertOneMembership(user, membershipId, projectId) {
  const { data, error } = await user.client.rpc(
    "list_own_project_memberships",
    { p_expected_participant_profile_id: user.id },
  );
  const matches = data?.filter(
    (membership) =>
      membership.membership_id === membershipId &&
      membership.project_id === projectId,
  );
  if (error || matches?.length !== 1) {
    throw new Error("Acceptance did not produce exactly one membership.");
  }
}

async function assertMeetingAccess(user, projectId, secret, expected) {
  const { data, error } = await user.client.rpc(
    "get_project_participant_meeting_details",
    {
      p_expected_profile_id: user.id,
      p_project_id: projectId,
    },
  );
  if (expected) {
    if (error || data?.length !== 1 || data[0].exact_meeting_text !== secret) {
      throw new Error("An authorized participant could not read meeting data.");
    }
  } else if (error?.code !== "42501" || data !== null) {
    throw new Error("A former participant retained protected meeting access.");
  }
}

async function assertAnonymousBoundaries(
  anonymous,
  proposalId,
  tavoloId,
  proposalSecret,
  tavoloSecret,
) {
  const { data: registryRows, error: registryError } = await anonymous
    .from("projects")
    .select("id");
  if (!registryError || registryRows !== null) {
    throw new Error("Anonymous registry enumeration did not fail closed.");
  }

  const [proposalResult, proposalListResult, tavoloResult, tavoloListResult] =
    await Promise.all([
      anonymous.rpc("get_public_proposal", { p_proposal_id: proposalId }),
      anonymous.rpc("list_public_proposals", {
        p_limit: 20,
        p_cursor_starts_at: null,
        p_cursor_id: null,
        p_locality: "Trento",
        p_skill_ids: null,
      }),
      anonymous.rpc("get_public_recurring_activity", {
        p_recurring_activity_id: tavoloId,
        p_occurrence_limit: 3,
        p_reference_time: referenceTime,
      }),
      anonymous.rpc("list_public_recurring_activities", {
        p_reference_time: referenceTime,
        p_limit: 20,
        p_cursor_next_starts_at: null,
        p_cursor_id: null,
        p_locality: "Trento",
      }),
    ]);
  const proposalCard = proposalListResult.data?.find(
    (proposal) => proposal.proposal_id === proposalId,
  );
  const tavoloCard = tavoloListResult.data?.find(
    (tavolo) => tavolo.recurring_activity_id === tavoloId,
  );
  if (
    proposalResult.error ||
    proposalResult.data?.length !== 1 ||
    proposalResult.data[0].exact_meeting_text !== null ||
    JSON.stringify(proposalResult.data).includes(proposalSecret) ||
    proposalListResult.error ||
    !proposalCard ||
    JSON.stringify(proposalCard).includes(proposalSecret) ||
    tavoloResult.error ||
    tavoloResult.data?.length !== 1 ||
    tavoloResult.data[0].exact_meeting_text !== null ||
    JSON.stringify(tavoloResult.data).includes(tavoloSecret) ||
    tavoloListResult.error ||
    !tavoloCard ||
    JSON.stringify(tavoloCard).includes(tavoloSecret)
  ) {
    throw new Error("Existing anonymous discovery/detail privacy changed.");
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
      throw safeDatabaseFailure("create a participation profile", anchorError);
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
    throw safeDatabaseFailure("complete a participation profile", updateError);
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
      "request a local participation OTP",
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
    "read a local participation OTP email",
  );
  const messageBody = `${message.Text ?? ""} ${message.HTML ?? ""}`;
  const token = messageBody.match(/(?:^|\D)(\d{6})(?:\D|$)/)?.[1];
  if (!token) {
    throw new Error(
      "A local participation email did not contain a 6-digit token.",
    );
  }

  const { data: verification, error: verificationError } =
    await client.auth.verifyOtp({ email, token, type: "email" });
  if (verificationError || !verification.user?.id || !verification.session) {
    throw safeDatabaseFailure(
      "verify a local participation OTP",
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
    "Mailpit did not receive a participation OTP within 15 seconds.",
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
