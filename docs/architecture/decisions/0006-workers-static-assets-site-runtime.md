# 0006 — Workers Static Assets runtime for the informational site

- **Status:** Accepted
- **Date:** 2026-09-14

## Context

SITE-02 implemented the purpose-limited waitlist from ADR 0005 with a reusable
handler behind a Cloudflare Pages Functions wrapper. No production Pages
project, Worker, D1 database, Turnstile widget, deployment, or DNS route exists
yet.

Cloudflare now documents Workers with Static Assets as the native migration
target for full-stack static applications. Adopting it before SITE-03 avoids
creating a legacy Pages deployment while preserving the existing Vite output,
D1 migration, Turnstile validation, and waitlist contract.

## Decision

Deploy `apps/site` as one native Cloudflare Worker with Static Assets. Vite
continues to build browser files into `dist/`. Wrangler points `main` at the
small Worker entry point, binds `dist/` as `ASSETS`, and routes `/api/*` to the
Worker before asset lookup. Existing static files use Cloudflare's asset-first
path without invoking Worker code.

The Worker explicitly delegates only `POST /api/waitlist` and its method
handling to the reusable SITE-02 handler. Unknown API paths receive a minimal
404, while non-API misses fall through to the static-assets binding. The site
has no client-side URL routes, so the runtime uses no SPA fallback.

D1 remains bound as `WAITLIST_DB`; its schema and migration history do not
change. Turnstile secrets, expected hostname/action, explicit testing mode, and
production fail-closed behavior do not change. Local full-stack development
uses `wrangler dev --local`; CI uses the Workers Vitest integration and a
Wrangler deploy dry run without contacting production resources.

SITE-03 owns the Workers Builds Git connection, real Worker/D1/Turnstile
resources, runtime and build variables, preview exposure, deployment, custom
domain, and DNS cutover.

## Alternatives considered

- **Keep Pages Functions:** rejected because no production Pages resource
  exists and the migration can be completed without public or data behavior
  changes.
- **Compile the Pages `functions/` folder into a Worker:** rejected because one
  route needs neither retained file-based routing nor a compatibility build
  step.
- **Add a router framework:** rejected because one explicit endpoint and one
  static fallback do not justify another runtime dependency.
- **Add the Cloudflare Vite plugin:** deferred because the existing `vite build`
  plus `wrangler dev/deploy` flow is small, direct, independently testable, and
  already uses compatible pinned tooling.

## Consequences

`apps/site` has one deployable Workers unit containing cached static assets and
the waitlist Worker. Existing static files bypass Worker execution; API routing
and non-asset fallback remain explicit and testable. No Node.js server is
introduced.

Production remains blocked on the same SITE-03 legal, operational, secret,
resource, hostname, deployment, and DNS inputs. This decision authorizes no
Cloudflare resource creation or production action.
