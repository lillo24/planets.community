# PLANETS 03B — Web Email-OTP Authentication

**Roadmap parent:** PLANETS 03 — Authentication and profiles  
**Task type:** Second portion of roadmap plan 03  
**Repository:** `lillo24/planets.community`

## Stacked implementation workflow

03A is intentionally still open for native QA, but this task may proceed in parallel because its implementation contract is already code-reviewed.

**Required implementation base when this prompt was written:**

- PR #7 branch: `codex/03a-mobile-email-otp-auth`
- reviewed head: `8af305270ee414e83c298085189b05b585644087`

Before changing code, inspect PR #7. If its head has moved because native QA produced a fix, use the **latest 03A branch head** rather than blindly resetting to the SHA above.

Create 03B from the 03A branch, not from `main`.

Prefer a branch such as:

```text
codex/03b-web-email-otp-auth
```

Open 03B as a **stacked pull request targeting `codex/03a-mobile-email-otp-auth`** while PR #7 remains open.

Do not merge 03B before 03A.

After native QA passes and PR #7 is merged:

1. rebase/update 03B onto the resulting `main`;
2. retarget the 03B PR to `main`;
3. resolve only genuine merge differences;
4. update roadmap status so 03A is `Implemented`;
5. rerun the full validation suite;
6. leave 03B unmerged for its own review.

If native QA materially changes the 03A auth contract, reconcile 03B with the final merged behavior before retargeting. Do not silently preserve a conflicting parallel implementation.

## Objective

Add public-first **web numeric email-OTP authentication** consistent with the reviewed 03A contract and the existing Next.js/Supabase SSR foundation.

After this task:

- `/` remains public;
- signed-out users can open a minimal web sign-in flow;
- one passwordless email flow handles new and returning users;
- the web sends the same six-digit OTP email already established by 03A;
- OTP verification establishes a cookie-backed Supabase session;
- Next.js Server Components can safely recognize restored sessions;
- a Next.js 16 `proxy.ts` refreshes Supabase auth cookies but does not implement access control;
- the own minimal `public.profiles` anchor is ensured after authentication;
- existing authenticated sessions with a missing profile anchor expose a safe retry path;
- users can sign out;
- `/admin` remains a deliberate 404 even while authenticated;
- no real profile fields, product routes, social login, provider provisioning, or admin authorization are added.

## Read before changing anything

Inspect the selected 03A branch/current repository first. At minimum read:

1. root `AGENTS.md`;
2. `docs/development/codex-tooling.md`;
3. `docs/architecture/core-stack.md`;
4. `docs/architecture/system-design.md`;
5. `docs/development/database.md`;
6. `docs/development/getting-started.md`;
7. `docs/implementation/roadmap.md`;
8. `supabase/config.toml`;
9. `supabase/templates/magic_link.html`;
10. the 03A mobile auth README, gateways, session/controller behavior, return-destination sanitizer, tests, and integration script;
11. `apps/web/AGENTS.md`;
12. `apps/web/README.md`;
13. `apps/web/package.json`;
14. current public/admin App Router structure;
15. `apps/web/src/lib/config/public-env.ts`;
16. `apps/web/src/lib/supabase/browser.ts`;
17. `apps/web/src/lib/supabase/server.ts`;
18. current Sentry/common-state/shadcn code and tests;
19. `.github/workflows/validation.yml`.

The mobile implementation is not code to copy literally; it defines the cross-platform behavioral contract that the TypeScript/Next.js implementation should match.

## Required framework/provider guidance

### Next.js

The repository uses Next.js 16.3.4.

Follow `apps/web/AGENTS.md` and read the relevant version-matched documentation under:

```text
apps/web/node_modules/next/dist/docs/
```

before implementing Proxy, cookies, Server Components, redirects, or forms.

Do not install a redundant standalone Next.js best-practices skill.

### Codex skills

Preserve the tooling policy in `docs/development/codex-tooling.md`.

The persistent skills/plugins established by previous plans should remain installed:

- Dart/Flutter plugin;
- `supabase-postgres-best-practices`;
- broad official `supabase` skill from 03A;
- Vercel React best-practices skill;
- shadcn skill.

Inspect before reinstalling.

Use the broad Supabase skill for current Auth/SSR guidance, but repository security rules and this plan remain authoritative.

