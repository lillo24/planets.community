import "server-only";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import {
  readProfilePageData as readProfile,
  type ProfileServerClientFactory,
} from "./profile-read";
export type {
  ProfilePageData,
  ProfileServerClientFactory,
} from "./profile-read";
export function readProfilePageData(
  createClient: ProfileServerClientFactory = createSupabaseServerClient,
) {
  return readProfile(createClient);
}
