import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { spawn, spawnSync } from "node:child_process";
import postgres from "postgres";
import { signInLocalOtpUser } from "./lib/local-authenticated-user.mjs";
import { ensureLocalProfilePhoto } from "./lib/local-profile-photo.mjs";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";

const status = readLocalSupabaseStatus(process.cwd());
assert.ok(["localhost", "127.0.0.1"].includes(new URL(status.apiUrl).hostname));
const sql = postgres(status.databaseUrl, { max: 8, onnotice: () => {} });
const mailpitUrl = process.env.MAILPIT_URL ?? "http://127.0.0.1:54324";
const runId = randomUUID().slice(0, 8);
const channels = [];
const pair = "project_request_chat",
  group = "project_chat",
  resource = "resource_chat";
try {
  if (process.argv.includes("--upgrade")) {
    assert.ok(
      process.env.CI === "true" || process.env.PLANETS_DISPOSABLE_QA === "1",
      "Upgrade requires an explicitly disposable local stack.",
    );
    cli(["db", "reset", "--local", "--version", "20261006101031"]);
    await upgrade();
  } else await verify();
} finally {
  await Promise.allSettled(
    channels.map(({ client, channel }) => client.removeChannel(channel)),
  );
  await sql.end();
}

async function verify() {
  console.log("MSG02: authenticated fixtures");
  const [owner, reader, newcomer, delegate] = await Promise.all(
    ["owner", "reader", "newcomer", "delegate"].map(user),
  );
  const p1 = await project(owner),
    p2 = await project(owner),
    tavolo = await project(owner, true);
  const r1 = await request(reader, p1),
    r2 = await request(reader, p2);
  const pairId = (
    await rpc(reader, "get_own_participation_conversation", {
      p_expected_profile_id: reader.id,
      p_request_id: r1,
    })
  )[0].chat_id;
  assert.deepEqual(
    await summary(reader),
    { total: 0, private: 0, groups: 0 },
    "Requests are not human unread",
  );
  console.log("MSG02: own account subscriptions");
  const hints = await subscribe(reader);
  // The repository's local auth.email.max_frequency is 1s. Establish a
  // genuinely independent OTP session without racing that configured limit.
  await new Promise((resolve) => setTimeout(resolve, 1100));
  const reader2 = await user("reader");
  assert.equal(reader2.id, reader.id);
  const secondSession = await subscribe(reader2);
  for (let i = 0; i < 3; i++)
    await send(owner, pair, pairId, `Synthetic pair ${i}`);
  const legacyId = (
    await rpc(owner, "get_own_project_join_request_chat", {
      p_expected_profile_id: owner.id,
      p_request_id: r1,
    })
  )[0].chat_id;
  await rpc(owner, "send_project_join_request_chat_message", {
    p_expected_profile_id: owner.id,
    p_chat_id: legacyId,
    p_body: "Synthetic legacy path",
  });
  await send(reader, pair, pairId, "Synthetic own message");
  assert.equal(await rowCount(reader, pair, pairId), 4);
  await waitUntil(() => hints.count >= 4, "unopened pair invalidates account");
  assert.deepEqual(await summary(reader), { total: 1, private: 1, groups: 0 });
  await denied(delegate, "get_own_message_feed_page", {
    p_expected_profile_id: delegate.id,
    p_kind: pair,
    p_chat_id: pairId,
    p_limit: 31,
  });
  await denied(reader, "get_own_message_unread_summary", {
    p_expected_profile_id: owner.id,
  });
  for (const table of [
    "message_streams",
    "message_sources",
    "message_incoming",
    "message_read_frontiers",
    "message_read_snapshots",
  ]) {
    const result = await reader.client
      .schema("private")
      .from(table)
      .select("*");
    assert.ok(result.error, `No direct read grant on ${table}`);
  }
  const membership = await accept(owner, r1);
  const groupId = (
    await sql`select id from public.project_group_chats where project_id=${p1}`
  )[0].id;
  await send(owner, group, groupId, "Synthetic group one");
  const listing = await rpc(owner, "create_resource_listing_draft", {
    p_expected_owner_profile_id: owner.id,
    p_listing_mode: "exchange",
    p_title: "Synthetic MSG02 listing",
    p_description: "Disposable unread fixture",
    p_country_code: "IT",
    p_locality: "Trento",
    p_administrative_area: null,
    p_public_location_label: "Trento",
  });
  await rpc(owner, "publish_resource_listing", {
    p_expected_owner_profile_id: owner.id,
    p_listing_id: listing,
  });
  const rr = await rpc(reader, "request_resource_listing", {
    p_expected_requester_profile_id: reader.id,
    p_listing_id: listing,
    p_message: "Synthetic Resource request",
  });
  await rpc(owner, "accept_resource_listing_request", {
    p_expected_owner_profile_id: owner.id,
    p_request_id: rr,
  });
  const resourceId = (
    await sql`select id from public.resource_request_chats where request_id=${rr}`
  )[0].id;
  await send(owner, resource, resourceId, "Synthetic Resource one");
  await send(owner, resource, resourceId, "Synthetic Resource two");
  assert.deepEqual(await summary(reader), { total: 3, private: 2, groups: 1 });
  assert.equal(await rowCount(reader, resource, resourceId), 2);
  const pairPage = await page(reader, pair, pairId);
  assert.equal(
    pairPage.items.filter((x) =>
      ["message", "legacy_message"].includes(x.item_kind),
    ).length,
    5,
  );
  await ack(reader, pair, pairId, pairPage.read_boundary);
  await waitUntil(
    () => secondSession.count >= 7,
    "same-user acknowledgement hint",
  );
  assert.deepEqual(await summary(reader), { total: 2, private: 1, groups: 1 });
  const groupPage = await page(reader, group, groupId);
  await send(owner, group, groupId, "Synthetic later arrival");
  await ack(reader, group, groupId, groupPage.read_boundary);
  await ack(reader, group, groupId, groupPage.read_boundary);
  assert.equal(
    await rowCount(reader, group, groupId),
    1,
    "Later arrival survives older/duplicate acknowledgement",
  );
  await denied(reader, "acknowledge_own_message_read", {
    p_expected_profile_id: reader.id,
    p_kind: group,
    p_chat_id: groupId,
    p_boundary: randomUUID(),
  });
  await denied(owner, "acknowledge_own_message_read", {
    p_expected_profile_id: owner.id,
    p_kind: group,
    p_chat_id: groupId,
    p_boundary: groupPage.read_boundary,
  });
  const preview = await page(reader, pair, pairId, { p_only_pending: true });
  assert.equal(preview.read_boundary, null);
  const cursor = groupPage.items.at(-1);
  assert.equal(
    (
      await page(reader, group, groupId, {
        p_before_created_at: cursor.created_at,
        p_before_item_kind: cursor.item_kind,
        p_before_item_id: cursor.item_id,
      })
    ).read_boundary,
    null,
  );

  // First admission and re-entry grant history, not unread backfill.
  await accept(owner, await request(newcomer, p1));
  assert.equal(await rowCount(newcomer, group, groupId), 0);
  await send(owner, group, groupId, "Synthetic entitled interval");
  const nm = (
    await sql`select id from public.project_memberships where project_id=${p1} and participant_profile_id=${newcomer.id} and left_at is null and removed_at is null`
  )[0].id;
  await rpc(newcomer, "leave_project", {
    p_expected_participant_profile_id: newcomer.id,
    p_membership_id: nm,
  });
  await send(owner, group, groupId, "Synthetic access gap");
  assert.equal(
    await rowCount(newcomer, group, groupId),
    1,
    "Former readable eligible unread remains",
  );
  await accept(owner, await request(newcomer, p1));
  assert.equal(
    await rowCount(newcomer, group, groupId),
    1,
    "Gap never becomes unread on re-entry",
  );
  await send(owner, group, groupId, "Synthetic re-entered interval");
  assert.equal(await rowCount(newcomer, group, groupId), 2);

  const invite = (
    await rpc(owner, "create_project_delegate_invitation", {
      p_expected_owner_profile_id: owner.id,
      p_project_id: p1,
    })
  )[0];
  const delegateId = await rpc(delegate, "accept_project_delegate_invitation", {
    p_expected_delegate_profile_id: delegate.id,
    p_token: invite.invite_token,
  });
  const warm = await subscribe(delegate);
  await send(owner, group, groupId, "Synthetic active delegate");
  await waitUntil(() => warm.count > 0, "active delegate own account signal");
  assert.equal(await rowCount(delegate, group, groupId), 1);
  await rpc(owner, "revoke_project_delegate", {
    p_expected_owner_profile_id: owner.id,
    p_delegate_id: delegateId,
  });
  await new Promise((resolve) => setTimeout(resolve, 400));
  const revokedCount = warm.count;
  assert.equal((await summary(delegate)).total, 0);
  await send(owner, group, groupId, "Synthetic after revoke");
  await send(owner, pair, pairId, "Synthetic endpoints only");
  await new Promise((resolve) => setTimeout(resolve, 400));
  assert.equal(
    warm.count,
    revokedCount,
    "Warm revoked delegate receives no subsequent private invalidation",
  );

  // Two canonical old-client writers choose different Project witnesses in the
  // SAME pair. The second starts before the read and waits behind the first
  // writer's uncommitted ordinal. Neither absent message may be acknowledged.
  const rt = await request(reader, tavolo);
  const legacyT = (
    await rpc(owner, "get_own_project_join_request_chat", {
      p_expected_profile_id: owner.id,
      p_request_id: rt,
    })
  )[0].chat_id;
  const legacy2 = (
    await rpc(owner, "get_own_project_join_request_chat", {
      p_expected_profile_id: owner.id,
      p_request_id: r2,
    })
  )[0].chat_id;
  let beforeDelayed, queuedSend;
  await sql.begin(async (tx) => {
    await identity(tx, owner.id);
    await tx`select public.send_project_join_request_chat_message(${owner.id}::uuid,${legacyT}::uuid,'Synthetic delayed Tavolo commit')`;
    const waiting = sendLegacy(
      owner,
      legacy2,
      "Synthetic delayed Proposal commit",
    );
    await waitForLock("send_project_join_request_chat_message");
    // Reads and acknowledgements must finish while the send transaction remains
    // open; a read-side stream upsert/FK would deadlock this proof.
    beforeDelayed = await page(reader, pair, pairId);
    await ack(reader, pair, pairId, beforeDelayed.read_boundary);
    // Commit the held writer before awaiting the queued writer outside this tx.
    queuedSend = waiting;
  });
  await queuedSend;
  assert.equal(
    await rowCount(reader, pair, pairId),
    2,
    "Absent delayed commit cannot hide behind read frontier",
  );
  await ack(reader, pair, pairId, beforeDelayed.read_boundary);
  assert.equal(await rowCount(reader, pair, pairId), 2);
  await rpc(owner, "reject_project_join_request", {
    p_expected_creator_profile_id: owner.id,
    p_request_id: rt,
  });

  const beforeMarkAll = await summary(reader);
  await sql`select * from public.process_notification_outbox_batch(100)`;
  await sql`select * from public.process_push_outbox_batch(100)`;
  const inbox = await rpc(reader, "list_own_notifications", {
    p_expected_profile_id: reader.id,
    p_limit: 100,
  });
  assert.ok(
    inbox.length > 0 &&
      inbox.every(
        (x) =>
          !["chat_message_received", "resource_chat_message_received"].includes(
            x.notification_kind,
          ),
      ),
  );
  await rpc(reader, "mark_all_notifications_read", {
    p_expected_profile_id: reader.id,
  });
  assert.deepEqual(
    await summary(reader),
    beforeMarkAll,
    "Mark-all activity does not read messages",
  );
  await rpc(reader, "set_own_notification_preference", {
    p_expected_profile_id: reader.id,
    p_category_slug: "resources",
    p_in_app_enabled: false,
    p_push_enabled: true,
  });
  await send(
    owner,
    resource,
    resourceId,
    "Synthetic independent disabled preference",
  );
  assert.equal(await rowCount(reader, resource, resourceId), 3);
  assert.equal(
    (
      await sql`select count(*)::int n from public.notifications where recipient_profile_id=${reader.id} and notification_kind in ('chat_message_received','resource_chat_message_received')`
    )[0].n,
    0,
  );
  assert.ok(
    (
      await sql`select count(*)::int n from private.push_delivery_jobs where recipient_profile_id=${reader.id} and notification_kind in ('chat_message_received','resource_chat_message_received')`
    )[0].n > 0,
  );
  await rpc(owner, "reject_project_join_request", {
    p_expected_creator_profile_id: owner.id,
    p_request_id: r2,
  });
  assert.equal(
    (
      await rpc(reader, "get_own_participation_conversation", {
        p_expected_profile_id: reader.id,
        p_request_id: r1,
      })
    )[0].is_read_only,
    true,
  );
  assert.equal(
    await rowCount(reader, pair, pairId),
    2,
    "Read-only is not read",
  );
  await ack(
    reader,
    pair,
    pairId,
    (await page(reader, pair, pairId)).read_boundary,
  );
  assert.equal(await rowCount(reader, pair, pairId), 0);
  await request(reader, p2);
  await send(owner, pair, pairId, "Synthetic same-pair reactivation");
  assert.equal(await rowCount(reader, pair, pairId), 1);

  // Complete totals, independent of first page, and bounded row counts.
  for (let i = 0; i < 23; i++) {
    const p = await project(owner);
    const r = await request(reader, p);
    await accept(owner, r);
    const c = (
      await sql`select id from public.project_group_chats where project_id=${p}`
    )[0].id;
    await send(owner, group, c, `Synthetic many-chat ${i}`);
  }
  assert.equal((await summary(reader)).groups, 24);
  const bounded = await rpc(reader, "list_own_scoped_conversation_items_v3", {
    p_expected_profile_id: reader.id,
    p_scope: "groups",
    p_limit: 1,
  });
  assert.equal(bounded.length, 1);
  assert.ok(bounded[0].unread_count > 0);
  // Representative metadata volume: 24 readable chats x 200 human rows, plus
  // same source UUID in legacy/pair and same chat UUID in two distinct kinds.
  const collision = randomUUID();
  await sql`insert into public.project_join_request_chat_messages(id,chat_id,sender_profile_id,body) values(${collision},${legacy2},${owner.id},'Synthetic legacy UUID collision')`;
  await sql`insert into public.participation_conversation_messages(id,conversation_id,sender_profile_id,body) values(${collision},${pairId},${owner.id},'Synthetic pair UUID collision')`;
  assert.equal(
    (
      await sql`select count(*)::int n from private.message_sources where source_id=${collision}`
    )[0].n,
    2,
  );
  const collisionOwner = await user("collision-owner");
  // Trusted fixture selects a pair UUID equal to an existing, valid group UUID;
  // ordinary request association and authenticated sends retain domain rules.
  await sql`insert into public.participation_conversations(id,lower_profile_id,upper_profile_id,activated_at)
    values(${groupId},least(${reader.id}::uuid,${collisionOwner.id}::uuid),greatest(${reader.id}::uuid,${collisionOwner.id}::uuid),clock_timestamp())`;
  await request(reader, await project(collisionOwner));
  await send(
    collisionOwner,
    pair,
    groupId,
    "Synthetic kind/chat UUID collision",
  );
  assert.equal(await rowCount(reader, pair, groupId), 1);
  assert.ok((await rowCount(reader, group, groupId)) > 0);
  assert.equal(await rowCount(reader, pair, pairId), 3);
  assert.deepEqual(await summary(reader), {
    total: 27,
    private: 3,
    groups: 24,
  });
  // Roll back the representative volume so later producer/projector gates do
  // not inherit thousands of unrelated events. Exercise the actual trigger.
  const tx = await sql.reserve();
  try {
    await tx`begin`;
    await tx`insert into public.project_chat_messages(chat_id,sender_profile_id,body,created_at)
      select c.id,${owner.id}::uuid,'Synthetic query-plan volume',clock_timestamp()
      from public.project_group_chats c join public.projects p on p.id=c.project_id
      cross join generate_series(1,200) where p.creator_profile_id=${owner.id}`;
    await tx`analyze private.message_incoming`;
    await tx`analyze private.message_sources`;
    // Explain the summary's SQL body, exposing the indexes below its SECURITY
    // DEFINER function boundary rather than an opaque Function Scan alone.
    const [{ prosrc }] =
      await tx`select prosrc from pg_proc where oid='private.own_message_unread(uuid)'::regprocedure`;
    const explain = await tx.unsafe(
      `explain (analyze,buffers,format json) ${prosrc.replace(/\bp_profile\b/g, "$1::uuid")}`,
      [reader.id],
    );
    const planText = JSON.stringify(explain);
    assert.ok(
      !/participation_conversation_messages|project_chat_messages|project_join_request_chat_messages|resource_request_chat_messages/.test(
        planText,
      ),
      "Summary plan never scans message bodies",
    );
    const metrics = explain[0]["QUERY PLAN"][0];
    console.log(
      `MSG02 metadata plan: ${metrics.Plan["Actual Rows"]} chats, ${metrics["Execution Time"]} ms, ${metrics.Plan["Shared Hit Blocks"]} shared hits; body-free joins.`,
    );
  } finally {
    await tx`rollback`;
    tx.release();
  }
  console.log(
    "MSG02 authenticated counts, eligibility, snapshot races, read-only/re-entry, revoked warm sockets, account hints, projection/push separation and pagination passed.",
  );
}

