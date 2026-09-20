import { createClient } from "@supabase/supabase-js";
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
    "Local Supabase status is missing the database URL required for agreement concurrency and privacy assertions.",
  );
}

const sql = postgres(databaseUrl, { max: 10, onnotice: () => {} });
const anonymous = createClient(apiUrl, publishableKey, {
  auth: { persistSession: false },
});

try {
  await verifyResourceExchangeAgreements();
} finally {
  await sql.end({ timeout: 5 });
}

async function verifyResourceExchangeAgreements() {
  const [owner, requester, requesterB, unrelated] = await Promise.all([
    signInWithLocalOtp("resource-agreement-owner@planets.invalid"),
    signInWithLocalOtp("resource-agreement-requester@planets.invalid"),
    signInWithLocalOtp("resource-agreement-requester-b@planets.invalid"),
    signInWithLocalOtp("resource-agreement-unrelated@planets.invalid"),
  ]);

  await Promise.all([
    ensureCompleteProfile(owner, "Agreement Verifier Owner"),
    ensureCompleteProfile(requester, "Agreement Verifier Requester"),
    ensureCompleteProfile(requesterB, "Agreement Verifier Requester B"),
    ensureCompleteProfile(unrelated, "Agreement Verifier Unrelated"),
  ]);

  const listingId = await createPublishedListing(
    owner,
    "Agreement verifier workbench",
  );
  const requestId = await requestListing(requester, listingId);
  await transitionRequest(owner, "accept_resource_listing_request", requestId);
  const agreement = await getAgreement(requester, requestId);
  if (
    agreement.lifecycle_state !== "negotiating" ||
    agreement.current_terms_id !== null ||
    agreement.pending_terms_id !== null
  ) {
    throw new Error(
      "Request acceptance did not atomically create one negotiating agreement.",
    );
  }

  const privateNote = "Private agreement verifier note";
  const requesterDescription = "Bookshelf offered by the requester";
  const firstTermsId = await proposeTerms(owner, agreement.agreement_id, {
    currentTermsId: null,
    pendingTermsId: null,
    ownerKind: "give",
    requesterKind: "give",
    requesterDescription,
    privateNote,
  });
  const secondTermsId = await proposeTerms(requester, agreement.agreement_id, {
    currentTermsId: null,
    pendingTermsId: firstTermsId,
    ownerKind: "give",
    requesterKind: "lend",
    requesterDescription: "Pressure washer supplied temporarily",
    requesterStartsAt: futureIso(1),
    requesterEndsAt: futureIso(10),
    privateNote: null,
  });
  await acceptTerms(owner, agreement.agreement_id, secondTermsId);

  const terms = await listTerms(requester, agreement.agreement_id);
  if (
    terms.length !== 2 ||
    terms[0].terms_id !== secondTermsId ||
    terms[0].is_current !== true ||
    terms[1].terms_id !== firstTermsId ||
    terms[1].is_current !== false ||
    terms[1].listing_title_snapshot !== "Agreement verifier workbench" ||
    terms[1].private_note !== privateNote
  ) {
    throw new Error(
      "Counter-proposal history did not preserve immutable server snapshots and pointers.",
    );
  }

  const timeline = await listEvents(owner, agreement.agreement_id);
  const eventKinds = timeline.map((event) => event.event_kind);
  if (
    !eventKinds.includes("agreement_created") ||
    !eventKinds.includes("terms_superseded") ||
    !eventKinds.includes("terms_accepted")
  ) {
    throw new Error("Agreement negotiation timeline was incomplete.");
  }

  await assertPrivateIsolation(unrelated, requestId, agreement.agreement_id);

  await milestone(
    owner,
    agreement.agreement_id,
    secondTermsId,
    "owner_resource",
    "resource_provided",
  );
  await milestone(
    requester,
    agreement.agreement_id,
    secondTermsId,
    "owner_resource",
    "resource_received",
  );
  await milestone(
    requester,
    agreement.agreement_id,
    secondTermsId,
    "requester_resource",
    "resource_provided",
  );
  await milestone(
    owner,
    agreement.agreement_id,
    secondTermsId,
    "requester_resource",
    "resource_received",
  );
  await milestone(
    owner,
    agreement.agreement_id,
    secondTermsId,
    "requester_resource",
    "resource_returned",
  );
  const finalEventId = await milestone(
    requester,
    agreement.agreement_id,
    secondTermsId,
    "requester_resource",
    "resource_return_received",
  );
  const duplicateFinalEventId = await milestone(
    requester,
    agreement.agreement_id,
    secondTermsId,
    "requester_resource",
    "resource_return_received",
  );
  if (duplicateFinalEventId !== finalEventId) {
    throw new Error("A duplicate milestone did not return canonical success.");
  }

  const completed = await getAgreement(owner, requestId);
  if (
    completed.lifecycle_state !== "completed" ||
    completed.completed_at === null
  ) {
    throw new Error("Required milestones did not complete the agreement.");
  }
  await assertPublicCount(listingId, 0);
  await requestListing(requester, listingId);

  await verifyOverdueAndCancellation(owner, requesterB);
  await verifyListingClosureAfterHandoff(owner, requesterB);
  await verifyCompetingProposals(owner, requester);
  await verifyAcceptVersusCounterProposal(owner, requester);
  await verifyCancelVersusFirstMilestone(owner, requester);
  await verifyFinalMilestoneRace(owner, requester);
  await assertIdentifierOnlyEvents([privateNote, requesterDescription]);

  console.log(
    "Confirmed real-OTP resource exchange agreements: atomic anchors, immutable counter-proposals, private reads, structured two-leg milestones, automatic completion, repeat requests, overdue derivation, cancellation, listing-close survival, identifier-only events, and deterministic proposal/accept/cancel/final-milestone serialization.",
  );
}

