# PLANETS COCREATE00 — Trova persone / Co-creazione: implementation roadmap and first Sandbox prompt

**Status:** Proposed design and phased Codex handoff, **not implemented**. Inspected `lillo24/planets.community` `main` on 2026-10-21 (`3039b0d2aaf60038a595d206c67d758a26f70f4f`). Always recheck latest `main` before coding.

**Execution rule:** This document is a roadmap. **When given to Codex now, implement only A00 (Sandbox Co-Creation Mode).** Do **not** implement later plans merely because they are listed here. Later backend plans require their own focused prompts and the listed policy decisions.

## 1. What the product discussion establishes

A possible new home identity, separate from the existing Activities Split experiment:

- **Trova persone** — find people for an activity, an affinity, or a situation (e.g., newly arrived in Trento). People can publish a post describing whom they seek; browse topic communities; discover/join small activity groups.
- **Progetti** — collaboration/co-creation, possibly especially public-benefit or tangible-output projects. **Exact boundary versus events/activities remains undecided.** Existing native Project behavior must not be rewritten by this mock.
- **Scambia/Dona** — resources, materials and competences; potentially a matching engine across the other areas. Existing functionality stays unchanged.

The words Attività, Evento, Tavoli, Gruppi, and Progetto are not yet a mutually exclusive final taxonomy. Earlier ACTSPLIT01 placed Tavoli under Activities; this conversation considered other placements. **Do not silently reclassify Tavoli, migrate existing records, rename released data types, or narrow what counts as a Project.** Test the navigation concept before finalizing taxonomy.

### Proposed Trova persone experience

1. **Posts / Richieste:** simple authored posts such as “Cerco gente per calcetto”, “Nuovo a Trento, vorrei conoscere persone”, “Macchinata Trento–Verona”, or “Cerco gruppo per Lupus in Fabula”. These are social requests, not imported calendar events or native Project participation requests.
2. **Comunità / Hubs:** discoverable topic spaces such as Calcetto, Giochi da tavolo, Viaggi, Nuovi a Trento, Hiking, Cucito. A topic can have a main shared chat (the **hub chat**).
3. **Small numbered groups:** inside Calcetto, show **Gruppo 1**, **Gruppo 2**, etc., with their own separate member list, capacity, and private group chat. Names are system-generated *within the topic*, not arbitrary user-assigned titles. Users discover available groups on Trova persone and see joined ones in Messages.
4. **Later, not now:** a structured message in the hub chat such as “Gruppo 2 cerca 1 persona”, linked to an atomic join action. No invented availability or room full count.

