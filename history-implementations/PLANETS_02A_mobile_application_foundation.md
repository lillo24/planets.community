# PLANETS 02A — Mobile Application Foundation

**Roadmap parent:** PLANETS 02 — Mobile and web application foundations  
**Task type:** First portion of roadmap plan 02  
**Repository:** `lillo24/planets.community`  
**Target base:** latest `main`  
**Verified prerequisite:** PLANETS 01B / PR #4 merged as `a7c2809246f4eb6a5dc3f495a370883939e1f112`

## Why roadmap plan 02 is split

The original plan 02 spans two independent application ecosystems plus configuration and observability:

- Flutter mobile architecture;
- Next.js public/admin architecture;
- Supabase client initialization on both surfaces;
- environment configuration;
- localization;
- loading/error conventions;
- Sentry;
- CI and documentation.

That is too broad for one reviewable implementation prompt.

Execute it as:

- **02A — Mobile Application Foundation**: this prompt.
- **02B — Web/Admin Application Foundation**: prepare only after 02A is merged and the repository is re-inspected.

Parent plan 02 remains incomplete until both portions are merged. Plan 03 must not begin after 02A alone.

## Objective

Replace the neutral Flutter bootstrap with a stable mobile application shell that later feature plans can extend without redesigning startup, routing, dependency access, configuration, localization, error-state UI, or monitoring.

After this task, the mobile app should have:

- a restrained feature-ready folder structure;
- Riverpod 3 as the only application state/dependency system;
- `go_router` and `MaterialApp.router`;
- typed `local` / `staging` / `production` build configuration;
- Supabase Flutter initialized from client-safe build configuration;
- Sentry error/crash reporting wired but disabled when no DSN is supplied;
- Material 3 theme/tokens without brand-specific visual design;
- Flutter `gen-l10n` localization scaffolding;
- reusable loading, empty, and safe error states;
- deterministic tests and CI;
- no authentication or product feature behavior.

## Read before changing anything

Inspect current `main` and Git status first. At minimum read:

1. `AGENTS.md`
2. `README.md`
3. `apps/mobile/pubspec.yaml`
4. `apps/mobile/lib/main.dart`
5. `apps/mobile/test/widget_test.dart`
6. current Android/iOS platform configuration
7. `package.json`
8. `.github/workflows/validation.yml`
9. `docs/development/getting-started.md`
10. `docs/development/database.md`
11. `docs/architecture/core-stack.md`
12. `docs/architecture/system-design.md`
13. `docs/implementation/roadmap.md`
14. relevant ADRs
15. `apps/web/AGENTS.md` only for awareness that plan 02B must follow the current Next.js-local documentation rather than old assumptions

The roadmap may still say 01B is in progress because that status was written before PR #4 merged. Repository merge history is the source of truth: **01A and 01B are implemented and parent plan 01 is complete.** Correct the roadmap as part of this PR.

## Current implementation evidence

At the verified base:

- Flutter 3.47.2 / Dart 3.13.2 are the repository-pinned mobile toolchain;
- the mobile app contains only Flutter plus `flutter_lints`;
- `main.dart` renders a neutral static bootstrap page;
- no Riverpod, `go_router`, Supabase Flutter, Sentry, or localization foundation exists;
- Android and iOS platform scaffolds exist with provisional identifiers;
- the secure Supabase database foundation is implemented;
- `public.profiles` exists as a minimal Auth-linked identity anchor;
- no mobile Supabase client exists;
- no authentication UI exists;
- no remote Supabase project or Sentry project is configured.

Current stable package releases when this prompt was prepared were approximately:

- `flutter_riverpod` 3.4.2;
- `go_router` 18.0.0;
- `supabase_flutter` 2.17.2;
- `sentry_flutter` 9.28.0.

Use the latest **stable**, Flutter-3.47.2-compatible releases available when executing this task. Do not use prerelease/alpha packages merely because they are newer. Record the exact resolved versions in the completion report.

## External context and accounts

No Google Doc is required.

No cloud account or credential is required.

Do not create/link/configure:

- a remote Supabase project;
- Sentry organization/project;
- Firebase;
- Vercel;
- Resend;
- PostHog;
- Cloudflare;
- Apple/Google developer resources.

