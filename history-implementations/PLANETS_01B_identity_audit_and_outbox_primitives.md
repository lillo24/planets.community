# PLANETS 01B — Identity, Audit, and Outbox Primitives

**Roadmap parent:** PLANETS 01 — Database foundation and security model  
**Task type:** Second and final portion of roadmap plan 01  
**Repository:** `lillo24/planets.community`  
**Target base:** latest `main`  
**Verified implementation base when this prompt was written:** PR #3 / PLANETS 01A merged as `0b2addce676478c73ff96b765d820729acb63f15`

## Objective

Complete the shared database foundation by adding the smallest durable application primitives that later product plans need:

1. a one-to-one application profile anchor linked to Supabase Auth;
2. a private append-oriented audit-event record;
3. a private transactional-outbox record.

The goal is **not** to implement authentication UX, profile features, notifications, or product domains. The goal is to give those later plans stable identities and transaction-local infrastructure while preserving the fail-closed security rules established by 01A.

After 01B is merged, parent roadmap plan 01 is complete and plan 02 may begin.

## Read before changing anything

Inspect the current repository and Git status first. At minimum read:

1. `AGENTS.md`
2. `README.md`
3. `docs/architecture/core-stack.md`
4. `docs/architecture/system-design.md`
5. `docs/architecture/decisions/0002-canonical-migrations-and-fail-closed-database-access.md`
6. `docs/development/database.md`
7. `docs/implementation/roadmap.md`
8. `package.json`
9. `.github/workflows/validation.yml`
10. `supabase/config.toml`
11. all current `supabase/migrations/*.sql`
12. all current `supabase/tests/*.sql`
13. `apps/web/src/types/database.generated.ts`

Inspect actual current `main`; do not assume the repository still exactly matches the merge SHA above.

## Current implemented foundation

01A established and CI verifies:

- timestamped SQL migrations are canonical;
- `public` is the API-facing application schema;
- `private` is not exposed through the Data API;
- automatic public-object exposure is disabled;
- objects created by the migration role `postgres` receive fail-closed client grants;
- PostgreSQL's creator-wide default `PUBLIC EXECUTE` for future `postgres` functions is revoked;
- every ordinary PLANETS table in `public` must have RLS enabled;
- PostGIS is installed under `extensions`;
- pgTAP tests run in CI;
- local database reset/lint/test/type-generation is reproducible;
- generated TypeScript types cover the local `public` schema and are drift-checked.

Preserve those conventions rather than recreating alternative ones.

## External context

No Google Doc, cloud project, provider credentials, staging environment, or production account is required.

Do not link a remote Supabase project or configure Firebase, Vercel, Sentry, Resend, PostHog, Cloudflare, or app stores.

Use only local Supabase plus repository evidence.

## Size boundary

01B should remain narrowly limited to:

- `public.profiles` as the application identity anchor;
- `private.audit_events`;
- `private.outbox_events`;
- policy/constraint/index tests for those primitives;
- generated types and documentation updates.

If implementation appears to require profile fields, authentication triggers, queue consumers, notification delivery, generic domain-event frameworks, admin roles, or deletion policy, stop that expansion and defer it.

## Decisions already made

### 1. Profile identity uses the Supabase Auth UUID

Use a one-to-one application profile anchor whose primary key is the corresponding `auth.users.id`.

Prefer the simple shape:

```text
public.profiles.id UUID PRIMARY KEY -> auth.users.id
```

Do not add a second surrogate profile identifier.

Later domain records can reference the stable application profile identifier without exposing the `auth` schema through the API.

### 2. Do not automatically create profiles from an Auth trigger yet

Do **not** add an `auth.users` signup trigger in 01B.

Plan 03 owns authentication and profile-completion behavior. It can explicitly create the profile anchor after a valid authenticated session.

This avoids coupling signup availability to a trigger before the application flow exists.

### 3. Raw Auth deletion must not silently destroy application identity

Do not use `ON DELETE CASCADE` from `public.profiles` to `auth.users`.

Use a restrictive/default referential action so deleting an Auth user while its application profile still exists fails rather than silently erasing application identity.

This is intentional even though generic Supabase profile examples often use cascade. PLANETS expects historical proposals/participation and later has a dedicated account-deletion/privacy plan. Plan 10 must explicitly define cleanup/anonymization/retention before Auth identity deletion is allowed to destroy related application state.

Do not implement the deletion workflow now.

### 4. The initial profile is deliberately skeletal

`public.profiles` should contain only identity/foundation fields that are already certain.

At minimum:

- `id`;
- `created_at`.

Do **not** add yet:

- display name;
- biography;
- avatar/photo;
- location;
- CAP/postal code;
- competences;
- interests;
- preferences;
- participation counters;
- badges;
- notification settings;
- visibility flags;
- moderation state;
- `updated_at` merely for future use.

