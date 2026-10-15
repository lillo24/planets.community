# PLANETS MAPUI03 — Compact text-only location UI and map-state attribution

## Goal

Implement the requested distinction between a **genuinely rendered map** and **plain public location text**. In Proposal details, a missing/disabled/failed/pending map must not leave an awkward “Powered by Geoapify” footer beneath an otherwise simple `Trento` label. Replace the standalone text “Open in Maps” fallback with a trailing accessible icon button. When map imagery really renders, retain the fully tappable map and required near-map attribution. Apply the principle consistently to closely related mobile location surfaces without a broad redesign.

This is **UI work first**. Do not conflate it with fixing the separate reason live map tiles are not rendering; MAPFIX03 handles that next.

## Baseline observed before writing this prompt

Repository: `lillo24/planets.community`; inspect current `origin/main` and `AGENTS.md` again before editing. At prompt preparation, main was `87f3983cbf1f8bd46f117568b32d91e9e0458042`; it may have advanced.

Verified implementation:

- `apps/mobile/lib/features/locations/presentation/location_preview_panel.dart`: detail widget has canonical public/protected read, text display, Google Maps link, optional `ReadOnlyBasemap`, disabled static fallback, and `LocationAttribution`. It currently decides attribution with `place != null || (label.isNotEmpty && textSource != 'manual')`, independent of successful tile rendering. The text fallback is `TextButton.icon` with “Open in Maps”.
- `apps/mobile/lib/features/geographic_discovery/presentation/read_only_basemap.dart`: knows its actual `_ready`/`_failed` and decoded `ui.Image` ownership. Mere tile-provider enablement or non-null coordinates do not prove that a map has appeared.
- `apps/mobile/lib/features/participation/presentation/project_participation_section.dart` uses the detail panel for Proposal and Tavolo locations. Other relevant places to inspect include `proposal_location_editor.dart`, `proposal_widgets.dart`, `public_proposals_screen.dart`, location resource-list/detail widgets, `location_attribution.dart`, and test files under `test/features/locations/`.
- The existing `mappa test` staging Proposal `ca208af9-bacd-4ae7-a107-dd79b9624a9e` has canonical Geoapify locality/coordinates and a **public `Trento` city name**. The historical stored provider-formatted label is longer than the UI should show. A second `Mappa Test 2` item was observed without a selected provider place; do not invent geometry for it.
- `docs/development/mapfix02-project-detail-map.md` and `docs/development/map-cache01-shared-tiles.md` contain earlier map flag, caching, privacy, attribution, and platform acceptance evidence. MAPFIX02 was synthetic Android coverage, not proven real tile rendering on the founder's device.

## Requested UI behavior — acceptance contract

**When map preview has not actually rendered** (feature off, no geometry, unready tiles, network failure, rejected request, decode failure, missing authorization, or fallback):

1. Show a compact row like `📍 Trento` with a small **icon-only** Maps/open-external action aligned to the **right** of the text. The text itself must not say “Open in Maps”. Use existing icon conventions, an accessible localized tooltip/semantics label, and a sufficiently large touch target (about 48dp).
2. The plain-text detail must **not** show an isolated `Powered by Geoapify` / OpenStreetMap footer. No empty map container or false pin, and no technical/geocoder status prose. A genuine map rendering state, not merely `place != null`, must drive the map-specific attribution surface.
3. The text-only display must use **ordinary independent geographic text**, such as the organizer-provided city or a separately sourced common municipality name, not a full formatted Geoapify result pretending to be independent. In this state, do not pass Geoapify-derived coordinates or a provider-specific formatted address into the Google Maps fallback; if allowed by the existing public-location privacy rules, use a city/country search query (e.g. `Trento, IT`) instead. Do not expose an exact private place. Do not silently label provider-derived stored data as `manual` just to suppress credits.
4. If the current persisted data does not let you establish an independent city-text source for all legacy rows, identify the precise cases and minimally safe way to store/derive independent public text. **Do not fabricate provenance or retroactively rewrite organizer content.** This requirement is a product constraint: discuss a material schema/backfill or legal decision before taking that step. Prefer a contained, well-supported solution using existing independently authored public data when possible.

**When map preview really renders**:

