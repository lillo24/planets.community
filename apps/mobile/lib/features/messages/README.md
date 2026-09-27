# Messages

This feature owns the authenticated mobile Messages information architecture.
It keeps canonical structured Project and Resource requests in `Requests` and a
mixed chronological conversation projection in `Chats`. The Chats tab exposes
independently paged `Private` and `Groups` scopes: Private contains Resource and
Project participation-request conversations, while Groups contains Project
group chats. Project and Resource detail transport remain in the adjacent
`project_chat/`, `project_request_chat/`, and `resource_chat/` features; this
feature owns their shared entry point.

The 07C1A backend also gives every Project participation-request episode a
private requester/organizer conversation with a structured Request item, immutable
human follow-ups, pending-only send entitlement, and permanent resolved history.
07C1B surfaces that conversation as an explicit typed variant in the Private
scope and routes it to the adjacent feature. Request-chat push/notification
projection remains deliberately deferred.

## Source map

- `domain/message_models.dart` defines the centrally discriminated Project and
  Resource request variants, strict viewer roles, typed contribution labels,
  and the complete activity/kind/request cursor.
- `domain/message_chat_models.dart` defines the sealed Project, Project-request,
  and Resource chat variants, complete activity/kind/chat cursor, and composite
  identity.
- `data/messages_gateway.dart` is the only Supabase boundary. The inbox and
  exact-item reads use the unified 04C4C2 RPCs; Project-only selection and
  mutation operations keep their existing 04C3B1/05A boundaries. Each narrow
  response is parsed strictly and cross-domain field mixtures fail closed.
- `data/message_chats_gateway.dart` reads only the canonical scoped unified
  Chats RPC. It strictly validates branch XOR fields, request lifecycle fields,
  and human-preview completeness.
- `application/message_chats_controller.dart` owns one identity-bound scope's
  paging, composite deduplication, loaded-writable-chat subscriptions, debounced
  canonical refresh, aggregated connection state, and reconnect catch-up. The
  provider layer creates separate Private and Groups controller instances so
  each scope owns its complete server cursor.
- `application/messages_controllers.dart` owns keyset paging, detail/action
  state, identity revisions, Reject/Withdraw guards, conflict reloads, and
  canonical post-triage synchronization with participation and the inbox.
- `presentation/messages_routes.dart` owns stable request, chat, and group-info
  routes used by navigation and future notification routing.
- `presentation/messages_screen.dart` owns the two-tab shell, Private/Groups
  toggle, independent loading/refresh/pagination, centrally discriminated chat
  cards, and role-aware Project/Resource request cards. Chats and Private are
  deterministic defaults; no unread or agreement activity copy is fabricated.
- `presentation/participation_request_details.dart` owns the reusable authorized
  Project request details sheet/content, canonical actions, resolved history,
  and Proposal/Tavolo navigation. The old full-screen request route is a thin
  wrapper around the same component. Rounded contribution labels remain
  detail-only so the inbox never performs per-row selection fan-out.
- `presentation/messages_formatters.dart` owns the shared safe relative-time and
  status formatting used by Messages and request-chat presentation.
- The adjacent `project_request_chat/` feature owns request-chat transport,
  identity-bound state, private identifier-only Realtime signals, structured
  request history, pinned lifecycle actions, and the pending-only composer.
- The adjacent `resource_requests/` feature owns Resource request detail and
  actions. Messages routes Resource cards there without copying domain state.

## Privacy and state

The backend returns an item only when the authenticated profile is its requester,
a current Project manager, or the Resource owner. Private request messages and
narrow display identities never come from public discovery reads. Missing and
unauthorized exact IDs fail identically. The client displays safe localized
errors and never renders backend diagnostics.

The request item and contribution-selection read are independent. Selection
loading/failure never removes Accept/Reject/Withdraw, and its local retry
resolves current canonical labels for the historical selected IDs. Empty
selection history is valid. Unknown selection kinds fail safely rather than
being rendered as an invented contribution type. These chips remain immutable
request history and are not reused as mutable acceptance state.

Manager Accept opens the participation-owned 04C3D2 triage sheet, which performs
its own action-local canonical selection read even when the Messages display
read previously succeeded or failed. The shared sheet requires every offered
item to be classified and is the only mobile owner of the D1 eight-argument
acceptance call. On return, request detail, inbox, and an already-loaded matching
manager participation view reload canonical state. Reject and requester
Withdraw remain owned here and unchanged.

Inbox and detail data live only in identity-bound Riverpod memory. Every load or
mutation captures the rendered identity and a request revision; sign-out or an
account switch clears state and rejects late responses. Pending actions are
role-specific: owners/delegates may Accept/Reject and requesters may Withdraw. A
successful action reloads the canonical item and inbox, then refreshes the
corresponding 05B participation view. Conflicts also reload current canonical
state. Resolved requests remain read-only request history and do not themselves
imply chat access. Chat availability and current/former behavior always come
from the 07B2B canonical projections. Successful Accept/leave/remove flows
issue only a narrow refresh hint so chat controllers re-read those projections.

Inbox pagination and deduplication use `(activity_at, item_kind, request_id)`,
so equal UUIDs in different domains cannot collide. New future structured kinds
(including possible Group or Project invitations) must be added as explicit
typed variants at this central parser/model boundary; no invitation flow is
implemented here.

## Navigation

Messages belongs to the existing Home branch, reached from Home's AppBar:

```text
/messages
/messages/requests/:requestId
/messages/requests/resource/:requestId
/messages/chats/request/:requestId
/messages/chats/:chatId
/messages/chats/:chatId/info
/messages/chats/resource/:chatId
```

Both routes require authentication and a complete profile. Their exact safe
internal destination survives email OTP and profile completion. The persistent
bottom navigation remains Profile / Browse / Home; there is no fourth tab. Plan
06B adds a separate Home notification bell/unread badge and resolves request
alerts into this feature's stable request route. 07B2C owns chat and group-info
presentation without adding a fourth bottom destination.
