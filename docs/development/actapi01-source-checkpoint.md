# ACTAPI01 source checkpoint

**Status: blocked on event-text reuse permission; MVP not implemented.**
Verified on 2026-10-21 from `main` at
`55a9480b` (the execution base). ACTSPLIT01 remains the example-only Activities
experience. No importer, catalogue migration, public read contract, scheduler or
real-listing Flutter integration has been added by this checkpoint.

## Why source-dependent work stopped

[ACTAPI01](../../history-implementations/PLANETS_ACTAPI01_official_api_activities_mvp.md)
requires applicable reuse terms before the source-specific parser and says to
stop source-dependent work if reuse permission cannot be established.

- [Agenda Trento's linked terms](https://eventi.comune.trento.it/agenda/info/terms)
  returned HTTP 200, but its substantive body contains only **“Terms text here”**.
  The portal's `/Note-legali` returned HTTP 410.
- [The municipal site's terms](https://www.comune.trento.it/Note-legali) provide
  default CC BY 4.0 permission with explicit exceptions, including incorporated
  third-party content. They do not expressly resolve rights for this separate
  collaborative calendar or every event mirrored onto the main site.
- [The provider README](https://gitlab.com/opencontent/openagenda/-/blob/master/README.md)
  describes events and association profiles as open data available through APIs.
  Its software GPL licence is not a deployment-specific event-text licence.
- The inspected event schema and sample payloads have no event-text licence or
  rights-holder field. Image licence captions concern images, which remain out
  of scope; they cannot establish permission for event descriptions.

This is an unresolved permission scope, not a finding that reuse is prohibited.
Public JSON accessibility, public publication state, an organizer name and a
shared upstream ID do not resolve that scope. No alternate aggregator or
geography has been substituted.

To resume, obtain an authoritative municipal/provider statement or terms URL
covering storage, plain-text adaptation and public republication of the
calendar's event text and schedule metadata in PLANETS, with attribution,
licence and any exclusions. If permission covers only a subset, establish an
explicit, verifiable selection rule before importing it. An assumption based
only on the hostname or generic open-data marketing is insufficient.

## Verified official API surface

Live read-only Node 24 `fetch` requests succeeded from this Windows host without
credentials. The research browser could not retrieve the API URLs; that tool
limitation does not mean the API is unavailable.

Both origins expose their public v2 route index:

- <https://eventi.comune.trento.it/api/opendata/v2/>
- <https://www.comune.trento.it/api/opendata/v2/>

Those indexes explicitly advertise `GET content/search/:Query`,
`GET content/read/:ContentObjectIdentifier`, `GET classes/:Identifier` and
calendar contexts. The following are actual successful requests, rather than
guessed private UI endpoints:

| Request                                                                                                                                                    | Observed result                                                          |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| [Portal event schema](https://eventi.comune.trento.it/api/opendata/v2/classes/event)                                                                       | HTTP 200; `event` class, `time_interval` uses `ocevent`                  |
| [Portal sample search](https://eventi.comune.trento.it/api/opendata/v2/content/search/classes%20%5Bevent%5D%20limit%201%20sort%20%5Bmodified%3D%3Edesc%5D) | HTTP 200; one hit; `totalCount: 2920`; next offset 1                     |
| [Portal exact detail](https://eventi.comune.trento.it/api/opendata/v2/content/read/5892)                                                                   | HTTP 200; ID 5892, upstream remote ID `95cba2e6d20ad9218b7a493d4ce82a52` |
| [Terminal page probe](https://eventi.comune.trento.it/api/opendata/v2/content/search/classes%20%5Bevent%5D%20limit%201%20offset%202920)                    | HTTP 200; zero hits; `nextPageQuery: null`; same total                   |
| [Main-site sample search](https://www.comune.trento.it/api/opendata/v2/content/search/classes%20%5Bevent%5D%20limit%201%20sort%20%5Bmodified%3D%3Edesc%5D) | HTTP 200; one hit; `totalCount: 2937`                                    |
| [Main-site exact detail](https://www.comune.trento.it/api/opendata/v2/content/read/49664)                                                                  | HTTP 200; ID 49664; same upstream remote ID as portal ID 5892            |

Counts include historical events and are point-in-time API totals, **not** the
90-day eligible count, a complete traversal, imported records or visible PLANETS
listings. Imported and newly visible records from this task: **zero**. No event
descriptions, contact records, images, attachments or raw responses were saved.

The matching remote ID, source-provided title and schedule establish a concrete
calendar mirror example on the main municipal domain. Main-site mirrored
payloads use fields such as `virtual_has_public_event_typology` and
`virtual_takes_place_in`; their schema is not interchangeable with portal data.
This does not establish which party owns the text rights.

## Observed shape and mapping leads

The search envelope has `query`, `nextPageQuery`, `totalCount`, `searchHits` and
`facets`. Each hit and the exact-detail result contain `metadata`, `data` and
`extradata`. This is a structural excerpt with synthetic identifiers and text;
it is not a publishable event, production fixture or an accepted parser contract:

```json
{
  "metadata": {
    "id": 1000,
    "remoteId": "synthetic-upstream-id",
    "classIdentifier": "event",
    "stateIdentifiers": [
      "moderation.accepted",
      "privacy.public",
      "programma_eventi.public"
    ],
    "modified": "2026-10-21T11:19:12+02:00"
  },
  "data": {
    "ita-IT": {
      "event_title": "Synthetic title",
      "event_abstract": "<p>Synthetic short description</p>",
      "has_public_event_typology": [
        "Evento culturale",
        "Manifestazione artistica"
      ],
      "time_interval": {
        "input": {
          "startDateTime": "2026-10-23T16:00:00+02:00",
          "endDateTime": "2026-11-10T19:00:00+01:00",
          "freq": "none",
          "timeZone": { "offset": "+02:00" }
        },
        "events": [
          {
            "id": "1792764000-1794333600",
            "start": "2026-10-23T16:00:00+02:00",
            "end": "2026-11-10T19:00:00+01:00"
          }
        ]
      }
    }
  },
  "extradata": { "ita-IT": { "urlAlias": "/Eventi/Synthetic-title" } }
}
```

Mapping leads for the eventual verified connector:

- `metadata.remoteId` is the upstream identity candidate; numeric IDs differ
  across mirrors. `metadata.modified` supplies upstream modification time.
- `data.ita-IT` carries source-language text. `event_abstract`, `description`,
  `about_target_audience` and `cost_notes` need allow-listed plain-text handling.
- `has_public_event_typology` supplies explicit event types. It must remain
  distinct from topic tags: a sports-themed exhibition can still be cultural.
- `takes_place_in` and `organizer` contain related-record references and display
  names. Personal contact fields and images must be excluded.
- `time_interval` exposes `input`, `text`, `recurrences`, `events` and
  `default_value`. The observed occurrence crosses Rome's autumn DST change
  with explicit `+02:00` and `+01:00` offsets. An input's single offset alone
  must not replace occurrence offsets or establish a fixed-offset timezone.
- `extradata.ita-IT.urlAlias` resolves the official page on the corresponding
  HTTPS origin. An API `metadata.link` is not the public event page.

Returned pagination and related-record links used **HTTP** absolute URLs even
though the request used HTTPS. A future importer must validate exact official
origins and API paths, then reconstruct an HTTPS request; never follow those
links blindly or silently broaden the allowlist. No source mutation was tried.

The sample detail responses supplied no ETag, Last-Modified or Retry-After.
No published numeric rate limit was established. This is not evidence that
limits do not exist or that conditional requests are supported.

## Reproduce the small read

This PowerShell example prints selected metadata only. It performs one read,
requires a successful response, rejects redirects and has a 15-second timeout.
It is a research probe, not the bounded production importer or a dry-run mode.

```powershell
$checkpointUri = 'https://eventi.comune.trento.it/api/opendata/v2/content/search/classes%20%5Bevent%5D%20limit%201%20sort%20%5Bmodified%3D%3Edesc%5D'
$checkpoint = Invoke-RestMethod -Method Get -Uri $checkpointUri -TimeoutSec 15 -MaximumRedirection 0 -ErrorAction Stop
$checkpoint | Select-Object query, totalCount, nextPageQuery | Format-List
$checkpoint.searchHits | ForEach-Object {
    [pscustomobject]@{
        id = $_.metadata.id
        remoteId = $_.metadata.remoteId
        modified = $_.metadata.modified
        states = $_.metadata.stateIdentifiers
        occurrenceCount = @($_.data.'ita-IT'.time_interval.events).Count
        officialPagePath = $_.extradata.'ita-IT'.urlAlias
    }
} | Format-List
```

Do not dump whole responses: metadata contains editor identities and event
content can contain personal contact details. Future automated validation must
use minimal scrubbed or synthetic fixtures, independent of live availability.

## Remaining checkpoint and implementation

After rights are resolved, verify overlapping ongoing/upcoming filtering for the
rolling 90-day window; stable paging and termination; multiple occurrences;
date-only/all-day end semantics; public/unpublished/cancelled states; related
venue resolution; and rate limits. The successful current-event sample does
not validate these contracts. Unknown booking, price, recurrence and capacity
must remain unknown rather than becoming participation promises.

Then implement and validate the plan's single-run dry-run/apply importer,
canonical isolated catalogue, leases and atomic persistence, public filtered
pagination, per-record 72-hour/14-day freshness, private bounded run history,
disabled daily runner, and real Flutter list/detail with separate examples.
Generate database types from migrations and test on a disposable local stack.
Do the bounded real-data repeat/import/public-read/render check only after the
permission checkpoint passes. No such end-to-end check has passed yet.

No deployment or activation steps exist at this checkpoint. No hosted migration,
secret, import, schedule, account resource or external communication was made.
Activities Split Mode is still device-local and off by default; switching it off
restores baseline navigation. There is no new catalogue state to roll back.
