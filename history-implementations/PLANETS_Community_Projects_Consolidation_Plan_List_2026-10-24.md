# PLANETS — Community / Project consolidation: implementation plan list

**Prepared:** 24 October 2026  
**Repository:** `lillo24/planets.community`, inspected `main` at `43dcf11a64c375dc9c21c2196770fbd12059c2db` (re-inspect before implementing).  
**Status:** proposed *sequencing and scopes*, **not implementation**, **not deployment approval**. Five distinct new Codex implementation plans are recommended; two pre-existing handoffs are tracked separately.

## Target product model

Use these meanings in the **new Find People / Communities experience**. Do **not** rename applied database tables or existing `/proposals/*` URLs merely to change user-facing vocabulary.

| User-facing concept | Role | Existing implementation boundary |
| --- | --- | --- |
| **Community** | Durable shared interest such as Drawing, Valorant, Gardening | Co-Creation curated topic hub with General and optional numbered groups. It is **not automatically** the existing registered-Group domain. |
| **Propose a Community** | Suggest a *new* community/topic not yet listed, with support/activation flow | Existing normalized community proposal + eligible-interest threshold; separate from Project creation. |
| **Project / Activity** | A concrete collaborative thing people can create, discover and join | Existing native Project/domain, whose internal API/URL vocabulary still says `proposal`. Native Project may have its existing early *Idea/in-definition* state; this is not a new Community proposal. |
| **General** | Public-to-admitted-members discussion for a Community and place to share relevant public Projects | Existing Co-Creation General with episode-specific admission and message rules. |
| **Numbered group** | Smaller persistent chat within the Community; may schedule meetings | Existing Co-Creation numbered group, not Project membership or registered Group. |
| **People-seeking post** | Separate experimental post with *Mi interessa*, author responses and post-scoped contact | **Legacy workflow to retire from the new primary UX**, preserving existing data, accepted contacts, reports and access safeguards. |

### One expected journey

1. In **Drawing**, members enter its General discussion.
2. A person creates a **Project** using the existing native editor (for example, *Paint a mural in Trento*), or finds a relevant already published Project.
3. An admitted General member shares the published Project in Drawing's General. Other General members see a useful Project link/card and may open the existing Project detail.
4. Joining the Project still uses **native Project participation** and its existing authorization; viewing the card or belonging to Drawing does not grant Project participation, chat access, creator authority or a new personal contact.
5. When **Valorant** does not exist yet, someone uses **Propose a Community**, and the existing interest/support and activation flow creates the durable Community when eligible. It does not create a Project.

No extra People-seeking post is necessary to complete that journey.

## Planned implementation workstreams

### CP01 — Community-first navigation and naming

**Goal:** The new Find People presentation leads primarily to existing Communities, not experimental People posts. Remove the ambiguity between a Community proposal and Project creation.

**Likely areas to inspect (confirm on latest main):**
- `apps/mobile/lib/app/router/app_router.dart`: `/people` currently renders `PeopleBrowseScreen`; `/people/hubs` and categorized Community routes exist.
- `apps/mobile/lib/features/co_creation/presentation/people_browse_screen.dart`, `co_creation_community_screens.dart` and the existing Home/Settings components.
- `apps/mobile/lib/l10n/app_it.arb` and `app_en.arb` for new-mode strings. Preserve existing mobile Mock Mode identity/realm handling and native navigation.

**Implementation scope:**
- Make ordinary new-mode Find People entry a clear **Communities / Find People** discovery interface; keep category, hub, General, numbered-group and Community-proposal access.
- Give **Propose a Community** its existing eligible category/proposal flow. Do not accidentally repurpose native Project proposals or create a parallel proposal backend.
- Make Home labels truthful. Do not show a disabled *Propose an idea* card implying a nonexistent separate creation system. Remove or replace it with a route to the **existing** Community proposal flow only where the required category can be selected correctly.
- Remove new People-post *browse/create/mine* affordances from the **primary experience**, but **retain exact legacy routes and necessary recovery/access paths** until CP04 has inventoried their users and data. Changing `/people` must not break `/people/posts/:id`, `/people/compose`, or protected existing continuations without an explicit compatibility decision.
- Do not change account eligibility, supported Community activation threshold, registered-Group permissions, or the experimental server gate.

