# PLANETS A1 — One private conversation per pair of people

**Codex implementation handoff — 24 October 2026**

## Outcome and approved product direction

**Implement A1 end-to-end**, not another screenshot review or a cosmetic label workaround. In **Messaggi → Privato**, the same two individuals must have **one visible personal conversation**, regardless of whether they connected via a Project/Tavolo participation request, Scambio-Dona, a personal contact through a registered Group, or an accepted Find People post. They should see **one combined, chronological, authorized human-message history**, with relevant contextual events and actions. Separate origins should not create a separate visible private chat for the same pair.

This direction comes from the founder's follow-up to UIAUDIT01: the screenshot showed two conversations with the same person; the audit confirmed they were real, different domains, not erroneous duplicate records. The founder rejected simply labeling the two rows and chose **a unified conversation per person instead**. This decision supersedes the earlier **cross-domain separation** for *personal two-person conversations*; it does not relax domain access rules.

**Do not deduplicate by display name, hide one row without its messages, silently merge database records, or restrict the change to a Resource/Project label.** A person can share the same visible name with another person; use canonical immutable profile identity.

### Concrete acceptance example

Suppose Alice and Marco have (1) a participation request for Alice's Project, (2) another participation request/Tavolo with reversed roles, (3) an accepted Scambio-Dona coordination, (4) a bilateral personal conversation begun through their Group, and (5) an accepted Find People post. In **Privato**, Alice must see **one row for Marco**, not five. Opening it shows their legitimately accessible conversations in one chronological history. A request or agreement action still opens its proper context. Both Alice and Marco see the same human messages they are independently entitled to see, subject to current domain authorizations. Other people with Marco's display name remain distinct rows.

The interface should feel like a single personal conversation, **not** a nested list of five sub-chats or a redesigned Requests inbox. Small contextual event labels/actions may distinguish a project request or Scambio-Dona agreement; ordinary human bubbles should not need noisy source labels unless essential to understand the sequence.

## Source inspection performed for this handoff

Current code was inspected on `lillo24/planets.community`, including `main` as of **3bffe5868aea8549f4e345aece2020a6e72997c3** (24 October 2026). Re-fetch current `main` when implementing: do **not** reset to this historical SHA.

Relevant established behavior:

- `docs/architecture/decisions/0007-participation-pair-conversations.md` (MSG01) already groups **Project/Tavolo requests** by ordered profile UUID pair. It explicitly leaves Resource chats independent. This historical exclusion is the exact A1 gap, not a data-duplication bug.
- `docs/architecture/decisions/0008-message-unread-and-activity-alerts.md` establishes human-only unread receipts, source-specific identities, rendered-newest acknowledgment, and old-client compatibility.
- `apps/mobile/lib/features/messages/data/message_chats_gateway.dart` currently reads `list_own_scoped_conversation_items_v7`. `message_chat_models.dart` still distinguishes `resource_chat`, `project_request_chat`, `member_contact_chat`, and other kinds; `messages_screen.dart` presents per-domain cards.
- Find People has an **additional** `PeopleContactItems` section (not included in the above v7 item parser), currently rendered separately in Private. See `apps/mobile/lib/features/co_creation/presentation/people_message_items.dart`, `people_private_gateway.dart`, and `docs/development/cocreate-posts-contacts.md`.
- Resource chat belongs to a particular accepted Scambio-Dona request/agreement and is writable only during that authorized coordination; see `features/resource_chat/`.
- Personal member-contact chat belongs to an explicitly accepted consent episode via a shared registered Group, with its own leave/rejoin/block rules; see `features/member_contact/`.
- The `group_contact/` representative-to-representative and `group_coordination/` multi-party features belong to the **Groups** scope and carry organizational authority, not ordinary personal chat consent. Preserve that boundary; do not relabel an organization representative chat as personal merely because exactly two humans happen to participate.
- Central requests, moderation evidence, blocking, notification delivery, exact source feeds, and original chat deep links already exist. Avoid replacing their logic with copies.
- The separately merged `UIAUDIT02` prompt covers **19 unrelated delegated corrections** and explicitly excludes A1 and DE1. Do not redo that batch, change DE1, or borrow unmerged work from another runner.

Read current `AGENTS.md`, applicable nested instructions, `docs/development/codex-tooling.md`, `docs/architecture/core-stack.md`, the above ADRs, and the closest backend/mobile domain docs before modifying code. The broader `Planets Community Design` document contains historical context-scoped chat intentions; current founder instruction takes precedence for A1's person-level presentation. **Codex does not require access to that external Google Doc, the real-account screenshot, the 457-page audit PDF, or a Google Drive session.** All essential decisions are in this prompt and the repository. If an external credential is required for an optional hosted test, do not stop local work.

## Scope and important limits

**Include:** all *authorized personal two-human* conversation sources already listed in Private:

