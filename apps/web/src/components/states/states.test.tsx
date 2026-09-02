import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

import { EmptyState } from "@/components/states/empty-state";
import { LoadingState } from "@/components/states/loading-state";
import { RecoverableErrorState } from "@/components/states/recoverable-error-state";

describe("common application states", () => {
  it("announces loading without exposing internal detail", () => {
    render(<LoadingState label="Loading activities" />);

    expect(screen.getByRole("status")).toHaveTextContent("Loading activities");
  });

  it("renders a reusable empty state", () => {
    render(
      <EmptyState title="Nothing here" description="Try another search." />,
    );

    expect(screen.getByText("Nothing here")).toBeVisible();
    expect(screen.getByText("Try another search.")).toBeVisible();
  });

  it("invokes the supplied recovery action", () => {
    const onRetry = vi.fn();
    render(
      <RecoverableErrorState
        title="Could not load"
        description="Try again."
        onRetry={onRetry}
      />,
    );

    fireEvent.click(screen.getByRole("button", { name: "Try again" }));

    expect(onRetry).toHaveBeenCalledOnce();
  });
});
