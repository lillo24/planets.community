import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";

import { ProposalCard, ProposalStatusBadge } from "./proposal-components";
import type { PublicProposalSummary } from "./proposal-models";

describe("proposal presentation", () => {
  it("renders all current discovery badges and a semantic green Just Finished badge", () => {
    const { rerender } = render(<ProposalStatusBadge status="upcoming" />);
    expect(screen.getByText("Upcoming")).toBeInTheDocument();
    rerender(<ProposalStatusBadge status="happening" />);
    expect(screen.getByText("Happening")).toBeInTheDocument();
    rerender(<ProposalStatusBadge status="just_finished" />);
    expect(screen.getByText("Just Finished")).toHaveClass("bg-success");
  });

  it("renders a linked public card with rough location and skills only", () => {
    render(<ProposalCard proposal={summary} />);
    expect(
      screen.getByRole("link", { name: "Community mural" }),
    ).toHaveAttribute(
      "href",
      "/proposals/00000000-0000-4000-8000-000000000001",
    );
    expect(screen.getByText("Central Bologna")).toBeInTheDocument();
    expect(screen.getByText("Required: Mural painting")).toBeInTheDocument();
    expect(screen.queryByText(/fountain/i)).not.toBeInTheDocument();
  });
});

export const summary: PublicProposalSummary = {
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
  skills: [
    {
      id: "skill-mural",
      slug: "mural",
      label: "Mural painting",
      category_id: "category-art",
      category_slug: "art",
      category_label: "Art",
      importance: "required",
    },
  ],
};
