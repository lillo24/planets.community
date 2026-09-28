import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

import { ModerationCaseDetailView } from "./moderation-components";
import { parseModerationCase } from "./moderation-models";
import { moderationDetailRow } from "./moderation-test-fixtures";

vi.mock("./moderation-actions", () => ({
  addModerationNoteAction: vi.fn(),
  transitionModerationCaseAction: vi.fn(),
}));

describe("moderation case detail", () => {
  it("shows private evidence, notes, and review actions without enforcement controls", () => {
    const detail = parseModerationCase([moderationDetailRow()]);
    if (!detail) throw new Error("missing fixture");
    render(<ModerationCaseDetailView detail={detail} />);

    expect(
      screen.getByRole("heading", { name: "Original report" }),
    ).toBeInTheDocument();
    expect(screen.getByText("Private note")).toBeInTheDocument();
    expect(
      screen.getByText(/does not currently know who physically attended/iu),
    ).toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: "Start review" }),
    ).toBeInTheDocument();
    expect(
      screen.queryByRole("button", { name: /suspend|hide|flag|block/iu }),
    ).not.toBeInTheDocument();
  });
});
