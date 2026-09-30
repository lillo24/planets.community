# PLANETS DB-COMPAT-01 — PostgREST-Safe Application Conflict SQLSTATEs

**Task type:** Cross-stack database/mobile compatibility patch  
**Repository:** `lillo24/planets.community`

## Required stack

Base this patch on the current top of the open functional stack:

```text
PR #69 — 05C2 Mobile Actual Contribution Experience
branch: codex/05c2-mobile-actual-contributions
head:   daaa9286c4014abe4bc39b108af2b8af4b520e0f
```

The relevant lower PRs remain open/unmerged:

```text
PR #61 — 04C3C1 Current Commitment Domain
PR #65 — 04C3D3A Live Requirement Coverage Domain
PR #68 — 05C1 Actual Contribution Attribution Domain
```

Do not merge any PR.

Before implementation:

1. fetch current `origin/main`;
2. confirm PR #69 still points to the expected head or reconcile any new stack movement;
3. branch from the final PR #69 head;
4. preserve all unrelated work.

Preferred branch:

```text
codex/db-compat-postgrest-conflict-sqlstate
```

Open the new PR with base:

```text
codex/05c2-mobile-actual-contributions
```

Archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_DB_COMPAT_01_postgrest_safe_conflict_sqlstates.md
```

---

# Why this patch is required

The current stack contains application-defined PL/pgSQL conflicts raised with:

```sql
errcode = '40001'
```

These are **not** genuine PostgreSQL serialization failures.

They currently represent three ordinary product/domain conflicts:

```text
04C3C1
Membership commitments changed since they were loaded.

04C3D3A
The Project requirement is already covered.

05C1
Actual contributions changed since they were loaded.
```

Supabase currently documents a PostgREST 14 bug where a custom RPC exception raised with SQLSTATE `40001` can be treated as transient and retried repeatedly.

The current self-hosted Supabase release line still uses PostgREST 14.x.

Do not make PLANETS correctness depend on a future PostgREST 16 deployment.

Use PostgREST's explicit custom HTTP conflict SQLSTATE instead:

```text
PT409
```

This represents an application-level HTTP 409 Conflict without impersonating PostgreSQL serialization failure.

---

# 1. Canonical conflict code

For the three explicit application conflicts in scope, replace:

```sql
raise exception using
  errcode = '40001',
  message = '...';
```

with an equivalent custom PostgREST conflict raise:

```sql
raise sqlstate 'PT409'
  using message = '...';
