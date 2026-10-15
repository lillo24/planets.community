# MAPUI03: independent city text and map-state attribution

Based on `origin/main` `8a2c32592e8d22df61d27c4446ba9fa339d3e35c`.
The founder selected the credit-free text-only city requirement and an independent
city source. No provider-credit exception or provenance migration is needed.

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
- Text-only details display only canonically attested manual city text or a name
  resolved from the bundled independent ISTAT catalogue. Provider labels/points
  remain separate. Unmatched detail data shows localized unavailability with no
  Maps action, never an uncredited provider address. Editor provider results and
  actually rendered maps retain their attribution. Tile scopes, leases, aborts,
  protected buffers, quotas and compile-time defaults are unchanged.

Tests encoding the old pending-text/button/error behavior were updated for the
requested compact fallback. Existing authorization, disposal and cache assertions
remain in place. The new visual matrix uses real Flutter widgets/fonts, EN/IT,
light/dark, 320dp and normal/2x text. Tile images in these tests are synthetic.

Reviewed captures: [manual city](evidence/mapui03/en-light-1.0x-manual.png),
[independent city at 2x](evidence/mapui03/it-dark-2.0x-geoapify.png), and
[decoded synthetic canvas](evidence/mapui03/it-synthetic-rendered.png). The last
capture is also 320dp and is not a live Geoapify map. Filename suffixes identify
the stored provenance: the text-only output comes from the independent source.

Captures are produced with
`flutter test test/features/locations/compact_location_ui_test.dart
test/features/locations/location_preview_widget_test.dart
test/features/locations/location_tiles_widget_test.dart
--dart-define=UI_POLISH_CAPTURE_DIR=<absolute-evidence-directory>`.
Final focused checks, complete mobile checks and hosted CI are reported in PR #265.

## Independent source without a migration

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

`presentation/independent_public_city.dart` prefers genuinely attested manual city
text (including international/nonmunicipal names). Otherwise the public locality/
country is an **exact lookup key**; the returned name comes from ISTAT's official
Italian name, not a shortened provider result. No fuzzy matching or geometry is
used. `mappa test` remains provider-sourced at revision 7, while its public
`Trento / IT` key independently resolves to ISTAT **Trento**. This is presentation
reference data, not a canonical city validator, geocoder, authorization rule or
search/matching boundary. No record, receipt or provenance is rewritten.

The pinned source is ISTAT's [Elenco dei comuni italiani](https://www.istat.it/classificazione/codici-dei-comuni-delle-province-e-delle-regioni/),
updated **21 February 2026**, retrieved **15 October 2026**, 7,894 municipalities.
The derived const map contains 8,132 unambiguous official name aliases.
The original [workbook](https://www.istat.it/storage/codici-unita-amministrative/Elenco-comuni-italiani.xlsx)
is retained unchanged in `apps/mobile/tool/data/istat-municipalities-2026-02-21.xlsx`;
SHA-256 `83842076860450f7e482daecea6b7a769f5f93d0bf5b0d48802b44896d7a26d5`.
ISTAT's [legal notice](https://www.istat.it/note-legali/) licenses this under
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). The adaptation extracts
official Italian names and official bilingual/other-language aliases, normalizes
keys, sorts/deduplicates them and omits ambiguous aliases. There are no coordinates
or Geoapify data. Source/version/adaptation and licence links are available through
**Help → Licences**, not a footer in city views. No ISTAT logo/endorsement is used.

`tool/generate_italian_municipalities.py` uses Python 3's standard library, verifies
the pinned checksum/schema/count and generates `data/italian_municipality_names.g.dart`.
See [maintenance commands](../../apps/mobile/tool/README.md). A source refresh
requires reviewing source/checksum/count/dates, generated names, licence notice
and tests together. Normal builds/runtime need neither Python nor a network call.

Related public cards/compatibility details use the same independent catalogue
names. All-catalogue city lists have no Geoapify footer. Older list DTOs omit
authored-text provenance: where their raw geocoding information cannot be
independently resolved, that retained information keeps its existing credits.
The text-only detail fallback never reuses that unclassified provider content.
Before imagery, even authorized exact-place text stays out of the city row;
after pixels render, its authorized precision/label and map credits remain.

This client-bundled reference lookup requires no schema, backfill, hosted function
deployment or provider-configuration change. PostgreSQL remains authoritative.
Tests cover source separation, official aliases, genuine manual names, unmatched
data, visible editor credits, decode/revoke/lifecycle/privacy, fresh Maps taps,
licence access and EN/IT 320dp normal/2x screenshots. Tests asserting former
provider-label/credit fallback behavior changed to the new specification; pixel
revocation tests wait for actual decoded pixels before asserting exact text.

## MAPFIX03 handoff and release boundary

MAPUI03 is merged in [PR #265](https://github.com/lillo24/planets.community/pull/265).
See the [MAPFIX03 follow-up evidence and remaining live acceptance](mapfix03-live-detail-diagnosis.md).

MAPFIX03 starts after MAPUI03 merges. Initial read-only ADB inventory on this run
found no attached device; physical phone `48091FDAS0041A`, installed package,
signer, installer, compiled gates and Play assignment remain unverified. Ordinary
staging builds omit both opt-in map flags; the existing explicit
`tool/build_map_live_staging.dart` provides them. This source fact does not prove
the installed artifact's root cause or authenticated live rendering.

No hosted SQL/Edge configuration was deployed, no provider tile traffic was
generated, no Android candidate was built or installed, and nothing was uploaded
to Play during MAPUI03. After the UI is merged, inspect the exact installed
artifact, check current staging parity and Play version history, prepare the
explicit map-enabled signed candidate from current main, and verify one bounded
authenticated `mappa test` preview before requesting a Play rollout.
