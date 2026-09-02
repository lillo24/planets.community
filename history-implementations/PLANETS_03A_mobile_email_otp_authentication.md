# PLANETS 03A — Mobile Email-OTP Authentication

**Roadmap parent:** PLANETS 03 — Authentication and profiles  
**Task type:** First portion of roadmap plan 03  
**Repository:** `lillo24/planets.community`  
**Target base:** latest `main`  
**Verified prerequisite:** PLANETS 02B / PR #6 merged as `4fca809f97fa965caaf21b2c53f120be6e772c74`

## Why roadmap plan 03 is split

The original plan 03 combines authentication/session behavior on Flutter, authentication/session behavior on Next.js, and unresolved profile/competence design.

Execute it as:

- **03A — Mobile Email-OTP Authentication**: this prompt.
- **03B — Web Email-OTP Authentication**: prepare after 03A is merged.
- **03C — Profile Setup and Competence/Preference Model**: prepare only after remaining profile/taxonomy decisions are resolved.

Parent plan 03 remains incomplete until all required portions are merged. Plan 04 must not begin after 03A alone.

## Objective

Add production-shaped **mobile passwordless email authentication** using a manually entered one-time code, while preserving PLANETS' public-first boundary.

After this task:

- the app remains usable without authentication;
- users can request a numeric email OTP;
- users can verify it in-app without a magic-link/deep-link callback;
- Supabase sessions restore across app restarts;
- users can sign out;
- the authenticated user's minimal `public.profiles` anchor is ensured;
- auth state is exposed through Riverpod and integrated into routing;
- local Supabase sends an OTP-code email into its local mail viewer;
- tests cover auth state, OTP request/verification, profile-anchor creation, routing, and failures;
- no real profile fields, social login, web auth, deep-link registration, or provider provisioning are introduced.

## Read before changing anything

Inspect current `main` and Git status first. At minimum read:

1. root `AGENTS.md`;
2. `docs/development/codex-tooling.md`;
3. `docs/architecture/core-stack.md`;
4. `docs/architecture/system-design.md`;
5. `docs/development/database.md`;
6. `docs/development/getting-started.md`;
7. `docs/implementation/roadmap.md`;
8. merged Supabase migrations/tests relevant to `public.profiles`;
9. `supabase/config.toml`;
10. `apps/mobile/README.md`;
11. `apps/mobile/pubspec.yaml`;
12. current mobile `app/`, `bootstrap/`, `core/backend/`, `core/config/`, router, localization, and tests;
13. current `supabase_flutter` API docs/package source where needed.

Merge history is authoritative: plans 00, 01, 02A, and 02B are implemented; parent plan 02 is complete.

## Product/design context already resolved

Current PLANETS design material establishes:

- users should browse/discover before registration is forced;
- authentication should be requested when a privileged action is attempted, such as joining;
- profile data later includes competences, interests/preferences, and participation-derived stats;
- photo/location visibility is still unresolved;
- exact competence taxonomy is still unresolved.

Therefore 03A establishes **authentication without making authentication the app's front door**.

The current app has no proposal browsing yet, so `/` remains public. Add only the minimum auth entry/status affordance needed to exercise and test authentication.

## Codex skills/plugins

Preserve the precedence in `docs/development/codex-tooling.md`:

1. repository code/configuration/tests;
2. PLANETS `AGENTS.md`/architecture/ADRs;
3. this implementation plan;
4. external skills/plugins.

### Keep existing persistent tooling

Existing tools from earlier plans should remain installed, including the official Dart/Flutter plugin and narrow Postgres/React/shadcn skills. Do not reinstall or uninstall them merely because this is a mobile task.

### Install and retain the broad official Supabase skill now

03A begins repeated Supabase Auth use, and later PLANETS plans use Supabase Realtime, Storage, Queues/Cron, and client integrations.

If the official broad Supabase skill is missing, install it globally for Codex:

```text
npx skills add supabase/agent-skills --skill supabase -g -a codex -y
```

Keep it installed for later PLANETS Supabase work.

It remains supplementary: PLANETS' fail-closed grants/RLS and current schema/tests override generic examples.

Do not install another generic auth/security/framework bundle.

## Current Auth baseline

The local Supabase config currently:

- enables Auth;
- allows new signups and email signups;
- disables anonymous sign-ins;
- uses 6-digit email OTPs;
- uses 1-hour OTP expiry;
- has the local mail viewer enabled;
- does not yet customize the passwordless email template to show a numeric OTP;
- has no production SMTP/provider configuration.

