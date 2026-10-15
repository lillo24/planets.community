# PLANETS MAPFIX03 — Prove and repair missing live map previews on Android

## Goal

After MAPUI03's text-only UI is integrated, determine **why valid Proposal locations still do not show map pixels in the user's installed PLANETS app** and fix the confirmed cause. Do not mistake a city label, a working Google Maps link, a 200 preview RPC or a synthetic Android renderer test for proof that authenticated Geoapify tiles reached the device and were drawn.

## Verified baseline and hypothesis

Use current `origin/main`, `AGENTS.md`, `docs/development/mapfix02-project-detail-map.md`, `docs/development/map-live01-android-activation.md`, `docs/development/map-cache01-shared-tiles.md`, `docs/development/staging01-hosted-deployment.md`, and the relevant Flutter build/tests. At prompt preparation the observed main head was `87f3983cbf1f8bd46f117568b32d91e9e0458042`; recheck before any branch/PR.

- `mappa test`, ID `ca208af9-bacd-4ae7-a107-dd79b9624a9e`, has verified public Geoapify locality geometry for **Trento** in Supabase `planets-staging` (`cllpvruvrrvxczjitlqd`). Do **not** alter this record for testing.
- Read-only staging configuration observed `enabled=true`, `tiles_enabled=true`, `center_enabled=true`, `cache_license_approved=true`, `tile_cache_seconds=60`, `failure_streak=0`, no block. Canonical `get_location_preview_v1` has repeatedly returned HTTP 200 to Dart Android clients. These facts don't establish that tile requests worked.
- Ordinary `apps/mobile/tool/build_staging_bundle.dart` does **not** opt into maps. Detail tiles require both `LOCATION_MAP_TILES_ENABLED=true` and `LOCATION_DETAIL_TILES_ENABLED=true` at **compile time** (and effective authenticated provider readiness). `apps/mobile/tool/build_map_live_staging.dart` sets both flags plus bounded reuse and editor search.
- MAPFIX02 PRs #235 and #236 confirmed the prior code-9 AAB had a disabled map-provider gateway, added four offline native flag combinations, and prepared a signed **0.1.6+10** map-enabled candidate. It did **not** prove which artifact was installed or perform live authenticated device QA or a Play rollout.
- STAGING01 subsequently applied **96 staging migrations**, fixing missing Proposals/Messages RPCs. It did not change compile-time map flags or install an APK.
- At the recent inspection, staging logs had many successful canonical preview RPCs and **no observed `/functions/v1/map-provider` request in the sampled recent log query**. This points to a possible disabled client gate or an unobserved/unauthorized transport path, but log coverage itself is not definitive.
- `LocationPreviewPanel` conditionally mounts `ReadOnlyBasemap` through tile/detail flags and a shared tile store. `ReadOnlyBasemap` handles decode and drawing; it reports optional failures as fallbacks. Static previews deliberately remain disabled. Guest-paid tile access is intentionally gated.

## Investigation order

1. **Prove the exact installed build.** Use read-only ADB against physical phone `48091FDAS0041A` when USB debugging is authorized: `adb -s 48091FDAS0041A devices -l`, `dumpsys package community.planets.app`, installer, version code/name, signing identity, base APK provenance/hash if accessible. Inspect the actual Play Closed-testing assignment/artifact and existing release manifests/build logs if connected. Do not infer from current `pubspec.yaml`, latest main, or highest version code. If the phone is unavailable, state that as a blocker and proceed with isolated emulator/live QA without claiming physical acceptance.
2. **Prove compiled gates, not just source presence.** Determine whether the installed/distributed artifact has the map transport gateway and detail tiles enabled (reproducible manifest, signed artifact inspection or contained safe diagnostics). Compare with MAPFIX02 code-9 code-10 evidence and current build. Do not claim a map-enabled AAB was distributed merely because it was built locally.
3. **Check user/session and authorized projection.** Preserve signed-out privacy and private exact-place protections; verify `mappa test` resolves to public locality under an authorized test client, and whether the device is signed into the expected staging account. Do not harvest OTP/JWT or ask the assistant for secrets.
4. **Observe tile traffic and one actual decoded frame.** If both client flags are on, with the user's authorized staging session exercise ONE bounded map detail, trace strictly sanitized stage outcomes: not attempted, disabled client/server, guest auth, 401/403, 429/budget, provider disabled/unconfigured, latency/transport, invalid PNG, decode, viewport/layout, success. Correlate with server function logs/account quarter-credit usage before/after. No broad retries, active probing loops or quota increases. Do not log any exact private coordinates, JWTs, signing secrets or raw protected provider responses.
5. **Fix the proven defect only.** If wrong artifact/flags, use the existing explicit map-enabled staging build path and prepare a new reviewed artifact from then-current main; verify the exact map flags in that output and any version-code conflict through Play. If runtime tile or rendering code fails, write a focused regression reproducing the failure and implement the smallest reliable fix. If the only issue is guest-paid-tile policy, report that product/budget decision rather than weakening authenticated rate controls on your own.

