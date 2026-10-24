# Resource chat

A1 routes personal messages into the unified pair timeline. The exact
`/messages/chats/resource/:chatId/manage` route reuses this feature's agreement
negotiation/progression and request-detail link with `managementOnly: true`.
It exposes no second transcript/composer and has no read boundary. Original
source screens/contracts remain available for compatibility and owner tests.

UIPOLISH03 gives summary and composer independently scrollable maximum shares
of available height, preserving the separate message scroll/read controller.
Scaffold owns IME resizing; composer padding must not add keyboard height again.
Canonical exchange/chat warnings precede the summary; a new warning resets only
that summary scroll. Name and role are separate, with full-name accessibility.
See `docs/development/uipolish03-details-groups-chat.md` for native/layout QA.

MSG02 history uses `get_own_message_feed_page` to obtain an own newest snapshot
boundary. The shared Messages viewport acknowledges only successfully rendered,
foreground, unobscured latest content. Older pages and previews never read chat;
closed coordination remains unread until acknowledged. Request-scoped identity,
counterparty authorization and exchange/system activity remain unchanged. See
the Messages feature and ADR 0008 for eligibility, baseline and activity alerts.

This feature owns the authenticated mobile conversation for one accepted
Scambio-Dona request episode. It renders permanent counterpart history and
human messages. The conversation screen embeds the independently loaded
04C4C3C1 agreement negotiation surface without making chat availability depend
on agreement availability.

## Source map

- `domain/resource_chat_models.dart` owns exact summary, human-message, cursor,
  lifecycle, role, and identifier-only Realtime signal types.
- `data/resource_chat_gateway.dart` owns the exact summary/history/send RPCs and
  the private per-profile Resource-chat Broadcast subscription. Payloads are
  strictly parsed; malformed hints become connection issues and never create a
  message locally.
- `application/resource_chat_controller.dart` owns identity/chat-bound state,
  oldest-first history, older-page merging, one-attempt send, PT409 recovery,
  canonical Realtime reconciliation, reconnect catch-up, counterpart-photo
  loading while coordination is open, and relationship/account cleanup.
- `application/resource_chat_refresh.dart` is the local revision signal used to
  reload chat state after agreement mutations.
- `presentation/resource_chat_screen.dart` owns counterpart context, accessible
  human bubbles, the authorized counterpart avatar, the open composer, neutral
  read-only history presentation, and composition of the separately owned
  agreement card.

The composer exists only while the exact summary grants send entitlement.
Completion or cancellation keeps history readable and closes the live writable
subscription. No agreement timeline, terms action, milestone, contact detail,
notification behavior, generic DM, or Group chat is owned here. The existing
Resource-chat subscription forwards identifier-only agreement-change signals
to the agreement refresh provider; it remains the only Realtime subscription
for the conversation.

Accepted/open coordination grants symmetric generic counterpart-photo access,
independent of whether the listing later closes. The controller loads by the
summary's canonical counterpart profile ID and invalidates that target when a
Realtime/read reconciliation reports coordination closure or the signed-in
account changes. Closed history remains readable without retaining a stale
relationship-authorized avatar.

09B2 adds confirmed Block/Unblock beside the canonical counterparty. The action
invalidates that person's cached photo but never makes accepted/open chat
read-only; ordinary agreement lifecycle still owns send availability.

## Automatic history paging (AUTO02)

History retains 30 recent items on opening and 30 older items per genuine upward
drag near the top (within one viewport). The shared Messages history list uses
lazy slivers with a stable center, preserving visible variable-height messages
when older records arrive. Open/send positioning, keyboard/layout and realtime
updates cannot drain history. Failure retains entries/cursor and pauses paging
until explicit Retry or refresh; short/accessibility navigation offers a
fallback. Older loading withholds the newest read boundary. Read-only history,
interaction restrictions, exchange state and canonical unread rules are unchanged.
