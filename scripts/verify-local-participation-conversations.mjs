import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { spawnSync } from "node:child_process";
import postgres from "postgres";
import { signInLocalOtpUser } from "./lib/local-authenticated-user.mjs";
import { ensureLocalProfilePhoto } from "./lib/local-profile-photo.mjs";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";

const status = readLocalSupabaseStatus(process.cwd());
assert.ok(
  ["127.0.0.1", "localhost"].includes(new URL(status.apiUrl).hostname),
  "Verifier requires a local QA stack.",
);
const sql = postgres(status.databaseUrl, { max: 6 });
const channels = [];
const mailpitUrl = process.env.MAILPIT_URL ?? "http://127.0.0.1:54324";
const runId = randomUUID().slice(0, 8);
try {
  if (process.argv.includes("--upgrade")) {
    assert.ok(
      process.env.CI === "true" || process.env.PLANETS_DISPOSABLE_QA === "1",
      "Populated upgrade resets its selected local stack; explicitly designate a disposable QA stack.",
    );
    cli(["db", "reset", "--local", "--version", "20261005111132"]);
    await verifyUpgrade();
  } else await verify();
} finally {
  await Promise.allSettled(
    channels.map(({ client, channel }) => client.removeChannel(channel)),
  );
  await sql.end();
}