Plan 03 owns real profile data and visibility.

### 5. Profile creation is self-service, but narrow

The authenticated user may create their own profile anchor and read their own anchor.

Do not expose all profiles publicly yet.

Use explicit grants plus RLS:

- `anon`: no table access;
- `authenticated`: only the minimum operations required to insert/read their own anchor;
- `service_role`: no new direct grant merely for convenience.

Prefer column-level `INSERT` permission if practical so the client may supply `id` but cannot override canonical server-generated timestamps.

Do not grant `UPDATE` or `DELETE` while the table has no client-mutable fields and deletion behavior is unresolved.

### 6. Audit events are private operational history

Create a minimal `private.audit_events` table for security-relevant and administrative/domain actions later recorded by trusted database/server operations.

It is not a user analytics table.

It is not exposed to client roles.

Use a restrained structure such as:

- UUID event ID;
- non-empty action/event name;
- optional actor user UUID;
- optional target type;
- optional target UUID;
- JSON object metadata;
- canonical creation timestamp.

Exact column names are Codex's choice after inspecting repository naming conventions.

Do not introduce an enum or centralized action registry yet.

Do not store message bodies, access tokens, exact location data, or unnecessary PII in generic audit metadata.

### 7. Audit retention remains unresolved, so deletion fails closed

If `actor_user_id` references `auth.users`, use a restrictive/default delete action rather than cascade or automatic nulling.

This deliberately prevents raw Auth deletion from silently rewriting audit history before plan 10 defines lawful retention/anonymization behavior.

A system-generated audit event may have a null actor.

A polymorphic target identifier should not require foreign keys to every future product table.

### 8. Outbox is a durable transaction record, not the delivery system

Create a minimal `private.outbox_events` table representing external/background work that has been committed as part of the same database transaction as a future domain action.

At minimum it should be able to represent:

- unique event ID;
- non-empty event type;
- JSON object payload;
- creation time;
- optional/not-before availability time if useful;
- whether/when the event has been handed off/processed by a later dispatcher.

Keep it small.

Do not implement:

- Supabase Queues consumption;
- cron;
- FCM;
- Resend;
- retry-attempt tables;
- exponential backoff;
- dead-letter queues;
- notification records;
- queue workers;
- Edge Functions.

Those belong primarily to plan 06.

The outbox event ID itself can act as the stable delivery/idempotency identity. Do not add a second speculative idempotency-key system unless a concrete need appears.

### 9. Do not add generic write-helper functions unless needed

Future canonical domain functions can insert audit/outbox rows transactionally.

01B does not need generic `write_audit_event()` or `enqueue_event()` database APIs merely to hide ordinary `INSERT` statements.

If Codex believes a permanent helper function is materially better, remember that 01A revoked implicit function execution creator-wide: every callable function needs a deliberate `EXECUTE` grant. Do not add a `SECURITY DEFINER` helper without a concrete requirement.

## Required work

### A. Add the profile-anchor migration

Create a new forward migration; do not edit the merged 01A migration.

Define `public.profiles` with:

- UUID primary key tied to `auth.users.id`;
- restrictive Auth-user deletion behavior;
- `created_at timestamptz not null default now()` or the equivalent existing convention;
- explicit RLS enablement;
- explicit reviewed grants;
- explicit operation-specific policies.

Use policy names that state the actor and operation.

For the current skeletal table:

- authenticated users can read only their own row;
- authenticated users can insert only a row whose `id` equals their own authenticated user ID;
- unauthenticated users have no access;
- authenticated users cannot insert another user's row;
- no client update/delete path exists.

Prefer the optimized Supabase RLS pattern `(select auth.uid())` and explicitly target `authenticated`.

Do not add a public profile view yet.

### B. Add test identities without production helpers

Extend the pgTAP suite to test policies as real database roles/JWT identities.

Do not add Basejump or another remote test-helper dependency unless current native local testing proves insufficient.

Use deterministic fake Auth users inside test transactions or another repository-local approach that:

- modifies no Supabase-managed schema structure;
- leaves no persistent fake user after rollback/reset;
- permits testing `auth.uid()` under `authenticated`;
- keeps tests readable.

A small test-only helper in the test transaction is acceptable if it is not installed as permanent production schema machinery.

### C. Profile RLS and grant tests

At minimum prove:

- RLS is enabled;
- `profiles.id` references the primary Auth user identifier;
- the FK is not cascade-delete;
- `anon` cannot select or insert;
- authenticated user A can insert A's anchor;
- authenticated user A cannot insert B's anchor;
- A can select A;
- A cannot select B;
- B can select B but not A;
- client code cannot update/delete profiles with current grants;
- the canonical `created_at` cannot be arbitrarily supplied by the client if column-level insert grants are used;
- deleting `auth.users` directly while the profile exists is rejected rather than silently deleting the profile.

