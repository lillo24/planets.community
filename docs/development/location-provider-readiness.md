# Location provider readiness

## Current MAP01 decision, 2026-10-08

Geoapify is now the accepted free-first implementation target. The disabled
server adapter, nullable canonical storage, private selection receipts and hard
request budgets are implemented by MAP01. Production mobile registration stays
disabled; no key, live traffic, deployment, map SDK or editor search UI is active.
The [MAP01 decision and runbook](map01-geoapify-location.md) owns current API,
field-by-field storage/attribution rights, exposure matrix, configuration and
activation gates. Its verified OSM-backed geocoding contract supersedes the
earlier deferred schema/provider shortlist below. Free commercial production
scope still needs owner clarification before activation. MAP02 can develop on
MAP01's implemented head without a live account/key.

MAP02 implements reusable editor selection and deterministic tests. Default
registration and both backend switches remain off; manual fields still work.
See [MAP02](map02-location-selector.md) for scoped activation wiring, draft/receipt
ordering and the MAP03 attribution gate.

MAP03 adds public card/detail panels and freshly authorized Google Maps links.
Static rendering remains disabled at client/runtime/database boundaries. The
[MAP03 runbook](map03-location-previews.md) owns current budgets, attribution,
transport and owner activation. Historical detail-only guidance below does not
describe current card panels.

## Historical UI-NEXT-04 assessment

The following assessment records the former disabled-only delivery. Its
Google/Mapbox options and activation checklist are historical context, not the
current selected implementation or a prohibition on MAP01's reviewed schema.

## Approved delivery

On 2026-10-07 the founder chose: **deliver the disabled foundation; retain manual
locations and document activation requirements**. This selects no paid provider,
billing account, storage licence, credential or production resource. The isolated
scope can merge after validation; provider-dependent schema/activation is deferred.

The gateway is disabled in every environment, with no activation config key.
Existing manual fields, instructions, visibility, draft snapshots/recovery,
templates and public/protected RPCs remain canonical. No new coordinates/place IDs
enter DTOs, migrations, grants or generated types. PostGIS grants neither data
rights nor public precision. No bulk geocoding or seed rewrite occurs.

## Bounded assessment, checked 2026-10-07

Google Autocomplete (New) is a suitable candidate for mixed city/address/venue
selection. Country restriction and ranking bias differ; a cities-only filter
would exclude venues. An adapter should restrict Italy, bias toward public Trento,
use IT/EN, explicit resolution and bounded field selection without GPS. This is a
feasibility finding, not approval. [Autocomplete documentation](https://developers.google.com/maps/documentation/places/web-service/place-autocomplete).

Google's place-ID storage exception does not authorize permanent storage of
labels, components or coordinates. Attribution and public terms/privacy apply.
Account billing address determines EEA terms, not user location. Current EEA
Places rules limit coordinate caching and add restrictions on other content's
map use/permitted uses. Do not apply Geocoding's different exception to Places or
infer unrestricted community ownership from a click. Obtain field-by-field use,
retention and historical-data approval before schema design.
[Places policies](https://developers.google.com/maps/documentation/places/web-service/policies),
[EEA service terms, section 15](https://cloud.google.com/terms/maps-platform/eea/maps-service-terms).

The one meaningful alternative is Mapbox Search Box with Flutter Maps. Search Box
supports Europe and IT/EN, but results are temporary; storing positions requires
an arrangement with Mapbox Sales. It does not solve permanent Project storage by
default. Tokens group suggest/retrieve billing sessions; each call still counts
against rate limits. [Search Box documentation](https://docs.mapbox.com/api/search/search-box/).

Both candidates offer Android/iOS maps in Flutter:
[Google setup](https://developers.google.com/maps/flutter-package/config),
[Mapbox Flutter Maps](https://docs.mapbox.com/flutter/maps/guides/).
A map package alone supplies neither approved Places transport nor persistence
or authorization. No package/version is selected or added. Activation must verify
native SDK/Places compatibility against current pinned Flutter/Dart/Gradle/iOS
dependencies, then build and interact on both platforms. No incidental upgrade.

## Usage and security

Current paid usage is zero. Estimate future cost from editing sessions × debounced
queries/session, explicit resolutions, deliberate detail map openings and legally
required historical refreshes. Maps are detail-only. Google's session termination
and detail fields affect billing; obtain the estimate for the actual approved
region/SKUs/volume rather than inventing a monthly price.
[Session pricing](https://developers.google.com/maps/documentation/places/web-service/session-pricing).

A future adapter must enforce allowed operations, query/result caps, timeouts,
rate/abuse limits and no arbitrary URL proxying. Native keys need platform **and
API** restrictions; those do not automatically secure arbitrary REST requests.
Choose supported native Places or a narrowly scoped authenticated backend adapter
with a self-hosted equivalent. Server keys never belong in the app. Do not send
emails, instructions, JWTs or unnecessary actor metadata to provider/logs.
[Security guidance](https://developers.google.com/maps/api-security-best-practices).

## Required activation work

1. Approve provider/product, billing-region terms and each persisted field.
   Specify expiry/refresh/delete for active/history/deletion requests and content
   attribution. Separate user-authored text from temporary derived data.
2. Agree volume/cost ceiling, enabled APIs, alerts **and enforceable quotas/rate
   limits**, abuse monitoring, key rotation and remote disable. No provisioning
   or acceptance of terms is authorized by this foundation.
3. Verify development/release identities and signing. Tracked bootstrap Android
   ID: `community.planets.bootstrap.planets_mobile`; iOS:
   `community.planets.bootstrap.planetsMobile`. These are repository values, not
   confirmed final production identities. Obtain fingerprints and separate
   platform/API-restricted keys, with secret-managed server credentials. Never
   paste secrets into tracked files or QA reports.
4. Implement reviewed canonical nullable storage/DTO extensions, RLS/grants and
   actor checks. Resolve public area independently; protect exact IDs/points just
   like addresses. Audit lists/detail, raw Data API/views, manager/member reads,
   Web HTML/SSR, templates, notifications, reports, logs and caches. Templates and
   reused drafts must exclude source-private locations. Preserve legacy values.
5. Wire selection UI and DRAFT01 raw-query state after contract approval. Raw
   typing is not selection. Keep manual fallback and bind cancel/dispose to actor,
   form and canonical entitlement changes; avoid guessed client-side roles.
6. Add lazy detail maps, readable attribution and deliberate map actions after
   approval. Broad cities get no precise directions. Public payloads, semantics,
   viewports/URLs must exclude restricted precision. An independent broad area,
   rather than rounded/blurred/displaced/zoomed-out exact points, is required.
7. Update privacy/terms disclosures. Run isolated migration/RLS/RPC, DTO/Web
   leakage, actor/revocation and expiry tests. Record actual native search/maps
   on Android **and iOS** with approved setup. Fakes are not live readiness.

Manual entry stays usable until replacement requirements pass. This record is
neither a licence acceptance nor a deployment.

## MAP04 / MAP05 public search-center handoff

MAP04 adds stored-public-point radius/viewport queries with no provider calls.
See [MAP04 geographic discovery](map04-geographic-discovery.md). MAP05 public
center autocomplete must define its own public/anonymous authorization, abuse
and cost boundary; MAP02 item-bound authenticated edit receipts are unsuitable.
MAP01 search and MAP03 static rendering remain disabled.
