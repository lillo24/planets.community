import { describe, expect, it, vi } from "vitest";

const redirect = vi.fn(() => {
  throw new Error("NEXT_REDIRECT");
});
const readProfilePageData = vi.fn();

vi.mock("next/navigation", () => ({ redirect }));
vi.mock("@/features/profile/profile-server", () => ({ readProfilePageData }));

describe("profile route", () => {
  it("redirects signed-out access through Auth with a safe return", async () => {
    readProfilePageData.mockResolvedValueOnce({ status: "signedOut" });
    const { default: ProfilePage } =
      await import("@/app/(public)/profile/page");

    await expect(ProfilePage()).rejects.toThrow("NEXT_REDIRECT");
    expect(redirect).toHaveBeenCalledWith("/auth?returnTo=/profile");
  });
});
