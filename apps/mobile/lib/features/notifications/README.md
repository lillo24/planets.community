# Notifications

This feature owns the authenticated mobile in-app notification inbox, unread
state, and current in-app preference UI. It consumes the canonical 06A/06D/04C4C2
notification projection; it does not read notification tables, process the
outbox, register devices, deliver push, or own participation/chat actions.

## Source map

- `domain/notification_models.dart` defines forward-safe category/kind/target
  enums, notification rows, paired keyset cursors/pages, and preferences.
- `data/notifications_gateway.dart` is the only Supabase boundary. It calls the
  six expected-identity-bound 06A client RPCs and strictly parses their narrow
  results. It never calls the service-only projector.
- `application/notifications_controllers.dart` owns inbox paging, unread state,
  mark-one/mark-all, duplicate-action guards, rollback/reload behavior,
  Participation/Resources/Matching preference state, and identity
  revisions.
- `presentation/notification_destination.dart` maps known semantic targets to
  the 07A Messages request item, the canonical Project-chat route, Resource
  request/chat routes, the existing public Resource detail route for Matching,
  or existing Proposal/Tavolo routes without deriving navigation from display
  copy.
- `presentation/notification_copy.dart` owns localized copy selection and safe
  missing-context/future-kind fallbacks.
- `presentation/home_notification_button.dart` owns the Home bell, accessible
  unread badge, and ready-identity refresh.
- `presentation/notifications_screen.dart` owns inbox loading, empty, safe
  error, refresh, keyset pagination, read state, and tap orchestration.
- `presentation/notification_preferences_screen.dart` exposes Participation,
  Resources, and the global Matching in-app controls while keeping Push
  hidden.
- `presentation/notification_routes.dart` identifies the guarded Home routes.

## Backend and privacy boundary

The gateway calls only `list_own_notifications`,
`get_own_unread_notification_count`, `mark_notification_read`,
`mark_all_notifications_read`, `list_own_notification_preferences`, and
`set_own_notification_preference`. Flutter contains no service-role credential
and never calls `process_notification_outbox_batch`. Notification source JSON,
request messages, exact meeting information, email, tokens, and outbox/audit
identifiers are neither requested nor rendered.

Known participation, Project-chat, Resource, and Matching rows are strictly validated,
including exact Resource request/chat/exchange shapes, event/leg consistency,
and Project/Resource field separation. Matching requires only its semantic
category/kind/destination and listing identifier; its listing title is optional
safe display enrichment. Neither saved-search identifiers nor filters enter the
mobile model. Resource copy uses only listing title
and safe actor context; it never fetches request text, chat bodies, private
terms, requester item descriptions, lend dates, or contact details. Unknown
future category or kind values become generic, non-navigable UI;
malformed UUIDs/timestamps and incomplete current semantics produce a safe
explicit load failure. Presentation never exposes raw wire values.

## State, navigation, and refresh

Routes belong to Home without changing Profile / Browse / Home:

```text
/notifications
/notifications/preferences
```

Request alerts open `/messages/requests/:requestId`; participant-left opens the
creator's existing Participation overview; participant-removed opens the
Proposal/Tavolo detail; Project chat alerts open `/messages/chats/:chatId`.
Resource request alerts open `/messages/requests/resource/:requestId` and
accepted/chat/exchange alerts open `/messages/chats/resource/:chatId`.
Matching alerts open the existing `/resources/:listingId` public detail. Their
inbox copy is built entirely from the notification RPC row; no saved search,
match fact, or listing is fetched while rendering the inbox.
Unknown or incomplete destinations have no route. An
unread tap attempts the identity-bound read first. A transient read failure is
reported but does not block a still-valid target; an identity change always
blocks navigation.

Inbox, unread, preference, page, and mutation results are held only in
identity-bound Riverpod memory. Sign-out/account change clears them and rejects
late work. Unread count refreshes when a ready Home bell is built, when the
inbox loads/refreshes, and after read actions. 06B deliberately adds no timer,
Realtime subscription, or background service.

The preference screen requires exactly one configurable Participation,
Resources, and Matching row, ignoring unknown future categories. A retained
Chat row is optional and preserved, with no obsolete in-app control. It preserves each
hidden `push_enabled` value unchanged when setting its
`in_app_enabled` value. Disabling a category affects future projected in-app
rows only; existing history remains. No category-specific push toggle is
exposed in this slice. Matching is one global immediate policy across all saved
searches: there is no digest/frequency selector or per-search notification
toggle. Push permission, provider delivery, and dedicated push control UX
remain separate work.

## Local native-QA data

Start from a fresh local stack because the 06A integration fixture asserts its
own initial state:

```text
npm run db:start
npm run db:reset
npm run notification:verify:local
npm run mobile:config:local
npm run dev:mobile
```

The trusted integration prepares deterministic local profiles for
`notifications-local-a@planets.invalid` (creator),
`notifications-local-b@planets.invalid` (requester), and
`notifications-local-c@planets.invalid` (other). Request a fresh OTP in the app
and read it from local Mailpit; the scripts never print OTPs or credentials.
The creator has received/withdrawn/participant-left history, the requester has
an accepted item, and the other profile has a rejected item.

When native QA creates another participation transition in the app, run:

```text
npm run notification:project:local
```

This local-only trusted helper derives the service credential from local
Supabase status, drains the projector outside Flutter, prints only aggregate
counts, and lets the tester pull-to-refresh. It is suitable for preparing
participant-removal, preference suppression/re-enable, and additional paging
rows without adding a QA control to the app.

MSG02 classifies by semantic kind: ordinary `chat_message_received` and
`resource_chat_message_received` events create no future inbox rows and existing
rows are excluded before paging, bell counts and mark-all. Historical rows remain
unchanged; exact own-ID read/navigation remains supported and never acknowledges
chat. Request, membership, Resource exchange/terms/milestone/cancellation and
Matching alerts retain their activity behavior, including chat destinations.
The shared event resolver, suppressed receipts, push preferences and supported
push jobs remain intact. Human-message attention belongs to Messages unread.
Device registration, FCM/APNs, permission timing, and safe provider previews
remain 06C2B. Native QA remains deferred to the consolidated Plan 12 pass.
