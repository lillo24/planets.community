# PLANETS MODINT01 — reconcile MAP01/HELP01 on PR #154

Continue the existing draft PR #154 in `lillo24/planets.community`. Integrate current committed main, resolve the generated-contract and package-script conflicts, and close the new location-service suspension gap. Produce a conflict-free, validated integration and updated founder-review packet on the same PR.

This is the remaining integration work before founder wording/presentation approval. The completed moderation Android/browser campaigns remain evidence for their tested sources; do not repeat them wholesale merely because approval is pending.

## 1. Exact baseline and current repository evidence

- Branch: `codex/modint01-moderation-auth-integration`.
- Published head: `db29c344c3a589e397bab627016080fe52d22d83`.
- Tested copy-correction source: `ce942c10c316f7ea4754bf2a37cbbeb19ecfb809`.
- Included main: `55219709cef1a533ee39b787949ae05838d3171a`.
- Current main verified for this prompt: `70f8ed3b92db2ba90792c3bd4de44412f1b3462d`.
- Main now includes MAP01 #172 (merge `6650d995c4a393ef43e13f16d51933645be72db9`) and HELP01 #173 (merge `70f8ed3b92db2ba90792c3bd4de44412f1b3462d`).
- Hosted run `37789890129` passed Mobile/Web/Site/Database on `ce942c10`. Tested→published changes are three Markdown files only. That run does not cover later main.
- PR #154 is currently draft/unmerged and conflicting. The recorded conflicts are `package.json` and `apps/web/src/types/database.generated.ts`; inspect actual current conflicts rather than assuming the list is unchanged.

Read current `AGENTS.md`, relevant folder maps, the existing integration review/copy packets, and MAP01's runbook `docs/development/map01-geoapify-location.md`. All required technical/design context is repository-backed. No provider account/key, external document or hosted backend is required.

Fetch and pin actual origin/main once at task start; record any advancement beyond the verified pin. Merge it into the existing MODINT01 branch, retaining both histories and all selected moderation-stack ancestors. This continuation explicitly overrides the default new-worktree/new-PR workflow. Preserve the corrected EN/IT `noticesRestrictionEffect` exactly.

Resolve package scripts semantically: keep both moderation/integration verifiers and MAP01's location verification in the appropriate Database/CI order. Replay the combined migrations and regenerate Web database types from that actual schema; do not resolve types through a textual union or discard either branch's API. Check SQL test-prefix uniqueness and generated-type drift.

## 2. Integrate location services with the existing suspension boundary

MAP01 adds six public functions, including three service-only functions:

- `reserve_location_search_v1`
- `issue_location_selections_v1`
- `resolve_location_selection_v1`
- `apply_item_location_v1`
- `get_public_item_location_v1`
- `get_authorized_item_location_v1`

Inspect their grants, helpers and effective call chains after integration. The old 232-signature inventory is a baseline, not the target count. Update the explicit inventory in `docs/development/account-suspension-rpc-inventory.json` with reviewed classifications, not an audit bypass.

A specific source gap needs correction: `supabase/functions/location-search/index.ts` validates the bearer through Auth's user endpoint, then calls PostgreSQL using the service role. A valid Auth session can belong to a suspended account. The new `private.lock_location_item` in migration `20261008124856_geoapify_shared_location_foundation.sql` checks profile existence and item authority; its Resource branch checks ownership but has no canonical suspension check. The client-facing identity helper does not protect that service-role path.

Reuse the stack's canonical account-status check for the actual stored/verified actor. Never substitute the service role's `auth.uid()`, token validity, profile existence, or a client-supplied active flag for that check. Add a forward migration if SQL changes are required; do not rewrite the merged MAP01 migration.

Ensure new reservations, resolution and issuance of selection results enforce the actor's current account access, including batches created before suspension. Respect existing serialization/lock order and actor/item/revision/slot binding. Canonical denial must not allocate new budgets/receipts or publish selection data for an already-suspended actor. An upstream request legitimately started before suspension cannot be retroactively recalled; distinguish that from release of new receipts/results after suspension and keep honest accounting for actual work.

