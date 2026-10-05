# PLANETS 09C2B1 — private moderation history in Mobile

Implement the first bounded slice of 09C2B in `lillo24/planets.community`: a signed-in user can read their own moderation notices, reasons intended for them, and apply/remove history in the Flutter app. Use the existing canonical own-history RPC. Produce a working draft PR with reviewable English/Italian copy.

This advances the affected-user UX already anticipated by 09C1A/09C1B/09C2A. It does not settle counterparty-warning policy or complete all of 09C2B. Read `AGENTS.md`, relevant feature READMEs and accepted architecture before editing. Continue through implementation and validation without pausing for routine choices within this scope.

## Exact base and limits

- Required base: [PR #139](https://github.com/lillo24/planets.community/pull/139), head `9a9476e3b74d9783ad74d4184baae74367020c62`.
- Predecessor branch: `codex/dbrace02-controlled-validation`.
- Create `codex/09c2b1-private-moderation-history`, stacked on that exact head; target the predecessor branch with a **draft PR**.
- Verify inherited ancestry #136 → #133 → #130 → #126 → #125 → #123. Inspect remote movement before acting; preserve this required base and do not silently import current `main` or another task's changes.

Leave this PR and its dependency stack unmerged and undeployed. Do not select hosting, provision resources, change billing/DNS, upgrade dependencies, implement appeals/minimum age, or change canonical consequence/enforcement semantics. Do not modify chronology constraints or claim the historical DB/Auth/Realtime incidents were repaired.

Read [#139's final evidence](https://github.com/lillo24/planets.community/pull/139#issuecomment-5993570838) and `docs/development/dbrace02-controlled-validation-and-failure-disposition.md`. Current local Web/Database and final-head Web/Site/Mobile/Database CI passed; the bounded observed-lock membership verifier now runs in CI. The historical incidents remain unexplained. Do not start another reproduction campaign unless new work produces a failure needing investigation.

## 1. Reuse the safe backend boundary

Inspect the final replayed definition and generated contract for:

`public.list_own_moderation_consequences(p_expected_profile_id, p_limit, p_before_applied_at, p_before_consequence_id)`

The existing projection supplies consequence ID/type, active state, apply/remove timestamps and separate user-facing reasons, plus safe content kind/ID/title where relevant. Default page size is 20; the cursor is the exact `(applied_at, consequence_id)` pair. Preserve timestamp precision and ordering when requesting another page.

It is expected-identity-bound and reads only episodes belonging to the current affected profile. Project-hide explanations belong to the immutable original Creator; Resource-hide explanations belong to the listing owner. Co-creators/Co-organizers do not gain the Creator's reasons. Do not use staff case history, direct private-table reads, a service-role key or another profile's supplied ID.

The suspension identity guard denies this general history RPC while suspended. The existing auth-owned suspension screen uses the separate narrow own-suspension status RPC. Preserve that boundary; do not allowlist general history for suspended users.

No SQL migration should be needed for this screen. If a real contract defect is discovered, demonstrate it and report the smallest justified scope rather than redesigning moderation to simplify the UI.

## 2. Build a private, readable screen

Add an authenticated account-settings entry and a route using the existing router and session guards. Suggested label/title: **PLANETS notices / Avvisi di PLANETS**. Adapt placement to the existing Settings account section; do not add a primary navigation tab or conflate these notices with the user's submitted reports.

Display the canonical newest-first history with clear active and removed states. Each episode should show its type, applied date, user-facing apply reason, and, if removed, removal date and removal reason. Show an owned-content title/type when supplied. Use readable plain text, including long reasons; do not interpret reason strings as HTML/Markdown, executable content or automatic links.

Provide loading, genuine empty, first-load failure, later-page failure, refresh and bounded pagination states. A failed or malformed response must not appear as “no notices.” Loading another page must retain already loaded rows and avoid duplicates. A refresh must reconcile changes without presenting stale status as confirmed current state. Do not infer a global active restriction from one incomplete history page or use this UI as an authorization boundary.

A removed episode remains history. Multiple types and multiple historical episodes must remain distinguishable. Do not present the total episode count as a score, strike count, guilt finding or public reputation.

Content references are optional. Showing the safe title is enough. Add a management link only if the existing owner route and authorization can handle hidden/cancelled/closed content safely; do not send owners to a public detail route that hiding intentionally denies.

## 3. Draft factual EN/IT copy for founder review

Implement concise localized labels and explanations grounded in current backend behavior. These are reviewable draft wording, not new policy approval.

| Type | Required factual meaning |
| --- | --- |
| Safety notice | PLANETS recorded a moderation notice; this consequence by itself does not restrict account actions. It is not a public profile badge. |
| Interaction restriction | While active, new outbound Project join requests and Scambio/Dona Resource requests are restricted; pending outbound requests were withdrawn when applied. Existing accepted participation/agreements and ordinary manager permissions remain governed by their existing rules. |
| Content hide | The identified content's visibility and new-interaction access are restricted by moderation. Hiding is separate from cancellation, closing or deletion. |
| Account suspension | Historical suspension episodes may be read once ordinary account access is available. An actively suspended account continues to use the dedicated suspension screen. |

Describe effects per consequence, without promising access that another active consequence may deny. Removal does not automatically resubmit withdrawn requests, reopen closed content or republish cancelled content. Reasons written by staff remain verbatim user-facing text; do not translate, paraphrase, fabricate or supplement them with private case evidence.

Do not promise appeal/support routes, response deadlines or restoration dates that do not exist. Avoid accusatory language. Record the exact EN/IT screen wording in the review report so the founder can approve a concrete result.

## 4. Preserve identity, suspension and privacy

Follow the moderation feature's existing gateway/domain/controller conventions. Derive expected identity from the verified current session. Bind all state to account-access identity and session revision; discard late responses after sign-out, account switch, suspension or controller disposal. Clear sensitive cached state on those transitions and do not persist reasons to SharedPreferences or generic caches.

Handle suspension during an in-flight request through the established auth status/guard flow. A direct link must not bypass that gate. Preserve Check status again and Sign out behavior on the existing suspension screen; no broad settings/history access is added while suspended.

Parse only the safe projection, validate required fields and maintain safe failure kinds. Never return staff notes, reporter identity, report/corroboration/counterstatement bodies, staff actor IDs or case/audit metadata to this screen. Do not send reasons or private fixture text to logging, analytics, crash breadcrumbs or push/outbox payloads.

Keep the screen usable with large text, long Italian copy, screen-reader labels, ordinary keyboard/back navigation and narrow layouts. Loading/error status must be understandable without color alone.

## 5. Deliberately separate later 09C2B work

Do not add contextual warnings about other users, a general safety-status lookup, public badges, restricted-action CTA interception, hidden-content banners on other screens, or notification projection/push/email delivery in this slice. Existing identifier-only moderation outbox events remain intentionally unconsumed by this new screen.

In the report, prepare a short founder decision table for the later slices: which concrete interactions may show counterparty warnings, eligible recipients and minimum disclosure, and notification channels/deep-link behavior, including suspension. State a recommendation and its tradeoff from current contracts, clearly marked **proposed**. Do not implement the recommendation or invent approval. Do not turn that table into a large policy document.

## 6. Verify real behavior and finish the draft

Add meaningful gateway/model/controller/widget tests for all four types, active and removed episodes, nullable content, long reasons, pagination/cursor precision, genuine empty versus failure, refresh, duplicate requests, identity switching and late responses, suspension gating, localization and Settings/back navigation.

Use a task-owned disposable backend and synthetic identities. Reuse existing authenticated moderation and suspension fixtures/verifiers. Verify real own-history results for affected users, an unrelated identity, Project Creator versus delegates, Resource owner and suspended identity; never replace authorization failures with successful empty data. Exercise enough history to validate a second page with tied apply times and unique IDs where practical. Extend existing helpers only where coverage is missing.

Run the required Mobile localization/format/analyze/test gates, Android compilation, and a real emulator/device plus local-backend smoke of apply → private history → revoke → refresh. Include an account switch and suspension routing check. Keep fixture reasons synthetic; screenshots/evidence must not contain real private data. State separately any physical-device, screen-reader or iOS checks not run.

Run required Database/auth checks if fixtures or verifiers change, preserving the inherited observed-lock/consequence/suspension gates. Verify final-head hosted CI and actual classification; state skips accurately. Do not claim a local verifier ran in CI unless that exact job includes it. Broaden checks only as required by changed/shared paths or repository policy.

Archive this exact prompt as `history-implementations/PLANETS_09C2B1_private_moderation_history.md`. Update the nearest feature documentation and roadmap: 09C2A implemented/in review, 09C2B1 private history implemented/in review, remaining 09C2B warnings/contextual UI/delivery deferred, 09C3/09D unchanged.

Write `docs/development/moderation-private-history-09c2b1-review.md` with the exact tested base/head, UI/copy, contract/privacy evidence, checks, unrun validation and the short later-decision table. Commit, push and open the draft stacked PR. Founder review covers this screen's presentation and wording, plus the inherited unmerged stack and explicitly unresolved historical risks; it does not authorize deployment or approve later warning policy.

Stop only task-owned services with the agreed backup retained, restore temporary configuration and verify checkout cleanliness. Finish with the PR URL, exact base/head, delivered behavior, evidence, remaining limits and the concrete next decision. Do not call all of 09C2B complete.
