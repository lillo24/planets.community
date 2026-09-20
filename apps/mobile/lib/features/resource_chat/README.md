# Resource chat

This feature owns the authenticated mobile conversation for one accepted
Scambio-Dona request episode. It renders permanent counterpart history and
human messages only. Structured agreement history remains canonical backend
state and is intentionally deferred to 04C4C3C.

## Source map

- `domain/resource_chat_models.dart` owns exact summary, human-message, cursor,
  lifecycle, role, and identifier-only Realtime signal types.
- `data/resource_chat_gateway.dart` owns the exact summary/history/send RPCs and
  the private per-profile Resource-chat Broadcast subscription. Payloads are
  strictly parsed; malformed hints become connection issues and never create a
  message locally.
- `application/resource_chat_controller.dart` owns identity/chat-bound state,
  oldest-first history, older-page merging, one-attempt send, PT409 recovery,
  canonical Realtime reconciliation, reconnect catch-up, and account cleanup.
- `presentation/resource_chat_screen.dart` owns counterpart context, accessible
  human bubbles, the open composer, and neutral read-only history presentation.

The composer exists only while the exact summary grants send entitlement.
Completion or cancellation keeps history readable and closes the live writable
subscription. No agreement timeline, terms action, milestone, contact detail,
notification behavior, generic DM, or Group chat is implemented here.
