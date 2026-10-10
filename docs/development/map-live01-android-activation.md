# MAP-LIVE01: explicit staging Android activation

This task enables existing location features for bounded development/staging
tests. It does not authorize production activation, Play upload/publication,
billing changes, database reset/seed, signing-key replacement or Pixel install.

## Client ownership and build

`item_location_gateway.dart` selects a scoped `ServerEditorPlaceGatewayFactory`
only when `LOCATION_EDITOR_SEARCH_ENABLED=true` **and** `APP_ENV=staging`.
Its availability checks the ready application identity against Supabase's user;
each request sends the current user JWT and rechecks readiness after completion.
Existing MAP02 save-before-search, receipt/revision binding, canonical reread,
independent public locality, exact visibility and lifecycle invalidation remain
the mutation boundary. Manual mode remains available. No direct Geoapify call or
provider key is compiled into the application.

From `apps/mobile`, using the pinned Flutter SDK and existing ignored files:

```powershell
dart run tool/build_map_live_staging.dart apk UNUSED_PLAY_VERSION_CODE
dart run tool/build_map_live_staging.dart appbundle UNUSED_PLAY_VERSION_CODE
```

Replace the final argument with a positive unused Play version code after
inspecting the package's current upload history. The task observed codes 1 and 2
on 2026-10-09, with 2 active in Closed testing - Alpha. This is a time-sensitive
observation, not a reserved future code. The script keeps staging.json restricted
to APP_ENV, SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, SENTRY_DSN and ENABLE_DEMO_TOOLS.
Staging requires a managed HTTPS origin, client-safe publishable key, demos off
and the existing permanent upload keystore through android/key.properties.

The explicit additional defines are:

| Define | QA value | Ordinary default |
| --- | --- | --- |
| LOCATION_MAP_TILES_ENABLED | true | false |
| LOCATION_MAP_CENTERS_ENABLED | true | false |
| LOCATION_DETAIL_TILES_ENABLED | true | false |
| LOCATION_MAP_CACHE_SECONDS | 60 | 0 |
| LOCATION_EDITOR_SEARCH_ENABLED | true | false; production always inert |

Detail tiles exclude static rendering even on failure/guests. CACHE01's public
compressed-byte reuse, protected transient scopes, authorization leases and
revocation remain unchanged. There is no disk cache, prefetch or client quota
bypass. See [CACHE01](map-cache01-shared-tiles.md).

An older installed binary does not gain these compiled flags when main or the
backend changes. Revert client activation by rebuilding without the flags using
the normal staging build. Never embed Geoapify/service-role keys, JWTs or signing
passwords in defines, source, screenshots or evidence.

## Verified staging target and narrow activation

The authenticated management connector confirmed `planets-staging`, ref
`cllpvruvrrvxczjitlqd`, ACTIVE_HEALTHY on 2026-10-09. Initially provider enabled,
tiles_enabled, center_enabled and cache_license_approved were true, tile TTL 60;
daily and actor limits were 8,000 quarter-credit units (2,000 credits).
Actor/global minute request limits were 30/120. The search switch was false,
with global_daily=1000, actor_daily=80 and actor_minute=10. Static preview remained
disabled with zero budgets. The CLI confirmed secret **names** were present;
values were neither read nor printed. Runtime behavior still requires a real
authenticated probe. All three deployed functions were version 4; map-provider
and location-search retained verify_jwt=true.

After verifying this exact target, runtime key readiness and quota, the only
authorized configuration write is:

```sql
update private.location_search_config set enabled = true
where singleton and not enabled;
select enabled, global_daily, actor_daily, actor_minute
from private.location_search_config where singleton;
```

Rollback sets that one enabled field false. Do not raise global limits, change
JWT verification, expose private SQL, disable shared staging to simulate failure,
or enable static previews. Diagnose 401/403/disabled/unconfigured/malformed/quota
responses before more provider requests. Use safe injected failures for kill
switch, late response and revocation tests.

## Attribution

Projects, Tavoli and Resources show no provider footer for genuinely empty,
loading or failed lists with no retained content. Resource matches follow the
same rule. Nonempty lists retain linked Geoapify/OSM credits: sanitized public
DTOs do not reliably expose provenance, and ordinary labels may remain derived
after clearing a pin. No cosmetic SQL change attempts to infer provenance.
Actual maps and selected provider text retain credits, 48dp links, keyboard and
screen-reader semantics. Cards remain compact and details retain one Maps action.

## Native and live evidence procedure

Use the task-owned `PLANETS_MAP_LIVE01_API35` / emulator-5570, separate from the
retained emulator-5560. Ask the owner to sign in normally to an existing staging
account; never mint a session, retrieve OTPs from auth tables or invent a user.
Record no login screenshots or credentials. Test Explore → Map at public Trento,
one bounded IT/EN center lookup, and return to List. Create clearly labelled
test-only content through the normal editor, select the independent public
locality, save/publish and reopen the detail map. Test private exact access only
with explicitly authorized owner/member/unrelated sessions. No existing user
content should be edited for this proof.

Capture account usage and the private account/day ledger before and after.
Distinguish actual upstream units, Edge cache hits and client reuse; a theoretical
tile count is not observed billing. Four tile units equal one credit, while
editor/center geocoding reserves four units. Account UI statistics may lag.

The Pixel was observed with community.planets.app 0.1.0, versionCode 2,
targetSdk 36. A later read-only certificate pull could not run because the phone
disconnected. No Pixel installation, data clearing or account/session change
occurred. Obtain its actual certificate before proposing any authorized update;
Play's distribution certificate may differ from the permanent upload key.

## Licensing and completion boundary

[Geoapify pricing](https://www.geoapify.com/pricing/) lists a Free allowance of
3,000 credits/day and commercial production use subject to limits and attribution.
[Binding terms](https://www.geoapify.com/terms-and-conditions/), version 5 dated
2024-02-02, still describe production limitations and contacting Geoapify for
details. These are not treated as resolved public-production approval. Bounded
development testing stays inside the existing 2,000-credit application cap.
[The tiles documentation](https://www.geoapify.com/map-tiles/) permits caching
OSM-based tiles; this task keeps the existing 60-second approved setting.

Source checks, real authenticated provider responses, actual native rendering,
test-item persistence, account usage and signed artifact verification are separate
evidence. Any missing native/login/provider/account step remains incomplete.
