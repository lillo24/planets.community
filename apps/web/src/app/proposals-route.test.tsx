import { render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";

import type { PublicProposalSummary } from "@/features/proposals/proposal-models";

const listPublicProposals = vi.fn();
const listSkillOptions = vi.fn();
const getPublicProposal = vi.fn();
const notFound = vi.fn(() => {
  throw new Error("NEXT_NOT_FOUND");
});

vi.mock("next/navigation", () => ({
  notFound,
  useRouter: () => ({ replace: vi.fn() }),
}));
vi.mock("@/features/proposals/proposal-server", () => ({
  publicProposalPageSize: 12,
  listPublicProposals,
  listSkillOptions,
  getPublicProposal,
}));

const summary: PublicProposalSummary = {
  proposal_id: "00000000-0000-4000-8000-000000000001",
  cover_object_path: null,
  title: "Community mural",
  summary: "Paint together",
  starts_at: "2026-09-03T10:00:00Z",
  ends_at: "2026-09-03T12:00:00Z",
  event_timezone: "Europe/Rome",
  country_code: "IT",
  locality: "Bologna",
  administrative_area: null,
  public_location_label: "Central Bologna",
  derived_status: "just_finished",
  skills: [],
};

describe("public proposal routes", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    listSkillOptions.mockResolvedValue([
      { id: "00000000-0000-4000-8000-000000000010", label: "Mural painting" },
    ]);
  });

  it("loads signed-out list filters and renders cursor pagination", async () => {
    listPublicProposals.mockResolvedValue(
      Array.from({ length: 12 }, (_, index) => ({
        ...summary,
        proposal_id: `00000000-0000-4000-8000-${String(index + 1).padStart(12, "0")}`,
      })),
    );
    const { default: Page } = await import("@/app/(public)/proposals/page");
    const element = await Page({
      searchParams: Promise.resolve({
        locality: " Bologna ",
        skill: "00000000-0000-4000-8000-000000000010",
      }),
    });
    render(element);

    expect(listPublicProposals).toHaveBeenCalledWith({
      locality: "Bologna",
      skillId: "00000000-0000-4000-8000-000000000010",
      cursor: undefined,
    });
    expect(
      screen.getByRole("button", { name: /Go to next page/i }),
    ).toHaveAttribute("href", expect.stringContaining("cursor="));
    expect(
      screen.getByRole("link", { name: "One-time Proposals" }),
    ).toHaveAttribute("aria-current", "page");
    expect(screen.getByRole("link", { name: "Tavoli" })).toHaveAttribute(
      "href",
      "/tavoli",
    );
  });

  it("renders restricted and public exact locations without leaking hidden text", async () => {
    const { default: Page } =
      await import("@/app/(public)/proposals/[id]/page");
    getPublicProposal.mockResolvedValue({
      ...summary,
      creator_profile_id: "user-1",
      creator_display_name: "Casey",
      description: "Full details",
      exact_meeting_text: null,
      exact_location_restricted: true,
    });
    const restricted = await Page({
      params: Promise.resolve({ id: summary.proposal_id }),
    });
    const view = render(restricted);
    expect(screen.getByTestId("restricted-location")).toHaveTextContent(
      "Exact location available after joining.",
    );
    expect(screen.queryByText(/fountain/i)).not.toBeInTheDocument();

    view.unmount();
    getPublicProposal.mockResolvedValue({
      ...summary,
      creator_profile_id: "user-1",
      creator_display_name: null,
      description: "Full details",
      exact_meeting_text: "At the fountain",
      exact_location_restricted: false,
    });
    render(
      await Page({ params: Promise.resolve({ id: summary.proposal_id }) }),
    );
    expect(screen.getByTestId("public-exact-location")).toHaveTextContent(
      "At the fountain",
    );
  });

  it("uses safe route errors and preserves 404 behavior", async () => {
    const { default: Page } =
      await import("@/app/(public)/proposals/[id]/page");
    getPublicProposal.mockRejectedValueOnce(
      new Error("raw private database error"),
    );
    render(
      await Page({ params: Promise.resolve({ id: summary.proposal_id }) }),
    );
    expect(
      screen.getByText("Proposal temporarily unavailable"),
    ).toBeInTheDocument();
    expect(screen.queryByText(/raw private/i)).not.toBeInTheDocument();

    await expect(
      Page({ params: Promise.resolve({ id: "not-a-uuid" }) }),
    ).rejects.toThrow("NEXT_NOT_FOUND");
  });
});
