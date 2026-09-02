# PLANETS 02B — Web/Admin Application Foundation

**Roadmap parent:** PLANETS 02 — Mobile and web application foundations  
**Task type:** Second and final portion of roadmap plan 02  
**Repository:** `lillo24/planets.community`  
**Target base:** latest `main`  
**Verified prerequisite:** PLANETS 02A / PR #5 merged as `ce32b551f6674d107163aed976d5f291889cd9af`

## Objective

Replace the neutral Next.js bootstrap with a stable public-web/admin foundation that later plans can extend without redesigning route boundaries, server/client responsibilities, environment configuration, Supabase client creation, common UI states, component-library usage, testing, or monitoring.

After this task, the web application should have:

- clearly separated public and admin route areas;
- server components as the default rendering model;
- typed local/staging/production public configuration;
- current Supabase browser/server client factories using the publishable key;
- shadcn/ui initialized with a small neutral foundation;
- optional privacy-safe Sentry error monitoring;
- common loading/empty/error UI;
- focused web unit/component tests integrated into CI;
- no authentication, admin authorization, product behavior, or deployment.

After 02B is merged, parent roadmap plan 02 is complete and plan 03 may begin.

## Read before changing anything

Inspect current `main`, Git status, dependency graph, and generated Next.js agent guidance first.

At minimum read:

1. root `AGENTS.md`;
2. `docs/development/codex-tooling.md`;
3. `docs/architecture/core-stack.md`;
4. `docs/architecture/system-design.md`;
5. `docs/implementation/roadmap.md`;
6. `docs/development/getting-started.md`;
7. `docs/development/database.md`;
8. `apps/web/AGENTS.md`;
9. `apps/web/package.json`;
10. `apps/web/next.config.ts`;
11. `apps/web/tsconfig.json`;
12. `apps/web/src/app/*`;
13. `apps/web/src/types/database.generated.ts`;
14. root `package.json`;
15. `.github/workflows/validation.yml`;
16. relevant merged migrations/tests only as needed to understand the existing public API boundary;
17. the merged 02A mobile configuration/tooling only where shared local-development behavior can be reused safely.

### Next.js version-matched guidance is required

This repository uses Next.js 16.3.4.

`apps/web/AGENTS.md` explicitly instructs coding agents to consult the version-matched documentation shipped under the installed Next.js package, because APIs/conventions may differ from training data.

Before implementing each substantial Next.js concern, read the relevant current files under:

```text
apps/web/node_modules/next/dist/docs/
```

Do not replace that with remembered Next.js patterns or an old generic Next.js skill.

If `next dev` updates its generated agent files, preserve the generated/current form rather than manually fighting it.

## Current implementation evidence

At the verified base:

- plans 00, 01, and 02A are merged;
- parent plan 02 is still incomplete because 02B remains;
- Next.js 16.3.4, React 19.2.8, TypeScript, Tailwind CSS 4, and ESLint are installed;
- the web app still contains only the original neutral root page/layout;
- no public/admin route groups exist;
- no shadcn `components.json` exists;
- no React-specific PLANETS component library exists;
- no Supabase JavaScript/SSR package exists;
- no web Supabase client exists;
- no web environment contract exists;
- no `@sentry/nextjs` integration exists;
- no web unit/component test framework exists;
- the database-generated `public` TypeScript type file already exists and contains the skeletal `profiles` API type;
- no authentication flow, session proxy, admin role, or product page exists.

Current relevant stable provider packages when this plan was prepared include approximately:

- `@supabase/ssr` 0.12.5;
- `@supabase/supabase-js` 2.112.4;
- `@sentry/nextjs` 10.73.0.

Resolve current stable compatible releases during implementation and record exact installed versions. Do not use prerelease versions merely because they are newer.

## Codex skills/plugins for this task

External skills remain supplementary. Preserve the authority order already recorded in `docs/development/codex-tooling.md`:

1. current repository code/configuration/tests;
2. PLANETS `AGENTS.md` and accepted architecture/ADRs;
3. this active implementation plan;
4. external skills/plugins and their generic examples.

Do not vendor generic skill contents or paste them into PLANETS documentation.

### 1. Keep existing persistent core tooling

Inspect the current Codex setup before adding anything.

The following should already exist from 02A:

- official `dart-flutter` plugin;
- official `supabase-postgres-best-practices` skill.

Do not reinstall them blindly and do not uninstall them after this web task.

The Postgres skill may be largely inactive in 02B because no database changes are expected.

