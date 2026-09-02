import "server-only";

import type { CurrentAuthState } from "@/features/auth/auth-models";
import { createSupabaseServerClient } from "@/lib/supabase/server";

type ClaimsResult = Readonly<{
  data: Readonly<{ claims: Readonly<{ sub?: unknown }> }> | null;
  error: unknown;
}>;

type ProfileResult = Readonly<{
  data: Readonly<{ id: string }> | null;
  error: unknown;
}>;

export type CurrentAuthClient = Readonly<{
  auth: Readonly<{
    getClaims(): Promise<ClaimsResult>;
  }>;
  from(table: "profiles"): {
    select(columns: "id"): {
      eq(
        column: "id",
        value: string,
      ): {
        maybeSingle(): PromiseLike<ProfileResult>;
      };
    };
  };
}>;

export type CurrentAuthClientFactory = () => Promise<CurrentAuthClient>;

const signedOutState = Object.freeze({ status: "signedOut" } as const);
const readyState = Object.freeze({ status: "ready" } as const);
const profileSetupRequiredState = Object.freeze({
  status: "profileSetupRequired",
} as const);

export async function readCurrentAuth(
  createClient: CurrentAuthClientFactory = createCurrentAuthClient,
): Promise<CurrentAuthState> {
  const client = await createClient();
  const { data: claimsData, error: claimsError } =
    await client.auth.getClaims();
  const userId = claimsData?.claims.sub;

  if (claimsError || typeof userId !== "string" || userId.length === 0) {
    return signedOutState;
  }

  const { data: profile, error: profileError } = await client
    .from("profiles")
    .select("id")
    .eq("id", userId)
    .maybeSingle();

  return !profileError && profile?.id === userId
    ? readyState
    : profileSetupRequiredState;
}

async function createCurrentAuthClient(): Promise<CurrentAuthClient> {
  return (await createSupabaseServerClient()) as unknown as CurrentAuthClient;
}
