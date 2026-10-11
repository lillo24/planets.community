import assert from "node:assert/strict";
import { createHash, randomUUID } from "node:crypto";
import { readFileSync } from "node:fs";
import { createClient } from "@supabase/supabase-js";
import postgres from "postgres";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";
import { signInLocalOtpUser } from "./lib/local-authenticated-user.mjs";

// Disposable local stack only. Shared activation has a separate read-only SQL runbook.
const { apiUrl, publishableKey, databaseUrl } = readLocalSupabaseStatus(
  process.cwd(),
);
const mailpitUrl = process.env.MAILPIT_URL ?? "http://127.0.0.1:54324";
for (const url of [apiUrl, databaseUrl, mailpitUrl]) {
  if (
    !url ||
    !["localhost", "127.0.0.1", "[::1]"].includes(new URL(url).hostname)
  ) {
    throw new Error(
      "OST01 verifier requires loopback API, database and mailbox URLs.",
    );
  }
}
const sql = postgres(databaseUrl, { max: 4, onnotice: () => {} });
const anonymous = createClient(apiUrl, publishableKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});
const catalog = JSON.parse(
  readFileSync(
    new URL(
      "../supabase/catalog/official-starter-templates.json",
      import.meta.url,
    ),
    "utf8",
  ),
);
async function rpc(client, name, args = {}) {
  const { data, error } = await client.rpc(name, args);
  if (error) throw new Error(`OST01 ${name}: ${error.code} ${error.message}`);
  return data;
}
const detail = async (id) =>
  (
    await rpc(anonymous, "get_public_proposal_template_v2", {
      p_template_id: id,
    })
  )[0];
