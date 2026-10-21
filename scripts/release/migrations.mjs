import { ReleaseError } from "./errors.mjs";
import { readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";
import { sha256, sqlFingerprint } from "./sql-fingerprint.mjs";

export const STAGING_REF = "cllpvruvrrvxczjitlqd";
export function readMigrations(root) {
  const versions = new Set();
  return readdirSync(join(root, "supabase/migrations"))
    .sort()
    .map((file) => {
      const match = /^(\d{14})_([a-z0-9_]+)\.sql$/.exec(file);
      if (!match || versions.has(match[1]))
        throw new ReleaseError(`Invalid/duplicate migration: ${file}`);
      versions.add(match[1]);
      const sql = readFileSync(join(root, "supabase/migrations", file), "utf8");
      return {
        version: match[1],
        name: match[2],
        file,
        sha256: sha256(sql),
        fingerprint: sqlFingerprint(sql),
        sql,
      };
    });
}

export function migrationDiff(local, remote, projectRef) {
  if (projectRef !== STAGING_REF)
    throw new ReleaseError("Staging target mismatch");
  const byVersion = new Map(local.map((m) => [m.version, m]));
  const seen = new Set();
  const drift = [];
  for (const row of remote) {
    if (seen.has(row.version))
      throw new ReleaseError("Duplicate remote migration version");
    seen.add(row.version);
    const canonical = byVersion.get(row.version);
    if (!canonical) drift.push({ version: row.version, reason: "remote-only" });
    else if (
      canonical.name !== row.name ||
      canonical.fingerprint !== row.fingerprint
    ) {
      drift.push({
        version: row.version,
        reason: "executed SQL differs from canonical source",
      });
    }
  }
  const latest = [...seen].sort().at(-1) ?? "";
  const pending = local
    .filter((m) => !seen.has(m.version))
    .map(({ sql, ...m }) => ({ ...m, historical: m.version < latest }));
  const predecessor_sha256 = sha256(
    JSON.stringify(
      remote
        .map((row) => ({
          version: row.version,
          name: row.name,
          remote_sha256: row.remote_sha256,
          canonical_sha256: byVersion.get(row.version)?.sha256,
        }))
        .sort((a, b) => a.version.localeCompare(b.version)),
    ),
  );
  return {
    project_ref: projectRef,
    applied: remote.length,
    pending,
    drift,
    predecessor_sha256,
  };
}

export function deploymentSet(diff, policy, approvalDigest) {
  if (
    policy.project_ref !== STAGING_REF ||
    policy.migration_owner !== "github-actions"
  )
    throw new ReleaseError("Unapproved deployment owner/target");
  if (diff.drift.length)
    throw new ReleaseError("Migration history drift blocks deployment");
  if (!/^\d{14}$/.test(policy.bootstrap_boundary ?? ""))
    throw new ReleaseError("Missing reviewed bootstrap boundary");
  if (!diff.pending.length) return [];
  if (diff.pending.some((m) => m.version <= policy.bootstrap_boundary)) {
    // The digest binds approval to every byte and the exact observed predecessor.
    const digest = sha256(JSON.stringify(diff));
    if (
      approvalDigest !== digest ||
      !policy.recovery_reference ||
      !policy.rehearsal_reference
    )
      throw new ReleaseError(
        "Bootstrap needs exact manifest approval, recovery and populated rehearsal evidence",
      );
    if (
      diff.pending.some(
        (m) => policy.bootstrap_approvals?.[m.version] !== m.sha256,
      )
    )
      throw new ReleaseError("Unapproved historical backlog");
  } else if (diff.pending.some((m) => m.historical)) {
    throw new ReleaseError(
      "Unexpected historical backlog; reconcile separately",
    );
  }
  return diff.pending;
}

export function assertBackendReady(diff, checks) {
  if (
    diff.pending.length ||
    diff.drift.length ||
    checks.missing_rpcs.length ||
    checks.unsafe_tables.length ||
    !checks.storage_safe ||
    !checks.grants_safe ||
    !checks.map_safe
  ) {
    throw new ReleaseError(
      "Backend verification failed; Android build and Play upload are blocked",
    );
  }
}

export function requiredRpcs(root) {
  const names = new Set([
    "list_public_resource_listings_v2",
    "get_public_resource_listing_v2",
    "create_resource_listing_draft_v2",
    "create_editor_resource_listing_draft_v2",
    "update_own_resource_listing_v2",
    "get_own_resource_listing_v2",
    "list_own_resource_listings_v2",
    "create_resource_saved_search_v2",
    "update_resource_saved_search_v2",
    "get_own_resource_saved_search_v2",
    "list_own_resource_saved_searches_v2",
    "list_own_scoped_conversation_items_v7",
    "get_own_message_unread_summary_with_contacts_and_discussions",
  ]);
  function walk(dir) {
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
      const path = join(dir, entry.name);
      if (entry.isDirectory()) walk(path);
      else if (entry.name.endsWith(".dart")) {
        const source = readFileSync(path, "utf8");
        for (const match of source.matchAll(
          /\.rpc(?:<[^;]*?>)?\(\s*['"]([a-z][a-z0-9_]+)['"]/g,
        ))
          names.add(match[1]);
      }
    }
  }
  walk(join(root, "apps/mobile/lib"));
  return [...names].sort();
}

export function requiredEdgeFunctions(root) {
  const names = new Set([
    "map-provider",
    "location-search",
    "location-preview",
  ]);
  function walk(dir) {
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
      const path = join(dir, entry.name);
      if (entry.isDirectory()) walk(path);
      else if (entry.name.endsWith(".dart")) {
        const source = readFileSync(path, "utf8");
        for (const match of source.matchAll(
          /(?:functions\/v1\/|\.functions\.invoke\(\s*['"])([a-z][a-z0-9-]+)/g,
        ))
          names.add(match[1]);
      }
    }
  }
  walk(join(root, "apps/mobile/lib"));
  return [...names].sort();
}