Use SQL privilege assertions as well as RLS behavior assertions. A policy alone is not sufficient evidence.

### D. Add `private.audit_events`

Create the minimal audit table with constraints that reject obviously malformed records.

Prefer:

- UUID PK with server/database-generated value;
- `action`/`event_type` non-empty after trimming;
- nullable actor Auth UUID;
- nullable target type/UUID;
- JSONB metadata defaulting to an object;
- a check that metadata is a JSON object;
- `created_at timestamptz not null default now()`.

Add only indexes justified by expected operational lookup, such as chronological lookup and actor lookup. Avoid speculative indexing every field.

No client role should receive direct table privilege.

Do not enable RLS merely as ceremony on an unexposed private table; private-schema isolation plus grants is the primary boundary unless current repository rules require otherwise.

### E. Add `private.outbox_events`

Create the minimal transactional outbox.

A suitable shape may include:

- UUID PK;
- non-empty `event_type`;
- JSONB object `payload`;
- `created_at`;
- optional `available_at` defaulting to current time;
- nullable `published_at`/`processed_at`.

If both availability and completion timestamps exist, add simple consistency checks where meaningful.

Add a partial index supporting later retrieval of pending events, for example by availability/creation order where completion is null.

Do not add worker-lock columns, attempt counts, provider-specific data, or notification semantics yet.

No client role should have direct access.

### F. Audit/outbox tests

Add pgTAP coverage proving:

- both tables exist in `private`;
- API/client roles cannot use or directly access them;
- valid rows can be created by the trusted migration/test owner;
- empty audit action/event type is rejected;
- empty outbox event type is rejected;
- audit metadata/outbox payload must be JSON objects if that constraint is selected;
- key timestamps/defaults work;
- the pending-outbox index exists and matches the intended pending predicate;
- direct Auth-user deletion is not allowed to silently mutate/delete actor-linked audit history if an actor FK is present.

Do not test hypothetical queue processing behavior.

### G. Preserve 01A security invariants

All existing 01A tests must continue passing.

In particular:

- every ordinary `public` table still has RLS;
- `private` stays unavailable to client roles;
- new public objects do not receive implicit client grants;
- new callable functions do not receive implicit `PUBLIC EXECUTE`;
- PostGIS remains under `extensions`.

Do not weaken existing tests to accommodate 01B.

### H. Generated public types

Regenerate `apps/web/src/types/database.generated.ts`.

The generated `public` types should now include the profile anchor.

They should not expose private audit/outbox tables because type generation remains scoped to the API-facing `public` schema.

Type drift must remain clean in CI.

Do not add a Supabase JavaScript client in this task.

### I. Documentation

Update the database/system documentation to record:

- `auth.users` is authentication identity;
- `public.profiles` is the application identity anchor;
- profile feature fields are deliberately deferred to plan 03;
- there is no automatic Auth signup trigger yet;
- raw Auth deletion is deliberately blocked by restrictive relationships until the account-deletion plan defines cleanup;
- audit/outbox tables live in `private`;
- audit is operational/security history, not analytics;
- outbox is a transaction-local handoff record, not the queue/delivery implementation;
- future migrations creating callable functions must explicitly grant required `EXECUTE`, including PostGIS/extension functions when a later feature needs direct caller execution.

Do not duplicate entire architecture docs.

### J. Roadmap status

Within the PR:

- mark 01A as `Implemented`;
- mark 01B as `In progress`;
- keep parent plan 01 as `In progress`;
- keep plan 02 `Not started`;
- set the immediate next action to complete/merge 01B before plan 02.

Do not mark parent 01 implemented before the 01B PR is merged.

## Non-goals

Do not implement:

- login/signup/OTP UI or API integration;
- automatic profile creation trigger;
- display-name/avatar/location/competence/profile preference fields;
- public profile browsing;
- profile editing;
- user suspension/moderation;
- notification preferences;
- proposal tables;
- participation tables;
- chat;
- actual location records;
- PostGIS query APIs;
- audit-writing domain functions;
- outbox consumer/dispatcher;
- Supabase Queues/Cron;
- Edge Functions;
- FCM/email;
- service-role server API;
- Sentry/PostHog;
- Flutter/Next.js Supabase client initialization;
- account deletion;
- data export;
- legal retention/anonymization policy;
- generic event bus architecture.

## Important edge cases

### Auth row exists but profile does not

This is a valid transitional state.

01B must not assume every Auth user has a profile automatically. Plan 03 will decide when profile completion is required.

### Duplicate profile creation

The primary key must make duplicate creation fail deterministically.

Do not implement an upsert policy that could hide duplicate lifecycle bugs unless plan 03 later needs it.

