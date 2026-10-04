import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@/types/database.generated";
import {
  mapParticipantFailure,
  ParticipantError,
  participantTokenPattern,
  parseAdmissionReceipt,
  parseCurrentParticipation,
  parseParticipantPreview,
  projectId,
  type AdmissionReceipt,
  type CurrentParticipation,
  type ParticipantAuth,
  type ParticipantPreview,
  type ProjectContext,
} from "./participant-models";

export async function readParticipantAuth(
  client: SupabaseClient<Database>,
): Promise<ParticipantAuth> {
  const { data, error } = await client.auth.getClaims();
  if (error) {
    if (error.name === "AuthSessionMissingError")
      return { account: null, phase: "signedOut" };
    throw new ParticipantError("network");
  }
  if (!data) return { account: null, phase: "signedOut" };
  const account = projectId(data.claims.sub);
  const { data: profile, error: profileError } = await client
    .from("profiles")
    .select("id, display_name")
    .eq("id", account)
    .maybeSingle();
  if (profileError)
    throw new ParticipantError(mapParticipantFailure(profileError));
  if (!profile) return { account, phase: "missingProfile" };
  if (
    profile.id !== account ||
    (profile.display_name !== null && typeof profile.display_name !== "string")
  )
    throw new ParticipantError("malformed");
  return {
    account,
    phase: profile.display_name?.trim() ? "ready" : "incompleteProfile",
  };
}
export async function previewParticipant(
  client: SupabaseClient<Database>,
  token: string,
): Promise<ParticipantPreview> {
  if (!participantTokenPattern.test(token)) return { available: false };
  const { data, error } = await client.rpc(
    "get_project_participant_invitation_preview",
    { p_token: token },
  );
  if (error) throw new ParticipantError(mapParticipantFailure(error));
  return parseParticipantPreview(data);
}
export async function acceptParticipant(
  client: SupabaseClient<Database>,
  account: string,
  token: string,
  action: string,
): Promise<AdmissionReceipt> {
  const { data, error } = await client.rpc(
    "accept_project_participant_invitation",
    {
      p_expected_profile_id: account,
      p_token: token,
      p_client_action_id: action,
    },
  );
  if (error) throw new ParticipantError(mapParticipantFailure(error));
  return parseAdmissionReceipt(data);
}
export async function readCurrentParticipation(
  client: SupabaseClient<Database>,
  account: string,
  project: ProjectContext,
): Promise<CurrentParticipation> {
  const [memberships, role] = await Promise.all([
    client.rpc("list_own_project_memberships", {
      p_expected_participant_profile_id: account,
    }),
    client.rpc("get_own_project_management_role", {
      p_expected_profile_id: account,
      p_project_id: project.id,
    }),
  ]);
  if (memberships.error || role.error)
    throw new ParticipantError(
      mapParticipantFailure(memberships.error ?? role.error),
    );
  return parseCurrentParticipation(memberships.data, role.data, project);
}