async function verifyOverdueAndCancellation(owner, requester) {
  const listingId = await createPublishedListing(
    owner,
    "Overdue verifier drill",
  );
  const requestId = await requestListing(requester, listingId);
  await transitionRequest(owner, "accept_resource_listing_request", requestId);
  const agreement = await getAgreement(owner, requestId);
  const termsId = await proposeTerms(owner, agreement.agreement_id, {
    currentTermsId: null,
    pendingTermsId: null,
    ownerKind: "lend",
    ownerStartsAt: pastIso(2),
    ownerEndsAt: pastIso(1),
    requesterKind: "none",
    requesterDescription: null,
    privateNote: null,
  });
  await acceptTerms(requester, agreement.agreement_id, termsId);
  const overdue = await getAgreement(requester, requestId);
  if (
    overdue.owner_lend_return_overdue !== true ||
    overdue.requester_lend_return_overdue !== false
  ) {
    throw new Error("A past unreturned owner lend was not derived overdue.");
  }
  await cancelAgreement(requester, agreement.agreement_id);
  const cancelled = await getAgreement(owner, requestId);
  if (
    cancelled.lifecycle_state !== "cancelled" ||
    cancelled.owner_lend_return_overdue !== false
  ) {
    throw new Error(
      "Pre-handoff cancellation did not close coordination and overdue truth.",
    );
  }
  await requestListing(requester, listingId);
}

async function verifyListingClosureAfterHandoff(owner, requester) {
  const listingId = await createPublishedListing(
    owner,
    "Closure verifier ladder",
  );
  const requestId = await requestListing(requester, listingId);
  await transitionRequest(owner, "accept_resource_listing_request", requestId);
  const agreement = await getAgreement(owner, requestId);
  const termsId = await proposeTerms(owner, agreement.agreement_id, {
    currentTermsId: null,
    pendingTermsId: null,
    ownerKind: "give",
    requesterKind: "none",
    requesterDescription: null,
    privateNote: null,
  });
  await acceptTerms(requester, agreement.agreement_id, termsId);
  await milestone(
    owner,
    agreement.agreement_id,
    termsId,
    "owner_resource",
    "resource_provided",
  );
  await closeListing(owner, listingId);
  await assertRpcCode(
    requester.client.rpc("cancel_resource_exchange_agreement", {
      p_expected_profile_id: requester.id,
      p_agreement_id: agreement.agreement_id,
    }),
    "PT409",
    "reject cancellation after the first milestone",
  );
  await milestone(
    requester,
    agreement.agreement_id,
    termsId,
    "owner_resource",
    "resource_received",
  );
  const completed = await getAgreement(requester, requestId);
  if (completed.lifecycle_state !== "completed") {
    throw new Error(
      "Listing closure destroyed or blocked accepted private coordination.",
    );
  }
  const { data: publicRows, error } = await anonymous.rpc(
    "get_public_resource_listing",
    { p_listing_id: listingId },
  );
  if (error || publicRows?.length !== 0) {
    throw new Error("A closed agreement listing remained public.");
  }
}

