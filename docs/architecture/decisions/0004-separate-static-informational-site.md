# 0004 — Separate static informational site

- **Status:** Accepted
- **Date:** 2026-09-12

## Context

The accepted architecture originally assigned informational pages, public
discovery, and future administration to one Next.js application under
`apps/web`. That application now contains authentication, profiles, and dynamic
Proposal and Tavolo discovery. Repurposing it as a small launch website would
mix responsibilities and risk changing implemented product behavior.

PLANETS also needs a lightweight public informational presence that can be
designed and deployed independently. The foundation must not prematurely
select a production host, introduce a backend, or move the existing web
application into a new repository.

## Decision

Add `apps/site` as a second Node workspace in the existing repository. It uses
Vite, React, and strict TypeScript and produces ordinary static assets. It owns
only the small public informational and launch website.

Keep `apps/web` as the Next.js application for dynamic public discovery and the
future authenticated administration surface. It retains its existing backend
and domain responsibilities unchanged.

Both applications use the root npm workspace and lockfile and have independent
development and validation commands. SITE-00 adds no Supabase client, database,
server-side rendering, authentication, analytics, runtime configuration, or
deployment provider to `apps/site`.

Production hosting is a later operational decision. SITE-03 will own the
Cloudflare deployment and `planets.community` cutover for the informational
site; this record does not configure or authorize that work.

## Alternatives considered

- **Repurpose `apps/web`:** rejected because it already owns implemented dynamic
  product behavior and a future authenticated admin boundary.
- **Use Next.js for both applications:** rejected for `apps/site` because its
  SITE-00 requirements are satisfied by a smaller static toolchain without a
  server-capable framework.
- **Create a separate repository:** rejected because the informational site
  shares project ownership, review, dependency restoration, and CI conventions
  with the existing monorepo.
- **Build without React:** viable for a single placeholder, but React provides a
  restrained component model for the already planned SITE-01 page work while
  retaining static output.

## Consequences

The repository has two independently built TypeScript web applications with a
clear responsibility boundary. CI validates both, and `apps/site/dist/` can be
served without a Node.js runtime.

Final branding, copy, navigation, the one-time launch waitlist, provider
configuration, production deployment, DNS changes, and retirement of the old
site remain deferred to SITE-01 through SITE-04. The future waitlist is for one
launch notification only and must not become a newsletter or general marketing
list.
