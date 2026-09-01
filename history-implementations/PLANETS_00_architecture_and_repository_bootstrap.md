# PLANETS 00 — Architecture and Repository Bootstrap

**Task type:** Complete roadmap plan  
**Repository:** `lillo24/planets.community`  
**Target base:** latest `main`  
**Repository state verified when this prompt was written:** `main` at `8b8db89e9234e2761fafe2c39dd9843d77117bf1`, documentation-only; no Flutter, Next.js, Supabase, CI, or product implementation exists yet.

## Objective

Create a boring, reproducible repository foundation for PLANETS without implementing product behavior.

After this task, a new contributor should be able to clone the repository, install the documented prerequisites, restore dependencies, start the local Supabase stack, run the empty Flutter and Next.js applications, and run the repository's validation commands.

The result should establish only the infrastructure that later plans can safely build on. It must **not** prematurely implement the database/security model from plan 01 or the application architecture/product shells from plan 02.

## Read before changing anything

Inspect the current repository first. At minimum read:

1. `AGENTS.md`
2. `README.md`
3. `docs/architecture/core-stack.md`
4. `docs/architecture/system-design.md`
5. `docs/implementation/roadmap.md`
6. `implementation_plan_sections_suggestions.md`

Then inspect the actual repository tree and Git status. Do not assume it still matches the commit recorded above if `main` has advanced.

Repository code/tests/configuration, when they exist, override older prompt assumptions about implemented behavior.

## Current status classification

### Implemented

At the verified base commit, only documentation exists:

- root README;
- architecture documentation;
- implementation roadmap;
- coding-agent instructions;
- implementation-plan guidance.

There is no runnable application or backend yet.

### Accepted/intended

The accepted baseline is:

- Flutter/Dart for Android and iOS;
- Supabase with PostgreSQL as the shared backend;
- Next.js/TypeScript for the public website and admin interface;
- GitHub Actions for general validation;
- Codemagic later for mobile release builds;
- managed services rather than a general-purpose VPS;
- one repository containing mobile, web, Supabase, documentation, and shared tooling.

Preserve the boundaries in the architecture documents.

### Tentative or intentionally unresolved

Do not resolve product behavior in this task, including:

- profile fields or visibility;
- proposal schema/lifecycle;
- competences taxonomy;
- participation rules;
- authentication UX;
- notification categories;
- chat behavior;
- moderation rules;
- location privacy;
- final mobile bundle/package identifiers;
- production environments, domains, accounts, credentials, or billing.

## Size boundary for this plan

Keep this as one implementation task **only while it remains a bootstrap task**.

The coherent scope is:

1. repository/root tooling;
2. official Flutter scaffold;
3. official Next.js scaffold;
4. local Supabase initialization;
5. initial validation CI;
6. developer setup documentation and ADR convention.

If implementation reveals that one of these requires substantial product architecture, provider provisioning, schema design, or a large custom build system, **do not expand the PR to absorb that work**. Defer it to the appropriate roadmap plan and report the boundary.

Do not combine plan 01 or plan 02 into this task merely because the new scaffolds make that work easy to start.

## External context and access

No external product document is required for this plan.

In particular:

- do **not** depend on access to the Google Doc `Planets Community Design`;
- no Supabase Cloud project is required;
- no Firebase project is required;
- no Vercel project is required;
- no Apple/Google developer account is required;
- no Sentry/PostHog/Resend/Cloudflare account is required;
- no production or staging secrets are required.

Network access may be needed to install SDK/package dependencies. Docker or a compatible container runtime is needed to run the local Supabase stack.

If a local system prerequisite is unavailable, continue with everything that can be implemented and validated safely. Do not handcraft generated framework/platform boilerplate merely to pretend that an official scaffold command succeeded. Report the exact limitation.

## Tooling decisions for this plan

### Node.js and package manager

Use **Node.js 24 LTS** as the repository's initial Node line.

Use **npm** as the Node package manager and root task entry point. The goal is to avoid introducing another package-manager prerequisite when Node already supplies npm.

