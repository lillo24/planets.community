# PLANETS STACK-INTEGRATION-02A — Blocking × Delegated Project Manager Convergence Fix

## Task type

Focused corrective integration task on the existing cumulative main candidate.

This is **not a new product feature plan**.

It fixes one cross-stack regression discovered after STACK-INTEGRATION-02 combined:

- 09B user blocking;
- 07C2 delegated Co-creator / Co-organizer authority;
- Project participation;
- Project capacity/fullness.

The approved product semantics already exist. The integrated implementation currently fails to enforce them on delegated-manager Project paths.

---

# 1. Objective

Repair the cumulative integration candidate so the Project blocking barrier applies to **every current Project manager with applicant-management authority**, not only the immutable original Creator.

After this fix:

1. a user cannot submit a new Project join request if there is an active block in either direction between the requester and **any current Project manager**;
2. a pending applicant cannot be accepted by any Creator / Co-creator / Co-organizer while the applicant has an active block relationship with **any current Project manager**;
3. when a current Project manager blocks a pending requester, the pending request is canonically `rejected`;
4. when a pending requester blocks any current Project manager, the pending request is canonically `withdrawn`;
5. revoked/former delegates no longer count as managers for future eligibility;
6. existing accepted Project membership, group chat, meeting access, workspace access, commitments, and history remain unchanged by the pair block, exactly as already approved;
7. capacity/fullness and contribution-triage acceptance behavior remain intact;
8. the blocking/request/accept races remain deterministic and deadlock-safe.

Do not change the already-approved ordinary user-blocking semantics beyond this manager-convergence correction.

---

# 2. Work directly on the existing integration candidate

Repository:

`lillo24/planets.community`

Current corrective base:

- integration branch:
  `codex/stack-integration-main-candidate`
- current exact head:
  `3d822dc8318a58766c90ef196a50dafaa54c06df`
- draft integration PR:
  `#120 — STACK-INTEGRATION-02: consolidate current PLANETS product stacks`
- PR target:
  `main`
- `main` remains:
  `06e983bb230a7a48514095fe407250ad6d38c148`

## Required workflow

Work on the existing integration candidate branch/worktree, or an isolated worktree that updates that **same branch**.

Append a corrective commit to:

`codex/stack-integration-main-candidate`

Push the updated branch so **PR #120 updates in place**.

Do **not**:

- create a separate feature PR;
- merge PR #120;
- merge `main`;
- modify old feature branches;
- close old PRs;
- force-push old feature branches;
- retarget existing PRs.

PR #120 must remain **draft and unmerged**.

If `codex/stack-integration-main-candidate` no longer points at exact head
`3d822dc8318a58766c90ef196a50dafaa54c06df`,
inspect the new commits first.

If the branch changed materially in the relevant blocking/delegate/participation area, stop and report the new state before applying this stale correction.

---

# 3. Confirmed current regression

This issue was verified against exact integration head:

`3d822dc8318a58766c90ef196a50dafaa54c06df`

## A. Current blocking request path is Creator-only

In:

`supabase/migrations/20260929155334_user_blocking_domain_enforcement.sql`

the cumulative `request_to_join_project(...)` blocking wrapper resolves only:

`projects.creator_profile_id`

and acquires/checks the pair barrier only for:

`requester ↔ original Creator`

It does not consider active Co-creators or Co-organizers.

## B. Current block-time pending-request cleanup is Creator-only

`private.close_pending_direct_requests_for_user_block(...)`

selects affected Project requests by comparing the blocked pair only against:

- `project.creator_profile_id`;
- `request.requester_profile_id`.

Therefore:

- a Co-creator blocking a pending applicant does not reject the request;
- a Co-organizer blocking a pending applicant does not reject the request;
- a requester blocking a current delegate does not withdraw the request.

## C. Delegated manager acceptance bypasses the blocking pair barrier

The integrated repository includes:

`public.accept_project_join_request_as_manager(...)`

from the delegated-manager stack.

It authorizes:

- original Creator;
- active Co-creator;
- active Co-organizer

through the canonical Project-manager boundary.

But the function contains no:

