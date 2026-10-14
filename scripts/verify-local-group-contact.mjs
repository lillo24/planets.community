import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import postgres from "postgres";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";
import { signInLocalOtpUser } from "./lib/local-authenticated-user.mjs";

// Synthetic local actors only. Never print sessions, notes, provider payloads or
// keys. The CLI selects this checkout's task-owned disposable config.
const status = readLocalSupabaseStatus(process.cwd());
const mailpitUrl = process.env.MAILPIT_URL ?? "http://127.0.0.1:54324";
for (const endpoint of [status.apiUrl, status.databaseUrl, mailpitUrl]) {
  assert.ok(
    ["127.0.0.1", "localhost", "[::1]"].includes(new URL(endpoint).hostname),
    "Contact verification requires loopback endpoints.",
  );
}
const sql = postgres(status.databaseUrl, { max: 8, onnotice: () => {} });
const run = randomUUID().slice(0, 8);
let checks = 0;
function equal(actual, expected, label) {
  assert.deepEqual(actual, expected, label);
  checks++;
}
const actor = (person) => ({ p_expected_profile_id: person.id });
const bound = (person, params) => ({
  ...(params.p_expected_reporter_profile_id ||
  params.p_expected_staff_profile_id
    ? {}
    : actor(person)),
  ...params,
});
async function call(person, name, params = {}) {
  const result = await person.client.rpc(name, bound(person, params));
  equal(
    result.error?.code ?? null,
    null,
    `${name} failed: ${result.error?.code ?? "none"}`,
  );
  return result.data;
}
async function denied(person, name, params, code = "42501") {
  const result = await person.client.rpc(name, bound(person, params));
  equal(result.error?.code, code, `${name} denial`);
}
async function user(label) {
  const person = await signInLocalOtpUser({
    ...status,
    mailpitUrl,
    email: `d-contact-${run}-${label}@planets.invalid`,
    verifierName: "group-contact",
  });
  await sql`insert into public.profiles(id,display_name) values(${person.id}::uuid,${`Fictional D ${label}`})`;
  return person;
}
async function group(person, label) {
  const id = await call(person, "create_group_draft", {
    p_client_request_id: randomUUID(),
    p_content: {
      name: `Fictional D ${run} ${label}`,
      description: "A synthetic local collaboration group for verification.",
      group_kind: "informal",
      locality: "Trento",
      volunteering_focus: true,
    },
  });
  await call(person, "set_group_publication_state", {
    p_group_id: id,
    p_client_request_id: randomUUID(),
    p_expected_version: 1,
    p_publication_state: "published",
  });
  return id;
}
async function grant(creator, person, groupId) {
  const [invitation] = await call(
    creator,
    "create_group_authority_invitation",
    {
      p_group_id: groupId,
      p_client_request_id: randomUUID(),
      p_role: "co_organizer",
    },
  );
  const [result] = await call(person, "accept_group_authority_invitation", {
    p_token: invitation.invite_token,
    p_client_request_id: randomUUID(),
  });
  return result.relationship_id;
}
async function asUser(tx, person, query) {
  await tx`select set_config('request.jwt.claim.sub',${person.id},true)`;
  await tx.unsafe("set local role authenticated");
  const result = await query(tx);
  await tx.unsafe("reset role");
  return result;
}
async function afterWait(groupId, rpcName, launch, transition) {
  let signal, release;
  const ready = new Promise((resolve) => {
    signal = resolve;
  });
  const proceed = new Promise((resolve) => {
    release = resolve;
  });
  const holder = sql.begin(async (tx) => {
    await tx`select id from private.community_groups where id=${groupId}::uuid for update`;
    signal();
    await proceed;
    await transition(tx);
  });
  await ready;
  // PostgREST builders are lazy thenables: assimilate now so the HTTP request
  // actually starts while the independent transaction is holding its row lock.
  const pending = Promise.resolve(launch());
  try {
    let waiting = false;
    for (let attempt = 0; attempt < 100; attempt++) {
      const [state] =
        await sql`select exists(select 1 from pg_stat_activity where pid<>pg_backend_pid() and wait_event_type='Lock' and query ilike ${`%${rpcName}%`}) waiting`;
      if (state.waiting) {
        waiting = true;
        break;
      }
      await new Promise((resolve) => setTimeout(resolve, 50));
    }
    equal(waiting, true, `observed ${rpcName} lock wait`);
  } finally {
    release();
  }
  await holder;
  return pending;
}

