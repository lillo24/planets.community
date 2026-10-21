// Explicit mock-only operator entrypoint for a network-capable owned CI host.
// No management token, permanent password, roster or normal credential is used.
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdtemp, writeFile, rm, mkdir } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { operator } from "./operator.mjs";
import { seed } from "./world.mjs";
import { verify } from "./verify.mjs";
import {
  MOCK_REF,
  MOCK_ORIGIN,
  NORMAL_ORIGIN,
  GENERATION,
  databaseTarget,
} from "./target.mjs";

assert.equal(process.env.GITHUB_ACTIONS, "true");
assert.equal(process.env.RUNNER_ENVIRONMENT, "github-hosted");
assert.equal(os.platform(), "linux");
assert.equal(process.env.GITHUB_REPOSITORY, "lillo24/planets.community");
const source = execFileSync("git", ["rev-parse", "HEAD"], {
  encoding: "utf8",
}).trim();
const input = JSON.parse(process.env.PLANETS_MOCK_OPERATOR ?? "null");
assert.equal(input?.source, source);
assert.equal(databaseTarget(input.databaseUrl).temporary, true);
assert.ok(
  Date.parse(input.expiresAt) > Date.now() + 30_000,
  "CLI login expired before setup",
);
assert.ok(
  typeof input.serviceKey === "string" &&
    /^sb_secret_[A-Za-z0-9_-]+$/.test(input.serviceKey),
  "Expected mock-only server credential",
);
// Mask each component as well as GitHub's complete JSON secret before any work.
for (const value of [
  input.databaseUrl,
  input.serviceKey,
  new URL(input.databaseUrl).password,
])
  process.stdout.write(`::add-mask::${value}\n`);
const privateDirectory = await mkdtemp(
  path.join(os.tmpdir(), "planets-mock-hosted-"),
);
const configPath = path.join(privateDirectory, "operator.json");
let context;
let phase = "target-guard";
let result;
try {
  await writeFile(
    configPath,
    JSON.stringify({
      projectRef: MOCK_REF,
      apiUrl: MOCK_ORIGIN,
      normalOrigin: NORMAL_ORIGIN,
      publishableKey: input.publishableKey,
    }),
    { mode: 0o600 },
  );
  process.env.MOCK_DATABASE_URL = input.databaseUrl;
  process.env.MOCK_SERVICE_ROLE_KEY = input.serviceKey;
  context = await operator(configPath);
  const marker = await context.guard();
  assert.equal(marker.enabled, false, "Hosted setup requires disabled access");
  phase = "migration-provenance";
  const applied =
    await context.sql`select name,sha256 from mock_control.applied_migrations order by name`;
  assert.deepEqual(
    applied.map((r) => ({ ...r })),
    context.inventory.migrations.map(({ name, sha256 }) => ({ name, sha256 })),
  );
  phase = "seed";
  await seed(context);
  phase = "read-only-verification";
  const verified = await verify(context);
  assert.equal(
    (await context.guard()).enabled,
    false,
    "Access changed during setup",
  );
  const [counts] =
    await context.sql`select (select count(*)::int from mock_control.personas) personas,(select count(*)::int from mock_control.testers where enrolled) enrolled`;
  result = {
    success: true,
    source,
    observedAt: new Date().toISOString(),
    projectRef: MOCK_REF,
    generation: GENERATION,
    schema: context.inventory.fingerprint,
    migrations: applied.length,
    ...verified,
    ...counts,
    enabled: false,
    enrollmentComplete: false,
    hostedTesterBrokerSmoke: false,
  };
} catch (error) {
  // Never export error messages, SQL text, connection strings or stack traces.
  result = {
    success: false,
    source,
    observedAt: new Date().toISOString(),
    projectRef: MOCK_REF,
    phase,
    code: /^[A-Z0-9_]{2,32}$/.test(error.code ?? "") ? error.code : null,
    fixtureFailure: /^Mock fixture [a-z_]+ failed \([A-Z0-9_]+\)\.$/.test(
      error.message ?? "",
    )
      ? error.message
      : null,
  };
  process.exitCode = 1;
} finally {
  await context?.sql.end({ timeout: 5 });
  delete process.env.MOCK_DATABASE_URL;
  delete process.env.MOCK_SERVICE_ROLE_KEY;
  await rm(privateDirectory, { recursive: true, force: true });
}
await mkdir("mock-hosted-evidence", { recursive: true });
await writeFile(
  "mock-hosted-evidence/setup.json",
  JSON.stringify(result, null, 2) + "\n",
);
console.log(JSON.stringify(result));
