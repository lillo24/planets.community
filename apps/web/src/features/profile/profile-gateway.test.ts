import { beforeEach, describe, expect, it, vi } from "vitest";

import { SupabaseWebProfileGateway } from "@/features/profile/profile-gateway";

const rpc = vi.fn();

describe("SupabaseWebProfileGateway", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    rpc.mockResolvedValue({ data: null, error: null });
  });

  it("calls the one canonical atomic profile operation", async () => {
    const gateway = new SupabaseWebProfileGateway({ rpc } as never);

    await gateway.updateOwnProfile({
      displayName: "Casey",
      bio: "Ready to help.",
      selectedSkillIds: ["skill-mural", "skill-musician"],
      visibility: {
        display_name: "public",
        bio: "private",
        skills: "public",
      },
    });

    expect(rpc).toHaveBeenCalledWith("update_own_profile", {
      p_display_name: "Casey",
      p_bio: "Ready to help.",
      p_skill_ids: ["skill-mural", "skill-musician"],
      p_display_name_audience: "public",
      p_bio_audience: "private",
      p_skills_audience: "public",
    });
  });

  it("propagates a backend failure without converting it to success", async () => {
    const failure = { code: "42501", message: "private database detail" };
    rpc.mockResolvedValueOnce({ data: null, error: failure });
    const gateway = new SupabaseWebProfileGateway({ rpc } as never);

    await expect(
      gateway.updateOwnProfile({
        displayName: "Casey",
        bio: "",
        selectedSkillIds: [],
        visibility: {
          display_name: "public",
          bio: "public",
          skills: "public",
        },
      }),
    ).rejects.toBe(failure);
  });
});
