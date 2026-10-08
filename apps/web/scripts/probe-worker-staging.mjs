import assert from "node:assert/strict";

const origin = process.env.LINK_HOST01_PROBE_ORIGIN;
assert(
  [
    "http://127.0.0.1:8796",
    "https://planets-web-link-host01-staging.developer-planets-community.workers.dev",
  ].includes(origin),
  "Use only the isolated LINK-HOST-01 Worker origin.",
);
const summary = [];
async function read(path, init = {}) {
  const response = await fetch(origin + path, {
    ...init,
    redirect: "manual",
    signal: AbortSignal.timeout(20000),
  });
  const body = await response.text();
  assert(
    !/PLANETS could not load|temporarily unavailable|could not load public/iu.test(
      body,
    ),
    "App returned a failure screen.",
  );
  summary.push({
    path,
    method: init.method ?? "GET",
    status: response.status,
    contentType: response.headers.get("content-type"),
  });
  return { response, body };
}

for (const path of [
  "/.well-known/assetlinks.json",
  "/.well-known/apple-app-site-association",
]) {
  for (const method of ["GET", "HEAD"]) {
    const { response, body } = await read(path, {
      method,
      headers: { Cookie: "irrelevant=synthetic" },
    });
    assert.equal(response.status, 404);
    assert(response.headers.get("content-type").startsWith("application/json"));
    assert.equal(response.headers.get("cache-control"), "no-store");
    assert(
      !response.headers.has("set-cookie") && !response.headers.has("location"),
    );
    if (method === "GET")
      assert.equal(JSON.parse(body).error, "association_not_configured");
    else assert.equal(body, "");
  }
  assert.equal(
    (
      await read(path, {
        method: "POST",
        body: "synthetic",
        headers: { Origin: origin },
      })
    ).response.status,
    405,
  );
}

let authHtml;
for (const path of [
  "/auth?returnTo=%2Fproposals",
  "/profile?returnTo=%2Fjoin%2Fproject%2Finvalid-public-probe",
  "/join/project/invalid-public-probe",
  "/invite/project/invalid-public-probe",
  "/joined/proposals/00000000-0000-4000-8000-000000000000",
  "/admin",
]) {
  const { response, body } = await read(path);
  assert([200, 307, 404].includes(response.status));
  assert.equal(
    response.headers.get("cache-control"),
    "private, no-store, max-age=0",
  );
  assert.equal(response.headers.get("referrer-policy"), "no-referrer");
  assert(response.headers.get("x-robots-tag").includes("noindex"));
  if (response.headers.has("location"))
    assert.equal(
      new URL(response.headers.get("location"), origin).origin,
      origin,
    );
  if (path.startsWith("/auth")) {
    assert.equal(response.status, 200);
    authHtml = body;
  }
}
for (const path of ["/proposals", "/tavoli"]) {
  assert.equal((await read(path)).response.status, 200);
  const headers = { RSC: "1", "Next-Router-Prefetch": "1" };
  let { response } = await read(`${path}?_rsc=synthetic`, { headers });
  if (response.status === 307) {
    // vinext canonicalizes the RSC cache-bust hash to match transport headers.
    // Follow only this bounded same-origin transport redirect, retaining headers.
    const location = new URL(response.headers.get("location"), origin);
    assert.equal(location.origin, origin);
    assert.equal(location.pathname, path);
    assert.deepEqual([...location.searchParams.keys()], ["_rsc"]);
    ({ response } = await read(location.pathname + location.search, {
      headers,
    }));
  }
  assert.equal(response.status, 200);
  assert(response.headers.get("content-type").startsWith("text/x-component"));
  assert.equal((await read(path, { method: "HEAD" })).body, "");
}
// The existing public Proposal loading boundary starts HTML streaming before
// its async notFound. Preserve its explicit 404 digest; do not mistake the
// HTTP-200 streamed shell for a successful detail or a Site fallback.
const missingProposal = await read(
  "/proposals/00000000-0000-4000-8000-000000000000",
);
assert(
  missingProposal.response.status === 404 ||
    (missingProposal.response.status === 200 &&
      missingProposal.body.includes("NEXT_HTTP_ERROR_FALLBACK;404")),
);
for (const path of [
  "/tavoli/00000000-0000-4000-8000-000000000000",
  "/admin/missing",
  "/_next/static/missing.js",
])
  assert.equal((await read(path)).response.status, 404);
const assets = [
  ...authHtml.matchAll(/(?:src|href)="(\/_next\/static\/[^"\s]+)"/gu),
].map((match) => match[1]);
assert(assets.length > 0, "No emitted app assets found.");
for (const path of [...new Set(assets)].slice(0, 4))
  assert.equal((await read(path)).response.status, 200);
assert.equal(
  (
    await read("/auth", {
      method: "POST",
      body: "synthetic",
      headers: { Origin: "https://evil.invalid" },
    })
  ).response.status,
  400,
);
assert.equal(
  (
    await read("/auth", {
      headers: {
        "X-Forwarded-Host": "evil.invalid",
        "X-Forwarded-Proto": "http",
      },
    })
  ).response.status,
  200,
);
console.log(
  JSON.stringify(
    { origin, passed: summary.length, requests: summary },
    null,
    2,
  ),
);
