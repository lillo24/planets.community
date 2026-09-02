# Database development

PostgreSQL is the canonical PLANETS product record. This guide owns the local schema-change, security-test, and generated-type workflow. The current foundation includes the application identity anchor plus private audit/outbox primitives; product feature tables remain deferred.

## Source of truth and daily workflow

Timestamped SQL files under `supabase/migrations/` are the only canonical schema history. PLANETS does not maintain a parallel `supabase/schemas/` declarative representation.

Start the local stack, generate a migration with the project-scoped CLI, edit the generated SQL, and replay the complete history:

```text
npm run db:start
npx supabase migration new concise_change_name
npm run db:reset
```

Never rewrite a migration that a shared environment may have applied; add a later migration. `npm run db:reset` is destructive only to the local database selected by the explicit `--local` script flag. It applies all migrations in timestamp order and then runs `supabase/seed.sql`.

The seed file is for deterministic development/test rows without real personal data. Keep schema, grants, policies, functions, and extensions in migrations rather than seeds. Plan 01A intentionally seeds nothing.

Later migrations should use lowercase `snake_case`, UUID primary keys for ordinary application entities unless a stronger reason exists, and the relevant `auth.users.id` for an auth-linked entity when appropriate. Timestamps use `timestamptz`; `created_at` is normally non-null with a database default, while `updated_at` is added only when useful and must be maintained server-side. Express enforceable invariants as constraints and choose each foreign key's delete behavior deliberately rather than defaulting mechanically to cascade.

There is no universal soft-delete or content-state convention. Deletion, anonymization, historical retention, and moderation state have product and legal consequences and belong to their later plans.

## Identity and shared operational primitives

Supabase Auth owns login identity in `auth.users`. `public.profiles` is the one-to-one PLANETS application identity anchor and reuses that Auth UUID as its primary key. It currently contains only `id` and a database-generated `created_at`; plan 03C owns profile data and visibility. There is no automatic Auth signup trigger, so an Auth user without an application profile is valid until an authenticated application flow explicitly creates the anchor.

Authenticated users receive table-level `SELECT` plus column-level `INSERT (id)` and RLS limits both operations to their own UUID. `anon` and `service_role` receive no profile grant, and clients receive no update/delete path. The column-level insert grant keeps `created_at` canonical.

The profile and audit-actor foreign keys restrict raw deletion from `auth.users`. This intentional failure guard prevents application identity or audit history from being silently destroyed before plan 10 defines cleanup, anonymization, and lawful retention. Do not replace it with cascade or nulling as an incidental feature migration.

`private.audit_events` is append-oriented operational/security history rather than user analytics; generic metadata must avoid bodies, tokens, exact locations, and unnecessary personal data. `private.outbox_events` is a transaction-local handoff record whose UUID supplies a stable event identity. Its availability/publication fields and pending index prepare later dispatch without implementing a queue, retries, notifications, or provider delivery. Neither private table has direct client privileges or Data API exposure.

## Public and private schemas

`public` is the PLANETS Data API schema. It remains listed in `[api].schemas` and is the only schema where later client-facing tables, views, or routines may be defined. Listing a schema makes it API-addressable; it does not grant object access by itself.

`private` owns non-API data and implementation details. It is deliberately absent from `[api].schemas`, and `anon`, `authenticated`, and `service_role` have neither `USAGE` nor `CREATE` on it. Do not grant `service_role` broad access as a convenience: it bypasses RLS, so any future access must be narrow, explicit, and justified by the owning plan.

PostGIS is installed into the existing non-API `extensions` schema. Qualify spatial types and functions as `extensions.geometry`, `extensions.st_point`, and similar names in migrations and tests. Location tables, precision, and visibility rules are not defined by this foundation.

## Fail-closed access

The local config pins `auto_expose_new_tables = false`. The foundation migration also changes PostgreSQL default privileges for objects created by the `postgres` role in `public` and `private`:

- tables and sequences grant nothing to PostgreSQL `PUBLIC`, `anon`, `authenticated`, or `service_role`;
- functions grant no `EXECUTE`, including PostgreSQL's built-in `PUBLIC EXECUTE` default;
- client roles cannot create objects in `public`;
- the owner retains its inherent owner privileges.

Default privileges are scoped to the object creator. Supabase migrations run as `postgres`, and the pgTAP probes assert that ownership assumption. PostgreSQL's built-in routine grant is global rather than schema-local, so removing `PUBLIC EXECUTE` intentionally applies to every future function created by `postgres`; each callable function must opt in explicitly. If a future migration runner creates PLANETS objects as another role, add and test equivalent `ALTER DEFAULT PRIVILEGES FOR ROLE ...` rules before using it.

For every future ordinary table in `public`, keep the following in one reviewed migration:

1. create the table and constraints;
2. enable RLS explicitly with `alter table ... enable row level security`;
3. add policies for the intended actors and operations;
4. grant only the exact table privileges each actor needs;
5. grant only the required sequence privileges when inserts depend on a sequence;
6. add pgTAP coverage for grants, denials, policies, and relevant concurrency/constraint behavior.

For a client-callable function, review its security mode, explicitly grant `EXECUTE` only to intended roles, and test every other role's denial. This includes extension/PostGIS functions if a later feature calls one directly as a non-owner role. A later `SECURITY DEFINER` function requires a concrete need, a controlled `search_path`, explicit execution grants, tests, and no caller-controlled schema resolution; this foundation adds none. Do not rely on RLS to compensate for an excessive object grant, and do not rely on a UI to hide data.

## Tests, lint, and generated types

The native pgTAP files under `supabase/tests/` verify:

- the private schema boundary for all three Data API roles;
- PostGIS installation, non-public placement, type availability, and a basic spatial operation;
- an invariant that rejects any ordinary PLANETS table in `public` without RLS;
- disposable `postgres`-owned table, sequence, and function probes with no implicit client privileges;
- removal of those probes by transaction rollback.
- the profile anchor's Auth relationship, grants, RLS behavior, canonical timestamp, and restrictive deletion;
- two deterministic fake Auth identities exercising positive and negative profile access;
- audit/outbox constraints, defaults, indexes, restrictive actor deletion, and private client denial.

Run focused commands while the stack is already running:

```text
npm run db:reset
npm run db:lint
npm run db:test
npm run auth:verify:local
npm run db:types
npm run db:types:check
```

`db:lint` intentionally checks only `public` and `private`, avoiding warnings owned by Supabase-managed schemas or extensions. `db:types` regenerates `apps/web/src/types/database.generated.ts` from local `public`; its wrapper propagates CLI failures, rejects empty output, and normalizes only the terminal newline across hosts. The file is generated output and must not be hand-edited or formatted. `db:types:check` regenerates it and fails on a tracked diff.

`auth:verify:local` requests a numeric email OTP from local Auth, reads the new message through Mailpit's API, verifies the code, and inserts/reads the authenticated user's profile anchor through current RLS. It uses only deterministic `.invalid` test identity data and never prints the email, code, access token, or client key.

`npm run check:db` performs reset, the local Auth integration check, lint, pgTAP, regeneration, and drift detection as one validation sequence. It assumes `npm run db:start` has already succeeded and leaves stack lifecycle to the caller. CI starts Supabase, runs the same underlying steps, and always stops it.