The app must support configuration for future staging/production resources without claiming those resources already exist.

## Decisions already made

### 1. Riverpod without another state framework

Use `flutter_riverpod` 3.x.

Wrap the application in `ProviderScope`.

Do not add:

- Provider;
- Bloc/Cubit;
- GetIt;
- injectable;
- another service locator;
- Flutter Hooks.

Do not use Riverpod's legacy `StateProvider`, `StateNotifierProvider`, or `ChangeNotifierProvider` for new foundation code.

For 02A, manual providers are enough. Do **not** add `riverpod_generator`, `riverpod_annotation`, `build_runner`, or code-generated providers solely to establish the shell. Reconsider code generation when actual feature state makes it useful.

Riverpod 3 retries failing providers by default. Do not put mutation/side-effect commands inside retryable provider build functions. Later feature mutations should be explicit operations.

### 2. `go_router` is the canonical mobile router

Use `MaterialApp.router` with one `GoRouter`.

Routing configuration should live under the application layer rather than inside feature widgets.

The foundation needs only:

- `/` for the neutral application shell;
- an explicit safe router error/not-found experience.

Do not add fake future routes for auth, profiles, proposals, chat, settings, or admin.

Platform app/universal-link registration is deferred until a real flow needs a callback/deep link.

### 3. Keep the folder structure restrained

A suitable high-level direction is:

```text
lib/
  app/
    app.dart
    router/
    theme/
  core/
    backend/
    config/
    monitoring/
    ui/
  l10n/
  main.dart
```

Do not create empty `features/*` hierarchies merely to demonstrate "feature-first."

When real features arrive, they should live under `features/<feature>/...` and organize presentation/state/data responsibilities as needed.

Keep `core` for genuinely cross-feature facilities only.

### 4. Build-time configuration uses `--dart-define-from-file`

Use typed application configuration rather than `dotenv` runtime assets.

The canonical configuration keys for mobile are:

```text
APP_ENV
SUPABASE_URL
SUPABASE_PUBLISHABLE_KEY
SENTRY_DSN
```

`APP_ENV` supports exactly:

- `local`
- `staging`
- `production`

Use Supabase's current **publishable key** terminology in code. Do not introduce `SUPABASE_SERVICE_ROLE_KEY`, secret keys, database passwords, or other server-only credentials into mobile configuration.

Supabase's publishable key is intentionally client-side; RLS/grants remain the security boundary.

Use untracked configuration files with committed examples, such as:

```text
apps/mobile/config/local.example.json
apps/mobile/config/staging.example.json
apps/mobile/config/production.example.json
```

Actual `local.json`, `staging.json`, and `production.json` files must be ignored.

Do not commit real staging/production values.

### 5. Configuration validation fails clearly

Create a small immutable typed `AppConfig`/environment model.

Validate at startup:

- environment value is recognized;
- Supabase URL is a valid absolute URI;
- local may use `http` or `https`;
- staging/production Supabase URLs require `https`;
- publishable key is non-empty;
- Sentry DSN is optional, but if supplied must be a valid supported URI.

Do not log or render the full publishable key or Sentry DSN.

A bad configuration must not produce a normal-looking app that silently lacks a backend.

Use a small startup-failure surface or similarly explicit failure path. In debug/test contexts, preserve enough diagnostic information for developers; production-visible text must not expose credentials or stack traces.

### 6. Supabase is initialized once at startup

Add `supabase_flutter`.

Initialize it before ordinary feature code runs using the configured:

- URL;
- publishable key.

Expose `Supabase.instance.client` through a Riverpod provider so later repositories/controllers can depend on a test-overridable provider rather than importing a custom global variable everywhere.

Do not query any product table in 02A.

Do not implement Auth flows, session redirects, profile creation, Realtime, Storage, or Edge Functions.

Do not add a generic custom API/repository wrapper merely around `SupabaseClient`.

### 7. Sentry is optional and privacy-safe

Add `sentry_flutter`.

If `SENTRY_DSN` is empty, Sentry must remain disabled and the application must run normally.

If configured, initialize the current stable SDK for error/crash reporting.

Foundation defaults:

- no user identity/email attached;
- `sendDefaultPii` remains false;
- do not enable session replay;
- do not enable screenshots;
- do not enable profiling;
- do not enable performance tracing merely for future use;
- do not attach Supabase keys, auth tokens, exact locations, message bodies, or arbitrary request bodies;
- do not send a synthetic test error on every startup.

Use the SDK's current supported Flutter error integration rather than installing redundant global error handlers that double-report exceptions.

Production source-map/debug-symbol upload belongs to release/operational plans.

### 8. Material 3 with neutral centralized tokens

Use Material 3 and centralize theme setup.

Provide:

- light theme;
- dark theme;
- `ThemeMode.system`;
- a small spacing/radius/breakpoint token set only where useful;
- standard accessible contrast and tap-target behavior.

Do not establish PLANETS brand colors, custom fonts, illustrations, animations, or polished navigation.

A standard Material seed/color choice may be used as a placeholder but must be documented as non-brand/foundation-only.

### 9. Localization uses Flutter's built-in generator

Add:

- `flutter_localizations` from the Flutter SDK;
- `intl` as required by current Flutter localization tooling.

Use `flutter: generate: true` and `l10n.yaml`.

Generated localization source must use the current source-generation model; do **not** import the removed synthetic `package:flutter_gen`.

Create an English template ARB only. The goal is to ensure future user-facing strings are localizable, not to decide supported languages.

Do not add Italian/German/etc. translations without a product decision.

### 10. Common state UI is simple, not a generic framework

Provide small reusable foundation widgets for:

- loading;
- empty state;
- recoverable error with optional retry callback.

They should:

- use theme tokens;
- be accessible;
- avoid raw exception/stack-trace output;
- allow feature-specific copy later.

Do not build a universal `Result`, `Either`, response wrapper, generic repository hierarchy, or complex `AsyncValue` abstraction before real features exist.

## Required work

### A. Dependencies

Use normal Flutter package tooling and update `pubspec.lock`.

Add stable compatible dependencies for:

- `flutter_riverpod`;
- `go_router`;
- `supabase_flutter`;
- `sentry_flutter`;
- `flutter_localizations`;
- `intl`.

Do not add Freezed/`json_serializable` yet: there are no application models to serialize. Those remain accepted stack tools and can be introduced with the first feature models.

Do not add packages that duplicate these responsibilities.

### B. App startup/bootstrap

Refactor `main.dart` into a thin entry point.

Separate concerns so startup is testable:

1. bind Flutter;
2. load/validate compile-time app config;
3. initialize Supabase once;
4. initialize Sentry only when configured;
5. run `ProviderScope`;
6. render the application.

Avoid a huge `main.dart`.

Do not perform network health checks or database queries at startup.

### C. Riverpod foundations

Provide small providers for stable cross-cutting dependencies, at minimum:

- typed app configuration;
- `SupabaseClient`;
- router if the chosen architecture benefits from a provider.

Providers must be overrideable in tests.

Do not create fake feature state providers.

### D. Router/application shell

Create `PlanetsApp` using `MaterialApp.router`.

Connect:

- router;
- theme/light/dark;
- system theme mode;
- localization delegates;
- supported locales;
- safe route-error handling.

Keep `/` as a neutral foundation screen. It may show `PLANETS` and a small non-product foundation message, but no pretend navigation or feature buttons.

### E. Local mobile configuration workflow

Preserve cross-platform development.

Prefer a small root script that can derive a local mobile config from `supabase status -o env` instead of forcing developers to copy long keys manually.

If current CLI output makes this practical, provide an equivalent of:

```text
npm run mobile:config:local
```

that writes ignored `apps/mobile/config/local.json` containing:

- `APP_ENV=local`;
- local Supabase API URL;
- local publishable/anon key mapped to `SUPABASE_PUBLISHABLE_KEY`;
- empty Sentry DSN.

It must not print the full key unnecessarily.

Allow an optional host override for the Android Emulator, where host loopback is normally reached through `10.0.2.2`.

If the current Supabase CLI output cannot be parsed robustly without brittle assumptions, do not build a fragile parser; document the exact `supabase status` → config-file setup instead.

Update `npm run dev:mobile` or add a clearly named local command so the intended config file is passed with `--dart-define-from-file`.