### Unauthenticated `auth.uid()`

Unauthenticated access must not rely only on `auth.uid() = id`, because `auth.uid()` is null without a session. Policies should explicitly target `authenticated`, and grants should leave `anon` without profile access.

### Auth deletion

A raw deletion of an Auth user with application/audit dependencies should fail.

Do not "fix" that failure with cascade during this task. It is the intended guard until plan 10.

### `service_role`

01A intentionally removed implicit service-role grants. Do not restore broad service-role table access.

Future server operations can receive narrowly reviewed privileges as they are introduced.

### PostGIS/function execution

01A removed creator-wide default `PUBLIC EXECUTE` for future `postgres` functions. If tests or implementation need a PostGIS function as a non-owner role, grant only the required execution privilege explicitly and document why. Do not undo the global fail-closed function default.

## Validation required

Run all relevant existing checks plus new database tests.

Where local containers work:

```text
npm ci
npm run db:start
npm run check:db
npm run format:check
npm run check
git diff --check
npm run db:stop
```

`check:db` must include clean reset, database lint, all pgTAP tests, generated-type regeneration, and drift detection.

If local Docker is unavailable, use the existing GitHub Database CI job for container-backed evidence and report local commands accurately as not run.

Inspect final PR CI. Database, Mobile, and Web jobs must pass before declaring success.

## Acceptance criteria

01B is ready for merge when:

- [ ] a new forward migration adds `public.profiles`;
- [ ] profile ID is one-to-one with `auth.users.id`;
- [ ] Auth deletion does not cascade-delete the profile;
- [ ] profile has only minimal foundation fields;
- [ ] profile RLS is enabled;
- [ ] `anon` has no profile access;
- [ ] authenticated users can insert/read only their own anchor;
- [ ] authenticated users cannot update/delete profiles yet;
- [ ] there is no Auth signup trigger;
- [ ] pgTAP tests exercise multiple fake authenticated identities;
- [ ] policy tests cover grants and row visibility/write checks;
- [ ] `private.audit_events` exists with minimal validity constraints;
- [ ] `private.outbox_events` exists with minimal validity constraints and a pending-work index;
- [ ] neither private primitive is directly accessible to API client roles;
- [ ] no queue/notification/worker behavior was introduced;
- [ ] existing 01A security invariants still pass;
- [ ] public generated TypeScript types include profiles but not private primitives;
- [ ] database lint passes;
- [ ] generated type drift passes;
- [ ] all GitHub CI jobs pass;
- [ ] documentation records the identity/private-primitives boundaries and deletion guard;
- [ ] 01A is recorded implemented and 01B in progress within the open PR;
- [ ] parent plan 01 remains in progress until this PR is merged;
- [ ] plan 02 remains untouched.

## Autonomy and stop conditions

Decide ordinary SQL names, constraint names, index names, and test-file organization autonomously.

You may choose:

- exact audit/outbox column names consistent with the behavior above;
- whether `available_at` is worthwhile in the minimal outbox;
- exact pgTAP fake-auth setup;
- exact policy names;
- exact private-table indexes;
- whether a small documentation/ADR update is needed.

Stop and report before:

- adding real profile fields;
- making profiles publicly readable;
- using cascade deletion from Auth;
- adding automatic Auth triggers;
- deciding legal audit-retention duration;
- adding a queue worker or delivery state machine;
- adding `SECURITY DEFINER` helpers without a concrete requirement;
- granting broad `service_role` access;
- weakening 01A fail-closed defaults;
- modifying Supabase-managed Auth schema structure;
- absorbing plan 02 or 03.

## Deliverables

Produce:

1. forward migration(s) for the profile/audit/outbox primitives;
2. profile grants and RLS policies;
3. pgTAP identity/RLS/private-primitive tests;
4. regenerated public TypeScript database types;
5. concise documentation updates;
6. roadmap update;
7. a focused pull request, preferably on a branch similar to `codex/01b-identity-audit-outbox`;
8. completion report.

Do not merge the pull request yourself unless explicitly instructed by the active execution environment.

## Completion report

Return:

1. **Summary**
2. **Changed areas/files**
3. **Profile anchor**
   - columns;
   - Auth FK/delete behavior;
   - grants;
   - RLS policies;
4. **Test identities/RLS**
   - how fake Auth identities are created;
   - positive/negative cases;
5. **Audit primitive**
   - columns/constraints/indexes;
   - client access;
6. **Outbox primitive**
   - columns/constraints/indexes;
   - client access;
7. **Generated types**
   - path and drift result;
8. **Validation**
   - exact commands/results;
9. **CI status**
10. **External/manual setup**
11. **Deferred work**
12. **Warnings/blockers for plan 02**
13. **Pull request/commit reference**

Do not report parent roadmap plan 01 as implemented until this PR has been merged.
