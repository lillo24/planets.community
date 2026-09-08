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
  return (data ?? []).map(parsePublicRecurringActivitySummary);
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
  return rows.length === 0 ? null : parsePublicRecurringActivityDetail(rows[0]);
}