function sendLegacy(account, chat, body) {
  return rpc(account, "send_project_join_request_chat_message", {
    p_expected_profile_id: account.id,
    p_chat_id: chat,
    p_body: body,
  });
}
async function identity(tx, id) {
  await tx`set local role authenticated`;
  await tx`select set_config('request.jwt.claim.sub',${id},true)`;
  await tx`set local statement_timeout='15s'`;
}
async function waitForLock(name) {
  await waitUntil(
    async () =>
      (
        await sql`select 1 from pg_stat_activity where wait_event_type='Lock' and query like ${"%" + name + "%"}`
      ).length > 0,
    `canonical ${name} blocked`,
  );
}

async function upgrade() {
  const owner = await user("upgrade-owner"),
    reader = await user("upgrade-reader");
  const p = await project(owner),
    r = await request(reader, p);
  const chat = (
    await rpc(reader, "get_own_participation_conversation", {
      p_expected_profile_id: reader.id,
      p_request_id: r,
    })
  )[0].chat_id;
  await send(owner, pair, chat, "Synthetic committed predecessor history");
  const legacyChat = (
    await rpc(owner, "get_own_project_join_request_chat", {
      p_expected_profile_id: owner.id,
      p_request_id: r,
    })
  )[0].chat_id;
  await sendLegacy(owner, legacyChat, "Synthetic predecessor legacy history");
  await accept(owner, r);
  const g = (
    await sql`select id from public.project_group_chats where project_id=${p}`
  )[0].id;
  await send(owner, group, g, "Synthetic old ordinary message alert");
  const resourceId = await resourceFixture(owner, reader);
  await send(
    owner,
    resource,
    resourceId,
    "Synthetic old Resource message alert",
  );
  const concurrentOwner = await user("upgrade-concurrent-owner");
  const concurrentProject = await project(concurrentOwner);
  const concurrentRequest = await request(reader, concurrentProject);
  const concurrentChat = (
    await rpc(reader, "get_own_participation_conversation", {
      p_expected_profile_id: reader.id,
      p_request_id: concurrentRequest,
    })
  )[0].chat_id;
  // Another pending witness permits a pre-cutover pair send despite accepting r.
  await request(reader, await project(owner));
  await sql`select * from public.process_notification_outbox_batch(100)`;
  const readAlert = (
    await sql`select id from public.notifications where recipient_profile_id=${reader.id} and notification_kind='chat_message_received'`
  )[0].id;
  await rpc(reader, "mark_notification_read", {
    p_expected_profile_id: reader.id,
    p_notification_id: readAlert,
  });
  const oldRows =
    await sql`select to_jsonb(n) data from public.notifications n order by id`;
  const oldMessages =
    await sql`select to_jsonb(m) data from public.participation_conversation_messages m order by id`;
  const oldGroup =
    await sql`select to_jsonb(m) data from public.project_chat_messages m order by id`;
  const oldLegacy =
    await sql`select to_jsonb(m) data from public.project_join_request_chat_messages m order by id`;
  const oldResource =
    await sql`select to_jsonb(m) data from public.resource_request_chat_messages m order by id`;
  let migration, postCutover, heldMessage;
  await sql.begin(async (tx) => {
    await identity(tx, owner.id);
    [heldMessage] =
      await tx`select * from public.send_participation_conversation_message(${owner.id}::uuid,${chat}::uuid,'Synthetic committed while migration waits')`;
    migration = cliAsync(["migration", "up", "--local"]);
    await waitForLock("participation_conversation_messages");
    // This second pair has independent domain locks. Its INSERT queues behind
    // the cutover's source-table lock and must use the installed receipt trigger.
    postCutover = send(
      concurrentOwner,
      pair,
      concurrentChat,
      "Synthetic queued across cutover",
    );
    await waitForLock("send_participation_conversation_message");
  });
  await migration;
  await postCutover;
  assert.deepEqual(
    await sql`select to_jsonb(n) data from public.notifications n order by id`,
    oldRows,
  );
  const currentMessages =
    await sql`select to_jsonb(m) data from public.participation_conversation_messages m order by id`;
  assert.ok(
    oldMessages.every((old) =>
      currentMessages.some(
        (current) => JSON.stringify(current) === JSON.stringify(old),
      ),
    ),
  );
  assert.ok(
    currentMessages.some(
      (x) =>
        x.data.id === heldMessage.message_id &&
        x.data.body === heldMessage.body &&
        x.data.sender_profile_id === heldMessage.sender_profile_id,
    ),
  );
  assert.deepEqual(
    await sql`select to_jsonb(m) data from public.project_chat_messages m order by id`,
    oldGroup,
  );
  assert.deepEqual(
    await sql`select to_jsonb(m) data from public.project_join_request_chat_messages m order by id`,
    oldLegacy,
  );
  assert.deepEqual(
    await sql`select to_jsonb(m) data from public.resource_request_chat_messages m order by id`,
    oldResource,
  );
  assert.equal(
    await rowCount(reader, pair, chat),
    0,
    "Writer committed before cutover is baseline",
  );
  assert.equal(
    await rowCount(reader, pair, concurrentChat),
    1,
    "Writer queued through cutover remains unread before any updated app read",
  );
  await ack(
    reader,
    pair,
    concurrentChat,
    (await page(reader, pair, concurrentChat)).read_boundary,
  );
  assert.deepEqual(
    await summary(reader),
    { total: 0, private: 0, groups: 0 },
    "One-time baseline has no invented read history",
  );
  const oldAlert = oldRows.find(
    (x) =>
      x.data.recipient_profile_id === reader.id &&
      x.data.notification_kind === "resource_chat_message_received" &&
      x.data.read_at === null,
  );
  assert.ok(oldAlert);
  assert.ok(
    !(
      await rpc(reader, "list_own_notifications", {
        p_expected_profile_id: reader.id,
        p_limit: 100,
      })
    ).some((x) =>
      ["chat_message_received", "resource_chat_message_received"].includes(
        x.notification_kind,
      ),
    ),
  );
  assert.equal(
    (
      await rpc(reader, "list_own_notifications", {
        p_expected_profile_id: reader.id,
        p_limit: 1,
      })
    ).length,
    1,
    "Activity predicate runs before pagination",
  );
  await rpc(reader, "mark_all_notifications_read", {
    p_expected_profile_id: reader.id,
  });
  assert.equal(
    (
      await sql`select read_at from public.notifications where id=${oldAlert.data.id}`
    )[0].read_at,
    null,
  );
  await send(owner, pair, chat, "Synthetic post-cutover unread");
  assert.equal((await summary(reader)).total, 1);
  await rpc(reader, "list_own_scoped_conversation_items_v3", {
    p_expected_profile_id: reader.id,
    p_scope: "private",
    p_limit: 1,
  });
  assert.equal(
    (await summary(reader)).total,
    1,
    "First updated list cannot establish a new baseline",
  );
  await rpc(reader, "mark_notification_read", {
    p_expected_profile_id: reader.id,
    p_notification_id: oldAlert.data.id,
  });
  await rpc(reader, "mark_notification_read", {
    p_expected_profile_id: reader.id,
    p_notification_id: oldAlert.data.id,
  });
  assert.equal(
    (await summary(reader)).total,
    1,
    "Exact retained notification read never reads chat",
  );
  console.log(
    "MSG02 populated upgrade preserves source/notification bytes, historical APIs, one-time baseline and post-cutover unread.",
  );
}

