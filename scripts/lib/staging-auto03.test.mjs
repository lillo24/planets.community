import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import {
  inspectAdditive,
  assertPolicySeparation,
  assertBoundedCatalog,
  catalogEffects,
  authorizeVerifiedPending,
  policyModuleHash,
  UnsafeCatalogError,
} from "../release/eligibility.mjs";
import { STAGING_REF, verifiedDeploymentSet } from "../release/migrations.mjs";
import { inventoryDigest } from "../release/safety.mjs";
import { sha256 } from "../release/sql-fingerprint.mjs";
import { assertNativeDeploymentDisabled } from "../release/backend.mjs";
import {
  assertReconciledWriter,
  previousWriterState,
} from "../release/writer-state.mjs";

const source = "a".repeat(40),
  tree = "b".repeat(40);
const privateTable =
  "create table private.example(id uuid primary key); alter table private.example enable row level security; revoke all on private.example from public,anon,authenticated,service_role;";
const roles = { anon: false, authenticated: false, service_role: false };
const privileges = () =>
  Object.fromEntries(
    Object.keys(roles).map((r) => [
      r,
      {
        SELECT: false,
        INSERT: false,
        UPDATE: false,
        DELETE: false,
        TRUNCATE: false,
        REFERENCES: false,
        TRIGGER: false,
      },
    ]),
  );
const table = () => ({
  id: "private.example",
  owner: "postgres",
  rls: true,
  forced: false,
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
  access: privileges(),
});
const fn = () => ({
  id: "public.reserve_basemap_tile_v2(p_actor uuid)",
  oid: 42,
  owner: "postgres",
  returns: "jsonb",
  acl: "{postgres=X/postgres,service_role=X/postgres}",
  access: { ...roles, service_role: true },
  definer: true,
  config: ['search_path=""'],
  body: "old",
});
const catalog = () => ({
  tables: [table()],
  functions: [fn()],
  policies: [],
  triggers: [],
  constraints: [],
  indexes: [],
  views: [],
});
const candidate = { classification: "private-additive-candidate" };
test("single native migration owner is verified from the real default branch metadata", () => {
  const base = {
    id: "synthetic",
    is_default: true,
    project_ref: STAGING_REF,
    parent_project_ref: STAGING_REF,
  };
  assert.equal(
    assertNativeDeploymentDisabled([base]).native_deployment_disabled,
    true,
  );
  assert.equal(
    assertNativeDeploymentDisabled([{ ...base, git_branch: "" }])
      .native_deployment_disabled,
    true,
  );
  for (const branches of [
    null,
    [],
    [base, base],
    [{ ...base, project_ref: "pnolarmzxmmjtguligfc" }],
    [{ ...base, git_branch: "main" }],
  ])
    assert.throws(() => assertNativeDeploymentDisabled(branches));
});
const scenario = () => {
  const base = {
    version: "20261021000000",
    sql: "select 1;",
    sha256: sha256("select 1;"),
  };
  const first = {
    version: "20261020000000",
    sql: privateTable,
    sha256: sha256(privateTable),
  };
  const last = {
    version: "20261023000000",
    sql: privateTable + "\n",
    sha256: sha256(privateTable + "\n"),
  };
  const local = [first, base, last];
  const pending = [first, last].map((m) => ({
    version: m.version,
    sha256: m.sha256,
    historical: m === first,
  }));
  const applied = [base];
  const witnesses = [first, last].map((m) => {
    const w = {
      version: m.version,
      sha256: m.sha256,
      predecessor_inventory_sha256: inventoryDigest(applied),
      preserved_rows: true,
      catalog_verified: true,
      independent_contracts: true,
      status: "auto-eligible-for-staging",
      catalog_effects: [],
      effect_sha256: sha256("[]"),
    };
    applied.push(m);
    return w;
  });
  return {
    local,
    diff: { project_ref: STAGING_REF, pending, drift: [] },
    evidence: {
      policy_version: 2,
      project_ref: STAGING_REF,
      source_sha: source,
      source_tree: tree,
      policy_module_sha256: policyModuleHash(),
      inventory_sha256: inventoryDigest(local),
      no_op_retry: true,
      resource_auth_rest: true,
      generated_types: true,
      trusted_security_tests: true,
      real_actor_denials: true,
      storage_objects_preserved: true,
      policy_negative_probes: true,
      single_writer_probe: true,
      migration_safety: witnesses,
    },
  };
};
const authorize = (s) =>
  authorizeVerifiedPending(s.diff, s.local, s.evidence, source, tree);

