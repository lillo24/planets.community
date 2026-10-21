# PLANETS ACTAPI01 — Official-API Activities MVP

## Outcome

Build the smallest complete path from **one official Trento event API** to real, read-only listings in the existing Activities screen:

`official API → bounded scheduled importer → canonical PostgreSQL catalogue → public read API → Flutter Activities`

Keep Activities Split Mode opt-in and OFF by default. Native Projects, Tavoli, participation, chats, and Scambio-Dona retain their existing contracts. This is one focused implementation PR, with a source-verification checkpoint before source-specific code. Work through the backend and UI in order; do not build a generic aggregation platform.

The user explicitly deferred their phone/UI review until later. Continue implementation and automated validation without waiting for that review. Report native QA limitations accurately.

## Current repository evidence

Inspected 2026-10-21: `lillo24/planets.community`, `main` at `8a6847a075a062d441cb4297f056c2f03295e907`. ACTSPLIT01 / PR #269 is already merged. **Start from latest main at execution time**, retaining subsequent work.

Verified areas:

- `docs/development/actsplit01-activities-sandbox.md`: device-local opt-in mode, `/activities`, 12 fictional examples, native Tavoli entry, baseline tutorial isolation, no existing ingestion service.
- `apps/mobile/lib/features/activities_sandbox/README.md` and `presentation/activities_screen.dart`: example-only in-memory filtering; categories and disciplines come from fixtures; real Tavoli is a separate entry. Do not mistake fixture taxonomy or models for a production catalogue.
- `apps/mobile/lib/features/settings/` owns `planets.sandbox.activitiesSplit` and restoration. `apps/mobile/lib/app/router/` owns the stable Browse branch and experiment gates.
- `supabase/functions/README.md`: existing provider integrations separate pure provider/handler code from runtime transports; canonical authorization and durable state live in PostgreSQL.
- `scripts/README.md` and root `package.json`: repository-owned Node ESM scripts, Node 24, `node --test` tooling tests, disposable local database verification, generated public database types, and change-scoped CI.
- `AGENTS.md` and `docs/architecture/system-design.md`: one canonical Supabase/PostgreSQL backend; portability to self-hosting; no client service-role credentials. Some architecture status prose is historical: actual code/migrations/tests win for implemented behavior.

Read current root/nested instructions, `implementation_plan_sections_suggestions.md`, architecture, migration/security conventions, affected Flutter controllers, workflow rules, and current manifests before editing. Exact new file/class/RPC names are implementation choices; the paths above are inspected ownership pointers, not a mandatory edit list.

## Scope decisions

**Now:** one official API connector, validated normalization, idempotent storage, public paginated reads, an opt-in daily refresh runner, and integration with the existing Activities UI.

**Not now:** scraping, browser automation, AI/search/extraction/translation, the thesis crawler, ICS/PDF/HTML-page ingestion, organizer submissions, bookings, payments, native joins/chats for imported items, new maps/geocoding, imported images, a source-admin dashboard, fuzzy cross-source deduplication, or a generic plugin/queue framework. HTML-valued fields returned inside the official JSON may be safely converted to plain text; that is not permission to fetch HTML pages as an ingestion fallback.

The first source is a calendar, not a verified directory of every sports course in Trento. Preserve this limitation. Do not pad Sports with fixtures or reclassify unrelated events to make it look populated.

## Required external context and source checkpoint

**Codex needs network access to official API/provider documentation and real API responses. No uploaded archive, Google Doc, crawler repository, or design export is required.** Hosted credentials and deployment are not assumed.

Preferred source: **Agenda Trento / Comune di Trento's OpenContent API**.

An earlier discussion confused two products called OpenAgenda. The municipal site's footer links to OpenContent and its GitLab project. **Do not implement `api.openagenda.com`, invent an agenda UID, or ask the founder for a French OpenAgenda account on that basis.**

Primary research entry points:

- https://eventi.comune.trento.it/ — footer identifies OpenContent's OpenAgenda; public category controls include sports/cultural event types.
- https://gitlab.com/opencontent/openagenda — provider source/description states that events and association profiles are available as open data via APIs.
- https://manuale.opencontent.it/opencity/gestione-dei-contenuti-1/gestione-avanzata-dei-contenuti/integrazioni-openagenda — official external-calendar/OpenContent integration documentation.
- https://github.com/OpencontentCoop/ocopendata — provider API implementation/reference to inspect as needed.
- https://github.com/OpencontentCoop/opendata_client — provider sample client repository; not proof of the current municipal payload.
- https://www.comune.trento.it/Note-legali — municipal website's default CC BY 4.0 terms, with explicit exceptions. Do not automatically extend these terms to every third-party item, image, or separate portal.

**Evidence limit:** planning verified the provider identity and documentation, but could not retrieve a successful live municipal API response or the event portal's linked terms from the research environment. No exact endpoint, authentication requirement, response field mapping, rate limit, or current event count is certified by this plan. An inaccessible research-tool request is not proof the API is down.

Before coding the provider-specific parser:

1. Establish the currently supported official endpoint from official documentation/provider code or the portal's published API references. The OpenContent `/api/opendata/v2/` family is a research lead, not a verified deployment contract. Do not depend on a private/undocumented UI-only endpoint.
2. Make a small, read-only request. Verify stable identifiers, JSON envelope, pagination/termination, detail resolution, locale, public publication status, event timing, categories, and source-page URLs. Verify current/upcoming filtering with genuine records when available; distinguish a legitimate empty calendar from a failed request. Do not widen geography or dates silently to manufacture results.
3. Establish the applicable reuse terms, attribution, permitted storage and access conditions. Exclude records with contrary restrictions. Images, logos and attachments remain out of scope even when text reuse is permitted.
4. Record the exact reproducible request, verification date, small redacted payload shape, field mapping, limits and rights references in a concise repository contract/runbook. Persist only minimal, scrubbed test examples; do not commit secrets or personal contact details.

A documented API on the main municipal domain serving the same official Trento calendar is an acceptable source choice if verified. Do not silently substitute Open Data Hub, another geography, or another aggregator. If no supported endpoint, required credentials, or reuse permission can be established, stop the source-dependent work and report that exact blocker. Provider-independent scaffolding/tests may proceed, but do not invent a parser, enable publication, or report real integration as complete.

## Importer and refresh

Use a small repository-owned single-run Node ESM importer consistent with existing tooling. Keep transport, source normalization and database persistence independently testable. A source identifier and connector boundary are enough; no adapter framework is required.

Provide documented dry-run and explicit apply modes. Dry-run fetches/validates and reports counts without catalogue mutations. Apply requires an explicit configured target; missing configuration is an error, never an implicit production destination. Initial mutating verification uses a disposable local stack.

Conservative defaults: one source; refresh daily once activated; a rolling 90-day upcoming/ongoing discovery window. Query overlaps correctly: an ongoing event can start before today. Record any source-imposed limits and how incomplete windows are surfaced.

Bound request time, response bytes, pages, records, related-record lookups and total run duration. Respect documented rate limits/Retry-After with capped retries. Use conditional requests where supported. Only call allowlisted official HTTPS API origins; validate pagination/detail links and redirects before fetching. Do not let payloads or clients choose arbitrary fetch destinations.

Normalize strictly. Missing optional data remains unknown. Invalid records produce explicit safe rejection reasons; malformed envelopes, failed pages, pagination loops or safety-limit exhaustion make the run incomplete/failed. Never turn an upstream error into a successful empty snapshot.

Persist by unique `(source_id, upstream_id)` identity. Re-runs update rather than duplicate; unchanged content does not receive fabricated source-modification dates. Replace a record's validated occurrence set atomically. A failed run must not erase the previous valid catalogue or advance a completeness checkpoint. Use a source-scoped lock/lease and reject obsolete completions so concurrent runs cannot overwrite newer state.

Honor explicit upstream cancellation/unpublication where the documented API exposes it. Absence from a partial page or moving date window is not a cancellation or a deletion. No destructive absence reconciliation in this first version. Track per-record last-seen separately from source-wide last-success so missing records do not appear freshly verified.