const intent = (actor, item, key = randomUUID()) => ({
  p_expected_creator_profile_id: actor.id,
  p_template_id: item.template_id,
  p_content_version: item.content_version,
  p_client_request_id: key,
  p_prefill_capacity: true,
});
try {
  const all = await rpc(anonymous, "list_public_proposal_templates_v2", {
    p_limit: 50,
  });
  const official = all.filter((t) => t.is_official);
  assert.equal(official.length, 8);
  assert.deepEqual(
    new Set(official.map((t) => t.template_id)),
    new Set(catalog.map((t) => t.template_id)),
  );
  const media = JSON.parse(
    readFileSync(new URL("./demo-assets/assets.json", import.meta.url), "utf8"),
  );
  for (const expected of catalog) {
    const item = await detail(expected.template_id);
    assert.equal(item.source_proposal_id, null);
    assert.equal(item.original_creator_profile_id, null);
    assert.equal(item.creator_display_name, "Planets Community Official");
    assert.equal(item.title, expected.content.title);
    assert.equal(item.resource_blueprint_count, 2);
    assert.equal(item.skills.length, 2);
    const [{ content }] =
      await sql`select content from private.official_starter_template_content where template_id=${expected.template_id}::uuid`;
    assert.deepEqual(
      content,
      expected.content,
      `reviewed content drift: ${expected.key}`,
    );
    const old = await rpc(anonymous, "get_public_proposal_template", {
      p_template_id: expected.template_id,
    });
    assert.deepEqual(old, [], "legacy source projection remains compatible");
    const key = expected.content.cover_asset_key;
    assert.equal(item.cover_asset_key, key);
    if (key) {
      const bytes = readFileSync(
        new URL(
          `../apps/mobile/assets/official_templates/${key}.webp`,
          import.meta.url,
        ),
      );
      const credit = media.covers.find((m) => m.file === `covers/${key}.webp`);
      assert.ok(credit?.sourcePageUrl && credit.photographer);
      assert.equal(
        createHash("sha256").update(bytes).digest("hex"),
        credit.sha256,
        "licensed bundled bytes match reviewed provenance",
      );
    }
  }
  const users = await Promise.all(
    ["applicant", "peer"].map((role) =>
      signInLocalOtpUser({
        apiUrl,
        publishableKey,
        mailpitUrl,
        email: `ost01-${role}@planets.invalid`,
        verifierName: `OST01 ${role}`,
      }),
    ),
  );
  for (const actor of users) {
    await sql`insert into public.profiles(id,display_name) values (${actor.id}::uuid,'OST01 local tester') on conflict(id) do update set display_name=excluded.display_name`;
  }
  const [actor, peer] = users;
  const item = await detail(catalog[0].template_id);
  const args = intent(actor, item);
  const receipts = await Promise.all([
    rpc(actor.client, "create_proposal_draft_from_template", args),
    rpc(actor.client, "create_proposal_draft_from_template", args),
  ]);
  const draft = receipts[0][0].proposal_id;
  assert.equal(
    receipts[1][0].proposal_id,
    draft,
    "concurrent exact retries create one destination",
  );
  assert.equal(receipts[0][0].source_proposal_id, null);
  const [stored] =
    await sql`select p.*, j.registration_capacity, j.count_organizers_toward_capacity from public.proposals p join public.projects j on j.id=p.id where p.id=${draft}::uuid`;
  assert.equal(stored.lifecycle_state, "draft");
  for (const field of [
    "starts_at",
    "ends_at",
    "country_code",
    "locality",
    "published_at",
  ])
    assert.equal(stored[field], null);
  assert.equal(
    stored.registration_capacity,
    catalog[0].content.registration_capacity_recommendation,
  );
  assert.equal(stored.count_organizers_toward_capacity, false);
  const needs =
    await sql`select id,title,details from public.project_resource_needs where project_id=${draft}::uuid order by title`;
  assert.equal(needs.length, 2);
  assert.ok(
    needs.every(
      (n) =>
        !catalog[0].content.resource_blueprints.some(
          (s) => s.source_need_id === n.id,
        ),
    ),
  );
  assert.deepEqual(
    needs.map(({ title, details }) => ({ title, details })),
    catalog[0].content.resource_blueprints
      .map(({ title, details }) => ({ title, details }))
      .sort((a, b) => a.title.localeCompare(b.title)),
  );
  assert.equal(
    (
      await sql`select count(*)::int n from public.proposal_skills where proposal_id=${draft}::uuid`
    )[0].n,
    2,
  );
  const peerRecovery = await rpc(
    peer.client,
    "get_own_proposal_template_application",
    {
      p_expected_creator_profile_id: peer.id,
      p_client_request_id: args.p_client_request_id,
    },
  );
  assert.deepEqual(peerRecovery, []);

  // Administrative edit and application serialize on the same identity row.
  const changed = {
    ...catalog[0].content,
    summary: "OST01 temporary local overlap check",
  };
  let pending;
  await sql.begin(async (tx) => {
    const [{ pid }] = await tx`select pg_backend_pid() pid`;
    await tx`select id from private.proposal_templates where id=${item.template_id}::uuid for update`;
    pending = actor.client
      .rpc("create_proposal_draft_from_template", intent(actor, item))
      .then((r) => r);
    const deadline = Date.now() + 10000;
    while (true) {
      const [{ blocked }] =
        await sql`select exists(select 1 from pg_stat_activity where ${pid}::int=any(pg_blocking_pids(pid))) blocked`;
      if (blocked) break;
      if (Date.now() > deadline)
        throw new Error(
          "OST01 application did not wait behind the reviewed content lock.",
        );
      await new Promise((resolve) => setTimeout(resolve, 30));
    }
    await tx`select private.provision_official_starter_template(${item.template_id}::uuid,${catalog[0].key},private.proposal_template_content_version(${tx.json(catalog[0].content)}::jsonb),${tx.json(changed)}::jsonb,'OST01 local concurrency review')`;
  });
  try {
    assert.equal(
      (await pending).error?.code,
      "PT409",
      "waiting application rechecks changed content",
    );
    const recovery = await rpc(
      actor.client,
      "create_proposal_draft_from_template",
      args,
    );
    assert.equal(
      recovery[0].proposal_id,
      draft,
      "accepted version survives later edits",
    );
  } finally {
    await sql`select private.provision_official_starter_template(${item.template_id}::uuid,${catalog[0].key},private.proposal_template_content_version(${sql.json(changed)}::jsonb),${sql.json(catalog[0].content)}::jsonb,'OST01 restore reviewed local catalog')`;
  }
  assert.equal(
    (await detail(item.template_id)).content_version,
    item.content_version,
  );
  console.log(
    "OST01: eight public examples, legacy compatibility, licensed covers, complete independent drafts, cross-user recovery and overlapping edit/apply passed.",
  );
} finally {
  await sql.end({ timeout: 5 });
}
