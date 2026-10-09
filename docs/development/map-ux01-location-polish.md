# MAP-UX01 location presentation

Preparation base: `a30e3eae434398e52465de21205ea101e60ba293` (MAP05 already merged).
Updated onto `ae9b477` before final combined validation after HERO05 merged.
This change owns mobile presentation and Workshop demo-source copy only.

## Before and after

| Surface                   | Before                                                                     | After                                                                                                                                |
| ------------------------- | -------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| Project and Tavolo cards  | Preview panel, status copy, credits and separate Maps gesture              | Compact pin/text metadata; the whole card opens internal detail                                                                      |
| Scambio/Dona cards        | Separate preview block below metadata                                      | Location joins the metadata Wrap, preferring structured public locality and retaining the canonical fallback                         |
| Project/Tavolo detail     | Public location text repeated above preview; multiple availability phrases | One location unit, one explicit Maps button for a current safe destination; meeting instructions retain their original authorization |
| Resource detail           | Preview block and availability copy                                        | One canonical label/preview/action unit; legacy branch keeps its one label and credits                                               |
| Disabled static rendering | Text-only status and availability boilerplate                              | No reserved map space; readable label, honest locality approximation and safe action                                                 |
| List/Map switch           | Small, asymmetric separate controls                                        | One shared full-width equal-half selector, selected state and at least 48dp height                                                   |
| Credits                   | Default button typography                                                  | Subdued theme-aware labelSmall links, compact wrapping and 48dp accessible targets                                                   |

The unused `ProposalLocation` compatibility widget remains text-only, with its
single credit group below the content. No detail mounts it alongside the shared
participation section. Editors keep credits after clear/manual entry because
ordinary labels can retain provider provenance. List feeds and Resource matches
credit once at the screen footer, rather than repeating credits on every card.
Feed credits scroll with the content and have clearance above Create, preserving
the tutorial's usable viewport at 320px/2x. Resource matches retain a fixed footer.
The Project title/status header wraps when it cannot fit, including Italian
status text at 320px/2x, without dropping metadata.
Map and its modal chooser each keep their own accessible credit group.

## Safety and navigation

MAP03 models, RPCs, `_safe`, auth/membership/role invalidation, cancellation,
revision matching, fresh reauthorization on tap and the 15-second lease remain.
Protected bytes are still overwritten and decoded RawImage ownership is still
local, outside the global ImageCache. During canonical reauthorization the
protected label, bitmap and Maps action disappear. Enabled optional rendering
failure retains the authorized place with one fallback; denial erases it.
Actual PNGs retain a 144dp detail height. No placeholder map is fabricated.

Both List and Map use `MapViewButton`. List entry keeps prepare/unfocus/push;
Map return keeps pop or the origin's existing List route fallback. Per-origin
filters, scroll, family, reference, radius and camera ownership are unchanged.
No new route branch is introduced.

## Demo data and deferred work

New Workshop source creation sends `locality, zona indicativa`. The world is
still synthetic; deterministic receipt identities, private sentinel instructions
and fixture safety remain unchanged. **This source edit does not update existing
demo rows.** No retained local or shared/hosted demo seed/reset/update was executed.
The existing CI classifier may replay its own disposable stack because the
shared demo helper changed. Any future refresh
must be explicitly scoped to task-owned disposable fixtures, or separately
authorized for a shared environment; do not reset the retained demo world.

Provider keys/flags, paid traffic, Edge Functions, canonical RPCs, migrations,
cache TTLs, credit accounting and hosted data are unchanged. MAP-CACHE remains
the separate follow-up for shared tiles/static composition and cache optimization.

## Reproduction

From the repository root, with the pinned Flutter SDK on PATH:

```text
cd apps/mobile
flutter test test/features/locations test/features/geographic_discovery test/features/participation/presentation/participation_flow_test.dart
cd ../..
node --test scripts/lib/demo-workshop.test.mjs
npm run check:mobile
```

Tests use fakes and no provider keys. EN/IT detail and control layouts cover
320px at 2x text; credits cover light/dark themes, semantic links and keyboard
activation. Maps tests cover all origins, selected non-navigation, direct-route
fallback, filters and preferences. This is automated component evidence, not a
physical-device or live-provider review. The comparison above describes the
before/after; no device screenshot or phone change is claimed.