test("private additive inspection is only a candidate; unknown privileged code is held", () => {
  assert.equal(
    inspectAdditive(privateTable).classification,
    "private-additive-candidate",
  );
  for (const sql of [
    "create table public.raw(id uuid);",
    "create function public.unknown() returns int language sql security definer set search_path='' as $$select 1$$;",
    privateTable + "grant select on private.example to anon;",
    "update private.example set id=gen_random_uuid();",
    privateTable + "create index idx on public.other(id);",
  ])
    assert.equal(
      inspectAdditive(sql).classification,
      "review-required-for-hosted",
    );
});
test("destructive and malformed statements cannot be automatic candidates", () => {
  for (const sql of [
    "drop table private.example;",
    "truncate private.example;",
    "alter table private.example drop column id;",
    "alter role authenticated superuser;",
    "create function private.x() returns int as $$unterminated",
  ])
    assert.equal(inspectAdditive(sql).classification, "blocked-unsafe");
});
test("SQL body tokens retain embedded semicolons and require an independent known contract", () => {
  const sql =
    "create or replace function private.reserve_mock_map_provider_v1() returns jsonb language plpgsql security definer set search_path='' as $$begin perform 1;return '{}'::jsonb;end$$;";
  assert.equal(
    inspectAdditive(sql).classification,
    "mock-basemap-contract-candidate",
  );
  assert.equal(
    inspectAdditive(sql.replace("perform 1", "execute 'select 1'"))
      .classification,
    "review-required-for-hosted",
  );
});
test("policy code, workflows, dependencies and proof fixtures cannot qualify SQL in the same PR", () => {
  const migration = "supabase/migrations/20261023000000_example.sql";
  for (const path of [
    "scripts/release/contracts.mjs",
    "scripts/release/eligibility.mjs",
    "scripts/release/policy.json",
    ".github/workflows/validation.yml",
    ".github/workflows/staging-release.yml",
    "package.json",
    "package-lock.json",
    "docs/development/evidence/release01/proof.json",
  ])
    assert.throws(
      () => assertPolicySeparation([migration, path]),
      /separate PRs/,
    );
  assert.doesNotThrow(() =>
    assertPolicySeparation([
      migration,
      "supabase/tests/new.sql",
      "docs/development/map.md",
    ]),
  );
});
test("catalog proof permits an isolated denied private table", () => {
  const before = catalog(),
    after = structuredClone(before);
  after.tables.push({ ...table(), id: "private.isolated" });
  assert.equal(assertBoundedCatalog(before, after, candidate).length, 1);
  after.tables[1].columns[0].acl = "{anon=r/postgres}";
  assert.throws(
    () => assertBoundedCatalog(before, after, candidate),
    /direct client privileges/,
  );
});
for (const [label, mutate] of [
  ["RLS disabled", (c) => (c.tables[0].rls = false)],
  ["owner changed", (c) => (c.tables[0].owner = "authenticated")],
  ["column rewritten", (c) => (c.tables[0].columns[0].type = "text")],
  ["existing table removed", (c) => (c.tables = [])],
  [
    "DELETE added to already-readable role",
    (c) => {
      c.tables[0].access.authenticated.SELECT = true;
      c.tables[0].access.authenticated.DELETE = true;
    },
  ],
])
  test("confirmed unsafe catalog: " + label, () => {
    const before = catalog(),
      after = structuredClone(before);
    if (label.startsWith("DELETE"))
      before.tables[0].access.authenticated.SELECT = true;
    mutate(after);
    assert.throws(
      () => assertBoundedCatalog(before, after, candidate),
      UnsafeCatalogError,
    );
  });