- `private.lock_user_interaction_pair(...)`;
- `private.assert_user_interaction_available(...)`;
- equivalent all-current-manager block enforcement.

The 09B blocking migration wraps only the legacy Creator-named acceptance path.

## D. No indirect trigger fixes this

The following cumulative domains were checked and do not indirectly enforce the missing manager block rule:

- participation;
- Project group chat;
- Co-creator authority;
- people capacity/fullness.

This is a real cross-stack integration regression.

## E. Existing tests missed the cross-product

The repository has green focused suites for:

- user blocking;
- delegates / Co-creators;
- capacity/fullness;

but no focused test proving:

`blocking × current delegated manager × Project request/accept`

The integration record currently states no known deterministic failure, so this corrective task must update that record to document the discovered and repaired convergence bug.

---

# 4. Approved product semantics — do not reopen

These are founder-approved decisions.

## Directional action, symmetric interaction barrier

A block is stored directionally:

`A blocks B`

but either active direction creates a symmetric barrier for **new direct interaction**.

For Project participation after delegated-authority convergence, a requester is interacting with the Project's **current management set**, not only with the immutable Creator.

Therefore:

> A Project join interaction is unavailable while the requester has an active block relationship, in either direction, with any current Project manager who has applicant-management authority.

Current Project manager means the repository's canonical manager set:

- original Creator;
- active Co-creator;
- active Co-organizer.

Use the existing manager source of truth. Do not invent a parallel role list.

---

# 5. New Project request semantics

Before creating a new Project join request:

1. resolve the current manager set canonically;
2. include original Creator plus active delegates with manager authority;
3. exclude revoked delegates;
4. determine whether an active user block exists between requester and **any** current manager;
5. if yes, reject the new interaction with the existing privacy-safe blocking failure semantics;
6. if no, continue through all existing participation checks.

Existing rules must still compose, including:

- complete profile;
- profile-photo trust gate;
- lifecycle/joinability;
- capacity/fullness;
- membership/request uniqueness;
- contribution selections;
- any existing concrete Project validation.

Do not change public Project visibility.

Do not expose which manager caused the barrier.

---

# 6. Pending Project request closure on Block

When a new block becomes active, inspect pending Project requests where the blocked pair is:

`requester ↔ current Project manager`

not only:

`requester ↔ original Creator`.

For a still-current manager:

## Manager blocks requester

If blocker is a current Project manager and blocked profile is the pending requester:

`pending → rejected`

Use the existing canonical rejection transition semantics/history/event behavior.

The manager who actually performed the block may be recorded as the resolving actor if consistent with current participation event rules.

## Requester blocks manager

If blocker is the pending requester and blocked profile is any current Project manager:

`pending → withdrawn`

Use canonical withdrawal semantics/history/event behavior.

## Both / multiple manager relationships

A Project can have several current managers.

The pending request is one canonical request and must resolve at most once.

Use deterministic processing.

Do not create a new request state such as:

- `blocked`;
- `moderated`;
- `manager_blocked`.

Do not rewrite already terminal requests.

---

# 7. Manager acceptance semantics

Every Project acceptance path must respect the same all-current-manager barrier.

This includes at minimum:

- legacy Creator-named acceptance compatibility path(s);
- `accept_project_join_request_as_manager(...)`;
- both zero-selection / contribution-triage signatures if both remain public.

A current manager must not be able to accept a pending applicant when that applicant has an active block relationship with **any current Project manager**, even when the accepting manager is not the blocked manager.

Example:

```text
Creator C
Co-creator A
Applicant B

A blocks B.
C attempts to accept B.
```

Acceptance must fail.

Likewise:

```text
B blocks Co-organizer O.
Creator C attempts to accept B.
```

Acceptance must fail.

The Project management team is the interaction boundary.

---

# 8. Revoked manager semantics

A revoked delegate is no longer a current Project manager.

Therefore a block involving only that former manager must not indefinitely prevent new Project participation.

Example:

```text
Co-organizer O blocks B.
O is later revoked.
No other current manager has a block with B.
```

A later fresh Project join interaction by B may proceed if all other rules permit it.

Do not turn historical delegated authority into a permanent blocking relationship with the Project.

