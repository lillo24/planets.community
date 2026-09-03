import "server-only";

import type { CurrentAuthState } from "@/features/auth/auth-models";
import { createSupabaseServerClient } from "@/lib/supabase/server";

type ClaimsResult = Readonly<{
  data: Readonly<{ claims: Readonly<{ sub?: unknown }> }> | null;
  error: unknown;
}>;

type ProfileResult = Readonly<{
  data: Readonly<{ display_name: string | null; id: string }> | null;
  error: unknown;
}>;

export type CurrentAuthClient = Readonly<{
  auth: Readonly<{
    getClaims(): Promise<ClaimsResult>;
  }>;
  from(table: "profiles"): {
    select(columns: "id, display_name"): {
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
const missingProfileState = Object.freeze({
  status: "profileSetupRequired",
  reason: "missing",
} as const);
const incompleteProfileState = Object.freeze({
  status: "profileSetupRequired",
  reason: "incomplete",
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
    .select("id, display_name")
    .eq("id", userId)
    .maybeSingle();

  if (profileError || profile?.id !== userId) {
    return missingProfileState;
  }
  return profile.display_name === null ? incompleteProfileState : readyState;
}

async function createCurrentAuthClient(): Promise<CurrentAuthClient> {
  return (await createSupabaseServerClient()) as unknown as CurrentAuthClient;
}
