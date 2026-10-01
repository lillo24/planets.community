# PLANETS STACK-INTEGRATION-02C — Final Hosted-CI Stabilization Before Merge

**Repository:** `lillo24/planets.community`  
**Existing PR:** #120 — `STACK-INTEGRATION-02: consolidate current PLANETS product stacks`  
**Patch in place from exact head:** `8afc8910c89ea1cccfd41e24bb5eeb7cf2b5e907`  
**Branch:** `codex/stack-integration-main-candidate`  
**Target remains:** `main`  
**Do NOT open another PR. Do NOT merge #120.**

Archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_STACK_INTEGRATION_02C_final_ci_stabilization.md
```

## Objective

Patch PR #120 in place for the two remaining hosted-CI failures from Validation run `36835008884`.

One is a real fail-closed web-admin issue discovered by CI.

The other is a viewport-sensitive Flutter widget-test failure.

Do not add product features.

After this patch, rerun the affected local checks and allow one normal hosted CI attempt. The goal is a green final integration PR ready to merge.

## 1. Verify exact starting state

Before editing, verify:

```text
PR #120
base: main @ 06e983bb230a7a48514095fe407250ad6d38c148
head: 8afc8910c89ea1cccfd41e24bb5eeb7cf2b5e907
draft: true
mergeable: true
```

If the head moved, stop and report the new head.

Do not create PR #121, modify `main`, close/retarget old PRs, or merge #120 yet.

## 2. Hosted Mobile failure: make delegate widget test viewport-robust

Hosted Mobile passed restore, localization, formatting, analysis, and 1,071 tests, then failed only:

```text
apps/mobile/test/features/project_delegates/presentation/project_delegate_flow_test.dart
team roles can change while self authority has no actions
```

The failure occurred after trying to promote `project-delegate-promote-operator`; the confirmation dialog never became available on the hosted 800x600 render and the later finder for the `FilledButton` labeled `Promote to Co-creator` returned zero widgets.

The same test passes locally.

Required fix:

- make this test deterministic across hosted/default viewport sizes;
- keep the real promotion/demotion/revocation behavior assertions;
- scroll the exact keyed controls into a hittable position;
- pump after scrolling;
- explicitly assert the action/dialog exists before tapping;
- use a controlled test viewport if appropriate and restore it afterward;
- do not use `warnIfMissed: false` merely to hide the problem;
- do not skip the test on CI;
- avoid production UI changes unless a real production layout bug is discovered.

Run the exact test repeatedly locally if practical.

## 3. Hosted Database failure: signed-out `/admin` must fail closed even if Auth/client establishment throws

Hosted Database passed migration replay, lint, advisors, all 104 pgTAP files / 3,236 assertions, and all domain verifiers before failing:

```text
npm run auth:web:verify:local
Error: Signed-out /admin did not fail closed (HTTP 200).
```

Current root cause:

```ts
const result = await readModerationQueue(...).catch(() => null);

