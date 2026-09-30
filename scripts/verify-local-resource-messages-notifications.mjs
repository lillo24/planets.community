import { randomUUID } from "node:crypto";

import postgres from "postgres";

import { signInLocalOtpUser } from "./lib/local-authenticated-user.mjs";
import { ensureLocalProfilePhoto } from "./lib/local-profile-photo.mjs";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";

const repositoryRoot = process.cwd();
const mailpitUrl = (
  process.env.MAILPIT_URL ?? "http://127.0.0.1:54324"
).replace(/\/$/, "");
const { apiUrl, publishableKey, databaseUrl } =
  readLocalSupabaseStatus(repositoryRoot);

if (!databaseUrl) {
  throw new Error(
    "Local Supabase status is missing the database URL required for body-free projection assertions.",
  );
}

const sql = postgres(databaseUrl, { max: 4, onnotice: () => {} });

try {
  await verifyResourceMessagesNotifications();
} finally {
  await sql.end({ timeout: 5 });
}

async function verifyResourceMessagesNotifications() {
  const [owner, requester, unrelated] = await Promise.all([
    signInWithLocalOtp("resource-projection-owner@planets.invalid"),
    signInWithLocalOtp("resource-projection-requester@planets.invalid"),
    signInWithLocalOtp("resource-projection-unrelated@planets.invalid"),
  ]);
  await Promise.all([
    ensureCompleteProfile(owner, "Resource Projection Owner"),
    ensureCompleteProfile(requester, "Resource Projection Requester"),
    ensureCompleteProfile(unrelated, "Resource Projection Unrelated"),
  ]);
  await Promise.all([
    ensureLocalProfilePhoto(owner),
    ensureLocalProfilePhoto(requester),
    ensureLocalProfilePhoto(unrelated),
  ]);

  const listingId = await createPublishedListing(owner);
  const requestPrivateText = "Verifier request text must remain private";
  const requestId = await rpcValue(
    requester,
    "request_resource_listing",
    {
      p_expected_requester_profile_id: requester.id,
      p_listing_id: listingId,
      p_message: requestPrivateText,
    },
    "create a Resource request",
  );

  await projectBothChannels();
  await assertInboxKind(owner, "resource_request_received", {
    listingId,
    requestId,
    destination: "resource_request",
  });

  await rpcValue(
    owner,
    "accept_resource_listing_request",
    {
      p_expected_owner_profile_id: owner.id,
      p_request_id: requestId,
    },
    "accept the Resource request",
  );
  const [chat, agreement] = await Promise.all([
    getChatByRequest(requester, requestId),
    getAgreement(requester, requestId),
  ]);
  await projectBothChannels();
  await assertInboxKind(requester, "resource_request_accepted", {
    listingId,
    requestId,
    chatId: chat.chat_id,
    agreementId: agreement.agreement_id,
    destination: "resource_chat",
  });

  const projectId = randomUUID();
  const membershipId = randomUUID();
  await seedProjectConversation({
    ownerId: owner.id,
    requesterId: requester.id,
    projectId,
    requestId,
    membershipId,
  });

  const unifiedRequests = await rpcRows(
    requester,
    "list_own_structured_request_message_items",
    {
      p_expected_profile_id: requester.id,
      p_limit: 50,
      p_cursor_activity_at: null,
      p_cursor_item_kind: null,
      p_cursor_request_id: null,
    },
    "list unified Requests",
  );
  const sameIdRows = unifiedRequests.filter(
    (item) => item.request_id === requestId,
  );
  if (
    sameIdRows.length !== 2 ||
    !sameIdRows.some((item) => item.item_kind === "participation_request") ||
    !sameIdRows.some((item) => item.item_kind === "resource_request")
  ) {
    throw new Error(
      "Unified Requests did not preserve both discriminated domains.",
    );
  }
  const exactResource = await rpcRows(
    requester,
    "get_own_structured_request_message_item",
    {
      p_expected_profile_id: requester.id,
      p_item_kind: "resource_request",
      p_request_id: requestId,
    },
    "read the exact unified Resource request",
  );
  if (
    exactResource.length !== 1 ||
    exactResource[0].resource_chat_id !== chat.chat_id ||
    exactResource[0].project_id !== null
  ) {
    throw new Error(
      "The exact unified request violated its Resource XOR shape.",
    );
  }

  const unifiedChatsBefore = await listUnifiedChats(requester);
  if (
    !unifiedChatsBefore.some((item) => item.item_kind === "project_chat") ||
    !unifiedChatsBefore.some(
      (item) =>
        item.item_kind === "resource_chat" && item.chat_id === chat.chat_id,
    )
  ) {
    throw new Error(
      "Unified Chats did not return both canonical chat domains.",
    );
  }
  const activityBefore = unifiedChatsBefore.find(
    (item) => item.chat_id === chat.chat_id,
  ).activity_at;

  const chatPrivateText = "Verifier chat body must remain private";
  const message = await rpcRow(
    owner,
    "send_resource_request_chat_message",
    {
      p_expected_profile_id: owner.id,
      p_chat_id: chat.chat_id,
      p_body: chatPrivateText,
    },
    "send a Resource chat message",
  );
  await projectBothChannels();
  await assertInboxKind(requester, "resource_chat_message_received", {
    listingId,
    requestId,
    chatId: chat.chat_id,
    agreementId: agreement.agreement_id,
    messageId: message.message_id,
    destination: "resource_chat",
  });

  const termsPrivateText = "Verifier private terms note must remain private";
  const termsId = await rpcValue(
    owner,
    "propose_resource_exchange_terms",
    {
      p_expected_profile_id: owner.id,
      p_agreement_id: agreement.agreement_id,
      p_expected_current_terms_id: null,
      p_expected_pending_terms_id: null,
      p_owner_transfer_kind: "give",
      p_owner_lend_starts_at: null,
      p_owner_lend_ends_at: null,
      p_requester_transfer_kind: "none",
      p_requester_resource_description: null,
      p_requester_lend_starts_at: null,
      p_requester_lend_ends_at: null,
      p_private_note: termsPrivateText,
    },
    "propose Resource agreement terms",
  );
  await projectBothChannels();
  await assertInboxKind(requester, "resource_exchange_terms_proposed", {
    listingId,
    requestId,
    chatId: chat.chat_id,
    agreementId: agreement.agreement_id,
    destination: "resource_chat",
  });

  const unifiedChatsAfterProposal = await listUnifiedChats(requester);
  const resourceAfterProposal = unifiedChatsAfterProposal.find(
    (item) => item.chat_id === chat.chat_id,
  );
  if (
    resourceAfterProposal.activity_at <= activityBefore ||
    resourceAfterProposal.last_visible_message_id !== message.message_id ||
    resourceAfterProposal.last_visible_message_body !== chatPrivateText
  ) {
    throw new Error(
      "Agreement activity did not advance Resource chat activity while preserving the human preview.",
    );
  }

  await rpcValue(
    requester,
    "accept_resource_exchange_terms",
    {
      p_expected_profile_id: requester.id,
      p_agreement_id: agreement.agreement_id,
      p_expected_pending_terms_id: termsId,
    },
    "accept Resource agreement terms",
  );
  await projectBothChannels();
  await assertInboxKind(owner, "resource_exchange_terms_accepted", {
    agreementId: agreement.agreement_id,
  });

  const providedEventId = await rpcValue(
    owner,
    "record_resource_exchange_milestone",
    {
      p_expected_profile_id: owner.id,
      p_agreement_id: agreement.agreement_id,
      p_expected_terms_id: termsId,
      p_leg_kind: "owner_resource",
      p_event_kind: "resource_provided",
    },
    "record the Resource provided milestone",
  );
  await projectBothChannels();
  const milestoneAlert = await assertInboxKind(
    requester,
    "resource_exchange_milestone_recorded",
    { agreementId: agreement.agreement_id },
  );
  if (
    milestoneAlert.resource_agreement_event_id !== providedEventId ||
    milestoneAlert.resource_exchange_event_kind !== "resource_provided" ||
    milestoneAlert.resource_exchange_leg_kind !== "owner_resource"
  ) {
    throw new Error("Milestone inbox context did not resolve canonical enums.");
  }

  await rpcValue(
    requester,
    "record_resource_exchange_milestone",
    {
      p_expected_profile_id: requester.id,
      p_agreement_id: agreement.agreement_id,
      p_expected_terms_id: termsId,
      p_leg_kind: "owner_resource",
      p_event_kind: "resource_received",
    },
    "record the Resource received milestone",
  );
  await projectBothChannels();
  await assertInboxKind(owner, "resource_exchange_completed", {
    agreementId: agreement.agreement_id,
  });

  await assertRpcCode(
    unrelated.client.rpc("get_own_structured_request_message_item", {
      p_expected_profile_id: unrelated.id,
      p_item_kind: "resource_request",
      p_request_id: requestId,
    }),
    "42501",
    "deny an unrelated unified request read",
  );
  await assertRpcCode(
    unrelated.client.rpc("get_own_resource_request_chat", {
      p_expected_profile_id: unrelated.id,
      p_chat_id: chat.chat_id,
    }),
    "42501",
    "deny an unrelated Resource chat read",
  );

  await rpcVoid(
    requester,
    "set_own_notification_preference",
    {
      p_expected_profile_id: requester.id,
      p_category_slug: "resources",
      p_in_app_enabled: false,
      p_push_enabled: false,
    },
    "disable the requester Resources preference",
  );
  const suppressedListingId = await createPublishedListing(owner);
  const suppressedRequestId = await rpcValue(
    requester,
    "request_resource_listing",
    {
      p_expected_requester_profile_id: requester.id,
      p_listing_id: suppressedListingId,
      p_message: null,
    },
    "create a preference-suppressed Resource request",
  );
  await rpcValue(
    owner,
    "accept_resource_listing_request",
    {
      p_expected_owner_profile_id: owner.id,
      p_request_id: suppressedRequestId,
    },
    "accept a preference-suppressed Resource request",
  );
  const suppressedChat = await getChatByRequest(requester, suppressedRequestId);
  const suppressedMessage = await rpcRow(
    owner,
    "send_resource_request_chat_message",
    {
      p_expected_profile_id: owner.id,
      p_chat_id: suppressedChat.chat_id,
      p_body: "Suppressed Resource alert body",
    },
    "send a preference-suppressed Resource message",
  );
  const beforeSuppressedProjection = await countProjectedMessage(
    suppressedMessage.message_id,
  );
  await projectBothChannels();
  const afterSuppressedProjection = await countProjectedMessage(
    suppressedMessage.message_id,
  );
  if (
    beforeSuppressedProjection.notifications !== 0 ||
    beforeSuppressedProjection.jobs !== 0 ||
    afterSuppressedProjection.notifications !== 0 ||
    afterSuppressedProjection.jobs !== 0 ||
    afterSuppressedProjection.receipts !== 2
  ) {
    throw new Error(
      "Resources preference suppression did not receipt both channels safely.",
    );
  }

  await verifyReceiptedHistoricalSource({
    ownerId: owner.id,
    requesterId: requester.id,
    listingId,
    requestId,
  });
  await assertBodyFreeState([
    requestPrivateText,
    chatPrivateText,
    termsPrivateText,
    "Suppressed Resource alert body",
  ]);

  console.log(
    "Confirmed real-OTP unified Requests/Chats and Resource alerts: discriminated cross-domain reads, canonical chat activity, owner/requester routing, Resource preferences, body-free notifications/push jobs, no-backfill receipts, and unrelated-user denial.",
  );
}

