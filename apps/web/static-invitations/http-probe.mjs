import assert from "node:assert/strict";
import { hostedOrigin } from "./cloudflare.mjs";
const origin = process.argv[2];
assert(
  ["http://127.0.0.1:8797", hostedOrigin].includes(origin),
  "Use the isolated local/staging host.",
);
const uuid = "fb030300-0000-4000-8000-000000000002";
const cases = [
  ["/", "GET", 200],
  ["/auth", "GET", 200],
  ["/profile?returnTo=%2F%2Fevil.invalid", "GET", 200],
  ["/join/project/" + "a".repeat(43), "GET", 200],
  [`/joined/proposals/${uuid}`, "GET", 200],
  [`/joined/tavoli/${uuid}`, "GET", 200],
  ["/auth", "HEAD", 200],
  ["/join/project/bad", "GET", 404],
  ["/join/project/%41".repeat(1), "GET", 404],
  ["/admin", "GET", 404],
  ["/api/unknown", "GET", 404],
  ["/.well-known/assetlinks.json", "GET", 404],
  ["/.well-known/apple-app-site-association", "HEAD", 404],
  ["/proposals/" + uuid, "GET", 404],
  ["/invite/project/" + "a".repeat(43), "GET", 404],
  ["/index.html", "GET", 404],
  ["/assets/missing.js", "GET", 404],
  ["/auth", "POST", 405],
  ["/auth", "OPTIONS", 405],
  ["/join/project/" + "a".repeat(43), "PUT", 405],
];
const shell = await fetch(origin + "/auth").then((r) => r.text());
const assets = [...shell.matchAll(/(?:src|href)="(\/assets\/[^"\s]+)"/gu)].map(
  (m) => m[1],
);
assert(assets.length >= 2);
for (const asset of assets) {
  cases.push([asset, "GET", 200], [asset, "HEAD", 200], [asset, "POST", 405]);
}
let passed = 0;
for (const [path, method, status] of cases) {
  const response = await fetch(origin + path, {
    method,
    redirect: "manual",
    signal: AbortSignal.timeout(20000),
  });
  const body = await response.text();
  assert.equal(response.status, status, `HTTP contract class ${passed}`);
  assert.match(
    response.headers.get("cache-control") ?? "",
    /no-store/u,
    `Cache contract class ${passed}`,
  );
  assert.equal(
    response.headers.get("referrer-policy"),
    "no-referrer",
    `Referrer contract class ${passed}`,
  );
  assert.equal(
    response.headers.get("x-robots-tag"),
    "noindex, nofollow, noarchive",
    `Robots contract class ${passed}`,
  );
  assert(!response.headers.has("set-cookie"));
  if (method === "HEAD") assert.equal(body, "");
  if (status === 200 && method === "GET" && !path.startsWith("/assets/")) {
    assert.match(body, /<div id="root"><\/div>/u);
    assert(!body.includes("text/x-component"));
  }
  passed++;
}
console.log(JSON.stringify({ origin, passed, realBrowserProof: false }));