1. The existing canonical Project/Tavolo participation **pair**, including legacy messages and repeated/reversed request episodes.
2. Accepted Scambio-Dona Resource chats, including historical completed/cancelled coordination where currently readable.
3. Accepted one-on-one member-contact conversations through registered Groups, with their episode and historical access boundaries.
4. Accepted bilateral **Find People post contacts**, including multiple posts with the same two people, only under the co-creation feature's real server/actor authorization. Do not fabricate content when the server experiment is disabled or permission/policy is absent.
5. Additional **personal two-human** source kinds that have reached current `main` by implementation time, if they satisfy the same explicit-consent and audience rules.

**Exclude:** Project/Tavolo group chats, General/numbered community rooms, registered-Group discussions/Ideas, representative group-to-group conversations, multi-party coordination, pending requests that have not established a readable personal conversation under existing rules, and any generic direct-message capability without prior legitimate context. Do not create a new public profile-to-DM action. Preserve the `Privato / Gruppi` division and the existing separate structured **Richieste** inbox.

**A unified view is not universal consent.** Existing gates remain authoritative on every read, send, acknowledgement, link/open, block, mute, report, reconnect, and access change. An accepted Scambio-Dona relationship must not grant access to a Group member-contact history that is no longer readable; an old Project request must not let someone write on a closed Resource agreement. A new encounter with the same person must not resurrect ended episodes, provide retrospective source transcripts beyond current rights, bypass a block, or turn a closed/withdrawn request into active permission. Preserve source retention/erasure/report provenance.

### Sending from a unified composer

There should be **one message composer in the unified conversation**, not one visually separate chat per origin:

- If exactly **one** underlying source grants send entitlement, use it transparently.
- If **several** currently grant send entitlement, choose the relevant current source when entering from its deep link; otherwise provide a small, understandable **“Regarding …”** source choice near the composer (or an equally safe existing pattern). Remember that selection only while authorized and for the current account; never silently send under a different project's or resource's authority after a race. Do not expose a source the actor cannot use.
- If **none** grants send entitlement, keep whatever history is still authorized readable and make the composer clearly unavailable. The label must reflect the relevant restrictions rather than claiming that any past contact entitles indefinite messaging.
- Server must revalidate the **exact selected source and actor** at commit time, including races, closure/withdrawal, moderation, blocks and policy. Preserve source-specific immutable intent, idempotency, original message IDs, retries and unsent drafts. Do not invent a new broad `send_to_person` RPC with fewer security checks.

A user-facing context selector is an authorization affordance, **not** a second inbox or second conversation. Keep contextual management actions (Request Accept/Reject/Withdraw/triage, agreement terms and completion, member-contact close/mute, Find People consent/close) under their original authorized domain owners. Do not manufacture source actions within the unified feed from guessed status.

## Technical implementation approach (choose the smallest correct variant)

### Phase A — Canonical server projection and safety contract

1. Inventory all current personal conversation **source/actor pairs**, status readers, write conditions, existing UI routes, Realtime hints, unread counts/read ACKs, notification lookups, and moderation report IDs. Note any source that can involve two different people under a changed owner/delegate role: use **actual immutable endpoint UUIDs** instead of a changing display title or current manager label.
2. Define a canonical **unordered person-pair identity** based on the two authenticated profile UUIDs, stable across different origins and across account sessions, while never creating a personal conversation from mere public profile discovery. Reuse existing pair conventions where appropriate, but avoid expanding the MSG01 participation anchor's send entitlements. If a new stable pair anchor/index is necessary, create it additively and establish it only from eligible existing source relationships; if authorization-safe derivation is simpler, use that.
3. Add **versioned** server RPC(s) for (a) one canonical **Private** row per authorized other profile **before pagination**, (b) an authorized **mixed chronological feed** for that pair, (c) the currently available source contexts/management metadata required by the UI, and (d) updated own-account unread summaries/acknowledgment composition if needed. Use typed source references and exact bounded source projections. Do not build the aggregate from individually paginated UI lists, otherwise old duplicates reappear across pages and unread totals drift.
4. For an event/message feed, preserve original source identity `(kind, original_id)` and timestamp. Use deterministic tie ordering and proper keyset pagination across mixed sources. A retained legacy message appearing through multiple associations must appear **once**, but distinct legitimate messages—even with identical bodies or timestamps—must remain distinct. Include only context/status information that the current actor is entitled to view.
5. Source reads must be reauthorized individually on each query; no global `pair membership = read everything` rule. Reuse narrower secure source functions where safe. Every `SECURITY DEFINER` helper, grant, RLS entry and `realtime.messages` policy needs deliberate review for cross-source access. No client-side hiding of restricted rows after an overbroad server response.
6. Combine **unread** by human sender and person pair: two unread Resource messages and one unread participation message from the same person must display **one unread Private conversation** in the global conversation-count badge, while the row can show **three unread human messages** if all are authorized. Groups counts remain separate. Source-specific outgoing/incoming ordinals and old installed-client semantics remain unchanged; older clients keep their existing versioned functions and counts.
7. Read ACK must occur only for source messages actually **rendered in the foreground, unobscured, at an eligible latest boundary**. Acknowledging the bottom of a unified feed must not automatically mark offscreen/unloaded messages in every source as read. Preserve no-auto-ACK behavior in lists, previews, hidden branches, sheets, and older paging; retain exact tokens for failed retry.
8. Realtime should invalidate a user's own pair/list/summary without broadcasting bodies, other actors' identities, request notes, hidden contexts or forbidden group audiences. Handle access revocation immediately and scrub stale cached content on account/realm change, block, or gate-off. Full authoritative refresh must reconcile missed messages without duplicate rows.
9. Keep existing source tables, UUIDs, historical chronology, moderation evidence, audit links, report identifiers, and accepted external/stable deep links. Do **not** migrate/copy/rewrite/delete source messages into a new global transcript as a shortcut. Add migrations rather than editing applied history. Generated database types and client parsers must reflect only new versioned contracts.
10. Compare older installed readers/writers and staged/hosted migration state using repository release runbooks. A new client should not be considered deployable against an older backend lacking its required RPCs. Do not expose an experimental fallback that guesses pair data from untrusted projections.

