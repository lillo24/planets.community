import { randomUUID } from "node:crypto";

import { createClient } from "@supabase/supabase-js";
import postgres from "postgres";

import { signInLocalOtpUser } from "./lib/local-authenticated-user.mjs";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";

const { apiUrl, publishableKey, serviceRoleKey, databaseUrl } =
  readLocalSupabaseStatus(process.cwd());
if (!serviceRoleKey || !databaseUrl) {
  throw new Error(
    "Local Supabase status is missing the trusted service key or direct database URL required for saved-search matching verification.",
  );
}

const mailpitUrl = (
  process.env.MAILPIT_URL ?? "http://127.0.0.1:54324"
).replace(/\/$/u, "");
const service = createClient(apiUrl, serviceRoleKey, {
  auth: { persistSession: false },
});
const secondService = createClient(apiUrl, serviceRoleKey, {
  auth: { persistSession: false },
});
const sql = postgres(databaseUrl, { max: 4, onnotice: () => {} });
const runMarker = randomUUID().slice(0, 8);

try {
  await verifySavedSearchMatching();
} finally {
  await sql.end({ timeout: 5 });
}

async function verifySavedSearchMatching() {
  const [searchOwner, secondRecipient, listingOwner] = await Promise.all([
    signInLocalOtpUser({
      apiUrl,
      publishableKey,
      mailpitUrl,
      email: "resource-matching-search-owner@planets.invalid",
      verifierName: "Saved-search matching verifier",
    }),
    signInLocalOtpUser({
      apiUrl,
      publishableKey,
      mailpitUrl,
      email: "resource-matching-second-recipient@planets.invalid",
      verifierName: "Saved-search matching verifier",
    }),
    signInLocalOtpUser({
      apiUrl,
      publishableKey,
      mailpitUrl,
      email: "resource-matching-listing-owner@planets.invalid",
      verifierName: "Saved-search matching verifier",
    }),
  ]);

  await Promise.all([
    completeProfile(searchOwner, "Matching Search Owner"),
    completeProfile(secondRecipient, "Matching Second Recipient"),
    completeProfile(listingOwner, "Matching Listing Owner"),
  ]);
  await Promise.all([
    clearSavedSearches(searchOwner),
    clearSavedSearches(secondRecipient),
    clearSavedSearches(listingOwner),
  ]);
  await drainProjector();

  const listingIds = [];

  const querySearchId = await createSavedSearch(searchOwner, {
    query: `Projector ${runMarker}`,
  });
  const localitySearchId = await createSavedSearch(searchOwner, {
    locality: `Locality ${runMarker}`,
  });
  const secondRecipientSearchId = await createSavedSearch(secondRecipient, {
    listingMode: "donate",
  });
  const ownerSearchId = await createSavedSearch(listingOwner, {
    query: `Projector ${runMarker}`,
  });

  const historicalListingId = await createListing(listingOwner, {
    title: `Projector ${runMarker} historical`,
    description: "Historical rollout fixture",
    locality: `Locality ${runMarker}`,
  });
  listingIds.push(historicalListingId);
  await publishListing(listingOwner, historicalListingId);
  const historicalEvent = await getPublicationEvent(historicalListingId);
  await sql`
    insert into private.outbox_consumer_receipts (
      outbox_event_id,
      consumer_key,
      processed_at
    )
    values (
      ${historicalEvent.id}::uuid,
      'saved-search-matching.v1',
      statement_timestamp()
    )
    on conflict do nothing
  `;
  await drainProjector();
  await assertMatchCount(
    historicalListingId,
    0,
    "historical pre-receipted publication",
  );

  const matchingListingId = await createListing(listingOwner, {
    title: `Projector ${runMarker} drill`,
    description: `Controlled description ${runMarker}`,
    locality: `Locality ${runMarker}`,
  });
  listingIds.push(matchingListingId);
  await publishListing(listingOwner, matchingListingId);
  const matchingEvent = await getPublicationEvent(matchingListingId);

  await sql`
    insert into private.outbox_consumer_receipts (
      outbox_event_id,
      consumer_key,
      processed_at
    )
    values
      (${matchingEvent.id}::uuid, 'notifications.v1', statement_timestamp()),
      (${matchingEvent.id}::uuid, 'push.v1', statement_timestamp())
    on conflict do nothing
  `;

  const matchResult = await processBatch(service, 100);
  if (
    matchResult.processed_count !== 1 ||
    matchResult.matches_created !== 3 ||
    matchResult.matches_suppressed !== 1
  ) {
    throw new Error(
      "Trusted matching projection did not create the expected multi-search, multi-recipient, self-suppressed fan-out.",
    );
  }

  const matchRows = await sql`
    select
      match.id,
      match.saved_search_id,
      match.saved_search_updated_at,
      match.recipient_profile_id,
      match.listing_id,
      match.matched_at,
      event.id as derived_event_id,
      event.payload,
      event.created_at as derived_created_at
    from private.resource_saved_search_listing_matches as match
    join private.outbox_events as event
      on event.event_type = 'resource_saved_search.matched'
      and event.payload ->> 'saved_search_match_id' = match.id::text
    where match.listing_id = ${matchingListingId}::uuid
    order by match.saved_search_id
  `;
  if (matchRows.length !== 3) {
    throw new Error("Matching projection did not persist exactly three facts.");
  }
  const expectedSearchIds = new Set([
    querySearchId,
    localitySearchId,
    secondRecipientSearchId,
  ]);
  for (const row of matchRows) {
    if (!expectedSearchIds.delete(row.saved_search_id)) {
      throw new Error(
        "Matching projection emitted an unexpected saved-search fact.",
      );
    }
    assertExactKeys(row.payload, [
      "saved_search_match_id",
      "saved_search_id",
      "recipient_profile_id",
      "listing_id",
    ]);
    if (
      row.payload.saved_search_match_id !== row.id ||
      row.payload.saved_search_id !== row.saved_search_id ||
      row.payload.recipient_profile_id !== row.recipient_profile_id ||
      row.payload.listing_id !== matchingListingId ||
      new Date(row.matched_at).getTime() !==
        new Date(matchingEvent.created_at).getTime() ||
      new Date(row.derived_created_at).getTime() !==
        new Date(matchingEvent.created_at).getTime()
    ) {
      throw new Error(
        "A derived event diverged from its identifier-only fact or source chronology.",
      );
    }
    const serializedPayload = JSON.stringify(row.payload).toLowerCase();
    if (
      serializedPayload.includes("projector") ||
      serializedPayload.includes("locality") ||
      serializedPayload.includes("controlled description")
    ) {
      throw new Error(
        "A derived match payload leaked controlled fixture text.",
      );
    }
  }
  if (expectedSearchIds.size !== 0) {
    throw new Error("One eligible saved search was omitted from the fan-out.");
  }
  if (matchRows.some((row) => row.saved_search_id === ownerSearchId)) {
    throw new Error("A listing owner received a self-owned match fact.");
  }

  const [independence] = await sql`
    select
      count(*) filter (
        where receipt.consumer_key = 'saved-search-matching.v1'
      )::integer as matching_receipts,
      count(*) filter (
        where receipt.consumer_key = 'notifications.v1'
      )::integer as notification_receipts,
      count(*) filter (
        where receipt.consumer_key = 'push.v1'
      )::integer as push_receipts,
      (
        select count(*)::integer
        from public.notifications
        where source_outbox_event_id = ${matchingEvent.id}::uuid
      ) as notifications,
      (
        select count(*)::integer
        from private.push_delivery_jobs
        where source_outbox_event_id = ${matchingEvent.id}::uuid
      ) as push_jobs
    from private.outbox_consumer_receipts as receipt
    where receipt.outbox_event_id = ${matchingEvent.id}::uuid
  `;
  if (
    independence?.matching_receipts !== 1 ||
    independence.notification_receipts !== 1 ||
    independence.push_receipts !== 1 ||
    independence.notifications !== 0 ||
    independence.push_jobs !== 0
  ) {
    throw new Error(
      "Matching projection did not remain independent from notification and push consumers.",
    );
  }

  const idempotentResult = await processBatch(service, 100);
  if (
    idempotentResult.processed_count !== 0 ||
    idempotentResult.matches_created !== 0
  ) {
    throw new Error("A second trusted projection run was not idempotent.");
  }

  await Promise.all([
    clearSavedSearches(searchOwner),
    clearSavedSearches(secondRecipient),
    clearSavedSearches(listingOwner),
  ]);

  const createdAfterListingId = await createListing(listingOwner, {
    title: `Created-after ${runMarker}`,
    description: "Created-after boundary fixture",
    locality: "Boundary",
  });
  listingIds.push(createdAfterListingId);
  await publishListing(listingOwner, createdAfterListingId);
  await createSavedSearch(searchOwner, {
    query: `Created-after ${runMarker}`,
  });
  await drainProjector();
  await assertMatchCount(
    createdAfterListingId,
    0,
    "search created after publication",
  );
  await clearSavedSearches(searchOwner);

  const updateSearchId = await createSavedSearch(searchOwner, {
    query: `Old-definition ${runMarker}`,
  });
  const updateBoundaryListingId = await createListing(listingOwner, {
    title: `New-definition ${runMarker}`,
    description: "Update boundary fixture",
    locality: "Boundary",
  });
  listingIds.push(updateBoundaryListingId);
  await publishListing(listingOwner, updateBoundaryListingId);
  await updateSavedSearch(searchOwner, updateSearchId, {
    query: `New-definition ${runMarker}`,
  });
  await drainProjector();
  await assertMatchCount(
    updateBoundaryListingId,
    0,
    "search edited after publication",
  );

  const futureListingId = await createListing(listingOwner, {
    title: `New-definition ${runMarker}`,
    description: "Future publication fixture",
    locality: "Boundary",
  });
  listingIds.push(futureListingId);
  await publishListing(listingOwner, futureListingId);
  await drainProjector();
  const [futureVersion] = await sql`
    select
      match.saved_search_updated_at,
      saved_search.updated_at as current_saved_search_updated_at
    from private.resource_saved_search_listing_matches as match
    join public.resource_saved_searches as saved_search
      on saved_search.id = match.saved_search_id
    where match.saved_search_id = ${updateSearchId}::uuid
      and match.listing_id = ${futureListingId}::uuid
  `;
  if (
    !futureVersion ||
    new Date(futureVersion.saved_search_updated_at).getTime() !==
      new Date(futureVersion.current_saved_search_updated_at).getTime()
  ) {
    throw new Error(
      "A future publication did not capture the edited search version token.",
    );
  }

  await clearSavedSearches(searchOwner);
  const closedSearchId = await createSavedSearch(searchOwner, {
    query: `Closed-before ${runMarker}`,
  });
  const closedListingId = await createListing(listingOwner, {
    title: `Closed-before ${runMarker}`,
    description: "Closed-before projection fixture",
    locality: "Boundary",
  });
  listingIds.push(closedListingId);
  await publishListing(listingOwner, closedListingId);
  await closeListing(listingOwner, closedListingId);
  await drainProjector();
  await assertMatchCount(
    closedListingId,
    0,
    "listing closed before delayed projection",
  );
  await deleteSavedSearch(searchOwner, closedSearchId);

  await Promise.all([
    clearSavedSearches(searchOwner),
    clearSavedSearches(secondRecipient),
    clearSavedSearches(listingOwner),
  ]);
  await drainProjector();

  const concurrentListingA = await createListing(listingOwner, {
    title: `Concurrent A ${runMarker}`,
    description: "Concurrent worker fixture A",
    locality: "Boundary",
  });
  const concurrentListingB = await createListing(listingOwner, {
    title: `Concurrent B ${runMarker}`,
    description: "Concurrent worker fixture B",
    locality: "Boundary",
  });
  listingIds.push(concurrentListingA, concurrentListingB);
  await Promise.all([
    publishListing(listingOwner, concurrentListingA),
    publishListing(listingOwner, concurrentListingB),
  ]);
  const concurrentResults = await Promise.all([
    processBatch(service, 1),
    processBatch(secondService, 1),
  ]);
  if (
    concurrentResults.reduce(
      (total, result) => total + result.processed_count,
      0,
    ) !== 2 ||
    concurrentResults.some((result) => result.processed_count !== 1)
  ) {
    throw new Error(
      "Concurrent service workers did not claim one independent source each.",
    );
  }
  for (const listingId of [concurrentListingA, concurrentListingB]) {
    const event = await getPublicationEvent(listingId);
    const [receiptCount] = await sql`
      select count(*)::integer as count
      from private.outbox_consumer_receipts
      where outbox_event_id = ${event.id}::uuid
        and consumer_key = 'saved-search-matching.v1'
    `;
    if (receiptCount?.count !== 1) {
      throw new Error("Concurrent workers did not leave one stable receipt.");
    }
  }

  for (const listingId of listingIds) {
    await closeIfPublished(listingOwner, listingId);
  }
  await Promise.all([
    clearSavedSearches(searchOwner),
    clearSavedSearches(secondRecipient),
    clearSavedSearches(listingOwner),
  ]);

  console.log(
    "Confirmed real-OTP saved-search matching, rollout no-backfill semantics, multi-recipient fan-out, self suppression, event-time create/update boundaries, closed-listing suppression, identifier-only events, independent receipts, idempotency, and concurrent trusted workers.",
  );
}

