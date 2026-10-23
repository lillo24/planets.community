# PLANETS RADAR01 — automatic discovery of local activities

**Implementation handoff for Codex. Finish the complete feature in one cumulative integration branch/PR.**

## Outcome and authorized scope

Extend PLANETS' existing Activities catalogue into a maintained local radar for **music and concerts, theatre/cinema, talks, workshops, social/nightlife activities, exhibitions and organized outings**, alongside the existing Sports offering. The objective is a catalogue of the same *kind* as RadarTN, populated from actual publishers and organizers, rather than another static demo or another facilities-only integration.

The founder now explicitly reopens the older **API-only / no HTML collection** restriction for this task: implement bounded collection from relevant public organizer/publisher websites as well as published APIs, RSS/Atom and iCalendar. Source access and reuse conditions still apply independently. Do not infer RadarTN's collection method from its label, scrape its database as PLANETS' feed, or treat attribution as permission.

A normal successful cycle is:

`approved sources → bounded collection → evidence-backed candidates → validation/deduplication → canonical catalogue → existing Activities List/Map/details → scheduled updates`

**Source and extractor qualification happens once per version/policy. Valid records and harmless updates from qualified sources then proceed automatically.** Human review is for ambiguity, conflicts or material source/parser changes, not mandatory approval of every event forever.

This is implementation work, including working real-source collectors, local end-to-end proof, tests, documentation, protected CI and normal source merge. Source registration/publication on shared environments, enabling hosted schedules, paid services and public app/store deployment remain separate activation actions. Prepare those actions concretely; do not claim them executed.

## Execute continuously

1. Fetch current main and inspect root/applicable `AGENTS.md`, current Activities contracts, active branches and progress before editing. Preserve concurrent work.
2. Use one isolated cumulative branch/worktree and focused main-targeted PR for this task. Logical stages below depend on **implemented and validated code on that branch**, not intermediate merges. This task overrides per-stage/per-document merge waits within RADAR01 only.
3. Implement each stage, run its relevant checks, checkpoint progress, and immediately continue. Fix routine parser, test, build and integration failures yourself.
4. Source-specific denial or unresolved reuse must block only the affected source/action. Finish other collectors, shared infrastructure, UI and QA. Never turn a source failure into a healthy empty feed.
5. Reconcile latest main, fix required CI failures, and merge when genuinely green under the repository's current policy. Do not redesign release safety policy, weaken tests or bypass branch protection. Current policy, rather than old owner-fingerprint instructions, determines source merge and hosted eligibility.
6. If execution ends, save an exact checkpoint in a scoped development progress file with branch/PR, completed stages, actual checks and next command. A checkpoint is not completion.

## Repository evidence — starting point, not a pinned checkout

Inspected main commit `fef1c343501a43712f997aca269a09ca6f245b75` on 2026-10-23; reread latest code. Activities/Sports PR #298 is merged at `67eee7b402986266116d92d4efe5d8fc690f3a7b`. It already implements:

- Canonical external `event`, finite-term `course` and undated `place` records; stable `(source_id, upstream_id)` identities; V1/V2 compatibility and V3 public geographic reads.
- Actual Flutter Activities/Sports list, details, query/kind/discipline/date/area filters, List/Map synchronization, provenance and official-link sharing.
- Code-owned connector resolution, bounded transport, atomic leased imports, independent source rights/enable gates, freshness/expiry, partial health, private inspection/maintenance and disabled-by-default scheduled refresh.
- One working real source: Trento's licensed municipal sports-equipment CSV. Agenda Trento is rights-blocked; the assessed ODH sports subset has no verified useful local coverage.
- Existing ACTMET01 hooks with production analytics denied. Preserve those controls.
- Co-Creation's explicit Find company handoff from eligible external event details. Do not introduce imported-event memberships, booking, organizers or chats.

Missing: general website/feed collectors, diverse working activity sources, durable candidate/evidence processing where needed, cross-source duplicate handling and useful non-sports type discovery.

