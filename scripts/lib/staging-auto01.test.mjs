import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { resolve } from "node:path";
import {
  classifyMigration,
  assertRoutineCatalog,
  assertRoutineTargets,
  authorizePending,
  inventoryDigest,
} from "../release/safety.mjs";
import {
  reviewEntries,
  REVIEW_PREFIX,
  deploymentReviews,
  requiresSafetyRehearsal,
} from "../release/reviews.mjs";
import {
  assertRecovery,
  recoveryReceipt,
  verifiedRecovery,
  assertStagingRecoveryMode,
  stagingRecovery,
} from "../release/recovery.mjs";
import {
  assertDeployContext,
  assertWriterSnapshot,
  writeStaging,
} from "../release/writer.mjs";
import {
  deploymentSet,
  readMigrations,
  STAGING_REF,
} from "../release/migrations.mjs";
import { sha256 } from "../release/sql-fingerprint.mjs";
import {
  assertDatabaseUrl,
  inspectSessionConnection,
  connectionFailure,
} from "../release/staging.mjs";
import { ReleaseError } from "../release/errors.mjs";
import { stagingTlsOptions, stagingCaPath } from "../release/transport.mjs";
import { X509Certificate } from "node:crypto";

const root = fileURLToPath(new URL("../../", import.meta.url));
const json = (path) => JSON.parse(readFileSync(resolve(root, path), "utf8"));
const source = "a".repeat(40),
  hash = "b".repeat(64);
const routine =
  "SET lock_timeout='5s'; SET statement_timeout='60s'; ALTER TABLE private.items ADD COLUMN note text NULL; RESET lock_timeout; RESET statement_timeout;";
const migration = (version, sql = routine) => ({
  version,
  sql,
  sha256: sha256(sql),
  file: `${version}_fixture.sql`,
});
const base = migration("20261022000000", "select 1;");
function scenario(sql = routine) {
  const next = migration("20261023000000", sql),
    local = [base, next];
  const diff = {
    drift: [],
    predecessor_sha256: hash,
    pending: [
      { version: next.version, sha256: next.sha256, historical: false },
    ],
  };
  const witness = {
    version: next.version,
    sha256: next.sha256,
    predecessor_inventory_sha256: inventoryDigest([base]),
    preserved_rows: true,
    routine_security_preserved: true,
  };
  const evidence = {
    source_sha: source,
    inventory_sha256: inventoryDigest(local),
    no_op_retry: true,
    resource_auth_rest: true,
    generated_types: true,
    migration_safety: [witness],
  };
  return { next, local, diff, witness, evidence };
}
const authorize = (s, reviews = [], recon = null) =>
  authorizePending(s.diff, s.local, s.evidence, source, reviews, recon);

test("whole SQL grammar accepts bounded nullable columns, never privileged/hidden effects", () => {
  assert.equal(classifyMigration(routine).classification, "routine-candidate");
  assert.equal(
    classifyMigration(`-- DROP is only a comment\n${routine}`).classification,
    "routine-candidate",
  );
  for (const sql of [
    "select 1;",
    `${routine} DROP TABLE private.items;`,
    routine.replace("text NULL", "text DEFAULT 'hidden rewrite'"),
    routine.replace("text NULL", "text NOT NULL"),
    routine.replace("'5s'", "'0'"),
    routine.replace("private.items", 'private."items"'),
    "DO $$BEGIN EXECUTE 'DROP TABLE private.items'; END$$;",
    "GRANT SELECT ON private.items TO anon;",
    "ALTER TABLE private.items DISABLE ROW LEVEL SECURITY;",
    "CREATE OR REPLACE FUNCTION public.get_items() RETURNS SETOF private.items LANGUAGE sql SECURITY DEFINER AS $$SELECT * FROM private.items$$;",
    "UPDATE private.items SET note='rewritten';",
    "/* unterminated",
  ])
    assert.equal(classifyMigration(sql).classification, "review-required", sql);
});