**Acceptance:** From the new-mode Home and Find People entry, a member can discover Drawing/Valorant, enter the eligible General, and propose a *new* Community; no normal front-door leads to a People-post feed. Existing private legacy/exit links remain safe. IT/EN and Mock persona route tests pass.

**Dependencies:** None of CP02–CP05; coordinate with UIAUDIT02's localized Settings P1 update. **Size/risk:** Medium; mostly routing, localization and guarded legacy visibility.

### CP02 — Reuse native Project discovery and creation in the new mode

**Goal:** *Find activities* is functional and takes users to ordinary **Projects**, rather than a different Co-Creation post model.

**Likely areas:** native `/proposals` discovery, `/proposals/create`, existing editor/draft/Idea state, new-mode Home/router, community/numbered-group Project entry. Inspect the existing `CoGroupProjects` and native draft source-link flow before extending it.

**Implementation scope:**
- Connect **Find activities / Projects** to the existing native browse/detail/search and create/edit flows, with their existing auth, data fields, map/location and participation rules.
- Give a member a clear **Create Project** entry where sensible; when launched from a Community/numbered group, preserve a safe route back. Do not copy its membership, chat, location or organizer rights into the native Project.
- Reuse the current native *Idea / in definition* Project lifecycle if applicable. Keep *Propose a Community* strictly separate. Preserve native direct/deep links and standard navigation in other app presentations.
- Do **not** invent group-owned Projects merely because creation started in a Community. Native creator/registered Group ownership stays authoritative; official Community ownership would require a separate founder decision.

**Acceptance:** A member can discover/create a Project through the new Home, publish it through the normal editor, view it with an unrelated Mock persona and request to join using existing native permission gates. No second Project database/editor is created.

**Dependencies:** CP01 for settled labels/navigation. **Size/risk:** Medium, primarily mobile integration and regression checks.

### CP03 — Share published Projects into Community General

**Goal:** A member can share a relevant existing Project in Drawing's General, and recipients can open the regular Project details, without pasting raw links or conflating the two memberships.

**Likely areas:** Co-Creation General chat and its versioned message contract, native public Project-detail/share links under `https://planets.community/proposals/<id>`, existing source-project links from numbered groups, message link review, public Project reader and moderation rules.

**Implementation scope:**
- Provide one explicit **Share Project** interaction, available from an eligible Project detail and/or the General composer. Prefer a compact, validated in-app Project link/card using **existing public sanitized fields**, with a clear title and action to view. Choose the smallest source-of-truth-consistent design after inspecting existing chat message types; don't impose a new cross-domain schema if safe canonical link rendering suffices.
- Limit the sender to their **current authorized General** episode. Validate the Project's **current public visibility** before preview and on open; don't leak unpublished Projects, exact private location, roster, private invitations or hidden metadata.
- A card/link does **not** enroll someone in a Project, move them into a numbered group, make the Project officially owned by the Community or create an unrestricted DM. Native Project join requests happen in the native detail.
- Preserve General text/link spam warning and moderation for ordinary messages. Give a first-party, validated structured share its correct UX without creating an arbitrary-URL warning bypass. Failed publication, revocation, deleted Projects, share races and old recipients must display a safe unavailable state.
- Do not introduce a persistent *officially associated Community Projects* directory yet; historical shared messages are enough unless evidence demonstrates a need.

**Acceptance:** Member A shares published Project X in Drawing General; member B sees a safe card/link, opens X with their native authority, and can request participation independently. Private/draft X is not exposed, unrelated Community members cannot read General, and a cancelled/hidden X doesn't leave leaked content. Existing chat/read/unread/moderation tests still pass.