Likely ownership areas, verified at inspection:

- `scripts/lib/external-activities/{connectors,transport,records,catalogue,importer,operations}.mjs` and their README.
- `scripts/import-external-activities.mjs`, `scripts/operate-external-activities.mjs`, guarded local verifiers, `.github/workflows/external-activities.yml`.
- `apps/mobile/lib/features/external_activities/`, shared public external-link and geographic infrastructure.
- `docs/development/{activities-sources,activities-operations,activities-map,actcat02-catalogue-contract,activity-interest-metrics}.md`.
- Canonical migrations/generated database types, SQL/HTTP contracts, existing tooling and Flutter tests.

The current broad category contract is `sports | culture | other`; it is not a detailed activity taxonomy. Current transport accepts JSON and narrowly declared CSV/text MIME; merely passing HTML/XML to that parser is not an implementation.

## External inputs and the missing RadarTN attachment

**Required:** internet access to the actual official sources, their access/reuse information and successful responses. If required evidence is inaccessible, stop that source-dependent operation and report the exact reason; do not invent selectors, endpoints or permissions. Continue independent work.

**Optional benchmark inputs:** `radartn_events_2026-10-21_to_2026-10-27.csv`, its `(1)` copy, and `radartn_export_fixed.zip`. These failed to materialize in the planning conversation and were **not inspected in this pass**. Do not assume that these files exist in Codex's checkout or claim to have compared their rows. If the founder supplies them, use a private, explicit local input path. If absent, mark exact CSV comparison unavailable and continue the implementation.

Earlier conversation reported 46 rows for October 21–27 and no original source URLs; this is historical, unverified benchmark context, not a fresh file audit, required output count or production seed. Never invent the missing source links.

RadarTN's publicly loaded frontend was inspected: `originalSourceHandle || "Canale ufficiale"` supplies its fallback label; a separate source URL points to Instagram or a website. This proves provenance presentation, not scraping, AI or an official API. The desired equivalent is **useful listings with real primary-source evidence**, not copying that generic verification-like label.

No private Google Doc, prior browser session, thesis crawler, uploaded volunteer-law PDFs or RadarTN account is required. The Google Doc was consulted as product context; this handoff contains all required decisions.

## Initial source shortlist — verify, implement, record outcomes

These are **collection candidates**, not blanket public-republication approvals. Use their own published feeds/structured interfaces first, then permitted website extraction. Reconfirm current behavior and event relevance.

| Publisher / activity families | Official starting points | Evidence established in planning |
| --- | --- | --- |
| **MUSE** — science, workshops, talks, exhibitions and family activities | <https://www.muse.it/calendario-eventi/>; advertised API root <https://www.muse.it/wp-json/> | Root schema advertises GET `/wp/v2/events`. A real three-row GET succeeded; WordPress headers reported 655 historical event posts, **not 655 current Trento activities**. `date`/`modified` are publication metadata, not occurrence times. Other MUSE venues include locations outside Trento. |
| **Centro Servizi Culturali Santa Chiara** — concerts, theatre, cinema and dance | <https://www.centrosantachiara.it/>; official linked box office <https://ticket.centrosantachiara.it/list/events?lang=it> | Public calendar visibly provides multiple dates/venues and both free/ticketed items. One direct robots request returned 403; worker access/reuse remains to qualify. Do not bypass a denial. Prefer organizer pages to box-office internals. |
| **UniTrento** — talks, seminars and workshops | <https://eventi.unitn.it/it>; <https://www.unitn.it/it/note-legali> | Public server-rendered listings and filters exist. University legal notices restrict default reuse to personal/noncommercial purposes absent other terms/permission. Do not assume PLANETS or third-party event material qualifies; resolve applicable scope or leave publication held. |
| **Trento Giovani** — community activities, creative workshops and social events | <https://trentogiovani.it/Novita/Eventi>; <https://trentogiovani.it/Note-legali> | Real HTML listings link to individual events. Public legal notices do not establish a blanket open licence. Some seasons/pages are historical. Use actual page-level evidence, not a municipal-name assumption. |
| **ARCI del Trentino / participating local circles** — music, cinema, workshops, games and social events | <https://arcideltrentino.it/>; observed programme <https://arcideltrentino.it/programmazione-circoli-arci-e-feste-di-tesseramento-2027/> | Official programme contains multiple activities and venues. Its title/year and publication/event dates require careful interpretation; membership/registration conditions differ. This is a candidate to qualify, not a certified current feed. |
| **SUSAT** — organized excursions and occasional courses | <https://www.susat.it/>; <https://www.susat.it/feed/> | Actual RSS returned 200 XML with the October 25 Cima Portule outing already mentioned in the RadarTN discussion. The RSS publication date is October 19; the outing date is October 25. Feed presence does not settle republication rights. Destination and Trento departure point are distinct. |

