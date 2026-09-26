# PLANETS STACK-STABILIZATION-01 — Clear Inherited Database Gates

**Task type:** Open-stack stabilization / validation repair  
**Repository:** `lillo24/planets.community`

## Required stack

Base this work on the current top of the completed 04C4 open stack:

```text
PR #93 — 04C4F3B2 Mobile Immediate Saved-Search Matching Notifications
branch: codex/04c4f3b2-mobile-matching-notifications
head:   c72f2d2d9a3a1577568b98f367b02a526bfb3b07
```

PR #93 is open, draft, cleanly mergeable, and intentionally unmerged.

Before implementation:

1. fetch current `origin/main`;
2. verify PR #93 still points to the expected head or reconcile any newer stacked head;
3. branch from the final PR #93 head;
4. do not merge any PR.

Preferred branch:

```text
codex/stack-stabilization-db-gates
```

Open against:

```text
codex/04c4f3b2-mobile-matching-notifications
```

Archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_STACK_STABILIZATION_01_clear_inherited_database_gates.md
```

No external product/design context is required.

---

# Goal

Make the **current complete open stack** pass its inherited database gates without changing product behavior.

Target green gates:

```text
npm run db:reset
npm run db:lint
npm run db:advisors
npm run db:test
npm run db:types:check
```

The currently known inherited problem classes are:

```text
1. DB lint:
   - ambiguous project_id/chat_id-style PL/pgSQL references
   - at least one unused/unread variable in live Project requirement coverage code

2. Full pgTAP:
   - older suites/helpers/fixtures retain stale assumptions
   - some failures involve current live Project requirement-coverage behavior

3. Generated type drift:
   - current schema includes two D1 RPCs absent from committed generated types:
     check_resource_exchange_pending_loan_availability
     list_owned_resource_listing_loan_schedule
```

These are starting leads, not permission to assume all failures. Re-run every gate first and work from the **actual final-head output**.

---

# 1. Repair-only scope

This PR is not a feature slice.

Do not change:

- Resource request/agreement semantics;
- loan reservation semantics;
- Project matching;
- saved-search semantics;
- notification behavior;
- UI/UX;
- authorization policy;
- lifecycle rules;
- moderation/legal/product policy.

A fix is acceptable only when it restores the already-intended current behavior or updates a stale test/type artifact to the current canonical contract.

---

# 2. Establish the exact failure baseline first

After a clean fetch/branch:

```text
npm run db:reset
npm run db:lint
npm run db:advisors
npm run db:test
npm run db:types:check
```

Record exact:

- function names;
- migration/function definitions implicated;
- linter rule/error text;
- failing test filenames/assertions;
- generated diff.

Do not start editing from the previous PR reports alone.

If the actual failure set differs, follow the actual current output.

---

# 3. Do not “make tests pass” by weakening behavior

For every failing pgTAP assertion classify it as one of:

```text
A. implementation bug
B. stale test expectation
C. stale fixture/setup
D. test-order/isolation problem
E. generated contract drift
```

Then fix the correct layer.

Do not:

- delete meaningful assertions;
- weaken RLS/security checks;
- broaden grants;
- suppress errors;
- skip tests;
- change expected values just because current output differs;
- remove concurrency/idempotency coverage.

If a failure reveals a genuine product/domain contradiction rather than stale validation, stop that repair and report it clearly instead of guessing new semantics.

---

# 4. Prefer forward database repair

Do not rewrite established migration history merely to silence lint.

For deployed-schema behavior fixes, add one narrow forward migration such as:

```text
<timestamp>_open_stack_database_gate_stabilization.sql
```

Use `CREATE OR REPLACE FUNCTION`, or drop/recreate only when PostgreSQL requires a signature/result-type change.

Historical test files may be edited when their assumptions are stale.

Historical implementation prompts must not be changed.

---

# 5. DB lint — ambiguous PL/pgSQL references

Fix actual reported ambiguous references using the least invasive technique:

- qualify table aliases;
- rename local variables/output variables;
- use `#variable_conflict use_column` only where consistent with repository style and genuinely clearer;
- avoid changing SQL meaning.

Pay particular attention to functions returning table columns named generically such as:

```text
project_id
chat_id
request_id
membership_id
```

when bodies also reference columns/variables with the same name.

The goal is **lint-clean unambiguous SQL**, not semantic refactoring.

---

# 6. Live Project requirement coverage lint

Inspect the current functions from:

```text
supabase/migrations/20260918102402_live_project_requirement_coverage_domain.sql
```

and every later migration that replaces them.