async function createPublishedListing(owner) {
  const listingId = await rpcValue(
    owner,
    "create_resource_listing_draft",
    {
      p_expected_owner_profile_id: owner.id,
      p_listing_mode: "exchange",
      p_title: "Resource projection verifier item",
      p_description: "Deterministic local-only projection verifier listing.",
      p_country_code: "IT",
      p_locality: "Trento",
      p_administrative_area: null,
      p_public_location_label: "Trento",
    },
    "create a Resource projection listing",
  );
  await rpcValue(
    owner,
    "publish_resource_listing",
    {
      p_expected_owner_profile_id: owner.id,
      p_listing_id: listingId,
    },
    "publish a Resource projection listing",
  );
  return listingId;
}

async function getAgreement(actor, requestId) {
  return rpcRow(
    actor,
    "get_resource_exchange_agreement",
    { p_expected_profile_id: actor.id, p_request_id: requestId },
    "read the Resource agreement",
  );
}

async function getChatByRequest(actor, requestId) {
  const [anchor] = await sql`
    select id
    from public.resource_request_chats
    where request_id = ${requestId}::uuid
  `;
  if (!anchor) {
    throw new Error("The accepted Resource request has no chat anchor.");
  }
  return rpcRow(
    actor,
    "get_own_resource_request_chat",
    { p_expected_profile_id: actor.id, p_chat_id: anchor.id },
    "read the Resource chat",
  );
}