Target **at least three working non-sports publisher collectors** across multiple activity families, plus a feed collector such as SUSAT when permitted. Start with this shortlist; if candidates are unusable, perform bounded discovery of at most four relevant local primary publishers to replace them. Do not spend the whole assignment hunting sources or repeatedly retrying blocked hosts. Implement source-independent adapters using synthetic fixtures while qualifying accessible sources.

Report collected, validated, publishable, held and failed separately. A working candidate collector can be delivered when publication remains held, but must not be described as a live public integration. Do not substitute transport POIs, old seasons, sports facilities or invented records to meet the target. If the minimum genuinely cannot be met, implement every eligible part and name the exact shortfall.

## Stage A — bounded collectors that produce real candidates

Extend the existing Node worker/import boundary; do not add a separate public database or ingestion platform.

- Add reusable support for RSS/Atom, bounded iCalendar, schema.org Event JSON-LD, and source-specific semantic HTML extraction. Use source-specific recipes after inspecting real response structure, not one giant regex or an AI-only universal scraper.
- Prefer declared APIs/feeds. Discover interfaces through publisher links/schema/documentation; do not invent undocumented endpoints. Use source-specific detail requests when listing data is insufficient.
- A source registry owns source ID, publisher relationship, exact permitted origins/paths, transport kinds, parser version, coverage, access policy, rights state and supported fields. Feed content must not choose arbitrary URLs, modules or policies.
- Extend the existing transport deliberately for HTML/XML/calendar MIME, streamed/decompressed size limits, encoding, timeouts, traversal, redirects and safe URL/DNS handling. Retain current source and run budgets; do not create unlimited fallbacks. XML must disable external entities/DTD/network expansion. JSON-LD must not fetch remote contexts or execute scripts.
- Enforce robots/access restrictions, source delays, bounded concurrency and Retry-After. A 403, login wall, CAPTCHA or explicit denial is a source blocker; do not use proxies, token borrowing or browser impersonation to evade it. A browser renderer is justified only by a permitted page's JS requirement, with the same network/resource bounds.
- Keep conditional requests/content hashes and extractor versions so unchanged material can reuse a validated revision. A 304 may confirm only the exact representation covered by its validators; it must not refresh unfetched detail pages or an incomplete source traversal.
- Preserve the distinction between page fetch time, source modification time, event time and last successful complete observation.
- Parse one programme into several events when explicit source structure supports it. Keep distinct performances, cities and showtimes. A title or publication month alone cannot identify an occurrence.
- No paid model/OCR service is needed for the initial scope. Ambiguous prose, image-only flyers or inaccessible attachments become explicit held candidates. Do not fabricate schedule fields or quietly add a recurring paid extraction dependency.

Actually run the eligible collectors locally against real sources. Commit small synthetic/minimal fixtures for deterministic tests; do not commit complete publisher pages, personal contacts, unlicensed descriptions or RadarTN exports.

## Stage B — evidence, validation and safe automatic publication

Use the canonical backend and existing private-write boundaries for durable job/candidate state where needed. Choose minimal additive contracts after inspecting the implementation.

