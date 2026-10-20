# PLANETS MAP-LIVE02 — Live Map search acceptance

Prepared: 20 October 2026.
Repository inspected: `lillo24/planets.community`, `main` at `32f37791b11f759adfe4b61c2cdd1b600fdf84f2`.

## Objective and sequence

Make the existing mobile Map search work end to end with the real staging backend and real Geoapify imagery. Diagnose the first failing layer and fix demonstrated defects; do not rebuild MAP04/MAP05 or produce another synthetic-only report presented as live acceptance.

This is the first of two sequential implementation plans. After its code/contract changes are merged, use `PLANETS_MAP-COST01_trento_cache_and_budget_fallback_2026-10-20.md` in this directory for shared Trento caching and reduced-detail fallback. Keep the two changes in separate PRs. An unresolved authorization or API-contract defect blocks dependent work; missing external login/device access alone may leave live acceptance pending while independently testable cost work proceeds against the established contract.

Start from then-current `main`, including any later UI/tutorial PRs. Read root/nested `AGENTS.md`, `docs/development/codex-tooling.md`, and `implementation_plan_sections_suggestions.md`. Follow the repository's isolated-worktree, scoped-checks, PR, automatic-merge and cleanup workflow. Direct-main authorization applies to publishing these plan documents, not implementation code.

## External context and permissions

Live acceptance requires resources outside Git: access to the existing `planets-staging` Supabase project, the ignored client staging configuration, and an ordinary signed-in staging account controlled by the owner. Their availability on the desktop is not guaranteed. Signed distribution additionally requires the original upload-signing configuration and verified Play version history; neither is required merely to run a debug build on an owned emulator.

Use available desktop/computer-control, browser, Android emulator, ADB and screenshot tools. Do the supported steps rather than giving the owner a generic checklist. Discover available tools and existing trusted local setup before declaring something unavailable.

- The physical phone is `48091FDAS0041A`. Use that exact serial for read-only phone inspections; use an explicitly identified task-owned serial for emulator commands. Do not clear, uninstall, overwrite or change accounts on the phone without separate approval.
- Use the existing authenticated session or the normal sign-in flow. Leave password/OTP entry to the owner when necessary. Never recover OTPs/JWTs from storage/auth tables, manufacture a production session, or put credentials in screenshots or logs.
- Existing bounded staging map requests through the normal application are in scope. Keep the QA session within the remaining server limits and at most 100 additional Geoapify credits; prefer far less. Stop live traffic on unexpected failures rather than repeatedly probing. Test exhaustion and failure through local fixtures, not by consuming the real allowance.
- Code, local disposable-database work, owned-emulator testing and signed candidate preparation using existing trusted inputs are in scope. This does not authorize Play upload/rollout, production activation, paid services, higher quotas, signing-key replacement, shared database reset/seed, or unrelated hosted changes.
- Hosted function/migration/configuration changes must follow separately available owner authorization. When none exists, prepare and validate the exact scoped deployment and rollback instructions, and mark hosted activation pending. Do not silently deploy changes merely to obtain a passing screenshot.

When a required external resource is inaccessible, stop the affected live/release step and identify the exact missing resource. Continue useful independent local work. Do not invent access or mark the blocked acceptance criterion complete.

No Google Doc, private PDF, or off-repository design export is required for this task; the relevant product decision is included here.

## Current evidence, not assumptions

The inspected source already contains:

- MAP04 public geographic search, `search_public_geography_v1`, radius/bounds queries, family filters and keyset pagination.
- MAP05 List/Map navigation, public pins/clusters/cards, city selection, radius changes and explicit Search this area.
- Authenticated server-side tile and city-search gateways, shared credit reservations, and bounded public byte reuse.
- `apps/mobile/tool/build_map_live_staging.dart`, which supplies the map transport, city-search, detail-tile, cache and staging editor-search defines. Ordinary builds do not acquire those flags simply because source code was merged.
- `docs/development/mapfix03-live-detail-diagnosis.md`, dated 15 October, which leaves real authenticated rendering unverified. The installed map-disabled artifact was a hypothesis, not a proven current-phone diagnosis.

A read-only check in the preceding owner discussion on 20 October observed staging project `cllpvruvrrvxczjitlqd` healthy, 96 deployed migrations matching the inspected main, active `map-provider` v4 and `location-search` v5, provider/tile/center/search switches enabled, a 60-second tile cache, and global/actor limits of 8,000 quarter-credit units. One public item was returned within 5 km of the existing central Trento reference. These are dated observations: recheck the target, effective functions, flags and eligibility rather than treating the counts or deployment state as permanent.

Source presence, database flags, an active Edge Function, a successful SQL call, an authenticated PNG response, and actual painted pixels are separate pieces of evidence. Privileged SQL success does not establish the app's anon/authenticated transport permissions.

### Areas to inspect

- `apps/mobile/lib/features/geographic_discovery/` and its tests.
- `apps/mobile/lib/features/locations/`, especially gateway and detail ownership.
- `apps/mobile/tool/build_map_live_staging.dart` and the distribution builders it complements.
- `supabase/functions/map-provider/` and `supabase/functions/location-search/`.
- The effective location/geographic-search migrations, not only their initial definitions.
- `docs/development/map04-geographic-discovery.md`, `map05-interactive-discovery.md`, `map-live01-android-activation.md`, `map-cache01-shared-tiles.md`, `mapfix03-live-detail-diagnosis.md`, and `play-closed-test.md`.
- Existing `map_discovery_smoke_test.dart`, `map_detail_smoke_test.dart`, fixture/driver tooling and `scripts/lib/map-provider.test.mjs`.