async function verifyCompetingProposals(owner, requester) {
  const { agreementId } = await createAcceptedAgreement(
    owner,
    requester,
    "Proposal race item",
  );
  let blockedProposal;

  await sql.begin(async (transaction) => {
    await setAuthenticatedTransaction(transaction, owner.id);
    await transaction`
      select public.propose_resource_exchange_terms(
        ${owner.id}::uuid,
        ${agreementId}::uuid,
        null,
        null,
        'give',
        null,
        null,
        'none',
        null,
        null,
        null,
        null
      )
    `;
    blockedProposal = track(
      proposeTermsRpc(requester, agreementId, {
        currentTermsId: null,
        pendingTermsId: null,
        ownerKind: "give",
        requesterKind: "none",
        requesterDescription: null,
        privateNote: null,
      }),
    );
    await assertBlocked(blockedProposal, "competing terms proposal");
  });

  await assertTrackedRpcCode(
    blockedProposal,
    "PT409",
    "reject the stale competing proposal",
  );
}

async function verifyAcceptVersusCounterProposal(owner, requester) {
  const { agreementId } = await createAcceptedAgreement(
    owner,
    requester,
    "Accept counter-proposal race item",
  );
  const pendingTermsId = await proposeTerms(owner, agreementId, {
    currentTermsId: null,
    pendingTermsId: null,
    ownerKind: "give",
    requesterKind: "none",
    requesterDescription: null,
    privateNote: null,
  });
  let blockedCounterProposal;

  await sql.begin(async (transaction) => {
    await setAuthenticatedTransaction(transaction, requester.id);
    await transaction`
      select public.accept_resource_exchange_terms(
        ${requester.id}::uuid,
        ${agreementId}::uuid,
        ${pendingTermsId}::uuid
      )
    `;
    blockedCounterProposal = track(
      proposeTermsRpc(owner, agreementId, {
        currentTermsId: null,
        pendingTermsId,
        ownerKind: "give",
        requesterKind: "give",
        requesterDescription: "Counter resource",
        privateNote: null,
      }),
    );
    await assertBlocked(
      blockedCounterProposal,
      "counter-proposal behind pending acceptance",
    );
  });

  await assertTrackedRpcCode(
    blockedCounterProposal,
    "PT409",
    "reject a counter-proposal based on accepted pointers",
  );
}

async function verifyCancelVersusFirstMilestone(owner, requester) {
  const { agreementId } = await createAcceptedAgreement(
    owner,
    requester,
    "Cancel milestone race item",
  );
  const termsId = await proposeTerms(owner, agreementId, {
    currentTermsId: null,
    pendingTermsId: null,
    ownerKind: "give",
    requesterKind: "none",
    requesterDescription: null,
    privateNote: null,
  });
  await acceptTerms(requester, agreementId, termsId);
  let blockedMilestone;

  await sql.begin(async (transaction) => {
    await setAuthenticatedTransaction(transaction, owner.id);
    await transaction`
      select public.cancel_resource_exchange_agreement(
        ${owner.id}::uuid,
        ${agreementId}::uuid
      )
    `;
    blockedMilestone = track(
      owner.client.rpc("record_resource_exchange_milestone", {
        p_expected_profile_id: owner.id,
        p_agreement_id: agreementId,
        p_expected_terms_id: termsId,
        p_leg_kind: "owner_resource",
        p_event_kind: "resource_provided",
      }),
    );
    await assertBlocked(blockedMilestone, "milestone behind cancellation");
  });

  await assertTrackedRpcCode(
    blockedMilestone,
    "PT409",
    "reject the first milestone after cancellation wins",
  );
}