Each candidate/revision needs a stable upstream identity, actual publisher/source URL, retrieval/parser version, content digest, extracted facts with field evidence/locators, relevant date/area, validation result and explicit reasons for withholding. Keep only necessary bounded evidence; avoid indefinite full-page/caption storage and raw personal-contact logs. Document a bounded retention/maintenance policy.

Separate **collection/access approval**, **field reuse policy**, **parser qualification**, and **public enablement**. Preserve the owner's source configuration authority; the importer must not approve its own rights. Once a source/policy/parser is qualified, automatically accept conforming new records and updates. Send only conflicts/drift/ambiguity to private review, with a small inspect/review CLI reusing existing authority patterns; no incidental admin portal.

- Public facts: title, explicit dates/times/timezone, venue/locality, activity type, stated cost/audience/access and official event link. Missing values stay null. Descriptive prose and images have separate reuse requirements; omit them when not cleared.
- The distinction between facts and creative wording does not itself clear contractual or systematic database extraction restrictions. Record actual applicable source policy; do not treat a source link, RSS, JSON-LD, robots allowance or public API as blanket permission. Do not demand fresh written permission where a clearly applicable licence already resolves the actual use.
- Keep Agenda Trento's unresolved checkpoint. Do not route the same blocked material through HTML and call the checkpoint resolved. A different primary source gets its own assessment.
- Preserve canonical source licence/provenance contracts. Never populate `license_url` with an unrelated CC link or set `rights_confirmed` merely to make a parser/client happy. Any necessary broader permission-basis representation must be additive, reviewed and backwards compatible.
- Distinguish cancellations from missing records, temporary failures, incomplete pagination and successful empty windows. Do not delete or refresh old observations after a failed/partial traversal. Complete absence alone is not proof of cancellation.
- Course terms, all-day/date-only events, exhibitions spanning days, explicit eligibility and booking requirements retain their source meaning. Do not turn an exhibition interval into a promise that it is open every hour or a weekly class into hundreds of separate cards.
- Handle Europe/Rome and explicit source timezones, season year rollover, DST, recurrence bounds and exceptions. Preserve publication dates separately; never use RSS `pubDate` or WordPress `date` as the event's date.
- Keep meeting point/departure and destination separate for outings. Local departure can support a relevant list entry, but must not produce a map pin that falsely places the actual activity in Trento.
- Only source-published public coordinates or an independently qualified public venue record may supply geometry. No private native coordinates, guessed city-centre venue pins, new GPS permission or paid geocoding.

### Deduplicate without destroying identities

Retain stable `(source_id, upstream_id)` UUIDs and existing deep links through revisions. Updates must not create new cards because a title changed.

Add narrowly supported cross-source duplicate/alias handling: explicit same organizer event ID, canonical official event URL or equivalent strong evidence first. Show one discoverable event with its supported occurrences and retained provenance where identity is proven. Preserve resolution for existing aliases/links and known source corrections. Different showtimes, venues, course terms and same-title events are not automatically duplicates.

Ambiguous matches remain private review suggestions; do not fuzzy-merge them or silently overwrite conflicting time/place facts. An apparent duplicate source must not extend the freshness of an unobserved authoritative source. Correctness takes priority over claiming a perfect deduplication rate.

## Stage C — Radar discovery, operations and complete local acceptance

Reuse current Activities screens, map, pagination, official-link sharing and Find company delegation. This pass adds needed non-sports coverage and discovery, not another parallel app or a full redesign.

