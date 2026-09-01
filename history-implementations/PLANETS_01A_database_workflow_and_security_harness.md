# PLANETS 01A — Database Workflow and Security Harness

**Roadmap parent:** PLANETS 01 — Database foundation and security model  
**Task type:** First portion of roadmap plan 01  
**Repository:** `lillo24/planets.community`  
**Target base:** latest `main`  
**Verified `main` when this prompt was written:** `3c26b29c4f7aa2f166719a86b009a677b300dedc`  
**Plan 00 merge:** `19ec48094c192c3ef858c1e435eda157ae51488b`

## Why roadmap plan 01 is split

The original roadmap item 01 combines two different kinds of work:

1. database workflow/security infrastructure; and
2. permanent shared application primitives such as the auth-linked profile anchor, audit events, and transactional outbox.

Implementing all of that in one first database pull request would enlarge the review surface precisely where security conventions are still being established.

Therefore execute roadmap plan 01 as:

- **01A — Database Workflow and Security Harness**: this prompt.
- **01B — Identity, Audit, and Outbox Primitives**: prepare only after 01A is merged and the repository is re-inspected.

Plan 01 remains incomplete until both portions are merged. Do not start plan 02 after 01A alone.

## Objective

Turn the empty local Supabase bootstrap from plan 00 into a reproducible, fail-closed database-development foundation.

After this task, contributors and CI should be able to:

- rebuild the local database entirely from committed SQL migrations;
- run database linting and pgTAP tests;
- prove that future API-facing tables are required to use RLS;
- prove that new tables/functions are **not** granted to client roles implicitly;
- keep the non-API `private` schema inaccessible to client roles;
- use PostGIS from a non-public extension schema;
- regenerate committed TypeScript database types from the local schema;
- detect migration, security, lint, test, or generated-type drift before merge.

This task establishes mechanisms and conventions. It must **not** define PLANETS product tables or user-facing behavior.

## Read before changing anything

Inspect the current repository and Git status first. At minimum read:

1. `AGENTS.md`
2. `README.md`
3. `package.json`
4. `.github/workflows/validation.yml`
5. `supabase/config.toml`
6. `supabase/seed.sql`
7. `docs/development/getting-started.md`
8. `docs/architecture/core-stack.md`
9. `docs/architecture/system-design.md`
10. `docs/architecture/decisions/README.md`
11. `docs/architecture/decisions/0001-root-npm-workspace.md`
12. `docs/implementation/roadmap.md`
13. `implementation_plan_sections_suggestions.md`

Inspect the actual tree rather than assuming it still matches the commit recorded above.

If `main` has advanced, use current repository evidence and preserve compatible newer work.

## Current repository evidence

At the verified base:

- plan 00 is merged and marked implemented;
- `apps/mobile` is a minimal Flutter Android/iOS scaffold;
- `apps/web` is a minimal Next.js TypeScript scaffold;
- the root uses npm workspaces and one root `package-lock.json`;
- Supabase CLI `2.116.0` is pinned as a root dev dependency;
- local Supabase is initialized under `supabase/`;
- `supabase/config.toml` uses PostgreSQL 17;
- the current Supabase validation job only proves start/status/stop;
- no migration files exist;
- no application tables exist;
- no RLS policies exist;
- no PostGIS application setup exists;
- no pgTAP test suite exists;
- no generated database type file exists;
- no Flutter or Next.js Supabase client exists;
- no remote Supabase project is linked or required.

The existing `supabase/config.toml` exposes the standard `public` and `graphql_public` schemas. Its `auto_expose_new_tables` setting is currently left unset/commented. The generated comment states that a fresh local project falls back to automatic exposure when it is unset.

The PLANETS architecture requires the opposite posture: API access must be explicit and security-sensitive defaults must fail closed.

## External context and access

No Google Doc or other product/design material is required.

No cloud provider account is required.

Do not create, link, or modify:

- a remote Supabase project;
- Firebase;
- Vercel;
- Cloudflare;
- Resend;
- Sentry;
- PostHog;
- Apple/Google developer resources.

Use only the local Supabase stack and repository tooling.

If current Supabase CLI behavior differs from this prompt, verify it against the installed pinned CLI and current official Supabase documentation. Prefer current supported behavior over reproducing stale syntax, but preserve the security intent and report any material discrepancy.

## Decisions already made

### 1. SQL migrations are canonical

Use committed, timestamped Supabase SQL migrations as the canonical database history.

Normal schema work should follow the migration workflow:

