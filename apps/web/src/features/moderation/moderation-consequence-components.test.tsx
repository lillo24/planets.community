import {
  act,
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
} from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { moderationConsequenceAction } from "./moderation-actions";
import { ModerationCaseDetailView } from "./moderation-components";
import { ModerationConsequencesSection } from "./moderation-consequence-components";
import { ModerationConsequenceControls } from "./moderation-consequence-controls";
import {
  consequenceChoices,
  parseConsequenceHistory,
  type ConsequenceActionResult,
  type ConsequenceEpisode,
} from "./moderation-consequence-models";
import { parseModerationCase } from "./moderation-models";
import {
  moderationConsequenceRow,
  moderationDetailRow,
} from "./moderation-test-fixtures";

vi.mock("./moderation-actions", () => ({
  moderationConsequenceAction: vi.fn(),
  addModerationNoteAction: vi.fn(),
  transitionModerationCaseAction: vi.fn(),
}));
const detail = parseModerationCase([
  { ...moderationDetailRow(), state: "under_review" },
])!;
const staffId = moderationConsequenceRow().actor_profile_id;
beforeEach(() => {
  vi.clearAllMocks();
  vi.mocked(moderationConsequenceAction).mockResolvedValue({
    status: "success",
    kind: "applied",
  });
});
afterEach(cleanup);

describe("case consequence history", () => {
  it("shows independent active and revoked episodes with reasons and linked staff notes", () => {
    const first = {
      ...moderationConsequenceRow(),
      revoked_at: "2026-09-28T11:00:00Z",
    };
    const revoked = {
      ...first,
      action_id: "00000000-0000-4000-8000-000000000933",
      action_kind: "revoked",
      user_reason: "Earlier issue resolved.",
      action_at: first.revoked_at,
    };
    const active = {
      ...moderationConsequenceRow(),
      consequence_id: "00000000-0000-4000-8000-000000000934",
      action_id: "00000000-0000-4000-8000-000000000935",
      consequence_type: "interaction_restriction",
    };
    render(
      <>
        <ModerationCaseDetailView detail={detail} />
        <ModerationConsequencesSection
          detail={detail}
          episodes={parseConsequenceHistory([first, revoked, active])}
          staffRole="moderator"
          staffProfileId={staffId}
        />
      </>,
    );
    expect(screen.getByText("Active")).toBeInTheDocument();
    expect(screen.getByText("Revoked")).toBeInTheDocument();
    expect(screen.getByText("Earlier issue resolved.")).toBeInTheDocument();
    expect(
      screen.getAllByRole("link", { name: "Linked private moderation note" }),
    ).toHaveLength(3);
    expect(
      document.getElementById(`moderation-note-${first.note_id}`),
    ).toHaveTextContent("Private note");
    expect(
      screen.getByText(/not the subject’s global consequence history/),
    ).toBeInTheDocument();
    expect(
      screen.getAllByText(
        (_, element) =>
          element?.tagName === "P" &&
          Boolean(
            element.textContent?.startsWith("Morgan · ") &&
            element.textContent.includes("UTC"),
          ),
      ),
    ).toHaveLength(3);
  });
  it("does not offer historical episode revocation or moderator suspension controls", () => {
    render(
      <ModerationConsequencesSection
        detail={detail}
        episodes={parseConsequenceHistory([
          {
            ...moderationConsequenceRow(),
            consequence_type: "account_suspension",
          },
        ])}
        staffRole="moderator"
        staffProfileId={staffId}
      />,
    );
    expect(
      screen.getByRole("heading", { name: "Account suspension" }),
    ).toBeInTheDocument();
    expect(
      screen.queryByRole("button", { name: /suspend account/i }),
    ).not.toBeInTheDocument();
  });
  it("requires explicit review on received cases, without changing review state", () => {
    render(
      <ModerationConsequencesSection
        detail={{ ...detail, state: "received" }}
        episodes={[]}
        staffRole="admin"
        staffProfileId={staffId}
      />,
    );
    expect(
      screen.getByText(/Start review before applying/),
    ).toBeInTheDocument();
    expect(screen.queryByRole("button")).not.toBeInTheDocument();
    expect(moderationConsequenceAction).not.toHaveBeenCalled();
  });
  it("suppresses self-suspension with a concrete explanation", () => {
    render(
      <ModerationConsequencesSection
        detail={{ ...detail, subjectProfileId: staffId }}
        episodes={[]}
        staffRole="admin"
        staffProfileId={staffId}
      />,
    );
    expect(
      screen.queryByRole("button", { name: "Suspend account" }),
    ).not.toBeInTheDocument();
    expect(screen.getByText(/Another admin is required/)).toBeInTheDocument();
  });
  it("renders plain text rather than interpreting HTML in a stored reason", () => {
    const { container } = render(
      <ModerationConsequencesSection
        detail={detail}
        episodes={parseConsequenceHistory([
          {
            ...moderationConsequenceRow(),
            user_reason: "<script>private()</script>",
          },
        ])}
        staffRole="moderator"
        staffProfileId={staffId}
      />,
    );
    expect(screen.getByText("<script>private()</script>")).toBeInTheDocument();
    expect(container.querySelector("script")).toBeNull();
  });
});

