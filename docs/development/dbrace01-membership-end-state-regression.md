# DBRACE-01: membership end-state investigation

Evidence date: 2026-10-05. **Unresolved diagnostic result, draft only.**
The original DEPSEC-01 membership `23514` is not explained or repaired by a
passing rerun. No SQL migration, timestamp clamp, retry, constraint weakening,
client contract change, merge, deployment or 09C2B implementation occurred.

## Exact source and isolation

- Selected dependency/PR target: [DEPSEC-01 #133](https://github.com/lillo24/planets.community/pull/133),
  `codex/depsec01-dependencies-admin-qa`, exact head
  `2ae80181ee9ed9cb52012d7b0ad73897330a2c49`, still open/draft when checked.
- Verified predecessor ancestry, all open: #130
  `99e95f90d0105cc3049fa9b76965f328104d8e4b`, #126
  `f6ce0f6c4d2f6d4ba673e29bedca9262275ff6b7`, #125
  `c0548a25d39ddc77a92bc02514c83a01f731e9ae`, #123
  `010471320779ffb5edaa7546b12cdc8f14809d2d`.
- Branch: `codex/dbrace01-membership-end-state`; tested implementation commit
  `43f7414770610bf42070f574bb21a14f2232551a`. Final publication head and
  exact-head hosted results are recorded in the draft PR body/evidence comment
  (a committed report cannot contain its own Git object ID). Subsequent changes
  are reports/prompt only; compare `git diff 43f7414770610bf42070f574bb21a14f2232551a HEAD -- apps scripts supabase .github package.json package-lock.json`.
- Separate managed task worktree; no latest-main work imported. The primary
  checkout independently advanced to `f291bdd017ba0509b4aba7e80dd655457c26c3bf`
  during validation. This task did not edit it or other worktrees/stacks.
- Clean lockfile install: Node **24.21.0**, npm **11.19.0**, embedded Undici
  **7.29.1**; 840 packages added, 843 audited. Eight inherited high-severity
  no-fix braces findings remain the separate DEPSEC review item. No dependency
  or install-script approval changed. The host npm launcher uses Node 24.13.0;
  supported runs used the selected Node and npm's `npm-cli.js` explicitly.
- Supabase CLI **2.118.0-beta.39**, Docker **29.3.1**, replayed PostgreSQL
  **17.6**, Flutter **3.47.2** / Dart **3.13.2**. No platform upgrade.
- Disposable project `planets-community-dbrace01-qa`: API 54381, DB 54382,
  shadow 54380, pooler 54389, Studio 54383, Mailpit 54384, inspector 8091,
  analytics 54387. API/DB/Mailpit targets are loopback guarded and derived from
  this worktree's project-scoped CLI status; only synthetic fixtures are used.

## Original failure: what is actually known

The [DEPSEC report](depsec01-dependency-security-and-admin-qa.md) and
[final evidence comment](https://github.com/lillo24/planets.community/pull/133#issuecomment-5984369573)
remain historical evidence, not a clean aggregate pass.

The task-owned retained session output identifies the exact failing stage:
`verifyRemovalSerialization`, **complete removal after replacement wins**,
`scripts/verify-local-project-membership-commitments.mjs:560` on the selected
baseline. It was the creator's HTTP `remove_project_member` after the participant's
authenticated SQL replacement committed, not the manager-named RPC. The original
Node version was already 24.21.0. Aggregate output was retained at
2026-10-04 20:02:38 UTC; its filtered database-log excerpt records the error at
20:02:17.124 UTC, authenticator backend PID 2541, SQLSTATE **23514**, constraint
**project_memberships_end_state_valid**.

The original failing tuple/DETAIL, exact membership ID, actor and timestamps
were **not retained** in that excerpt. Consequently the failed invariant clause
and original cause remain **unknown**. Tokens, OTPs, raw session logs and private
payloads are not copied into this report. No retained Windows Kernel-General
clock-change event (ID 1) was found in the 20:00–20:05 UTC window; this does not
exclude a Docker/WSL clock adjustment.

## Canonical boundary review

Replayed function/trigger definitions were inspected, not just old migrations:

- Creator removal and participant leave are the definitions from
  `20260913134856_project_chat_message_domain_realtime.sql`. Both find the Project,
  take concrete/shared Project locks, reread the membership `FOR UPDATE`, recheck
  actor/current-membership conditions, then obtain `clock_timestamp()`. Removal
  sets the end time and authenticated actor together; leave sets only `left_at`.
  The constraint retains exclusivity, both end-time chronology clauses and the
  removal actor pair. Identity helpers still compose account suspension.
- `remove_project_member_as_manager` uses an earlier `statement_timestamp()`
  assignment before its locks. That is a separate timestamp concern, **not the
  observed failing creator RPC**. It was not opportunistically changed.
- Acceptance uses canonical triage and a server `statement_timestamp()` for the
  membership episode. The verifier creates/publishes/requests/accepts through
  authenticated RPCs; its 2098 Proposal schedule is not a future `joined_at`
  injection. Fresh fixtures have distinct requests/memberships; no reuse of an
  ended episode or direct timestamp rewrite occurs in the race campaign.
- The capacity BEFORE trigger returns the membership unchanged; ended coverage
  release is AFTER the end-state update. INSERT triggers seed commitments,
  initialize coverage and ensure chat. No timestamp/actor-rewriting trigger was
  found. Commitments serialize on the same Project/membership boundary.
- Creator/delegate authority, stale/ended rechecks, one current membership,
  historical commitments/actual contributions, RLS/grants/search paths, block
  and suspension enforcement are untouched. Neither an unauthorized actor nor
  a stale unlocked membership read was demonstrated as the original cause.

[PostgreSQL 17 timestamp semantics](https://www.postgresql.org/docs/17/functions-datetime.html#FUNCTIONS-DATETIME-CURRENT)
distinguish statement-start time from actual wall-clock time; they do not justify
a timestamp clamp or a claim that the original environment reversed its clock.

## Proven verifier gap and focused changes

The baseline lock assertion only delayed 250 ms and tested whether a promise
was unsettled. An extracted baseline assertion accepted `{ settled: false }`
even when **no server request existed**. A regression requiring that assertion
to reject failed with `AssertionError: Missing expected rejection` on Node
24.21.0. This proves missing synchronization evidence, **not a cause of 23514**.

The new `membership-race-evidence` helper has 12 regression tests. It requires
one observed PostgreSQL lock waiter blocked by the exact authenticated winner
PID, rejects unrelated/ambiguous/non-lock waits and observer errors, and fails
when the loser settles before observation or the monotonic deadline expires.
The serial verifier starts exactly one HTTP loser on a fresh Project; canonical
SQL winner and HTTP loser results are both checked. All eight existing
leave/removal/resource/skill race assertions use this observation.

The initial observer implementation filtered activity query text by RPC name.
After all 40 end-state cases passed, the wide Proposal-update case timed out
with 57014: the name starts at character offset 1017 in a 2,371-character
statement and is not fully present in the configured 1 KB activity snapshot.
This introduced observer error was investigated and corrected, not ignored:
the final observer uses exact blocking PIDs and rejects ambiguous waiters,
without depending on truncated query text. No production configuration changed.

Leave/removal failure evidence now records operation/order/stage, synthetic
membership/actor IDs, membership times, server clock samples, observed PIDs and
scoped coverage/occupancy/event counts. A committed row after rollback is labelled
separately from the failing UPDATE tuple. Only the known eight-column membership
tuple is parsed from PostgREST or SQL-driver details; arbitrary messages/details
are not logged. Clause comparisons preserve microseconds. Missing/unrecognized
DETAIL remains unavailable rather than guessing a failed clause.

A rollback-only diagnostic probe deliberately moved a synthetic current
membership's join time one day forward, then called canonical creator removal.
The real error parsed as 23514 and `removed_at_at_or_after_joined_at`; the
original membership timestamps/end state were unchanged after rollback. This
checks diagnostic parsing, **not reproduction of the DEPSEC cause**. The forward
timestamp was never committed or added to canonical fixtures.

See [database workflow](database.md) for guards, 10-second observation deadline,
20 ms polling, verifier-only 15-second statement/HTTP limits and campaign CLI.
There are no retries, swallowed 23514 errors or success-shaped fallbacks.

## Bounded reproduction and validation

Campaign limit: **10 iterations**, four fresh accepted memberships per iteration,
stop at first unexpected failure. Both end-first and replacement-first orders
were exercised for leave and creator removal. The initial development run passed
all 40 end-state cases before the separate wide-RPC observer failure described
above. After that evidence-supported observer correction, the full targeted
verifier with `--race-iterations=10` passed: **40 observed end-state races**, plus
its other authorization/lifecycle/rejoin/resource/skill checks. Each loser was
observed waiting on `transactionid` behind the winner. The original 23514 did
not reproduce; finite repetitions do not prove it impossible.

Postconditions check exclusive valid end state, correct actor, zero current
membership occupancy, zero live coverage rows, exactly one end audit/outbox
event, expected commitment-event count and preserved final historical
commitments. These fresh races start without coverage, so they do **not** by
themselves prove release of positive coverage or every chat/manager/security
composition. Dedicated integrations/pgTAP remain necessary.

### Clean aggregate: failed, not rerun until green

One uninterrupted `npm run check:db` was run on the tested implementation,
resetting **only** the disposable project. Replay, lint and security advisors
passed. pgTAP failed: **109 files, 3,395 executed assertions**, two files exiting
before their final TAP plan. No aggregate retry was run.

- `026_project_group_chat_access.test.sql`: reconciliation violated
  `project_group_chats_creation_not_before_activation`. For the existing normal
  Project `e7100000-0000-4000-8000-000000000001`, activation was
  `2026-10-05 08:21:10.380508+00` but attempted creation was
  `2026-10-05 08:21:10.172788+00` (207,720 microseconds earlier).
- `110_moderation_consequence_integration.test.sql:49`: canonical acceptance
  violated `project_join_requests_resolution_valid`. The synthetic request's
  `created_at` was `2026-10-05 08:22:08.5595+00`, attempted `resolved_at`
  `2026-10-05 08:22:08.216757+00` (342,743 microseconds earlier).

These are observed server-generated chronology inversions in unchanged database
code. They are **not** the original membership constraint failure. Clock behavior
is a candidate requiring further evidence, not a license to weaken several
domain invariants. A separate bounded read-only probe (30 batches / 3,000,000
`clock_timestamp()` samples over approximately 5.99 seconds) observed **zero**
negative adjacent deltas. It neither establishes nor rules out an intermittent
host/container clock reversal. No clock setting or shared service was changed.

Authenticated integration stages and type drift were not reached by the
aggregate. The independent follow-ups do not convert it into a pass:

- **Passed independently:** the final membership verifier (four further observed
  end-state races plus all other flows), positive live coverage cleanup/rejoin,
  actual contributions including post-end leave/removal races, authenticated
  moderation consequences, **36** consequence winner orders, **24** suspension
  winner orders, **193**-signature suspension/broadcaster audit and generated
  database type drift (no diff).
- **Failed:** participation integration stopped before domain verification at
  the OTP request. Task Auth logs record HTTP **504 / request_timeout** at
  08:27:41–42 UTC; Auth/Kong/Mailpit were subsequently healthy and no database
  lock wait remained. The failure is retained; later successful OTP-based gates
  do not rewrite this invocation as passed.
- **Failed:** account-suspension integration reached its pre-suspension live
  signal check and stopped at `waitSignal`, line 658, called from line 349:
  `Expected committed private signal was not delivered.` It was not retried or
  treated as a successful suspension/Realtime gate.
- **Tooling:** all **39** tests passed, including the 12 new evidence regressions.
- **Mobile:** full `check:mobile` passed: localization, 411-file formatting
  (no change), static analysis and **1,087** tests. The Dart analysis skill was
  used to verify the existing configuration/output; no Dart fix or source change.
- **Web:** full `check:web` failed on the unchanged `already_revoked` alert-focus
  assertion in `moderation-consequence-components.test.tsx:316`: **305/306**
  tests passed across 40 files. The expected alert existed, but focus remained
  on the Reason textarea. No UI/test change was made to manufacture a pass.
  Independent Web lint, type generation/check and production build passed.
  The unmodified focused component file subsequently passed **18/18** tests;
  that diagnostic rerun does not turn the earlier full aggregate into a pass
  or establish the focus failure's cause.
- **Formatting/whitespace:** standard `format:check:web`, focused report
  formatting and `git diff --check` passed; exact prompt archive comparison
  passed after line-ending normalization.

Classification against #133: **Mobile=true, Web=true, Database=true,
Site=false**, because `scripts/lib` is conservatively shared tooling. No Site
source, dependency or contract changed, so its unrelated suite was not rerun.
No CI/classifier/trigger/cost change was made. The new helper regressions run in
the existing Web tooling gate; the actual membership-commitment verifier is
**absent from hosted Database CI** and its race results remain local evidence.
Exact final-head hosted job results/skips/availability are recorded in the draft
PR evidence comment, not inferred from predecessor badges or locally run stages.

### Cleanup

Only `planets-community-dbrace01-qa` was stopped with CLI-confirmed `backup=true`.
Its database, Storage and Edge volumes remain retained. Temporary configuration
was restored **byte-for-byte**, SHA-256
`2E67B7A5CDA9FFC671C31B4461C1C8B896CC75C3BF727F6E406EE573EEFBD8F6`.
The primary checkout remained clean. No task Web server/configuration was
created, no unrelated stack/worktree was stopped/removed, and the managed task
checkout remains attached for draft review. The published runtime trees match
the tested implementation; only dated evidence and the exact prompt archive
were added afterward.

## Remaining evidence / required review

Do not close the original finding on this draft. Review the preserved canonical
contracts, synchronization/diagnostic changes and the **unmerged stack**. A next
occurrence needs the actual failed membership tuple and clause, exact operation
and source, before/after server clocks, observed winner/waiter PIDs and rollback
state. Correlate any chronology inversion with guest/host time synchronization
events on a controlled environment before selecting a SQL or environment repair.
The independent local pgTAP chronology and Web focus failures also require
explicit disposition; green predecessor badges cannot replace these results.

09C2B remains the next functional plan only after this finding is addressed and
the founder settles affected-user copy/contextual-warning choices. No moderation
policy, appeals, hosting, provider configuration or production operation was
chosen here.