1. create/edit a migration locally;
2. reset the local database from zero;
3. run lint/tests;
4. commit the migration;
5. after a migration is merged and relied on, future changes are new forward migrations rather than edits to history.

Do not introduce Supabase declarative schema files in this task.

Do not make schema changes only through Studio and leave them uncaptured.

A future explicit architecture decision may revisit declarative schemas if the repository grows enough to justify them.

### 2. `public` is API-facing; `private` is not

Use:

- `public` for application objects intentionally eligible for Supabase Data API access;
- `private` for server/internal objects that must not be directly exposed through the Data API;
- Supabase-managed schemas such as `auth`, `storage`, and `realtime` remain platform-owned;
- extension objects belong in a non-public extension schema.

Do not add `private` to `api.schemas`.

Client roles must not receive broad usage/access to `private`.

Future trusted operations that need private data should use deliberately designed server/database boundaries rather than exposing the schema.

### 3. API access requires explicit grants

PLANETS must not rely on implicit grants to `anon`, `authenticated`, or `service_role`.

Set the local Supabase Data API configuration to **not automatically expose new tables**.

Establish PostgreSQL default privileges for PLANETS-owned objects in `public` so a newly created table, sequence, or function is not accidentally callable by client roles merely because a migration forgot to review permissions.

Later feature migrations must explicitly grant only the privileges they need.

RLS and SQL grants are separate layers; later API-facing tables will require both appropriate grants and RLS policies.

### 4. RLS is mandatory for API-facing tables

Every ordinary PLANETS table in an exposed application schema must have Row Level Security enabled.

Do **not** add a hidden event trigger that automatically changes every future table. Prefer explicit migration SQL plus a CI/pgTAP invariant that fails when someone forgets RLS.

This makes security behavior visible in each feature migration while still preventing accidental merges.

### 5. No blanket soft-delete convention

Do not introduce a universal `deleted_at` column or generic content-state abstraction.

Deletion, anonymization, historical retention, and moderation state have product/legal consequences and will be defined by the relevant later plans.

### 6. Common data conventions

Document these as defaults for later migrations, not as reasons to create unused tables now:

- UUID primary keys for ordinary application entities unless a stronger reason exists;
- auth-linked entities may reuse the relevant `auth.users.id`;
- timestamps use `timestamptz`;
- `created_at` should normally be non-null with a database default;
- mutable `updated_at` is added only where useful and must be maintained server-side if introduced;
- constraints should express invariants the database can enforce;
- names use conventional lowercase `snake_case`;
- foreign-key delete behavior must be selected deliberately per relationship rather than defaulting mechanically to cascade.

### 7. PostGIS is enabled now, map behavior is not

Enable PostGIS through a migration because geographic data is an accepted backend foundation.

Install it in a non-public extension schema at creation time. Do not install PostGIS into `public`, and do not create PLANETS location tables yet.

Prefer the existing Supabase `extensions` schema when supported by the current local stack. If the current PostGIS/Supabase combination requires or strongly favors a dedicated non-public extension schema, use one and document the decision.

Do not attempt to relocate PostGIS after creating application dependencies on it.

## Scope

### A. Migration workflow

Create the first database migration(s) using the Supabase migration tooling.

The committed migration history should establish only foundation concerns needed by 01A, such as:

- non-public `private` schema;
- extension setup;
- fail-closed default privileges;
- any small database-level foundation needed to make those rules reproducible.

One or several migrations are acceptable. Prefer logical reviewability over arbitrary file count.

Do not create empty migrations for future features.

### B. Fail-closed Data API configuration

Update `supabase/config.toml` so local behavior explicitly disables automatic exposure/granting of newly created public objects where the current CLI supports that setting.

The goal is to align local development with the accepted security rule:

> a developer creates an object first; API privileges are granted intentionally afterward.

Do not remove `public` from the exposed schemas because PLANETS will use the Data API later.

Do not expose `private`.

### C. Default PostgreSQL privileges

For PLANETS-created objects in the API-facing application schema, configure defaults so future migrations do not accidentally grant access to:

- `anon`;
- `authenticated`;
- `service_role`;
- PostgreSQL `PUBLIC`, where PostgreSQL would otherwise grant routine execution implicitly.

Cover the relevant object classes:

- tables;
- sequences;
- routines/functions.

Be precise about which object owner/default-privilege context is being modified. Supabase migrations normally execute as a privileged project role; inspect the local environment rather than writing an `ALTER DEFAULT PRIVILEGES` statement that looks correct but applies to the wrong creator role.

Explicit feature-level grants will be added later.

Do not broadly revoke privileges from Supabase-managed schemas or platform roles.

