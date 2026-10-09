import "client-only";

import { createBrowserClient } from "@supabase/ssr";

import { readPublicEnv, type PublicEnv } from "@/lib/config/public-env";
import type { Database } from "@/types/database.generated";

// The optional public config/OTP-only mode belongs to the isolated static
// invitation trial: same SDK cookie session/refresh/BroadcastChannel, secure
// staging cookies and uncached, no-referrer backend reads. Next defaults stay
// unchanged. URL-carried Auth credentials are disabled in the numeric OTP trial.
export function createSupabaseBrowserClient(
  config: PublicEnv = readPublicEnv(),
  numericOtpOnly = false,
) {
  if (!numericOtpOnly)
    return createBrowserClient<Database>(
      config.supabaseUrl,
      config.supabasePublishableKey,
    );
  return createBrowserClient<Database>(
    config.supabaseUrl,
    config.supabasePublishableKey,
    {
      auth: { detectSessionInUrl: false },
      cookieOptions: { secure: config.appEnv !== "local" },
      global: {
        fetch: (input, init) =>
          fetch(input, {
            ...init,
            cache: "no-store",
            referrerPolicy: "no-referrer",
          }),
      },
    },
  );
}