async function verify() {
  const [creator, requester, delegate, stranger] = await Promise.all(
    ["creator", "requester", "delegate", "stranger"].map(user),
  );
  const projects = await Promise.all([
    fixture(creator),
    fixture(creator),
    fixture(creator, "recurring"),
    fixture(requester),
  ]);
  const [first, second, tavolo, reverse] = await Promise.all([
    request(requester, projects[0]),
    request(requester, projects[1]),
    request(requester, projects[2]),
    request(creator, projects[3]),
  ]);
  const summary = await get(requester, first);
  const pairId = summary.chat_id;
  for (const requestId of [second, tavolo, reverse])
    assert.equal((await get(creator, requestId)).chat_id, pairId);
  assert.equal(summary.pending_count, 4);
  const list = await rpc(requester, "list_own_scoped_conversation_items", {
    p_expected_profile_id: requester.id,
    p_scope: "private",
    p_limit: 1,
  });
  assert.equal(list.length, 1);
  assert.equal(list[0].chat_id, pairId);
  assert.equal(list[0].pending_count, 4);
  assert.equal(
    (await feed(creator, pairId)).filter((x) => x.item_kind === "request")
      .length,
    4,
  );

  const invite = (
    await rpc(creator, "create_project_delegate_invitation", {
      p_expected_owner_profile_id: creator.id,
      p_project_id: projects[0],
    })
  )[0];
  const delegateId = await rpc(delegate, "accept_project_delegate_invitation", {
    p_expected_delegate_profile_id: delegate.id,
    p_token: invite.invite_token,
  });
  assert.ok(
    (
      await rpc(delegate, "list_project_join_requests_for_manager", {
        p_expected_manager_profile_id: delegate.id,
        p_project_id: projects[0],
      })
    ).some((x) => x.request_id === first),
  );
  const legacyChat = (
    await rpc(requester, "get_own_project_join_request_chat", {
      p_expected_profile_id: requester.id,
      p_request_id: first,
    })
  )[0].chat_id;
  for (const account of [delegate, stranger]) {
    await denied(account, "get_own_participation_conversation", {
      p_expected_profile_id: account.id,
      p_request_id: first,
    });
    await denied(account, "list_own_participation_conversation_items", {
      p_expected_profile_id: account.id,
      p_chat_id: pairId,
      p_limit: 10,
    });
    await denied(account, "send_participation_conversation_message", {
      p_expected_profile_id: account.id,
      p_chat_id: pairId,
      p_body: "Forbidden",
    });
    await denied(account, "get_own_project_join_request_chat", {
      p_expected_profile_id: account.id,
      p_request_id: first,
    });
    await denied(account, "list_own_project_join_request_chat_items", {
      p_expected_profile_id: account.id,
      p_chat_id: legacyChat,
      p_limit: 10,
    });
    await denied(account, "send_project_join_request_chat_message", {
      p_expected_profile_id: account.id,
      p_chat_id: legacyChat,
      p_body: "Forbidden",
    });
    await subscribe(account, pairId, false);
  }
  await denied(requester, "get_own_participation_conversation", {
    p_expected_profile_id: stranger.id,
    p_request_id: first,
  });
  const incoming = await subscribe(creator, pairId);
  const outgoing = await subscribe(requester, pairId);
  const message = (await send(requester, pairId, "  Pair follow-up  "))[0];
  assert.equal(message.body, "Pair follow-up");
  await waitUntil(() => incoming.length > 0, "second client message hint");
  assert.ok(
    (await feed(creator, pairId)).some(
      (x) => x.message_id === message.message_id && x.request_id === null,
    ),
  );
  for (const signal of incoming) {
    assert.ok(
      Object.keys(signal).every((field) => ["chat_id", "id"].includes(field)),
    );
    assert.equal(signal.chat_id, pairId);
    if (signal.id !== undefined) assert.match(signal.id, /^[0-9a-f-]{36}$/i);
  }

  // Deliberately tied timestamp AND UUID across legacy/new source tables.
  // These synthetic fixtures prove source-kind identity, without claiming they
  // are a populated upgrade (that has its own verifier).
  await sql`insert into public.project_join_request_chat_messages(id,chat_id,sender_profile_id,body,created_at)
    values(${message.message_id},${legacyChat},${delegate.id},'Synthetic tied legacy reply',${message.created_at})`;
  const complete = await feed(creator, pairId);
  let paged = [];
  let boundary;
  do {
    const page = await feed(creator, pairId, 1, boundary);
    if (!page.length) break;
    paged.push(page[0]);
    boundary = page[0];
  } while (paged.length <= complete.length);
  assert.deepEqual(paged.map(key), complete.map(key));
  assert.equal(new Set(paged.map(key)).size, complete.length);
  assert.ok(
    paged.some(
      (x) =>
        x.item_kind === "legacy_message" &&
        x.sender_profile_id === delegate.id &&
        x.request_id === first,
    ),
  );

  await rpc(delegate, "reject_project_join_request_as_manager", {
    p_expected_manager_profile_id: delegate.id,
    p_request_id: first,
  });
  assert.equal((await get(creator, first)).pending_count, 3);
  assert.equal((await get(creator, first)).has_send_entitlement, true);
  await waitUntil(() => outgoing.length > 0, "second client resolution hint");
  await send(creator, pairId, "Another pending request remains");
  await rpc(creator, "revoke_project_delegate", {
    p_expected_owner_profile_id: creator.id,
    p_delegate_id: delegateId,
  });
  await denied(delegate, "get_own_participation_conversation", {
    p_expected_profile_id: delegate.id,
    p_request_id: first,
  });
  await rpc(creator, "reject_project_join_request_as_manager", {
    p_expected_manager_profile_id: creator.id,
    p_request_id: tavolo,
  });
  await rpc(creator, "withdraw_project_join_request", {
    p_expected_requester_profile_id: creator.id,
    p_request_id: reverse,
  });

  // A send waiting behind final resolution must re-read committed state.
  let waitingSend;
  await sql.begin(async (tx) => {
    await identity(tx, creator.id);
    await tx`select public.reject_project_join_request_as_manager(${creator.id}::uuid,${second}::uuid)`;
    waitingSend = requester.client
      .rpc("send_participation_conversation_message", {
        p_expected_profile_id: requester.id,
        p_chat_id: pairId,
        p_body: "Final resolution wins",
      })
      .then((x) => x);
    await waitForDatabaseLock("send_participation_conversation_message");
  });
  assert.equal((await waitingSend).error?.code, "PT409");
  assert.equal((await get(requester, first)).has_send_entitlement, false);
  const retained = (await feed(requester, pairId)).map(key);
  const signalCount = incoming.length;
  const reopened = await request(requester, projects[1]);
  assert.equal((await get(creator, reopened)).chat_id, pairId);
  assert.equal((await get(creator, reopened)).pending_count, 1);
  const reopenedKeys = new Set((await feed(requester, pairId)).map(key));
  assert.ok(retained.every((item) => reopenedKeys.has(item)));
  await waitUntil(
    () => incoming.length > signalCount,
    "read-only reactivation hint",
  );

  // A send authorized first remains durable after final resolution commits.
  let waitingResolution;
  let durable;
  await sql.begin(async (tx) => {
    await identity(tx, requester.id);
    [durable] =
      await tx`select * from public.send_participation_conversation_message(${requester.id}::uuid,${pairId}::uuid,'Serialized before resolution')`;
    waitingResolution = creator.client
      .rpc("reject_project_join_request_as_manager", {
        p_expected_manager_profile_id: creator.id,
        p_request_id: reopened,
      })
      .then((x) => x);
    await waitForDatabaseLock("reject_project_join_request_as_manager");
  });
  assert.equal((await waitingResolution).error, null);
  assert.ok(
    (await feed(creator, pairId)).some(
      (x) => x.message_id === durable.message_id,
    ),
  );

  // Unrelated invitations/membership cannot create a pair or authorize sending.
  const invitationProject = await fixture(creator);
  const direct = (
    await rpc(creator, "create_project_participant_invitation", {
      p_expected_profile_id: creator.id,
      p_project_id: invitationProject,
    })
  )[0];
  await rpc(stranger, "accept_project_participant_invitation", {
    p_expected_profile_id: stranger.id,
    p_token: direct.invite_token,
    p_client_action_id: randomUUID(),
  });
  assert.equal(
    (
      await rpc(stranger, "list_own_scoped_conversation_items", {
        p_expected_profile_id: stranger.id,
        p_scope: "private",
        p_limit: 50,
      })
    ).filter((x) => x.item_kind === "project_request_chat").length,
    0,
  );
  assert.equal(
    (
      await requester.client.rpc("send_participation_conversation_message", {
        p_expected_profile_id: requester.id,
        p_chat_id: pairId,
        p_body: "No pending request",
      })
    ).error?.code,
    "PT409",
  );

  // Direct admission supersedes the final ordinary request under the same
  // canonical interaction/Project locks; it cannot leave stale send authority.
  const supersededProject = await fixture(creator);
  const supersededRequest = await request(requester, supersededProject);
  const supersedingInvite = (
    await rpc(creator, "create_project_participant_invitation", {
      p_expected_profile_id: creator.id,
      p_project_id: supersededProject,
    })
  )[0];
  let invitationRaceSend;
  await sql.begin(async (tx) => {
    await identity(tx, requester.id);
    await tx`select * from public.accept_project_participant_invitation(${requester.id}::uuid,${supersedingInvite.invite_token},${randomUUID()}::uuid)`;
    invitationRaceSend = creator.client
      .rpc("send_participation_conversation_message", {
        p_expected_profile_id: creator.id,
        p_chat_id: pairId,
        p_body: "Invitation committed first",
      })
      .then((x) => x);
    await waitForDatabaseLock("send_participation_conversation_message");
  });
  assert.equal((await invitationRaceSend).error?.code, "PT409");
  assert.equal(
    (await get(creator, supersededRequest)).request_status,
    "withdrawn",
  );

  // Requester-versus-any-current-manager blocking remains request-scoped.
  const blockInvite = (
    await rpc(creator, "create_project_delegate_invitation", {
      p_expected_owner_profile_id: creator.id,
      p_project_id: projects[0],
    })
  )[0];
  await rpc(delegate, "accept_project_delegate_invitation", {
    p_expected_delegate_profile_id: delegate.id,
    p_token: blockInvite.invite_token,
  });
  const blockedRequest = await request(requester, projects[0]);
  const unaffectedRequest = await request(requester, projects[1]);
  await rpc(requester, "block_user", {
    p_expected_blocker_profile_id: requester.id,
    p_blocked_profile_id: delegate.id,
  });
  assert.equal(
    (await get(creator, blockedRequest)).request_status,
    "withdrawn",
  );
  assert.equal(
    (await get(creator, unaffectedRequest)).has_send_entitlement,
    true,
  );
  await send(requester, pairId, "A separate eligible request remains");
  const deniedAcceptance = await creator.client.rpc(
    "accept_project_join_request_as_manager",
    { p_expected_manager_profile_id: creator.id, p_request_id: blockedRequest },
  );
  assert.ok(
    deniedAcceptance.error,
    "Another pending request must not authorize accepting the blocked request.",
  );
  await rpc(requester, "unblock_user", {
    p_expected_blocker_profile_id: requester.id,
    p_blocked_profile_id: delegate.id,
  });
  const audit =
    await sql`select metadata from private.audit_events where action='participation.conversation_message_sent' and target_id=${pairId}`;
  for (const event of audit)
    assert.deepEqual(Object.keys(event.metadata).sort(), [
      "chat_id",
      "message_id",
      "sender_profile_id",
    ]);
  const broadcasts =
    await sql`select topic,payload from realtime.messages where event='participation.conversation_changed' and payload->>'chat_id'=${pairId}`;
  assert.ok(
    broadcasts.every((x) =>
      [creator.id, requester.id].some((id) =>
        x.topic.endsWith(`:profile:${id}`),
      ),
    ),
  );
  await verifyLargeHistoryAndBlock(requester);
  console.log(
    "Confirmed server pair grouping, concurrent/opposite creation, independent requests, mixed-kind paging, endpoint/legacy privacy, two-client identifier-only Realtime, resolved reactivation, both send/resolution orders, invitation isolation, and request-scoped manager blocking.",
  );
}