`public.profiles` contains only:

- `id uuid primary key -> auth.users.id ON DELETE RESTRICT`;
- `created_at timestamptz default now()`.

Authenticated users may select only their own anchor and insert only their own `id`; they cannot update/delete or supply `created_at`.

There is intentionally no Auth signup trigger.

Preserve that design.

## Decisions for 03A

### 1. One passwordless email flow handles new and returning users

Use Supabase `signInWithOtp` with email.

Do not build separate sign-up and login forms.

Allow the normal passwordless flow to create an Auth user when the email is new unless current installed API behavior requires a different explicit option.

Do not reveal whether an entered email already had an account.

### 2. Use a numeric OTP, not a magic link

The passwordless email template must contain `{{ .Token }}` and must not require the user to click `{{ .ConfirmationURL }}`.

Verify using the current email OTP verification type supported by the installed Supabase Flutter version/current official docs.

Do not use deprecated verification types.

Because the user manually enters the code:

- do not add Android app links;
- do not add iOS universal/custom auth callbacks;
- do not change package/bundle identifiers for auth;
- do not add `emailRedirectTo`.

### 3. Keep six-digit codes and existing expiry

Keep the current 6-digit OTP length.

Do not invent a new production expiry/rate-limit policy.

Local mail limits may be raised modestly if `email_sent = 2/hour` materially blocks local iteration; document any such change as local-only.

### 4. Public browsing remains the default

The application must not redirect every signed-out user to auth.

`/` stays public.

Add only auth-specific routes such as `/auth` and `/auth/verify` (or equally clear equivalents).

### 5. Preserve a safe internal return destination

Support an optional internal `returnTo` so later privileged flows can resume after auth.

It must accept only internal app locations; reject absolute/external URLs and arbitrary schemes; fallback to `/`.

Do not add nonexistent product destinations now.

### 6. Supabase Auth is the session source of truth

Add a real auth feature boundary under `features/auth/`.

Riverpod should expose app-facing auth/session state derived from:

- current session;
- `onAuthStateChange`.

Do not maintain an independent persisted `isLoggedIn` flag or duplicate auth token storage.

### 7. Auth commands are explicit side effects

OTP request, OTP verify, logout, and profile-anchor ensure operations must be explicit commands/controllers, not side effects inside retryable provider build methods.

Use Riverpod 3 and the merged architecture; do not add ChangeNotifier/Bloc/GetIt.

### 8. Ensure the minimal profile anchor after auth

After successful authentication, ensure the own `public.profiles` row exists.

Do not add profile fields.

The operation must be idempotent.

Because UPDATE is intentionally not granted, do not use an upsert that requires UPDATE. Use an insert-if-missing strategy compatible with current grants/RLS; treat only the expected own-profile duplicate as success and do not swallow unrelated database errors.

Do not weaken database permissions.

### 9. Logout is session termination only

Use current Supabase sign-out behavior.

After logout, auth state is signed-out and `/` remains available.

Do not delete the account/profile.

### 10. Errors are safe and actionable

Map common user-recoverable failures into safe messages:

- invalid/expired OTP;
- rate limit;
- invalid email;
- connectivity failure;
- generic auth failure.

Never expose stack traces, JWTs, keys, database details, OTPs, or raw provider bodies.

## Required work

### A. Local numeric OTP email template

Add a local passwordless template, likely:

```text
supabase/templates/magic_link.html
```

Configure `[auth.email.template.magic_link]` in `supabase/config.toml`.

The template should contain:

- a PLANETS sign-in heading;
- clearly displayed `{{ .Token }}`;
- a short security/expiry note;
- no marketing content;
- no magic-login link.

Document that hosted staging/production later need an equivalent hosted template; this local file does not configure hosted Supabase.

### B. Auth feature structure

Add a real feature folder, for example:

```text
lib/features/auth/
  data/
  application/
  presentation/
```

Use only layers justified by actual code.

Likely responsibilities:

- Supabase auth adapter/repository;
- auth state provider;
- explicit auth command controller;
- request-code screen/form;
- verify-code screen/form;
- minimal signed-in status/logout affordance.

### C. Request-code behavior

Implement:

- trim surrounding email whitespace;
- basic presence/email-shape validation;
- loading/duplicate-submit prevention;
- `signInWithOtp(email: ...)`;
- transition to verification only after success;
- resend action/cooldown behavior without pretending client cooldown is the security boundary.

