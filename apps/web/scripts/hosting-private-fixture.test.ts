// @vitest-environment node
import { describe, expect, it } from "vitest";

import {
  assertPrivateFixtureResponse,
  privateFixtureMarkers,
} from "./hosting-private-fixture.mjs";

const markers = [
  ...privateFixtureMarkers.notes,
  privateFixtureMarkers.witness,
  privateFixtureMarkers.counterstatement,
];
const response = (format: string, authorized = false) =>
  new Response(null, {
    status: authorized || format === "flight" ? 200 : 404,
    headers: {
      "content-type": format === "flight" ? "text/x-component" : "text/html",
      "cache-control": "private, no-store, max-age=0",
    },
  });
const deniedBody = (format: string) =>
  format === "flight" ? "NEXT_HTTP_ERROR_FALLBACK;404" : "Page unavailable";

describe.each(["html", "flight"])("private fixture %s assertions", (format) => {
  it("requires every actual marker in the authorized response", () => {
    const expected = { format, authorized: true, markers };
    expect(() =>
      assertPrivateFixtureResponse(
        response(format, true),
        markers.join(" "),
        expected,
      ),
    ).not.toThrow();
    for (const marker of markers) {
      expect(() =>
        assertPrivateFixtureResponse(
          response(format, true),
          markers.filter((item) => item !== marker).join(" "),
          expected,
        ),
      ).toThrow("Missing authorized private fixture marker");
    }
  });

  it.each(markers)(
    "rejects denial-shaped payloads leaking marker %#",
    (marker) => {
      expect(() =>
        assertPrivateFixtureResponse(
          response(format),
          `${deniedBody(format)} ${marker}`,
          { format, authorized: false, markers },
        ),
      ).toThrow("Private fixture data reached a denied response");
    },
  );

  it("requires status, type, private/no-store and not-found semantics together", () => {
    const expected = { format, authorized: false, markers };
    expect(() =>
      assertPrivateFixtureResponse(
        response(format),
        deniedBody(format),
        expected,
      ),
    ).not.toThrow();
    const valid = response(format);
    for (const invalid of [
      new Response(null, { status: 302, headers: valid.headers }),
      new Response(null, {
        status: valid.status,
        headers: {
          "content-type": "application/json",
          "cache-control": "private, no-store",
        },
      }),
      new Response(null, {
        status: valid.status,
        headers: {
          "content-type": valid.headers.get("content-type")!,
          "cache-control": "public, max-age=60",
        },
      }),
      new Response(null, {
        status: valid.status,
        headers: {
          "content-type": valid.headers.get("content-type")!,
          "cache-control": "no-store",
        },
      }),
    ]) {
      expect(() =>
        assertPrivateFixtureResponse(invalid, deniedBody(format), expected),
      ).toThrow();
    }
    expect(() =>
      assertPrivateFixtureResponse(valid, "successful empty data", expected),
    ).toThrow();
  });

  it("rejects empty marker contracts", () => {
    for (const invalid of [[], [""]]) {
      expect(() =>
        assertPrivateFixtureResponse(response(format), deniedBody(format), {
          format,
          authorized: false,
          markers: invalid,
        }),
      ).toThrow();
    }
  });
});
