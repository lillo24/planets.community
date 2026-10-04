import assert from "node:assert/strict";

import { assertProbeResponse } from "./probe-local-hosting.mjs";

// Exact, non-secret synthetic text shared by the seed and live privacy verifier.
// All selected markers must be observed in authorized reads before denial tests.
export const privateFixtureMarkers = Object.freeze({
  notes: Object.freeze(
    Array.from(
      { length: 8 },
      (_, index) => `Synthetic private note ${index + 1}:`,
    ),
  ),
  witness: "Synthetic private witness statement for hosting QA.",
  counterstatement: "Synthetic private counterparty statement for hosting QA.",
});

export function assertPrivateFixtureResponse(
  response,
  body,
  { format, authorized, markers },
) {
  assert.ok(["html", "flight"].includes(format), "Unknown private transport.");
  assert.equal(typeof authorized, "boolean", "Specify the access expectation.");
  assert.ok(
    Array.isArray(markers) &&
      markers.length > 0 &&
      markers.every(
        (marker) => typeof marker === "string" && marker.length > 0,
      ),
    "Require actual nonempty private fixture markers.",
  );
  assertProbeResponse(response, body, {
    status: authorized || format === "flight" ? 200 : 404,
    rscNotFound: !authorized && format === "flight",
  });
  assert.match(
    response.headers.get("content-type") ?? "",
    format === "flight" ? /^text\/x-component(?:;|$)/i : /^text\/html(?:;|$)/i,
    "Wrong private response content type.",
  );
  assert.match(
    response.headers.get("cache-control") ?? "",
    /(?:^|[,\s])private(?:$|[,\s])/i,
    "Private response must not enter a shared cache.",
  );
  if (!authorized && format === "html") {
    assert.ok(
      body.includes("Page unavailable"),
      "Missing HTML not-found page.",
    );
  }
  if (authorized) {
    assert.ok(
      !body.includes("NEXT_HTTP_ERROR_FALLBACK;404"),
      "Authorized response was a not-found payload.",
    );
  }
  for (const marker of markers) {
    // Never include a marker or response body in assertion errors/logs.
    assert.equal(
      body.includes(marker),
      authorized,
      authorized
        ? "Missing authorized private fixture marker."
        : "Private fixture data reached a denied response.",
    );
  }
}
