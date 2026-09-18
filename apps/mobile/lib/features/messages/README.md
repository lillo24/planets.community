# Messages

This feature owns the authenticated mobile Messages information architecture.
It keeps canonical structured participation requests and Project group chats
in independent `Requests` and `Chats` tabs rather than creating one ambiguous
chronological feed. Project-chat transport and UI live in the adjacent
`project_chat/` feature; this feature remains the entry point.

## Source map

- `domain/message_models.dart` defines the strict requester/creator viewer role,
  structured request item, typed skill/resource selection labels, and paired
  activity/request cursor.
- `data/messages_gateway.dart` is the only Supabase boundary. It calls the 07A
  list/exact reads, the private 04C3B1 selection read, and the existing 05A
  Accept/Reject/Withdraw transitions, then strictly parses each narrow response.
- `application/messages_controllers.dart` owns keyset paging, detail/action
  state, identity revisions, duplicate-action guards, conflict reloads, and
  synchronization with the existing 05B participation controllers.
- `presentation/messages_routes.dart` owns stable request, chat, and group-info
  routes used by navigation and future notification routing.
- `presentation/messages_screen.dart` owns the two-tab shell, independent
  loading/refresh/pagination, chat previews, and the existing role-aware request
  cards. Chats is the deterministic default and no unread state is fabricated.
- `presentation/participation_request_message_screen.dart` owns full authorized
  request detail, canonical actions, resolved history, and Proposal/Tavolo
  navigation. Rounded contribution labels remain detail-only so the inbox never
  performs per-row selection fan-out.

## Privacy and state

The backend returns an item only when the authenticated profile is its requester
or the owning Project creator. The private request message and narrow display
identities are never loaded from public project reads. Missing and unauthorized
exact IDs fail identically. The client displays safe localized errors and never
renders backend diagnostics.

The request item and contribution-selection read are independent. Selection
loading/failure never removes Accept/Reject/Withdraw, and its local retry
resolves current canonical labels for the historical selected IDs. Empty
selection history is valid. Unknown selection kinds fail safely rather than
being rendered as an invented contribution type.

On the 04C3D1 backend, the existing two-argument Accept call succeeds only when
the request has no selected contributions. A selected request therefore remains
visible but cannot be accepted by this stacked client until 04C3D2 adds the
mandatory needed/already-found/extra decision controls and calls the explicit
triaged overload. Reject and Withdraw are unchanged; the backend invariant is
not weakened to preserve the interim button behavior.

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

## Navigation

Messages belongs to the existing Home branch, reached from Home's AppBar:

```text
/messages
/messages/requests/:requestId
/messages/chats/:chatId
/messages/chats/:chatId/info
```

Both routes require authentication and a complete profile. Their exact safe
internal destination survives email OTP and profile completion. The persistent
bottom navigation remains Profile / Browse / Home; there is no fourth tab. Plan
06B adds a separate Home notification bell/unread badge and resolves request
alerts into this feature's stable request route. 07B2C owns chat and group-info
presentation without adding a fourth bottom destination.