const catalog = () => ({
  security: hash,
  tables: [
    {
      name: "private.items",
      kind: "r",
      rls: true,
      inherited: false,
      owner: "postgres",
      client_access: false,
      security: hash,
      columns: [
        {
          name: "id",
          type: "uuid",
          not_null: true,
          default: null,
          identity: "",
          generated: "",
        },
      ],
    },
  ],
});
const effects = classifyMigration(routine).effects;
test("semantic proof rejects access expansion, hidden triggers, defaults and existing contract changes", () => {
  const before = catalog(),
    after = catalog();
  after.tables[0].columns.push({
    name: "note",
    type: "text",
    not_null: false,
    default: null,
    identity: "",
    generated: "",
  });
  assert.doesNotThrow(() => assertRoutineCatalog(before, after, effects));
  for (const mutate of [
    (a) => {
      a.security = "changed-trigger";
    },
    (a) => {
      a.tables[0].rls = false;
    },
    (a) => {
      a.tables[0].client_access = true;
    },
    (a) => {
      a.tables[0].columns[0].type = "text";
    },
    (a) => {
      a.tables[0].columns[1].default = "'secret'";
    },
  ]) {
    const altered = structuredClone(after);
    mutate(altered);
    assert.throws(() => assertRoutineCatalog(before, altered, effects));
  }
  const publicTarget = catalog();
  publicTarget.tables[0].client_access = true;
  assert.throws(() => assertRoutineTargets(publicTarget, effects), /RPC-only/);
});

test("exact validated routine set needs no post-merge approval; stale or failed evidence blocks", () => {
  assert.equal(authorize(scenario())[0].authorization, "routine-verified");
  for (const change of [
    (s) => {
      s.evidence.source_sha = "c".repeat(40);
    },
    (s) => {
      s.evidence.generated_types = false;
    },
    (s) => {
      s.evidence.no_op_retry = false;
    },
    (s) => {
      s.evidence.resource_auth_rest = false;
    },
    (s) => {
      s.witness.preserved_rows = false;
    },
    (s) => {
      s.witness.routine_security_preserved = false;
    },
    (s) => {
      s.witness.predecessor_inventory_sha256 = hash;
    },
    (s) => {
      s.local[1].sql += "select 2;";
    },
    (s) => {
      s.diff.pending[0].sha256 = hash;
    },
    (s) => {
      s.diff.drift.push({ reason: "remote mismatch" });
    },
  ]) {
    const s = scenario();
    change(s);
    assert.throws(() => authorize(s));
  }
});
test("mixed routine/risky dependencies are authorized together before any write", () => {
  const s = scenario(),
    risky = migration(
      "20261024000000",
      "grant select on private.items to anon;",
    );
  s.local.push(risky);
  s.diff.pending.push({ ...risky, historical: false });
  s.evidence.inventory_sha256 = inventoryDigest(s.local);
  const witness = {
    version: risky.version,
    sha256: risky.sha256,
    predecessor_inventory_sha256: inventoryDigest([base, s.next]),
    preserved_rows: true,
  };
  s.evidence.migration_safety.push(witness);
  assert.throws(() => authorize(s), /pre-merge owner review/);
  assert.deepEqual(
    authorize(s, [witness]).map((d) => d.authorization),
    ["routine-verified", "pre-merge-owner-review"],
  );
});

