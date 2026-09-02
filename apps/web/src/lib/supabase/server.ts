import "server-only";

import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";

import { readPublicEnv } from "@/lib/config/public-env";
import type { Database } from "@/types/database.generated";

export async function createSupabaseServerClient() {
  const config = readPublicEnv();
  const cookieStore = await cookies();

  return createServerClient<Database>(
    config.supabaseUrl,
    config.supabasePublishableKey,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll();
        },
        setAll(cookiesToSet) {
          for (const { name, value, options } of cookiesToSet) {
            cookieStore.set(name, value, options);
          }
        },
      },
    },
  );
}
