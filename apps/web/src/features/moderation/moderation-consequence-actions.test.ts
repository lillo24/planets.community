import { beforeEach, describe, expect, it, vi } from "vitest";
import { revalidatePath } from "next/cache";
import { moderationConsequenceAction } from "./moderation-actions";
import { performModerationConsequence } from "./moderation-operations";
import { moderationDetailRow } from "./moderation-test-fixtures";
import type { ConsequenceActionResult } from "./moderation-consequence-models";

vi.mock("next/cache", () => ({ revalidatePath: vi.fn() }));
vi.mock("./moderation-operations", () => ({
  performModerationConsequence: vi.fn(),
  addModerationNote: vi.fn(),
  transitionModerationCase: vi.fn(),
}));
const caseId = moderationDetailRow().case_id;
beforeEach(() => vi.clearAllMocks());

describe("consequence Server Action", () => {
  it.each(["unauthorized", "duplicate", "already_revoked", "stale"] as const)(
    "refreshes trusted paths on %s and ignores forged previous state",
    async (kind) => {
      vi.mocked(performModerationConsequence).mockResolvedValue({
        status: "error",
        kind,
      });
      const forgedPrevious = {
        status: "success",
        kind: "applied",
        staffProfileId: "forged",
      } as ConsequenceActionResult;
      expect(await moderationConsequenceAction(forgedPrevious, form())).toEqual(
        { status: "error", kind },
      );
      expect(performModerationConsequence).toHaveBeenCalledWith({
        mode: "apply",
        caseId,
        type: "safety_notice",
        userReason: "User explanation",
        internalNote: "Private explanation",
      });
      expect(vi.mocked(revalidatePath).mock.calls).toEqual([
        ["/admin"],
        [`/admin/cases/${caseId}`],
      ]);
    },
  );
  it("revalidates after a confirmed apply", async () => {
    vi.mocked(performModerationConsequence).mockResolvedValue({
      status: "success",
      kind: "applied",
    });
    expect(
      await moderationConsequenceAction({ status: "idle" }, form()),
    ).toMatchObject({ status: "success" });
    expect(revalidatePath).toHaveBeenCalledTimes(2);
  });
  it.each(["caseId", "staffProfileId"])(
    "never uses a malformed/extra %s in an RPC or revalidation path",
    async (key) => {
      const data = form();
      data.set(key, "../../secret");
      expect(
        await moderationConsequenceAction({ status: "idle" }, data),
      ).toEqual({ status: "error", kind: "invalid_input" });
      expect(performModerationConsequence).not.toHaveBeenCalled();
      expect(revalidatePath).not.toHaveBeenCalled();
    },
  );
});

function form() {
  const data = new FormData();
  for (const [key, value] of Object.entries({
    mode: "apply",
    caseId,
    type: "safety_notice",
    userReason: "User explanation",
    internalNote: "Private explanation",
  }))
    data.set(key, value);
  return data;
}
