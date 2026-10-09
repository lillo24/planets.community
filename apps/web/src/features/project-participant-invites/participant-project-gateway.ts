import "client-only";
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@/types/database.generated";
import { createSupabaseBrowserClient } from "@/lib/supabase/browser";
import { parsePublicProposalDetail } from "../proposals/proposal-models";
import { parsePublicRecurringActivityDetail } from "../recurring-activities/recurring-activity-models";
import { ParticipantError, type ProjectContext } from "./participant-models";

export type InvitationProject = Readonly<{
  title: string;
  description: string;
  coverObjectPath: string | null;
}>;
export interface InvitationProjectGateway {
  read(project: ProjectContext): Promise<InvitationProject | null>;
  cover(project: ProjectContext, objectPath: string): Promise<Blob>;
}

export class SupabaseInvitationProjectGateway implements InvitationProjectGateway {
  constructor(private readonly client: SupabaseClient<Database>) {}
  async read(project: ProjectContext): Promise<InvitationProject | null> {
    const result =
      project.kind === "one_time"
        ? await this.client.rpc("get_public_proposal", {
            p_proposal_id: project.id,
          })
        : await this.client.rpc("get_public_recurring_activity", {
            p_recurring_activity_id: project.id,
            p_occurrence_limit: 1,
            p_reference_time: new Date().toISOString(),
          });
    if (result.error) throw result.error;
    if (!Array.isArray(result.data) || result.data.length > 1)
      throw new ParticipantError("malformed");
    if (!result.data.length) return null;
    const detail =
      project.kind === "one_time"
        ? parsePublicProposalDetail(result.data[0])
        : parsePublicRecurringActivityDetail(result.data[0]);
    const id =
      "proposal_id" in detail
        ? detail.proposal_id
        : detail.recurring_activity_id;
    if (id !== project.id) throw new ParticipantError("malformed");
    // Keep only public presentation, never meeting details, identities or offers.
    return {
      title: detail.title,
      description: detail.description,
      coverObjectPath: detail.cover_object_path,
    };
  }
  async cover(project: ProjectContext, objectPath: string): Promise<Blob> {
    const uuid =
      "[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}";
    const parts = objectPath.split("/");
    if (
      !new RegExp(`^${uuid}/projects/${uuid}/${uuid}\\.webp$`, "iu").test(
        objectPath,
      ) ||
      parts[2]?.toLowerCase() !== project.id.toLowerCase()
    )
      throw new ParticipantError("malformed");
    // This private bucket's public-cover policy permits canonical authenticated
    // download, not public URLs/signing. The SDK carries the current credentials.
    const { data, error } = await this.client.storage
      .from("cover-images")
      .download(objectPath);
    if (error) throw error;
    if (
      !data ||
      data.type !== "image/webp" ||
      !data.size ||
      data.size > 512 * 1024
    )
      throw new ParticipantError("malformed");
    return data;
  }
}
export function createInvitationProjectGateway() {
  return new SupabaseInvitationProjectGateway(createSupabaseBrowserClient());
}
