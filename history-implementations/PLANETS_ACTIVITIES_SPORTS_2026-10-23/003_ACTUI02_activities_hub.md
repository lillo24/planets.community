# ACTUI02 — make Activities a coherent discovery page

Read [001_context.md](001_context.md). Depends on merged 002; no live source is required. Implement the page in the real Flutter app, then continue the queue.

## Outcome and current evidence

Activities currently presents All/Sports/Culture chips, a separate native Tavoli entry, external-feed explanation, example-preview action, search and event cards. It reads the canonical backend but has no integrated external map. Build a clear Activities hub that accommodates events, ongoing courses and places, rather than presenting everything as an event feed. Sports receives its deeper controls in 004.

Inspect current `external_activities`, `activities_sandbox`, Browse switcher/router, Home, Settings, localization, controllers and design tokens. Reuse existing ownership and preserve the baseline tutorial. This is a focused navigation/layout pass, not a new Home redesign or a second preview app.

## Page behavior

- Retain **Projects / Activities** navigation when Activities Split Mode is enabled. Make Activities the consistent label on Home, Browse and back navigation. No additional bottom-navigation tab. OFF restores current native navigation and gates experiment routes.
- Provide the primary **All / Sports / Culture** category choice with a readable selected state and accessible touch targets. The landing view should give a concise way to enter Sports and Culture and see genuine external results; avoid simultaneous redundant carousels/chips/dropdowns for the same category.
- Under All/Culture, keep a recognizable **Tavoli culturali** entry opening the current native flow. It retains its own list/search/create/participation/map rules. Do not convert native Tavoli to imported records, mix their private/requested data into external counts, or imply external keyword filters also searched native Tavoli.
- Present compact kind choices where they help discovery: All, Courses & sessions, Events, Places to practise. Only show combinations supported by the context; Culture need not advertise an empty sports-place section. The Sports-specific treatment is finalized in 004.
- Use one clear search field with scope-accurate copy. Apply kind/category/query/discipline/date filters through the canonical server contract across all pages. Debounce/cancel obsolete reads using existing patterns; never filter only the current page.
- Keep advanced/date filters in one compact disclosure or sheet. A date filter is applicable to events/known course sessions, not a claim about an undated place. Avoid showing unsupported price, distance, skill-level or availability controls that cannot filter real data.
- Every control must work or be omitted. The Map action is introduced when 008 supplies its working route; do not ship a dead “coming soon” button or fake map in this step. Leave a clean compositional seam for the existing List/Map selector.
- Use kind-aware card metadata: an event's date; a course's season/weekly schedule; a place's discipline and location. Keep source labels understated. Do not require imported images to make the page readable; use existing icons, tokens and typographic hierarchy.
- Separate initial loading, refreshing retained data, genuine empty matches, unconfigured source, source trouble, stale records and backend read failure. Keep valid results from healthy sources visible when a different source fails after 005. Do not replace a successful empty result with examples.
- Move the fictional example action to an explicit, secondary **Preview examples** entry. It remains reachable and labelled, without competing with real discovery or suggesting a live municipal catalogue already exists.

## State and lifecycle

Retain filters and scroll when returning from details. Clear incompatible subfilters deliberately when switching categories/kinds; keep useful compatible choices. Document which state is RAM-only. Do not persist location/search history or add background fetches. No new reads when the surface is inactive, backgrounded or mode OFF. Cancel stale callbacks on state/account/readiness transitions as existing controllers require.

Preserve current valid card-open/share instrumentation and its denied production gate. Do not invent view events on widget builds, filter changes, restores or example navigation. No popularity labels, attendance/crowding indicators or native joins for external records.

## Validation and done

Render and inspect populated mixed-kind, Sports, Culture/Tavoli, empty, unconfigured, read-error and stale states with deterministic public fixtures injected only into tests/explicit demo mode. At minimum inspect Italian/English, light/dark, 320/360 dp and 2× text on the difficult states. Fix clipping, stacked redundant headings and unusable control density.

Test category/kind transitions, search across pagination, stale response fencing, detail-back restoration, off-mode route gating, native Tavoli navigation and independence of the Messages/Browse setting. Keep Settings and tutorial regression coverage. Run formatting, analysis, affected Flutter/router/controller suites and required CI. Update feature maps/progress, commit screenshots using repository evidence conventions where appropriate, and merge a focused PR. Phone review remains deferred; do not stop the queue for it.