test("bounded historical pair preserves original approval and refuses changed scope/predecessor", () => {
  const local = readMigrations(root),
    observed = json(
      "docs/development/evidence/release01/staging-auto01-predecessor.json",
    );
  const recon = {
    ...json("scripts/release/reconciliation.json"),
    enabled: true,
  };
  const policy = json("scripts/release/policy.json");
  assert.equal(
    policy.bootstrap_approvals.length ??
      Object.keys(policy.bootstrap_approvals).length,
    26,
  );
  const pending = observed.pending;
  const diff = {
    drift: [],
    pending,
    predecessor_sha256: recon.predecessor_sha256,
  };
  const prior = local.filter(
    (m) => !pending.some((p) => p.version === m.version),
  );
  const witnesses = pending.map((p) => {
    const w = {
      version: p.version,
      sha256: p.sha256,
      predecessor_inventory_sha256: inventoryDigest(prior),
      preserved_rows: true,
    };
    prior.push(local.find((m) => m.version === p.version));
    return w;
  });
  const evidence = {
    source_sha: source,
    inventory_sha256: inventoryDigest(local),
    no_op_retry: true,
    resource_auth_rest: true,
    generated_types: true,
    migration_safety: witnesses,
  };
  const s = { local, diff, evidence };
  assert.equal(deploymentSet(diff, policy, null, recon).length, 3);
  assert.equal(authorize(s, witnesses, recon).length, 3);
  assert.throws(
    () => authorize(s, witnesses.slice(0, 2), recon),
    /pre-merge owner review/,
  ); // third file is independently reviewed
  for (const r of [
    { ...recon, enabled: false },
    { ...recon, predecessor_sha256: hash },
    { ...recon, migrations: [...recon.migrations, pending[2]] },
  ])
    assert.throws(() => authorize(s, witnesses, r), /two-file/);
  assert.throws(() =>
    deploymentSet(diff, policy, null, {
      ...recon,
      migrations: recon.migrations.toReversed(),
    }),
  );
  assert.deepEqual(
    authorizePending({ drift: [], pending: [] }, [], null, source, [], null),
    [],
  );
});

const pr = {
  number: 10,
  head: { sha: source },
  merged_at: "2026-10-22T12:00:00Z",
};
const approval = {
  version: "20261023000000",
  sha256: hash,
  predecessor_inventory_sha256: hash,
};
const comment = () => ({
  id: 4,
  user: { id: 42, type: "User" },
  created_at: "2026-10-22T11:00:00Z",
  updated_at: "2026-10-22T11:00:00Z",
  body:
    REVIEW_PREFIX +
    JSON.stringify({
      project_ref: STAGING_REF,
      source_sha: source,
      approvals: [approval],
    }),
});
test("review proof requires exact owner/source and pre-merge creation AND edit timestamps", () => {
  assert.equal(reviewEntries([comment()], pr, 42).length, 1);
  for (const mutate of [
    (c) => {
      c.user.id = 7;
    },
    (c) => {
      c.user.type = "Bot";
    },
    (c) => {
      c.updated_at = "2026-10-22T13:00:00Z";
    },
    (c) => {
      c.created_at = "invalid";
    },
    (c) => {
      c.body = REVIEW_PREFIX + "null";
    },
    (c) => {
      c.body = c.body.replace(source, "d".repeat(40));
    },
    (c) => {
      c.body = c.body.replace(STAGING_REF, "wrong-project");
    },
  ]) {
    const c = comment();
    mutate(c);
    assert.deepEqual(reviewEntries([c], pr, 42), []);
  }
});
test("deployment independently rechecks merged PR owner proof and original canonical bytes", async () => {
  const m = migration(approval.version, "select 1;"),
    c = comment();
  c.body = c.body.replace(hash, m.sha256);
  const merged = {
    ...pr,
    base: { ref: "main", repo: { full_name: "lillo24/planets.community" } },
    head: { ...pr.head, repo: { full_name: "lillo24/planets.community" } },
  };
  let changedBytes = false;
  const api = async (path) =>
    path === ""
      ? { owner: { id: 42 } }
      : path.includes("/pulls?")
        ? [merged]
        : path.includes("/comments?")
          ? [c]
          : {
              encoding: "base64",
              content: Buffer.from(changedBytes ? "select 2;" : m.sql).toString(
                "base64",
              ),
            };
  assert.equal(
    (
      await deploymentReviews(
        [m],
        [{ path: m.file, migrations: [m] }],
        api,
        () => source,
      )
    ).length,
    1,
  );
  changedBytes = true;
  assert.deepEqual(
    await deploymentReviews(
      [m],
      [{ path: m.file, migrations: [m] }],
      api,
      () => source,
    ),
    [],
  );
});

