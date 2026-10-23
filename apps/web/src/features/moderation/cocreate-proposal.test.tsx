import { describe, it, expect, vi } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
vi.mock("server-only", () => ({}));
const { action, refresh } = vi.hoisted(() => ({
  action: vi.fn(),
  refresh: vi.fn(),
}));
vi.mock("./moderation-actions", () => ({ moderateCoProposalAction: action }));
vi.mock("next/navigation", () => ({ useRouter: () => ({ refresh }) }));
import { parseCoProposalReview } from "./cocreate-proposal-models";
import { CoProposalReviewView } from "./cocreate-proposal-review";
import {
  readModerationCase,
  type ModerationServerClient,
} from "./moderation-server";
import { moderateCoProposal } from "./moderation-operations";
import { moderationDetailRow } from "./moderation-test-fixtures";

const id = "00000000-0000-4000-8000-000000000001";
const raw = {
  evidence: {
    proposal_id: id,
    category_id: "videogames",
    name: "Valorant",
    locality: "Trento",
    explanation: "<script>reported text</script>",
    state: "pending",
    interested_count: 2,
    activation_threshold: 3,
    hub_id: null,
    version: 1,
    created_at: "2026-10-23T09:00:00Z",
    expires_at: "2026-11-22T09:00:00Z",
  },
  version: 2,
  state: "pending",
  suppressed: false,
};
function client(rpc: ModerationServerClient["rpc"]): ModerationServerClient {
  return {
    rpc,
    auth: {
      getClaims: async () => ({ data: { claims: { sub: id } }, error: null }),
    },
  };
}

describe("COMM01 scoped moderation", () => {
  it("rejects malformed or leaking evidence instead of displaying partial success", () => {
    expect(parseCoProposalReview(raw).evidence.proposalId).toBe(id);
    for (const value of [
      { ...raw, roster: [] },
      { ...raw, evidence: { ...raw.evidence, supporters: [id] } },
      { ...raw, evidence: { ...raw.evidence, proposal_id: "bad" } },
      { ...raw, version: 0 },
      { ...raw, evidence: { ...raw.evidence, hub_id: id } },
    ])
      expect(() => parseCoProposalReview(value)).toThrow(/malformed/);
  });
  it("reads exact proposal evidence only after fresh staff access", async () => {
    let failure: unknown = null;
    const rpc = vi.fn(async (name: string) => {
      if (name === "get_own_moderation_staff_access")
        return { data: [{ staff_role: "moderator" }], error: null };
      if (name === "get_moderation_case_detail")
        return {
          data: [
            {
              ...moderationDetailRow(),
              target_kind: "cocreate_community_proposal",
              project_context_id: null,
              resource_request_context_id: null,
            },
          ],
          error: null,
        };
      if (name === "get_moderation_case_cocreate_proposal")
        return { data: raw, error: failure };
      throw Error(`Unexpected capability ${name}`);
    });
    const result = await readModerationCase(id, async () => client(rpc));
    if (result.status === "ready")
      expect(result.detail?.coProposal?.evidence.name).toBe("Valorant");
    expect(rpc.mock.calls.map((c) => c[0])).toEqual([
      "get_own_moderation_staff_access",
      "get_moderation_case_detail",
      "get_moderation_case_cocreate_proposal",
    ]);
    failure = { code: "42501" };
    await expect(
      readModerationCase(id, async () => client(rpc)),
    ).rejects.toThrow(/proposal report evidence/);
  });
  it("validates authority, scope and version receipt for every action", async () => {
    const input = {
      caseId: id,
      proposalId: id,
      commandId: id,
      version: 2,
      operation: "suppress" as const,
    };
    const rpc = vi.fn(async (name: string) =>
      name === "get_own_moderation_staff_access"
        ? { data: [{ staff_role: "moderator" }], error: null }
        : {
            data: { operation: "suppress", proposal_id: id, version: 3 },
            error: null,
          },
    );
    expect(
      (await moderateCoProposal(input, async () => client(rpc))).status,
    ).toBe("accepted");
    expect(rpc.mock.calls.map((c) => c[0])).toEqual([
      "get_own_moderation_staff_access",
      "moderate_cocreate_community_proposal",
    ]);
    expect(
      (
        await moderateCoProposal({ ...input, version: 0 }, async () =>
          client(rpc),
        )
      ).status,
    ).toBe("invalid");
    const denied = vi.fn(async () => ({ data: [], error: null }));
    expect(
      (await moderateCoProposal(input, async () => client(denied))).status,
    ).toBe("denied");
    expect(denied).toHaveBeenCalledTimes(1);
  });
  it("renders escaped report text and retries a lost reply with the same frozen intent", async () => {
    action.mockReset();
    action
      .mockResolvedValueOnce({ status: "error" })
      .mockResolvedValueOnce({ status: "accepted" });
    const { container } = render(
      <CoProposalReviewView review={parseCoProposalReview(raw)} caseId={id} />,
    );
    expect(screen.getByText(raw.evidence.explanation)).toBeVisible();
    expect(container.querySelector("script")).toBeNull();
    expect(container.querySelector("a")).toBeNull();
    fireEvent.click(screen.getByRole("button", { name: "Suppress proposal" }));
    await screen.findByRole("button", { name: "Retry same proposal action" });
    fireEvent.click(
      screen.getByRole("button", { name: "Retry same proposal action" }),
    );
    await waitFor(() => expect(action).toHaveBeenCalledTimes(2));
    expect(action.mock.calls[1]).toEqual(action.mock.calls[0]);
    await screen.findByText("Proposal action accepted.");
  });
});
