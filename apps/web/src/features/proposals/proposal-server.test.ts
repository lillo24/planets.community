import { beforeEach, describe, expect, it, vi } from "vitest";
const { rpc } = vi.hoisted(() => ({ rpc: vi.fn() }));
vi.mock("server-only", () => ({}));
vi.mock("@/lib/supabase/server", () => ({
  createSupabaseServerClient: async () => ({ rpc }),
}));
import { getPublicProposal, listPublicProposals } from "./proposal-server";

const id = "00000000-0000-4000-8000-000000000001";
const row = {
  proposal_id: id,
  definition_phase: "idea",
  published_at: "2026-09-01T10:00:00Z",
  reference_time: "2026-09-01T11:00:00Z",
  title: "Garden together",
  summary: "Plan a shared garden together.",
  description: null,
  starts_at: null,
  ends_at: null,
  event_timezone: null,
  country_code: null,
  locality: null,
  administrative_area: null,
  public_location_label: null,
  derived_status: null,
  skills: [],
  cover_object_path: null,
  creator_profile_id: id,
  creator_display_name: null,
  exact_meeting_text: null,
  exact_location_restricted: false,
  exact_location: "PRIVATE VALUE",
};
describe("versioned proposal API", () => {
  beforeEach(() => rpc.mockReset());
  it("forwards phase, search and immutable publication cursor/reference together", async () => {
    rpc.mockResolvedValue({ data: [row], error: null });
    const cursor = {
      id,
      publishedAt: row.published_at,
      referenceTime: row.reference_time,
    };
    const items = await listPublicProposals({
      definitionPhase: "idea",
      query: "garden",
      locality: " Trento ",
      skillId: id,
      cursor,
    });
    expect(rpc).toHaveBeenCalledWith("list_public_proposals_v2", {
      p_limit: 12,
      p_cursor_id: id,
      p_cursor_published_at: row.published_at,
      p_reference_time: row.reference_time,
      p_definition_phase: "idea",
      p_query: "garden",
      p_locality: "Trento",
      p_skill_ids: [id],
    });
    expect(items[0].starts_at).toBeNull();
    expect(items[0]).not.toHaveProperty("exact_location");
  });
  it("opts detail/share into v2 and handles honest missing description", async () => {
    rpc.mockResolvedValue({ data: [row], error: null });
    expect((await getPublicProposal(id))?.description).toBeNull();
    expect(rpc).toHaveBeenCalledWith("get_public_proposal_v2", {
      p_proposal_id: id,
    });
  });
  it("fails on API errors, malformed Defined payloads and absent page anchors", async () => {
    rpc.mockResolvedValue({ data: [], error: new Error("network") });
    await expect(listPublicProposals({})).rejects.toThrow("network");
    rpc.mockResolvedValue({
      data: [{ ...row, definition_phase: "defined" }],
      error: null,
    });
    await expect(listPublicProposals({})).rejects.toThrow();
    rpc.mockResolvedValue({
      data: [{ ...row, published_at: null }],
      error: null,
    });
    await expect(listPublicProposals({})).rejects.toThrow("pagination anchor");
  });
});
