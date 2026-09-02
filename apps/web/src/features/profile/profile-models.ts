export type ProfileAudience = "public" | "private";
export type ProfileFieldKey = "display_name" | "bio" | "skills";

export type ProfileSkill = Readonly<{
  id: string;
  categoryId: string;
  slug: string;
  label: string;
  sortOrder: number;
}>;

export type ProfileSkillCategory = Readonly<{
  id: string;
  slug: string;
  label: string;
  sortOrder: number;
  skills: readonly ProfileSkill[];
}>;

export type OwnProfile = Readonly<{
  displayName: string | null;
  bio: string | null;
  selectedSkillIds: readonly string[];
  visibility: Readonly<Record<ProfileFieldKey, ProfileAudience>>;
}>;

export type ProfileEditorData = Readonly<{
  profile: OwnProfile;
  categories: readonly ProfileSkillCategory[];
}>;

export type ProfileUpdate = Readonly<{
  displayName: string;
  bio: string;
  selectedSkillIds: readonly string[];
  visibility: Readonly<Record<ProfileFieldKey, ProfileAudience>>;
}>;

export type ProfileValidationErrors = Readonly<{
  displayName?: string;
  bio?: string;
}>;

export function normalizeProfileUpdate(update: ProfileUpdate): ProfileUpdate {
  return {
    ...update,
    displayName: update.displayName.trim(),
    bio: update.bio.trim(),
    selectedSkillIds: [...new Set(update.selectedSkillIds)],
  };
}

export function validateProfileUpdate(
  update: ProfileUpdate,
): ProfileValidationErrors {
  const errors: { displayName?: string; bio?: string } = {};
  const displayNameLength = update.displayName.trim().length;
  if (displayNameLength < 2 || displayNameLength > 60) {
    errors.displayName =
      "Enter 2 to 60 characters after trimming surrounding spaces.";
  }
  if (update.bio.trim().length > 500) {
    errors.bio = "Keep your bio to 500 characters or fewer.";
  }
  return errors;
}

export function hasProfileValidationErrors(
  errors: ProfileValidationErrors,
): boolean {
  return errors.displayName !== undefined || errors.bio !== undefined;
}
