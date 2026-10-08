// @vitest-environment node
import { describe, expect, it } from "vitest";

import {
  assertProbeResponse,
  parseProbeOrigin,
} from "./probe-local-hosting.mjs";

describe("local hosting probe guard", () => {
  it.each([
    "http://127.0.0.1:3117",
    "http://localhost:3117/",
    "http://[::1]:3117",
  ])("accepts explicit loopback %s", (origin) => {
    expect(parseProbeOrigin(origin)).toBe(new URL(origin).origin);
  });

  it.each([
    undefined,
    "https://example.com",
    "http://127.0.0.1.example.com",
    "http://127.0.0.2",
    "https://localhost",
    "http://user:secret@localhost",
    "http://localhost/admin",
    "http://localhost/?token=x",
    "http://localhost/#x",
  ])("rejects unsafe/ambiguous origin %s", (origin) => {
    expect(() => parseProbeOrigin(origin)).toThrow();
  });
});

describe("hosting response assertions", () => {
  const response = (
    status = 404,
    headers: Record<string, string> = {
      "cache-control": "private, no-store, max-age=0",
    },
  ) => new Response(null, { status, headers });

  it("accepts a genuine no-store HTML 404", () => {
    expect(() =>
      assertProbeResponse(response(), "", { status: 404 }),
    ).not.toThrow();
  });

  it("rejects success-shaped and shared-cache responses", () => {
    expect(() =>
      assertProbeResponse(response(200), "", { status: 404 }),
    ).toThrow();
    expect(() =>
      assertProbeResponse(
        response(404, { "cache-control": "public, max-age=60" }),
        "",
        { status: 404 },
      ),
    ).toThrow();
  });

  it("requires both the Flight type and the not-found digest", () => {
    const flight = response(200, {
      "cache-control": "no-store",
      "content-type": "text/x-component",
    });
    const expected = { status: 200, rscNotFound: true };
    expect(() =>
      assertProbeResponse(flight, "NEXT_HTTP_ERROR_FALLBACK;404", expected),
    ).not.toThrow();
    expect(() =>
      assertProbeResponse(flight, "ordinary data", expected),
    ).toThrow();
    expect(() =>
      assertProbeResponse(
        response(200),
        "NEXT_HTTP_ERROR_FALLBACK;404",
        expected,
      ),
    ).toThrow();
  });

  it("does not confuse a failed/malformed action with authorization denial", () => {
    const expected = { status: 200, unauthorizedAction: true };
    expect(() =>
      assertProbeResponse(response(200), '{"kind":"unauthorized"}', expected),
    ).not.toThrow();
    expect(() =>
      assertProbeResponse(response(200), '{"kind":"invalid_input"}', expected),
    ).toThrow();
    expect(() =>
      assertProbeResponse(
        response(200),
        '{"kind":"unauthorized","status":"success"}',
        expected,
      ),
    ).toThrow();
  });

  it("requires every invite privacy header", () => {
    const expected = { status: 200, invite: true };
    expect(() => assertProbeResponse(response(200), "", expected)).toThrow();
    expect(() =>
      assertProbeResponse(
        response(200, {
          "cache-control": "private, no-store",
          "referrer-policy": "no-referrer",
          "x-robots-tag": "noindex, nofollow, noarchive",
        }),
        "",
        expected,
      ),
    ).not.toThrow();
  });
});