Do not install the full Vercel plugin or another generic auth/security bundle.

## Canonical 03A auth contract to preserve

03B must align with the reviewed mobile behavior:

- one `signInWithOtp` email flow for new and returning users;
- email is **trimmed only**; do not lowercase or otherwise rewrite its casing;
- the local passwordless template contains `{{ .Token }}` and no magic-login URL;
- verification uses email OTP type with exactly six digits;
- OTP/pending email are not persisted as durable application data;
- public browsing is not blocked by signed-out state;
- external/unsafe return destinations are rejected;
- Supabase Auth is the session source of truth;
- only the own skeletal profile anchor is ensured;
- only the expected `profiles_pkey` duplicate is idempotent success;
- unexpected profile-anchor failure keeps the valid auth session and exposes retry;
- logout ends the session but does not delete the account/profile;
- OTP, full email, tokens, and raw provider errors are not logged or sent to monitoring.

Do not change the shared Supabase template/rate-limit behavior merely for web convenience unless concrete integration evidence requires it.

## Architecture decisions for 03B

### 1. Keep auth public-first

`/` remains public.

Add a minimal public auth route:

```text
/auth
```

Do not make the root page or all public routes redirect to authentication.

There is no need to mirror mobile's separate `/auth/verify` route if doing so would require persisting the pending email. Prefer a single `/auth` client flow with request and verification steps kept in memory.

Refreshing the browser during OTP entry may return the user to email entry. That is acceptable.

Never put the OTP in the URL.

Do not put the full email in the URL merely to reconstruct verification state.

### 2. Client-side request/verify flow is appropriate here

Use the existing typed `createSupabaseBrowserClient()` for the interactive OTP request/verification flow.

A narrow auth adapter/controller/hook should isolate Supabase SDK calls from presentation code where useful.

Do not add Redux/Zustand/TanStack Query/SWR merely for this flow.

After successful `verifyOtp`, the `@supabase/ssr` browser client owns the cookie-backed session.

Then:

1. ensure the profile anchor;
2. clear pending in-memory auth flow state;
3. navigate to the safe return destination;
4. call `router.refresh()` so Server Components observe the new session.

### 3. Add Next.js 16 Proxy for token refresh, not authorization

03B is where cookie-backed SSR session refresh becomes real.

Implement the current Supabase SSR + Next.js 16 Proxy pattern using `proxy.ts` in the correct version-supported location.

The Proxy should:

- create a request-scoped Supabase server client from request cookies;
- call the current trusted token validation/refresh method recommended by Supabase (`getClaims()` at the time this prompt was written);
- propagate refreshed cookies to both the request and response as required by the current official pattern;
- exclude static/image/build assets through a current matcher where appropriate.

The Proxy must **not**:

- force authentication for public pages;
- decide product authorization;
- unlock `/admin`;
- use `getSession()` as a trusted server authorization check;
- use service-role credentials.

Follow current Supabase/Next.js documentation rather than old `middleware.ts` examples.

### 4. Server-side session reads use verified claims

Add a small server-only auth/session helper for Server Components.

Use the current Supabase trusted method for server authentication, currently `auth.getClaims()`.

Do not trust cookie contents directly.

Do not use `getSession()` to protect/read server-authenticated state.

Expose only the minimum app-owned identity/readiness result needed by the UI, such as:

- signed out;
- authenticated + profile ready;
- authenticated + profile anchor missing/retry needed.

Do not pass access tokens or raw claims into Client Components.

### 5. Preserve `/admin` fail-closed behavior

Authentication is not administration authorization.

Even with a valid authenticated session:

```text
/admin
```

must continue returning the existing true 404.

Do not add admin roles, claims, guards, dashboards, placeholders, or authenticated admin shells.

### 6. Profile-anchor readiness is part of authenticated state

After OTP verification, ensure the authenticated user's `public.profiles` row using current RLS.

Use an INSERT of the own `id`.

Do not use an UPDATE-requiring upsert.

Treat only a `23505` duplicate specifically attributable to `profiles_pkey` as successful idempotence.

Do not swallow unrelated PostgREST errors.

For a restored web session where the profile anchor is absent:

- still recognize the user as authenticated;
- render a minimal safe "complete session setup"/retry action;
- do not mutate the database automatically during Server Component render;
- the retry action may use the browser client to ensure the anchor and refresh the page.

Do not add profile fields.

### 7. Safe return destinations

Support optional:

```text
/auth?returnTo=/...
```

Create/reuse a pure TypeScript sanitizer with behavior aligned to mobile:

- internal absolute-path destinations only;
- reject protocol-relative paths;
- reject URLs with schemes/authorities;
- reject backslashes;
- reject auth-loop destinations such as `/auth`;
- fallback `/`.

Do not allow open redirects.

The return destination may live in component memory after parsing; it is not sensitive.

### 8. Request/verification UX

Request step:

- trim email, preserve casing;
- validate basic shape;
- prevent duplicate submit;
- call `signInWithOtp({ email, options: { shouldCreateUser: true } })`;
- no `emailRedirectTo`;
- move to code entry after success.

Verification step:

- exactly six digits;
- support paste/browser `autocomplete="one-time-code"` where appropriate;
- show only a masked destination email;
- prevent duplicate submit;
- call `verifyOtp({ email, token, type: "email" })`;
- ensure profile anchor after success.

Resend:

- retain the 30-second UI-only cooldown used by mobile for behavioral consistency;
- backend rate limits remain authoritative;
- preserve the pending email/return destination on recoverable failures.

Use shadcn's existing foundation components; do not introduce final design.

### 9. Sign out

Provide a minimal sign-out affordance when the server recognizes an authenticated session.

Use the browser Supabase client or a current simple server action if current Next.js/Supabase docs make that materially cleaner.

After successful sign-out:

- cookies/session are cleared by Supabase;
- `router.refresh()`/navigation updates server-rendered state;
- `/` remains available;
- `/admin` remains 404.

Do not delete profile/Auth records.

### 10. Monitoring/privacy

Do not call `Sentry.setUser()` with email/user identity in 03B.

Do not record:

- OTPs;
- full email addresses;
- access/refresh tokens;
- cookie contents;
- raw Supabase error bodies.

Expected invalid OTP/email mistakes should remain safe UI errors, not noisy exception telemetry.

Unexpected operational failures may use existing privacy-safe monitoring only after sanitization.

## Required work

### A. Web auth feature boundary

Add a restrained feature area, likely under:

```text
apps/web/src/features/auth/
```

or an equally clear current convention.

Likely responsibilities:

- pure auth models/failure mapping;
- return-destination sanitizer;
- client-only Supabase auth/profile gateway;
- OTP flow component/controller/hook;
- server-only current-auth/profile-readiness helper;
- minimal sign-in/status/sign-out/retry UI.

Do not create generic repositories/use-cases without concrete need.

### B. Update the server Supabase factory if current docs require it

The existing 02B server client writes cookies directly through `cookies().set`.

Reconcile it with current Supabase SSR docs for use from Server Components:

- request-scoped client only;
- safe cookie `getAll`/`setAll`;
- if current docs require ignoring cookie writes from Server Component contexts because Proxy handles refresh, implement that exact supported behavior;
- do not broadly hide unrelated exceptions.

Keep server/client import boundaries enforced with `server-only`/`client-only`.

### C. Proxy/session refresh

Implement and test the current Proxy session-refresh helper.

Keep auth refresh logic isolated from product authorization so later feature guards can depend on verified session helpers rather than editing Proxy into a giant route policy engine.

### D. `/auth` route

Create a public server page that:

- sanitizes `returnTo`;
- detects an already authenticated/ready session and safely redirects to `returnTo` or `/`;
- renders the client OTP flow otherwise;
- does not require Supabase config at global build import time beyond the already-established environment behavior.

If the user is authenticated but profile anchor is missing, present retry rather than a new OTP form.

### E. Root public auth status

Update the neutral public foundation page only enough to expose:

Signed out:

- Sign in link.

Authenticated and ready:

- generic "Signed in" state;
- Sign out.

Authenticated but anchor missing:

- generic authenticated/setup-retry state;
- retry anchor setup;
- sign out.

Do not display full email/name/profile data.

Do not add final account/settings navigation.

### F. Tests

Add focused web tests.

#### Pure/unit tests

Cover:

- email trim preserves casing;
- invalid email;
- safe return destination;
- external/protocol-relative/backslash/auth-loop rejection;
- six-digit token validation;
- safe failure mapping;
- expected `profiles_pkey` duplicate classification;
- unrelated DB error propagation;
- profile-readiness mapping from claims/profile query.

#### Component tests

Cover:

- signed-out request form;
- request success transitions to code entry;
- masked email preserves casing without revealing full address;
- duplicate submit prevention;
- invalid code stays in verification;
- resend cooldown;
- verification success calls anchor ensure and safe navigation/refresh;
- profile ensure unexpected failure keeps authenticated/retry state;
- sign-out;
- raw backend errors/OTP/full email are not rendered.

Use dependency injection/test doubles around the web Auth gateway; do not require jsdom tests to talk to a live Supabase instance.

#### Server/session tests

Cover the server auth helper with mocked Supabase claims/profile responses.

Ensure the implementation uses verified claims rather than `getSession()` for trusted server auth state.

Test Proxy/session-refresh behavior at the smallest reliable level supported by the current Next.js setup.

### G. Local integration / HTTP smoke

The 03A branch already has a deterministic local Supabase + Mailpit OTP integration check.

Extend automation only where it adds real web evidence.

Prefer adding a focused web-session integration that can:

1. request/read/verify a local OTP using supported Supabase APIs;
2. obtain cookie state through supported `@supabase/ssr` behavior rather than manually inventing cookie encoding;
3. request the built/running Next.js `/` with that session and verify the server sees an authenticated user;
4. confirm `/admin` still returns 404 while authenticated.

If this can be done deterministically without Playwright/browser UI automation, add it to CI.

Do not add Playwright solely for this foundation auth check.

If current libraries make the cookie integration brittle, keep the existing real Supabase OTP integration plus strong unit/server tests and document the remaining manual browser check. Do not reverse-engineer internal cookie formats.

### H. CI

Keep Mobile and Database validation green.

Web validation must continue including:

- unit/component tests;
- ESLint;
- Next route type generation/TypeScript;
- production build;
- existing HTTP smoke.

Add auth/session integration evidence if implemented.

Remember that 03B is stacked on 03A while QA is pending. The final validation that matters for merge must be rerun **after rebasing/retargeting onto merged `main`**.

### I. Documentation

Update web/development docs with:

- numeric email OTP flow;
- same template/OTP contract as mobile;
- memory-only pending email/code state;
- cookie-backed SSR sessions;
- Proxy's refresh-only responsibility;
- `getClaims()`/trusted server session rule;
- profile-anchor readiness/retry;
- public-first behavior;
- safe return destination;
- sign out;
- explicit `/admin` 404 boundary;
- no magic links/deep links/social providers.

Do not duplicate external Supabase/Next.js skill content.

### J. Roadmap handling for a stacked PR

While PR #7 remains open:

- parent 03 → `In progress`;
- 03A → `In progress`;
- 03B → `In progress`;
- 03C → `Blocked`;
- plan 04 → `Not started`.

Do **not** call 03A implemented merely because 03B is based on it.

After PR #7 merges and before 03B is retargeted to `main`:

- 03A → `Implemented`;
- 03B remains `In progress`;
- parent 03 remains `In progress`;
- 03C remains `Blocked`.

Document the stacked-PR workflow concisely if needed so the temporary dual-"in progress" state is understandable.

## Non-goals

Do not implement:

- profile fields/onboarding;
- competence/interests/preferences taxonomy;
- public user profiles;
- mobile changes unrelated to a 03A rebase/final compatibility fix;
- magic links;
- deep links;
- Google/Apple/social login;
- passwords;
- MFA;
- password recovery/email change;
- admin authorization/roles;
- functional `/admin`;
- proposal/discovery/join flows;
- service-role Supabase clients;
- database migrations/grant changes;
- Auth signup triggers;
- hosted SMTP/provider setup;
- Vercel deployment;
- analytics;
- final visual design;
- Playwright unless concrete web-auth evidence genuinely requires it.

## Edge cases

### 03A changes during native QA

Rebase 03B onto the final 03A branch before retargeting.

If the behavior changes materially, update the web contract and tests rather than keeping divergence.

### Browser refresh during code entry

Returning to the email-request step is acceptable. Do not persist OTP values or add email-in-URL solely to survive refresh.

