# PI04 — native links and public host readiness

PI04 extends repository link configuration and defines a provider-neutral public
origin contract. It does not deploy an ingress, change DNS, select a dynamic web
host, replace bootstrap identities/signing, or publish a store listing.

Dependency/base: PI03 merge `f291bdd017ba0509b4aba7e80dd655457c26c3bf` on
`main`. Hosting assessment PR #130 remains an unmerged draft on a different
dependency branch; its provider/runtime/dependency changes are not adopted.

## Native delivery boundary

Android's resolved minimum SDK is 24 (target 36); iOS targets 15. Android uses
four separate HTTPS `planets.community` data tuples with API-1 simple-glob
`pathPattern` rules. Invitation tails have exactly 43 single-character dots;
detail tails have UUID-length groups and literal hyphens. There is no whole-host
or prefix claim, new origin, custom scheme, plugin, or Android 15-only exclusion.
The active plan retains HTTPS-only behavior despite broader HTTP+HTTPS examples
in current Android guidance.

Apple's existing association response uses ordered legacy `paths`: four
`NOT <family>/*/*` descendant exclusions precede fixed-length `?` invitation and
UUID-shape detail globs. This representation supports the existing minimum iOS
target. Queries do not participate in OS path matching and remain available to
Flutter. Entitlements and Flutter AppDelegate/SceneDelegate integration remain
the existing owners.

OS matching is not UUID/token validation. Android dots can match invalid
characters or a same-length crafted slash path; Apple globs can match invalid
characters. Neither proves database existence, admission, or current membership.
Standard `/edit`, `/join`, `/participant-links` and other management descendants
of a UUID do not match. Tests pin both accepted paths and unavoidable overreach.

`app/router/native_project_links.dart` validates absolute platform arrivals before
the existing GoRouter routes: canonical HTTPS host, no credentials/nondefault
port/fragment/encoded path characters, an exact URL-safe 43-character token, or
a UUID v1–5 with a valid variant and no descendant. Token URLs have no query;
detail queries retain their exact multiplicity. Dart normalizes explicit default
HTTPS port 443 to the canonical origin. Relative internal navigation keeps its
existing contracts and protected route guards.

The router converts valid external destinations into internal routes. Invalid
or browser-only external URLs reach a generic `/link-unavailable` screen,
without echoing URLs, fetching protected data, accepting, or reopening a browser.
Duplicate delivery retains the same preview/attempt, OTP form or profile return.
A different valid external destination cancels a pending OTP flow so an old
completion cannot navigate back to its previous Project. Account/Project revision
guards remain in the feature controllers; native delivery never means Join or
re-entry.

The routing configuration exposes GoRouter 18's entry guard only while the
existing route-information provider holds an external URL. A duplicate stops
before parsing and retains the existing match list/form. A different-link
`Allow(then: ...)` cancels OTP after navigation commits, including an in-flight
email-code request. Relative internal navigation retains synchronous parsing,
startup/restored Auth and initial loading states. No second platform listener
or plugin is registered.
Restored Auth does not rebuild an initial empty match list during cold native
parsing; initial redirects read the latest session and no private stacks exist
yet. Established routes still replace shell/branch keys on account changes.

## Public origin ownership contract

There is no approved shared production ingress in main. The existing Site Worker
owns Static Assets and only the bounded waitlist endpoint; its configuration is
not a proxy for Next. The following is the deployment contract to satisfy when
an origin and ingress are explicitly approved, not a new hosting decision.

