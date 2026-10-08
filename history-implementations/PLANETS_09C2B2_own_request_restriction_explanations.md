# PLANETS 09C2B2 — own request restriction explanations

Implement the next bounded moderation UX slice in `lillo24/planets.community`: after a canonical denial of a new Project join request or Scambio/Dona Resource request, an affected user can see a factual explanation of their own verified active interaction restriction and open their private PLANETS notices. Produce a working draft PR with EN/IT wording for founder review.

This is private affected-user UX. Counterparty warnings, notification delivery and the rest of 09C2B remain separate. Read `AGENTS.md`, feature READMEs and accepted architecture before editing. Complete implementation and validation without pausing for routine choices within this scope.

## Exact base and inherited evidence

- Required base: [draft PR #144](https://github.com/lillo24/planets.community/pull/144), published head `291257dda7783347d8867f3fc6c6287a281e8fcd`.
- Create `codex/09c2b2-own-request-explanations` from that exact head. Open a **draft stacked PR** targeting `codex/authqa01-otp-bootstrap-status`, not `main`.
- Verify ancestry through #142 → #139 → #136 → #133 → #130 → #126 → #125 → #123. Inspect remote movement; do not silently substitute another base or import unrelated changes.

Read `docs/development/authqa01-otp-bootstrap-and-home-status.md` and [#144's final evidence](https://github.com/lillo24/planets.community/pull/144#issuecomment-5998410083). Its tested source is `51bef936ce70ecf5085baea46debc5daf097efc0`; hosted run `37335681872` passed Mobile with Database/Web/Site skipped. The published head adds only documentation/screenshots. The real normal-Android OTP/Home/profile/history/suspension smoke passed. Preserve the OTP bootstrap fix and its regressions.

Read `docs/development/moderation-private-history-09c2b1-review.md` for existing private notices, session guards and pending founder wording review. Historical Realtime/DB incidents remain unexplained; do not start another investigation unless this change produces relevant evidence. Physical-device, iOS and native accessibility evidence must remain accurately labelled.

Keep the entire stack draft, unmerged and undeployed. Do not choose hosting, provision resources, change billing/DNS, upgrade dependencies, implement appeals, or alter canonical moderation/enforcement semantics.

## 1. Diagnose only the user's own current restriction

Inspect final replayed SQL, generated contracts and these entry points:

- `private.profile_has_active_interaction_restriction` and `private.assert_profile_new_interactions_available`;
- Project request submission in `participation_controllers.dart` / `join_request_screen.dart`;
- Resource submission in `resource_request_controllers.dart` / `resource_request_composer.dart`;
- `list_own_moderation_consequences` and the existing own-consequence gateway/controller.

The canonical restriction denial is generic `PT409`, also used for unavailable interactions involving other causes. **A generic denial does not prove the requester is restricted.** Do not classify moderation from error-message text, reveal a target's hidden status or block relationship, or change generic server errors to disclose those facts.

After the relevant canonical submit denial, perform one bounded, fresh, identity-bound check of the acting user's own current interaction-restriction status. The check supplies explanation only; the canonical mutation remains the authorization boundary. If the status is inactive, unknown, malformed or unavailable, keep the safe generic failure. If independently confirmed active, explain that own restriction without claiming it was the only cause of the failed operation. Handle suspension through the existing Auth flow before showing ordinary account UI.

Do not infer absence from the first history page: an active restriction can be older than newer removed episodes. Inspect existing APIs for a complete current-state answer. If none provides it, add one minimal read-only own-status RPC in a forward migration, using the canonical predicate and existing expected-identity/profile-anchor/account-access guards. A suggested name is `get_own_interaction_restriction_status(p_expected_profile_id)`; return only the minimal current own-state projection, preferably a boolean. No arbitrary-profile lookup, target metadata, case IDs, staff identity, reasons or private notes are needed.

Do not grant API roles access to private helpers/tables, use service-role credentials in Mobile, or add a suspension exception. General own history and this ordinary status read remain denied while suspended. Update generated contracts, the authenticated-RPC inventory and suspension audit coverage precisely if adding an RPC; unknown RPCs must still fail the audit. Do not use a broad allowlist exemption.

## 2. Integrate with both request forms

Apply the explanation only to new outbound Project join and Resource request submissions. Preserve existing validation, photo trust gates, selected participation options, command ordering and canonical success navigation. Do not modify acceptance, withdrawal, leaving, manager actions, existing chat/agreements or public content visibility.

For Resource requests, preserve canonical-active-request refresh and conflict recovery. An explanatory lookup must not hide an existing request, convert failure to success, duplicate a mutation or replace a more specific valid error such as invalid input/photo required.

Show a concise own-restriction explanation and a localized **View PLANETS notices** action using the existing guarded private-history route. Keep the canonical failure understandable while the optional check is loading or fails. Avoid global button disabling, broad action interception or new background polling.

Opening notices and returning must preserve a same-session request draft: Project message/options and Resource composer message, including its modal presentation. Do not silently discard text or resubmit. After revocation, a user-initiated retry must call the canonical mutation again; removal does not restore previously withdrawn requests. Reconcile explanation state on each relevant attempt and never present cached active status as freshly confirmed.

Bind asynchronous status and displayed explanation to verified account access, session revision and operation revision. Clear them on sign-out, account switch, suspension, disposal and a new attempt; reject late results, including A → signed out → A. Do not carry private drafts or explanation state into another account. On `PT403`, use the existing Auth refresh/router path; do not reinterpret suspension as interaction restriction or create a parallel suspension screen.

## 3. Draft factual, accessible EN/IT wording

Use the existing localization and component conventions. Suggested meaning: “A restriction on new requests is active on your account. View PLANETS notices for details.” Adapt wording to each form without promising that revocation guarantees eligibility.

These are working drafts, not founder policy approval. Do not add guilt findings, strike counts, public badges, expiry promises, appeal/support routes or deadlines. Existing staff-written reasons remain verbatim plain text in private notices; do not copy them into composer errors, logs, analytics, crash breadcrumbs or notification payloads.

Support narrow layouts, large text, long Italian labels, focus/back navigation and semantic error announcements without relying on color. Keep the notices action reachable without losing entered text. Record exact new EN/IT strings and representative screenshots in the review report. Existing #142 copy/presentation approval remains pending.

## 4. Verify contracts, privacy and real flows

Add meaningful tests for own active/inactive state, revoked/reapplied episodes, an active episode older than a full history page, unrelated identity, expected-ID mismatch, anonymous access, missing profile anchor and suspended access. Test malformed/failed transport, fresh checks, account switching, suspension during lookup, disposal and late same-ID session results. Prove the projection cannot expose another profile or staff/case data.

Test both forms' restriction explanation and notices/back navigation with preserved drafts. Cover generic denials caused by blocking or hidden/unavailable targets, no own restriction, coexistence with an own restriction, ordinary validation/photo gates, Resource conflict recovery and retry after removal. Preserve #144's bootstrap regressions. Use deterministic fake-controlled ordering for asynchronous races.

Use a task-owned disposable backend and synthetic identities. Recreate isolated configuration from the restored checkout; do not reuse a stale startup command or alter shared services. Follow repository scripts and pinned toolchains. Reuse the proven OTP/PKCE smoke approach rather than bypassing normal login or changing Auth to simplify fixtures.

Run real authenticated API checks and real Android smoke for both request forms: normal OTP login → unrestricted baseline → staff applies own restriction → submit denied with verified private explanation → notices → back with draft intact → staff revokes → explicit retry governed by canonical rules. Verify unrelated-user isolation, a generic target/block denial and suspension routing. Use synthetic screenshot content only.

Run required Mobile localization/format/analyze/test gates and Android compilation. If adding SQL/contracts/verifier changes, run required Database checks, real-auth consequence/suspension checks and the RPC audit; preserve inherited concurrency gates. Broaden Web/Site checks only where changed/shared paths or repository policy require them. Report actual native accessibility/iOS/physical-device checks separately; never substitute widget tests for them.

Verify hosted CI on the final tested source, including classification and actual skips. If publication subsequently changes only documentation/screenshots, prove source equivalence and distinguish published head from tested source; do not claim an unrun final-head job. Investigate new failures with evidence rather than speculative SQL changes or waived checks.

## 5. Publish a reviewable draft

Archive this exact prompt as `history-implementations/PLANETS_09C2B2_own_request_restriction_explanations.md`. Update relevant feature documentation and roadmap to mark this bounded slice implemented/in review, preserving pending founder review and later 09C2B/09C3/09D work.

Write `docs/development/moderation-own-request-explanations-09c2b2-review.md` with exact base/published head/tested source, RPC decision and safe contract, both UI flows, EN/IT strings, privacy/session evidence, local and hosted results, screenshots, unrun checks and remaining review items.

Do not implement counterparty safety warnings, general safety-status APIs, hidden-content banners elsewhere, moderation notification projection/push/email delivery or appeals. Leave identifier-only moderation outbox events unchanged. Do not call all of 09C2B complete.

Commit, push and open the draft stacked PR. Stop only task-owned services with backup retained, restore temporary configuration and confirm clean checkouts. Finish with the PR URL, exact base/head, delivered behavior, validation evidence and remaining founder copy/presentation decisions. Nothing is merged or deployed.

