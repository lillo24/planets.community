import assert from "node:assert/strict";
import { readFileSync, mkdirSync } from "node:fs";
import { resolve, basename } from "node:path";
import { TraceMap, originalPositionFor } from "@jridgewell/trace-mapping";

export const workerName = "planets-web-link-host01-staging";
export const accountId = "5e9cf144fb13c9913f8570b32d7288a8";
export const localOrigin = "http://127.0.0.1:8796";
export const hostedOrigin =
  "https://planets-web-link-host01-staging.developer-planets-community.workers.dev";
export const outputDirectory = resolve(".wrangler/link-host02");

export function outputFile(label, suffix) {
  assert(
    /^[a-z][a-z0-9-]{0,50}$/.test(label),
    "Use a short diagnostic label, not a URL or path.",
  );
  assert(/^[a-z0-9.-]+$/.test(suffix), "Invalid diagnostic suffix.");
  mkdirSync(outputDirectory, { recursive: true });
  return resolve(outputDirectory, `${label}-${suffix}`);
}

export function checkGeneratedConfig() {
  const config = JSON.parse(readFileSync("dist/server/wrangler.json", "utf8"));
  assert(
    config.name === workerName &&
      config.workers_dev &&
      !config.routes?.length &&
      !config.observability?.enabled,
    "Refusing non-isolated Worker configuration.",
  );
  return config;
}

export function probeCases(asset) {
  assert(
    /^\/_next\/static\/[a-zA-Z0-9_./-]+$/.test(asset),
    "Invalid emitted static asset.",
  );
  assert.equal(
    new URL(asset, localOrigin).pathname,
    asset,
    "Refusing normalized asset traversal.",
  );
  return [
    {
      name: "auth",
      path: "/auth?returnTo=%2Fproposals",
      status: 200,
      check: (b) => b.includes("Sign"),
    },
    { name: "public-list", path: "/proposals", status: 200 },
    {
      name: "public-detail-missing",
      path: "/proposals/00000000-0000-4000-8000-000000000000",
      status: 200,
      check: (b) => b.includes("NEXT_HTTP_ERROR_FALLBACK;404"),
    },
    {
      name: "malformed-invite",
      path: "/join/project/invalid-public-probe",
      status: 200,
    },
    {
      name: "confirmation-signed-out",
      path: "/joined/proposals/00000000-0000-4000-8000-000000000000",
      status: 200,
    },
    {
      name: "auth-redirect",
      path: "/profile?returnTo=%2Fproposals",
      status: 307,
    },
    {
      name: "rsc",
      path: "/proposals",
      status: 200,
      headers: { RSC: "1" },
      contentType: "text/x-component",
    },
    {
      name: "association",
      path: "/.well-known/assetlinks.json",
      status: 404,
      contentType: "application/json",
    },
    { name: "static-asset", path: asset, status: 200 },
  ];
}

export function validateResponse(spec, response, body) {
  assert.equal(response.status, spec.status, `Unexpected ${spec.name} status`);
  assert(
    !/PLANETS could not load|temporarily unavailable|could not load public/iu.test(
      body,
    ),
    "App returned a failure screen.",
  );
  if (spec.contentType)
    assert(response.headers.get("content-type")?.startsWith(spec.contentType));
  if (spec.check) assert(spec.check(body), `Unexpected ${spec.name} body`);
}

export function rscDestination(origin, location) {
  assert([localOrigin, hostedOrigin].includes(origin));
  assert(location, "Missing RSC redirect");
  const url = new URL(location, origin);
  assert.equal(url.origin, origin);
  assert.equal(url.pathname, "/proposals");
  assert(!url.username && !url.password && !url.hash);
  assert.deepEqual([...url.searchParams.keys()], ["_rsc"]);
  return url.pathname + url.search;
}

export async function canonicalizeRsc(origin, spec) {
  const response = await fetch(origin + spec.path, {
    headers: spec.headers,
    redirect: "manual",
    signal: AbortSignal.timeout(30000),
  });
  await response.text();
  assert.equal(response.status, 307);
  spec.path = rscDestination(origin, response.headers.get("location"));
}

export function distribution(rows) {
  const values = rows.map((r) => r.activeMs).sort((a, b) => a - b);
  const q = (fraction) =>
    values[Math.ceil(values.length * fraction) - 1] ?? null;
  return {
    n: rows.length,
    errors: rows.filter((r) => r.error).length,
    p50: q(0.5),
    p95: q(0.95),
    max: values.at(-1) ?? null,
  };
}

