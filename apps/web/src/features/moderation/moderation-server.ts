import "server-only";

import { createSupabaseServerClient } from "@/lib/supabase/server";
import {
  encodeModerationCursor,
  moderationQueuePageSize,
  parseModerationCase,
  parseModerationCorroboration,
  parseModerationCounterstatement,
  parseModerationQueue,
  type ModerationCaseDetail,
  type ModerationQueueCursor,
  type ModerationQueuePage,
  type ModerationStaffRole,
  type ModerationState,
} from "./moderation-models";

type QueryResult = Readonly<{ data: unknown; error: unknown }>;

export type ModerationServerClient = Readonly<{
  auth: Readonly<{
    getClaims(): Promise<
      Readonly<{
        data: Readonly<{ claims: Readonly<{ sub?: unknown }> }> | null;
        error: unknown;
      }>
    >;
  }>;
  rpc(name: string, params: Record<string, unknown>): Promise<QueryResult>;
}>;

export type ModerationServerClientFactory =
  () => Promise<ModerationServerClient>;

export type ModerationStaffAccess = Readonly<{
  profileId: string;
  role: ModerationStaffRole;
  client: ModerationServerClient;
}>;

export type ModerationQueueResult =
  | Readonly<{ status: "denied" }>
  | Readonly<{
      status: "ready";
      staffRole: ModerationStaffRole;
      page: ModerationQueuePage;
    }>;

export type ModerationDetailResult =
  | Readonly<{ status: "denied" }>
  | Readonly<{
      status: "ready";
      staffRole: ModerationStaffRole;
      detail: ModerationCaseDetail | null;
    }>;

export async function requireModerationStaff(
  createClient: ModerationServerClientFactory = createModerationServerClient,
): Promise<ModerationStaffAccess | null> {
  const client = await createClient();
  const { data, error } = await client.auth.getClaims();
  const profileId = data?.claims.sub;
  if (error || typeof profileId !== "string" || profileId.length === 0) {
    return null;
  }
  const access = await client.rpc("get_own_moderation_staff_access", {
    p_expected_profile_id: profileId,
  });
  if (access.error || !Array.isArray(access.data) || access.data.length !== 1) {
    return null;
  }
  const role = (access.data[0] as { staff_role?: unknown }).staff_role;
  if (role !== "moderator" && role !== "admin") return null;
  return { profileId, role, client };
}

export async function readModerationQueue(
  filters: Readonly<{
    state?: ModerationState;
    cursor?: ModerationQueueCursor;
  }>,
  createClient: ModerationServerClientFactory = createModerationServerClient,
): Promise<ModerationQueueResult> {
  const access = await requireModerationStaff(createClient);
  if (!access) return { status: "denied" };
  const result = await access.client.rpc("list_moderation_cases", {
    p_expected_staff_profile_id: access.profileId,
    p_state: filters.state ?? null,
    p_limit: moderationQueuePageSize + 1,
    p_before_created_at: filters.cursor?.createdAt ?? null,
    p_before_case_id: filters.cursor?.caseId ?? null,
  });
  if (result.error)
    throw new Error("The moderation queue could not be loaded.");
  const rows = parseModerationQueue(result.data);
  const cases = rows.slice(0, moderationQueuePageSize);
  const finalCase = cases.at(-1);
  return {
    status: "ready",
    staffRole: access.role,
    page: {
      cases,
      nextCursor:
        rows.length > moderationQueuePageSize && finalCase
          ? encodeModerationCursor({
              createdAt: finalCase.createdAt,
              caseId: finalCase.caseId,
            })
          : undefined,
    },
  };
}

export async function readModerationCase(
  caseId: string,
  createClient: ModerationServerClientFactory = createModerationServerClient,
): Promise<ModerationDetailResult> {
  const access = await requireModerationStaff(createClient);
  if (!access) return { status: "denied" };
  const result = await access.client.rpc("get_moderation_case_detail", {
    p_expected_staff_profile_id: access.profileId,
    p_case_id: caseId,
  });
  if (result.error) throw new Error("The moderation case could not be loaded.");
  const detail = parseModerationCase(result.data);
  if (!detail) {
    return { status: "ready", staffRole: access.role, detail };
  }

  const [corroboration, counterstatement] = await Promise.all([
    detail.projectContextId
      ? access.client.rpc("get_moderation_case_corroboration", {
          p_expected_staff_profile_id: access.profileId,
          p_case_id: caseId,
        })
      : Promise.resolve(null),
    detail.resourceRequestContextId
      ? access.client.rpc("get_moderation_case_counterstatement", {
          p_expected_staff_profile_id: access.profileId,
          p_case_id: caseId,
        })
      : Promise.resolve(null),
  ]);
  if (corroboration?.error) {
    throw new Error(
      "The moderation corroboration evidence could not be loaded.",
    );
  }
  if (counterstatement?.error) {
    throw new Error("The moderation counterstatement could not be loaded.");
  }
  return {
    status: "ready",
    staffRole: access.role,
    detail: {
      ...detail,
      corroboration: corroboration
        ? parseModerationCorroboration(corroboration.data)
        : null,
      counterstatement: counterstatement
        ? parseModerationCounterstatement(counterstatement.data)
        : null,
    },
  };
}

export async function createModerationServerClient(): Promise<ModerationServerClient> {
  return (await createSupabaseServerClient()) as unknown as ModerationServerClient;
}