async function verifyLargeHistoryAndBlock(requester) {
  const owner = await user("pagination-owner");
  const projects = await Promise.all(
    Array.from({ length: 35 }, () => fixture(owner)),
  );
  const ids = await Promise.all(
    projects.map((project) => request(requester, project)),
  );
  const summary = await get(owner, ids[0]);
  assert.equal(summary.pending_count, 35);
  assert.equal(summary.pending_items.length, 30);
  const pairId = summary.chat_id;
  // Synthetic durable history tests page boundaries without claiming it was
  // authored through a client. Actual sends and Realtime are exercised above.
  await sql`insert into public.participation_conversation_messages(conversation_id,sender_profile_id,body,created_at)
    select ${pairId},${requester.id},'Synthetic paginated history',now()+interval '1 second' from generate_series(1,62)`;
  assert.ok(
    !(await feed(owner, pairId, 30)).some((row) => row.request_id === ids[0]),
  );
  assert.equal((await get(owner, ids[0])).request_id, ids[0]);
  const lookup = await rpc(
    owner,
    "get_own_participation_conversation_requests",
    {
      p_expected_profile_id: owner.id,
      p_chat_id: pairId,
      p_request_ids: [ids[0]],
    },
  );
  assert.equal(lookup[0].request_id, ids[0]);
  let all = [];
  let cursor;
  while (true) {
    const page = await feed(owner, pairId, 13, cursor);
    if (!page.length) break;
    all.push(...page);
    cursor = page.at(-1);
  }
  assert.equal(all.length, 97);
  assert.equal(new Set(all.map(key)).size, 97);
  let queued;
  await sql.begin(async (tx) => {
    await identity(tx, requester.id);
    await tx`select public.block_user(${requester.id}::uuid,${owner.id}::uuid)`;
    queued = owner.client
      .rpc("send_participation_conversation_message", {
        p_expected_profile_id: owner.id,
        p_chat_id: pairId,
        p_body: "Block committed first",
      })
      .then((x) => x);
    await waitForDatabaseLock("send_participation_conversation_message");
  });
  assert.equal((await queued).error?.code, "PT409");
  assert.equal((await get(owner, ids[0])).pending_count, 0);
  assert.equal((await get(owner, ids[0])).has_send_entitlement, false);
  await rpc(requester, "unblock_user", {
    p_expected_blocker_profile_id: requester.id,
    p_blocked_profile_id: owner.id,
  });
  assert.equal((await get(owner, ids[0])).has_send_entitlement, false);
  console.log(
    "Confirmed 35-request canonical pending total/30-item banner, 97-item tied-time keyset history, old context lookup, and send waiting behind a committed block.",
  );
}

