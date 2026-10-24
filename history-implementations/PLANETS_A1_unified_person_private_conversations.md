# PLANETS A1 — One private conversation per person, across authorized contexts

**Codex implementation handoff — complete the feature, not another UX audit.**

## Goal and concrete acceptance example

In **Messaggi → Privato**, show **one conversation per unordered pair of individual PLANETS accounts**, even when the two people have interacted through multiple Projects/Tavoli, Scambio-Dona agreements, registered Group member contacts, or Find People posts.

Example: I request to join Marco's Project, ask to join another Project he created, and coordinate a Scambio-Dona loan with him. **There must be one Marco row and one Marco message timeline, not two/three domain-specific chats.** When the person-level thread opens, authorized messages from those relationships appear together in stable chronological order, with enough small contextual cues to understand which request/agreement/contact an action belongs to. Navigating to the conversation from any legitimate source reaches the **same personal thread**, optionally focusing the related context/message.

This **supersedes the A1 audit proposal to add labels to duplicate rows**. Labels alone are not the fix. Do not deduplicate by name or hide extra records. Maintain all original messages, requests, agreements, references and reports.

The user has approved the **person-level conversation experience**, *not* unrestricted direct messaging, silent new consents, cross-domain privilege sharing or publicizing previously private text. Preserve the current specific consent/permission model until a separate product decision explicitly changes it.

## Evidence and existing decisions — re-check current main

Repository: `lillo24/planets.community`. Latest observed main while drafting: `3bffe5868aea8549f4e345aece2020a6e72997c3` on 24 October 2026. **Fetch latest main, current PRs, AGENTS instructions and all applicable docs** rather than hardcoding that SHA or assuming the branch is stable.

Starting implementation areas to inspect (verify actual files/versions before editing):

- `docs/architecture/decisions/0007-participation-pair-conversations.md`, `docs/implementation/msg01-pair-conversations-and-request-messages.md`, `apps/mobile/lib/features/project_request_chat/`, `supabase/migrations/20261006101031_participation_pair_conversations.sql` — one pair across Project/Tavolo participation requests, but explicitly **not** Resource chats.
- `apps/mobile/lib/features/messages/` — current `list_own_scoped_conversation_items_v7`, distinct `MessageChatItem` kinds, composite keys, Private/Groups controller, unread/read-viewport behavior. The Find People inbox has separate components/readers; inspect current full composition and pagination, not only the native feed.
- `apps/mobile/lib/features/resource_chat/`, `resource_requests/`, `resource_exchange/` — accepted agreements have their own resource chat, history and read-only lifecycle. Preserve negotiated terms, handoff/milestones, and per-request evidence.
- `docs/development/member-contact-backend-review.md`, `apps/mobile/lib/features/member_contact/` — Group-origin, explicit accepted personal contact; the same two people can have different Group contexts. Approved policy retains permitted historical episodes and does **not** grant general DMs.
- `docs/development/cocreate-posts-contacts.md`, `apps/mobile/lib/features/co_creation/` — post-scoped explicitly accepted People contacts; post suppression or the experimental gate can deny transcript reads. Existing exact own-exit/recovery paths remain reachable.
- `docs/development/group-contact-contract.md`, `apps/mobile/lib/features/group_contact/`, `group_coordination/`, `group_discussions/` — representative Group-contact conversations and multi-person coordination have a different audience; do not automatically absorb them into person-to-person DMs.
- `docs/development/uiaudit01-pixel9pro-review.md` (A1, local reproduction) and `scripts/ui-audit/README.md` — synthetic evidence and native capture tools; no live-account screenshot required. The audit found distinct legitimate domains, not duplicate `(kind, chatId)` records.
- Connected Google Doc **Planets Community Design**, App Concept / Technical Overview, for intended product behavior. Some older entries expressly made Resource or request chats separate; **this new owner decision supersedes that UI grouping**, but it does not silently override prior security/retention/consent rules. Record the scoped design change in an ADR.

Potential overlapping work: UIAUDIT02 delegated cleanups and other recent main changes may touch Messages. Reconcile merged code, preserve active independent worktrees/PRs, and do not roll back unrelated improvements.

## Boundaries and scope

**Include the individual-to-individual `Privato` surface:**

1. Project/Tavolo participation requester ↔ original Creator pair; repeated/reversed requests already share one participation context.
2. Scambio-Dona owner ↔ requester, across different accepted listing/request/agreement episodes.
3. Explicit personal contact between members of a registered Group (even if multiple eligible origin Groups/consent episodes exist).
4. Accepted Find People post author ↔ interested person, across different posts.
5. Any other currently implemented **genuinely bilateral, personal** private conversation kind discovered in the current repository; inspect its audience and grant before inclusion.

