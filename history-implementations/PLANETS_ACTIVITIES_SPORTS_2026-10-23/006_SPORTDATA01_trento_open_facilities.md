# SPORTDATA01 — real public sports places from Comune di Trento

Read [001_context.md](001_context.md). Depends on 002/005. This source requires external network access. If authoritative source access fails, stop the source-dependent part, record the missing evidence and continue 007 onward; do not substitute fake records or HTML scraping.

## Outcome

Implement and locally exercise a real official-data adapter for public sports facilities/equipment in municipal green areas. Show these as **Places to practise** in Sports and supply their published geometry for the map. This is a directory of places/equipment, not a sports-course/event API or booking integration.

## Verified source and exact observations

- Official metadata/licence page: <https://www.comune.trento.it/Amministrazione/Documenti-e-dati/Dataset/Impianti-sportivi-ad-accesso-libero>
- Its linked machine-readable resource: <https://www.comune.trento.it/customexport/dataset-csv_resource-46671>
- Planning observed explicit **CC BY 4.0** on the dataset page and successfully downloaded **27,085 bytes** of UTF-8 comma-delimited CSV. SHA-256 of that point-in-time download: `d3e12a39b0d12712f9b83d0c3ac7485603c34754d5b4b394270a94b27e6aab34`.
- Header: `Item,Tipo di impianto,Luogo,Ingresso da,Link,Coordinate GPS,Note` (CSV quoting applies).
- **116 rows**, no blank/duplicate `Item` values; **60 distinct `Luogo` strings**; all 116 coordinate pairs parse as latitude then longitude; 37 blank `Link` cells; all `Note` cells blank. Do not hard-code these counts or checksum as permanent API invariants.
- Original type counts: Fitness 4, Ping pong 34, Pattini a rotelle 4, Pallavolo 23, Bocce 5, Pallacanestro 24, Calcio/Calcetto 12, Tennis 4, Percorsi vita e salute 4, Scacchiera 2.
- A real shape example: `Item=2`, `Tipo di impianto=Fitness`, `Luogo=Giardino Massimiliano I d'Asburgo - Cristo Re`, `Ingresso da=via Lung’Adige Braille, via Abondi, via Bepi Mor`, coordinates `46.080252379154174, 11.114328551144727`. `Link` contains an HTML `<a>` whose HTTPS href points to the municipal public place page. Another row can legitimately have no link.

Re-fetch/revalidate the source and applicable licence when implementing. The attached PDFs and local planning download are not required inputs. If the resource shape changed, adapt from the actual response and preserve a concise evidence note. Do not invent alternative endpoint paths.

This pack explicitly approves this **official CSV export adapter** alongside APIs. It permits no generic page crawler, linked-page text extraction, social-media collection or unrelated fallback. Parsing source-provided HTML inside the CSV link cell is field decoding only.

## Source checkpoint and local authorization

Record the verified metadata page, resource, licence URL, attribution, retrieval date, supported coverage and parser version. The explicit applicable dataset licence is adequate evidence for reusing this dataset with attribution; a fresh email/written-permission request is not required by this plan. Do not inherit Agenda Trento's event-description blocker.

Prepare owner-controlled **disabled hosted configuration**. A disposable local source configuration with rights confirmed from the documented dataset licence and an enabled local import is authorized for acceptance testing. It must not affect hosted projects, enable GitHub schedules or alter Agenda Trento's gates. Do not send external messages.

## Mapping requirements

- Stable source identity plus upstream `Item` identifies an equipment/facility entry. Verify uniqueness/nonblank IDs every run and test stable repeat/update. A changed row order, display title or venue URL must not recreate identities. If source evidence shows `Item` is only transient numbering, stop and resolve identity rather than silently hashing titles.
- `kind=place`, category Sports; retain original `Tipo di impianto`. Map known types deterministically to controlled disciplines with IT/EN labels. Keep unknown new types under a generic sports-place type and report them; never infer a course, coach, club membership or competitive event.
- Build a concise factual display title from type and place when needed; preserve the original place name. `Ingresso da` is source-provided access/address text, not necessarily a verified postal address. `Note` is optional plain text. A missing description stays absent; do not manufacture prose.
- A row is a sports equipment/facility entry. Different `Item` values at one park or with one official URL must not be collapsed automatically. A cluster/venue label may group display, but canonical identity and counts stay clear.
- Parse CSV correctly: quoted commas, multiline fields, CR/LF, UTF-8 BOM, empty cells and Unicode apostrophes. Reject malformed structural data, duplicate headers/IDs and truncation. Use an existing suitable parser or a justified pinned dependency; no naive `split(',')`.
- Extract only one safe public municipal href from the bounded `Link` value. Strip markup and validate the exact allowed origin/path. No script/unsafe-URL execution, rendering of the raw anchor or fetch of that page. Missing/invalid link may use the verified dataset metadata page as an explicitly typed **dataset-level source link**. Do not pretend it is the missing place/enrollment page or reject all 37 otherwise useful rows merely for that absence.
- Parse `Coordinate GPS` as the documented latitude/longitude pair, validate finite ranges and plausible source coverage, and store as **published public venue geometry**, with source provenance. Do not reverse axes based on guesses. Unexpected distant values should produce a visible validation outcome, not get silently snapped/geocoded. Keep source precision honest; equipment coordinates do not establish entrance-level accuracy or accessibility.
- No dates/occurrences, opening-now status, availability, capacity, photos, personal contacts, ticket price or booking URL are invented. The dataset's access-scope wording can be attributed; it does not certify that a facility is open or usable at this instant.
- Complete export validation precedes atomic import. A failure/HTML error page/empty malformed export cannot erase the last good catalogue. An unchanged full export can re-observe its records; no blanket refresh of absent entries.

## UI and local end-to-end proof

Use the existing canonical public reader; the mobile app never downloads this CSV. Render at least one actual imported place in Sports/Places, its detail/provenance and dataset-link fallback. Once 008 is merged, include real map proof in 011; do not make this adapter wait for the map step.

Run the importer twice against an isolated local catalogue. Report fetched/accepted/rejected entries, reasons, stable IDs/revisions and no duplicates. Demonstrate a controlled synthetic changed-row update separately; do not mutate the real upstream export. Verify anonymous reads, source-disable removal and no native records changed.

Normal CI uses small representative synthetic CSV fixtures with the actual header/shape and synthetic public links/coordinates, plus explicit attribution if any real source row is committed. Live re-fetch is opt-in, bounded and not a PR/fork dependency. Test quoted/multiline CSV, missing link/notes, malicious anchors, invalid/axis-swapped/out-of-area coordinates, duplicate IDs, reordered/added columns and schema drift.

## Completion classification

Update source/runbook/feature/progress docs, tests and generated contracts as applicable; open/merge the focused PR after checks. State exactly whether the source was live-verified, imported locally, rendered locally and activated anywhere hosted. No hosted import/deployment/scheduler activation is authorized. A fixture-only parser can be merged as partial work if useful, but cannot be reported as a completed live connector.