if (result === null) {
  return <Queue unavailable ... />;
}
if (result.status === "denied") notFound();
```

and the case-detail page uses the same pattern.

`readModerationQueue()` normally returns `{ status: "denied" }` for a signed-out caller. But if identity establishment itself throws — for example:

```text
createSupabaseServerClient()
client.auth.getClaims()
staff-access RPC call itself throwing
```

the page-level catch converts that to a generic operational-unavailable state, which renders HTTP 200 and exposes the existence of the moderation surface.

Required semantics:

### Cannot establish authorized staff identity

Examples:

```text
signed out
invalid/missing session
create-client/session lookup failure
getClaims error/throw
staff-access RPC denied/error/throw
unknown/malformed staff role
```

Result:

```text
denied
→ notFound()
→ HTTP 404
```

### Staff identity established, later moderation read fails

Examples:

```text
authorized moderator/admin
list_moderation_cases RPC fails
case-detail/evidence RPC fails
```

Result may remain:

```text
Queue unavailable
Case unavailable
```

because staff authorization is already proven.

Preferred boundary: harden `requireModerationStaff(...)` so failures while establishing staff identity return `null` instead of escaping. Then operational RPC failures after authorization can continue to throw and be rendered as staff-safe unavailable states.

Audit both queue and case-detail routes.

## 4. Admin tests

Extend:

```text
apps/web/src/features/moderation/moderation-server.test.ts
apps/web/src/app/admin-route.test.ts
```

and case-route tests as appropriate.

Cover:

```text
signed-out normal result → denied
create client throws → denied
getClaims throws → denied
staff-access RPC returns error → denied
staff-access RPC throws → denied
ordinary authenticated non-staff → denied
authorized moderator/admin → ready
authorized queue RPC failure → still throws operational "could not be loaded"
signed-out /admin → 404
signed-out /admin/cases/<valid uuid> → 404
ordinary non-staff /admin → 404
authorized staff + operational queue failure → Queue unavailable
authorized staff + operational case failure → Case unavailable
```

Do not reveal whether denial came from missing session, role, or staff record.

## 5. Reproduce the hosted web-auth boundary locally

Run:

```text
npm run db:start
npm run web:config:local
npm run build --workspace @planets/web
npm run auth:web:verify:local
```

The signed-out `/admin` 404 boundary must pass.

Do not loosen the verifier.

## 6. Validation

Focused first:

```text
cd apps/mobile
flutter test test/features/project_delegates/presentation/project_delegate_flow_test.dart
```

Run it more than once if practical.

Then:

```text
npm run test --workspace @planets/web
npm run lint --workspace @planets/web
npm run typecheck --workspace @planets/web
npm run build --workspace @planets/web
npm run auth:web:verify:local
```

Then final integration checks:

```text
npm run check:mobile
npm run check:web
npm run check:site
npm run check:db
flutter build apk --debug
npm run format:check
git diff --check
```

No database migration or generated DB type change should be necessary.

## 7. Hosted CI

Push the new final head to existing PR #120 and allow one normal Validation run.

Goal:

```text
Change classification: PASS
Mobile: PASS
Web: PASS
Site: PASS
Database: PASS
```

If a new failure appears, inspect and classify it; do not blindly rerun.

## 8. Documentation / PR body

Update:

```text
docs/development/stack-integration-2026-09.md
```

with a short final-CI correction section:

- hosted delegate-test viewport fragility and deterministic fix;
- signed-out moderation fail-closed inconsistency and server-auth fix;
- local/hosted validation result.

Update PR #120 body with the new final head and final CI status.

Keep #120 draft until founder chooses to merge.

## 9. Acceptance criteria

- [ ] Started from exact `8afc8910c89ea1cccfd41e24bb5eeb7cf2b5e907`.
- [ ] PR #120 patched in place.
- [ ] No new PR opened.
- [ ] `main` unchanged.
- [ ] Delegate role-change test is robust on hosted/default small viewport.
- [ ] Test still verifies real promotion/demotion/revocation.
- [ ] Signed-out `/admin` returns 404 even if client/Auth/staff-access establishment throws.
- [ ] Signed-out case-detail route also fails closed.
- [ ] Ordinary non-staff fails closed.
- [ ] Operational failure after established staff authorization still renders unavailable state.
- [ ] `auth:web:verify:local` passes.
- [ ] `check:mobile`, `check:web`, `check:site`, `check:db` pass.
- [ ] Android debug APK builds.
- [ ] format/diff checks pass.
- [ ] Previous blocking/capacity and founder-QA mobile corrections remain intact.
- [ ] PR #120 remains draft/unmerged pending founder merge decision.

## Completion report

Return:

1. exact starting head;
2. final head;
3. confirmation #120 patched in place;
4. Mobile test fragility root cause and deterministic fix;
5. signed-out `/admin` root cause;
6. final `requireModerationStaff` / fail-closed behavior;
7. admin route/unit/integration tests added;
8. local web-auth smoke result;
9. full mobile test count;
10. web/site results;
11. database/check:db result;
12. APK result;
13. formatting/diff result;
14. hosted Validation result per job;
15. confirmation:
    - `main` unchanged,
    - no new PR,
    - #120 draft/unmerged,
    - prior 02A/02B corrections preserved.

Do not call #120 merge-ready while a deterministic security-boundary or hosted test failure remains unexplained.
