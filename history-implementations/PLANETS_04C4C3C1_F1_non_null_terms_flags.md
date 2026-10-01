# PLANETS 04C4C3C1 F1 — Non-null Agreement Terms Flags

**Task:** Focused SQL-to-Flutter contract repair before 04C4C3C2.
**Repository:** `lillo24/planets.community`
**PR:** Update existing draft PR #80; do not open another feature PR or merge anything.

## 1. Starting point and scope

Continue on:

```text
PR #80
branch: codex/04c4c3c1-mobile-scambio-negotiation
reviewed head: df7d810812a4c413b690ac2c0c7ab8127931348d
base branch: codex/04c4c3b-mobile-resource-conversation
base head: 1f1b6988166f95be54c486b8781a6520f79f1fc1
```

Fetch and check the current refs before editing. Preserve any newer legitimate work and all unrelated local changes. Do not reset another checkout or rebase the entire dependency stack merely for this fix.

Archive this prompt verbatim as:

```text
history-implementations/PLANETS_04C4C3C1_F1_non_null_terms_flags.md
```

The original C3C1 prompt archive remains unchanged. This follow-up explicitly authorizes **one small forward SQL migration** plus focused tests and technical documentation. It is an exception to the original mobile-only task boundary, not permission to redesign the agreement domain.

## 2. Observed contract mismatch

At the reviewed head, the effective definition of:

```text
public.list_resource_exchange_agreement_terms(uuid, uuid)
```

comes from:

```text
supabase/migrations/20260919195434_reliable_scambio_agreement_loan_barter_domain.sql
```

Its last two selected expressions are:

```sql
terms.id = agreement.current_terms_id,
terms.id = agreement.pending_terms_id
```

The agreement pointers are legitimately nullable. Ordinary PostgreSQL equality returns NULL when either operand is NULL.

Flutter's `ResourceExchangePayloadParser.terms` in:

```text
apps/mobile/lib/features/resource_exchange/data/resource_exchange_gateway.dart
```

passes both fields through `_bool`, which rejects anything other than a Dart `bool`.

Consequently, normal agreement states produce a payload the current mobile parser rejects:

| Agreement state | Returned terms row | Existing flags | Required flags |
|---|---|---|---|
| First proposal; no accepted terms | Pending version | NULL / true | false / true |
| Proposal accepted; no pending replacement | Current version | true / NULL | true / false |
| Proposal rejected or withdrawn; no accepted terms | Historical version | NULL / NULL | false / false |
| Current and pending both exist | Current version | true / false | true / false |
| Current and pending both exist | Pending version | false / true | false / true |
| Current terms retained after cancellation | Current version | true / NULL | true / false |

An agreement without any terms returns an empty list and is not itself affected.

The current gateway test fixture supplies `is_current: false` and `is_pending: true` directly. That validates the intended payload, but does not establish that the SQL RPC emits it.

This finding is based on source inspection and PostgreSQL semantics; it is not a claim that a full live end-to-end reproduction has already been executed. Reproduce and document it during this task.

## 3. Verify the effective definition first

Search the branch's migrations in chronological order for every definition of `list_resource_exchange_agreement_terms`. At the reviewed head, neither of the two subsequent migrations replaces it. Check again in case the branch advanced.

When an isolated database is available, inspect `pg_get_functiondef` as well. Record which definition is effective after replay. Do not diagnose only the original migration if a newer override exists.

Use a minimal SQL comparison as a sanity check, then reproduce with a genuine first pending proposal through the existing authenticated agreement workflow.

## 4. Repair the projection, not the parser

Add a new, uniquely timestamped forward migration after the existing stack's migrations. Use `CREATE OR REPLACE FUNCTION` with the **latest effective body** and change only the two flag expressions to non-null booleans:

```sql
coalesce(terms.id = agreement.current_terms_id, false),
coalesce(terms.id = agreement.pending_terms_id, false)
```

An equivalent null-safe comparison is acceptable, but prefer the explicit expression above for an easily audited two-expression diff.

Semantics must remain:

```text
is_current = true exactly when the non-null current pointer identifies this row
is_pending = true exactly when the non-null pending pointer identifies this row
otherwise false, never null
```

Do not replace nullable UUID pointers with sentinel UUIDs. Do not filter out legitimate historical rows to avoid parsing them. Do not use a database-wide NULL-compatibility setting.

Keep the existing Flutter boolean parser strict. Do not globally convert null, missing fields, strings, or integers to false. The canonical RPC should satisfy its intended contract for every client.

## 5. Preserve every unrelated contract

Do not change function arguments, output column names/order/types, version ordering, counterpart authorization, identity checks, `STABLE`, `SECURITY DEFINER`, empty search path, ownership, or execution grants.

Do not change the underlying agreement/terms/event tables, stored pointers, accepted terms, immutable snapshots, dates, notes, request states, chat lifecycle, or notification behavior.

Do not modify the old migration. Existing development databases must receive the fix by applying the new migration, not by relying on an edited historical file.

No backfill or application-data mutation is needed. Calling the fixed read must remain side-effect-free: no audit, outbox, notification, or agreement-history event.

Compare the old and replacement function bodies and document the two-expression-only change. Check that existing ACL/security metadata is preserved after application.

