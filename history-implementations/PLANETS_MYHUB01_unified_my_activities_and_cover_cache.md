# PLANETS MYHUB01 — Unified “Le mie attività”: two compact filters, small horizontal cards, owner covers

## Objective and sequencing

**Implement MYHUB01 now, directly from the latest `origin/main`. Do not run or wait for DRAFTFIX01.** The previous observation that Bozze showed “Error” has not been reconfirmed on the newer app, so independent root-cause diagnosis is explicitly deferred. This task replaces the draft-only folder and its top-right management menu with one personal activity list containing the user's own Projects, Tavoli, Dona and Scambia entries, across draft, published and terminal states; it also keeps the co-organized work previously reachable in My Projects/My Tavoli.

The requested UI is deliberately minimal: two compact **multi-select picker fields**, then a chronological feed of **new small horizontal cards** with a left thumbnail, title and small status badge on the right. No large cover cards, secondary explanation lines or extra filter headings. Retain the earlier requested bounded, safe reuse of personal cover images.

## Current repository facts (inspected 2026-10-21)

- `apps/mobile/lib/features/drafts/presentation/drafts_screen.dart` implements `/drafts?types=project,table,donate,exchange`. Four visible `FilterChip`s select item types, and a top-right `drafts-management` overflow links to `/proposals/mine`, `/tavoli/mine` and `/resources/mine`. It currently displays draft rows only. `application/own_drafts.dart` composes the existing three owner controller collections and sorts by real `updatedAt`.
- The three owner data models and gateways already cover drafts, published and terminal records with canonical IDs, lifecycle, title, update time and cover path. `OwnProposalsScreen` and `OwnRecurringActivitiesScreen` separately display `delegatedProjectsProvider` entries. The delegated projection carries `delegatedAt`, not genuine content `updatedAt`.
- **Use the existing category/skill picker pattern**: `apps/mobile/lib/core/widgets/tag_multi_select.dart` (`TagMultiSelect` with `TagMultiSelectCategory`/`Option`) and `apps/mobile/lib/features/proposals/presentation/skill_filter.dart`. It is a compact field opening a bounded multi-select sheet, not the segmented Projects/Tavoli browsing switch or four permanently visible FilterChips. Existing selector text is skill-specific; adapt localized wording/optional search minimally for generic type/status pickers, without breaking current skill uses.
- `apps/mobile/lib/features/cover_media/application/cover_image_loader.dart`: public covers use immutable-path `publicCoverBytesProvider`; owner-only covers use identity-checked `FutureProvider.autoDispose.family` keyed by `(ownerProfileId, objectPath)` and can refetch on revisit. Shared `CoverImage` already handles loading, errors and missing images. Review storage grants and identity invalidation before modifying caching.
- `apps/mobile/lib/app/router/app_router.dart`, discovery toolbar actions, tutorial flows, and old owner-management routes are existing navigation contracts; update them coherently. Other relevant references: `apps/mobile/test/features/drafts/drafts_test.dart`, `apps/mobile/lib/features/drafts/README.md`, `apps/mobile/lib/features/proposals/README.md`, `apps/mobile/lib/features/recurring_activities/README.md` and `AGENTS.md`. Recheck all against the newest main when implementing.

## Fixed visual and interaction decisions

### Unified screen

- Name the page **“Le mie attività”** (EN “My activities”). Open it from the existing folder/own-items toolbar actions. Remove the now-redundant top-right dropdown used solely to jump among My Proposals/My Tavoli/My Listings, because these records will already be accessible here. Do not remove capabilities that previously lived on those screens.
- Show *owned* entries from all four types: **Progetti, Tavoli, Dona, Scambia**, including drafts, published/current and terminal/history entries. Preserve a distinct, understandable way to reach current co-created/co-organized Projects/Tavoli. Do not show arbitrary Projects merely joined as a participant as personally managed content.
- Default sorting: **newest actual `updatedAt` first** for owned records. Stable tie-break by type and ID; no duplicates. A source does not need to have data returned for another source's cards to display.

### Exactly two compact picker fields, not visible filter-chip rows

- Replace the old strip of always-visible four type `FilterChip`s with **two field-style multi-select controls** based on `TagMultiSelect`/`SkillFilter`'s existing category search-selection pattern:
  1. **Tipo**: Progetti / Tavoli / Dona / Scambia.
  2. **Stato**: all lifecycle groupings needed for drafts, published, paused, completed/ended/closed and cancelled states. Present concise EN/IT names; do not collapse paused or cancelled into an incorrectly “active” label.
- Each field is self-explanatory: **show `Tipo` and `Stato` as the in-field empty placeholder/label**. **No extra heading above them**, no lengthy helper caption, no “Select types”/“Select status” instructional sentence. When selected, show a short selection summary (selected names/count), preserving a clear control identity. Keep the control as compact as possible without sacrificing touch targets or accessibility.
- Opening each field reveals the actual multi-select choices with Apply/Clear or existing staged choice behavior. **OR within Type**, **OR within Status**, **AND across the two fields**. No selections in a field means All for that dimension. An existing contextual entry `/drafts?types=project` should preselect the type but still include all statuses by default.
- Do not reproduce the **Projects / Tavoli culturali segmented switch**. This is the user's specifically rejected style for this screen. Adapt the generic picker so it never says “Search skills” or “skills selected” for type/status; with only a few static options, suppressing an unnecessary search box is acceptable while retaining its compact dropdown/sheet visual vocabulary.
- Prefer two selectors in one row on normal width if comfortably readable; wrap/stack them at 320dp or 2x font size rather than truncating labels or overflowing.

### New reduced horizontal card design — intentionally different from existing browse cards

