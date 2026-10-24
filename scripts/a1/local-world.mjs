// A1 owns exactly one new disposable local stack. No shared reset or activation.
import assert from "node:assert/strict";
import { randomBytes, randomUUID, generateKeyPairSync } from "node:crypto";
import { spawnSync } from "node:child_process";
import {
  cp,
  mkdir,
  mkdtemp,
  readFile,
  readdir,
  writeFile,
} from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { createServer } from "node:net";
import { parseLocalSupabaseStatus } from "../lib/local-supabase-status.mjs";

assert.equal(process.env.PLANETS_DISPOSABLE_QA, "1");
if (process.platform === "win32") {
  assert.equal(process.env.CONTAINER_CONNECTION, "planets-cocreate-qa-root");
  assert.equal(
    process.env.DOCKER_HOST,
    "npipe:////./pipe/podman-planets-cocreate-qa",
  );
} else {
  assert.ok(
    !process.env.DOCKER_HOST ||
      process.env.DOCKER_HOST === "unix:///var/run/docker.sock",
  );
}
const root = process.cwd();
for (const port of [61320, 61321, 61322, 61324]) {
  const server = createServer();
  await new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(port, "127.0.0.1", resolve);
  });
  await new Promise((resolve) => server.close(resolve));
}
const directory = await mkdtemp(path.join(os.tmpdir(), "planets-a1-"));
if (process.env.A1_WORLD_POINTER)
  await writeFile(process.env.A1_WORLD_POINTER, directory);
await mkdir(path.join(directory, "supabase/migrations"), { recursive: true });
for (const file of await readdir(path.join(root, "supabase/migrations"))) {
  // Real populated upgrade starts on the exact pre-A1 inventory.
  if (file.includes("a1_unified_private_conversations")) continue;
  await cp(
    path.join(root, "supabase/migrations", file),
    path.join(directory, "supabase/migrations", file),
  );
}
for (const entry of ["templates", "seed.sql"])
  await cp(
    path.join(root, "supabase", entry),
    path.join(directory, "supabase", entry),
    { recursive: true },
  );
const environment = {
  ...process.env,
  A1_PUBLIC: "sb_publishable_" + randomBytes(24).toString("base64url"),
  A1_SECRET: "sb_secret_" + randomBytes(32).toString("base64url"),
  A1_JWT: randomBytes(48).toString("base64url"),
};
let config = await readFile(path.join(root, "supabase/config.toml"), "utf8");
config = config
  .replace(
    'project_id = "planets-community"',
    `project_id = "a1-${path.basename(directory)}"`,
  )
  .replace(/\b543(\d\d)\b/g, (_, port) => String(61300 + Number(port)))
  .replace(
    /(\[auth\]\r?\n)/,
    '$1publishable_key = "env(A1_PUBLIC)"\nsecret_key = "env(A1_SECRET)"\njwt_secret = "env(A1_JWT)"\n',
  )
  .replace(
    '# signing_keys_path = "./signing_keys.json"',
    'signing_keys_path = "./signing_keys.json"',
  );
await writeFile(path.join(directory, "supabase/config.toml"), config);
const { privateKey } = generateKeyPairSync("ec", { namedCurve: "prime256v1" });
await writeFile(
  path.join(directory, "supabase/signing_keys.json"),
  JSON.stringify([
    {
      ...privateKey.export({ format: "jwk" }),
      kid: randomUUID(),
      alg: "ES256",
      use: "sig",
      key_ops: ["sign", "verify"],
    },
  ]),
);
await writeFile(
  path.join(directory, "private-environment.json"),
  JSON.stringify({
    A1_PUBLIC: environment.A1_PUBLIC,
    A1_SECRET: environment.A1_SECRET,
    A1_JWT: environment.A1_JWT,
  }),
);
console.log(`A1 owned local directory: ${directory}`);
const cli = path.join(root, "node_modules/supabase/dist/supabase.js");
function run(args) {
  const result = spawnSync(
    process.execPath,
    [cli, ...args, "--workdir", directory],
    {
      env: environment,
      encoding: "utf8",
      timeout: 900000,
      maxBuffer: 32 * 1024 * 1024,
    },
  );
  return result;
}
const started = run([
  "start",
  "-x",
  "studio,logflare,vector,imgproxy,supavisor,edge-runtime",
]);
await writeFile(
  path.join(directory, "private-start.log"),
  `${started.stdout}\n${started.stderr}`,
);
assert.equal(
  started.status,
  0,
  `A1 local startup failed; inspect ${directory}/private-start.log`,
);
const status = run(["status", "--output", "json"]);
assert.equal(status.status, 0);
const parsed = parseLocalSupabaseStatus(status.stdout);
assert.equal(new URL(parsed.databaseUrl).port, "61322");
await writeFile(
  path.join(directory, "private-status.json"),
  JSON.stringify(parsed),
);
console.log(
  "A1 predecessor ready on owned loopback API 61321 / database 61322.",
);
