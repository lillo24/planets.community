import { describe, expect, it } from "vitest";

import {
  hasProfileValidationErrors,
  normalizeProfileUpdate,
  validateProfileUpdate,
  type ProfileUpdate,
} from "@/features/profile/profile-models";

const validUpdate: ProfileUpdate = {
  expectedProfileId: "user-a",
  displayName: "Casey",
  bio: "Ready to help.",
  selectedSkillIds: ["skill-1"],
  visibility: {
    display_name: "public",
    bio: "private",
    skills: "public",
  },
};

describe("profile update validation", () => {
  it("trims scalar fields and deduplicates controlled skill IDs", () => {
    expect(
      normalizeProfileUpdate({
        ...validUpdate,
        displayName: "  Casey Artist  ",
        bio: "  Ready to help.  ",
        selectedSkillIds: ["skill-1", "skill-1", "skill-2"],
      }),
    ).toEqual({
      ...validUpdate,
      displayName: "Casey Artist",
      bio: "Ready to help.",
      selectedSkillIds: ["skill-1", "skill-2"],
    });
  });

  it("requires only a valid display name and limits the optional bio", () => {
    expect(hasProfileValidationErrors(validateProfileUpdate(validUpdate))).toBe(
      false,
    );
    expect(
      validateProfileUpdate({ ...validUpdate, displayName: "X" }),
    ).toHaveProperty("displayName");
    expect(
      validateProfileUpdate({ ...validUpdate, bio: "b".repeat(501) }),
    ).toHaveProperty("bio");
    expect(
      hasProfileValidationErrors(
        validateProfileUpdate({ ...validUpdate, bio: "" }),
      ),
    ).toBe(false);
  });
});
