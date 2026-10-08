import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { createRequire } from "node:module";
import { pathToFileURL } from "node:url";

const missingCase = "/admin/cases/00000000-0000-4000-8000-000000000000";

// Only anonymous, synthetic requests. This is not authenticated QA or a CPU benchmark.
export function parseProbeOrigin(value) {
  assert.equal(typeof value, "string", "Supply one explicit loopback origin.");
  const url = new URL(value);
  assert.ok(
    url.protocol === "http:" &&
      ["127.0.0.1", "localhost", "[::1]"].includes(url.hostname) &&
      !url.username &&
      !url.password &&
      url.pathname === "/" &&
      !url.search &&
      !url.hash,
    "The probe requires a credential-free HTTP loopback origin, without a path.",
  );
  return url.origin;
}

export function assertProbeResponse(response, body, expected) {
  assert.equal(response.status, expected.status, "Unexpected HTTP status.");
  assert.match(
    response.headers.get("cache-control") ?? "",
    /(?:^|[,\s])no-store(?:$|[,\s])/i,
    "Response must not be stored in a shared cache.",
  );
  if (expected.rscNotFound) {
    assert.match(
      response.headers.get("content-type") ?? "",
      /text\/x-component/,
    );
    assert.ok(
      body.includes("NEXT_HTTP_ERROR_FALLBACK;404"),
      "Missing RSC 404 digest.",
    );
  }
  if (expected.invite) {
    assert.match(response.headers.get("cache-control"), /private/);
    assert.equal(response.headers.get("referrer-policy"), "no-referrer");
    assert.equal(
      response.headers.get("x-robots-tag"),
      "noindex, nofollow, noarchive",
    );
  }
  if (expected.unauthorizedAction) {
    assert.ok(
      body.includes('"kind":"unauthorized"'),
      "Action must deny anonymous authority.",
    );
    assert.ok(
      !body.includes('"status":"success"'),
      "Action unexpectedly succeeded.",
    );
  }
}

async function request(origin, path, init, expected) {
  const started = performance.now();
  let response;
  let body;
  try {
    response = await fetch(`${origin}${path}`, {
      ...init,
      redirect: "manual",
      signal: AbortSignal.timeout(15_000),
    });
    body = await response.text();
    assert.equal(
      new URL(response.url).origin,
      origin,
      "Unexpected cross-origin redirect.",
    );
    assertProbeResponse(response, body, expected);
  } catch {
    // Do not print response bodies, action payloads, credentials or raw backend errors.
    throw new Error(
      `Hosting probe failed: ${init.method ?? "GET"} ${path}; expected ${expected.status} with no-store and the documented boundary.`,
    );
  }
  return {
    status: response.status,
    wallMs: Math.round(performance.now() - started),
    bytes: Buffer.byteLength(body),
    cacheControl: response.headers.get("cache-control"),
    contentType: response.headers.get("content-type"),
    setCookieCount: response.headers.getSetCookie().length,
  };
}

async function main() {
  assert.equal(
    process.argv.length,
    3,
    "Usage: node apps/web/scripts/probe-local-hosting.mjs http://127.0.0.1:3117",
  );
  const origin = parseProbeOrigin(process.argv[2]);
  const cases = [
    ["/", {}, { status: 200 }],
    ["/auth", {}, { status: 200 }],
    ["/admin", {}, { status: 404 }],
    [missingCase, {}, { status: 404 }],
    // Next 16 returns a not-found Flight digest with HTTP 200 here, also on Node.
    [
      "/admin?_rsc",
      { headers: { RSC: "1" } },
      { status: 200, rscNotFound: true },
    ],
    [
      `${missingCase}?_rsc`,
      { headers: { RSC: "1" } },
      { status: 200, rscNotFound: true },
    ],
    ["/invite/project/not-a-token", {}, { status: 200, invite: true }],
    ["/.well-known/assetlinks.json", {}, { status: 404 }],
    ["/.well-known/apple-app-site-association", {}, { status: 404 }],
    ["/tavoli/not-an-id", {}, { status: 404 }],
  ];
  for (const [path, init, expected] of cases) {
    const samples = [];
    for (let index = 0; index < 3; index++) {
      samples.push(await request(origin, path, init, expected));
    }
    console.log(JSON.stringify({ path, samples }));
  }

  const manifest = JSON.parse(
    await readFile(
      new URL(
        "../.next/server/server-reference-manifest.json",
        import.meta.url,
      ),
      "utf8",
    ),
  );
  const action = Object.entries(manifest.node).find(
    ([, value]) => value.exportedName === "moderationConsequenceAction",
  )?.[0];
  assert.ok(
    action,
    "Build the current app first; no consequence action found.",
  );
  // Use the exact installed Next transport encoder, not a forged/malformed form.
  // This internal test-only API must be rechecked when the pinned Next line changes.
  const { encodeReply } = createRequire(import.meta.url)(
    "next/dist/compiled/react-server-dom-turbopack/client.browser",
  );
  for (const originMatches of [true, false]) {
    const form = new FormData();
    for (const [key, value] of Object.entries({
      mode: "apply",
      caseId: "00000000-0000-4000-8000-000000000000",
      type: "safety_notice",
      userReason: "Synthetic local probe",
      internalNote: "Separate synthetic local note",
    }))
      form.set(key, value);
    const sample = await request(
      origin,
      missingCase,
      {
        method: "POST",
        headers: {
          "Next-Action": action,
          Origin: originMatches ? origin : "http://untrusted.invalid",
        },
        body: await encodeReply([{ status: "idle" }, form]),
      },
      { status: originMatches ? 200 : 500, unauthorizedAction: originMatches },
    );
    console.log(
      JSON.stringify({
        method: "POST",
        path: missingCase,
        originMatches,
        sample,
      }),
    );
  }
  console.log(
    "Anonymous hosting probe passed. Authenticated staff/browser/cookie isolation, monitoring, CPU and cloud quotas are NOT certified.",
  );
}

if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(process.argv[1]).href
) {
  main().catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
  });
}
