# D-R01 — Reconcile and finish the existing representative-contact implementation

## Objective and scope

Bring the already-written D01/D02 contact requests and bilateral conversations onto current main and the resolved D-R00 contract. Reuse code, receipts, tests and evidence; do not create another group-contact subsystem. This stage does not depend on C's new General/Idea domain.

## Functional behavior

A current authorized representative deliberately selects the Group they speak for and the eligible destination/purpose. Both personal identity and selected Group are shown clearly. Group provenance on an old public Project is not proof that its creator still represents that Group. Server authorization—not a frontend role badge—decides at submit, triage, accept and send.

Deliver the pending request to exactly the D-R00-approved audience. If the reviewed candidate is an eligible-manager inbox, disclose that audience to the sender before Send, keep resolved metadata narrow, and ensure only the explicitly accepting human gains the bilateral admission. If a later actual decision selects named recipients, implement that rather than leaving a hidden broad manager inbox. No Group-wide chat membership or automatic admission of replacement managers.

Explicit Send/Accept/Decline/Withdraw/Close/Leave have distinct outcomes and frozen recovery identities. Opening a public Group/Project/profile or completing OTP never sends/accepts. Received notes are requests, not fake human chat messages. Preserve purpose, sender, represented Group and safe destination context without publishing private rosters, affiliations or exact meeting details.

Only approved current admissions may read/signal/acknowledge/send, and the chosen history contract must be consistent across body, exact-message, list preview, latest timestamp, roster, unread, report context and stale cached state. Test role grant changes/revocation/regrant, account erasure, Group availability and blocking after lock waits. Do not silently keep the old permanent-history-loss choice if the founder approves retained history—or silently change it based on C.

## Preserve privacy, retries and safety

Keep sender/actor/Group IDs and request intent frozen through unknown replies. Distinguish an original receipt from current access. No duplicate request/conversation/admission on exact replay; altered input cannot reuse an accepted key. A “no result” must not disguise a failed command or a revoked route.

Use the installed canonical blocking locks/helpers and fail-closed authorization. The policy for a block involving another target manager must follow the resolved recipient model, not an arbitrary list fetched by the client. No private block direction disclosure. Reporting/withdraw/leave retain their safe scope and cannot be rate-limited into inaccessibility. Genuine report evidence is exact and case-bound; staff role alone never opens the conversation.

Retain existing Project/Resource/request conversation IDs, history and consent. Do not route all member chat through representative APIs or broaden a current-manager predicate into a universal personal-contact grant.

## Technical work

Inspect actual D migrations and affected main code; resolve current conflicts before extending the lane. Preserve legacy Requests/Chats/unread and old parser behavior. Reallocate API versions only after inspecting both lanes. Keep fixes additive where history may already be applied; follow the shared migration/replay discipline.

Reuse D's local native harness but repair its demonstrated driver/scroll/lifecycle failures with tests, not longer unexplained waits or relaxed assertions. Identify what was injected (fixture Auth, response loss, mocked launcher) versus genuine real-backend UI interaction.

## Acceptance

Real synthetic accounts from separate Groups; every manager role; ordinary member denial of representation; multiple possible represented Groups; self/duplicate targeting; two target acceptors racing; source/target role changes; block/consent/retry/closed state; approved old-history/replacement behavior; no public/private data cross-leak; several list/history pages; exact reported-message evidence. Complete the final native contact journey or clearly leave that qualification outstanding for D-R04.

Code for unresolved recipient/history choices stays review-only. Once decisions and tests are resolved, include it in the final D cumulative result; do not independently merge obsolete D01/D02 stages.
