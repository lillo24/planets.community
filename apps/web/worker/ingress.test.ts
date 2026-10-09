// @vitest-environment node
import { describe, expect, it } from "vitest";
import { isWebPath, prepareWebRequest, protectWebResponse } from "./ingress";

const origin = "https://planets.community";

describe("bounded Cloudflare ingress", () => {
  it("owns app namespaces and exact associations while preserving Site", () => {
    for (const path of [
      "/auth",
      "/auth/missing",
      "/profile",
      "/admin/cases/1",
      "/proposals",
      "/tavoli/1",
      "/join/project/sample",
      "/invite/project/sample",
      "/joined/proposals/1",
      "/joined/tavoli/1",
      "/_next/static/app.js",
      "/.well-known/assetlinks.json",
      "/.well-known/apple-app-site-association",
    ])
      expect(isWebPath(path)).toBe(true);
    for (const path of [
      "/",
      "/assets/app.js",
      "/api/waitlist",
      "/authentic",
      "/proposals-other",
      "/join/other",
      "/.well-known/other",
      "/missing",
    ])
      expect(isWebPath(path)).toBe(false);
  });

  it("forwards POST/query/body/cookies/Flight and reconstructs forwarding metadata", async () => {
    const request = new Request(`${origin}/auth?returnTo=%2Fproposals`, {
      method: "POST",
      body: "synthetic-form",
      headers: {
        Origin: origin,
        Cookie: "a=synthetic; b=synthetic",
        RSC: "1",
        "Next-Router-State-Tree": "synthetic",
        Forwarded: "host=evil.invalid",
        "X-Forwarded-Host": "evil.invalid",
        "X-Forwarded-Proto": "http",
        "X-Forwarded-For": "untrusted",
      },
    });
    const result = prepareWebRequest(request, [origin]);
    expect(result).toBeInstanceOf(Request);
    const forwarded = result as Request;
    expect(forwarded.url).toBe(request.url);
    expect(forwarded.method).toBe("POST");
    expect(await forwarded.text()).toBe("synthetic-form");
    for (const header of ["origin", "cookie", "rsc", "next-router-state-tree"])
      expect(forwarded.headers.get(header)).toBe(request.headers.get(header));
    expect(forwarded.headers.get("x-forwarded-host")).toBe("planets.community");
    expect(forwarded.headers.get("x-forwarded-proto")).toBe("https");
    expect(forwarded.headers.has("forwarded")).toBe(false);
    expect(forwarded.headers.has("x-forwarded-for")).toBe(false);
  });

  it("rejects foreign URLs, Host and Origin", () => {
    for (const request of [
      new Request("https://evil.invalid/auth"),
      new Request(`${origin}/auth`, { headers: { Host: "evil.invalid" } }),
      new Request(`${origin}/auth`, {
        method: "POST",
        headers: { Origin: "https://evil.invalid" },
      }),
    ]) {
      const response = prepareWebRequest(request, [origin]) as Response;
      expect(response.status).toBe(400);
      expect(response.headers.get("cache-control")).toContain("no-store");
      expect(response.headers.get("referrer-policy")).toBe("no-referrer");
      expect(response.headers.get("x-robots-tag")).toContain("noindex");
    }
  });

  it("preserves streaming response/status/MIME and independent refresh cookies", async () => {
    const headers = new Headers({
      "Content-Type": "text/x-component",
      Location: "/profile",
      "Cache-Control": "public, max-age=3600",
    });
    headers.append("Set-Cookie", "session.0=synthetic; Path=/; HttpOnly");
    headers.append("Set-Cookie", "session.1=synthetic; Path=/; HttpOnly");
    const response = protectWebResponse(
      new Response("synthetic-flight", { status: 307, headers }),
      "/auth",
    );
    expect(response.status).toBe(307);
    expect(response.headers.get("content-type")).toBe("text/x-component");
    expect(response.headers.get("location")).toBe("/profile");
    expect(response.headers.getSetCookie()).toHaveLength(2);
    expect(response.headers.get("cache-control")).toBe(
      "private, no-store, max-age=0",
    );
    expect(response.headers.get("referrer-policy")).toBe("no-referrer");
    expect(response.headers.get("x-robots-tag")).toContain("noindex");
    expect(await response.text()).toBe("synthetic-flight");
  });

  it("leaves disabled direct association 404/HEAD responses intact", () => {
    const response = new Response(null, {
      status: 404,
      headers: {
        "Content-Type": "application/json",
        "Cache-Control": "no-store",
      },
    });
    expect(protectWebResponse(response, "/.well-known/assetlinks.json")).toBe(
      response,
    );
  });
});
