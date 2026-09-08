# Public recurring activities (Tavoli)

This feature owns the website's signed-out, read-only Tavoli discovery. It is
separate from one-time Proposals and contains no owner management or authoring.

- `recurring-activity-models.ts` strictly validates sanitized public summary,
  detail, schedule, occurrence, and snapshot-cursor payloads. A restricted
  exact location is represented without a text field.
- `recurring-activity-server.ts` is the server-only boundary for the canonical
  public list and exact-ID detail RPCs. It never reads recurring tables or
  owner operations directly.
- `recurring-activity-components.tsx` renders cards, lifecycle badges,
  recurrence wording, and occurrence times in the named event time zone.

The first list request captures one UTC reference time. Every opaque cursor
binds that snapshot to its normalized locality and carries the backend's
`(next_starts_at, recurring_activity_id)` position. A missing, malformed, or
filter-mismatched cursor starts a new snapshot rather than reaching the RPC.

Public cards receive only compact rough-location rows and never make N+1 detail
requests for recurrence wording. Exact public meeting text is detail-only;
participant-restricted detail retains no protected text in its parsed model.