Known area includes functions such as:

```text
private.lock_project_for_live_requirement_coverage(...)
private.initialize_project_membership_live_coverage(...)
public.claim_project_requirement(...)
public.set_project_requirement_manual_coverage(...)
public.list_project_live_requirement_coverage(...)
```

Do not assume the original migration is still the live final definition; inspect later replacements first.

Remove/repair genuinely unused variables without altering event, locking, coverage, or authorization behavior.

---

# 7. Preserve current SQLSTATE compatibility

The current stack reserves:

```text
40001
```

for genuine PostgreSQL serialization failures and uses:

```text
PT409
```

for explicit application conflicts.

Do not regress this convention.

If any stale test still expects a pre-DB-COMPAT explicit `40001`, update the stale test rather than reintroducing unsafe behavior.

---

# 8. Full pgTAP — run by filename and isolate failures

After baseline full-suite failure:

1. identify each failing `.test.sql`;
2. run the failing file/focused group alone;
3. determine whether it fails independently;
4. compare its assumptions against current schema/function behavior;
5. repair;
6. rerun the focused file;
7. rerun the full suite.

Do not rely on only the new 04C4F tests, which are already known to pass.

---

# 9. Stale structural tests

Some older structural tests may inspect function definitions with brittle string matching.

If the canonical behavior is unchanged but a newer safe implementation changed:

- qualification;
- helper factoring;
- lock syntax;
- conflict SQLSTATE;
- resolver structure;

update the test to assert the **semantic/security invariant**, not one obsolete textual implementation detail.

Do not remove structural checks that protect:

- fixed search paths;
- grants;
- RLS;
- lock behavior;
- safe SQLSTATE;
- expected RPC signatures.

---

# 10. Stale behavioral fixtures

If an older pgTAP fixture now violates a newer valid invariant, repair the fixture.

Examples of legitimate fixture drift may include:

- newer required lifecycle state;
- newer canonical chat/request relation;
- updated conflict code;
- stricter notification shape;
- current Project requirement coverage prerequisites.

Do not weaken production constraints to accommodate invalid old fixture data.

---

# 11. Live requirement-coverage test failures

Treat current 04C3D3A semantics as canonical unless repository evidence shows a real bug:

```text
participant/manual live sources are distinct from commitments;
first source emits covered transition;
last source removal emits needed-again;
generic commitment addition does not imply live coverage;
claim can create missing commitment + coverage atomically;
only current/operational Project state supports live coverage;
creator/manual and participant authorization remain separate.
```

When older tests disagree, trace the intended current contract through:

```text
migration
roadmap
feature docs
current focused verifier/tests
```

Do not casually change coverage event counts or lifecycle behavior.

---

# 12. Chat-related stale failures

For any inherited `chat_id`/Project-chat pgTAP issue:

- preserve the merged 07B2B/07B2C server-authorized chat model;
- preserve current/former/rejoin history rules;
- preserve body privacy boundaries in notifications;
- preserve shared notification resolver behavior.

Fix ambiguous qualification or stale test assumptions only.

Do not reopen E2EE/MLS or redesign chat.

---

# 13. Generated type drift

After clean replay, regenerate canonical database types using the repository command.

The final generated contract must include the two current D1 RPCs:

```text
check_resource_exchange_pending_loan_availability
list_owned_resource_listing_loan_schedule
```

Do not hand-author their signatures if the generator can run.

Verify the generated signatures against the actual database.

Do not include unrelated churn if the generator produces unstable ordering/formatting; use repository-standard generation and formatting only.

---

# 14. D1 generated RPC contract sanity

Confirm the generated RPC signatures match the live D1 migration, including:

```text
check_resource_exchange_pending_loan_availability
  expected profile
  agreement
  expected pending terms
  → is_lend / is_available

list_owned_resource_listing_loan_schedule
  expected owner
  listing
  → canonical active loan schedule fields
```

Do not change D1 SQL just to fit stale generated types.

Schema is source of truth; types follow schema.

---

# 15. Advisors

`npm run db:advisors` already passed in recent slices.

It must remain green after stabilization.

Do not introduce new security/performance advisor warnings.

---

# 16. Clean replay is mandatory

Final validation must begin from a clean local database replay.

Do not prove fixes only against an already-mutated local DB.

At minimum:

```text
npm run db:reset
```

must succeed immediately before the final database validation sequence.

---

# 17. No hidden shared-environment dependency

The stabilization PR should be fully verifiable on the repository's intended local Supabase stack.

Do not depend on:

- hosted Supabase;
- production data;
- external Firebase;
- external credentials;
- user-specific manual rows.

