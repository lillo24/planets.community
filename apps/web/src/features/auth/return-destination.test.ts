import { describe, expect, it } from "vitest";

import { sanitizeReturnDestination } from "@/features/auth/return-destination";

describe("sanitizeReturnDestination", () => {
  it("keeps an internal path, query, and fragment", () => {
    expect(sanitizeReturnDestination("/proposals?nearby=true#results")).toBe(
      "/proposals?nearby=true#results",
    );
  });

  it("rejects external, protocol-relative, backslash, and auth-loop paths", () => {
    for (const candidate of [
      "https://attacker.example/private",
      "//attacker.example/private",
      "\\attacker.example\\private",
      "/%5Cattacker.example/private",
      "/%2F%2Fattacker.example/private",
      "/auth",
      "/auth/verify",
      "/%61uth/verify",
    ]) {
      expect(sanitizeReturnDestination(candidate)).toBe("/");
    }
  });

  it("falls back for absent, malformed, and relative destinations", () => {
    expect(sanitizeReturnDestination(undefined)).toBe("/");
    expect(sanitizeReturnDestination("")).toBe("/");
    expect(sanitizeReturnDestination("proposals")).toBe("/");
    expect(sanitizeReturnDestination("/%E0%A4%A")).toBe("/");
  });
});
