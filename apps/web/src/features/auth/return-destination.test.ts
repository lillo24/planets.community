import { describe, expect, it } from "vitest";

import { participantCancelDestination } from "./return-destination";

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
  it("rejects multiply encoded external/auth-loop paths while preserving exact special and authority destinations", () => {
    for (const path of [
      "/%252Fattacker.example/path",
      "/%255Cattacker.example",
      "/%2561uth",
      "/%252561uth/verify",
    ])
      expect(sanitizeReturnDestination(path)).toBe("/");
    const special = `/join/project/${"a".repeat(43)}`;
    expect(sanitizeReturnDestination(special)).toBe(special);
    expect(participantCancelDestination(special)).toBe(special);
    expect(
      participantCancelDestination(
        `/profile?returnTo=${encodeURIComponent(special)}`,
      ),
    ).toBe(special);
    expect(
      participantCancelDestination(
        `/profile?returnTo=${encodeURIComponent(special)}&returnTo=/`,
      ),
    ).toBe("/");
    expect(
      participantCancelDestination(`/invite/project/${"a".repeat(43)}`),
    ).toBe("/");
    expect(participantCancelDestination("/profile")).toBe("/");
    expect(
      participantCancelDestination(
        "/joined/tavoli/00000000-0000-4000-8000-000000000001",
      ),
    ).toBe("/tavoli/00000000-0000-4000-8000-000000000001");
  });
});
