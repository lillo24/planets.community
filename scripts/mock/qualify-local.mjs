import assert from "node:assert/strict";
import {
  generateKeyPairSync,
  randomBytes,
  randomUUID,
  createHash,
} from "node:crypto";
import { spawnSync } from "node:child_process";
import { cp, mkdir, mkdtemp, readFile, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import postgres from "postgres";
import { createClient } from "@supabase/supabase-js";
import { parseLocalSupabaseStatus } from "../lib/local-supabase-status.mjs";
import {
  migrationInventory,
  MOCK_REF,
  GENERATION,
  NORMAL_ORIGIN,
  MOCK_ORIGIN,
} from "./target.mjs";
import { seed, PERSONAS } from "./world.mjs";
import { verify } from "./verify.mjs";
import { createRuntime } from "../../supabase/functions/mock-personas/runtime.mjs";

// Owns two NEW disposable loopback stacks. Never resets an existing workspace,
// contacts a hosted target, launches a device or prints CLI status/credentials.
assert.ok(
  process.env.CI === "true" || process.env.PLANETS_DISPOSABLE_QA === "1",
  "Explicit disposable QA required.",
);
const root = process.cwd();
const taskRoot = await mkdtemp(path.join(os.tmpdir(), "planets-mock-qa-"));
const stacks = [];
const stackSecrets = new Map();
let context;
let checks = 0;
function equal(a, b, label) {
  assert.deepEqual(a, b, label);
  checks++;
}
function run(cwd, args) {
  const result = spawnSync(
    path.join(root, "node_modules/.bin/supabase"),
    args,
    {
      cwd,
      env: { ...process.env, ...stackSecrets.get(cwd) },
      encoding: "utf8",
      shell: process.platform === "win32",
      timeout: 900000,
      maxBuffer: 32 * 1024 * 1024,
    },
  );
  if (result.status !== 0)
    throw new Error(
      `Disposable ${args[0]} failed (${result.error?.code ?? result.status}); private CLI output suppressed.`,
    );
  return result.stdout;
}
async function stack(name, offset) {
  const directory = path.join(taskRoot, name);
  await mkdir(path.join(directory, "supabase"), { recursive: true });
  for (const entry of ["migrations", "templates", "seed.sql"])
    await cp(
      path.join(root, "supabase", entry),
      path.join(directory, "supabase", entry),
      { recursive: true },
    );
  let config = await readFile(path.join(root, "supabase/config.toml"), "utf8");
  // Pinned CLI v2.118.0-beta.39 generates asymmetric JWTs from signing_keys_path,
  // but opaque API keys otherwise remain shared local defaults. Its auth config
  // supports Secret env references for these three values (pkg/config/auth.go).
  stackSecrets.set(directory, {
    MOCK_QA_PUBLISHABLE_KEY:
      "sb_publishable_" + randomBytes(24).toString("base64url"),
    MOCK_QA_SECRET_KEY: "sb_secret_" + randomBytes(32).toString("base64url"),
    MOCK_QA_JWT_SECRET: randomBytes(48).toString("base64url"),
  });
  config = config.replace(
    /(\[auth\]\r?\n)/,
    '$1publishable_key = "env(MOCK_QA_PUBLISHABLE_KEY)"\nsecret_key = "env(MOCK_QA_SECRET_KEY)"\njwt_secret = "env(MOCK_QA_JWT_SECRET)"\n',
  );
  config = config
    .replace(
      'project_id = "planets-community"',
      `project_id = "mock-qa-${name}-${path.basename(taskRoot)}"`,
    )
    .replace(/\b543(\d\d)\b/g, (_, port) =>
      String(54300 + Number(port) + offset),
    )
    .replace(
      '# signing_keys_path = "./signing_keys.json"',
      'signing_keys_path = "./signing_keys.json"',
    );
  const { privateKey } = generateKeyPairSync("ec", {
    namedCurve: "prime256v1",
  });
  const jwk = {
    ...privateKey.export({ format: "jwk" }),
    kid: randomUUID(),
    alg: "ES256",
    use: "sig",
    key_ops: ["sign", "verify"],
  };
  await writeFile(
    path.join(directory, "supabase/signing_keys.json"),
    JSON.stringify([jwk]),
    { mode: 0o600 },
  );
  await writeFile(path.join(directory, "supabase/config.toml"), config);
  stacks.push(directory);
  console.log(
    `Starting owned ${name} realm (private signing key, no hosted access).`,
  );
  run(directory, [
    "start",
    "-x",
    "studio,logflare,vector,imgproxy,supavisor,edge-runtime",
  ]);
  const status = parseLocalSupabaseStatus(
    run(directory, ["status", "--output", "json"]),
  );
  for (const endpoint of [status.apiUrl, status.databaseUrl])
    assert.ok(
      ["127.0.0.1", "localhost", "[::1]"].includes(new URL(endpoint).hostname),
    );
  return { ...status, directory };
}
const options = {
  auth: {
    persistSession: false,
    autoRefreshToken: false,
    detectSessionInUrl: false,
  },
};
async function login(status, id, email) {
  const admin = createClient(status.apiUrl, status.serviceRoleKey, options);
  const created = await admin.auth.admin.createUser({
    id,
    email,
    email_confirm: true,
  });
  assert.equal(created.error, null, "Create synthetic ordinary Auth identity");
  const link = await admin.auth.admin.generateLink({
    type: "magiclink",
    email,
  });
  assert.equal(
    link.error,
    null,
    "Generate one-time login, without sending email",
  );
  const client = createClient(status.apiUrl, status.publishableKey, options);
  const result = await client.auth.verifyOtp({
    type: "magiclink",
    token_hash: link.data.properties.hashed_token,
  });
  assert.equal(result.error, null, "Genuine standard Auth session");
  return { id, client, session: result.data.session };
}

try {
  const normal = await stack("normal", 1000),
    mock = await stack("mock", 2000);
  equal(
    normal.publishableKey !== mock.publishableKey,
    true,
    "Independent public API credentials",
  );
  equal(
    normal.serviceRoleKey !== mock.serviceRoleKey,
    true,
    "Independent administrative credentials",
  );
  const sql = postgres(mock.databaseUrl, { max: 4, onnotice: () => {} });
  const inventory = await migrationInventory(root);
  await sql.unsafe(await readFile("supabase/mock/marker.sql", "utf8"));
  await sql`insert into mock_control.environment(project_ref,generation,schema_fingerprint,operator_confirmed)
    values(${MOCK_REF},${GENERATION},${inventory.fingerprint},true)`;
  await sql.unsafe(await readFile("supabase/mock/control.sql", "utf8"));
  context = {
    sql,
    guard: async (tx = sql) => {
      const [row] =
        await tx`select project_ref,generation,schema_fingerprint from mock_control.environment`;
      equal(
        row,
        {
          project_ref: MOCK_REF,
          generation: GENERATION,
          schema_fingerprint: inventory.fingerprint,
        },
        "Local cloned control marker",
      );
    },
    client: () => createClient(mock.apiUrl, mock.publishableKey, options),
    admin: () => createClient(mock.apiUrl, mock.serviceRoleKey, options),
  };
  console.log("Creating canonical mock fixtures.");
  const first = await seed(context);
  console.log("Reading canonical fixture verification.");
  const verification = await verify(context);
  checks += verification.checks;
  async function snapshot() {
    const names =
      await sql`select n.nspname||'.'||c.relname as name from pg_class c join pg_namespace n on n.oid=c.relnamespace
      where n.nspname in ('public','private') and c.relkind='r' and c.relname<>'spatial_ref_sys' order by 1`;
    const hashes = {};
    for (const { name } of names) {
      const [row] = await sql.unsafe(
        `select coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text),'[]'::jsonb)::text as rows from ${name} t`,
      );
      hashes[name] = createHash("sha256").update(row.rows).digest("hex");
    }
    return hashes;
  }
  console.log("Checking populated control replay and repeat seed.");
  const before = await snapshot();
  // Populate -> reinstall mock control -> repeat seed, preserving every product
  // row and every deliberately changed profile field.
  await sql.unsafe(await readFile("supabase/mock/control.sql", "utf8"));
  await seed(context);
  equal(
    await snapshot(),
    before,
    "Populated mock control upgrade and non-destructive repeat seed",
  );
  const tester = await login(
    normal,
    randomUUID(),
    "tester-one@planets.invalid",
  );
  const other = await login(normal, randomUUID(), "tester-two@planets.invalid");
  const outsider = await login(
    normal,
    randomUUID(),
    "not-enrolled@planets.invalid",
  );
  const normalSentinel = await login(
    normal,
    PERSONAS[0].id,
    "normal-sentinel@planets.invalid",
  );
  const anchor = await normalSentinel.client
    .from("profiles")
    .insert({ id: normalSentinel.id });
  equal(anchor.error, null, "Overlapping normal profile ID");
  const updated = await normalSentinel.client.rpc(
    "update_own_profile_content_v1",
    {
      p_expected_profile_id: normalSentinel.id,
      p_display_name: "NORMAL ONLY SENTINEL",
      p_bio: "Normal realm sentinel",
      p_skill_ids: [],
    },
  );
  equal(updated.error, null, "Normal-only sentinel");
  const issuer = `${NORMAL_ORIGIN}/auth/v1`;
  for (const person of [tester, other])
    await sql`insert into mock_control.testers(issuer,user_id) values(${issuer},${person.id}::uuid)`;
  await sql`update mock_control.environment set enabled=true`;
  const network = [];
  const handler = createRuntime({
    enabled: true,
    normalOrigin: NORMAL_ORIGIN,
    mockOrigin: MOCK_ORIGIN,
    normalKey: normal.publishableKey,
    service: mock.serviceRoleKey,
    deliveryKey: randomBytes(32).toString("base64"),
    fetcher: (url, init) => {
      const target = new URL(url);
      network.push({ origin: target.origin, path: target.pathname });
      if (target.origin === NORMAL_ORIGIN) {
        assert.equal(
          target.pathname,
          "/auth/v1/user",
          "Only normal Auth control verification",
        );
        return fetch(url.replace(NORMAL_ORIGIN, normal.apiUrl), init);
      }
      assert.equal(target.origin, MOCK_ORIGIN, "No arbitrary destination");
      return fetch(url.replace(MOCK_ORIGIN, mock.apiUrl), init);
    },
  });
  const send = (person, body, token = person?.session.access_token) =>
    handler(
      new Request("http://localhost/ignored", {
        method: "POST",
        headers: { authorization: token ? `Bearer ${token}` : "" },
        body: JSON.stringify(body),
      }),
    );
  equal(
    (await send(null, { action: "catalog" })).status,
    401,
    "No Auth denied",
  );
  equal(
    (await send(outsider, { action: "catalog" })).status,
    403,
    "Non-tester denied",
  );
  equal(
    (await send(tester, { action: "catalog" })).status,
    200,
    "Enrolled catalog",
  );
  const intent = {
    action: "issue",
    persona_key: "giulia",
    request_id: randomUUID(),
  };
  const response = await send(tester, intent);
  equal(response.status, 200, "Real broker issuance");
  const delivery = await response.json();
  equal(delivery.user_id, PERSONAS[0].id, "Exact persona account");
  const recovered = await send(tester, intent);
  equal(recovered.status, 200, "Lost-response recovery");
  equal(
    (await recovered.json()).refresh_token === delivery.refresh_token,
    true,
    "Recovery returns original session, no rotation",
  );
  const persona = createClient(mock.apiUrl, mock.publishableKey, options);
  const installed = await persona.auth.setSession({
    access_token: delivery.access_token,
    refresh_token: delivery.refresh_token,
  });
  equal(installed.error, null, "Standard client installation");
  const actual = await persona
    .from("profiles")
    .select("id,display_name")
    .eq("id", PERSONAS[0].id)
    .single();
  equal(
    actual.data?.display_name,
    "Giulia",
    "Same UUID resolves only mock sentinel",
  );
  const wrongNormal = createClient(normal.apiUrl, normal.publishableKey, {
    ...options,
    accessToken: async () => delivery.access_token,
  });
  equal(
    Boolean((await wrongNormal.from("profiles").select("id")).error),
    true,
    "Mock bearer rejected by normal data API",
  );
  const wrongMock = createClient(mock.apiUrl, mock.publishableKey, {
    ...options,
    accessToken: async () => tester.session.access_token,
  });
  equal(
    Boolean((await wrongMock.from("profiles").select("id")).error),
    true,
    "Normal bearer rejected by mock data API",
  );
  equal(
    (await send(tester, { action: "catalog" }, delivery.access_token)).status,
    403,
    "Persona cannot act as normal tester",
  );
  equal(
    (await send(tester, { ...intent, persona_key: "staff" })).status,
    403,
    "Unregistered staff persona denied",
  );
  equal(
    (await send(tester, { ...intent, persona_key: "marco" })).status,
    409,
    "Changed payload cannot reuse request",
  );
  const concurrentIntents = [
    { ...intent, request_id: randomUUID() },
    { ...intent, request_id: randomUUID() },
  ];
  const concurrentResponses = await Promise.all([
    send(tester, concurrentIntents[0]),
    send(other, concurrentIntents[1]),
  ]);
  for (let i = 0; i < 2; i++) {
    if (concurrentResponses[i].status === 409)
      concurrentResponses[i] = await send(
        i === 0 ? tester : other,
        concurrentIntents[i],
      );
    equal(
      concurrentResponses[i].status,
      200,
      "Simultaneous testers recover independent same-persona sessions",
    );
  }
  const deliveryA = await concurrentResponses[0].json();
  const delivery2 = await concurrentResponses[1].json();
  equal(
    delivery2.refresh_token !== delivery.refresh_token,
    true,
    "Independent refresh sessions",
  );
  const otherPersona = createClient(mock.apiUrl, mock.publishableKey, options);
  await otherPersona.auth.setSession({
    access_token: delivery2.access_token,
    refresh_token: delivery2.refresh_token,
  });
  await persona.auth.signOut({ scope: "local" });
  const candidateA = createClient(mock.apiUrl, mock.publishableKey, options);
  await candidateA.auth.setSession({
    access_token: deliveryA.access_token,
    refresh_token: deliveryA.refresh_token,
  });
  await candidateA.auth.signOut({ scope: "local" });
  equal(
    (await otherPersona.auth.refreshSession()).error,
    null,
    "One tester local logout preserves other tester",
  );
  equal(
    Boolean(
      (
        await otherPersona.auth.updateUser({
          password: "synthetic-never-log-this-password",
        })
      ).error,
    ),
    true,
    "Server rejects shared persona password mutation",
  );
  equal(
    Boolean(
      (await otherPersona.auth.updateUser({ email: "seizure@planets.invalid" }))
        .error,
    ),
    true,
    "Server rejects persona email change",
  );
  equal(
    Boolean(
      (
        await otherPersona.auth.mfa.enroll({
          factorType: "totp",
          friendlyName: "unsupported",
        })
      ).error,
    ),
    true,
    "Server rejects fixture MFA enrollment",
  );
  await sql`select public.mock_control_offboard(${issuer},${other.id}::uuid)`;
  const cancelledIntent = { ...intent, request_id: randomUUID() };
  equal(
    (await send(tester, { ...cancelledIntent, action: "retire" })).status,
    200,
    "Cancel before server claim leaves a bounded tombstone",
  );
  equal(
    (await send(tester, cancelledIntent)).status,
    409,
    "Delayed issue cannot revive a cancelled request",
  );
  equal(
    (await send(other, { action: "catalog" })).status,
    403,
    "Revoked tester loses cached catalog authority",
  );
  equal(
    Boolean((await otherPersona.auth.refreshSession()).error),
    true,
    "Offboarding revokes only issued refresh session",
  );
  console.log(
    JSON.stringify({
      checks,
      sourceSchema: inventory.fingerprint,
      personas: first.personas,
      normalCalls: network.filter((n) => n.origin === NORMAL_ORIGIN).length,
      success: true,
    }),
  );
} catch (error) {
  console.error(
    `Mock two-realm qualification failed at ${error.message?.replace(/[^a-zA-Z0-9 ._:()/-]/g, "").slice(0, 180) ?? "unknown step"}`,
  );
  process.exitCode = 1;
} finally {
  await context?.sql.end();
  for (const directory of stacks.reverse()) {
    try {
      run(directory, ["stop", "--no-backup"]);
    } catch {
      console.error("Owned QA stack cleanup failed.");
      process.exitCode = 1;
    }
  }
  // Retain only private local recovery files; no recursive delete or broad prune.
}