### 2. Install and retain Vercel Engineering's narrow React skill

Inspect global skills first. If it is missing, install only the official Vercel Engineering React/Next.js performance skill globally for Codex:

```text
npx skills add vercel-labs/agent-skills --skill react-best-practices -g -a codex -y
```

Keep it installed for later PLANETS React/Next.js work.

Use it for React composition, rendering, bundle, data-fetching, and performance guidance where applicable.

It does **not** override:

- the Next.js 16.3 bundled docs;
- PLANETS' server/client/backend boundaries;
- product scope;
- security requirements.

Do not install the broad Vercel plugin.

### 3. Do not install a standalone Next.js best-practices skill

Next.js moved general framework knowledge into version-matched bundled docs and generated agent rules for Next.js 16.3+.

Therefore:

- use `apps/web/AGENTS.md`;
- use `node_modules/next/dist/docs/`;
- do not add an old `next-best-practices` skill;
- do not install the full Vercel plugin merely to obtain its `nextjs` skill.

Workflow-specific Next.js skills may be reconsidered later only if a future task actually uses the feature they target, such as Cache Components adoption/optimization.

### 4. Establish shadcn, then install and retain its official skill

shadcn/ui is an accepted PLANETS web component foundation and Tailwind is already present.

First initialize shadcn in the existing `apps/web` application using the current stable CLI and npm, after inspecting what the CLI will change.

Use the current official default foundation unless the repository or CLI exposes a concrete incompatibility. As of this plan, the shadcn CLI defaults/recommends Base UI for new setups and the default preset is a neutral foundation rather than PLANETS branding.

Do not choose a custom visual preset or community registry.

Once `components.json` exists and shadcn is actually established, inspect global skills and install the official shadcn skill globally for Codex if missing:

```text
npx skills add shadcn/ui --skill shadcn -g -a codex -y
```

Keep it installed while shadcn remains part of PLANETS.

Before adding/using a shadcn component:

1. run `npx shadcn@latest info --json`;
2. inspect installed components;
3. use `npx shadcn@latest docs <component>` for current component APIs;
4. use dry-run/diff when adding or updating where useful.

Add only components actually needed by the foundation. Likely candidates include a small subset such as Button, Alert, Empty, Spinner/Skeleton, but follow current shadcn docs rather than this illustrative list.

Do not install blocks, dashboards, auth forms, community registries, or large component sets.

### 5. Do not add the broad Supabase skill merely for SSR guidance

The currently installed `supabase-postgres-best-practices` skill remains useful for database/RLS work, but it is not an SSR integration guide.

For this task, consult **current official Supabase documentation** for `@supabase/ssr` and Next.js rather than permanently installing the broad Supabase skill solely for one integration concern.

This avoids making every future Supabase-related prompt load a broad provider skill when PLANETS already has detailed database guardrails.

If a later sequence repeatedly needs Supabase Auth/Realtime/Storage/provider guidance, reevaluate the broad official skill based on measured usefulness.

## External context and accounts

No Google Doc or cloud-provider account is required.

Do not create, link, authenticate, or provision:

- a remote Supabase project;
- Vercel;
- Sentry;
- Cloudflare;
- Resend;
- PostHog;
- Firebase;
- Apple/Google resources.

Do not run the Sentry wizard because it requests account/project interaction and scaffolds deployment/source-map concerns outside 02B.

No production or staging credentials are required.

## Decisions already made

### 1. Server Components are the default

Use the Next.js App Router as documented by the installed Next.js version.

Prefer Server Components by default.

Add `"use client"` only for components that genuinely require browser state, event handlers, effects, or client-only SDK behavior.

Do not turn layouts/pages into Client Components merely to access shared UI.

Keep data access close to server surfaces when browser interactivity does not require otherwise.

### 2. Public and admin routes are structurally separate

Create clear route ownership, for example using route groups:

```text
src/app/
  (public)/
  (admin)/
```

The public `/` route remains a minimal semantic PLANETS web foundation, not a finished marketing website.

Reserve `/admin` under the admin route area, but **fail closed** because authentication/authorization does not exist yet.

Do not expose a functional admin interface or any database data.

A request to `/admin` should return an intentionally inaccessible result, preferably `notFound()` or an equivalently non-sensitive disabled route, until the later moderation/admin plan establishes authorization.

This is not an admin-auth implementation.

### 3. Next.js is not a second domain backend

Server Components, Route Handlers, and Server Actions may eventually call canonical Supabase operations, but they must not create web-only versions of PLANETS domain rules.