Use small, documented freshness defaults: mark records stale after 72 hours without re-observation; hide them from ordinary discovery after 14 days without re-observation, even if an old end date is still in the future. Date-expired records leave upcoming discovery independently. If legitimate conditional responses prove unchanged content, they may refresh observation time. Keep time injectable in tests. These are product freshness rules, not claims about upstream verification or available places.

Keep compact private run records: source, start/end, success/incomplete/failure, fetched/accepted/rejected/changed counts and sanitized error codes. Bound retention, for example 30 days. No permanent raw-response archive or personal-data-rich logs.

### Scheduling without a new service

Expose the same runner for manual execution and a small GitHub Actions daily/dispatch workflow, or reuse an existing equivalent scheduler if current repository evidence supports one. The CLI must remain runnable from ordinary cron for portability.

Ship scheduling **disabled by default** behind explicit configuration. Use minimal workflow permissions, bounded runtime, per-target concurrency and server-only secrets; never expose credentials to PR/fork jobs. Document exact owner setup and disable steps. Do not provision a host, purchase a service, enable a hosted schedule, write secrets, or perform a hosted import as part of this task. Missing credentials or disabled operation must be distinguishable from a successful import. Report deployment/activation separately from code completion.

## Canonical data and public read contract

Create an additive external-activity domain, separate from native Proposal/Tavolo tables and identities. Keep the schema small; code-owned source configuration plus minimal source/run metadata is sufficient.

Represent the information needed to render and filter:

- Internal stable ID, source ID/name, upstream ID, canonical official page URL and attribution/license reference.
- Source-language title and plain-text description; optional organizer display name, cost/audience text, city and public venue/address. No fake organizer account. Omit structured personal contact fields, images and attachments.
- Explicit event occurrences/schedule information, timezone and date-only/all-day semantics, optional explicit cancelled status. Model multiple occurrences without pretending an event runs continuously between its first and last session. Unknown recurrence stays unknown; do not derive weekly classes from prose.
- Canonical categories (`sports`, `culture`, unclassified/other as needed), original source categories, and an optional discipline only when supported by an explicit structured mapping. These are not competence IDs.
- Upstream-modified time when supplied, per-record last observed time, normalized-content revision/hash, and applicable source-health/freshness metadata.

Choose occurrence storage after seeing the payload; it must support correct upcoming filtering and stable ordering. Preserve timezone offsets and test Europe/Rome daylight-saving boundaries. A date-only value must not become a claimed midnight appointment. Interpret all-day end semantics only according to the source contract.

Use deterministic category mappings from verified source fields. A cultural exhibition about sport is not automatically a participatory sports session. Keep original type/audience context and do not imply spectators can enroll. Unknown price is not free; absent registration/availability is not open admission.

Provide a narrow public list/detail contract with server-side category/query filtering, bounded pagination and deterministic ordering by actual next occurrence plus stable ID. Do not filter only the first downloaded page. Scope query state/cursors to the complete filter and a consistent time reference; reset safely on refresh/filter changes. Derive discipline options from catalogue metadata, not the visible page or fictional fixtures; omit the discipline selector when no reliable source taxonomy exists.

Anonymous and authenticated users can read only licensed, publishable, sanitized records from an enabled source. All importer writes, source configuration and run diagnostics are server-only. Add explicit grants/RLS, protect private state, and revoke inappropriate default function execution. An app preference is not authorization. Preserve a server-side source disable/unpublish mechanism without requiring a new admin UI.

Use canonical migrations, generated types and existing database verification conventions. Do not rewrite historical migrations, broaden existing native authorization, or put a service-role key in Flutter. Document the public payload and source states, including unconfigured, never synchronized, healthy, empty, stale and unavailable.

## Flutter integration

Under the existing enabled Activities Split Mode:

