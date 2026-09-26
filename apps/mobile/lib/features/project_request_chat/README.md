# Participation-request private chat

This feature owns the requester-to-organizer conversation attached to one
Project join-request episode.

- `domain/` defines strict summary, feed, cursor, and Realtime signal models.
- `data/` calls the 07C1A RPCs and subscribes to the private per-profile topic.
- `application/` owns identity-safe loading, paging, sending, and reconciliation.
- `presentation/` renders the conversation and its pinned request-state banner.

Structured request actions and contribution details remain owned by the
Messages and Participation features and are reused from this chat.
