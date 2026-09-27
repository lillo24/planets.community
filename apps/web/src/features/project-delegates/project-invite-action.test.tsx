import {
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
} from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";

import type { WebProjectDelegateGateway } from "./project-delegate-gateway";
import { ProjectInviteAction } from "./project-invite-action";

vi.mock("next/navigation", () => ({
  useRouter: () => ({ replace: vi.fn() }),
}));

afterEach(cleanup);

const token = "A".repeat(43);
const preview = {
  isAvailable: true as const,
  projectId: "00000000-0000-4000-8000-000000000001",
  projectKind: "one_time" as const,
  projectTitle: "Community mural",
  ownerDisplayName: "Casey",
  expiresAt: "2030-01-01T12:00:00Z",
};

describe("ProjectInviteAction", () => {
  it("preserves the exact invite route through sign-in and profile setup", () => {
    const view = render(
      <ProjectInviteAction
        auth={{ status: "signedOut" }}
        preview={preview}
        token={token}
        gateway={gateway()}
      />,
    );
    expect(
      screen.getByRole("button", { name: "Sign in to accept" }),
    ).toHaveAttribute(
      "href",
      `/auth?returnTo=${encodeURIComponent(`/invite/project/${token}`)}`,
    );

    view.rerender(
      <ProjectInviteAction
        auth={{ status: "profileSetupRequired", reason: "incomplete" }}
        preview={preview}
        token={token}
        gateway={gateway()}
      />,
    );
    expect(
      screen.getByRole("button", { name: "Complete profile to accept" }),
    ).toHaveAttribute(
      "href",
      `/profile?returnTo=${encodeURIComponent(`/invite/project/${token}`)}`,
    );
  });

  it("accepts only on click with the verified identity and navigates", async () => {
    const projectGateway = gateway();
    const navigation = { replace: vi.fn() };
    render(
      <ProjectInviteAction
        auth={{ status: "ready", profileId: "profile-a" }}
        preview={preview}
        token={token}
        gateway={projectGateway}
        navigation={navigation}
      />,
    );
    expect(projectGateway.acceptInvitation).not.toHaveBeenCalled();
    fireEvent.click(screen.getByRole("button", { name: "Accept invitation" }));
    await waitFor(() => {
      expect(projectGateway.acceptInvitation).toHaveBeenCalledWith(
        "profile-a",
        token,
      );
      expect(navigation.replace).toHaveBeenCalledWith(
        `/proposals/${preview.projectId}`,
      );
    });
  });

  it("maps an accepted recurring invitation to Tavolo detail", async () => {
    const projectGateway = gateway();
    const navigation = { replace: vi.fn() };
    render(
      <ProjectInviteAction
        auth={{ status: "ready", profileId: "profile-a" }}
        preview={{ ...preview, projectKind: "recurring" }}
        token={token}
        gateway={projectGateway}
        navigation={navigation}
      />,
    );

    fireEvent.click(screen.getByRole("button", { name: "Accept invitation" }));
    await waitFor(() => {
      expect(navigation.replace).toHaveBeenCalledWith(
        `/tavoli/${preview.projectId}`,
      );
    });
  });

  it("maps owner self-accept without exposing backend diagnostics", async () => {
    const projectGateway = gateway();
    vi.mocked(projectGateway.acceptInvitation).mockRejectedValueOnce({
      message: "A Project owner cannot accept their own delegate invitation.",
      details: "private diagnostic",
    });
    render(
      <ProjectInviteAction
        auth={{ status: "ready", profileId: "profile-a" }}
        preview={preview}
        token={token}
        gateway={projectGateway}
      />,
    );
    fireEvent.click(screen.getByRole("button", { name: "Accept invitation" }));
    expect(
      await screen.findByText("You already own this Project."),
    ).toBeVisible();
    expect(document.body).not.toHaveTextContent("private diagnostic");
  });
});

function gateway(): WebProjectDelegateGateway {
  return { acceptInvitation: vi.fn().mockResolvedValue(undefined) };
}