- Add a compact source-backed **activity-type** facet/filter covering the families actually ingested, e.g. Music, Theatre/Cinema, Talks, Workshops, Social/Nightlife, Exhibitions and Outings. Keep broad categories and sports discipline behavior compatible. Do not overload sports discipline with unrelated labels or fabricate populated filters.
- Use one server-owned filter contract for List/Map and facets before pagination. Add/version contracts only as necessary; preserve existing installed V1/V2/V3 consumers and filter-bound cursors. Missing geometry remains discoverable in the unscoped List.
- Offer useful day/date discovery through current controls; verify Today / Weekend / chosen dates or equivalent simple access. Do not add a separate community-meeting calendar or confuse external events with Co-Creation meetings.
- Source copy names the real publisher, e.g. **Fonte: MUSE**, with a valid relevant link. Use an official-source indication only when the registry establishes the relationship. Never use a generic "Canale ufficiale" fallback as a verification claim.
- Show known price/access/membership restrictions and honest unknowns. Keep read-only imported details and existing explicit external participation actions; no automatic PLANETS admission or crowding predictions.
- Preserve no-provider map behavior, public cache/attribution/budget ownership, opt-in experiment boundaries, account/Mock fencing and denied analytics. A source-based event label must not become a political endorsement.
- Reuse the existing refresh/maintenance CLI and disabled workflow. Schedule approved sources automatically when configured; daily is the initial default, with source-specific due cadence, independent failures, source kill switches and recoverable leases.
- The current operator supports up to four selected sources per run and a seven-minute parent bound. If the qualified registry exceeds that, implement explicit bounded batches with a target-wide outcome and documented total budget; do not drop sources or silently remove limits.
- No external fetching from individual phone requests. No per-user crawler or background polling in Flutter.
- Provide reproducible dry-run, local apply, inspection, review/qualification, publication gating, scheduled due-run and disable/recovery instructions. Hosted secrets, source flags and schedules stay unchanged until separately activated.

### Real acceptance, then protected delivery

Use an owned non-default disposable local backend and meaningful real HTTP/SQL checks where contracts change. Preserve unrelated user/peer services. Run focused checks after each stage, then the repository's required checks once against the integrated result.

Prove:

1. Multiple real source collectors extract distinct useful activity families; publishability and held-source reasons are explicit.
2. Repeat imports preserve IDs and create no duplicates; changed title/time updates the existing item, and incomplete/failed runs preserve prior valid data.
3. Source disable and rights withdrawal deny public list/detail/map and in-flight promotion; private candidates/evidence are inaccessible to ordinary clients.
4. Source conflicts, malformed XML/HTML, external entities/unsafe links, redirects, over-budget responses, date-only events, publication-versus-event dates, DST/season rollover, recurring exceptions and same-title separate performances behave correctly.
5. Exact duplicate aliases deduplicate while distinct dates/venues stay distinct; signed paging, facets and list/map agreement survive filtering and source updates.
6. Real local canonical List/Map/details show qualified non-sports records when rights permit. If a real source is publication-held, show its actual private candidate result separately; synthetic public fixtures test UI but cannot count as licensed live-source proof.
7. Render and inspect IT/EN, 320/360dp and large text, source attribution, empty/error/partial/stale states, missing geometry and social/outdoor access restrictions. Use existing mobile and debug-build verification. Physical-device unavailability does not halt coding or justify a false device-QA claim.

If the RadarTN CSV becomes available, privately compare the same explicit date window: occurrence-level matches, activity-family coverage, missing organizers/sources and unresolved rows. Verify file contents/header/count first. The historical window cannot be compared to today's changing catalogue as if they were the same snapshot. No invented exact "46/46" parity. A benchmark miss may mean absent sources or now-removed historical pages, not necessarily a parser defect.

Final evidence should distinguish fetched pages, parsed candidates, public-eligible records, withheld/failed records, duplicates and updates by source, family and relevant date. Do not log raw bodies or credentials. Update nearest source/operations/feature docs and a concise progress record.

Finish source implementation, CI and merge rather than handing back another plan after the first adapter. Report one concise final handoff with actual collectors, categories, source publication states, real-versus-synthetic evidence, PR/merge, failed/unrun checks and a consolidated exact activation list. **No claim of full RadarTN parity, complete Trento coverage, hosted import, enabled scheduler or public release without evidence.**