| Public path                                                   | Response owner                                  | Native destination                                               |
| ------------------------------------------------------------- | ----------------------------------------------- | ---------------------------------------------------------------- |
| `/join/project/<token>`                                       | Next participant preview and explicit admission | Minimal participant preview                                      |
| `/invite/project/<token>`                                     | Existing Next authority preview/acceptance      | Existing authority preview                                       |
| `/proposals/<uuid>?intent=join`, `/tavoli/<uuid>?intent=join` | Next public detail and app CTA                  | Existing dismissible ordinary request intent; exactly one marker |
| `/proposals/<uuid>`, `/tavoli/<uuid>`                         | Next public detail                              | Non-mutating detail and same-account rediscovery                 |
| `/joined/proposals/<uuid>`, `/joined/tavoli/<uuid>`           | Next verified confirmation                      | Browser-only; its app button uses token-free public detail       |
| `/auth`, `/profile`, safe internal returns                    | Next OTP/profile and session cookies            | Browser-only                                                     |
| Both advertised `/.well-known` endpoints                      | Next association response owner directly        | Verification resources, not destinations                         |
| `/_next/*`, RSC/prefetch/POST to Next routes                  | Next assets/runtime                             | Browser transport                                                |
| `/proposals`, `/tavoli`, `/admin` and descendants             | Next list/admin or Next 404                     | Only the valid public details above are claimed                  |
| `/`, informational assets, `/api/waitlist`                    | Site assets / existing waitlist Worker          | Browser-only                                                     |
| Unknown path in a Next namespace                              | Next 404                                        | Unclaimed                                                        |
| Unknown informational/API path                                | Site asset/API 404, no SPA shell                | Unclaimed                                                        |

Route namespaces before static asset resolution. Preserve the request method,
unmodified path/query, body, cookies, Origin, Next transport headers and response
status/content type/body. Preserve **multiple separate Set-Cookie headers**,
including session refresh/deletion; never fold them into a comma-separated value.
The public origin must remain the browser origin through relative auth/profile/
confirmation navigation. A cross-origin redirect is not a substitute for proxying
the application and its assets. No product path can fall through to D1/waitlist.

Use a defined trusted ingress hop chain: discard/reconstruct client-supplied
Forwarded/X-Forwarded-* metadata, validate advertised Host and Origin, and only
send verified public-origin values to Next. Do not let untrusted forwarding
headers affect cookies, redirects or server actions. Preserve HTML, RSC,
prefetch and POST behavior; do not force content type or buffer/rewrite bodies
as static HTML.

Verification endpoints must be direct, unauthenticated, nonredirecting JSON.
`src/proxy.ts` now bypasses session refresh for these two exact resources.
Missing/malformed/bootstrap identity still yields 404 JSON with `no-store`;
valid configuration yields 200 JSON with public max-age/s-maxage 300. Never
suppress that disabled 404, serve a challenge/login/index page, or append a
trailing-slash/cross-host redirect to the advertised paths.

Participant/authority/auth/profile/confirmation traffic bypasses shared caching.
Preserve `no-store`, `no-referrer`, `noindex/nofollow/noarchive`, dynamic renders
and cookie refresh. Personalized confirmation cannot be cached under a public
key. Preserve canonical Supabase security and browser explicit admission.

## Local reproduction and evidence

`apps/web/test-support/public-host-harness.ts` is a disposable, loopback-only Node
streaming proxy with no access logger/cache/redirect following. Its tests use
stand-in owners to exercise precedence, methods, queries, RSC/prefetch headers,
body forwarding, separate cookies, invalid origin rejection and unmasked 404s.
It is not shipped as the Site Worker or an approved production ingress.

`pi04-browser-fixture.ts` refuses every backend except the explicitly opted-in
`planets-community-pi04` stack on ports 58720–58729. It seeds synthetic public
Projects, stores capabilities only in ignored `.env.pi04-browser.json`, runs
production Next on 3155, a disposable Site stand-in on 3156, and the public-origin
harness on 3154. Next stdout/stderr and request logging are disabled. The stand-in
launch/OTP helpers are test resources, not product routes or a real waitlist.
The fixture's capture mode obtains a second verified session for the same
synthetic account, checks the browser-joined Proposal, revokes the original
links and writes only ignored mobile configuration for the adapter check.

Web's `allowImportingTsExtensions` supports these directly runnable Node
TypeScript helpers under the existing `noEmit` configuration; no dependency or
production runtime change was added.

Before starting, check 58720–58729, 8783 and 3154–3156 are free. Back up
`supabase/config.toml` to an ignored local file, change only its project ID to
`planets-community-pi04`, its 54320–54329 ports to 58720–58729, and Edge inspector
port to 8783. Do not reset or stop another stack. From the repository root:

