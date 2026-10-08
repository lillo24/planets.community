# Participation pair conversations

This feature owns one durable personal conversation between the canonical
requester and immutable Project Creator across their Proposal/Project and Tavolo
requests. The directory and request-context URL retain their established names.
Resource conversations and Project group chats have separate owners.

- `domain/` defines the summary, canonical pending total/page, complete feed
  cursor, and distinct request/legacy-message/new-message identities. Each
  request determines its own incoming/outgoing role and current status.
- `data/` owns the MSG01 expected-identity RPCs, bounded feed and pending-list
  paging, batched loaded-request status refresh, and one private pair/profile
  subscription. New messages have no request provenance. Realtime may append a
  delivery UUID; the strict parser permits that identifier and rejects content.
- `application/` owns account-bound loads, paging, explicit sends, signal/resume
  reconciliation, and reconnect catch-up across bounded pages until reaching
  the previously loaded boundary. Resolutions update old request items in place
  without refetching all history. Read-only pairs remain subscribed.
- `presentation/` owns the counterparty header, filled outlined aligned request
  bubbles, one/many/zero pending banner, legacy author/context label, and one
  composer. Older loading preserves scroll position; background signals do not
  force-scroll a reader. Sends preserve draft text on failure and never auto-retry.

Only pair endpoints have personal history/preview/send/Realtime access. A
non-endpoint delegate opening an old request-chat URL reaches authorized Requests
details after a successful canonical management read. Unrelated callers receive
the same unavailable failure as a missing request. Original request notes and
offers remain visible to authorized managers; the audience notice distinguishes
them from personal follow-ups and earlier organizer discussions.

Accept uses the Participation contribution-triage sheet with exact request and
Project IDs. Reject and requester Withdraw reuse Messages details. Sending
requires at least one eligible pending request under canonical manager/block
rules; `pendingCount` counts all pending requests, not just eligible ones or the
timeline page. A changed send witness returns an explicit conflict, refreshes
canonical state, and can remain writable through another request.

Structured request actions and contribution details remain owned by the
Messages and Participation features and are reused from this chat.

09C1B denies suspended accounts private chat reads/sends. Confirmed suspension
or failed account-status checks clear private caches and close channels, while
the backend suppresses new recipient Broadcast hints despite cached socket
authorization (already queued hints cannot be recalled). Only pending outbound
requests are canonically withdrawn; accepted/terminal request history remains.
Counterparty photos use the shared account-bound visible-photo cache and current
authorization. A persistent conversation grants no permanent photo entitlement.
Delayed actions, loads, sends, pagination, and scroll callbacks verify identity.

The pinned Realtime client can include transport `meta.id`/`meta.replayed` and a
delivery UUID alongside the application payload's conversation ID. The parser
validates this bounded metadata and rejects other fields or personal content;
transport metadata never grants access or replaces durable refresh.

`/messages/chats/request/:requestId` resolves the pair and highlights that request
if loaded; an older referenced request has an exact details link without requiring
the entire transcript. IT/EN copy is generated from ARB sources. MSG02 history
uses `get_own_message_feed_page` for an own newest snapshot boundary; the shared
Messages viewport acknowledges only foreground, unobscured latest content.
Older/pending-only pages issue no boundary. Pair unread counts remain independent
of pending totals and read-only/send entitlement. See the Messages feature and
ADR 0008 for baseline, commit ordering and activity-alert separation.
