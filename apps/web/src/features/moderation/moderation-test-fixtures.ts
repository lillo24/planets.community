export function moderationQueueRow() {
  return {
    case_id: "00000000-0000-4000-8000-000000000901",
    state: "received",
    state_version: 0,
    created_at: "2026-09-28T10:00:00Z",
    category: "harassment_abuse",
    target_kind: "project_chat_message",
    target_summary: "Project chat message",
    context_summary: "Community garden",
    subject_profile_id: "00000000-0000-4000-8000-000000000902",
    subject_display_name: "Taylor",
  };
}

export function moderationDetailRow() {
  return {
    ...moderationQueueRow(),
    completed_at: null,
    explanation: "A sufficiently detailed original report.",
    reporter_profile_id: "00000000-0000-4000-8000-000000000903",
    reporter_display_name: "Casey",
    project_context_id: "00000000-0000-4000-8000-000000000904",
    resource_listing_context_id: null,
    resource_request_context_id: null,
    resource_chat_context_id: null,
    notes: [
      {
        note_id: "00000000-0000-4000-8000-000000000905",
        author_profile_id: "00000000-0000-4000-8000-000000000906",
        author_display_name: "Morgan",
        body: "Private note",
        created_at: "2026-09-28T10:01:00Z",
      },
    ],
    events: [
      {
        event_id: "00000000-0000-4000-8000-000000000907",
        actor_profile_id: "00000000-0000-4000-8000-000000000903",
        actor_display_name: "Casey",
        event_kind: "report_received",
        from_state: null,
        to_state: "received",
        state_version: 0,
        note_id: null,
        created_at: "2026-09-28T10:00:00Z",
      },
      {
        event_id: "00000000-0000-4000-8000-000000000908",
        actor_profile_id: "00000000-0000-4000-8000-000000000906",
        actor_display_name: "Morgan",
        event_kind: "note_added",
        from_state: null,
        to_state: null,
        state_version: 0,
        note_id: "00000000-0000-4000-8000-000000000905",
        created_at: "2026-09-28T10:01:00Z",
      },
    ],
  };
}
