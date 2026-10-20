import { cleanup, render, screen, within } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";

import { ModerationCaseDetailView } from "./moderation-components";
import { parseGroupContactEvidence } from "./group-contact-moderation-models";
import { parseTemplateReview } from "./template-moderation-models";
import { templateReviewRow } from "./template-moderation-test-fixtures";
import {
  parseModerationCase,
  parseModerationCorroboration,
  parseModerationCounterstatement,
} from "./moderation-models";
import {
  moderationCounterstatementRow,
  moderationCorroborationRow,
  moderationDetailRow,
  moderationResourceDetailRow,
} from "./moderation-test-fixtures";

vi.mock("./moderation-actions", () => ({
  addModerationNoteAction: vi.fn(),
  transitionModerationCaseAction: vi.fn(),
  removeModerationTemplateAction: vi.fn(),
}));
vi.mock("next/navigation", () => ({ useRouter: () => ({ refresh: vi.fn() }) }));

describe("moderation case detail", () => {
  afterEach(cleanup);
  it.each<[string, string | null, string]>([
    ["member_contact_request", null, "No introductory note was included."],
    [
      "member_contact_request",
      "Personal introduction",
      "Personal introduction",
    ],
    [
      "member_contact_message",
      "Reported personal message",
      "Reported personal message",
    ],
  ])(
    "shows exact personal contact evidence with origin context",
    (kind, body, expectedText) => {
      const row = moderationDetailRow();
      const detail = parseModerationCase([{ ...row, target_kind: kind }]);
      if (!detail) throw new Error("missing fixture");
      render(
        <ModerationCaseDetailView
          detail={{
            ...detail,
            groupContact: parseGroupContactEvidence({
              kind,
              target_id: row.case_id,
              human_id: row.subject_profile_id,
              source_group_id: row.case_id,
              target_group_id: null,
              purpose: null,
              title: "Synthetic origin group",
              body,
              created_at: row.created_at,
            }),
          }}
        />,
      );
      expect(
        screen.getByText("Reported personal contact content"),
      ).toBeInTheDocument();
      expect(screen.getByText("Origin group")).toBeInTheDocument();
      expect(screen.getByText(expectedText)).toBeInTheDocument();
      expect(screen.queryByText("Represented group")).not.toBeInTheDocument();
      expect(
        screen.queryByRole("link", { name: /conversation|chat/iu }),
      ).not.toBeInTheDocument();
    },
  );
  it("renders valid fractional template duration", () => {
    const detail = parseModerationCase([moderationDetailRow()]);
    if (!detail) throw new Error("missing fixture");
    const row = templateReviewRow();
    const { container } = render(
      <ModerationCaseDetailView
        detail={{
          ...detail,
          template: parseTemplateReview([
            { ...row, content: { ...row.content, duration_seconds: 7200.001 } },
          ]),
          templateBlueprints: [],
        }}
      />,
    );
    expect(
      within(container).getByText(
        new RegExp(String(7200.001 / 3600).replace(".", "\\.") + " hours", "u"),
      ),
    ).toBeInTheDocument();
  });
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

  it.each([
    [null, "Pending", "No statement submitted yet."],
    [
      "My private version of events.",
      "Submitted",
      "My private version of events.",
    ],
  ])(
    "shows counterparty evidence with its final status",
    (statement, status, expectedText) => {
      const detail = parseModerationCase([moderationResourceDetailRow()]);
      if (!detail) throw new Error("missing fixture");
      const { container } = render(
        <ModerationCaseDetailView
          detail={{
            ...detail,
            counterstatement: parseModerationCounterstatement([
              moderationCounterstatementRow(statement),
            ]),
          }}
        />,
      );
      const view = within(container);

      expect(
        view.getByRole("heading", { name: "Counterparty statement" }),
      ).toBeInTheDocument();
      expect(view.getByText(status)).toBeInTheDocument();
      expect(view.getAllByText("Taylor")).not.toHaveLength(0);
      expect(view.getByText(expectedText)).toBeInTheDocument();
      expect(
        view.getByText(/not a verdict or an automatic consequence/iu),
      ).toBeInTheDocument();
      expect(
        view.queryByRole("button", { name: /suspend|hide|flag|block/iu }),
      ).not.toBeInTheDocument();
    },
  );
});