Create one root Node workspace/lockfile for Node-managed packages, including `apps/web` and the project-scoped Supabase CLI. Avoid a second nested Node lockfile unless the current toolchain makes that unavoidable and you can justify it.

The Supabase CLI should be installed as a **project dev dependency and pinned to an exact stable version**, then invoked through npm/`npx`, rather than requiring every developer to install an unrelated global CLI.

Do not introduce Turborepo, Nx, pnpm, Yarn, Bun, Make, `just`, Melos, FVM, `mise`, `asdf`, or another orchestration/version-management layer in this task unless repository evidence or a concrete toolchain failure demonstrates that it is needed. If you believe one is necessary, stop and explain the specific problem before adding it.

### Flutter

Use the **stable Flutter channel**, not beta/main/canary.

Resolve the current stable release available at task execution, record the exact version used in documentation and CI, and use the same stable version in automated validation.

The repository does not need an additional Flutter version manager in plan 00. If exact local SDK pinning later becomes painful, that can be revisited with evidence.

### Next.js

Use the current stable `create-next-app`/Next.js toolchain with:

- TypeScript;
- App Router;
- ESLint;
- Tailwind CSS;
- a normal import alias such as `@/*`;
- no experimental/canary dependencies unless a current stable generator requires them.

Prefer ordinary generated defaults over custom framework configuration.

## Required work

### 1. Establish root repository tooling

Create the minimum root configuration needed to make the repository coherent and cross-platform.

At minimum:

- a private root `package.json`;
- npm workspace configuration including `apps/web`;
- one root `package-lock.json`;
- the pinned Supabase CLI dev dependency;
- a Node version declaration and/or `engines` entry consistent with Node 24 LTS;
- a root `.editorconfig`;
- a root `.gitignore` covering generated build output, dependency directories, local environment files, and Supabase temporary state;
- root npm scripts that expose the common developer actions without requiring Bash-specific scripts.

Prefer simple npm scripts over a custom task-runner framework.

Expose a clear root command interface. Exact implementation may vary, but contributors should have equivalents of:

```text
npm run dev:web
npm run dev:mobile

npm run db:start
npm run db:stop
npm run db:status

npm run check:web
npm run check:mobile
npm run check

npm run format
npm run format:check
```

Add additional small commands only when they materially improve setup or CI, for example dependency restore or a Supabase smoke check.

`npm run check` should remain suitable for frequent local use. Do not make it implicitly provision cloud services, mutate remote resources, or require production credentials.

If starting the full local Supabase stack would make the ordinary `check` command unreasonably slow, keep database startup/status as a separate explicit command and test it in its own CI job.

### 2. Bootstrap the Flutter mobile application

Create the mobile project under:

```text
apps/mobile/
```

Use the official Flutter scaffold command rather than manually creating Android/iOS platform boilerplate.

Requirements:

- Android and iOS are the only required Flutter target platforms for this application;
- use a normal Dart package name appropriate for the repository, such as `planets_mobile`;
- set the visible bootstrap application name to `PLANETS`;
- use a clearly provisional/non-store platform identifier if the scaffold requires one;
- document that final Android/iOS package/bundle identifiers must be finalized before provider registrations that depend on them, especially Firebase/FCM;
- keep generated platform configuration conventional;
- replace disposable Flutter demo/counter branding with a tiny neutral PLANETS bootstrap screen;
- retain only enough UI to prove the application starts;
- keep the generated/basic widget smoke test or replace it with an equivalent neutral bootstrap smoke test.

Do **not** add in plan 00:

- Riverpod;
- `go_router`;
- Freezed;
- `json_serializable`;
- Supabase Flutter;
- Firebase;
- Sentry;
- localization architecture;
- feature-first folders;
- authentication;
- product screens.

Those application foundations belong primarily to plan 02 or later.

The Flutter scaffold must pass:

- formatting check;
- `flutter analyze`;
- `flutter test`.