**Dependencies:** CP02. Coordinate with existing group-created Project draft/source link logic and A1; do not replace them. **Size/risk:** High due to cross-domain visibility and chat mechanics. Split backend/renderer into separate PRs only if security/contract review requires it.

### CP04 — Reversibly retire People-seeking posts and preserve history

**Goal:** Remove the duplicate *post → Mi interessa → post-contact* path from ordinary new creation/discovery **after** CP02/CP03 provide usable Projects and Community entry, without losing historical conversations, reports or user rights.

**Likely areas:** `people_browse_screen.dart`, `people_manage_screen.dart`, `people_message_items.dart`, People-post gateways/routes, post-linked event/source workflows, native Messages and moderation/report/legacy-close/withdraw paths, Mock fixtures, migration and deployed-client compatibility.

**Implementation scope:**
- First inventory server activation and hosted deployments, actual data/active contacts, compatible mobile releases, old links, saved posts, current report obligations, accepted contact history and the A1 unified-chat implementation status. Do not assume the experimental gate being OFF means there is no persisted data or old client.
- Stop offering new People-post browsing/creating/interest requests in the normal new UI. Redirect **new intent** to Projects, Communities or meetings where appropriate; do not silently transform an existing post into a Project because fields and consent semantics differ.
- Preserve authorized **existing** accepted contacts/messages; actor-only historical views and exact exit/close/withdraw, reporting, audit links, moderation evidence and erasure/retention policies. If A1 is not merged, preserve the original accessible private conversation rows/routes until it is. Do not strand a legitimate conversation by hiding its only route.
- Maintain server/RPC backward compatibility during any overlapping installed-client period. No destructive database migration, bulk rewrite, automatic enrollment, mass post closure or irreversible data deletion as part of this stage. Any backend hard removal needs its **own** later, evidence-based, explicitly approved plan.
- If removing the feature leaves a genuine unsolved lightweight case (*I want someone to draw with tomorrow*), document that gap instead of quietly reintroducing People posts. Existing General and scheduled meetings should be evaluated first.

**Acceptance:** Current users can still read legally/technically authorized legacy private messages and complete necessary withdrawals/closures/reports; current new-mode users cannot accidentally enter the duplicated new-post workflow. Mock and older-client compatibility checks show no broken links or unauthorized exposure.

**Dependencies:** CP02 + CP03, and **A1 must either be implemented/qualified or its accessible legacy message paths retained**. Coordinate with UIAUDIT02 FO1/DK1/DU1: even sunset content needs correct permissions/empty states. **Size/risk:** High, because of privacy, legacy clients and data lifecycle.

### CP05 — Cross-persona integration, UI audit and release qualification

**Goal:** Verify the consolidated experience from different users' perspectives and provide concise founder-review evidence before any rollout.

**Likely areas:** the existing independent Activities/Find People Mock realms, `scripts/mock/world.mjs`, `scripts/mock/people-world.mjs`, native Pixel 9 Pro screenshot tooling, integration tests, project sharing/participation verification and documented release gates.

**Implementation scope:**
- Preserve all ten canonical Mock personas and update **scenario journeys**, not arbitrary fake one-off profiles: Drawing General → public Project share → distinct requester → authorized Project participation; a proposed new Community → eligible support → explicit General join; Project creator vs General member vs outsider vs rejected/blocked account.
- Keep a legacy-access regression fixture when post-contact data is retained. Don't erase retained shared Mock data or reset a non-task-owned realm.
- Run relevant backend/RLS, auth, send/unread/pagination, lifecycle, Flutter, router and localization checks, including old-deep-link denial/safe fallback and server-gate OFF. Confirm that each normal-mode feature still works independently of the Co-Creation presentation switch.
- Produce a **brief phone-friendly before/after PDF** and original-capture ZIP, with stable issue IDs and deduplicated findings. Prefer an owner-accessible private Google Drive handoff (if authenticated); otherwise return verified local artifacts and exact manual transfer instructions. Do not commit private screenshots or identities publicly.
- Record **implemented / tested locally / deployed / not deployed** separately. Do not activate hosted gates or publish an app release without separate authorization.

