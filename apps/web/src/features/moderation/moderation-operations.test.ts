import { describe, expect, it, vi } from "vitest";

import {
  addModerationNote,
  transitionModerationCase,
} from "./moderation-operations";
import type { ModerationServerClient } from "./moderation-server";

vi.mock("server-only", () => ({}));

describe("moderation staff operations", () => {
  it("trims and appends a private note through the canonical RPC", async () => {
    const staff = client(["moderator"]);
    await addModerationNote(
      { caseId, body: "  Private note  " },
      async () => staff,
    );
    expect(staff.rpc).toHaveBeenLastCalledWith("add_moderation_case_note", {
      p_expected_staff_profile_id: profileId,
      p_case_id: caseId,
      p_body: "Private note",
    });
  });

  it("passes the compare-and-swap version to a review-only transition", async () => {
    const staff = client(["admin"]);
    await transitionModerationCase(
      { caseId, expectedStateVersion: 2, targetState: "under_review" },
      async () => staff,
    );
    expect(staff.rpc).toHaveBeenLastCalledWith(
      "transition_moderation_case",
      expect.objectContaining({
        p_expected_state_version: 2,
        p_target_state: "under_review",
      }),
    );
  });

  it("rechecks authorization and denies the next operation after revocation", async () => {
    const staff = client(["moderator", null]);
    await addModerationNote({ caseId, body: "First note" }, async () => staff);
    await expect(
      addModerationNote({ caseId, body: "Second note" }, async () => staff),
    ).rejects.toThrow("staff access");
  });

  it("rejects non-review enforcement-like states before any RPC", async () => {
    const staff = client(["admin"]);
    await expect(
      transitionModerationCase(
        { caseId, expectedStateVersion: 0, targetState: "suspended" },
        async () => staff,
      ),
    ).rejects.toThrow("invalid");
    expect(staff.rpc).not.toHaveBeenCalled();
  });
});

const profileId = "00000000-0000-4000-8000-000000000906";
const caseId = "00000000-0000-4000-8000-000000000901";

function client(
  roles: Array<"moderator" | "admin" | null>,
): ModerationServerClient {
  let accessIndex = 0;
  return {
    auth: {
      getClaims: vi
        .fn()
        .mockResolvedValue({
          data: { claims: { sub: profileId } },
          error: null,
        }),
    },
    rpc: vi.fn(async (name: string) => {
      if (name === "get_own_moderation_staff_access") {
        const role = roles[accessIndex++];
        return { data: role ? [{ staff_role: role }] : [], error: null };
      }
      return { data: [], error: null };
    }),
  };
}
