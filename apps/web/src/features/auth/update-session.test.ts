import { readFileSync } from "node:fs";
import { resolve } from "node:path";

import { createServerClient } from "@supabase/ssr";
import { unstable_doesMiddlewareMatch } from "next/experimental/testing/server";
import { NextRequest } from "next/server";
import { beforeEach, describe, expect, it, vi } from "vitest";

import { updateSupabaseSession } from "@/features/auth/update-session";
import { config } from "@/proxy";

vi.mock("server-only", () => ({}));
vi.mock("@supabase/ssr", () => ({ createServerClient: vi.fn() }));

describe("Supabase session Proxy", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    process.env.NEXT_PUBLIC_APP_ENV = "local";
    process.env.NEXT_PUBLIC_SUPABASE_URL = "http://127.0.0.1:54321";
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY = "publishable-key";
    process.env.NEXT_PUBLIC_SENTRY_DSN = "";
  });

  it("validates claims and propagates refreshed cookies and cache headers", async () => {
    vi.mocked(createServerClient).mockImplementation((_url, _key, options) => {
      return {
        auth: {
          getClaims: vi.fn(async () => {
            await options.cookies.setAll?.(
              [
                {
                  name: "session-cookie",
                  value: "refreshed-value",
                  options: { httpOnly: true, path: "/" },
                },
              ],
              { "Cache-Control": "private, no-store" },
            );
            return { data: null, error: null };
          }),
        },
      } as never;
    });
    const request = new NextRequest("https://planets.example/");

    const response = await updateSupabaseSession(request);

    const client = vi.mocked(createServerClient).mock.results[0]?.value as {
      auth: { getClaims: ReturnType<typeof vi.fn> };
    };
    expect(client.auth.getClaims).toHaveBeenCalledOnce();
    expect(request.cookies.get("session-cookie")?.value).toBe(
      "refreshed-value",
    );
    expect(response.cookies.get("session-cookie")?.value).toBe(
      "refreshed-value",
    );
    expect(response.headers.get("cache-control")).toBe("private, no-store");
    expect(response.headers.get("location")).toBeNull();
  });

  it("matches application routes but skips build and image assets", () => {
    expect(doesProxyMatch("/")).toBe(true);
    expect(doesProxyMatch("/auth")).toBe(true);
    expect(doesProxyMatch("/admin")).toBe(true);
    expect(doesProxyMatch("/_next/static/chunk.js")).toBe(false);
    expect(doesProxyMatch("/_next/image?url=%2Fphoto.png")).toBe(false);
    expect(doesProxyMatch("/photo.png")).toBe(false);
  });

  it("never trusts getSession or implements route authorization", () => {
    const source = readFileSync(
      resolve(process.cwd(), "src/features/auth/update-session.ts"),
      "utf8",
    );

    expect(source).toContain("auth.getClaims()");
    expect(source).not.toMatch(/\.getSession\s*\(/u);
    expect(source).not.toContain("redirect(");
  });
});

function doesProxyMatch(url: string): boolean {
  return unstable_doesMiddlewareMatch({
    config,
    nextConfig: {},
    url,
  });
}
