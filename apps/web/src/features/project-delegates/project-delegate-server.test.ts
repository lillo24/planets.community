import { describe, expect, it, vi } from "vitest";

vi.mock("server-only", () => ({}));

import { previewProjectDelegateInvitation } from "./project-delegate-server";

const token = "A".repeat(43);

describe("Project delegate invitation server preview", () => {
  it("performs only the side-effect-free preview RPC", async () => {
    const rpc = vi.fn().mockResolvedValue({
      data: [
        {
          is_available: true,
          project_id: "00000000-0000-4000-8000-000000000001",
          project_kind: "one_time",
          project_title: "Community mural",
          owner_display_name: "Casey",
          expires_at: "2030-01-01T12:00:00Z",
        },
      ],
      error: null,
    });

    await expect(
      previewProjectDelegateInvitation(token, async () => ({ rpc }) as never),
    ).resolves.toMatchObject({
      isAvailable: true,
      projectTitle: "Community mural",
    });
    expect(rpc).toHaveBeenCalledOnce();
    expect(rpc).toHaveBeenCalledWith("preview_project_delegate_invitation", {
      p_token: token,
    });
    expect(rpc).not.toHaveBeenCalledWith(
      "accept_project_delegate_invitation",
      expect.anything(),
    );
  });

  it("turns malformed or failed reads into an app-owned error", async () => {
    const rpc = vi.fn().mockResolvedValue({
      data: null,
      error: { message: "private token diagnostics" },
    });
    await expect(
      previewProjectDelegateInvitation(token, async () => ({ rpc }) as never),
    ).rejects.not.toThrow("private token diagnostics");
  });
});
