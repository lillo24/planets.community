import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { openA1World } from "./owned-world.mjs";
import { applyParticipationRpcNullability } from "../lib/participation-rpc-nullability.mjs";

const { directory, sql } = await openA1World(process.argv[2]);
await sql.end();
const mode = process.argv[3],
  root = process.cwd();
const commands = {
  reset: ["db", "reset", "--local"],
  test: ["test", "db", path.join(root, "supabase/tests")],
  lint: [
    "db",
    "lint",
    "--local",
    "--schema",
    "public,private",
    "--level",
    "warning",
    "--fail-on",
    "warning",
  ],
  advisors: [
    "db",
    "advisors",
    "--local",
    "--type",
    "security",
    "--level",
    "warn",
    "--fail-on",
    "error",
  ],
  types: ["gen", "types", "typescript", "--local", "--schema", "public"],
};
assert.ok(Object.hasOwn(commands, mode));
const environment = {
  ...process.env,
  ...JSON.parse(
    await readFile(path.join(directory, "private-environment.json"), "utf8"),
  ),
};
const result = spawnSync(
  process.execPath,
  [
    path.join(root, "node_modules/supabase/dist/supabase.js"),
    ...commands[mode],
    "--workdir",
    directory,
  ],
  {
    env: environment,
    encoding: "utf8",
    timeout: 1800000,
    maxBuffer: 64 * 1024 * 1024,
  },
);
await writeFile(
  path.join(directory, `private-${mode}.log`),
  `${result.stdout ?? ""}\n${result.stderr ?? ""}`,
);
assert.equal(
  result.status,
  0,
  `A1 owned ${mode} failed; inspect ${directory}/private-${mode}.log`,
);
if (mode === "types") {
  assert.ok(result.stdout.includes("export type Database"));
  await writeFile(
    path.join(root, "apps/web/src/types/database.generated.ts"),
    applyParticipationRpcNullability(result.stdout.trimEnd()) + "\n",
  );
}
console.log(`A1 owned ${mode} passed.`);
if (mode === "test")
  console.log(
    result.stdout
      .split("\n")
      .filter((s) => /Files=|Tests=|Result:/.test(s))
      .join("\n"),
  );