02B introduces no domain mutations.

Do not add a custom REST/API layer.

Do not add secret/service-role credentials.

### 4. Web public environment contract

Use explicit client-safe variables:

```text
NEXT_PUBLIC_APP_ENV
NEXT_PUBLIC_SUPABASE_URL
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY
NEXT_PUBLIC_SENTRY_DSN
```

`NEXT_PUBLIC_APP_ENV` supports exactly:

- `local`;
- `staging`;
- `production`.

Use current Supabase publishable-key terminology.

Never introduce a `NEXT_PUBLIC_` secret/service-role key.

The Sentry DSN is not a secret and can use the public variable on browser and server initialization. Source-map auth tokens are deferred.

Create a small pure typed parser/validator for these values.

Validation should mirror the useful 02A principles:

- environment must be recognized;
- Supabase URL must be absolute HTTP(S);
- local may use HTTP;
- staging/production require HTTPS;
- publishable key must be non-empty;
- Sentry DSN may be empty/disabled;
- a non-empty DSN must be a valid supported URL;
- diagnostic representations must not expose the full publishable key/DSN.

Do not invent unused server-secret env variables.

### 5. Environment validation is explicit but does not break unrelated builds

Because no page in 02B needs to query Supabase, do not make the entire Next.js build depend on a real backend merely by importing a throwing environment parser globally.

Client factories should validate when configuration is used.

Sentry is optional and must remain disabled without a DSN.

Commit an example environment file and ignore real local files.

CI may use deterministic fake/test values where a test needs valid configuration; it must not require a cloud project.

### 6. Use current Supabase SSR clients without implementing Auth yet

Install current stable:

- `@supabase/supabase-js`;
- `@supabase/ssr`.

Use the already-generated `Database` TypeScript type.

Establish two deliberate factories:

- browser client using current `createBrowserClient`;
- server/request client using current `createServerClient` and Next.js cookie APIs.

Follow the current Supabase Next.js SSR docs at implementation time.

Do not use deprecated `@supabase/auth-helpers-*`.

Do not create a module-level mutable server client shared across requests.

Do not query `profiles` or any product table merely to prove the client works.

Do not add:

- login/signup;
- `proxy.ts` session refresh;
- auth redirects;
- `getUser`/`getClaims` route guards;
- profile creation;
- service-role clients.

Those belong to plan 03 or later.

The purpose is to establish the correct factories/boundaries now so plan 03 does not need to replace an ad-hoc client setup.

### 7. Initialize shadcn as neutral infrastructure, not final design

Use shadcn's current default supported primitive library and CSS-variable setup.

Treat all generated theme values as provisional foundation values.

Do not add:

- custom fonts;
- PLANETS brand colors;
- illustrations;
- complex animation;
- custom design presets;
- dashboard templates.

Prefer semantic shadcn/Tailwind tokens rather than raw colors in reusable foundation components.

### 8. Sentry is manual, optional, and privacy-restrained

Install current stable `@sentry/nextjs` manually.

Use the current Next.js 16/Sentry-supported instrumentation files and hooks after checking current docs.

Do not run the Sentry wizard.

When `NEXT_PUBLIC_SENTRY_DSN` is empty:

- browser/server/edge monitoring is disabled;
- the application builds and runs normally.

When enabled, foundation defaults must avoid unnecessary collection:

- `sendDefaultPii` false;
- no user identity/email;
- tracing/performance sampling disabled;
- session replay disabled/not installed;
- profiling disabled;
- no source-map upload;
- no `SENTRY_AUTH_TOKEN`;
- no tunnel route;
- no synthetic startup/test event;
- no auth tokens/cookies/request bodies intentionally attached.

Use current supported Sentry options rather than copying old config filenames from memory.

If a global error boundary reports an exception, render safe user-facing copy and never print raw exception details.

Do not let an unavailable DSN/project make the web app fail.

### 9. Common web states use the established component foundation

Provide small reusable loading, empty, and recoverable-error components.

Use shadcn components where they fit rather than recreating base controls.

Requirements:

- accessible semantic markup;
- visible loading semantics;
- safe error copy;
- no raw stack/exception text;
- optional retry interaction where meaningful;
- no universal result/error framework.

### 10. No internationalization framework yet

02A established Flutter localization.

Do not introduce a Next.js i18n library in 02B merely for symmetry.

The public website has no settled multilingual product requirement yet. Keep user-facing foundation copy centralized/simple enough to migrate later.

