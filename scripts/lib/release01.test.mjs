import test from "node:test";
import assert from "node:assert/strict";
import {
  mkdtempSync,
  mkdirSync,
  readFileSync,
  writeFileSync,
  existsSync,
  rmSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";
import {
  readMigrations,
  migrationDiff,
  deploymentSet,
  assertBackendReady,
  STAGING_REF,
  requiredEdgeFunctions,
} from "../release/migrations.mjs";
import { sqlFingerprint, sha256 } from "../release/sql-fingerprint.mjs";
import {
  summarizeHistory,
  managementClient,
  verificationQuery,
  verifyFunctions,
  publicSmoke,
} from "../release/backend.mjs";
import { assertDatabaseUrl } from "../release/staging.mjs";
import {
  selectTrack,
  allocateCode,
  publishBundle,
  playAccessToken,
  playClient,
} from "../release/play.mjs";
import { manualCode, prepareSigning } from "../release/android.mjs";
import { requireFullValidation } from "../release/validation.mjs";
import { verifyPersistedArtifact } from "../release/publish.mjs";

const sql = "create table private.example(id integer);";
const migration = {
  version: "20261021155653",
  name: "example",
  file: "20261021155653_example.sql",
  sha256: sha256(sql),
  fingerprint: sqlFingerprint(sql),
  sql,
};
const remote = summarizeHistory([
  { version: migration.version, name: migration.name, statements: [sql] },
]);
const diff = migrationDiff([migration], [], STAGING_REF);
const policy = {
  project_ref: STAGING_REF,
  migration_owner: "github-actions",
  bootstrap_boundary: migration.version,
  bootstrap_approvals: { [migration.version]: migration.sha256 },
  recovery_reference: "owned encrypted backup with restore rehearsal",
  rehearsal_reference: "populated CI evidence",
};
const ready = {
  missing_rpcs: [],
  unsafe_tables: [],
  storage_safe: true,
  grants_safe: true,
  map_safe: true,
};
const playPolicy = {
  package: "community.planets.app",
  closed_track: "alpha",
  closed_track_verified_reference: "Console evidence",
  historical_version_code_floor: 12,
};
const tracks = [
  {
    track: "production",
    releases: [{ status: "completed", versionCodes: ["6"] }],
  },
  {
    track: "alpha",
    releases: [
      {
        status: "completed",
        versionCodes: ["12"],
        countryTargeting: { countries: ["IT"] },
      },
    ],
  },
];

test("migration lexer preserves literal/body content, token boundaries and statement boundaries", () => {
  assert.equal(
    sqlFingerprint(
      "-- comment\n select 1; /* outer /* inner */ done */ select 'x';",
    ),
    sqlFingerprint("select 1 ; select 'x'"),
  );
  for (const [a, b] of [
    ["select 'a b'", "select 'ab'"],
    ["select ab", "select a b"],
    ["select $$--x\na$$", "select $$--x\nb$$"],
    ["select 1; select 2", "select 1 select 2"],
    ["select 'a;';", "select 'a'"],
    ['select "x y"', 'select "xy"'],
  ])
    assert.notEqual(sqlFingerprint(a), sqlFingerprint(b));
  assert.equal(
    sqlFingerprint("select E'a\\\'b';"),
    sqlFingerprint("select E'a\\\'b'"),
  );
  for (const s of ["select 'x", "select $$x", "/* x"])
    assert.throws(() => sqlFingerprint(s));
});

test("migration diff detects earlier timestamp, unexpected remote, modified history and target mismatch", () => {
  assert.equal(
    migrationDiff(
      [migration],
      [...remote, { ...remote[0], version: "20261022100000" }],
      STAGING_REF,
    ).drift[0].reason,
    "remote-only",
  );
  assert.equal(
    migrationDiff(
      [migration],
      [{ ...remote[0], fingerprint: "changed" }],
      STAGING_REF,
    ).drift.length,
    1,
  );
  assert.equal(
    migrationDiff(
      [migration],
      [{ ...remote[0], version: "20261022100000" }],
      STAGING_REF,
    ).pending[0].historical,
    true,
  );
  assert.throws(
    () => migrationDiff([migration], remote, "other-project"),
    /target/,
  );
  assert.throws(
    () => migrationDiff([migration], [...remote, ...remote], STAGING_REF),
    /Duplicate/,
  );
});

test("migration source rejects duplicate versions and unexpected files", () => {
  const root = mkdtempSync(join(tmpdir(), "release01-source-"));
  try {
    mkdirSync(join(root, "supabase/migrations"), { recursive: true });
    writeFileSync(join(root, "supabase/migrations", migration.file), sql);
    assert.equal(readMigrations(root)[0].sha256, migration.sha256);
    writeFileSync(
      join(root, "supabase/migrations", "20261021155653_other.sql"),
      sql,
    );
    assert.throws(() => readMigrations(root), /duplicate/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("bootstrap binds every hash and exact predecessor to approval/recovery/rehearsal", () => {
  const approval = sha256(JSON.stringify(diff));
  assert.deepEqual(deploymentSet(diff, policy, approval), diff.pending);
  for (const candidate of [
    { ...policy, bootstrap_boundary: null },
    { ...policy, bootstrap_approvals: {} },
    { ...policy, recovery_reference: null },
    { ...policy, rehearsal_reference: null },
    { ...policy, migration_owner: "native-integration" },
  ])
    assert.throws(() => deploymentSet(diff, candidate, approval));
  assert.throws(() => deploymentSet(diff, policy, "stale"), /Bootstrap/);
  assert.throws(
    () =>
      deploymentSet(
        { ...diff, predecessor_sha256: "changed" },
        policy,
        approval,
      ),
    /Bootstrap/,
  );
  assert.throws(
    () => deploymentSet({ ...diff, drift: [{}] }, policy, approval),
    /drift/,
  );
  assert.deepEqual(
    deploymentSet(
      migrationDiff([migration], remote, STAGING_REF),
      policy,
      "stale",
    ),
    [],
  );
});

test("routine deployment rejects historical gaps even after bootstrap", () => {
  const reconciled = {
    ...policy,
    bootstrap_boundary: "20261020150706",
  };
  assert.equal(deploymentSet(diff, reconciled).length, 1);
  assert.throws(
    () =>
      deploymentSet(
        { ...diff, pending: [{ ...diff.pending[0], historical: true }] },
        reconciled,
      ),
    /historical/,
  );
  assert.throws(
    () =>
      deploymentSet(diff, {
        ...reconciled,
        bootstrap_boundary: "20261022100000",
      }),
    /Bootstrap/,
  );
  // Completion is inferred from live applied history, with no manual flag flip.
  assert.deepEqual(deploymentSet({ ...diff, pending: [] }, policy), []);
});

test("every backend failure blocks Android, and verify SQL includes current category/message contracts", () => {
  const clean = { ...diff, pending: [] };
  assert.doesNotThrow(() => assertBackendReady(clean, ready));
  for (const checks of [
    { ...ready, missing_rpcs: ["missing"] },
    { ...ready, unsafe_tables: ["private.bad"] },
    { ...ready, storage_safe: false },
    { ...ready, grants_safe: false },
    { ...ready, map_safe: false },
  ])
    assert.throws(() => assertBackendReady(clean, checks), /blocked/);
  assert.throws(() => assertBackendReady(diff, ready), /blocked/);
  const query = verificationQuery(process.cwd(), true);
  for (const name of [
    "list_public_resource_listings_v2",
    "list_own_scoped_conversation_items_v7",
    "map_baseline_config",
    "relrowsecurity",
  ])
    assert.ok(query.includes(name));
});

test("DB URL rejects localhost, other projects, deceptive hosts and missing secrets", () => {
  assert.match(
    assertDatabaseUrl(
      `postgres://postgres:synthetic@db.${STAGING_REF}.supabase.co/postgres?sslmode=disable`,
    ),
    /sslmode=verify-full$/,
  );
  for (const value of [
    undefined,
    "postgres://postgres:secret@localhost/postgres",
    `postgres://postgres:secret@db.${STAGING_REF}.supabase.co.evil.test/postgres`,
    `postgres://postgres.other:secret@aws-1-eu-west-1.pooler.supabase.com/postgres`,
  ])
    assert.throws(() => assertDatabaseUrl(value));
  assert.doesNotThrow(() =>
    assertDatabaseUrl(
      `postgres://postgres:synthetic@db.${STAGING_REF}.supabase.co/postgres`,
    ),
  );
  assert.doesNotThrow(() =>
    assertDatabaseUrl(
      `postgres://postgres.${STAGING_REF}:synthetic@aws-1-eu-west-1.pooler.supabase.com/postgres`,
    ),
  );
});

test("missing deployment credentials fail before any request; errors never forward provider body", async () => {
  assert.throws(() => managementClient(""), /SUPABASE_ACCESS_TOKEN/);
  const calls = [];
  const api = managementClient("synthetic", async (url, init) => {
    calls.push({ url, init });
    return new Response(JSON.stringify({ secret: "must not log" }), {
      status: 403,
    });
  });
  await assert.rejects(
    api.query("select 1"),
    (e) => e.message.includes("403") && !e.message.includes("must not log"),
  );
  assert.equal(JSON.parse(calls[0].init.body).read_only, true);
  assert.ok(calls[0].url.includes(STAGING_REF));
});

test("changed deployed Edge bundle or unreviewed source blocks delivery", () => {
  const p = JSON.parse(readFileSync("scripts/release/policy.json", "utf8"));
  const functions = p.approved_functions.map((f) => ({
    ...f,
    status: "ACTIVE",
  }));
  assert.equal(verifyFunctions(process.cwd(), p, functions), true);
  assert.equal(
    verifyFunctions(
      process.cwd(),
      p,
      functions.map((f) => ({ ...f, version: f.version + 1 })),
    ),
    false,
  );
  assert.equal(
    verifyFunctions(
      process.cwd(),
      {
        ...p,
        approved_function_source_sha256: { "map-provider/index.ts": "changed" },
      },
      functions,
    ),
    false,
  );
});

test("a newly added mobile Edge dependency cannot pass an older release policy", () => {
  const root = mkdtempSync(join(tmpdir(), "release01-edge-"));
  try {
    mkdirSync(join(root, "apps/mobile/lib"), { recursive: true });
    writeFileSync(
      join(root, "apps/mobile/lib/compat.dart"),
      "final uri = base.resolve('functions/v1/client-compatibility');",
    );
    assert.ok(requiredEdgeFunctions(root).includes("client-compatibility"));
    const p = JSON.parse(readFileSync("scripts/release/policy.json", "utf8"));
    assert.equal(
      verifyFunctions(
        root,
        p,
        p.approved_functions.map((f) => ({ ...f, status: "ACTIVE" })),
      ),
      false,
    );
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("hosted HTTP smoke checks legacy/V2/validation/privacy without retaining returned content", async () => {
  const config = JSON.stringify({
    SUPABASE_URL: `https://${STAGING_REF}.supabase.co`,
    SUPABASE_PUBLISHABLE_KEY: "sb_publishable_" + "a".repeat(24),
  });
  const results = [
    new Response('[{"title":"must not retain"}]'),
    new Response("[]"),
    new Response('{"code":"22023","details":"private"}', { status: 400 }),
    new Response('{"code":"42501"}', { status: 401 }),
  ];
  const calls = [];
  const checks = await publicSmoke(config, async (url, init) => {
    calls.push({ url, init });
    return results.shift();
  });
  assert.equal(checks.length, 4);
  assert.equal(JSON.stringify(checks).includes("must not retain"), false);
  assert.ok(
    calls.every((c) =>
      c.url.startsWith(`https://${STAGING_REF}.supabase.co/rest/v1/rpc/`),
    ),
  );
  await assert.rejects(
    publicSmoke(
      config,
      async () => new Response('{"code":"PGRST202"}', { status: 404 }),
    ),
    /smoke failed/,
  );
});

test("disposable rehearsal refuses ordinary local execution before touching a stack", () => {
  const result = spawnSync(process.execPath, ["scripts/release/rehearse.mjs"], {
    encoding: "utf8",
    env: {
      ...process.env,
      GITHUB_ACTIONS: "false",
      PLANETS_DISPOSABLE_QA: "1",
    },
  });
  assert.equal(result.status, 1);
  assert.match(
    result.stderr,
    /requires its isolated disposable Linux Actions workspace/,
  );
});

test("Play requires exact existing closed track and preserves pending owner work", () => {
  assert.equal(selectTrack(tracks, playPolicy).track, "alpha");
  for (const p of [
    { ...playPolicy, closed_track: "production" },
    { ...playPolicy, closed_track: "internal" },
    { ...playPolicy, closed_track: "beta" },
    { ...playPolicy, closed_track: "new" },
    { ...playPolicy, closed_track_verified_reference: null },
  ])
    assert.throws(() => selectTrack(tracks, p));
  assert.throws(
    () =>
      selectTrack(
        [{ track: "alpha", releases: [{ status: "draft" }] }],
        playPolicy,
      ),
    /reconciliation/,
  );
});

test("version allocation includes all tracks/bundles/apks, rejects reused and out-of-range codes", () => {
  assert.equal(allocateCode(playPolicy, 1, tracks, [], []), 13);
  assert.throws(
    () => allocateCode(playPolicy, 1, tracks, [{ versionCode: 13 }], []),
    /used/,
  );
  assert.throws(
    () => allocateCode(playPolicy, 1, tracks, [], [{ versionCode: 20 }]),
    /used/,
  );
  assert.throws(() =>
    allocateCode(
      { ...playPolicy, historical_version_code_floor: null },
      1,
      tracks,
      [],
      [],
    ),
  );
  assert.throws(() => allocateCode(playPolicy, 2100000000, tracks, [], []));
});

test("manual artifact route requires fresh explicit Console verification", () => {
  const now = Date.now();
  assert.equal(
    manualCode(
      {
        PLAY_VERIFIED_UNUSED_CODE: "13",
        PLAY_CONSOLE_CHECKED_AT: new Date(now).toISOString(),
      },
      playPolicy,
      now,
    ),
    13,
  );
  for (const env of [
    {},
    {
      PLAY_VERIFIED_UNUSED_CODE: "12",
      PLAY_CONSOLE_CHECKED_AT: new Date(now).toISOString(),
    },
    {
      PLAY_VERIFIED_UNUSED_CODE: "13",
      PLAY_CONSOLE_CHECKED_AT: new Date(now - 86400001).toISOString(),
    },
  ])
    assert.throws(() => manualCode(env, playPolicy, now));
});

test("signing preflight rejects absent secrets and never overwrites owner inputs", () => {
  const root = mkdtempSync(join(tmpdir(), "release01-signing-"));
  try {
    assert.throws(() => prepareSigning({}, root), /Missing/);
    mkdirSync(join(root, "apps/mobile/config"), { recursive: true });
    writeFileSync(join(root, "apps/mobile/config/staging.json"), "owner");
    assert.throws(() => prepareSigning({}, root), /overwrite/);
    assert.equal(
      readFileSync(join(root, "apps/mobile/config/staging.json"), "utf8"),
      "owner",
    );
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("ephemeral signing files are private, correctly escaped, and cleaned", () => {
  const root = mkdtempSync(join(tmpdir(), "release01-signing-"));
  try {
    const env = {
      STAGING_CONFIG_JSON: JSON.stringify({
        APP_ENV: "staging",
        SUPABASE_URL: `https://${STAGING_REF}.supabase.co`,
        ENABLE_DEMO_TOOLS: "false",
        SENTRY_DSN: "",
      }),
      ANDROID_UPLOAD_KEYSTORE_BASE64: Buffer.from("fixture").toString("base64"),
      ANDROID_UPLOAD_STORE_PASSWORD: "a\nb=\\c",
      ANDROID_UPLOAD_KEY_PASSWORD: "synthetic",
      ANDROID_UPLOAD_KEY_ALIAS: "upload",
    };
    const cleanup = prepareSigning(env, root);
    assert.ok(
      readFileSync(
        join(root, "apps/mobile/android/key.properties"),
        "utf8",
      ).includes("\\u000a"),
    );
    cleanup();
    assert.equal(
      existsSync(join(root, "apps/mobile/android/key.properties")),
      false,
    );
    assert.equal(
      existsSync(join(root, "apps/mobile/config/staging.json")),
      false,
    );
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

function mockPlay({ badHash = false, failCommit = false } = {}) {
  const calls = [];
  return {
    calls,
    create: async () => ({ id: "edit" }),
    inventory: async () => ({ tracks, bundles: [], apks: [] }),
    discard: async () => {
      calls.push("discard");
    },
    request: async (path, method, body) => {
      calls.push({ path, method, body });
      if (path.includes("/bundles?"))
        return {
          versionCode: 13,
          sha256: badHash ? "bad" : sha256(Buffer.from("bundle")),
        };
      if (path.endsWith(":commit") && failCommit)
        throw new Error("commit uncertain");
      if (!method)
        return {
          track: "alpha",
          releases: [{ status: "completed", versionCodes: ["13"] }],
        };
      return {};
    },
  };
}
const evidence = {
  package: "community.planets.app",
  version_code: 13,
  sha256: sha256(Buffer.from("bundle")),
  source_sha: "a".repeat(40),
};
test("publication approves only the persisted verified source/certificate/AAB receipt", () => {
  const p = { ...playPolicy, upload_certificate_sha256: "b".repeat(64) };
  const e = {
    ...evidence,
    backend: `https://${STAGING_REF}.supabase.co`,
    debuggable: false,
    demos_enabled: false,
    target_sdk: 36,
    signed_payloads: 3,
    native_16k_checks: 2,
    upload_certificate_sha256: p.upload_certificate_sha256,
  };
  const v = {
    source_sha: e.source_sha,
    areas: ["Mobile", "Database", "Web", "Site"],
  };
  assert.doesNotThrow(() =>
    verifyPersistedArtifact(p, e, Buffer.from("bundle"), v, e.source_sha),
  );
  for (const changed of [
    { ...e, source_sha: "c".repeat(40) },
    { ...e, upload_certificate_sha256: "c".repeat(64) },
    { ...e, target_sdk: undefined },
    { ...e, demos_enabled: true },
  ])
    assert.throws(() =>
      verifyPersistedArtifact(
        p,
        changed,
        Buffer.from("bundle"),
        v,
        e.source_sha,
      ),
    );
  assert.throws(() =>
    verifyPersistedArtifact(p, e, Buffer.from("modified"), v, e.source_sha),
  );
});
test("backend/artifact failure causes zero Play API calls", async () => {
  const api = mockPlay();
  await assert.rejects(
    publishBundle(api, {
      policy: playPolicy,
      bundle: Buffer.from("bundle"),
      evidence,
      backendReady: false,
    }),
  );
  await assert.rejects(
    publishBundle(api, {
      policy: playPolicy,
      bundle: Buffer.from("changed"),
      evidence,
      backendReady: true,
    }),
  );
  assert.deepEqual(api.calls, []);
});
test("Play upload validates accepted hash, updates only exact track, preserves countries, and re-reads committed state", async () => {
  const api = mockPlay();
  const result = await publishBundle(api, {
    policy: playPolicy,
    bundle: Buffer.from("bundle"),
    evidence,
    backendReady: true,
  });
  const update = api.calls.find((c) => c.method === "PUT");
  assert.equal(update.path, "/edit/tracks/alpha");
  assert.deepEqual(update.body.releases[0].countryTargeting, {
    countries: ["IT"],
  });
  assert.equal(
    api.calls.some((c) => c.path?.includes("testers")),
    false,
  );
  assert.equal(result.api_status, "completed");
  assert.match(result.delivery, /must be verified/);
});
test("bad upload hash and ambiguous commit never produce a successful release receipt", async () => {
  for (const options of [{ badHash: true }, { failCommit: true }]) {
    const api = mockPlay(options);
    await assert.rejects(
      publishBundle(api, {
        policy: playPolicy,
        bundle: Buffer.from("bundle"),
        evidence,
        backendReady: true,
      }),
    );
    assert.equal(api.calls.at(-1), "discard");
    if (options.badHash)
      assert.equal(
        api.calls.some((c) => c.method === "PUT"),
        false,
      );
  }
});
test("Play auth and transport reject missing credential, malicious token URL and provider error disclosure", async () => {
  await assert.rejects(playAccessToken(""), /Missing/);
  await assert.rejects(
    playAccessToken(JSON.stringify({ token_uri: "https://evil.test" })),
    /Invalid/,
  );
  const api = playClient(
    "fixture",
    async () => new Response("private provider body", { status: 403 }),
  );
  await assert.rejects(
    api.create(),
    (e) =>
      e.message.includes("403") && !e.message.includes("private provider body"),
  );
});

test("pre-release Validation rejects stale main and skipped affected checks", async () => {
  const env = {
    GITHUB_REF: "refs/heads/main",
    GITHUB_SHA: "a".repeat(40),
    GITHUB_REPOSITORY: "example/test",
    GH_TOKEN: "fixture",
  };
  const response = (data) =>
    new Response(JSON.stringify(data), { status: 200 });
  await assert.rejects(
    requireFullValidation(env, async () =>
      response({ object: { sha: "b".repeat(40) } }),
    ),
    /advanced/,
  );
  const fetcher = async (url) =>
    url.includes("/git/ref/")
      ? response({ object: { sha: env.GITHUB_SHA } })
      : url.includes("/jobs?")
        ? response({
            jobs: ["Change classification", "Mobile", "Web", "Site"].map(
              (name) => ({ name, conclusion: "success" }),
            ),
          })
        : response({
            workflow_runs: [
              { id: 1, head_sha: env.GITHUB_SHA, conclusion: "success" },
            ],
          });
  await assert.rejects(requireFullValidation(env, fetcher), /Database/);
});

test("AAB manifest/payload validator covers altered identity, debuggable and unsigned zip payloads", () => {
  const result = spawnSync(
    process.platform === "win32" ? "python" : "python3",
    [
      "-m",
      "unittest",
      "discover",
      "-s",
      "scripts/release",
      "-p",
      "test_artifact.py",
    ],
    { encoding: "utf8" },
  );
  assert.equal(result.status, 0, result.stderr);
});
