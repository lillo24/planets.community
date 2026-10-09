import { describe, expect, it, vi } from "vitest";
import { trialReturn, trialRoute } from "./routes";
import { trialPublicConfig } from "./public-config";
import worker from "./worker";
const token = "a".repeat(43);
const uuid = "fb030300-0000-4000-8000-000000000002";
describe("isolated static invitation boundary", () => {
  it("owns only exact participant/onboarding/confirmation paths", () => {
    for (const path of [
      "/",
      "/auth",
      "/profile",
      `/join/project/${token}`,
      `/joined/proposals/${uuid}`,
      `/joined/tavoli/${uuid}`,
    ])
      expect(trialRoute(path)).not.toBeNull();
    for (const path of [
      "/admin",
      "/api/auth",
      "/invite/project/" + token,
      "/proposals/" + uuid,
      "/.well-known/assetlinks.json",
      "/index.html",
      `/join/project/${token}/`,
      "/join/project/%41" + token,
      "/joined/tavoli/not-a-uuid",
    ])
      expect(trialRoute(path)).toBeNull();
  });
  it("preserves participant and nested profile returns, rejects external and encoded tricks", () => {
    const invite = `/join/project/${token}`;
    expect(trialReturn(invite)).toBe(invite);
    expect(trialReturn(`/profile?returnTo=${encodeURIComponent(invite)}`)).toBe(
      `/profile?returnTo=${encodeURIComponent(invite)}`,
    );
    for (const value of [
      "//evil.invalid",
      "https://evil.invalid",
      "/%252f%252fevil.invalid",
      "/%2561uth",
      "/profile?returnTo=//evil.invalid",
      "/profile?returnTo=/&returnTo=" + invite,
      invite + "#secret",
      invite + "?other=1",
      "/admin",
    ])
      expect(trialReturn(value)).toBe("/");
  });
  it("compiles only public configuration and refuses secrets/monitoring/arbitrary targets", () => {
    const publicConfig = {
      NEXT_PUBLIC_APP_ENV: "local",
      NEXT_PUBLIC_SUPABASE_URL: "http://127.0.0.1:59121",
      NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: "sb_publishable_synthetic",
    };
    expect(trialPublicConfig(publicConfig).config.appEnv).toBe("local");
    expect(() =>
      trialPublicConfig({
        ...publicConfig,
        NEXT_PUBLIC_SENTRY_DSN: "https://secret.invalid",
      }),
    ).toThrow("Unexpected static public setting");
    expect(() =>
      trialPublicConfig({
        ...publicConfig,
        NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: "sb_secret_synthetic",
      }),
    ).toThrow("public publishable");
    expect(() =>
      trialPublicConfig({
        ...publicConfig,
        NEXT_PUBLIC_SUPABASE_URL: "https://other.invalid",
      }),
    ).toThrow("owned backend");
  });
  it("serves the generic asset with private headers, no original query/cookie and no session processing", async () => {
    const fetch = vi.fn().mockResolvedValue(
      new Response("generic shell", {
        headers: {
          "Content-Type": "text/html",
          "Cache-Control": "public,max-age=3600",
          "Set-Cookie": "must-be-stripped",
        },
      }),
    );
    const response = await worker.fetch(
      new Request(
        `https://trial.invalid/join/project/${token}?returnTo=private`,
        { headers: { Cookie: "sensitive" } },
      ),
      { ASSETS: { fetch } },
    );
    expect(response.status).toBe(200);
    expect(response.headers.get("cache-control")).toBe("private, no-store");
    expect(response.headers.get("referrer-policy")).toBe("no-referrer");
    expect(response.headers.get("x-robots-tag")).toBe(
      "noindex, nofollow, noarchive",
    );
    expect(response.headers.has("set-cookie")).toBe(false);
    const forwarded = fetch.mock.calls[0][0] as Request;
    expect(forwarded.url).toBe("https://trial.invalid/index.html");
    expect(forwarded.headers.has("cookie")).toBe(false);
    expect(await response.text()).not.toContain(token);
  });
  it("HEAD reuses the asset HEAD; unknown paths/methods never fetch the shell", async () => {
    const fetch = vi.fn().mockResolvedValue(new Response(null));
    expect(
      (
        await worker.fetch(
          new Request("https://trial.invalid/auth", { method: "HEAD" }),
          { ASSETS: { fetch } },
        )
      ).status,
    ).toBe(200);
    expect(fetch.mock.calls[0][0].method).toBe("HEAD");
    fetch.mockClear();
    for (const [path, method, status] of [
      ["/api/unknown", "GET", 404],
      ["/.well-known/apple-app-site-association", "HEAD", 404],
      ["/auth", "POST", 405],
      ["/auth", "OPTIONS", 405],
    ] as const) {
      const response = await worker.fetch(
        new Request(`https://trial.invalid${path}`, { method }),
        { ASSETS: { fetch } },
      );
      expect(response.status).toBe(status);
      expect(response.headers.get("referrer-policy")).toBe("no-referrer");
      if (method === "HEAD") expect(await response.text()).toBe("");
    }
    expect(fetch).not.toHaveBeenCalled();
  });
});
