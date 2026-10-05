import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFile, writeFile, unlink } from "node:fs/promises";
import postgres from "postgres";
import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";
import {
  seedLocalDemoWorld,
  verifyLocalDemoWorld,
  withLocalDemoWorldLock,
} from "./lib/demo-world.mjs";
import { snapshotDemoDomain } from "./lib/demo-workshop.mjs";

const [phase, direction, checkpoint] = process.argv.slice(2);
if (
  !["--before", "--after", "--seed-rerun"].includes(phase) ||
  !["main", "template"].includes(direction) ||
  !checkpoint
)
  throw new Error(
    "Use --before/--after main/template <private checkpoint path> on the owned disposable stack.",
  );
const status = readLocalSupabaseStatus(process.cwd());
if (new URL(status.databaseUrl).hostname !== "127.0.0.1")
  throw new Error("Upgrade snapshots require a loopback database.");
const sql = postgres(status.databaseUrl, { max: 1, onnotice: () => {} });
async function digest(table, columns) {
  const [{ rows }] =
    await sql`select coalesce(jsonb_agg(to_jsonb(records) order by to_jsonb(records)::text),'[]'::jsonb) as rows from (select ${sql(columns)} from ${sql(table)}) records`;
  return {
    count: rows.length,
    sha256: createHash("sha256").update(JSON.stringify(rows)).digest("hex"),
  };
}
try {
  if (phase === "--seed-rerun") {
    await withLocalDemoWorldLock(
      status,
      process.env.MAILPIT_URL,
      async (coordinationSql) => {
        const options = {
          repositoryRoot: process.cwd(),
          status,
          mailpitUrl: process.env.MAILPIT_URL,
          coordinationSql,
          sessionPool: new Map(),
        };
        await seedLocalDemoWorld(options);
        await verifyLocalDemoWorld(options);
        const before = await snapshotDemoDomain(coordinationSql);
        await seedLocalDemoWorld(options);
        await verifyLocalDemoWorld(options);
        assert.deepEqual(
          await snapshotDemoDomain(coordinationSql),
          before,
          `${direction} upgrade converges without duplicate/replaced history on seed rerun.`,
        );
        console.log(
          `Populated ${direction} upgrade: explicit integrated seed/verify and unchanged rerun preserve all ${Object.keys(before).length} product tables.`,
        );
      },
    );
  } else {
    const columns =
      await sql`select table_schema||'.'||table_name as name, array_agg(column_name order by ordinal_position) as columns
    from information_schema.columns where table_schema in ('public','private') and table_name in
    (select c.relname from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname in ('public','private') and c.relkind='r') group by table_schema,table_name order by 1`;
    if (phase === "--before") {
      const record = {};
      for (const table of columns)
        record[table.name] = {
          columns: table.columns,
          ...(await digest(table.name, table.columns)),
        };
      for (const name of [
        "public.proposals",
        "public.project_memberships",
        "private.outbox_events",
        direction === "main"
          ? "private.project_participant_admissions"
          : "private.proposal_template_applications",
      ])
        assert.ok(
          record[name]?.count > 0,
          `Populated ${direction} rehearsal requires ${name}.`,
        );
      const migrations =
        await sql`select version from supabase_migrations.schema_migrations order by version`;
      const [{ sources }] =
        await sql`select count(*)::int as sources from public.proposals where published_at is not null`;
      await writeFile(
        checkpoint,
        JSON.stringify({
          record,
          migrations: migrations.map((m) => m.version),
          sources,
        }),
        { mode: 0o600 },
      );
      console.log(
        `Populated ${direction} checkpoint: ${columns.length} canonical tables, old-column digests only; no capabilities exported.`,
      );
    } else {
      const { record, migrations, sources } = JSON.parse(
        await readFile(checkpoint, "utf8"),
      );
      for (const [name, before] of Object.entries(record)) {
        assert.deepEqual(
          await digest(name, before.columns),
          { count: before.count, sha256: before.sha256 },
          `Every pre-upgrade column/row survives: ${name}`,
        );
        const added = columns
          .find((t) => t.name === name)
          .columns.filter((c) => !before.columns.includes(c));
        const expected =
          direction === "main" && name === "private.moderation_cases"
            ? [
                "target_proposal_template_id",
                "template_source_proposal_id",
                "template_report_content_version",
              ]
            : direction === "template" && name === "public.project_memberships"
              ? ["originating_participant_invitation_id"]
              : direction === "template" &&
                  name === "public.project_join_requests"
                ? ["resolution_reason", "superseded_by_membership_id"]
                : [];
        assert.deepEqual(
          added,
          expected,
          `Explicit new-column projection: ${name}`,
        );
        for (const column of added) {
          const [{ count }] =
            await sql`select count(*)::int as count from ${sql(name)} where ${sql(column)} is not null`;
          assert.equal(count, 0, `Legacy ${name}.${column} stays null.`);
        }
      }
      const applied = (
        await sql`select version from supabase_migrations.schema_migrations order by version`
      ).map((m) => m.version);
      assert.equal(new Set(applied).size, applied.length);
      assert.ok(migrations.every((version) => applied.includes(version)));
      const empty =
        direction === "main"
          ? [
              "private.proposal_template_baselines",
              "private.proposal_template_applications",
              "private.proposal_template_removal_actions",
              "private.proposal_draft_creations",
            ]
          : [
              "private.project_participant_invitations",
              "private.project_participant_invitation_secrets",
              "private.project_participant_admissions",
            ];
      for (const name of empty) {
        const [{ count }] =
          await sql`select count(*)::int as count from ${sql(name)}`;
        assert.equal(count, 0, `No invented historical records: ${name}`);
      }
      if (direction === "main") {
        const [{ count }] =
          await sql`select count(*)::int as count from private.proposal_templates`;
        assert.equal(
          count,
          sources,
          "Exactly once-published legacy sources gain identities.",
        );
      }
      await unlink(checkpoint);
      console.log(
        `Populated ${direction} → integrated passed: ${Object.keys(record).length} tables preserve all original columns/rows; nullable origin projection and no fabricated history verified.`,
      );
    }
  }
} finally {
  await sql.end({ timeout: 5 });
}