5. A successfully painted tile/static image should be visible in the existing 144dp detail canvas, clickable across the full map, retaining its current external-map affordance (top-right if this is already the installed UI's convention; avoid gratuitous rearrangement). Keep accurate approximation/precision semantics, fresh reauthorization on tap, accessible interaction, and meaningful near-map Geoapify/OpenStreetMap attribution. Don't show a second duplicate attribution row.
6. An in-flight tile request, placeholder, decoded-bytes intent, or transient provider enablement is **not** a rendered map. Test transitions from loading -> success, success -> revoke, success -> decode fail, backgrounding, and identity/entitlement changes. Avoid flicker/races from widget callbacks, frame scheduling or scroll updates.
7. When actual Geoapify autocomplete/geocoding suggestions/results are visible in create/edit flows, retain their required provider/data credits **near those results**. Merely editing a short, independently sourced city in a normal text field should not inject provider branding. Keep source/visibility distinctions clear.

## Attribution and compliance boundary

The owner's requested visual behavior is strict: **no conspicuous map-provider footer in a text-only detail fallback**, attribution when map imagery renders, and normal attribution around *actual visible geocoding suggestions*.

But do not claim that shortening a stored Geoapify API result to `Trento` automatically changes the result's source. Contract and copyright are different questions. Official sources reviewed during handoff:

- https://www.geoapify.com/terms-and-conditions/ — Free-plan attribution obligations
- https://www.geoapify.com/geocoding-api/ — Free commercial geocoding FAQ requests a follow-link **near geocoding information**
- https://apidocs.geoapify.com/docs/maps/map-tiles/ — map credits and location of map credits
- https://www.openstreetmap.org/copyright — data-origin attribution and ODbL

**Implementation direction:** make plain text genuinely independent where possible and scope Geoapify credits to actual visible Geoapify services/content. If satisfying the UI requirement for an already provider-derived legacy text row would mean suppressing attribution for data that the terms require credit for, **do not silently assert compliance**. Implement the unambiguous improvements and escalate that specific conflict with concrete low-clutter options (independent city text source or a narrowly located attribution treatment). Avoid a blanket app-wide legal conclusion unsupported by the terms.

## Implementation guidance

- Reuse existing feature-first Flutter structure. The detail panel currently knows `showTiles`, but `ReadOnlyBasemap` knows when it has decoded and painted pixels. Prefer a narrowly scoped, safe displayed-state signal/composition over guessing from configuration, `place`, API success or cached bytes.
- Keep tile-cache ownership, 15-second leases, public/private buffers, aborts and lifecycle revocation unchanged. Preserve source-of-truth privacy checks for Maps navigation.
- Do not enable paid static fallback, make extra map calls to detect success, or reveal provider keys in Flutter. No broad Maps SDK replacement.
- Keep EN/IT localization, light/dark mode, 320dp screens and 2x accessibility text. Avoid standalone dense rows of attribution that break the layout.
- Update doc comments that now incorrectly equate `place != null` with visible map or describe unconditional attribution; add focused regression tests.

## Testing and evidence

Run `npm run check:mobile`, focused existing location widget/tiles tests, and any relevant native synthetic integration harness (`integration_test/map_detail_smoke_test.dart`). Verify:

- text-only area `Trento`: city + right icon, no text button / no provider footer *only when independently sourced*;
- no selected place and manual city: no invented coordinates/pins, safe/no Maps action where not authorized;
- provider suggestion/results in editor: correct credits;
- decoded map: one actual map canvas, one credit treatment, full-map action, no text fallback;
- tile disabled, authenticated rejection, rate/budget, malformed PNG/decode, background/re-entry, protected/private revocation;
- no display/cross-account regressions on Proposal, Tavolo and Resource details.

Render and review real Flutter widget screenshots; distinguish synthetic images from live Geoapify. Record any source-provenance cases that cannot be safely classified without new data.

## Delivery and stop conditions

- One focused UI PR; a second PR only if an independent source/provenance migration proves necessary and is separately approved.
- Do not upload or publish Android, deploy SQL/Edge changes to hosted staging, modify existing Project location records, use paid resources, or change map provider quotas.
- Report completed UI states, screenshots/tests, required outside context, attribution/legal ambiguity if any, and the exact handoff to MAPFIX03.
- Preserve external-device identity `48091FDAS0041A` for future physical tests, but this UI phase must be testable offline.

## Required GitHub merge handoff

Implement MAPUI03 first, based on current `origin/main`, in its own task branch/worktree. After focused tests and all required CI pass, **open a PR and merge the completed UI changes into `main` automatically as the final implementation step**. Then sync `main` and clean up the task branch/worktree. Do not leave a verified, mergeable UI PR unmerged merely because MAPFIX03 live-device testing is a subsequent task. **If the legal attribution/provenance constraint or another material safety issue cannot be resolved as specified, stop for that decision rather than merging a knowingly noncompliant workaround**; clearly distinguish what was safely completed from what remains blocked. PR merge does not authorize Play rollout or hosted database/provider changes.
