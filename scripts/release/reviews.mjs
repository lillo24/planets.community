import { ReleaseError } from "./errors.mjs";
import { execFileSync } from "node:child_process";
import {
  readFileSync,
  writeFileSync,
  mkdirSync,
  appendFileSync,
} from "node:fs";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";
import { classifyMigration, inventoryDigest } from "./safety.mjs";
import { readMigrations, STAGING_REF } from "./migrations.mjs";
import { sha256 } from "./sql-fingerprint.mjs";
import {
  assertPolicySeparation,
  migrationCandidate,
  policyModuleHash,
} from "./eligibility.mjs";

export const REVIEW_PREFIX = "STAGING-AUTO01-REVIEW\n";
export function requiresSafetyRehearsal(paths) {
  return paths.some(
    (p) =>
      !/\.(md|mdx)$/i.test(p) &&
      /^(supabase\/migrations\/|scripts\/release\/|scripts\/lib\/(release01|staging-auto01)\.test\.mjs$|docs\/development\/evidence\/release01\/(migration-manifest|staging-auto01-predecessor)\.json$|\.github\/workflows\/(validation|staging-release)\.yml$|package(-lock)?\.json$)/.test(
        p,
      ),
  );
}
const hash = /^[a-f0-9]{64}$/,
  commit = /^[a-f0-9]{40}$/;
export function githubClient(env = process.env, fetcher = fetch) {
  if (!env.GH_TOKEN || env.GITHUB_REPOSITORY !== "lillo24/planets.community")
    throw new ReleaseError("Missing Actions identity/token for staging proof");
  return async (path) => {
    const response = await fetcher(
      `https://api.github.com/repos/${env.GITHUB_REPOSITORY}${path}`,
      {
        headers: {
          Authorization: `Bearer ${env.GH_TOKEN}`,
          Accept: "application/vnd.github+json",
          "X-GitHub-Api-Version": "2022-11-28",
        },
        signal: AbortSignal.timeout(60000),
      },
    );
    if (!response.ok)
      throw new ReleaseError(
        `Staging proof API failed (HTTP ${response.status})`,
      );
    return response.json();
  };
}
export function reviewEntries(comments, pr, ownerId) {
  if (!commit.test(pr.head?.sha ?? ""))
    throw new ReleaseError("Invalid review source");
  const output = [];
  for (const c of comments) {
    if (
      c.user?.id !== ownerId ||
      c.user?.type !== "User" ||
      typeof c.body !== "string" ||
      !c.body.startsWith(REVIEW_PREFIX)
    )
      continue;
    // A post-merge comment cannot retroactively authorize an unreviewed merge.
    const created = Date.parse(c.created_at),
      updated = Date.parse(c.updated_at);
    if (
      !Number.isFinite(created) ||
      !Number.isFinite(updated) ||
      (pr.merged_at &&
        (!Number.isFinite(Date.parse(pr.merged_at)) ||
          created > Date.parse(pr.merged_at) ||
          updated > Date.parse(pr.merged_at)))
    )
      continue;
    let proof;
    try {
      proof = JSON.parse(c.body.slice(REVIEW_PREFIX.length));
    } catch {
      continue;
    }
    if (
      !proof ||
      typeof proof !== "object" ||
      Array.isArray(proof) ||
      Object.keys(proof).sort().join(",") !==
        "approvals,project_ref,source_sha" ||
      proof.project_ref !== STAGING_REF ||
      proof.source_sha !== pr.head.sha ||
      !Array.isArray(proof.approvals) ||
      proof.approvals.length > 128
    )
      continue;
    for (const a of proof.approvals) {
      if (
        !a ||
        typeof a !== "object" ||
        Array.isArray(a) ||
        Object.keys(a).sort().join(",") !==
          "predecessor_inventory_sha256,sha256,version" ||
        !/^\d{14}$/.test(a.version) ||
        !hash.test(a.sha256) ||
        !hash.test(a.predecessor_inventory_sha256)
      )
        continue;
      output.push({ ...a, pr: pr.number, comment_id: c.id });
    }
  }
  return output;
}
async function commentsFor(api, number) {
  const comments = [];
  for (let page = 1; page <= 10; page++) {
    const rows = await api(
      `/issues/${number}/comments?per_page=100&page=${page}`,
    );
    comments.push(...rows);
    if (rows.length < 100) return comments;
  }
  throw new ReleaseError(
    "Review pagination limit exceeded; reconcile explicitly",
  );
}
export async function ownerReviewsForPr(api, pr) {
  const repo = await api("");
  if (
    pr.base?.ref !== "main" ||
    pr.base?.repo?.full_name !== "lillo24/planets.community" ||
    pr.head?.repo?.full_name !== "lillo24/planets.community"
  )
    throw new ReleaseError("Review must belong to a same-repository main PR");
  return reviewEntries(await commentsFor(api, pr.number), pr, repo.owner.id);
}
export async function deploymentReviews(
  local,
  paths,
  api,
  git = (args) => execFileSync("git", args, { encoding: "utf8" }).trim(),
) {
  const proofs = [];
  for (const { path, migrations } of paths) {
    const changed = git(["log", "-1", "--format=%H", "--", path]);
    if (!commit.test(changed))
      throw new ReleaseError("Cannot identify migration review origin");
    const prs = await api(`/commits/${changed}/pulls?per_page=100`);
    for (const pr of prs.filter((p) => p.merged_at)) {
      const entries = await ownerReviewsForPr(api, pr);
      for (const m of migrations) {
        const matching = entries.filter(
          (e) => e.version === m.version && e.sha256 === m.sha256,
        );
        if (!matching.length) continue;
        const content = await api(
          `/contents/supabase/migrations/${m.file}?ref=${pr.head.sha}`,
        );
        if (
          content.encoding !== "base64" ||
          sha256(Buffer.from(content.content, "base64")) !== m.sha256
        )
          continue;
        proofs.push(...matching);
      }
    }
  }
  return proofs;
}

