import { beforeEach, describe, expect, it, vi } from "vitest";

import { readProfilePageData } from "@/features/profile/profile-server";

vi.mock("server-only", () => ({}));

const getClaims = vi.fn();
const from = vi.fn();

describe("readProfilePageData", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    getClaims.mockResolvedValue({
      data: { claims: { sub: "user-1" } },
      error: null,
    });
  });

  it("returns signed out before reading profile data without verified claims", async () => {
    getClaims.mockResolvedValueOnce({
      data: null,
      error: { code: "session_not_found" },
    });

    await expect(
      readProfilePageData(async () => ({ auth: { getClaims }, from }) as never),
    ).resolves.toEqual({ status: "signedOut" });
    expect(from).not.toHaveBeenCalled();
  });

  it("returns a serializable incomplete owner profile and categorized catalog", async () => {
    configureReads({ displayName: null });

    await expect(
      readProfilePageData(async () => ({ auth: { getClaims }, from }) as never),
    ).resolves.toEqual({
      status: "ready",
      data: {
        profile: {
          id: "user-1",
          displayName: null,
          bio: null,
          selectedSkillIds: ["skill-musician"],
          visibility: {
            display_name: "public",
            bio: "private",
            skills: "public",
          },
        },
        categories: [
          {
            id: "category-music",
            slug: "music",
            label: "Music",
            sortOrder: 1,
            skills: [
              {
                id: "skill-musician",
                categoryId: "category-music",
                slug: "musician",
                label: "Musician",
                sortOrder: 1,
              },
            ],
          },
        ],
      },
    });
  });

  it("returns missing for an absent anchor and fails loudly for partial visibility", async () => {
    configureReads({ profileMissing: true });
    await expect(
      readProfilePageData(async () => ({ auth: { getClaims }, from }) as never),
    ).resolves.toEqual({ status: "missing" });

    configureReads({ visibilityIncomplete: true });
    await expect(
      readProfilePageData(async () => ({ auth: { getClaims }, from }) as never),
    ).rejects.toThrow("profile visibility settings are incomplete");
  });
});

function configureReads({
  displayName = "Casey",
  profileMissing = false,
  visibilityIncomplete = false,
}: Readonly<{
  displayName?: string | null;
  profileMissing?: boolean;
  visibilityIncomplete?: boolean;
}>) {
  from.mockImplementation((table: string) => {
    if (table === "profiles") {
      return selectEqSingle(
        profileMissing
          ? { data: null, error: null }
          : {
              data: { id: "user-1", display_name: displayName, bio: null },
              error: null,
            },
      );
    }
    if (table === "skill_categories") {
      return selectOrder({
        data: [
          {
            id: "category-music",
            slug: "music",
            label: "Music",
            sort_order: 1,
          },
        ],
        error: null,
      });
    }
    if (table === "skills") {
      return selectOrder({
        data: [
          {
            id: "skill-musician",
            category_id: "category-music",
            slug: "musician",
            label: "Musician",
            sort_order: 1,
          },
        ],
        error: null,
      });
    }
    if (table === "profile_skills") {
      return selectEq({
        data: [{ skill_id: "skill-musician" }],
        error: null,
      });
    }
    return selectEq({
      data: visibilityIncomplete
        ? [{ field_key: "display_name", audience: "public" }]
        : [
            { field_key: "display_name", audience: "public" },
            { field_key: "bio", audience: "private" },
            { field_key: "skills", audience: "public" },
          ],
      error: null,
    });
  });
}

function selectEqSingle(result: unknown) {
  return {
    select: vi.fn(() => ({
      eq: vi.fn(() => ({ maybeSingle: vi.fn().mockResolvedValue(result) })),
    })),
  };
}

function selectOrder(result: unknown) {
  return {
    select: vi.fn(() => ({ order: vi.fn().mockResolvedValue(result) })),
  };
}

function selectEq(result: unknown) {
  return {
    select: vi.fn(() => ({ eq: vi.fn().mockResolvedValue(result) })),
  };
}
