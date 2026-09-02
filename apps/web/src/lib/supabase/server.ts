import "server-only";

import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";

import { readPublicEnv } from "@/lib/config/public-env";
import type { Database } from "@/types/database.generated";

export async function createSupabaseServerClient() {
  const cookieStore = await cookies();
  const config = readPublicEnv();

  return createServerClient<Database>(
    config.supabaseUrl,
    config.supabasePublishableKey,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll();
        },
        setAll(cookiesToSet, cacheHeaders) {
          // Server Components cannot attach these response-cache headers. The
          // request Proxy applies them at the response-writing boundary.
          void cacheHeaders;
          try {
            for (const { name, value, options } of cookiesToSet) {
              cookieStore.set(name, value, options);
            }
          } catch {
            // Server Components cannot write response cookies. The request
            // Proxy refreshes and propagates them before rendering instead.
          }
        },
      },
    },
  );
}