Do not put name/location/competence/preferences into Auth metadata.

### D. Verify-code behavior

The verification UI should:

- show a masked/identified destination email appropriately;
- accept the expected numeric code length;
- support paste;
- prevent duplicate submit;
- verify via current Supabase email OTP API;
- establish the session;
- ensure the profile anchor;
- navigate to sanitized `returnTo` or `/`.

If profile-anchor ensure fails after Auth succeeds:

- keep the valid session;
- show a safe retryable setup error;
- do not pretend Auth itself failed;
- do not sign out automatically.

### E. Auth/session provider

Expose app-facing states that distinguish at least:

- restoring/checking session;
- signed out;
- authenticated;
- authenticated but profile-anchor setup needs retry/error if useful.

React to initial session and relevant auth-state-change events, including sign-out.

Do not create speculative MFA/provider states.

### F. Router integration

Integrate auth routes into existing `go_router`.

Keep `/` public.

Avoid redirect loops while auth state restores.

Authenticated users should not remain on the sign-in route.

Opening verify without pending email context should return to email entry.

Pending email need not survive arbitrary process death; returning to email entry is acceptable. Never persist OTP values.

### G. Minimal public/auth affordance

Update the neutral foundation screen only enough to exercise Auth:

- signed out: simple Sign in;
- signed in: minimal signed-in/account status and Sign out.

Do not create final account/profile/settings navigation.

### H. Localization

Add all new user-facing Auth strings to Flutter localization resources.

English remains the only configured locale.

### I. Monitoring/privacy

Do not attach email/user ID to Sentry automatically.

Do not log OTPs, tokens, full emails, session values, or provider bodies in breadcrumbs/errors.

Expected user mistakes such as an invalid OTP should not become noisy monitoring events unless there is a clear operational reason.

### J. Tests

Add focused tests without an external email provider.

#### Unit/controller

Cover:

- request success;
- invalid email;
- request backend failure;
- duplicate-submit prevention;
- verify success;
- invalid/expired code mapping;
- profile-anchor ensure success;
- expected existing-anchor duplicate handling;
- unrelated profile failures are not swallowed;
- sign-out;
- session/auth transition handling;
- safe error redaction.

Use test doubles around Supabase-facing operations rather than repeatedly reinitializing the global Supabase singleton.

#### Widget/router

Cover:

- signed-out `/` stays public;
- sign-in route renders;
- request success reaches verify;
- malformed OTP is rejected locally;
- verification success returns safely;
- invalid/external `returnTo` becomes `/`;
- authenticated user does not remain on sign-in;
- verify without pending email returns to email entry;
- logout returns signed-out state while `/` remains available;
- raw backend exceptions are not rendered.

#### Local/backend evidence

Where Docker/local Supabase works, validate enough of the real flow to prove:

- passwordless request creates an email in local mail viewer;
- email contains numeric OTP rather than requiring a magic link;
- OTP verification creates/authenticates a session;
- own profile anchor can be inserted/read under current RLS.

Automate only if deterministic and supported without fragile email-UI scraping. Otherwise document an exact Mailpit verification procedure.

### K. Database/security validation

Do not change `public.profiles` schema/grants unless concrete repository evidence proves it cannot support the flow.

All existing database tests stay green.

Do not add a signup trigger.

### L. CI

Keep Web and Database jobs green.

Update Mobile validation for new tests/dependencies.

If local Auth integration can run deterministically in GitHub Actions without external services, add a focused integration step/job; otherwise do not force email UI automation into CI.

### M. Documentation and roadmap

Document:

- email OTP architecture;
- local mail viewer workflow;
- numeric-code template;
- session restoration;
- profile-anchor ensure behavior;
- public-first routing;
- safe return destination;
- logout;
- explicit absence of magic links/deep links/social providers.

Update `docs/development/codex-tooling.md` to record the broad Supabase skill as persistent if installed.

Update roadmap:

- parent 02 → `Implemented`;
- 02A → `Implemented`;
- 02B → `Implemented`;
- split 03 into 03A/03B/03C;
- parent 03 → `In progress`;
- 03A → `In progress`;
- 03B → `Not started`;
- 03C → `Blocked` or `Not started` with explicit founder-decision dependency;
- plan 04 remains `Not started`.

Within the open PR, do not mark 03A implemented until merged.

## Explicitly deferred founder decisions for 03C

Do not resolve in 03A:

