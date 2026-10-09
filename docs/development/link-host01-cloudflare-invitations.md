# LINK-HOST-01 Cloudflare invitation hosting

This is a staging-only trial of the existing `apps/web` application. Its scripts
cannot attach a domain or route. Code merge does not approve a canonical-domain
cutover, staging schema deployment or native store association.

## Runtime and ownership

The trial pins vinext 1.0.1 (beta), Vite 8.3.0, Cloudflare Vite plugin 1.63.0 and
Wrangler 4.148.0. Next 16.3.4, its normal `dev`/`build`/`start`, Supabase factories,
Proxy, invitation RPCs and profile flow remain in place. The versioned upstream
[Workers guide](https://developers.cloudflare.com/workers/framework-guides/web-apps/nextjs/)
recommends a compatibility check and warns that vinext is beta. Its static check
exits 1 for partial Sentry support; it is not a runtime certification.

The separate `vite.worker.config.mts` selects the Cloudflare RSC environment.
ESM package mode is necessary: without it, the SSR output is `index.mjs` but
vinext asks for `ssr/index.js`, and real requests fail. The Worker also directly
reuses the existing association GET/HEAD handlers: vinext's hidden-directory
discovery otherwise returns an HTML 404 for the `.well-known` JSON resources.
These adaptations do not replace or bypass Supabase session Proxy refresh.

`worker/ingress.ts` validates the advertised request URL, Host and optional
Origin, discards all incoming forwarding metadata and reconstructs host/protocol
from the validated URL. It streams responses, preserves independent Set-Cookie
headers and adds no-store/no-referrer/noindex to sensitive descendants, including
admin. No shared cache or additional database/service binding is enabled.

Workers Observability is disabled. Do not enable access logs, tail token-bearing
requests or capture browser chrome during invitation QA. Existing telemetry
filters remain responsible for dropping invitation secrets. Account-wide
Logpush/cache rules still need an owner review before canonical cutover.

Monitoring and native/store identities are disabled in this deployment. Both
empty-DSN and synthetic-DSN enabled builds and anonymous workerd probes passed;
no real monitoring delivery or authenticated telemetry was tested. The runner
rejects a nonempty Sentry DSN and unverified native/store settings. Enabling
monitoring needs an independent Worker-runtime and privacy proof; normal Node
monitoring retains its existing implementation. Do not silently stub Sentry,
weaken Proxy or upgrade to an unreviewed SDK to pass deployment.

## Reproduce the isolated deployment

From the repository root, install the committed lockfile with `npm ci`. Create
the ignored `apps/web/.env.worker-staging.local` using the public publishable key
from **planets-staging**, project `cllpvruvrrvxczjitlqd`:

```dotenv
NEXT_PUBLIC_APP_ENV=staging
NEXT_PUBLIC_SUPABASE_URL=https://cllpvruvrrvxczjitlqd.supabase.co
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=<public publishable key>
NEXT_PUBLIC_SENTRY_DSN=
NEXT_PUBLIC_PLANETS_ANDROID_DOWNLOAD_URL=
NEXT_PUBLIC_PLANETS_IOS_DOWNLOAD_URL=
```

Leave all four `PLANETS_*` association identity settings absent/empty. Never put
service-role keys, database passwords or email-provider secrets in this file or
NEXT_PUBLIC values. The runner uses the existing typed environment parser and
rejects another backend, non-staging mode or a non-publishable key.
`NEXT_PUBLIC_*` values are compiled into both server and browser output: changing
a Wrangler variable alone cannot switch an already-built client's backend.
Rebuild when public settings change. No secret bindings are needed by this app.

```text
npm run worker:build:staging --workspace @planets/web
npm run worker:dry-run:staging --workspace @planets/web
npm run worker:preview:staging --workspace @planets/web
```

In another PowerShell terminal:

```powershell
$env:LINK_HOST01_PROBE_ORIGIN = 'http://127.0.0.1:8796'
node apps/web/scripts/probe-worker-staging.mjs
```

Stop preview before rebuilding on Windows: workerd holds generated modules open.
The build emits `dist/server/wrangler.json`; preview/deploy/dry-run use that exact
generated config, not the source entry. The runner rejects a changed Worker name,
any routes, disabled workers.dev, or enabled request Observability.

Use existing Wrangler OAuth login or a securely configured token based on the
Edit Cloudflare Workers template, scoped to account
`5e9cf144fb13c9913f8570b32d7288a8`. Do not paste credentials into chat. No billing
upgrade is authorized. Deploy only the isolated name after local runtime proof:

```text
npm run worker:deploy:staging --workspace @planets/web
```

The deployed temporary host is
[`planets-web-link-host01-staging.developer-planets-community.workers.dev`](https://planets-web-link-host01-staging.developer-planets-community.workers.dev/auth).
Use it as `LINK_HOST01_PROBE_ORIGIN` for the same guarded anonymous probe. That
probe deliberately refuses the live domain, follows only a bounded same-origin
RSC cache-bust redirect and uses only malformed/non-secret invitation paths.
No raw real capability is accepted or printed. Standard streamed Proposal
not-found HTML can return HTTP 200 with `NEXT_HTTP_ERROR_FALLBACK;404` because
its existing public loading boundary has already streamed; Tavoli/admin/asset
missing routes must return actual HTTP 404. Do not interpret the streamed shell
as successful detail data.

For an existing staging Worker, record the deployed version before each update
and use Wrangler `rollback` after discovering its current `--help` syntax.
For first deployment, removal of this named staging-only Worker is the rollback;
never remove the Site Worker, D1 database or custom domain. No staging deployment
rollback requires a database reset or DNS change.

## Shared staging schema

Read-only comparison on 2026-10-08: main at
`70f8ed3b92db2ba90792c3bd4de44412f1b3462d` has 70 canonical migration files;
staging has 60 applied versions, latest `20261006101031`; no remote-only version.
The task branch subsequently updated to main
`4f158f323ebdfacbc9e86b66072ac91c80118ddd`; that intervening change adds only
Play Store asset documentation/artwork and leaves runtime/schema files intact.
Missing versions:

```text
20261003125831 source_linked_proposal_template_workshop
20261003191351 template_reporting_and_removal
20261004145334 template_to_draft_creation
20261004200147 idempotent_editor_draft_creation
20261005104541 similar_active_proposal_matching
20261006131533 message_unread_activity_separation
20261007090000 new_template_draft_italy_timezone
20261007103000 push_projector_receipt_recheck
20261007103322 messages_list_activity_preview
20261008124856 geoapify_shared_location_foundation
```

Several are older than the latest applied version. Do not treat this as a clean
append-only `db push`, repair history or replay the 60. Review canonical files,
the CLI dry-run's exact catch-up set and dependencies with the sole staging
operator before requesting explicit schema deployment authorization. No schema,
seed, user or membership write was performed by this task. Basic web invitation
and discovery RPCs predate these gaps; that does not certify whole-main parity
or newer location/template/messages features. Full real browser Join still needs
an authorized disposable staging invitation/account and OTP access.

## Proposed canonical ingress — owner gate

Read-only account inspection found an active zone, Site Custom Domain
`planets.community` -> `planets-public-site`, and **zero Worker Routes**. Site
bindings remain ASSETS, WAITLIST_DB and its existing Turnstile settings/secret.
The zone reports Free Website; the subscription API returned 403, so this is
not independent proof of the account's Workers billing tier.

[Cloudflare documents](https://developers.cloudflare.com/workers/configuration/routing/custom-domains/#interaction-with-routes)
that Routes execute before a Custom Domain origin. Narrow Routes to the tested
dynamic Worker are preferable here; no Site deployment, gateway, service binding,
DNS change or new Custom Domain is necessary. Proposed patterns, all for the
same existing zone, are:

```text
https://planets.community/join/project/*
https://planets.community/invite/project/*
https://planets.community/joined/proposals/*
https://planets.community/joined/tavoli/*
https://planets.community/proposals*
https://planets.community/tavoli*
https://planets.community/auth*
https://planets.community/profile*
https://planets.community/admin*
https://planets.community/_next/*
https://planets.community/.well-known/assetlinks.json*
https://planets.community/.well-known/apple-app-site-association*
```

Cloudflare matches URL queries too, so the suffix wildcard includes auth return
queries and association query strings. The Worker enforces exact namespace
boundaries: `/authentic`, `/proposals-other` and other prefix overmatches call the
existing Site Custom Domain origin. Same-zone fetch to that Custom Domain is
supported; fetch to another Route/workers.dev would require a service binding.
Do not add `planets.community/*`. Site retains `/`, `/assets/*`, `/api/waitlist`,
favicon and unrelated 404s. Actual app HTML emits assets under `/_next/static/`.

Before making these routes, require: successful disposable staging OTP/profile/
explicit Join/token-free confirmation and refresh/leave/re-entry proof; Free CPU
and startup evidence; reviewed route list and rollback; explicit owner approval.
Re-read current zone routes and deployed Worker version immediately before the
change. If another operator changed ownership, stop and reconcile first. Record
the IDs of only the newly added routes; rollback deletes only those IDs and leaves
the original Site Custom Domain/DNS/bindings intact. Re-test root/assets/waitlist
and the dynamic HTTP contract, then perform a real WhatsApp/browser-opened link.
Disabled JSON association 404s do not establish Android/iOS verified app links.

## Validation record

The follow-up [LINK-HOST-02 CPU diagnosis](link-host02-cpu-diagnosis.md) separates
global initialization, fresh local first requests and repeated route classes.
It replaces causal guesses from the tiny mixed samples with production workerd
profiles and version-scoped hosted windows. Its SSR-preload trial was discarded;
the deployed runtime remains the version recorded below. PR #176 stays draft.

The final PR records exact check results and deployed version. Local focused
ingress tests and real workerd anonymous probes exercise associations, sensitive
headers, lists, missing details, HEAD/POST, Flight/prefetch, assets, redirects and
forwarding-header reconstruction. They do not certify real OTP, authenticated
chunked refresh, profile completion, admission, full/blocked/expired links,
leave/re-entry, Cloudflare cache rules or native links without their fixtures.

Local repository validation used Node 24.19.0 from the bundled desktop runtime;
CI uses the repository's Node 24.20.0. Tooling tests (53), focused ingress tests
(5), Web lint/typecheck, ordinary Next build, `check:site`, `format:check:web`,
explicit formatting checks for the new MJS/MTS/JSONC files, and
`git diff --check` passed. The full Web process-worker rerun had 283 passes, one skip and
six failures: five 5-second import/render timeouts and a following admin mock
assertion failure. A prior run had seven failures. No test timeout or assertion
was weakened. The standard Web command was also attempted; its thread worker
stalled locally. Exact-head CI results are recorded on the PR and must be
distinguished from these local failures. No local/shared Supabase reset or
database suite was run for this hosting-only task.

Final disabled-monitoring deployment on 2026-10-08: 1,974.14 KiB upload / 569.74 KiB
gzip, 22 ms Worker startup, ASSETS only; 23 assets uploaded and 28 reused from
63 generated files. The initial dry-run enumerated 185 modules. Version:
`8e7d46f6-6bf5-4a31-aecd-5340efc5600c`. All 30 guarded anonymous HTTP probes
passed on this final hosted version. Earlier empty-DSN and synthetic-DSN local
workerd trials both passed all 30 probes; real Sentry delivery remains unverified.

**Free hosting is blocked by measured CPU.** The first hosted GraphQL sample
reported 24 successful invocations, zero errors, CPU p50 `17746` and p99
`199007`. GraphQL schema introspection explicitly describes these fields as
microseconds: **17.746 ms median and 199.007 ms p99**. This is a small mixed
anonymous-route sample, not an authenticated load test. A later final-deployment
sample reported 22 successful invocations, zero errors, **8.021 ms median and
206.990 ms p99**: the median improved, but the upper tail still exceeds the
official [Free limit](https://developers.cloudflare.com/workers/platform/limits/)
of 10 ms CPU per invocation; successful requests do not certify sustained Free
operation. No billing tier was enabled or changed, and the account subscription
API was unavailable. Neither upload size nor startup is the observed blocker.

Hosting choices requiring an owner decision:

| Choice                   | Current evidence and cost                                                                                                                                                                                                                        | Remaining gate                                                                                                                            |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------- |
| Workers Free with vinext | Build/anonymous runtime work; measured CPU exceeds 10 ms                                                                                                                                                                                         | Cannot recommend canonical cutover on this evidence                                                                                       |
| Workers Paid with vinext | [Minimum $5 USD/month per account](https://developers.cloudflare.com/workers/platform/pricing/); 10 million requests and 30 million CPU ms included, then $0.30/additional million requests and $0.02/additional million CPU ms                  | Explicit billing authorization, real OTP/Join/refresh proof, beta adapter acceptance; no paid change performed                            |
| OpenNext on Workers      | Current Cloudflare guide still lists Node.js Middleware unsupported; the unchanged Next 16 Proxy is required. OpenNext 1.20.9 excludes current Next 16.3.4. PR #130's Sentry/Wasm failure is historical, not proof against every current version | A separately reviewed Next upgrade, independent Proxy/Sentry runtime proof and fresh CPU measurements; not an established Free workaround |
| Conventional Node        | Existing Next build passes without an adapter; `npm run build --workspace @planets/web` then `npm run start --workspace @planets/web`                                                                                                            | Owner-selected Node host, its quoted recurring cost, TLS/reverse proxy for the same bounded paths, and real OTP/Join proof                |

The Free limit applies to either Workers adapter; replacing the adapter cannot
be claimed to solve CPU without measurements. The current OpenNext support
assessment comes from the [official guide](https://developers.cloudflare.com/workers/framework-guides/web-apps/opennext/).
Published OpenNext 1.20.9 declares the Next peer range
`>=15.5.27 <16 || >=16.3.8`, verified with `npm view` on 2026-10-08.
Do not disable Proxy, cache private pages or merge PR #130/#149 as a shortcut.

Interactive browser QA could not run: the desktop browser tool repeatedly
failed to attach the staging tab. No disposable staging invitation/account or
OTP access was supplied. Real OTP, session continuation, profile completion,
explicit Join, token-free confirmation, leave/re-entry and full/blocked/expired
links remain unverified. The HTTP probe and synthetic cookie-pair unit test do
not substitute for this proof. Canonical cutover remains blocked by the hosting
decision, staging proof and explicit live-routing approval.

Live read-only baseline: root 200 HTML, JS/CSS assets 200, waitlist GET 405
with no-store; no signup was submitted. Canonical routes remain unchanged until
their approval gate passes. Do not report the public invitation URL as fixed
from this staging-only proof.
