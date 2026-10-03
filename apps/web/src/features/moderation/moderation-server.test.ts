import { describe, expect, it, vi } from "vitest";

import {
  readModerationCase,
  readModerationQueue,
  requireModerationStaff,
  type ModerationServerClient,
} from "./moderation-server";
import {
  moderationCounterstatementRow,
  moderationCorroborationRow,
  moderationConsequenceRow,
  moderationDetailRow,
  moderationQueueRow,
  moderationResourceDetailRow,
} from "./moderation-test-fixtures";

vi.mock("server-only", () => ({}));

describe("moderation server authorization", () => {
  it("denies a normal signed-out result", async () => {
    const signedOut = client({ profileId: null });
    await expect(
      readModerationQueue({}, async () => signedOut),
    ).resolves.toEqual({ status: "denied" });
    expect(signedOut.rpc).not.toHaveBeenCalled();
  });

  it("denies when client creation throws", async () => {
    await expect(
      requireModerationStaff(async () => {
        throw new Error("client unavailable");
      }),
    ).resolves.toBeNull();
  });

  it("denies when claims lookup throws", async () => {
    const claimsFailure = client({ profileId, claimsThrows: true });
    await expect(
      readModerationQueue({}, async () => claimsFailure),
    ).resolves.toEqual({ status: "denied" });
    expect(claimsFailure.rpc).not.toHaveBeenCalled();
  });

  it.each(["error", "throw"] as const)(
    "denies when the staff-access RPC ends in an %s",
    async (failure) => {
      const staffLookupFailure = client({
        profileId,
        staffAccessError: failure === "error",
        staffAccessThrows: failure === "throw",
      });
      await expect(
        readModerationQueue({}, async () => staffLookupFailure),
      ).resolves.toEqual({ status: "denied" });
      expect(staffLookupFailure.rpc).toHaveBeenCalledTimes(1);
    },
  );

  it("denies ordinary authenticated and malformed-role callers", async () => {
    for (const staffRole of [null, "owner"] as const) {
      const ordinary = client({ profileId, staffRole });
      await expect(
        readModerationQueue({}, async () => ordinary),
      ).resolves.toEqual({ status: "denied" });
      expect(ordinary.rpc).toHaveBeenCalledTimes(1);
    }
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
      corroboration: [moderationCorroborationRow()],
    });
    const result = await readModerationCase(caseId, async () => staff);
    expect(result.status).toBe("ready");
    if (result.status === "ready") {
      expect(result.detail?.explanation).toContain("original report");
      expect(result.detail?.notes[0].body).toBe("Private note");
      expect(result.detail?.corroboration?.responses[0].choice).toBe("unsure");
    }
  });

  it("loads pending counterparty evidence only for a Resource request case", async () => {
    const staff = client({
      profileId,
      staffRole: "moderator",
      detail: [moderationResourceDetailRow()],
      counterstatement: [moderationCounterstatementRow()],
    });
    const result = await readModerationCase(caseId, async () => staff);
    expect(result.status).toBe("ready");
    if (result.status === "ready") {
      expect(result.detail?.counterstatement).toMatchObject({
        recipientDisplayName: "Taylor",
        statement: null,
      });
    }
    expect(staff.rpc).toHaveBeenCalledWith(
      "get_moderation_case_counterstatement",
      expect.objectContaining({ p_case_id: caseId }),
    );
    expect(staff.rpc).not.toHaveBeenCalledWith(
      "get_moderation_case_corroboration",
      expect.anything(),
    );
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

  it("fails loudly when an authorized case RPC fails", async () => {
    const staff = client({
      profileId,
      staffRole: "admin",
      detailError: true,
    });
    await expect(readModerationCase(caseId, async () => staff)).rejects.toThrow(
      "could not be loaded",
    );
  });

  it("reads only current-case consequences with the server-derived identity", async () => {
    const staff = client({
      profileId,
      staffRole: "admin",
      detail: [moderationDetailRow()],
      consequences: [moderationConsequenceRow()],
      corroboration: [moderationCorroborationRow()],
    });
    const result = await readModerationCase(caseId, async () => staff);
    expect(result).toMatchObject({
      status: "ready",
      staffProfileId: profileId,
      consequences: [{ type: "safety_notice", revokedAt: null }],
    });
    expect(staff.rpc).toHaveBeenCalledWith(
      "list_moderation_case_consequence_history",
      { p_expected_staff_profile_id: profileId, p_case_id: caseId },
    );
  });

  it.each(["rpc", "malformed"])(
    "does not turn %s history failure into an empty case history",
    async (failure) => {
      const staff = client({
        profileId,
        staffRole: "moderator",
        detail: [moderationDetailRow()],
        consequences: failure === "malformed" ? [{}] : [],
        historyError: failure === "rpc",
      });
      await expect(
        readModerationCase(caseId, async () => staff),
      ).rejects.toThrow(/history could not be loaded|response was malformed/);
    },
  );
});

const profileId = "00000000-0000-4000-8000-000000000906";
const caseId = "00000000-0000-4000-8000-000000000901";

function client({
  profileId,
  staffRole,
  queue = [],
  detail = [],
  corroboration = [],
  counterstatement = [],
  consequences = [],
  historyError = false,
  queueError = false,
  detailError = false,
  claimsThrows = false,
  staffAccessError = false,
  staffAccessThrows = false,
}: {
  profileId: string | null;
  staffRole?: unknown;
  queue?: unknown[];
  detail?: unknown[];
  corroboration?: unknown[];
  counterstatement?: unknown[];
  consequences?: unknown[];
  historyError?: boolean;
  queueError?: boolean;
  detailError?: boolean;
  claimsThrows?: boolean;
  staffAccessError?: boolean;
  staffAccessThrows?: boolean;
}): ModerationServerClient {
  return {
    auth: {
      getClaims: vi.fn(async () => {
        if (claimsThrows) throw new Error("claims unavailable");
        return {
          data: profileId ? { claims: { sub: profileId } } : null,
          error: profileId ? null : { code: "signed_out" },
        };
      }),
    },
    rpc: vi.fn(async (name: string) => {
      if (name === "get_own_moderation_staff_access") {
        if (staffAccessThrows) throw new Error("staff lookup unavailable");
        return {
          data: staffRole ? [{ staff_role: staffRole }] : [],
          error: staffAccessError ? { code: "offline" } : null,
        };
      }
      if (name === "list_moderation_cases") {
        return { data: queue, error: queueError ? { code: "offline" } : null };
      }
      if (name === "get_moderation_case_detail") {
        return {
          data: detail,
          error: detailError ? { code: "offline" } : null,
        };
      }
      if (name === "get_moderation_case_corroboration") {
        return { data: corroboration, error: null };
      }
      if (name === "get_moderation_case_counterstatement") {
        return { data: counterstatement, error: null };
      }
      if (name === "list_moderation_case_consequence_history") {
        return {
          data: consequences,
          error: historyError ? { code: "offline" } : null,
        };
      }
      throw new Error(`Unexpected RPC: ${name}`);
    }),
  };
}
