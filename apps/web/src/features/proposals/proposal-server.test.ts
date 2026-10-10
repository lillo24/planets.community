import { beforeEach, describe, expect, it, vi } from "vitest";
vi.mock("server-only", () => ({}));
const rpc = vi.fn();
vi.mock("@/lib/supabase/server", () => ({
  createSupabaseServerClient: vi.fn(async () => ({ rpc })),
}));
import { getPublicProposal } from "./proposal-server";
const id = "fa021000-0000-4000-8000-000000000001";
const row = {
  proposal_id: id,
  cover_object_path: null,
  creator_profile_id: "owner",
  creator_display_name: null,
  title: "Synthetic Project",
  summary: "Summary",
  description: "Description",
  starts_at: "2030-01-01T10:00:00Z",
  ends_at: "2030-01-01T12:00:00Z",
  event_timezone: "Europe/Rome",
  country_code: "IT",
  locality: "Trento",
  administrative_area: null,
  public_location_label: "Trento",
  derived_status: "upcoming",
  skills: [],
  exact_meeting_text: null,
  exact_location_restricted: true,
};
describe("one-time public location server boundary", () => {
  beforeEach(() => vi.resetAllMocks());
  it("private place/directions use only public detail with no point read", async () => {
    rpc.mockResolvedValueOnce({ data: [row], error: null });
    expect((await getPublicProposal(id))?.exactMapsUrl).toBeUndefined();
    expect(rpc).toHaveBeenCalledTimes(1);
    expect(rpc).toHaveBeenCalledWith("get_public_proposal", {
      p_proposal_id: id,
    });
  });
  it("deliberately public selected label gets a fresh actor-free public exact point", async () => {
    rpc.mockResolvedValueOnce({
      data: [
        {
          ...row,
          exact_location_restricted: false,
          exact_meeting_text: "Synthetic venue",
        },
      ],
      error: null,
    });
    rpc.mockResolvedValueOnce({
      data: {
        item_kind: "one_time",
        item_id: id,
        audience: "public",
        scope: "exact",
        place: {
          kind: "amenity",
          label: "Synthetic venue",
          latitude: 46.12,
          longitude: 11.17,
        },
      },
      error: null,
    });
    const result = await getPublicProposal(id);
    expect(new URL(result!.exactMapsUrl!).searchParams.get("query")).toBe(
      "46.12,11.17",
    );
    expect(rpc).toHaveBeenLastCalledWith("get_location_preview_v1", {
      p_kind: "one_time",
      p_item: id,
      p_view: "public_detail",
    });
  });
  it("privacy change between reads removes Maps destination; read errors are explicit", async () => {
    const publicRow = {
      ...row,
      exact_location_restricted: false,
      exact_meeting_text: "Synthetic venue",
    };
    rpc.mockResolvedValueOnce({ data: [publicRow], error: null });
    rpc.mockResolvedValueOnce({
      data: {
        item_kind: "one_time",
        item_id: id,
        audience: "public",
        scope: "area",
        place: null,
      },
      error: null,
    });
    const revoked = await getPublicProposal(id);
    expect(revoked?.exactMapsUrl).toBeNull();
    expect(revoked?.exact_meeting_text).toBeNull();
    expect(revoked?.exact_location_restricted).toBe(true);
    rpc.mockResolvedValueOnce({ data: [publicRow], error: null });
    rpc.mockResolvedValueOnce({ data: null, error: new Error("Unavailable") });
    await expect(getPublicProposal(id)).rejects.toThrow("Unavailable");
  });
});
