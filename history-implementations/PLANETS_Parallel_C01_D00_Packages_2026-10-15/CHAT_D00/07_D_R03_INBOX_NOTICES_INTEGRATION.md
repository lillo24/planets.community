# D-R03 — Requests, private/contact chats, notices and current-main integration

## Objective

Make all approved D/M features coexist with existing Project/Resource conversations and C **when C is on main**. This stage is owned by the D00 chat; no third coordinator exists. C can merge first or later.

## Required behavior

1. Compose the actual current Requests/Chats/unread interfaces. The prior draft introduced Requests v3/Chats v6/unread v2 while old C used a separate discussion summary; those numbers are historical, not available-slot instructions. Inspect current effective signatures and version only where required. Legacy clients must not receive unsupported new kinds.
2. Preserve distinct types for Idea invitation, member-contact request, representative request, coordination consent and Project/Resource request. Filter/union before paging; stable keys include domain, not UUID alone. No disappearing requests after the first page, duplicated human unread, or forced Project request used for member consent.
3. Preserve all canonical human-message counts and existing read semantics. Activity notices and membership/invitation state are not fake chat messages. Use independently authorized ACK frontiers; a request modal or collapsed Group folder does not read a conversation. Source/Project continuity from C cannot double-count history or hide D unread.
4. Deliver explicit member/representative contact and coordination invitations in Requests plus the approved in-app notice flow. Keep ordinary chat notifications separated from the activity inbox, preserve per-conversation mute and hidden-state semantics, and do not claim external OS push is live without actual configured delivery. Notification previews/taps reauthorize; no notes, private participants or invite tokens in broad payloads.
5. Combine all account activity and access-invalidation hints. Never replace the peer's listener with yours. Clear appropriate private state on identity switch, leave, role loss and forbidden reads, including A→B→A and offline cached routes. Keep each domain's lifetime rules independent.
6. Preserve exact typed report targets, staff evidence dispatchers and own report history. Existing C reports must survive D constraint changes and vice versa, including in populated upgrades. A shared report UI grants no cross-conversation browsing rights.
7. When C is present, compose the current Group People/compact sheet with both **Invite to Idea** (C) and **Request conversation** (M), exposing each only when authorized. Preserve C folders, General pin, hide/mute and conversion. D private personal chats never become room content visible to Group managers. When C is absent, keep D/M functional using current Group People and document the optional action seam for the later C merger.
8. Reconcile localization, router setup/cancel paths, generated schema types, scripts and CI by semantics, not whole-file ours/theirs. Read incoming UI-polish changes and keep their behavior. No universal contact/search directory or unrelated navigation redesign.

## Migration and final-main hazards

Exercise the actual sorted sequence of both lanes' migrations and inspect final definitions, grants and constraints. Old C and D timestamps interleave. Test populated peer records before applying your cumulative branch: report constraints, group roles, Block helpers, unread wrappers and statement dependencies must remain valid at **each** step, not just after a final repair migration. Never modify an applied main migration as a shortcut.

Use a forward, version-compatible reconciliation strategy from the real code. A conflict-free Git merge or green isolated D suite is insufficient if the combined schema erases C kinds. Generate types from the resulting database. Record which peer/main SHA was incorporated; absence of C is explicit, not a fake empty C runtime response.

## Tests

Mixed corpus with more than one page per conversation/request kind, two Groups, member and representative accounts, multiple origins, hidden/muted Idea, pending Project invitation, closed/left chats and distinct reports. Check totals/ordering/paging, no protected context leak, current and old client contracts, account switch, consent, Group/Project independence and cross-lane role-loss rules. Run real combined upgrade/Auth/native checks where both lanes are present; otherwise finish D-only qualification and publish exact C integration requirements.