### Authenticated session, missing profile anchor

Remain authenticated; expose retry. Do not redirect to OTP again.

### Expired session

Proxy/session validation should naturally return the server view to signed-out state.

### Authenticated `/admin`

Still 404.

### Email casing

Preserve all casing after trimming exactly as the corrected 03A implementation does.

## Acceptance criteria

03B is ready for final review when:

- [ ] it is initially based on the latest 03A branch, not stale `main`;
- [ ] stacked PR targets `codex/03a-mobile-email-otp-auth` while PR #7 remains open;
- [ ] existing Codex skills are reused without redundant broad installs;
- [ ] `/` remains public;
- [ ] `/auth` implements in-memory two-step numeric email OTP;
- [ ] email is trimmed but casing preserved;
- [ ] no magic link/email redirect is used;
- [ ] six-digit verification uses type `email`;
- [ ] safe internal `returnTo` prevents open redirects/auth loops;
- [ ] browser verification establishes the Supabase SSR cookie session;
- [ ] Next.js 16 Proxy refreshes/validates session cookies using current official guidance;
- [ ] trusted Server Component auth reads use `getClaims()` or the current official equivalent, not `getSession()`;
- [ ] `/admin` remains 404 for signed-out and signed-in users;
- [ ] profile anchor is ensured with own-ID INSERT and narrow duplicate classification;
- [ ] restored authenticated sessions detect missing profile anchor and expose retry;
- [ ] logout works without deleting account/profile;
- [ ] no OTP/full email/token/cookie/raw backend error leaks to UI/logs/Sentry;
- [ ] web Auth unit/component/server tests pass;
- [ ] local web session integration is automated if it can be done through supported APIs without brittle cookie reverse engineering;
- [ ] existing Mobile/Database validation remains green;
- [ ] no schema/profile/product/admin scope leaks into 03B;
- [ ] 03C remains blocked;
- [ ] 03B is not merged before 03A;
- [ ] after 03A merges, 03B is rebased/retargeted to `main` and the full suite is rerun.

## Autonomy and stop conditions

Decide ordinary React component names, feature subfolders, client hook/controller organization, error copy, and minimal test seams autonomously.

You may decide:

- exact `/auth` component structure;
- whether sign-out is browser-client based or a small current-pattern Server Action;
- exact Proxy helper module layout;
- exact supported matcher;
- exact deterministic integration strategy.

Stop and report before:

- changing the numeric OTP contract;
- persisting OTPs/full email as durable app state;
- using open redirects;
- trusting server `getSession()` for authorization/session identity;
- exposing authenticated `/admin`;
- adding profile fields or competence taxonomy;
- changing database grants/RLS;
- adding social login/deep links;
- installing full Vercel/generic auth packs;
- merging 03B before 03A;
- absorbing 03C or plan 04.

## Deliverables

Produce:

1. web Auth feature boundary;
2. in-memory request/verify OTP UI;
3. safe return-destination logic;
4. cookie-backed Supabase SSR session behavior;
5. Next.js 16 Proxy session refresh;
6. trusted server current-auth/profile-readiness helper;
7. profile-anchor ensure/retry;
8. sign-out;
9. minimal root auth status;
10. focused tests;
11. deterministic web-session integration if supported cleanly;
12. documentation/roadmap updates;
13. stacked PR against `codex/03a-mobile-email-otp-auth`;
14. completion report.

Do not merge the PR.

## Completion report

Return:

1. **Summary**
2. **Branch/base/stacked PR status**
3. **Changed areas/files**
4. **Codex skills/guidance used**
5. **Web Auth architecture**
6. **OTP request/verification behavior**
7. **Email casing and pending-state behavior**
8. **Proxy/session refresh**
9. **Trusted server session state**
10. **Profile-anchor readiness/retry**
11. **Return destination**
12. **Sign-out**
13. **Admin fail-closed verification**
14. **Privacy/error handling**
15. **Tests**
16. **Local web Auth/session integration evidence**
17. **Validation and CI**
18. **Manual/external setup**
19. **03A rebase/retarget work still required**
20. **Deferred 03C founder decisions**
21. **Pull request/commit reference**

Do not report 03A or parent plan 03 as implemented while PR #7 remains unmerged.
