import { beforeEach, describe, expect, it, vi } from "vitest";

const notFound = vi.fn(() => {
  throw new Error("NEXT_NOT_FOUND");
});
const requireCurrentModerationStaff = vi.fn(() =>
  Promise.resolve<unknown>(null),
);

vi.mock("next/navigation", () => ({ notFound }));
vi.mock("@/features/moderation/moderation-server", () => ({
  readModerationQueue: vi.fn().mockResolvedValue({ status: "denied" }),
  requireCurrentModerationStaff,
}));

describe("staff-only admin route", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("terminates through the not-found boundary when canonical staff access is denied", async () => {
    const { default: AdminPage } = await import("@/app/(admin)/admin/page");

    await expect(
      AdminPage({ searchParams: Promise.resolve({}) }),
    ).rejects.toThrow("NEXT_NOT_FOUND");
    expect(notFound).toHaveBeenCalledOnce();
  });

  it("denies access in the parent layout before child streaming begins", async () => {
    const { default: AdminLayout } = await import("@/app/(admin)/layout");

    await expect(
      AdminLayout({ children: "private admin content" }),
    ).rejects.toThrow("NEXT_NOT_FOUND");
    expect(notFound).toHaveBeenCalledOnce();
  });

  it("renders the child boundary after canonical staff access succeeds", async () => {
    requireCurrentModerationStaff.mockResolvedValueOnce({
      profileId: "staff-profile",
    });
    const { default: AdminLayout } = await import("@/app/(admin)/layout");

    await expect(
      AdminLayout({ children: "private admin content" }),
    ).resolves.toBe("private admin content");
    expect(notFound).not.toHaveBeenCalled();
  });
});
