import {
  parsePublicEnv,
  type PublicEnvInput,
} from "../src/lib/config/public-env";
import { parseHandoffConfig } from "../src/features/project-app-handoff/handoff-config";

export const publicKeys = [
  "NEXT_PUBLIC_APP_ENV",
  "NEXT_PUBLIC_SUPABASE_URL",
  "NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY",
  "NEXT_PUBLIC_PLANETS_ANDROID_DOWNLOAD_URL",
  "NEXT_PUBLIC_PLANETS_IOS_DOWNLOAD_URL",
] as const;
export function trialPublicConfig(input: Record<string, string | undefined>) {
  for (const key of Object.keys(input))
    if (!publicKeys.includes(key as (typeof publicKeys)[number]))
      throw new Error(`Unexpected static public setting: ${key}`);
  const config = parsePublicEnv(input as PublicEnvInput);
  if (!config.supabasePublishableKey.startsWith("sb_publishable_"))
    throw new Error("Static trial requires a public publishable key.");
  if (config.appEnv === "local") {
    if (config.supabaseUrl !== "http://127.0.0.1:59121")
      throw new Error("Static local trial requires its owned backend.");
  } else if (
    config.appEnv !== "staging" ||
    config.supabaseUrl !== "https://cllpvruvrrvxczjitlqd.supabase.co"
  )
    throw new Error("Static staging trial requires planets-staging.");
  return { config, handoff: parseHandoffConfig(input) };
}
