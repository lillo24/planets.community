# PLANETS SITE-02W — Migrate Informational Site from Pages Functions to Workers Static Assets

## Objective

Migrate the already-implemented PLANETS informational site deployment model from **Cloudflare Pages + Pages Functions** to **Cloudflare Workers + Static Assets**, before any production deployment has been created.

This is a narrow infrastructure/runtime migration.

The user-facing website and SITE-02 waitlist behavior must remain unchanged:

- Vite/React static informational site;
- same landing page and branding;
- same `POST /api/waitlist` contract;
- same D1 schema and migration history;
- same Turnstile validation;
- same one-time launch-email consent;
- same duplicate/idempotency behavior;
- same privacy/data-minimization boundary;
- no production deployment or DNS change yet.

The goal is to leave `apps/site` ready to be connected through Cloudflare's current **Workers** Git deployment flow rather than the legacy Pages workflow.

---

## Why this change is being made now

No production Cloudflare site has been deployed yet, so this is the lowest-cost point to adopt Cloudflare's current primary application platform.

Current Cloudflare documentation recommends Workers Static Assets for new applications and provides an official Pages-to-Workers migration path. Workers supports the capabilities PLANETS already needs—Static Assets, D1, secrets/bindings, and Worker code—while providing the broader platform Cloudflare is actively extending.

Do not reinterpret this as a reason to add more Cloudflare services or product features.

This task is only:

> Pages deployment structure → native Workers deployment structure.

---

## Repository evidence verified when this prompt was prepared

Current merged SITE-02 is on `main`.

Relevant current implementation includes:

### `apps/site/wrangler.jsonc`

It currently contains a Pages-specific configuration:

- `name: "planets-public-site"`
- `compatibility_date: "2026-09-13"`
- `pages_build_output_dir: "./dist"`
- D1 binding `WAITLIST_DB`
- placeholder all-zero D1 `database_id`
- `migrations_dir: "migrations"`

### `apps/site/package.json`

SITE-02 currently uses:

- Vite 8.3;
- React 19.2.8;
- TypeScript;
- Wrangler 4.131.1;
- `@cloudflare/vitest-plugin`;
- `@cloudflare/workers-types`.

Pages-specific/local scripts include:

- `dev:waitlist`: build then `wrangler pages dev`;
- D1 local migration/inspection/reset commands;
- separate client and Cloudflare runtime test suites.

### Waitlist implementation

The reusable waitlist handler already lives in:

- likely `apps/site/functions/waitlist.ts`

and owns:

- request/method/content-type validation;
- request size and payload shape limits;
- email validation/normalization;
- explicit consent;
- server-side Turnstile Siteverify;
- exact expected action/hostname checks;
- local official-test-key mode;
- prepared D1 insert;
- idempotent `ON CONFLICT DO NOTHING`;
- privacy-safe errors/logging.

The Pages routing wrapper is currently:

- likely `apps/site/functions/api/waitlist.ts`

and only maps the Pages Function request to the reusable handler.

### Static site

The site already builds to `apps/site/dist/`.

There is no Node server and no need to introduce one.

---

## Inspect before editing

Before implementation, read current:

- `AGENTS.md`
- root `package.json`
- `apps/site/package.json`
- `apps/site/wrangler.jsonc`
- `apps/site/vite.config.ts`
- `apps/site/README.md`
- all `apps/site/functions/**`
- all SITE-02 Cloudflare tests/config
- `apps/site/migrations/**`
- `.github/workflows/validation.yml`
- `docs/architecture/decisions/0004-separate-static-informational-site.md`
- `docs/implementation/roadmap.md`
- `implementation_plan_sections_suggestions.md`

Also inspect current Cloudflare official documentation compatible with the resolved Wrangler/Vite versions, especially:

- Migrate from Pages to Workers;
- Workers Static Assets;
- Wrangler static-assets configuration;
- Workers D1 bindings;
- Workers preview/`workers.dev` behavior.

Repository code remains the source of truth for existing behavior. Current Cloudflare docs are the source of truth for deployment syntax.

---

# Architecture target

