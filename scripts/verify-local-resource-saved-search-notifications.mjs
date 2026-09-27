import { randomUUID } from "node:crypto";

import { createClient } from "@supabase/supabase-js";
import postgres from "postgres";

import { signInLocalOtpUser } from "./lib/local-authenticated-user.mjs";
import { ensureLocalProfilePhoto } from "./lib/local-profile-photo.mjs";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";

const { apiUrl, publishableKey, serviceRoleKey, databaseUrl } =
  readLocalSupabaseStatus(process.cwd());
if (!serviceRoleKey || !databaseUrl) {
  throw new Error(
    "Local Supabase status is missing the trusted service key or direct database URL required for saved-search notification verification.",
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
const privateLocality = `Verifier-private-locality-${runMarker}`;

try {
  await verifySavedSearchNotifications();
} finally {
  await sql.end({ timeout: 5 });
}

async function verifySavedSearchNotifications() {
  const [recipient, listingOwner] = await Promise.all([
    signInLocalOtpUser({
      apiUrl,
      publishableKey,
      mailpitUrl,
      email: "resource-matching-alert-recipient@planets.invalid",
      verifierName: "Saved-search notification verifier",
    }),
    signInLocalOtpUser({
      apiUrl,
      publishableKey,
      mailpitUrl,
      email: "resource-matching-alert-owner@planets.invalid",
      verifierName: "Saved-search notification verifier",
    }),
  ]);

  await Promise.all([
    completeProfile(recipient, "Matching Alert Recipient"),
    completeProfile(listingOwner, "Matching Alert Listing Owner"),
  ]);
  await Promise.all([
    ensureLocalProfilePhoto(recipient),
    ensureLocalProfilePhoto(listingOwner),
  ]);
  await Promise.all([
    clearSavedSearches(recipient),
    clearSavedSearches(listingOwner),
  ]);
  await setMatchingPreference(recipient, true, true);
  await drainAllProjectors();

  const listingIds = [];

  await createSavedSearch(recipient, {
    query: `ceramic-${runMarker}`,
  });
  await createSavedSearch(recipient, { locality: privateLocality });

  const firstListingId = await createListing(listingOwner, {
    title: `Ceramic-${runMarker} planter`,
    description: "Public first matching listing",
    locality: privateLocality,
  });
  listingIds.push(firstListingId);
  await publishListing(listingOwner, firstListingId);
  const matchingResult = await processSavedSearchBatch(service, 100);
  assert(
    matchingResult.processed_count === 1 &&
      matchingResult.matches_created === 2,
    "F3A did not create both saved-search provenance facts.",
  );
  const firstMatchEvents = await getMatchEvents(firstListingId);
  assert(firstMatchEvents.length === 2, "Expected two F3A match events.");

  const notificationResults = await Promise.all([
    processNotificationBatch(service, 1),
    processNotificationBatch(secondService, 1),
  ]);
  assertProjectionTotals(notificationResults, {
    processed: 2,
    created: 1,
    suppressed: 1,
    kind: "notification",
  });
  const pushResults = await Promise.all([
    processPushBatch(service, 1),
    processPushBatch(secondService, 1),
  ]);
  assertProjectionTotals(pushResults, {
    processed: 2,
    created: 1,
    suppressed: 1,
    kind: "push",
  });

  await assertListingDelivery({
    listingId: firstListingId,
    recipientId: recipient.id,
    expectedNotifications: 1,
    expectedJobs: 1,
    expectedMatchEvents: 2,
  });
  const inbox = await rpcRows(recipient.client, "list_own_notifications", {
    p_expected_profile_id: recipient.id,
    p_limit: 100,
    p_cursor_created_at: null,
    p_cursor_id: null,
  });
  const firstInboxRow = inbox.find(
    (row) => row.resource_listing_id === firstListingId,
  );
  assert(
    firstInboxRow?.category_slug === "matching" &&
      firstInboxRow.notification_kind === "matching_available" &&
      firstInboxRow.destination_kind === "matching_result" &&
      firstInboxRow.resource_listing_title === `Ceramic-${runMarker} planter` &&
      firstInboxRow.actor_profile_id === null &&
      firstInboxRow.project_id === null &&
      firstInboxRow.resource_request_id === null &&
      firstInboxRow.resource_agreement_id === null,
    "The inbox did not return the safe matching-result contract.",
  );
  await assertNoPrivateProjectionText(privateLocality);

  await setMatchingPreference(recipient, false, true);
  const pushOnlyListingId = await createListing(listingOwner, {
    title: `Ceramic-${runMarker} shelf`,
    description: "Channel independence fixture one",
    locality: privateLocality,
  });
  listingIds.push(pushOnlyListingId);
  await publishListing(listingOwner, pushOnlyListingId);
  await processSavedSearchBatch(service, 100);
  const disabledInApp = await processNotificationBatch(service, 100);
  const enabledPush = await processPushBatch(service, 100);
  assert(
    disabledInApp.processed_count === 2 &&
      disabledInApp.notifications_created === 0 &&
      disabledInApp.notifications_suppressed === 2 &&
      enabledPush.processed_count === 2 &&
      enabledPush.jobs_created === 1 &&
      enabledPush.jobs_suppressed === 1,
    "In-app-disabled/push-enabled Matching preference was not independent.",
  );
  await assertListingDelivery({
    listingId: pushOnlyListingId,
    recipientId: recipient.id,
    expectedNotifications: 0,
    expectedJobs: 1,
    expectedMatchEvents: 2,
  });

  await setMatchingPreference(recipient, true, false);
  const inAppOnlyListingId = await createListing(listingOwner, {
    title: `Ceramic-${runMarker} bowl`,
    description: "Channel independence fixture two",
    locality: privateLocality,
  });
  listingIds.push(inAppOnlyListingId);
  await publishListing(listingOwner, inAppOnlyListingId);
  await processSavedSearchBatch(service, 100);
  const enabledInApp = await processNotificationBatch(service, 100);
  const disabledPush = await processPushBatch(service, 100);
  assert(
    enabledInApp.processed_count === 2 &&
      enabledInApp.notifications_created === 1 &&
      enabledInApp.notifications_suppressed === 1 &&
      disabledPush.processed_count === 2 &&
      disabledPush.jobs_created === 0 &&
      disabledPush.jobs_suppressed === 2,
    "In-app-enabled/push-disabled Matching preference was not independent.",
  );
  await assertListingDelivery({
    listingId: inAppOnlyListingId,
    recipientId: recipient.id,
    expectedNotifications: 1,
    expectedJobs: 0,
    expectedMatchEvents: 2,
  });

  await setMatchingPreference(recipient, true, true);
  await clearSavedSearches(recipient);
  await assertListingDelivery({
    listingId: firstListingId,
    recipientId: recipient.id,
    expectedNotifications: 1,
    expectedJobs: 1,
    expectedMatchEvents: 2,
  });

  const staleSearchId = await createSavedSearch(recipient, {
    query: `stale-${runMarker}`,
  });
  const staleListingId = await createListing(listingOwner, {
    title: `Stale-${runMarker} listing`,
    description: "Stale version fixture",
    locality: "Trento",
  });
  listingIds.push(staleListingId);
  await publishListing(listingOwner, staleListingId);
  await processSavedSearchBatch(service, 100);
  await updateSavedSearch(recipient, staleSearchId, {
    query: `edited-${runMarker}`,
  });
  await projectBothChannels();
  await assertSuppressedDelivery(staleListingId, "stale saved-search version");

  await clearSavedSearches(recipient);
  const deletedSearchId = await createSavedSearch(recipient, {
    query: `deleted-${runMarker}`,
  });
  const deletedListingId = await createListing(listingOwner, {
    title: `Deleted-${runMarker} listing`,
    description: "Deleted search fixture",
    locality: "Trento",
  });
  listingIds.push(deletedListingId);
  await publishListing(listingOwner, deletedListingId);
  await processSavedSearchBatch(service, 100);
  await deleteSavedSearch(recipient, deletedSearchId);
  await projectBothChannels();
  await assertSuppressedDelivery(deletedListingId, "deleted saved search");

  const editedListingSearchId = await createSavedSearch(recipient, {
    query: `before-edit-${runMarker}`,
  });
  const editedListingId = await createListing(listingOwner, {
    title: `Before-edit-${runMarker} listing`,
    description: "Before edit fixture",
    locality: "Trento",
  });
  listingIds.push(editedListingId);
  await publishListing(listingOwner, editedListingId);
  await processSavedSearchBatch(service, 100);
  await updateListing(listingOwner, editedListingId, {
    title: "Current hammer listing",
    description: "The saved filter no longer matches",
    locality: "Trento",
  });
  await projectBothChannels();
  await assertSuppressedDelivery(
    editedListingId,
    "current listing no longer matching",
  );
  await deleteSavedSearch(recipient, editedListingSearchId);

  const closedListingSearchId = await createSavedSearch(recipient, {
    query: `closed-${runMarker}`,
  });
  const closedListingId = await createListing(listingOwner, {
    title: `Closed-${runMarker} listing`,
    description: "Closed-before-delivery fixture",
    locality: "Trento",
  });
  listingIds.push(closedListingId);
  await publishListing(listingOwner, closedListingId);
  await processSavedSearchBatch(service, 100);
  await closeListing(listingOwner, closedListingId);
  await projectBothChannels();
  await assertSuppressedDelivery(closedListingId, "closed listing");
  await deleteSavedSearch(recipient, closedListingSearchId);

  const repeatNotification = await processNotificationBatch(service, 100);
  const repeatPush = await processPushBatch(service, 100);
  assert(
    repeatNotification.processed_count === 0 &&
      repeatPush.processed_count === 0,
    "Repeated channel projection was not idempotently empty.",
  );

  for (const listingId of listingIds) {
    await closeIfPublished(listingOwner, listingId);
  }
  await Promise.all([
    clearSavedSearches(recipient),
    clearSavedSearches(listingOwner),
  ]);

  console.log(
    "Confirmed immediate saved-search matching alerts with one recipient/listing delivery, concurrent channel workers, independent Matching preferences, exact receipts, stale/deleted/search-filter/closed-listing suppression, safe inbox context, and private-text-free notification/push state.",
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

async function setMatchingPreference(user, inAppEnabled, pushEnabled) {
  const { error } = await user.client.rpc("set_own_notification_preference", {
    p_expected_profile_id: user.id,
    p_category_slug: "matching",
    p_in_app_enabled: inAppEnabled,
    p_push_enabled: pushEnabled,
  });
  if (error) throw failure("set Matching channel preference", error);
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

async function updateListing(user, listingId, input) {
  await rpcId(user.client, "update_own_resource_listing", {
    p_expected_owner_profile_id: user.id,
    p_listing_id: listingId,
    p_listing_mode: "donate",
    p_title: input.title,
    p_description: input.description,
    p_country_code: "IT",
    p_locality: input.locality,
    p_administrative_area: null,
    p_public_location_label: input.locality,
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
  await rpcId(user.client, "update_resource_saved_search", {
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

async function getMatchEvents(listingId) {
  return sql`
    select event.id, event.payload
    from private.outbox_events as event
    where event.event_type = 'resource_saved_search.matched'
      and event.payload ->> 'listing_id' = ${listingId}
    order by event.created_at, event.id
  `;
}

async function processSavedSearchBatch(client, limit) {
  const [result] = await rpcRows(
    client,
    "process_resource_saved_search_matching_outbox_batch",
    { p_limit: limit },
  );
  if (!result || !Number.isInteger(result.processed_count)) {
    throw new Error("Saved-search matching returned an unexpected shape.");
  }
  return result;
}

async function processNotificationBatch(client, limit) {
  const [result] = await rpcRows(client, "process_notification_outbox_batch", {
    p_limit: limit,
  });
  if (!result || !Number.isInteger(result.processed_count)) {
    throw new Error("Notification projection returned an unexpected shape.");
  }
  return result;
}

async function processPushBatch(client, limit) {
  const [result] = await rpcRows(client, "process_push_outbox_batch", {
    p_limit: limit,
  });
  if (!result || !Number.isInteger(result.processed_count)) {
    throw new Error("Push projection returned an unexpected shape.");
  }
  return result;
}

async function drainAllProjectors() {
  for (;;) {
    const result = await processSavedSearchBatch(service, 100);
    if (result.processed_count === 0) break;
  }
  for (;;) {
    const result = await processNotificationBatch(service, 100);
    if (result.processed_count === 0) break;
  }
  for (;;) {
    const result = await processPushBatch(service, 100);
    if (result.processed_count === 0) break;
  }
}

async function projectBothChannels() {
  await processNotificationBatch(service, 100);
  await processPushBatch(service, 100);
}

function assertProjectionTotals(results, expected) {
  const totals = results.reduce(
    (sum, result) => ({
      processed: sum.processed + result.processed_count,
      created:
        sum.created +
        (expected.kind === "notification"
          ? result.notifications_created
          : result.jobs_created),
      suppressed:
        sum.suppressed +
        (expected.kind === "notification"
          ? result.notifications_suppressed
          : result.jobs_suppressed),
    }),
    { processed: 0, created: 0, suppressed: 0 },
  );
  assert(
    totals.processed === expected.processed &&
      totals.created === expected.created &&
      totals.suppressed === expected.suppressed,
    `Concurrent ${expected.kind} workers returned unexpected totals.`,
  );
}

async function assertListingDelivery({
  listingId,
  recipientId,
  expectedNotifications,
  expectedJobs,
  expectedMatchEvents,
}) {
  const [row] = await sql`
    select
      (
        select count(*)::integer
        from public.notifications
        where recipient_profile_id = ${recipientId}::uuid
          and resource_listing_id = ${listingId}::uuid
          and category_slug = 'matching'
          and notification_kind = 'matching_available'
          and destination_kind = 'matching_result'
      ) as notifications,
      (
        select count(*)::integer
        from private.push_delivery_jobs
        where recipient_profile_id = ${recipientId}::uuid
          and resource_listing_id = ${listingId}::uuid
          and category_slug = 'matching'
          and notification_kind = 'matching_available'
          and destination_kind = 'matching_result'
      ) as jobs,
      (
        select count(*)::integer
        from private.outbox_events
        where event_type = 'resource_saved_search.matched'
          and payload ->> 'listing_id' = ${listingId}
      ) as match_events,
      (
        select count(*)::integer
        from private.outbox_consumer_receipts as receipt
        join private.outbox_events as event
          on event.id = receipt.outbox_event_id
        where event.event_type = 'resource_saved_search.matched'
          and event.payload ->> 'listing_id' = ${listingId}
          and receipt.consumer_key in ('notifications.v1', 'push.v1')
      ) as channel_receipts
  `;
  assert(
    row?.notifications === expectedNotifications &&
      row.jobs === expectedJobs &&
      row.match_events === expectedMatchEvents &&
      row.channel_receipts === expectedMatchEvents * 2,
    "Saved-search matching delivery or independent receipts were incorrect.",
  );
}

async function assertSuppressedDelivery(listingId, reason) {
  const events = await getMatchEvents(listingId);
  assert(events.length === 1, `Expected one match event for ${reason}.`);
  const [row] = await sql`
    select
      (
        select count(*)::integer
        from public.notifications
        where resource_listing_id = ${listingId}::uuid
          and category_slug = 'matching'
      ) as notifications,
      (
        select count(*)::integer
        from private.push_delivery_jobs
        where resource_listing_id = ${listingId}::uuid
          and category_slug = 'matching'
      ) as jobs,
      (
        select count(*)::integer
        from private.outbox_consumer_receipts
        where outbox_event_id = ${events[0].id}::uuid
          and consumer_key in ('notifications.v1', 'push.v1')
      ) as receipts
  `;
  assert(
    row?.notifications === 0 && row.jobs === 0 && row.receipts === 2,
    `The ${reason} boundary did not suppress and receipt both channels.`,
  );
}

async function assertNoPrivateProjectionText(privateText) {
  const [row] = await sql`
    select
      coalesce(string_agg(to_jsonb(notification)::text, ''), '') as notifications,
      (
        select coalesce(string_agg(to_jsonb(job)::text, ''), '')
        from private.push_delivery_jobs as job
        where job.category_slug = 'matching'
      ) as jobs,
      (
        select coalesce(string_agg(event.payload::text, ''), '')
        from private.outbox_events as event
        where event.event_type = 'resource_saved_search.matched'
      ) as events
    from public.notifications as notification
    where notification.category_slug = 'matching'
  `;
  const loweredPrivateText = privateText.toLowerCase();
  assert(
    !row.notifications.toLowerCase().includes(loweredPrivateText) &&
      !row.jobs.toLowerCase().includes(loweredPrivateText) &&
      !row.events.toLowerCase().includes(loweredPrivateText),
    "Private saved-search text leaked into projection state.",
  );
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

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function failure(action, error) {
  const code = /^[a-z0-9_]+$/iu.test(error?.code ?? "")
    ? error.code
    : "unknown";
  return new Error(`Failed to ${action} (code ${code}).`);
}
