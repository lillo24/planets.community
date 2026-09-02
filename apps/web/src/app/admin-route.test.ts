import { describe, expect, it, vi } from "vitest";

const notFound = vi.fn(() => {
  throw new Error("NEXT_NOT_FOUND");
});

vi.mock("next/navigation", () => ({ notFound }));

describe("reserved admin route", () => {
  it("always terminates through the not-found boundary", async () => {
    const { default: AdminPage } = await import("@/app/(admin)/admin/page");

    expect(AdminPage).toThrow("NEXT_NOT_FOUND");
    expect(notFound).toHaveBeenCalledOnce();
  });
});
