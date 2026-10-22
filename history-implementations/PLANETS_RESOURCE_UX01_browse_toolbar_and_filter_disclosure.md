# PLANETS RESOURCE-UX01 — Compact Scambio-Dona search toolbar and filters

**Repository:** `lillo24/planets.community`  
**Base:** current `origin/main` at execution; inspect the repository again before coding.  
**Scope:** focused Flutter/mobile UX PR. No database migration.  
**Dependency:** independent of RESOURCE-CAT01 (category support), which can follow after this PR.  
**External context:** none required; this prompt is self-contained.

## Goal

On **Scambio-Dona** (`/resources`), remove the dedicated Save search row, place the Save search action beside the keyword field and the existing filter disclosure button, and move the **Dona/Scambia** selector into the collapsible secondary filters. Preserve every existing filtering and saved-search behavior.

## Verified current implementation

Inspect these areas on fresh `main`, rather than relying exclusively on the paths below:

- `apps/mobile/lib/features/resource_listings/presentation/public_resource_listings_screen.dart`: visible `MapViewButton`; mode `SegmentedButton` above the search field; search `TextField` beside `BrowseFilterButton`; a separate `Wrap` containing `OutlinedButton.icon` for Save search; collapsed locality field.
- `apps/mobile/lib/core/widgets/browse_filter_button.dart`: disclosure button, including active-filter badge.
- `apps/mobile/lib/features/resource_saved_searches/`: Save-current-search action and saved-search restoration.
- Flutter tests: `resource_listing_flow_test.dart`, `resource_saved_search_browse_integration_test.dart`, and relevant responsive/layout tests.

## Intended layout

```text
Scambio-Dona
[List / Map control — preserve existing behavior]

[ Search resources................ ] [bookmark+] [filters]

   (Only when filters expanded:)
   Tipo annuncio   [Dona] [Scambia]
   Località         [................]

[Result cards...]
```

The precise icons and padding should follow existing theme components. This is a **single toolbar row**: the search input expands; Save search is a compact icon button immediately after the input; `BrowseFilterButton` remains at the end. Do not put Save search into another row or force a long text label into a 320px mobile toolbar. Keep sensible touch targets, tooltip and localized accessibility semantics: **Salva ricerca / Save search**. Prefer retaining `resource-save-search`, `resource-query-filter`, and `resource-toggle-filters` test keys.

The bookmark action appears only for a ready authenticated identity, as currently. If signed out, the search field naturally takes the space; do not leave an empty button slot. Preserve disabled/loading states, saved-search validation, policy acknowledgement, `_flushFilters()` before save, duplicate feedback, and no extra duplicate search RPC. The separate app-bar entry to **Ricerche salvate** stays.

## Collapsible filters

- The **Dona/Scambia** mode selector must render **inside** the `_filtersExpanded` section, before the locality field. It is hidden when collapsed, with no top-level replacement.
- The keyword search and disclosure button remain visible whether filters are open or closed.
- Reuse the current mode semantics: both selected = no mode filter (`null`); one selected = that mode; never an empty effective selection. A mode change still applies immediately, while query/locality retain existing debounce and submit behavior.
- **Disclosure must not apply, clear, or reset filters.** Collapsing hides controls but retains their chosen values and results; reopening shows the selection and locality accurately, including after opening a saved search.
- Update `BrowseFilterButton.hasActiveFilters` for Resource Browse to include **an effective mode filter OR a nonempty locality**. Do not count keyword text toward the hidden-filter badge: keyword remains visible in the main row.
- Keep public signed-out discovery, pagination, list/map navigation, account changes, loading/retained results, and creating a listing unchanged.

## Implementation boundaries

This PR is **layout-only**. Do not introduce resource categories here, change saved-search or listing contracts, alter SQL, or redesign the shared filter button across other screens. A separate RESOURCE-CAT01 prompt adds the category dimension end-to-end; its control will later join this disclosure panel and contribute to the badge.

Use existing EN/IT localization; add no hard-coded production strings. Follow repository conventions for Flutter formatting, responsive sizing, focus handling, accessible icon controls and localization generation.

## Validation and acceptance

Update/add focused Flutter tests to assert:

1. At initial load, keyword + (authenticated) Save search + disclosure occupy the same row; mode and locality are hidden; no old Save search row remains.
2. Expanding reveals mode and locality; collapsing hides both without clearing them or making another backend request.
3. Mode-only filters show the active-filters badge while collapsed; removing effective mode/locality hides it.
4. Dona-only, Scambia-only, and both semantics still yield the existing backend mode values, and saved-search Open restores the hidden selection correctly.
5. Signed-out browse has no Save search button; signed-in save retains pending-input validation, success/duplicate/error/loading behavior, and no duplicate network application.
6. No RenderFlex overflow at narrow widths (including 320 logical pixels), large text scale, IT/EN, or with the keyboard active. Tooltip/semantics remain discoverable.
7. Map entry, list pagination, empty/loading/errors, and existing resource/saved-search tests still pass.

Run Dart format, Flutter analyze, relevant tests plus the repository-standard feasible validation; report what was actually run. Update the resource-listings README to match the revised disclosure behavior.

## Delivery

Create a focused branch/PR from current `main` (suggested `codex/resource-ux01-search-filter-toolbar`). Do not commit app implementation changes directly to `main` or merge the PR without approval. Report changed files, screenshots/widget-layout evidence where practical, validation, and any blockers. Do not claim physical-device testing unless performed.