// Exercise the actual predecessor schema with canonical operations before applying
// MSG01. This is deliberately separate from synthetic fixtures on the new schema.
async function verifyUpgrade() {
  assert.equal(
    (
      await sql`select to_regclass('public.participation_conversations') as table_name`
    )[0].table_name,
    null,
  );
  const [creator, requester, delegate] = await Promise.all(
    ["upgrade-creator", "upgrade-requester", "upgrade-delegate"].map(user),
  );
  const projects = await Promise.all([
    fixture(creator),
    fixture(creator),
    fixture(creator),
    fixture(creator, "recurring"),
    fixture(creator),
  ]);
  const pending = await request(requester, projects[0]);
  const invite = (
    await rpc(creator, "create_project_delegate_invitation", {
      p_expected_owner_profile_id: creator.id,
      p_project_id: projects[0],
    })
  )[0];
  await rpc(delegate, "accept_project_delegate_invitation", {
    p_expected_delegate_profile_id: delegate.id,
    p_token: invite.invite_token,
  });
  const oldGet = async (id) =>
    (
      await rpc(requester, "get_own_project_join_request_chat", {
        p_expected_profile_id: requester.id,
        p_request_id: id,
      })
    )[0];
  const oldSend = (account, chatId, body) =>
    rpc(account, "send_project_join_request_chat_message", {
      p_expected_profile_id: account.id,
      p_chat_id: chatId,
      p_body: body,
    });
  const oldChat = (await oldGet(pending)).chat_id;
  await oldSend(requester, oldChat, "Synthetic original requester follow-up");
  await oldSend(delegate, oldChat, "Synthetic historical delegate reply");
  const accepted = await request(requester, projects[1]);
  await oldSend(
    creator,
    (await oldGet(accepted)).chat_id,
    "Synthetic Creator acceptance discussion",
  );
  await rpc(creator, "accept_project_join_request_as_manager", {
    p_expected_manager_profile_id: creator.id,
    p_request_id: accepted,
  });
  const rejected = await request(requester, projects[2]);
  await oldSend(
    requester,
    (await oldGet(rejected)).chat_id,
    "Synthetic rejected-episode discussion",
  );
  await rpc(creator, "reject_project_join_request_as_manager", {
    p_expected_manager_profile_id: creator.id,
    p_request_id: rejected,
  });
  const repeated = await request(requester, projects[2]);
  const withdrawn = await request(requester, projects[3]);
  await oldSend(
    creator,
    (await oldGet(withdrawn)).chat_id,
    "Synthetic Tavolo discussion",
  );
  await rpc(requester, "withdraw_project_join_request", {
    p_expected_requester_profile_id: requester.id,
    p_request_id: withdrawn,
  });
  const superseded = await request(requester, projects[4]);
  await oldSend(
    requester,
    (await oldGet(superseded)).chat_id,
    "Synthetic superseded-request discussion",
  );
  const direct = (
    await rpc(creator, "create_project_participant_invitation", {
      p_expected_profile_id: creator.id,
      p_project_id: projects[4],
    })
  )[0];
  await rpc(requester, "accept_project_participant_invitation", {
    p_expected_profile_id: requester.id,
    p_token: direct.invite_token,
    p_client_action_id: randomUUID(),
  });
  const ids = [pending, accepted, rejected, repeated, withdrawn, superseded];
  const snapshot = async () => ({
    requests:
      await sql`select * from public.project_join_requests where id=any(${ids}::uuid[]) order by id`,
    chats:
      await sql`select * from public.project_join_request_chats where request_id=any(${ids}::uuid[]) order by id`,
    messages:
      await sql`select m.* from public.project_join_request_chat_messages m join public.project_join_request_chats c on c.id=m.chat_id where c.request_id=any(${ids}::uuid[]) order by m.id`,
    memberships:
      await sql`select * from public.project_memberships where project_id=any(${projects}::uuid[]) order by id`,
    admissions:
      await sql`select * from private.project_participant_admissions where project_id=any(${projects}::uuid[]) order by client_action_id`,
  });
  const before = await snapshot();
  assert.equal(
    before.requests.find((x) => x.id === superseded).resolution_reason,
    "direct_participant_invitation",
  );
  const cachedDelegate = await subscribeLegacy(delegate, oldChat);
  const legacyEndpoint = await subscribeLegacy(requester, oldChat);
  cli(["migration", "up", "--local"]);
  const after = await snapshot();
  assert.ok(
    JSON.stringify(before) === JSON.stringify(after),
    "Upgrade must leave original records, bodies, authors, timestamps, status, membership/admission references unchanged.",
  );
  const associations =
    await sql`select * from public.participation_conversation_requests where request_id=any(${ids}::uuid[]) order by request_id`;
  assert.equal(associations.length, ids.length);
  assert.equal(new Set(associations.map((x) => x.conversation_id)).size, 1);
  for (const mapping of associations)
    assert.equal(
      mapping.legacy_chat_id,
      before.chats.find((x) => x.request_id === mapping.request_id).id,
    );
  const earliest = [...before.requests].sort(
    (a, b) =>
      a.created_at - b.created_at ||
      before.chats
        .find((x) => x.request_id === a.id)
        .id.localeCompare(before.chats.find((x) => x.request_id === b.id).id),
  )[0];
  const pairId = associations[0].conversation_id;
  assert.equal(
    pairId,
    before.chats.find((x) => x.request_id === earliest.id).id,
  );
  const history = await upgradedFeed(requester, pairId);
  assert.equal(history.length, before.requests.length + before.messages.length);
  assert.equal(new Set(history.map(key)).size, history.length);
  for (const source of before.messages) {
    const item = history.find(
      (x) => x.item_kind === "legacy_message" && x.item_id === source.id,
    );
    assert.ok(
      item &&
        item.body === source.body &&
        item.sender_profile_id === source.sender_profile_id &&
        new Date(item.created_at).getTime() === source.created_at.getTime(),
      "Legacy source content, author, identity and timestamp must survive.",
    );
    assert.equal(
      item.request_id,
      before.chats.find((x) => x.id === source.chat_id).request_id,
    );
  }
  for (const source of before.requests) {
    const item = history.find(
      (x) => x.item_kind === "request" && x.item_id === source.id,
    );
    assert.equal(item.request_status, source.status);
    assert.equal(
      new Date(item.created_at).getTime(),
      source.created_at.getTime(),
    );
    assert.equal((await get(creator, source.id)).chat_id, pairId);
  }
  assert.equal((await get(creator, pending)).pending_count, 2);
  assert.ok(
    (
      await rpc(delegate, "list_project_join_requests_for_manager", {
        p_expected_manager_profile_id: delegate.id,
        p_project_id: projects[0],
      })
    ).some((x) => x.request_id === pending),
  );
  await denied(delegate, "get_own_project_join_request_chat", {
    p_expected_profile_id: delegate.id,
    p_request_id: pending,
  });
  await denied(delegate, "list_own_project_join_request_chat_items", {
    p_expected_profile_id: delegate.id,
    p_chat_id: oldChat,
    p_limit: 10,
  });
  await denied(delegate, "send_project_join_request_chat_message", {
    p_expected_profile_id: delegate.id,
    p_chat_id: oldChat,
    p_body: "Forbidden",
  });
  await subscribe(delegate, pairId, false);
  const positive = await subscribe(creator, pairId);
  await oldSend(
    requester,
    oldChat,
    "Synthetic retained endpoint compatibility",
  );
  await send(creator, pairId, "Synthetic new pair history");
  await rpc(creator, "reject_project_join_request_as_manager", {
    p_expected_manager_profile_id: creator.id,
    p_request_id: pending,
  });
  await waitUntil(
    () => positive.length >= 3 && legacyEndpoint.length > 0,
    "post-upgrade endpoint signals",
  );
  // A positive subscriber proves the publisher is active; allow socket delivery
  // to settle before asserting zero addressed payloads on the cached delegate.
  await new Promise((resolve) => setTimeout(resolve, 250));
  assert.equal(
    cachedDelegate.length,
    0,
    "An already-connected delegate must receive no post-upgrade personal signals.",
  );
  console.log(
    "Confirmed populated predecessor upgrade: six pending/resolved/repeated/superseded episodes, original source records and references, actual delegate authors, deterministic no-copy mapping, old endpoint RPC/URL context, and cached delegate socket isolation.",
  );
}

