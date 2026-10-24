import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { signInLocalOtpUser } from "../lib/local-authenticated-user.mjs";
import { openA1World, rpc } from "./owned-world.mjs";

const { directory, status, sql } = await openA1World(process.argv[2]);
const world = JSON.parse(
  await readFile(path.join(directory, "private-world.json"), "utf8"),
);
const users = {};
let checks = 0;
const equal = (a, b, label) => {
  assert.deepEqual(a, b, label);
  checks++;
};
async function denied(user, name, args, code = "42501") {
  const { error } = await user.client.rpc(name, args);
  equal(error?.code, code, `${name} must deny exact unauthorized intent`);
}
const own = (user) => ({ p_expected_profile_id: user.id });
const pair = (user, peer) => ({ ...own(user), p_peer_profile_id: peer.id });
try {
  for (const [key, person] of Object.entries(world.people)) {
    users[key] = await signInLocalOtpUser({
      ...status,
      mailpitUrl: "http://127.0.0.1:61324",
      email: person.email,
      verifierName: "A1 HTTP",
      shouldCreateUser: false,
    });
    equal(
      users[key].id,
      person.id,
      "real OTP restores the exact fictional account",
    );
  }
  const { alice, marco, outsider } = users;
  const initial = await rpc(alice, "list_own_private_pairs_v1", own(alice));
  equal(
    initial.length,
    1,
    "one server-paginated row across all personal domains",
  );
  equal(
    initial[0].peer_profile_id,
    marco.id,
    "counterparty is immutable identity",
  );
  const opposite = (
    await rpc(marco, "list_own_private_pairs_v1", own(marco))
  )[0];
  equal(
    initial[0].pair_key,
    opposite.pair_key,
    "both endpoints derive the same unordered identity",
  );
  equal(initial[0].unread_count, 5, "all incoming human messages contribute");
  equal(
    (await rpc(alice, "get_own_private_pair_unread_v1", own(alice))).private,
    1,
    "badge counts a pair once",
  );
  equal(
    (
      await rpc(
        alice,
        "get_own_message_unread_summary_with_cocreate",
        own(alice),
      )
    ).private,
    5,
    "old installed source-count contract remains unchanged",
  );
  equal(
    await rpc(outsider, "list_own_private_pairs_v1", own(outsider)),
    [],
    "outsider has no generic DM",
  );
  await denied(outsider, "get_own_private_pair_page_v1", pair(outsider, alice));
  await denied(outsider, "get_own_private_pair_page_v1", pair(alice, marco));
  await denied(alice, "resolve_own_private_pair_v1", {
    ...own(alice),
    p_context_kind: "resource_chat",
    p_context_id: randomUUID(),
  });
  const page = await rpc(alice, "get_own_private_pair_page_v1", {
    ...pair(alice, marco),
    p_limit: 50,
  });
  const original = page.items.filter((m) => m.body !== null);
  equal(
    original.length,
    5,
    "combined history retains all five original human messages",
  );
  equal(
    new Set(original.map((m) => m.item_kind + ":" + m.item_id)).size,
    5,
    "source namespacing does not collapse legitimate messages",
  );
  const walked = [];
  let before = {};
  for (let n = 0; n < 30; n++) {
    const next = await rpc(alice, "get_own_private_pair_page_v1", {
      ...pair(alice, marco),
      p_limit: 1,
      ...before,
    });
    if (!next.items.length) break;
    const item = next.items[0];
    walked.push(item.item_kind + ":" + item.item_id);
    if (n > 0)
      equal(
        next.read_boundary,
        null,
        "older source pages issue no acknowledgement boundary",
      );
    before = {
      p_before_created_at: item.created_at,
      p_before_item_kind: item.item_kind,
      p_before_item_id: item.item_id,
    };
  }
  equal(
    walked,
    page.items.map((m) => m.item_kind + ":" + m.item_id),
    "mixed keyset paging has neither omissions nor duplicates",
  );
  const coMessage = original.find((m) => m.source_kind === "cocreate_contact");
  await rpc(alice, "acknowledge_own_private_pair_v1", {
    ...pair(alice, marco),
    p_boundary: page.read_boundary,
    p_rendered_keys: [coMessage.item_kind + ":" + coMessage.item_id],
  });
  equal(
    (await rpc(alice, "list_own_private_pairs_v1", own(alice)))[0].unread_count,
    4,
    "ACK affects only the rendered source",
  );
  await denied(marco, "acknowledge_own_private_pair_v1", {
    ...pair(marco, alice),
    p_boundary: page.read_boundary,
    p_rendered_keys: [coMessage.item_kind + ":" + coMessage.item_id],
  });

  const command = {
    ...pair(alice, marco),
    p_command_id: randomUUID(),
    p_context_kind: "resource_chat",
    p_context_id: world.resourceChat,
    p_episode_id: null,
    p_body: "Confermo: ci vediamo sabato alle 10.",
  };
  const result = await rpc(alice, "send_own_private_pair_message_v1", command);
  equal(
    await rpc(alice, "send_own_private_pair_message_v1", command),
    result,
    "exact delivery retry returns the immutable source receipt",
  );
  await denied(
    alice,
    "send_own_private_pair_message_v1",
    { ...command, p_body: "Changed intent" },
    "22023",
  );
  await denied(alice, "send_own_private_pair_message_v1", {
    ...command,
    p_command_id: randomUUID(),
    p_peer_profile_id: outsider.id,
  });
  await denied(alice, "send_own_private_pair_message_v1", {
    ...command,
    p_command_id: randomUUID(),
    p_peer_profile_id: alice.id,
  });
  equal(
    (await rpc(marco, "get_own_private_pair_unread_v1", own(marco))).private,
    1,
    "one real outgoing send creates one peer badge",
  );

  const invitation = (
    await rpc(alice, "create_project_delegate_invitation", {
      p_expected_owner_profile_id: alice.id,
      p_project_id: world.project,
    })
  )[0];
  await rpc(outsider, "accept_project_delegate_invitation", {
    p_expected_delegate_profile_id: outsider.id,
    p_token: invitation.invite_token,
  });
  equal(
    (
      await rpc(outsider, "list_project_join_requests_for_manager", {
        p_expected_manager_profile_id: outsider.id,
        p_project_id: world.project,
      })
    ).length,
    1,
    "delegate retains structured request management",
  );
  equal(
    await rpc(outsider, "list_own_private_pairs_v1", own(outsider)),
    [],
    "manager authority creates no personal pair access",
  );
  await denied(outsider, "resolve_own_private_pair_v1", {
    ...own(outsider),
    p_context_kind: "participation_request",
    p_context_id: world.first,
  });

  await sql`update auth.users set banned_until=now()+interval '1 hour' where id=${marco.id}`;
  try {
    equal(
      await rpc(alice, "list_own_private_pairs_v1", own(alice)),
      [],
      "unavailable counterparty leaves no cached pair projection",
    );
    await denied(alice, "get_own_private_pair_page_v1", pair(alice, marco));
    await denied(marco, "list_own_private_pairs_v1", own(marco));
  } finally {
    await sql`update auth.users set banned_until=null where id=${marco.id}`;
  }
  const [acceptance] =
    await sql`select * from private.policy_acceptances where account_id=${alice.id} and bundle_version='POLICY01-2026-10-08-v1'`;
  await sql`delete from private.policy_acceptances where account_id=${alice.id}`;
  try {
    const restricted = await rpc(alice, "get_own_private_pair_page_v1", {
      ...pair(alice, marco),
      p_limit: 50,
    });
    equal(
      restricted.items.some((m) => m.source_kind === "cocreate_contact"),
      false,
      "stale policy removes only gated contact histories",
    );
  } finally {
    await sql`insert into private.policy_acceptances ${sql(acceptance)}`;
  }
  await sql`update private.cocreate_settings set enabled=false`;
  const disabled = await rpc(alice, "get_own_private_pair_page_v1", {
    ...pair(alice, marco),
    p_limit: 50,
  });
  equal(
    disabled.items.some((m) => m.source_kind === "cocreate_contact"),
    false,
    "gate OFF removes bodies and context metadata",
  );
  await denied(alice, "acknowledge_own_private_pair_v1", {
    ...pair(alice, marco),
    p_boundary: page.read_boundary,
    p_rendered_keys: [coMessage.item_kind + ":" + coMessage.item_id],
  });
  await denied(alice, "resolve_own_private_pair_v1", {
    ...own(alice),
    p_context_kind: "cocreate_contact",
    p_context_id: world.contacts[0],
  });
  await sql`update private.cocreate_settings set enabled=true`;

  await rpc(alice, "block_user", {
    p_expected_blocker_profile_id: alice.id,
    p_blocked_profile_id: marco.id,
  });
  const blocked = await rpc(alice, "list_own_private_pair_contexts_v1", {
    ...pair(alice, marco),
    p_only_writable: true,
  });
  equal(
    blocked.map((c) => c.kind),
    ["resource_chat"],
    "blocking preserves only the domain's explicit accepted-Resource exception",
  );
  await rpc(alice, "send_own_private_pair_message_v1", {
    ...command,
    p_command_id: randomUUID(),
    p_body: "Consegna già concordata: gli attrezzi restano disponibili.",
  });
  await rpc(alice, "unblock_user", {
    p_expected_blocker_profile_id: alice.id,
    p_blocked_profile_id: marco.id,
  });
  const [beforeRace] =
    await sql`select count(*)::int count from public.resource_request_chat_messages where chat_id=${world.resourceChat}`;
  let pending;
  await sql.begin(async (tx) => {
    await tx`select id from public.resource_exchange_agreements where id=${world.agreement} for update`;
    pending = alice.client
      .rpc("send_own_private_pair_message_v1", {
        ...command,
        p_command_id: randomUUID(),
        p_body: "This racing send must fail.",
      })
      .then((value) => value);
    let waiting = false;
    for (let n = 0; n < 100; n++) {
      const [state] =
        await sql`select exists(select 1 from pg_stat_activity where pid<>pg_backend_pid()
        and wait_event_type='Lock' and query like '%send_own_private_pair_message_v1%') waiting`;
      if (state.waiting) {
        waiting = true;
        break;
      }
      await new Promise((resolve) => setTimeout(resolve, 25));
    }
    equal(
      waiting,
      true,
      "observe a genuine selected-source lock wait before closing",
    );
    await tx`select set_config('request.jwt.claim.sub',${alice.id},true)`;
    await tx`select public.cancel_resource_exchange_agreement(${alice.id},${world.agreement})`;
  });
  equal(
    (await pending).error?.code,
    "PT409",
    "racing closure rejects the exact source instead of switching to People",
  );
  const [afterRace] =
    await sql`select count(*)::int count from public.resource_request_chat_messages where chat_id=${world.resourceChat}`;
  equal(
    beforeRace.count,
    afterRace.count,
    "failed racing send creates no message",
  );
  const final = await rpc(alice, "get_own_private_pair_page_v1", {
    ...pair(alice, marco),
    p_limit: 50,
  });
  for (const originalMessage of original)
    equal(
      final.items.find(
        (m) =>
          m.item_kind === originalMessage.item_kind &&
          m.item_id === originalMessage.item_id,
      )?.body,
      originalMessage.body,
      "original source IDs and bodies remain intact",
    );
  const proof = {
    checks,
    real_otp_auth: true,
    real_http_rpc: true,
    source_domains: 4,
    accepted_people_posts: 2,
    actual_selected_source_lock_wait: true,
    original_messages_preserved: 5,
    hosted_operations: false,
  };
  await writeFile(
    path.join(directory, "http-proof.json"),
    JSON.stringify(proof, null, 2) + "\n",
  );
  console.log(JSON.stringify(proof));
} finally {
  await sql`update private.cocreate_settings set enabled=false`;
  await sql.end({ timeout: 5 });
}
