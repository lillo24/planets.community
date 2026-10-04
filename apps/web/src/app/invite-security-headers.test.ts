import { describe, expect, it } from "vitest";

import nextConfig from "../../next.config";

describe("invite response security headers", () => {
  it("prevents indexing, referrer disclosure, and caching", async () => {
    const entries = await nextConfig.headers?.();
    for (const source of [
      "/invite/project/:token",
      "/join/project/:token",
      "/joined/:kind/:id",
      "/auth",
      "/profile",
    ]) {
      const invite = entries?.find((entry) => entry.source === source);
      expect(invite?.headers).toEqual(
        expect.arrayContaining([
          { key: "Cache-Control", value: "private, no-store, max-age=0" },
          { key: "Referrer-Policy", value: "no-referrer" },
          { key: "X-Robots-Tag", value: "noindex, nofollow, noarchive" },
        ]),
      );
    }
  });
});
