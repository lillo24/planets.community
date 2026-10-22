# PLANETS RESOURCE-CAT01 — Scambio-Dona categories, end to end

**Repository:** `lillo24/planets.community`  
**Base:** latest `origin/main` containing RESOURCE-UX01, if that layout PR has been merged. Reinspect the actual code first.  
**Scope:** resource listing domain + Supabase API + Flutter browse/editor + saved searches/matching + list/map consistency. One cohesive feature PR, separate from RESOURCE-UX01.  
**External context:** none required. The pertinent product decisions and open questions are reproduced here.

## Objective and distinction

Provide a functional **Categoria / Category** filter for Scambio-Dona, inside its collapsible filters alongside Dona/Scambia and locality. Category must be a real stored attribute of listings so that filtering works across pages, saved searches and maps. Avoid a cosmetic dropdown that searches only already-loaded cards or guesses categories from descriptions.

The product design document currently considers a global resource taxonomy future work and separately leaves *permitted / restricted goods and services* policy unresolved. **This feature is a lightweight organizational classification, not a safety/eligibility whitelist.** Keep existing Community Rules, moderation, and listing-mode/loan semantics unchanged; do not imply a category label authorizes an item. Do not attempt Project-needs-to-listing semantic matching or a universal ontology.

## Initial classification contract

Start with one selected category per listing, using stable, nonlocalized slugs. An intentionally small first version:

| Slug | Italiano | English |
| --- | --- | --- |
| `tools_diy` | Attrezzi e fai-da-te | Tools & DIY |
| `garden_outdoors` | Giardinaggio ed esterni | Garden & Outdoors |
| `home_furniture` | Casa e arredamento | Home & Furniture |
| `electronics` | Elettronica | Electronics |
| `clothing_accessories` | Abbigliamento e accessori | Clothing & Accessories |
| `books_learning` | Libri e materiali didattici | Books & Learning |
| `sports_hobbies` | Sport, hobby e giochi | Sports, Hobbies & Games |
| `materials` | Materiali e forniture | Materials & Supplies |
| `other` | Altro | Other |

`Tutte / All` is a **filter choice**, not a stored listing category. Keep categories separate from `listing_mode` (`donate`, `exchange`). Do not add specific categories for food, animals, medicines or regulated services while those policies remain undecided. These broad labels neither approve nor prohibit an item: current rules still govern publication. A stable enum/contract or repository-consistent catalog is preferable to editable free text. No hierarchical subcategories, multi-tagging, dynamic taxonomy admin, or auto-classification in this slice.

## Legacy and backward compatibility

- Add nullable `category_slug` to existing `resource_listings`. **Do not automatically classify or backfill** existing listings as `other` or infer categories from text.
- Public unfiltered `Tutte / All` continues to show legacy `NULL` listings; a specific category filter matches only explicitly assigned listings. If displaying a legacy null, omit category or show a neutral localized *not categorized*, never *Altro*.
- Owner drafts may have no category. The updated mobile app should prompt for a category before **new publication**, but editing an already-published legacy listing without a category must not break other permitted edits. Preserve existing mobile build compatibility: backend must continue accepting legitimate old-client requests that omit category.
- Category changes to existing published listings must follow current editor authorization and lifecycle rules. Closed listings remain terminal. Do not modify listing IDs, cover retry behavior, auth, publication timestamps, or request/loan records.

## Source areas to inspect

Verified on main during plan preparation; confirm current definitions before coding:

- `apps/mobile/lib/features/resource_listings/{domain/resource_listing_models.dart,data/resource_listing_gateway.dart,application/resource_listing_controllers.dart,presentation/public_resource_listings_screen.dart,presentation/resource_listing_editor_screen.dart,presentation/resource_listing_widgets.dart}`
- `apps/mobile/lib/features/resource_saved_searches/` (models, gateway, controller, editor, list/Open action, tests)
- `apps/mobile/lib/features/geographic_discovery/` (list/map filter snapshot and `resource_mode`, keyword, locality in geographic query)
- `supabase/migrations/20260914134222_scambio_dona_listing_domain_foundation.sql` plus **all later migrations** that replace Resource RPCs or add covers/locations/requests
- `supabase/migrations/20260925112156_personal_saved_resource_search_domain.sql`, `20260925142259_saved_search_new_listing_match_projection.sql`, and later saved-search notification code
- `supabase/migrations/20261009070032_map04_geographic_discovery.sql`, latest deployed function definitions / generated types, and corresponding SQL/Flutter tests.

Do not assume the earliest migration's RPC signatures remain authoritative. The app uses RPC-only Resource access, and existing released clients and Supabase functions must keep working. Inspect dependency graphs before modifying return types or overloaded functions; prefer compatible extension or clearly versioned RPCs with documented wrappers. Never replace an authenticated/security-definer contract with client-side direct table access. Preserve grants, RLS, security-definer search paths, identity checks and pagination.

## Resource listing persistence and API

