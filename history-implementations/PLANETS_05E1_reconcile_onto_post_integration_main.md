# PLANETS 05E1 — Reconcile PR #121 onto Current Main

**Repository:** `lillo24/planets.community`  
**Existing PR:** #121 — `05E1: Add organizer-aware capacity and public headcount`  
**Current branch:** `codex/05e1-organizer-aware-capacity`  
**Required starting head:** `7b85ddbb05bb1cf4fe7d5ee71f5fb7ed6f0d2490`  
**Current main:** `415c2d7bf6370b5045399dcc1b7fdcd2b61f42a7`  
**Goal:** reconcile #121 onto current `main`, retarget #121 to `main`, validate, and leave it ready for founder merge.  
**Do NOT create a replacement PR. Do NOT merge #121.**

Archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_05E1_reconcile_onto_post_integration_main.md
```

## 0. Objective

PR #120 has now been merged into `main`.

Current `main` is:

```text
415c2d7bf6370b5045399dcc1b7fdcd2b61f42a7
Merge pull request #120 — STACK-INTEGRATION-02
```

PR #121 was created before the final #120 corrections and currently diverges from `main`.

Current verified state:

```text
PR #121
head: 7b85ddbb05bb1cf4fe7d5ee71f5fb7ed6f0d2490
base: codex/stack-integration-main-candidate
merge base with current main: f5958e00e9b1abb02b079f5489b769502fb3c88b
```

Relative to current `main`, #121 is 5 commits ahead and 3 commits behind.

The goal is:

```text
current main
+ intended 05E1 organizer-aware-capacity work
= corrected PR #121
```

Then retarget #121 to `main`, run full validation, and leave it unmerged for founder review.

Do not start 05E2 in this task.

## 1. Verify exact starting state

Before editing:

1. fetch all remotes;
2. verify current `main` is exactly `415c2d7bf6370b5045399dcc1b7fdcd2b61f42a7`;
3. verify PR #121 head is exactly `7b85ddbb05bb1cf4fe7d5ee71f5fb7ed6f0d2490`;
4. verify PR #121 still targets `codex/stack-integration-main-candidate`;
5. verify the worktree is clean.

If any SHA changed materially, stop and report the new graph instead of reconciling a stale snapshot.

## 2. Preserve 05E1 product semantics

Keep the intended 05E1 behavior:

- nullable `registrationCapacity`;
- unique public/social people count;
- Creator + active Co-creators + active Co-organizers are organizers;
- organizer membership overlap counts once socially;
- organizers do not count toward registration capacity by default unless explicitly enabled;
- capacity enforcement stays serialized under the Project lock;
- participant/delegate/capacity/policy-toggle races remain safe;
- Proposal and Tavolo create/edit/read UX keeps the capacity policy;
- English/Italian localization stays complete;
- intended compatibility overloads remain.

Do not implement 05E2 social-proof hiding, popularity/ranking, size filters, waitlists, templates, or people/chat redesign.

## 3. Preserve final #120 behavior from current main

Current `main` is authoritative for the final #120 corrections.

Preserve:

### Manager blocking
- Creator, active Co-creator, and active Co-organizer are current managers;
- revoked delegates do not affect eligibility;
- request creation and all acceptance paths revalidate blocking;
- Creator acceptance cannot bypass a block involving another manager;
- delegated-manager acceptance cannot bypass blocking;
- capacity/fullness still composes with blocking.

### Founder-QA mobile fixes
- chat/Realtime teardown is dispose-safe;
- Review Requests is a sibling of My Reports;
- legacy moderation routes redirect canonically;
- private Project-request and Resource rows show counterparty avatars;
- Project-request chat detail shows avatar;
- current-manager profile-photo visibility and batching/cache semantics remain intact.

### Final hosted-CI/admin fixes
- delegate widget tests are viewport-robust;
- signed-out/non-staff `/admin` and case routes fail closed with 404;
- moderation client/claims/staff-access establishment failures fail closed;
- authorized operational moderation failures still show unavailable states;
- parent admin authorization happens before loading UI can stream.

Do not restore older intermediate copies of these fixes from #121.

## 4. Reconciliation strategy

Work directly on:

```text
codex/05e1-organizer-aware-capacity
```

Bring exact current `main` into #121 with a normal merge/reconciliation approach, preferably:

```text
git merge 415c2d7bf6370b5045399dcc1b7fdcd2b61f42a7
```

or repository-consistent equivalent.

Do not use broad `ours` / `theirs` conflict resolution.

For overlapping files, target:

```text
final #120 behavior from current main
+
05E1-specific organizer-aware capacity delta
```

Likely hotspots include participation docs/controllers, delegate tests, admin layout/server tests, blocking verifier, architecture/database docs, localization, generated types, and capacity tests.

## 5. Migration audit

05E1 adds:

```text
supabase/migrations/20260930140814_organizer_aware_capacity_headcount.sql
```

After merging current main:

1. replay all migrations from zero;
2. verify timestamp order;
3. verify later #120 migrations do not overwrite 05E1 semantics;
4. verify 05E1 definitions retain final manager-blocking semantics;
5. verify Proposal/Tavolo reads retain covers/media/workspace/capacity fields.

Do not rewrite already-merged `main` migrations.

If 05E1 itself needs a narrow compatibility correction, update its unmerged migration or add a later 05E1 corrective migration, whichever is safer for cumulative replay.

## 6. Capacity + blocking composition

Verify:

- blocked requester cannot create a join request involving any current manager;
- current manager cannot accept a blocked requester;
- Creator acceptance cannot bypass another manager's block;
- delegated-manager acceptance cannot bypass blocking;
- revoked delegates do not affect eligibility;
- final registration slot is race-safe;
- organizer policy toggle is race-safe;
- promotion/demotion/revocation remains capacity-safe;
- organizer+participant overlap is socially unique;
- `capacityUsedCount` honors the organizer-counting toggle.

Do not weaken either subsystem.

## 7. Retarget PR #121

Once reconciled:

Change PR #121 base from:

```text
codex/stack-integration-main-candidate
```

to:

```text
main
```

Do not open a new PR.

Update the PR body to:

- state #120 is merged;
- record old head, reconciliation commit, final head;
- state exact current-main base;
- summarize conflicts;
- report validation;
- keep PR draft/unmerged.

## 8. Documentation

Update durable 05E1 docs to the cumulative state.

Preserve #120 integration history.

Roadmap should describe 05E1 as implemented in PR #121 but pending merge until it actually merges.

## 9. Validation

Focused first:

```text
npm run project:capacity:verify:local
npm run blocking:verify:local
```

Run focused capacity/blocking pgTAP suites.

Then full cumulative validation:

### Database

```text
npm run db:reset
npm run db:lint
npm run db:advisors
npm run db:test
npm run db:types:check
npm run check:db
```

### Demo

```text
npm run demo:reset:local
npm run demo:verify:local
npm run demo:seed:local
npm run demo:verify:local
```

### Mobile

```text
npm run check:mobile
flutter build apk --debug
```

### Web / site

```text
npm run check:web
npm run check:site
```

### Hygiene

```text
npm run format:check
git diff --check
```

Also verify localization parity, unique migration timestamps, unique pgTAP prefixes, and no MLS/OpenMLS production dependency.

## 10. Hosted CI

Push the reconciled final head to existing PR #121 after retargeting to `main`.

Allow one normal Validation run.

Goal:

```text
Change classification: PASS
Mobile: PASS
Web: PASS
Site: PASS
Database: PASS
```

Inspect any failure rather than blindly rerunning.

## 11. Acceptance criteria

- [ ] Started from exact #121 head `7b85ddbb05bb1cf4fe7d5ee71f5fb7ed6f0d2490`.
- [ ] Verified current `main` `415c2d7bf6370b5045399dcc1b7fdcd2b61f42a7`.
- [ ] Current main reconciled into #121.
- [ ] No replacement PR created.
- [ ] #121 retargeted to `main`.
- [ ] Final #120 manager-blocking behavior preserved.
- [ ] Final #120 chat/navigation/avatar behavior preserved.
- [ ] Final #120 admin fail-closed behavior preserved.
- [ ] 05E1 registration-capacity semantics preserved.
- [ ] Organizer-counting toggle preserved.
- [ ] Unique social people count preserved.
- [ ] Creator/Co-creator/Co-organizer semantics preserved.
- [ ] Revoked delegates excluded correctly.
- [ ] Capacity/blocking concurrency remains safe.
- [ ] Migration replay passes.
- [ ] `check:db` passes.
- [ ] Demo idempotency passes.
- [ ] Mobile suite passes.
- [ ] Android debug APK builds.
- [ ] Web/site pass.
- [ ] Format/diff pass.
- [ ] Hosted CI green or any external failure precisely explained.
- [ ] #121 remains draft/unmerged.
- [ ] No 05E2 work started.

## 12. Completion report

Return:

1. starting #121 head;
2. current-main SHA merged into it;
3. reconciliation merge commit(s);
4. final head;
5. confirmation #121 patched in place;
6. confirmation PR base is now `main`;
7. major conflicts/resolutions;
8. preservation of final #120 blocking behavior;
9. preservation of final #120 chat/navigation/avatar/admin fixes;
10. final 05E1 capacity/headcount semantics;
11. migration replay result;
12. focused capacity/blocking results;
13. pgTAP file/assertion counts;
14. `check:db`;
15. demo idempotency;
16. mobile test count + APK;
17. web/site results;
18. format/localization/audits;
19. hosted CI per-job status;
20. confirmation:
    - `main` was not modified during the task,
    - no new PR was opened,
    - #121 remains draft/unmerged,
    - no 05E2 work was started.