## Expected UI and privacy

- Honor MAPUI03: if a preview isn't actually rendered, compact independent city text + right-side icon-only Maps action, without a loose map-specific credit footer. When the full 144dp map actually draws, whole map remains tappable and proper Geoapify/OSM credits are shown near it.
- City area is a *general* location, never a fake meeting pin. Retain exact visibility and membership/manager permissions. When location text is manual/unverified, do not invent geo-coordinates.
- Preserve live tile gateway budgets/caching, cache permissions, abort/revoke guarantees, separated public/protected tile bytes, fresh canonical Maps-tap reauthorization. No private or service-role keys in the mobile binary.
- No new paid static-map fallback, default-on public/guest quota change, or external map SDK without a separate founder decision.

## Validation

- Real authenticated Android staging test with current-source release-mode map-enabled build where feasible, clearly distinguished from the **synthetic** offline fixture.
- One verified preview of `mappa test` (Trento) renders actual tiles in the app with a visible area symbol, no precise false meeting point; the whole canvas opens Google Maps after canonical authorization.
- Negative controls: disabled transport/detail flags, guest, budget/rate failure, offline, malformed image, denied exact location, background/foreground, sign-out/relogin; these display compact fallback without phantom map success or private leakage.
- Run `npm run check:mobile`, focused Flutter tile/preview tests, `node --test scripts/lib/map-provider.test.mjs`, and native integration tests as appropriate. Record tests actually run and separate builds from installs/releases.
- Verify current staging migration parity and outstanding schema dependency before recommending an upload. The earlier 96-migration count is a dated observation, not an invariant.

## External context and stop points

Required for *physical* acceptance: USB access to `48091FDAS0041A` and user-approved staging login, plus installed-package/Play Closed-testing evidence. If missing, report which portion was possible and the precise step the founder must perform. Play Console actions may require the owner's browser; don't claim you can see its distribution without access.

**Do not** perform an unapproved production/staging migration, reset data, uninstall or clear the phone app, replace signing material, upload/roll out a Play release, change paid quotas, deploy Edge settings, create a paid service, or reveal private logs. Prepare a verified, signed candidate and clear release checklist first. Stop and ask before a consequential deployment, budget/privacy decision, or irreversible change.

## Completion report

Return: (1) exact root cause and proof, (2) installed artifact and compiled flags or explicitly unresolved, (3) changed files/PR, (4) commands and pass/fail results, (5) proof of real tiles vs synthetic render, (6) privacy/quota/cost observations, (7) any tested new signed candidate with precise SHA/version and reason not yet installed, and (8) remaining Play/physical QA steps. Do not report the live map as fixed until a genuine authenticated client has rendered it.

## Required GitHub merge handoff

Start **after MAPUI03 is merged**, from the then-current `origin/main`. If diagnosis identifies a confirmed code/build-tool defect, implement the smallest verified fix in an isolated branch, run focused tests and required CI, **open a PR and merge it into `main` automatically as the final code step**, then sync and clean up the task branch/worktree. Do not leave a green, mergeable fix PR open solely because Play distribution or physical-phone acceptance happens later. If the only cause is an outdated or incorrectly built installed artifact, do not invent a code change to manufacture a PR: document the verified candidate and precise deployment blocker. If a consequential approval, safety issue, or unresolved failure remains, stop and report rather than merging a speculative fix. A code merge is **not** authorization to install, upload or publish an app, change provider limits, or modify hosted staging.
