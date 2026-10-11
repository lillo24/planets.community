import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import postgres from "postgres";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";

// Checkpoint only; the documented operator sequence performs local resets/upgrades.
const { databaseUrl } = readLocalSupabaseStatus(process.cwd());
assert.equal(
  process.env.PLANETS_DISPOSABLE_QA,
  "1",
  "Explicit disposable QA acknowledgment required.",
);
assert.ok(
  databaseUrl &&
    ["localhost", "127.0.0.1", "[::1]"].includes(new URL(databaseUrl).hostname),
  "OST01 upgrade rehearsal requires a loopback database.",
);
const sql = postgres(databaseUrl, { max: 1, onnotice: () => {} });
const checkpoint = join(
  tmpdir(),
  `planets-ost01-upgrade-${new URL(databaseUrl).port}.json`,
);
async function digest(table, upgraded) {
  const rows =
    table === "private.proposal_templates" && upgraded
      ? await sql`select coalesce(jsonb_agg(to_jsonb(t)-'template_kind'-'starter_key' order by t.id),'[]'::jsonb) as data from private.proposal_templates t where t.template_kind='community'`
      : await sql`select coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text),'[]'::jsonb) as data from ${sql(table)} t`;
  // Sort after removing new schema-only fields so both phases use the same order.
  const ordered = rows[0].data.map((r) => JSON.stringify(r)).sort();
  return {
    count: ordered.length,
    sha256: createHash("sha256").update(JSON.stringify(ordered)).digest("hex"),
  };
}
try {
  const [{ present }] =
    await sql`select to_regclass('private.official_starter_template_content') is not null present`;
  if (process.argv[2] === "--before") {
    assert.equal(present, false, "Checkpoint requires pre-OST01 schema.");
    const tables =
      await sql`select n.nspname||'.'||c.relname as name from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname in ('public','private') and c.relkind='r' order by 1`;
    const record = {};
    for (const { name } of tables) record[name] = await digest(name, false);
    for (const table of [
      "public.proposals",
      "private.proposal_templates",
      "private.proposal_template_applications",
      "private.moderation_cases",
      "private.proposal_template_removal_actions",
    ])
      assert.ok(
        record[table].count > 0,
        `Populated upgrade fixture missing: ${table}`,
      );
    writeFileSync(checkpoint, JSON.stringify(record), "utf8");
    console.log(
      `OST01 pre-upgrade checkpoint: ${tables.length} domain tables, including accepted applications and moderation removals.`,
    );
  } else if (process.argv[2] === "--after") {
    assert.equal(present, true, "After phase requires real forward migration.");
    const record = JSON.parse(readFileSync(checkpoint, "utf8"));
    for (const [table, previous] of Object.entries(record))
      assert.deepEqual(
        await digest(table, true),
        previous,
        `Upgrade changed existing rows: ${table}`,
      );
    assert.equal(
      (
        await sql`select count(*)::int n from public.list_public_proposal_templates_v2(p_limit=>50) where is_official`
      )[0].n,
      8,
    );
    console.log(
      `OST01 populated upgrade preserved every existing row across ${Object.keys(record).length} domain tables and exposed eight examples.`,
    );
  } else throw new Error("Choose --before or --after.");
} finally {
  await sql.end({ timeout: 5 });
}
