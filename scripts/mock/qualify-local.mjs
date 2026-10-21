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
import { seed, PERSONAS, personaSessions } from "./world.mjs";
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
  if (name === "mock") {
    config = config.replaceAll("enable_signup = true", "enable_signup = false");
  }
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
  const signup = await fetch(`${mock.apiUrl}/auth/v1/signup`, {
    method: "POST",
    headers: {
      apikey: mock.publishableKey,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      email: "unsupported-signup@personas.planets.invalid",
      password: "synthetic-denied-signup-value",
    }),
  });
  equal(
    (await signup.json()).error_code,
    "signup_disabled",
    "Mock Auth rejects public signup at the server",
  );
  const authSettings = await (
    await fetch(`${mock.apiUrl}/auth/v1/settings`, {
      headers: { apikey: mock.publishableKey },
    })
  ).json();
  equal(
    authSettings.external.google,
    false,
    "Mock Google provider is disabled at the server",
  );
  const sql = postgres(mock.databaseUrl, { max: 4, onnotice: () => {} });
  const inventory = await migrationInventory(root);
  await sql.unsafe(await readFile("supabase/mock/marker.sql", "utf8"));
  await sql`insert into mock_control.environment(project_ref,generation,schema_fingerprint,operator_confirmed)
    values(${MOCK_REF},${GENERATION},${inventory.fingerprint},true)`;
  await sql.unsafe(await readFile("supabase/mock/control.sql", "utf8"));
  const [hookResult] =
    await sql`select mock_control.deny_external_auth_delivery('{}'::jsonb) as result`;
  equal(
    hookResult.result.error.http_code,
    403,
    "Auth delivery hook fails closed without sending mail/SMS",
  );
  const [hookPrivileges] = await sql`select
    has_function_privilege('authenticated','mock_control.deny_external_auth_delivery(jsonb)','execute') as ordinary,
    has_function_privilege('supabase_auth_admin','mock_control.deny_external_auth_delivery(jsonb)','execute') as auth,
    has_schema_privilege('supabase_auth_admin','mock_control','usage') as auth_usage`;
  equal(
    hookPrivileges.ordinary,
    false,
    "Ordinary users cannot invoke private Auth hook",
  );
  equal(
    hookPrivileges.auth,
    true,
    "Only Auth hook role receives execution permission",
  );
  equal(
    hookPrivileges.auth_usage,
    true,
    "Auth hook role can resolve only its explicitly granted schema/function",
  );
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
  // Rehearse retirement of populated legacy ownership controls with a genuine
  // ordinary persona session. These temporary historical tables are QA only.
  const legacyPeople = await personaSessions(context);
  const legacyAuth = await legacyPeople.giulia.client.auth.getSession();
  assert.equal(legacyAuth.error, null);
  assert.ok(legacyAuth.data.session);
  const legacySession = JSON.parse(
    Buffer.from(
      legacyAuth.data.session.access_token.split(".")[1],
      "base64url",
    ).toString(),
  ).session_id;
  await sql.unsafe(`create table mock_control.testers(issuer text,user_id uuid,enrolled boolean default true,primary key(issuer,user_id));
    create table mock_control.deliveries(issuer text,tester_id uuid,request_id uuid,session_id uuid,foreign key(issuer,tester_id) references mock_control.testers(issuer,user_id));
    create table mock_control.catalog_rate(issuer text,tester_id uuid,window_start timestamptz,requests integer);`);
  const legacyOwner = randomUUID();
  await sql`insert into mock_control.testers values('retired-fixture-issuer',${legacyOwner}::uuid,true)`;
  await sql`insert into mock_control.deliveries values('retired-fixture-issuer',${legacyOwner}::uuid,${randomUUID()}::uuid,${legacySession}::uuid)`;
  // Populate -> reinstall mock control -> repeat seed, preserving every product
  // row and every deliberately changed profile field.
  await sql.unsafe(await readFile("supabase/mock/control.sql", "utf8"));
  equal(
    Boolean((await legacyPeople.giulia.client.auth.refreshSession()).error),
    true,
    "Legacy mock ownership upgrade revokes its recorded session",
  );
  equal(
    (await sql`select to_regclass('mock_control.testers') as legacy`)[0].legacy,
    null,
    "Retired enrollment tables are absent",
  );
  for (const person of Object.values(legacyPeople))
    await person.client.auth.signOut({ scope: "local" });
  await seed(context);
  equal(
    await snapshot(),
    before,
    "Populated mock control upgrade and non-destructive repeat seed",
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
  await sql`update mock_control.environment set enabled=true`;
  const network = [];
  const handler = createRuntime({
    enabled: true,
    mockOrigin: MOCK_ORIGIN,
    service: mock.serviceRoleKey,
    deliveryKey: randomBytes(32).toString("base64"),
    fetcher: (url, init) => {
      const target = new URL(url);
      network.push({ origin: target.origin, path: target.pathname });
      assert.equal(target.origin, MOCK_ORIGIN, "No arbitrary destination");
      return fetch(url.replace(MOCK_ORIGIN, mock.apiUrl), init);
    },
  });
  const send = (capability, body, authorization = null) =>
    handler(
      new Request("http://localhost/ignored", {
        method: "POST",
        headers: {
          ...(capability ? { "x-mock-client": capability } : {}),
          ...(authorization
            ? { authorization: `Bearer ${authorization}` }
            : {}),
        },
        body: JSON.stringify(body),
      }),
    );
  async function bootstrap() {
    const response = await send(null, { action: "bootstrap" });
    equal(response.status, 200, "Guest bootstrap requires no normal identity");
    const value = await response.json();
    equal(
      /^[a-f0-9]{64}$/.test(value.capability),
      true,
      "Opaque random client capability",
    );
    return value.capability;
  }
  const clientOne = await bootstrap(),
    clientTwo = await bootstrap();
  equal(
    clientOne !== clientTwo,
    true,
    "Independent clients never share capabilities",
  );
  equal(
    (await send(null, { action: "catalog" })).status,
    401,
    "Request identity alone grants no recovery authority",
  );
  equal(
    (await send("f".repeat(64), { action: "catalog" })).status,
    403,
    "Unregistered capability denied",
  );
  equal(
    (await send(clientOne, { action: "catalog" })).status,
    200,
    "Guest catalog available",
  );
  const intent = {
    action: "issue",
    persona_key: "giulia",
    request_id: randomUUID(),
  };
  await sql`update auth.users set role='service_role' where id=${PERSONAS[0].id}::uuid`;
  equal(
    (await send(clientOne, intent)).status,
    403,
    "Privileged Auth role cannot become a selectable persona",
  );
  await sql`update auth.users set role='authenticated' where id=${PERSONAS[0].id}::uuid`;
  const response = await send(clientOne, intent);
  equal(response.status, 200, "Real broker issuance");
  const delivery = await response.json();
  equal(delivery.user_id, PERSONAS[0].id, "Exact persona account");
  const recovered = await send(clientOne, intent);
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
    accessToken: async () => normalSentinel.session.access_token,
  });
  equal(
    Boolean((await wrongMock.from("profiles").select("id")).error),
    true,
    "Normal bearer rejected by mock data API",
  );
  equal(
    (await send(clientOne, { action: "catalog" }, delivery.access_token))
      .status,
    401,
    "A persona bearer is not a client capability",
  );
  equal(
    (await send(clientOne, { ...intent, persona_key: "staff" })).status,
    403,
    "Unregistered staff persona denied",
  );
  equal(
    (await send(clientOne, { ...intent, persona_key: "marco" })).status,
    409,
    "Changed payload cannot reuse request",
  );
  const concurrentIntents = [
    { ...intent, request_id: randomUUID() },
    { ...intent, request_id: randomUUID() },
  ];
  const concurrentResponses = await Promise.all([
    send(clientOne, concurrentIntents[0]),
    send(clientTwo, concurrentIntents[1]),
  ]);
  for (let i = 0; i < 2; i++) {
    if (concurrentResponses[i].status === 409)
      concurrentResponses[i] = await send(
        i === 0 ? clientOne : clientTwo,
        concurrentIntents[i],
      );
    equal(
      concurrentResponses[i].status,
      200,
      "Simultaneous clients recover independent same-persona sessions",
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
    "One client local logout preserves another client",
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
  const cancelledIntent = { ...intent, request_id: randomUUID() };
  equal(
    (await send(clientOne, { ...cancelledIntent, action: "retire" })).status,
    200,
    "Cancel before server claim leaves a bounded tombstone",
  );
  equal(
    (await send(clientOne, cancelledIntent)).status,
    409,
    "Delayed issue cannot revive a cancelled request",
  );
  // Guessing another client's request can retire only the attacker's own
  // binding. It cannot retrieve or revoke the original client's delivery.
  equal(
    (await send(clientTwo, { ...intent, action: "retire" })).status,
    200,
    "Guessed request retirement is client-local",
  );
  const retained = await send(clientOne, intent);
  equal(retained.status, 200, "Original client retains its encrypted response");
  equal(
    (await retained.json()).refresh_token,
    delivery.refresh_token,
    "Guess cannot replace original delivery",
  );
  equal(
    (await send(clientOne, { ...concurrentIntents[1], action: "retire" }))
      .status,
    200,
    "Guessed live request retires only the caller binding",
  );
  equal(
    (await otherPersona.auth.refreshSession()).error,
    null,
    "Guessing a live request cannot revoke the other client session",
  );
  await sql`insert into mock_control.global_rate values('bootstrap',date_trunc('minute',now()),60)
    on conflict(kind) do update set window_start=excluded.window_start,requests=excluded.requests`;
  equal(
    (await send(null, { action: "bootstrap" })).status,
    429,
    "New capabilities cannot evade global limits",
  );
  await sql`delete from mock_control.global_rate where kind='bootstrap'`;
  await sql`select public.mock_control_shutdown()`;
  equal(
    (await send(null, { action: "bootstrap" })).status,
    403,
    "Shutdown denies old clients fresh capability issuance",
  );
  equal(
    (
      await send(clientTwo, {
        action: "issue",
        persona_key: "giulia",
        request_id: randomUUID(),
      })
    ).status,
    403,
    "Shutdown denies fresh persona sessions",
  );
  equal(
    Boolean((await otherPersona.auth.refreshSession()).error),
    true,
    "Shutdown revokes mock refresh sessions",
  );
  equal(
    (await normalSentinel.client.auth.refreshSession()).error,
    null,
    "Mock shutdown preserves normal account session",
  );
  equal(
    network.filter((n) => n.origin === NORMAL_ORIGIN).length,
    0,
    "Public broker never contacts normal Auth or product data",
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
  if (process.argv[2] === "--native") {
    await sql`update mock_control.environment set enabled=true`;
    const { nativeBridge } = await import("./native-bridge.mjs");
    await nativeBridge({
      directory: process.argv[3],
      normal,
      mock,
      sql,
      first,
      normalSentinel,
    });
  }
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
