# MAP01 shared location foundation

MAP05 adds a required master gate and exact quarter-credit account ceiling for
all four Geoapify consumers. Existing editor limits remain additional guards;
see [current meter and activation](map05-interactive-discovery.md). Its public
search-center API is separate, authenticated-only and disabled by default.

Decision verified on 2026-10-08 against main `4b994d278a9686063573e9ed60e82201dd820256`.
Geoapify is the accepted free-first implementation target. No account, commercial
terms acceptance, provider traffic, deployment, GPS permission or map SDK is
activated. MAP02 owns editor controls, MAP03 previews, MAP04 geographic queries
and MAP05 interactive discovery.

## API and licensing decision

The only permitted upstream endpoint is
`GET https://api.geoapify.com/v1/geocode/autocomplete`. One query permits Italy
with `filter=countrycode:it`, ranks around public Trento with
`bias=proximity:11.1217,46.0748`, uses `lang=it|en`, `limit=5`, `format=json`
and a server-secret key. The bias excludes no other Italian location. The
[autocomplete documentation](https://apidocs.geoapify.com/docs/geocoding/address-autocomplete/)
lists locality, street, building and amenity results. A suggestion already carries
the required verified geocoding details; explicit resolve validates its server
receipt and makes zero additional provider calls. There is no provider-ID lookup.

The optional combined [Autocomplete/Places flow](https://www.geoapify.com/address-autocomplete-with-built-in-places-support/)
uses additional Places requests. It is excluded: autocomplete amenity support is
documented, but real venue quality has not been tested. Unsupported result types
or unreviewed sources fail explicitly; Geoapify is not silently replaced.

[Geocoding storage guidance](https://www.geoapify.com/geocoding-api/) permits
stored results while retaining source attribution. [Provider terms](https://www.geoapify.com/terms-and-conditions/)
require OSM attribution, Geoapify attribution on Free, and any API-specific
credits. [OSM's licence](https://www.openstreetmap.org/copyright) permits copying
and reuse subject to ODbL attribution and applicable share-alike obligations.
MAP01 admits only `datasource.sourcename=openstreetmap`. Other datasets require a
separate field/source-rights review; absence of source metadata is not approval.

| Field/class                                                                                         | Storage and retention decision                                                                                                                                                                                                                        |
| --------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| User-authored manual public label/locality and meeting instructions                                 | Existing canonical fields and historical retention remain intact. Not provider-verified geometry. Instructions never go upstream.                                                                                                                     |
| Provider display label, locality, administrative area, country                                      | Store only selected OSM-backed normalized geocoding fields, bounded at 180/120/120/2 characters. Source rights above apply to addresses and autocomplete amenity geocoding equally. No directory enrichment.                                          |
| Latitude/longitude and result kind/type                                                             | Store the selected geocoding point, SRID 4326, with source attribution. Broad locality is an area reference, never a precise meeting pin. Exact points stay in the existing meeting table.                                                            |
| Confidence                                                                                          | Optional bounded 0–1 provider ranking evidence. Preserved as part of the selected result; it is not proof that a venue exists or that a meeting occurred.                                                                                             |
| Provider/source, attribution, ODbL URL                                                              | Durable provenance accompanies selected fields and historical authorized reads. Required credits: linked Geoapify and OSM contributors/copyright. No HTML or arbitrary attribution URLs are copied from responses.                                    |
| `verified_at`                                                                                       | Server-issued provenance time; never accepted from a client or automatically refreshed. It describes verification time, not continuing venue accuracy.                                                                                                |
| Provider place ID, datasource object, categories, opening hours, contact/media, timezone, full JSON | Not persisted or exposed. No permanence promise for provider IDs and no extra Places licence assumption. Existing event timezones are untouched.                                                                                                      |
| Opaque receipt, search digest and temporary selected objects                                        | Five-minute server TTL for actor/item/slot/revision/session, independent of durable licensing. Expired objects are erased on the next enabled reservation; operators may run the cleanup below without activation. No original query text is stored.  |
| Applied selected result                                                                             | Nullable canonical content, retained with existing content/history until explicit clear/replacement or applicable canonical deletion policy. No bulk refresh, changed historical policy or new account deletion semantics.                            |
| Write retry record                                                                                  | Private identifier-only actor/request/item/receipt/revision record, following existing recovery patterns. Contains no labels, coordinates or provider response. Superseded retries fail, and authorization is rechecked even for duplicate responses. |

The [pricing page](https://www.geoapify.com/pricing/) advertises 3,000 Free
credits/day and Limited Commercial Use. [Metering details](https://www.geoapify.com/pricing-details/)
meter autocomplete/geocoding, Places and maps separately; provider quotas are
soft. Formal terms qualify commercial production use and request contact for
details, while product guidance permits commercial projects within limits. The
owner must obtain confirmation for PLANETS' intended production usage, agree an
account-wide cost ceiling and approve source/attribution obligations before
activation. These caveats do not prevent disabled fake-tested code and licensed
nullable storage. No commercial terms have been accepted here.

## Server and quota boundary

`supabase/functions/location-search/` is a self-host-compatible Edge Function.
`provider.mjs` owns the fixed upstream HTTP adapter and normalization;
`handler.mjs` owns purpose/actor/scope checks and metering;
`index.ts` owns Auth/REST transport and runtime-only secrets. Tests import the
same pure modules and inject all external dependencies.

Both `LOCATION_SEARCH_ENABLED=true` **and**
`private.location_search_config.enabled=true` are required. All committed defaults
are false, and the template key is empty. There is no key/activation flag in
Flutter or Web. Missing configuration is `unconfigured`, a disabled switch is
`disabled`, and each makes zero provider calls. The registered mobile gateway
remains `DisabledPlaceSearchGateway`; MAP02 can inject `ServerPlaceSearchGateway`
only after its actor/form/entitlement lifecycle wiring and activation gates.

POST search/resolve accepts a narrow actor/item/kind/revision/slot/session scope.
Search alone includes normalized query and IT/EN language; resolve accepts only
the issued receipt. Unknown fields, arbitrary URL/provider/parameter bags,
client coordinates, query parameters and anonymous calls are rejected. JWTs go
only to Supabase Auth; neither JWT nor identity goes to Geoapify. No unauthenticated
search proxy is activated. MAP05 public search would need a separately reviewed
identity/installation abuse boundary and must use the same global meter.

Backend input is 2–160 NFC-normalized characters, with control characters
rejected, body capped at 4 KiB and provider JSON capped at 64 KiB. At most five
unique suggestions are admitted. The fixed upstream request has a 3.5-second
deadline across fetch/body, refuses redirects and makes no retries. Private
upstream bodies/URLs/errors are never emitted. Supabase transport has two-second
timeouts. Status-only metric injection is available; the default hook emits
nothing. Never attach request objects or exception messages to monitoring.

Atomic PostgreSQL reservations serialize on the one configuration row and
enforce **1,000 provider requests per UTC day globally, 80 per actor per day,
10 per actor per minute**. Privileged operators can configure lower caps, or
raise them within the migration's conservative 2,000/200/20 bounds after owner
approval. One autocomplete costs one reserved request; failures are not refunded.
This is deliberately below advertised Free capacity. It is not an account-wide
cap for unrelated keys/projects or future maps. Maps/tiles/static previews and
any optional Places flow need their own approved costs inside a shared meter.

Identical actor/item/revision/slot/session/query-digest requests reuse an unexpired
ready batch. Concurrent duplicates return `search_pending`. A provider failure
leaves that reservation pending for at most five minutes; a new query/session can
retry only inside the same enforced budgets. Manual drafts are unaffected.
Unavailable metering/Auth/transport cannot trigger an upstream call. Statuses
distinguish disabled, unconfigured, unauthorized, immutable item, stale/expired
selection, budget exhaustion, rate limiting, pending search, invalid credentials,
provider quota/HTTP failure, timeout, offline, malformed response, invalid country
and unsupported place/source. An empty successful result is a genuine no-match.

## Canonical storage and RPC contract

Migration `20261008124856_geoapify_shared_location_foundation.sql` adds nullable
`selected_public_place` and `location_revision` to existing content parents,
`selected_exact_place` to the two existing protected meeting tables, and only
`resource_listings.public_location` as a new geography column. Project/Tavolo
`approximate_location` and protected `exact_location` are reused. No generic
location owner table, duplicate Project point or geography discovery is added.

`selected_public_place` on Projects/Tavoli must be independently selected broad
locality. Selecting an address never derives public area by rounding, jitter,
zoom, viewport or reverse geocoding. Exact-only content has null public geography.
Resource selections are public locality/address/amenity without a new private
pickup-address or participation policy. Normalized fields, kind/type, coordinates,
source and point/JSON consistency are checked in Postgres. Untouched manual and
international records keep null derived data and their current country/timezone.

The service role can reserve/issue/resolve receipts via the three purpose-limited
`*_location_*_v1` server RPCs. It has no raw receipt/config/budget table access and
cannot invoke the client durable mutation. The Edge Function first validates
the JWT against Supabase Auth; service-only actor parameters must never be
exposed as client RPCs. All new private tables have RLS and zero client grants;
all privileged functions have empty search paths and explicit execute grants.

`apply_item_location_v1(expected actor, kind, item, expected revision, request UUID,
public action/receipt, exact action/receipt)` atomically supports `unchanged`,
`replace` and `clear`. Only replacement takes a receipt. The backend rechecks
canonical Creator/Co-creator structural authority, Creator-only draft ownership,
one-time start/terminal constraints, ended Tavoli and closed Resources. Resource
editing remains owner-only. Co-organizers and ordinary members can read entitled
meeting details but cannot perform structural location changes. Location adds
neither photo nor publication nor an extra login gate.

Replacement updates canonical public structured/text fields from the independent
public selection, leaves manual meeting instructions and exact visibility intact,
and never accepts client labels/geometry as verified. Clear removes metadata and
geometry while retaining current text. Any legacy public text change clears its
derived public pin; manual meeting-instruction change clears the derived exact
pin. Visibility change increments revision and immediately changes reads without
manufacturing public coordinates. Existing RPC signatures remain unchanged.

Content/location/visibility changes invalidate saved revisions. Exact changes
also increment the parent revision. A retry UUID binds the full mutation input;
duplicates recheck authorization and succeed only while that resulting revision
is current. Stale/superseded updates fail with `40001`. Invalid/expired/reused
receipts fail explicitly, and a failed multi-slot transaction consumes neither
receipt. Publication/recovery/template creation remain separate existing RPCs.

MAP02 sequence: save manual draft/content using the existing RPC, obtain
`get_authorized_item_location_v1` revision, create actor/form-scoped search
gateway/controller, explicitly resolve each selection, then apply the receipts
with that revision and one retry UUID. Save before searching; an intervening
content edit requires fresh search receipts. Cancel/erase on actor change
(including Alice → Bob → Alice), entitlement loss, new form/revision, departure
and disposal. Raw query and short-lived receipt data must never enter DRAFT01
durable snapshots. Existing persisted selected data survives recovery via its
own canonical read; source-private data is not copied into new templates/drafts.

## Read/exposure audit

| Surface/viewer                                                                | Sanctioned data                                                                                                                                                                                                             |
| ----------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Legacy public list/detail, pending projections, Next.js SSR/HTML/share routes | Existing public coarse text; exact instructions only where already explicitly public. Their result signatures/allowlists contain no new protected metadata, receipts or points. Web does not call the new location RPC yet. |
| `get_public_item_location_v1(kind,id)`                                        | Independently selected public area; Resource public selection. Project exact selection only when existing exact visibility is `public` and canonical public detail is reachable. No geographic/viewport/radius parameters.  |
| Creator/current Co-creator/Co-organizer/current accepted member               | `get_authorized_item_location_v1` delegates Project meeting entitlement to the effective existing participant RPC and includes protected selected metadata plus current revision.                                           |
| Removed/former member, unrelated signed-in, changed expected account          | Protected read rejected on every request. Flutter controller cancellation clears derived labels/points; no shared public cache, persisted search cache or new protected-detail cache exists.                                |
| Resource owner                                                                | Existing owner read gates the authorized selection/revision projection, including own closed history. No Project-membership semantics.                                                                                      |
| Raw Data API, generic views, grants                                           | Existing content tables remain RPC-only. New columns gain no direct grants; new private tables expose no client policies/grants.                                                                                            |
| Templates/new template drafts                                                 | Existing explicit reusable-content allowlist copies no exact provider object, exact point, ID or receipt. New nullable columns default null. Public reusable text remains subject to existing free-text responsibility.     |
| Audit/outbox/notification payloads, errors/metrics                            | Identifier-only change audit. No new location outbox content, notification, URL, directions, viewport builder or provider response logging.                                                                                 |

Future MAP03/04 must consume these sanctioned projections. An area remains
independent even when there is no public point: absence is not permission to query
or narrow around a confidential pin. Public result objects require attribution;
explicitly public exact detail must never be reused as a generic browse/map pin.

## Owner activation and operations

MAP02 wires the reusable selector into three Flutter editors while retaining
disabled/manual registration. Its scoped factory, save/retry ordering,
idempotent Tavolo/Resource bootstrap, exposure and native rehearsal are documented
in [MAP02](map02-location-selector.md). No UI flag, key, live traffic or switch
activation is introduced. MAP03 must credit public surfaces, including derived
text retained after clear/template copy, before activation. An injected native
fake is presentation evidence only.

1. Confirm commercial production scope with Geoapify and approve intended
   volume/cost ceiling and ODbL/attribution responsibilities. Update truthful
   location/privacy disclosures; voluntarily searched addresses can be personal
   data even though backend egress hides device IP from Geoapify. See the
   [provider privacy notes](https://www.geoapify.com/maps-geocoding-routing-apis-gdpr-compliant-application/).
2. Obtain an account/key and actual server egress IP. Keep the key in runtime
   secret storage, restrict it to that IP where possible, and test restrictions.
   [Key guidance](https://myprojects.geoapify.com/help/api-keys/) explains that
   CORS is not authorization. No final host/egress identity has been supplied.
3. Deploy only after explicit authorization. Use the same Edge/Auth/PostgREST
   environment boundary on managed or self-hosted Supabase. Never copy `.env`
   into a client bundle, tracked config, screenshot or build log.
4. Implement and verify MAP02 identity/entitlement cancellation and visible
   linked Geoapify/OSM attribution wherever selected geocoding data is displayed,
   including legacy public text that replacement updates. Attribution must also
   cover retained labels after clearing a pin and public text reused by templates;
   a page-wide credit is necessary where that legacy text has no source object.
   Clearing geometry does not remove the text's attribution obligation. Activation must wait
   for those displays and relevant terms/privacy disclosures; MAP01 adds no UI.
5. With owner-approved real testing, exercise `Trento`, `Povo, Trento`,
   `Piazza Duomo, Trento`, one Italian street address and one named venue/POI,
   both IT/EN and a locality elsewhere in Italy. Record source eligibility,
   component/coordinate quality, amenities and failure behavior. No native/live
   provider readiness is inferred from fixtures. Missing venue quality requires
   a documented follow-up decision before adding metered Places calls.
6. Configure conservative database caps and monitoring, then enable database
   and runtime switches only with explicit authorization. Check absent key,
   invalid key, quota/meter failure, manual fallback and revocation on target
   Android/iOS runtimes before calling the integration live.

Immediate kill switch (privileged operator, approved environment):
`update private.location_search_config set enabled=false where singleton;`
It blocks new reservations/resolution/replacement; clears/manual edits remain
available. Already in-flight upstream requests can finish, but cannot issue a
new durable selection after disabled checks. Disable the runtime switch and
restart/redeploy it for zero subsequent network attempts.

Rotate a key while disabled: create restricted replacement, change runtime
secret, test only with authorization, remove old key, then deliberately reenable.
Never use billing dashboards/soft quota as the hard cap. Inspect counts in
`private.location_search_budgets` without adding query/coordinate analytics.
Operators may delete expired `location_search_batches` and old UTC budget rows
without enabling search; child selection objects cascade away. Keep body-free
write retries under existing recovery/retention policy. Account deletion remains
the founder-owned canonical workflow, not an incidental MAP01 cleanup.

## Reproduction and validation

Provider/endpoint fixtures: `node --test scripts/lib/location-search.test.mjs`
(also included in `npm run test:tooling` and Web CI). Flutter fixtures:
`flutter test test/features/locations` from `apps/mobile`. Database invariants:
`supabase test db supabase/tests/120_location_foundation.test.sql`. Existing
structure-test column lists were extended only for the additive schema.

Use `npm run check:db` only on a task-owned disposable stack with distinct
project ID/ports/containers; it resets and mutates its stack. MAP01 QA used
`planets-map01-qa`, API `55421`, DB `55422`, distinct from the retained phone/demo
stack `planets-community` at `54321/54322`. Local isolation config is temporary
and must not be committed. Set `PLANETS_DISPOSABLE_QA=1` for upgrade verifiers.
Run standard mobile/Web gates and the canonical `npm run db:types` generator.
No fixture invokes Geoapify; no hosted migration or phone session is authorized.

`npm run location:verify:local` exercises real authenticated REST writes,
service-only receipt issuance and concurrent retries/reservations with synthetic
normalized provider data. It requires `CI=true` or `PLANETS_DISPOSABLE_QA=1` and
an explicit loopback `MAILPIT_URL` (MAP01: `http://127.0.0.1:55424`). It is included
in the full database command and Database CI. The workflow addition therefore
selects every validation area under the existing classification policy, without
changing required status checks or weakening unrelated coverage.

[MAP03](map03-location-previews.md) now owns read-only previews, public batching,
static transport, public attribution and the shared rendering/autocomplete
credit ceiling. Provider defaults remain disabled.
