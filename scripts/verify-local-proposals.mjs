import { createClient } from "@supabase/supabase-js";

import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";

const repositoryRoot = process.cwd();
const mailpitUrl = (
  process.env.MAILPIT_URL ?? "http://127.0.0.1:54324"
).replace(/\/$/, "");
const { apiUrl, publishableKey } = readLocalSupabaseStatus(repositoryRoot);
const userAEmail = "proposal-integration-a@planets.invalid";
const userBEmail = "proposal-integration-b@planets.invalid";

await verifyProposals();

async function verifyProposals() {
  const [userA, userB] = await Promise.all([
    signInWithLocalOtp(userAEmail),
    signInWithLocalOtp(userBEmail),
  ]);
  await Promise.all([
    ensureCompleteProfile(userA, "Proposal Owner A"),
    ensureCompleteProfile(userB, "Proposal Owner B"),
  ]);

  const { data: skills, error: skillError } = await userA.client
    .from("skills")
    .select("id, slug")
    .in("slug", ["mural-painting", "basic-repairs"])
    .order("slug");
  if (skillError || skills?.length !== 2) {
    throw new Error(
      "Could not load the controlled skills needed for proposal verification.",
    );
  }
  const muralSkillId = skills.find(
    (skill) => skill.slug === "mural-painting",
  )?.id;
  const repairSkillId = skills.find(
    (skill) => skill.slug === "basic-repairs",
  )?.id;
  if (!muralSkillId || !repairSkillId) {
    throw new Error(
      "The proposal skill catalog did not contain the expected stable identifiers.",
    );
  }

  const userBDraftId = await createDraft(userB, {
    title: "User B draft",
    skillIds: [],
    skillImportances: [],
  });

  const now = Date.now();
  const restrictedSecret =
    "Private courtyard entrance for accepted participants";
  const restrictedProposalId = await createDraft(userA, {
    title: "Neighborhood mural",
    summary: "Create a public mural together.",
    description: "Bring ideas and help paint a shared neighborhood design.",
    startsAt: new Date(now - 60 * 60 * 1000).toISOString(),
    endsAt: new Date(now + 2 * 60 * 60 * 1000).toISOString(),
    eventTimezone: "Europe/Rome",
    countryCode: "IT",
    locality: "Trento",
    administrativeArea: "Povo",
    publicLocationLabel: "Trento · Povo",
    exactMeetingText: restrictedSecret,
    exactLocationVisibility: "participants",
    skillIds: [muralSkillId],
    skillImportances: ["required"],
  });

  const { data: crossUserRows, error: crossUserReadError } = await userB.client
    .from("proposals")
    .select("id")
    .eq("id", restrictedProposalId);
  if (crossUserReadError || crossUserRows?.length !== 0) {
    throw new Error("User B could directly read user A's proposal row.");
  }

  const { error: crossUserMutationError } = await userB.client.rpc(
    "update_own_proposal",
    proposalParams(userB.id, restrictedProposalId, {
      title: "Cross-account overwrite",
      skillIds: [],
      skillImportances: [],
    }),
  );
  if (crossUserMutationError?.code !== "42501") {
    throw new Error("Cross-account proposal mutation did not fail closed.");
  }

  const { error: staleIdentityError } = await userB.client.rpc(
    "update_own_proposal",
    proposalParams(userA.id, userBDraftId, {
      title: "Stale user A content",
      skillIds: [],
      skillImportances: [],
    }),
  );
  if (staleIdentityError?.code !== "42501") {
    throw new Error(
      "A stale expected proposal creator was not rejected before mutation.",
    );
  }
  const { data: userBProposal, error: userBProposalError } =
    await userB.client.rpc("get_own_proposal", {
      p_expected_creator_profile_id: userB.id,
      p_proposal_id: userBDraftId,
    });
  if (
    userBProposalError ||
    userBProposal?.length !== 1 ||
    userBProposal[0].title !== "User B draft"
  ) {
    throw new Error(
      "Stale-form rejection changed the newly authenticated user's draft.",
    );
  }

  await publish(userA, restrictedProposalId);

  const anonymous = createClient(apiUrl, publishableKey, {
    auth: { persistSession: false },
  });
  const { data: directProposalRows, error: directProposalError } =
    await anonymous.from("proposals").select("id");
  if (!directProposalError || directProposalRows !== null) {
    throw new Error(
      "Anonymous direct proposal-table access did not fail closed.",
    );
  }

  const { data: restrictedList, error: restrictedListError } =
    await anonymous.rpc("list_public_proposals", {
      p_limit: 20,
      p_cursor_starts_at: null,
      p_cursor_id: null,
      p_locality: "Trento",
      p_skill_ids: [muralSkillId],
      p_query: "NEIGHBORHOOD MURAL",
    });
  const restrictedCard = restrictedList?.find(
    (proposal) => proposal.proposal_id === restrictedProposalId,
  );
  if (
    restrictedListError ||
    !restrictedCard ||
    restrictedCard.derived_status !== "happening" ||
    restrictedCard.public_location_label !== "Trento · Povo" ||
    !Array.isArray(restrictedCard.skills) ||
    restrictedCard.skills.length !== 1 ||
    JSON.stringify(restrictedCard).includes(restrictedSecret)
  ) {
    throw new Error(
      "Anonymous proposal discovery was not correctly sanitized or classified.",
    );
  }

  const { data: restrictedDetails, error: restrictedDetailError } =
    await anonymous.rpc("get_public_proposal", {
      p_proposal_id: restrictedProposalId,
    });
  if (
    restrictedDetailError ||
    restrictedDetails?.length !== 1 ||
    restrictedDetails[0].exact_meeting_text !== null ||
    restrictedDetails[0].exact_location_restricted !== true ||
    JSON.stringify(restrictedDetails[0]).includes(restrictedSecret)
  ) {
    throw new Error(
      "Participant-restricted exact meeting information leaked publicly.",
    );
  }

  const { data: ownerDetails, error: ownerDetailError } =
    await userA.client.rpc("get_own_proposal", {
      p_expected_creator_profile_id: userA.id,
      p_proposal_id: restrictedProposalId,
    });
  if (
    ownerDetailError ||
    ownerDetails?.length !== 1 ||
    ownerDetails[0].exact_meeting_text !== restrictedSecret
  ) {
    throw new Error(
      "The proposal creator could not read the own restricted meeting information.",
    );
  }

  const publicExactText = "Piazza Duomo, by the fountain";
  const publicProposalId = await createDraft(userA, {
    title: "Community 100%_ repair session",
    summary: "Repair useful household items together.",
    description: "Bring a small item and learn basic repair skills.",
    startsAt: new Date(now + 24 * 60 * 60 * 1000).toISOString(),
    endsAt: new Date(now + 26 * 60 * 60 * 1000).toISOString(),
    eventTimezone: "Europe/Rome",
    countryCode: "IT",
    locality: "Trento",
    administrativeArea: "Centro storico",
    publicLocationLabel: "Trento · Centro storico",
    exactMeetingText: publicExactText,
    exactLocationVisibility: "public",
    skillIds: [repairSkillId],
    skillImportances: ["useful"],
  });
  await publish(userA, publicProposalId);

  const [
    { data: publicList, error: publicListError },
    { data: publicDetails, error: publicDetailError },
  ] = await Promise.all([
    anonymous.rpc("list_public_proposals", {
      p_limit: 20,
      p_cursor_starts_at: null,
      p_cursor_id: null,
      p_locality: null,
      p_skill_ids: null,
      p_query: "HOUSEHOLD ITEMS",
    }),
    anonymous.rpc("get_public_proposal", { p_proposal_id: publicProposalId }),
  ]);
  const publicCard = publicList?.find(
    (proposal) => proposal.proposal_id === publicProposalId,
  );
  if (
    publicListError ||
    publicDetailError ||
    !publicCard ||
    JSON.stringify(publicCard).includes(publicExactText) ||
    publicDetails?.length !== 1 ||
    publicDetails[0].exact_meeting_text !== publicExactText ||
    publicDetails[0].exact_location_restricted !== false
  ) {
    throw new Error(
      "Public exact meeting information did not remain detail-only.",
    );
  }
  if (
    publicList?.length !== 1 ||
    publicCard.title !== "Community 100%_ repair session"
  ) {
    throw new Error(
      "Literal, case-insensitive Proposal search did not filter the backend page.",
    );
  }

  const { error: cancelError } = await userA.client.rpc("cancel_proposal", {
    p_expected_creator_profile_id: userA.id,
    p_proposal_id: restrictedProposalId,
  });
  if (cancelError) {
    throw safeDatabaseFailure("cancel user A's proposal", cancelError);
  }
  const { data: afterCancellation, error: afterCancellationError } =
    await anonymous.rpc("list_public_proposals", {
      p_limit: 20,
      p_cursor_starts_at: null,
      p_cursor_id: null,
      p_locality: null,
      p_skill_ids: null,
      p_query: null,
    });
  if (
    afterCancellationError ||
    afterCancellation?.some(
      (proposal) => proposal.proposal_id === restrictedProposalId,
    )
  ) {
    throw new Error(
      "Cancellation did not remove the proposal from public discovery.",
    );
  }

  console.log(
    "Confirmed two-user proposal ownership, stale-identity rejection, literal backend search, public discovery sanitization, detail-only exact location, lifecycle, filters, and time-derived current statuses.",
  );
}

