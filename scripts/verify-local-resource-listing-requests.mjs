import { createClient } from "@supabase/supabase-js";
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
    "Local Supabase status is missing the database URL required for request concurrency and event assertions.",
  );
}

const sql = postgres(databaseUrl, { max: 8, onnotice: () => {} });
const anonymous = createClient(apiUrl, publishableKey, {
  auth: { persistSession: false },
});

try {
  await verifyResourceListingRequests();
} finally {
  await sql.end({ timeout: 5 });
}

async function verifyResourceListingRequests() {
  const [
    owner,
    requesterA,
    requesterB,
    requesterC,
    requesterD,
    requesterE,
    unrelated,
  ] = await Promise.all([
    signInWithLocalOtp("resource-request-owner@planets.invalid"),
    signInWithLocalOtp("resource-request-a@planets.invalid"),
    signInWithLocalOtp("resource-request-b@planets.invalid"),
    signInWithLocalOtp("resource-request-c@planets.invalid"),
    signInWithLocalOtp("resource-request-d@planets.invalid"),
    signInWithLocalOtp("resource-request-e@planets.invalid"),
    signInWithLocalOtp("resource-request-unrelated@planets.invalid"),
  ]);

  await Promise.all([
    ensureCompleteProfile(owner, "Resource Request Owner"),
    ensureCompleteProfile(requesterA, "Resource Requester A"),
    ensureCompleteProfile(requesterB, "Resource Requester B"),
    ensureCompleteProfile(requesterC, "Resource Requester C"),
    ensureCompleteProfile(requesterD, "Resource Requester D"),
    ensureCompleteProfile(requesterE, "Resource Requester E"),
    ensureCompleteProfile(unrelated, "Resource Request Unrelated"),
  ]);
  await Promise.all(
    [
      owner,
      requesterA,
      requesterB,
      requesterC,
      requesterD,
      requesterE,
      unrelated,
    ].map((user) => ensureLocalProfilePhoto(user)),
  );

  const listingId = await createPublishedListing(
    owner,
    "Request verifier item",
  );
  const requestMessages = [
    "Private request context A",
    "Private request context B",
    "Private request context C",
    "Private request context D",
  ];
  const [requestA, requestB, requestC, requestD] = await Promise.all([
    requestListing(requesterA, listingId, `  ${requestMessages[0]}  `),
    requestListing(requesterB, listingId, requestMessages[1]),
    requestListing(requesterC, listingId, requestMessages[2]),
    requestListing(requesterD, listingId, requestMessages[3]),
  ]);

  await assertPublicCount(listingId, 4);

  const ownerRows = await listOwnerRequests(owner, listingId);
  if (
    ownerRows.length !== 4 ||
    !ownerRows.every(
      (row) =>
        row.status === "pending" &&
        typeof row.requester_display_name === "string",
    ) ||
    ownerRows.find((row) => row.request_id === requestA)?.request_message !==
      requestMessages[0]
  ) {
    throw new Error(
      "The owner request history was incomplete or did not preserve normalized private context.",
    );
  }

  const requesterRows = await listOwnRequests(requesterA);
  if (
    requesterRows.length !== 1 ||
    requesterRows[0].request_id !== requestA ||
    requesterRows[0].owner_profile_id !== owner.id ||
    requesterRows[0].owner_display_name !== "Resource Request Owner"
  ) {
    throw new Error(
      "Requester history did not return canonical listing context.",
    );
  }

  const { data: unrelatedRead, error: unrelatedReadError } =
    await unrelated.client.rpc("get_resource_listing_request", {
      p_expected_profile_id: unrelated.id,
      p_request_id: requestA,
    });
  if (unrelatedReadError || unrelatedRead?.length !== 0) {
    throw new Error("An unrelated user could read another listing request.");
  }

  const { data: anonymousRows, error: anonymousError } = await anonymous
    .from("resource_listing_requests")
    .select("id");
  if (!anonymousError || anonymousRows !== null) {
    throw new Error("Anonymous request-table enumeration did not fail closed.");
  }

  await Promise.all([
    transitionRequest(owner, "accept_resource_listing_request", requestA),
    transitionRequest(owner, "accept_resource_listing_request", requestB),
  ]);
  await transitionRequest(owner, "reject_resource_listing_request", requestC);
  await transitionRequest(
    requesterD,
    "withdraw_resource_listing_request",
    requestD,
  );
  await assertPublicCount(listingId, 2);

  const requestE = await requestListing(requesterE, listingId, null);
  await closeListing(owner, listingId);
  const closedRows = await readRequestStatuses([
    requestA,
    requestB,
    requestC,
    requestD,
    requestE,
  ]);
  assertStatuses(
    closedRows,
    new Map([
      [requestA, "accepted"],
      [requestB, "accepted"],
      [requestC, "rejected"],
      [requestD, "withdrawn"],
      [requestE, "listing_closed"],
    ]),
  );

  const closedOwnerRows = await listOwnerRequests(owner, listingId);
  const closedRequesterRows = await listOwnRequests(requesterE);
  if (
    closedOwnerRows.length !== 5 ||
    closedRequesterRows.find((row) => row.request_id === requestE)?.status !==
      "listing_closed"
  ) {
    throw new Error(
      "Closed listing request history was not retained privately.",
    );
  }
  const { data: closedPublicRows, error: closedPublicError } =
    await anonymous.rpc("get_public_resource_listing", {
      p_listing_id: listingId,
    });
  if (closedPublicError || closedPublicRows?.length !== 0) {
    throw new Error("A closed listing remained publicly readable.");
  }

  await verifyAcceptVersusWithdraw(owner, requesterD);
  await verifyRejectVersusWithdraw(owner, requesterC);
  await verifyRequestVersusClose(owner, requesterE);
  await verifyDuplicateRequest(owner, requesterE);
  await assertIdentifierOnlyEvents(requestMessages);

  console.log(
    "Confirmed real-OTP Scambio-Dona requests: four-party interest counts, owner/requester history, two independent acceptances, rejection, withdrawal, close preservation, private reads, identifier-only events, deterministic decision/close/duplicate serialization, and fail-closed direct access.",
  );
}