const policy = {
  project_ref: STAGING_REF,
  workflow_id: 123,
  workflow_path: ".github/workflows/staging-recovery.yml",
  workflow_sha256: hash,
  policy_id: "12345678-1234-1234-1234-123456789abc",
  max_age_hours: 1,
};
const receipt = () => ({
  project_ref: STAGING_REF,
  policy_id: policy.policy_id,
  predecessor_inventory_sha256: hash,
  completed_at: "2026-10-22T11:30:00Z",
  encrypted: true,
  access_controlled: true,
  database_restored: true,
  storage_objects_restored: true,
  database_sha256: hash,
  storage_objects_sha256: hash,
});
test("recovery needs fresh restore evidence for BOTH encrypted DB and actual Storage objects", () => {
  const now = Date.parse("2026-10-22T12:00:00Z");
  assert.equal(
    assertRecovery(policy, receipt(), hash, now).database_restored,
    true,
  );
  for (const mutate of [
    (r) => {
      r.storage_objects_restored = false;
    },
    (r) => {
      r.database_restored = false;
    },
    (r) => {
      r.encrypted = false;
    },
    (r) => {
      r.access_controlled = false;
    },
    (r) => {
      r.completed_at = "2026-10-21T12:00:00Z";
    },
    (r) => {
      r.completed_at = "2026-10-23T12:00:00Z";
    },
    (r) => {
      r.predecessor_inventory_sha256 = "c".repeat(64);
    },
    (r) => {
      r.project_ref = "production";
    },
    (r) => {
      r.unexpected_private_payload = "fictional private data";
    },
  ]) {
    const r = receipt();
    mutate(r);
    assert.throws(() => assertRecovery(policy, r, hash, now));
  }
  assert.throws(() =>
    assertRecovery(
      { backup_waiver: "No backup is fine" },
      receipt(),
      hash,
      now,
    ),
  );
});
test("missing recovery setup and changed trusted workflow fail closed", async () => {
  await assert.rejects(
    verifiedRecovery({}, () => {}, hash),
    /one-time|One-time/,
  );
  const env = {
    STAGING_RECOVERY_POLICY_JSON: JSON.stringify(policy),
    GITHUB_REPOSITORY: "lillo24/planets.community",
  };
  const api = async (path) =>
    path.includes("/runs?")
      ? {
          workflow_runs: [
            {
              head_branch: "main",
              head_repository: { full_name: env.GITHUB_REPOSITORY },
              conclusion: "success",
              event: "schedule",
              head_sha: source,
            },
          ],
        }
      : {
          encoding: "base64",
          content: Buffer.from("unreviewed workflow").toString("base64"),
        };
  await assert.rejects(verifiedRecovery(env, api, hash), /source differs/);
});

function zipReceipt(data) {
  const name = Buffer.from("recovery.json"),
    body = Buffer.from(JSON.stringify(data));
  const local = Buffer.alloc(30);
  local.writeUInt32LE(0x04034b50);
  local.writeUInt16LE(name.length, 26);
  local.writeUInt32LE(body.length, 18);
  local.writeUInt32LE(body.length, 22);
  const central = Buffer.alloc(46);
  central.writeUInt32LE(0x02014b50);
  central.writeUInt32LE(body.length, 20);
  central.writeUInt32LE(body.length, 24);
  central.writeUInt16LE(name.length, 28);
  const end = Buffer.alloc(22);
  end.writeUInt32LE(0x06054b50);
  end.writeUInt16LE(1, 8);
  end.writeUInt16LE(1, 10);
  end.writeUInt32LE(central.length + name.length, 12);
  end.writeUInt32LE(local.length + name.length + body.length, 16);
  return Buffer.concat([local, name, body, central, name, end]);
}
test("only one bounded metadata ZIP receipt is accepted without disk extraction", () => {
  assert.deepEqual(recoveryReceipt(zipReceipt(receipt())), receipt());
  for (const invalid of [
    Buffer.alloc(0),
    Buffer.alloc(65537),
    zipReceipt({ huge: "x".repeat(17000) }),
    zipReceipt(receipt()).subarray(0, 50),
  ])
    assert.throws(() => recoveryReceipt(invalid));
  const extra = zipReceipt(receipt());
  extra.writeUInt16LE(2, extra.length - 12);
  assert.throws(() => recoveryReceipt(extra));
});

