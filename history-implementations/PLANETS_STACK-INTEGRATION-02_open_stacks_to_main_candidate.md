# PLANETS STACK-INTEGRATION-02 — Consolidate Open Product Stacks into a Main Candidate

**Task type:** Repository integration, conflict resolution, cumulative-schema stabilization, and full validation  
**Repository:** `lillo24/planets.community`  
**Required `main` base at prompt creation:** `06e983bb230a7a48514095fe407250ad6d38c148`  
**Preferred branch:** `codex/stack-integration-main-candidate`  
**Final PR target:** `main`  
**Final PR must be DRAFT and MUST NOT be merged.**

Archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_STACK-INTEGRATION-02_open_stacks_to_main_candidate.md
```

## 0. Objective

PLANETS has accumulated a large number of intentionally unmerged stacked PRs.

The implementation work is real and extensive, but `main` is still at:

```text
06e983bb230a7a48514095fe407250ad6d38c148
Merge PR #76 — DEMO-B
```

The goal of this task is to produce **one coherent integration branch representing the current intended app**, resolve the parallel-stack conflicts, repair cumulative test/schema drift, and open one **draft PR to `main`** for founder review.

Do not merge `main`. Do not close the existing stacked PRs yet.

Success is:

```text
current main
+ intended open product work
+ no deferred prototype work
+ cumulative migrations/tests reconciled
+ full local validation green
= one reviewable main-candidate PR
```

This is not a feature-development prompt. Do not add new product behavior except where strictly necessary to reconcile already-implemented accepted behavior.

## 1. Integrate descendant tips, not every PR individually

At prompt creation, the open PR graph was verified from GitHub.

### A. Main Resource/Profile/Media/Demo chain — integrate tip PR #115

```text
PR #115
branch: codex/demo-realistic-world-covers
head: 32fd20e87ddf0c0395dcf9f06e3c4b1c9f745eef
```

Its ancestry contains:

```text
#45 → #52 → #60 → #61 → #62 → #63 → #64 → #65 → #66 → #67
→ #68 → #69 → #70 → #71 → #72 → #73 → #75 → #78 → #79 → #80
→ #81 → #82 → #83 → #84 → #87 → #88 → #89 → #90 → #91 → #92
→ #93 → #94 → #95 → #96 → #98 → #101 → #104 → #106 → #110
→ #112 → #115
```

This chain includes Project Resource needs/contribution flows, Scambio-Dona requests/agreements/conversations/handoff/loan/matching/saved searches/notifications, stack stabilization, profile photos/trust gates, cover media, and the realistic demo world.

Do not replay these PRs individually if the tip can be integrated safely.

### B. Moderation / blocking chain — integrate tip PR #118

```text
PR #118
branch: codex/09b2-mobile-blocking-ux
head: da280adc9531a70fc8d6e5a181dcb7a035bd1665
```

Unique descendants after shared ancestry:

```text
#107 → #109 → #114 → #116 → #118
```

### C. Delegate / Co-creator + capacity chain — integrate tip PR #119

```text
PR #119
branch: codex/05e-project-participant-capacity
head: 9e056df0eaa997e8cbec4deee1ce6c8a3b225c63
```

Its unique branch includes:

```text
#97 → #99 → #102 → #105 → #108 → #111 → #113 → #119
```

This includes participation-request private chats, delegates/invites, Co-creator/Co-organizer authority, authority UX, Co-creator structural UX, and Project people capacity/fullness.

### D. Shared Project workspace — integrate tip PR #117

```text
PR #117
branch: codex/07c3-project-shared-workspace
head: aec97fb752cfe872691016936bdb33b912471307
```

PR #117 is a sibling of #119 from the same #113 ancestor. After #119 has brought in the shared delegate/Co-creator ancestry, #117 should contribute only the 07C3 workspace-specific work plus conflict resolutions.

### E. Italian localization + Settings — integrate tip PR #103

```text
PR #103
branch: codex/settings-language-preferences
head: 267560e9f97023104d498867e7aa2ffe64bec987
```

Ancestry:

```text
#100 → #103
```

## 2. Explicitly excluded work

Do NOT integrate:

```text
PR #28 — PLANETS 07B2A MLS E2EE architecture prototype
head: 01646cc6d5c0635c2a4f74e9ea39c08c5ee5365a
```

It is intentionally deferred prototype/research work.

If another open PR is discovered that is not an ancestor of one of the five included tips above, classify it as:

```text
intended production work
deferred/prototype
superseded
unknown
```

Stop before silently omitting an unknown case.

## 3. Verify the snapshot before modifying anything

Before integration:

1. fetch all remotes;
2. verify current `main`;
3. list all open PRs;
4. verify the five included tip SHAs and excluded #28;
5. reconstruct the dependency graph;
6. confirm every intended open PR is reachable from an included tip.

Expected snapshot:

```text
main: 06e983bb230a7a48514095fe407250ad6d38c148
#103: 267560e9f97023104d498867e7aa2ffe64bec987
#115: 32fd20e87ddf0c0395dcf9f06e3c4b1c9f745eef
#117: aec97fb752cfe872691016936bdb33b912471307
#118: da280adc9531a70fc8d6e5a181dcb7a035bd1665
#119: 9e056df0eaa997e8cbec4deee1ce6c8a3b225c63
excluded #28: 01646cc6d5c0635c2a4f74e9ea39c08c5ee5365a
```

If `main` or an included tip changed materially, stop and report the new graph rather than integrating a stale snapshot.

Do not modify unrelated worktrees.

## 4. Integration strategy

Create:

```text
codex/stack-integration-main-candidate
```

from exact current `main`.

Prefer merging exact descendant tip commits/branches instead of cherry-picking dozens of individual commits.

Recommended semantic order:

```text
1. #115  Resource/Profile/Media/Demo
2. #118  Moderation/Blocking
3. #119  Delegates/Co-creators/Capacity
4. #117  Shared Workspace sibling
5. #103  Italian Localization + Settings
```

Use exact verified SHAs.

Do not merge existing PRs through GitHub during this task. All work happens on the candidate branch.

## 5. Conflict resolution rule

Never use broad `ours`/`theirs` resolution.

For each conflict:

1. inspect both histories;
2. identify behavior introduced by each side;
3. retain both when compatible;
4. adapt types/interfaces/tests to the cumulative product;
5. run focused tests after resolving the conflict family.

The final branch is the combined product, not a winner between branches.

## 6. Known conflict hotspots

### #117 ↔ #119

Known common files include:

```text
apps/mobile/lib/l10n/app_en.arb
apps/web/src/types/database.generated.ts
docs/architecture/system-design.md
docs/development/database.md
docs/implementation/roadmap.md
package.json
```

Both also currently add different tests numbered `070` and `071`.

### #117 ↔ #118

Likely conflicts include:

```text
apps/mobile/lib/app/router/app_router.dart
apps/mobile/lib/features/project_chat/README.md
apps/mobile/lib/features/project_chat/presentation/project_chat_screen.dart
apps/mobile/lib/l10n/app_en.arb
apps/web/src/types/database.generated.ts
docs/architecture/system-design.md
docs/development/database.md
docs/implementation/roadmap.md
```

Preserve blocking controls, workspace organization tools, relocated Needs, and chat security/identity behavior.

### #119 ↔ #118

Preserve both capacity/fullness and blocking/moderation behavior across shared participation/Proposal/Tavolo surfaces.

### #117 / #118 ↔ #103

Preserve Settings routes, workspace routes, blocking routes, localization, and all required dependencies.

## 7. Duplicate pgTAP numbering

Known collision:

```text
#117:
070_project_shared_workspace_structure.test.sql
071_project_shared_workspace_access.test.sql

