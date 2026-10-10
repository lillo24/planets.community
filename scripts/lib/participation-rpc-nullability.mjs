// pg-meta cannot infer nullable RETURNS TABLE fields. Keep participation API
// MSG01 typed-feed and opt-in Idea contracts accurate without changing unrelated records.
const ideaLogistics = [
  "starts_at",
  "ends_at",
  "event_timezone",
  "country_code",
  "locality",
  "administrative_area",
  "public_location_label",
  "derived_status",
];
const ideaOwnFields = [
  ...ideaLogistics,
  "title",
  "summary",
  "description",
  "cover_object_path",
  "exact_meeting_text",
  "published_at",
  "cancelled_at",
];
export const participationRpcNullableFields = Object.freeze({
  // IDEA01A opts in explicitly. Never widen the legacy strict event projections.
  get_public_proposal_v2: [
    ...ideaLogistics,
    "description",
    "cover_object_path",
    "creator_display_name",
    "exact_meeting_text",
  ],
  get_own_proposal_v2: ideaOwnFields,
  list_own_proposals_v2: ideaOwnFields,
  list_public_proposals_v2: [...ideaLogistics, "cover_object_path"],
  list_own_pending_requested_proposals_v2: [
    ...ideaLogistics,
    "cover_object_path",
  ],
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
  get_own_participation_conversation: [
    "request_message",
    "resolved_at",
    "accepted_project_group_chat_id",
  ],
  get_own_participation_conversation_requests: [
    "request_message",
    "resolved_at",
    "accepted_project_group_chat_id",
    "message_id",
    "sender_profile_id",
    "sender_display_name",
    "body",
  ],
  list_own_participation_conversation_items: [
    "request_id",
    "message_id",
    "project_id",
    "project_kind",
    "project_title",
    "request_status",
    "request_message",
    "requester_profile_id",
    "requester_display_name",
    "sender_profile_id",
    "sender_display_name",
    "body",
    "resolved_at",
    "accepted_project_group_chat_id",
  ],
  list_own_scoped_conversation_items: [
    "accepted_project_group_chat_id",
    "agreement_lifecycle",
    "coordination_closed_at",
    "last_visible_message_at",
    "last_visible_message_body",
    "last_visible_message_id",
    "last_visible_sender_display_name",
    "last_visible_sender_profile_id",
    "project_id",
    "project_kind",
    "project_request_counterparty_display_name",
    "project_request_counterparty_profile_id",
    "project_request_id",
    "project_request_message",
    "project_request_project_id",
    "project_request_project_kind",
    "project_request_project_title",
    "project_request_resolved_at",
    "project_request_status",
    "resource_agreement_id",
    "resource_counterparty_display_name",
    "resource_counterparty_profile_id",
    "resource_listing_id",
    "resource_request_id",
  ],
});

export const participationRpcNullableNumberFields = Object.freeze({
  list_own_scoped_conversation_items: ["pending_count"],
});

export function applyParticipationRpcNullability(output) {
  for (const [registry, fieldType] of [
    [participationRpcNullableFields, "string"],
    [participationRpcNullableNumberFields, "number"],
  ]) {
    for (const [name, fields] of Object.entries(registry)) {
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
            `^(          ${field}: )${fieldType}(?: \\| null)?$`,
            "m",
          );
          if (!fieldPattern.test(body)) {
            throw new Error(
              `Generated ${name} result is missing expected ${fieldType} field ${field}.`,
            );
          }
          body = body.replace(fieldPattern, `$1${fieldType} | null`);
        }
        return body;
      });
    }
  }
  return output;
}
