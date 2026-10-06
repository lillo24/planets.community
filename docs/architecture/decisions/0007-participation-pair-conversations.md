# 0007 — Durable participation pair conversations

- **Status:** Accepted
- **Date:** 2026-10-06

## Context

MSG01 approves one conversation between the canonical requester and immutable
Project Creator across Proposal/Project and Tavolo requests, including reversed
roles and repeat episodes. Previously, each request had a separate visible chat
and ordinary Project delegates could read and reply to it.

## Decision

Use one immutable database anchor per ordered pair of profile UUIDs. Canonical
request creation establishes the anchor and an immutable request/legacy-chat
association in the same transaction. Profiles, previews, and direct participant
or authority invitations do not independently establish a pair.

The mixed feed projects each canonical request once at its original timestamp,
retained legacy messages from their source tables, and new pair messages from a
separate immutable table without a request foreign key. Legacy messages retain
actual authors and request provenance and receive an explicit earlier-discussion
label. No messages are copied, reassigned, or deleted by the migration.

Only the two endpoints can access personal history, previews, sending, and
Realtime, including retained request-chat RPCs. Ordinary Co-creators and
Co-organizers keep existing scoped request notes, offers, and manager actions
through Requests/Participation. Existing explicit staff/evidence authority is
unchanged; being a manager creates no new staff permission.

Sending requires at least one eligible pending canonical request, including its
requester-versus-every-current-manager block rules. The send locks one request
witness in the existing interaction-pair → concrete/shared Project → request
order and rechecks it. A witness changed by a race produces an explicit `PT409`
and canonical refresh; the client preserves the draft and never silently retries.
Another pending request keeps the pair writable on the refreshed summary. Pair
rows are never locked before Project rows and there is no multi-Project send
lock chain.

## Consequences

Pair grouping occurs before server pagination. Pending totals include all
canonical pending requests, while the banner's initial request page is bounded
and independently pageable. Role and action authorization remain per request.
Closed conversations retain history and their subscriptions so a new legitimate
request can reactivate them. Hints address endpoints only, protecting already
connected legacy delegate sockets without relying on reconnect authorization.

The existing URL resolves a request context into its pair; non-endpoint managers
reach authorized request details. Old RPCs remain request-scoped endpoint
adapters and cannot return new pair messages or unrelated request history.
Original IDs and audit/report references remain valid.

Resource conversations and Project group chats retain their existing owners and
pagination. There is no generic direct messenger, offline queue, retention-policy
change, unread state, or notification-inbox change. MSG02 remains separate.