async function verifyAcceptVersusWithdraw(owner, requester) {
  const listingId = await createPublishedListing(owner, "Accept race item");
  const requestId = await requestListing(requester, listingId, null);
  let blockedWithdrawal;

  await sql.begin(async (transaction) => {
    await setAuthenticatedTransaction(transaction, owner.id);
    await transaction`
      select public.accept_resource_listing_request(
        ${owner.id}::uuid,
        ${requestId}::uuid
      )
    `;
    blockedWithdrawal = track(
      requester.client.rpc("withdraw_resource_listing_request", {
        p_expected_requester_profile_id: requester.id,
        p_request_id: requestId,
      }),
    );
    await assertBlocked(
      blockedWithdrawal,
      "withdrawal behind owner acceptance",
    );
  });

  await assertTrackedRpcCode(
    blockedWithdrawal,
    "PT409",
    "reject the losing withdrawal after acceptance",
  );
  await assertRequestStatus(requestId, "accepted");
}

async function verifyRejectVersusWithdraw(owner, requester) {
  const listingId = await createPublishedListing(owner, "Reject race item");
  const requestId = await requestListing(requester, listingId, null);
  let blockedWithdrawal;

  await sql.begin(async (transaction) => {
    await setAuthenticatedTransaction(transaction, owner.id);
    await transaction`
      select public.reject_resource_listing_request(
        ${owner.id}::uuid,
        ${requestId}::uuid
      )
    `;
    blockedWithdrawal = track(
      requester.client.rpc("withdraw_resource_listing_request", {
        p_expected_requester_profile_id: requester.id,
        p_request_id: requestId,
      }),
    );
    await assertBlocked(blockedWithdrawal, "withdrawal behind owner rejection");
  });

  await assertTrackedRpcCode(
    blockedWithdrawal,
    "PT409",
    "reject the losing withdrawal after rejection",
  );
  await assertRequestStatus(requestId, "rejected");
}

