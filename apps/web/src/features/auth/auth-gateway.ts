import "client-only";

import type { SupabaseClient } from "@supabase/supabase-js";

import { handleProfileAnchorInsertFailure } from "@/features/auth/auth-models";
import { createSupabaseBrowserClient } from "@/lib/supabase/browser";
import type { Database } from "@/types/database.generated";

export interface WebAuthGateway {
  requestEmailOtp(email: string): Promise<void>;
  // The canonical gateway returns the verified OTP subject. Ordinary Auth
  // callers can ignore it; injected legacy/test gateways may return void.
  verifyEmailOtp(email: string, token: string): Promise<string | void>;
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

  async verifyEmailOtp(email: string, token: string): Promise<string> {
    const { data, error } = await this.client.auth.verifyOtp({
      email,
      token,
      type: "email",
    });
    if (error) {
      throw error;
    }
    const account = (data.user ?? data.session?.user)?.id;
    if (typeof account !== "string" || !account) {
      throw new Error("OTP verification completed without an identity.");
    }
    return account;
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