---

# 18. Keep existing focused verifiers green

Run relevant existing focused verifiers after the full DB fixes, especially the areas touched by repairs.

At minimum include, when available:

```text
project requirement coverage verifier
resource loan reservation verifier
saved-search verifier
saved-search matching verifier
saved-search notification verifier
push delivery protocol verifier
```

Use actual package script names from the repository.

Do not claim a verifier passed if it did not execute.

---

# 19. Web/Site/Mobile regression

Run:

```text
npm run check:web
npm run check:site
npm run check:mobile
flutter build apk --debug
git diff --check
```

This PR should not need feature-code changes, but full regression protects generated types and shared contracts.

---

# 20. No formatting drive-by changes

The prior reports mention inherited unrelated Site formatting differences.

Do not reformat unrelated files merely to make a repository-wide formatter quiet unless those files are part of the actual required gate.

Keep this PR focused on the database-gate blockers.

---

# 21. Hosted Validation

Attempt hosted Validation once on the final head.

If GitHub again allocates no runner because of billing/spending-limit restrictions, report:

```text
not executed due external infrastructure
```

Do not rerun pointlessly.

Local gates still need to be green.

---

# 22. Roadmap/documentation

Update the roadmap only enough to record:

```text
04C4 remains functionally complete in the open stack
STACK-STABILIZATION-01 clears inherited database validation blockers
```

Do not mark open feature PRs as merged/implemented.

Do not begin 06C2B or Plan 08 in this PR.

---

# 23. Next-feature handoff

After this stabilization PR is green:

## 06C2B

Still requires external/founder inputs:

```text
Firebase Android config
Firebase iOS config
APNs setup
FCM HTTP v1 server credentials
push permission timing
safe push preview policy
self-host-compatible worker deployment target
```

Do not fabricate these.

## Plan 08

Still requires the media-backend decision before permanent storage design:

```text
self-hosted Supabase Storage
vs
external object store such as Cloudflare R2
```

The next feature should be selected only after one of these decision gates is resolved.

---

# Non-goals

Do not implement:

- Firebase/FCM/APNs;
- push permission UI;
- media/storage;
- moderation;
- new Resource behavior;
- new Project behavior;
- UI polish;
- new notification kinds;
- per-search notification controls;
- production infrastructure;
- migration squashing;
- PR merging.

---

# Acceptance criteria

- [ ] based on exact PR #93 head;
- [ ] exact prompt archived;
- [ ] actual current failures captured before editing;
- [ ] one focused forward DB repair migration if production functions require changes;
- [ ] no product behavior redesign;
- [ ] `db:reset` green;
- [ ] `db:lint` green;
- [ ] `db:advisors` green;
- [ ] full `db:test` green;
- [ ] `db:types:check` green;
- [ ] two D1 loan RPCs appear in generated types;
- [ ] ambiguous PL/pgSQL references eliminated;
- [ ] unused-variable lint eliminated;
- [ ] stale tests repaired rather than production security weakened;
- [ ] current PT409/40001 convention preserved;
- [ ] live Project coverage semantics preserved;
- [ ] Project chat semantics preserved;
- [ ] focused affected verifiers green;
- [ ] Web/Site/Mobile regression green;
- [ ] debug APK green;
- [ ] no unrelated formatting churn;
- [ ] hosted CI attempted once and reported accurately;
- [ ] no new feature scope;
- [ ] no PR merged.

---

# Completion report

Return:

1. Stack/base status
2. Stabilization branch/base/PR
3. Initial exact failing gates
4. Changed files
5. Forward migration/DB repair summary
6. DB lint root causes
7. Ambiguous-reference fixes
8. Unused-variable fixes
9. pgTAP failure classification
10. Production bugs found/fixed, if any
11. Stale structural tests updated
12. Stale behavioral fixtures updated
13. Live coverage behavior verification
14. Chat behavior verification
15. PT409/40001 compatibility verification
16. Generated-type regeneration
17. D1 loan RPC type entries
18. `db:reset`
19. `db:lint`
20. `db:advisors`
21. focused pgTAP
22. full `db:test`
23. `db:types:check`
24. focused integration/verifier results
25. Web validation
26. Site validation
27. Mobile validation
28. debug APK
29. diff/format checks
30. Hosted Validation executed/not-executed
31. Remaining inherited failures, if any
32. Any genuine unresolved design/logic issue
33. 06C2B external prerequisites status
34. Plan 08 media-decision status
35. Warnings/blockers
36. Commit/PR reference

Do not merge any PR.