**Acceptance:** The main path works for the creator, recipient and non-member; UI terminology matches the model; private history and moderation rights remain correct; all reported breaks are documented. Founder has a short review artifact rather than a fresh 457-page audit.

**Dependencies:** CP01–CP04 and compatible A1/UIAUDIT02 changes. Each preceding PR still requires its own tests; CP05 is not a substitute. **Size/risk:** Medium, integration/test-heavy.

## Existing plans to coordinate, not duplicate

| Workstream | Already on `main` | Coordination rule |
| --- | --- | --- |
| **A1 — One private personal conversation per pair** | `history-implementations/PLANETS_A1_unified_private_conversations_codex.md`, merged documentation PR #323 | This is an **implementation handoff**, not proof of merged code. Unified authorized history must include legacy post contacts if eligible; **CP04 must not remove their only accessible history**. No cross-domain consent escalation. |
| **UIAUDIT02 — 19 approved UI/functional fixes** | `history-implementations/PLANETS_UIAUDIT02_19_delegated_fixes.md`, merged documentation PR #322 | Implement on latest code. Do not repeat work in CP01–CP05; preserve FO1 reporter security, DU1 composed inbox states and other historical corrections even if the new post entry is retired. **DE1** (own-post management UI) stays on hold and becomes unnecessary if the new People-post entry is retired. |

Suggested dependency order: **CP01 → CP02 → CP03 → CP04 → CP05**. UIAUDIT02 may run early. A1 may run independently but should merge/qualify before CP04; take care if concurrent work touches Messages or Co-Creation components. Avoid parallel overlapping code branches when a sequential merge is cheaper than conflict reconciliation.

## Important boundaries and questions for future code prompts

**Chosen conservative defaults for these plans:**

1. **Project origin/ownership:** Sharing a Project in a Community does not turn it into a Community-owned Project. Author remains the existing native creator/registered Group, until a separately approved ownership model exists.
2. **Sharing scope:** Start with a member sharing a **public, currently visible** Project into a General they can already write to. Do not require Project ownership merely to share a public link; enforce existing chat spam/moderation and Project visibility.
3. **Proposals:** In *new-mode copy*, “Propose a Community” means a **new Community**, while “Project” means a collaborative activity (native routes and database may still use “proposal”). Don't globally rename native proposal IDs/URLs or erase native *Ideas*.
4. **Legacy post history:** Sunset UI first; retain historical data, access and compliance until actual usage/retention/older-client evidence can justify separately approved destructive retirement.
5. **Environment:** `main` contains merged experimental code, but its server gate defaults OFF; repository integration does not imply production activation, actual hosted migration, signed app release or physical-device acceptance.

Stop and surface material new choices rather than silently deciding: whether Communities should formally **own** Projects (not needed for sharing), whether Projects require permanent curated linking to Communities (not needed for in-chat sharing), and whether any new lightweight one-to-one people-seeking flow is truly indispensable after normal Project + General + meetings work. If no such choice blocks a phase, implement the minimal reversible behavior described above.

## Scope of this artifact

This file **lists and scopes five future independently reviewable Codex implementation plans**. It is a roadmap, **not** five fully expanded code-edit prompts and not permission for destructive operations, production activation or release. Before executing any phase, derive that phase's focused prompt from **current** `main` and current `AGENTS.md`, inspect the required domain owners, use a separate PR/worktree and record exact acceptance and rollback evidence. No external Google Doc, Drive, audit PDF or personal screenshot is required to implement these phase definitions; optional private evidence can improve visual review but must not be assumed accessible to Codex.