## Required work

### A. Codex tooling verification

Before application edits:

1. inspect installed Codex plugins/skills;
2. confirm persistent 02A tools remain;
3. install `react-best-practices` globally if missing;
4. do not install a Next.js skill/full Vercel plugin;
5. initialize shadcn;
6. after shadcn exists, install its official skill globally if missing;
7. update `docs/development/codex-tooling.md` only with concise status/policy information, not copied skill rules.

The completion report must distinguish already-installed versus newly installed tools.

### B. Web dependencies

Install stable compatible dependencies required by the implementation, expected to include:

- `@supabase/supabase-js`;
- `@supabase/ssr`;
- `@sentry/nextjs`;
- shadcn-generated dependencies for the chosen minimal components.

Add a focused web test stack only as needed. Prefer a small conventional setup such as Vitest + React Testing Library/jsdom rather than inventing custom test infrastructure.

Do not add a client state-management library. No web product state exists yet.

Do not add SWR/TanStack Query merely because a generic React skill mentions client fetching.

### C. shadcn initialization

Initialize shadcn inside the existing `apps/web` application, preserving:

- npm/root workspace behavior;
- existing Tailwind CSS 4 setup where compatible;
- `@/*` alias;
- Next.js App Router;
- neutral/provisional theme.

Commit `components.json` and generated source required by actually used components.

Use `npx shadcn@latest info --json` after initialization and record the resolved:

- primitive library;
- preset/base;
- icon library;
- aliases;
- installed foundation components.

Do not add a large library of unused components.

### D. Route/application structure

Move the neutral public root into the new public route area without changing `/`.

Create the admin route boundary and make `/admin` fail closed.

Add appropriate safe Next.js application-state files where useful:

- root/public `not-found`;
- global/segment error boundary;
- loading state.

Keep metadata generic and accurate. Do not write marketing claims or final SEO copy.

### E. Environment module and local web config

Create a pure typed environment parser plus the small runtime adapters needed for server/browser factories.

Commit an example environment file.

Add an ignored local-development workflow.

Prefer extending/reusing the existing local Supabase status tooling from 02A rather than creating inconsistent parsing rules.

Provide a root command equivalent to:

```text
npm run web:config:local
```

that generates `apps/web/.env.local` from the running local Supabase status, with:

```text
NEXT_PUBLIC_APP_ENV=local
NEXT_PUBLIC_SUPABASE_URL=<local API URL>
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=<local publishable/legacy anon fallback from CLI>
NEXT_PUBLIC_SENTRY_DSN=
```

Do not print the full key.

For web development on the same computer, use the normal loopback address; do not apply the Android `10.0.2.2` rewrite.

If reusing the mobile helper cleanly requires extracting shared parsing code, preserve mobile behavior and add tests/validation rather than rewriting it casually.

### F. Supabase browser/server factories

Implement typed factories in a clear web-owned area such as:

```text
src/lib/supabase/
```

or another convention supported by the current repo.

Browser factory:

- uses current `@supabase/ssr` browser API;
- uses client-safe validated environment;
- is usable from Client Components later;
- uses `Database` generic types.

Server factory:

- is server-only;
- creates a client per request/context rather than a shared global;
- uses current Next.js cookie APIs and current `@supabase/ssr` signatures;
- uses the publishable key;
- uses `Database` types.

Do not create Proxy/middleware/session refresh yet.

Do not query data in the foundation pages.

### G. Sentry integration

Configure the current stable SDK manually according to current Next.js 16 guidance.

Implement the runtime files required for supported browser/server error monitoring.

Use a small shared privacy-safe option builder when doing so meaningfully reduces drift between runtime configs; do not create abstraction for its own sake.

Add a safe global error UI that reports through Sentry only when configured.

Do not configure source-map uploads or provider credentials.

Do not add Sentry example/test routes.

### H. Common UI states

Add the minimal shadcn components needed, consulting the installed shadcn skill/CLI docs before each addition.

Build reusable PLANETS foundation wrappers for:

- loading;
- empty;
- recoverable error.

Keep them simple and semantic.

Do not add dashboard/sidebar/data-table/form infrastructure before a real feature requires it.

### I. Tests

Add focused automated web tests for actual foundation behavior.

At minimum cover:

#### Environment

- local/staging/production parsing;
- unknown environment rejection;
- missing/blank Supabase values;
- HTTP allowed only for local;
- HTTPS required outside local;
- optional empty Sentry DSN;
- invalid DSN rejection;
- safe/redacted diagnostic representation.

