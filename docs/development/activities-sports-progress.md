# Activities & Sports implementation progress

Current continuation: the founder explicitly adopted
[RESUME02](../../history-implementations/PLANETS_RESUME02_finish_activities_sports_queue.md).
Use this existing cumulative branch/worktree and PR #298 for 002–011; tested
predecessors may be built on before intermediate merges. Delegated exact-head
SQL review/posting through the existing verified owner account is authorized.
Keep all identity/hash/preservation/semantic/CI controls intact. The older
per-step-merge and personal-posting waits below are historical and superseded.
RESUME01 integration/local preparation finishes first; the independent 002
navigation reproduction/repair is qualified while its final Database CI runs.

Pack: `ACTSPORTS-2026-10-23`. Initial 002 runner: Codex thread
`01a165d0-5cc8-7ba0-8ce1-c5b76de7b120`. Entry point found on `origin/main` at
`d735bb88decbc845ee27d1f5812941a233b61b3f`; every numbered prompt was present and
READY. The file-watching heartbeat was deleted after detection. No competing
runner for this queue was found in current tasks, worktrees or open PRs.

| Step            | Status                                                  | Dependency base / PR / merge                                                                                                                                                          |
| --------------- | ------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 002 ACTCAT02    | Navigation regression repaired and locally verified     | Existing `4790cf59`; main `33f0309b` reconciled in `79b57979`; same cumulative [#298](https://github.com/lillo24/planets.community/pull/298), final consolidated review/merge pending |
| 003 ACTUI02     | Next after RESUME01 and merged-main reconciliation      | Not started; tested 002 is the dependency, no intermediate merge wait                                                                                                                 |
| 004 SPORTUI01   | Queued after tested 003                                 | Not started                                                                                                                                                                           |
| 005 ACTSRC02    | Ready on tested 002                                     | Not started                                                                                                                                                                           |
| 006 SPORTDATA01 | Queued after 005 and source re-verification             | Not started; no current live counts asserted                                                                                                                                          |
| 007 ACTGEO01    | Queued after tested 005                                 | Not started; independent of live 006                                                                                                                                                  |
| 008 ACTMAP01    | Queued after tested 003, 004, 007                       | Not started                                                                                                                                                                           |
| 009 SPORTAPI02  | Queued after tested 005 and bounded source verification | Not started; sports/course coverage unverified                                                                                                                                        |
| 010 ACTOPS01    | Queued after tested 005                                 | Not started                                                                                                                                                                           |
| 011 ACTQA01     | Queued after all ready implementations                  | Not started                                                                                                                                                                           |

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
