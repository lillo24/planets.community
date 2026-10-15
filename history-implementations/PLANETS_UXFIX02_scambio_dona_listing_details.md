# PLANETS UXFIX02 — Scambio/Dona Listing Details UI Cleanup

**Plan ID:** `UXFIX02`  
**Status:** Implemented in the UXFIX02 change; see the Resource requests README and PR validation. A new app build/release is required for installed versions.

## Objective

Make the public **Listing details** page and its existing **View request** destination cleaner, without altering the Scambio/Dona request lifecycle or access rules. This is one focused Flutter UI change; implement as one PR.

## Current repository evidence (default `main` inspected 2026-10-14)

- `apps/mobile/lib/features/resource_listings/presentation/public_resource_listings_screen.dart` renders `PublicResourceListingDetailScreen`. It currently places the `ResourceListingModeBadge` near the top, but renders `resource-detail-interest-count` separately below the owner row. For an authenticated non-owner it renders `_ResourceRequestListingActions`, then Block and Report, then a bottom `resource-request-flow-helper` paragraph. This helper also currently appears for signed-out viewers.
- `_ResourceRequestListingActions` currently renders `ResourceRequestStatusChip` for the active request and, for `pending`, a separate `resource-request-inline-withdraw` button alongside `resource-request-view`.
- `resource-request-view` already navigates to the existing `/messages/requests/resource/:requestId` flow via `resourceRequestMessageRoute(active.id)`.
- `apps/mobile/lib/features/resource_requests/presentation/resource_request_screen.dart` implements that request details page. The requester already has a working `resource-request-withdraw` action there, using the canonical controller; the owner has Accept/Reject instead.
- `apps/mobile/lib/l10n/app_en.arb` and `app_it.arb` already define `resourceInterestCount`, `resourceRequestFlowHelper`, and the request action labels. `apps/mobile/test/features/resource_listings/presentation/resource_listing_flow_test.dart` includes expectations for the old placement and the inline withdrawal control; related request-detail tests exist in `apps/mobile/test/features/messages/presentation/messages_flow_test.dart`.

Re-inspect latest `main` and any more recent overlapping changes before modifying anything. Treat these files as verified areas to inspect, not a restriction against choosing a cleaner internal implementation.

## Required user-facing behavior

### A. Listing details: concise active-request controls

For a logged-in **requester with a pending request**:

- Do **not** show a `Pending` badge in **Listing details**.
- Show a **single `View request`** action there, not both `Withdraw request` and `View request`.
- `View request` opens the existing request detail and keeps its current navigation/return behavior. Do not introduce a new sheet or alternate withdrawal path.
- On that **View request** screen, `Withdraw request` remains accessible and operational for that pending requester, following the existing loading, authorization and error behavior.
- Keep meaningful existing states for other request phases intact. In particular, do not hide lifecycle information or acceptance/coordination controls from the request-detail page. The user asked to remove the redundant *Pending* badge on **Listing details**, not to remove status throughout the app.

For visitors without an active request, keep the existing request-creation and sign-in flows; for owners, keep existing management actions; for blocked interactions, retain existing restrictions and recovery controls. Reuse identity-bound canonical request state and navigation.

### B. Move explanatory copy under Withdraw request

- Remove the `resourceRequestFlowHelper` paragraph from the **bottom of Listing details** (currently below Block and Report), including the signed-out case.
- Render the **same localized explanation** — English: “After the owner accepts your request, you can chat and agree whether the item is given or lent and what is exchanged.” — **directly under `Withdraw request`** on the existing **View request** detail page, where the viewer is the requester and the request is pending.
- The helper should be visually associated with the withdrawal/request section, with subdued readable body-small styling and sensible spacing. Do not put it under the Block/Report actions.
- Do not display that pending-specific paragraph under owner Accept/Reject or on already accepted/terminal requests. Preserve both EN and IT localized content; avoid hard-coded text or unnecessary copy changes.

### C. Move interest count to the top beside Dona/Scambia

- In **Listing details**, show the existing **`resourceInterestCount(detail.summary.activeRequestCount)`** next to the `Dona`/`Scambia` mode badge near the top (above the listing title), ideally with its existing people icon.
- Remove the separate count row currently below the owner information; do not duplicate the number.
- Apply consistently to donation and exchange listings, and for signed-out, requester and owner views; display the same public count and singular/plural localization as before. Do not reinterpret or recalculate `activeRequestCount`, or introduce another query.
- Use a responsive `Wrap`/equivalent with appropriate spacing: normally adjacent on one line; when width or large text requires it, let the count wrap immediately below the badge rather than overflowing or truncating critical text.
- Keep good semantics/screen-reader labels without announcing the count twice.

## Constraints and non-goals

- UI-only Flutter task. No Supabase database/migrations/RPC changes, no new app permissions, no policy or request lifecycle changes, no new network calls, no redesign of owner/block/report workflows.
- Preserve authenticated requester-only withdrawal, accepted request conversation handling, repeat-request eligibility, identity-switch invalidation, canonical refresh after mutation, and the existing `/messages/requests/resource/:requestId` route.
- Keep consistency with shared theme spacing, buttons, accessibility and localization. Avoid broad refactors or changes to listing cards (the user requested **Listing details**).
- No external documents, screenshots, credentials or dashboards are needed; the repository suffices for this scoped task.

## Testing and acceptance

Update the existing Flutter widget tests, especially the old expectations in `resource_listing_flow_test.dart`, and add/extend request detail tests as appropriate to verify:

1. Pending requester: Listing details contains `View request` but neither an inline Withdraw button nor a visible `Pending` status chip; `View request` opens the correct request, contains an operational Withdraw action, and shows the helper **below** it.
2. The helper is absent from Listing details (including signed-out), absent for the owner and accepted/terminal request detail states, and localized appropriately in English and Italian.
3. Count appears in the top badge row and **not** again below owner; test `0`, `1`, and `2+` as applicable, both modes, plus narrow screen/large-text accessibility layout. Reuse existing public `activeRequestCount`.
4. Viewers without a request still see the correct Request/sign-in action; owner and blocked cases are unaffected; accepted-open and coordination-closed cases retain their existing behavior.
5. Withdrawal still updates canonical status via the existing controller, including refresh and error handling. Test navigation back to Listing details after withdrawal to ensure the active-request UI updates without stale buttons.

Run focused affected Flutter tests and `npm run check:mobile` if practical; report exact results, pre-existing failures, and any native QA not performed. Keep test fixture operations isolated; do not reset shared Supabase data or disturb the founder's physical phone/session.

## Deliverable and process

Work from latest `main` on a focused branch, implement the change, update relevant tests and short docs only if behavior documentation needs correction, open a PR, and report changed areas, commands/results, screenshots or screenshots-not-run, known limitations, and PR link. Do not claim a Google Play build is updated merely because the PR exists; do not deploy to production or merge without the normal checks and user workflow.