If the environment has a working Android toolchain, also perform a basic debug Android build or run smoke check. Do not treat the inability to build iOS on a non-macOS machine as a failure; report it accurately.

### 3. Bootstrap the Next.js web application

Create the web project under:

```text
apps/web/
```

Use the official stable Next.js scaffold rather than manually reconstructing generated framework files.

Requirements:

- TypeScript;
- App Router;
- ESLint;
- Tailwind CSS;
- no product-specific backend logic;
- no authentication;
- no admin authorization;
- no Supabase client yet unless the generator itself requires nothing beyond placeholders;
- no Sentry;
- no analytics;
- no shadcn/ui setup yet unless there is a compelling current-tooling reason. Plan 02 owns the real web application foundation.

Replace disposable starter marketing/demo content with a minimal semantic PLANETS bootstrap page. It should prove rendering works, not establish visual identity.

Ensure the web package exposes at least:

```text
dev
build
start
lint
typecheck
```

`typecheck` should perform an explicit TypeScript check rather than assuming `next build` substitutes for all static validation.

The web scaffold must pass:

- npm dependency installation from the root lockfile;
- ESLint;
- TypeScript checking;
- production `next build`.

Do not add a testing framework solely to produce an artificial unit test for a static placeholder page. The production build is sufficient as the web smoke test for plan 00. Playwright and richer component/integration testing can be introduced when there is behavior worth testing.

### 4. Initialize Supabase local development

Initialize Supabase at the repository root so the canonical location is:

```text
supabase/
```

Use the official Supabase CLI initialization command.

Requirements:

- commit `supabase/config.toml`;
- keep generated CLI temporary directories ignored;
- use a local project identifier appropriate for PLANETS;
- do not link the repository to a remote Supabase project;
- do not create a production/staging project;
- do not add OAuth providers or external service secrets;
- do not define product tables, RLS policies, PostGIS setup, audit tables, outbox tables, or auth/profile relationships yet;
- do not decide the migration-vs-declarative-schema workflow beyond what is required for a clean initialization; plan 01 owns the database workflow and security model.

It is acceptable to add an empty/comment-only deterministic `supabase/seed.sql` if that makes the intended local workflow explicit. Do not create fake domain seed data before a schema exists.

Where Docker/container runtime is available, verify:

1. local Supabase starts successfully;
2. CLI health checks pass;
3. status can be queried;
4. the stack stops cleanly.

The local Supabase stack is development-only and must not be exposed publicly.

### 5. Add initial GitHub Actions validation

Add a focused pull-request/main validation workflow under `.github/workflows/`.

Use separate jobs where this improves failure isolation.

#### Mobile job

At minimum:

- checkout;
- install the exact stable Flutter version selected for this repository;
- restore Flutter dependencies;
- run formatting check;
- run static analysis;
- run Flutter tests.

Do not require iOS compilation on a Linux runner.

#### Web job

At minimum:

- checkout;
- install Node 24 LTS;
- use npm cache where appropriate;
- run `npm ci` from the repository root;
- run web linting;
- run web TypeScript checking;
- run the production Next.js build.

#### Supabase local smoke job

At minimum:

- checkout;
- install Node 24 LTS;
- run `npm ci`;
- use the repository-pinned Supabase CLI;
- start the local Supabase stack on the CI runner;
- verify it reaches a healthy/status-reporting state;
- stop it even when a later smoke step fails.

This job tests only that the local platform can be reproduced. Plan 01 will add migration replay, pgTAP, RLS, and schema tests.

#### Workflow safety

- trigger on pull requests and pushes to `main`;
- give the workflow only the GitHub permissions it needs, preferably read-only contents for validation;
- do not use production secrets;
- do not deploy;
- do not create cloud resources;
- use concurrency cancellation for superseded runs when practical;
- avoid duplicated dependency installation inside a job when caching/setup can keep the workflow simple.

Do not add Codemagic configuration yet. Codemagic is for later signed/release builds and belongs to plan 12 unless an earlier concrete need appears.

