# 09C1A moderation consequence review report

Status on 2026-10-02: implementation ready for required founder domain/security
review; **draft and unmerged**. The complete local database gate passed on an
isolated QA stack, including migration replay, lint/advisors, all pgTAP tests,
the existing verifier matrix, both new consequence verifiers and type drift.
Mobile, Web, Site and hosted CI also passed on the code/test head recorded below.
No migration has been applied to a shared or production environment. No
production deployment or merge is authorized.

## 1. Summary

Two additive migrations introduce manual reversible safety notices, outbound
interaction restrictions and Project/Resource content hides. Four pgTAP files,
a ten-identity real-auth verifier and a 36-race concurrency verifier cover the
new boundaries. All 108 pgTAP files / 3,415 assertions and both new verifiers
have passed locally together in a complete `check:db` sequence. Earlier local
clock rollback and cross-worktree stack replacement are documented in section 22;
neither was worked around by weakening domain constraints or tests.

## 2. Git and approved base

Branch: `codex/09c1a-moderation-consequence-domain`, isolated managed worktree.
Approved base: `main`, `11155618e0aa7bf0de62ae178f79d4c0c50ac644`.
The founder explicitly approved using main after inspection of merged PR #120
and organizer-aware capacity PR #121. This supersedes the archived prompt's
older `f5958e00e9b1abb02b079f5489b769502fb3c88b` candidate/base-branch clauses.
Main was refetched and remained at the approved SHA during final local validation.
Validated code/test head: `4673818d8b56bd2805c21d6230cf9a3053d73139`.
The final report-only follow-up does not change any runtime, migration, test,
generated type, dependency or CI configuration; its final SHA and normal hosted
run are recorded on the PR to avoid a self-referential report commit.
[Draft PR #123](https://github.com/lillo24/planets.community/pull/123) into main
is the authoritative head-SHA/link artifact; no direct
main push, merge, or branch/worktree cleanup has occurred.

## 3. Consequence model

Private episodes own immutable case, type, affected profile and optional content
target. Only a one-way revoke timestamp closes an episode. Append-only actions
link staff actors, user-facing reasons and ordinary case notes. Restrictive FKs,
RLS, revoked direct API-role grants and partial active uniqueness preserve
history. Reapply creates a new episode; suspension is not a valid type.

## 4. Apply/revoke contract

Expected-identity staff commands derive targets server-side. Apply requires
`under_review` or `completed`; received cases fail. Both commands recheck current
moderator/admin and hold a staff-role share lock. Each transaction appends its
private note/action and identifier-only audit/outbox atomically. Case state
does not change. Duplicate active apply or repeated revoke returns `PT409`;
there is no retry key or silent idempotent success.

## 5. Reason/note privacy

Both operations require trimmed plain-text user reasons of 1–2000 characters
and private notes of 1–4000 characters. Only private actions/notes store bodies.
Own history excludes staff identity, notes, evidence, reporter and case IDs.
Verifiers emit only safe steps/codes, never tokens or sensitive bodies.

## 6. Safety notices

A private active predicate and own/staff histories exist. Notices have no
authorization, public profile, reputation, photo, account or relationship
effect. Contextual counterparty APIs and warning UX are deliberately absent.

## 7. Interaction restrictions

Only new outbound Project join and Resource listing requests are forbidden.
Publishing, profile/settings, reporting, incoming-request management and
accepted coordination retain their existing authorization. This is not suspension.

## 8. Creator/delegated acceptance

The canonical Project manager-interaction helper checks the requester after
serialization. Both compatibility and six-array triaged overloads for Creator,
Co-creator and Co-organizer flow through that helper. A restricted manager can
still accept an unrestricted requester. Revoked delegates remain excluded by
the existing manager-set convergence checks.

## 9. Pending withdrawals

Restriction apply withdraws only the subject's still-pending outbound attempts
under the existing concrete/shared Project or listing/request locks. Canonical
withdrawal events and resolved-by requester identity are retained; the separate
consequence action records the staff decision. Accepted/terminal rows remain.
Revoke does not resurrect attempts.

## 10. Proposal hide

Public search/list/detail, capacity, Needs, covers and contextual photo access
exclude hidden Projects. New requests and pending acceptance fail. Pending
status and published/cancelled lifecycle remain independent. Withdrawal,
rejection and ordinary private owner/manager operations are preserved.

## 11. Tavolo hide

List, occurrence and exact detail—including paused/ended historical detail—are
suppressed. Ordinary authorized pause/resume/end cannot clear hide. Unhide
restores only the visibility barrier, never resumes an ended activity.

## 12. Resource hide

Discovery/detail, new requests, pending acceptance and new match delivery are
blocked. Pending requests remain pending, withdrawal/rejection remain valid,
and owner editing/closing does not clear hide. Unhide never republishes closed
content. Accepted agreements, terms, milestones, loan-return and chats are not
rewritten or given new consequence checks.

## 13. Cover/photo/matching controls

Public cover-object authorization uses the same canonical hide predicates, so
a known path cannot bypass hiding. Bytes are not deleted and owner management
remains. Hidden content no longer supplies public contextual photo access;
independent accepted relationships and truly public photos retain the existing
photo boundary. Candidate/new-listing matching filters hidden listings. Immediate
match resolution and its dispatch wrapper are volatile; resolution takes a listing share lock before revalidation
to serialize new delivery with hide; historical match facts/deliveries remain.

## 14. Existing relationships

Accepted membership, chat entitlement/history, meeting access, workspace,
commitments, capacity occupancy and Resource agreement/chat access retain their
canonical rules. The new pgTAP integration and authenticated HTTP checks passed
for these boundaries.

## 15. Concurrency and locks

New interactions acquire requester profile moderation lock → deterministic
manager/owner block pairs → concrete/shared Project or listing → revalidation
and canonical mutation. Hide shares the content lock; restriction shares the
profile lock and closes pending attempts under domain locks without reversing
pair-lock order. The verifier observes actual PostgreSQL lock waits, not just
sleeps, and asserts both winner-order final states across nine operations and
both consequence types (36 races), plus the final-capacity-spot regression.
All 36 winner-order races and the final-capacity-spot scenario passed locally,
with actual wait events and final persisted states asserted.

## 16. Own reads

Identity-bound history uses a complete timestamp/ID keyset cursor, default 20
and maximum 50. Profile consequences belong only to the subject; Project hides
only to immutable original Creator; Resource hides only to owner. Delegates
do not inherit Creator reasons. Current staff has a separate case-action history.

## 17. 09C2 outbox

Six `moderation.<safety_notice|interaction_restriction|content_hide>_<applied|revoked>`
source types contain consequence/action/case/affected-profile and optional
content identifiers only. They are intentionally unconsumed until 09C2.
No notification copy, push, email or Realtime projection was added.

## 18. Blocking, authority and capacity

No block episode is created/revoked by moderation. Unblock does not remove a
restriction; restriction revoke does not remove a block. Existing all-current-
manager convergence, photo trust, lifecycle, contribution triage and organizer-
aware capacity logic are retained. The new barrier precedes any spot,
membership or commitment mutation.

## 19. Audit and evidence

Consequence metadata is identifier-only. Evidence APIs have no added consequence
checks. The existing reporting verifier now scopes its no-evidence-outbox
assertion to its own case: legitimate consequence-source events elsewhere must
not invalidate the reporting contract. This strengthens coexistence without
allowing report/evidence payloads into generic outbox state.

## 20. Validation

| Check                                 | Result                                                                                                                                   |
| ------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| Mobile `check:mobile`                 | Passed again: 408 files formatted with zero changes, analysis clean, 1,077 tests                                                         |
| Site `check:site`                     | Passed again: 34 client + 19 waitlist tests, lint/types/build/deploy dry-run                                                             |
| Web `check:web` after type generation | Passed: 33 files / 142 app tests, lint/typecheck/production build                                                                        |
| `test:tooling`                        | Passed: 24 tests as part of the final Web gate                                                                                           |
| `db:reset`                            | Passed: full canonical migration replay and seed                                                                                         |
| `db:lint` / `db:advisors`             | Passed: no schema warnings or security findings                                                                                          |
| `db:test`                             | Passed from the complete gate's clean reset: 108 files / 3,415 assertions                                                                |
| `check:db`                            | Passed end-to-end, exit 0, on the isolated local QA stack described in section 22                                                        |
| Existing database verifier matrix     | All existing verifiers passed together in that complete gate, including inherited lifecycle, membership, blocking and capacity checks    |
| New authenticated verifier            | Passed in the complete gate: ten real OTP identities, staff/own-reason privacy, preserved coordination and HTTP cover denial/restoration |
| New concurrency verifier              | Passed in the complete gate: 36 winner-order races across all acceptance overloads, plus final-capacity-spot regression                  |
| `db:types` / `db:types:check`         | Passed: CLI-generated public types include the four new RPCs; no regeneration drift                                                      |
| New Node verifier syntax              | Passed `node --check` for both entrypoints and shared fixture module                                                                     |
| `format:check` / `git diff --check`   | Passed: Web/Site formatting, 408 Dart files unchanged, clean diff whitespace                                                             |

The earlier Web test/worker-start timeouts during concurrent validation were
resolved by an isolated bounded-worker run. The final standard `check:web`
command itself subsequently passed; no Web test was weakened or skipped.

There are 108 pgTAP files / 3,415 assertions in the final inventory (104
inherited + 4 new). The approved main already contains founder-QA tests 106 and
107, so this plan uses globally unique numbers **108–111**, superseding the
prompt's older maximum-105 inventory. No mobile production code changed and no
new Android APK was built. Web validation passed again after type generation.

## 21. Demo

`demo:reset:local` → `demo:verify:local` → `demo:seed:local` →
`demo:verify:local` passed again on the isolated QA stack. The deterministic local world and its media,
Messages, notifications, chats, public discovery, RLS and protected-location
checks remained valid after reseeding. No demo source/assets/persona definitions,
production data or shared environment were changed; only the explicitly local
database and synthetic Storage fixtures were reset/seeded.

## 22. Environment and hosted CI

The earlier Docker Desktop inference-manager startup failure was resolved when
the founder opened Docker Desktop. Engine 29.3.1 responded; local start and full
migration reset succeeded. No factory reset, Docker data deletion, service
reconfiguration or remote database fallback was attempted.

The first complete local database gate later encountered SQLSTATE `23514` in
the inherited `remove_project_member` flow: PostgreSQL logged a removal time
77 ms before its membership's creation time, after already logging later
statements. The unchanged coverage verifier passed immediately on rerun. A
second complete gate failed inherited Tavolo lifecycle tests when pause/end
timestamps preceded publication. A read-only 2,000-query `clock_timestamp()`
probe independently detected two backward steps, the largest about **1.16
seconds**. The active Linux clocksource is `tsc`; alternative Hyper-V sources
exist, but no kernel/host clock configuration was changed. The underlying
host/VM cause remains undiagnosed. No timestamp constraint or test was weakened.

After the founder authorized a restart, the execution policy rejected the Docker
Desktop management command before execution; no Docker Desktop/WSL restart was
performed. A later read-only 10,000-query clock probe observed zero backward
steps, and a host/database sample differed by 1 ms. These observations justified
resuming validation but do not establish a permanent clock repair.

The next full gate passed pgTAP and the existing verifier matrix, then received
`PGRST202` from the new RPC. PostgreSQL inspection confirmed that both new
migrations and the consequence table/function were absent: while the gate was
running, the shared `planets-community` database container had been recreated
with the `07c4-unified-project-people` worktree label and that branch's migration
history. This was a cross-worktree test-stack collision, not an API-cache or
consequence-domain failure. No further reset/stop of that shared stack was made.

The successful full gate used an ephemeral project identity
`planets-community-09c1a-qa` in this isolated worktree's local config, with API
54331, database 54332, shadow 54330, Studio 54333, Mailpit 54334, analytics 54337,
pooler 54339 and inspector 8084. Ports were checked free before startup. The
pinned CLI remained `2.118.0-beta.39`; all migrations, seeds, auth/security
settings and verifier implementations were unchanged. Following the
[Supabase CLI configuration reference](https://supabase.com/docs/guides/local-development/cli/config),
only project identity and port assignments were temporarily overridden.

Startup was `npm run db:start -- --exclude imgproxy,studio,edge-runtime,vector,supavisor`;
the excluded optional UI/image/Edge services are not used by this database gate.
Validation was the unmodified `npm run check:db` with
`MAILPIT_URL=http://127.0.0.1:54334`. Existing helpers discovered API/database
endpoints from project-scoped CLI status. Docker labels and migration history
confirmed the isolated target before validation and retained both new migrations
afterward. The complete sequence exited 0 without skipping any check. The full
demo reset/verify/seed/verify sequence also passed on this stack. After checking
the container's project/worktree labels, cleanup used
`npm run db:stop -- --project-id planets-community-09c1a-qa --no-backup`.
Only this ephemeral stack and its synthetic-data volumes were removed; they are
reproducible from the migrations and demo commands. The original config was
restored, and no temporary identity or port override is part of the PR.

The initial hosted attempt, [36992489535](https://github.com/lillo24/planets.community/actions/runs/36992489535),
allocated runners successfully: classification, Site, Web and Mobile passed; database
replay passed, then lint flagged a stable dispatch wrapper calling the now-
volatile locking matching resolver. The migration now propagates volatility to
that wrapper without changing event routing. Fixture review also corrected
exact seven-day invitation timestamps and invitation-matching delegation time.
The revised-head run [36993592274](https://github.com/lillo24/planets.community/actions/runs/36993592274)
passed classification, Site, Web and Mobile, and applied both new migrations
during start. Its following reset failed at Docker container bootstrap with
exit 125 before lint/tests; it was not rerun unchanged. Local replay/lint now
validate the wrapper fix. The final code/test head
`4673818d8b56bd2805c21d6230cf9a3053d73139` passed the normal PR-triggered run
[36996582681](https://github.com/lillo24/planets.community/actions/runs/36996582681):
classification, Mobile, Web, Site and Database all succeeded. The Database job
also passed both new verifiers, local-configured web build, web Auth/Tavoli checks
and generated-type drift. The report-only follow-up gets its normal final-head
attempt; its exact SHA/run/outcome is recorded on the PR. No hosted gate is
waived, and the old billing exception does not apply to these runner-allocated
attempts. CI now invokes both new
verifiers inside the existing Database job; no extra recurring workflow exists.

## 23. Deferred scope

09C1B account suspension/global enforcement; 09C2 admin/mobile consequence UX,
contextual warnings and notification projection; founder-policy-dependent 09C3
appeals; 09D minimum age; Plan 10 retention/deletion/anonymization all remain
deferred. No automated punishment, reputation score, delegate revocation,
membership removal or accepted Resource termination was implemented.

## 24. Stop-worthy findings and remaining work

The base discrepancy was resolved by explicit approval to use current main.
Owned fixture defects were corrected: schema-qualified pgTAP assertions need
their explicit description overloads, Storage tests need the exact-download
operation context, and new test numbers must follow main's actual maximum 107.
These changes correct verification, not product policy or inherited assertions.

There is no remaining repository-owned validation failure on the validated
code/test head. The earlier clock fault's underlying cause is not claimed fixed;
the later complete isolated gate passed without any timestamp workaround.
Future concurrent local QA must use distinct project identities/ports or be
coordinated to avoid another shared-stack replacement. Founder domain/security
review of manual consequence scope, reason privacy, lifecycle independence and
locking remains required. The PR must remain draft/unmerged; no deployment is
in scope.
