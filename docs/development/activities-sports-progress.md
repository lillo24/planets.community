# Activities & Sports implementation progress

Pack: `ACTSPORTS-2026-10-23`. Runner: Codex thread
`01a165d0-5cc8-7ba0-8ce1-c5b76de7b120`. Entry point found on `origin/main` at
`d735bb88decbc845ee27d1f5812941a233b61b3f`; every numbered prompt was present and
READY. The file-watching heartbeat was deleted after detection. No competing
runner for this queue was found in current tasks, worktrees or open PRs.

| Step            | Status                                                 | Dependency base / PR / merge                                                                                   |
| --------------- | ------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------- |
| 002 ACTCAT02    | Validated locally; exact owner review required         | Base `d735bb88decbc845ee27d1f5812941a233b61b3f`; branch `codex/actcat02-catalogue-kinds`; PR pending; unmerged |
| 003 ACTUI02     | Waiting for merged 002                                 | Not started                                                                                                    |
| 004 SPORTUI01   | Waiting for merged 002, 003                            | Not started                                                                                                    |
| 005 ACTSRC02    | Waiting for merged 002                                 | Not started                                                                                                    |
| 006 SPORTDATA01 | Waiting for merged 002, 005 and source re-verification | Not started; no current live counts asserted                                                                   |
| 007 ACTGEO01    | Waiting for merged 002, 005                            | Not started; does not depend on live 006 data                                                                  |
| 008 ACTMAP01    | Waiting for merged 003, 004, 007                       | Not started                                                                                                    |
| 009 SPORTAPI02  | Waiting for merged 002, 005 and source verification    | Not started; sports/course coverage unverified                                                                 |
| 010 ACTOPS01    | Waiting for merged 005                                 | Not started                                                                                                    |
| 011 ACTQA01     | Waiting for merged implemented portions                | Not started                                                                                                    |

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
all 36 external catalogue tests. Generated types come from the disposable schema.
The Windows Store Python alias caused one initial tooling check to fail;
re-running with bundled Python on the process PATH passed all 185 tests.
WSL container lifecycle timeouts required explicit real health probes; all six
passed, then SQL/HTTP checks succeeded. No health failure was hidden.

Live source records imported: **0**. All exercised catalogue data is synthetic
and removed by the verifier/transaction rollback. Hosted migrations/data:
**unchanged by this task**. Refresh scheduler: **not enabled**. Native phone QA:
**deferred**, no physical-device claim. No production deployment occurred.

## Resume checkpoint

Worktree:
`C:\Users\utente\.codex\worktrees\actcat02-catalogue-kinds\planets.community`.
Task branch: `codex/actcat02-catalogue-kinds`.

Finish final validation, inspect the diff, commit/push only intended files and
open the focused 002 PR. The existing pre-merge migration policy at
`scripts/release/reviews.mjs` requires a repository-owner-authored
`STAGING-AUTO01-REVIEW` comment containing the exact `review-required.json` for
the final head. This is a function/grant migration outside the routine nullable
column allowlist. Do not bypass the gate or begin dependent implementation.

After the owner review: rerun required CI for that exact head; fix any failures;
update from latest main if needed (which invalidates the head-specific review),
merge when green, record the merge SHA, stop the task-owned disposable stack,
archive the task worktree and remove its merged branch. Fetch latest main and
immediately start `003_ACTUI02_activities_hub.md` on a new isolated worktree.
