# Messages

This feature owns the authenticated mobile Messages information architecture.
It keeps canonical structured Project and Resource requests and Project group
chats in independent `Requests` and `Chats` tabs rather than creating one
ambiguous chronological feed. Project-chat transport and UI live in the adjacent
`project_chat/` feature; this feature remains the entry point.

## Source map

- `domain/message_models.dart` defines the centrally discriminated Project and
  Resource request variants, strict viewer roles, typed contribution labels,
  and the complete activity/kind/request cursor.
- `data/messages_gateway.dart` is the only Supabase boundary. The inbox and
  exact-item reads use the unified 04C4C2 RPCs; Project-only selection and
  mutation operations keep their existing 04C3B1/05A boundaries. Each narrow
  response is parsed strictly and cross-domain field mixtures fail closed.
- `application/messages_controllers.dart` owns keyset paging, detail/action
  state, identity revisions, Reject/Withdraw guards, conflict reloads, and
  canonical post-triage synchronization with participation and the inbox.
- `presentation/messages_routes.dart` owns stable request, chat, and group-info
  routes used by navigation and future notification routing.
- `presentation/messages_screen.dart` owns the two-tab shell, independent
  loading/refresh/pagination, chat previews, and role-aware Project/Resource
  request cards. Chats is the deterministic default and no unread state is
  fabricated.
- `presentation/participation_request_message_screen.dart` owns full authorized
  request detail, canonical actions, resolved history, and Proposal/Tavolo
  navigation. Rounded contribution labels remain detail-only so the inbox never
  performs per-row selection fan-out.
- The adjacent `resource_requests/` feature owns Resource request detail and
  actions. Messages routes Resource cards there without copying domain state.

## Privacy and state

The backend returns an item only when the authenticated profile is its requester
or the owning Project creator/Resource owner. Private request messages and
narrow display identities never come from public discovery reads. Missing and
unauthorized exact IDs fail identically. The client displays safe localized
errors and never renders backend diagnostics.

The request item and contribution-selection read are independent. Selection
loading/failure never removes Accept/Reject/Withdraw, and its local retry
resolves current canonical labels for the historical selected IDs. Empty
selection history is valid. Unknown selection kinds fail safely rather than
being rendered as an invented contribution type. These chips remain immutable
request history and are not reused as mutable acceptance state.

Creator Accept opens the participation-owned 04C3D2 triage sheet, which performs
its own action-local canonical selection read even when the Messages display
read previously succeeded or failed. The shared sheet requires every offered
item to be classified and is the only mobile owner of the D1 eight-argument
acceptance call. On return, request detail, inbox, and an already-loaded matching
creator participation view reload canonical state. Reject and requester
Withdraw remain owned here and unchanged.

Inbox and detail data live only in identity-bound Riverpod memory. Every load or
mutation captures the rendered identity and a request revision; sign-out or an
account switch clears state and rejects late responses. Pending actions are
role-specific: creators may Accept/Reject and requesters may Withdraw. A
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
/messages/chats/:chatId
/messages/chats/:chatId/info
```

Both routes require authentication and a complete profile. Their exact safe
internal destination survives email OTP and profile completion. The persistent
bottom navigation remains Profile / Browse / Home; there is no fourth tab. Plan
06B adds a separate Home notification bell/unread badge and resolves request
alerts into this feature's stable request route. 07B2C owns chat and group-info
presentation without adding a fourth bottom destination.