### 6. Developer documentation

Update repository documentation so a contributor can reproduce the foundation without reading the implementation prompt.

At minimum document:

#### Prerequisites

- Git;
- Node.js 24 LTS and npm;
- the exact stable Flutter version selected;
- Docker Desktop or another Supabase-supported Docker-compatible runtime;
- Android tooling only when running/building Android;
- macOS/Xcode only when running/building iOS.

Avoid requiring WSL, Git Bash, Make, or Unix-only shell behavior for normal commands. The primary contributor environment may be Windows.

#### First setup

Document the exact clone/dependency/local-service sequence, using the committed root scripts.

A contributor should understand how to:

- install Node dependencies;
- restore Flutter packages;
- start/stop local Supabase;
- run the web application;
- run the mobile application;
- run all ordinary validation;
- find local Supabase Studio/status information.

#### Environment/secrets

Do not invent future environment variables.

If no application environment variables are consumed yet, say so explicitly rather than creating many unused placeholders. Create `.env.example` files only for variables that the bootstrap genuinely uses or for a minimal convention that prevents secret mistakes.

Any real `.env*` file containing secrets must be ignored. Never commit production credentials.

#### Repository status

Update `README.md` so it no longer claims that mobile/backend/web have not been bootstrapped once this task is complete.

Keep README concise; link to a dedicated getting-started/contributing document for detailed setup commands.

### 7. Establish ADR convention

Create a small architecture-decision location, for example:

```text
docs/architecture/decisions/
```

Add concise guidance/template covering:

- identifier/title;
- status;
- date;
- context/problem;
- decision;
- alternatives considered when relevant;
- consequences/tradeoffs.

Do not create ADRs for trivial generated defaults.

If plan 00 introduces a material long-lived decision not already captured in the architecture docs—such as the root package/workspace strategy—record it only if the rationale is likely to matter later. Otherwise keep the convention ready for future plans.

## Repository shape after completion

The exact generated internals are tool-owned, but the high-level tree should approximately be:

```text
/
├─ .github/
│  └─ workflows/
├─ apps/
│  ├─ mobile/
│  └─ web/
├─ supabase/
│  └─ config.toml
├─ docs/
│  ├─ architecture/
│  │  └─ decisions/
│  ├─ development/              # if useful for setup docs
│  └─ implementation/
├─ AGENTS.md
├─ README.md
├─ package.json
├─ package-lock.json
├─ .editorconfig
└─ .gitignore
```

Do not create empty directory hierarchies for future features merely to match an aspirational tree.

## Non-goals

Do not implement or configure any of the following in this task:

- production or staging Supabase;
- Vercel deployment;
- Cloudflare DNS;
- Firebase/FCM;
- Resend;
- Sentry;
- PostHog;
- Codemagic;
- app-store signing;
- social/email authentication;
- application profiles;
- PostgreSQL domain schema;
- PostGIS;
- RLS;
- database functions;
- audit/outbox/queues;
- Storage buckets;
- Realtime chat;
- proposal or participation behavior;
- admin routes/permissions;
- final public website content;
- polished UI/design system;
- localization architecture;
- Riverpod/`go_router`/Freezed;
- shadcn component installation;
- Playwright setup unless a concrete bootstrap requirement appears;
- donation/payment behavior;
- map SDKs;
- AI functionality;
- a VPS, microservices, Redis, Kubernetes, or dedicated search.

Do not add placeholders for these systems beyond documentation references already present.

## Implementation guidance

### Prefer generated official scaffolds

Use framework generators for framework-owned boilerplate:

- Flutter CLI for mobile;
- `create-next-app` for web;
- Supabase CLI for local backend configuration.

After generation, remove irrelevant demo content and integrate the result into the repository conventions.

Do not manually recreate generated Android/iOS platform directories, Next.js internals, or Supabase `config.toml` from memory if the official tool is available.

### Keep root orchestration thin

The repository contains multiple ecosystems, but it does not yet need a general monorepo framework.