## 6. Database regression coverage

Extend the focused agreement pgTAP suite or add a small contract suite. Assert both logical values and non-nullness; a test that only checks selected true values is insufficient.

Exercise these states through canonical mutations where practical:

1. No proposal yet: the list is empty.
2. First pending proposal: false/true.
3. Accepted proposal without replacement: true/false.
4. Accepted current version plus pending replacement: exactly one current and one pending row; older rows false/false.
5. Pending-only proposal rejected: historical row false/false.
6. Pending-only proposal withdrawn: historical row false/false.
7. Rejected/withdrawn replacement: original current true/false; replacement false/false.
8. Cancelled agreement, with and without previously accepted terms: all flags are booleans and agree with retained pointers.
9. In-progress and completed agreement: current true/false; old versions false/false.

For every returned row assert `is_current IS NOT NULL` and `is_pending IS NOT NULL`, and verify the JSON serialization contains actual booleans. Preserve owner/requester access and unrelated/anonymous denial tests.

Compare audit/outbox/event counts around read-only calls to confirm no new side effects.

## 7. Test the RPC-to-client boundary

Extend the existing real-OTP agreement verifier rather than inventing an unrelated backend harness.

Use synthetic test accounts and fixture resources to perform request acceptance, first proposal, terms acceptance, and at least one rejected or withdrawn proposal. Inspect the actual PostgREST JSON after each step:

```javascript
assert.equal(typeof row.is_current, 'boolean');
assert.equal(typeof row.is_pending, 'boolean');
```

Then verify expected values against the agreement pointers.

Feed representative RPC-produced, synthetic terms payloads through the production Dart parser and snapshot reconciliation in a focused test or existing integration mechanism. A sanitized test fixture may be used for the cross-language handoff, but its flags must come from the RPC output, not be repaired in test code.

Do not write JWTs, OTPs, API keys, or real users' terms/notes into fixtures or logs. Record how the fixture was obtained and which schema revision produced it. If runtime execution is unavailable, distinguish newly added test coverage from executed evidence.

## 8. Flutter regressions

Keep tests proving malformed payloads still fail. Explicitly cover:

```text
is_current = null
is_pending = null
missing flag
string/integer instead of boolean
contradictory true/true flags
flag/pointer disagreement
```

These remain invalid canonical API payloads after the SQL fix.

Add positive parser/reconciliation coverage for pending-only, current-only, and historical-only payloads containing the corrected booleans. Include a controller/widget path showing that the first proposal and its later acceptance remain displayable after canonical reload.

Do not weaken pointer reconciliation or infer authority from a proposal's position in the returned list.

## 9. Generated types and documentation

No RPC signature or declared SQL output type changes. Do not manually edit generated TypeScript types solely to make this change appear complete.

When the database is available, regenerate/check types and report the result. An unrelated pre-existing drift is a separate finding, not permission to hide it.

Add a short note to the Resource-exchange README/database documentation: the two projection flags are always non-null booleans, while the agreement's current/pending UUID pointers remain nullable.

Record this as a C3C1 contract follow-up. Keep C3C2 handoff/return/timeline/overdue and C3D notifications unimplemented. No product Google Doc changes are needed.

## 10. Validation and shared-runtime safety

Do not assume Docker is still unavailable: some later work has executed against local Supabase. Inspect current availability safely.

Use an isolated disposable database/stack or explicitly coordinate exclusive use before resetting a shared stack. Another task resetting the same database invalidates the run; report that rather than marking it passed. Do not stop services or delete containers, volumes, sockets, or settings outside this task's authorized workspace.

Run, where available:

```text
clean migration replay and focused agreement pgTAP
upgrade application of the new migration over the pre-fix schema
real-OTP/RPC boolean-contract regression
DB lint/advisors and generated-type drift
focused Flutter parser/controller/widget tests
npm run check:mobile
flutter build apk --debug
npm run check:web
npm run check:site
git diff --check
```

Record exact tested heads and whether each check executed. Static SQL parsing is not database execution; fixture-based Flutter tests are not an authenticated RPC test.

Allow one final-head hosted Validation attempt. If runner allocation is blocked by the known billing restriction, do not repeatedly rerun it. Existing full-stack database failures and deferred native Plan 12 QA remain separate; this fix does not claim to clear them.

## 11. Deliverables

Push a focused follow-up commit to existing PR #80, preserving its dependency base. Leave it draft and unmerged.

Report the initial reproduction, effective function source, migration path, exact changed expressions, preserved grants/signature, SQL/JSON flag results for each covered lifecycle, RPC-to-Dart test evidence, type-drift result, local/hosted validation, and final commit SHA.

Do not implement handoff controls, the timeline, overdue UI, new notifications, or any new business policy in this follow-up.

## Reference checked during review

Reviewed repository commit: `df7d810812a4c413b690ac2c0c7ab8127931348d`.

Relevant files are the original agreement migration, the Resource-exchange gateway, and `apps/mobile/test/features/resource_exchange/data/resource_exchange_gateway_test.dart`.

PostgreSQL's comparison semantics are documented at:

```text
https://www.postgresql.org/docs/current/functions-comparison.html
```

Do not merge any PR.
