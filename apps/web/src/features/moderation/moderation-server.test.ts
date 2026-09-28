import { describe, expect, it, vi } from "vitest";

import {
  readModerationCase,
  readModerationQueue,
  type ModerationServerClient,
} from "./moderation-server";
import {
  moderationDetailRow,
  moderationQueueRow,
} from "./moderation-test-fixtures";

vi.mock("server-only", () => ({}));

describe("moderation server authorization", () => {
  it("denies signed-out and ordinary authenticated callers", async () => {
    const signedOut = client({ profileId: null });
    await expect(
      readModerationQueue({}, async () => signedOut),
    ).resolves.toEqual({ status: "denied" });
    expect(signedOut.rpc).not.toHaveBeenCalled();

    const ordinary = client({ profileId: profileId, staffRole: null });
    await expect(
      readModerationQueue({}, async () => ordinary),
    ).resolves.toEqual({ status: "denied" });
    expect(ordinary.rpc).toHaveBeenCalledTimes(1);
  });

  it.each(["moderator", "admin"] as const)(
    "allows an active %s to read the bounded queue",
    async (staffRole) => {
      const staff = client({
        profileId,
        staffRole,
        queue: [moderationQueueRow()],
      });
      const result = await readModerationQueue(
        { state: "received" },
        async () => staff,
      );
      expect(result).toMatchObject({ status: "ready", staffRole });
      expect(staff.rpc).toHaveBeenLastCalledWith(
        "list_moderation_cases",
        expect.objectContaining({ p_limit: 26, p_state: "received" }),
      );
    },
  );

  it("returns staff-only report evidence through the detail RPC", async () => {
    const staff = client({
      profileId,
      staffRole: "moderator",
      detail: [moderationDetailRow()],
    });
    const result = await readModerationCase(caseId, async () => staff);
    expect(result.status).toBe("ready");
    if (result.status === "ready") {
      expect(result.detail?.explanation).toContain("original report");
      expect(result.detail?.notes[0].body).toBe("Private note");
    }
  });

  it("fails loudly when an authorized queue RPC fails", async () => {
    const staff = client({
      profileId,
      staffRole: "moderator",
      queueError: true,
    });
    await expect(readModerationQueue({}, async () => staff)).rejects.toThrow(
      "could not be loaded",
    );
  });
});

const profileId = "00000000-0000-4000-8000-000000000906";
const caseId = "00000000-0000-4000-8000-000000000901";

function client({
  profileId,
  staffRole,
  queue = [],
  detail = [],
  queueError = false,
}: {
  profileId: string | null;
  staffRole?: "moderator" | "admin" | null;
  queue?: unknown[];
  detail?: unknown[];
  queueError?: boolean;
}): ModerationServerClient {
  return {
    auth: {
      getClaims: vi.fn().mockResolvedValue({
        data: profileId ? { claims: { sub: profileId } } : null,
        error: profileId ? null : { code: "signed_out" },
      }),
    },
    rpc: vi.fn(async (name: string) => {
      if (name === "get_own_moderation_staff_access") {
        return {
          data: staffRole ? [{ staff_role: staffRole }] : [],
          error: null,
        };
      }
      if (name === "list_moderation_cases") {
        return { data: queue, error: queueError ? { code: "offline" } : null };
      }
      if (name === "get_moderation_case_detail")
        return { data: detail, error: null };
      throw new Error(`Unexpected RPC: ${name}`);
    }),
  };
}
