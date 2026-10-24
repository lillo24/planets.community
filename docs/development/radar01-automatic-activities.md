# Automatic local Activities (RADAR01)

RADAR01 extends the existing Node worker, canonical catalogue and Flutter
Activities screens. It creates no hosted source, source permission, schedule,
production deployment or native participation/booking/chat mechanism.

## Collection and source policy

The code-owned registry in `scripts/lib/external-activities/radar-sources.mjs`
defines publisher relationship, origin/path scope, parser version, MIME, delay
and coverage. `robots.txt` is fetched on every collection; its availability or
allowance is not a reuse licence. A 401/403, robots denial, unexpected delay,
malformed response or incomplete traversal fails explicitly. No browser, proxy,
login, paid model/OCR or phone-side fetch is used.

| Source ID / publisher                                         | Actual interface and coverage                                                                                                                                                                                                                                                                                                       | Parser              |
| ------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------- |
| `muse-events` / MUSE                                          | [Calendar](https://www.muse.it/calendario-eventi/) and its linked `/eventi/` detail panels. Stable advertised WordPress event ID; linked and unlinked venue panels. Explicit full dates/date lists, or exhibition spans. Other MUSE venues are excluded; ambiguous recurrence prose is held.                                        | `muse-semantic-v1`  |
| `santa-chiara-events` / Centro Servizi Culturali Santa Chiara | [Publisher](https://www.centrosantachiara.it/), whose own `load_shows` submits `/csc_shows` with `date-range`. One bounded read-only form POST queries the explicit 90-day window. Separate performances retain their dates; different venues remain separate. A source item link is required; no box-office internals are crawled. | `santa-calendar-v1` |
| `arci-trentino-events` / ARCI del Trentino                    | Events linked by the [publisher homepage](https://arcideltrentino.it/), then actual Event JSON-LD and semantic category/venue evidence. This is a publisher relationship, not proof that ARCI organizes every item or a complete regional archive. Default plugin price zero does not prove free entry.                             | `arci-jsonld-v1`    |
| `susat-outings` / SUSAT                                       | [Published RSS](https://www.susat.it/feed/). Explicit full outing date in each title; RSS publication date is retained separately. Only supported local-departure evidence establishes relevance. Destination, city and geometry are not invented from a Trento departure.                                                          | `susat-rss-v1`      |

These four sources are **publication-held**: no applicable republication basis
was established by the access checks. Source links, APIs, feeds, JSON-LD and the
distinction between facts and creative wording do not themselves clear reuse or
systematic extraction restrictions. No unrelated CC URL is supplied. UniTrento's
[legal notices](https://www.unitn.it/it/note-legali) restrict default reuse;
[Trento Giovani's notices](https://trentogiovani.it/Note-legali) do not establish
a blanket licence. They remain assessed candidates without enabled collectors.
No replacement publisher hunt was needed. Agenda Trento and ODH retain their
existing, independent blocks.

General bounded RSS/Atom, iCalendar and JSON-LD support lives in `extraction.mjs`;
it does not make arbitrary sources configurable. XML DTD/entities/XInclude are
denied, contexts/scripts are never executed or fetched, and calendar expansion
supports only finite daily/weekly rules with bounded exceptions. Unsupported
rules and ambiguous DST wall clocks are held. Date-only values stay dates;
exhibition spans do not assert continuous opening. Publication metadata is
never used as an occurrence date. Missing source fields stay null. Descriptions
and images are omitted from the new publisher collectors.

Transport keeps the original five-minute, 160-request, 50-page, 100-related,
2 MiB decompressed response, 16 MiB total and 2,000-record limits. HTML/XML/calendar
MIME requires the separate document opt-in; the existing CSV path stays narrow.
Requests are sequential per source, with 1-second minimum spacing (Santa Chiara:
10 seconds). Retry-After is respected within the existing capped wait, and a
longer requested wait fails this run. DNS is checked inside the actual TLS
connection lookup, denying private/reserved addresses; HTTPS origins and paths
remain code-owned. Redirects are revalidated; calendar POST redirects are denied.

## Private evidence and promotion

Only an owner can configure source flags. All new source flags default false;
`radar_parser_version` and `radar_policy_url` default null. Collection requires
`radar_collection_enabled` and an exact registered parser version. It does not
require public enablement or grant reuse approval.

Promotion additionally requires existing `enabled`, `rights_confirmed`, genuine
`license_url` and attribution, plus `radar_parser_qualified`, `radar_facts_reuse`
and a relevant `radar_policy_url`. `radar_prose_reuse` is a separate false-by-default
gate; these collectors never extract descriptions even when it is true. Images
are not supported by this import boundary. A service key cannot set these flags.
The existing licence/provenance contract remains required; private permission
without a usable public permission/licence representation needs a separate
contract decision, not a fabricated `license_url`.

Qualification is bound to `radar_qualified_parser_version` and the actual approved
terms digest: `radar_policy_revision` must match `radar_qualified_policy_revision`.
All three default null. A parser or policy revision change immediately invalidates
the former qualification until the owner explicitly qualifies that version.
Policy changes must be registered by the owner; collection does not infer rights
from an unchanged policy URL or silently approve newly observed terms.

`external_radar_runs` stores bounded collection outcomes. Candidates store
stable upstream identity, a digest of normalized facts/reason/parser, record,
field locators, actual URL/content digest, retrieval time, parser version,
publication date and explicit hold/review reason. `external_radar_documents`
stores only extracted facts/link recipes and validators, never complete pages,
images or contact paragraphs. The private tables have RLS and no raw grants,
including service role. Narrow service RPCs inspect, collect, reject an exact
revision and maintain evidence. Ordinary clients cannot read them.

Complete traversals replace only their bounded representation cache (at most
64 documents). A 304 confirms only its own cached representation with the same
parser and extraction context: cached listing links are still traversed and
every detail is independently fetched/validated. POST queries are never
conditionally reused. Incomplete/failed traversals commit no candidates,
document validators, catalogue updates or observations. Source modification,
retrieval, occurrence, publication and complete-run times remain distinct.

The source lease is shared with the existing importer. Source changes invalidate
promotion through its configuration version; a disable or rights/qualification
withdrawal also denies public reads immediately. A legacy finish RPC cannot
bypass the qualified-evidence trigger. A held collection leaves canonical
observations and last successful public import untouched. Conflicts and all-held
unexpected drift do not become a healthy empty import. Absence is not cancellation.

Maintenance retains at most three revisions per identity and prunes evidence
older than 30 days, plus document caches older than seven days. Each maintenance
RPC deletes at most 100 candidates/documents; the operator drains at most 100
such batches per selected source under its parent deadline. Active source leases
are skipped, expired leases recover explicitly, and no canonical identity/facts
are deleted. Regular maintenance is required to enforce retention; keep it in
the scheduled apply path and use standalone maintenance after disabling a source.

## Identity, aliases and public discovery

Existing `(source_id,upstream_id)` UUIDs survive harmless title/time updates.
Santa Chiara groups one source item/venue's explicit performances; the stable
published slug plus venue distinguishes separate venues. A corrected upstream
identity or venue wording requires review, rather than a fuzzy merge.

Exact cross-source aliases require the same official item URL and identical
occurrence/schedule/venue/city/geometry/status facts. Original records and
provenance are retained; the first collected identity stays canonical. The
private `radar_identity_seen_at` defaults to migration time for existing rows and
actual insertion time for new rows; it is not an assertion about source creation.
Conflicting time/place facts are held as `source_conflict`. No title similarity
merge occurs. Old links resolve through the proven alias to the canonical item.
An alias cannot refresh an unobserved canonical source; source withdrawal and
canonical freshness gates still apply. Known source corrections require owner
review of the retained source records, not an automatic title-based mapping.
After collecting both identities, `operate-radar-candidates.mjs --alias --source
<id> --upstream <old-id> --canonical-upstream <corrected-id> --target <target>`
uses the separate owner database credential to record an explicit same-source
correction and invalidate cursors. It permits no alias chain or policy change.
Corrected links still require the canonical record's own freshness and source
approval. Automatic reconciliation cannot overwrite this owner mapping.

V4 adds `p_activity_type` after all V3 parameters and keeps the HMAC cursor bound
to it, all other filters, eligible source versions and the reference/order. V1,
V2 and V3 signatures/OIDs/grants remain available. The canonical helper owns
eligibility and aliases for every version; V4 applies family/query/discipline/
date/area/map scope before facets and paging. Public `activity_type` is nullable:
`music`, `theatre-cinema`, `talks`, `workshops`, `social`, `exhibitions`, `outings`.
Unknown generic publisher labels do not populate a fabricated family.

Flutter uses V4 for List and Map, retains the selected type across search/area/
date changes and shows only source-backed facets (plus a clearable current
selection). Sports disciplines and broad categories keep their existing meaning.
Today/Weekend use Europe/Rome calendar dates; Sunday selects the remaining Sunday.
Chosen dates keep the existing exclusive end and 90-day bound. Missing geometry
remains visible in unscoped List. Publisher names, honest unknowns, official links,
Find company, mode/account fencing, no-provider maps, map budgets and denied
production analytics retain their existing boundaries.

## Reproduction and exact activation sequence

Dry-run performs collection/validation without database writes and reports zero
publishable records because it cannot infer owner configuration:

```text
node scripts/operate-external-activities.mjs --dry-run --sources muse-events,santa-chiara-events,arci-trentino-events,susat-outings
```

All applied/operator commands require `ACTIVITIES_API_URL`, server-only
`ACTIVITIES_SERVICE_ROLE_KEY`, and equality between `ACTIVITIES_TARGET` and
`--target`. No credential belongs in a client or command argument. Owner-only
qualification additionally uses `ACTIVITIES_OWNER_DATABASE_URL`; never supply
that secret to the scheduled importer.

1. Merge protected source validation and apply migrations only through the
   repository's authorized backend process. This migration remains review-required
   for hosted application; source merge does not enable that application.
2. Reassess the actual source access/reuse terms and each permitted field. Supply
   a genuinely applicable licence/permission representation; unresolved sources
   remain held. Review source structure and focused/live acceptance for the exact
   parser version. Do not use synthetic fixture licences for real publishers.
3. Owner registers each selected source **publicly disabled**, using its exact
   registry ID/origin/parser and supported kind `event`. For example:

   ```sql
   insert into private.external_activity_sources
    (source_id,display_name,official_origin,supported_kinds,enabled,rights_confirmed,
     radar_collection_enabled,radar_parser_version)
   values ('muse-events','MUSE','https://www.muse.it',array['event'],false,false,
     true,'muse-semantic-v1');
   ```

   This is an explicit owner action, not a seed or an automatically executed upsert.

4. Apply a private collection, inspect held facts, and resolve conflicts/drift.
   Qualification is once per exact parser/policy; it leaves public rights and
   enablement unchanged. The owner runs the qualification command only after
   verifying the supplied actual policy covers the field use:

   ```text
   node scripts/operate-external-activities.mjs --apply --sources muse-events --target <target>
   node scripts/operate-radar-candidates.mjs --inspect --source muse-events --target <target>
   node scripts/operate-radar-candidates.mjs --reject --source muse-events --upstream <id> --revision <digest> --target <target>
   node scripts/operate-radar-candidates.mjs --qualify --source muse-events --parser-version muse-semantic-v1 --policy-url <actual-policy-url> --policy-sha256 <actual-approved-terms-digest> --target <target>
   ```

5. With separate authorization and actual approved attribution/licence, owner
   sets existing `rights_confirmed`, `attribution`, `license_url`, then `enabled`.
   Run apply again; conforming candidates/updates now promote automatically.
   Verify anonymous V4 List/Map/detail and old alias resolution. Do not deploy a
   V4 client to a backend without this migration.
6. Select explicit `ACTIVITIES_SOURCES`, target and importer credentials, then
   separately authorize/enable `ACTIVITIES_IMPORT_ENABLED`. Daily cadence remains
   the default; `ACTIVITIES_REFRESH_POLICY_JSON` still permits whole days, 24–168h.
   Due checks use a successful complete private collection for Radar, public
   success for older connectors. Failures remain due. No per-phone polling exists.

   ```text
   node scripts/operate-external-activities.mjs --apply --due-only --batch-size 4 --sources trento-open-sports-facilities,muse-events,santa-chiara-events,arci-trentino-events,susat-outings --target <target>
   node scripts/operate-external-activities.mjs --maintain --sources muse-events --target <target>
   node scripts/operate-radar-candidates.mjs --maintain --source muse-events --target <target>
   ```

   More than four selected sources requires explicit `--batch-size 4`: at most
   eight sources, two sequential seven-minute batches and a 14-minute total.
   The opt-in workflow has 18 minutes including setup/receipts. One-to-four-source
   runs retain their seven-minute parent. This broadens only the explicit opted-in
   source set; the existing main/owner/target/disabled workflow gates remain.
   Overall `held`, `partial` and `failure` exit nonzero; counts distinguish collected,
   validated, publishable and held. A held collection is never a public integration.

7. Kill a source by disabling `enabled`; withdraw rights/qualification as required.
   To stop traffic also disable `radar_collection_enabled` and remove it from the
   selected schedule set. Maintain expired leases/retention separately. Preserve
   prior canonical identities; late completions cannot re-enable publication.

Deterministic checks and actual local acceptance are separate:

```text
node --test scripts/lib/external-radar.test.mjs scripts/lib/external-activities.test.mjs scripts/lib/external-catalogue.test.mjs scripts/lib/external-multi-source.test.mjs scripts/lib/external-operations.test.mjs
supabase test db --local supabase/tests/165_external_radar.test.sql
PLANETS_DISPOSABLE_QA=1 node scripts/verify-local-external-radar.mjs
PLANETS_DISPOSABLE_QA=1 node scripts/verify-local-external-radar.mjs --live --evidence <new-private-json-path>
flutter test test/features/external_activities/external_radar_test.dart --dart-define=UI_POLISH_CAPTURE_DIR=<absolute-local-directory>
```

`npm run activities:verify:local` runs legacy acceptance and then Radar acceptance
after removing legacy fixtures. Synthetic checks allow the ephemeral CI stack at
its default local ports, following the existing verifier. Human local QA still
requires `PLANETS_DISPOSABLE_QA=1` and a non-default owned stack; all target URLs
must remain loopback. Live publisher fetching is forbidden in CI.

The live command requires a fresh owned non-default disposable backend, imports
real facts privately with all public rights/qualification OFF, repeats the same
extracted revision for idempotence, saves only bounded candidate evidence and
cleans test sources in `finally`. Optional `--source <known-id>` narrows a live
qualification. Synthetic real HTTP/SQL covers public promotion, updates, failures,
aliases, filters/map/cursors, disable and private permissions. Synthetic public
fixtures are not licensed live-source proof. See the [progress/evidence record](radar01-progress.md)
for actual results and remaining activation work. The optional RadarTN exports
were unavailable; no exact row/46-event parity or complete Trento coverage is claimed.