function cli(args) {
  const result = spawnSync("supabase", args, {
    encoding: "utf8",
    shell: process.platform === "win32",
    maxBuffer: 16 * 1024 * 1024,
  });
  if (result.error || result.status !== 0)
    throw new Error(
      `MSG01 disposable QA migration step ${args.join(" ")} failed (exit ${result.status ?? "unavailable"}).`,
    );
}
async function subscribeLegacy(account, chatId) {
  const signals = [];
  const channel = account.client.channel(
    `project-request-chat:${chatId}:profile:${account.id}`,
    { config: { private: true } },
  );
  channels.push({ client: account.client, channel });
  channel.on(
    "broadcast",
    { event: "project.join_request_chat_message_sent" },
    (value) => signals.push(value.payload),
  );
  await new Promise((resolve, reject) => {
    const timer = setTimeout(
      () => reject(new Error("Predecessor legacy subscription timed out.")),
      10000,
    );
    channel.subscribe((state) => {
      if (state === "SUBSCRIBED") {
        clearTimeout(timer);
        resolve();
      } else if (["CHANNEL_ERROR", "TIMED_OUT", "CLOSED"].includes(state)) {
        clearTimeout(timer);
        reject(new Error("Predecessor authorized legacy subscription failed."));
      }
    });
  });
  return signals;
}