// Same non-idle sample-delta method as pinned Wrangler's startup summary.
// These are local sampling estimates, not Cloudflare CPU billing counters.
export function summarizeProfile(
  profile,
  locate = (frame) => ({
    source: frame.url || "native",
    function: frame.functionName || "(anonymous)",
  }),
) {
  assert.equal(profile.samples.length, profile.timeDeltas.length);
  const nodes = new Map(profile.nodes.map((n) => [n.id, n]));
  const groups = new Map();
  let active = 0,
    idle = 0,
    gc = 0,
    unattributed = 0,
    longGaps = 0;
  profile.samples.forEach((id, i) => {
    const node = nodes.get(id),
      us = profile.timeDeltas[i];
    assert(
      node && Number.isFinite(us) && us >= 0,
      "Invalid CPU profile sample",
    );
    if (us > 10000) longGaps++;
    if (node.callFrame.functionName === "(idle)") {
      idle += us;
      return;
    }
    active += us;
    if (node.callFrame.functionName === "(garbage collector)") gc += us;
    if (
      node.callFrame.functionName === "(program)" ||
      (!node.callFrame.functionName && !node.callFrame.url)
    )
      unattributed += us;
    const key = JSON.stringify(locate(node.callFrame));
    const group = groups.get(key) ?? { us: 0, samples: 0 };
    group.us += us;
    group.samples++;
    groups.set(key, group);
  });
  return {
    activeMs: active / 1000,
    idleMs: idle / 1000,
    gcMs: gc / 1000,
    unattributedMs: unattributed / 1000,
    longGaps,
    samples: profile.samples.length,
    top: [...groups]
      .sort((a, b) => b[1].us - a[1].us)
      .slice(0, 20)
      .map(([k, v]) => ({
        ...JSON.parse(k),
        ms: v.us / 1000,
        samples: v.samples,
      })),
  };
}

export function sourceLocator() {
  const maps = new Map();
  return (frame) => {
    const url = frame.url;
    let mapped;
    if (url && frame.lineNumber >= 0) {
      // Only generated module names; never read an arbitrary inspector URL.
      const artifact =
        /^(?:ssr\/)?(?:index\.js|_next\/static\/[a-zA-Z0-9_.-]+\.js)$/.test(
          url,
        );
      if (artifact) {
        if (!maps.has(url)) {
          try {
            maps.set(
              url,
              new TraceMap(
                JSON.parse(
                  readFileSync(resolve("dist/server", url + ".map"), "utf8"),
                ),
              ),
            );
          } catch (error) {
            if (error.code !== "ENOENT") throw error;
            maps.set(url, null);
          }
        }
        if (maps.get(url))
          mapped = originalPositionFor(maps.get(url), {
            line: frame.lineNumber + 1,
            column: frame.columnNumber,
          });
      }
    }
    const raw = (mapped?.source ?? url).replaceAll("\\", "/");
    const source =
      raw.match(/(?:node_modules|src|worker)\/.*$/)?.[0] ??
      (url.startsWith("ssr/") || url.startsWith("_next/")
        ? url
        : basename(raw) || "native");
    return {
      source,
      function: mapped?.name || frame.functionName || "(anonymous)",
      line: mapped?.line ?? frame.lineNumber + 1,
    };
  };
}

export function cloudflareToken() {
  // OAuth stays in the existing Wrangler store. Never serialize credentials.
  const token =
    process.env.CLOUDFLARE_API_TOKEN ||
    readFileSync(
      resolve(process.env.APPDATA, "xdg.config/.wrangler/config/default.toml"),
      "utf8",
    ).match(/oauth_token\s*=\s*"([^"]+)"/)?.[1];
  assert(
    token,
    "Set CLOUDFLARE_API_TOKEN or use the existing Windows Wrangler OAuth login.",
  );
  return token;
}

export async function currentVersion(token) {
  const response = await fetch(
    `https://api.cloudflare.com/client/v4/accounts/${accountId}/workers/scripts/${workerName}/deployments`,
    { headers: { Authorization: `Bearer ${token}` } },
  );
  assert(response.ok, `Deployment metadata HTTP ${response.status}`);
  const data = await response.json();
  assert(
    data.success &&
      data.result.deployments[0].versions.length === 1 &&
      data.result.deployments[0].versions[0].percentage === 100,
    "Expected one fully deployed staging version",
  );
  return data.result.deployments[0].versions[0].version_id;
}