Prefer a **native Worker entry point plus Workers Static Assets**, while preserving the existing Vite client build.

The intended shape is conceptually:

```text
apps/site/
  src/                 # existing React/Vite site
  worker/
    index.ts            # native Worker request entry point
  migrations/          # existing D1 migrations
  dist/                # Vite static output
  wrangler.jsonc
```

Exact names may vary if current repo conventions justify it.

## Request routing

The Worker should own the dynamic route:

```text
POST /api/waitlist
```

and delegate it to the existing reusable SITE-02 handler rather than reimplementing its logic.

Static website requests should be served through Workers Static Assets.

Do not keep Pages file-based routing as the canonical production architecture merely to avoid changing the tiny route wrapper.

Because there is only one API endpoint, a small explicit Worker router is preferable to introducing a routing framework.

Do **not** add Hono, React Router server features, Next.js, or another framework for one endpoint.

---

# Wrangler migration

Replace Pages-specific configuration with current Workers configuration.

At a minimum, reconcile:

```text
pages_build_output_dir
```

into the current Workers Static Assets configuration, conceptually:

```jsonc
{
  "main": "./worker/index.ts",
  "assets": {
    "directory": "./dist",
    "binding": "ASSETS"
  }
}
```

Use the exact current Wrangler schema and syntax after verifying official docs.

Preserve:

- Worker name unless a concrete naming conflict exists;
- current compatibility date unless current migration guidance requires an intentional update;
- D1 binding name `WAITLIST_DB`;
- migrations directory;
- placeholder/no-production-resource discipline.

Do not commit a real production D1 database ID in this migration unless repository/provider conventions require it later in SITE-03.

## Static routing behavior

Choose explicit Workers Static Assets behavior appropriate for this site.

The current site uses one landing page with anchor navigation rather than client-side URL routes, so do not add SPA fallback behavior unless the actual merged implementation now requires it.

The `/api/waitlist` path must reach the Worker and never be mistaken for a static asset.

Other existing static assets must continue to be served correctly.

Avoid running the Worker for every static asset request unless required. Prefer the ordinary Workers Static Assets fast path where static files are served directly and the Worker handles non-asset/API requests.

If an `ASSETS` binding is used, keep fallback behavior explicit and testable.

---

# Worker entry point

Create a small native Worker entry point.

It should:

1. parse the request URL;
2. route `/api/waitlist` to the existing SITE-02 waitlist handler;
3. preserve expected method handling from the existing handler;
4. serve/fall through to static assets according to the selected Workers Static Assets configuration;
5. return an appropriate response for unknown dynamic routes.

Do not move SITE-02 business/security logic into the entry point.

Keep the waitlist handler independently testable.

If the existing `functions/waitlist.ts` path becomes semantically misleading after Pages is removed, move/rename it conservatively to an appropriate Worker/server module and update all imports/tests. Do not refactor its internals unless required for the runtime migration.

---

# Remove Pages-specific production structure

Once native Workers routing is proven:

- remove the Pages route wrapper that is no longer needed;
- remove Pages-only types/configuration;
- remove `wrangler pages dev` usage;
- remove Pages-specific documentation wording;
- remove stale Pages deployment instructions.

Do not delete reusable waitlist logic or tests.

Run a repository-wide search for:

- `PagesFunction`
- `pages_build_output_dir`
- `wrangler pages`
- `Pages Functions`
- other Pages-only assumptions

and classify each occurrence before changing it.

Historical archived implementation prompts may of course continue to mention Pages as historical fact. Do not rewrite archived history merely to make searches empty.

---

# Local development

Preserve two useful modes:

### Static visual development

The existing fast Vite-only command may remain for layout work:

```text
npm run dev:site
```

or the equivalent current command.

It does not need D1/API behavior.

### Full waitlist development

Replace the Pages runtime command with a Workers-compatible local development flow.

The full local environment must still support:

- Vite-built/static assets;
- native Worker entry point;
- local D1;
- official Turnstile testing mode;
- real local `/api/waitlist` requests.

Prefer the simplest current Wrangler/Workers workflow.

