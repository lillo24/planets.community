# PLANETS mobile application

This folder owns the Flutter application and its generated Android/iOS platform projects. It contains the shared client foundation, mobile email-OTP authentication, basic profile setup/editing, and one-time proposal discovery/management.

## Source map

- `lib/main.dart` is the process boundary. It reports startup failures without rendering configuration or exception details.
- `lib/bootstrap/` orders validated configuration, Supabase initialization, optional monitoring, and application launch.
- `lib/app/` owns the root `MaterialApp.router`, stateful Profile / Browse / Home shell, neutral foundation screen, and startup-failure application. See its [navigation contract](lib/app/README.md).
- `lib/core/config/` owns the typed compile-time environment contract and its Riverpod provider.
- `lib/core/backend/` initializes Supabase and exposes its client through an overrideable provider.
- `lib/core/monitoring/` owns optional, privacy-safe Sentry startup.
- `lib/core/theme/` and `lib/core/widgets/` own neutral design tokens and common loading/empty/error UI.
- `lib/features/auth/` owns numeric email-OTP request/verification, session state, profile-anchor readiness, sign-out, and Auth UI.
- `lib/features/profile/` owns basic profile display/setup/editing, controlled skill selection, and public/private field choices.
- `lib/features/proposals/` owns public one-time proposal browse/detail plus complete-profile create/edit/my-proposals flows. It calls canonical RPCs and carries the screen's expected identity on every owner mutation.
- `lib/l10n/` owns the English ARB source. `flutter gen-l10n` regenerates ignored Dart output under `lib/l10n/generated/`.
- `config/` contains committed configuration examples; runtime files without `.example` are ignored.
- `test/` mirrors the application responsibility boundaries.
- `android/` and `ios/` contain conventional Flutter platform configuration. Local HTTP exceptions are debug-only; shared iOS plist changes must be mirrored in `Info.plist` and `Info-Debug.plist`.

Startup follows one order: parse and validate config, initialize the canonical Supabase client, configure Sentry only when a DSN exists, then launch one Riverpod `ProviderScope`. The app starts the Auth session observer explicitly after launch. `/` and proposal browse/detail remain public; `/auth` requests a code; `/auth/verify` verifies it; `/profile` and `/profile/edit` own authenticated profile display/setup. Proposal create/edit/my routes require a complete profile and route incomplete profiles to setup. Optional `returnTo` values accept only internal non-Auth paths. Magic links, social providers, proposal participation, recurring activities, maps/media, and final branding remain deferred.

Proposal date/time input is interpreted in an explicit IANA time zone with the bundled `timezone` data and sent to PostgreSQL as UTC instants. Draft/publish/update/cancel authorization and stored/derived lifecycle rules remain canonical database behavior. Public cards receive rough location only; detail shows exact meeting text only when the sanitized backend response marks it public.

The pending email and code live only in memory. Supabase owns session persistence and refresh. After verification, the app inserts the current user's skeletal `public.profiles` row; the expected existing primary key is idempotent success, while any unrelated error keeps the session and offers anchor retry. A non-null valid display name then derives completed-profile readiness.

Run mobile commands from the repository root:

```text
npm run mobile:config:local
npm run dev:mobile
npm run check:mobile
```

The local config command requires the local Supabase stack. See the repository [getting-started guide](../../docs/development/getting-started.md#mobile-configuration) for environment keys, Android emulator setup, and the provisional application identifiers.