async function verifyRequestVersusClose(owner, requester) {
  const listingId = await createPublishedListing(owner, "Close race item");
  let requestId;
  let blockedClose;

  await sql.begin(async (transaction) => {
    await setAuthenticatedTransaction(transaction, requester.id);
    const [created] = await transaction`
      select public.request_resource_listing(
        ${requester.id}::uuid,
        ${listingId}::uuid,
        null
      ) as request_id
    `;
    requestId = created.request_id;
    blockedClose = track(
      owner.client.rpc("close_resource_listing", {
        p_expected_owner_profile_id: owner.id,
        p_listing_id: listingId,
      }),
    );
    await assertBlocked(blockedClose, "listing close behind request creation");
  });

  await assertTrackedRpcValue(
    blockedClose,
    listingId,
    "complete listing close after request creation",
  );
  await assertRequestStatus(requestId, "listing_closed");
}

async function verifyDuplicateRequest(owner, requester) {
  const listingId = await createPublishedListing(owner, "Duplicate race item");
  let firstRequestId;
  let blockedDuplicate;

  await sql.begin(async (transaction) => {
    await setAuthenticatedTransaction(transaction, requester.id);
    const [created] = await transaction`
      select public.request_resource_listing(
        ${requester.id}::uuid,
        ${listingId}::uuid,
        null
      ) as request_id
    `;
    firstRequestId = created.request_id;
    blockedDuplicate = track(
      requester.client.rpc("request_resource_listing", {
        p_expected_requester_profile_id: requester.id,
        p_listing_id: listingId,
        p_message: null,
      }),
    );
    await assertBlocked(blockedDuplicate, "duplicate request behind creation");
  });

  await assertTrackedRpcCode(
    blockedDuplicate,
    "PT409",
    "reject the losing duplicate request",
  );
  const [{ active_count: activeCount }] = await sql`
    select count(*)::integer as active_count
    from public.resource_listing_requests
    where listing_id = ${listingId}::uuid
      and requester_profile_id = ${requester.id}::uuid
      and status in ('pending', 'accepted')
  `;
  if (activeCount !== 1) {
    throw new Error(
      "The duplicate race did not leave exactly one active request.",
    );
  }
  await assertRequestStatus(firstRequestId, "pending");
}

async function createPublishedListing(owner, title) {
  const { data: listingId, error: createError } = await owner.client.rpc(
    "create_resource_listing_draft",
    {
      p_expected_owner_profile_id: owner.id,
      p_listing_mode: "exchange",
      p_title: title,
      p_description:
        "Deterministic listing used only by the local resource-request verifier.",
      p_country_code: "IT",
      p_locality: "Trento",
      p_administrative_area: null,
      p_public_location_label: "Trento",
    },
  );
  if (createError || typeof listingId !== "string") {
    throw safeDatabaseFailure("create a request-verifier listing", createError);
  }
  const { data: publishedId, error: publishError } = await owner.client.rpc(
    "publish_resource_listing",
    {
      p_expected_owner_profile_id: owner.id,
      p_listing_id: listingId,
    },
  );
  if (publishError || publishedId !== listingId) {
    throw safeDatabaseFailure(
      "publish a request-verifier listing",
      publishError,
    );
  }
  return listingId;
}

async function requestListing(requester, listingId, message) {
  const { data, error } = await requester.client.rpc(
    "request_resource_listing",
    {
      p_expected_requester_profile_id: requester.id,
      p_listing_id: listingId,
      p_message: message,
    },
  );
  if (error || typeof data !== "string") {
    throw safeDatabaseFailure("request a resource listing", error);
  }
  return data;
}

async function transitionRequest(actor, operation, requestId) {
  const identityKey = operation.startsWith("withdraw_")
    ? "p_expected_requester_profile_id"
    : "p_expected_owner_profile_id";
  const { data, error } = await actor.client.rpc(operation, {
    [identityKey]: actor.id,
    p_request_id: requestId,
  });
  if (error || data !== requestId) {
    throw safeDatabaseFailure(operation.replaceAll("_", " "), error);
  }
}

async function closeListing(owner, listingId) {
  const { data, error } = await owner.client.rpc("close_resource_listing", {
    p_expected_owner_profile_id: owner.id,
    p_listing_id: listingId,
  });
  if (error || data !== listingId) {
    throw safeDatabaseFailure("close a resource listing", error);
  }
}