If `wrangler dev` requires building client assets first, encode that reliably in repository scripts.

Do not make local development hit remote D1 by default.

---

# Cloudflare Vite plugin

Do **not** add `@cloudflare/vite-plugin` automatically.

First determine whether the existing simple architecture benefits materially from it.

The current site already has:

- a working Vite client build;
- a very small Worker boundary;
- Cloudflare runtime tests.

A direct `vite build` + `wrangler dev/deploy` structure is acceptable and likely simpler.

Use the Cloudflare Vite plugin only if current official guidance and repository inspection show it substantially simplifies the combined Worker/client build without creating unnecessary migration scope.

If added, explain why in the completion report and update the build/test workflow accordingly.

Do not introduce it merely because it exists.

---

# D1

The D1 model and behavior are not being redesigned.

Preserve exactly:

- binding name `WAITLIST_DB`;
- existing migration history;
- existing `launch_waitlist` schema;
- existing normalization/duplicate behavior;
- local migration commands or equivalent Workers-compatible replacements;
- local-only defaults for development.

Do not create a real production D1 database in this task.

SITE-03 will provision and bind the real database.

---

# Turnstile

Preserve SITE-02 behavior exactly:

- client receives only the public site key;
- server receives the secret;
- server validates with Siteverify;
- expected hostname/action checks remain;
- official testing-key mode remains local/test only;
- no real production credentials are introduced.

Do not weaken production validation to make Workers migration easier.

---

# Environment/bindings

Update Worker environment typing so the native Worker entry point has typed access to:

- `WAITLIST_DB`;
- `TURNSTILE_SECRET_KEY`;
- `TURNSTILE_EXPECTED_ACTION`;
- `TURNSTILE_EXPECTED_HOSTNAME`;
- `TURNSTILE_TESTING_MODE`;
- static-assets binding if explicitly used.

Do not expose server secrets through `VITE_*`.

Keep browser and Worker environment types separated where appropriate.

---

# Tests

This migration must prove behavioral equivalence rather than only compiling.

Preserve all existing SITE-02 tests and adapt only the runtime-specific test harness where necessary.

At minimum verify:

## Worker routing

- `/api/waitlist` reaches the waitlist handler;
- valid POST still works;
- invalid method behavior remains correct;
- unknown API/dynamic routes do not expose static/private files;
- static asset requests are served correctly.

## Waitlist behavior

Existing coverage must remain green for:

- input/body validation;
- explicit consent;
- Turnstile success/failure;
- D1 persistence;
- duplicate idempotency;
- privacy-safe errors;
- no personal-data logging.

## Local integration smoke

Run the full native Workers local runtime and verify:

1. homepage loads;
2. logo/static assets load;
3. waitlist request reaches Worker;
4. synthetic test email is inserted in local D1;
5. duplicate submission does not create a second row;
6. invalid Turnstile path fails;
7. no Node server is required.

If possible, ensure this smoke path no longer invokes any `wrangler pages ...` command.

---

# CI and scripts

Update package/root scripts to use Workers terminology and commands.

Keep:

- client tests;
- Cloudflare runtime tests;
- lint;
- typecheck;
- static build;
- full root validation.

Remove or rename scripts whose names/commands incorrectly imply Pages.

Do not make CI require:

- Cloudflare login;
- production D1;
- real Turnstile credentials;
- network deployment.

SITE-02W must remain reproducible in ordinary PR CI.

---

# Documentation / architecture

Update the nearest authoritative documentation so future agents do not reintroduce Pages.

At minimum update:

- `apps/site/README.md`;
- roadmap/site mini-track wording where it refers specifically to Pages;
- architecture documentation where Cloudflare deployment/runtime is described.

Because this establishes a lasting production-runtime direction for `apps/site`, inspect the repository ADR convention.

If warranted, add a concise ADR recording:

> `apps/site` uses Cloudflare Workers with Static Assets for the site runtime and waitlist API; D1 and Turnstile remain the selected SITE-02 services.

Alternatively update ADR 0004 only if repository conventions clearly prefer extending that decision rather than adding a new material decision record.

