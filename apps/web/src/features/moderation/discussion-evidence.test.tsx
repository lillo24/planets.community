import { describe, expect, it, vi } from "vitest";
import { render, screen } from "@testing-library/react";
vi.mock("server-only", () => ({}));
import {
  DiscussionEvidenceView,
  parseDiscussionEvidence,
} from "./discussion-evidence";
import {
  readModerationCase,
  type ModerationServerClient,
} from "./moderation-server";
import { moderationDetailRow } from "./moderation-test-fixtures";
const id = "00000000-0000-4000-8000-000000000001";
const evidence = {
  message_id: id,
  room_id: id,
  group_id: id,
  title: "Parco",
  body: "<script>private evidence</script>",
  sender_id: id,
  created_at: "2026-10-14T10:00:00Z",
};
describe("discussion report evidence", () => {
  it("rejects extra private fields and malformed exact snapshots", () => {
    expect(parseDiscussionEvidence(evidence)).toEqual(evidence);
    for (const [key, value] of Object.entries({
      room_id: "wrong",
      body: "",
      created_at: "yesterday",
      roster: [],
    }))
      expect(() =>
        parseDiscussionEvidence({ ...evidence, [key]: value }),
      ).toThrow(/malformed/);
  });
  it("renders escaped text without a room browsing link", () => {
    const { container } = render(
      <DiscussionEvidenceView evidence={evidence} />,
    );
    expect(screen.getByText(evidence.body)).toBeVisible();
    expect(container.querySelector("script")).toBeNull();
    expect(container.querySelector("a")).toBeNull();
  });
  it("fetches only exact evidence after staff authorization and fails on its read error", async () => {
    let failure: unknown = null;
    const rpc = vi.fn(async (name: string) => {
      if (name === "get_own_moderation_staff_access")
        return { data: [{ staff_role: "moderator" }], error: null };
      if (name === "get_moderation_case_detail")
        return {
          data: [
            {
              ...moderationDetailRow(),
              target_kind: "group_discussion_message",
              project_context_id: null,
              resource_request_context_id: null,
            },
          ],
          error: null,
        };
      if (name === "get_moderation_case_group_discussion")
        return { data: evidence, error: failure };
      throw new Error(`Unexpected capability ${name}`);
    });
    const client = {
      rpc,
      auth: {
        getClaims: async () => ({ data: { claims: { sub: id } }, error: null }),
      },
    } satisfies ModerationServerClient;
    const result = await readModerationCase(id, async () => client);
    if (result.status === "ready")
      expect(result.detail?.discussion).toEqual(evidence);
    expect(rpc.mock.calls.map((call) => call[0])).toEqual([
      "get_own_moderation_staff_access",
      "get_moderation_case_detail",
      "get_moderation_case_group_discussion",
    ]);
    failure = { code: "42501" };
    await expect(readModerationCase(id, async () => client)).rejects.toThrow(
      /evidence could not be loaded/,
    );
  });
});