async function seedProjectConversation({
  ownerId,
  requesterId,
  projectId,
  requestId,
  membershipId,
}) {
  await sql.begin(async (transaction) => {
    await transaction`
      insert into public.proposals (
        id,
        creator_profile_id,
        lifecycle_state,
        title,
        starts_at,
        ends_at,
        event_timezone,
        published_at
      )
      values (
        ${projectId}::uuid,
        ${ownerId}::uuid,
        'published',
        'Unified verifier Project',
        statement_timestamp() + interval '30 days',
        statement_timestamp() + interval '30 days 2 hours',
        'Europe/Rome',
        statement_timestamp()
      )
    `;
    await transaction`
      insert into public.project_join_requests (
        id,
        project_id,
        requester_profile_id,
        status,
        created_at,
        resolved_at,
        resolved_by_profile_id
      )
      values (
        ${requestId}::uuid,
        ${projectId}::uuid,
        ${requesterId}::uuid,
        'accepted',
        statement_timestamp(),
        statement_timestamp(),
        ${ownerId}::uuid
      )
    `;
    await transaction`
      insert into public.project_memberships (
        id,
        project_id,
        participant_profile_id,
        originating_request_id,
        joined_at
      )
      values (
        ${membershipId}::uuid,
        ${projectId}::uuid,
        ${requesterId}::uuid,
        ${requestId}::uuid,
        statement_timestamp()
      )
    `;
  });
}