function key(item) {
  return `${item.item_kind}:${item.item_id}`;
}
async function user(name) {
  const account = await signInLocalOtpUser({
    ...status,
    mailpitUrl,
    email: `msg01-${runId}-${name}@planets.invalid`,
    verifierName: "MSG01",
  });
  const inserted = await account.client
    .from("profiles")
    .insert({ id: account.id });
  if (inserted.error && inserted.error.code !== "23505")
    throw new Error(`Profile setup failed (${inserted.error.code}).`);
  await rpc(account, "update_own_profile", {
    p_expected_profile_id: account.id,
    p_display_name: `MSG01 ${name}`,
    p_bio: null,
    p_skill_ids: [],
    p_display_name_audience: "private",
    p_bio_audience: "private",
    p_skills_audience: "private",
  });
  await ensureLocalProfilePhoto(account);
  return account;
}
async function fixture(owner, kind = "one_time") {
  const id = randomUUID();
  if (kind === "one_time")
    await sql`insert into public.proposals(id,creator_profile_id,lifecycle_state,title,starts_at,ends_at,published_at)
    values(${id},${owner.id},'published','Synthetic MSG01 Proposal',now()+interval '1 day',now()+interval '2 days',now())`;
  else
    await sql`insert into public.recurring_activities(id,creator_profile_id,lifecycle_state,title,published_at)
    values(${id},${owner.id},'published','Synthetic MSG01 Tavolo',now())`;
  return id;
}
function request(account, projectId) {
  return rpc(account, "request_to_join_project", {
    p_expected_requester_profile_id: account.id,
    p_project_id: projectId,
    p_request_message: "Synthetic original request",
    p_skill_ids: [],
    p_resource_need_ids: [],
  });
}
async function get(account, requestId) {
  return (
    await rpc(account, "get_own_participation_conversation", {
      p_expected_profile_id: account.id,
      p_request_id: requestId,
    })
  )[0];
}
function send(account, pairId, body) {
  return rpc(account, "send_participation_conversation_message", {
    p_expected_profile_id: account.id,
    p_chat_id: pairId,
    p_body: body,
  });
}
function feed(account, pairId, limit = 50, cursor) {
  return rpc(
    account,
    "list_own_participation_conversation_items",
    feedParams(account, pairId, limit, cursor),
  );
}
function feedParams(account, pairId, limit = 50, cursor) {
  return {
    p_expected_profile_id: account.id,
    p_chat_id: pairId,
    p_limit: limit,
    p_before_created_at: cursor?.created_at ?? null,
    p_before_item_kind: cursor?.item_kind ?? null,
    p_before_item_id: cursor?.item_id ?? null,
  };
}
async function upgradedFeed(account, pairId) {
  // CLI migration completion precedes PostgREST's asynchronous schema reload.
  // Retry only this read and only the missing-cache signature; mutations and
  // authorization/domain failures retain their ordinary fail-loud behavior.
  const deadline = Date.now() + 10000;
  while (true) {
    const { data, error } = await account.client.rpc(
      "list_own_participation_conversation_items",
      feedParams(account, pairId),
    );
    if (!error) return data;
    if (error.code !== "PGRST202" || Date.now() >= deadline)
      throw new Error(
        `MSG01 upgraded list_own_participation_conversation_items for pair ${pairId} failed (code ${error.code}).`,
      );
    await new Promise((resolve) => setTimeout(resolve, 200));
  }
}
async function rpc(account, name, params) {
  const result = await account.client.rpc(name, params);
  if (result.error)
    throw new Error(`${name} failed (code ${result.error.code}).`);
  return result.data;
}
async function denied(account, name, params) {
  const result = await account.client.rpc(name, params);
  assert.equal(result.error?.code, "42501", name);
  assert.equal(result.data, null);
}
async function identity(tx, id) {
  await tx`set local role authenticated`;
  await tx`select set_config('request.jwt.claim.sub',${id},true)`;
}
async function waitUntil(predicate, label) {
  const until = Date.now() + 10000;
  while (Date.now() < until) {
    if (await predicate()) return;
    await new Promise((resolve) => setTimeout(resolve, 50));
  }
  throw new Error(`Timed out: ${label}.`);
}
function waitForDatabaseLock(name) {
  return waitUntil(
    async () =>
      (
        await sql`select count(*)::int as n from pg_stat_activity where wait_event_type='Lock' and query like ${`%${name}%`}`
      )[0].n > 0,
    `serialized ${name}`,
  );
}
async function subscribe(account, pairId, allowed = true) {
  const signals = [];
  const channel = account.client.channel(
    `participation-conversation:${pairId}:profile:${account.id}`,
    { config: { private: true } },
  );
  channels.push({ client: account.client, channel });
  channel.on(
    "broadcast",
    { event: "participation.conversation_changed" },
    (value) => signals.push(value.payload),
  );
  await new Promise((resolve, reject) => {
    const timeout = setTimeout(
      () => reject(new Error("Pair subscription timed out.")),
      10000,
    );
    channel.subscribe((state) => {
      if (state === "SUBSCRIBED") {
        clearTimeout(timeout);
        allowed
          ? resolve()
          : reject(new Error("Delegate subscribed to personal chat."));
      } else if (["CHANNEL_ERROR", "CLOSED", "TIMED_OUT"].includes(state)) {
        clearTimeout(timeout);
        allowed
          ? reject(new Error("Endpoint subscription failed."))
          : resolve();
      }
    });
  });
  return signals;
}