**Important terminology:** these small groups are more like *crews with their own membership* than standard Discord channels (which often share the parent server's membership). Avoid conflating topic category, hub community, room, registered community group, or Project group chat.

## 2. Current code to reuse, without conflating domains

- `apps/mobile/lib/app/foundation_screen.dart`, `app/router/`, `features/settings/`, `features/activities_sandbox/`: current Home/Browse routing and device-local `Activities Split Mode` (`planets.sandbox.activitiesSplit`), disabled by default. ACTSPLIT01 is merged and has its own fixture-only catalogue.
- `supabase/migrations/20261011141035_persistent_groups_backend.sql`, `features/groups/`, `features/group_membership/`: registered `community_groups` (`informal`/`organization`) with **named, managed, durable identity**, publication and complex membership/authority. Not generic public topic hubs.
- `supabase/migrations/20261014074255_group_discussions_domain.sql`, `20261015094229_group_ideas_general_and_history.sql`, `features/group_discussions/`: registered-Group General/Ideas chat, invitations, admissions, messages, read/unread and Messages folders. Existing rooms depend on registered-Group access; do not treat them as open public topic channels without explicit new authorization.
- `features/messages/`, `features/project_chat/`, `features/group_contact/`, `features/group_coordination/`: other chat, Requests, consent, moderation, idempotency and conversation UI patterns. `group_coordination` describes provisional 3–5-seat conversations, **not** this proposed discoverable numbered-group product.
- `docs/architecture/product-decisions.md` and `docs/development/group-ideas-revision.md` document established membership/history contracts. Preserve them.
- ACTAPI01 (official event APIs) and ACTMET01 (activity interest tracking) are separate initiatives. No dependency between those and A00.

The design text quoted in this conversation is fully represented by the decisions above. **Codex needs no Google Doc, screenshots, external accounts, external services, or other out-of-repository files for A00.** Any future task that requires additional external context must state it explicitly.

## 3. Roadmap: a list of implementation lists

### A — Validate the new product identity (UI only)

- **A00 — Sandbox Co-Creation Mode (READY NOW).** Add another opt-in sandbox UI path with a Home entry for Trova persone, alongside Progetti and Scambia/Dona. Present separate Richieste and Comunità discovery, illustrative hub and numbered-room previews, and a mock post composer. Fixture data only. Keep all released functionality intact. **No DB, chat mutations, APIs, real posts, or actual joining.** Acceptance: navigation and coherent mock journeys that can be turned on/off.
- **A01 — UX evaluation / taxonomy decision (AFTER A00).** Compare A00 with ACTSPLIT01 on real devices. Decide whether native Tavoli belong under Attività, Trova persone, or another area, and whether the real official-event catalogue is separate from community-organized activity. Record decisions; do not implement classification migrations before this checkpoint.

### B — Public people-seeking posts (may follow A00 independently of C)

- **B01 — Post data, discovery and safety domain.** An authenticated owner can create/edit/close a bounded public people-seeking post with intent, optional topic, broad locality, created/expiry state. Public browse is paginated; RLS/RPC and reporting respect blocking, moderation, visibility, account deletion and location privacy. Avoid contact details and exact personal/meeting addresses. Separate from Project proposals and imported events. Decide a safe responder/interest-handshake before real contact actions.
- **B02 — Post mobile experience.** Replace the A00 Posts fixtures with real paginated listing, composer, details, My posts, controlled interest/response UX, loading/error/empty states, and EN/IT accessibility. Reuse native profile/report/consent patterns; do not create unsolicited direct messages from a public post.

### C — Topic communities and numbered group chats (can be planned beside B)

- **C01 — Hub catalogue, membership, and main-chat policy.** Define a finite, moderated topic directory (e.g., Calcetto; Giochi da tavolo). Determine who may create or rename public topics; what joining a hub means; and whether a main chat is open to all joined hub members. Establish source-of-truth, safe admission, privacy and reporting without reusing registered-Group grants accidentally. Reuse existing message infrastructure where authorization allows; otherwise add a clearly distinct typed domain.
- **C02 — Hub discovery and main-chat UI.** Public topic directory/filter/detail; explicit Join hub; chat link through Messages only for actually admitted users; Leave/mute/report; no public transcript before admission. Maintain current Messages/Requests/unread behavior across account switches and blocked actors.
- **C03 — Numbered rooms: backend and capacity.** Within a hub, atomic create/join/leave for numbered `Gruppo N` rooms; bound people count and prevent concurrent overfill. Numbering is stable inside each hub; room memberships must be separate from hub membership and from registered Groups/Project chats. Implement explicit admission/history/leave/removal authority policy, failure/idempotency and reporting. **Five seats is an illustrative sandbox default, not a global requirement until agreed.**
- **C04 — Numbered rooms: mobile + Messages.** Room list shows reliable current `n/capacity`, full/available state, and actual Join/Leave only when C03 authorizes it. Room details/chat with member-only history and send; joined rooms appear in the existing Messages Groups scope without duplicating conversation entries or inventing new nav tabs. Concurrency, reconnect, account switch and exited-user visibility must be tested.

### D — Extensions to decide later, not blockers

- **D01 — Structured “looking for one more person” posts.** A room can publish a server-authored, capacity-aware recruitment card/message to the hub chat. Joining rechecks live eligibility/capacity atomically. Expiry/retraction when full or archived, anti-spam and moderation needed.
- **D02 — Posts ↔ rooms ↔ Projects.** Optional conversion from a request into a room, or from an active group activity into a native Project/Event. Keep separate author/organizer consent and membership; never auto-join users through conversion.
- **D03 — Taxonomy, matching and provider events.** Link interests/skills/availability/locations, import official event data only through ACTAPI01, and evaluate direct links to Trova persone. No inference of personal relationships or crowding from clicks alone.

**Suggested execution dependencies:** A00 → A01 UX checkpoint. B01 → B02 and C01 → C02 → C03 → C04 are independent lanes after shared design/security review. D01 needs C03/C04; D02 requires B/C domain review. Avoid multi-layer mega-PRs.

## 4. Nonnegotiable unresolved product questions for real backend work

Do not silently decide these in C01/C03/B01: (a) whether an open hub chat's earlier history is readable on join; (b) what happens to group-message history after exit/removal; (c) who curates/creates hubs and moderates high-volume group chats; (d) maximum crew capacity, membership in multiple crews, and who can create/remove one; (e) whether post responders send an interest request, a private chat invite, or some other consent handshake; (f) how long transient posts and small rooms live; (g) safe handling of minors, shared rides, exact meeting places, spam, blocks and moderation. For A00 these are **visually illustrated, not committed**.

## 5. Codex implementation prompt — A00 ONLY

**Goal:** Implement a reversible **Settings → Sandbox → Co-Creation Mode / Modalità Co-creazione** that lets the team try the proposed navigation and public/community structure without any live social actions. Start from latest `main`, read `AGENTS.md`, nested feature instructions, repository migration/security conventions and current affected Flutter code. Prioritize minimal reuse over forcing old domains into new shapes.

**Mode and safety:**

1. Add a **distinct, saved, opt-in, default-OFF** Sandbox preference and visible description. Preserve `planets.sandbox.activitiesSplit` unchanged. When both are ON, the new Co-Creation visual experience takes precedence while active; turning it OFF reveals the user's previously saved Activities Split choice. Explain this interaction in Settings. Avoid automatic writes to the other preference. Follow existing bootstrap, error/retry and tutorial replay conventions; no flash of wrong Home layout.
2. With new mode ON, Home shows **Trova persone / Progetti / Scambia-Dona**. Trova persone opens a discoverable browse view inside the existing shell. Progetti and Scambia-Dona keep their **real existing routes**. Do not add a bottom-navigation tab or break native Projects, Tavoli, Groups, Chats, deep links, notifications, protected drafts or existing Activities Split mode when Co-Creation is OFF.
3. The new Trova persone page has two clear sections/tabs **Richieste** (authored posts) and **Comunità** (topic hubs), plus straightforward search/filter affordances. Include fictional, clearly labelled Italian/English sample posts spanning calcetto, board games, newcomers, and a Trento–Verona shared trip. A simple compose/preview flow may manipulate **only local ephemeral mock state**; no false publication success, auth requirement, network write or real messages.
4. Community fixtures: at least **Calcetto** and **Giochi da tavolo** plus a few other representative topics. Hub detail illustrates a main-chat preview and small numbered rooms **Gruppo 1 / Gruppo 2**, showing illustrative members and seat counts (e.g. 5/5 and 4/5) and a 'one seat remaining' state. A room preview explains that this would become a separate member chat visible in Messages. Actions must say clearly **Demo / Anteprima**, not claim to join a real chat. No fixture enters canonical Message, Group, Project, Resource, Tavolo or activity-API tables, controllers or analytics.
5. Use terminology that distinguishes **Comunità** (topic), **Chat generale** (the main hub), and **Gruppo N** (small bounded crew). Do not relabel registered `community_groups` as topic hubs or touch their persisted records. Honor existing localization structure, phone screen widths, accessibility labels and loading/scroll conventions.
6. Keep the first pass simple: no calendar scraping, event APIs, user matching algorithm, real user directory, contacts, private messages, notification delivery, maps, real chat, moderation mutations or database migrations. A00 is UI discovery, not a hidden production feature.

**Validation:** Add Flutter widget/unit tests for default-off/off-on transitions, preserved Activities Split preference and precedence, retained baseline Home and tutorial, navigation paths, mock Richieste/Comunità flow, numbered-room labels/capacity, EN/IT strings, back/scroll, small screens and account-switch safety. Run relevant analysis, scoped tests and Mobile CI/builds; provide exact results. Where feasible inspect rendered screens. Native-device acceptance can be deferred but must be reported as unverified. Document the toggle, demo limitations, test evidence and rollback in `docs/development/`.

**Delivery:** One focused PR for A00 only, with changes/tests/docs. Do not deploy or enable in production for everyone. Report newly discovered conflicts or policy choices without implementing B/C/D. Close/merge only according to the normal repository workflow; make no unrequested edits to other implementation-plan files.