function listUnifiedChats(actor) {
  return rpcRows(
    actor,
    "list_own_message_chat_items",
    {
      p_expected_profile_id: actor.id,
      p_limit: 50,
      p_cursor_activity_at: null,
      p_cursor_item_kind: null,
      p_cursor_chat_id: null,
    },
    "list unified Chats",
  );
}

async function projectBothChannels() {
  await sql`select * from public.process_notification_outbox_batch(100)`;
  await sql`select * from public.process_push_outbox_batch(100)`;
}

async function assertInboxKind(actor, kind, expected) {
  const rows = await rpcRows(
    actor,
    "list_own_notifications",
    {
      p_expected_profile_id: actor.id,
      p_limit: 100,
      p_cursor_created_at: null,
      p_cursor_id: null,
    },
    "read the recipient notification inbox",
  );
  const row = rows.find((candidate) => candidate.notification_kind === kind);
  if (!row) {
    throw new Error(`The expected ${kind} alert is absent.`);
  }
  const comparisons = [
    ["resource_listing_id", expected.listingId],
    ["resource_request_id", expected.requestId],
    ["resource_chat_id", expected.chatId],
    ["resource_chat_message_id", expected.messageId],
    ["resource_agreement_id", expected.agreementId],
    ["destination_kind", expected.destination],
  ];
  for (const [field, value] of comparisons) {
    if (value !== undefined && row[field] !== value) {
      throw new Error(`The ${kind} alert has incorrect ${field} context.`);
    }
  }
  if (
    row.category_slug !== "resources" ||
    row.project_id !== null ||
    row.request_id !== null ||
    row.chat_id !== null ||
    row.message_id !== null
  ) {
    throw new Error(`The ${kind} alert violated the Project/Resource XOR.`);
  }
  return row;
}

async function countProjectedMessage(messageId) {
  const [row] = await sql`
    select
      (
        select count(*)::integer
        from public.notifications
        where resource_chat_message_id = ${messageId}::uuid
      ) as notifications,
      (
        select count(*)::integer
        from private.push_delivery_jobs
        where resource_chat_message_id = ${messageId}::uuid
      ) as jobs,
      (
        select count(*)::integer
        from private.outbox_consumer_receipts as receipt
        join private.outbox_events as event
          on event.id = receipt.outbox_event_id
        where event.payload ->> 'message_id' = ${messageId}
          and receipt.consumer_key in ('notifications.v1', 'push.v1')
      ) as receipts
  `;
  return row;
}

