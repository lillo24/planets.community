# LINK-HOST-02 — CPU diagnosis of draft PR #176

This continues [PR #176](https://github.com/lillo24/planets.community/pull/176)
on its existing isolated branch. The PR remains **draft and unmerged**.
The measured baseline is code `00583d2402ad800e4a82e29fb3426d27a34dee96`,
deployed Worker version `8e7d46f6-6bf5-4a31-aecd-5340efc5600c`.
At task start, main was re-fetched at `5cfcdd14331f003b5cf3b5e92cb1c2bcd62d9878`;
its intervening changes do not change the Web Auth/rendering implementation.
The final fetch found `4421f08c9969fdc3fee85678ddd881b23828034f`, adding only
Android closed-test plumbing and its documentation, with no Web changes.
No rebase or unrelated integration changed the baseline.

## Findings and decision

Anonymous dynamic rendering already exceeds the Workers Free **10 ms CPU per
invocation** budget. Neither account creation nor admission is needed to
reproduce this. The measured work is distributed across vinext's request/RSC
pipeline, React Flight decoding, React HTML streaming, request-scoped Supabase
client construction, and first-use module initialization. There is no measured
single application function that can safely be removed to fix the budget.

Production workerd profiles identify `app-rsc-handler.js`,
`app-page-element-builder.js`, `app-page-render.js`, `app-middleware.js`,
`request-tracing.js`, the plugin-rsc Flight client, the Supabase server-client
chunk, and the SSR entry. For example, in the first Auth profile, exclusive
non-idle sampled contributions were 33.966 ms in `ssr/index.js`, 25.064 ms in
the RSC entry, 15.211 ms in `createServerClient`, 8.116 ms in the page-element
builder chunk, and 7.688 ms in the SSR Button chunk. 60.688 ms was unattributed
`(program)` time. These are **local sampling contributions**, not measurements
of those modules' hosted CPU. In the warm public-list profile, the SSR
`za` frame's emitted code matches React's `flushCompletedQueues` in
`react-dom-server.edge.production.js`; the mapped Flight client frame points
to line 889 of its production decoder. Source maps do not map every prebundled
React/native frame, so attribution is incomplete.

The first request performs additional lazy imports and rendering not present
in the global startup profile. This explains a plausible first-use contributor;
it does **not** retrospectively identify the route or cold state of the old
199–207 ms mixed hosted outliers. Request logs were disabled, so that historical
attribution cannot be recovered. The new route windows reproduce over-budget
CPU without those operations or outliers. There is no evidence here that
disabled Sentry is the principal hotspot, and it was not stubbed or removed.

The smallest trial eagerly loaded the existing SSR entry with
`await import.meta.viteRsc.loadModule("ssr", "index")` at Worker module startup.
It loaded code only and kept Proxy, per-request clients and all handlers intact.
It increased sampled global startup and did not consistently reduce first or
warm request estimates, so it was **discarded before deployment**. No runtime
optimization is retained, and no new Worker version was uploaded.

Free operation is **not established and cannot be recommended for cutover**.
Repeated anonymous Auth, discovery and rendered RSC exceed 10 ms, with no
headroom for real login/refresh/profile/Join work. Successful responses, a
single median below 10 ms, bundle size, and the 22 ms reported deployment startup
do not establish reliable Free operation. This does not rule out every Free
architecture. The limit and profiling method are documented by Cloudflare in
the [Workers limits](https://developers.cloudflare.com/workers/platform/limits/)
and [CPU profiling guide](https://developers.cloudflare.com/workers/observability/dev-tools/cpu-usage/).

## Hosted measurements

Each window sent 30 sequential, anonymous requests of one fixed class and fully
consumed each body. Windows are separated by 2.2 seconds. No other probes were
run against this Worker during a window. GraphQL filters include the exact
Worker, version and UTC start/end; no route dimension is available. Another
operator's traffic cannot be excluded. `avg.sampleInterval` is greater than 1,
so `sum.requests` is an adaptive estimate and can differ from the 30 sent.
Estimated counts are shown explicitly. Quantiles are direct window aggregates;
none were subtracted. These bounded samples are not a production tail forecast.

First windows: 2026-10-08 20:30:33–20:31:06 UTC; corrected rendered RSC:
20:36:41–20:36:45 UTC. Repeat windows: 20:49:31–20:50:11 UTC. Both sets ran
the **same deployed code/version**. The repeat is not an optimized deployment.
Hosted isolate affinity/cold state was not controlled; an idle interval was not
called a cold start. Local fresh-isolate tests below provide that separation.

All values are **CPU ms**, converted from schema-verified microseconds. Every
valid class had 30/30 expected HTTP results and zero reported Worker errors.

| Class                            | First p50 / p95 / max    | Repeat p50 / p95 / max   | GraphQL estimated requests, first → repeat |
| -------------------------------- | ------------------------ | ------------------------ | ------------------------------------------ |
| Auth HTML                        | 11.443 / 17.167 / 17.670 | 17.111 / 24.442 / 31.181 | 30 → 30                                    |
| Public list                      | 14.544 / 21.924 / 23.353 | 22.532 / 36.459 / 45.290 | 29 → 28                                    |
| Missing public detail            | 11.437 / 19.096 / 20.365 | 14.516 / 27.954 / 37.417 | 42 → 32                                    |
| Malformed participant invitation | 8.286 / 15.728 / 16.534  | 12.452 / 17.812 / 30.621 | 30 → 29                                    |
| Signed-out confirmation          | 8.235 / 17.005 / 72.783  | 10.949 / 16.887 / 87.673 | 30 → 30                                    |
| Profile → Auth redirect          | 6.268 / 15.845 / 20.697  | 10.676 / 16.210 / 18.036 | 29 → 31                                    |
| Rendered public RSC              | 10.696 / 20.281 / 22.862 | 13.442 / 22.533 / 28.825 | 30 → 30                                    |
| Disabled association JSON        | 0.466 / 0.804 / 0.804    | 0.819 / 1.033 / 1.036    | 30 → 30                                    |
| Emitted static asset             | Worker bypass            | Worker bypass            | 0 → 0                                      |

The first RSC control mistakenly requested the uncanonicalized transport URL:
all 30 returned the expected adapter 307 instead of rendered Flight. That
window (1.172 / 1.398 / 1.398 ms) is a **redirect control**, excluded from the
rendered-RSC row. The probe was corrected to resolve and validate the bounded
same-origin `_rsc` redirect once before measuring 30 HTTP-200 Flight responses.
This initial probe mismatch is not hidden as a passing rendering test.

Static controls were emitted assets discovered from Auth HTML. Local user-isolate
profiling recorded no samples for them, and hosted GraphQL recorded no Worker
invocations. The configured ASSETS layer serves them before the app Worker.

There was no authorized disposable invitation/account/OTP fixture. Valid preview,
signup, OTP verification, authenticated refresh, profile completion, explicit
Join and real membership confirmation are **unmeasured**. Missing-detail and
signed-out confirmation results are not successful detail/admission proof.
The existing streamed missing Proposal shell intentionally carries the
`NEXT_HTTP_ERROR_FALLBACK;404` digest despite HTTP 200.

## Local startup and optimization trial

The profiles run production Vite output under pinned Wrangler/workerd, not
the Vite development rendering path. Requests are profiled using CDP
`Profiler.start`/`stop`, requesting a 100 μs sampling interval, and consuming
the complete body before stopping. `(idle)` deltas are excluded; GC is included.
This is the same non-idle delta summary used by pinned Wrangler's startup
profiler. **Windows scheduling, profiler overhead, long sampling gaps and
unmapped/native frames make these estimates unsuitable as hosted/billing CPU
counters.** They are neither network stopwatch timings nor Free certification.
Zero samples for a short handler do not prove zero CPU.

The global-only profile uses Wrangler's `check startup` on a dry-run multipart
bundle. Its synthetic request imports the app module without calling app.fetch.
Each request run deliberately starts and disposes a local Worker process.
The first requests use three separate fresh isolates (Auth, list, malformed
invitation respectively); all returned their expected response. In the first
isolate each class is primed and then measured 30 times. Hosted metrics, not
local absolute duration, establish the budget problem.

| Non-idle sampled work, ms                          | Baseline                    | SSR preload trial           |
| -------------------------------------------------- | --------------------------- | --------------------------- |
| Global module startup, one sample each             | 68.850                      | 190.463                     |
| First Auth request in a fresh isolate, n=1         | 216.817                     | 178.859                     |
| First list request in a fresh isolate, n=1         | 359.212                     | 902.093                     |
| First malformed invitation in a fresh isolate, n=1 | 150.412                     | 229.718                     |
| Warm Auth p50 / p95 / max, n=30                    | 48.185 / 107.788 / 113.458  | 41.604 / 78.092 / 79.235    |
| Warm list p50 / p95 / max, n=30                    | 102.115 / 138.869 / 341.771 | 108.078 / 182.254 / 383.182 |
| Warm missing detail p50 / p95 / max, n=30          | 98.099 / 131.152 / 329.013  | 111.028 / 170.353 / 218.725 |
| Warm malformed invitation p50 / p95 / max, n=30    | 35.057 / 46.558 / 48.900    | 37.462 / 63.584 / 66.529    |
| Warm confirmation p50 / p95 / max, n=30            | 53.234 / 99.232 / 162.750   | 56.485 / 102.819 / 112.013  |
| Warm Auth redirect p50 / p95 / max, n=30           | 24.523 / 37.708 / 83.462    | 38.187 / 129.864 / 160.129  |

These paired route classes had zero response errors in both builds. The baseline
local RSC probe had the same redirect mismatch described above, so it is excluded
from this comparison; the trial's corrected RSC had 30/30 Flight responses.
The final corrected baseline run uses the published harness: 288 profiled reads,
zero response errors, and three fresh isolates. First Auth/list/malformed reads
were 196.285 / 358.414 / 125.793 ms of non-idle samples respectively. No
request-specific state was shared to obtain these measurements.

| Final baseline, non-idle sample ms, 30 warm reads each | p50    | p95     | max     | Response errors |
| ------------------------------------------------------ | ------ | ------- | ------- | --------------- |
| Auth                                                   | 38.655 | 76.859  | 171.051 | 0               |
| Public list                                            | 98.490 | 173.518 | 176.739 | 0               |
| Missing detail                                         | 89.012 | 109.018 | 202.764 | 0               |
| Malformed invitation                                   | 35.993 | 91.094  | 105.721 | 0               |
| Signed-out confirmation                                | 25.943 | 38.847  | 40.574  | 0               |
| Auth redirect                                          | 24.945 | 47.217  | 67.708  | 0               |
| Rendered RSC                                           | 84.600 | 133.302 | 153.639 | 0               |
| Association                                            | 0.000  | 23.694  | 27.476  | 0               |
| Static asset                                           | 0.000  | 0.000   | 0.000   | 0               |

The association's zero median and long-gap upper samples illustrate the
sampling limitations on this Windows host; use its hosted measurements for
the actual CPU budget. The asset's absence of user-isolate samples is additionally
confirmed by hosted absence of Worker invocations.

## Reproduce safely

Use the committed lockfile and public staging env from the
[LINK-HOST-01 runbook](link-host01-cloudflare-invitations.md). Node 24.19.0 was used
for profiling; repository CI uses 24.20.0. Stop the existing preview before
profiling. From `apps/web`:

```text
npm run worker:profile-build:staging
node scripts/profile-worker-local.mjs baseline
node node_modules/wrangler/bin/wrangler.js deploy --config dist/server/wrangler.json --dry-run --outfile .wrangler/link-host02/baseline.bundle
node node_modules/wrangler/bin/wrangler.js check startup --workerBundle .wrangler/link-host02/baseline.bundle --outfile .wrangler/link-host02/baseline-startup.cpuprofile
node scripts/profile-worker-hosted.mjs baseline
node scripts/read-worker-cpu.mjs baseline
```

The profile build adds private hidden source maps while preserving production
mode. All profiles and local telemetry live in ignored `.wrangler/link-host02`;
never commit/upload raw profiles, source maps or logs. Tools emit only fixed
class labels, status/counts, aggregate timings and code frames; they accept no
real capability, cookie, email or OTP. The hosted tool reads the existing
Windows Wrangler OAuth store or `CLOUDFLARE_API_TOKEN` and prints no credentials.
Use `wrangler whoami` privately to refresh expired OAuth first. Wait for analytics
ingestion before reading windows; absent metrics are missing coverage, not zero
CPU. An optional last argument to the hosted profiler selects one fixed class.

`ws` 8.21.0 and `@jridgewell/trace-mapping` 0.3.31 are direct diagnostic dev
dependencies, matching their already-locked versions. No runtime dependency
was upgraded. Tests cover CPU/idle/GC accounting, sparse quantiles, bounded RSC
redirects and fixed non-secret inputs. The staging deploy runner refuses client
`.map` files: rebuild with ordinary `worker:build:staging` before any deployment.
The rejection was exercised without invoking Wrangler deployment.

## Resource and release boundaries

Read-only access and deployment metadata were verified before measuring. The
Worker still uses version `8e7d46f6-6bf5-4a31-aecd-5340efc5600c` at 100%.
Its configured usage model is `standard`; subscriptions returned 403, so the
actual Workers billing tier remains **unverified**. The zone's Free Website
label is not Workers-tier proof. No paid option or billing change was enabled.
Request Observability remains disabled. No deployment, DNS/Route/Site change,
shared Supabase reset/seed/migration, signing/store change, or PR merge occurred.

The existing deployment's rollback target was recorded and CLI help verified:

```text
node node_modules/wrangler/bin/wrangler.js rollback 5fe98031-16ad-4b95-b1e2-f7485764ee59 --config dist/server/wrangler.json --yes --message "Restore previous isolated staging version"
```

This is an available rollback, not a command executed by this diagnosis.
The retained runtime is the original baseline, so no update/rollback was needed.
Canonical invitation URLs remain unfixed until separate live-routing and real
browser-flow gates pass. The historical six local full-Web failures and green
baseline hosted CI remain recorded in LINK-HOST-01; final checks and exact-head
hosted CI for this change are recorded on the draft PR.

## Validation of the published diagnostic tooling

The complete local process-pool Web run passed **293 tests with one skip**
(48 files). A second complete run had **291 passes, one skip and two failures**
in `admin-route.test.ts`: its signed-out test exceeded the unchanged 5-second
timeout, and the following ordinary-user test observed two mock calls instead
of one. Both outcomes are retained; this nondeterministic local result does not
erase the original six failures. No application test, assertion or timeout was
weakened. Final-head Linux CI results are recorded on the PR separately.

Repository tooling tests (53), the final focused CPU/ingress tests (9), Web lint,
Web typecheck, ordinary Next production build including TypeScript, production
Worker build, generated-config dry-run, all 30 normal-build local HTTP probes,
`format:check:web`, explicit MJS/MTS/JSONC formatting and `git diff --check` passed.
The final focused rerun includes rejection of normalized asset traversal.
The normal Worker output contains no diagnostic source maps and reports
1,974.14 KiB upload / 569.75 KiB gzip, ASSETS only. It was not uploaded.
No local/shared Supabase reset or database suite, physical-device test or real
browser OTP/Join session was run. Site source/contracts and locked package
versions are unchanged; hosted CI covers the shared lockfile metadata change.

## Smallest next option

Prepare a separately authorized feasibility plan for a **static browser
invitation client** served as assets, using the existing canonical Supabase
Auth and invitation/profile/admission RPCs. Rendering would move to the browser;
RLS/capacity/blocking rules would remain in PostgreSQL. Prove OTP/return
continuation, session/privacy behavior and explicit Join before choosing that
architecture. This is a proposal, not an implemented Proxy bypass or a second
invitation business-rule implementation. Existing dynamic discovery and Next
administration still need their own measured hosting choice; a static invitation
client does not automatically host the current admin server surface.

The founder's installed-app alternative remains a future choice: installed app
opens the original invitation; otherwise download from Play Store and manually
reopen that invitation after installation. No store URL was invented, no native
association was certified, and automatic post-install continuation is not
implemented or claimed. No mobile OTP retest is requested by this diagnosis.
