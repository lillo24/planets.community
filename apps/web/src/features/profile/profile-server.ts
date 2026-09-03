import "server-only";

import type { SupabaseClient } from "@supabase/supabase-js";

import type {
  ProfileAudience,
  ProfileEditorData,
  ProfileFieldKey,
  ProfileSkill,
} from "@/features/profile/profile-models";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import type { Database } from "@/types/database.generated";

export type ProfilePageData =
  | Readonly<{ status: "signedOut" }>
  | Readonly<{ status: "missing" }>
  | Readonly<{ status: "ready"; data: ProfileEditorData }>;

export type ProfileServerClientFactory = () => Promise<
  SupabaseClient<Database>
>;

export async function readProfilePageData(
  createClient: ProfileServerClientFactory = createProfileServerClient,
): Promise<ProfilePageData> {
  const client = await createClient();
  const { data: claimsData, error: claimsError } =
    await client.auth.getClaims();
  const userId = claimsData?.claims.sub;
  if (claimsError || typeof userId !== "string" || userId.length === 0) {
    return { status: "signedOut" };
  }

  const [
    profileResult,
    categoriesResult,
    skillsResult,
    selectedResult,
    visibilityResult,
  ] = await Promise.all([
    client
      .from("profiles")
      .select("id, display_name, bio")
      .eq("id", userId)
      .maybeSingle(),
    client
      .from("skill_categories")
      .select("id, slug, label, sort_order")
      .order("sort_order"),
    client
      .from("skills")
      .select("id, category_id, slug, label, sort_order")
      .order("sort_order"),
    client.from("profile_skills").select("skill_id").eq("profile_id", userId),
    client
      .from("profile_field_visibility")
      .select("field_key, audience")
      .eq("profile_id", userId),
  ]);

  if (
    profileResult.error ||
    profileResult.data === null ||
    profileResult.data.id !== userId
  ) {
    return { status: "missing" };
  }
  if (
    categoriesResult.error ||
    skillsResult.error ||
    selectedResult.error ||
    visibilityResult.error
  ) {
    throw new Error("The profile settings could not be loaded.");
  }

  const visibility = Object.fromEntries(
    visibilityResult.data.map((row) => [row.field_key, row.audience]),
  ) as Partial<Record<ProfileFieldKey, ProfileAudience>>;
  if (
    visibility.display_name === undefined ||
    visibility.bio === undefined ||
    visibility.skills === undefined ||
    visibilityResult.data.length !== 3
  ) {
    throw new Error("The profile visibility settings are incomplete.");
  }

  const skills: ProfileSkill[] = skillsResult.data.map((skill) => ({
    id: skill.id,
    categoryId: skill.category_id,
    slug: skill.slug,
    label: skill.label,
    sortOrder: skill.sort_order,
  }));

  return {
    status: "ready",
    data: {
      profile: {
        id: profileResult.data.id,
        displayName: profileResult.data.display_name,
        bio: profileResult.data.bio,
        selectedSkillIds: selectedResult.data.map((row) => row.skill_id),
        visibility: visibility as Record<ProfileFieldKey, ProfileAudience>,
      },
      categories: categoriesResult.data.map((category) => ({
        id: category.id,
        slug: category.slug,
        label: category.label,
        sortOrder: category.sort_order,
        skills: skills.filter((skill) => skill.categoryId === category.id),
      })),
    },
  };
}

async function createProfileServerClient(): Promise<SupabaseClient<Database>> {
  return createSupabaseServerClient();
}