**Exclude from person-pair aggregation:** multi-person chat, Project/Tavolo group rooms, Communities General and numbered groups, Ideas, registered Group discussions, representative Group-to-Group/bilateral *on-behalf-of-group* conversations currently under `Gruppi`, and staff/moderation evidence. Their authorization can involve more than two people, representatives, or an organization. Do not silently convert group authority into personal authorization. Describe any borderline case and why it was excluded.

The `Richieste` inbox continues to show **each structured request and its actions**; the private thread is a communication surface, not a replacement for independent approval, invitation, participation or exchange workflows.

## Non-negotiable security model

**One UI thread ≠ one universal read/send grant.** Each historic message retains its original owning domain, actor, request/post/agreement/group/episode provenance, staff evidence identity and authorization. A person-level thread can project **only messages the currently authenticated endpoint can read under the source domain's current rules**. An additional relationship with the same person must never unlock protected messages from another relationship.

Examples to explicitly preserve:

- Closing a Project request must not erase already authorized history, but must not create a new send permission; a different pending eligible request can still permit sends through its own context.
- A completed/closed exchange retains the existing allowed history but does not create a global DM send permission. Other legitimately active coordination can remain usable.
- Registered Group member contact lost due to Group/episode exit is not silently reactivated by rejoining or by a Project interaction; historical source access follows its own bounded rule.
- Suppressed/unavailable Find People post content must not leak via the pair inbox, previews, search, notifications, caching or old direct links. Experiment OFF, outdated policies and exit-only gates must remain enforced.
- Block, account ban/deletion, conditional sharing, temporary authority loss, moderator action and profile-photo audience must be rechecked **per source**, including after reconnect/account switch. Blocking's current already-accepted Resource exception must not be broadened or accidentally removed.
- A group manager, Group member, Project delegate, moderator or shared-lab tester does not gain any other person's private transcript solely by holding that role.
- Do not broaden `SECURITY DEFINER`, grants, Realtime subscriptions, accessible table projections or profile reads. Denied rows must not affect visible message counts or reveal their existence.
- Preserve original source-side immutable IDs, append-only semantics, time ordering, moderation/report references, data-deletion/tombstone behavior, account and role fencing, and installed-client compatibility. No mass message copying, destructive rewrite, best-effort table joins that bypass RLS, or fabricated migration repair.

## Product behavior to build

### 1. A genuine person-level inbox and timeline

- Exactly **one `Privato` list row per canonical unordered pair of user profile IDs**, with the other person's currently authorized public/interaction-limited display name/photo; never group by display name (two different people can share a name).
- Pair row activity, preview and unread indicators reflect the complete currently authorized cross-domain view. A pair appears when there is at least one currently authorized conversation/history to show; no empty unauthorized ghost row and no exposure of hidden domain existence.
- Opening the row displays **one continuous, stable time-ordered message view** assembled from all authorized eligible personal contexts, not a launcher listing four different legacy chat screens, separate tabs or four scrollable subthreads.
- Attribute messages to the correct original sender; preserve chronological ordering across contexts using a deterministic composite tie-breaker when timestamps match, stable pagination and no duplicate render on refresh/Realtime or cross-domain IDs.
- Label context transitions/messages sparingly (e.g. `Progetto: Murale`, `Scambio-Dona: trapano`, `Gruppo: ...`, `Trova persone: ...`) only when the viewer has access to that context/title. Avoid cluttering every bubble. Offer a compact accessible way to inspect the source context and its current status/action when authorized. Hide unavailable metadata rather than leaking names or IDs.
- Preserve native and browser/deep-link entry points to old domain-specific chat routes. A link to an authorized conversation should resolve to this person's **same universal private thread**, carrying only validated context focus; legacy clients may keep their original routes and RPC contracts. A denied/stale source link must not use the pair thread as a back door to read source data.
- Keep `Gruppi`, `Richieste`, notification inbox, Project group chat, Resource agreement controls and reporting actions functionally intact.

### 2. One composer, with contextual eligibility

- This is **not an unrestricted messenger**. A send must use an authorized, currently writable source context (e.g., pending eligible participation, accepted/open Resource coordination, live accepted member contact, accepted People contact). Let the backend revalidate its **original source command** and access rules.
- If exactly one valid context is writable, use it automatically and show enough indication of its origin. If several are writable, offer a compact context selector and make the chosen send context unambiguous before sending; do not silently send via an arbitrary context.
- If none is writable, keep the authorized history readable and show one concise explanation that sending requires an active permitted interaction. No artificial `Start chatting` button that bypasses consent.
- Keep unsent drafts bound to the active identity, person-pair and selected context; a stale/revoked context freezes or preserves the draft with truthful conflict/retry handling, **never silently retries through a different relationship**.
- Preserve rate limits, block/consent checks, atomic receipts, idempotent retries and original send domain. Do not add a global send API that assumes pair membership is sufficient authorization.

