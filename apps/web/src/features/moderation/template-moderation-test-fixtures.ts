export const templateId = "00000000-0000-4000-8000-000000000931";
export const templateSourceId = "00000000-0000-4000-8000-000000000932";
export const templateStaffId = "00000000-0000-4000-8000-000000000903";
export const templateCaseId = "00000000-0000-4000-8000-000000000900";
export const templateVersion = "tw01:" + "a".repeat(64);
export function templateReviewRow() {
  return {
    template_id: templateId,
    source_proposal_id: templateSourceId,
    original_creator_profile_id: "00000000-0000-4000-8000-000000000902",
    report_content_version: templateVersion,
    current_content_version: templateVersion,
    content_changed: false,
    publicly_available: true,
    removed_at: null,
    content: {
      title: "Community garden template",
      summary: "Published idea",
      description: "<script>untrusted</script>",
      skills: [
        {
          id: "00000000-0000-4000-8000-000000000935",
          label: "Gardening",
          category_label: "Outdoor",
          importance: "required",
        },
      ],
      registration_capacity_recommendation: 8,
      duration_seconds: 7200,
      cover_object_path: null,
    },
    resource_blueprint_count: 0,
    removal_action: null,
  };
}
export function templateReceiptRow(
  outcome: "removed" | "already_removed" = "removed",
) {
  return {
    request_id: "00000000-0000-4000-8000-000000000933",
    outcome,
    effective_action_id: "00000000-0000-4000-8000-000000000934",
    effective_at: "2026-10-03T14:00:00Z",
    effective_actor_profile_id: templateStaffId,
  };
}