async function listOwnerRequests(owner, listingId) {
  const { data, error } = await owner.client.rpc(
    "list_resource_listing_requests",
    {
      p_expected_owner_profile_id: owner.id,
      p_listing_id: listingId,
    },
  );
  if (error || !Array.isArray(data)) {
    throw safeDatabaseFailure("list owner resource requests", error);
  }
  return data;
}

async function listOwnRequests(requester) {
  const { data, error } = await requester.client.rpc(
    "list_own_resource_listing_requests",
    { p_expected_requester_profile_id: requester.id },
  );
  if (error || !Array.isArray(data)) {
    throw safeDatabaseFailure("list own resource requests", error);
  }
  return data;
}

async function assertPublicCount(listingId, expectedCount) {
  const [
    { data: cards, error: cardsError },
    { data: detail, error: detailError },
  ] = await Promise.all([
    anonymous.rpc("list_public_resource_listings", {
      p_limit: 50,
      p_cursor_published_at: null,
      p_cursor_id: null,
      p_listing_mode: null,
      p_locality: null,
      p_query: null,
    }),
    anonymous.rpc("get_public_resource_listing", {
      p_listing_id: listingId,
    }),
  ]);
  const card = cards?.find((candidate) => candidate.listing_id === listingId);
  if (
    cardsError ||
    detailError ||
    card?.active_request_count !== expectedCount ||
    detail?.[0]?.active_request_count !== expectedCount ||
    "requester_profile_id" in card ||
    "request_message" in card
  ) {
    throw new Error(
      "Public active interest was incorrect or leaked request data.",
    );
  }
}

async function readRequestStatuses(requestIds) {
  return sql`
    select id, status
    from public.resource_listing_requests
    where id = any(${requestIds}::uuid[])
  `;
}

function assertStatuses(rows, expectedStatuses) {
  if (
    rows.length !== expectedStatuses.size ||
    rows.some((row) => expectedStatuses.get(row.id) !== row.status)
  ) {
    throw new Error(
      "Resource request statuses did not match canonical history.",
    );
  }
}

async function assertRequestStatus(requestId, expectedStatus) {
  const [row] = await sql`
    select status
    from public.resource_listing_requests
    where id = ${requestId}::uuid
  `;
  if (row?.status !== expectedStatus) {
    throw new Error(
      "A serialized request transition produced the wrong state.",
    );
  }
}

async function assertIdentifierOnlyEvents(privateMessages) {
  const events = await sql`
    select event_type, payload
    from private.outbox_events
    where event_type in (
      'resource_listing.request_created',
      'resource_listing.request_accepted',
      'resource_listing.request_rejected',
      'resource_listing.request_withdrawn',
      'resource_listing.request_closed'
    )
  `;
  const expectedKeys = [
    "actor_profile_id",
    "listing_id",
    "owner_profile_id",
    "request_id",
    "requester_profile_id",
  ];
  if (events.length === 0) {
    throw new Error("Resource request transitions emitted no outbox events.");
  }
  for (const event of events) {
    const keys = Object.keys(event.payload ?? {}).sort();
    if (JSON.stringify(keys) !== JSON.stringify(expectedKeys)) {
      throw new Error("A resource request event was not identifier-only.");
    }
    const serialized = JSON.stringify(event.payload);
    if (privateMessages.some((message) => serialized.includes(message))) {
      throw new Error(
        "A private resource request message leaked into an event.",
      );
    }
  }

  const [{ leaked_audit: leakedAudit }] = await sql`
    select count(*)::integer as leaked_audit
    from private.audit_events
    where action like 'resource_listing.request_%'
      and (
        metadata ? 'request_message'
        or metadata ? 'listing_title'
        or metadata ? 'display_name'
      )
  `;
  if (leakedAudit !== 0) {
    throw new Error("Private request content leaked into audit metadata.");
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
        "create a request-verifier profile",
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
    throw safeDatabaseFailure("complete a request-verifier profile", error);
  }
}

function signInWithLocalOtp(email) {
  return signInLocalOtpUser({
    apiUrl,
    publishableKey,
    mailpitUrl,
    email,
    verifierName: "resource listing request verifier",
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

async function assertTrackedRpcValue(tracked, expectedValue, action) {
  const result = await tracked.promise;
  if (result.error || result.data !== expectedValue) {
    throw safeDatabaseFailure(action, result.error);
  }
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
