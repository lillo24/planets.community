import { describe, expect, it, vi } from "vitest";

const notFound = vi.fn(() => {
  throw new Error("NEXT_NOT_FOUND");
});

vi.mock("next/navigation", () => ({ notFound }));
vi.mock("@/features/moderation/moderation-server", () => ({
  readModerationQueue: vi.fn().mockResolvedValue({ status: "denied" }),
}));

describe("staff-only admin route", () => {
  it("terminates through the not-found boundary when canonical staff access is denied", async () => {
    const { default: AdminPage } = await import("@/app/(admin)/admin/page");

    await expect(
      AdminPage({ searchParams: Promise.resolve({}) }),
    ).rejects.toThrow("NEXT_NOT_FOUND");
    expect(notFound).toHaveBeenCalledOnce();
  });
});