```powershell
npm run db:start
npm run web:config:local
npm run mobile:config:local
npm run build --workspace @planets/web
$env:PI04_LOCAL_REHEARSAL = '1'
$env:PATH = "$((Get-Location).Path)/node_modules/.bin;$env:PATH"
node apps/web/test-support/pi04-browser-fixture.ts
```

Use the loopback landing page in Chrome. Open Proposal preview, sign in with
the fixture's synthetic email, retrieve the numeric code privately from its
loopback OTP helper, and enter it in the actual OTP form. Cancel basic-profile
setup back to preview, reopen and save only a display name, then explicitly
Join. Confirm a token-free `/joined/proposals/<uuid>` URL and same-account copy.
Repeat for Tavolo, check reload/back without another admission, browser
cancellation, ordinary-intent fallback and app-button behavior. Keep tokens,
emails, OTPs, cookie contents and screenshots of token-bearing browser chrome
out of reports and diagnostics.

After the browser Proposal join, in another root shell:

```powershell
$env:PI04_LOCAL_REHEARSAL = '1'
$env:PATH = "$((Get-Location).Path)/node_modules/.bin;$env:PATH"
node apps/web/test-support/pi04-browser-fixture.ts --capture-mobile
cd apps/mobile
flutter test --no-pub --dart-define=PI04_LOCAL_REHEARSAL=true test/features/project_participant_invites/participant_web_rediscovery_test.dart
```

That test uses production mobile gateways with a verified same-account token:
own current membership and chat remain after revocation, repeated own reads do
not create an episode, revoked preview is unavailable, and anonymous own reads
fail. It is an adapter/backend check, not mobile GUI login or native association.

Run the actual production HTTP probes with the fixture server running:

```powershell
$env:PI04_PROBE_ORIGIN = 'http://127.0.0.1:3154'
node apps/web/test-support/pi04-host-probe.ts
```

Stop only this fixture server, then restart it with `--reuse
--enabled-associations` and run the probe with `--enabled-associations`. It
checks GET/HEAD direct JSON/status/cache/no-cookie contracts with synthetic
public identities, sensitive headers, actual HTML/Next assets/RSC/prefetch/POST,
and both owners' 404 behavior. Synthetic identities never establish a real app
association. Do not build into `.next` while using it for browser QA; finish the
build before starting/restarting the production server.

Required gates are `npm run check:mobile`, `npm run check:web`,
`npm run format:check:web`, and `git diff --check`. Site/schema were not changed;
Site/Database CI are expected to skip under the existing classifier. For merged
manifest validation after the debug APK build:

Final local results:

- `npm run check:mobile`: localization, formatting and analysis passed;
  **1,204 tests passed, two opt-in backend tests skipped**.
- `npm run check:web`: **28 tooling tests and 263 Web tests passed, one opt-in
  integration test skipped**; lint, type generation/typecheck and production
  build passed. The final fixture/probe files also passed scoped ESLint and
  `npm run typecheck --workspace @planets/web`.
- `npm run format:check:web` and `git diff --check` passed.
- `flutter run -d emulator-5554 --no-pub --dart-define-from-file=config/local.json
--dart-define=ENABLE_DEMO_TOOLS=false` built/installed the debug APK and started
  normally. DTD hot reload of the final routing code succeeded with no runtime
  errors. The merged-manifest command below passed both checks.
- The documented production HTTP probe passed in both disabled and
  `--enabled-associations` modes. The explicit same-account mobile rediscovery
  command above passed its one opt-in adapter/backend test.

```powershell
cd apps/mobile
$env:PLANETS_MERGED_MANIFEST = 'build/app/intermediates/merged_manifests/debug/processDebugManifest/AndroidManifest.xml'
flutter test --no-pub test/app/router/native_project_invite_links_test.dart
Remove-Item Env:PLANETS_MERGED_MANIFEST
```