Do not create documentation purely ceremonially.

Historical implementation archives should remain unchanged except for archiving this new prompt.

---

# Roadmap classification

This is a corrective/migration task between SITE-02 and SITE-03, not a new product feature.

Record it using a clear identifier such as:

```text
SITE-02W — Workers runtime migration
```

or the repository's preferred naming convention.

After merge:

- SITE-00: Implemented
- SITE-01: Implemented
- SITE-02: Implemented
- SITE-02W: Implemented
- SITE-03: still responsible for production Cloudflare provisioning/deployment and domain work
- SITE-04: still responsible for launch notification/retirement

Do not claim SITE-03 is implemented.

---

# Non-goals

Do not:

- deploy to Cloudflare;
- connect the GitHub repository in the Cloudflare dashboard;
- create production Worker resources;
- create production D1;
- create production Turnstile widgets;
- add real secrets;
- change DNS;
- attach `planets.community`;
- send launch emails;
- change waitlist consent semantics;
- change the D1 schema unless a runtime incompatibility genuinely requires it;
- add analytics;
- add rate limiting simply because Workers supports it;
- add Cron, Queues, Durable Objects, R2, KV, or other Workers features;
- redesign the website;
- modify `apps/web` or Flutter product behavior.

---

# Acceptance criteria

SITE-02W is complete when:

- [ ] SITE-02 remains behaviorally unchanged.
- [ ] `apps/site` no longer depends on Pages Functions as its canonical runtime.
- [ ] a native Worker entry point owns `/api/waitlist`.
- [ ] static content is configured through Workers Static Assets.
- [ ] `pages_build_output_dir` is removed.
- [ ] ordinary runtime scripts no longer use `wrangler pages dev`.
- [ ] D1 migration/history and binding contract remain intact.
- [ ] Turnstile security checks remain intact.
- [ ] local full-stack development works through Workers.
- [ ] static homepage/assets and `/api/waitlist` work together locally.
- [ ] existing waitlist/client tests remain green.
- [ ] Worker routing/static-asset behavior has explicit coverage.
- [ ] CI requires no production Cloudflare resources.
- [ ] docs/roadmap no longer describe Pages as the intended deployment runtime.
- [ ] no production deployment, provider resource creation, or DNS change occurs.
- [ ] SITE-03 can now use the Cloudflare dashboard's normal Workers Git connection flow.

---

# Git / PR rule

This task must be represented on GitHub.

Do not finish with changes only in a local worktree.

Required flow:

1. branch/worktree from current `main`;
2. implement and validate;
3. commit;
4. push;
5. open a focused GitHub PR;
6. wait for required CI;
7. reconcile with latest `main` if it advanced;
8. follow the repository's current merge policy.

If the repository currently authorizes automatic merging for fully specified technical tasks with green CI and no founder review requirement, this task is suitable for that behavior.

Regardless of merge policy, a PR must exist so later ChatGPT/Codex sessions can inspect the implementation from GitHub.

---

# Stop conditions

Stop and report if:

- current Cloudflare Workers documentation shows a material incompatibility with the existing D1/Turnstile architecture;
- preserving SITE-02 semantics would require a significant product/security redesign;
- migration requires creating real Cloudflare resources or credentials;
- Worker/static-asset routing cannot be made equivalent without introducing a substantial framework;
- an unresolved choice would materially affect cost, privacy, or public behavior.

Do not stop for ordinary file placement, script naming, or small runtime typing decisions.

---

# Completion report

Return:

1. summary;
2. branch, commit, and GitHub PR URL;
3. final Worker/static-assets architecture;
4. files moved/removed from the Pages structure;
5. Wrangler/config changes;
6. local-development command changes;
7. D1 and Turnstile compatibility confirmation;
8. tests/checks run and exact results;
9. whether the Cloudflare Vite plugin was used and why/why not;
10. documentation/ADR/roadmap changes;
11. confirmation that no Cloudflare production resource/deployment/DNS action occurred;
12. exact SITE-03 steps now enabled by this migration;
13. any warning that should block deployment.
