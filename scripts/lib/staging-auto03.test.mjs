import test from "node:test";
import { execFileSync } from "node:child_process";
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
  predecessorCatalog,
  assertPredecessorCatalog,
} from "../release/eligibility.mjs";
import { STAGING_REF, verifiedDeploymentSet } from "../release/migrations.mjs";
import { inventoryDigest } from "../release/safety.mjs";
import { sha256 } from "../release/sql-fingerprint.mjs";
import { writeStaging } from "../release/writer.mjs";
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
  expressions_safe: true,
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
  event_triggers: [],
});
const candidate = { classification: "private-additive-candidate" };
test("global DDL callbacks are part of the predecessor and cannot change through an additive candidate", () => {
  const before = catalog();
  const event = {
    id: "ensure_rls",
    owner: "postgres",
    event: "ddl_command_end",
    enabled: "O",
    tags: ["CREATE TABLE"],
    function: "public.rls_auto_enable()",
  };
  before.event_triggers = [event];
  assert.doesNotThrow(() =>
    assertPredecessorCatalog(predecessorCatalog(before), before),
  );
  for (const mutate of [
    (c) =>
      c.event_triggers.push({
        ...event,
        id: "hidden_callback",
        function: "private.hidden()",
      }),
    (c) => (c.event_triggers[0].enabled = "D"),
    (c) => (c.event_triggers[0].function = "private.changed()"),
    (c) => (c.event_triggers[0].tags = ["ALTER TABLE"]),
    (c) => (c.event_triggers[0].owner = "authenticated"),
    (c) => (c.event_triggers = []),
  ]) {
    const changed = structuredClone(before);
    mutate(changed);
    assert.throws(() =>
      assertPredecessorCatalog(predecessorCatalog(before), changed),
    );
    assert.throws(
      () => assertBoundedCatalog(before, changed, candidate),
      /global DDL/,
    );
  }
  const incomplete = predecessorCatalog(before);
  delete incomplete.event_triggers;
  assert.throws(
    () => assertPredecessorCatalog(incomplete, before),
    /Incomplete/,
  );
  const omittedBefore = catalog(),
    newSection = catalog();
  delete omittedBefore.event_triggers;
  newSection.event_triggers = [event];
  assert.equal(
    catalogEffects(omittedBefore, newSection)[0].section,
    "event_triggers",
  );
});
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
      predecessor_catalog: predecessorCatalog(catalog()),
      predecessor_catalog_sha256: sha256(
        JSON.stringify(predecessorCatalog(catalog())),
      ),
      no_op_retry: true,
      resource_auth_rest: true,
      generated_types: true,
      trusted_security_tests: true,
      real_actor_denials: true,
      storage_objects_preserved: true,
      policy_negative_probes: true,
      single_writer_probe: true,
      cli_startup_bounds: true,
      hosted_runtime_callback: true,
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

