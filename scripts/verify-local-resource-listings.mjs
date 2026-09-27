import { createClient } from "@supabase/supabase-js";
import postgres from "postgres";

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
    "Local Supabase status is missing the direct database URL required for identifier-only audit/outbox assertions.",
  );
}

const sql = postgres(databaseUrl, { max: 2, onnotice: () => {} });
const userAEmail = "resource-listing-integration-a@planets.invalid";
const userBEmail = "resource-listing-integration-b@planets.invalid";

try {
  await verifyResourceListings();
} finally {
  await sql.end({ timeout: 5 });
}

async function verifyResourceListings() {
  const [userA, userB] = await Promise.all([
    signInWithLocalOtp(userAEmail),
    signInWithLocalOtp(userBEmail),
  ]);
  await Promise.all([
    ensureCompleteProfile(userA, "Resource Owner A", "private"),
    ensureCompleteProfile(userB, "Resource Owner B", "public"),
  ]);
  await Promise.all(
    [userA, userB].map((user) => ensureLocalProfilePhoto(user)),
  );

  const anonymous = createClient(apiUrl, publishableKey, {
    auth: { persistSession: false },
  });

  const draftId = await createDraft(userA, {
    listingMode: "donate",
    title: "  Table idea  ",
  });

  const [draftList, draftDetail] = await Promise.all([
    listPublic(anonymous, {}),
    getPublic(anonymous, draftId),
  ]);
  if (
    draftList.some((listing) => listing.listing_id === draftId) ||
    draftDetail.length !== 0
  ) {
    throw new Error("An incomplete draft was exposed through a public RPC.");
  }

  const { data: anonymousDirectRows, error: anonymousDirectError } =
    await anonymous.from("resource_listings").select("id");
  if (!anonymousDirectError || anonymousDirectRows !== null) {
    throw new Error(
      "Anonymous direct listing-table access did not fail closed.",
    );
  }

  const { error: crossEditError } = await userB.client.rpc(
    "update_own_resource_listing",
    listingParams(userB.id, draftId, {
      listingMode: "donate",
      title: "Cross-account overwrite",
    }),
  );
  if (crossEditError?.code !== "42501") {
    throw new Error("Cross-account listing mutation did not fail closed.");
  }

  const { data: crossReadRows, error: crossReadError } = await userB.client.rpc(
    "get_own_resource_listing",
    {
      p_expected_owner_profile_id: userB.id,
      p_listing_id: draftId,
    },
  );
  if (crossReadError || crossReadRows?.length !== 0) {
    throw new Error("Another profile could read a private owner listing form.");
  }

  const { data: authenticatedDirectRows, error: authenticatedDirectError } =
    await userB.client.from("resource_listings").select("id");
  if (!authenticatedDirectError || authenticatedDirectRows !== null) {
    throw new Error(
      "Authenticated direct listing-table access did not fail closed.",
    );
  }

  const { error: incompletePublishError } = await userA.client.rpc(
    "publish_resource_listing",
    {
      p_expected_owner_profile_id: userA.id,
      p_listing_id: draftId,
    },
  );
  if (incompletePublishError?.code !== "22023") {
    throw new Error("An incomplete resource listing draft was publishable.");
  }

  const donateDescription =
    "Solid wood table available for a new home in the neighborhood.";
  await updateListing(userA, draftId, {
    listingMode: "donate",
    title: "Community table",
    description: donateDescription,
    countryCode: "it",
    locality: "Trento",
    administrativeArea: "Povo",
    publicLocationLabel: "Trento · Povo",
  });
  await publish(userA, draftId);
  await publish(userA, draftId);

  const [donateCards, donateDetail] = await Promise.all([
    listPublic(anonymous, { listingMode: "donate" }),
    getPublic(anonymous, draftId),
  ]);
  const donateCard = donateCards.find(
    (listing) => listing.listing_id === draftId,
  );
  if (!donateCard || donateDetail.length !== 1) {
    throw new Error(
      "A published donate listing was missing from public reads.",
    );
  }
  assertExactKeys(donateCard, [
    "active_request_count",
    "administrative_area",
    "country_code",
    "description",
    "listing_id",
    "listing_mode",
    "locality",
    "public_location_label",
    "published_at",
    "title",
  ]);
  assertExactKeys(donateDetail[0], [
    "active_request_count",
    "administrative_area",
    "country_code",
    "description",
    "listing_id",
    "listing_mode",
    "locality",
    "owner_display_name",
    "owner_profile_id",
    "public_location_label",
    "published_at",
    "title",
  ]);
  if (
    donateCard.country_code !== "IT" ||
    donateCard.locality !== "Trento" ||
    donateCard.public_location_label !== "Trento · Povo" ||
    donateCard.active_request_count !== 0 ||
    donateDetail[0].owner_profile_id !== userA.id ||
    donateDetail[0].owner_display_name !== null ||
    donateDetail[0].active_request_count !== 0 ||
    JSON.stringify(donateDetail[0]).includes(userAEmail)
  ) {
    throw new Error(
      "Public listing data was not normalized, narrow, or display-name-private.",
    );
  }

  await ensureCompleteProfile(userA, "Resource Owner A", "public");
  const visibleOwnerDetail = await getPublic(anonymous, draftId);
  if (visibleOwnerDetail[0]?.owner_display_name !== "Resource Owner A") {
    throw new Error(
      "Public listing detail did not follow the owner's public display-name visibility.",
    );
  }

  const exchangeDescription =
    "Battery and charger included for a practical exchange arrangement.";
  const exchangeId = await createDraft(userA, {
    listingMode: "exchange",
    title: "Cordless drill",
    description: exchangeDescription,
    countryCode: "IT",
    locality: "Rovereto",
    administrativeArea: null,
    publicLocationLabel: "Rovereto",
  });
  await publish(userA, exchangeId);

  const [donateOnly, exchangeOnly, trentoOnly, titleMatch, bodyMatch, noMatch] =
    await Promise.all([
      listPublic(anonymous, { listingMode: "donate" }),
      listPublic(anonymous, { listingMode: "exchange" }),
      listPublic(anonymous, { locality: " trento " }),
      listPublic(anonymous, { query: "CORDLESS" }),
      listPublic(anonymous, { query: "charger included" }),
      listPublic(anonymous, { query: "absent search phrase" }),
    ]);
  assertOnlyListing(donateOnly, draftId, "donate mode");
  assertOnlyListing(exchangeOnly, exchangeId, "exchange mode");
  assertOnlyListing(trentoOnly, draftId, "locality");
  assertOnlyListing(titleMatch, exchangeId, "title keyword");
  assertOnlyListing(bodyMatch, exchangeId, "description keyword");
  if (noMatch.length !== 0) {
    throw new Error("A nonmatching keyword returned a public listing.");
  }

  const { error: invalidModeError } = await anonymous.rpc(
    "list_public_resource_listings",
    publicListParams({ listingMode: "loan" }),
  );
  if (invalidModeError?.code !== "22023") {
    throw new Error("An invalid public listing mode filter did not fail.");
  }

  const firstPage = await listPublic(anonymous, { limit: 1 });
  if (firstPage.length !== 1 || firstPage[0].listing_id !== exchangeId) {
    throw new Error("Newest-first listing discovery order was unstable.");
  }
  const secondPage = await listPublic(anonymous, {
    limit: 1,
    cursorPublishedAt: firstPage[0].published_at,
    cursorId: firstPage[0].listing_id,
  });
  assertOnlyListing(secondPage, draftId, "paired keyset cursor");

  const authenticatedPublicRows = await listPublic(userB.client, {});
  const anonymousPublicRows = await listPublic(anonymous, {});
  if (
    JSON.stringify(authenticatedPublicRows) !==
    JSON.stringify(anonymousPublicRows)
  ) {
    throw new Error(
      "Anonymous and authenticated clients received different public listing data.",
    );
  }

  await updateListing(userA, draftId, {
    listingMode: "exchange",
    title: "Updated community table",
    description: "Solid wood table available for a practical exchange.",
    countryCode: "IT",
    locality: "Trento",
    administrativeArea: "Povo",
    publicLocationLabel: "Trento · Povo",
  });
  const updatedDetail = await getPublic(anonymous, draftId);
  if (
    updatedDetail[0]?.listing_mode !== "exchange" ||
    updatedDetail[0]?.title !== "Updated community table"
  ) {
    throw new Error(
      "A safe published edit did not remain public with its new discovery intent.",
    );
  }

  const { error: invalidPublishedEdit } = await userA.client.rpc(
    "update_own_resource_listing",
    listingParams(userA.id, draftId, {
      listingMode: "exchange",
      title: "Invalid published edit",
      description: null,
      countryCode: "IT",
      locality: "Trento",
      administrativeArea: "Povo",
      publicLocationLabel: "Trento · Povo",
    }),
  );
  if (invalidPublishedEdit?.code !== "22023") {
    throw new Error("An unpublishable published edit did not fail atomically.");
  }
  const afterRejectedEdit = await getPublic(anonymous, draftId);
  if (afterRejectedEdit[0]?.title !== "Updated community table") {
    throw new Error(
      "A rejected published edit changed canonical listing data.",
    );
  }

  await closeListing(userA, draftId);
  const [afterCloseList, afterCloseDetail, ownerHistory] = await Promise.all([
    listPublic(anonymous, {}),
    getPublic(anonymous, draftId),
    listOwn(userA),
  ]);
  if (
    afterCloseList.some((listing) => listing.listing_id === draftId) ||
    afterCloseDetail.length !== 0
  ) {
    throw new Error("A closed listing remained publicly available.");
  }
  const closedOwnerRow = ownerHistory.find(
    (listing) => listing.listing_id === draftId,
  );
  if (
    !closedOwnerRow ||
    closedOwnerRow.lifecycle_state !== "closed" ||
    !closedOwnerRow.published_at ||
    !closedOwnerRow.closed_at
  ) {
    throw new Error("A closed listing was not retained in owner history.");
  }

  const { error: secondCloseError } = await userA.client.rpc(
    "close_resource_listing",
    {
      p_expected_owner_profile_id: userA.id,
      p_listing_id: draftId,
    },
  );
  if (secondCloseError?.code !== "55000") {
    throw new Error(
      "Repeated listing closure was not terminal and deterministic.",
    );
  }

  const outboxEvents = await sql`
    select event_type, payload
    from private.outbox_events
    where payload ->> 'listing_id' in (${draftId}, ${exchangeId})
    order by created_at, id
  `;
  const auditEvents = await sql`
    select action, actor_user_id, target_type, target_id, metadata
    from private.audit_events
    where target_type = 'resource_listing'
      and target_id in (${draftId}, ${exchangeId})
    order by created_at, id
  `;
  if (outboxEvents.length !== 3 || auditEvents.length !== 3) {
    throw new Error(
      "Resource listing publication/closure did not produce the expected idempotent events.",
    );
  }
  for (const event of outboxEvents) {
    assertExactKeys(event.payload, [
      "listing_id",
      "listing_mode",
      "owner_profile_id",
    ]);
  }
  for (const event of auditEvents) {
    assertExactKeys(event.metadata, ["listing_mode"]);
    if (
      event.actor_user_id !== userA.id ||
      event.target_type !== "resource_listing" ||
      ![draftId, exchangeId].includes(event.target_id)
    ) {
      throw new Error(
        "A resource listing audit event had unsafe identity context.",
      );
    }
  }
  const operationalState = JSON.stringify({ outboxEvents, auditEvents });
  for (const forbidden of [
    donateDescription,
    exchangeDescription,
    "Updated community table",
    "Trento",
    "Rovereto",
    userAEmail,
    userBEmail,
  ]) {
    if (operationalState.includes(forbidden)) {
      throw new Error(
        "Resource listing audit/outbox state contained listing content, location, or contact data.",
      );
    }
  }

  console.log(
    "Confirmed two-owner resource listing identity, private drafts, publish/edit/close lifecycle, rough-location privacy, display-name visibility, public mode/locality/keyword filters, stable keyset pagination, and identifier-only audit/outbox events.",
  );
}

