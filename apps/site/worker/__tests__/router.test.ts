import { describe, expect, it, vi } from "vitest";

import { routeWorkerRequest } from "../index";

function createWorkerEnv(assetResponse = new Response("asset")) {
  return {
    ASSETS: {
      fetch: vi.fn(async () => assetResponse),
    } as unknown as Fetcher,
    WAITLIST_DB: {} as D1Database,
    TURNSTILE_SECRET_KEY: "test-secret",
    TURNSTILE_EXPECTED_ACTION: "waitlist_signup",
    TURNSTILE_EXPECTED_HOSTNAME: "planets.test",
    TURNSTILE_TESTING_MODE: "false",
  } satisfies WorkerEnv;
}

describe("native Worker routing", () => {
  it("routes only the exact waitlist path to the reusable handler", async () => {
    const env = createWorkerEnv();
    const handler = vi.fn(async () => new Response("waitlist"));
    const request = new Request(
      "https://planets.test/api/waitlist?source=landing",
      { method: "POST" },
    );

    const response = await routeWorkerRequest(request, env, handler);

    expect(await response.text()).toBe("waitlist");
    expect(handler).toHaveBeenCalledOnce();
    expect(handler).toHaveBeenCalledWith(request, env);
    expect(env.ASSETS.fetch).not.toHaveBeenCalled();
  });

  it("preserves the waitlist handler's method response", async () => {
    const response = await routeWorkerRequest(
      new Request("https://planets.test/api/waitlist"),
      createWorkerEnv(),
    );

    expect(response.status).toBe(405);
    expect(response.headers.get("Allow")).toBe("POST");
  });

  it("returns a private API 404 without consulting static assets", async () => {
    const env = createWorkerEnv();
    const handler = vi.fn();

    const response = await routeWorkerRequest(
      new Request("https://planets.test/api/unknown"),
      env,
      handler,
    );

    expect(response.status).toBe(404);
    expect(await response.json()).toEqual({ ok: false, code: "not_found" });
    expect(response.headers.get("Cache-Control")).toBe("no-store");
    expect(handler).not.toHaveBeenCalled();
    expect(env.ASSETS.fetch).not.toHaveBeenCalled();
  });

  it("falls through non-API requests to the static-assets binding", async () => {
    const assetResponse = new Response("body {}", {
      headers: { "Content-Type": "text/css" },
    });
    const env = createWorkerEnv(assetResponse);
    const request = new Request("https://planets.test/assets/site.css");

    const response = await routeWorkerRequest(request, env);

    expect(await response.text()).toBe("body {}");
    expect(response.headers.get("Content-Type")).toBe("text/css");
    expect(env.ASSETS.fetch).toHaveBeenCalledWith(request);
  });

  it("does not turn Worker source paths into static responses", async () => {
    const env = createWorkerEnv(new Response("Not Found", { status: 404 }));

    const response = await routeWorkerRequest(
      new Request("https://planets.test/worker/waitlist.ts"),
      env,
    );

    expect(response.status).toBe(404);
  });
});
