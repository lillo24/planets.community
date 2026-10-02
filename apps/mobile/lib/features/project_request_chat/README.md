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
- `presentation/` renders the conversation, counterparty avatar/name header,
  and its pinned request-state banner.

The controller loads the role-specific counterparty through the shared visible
profile-photo cache, revalidates authorization on refresh, and invalidates the
target when the request resolves or the opposite party changes. Signal teardown
is idempotent and ignores synchronous/late close callbacks after the route is
detached.

Structured request actions and contribution details remain owned by the
Messages and Participation features and are reused from this chat.

09C1B denies suspended accounts private chat reads/sends. Confirmed suspension
or failed account-status checks clear private caches and close channels, while
the backend suppresses new recipient Broadcast hints despite cached socket
authorization (already queued hints cannot be recalled). Only pending outbound
requests are canonically withdrawn; accepted/terminal request history remains.
