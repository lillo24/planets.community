# LINK-HOST-03: static participant invitation trial

## Scope and decision status

This is an isolated feasibility trial from main
`723582be49fcbd78c19bd5316da661c297f7eeba` on 2026-10-09. The source branch is
`codex/link-host03-static-invitations`. It must remain a draft, unmerged PR.
PR #176 remains independently draft at
`409ecc3e2b0afc3c3cf88aaea0b626c8bd06184f`; none of its vinext code is a dependency.
No live Site, canonical routing, DNS, billing or shared backend data/schema was
changed. This provisional boundary does not replace the accepted architecture.
The final main fetch was `1d9871bd64197226089b8477a6fac2ae94431504`; intervening
files were mobile hero/layout polish only, with no Web/backend dependency change.

The client-only Vite target in `apps/web/static-invitations` imports the existing
canonical participant controller/gateway/parsers, numeric OTP gateway, profile
reader/save gateway and UI. Shared `*-view.tsx` components receive a small host
navigation adapter; existing entry points retain real Next wrappers. There are
no fake Next aliases, RSC/Flight, server actions, Auth proxy or Node hosting.
The build rejects Next/vinext/server-only runtime modules.

## Route and authorization boundary

| Path                                                                                    | Trial behavior                                                      |
| --------------------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| `/`                                                                                     | Minimal trial landing page                                          |
| `/join/project/<43-character capability>`                                               | Public minimal preview; explicit prerequisite continuation and Join |
| `/auth`, `/profile`                                                                     | Numeric OTP and basic profile with narrowed canonical safe returns  |
| `/joined/proposals/<uuid>`, `/joined/tavoli/<uuid>`                                     | Token-free confirmation; fresh own membership/Creator reads         |
| Emitted `/assets/*`                                                                     | Static JS/CSS, asset serving                                        |
| Authority, ordinary discovery, admin, API, associations, malformed paths, missing files | HTTP 404; no SPA success fallback                                   |

Only GET/HEAD are supported; other methods return 405. The tiny Worker validates
path/method and returns the same generic `index.html`, stripping cookies/query
from its internal asset request. It does not render, call Supabase, inspect Auth
or embed personalized state. Matching assets bypass Worker invocation; misses
reach its 404. `_headers` protects asset responses; Worker-generated responses
set the same no-store, no-referrer and noindex/nofollow/noarchive explicitly.
There is no telemetry, access logging, service worker or published source map.

JWT validation, RLS and canonical RPCs remain authoritative. Auth restoration,
profile save, cancellation, link opening and read retries never admit. The reused
controller binds account/token/action UUID, suppresses duplicate submissions,
ignores stale revisions and retains same-attempt replay recovery. The single
controller survives component remounts in tab/process memory only; reload loses
the action UUID. A fresh explicit click after reload first checks canonical
current membership and does not claim to recover the lost attempt.

Confirmation always rereads current own participation/Creator context. Departure
invalidates confirmation; deliberate re-entry creates a new episode. Public
Project/app links keep the fixed `https://planets.community` owner. Store links
are absent and honestly unavailable; no native identity or automatic post-install
continuation was invented.

## Session and configuration

The founder-requested invitation setup now asks only for a name and offers
Continue. Biography, skills and visibility controls are omitted from this static
target; loaded values are preserved through the same canonical profile gateway.
An empty biography is already normalized to SQL NULL by `update_own_profile`, so
no placeholder text or schema change is needed. Profile personalization remains
available in the app, and saving the name returns to the invitation without
submitting Join. The full Next profile editor retains its existing controls.
This UI follow-up does not replace the exact deployed-version measurement or
browser proof record below; the recorded staging deployment predates it.
Follow-up validation: `npm run check:web` passed (61 tooling tests, 298 Web tests,
two existing opt-in backend skips, lint/typecheck, Next production build and
static invitation build). All 11 focused profile-form tests passed, including
name-only validation, empty biography and preservation of existing hidden fields;
scoped formatting and `git diff --check` passed.

Resolved Supabase SDKs are `@supabase/ssr 0.12.5` and `supabase-js 2.113.0`.
The static target reuses `createSupabaseBrowserClient`: the SSR SDK owns its
JavaScript-readable, SameSite=Lax cookie session, default persistence/automatic
refresh and storage-key BroadcastChannel notifications. Staging cookies are
Secure. No parallel login flag, email/code storage, capability or action UUID
is persisted. URL-carried Auth credentials are disabled for numeric OTP; backend
fetches force no-store/no-referrer. The existing Next factory defaults and Proxy
are unchanged. Cookie persistence is not an assertion that browser reload or
cross-tab tests passed; see the proof matrix.