test("writer requires exact tested/rehearsed main, one-time readiness and credentials", () => {
  const env = {
    GITHUB_ACTIONS: "true",
    GITHUB_REPOSITORY: "lillo24/planets.community",
    GITHUB_REF: "refs/heads/main",
    GITHUB_SHA: source,
    RELEASE_VALIDATED_SHA: source,
    RELEASE_REHEARSED_SHA: source,
    STAGING_DEPLOYMENT_OWNER: "github-actions",
    STAGING_AUTOMATION_READY: "true",
    GH_TOKEN: "fictional",
    SUPABASE_ACCESS_TOKEN: "fictional",
    STAGING_CONFIG_JSON: JSON.stringify({
      APP_ENV: "staging",
      SUPABASE_URL: `https://${STAGING_REF}.supabase.co`,
    }),
    STAGING_RECOVERY_MODE: "development-no-backup",
  };
  assert.doesNotThrow(() => assertDeployContext(env));
  for (const key of Object.keys(env)) {
    const bad = { ...env };
    delete bad[key];
    assert.throws(() => assertDeployContext(bad));
  }
});
test("push never reaches Android/Play regardless of legacy auto-publish flag", () => {
  const workflow = readFileSync(
    resolve(root, ".github/workflows/staging-release.yml"),
    "utf8",
  );
  const android = workflow.split("  android:")[1].split("  publish:")[0],
    publish = workflow.split("  publish:")[1];
  for (const job of [android, publish])
    assert.match(
      job.split("runs-on:")[0],
      /github.event_name == 'workflow_dispatch'/,
    );
  assert.doesNotMatch(workflow, /vars.STAGING_AUTO_PUBLISH/);
  assert.match(publish, /environment: planets-play-closed/);
  assert.equal(json("scripts/release/reconciliation.json").enabled, false);
});
test("concurrent writer or changed independent history aborts before CLI apply", () => {
  const observed = [{ version: base.version, sha256: base.sha256 }];
  assert.doesNotThrow(() =>
    assertWriterSnapshot(true, observed, observed, observed),
  );
  assert.throws(
    () => assertWriterSnapshot(false, observed, observed, observed),
    /writer lock/,
  );
  assert.throws(
    () => assertWriterSnapshot(true, [], observed, observed),
    /history changed/,
  );
  assert.throws(
    () => assertWriterSnapshot(true, observed, [], observed),
    /history changed/,
  );
});
test("semantic safety lives in the always-present required classification check without unrelated rehearsal cost", () => {
  for (const path of [
    "supabase/migrations/20261023000000_test.sql",
    "scripts/release/safety.mjs",
    ".github/workflows/validation.yml",
    "package-lock.json",
  ])
    assert.equal(requiresSafetyRehearsal([path]), true);
  for (const path of [
    "README.md",
    "docs/development/example.md",
    "apps/site/src/App.tsx",
    "apps/mobile/lib/main.dart",
    "scripts/release/README.md",
    "supabase/functions/README.md",
    ".github/workflows/README.md",
  ])
    assert.equal(requiresSafetyRehearsal([path]), false);
  const validation = readFileSync(
    resolve(root, ".github/workflows/validation.yml"),
    "utf8",
  );
  assert.match(
    validation.split("\n  mobile:\n")[0],
    /node scripts\/release\/rehearse.mjs/,
  );
  const release = readFileSync(
    resolve(root, ".github/workflows/staging-release.yml"),
    "utf8",
  );
  assert.match(release.split("permissions:")[0], /"!\*\*\/\*\.md"/);
});
test("session lock cannot silently use the transaction pooler port", () => {
  const route = `postgres://postgres.${STAGING_REF}:fictional@aws-1-eu-west-1.pooler.supabase.com`;
  assert.match(
    assertDatabaseUrl(`${route}:5432/postgres`),
    /sslmode=verify-full/,
  );
  assert.throws(() => assertDatabaseUrl(`${route}:6543/postgres`));
  assert.throws(() => assertDatabaseUrl(`${route}/postgres#unexpected`));
});