describe("explicit consequence confirmation", () => {
  it.each([
    "Apply safety notice",
    "Restrict new interactions",
    "Suspend account",
  ])(
    "opens %s with blank, distinct, labelled fields and factual effect copy",
    (label) => {
      controls();
      fireEvent.click(screen.getByRole("button", { name: label }));
      expect(
        screen.getByRole("textbox", { name: "Reason shown to the user" }),
      ).toHaveValue("");
      expect(
        screen.getByRole("textbox", { name: "Private moderation note" }),
      ).toHaveValue("");
      expect(
        screen.getByText(
          /Visible only to moderation staff, never to the affected user/,
        ),
      ).toBeInTheDocument();
      expect(
        screen.getByText(/Do not include reporter identity/),
      ).toBeInTheDocument();
      expect(
        screen.getByRole("button", { name: "Confirm apply" }),
      ).toBeInTheDocument();
      expect(
        screen.queryByDisplayValue(detail.explanation),
      ).not.toBeInTheDocument();
      expect(
        screen.queryByDisplayValue(detail.notes[0].body),
      ).not.toBeInTheDocument();
      expect(moderationConsequenceAction).not.toHaveBeenCalled();
    },
  );
  it("makes compatible Resource hide explicit and preserves pending/accepted/lifecycle semantics", () => {
    const choices = consequenceChoices(
      { ...detail, targetKind: "resource_listing" },
      [],
      "moderator",
      staffId,
    );
    render(
      <ModerationConsequenceControls
        caseId={detail.caseId}
        choices={choices}
      />,
    );
    fireEvent.click(
      screen.getByRole("button", { name: "Hide resource listing" }),
    );
    expect(screen.getByText(/reported Resource listing/)).toBeInTheDocument();
    expect(
      screen.getByText(/existing pending requests remain pending/),
    ).toBeInTheDocument();
    expect(
      screen.getByText(/owner lifecycle is unchanged/),
    ).toBeInTheDocument();
  });
  it("revoke confirmation starts blank and explains that withdrawn requests are not restored", async () => {
    controls(
      parseConsequenceHistory([
        {
          ...moderationConsequenceRow(),
          consequence_type: "interaction_restriction",
        },
      ]),
    );
    fireEvent.click(
      screen.getByRole("button", { name: "Remove interaction restriction" }),
    );
    expect(
      screen.getByText(/Previously withdrawn requests are not restored/),
    ).toBeInTheDocument();
    await submit("Confirm revoke");
    const sent = vi.mocked(moderationConsequenceAction).mock.calls[0][1];
    expect(Object.fromEntries(sent)).toMatchObject({
      mode: "revoke",
      consequenceId: moderationConsequenceRow().consequence_id,
      userReason: "Public reason",
      internalNote: "Private note, not the public reason",
    });
  });
  it("returns keyboard focus to the trigger on cancel and resets drafts when choosing another action", () => {
    controls();
    const trigger = screen.getByRole("button", { name: "Apply safety notice" });
    fireEvent.click(trigger);
    expect(
      screen.getByRole("textbox", { name: "Reason shown to the user" }),
    ).toHaveFocus();
    fireEvent.change(
      screen.getByRole("textbox", { name: "Reason shown to the user" }),
      { target: { value: "Old draft" } },
    );
    fireEvent.click(
      screen.getByRole("button", { name: "Restrict new interactions" }),
    );
    expect(
      screen.getByRole("textbox", { name: "Reason shown to the user" }),
    ).toHaveValue("");
    fireEvent.click(screen.getByRole("button", { name: "Cancel" }));
    expect(
      screen.getByRole("button", { name: "Restrict new interactions" }),
    ).toHaveFocus();
    expect(screen.queryByRole("textbox")).not.toBeInTheDocument();
  });
  it("prevents duplicate submit and has no optimistic active episode before confirmation", async () => {
    let resolve!: (value: ConsequenceActionResult) => void;
    vi.mocked(moderationConsequenceAction).mockImplementation(
      () =>
        new Promise((done) => {
          resolve = done;
        }),
    );
    controls();
    fireEvent.click(
      screen.getByRole("button", { name: "Apply safety notice" }),
    );
    await submit();
    expect(screen.getByRole("button", { name: "Saving…" })).toBeDisabled();
    expect(screen.getByRole("button", { name: "Cancel" })).toBeDisabled();
    expect(
      screen.getByRole("button", { name: "Suspend account" }),
    ).toBeDisabled();
    expect(screen.queryByRole("status")).not.toBeInTheDocument();
    await act(async () => resolve({ status: "success", kind: "applied" }));
    expect(screen.getByRole("status")).toHaveTextContent("Consequence applied");
    expect(moderationConsequenceAction).toHaveBeenCalledTimes(1);
  });
  it.each([
    "duplicate",
    "already_revoked",
    "unauthorized",
    "invalid_input",
  ] as const)(
    "renders bounded actionable %s and keeps the two drafts distinct",
    async (kind) => {
      vi.mocked(moderationConsequenceAction).mockResolvedValue({
        status: "error",
        kind,
      });
      controls();
      fireEvent.click(
        screen.getByRole("button", { name: "Apply safety notice" }),
      );
      await submit();
      // Presence is observable at commit, before the passive outcome-focus
      // effect. Synchronize with the keyboard contract, not just the markup.
      await waitFor(() => expect(screen.getByRole("alert")).toHaveFocus());
      expect(screen.getByRole("link", { name: "Reload case" })).toHaveAttribute(
        "href",
        `/admin/cases/${detail.caseId}`,
      );
      expect(
        screen.getByRole("textbox", { name: "Reason shown to the user" }),
      ).toHaveValue("Public reason");
      expect(
        screen.getByRole("textbox", { name: "Private moderation note" }),
      ).toHaveValue("Private note, not the public reason");
      expect(
        screen
          .getByRole("textbox", { name: "Reason shown to the user" })
          .getAttribute("aria-describedby"),
      ).toContain(screen.getByRole("alert").id);
      expect(screen.queryByRole("status")).not.toBeInTheDocument();
    },
  );
  it("shows an explicit unconfirmed failure when the server-action transport throws", async () => {
    vi.mocked(moderationConsequenceAction).mockRejectedValue(
      new Error("secret SQL diagnostics"),
    );
    controls();
    fireEvent.click(
      screen.getByRole("button", { name: "Apply safety notice" }),
    );
    await submit();
    await waitFor(() =>
      expect(screen.getByRole("alert")).toHaveTextContent(
        "could not be confirmed",
      ),
    );
    expect(screen.queryByText(/secret SQL/)).not.toBeInTheDocument();
  });
  it("retains confirmation when refreshed choices remove the completed apply panel", async () => {
    const view = controls();
    fireEvent.click(
      screen.getByRole("button", { name: "Apply safety notice" }),
    );
    await submit();
    await waitFor(() =>
      expect(screen.getByRole("status")).toHaveTextContent(
        "Consequence applied",
      ),
    );
    view.rerender(
      <ModerationConsequenceControls caseId={detail.caseId} choices={[]} />,
    );
    expect(screen.getByRole("status")).toHaveTextContent("Consequence applied");
    expect(screen.queryByRole("textbox")).not.toBeInTheDocument();
    expect(screen.getByRole("status")).toHaveFocus();
  });
});

function controls(episodes: ConsequenceEpisode[] = []) {
  return render(
    <ModerationConsequenceControls
      caseId={detail.caseId}
      choices={consequenceChoices(detail, episodes, "admin", staffId)}
    />,
  );
}
async function submit(label = "Confirm apply") {
  fireEvent.change(
    screen.getByRole("textbox", { name: "Reason shown to the user" }),
    { target: { value: "Public reason" } },
  );
  fireEvent.change(
    screen.getByRole("textbox", { name: "Private moderation note" }),
    { target: { value: "Private note, not the public reason" } },
  );
  fireEvent.click(screen.getByRole("button", { name: label }));
  await waitFor(() => expect(moderationConsequenceAction).toHaveBeenCalled());
}