1. Add and validate `category_slug` in the server's canonical listing storage; allow `NULL` for backward compatibility, and reject unsupported nonnull slugs. Update create/update draft content, public list/detail, owner list/detail, and related parsers/type definitions. Do not break published-listing reads by old clients.
2. Extend public list filtering with an optional category criterion combined with existing mode, locality and literal keyword predicates. Preserve published-only visibility, active-interest-count sanitization, keyset cursor ordering, paging, ownership privacy, blocked-owner behavior and zero-result behavior. Do not filter a fetched page in Flutter; enforce before database pagination.
3. Handle PostgreSQL `RETURNS TABLE` changes, dependent functions, RPC signature/grants and PostgREST ambiguity safely. If adding versioned endpoints, keep the old endpoints and release-compatible behavior intact; document which the new mobile client calls. Update generated Supabase/Web DB types as the repository requires.
4. Add any focused index only if query plans or repository conventions justify it. Avoid expensive table scans or new billing/services.

## Flutter listing editor and discoverability

- Add a localized **Categoria** single-select to create/edit listings, with a clear unset state for drafts. New publication from the updated app requires explicit category choice. Display the chosen category unobtrusively on public listing cards/details and owner listings where appropriate; don't invent one for legacy data.
- In `/resources`, put a **Categoria / Category** selector inside the `_filtersExpanded` panel, between the Dona/Scambia selector and locality (after RESOURCE-UX01). Default is `Tutte / All`; selecting one category applies it through the canonical provider + backend; clearing returns to All.
- Add category to the canonical Resource filter tuple/state, normalized input, filter synchronization, retry/revision checks, request deduplication, `resultsMatchFilters`, pagination keys and reset paths. Preserve debounce/submit/mode behavior and old saved-search Open semantics.
- A nondefault category adds to the filter-disclosure active badge even when collapsed. The always-visible query alone must not trigger the hidden-filter badge. Hiding/reopening filters must preserve category, mode and locality.
- Keep signed-out discovery public, and do not alter app navigation or the existing Map/List selector.

## Saved searches and matching notifications

- A saved search must persist the **entire visible filter set**: keyword, mode, locality **and category**. Category alone counts as a valid saved search. Extend create/update/list/get, parser, editor, summary, Open restore, duplicate identity/unique-index logic and input validation. Existing saved searches retain `category = NULL` and their current meaning; do not break personal data boundaries.
- Update the backend saved-search-to-new-listing matcher (`private.resource_listing_matches_saved_search_filters` and its call sites / projection). A category-restricted saved search must match only explicitly categorized new listings of that category, with the existing keyword, mode and locality conjunction. Avoid spurious/duplicate notifications, changing pre-existing notification opt-in/visibility, or triggering old matches from an unsafe backfill.
- Preserve category through List → Map → List. Map's geographic query must apply the category **only to Resource items**, including in mixed-family `All` mode; Progetti/Tavoli should not be dropped because of a Resource category. Extend the geographic query validator and server candidate filtering, with correct radius/bounds/pagination, only as required. Verify the behavior is consistent for map and list, not a local post-filter.
- Existing Project resource-needs matching remains keyword/geography/mode-based unless separately specified. A category is not a canonical Project resource skill/need taxonomy.

## Security, migration and tests

Use additive, deployable SQL migrations. Explicitly assess mobile/backend rollout order and backward compatibility with older signed APKs; **do not deploy** or alter hosted configuration without authorization. Regenerate checked-in types and keep README/docs accurate.

Test at least:

1. Category validation on draft/edit, null legacy compatibility, unauthorized writes/read visibility, old RPC clients, and unknown category rejection.
2. Backend category + mode + locality + query combinations, case/slug normalization, stable published keyset pagination and no category-based leakage.
3. Flutter All/category-only/combined filters, no reset on disclosure, mode independence, provider sync, stale fetch rejection, empty/error/loading, signed-out use, new-publish validation and legacy edits.
4. Saved searches: category-only save, edit, duplicate behavior, Open restores UI/results, account switch, existing null-category definitions and backend match/no-match notification projection.
5. List/Map/All family transitions, geography radius/bounds, category applied only to Resource family, other families unchanged.
6. EN/IT localization, semantics, narrow-screen layout (320 logical pixels), larger text, and no filter overflow.

Run SQL structure/access/matching tests, local Resource verification scripts, Flutter analyze/format/tests, generated-type validation, and the project's feasible standard regressions. Report any unrun checks and reasons; never claim a real-device/hosted deploy pass without running it.

## Delivery and stop conditions

Create a separate PR from current `main` after RESOURCE-UX01 is merged (suggested `codex/resource-cat01-categories`). The founder approved **category classification/filtering**, not changes to the legal catalog of permitted goods or to loan/barter policy. If implementation requires deciding whether risky categories of goods may be offered, do not decide that policy: keep existing rules and explain the blocker instead. Do not widen scope to Project matching, taxonomy administration, AI tagging, payments, or moderation redesign.

Provide a concise completion report with migration/API backward-compatibility strategy, exact slugs/labels, changed files, listing/editor/filter/save/map/notification evidence, commands/results, any remaining policy question, and PR URL. Do not commit application changes directly to `main` or merge the PR without approval.
