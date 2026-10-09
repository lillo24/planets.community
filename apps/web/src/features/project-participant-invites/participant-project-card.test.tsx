import {
  act,
  cleanup,
  fireEvent,
  render,
  screen,
} from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { ParticipantProjectCard } from "./participant-project-card";
import { deferred, project, account } from "./participant-test-fixtures";
import type {
  InvitationProject,
  InvitationProjectGateway,
} from "./participant-project-gateway";
vi.mock("client-only", () => ({}));
const detail: InvitationProject = {
  title: "Community mural",
  description: "Paint together.\nEveryone is welcome.",
  coverObjectPath: `${account}/projects/${project.id}/${account}.webp`,
};
const createObjectURL = vi.fn(() => "blob:test-cover");
const revokeObjectURL = vi.fn();
beforeEach(() => {
  vi.stubGlobal(
    "URL",
    class extends URL {
      static createObjectURL = createObjectURL;
      static revokeObjectURL = revokeObjectURL;
    },
  );
  vi.clearAllMocks();
});
afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});
function gateway() {
  return {
    read: vi.fn<InvitationProjectGateway["read"]>().mockResolvedValue(detail),
    cover: vi
      .fn<InvitationProjectGateway["cover"]>()
      .mockResolvedValue(new Blob(["cover"], { type: "image/webp" })),
  };
}
describe("inline invitation project card", () => {
  it("renders the public description and permission-checked cover without another navigation", async () => {
    const remote = gateway();
    const view = render(
      <ParticipantProjectCard
        project={project}
        title="Preview title"
        gateway={remote}
      />,
    );
    expect(await screen.findByText(/Everyone is welcome/)).toBeVisible();
    const image = await screen.findByRole("img", {
      name: "Cover for Community mural",
    });
    expect(image).toHaveAttribute("src", "blob:test-cover");
    expect(image).toHaveAttribute("referrerpolicy", "no-referrer");
    expect(screen.queryByRole("link")).not.toBeInTheDocument();
    expect(remote.cover).toHaveBeenCalledWith(project, detail.coverObjectPath);
    view.unmount();
    expect(revokeObjectURL).toHaveBeenCalledWith("blob:test-cover");
  });
  it("keeps title and description when the optional cover is missing or denied", async () => {
    const remote = gateway();
    remote.cover.mockRejectedValue(new Error("denied"));
    render(
      <ParticipantProjectCard
        project={project}
        title="Preview title"
        gateway={remote}
      />,
    );
    expect(await screen.findByText(/Everyone is welcome/)).toBeVisible();
    expect(screen.queryByRole("img")).not.toBeInTheDocument();
    expect(screen.queryByText(/unavailable|denied/i)).not.toBeInTheDocument();
  });
  it("drops a broken image while keeping the project content", async () => {
    render(
      <ParticipantProjectCard
        project={project}
        title="Preview title"
        gateway={gateway()}
      />,
    );
    fireEvent.error(await screen.findByRole("img"));
    expect(screen.queryByRole("img")).not.toBeInTheDocument();
    expect(screen.getByText(/Everyone is welcome/)).toBeVisible();
  });
  it("does not publish a late cover after unmount", async () => {
    const remote = gateway();
    const pending = deferred<Blob>();
    remote.cover.mockReturnValue(pending.promise);
    const view = render(
      <ParticipantProjectCard
        project={project}
        title="Preview title"
        gateway={remote}
      />,
    );
    await screen.findByText(/Everyone is welcome/);
    view.unmount();
    await act(async () =>
      pending.resolve(new Blob(["cover"], { type: "image/webp" })),
    );
    expect(createObjectURL).not.toHaveBeenCalled();
  });
  it("does not replace a new project's description with a stale response", async () => {
    const remote = gateway();
    const pending = deferred<InvitationProject | null>();
    remote.read.mockReturnValueOnce(pending.promise).mockResolvedValueOnce({
      title: "New project",
      description: "New description",
      coverObjectPath: null,
    });
    const view = render(
      <ParticipantProjectCard
        project={project}
        title="Old preview"
        gateway={remote}
      />,
    );
    view.rerender(
      <ParticipantProjectCard
        project={{ ...project, id: account }}
        title="New preview"
        gateway={remote}
      />,
    );
    await screen.findByText("New description");
    await act(async () => pending.resolve(detail));
    expect(screen.queryByText(/Everyone is welcome/)).not.toBeInTheDocument();
    expect(screen.getByText("New description")).toBeVisible();
    expect(remote.cover).not.toHaveBeenCalled();
  });
});
