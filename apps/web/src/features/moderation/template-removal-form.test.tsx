import {
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
} from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { TemplateRemovalForm } from "./template-removal-form";
import { removeModerationTemplateAction } from "./moderation-actions";
import {
  templateId,
  templateCaseId,
  templateVersion,
  templateReceiptRow,
} from "./template-moderation-test-fixtures";
import {
  parseTemplateRemovalReceipt,
  parseTemplateReview,
} from "./template-moderation-models";
import { ModerationCaseDetailView } from "./moderation-components";
import { parseModerationCase } from "./moderation-models";
import { moderationDetailRow } from "./moderation-test-fixtures";
import { templateReviewRow } from "./template-moderation-test-fixtures";
afterEach(() => {
  cleanup();
  vi.clearAllMocks();
});
const refresh = vi.fn();
vi.mock("next/navigation", () => ({ useRouter: () => ({ refresh }) }));
vi.mock("./moderation-actions", () => ({
  removeModerationTemplateAction: vi.fn(),
  addModerationNoteAction: vi.fn(),
  transitionModerationCaseAction: vi.fn(),
}));
const props = {
  caseId: templateCaseId,
  templateId,
  contentVersion: templateVersion,
  removed: false,
  pageStale: false,
};
function confirm() {
  fireEvent.change(screen.getByLabelText(/Protected removal reason/u), {
    target: { value: "An explicit private removal reason." },
  });
  fireEvent.click(screen.getByRole("checkbox"));
  fireEvent.click(
    screen.getByRole("button", { name: "Confirm template removal" }),
  );
}
describe("explicit template removal", () => {
  it("requires reason and deliberate confirmation, and retries ambiguous delivery with frozen inputs and one UUID", async () => {
    const action = vi.mocked(removeModerationTemplateAction);
    action
      .mockRejectedValueOnce(new Error("private transport details"))
      .mockResolvedValueOnce({
        status: "removed",
        receipt: parseTemplateRemovalReceipt([templateReceiptRow()]),
      });
    render(<TemplateRemovalForm {...props} />);
    expect(
      screen.getByRole("button", { name: "Confirm template removal" }),
    ).toBeDisabled();
    confirm();
    await screen.findByText(/result could not be confirmed/u);
    expect(screen.getByLabelText(/Protected removal reason/u)).toBeDisabled();
    fireEvent.click(
      screen.getByRole("button", { name: "Retry same removal request" }),
    );
    await screen.findByText(
      "Template removed. The source Proposal is unchanged.",
    );
    expect(action.mock.calls[0][0]).toEqual(action.mock.calls[1][0]);
    expect(action.mock.calls[0][0].requestId).toMatch(/^[0-9a-f-]{36}$/u);
    expect(screen.queryByText(/private transport/u)).not.toBeInTheDocument();
  });
  it.each(["already_removed", "stale", "denied", "invalid", "error"] as const)(
    "shows truthful %s state",
    async (status) => {
      vi.mocked(removeModerationTemplateAction).mockResolvedValue(
        status === "already_removed"
          ? {
              status,
              receipt: parseTemplateRemovalReceipt([
                templateReceiptRow(status),
              ]),
            }
          : { status },
      );
      render(<TemplateRemovalForm {...props} />);
      confirm();
      await waitFor(() =>
        expect(screen.getByRole("status")).toBeInTheDocument(),
      );
      if (status === "stale" || status === "invalid") {
        fireEvent.click(screen.getByRole("button", { name: "Refresh review" }));
        expect(refresh).toHaveBeenCalled();
      }
      if (status === "denied")
        expect(
          screen.queryByRole("button", { name: "Confirm template removal" }),
        ).not.toBeInTheDocument();
      if (status === "already_removed")
        expect(
          screen.getByText(/original removal time and staff attribution/u),
        ).toBeInTheDocument();
    },
  );
  it("renders escaped published content and no Project corroboration warning for template provenance", () => {
    const detail = parseModerationCase([
      {
        ...moderationDetailRow(),
        target_kind: "proposal_template",
        project_context_id: null,
      },
    ])!;
    const { container } = render(
      <ModerationCaseDetailView
        detail={{
          ...detail,
          template: parseTemplateReview([templateReviewRow()]),
          templateBlueprints: [],
        }}
      />,
    );
    expect(screen.getByText("<script>untrusted</script>")).toBeInTheDocument();
    expect(container.querySelector("script")).toBeNull();
    expect(screen.queryByText(/physically attended/u)).not.toBeInTheDocument();
    expect(screen.getByText(/Source cover unavailable/u)).toBeInTheDocument();
    expect(
      screen.getByText(/does not remove the source Proposal/u),
    ).toBeInTheDocument();
  });
});