async function verifyFinalMilestoneRace(owner, requester) {
  const { requestId, agreementId } = await createAcceptedAgreement(
    owner,
    requester,
    "Final milestone race item",
  );
  const termsId = await proposeTerms(owner, agreementId, {
    currentTermsId: null,
    pendingTermsId: null,
    ownerKind: "give",
    requesterKind: "give",
    requesterDescription: "Requester race resource",
    privateNote: null,
  });
  await acceptTerms(requester, agreementId, termsId);
  await milestone(
    owner,
    agreementId,
    termsId,
    "owner_resource",
    "resource_provided",
  );
  await milestone(
    requester,
    agreementId,
    termsId,
    "requester_resource",
    "resource_provided",
  );
  let blockedFinalMilestone;

  await sql.begin(async (transaction) => {
    await setAuthenticatedTransaction(transaction, requester.id);
    await transaction`
      select public.record_resource_exchange_milestone(
        ${requester.id}::uuid,
        ${agreementId}::uuid,
        ${termsId}::uuid,
        'owner_resource',
        'resource_received'
      )
    `;
    blockedFinalMilestone = track(
      owner.client.rpc("record_resource_exchange_milestone", {
        p_expected_profile_id: owner.id,
        p_agreement_id: agreementId,
        p_expected_terms_id: termsId,
        p_leg_kind: "requester_resource",
        p_event_kind: "resource_received",
      }),
    );
    await assertBlocked(
      blockedFinalMilestone,
      "other final confirmation behind agreement lock",
    );
  });

  await assertTrackedRpcValue(
    blockedFinalMilestone,
    "record the serialized final confirmation",
  );
  const completed = await getAgreement(owner, requestId);
  const [{ completion_count: completionCount }] = await sql`
    select count(*)::integer as completion_count
    from public.resource_exchange_agreement_events
    where agreement_id = ${agreementId}::uuid
      and event_kind = 'agreement_completed'
  `;
  if (completed.lifecycle_state !== "completed" || completionCount !== 1) {
    throw new Error(
      "Final milestone serialization did not complete the agreement exactly once.",
    );
  }
}

async function createAcceptedAgreement(owner, requester, title) {
  const listingId = await createPublishedListing(owner, title);
  const requestId = await requestListing(requester, listingId);
  await transitionRequest(owner, "accept_resource_listing_request", requestId);
  const agreement = await getAgreement(owner, requestId);
  return { listingId, requestId, agreementId: agreement.agreement_id };
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
        "Deterministic listing used only by the local agreement verifier.",
      p_country_code: "IT",
      p_locality: "Trento",
      p_administrative_area: null,
      p_public_location_label: "Trento",
    },
    "create an agreement-verifier listing",
  );
  const publishedId = await rpcValue(
    owner,
    "publish_resource_listing",
    {
      p_expected_owner_profile_id: owner.id,
      p_listing_id: listingId,
    },
    "publish an agreement-verifier listing",
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
    "request an agreement-verifier listing",
  );
}

