# SPORTAPI02 — a second official structured activity source

Read [001_context.md](001_context.md). Depends on 002/005; UI/map steps need not wait for this source. External source documentation and real responses are required for provider-specific implementation. The checkpoint below is deliberately source-local.

## Outcome

Prove the infrastructure accepts another genuine official/provider API, ideally yielding useful local sports offerings or places. Use the same canonical kinds and public reads; do not create a score/results feed or a broad unfiltered tourism directory. If there is no verified useful permitted subset, deliver an accurate bounded source assessment and any independently useful verified adapter tests, mark the connector incomplete and continue 010/011.

This is not authorization for indefinite source hunting. Spend at most about **20 minutes on initial source verification** and at most two sensible retries of an unavailable endpoint before recording the limitation. Once a viable source is proven, spend the remaining implementation effort on the adapter and end-to-end proof rather than searching for more providers.

## First candidate: Open Data Hub Content API

Authoritative entry points:

- <https://docs.opendatahub.com/use-data/content-api/reference/>
- <https://docs.opendatahub.com/licensing/>
- <https://tourism.api.opendatahub.com/swagger/index.html>
- <https://tourism.api.opendatahub.com/v1/>

Its published entity families include `ODHActivityPoi` for activities/POIs and `Event`/`EventShort` for dated events. Tags, fields and filtering must be checked against the **current** documentation and actual payload; do not assume a legacy `ODHTag` endpoint or a generic Event API contains courses.

A planning read succeeded at:

```text
https://tourism.api.opendatahub.com/v1/ODHActivityPoi?latitude=46.0748&longitude=11.1217&radius=10000&pagesize=3&pagenumber=1&language=it&fields=Id,Shortname,Detail.it.Title,LicenseInfo,GpsInfo,ODHTags,Source,Active,_Meta
```

Observed envelope: `TotalResults`, `TotalPages`, `CurrentPage`, `PreviousPage`, `NextPage`, `Seed`, `Items`; reported 353 results/118 pages at that moment. **The three returned sample rows were transport stops (`Source=sta`, empty sports tags), not sport listings.** They had `LicenseInfo.License=CC0`, `ClosedData=false`, published latitude/longitude and import metadata. These observations verify accessibility/shape only; they establish neither a useful sports subset nor course coverage. Do not publish these rows as Sports.

The selected-field response returned some dotted field names such as `Detail.it.Title` as literal keys. Inspect the actual selected/full response and normalize consistently rather than assuming a nested object from the field selector. `_Meta.LastUpdate` is not necessarily the organizer's latest content change or availability confirmation.

## Required source checkpoint

1. Establish endpoint/version, supported geospatial filters and units, paging/termination, IDs, publication/active state, localized fields, structured type/tag mapping, information-page URLs and record licence. Use small bounded reads, not a complete unfiltered regional dump.
2. Identify a source-backed **sports-relevant** record subset in Trento or the existing selected area. Do not classify by title keywords alone, import public transport stops/restaurant/weather records, or expand the geography to Bolzano just to produce results. If testing wider geography is useful, label it an explicit separate test and keep it out of Trento publication evidence.
3. Verify the returned subset means a place, a dated participatory/spectator event or a genuine current course. A hiking itinerary/route is not automatically a facility/course; this queue does not add route geometry/navigation/safety/routing features. Exclude unsupported route-only material rather than mislabelling it.
4. Apply a deterministic record-level rights policy from actual `LicenseInfo` and authoritative terms. A documented open CC0/CC BY record with required attribution is sufficient; do not demand individual written permission by default. Exclude closed/proprietary/unknown records, and do not extend record licence to images/attachments. Conflicting licence/publication fields are explicit rejects.
5. Verify canonical official information links and their source-specific origin allowlist. No invented organizer page, booking link or unsafe URL. A documented dataset-level source link is acceptable with the correct label if no specific page exists.
6. Record actual eligible counts/sample IDs and limits honestly. A successful empty, correct filtered request is evidence of no current matches in that scope, not an API failure; a malformed or unsupported filter is not evidence of no sport coverage.

If this candidate fails for coverage/rights/access, you may check at most **two other clearly published official JSON API candidates** already identified in authoritative local/provider documentation. Do not guess municipal endpoints, register accounts, purchase data or switch to scraping/ICS/PDF/social automation. Agenda Trento's current event-text checkpoint remains unresolved unless genuinely new authoritative evidence exists; do not repeat the placeholder-terms investigation. No external messages are authorized.

## Adapter if the checkpoint passes

Use the 005 registry/transport and 002 canonical validation. Implement one connector with a source-scoped coverage/filter contract and code-owned destinations. Bound pages/requests/bytes/runtime, validate pagination destinations, and handle rate limits/retries and incomplete traversals without wiping existing data.

Preserve upstream IDs as source-scoped identities, explicit source timestamps and per-record licences/attribution where required. Exclude contact-rich/private fields and media. Unknown schedule/price/eligibility stays unknown; calculate recurrence only from 002-supported explicit structured rules. Do not use AI or descriptions to infer a course, session dates or opening hours. Provider shape/capabilities must not leak into arbitrary UI conditionals.

Import into an isolated local catalogue with independent owner-approved local source metadata, then verify anonymous list/detail, Sports rendering, repeat/no-duplicate updates and geography when the source supplies permitted geometry. Source disable removes only this source, leaving 006 readable. No hosted activation.

## Validation, partial work and completion

Normal tests use deterministic synthetic API envelopes matching the verified source, not live traffic. Cover paging, empty/malformed/truncated responses, unknown tags, licence exclusions, inactive/deleted status, missing optional fields, dotted/nested field handling, unsafe links, geometry precision, overlapping dates/season and stable identity. Include tests excluding transport stops/unsupported route-only records.

Run affected tooling/database/HTTP/mobile checks and required CI. Update the source evidence/runbook, progress and any actual public contract changes. Merge useful completed work through a focused PR. If only verification is possible, say **source verified but connector not implemented**, **no eligible local coverage**, or **blocked**, as appropriate; do not count a documentation PR or always-empty adapter as a working second integration. Continue 010 without waiting for the founder.
