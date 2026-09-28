import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

import { ModerationCaseDetailView } from "./moderation-components";
import {
  parseModerationCase,
  parseModerationCorroboration,
} from "./moderation-models";
import {
  moderationCorroborationRow,
  moderationDetailRow,
} from "./moderation-test-fixtures";

vi.mock("./moderation-actions", () => ({
  addModerationNoteAction: vi.fn(),
  transitionModerationCaseAction: vi.fn(),
}));

describe("moderation case detail", () => {
  it("shows private evidence, notes, and review actions without enforcement controls", () => {
    const detail = parseModerationCase([moderationDetailRow()]);
    if (!detail) throw new Error("missing fixture");
    render(
      <ModerationCaseDetailView
        detail={{
          ...detail,
          corroboration: parseModerationCorroboration([
            moderationCorroborationRow(),
          ]),
        }}
      />,
    );

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
    expect(
      screen.getByRole("heading", { name: "Group corroboration" }),
    ).toBeInTheDocument();
    expect(screen.getByText("Riley")).toBeInTheDocument();
    expect(
      screen.getByText(/not a vote, verdict, score/iu),
    ).toBeInTheDocument();
    expect(
      screen.getByText(/does not prove physical attendance/iu),
    ).toBeInTheDocument();
  });
});
