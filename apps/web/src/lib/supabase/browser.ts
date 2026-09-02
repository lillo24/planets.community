import "client-only";

import { createBrowserClient } from "@supabase/ssr";

import { readPublicEnv } from "@/lib/config/public-env";
import type { Database } from "@/types/database.generated";

export function createSupabaseBrowserClient() {
  const config = readPublicEnv();

  return createBrowserClient<Database>(
    config.supabaseUrl,
    config.supabasePublishableKey,
  );
}