Auth hints immediately invalidate private UI by identity epoch. Verified claims
bind reads/mutations. Profile/Auth views unmount on identity changes; late saves
or verification cannot navigate an obsolete view. A restored missing profile
anchor uses the same minimal canonical setup operation and offers explicit retry;
it never admits. Same-origin production cookie/session compatibility with Next
must be tested before route cutover; workers.dev cookies do not share the
canonical origin's session.

The strict public allowlist contains only `NEXT_PUBLIC_APP_ENV`,
`NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` and optional
`NEXT_PUBLIC_PLANETS_ANDROID_DOWNLOAD_URL` / `NEXT_PUBLIC_PLANETS_IOS_DOWNLOAD_URL`.
Unknown public settings (including Sentry) fail the build. Keys must have the
publishable prefix; URLs are fixed to the owned local backend or planets-staging.
No full environment object, service-role/secret key or Auth token enters output.
Existing repository versions Vite 8.3.0 and Wrangler 4.131.1 are declared directly;
no dependency version upgrade was needed. Compatibility date 2026-09-18 matches
the pinned Wrangler/workerd runtime.

## Reproduce the isolated local trial

Use the repository-supported Node runtime (this run used Node 24.19.0), `npm ci`,
Docker, and the installed Supabase CLI. Commands below start at repository root.
On Windows ensure that same Node and `node_modules/.bin` are on PATH.

```powershell
node apps/web/static-invitations/local-stack.mjs prepare
node apps/web/static-invitations/local-stack.mjs start
$env:LINK_HOST03_LOCAL='1'
node apps/web/static-invitations/browser-fixture.ts --seed
npm run invitation:build:local --workspace @planets/web
npm run invitation:preview --workspace @planets/web
```

In a separate terminal run the private helper:

```powershell
$env:LINK_HOST03_LOCAL='1'
node apps/web/static-invitations/browser-fixture.ts
```

Open `http://127.0.0.1:3193` and use its launch links instead of printing
capabilities. New account: `linkhost03-new@planets.invalid`; existing incomplete
account: `linkhost03-existing@planets.invalid`; switch account:
`linkhost03-other@planets.invalid`. Private `/otp/proposal`, `/otp/tavolo` and
`/otp/other` pages display only the corresponding local Mailpit code; never
capture/log it. Enter it into the real six-digit form, complete a display name
(photo optional), return to preview, and click Join deliberately. Inspect the
token-free confirmation and helper `/status` counts. The fixture includes revoked,
full and blockable projects; the full slot is occupied through canonical admission
by a separate synthetic account (the Creator does not occupy that slot).

The backend is `planets-community-link-host03`, PostgreSQL 17.6 with all 73
canonical migrations, CLI 2.118.0-beta.39, ports 59120–59129, inspector 8913.
Canonical configuration/migrations/templates are copied to ignored
`apps/web/.wrangler/link-host03/backend`, leaving repository config and other
stacks untouched. Seeding refuses an existing owner; it does not silently reset.

```powershell
$env:LINK_HOST03_LOCAL='1'
npm run test --workspace @planets/web -- static-invitations/local-integration.test.ts
node apps/web/static-invitations/http-probe.mjs http://127.0.0.1:8797
node apps/web/static-invitations/local-stack.mjs stop
```

Stop the two task-owned servers with Ctrl+C as well. This retains disposable
backend data for inspection; it never stops/resets other stacks.

## Isolated staging deployment and measurements

Fixed Worker: `planets-link-host03-static-staging`, account
`5e9cf144fb13c9913f8570b32d7288a8`, workers.dev only; no custom routes or previews.
Copy `.env.trial-staging.example` to ignored `.env.trial-staging`, provide the
canonical staging public publishable key, and keep all other environment data out.
Use existing Wrangler OAuth or an appropriately scoped API token privately.

```powershell
npm run invitation:build:staging --workspace @planets/web
npm run invitation:dry-run --workspace @planets/web
npm run invitation:deploy:staging --workspace @planets/web
node apps/web/static-invitations/hosted-cpu.mjs measure
node apps/web/static-invitations/http-probe.mjs https://planets-link-host03-static-staging.developer-planets-community.workers.dev
node apps/web/static-invitations/hosted-cpu.mjs read
```

