import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import postgres from "postgres";

export async function openA1World(value) {
  assert.equal(process.env.PLANETS_DISPOSABLE_QA, "1");
  const directory = path.resolve(value);
  assert.equal(path.dirname(directory), os.tmpdir());
  assert.ok(path.basename(directory).startsWith("planets-a1-"));
  const config = await readFile(
    path.join(directory, "supabase/config.toml"),
    "utf8",
  );
  assert.ok(config.includes(`project_id = "a1-${path.basename(directory)}"`));
  const status = JSON.parse(
    await readFile(path.join(directory, "private-status.json"), "utf8"),
  );
  for (const [value, port] of [
    [status.databaseUrl, "61322"],
    [status.apiUrl, "61321"],
  ]) {
    assert.equal(new URL(value).hostname, "127.0.0.1");
    assert.equal(new URL(value).port, port);
  }
  const sql = postgres(status.databaseUrl, { max: 6, onnotice: () => {} });
  return { directory, status, sql };
}
export async function rpc(user, name, parameters = {}) {
  const { data, error } = await user.client.rpc(name, parameters);
  if (error) throw new Error(`A1 ${name} failed (${error.code}).`);
  return data;
}