for (const [label, mutate] of [
  ["function replaced with new OID", (c) => c.functions[0].oid++],
  ["definer context", (c) => (c.functions[0].config = [])],
  [
    "function privilege widened",
    (c) => (c.functions[0].acl += "authenticated=X"),
  ],
  [
    "hidden trigger",
    (c) =>
      c.triggers.push({
        id: "private.example.hidden",
        definition: "execute unsafe()",
      }),
  ],
  [
    "new direct table access",
    (c) => {
      const t = table();
      t.id = "private.new";
      t.access.anon.SELECT = true;
      c.tables.push(t);
    },
  ],
])
  test("unproven catalog is held: " + label, () => {
    const before = catalog(),
      after = structuredClone(before);
    mutate(after);
    assert.throws(() => assertBoundedCatalog(before, after, candidate));
  });
test("same signature body changes remain explicit effects for independent domain contracts", () => {
  const before = catalog(),
    after = structuredClone(before);
  after.functions[0].body = "wrong shared ledger";
  const effects = catalogEffects(before, after);
  assert.equal(effects[0].oid_retained, true);
  assert.notEqual(effects[0].before, effects[0].after);
  const other = structuredClone(after);
  other.functions[0].oid++;
  assert.equal(catalogEffects(before, other)[0].oid_retained, false);
});

test("one trusted private delegate retains the original object/body and exact caller contract", () => {
  const before = catalog();
  before.functions[0] = {
    ...fn(),
    id: "private.cocreate_recruitment_projection(p_id uuid)",
    source_body: "original",
  };
  const after = structuredClone(before);
  after.functions[0].oid = 43;
  after.functions[0].source_body = "new wrapper";
  after.functions.push({
    ...before.functions[0],
    id: "private.cocreate_recruitment_before_meetings(p_id uuid)",
  });
  const established = { classification: "established-contract-candidate" };
  assert.doesNotThrow(() => assertBoundedCatalog(before, after, established));
  assert.throws(() => assertBoundedCatalog(before, after, candidate));
  after.functions[1].source_body = "changed original";
  assert.throws(() => assertBoundedCatalog(before, after, established));
});
test("whole exact non-contiguous dependency chain qualifies before any apply", () => {
  const s = scenario(),
    decisions = authorize(s);
  assert.equal(decisions.length, 2);
  assert.equal(decisions[0].historical, true);
  assert.equal(decisions[0].authorization, "standing-verified-policy");
  assert.deepEqual(
    verifiedDeploymentSet(
      s.diff,
      {
        project_ref: STAGING_REF,
        migration_owner: "github-actions",
        staging_safety_version: 2,
      },
      decisions,
    ),
    s.diff.pending,
  );
  assert.throws(
    () =>
      verifiedDeploymentSet(
        s.diff,
        {
          project_ref: STAGING_REF,
          migration_owner: "github-actions",
          staging_safety_version: 2,
        },
        decisions.slice(0, 1),
      ),
    /Whole pending chain/,
  );
});
for (const [name, mutate] of [
  ["source drift", (s) => (s.evidence.source_sha = "c".repeat(40))],
  ["tree drift", (s) => (s.evidence.source_tree = "c".repeat(40))],
  [
    "validator changed",
    (s) => (s.evidence.policy_module_sha256 = "c".repeat(64)),
  ],
  ["wrong project", (s) => (s.diff.project_ref = "pnolarmzxmmjtguligfc")],
  ["SQL history drift", (s) => s.diff.drift.push({ reason: "changed bytes" })],
  [
    "fabricated effect digest",
    (s) =>
      s.evidence.migration_safety[0].catalog_effects.push({ id: "unverified" }),
  ],
  [
    "missing independent tests",
    (s) => (s.evidence.migration_safety[0].independent_contracts = false),
  ],
  [
    "held late dependency",
    (s) =>
      (s.evidence.migration_safety[1].status = "review-required-for-hosted"),
  ],
  [
    "stale predecessor",
    (s) =>
      (s.evidence.migration_safety[1].predecessor_inventory_sha256 = "c".repeat(
        64,
      )),
  ],
  ["changed migration", (s) => (s.local[0].sql += " select 2;")],
  [
    "reordered witnesses",
    (s) =>
      (s.evidence.migration_safety[0].predecessor_inventory_sha256 =
        s.evidence.migration_safety[1].predecessor_inventory_sha256),
  ],
  ...[
    "no_op_retry",
    "resource_auth_rest",
    "generated_types",
    "trusted_security_tests",
    "real_actor_denials",
    "storage_objects_preserved",
    "policy_negative_probes",
    "single_writer_probe",
  ].map((key) => [key, (s) => (s.evidence[key] = false)]),
])
  test("receipt fails closed: " + name, () => {
    const s = scenario();
    mutate(s);
    assert.throws(() => authorize(s));
  });