```

or another syntactically equivalent PostgreSQL form.

Keep the existing human-safe messages unless repository conventions justify a minor wording adjustment.

---

# 2. Do not rewrite historical migrations

The affected functions were introduced in already-open lower stacked PRs.

Do **not** edit their historical migration files from this top patch.

Reason:

```text
if a lower migration has already executed in any development environment,
editing the old file does not upgrade that database.
```

Instead add one new forward migration that `create or replace`s the current canonical functions with identical semantics except for the explicit application-conflict SQLSTATE.

This patch must be safe both for:

```text
clean replay
and
upgrade of a database that already executed the lower migrations
```

---

# 3. Functions in scope

Inspect the current exact definitions and patch these canonical functions.

## 04C3C1

```text
public.replace_project_membership_commitments(...)
```

Current explicit stale-snapshot conflict:

```text
Membership commitments changed since they were loaded.
```

New SQLSTATE:

```text
PT409
```

Preserve:

- full-set CAS;
- lock order;
- expected-before-desired validation;
- no-op behavior;
- coverage integration added by later migrations;
- events;
- grants/security-definer/search-path behavior.

Important: because later migrations may already have replaced/evolved this function, copy the **latest definition at PR #69 head**, not the original PR #61 body.

## 04C3D3A

```text
public.claim_project_requirement(...)
```

Current race result when another source already covers the requirement:

```text
The Project requirement is already covered.
```

New SQLSTATE:

```text
PT409
```

Preserve:

- claim-vs-claim serialization;
- commitment creation when necessary;
- coverage creation;
- transition events;
- 50/50 limits;
- lock order;
- Realtime/system-event behavior added by later migrations.

Again, use the latest PR #69-head function definition.

## 05C1

```text
public.replace_project_membership_actual_contributions(...)
```

Current stale-CAS conflict:

```text
Actual contributions changed since they were loaded.
```

New SQLSTATE:

```text
PT409
```

Preserve all 05C1 semantics exactly.

---

# 4. Scope audit

Before coding, search the complete PR #69 tree for explicit application-authored `40001`.

Classify each occurrence.

Expected intentional raises are the three above.

Also inspect:

- pgTAP assertions;
- verifier scripts;
- mobile error mappings;
- documentation/comments;
- archived prompts.

Do not blindly replace text inside archived implementation prompts.

Archived prompts are historical artifacts and should remain byte-for-byte unchanged.

If another live application-authored `40001` raise exists outside the expected three:

```text
stop and report it in the completion report,
then patch it only if its semantics are clearly the same application-conflict pattern.
```

Do not alter genuine PostgreSQL-generated serialization handling.

---

# 5. Flutter conflict mappings

Update production mobile code to treat:

```text
PT409
```

as the canonical application conflict.

## Membership commitments

Current behavior:

```text
custom conflict
→ MembershipCommitmentFailureKind.staleEdit
→ reload canonical commitments/options
→ no automatic stale merge
```

Preserve exactly, but map from:

```text
PT409
```

instead of the custom `40001`.

Do not map arbitrary genuine `40001` to `staleEdit`.

## Project Needs claim

Current behavior:

```text
claim conflict
→ ProjectNeedsNotice.coveredElsewhere
→ reload canonical coverage
→ "Someone else just covered this need."
```

Trigger this behavior from:

```text
PT409
```

Do not auto-retry.

## Actual contributions

Current behavior:

```text
custom conflict
→ staleEdit
→ reload actual contributions/options
→ discard stale draft
→ creator reviews again
```

Map from:

```text
PT409
```

instead of custom `40001`.

---

# 6. Do not overload HTTP status alone

Flutter/Supabase error handling should continue to inspect the returned PostgREST/PostgreSQL code.

Do not change the client to infer domain conflict from:

```text
HTTP 409 alone
```

because ordinary database constraints may also map to HTTP 409.

Canonical domain marker:

```text
PostgrestException.code == 'PT409'
```

within these specific RPC contexts.

---

# 7. SQL tests

Update affected pgTAP tests so explicit application conflict assertions expect:

```text
PT409
```

not:

```text
40001
```

Preserve all behavioral assertions.

Add a focused regression asserting that the latest canonical definitions of the three functions do not contain an application-authored:

```text
errcode = '40001'
```

or equivalent explicit `RAISE ... 40001`.

Do not attempt to ban genuine database serialization failures globally.

---

# 8. Real integration/verifier tests

Update affected verifier expectations.

At minimum verify through real RPC calls when the DB gate is available:

```text
stale membership commitment CAS
→ one PT409 response

simultaneous requirement claim loser
→ one PT409 response

stale actual-contribution CAS
→ one PT409 response
```

Critically, each logical request should cause only the intended canonical operation.

Where practical, include guards that would expose repeated side effects/events.

Do not build timing-based tests that require detecting an infinite loop directly.

---

# 9. Mobile tests

Update and add focused tests for all three callers.

## Membership commitment

```text
PT409
→ staleEdit
→ canonical reload
→ no automatic resubmit
```

A synthetic `40001` should **not** be classified as the application's stale-edit marker.

## Needs claim

```text
PT409
→ coveredElsewhere notice
→ canonical reload
→ no automatic resubmit
```

## Actual contribution

```text
PT409
→ staleEdit
→ canonical reload/options reload
→ stale desired state discarded
→ no automatic resubmit
```

---

# 10. Documentation

Update current technical documentation to state:

```text
Application-level optimistic-concurrency / already-covered conflicts use
PostgREST custom SQLSTATE PT409.

