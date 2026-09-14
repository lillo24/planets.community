# Project chat

This feature owns the authenticated mobile group-chat experience over the
canonical Project chat backend. It does not own participation membership,
meeting data, unread state, notification projection, or project content.

## Source map

- `domain/project_chat_models.dart` defines strict summary, message, cursor,
  page, Realtime-signal, and viewer-role models.
- `data/project_chat_gateway.dart` is the only Supabase boundary. It calls the
  three 07B2B RPCs and opens private per-chat/per-profile Broadcast channels.
- `application/project_chat_controllers.dart` owns identity-bound chat-list and
  detail state, keyset pagination, ordering, deduplication, send flow, durable
  reconciliation, and entitlement-scoped subscriptions.
- `application/project_chat_refresh.dart` is the narrow cross-feature signal
  used after participation acceptance, leave, or removal.
- `presentation/project_chat_screen.dart` renders history, current-member
  composer, former-member read-only state, and the group-info entry point.
- `presentation/project_chat_info_screen.dart` renders canonical summary
  context, Project/Tavolo and creator Participation navigation, and lazy access
  to the existing protected meeting operation.
- `presentation/project_chat_failure_message.dart` maps failures to safe,
  localized copy without backend diagnostics.

## Canonical data and Realtime

The client reads only `list_own_project_group_chats` and
`list_own_project_chat_messages`, and sends only through
`send_project_chat_message`. It does not read chat tables directly. Backend
history pages arrive newest-first and are transformed to oldest-first UI order;
older pages use the exact `(created_at, message_id)` cursor. Chat-list pages use
the exact `(activity_at, chat_id)` cursor.

Realtime is a private authenticated Broadcast hint on
`project-chat:<chatId>:profile:<profileId>`. The identifier-only payload is not
rendered or trusted as message content. A valid hint, reconnect, app resume, or
explicit refresh reloads durable RPC state and deduplicates by canonical
message ID. Subscriptions exist only while the Messages/chat screen is active
and the backend reports current entitlement. Former members keep only the
server-authorized history frontier, with no composer, live channel, protected
meeting request, or indication of newer activity.

All cached summaries, messages, composer state, meeting details, async
revisions, and subscriptions are scoped to the rendered profile identity.
Account changes clear state and reject late responses. Accept, leave, and
remove transitions trigger a canonical refresh rather than predicting chat
membership in the client.

## Navigation

The feature remains inside the existing Home branch:

```text
/messages
/messages/chats/:chatId
/messages/chats/:chatId/info
```

The info route uses `ParticipationRoutes.detail(...)` and, for creators only,
`ParticipationRoutes.participants(...)`. Protected meeting text remains owned
by Participation and is loaded only after a current-entitled user explicitly
requests it from group info. The unstructured location value is intentionally
not re-rendered because no established safe mobile formatter exists for it.

## Plan 12 native QA checklist

Comprehensive native interaction QA is deferred to the consolidated Plan 12
pass. On Android and iOS, verify:

1. keyboard resize, multiline input, send, dismissal, and focus restoration;
2. initial bottom scroll and viewport preservation when older history loads;
3. bubble alignment, long text wrapping, text scaling, screen-reader order, and
   message/composer semantics;
4. Chats/Requests tab switching, back behavior, deep links, and branch
   restoration;
5. offline/reconnect/resume catch-up without duplicates;
6. leave, removal, rejoin, creator, and account-switch transitions;
7. protected meeting data never remains visible after entitlement or identity
   changes.

Automated Flutter tests and Android compilation validate the functional
contract but are not recorded as native-device QA.
