import { cleanup, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { AuthStatusCard } from "./auth-status-card";
vi.mock("./auth-session-actions", () => ({
  AuthSessionActions: () => <button>Sign out</button>,
}));
afterEach(cleanup);
describe("participant profile continuation", () => {
  it.each(["direct", "nested"])(
    "returns %s participant onboarding to explicit Join after one profile save",
    (kind) => {
      const preview = `/join/project/${"a".repeat(43)}`;
      const returnTo =
        kind === "direct"
          ? preview
          : `/profile?returnTo=${encodeURIComponent(preview)}`;
      render(
        <AuthStatusCard
          state={{ status: "profileSetupRequired", reason: "incomplete" }}
          returnTo={returnTo}
        />,
      );
      expect(
        screen.getByRole("button", { name: "Complete profile" }),
      ).toHaveAttribute(
        "href",
        `/profile?returnTo=${encodeURIComponent(preview)}`,
      );
      expect(
        screen.getByRole("link", { name: "Back to invitation" }),
      ).toHaveAttribute("href", preview);
    },
  );
  it("offers missing-anchor cancellation and preserves normal/authority profile destinations", () => {
    const preview = `/join/project/${"a".repeat(43)}`;
    const missing = render(
      <AuthStatusCard
        state={{ status: "profileSetupRequired", reason: "missing" }}
        returnTo={preview}
      />,
    );
    expect(
      screen.getByRole("link", { name: "Back to invitation" }),
    ).toHaveAttribute("href", preview);
    missing.unmount();
    const authority = `/invite/project/${"a".repeat(43)}`;
    const invite = render(
      <AuthStatusCard
        state={{ status: "profileSetupRequired", reason: "incomplete" }}
        returnTo={authority}
      />,
    );
    expect(
      screen.getByRole("button", { name: "Complete profile" }),
    ).toHaveAttribute(
      "href",
      `/profile?returnTo=${encodeURIComponent(authority)}`,
    );
    expect(
      screen.queryByRole("link", { name: "Back to invitation" }),
    ).not.toBeInTheDocument();
    invite.unmount();
    render(
      <AuthStatusCard
        state={{ status: "profileSetupRequired", reason: "incomplete" }}
      />,
    );
    expect(
      screen.getByRole("button", { name: "Complete profile" }),
    ).toHaveAttribute("href", "/profile");
  });
});
