# Notifications

This feature owns the authenticated mobile in-app notification inbox, unread
state, and current in-app preference UI. It consumes the canonical 06A/06D
notification projection; it does not read notification tables, process the
outbox, register devices, deliver push, or own participation/chat actions.

## Source map

- `domain/notification_models.dart` defines forward-safe category/kind/target
  enums, notification rows, paired keyset cursors/pages, and preferences.
- `data/notifications_gateway.dart` is the only Supabase boundary. It calls the
  six expected-identity-bound 06A client RPCs and strictly parses their narrow
  results. It never calls the service-only projector.
- `application/notifications_controllers.dart` owns inbox paging, unread state,
  mark-one/mark-all, the Participation preference, duplicate-action guards,
  rollback/reload behavior, Participation/Chat preference state, and identity
  revisions.
- `presentation/notification_destination.dart` maps known semantic targets to
  the 07A Messages request item, the canonical Project-chat route, or existing
  Proposal/Tavolo routes without deriving navigation from display copy.
- `presentation/notification_copy.dart` owns localized copy selection and safe
  missing-context/future-kind fallbacks.
- `presentation/home_notification_button.dart` owns the Home bell, accessible
  unread badge, and ready-identity refresh.
- `presentation/notifications_screen.dart` owns inbox loading, empty, safe
  error, refresh, keyset pagination, read state, and tap orchestration.
- `presentation/notification_preferences_screen.dart` exposes Participation
  and Chat **In-app notifications** controls while keeping Push hidden.
- `presentation/notification_routes.dart` identifies the guarded Home routes.

## Backend and privacy boundary

The gateway calls only `list_own_notifications`,
`get_own_unread_notification_count`, `mark_notification_read`,
`mark_all_notifications_read`, `list_own_notification_preferences`, and
`set_own_notification_preference`. Flutter contains no service-role credential
and never calls `process_notification_outbox_batch`. Notification source JSON,
request messages, exact meeting information, email, tokens, and outbox/audit
identifiers are neither requested nor rendered.

Known participation and Project-chat rows are strictly validated. Unknown future category,
kind, destination, or project kind values become generic, non-navigable UI;
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
Proposal/Tavolo detail; chat alerts open `/messages/chats/:chatId`. Unknown or
incomplete destinations have no route. An
unread tap attempts the identity-bound read first. A transient read failure is
reported but does not block a still-valid target; an identity change always
blocks navigation.

Inbox, unread, preference, page, and mutation results are held only in
identity-bound Riverpod memory. Sign-out/account change clears them and rejects
late work. Unread count refreshes when a ready Home bell is built, when the
inbox loads/refreshes, and after read actions. 06B deliberately adds no timer,
Realtime subscription, or background service.

The preference screen loads the effective Participation and Chat rows and
preserves each hidden `push_enabled` value unchanged when setting its
`in_app_enabled` value. Disabling a category affects future projected in-app
rows only; existing history remains. Push permission and controls belong to
06C2B.

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

06D chat alerts use only safe actor/Project display context and semantic
Project/chat/message identifiers; they never fetch or render message bodies.
Device registration, FCM/APNs, permission timing, and safe provider previews
remain 06C2B. Native QA remains deferred to the consolidated Plan 12 pass.