try {
  const alice = await user("alice"),
    bob = await user("bob"),
    carol = await user("carol"),
    outsider = await user("outsider");
  const garden = await group(alice, "Garden"),
    workshop = await group(bob, "Workshop"),
    library = await group(alice, "Library");
  const carolGrant = await grant(bob, carol, workshop);
  const requestIntent = {
    p_action_id: randomUUID(),
    p_source_group_id: garden,
    p_target_group_id: workshop,
    p_purpose: "collaboration",
    p_title: "Synthetic collaboration",
    p_note: "Private synthetic local request.",
  };
  // Deliberately discard the first canonical delivery as a lost-response model.
  await call(alice, "submit_group_contact_request", requestIntent);
  const request = await call(
    alice,
    "submit_group_contact_request",
    requestIntent,
  );
  equal(request.replayed, true, "lost submit replay");
  await denied(
    alice,
    "submit_group_contact_request",
    { ...requestIntent, p_note: "Changed intent" },
    "PT409",
  );
  await denied(outsider, "get_own_group_contact_request", {
    p_request_id: request.request_id,
  });
  const triage = await call(carol, "get_own_group_contact_request", {
    p_request_id: request.request_id,
  });
  equal(triage.request_message, requestIntent.p_note, "authorized triage");
  const acceptArgs = {
    p_action_id: randomUUID(),
    p_request_id: request.request_id,
  };
  const accepted = await call(
    carol,
    "accept_group_contact_request",
    acceptArgs,
  );
  equal(
    (await call(carol, "accept_group_contact_request", acceptArgs)).chat_id,
    accepted.chat_id,
    "lost accept returns same chat",
  );
  await denied(bob, "get_own_group_contact_conversation", {
    p_chat_id: accepted.chat_id,
  });
  const resolved = await call(bob, "get_own_group_contact_request", {
    p_request_id: request.request_id,
  });
  equal(
    resolved.request_message,
    null,
    "other manager cannot read resolved note",
  );
  equal(resolved.chat_id, null, "other manager has no exact chat route");
  const ownRequest = await call(alice, "get_own_group_contact_request", {
    p_request_id: request.request_id,
  });
  equal(
    ownRequest.chat_id,
    accepted.chat_id,
    "submitter can navigate accepted chat",
  );
  const legacyBefore = await call(carol, "get_own_message_unread_summary");
  const sendIntent = {
    p_action_id: randomUUID(),
    p_chat_id: accepted.chat_id,
    p_body: "Synthetic human message",
  };
  const sent = await call(alice, "send_group_contact_message", sendIntent);
  equal(
    (await call(alice, "send_group_contact_message", sendIntent)).message_id,
    sent.message_id,
    "lost send returns same message",
  );
  equal(
    await call(carol, "get_own_message_unread_summary"),
    legacyBefore,
    "old-client totals exclude D",
  );
  equal(
    (await call(carol, "get_own_message_unread_summary_v2")).groups,
    legacyBefore.groups + 1,
    "new totals include D unread conversation",
  );
  equal(
    (
      await call(carol, "list_own_scoped_conversation_items_v5", {
        p_scope: "groups",
        p_limit: 20,
      })
    ).some((item) => item.item_kind === "group_contact_chat"),
    false,
    "legacy exact kinds unchanged",
  );
  const feed = await call(carol, "get_own_group_contact_feed", {
    p_chat_id: accepted.chat_id,
    p_limit: 20,
  });
  equal(feed.items.length, 1, "one committed human send");
  await call(carol, "acknowledge_own_message_read_v2", {
    p_kind: "group_contact_chat",
    p_chat_id: accepted.chat_id,
    p_boundary: feed.read_boundary,
  });
  equal(
    await call(carol, "get_own_message_unread_summary_v2"),
    legacyBefore,
    "canonical acknowledged D unread",
  );

  const result = await afterWait(
    workshop,
    "send_group_contact_message",
    () =>
      alice.client.rpc("send_group_contact_message", {
        ...actor(alice),
        p_action_id: randomUUID(),
        p_chat_id: accepted.chat_id,
        p_body: "Must not commit after revoke",
      }),
    (tx) =>
      asUser(
        tx,
        bob,
        (t) =>
          t`select public.revoke_group_delegate(${bob.id}::uuid,${carolGrant}::uuid,${randomUUID()}::uuid)`,
      ),
  );
  equal(result.error?.code, "42501", "send rechecks role after observed wait");
  await denied(carol, "get_own_group_contact_feed", {
    p_chat_id: accepted.chat_id,
  });
  await denied(carol, "acknowledge_group_contact_read", {
    p_chat_id: accepted.chat_id,
    p_boundary: feed.read_boundary,
  });
  await grant(bob, carol, workshop);
  await denied(carol, "get_own_group_contact_conversation", {
    p_chat_id: accepted.chat_id,
  });
  const receipt = await call(carol, "recover_group_contact_action", {
    p_action_id: acceptArgs.p_action_id,
  });
  equal(
    receipt.outcome,
    "accepted",
    "own metadata recovery after old grant loss",
  );
  const reportArgs = {
    p_expected_reporter_profile_id: carol.id,
    p_client_submission_id: randomUUID(),
    p_category: "harassment_abuse",
    p_explanation: "Synthetic report of the earlier received message.",
    p_target_kind: "group_contact_message",
    p_target_id: sent.message_id,
  };
  const report = await call(carol, "submit_moderation_report", reportArgs);
  equal(
    (await call(carol, "submit_moderation_report", reportArgs))[0].case_id,
    report[0].case_id,
    "report retry after role loss",
  );
  await denied(outsider, "get_moderation_case_group_contact", {
    p_expected_staff_profile_id: outsider.id,
    p_case_id: report[0].case_id,
  });
  await sql`insert into private.moderation_staff_roles(profile_id,staff_role) values(${outsider.id}::uuid,'moderator')`;
  const evidence = await call(outsider, "get_moderation_case_group_contact", {
    p_expected_staff_profile_id: outsider.id,
    p_case_id: report[0].case_id,
  });
  equal(
    evidence.body,
    sendIntent.p_body,
    "staff gets only exact targeted evidence",
  );
  await denied(outsider, "get_own_group_contact_conversation", {
    p_chat_id: accepted.chat_id,
  });

  // Accept/decline competing transactions produce one terminal canonical result.
  const second = await call(alice, "submit_group_contact_request", {
    ...requestIntent,
    p_action_id: randomUUID(),
    p_source_group_id: library,
  });
  const competitors = await Promise.all([
    bob.client.rpc("accept_group_contact_request", {
      ...actor(bob),
      p_action_id: randomUUID(),
      p_request_id: second.request_id,
    }),
    carol.client.rpc("decline_group_contact_request", {
      ...actor(carol),
      p_action_id: randomUUID(),
      p_request_id: second.request_id,
    }),
  ]);
  equal(competitors.filter((r) => !r.error).length, 1, "one resolution wins");
  equal(
    competitors.find((r) => r.error).error.code,
    "PT409",
    "loser gets canonical conflict",
  );
  const [duplicates] =
    await sql`select count(*)::integer count from private.group_contact_conversations where request_id=${second.request_id}::uuid`;
  equal(duplicates.count <= 1, true, "no duplicate conversation");

  await denied(
    alice,
    "submit_group_contact_request",
    { ...requestIntent, p_action_id: randomUUID(), p_target_group_id: library },
    "42501",
  );
  const noCommit = await call(alice, "recover_group_contact_action", {
    p_action_id: randomUUID(),
  });
  equal(noCommit, null, "missing receipt is distinct from success");
  console.log(
    `Group contact: ${checks} real-Auth/PostgREST, retry, legacy, safety and observed-race checks passed.`,
  );
} finally {
  await sql.end();
}