async function transitionRequest(owner, operation, requestId) {
  const value = await rpcValue(
    owner,
    operation,
    {
      p_expected_owner_profile_id: owner.id,
      p_request_id: requestId,
    },
    operation.replaceAll("_", " "),
  );
  if (value !== requestId) {
    throw new Error("Request transition returned the wrong identifier.");
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

async function listTerms(actor, agreementId) {
  const { data, error } = await actor.client.rpc(
    "list_resource_exchange_agreement_terms",
    { p_expected_profile_id: actor.id, p_agreement_id: agreementId },
  );
  if (error || !Array.isArray(data)) {
    throw safeDatabaseFailure("list agreement terms", error);
  }
  return data;
}

async function listEvents(actor, agreementId) {
  const { data, error } = await actor.client.rpc(
    "list_resource_exchange_agreement_events",
    { p_expected_profile_id: actor.id, p_agreement_id: agreementId },
  );
  if (error || !Array.isArray(data)) {
    throw safeDatabaseFailure("list agreement events", error);
  }
  return data;
}

function proposeTermsRpc(actor, agreementId, terms) {
  return actor.client.rpc("propose_resource_exchange_terms", {
    p_expected_profile_id: actor.id,
    p_agreement_id: agreementId,
    p_expected_current_terms_id: terms.currentTermsId,
    p_expected_pending_terms_id: terms.pendingTermsId,
    p_owner_transfer_kind: terms.ownerKind,
    p_owner_lend_starts_at: terms.ownerStartsAt ?? null,
    p_owner_lend_ends_at: terms.ownerEndsAt ?? null,
    p_requester_transfer_kind: terms.requesterKind,
    p_requester_resource_description: terms.requesterDescription,
    p_requester_lend_starts_at: terms.requesterStartsAt ?? null,
    p_requester_lend_ends_at: terms.requesterEndsAt ?? null,
    p_private_note: terms.privateNote,
  });
}

async function proposeTerms(actor, agreementId, terms) {
  const { data, error } = await proposeTermsRpc(actor, agreementId, terms);
  if (error || typeof data !== "string") {
    throw safeDatabaseFailure("propose resource exchange terms", error);
  }
  return data;
}

async function acceptTerms(actor, agreementId, termsId) {
  const value = await rpcValue(
    actor,
    "accept_resource_exchange_terms",
    {
      p_expected_profile_id: actor.id,
      p_agreement_id: agreementId,
      p_expected_pending_terms_id: termsId,
    },
    "accept resource exchange terms",
  );
  if (value !== termsId) {
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

async function cancelAgreement(actor, agreementId) {
  const value = await rpcValue(
    actor,
    "cancel_resource_exchange_agreement",
    { p_expected_profile_id: actor.id, p_agreement_id: agreementId },
    "cancel a resource exchange agreement",
  );
  if (value !== agreementId) {
    throw new Error("Agreement cancellation returned the wrong identifier.");
  }
}

async function closeListing(owner, listingId) {
  const value = await rpcValue(
    owner,
    "close_resource_listing",
    {
      p_expected_owner_profile_id: owner.id,
      p_listing_id: listingId,
    },
    "close an agreement-verifier listing",
  );
  if (value !== listingId) {
    throw new Error("Listing closure returned the wrong identifier.");
  }
}

async function assertPrivateIsolation(unrelated, requestId, agreementId) {
  const { data: unrelatedRows, error: unrelatedError } =
    await unrelated.client.rpc("get_resource_exchange_agreement", {
      p_expected_profile_id: unrelated.id,
      p_request_id: requestId,
    });
  if (unrelatedError || unrelatedRows?.length !== 0) {
    throw new Error("An unrelated user could read a private agreement.");
  }
  const { data: anonymousRows, error: anonymousError } = await anonymous
    .from("resource_exchange_agreement_terms")
    .select("id");
  if (!anonymousError || anonymousRows !== null) {
    throw new Error(
      "Anonymous agreement-term enumeration did not fail closed.",
    );
  }
  const { data: unrelatedTerms, error: unrelatedTermsError } =
    await unrelated.client.rpc("list_resource_exchange_agreement_terms", {
      p_expected_profile_id: unrelated.id,
      p_agreement_id: agreementId,
    });
  if (!unrelatedTermsError || unrelatedTerms !== null) {
    throw new Error(
      "An unrelated user could enumerate private agreement terms.",
    );
  }
}

async function assertPublicCount(listingId, expectedCount) {
  const { data, error } = await anonymous.rpc("get_public_resource_listing", {
    p_listing_id: listingId,
  });
  if (error || data?.[0]?.active_request_count !== expectedCount) {
    throw new Error("Public active-interest count was not canonical.");
  }
}

async function assertIdentifierOnlyEvents(privateTexts) {
  const events = await sql`
    select event_type, payload
    from private.outbox_events
    where event_type like 'resource_exchange.%'
  `;
  const allowedKeys = new Set([
    "agreement_event_id",
    "agreement_id",
    "actor_profile_id",
    "listing_id",
    "owner_profile_id",
    "request_id",
    "requester_profile_id",
    "terms_id",
  ]);
  if (events.length === 0) {
    throw new Error("Agreement transitions emitted no outbox events.");
  }
  for (const event of events) {
    if (Object.keys(event.payload ?? {}).some((key) => !allowedKeys.has(key))) {
      throw new Error("An agreement event was not identifier-only.");
    }
    const serialized = JSON.stringify(event.payload);
    if (privateTexts.some((value) => serialized.includes(value))) {
      throw new Error("Private agreement content leaked into an event.");
    }
  }
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
      throw safeDatabaseFailure(
        "create an agreement-verifier profile",
        anchorError,
      );
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
    throw safeDatabaseFailure("complete an agreement-verifier profile", error);
  }
}

function signInWithLocalOtp(email) {
  return signInLocalOtpUser({
    apiUrl,
    publishableKey,
    mailpitUrl,
    email,
    verifierName: "resource exchange agreement verifier",
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

function futureIso(days) {
  return new Date(Date.now() + days * 86_400_000).toISOString();
}

function pastIso(days) {
  return new Date(Date.now() - days * 86_400_000).toISOString();
}

function delay(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}
