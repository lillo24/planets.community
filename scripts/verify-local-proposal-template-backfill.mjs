import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import postgres from "postgres";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";

// Explicit local upgrade rehearsal, never run inside ordinary CI/reset tests.
// See docs/development/template-workshop.md for the before/migrate/after sequence.
const phase = process.argv[2];
if (!["--before", "--after"].includes(phase)) {
  throw new Error(
    "Use --before on pre-TW01 schema or --after after local migration up.",
  );
}
const { databaseUrl } = readLocalSupabaseStatus(process.cwd());
if (!databaseUrl)
  throw new Error("TW01 backfill local database URL is missing.");
const sql = postgres(databaseUrl);
const owner = "e9000000-0000-4000-8000-000000000001";
const source = (n) => `e9100000-0000-4000-8000-${String(n).padStart(12, "0")}`;
try {
  if (phase === "--before") {
    const [{ template_table }] =
      await sql`select to_regclass('private.proposal_templates') as template_table`;
    assert.equal(
      template_table,
      null,
      "backfill before-phase requires pre-TW01 local schema",
    );
    await sql`insert into auth.users(id,email) values (${owner}::uuid,'tw01-backfill@planets.invalid')`;
    await sql`insert into public.profiles(id,display_name) values (${owner}::uuid,'TW01 legacy author')`;
    for (const [n, state, future] of [
      [1, "draft", true],
      [2, "published", true],
      [3, "published", false],
      [4, "cancelled", false],
    ]) {
      await sql`insert into public.proposals(id,creator_profile_id,lifecycle_state,title,summary,description,starts_at,ends_at,published_at,cancelled_at)
        values (${source(n)}::uuid,${owner}::uuid,${state},'TW01 legacy idea','Reusable legacy summary','No retained draft exists',
          now()+${future ? "2 days" : "-4 days"}::interval,now()+${future ? "3 days" : "-3 days"}::interval,
          ${state === "draft" ? null : "2026-01-01T00:00:00Z"}::timestamptz,
          ${state === "cancelled" ? "2026-01-02T00:00:00Z" : null}::timestamptz)`;
    }
    console.log(
      "TW01 legacy draft/future/completed/cancelled fixtures created on pre-migration local schema.",
    );
  } else {
    const identities =
      await sql`select * from private.proposal_templates where original_creator_profile_id=${owner}::uuid order by source_proposal_id`;
    assert.deepEqual(
      identities.map((row) => row.source_proposal_id),
      [source(2), source(3), source(4)],
    );
    const [{ baselines }] =
      await sql`select count(*)::int as baselines from private.proposal_template_baselines where template_id=any(${identities.map((row) => row.id)}::uuid[])`;
    assert.equal(baselines, 0, "backfill must not invent saved drafts");
    const rows =
      await sql`select source_proposal_id from public.list_public_proposal_templates(p_query=>'TW01 legacy idea')`;
    assert.deepEqual(
      rows.map((row) => row.source_proposal_id),
      [source(3)],
    );
    const [{ events }] =
      await sql`select count(*)::int as events from private.outbox_events where payload->>'proposal_id'=any(${[source(1), source(2), source(3), source(4)]}::text[])`;
    assert.equal(events, 0, "backfill must not fabricate publication events");
    const migration = await readFile(
      new URL(
        "../supabase/migrations/20261003125831_source_linked_proposal_template_workshop.sql",
        import.meta.url,
      ),
      "utf8",
    );
    const statement = migration.match(
      /^insert into private\.proposal_templates \([\s\S]*?on conflict \(source_proposal_id\) do nothing;/m,
    )?.[0];
    assert.ok(
      statement,
      "could not locate the actual migration backfill statement",
    );
    await sql.unsafe(statement);
    assert.deepEqual(
      await sql`select * from private.proposal_templates where original_creator_profile_id=${owner}::uuid order by source_proposal_id`,
      identities,
    );
    console.log(
      "TW01 actual upgrade backfill passed: one identity per publication, no draft baseline/events, Completed-only reads and idempotent replay.",
    );
  }
} finally {
  await sql.end();
}
