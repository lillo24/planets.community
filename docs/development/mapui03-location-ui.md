# MAPUI03: compact location UI (provenance decision pending)

Based on `origin/main` `8a2c32592e8d22df61d27c4446ba9fa339d3e35c`.
This is a partial implementation, not acceptance of the complete archived plan.

## Implemented safely

- The text fallback uses a trailing localized, icon-only Maps button with a
  48dp target. Disabled, loading and failed imagery leave no empty map canvas,
  loading prose or optional-image error prose.
- Text-only navigation re-reads canonical authorization and searches the public
  city/country. It never passes the selected provider coordinates or formatted
  address. City-only Projects without a selected place still have no destination.
- The decoded compositor's image builder owns the text, map action and map
  attribution together. Static decoding follows the same composition. There is
  no asynchronous displayed-state callback to race revocation or parent builds.
  The rendered map retains the existing full-canvas action, precision semantics
  and fresh canonical authorization.
- Independently confirmed manual text has no provider credit. Editor provider
  results retain their existing attribution. Tile scopes, leases, aborts,
  protected buffers, quotas and compile-time defaults are unchanged.

Tests encoding the old pending-text/button/error behavior were updated for the
requested compact fallback. Existing authorization, disposal and cache assertions
remain in place. The new visual matrix uses real Flutter widgets/fonts, EN/IT,
light/dark, 320dp and normal/2x text. Tile images in these tests are synthetic.

Reviewed captures: [manual city](evidence/mapui03/en-light-1.0x-manual.png),
[provider text at 2x](evidence/mapui03/it-dark-2.0x-geoapify.png), and
[decoded synthetic canvas](evidence/mapui03/it-synthetic-rendered.png). The last
capture uses the existing tile-test viewport (800dp); it is not a live Geoapify
map. The provider capture deliberately exposes the unresolved footer treatment.

Focused validation passed: 93 compact/preview/tile widget tests, plus all 31
`node --test scripts/lib/map-provider.test.mjs` tests. Captures were produced with
`flutter test test/features/locations/compact_location_ui_test.dart
test/features/locations/location_preview_widget_test.dart
test/features/locations/location_tiles_widget_test.dart
--dart-define=UI_POLISH_CAPTURE_DIR=<absolute-evidence-directory>`.
The complete mobile check and hosted CI results are reported in the PR.

## Concrete unresolved source constraint

Read-only staging inspection on 2026-10-15 confirmed that Proposal
`ca208af9-bacd-4ae7-a107-dd79b9624a9e` (`mappa test`) has `locality=Trento`,
`country_code=IT`, a selected public place and canonical text source `geoapify`.
No content was changed. No private meeting projection or authentication secret
was queried.

`20261011180000_location_text_provenance.sql` fingerprints public country,
locality, administrative area and label together. A selected public place makes
that public text provider-derived. Clearing geometry does not confer manual
authorship, and unclassified historical rows remain unknown. There is no separate
independently authored city field or trustworthy universal legacy backfill.

The [Geoapify geocoding FAQ](https://www.geoapify.com/geocoding-api/) requests a
link near geocoding information and retained data-source credit when reusing
stored results. [Its terms](https://www.geoapify.com/terms-and-conditions/) also
require free-plan Geoapify and OpenStreetMap attribution. Shortening the saved
result to `Trento` does not establish a different source.

The partial implementation therefore retains the existing credit for provider
or unknown text. This does **not** satisfy the plan's strict credit-free,
independently sourced fallback for those records. Merge is held for the plan's
explicit decision gate. The concrete alternatives sent to the owner are:

1. Accept a small linked Geoapify/OSM credit beside provider/unknown city text,
   retaining no credit for independently authored manual text.
2. Preserve the strict credit-free requirement and approve a separate independent
   city-source/schema plan. No record rewrite or provenance backfill is implied.

## MAPFIX03 handoff and release boundary

MAPFIX03 starts after MAPUI03 merges. Initial read-only ADB inventory on this run
found no attached device; physical phone `48091FDAS0041A`, installed package,
signer, installer, compiled gates and Play assignment remain unverified. Ordinary
staging builds omit both opt-in map flags; the existing explicit
`tool/build_map_live_staging.dart` provides them. This source fact does not prove
the installed artifact's root cause or authenticated live rendering.

No hosted SQL/Edge configuration was deployed, no provider tile traffic was
generated, no Android candidate was built or installed, and nothing was uploaded
to Play. After the UI gate is resolved and merged, inspect the exact installed
artifact, check current staging parity and Play version history, prepare the
explicit map-enabled signed candidate from current main, and verify one bounded
authenticated `mappa test` preview before requesting a Play rollout.
