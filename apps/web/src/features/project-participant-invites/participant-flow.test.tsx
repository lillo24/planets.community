import {
  act,
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
} from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { ParticipantController } from "./participant-controller";
import { ParticipantInviteFlow } from "./participant-invite-flow";
import { ParticipantConfirmation } from "./participant-confirmation";
import {
  fakeGateway,
  preview,
  project,
  receipt,
  token,
} from "./participant-test-fixtures";
vi.mock("client-only", () => ({}));
const replace = vi.fn();
vi.mock("next/navigation", () => ({ useRouter: () => ({ replace }) }));
const controllers: ParticipantController[] = [];
function setup() {
  const fake = fakeGateway();
  const controller = new ParticipantController(fake.gateway);
  controllers.push(controller);
  return { ...fake, controller };
}
afterEach(() => {
  cleanup();
  controllers.forEach((c) => c.dispose());
  controllers.length = 0;
  vi.clearAllMocks();
});
describe("participant browser controls", () => {
  it("renders minimal signed-out preview and exact auth return, never an automatic admission", async () => {
    const { controller, gateway } = setup();
    gateway.auth.mockResolvedValue({ account: null, phase: "signedOut" });
    render(
      <ParticipantInviteFlow
        token={token}
        initialRead={{ preview }}
        config={{}}
        controller={controller}
      />,
    );
    expect(
      await screen.findByRole("link", { name: "Sign in or create an account" }),
    ).toHaveAttribute(
      "href",
      `/auth?returnTo=${encodeURIComponent(`/join/project/${token}`)}`,
    );
    expect(screen.getByRole("link", { name: "View Project" })).toHaveAttribute(
      "href",
      `/proposals/${project.id}`,
    );
    expect(gateway.accept).not.toHaveBeenCalled();
    expect(screen.queryByText(/expires/i)).not.toBeInTheDocument();
  });
  it.each(["missingProfile", "incompleteProfile"] as const)(
    "offers only non-photo continuation for %s",
    async (phase) => {
      const { controller, gateway } = setup();
      gateway.auth.mockResolvedValue({ account: project.id, phase });
      render(
        <ParticipantInviteFlow
          token={token}
          initialRead={{ preview }}
          config={{}}
          controller={controller}
        />,
      );
      expect(
        await screen.findByRole("link", { name: "Complete basic profile" }),
      ).toHaveAttribute(
        "href",
        `${phase === "missingProfile" ? "/auth" : "/profile"}?returnTo=${encodeURIComponent(`/join/project/${token}`)}`,
      );
      expect(
        screen.queryByRole("button", { name: "Join Project" }),
      ).not.toBeInTheDocument();
      expect(gateway.accept).not.toHaveBeenCalled();
    },
  );
  it("requires explicit Join then navigates only after canonical current participation", async () => {
    const { controller, gateway } = setup();
    render(
      <ParticipantInviteFlow
        token={token}
        initialRead={{ preview }}
        config={{}}
        controller={controller}
      />,
    );
    const join = await screen.findByRole("button", { name: "Join Project" });
    expect(gateway.accept).not.toHaveBeenCalled();
    gateway.participation.mockResolvedValue({ current: true, creator: false });
    fireEvent.click(join);
    await vi.waitFor(() =>
      expect(replace).toHaveBeenCalledWith(`/joined/proposals/${project.id}`),
    );
    expect(gateway.accept).toHaveBeenCalledOnce();
  });
  it("keeps committed receipt after read failure and retries status without joining", async () => {
    const { controller, gateway } = setup();
    render(
      <ParticipantInviteFlow
        token={token}
        initialRead={{ preview }}
        config={{}}
        controller={controller}
      />,
    );
    const join = await screen.findByRole("button", { name: "Join Project" });
    gateway.participation.mockRejectedValueOnce(new Error("offline"));
    fireEvent.click(join);
    const retry = await screen.findByRole("button", {
      name: "Retry status check",
    });
    expect(replace).not.toHaveBeenCalled();
    gateway.participation.mockResolvedValue({ current: true, creator: false });
    fireEvent.click(retry);
    expect(
      await screen.findByRole("link", { name: "Continue to PLANETS" }),
    ).toBeVisible();
    expect(gateway.accept).toHaveBeenCalledOnce();
  });
  it("keeps unavailable recovery visible after remount without auto-retry", async () => {
    const { controller, gateway } = setup();
    await controller.openInvite(token);
    gateway.accept.mockRejectedValueOnce(new Error("lost"));
    await controller.join();
    gateway.preview.mockResolvedValue({ available: false });
    render(
      <ParticipantInviteFlow
        token={token}
        initialRead={{ preview: { available: false } }}
        config={{}}
        controller={controller}
      />,
    );
    expect(
      await screen.findByRole("button", { name: "Check previous join" }),
    ).toBeVisible();
    expect(screen.getByText("Invitation unavailable")).toBeVisible();
    expect(gateway.accept).toHaveBeenCalledOnce();
  });
  it("distinguishes service failure from canonical unavailable", async () => {
    const { controller, gateway } = setup();
    gateway.preview.mockRejectedValue(new Error(token));
    render(
      <ParticipantInviteFlow
        token={token}
        initialRead={{ failure: "network" }}
        config={{}}
        controller={controller}
      />,
    );
    await waitFor(() =>
      expect(screen.getByText(/could not confirm/i)).toBeVisible(),
    );
    expect(
      screen.queryByText("Invitation unavailable"),
    ).not.toBeInTheDocument();
  });
  it("token-free confirmation updates after removal and exposes no Join", async () => {
    const { controller, gateway } = setup();
    gateway.participation.mockResolvedValue({ current: true, creator: false });
    render(
      <ParticipantConfirmation
        project={project}
        config={{}}
        controller={controller}
      />,
    );
    expect(
      await screen.findByRole("link", { name: "Open PLANETS" }),
    ).toHaveAttribute(
      "href",
      `https://planets.community/proposals/${project.id}`,
    );
    gateway.participation.mockResolvedValue({ current: false, creator: false });
    await act(() => controller.retryReads());
    expect(
      screen.queryByRole("link", { name: "Open PLANETS" }),
    ).not.toBeInTheDocument();
    expect(gateway.accept).not.toHaveBeenCalled();
    expect(gateway.preview).not.toHaveBeenCalled();
    expect(receipt.outcome).toBe("joined");
  });
});
