import { createClient } from "@supabase/supabase-js";

import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";
import { ensureLocalProfilePhoto } from "./lib/local-profile-photo.mjs";

const repositoryRoot = process.cwd();
const mailpitUrl = (
  process.env.MAILPIT_URL ?? "http://127.0.0.1:54324"
).replace(/\/$/, "");
const { apiUrl, publishableKey } = readLocalSupabaseStatus(repositoryRoot);
const referenceTime = "2098-01-01T00:00:00.000Z";
const muralSkillId = "d0000000-0000-4000-8001-000000000001";

await verifyParticipationAwareBrowse();

async function verifyParticipationAwareBrowse() {
  const [requester, other, creator] = await Promise.all([
    signInWithLocalOtp("participation-browse-a@planets.invalid"),
    signInWithLocalOtp("participation-browse-b@planets.invalid"),
    signInWithLocalOtp("participation-browse-c@planets.invalid"),
  ]);
  await Promise.all([
    ensureCompleteProfile(requester, "Browse Requester A"),
    ensureCompleteProfile(other, "Browse User B"),
    ensureCompleteProfile(creator, "Browse Creator C"),
  ]);
  await Promise.all(
    [requester, other, creator].map((user) => ensureLocalProfilePhoto(user)),
  );

  const runId = Date.now().toString(36);
  const locality = `Browse05D-${runId}`;
  const proposalSecret = `protected-proposal-${runId}`;
  const tavoloSecret = `protected-tavolo-${runId}`;
  const requestSecret = `private-request-${runId}`;

  const earliestProposalId = await createProposal(creator, {
    title: `Browse early ${runId}`,
    locality,
    startsAt: "2098-02-01T10:00:00.000Z",
    endsAt: "2098-02-01T12:00:00.000Z",
    exactMeetingText: proposalSecret,
    skillIds: [],
  });
  const acceptedProposalId = await createProposal(creator, {
    title: `Browse accepted ${runId}`,
    locality,
    startsAt: "2098-03-01T10:00:00.000Z",
    endsAt: "2098-03-01T12:00:00.000Z",
    exactMeetingText: proposalSecret,
    skillIds: [],
  });
  const requestedProposalId = await createProposal(creator, {
    title: `Browse requested ${runId}`,
    locality,
    startsAt: "2098-04-01T10:00:00.000Z",
    endsAt: "2098-04-01T12:00:00.000Z",
    exactMeetingText: proposalSecret,
    skillIds: [muralSkillId],
  });

  const publicBefore = await listPublicProposals(requester, locality);
  const publicIdsBefore = publicBefore.map((card) => card.proposal_id);
  if (
    publicIdsBefore.indexOf(earliestProposalId) === -1 ||
    publicIdsBefore.indexOf(requestedProposalId) <=
      publicIdsBefore.indexOf(earliestProposalId)
  ) {
    throw new Error(
      "The requested Proposal fixture was not later in ordinary public order.",
    );
  }

  const pendingProposalRequestId = await requestToJoin(
    requester,
    requestedProposalId,
    requestSecret,
  );
  const requestedProposals = await listRequestedProposals(
    requester,
    locality,
    null,
  );
  assertOnlyId(
    requestedProposals,
    "proposal_id",
    requestedProposalId,
    "pending requested Proposal",
  );
  assertSafeCards(requestedProposals, [proposalSecret, requestSecret]);

  const skillMatch = await listRequestedProposals(requester, locality, [
    muralSkillId,
  ]);
  assertOnlyId(
    skillMatch,
    "proposal_id",
    requestedProposalId,
    "skill-filtered requested Proposal",
  );
  const skillMiss = await listRequestedProposals(requester, locality, [
    "d0000000-0000-4000-8004-000000000001",
  ]);
  if (skillMiss.length !== 0) {
    throw new Error("Requested Proposal skill filtering was inconsistent.");
  }

  const publicAfter = await listPublicProposals(requester, locality);
  if (
    JSON.stringify(publicIdsBefore) !==
    JSON.stringify(publicAfter.map((card) => card.proposal_id))
  ) {
    throw new Error("Participation changed ordinary Proposal ordering.");
  }
  const otherOwnRequested = await listRequestedProposals(other, locality, null);
  if (otherOwnRequested.length !== 0) {
    throw new Error("User B read user A's requested Proposal state.");
  }
  const { error: proposalCrossIdentityError } = await other.client.rpc(
    "list_own_pending_requested_proposals",
    {
      p_expected_requester_profile_id: requester.id,
      p_locality: locality,
      p_skill_ids: null,
    },
  );
  if (proposalCrossIdentityError?.code !== "42501") {
    throw new Error(
      "Cross-account requested Proposal access did not fail closed.",
    );
  }

  await withdrawRequest(requester, pendingProposalRequestId);
  if ((await listRequestedProposals(requester, locality, null)).length !== 0) {
    throw new Error("A withdrawn Proposal remained in Requested Browse.");
  }
  const acceptedRequestId = await requestToJoin(
    requester,
    acceptedProposalId,
    null,
  );
  await acceptRequest(creator, acceptedRequestId);
  if ((await listRequestedProposals(requester, locality, null)).length !== 0) {
    throw new Error("An accepted Proposal remained in Requested Browse.");
  }

  const tavoloId = await createTavolo(creator, {
    title: `Browse Tavolo ${runId}`,
    locality,
    exactMeetingText: tavoloSecret,
  });
  await requestToJoin(requester, tavoloId, requestSecret);
  const requestedTavoli = await listRequestedTavoli(requester, locality);
  assertOnlyId(
    requestedTavoli,
    "recurring_activity_id",
    tavoloId,
    "pending requested Tavolo",
  );
  assertSafeCards(requestedTavoli, [tavoloSecret, requestSecret]);
  if (
    (await listRequestedTavoli(requester, `${locality}-mismatch`)).length !== 0
  ) {
    throw new Error("Requested Tavolo locality filtering was inconsistent.");
  }

  await transitionTavolo(creator, "pause_recurring_activity", tavoloId);
  if ((await listRequestedTavoli(requester, locality)).length !== 0) {
    throw new Error("A paused Tavolo remained in Requested Browse.");
  }
  await transitionTavolo(creator, "resume_recurring_activity", tavoloId);
  assertOnlyId(
    await listRequestedTavoli(requester, locality),
    "recurring_activity_id",
    tavoloId,
    "resumed requested Tavolo",
  );
  await transitionTavolo(creator, "end_recurring_activity", tavoloId);
  if ((await listRequestedTavoli(requester, locality)).length !== 0) {
    throw new Error("An ended Tavolo remained in Requested Browse.");
  }

  console.log(
    "Confirmed requester-only pending Proposal/Tavolo Browse promotion, stable public order, filters, withdrawal/acceptance/lifecycle removal, and sanitized card payloads.",
  );
}