#119:
070_project_people_capacity_structure.test.sql
071_project_people_capacity_access.test.sql
```

After all database branches are integrated:

1. inventory every `supabase/tests/*.sql`;
2. ensure every numeric filename is unique;
3. rename conflicting test files to globally unique numbers;
4. preserve all test semantics;
5. update references if needed.

Audit for additional numbering collisions.

## 8. Migration ordering audit

Parallel branches created migrations independently.

After integration:

1. list migrations in lexical timestamp order;
2. verify cross-branch dependencies;
3. ensure referenced tables/functions exist before use;
4. ensure later `create or replace` definitions retain cumulative behavior;
5. detect duplicate overloads that restore older semantics;
6. run an empty-database reset.

Do not assume PR merge order controls migration order.

Because these migrations are still unmerged, renaming an unmerged migration may be considered when clearly safer than an artificial corrective migration. Do not rewrite migration history already merged to `main`.

## 9. Preserve current main DEMO-A and realistic DEMO-B

Current `main` already contains earlier demo tooling. PR #115 reintroduced/upgraded DEMO-B on a diverged stack.

Final behavior must:

- preserve current DEMO-A;
- preserve the realistic DEMO-B from #115;
- avoid duplicate demo scripts/commands;
- preserve local-only protections;
- preserve realistic covers/profile fixtures;
- preserve idempotent legacy-demo migration.

Run demo seed/verify on the cumulative database.

## 10. Modernize stale cumulative database tests

Integration is the correct place to fix old tests that still assert historical plan boundaries.

Example already verified:

```text
supabase/tests/031_resource_listings_structure.test.sql
```

still asserts that:

```text
public.resource_listing_requests
```

does not exist, despite later accepted Scambio-Dona implementation creating it.

For every failing historical test:

1. identify its original responsibility;
2. determine whether a later accepted feature intentionally invalidated a negative assertion;
3. update the test to validate what still belongs to its original responsibility;
4. move later-state assertions to the later owning suite if appropriate;
5. preserve meaningful security assertions.

Do not remove accepted product features to satisfy stale tests.

## 11. pgTAP portability

Replace unsupported helpers such as old `unlike(...)` usage with helpers available in the pinned local environment, e.g.:

```text
ok(...)
is(...)
results_eq(...)
throws_ok(...)
```

Do not change the database image just to support obsolete test syntax.

## 12. Date/time and fixture determinism

Repair failures caused by aging timestamps, sub-second clock assumptions, or cross-verifier fixture contamination.

Prefer relative `statement_timestamp()` fixtures for relative lifecycle tests.

Make `npm run db:test` independently repeatable after `npm run db:reset`.

## 13. Database lint warning

Recent branches report an inherited unused/unread variable around:

```text
acknowledge_project_requirement_attention
```

Inspect the cumulative function.

If genuinely unused, remove it safely while preserving behavior. Do not globally suppress the warning.

Aim for a clean database lint result.

## 14. Generated DB types

Do not manually resolve `apps/web/src/types/database.generated.ts` as authoritative.

After final migrations:

```text
npm run db:types
npm run db:types:check
```

Commit the generated result.

## 15. Router integration

The final mobile router must contain the union of intended routes, including current main plus implemented Resource flows, Settings/language, blocking, delegates/invites, co-creator management, workspace, notifications/messages, and related screens.

Do not duplicate paths or lose Auth/profile return-intent behavior.

## 16. Dependency manifest integration

Final manifests must contain the union of actually required dependencies/scripts.

Examples likely required include:

- Settings persistence dependency;
- `url_launcher`;
- image/crop/picker packages;
- `share_plus`;
- all currently validated app dependencies.

PR #28/OpenMLS dependencies must remain excluded.

Resolve `pubspec.yaml` semantically, then regenerate `pubspec.lock`; do not hand-edit lock versions.

## 17. Localization integration

PR #103 adds Italian localization, while later branches added many English keys.

After all feature merges:

1. retain every current key in `app_en.arb`;
2. preserve existing `app_it.arb` translations;
3. add Italian translations for newly integrated user-visible keys missing from Italian;
4. preserve placeholder signatures/metadata;
5. run `flutter gen-l10n`;
6. run localization tests.

Do not solve conflicts by deleting later strings or disabling Italian.

## 18. Product behavior regression checklist

Preserve already-implemented behavior from the included stacks, including where present:

### Project / participation
- resource needs;
- join contribution selections;
- current commitments;
- live need coverage;
- Needs chat resurfacing;
- actual contributions;
- people capacity/fullness;
- participation-request private chats.

### Scambio-Dona
- requests;
- agreements;
- conversations;
- negotiation/handoff/return/timeline;
- loan availability;
- matching;
- saved searches;
- matching notifications;
- covers.

### Delegated management
- Co-organizer;
- Co-creator;
- invite links;
- authority management;
- structural edit/lifecycle UX;
- shared Project workspace.

### Media/trust
- profile photos;
- photo visibility/trust gates;
- Project/Tavolo covers;
- Resource covers;
- realistic demo assets.

### Safety
- reporting/moderation;
- corroboration;
- Scambio counterstatement;
- user blocking domain + mobile UX.

### Settings/localization
- Italian;
- language preference;
- Settings surface.

This is a regression checklist, not permission to invent absent features.

## 19. Combined participation/blocking/capacity behavior

Resolve shared participation conflicts so the final behavior simultaneously preserves:

- manager authorization;
- capacity/fullness;
- blocked-user restrictions;
- request/accept/reject/leave/remove flows;
- Co-organizer/Co-creator independence from ordinary membership;
- privacy-safe blocked-state failures.

Add focused integration tests where combined behavior was never tested on one branch.

## 20. Combined chat behavior

Final `project_chat_screen.dart` must preserve:

- human/system mixed history;
- Realtime behavior;
- Needs attention/count/pulse;
- Needs in the organization-tools strip;
- Workspace quick action;
- blocking/report actions;
- read-only former-member behavior;
- identity safety.

Do not move Needs back into the composer just to simplify a conflict.

Do not expose Workspace to former members.

## 21. Settings/router/package reconciliation

Merge #103 last.

Final app must expose Settings/language while retaining all routes and feature packages from the other stacks.

Regenerate dependency lockfiles and localization output from the final manifests/catalogs.

## 22. Documentation reconciliation

Reconcile:

```text
docs/architecture/system-design.md
docs/development/database.md
docs/implementation/roadmap.md
feature READMEs
```

to the cumulative implementation.

Do not take one branch's docs wholesale.

Roadmap must distinguish:

```text
implemented in integration candidate
not yet merged to main
deferred
not started
```

Keep MLS/E2EE prototype explicitly deferred.

Preserve all `history-implementations/` prompt archives.

## 23. Integration record

Add:

```text
docs/development/stack-integration-2026-09.md
```

Record:

- starting main SHA;
- included tips/SHAs;
- excluded work/reason;
- integration order;
- conflicts resolved;
- test renames;
- migration fixes;
- stale tests repaired;
- any real cumulative production bugs fixed;
- final validation;
- remaining issues.

## 24. Do not close old PRs yet

Do NOT:

- merge the integration PR;
- merge old PRs individually;
- close old PRs;
- delete branches;
- retarget every old PR;
- force-push feature branches.

Old graph stays intact until founder review.

## 25. Full validation target

This integration candidate should make the repository coherent rather than accepting focused-only validation.

### Database

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

If `check:db` fails, classify and fix repository-owned deterministic issues. Do not hide failures.

### Demo

Run:

```text
npm run demo:reset:local
npm run demo:verify:local
npm run demo:seed:local
npm run demo:verify:local
```

Verify second-run idempotency.

### Mobile

```text
npm run check:mobile
flutter build apk --debug
```

### Web/site

```text
npm run check:web
npm run check:site
```

### Hygiene

```text
npm run format:check
git diff --check
```

Fix safe mechanical formatting debt rather than knowingly carrying a red repository-wide check, but avoid broad cosmetic rewrites.

## 26. Targeted integration tests

Add focused tests only where combining branches creates new interactions, e.g.:

- blocking + participation capacity;
- blocking + Project request actions;
- workspace + blocking/report chat actions;
- Settings router + new routes;
- Italian key completeness;
- Co-organizer management + capacity;
- Co-creator structural edit + cover/trust fields;
- realistic demo against cumulative profile/cover/capacity/moderation schema.

## 27. Hosted CI limitation

Make one final-head hosted validation attempt if normal workflow triggers.

If GitHub again reports the known billing/spending-limit block before any step runs, document it and do not rerun unchanged infrastructure failures.

Local full validation remains required.

## 28. Genuine product conflicts

If two accepted branches encode genuinely incompatible product semantics:

1. do not silently choose;
2. preserve work completed so far;
3. document exact conflicting behavior/functions/files;
4. stop before calling the integration ready;
5. report the founder decision required.

Ordinary code/test conflicts should be resolved autonomously.

## 29. Draft integration PR

Push the candidate and open:

```text
Draft PR → main
```

Suggested title:

```text
STACK-INTEGRATION-02: consolidate current PLANETS product stacks
```

PR body must include:

- exact main base SHA;
- included tips/SHAs;
- excluded PR #28;
- integration order;
- major conflict resolutions;
- database-test modernization;
- migration/test renames;
- localization reconciliation;
- full validation;
- hosted CI status;
- explicit `DO NOT MERGE until founder review`.

## 30. Acceptance criteria

- [ ] Starts from exact verified `main`.
- [ ] Every open PR is classified.
- [ ] PR #28 remains excluded.
- [ ] #115 lineage integrated.
- [ ] #118 lineage integrated.
- [ ] #119 lineage integrated.
- [ ] #117 workspace sibling integrated.
- [ ] #103 localization/settings lineage integrated.
- [ ] No included stack replayed twice.
- [ ] DEMO-A + realistic DEMO-B coexist.
- [ ] Duplicate pgTAP filenames eliminated.
- [ ] Migration order valid from empty DB.
- [ ] Stale historical assertions updated to cumulative intent.
- [ ] Unsupported pgTAP helpers replaced.
- [ ] Fixtures deterministic/isolated.
- [ ] Generated DB types regenerated.
- [ ] Router is the intended union.
- [ ] Dependency manifests are the intended union with no MLS/OpenMLS prototype dependency.
- [ ] English and Italian localization are complete and structurally compatible.
- [ ] Blocking, capacity, participation, delegates, workspace, Needs, and chat coexist.
- [ ] Profile-photo/cover behavior survives.
- [ ] Moderation/blocking survives.
- [ ] Settings/language survives.
- [ ] `npm run db:test` passes.
- [ ] `npm run check:db` passes, except only a precisely documented external/non-deterministic environment failure that cannot be repository-fixed.
- [ ] demo seed/verify passes twice.
- [ ] `npm run check:mobile` passes.
- [ ] Android debug APK builds.
- [ ] `npm run check:web` passes.
- [ ] `npm run check:site` passes.
- [ ] formatting/diff checks pass.
- [ ] integration record committed.
- [ ] prompt archived exactly.
- [ ] draft PR to `main` opened.
- [ ] `main` unchanged.
- [ ] old PRs/branches untouched.

## 31. Completion report

Return:

1. starting `main` SHA;
2. integration branch;
3. final head SHA;
4. draft integration PR number/link;
5. included tip SHAs actually used;
6. full open-PR classification:
   - included through ancestry,
   - excluded/deferred,
   - superseded if any;
7. actual integration order;
8. major conflicts and resolutions;
9. test files renumbered;
10. migration-order corrections;
11. stale pgTAP tests modernized;
12. actual cumulative production bugs fixed;
13. router/dependency/localization reconciliation;
14. database test counts/results;
15. `check:db` result;
16. demo idempotency result;
17. mobile test count + APK result;
18. web/site results;
19. format/diff results;
20. hosted CI result;
21. remaining warnings/decisions;
22. confirmation that:
   - `main` was not modified,
   - integration PR is draft/unmerged,
   - PR #28 was excluded,
   - no existing feature PR was closed/force-pushed/deleted.

Do not report success while a repository-owned deterministic full-suite failure remains unexplained.