After verification, close only task-created browser tabs, stop only this fixture
server/Flutter process, stop `planets-community-pi04` with `--no-backup`, restore
the original `supabase/config.toml`, and remove task-owned ignored fixture/config/
logs. Never print the local configuration or inspect personal browser history.

This run stopped only its fixture/Next server, Flutter process and PI04 backend,
and restored `supabase/config.toml` without a diff. Automatic approval review
rejected removing the task-owned ignored fixture/config files with “blocked by
policy”; no more specific reason was supplied and equivalent deletion was not
retried. They remain ignored. Managed checkout cleanup remains pending so that
archival is not used to sidestep that rejection.

| Evidence                        | PI04 result / limit                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| ------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Repository configuration/tests  | Bounded four-family OS filters; application origin/shape rejection; platform default-route and `flutter/navigation` cold/warm/duplicate/onboarding/stale-result tests; association identity/fingerprint/cache/body tests. Final required gate results recorded with the PR.                                                                                                                                                                           |
| Local Android build/runtime     | Flutter 3.47.2 / Dart 3.13.2; debug APK built and installed, bootstrap package `community.planets.bootstrap.planets_mobile`, target 36, Android 17/API 37 emulator. Normal startup, DTD hot reload and runtime-error check passed. Actual merged manifest tests passed.                                                                                                                                                                               |
| Native URL intent dispatch      | Force-stop + explicit VIEW + link-status command group rejected by automatic approval review with “blocked by policy”; not retried through an equivalent mechanism. Cold/warm Android intent smoke and verified-domain resolution remain unexecuted.                                                                                                                                                                                                  |
| Local production HTTP           | Disabled and synthetically enabled associations passed, including GET/HEAD JSON/direct/cache/no-cookie contracts. HTML/assets/RSC/prefetch/POST and privacy/404 probes passed. Stand-in Site is not real deployed waitlist evidence.                                                                                                                                                                                                                  |
| Local browser                   | Chrome 154 on Windows, production Next 16.3.4 and dedicated Supabase: Proposal preview, actual numeric OTP entry, profile cancellation/completion, explicit photo-free Join, token-free current-membership confirmation and unavailable-download/same-account copy verified. Automation detached during reload; reload/back, Tavolo browser join and actual Open PLANETS click remain unverified. In-app browser attachment also timed out.           |
| Same-account mobile rediscovery | Production mobile adapter against the same synthetic browser account passed: Proposal membership/chat remain after original link revocation; no new admission. Mobile GUI sign-in/install-later journey remains unexecuted.                                                                                                                                                                                                                           |
| Live public host, 2026-10-05    | Read-only HTTPS fetch: root 200 HTML (`server: cloudflare`, `cache-control: public, max-age=0, must-revalidate`); both well-known endpoints and non-secret sample participant/public-detail URLs 404. Association 404 responses had no observed JSON MIME/cache headers. No redirect was observed with redirect following disabled. Actual origin/ingress owner, cache rules, TLS/DNS account control and access-log configuration remain unverified. |
| Signed Android/iOS delivery     | Final identities/certificates/provisioning unavailable; bootstrap guards retained. No verified domain, signed production build, external-app tap or installed/absent device comparison proved. Windows cannot build/test iOS through Xcode/macOS.                                                                                                                                                                                                     |
| Stores/downloads                | Neither real download setting/listing is configured in this rehearsal. Unavailable copy is retained; no listing ID or Smart App Banner is invented.                                                                                                                                                                                                                                                                                                   |

## External release runbook

Account owners must supply an approved Next dynamic origin and ingress owner,
public DNS/TLS/domain access, the final Android application ID and matching
installed/distribution certificate SHA-256 fingerprints, Apple application
identifier prefix/Team/bundle and signed Associated Domains provisioning,
signed test builds/devices, and real store/download listings. Association
identifiers are public; private keys/signing credentials do not belong in chat.
Deployment/DNS/store actions require their own explicit operational authorization.

Verify the advertised resources directly without `-L` or authentication:

```powershell
curl.exe --max-time 15 -i https://planets.community/.well-known/assetlinks.json
curl.exe --max-time 15 -i https://planets.community/.well-known/apple-app-site-association
```