#### Supabase boundary

Without making a real network request:

- browser client factory consumes the validated public config;
- server factory is not a browser import;
- no secret/service-role environment key is referenced;
- generated `Database` type remains part of the client typing.

Use dependency seams/mocks only where they make the tests clearer; do not build a generic client factory framework.

#### Routes/states

- public foundation content renders safely;
- common loading/empty/error states render with accessible roles/text;
- error state does not expose raw exception text;
- retry control works where implemented;
- admin access remains fail-closed.

For admin route behavior, a build/server smoke test is acceptable if unit testing the Next.js `notFound()` boundary would be artificial.

Do not add fake production data.

### J. Validation and CI

Preserve existing Mobile and Database jobs unchanged unless a shared script refactor requires a compatible update.

Extend web validation to run new tests.

A clean web validation path should include:

```text
npm ci
npm run lint --workspace @planets/web
npm run typecheck --workspace @planets/web
npm run test --workspace @planets/web
npm run build --workspace @planets/web
```

or equivalent root commands.

If the build does not require real Supabase config because no factory is invoked by a page, keep it credential-free.

If deterministic environment values are needed for tests/build instrumentation, use non-secret local/test values in CI rather than cloud credentials.

Perform an HTTP smoke check of the built application when practical:

- `/` succeeds;
- `/admin` is intentionally inaccessible;
- an unknown route uses the safe not-found behavior.

Do not introduce Vercel deployment CI.

### K. Documentation and roadmap

Update web/development documentation covering:

- route ownership;
- Server Component default;
- client-component rule;
- environment variables;
- local `.env.local` generation;
- Supabase browser/server factories;
- explicit absence of auth/proxy behavior;
- shadcn CLI/skill workflow;
- Sentry-disabled-by-default/privacy behavior;
- test commands.

Update `docs/development/codex-tooling.md` to record:

- React skill now persistent;
- Next.js bundled docs remain the framework source;
- shadcn skill now persistent after initialization;
- full Vercel plugin still deferred.

Update roadmap status within the open PR:

- parent 01 → `Implemented`;
- 02A → `Implemented`;
- 02B → `In progress`;
- parent 02 → `In progress`;
- plan 03 remains `Not started`.

Do **not** mark parent 02 implemented until this PR is actually merged.

## Non-goals

Do not implement:

- email OTP/login/signup/logout;
- session refresh Proxy/middleware;
- route guards based on Supabase Auth;
- profile creation/editing;
- public profiles;
- competences/preferences;
- proposals/discovery;
- participation;
- notifications;
- chat;
- Storage/Realtime;
- database migrations or grants;
- admin roles/authorization/moderation;
- functional admin pages;
- service-role/secret Supabase clients;
- Server Actions/domain mutations;
- custom REST APIs;
- Vercel provisioning/deployment;
- the full Vercel plugin;
- PostHog;
- Resend;
- final website copy/SEO strategy;
- final visual branding;
- custom fonts/illustrations;
- large shadcn blocks/component sets;
- client state/query libraries without a concrete feature;
- a web i18n framework;
- Playwright merely to test placeholder content if the existing test/build/smoke evidence is sufficient.

## Edge cases and failure behavior

### Missing `.env.local`

The neutral website can still build if it does not instantiate Supabase.

Any code path requesting a Supabase client must fail with clear configuration guidance rather than constructing a malformed client.

Do not silently select production values.

### Local Supabase unavailable

`web:config:local` should fail with an actionable message instructing the developer to start Docker/local Supabase.

Do not modify Docker or expose Supabase publicly.

### Browser/server import leakage

Prevent accidental import of server-only Supabase utilities into client bundles using current Next.js-supported conventions.

Do not rely only on comments.

### Admin route

Until authorization exists, fail closed.

Do not make a public placeholder dashboard that later developers might mistake for secured admin behavior.

### Sentry disabled or invalid

An empty DSN is a valid disabled state.

A malformed non-empty DSN should fail validation in focused configuration code, not cause a mysterious runtime failure.

No Sentry service should be required for CI.

### shadcn upstream changes

Use `npx shadcn@latest info/docs/dry-run/diff`; do not fetch raw component source manually.

Do not overwrite local component changes without inspecting diffs.

## Acceptance criteria

02B is ready for merge when:

- [ ] current Codex plugin/skill state was inspected;
- [ ] Vercel Engineering `react-best-practices` is globally installed for Codex if it was missing;
- [ ] no standalone Next.js best-practices skill/full Vercel plugin was installed;
- [ ] shadcn is initialized in `apps/web`;
- [ ] official shadcn skill is globally installed after initialization if it was missing;
- [ ] `docs/development/codex-tooling.md` records the concise updated policy/status without copied generic skill content;
- [ ] public and admin route ownership are structurally separated;
- [ ] `/` remains a neutral working public foundation;
- [ ] `/admin` fails closed with no sensitive/admin functionality;
- [ ] Server Components remain the default;
- [ ] typed web environment validation exists;
- [ ] local/staging/production Supabase URL rules are enforced;
- [ ] publishable key is the only Supabase key permitted in public web configuration;
- [ ] real `.env.local` is ignored and an example is committed;
- [ ] local web config can be generated from local Supabase without printing the key;
- [ ] `@supabase/ssr` and `@supabase/supabase-js` are installed at stable compatible versions;
- [ ] typed browser and per-request server Supabase factories exist;
- [ ] no Auth proxy/session refresh/query/product behavior exists;
- [ ] shadcn uses a neutral/default foundation with only actually needed components;
- [ ] Sentry Next.js is manually integrated without requiring an account;
- [ ] empty DSN cleanly disables Sentry;
- [ ] PII/tracing/replay/profiling/source-map upload are not enabled by default;
- [ ] common loading/empty/error UI exists and is accessible;
- [ ] focused web tests cover configuration and common-state behavior;
- [ ] web lint/typecheck/tests/build pass;
- [ ] HTTP smoke verifies public success and admin fail-closed behavior when practical;
- [ ] Mobile and Database CI remain green;
- [ ] no database/product/auth/admin implementation leaked into 02B;
- [ ] 02A is recorded implemented and 02B in progress within the PR;
- [ ] parent plan 02 remains in progress until merge.

## Autonomy and stop conditions

Decide ordinary file names, test framework details, exact minimal shadcn component selection, and small component composition autonomously.

You may decide:

- exact route-group folder names;
- exact environment parser module names;
- exact Supabase utility paths;
- Vitest/testing-library details if used;
- exact current shadcn default resolved by the CLI;
- exact neutral foundation components;
- exact Sentry runtime config filenames required by current SDK/Next.js docs;
- whether a small shared local-Supabase script refactor is cleaner than duplicating parsing.

Stop and report before:

- installing the full Vercel plugin;
- installing an old/redundant Next.js guidance skill;
- installing broad generic skill packs;
- choosing a custom shadcn visual preset/registry with product-design implications;
- exposing a functional unauthenticated `/admin`;
- adding service-role/secret keys;
- implementing auth/proxy/session behavior;
- making database changes;
- allowing skill guidance to override PLANETS boundaries;
- requiring a cloud account;
- introducing a second web backend;
- absorbing plan 03.

## Deliverables

Produce:

1. verified web-relevant Codex skill setup;
2. shadcn initialization and minimal used components;
3. public/admin route structure;
4. typed web environment configuration and examples;
5. local web Supabase config tooling;
6. typed Supabase browser/server factories;
7. privacy-safe optional Sentry Next.js integration;
8. common loading/empty/error UI;
9. focused automated web tests;
10. CI/check updates;
11. web/development/Codex-tooling documentation;
12. roadmap update;
13. focused pull request, preferably on a branch similar to `codex/02b-web-admin-foundation`;
14. completion report.

Do not merge the pull request yourself unless explicitly instructed by the active execution environment.

## Completion report

Return:

1. **Summary**
2. **Changed areas/files**
3. **Codex skills/plugins**
   - existing;
   - newly installed;
   - deliberately deferred;
   - any guidance conflicts resolved in favor of PLANETS/Next.js bundled docs;
4. **Resolved package versions**
5. **shadcn foundation**
   - resolved primitive library/preset;
   - installed components;
   - `components.json` choices;
6. **Route structure**
   - public;
   - admin fail-closed behavior;
7. **Environment/config**
   - variables;
   - validation;
   - local generation workflow;
8. **Supabase web clients**
   - browser;
   - server;
   - explicit Auth behavior deferred;
9. **Sentry/privacy**
10. **Common UI states**
11. **Tests**
12. **Validation and CI**
13. **Manual/external setup**
14. **Deferred work**
15. **Warnings/blockers for plan 03**
16. **Pull request/commit reference**

Do not report parent roadmap plan 02 as implemented until this pull request is merged.
