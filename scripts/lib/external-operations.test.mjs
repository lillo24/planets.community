import assert from "node:assert/strict";
import test from "node:test";
import { readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { ActivityImportError } from "./external-activities/transport.mjs";
import { runActivityImport } from "./external-activities/importer.mjs";
import {
  activityOperationArguments,
  activityOperationTarget,
  activityRefreshPolicy,
  runActivityOperations,
} from "./external-activities/operations.mjs";

const municipal = "trento-open-sports-facilities";
const snapshot = {
  state: "success",
  fetched: 0,
  accepted: 0,
  rejected: 0,
  changed: 0,
};
const code = (expected) => (error) =>
  error instanceof ActivityImportError && error.code === expected;
function harness(overrides = {}) {
  const calls = [];
  const ids = ["source-a", "source-b"];
  const sources = ids.map((id) => ({
    id,
    configured: true,
    enabled: true,
    rights_confirmed: true,
    lease_state: "idle",
    last_success_at: null,
  }));
  const settings = {
    sources: ids,
    mode: "apply",
    resolve: (id) => ({ sourceId: id }),
    store: {
      maintain: async () => {
        calls.push("maintain");
        return { expired_leases: 0, pruned_runs: 0 };
      },
      inspect: async () => ({ as_of: "2026-10-23T12:00:00Z", sources }),
    },
    importSource: async ({ connector }) => {
      calls.push(connector.sourceId);
      return { ...snapshot };
    },
    ...overrides,
  };
  return { settings, calls, sources };
}

test("source set is explicit, bounded and code owned; default starts no provider", () => {
  assert.throws(
    () => activityOperationArguments(["--dry-run"], {}),
    code("source_set_required"),
  );
  assert.deepEqual(
    activityOperationArguments(["--dry-run"], { ACTIVITIES_SOURCES: municipal })
      .sources,
    [municipal],
  );
  for (const sources of [
    "",
    `${municipal},${municipal}`,
    "source-a",
    " agenda-trento",
    "agenda-trento,,",
  ]) {
    assert.throws(() =>
      activityOperationArguments(["--sources", sources, "--dry-run"], {}),
    );
  }
  for (const args of [
    ["--apply"],
    ["--inspect"],
    ["--dry-run", "--target", "x"],
    ["--dry-run", "--due-only"],
    ["--maintain", "--apply"],
  ]) {
    assert.throws(() => activityOperationArguments(args, {}));
  }
  const run = spawnSync(
    process.execPath,
    ["scripts/operate-external-activities.mjs", "--dry-run"],
    { encoding: "utf8", env: { ...process.env, ACTIVITIES_SOURCES: "" } },
  );
  assert.equal(run.status, 1);
  assert.match(run.stderr, /source_set_required/);
  assert.equal(run.stdout, "");
});
test("target equality and local/HTTPS URL rules fail before writes", () => {
  const env = {
    ACTIVITIES_API_URL: "http://127.0.0.1:54921",
    ACTIVITIES_SERVICE_ROLE_KEY: "synthetic-private",
    ACTIVITIES_TARGET: "owned-local",
  };
  assert.equal(
    activityOperationTarget({ target: "owned-local" }, env).apiUrl,
    env.ACTIVITIES_API_URL,
  );
  assert.throws(
    () => activityOperationTarget({ target: "other" }, env),
    code("missing_explicit_target"),
  );
  for (const url of [
    "http://remote.example.org",
    "https://user:pass@example.org",
    "https://example.org?secret=x",
    "not-a-url",
  ])
    assert.throws(
      () =>
        activityOperationTarget(
          { target: "owned-local" },
          { ...env, ACTIVITIES_API_URL: url },
        ),
      code("invalid_target"),
    );
});
test("private cadence defaults daily, bounded whole days, cannot add sources/origins", () => {
  assert.equal(activityRefreshPolicy()[municipal], 24);
  assert.equal(
    activityRefreshPolicy(JSON.stringify({ [municipal]: 72 }))[municipal],
    72,
  );
  for (const value of [
    "null",
    "[]",
    "{",
    '{"source-a":24}',
    JSON.stringify({ [municipal]: 12 }),
    JSON.stringify({ [municipal]: 169 }),
    JSON.stringify({ [municipal]: 25 }),
  ])
    assert.throws(
      () => activityRefreshPolicy(value),
      code("invalid_refresh_policy"),
    );
});
test("A succeeds / B fails: independent results and non-success overall, safe bounded error", async () => {
  const { settings, calls } = harness();
  settings.importSource = async ({ connector }) => {
    calls.push(connector.sourceId);
    if (connector.sourceId === "source-b")
      throw new Error("secret https://private.example.org?token=x");
    return snapshot;
  };
  const result = await runActivityOperations(settings);
  assert.equal(result.status, "partial");
  assert.deepEqual(calls, ["maintain", "source-a", "source-b"]);
  assert.deepEqual(result.sources[1], {
    id: "source-b",
    state: "failed",
    code: "internal_error",
  });
  assert.doesNotMatch(JSON.stringify(result), /private\.example|secret|token=/);
});
test("rights/coverage blocked B causes no provider IO and A still succeeds", async () => {
  for (const blocked of ["agenda-trento", "odh-trento-sports"]) {
    const { settings, calls } = harness();
    settings.sources = ["source-a", blocked];
    settings.store.inspect = async () => ({
      as_of: new Date().toISOString(),
      sources: settings.sources.map((id) => ({
        id,
        configured: true,
        enabled: true,
        rights_confirmed: true,
      })),
    });
    settings.resolve = (id) => {
      if (id === blocked)
        throw new ActivityImportError(
          blocked === "agenda-trento"
            ? "source_rights_checkpoint_blocked"
            : "source_coverage_checkpoint_blocked",
        );
      return { sourceId: id };
    };
    const result = await runActivityOperations(settings);
    assert.equal(result.status, "partial");
    assert.deepEqual(calls, ["maintain", "source-a"]);
    assert.match(result.sources[1].code, /checkpoint_blocked$/);
  }
});
test("all disabled, unconfigured, unlicensed, busy and all failed remain failures", async () => {
  for (const state of [
    "disabled",
    "unconfigured",
    "rights_blocked",
    "busy",
    "failed",
  ]) {
    const { settings, sources, calls } = harness();
    for (const source of sources) {
      if (state === "disabled") source.enabled = false;
      if (state === "unconfigured") source.configured = false;
      if (state === "rights_blocked") source.rights_confirmed = false;
      if (state === "busy") source.lease_state = "running";
    }
    if (state === "failed")
      settings.importSource = async () => {
        throw new ActivityImportError("upstream_error");
      };
    const result = await runActivityOperations(settings);
    assert.equal(result.status, "failure");
    assert.ok(result.sources.every((x) => x.state === state));
    assert.deepEqual(calls, ["maintain"]);
  }
});
test("empty complete traversal is healthy; due scheduling uses backend success time", async () => {
  const { settings, sources, calls } = harness({
    dueOnly: true,
    policy: { "source-a": 24, "source-b": 24 },
  });
  sources[0].last_success_at = "2026-10-23T11:00:00Z";
  sources[1].last_success_at = "2026-10-22T11:00:00Z";
  const result = await runActivityOperations(settings);
  assert.equal(result.status, "success");
  assert.equal(result.sources[0].state, "not_due");
  assert.equal(result.sources[1].accepted, 0);
  assert.deepEqual(calls, ["maintain", "source-b"]);
});
test("unknown municipal type summary is actionable warning, not green or destructive loss", async () => {
  const { settings } = harness({
    importSource: async () => ({
      ...snapshot,
      source_summary: { unknown_types: 1 },
    }),
  });
  const result = await runActivityOperations(settings);
  assert.equal(result.status, "failure");
  assert.ok(
    result.sources.every(
      (x) => x.code === "unknown_source_types" && x.state === "warning",
    ),
  );
});
test("manual dry-run never calls inspection, maintenance or persistence", async () => {
  const { settings, calls } = harness({ mode: "dry-run" });
  settings.importSource = async ({ apply, store, connector }) => {
    assert.equal(apply, false);
    // Exercise the real importer with a complete zero-record connector.
    return runActivityImport({
      apply,
      store,
      connector: {
        ...connector,
        origins: ["https://example.org"],
        apiPathPrefix: "/api/",
        collect: async () => ({ complete: true, entries: [] }),
      },
    });
  };
  assert.equal((await runActivityOperations(settings)).status, "success");
  assert.deepEqual(calls, []);
});
test("unexpected record validation drift cannot become a green zero-accepted export", async () => {
  const { settings } = harness({
    mode: "dry-run",
    importSource: runActivityImport,
  });
  settings.resolve = (sourceId) => ({
    sourceId,
    origins: ["https://example.org"],
    officialOrigin: "https://example.org",
    apiPathPrefix: "/api/",
    collect: async () => ({
      complete: true,
      entries: [{ record: { upstream_id: "malformed" } }],
    }),
  });
  const result = await runActivityOperations(settings);
  assert.equal(result.status, "failure");
  assert.ok(
    result.sources.every(
      (x) => x.state === "failed" && x.code === "source_record_drift",
    ),
  );
});
test("valid subset with unexpected rejected rows keeps explicit nonzero operator warning", async () => {
  const { settings } = harness({
    mode: "dry-run",
    importSource: runActivityImport,
  });
  settings.resolve = (sourceId) => ({
    sourceId,
    origins: ["https://example.org"],
    officialOrigin: "https://example.org",
    apiPathPrefix: "/api/",
    collect: async () => ({
      complete: true,
      entries: [
        {
          record: {
            upstream_id: "good",
            title: "Synthetic valid place",
            description: null,
            kind: "place",
            category: "sports",
            source_categories: [],
            canonical_url: "https://example.org/place",
            status: "scheduled",
            publishable: true,
            occurrences: [],
          },
        },
        { record: { upstream_id: "bad" } },
      ],
    }),
  });
  const result = await runActivityOperations(settings);
  assert.equal(result.status, "failure");
  assert.ok(
    result.sources.every(
      (x) =>
        x.state === "warning" &&
        x.code === "source_record_drift" &&
        x.accepted === 1 &&
        x.rejected === 1 &&
        x.invalid_records === 1,
    ),
  );
});
test("parent timeout records interrupted receipt and skips subsequent provider attempts", async () => {
  const { settings, calls } = harness({
    runMs: 20,
    importSource: runActivityImport,
  });
  const receipts = [];
  settings.store.begin = async () => {
    calls.push("begin");
    return { run_id: "synthetic", started_at: new Date().toISOString() };
  };
  settings.store.finish = async (id, input) => {
    receipts.push(input);
    return { state: input.state };
  };
  settings.resolve = (id) => ({
    sourceId: id,
    origins: ["https://example.org"],
    apiPathPrefix: "/api/",
    collect: () => new Promise(() => {}),
  });
  const result = await runActivityOperations(settings);
  assert.equal(result.status, "failure");
  assert.ok(result.sources.every((x) => x.code === "deadline"));
  assert.deepEqual(calls, ["maintain", "begin"]);
  assert.equal(receipts[0].errorCode, "deadline");
  assert.deepEqual(receipts[0].records, []);
});
test("pre-interrupted operation cannot create a lease; standalone maintenance needs no connector", async () => {
  const controller = new AbortController();
  controller.abort();
  const { settings, calls } = harness({ parentSignal: controller.signal });
  await assert.rejects(() => runActivityOperations(settings), code("deadline"));
  assert.deepEqual(calls, []);
  const maintenance = harness({
    mode: "maintain",
    resolve: () => {
      throw new Error("must not resolve");
    },
  });
  assert.equal(
    (await runActivityOperations(maintenance.settings)).status,
    "success",
  );
  assert.deepEqual(maintenance.calls, ["maintain"]);
});
test("lost completion response remains unconfirmed and never claimed as a stored failure", async () => {
  const { settings } = harness({
    importSource: async () => {
      throw new ActivityImportError("completion_unconfirmed");
    },
  });
  const result = await runActivityOperations(settings);
  assert.ok(result.sources.every((x) => x.code === "completion_unconfirmed"));
  assert.equal(result.status, "failure");
});
test("interrupt arriving while a lease is claimed cannot start collection", async () => {
  const controller = new AbortController();
  let collected = false;
  let failure;
  await assert.rejects(
    () =>
      runActivityImport({
        apply: true,
        parentSignal: controller.signal,
        connector: {
          sourceId: "synthetic",
          collect: async () => {
            collected = true;
            return new Promise(() => {});
          },
        },
        store: {
          begin: async () => {
            controller.abort();
            return {
              run_id: "synthetic",
              started_at: new Date().toISOString(),
            };
          },
          finish: async (id, input) => {
            failure = input;
          },
        },
      }),
    code("deadline"),
  );
  assert.equal(collected, false);
  assert.equal(failure.errorCode, "deadline");
});
test("workflow remains gated to main/owner, least privilege, serial target and bounded job", () => {
  const yaml = readFileSync(
    ".github/workflows/external-activities.yml",
    "utf8",
  );
  assert.match(yaml, /github\.repository == 'lillo24\/planets\.community'/);
  assert.match(yaml, /github\.ref == 'refs\/heads\/main'/);
  assert.match(yaml, /vars\.ACTIVITIES_IMPORT_ENABLED == 'true'/);
  assert.match(yaml, /contents: read/);
  assert.doesNotMatch(yaml, /pull_request|contents: write|id-token: write/);
  assert.match(yaml, /cancel-in-progress: false/);
  assert.match(yaml, /timeout-minutes: 10/);
  assert.match(
    yaml,
    /ACTIVITIES_SOURCES: \$\{\{ vars\.ACTIVITIES_SOURCES \}\}/,
  );
  assert.match(yaml, /extra\+=\(--due-only\)/);
  assert.match(yaml, /default: false/);
  assert.doesNotMatch(yaml, /--source agenda-trento/);
});
