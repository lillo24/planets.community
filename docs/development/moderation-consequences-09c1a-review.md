# 09C1A moderation consequence review report

Status on 2026-10-02: implementation prepared for draft review; **not complete
or merge-ready**. Local database execution and generated types are blocked by
Docker Desktop startup failure. Hosted migration replay passed; its initial lint
failure has a scoped volatility fix awaiting validation. No migration has been applied to a shared or
production environment. No production deployment or merge is authorized.

## 1. Summary

Two additive migrations introduce manual reversible safety notices, outbound
interaction restrictions and Project/Resource content hides. Four pgTAP files,
a ten-identity real-auth verifier and a 36-race concurrency verifier cover the
new boundaries. Their database assertions have **not run**.

## 2. Git and approved base

Branch: `codex/09c1a-moderation-consequence-domain`, isolated managed worktree.
Approved base: `main`, `11155618e0aa7bf0de62ae178f79d4c0c50ac644`.
The founder explicitly approved using main after inspection of merged PR #120
and organizer-aware capacity PR #121. This supersedes the archived prompt's
older `f5958e00e9b1abb02b079f5489b769502fb3c88b` candidate/base-branch clauses.
Main was refetched and remained at the approved SHA before draft submission.
The draft PR into main is the authoritative head-SHA/link artifact; no direct
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
canonical rules. New tests assert these boundaries, but execution is still pending.

## 15. Concurrency and locks

New interactions acquire requester profile moderation lock → deterministic
manager/owner block pairs → concrete/shared Project or listing → revalidation
and canonical mutation. Hide shares the content lock; restriction shares the
profile lock and closes pending attempts under domain locks without reversing
pair-lock order. The verifier observes actual PostgreSQL lock waits, not just
sleeps, and asserts both winner-order final states across nine operations and
both consequence types (36 races), plus the final-capacity-spot regression.
These are planned assertions, **not proven race outcomes yet**.

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

| Check                                                                        | Result                                                                                 |
| ---------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| Mobile `check:mobile`                                                        | Passed: 408 files formatted, analysis clean, 1,077 tests                               |
| Site `check:site`                                                            | Passed: 34 client + 19 waitlist tests, lint/types/build/deploy dry-run                 |
| Web initial `check:web`                                                      | Failed: one test timeout and one worker-start timeout during concurrent gates          |
| Web isolated rerun `npm run test --workspace @planets/web -- --maxWorkers=2` | Passed: 33 files, 142 tests                                                            |
| Web lint/typecheck/build                                                     | Passed after the isolated rerun                                                        |
| `test:tooling`                                                               | Passed: 24 tests                                                                       |
| New Node verifier syntax                                                     | Passed `node --check` for both entrypoints and shared fixture module                   |
| `format:check` and `git diff --check`                                        | Passed; rerun after final report/hygiene edits before submission                       |
| `db:reset`, `check:db`                                                       | Blocked at Docker API connection before migration execution                            |
| `db:types`                                                                   | Could not generate against unavailable local stack; generated output remains unchanged |
| New real-auth/race commands                                                  | Blocked before fixtures/Auth/transactions: local Supabase status unavailable           |
| Lint/advisors/pgTAP/existing database verifiers/type drift                   | Not run successfully; require the local stack                                          |

There are 108 pgTAP files in the final inventory (104 inherited + 4 new; unique
numbers 106–109). **No final assertion count is available**, and inherited
prompt counts are not new-feature validation. No mobile production code changed;
no new Android APK was built. Database/generated-type-dependent client checks
must be repeated after successful type generation.

## 21. Demo

Reset/verify/seed/verify idempotency remains unrun because it requires Docker.
No demo assets, personas, production data or shared environment were changed.

## 22. Environment and hosted CI

Docker Desktop failed normal CLI startup in its inference manager while opening
its local socket, then shut down. The Linux Docker named pipe is absent and both
WSL distributions are stopped. No factory reset, Docker data deletion, service
reconfiguration or remote database fallback was attempted. The founder was
asked to restart Docker Desktop; this is the actionable local prerequisite.

The initial hosted attempt, [36992489535](https://github.com/lillo24/planets.community/actions/runs/36992489535),
allocated runners successfully: classification, Site, Web and Mobile passed; database
replay passed, then lint flagged a stable dispatch wrapper calling the now-
volatile locking matching resolver. The migration now propagates volatility to
that wrapper without changing event routing. Fixture review also corrected
exact seven-day invitation timestamps and invitation-matching delegation time.
These scoped fixes require validation on the revised head; no failing gate is
waived. Record the revised-head attempt on the PR. A billing/runner refusal,
if encountered, is an availability limitation, never a passed gate; do not
rerun unchanged runner-allocation failures. CI now invokes both new
verifiers inside the existing Database job; no extra recurring workflow exists.

## 23. Deferred scope

09C1B account suspension/global enforcement; 09C2 admin/mobile consequence UX,
contextual warnings and notification projection; founder-policy-dependent 09C3
appeals; 09D minimum age; Plan 10 retention/deletion/anonymization all remain
deferred. No automated punishment, reputation score, delegate revocation,
membership removal or accepted Resource termination was implemented.

## 24. Stop-worthy findings and remaining work

The base discrepancy was resolved by explicit approval to use current main.
Docker availability is the remaining blocker; unvalidated SQL/concurrency must
not be treated as safe to merge. After Docker runs: replay and fix any migration
or pgTAP failures, run the complete database gate and all new/affected verifiers,
generate and commit types, run type drift and demo idempotency, then repeat the
affected client/hygiene gates and update this report with actual counts/results.
Founder domain/security review remains required by the plan, and the PR must
remain draft/unmerged. No production deployment is part of this task.