### D. Private schema isolation

Create and secure a `private` schema.

At minimum prove that ordinary API/client roles cannot use it directly.

Do not create product tables inside it yet.

Do not expose it through PostgREST/Data API configuration.

Do not add a convenience grant to `service_role` merely because it is privileged; later trusted access should be explicit.

### E. PostGIS

Enable PostGIS reproducibly through migration SQL.

Validation must prove:

- the extension exists after a clean reset;
- it is not installed in `public`;
- a basic supported PostGIS type/function is available.

Do not create map, address, CAP, municipality, proposal-location, or user-location tables.

### F. pgTAP test harness

Create a database test suite under `supabase/tests/` using pgTAP.

Avoid adding the Basejump/database.dev test-helper package in 01A. There is no authenticated product table yet, so a network-installed helper dependency does not currently buy enough value.

Use native pgTAP/Postgres capabilities and the local Supabase environment.

The test suite should establish reusable security invariants.

At minimum test:

#### Schema/security structure

- `private` exists;
- `private` is not directly usable by `anon`;
- `private` is not directly usable by `authenticated`;
- `private` is not directly usable by `service_role` unless current platform behavior makes a narrower safe rule necessary and that exception is documented;
- PostGIS exists in a non-public schema.

#### RLS invariant

Fail if any ordinary PLANETS table in the API-facing `public` schema exists without RLS enabled.

Make the query precise enough to exclude irrelevant system/extension relations.

It is acceptable that this assertion currently sees zero PLANETS application tables. Its value is as a future guard.

#### Default-grant invariant

Within a rolled-back test transaction, create disposable probe objects using the same ownership context future migrations use and prove that they do **not** automatically receive client access.

Probe enough object types to catch mistakes in default privileges, for example:

- a table;
- a sequence if not adequately covered by the table probe;
- a function/routine.

The test must clean up through rollback and must not leave probe objects in the schema.

#### Function execution default

Explicitly verify that a newly created PLANETS function is not executable through a client role merely because PostgreSQL's default routine privileges were left unchanged.

Do not create a permanent fake application function only for this test.

### G. Database linting and reset validation

Add root scripts for the database workflow.

Names may vary if existing conventions strongly suggest alternatives, but contributors should have clear equivalents of:

```text
npm run db:reset
npm run db:lint
npm run db:test
npm run db:types
npm run check:db
```

Keep the existing fast `npm run check` focused on web/mobile unless there is a strong reason to make Docker a prerequisite for every ordinary check.

`check:db` may assume the local Supabase stack is already running, or may own the lifecycle if implemented safely and cross-platform. Document the choice clearly.

Database validation should include:

1. reset/replay all migrations from zero;
2. database linting at an appropriate strictness;
3. pgTAP suite;
4. generated type consistency.

Use `supabase db lint` rather than introducing a separate SQL linter unless a concrete gap is demonstrated.

### H. Generated TypeScript database types

Generate TypeScript types from the **local** database schema using the pinned Supabase CLI.

Store one committed generated file in a location the existing Next.js application can later consume without introducing a new package/workspace solely for this file.

A likely location is under `apps/web/src/`, for example a clearly named generated/database-types path. Inspect current Next.js structure and choose the least artificial location.

Requirements:

- generated from local migrations, not a remote project;
- generated for the intended API schema(s), primarily `public`;
- clearly marked generated/do-not-hand-edit where the generator permits or documentation can state it;
- a root script regenerates it deterministically;
- CI regenerates it after reset and fails on Git diff if the committed file is stale.

Do not add `@supabase/supabase-js` or initialize a web Supabase client yet. That belongs to plan 02.

### I. CI database job

Upgrade the existing **Supabase local smoke** job into a real database validation job.

It should still exercise a clean local Supabase lifecycle, but now also prove the committed database foundation.

At minimum:

1. checkout;
2. Node 24 and `npm ci`;
3. start local Supabase;
4. reset the database from committed migrations/seed;
5. run database lint;
6. run pgTAP tests;
7. regenerate committed TypeScript database types;
8. fail if generated types differ;
9. stop Supabase with `if: always()` or equivalent cleanup.

Keep mobile and web jobs independent.

Do not add cloud credentials or link to a remote project.

Do not deploy migrations.

### J. Documentation and ADR

Add concise database-development documentation covering:

- migration creation;
- clean reset;
- seed rules;
- explicit grants + RLS relationship;
- `public` versus `private`;
- database test commands;
- generated-type workflow;
- PostGIS extension location;
- what must happen when a developer adds a future API-facing table/function.

