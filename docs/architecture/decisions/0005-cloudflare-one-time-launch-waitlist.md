# 0005 — Cloudflare one-time launch waitlist boundary

- **Status:** Accepted
- **Date:** 2026-09-13

The waitlist data, privacy, and service boundary remains accepted. [ADR
0006](0006-workers-static-assets-site-runtime.md) narrows its previously
deployment-neutral Pages Functions/Workers-compatible runtime to native
Cloudflare Workers with Static Assets.

## Context

ADR 0004 keeps the public informational site independent from the dynamic
product application and static-first. SITE-02 adds one deliberately narrow
write operation: a visitor may request exactly one email when the PLANETS
Android/iOS app becomes available.

That operation needs server-side abuse validation and durable, duplicate-safe
storage, but it must not introduce the product's Supabase backend, a
general-purpose site API, analytics, accounts, or a marketing database.
Production Cloudflare resources and domain cutover remain separately controlled
work in SITE-03.

## Decision

Keep the Vite/React page as static output. Add one Cloudflare Pages
Functions/Workers-compatible handler at `POST /api/waitlist`, validate
Turnstile through the server-side Siteverify API, and persist the accepted
address in Cloudflare D1 through a committed migration and prepared statement.

The D1 row contains only the normalized email, creation and consent timestamps,
the fixed purpose version `launch_notification_v1`, and nullable
`notified_at` reserved for SITE-04. Normalization trims and lower-cases the
address for duplicate prevention; it does not rewrite provider-specific aliases.
A conflict preserves the original row and returns the same minimal success
response as a new insert.

The Turnstile secret, expected action, expected hostname, and explicit testing
mode are server-side bindings. Production mode requires exact action and
hostname matches. Testing mode accepts only Cloudflare's testing-key marker and
the configured synthetic hostname. Only the public site key is exposed to the
static build. Local development and CI use official test credentials or mocks
with local Wrangler/Miniflare D1 state and never require a remote Cloudflare
account.

SITE-03 owns creation and binding of production D1 and Turnstile resources,
production secrets and hostname, deployment, and DNS. SITE-04 owns the one-time
delivery and approved waitlist retirement/retention behavior.

## Alternatives considered

- **Use the product Supabase backend:** rejected because the independent launch
  site needs one bounded operation and must not acquire product-domain or account
  dependencies.
- **Use a spreadsheet, CRM, or mailing-list provider:** rejected because those
  systems encourage broader data collection or communication semantics and make
  the one-purpose boundary harder to enforce.
- **Store only in browser or send directly to email:** rejected because neither
  provides a durable, server-validated, duplicate-safe record for the later
  launch notification.
- **Build a self-service account/unsubscribe system:** rejected as
  disproportionate for one pre-launch message. A validated removal request is
  handled by deleting the D1 row.

## Consequences

The public site now has one dynamic provider-specific boundary while remaining
static-first. CI must validate both the browser form and the Cloudflare
runtime/D1 migration. The endpoint must fail closed when Turnstile or
configuration fails and must never log submitted addresses or tokens.

The stored address is authorized only for the launch notification. It cannot be
repurposed for newsletters, promotions, recurring updates, advertising,
profiling, or unrelated communication. No IP address, user agent, name,
location, analytics identifier, marketing preference, or arbitrary payload is
stored.

Production cutover is blocked until the controller identity, public/privacy
contact, removal-request procedure, access ownership, data-retirement decision,
real Turnstile widget/secret/hostname/action, and D1 resource are approved and
verified.
