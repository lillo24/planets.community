import "server-only";

import { createSupabaseServerClient } from "@/lib/supabase/server";
import { publicExactMapsUrl } from "@/features/locations/public-exact-maps-url";
import {
  parsePublicProposalDetail,
  parsePublicProposalSummary,
  type ProposalFilters,
  type PublicProposalDetail,
  type PublicProposalSummary,
  type SkillOption,
} from "./proposal-models";

export const publicProposalPageSize = 12;

export async function listPublicProposals(
  filters: ProposalFilters,
): Promise<PublicProposalSummary[]> {
  const client = await createSupabaseServerClient();
  const { data, error } = await client.rpc("list_public_proposals", {
    p_limit: publicProposalPageSize,
    p_cursor_starts_at: filters.cursor?.startsAt,
    p_cursor_id: filters.cursor?.id,
    p_locality: filters.locality?.trim() || undefined,
    p_skill_ids: filters.skillId ? [filters.skillId] : undefined,
  });
  if (error) throw error;
  return (data ?? []).map(parsePublicProposalSummary);
}

export async function getPublicProposal(
  proposalId: string,
): Promise<PublicProposalDetail | null> {
  const client = await createSupabaseServerClient();
  const { data, error } = await client.rpc("get_public_proposal", {
    p_proposal_id: proposalId,
  });
  if (error) throw error;
  const rows = data ?? [];
  if (rows.length === 0) return null;
  const detail = parsePublicProposalDetail(rows[0]);
  if (detail.exact_location_restricted || !detail.exact_meeting_text)
    return detail;
  const preview = await client.rpc("get_location_preview_v1", {
    p_kind: "one_time",
    p_item: proposalId,
    p_view: "public_detail",
  });
  if (preview.error) throw preview.error;
  const exactMapsUrl = publicExactMapsUrl(
    preview.data,
    proposalId,
    detail.exact_meeting_text,
  );
  // A newer privacy/selection revision must also revoke the older text label.
  return exactMapsUrl
    ? { ...detail, exactMapsUrl }
    : {
        ...detail,
        exactMapsUrl: null,
        exact_meeting_text: null,
        exact_location_restricted: true,
      };
}

export async function listSkillOptions(): Promise<SkillOption[]> {
  const client = await createSupabaseServerClient();
  const { data, error } = await client
    .from("skills")
    .select("id, label")
    .order("sort_order");
  if (error) throw error;
  return (data ?? []).map((row) => ({ id: row.id, label: row.label }));
}
