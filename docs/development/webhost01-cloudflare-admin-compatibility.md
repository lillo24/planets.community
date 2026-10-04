# WEBHOST-01: dynamic Web hosting assessment

Evidence collected 2026-10-03/04. **Recommendation: retain conventional Next.js
on Node as the least disruptive fallback. Do not publish the tested Cloudflare
candidate.** Real Worker auth/moderation flows worked, but Sentry module-startup
errors and experimental Node Proxy support prevent a clean compatibility pass.
Free-tier suitability is unverified, not established by low staff traffic.

**Dated follow-up:** [DEPSEC-01](depsec01-dependency-security-and-admin-qa.md)
records later dependency remediation, stronger actual-marker privacy assertions
and conventional-Node admin QA. This remains the October 3/4 Worker snapshot;
its dependency counts and missing browser checks are historical, not current
follow-up results. Worker measurements, Sentry startup and Proxy blockers are
not reclassified by that work. PR #130's late cleanup comment records the
subsequent successful advisor check and backed-up stop of its named local stack.

## Revision and scope

- Branch: `codex/webhost01-cloudflare-admin-compatibility`.
- Exact dependency base / draft target: PR [#126](https://github.com/lillo24/planets.community/pull/126),
  `f6ce0f6c4d2f6d4ba673e29bedca9262275ff6b7`,
  `codex/09c2a-admin-consequence-controls`.
- Final implementation/check source: `47fc70cdc6b574fc37b190617d83eb67e3a420a1`.
  The publication head (subsequent evidence/prompt-only commit) is recorded as
  an exact SHA in the draft PR body; a committed report cannot contain its own
  Git object ID. Verify its non-documentation tree against this source SHA.
- #126 was reconfirmed open/draft/MERGEABLE, two commits ahead and zero behind
  #125 `c0548a25d39ddc77a92bc02514c83a01f731e9ae`; #123 remains
  `010471320779ffb5edaa7546b12cdc8f14809d2d`.
- Main remains the separate invitation head
  `996f019f19f9fc3f661c388c30cb01d966e64d37`. No invitation/template integration
  was imported. Parent PRs, main, mobile, Site sources/configuration, canonical
  database/migrations, moderation policy and 09C2B are untouched.

No deployment, remote preview, login to Cloudflare, resource provisioning,
billing, DNS, certificate or production-backend changes occurred. The public
Site/waitlist remains a separate subsystem; its D1/Turnstile bindings were not
used by the Web prototype. No supported optional hosting path or architecture
decision is established here.

## Runtime comparison

| Candidate                                | Tested/version-compatible evidence                                                                                                                                                              | Result                                                                                                                                                     |
| ---------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Next 16.3.8 + OpenNext Cloudflare 1.20.8 | Retains `next build`; App Router, SSR, Flight, actions, handlers and async cookies exercised in local workerd. Build warns that Node middleware is experimental and not maintained.             | Functional flows pass; **not clean-compatible**: Proxy support gap and Sentry Wasm startup errors.                                                         |
| vinext 1.0.1                             | Official Cloudflare-recommended Next-compatible Vite path; guide calls it beta. `vinext check` reported 8/8 imports, 1/1 config option and 2/3 dependencies compatible, Sentry partial; exit 1. | Static heuristic only (its “98%” is not runtime proof). Vite/RSC-toolchain replacement needs a separate reviewed migration; not adopted or runtime-tested. |
| Existing Next 16.3.8 on Node 24          | Ordinary production build and SSR OTP/cookie/admin-denial verifier passed; HTML/Flight denial behavior compared directly.                                                                       | Least-change fallback. Live hosting, operations, capacity and total price remain unverified.                                                               |

Support sources: [Cloudflare Next/vinext guide](https://developers.cloudflare.com/workers/framework-guides/web-apps/nextjs/),
[Cloudflare OpenNext feature table](https://developers.cloudflare.com/workers/framework-guides/web-apps/opennext/),
[OpenNext support/Windows limitations](https://opennext.js.org/cloudflare),
[vinext upstream](https://github.com/cloudflare/vinext). Node middleware is listed
as unsupported by the provider, even though this adapter can experimentally
bundle/run it. Next 16 Proxy's default Node runtime was not changed to Edge.

Resolved application versions: Next/eslint-config-next **16.3.8**, React 19.2.8,
Supabase JS 2.113.0 / SSR 0.12.5, Sentry Next 10.73.0. Local tooling: Node
24.20.0 (initial independent probes also used 24.13.0), npm 11.6.2, existing
Wrangler 4.131.1/workerd, ephemeral OpenNext 1.20.8 / AWS adapter 4.1.7,
Supabase CLI 2.118.0-beta.39. No adapter/vinext dependency is added to the lockfile.

The narrow Next 16.3.4 → 16.3.8 patch and matching eslint-config-next/Next
internals are the only dependency changes. It meets the adapter's
[1.20.8 security floor](https://github.com/opennextjs/opennextjs-cloudflare/releases/tag/%40opennextjs/cloudflare%401.20.8)
(15.5.27 or 16.3.8 minimum), without an unsupported-version override. It also
fixes the inherited critical [ImageResponse RCE](https://github.com/vercel/next.js/security/advisories/GHSA-vcvr-r3jv-pc5j)
(affected 16.2–before 16.3.6). No application `next/og`/ImageResponse use was found;
that limited exposure is not a reason to leave the vulnerable framework installed.

### Monitoring blocker

Both empty-DSN and **valid synthetic loopback-DSN** builds start with two
unhandled `WebAssembly.compile(): Wasm code generation disallowed by embedder`
failures. Enabled monitoring also reports unhandled-rejection capture attempts.
HTTP success does not cure that startup failure. The earlier hyphenated dummy
DSN was rejected by the SDK and was discarded as monitoring-on evidence.

Installed Sentry 10.73.0's server entry eagerly exports build configuration;
generated server bundles contain eager lexer Wasm compilation. This is
consistent with the upstream [runtime/build-config leakage issue #22794](https://github.com/getsentry/sentry-javascript/issues/22794),
including a 10.73.0 reproduction. The breaking export separation was merged in
[Sentry #23628](https://github.com/getsentry/sentry-javascript/pull/23628) for v11;
closure of that issue does not patch v10. Latest observed v11.4.0 was **not**
installed. Exact attribution of every bundled lexer call is not proven.
[Workers Wasm restrictions](https://developers.cloudflare.com/workers/runtime-apis/webassembly/)
explain why dynamic compilation fails. No monitoring removal, dependency
downgrade, alias/stub, major upgrade or weakened security was used to hide it.

## Local compatibility, security and browser evidence

[Redacted request/bundle measurements](webhost01-local-evidence.json) preserve
the actual probe output, not private HTML, cookies, OTPs, action IDs or manifests.
[Probe/fixture map](../../apps/web/scripts/README.md) documents runnable checks.
Local uncommitted logs are `planets-webhost01-*` under the owner's Temp folder;
the transcript contains browser observations/screenshots, not a committed image
archive or production-data capture.

The isolated backend was **only** `planets-community-webhost01-qa`, API 54361,
DB 54362, Mailpit 54364. Synthetic `.invalid` identities used real Mailpit OTPs
and canonical user/staff RPCs. Existing fixture SQL was limited to disposable
staff/content/accepted-relationship bootstrap, never runtime service-role access.
The fixture creates 35 report/case pairs, eight ~1 KB private notes, reviewed
and received cases, two invited witnesses/one response and one counterstatement.
The current domain creates **one case per report**: multi-report aggregation
was not invented to fit the prompt. Queue requests fetch 26, display 25 and
offer a working next page. The auth verifier adds one further synthetic case.

Passed under actual local Worker execution:

- Signed-out and ordinary-user admin/case **HTML 404** with no staff evidence;
  forged anonymous/ordinary/moderator suspension actions deny authority; an
  admin's self-suspension action returns the safe `self_suspension` result.
- Flight requests return HTTP **200 with `NEXT_HTTP_ERROR_FALLBACK;404`**, not
  literal 404. Ordinary `next start` reproduces this Next 16 protocol behavior.
  The distinction is explicit; private evidence was absent, not replaced by a
  successful empty staff result. RSC requests without the normalization query
  redirect; probes use the canonical `?_rsc` transport.
- Real chunked refresh: expire only the local session envelope while retaining
  genuine JWT/refresh tokens; synthetic metadata forces chunking. Moderator and
  admin each received four separate `Set-Cookie` headers and the correct identity.
  Cookies stayed host-only/SameSite=Lax; local HTTP does **not** prove production
  HTTPS/Secure attributes.
- Three interleaved rounds of independent, same-host in-memory cookie jars:
  owner profile, staff role, queue HTML/Flight and private case reads remained
  identity-bound. Temporary canonical staff suspension made an existing cookie
  jar's next admin read 404; revocation restored access. Local sign-out of one
  jar left the other authorized. This is **not live CDN isolation certification**.
- Mismatched server-action Origin/Host produced a rejected action (HTTP 500);
  origin checks/trust settings were not loosened. Invite fallback retained
  private/no-store, no-referrer and noindex/nofollow/noarchive. Invalid Tavolo
  and missing association configuration returned 404. Valid invite acceptance
  and external backend/domain integration were not retested on a deployed host.

Real browser QA used the Codex IAB on Windows/workerd, 390×844 moderator/auth
views and 1280×720 admin views. Browser moderator/admin sessions used different
cookie hosts (`127.0.0.1`/`localhost`), not independent browser profiles; the
additional HTTP jars tested same-host isolation. Observed:

- Numeric OTP sign-in; populated staff queue and actual next-page navigation.
- Separate blank labelled reason/note fields, required-field validation,
  reason autofocus, cancel focus recovery and readable narrow forms without
  horizontal overflow. Safety notice apply/revoke visibly succeeded; local SQL
  confirmed two distinct reason/private-note pairs and historical episodes.
- Moderator lacks suspension controls; admin can suspend/unsuspend another
  subject; self-case omits suspension. Canonical subject status confirmed the
  real suspension. Received case requires Start review; completed review and
  revoked consequence history remain independent.
- Direct Project hide/unhide forms succeeded without owner lifecycle changes.
  Project-context-only profile report correctly lacked content-hide controls;
  witness and Resource-request counterstatement evidence rendered privately.
- A filled stale page submitted after local moderator-role deactivation became
  unavailable; SQL confirmed no episode or submitted note was stored. Role was
  restored. Duplicate/already-revoked races remain covered by unchanged domain
  tests/verifiers, not claimed as additional browser races. A separate direct
  Resource-listing hide form and full keyboard audit were not completed.

All observed private responses were no-store; no public ISR/cache/bindings were
introduced. Source review retains per-request Supabase clients and canonical
fresh authority. Synthetic probe logs contain only route/status/time/size/count
metadata. Private server manifests contain an action encryption key and must
never be uploaded or committed. Production access-log redaction of token-bearing
invite paths, hosted source-map visibility and Sentry transport remain unverified.

## Workload measurements and limits

| Workload                     | Local wall evidence                                                         | Bytes / outgoing-path evidence                                                                                                   |
| ---------------------------- | --------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| First process request `/`    | 912 ms; warm 19–43 ms                                                       | 20,005-byte HTML. Not startup CPU.                                                                                               |
| Staff queue                  | First observed browser request 30 ms in warmed process; HTTP warm 43–107 ms | ~151 KB HTML/~79 KB Flight, 25 cases. Staff-access + queue RPCs; claims may add Auth/JWKS fetches.                               |
| Private profile case         | HTTP warm 63–187 ms                                                         | ~77–78 KB HTML, eight notes/history. Staff-access + detail + history RPCs; evidence adds optional RPCs.                          |
| Auth/refresh                 | `/auth` 33–69 ms; forced refresh 170/225 ms                                 | ~19.6 KB auth HTML; four cookie headers per refresh. Adds token refresh, claims validation and owner/profile/catalog reads.      |
| Genuine browser apply/revoke | Notice 48/35 ms; suspension 46/159 ms; Project hide 193/131 ms              | Wrangler request-duration wall time, not whole-browser latency. Fresh authorization + mutation RPC + revalidated reads/prefetch. |

Outbound counts above are **source-path descriptions**, not measured network
totals; Auth algorithm/JWKS cache, revalidation and prefetch affect them. Never
budget one page click as one invocation. Local CPU fields were zero even for
long requests, so they were rejected as measurements. Representative cold
admin/detail CPU, startup CPU, memory peaks, concurrency tails and live metrics
are **unmeasured**. Network waiting is not CPU execution;
[Cloudflare CPU guidance](https://developers.cloudflare.com/workers/observability/dev-tools/cpu-usage/)
requires profiling/representative metrics before a Free-tier conclusion.

Current [Workers limits](https://developers.cloudflare.com/workers/platform/limits/)
(checked October 4, 2026):

| Constraint                             | Free / Paid                                    | Assessment                                                                                               |
| -------------------------------------- | ---------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| Dynamic requests                       | 100,000/account/day UTC / no daily cap         | Existing Site/waitlist usage unknown; names do not isolate quota.                                        |
| CPU/invocation                         | 10 ms / default 30 s, configurable ≤5 min      | Free unverified; SSR/auth is a risk, not a measured violation.                                           |
| Memory; startup                        | 128 MB/isolate; 1 s global startup CPU, both   | Not certified; startup exceptions already block acceptance.                                              |
| Worker size                            | 64 MiB **uncompressed**, both                  | 20,037.84 KiB (~19.57 MiB) passes dry-run size comparison. Gzip 4,551.51 KiB is diagnostic, not a limit. |
| Subrequests; open outbound connections | 50/10,000 per invocation; six concurrent, both | Optional evidence reads parallelize; load unprofiled.                                                    |
| Static assets                          | 20,000/100,000 files/version; 25 MiB/file      | 47 files; largest 426,801 bytes.                                                                         |
| Environment entries                    | 64/128 per Worker; 5 KB/value                  | Four existing public config names suffice.                                                               |
| Workers/account                        | 100/500                                        | Account inventory unknown.                                                                               |

Old adapter references to 3/10 MiB compressed limits are stale relative to the
current provider page. Bundle size is not the observed blocker.
[Native Static Assets](https://developers.cloudflare.com/workers/static-assets/billing-and-limitations/)
are free/unlimited only when served without running the Worker; `run_worker_first`
can turn asset requests into billed invocations. No such cost/cache shortcut was
adopted. Extra R2/KV/D1/DO/Queues/Images costs in this prototype: **none**, only
`ASSETS`; future features must justify their own resources.

[Workers Builds](https://developers.cloudflare.com/workers/ci-cd/builds/limits-and-pricing/)
allows 3,000/6,000 account minutes monthly, paid extra $0.005/minute; 1/6
concurrent builds, 20 minutes/build, 2/4 vCPU, 8 GB RAM/20 GB disk. It was not
connected; GitHub CI quotas are separate. [Workers Logs](https://developers.cloudflare.com/workers/observability/logs/workers-logs/)
before the December 1, 2026 change: Free 200,000 events/day/3-day retention; Paid
20 million/month/7 days, extra $0.60/million. Recheck at publication. Logs have
256 KiB/request and account-scale collection limits; never log private evidence.
[Budget alerts](https://developers.cloudflare.com/billing/manage/budget-alerts/)
notify; they are not a hard spending cap.

### Editable pilot estimates (not measurements or approved spend)

Let daily invocations be `M × S × (N × H + U × J + L) + P × D + W`:
staff M, sessions/staff S, navigations/session N, dynamic HTML/RSC/prefetch
requests/navigation H, mutations/session U, requests/mutation/revalidation J,
extra auth/refresh invocations/session L, public discovery visits P, dynamic
requests/visit D, and other account dynamic usage W (including Site/waitlist).
Proxy runs inside an invocation; its backend calls are subrequests, not extra
inbound requests. Below W=0 is illustrative, **not an assertion about this account**.

| Input/result              | Small pilot             | Larger pilot                |
| ------------------------- | ----------------------- | --------------------------- |
| M, S, N, H                | 5, 1, 20, 2             | 50, 2, 40, 2                |
| U, J, L                   | 5, 2, 4                 | 10, 2, 4                    |
| P, D                      | 1,000, 2                | 100,000, 2                  |
| Dynamic/day; 30-day month | 2,270; 68,100           | 210,400; 6,312,000          |
| Free request cap alone    | Below, before unknown W | Exceeded, regardless of CPU |

[Paid pricing](https://developers.cloudflare.com/workers/platform/pricing/):
new account subscription $5 USD/month minimum includes 10 million requests and
30 million CPU-ms; extra $0.30/million requests + $0.02/million CPU-ms. Estimated
monthly Worker bill is `5 + .30 × max(R−10M,0)/1M + .02 × max(R×C−30M,0)/1M`,
where C is assumed average CPU-ms. At **20 ms assumed**, the small pilot is $5
and larger $6.9248 (~$6.92); at **50 ms assumed**, larger is $10.712 (~$10.71).
These CPU assumptions do not satisfy Free's per-invocation 10 ms condition.
One log event/invocation fits the Paid included events in either scenario, but
existing account consumption/extra events may add cost.

Already-Paid account: incremental subscription $0; overages depend on **combined**
requests/CPU/logs, not these isolated examples. Backend, email, domain, monitoring,
taxes and other services are excluded. Existing plan/billing/traffic are unknown.
Node on already-owned spare server capacity could have $0 incremental hosting
subscription, **not $0 total operating cost**; capacity, maintenance and vendor
price are unverified. That is the minimum-change alternative, not authorization
to provision or incidentally implement production Supabase self-hosting.

## Dependency-security follow-up

Read-only final `npm audit`: **16 vulnerable package entries: 11 high, five
moderate, zero critical** (previous 17/one critical). Entries propagated through
parents are not 16 independent exploits. No blind audit fix was run.

| Resolved family / consumers                                                        | Relevant primary advisories and disposition                                                                                                                                                                                                                                                                                                                                                                       |
| ---------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| brace-expansion 1.1.18/5.0.9, minimatch/glob, ESLint, Sentry build exports, shadcn | [Quadratic DoS](https://github.com/juliangruber/brace-expansion/security/advisories/GHSA-q2hr-2g5m-vwhr) patches 1.1.21/5.0.12 cover the newer floor; stack-overflow advisories qhr7/6j4f also affect resolved versions. Untrusted patterns matter; update transitive owners deliberately.                                                                                                                        |
| braces 3.0.3 → micromatch/fast-glob → ESLint/shadcn                                | [Unbounded recursion](https://github.com/advisories/GHSA-vfj7-8cjw-p6xm), no patched release in audit; [upstream issue](https://github.com/micromatch/braces/issues/70). No application glob input found; tooling supply-chain risk remains.                                                                                                                                                                      |
| fast-uri 3.1.6 → AJV/schema-utils/Webpack/Sentry; shadcn config/MCP                | [Host normalization](https://github.com/fastify/fast-uri/security/advisories/GHSA-hrr3-gc8f-f4qj) fixes 3.1.8; port/authority advisories qw65/58mr fix 3.1.7. Runtime reachability requires review, not only npm's dev classification.                                                                                                                                                                            |
| Undici 7.29.0/8.10.1 → Site Miniflare, shadcn dotenvx, jsdom                       | [BalancedPool TLS bypass](https://github.com/nodejs/undici/security/advisories/GHSA-w293-vg96-wgc3), WebSocket/cache cross-user/other audit advisories need 7.29.1/8.10.2. No direct application BalancedPool/cache-interceptor/WebSocketStream use found. Workers native fetch differs; Node 24.20.0 embeds Undici 7.29.0, unaffected by npm package fixes. Review maintained Node 24 security patch separately. |
| Hono 4.13.5; ip-address 10.7.0 via shadcn MCP/socks                                | [Hono boundary XSS](https://github.com/honojs/hono/security/advisories/GHSA-hxh3-vqpv-xpqv) fixes 4.13.7; [IP parsing](https://github.com/advisories/GHSA-j6r3-76f7-8jcv) / h3mg fix 10.7.1. No app CLI/server imports found; tooling updates remain outstanding.                                                                                                                                                 |

Shadcn is listed as a production dependency despite CLI-oriented use. Sentry's
actual Worker runtime/build-export leak means build-only dependencies cannot
all be dismissed as absent from this artifact. No attacker-controlled path to
every advisory was proven, and no blanket release/security clearance is given.
Wrangler/Miniflare, Next ESLint and ts-morph parent audit entries arise through
these paths. A separate scoped security/toolchain plan should update supported
parents, review the no-patch braces path, and repeat runtime/source triage.

## Reproduction, validation and owner handoff

The failed prototype configuration was deliberately **removed**, not committed
as supported deployment configuration. For a future disposable reproduction,
install OpenNext **1.20.8** outside the repo, create a temporary
`open-next.config.ts` importing `defineCloudflareConfig` from that installation's
`dist/api/config.js` and returning `defineCloudflareConfig()` (default dummy
cache, no R2). Its path is machine-specific; do not commit an absolute cache path.
Use a temporary `apps/web/wrangler.jsonc` with precisely:

```json
{
  "name": "planets-web-webhost01-local-probe",
  "main": ".open-next/worker.js",
  "compatibility_date": "2026-09-13",
  "compatibility_flags": ["nodejs_compat"],
  "workers_dev": false,
  "preview_urls": false,
  "assets": { "directory": ".open-next/assets", "binding": "ASSETS" }
}
```

Date matches the existing Site baseline and the tested workerd; a later date
exceeded this installed engine's support. OpenNext requires at least 2024-09-23
with nodejs_compat; see its [manual setup](https://opennext.js.org/cloudflare/get-started).
Run from `apps/web` with Node 24/npm 11:

```text
npm exec --yes --package=@opennextjs/cloudflare@1.20.8 -- opennextjs-cloudflare build
npx --no-install wrangler dev --local --ip 127.0.0.1 --port 3117 --inspector-port 9237 --config wrangler.jsonc
npx --no-install wrangler deploy --dry-run --config wrangler.jsonc
```

No auto-migration, unsupported-version flag, deploy without dry-run or remote
preview was used. Set `WRANGLER_SEND_METRICS=false`. Build twice: DSN empty and
a valid synthetic **loopback-only** DSN, never a real monitoring destination.
Normal committed `npm run check:web` does not require Cloudflare credentials.

For backend reproduction, temporarily copy the canonical config into a separate
checkout with project ID `planets-community-webhost01-qa`; API/DB/shadow/pooler/
Studio/Mailpit/inspector/analytics ports 54361/54362/54360/54369/54363/54364/8087/54367.
Start/reset **only that disposable project**, generate ignored Web local config,
then build, seed and run the documented probes. Never seed the restored shared
config; the committed guards reject it. Restore canonical config afterward.
Its byte hash was verified unchanged. Generated private artifacts and local env
were moved out of the worktree, not published. At final cleanup Docker's Linux
engine was unavailable again; own disposable containers/volumes may remain
recoverable. Once Docker returns, stop **only** that named project using its
temporary configuration; do not run stop/reset against the shared project.

Validation record:

- Web: all **279 tests** (253 inherited + 26 guard/probe), tooling **27**, lint,
  typecheck and no-env Next production build passed. An initial concurrent run
  had two route-test failures/stalled; isolated seven-route and complete verbose
  runs then passed without changing those tests. The final complete
  `npm run check:web` command also passed (279 tests/27 tooling plus lint,
  typecheck and production build).
- Site: **53 tests**, lint/typecheck/build and deployment **dry-run** passed;
  both formatting gates and diff checks passed. No Site deployment occurred.
- Owned clean DB reset/lint and **109 files / 3,465 assertions** passed. An
  earlier contaminated local run failed; own clean reset fixed it, not SQL/test
  edits. Real-auth consequence and suspension/Realtime verifiers and ordinary
  Node production Web OTP/session verifier passed. Security advisor retry was
  **blocked by Docker/54362 connection refusal**, not a passing result.
- Candidate OpenNext builds/dry-runs passed; anonymous 32-request and real OTP/
  refresh/authority/jar verifier passed, but monitoring startup **failed**.
- Mobile and all unrelated domain verifiers were not rerun; their relevant
  trees are identical to #126. Inherited [#126 CI](https://github.com/lillo24/planets.community/actions/runs/37143553475)
  is not final-head CI. Final-head hosted status is recorded in the draft PR;
  unchanged classification selects Web/Site/Database for the root lockfile, not
  Mobile. No hosted rerun or CI-policy weakening is authorized here.

Existing environment contract (no new production secret/config variable):

| Name                                   | Public/secret; lifecycle                               | Future configuration                                                                                      |
| -------------------------------------- | ------------------------------------------------------ | --------------------------------------------------------------------------------------------------------- |
| `NEXT_PUBLIC_APP_ENV`                  | Public; baked browser/build value and server read      | staging/production as appropriate, rebuild on change.                                                     |
| `NEXT_PUBLIC_SUPABASE_URL`             | Public; baked + server                                 | Reachable HTTPS canonical managed/self-hosted endpoint, never developer localhost in cloud.               |
| `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | Public client key; baked + server                      | Matching backend, rebuild; never substitute a service-role key.                                           |
| `NEXT_PUBLIC_SENTRY_DSN`               | Public optional DSN; baked browser + server monitoring | SDK/runtime compatibility first; empty means optional monitoring off, not that import failures are fixed. |

**Founder review request:** choose unchanged Next/Node hosting or authorize a
separate Cloudflare compatibility/migration investigation (supported Proxy,
Sentry v11 evaluation or vinext migration). Review budget assumptions, security
follow-up and unknown account-wide usage. Buying Paid alone fixes neither the
Wasm failure nor experimental support.

Before any separately authorized deployment: resolve these blockers, update
the dependency/security baseline, rerun representative local/browser checks,
verify actual account plan/usage/build/log quotas, approve isolated Worker and
hostname without changing the Site route, configure HTTPS backend/auth origins
and baked env, define secrets/log redaction and rollback. Then authorize a
staging-only deployment and measure cold/warm CPU distributions, startup/memory,
errors, concurrent HTML/Flight/actions and two genuinely independent browser
profiles through the CDN. Reconfirm cookie attributes/CSRF/invite privacy and
failure behavior at that real hostname before choosing Free versus Paid or
publishing. No such owner action was assumed completed.
