import { describe, expect, it, vi } from "vitest";
import { render, screen, waitFor, fireEvent } from "@testing-library/react";
vi.mock("server-only", () => ({}));
import { parseAttributions, parseGroupProjects } from "./group-project-models";
import { publicProjectGroups } from "./group-project-server";
import { ProjectGroupBadge } from "./project-group-badge";
import { GroupProjectFeed } from "./group-project-feed";
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@/types/database.generated";

const id = "70000000-0000-4000-8000-000000000001";
describe("public registered-group Project provenance", () => {
  it("uses one bounded batch with no role/private table reads", async () => {
    const rpc = vi.fn(async () => ({
      data: [
        {
          project_id: id,
          state: "group",
          group_id: id,
          name: "Garden",
          group_kind: "informal",
        },
      ],
      error: null,
    }));
    const result = await publicProjectGroups(
      { rpc } as unknown as SupabaseClient<Database>,
      [id],
    );
    expect(result.get(id)).toMatchObject({
      state: "group",
      groupId: id,
      name: "Garden",
    });
    expect(rpc).toHaveBeenCalledExactlyOnceWith("get_public_project_groups", {
      p_project_ids: [id],
    });
    await expect(
      publicProjectGroups(
        { rpc } as unknown as SupabaseClient<Database>,
        Array(51).fill(id),
      ),
    ).rejects.toThrow("bound");
  });
  it("rejects failed reads and hidden identity in a neutral projection", async () => {
    const rpc = vi.fn(async () => ({
      data: null,
      error: new Error("Unavailable"),
    }));
    await expect(
      publicProjectGroups({ rpc } as unknown as SupabaseClient<Database>, [id]),
    ).rejects.toThrow("Unavailable");
    expect(() =>
      parseAttributions([
        { project_id: id, state: "unavailable", group_id: id },
      ]),
    ).toThrow();
    expect(() =>
      parseGroupProjects([{ project_id: id, private_planning: "secret" }]),
    ).toThrow();
  });
  it("neutral attribution has no link or hidden name", () => {
    render(<ProjectGroupBadge group={{ state: "unavailable" }} />);
    expect(screen.getByText(/currently unavailable/)).toBeVisible();
    expect(screen.queryByRole("link")).not.toBeInTheDocument();
  });
  it("links the current public group identity", () => {
    render(
      <ProjectGroupBadge
        group={{
          state: "group",
          groupId: id,
          name: "Garden",
          kind: "organization",
        }}
      />,
    );
    expect(screen.getByRole("link", { name: /Garden/ })).toHaveAttribute(
      "href",
      `/groups/${id}`,
    );
  });
  it("retains the failed cursor and retries explicitly", async () => {
    const items = Array.from({ length: 20 }, (_, n) => ({
      id: `${id}-${n}`,
      title: `Project ${n}`,
      summary: "Public purpose",
      kind: "one_time" as const,
      idea: true,
      publishedAt: "2026-10-13T10:00:00Z",
    }));
    const reader = vi
      .fn()
      .mockResolvedValueOnce(items)
      .mockRejectedValueOnce(new Error("network"))
      .mockResolvedValueOnce([]);
    render(<GroupProjectFeed groupId={id} reader={reader} />);
    await waitFor(() =>
      expect(screen.getByRole("button", { name: "Load more" })).toBeEnabled(),
    );
    fireEvent.click(screen.getByRole("button", { name: "Load more" }));
    await screen.findByRole("button", { name: "Retry" });
    expect(screen.getByRole("link", { name: "Project 0" })).toBeVisible();
    fireEvent.click(screen.getByRole("button", { name: "Retry" }));
    await waitFor(() => expect(reader).toHaveBeenCalledTimes(3));
    expect(reader.mock.calls[1]).toEqual(reader.mock.calls[2]);
  });
  it("ignores a late page from a previous group", async () => {
    let complete!: (value: []) => void;
    const reader = vi
      .fn()
      .mockReturnValueOnce(
        new Promise((resolve) => {
          complete = resolve;
        }),
      )
      .mockResolvedValueOnce([]);
    const view = render(<GroupProjectFeed groupId={id} reader={reader} />);
    view.rerender(<GroupProjectFeed groupId="another-group" reader={reader} />);
    await screen.findByText(/No public Projects/);
    complete([]);
    await waitFor(() =>
      expect(screen.queryByText("Loading Projects…")).not.toBeInTheDocument(),
    );
  });
});