async function createDraft(user, input) {
  const { data, error } = await user.client.rpc(
    "create_proposal_draft",
    proposalParams(user.id, null, input),
  );
  if (error || typeof data !== "string") {
    throw safeDatabaseFailure("create a proposal draft", error ?? {});
  }
  return data;
}

async function publish(user, proposalId) {
  const { error } = await user.client.rpc("publish_proposal", {
    p_expected_creator_profile_id: user.id,
    p_proposal_id: proposalId,
  });
  if (error) {
    throw safeDatabaseFailure("publish a proposal", error);
  }
}

function proposalParams(expectedCreatorId, proposalId, input) {
  return {
    p_expected_creator_profile_id: expectedCreatorId,
    ...(proposalId ? { p_proposal_id: proposalId } : {}),
    p_title: input.title ?? null,
    p_summary: input.summary ?? null,
    p_description: input.description ?? null,
    p_starts_at: input.startsAt ?? null,
    p_ends_at: input.endsAt ?? null,
    p_event_timezone: input.eventTimezone ?? null,
    p_country_code: input.countryCode ?? null,
    p_locality: input.locality ?? null,
    p_administrative_area: input.administrativeArea ?? null,
    p_public_location_label: input.publicLocationLabel ?? null,
    p_exact_meeting_text: input.exactMeetingText ?? null,
    p_exact_location_visibility:
      input.exactLocationVisibility ?? "participants",
    p_skill_ids: input.skillIds,
    p_skill_importances: input.skillImportances,
  };
}