async function verifyReceiptedHistoricalSource({
  ownerId,
  requesterId,
  listingId,
  requestId,
}) {
  const eventId = randomUUID();
  await sql.begin(async (transaction) => {
    await transaction`
      insert into private.outbox_events (id, event_type, payload)
      values (
        ${eventId}::uuid,
        'resource_listing.request_created',
        jsonb_build_object(
          'request_id', ${requestId}::uuid,
          'listing_id', ${listingId}::uuid,
          'owner_profile_id', ${ownerId}::uuid,
          'requester_profile_id', ${requesterId}::uuid,
          'actor_profile_id', ${requesterId}::uuid
        )
      )
    `;
    await transaction`
      insert into private.outbox_consumer_receipts (
        outbox_event_id,
        consumer_key
      )
      values
        (${eventId}::uuid, 'notifications.v1'),
        (${eventId}::uuid, 'push.v1')
    `;
  });
  await projectBothChannels();
  const [row] = await sql`
    select
      (
        select count(*)
        from public.notifications
        where source_outbox_event_id = ${eventId}::uuid
      ) as notifications,
      (
        select count(*)
        from private.push_delivery_jobs
        where source_outbox_event_id = ${eventId}::uuid
      ) as jobs
  `;
  if (Number(row.notifications) !== 0 || Number(row.jobs) !== 0) {
    throw new Error(
      "A pre-receipted historical Resource source was backfilled.",
    );
  }
}

async function assertBodyFreeState(privateValues) {
  const [row] = await sql`
    select
      coalesce(jsonb_agg(to_jsonb(notification)), '[]'::jsonb)::text
        as notifications,
      coalesce(jsonb_agg(to_jsonb(job)), '[]'::jsonb)::text as jobs
    from public.notifications as notification
    full join private.push_delivery_jobs as job
      on false
    where notification.category_slug = 'resources'
      or job.category_slug = 'resources'
  `;
  for (const privateValue of privateValues) {
    if (
      row.notifications.includes(privateValue) ||
      row.jobs.includes(privateValue)
    ) {
      throw new Error(
        "Private Resource copy leaked into alert projection state.",
      );
    }
  }
}

async function ensureCompleteProfile(user, displayName) {
  const { error: insertError } = await user.client
    .from("profiles")
    .insert({ id: user.id });
  if (insertError) {
    const diagnostic = `${insertError.message ?? ""} ${insertError.details ?? ""}`;
    if (insertError.code !== "23505" || !diagnostic.includes("profiles_pkey")) {
      throw safeDatabaseFailure("create a verifier profile", insertError);
    }
  }
  await rpcVoid(
    user,
    "update_own_profile",
    {
      p_expected_profile_id: user.id,
      p_display_name: displayName,
      p_bio: null,
      p_skill_ids: [],
      p_display_name_audience: "private",
      p_bio_audience: "private",
      p_skills_audience: "private",
    },
    "complete a verifier profile",
  );
}

function signInWithLocalOtp(email) {
  return signInLocalOtpUser({
    apiUrl,
    publishableKey,
    mailpitUrl,
    email,
    verifierName: "Resource Messages notification verifier",
  });
}

async function rpcRows(actor, operation, args, action) {
  const { data, error } = await actor.client.rpc(operation, args);
  if (error || !Array.isArray(data)) {
    throw safeDatabaseFailure(action, error);
  }
  return data;
}

async function rpcRow(actor, operation, args, action) {
  const rows = await rpcRows(actor, operation, args, action);
  if (rows.length !== 1) {
    throw new Error(`Failed to ${action} with one canonical row.`);
  }
  return rows[0];
}

async function rpcValue(actor, operation, args, action) {
  const { data, error } = await actor.client.rpc(operation, args);
  if (error || typeof data !== "string") {
    throw safeDatabaseFailure(action, error);
  }
  return data;
}

async function rpcVoid(actor, operation, args, action) {
  const { error } = await actor.client.rpc(operation, args);
  if (error) {
    throw safeDatabaseFailure(action, error);
  }
}

async function assertRpcCode(pending, expectedCode, action) {
  const { data, error } = await pending;
  if (data !== null || error?.code !== expectedCode) {
    throw new Error(`Failed to ${action} with the expected database error.`);
  }
}

function safeDatabaseFailure(action, error) {
  const code =
    typeof error?.code === "string" && /^[a-z0-9_]+$/iu.test(error.code)
      ? error.code
      : "unknown";
  return new Error(`Failed to ${action} (code ${code}).`);
}
