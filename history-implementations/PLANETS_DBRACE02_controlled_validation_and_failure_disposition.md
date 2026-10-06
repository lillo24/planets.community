# PLANETS DBRACE-02 — controlled validation and failure disposition

Work in `lillo24/planets.community`. Complete this maintenance task in an isolated worktree and a draft PR. Read the repository's `AGENTS.md` and relevant database, validation and moderation documentation first. Continue autonomously within this scope; use the existing reports as evidence, not as proof that failures were repaired.

## Goal

Close the CI coverage gap exposed by DBRACE-01 and give each recorded local failure an evidence-based disposition. Repair only causes demonstrated by source inspection and controlled reproduction. Do not make recovery of the missing historical failed tuple a prerequisite for finishing this task.

This task does not implement 09C2B. Do not merge, deploy, select hosting, provision external infrastructure, change billing/DNS, or alter production data. Cloudflare blockers and the remaining dependency advisory are outside scope.

## Exact starting point

- Predecessor: draft [PR #136](https://github.com/lillo24/planets.community/pull/136).
- Branch: `codex/dbrace01-membership-end-state`.
- Required base: `b8ab159b5bcb643b477cdaa60b0484b7ad0d0e8f`.
- Its predecessor: #133 at `2ae80181ee9ed9cb52012d7b0ad73897330a2c49`.
- Create `codex/dbrace02-controlled-validation`, stacked on #136's branch. Verify the required commit and inherited ancestry before editing. Do not substitute latest `main` or incorporate unrelated changes. If the remote predecessor has advanced, preserve the required base and document the difference; do not silently rebase the task.

Read `docs/development/dbrace01-membership-end-state-regression.md`, its linked DEPSEC-01 evidence, and the [final PR report](https://github.com/lillo24/planets.community/pull/136#issuecomment-5991903038). Preserve the distinction between locally tested implementation `43f7414770610bf42070f574bb21a14f2232551a` and the documentation-only final head.

## What is established

DBRACE-01 repaired a verifier synchronization gap: an unsettled HTTP promise after a delay did not prove that a request had reached PostgreSQL. The new observer requires the actual waiter to be blocked by the winning transaction. Its 40 local race cases passed. This proves stronger regression coverage, not the cause or repair of the original `23514 project_memberships_end_state_valid` failure.

Final-head Actions run [37290080647](https://github.com/lillo24/planets.community/actions/runs/37290080647) passed Web, Mobile and Database. Site was skipped. The Database workflow did **not** execute `project:membership-commitments:verify:local`; do not describe those local race cases as hosted CI coverage.

One clean local `check:db` failed in two other chronology constraints:

| Test | Constraint | Recorded ordering |
| --- | --- | --- |
| `026_project_group_chat_access.test.sql` | `project_group_chats_creation_not_before_activation` | attempted `created_at` 08:21:10.172788 UTC before `activated_at` 08:21:10.380508 UTC, by 207,720 microseconds |
| `110_moderation_consequence_integration.test.sql:49` | `project_join_requests_resolution_valid` | attempted `resolved_at` 08:22:08.216757 UTC before `created_at` 08:22:08.559500 UTC, by 342,743 microseconds |

Both occurred on 2026-10-05. Clock adjustment is a hypothesis, not an established cause. The short subsequent clock sampling that found no reversal does not resolve them.

Separate failures also remain: an Auth OTP request returned 504 / `request_timeout`; account-suspension integration missed its **pre-suspension** Realtime signal; full Web validation failed the `already_revoked` alert-focus assertion although the unchanged focused file subsequently passed. Treat these as separate incidents unless evidence connects them.

## 1. Add the missing CI check

Integrate `npm run project:membership-commitments:verify:local` into the existing Database job in `.github/workflows/validation.yml`, after the disposable backend has been started, reset and made ready. Inspect the script's current configuration and prerequisites; supply the existing local Auth/Mailpit/database configuration through established helpers.

Use the normal bounded default run, covering all four leave/removal race orders with observed locks. Do not put the 40-case diagnostic campaign into every PR run. Preserve loopback guards, explicit failure propagation, finite operation deadlines and `always()` cleanup. Never swallow a constraint error or retry a race until it passes.

Confirm the workflow's path classification actually schedules Database when the verifier/helper changes. Add a meaningful classification regression only if the current mapping needs repair. Ensure the new step fits the existing job budget; change that budget only if measured runtime justifies it. Do not duplicate the full database suite inside the new step.

## 2. Establish comparable controlled validation

Use an existing supported Linux environment, including the existing Ubuntu Actions runner, as the comparison to the Windows/Docker run. No new hosted VM, account or paid resource is needed. If local Linux execution is unavailable, say so and use hosted evidence with its limits stated.

Record exact code SHA, Node/Supabase/PostgreSQL versions, OS/container context, migration replay status, service readiness and test commands. Use a fresh task-owned backend and fixtures. Do not touch another worktree's services or change host, WSL or container clock settings.

Run one clean baseline for the affected full checks where practical and one final uninterrupted aggregate after changes. Use targeted reproductions to test specific hypotheses. Bound each experiment before starting; repeat only when a code change or new hypothesis makes the result informative. A successful later run must remain a separate observation from a recorded failure.

## 3. Investigate the chronology failures

Inspect the **final replayed definitions**, defaults, triggers and constraints, not just an older migration with the same function name. Trace the actual statements and transactions in tests 026 and 110. Check whether transaction-start, statement-start or actual wall-clock timestamps, fixture chronology, and `INSERT ... ON CONFLICT` constraint evaluation explain the observed ordering.

Use the official [PostgreSQL 17 datetime documentation](https://www.postgresql.org/docs/17/functions-datetime.html) for timestamp semantics. Capture microsecond precision, the relevant row fields, failed attempted values versus committed values after rollback, backend identity and statement boundaries. If comparing clocks, use bounded paired wall-clock and monotonic observations; distinguish a clock discontinuity from a timestamp taken earlier in a long-running statement or transaction.

Retain the original membership error's missing-evidence limitation. Its creator-removal path obtains `clock_timestamp()` after locking and rechecking state. A different manager RPC's earlier timestamp handling is not proof of the reported creator-path failure. Do not expand scope to repair that RPC without an independently demonstrated defect.

If a database defect is reproduced, add a regression that fails for the demonstrated reason on the base and passes with the repair. Apply the smallest forward migration consistent with repository policy and canonical lifecycle/audit behavior. Verify historical replay and generated type drift as applicable. Do not clamp times with `GREATEST`, relax/drop chronology constraints, rewrite history, add retries, or introduce arbitrary sleeps to obtain green checks.

If an environmental cause is demonstrated, document the exact evidence and supported validation setup. A Linux pass alone does not prove that Windows clock reversal caused the original error. If neither cause is demonstrated, retain the uncertainty and a bounded evidence-capture procedure for recurrence.

## 4. Give each other failure its own disposition

- **Auth 504:** inspect task service logs and readiness at the failed request. Distinguish startup/resource readiness from a repeatable Auth or verifier defect. Use a bounded readiness check if missing readiness is demonstrated; preserve real OTP verification and explicit errors.
- **Realtime:** identify the actual channel status, subscription acknowledgement, committed write and expected pre-suspension event. Demonstrate whether this was listener readiness, transport failure, filtering or product behavior. Preserve the later suspension access and delivery assertions; do not remove the initial signal check or add a retry loop to conceal a missed event.
- **Alert focus:** inspect the component's focus effect and the test's synchronization. The current test observes the alert and then immediately asserts focus, so asynchronous ordering is a candidate to test. If that is the demonstrated cause, await the required observable focus condition. If product behavior is defective, repair the component. Preserve keyboard focus and accessible error behavior; do not weaken the assertion or merely enlarge timeouts.

For every repair, provide a focused regression or other direct evidence appropriate to the defect. Avoid tests that merely repeat the implementation. Do not treat a focused pass as proof of full-suite stability.

## 5. Validate and finish

Run required repository checks for the final changes, including tooling/helper tests, full Web validation and the clean Database aggregate with its authenticated verifiers. If an aggregate stops early, enumerate which subsequent checks did not execute; run necessary remaining checks separately without calling the aggregate passed.

Verify that hosted CI at the exact final head executes the newly added membership step successfully. Use existing workflow dispatch/full classification when needed so Web, Site, Mobile and Database all receive final-head coverage. Record actual successes, failures, cancellations and skips. Keep any rerun history visible and explain why a rerun was warranted. If local validation preceded documentation-only edits, demonstrate runtime equivalence and still cite the exact hosted head.

Write `docs/development/dbrace02-controlled-validation-and-failure-disposition.md`. Include a concise disposition table for the historical membership incident, both chronology failures, Auth, Realtime and focus: evidence, cause established or unknown, repair if any, final local/hosted result and remaining limitation. Link the prior reports without rewriting their failures as successes. Document the added CI coverage and runtime cost.

DBRACE-02 may finish with the historical membership incident explicitly **unexplained**, provided current controlled gates pass and no reproducible defect remains untreated. Do not label that incident fixed. If a current gate still fails, leave it visible and explain its practical consequence; do not launch an unbounded follow-up campaign or silently waive it.

Commit the scoped changes, push the branch, and open a draft PR targeting `codex/dbrace01-membership-end-state`. Leave the whole stack unmerged and undeployed. State exactly what requires founder review. Keep 09C2B's user-facing copy/contextual-warning decisions separate from these technical findings, and recommend its next step only from the resulting evidence.

Stop only task-owned services, retain the agreed backup, restore temporary configuration and verify checkout cleanliness. Finish with the PR URL, exact base/head, repairs, unresolved findings, final-head CI evidence and a clear next action.