const developmentEnv = {
  STAGING_RECOVERY_MODE: "development-no-backup",
  STAGING_CONFIG_JSON: JSON.stringify({
    APP_ENV: "staging",
    SUPABASE_URL: `https://${STAGING_REF}.supabase.co`,
  }),
};
test("standing staging-only waiver skips all recovery access and records no restoration claims", async () => {
  const forbidden = () => assert.fail("No recovery access in development mode");
  for (let merge = 0; merge < 2; merge++) {
    const evidence = await stagingRecovery(
      {
        ...developmentEnv,
        STAGING_RECOVERY_POLICY_JSON: "unused invalid policy",
      },
      forbidden,
      hash,
      STAGING_REF,
      forbidden,
    );
    assert.deepEqual(evidence, {
      mode: "development-no-backup",
      status: "waived",
      project_ref: STAGING_REF,
      predecessor_inventory_sha256: hash,
      data_loss_accepted: true,
    });
    assert.doesNotMatch(
      JSON.stringify(evidence),
      /restored|completed_at|database_sha256|storage_objects_sha256|workflow_run_id|policy_id/,
    );
  }
  for (const mode of [
    undefined,
    "",
    "no-backup",
    "production",
    "VERIFIED-BACKUP",
  ])
    assert.throws(() =>
      assertStagingRecoveryMode(
        { ...developmentEnv, STAGING_RECOVERY_MODE: mode },
        STAGING_REF,
      ),
    );
  for (const project of [undefined, "production", "pnolarmzxmmjtguligfc"])
    await assert.rejects(
      stagingRecovery(developmentEnv, forbidden, hash, project, forbidden),
      /restricted to planets-staging/,
    );
  for (const config of [
    "invalid",
    "null",
    JSON.stringify({
      APP_ENV: "production",
      SUPABASE_URL: `https://${STAGING_REF}.supabase.co`,
    }),
    JSON.stringify({
      APP_ENV: "staging",
      SUPABASE_URL: "https://pnolarmzxmmjtguligfc.supabase.co",
    }),
  ])
    assert.throws(() =>
      assertStagingRecoveryMode(
        { ...developmentEnv, STAGING_CONFIG_JSON: config },
        STAGING_REF,
      ),
    );
  await assert.rejects(
    stagingRecovery(
      developmentEnv,
      forbidden,
      "invalid",
      STAGING_REF,
      forbidden,
    ),
    /observed predecessor/,
  );
});

test("verified-backup delegates to genuine trusted workflow and fresh DB plus Storage verification", async () => {
  const workflow = "fictional owner-reviewed recovery workflow";
  const env = {
    ...developmentEnv,
    STAGING_RECOVERY_MODE: "verified-backup",
    STAGING_RECOVERY_POLICY_JSON: JSON.stringify({
      ...policy,
      workflow_sha256: sha256(workflow),
    }),
    GITHUB_REPOSITORY: "lillo24/planets.community",
    GH_TOKEN: "fictional",
  };
  let proof = { ...receipt(), completed_at: new Date().toISOString() };
  let downloads = 0;
  const api = async (path) =>
    path.includes("/runs?")
      ? {
          workflow_runs: [
            {
              id: 19,
              head_branch: "main",
              head_repository: { full_name: env.GITHUB_REPOSITORY },
              conclusion: "success",
              event: "schedule",
              head_sha: source,
            },
          ],
        }
      : path.includes("/contents/")
        ? {
            encoding: "base64",
            content: Buffer.from(workflow).toString("base64"),
          }
        : {
            artifacts: [
              {
                id: 4,
                name: "staging-recovery-receipt",
                expired: false,
                size_in_bytes: 1000,
              },
            ],
          };
  const fetcher = async () => {
    downloads++;
    return new Response(zipReceipt(proof));
  };
  const result = await stagingRecovery(env, api, hash, STAGING_REF, fetcher);
  assert.equal(downloads, 1);
  assert.deepEqual(result, {
    mode: "verified-backup",
    status: "verified",
    policy_id: policy.policy_id,
    completed_at: proof.completed_at,
    database_restored: true,
    storage_objects_restored: true,
    workflow_run_id: 19,
  });
  for (const bad of [
    { database_restored: false },
    { storage_objects_restored: false },
    { completed_at: "2020-01-01T00:00:00Z" },
    { predecessor_inventory_sha256: "c".repeat(64) },
    { project_ref: "production" },
  ]) {
    proof = { ...receipt(), completed_at: new Date().toISOString(), ...bad };
    await assert.rejects(
      stagingRecovery(env, api, hash, STAGING_REF, fetcher),
      /backup\/restore evidence/,
    );
  }
  await assert.rejects(
    stagingRecovery(
      { ...env, STAGING_RECOVERY_POLICY_JSON: undefined },
      api,
      hash,
      STAGING_REF,
      fetcher,
    ),
    /STAGING_RECOVERY_POLICY_JSON/,
  );
});

