// Production Next HTTP probes on the explicit disposable local public origin.
// Uses only non-secret malformed links and public fixture identifiers.
export {};
const pi05 = process.env.PI05_PROBE_ORIGIN === "http://127.0.0.1:3174";
const origin = pi05
  ? process.env.PI05_PROBE_ORIGIN
  : process.env.PI04_PROBE_ORIGIN;
if (!origin) throw new Error("A disposable loopback probe origin is required.");
if (origin !== "http://127.0.0.1:3154" && !pi05)
  throw new Error(
    "PI04 probe requires disposable loopback public origin 3154.",
  );
const enabled = process.argv.includes("--enabled-associations");
function verify(condition: boolean, message: string): asserts condition {
  if (!condition) throw new Error(message);
}
for (const path of [
  "/.well-known/assetlinks.json",
  "/.well-known/apple-app-site-association",
]) {
  for (const method of ["GET", "HEAD"]) {
    const response = await fetch(`${origin}${path}`, {
      method,
      redirect: "manual",
      headers: { Cookie: "synthetic=irrelevant" },
    });
    verify(
      response.status === (enabled ? 200 : 404),
      "Association response status differs from configured mode.",
    );
    verify(
      !response.headers.has("location") && !response.headers.has("set-cookie"),
      "Association must be direct and session-independent.",
    );
    verify(
      response.headers.get("content-type")?.startsWith("application/json") ===
        true,
      "Association MIME must be JSON.",
    );
    verify(
      response.headers.get("cache-control") ===
        (enabled ? "public, max-age=300, s-maxage=300" : "no-store"),
      "Association cache contract differs.",
    );
    if (method === "GET") {
      const body = await response.json();
      if (!enabled)
        verify(
          body.error === "association_not_configured",
          "Disabled association body differs.",
        );
      else if (path.endsWith(".json"))
        verify(
          body[0].target.package_name === "invalid.planets.synthetic",
          "Expected only synthetic Android identity.",
        );
      else
        verify(
          body.applinks.details[0].appID ===
            "ABCDE12345.invalid.planets.synthetic",
          "Expected only synthetic Apple identity.",
        );
    }
  }
}
const id = pi05
  ? process.env.PI05_PROBE_PROPOSAL_ID
  : "fb040000-0000-4000-8000-000000000002";
verify(
  typeof id === "string" &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/u.test(
      id,
    ),
  "A public synthetic Proposal UUID is required.",
);
for (const path of [
  "/join/project/invalid-public-probe",
  "/invite/project/invalid-public-probe",
  "/auth?returnTo=%2Fjoin%2Fproject%2Finvalid-public-probe",
  `/joined/proposals/${id}`,
]) {
  const response = await fetch(`${origin}${path}`, { redirect: "manual" });
  verify(
    [200, 404].includes(response.status),
    "Sensitive route unexpectedly redirects/fails.",
  );
  verify(
    response.headers.get("cache-control")?.includes("no-store") === true,
    "Sensitive route must bypass shared caches.",
  );
  verify(
    response.headers.get("referrer-policy") === "no-referrer",
    "Sensitive route must suppress referrers.",
  );
  verify(
    response.headers.get("x-robots-tag")?.includes("noindex") === true,
    "Sensitive route must suppress indexing.",
  );
}
const detail = await fetch(`${origin}/proposals/${id}?intent=join`);
verify(detail.status === 200, "Public fixture detail failed.");
const html = await detail.text();
verify(
  html.includes(pi05 ? "Prepariamo insieme le cassette" : "PI04 public mural"),
  "Public fixture detail reached wrong owner.",
);
const script =
  html.match(/src="([^"]+\/_next\/[^"]+)"/u)?.[1] ??
  html.match(/src="(\/_next\/[^"]+)"/u)?.[1];
verify(Boolean(script), "Next browser asset missing.");
verify(
  (await fetch(new URL(script!, origin))).ok,
  "Next browser asset reached wrong owner.",
);
const rsc = await fetch(
  `${origin}/proposals/${id}?intent=join&_rsc=nonsecret-probe`,
  { headers: { RSC: "1", "Next-Router-Prefetch": "1" } },
);
verify(
  rsc.status === 200 &&
    rsc.headers.get("content-type")?.startsWith("text/x-component") === true,
  "Next RSC/prefetch transport failed.",
);
const post = await fetch(`${origin}/auth`, {
  method: "POST",
  headers: {
    Origin: origin,
    "Content-Type": "application/x-www-form-urlencoded",
  },
  body: "probe=nonsecret",
  redirect: "manual",
});
verify([200, 405].includes(post.status), "Next POST was not preserved.");
verify(
  (await fetch(`${origin}/join/unknown`)).status === 404,
  "Unknown dynamic descendant must retain Next 404.",
);
const unknown = await fetch(`${origin}/unknown-static-probe`);
verify(
  unknown.status === 404 && (await unknown.text()).includes("Site fixture 404"),
  "Unknown Site path must not become a SPA shell.",
);
console.log(
  `${pi05 ? "PI05" : "PI04"} production HTTP contract passed; associations ${enabled ? "synthetically enabled" : "disabled"}; HTML/assets/RSC/prefetch/POST/privacy/404 preserved.`,
);
