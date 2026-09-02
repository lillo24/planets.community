# PLANETS mobile application

This folder owns the Flutter application and its generated Android/iOS platform projects. It contains the shared client foundation and the first real product boundary: mobile email-OTP authentication.

## Source map

- `lib/main.dart` is the process boundary. It reports startup failures without rendering configuration or exception details.
- `lib/bootstrap/` orders validated configuration, Supabase initialization, optional monitoring, and application launch.
- `lib/app/` owns the root `MaterialApp.router`, router, neutral foundation screen, and startup-failure application.
- `lib/core/config/` owns the typed compile-time environment contract and its Riverpod provider.
- `lib/core/backend/` initializes Supabase and exposes its client through an overrideable provider.
- `lib/core/monitoring/` owns optional, privacy-safe Sentry startup.
- `lib/core/theme/` and `lib/core/widgets/` own neutral design tokens and common loading/empty/error UI.
- `lib/features/auth/` owns numeric email-OTP request/verification, session state, profile-anchor readiness, sign-out, and Auth UI.
- Future real product features belong under `lib/features/<feature>/`. A feature should add presentation, domain, or data subfolders only when it has real responsibilities in those layers.
- `lib/l10n/` owns the English ARB source. `flutter gen-l10n` regenerates ignored Dart output under `lib/l10n/generated/`.
- `config/` contains committed configuration examples; runtime files without `.example` are ignored.
- `test/` mirrors the application responsibility boundaries.
- `android/` and `ios/` contain conventional Flutter platform configuration. Local HTTP exceptions are debug-only; shared iOS plist changes must be mirrored in `Info.plist` and `Info-Debug.plist`.

Startup follows one order: parse and validate config, initialize the canonical Supabase client, configure Sentry only when a DSN exists, then launch one Riverpod `ProviderScope`. The app starts the Auth session observer explicitly after launch. `/` remains public; `/auth` requests a code and `/auth/verify` verifies it. Optional `returnTo` values accept only internal non-Auth paths. Magic links, deep-link registration, social providers, web/admin Auth, final profile fields, product navigation, and final branding remain deferred.

The pending email and code live only in memory. Supabase owns session persistence and refresh. After verification, the app inserts the current user's minimal `public.profiles` row; the expected existing primary key is idempotent success, while any unrelated error keeps the session and offers profile-setup retry.

Run mobile commands from the repository root:

```text
npm run mobile:config:local
npm run dev:mobile
npm run check:mobile
```

The local config command requires the local Supabase stack. See the repository [getting-started guide](../../docs/development/getting-started.md#mobile-configuration) for environment keys, Android emulator setup, and the provisional application identifiers.