### 3. Requests, statuses and contextual actions

- Keep accepted/rejected/pending/withdrawn request events and Resource agreement milestones available as their original structured objects. Show a compact contextual entry card or event in the shared thread only if already authorized, with the proper route to review, accept/reject, withdraw, open Project group chat, inspect terms/loan state, or return to that source.
- Do not mix a sender's personal message with a manager-only request note or confidential agreement step. Avoid duplicating one request's labels across every message.
- Existing source-specific close/leave/mute/request behavior stays scoped. A `mute` in one domain must not silently become `mute Marco globally` without a separate approval. A shared person-level mute is **not** required by A1.

### 4. Pagination, unread/read, notifications and privacy correctness

- Backend person list must group **before** pagination; no client-side hide-by-person shortcut, no missing pairs split by 50-item page and no N+1 pair read storm. Preserve bounded database work and mixed-feed paging under many contexts/messages.
- Choose a rigorous server-authoritative way to calculate unread *persons* and incoming unread *messages* across all authorized contexts. A person with three unread source conversations must show one unread conversation badge and the correct total, not three conversation badges; legacy readers should continue to see their prior domain semantics.
- Acknowledge only rendered, foreground, actually visible messages using source-specific signed/bounded read-frontier proofs or an equally strong validated aggregate that composes original rules. Opening the pair row must not mark hidden/older/offscreen/inaccessible messages read. Failure of one domain must not generate a false `all read` state.
- Combine source-scoped Realtime signals into a bounded invalidation flow. Revalidate on restart, reconnect, block, realm/account switch, context closure or authorization change. Never subscribe to previously inaccessible transcripts or expose IDs/titles/bodies in broad invalidations.
- Correct empty/loading/error/partial-state composition. If one source temporarily fails, do not claim the pair has no history; preserve permitted loaded content with an accurate partial-data warning and retry without leaking denied context details. Ensure offline/stale caches are fenced by account/realm/policy.

## Suggested implementation approach (not rigid implementation instructions)

Inspect current DB functions, source feed/read-frontier contracts and indexes before choosing. A sensible design is a **stable cross-domain person-pair projection/anchor for inbox identity**, plus a **bounded, authorization-filtered chronological union of original source messages** and contextual actions. Keep source messages where they are and route sends/acks/reports to their owning domains. Avoid treating the existing participation-specific anchor as automatically granting authorization for unrelated Resource/Group/People contexts.

A dedicated immutable pair ID and an internal source-context association can be useful, **but pair existence must not itself create a consent or membership**. If you add tables/functions, use unique canonical ordered pair keys and additive migrations with audited grants/RLS/search_path, stable indexes and explicit actor checks; protect concurrent first-contact creation and legacy conversion. Alternatively, if a securely paginated pair projection can be built over existing proven read helpers without persistent new anchors, explain why that is safer. Either is acceptable if the UI really becomes one timeline and remains efficient.

The existing database uses multiple message ordering strategies (time, per-chat ordinal, conversation IDs). Define a **total ordering** across sources with stable tie handling and cursor semantics; preserve original per-domain order when equal-time records appear. Never load every message into memory just to sort them on the phone.

Do not refactor unrelated messaging internals solely to make code pretty. Keep untouched public RPC results and applied migration bytes byte-for-byte identical. Add versioned APIs, make the new client/backend requirement explicit, and supply an honest old-backend fallback or version gate without disguising multiple domain rows as a completed A1.

## Execution strategy: end-to-end, staged within the task

This crosses multiple independent chat domains, SQL/RLS, badges/read receipts and mobile navigation. **Use one coherent Codex implementation task with two reviewable stages**; use two sequential PRs if this materially reduces risk, otherwise one clearly divided PR is acceptable. Finish both stages where authorized. Do not stop after a document, read-only spike, or backend-only commit while the client stage remains runnable.

**Stage A — evidence and backend contracts.**
1. Inventory all actual bilateral private domains, canonical sources, ids, access endpoints, consent/write/read rules, message provenance, pagination, notifications, unread counts and browser/mobile routes. Record an explicit inclusion/exclusion and access matrix in a short new ADR.
2. Prototype and verify one canonical pair lookup and mixed person-row projection over representative actors/contexts, with complete authorized counts and keyset paging. Verify no source-history leakage after closure/suppression/block/membership loss.
3. Add the aggregate person-timeline read/projection and read-boundary composition without mutating historical source message IDs; exact routes/messages retain their original report evidence. Keep old API behavior intact.
4. Run schema, grant, index, lock-order, populated upgrade and canonical Auth/RLS concurrency tests before using the new endpoints in the app.

