import "client-only";

import type { SupabaseClient } from "@supabase/supabase-js";

import { handleProfileAnchorInsertFailure } from "@/features/auth/auth-models";
import { createSupabaseBrowserClient } from "@/lib/supabase/browser";
import type { Database } from "@/types/database.generated";

export interface WebAuthGateway {
  requestEmailOtp(email: string): Promise<void>;
  verifyEmailOtp(email: string, token: string): Promise<void>;
  ensureCurrentProfileAnchor(): Promise<void>;
  signOut(): Promise<void>;
}

export class SupabaseWebAuthGateway implements WebAuthGateway {
  constructor(private readonly client: SupabaseClient<Database>) {}

  async requestEmailOtp(email: string): Promise<void> {
    const { error } = await this.client.auth.signInWithOtp({
      email,
      options: { shouldCreateUser: true },
    });
    if (error) {
      throw error;
    }
  }

  async verifyEmailOtp(email: string, token: string): Promise<void> {
    const { data, error } = await this.client.auth.verifyOtp({
      email,
      token,
      type: "email",
    });
    if (error) {
      throw error;
    }
    if (!data.user && !data.session?.user) {
      throw new Error("OTP verification completed without an identity.");
    }
  }

  async ensureCurrentProfileAnchor(): Promise<void> {
    const { data, error } = await this.client.auth.getClaims();
    const userId = data?.claims.sub;
    if (error) {
      throw error;
    }
    if (typeof userId !== "string" || userId.length === 0) {
      throw new Error("The authenticated identity is unavailable.");
    }

    const { error: profileError } = await this.client
      .from("profiles")
      .insert({ id: userId });
    if (profileError) {
      handleProfileAnchorInsertFailure(profileError);
    }
  }

  async signOut(): Promise<void> {
    const { error } = await this.client.auth.signOut();
    if (error) {
      throw error;
    }
  }
}

export function createWebAuthGateway(): WebAuthGateway {
  return new SupabaseWebAuthGateway(createSupabaseBrowserClient());
}