Codex may select an appropriately scoped read-only **aggregation view** over existing domain transcripts, plus a new pair-list contract, instead of introducing a new message table. Prefer avoiding duplicate durable message storage. If source identity/entitlement complexity makes a safe design impossible without changing consent/retention rules, **stop the affected architectural change and explain the exact unsatisfied boundary**, rather than weakening permissions or silently changing the product goal. Continue independent safe work and tests.

### Phase B — Mobile conversation, navigation, and lifecycle

1. Introduce one Private person-row and one Private person-detail screen or reuse an existing shared message-history component if it supports the complete mixed feed. The row must show canonical counterparty name/photo (only if current profile-photo rules permit), latest **authorized** activity, aggregated unread, and read-only state only when no eligible send context remains. Do not use names for identity or stable keys.
2. Entering a row opens the same person-level timeline regardless of whether the relationship began in Projects, Resources, member contacts, or Find People. Old list sub-sections such as the appended `PeopleContactItems` must not produce a second row outside the canonical server paging. Empty/loading/partial/failure states must reflect the complete Private feed (avoid the recently audited contradictory empty-copy issue).
3. Preserve compact, human-readable **context cards** for request status/triage, agreement negotiations, post interest, and Group-member consent, where currently authorized. Put detailed workflows behind existing pages/sheets rather than repeating all their controls in a conversation. Avoid cluttering every human bubble with source tags; include targeted provenance when needed for moderation, historical interpretation or safe action.
4. Every existing entry point should resolve through the correct source authorization to the canonical pair thread **with appropriate source focus**, including old Resource/Project/member/post direct links, notification taps and post-auth continuations. A link whose original source is inaccessible must not be silently treated as permission to reveal or act on a different source—even if another chat with that person remains valid. Keep old routes valid for installed clients and internal links or provide security-equivalent compatibility redirects.
5. Implement source selection for the single composer as above; never auto-switch a pending immutable send attempt across contexts. Account switch, realm change and blocked/lost access must discard stale private feed state; don't clear valid user-entered draft on an ordinary recoverable network error.
6. Preserve existing Requests, notification read/activity categories, separate Groups, organization-representative and multi-person messages, moderation/report navigation, and current user-block UX. No generic new DM feature.
7. EN/IT localization, semantic labels, screen-reader/large-text layouts, keyboard/safe areas, pagination, notification badge, scroll restoration and performant list rendering are required. When one person has many Resource requests/posts, their personal thread must remain usable without downloading the entire history on launch.

### UX acceptance examples

- Alice and Marco have two Project requests, one open Resource agreement and two accepted Find People posts. One Private row; the detail has **one** chronological interleaving of legitimately visible messages, with contextual affordances, not five separate sub-chat tabs.
- Alice sends a normal message where only the Resource coordination is writable. It sends with Resource rights. The Resource coordination closes and Project request remains pending: the next authorized send uses the Project context after a fresh entitlement read, not an implicit reactivation of Resource. When both are writable and no deep-link source was selected, the composer makes context unambiguous before send.
- Alice leaves the Group that once authorized a member contact. The remaining person-level conversation does not keep unauthorized Group messages or reopen that episode just because a Project relationship still exists.
- Find People server gate is OFF: no previously gated contact bodies, counts, or source metadata leak through the general Private row. Exact own-exit endpoints still work under their original rules.
- A person blocks the other while an already-accepted Resource coordination remains permitted under the current domain exception: the unified UI follows **that** existing exception without turning it into generic unblocked messaging for other domains.
- A notification or old direct link for a deleted/unauthorized Resource chat fails safely in its original context, even if the user can open another legitimate pair conversation.

