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
  const runs = await api(
    "/actions/workflows/staging-release.yml/runs?branch=main&per_page=20",
  );
  for (const run of runs.workflow_runs) {
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
    if (state) return state;
    if (["failure", "cancelled", "timed_out"].includes(run.conclusion)) {
      const jobs = await api(
        `/actions/runs/${run.id}/jobs?per_page=100&filter=latest`,
      );
      const writer = jobs.jobs.find((j) => j.name === "staging");
      if (
        writer?.steps.some(
          (s) =>
            s.name ===
              "Preflight, classified migration apply, backend verification" &&
            ["failure", "cancelled", "timed_out"].includes(s.conclusion),
        )
      ) {
        const file = await api(
          `/contents/scripts/release/policy.json?ref=${run.head_sha}`,
        );
        if (
          file.encoding === "base64" &&
          JSON.parse(Buffer.from(file.content, "base64"))
            .staging_safety_version === 2
        )
          return { workflow_run_id: run.id, status: "unknown-write-outcome" };
      }
    }
  }
  return null;
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
