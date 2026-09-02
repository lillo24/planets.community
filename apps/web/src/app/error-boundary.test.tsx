import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

import ErrorPage from "@/app/error";

const { captureClientException } = vi.hoisted(() => ({
  captureClientException: vi.fn(),
}));

vi.mock("@/lib/monitoring/capture-client-exception", () => ({
  captureClientException,
}));

describe("route error boundary", () => {
  it("reports the exception and invokes Next.js reset when retried", () => {
    const error = new Error("private internal detail");
    const reset = vi.fn();

    render(<ErrorPage error={error} reset={reset} />);

    expect(captureClientException).toHaveBeenCalledWith(error);
    expect(
      screen.queryByText("private internal detail"),
    ).not.toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", { name: "Try again" }));

    expect(reset).toHaveBeenCalledOnce();
  });
});