test("private defaults, references, initial values and index expressions cannot hide privileged effects", () => {
  for (const sql of [
    "create table private.example(id uuid references auth.users(id));",
    "create table private.example(id text default public.read_private_profile());",
    "create table private.example(id integer check(id #! 1));",
    privateTable +
      "insert into private.example values(private.mutate_profile());",
    privateTable +
      "create index example_expr on private.example(public.private_lookup(id));",
  ])
    assert.equal(
      inspectAdditive(sql).classification,
      "review-required-for-hosted",
    );
});
test("basemap names cannot authorize another relation, callee or configuration write", () => {
  const sql = execFileSync(
    "git",
    [
      "show",
      "b20c20758f6addfa1a15b670b6155e09cac614f6:supabase/migrations/20261023054839_mapmock01_shared_public_basemap.sql",
    ],
    { encoding: "utf8" },
  );
  assert.equal(
    inspectAdditive(sql).classification,
    "mock-basemap-contract-candidate",
  );
  for (const changed of [
    sql.replace(
      "select * into cfg from private.location_provider_config",
      "select * into cfg from private.real_user_secret",
    ),
    sql.replace(
      "perform 1 from private.location_search_config",
      "update private.location_provider_config set daily_units_limit=800000; perform 1 from private.location_search_config",
    ),
    sql.replace("where bucket<day", "where true"),
    sql.replace(
      "return 'ok';",
      "perform public.get_own_profile_photo(null); return 'ok';",
    ),
  ]) {
    assert.notEqual(changed, sql);
    assert.equal(
      inspectAdditive(changed).classification,
      "review-required-for-hosted",
    );
  }
  // Structure alone cannot prove accounting semantics: the real independent
  // PostgreSQL contracts must still reject both unchanged-signature mutants.
  assert.equal(
    inspectAdditive(sql.replaceAll("'units:global'", "'units:shadow'"))
      .classification,
    "mock-basemap-contract-candidate",
  );
  assert.equal(
    inspectAdditive(
      sql.replaceAll("cfg.daily_units_limit/4", "cfg.daily_units_limit"),
    ).classification,
    "mock-basemap-contract-candidate",
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

test("isolated additions cannot use unknown type IO or remove an existing table permission", () => {
  const before = catalog(),
    after = structuredClone(before);
  after.tables.push({
    ...table(),
    id: "private.new",
    columns: [{ name: "value", type: "public.unproven_domain" }],
  });
  assert.throws(
    () => assertBoundedCatalog(before, after, candidate),
    /unproven type/,
  );
  after.tables.pop();
  before.tables[0].access.authenticated.SELECT = true;
  assert.throws(
    () => assertBoundedCatalog(before, after, candidate),
    /permission contract/,
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
    "cli_startup_bounds",
    "hosted_runtime_callback",
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

test("rejected pre-apply proof records a known no-write failure before returning", async () => {
  const receipts = [];
  await assert.rejects(() =>
    writeStaging({
      diff: { pending: [{}], project_ref: "pnolarmzxmmjtguligfc" },
      policy: { staging_safety_version: 2 },
      env: {
        GITHUB_SHA: source,
        GITHUB_RUN_ID: "12",
        STAGING_RECOVERY_MODE: "development-no-backup",
      },
      save: (name, value) => receipts.push({ name, value }),
    }),
  );
  assert.equal(receipts[0].name, "deployment");
  assert.equal(receipts[0].value.status, "failed-before-write");
  assert.equal(receipts[0].value.attempt_started, false);
  assertReconciledWriter(receipts[0].value, "unneeded", {});
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

test("a hundred unrelated runs cannot hide an earlier unresolved writer", async () => {
  const harmless = Array.from({ length: 100 }, (_, i) => ({
    id: 1000 - i,
    event: "workflow_dispatch",
    head_sha: source,
  }));
  const failed = { id: 10, event: "push", head_sha: source };
  const state = {
    workflow_run_id: 10,
    source_sha: source,
    status: "failed-partial",
  };
  const pages = [];
  const api = async (path) => {
    if (path.includes("/actions/workflows/")) {
      pages.push(path);
      return { workflow_runs: path.endsWith("page=1") ? harmless : [failed] };
    }
    if (path.includes("/artifacts"))
      return {
        artifacts: path.includes("/10/")
          ? [{ name: "release-staging-10", expired: false }]
          : [],
      };
    if (path.includes("/jobs")) return { jobs: [] };
    assert.fail("Unexpected API path");
  };
  assert.deepEqual(
    await previousWriterState(
      api,
      { GITHUB_RUN_ID: "2000" },
      async () => state,
    ),
    state,
  );
  assert.equal(pages.length, 2);
  assert.throws(
    () => assertReconciledWriter(state, "current", {}),
    /Unreconciled/,
  );
});
test("expired artifacts retain only actual protected writer success; never infer partial success", async () => {
  const run = { id: 10, event: "push", head_sha: source };
  const base = {
    name: "staging",
    head_sha: source,
    conclusion: "success",
    steps: [
      {
        name: "Preflight, classified migration apply, backend verification",
        status: "completed",
        conclusion: "success",
      },
    ],
  };
  const api = (writer) => async (path) => {
    if (path.includes("/actions/workflows/")) return { workflow_runs: [run] };
    if (path.includes("/artifacts"))
      return { artifacts: [{ name: "release-staging-10", expired: true }] };
    if (path.includes("/jobs")) return { jobs: [writer] };
    if (path.includes("/contents/"))
      return {
        encoding: "base64",
        content: Buffer.from('{"staging_safety_version":2}').toString("base64"),
      };
    assert.fail("Unexpected API path");
  };
  assert.equal((await previousWriterState(api(base), {})).status, "verified");
  const failed = structuredClone(base);
  failed.conclusion = "failure";
  failed.steps[0].conclusion = "failure";
  assert.equal(
    (await previousWriterState(api(failed), {})).status,
    "unknown-write-outcome",
  );
  const wrong = structuredClone(base);
  wrong.head_sha = "b".repeat(40);
  assert.equal(
    (await previousWriterState(api(wrong), {})).status,
    "unknown-write-outcome",
  );
});

test("a later rejected preflight does not reconcile an older partial apply", async () => {
  const runs = [
    { id: 11, event: "push", head_sha: source },
    { id: 10, event: "push", head_sha: source },
  ];
  const states = {
    11: {
      workflow_run_id: 11,
      source_sha: source,
      status: "failed-before-write",
    },
    10: { workflow_run_id: 10, source_sha: source, status: "failed-partial" },
  };
  const api = async (path) => {
    if (path.includes("/artifacts")) {
      const id = path.includes("/11/") ? 11 : 10;
      return { artifacts: [{ name: `release-staging-${id}`, expired: false }] };
    }
    return { workflow_runs: runs };
  };
  assert.equal(
    (
      await previousWriterState(
        api,
        { GITHUB_RUN_ID: "12" },
        async (id) => states[id],
      )
    ).workflow_run_id,
    10,
  );
});
test("a no-pending protected deployment cannot erase an unreconciled write", async () => {
  const receipts = [];
  const historyApi = async (path) => {
    if (path.includes("/actions/workflows/"))
      return { workflow_runs: [{ id: 10, event: "push", head_sha: source }] };
    if (path.includes("/artifacts")) return { artifacts: [] };
    if (path.includes("/jobs"))
      return {
        jobs: [
          {
            name: "staging",
            steps: [
              {
                name: "Preflight, classified migration apply, backend verification",
                status: "completed",
                conclusion: "failure",
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
    assert.fail("Unexpected API path");
  };
  await assert.rejects(
    () =>
      writeStaging({
        diff: { pending: [], predecessor_sha256: "current" },
        remote: [],
        env: {
          GITHUB_ACTIONS: "true",
          GITHUB_RUN_ID: "11",
          GITHUB_SHA: source,
        },
        historyApi,
        save: (name, value) => receipts.push({ name, value }),
      }),
    /Unreconciled/,
  );
  assert.ok(receipts.every((r) => r.value.status === "failed-before-write"));
});
test("pre-write catalog covers unchanged helpers and ignores only provider-owned internals", () => {
  const before = catalog();
  before.functions.push({
    ...fn(),
    id: "auth.provider_internal()",
    body: "vendor-old",
  });
  const after = structuredClone(before);
  after.functions[0].oid = 999; // same canonical definition, different disposable/live OID
  after.functions[1].body = "vendor-new";
  assert.doesNotThrow(() =>
    assertPredecessorCatalog(predecessorCatalog(before), after),
  );
  after.functions[0].body = "unknown out-of-band domain edit";
  assert.throws(
    () => assertPredecessorCatalog(predecessorCatalog(before), after),
    /predecessor catalog drift/,
  );
  after.functions[0].body = before.functions[0].body;
  after.functions.push({ ...fn(), id: "public.hidden_callee()" });
  assert.throws(
    () => assertPredecessorCatalog(predecessorCatalog(before), after),
    /hidden_callee/,
  );
});
test("resolved custom expression dependencies cannot become isolated additive proof", () => {
  const before = catalog(),
    after = structuredClone(before);
  after.tables.push({ ...table(), id: "private.new", expressions_safe: false });
  assert.throws(
    () => assertBoundedCatalog(before, after, candidate),
    /unproven function/,
  );
});
test("a fabricated earlier receipt with another source cannot clear a partial hold", async () => {
  const api = async (path) =>
    path.includes("/artifacts")
      ? { artifacts: [{ name: "release-staging-10", expired: false }] }
      : { workflow_runs: [{ id: 10, event: "push", head_sha: source }] };
  await assert.rejects(
    () =>
      previousWriterState(api, {}, async () => ({
        workflow_run_id: 10,
        source_sha: "b".repeat(40),
        status: "verified",
      })),
    /protected source/,
  );
});
