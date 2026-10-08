# PLANETS MODINT01 — moderation/Auth stack integration for founder review

Integrate the completed moderation/Auth stack through PR #148 with current committed `main` in `lillo24/planets.community`. Resolve real compatibility problems, validate the combined application and publish one draft PR targeting `main`, with a concise founder review packet. This task prepares a concrete result for review; it does not merge or deploy anything.

Read `AGENTS.md`, relevant feature READMEs, architecture and existing task reports. Continue through reconciliation, fixes and validation without pausing for routine implementation choices. Preserve both histories and already-established product/security behavior.

## 1. Pin inputs and retain ancestry

| Input | Verified head at prompt preparation |
| --- | --- |
| Committed `main`, including #147 account exits/navigation | `67133025b4dc8a90a3d303e70d69df6ee6faf84c` |
| Moderation/Auth stack, draft #148 | `24d8f7fd21eeacb41055a16a2f3198b8148c9580` |

Fetch and pin `main` once at task start. If it has advanced, inspect its committed changes, record the exact replacement baseline and include that current baseline within this integration task. Keep #148's exact selected source; inspect any movement of that branch without silently replacing it.

Create `codex/modint01-moderation-auth-integration` from the selected `main`, then merge the exact #148 head preserving ancestry. Target `main` with a **draft PR**. Do not squash/cherry-pick the stack into an unrelated history or rewrite predecessor branches.

Verify inherited #148 → #144 → #142 → #139 → #136 → #133 → #130 → #126 → #125 → #123 ancestry and preserve each contribution. Include only committed `main` plus this selected stack and necessary integration fixes. In particular, unmerged #146 templates/workshop remains a separate review; do not import it or other active draft work.