export async function checkPullRequest(
  env = process.env,
  api = githubClient(env),
) {
  const event = JSON.parse(readFileSync(env.GITHUB_EVENT_PATH, "utf8"));
  // Legacy owner-comment readers above remain for auditing old deployments.
  // They are not an authorization path under the standing staging policy.
  const git = (args) => execFileSync("git", args, { encoding: "utf8" }).trim();
  const paths = event.pull_request
    ? git([
        "diff",
        "--no-renames",
        "--name-only",
        event.pull_request.base.sha,
        event.pull_request.head.sha,
      ])
        .split("\n")
        .filter(Boolean)
    : [];
  assertPolicySeparation(paths);
  if (env.GITHUB_OUTPUT)
    appendFileSync(
      env.GITHUB_OUTPUT,
      `rehearse=${!event.pull_request || requiresSafetyRehearsal(paths)}\n`,
    );
  const local = readMigrations(process.cwd());
  const added = [];
  if (event.pull_request) {
    for (const line of git([
      "diff",
      "--no-renames",
      "--name-status",
      event.pull_request.base.sha,
      event.pull_request.head.sha,
      "--",
      "supabase/migrations",
    ])
      .split("\n")
      .filter(Boolean)) {
      const [status, path] = line.split("\t");
      if (status !== "A")
        throw new ReleaseError(
          "Canonical history edits/removals are unsafe; add a migration",
        );
      const m = local.find((m) => `supabase/migrations/${m.file}` === path);
      if (!m) throw new ReleaseError("Unparseable canonical migration path");
      let candidate;
      try {
        candidate = migrationCandidate(m);
      } catch (error) {
        if (!(error instanceof ReleaseError)) throw error;
        candidate = { classification: "blocked-unsafe", reason: error.message };
      }
      added.push({
        version: m.version,
        sha256: m.sha256,
        candidate: candidate.classification,
        status:
          candidate.classification === "blocked-unsafe"
            ? "blocked-unsafe"
            : "review-required-for-hosted",
        reason:
          candidate.classification === "blocked-unsafe"
            ? candidate.reason
            : "Awaiting populated catalog/security/real-actor proof",
      });
    }
  }
  mkdirSync("build/release01", { recursive: true });
  writeFileSync(
    "build/release01/staging-eligibility.json",
    JSON.stringify(
      {
        policy_version: 2,
        source_sha: git(["rev-parse", "HEAD"]),
        pr_head_sha: event.pull_request?.head.sha ?? null,
        source_tree: git(["rev-parse", "HEAD^{tree}"]),
        policy_module_sha256: policyModuleHash(),
        migration_safety: added,
      },
      null,
      2,
    ) + "\n",
  );
  console.log(
    "Source safety: no owner fingerprint required; hosted eligibility awaits independent populated/security proof.",
  );
  const blocked = added.find((m) => m.status === "blocked-unsafe");
  if (blocked)
    throw new ReleaseError(
      `Migration ${blocked.version} blocked-unsafe: ${blocked.reason}`,
    );
  return;
}
if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(resolve(process.argv[1])).href
)
  checkPullRequest().catch(async (e) => {
    const { reportFailure } = await import("./errors.mjs");
    reportFailure("migration safety", e);
  });