The pairwise user block still exists between O and B as a user relationship; it simply stops affecting that Project once O is no longer a current manager.

---

# 9. Existing accepted relationships remain unchanged

Preserve the already-approved 09B rule:

Blocking does **not** automatically remove an accepted Project member.

Do not:

- terminate current membership;
- rewrite membership intervals;
- delete participation history;
- revoke existing group-chat access solely because of pair blocking;
- hide pairwise messages inside a shared Project chat;
- remove protected meeting access from a current accepted member solely because of pair blocking;
- remove shared-workspace access from a current accepted member solely because of pair blocking;
- alter commitments / actual-contribution history;
- change capacity occupancy except through ordinary membership transitions.

Delegated authority and participant membership remain independent.

---

# 10. Capacity/fullness must remain cumulative

The integrated repository now has canonical Project people capacity.

The blocking fix must not bypass or duplicate it.

Acceptance after this correction must still enforce, in the existing canonical order:

- block-manager barrier;
- current manager authorization;
- contribution-triage validity;
- Project lifecycle;
- current membership/request validity;
- Project capacity/fullness;
- all other existing membership insertion safeguards.

A failed blocking check must not consume a capacity spot or partially write acceptance decisions.

A failed capacity check must not mutate blocking state.

Do not introduce a second capacity calculation.

---

# 11. Concurrency requirements

This is the most important implementation detail.

The fix must preserve the 09B guarantee that Block vs Request/Accept has only valid serial outcomes.

## Existing pair lock

09B provides:

`private.lock_user_interaction_pair(uuid, uuid)`

for a lexically sorted profile pair.

Block operations use it before Project/Resource row locks.

The Project manager case now involves:

`requester ↔ N current managers`.

## Required result

The solution must deterministically handle:

- Block by Creator vs Request;
- Block by Co-creator vs Request;
- Block by Co-organizer vs Request;
- Requester block of any current manager vs Request;
- Block by any current manager vs manager acceptance;
- Requester block of any current manager vs manager acceptance;
- concurrent delegate revocation / role change where relevant;
- capacity race together with block race.

## Lock-order guardrail

Do not casually acquire:

`Project row → pair lock`

when 09B block operations use:

`pair lock → Project row`

because that can introduce a deadlock cycle.

Prefer an implementation that:

1. snapshots current manager IDs;
2. acquires all required requester↔manager pair locks in deterministic order;
3. enters the existing Project lock order;
4. revalidates the current manager set and all active block relationships before mutation.

If the current manager set changed materially between pre-lock snapshot and Project-locked revalidation, prefer a safe retry/conflict rather than silently accepting under an un-serialized manager relationship.

An equivalent design is acceptable if it proves the same deadlock-safe serial semantics.

Do not implement a best-effort `exists(block)` check without serialization.

---

# 12. Centralize current-manager blocking logic

Do not scatter three slightly different definitions of the manager set.

Reuse the integrated repository's canonical manager authority:

`private.profile_is_project_manager(...)`

and the underlying Creator + active delegate truth.

A focused private helper may be appropriate, conceptually providing:

- current Project manager profile IDs;
- whether a requester has a block with any current manager;
- deterministic acquisition/revalidation for those manager pairs.

Exact function names are Codex's choice.

Requirements:

- Creator included once;
- active Co-creators included;
- active Co-organizers included;
- revoked delegates excluded;
- duplicate identities collapsed;
- deterministic ordering.

Do not alter immutable Project Creator attribution.

---

# 13. Migration strategy

All relevant blocking/delegate/capacity migrations are still part of the unmerged integration candidate.

Do not modify any old feature branch.

On the integration candidate, choose the safest cumulative-schema correction.

Acceptable approaches include:

### A. Correct the unmerged blocking migration

Update:

`20260929155334_user_blocking_domain_enforcement.sql`

so its final cumulative definitions understand the already-earlier delegate schema.

This is attractive because the blocking migration timestamp is after the delegated-authority migrations.

### B. Add a focused corrective integration migration

Use this if it makes cumulative ordering, testability, or wrapper preservation materially safer.

If adding a migration:

- use a new unique timestamp;
- preserve all cumulative function signatures;
- document why the corrective migration is necessary.

Do not rewrite any migration already merged to `main`.

Whichever approach is chosen, verify later migrations do not overwrite the corrected definitions.

---

# 14. Legacy Creator compatibility

Do not remove legacy Creator-named RPCs.

The cumulative repository deliberately retains compatibility boundaries such as:

`accept_project_join_request(...)`

while delegate-capable clients use:

`accept_project_join_request_as_manager(...)`.

Both must enforce the same Project blocking eligibility.

Avoid duplicating the entire acceptance implementation.

Prefer one shared canonical block-manager eligibility boundary composed into both paths.

---

# 15. Mobile / UX scope

No broad UI redesign is required.

The current 09B2 privacy-safe behavior remains acceptable:

- the client knows only the signed-in user's outbound blocks;
- inbound block direction remains undisclosed;
- generic backend PT409 copy may handle a block involving another current manager that the requester cannot see as their own outbound block.

Do not expose the full Project manager block graph to the requester.

Do not add:

- list of managers who block the user;
- block reason;
- inbound block state;
- reciprocal state.

If no mobile production change is needed, leave mobile code unchanged.

---

# 16. Profile photos and other 09B behavior

This corrective task is about Project participation manager convergence.

Do not broaden it into unrelated blocking changes.

Preserve:

- public content visibility;
- public profile photos;
- interaction-only photo denial according to existing authorization;
- accepted Resource coordination behavior;
- Resource request blocking;
- moderation evidence independence;
- Blocked users mobile management.

If repository inspection reveals a **directly analogous delegate-manager leak in the existing Project interaction-photo authorization introduced by this same integration**, document it separately and stop before expanding scope unless the fix is a small unavoidable part of making manager blocking coherent.

---

# 17. Tests — new cumulative coverage is required

The existing green suites are insufficient because they test the branches separately.

Add focused integration coverage specifically for:

`blocking × delegated managers × participation × capacity`

Use new globally unique pgTAP numbers after the current integrated inventory.

At the current candidate, tests already reach `103`, so prefer new prefixes such as:

```text
104_...
105_...
```

after verifying no newer files exist when you start.

Do not renumber unrelated suites again.

---

# 18. Required pgTAP scenarios

Cover at least:

## Request creation

1. requester ↔ Creator block denies request;
2. requester ↔ Co-creator block denies request;
3. requester ↔ Co-organizer block denies request;
4. reverse block direction for each manager role denies request;
5. block with revoked former delegate does not deny a later fresh request when no current manager block remains;
6. no-block path remains joinable subject to ordinary rules;
7. capacity-full denial still works independently.

## Pending request closure

8. Co-creator blocks pending requester → request becomes `rejected`;
9. Co-organizer blocks pending requester → `rejected`;
10. requester blocks Co-creator → `withdrawn`;
11. requester blocks Co-organizer → `withdrawn`;
12. one request with several managers resolves exactly once;
13. terminal request is not rewritten;
14. revoked former manager blocking does not newly resolve a pending request.

## Acceptance

15. Creator cannot accept if requester is blocked with Co-creator;
16. Creator cannot accept if requester is blocked with Co-organizer;
17. Co-creator cannot accept if requester is blocked with Creator;
18. Co-creator cannot accept if requester is blocked with another current manager;
19. Co-organizer cannot accept if requester is blocked with any current manager;
20. two-argument compatibility acceptance obeys the same rule;
21. triaged acceptance obeys the same rule;
22. acceptance succeeds when the only blocked delegate was revoked and all other rules permit it;
23. capacity/fullness still prevents overbooking after the blocking fix.

## Existing relationships

24. existing accepted membership remains after manager/requester block;
25. group chat entitlement remains;
26. protected meeting access remains for current participant;
27. shared workspace remains available to current participant/current manager under its ordinary rules;
28. authority alone still does not consume capacity.

---

# 19. Concurrency verifier

Extend:

`scripts/verify-local-user-blocking-concurrency.mjs`

or add one focused integration verifier if clearer.

Use real concurrent transactions.

At minimum prove:

## Co-creator / Co-organizer Request race

