# UI-NEXT-02 — Stable discovery and own drafts

## Base and sequence

The user's 7 October batch instruction replaces the prompt's merged-predecessor
requirement: implement separate slices on predecessor history, then merge in order.
This branch starts at UI-NEXT-01 PR #156 head
`2770ec78702b320632684c996464257ad6f690ad`; its main ancestor is
`9cd024cc38c02b0333a32f8abe71fdc9681df548`. UI-NEXT-01 is preserved unchanged.
Validated implementation commit: `eca0a709d24b0a1c9eb986727ca07b8ec1e72925`.
The PR evidence comment records its final documentation head and merge reference.

## Behavior

Projects, Tavoli and Scambio keep their family/filter/search controls mounted
through idle, loading, errors and empty results. Family root changes have no page
transition; detail/editor transitions and native/draft guards remain. Browse's
explicit initial location is still `/proposals`, independent of the hub route.
The hub selects Browse truthfully. Root Back reads canonical route matches rather
than a departing Navigator's stale `canPop` during a Material replacement.

Same-query refresh retains useful rows with visible progress/failure. Project and
Tavolo filter changes clear rows before loading. Scambio preserves its existing
retained-row contract but labels previous results and disables their actions until
the new filter completes successfully. Failed Tavolo refresh retains the original
pagination reference-time snapshot. Stale revisions remain rejected.

Owner management waits for both owner and delegated sources before declaring an
empty collection. A completed peer is not reloaded merely because the other is
pending. Independent failures/pending sections remain explicit with successful
rows retained. Private controllers invalidate on readiness as well as actor.
Canonical owner RPCs had no client paging despite the API's 1,000-row response
cap. Gateways now exhaust them using 200-row UUID keyset pages, restore existing
created-time ordering, and batch structural capacity reads within the canonical
100-ID limit. Later page failures fail the entire source. This extends the existing
gateway completeness contract without changing database functions or RLS.

The [draft module](../../apps/mobile/lib/features/drafts/README.md) documents the
typed hub, contextual OR filters, direct editor/recovery routes, source refresh,
and retained published/history/co-organizer management. No backend migration,
authorization change, taxonomy or creation-form redesign is included.

## Demo and validation

The trusted local seeder adds four unpublished Giulia-owned canonical rows and
never overwrites edited or published destinations. Opaque creation receipts are
host-local and shared across worktrees; [reproduction and recovery](../development/demo-data.md)
describe their location and failure behavior.

Validation uses an owned disposable Supabase project
`planets-community-ui-next02-qa-20261007`, API/DB/Mailpit ports 55381/55382/55384.
Its temporary configuration is restored before commit. The retained phone-demo
and MODINT01 stacks are untouched. No iOS device run is possible on this host.
Native Android evidence is recorded separately from widget, backend and build checks.

Passed on the final source: `npm run check:mobile` (format, localization,
analysis and 1,515 tests; two existing skips), `npm run check:web`, and
`npm run check:db` on the owned stack (migrations, pgTAP, authorization,
integration/demo and generated-type checks). The six demo-draft unit tests and
targeted Prettier check also pass. The focused draft/owner/paging checks passed
44 tests; the final navigation suite passed 45.

The opted-in `test_support/ui_next02_rehearsal.dart` Android fixture built and
ran on the owned `emulator-5580`. Its bounded native driver exercised repeated
Project/Tavolo switches, contextual Project drafts, clearing the last filter to
all four types, a genuine empty hub, and empty Tavolo entry. Captures confirm the
hub selects Browse. These are deterministic native UI fixtures; live canonical
backend behavior was validated separately by the owned database suite. Neither
the founder's physical phone nor native iOS was exercised. Host-local logs and
captures are under the task's visualization directory, with no credentials
committed. Production map/provider activation is outside this slice.

## Next slice

UI-NEXT-03 stacks on this head. Normal creation still targets `/proposals/create`;
typed draft edits remain `/proposals/:id/edit`, `/tavoli/:id/edit` and
`/resources/:id/edit`. Workshop, DRAFT01, capacity/time helpers, similar-project
matching and manual location fields retain their prior contracts.
