import { readFileSync } from "node:fs";
import { resolve } from "node:path";

import { beforeEach, describe, expect, it, vi } from "vitest";

const createBrowserClient = vi.fn();
const createServerClient = vi.fn();
const getAll = vi.fn(() => [{ name: "session", value: "cookie-value" }]);
const set = vi.fn();

vi.mock("@supabase/ssr", () => ({
  createBrowserClient,
  createServerClient,
}));

vi.mock("next/headers", () => ({
  cookies: vi.fn(async () => ({ getAll, set })),
}));

vi.mock("server-only", () => ({}));

describe("Supabase client factories", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    process.env.NEXT_PUBLIC_APP_ENV = "local";
    process.env.NEXT_PUBLIC_SUPABASE_URL = "http://127.0.0.1:54321";
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY = "publishable-key";
    process.env.NEXT_PUBLIC_SENTRY_DSN = "";
  });

  it("creates the browser client from canonical public configuration", async () => {
    const expectedClient = { kind: "browser" };
    createBrowserClient.mockReturnValue(expectedClient);
    const { createSupabaseBrowserClient } =
      await import("@/lib/supabase/browser");

    expect(createSupabaseBrowserClient()).toBe(expectedClient);
    expect(createBrowserClient).toHaveBeenCalledWith(
      "http://127.0.0.1:54321",
      "publishable-key",
    );
  });

  it("adapts the current request cookie store for the server client", async () => {
    const expectedClient = { kind: "server" };
    createServerClient.mockReturnValue(expectedClient);
    const { createSupabaseServerClient } =
      await import("@/lib/supabase/server");

    expect(await createSupabaseServerClient()).toBe(expectedClient);
    const options = createServerClient.mock.calls[0]?.[2];

    expect(options.cookies.getAll()).toEqual([
      { name: "session", value: "cookie-value" },
    ]);
    options.cookies.setAll(
      [
        {
          name: "session",
          value: "new-value",
          options: { httpOnly: true },
        },
      ],
      { "Cache-Control": "private, no-store" },
    );
    expect(set).toHaveBeenCalledWith("session", "new-value", {
      httpOnly: true,
    });
  });

  it("lets Proxy own cookie writes when a Server Component cannot set them", async () => {
    createServerClient.mockReturnValue({ kind: "server" });
    set.mockImplementationOnce(() => {
      throw new Error("Cookies can only be modified in a Server Action");
    });
    const { createSupabaseServerClient } =
      await import("@/lib/supabase/server");

    await createSupabaseServerClient();
    const options = createServerClient.mock.calls.at(-1)?.[2];

    expect(() =>
      options.cookies.setAll(
        [{ name: "session", value: "new-value", options: {} }],
        { "Cache-Control": "private, no-store" },
      ),
    ).not.toThrow();
  });

  it("keeps browser/server markers explicit and references no privileged key", () => {
    const browserSource = readFileSync(
      resolve(process.cwd(), "src/lib/supabase/browser.ts"),
      "utf8",
    );
    const serverSource = readFileSync(
      resolve(process.cwd(), "src/lib/supabase/server.ts"),
      "utf8",
    );

    expect(browserSource).toContain('import "client-only"');
    expect(browserSource).not.toContain("server-only");
    expect(serverSource).toContain('import "server-only"');
    expect(serverSource).not.toContain("client-only");
    expect(`${browserSource}\n${serverSource}`).not.toMatch(/service.?role/i);
  });
});
