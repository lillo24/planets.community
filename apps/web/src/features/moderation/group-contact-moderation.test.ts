import { describe, expect, it, vi } from "vitest";
vi.mock("server-only", () => ({}));
import { parseGroupContactEvidence } from "./group-contact-moderation-models";
import {
  readModerationCase,
  type ModerationServerClient,
} from "./moderation-server";
import { moderationDetailRow } from "./moderation-test-fixtures";
const id = "00000000-0000-4000-8000-000000000001";
const message = {
  kind: "group_contact_message",
  target_id: id,
  human_id: id,
  source_group_id: id,
  target_group_id: null,
  purpose: null,
  title: null,
  body: "Protected reported message",
  created_at: "2026-10-14T08:00:00Z",
};
function client(role: string | null = "moderator", error: unknown = null) {
  const rpc = vi.fn(async (name: string) => {
    if (name === "get_own_moderation_staff_access")
      return { data: role ? [{ staff_role: role }] : [], error: null };
    if (name === "get_moderation_case_detail")
      return {
        data: [
          {
            ...moderationDetailRow(),
            target_kind: message.kind,
            project_context_id: null,
            resource_request_context_id: null,
          },
        ],
        error: null,
      };
    if (name === "get_moderation_case_group_contact")
      return { data: message, error };
    throw new Error("Unexpected evidence RPC");
  });
  return {
    rpc,
    auth: {
      getClaims: async () => ({ data: { claims: { sub: id } }, error: null }),
    },
  } satisfies ModerationServerClient;
}
describe("case-scoped contact evidence", () => {
  it("parses separate typed message and request targets", () => {
    expect(parseGroupContactEvidence(message)).toMatchObject({
      kind: "group_contact_message",
      humanId: id,
    });
    expect(
      parseGroupContactEvidence({
        ...message,
        kind: "group_contact_request",
        target_group_id: id,
        purpose: "idea",
        title: "Private idea",
      }),
    ).toMatchObject({ purpose: "idea" });
  });
  it("rejects unknown fields, mixed targets and invalid identifiers", () => {
    for (const patch of [
      { source_chat_id: id },
      { kind: "project_chat" },
      { title: "Inherited title" },
      { human_id: "bad" },
      { body: "x".repeat(4001) },
    ])
      expect(() => parseGroupContactEvidence({ ...message, ...patch })).toThrow(
        /malformed/,
      );
  });
  it("requires staff before fetching exact evidence", async () => {
    const denied = client(null);
    expect((await readModerationCase(id, async () => denied)).status).toBe(
      "denied",
    );
    expect(denied.rpc).not.toHaveBeenCalledWith(
      "get_moderation_case_group_contact",
      expect.anything(),
    );
    const staff = client();
    const result = await readModerationCase(id, async () => staff);
    if (result.status !== "ready") throw new Error("Staff case expected.");
    expect(result.detail?.groupContact?.body).toBe(message.body);
    expect(staff.rpc).toHaveBeenCalledWith(
      "get_moderation_case_group_contact",
      { p_expected_staff_profile_id: id, p_case_id: id },
    );
  });
  it("does not conceal an evidence-read failure", async () => {
    await expect(
      readModerationCase(id, async () =>
        client("moderator", { code: "42501" }),
      ),
    ).rejects.toThrow(/evidence/);
  });
});
