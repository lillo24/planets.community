import { describe, it, expect, vi, afterEach } from "vitest";
import {
  cleanup,
  render,
  screen,
  waitFor,
  fireEvent,
} from "@testing-library/react";
import { GroupInviteFlow } from "./group-invite-flow";
import { GroupInvitationController } from "./group-controller";
import { GroupLanding } from "./group-landing";
import type { GroupInvitationGateway } from "./group-gateway";
vi.mock("client-only", () => ({}));
afterEach(cleanup);
const replace = vi.fn();
vi.mock("next/navigation", () => ({ useRouter: () => ({ replace }) }));
const actor = "f303b000-0000-4000-8000-000000000001",
  group = "f303b000-0000-4000-8000-000000000002",
  key = "f303b000-0000-4000-8000-000000000003",
  token = "A".repeat(43);
function fixture() {
  const gateway = {
    auth: vi.fn().mockResolvedValue({ account: actor, phase: "ready" }),
    preview: vi.fn().mockResolvedValue({
      available: true,
      id: group,
      name: "Fictional neighbours",
      kind: "informal",
      role: "co_creator",
      expires: "2026-10-19T00:00:00Z",
    }),
    publicGroup: vi.fn().mockResolvedValue(null),
    current: vi
      .fn()
      .mockResolvedValue({ role: null, delegate: null, membership: null }),
    policy: vi.fn().mockResolvedValue(true),
    recover: vi.fn().mockResolvedValue(null),
    accept: vi.fn().mockResolvedValue({
      group,
      relationship: key,
      kind: "delegate",
      outcome: "accepted",
      current: "co_creator",
      replayed: false,
    }),
    observeIdentity: () => () => {},
  } satisfies GroupInvitationGateway;
  const controller = new GroupInvitationController(gateway, () => key);
  return { gateway, controller };
}
describe("group invitation presentation", () => {
  it("does not turn public content or an ended episode into a joined claim", async () => {
    const f = fixture();
    render(<GroupLanding id={group} confirmation gateway={f.gateway} />);
    await screen.findByText(
      "You do not currently participate or hold an organizer role.",
    );
    expect(screen.queryByText("You are part of this group.")).toBeNull();
    expect(f.gateway.accept).not.toHaveBeenCalled();
    expect(
      screen.getByRole("link", { name: "Open in PLANETS" }),
    ).toHaveAttribute("href", `https://planets.community/groups/${group}`);
    f.controller.dispose();
  });
  it("asks a guest to verify current status without reading private state", async () => {
    const f = fixture();
    f.gateway.auth.mockResolvedValue({ account: null, phase: "guest" });
    render(<GroupLanding id={group} confirmation gateway={f.gateway} />);
    await screen.findByText(
      "Sign in to check your current participation or organizer role.",
    );
    expect(f.gateway.current).not.toHaveBeenCalled();
    expect(f.gateway.accept).not.toHaveBeenCalled();
    f.controller.dispose();
  });
  it("requires informed Co-creator consent and reports failed current read without admitting again", async () => {
    const f = fixture();
    render(
      <GroupInviteFlow token={token} authority controller={f.controller} />,
    );
    const accept = await screen.findByRole("button", {
      name: "Accept organizer role",
    });
    expect(accept).toBeDisabled();
    expect(screen.getByText(/private draft access/u)).toBeInTheDocument();
    fireEvent.click(
      screen.getByRole("checkbox", { name: /I understand and accept/u }),
    );
    f.gateway.current.mockRejectedValueOnce(new Error("offline"));
    fireEvent.click(accept);
    await screen.findByText(
      "Your action was recorded, but current status could not be checked.",
    );
    expect(f.gateway.accept).toHaveBeenCalledTimes(1);
    fireEvent.click(screen.getByRole("button", { name: "Retry status check" }));
    await screen.findByText(/no longer current/u);
    expect(f.gateway.accept).toHaveBeenCalledTimes(1);
    f.controller.dispose();
  });
  it("retains original authority retry after its single-use preview becomes unavailable", async () => {
    const f = fixture();
    render(
      <GroupInviteFlow token={token} authority controller={f.controller} />,
    );
    const accept = await screen.findByRole("button", {
      name: "Accept organizer role",
    });
    fireEvent.click(
      screen.getByRole("checkbox", { name: /I understand and accept/u }),
    );
    f.gateway.accept.mockRejectedValueOnce(new Error("lost reply"));
    fireEvent.click(accept);
    await screen.findByRole("button", { name: "Retry original action" });
    f.gateway.preview.mockResolvedValue({ available: false });
    f.gateway.recover.mockResolvedValue({
      group,
      relationship: key,
      kind: "delegate",
      outcome: "accepted",
      current: "revoked",
      replayed: true,
    });
    fireEvent.click(screen.getByRole("button", { name: "Retry" }));
    await waitFor(() =>
      expect(
        screen.getByRole("button", { name: "Retry original action" }),
      ).toBeEnabled(),
    );
    fireEvent.click(
      screen.getByRole("button", { name: "Retry original action" }),
    );
    await screen.findByText(/no longer current/u);
    expect(f.gateway.accept).toHaveBeenCalledTimes(1);
    f.controller.dispose();
  });
});
