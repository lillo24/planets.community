# Messages

This feature owns the authenticated mobile Messages information architecture.
It keeps canonical structured Project and Resource requests in `Requests` and a
mixed chronological conversation projection in `Chats`. The Chats tab exposes
independently paged `Private` and `Groups` scopes: Private contains Resource and
Project participation-request conversations, while Groups contains Project
group chats. Project and Resource detail transport remain in the adjacent
`project_chat/`, `project_request_chat/`, and `resource_chat/` features; this
feature owns their shared entry point.

MSG01 gives the requester/immutable Creator pair one durable participation
conversation across Projects and Tavoli, including repeat episodes and reversed
roles. Server grouping occurs before paging. The existing typed
`ProjectRequestMessageChatItem` and wire discriminator `project_request_chat`
now identify a pair row; its representative request ID is navigation context.
The canonical pending total and entitlement are independent of that request's
status. Requests remains the separate request-management view. MSG02 adds
durable human-message unread state; activity alerts remain in Notifications.

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
- `data/message_chats_gateway.dart` reads `list_own_scoped_conversation_items_v4`,
  the canonical scoped unified Chats RPC with pair pending totals. It strictly
  validates branch XOR fields, request-context lifecycle fields,
  human-preview completeness, and the Resource-only canonical opposite-party
  identity returned by that projection.
  Two nullable preview fields distinguish the latest pair request status and
  latest visible group system-event label from an older human preview. Pair
  route context remains independent; human activity wins exact timestamp ties.
  The released v3 shape and function remain unchanged.
- `domain/message_unread_models.dart` validates complete account/scope counts
  and server-issued newest-feed snapshot tokens.
- `data/message_unread_gateway.dart` owns expected-identity summary/read RPCs
  and one private account invalidation subscription. The shared
  `core/backend/private_broadcast_payload.dart` separates legitimate Realtime
  transport metadata from the strict identifier-only application payload.
- `application/message_unread_controller.dart` owns canonical count refresh,
  coalescing, foreground/reconnect recovery, stale/error state, and identity
  revisions. It never adjusts totals arithmetically.
- `presentation/message_unread_badge.dart` renders zero-hidden counts, visual
  caps and exact localized accessibility labels. Home and the Messages-labelled
  navigation slot share the complete conversation total; Groups uses its scope
  total, and rows use incoming human-message counts.
- `presentation/message_read_viewport.dart` acknowledges only a successfully
  rendered newest boundary at the latest scroll position in a foreground,
  unobscured conversation. All three detail features reuse it. Hidden branches,
  previews, older scroll, group info and failed loads cannot acknowledge.
  Failed reads preserve the exact token for explicit retry.
- `application/message_chats_controller.dart` owns one identity-bound scope's
  paging, composite deduplication, loaded-pair subscriptions (also read-only), debounced
  canonical refresh, aggregated connection state, reconnect catch-up, and one
  non-blocking deduplicated photo batch for Private counterparties. Pagination
  requests metadata only for newly encountered targets; Groups never requests
  person photos. The
  provider layer creates separate Private and Groups controller instances so
  each scope owns its complete server cursor.
- `application/messages_controllers.dart` owns keyset paging, detail/action
  state, identity revisions, Reject/Withdraw guards, conflict reloads, and
  canonical post-triage synchronization with participation and the inbox.
- `presentation/messages_routes.dart` owns stable request, chat, and group-info
  routes used by navigation and future notification routing.
- `presentation/messages_screen.dart` owns the two-tab shell, Private/Groups
  toggle, independent loading/refresh/pagination, centrally discriminated chat
  cards, Private Project-request/Resource counterparty avatars, and role-aware
  Project/Resource request cards. Group rows never receive a person avatar.
  Chats and Private are deterministic defaults. Canonical unread counts are
  independent of pending requests and agreement activity.
  Conversation rows share identity/preview content with trailing local time
  above incoming human-message count. Private rows use counterparty names;
  role/kind/read-only/context metadata stays in detail experiences. Scope
  labels contain canonical conversation counts to the right, zero hidden;
  unknown/stale counts remain explicit. Selected navigation badges use theme
  inverse colors, including the unavailable variant.
  Private counterparty previews omit the redundant name; historical replies
  by a different legacy author retain that author's name, and own replies use
  localized You/Tu.