- required profile fields beyond ID/timestamp;
- display/real-name visibility;
- profile photo requirement/visibility;
- location granularity/visibility including CAP-only ideas;
- competence taxonomy hierarchy and free-text vs controlled vocabulary;
- interests/preferences structure;
- public profile visibility;
- badges;
- notification preference categories.

## Non-goals

Do not implement:

- web authentication;
- magic-link auth;
- mobile deep links/app links/universal links;
- Google/Apple/social login;
- passwords;
- phone/SMS;
- MFA;
- password reset/email change;
- account deletion;
- final profile/setup;
- profile data fields;
- proposal/discovery/join;
- notification preferences;
- admin auth;
- service-role clients;
- hosted Supabase provisioning;
- custom SMTP/Resend;
- production rate-limit policy;
- analytics;
- final visual design.

## Edge cases

### Existing versus new email

Use the same flow and do not expose account existence.

### Incorrect/expired OTP

Remain on verification; allow retry/resend; preserve pending email on recoverable errors.

### Request succeeds, app restarts

Returning to email entry is acceptable. Do not persist OTP.

### Profile already exists

Treat only the expected own-profile duplicate as successful idempotence.

### Auth succeeds, profile ensure unexpectedly fails

Keep session valid and expose a safe retry path. Downstream authenticated features must not assume profile readiness until successful.

### Session expires

Return app-facing state to signed out according to real Supabase session behavior.

## Acceptance criteria

03A is ready for merge when:

- [ ] parent 02 and 02A/02B are recorded implemented;
- [ ] plan 03 is split into 03A/03B/03C;
- [ ] broad official Supabase skill is installed globally if missing and recorded persistent;
- [ ] local passwordless template contains numeric `{{ .Token }}`;
- [ ] one email OTP flow handles new/returning users;
- [ ] no magic-link/deep-link callback is required;
- [ ] `/` remains usable signed out;
- [ ] auth routes exist without fake product routes;
- [ ] safe internal `returnTo` exists;
- [ ] auth state derives from Supabase session/events;
- [ ] no duplicate token/session persistence exists;
- [ ] request/verify commands are explicit side effects;
- [ ] successful auth ensures own profile anchor idempotently;
- [ ] existing database RLS/grants are not weakened;
- [ ] no signup trigger is introduced;
- [ ] logout works without account deletion;
- [ ] auth UI is localized;
- [ ] OTP/email/session values are not leaked into logs/Sentry;
- [ ] unit/controller and widget/router Auth tests pass;
- [ ] local numeric-OTP flow is verified automatically or with a precise documented procedure;
- [ ] Mobile, Web, Database CI stay green;
- [ ] no profile/taxonomy/social-login/product decision leaks into 03A;
- [ ] parent plan 03 remains in progress.

## Autonomy and stop conditions

Decide ordinary code organization, provider/controller names, form widgets, error copy, and test doubles autonomously.

Stop and report before:

- switching to magic-link auth;
- adding social login;
- adding deep-link registration;
- choosing profile fields/visibility;
- choosing competence taxonomy;
- weakening profile RLS/grants;
- adding Auth signup trigger;
- requiring hosted Supabase/SMTP;
- installing broad generic auth/security packs;
- absorbing 03B/03C or plan 04.

## Deliverables

Produce:

1. persistent broad Supabase Codex skill setup;
2. local numeric email-OTP template/config;
3. mobile Auth feature implementation;
4. request/verify UI;
5. Supabase-derived session state;
6. profile-anchor ensure;
7. logout;
8. router/public-first and safe-return integration;
9. localization;
10. Auth-focused tests;
11. local Auth integration evidence/procedure;
12. documentation/Codex-tooling/roadmap updates;
13. focused PR, preferably `codex/03a-mobile-email-otp-auth`;
14. completion report.

Do not merge the PR yourself unless explicitly instructed.

## Completion report

Return:

1. **Summary**
2. **Changed areas/files**
3. **Codex skills/plugins**
4. **Local Auth configuration/template**
5. **Auth feature architecture**
6. **OTP request flow**
7. **OTP verification flow**
8. **Session restoration/state handling**
9. **Profile-anchor ensure**
10. **Routing/return destination**
11. **Logout**
12. **Privacy/error handling**
13. **Tests**
14. **Local OTP integration evidence**
15. **Validation and CI**
16. **Manual/external setup**
17. **Deferred founder decisions for 03C**
18. **Warnings/blockers for 03B**
19. **Pull request/commit reference**

Do not report parent plan 03 as implemented.
