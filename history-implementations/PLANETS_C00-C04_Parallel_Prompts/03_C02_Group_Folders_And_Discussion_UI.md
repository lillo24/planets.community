# C02 — Lightweight Group folders and private discussion chat UI

Read C coordinator, C00 contract and C01 domain. Start from the verified C01 head, using provisional review-only status if C00 access approval is still missing.

## Objective

A user with current access to one or more registered Group discussions can find them naturally under compact Group headings in the existing Messages screen. They can open a private room, read bounded history, send text, and reach the same Discussions section from that Group's own page. No full Slack-style channel interface, recursive folders, global user picker or arbitrary private chats.

Suggested conceptual structure:

Messages → Groups → “Trento Green” (expand/collapse) → “General planning”, “Parco”; other existing Project conversations remain independently accessible in their current navigation.
“General planning” is only a sample title, **not** an instruction to automatically create an all-member room.

## Implementation scope

Inspect current Messages navigation, independent Private/Groups paginated feeds, Project chat controller, unread and read-viewport contract, route restoration through Auth/profile, Group public/detail/current participation feature and current D PR. Use domain-owned Group-discussion controllers/gateways and minimally scoped routes.

- Display current entitled Groups as a one-level collapsible folder/list, bounded and paginated. Each heading is the registered Group's current contextual display name; do not load a public manager/member directory to show it.
- Display rooms visible **to this person** only, paginated within the selected Group. A person without accepted room admission must not receive sensitive room titles/previews unless C00 explicitly authorizes an invitation-status projection.
- Authorized Group managers can open a deliberate Create discussion screen, name it and invite allowed Group members from the **existing private current People projection**. Invitation acceptance is explicit. Ordinary members get the approved join/invite and Leave actions, not a global Create button.
- Chat detail follows C01's canonical history frontier; preserve stable newest/older pagination and scroll position, text composer/error draft, one-send receipt recovery, unread foreground acknowledgement, safe localized identity labels, reconnection refresh and canonical denial states.
- Show unread counts on group/room headings from server-issued currently entitled unread state. Do not derive totals from the subset of loaded rows or auto-acknowledge while the room is collapsed/backgrounded.
- Provide equivalent reachability on the Group detail page without exposing private sections to guests/pending/former members.
- Preserve Project/Tavolo/Resource chat, Requests, group invitation and navigation/deep-link behavior; do not move a Project group chat into a registered Group folder simply because its Project is attributed to that Group. The participation audiences are different.
- Empty and read-error states are distinct. Retry an actual failed request rather than pretending there are no rooms. Long names, large text, 320px screens and EN/IT need clear disclosure/overflow, keyboard/semantics and robust Back navigation.

## Interaction and performance rules

No all-groups + all-rooms + all-history preload on entering Messages. No per-row unbounded photo/profile fetch. Folder expansion triggers scoped lazy reads, and deliberate Load more works for Groups/rooms/older messages. A newly arriving message updates the canonical row through safe invalidation/refresh without resetting unrelated groups' scroll positions or accidentally acknowledging it.

Keep current real-person sender labels scoped to room authorization, not generic profile visibility. Deleted/erased identities use neutral placeholders. After room invitation revocation/group leave/account switch, close protected composer and clear cached private titles/previews/history. C01's live backend denial is authoritative over stale Flutter state.

## Parallel D constraints

Batch D simultaneously adds representative conversations to Messages. Do not independently replace its request/inbox/unread projection without inspecting the merged/current typed contract. Prefer an independent C-owned Group-discussion folder list alongside existing sections, then a narrow read-only umbrella integration; never mix first capped pages from distinct APIs and sort them locally as if globally complete.

Refactor common view widgets only where current code clearly supports both semantics. Do not bind D's representative conversations to Group-room membership or automatically display them under a registered Group folder. Keep separate notification categories/report routes.

## Validation

Focused Flutter models/parsers, identity/role transitions, pending invitation, current admit/leave, navigation/back/guest/profile OTP, lazy pagination with stable cursors, room send/older load/unread/refresh, concurrent late responses, EN/IT/light/dark/narrow/large type and actual emulator frames. Include a genuine synthetic Auth + local-backend journey after C01 server validation.

Use C01's unchanged authority matrix as the acceptance oracle; UI hiding is not server security. Push a C02 draft PR and continue to C03; no independent main merge.
