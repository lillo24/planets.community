import "client-only";

import type { SupabaseClient } from "@supabase/supabase-js";

import { createSupabaseBrowserClient } from "@/lib/supabase/browser";
import type { Database } from "@/types/database.generated";

export interface WebProjectDelegateGateway {
  acceptInvitation(expectedProfileId: string, token: string): Promise<void>;
}

export class SupabaseWebProjectDelegateGateway implements WebProjectDelegateGateway {
  constructor(private readonly client: SupabaseClient<Database>) {}

  async acceptInvitation(
    expectedProfileId: string,
    token: string,
  ): Promise<void> {
    const { error } = await this.client.rpc(
      "accept_project_delegate_invitation",
      {
        p_expected_delegate_profile_id: expectedProfileId,
        p_token: token,
      },
    );
    if (error) throw error;
  }
}

export function createWebProjectDelegateGateway(): WebProjectDelegateGateway {
  return new SupabaseWebProjectDelegateGateway(createSupabaseBrowserClient());
}
