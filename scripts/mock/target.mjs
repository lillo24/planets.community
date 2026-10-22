import { createHash } from "node:crypto";
import { readdir, readFile } from "node:fs/promises";

export const MOCK_REF = "pnolarmzxmmjtguligfc";
export const NORMAL_REF = "cllpvruvrrvxczjitlqd";
export const GENERATION = "mock-world-2026-10-21-v1";
export const MOCK_ORIGIN = `https://${MOCK_REF}.supabase.co`;
export const NORMAL_ORIGIN = `https://${NORMAL_REF}.supabase.co`;

// A session pooler is required: the seeder reserves a session advisory lock.
// The platform's short-lived CLI login inherits postgres through SET ROLE; it
// does not rotate the project's permanent password or normal staging secrets.
export function databaseTarget(value) {
  const url = new URL(value ?? "invalid:");
  const user = decodeURIComponent(url.username);
  const temporary = user === `cli_login_postgres.${MOCK_REF}`;
  if (
    !["postgres:", "postgresql:"].includes(url.protocol) ||
    !url.password ||
    url.search ||
    url.hash ||
    (url.port && url.port !== "5432") ||
    url.pathname !== "/postgres" ||
    !(
      (url.hostname === `db.${MOCK_REF}.supabase.co` && user === "postgres") ||
      (url.hostname.endsWith(".pooler.supabase.com") &&
        (user === `postgres.${MOCK_REF}` || temporary))
    )
  )
    throw new Error(
      "Database URL must address the exact mock session endpoint.",
    );
  return { temporary };
}

// Adding a new target requires review, never a --force argument or name match.
export function assertTarget(config, marker, fingerprint) {
  if (
    config.projectRef !== MOCK_REF ||
    config.apiUrl !== MOCK_ORIGIN ||
    config.normalOrigin !== NORMAL_ORIGIN ||
    config.apiUrl === config.normalOrigin ||
    marker?.project_ref !== MOCK_REF ||
    marker?.generation !== GENERATION ||
    marker?.schema_fingerprint !== fingerprint ||
    marker?.operator_confirmed !== true
  )
    throw new Error(
      "Mock target/marker/schema mismatch; no mutation permitted.",
    );
  return true;
}

export async function migrationInventory(root = process.cwd()) {
  const directory = `${root}/supabase/migrations`;
  const files = (await readdir(directory))
    .filter((p) => /^\d{14}_.+\.sql$/.test(p))
    .sort();
  const migrations = [];
  for (const name of files) {
    const source = (await readFile(`${directory}/${name}`, "utf8")).replaceAll(
      "\r\n",
      "\n",
    );
    migrations.push({
      name,
      sha256: createHash("sha256").update(source).digest("hex"),
    });
  }
  return {
    fingerprint: createHash("sha256")
      .update(JSON.stringify(migrations))
      .digest("hex"),
    migrations,
  };
}

export function publicKey(value) {
  if (
    typeof value !== "string" ||
    !/^sb_publishable_[A-Za-z0-9_-]{20,}$/.test(value)
  ) {
    throw new Error("A client-safe publishable key is required.");
  }
  return value;
}