**Stage B — complete mobile experience and qualification.**
1. Implement one deduplicated private inbox row keyed by the canonical unordered pair (server groups before paging) and a single mixed timeline; keep separate `Gruppi` navigation.
2. Reuse shared Messages viewport behavior, rich context navigation and source-specific send/recovery/read acknowledgements. Route old deep links/notification taps safely into the same thread.
3. Cover Italian and English copy, light/dark, long names, bigger text, unread badges, composer statuses, profile photo privacy, sparse labels, contexts changing mid-send, errors and offline resumes.
4. Run actual Android native tests on an owned emulator with the original Mock personas and task-owned disposable Auth/backend. Collect **before/after images** of two different domains for the same person and at least one three-domain pair. Distinguish synthetic backend results from the user's prior installed-app screenshot; do not claim the installed release is changed.
5. Validate complete inter-domain typing, old-client RPC contracts and mobile build; reconcile current main; follow normal protected CI/review workflow and merge qualified code, reporting exact blocks if any.

Use existing task-owned fixtures and CI verifiers when possible; extend focused tests rather than running every expensive historical suite repeatedly. No mutation of a shared hosted Mock, staging, normal/production database or release state is authorized by this handoff. No Google Play upload, Cloudflare deployment, billing, feature-gate enablement, iOS release or environment reset. Preserve independent in-flight agent worktrees, PRs and build caches.

## Required failure and regression matrix

1. Two accounts share the **same display name**: never merge. One pair has two Projects and two Resource exchanges: exactly **one** row, one thread; all original source events remain distinct and actionable.
2. Same requester and Creator across reversed Project roles/Tavoli, multiple pending/accepted/rejected/withdrawn episodes, with source status changes while thread is open.
3. Two accepted Resources with one completed and one writable, terms negotiated/loan returned, original report IDs and messages intact.
4. Two member-contact origin Groups for the same two people; one accepted, one ended; context loss and rejoin do not reactivate old send permissions.
5. Multiple accepted People posts between the same actors; suppression, closed/expired posts, experiment OFF and identity-only own-exit: no private leak or illicit reopening.
6. A user blocked with one permitted Resource coordination exception; no illegitimate fallback through a blocked Project/member/People source.
7. Distinct accounts/groups with overlapping names, deleted/profile-hidden counterpart, authorization downgrade mid-page, actor/realm switch, stale source deep links and reordered realtime events.
8. Equal timestamps and message UUID collision across domains, 50+ original contexts, mixed historical/new sends, large text bodies, stable before/after pagination, exactly-once list projection.
9. An actor has unread in two contexts with one counterpart: one unread person but correct incoming message total; open history/read-scroll/ACK proves only actually rendered messages are acknowledged.
10. An RLS-denied/missing source, one timeout and one permission revocation: no hidden rows/previews/count/title disclosure, truthful partial-data state, no data loss or auto-submit.
11. Legacy app endpoints for every original source still work after forward migration; populated real-looking migration preserves all old rows, warmed RPC OIDs/ACLs/result shapes, exact moderator evidence, and actor/policy restrictions.
12. Test fixture shows A1-before (two rows with same counterparty, different domains) and A1-after (one row and correctly mixed private timeline). Use real local PostgREST/Auth and the actual mobile render, not only mock widget assertions.

## Definition of done / result

- **One person, one Private row, one continuous private timeline** with preserved source consent/authorization, appropriate active-context send, and zero lost messages or permission widening.
- One new documented ADR defining canonical person-pair UI semantics and the fact that old domain grants remain independent (so previous ADRs and historical tests remain understandable).
- Additive migrations/versioned readers and backwards compatibility for installed clients; no historic migration rewrites or unreviewed hosted writes.
- Actual native evidence with accessible content and stable app navigation from all legitimate contexts, plus focused SQL/Auth/upgrade/Realtime/unread tests and final CI result.
- PR(s) merged into `main` only after all required checks and applicable exact migration review approval. If those are genuinely blocked, preserve reviewable PR(s), finish unrelated work and report the precise unresolved gate; do **not** disable a migration approval rule.
- Final report: exact repo head/PRs/merge state, included domains and deliberate exclusions, UI behavior, data/permission invariants, passed/failed/deferred verification, any backend prerequisites for a future release, and the specific old screenshot scenario to test on the next installed build.

**External context:** No private reference screenshot, spreadsheet or Google Doc export is required for Codex to complete this task. All necessary engineering context and target behavior are in the repository and this prompt; the screenshot is optional as a visual reference. If Codex needs a separately held credential or approval to do a hosted deployment, **stop that hosted action**, do not guess or search for secrets, and finish local implementation/verification.