- Make the main external catalogue show real imported records from PLANETS' backend. The device never contacts the provider or starts an import. Pull-to-refresh refreshes backend reads only.
- Preserve All/Sports/Culture and the separate native Tavoli entry under All/Culture. Search applies to external listings, not native Tavoli; label its scope accurately. Native Tavoli loading, errors, creation, join and map behavior remain untouched.
- Keep the 12 examples accessible only through an explicit, clearly labelled example-preview action/route, with their own filters. Never mix them into real results or use them as fallback for an empty, unconfigured or failing API. Existing example detail routes remain truthful.
- Use the current card/detail design and page-app-bar conventions. Show title, source-provided schedule, venue/city and an understated source label. The real detail has attribution, last fetched information with correct wording, and **View official event / Vedi evento sul sito ufficiale** through the app's safe external-link boundary.
- Treat source URLs as untrusted: allow safe public HTTP(S) destinations according to current app policy, reject unsafe schemes/credentials and do not render arbitrary source HTML. Do not open native actions from imported IDs.
- No imported-item Join, chat, participant count, creator profile, availability badge, purchase, native report/submission or fake success actions. Do not invent a partnership or municipal endorsement of PLANETS.
- Distinguish loading, successful empty results, import not configured, backend read error and retained-but-stale data. A failed client read is not “no activities”; source-wide success alone must not mask stale individual records. Do not claim complete Trento coverage.
- Preserve local filters/scroll when returning from a detail. Turning the mode OFF restores the prior navigation and gates experiment routes, without changing stored catalogue records or native flows. Do not initiate new catalogue reads from inactive/off surfaces.

Localize UI in Italian/English. Source content can remain in its supplied language; no AI translation. Keep narrow-screen/large-text accessibility and the unchanged baseline tutorial. Do not add external-content maps or network image fetching in this pass.

## Validation and completion

Use deterministic synthetic/scrubbed provider-shaped fixtures for normal CI; routine tests must not depend on municipal API availability.

Required evidence:

1. Parser/transport tests: verified envelope and fields, optional/missing content, invalid URLs, categories, pagination boundaries, rate limits, malformed pages, all-day and multiple occurrences, timezone/DST, explicit cancellation and unknown availability.
2. Disposable local database tests: anonymous/public projection, denied client writes/private access, idempotent repeat, changed-record update, concurrent runs, failure without catalogue loss, per-record staleness/expiry, filter paging and source disable. Confirm no native records or permissions change. Generate database types rather than editing generated output.
3. Flutter tests: real records/filters/detail/source links, honest empty/error/unconfigured/stale states, explicit separate examples, no fixture/native mutations, off-mode gating and existing Settings/router/tutorial/Tavoli regression coverage. Run formatting, analysis, affected database/tooling/mobile checks and required CI; root/tooling changes need appropriate broader validation.
4. An opt-in, bounded end-to-end source check after the source checkpoint passes: fetch real permitted data, import into an isolated local catalogue, read via the anonymous contract, render at least one actual record when available, then repeat and demonstrate stable identity/no duplicates. Record what was genuinely observed. If live data or source access is unavailable, report that as an unverified/blocking integration result, not a passing live test.

Capture actual rendered list/detail states when the environment supports it. Phone review may wait as requested; automated validation still runs. Physical Android commands must target `48091FDAS0041A`. Widget screenshots are not native Android/iOS evidence. Do not let the previously broken emulator drive unrelated runtime changes.

Update the relevant feature maps and a short source/import/read-contract runbook with activation, freshness, rights, commands, schedule disable, and rollback. No production deployment, app-store release, hosted migration or schedule activation is authorized by this plan.

Follow current AGENTS workflow: isolated task branch/worktree, focused PR into latest main, required checks, normal merge and cleanup. Direct-main authorization applies only to publishing this plan file, not implementation code. Respect any cleanup block rather than bypassing it.

Report: PR/merge commit; verified source and exact API; imported/visible counts and coverage limits; what is implemented versus locally exercised versus hosted-active; commands/results; migration/security impact; remaining setup; and any source/rights/schema issue that blocks calling the pipeline complete. A future scraping/AI plan is not part of this delivery.
