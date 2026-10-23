import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { verifyBackendHandoff } from "../release/backend-handoff.mjs";
import { sha256 } from "../release/sql-fingerprint.mjs";
const now = Date.parse("2026-10-23T12:00:00Z");
function fixture() {
  const env = {
    GITHUB_ACTIONS: "true",
    GITHUB_REPOSITORY: "lillo24/planets.community",
    GITHUB_REF: "refs/heads/main",
    GITHUB_SHA: "a".repeat(40),
    GITHUB_RUN_ID: "12",
    RELEASE_VARIANT: "closed-test-mock",
    GH_TOKEN: "fictional-actions-token",
  };
  const identity = {
    source_sha: env.GITHUB_SHA,
    workflow_run_id: env.GITHUB_RUN_ID,
  };
  const receipts = {
    backend: {
      ...identity,
      verified_at: new Date(now).toISOString(),
      project_ref: "cllpvruvrrvxczjitlqd",
      release_variant: "closed-test-mock",
      policy_sha256: sha256(readFileSync("scripts/release/policy.json")),
      pending: [],
      drift: [],
      checks: {
        missing_rpcs: [],
        unsafe_tables: [],
        storage_safe: true,
        grants_safe: true,
        map_safe: true,
      },
    },
    http: { ...identity, checks: [{}, {}, {}, {}] },
    deployment: { ...identity, status: "verified" },
  };
  const run = {
    id: 12,
    head_sha: env.GITHUB_SHA,
    head_branch: "main",
    path: ".github/workflows/staging-release.yml",
    event: "workflow_dispatch",
  };
  const job = {
    name: "staging",
    head_sha: env.GITHUB_SHA,
    conclusion: "success",
    steps: [
      {
        name: "Preflight, classified migration apply, backend verification",
        conclusion: "success",
      },
    ],
  };
  return {
    env,
    receipts,
    run,
    job,
    api: async (p) => (p.includes("/jobs?") ? { jobs: [job] } : run),
  };
}
test("signing consumes a fresh exact-source protected job without receiving a Supabase token", async () => {
  const s = fixture();
  assert.equal(s.env.SUPABASE_ACCESS_TOKEN, undefined);
  const result = await verifyBackendHandoff(s.receipts, s.env, s.api, now);
  assert.equal(result.source_sha, s.env.GITHUB_SHA);
  assert.equal(result.workflow_run_id, "12");
});
for (const [label, mutate] of [
  [
    "other project",
    (s) => (s.receipts.backend.project_ref = "pnolarmzxmmjtguligfc"),
  ],
  ["other source", (s) => (s.receipts.backend.source_sha = "b".repeat(40))],
  ["other run", (s) => (s.receipts.http.workflow_run_id = "11")],
  [
    "ordinary staging variant",
    (s) => (s.receipts.backend.release_variant = "staging"),
  ],
  [
    "changed policy",
    (s) => (s.receipts.backend.policy_sha256 = "b".repeat(64)),
  ],
  ["partial SQL", (s) => (s.receipts.deployment.status = "failed-partial")],
  ["unverified function", (s) => (s.receipts.backend.checks.map_safe = false)],
  [
    "string-shaped success",
    (s) => (s.receipts.backend.checks.map_safe = "false"),
  ],
  [
    "RPC gap",
    (s) => (s.receipts.backend.checks.missing_rpcs = ["required_rpc"]),
  ],
  [
    "old receipt",
    (s) =>
      (s.receipts.backend.verified_at = new Date(now - 900001).toISOString()),
  ],
  [
    "future receipt",
    (s) => (s.receipts.backend.verified_at = new Date(now + 1).toISOString()),
  ],
  ["missing privacy smoke", (s) => s.receipts.http.checks.pop()],
  ["wrong workflow", (s) => (s.run.path = ".github/workflows/untrusted.yml")],
  ["wrong job source", (s) => (s.job.head_sha = "b".repeat(40))],
  ["failed protected job", (s) => (s.job.conclusion = "failure")],
  ["unfinished protected step", (s) => (s.job.steps[0].conclusion = null)],
  ["PR build", (s) => (s.env.GITHUB_REF = "refs/pull/1/merge")],
])
  test("backend handoff rejects " + label, async () => {
    const s = fixture();
    mutate(s);
    await assert.rejects(() =>
      verifyBackendHandoff(s.receipts, s.env, s.api, now),
    );
  });
