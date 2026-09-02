import "client-only";

import type { SupabaseClient } from "@supabase/supabase-js";

import type { ProfileUpdate } from "@/features/profile/profile-models";
import { createSupabaseBrowserClient } from "@/lib/supabase/browser";
import type { Database } from "@/types/database.generated";

export interface WebProfileGateway {
  updateOwnProfile(update: ProfileUpdate): Promise<void>;
}

export class SupabaseWebProfileGateway implements WebProfileGateway {
  constructor(private readonly client: SupabaseClient<Database>) {}

  async updateOwnProfile(update: ProfileUpdate): Promise<void> {
    const { error } = await this.client.rpc("update_own_profile", {
      p_display_name: update.displayName,
      p_bio: update.bio,
      p_skill_ids: [...update.selectedSkillIds],
      p_display_name_audience: update.visibility.display_name,
      p_bio_audience: update.visibility.bio,
      p_skills_audience: update.visibility.skills,
    });
    if (error) {
      throw error;
    }
  }
}

export function createWebProfileGateway(): WebProfileGateway {
  return new SupabaseWebProfileGateway(createSupabaseBrowserClient());
}