async function resourceFixture(owner, reader) {
  const listing = await rpc(owner, "create_resource_listing_draft", {
    p_expected_owner_profile_id: owner.id,
    p_listing_mode: "exchange",
    p_title: "Synthetic upgrade listing",
    p_description: "Disposable migration fixture",
    p_country_code: "IT",
    p_locality: "Trento",
    p_administrative_area: null,
    p_public_location_label: "Trento",
  });
  await rpc(owner, "publish_resource_listing", {
    p_expected_owner_profile_id: owner.id,
    p_listing_id: listing,
  });
  const request = await rpc(reader, "request_resource_listing", {
    p_expected_requester_profile_id: reader.id,
    p_listing_id: listing,
    p_message: "Synthetic upgrade Resource request",
  });
  await rpc(owner, "accept_resource_listing_request", {
    p_expected_owner_profile_id: owner.id,
    p_request_id: request,
  });
  return (
    await sql`select id from public.resource_request_chats where request_id=${request}`
  )[0].id;
}
function cliAsync(args) {
  return new Promise((resolve, reject) => {
    const child = spawn("supabase", args, {
      shell: process.platform === "win32",
      stdio: ["ignore", "ignore", "pipe"],
    });
    let diagnostic = "";
    child.stderr.on("data", (data) => {
      diagnostic += data.toString();
    });
    child.on("error", reject);
    child.on("exit", (code) =>
      code === 0
        ? resolve()
        : reject(new Error(`MSG02 migration CLI failed: ${diagnostic}`)),
    );
  });
}

