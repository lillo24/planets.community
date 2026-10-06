import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync, writeFileSync, unlinkSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import postgres from "postgres";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";

const { databaseUrl } = readLocalSupabaseStatus(process.cwd());
if (
  !databaseUrl ||
  !["127.0.0.1", "localhost", "[::1]"].includes(new URL(databaseUrl).hostname)
)
  throw new Error(
    "TW03 upgrade rehearsal requires a loopback disposable database.",
  );
const sql = postgres(databaseUrl, { max: 1, onnotice: () => {} });
const checkpoint = join(
  tmpdir(),
  "planets-tw03-upgrade-" + new URL(databaseUrl).port + ".json",
);
async function digest(table) {
  const [{ rows }] =
    await sql`select coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text),'[]'::jsonb) as rows from ${sql(table)} as t`;
  return {
    count: rows.length,
    sha256: createHash("sha256").update(JSON.stringify(rows)).digest("hex"),
  };
}
try {
  const [{ present }] =
    await sql`select to_regclass('private.proposal_template_applications') is not null as present`;
  if (process.argv[2] === "--before") {
    assert.equal(present, false, "checkpoint requires exact pre-TW03 schema");
    const tables = (
      await sql`select n.nspname || '.' || c.relname as name from pg_class c join pg_namespace n on n.oid=c.relnamespace
      where n.nspname in ('public','private') and c.relkind='r' order by 1`
    ).map((t) => t.name);
    const record = {};
    for (const table of tables) record[table] = await digest(table);
    for (const table of [
      "public.proposals",
      "private.proposal_templates",
      "private.proposal_template_baselines",
      "private.moderation_cases",
      "private.moderation_reports",
      "private.proposal_template_removal_actions",
    ])
      assert.ok(
        record[table].count > 0,
        "upgrade requires populated fixture: " + table,
      );
    writeFileSync(checkpoint, JSON.stringify(record), "utf8");
    console.log(
      "TW03 upgrade: predecessor checkpoint retained " +
        tables.length +
        " populated/empty domain tables, including genuine baselines and removal attribution.",
    );
  } else if (process.argv[2] === "--after") {
    assert.equal(
      present,
      true,
      "after phase requires real TW03 forward migration",
    );
    const record = JSON.parse(readFileSync(checkpoint, "utf8"));
    for (const [table, previous] of Object.entries(record))
      assert.deepEqual(
        await digest(table),
        previous,
        "upgrade preserves every row: " + table,
      );
    assert.equal(
      (await digest("private.proposal_template_applications")).count,
      0,
      "no fabricated historical applications",
    );
    unlinkSync(checkpoint);
    console.log(
      "TW03 upgrade passed: " +
        Object.keys(record).length +
        " existing domain tables byte-equivalent by canonical row digest; zero fabricated applications.",
    );
  } else
    throw new Error(
      "Use --before on populated TW02 schema, migrate forward, then --after.",
    );
} finally {
  await sql.end({ timeout: 2 });
}
