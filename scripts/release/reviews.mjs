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
  if (!event.pull_request) {
    if (env.GITHUB_OUTPUT) appendFileSync(env.GITHUB_OUTPUT, "rehearse=true\n");
    console.log(
      "PR review gate: no PR delta; deploy re-verifies prior owner proof independently.",
    );
    return;
  }
  const pr = event.pull_request;
  const git = (args) => execFileSync("git", args, { encoding: "utf8" });
  if (env.GITHUB_OUTPUT)
    appendFileSync(
      env.GITHUB_OUTPUT,
      `rehearse=${requiresSafetyRehearsal(git(["diff", "--no-renames", "--name-only", pr.base.sha, pr.head.sha]).trim().split("\n"))}\n`,
    );
  const files = git([
    "diff",
    "--no-renames",
    "--name-status",
    pr.base.sha,
    pr.head.sha,
    "--",
    "supabase/migrations",
  ])
    .trim()
    .split("\n")
    .filter(Boolean);
  const local = readMigrations(process.cwd());
  const newFiles = [];
  for (const line of files) {
    const [status, path] = line.split("\t");
    if (status !== "A")
      throw new ReleaseError(
        "Canonical history edits/removals require separate reconciliation; add a new migration",
      );
    const m = local.find((m) => `supabase/migrations/${m.file}` === path);
    if (!m) throw new ReleaseError("Invalid new migration path");
    newFiles.push(m);
  }
  const prior = local.filter((m) => !newFiles.includes(m));
  const needed = [];
  for (const m of newFiles.sort((a, b) => a.version.localeCompare(b.version))) {
    const classification = classifyMigration(m.sql);
    if (classification.classification !== "routine-candidate")
      needed.push({
        version: m.version,
        sha256: m.sha256,
        predecessor_inventory_sha256: inventoryDigest(prior),
      });
    prior.push(m);
  }
  const reconciliation = JSON.parse(
    readFileSync("scripts/release/reconciliation.json", "utf8"),
  );
  const enabledBefore = (() => {
    try {
      return JSON.parse(
        git(["show", `${pr.base.sha}:scripts/release/reconciliation.json`]),
      ).enabled;
    } catch {
      return false;
    }
  })();
  if (reconciliation.enabled && !enabledBefore) {
    const observed = JSON.parse(
      readFileSync(
        "docs/development/evidence/release01/staging-auto01-predecessor.json",
        "utf8",
      ),
    );
    const base = observed.applied_history;
    for (const m of observed.pending) {
      needed.push({
        version: m.version,
        sha256: m.sha256,
        predecessor_inventory_sha256: inventoryDigest(base),
      });
      base.push({ version: m.version, canonical_sha256: m.sha256 });
    }
  }
  mkdirSync("build/release01", { recursive: true });
  writeFileSync(
    "build/release01/review-required.json",
    JSON.stringify(
      { project_ref: STAGING_REF, source_sha: pr.head.sha, approvals: needed },
      null,
      2,
    ) + "\n",
  );
  if (!needed.length) {
    console.log(
      "Migration safety: no review-required SQL; routine candidates still require catalog/data rehearsal.",
    );
    return;
  }
  const reviews = await ownerReviewsForPr(api, pr);
  if (
    needed.some(
      (n) =>
        !reviews.some(
          (r) =>
            r.version === n.version &&
            r.sha256 === n.sha256 &&
            r.predecessor_inventory_sha256 === n.predecessor_inventory_sha256,
        ),
    )
  )
    throw new ReleaseError(
      "Pre-merge owner review required: post STAGING-AUTO01-REVIEW plus the exact review-required.json object, then rerun this gate. No deployment approval can replace it.",
    );
  console.log(
    `Migration safety: ${needed.length} exact-content pre-merge owner reviews verified.`,
  );
}
if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(resolve(process.argv[1])).href
)
  checkPullRequest().catch(async (e) => {
    const { reportFailure } = await import("./errors.mjs");
    reportFailure("migration safety", e);
  });
