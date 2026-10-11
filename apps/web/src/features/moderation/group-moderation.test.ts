import { describe, expect, it, vi } from "vitest";
vi.mock("server-only", () => ({}));
import { groupVersion, parseGroupReview } from "./group-moderation-models";
import { setGroupSuppression } from "./moderation-operations";
import { readModerationCase } from "./moderation-server";
import { moderationDetailRow } from "./moderation-test-fixtures";
import type { ModerationServerClient } from "./moderation-server";
const id = "00000000-0000-4000-8000-000000000001";
import { groupRow } from "./group-moderation-test-fixtures";
const input = {
  caseId: id,
  groupId: id,
  requestId: id,
  version: 3,
  suppressed: true,
  reason: "A protected staff reason.",
};
function client(
  role: string | null = "moderator",
  error: unknown = null,
  data: unknown = 4,
) {
  const rpc = vi.fn(async (name: string, params: Record<string, unknown>) => {
    if (!params) throw new Error("RPC arguments required");
    if (name === "get_own_moderation_staff_access")
      return { data: role ? [{ staff_role: role }] : [], error: null };
    if (name === "get_moderation_case_detail")
      return {
        data: [
          {
            ...moderationDetailRow(),
            target_kind: "group",
            project_context_id: null,
          },
        ],
        error: null,
      };
    if (name === "get_moderation_case_group")
      return { data: groupRow(), error };
    return { data, error };
  });
  return {
    rpc,
    auth: {
      getClaims: async () => ({ data: { claims: { sub: id } }, error: null }),
    },
  } satisfies ModerationServerClient;
}
describe("group staff contract", () => {
  it("strict current content, null manager and report-time version", () => {
    expect(parseGroupReview(groupRow())).toMatchObject({
      version: 3,
      reportVersion: 1,
      contentChanged: true,
      locality: null,
      managerId: null,
    });
    for (const [key, value] of Object.entries({
      version: "3",
      report_version: 0,
      directory_suppressed: "true",
      group_kind: "verified",
      manager_profile_id: "unknown",
    }))
      expect(() => parseGroupReview({ ...groupRow(), [key]: value })).toThrow(
        /malformed/,
      );
    expect(() => groupVersion(Number.MAX_SAFE_INTEGER + 1)).toThrow();
  });
  it("loads group context only inside staff case reads", async () => {
    const c = client();
    const result = await readModerationCase(id, async () => c);
    expect(result.status).toBe("ready");
    if (result.status === "ready")
      expect(result.detail?.group?.contentChanged).toBe(true);
    expect(c.rpc.mock.calls.map((c) => c[0])).toEqual([
      "get_own_moderation_staff_access",
      "get_moderation_case_detail",
      "get_moderation_case_group",
    ]);
    const denied = client(null);
    expect(await readModerationCase(id, async () => denied)).toEqual({
      status: "denied",
    });
    expect(denied.rpc).toHaveBeenCalledTimes(1);
    await expect(
      readModerationCase(id, async () =>
        client("moderator", { code: "42501" }),
      ),
    ).rejects.toThrow(/group review/);
  });
  it.each(["PT409", "42501", "22023", "55000", "unexpected"])(
    "maps %s without a success-shaped result",
    async (code) => {
      expect(
        await setGroupSuppression(input, async () =>
          client("moderator", { code }),
        ),
      ).toEqual({
        status:
          code === "PT409"
            ? "stale"
            : code === "42501"
              ? "denied"
              : code === "22023" || code === "55000"
                ? "invalid"
                : "error",
      });
    },
  );
  it("uses exact staff version/key/intent on retries and never transitions a review", async () => {
    const c = client();
    expect(await setGroupSuppression(input, async () => c)).toEqual({
      status: "accepted",
      version: 4,
    });
    await setGroupSuppression(input, async () => c);
    const writes = c.rpc.mock.calls.filter(
      (call) => call[0] === "set_group_directory_suppression",
    );
    expect(writes).toHaveLength(2);
    expect(writes[0]).toEqual(writes[1]);
    expect(c.rpc).not.toHaveBeenCalledWith(
      "recover_group_command",
      expect.anything(),
    );
    expect(c.rpc).not.toHaveBeenCalledWith(
      "transition_moderation_case",
      expect.anything(),
    );
    expect(
      await setGroupSuppression({ ...input, reason: "short" }, async () => c),
    ).toEqual({ status: "invalid" });
    expect(await setGroupSuppression(input, async () => client(null))).toEqual({
      status: "denied",
    });
    expect(
      await setGroupSuppression(input, async () =>
        client("moderator", null, "4"),
      ),
    ).toEqual({ status: "error" });
  });
});