## Tests, checks, and deployment boundary

Use **one cohesive end-to-end implementation prompt/PR**, with separately reviewable **backend/projection/security** and **mobile/UI** commits and targeted checkpoints. The backend may be migrated ahead of the client only if it is additive, old-client compatible and cannot expose the new unified behavior prematurely. Do not mark A1 complete after building only an RPC, hiding rows, or producing design documents. If the repository's protected migration workflow requires a separate PR, keep an explicit dependent completion path and finish as much as can be safely integrated; never bypass its review gate.

Required evidence on a disposable, owned local backend (not staging/production/shared Mock):

- **Identity and dedupe:** one row per profile-pair across multiple same/different personal source kinds; reversed participants; same display name on distinct accounts; same source reachable via multiple legacy associations; stable sorting across keyset boundaries, refresh and signals.
- **Consent/RLS negative matrix:** unrelated user, manager/delegate, former Group member, blocked actor, closed/withdrawn/expired source, disabled Find People gate, suspended/deleted account, stale/invalid policy, cross-realm switch; no source disclosure from pair aggregation, pagination, direct links or notifications.
- **History:** ordered mixed message/event feed under latest cursor, identical timestamps, old source messages retained without rewriting, report-by-source-ID, and no transcript exposure beyond existing per-source boundaries.
- **Send/concurrency:** single writable context, multiple writable contexts with explicit selection, no eligible context, racing closure/block/role change, ambiguous network reply, exact command replay/idempotence and preserved draft.
- **Unread/ACK/Realtime:** one pair badge across several domains, correct per-row message total and Groups separation, acknowledgement of only rendered eligible source boundaries, non-read from preview/older/covered views, actor switch and lost socket recovery, no duplicate alerts from grouping.
- **Compatibility:** existing RPCs/old signed clients, current generated types, deep links, Requests and Group chats, moderation audit, member-contact exit/rejoin and Resource agreement progression.
- **Real native visual check:** Android emulator (Pixel 9 Pro or accurately reported equivalent), Italian dark theme, English/light selected variants, narrow/large text and keyboard-open states. Use task-owned fictional personas with two different authorized contexts and confirm the *one-row one-thread* result visually. Exercise both sides of an interaction, preserving privacy in artifacts.

Inspect the established local verifiers/tests before writing new ones, particularly:
`supabase/tests/112_participation_conversations.test.sql`, `119_message_list_activity_preview.test.sql`, `140_member_contact.test.sql`, `144_contact_mixed_pagination.test.sql`, relevant Resource and `150/151_cocreate` tests, `scripts/verify-local-participation-conversations.mjs`, `scripts/verify-local-member-contact.mjs`, `scripts/verify-local-cocreate-posts.mjs`, `apps/mobile/test/features/messages/`, and `scripts/ui-audit/` for the owned Pixel capture method. Follow `npm run check:db`/mobile checks and the repository's **required CI + populated-upgrade/migration review gates** to the extent warranted by actual changes.

**Not authorized:** hosted/staging/production database writes outside existing approved automation, destructive data repair, changing security gates/review policy, Play/App Store publishing, enabling hosted Find People/Mock experiments, buying external services, or personally representing unperformed human SQL review. Do not post a migration review approval unless the present task's actual authorization and authenticated owner identity satisfy the repository rules; otherwise supply the exact review artifact and complete independent validation.

Keep the task in its isolated branch/worktree; reconcile newest main before final checks, preserve concurrent `UIAUDIT02` and other branch work, resolve ordinary test failures, and create/merge a PR when legitimately allowed by the required checks. Only archive task-owned temporary environments/artifacts; never delete another task's resources. Record merged commit or the exact unresolved gate.

## Final handoff

1. **What was implemented:** canonical Private pair row/feed, send-context behavior, compatibility and preserved domain permissions; explicitly state any excluded contexts.
2. **Verified results:** tests, native before/after screenshots, successful migrations and security checks, CI/PR/merge status, and any known limitation.
3. **Delivery:** a compact phone-friendly before/after PDF or clear paired screenshots showing two previously separate personal rows collapsing to one while preserving all authorized messages, with stable source provenance but no private real-account material. Attach it through an accessible mechanism; avoid local-only links that the user cannot open from another device.
4. **Rollout:** precise backend-before-client deployment ordering, hosted work *actually* performed (if any), app-store status, and residual manual gates. Do not claim the founder's installed-app A1 is resolved until a compatible installed build actually reaches that backend.

Only A1 is in scope. The separate DE1 People-post author-management action and 19 delegated `UIAUDIT02` fixes are other tasks.