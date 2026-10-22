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
} from "../release/recovery.mjs";
import {
  assertDeployContext,
  assertWriterSnapshot,
} from "../release/writer.mjs";
import {
  deploymentSet,
  readMigrations,
  STAGING_REF,
} from "../release/migrations.mjs";
import { sha256 } from "../release/sql-fingerprint.mjs";

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
    STAGING_CONFIG_JSON: "fictional",
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
});
