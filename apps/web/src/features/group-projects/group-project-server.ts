import "server-only";
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@/types/database.generated";
import { parseAttributions } from "./group-project-models";
import type { ProjectGroupAttribution } from "./group-project-models";

export async function publicProjectGroups(
  client: SupabaseClient<Database>,
  ids: string[],
): Promise<Map<string, ProjectGroupAttribution>> {
  if (ids.length === 0) return new Map();
  if (ids.length > 50)
    throw new TypeError("Attribution page exceeded its bound.");
  const { data, error } = await client.rpc("get_public_project_groups", {
    p_project_ids: ids,
  });
  if (error) throw error;
  const groups = parseAttributions(data);
  for (const id of groups.keys())
    if (!ids.includes(id))
      throw new TypeError("Attribution escaped its requested Project batch.");
  return groups;
}