- **Small left thumbnail** (roughly 84–104 logical px wide at ordinary phone width, responsive), cropped consistently; if no cover, keep the same compact geometry with a neutral native placeholder. Never use huge 16:9 full-width images or a tall stacked `CoverImage` inside each card.
- To the **right**, show the title prominently, with a compact status badge in the **top-right** (`Bozza`, `Pubblicato`, `In pausa`, `Concluso`, `Annullato`, etc. as appropriate). Include at most one muted metadata line, e.g. type and a truthful concise modified date when it adds value. Omit redundant descriptions, category explanations, “Continue editing”, “Open and manage”, long subtitles, decorative action rows and duplicate lifecycle words.
- Example of desired density (layout guidance, not synthetic app content):

  ```text
  [small cover]  Orto di quartiere         [Bozza]
                 Progetto · 20 ott.
  [small cover]  Tavolo di filosofia      [Pubblicato]
                 Tavolo · Ieri
  ```

- The **entire row opens** the correct existing destination. Draft -> guarded editor, published -> established detail/management flow, terminal -> appropriate permitted/read-only state, Resource -> existing owner listing/actions. If only a delegated managerial role is available, show the role concisely and honor that role's actual permitted navigation. Do not show an edit icon for rows without editing permission.
- Titles need graceful wrapping/ellipsis; badge and thumbnail must remain legible on 320dp screens at 2x text, in IT/EN and light/dark. Tight design is not a fixed-height overflow. Use new local card style rather than broadly changing public discovery cards.

## Lifecycle, owner/delegated work and data integrity

- Use real canonical lifecycle/derived status. A published Proposal can be a completed event; an unpublished Idea is still a draft; a paused Tavolo isn't active. Filters must reflect those facts and badges must not lie. Add status grouping as presentation logic, not invented backend state.
- Keep owned records together in updated-first order. Because `DelegatedProject` offers `delegatedAt` and no reliable content update timestamp, show delegated/co-organized work in a **small clearly distinguished section of the same page** sorted by a truthful available date, or reuse a verified existing authorized actual update time if available. Do not fabricate “last edited”. Preserve Creator/Co-creator/Co-organizer identity where needed, don't duplicate owner records and don't elevate delegate permissions.
- Retain DRAFT01 pending-create/recovery behavior and editor-return navigation. Keep existing owner actions (publish/pause/resume/end/cancel, resource requests, etc.) reachable from proper destination. Preserve old `/drafts` route and `types=` links; legacy `/proposals/mine`, `/tavoli/mine`, `/resources/mine` and deep links must still work or route to an equivalent filtered hub without losing management functions.
- On return after editing or state change, refresh only relevant source when sensible, reorder by updatedAt and preserve type/status selections. Error loading Projects must not hide previously loaded Tavoli and Scambio. Show a small localized per-source Retry and truthful partial loading/error. **Do not claim to have diagnosed or fixed the older reported Bozze error** unless independently reproduced and resolved as a necessary part of MYHUB01; DRAFTFIX01 is *deferred*, not a prerequisite and not a separate required task.

## Cover performance (part of this same UI task)

- Reuse `publicCoverBytesProvider` for publicly readable immutable cover paths. For owner-only draft covers, implement or reuse a **bounded per-session, identity-scoped in-memory cache** so a return to this list usually displays previously fetched covers immediately. Do not promise zero latency for first download or decode.
- Bound cache entry count/bytes, prefer currently visible cards (no bulk preloading all history); invalidate on sign-out, account switch, authorization loss, resource disposal/memory pressure, and different immutable object path. Never keep private draft photos available to a different identity, export them to public cache or persist them to disk without a separate reviewed design. Preserve safe error and retry behavior.
- Covers must be optional and must not delay display of title/status. Test that opening and returning to the list reuses valid owner bytes (measure gateway call counts), and that switching actor clears them.

## Validation and implementation autonomy

- Follow repository feature-first conventions and inspect the current actual code and tests. Prefer existing owner collections/controller adapters; don't duplicate server queries or invent a giant combined feed or schema solely for this UI. If a new backend projection would be necessary for purely cosmetic timing, avoid it; use the distinct delegated section instead.
- Update EN/IT localizations, route/tooltips, screen-reader semantics, tutorial references, and docs describing draft-only hub behavior. UI testing must cover two compact selectors, staged multi-selection/clear, OR/AND and default-all logic, contextual entry, all types/statuses, actual update sorting/ties, permissions, authenticated vs invalid identity, cross-type same UUID, per-source partial failures, editor return, compact responsive cards, and owner image cache lifecycle.
- Visually inspect real Flutter widget screenshots (not invented screenshots) for IT/EN, dark/light, regular and 320dp 2x; assert no overflow and no extraneous explanation copy. Run `npm run check:mobile`, relevant focused/native integration checks and final-head CI.
- No Play upload, no phone installation, no staging/prod SQL/Edge/provider writes, no billing changes, and no destructive data operations. No external screenshots or Google Doc are required; this prompt contains the requested visual specification. Device `48091FDAS0041A` can be used for read-only QA if available; do not block on physical-device access.

## Completion and merge instructions

- Work from the **latest `origin/main`** on an isolated branch/worktree. **Do not execute DRAFTFIX01 first or delay MYHUB01 pending its result.**
- Implement, test, document and open a focused PR. After required CI passes, inspect changes and **automatically merge the verified MYHUB01 implementation into `main`**, then sync and clean up the task branch/worktree. Do not leave a green mergeable PR open merely because real-phone tests or separate Bozze investigation remains. Stop if there is a consequential permission/security failure that cannot be safely resolved.
- Report merged PR URL, screen examples/screenshots, status/type filter behavior, compact card presentation, existing-route compatibility, cover-cache test/measurement, test/CI results and any *independently evidenced* leftover error. Do not report an unexplored old error as fixed, and do not ship to Google Play as part of this plan.