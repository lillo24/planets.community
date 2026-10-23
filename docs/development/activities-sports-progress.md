# Activities & Sports implementation progress

Current continuation: the founder explicitly adopted
[RESUME02](../../history-implementations/PLANETS_RESUME02_finish_activities_sports_queue.md).
Use this existing cumulative branch/worktree and PR #298 for 002–011; tested
predecessors may be built on before intermediate merges. Delegated exact-head
SQL review/posting through the existing verified owner account is authorized.
Keep all identity/hash/preservation/semantic/CI controls intact. The older
per-step-merge and personal-posting waits below are historical and superseded.
RESUME01 is merged at 9945ad01 with all required CI green; local release
preparation is recorded. This cumulative branch now includes that merged code.

Pack: `ACTSPORTS-2026-10-23`. Initial 002 runner: Codex thread
`01a165d0-5cc8-7ba0-8ce1-c5b76de7b120`. Entry point found on `origin/main` at
`d735bb88decbc845ee27d1f5812941a233b61b3f`; every numbered prompt was present and
READY. The file-watching heartbeat was deleted after detection. No competing
runner for this queue was found in current tasks, worktrees or open PRs.

| Step            | Status                                           | Evidence / next action                                         |
| --------------- | ------------------------------------------------ | -------------------------------------------------------------- |
| 002 ACTCAT02    | Implemented and locally verified                 | Existing 4790cf59; navigation repair ed9127b9; cumulative #298 |
| 003 ACTUI02     | Implemented and locally verified                 | 7940d8c9                                                       |
| 004 SPORTUI01   | Implemented and locally verified                 | 38d302b4                                                       |
| 005 ACTSRC02    | Implemented and locally verified                 | 71d5bf63; 144-migration replay                                 |
| 006 SPORTDATA01 | Implemented; real local source verified          | 846a256b; 116 records; no hosted publication                   |
| 007 ACTGEO01    | Implemented and locally verified                 | 145 migrations; full 8415 assertions                           |
| 008 ACTMAP01    | Implemented and locally verified                 | Shared renderer; zero provider attempts                        |
| 009 SPORTAPI02  | Assessment complete; connector blocked           | No eligible local coverage verified; proceed to 010            |
| 010 ACTOPS01    | Implemented and locally verified                 | 146-migration upgrade; 37 SQL assertions; real operator HTTP   |
| 011 ACTQA01     | Locally qualified; final protected CI/merge next | 146 clean migrations; 8,452 SQL / 4,314 mobile; #298           |

## 011 final pre-merge qualification checkpoint

