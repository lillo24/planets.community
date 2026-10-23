import { readFileSync } from "node:fs";
import { ReleaseError } from "./errors.mjs";
import { releaseVariant } from "./config.mjs";
import { assertBackendReady, STAGING_REF } from "./migrations.mjs";
import { githubClient } from "./reviews.mjs";
import { sha256 } from "./sql-fingerprint.mjs";

// A signing job receives verified metadata from this run's protected staging
// job. It never receives or copies that environment's Supabase credential.
export async function verifyBackendHandoff(
  { backend, http, deployment },
  env,
  api = githubClient(env),
  now = Date.now(),
) {
  const verified = Date.parse(backend?.verified_at ?? "");
  if (
    env.GITHUB_ACTIONS !== "true" ||
    env.GITHUB_REPOSITORY !== "lillo24/planets.community" ||
    env.GITHUB_REF !== "refs/heads/main" ||
    !/^[a-f0-9]{40}$/.test(env.GITHUB_SHA ?? "") ||
    !/^[1-9][0-9]*$/.test(env.GITHUB_RUN_ID ?? "") ||
    backend?.source_sha !== env.GITHUB_SHA ||
    http?.source_sha !== env.GITHUB_SHA ||
    deployment?.source_sha !== env.GITHUB_SHA ||
    String(backend?.workflow_run_id) !== env.GITHUB_RUN_ID ||
    String(http?.workflow_run_id) !== env.GITHUB_RUN_ID ||
    String(deployment?.workflow_run_id) !== env.GITHUB_RUN_ID ||
    backend?.project_ref !== STAGING_REF ||
    backend?.release_variant !== releaseVariant(env) ||
    backend?.policy_sha256 !==
      sha256(readFileSync("scripts/release/policy.json")) ||
    deployment?.status !== "verified" ||
    !Number.isFinite(verified) ||
    verified > now ||
    now - verified > 15 * 60_000 ||
    !Array.isArray(backend?.pending) ||
    !Array.isArray(backend?.drift) ||
    !Array.isArray(backend?.checks?.missing_rpcs) ||
    !Array.isArray(backend?.checks?.unsafe_tables) ||
    backend.checks.storage_safe !== true ||
    backend.checks.grants_safe !== true ||
    backend.checks.map_safe !== true ||
    !Array.isArray(http?.checks) ||
    http.checks.length !== 4
  )
    throw new ReleaseError("Missing/stale same-run protected backend handoff");
  assertBackendReady(backend, backend.checks);
  const run = await api(`/actions/runs/${env.GITHUB_RUN_ID}`);
  const jobs = await api(
    `/actions/runs/${env.GITHUB_RUN_ID}/jobs?per_page=100&filter=latest`,
  );
  const job = jobs.jobs?.find((j) => j.name === "staging");
  if (
    run.id !== Number(env.GITHUB_RUN_ID) ||
    run.head_sha !== env.GITHUB_SHA ||
    run.head_branch !== "main" ||
    run.path !== ".github/workflows/staging-release.yml" ||
    run.event !== "workflow_dispatch" ||
    job?.head_sha !== env.GITHUB_SHA ||
    job?.conclusion !== "success" ||
    !job.steps?.some(
      (s) =>
        s.name ===
          "Preflight, classified migration apply, backend verification" &&
        s.conclusion === "success",
    )
  )
    throw new ReleaseError(
      "Protected staging job has not verified this exact build run",
    );
  return {
    source_sha: env.GITHUB_SHA,
    workflow_run_id: env.GITHUB_RUN_ID,
    verified_at: backend.verified_at,
  };
}
