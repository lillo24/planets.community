import { publicProjectGroups } from "@/features/group-projects/group-project-server";
import "server-only";

import { createSupabaseServerClient } from "@/lib/supabase/server";
import {
  parsePublicRecurringActivityDetail,
  parsePublicRecurringActivitySummary,
  type PublicRecurringActivityDetail,
  type PublicRecurringActivityListRequest,
  type PublicRecurringActivitySummary,
} from "./recurring-activity-models";

export const publicRecurringActivityPageSize = 12;
export const publicRecurringActivityOccurrenceLimit = 5;

export class PublicRecurringActivityReadError extends Error {
  constructor(operation: "list" | "detail") {
    super(`Public Tavoli ${operation} is unavailable.`);
    this.name = "PublicRecurringActivityReadError";
  }
}

export async function listPublicRecurringActivities(
  request: PublicRecurringActivityListRequest,
): Promise<PublicRecurringActivitySummary[]> {
  const client = await createSupabaseServerClient();
  const { data, error } = await client.rpc("list_public_recurring_activities", {
    p_reference_time: request.referenceTime,
    p_limit: publicRecurringActivityPageSize,
    p_cursor_next_starts_at: request.cursor?.nextStartsAt,
    p_cursor_id: request.cursor?.recurringActivityId,
    p_locality: request.locality,
  });
  if (error) throw new PublicRecurringActivityReadError("list");
  const groups = await publicProjectGroups(
    client,
    (data ?? []).map((row) => row.recurring_activity_id),
  );
  return (data ?? []).map((row) => ({
    ...parsePublicRecurringActivitySummary(row),
    groupAttribution: groups.get(row.recurring_activity_id),
  }));
}

export async function getPublicRecurringActivity(
  recurringActivityId: string,
  referenceTime: string,
): Promise<PublicRecurringActivityDetail | null> {
  const client = await createSupabaseServerClient();
  const { data, error } = await client.rpc("get_public_recurring_activity", {
    p_recurring_activity_id: recurringActivityId,
    p_occurrence_limit: publicRecurringActivityOccurrenceLimit,
    p_reference_time: referenceTime,
  });
  if (error) throw new PublicRecurringActivityReadError("detail");
  const rows = data ?? [];
  if (rows.length > 1) throw new PublicRecurringActivityReadError("detail");
  if (rows.length === 0) return null;
  const groups = await publicProjectGroups(client, [recurringActivityId]);
  return {
    ...parsePublicRecurringActivityDetail(rows[0]),
    groupAttribution: groups.get(recurringActivityId),
  };
}