Current main `3f1ae160` is included through merge `412008ad`, preserving the merged
PEOPLEHOME Home/General-link work. The one cumulative main-targeted
[PR #298](https://github.com/lillo24/planets.community/pull/298) owns the final
exact-head CI, delegated SQL proof and merge outcome; no intermediate feature
merge or takeover of unmerged MAPMOCK/VIS01 work occurred.

Completed local qualification:

- Full `flutter gen-l10n`, Dart formatting, `flutter analyze`: clean; full
  `flutter test --concurrency=2`: **4,314 PASS, two existing skips**.
- `npm run check:web`: **208 tooling tests** (fresh tooling rerun after the final
  operations diagnostic fix), **405 web tests, two existing skips**, lint,
  typecheck, production build and static-invitation checks pass.
  `npm run check:site`: **60 tests**, lint/typecheck, build and Wrangler deployment
  **dry-run** pass. No website deployment occurred.
- `flutter build apk --debug --target-platform android-arm64
--dart-define=ENABLE_DEMO_TOOLS=false`: pass. APK SHA-256 is in the
  [safe evidence manifest](evidence/activities-sports/integration-local-qualification.json).
  This is a compile qualification, not a signed release or on-device test.
  Existing sentry_flutter/share_plus built-in Kotlin deprecation warnings remain;
  no unrequested dependency upgrade or signing change was made.
- Actual main **142→146** populated upgrade: **232 original tables / 271 rows**
  and every original column preserved after each file. Warmed old import calls,
  importer OIDs/grants, event UUID/prose and no-op retry survive. The four raw
  migration hashes/predecessor digests are recorded in the manifest. Existing
  published SQL bytes are unchanged. `db:lint`, `db:advisors` and standard
  `db:types:check` pass. The fresh 146-file clean start and full pgTAP pass: **175 files / 8,452 assertions**.
- Guarded `activities:verify:local` passes real anonymous/service contracts,
  legacy upgrade, A/A and A/B races, source isolation/partial/disable, V3 List/Map,
  signed cursors, 2,406-row GiST/cap, private operations, no-write dry-run,
  lease recovery and late completion fencing. Fixtures are removed.
- Fresh opt-in `activities:trento:verify:local -- --evidence <new-path>`:
  **116 actual equipment records / 60 named places**, zero rejected/unknown types,
  37 dataset links, four pages, zero-change repeat of the same single fetched
  snapshot. V3 complete **List 116 / Map 116**, query+discipline **5 / 5**, stable
  external namespace and post-disable list/detail denial pass. Actual CSV hash is
  unchanged from 006. All source rows/receipts were cleaned; no hosted data.
- Fresh scoped external/ACTMET/opt-in municipal run: **125 PASS**, **120 PNGs**.
  Actual IT/EN, light/dark, 320/360dp, 2× text captures were inspected, including
  real places, unknown/weekly courses, map/chooser/selection, partial/stale/error.
  Captures are synthetic except those explicitly labelled real municipal data.
  The physical phone `48091FDAS0041A` is absent. An attached emulator was not used;
  there is no physical Android/iOS or store-release claim.

Inspection repaired a monitoring gap: unexpected record/schedule validation
rejections now produce nonzero `source_record_drift` diagnostics instead of a
green zero-accepted export. Known outside-window/rights exclusions keep the
existing explicit policy; no canonical erasure or test weakening was introduced.
The real-import verifier now proves V3 List/Map equality and source-disable denial.

The exact CI request also exposed a reporting distinction: two Windows local
SQL inputs used CRLF while their published Git blobs use LF. Byte comparison
proves that newline conversion is the only difference; no published migration
content changed. The manifest labels the original local execution checksums
separately and records canonical Git hashes for review. Its predecessor chain
uses the complete actual PR base plus additions, matching the unchanged gate;
the earlier-timestamp addition cannot use only a chronological prefix. Working
copies now match Git exactly, and canonical-LF clean replay is additionally run.

Windows/Podman `db reset` failed with `DbConnectError` and later `DbSetupError`.
Only the task-owned `planets-resume02-qa` stack was stopped/restarted from empty;
the 142 and 146 fresh starts and actual-main upgrade passed without health bypass.
The shared VM was already running and stays running; peer backends are untouched.

The broad root formatter reports six **unchanged-main** baseline files:
`scripts/verify-local-proposal-skills.mjs`, `evidence/hero05/README.md`,
`evidence/navperf01/README.md`, `evidence/tut04/README.md`,
`docs/development/msgrefresh01-stable-refresh.md` and
`docs/development/navigation-headers.md`. The three evidence README paths are
under `docs/development/`. Their diff against main is empty. All changed
Prettier paths and full Dart formatting pass; unrelated files were preserved.

Immediate next action: commit this fully qualified local checkpoint, push the
reviewed final head, compare the fresh CI review artifact with all four
actual SQL hashes/predecessors, post the authorized exact proof through verified
owner ID **80243470**, and rerun required Validation. Inspect the populated CI
semantics and every required status; then mark ready and merge #298 at that exact
head, record its immutable merge/result in the PR, and clean only owned runtime
and worktree state. The progress file is a pre-merge source checkpoint; the linked
PR supplies the final merge SHA and exact CI artifacts without a circular commit.

The [operations runbook](activities-operations.md) is the activation/rollback
handoff. Reconcile any older hosted migration backlog before these four additions;
the programme does not imply that the existing hosted schemas match main. All new
sources/schedules remain unactivated, no hosted migration/import was performed,
and Android signing/configuration/unused Play version-code inputs from RESUME01
remain external release prerequisites. Agenda rights and ODH useful local coverage
stay explicitly blocked; no actual course/event source is claimed.

Optional phone review: actual Settings ON/OFF and return; Sports list/map/filter/
cluster/detail/back; real source/dataset link; account/background invalidation and
native Tavoli/Messages. Use only the owner's specified serial when available.

## 010 ACTOPS01 local qualification

The existing importer/disabled daily job now handles an explicit allow-listed
source set, independent outcomes, durable daily due cadence, a seven-minute
parent deadline and safe interruption. All failed/blocked/disabled/unconfigured
and partial runs return nonzero; a healthy source never conceals another's
failure. Dry-run writes nothing. Unknown municipal types produce a bounded
actionable warning while retaining honest source labels; structural empty,
duplicate/schema/truncated exports fail without hard-coding 116.

The additive migration adds service-only sanitized inspection and bounded
selected-source expired-lease/30-day compact receipt maintenance, even when
disabled. Canonical records/provenance and raw table grants remain unchanged.
Begin retains its function identity and ten-minute lease, replacing global
unbounded pruning with source-scoped maintenance. No hosted source or workflow
is enabled. See [activation and recovery](activities-operations.md).

Evidence: `npm run test:tooling` **207 PASS** (including 14 operation tests);
task-owned 145→146 upgrade; `supabase test db ...164_external_operations.test.sql`
**37 PASS**; `npm run db:lint` and `db:advisors` clean; standard `db:types`
regenerated. Guarded `activities:verify:local` passed predecessor compatibility,
multi-source/geographic checks and real service/anonymous operations: no-write
dry-run, apply/due skip, private denial, locked-source skip, expired lease/late
completion fencing and canonical row preservation. All synthetic fixtures were
cleaned. Full clean replay, final drift and broad regression are next in 011.

Next: reconcile newly merged main (PEOPLEHOME and current planning/docs), qualify
the complete integration, build Android, review exact final SQL/evidence and
post delegated owner proof; required CI and protected #298 merge follow.

## 002 implementation and evidence

The existing catalogue/import transaction represents events, current finite-term
courses and undated places. V1 stays compatible; V2 supplies nullable prose,
typed schedules and published geometry, server filters/facets and deterministic
cross-kind pagination. Flutter uses V2, preserves stable IDs and denied analytics,
and renders unknown sessions/places safely. The sandbox remains off by default.
See [contract, rollout and local verification](actcat02-catalogue-contract.md).

Completed checks: 185 tooling tests; full mobile formatting/analysis and 4,036
passing tests with two existing skips; database suite (161 files, 6,543
assertions); SQL lint and security advisors; populated predecessor upgrade with
warmed importer calls and stable function/record identities; real
service/anonymous V1/V2 HTTP checks; web typecheck; eight inspected IT/EN rendered
widget captures at 320/360 dp and 2× text in both themes. After the full mobile
run, the final localized detail presentation passed fresh scoped analysis and
all 36 external catalogue tests. Generated types come from the disposable schema; the post-commit `db:types:check` passed.
The Windows Store Python alias caused one initial tooling check to fail;
re-running with bundled Python on the process PATH passed all 185 tests.
WSL container lifecycle timeouts required explicit real health probes; all six
passed, then SQL/HTTP checks succeeded. No health failure was hidden.

Live source records imported: **0**. All exercised catalogue data is synthetic
and removed by the verifier/transaction rollback. Hosted migrations/data:
**unchanged by this task**. Refresh scheduler: **not enabled**. Native phone QA:
**deferred**, no physical-device claim. No production deployment occurred.

## Historical 002 checkpoint before RESUME02

Worktree:
`C:\Users\utente\.codex\worktrees\actcat02-catalogue-kinds\planets.community`.
Task branch: `codex/actcat02-catalogue-kinds`.

PR #298 is open. The changes are committed and pushed on the task branch;
required CI awaits the exact owner review. The existing pre-merge policy at
`scripts/release/reviews.mjs` requires a repository-owner-authored
`STAGING-AUTO01-REVIEW` comment containing the exact `review-required.json` for
the final head. This is a function/grant migration outside the routine nullable
column allowlist. Do not bypass the gate or begin dependent implementation.

After the owner review: rerun required CI for that exact head; fix any failures;
update from latest main if needed (which invalidates the head-specific review),
merge when green, record the merge SHA, stop the task-owned disposable stack,
archive the task worktree and remove its merged branch. Fetch latest main and
immediately start `003_ACTUI02_activities_hub.md` on a new isolated worktree.

## RESUME02 checkpoint — 23 October 2026

The existing worktree was clean with no unpushed commits. Its prior runner's
latest turn is completed and not loaded; no active competing queue runner was
found. The founder now explicitly requests resuming this same queue. Preserve
PEOPLEHOME and MAPMOCK work and include Find People only after its main merge.

Reproduced the three CI failures on the actual pinned Flutter configuration:
`flutter gen-l10n`, then `flutter test --no-pub
test/app/router/navigation_shell_test.dart --plain-name ACTSPLIT01 --reporter
expanded`: **8 PASS / 3 FAIL** at the old `External calendars · Trento` assertions.
ACTCAT02's accepted event/course/place contract intentionally generalized the
localized heading to **External activities · Trento**. The widget renders that
current localized value, so the two assertions (one parameterized over two
destinations) were obsolete. Only those expectations and their rationale comment
changed; native navigation, error/example separation and other assertions remain.

After repair, the **complete navigation suite: 64 PASS**. Both rendered public
layout journeys also PASS; 14 opt-in test-surface captures are retained privately
under `.actcat02-qa/resume02-navigation`. The actual Activities heading and honest
unconfigured state were inspected. These are rendered widgets at the default
test surface, not phone QA or the later 320/360 dp acceptance matrix. Formatting
of the changed Dart test passes with zero changes. No SQL or runtime code changed
in this repair, and no repeat database replay is claimed.

Next: finish the separately requested RESUME01 merge/local-release preparation,
fetch its merged main into this same cumulative branch, resolve shared source/
generated-type areas, then implement 003 → 004 → 005 → 006 → 007 → 008 → 009 →
010 → 011. Commit/tests/progress per stage, no intermediate merge waits. Obtain
fresh consolidated exact-content approval and required final CI before the one
queue merge. No hosted source/import/scheduler activation or store upload.

RESUME01 is merged at 9945ad01 with all required CI green. Its code is now reconciled into this cumulative branch. Both ARB additions are retained; the event-only D03 Find company handoff is intentionally limited to event records. Continue 003/004, then 005–011; no intermediate merges or hosted activation.

### 003 ACTUI02 — implemented and locally qualified

One category/kind filter and compact dates/discipline disclosure now drive the
canonical server filter across pagination. Place selection clears dates, Culture
clears incompatible sports place/discipline, reset retains category. Search and
scroll remain RAM-only; existing inactive/off/stale fences and native Tavoli are
preserved. Examples moved to the secondary footer; no dead Map action exists.

`flutter analyze lib/features/external_activities`: PASS. Scoped external,
ACTMET01 and complete navigation tests: **130 PASS**, including new server-filter
transition/search/reset and native scope journeys. Old interaction assumptions
were repaired with real scroll/pump before tapping after controls moved; no
navigation/analytics assertion removed. Rendered IT/EN × 320/360dp × light/dark,
2x text: **8 PASS / 16 captures**; narrow Italian controls and English stale
results inspected. Source heading reduced after inspection to avoid redundant
oversized headings. No device or live source claim. Remaining detailed Sports
metadata and final integrated matrix belong to 004/011. Next: implement 004.

### 004 SPORTUI01 — implemented and locally qualified

Sports now shares All/Courses & sessions/Events/Places controls, server discipline
labels and reset. Cards/details show known term/weekly schedule, explicit unknown
next session, source place/access and optional conditions. Item and dataset
information actions have distinct typed labels. No price/date/opening/capacity,
booking or native membership is inferred. D03 remains limited to actual events.

Scoped analysis PASS; external catalogue and ACTMET01 suites **93 PASS** after
removing accidentally repeated visual registrations. Twenty distinct rendered
weekly/unknown/cancelled/place/dataset journeys cover EN/IT, 320/360dp, both themes
and 2x text; top/provenance captures inspected, with no clipping or layout error.
Existing link failure, account replacement, unavailable detail and denied metrics
regressions remain. The final canonical link-scope reader is wired in 005, then
final integrated acceptance in 011. Next: additive multi-source schema/imports.

### 005 ACTSRC02 — implemented and locally qualified

Forward migration `20261023093757` removes only the one-enabled-source index,
preserves source/record identities, and adds owner-only bounded public-link
origins/capabilities plus configuration version fencing. Existing atomic import
transaction/OIDs/grants remain. V2 exposes partial health with sanitized counts;
V1 traverses all eligible non-null-prose events with its original payload/health
vocabulary. The code-owned resolver, independent API/public-link policies and
explicit-MIME UTF-8 CSV transport retain the original network budgets.

Fresh **144-migration** replay and 143→144 local application PASS. Scoped pgTAP:
**3 files / 167 assertions PASS**. Real anonymous/service HTTP: A/A exclusion,
A/B overlap, colliding upstream IDs, paging/facets, repeat/update/lost reply,
failed-source preservation, partial health and mid-run disable all PASS. Existing
populated ACTCAT02 upgrade witness also PASS. Scoped tooling **27 PASS**; mobile
external suite **67 PASS**, analysis PASS. Lint caught an unused V1 metadata
variable; removed it, then clean replay, lint and security advisors PASS with no
issues. Established `db:types:check` PASS. No hosted migration/config/import.
Next: official municipal adapter and real local qualification (006), then 007.

### 006 SPORTDATA01 — implemented with real local evidence

Reverified official metadata/resource/CC BY 4.0. Actual export: **116 equipment
records / 60 named places / 10 types / 37 missing item links / zero missing
geometry / all Notes empty**, 27,085 bytes, decoded UTF-8 SHA-256
`f7a2820e56ce27a12156a64c7223604734997c1e2b27db8bb224af34e86a7e4b`.
Counts are observations. One source href has trailing whitespace; boundary-only
normalization is documented/tested, without relaxing origin/path/security rules.

Real canonical local import: **116 accepted / 0 rejected**, four anonymous pages,
no duplicate/missing UUIDs. Repeat of the same actually fetched snapshot: **0
changed**, UUID/revision/hash stable; V1 events and Courses honestly empty.
Native project count unchanged and all source/records cleaned in finally. No
hosted publication or scheduler. Dataset fallback is explicitly typed, entrance
text stays access context and no date/price/opening/organizer is invented.

Scoped tooling **31 PASS**. Final external/ACTMET01/real-render suite **98 PASS**;
analysis PASS. Four actual municipal EN/IT light/dark 320/360dp 2x journeys/eight
captures inspected. Initial test-file async IO stalled under the widget fake
clock; replaced only that test evidence read with synchronous local-file IO and
reran green. Real rendering exposed verbose repeated card metadata; cards now
keep concise type/location/source while full entrance/access remains in detail.
Selected captures are committed with attribution. Next: 007 canonical geographic
query, then 008 working shared map integration; no live-source dependency wait.

### 007 ACTGEO01 — implemented and locally qualified

Additive `20261023101305` stores/indexes only canonical source-public geometry,
adds an isolated external V3 query with shared MAP04 bounds/complexity limits and
15-minute HMAC-signed full-tuple cursors. Existing V1/V2/native geography are
unchanged. Map identity is `external_activity:<UUID>`; distance is from an explicit
radius reference and available only for venue precision. Same eligibility helper
handles cancellation, expiry, current course terms and every source gate.

**145-migration clean replay; full pgTAP 174 files / 8,415 assertions PASS**.
Scoped external/native geography includes exact geodesic/viewport boundaries,
HMAC tampering/expiry and source disable. Real HTTP list/map equality, mixed kinds,
two-source paging/precision, signed continuations and disable PASS. A **2,406-row**
synthetic catalogue selected radius/bounds GiST indexes (6.236ms / 0.093ms observed)
and enforced >2,000 matching spatial candidates; a full query refinement narrows
before that cap. Fixtures cleaned. No native geometry or provider was used.

Lint identified an over-strong IMMUTABLE annotation on JSON area normalization;
changed it to STABLE and reran lint/advisors with **no issues**. Standard database
types regenerated. Scoped mobile/ACTMET01 **96 PASS**, analysis PASS, including
A→B→A pending-response cancellation and strict area/namespace/distance tests.
Next: 008 working List/Map route using a modest shared-renderer extraction,
retaining the one external filter authority and all native cache/provider rules.

### Resumable checkpoint — 008 in progress

007 committed as `809942b2`; generated type drift and web typecheck PASS. Existing
cumulative branch/worktree/PR #298 retained. 008 working code is uncommitted:
shared public camera/grid/canvas and loaded-entry chooser extraction, separate
external map result lifecycle sharing the one filter authority, gated map route,
List/Map selector and localization. Inspect `.actcat02-qa/008-analyze.log`, then
finish widget/router/native-cache regressions and narrow rendered inspection
before committing 008. Do not mark the new map qualified yet. Private operational
checkpoint: `.actcat02-qa/resume02-checkpoint.json`; local disposable project
`planets-resume02-qa`, API 54921 / DB 54922, 145 migrations, no enabled source.
Source environment helper `.actcat02-qa/use-backend.ps1` contains no credentials.
Continue 009 → 010 → 011 and the final authorized protected merge; no hosted work.

### 008 ACTMAP01 — implemented and locally qualified

Working List/Map, source-public typed markers, stable loaded clusters/chooser,
explicit area/reference search, shared filters, retained camera/selection and
external UUID details now compose the existing public renderer/cache/budget
boundary. No native GeoKind/default-All change or second tile cache. All provider
flags remain OFF; counted tile/search/resolve gateway attempts **0**. Source
unconfigured/empty/error/partial/stale and locality precision remain distinct.

The first map journeys found that lazy scrolling could dispose the canvas and
hide the selected-card target. Fixed by keeping one shared canvas mounted in the
native-style scrolling control column; the same unchanged journeys pass. Tests
also use valid lifecycle transitions and real scrolling to feedback/results.
The kind selector is now a compact native dropdown after inspection showed
redundant stacked chips at 2x text. All kind/date/query semantics are retained.

Final external/ACTMET01 suites **120 PASS**, plus the arbitrary valid 3.5km radius
regression **1 PASS**. Native map/cache/router/Settings component of the scoped
regression also passed (276 tests); its three external viewport assumptions were
fixed and included in the fresh 120-pass run. Final scoped analysis: **no issues**.
Twenty difficult-state/narrow visual cases plus four functional map journeys
cover EN/IT, light/dark, 320/360dp and 2x text; actual rendered captures inspected
and selected evidence committed. No physical device or hosted activation claim.
See `activities-map.md` for exact commands, semantics and inspection links.
Next: bounded 009 official second-source verification, then 010 and 011; no
intermediate merge, source-availability or phone-review wait.

### 009 SPORTAPI02 — bounded assessment complete; connector blocked

Verified current official docs, Swagger and actual 200 JSON responses in
**8m14s (11:13:47–11:22:01 UTC)**, zero unavailable-endpoint retries. Scope remains
Trento 10km. Nine observed active facility tags: **0 local**; same-filter positive
global control **105** (explicitly not local coverage). Complete open non-STA
subset: **12** winery/charging records, no sports. Other sampled SIAT route data
is explicitly Closed/ClosedData=true and unsupported as a place/course. Current
active/published Event window is empty; the unbounded-date sample is a 2021 outing.
No course or useful permitted local sports subset was verified.

The evidence manifest records counts, query scope, sample record IDs and saved
response hashes without raw documents/contacts. The recognized ODH source returns
an explicit coverage-checkpoint failure before provider/DB IO; **no connector or
working second integration is claimed**. No additional official candidates were
already identified, and no scraping/account/source hunting was substituted.
Scoped tooling **22 PASS**; actual CLI dry-run exits **1** with the distinct
coverage code, not successful empty. No hosted action. Next: 010 bounded refresh,
private health/maintenance and disabled scheduling, then full 011 qualification.
