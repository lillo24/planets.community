import "server-only";

import type { SupabaseClient } from "@supabase/supabase-js";

import { createSupabaseServerClient } from "@/lib/supabase/server";
import type { Database } from "@/types/database.generated";
import {
  parseProjectDelegateInvitePreview,
  type ProjectDelegateInvitePreview,
} from "./project-delegate-models";

export async function previewProjectDelegateInvitation(
  token: string,
  createClient: () => Promise<
    SupabaseClient<Database>
  > = createProjectDelegateServerClient,
): Promise<ProjectDelegateInvitePreview> {
  const client = await createClient();
  const { data, error } = await client.rpc(
    "preview_project_delegate_invitation",
    { p_token: token },
  );
  if (error || data === null || data.length !== 1) {
    throw new Error("Project delegate invitation preview is unavailable.");
  }
  return parseProjectDelegateInvitePreview(data[0]);
}

async function createProjectDelegateServerClient(): Promise<
  SupabaseClient<Database>
> {
  return createSupabaseServerClient();
}