async function completeProfile(user, displayName) {
  const { error: anchorError } = await user.client
    .from("profiles")
    .insert({ id: user.id });
  if (
    anchorError &&
    (anchorError.code !== "23505" ||
      !`${anchorError.message ?? ""} ${anchorError.details ?? ""}`.includes(
        "profiles_pkey",
      ))
  ) {
    throw failure("create verifier profile", anchorError);
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
  if (error) throw failure("complete verifier profile", error);
}

async function createListing(user, { title, description, locality }) {
  return rpcId(user.client, "create_resource_listing_draft", {
    p_expected_owner_profile_id: user.id,
    p_listing_mode: "donate",
    p_title: title,
    p_description: description,
    p_country_code: "IT",
    p_locality: locality,
    p_administrative_area: null,
    p_public_location_label: locality,
  });
}

async function publishListing(user, listingId) {
  await rpcId(user.client, "publish_resource_listing", {
    p_expected_owner_profile_id: user.id,
    p_listing_id: listingId,
  });
}

async function closeListing(user, listingId) {
  await rpcId(user.client, "close_resource_listing", {
    p_expected_owner_profile_id: user.id,
    p_listing_id: listingId,
  });
}

async function closeIfPublished(user, listingId) {
  const [listing] = await sql`
    select lifecycle_state
    from public.resource_listings
    where id = ${listingId}::uuid
  `;
  if (listing?.lifecycle_state === "published") {
    await closeListing(user, listingId);
  }
}

async function createSavedSearch(user, input) {
  return rpcId(user.client, "create_resource_saved_search", {
    p_expected_profile_id: user.id,
    p_query: input.query ?? null,
    p_listing_mode: input.listingMode ?? null,
    p_locality: input.locality ?? null,
  });
}

async function updateSavedSearch(user, savedSearchId, input) {
  return rpcId(user.client, "update_resource_saved_search", {
    p_expected_profile_id: user.id,
    p_saved_search_id: savedSearchId,
    p_query: input.query ?? null,
    p_listing_mode: input.listingMode ?? null,
    p_locality: input.locality ?? null,
  });
}

async function deleteSavedSearch(user, savedSearchId) {
  await rpcId(user.client, "delete_resource_saved_search", {
    p_expected_profile_id: user.id,
    p_saved_search_id: savedSearchId,
  });
}

async function clearSavedSearches(user) {
  for (;;) {
    const rows = await rpcRows(
      user.client,
      "list_own_resource_saved_searches",
      {
        p_expected_profile_id: user.id,
        p_limit: 50,
        p_cursor_updated_at: null,
        p_cursor_id: null,
      },
    );
    if (rows.length === 0) return;
    for (const row of rows) {
      await deleteSavedSearch(user, row.saved_search_id);
    }
  }
}

async function getPublicationEvent(listingId) {
  const [event] = await sql`
    select id, created_at
    from private.outbox_events
    where event_type = 'resource_listing.published'
      and payload ->> 'listing_id' = ${listingId}
    order by created_at desc, id desc
    limit 1
  `;
  if (!event) {
    throw new Error("A published listing did not create its canonical event.");
  }
  return event;
}

async function processBatch(client, limit) {
  const rows = await rpcRows(
    client,
    "process_resource_saved_search_matching_outbox_batch",
    { p_limit: limit },
  );
  if (
    rows.length !== 1 ||
    !Number.isInteger(rows[0].processed_count) ||
    !Number.isInteger(rows[0].matches_created) ||
    !Number.isInteger(rows[0].matches_suppressed)
  ) {
    throw new Error(
      "The trusted projector returned an unexpected result shape.",
    );
  }
  return rows[0];
}

async function drainProjector() {
  for (;;) {
    const result = await processBatch(service, 100);
    if (result.processed_count === 0) return;
  }
}

async function assertMatchCount(listingId, expected, action) {
  const [result] = await sql`
    select count(*)::integer as count
    from private.resource_saved_search_listing_matches
    where listing_id = ${listingId}::uuid
  `;
  if (result?.count !== expected) {
    throw new Error(`Unexpected match count for ${action}.`);
  }
}

async function rpcId(client, name, args) {
  const { data, error } = await client.rpc(name, args);
  if (error || typeof data !== "string") throw failure(name, error);
  return data;
}

async function rpcRows(client, name, args) {
  const { data, error } = await client.rpc(name, args);
  if (error || !Array.isArray(data)) throw failure(name, error);
  return data;
}

function assertExactKeys(value, expectedKeys) {
  if (
    value === null ||
    Array.isArray(value) ||
    typeof value !== "object" ||
    JSON.stringify(Object.keys(value).sort()) !==
      JSON.stringify([...expectedKeys].sort())
  ) {
    throw new Error("A derived match event returned an unexpected shape.");
  }
}

function failure(action, error) {
  const code = /^[a-z0-9_]+$/iu.test(error?.code ?? "")
    ? error.code
    : "unknown";
  return new Error(`Failed to ${action} (code ${code}).`);
}
