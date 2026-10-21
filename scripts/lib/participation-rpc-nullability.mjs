// pg-meta cannot infer nullable RETURNS TABLE fields. Keep participation API
// MSG01 typed-feed, opt-in Idea, group and CAT01 contracts accurate without changing unrelated records.
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
  // IMG01 optional thumbnails preserve full-only legacy photos.
  get_own_profile_photo_v2: ["thumbnail_object_path"],
  get_profile_photo_for_viewer_v2: ["thumbnail_object_path"],
  list_profile_photos_for_viewer_v2: ["thumbnail_object_path"],
  get_project_creator_profile_photo_for_viewer_v2: ["thumbnail_object_path"],
  get_resource_listing_owner_profile_photo_for_viewer_v2: [
    "thumbnail_object_path",
  ],
  set_own_profile_photo_v2: [
    "previous_object_path",
    "previous_thumbnail_object_path",
  ],
  // CAT01 leaves existing and old-client listings/definitions unclassified.
  get_public_resource_listing_v2: ["category_slug"],
  list_public_resource_listings_v2: ["category_slug"],
  get_own_resource_listing_v2: ["category_slug"],
  list_own_resource_listings_v2: ["category_slug"],
  get_own_resource_saved_search_v2: ["category_slug"],
  list_own_resource_saved_searches_v2: ["category_slug"],
  // GRP03A relationship recovery and contextual reads have explicit null states.
  get_own_group_membership_context: [
    "authority_role",
    "delegate_id",
    "current_membership_id",
    "membership_status",
    "pending_request_id",
    "pending_note",
    "latest_request_id",
    "latest_request_status",
    "latest_membership_id",
    "latest_membership_status",
  ],
  create_group_join_request: [
    "relationship_id",
    "current_status",
    "expires_at",
  ],
  withdraw_group_join_request: [
    "relationship_id",
    "current_status",
    "expires_at",
  ],
  accept_group_join_request: [
    "relationship_id",
    "current_status",
    "expires_at",
  ],
  reject_group_join_request: [
    "relationship_id",
    "current_status",
    "expires_at",
  ],
  leave_group: ["relationship_id", "current_status", "expires_at"],
  remove_group_member: ["relationship_id", "current_status", "expires_at"],
  create_group_authority_invitation: [
    "relationship_id",
    "current_status",
    "expires_at",
    "invite_token",
  ],
  create_group_role_offer: ["relationship_id", "current_status", "expires_at"],
  accept_group_role_offer: ["relationship_id", "current_status", "expires_at"],
  decline_group_role_offer: ["relationship_id", "current_status", "expires_at"],
  revoke_group_authority_invitation: [
    "relationship_id",
    "current_status",
    "expires_at",
  ],
  change_group_delegate_role: [
    "relationship_id",
    "current_status",
    "expires_at",
  ],
  revoke_group_delegate: ["relationship_id", "current_status", "expires_at"],
  step_down_group_authority: [
    "relationship_id",
    "current_status",
    "expires_at",
  ],
  accept_group_authority_invitation: [
    "relationship_id",
    "current_status",
    "expires_at",
  ],
  accept_group_participant_invitation: [
    "relationship_id",
    "current_status",
    "expires_at",
  ],
  recover_group_relationship_command: [
    "relationship_id",
    "current_status",
    "expires_at",
  ],
  create_group_participant_invitation: ["invite_token", "revoked_at"],
  regenerate_group_participant_invitation: ["invite_token", "revoked_at"],
  revoke_group_participant_invitation: ["invite_token", "revoked_at"],
  get_current_group_participant_invitation: ["invite_token", "revoked_at"],
  get_group_participant_invitation_preview: [
    "group_id",
    "group_name",
    "group_kind",
  ],
  get_group_authority_invitation_preview: [
    "group_id",
    "group_name",
    "group_kind",
    "offered_role",
    "expires_at",
  ],
  get_own_group_role: [
    "authority_role",
    "delegate_id",
    "current_membership_id",
    "membership_status",
  ],
  list_current_group_people: [
    "display_name",
    "authority_role",
    "delegate_id",
    "current_membership_id",
    "joined_at",
  ],
  list_own_group_join_requests: [
    "requester_display_name",
    "note",
    "resolved_at",
    "resolved_by_profile_id",
    "resolution_reason",
    "superseded_by_membership_id",
  ],
  list_group_join_requests: [
    "requester_display_name",
    "note",
    "resolved_at",
    "resolved_by_profile_id",
    "resolution_reason",
    "superseded_by_membership_id",
  ],
  list_own_group_memberships: [
    "display_name",
    "originating_request_id",
    "ended_at",
    "ended_by_profile_id",
  ],
  list_group_membership_history: [
    "display_name",
    "originating_request_id",
    "ended_at",
    "ended_by_profile_id",
  ],
  list_group_delegates: ["display_name", "revoked_at", "revoked_by_profile_id"],
  list_group_authority_invitations: [
    "target_profile_id",
    "target_membership_id",
    "resolved_at",
    "resolved_by_profile_id",
    "accepted_delegate_id",
  ],
  list_own_group_role_offers: [
    "target_profile_id",
    "target_membership_id",
    "resolved_at",
    "resolved_by_profile_id",
    "accepted_delegate_id",
  ],
  list_group_participant_invitation_history: [
    "revoked_at",
    "revoked_by_profile_id",
  ],
  get_group_structural_context: ["locality"],
  // GRP01 locality is optional in both public and owner projections.
  get_public_group: ["locality"],
  list_public_groups: ["locality"],
  get_own_group: ["locality"],
  list_own_groups: ["locality"],
  // OST01 organization provenance. Legacy public reads remain strict.
  list_public_proposal_templates_v2: [
    "source_proposal_id",
    "original_creator_profile_id",
    "creator_display_name",
    "cover_object_path",
    "cover_asset_key",
  ],
  get_public_proposal_template_v2: [
    "source_proposal_id",
    "original_creator_profile_id",
    "creator_display_name",
    "cover_object_path",
    "cover_asset_key",
  ],
  create_proposal_draft_from_template: ["source_proposal_id"],
  get_own_proposal_template_application: ["source_proposal_id"],
  get_moderation_case_template: [
    "source_proposal_id",
    "original_creator_profile_id",
  ],
  list_moderation_cases: ["subject_profile_id"],
  get_moderation_case_detail: ["subject_profile_id"],
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
  get_public_proposal_template_v2: ["registration_capacity_recommendation"],
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
