# Participation-request private chat

This feature owns the requester-to-organizer conversation attached to one
Project join-request episode.

The organizer side is an explicit `creator` or `delegate` viewer role. Both use
the manager-named participation mutations while the request is pending; a
revoked delegate is rejected by the next canonical read, send, or Realtime
authorization check. The final delegate invitation and link UX remains 07C2B.

- `domain/` defines strict summary, feed, cursor, and Realtime signal models.
- `data/` calls the 07C1A RPCs and subscribes to the private per-profile topic.
- `application/` owns identity-safe loading, paging, sending, and reconciliation.
- `presentation/` renders the conversation and its pinned request-state banner.

Structured request actions and contribution details remain owned by the
Messages and Participation features and are reused from this chat.