- `presentation/participation_request_details.dart` owns the reusable authorized
  Project request details sheet/content, canonical actions, resolved history,
  and Proposal/Tavolo navigation. The old full-screen request route is a thin
  wrapper around the same component. Rounded contribution labels remain
  detail-only so the inbox never performs per-row selection fan-out.
- `presentation/messages_formatters.dart` owns the shared safe relative-time and
  status formatting used by Messages and request-chat presentation.
  Conversation timestamps use local calendar days: today `HH:mm`, earlier
  within six days an abbreviated localized weekday, otherwise localized
  compact date including year. Existing request/detail date formatting stays
  separate. Pair read-only footer explains reactivation through a new eligible
  pending request; it does not change canonical send entitlement.
- The adjacent `project_request_chat/` feature owns request-chat transport,
  identity-bound state, private identifier-only Realtime signals, structured
  request history, pinned lifecycle actions, and the pending-only composer.
- The adjacent `resource_requests/` feature owns Resource request detail and
  actions. Messages routes Resource cards there without copying domain state.

## Privacy and state

Structured request management returns items to the requester, current Project
manager, or Resource owner. Personal participation pair rows/history are visible
only to their endpoints; ordinary delegates retain request notes/offers and
actions through Requests, without personal previews or follow-ups. Private
messages and narrow display identities never come from public discovery reads. Missing and
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

Counterparty photo metadata and bytes use the adjacent profile-photo feature's
identity-bound in-memory cache. Missing or denied photos keep placeholders and
cannot fail the Messages list; no private photo bytes are persisted to disk.

Inbox pagination and deduplication use `(activity_at, item_kind, request_id)`,
so equal UUIDs in different domains cannot collide. New future structured kinds
(including possible Group or Project invitations) must be added as explicit
typed variants at this central parser/model boundary; no invitation flow is
implemented here.

## Navigation

Messages belongs to the existing Home branch, reached from Home's AppBar or the
default bottom-right navigation shortcut:

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
bottom navigation is Profile / Home / Messages by default, with Browse available
as a device-local Settings preference. Direct Messages or Browse entry makes the
right slot reflect the current destination regardless of that preference; the
route branches remain stable and there is no fourth tab. Plan
06B adds a separate Home notification bell/unread badge and resolves request
alerts into this feature's stable request route. 07B2C owns chat and group-info
presentation without adding a fourth bottom destination.

The retained request-chat route resolves endpoints to the pair with exact request
context and authorized non-endpoint delegates to request details. The UX-NAV01
shell and post-auth return contract remain in their existing router owners.
Loaded read-only pair rows keep one subscription per pair so reactivation can
refresh their summaries. One additional account subscription invalidates unread
totals and scoped lists even for new/unloaded conversations. Unknown or failed
counts display an explicit unavailable/stale indicator; refreshing Messages,
foreground resume or reconnection retries the canonical read. Account changes
clear counts immediately and dispose old subscriptions.

## Durable unread and rollout

Only incoming human messages create eligible receipts. See
[ADR 0008](../../../../../docs/architecture/decisions/0008-message-unread-and-activity-alerts.md)
for commit ordering, one-time rollout baseline and group admission/re-entry.
The badge counts authorized unread conversations across complete scopes, never
loaded pages. Resource chats retain request-scoped identity. Read-only history
retains unread until opened and acknowledged; activity mark-all never reads it.
Unread is private own-state, independent of notification preferences/projectors.
Apply the backend migration before releasing this client; old clients gain no
badges or acknowledgement merely from migration.

`presentation/messages_landing_screen.dart` gates only the public `/messages`
root. Signed-out users get contextual Log in with `/messages` as the Auth return;
incomplete profiles get completion/retry with a safe root cancellation. Restoring
and failed sessions expose the shared recovery state. Private loaders mount only
for a ready identity, keyed by actor; every descendant keeps router protection.