Do not expose the local Supabase stack on a public network as part of this automation.

### F. Platform networking prerequisite

Ensure the Android release/main manifest declares `INTERNET` permission as required for Supabase network access.

Do not add broad cleartext/network-security exceptions to production.

If a debug-only local HTTP exception is required by the actual current Android/iOS toolchain to reach local Supabase, scope it strictly to debug and document it. Do not weaken release transport security.

Do not add Android 17 local-network runtime permission machinery unless the current app target and an actual local-development connection require it.

### G. Localization

Add current Flutter `gen-l10n` setup and a minimal English ARB.

Move foundation-visible strings that should be user-facing into localization resources.

Ensure a clean checkout generates localization sources before analyze/test/build.

Choose whether generated Dart localization files are committed or regenerated as part of tooling based on current Flutter 3.47 behavior; document the convention and make CI deterministic. Do not maintain generated files manually.

### H. Theme and common state widgets

Add the neutral theme/tokens and the three common state widgets.

Use semantics/accessibility where appropriate.

Do not introduce a component library or design system package.

### I. Tests

Replace the old bootstrap-only test with focused tests.

At minimum cover:

#### Configuration

- `local`, `staging`, `production` parse correctly;
- unknown environment fails;
- missing/blank Supabase config fails;
- HTTP Supabase URL is allowed for local;
- HTTP Supabase URL is rejected for staging/production;
- optional empty Sentry DSN disables monitoring;
- invalid non-empty DSN fails safely;
- diagnostic output does not expose full configured keys.

#### App shell/router

- app renders through `MaterialApp.router`;
- `/` renders the foundation route;
- unknown route uses the safe router error/not-found surface;
- ProviderScope overrides can supply test config/dependencies.

#### Theme/localization/states

- light/dark themes are available;
- English localization initializes;
- loading/empty/error states render;
- raw exception text is not exposed by default;
- retry callback is invoked when supplied.

Do not require a real Supabase network connection or Sentry account in unit/widget tests.

### J. Validation and CI

Keep existing database, web, and mobile jobs passing.

Update mobile validation as required by localization generation and new dependencies.

A clean mobile job should perform equivalents of:

```text
flutter pub get
flutter gen-l10n
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

If `flutter pub get` already performs deterministic l10n generation on the pinned SDK, an explicit generation command can still remain for clarity.

The database job must continue passing unchanged security tests and generated web-type drift.

### K. Documentation and roadmap

Add/update concise mobile development documentation covering:

- mobile architecture boundaries;
- environment keys;
- `--dart-define-from-file`;
- local Supabase configuration;
- Android emulator host override;
- Sentry-disabled-by-default behavior;
- localization generation;
- relevant root commands;
- future feature folder convention.

Update the roadmap:

- parent 01 → `Implemented`;
- 01A → `Implemented`;
- 01B → `Implemented`;
- split parent 02 into 02A and 02B;
- parent 02 → `In progress`;
- 02A → `In progress`;
- 02B → `Not started`;
- plan 03 remains `Not started` and blocked on full parent 02 completion.

The immediate next action after this PR should be completion/merge of 02A followed by preparation of 02B from the actual merged result.

## Non-goals

Do not implement:

- email OTP/login/signup/logout;
- session-driven route redirects;
- profile creation/editing;
- profile fields;
- competence/preferences;
- proposals;
- participation;
- notifications;
- chat;
- Storage;
- Realtime behavior;
- Edge Functions;
- database schema changes;
- new database grants/policies;
- app-link/universal-link platform association;
- final navigation structure;
- bottom navigation;
- polished home screen;
- custom brand identity;
- maps/location permissions;
- Firebase;
- PostHog;
- provider code generation;
- Freezed/model serialization;
- offline persistence/sync;
- remote Supabase or Sentry provisioning;
- release symbol upload.

## Failure behavior and edge cases

### Missing mobile config file

Development must fail clearly with setup guidance, not silently fall back to a production/staging endpoint.

Do not commit an actual config just to make startup pass.

### Malformed environment values

Reject them before initializing Supabase/Sentry.

Do not normalize an unknown environment string into `local`.

### Sentry unavailable/unconfigured

An empty DSN is a valid disabled state.

The application must not depend on Sentry availability to start.

### Supabase initialization error

Do not render a success-looking application shell if initialization failed.

Show a safe startup failure or fail loudly according to build mode; do not expose credentials.

### Testing global Supabase initialization

Do not make widget tests depend on repeated global `Supabase.initialize` calls. Keep the app shell/provider boundaries overrideable so most tests can provide fakes/mocks or avoid reading the client.

### Local HTTP

Do not weaken production transport security to simplify local development.

Prefer debug-only configuration when the platform needs an exception.

## Acceptance criteria

02A is ready for merge when:

- [ ] parent plan 01/01A/01B are recorded implemented;
- [ ] roadmap plan 02 is split into 02A/02B and parent 02 is in progress;
- [ ] Riverpod 3 is installed and `ProviderScope` is the root dependency/state container;
- [ ] no competing state/service-locator framework is introduced;
- [ ] `go_router` drives `MaterialApp.router`;
- [ ] only real foundation routes exist;
- [ ] typed `local/staging/production` config exists;
- [ ] config is supplied through `--dart-define-from-file`;
- [ ] real config files are ignored and examples are committed;
- [ ] mobile config never contains server-only Supabase secrets;
- [ ] Supabase Flutter initializes from URL + publishable key;
- [ ] `SupabaseClient` is exposed through an overrideable Riverpod provider;
- [ ] no database query/auth behavior is introduced;
- [ ] Sentry Flutter is wired and disabled when DSN is empty;
- [ ] privacy-safe Sentry defaults are documented/tested where practical;
- [ ] Material 3 light/dark/system theme foundation exists;
- [ ] no final brand styling is introduced;
- [ ] Flutter built-in localization generation works from a clean checkout;
- [ ] localization does not use `package:flutter_gen`;
- [ ] loading/empty/error foundation widgets exist;
- [ ] Android main/release networking permission is correct;
- [ ] mobile config/startup/router/theme/localization/state tests pass;
- [ ] `flutter analyze` and all Flutter tests pass;
- [ ] Database and Web CI remain green;
- [ ] no product feature or plan-03 auth/profile behavior leaks into 02A.

## Autonomy and stop conditions

Decide low-level file/class names and minor widget composition autonomously.

You may decide:

- exact `lib/app` / `lib/core` subfolders;
- exact provider names;
- whether `GoRouter` is itself a provider;
- exact placeholder Material seed;
- exact localization output path;
- generated-l10n commit convention;
- exact local config helper implementation;
- exact safe startup-error UI.

Stop and report before:

- changing the accepted mobile framework/state/router/backend choices;
- adding a second state-management/DI framework;
- using service-role/secret credentials in mobile;
- making profile/auth product decisions;
- requiring a cloud account for this plan;
- weakening production network security for local HTTP;
- adding final navigation/visual design;
- introducing a broad error/result/repository abstraction without concrete use;
- absorbing 02B or plan 03.

## Deliverables

Produce:

1. mobile architecture/startup refactor;
2. Riverpod and router foundations;
3. typed configuration and example files;
4. Supabase client initialization/provider;
5. optional Sentry initialization;
6. Material 3 theme/tokens;
7. localization scaffold;
8. loading/empty/error states;
9. tests;
10. local-mobile config/run tooling;
11. documentation and roadmap updates;
12. focused pull request, preferably on a branch similar to `codex/02a-mobile-foundation`;
13. completion report.

Do not merge the pull request yourself unless explicitly instructed by the active execution environment.

## Completion report

Return:

1. **Summary**
2. **Changed areas/files**
3. **Resolved package versions**
4. **Mobile structure**
5. **Configuration**
   - keys;
   - file workflow;
   - local Android emulator behavior;
6. **Riverpod/router**
7. **Supabase initialization**
8. **Sentry/privacy defaults**
9. **Theme/localization/state UI**
10. **Tests**
11. **Validation and CI**
12. **Manual/external setup**
13. **Deferred work**
14. **Warnings/blockers for 02B**
15. **Pull request/commit reference**

Do not report parent roadmap plan 02 as implemented. Only 02A can be complete after this PR; 02B remains required before plan 03.
