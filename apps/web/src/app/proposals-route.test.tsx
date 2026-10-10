import { cleanup, render, screen } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

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
  definition_phase: "defined",
  published_at: "2026-09-01T10:00:00Z",
  reference_time: "2026-09-01T11:00:00Z",
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
  it("renders an optional Idea detail and keeps the app compatibility fallback", async () => {
    getPublicProposal.mockResolvedValue({
      ...summary,
      definition_phase: "idea",
      starts_at: null,
      ends_at: null,
      event_timezone: null,
      public_location_label: null,
      derived_status: null,
      description: null,
      creator_profile_id: summary.proposal_id,
      creator_display_name: null,
      exact_meeting_text: null,
      exact_location_restricted: false,
    });
    const { default: Page } =
      await import("@/app/(public)/proposals/[id]/page");
    render(
      await Page({ params: Promise.resolve({ id: summary.proposal_id }) }),
    );
    expect(screen.getByText("In definition")).toBeInTheDocument();
    expect(screen.getByText("Date to decide together")).toBeInTheDocument();
    expect(screen.getByText("Place to decide together")).toBeInTheDocument();
    expect(
      screen.getByText(/older app shows it as unavailable/),
    ).toBeInTheDocument();
    expect(screen.queryByText("Completed")).not.toBeInTheDocument();
  });
  afterEach(cleanup);
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
        definition_phase: "defined",
        published_at: "2026-09-01T10:00:00Z",
        reference_time: "2026-09-01T11:00:00Z",
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
      exact_meeting_text: "Synthetic verified venue",
      exact_location_restricted: false,
      exactMapsUrl:
        "https://www.google.com/maps/search/?api=1&query=46.12%2C11.17",
    });
    render(
      await Page({ params: Promise.resolve({ id: summary.proposal_id }) }),
    );
    expect(screen.getByTestId("public-exact-location")).toHaveTextContent(
      "Synthetic verified venue",
    );
    expect(
      screen.getByRole("link", { name: "Open exact location in Google Maps" }),
    ).toHaveAttribute(
      "href",
      "https://www.google.com/maps/search/?api=1&query=46.12%2C11.17",
    );
  });

  it("keeps phase, keyword, city and skill together in publication pagination", async () => {
    listPublicProposals.mockResolvedValue(
      Array.from({ length: 12 }, () => summary),
    );
    const { default: Page } = await import("@/app/(public)/proposals/page");
    render(
      await Page({
        searchParams: Promise.resolve({
          phase: "idea",
          query: "garden",
          locality: "Trento",
          skill: "00000000-0000-4000-8000-000000000010",
        }),
      }),
    );
    expect(listPublicProposals).toHaveBeenCalledWith(
      expect.objectContaining({
        definitionPhase: "idea",
        query: "garden",
        locality: "Trento",
        skillId: "00000000-0000-4000-8000-000000000010",
      }),
    );
    const href = screen
      .getByRole("button", { name: /Go to next page/i })
      .getAttribute("href")!;
    const params = new URL(href, "https://example.test").searchParams;
    expect(params.get("phase")).toBe("idea");
    expect(params.get("query")).toBe("garden");
    expect(params.get("locality")).toBe("Trento");
    expect(params.get("skill")).toBe("00000000-0000-4000-8000-000000000010");
    expect(params.get("cursor")).toBeTruthy();
  });

  it("shows a city-only Project without claiming its absent venue is hidden", async () => {
    const { default: Page } =
      await import("@/app/(public)/proposals/[id]/page");
    getPublicProposal.mockResolvedValue({
      ...summary,
      locality: "Trento",
      public_location_label: "Trento",
      creator_profile_id: "user-1",
      creator_display_name: null,
      description: "Full details",
      exact_meeting_text: null,
      exact_location_restricted: false,
    });
    render(
      await Page({ params: Promise.resolve({ id: summary.proposal_id }) }),
    );
    expect(screen.getByText("Trento")).toBeInTheDocument();
    expect(screen.getByTestId("no-exact-location")).toHaveTextContent(
      "Precise meeting instructions have not been added yet.",
    );
    expect(screen.queryByTestId("restricted-location")).not.toBeInTheDocument();
    expect(
      screen.queryByTestId("public-exact-location"),
    ).not.toBeInTheDocument();
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