- manager Block wins → no pending request survives;
- Request wins → later block closes that pending request canonically.

## Manager acceptance race

- manager/requester Block wins → acceptance fails and request does not become membership;
- acceptance wins → accepted membership remains after later Block.

Run this for at least one delegated manager role and ensure the helper used is role-generic; pgTAP covers both delegated roles.

## Capacity composition

Include or preserve one final-spot acceptance scenario proving the corrected manager block path does not bypass the existing capacity serialization.

Do not rely only on timing sleeps.

Use canonical locks/transactions and assert final database state.

---

# 20. Security/privacy regression checks

Prove this fix does not expose:

- inbound block direction;
- which Project manager caused the barrier;
- block graph;
- delegate private metadata to applicant;
- Auth email;
- invitation token/digest;
- moderation evidence.

The requester-facing failure remains the existing safe interaction-unavailable shape.

Manager private reads remain authorized through current manager rules.

---

# 21. Documentation corrections

Update at least:

`docs/development/stack-integration-2026-09.md`

Record this as a cumulative production bug discovered during founder review:

> Project blocking had been integrated before delegated-manager authority and therefore still enforced Creator-only Project interaction checks; manager-specific acceptance and pending-request closure bypassed the intended current-manager block barrier.

Record:

- exact pre-fix candidate head;
- correction approach;
- tests added;
- final validation.

Also reconcile, where needed:

- `docs/architecture/system-design.md`
- `docs/development/database.md`
- `docs/implementation/roadmap.md`
- relevant blocking / participation READMEs.

The durable architecture should state clearly:

> Project new-interaction blocking evaluates the requester against every current Project manager — original Creator plus active Co-creators and Co-organizers — while existing accepted membership remains intact.

Do not change the founder-approved semantics.

---

# 22. Archive this prompt

Archive this exact prompt unchanged under:

```text
history-implementations/PLANETS_STACK_INTEGRATION_02A_blocking_manager_convergence_fix.md
```

---

# 23. Full validation

Because this patches the integration candidate itself, return it to the same repository-wide green standard as STACK-INTEGRATION-02.

## Database

Run:

```text
npm run db:reset
npm run db:lint
npm run db:advisors
npm run db:test
npm run db:types:check
npm run check:db
```

Target: green.

Report final pgTAP file/assertion counts.

## Focused verifiers

Run at least:

- blocking concurrency verifier;
- Project participation verifier;
- Project delegate / Co-creator relevant verifier(s);
- Project capacity/fullness verifier;
- Project chat verifier(s);
- any contribution-triage verifier affected by acceptance wrappers.

If no existing delegate verifier exists for the exact path, rely on focused pgTAP plus the new real-auth/concurrency verifier and report that explicitly.

## Demo

Because cumulative schema changed, rerun:

```text
npm run demo:reset:local
npm run demo:verify:local
npm run demo:seed:local
npm run demo:verify:local
```

Preserve idempotency.

## Mobile

If no mobile production code changed, still run the integration candidate gate:

```text
npm run check:mobile
flutter build apk --debug
```

The integration PR is supposed to remain fully green.

## Web / Site

Run:

```text
npm run check:web
npm run check:site
```

## Hygiene

Run:

```text
npm run format:check
git diff --check
```

Do not report success while a repository-owned deterministic failure remains unexplained.

---

# 24. Generated DB types

If any public function signature or schema changes:

```text
npm run db:types
npm run db:types:check
```

Commit generated output.

Do not hand-edit the generated database type file as the source of truth.

---

# 25. Hosted CI

Push the corrective commit to the existing candidate branch.

Allow the normal PR #120 workflow to make one final-head hosted attempt.

If GitHub again refuses runner allocation before any step because of the known account billing/spending-limit issue:

- document the new run on PR #120 / integration record;
- do not repeatedly rerun unchanged infrastructure failures.

Do not claim hosted CI passed.

---

# 26. PR #120 handling

Update the existing draft PR #120 body if needed so founder review knows:

- the cross-stack manager/blocking bug was found after initial integration;
- it has been corrected;
- new manager/blocking integration tests were added;
- full local validation is green again.

Keep the explicit:

`DO NOT MERGE until founder review`

gate.

Do not open another PR for this correction.

---

# 27. Non-goals

Do not implement:

- 09C moderation consequences;
- suspension;
- moderation warnings;
- age policy;
- appeals;
- new block UX;
- new delegate UX;
- new capacity behavior;
- member removal on block;
- Project chat pairwise censorship;
- public content hiding;
- Resource-domain changes unrelated to regression;
- MLS/E2EE;
- unrelated refactors.

The purpose is only to make the already-approved cumulative behavior correct.

---

# 28. Stop conditions

Stop and report before proceeding if:

1. current candidate head changed materially from
   `3d822dc8318a58766c90ef196a50dafaa54c06df`;
2. fixing manager blocking requires changing founder-approved semantics;
3. a deadlock-safe ordering cannot be achieved between:
   - manager-set evaluation;
   - 09B pair locks;
   - Project participation locks;
   - delegate authority mutations;
4. the fix would require exposing inbound block state;
5. manager identity cannot be determined canonically without redesigning 07C2;
6. full cumulative validation reveals another genuine product-semantic conflict.

Ordinary code conflicts, test repairs, or safe helper refactors should be resolved autonomously.

---

# 29. Acceptance criteria

- [ ] Starts from exact candidate head `3d822dc8318a58766c90ef196a50dafaa54c06df`.
- [ ] Works on `codex/stack-integration-main-candidate`.
- [ ] Updates existing draft PR #120 rather than opening a new PR.
- [ ] Original Creator is a current manager for blocking.
- [ ] Active Co-creator is a current manager for blocking.
- [ ] Active Co-organizer is a current manager for blocking.
- [ ] Revoked delegate is not a current manager for blocking.
- [ ] New request is denied if requester has a block in either direction with any current manager.
- [ ] Block by current manager rejects the pending requester.
- [ ] Block by requester against current manager withdraws the pending request.
- [ ] One pending request resolves at most once even with multiple managers.
- [ ] Creator acceptance cannot bypass a block involving another manager.
- [ ] Co-creator acceptance cannot bypass any current-manager block.
- [ ] Co-organizer acceptance cannot bypass any current-manager block.
- [ ] Legacy two-argument acceptance remains compatible and block-safe.
- [ ] Contribution-triage acceptance remains block-safe.
- [ ] Capacity/fullness remains correct.
- [ ] Existing accepted membership/chat/meeting/workspace behavior remains unchanged by pair blocking.
- [ ] Inbound block direction remains private.
- [ ] Concurrency tests prove only approved serial outcomes.
- [ ] New focused cross-stack pgTAP coverage exists.
- [ ] Integration record documents the discovered/fixed cumulative bug.
- [ ] Full database/check:db/demo/mobile/APK/web/site/format validation returns green.
- [ ] Generated types are correct.
- [ ] `main` remains unchanged.
- [ ] PR #120 remains draft and unmerged.
- [ ] Old feature PRs/branches remain untouched.
- [ ] No 09C behavior is introduced.

---

# 30. Completion report

Return:

1. starting candidate SHA;
2. final candidate SHA;
3. confirmation branch remained `codex/stack-integration-main-candidate`;
4. PR #120 link/status;
5. exact root cause;
6. correction architecture/helpers;
7. current-manager definition used;
8. new-request enforcement behavior;
9. pending-request closure behavior;
10. Creator/Co-creator/Co-organizer acceptance behavior;
11. revoked-manager behavior;
12. lock hierarchy and concurrency proof;
13. capacity/fullness regression result;
14. existing membership/chat/meeting/workspace regression result;
15. pgTAP files added + final file/assertion count;
16. focused verifier results;
17. `check:db` result;
18. demo idempotency result;
19. mobile test count + APK result;
20. web/site results;
21. format/diff results;
22. hosted CI result;
23. integration record/docs updated;
24. remaining warnings or founder decisions;
25. confirmation that:
    - `main` was not modified;
    - PR #120 is still draft/unmerged;
    - no old PR/branch was modified or closed;
    - no 09C work was introduced.

Do not report the integration candidate ready while a repository-owned deterministic regression remains.