Keep the Edge response safe and compatible with the established account/auth failure contract; expose no reason, staff note or raw database diagnostic. Verify the Flutter gateway fails closed on denial and stale actor completions.

Preserve existing distinctions:

- Public location reads expose only genuinely public, canonically visible information. Test content-hide suppression for Proposal/Tavolo/Resource public location projections.
- Authenticated protected reads/writes deny suspended actors and expected-identity mismatches while retaining normal active-member/manager/owner rules.
- Existing memberships, agreements and organizer roles remain stored.
- Interaction restriction is not blanket suspension and does not remove ordinary organizer permissions.
- Content hide remains separate from owner lifecycle and preserves entitled existing relationships.
- Search receipts, selected protected coordinates and provider metadata do not leak through legacy reads, templates or durable editor snapshots.

Keep MAP01's runtime/database kill switches off, all hard budgets intact and production provider activation deferred. Use fake provider responses and an owned disposable backend; make no real Geoapify calls.

## 3. Preserve Help/tutorial routing and draft privacy

HELP01 adds public Help/contact/bug/person-guidance routes and tutorial replay. Preserve its signed-out public entry, review-before-mail-handoff behavior, in-memory support draft, truthful launcher results and configured contact.

Check these additions against MODINT01's global suspension/status-failure precedence:

- Direct Help/tutorial URLs, Back, Welcome and replay completion cannot open private account views or escape the existing account-status gate.
- Do not introduce a new suspended-account Help exception or appeal route.
- Account switch, same-actor suspension/status failure and late launcher/clipboard callbacks cannot restore an obsolete draft, private view or navigation destination.
- Public signed-out Help continues to work and no private account read is added to guest navigation.
- No email is sent by QA; use the existing injectable launcher/widget pattern.

Preserve both histories' tests and localization keys. Adjust incoming expectations only when the existing canonical gate or demonstrated current routing requires it; do not weaken privacy assertions to make reconciliation pass.

## 4. Validate affected integration, then publish for founder review

First demonstrate the location-service gap with a meaningful failing regression, then show it passing after the canonical fix. Include active and pre-existing suspended sessions, Resource owner and Project structural authority, protected reads/writes, service grants, existing-batch resolve/issue after suspension, and expected-actor mismatch. Add observed concurrency coverage where needed to verify the chosen account/item lock composition, without inventing guarantees for already-started network requests.

Run the merged MAP01 verifier and suspension/integration audit together on the owned task backend. Validate replay/lint/advisors, required Database tests, type drift, relevant real-auth/concurrency verifiers, package/CI command ordering and demo compatibility. Run the required combined-source Mobile/Web/Site checks and normally classified final-source CI once. Inspect actual job checkouts/results and record exact SHAs.

Keep native/manual work focused on demonstrated changed behavior. Existing full OTP/request/browser campaign evidence stays completed with its source boundaries. Run affected Help/tutorial/account-gate checks and location gateway/Edge fixtures; repeat a full real campaign only if a new production change invalidates that evidence. Do not create another identical screenshot or QA campaign for unchanged wording.

Use the documented MODINT01 configuration preparer before task-backend work; canonical configuration was restored. Protect shared demo and hosted closed-test environments. Complete reset-based Database work before preparing UI actors. The founder's request to leave existing emulator/build processes running remains in force. Avoid heavyweight builds alongside native execution; do not stop those processes or shared services incidentally.

Update the same review packet, copy packet/source provenance, inventory/runbook documentation and PR description. Archive this prompt under `history-implementations/`. State whether target main moved again and whether the PR is conflict-free; assess actual new differences rather than endlessly chasing unrelated commits or claiming latest-main coverage you did not run.

Keep #154 draft/unmerged. No readiness transition, predecessor closure, production deployment, provider activation, billing/DNS change or dependency upgrade is authorized. Existing dependency/Realtime/device/accessibility/hosting limitations retain their separate dispositions. Do not claim founder approval.

Return the same PR URL, included-main/tested/published SHAs, conflict resolution, demonstrated location guard fix, actual validation, source-equivalence evidence and remaining founder review items. Once this integration passes, the next decision is founder approval of the delivered wording/presentation—not another unrequested full QA loop.
