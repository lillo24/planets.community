import { readFileSync } from "node:fs";
import { resolve } from "node:path";

import { describe, expect, it, vi } from "vitest";

import {
  readCurrentAuth,
  type CurrentAuthClient,
} from "@/features/auth/current-auth";

vi.mock("server-only", () => ({}));

describe("readCurrentAuth", () => {
  it("uses verified claims and returns signed out without an identity", async () => {
    const profileRead = vi.fn();
    const client = createClient({
      claims: { data: null, error: { code: "session_not_found" } },
      profileRead,
    });

    await expect(readCurrentAuth(async () => client)).resolves.toEqual({
      status: "signedOut",
    });
    expect(profileRead).not.toHaveBeenCalled();
  });

  it("returns ready only when the claimed identity has a profile anchor", async () => {
    const client = createClient({
      claims: { data: { claims: { sub: "user-1" } }, error: null },
      profile: { data: { id: "user-1" }, error: null },
    });

    await expect(readCurrentAuth(async () => client)).resolves.toEqual({
      status: "ready",
    });
  });

  it("keeps authentication but requires retry for a missing or unreadable anchor", async () => {
    for (const profile of [
      { data: null, error: null },
      { data: null, error: { code: "network_failure" } },
    ]) {
      const client = createClient({
        claims: { data: { claims: { sub: "user-1" } }, error: null },
        profile,
      });

      await expect(readCurrentAuth(async () => client)).resolves.toEqual({
        status: "profileSetupRequired",
      });
    }
  });

  it("does not use the unverified getSession server API", () => {
    const source = readFileSync(
      resolve(process.cwd(), "src/features/auth/current-auth.ts"),
      "utf8",
    );

    expect(source).toContain("auth.getClaims()");
    expect(source).not.toMatch(/\.getSession\s*\(/u);
  });
});

function createClient({
  claims,
  profile = { data: null, error: null },
  profileRead = vi.fn(),
}: Readonly<{
  claims: Awaited<ReturnType<CurrentAuthClient["auth"]["getClaims"]>>;
  profile?: Awaited<
    ReturnType<
      ReturnType<
        ReturnType<ReturnType<CurrentAuthClient["from"]>["select"]>["eq"]
      >["maybeSingle"]
    >
  >;
  profileRead?: ReturnType<typeof vi.fn>;
}>): CurrentAuthClient {
  profileRead.mockResolvedValue(profile);
  return {
    auth: { getClaims: vi.fn().mockResolvedValue(claims) },
    from: vi.fn(() => ({
      select: vi.fn(() => ({
        eq: vi.fn(() => ({ maybeSingle: profileRead })),
      })),
    })),
  } as unknown as CurrentAuthClient;
}
