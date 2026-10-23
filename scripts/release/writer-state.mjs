import { ReleaseError } from "./errors.mjs";
import { mkdtempSync, readFileSync, rmSync, statSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

export function assertReconciledWriter(state, predecessor, env) {
  if (!state || ["verified", "failed-before-write"].includes(state.status))
    return;
  if (
    env.STAGING_RECONCILED_FAILURE_RUN_ID !== String(state.workflow_run_id) ||
    env.STAGING_RECONCILED_PREDECESSOR_SHA256 !== predecessor
  )
    throw new ReleaseError(
      `Unreconciled staging writer ${state.workflow_run_id}; inspect actual history/catalog/data before setting the protected reconciliation run and predecessor`,
    );
}
// Read only protected main's own sanitized artifacts; no token/DB URL is logged.
export async function previousWriterState(api, env, load = loadArtifact) {
  // Read-only/failed-preflight runs cannot push an unresolved writer out of a
  // fixed lookback. Bound API cost explicitly and fail closed if history is longer.
  for (let page = 1; page <= 10; page++) {
    const response = await api(
      `/actions/workflows/staging-release.yml/runs?branch=main&per_page=100&page=${page}`,
    );
    if (!Array.isArray(response.workflow_runs))
      throw new ReleaseError(
        "Cannot independently enumerate staging writer history",
      );
    for (const run of response.workflow_runs) {
      if (
        String(run.id) === env.GITHUB_RUN_ID ||
        !["push", "workflow_dispatch"].includes(run.event)
      )
        continue;
      const artifacts = await api(
        `/actions/runs/${run.id}/artifacts?per_page=100`,
      );
      const artifact = artifacts.artifacts.find(
        (a) => a.name === `release-staging-${run.id}` && !a.expired,
      );
      const state = artifact ? await load(run.id, artifact.name, env) : null;
      if (state) {
        if (
          state.source_sha !== run.head_sha ||
          String(state.workflow_run_id) !== String(run.id)
        )
          throw new ReleaseError(
            "Previous staging receipt does not match its protected source/run",
          );
        return state;
      }
      const jobs = await api(
        `/actions/runs/${run.id}/jobs?per_page=100&filter=latest`,
      );
      const writer = jobs.jobs.find((j) => j.name === "staging");
      const step = writer?.steps.find(
        (s) =>
          s.name ===
            "Preflight, classified migration apply, backend verification" &&
          s.status !== "queued" &&
          s.conclusion !== "skipped",
      );
      if (!step) continue;
      const file = await api(
        `/contents/scripts/release/policy.json?ref=${run.head_sha}`,
      );
      if (file.encoding !== "base64")
        throw new ReleaseError(
          "Cannot independently identify the previous staging policy",
        );
      const version = JSON.parse(
        Buffer.from(file.content, "base64"),
      ).staging_safety_version;
      if (version === 1) return null; // Before standing-policy activation; legacy audit.
      if (version !== 2)
        throw new ReleaseError("Unknown previous staging writer policy");
      // Artifact retention must not erase a later verified reconciliation.
      // The protected job's actual success persists independently of its ZIP.
      if (
        writer.conclusion === "success" &&
        step.conclusion === "success" &&
        writer.head_sha === run.head_sha
      )
        return {
          workflow_run_id: run.id,
          source_sha: run.head_sha,
          status: "verified",
          verification: "protected-job-success",
        };
      return {
        workflow_run_id: run.id,
        source_sha: run.head_sha,
        status: "unknown-write-outcome",
      };
    }
    if (response.workflow_runs.length < 100) return null;
  }
  throw new ReleaseError(
    "Staging writer history exceeds the bounded audit; independently reconcile before writing",
  );
}
function loadArtifact(run, name, env) {
  const directory = mkdtempSync(join(tmpdir(), "planets-writer-state-"));
  try {
    const r = spawnSync(
      "gh",
      [
        "run",
        "download",
        String(run),
        "--repo",
        env.GITHUB_REPOSITORY,
        "--name",
        name,
        "--dir",
        directory,
      ],
      {
        env: { ...process.env, GH_TOKEN: env.GH_TOKEN },
        encoding: "utf8",
        timeout: 60000,
        maxBuffer: 16384,
      },
    );
    if (r.status !== 0 || r.error)
      throw new ReleaseError(
        "Cannot independently read the previous staging writer receipt",
      );
    let size;
    try {
      size = statSync(join(directory, "deployment.json")).size;
    } catch (error) {
      if (error.code === "ENOENT") return null;
      throw error;
    }
    if (size > 131072)
      throw new ReleaseError("Oversized staging writer receipt");
    const state = JSON.parse(
      readFileSync(join(directory, "deployment.json"), "utf8"),
    );
    if (
      String(state.workflow_run_id) !== String(run) ||
      !/^[a-f0-9]{40}$/.test(state.source_sha ?? "")
    )
      throw new ReleaseError("Staging writer receipt identity mismatch");
    return state;
  } finally {
    // Exact mkdtemp-owned directory, not a caller-provided deletion target.
    rmSync(directory, { recursive: true, force: true });
  }
}