async function createProposal(creator, input) {
  const { data, error } = await creator.client.rpc("create_proposal_draft", {
    p_expected_creator_profile_id: creator.id,
    p_title: input.title,
    p_summary: "A deterministic requested Browse Proposal.",
    p_description: "Integration-only Proposal detail content.",
    p_starts_at: input.startsAt,
    p_ends_at: input.endsAt,
    p_event_timezone: "Europe/Rome",
    p_country_code: "IT",
    p_locality: input.locality,
    p_administrative_area: null,
    p_public_location_label: input.locality,
    p_exact_meeting_text: input.exactMeetingText,
    p_exact_location_visibility: "participants",
    p_skill_ids: input.skillIds,
    p_skill_importances: input.skillIds.map(() => "required"),
  });
  if (error || typeof data !== "string") {
    throw safeDatabaseFailure(
      "create a requested Browse Proposal",
      error ?? {},
    );
  }
  const { error: publishError } = await creator.client.rpc("publish_proposal", {
    p_expected_creator_profile_id: creator.id,
    p_proposal_id: data,
  });
  if (publishError) {
    throw safeDatabaseFailure(
      "publish a requested Browse Proposal",
      publishError,
    );
  }
  return data;
}

async function createTavolo(creator, input) {
  const { data, error } = await creator.client.rpc(
    "create_recurring_activity_draft",
    {
      p_expected_creator_profile_id: creator.id,
      p_title: input.title,
      p_summary: "A deterministic requested Browse Tavolo.",
      p_description: "Integration-only Tavolo detail content.",
      p_topic: "Community",
      p_country_code: "IT",
      p_locality: input.locality,
      p_administrative_area: null,
      p_public_location_label: input.locality,
      p_exact_meeting_text: input.exactMeetingText,
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
    throw safeDatabaseFailure("create a requested Browse Tavolo", error ?? {});
  }
  await transitionTavolo(creator, "publish_recurring_activity", data);
  return data;
}

async function listPublicProposals(user, locality) {
  const { data, error } = await user.client.rpc("list_public_proposals", {
    p_limit: 20,
    p_cursor_starts_at: null,
    p_cursor_id: null,
    p_locality: locality,
    p_skill_ids: null,
  });
  if (error) throw safeDatabaseFailure("list public Proposals", error);
  return data ?? [];
}

async function listRequestedProposals(user, locality, skillIds) {
  const { data, error } = await user.client.rpc(
    "list_own_pending_requested_proposals",
    {
      p_expected_requester_profile_id: user.id,
      p_locality: locality,
      p_skill_ids: skillIds,
    },
  );
  if (error) throw safeDatabaseFailure("list requested Proposals", error);
  return data ?? [];
}

async function listRequestedTavoli(user, locality) {
  const { data, error } = await user.client.rpc(
    "list_own_pending_requested_recurring_activities",
    {
      p_expected_requester_profile_id: user.id,
      p_reference_time: referenceTime,
      p_locality: locality,
    },
  );
  if (error) throw safeDatabaseFailure("list requested Tavoli", error);
  return data ?? [];
}

async function requestToJoin(user, projectId, requestMessage) {
  const { data, error } = await user.client.rpc("request_to_join_project", {
    p_expected_requester_profile_id: user.id,
    p_project_id: projectId,
    p_request_message: requestMessage,
  });
  if (error || typeof data !== "string") {
    throw safeDatabaseFailure("request participation", error ?? {});
  }
  return data;
}

async function withdrawRequest(user, requestId) {
  const { error } = await user.client.rpc("withdraw_project_join_request", {
    p_expected_requester_profile_id: user.id,
    p_request_id: requestId,
  });
  if (error) throw safeDatabaseFailure("withdraw participation", error);
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
    throw safeDatabaseFailure("accept participation", error ?? {});
  }
}

