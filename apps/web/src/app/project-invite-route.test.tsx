import { render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";

const previewProjectDelegateInvitation = vi.fn();
const readCurrentAuth = vi.fn();

vi.mock("@/features/project-delegates/project-delegate-server", () => ({
  previewProjectDelegateInvitation,
}));
vi.mock("@/features/auth/current-auth", () => ({ readCurrentAuth }));
vi.mock("@/features/project-delegates/project-invite-action", () => ({
  ProjectInviteAction: () => <button>Accept invitation</button>,
}));

const token = "A".repeat(43);

describe("Project delegate invite route", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    readCurrentAuth.mockResolvedValue({ status: "signedOut" });
  });

  it("renders a safe available preview without accepting during GET/render", async () => {
    previewProjectDelegateInvitation.mockResolvedValue({
      isAvailable: true,
      projectId: "00000000-0000-4000-8000-000000000001",
      projectKind: "one_time",
      projectTitle: "Community mural",
      ownerDisplayName: "Casey",
      expiresAt: "2030-01-01T12:00:00Z",
    });
    const { default: Page } = await import("@/app/invite/project/[token]/page");
    render(
      await Page({
        params: Promise.resolve({ token }),
        searchParams: Promise.resolve({}),
      }),
    );

    expect(screen.getByText("Community mural")).toBeVisible();
    expect(screen.getByText(/Casey invited you/u)).toBeVisible();
    expect(
      screen.getByRole("button", { name: "Accept invitation" }),
    ).toBeVisible();
    expect(previewProjectDelegateInvitation).toHaveBeenCalledWith(token);
  });

  it("collapses unavailable and failed previews to one safe state", async () => {
    previewProjectDelegateInvitation.mockRejectedValue(
      new Error("raw token database detail"),
    );
    const { default: Page } = await import("@/app/invite/project/[token]/page");
    render(
      await Page({
        params: Promise.resolve({ token }),
        searchParams: Promise.resolve({}),
      }),
    );
    expect(screen.getByText("Invitation unavailable")).toBeVisible();
    expect(document.body).not.toHaveTextContent("raw token database detail");
  });

  it("uses static non-indexable metadata with no token", async () => {
    const { metadata } = await import("@/app/invite/project/[token]/page");
    expect(metadata.robots).toMatchObject({
      index: false,
      follow: false,
      noarchive: true,
    });
    expect(JSON.stringify(metadata)).not.toContain(token);
  });
});
