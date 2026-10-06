import "server-only";

import { cache } from "react";

import { createSupabaseServerClient } from "@/lib/supabase/server";
import {
  parseConsequenceHistory,
  type ConsequenceEpisode,
} from "./moderation-consequence-models";
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

import {
  parseTemplateReview,
  parseTemplateBlueprints,
  isTemplateVersion,
} from "./template-moderation-models";

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
  storage?: Readonly<{
    from(bucket: string): Readonly<{
      createSignedUrl(
        path: string,
        seconds: number,
      ): Promise<
        Readonly<{ data: { signedUrl: string } | null; error: unknown }>
      >;
    }>;
  }>;
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
      staffProfileId: string;
      consequences: ConsequenceEpisode[];
    }>;

export async function requireModerationStaff(
  createClient: ModerationServerClientFactory = createModerationServerClient,
): Promise<ModerationStaffAccess | null> {
  try {
    const client = await createClient();
    const { data, error } = await client.auth.getClaims();
    const profileId = data?.claims.sub;
    if (error || typeof profileId !== "string" || profileId.length === 0) {
      return null;
    }
    const access = await client.rpc("get_own_moderation_staff_access", {
      p_expected_profile_id: profileId,
    });
    if (
      access.error ||
      !Array.isArray(access.data) ||
      access.data.length !== 1
    ) {
      return null;
    }
    const role = (access.data[0] as { staff_role?: unknown }).staff_role;
    if (role !== "moderator" && role !== "admin") return null;
    return { profileId, role, client };
  } catch {
    // Identity and staff-role establishment must fail closed. Operational
    // moderation reads happen only after this boundary and still throw.
    return null;
  }
}

export const requireCurrentModerationStaff = cache(() =>
  requireModerationStaff(createModerationServerClient),
);

export async function readModerationQueue(
  filters: Readonly<{
    state?: ModerationState;
    cursor?: ModerationQueueCursor;
  }>,
  createClient?: ModerationServerClientFactory,
): Promise<ModerationQueueResult> {
  const access = createClient
    ? await requireModerationStaff(createClient)
    : await requireCurrentModerationStaff();
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
  createClient?: ModerationServerClientFactory,
  templatePage?: Readonly<{ needCursor: string; contentVersion: string }>,
): Promise<ModerationDetailResult> {
  const access = createClient
    ? await requireModerationStaff(createClient)
    : await requireCurrentModerationStaff();
  if (!access) return { status: "denied" };
  const result = await access.client.rpc("get_moderation_case_detail", {
    p_expected_staff_profile_id: access.profileId,
    p_case_id: caseId,
  });
  if (result.error) throw new Error("The moderation case could not be loaded.");
  const detail = parseModerationCase(result.data);
  if (!detail) {
    return {
      status: "ready",
      staffRole: access.role,
      staffProfileId: access.profileId,
      detail,
      consequences: [],
    };
  }

  const [corroboration, counterstatement, consequences, templateResult] = await Promise.all([
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
    access.client.rpc("list_moderation_case_consequence_history", {
      p_expected_staff_profile_id: access.profileId,
      p_case_id: caseId,
    }),
    detail.targetKind === "proposal_template"
      ? access.client.rpc("get_moderation_case_template", {
          p_expected_staff_profile_id: access.profileId,
          p_case_id: caseId,
        })
      : Promise.resolve(null),
  ]);
  if (consequences.error)
    throw new Error("The moderation consequence history could not be loaded.");
  if (corroboration?.error) {
    throw new Error(
      "The moderation corroboration evidence could not be loaded.",
    );
  }
  if (counterstatement?.error) {
    throw new Error("The moderation counterstatement could not be loaded.");
  }
  if (templateResult?.error)
    throw new Error("The template review could not be loaded.");
  const template = templateResult
    ? parseTemplateReview(templateResult.data)
    : null;
  let templateBlueprints: ReturnType<typeof parseTemplateBlueprints> = [];
  let templatePageStale = false;
  let templateNextNeedId: string | null = null;
  let templateCoverUrl: string | null = null;
  if (template) {
    if (templatePage && !isTemplateVersion(templatePage.contentVersion))
      throw new Error("The template page version is invalid.");
    const page = await access.client.rpc(
      "list_moderation_case_template_blueprints",
      {
        p_expected_staff_profile_id: access.profileId,
        p_case_id: caseId,
        p_content_version:
          templatePage?.contentVersion ?? template.currentContentVersion,
        p_limit: 21,
        p_cursor_need_id: templatePage?.needCursor ?? null,
      },
    );
    if (
      page.error &&
      typeof page.error === "object" &&
      "code" in page.error &&
      page.error.code === "PT409"
    ) {
      templatePageStale = true;
    } else {
      if (page.error)
        throw new Error("The template resource page could not be loaded.");
      const rows = parseTemplateBlueprints(page.data);
      templateBlueprints = rows.slice(0, 20);
      templateNextNeedId =
        rows.length > 20 ? templateBlueprints.at(-1)!.sourceNeedId : null;
    }
    if (template.coverObjectPath && access.client.storage) {
      // Ordinary source Storage RLS authorizes this short-lived URL. A denied
      // source cover stays unavailable; no staff bucket/table bypass.
      const cover = await access.client.storage
        .from("cover-images")
        .createSignedUrl(template.coverObjectPath, 60);
      if (!cover.error) templateCoverUrl = cover.data?.signedUrl ?? null;
    }
  }
  return {
    status: "ready",
    staffRole: access.role,
    staffProfileId: access.profileId,
    consequences: parseConsequenceHistory(consequences.data),
    detail: {
      ...detail,
      template,
      templateBlueprints,
      templateNextNeedId,
      templatePageStale,
      templateCoverUrl,
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
