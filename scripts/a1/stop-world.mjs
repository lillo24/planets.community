import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { openA1World } from "./owned-world.mjs";
const { directory, sql } = await openA1World(process.argv[2]);
await sql.end();
const environment = {
  ...process.env,
  ...JSON.parse(
    await readFile(path.join(directory, "private-environment.json"), "utf8"),
  ),
};
const result = spawnSync(
  process.execPath,
  [
    path.join(process.cwd(), "node_modules/supabase/dist/supabase.js"),
    "stop",
    "--no-backup",
    "--workdir",
    directory,
  ],
  {
    env: environment,
    encoding: "utf8",
    timeout: 300000,
    maxBuffer: 1024 * 1024,
  },
);
assert.equal(result.status, 0, "Stopping the exact owned A1 project failed.");
console.log("Stopped only the owned A1 backend.");
