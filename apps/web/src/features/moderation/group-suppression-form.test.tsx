import {
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
} from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { GroupSuppressionForm } from "./group-suppression-form";
import { setGroupSuppressionAction } from "./moderation-actions";
const refresh = vi.fn();
vi.mock("next/navigation", () => ({ useRouter: () => ({ refresh }) }));
vi.mock("./moderation-actions", () => ({ setGroupSuppressionAction: vi.fn() }));
afterEach(() => {
  cleanup();
  vi.clearAllMocks();
});
const props = {
  caseId: "00000000-0000-4000-8000-000000000001",
  groupId: "00000000-0000-4000-8000-000000000002",
  version: 3,
  suppressed: false,
};
function submit() {
  fireEvent.change(screen.getByLabelText(/Private reason/), {
    target: { value: "A protected staff reason." },
  });
  fireEvent.click(screen.getByRole("button", { name: "Hide from directory" }));
}
describe("explicit directory suppression", () => {
  it("freezes reason and intent after ambiguous response, retry repeats exact command", async () => {
    vi.mocked(setGroupSuppressionAction)
      .mockRejectedValueOnce(new Error("lost"))
      .mockResolvedValueOnce({ status: "accepted", version: 4 });
    render(<GroupSuppressionForm {...props} />);
    submit();
    await screen.findByRole("button", { name: "Retry same directory action" });
    expect(screen.getByLabelText(/Private reason/)).toBeDisabled();
    const original = vi.mocked(setGroupSuppressionAction).mock.calls[0][0];
    fireEvent.click(
      screen.getByRole("button", { name: "Retry same directory action" }),
    );
    await waitFor(() =>
      expect(setGroupSuppressionAction).toHaveBeenCalledTimes(2),
    );
    expect(vi.mocked(setGroupSuppressionAction).mock.calls[1][0]).toEqual(
      original,
    );
    await waitFor(() => expect(refresh).toHaveBeenCalled());
  });
  it.each(["stale", "denied", "invalid"] as const)(
    "stops %s requests until a new reviewed screen",
    async (status) => {
      vi.mocked(setGroupSuppressionAction).mockResolvedValue({ status });
      render(<GroupSuppressionForm {...props} />);
      submit();
      await screen.findByRole("button", { name: "Reload current review" });
      expect(
        screen.queryByRole("button", { name: "Hide from directory" }),
      ).not.toBeInTheDocument();
      expect(setGroupSuppressionAction).toHaveBeenCalledTimes(1);
    },
  );
  it("restore only clears suppression and explains independent publication", async () => {
    vi.mocked(setGroupSuppressionAction).mockResolvedValue({
      status: "accepted",
      version: 4,
    });
    render(<GroupSuppressionForm {...props} suppressed />);
    expect(screen.getByText(/does not publish drafts/)).toBeInTheDocument();
    fireEvent.change(screen.getByLabelText(/Private reason/), {
      target: { value: "Restoring directory eligibility." },
    });
    fireEvent.click(
      screen.getByRole("button", { name: "Restore directory eligibility" }),
    );
    await waitFor(() =>
      expect(setGroupSuppressionAction).toHaveBeenCalledWith(
        expect.objectContaining({ suppressed: false, version: 3 }),
      ),
    );
  });
});