## Implementation work

### 1. Establish the actual execution target

Inspect the current desktop checkout, configured backend and existing build path. For a connected phone, read package version, installer and signer for `community.planets.app`; do not infer its flags from current main or an old report. Record non-secret source/build provenance.

Verify the real client activation and auth readiness. Keep production/offline defaults intact. Use or improve the explicit staging build path and its verification so that a future ordinary build cannot be mislabeled as map-enabled. Record the defines in a non-secret manifest or equivalent reproducible evidence rather than relying on a remembered shell command.

The existing explicit staging path includes:

```text
LOCATION_MAP_TILES_ENABLED=true
LOCATION_MAP_CENTERS_ENABLED=true
LOCATION_DETAIL_TILES_ENABLED=true
LOCATION_MAP_CACHE_SECONDS=60
LOCATION_EDITOR_SEARCH_ENABLED=true
```

Recheck their current owners and the staging-only editor constraint. The cost successor may change the public-basemap caching policy; do not implement that redesign here.

### 2. Diagnose before patching

Trace normal app requests through client gate/session, public search RPC, map-provider Edge entrypoint, verified actor, reservations/cache, upstream response, binary decoding and painting. Use status/count-only evidence, never raw tokens, private coordinates or whole request dumps.

The inspected tile adapter uses `api.geoapify.com/v1/tile/...`; current official examples use `maps.geoapify.com/v1/tile/...`. That difference is a verification lead, not proof of failure. Verify actual status/redirect behavior through the controlled adapter and current documentation; change the fixed endpoint only when justified. Keep HTTPS host/path allowlisting, key secrecy, size/deadline limits and redirect policy. Do not enable arbitrary URLs or blindly weaken JWT verification to remove a 401.

Classify disabled/unconfigured, guest/auth failure, rate limit, budget exhaustion, pending cache reservation, upstream failure, malformed image and renderer failure separately. Add narrow regression tests for each defect actually changed. Avoid speculative MIME/renderer rewrites that previous evidence already excluded unless new evidence contradicts it.

### 3. Prove the user journey

Using the real app and a normal signed-in staging session:

1. Explore/List → Map opens real Trento imagery without requesting GPS.
2. Eligible public results display; pins/clusters open their existing cards and details.
3. City autocomplete produces real suggestions, explicit selection moves the search reference, and results are queried for the selected area.
4. Panning/zooming followed by Search this area updates the database query; changing radius and activity family works.
5. Return to List preserves the appropriate filters/navigation state; leaving/backgrounding and returning does not restore stale protected content.

Test Projects, Tavoli and Resources with existing eligible content or clearly identified task-owned fixtures. A lack of hosted records is not a renderer bug. Do not silently geocode manual records, move existing proposals, invent default templates as active activities, or expose private meeting points to populate the map. Do not promise an exact Povo event location from a proposal whose public coordinate is only the Trento locality reference.

Exercise guest behavior explicitly: public discovery is available, but paid-provider imagery/autocomplete remain authenticated. Do not broaden guest access or introduce GPS in this task.

### 4. Evidence and build handoff

Use computer control to capture and inspect screenshots of the actual mobile journey: Trento map/results, city suggestions and the changed search area, and a selected result/detail. Keep captures few, relevant and free of unrelated personal content or account UI. Preserve map attribution. Label each image as real staging imagery, cached real imagery, or synthetic fixture imagery; a browser tile screenshot is not mobile rendering proof.

Measure aggregate reservations before/after the bounded session and distinguish Edge cache hits, client reuse and upstream requests. Do not confuse a 200 response with successful image decoding/painting. Report real-device and iOS checks separately from Android emulator checks.

For a signed candidate, use the existing original signing inputs and an actually unused Play version code; do not reserve or guess a number from historical reports. An upload-key APK may not replace a Play-signed installation. Record source SHA, exact flags, backend, package/version, artifact hash and signing fingerprint; keep binaries outside Git unless repository policy says otherwise. Missing distribution inputs should not block emulator acceptance.

## Validation and completion

Run the repository's affected Flutter and map-provider checks, plus SQL/security/REST checks when those layers change. Use an explicitly disposable local stack for reset/replay or failure injection. Reuse existing integration tooling; do not add a second test architecture. Check current Supabase documentation and installed CLI help rather than copying obsolete log/query commands.

Acceptance requires actual public-search transport, real authenticated city/tile responses, painted mobile maps, correct navigation, preserved privacy/quotas and inspected visual evidence. Every unperformed part remains explicitly pending. Screenshots and unit tests complement, rather than replace, each other.

Update the closest runbooks and add a concise MAP-LIVE02 outcome recording the diagnosis, narrow fix, exact commands/results, source/build identity, visual evidence, observed credit delta and any missing external action. Push the implementation branch, open a PR, follow the repository's merge/cleanup rules, then give the next-plan handoff. Do not manufacture an app-code patch if the problem is solely the build configuration.

Public references checked during planning; recheck relevant details at execution:

- https://apidocs.geoapify.com/docs/maps/
- https://www.geoapify.com/map-tiles/
- https://www.geoapify.com/pricing/
- https://www.geoapify.com/terms-and-conditions/
- https://supabase.com/changelog

The general terms retain production-specific conditions. This staging task is not a new production-licensing approval.