async function ensureCompleteProfile(user, displayName) {
  const { error: anchorError } = await user.client
    .from("profiles")
    .insert({ id: user.id });
  if (anchorError) {
    const diagnostic = `${anchorError.message ?? ""} ${anchorError.details ?? ""}`;
    if (anchorError.code !== "23505" || !diagnostic.includes("profiles_pkey")) {
      throw safeDatabaseFailure(
        "create a proposal profile anchor",
        anchorError,
      );
    }
  }

  const { error: updateError } = await user.client.rpc("update_own_profile", {
    p_expected_profile_id: user.id,
    p_display_name: displayName,
    p_bio: null,
    p_skill_ids: [],
    p_display_name_audience: "public",
    p_bio_audience: "private",
    p_skills_audience: "public",
  });
  if (updateError) {
    throw safeDatabaseFailure("complete a proposal test profile", updateError);
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
    throw safeDatabaseFailure("request a local proposal OTP", requestError);
  }

  const messageId = await waitForNewMessage(
    email,
    existingMessageIds,
    requestStartedAt,
  );
  const message = await fetchJson(
    `${mailpitUrl}/api/v1/message/${encodeURIComponent(messageId)}`,
    {},
    "read a local proposal OTP email",
  );
  const messageBody = `${message.Text ?? ""} ${message.HTML ?? ""}`;
  const token = messageBody.match(/(?:^|\D)(\d{6})(?:\D|$)/)?.[1];
  if (!token) {
    throw new Error(
      "A local proposal sign-in email did not contain a 6-digit token.",
    );
  }

  const { data: verification, error: verificationError } =
    await client.auth.verifyOtp({
      email,
      token,
      type: "email",
    });
  if (verificationError || !verification.user?.id || !verification.session) {
    throw safeDatabaseFailure(
      "verify a local proposal OTP",
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
    "Mailpit did not receive a proposal OTP email within 15 seconds.",
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