async function createDraft(user, input) {
  const { data, error } = await user.client.rpc(
    "create_resource_listing_draft",
    listingParams(user.id, null, input),
  );
  if (error || typeof data !== "string") {
    throw safeDatabaseFailure("create a resource listing draft", error ?? {});
  }
  return data;
}

async function updateListing(user, listingId, input) {
  const { error } = await user.client.rpc(
    "update_own_resource_listing",
    listingParams(user.id, listingId, input),
  );
  if (error) {
    throw safeDatabaseFailure("update a resource listing", error);
  }
}

async function publish(user, listingId) {
  const { error } = await user.client.rpc("publish_resource_listing", {
    p_expected_owner_profile_id: user.id,
    p_listing_id: listingId,
  });
  if (error) {
    throw safeDatabaseFailure("publish a resource listing", error);
  }
}

async function closeListing(user, listingId) {
  const { error } = await user.client.rpc("close_resource_listing", {
    p_expected_owner_profile_id: user.id,
    p_listing_id: listingId,
  });
  if (error) {
    throw safeDatabaseFailure("close a resource listing", error);
  }
}

async function listOwn(user) {
  const { data, error } = await user.client.rpc("list_own_resource_listings", {
    p_expected_owner_profile_id: user.id,
  });
  if (error || !Array.isArray(data)) {
    throw safeDatabaseFailure("list own resource listings", error ?? {});
  }
  return data;
}