Record status, MIME, JSON, cache headers, every redirect, actual certificate/app
identity and ingress/origin ownership. Enabled responses must match the
distributed build; disabled 404 must remain intentional no-store JSON. A fetch
or a synthetic serializer test is not device delivery proof.

For an installed signed Android build, with the **actual public** application ID
in `PLANETS_ANDROID_APP_ID` and an existing public UUID in `PLANETS_PUBLIC_UUID`:

```powershell
adb shell pm verify-app-links --re-verify $env:PLANETS_ANDROID_APP_ID
adb shell pm get-app-links $env:PLANETS_ANDROID_APP_ID
adb shell am start -W -a android.intent.action.VIEW -c android.intent.category.BROWSABLE -d "https://planets.community/proposals/$($env:PLANETS_PUBLIC_UUID)?intent=join"
```

Allow verification time, then record the domain's **verified** state. A user
manually enabling a domain is a preference override, not verification. An
untargeted VIEW (no package/component) must resolve naturally. Separately test
external-app taps and the browser Open PLANETS button, cold start and warm
delivery, duplicate delivery, both families, signed-out/profile/account changes,
app absent and installed states. Use only disposable invitation capabilities
through UI taps for token cases; do not paste raw tokens into shell history,
screenshots, telemetry or copied diagnostic URLs. Do not force success by
manually approving domains and then label them verified.

On macOS, validate signed iOS bundle/entitlements/provisioning against the AASA
appID. A simulator `xcrun simctl openurl booted` with a token-free public Project
URL can exercise dispatch; it cannot establish production signed-device
verification. On a signed device, tap public/synthetic invitation links from
Messages/Notes or another external app, cold and warm. Test the actual same-domain
Safari Open PLANETS button separately; Safari may retain same-domain navigation
or the user's browser preference even with valid association. Keep normal web
fallback working. Record OS/browser, external versus same-domain source,
installation/cache propagation and user preference; reinstall only when the
tester understands its local-data consequences. A Smart App Banner is a later
option only with a real listing. Never infer launch success from a timer or AASA
fetch, and never transfer a browser session in a URL.

## Privacy and remaining integration scope

Existing application Sentry filters remain responsible for direct/encoded token
URLs, nested returnTo values, RPC bodies, exceptions and navigation breadcrumbs.
They do not configure CDN/ingress/origin logs or analytics. Future owners must
suppress or redact token-bearing paths and repeatedly encoded return queries
**before** persistence/export; include WAF/CDN request samples, load balancer,
origin/Next access and error logs, analytics, traces, screenshots and support
exports. Define and verify cache bypass, cookie handling, retention periods,
operator access and export destinations with synthetic probes. No remote logging
configuration has been verified. Bearer links may still appear in OS/browser
history; do not promise universal history removal.

PI05 can consolidate the integrated demo and complete outstanding browser
reload/back/Tavolo/handoff cases, mobile GUI same-account rediscovery, ordinary
photo/contribution/approval checks, revoked-link/install-later and admission
recovery/re-entry/account-switch regressions. Public routing and signed-device
proof require the account-owner inputs above and a separately authorized release
setup. PI04 repository completion does not establish live hosting or store delivery.

Primary platform references checked for this plan:

- [Android App Link filters/compatibility](https://developer.android.com/training/app-links/add-applinks) and [data-pattern semantics](https://developer.android.com/guide/topics/manifest/data-element).
- [Android verification](https://developer.android.com/training/app-links/verify-applinks).
- [Flutter Android App Links](https://docs.flutter.dev/cookbook/navigation/set-up-app-links) and [Flutter iOS Universal Links](https://docs.flutter.dev/cookbook/navigation/set-up-universal-links).
- [Apple Associated Domains](https://developer.apple.com/documentation/xcode/supporting-associated-domains) and [archived Universal Link matching/Safari behavior](https://developer.apple.com/library/archive/documentation/General/Conceptual/AppSearch/UniversalLinks.html); current signed-device behavior still needs testing.
