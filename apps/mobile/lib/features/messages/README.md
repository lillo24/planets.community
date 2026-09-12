# Messages

This feature owns the authenticated mobile Messages surface for structured
participation requests. It presents canonical `project_join_requests`; it does
not create a generic message, thread, or request-copy store. Project group chat
remains separate Plan 07B scope.

## Source map

- `domain/message_models.dart` defines the strict requester/creator viewer role,
  structured request item, and paired activity/request cursor.
- `data/messages_gateway.dart` is the only Supabase boundary. It calls the 07A
  list/exact read RPCs and the existing 05A Accept/Reject/Withdraw transitions,
  then strictly parses the narrow response.
- `application/messages_controllers.dart` owns keyset paging, detail/action
  state, identity revisions, duplicate-action guards, conflict reloads, and
  synchronization with the existing 05B participation controllers.
- `presentation/messages_routes.dart` owns the stable
  `/messages/requests/:requestId` target used by future notification routing.
- `presentation/messages_screen.dart` owns inbox loading, empty, safe-error,
  refresh, pagination, role-aware copy, status, and project context.
- `presentation/participation_request_message_screen.dart` owns full authorized
  request detail, canonical actions, resolved history, and Proposal/Tavolo
  navigation.

## Privacy and state

The backend returns an item only when the authenticated profile is its requester
or the owning Project creator. The private request message and narrow display
identities are never loaded from public project reads. Missing and unauthorized
exact IDs fail identically. The client displays safe localized errors and never
renders backend diagnostics.

Inbox and detail data live only in identity-bound Riverpod memory. Every load or
mutation captures the rendered identity and a request revision; sign-out or an
account switch clears state and rejects late responses. Pending actions are
role-specific: creators may Accept/Reject and requesters may Withdraw. A
successful action reloads the canonical item and inbox, then refreshes the
corresponding 05B participation view. Conflicts also reload current canonical
state. Resolved requests remain read-only history and do not imply chat access.

## Navigation

Messages belongs to the existing Home branch, reached from Home's AppBar:

```text
/messages
/messages/requests/:requestId
```

Both routes require authentication and a complete profile. Their exact safe
internal destination survives email OTP and profile completion. The persistent
bottom navigation remains Profile / Browse / Home; there is no fourth tab. Plan
06B adds a separate Home notification bell/unread badge and resolves request
alerts into this feature's stable request route.