test("waiver leaves SQL review, preservation, chronology and source guards independent", async () => {
  await stagingRecovery(developmentEnv, () => assert.fail(), hash, STAGING_REF);
  assert.equal(authorize(scenario())[0].authorization, "routine-verified");
  for (const sql of [
    "grant select on private.items to anon;",
    "alter table private.items disable row level security;",
  ])
    assert.throws(() => authorize(scenario(sql)), /pre-merge owner review/);
  for (const mutate of [
    (s) => {
      s.evidence.source_sha = "c".repeat(40);
    },
    (s) => {
      s.witness.preserved_rows = false;
    },
    (s) => {
      s.witness.routine_security_preserved = false;
    },
    (s) => {
      s.witness.predecessor_inventory_sha256 = hash;
    },
    (s) => {
      s.diff.pending[0].sha256 = hash;
    },
    (s) => {
      s.diff.pending[0].historical = true;
    },
    (s) => {
      s.diff.drift.push({ reason: "unexpected live history" });
    },
  ]) {
    const s = scenario();
    mutate(s);
    assert.throws(() => authorize(s));
  }
  const remote = [{ version: base.version }],
    diff = { pending: [] };
  assert.deepEqual(await writeStaging({ remote, diff }), { remote, diff });
  await assert.rejects(
    writeStaging({
      diff: { pending: [{}], project_ref: "pnolarmzxmmjtguligfc" },
      policy: { staging_safety_version: 1 },
      env: developmentEnv,
    }),
    /restricted to planets-staging/,
  );
});

test("inspect proves client TLS without confusing pooler-to-Postgres TLS and withholds native diagnostics", async () => {
  const env = {
    STAGING_DB_URL: `postgres://postgres.${STAGING_REF}:fictional@aws-1-eu-west-1.pooler.supabase.com:5432/postgres`,
  };
  let session = {
    database_name: "postgres",
    database_role: "postgres",
    backend_pid: 42,
  };
  let changed = false,
    ended = false,
    history = [];
  const connect = (url, options) => {
    assert.match(url, /sslmode=verify-full/);
    assert.deepEqual(options.ssl, stagingTlsOptions());
    assert.equal(options.max, 1);
    assert.equal(options.connect_timeout, 20);
    let calls = 0;
    return {
      unsafe: async (query) => {
        assert.match(query, /^select /);
        assert.doesNotMatch(query, /pg_stat_ssl/);
        if (query.includes("schema_migrations")) return history;
        calls++;
        return [
          { ...session, ...(calls === 2 && changed && { backend_pid: 43 }) },
        ];
      },
      end: async () => {
        ended = true;
      },
    };
  };
  assert.deepEqual(await inspectSessionConnection(env, [], connect), {
    client_tls_verified: true,
    session_verified: true,
    history_matches: true,
    port: 5432,
  });
  assert.equal(ended, true);
  for (const bad of [
    { database_name: "other" },
    { database_role: "other" },
    { backend_pid: null },
  ]) {
    session = {
      database_name: "postgres",
      database_role: "postgres",
      backend_pid: 42,
      ...bad,
    };
    ended = false;
    await assert.rejects(
      inspectSessionConnection(env, [], connect),
      /session or independent/,
    );
    assert.equal(ended, true);
  }
  session = {
    database_name: "postgres",
    database_role: "postgres",
    backend_pid: 42,
  };
  changed = true;
  await assert.rejects(
    inspectSessionConnection(env, [], connect),
    /session or independent/,
  );
  changed = false;
  history = [
    { version: base.version, name: "fixture", statements: ["select 1"] },
  ];
  await assert.rejects(
    inspectSessionConnection(env, [], connect),
    /independent migration history/,
  );
  await assert.rejects(
    inspectSessionConnection(
      { STAGING_DB_URL: env.STAGING_DB_URL.replace(":5432/", ":6543/") },
      [],
      () => assert.fail("Reject transaction pooler before connect"),
    ),
  );
  for (const code of [
    "28P01",
    "ENOTFOUND",
    "ERR_TLS_CERT_ALTNAME_INVALID",
    "unexpected-private-code",
  ])
    assert.doesNotMatch(
      connectionFailure({ code, message: "fictional-private-password" }),
      /fictional-private|unexpected-private/,
    );
  assert.equal(
    connectionFailure(new ReleaseError("safe authored failure")),
    "safe authored failure",
  );
});