async function listPublic(client, options) {
  const { data, error } = await client.rpc(
    "list_public_resource_listings",
    publicListParams(options),
  );
  if (error || !Array.isArray(data)) {
    throw safeDatabaseFailure("list public resource listings", error ?? {});
  }
  return data;
}

async function getPublic(client, listingId) {
  const { data, error } = await client.rpc("get_public_resource_listing", {
    p_listing_id: listingId,
  });
  if (error || !Array.isArray(data)) {
    throw safeDatabaseFailure(
      "read public resource listing detail",
      error ?? {},
    );
  }
  return data;
}

function listingParams(expectedOwnerId, listingId, input) {
  return {
    p_expected_owner_profile_id: expectedOwnerId,
    ...(listingId ? { p_listing_id: listingId } : {}),
    p_listing_mode: input.listingMode,
    p_title: input.title ?? null,
    p_description: input.description ?? null,
    p_country_code: input.countryCode ?? null,
    p_locality: input.locality ?? null,
    p_administrative_area: input.administrativeArea ?? null,
    p_public_location_label: input.publicLocationLabel ?? null,
  };
}

function publicListParams(options) {
  return {
    p_limit: options.limit ?? 20,
    p_cursor_published_at: options.cursorPublishedAt ?? null,
    p_cursor_id: options.cursorId ?? null,
    p_listing_mode: options.listingMode ?? null,
    p_locality: options.locality ?? null,
    p_query: options.query ?? null,
  };
}

