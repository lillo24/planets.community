import { ReleaseError } from "./errors.mjs";
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { readMigrations, migrationDiff, STAGING_REF } from "./migrations.mjs";
import { summarizeHistory } from "./backend.mjs";
import { sha256 } from "./sql-fingerprint.mjs";
import { execFileSync } from "node:child_process";

// Offline inspection of a bounded metadata export; never runs SQL or applies it.
const [input, output] = process.argv.slice(2);
if (!input || !output)
  throw new ReleaseError(
    "Usage: inventory.mjs REMOTE_STATEMENTS_JSON OUTPUT_JSON",
  );
const local = readMigrations(process.cwd());
const remote = summarizeHistory(JSON.parse(readFileSync(input, "utf8")));
const diff = migrationDiff(local, remote, STAGING_REF);
const pending = diff.pending.map((m) => {
  const canonical = local.find((item) => item.version === m.version);
  const routines = [
    ...canonical.sql.matchAll(
      /create\s+(?:or\s+replace\s+)?function\s+(?:public|private)\.([a-z_0-9]+)/gi,
    ),
  ].map((r) => r[1]);
  const tables = [
    ...canonical.sql.matchAll(
      /create\s+table\s+(?:public|private)\.([a-z_0-9]+)/gi,
    ),
  ].map((r) => r[1]);
  const category = m.name.startsWith("resource_cat01");
  const member =
    m.name.startsWith("member_contact") || m.name.startsWith("contact_report");
  return {
    ...m,
    prerequisites:
      local.indexOf(canonical) > 0
        ? [local[local.indexOf(canonical) - 1].version]
        : [],
    prerequisite_basis:
      "Conservative canonical release order; not a claim that every immediate predecessor is a direct SQL dependency",
    domain: category
      ? "resource categories/saved searches/maps"
      : member
        ? "Group-member personal contact/privacy/reporting"
        : "Groups/representative contact/discussions/coordination/messages",
    effects: {
      tables_created: [...new Set(tables)],
      routines_created_or_replaced: [...new Set(routines)],
      security: category
        ? "V2 RPC grants, category constraints/predicates; legacy calls retained; no backfill"
        : "Private RLS/grants, consent/history/reporting, locking and/or message projections; existing data must be preserved",
    },
    required_for_current_app_release: true,
    rollout_approval: category
      ? "RELEASE01 authorizes CAT01, subject to safety/rehearsal/recovery gates"
      : "Separate hosted backlog approval required; code merge is not deployment approval",
    policy_status: member
      ? "Scoped policy 3 approved 2026-10-20; hosted deployment still unapproved"
      : "See merged domain runbook; no new policy decision inferred",
  };
});
const report = {
  source_sha: execFileSync("git", ["rev-parse", "HEAD"], {
    encoding: "utf8",
  }).trim(),
  observed_at: process.env.RELEASE_INVENTORY_OBSERVED_AT ?? null,
  generated_at: new Date().toISOString(),
  ...diff,
  pending,
  approval_digest: sha256(JSON.stringify(diff)),
  comparison:
    "Token-exact SQL excluding exterior comments/whitespace/empty terminators; string and dollar-body contents preserved. Raw executed hashes are separate, not byte-identical source claims.",
  applied_history: remote.map((row) => ({
    ...row,
    canonical_sha256: local.find((m) => m.version === row.version)?.sha256,
  })),
};
mkdirSync(
  output.slice(0, Math.max(output.lastIndexOf("/"), output.lastIndexOf("\\"))),
  { recursive: true },
);
writeFileSync(output, JSON.stringify(report, null, 2) + "\n");
console.log(
  `Inventory: ${diff.applied} applied; ${pending.length} pending; ${diff.drift.length} drift; digest ${report.approval_digest}`,
);
