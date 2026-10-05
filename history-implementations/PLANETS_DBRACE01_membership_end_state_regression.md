# PLANETS — DBRACE-01: resolve the membership end-state failure

## Goal

Investigate and resolve the intermittent membership-removal failure disclosed by DEPSEC-01. Establish whether the fault is in canonical database behavior, the concurrency verifier/fixture, or its environment. Implement the smallest evidence-supported repair with a meaningful regression test. Preserve membership history, authorization, live coverage and concurrency guarantees.

This task closes a validation finding before the next functional moderation plan. It does not implement 09C2B or choose hosting. Do not classify the finding as harmless merely because reruns pass, and do not assume the new Node version caused it.

## 1. Exact base and workflow

Repository: `lillo24/planets.community`.

The task explicitly selects this unmerged dependency:

- [DEPSEC-01 draft PR #133](https://github.com/lillo24/planets.community/pull/133)
- Branch: `codex/depsec01-dependencies-admin-qa`
- Exact head: `2ae80181ee9ed9cb52012d7b0ad73897330a2c49`
- Its base: WEBHOST-01 #130 at `99e95f90d0105cc3049fa9b76965f328104d8e4b`.
- Required ancestry: 09C2A #126 `f6ce0f6c4d2f6d4ba673e29bedca9262275ff6b7`, 09C1B #125 `c0548a25d39ddc77a92bc02514c83a01f731e9ae`, 09C1A #123 `010471320779ffb5edaa7546b12cdc8f14809d2d`.

Verify remote state and ancestry. Use an isolated worktree/branch, suggested `codex/dbrace01-membership-end-state`, based on the exact #133 head. Open a draft PR targeting `codex/depsec01-dependencies-admin-qa`. This explicitly overrides the usual main-target/automatic-merge defaults. Do not merge this task or its predecessors, or import unrelated latest-main changes. If the selected dependency changed or was merged, inspect and explain the equivalent base before dependent work.

Read applicable `AGENTS.md`, architecture, database workflow and `docs/development/codex-tooling.md`. Follow the repository's Supabase guidance and load its narrow Postgres skill before SQL/migration/security-test edits. Use version-matched primary documentation when needed. No external product document or new founder policy decision is required.

## 2. Starting evidence

Read `docs/development/depsec01-dependency-security-and-admin-qa.md` and the [final evidence comment](https://github.com/lillo24/planets.community/pull/133#issuecomment-5984369573).

The first local full database aggregate failed during membership-removal concurrency with SQLSTATE `23514` and constraint `project_memberships_end_state_valid`. The unchanged targeted verifier then passed twice; remaining gates passed independently. Final-head hosted CI also passed all four areas, but that does not establish the cause of the earlier failure or prove every extra manual verifier ran in CI.

The constraint requires mutually exclusive leave/removal states, end timestamps at or after `joined_at`, and consistent removal actor metadata. Identify which clause failed rather than treating the constraint name as a diagnosis.

Start investigation with:

- `scripts/verify-local-project-membership-commitments.mjs`, particularly `verifyRemovalSerialization`, fixture creation, authenticated transactions and lock assertions.
- Other callers in participation and actual-contribution verifiers if original logs point there.
- `supabase/migrations/20260908164407_project_participation_domain_foundation.sql` for the original constraint/contracts.
- All later definitions/wrappers of `leave_project`, `remove_project_member`, `remove_project_member_as_manager`, identity/locking helpers and membership triggers.
- Membership commitments, live coverage, delegate/organizer authorization, blocking and suspension composition.

Correlate the original error with its actual failing stage. Do not assume the first source candidate is proven to be the failing operation. Inspect replayed database function/trigger definitions, not only an older migration whose implementation may have been replaced or wrapped.

## 3. Reproduce and isolate

Use the supported Node 24.21.0/npm 11 environment and a clean lockfile install. Record actual versions, Postgres/Supabase versions and the exact tested source.

Use a separately named disposable local Supabase project with synthetic users, guarded project/loopback endpoints and isolated ports. Never run resets or cleanup against a shared stack. Reuse existing safety helpers where they fit; restore temporary canonical configuration byte-for-byte afterward.

Retrieve task-owned original logs if available. If not, say so and add redacted diagnostic context around the narrow failure. Capture the failing operation, relevant synthetic membership timestamps/end-state/actor fields, SQLSTATE/constraint, transaction ordering and lock state. Keep tokens, OTPs, cookie jars, private payloads and unrelated data out of logs/committed evidence.

Run a bounded reproduction campaign using fresh fixtures, both operation orders and a documented stopping limit. Use observed transaction/lock coordination to force the race; a fixed delay or a promise that has not settled does not alone prove the server reached the blocking lock. Verify both canonical operations actually execute and that timeouts/unexpected SQL errors fail visibly.

Review stale row reads, lock ordering and reauthorization after waits; timestamp semantics and any fixture clock assumptions; trigger side effects; and cleanup/reuse between runs. Treat clock reversal, future fixture timestamps and host/container timing as hypotheses requiring evidence. Do not apply a global timestamp rewrite, clamp or new retry behavior without proving its correctness for the actual contract.

Once isolated, create a regression that fails on the selected baseline and passes with the repair. Record the pre-fix failure. For a harness-only fault, demonstrate why canonical behavior was valid and why the original assertion/fixture could fail, then test the repaired harness without reducing the race it exercises.

## 4. Minimal repair and preserved contracts

- For a database defect, add a forward migration; do not rewrite existing migration history or drop/weaken `project_memberships_end_state_valid`.
- Keep function signatures, normal result values, expected domain error codes, security-definer search paths, grants/RLS and current identity/role/suspension checks intact unless a demonstrated defect requires a reviewed contract change.
- Preserve one membership episode per accepted request, historical commitments/actual contributions and creator/delegate versus participant authority.
- Preserve exclusive leave/removal state, consistent actor/timestamps, coverage release, capacity/headcount and chat/access transitions. Failed or losing mutations must not leave partial writes or duplicate audit/outbox effects.
- Verify both removal-before-replacement and replacement-before-removal, and corresponding leave behavior where the fix can affect it. Include current manager, revoked/unauthorized actor and suspended-actor checks when the changed boundary touches them.
- Do not hide the failure with retries, longer sleeps, swallowed `23514`, ignored assertions or successful-looking fallbacks. A passing run alone is not a repair.
- If only test synchronization or fixture setup is faulty, change that boundary and explain why SQL/domain behavior stays intact. Do not add an unnecessary migration.

Keep this change focused. No new moderation policy, appeals, notification projection, user-facing consequence UX, dependency migration, Cloudflare/Sentry workaround, production infrastructure or broad UI redesign.

## 5. Validation

Run the new regression and targeted concurrency verifier on the affected artifact. Repeat with fresh fixtures under the documented bounded schedule and retain concise results; do not present finite repetitions as proof of race impossibility.

After the repair, run one uninterrupted full `npm run check:db` against a clean replay of only the disposable task database. It must cover replay, lint/advisors, pgTAP and the repository's authenticated/domain/concurrency/type-drift gates. If it fails, investigate rather than rerunning until green. Preserve and distinguish earlier failures from final results.

Run affected participation, membership-commitment, coverage/actual-contribution and moderation consequence/suspension integrations as justified by the actual change. Check generated type drift and `git diff --check`. Use the standard tooling/format checks for changed files. Run Web/Mobile checks when client-visible RPC behavior, shared tooling or generated types can be affected; do not run unrelated areas solely to inflate the report.

Inspect path classification and exact final-head hosted checks. A targeted local verifier absent from hosted CI remains local evidence; report it accurately. Avoid CI edits unless needed to prevent recurrence. If CI/classifier changes are necessary, follow the repository's required manual full checkpoint, preserve required statuses and scoped validation, and explain recurring cost.

If Docker or a required gate is unavailable, finish independent analysis/regression work and report blocked checks precisely. Do not claim the finding resolved without causal evidence and completed relevant validation. If bounded investigation cannot reproduce or explain it, leave an explicit unresolved diagnostic result with useful instrumentation and exact next evidence needed, without speculative database changes.

## 6. Deliverables and cleanup

Commit a concise report at `docs/development/dbrace01-membership-end-state-regression.md`: exact base/tested/final head, original failure provenance, failing invariant clause and proven cause (or unresolved limits), pre-fix regression, fix rationale, tested transaction orders/side effects, local aggregate and hosted results.

Update nearby docs for changed non-obvious behavior. Link the follow-up from DEPSEC-01 without rewriting its historical failure as a passed run. Archive this exact prompt at `history-implementations/PLANETS_DBRACE01_membership_end_state_regression.md`.

Push a clean draft PR with a concrete review request covering the root cause, preserved database/security contracts and the unmerged stack. Keep the task checkout for review. Restore configuration and stop only task-owned services with disposable data backup retained; do not remove unrelated worktrees or stacks.

Return a short report with branch/base/head/PR, whether this was a database, verifier or environment defect, causal evidence, fixes, checks and remaining uncertainty. 09C2B remains the next functional plan after this finding is addressed and its user-copy/contextual-warning choices are settled.

No merge, deployment, remote preview, shared/production database operation, provider login, resource/billing/DNS change or 09C2B implementation is authorized.
