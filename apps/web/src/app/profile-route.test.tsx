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

    await expect(
      ProfilePage({
        params: Promise.resolve({}),
        searchParams: Promise.resolve({}),
      }),
    ).rejects.toThrow("NEXT_REDIRECT");
    expect(redirect).toHaveBeenCalledWith("/auth?returnTo=/profile");
  });

  it("rejects external and encoded-external post-save destinations", async () => {
    readProfilePageData.mockResolvedValue({ status: "signedOut" });
    const { default: ProfilePage } =
      await import("@/app/(public)/profile/page");

    for (const returnTo of [
      "https://attacker.example/path",
      "%2F%2Fattacker.example/path",
    ]) {
      redirect.mockClear();
      await expect(
        ProfilePage({
          params: Promise.resolve({}),
          searchParams: Promise.resolve({ returnTo }),
        }),
      ).rejects.toThrow("NEXT_REDIRECT");
      expect(redirect).toHaveBeenCalledWith(
        "/auth?returnTo=%2Fprofile%3FreturnTo%3D%252F",
      );
    }
  });
});
