# MAP05 validation record

Implementation base: inspected `main` at
`723582be49fcbd78c19bd5316da661c297f7eeba` (MAP04 #182), on isolated branch
`codex/map05-interactive-discovery`. Before handoff, the branch was rebased onto
`a8f2f9c8f034bd7594bf3d29031b0a8835f3db35` after the independent #184 hero-star
polish merged. The only implementation-tree change from the fully validated
MAP05 head was that one-line mobile polish; provider, SQL, Web and Android
fixture files were unchanged. The full mobile gate was repeated on integration.
The PR records the immutable tested head,
hosted check run and merge result. No hosted migration or provider activation is
part of this record. See the [runbook](map05-interactive-discovery.md) for the
contract, configuration and account-owner activation checklist.

## Delivered behavior

Projects, Tavoli and Scambio/Dona each open one shared map route with their
existing applied filters. Map-only All combines the families without changing
List filters. Radius/reference/camera/family preferences survive List/Map and
detail navigation within the account session. Pan/zoom does not run a geographic
query; Search this area and Load more are explicit. Loaded-only clusters and
cards open existing internal detail routes. Trento is a starting reference,
with no GPS request. Disabled provider configuration leaves a labelled blank
basemap with public results, camera, radius, cards and List access available.

`flutter_map` 8.3.2 (BSD-3-Clause) and `latlong2` 0.9.1 (Apache-2.0) are pinned;
installed SDK constraints, APIs and license files were checked. The renderer
uses an app-owned bounded tile queue, never a public URL template or embedded
key. Provider/renderer interfaces were reviewed for allowlisting, finite work,
transport bounds and disposal. This is a scoped code/dependency review, not a
claim of a separate penetration test or exhaustive vulnerability audit.

The independent center gateway requires a real Supabase actor. Guests can use
public MAP04 discovery but cannot perform paid center/tile operations. The
quarter-credit ledger atomically covers editor search 4 units, map center 4,
static image 16 and tile 1; one unit is 0.25 credit. Cache hits/resolve consume
request-rate capacity and no upstream credits. All live flags default false,
the master is false, the account ceiling is zero and tile retention is zero.

## Local automated checks

| Check                                               | Result                                                                                                                                       |
| --------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| `node --test scripts/lib/map-provider.test.mjs`     | 31 passed; injected provider/Auth/RPC only                                                                                                   |
| Focused geographic unit/controller suite            | 39 passed: 9 MAP05 plus 30 existing MAP04                                                                                                    |
| MAP05 widget suite                                  | 20 passed                                                                                                                                    |
| Existing skills-filter plus MAP05 widget regression | 28 passed; existing assertions unchanged                                                                                                     |
| `npm run check:mobile`                              | Passed localization generation, formatting, analysis (no issues), 1,876 tests; 2 existing opt-in tests skipped                               |
| `npm run check:web` with `VITEST_MAX_WORKERS=2`     | Passed: 92 tooling tests; 285 Web tests passed, 1 existing opt-in smoke skipped; lint, types and production build passed                     |
| `npm run check:db` on owned disposable stack        | Passed complete clean replay: lint/advisors, 3,908 SQL assertions in 124 files, all named authenticated/regression verifiers and demo proofs |
| New SQL suite within full replay                    | 62 MAP05 pgTAP assertions passed                                                                                                             |
| Existing location SQL suites within full replay     | 116 MAP01–04 assertions passed                                                                                                               |
| Location authenticated REST/concurrency verifier    | 177 checks passed: existing 136 plus 41 MAP05; no Geoapify traffic                                                                           |
| Generated database types                            | `db:types:check` passed; three service-only RPC signatures added                                                                             |
| Formatting/diff                                     | Dart standard and integration/driver formatting, scoped Prettier and git diff checks passed                                                  |

The two existing Flutter skips are PI02/PI04 opt-in backend/native rehearsals;
the existing Web skip is PI03 local smoke. No MAP05 test is skipped. The Site
application has no changed ownership/dependency area and its local gate was not
run. The unchanged path classifier selects Mobile, Web and Database for this
diff; the final PR Checks tab is the authoritative hosted execution record.

Hosted CI could not start: [run 37917977783](https://github.com/lillo24/planets.community/actions/runs/37917977783)
failed before any workflow step. GitHub's annotation reports recent account
payment failures or a spending limit requiring attention. All downstream jobs
were skipped; no hosted test is claimed as passed. The PR records the final-head
rerun result. Account-owner billing resolution and a green final-head Validation
run are required before merge; no workflow or status gate was bypassed.

MAP05 tests cover all origins/families and family-scoped filters, explicit
radius/bounds actions, identical-city clustering, public precise resources,
duplicate-page identities, stable anchors/card selection, loaded counts,
additional-page retry and expired-cursor refresh. Widget probes include route
departure, foreground changes, identity/ABA, stale search and selection,
disabled guests, EN/IT at 320px and 2x text, 220px keyboard inset, safe-area
attribution, link semantics and keyboard interaction.

The fake Edge handler tests prove disabled/unconfigured zero IO, operation and
XYZ/style allowlists, guest/spoofed-actor rejection, independent flags, reserve
before upstream, Italy/bias/sanitized projection, cache and pending handling,
kill during fetch, finite PNG/stream/time bounds, failure charging and status-only
metrics. Real local JWT/Auth and service RPC bindings are exercised by the REST
verifier, including twelve concurrent reservations for the last quarter-credit
(one winner), ten-way pending dedup, actor-bound center resolve and expiry.
The Deno entrypoint itself was not live-served; its pure handler and real local
Auth/RPC boundary were exercised without external provider calls.

MAP04's existing privacy verifier ran unchanged: recursive payload scans,
anonymous/current/former-member comparison, repeated tiny probes, and changes
to private exact points/visibility leave public result geometry unchanged.
No MAP01–04 applied migration, public discovery RPC semantics, public DTO or
ordinary List RPC was rewritten. The two older SQL fixture files only enable
the new master/ceiling inside their rolled-back synthetic transactions.

## Android fixture evidence

Passed on task-owned PLANETS_MAP05_QA_API35, API 35 x86_64 (emulator-5590). The final journey completed in 29 seconds with one journey assertion group plus framework teardown, and five screenshots. No provider, Maps app, hosted backend or physical device was used.

The journey uses actual Projects/Tavoli/Resource List and detail widgets with
synthetic public DTOs, fake geocoder and neutral decodable PNG tiles. It exercises
Projects cluster/card/detail, All, radius, pan → Search this area, explicit
Bolzano center selection, List restoration, Italian Tavolo/card/detail, and
Dona/Scambia public precise cards/details. `HttpOverrides` rejects any attempted
network access and the journey asserts zero attempts.

Screenshots from the owned Android fixture:

- [Projects identical-locality chooser](assets/map05/map05-project-cluster.png)
- [All viewport search](assets/map05/map05-all-viewport.png)
- [Italian Tavolo approximate card](assets/map05/map05-tavolo-it-card.png)
- [Donate public-address card](assets/map05/map05-resource-4-card.png)
- [Exchange public-venue card](assets/map05/map05-resource-5-card.png)

Neutral fixture tiles are labelled synthetic; they contain no invented streets.
Native evidence proves the fixture flow and Flutter rendering on an emulator.
Real map quality, live Geoapify, external Google Maps dispatch, iOS,
physical-device/screen-reader checks and owner terms/privacy approval remain
unverified external activation tasks.

## Isolation, failed attempts and cleanup

Database rehearsal used only task-owned `planets-map05-qa`, API 55731, database
55732, Mailpit 55734 and distinct auxiliary ports, with explicit disposable-QA
acknowledgement. The temporary config is excluded from the commit. The retained
`planets-community` 54321/54322 stack, other emulator `PLANETS_MODINT01_API35`,
phone `48091FDAS0041A`, staging and production were untouched.

Earlier development attempts exposed and fixed map-route visibility lookup,
dispose/ref access, lazy map-controller detachment, narrow keyboard chooser
overflow, missing link semantics, fixture JSON encoding and fixture token access.
The first full mobile run caught the new List indicator conflicting with an
existing skills-filter Chip assertion; implementation was corrected and the
unchanged test passed. A first native run had an incorrect expected fixture
label, corrected before the successful journey. These attempts are not counted
as passing gates.

The first full database attempt reached green SQL/location checks but timed out
in the existing PI01 invitation verifier during concurrent host-heavy work.
The complete clean replay was rerun without the emulator. The first Web attempt
stalled with default Vitest worker concurrency on the busy host; only that
owned Vitest process was stopped, then the full gate passed with two workers.
No assertions, production timeouts or CI coverage were weakened.

The owned Supabase project was stopped with its exact project ID and no backup; no matching containers or volumes remain. Canonical supabase/config.toml was restored with zero diff. The owned emulator was stopped only after verifying its AVD name, and that exact AVD was deleted after validating its absolute path. Evidence screenshots are retained in this repository.
