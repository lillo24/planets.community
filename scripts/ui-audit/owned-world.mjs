// Shared ownership checks for UIAUDIT01's disposable local fixture commands.
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { readFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import postgres from "postgres";
import { createClient } from "@supabase/supabase-js";
import { parseLocalSupabaseStatus } from "../lib/local-supabase-status.mjs";
import { migrationInventory, MOCK_REF, GENERATION } from "../mock/target.mjs";

export async function openOwnedWorld(value) {
  assert.equal(process.env.PLANETS_DISPOSABLE_QA, "1");
  const directory = path.resolve(value);
  assert.equal(path.dirname(directory), os.tmpdir());
  assert.ok(path.basename(directory).startsWith("planets-uiaudit01-"));
  const stacks = JSON.parse(
    await readFile(path.join(directory, "private-stacks.json"), "utf8"),
  );
  const owned = stacks.find((stack) => stack.name === "mock");
  assert.ok(owned, "Owned Mock stack manifest required");
  assert.equal(path.dirname(owned.directory), directory);
  const result = spawnSync(
    process.execPath,
    [
      "node_modules/supabase/dist/supabase.js",
      "status",
      "--output",
      "json",
      "--workdir",
      owned.directory,
    ],
    {
      env: { ...process.env, ...owned.environment },
      encoding: "utf8",
      timeout: 30000,
      maxBuffer: 1024 * 1024,
    },
  );
  assert.equal(result.status, 0, "Owned local CLI status required");
  const status = parseLocalSupabaseStatus(result.stdout);
  assert.equal(new URL(status.apiUrl).port, "59321");
  assert.equal(new URL(status.apiUrl).hostname, "127.0.0.1");
  const sql = postgres(status.databaseUrl, { max: 4, onnotice: () => {} });
  const inventory = await migrationInventory();
  const options = { auth: { persistSession: false, autoRefreshToken: false } };
  const context = {
    sql,
    guard: async () => {
      const [marker] =
        await sql`select project_ref,generation,schema_fingerprint from mock_control.environment`;
      assert.deepEqual(marker, {
        project_ref: MOCK_REF,
        generation: GENERATION,
        schema_fingerprint: inventory.fingerprint,
      });
    },
    client: () => createClient(status.apiUrl, status.publishableKey, options),
    admin: () => createClient(status.apiUrl, status.serviceRoleKey, options),
  };
  try {
    await context.guard();
  } catch (error) {
    await sql.end({ timeout: 5 });
    throw error;
  }
  return { directory, sql, context };
}
