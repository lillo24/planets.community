// pg-meta cannot infer nullable RETURNS TABLE fields. Keep the bounded PI01
// contract accurate without changing unrelated generated functions or tables.
export const participationRpcNullableFields = Object.freeze({
  list_own_project_memberships: ["originating_request_id"],
  list_project_members: ["originating_request_id"],
  list_project_members_for_manager: ["originating_request_id"],
  page_project_history_for_manager: ["originating_request_id"],
  accept_project_participant_invitation: ["membership_id", "membership_status"],
  get_project_participant_invitation_preview: [
    "project_id",
    "project_kind",
    "project_title",
  ],
  get_project_join_request_resolution_context: [
    "resolution_reason",
    "superseded_by_membership_id",
  ],
  list_project_participant_invitation_history: [
    "revocation_reason",
    "revoked_at",
    "revoked_by_profile_id",
  ],
});

export function applyParticipationRpcNullability(output) {
  for (const [name, fields] of Object.entries(participationRpcNullableFields)) {
    const functionPattern = new RegExp(
      `^      ${name}: \\{[\\s\\S]*?^      \\}`,
      "m",
    );
    if (!functionPattern.test(output)) {
      throw new Error(
        `Generated database types are missing participation RPC ${name}.`,
      );
    }
    output = output.replace(functionPattern, (body) => {
      for (const field of fields) {
        const fieldPattern = new RegExp(
          `^(          ${field}: )string(?: \\| null)?$`,
          "m",
        );
        if (!fieldPattern.test(body)) {
          throw new Error(
            `Generated ${name} result is missing expected string field ${field}.`,
          );
        }
        body = body.replace(fieldPattern, "$1string | null");
      }
      return body;
    });
  }
  return output;
}