Update `docs/development/getting-started.md` only where needed; avoid duplicating an entire database guide into it.

Record a focused ADR if useful for the lasting decision:

> canonical SQL migrations + explicit/fail-closed Data API grants + CI security invariants.

One ADR may cover this coherent decision. Do not create separate ADRs for every command.

Update the implementation roadmap to reflect the 01A/01B split and mark the parent plan 01 as **In progress** while 01B remains outstanding.

## Non-goals

Do not implement any of the following:

- `public.profiles` or another application user/profile table;
- auth-user creation triggers;
- profile fields;
- authentication flows;
- public browsing policies;
- proposal tables;
- competence/resource taxonomy;
- location/address tables;
- PostGIS indexes tied to product data;
- audit-event tables;
- transactional outbox tables;
- queue consumers;
- notification tables;
- storage buckets;
- chat;
- moderation;
- admin roles;
- account deletion;
- generic updated-at trigger frameworks;
- universal soft delete;
- Supabase Flutter;
- `supabase-js`;
- Edge Functions;
- remote Supabase linking;
- production/staging databases;
- deployment workflows;
- Sentry/PostHog/Firebase/Resend;
- plan 02 Flutter/Next.js architecture.

Those belong to 01B or later roadmap plans.

## Important security guidance

### Grants and RLS are both required

Do not treat RLS as a substitute for table/function grants.

The intended future sequence for an API-facing table is:

1. create table;
2. add constraints/indexes;
3. enable RLS;
4. define policies;
5. explicitly grant only required operations to relevant API roles;
6. add allow/deny tests for each actor/operation.

For functions:

1. create the function with a reviewed security mode;
2. revoke default execution where needed;
3. grant `EXECUTE` only to intended roles;
4. test it as those roles.

### `SECURITY DEFINER`

01A should not need application `SECURITY DEFINER` functions.

If Codex concludes one is required merely to establish the harness, stop and explain why before adding it.

Later `SECURITY DEFINER` functions must have:

- a concrete need;
- a controlled `search_path`;
- explicit execution grants;
- tests;
- no reliance on caller-controlled schema resolution.

### Supabase-managed schemas

Do not modify Supabase internal/auth/storage tables or their structural contracts.

`auth.users` will be referenced by a PLANETS application table in 01B. Do not add that table now.

### Extension schemas

Do not place application tables/functions in the extension schema.

Do not put PostGIS in `public`.

### Logs and test data

Tests must contain only deterministic fake/test data.

No real user data, access tokens, provider credentials, or local machine secrets.

## Failure behavior and edge cases

### Docker unavailable locally

If the execution environment cannot run Docker but the repository can still be modified:

- implement the migration/test/CI work;
- validate static parts that do not need containers;
- rely on the PR's Ubuntu CI for the full database lifecycle;
- inspect CI results before declaring success;
- do not claim local database tests ran if they did not.

Plan 00 established that CI can run local Supabase successfully, so a developer-machine Docker issue is not by itself a blocker.

### Supabase local/cloud exposure mismatch

Because no remote project exists, do not guess remote dashboard state.

The repository should encode the intended local fail-closed behavior and document that future staging/production provisioning must preserve explicit-grant behavior.

If a CLI setting only affects local development, combine it with SQL privilege tests so the security contract is not merely a TOML assumption.

### PostGIS schema behavior differs

PostGIS is not safely relocatable after dependencies exist.

If the local version refuses the preferred extension schema or already installs it differently:

- inspect actual extension metadata;
- choose a supported non-public schema before product location tables exist;
- document the result;
- do not use `DROP EXTENSION ... CASCADE` as a casual workaround.

### Database lint reports platform-owned issues

Do not hide genuine PLANETS errors.

If `supabase db lint` reports warnings/errors originating solely from untouched Supabase-managed schemas:

- determine whether schema scoping or lint severity can focus on project-owned objects;
- document any unavoidable platform noise;
- do not disable database linting entirely.

### Type generation is nondeterministic

If regenerated local types differ due to timestamps, ordering, or environment noise, identify the cause rather than normalizing arbitrary output.

The checked-in type file must be deterministically reproducible from committed schema and pinned tooling.

## Validation required

Run and report exact commands/results.

At minimum, where the environment supports the local stack:

```text
npm ci
npm run db:start
npm run db:reset
npm run db:lint
npm run db:test
npm run db:types
git diff --exit-code -- <generated-type-path>
npm run check:db
npm run db:stop
```

Also run the existing non-database validation relevant to touched configuration/documentation:

```text
npm run format:check
npm run check
git diff --check
```

If root formatting intentionally does not include SQL, add an appropriate simple SQL formatting convention only if a current repository tool already supports it. Do not introduce a large SQL-formatting dependency solely for aesthetics.

### Clean-reset proof

The database must be validated from a fresh state, not only incrementally from a developer's existing container volume.

A successful `supabase db reset` after the local stack starts is required evidence that all committed migrations replay correctly.

### PR CI proof

Open a focused pull request and inspect GitHub Actions.

Do not report success while the database job is failing or still known-broken.

## Acceptance criteria

The task is complete when:

- [ ] roadmap plan 01 is documented as split into 01A and 01B;
- [ ] plan 01 parent status is `In progress`;
- [ ] canonical SQL migration workflow is documented;
- [ ] at least one foundation migration exists and replays from zero;
- [ ] `private` exists and is not exposed through the Data API;
- [ ] client roles cannot directly use `private`;
- [ ] local Supabase automatic new-table exposure is explicitly disabled where supported;
- [ ] PostgreSQL default privileges for PLANETS-owned public objects fail closed for client roles;
- [ ] routine/function default execution is explicitly protected;
- [ ] PostGIS is installed reproducibly outside `public`;
- [ ] pgTAP tests enforce the public-table RLS invariant;
- [ ] pgTAP tests verify fail-closed default grants with disposable probe objects;
- [ ] pgTAP tests verify private-schema isolation;
- [ ] pgTAP tests verify PostGIS placement/availability;
- [ ] `supabase db lint` is part of the database validation flow;
- [ ] root database scripts expose reset/lint/test/type/check operations;
- [ ] TypeScript database types are generated locally and committed;
- [ ] CI regenerates types and fails on drift;
- [ ] the GitHub database job performs start → reset → lint → tests → type check → stop;
- [ ] no remote Supabase project or secrets are required;
- [ ] no product/application tables were introduced;
- [ ] no auth/profile, audit/outbox, notification, location, proposal, or UI behavior leaked into 01A;
- [ ] documentation explains what a future feature migration must do to expose a table/function safely;
- [ ] all applicable CI jobs pass.

## Autonomy and stop conditions

Decide ordinary SQL/test/file organization autonomously when consistent with this prompt.

You may decide:

- one versus several foundation migration files;
- exact pgTAP test filenames;
- exact root database script names if they remain clear;
- exact generated TypeScript type path within the existing web application;
- whether database workflow docs live in a dedicated `docs/development/` file;
- whether the security/migration decision deserves one ADR;
- exact non-public extension schema when required by the current supported PostGIS setup.

Stop and report before:

- exposing `private`;
- changing the accepted public/private responsibility boundary;
- adding a product table;
- adding auth/profile schema;
- adding a `SECURITY DEFINER` application helper to work around an architectural problem;
- modifying Supabase-managed tables/schemas structurally;
- linking/provisioning a remote project;
- weakening fail-closed grants because tests are inconvenient;
- replacing migrations with declarative schemas;
- adding a third-party database testing package merely for convenience;
- absorbing 01B or plan 02.

## Deliverables

Produce:

1. foundation migration(s);
2. fail-closed Supabase/API configuration;
3. PostGIS foundation;
4. pgTAP test harness and invariant tests;
5. root database scripts;
6. generated TypeScript database types;
7. upgraded database CI validation;
8. concise database workflow/security documentation;
9. relevant ADR/update if warranted;
10. roadmap update showing 01A/01B and parent plan 01 in progress;
11. focused pull request from a dedicated branch, preferably named similarly to `codex/01a-database-security-foundation`;
12. completion report.

Do not merge the pull request yourself unless the active execution environment explicitly instructs you to do so.

## Completion report

Return:

1. **Summary**
2. **Changed areas/files**
3. **Migration structure**
4. **Security defaults**
   - exposed schemas;
   - auto-exposure setting;
   - default table/sequence/function privileges;
   - private-schema grants;
5. **PostGIS**
   - version;
   - installation schema;
6. **Database tests**
   - invariant tests added;
   - exact pgTAP result;
7. **Generated types**
   - path;
   - generation command;
   - drift check result;
8. **Validation**
   - exact commands and pass/fail/not-run results;
9. **CI status**
10. **External/manual setup remaining**
11. **Known limitations/deferred work**
12. **Warnings/blockers for 01B**
13. **Pull request/commit reference**

Do not describe parent roadmap plan 01 as implemented. Only 01A is complete after this pull request; 01B still owns the identity/profile anchor, audit primitives, and transactional outbox.