async function transitionTavolo(creator, operation, activityId) {
  const { error } = await creator.client.rpc(operation, {
    p_expected_creator_profile_id: creator.id,
    p_recurring_activity_id: activityId,
  });
  if (error) throw safeDatabaseFailure(operation.replaceAll("_", " "), error);
}

function assertOnlyId(rows, key, expectedId, description) {
  if (rows.length !== 1 || rows[0]?.[key] !== expectedId) {
    throw new Error(`The ${description} result was inconsistent.`);
  }
}

function assertSafeCards(rows, forbiddenValues) {
  const serialized = JSON.stringify(rows);
  if (forbiddenValues.some((value) => serialized.includes(value))) {
    throw new Error("A requested Browse card leaked protected content.");
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
        "create a requested Browse profile",
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
      "complete a requested Browse profile",
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
    throw safeDatabaseFailure("request a local Browse OTP", requestError);
  }
  const messageId = await waitForNewMessage(
    email,
    existingMessageIds,
    requestStartedAt,
  );
  const message = await fetchJson(
    `${mailpitUrl}/api/v1/message/${encodeURIComponent(messageId)}`,
    {},
    "read a local Browse OTP email",
  );
  const body = `${message.Text ?? ""} ${message.HTML ?? ""}`;
  const token = body.match(/(?:^|\D)(\d{6})(?:\D|$)/)?.[1];
  if (!token) {
    throw new Error("A local Browse email did not contain a 6-digit token.");
  }
  const { data: verification, error: verificationError } =
    await client.auth.verifyOtp({ email, token, type: "email" });
  if (verificationError || !verification.user?.id || !verification.session) {
    throw safeDatabaseFailure(
      "verify a local Browse OTP",
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
  throw new Error("Mailpit did not receive a Browse OTP within 15 seconds.");
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
