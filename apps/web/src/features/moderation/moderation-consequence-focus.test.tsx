import type { ComponentProps } from "react";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
} from "@testing-library/react";
import { afterEach, expect, it, vi } from "vitest";
import { moderationConsequenceAction } from "./moderation-actions";
import { ModerationConsequenceControls } from "./moderation-consequence-controls";
import { moderationDetailRow } from "./moderation-test-fixtures";

const probe = vi.hoisted(() => ({
  commits: [] as { present: boolean; focused: boolean }[],
}));
vi.mock("./moderation-actions", () => ({
  moderationConsequenceAction: vi.fn(),
}));
vi.mock("@/components/ui/alert", async (importOriginal) => {
  const actual = await importOriginal<typeof import("@/components/ui/alert")>();
  return {
    ...actual,
    // Observe the real DOM at ref attachment, before the parent's passive
    // effect. Forward its original ref; do not delay or replace its focus logic.
    Alert: function CommitProbe({
      ref,
      ...props
    }: ComponentProps<typeof actual.Alert>) {
      return (
        <actual.Alert
          {...props}
          ref={(node) => {
            if (typeof ref === "function") ref(node);
            else if (ref) ref.current = node;
            if (node)
              probe.commits.push({
                present: document.body.contains(node),
                focused: document.activeElement === node,
              });
          }}
        />
      );
    },
  };
});
afterEach(cleanup);

it("an already-revoked alert can be present before its required outcome focus", async () => {
  probe.commits.length = 0;
  vi.mocked(moderationConsequenceAction).mockResolvedValue({
    status: "error",
    kind: "already_revoked",
  });
  render(
    <ModerationConsequenceControls
      caseId={moderationDetailRow().case_id}
      choices={[
        {
          mode: "apply",
          type: "safety_notice",
          label: "Apply safety notice",
          effect: "Records an independent safety notice.",
        },
      ]}
    />,
  );
  fireEvent.click(screen.getByRole("button", { name: "Apply safety notice" }));
  fireEvent.change(
    screen.getByRole("textbox", { name: "Reason shown to the user" }),
    { target: { value: "Public reason" } },
  );
  fireEvent.change(
    screen.getByRole("textbox", { name: "Private moderation note" }),
    { target: { value: "Separate private note" } },
  );
  fireEvent.click(screen.getByRole("button", { name: "Confirm apply" }));
  await waitFor(() => expect(screen.getByRole("alert")).toHaveFocus());
  expect(probe.commits[0]).toEqual({ present: true, focused: false });
  expect(
    screen.getByRole("textbox", { name: "Reason shown to the user" }),
  ).toHaveValue("Public reason");
  expect(
    screen.getByRole("textbox", { name: "Private moderation note" }),
  ).toHaveValue("Separate private note");
});