The root npm layer should mostly provide:

- Node dependency/workspace management;
- the pinned Supabase CLI;
- memorable cross-platform commands that delegate to Flutter, Next.js, or Supabase.

Do not wrap every underlying command in custom JavaScript just to hide standard tooling.

### Preserve plan boundaries

If generated scaffolds expose obvious opportunities to add Riverpod, Supabase clients, routing, auth, Sentry, or domain folders, leave them for their roadmap plan.

A clean empty foundation is the desired outcome.

### Version recording

In the completion report, state the exact versions actually used for at least:

- Node;
- npm;
- Flutter;
- Dart;
- Next.js;
- React;
- Supabase CLI.

Use stable releases only.

## Failure behavior and edge cases

Handle these deliberately:

### Missing Docker

If Docker/container runtime is unavailable:

- still initialize Supabase config with the CLI if possible;
- add the CI smoke job;
- document local Docker as a prerequisite;
- report that local Supabase startup was not validated in the Codex environment;
- do not claim it passed.

Do not remove Supabase from the plan merely because the current execution environment lacks Docker.

### Missing Flutter SDK or platform tools

If Flutter itself is unavailable and cannot be installed safely:

- do not handcraft the Flutter-generated platform projects;
- report the blocker clearly.

If Flutter works but Android SDK/Xcode does not:

- run formatting/analyze/tests;
- leave platform build validation to an environment with the required SDK;
- do not treat lack of Xcode outside macOS as a defect.

### Generated dependency conflicts

If current stable framework generators produce a conflict with Node 24 LTS or with each other:

1. verify the conflict from actual commands/errors;
2. prefer current stable supported versions rather than beta/canary;
3. make the smallest compatibility adjustment;
4. document it;
5. only stop if resolving it would materially change the accepted stack.

### Final mobile identifiers

Do not stop this task solely because final store identifiers are not decided.

Use a clearly provisional identifier if necessary and document the follow-up decision. It must be finalized **before Firebase/FCM or store provisioning that depends on package/bundle identity**.

### Environment files

Do not commit real credentials.

If a generated tool creates a local file containing machine-specific credentials/state, ensure it is ignored before committing.

## Validation required

Run all checks available in the execution environment.

### Repository/root

- clean dependency install from the committed lockfile;
- root script commands resolve correctly;
- no accidental secrets or machine-local paths are committed.

### Flutter

From a clean dependency restore:

- formatting check;
- `flutter analyze`;
- `flutter test`;
- optional Android debug build/run smoke if the Android SDK is available.

### Web

From root `npm ci`:

- lint;
- TypeScript check;
- production build.

### Supabase

Where a container runtime is available:

- local start;
- health/status check;
- clean stop.

### GitHub Actions

Validate workflow syntax/configuration as far as tooling allows.

If the branch can be pushed and a PR opened, inspect the resulting GitHub Actions runs. A task is not fully validated merely because equivalent commands worked locally if the committed workflow itself is broken.

Do not state that any command passed if it was not executed.

## Acceptance criteria

The task is complete when all applicable items below are true:

- [ ] `apps/mobile` is an official, minimal Android/iOS Flutter scaffold.
- [ ] `apps/web` is an official, minimal TypeScript/App-Router Next.js scaffold.
- [ ] root npm workspace/dependency management is coherent and has one canonical Node lockfile.
- [ ] the Supabase CLI is project-scoped and pinned to a stable exact version.
- [ ] `supabase/config.toml` is committed and no remote project is linked/configured.
- [ ] local Supabase can be started/status-checked/stopped in at least CI, and locally too when Docker is available.
- [ ] root commands provide a simple cross-platform way to run and validate each surface.
- [ ] Flutter formatting/analyze/tests pass.
- [ ] web lint/typecheck/production build pass.
- [ ] GitHub Actions independently validates mobile, web, and local Supabase bootstrap.
- [ ] no workflow deploys or requires production secrets.
- [ ] README accurately describes the new implementation state.
- [ ] contributor/development documentation contains prerequisites and exact startup/check commands.
- [ ] an ADR convention exists without unnecessary ADR proliferation.
- [ ] no authentication, domain schema, RLS, product features, monitoring integrations, deployment, or UI polish has leaked into this task.
- [ ] no credentials, machine-specific paths, generated dependency directories, or local Supabase state are committed.
- [ ] exact selected tool/framework versions are recorded.
- [ ] plan 00's roadmap status is updated appropriately only if the work meets its acceptance criteria.