function assertOnlyListing(rows, expectedId, filterName) {
  if (rows.length !== 1 || rows[0].listing_id !== expectedId) {
    throw new Error(
      `The ${filterName} listing filter returned unexpected rows.`,
    );
  }
}

function assertExactKeys(value, expectedKeys) {
  if (
    value === null ||
    Array.isArray(value) ||
    typeof value !== "object" ||
    JSON.stringify(Object.keys(value).sort()) !==
      JSON.stringify([...expectedKeys].sort())
  ) {
    throw new Error(
      "A resource listing boundary returned an unexpected shape.",
    );
  }
}

async function ensureCompleteProfile(user, displayName, displayNameAudience) {
  const { error: anchorError } = await user.client
    .from("profiles")
    .insert({ id: user.id });
  if (anchorError) {
    const diagnostic = `${anchorError.message ?? ""} ${anchorError.details ?? ""}`;
    if (anchorError.code !== "23505" || !diagnostic.includes("profiles_pkey")) {
      throw safeDatabaseFailure(
        "create a resource-listing profile anchor",
        anchorError,
      );
    }
  }

  const { error: updateError } = await user.client.rpc("update_own_profile", {
    p_expected_profile_id: user.id,
    p_display_name: displayName,
    p_bio: null,
    p_skill_ids: [],
    p_display_name_audience: displayNameAudience,
    p_bio_audience: "private",
    p_skills_audience: "private",
  });
  if (updateError) {
    throw safeDatabaseFailure(
      "complete a resource-listing test profile",
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
      "request a local resource-listing OTP",
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
    "read a local resource-listing OTP email",
  );
  const messageBody = `${message.Text ?? ""} ${message.HTML ?? ""}`;
  const token = messageBody.match(/(?:^|\D)(\d{6})(?:\D|$)/)?.[1];
  if (!token) {
    throw new Error(
      "A local resource-listing sign-in email did not contain a 6-digit token.",
    );
  }

  const { data: verification, error: verificationError } =
    await client.auth.verifyOtp({ email, token, type: "email" });
  if (verificationError || !verification.user?.id || !verification.session) {
    throw safeDatabaseFailure(
      "verify a local resource-listing OTP",
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
    "Mailpit did not receive a resource-listing OTP email within 15 seconds.",
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