Do not use a custom SQLSTATE 40001 for application conflicts.
40001 is reserved for genuine PostgreSQL serialization failures.
```

Document why:

```text
PostgREST 14 may retry custom 40001 RPC errors.
```

The exact production/self-hosted PostgREST version should still be pinned/documented during Plan 13, but PLANETS should no longer require PostgREST 16 merely for these conflict paths.

Do not add this implementation detail to the product Google Doc.

---

# 11. Roadmap / compatibility note

Add a compact technical compatibility entry or note in the implementation roadmap/development database docs.

This is not a new product feature.

Do not reorder the product roadmap around it.

After this patch, the next product-design discussion remains:

```text
04C4 — Listing Requests/Handoff + Saved Search/Matching
```

which still requires founder decisions on request/contact/handoff/matching semantics.

---

# 12. Generated types

No RPC signatures change.

A type regeneration should therefore produce no semantic API change.

If the DB is unavailable:

- do not hand-edit generated types merely for this patch unless an actual type change is discovered;
- keep the existing inherited type-drift gate.

---

# 13. Validation

Run available non-DB checks:

```text
npm run check:mobile
flutter build apk --debug
npm run check:web
npm run check:site
git diff --check
```

Run:

- SQL parse checks;
- focused Flutter tests;
- verifier syntax checks;
- formatting.

When Docker/Supabase becomes available, the mandatory DB gate includes:

```text
clean migration replay
DB lint/advisors
all pgTAP
real OTP/integration
generated-type drift
```

Attempt hosted Validation once.

If GitHub again allocates no runner because of the known billing/spending-limit issue:

```text
not executed due external infrastructure
```

Do not rerun pointlessly.

---

# Non-goals

Do not:

- implement 04C4;
- change CAS business semantics;
- change claim semantics;
- change contribution UX;
- upgrade/pin production Supabase in this feature patch;
- introduce retries;
- add client automatic conflict retry;
- change genuine PostgreSQL serialization handling;
- rewrite archived prompts;
- merge any PR.

---

# Acceptance criteria

Ready for review when:

- [ ] patch is based on PR #69;
- [ ] exact prompt archived;
- [ ] one forward migration upgrades existing databases;
- [ ] latest membership-commitment CAS uses `PT409`;
- [ ] latest requirement-claim race uses `PT409`;
- [ ] latest actual-contribution CAS uses `PT409`;
- [ ] no affected function semantics changed otherwise;
- [ ] production Flutter maps `PT409` correctly in all three flows;
- [ ] custom `40001` is no longer the domain marker in these clients;
- [ ] affected pgTAP expectations use `PT409`;
- [ ] real verifier expectations use `PT409`;
- [ ] no stale automatic retry introduced;
- [ ] archived historical prompts remain unchanged;
- [ ] current technical docs explain the PostgREST compatibility rule;
- [ ] non-DB regression validation passes;
- [ ] full DB validation remains a hard pre-merge gate;
- [ ] no PR merged.

---

# Completion report

Return:

1. **Stack/base status**
2. **Compatibility branch/base/PR**
3. **Changed files**
4. **Full `40001` audit result**
5. **Membership-CAS SQLSTATE change**
6. **Requirement-claim SQLSTATE change**
7. **Actual-contribution CAS SQLSTATE change**
8. **Forward-migration strategy**
9. **Membership mobile mapping**
10. **Needs mobile mapping**
11. **Actual-contribution mobile mapping**
12. **Behavior preserved**
13. **pgTAP updates**
14. **Integration/verifier updates**
15. **Flutter regression tests**
16. **Documentation**
17. **Generated-type impact**
18. **Local validation**
19. **Hosted Validation executed/not-executed**
20. **Remaining DB validation blocker**
21. **04C4 handoff**
22. **Warnings/blockers**
23. **Commit/PR reference**

Do not merge any PR.