Read [#148's final evidence](https://github.com/lillo24/planets.community/pull/148#issuecomment-6013750582) and `docs/development/moderation-own-request-explanations-09c2b2-review.md`. Tested source `fd373e3d066791abfe736d7c3fc8a4364f4e14ba` passed hosted run `37444791738`: Mobile/Web/Database passed, Site skipped. Published #148 adds only review documentation. These results validate that predecessor, not the new combined tree.

Keep all predecessor PRs open and draft. Do not close them as superseded, mark anything ready, merge, deploy, publish an app build, apply migrations to a shared/hosted database, or change hosting/resources/billing/DNS.

## 2. Reconcile behavior, not only text conflicts

Inspect the complete diff from the merge base, including cleanly merged files. Current `main` includes unified Project People/role offers, PI01–PI05 participant links and #147 account exits/configurable navigation. The stack changes Auth bootstrap, suspension routing, Settings/private notices, request forms, backend enforcement, dependencies and CI.

Preserve these combined invariants:

- Normal OTP login converges to ready Home without the stale setup error. Genuine bootstrap failures remain visible; obsolete SDK/session operations cannot restore another account or a signed-out session. Retain #144's controlled ordering and normal-UI regressions.
- All existing sign-out controls, including #147's account exits, use canonical Auth/session cleanup. Preserve configurable navigation for ordinary account access. Suspended identities cannot reach Home, Profile, Settings, private notices, Messages or invite/manager screens through a shortcut, Back, deep link or old route stack. The dedicated suspension screen retains status refresh/sign-out.
- Private notices remain own-only, with verbatim reasons, correct pagination and clear active/removed state. Both request forms retain the independently checked own-status explanation, generic canonical failure, private-notices/Back draft preservation and explicit canonical retry. Never infer eligibility from a history page or disclose another person's block/moderation state.
- Main's participant invitations remain distinct from delegate/role offers. Preserve photo-free direct admission, identity-bound action receipts, response-loss recovery, membership origin nullability, capacity/organizer semantics, request supersession and membership/chat continuity. Existing request-based photo gates still apply where specified.
- Preserve staff apply/revoke controls, current moderator/admin authorization, admin-only suspension, self-suspension rejection, separate user reasons/private notes and immutable history. No new public warning/badge or automatic moderation policy is introduced.
- Preserve main's recorded-actor notification behavior and demo recovery/idempotency checks. Moderation consequence source events still gain no notification recipient projection or delivery in this task.

Resolve conflicts with the smallest coherent implementation, retaining regression tests from both inputs. A successful Git merge is insufficient evidence of compatibility.

## 3. Audit the replayed backend and new API boundaries

Replay the combined migrations on an isolated disposable backend. Inspect final definitions, grants, RLS, generated types and runtime contracts. Do not rewrite already-published migration history or relax chronology/provenance constraints to make fixtures pass. Use a forward migration for any demonstrated compatibility repair.

PI01's direct-invitation migration was added after the suspension-enforcement migration. Verify the complete **merged** authenticated RPC inventory, not the inherited count of 194. Cover invitation management/admission/resolution, Project People/role offers and all compatibility overloads alongside existing moderation APIs. Test actual denial with authenticated suspended identities, including pre-existing sessions. Public/anonymous preview contracts need their precise classification; do not grant a broad ordinary-account exception or waive unknown signatures.

Verify these interactions against canonical guards:

- participant-link admission and request/role-offer paths versus suspension, requester/manager blocking, active interaction restriction, content hiding, lifecycle and capacity;
- public invitation preview versus hidden content: it must not disclose a hidden Project's title/ID through a bearer link when canonical visibility denies that projection;
- idempotent admission recovery versus fresh admission: read-only recovery must not create membership, restore a departed episode, consume capacity or mint chat entitlement;
- new authenticated reads and mutations versus expected-ID mismatch, missing profile anchor, anonymous access, deactivated staff and account suspension;
- apply/revoke serialization versus invitation/request admission and existing accepted relationships.

Reuse canonical identity/interaction/visibility helpers and lock ordering. Preserve approved semantics rather than adding blanket manager/participant restrictions. Distinguish a demonstrated enforcement gap from an unresolved product question; document a concrete question if existing contracts do not define it, and complete independent integration work without inventing policy.

Regenerate database types through the combined repository tooling. Preserve main's participant-origin nullability handling. Update inventory/audit coverage exactly; keep the narrow own-suspension status exception and safe own-status/history boundaries.

Reconcile package manifests/lockfiles from the selected inputs, retaining #133 remediation and #130's narrow Next patch. No opportunistic dependency upgrades. Report current advisories and any actual gate failure accurately; do not describe inherited `braces` findings as resolved or treat an earlier audit count as a current scan.

## 4. Validate the combined source

Add tests for demonstrated integration risks or fixes, using controlled ordering for async races. Keep inherited coverage executable, including the observed-lock membership CI verifier and main's demo idempotency/recovery checks. Do not relax assertions/timeouts, remove tests, rerun until green without explanation, or classify relevant failures away.

Run repository-required Database, Mobile, Web, tooling and Site validation on the combined source, plus Android compilation. Include schema/security checks, generated-contract drift checks, complete RPC suspension audit, real-auth moderation/consequence/suspension verifiers and applicable concurrency gates. Record actual commands, counts and failures; predecessor results cannot substitute for these checks.

Use task-owned services, synthetic identities and restored-checkout configuration. Recreate isolated configuration instead of using stale startup commands. Preserve shared backends/devices and use the proven OTP/PKCE approach.

Run a focused real Android integration smoke: normal OTP/Home/profile setup; #147 sign-out controls and navigation selection; own notices; both restricted request forms with notices/Back/draft retention and revoke/retry; account switch; suspension during ordinary access and shortcut/deep-link attempts; status refresh after revocation. Exercise participant invitation admission and existing membership/chat continuity in the combined app.

Run real local browser checks for staff apply/revoke authorization and browser participant joining/handoff boundaries where the combined routes/contracts changed. Reuse existing harnesses and fixtures. Record public content hiding/preview evidence without publishing tokens, OTPs, privileged credentials or private reasons.

Physical-device, iOS, TalkBack/VoiceOver and hardware-keyboard checks remain separately labelled unless actually run. Host/widget semantics are not native accessibility evidence. Do not expand into another historical DB/Realtime investigation without a relevant new failure; preserve unresolved findings explicitly.

Verify hosted CI on the final tested integration source, including actual classification and every required job. Explain legitimate skips. If a later publication changes only documentation/screenshots, prove source equivalence and record both tested and published SHAs; do not claim an unrun final-head run. Record any later movement of target `main` and actual mergeability without implying it was tested if it was not included.

## 5. Prepare one concrete founder review packet

Write `docs/development/modint01-moderation-auth-integration-review.md` with:

1. Exact pinned inputs, merge ancestry, tested/published head and draft PR.
2. A compact source-PR → delivered behavior → integration evidence table, plus substantive reconciliation fixes.
3. Local/hosted results and real-flow evidence, with failures and unrun checks distinguished.
4. Exact current EN/IT moderation copy and representative synthetic screenshots: suspension, private notice types/active/removed states, and Project/Resource request explanations. Extract wording from the combined source; do not silently rewrite it or claim founder approval.
5. A short decision table distinguishing review of delivered copy/presentation from separately proposed counterparty warnings, owner contextual UI, notification channels/disclosure, appeals and minimum-age policy.

Carry forward material unresolved items: dependency advisories, historical DB/Realtime causes, native QA gaps and Cloudflare compatibility/free-CPU uncertainties. #144 repaired the specific OTP/Home bootstrap race; do not present that old setup-error symptom as still unresolved or claim it repaired unrelated incidents. Hosting remains unselected; the existing conventional Next.js/Node recommendation is an assessment, not a deployment decision.

Update roadmap/nearest READMEs to describe the **integration draft in review**, retaining remaining 09C2B and later work as deferred. Archive this exact prompt as `history-implementations/PLANETS_MODINT01_moderation_auth_stack_integration.md`. Keep historical reports as historical evidence; link the current disposition rather than erasing earlier failed attempts.

Commit, push and open the draft PR targeting `main`. Stop only task-owned services with backups retained, restore temporary configuration and verify clean checkouts.

Finish with the PR URL, exact pinned main/stack/tested/published SHAs, fixes, CI/real-flow evidence and a concise founder review checklist. No merge/deployment or policy approval is implied. This consolidates the completed stack for review; it does not complete all of 09C2B.