Deploy refuses an existing name unless the private task journal identifies its
exact currently deployed version. It checks asset contents, source maps, isolated
configuration and post-deploy Observability/subdomain settings; logs stay ignored.
The CPU script sends one first-observed request, then two 30-request windows for
each route class, consuming bodies; aggregate analytics are filtered by exact
script/version/time. Cold isolate placement cannot be controlled. Adaptive
analytics may estimate counts or omit a one-request window; report that limitation
instead of treating missing CPU as zero. No request-level logs are enabled.

Staging parity read-only snapshot: `cllpvruvrrvxczjitlqd`, healthy PostgreSQL
17.11 / hosted 17.11.0.003, **60 applied migrations**, latest `20261006101031`;
main contains **73**. All five trial APIs exist (`get_project_participant_invitation_preview`,
`accept_project_participant_invitation`, `list_own_project_memberships`,
`get_own_project_management_role`, `update_own_profile`). Existence does not prove
full migration/behavior parity. No history repair, migration or shared seed ran.

## Hosted CPU result and decision

The static boundary removes the observed server-rendering CPU problem for these
trial routes: the first observed Auth request used **0.595 ms** and the highest
observed repeated-route CPU was **0.740 ms**, well below the Workers Free
[10 ms invocation budget](https://developers.cloudflare.com/workers/platform/limits/).
There is no React/server/Auth work in that Worker; actual OTP/profile/Join traffic
runs from the browser directly to canonical Supabase. This is a practical
Free-hosting candidate worth continuing, **not a completed browser/hosted journey
or approval for canonical routing**. The missing browser proof is a tool/fixture
limitation, not evidence that static Auth is impractical; an app-only fallback is
not warranted by the CPU result and was not implemented.

Measurements ran 2026-10-09 11:06:38.789–11:07:56.667 UTC on the exact version below:
361 expected HTTP responses, including 60 emitted-asset reads; no response errors.
Two sets each sent 30 requests per class. CPU values below are milliseconds
(Cloudflare microseconds divided by 1000), direct window aggregates, not
differences or wall-clock timings. Request Observability stayed disabled.

| Class                         | First repeated p50 / p95 / max | Later repeated p50 / p95 / max | Estimated Worker requests first / later |
| ----------------------------- | ------------------------------ | ------------------------------ | --------------------------------------- |
| Auth shell                    | 0.414 / 0.480 / 0.480          | 0.384 / 0.525 / 0.525          | 30 / 32                                 |
| Valid-shaped invitation shell | 0.449 / 0.656 / 0.656          | 0.472 / 0.583 / 0.583          | 30 / 25                                 |
| Token-free confirmation shell | 0.394 / 0.534 / 0.534          | 0.454 / 0.533 / 0.533          | 30 / 30                                 |
| Emitted JS asset              | Worker bypass                  | Worker bypass                  | 0 / 0                                   |
| Unknown route HTTP 404        | 0.317 / 0.740 / 0.740          | 0.346 / 0.591 / 0.591          | 30 / 30                                 |
| Unsupported method HTTP 405   | 0.322 / 0.422 / 0.422          | 0.355 / 0.565 / 0.565          | 27 / 30                                 |

The one-request first-observed Auth window has one reported invocation at
0.595 ms (p50/p95/max). It is not a controlled cold-isolate experiment.
`avg.sampleInterval` exceeds one for repeated windows, so estimated counts can
differ from requests sent; recent data can also arrive late. The final aggregate
read was 11:10:09.907 UTC; all reported Worker errors were zero. Repeated-window
sample intervals ranged from about 1.765 to 5. No route dimension
exists, so bounded script/version/time windows identify the traffic class.
These small adaptive samples establish headroom for this simple handler, not a
production tail guarantee. Empty asset windows corroborate configured asset
bypass and do not mean an invoked Worker costs zero CPU.

## Proof record

The isolated deployment at 2026-10-09 11:06:27 UTC is Worker version
`cdaaafea-d3a6-48a9-8402-98e05a4cf2a4`, source
`2a4055752b92c9bbac6741133f80ffee2485187c` (runtime matches the built implementation
at `2080224`; subsequent source commits changed deployment guards/tests only).
Post-deploy API reads verified workers.dev enabled, previews/Observability disabled,
zero custom domains and zero routes to this Worker in the canonical zone.
The #176 baseline still deploys `8e7d46f6-6bf5-4a31-aecd-5340efc5600c`.

Automated local validation: 61 tooling tests, 293 web tests (two opt-in backend
tests skipped in the normal suite), web lint/typecheck, normal Next production
build, static CI build, local/staging Vite builds, Wrangler dry-run, scoped
Prettier and `git diff --check` passed. `npm run check:site` passed (41 Site and
19 delivery tests plus its lint/type/build/dry-run). The first web run timed out
in an unchanged Tavoli test; after stopping task services the full test suite
passed. The command then encountered a temporary extraction script under the
source root; it was moved into ignored diagnostics and all remaining `check:web`
stages passed separately. No test timeout or assertion was weakened.

The final real-backend opt-in test also passed with fresh SDK session refresh,
restoration into a new controller (no retained receipt/action), no extra admission,
and canonical departure cleanup. Its first restoration assertion raced the SDK's
deferred `INITIAL_SESSION` replacement read; the test now waits for that real
read to finish instead of treating the first Promise as settled UI state.
Two additional deployment-artifact regression tests passed (seven focused
boundary/artifact cases in total), and changed-script lint/typecheck passed.
No source map was published. The client transfer is about 158.6 KiB gzip JS plus
9.5 KiB gzip CSS; Vite reports its >500 KiB uncompressed chunk warning. This is
browser work/transfer, separate from the 2.18 KiB Worker bundle's CPU.

| Coverage                                                                         | Local                                                                        | Hosted                                                            |
| -------------------------------------------------------------------------------- | ---------------------------------------------------------------------------- | ----------------------------------------------------------------- |
| Production static build, route/method/privacy probes                             | Build/dry-run and 26 HTTP cases passed                                       | 26 HTTP cases passed on exact deployment                          |
| Real numeric OTP/profile/explicit Join, both kinds, no photo                     | Adapter/backend test passed; browser reached preview and six-digit form only | Unavailable: no authorized disposable staging OTP/project fixture |
| No implicit admission, duplicate Join, lost-response same-attempt replay         | Real backend adapter assertions passed                                       | Unavailable                                                       |
| Fresh confirmation, leave/read retry, deliberate re-entry, revoked/full/blocking | Real backend adapter assertions passed                                       | Unavailable                                                       |
| Reload/back, resend recovery, session refresh, logout/account switch/cross-tab   | Shared focused regressions; full real-browser journey unproved               | Unavailable                                                       |
| Browser captures after successful Join                                           | Unavailable                                                                  | Unavailable                                                       |

Browser automation initially reached the production-built preview and actual
numeric OTP form. Mailbox-tab reads then repeatedly timed out and final recovery
reported **Debugger unattached**. No OTP verification, profile-save or Join UI
success is claimed. HTTP probes and real backend adapters are not substitutes
for that browser proof. No existing private account/project was reused on staging.

A diagnostic filter accidentally emitted disposable local-stack credentials in
the tool transcript; no staging credential/session/OTP was emitted or committed.
That backend and the local helper/preview processes were stopped. Local diagnostic
files remain ignored; do not copy them into reports or PRs.

## Rollback/removal and next gate

For a later owned trial deployment, use the previously recorded version with
`wrangler rollback <previous-version> --config static-invitations/wrangler.jsonc`
from `apps/web`; verify the journal and exact Worker name first. The first
deployment has no earlier version. To remove only this trial, use
`wrangler delete planets-link-host03-static-staging --config static-invitations/wrangler.jsonc`.
Do not delete or update #176's Worker, the public Site, domains or DNS. Source
remains recoverable from the draft PR. No production deployment is part of merge.

Before canonical routing: finish both-kind real browser and authorized hosted
journeys, reconcile staging parity through its separate authorized process,
prove SDK cookie/refresh/cross-tab compatibility with Next on the intended origin,
and select exact participant/Auth/profile/confirmation routes. Keep authority
invitations, public discovery, admin and native association resources with their
separate owners. A later route plan should preserve canonical token-free handoff
and the existing live Site/policies/waitlist. Do not cut over on this draft's CPU
result alone. Invoked Worker requests retain Workers quotas/budget; static assets
and Supabase Auth/database/email quotas are separate, not unlimited backend usage.
