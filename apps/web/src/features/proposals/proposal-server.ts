import "server-only";

import { createSupabaseServerClient } from "@/lib/supabase/server";
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
  const { data, error } = await client.rpc("list_public_proposals_v2", {
    p_limit: publicProposalPageSize,
    p_cursor_published_at: filters.cursor?.publishedAt,
    p_reference_time: filters.cursor?.referenceTime,
    p_definition_phase: filters.definitionPhase,
    p_query: filters.query,
    p_cursor_id: filters.cursor?.id,
    p_locality: filters.locality?.trim() || undefined,
    p_skill_ids: filters.skillId ? [filters.skillId] : undefined,
  });
  if (error) throw error;
  return (data ?? []).map((row) => {
    const proposal = parsePublicProposalSummary(row);
    if (!proposal.published_at || !proposal.reference_time)
      throw new TypeError("Missing publication pagination anchor");
    return proposal;
  });
}

export async function getPublicProposal(
  proposalId: string,
): Promise<PublicProposalDetail | null> {
  const client = await createSupabaseServerClient();
  const { data, error } = await client.rpc("get_public_proposal_v2", {
    p_proposal_id: proposalId,
  });
  if (error) throw error;
  const rows = data ?? [];
  return rows.length === 0 ? null : parsePublicProposalDetail(rows[0]);
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
