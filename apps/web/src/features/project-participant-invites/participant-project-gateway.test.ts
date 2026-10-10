import { describe, expect, it, vi } from "vitest";
import { SupabaseInvitationProjectGateway } from "./participant-project-gateway";
import { account, project } from "./participant-test-fixtures";
vi.mock("client-only", () => ({}));
const cover = `${account}/projects/${project.id}/${account}.webp`;
function row(kind: "one_time" | "recurring") {
  return {
    definition_phase: "defined",
    published_at: "2026-09-01T10:00:00Z",
    reference_time: "2026-09-01T11:00:00Z",
    proposal_id: project.id,
    recurring_activity_id: project.id,
    cover_object_path: cover,
    creator_profile_id: account,
    creator_display_name: "Casey",
    title: "Community mural",
    summary: "Paint together",
    description: "Bring the neighborhood together with color.",
    starts_at: "2030-01-02T18:00:00Z",
    ends_at: "2030-01-02T19:30:00Z",
    event_timezone: "Europe/Rome",
    country_code: "IT",
    locality: "Trento",
    administrative_area: null,
    public_location_label: "Trento",
    derived_status: "upcoming",
    skills: [],
    lifecycle_state: "published",
    topic: null,
    recurrence_type: "weekly",
    weekday: 3,
    day_of_month: null,
    local_start_time: "19:00:00",
    duration_minutes: 90,
    schedule_effective_from: "2030-01-01",
    next_occurrences: [
      {
        local_starts_at: "2030-01-02T19:00:00",
        starts_at: "2030-01-02T18:00:00Z",
        ends_at: "2030-01-02T19:30:00Z",
        event_timezone: "Europe/Rome",
      },
    ],
    exact_meeting_text: "PRIVATE MEMBER ADDRESS",
    exact_location_restricted: false,
    selected_exact_place: { label: "PRIVATE GEOMETRY" },
    ...(kind === "recurring" ? { proposal_id: undefined } : {}),
  };
}
function setup() {
  const rpc = vi
    .fn()
    .mockResolvedValue({ data: [row("one_time")], error: null });
  const download = vi.fn().mockResolvedValue({
    data: new Blob(["fixture"], { type: "image/webp" }),
    error: null,
  });
  const storage = { from: vi.fn(() => ({ download })) };
  return {
    rpc,
    download,
    storage,
    gateway: new SupabaseInvitationProjectGateway({ rpc, storage } as never),
  };
}
describe("public invitation project presentation", () => {
  it.each(["one_time", "recurring"] as const)(
    "uses the existing %s public detail API and drops private fields",
    async (kind) => {
      const { rpc, gateway } = setup();
      rpc.mockResolvedValue({ data: [row(kind)], error: null });
      const detail = await gateway.read({ ...project, kind });
      expect(rpc).toHaveBeenCalledWith(
        kind === "one_time"
          ? "get_public_proposal_v2"
          : "get_public_recurring_activity",
        kind === "one_time"
          ? { p_proposal_id: project.id }
          : {
              p_recurring_activity_id: project.id,
              p_occurrence_limit: 1,
              p_reference_time: expect.any(String),
            },
      );
      expect(detail).toEqual({
        title: "Community mural",
        description: "Bring the neighborhood together with color.",
        coverObjectPath: cover,
      });
      expect(JSON.stringify(detail)).not.toContain("PRIVATE");
      expect(detail).not.toHaveProperty("creator_profile_id");
    },
  );
  it("does not invent details for non-public projects and propagates failed reads", async () => {
    const { rpc, gateway } = setup();
    rpc.mockResolvedValueOnce({ data: [], error: null });
    await expect(gateway.read(project)).resolves.toBeNull();
    rpc.mockResolvedValueOnce({ data: null, error: { code: "42501" } });
    await expect(gateway.read(project)).rejects.toEqual({ code: "42501" });
  });
  it("rejects mismatched project identities, multiple rows and unrelated covers", async () => {
    const { rpc, gateway, download } = setup();
    rpc.mockResolvedValueOnce({
      data: [
        {
          ...row("one_time"),
          proposal_id: account,
          cover_object_path: null,
        },
      ],
      error: null,
    });
    await expect(gateway.read(project)).rejects.toThrow();
    rpc.mockResolvedValueOnce({
      data: [row("one_time"), row("one_time")],
      error: null,
    });
    await expect(gateway.read(project)).rejects.toThrow();
    rpc.mockResolvedValueOnce({
      data: [
        {
          ...row("one_time"),
          cover_object_path: `${account}/projects/${account}/${account}.webp`,
        },
      ],
      error: null,
    });
    await expect(gateway.read(project)).rejects.toThrow();
    expect(download).not.toHaveBeenCalled();
  });
  it("downloads only a validated current project cover through the private bucket's normal SDK path", async () => {
    const { gateway, storage, download } = setup();
    await expect(gateway.cover(project, cover)).resolves.toBeInstanceOf(Blob);
    expect(storage.from).toHaveBeenCalledWith("cover-images");
    expect(download).toHaveBeenCalledWith(cover);
    await expect(
      gateway.cover(project, `${account}/projects/${account}/${account}.webp`),
    ).rejects.toThrow();
    await expect(
      gateway.cover(project, "https://example.com/image.webp"),
    ).rejects.toThrow();
    expect(download).toHaveBeenCalledOnce();
  });
  it("honors download denial and rejects oversized or non-WebP content", async () => {
    const { gateway, download } = setup();
    download.mockResolvedValueOnce({ data: null, error: { status: 403 } });
    await expect(gateway.cover(project, cover)).rejects.toEqual({
      status: 403,
    });
    for (const blob of [
      new Blob(["html"], { type: "text/html" }),
      new Blob([new Uint8Array(512 * 1024 + 1)], { type: "image/webp" }),
    ]) {
      download.mockResolvedValueOnce({ data: blob, error: null });
      await expect(gateway.cover(project, cover)).rejects.toThrow();
    }
  });
});
