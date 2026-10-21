import { ReleaseError, reportFailure } from "./errors.mjs";
import { mkdirSync, writeFileSync } from "node:fs";
import { setTimeout } from "node:timers/promises";

export async function requireFullValidation(
  env = process.env,
  fetcher = fetch,
  wait = setTimeout,
) {
  const sha = env.GITHUB_SHA;
  if (
    env.GITHUB_REF !== "refs/heads/main" ||
    !/^[a-f0-9]{40}$/.test(sha ?? "") ||
    !env.GH_TOKEN
  )
    throw new ReleaseError(
      "Release validation requires current main and Actions token",
    );
  const base = `https://api.github.com/repos/${env.GITHUB_REPOSITORY}`;
  async function api(path, body) {
    const r = await fetcher(`${base}${path}`, {
      method: body ? "POST" : "GET",
      headers: {
        Authorization: `Bearer ${env.GH_TOKEN}`,
        Accept: "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
      },
      ...(body && { body: JSON.stringify(body) }),
      signal: AbortSignal.timeout(60000),
    });
    if (!r.ok)
      throw new ReleaseError(
        `Release validation API failed (HTTP ${r.status})`,
      );
    return r.status === 204 ? null : r.json();
  }
  if ((await api("/git/ref/heads/main")).object.sha !== sha)
    throw new ReleaseError("Main advanced; start a new release run");
  const list = () =>
    api(
      `/actions/workflows/validation.yml/runs?event=workflow_dispatch&head_sha=${sha}&per_page=50`,
    );
  const previous = (await list()).workflow_runs;
  let run = previous.find(
    (r) => r.head_sha === sha && r.conclusion === "success",
  );
  if (!run) {
    const lastId = Math.max(0, ...previous.map((r) => r.id));
    await api("/actions/workflows/validation.yml/dispatches", { ref: "main" });
    for (let i = 0; i < 150; i++) {
      await wait(20000);
      run = (await list()).workflow_runs.find(
        (r) => r.id > lastId && r.head_sha === sha,
      );
      if (run?.status === "completed") break;
    }
  }
  if (!run || run.conclusion !== "success")
    throw new ReleaseError(
      "Exact-source complete Validation did not pass; release blocked",
    );
  const jobs = (
    await api(`/actions/runs/${run.id}/jobs?per_page=100&filter=latest`)
  ).jobs;
  for (const name of [
    "Change classification",
    "Mobile",
    "Database",
    "Web",
    "Site",
  ]) {
    if (!jobs.some((job) => job.name === name && job.conclusion === "success"))
      throw new ReleaseError(
        `Release requires ${name} success; skipped is insufficient`,
      );
  }
  if ((await api("/git/ref/heads/main")).object.sha !== sha)
    throw new ReleaseError(
      "Main advanced during validation; start a new release run",
    );
  mkdirSync("build/release01", { recursive: true });
  writeFileSync(
    "build/release01/validation.json",
    JSON.stringify(
      {
        source_sha: sha,
        run_id: run.id,
        url: run.html_url,
        areas: ["Mobile", "Database", "Web", "Site"],
      },
      null,
      2,
    ),
  );
  console.log(`Complete exact-source Validation passed: ${run.html_url}`);
}

if (process.argv[1]?.endsWith("validation.mjs"))
  requireFullValidation().catch((error) => reportFailure("Validation", error));