test("connection failures expose only allowlisted network codes, including aggregate failures", () => {
  for (const code of [
    "ENOTFOUND",
    "EAI_AGAIN",
    "ECONNREFUSED",
    "ETIMEDOUT",
    "CONNECT_TIMEOUT",
    "EHOSTUNREACH",
    "ENETUNREACH",
  ]) {
    const error = Object.assign(new Error("postgres://private:password@host"), {
      code,
      address: "private-address",
    });
    const message = connectionFailure(error);
    assert.match(message, new RegExp(`\\(${code}\\)`));
    assert.doesNotMatch(message, /private|password|postgres:\/\//);
  }
  const aggregate = new AggregateError(
    [
      { code: "ENETUNREACH", message: "private-address" },
      { code: "ETIMEDOUT", message: "private-password" },
      { code: "ENETUNREACH" },
      { code: "private-code", message: "private-host" },
    ],
    "postgres://private:password@host",
  );
  assert.equal(
    connectionFailure(aggregate),
    "Staging database network connection failed: network is unreachable (ENETUNREACH); connection timed out (ETIMEDOUT)",
  );
  assert.equal(
    connectionFailure(new AggregateError([{ code: "private-code" }])),
    "Staging database connection failed; native diagnostics withheld",
  );
});

test("session client and migration CLI retain the same reviewed public CA with hostname verification", () => {
  const options = stagingTlsOptions();
  assert.equal(options.rejectUnauthorized, true);
  assert.deepEqual(options.ca, readFileSync(stagingCaPath));
  const certificate = new X509Certificate(options.ca);
  assert.equal(certificate.ca, true);
  assert.equal(
    certificate.fingerprint256,
    "80:70:25:AD:50:D4:ED:21:9D:2C:9C:7D:29:9C:00:4F:82:4E:B0:0C:F7:F6:5A:FE:F6:07:D0:7B:72:E6:CA:FA",
  );
  const writer = readFileSync(
    resolve(root, "scripts/release/writer.mjs"),
    "utf8",
  );
  assert.match(writer, /ssl: stagingTlsOptions\(\)/);
  assert.match(writer, /PGSSLROOTCERT: stagingCaPath/);
  assert.doesNotMatch(writer, /rejectUnauthorized: false/);
  const workflow = readFileSync(
    resolve(root, ".github/workflows/staging-release.yml"),
    "utf8",
  );
  const observer = workflow.split("\n  observe:")[1].split("\n  rehearse:")[0];
  assert.match(observer, /github.ref == 'refs\/heads\/main'/);
  assert.match(observer, /inputs.operation == 'inspect'/);
  assert.match(observer, /environment: planets-staging/);
  const condition = workflow.split("\n  staging:")[1].split("environment:")[0];
  assert.match(condition, /needs: \[validate, rehearse, observe\]/);
  for (const gate of ["observe", "validate", "rehearse"])
    assert.ok(condition.includes(`needs.${gate}.result == 'success'`));
});
