import { describe, expect, it, vi } from "vitest";
import {
  parseTemplateReview,
  parseTemplateBlueprints,
  parseTemplateRemovalReceipt,
} from "./template-moderation-models";
import { removeModerationTemplate } from "./moderation-operations";
import {
  readModerationCase,
  type ModerationServerClient,
} from "./moderation-server";
import { moderationDetailRow } from "./moderation-test-fixtures";
import {
  templateReviewRow,
  templateReceiptRow,
  templateId,
  templateStaffId,
  templateCaseId,
  templateVersion,
} from "./template-moderation-test-fixtures";
vi.mock("server-only", () => ({}));
const input = {
  caseId: templateCaseId,
  templateId,
  requestId: templateReceiptRow().request_id,
  reviewedContentVersion: templateVersion,
  reason: "Explicit protected removal reason.",
};
function client(
  result: { data: unknown; error: unknown } = {
    data: [templateReceiptRow()],
    error: null,
  },
  role: string | null = "moderator",
) {
  return {
    auth: {
      getClaims: async () => ({
        data: { claims: { sub: templateStaffId } },
        error: null,
      }),
    },
    rpc: vi.fn(async (name: string) =>
      name === "get_own_moderation_staff_access"
        ? { data: role ? [{ staff_role: role }] : [], error: null }
        : result,
    ),
  } satisfies ModerationServerClient;
}
describe("template moderation contracts", () => {
  it("parses only current published context and protected effective action", () => {
    const parsed = parseTemplateReview([templateReviewRow()]);
    expect(parsed.description).toBe("<script>untrusted</script>");
    expect(parsed).not.toHaveProperty("baseline");
    expect(parsed.contentChanged).toBe(false);
    expect(() => parseTemplateReview([])).toThrow();
    expect(() =>
      parseTemplateReview([
        { ...templateReviewRow(), current_content_version: "revision-1" },
      ]),
    ).toThrow();
    expect(() =>
      parseTemplateReview([
        { ...templateReviewRow(), content_changed: "false" },
      ]),
    ).toThrow();
    expect(() => parseTemplateBlueprints(Array(51).fill({}))).toThrow();
    expect(() =>
      parseTemplateRemovalReceipt([
        { ...templateReceiptRow(), outcome: "approved" },
      ]),
    ).toThrow();
  });
  it.each(["removed", "already_removed"] as const)(
    "returns truthful %s receipt and binds exact inputs to current staff",
    async (outcome) => {
      const staff = client({
        data: [templateReceiptRow(outcome)],
        error: null,
      });
      const result = await removeModerationTemplate(input, async () => staff);
      expect(result.status).toBe(outcome);
      expect(staff.rpc).toHaveBeenLastCalledWith(
        "remove_moderation_case_template",
        {
          p_expected_staff_profile_id: templateStaffId,
          p_case_id: templateCaseId,
          p_template_id: templateId,
          p_client_request_id: input.requestId,
          p_reviewed_content_version: templateVersion,
          p_reason: input.reason,
        },
      );
    },
  );
  it.each([
    ["PT409", "stale"],
    ["42501", "denied"],
    ["22023", "invalid"],
    ["57014", "error"],
  ])("maps %s to explicit %s", async (code, status) => {
    expect(
      await removeModerationTemplate(input, async () =>
        client({ data: null, error: { code, message: "private details" } }),
      ),
    ).toEqual({ status });
  });
  it("rechecks role on every delivery, including receipt retry", async () => {
    const staff = client();
    const factory = async () => staff;
    await removeModerationTemplate(input, factory);
    staff.rpc.mockImplementation(async () => ({ data: [], error: null }));
    expect(await removeModerationTemplate(input, factory)).toEqual({
      status: "denied",
    });
    expect(
      staff.rpc.mock.calls.filter(
        ([name]) => name === "remove_moderation_case_template",
      ),
    ).toHaveLength(1);
  });
  it("rejects reason/identity/version before calling RPC and never turns transport failure into success", async () => {
    const staff = client();
    expect(
      await removeModerationTemplate(
        { ...input, reason: "short" },
        async () => staff,
      ),
    ).toEqual({ status: "invalid" });
    expect(staff.rpc).not.toHaveBeenCalled();
    staff.rpc.mockImplementation(async (name) => {
      if (name === "get_own_moderation_staff_access")
        return { data: [{ staff_role: "moderator" }], error: null };
      throw new Error("transport details");
    });
    expect(await removeModerationTemplate(input, async () => staff)).toEqual({
      status: "error",
    });
  });
  it("loads template source context without Project evidence and signs media only through source Storage", async () => {
    const staff = client();
    const row = templateReviewRow();
    const review = {
      ...row,
      content: { ...row.content, cover_object_path: "source-cover.webp" },
    };
    staff.rpc.mockImplementation(async (name) => {
      if (name === "get_own_moderation_staff_access")
        return { data: [{ staff_role: "moderator" }], error: null };
      if (name === "get_moderation_case_detail")
        return {
          data: [
            {
              ...moderationDetailRow(),
              target_kind: "proposal_template",
              project_context_id: null,
            },
          ],
          error: null,
        };
      if (name === "get_moderation_case_template")
        return { data: [review], error: null };
      if (name === "list_moderation_case_template_blueprints")
        return { data: [], error: null };
      throw new Error("unexpected evidence read: " + name);
    });
    const sign = vi.fn(async () => ({ data: null, error: { code: "403" } }));
    const result = await readModerationCase(templateCaseId, async () => ({
      ...staff,
      storage: { from: () => ({ createSignedUrl: sign }) },
    }));
    expect(result).toMatchObject({
      status: "ready",
      detail: {
        template: { templateId },
        templateCoverUrl: null,
        corroboration: null,
        counterstatement: null,
      },
    });
    expect(sign).toHaveBeenCalledWith("source-cover.webp", 60);
  });
  it("surfaces stale resource pages as stale, and operational page failure as failure", async () => {
    const staff = client();
    let errorCode = "PT409";
    staff.rpc.mockImplementation(async (name) => {
      if (name === "get_own_moderation_staff_access")
        return { data: [{ staff_role: "moderator" }], error: null };
      if (name === "get_moderation_case_detail")
        return {
          data: [
            {
              ...moderationDetailRow(),
              target_kind: "proposal_template",
              project_context_id: null,
            },
          ],
          error: null,
        };
      if (name === "get_moderation_case_template")
        return { data: [templateReviewRow()], error: null };
      return { data: null, error: { code: errorCode } };
    });
    expect(
      await readModerationCase(templateCaseId, async () => staff),
    ).toMatchObject({ detail: { templatePageStale: true } });
    errorCode = "57014";
    await expect(
      readModerationCase(templateCaseId, async () => staff),
    ).rejects.toThrow("resource page could not be loaded");
  });
});