function summary(account) {
  return rpc(account, "get_own_message_unread_summary", {
    p_expected_profile_id: account.id,
  });
}
function page(account, kind, chat, extra = {}) {
  return rpc(account, "get_own_message_feed_page", {
    p_expected_profile_id: account.id,
    p_kind: kind,
    p_chat_id: chat,
    p_limit: 31,
    ...extra,
  });
}
function ack(account, kind, chat, boundary) {
  return rpc(account, "acknowledge_own_message_read", {
    p_expected_profile_id: account.id,
    p_kind: kind,
    p_chat_id: chat,
    p_boundary: boundary,
  });
}
async function rowCount(account, kind, chat) {
  return Number(
    (
      await sql`select coalesce((select unread_count from private.own_message_unread(${account.id}) where conversation_kind=${kind} and chat_id=${chat}),0) n`
    )[0].n,
  );
}
function send(account, kind, chat, body) {
  return rpc(
    account,
    kind === pair
      ? "send_participation_conversation_message"
      : kind === group
        ? "send_project_chat_message"
        : "send_resource_request_chat_message",
    { p_expected_profile_id: account.id, p_chat_id: chat, p_body: body },
  );
}
function request(account, project) {
  return rpc(account, "request_to_join_project", {
    p_expected_requester_profile_id: account.id,
    p_project_id: project,
    p_request_message: "Synthetic MSG02 request",
    p_skill_ids: [],
    p_resource_need_ids: [],
  });
}
function accept(account, request) {
  return rpc(account, "accept_project_join_request", {
    p_expected_creator_profile_id: account.id,
    p_request_id: request,
  });
}
async function project(owner, recurring = false) {
  const id = randomUUID();
  if (recurring)
    await sql`insert into public.recurring_activities(id,creator_profile_id,lifecycle_state,title,published_at) values(${id},${owner.id},'published','Synthetic MSG02 Tavolo',now())`;
  else
    await sql`insert into public.proposals(id,creator_profile_id,lifecycle_state,title,starts_at,ends_at,published_at) values(${id},${owner.id},'published','Synthetic MSG02 Proposal',now()+interval '1 day',now()+interval '2 days',now())`;
  return id;
}
async function user(name) {
  const account = await signInLocalOtpUser({
    ...status,
    mailpitUrl,
    email: `msg02-${runId}-${name}@planets.invalid`,
    verifierName: "MSG02",
  });
  const inserted = await account.client
    .from("profiles")
    .insert({ id: account.id });
  if (inserted.error && inserted.error.code !== "23505")
    throw new Error(`MSG02 profile setup (${inserted.error.code})`);
  await rpc(account, "update_own_profile", {
    p_expected_profile_id: account.id,
    p_display_name: `MSG02 ${name}`,
    p_bio: null,
    p_skill_ids: [],
    p_display_name_audience: "private",
    p_bio_audience: "private",
    p_skills_audience: "private",
  });
  await ensureLocalProfilePhoto(account);
  return account;
}
async function rpc(account, name, params) {
  const result = await account.client.rpc(name, params);
  if (result.error)
    throw new Error(
      `${name} failed (${result.error.code}): ${result.error.message}`,
    );
  return result.data;
}
async function denied(account, name, params) {
  const result = await account.client.rpc(name, params);
  assert.equal(result.error?.code, "42501", name);
  assert.equal(result.data, null);
}
function cli(args) {
  const result = spawnSync("supabase", args, {
    shell: process.platform === "win32",
    encoding: "utf8",
    maxBuffer: 16 * 1024 * 1024,
  });
  if (result.status !== 0)
    throw new Error(`MSG02 CLI ${args[0]} failed: ${result.stderr}`);
}
async function waitUntil(predicate, label) {
  const until = Date.now() + 10000;
  while (Date.now() < until) {
    if (await predicate()) return;
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error(`MSG02 timeout: ${label}`);
}
async function subscribe(account) {
  const result = { count: 0 };
  const channel = account.client
    .channel(`message-unread:profile:${account.id}`, {
      config: { private: true },
    })
    .on("broadcast", { event: "messages.unread_changed" }, (value) => {
      const payload = value.payload;
      assert.equal(payload.profile_id, account.id);
      assert.ok(
        Object.keys(payload).every((k) => ["profile_id", "id"].includes(k)),
      );
      result.count++;
    });
  channels.push({ client: account.client, channel });
  await new Promise((resolve, reject) => {
    const timer = setTimeout(
      () => reject(new Error("MSG02 private subscription timed out")),
      15000,
    );
    channel.subscribe((state) => {
      if (state === "SUBSCRIBED") {
        clearTimeout(timer);
        resolve();
      } else if (["CHANNEL_ERROR", "TIMED_OUT"].includes(state)) {
        clearTimeout(timer);
        reject(new Error("MSG02 private subscription failed"));
      }
    });
  });
  return result;
}
