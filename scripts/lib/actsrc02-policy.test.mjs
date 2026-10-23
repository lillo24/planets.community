import test from "node:test";
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import {
  SOURCE_INDEX_RETIREMENT as contract,
  migrationCandidate,
  inspectAdditive,
  assertBoundedCatalog,
  assertSourceIndexRetirementCatalog,
  UnsafeCatalogError,
  authorizeVerifiedPending,
  policyModuleHash,
  predecessorCatalog,
} from "../release/eligibility.mjs";
import { STAGING_REF } from "../release/migrations.mjs";
import { inventoryDigest } from "../release/safety.mjs";
import { sha256 } from "../release/sql-fingerprint.mjs";

// Immutable UNTRUSTED candidate input, not canonical SQL or deployment approval.
const sql = execFileSync(
  "git",
  [
    "show",
    `a6edec44cd3af17cd0b6bb339d74327ceceda488:supabase/migrations/${contract.file}`,
  ],
  { encoding: "utf8" },
);
const migration = { ...contract, sql };
const privileges = () =>
  Object.fromEntries(
    ["anon", "authenticated", "service_role"].map((r) => [
      r,
      Object.fromEntries(
        [
          "SELECT",
          "INSERT",
          "UPDATE",
          "DELETE",
          "TRUNCATE",
          "REFERENCES",
          "TRIGGER",
        ].map((p) => [p, false]),
      ),
    ]),
  );
function catalogs() {
  const before = {
    tables: [
      "external_activity_sources",
      "external_activities",
      "external_activity_runs",
      "external_activity_occurrences",
    ].map((name) => ({
      id: `private.${name}`,
      owner: "postgres",
      rls: true,
      forced: false,
      columns: [{ name: "id", type: "text", acl: "" }],
      access: privileges(),
    })),
    functions: [],
    policies: [],
    triggers: [],
    views: [],
    constraints: [
      {
        id: "private.external_activity_sources.external_activity_sources_pkey",
        definition: "PRIMARY KEY (source_id)",
      },
      {
        id: "private.external_activities.external_activities_source_id_upstream_id_key",
        definition: "UNIQUE (source_id, upstream_id)",
      },
    ],
    indexes: [
      {
        id: contract.id,
        table: contract.table,
        definition: contract.definition,
      },
      {
        id: "private.external_activity_sources_pkey",
        table: contract.table,
        definition: "source primary key",
      },
      {
        id: "private.unrelated",
        table: "private.external_activity_runs",
        definition: "run index",
      },
    ],
  };
  const after = structuredClone(before);
  after.indexes.shift();
  return { before, after };
}
const candidate = { classification: contract.classification };

test("only exact ACTSRC02 bytes and identity select the source-only contract", () => {
  assert.equal(sha256(sql), contract.sha256);
  assert.equal(
    migrationCandidate(migration).classification,
    contract.classification,
  );
  // Generic DROP handling is unchanged, including this index without its pin.
  assert.equal(inspectAdditive(sql).classification, "blocked-unsafe");
  for (const m of [
    { ...migration, sql: sql + "\n" },
    { ...migration, sha256: "a".repeat(64) },
    { ...migration, version: "20261023093758" },
    { ...migration, file: "20261023093757_other.sql" },
  ])
    assert.equal(migrationCandidate(m).classification, "blocked-unsafe");
  for (const statement of [
    "drop index private.external_activity_one_enabled_source;",
    "drop index private.external_activities_pkey;",
    "drop table private.external_activity_sources;",
    "truncate private.external_activities;",
  ])
    assert.equal(inspectAdditive(statement).classification, "blocked-unsafe");
});

test("source-only proof retires exactly the expected index while ordinary proof still rejects it", () => {
  const { before, after } = catalogs();
  assert.equal(assertSourceIndexRetirementCatalog(before, after), contract.id);
  assert.equal(assertBoundedCatalog(before, after, candidate).length, 1);
  assert.throws(
    () =>
      assertBoundedCatalog(before, after, {
        classification: "private-additive-candidate",
      }),
    UnsafeCatalogError,
  );
});

for (const [label, mutate] of [
  ["wrong table", (b) => (b.indexes[0].table = "private.external_activities")],
  [
    "wrong key",
    (b) =>
      (b.indexes[0].definition = contract.definition.replace(
        "(enabled)",
        "(source_id)",
      )),
  ],
  ["wrong predicate", (b) => (b.indexes[0].definition += " AND false")],
  ["predecessor missing", (b) => b.indexes.shift()],
  ["identity predecessor missing", (b) => b.constraints.shift()],
  ["index still exists", (b, a) => a.indexes.push(b.indexes[0])],
  ["unrelated index lost", (b, a) => a.indexes.pop()],
  [
    "retained index redefined",
    (b, a) => (a.indexes[0].definition += " changed"),
  ],
  ["identity constraint lost", (b, a) => a.constraints.pop()],
  [
    "identity constraint redefined",
    (b, a) => (a.constraints[0].definition = "PRIMARY KEY (other)"),
  ],
  ["RLS disabled", (b, a) => (a.tables[0].rls = false)],
  ["owner changed", (b, a) => (a.tables[0].owner = "authenticated")],
  ["anon widened", (b, a) => (a.tables[0].access.anon.SELECT = true)],
  [
    "service widened",
    (b, a) => (a.tables[2].access.service_role.UPDATE = true),
  ],
  [
    "column grant",
    (b, a) => (a.tables[0].columns[0].acl = "{anon=r/postgres}"),
  ],
  [
    "unsafe predecessor",
    (b) => (b.tables[0].access.authenticated.SELECT = true),
  ],
])
  test(`source-only contract rejects ${label}`, () => {
    const { before, after } = catalogs();
    mutate(before, after);
    assert.throws(
      () => assertBoundedCatalog(before, after, candidate),
      UnsafeCatalogError,
    );
  });

test("a promoted source-only witness cannot authorize any hosted pending write", () => {
  const source = "a".repeat(40),
    tree = "b".repeat(40),
    local = [migration];
  const predecessor = predecessorCatalog(catalogs().before);
  const evidence = {
    policy_version: 2,
    project_ref: STAGING_REF,
    source_sha: source,
    source_tree: tree,
    policy_module_sha256: policyModuleHash(),
    inventory_sha256: inventoryDigest(local),
    predecessor_catalog: predecessor,
    predecessor_catalog_sha256: sha256(JSON.stringify(predecessor)),
    no_op_retry: true,
    resource_auth_rest: true,
    generated_types: true,
    trusted_security_tests: true,
    real_actor_denials: true,
    storage_objects_preserved: true,
    policy_negative_probes: true,
    single_writer_probe: true,
    cli_startup_bounds: true,
    migration_safety: [
      {
        version: migration.version,
        sha256: migration.sha256,
        predecessor_inventory_sha256: inventoryDigest([]),
        preserved_rows: true,
        catalog_verified: true,
        independent_contracts: true,
        status: "auto-eligible-for-staging",
        catalog_effects: [],
        effect_sha256: sha256("[]"),
      },
    ],
  };
  const diff = {
    project_ref: STAGING_REF,
    drift: [],
    pending: [{ version: migration.version, sha256: migration.sha256 }],
  };
  assert.throws(
    () => authorizeVerifiedPending(diff, local, evidence, source, tree),
    /source-only; hosted application/,
  );
});