test("partial or interrupted writes require independently reconciled exact live predecessor", () => {
  for (const status of [
    "applying",
    "verified-prefix",
    "failed-unverified",
    "failed-partial",
    "unknown-write-outcome",
  ]) {
    const state = { workflow_run_id: 12, status };
    assert.throws(
      () => assertReconciledWriter(state, "a".repeat(64), {}),
      /Unreconciled/,
    );
    assert.throws(() =>
      assertReconciledWriter(state, "a".repeat(64), {
        STAGING_RECONCILED_FAILURE_RUN_ID: "12",
        STAGING_RECONCILED_PREDECESSOR_SHA256: "b".repeat(64),
      }),
    );
    assert.doesNotThrow(() =>
      assertReconciledWriter(state, "a".repeat(64), {
        STAGING_RECONCILED_FAILURE_RUN_ID: "12",
        STAGING_RECONCILED_PREDECESSOR_SHA256: "a".repeat(64),
      }),
    );
  }
  assert.doesNotThrow(() =>
    assertReconciledWriter({ status: "failed-before-write" }, "", {}),
  );
});
test("previous writer status comes from the protected run artifact; cancelled unknown writes hold", async () => {
  const run = {
    id: 10,
    event: "push",
    conclusion: "failure",
    head_sha: source,
  };
  const env = { GITHUB_RUN_ID: "11" };
  const state = {
    workflow_run_id: 10,
    source_sha: source,
    status: "failed-partial",
  };
  const api = async (path) =>
    path.includes("/artifacts")
      ? { artifacts: [{ name: "release-staging-10", expired: false }] }
      : { workflow_runs: [run] };
  assert.deepEqual(
    await previousWriterState(api, env, async () => state),
    state,
  );
  const unknown = await previousWriterState(async (path) => {
    if (path.includes("/artifacts")) return { artifacts: [] };
    if (path.includes("/jobs"))
      return {
        jobs: [
          {
            name: "staging",
            steps: [
              {
                name: "Preflight, classified migration apply, backend verification",
                conclusion: "cancelled",
              },
            ],
          },
        ],
      };
    if (path.includes("/contents/"))
      return {
        encoding: "base64",
        content: Buffer.from('{"staging_safety_version":2}').toString("base64"),
      };
    return { workflow_runs: [run] };
  }, env);
  assert.equal(unknown.status, "unknown-write-outcome");
});
test("trusted workflow selects pre-change engine for privileged SQL and keeps real replay probes", () => {
  const root = fileURLToPath(new URL("../../", import.meta.url));
  const workflow = readFileSync(
    root + "/.github/workflows/validation.yml",
    "utf8",
  );
  assert.match(
    workflow,
    /node build\/trusted-release\/scripts\/release\/reviews.mjs/,
  );
  assert.match(
    workflow,
    /node build\/trusted-release\/scripts\/release\/rehearse.mjs/,
  );
  const replay = readFileSync(root + "/scripts/release/rehearse.mjs", "utf8");
  for (const call of [
    "seedStorageWitness(",
    "realActorServiceDenials(",
    "mapPolicyNegativeControls(",
    "writerLockContract(",
  ])
    assert.ok(replay.includes(call));
});