If any required criterion cannot be met because of the execution environment, distinguish **implementation complete but locally unverified** from an actual implementation failure. CI can supply missing platform evidence where appropriate.

## Documentation updates

At completion:

1. update `README.md` from "not bootstrapped" to the real state;
2. add/update contributor or development-startup documentation;
3. add the ADR convention;
4. update `docs/implementation/roadmap.md`:
   - mark plan 00 `Implemented` only if the PR satisfies this prompt and is ready to merge;
   - otherwise use `In progress` or `Blocked` and explain why in the report;
5. update architecture docs only if implementation uncovered a genuine architecture change. Do not rewrite them merely to repeat generated file paths.

## Manual/external setup remaining after this task

There should be **no required cloud account configuration** to consider plan 00 complete.

A human developer may still need to install local prerequisites on their own machine:

- Flutter SDK;
- Android tooling;
- Docker Desktop/container runtime;
- Xcode on macOS for iOS builds.

Do not configure:

- remote Supabase;
- Firebase;
- Vercel;
- Cloudflare;
- Resend;
- Sentry;
- PostHog;
- Apple/Google developer accounts.

Those belong to later plans.

## Autonomy and stop conditions

You may decide ordinary scaffold and configuration details without asking for founder input when they are consistent with this prompt and the architecture documents.

Examples you should decide autonomously:

- generated formatting settings;
- minor folder placement inside the generated apps;
- exact stable patch versions;
- CI cache configuration;
- whether detailed setup lives in `CONTRIBUTING.md` or `docs/development/getting-started.md`;
- a provisional mobile package/bundle identifier;
- minor root-script implementation details.

Stop and report before:

- replacing one of the accepted core technologies;
- adding a monorepo/build orchestration framework because of preference rather than demonstrated need;
- creating or linking cloud resources;
- introducing recurring infrastructure cost;
- committing secrets;
- defining product/domain schema or authorization rules;
- making a production package/bundle identifier decision that requires external ownership information;
- absorbing substantial plan 01 or plan 02 work.

## Deliverables

Produce:

1. the bootstrap code/configuration;
2. Flutter and Next.js minimal smoke surfaces;
3. local Supabase configuration;
4. root dependency/task configuration;
5. initial GitHub Actions CI;
6. updated README/developer documentation;
7. ADR convention;
8. any minimal test/smoke files required by the generated applications;
9. a focused pull request from a dedicated branch, preferably named similarly to `impl/00-repository-bootstrap`;
10. a completion report.

Do **not** merge the pull request yourself unless the active execution environment explicitly instructs you to do so.

## Completion report

Return a concise structured report containing:

1. **Summary** — what is now runnable/reproducible.
2. **Changed areas/files** — major paths only.
3. **Selected versions** — Node, npm, Flutter, Dart, Next.js, React, Supabase CLI.
4. **Decisions/assumptions** — especially root workspace/tooling and provisional mobile identifiers.
5. **Validation** — exact commands run and pass/fail/not-run results.
6. **CI status** — workflow names/runs and failures if the PR was pushed.
7. **External/manual setup remaining** — local prerequisites only; confirm no cloud accounts were provisioned.
8. **Known limitations/deferred work** — clearly separate plans 01 and 02.
9. **Warnings/blockers for plan 01** — anything discovered that should stop the next roadmap task.
10. **Pull request or commit reference**.

Do not report plan 00 as complete if the repository is not reproducible from committed files or if CI is knowingly broken.
