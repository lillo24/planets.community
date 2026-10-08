# DBRACE-02: controlled validation and failure disposition

Evidence date: 2026-10-05. Draft technical maintenance only; the dependency
stack remains unmerged and undeployed. No 09C2B feature, hosting selection,
clock adjustment, shared-service reset, production operation or dependency
upgrade is included. Historical failures are not rewritten as successful runs.

## Source and controlled setup

- Required base: DBRACE-01 [PR #136](https://github.com/lillo24/planets.community/pull/136),
  `b8ab159b5bcb643b477cdaa60b0484b7ad0d0e8f`, branch
  `codex/dbrace01-membership-end-state`. Its ancestor #133 is exactly
  `2ae80181ee9ed9cb52012d7b0ad73897330a2c49`. Both remote heads were unchanged
  and draft/open at initial verification; no latest-main changes were imported.
- Separate managed worktree and branch `codex/dbrace02-controlled-validation`.
  Tested implementation: `9accde3f6fc8a8fa1089edfa6a98d2bb20958deb`.
  The draft targets #136's branch, not main. Exact tested/publication SHAs and
  exact-head Actions results are recorded in its final PR evidence comment;
  a committed report cannot include its own Git object ID.
- DBRACE-01's tested runtime was `43f7414770610bf42070f574bb21a14f2232551a`;
  its final b8ab head changed documentation only. Its [report](dbrace01-membership-end-state-regression.md),
  linked [DEPSEC evidence](depsec01-dependency-security-and-admin-qa.md) and
  [final comment](https://github.com/lillo24/planets.community/pull/136#issuecomment-5991903038)
  remain historical evidence. Run 37290080647 omitted the membership verifier
  and skipped Site; it is not this task's full checkpoint.
- Clean `npm ci`: Node 24.21.0, npm 11.19.0, embedded Undici 7.29.1;
  840 packages added / 843 audited. Use the selected Node with npm's
  `npm-cli.js` explicitly: the host npm launcher uses a different Node.
  The eight inherited high-severity advisory entries remain out of scope.
- Windows 11 Home 10.0.26200, Docker Desktop Linux containers / Docker 29.3.1,
  Supabase CLI 2.118.0-beta.39. Replayed PostgreSQL reports 17.6; image
  `public.ecr.aws/supabase/postgres:17.6.1.171`. Auth v2.197.0, Realtime v2.135.3,
  Mailpit v1.30.2. The available Ubuntu 24.04.4 WSL distribution had no Linux
  Node executable; the existing Ubuntu Actions runner supplies the supported
  Linux comparison, not a newly provisioned resource or a clock-independent
  proof about Windows/Docker.
- Fresh disposable project `planets-community-dbrace02-qa`: API 54401,
  DB 54402, shadow 54400, pooler 54409, Studio 54403, Mailpit 54404,
  inspector 8092, analytics 54407. Only synthetic task fixtures are used.
  Start used the existing CLI, excluding Studio/imgproxy, without ignoring
  health failures. All 61 inherited migrations replayed from zero.
- Before validation, Auth `/health`, REST and Mailpit `/livez` returned 200;
  PG/Auth/Kong/Storage/Realtime/Mailpit were healthy. Realtime's message
  replication slot was active. Vector was observed restarting; no blanket
  claim that every optional container was healthy is made. Other services
  and clock configuration were not changed. Host available memory varied
  (approximately 1 GB during Web, 2.6 GB later); that is context, not a proven
  cause of an older failure.

## Dispositions

The old DBRACE-01 containers were already removed after backup/teardown; their
live Auth/Realtime logs cannot now supply missing request-time or post-ack state.
Retained session/report log excerpts establish the historical 504 window, not
its cause. Current task service health/logs and successful invocations are
independent evidence, not retroactive recovery of those missing observations.

Hosted entries refer to the exact final-head PR evidence, not predecessor badges.

| Incident                                                               | Cause / evidence                                                                                                                                                   | Repair and current gate                                                                                                       | Remaining limitation                                                                                                                                |
| ---------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| Historical creator removal `23514 project_memberships_end_state_valid` | Original stage/PID/constraint known; failed tuple and clause unavailable. Replayed creator RPC takes `clock_timestamp()` after locks/rechecks.                     | No SQL repair. Existing observed-lock verifier now included in hosted Database; local default covers all four orders.         | Original cause remains **unexplained**, not fixed. Missing historical tuple is not a prerequisite for this task.                                    |
| 026 chat creation chronology                                           | Attempted creation preceded activation by 207,720 µs. Reconciliation checks an INSERT candidate before handling the existing chat conflict.                        | No domain repair: actual canonical failure not reproduced in the controlled baseline. Constraint/history unchanged.           | Conflict evaluation mechanism established; original timestamp inversion's cause unknown.                                                            |
| 110 request resolution chronology                                      | Attempted resolution preceded creation by 342,743 µs. Request default is transaction time; acceptance uses statement time.                                         | No domain repair: no demonstrated defect justifying a migration. Constraint/history unchanged.                                | Earlier timestamp acquisition and clock adjustment were examined, neither established as the historical cause.                                      |
| Auth OTP 504 / `request_timeout`                                       | Historical Auth log window 08:27:41–42 UTC; later health alone cannot explain that request. Mailpit is queried before the real OTP request.                        | No readiness/retry change. Controlled health and real OTP/participation gates remain required.                                | Original request-time resource/readiness context incomplete; no repeatable Auth/verifier defect demonstrated.                                       |
| Pre-suspension Realtime signal missed                                  | Source awaits `SUBSCRIBED` before sending canonical committed messages, then requires their exact IDs. Historical post-ack channel/replication state not retained. | No transport/filter/domain change or retry. Initial signal and later suspension assertions retained.                          | Historical cause unknown; join acknowledgement alone does not prove continued delivery health.                                                      |
| `already_revoked` alert focus                                          | Commit-phase probe observes the real attached alert present but not focused; the unchanged passive effect subsequently focuses it.                                 | Error tests await **focus**, preserving the same keyboard assertion/time limit/drafts. Probe + focused file: 19 tests passed. | Demonstrated synchronization hazard repaired; the older invocation's scheduler trace was not retained. Full-suite results remain separate evidence. |

## Chronology investigation

Final replayed `pg_get_functiondef`, column defaults, trigger definitions and
constraint definitions were inspected. Both creator removal and leave preserve
the Project/membership lock order and assign actual time after revalidation.
The differently named manager-removal RPC's early timestamp is not evidence for
the reported creator-path failure, and was not opportunistically changed.
Capacity and membership/chat/coverage triggers do not rewrite end timestamps.

In 026, one explicit transaction creates canonical requests and accepts them;
first membership insertion ensures the anchor. The later historical Project has
2023/2024 membership fixtures, then its anchor is deliberately deleted before
reconciliation. Reconciliation considers **all** membership Projects, including
the existing normal Project that failed historically, and proposes default
`statement_timestamp()` creation before `ON CONFLICT` handling. The failed INSERT
candidate is not evidence that the committed existing chat had invalid times.

In 110, the explicit transaction creates identities/photos/Projects/Resources,
requests as users 5/6 in separate SQL commands, changes the expected actor to
user 2, then invokes two-argument canonical acceptance at line 49. That wrapper
calls triaged acceptance; the final inner definition initializes
`transition_time := statement_timestamp()`, resolves the request and inserts
the membership with that same value. Request `created_at` defaults to `now()`.
No future request or membership time is injected by those fixtures.

The retained historical values are failed **attempts**, not committed state:
026's existing normal Project `e7100000-0000-4000-8000-000000000001`
had activation 08:21:10.380508 UTC versus candidate creation .172788;
110 attempted resolution 08:22:08.216757 UTC versus request creation .559500.
Both test files use explicit transactions; after a statement abort their
rolled-back fixtures are not a substitute for the original failing tuple.
After final pgTAP passed, a separate committed-state read on observer PID 1339
at 11:03:50.014476 UTC found zero memberships for 026's normal Project and
zero requests for 110's Project, consistent with test rollback. It supplies
current rollback evidence, not the missing historical attempted membership row.

[PostgreSQL 17 datetime semantics](https://www.postgresql.org/docs/17/functions-datetime.html#FUNCTIONS-DATETIME-CURRENT)
distinguish transaction-start time, latest client command-message receipt time,
and actual time at evaluation. An older statement/transaction timestamp inside
a long command is not, by itself, evidence of clock reversal. A single psql
multi-command probe on PID 458 showed identical transaction/statement times
10:42:50.189321 UTC, with advancing actual time .190029/.190077; it is not a
reconstruction of the historical pgTAP runner's message boundaries.

A bounded rollback-only temporary-table probe confirmed the conflict mechanism:
an existing valid row did not prevent a candidate CHECK failure before an
`ON CONFLICT DO UPDATE` that would retain the existing value. Attempted
activation was 10:47:26.507225 UTC, default creation .029787. This intentionally
mixes statement-start and actual time within one command and is **not** a
canonical database-defect reproduction. The failed statement/connection rolled
back; neither the temporary table nor candidate was committed.

A separate read-only paired observation was bounded to 120 PG samples, 20 ms
sampling interval, one backend PID 491, 5-second SQL deadline. Each sample
bracketed microsecond PG transaction/statement/actual epoch strings with host
`Date.now()` and `process.hrtime.bigint()`. First/last host intervals were
10:43:29.405–29.602 and 10:43:35.038–35.044 UTC; actual PG samples ranged
1791197009573886–1791197015040549 µs. No adjacent PG reversal was observed.
The roughly 5.6-second window cannot rule out an intermittent discontinuity at
another time, and is not contemporaneous with the historical failures.

No `GREATEST` clamp, chronology constraint weakening, migration rewrite,
future-time fixture change, retry or arbitrary delay was introduced. No SQL
migration or generated public-contract change is warranted by this evidence.

## CI coverage and checks

The new Database step runs `npm run project:membership-commitments:verify:local`
after contribution-selection validation, with the normal one-iteration default.
Project-scoped CLI status provides API/DB endpoints; the standard CI Mailpit
endpoint is loopback 54324. All four end-state winner orders require observed
PostgreSQL blocking, while the remaining verifier flows run once. Diagnostic
40-case campaigns remain opt-in. Guards, deadlines, failure propagation,
`always()` cleanup, the 25-minute budget and existing triggers remain intact.

Actual classifier evaluation: verifier → Database; shared evidence helper →
Mobile/Web/Database; workflow → all four. Existing mapping is correct, so no
classification code or redundant regression was added. The workflow change
requires a full Web/Site/Mobile/Database hosted checkpoint.

Local commands use the supported explicit Node/npm runtime and
`MAILPIT_URL=http://127.0.0.1:54404`. Heavy aggregates are run sequentially.
Baseline Web executed all 306 inherited tests / 40 files and 39 tooling tests
successfully, followed by lint/types/build. The commit-phase probe subsequently
passed, and both focused files passed all 19 tests after synchronization changed.
Final Web `check:web` passed without interruption: 39 tooling tests,
307 Web tests / 41 files, lint, type generation/check and production build.
Standard `format:check:web`, parsed workflow ordering/`always()` cleanup,
whitespace and exact prompt archive checks passed. The archive differs only
in normalized line endings. Exact hosted outcomes belong to the final-head PR
evidence comment, not to a predecessor run. Publication changes after the
tested implementation are report-only; compare `git diff
9accde3f6fc8a8fa1089edfa6a98d2bb20958deb HEAD -- apps scripts supabase .github
package.json package-lock.json .nvmrc` after temporary config restoration.

The one clean Database baseline also passed without interruption: replay,
lint/advisors, all pgTAP files, every authenticated verifier, four observed
membership orders, positive coverage/actual contributions, consequence and
suspension Realtime checks, 36 consequence races, 24 suspension races,
193-signature audit and type drift. No downstream stage was skipped or
independently substituted for that aggregate. Its database runtime trees were
identical to required b8ab throughout; only CI/Web tests/documentation changed.

Final `check:db` at the tested implementation also passed **uninterrupted**:
61-migration reset/replay, lint/advisors, 109 pgTAP files / 3,465 assertions,
every authenticated verifier, four actual-lock membership orders, coverage,
resurfacing and actual attribution, all moderation/Realtime/Storage checks,
36 consequence races, 24 suspension races, the 193-signature audit and generated
type drift. No stage was omitted or repaired by an independent substitution.

One additional bounded default invocation measured the new recurring step,
not a retry of a failure: **11.112 seconds** locally, including npm/CLI/real OTP
and the remaining verifier flows, four fresh end-state fixtures, no iteration
flag and exit 0. This is not a hosted timing guarantee. The existing 25-minute
Database budget is retained; actual Ubuntu step/job durations are recorded in
the final-head evidence. No CI rerun/waiver is assumed. The final PR workflow
diff selects every area, so no duplicate full dispatch is necessary.

## Bounded recurrence capture

Do not retry a failed operation to erase its result. Capture one failed
invocation before teardown, then stop that experiment:

1. Record exact source SHA, task project/endpoints, CLI/runtime/image versions,
   command invocation/message boundaries and UTC window. Never change a clock
   or restart another worktree's service.
2. For chronology, retain the allowlisted failed tuple/constraint at six-digit
   precision, operation/order and backend PIDs. Distinguish attempted values
   from committed row snapshots after rollback; collect final definitions,
   defaults and triggers. Membership diagnostics already provide that boundary.
   Bracket a bounded 120-sample PG epoch probe with wall/monotonic host values;
   correlate it with task container/WSL time events rather than infer reversal
   from differing timestamp semantics. Do not log unrelated rows/payloads.
3. For Auth, retain only status/code/request time, simultaneous health results,
   task container CPU/memory and PG waits. Inspect matching task Auth/Kong/Mailpit
   logs with credentials, OTPs and emails excluded. A 200 after the failure is
   not request-time readiness evidence. Preserve real OTP verification.
4. For Realtime, record safe channel status transitions/ack timestamps, expected
   event name and synthetic message/topic IDs, canonical committed message row,
   matching identifier-only `realtime.messages` entry and active replication
   slot state. Check transport/filter/recipient suspension independently; do
   not dump bodies, tokens or private payloads. Keep the initial 10-second signal
   assertion and later suspension non-delivery/recovery checks.
5. For focus, preserve the exact full-suite failure and use the commit-phase
   probe plus observable focus assertion; a focused pass cannot replace the
   full Web aggregate.

## Cleanup and review boundary

Only `planets-community-dbrace02-qa` is stopped with backup retained. Temporary
configuration is restored byte-for-byte and both checkouts are verified.
Canonical config SHA-256:
`2E67B7A5CDA9FFC671C31B4461C1C8B896CC75C3BF727F6E406EE573EEFBD8F6`.
The managed draft-review worktree remains attached, not a merged leftover.

Founder review is required for the unmerged stack and explicitly unresolved
historical incidents, not for guessing a missing tuple or approving test-only
focus synchronization. Review the new actual CI race coverage and its final-head
result; do not label the historical membership incident fixed. Cloudflare and
dependency-advisory decisions remain separate. If current controlled gates pass,
09C2B may be scoped next after the founder settles affected-user copy/contextual
warning choices; these technical findings do not decide them or authorize merge.
