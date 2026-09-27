# PLANETS mobile application

This folder owns the Flutter application and its generated Android/iOS platform projects. It contains the shared client foundation, mobile email-OTP authentication, basic profile setup/editing, one-time proposal discovery/management, recurring Tavoli discovery/management, standalone Scambio-Dona discovery/owner management, shared Project participation, structured participation-request Messages, and Project group chat.

## Source map

- `lib/main.dart` is the process boundary. It reports startup failures without rendering configuration or exception details.
- `lib/bootstrap/` orders validated configuration, Supabase initialization, optional monitoring, and application launch.
- `lib/app/` owns the root `MaterialApp.router`, stateful Profile / Browse / Home shell, neutral foundation screen, and startup-failure application. See its [navigation contract](lib/app/README.md).
- `lib/core/config/` owns the typed compile-time environment contract and its Riverpod provider.
- `lib/core/backend/` initializes Supabase and exposes its client through an overrideable provider.
- `lib/core/monitoring/` owns optional, privacy-safe Sentry startup.
- `lib/core/theme/` and `lib/core/widgets/` own neutral design tokens and common loading/empty/error UI.
- `lib/core/time/` owns named event-time-zone conversion and formatting shared by one-time and recurring activities.
- `lib/features/settings/` owns public Settings, the local language preference,
  and links to existing account preference surfaces.
- `lib/features/auth/` owns numeric email-OTP request/verification, session state, profile-anchor readiness, sign-out, and Auth UI.
- `lib/features/profile/` owns basic profile display/setup/editing, controlled skill selection, and public/private field choices.
- `lib/features/proposals/` owns public one-time proposal browse/detail plus complete-profile create/edit/my-proposals flows. It calls canonical RPCs and carries the screen's expected identity on every owner mutation.
- `lib/features/recurring_activities/` owns public Tavoli browse/detail, weekly/monthly draft editing, and My Tavoli lifecycle management over the canonical 04B1 RPCs. See its [feature boundary](lib/features/recurring_activities/README.md).
- `lib/features/resource_listings/` owns signed-out Scambio-Dona discovery/detail and complete-profile create/edit/publish/close flows over only the canonical 04C1 RPCs. See its [feature boundary](lib/features/resource_listings/README.md).
- `lib/features/participation/` owns shared Proposal/Tavolo join requests, own participation state, creator review, membership actions, and participant-authorized meeting information over the canonical 05A RPCs. See its [feature boundary](lib/features/participation/README.md).
- `lib/features/messages/` owns the Home-branch Messages inbox, exact structured participation-request detail/history, and role-specific canonical actions over the 07A reads and existing 05A transitions. See its [feature boundary](lib/features/messages/README.md).
- `lib/features/project_chat/` owns Project-chat summaries, history, send, private Realtime reconciliation, current/former UI, and group information over the canonical 07B2B boundary. See its [feature boundary](lib/features/project_chat/README.md).
- `lib/l10n/` owns the English template ARB and the complete Italian catalog. English remains the fallback for unsupported locales. `flutter gen-l10n` regenerates ignored Dart output under `lib/l10n/generated/`.
- `config/` contains committed configuration examples; runtime files without `.example` are ignored.
- `test/` mirrors the application responsibility boundaries.
- `android/` and `ios/` contain conventional Flutter platform configuration. Local HTTP exceptions are debug-only; shared iOS plist changes must be mirrored in `Info.plist` and `Info-Debug.plist`.

Startup follows one order: parse and validate config, restore the noncritical
local language preference with a System-default fallback, initialize the
canonical Supabase client, configure Sentry only when a DSN exists, then launch
one Riverpod `ProviderScope`. The app starts the Auth session observer explicitly
after launch. `/`, `/settings`, `/settings/language`, Proposal browse/detail,
Tavoli browse/detail, and Scambio-Dona browse/detail remain public; `/auth`
requests a code; `/auth/verify` verifies it; `/profile` and `/profile/edit` own
authenticated profile display/setup. Proposal/Tavolo/Scambio-Dona create/edit/my,
participation join/creator-review, and Messages routes require a complete profile
and route incomplete profiles to setup. Scambio-Dona management, Participation,
and Messages intent survives OTP and profile completion through sanitized
internal `returnTo` values. Magic links, social providers, maps/media, and final
branding remain deferred.

Proposal date/time input is interpreted in an explicit IANA time zone with the bundled `timezone` data and sent to PostgreSQL as UTC instants. Draft/publish/update/cancel authorization and stored/derived lifecycle rules remain canonical database behavior. Public cards receive rough location only; detail shows exact meeting text only when the sanitized backend response marks it public.

The persistent bottom navigation remains Profile / Browse / Home. Browse has separate route-backed Proposal and Tavoli lists; it never mixes their models into one feed. Home exposes the Progetti and Scambio-Dona pillars plus Messages without adding a fourth tab or chat unread badge. `/resources`, its public detail, and its protected `mine`/`create`/`edit` children remain on the Home branch. Scambio-Dona is text-only and has no post-listing interaction flow; requests and handoff remain deferred to 04C4. `/messages`, `/messages/requests/:requestId`, `/messages/chats/:chatId`, and `/messages/chats/:chatId/info` remain on the Home branch. Tavoli pagination reuses one explicit UTC reference snapshot across cursor pages. Recurring schedules remain the versioned, bounded weekly/monthly 04B1 model, and pause/resume/end authorization remains canonical database behavior.

Participation is shared across both concrete Project types without merging their content models. Public details remain available signed out. Private request, membership, creator-review, operational meeting, structured Messages, Project-chat state, and Scambio-Dona owner state are held only in identity-bound memory and cleared on account changes. Messages request list/exact reads are requester/creator-only, while Accept/Reject/Withdraw reuse the expected-identity-bound 05A transitions and refresh 05B state. Project chat reads remain server-authorized for creator/current/former history, sends and private Realtime are current-only, and protected meeting details remain in the Participation boundary. Chat notifications/unread state, push delivery, Project resources, Scambio-Dona post-listing interactions, capacity, and contribution verification remain deferred.

The pending email and code live only in memory. Supabase owns session persistence and refresh. After verification, the app inserts the current user's skeletal `public.profiles` row; the expected existing primary key is idempotent success, while any unrelated error keeps the session and offers anchor retry. A non-null valid display name then derives completed-profile readiness.

Run mobile commands from the repository root:

```text
npm run mobile:config:local
npm run dev:mobile
npm run check:mobile
```

The local config command requires the local Supabase stack. See the repository [getting-started guide](../../docs/development/getting-started.md#mobile-configuration) for environment keys, Android emulator setup, and the provisional application identifiers.
