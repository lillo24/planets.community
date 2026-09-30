# PLANETS QA-02 — Discovery, Scambio Detail, and Skill-Selector Polish

**Task type:** Mobile/UI polish + narrow Proposal-search backend support  
**Repository:** `lillo24/planets.community`

## Base

Implement this **after QA-01** and branch from the final head of:

```text
codex/qa01-navigation-public-profile-back
```

Preferred branch:

```text
codex/qa02-discovery-profile-polish
```

Open a draft PR against the final QA-01 branch.

Archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_QA02_discovery_profile_polish.md
```

---

# External UI reference

Use as interaction inspiration:

```text
repository:
lillo24/general_modular_components

files:
React-components/fancy-multi-select/FancyMultiSelect.jsx
React-components/fancy-multi-select/fancyMultiSelect.css
```

Relevant ideas:

```text
compact closed trigger
selected values as badges/tags
bounded scrollable menu
search inside menu
selected badges removable directly
clear action
controlled parent-owned selection
```

Do not port React/CSS literally. Build native Flutter/Material components using PLANETS tokens.

The user explicitly does **not** want checkbox-list visuals for skills.

If Codex cannot access that external repo, the interaction contract above is sufficient.

---

# Manual-QA polish/issues to address

1. `Set up your profile` → Skills is always fully expanded and consumes too much vertical space.
2. Proposal Browse has no free-text search.
3. Proposal Skills filter should use the same compact tag/multi-select interaction language.
4. Scambio search requires an explicit Search button instead of automatic debounced search.
5. Scambio cards should use metadata more intelligently:
   - top-right: publication age (`30m`, `3h`, `3d`);
   - bottom-left: people interested;
   - bottom-right: location;
   - `Scambia` should no longer occupy top-right.
6. Scambio detail is visually bland.
7. Scambio detail can show ugly duplicate location:
   ```text
   Public Location
   Trento
   Trento, IT
   ```
8. Signed-out Scambio detail has no visible request CTA, making the exchange workflow look absent.

Do not change the existing Resource request/agreement lifecycle.

---

# 1. Reusable Flutter multi-select/tag component

Create a reusable controlled multi-select component/family that supports:

```text
label
placeholder
categories/options
selected IDs
search
toggle
clear
disabled state
selected-summary tags
optional Apply/Done
```

Use Flutter-native widgets and PLANETS theme tokens.

Avoid hard-wiring it only to Profile or Proposal Browse if a clean reusable abstraction is feasible.

---

# 2. Compact closed state

When closed, the component should occupy little vertical space.

Examples:

```text
Skills
[Gardening] [Photography] [+3]   ▾
```

or:

```text
[ Select skills · 5 selected ▾ ]
```

Do not render every category on the parent page while closed.

---

# 3. Selected tags

Selected skills:

- render as compact bordered/filled tags;
- are directly removable/toggleable;
- wrap safely;
- have clear semantics;
- do not use checkbox-list visuals.

Selection must not rely on color alone.

---

# 4. Bounded open selector

Open into a bounded phone-friendly surface:

```text
bottom sheet
or anchored menu/dialog if it behaves better
```

The surface should contain:

```text
Search skills
category headings
skill chips/buttons
selected state
Clear
Done/Apply when appropriate
```

Internal list scrolls; the parent page does not expand to the whole catalog.

---

# 5. Profile setup/edit Skills

Replace the current permanently expanded `CheckboxListTile` catalog in `ProfileEditScreen`.

Profile behavior:

- local form state updates immediately;
- no network call per skill tap;
- existing selected skills initialize selected tags;
- tapping a selected tag removes it;
- Save still sends the exact complete selected ID set atomically through the existing profile update RPC;
- catalog/category ordering remains canonical.

Use the same component in initial setup and later profile edit.

---

# 6. Proposal Browse Skills filter

Replace current checkbox-heavy `SkillFilter` presentation with the same visual language.

Browse may keep staged selection and explicit `Apply` to avoid a network request on every chip tap.

Expected:

```text
compact trigger + selected summary
→ open bounded selector
→ searchable categories
→ chip/button toggles
→ Clear
→ Apply
```

Preserve the important current behavior: opening the filter must **not** summon the keyboard until the user explicitly taps the search field.

---

# 7. Proposal free-text search must be backend-backed

Do not filter only the currently loaded Flutter page.

Current Proposal discovery supports:

```text
cursor
locality
skill IDs
```

Add optional:

```text
p_query text default null
```

to the canonical public Proposal listing behavior through a **forward migration**.

Also extend:

```text
list_own_pending_requested_proposals
```

with the same query, so the promoted Requested section obeys the same active search.

Do not show promoted requested cards that fail the query while ordinary results are filtered.

---

# 8. Proposal query semantics

Normalize:

```text
trim
blank → null/no filter
max 120 chars
```

Oversized query → `22023`.

Use literal case-insensitive substring search over:

```text
title
summary
description
```

Prefer `position(normalized_query in lower(field)) > 0` or equivalent so `%` and `_` are literal text, not wildcard operators.

No FTS/AI/taxonomy in this QA slice.

---

# 9. Proposal RPC migration safety

Inspect current dependencies/signatures before changing the function.

Because input signatures cannot simply change via ordinary `CREATE OR REPLACE FUNCTION`, use a safe forward migration.

Requirements:

- never edit historical migrations;
- preserve current security/search path/grants;
- preserve cursor/locality/skill behavior;
- preserve anonymous public listing access;
- preserve authenticated requested-list identity checks;
- avoid ambiguous overloads in PostgREST;
- update function comments/tests/verifiers;
- regenerate generated DB types.

Existing web callers should continue working by omitting default `p_query`.

---

# 10. Proposal mobile state

Add canonical `query` to Proposal browse/controller state.

Include it in:

```text
revision checks
pagination
requested refresh
filter state
```

Stale results from older queries must never overwrite current query state.

---

# 11. Proposal search UI

Near top of Proposal Browse:

```text
Proposal/Tavolo switcher
Search projects
Location
Skills
results
```

No explicit Search button.

Localized placeholder such as `Search projects`.

---

# 12. Proposal debounce

Search automatically after ~300–400 ms.

Requirements:

- cancel pending debounce on each new keystroke;
- cancel on dispose;
- clear query reloads unfiltered results;
- Enter/submit flushes immediately;
- stale response cannot win;
- pagination keeps same query;
- do not request on every keystroke.

---

# 13. Scambio debounced filters

Current Scambio has query + locality + Search button.

Remove dedicated Search button.

Behavior:

```text
query → debounce ~300–400ms
locality → same debounce, or focus-loss/submit only if implementation proves cleaner
mode segmented button → immediate
Enter → flush pending debounce immediately
```

Prefer query/locality consistency.

Typing must remain enabled during loading.

---

# 14. Scambio refresh polish

Avoid making the page look broken during every debounced request.

Where current controller architecture allows:

- retain existing results during refresh;
- show subtle progress;
- never replace the entire page with a full-screen loader for every character;
- stale response cannot replace newer state.

No speculative local filtering.

---

# 15. Scambio card redesign

Target top row:

```text
Listing title                         3h
```

Top-right becomes relative publication age.

Examples:

```text
now
30m
3h
3d
```

For older entries, use a localized compact date policy.

Do not run one timer per card.

---

# 16. Mode is secondary metadata

Do not remove the distinction between:

```text
Dona
Scambia
```

because All mode mixes both.

Move it to a subtler secondary position under/near title or description.

Do not keep it top-right.

---

# 17. Bottom card metadata

Use approximately:

```text
[people] 3 interested            [location] Trento
```

Requirements:

```text
interest → bottom-left
location → bottom-right
```

Support narrow layout/wrap without overflow.

Do not repeat publication date lower down.

---

# 18. Relative-age formatter

Add tested formatter with roughly:

```text
<1 min → now
<60 min → Xm
<24h → Xh
<7d → Xd
otherwise → localized short date
```

Exact localization wording may adapt.

Use same formatter on card and detail.

---

# 19. Scambio detail hierarchy

Current detail is correct but too plain.

Improve hierarchy approximately:

```text
[Dona/Scambia]
Title
3h · Listed by Alice

Description section

Location
Trento

3 people interested

Primary request/status action
```

Use cards/sections/typography sparingly.

Do not make it visually noisy.

---

# 20. Fix duplicate location

Current presentation can render:

```text
Public Location
Trento
Trento, IT
```

Change to one concise canonical display.

Rules:

1. title is localized `Location`, not technical `Public Location`;
2. prefer non-empty `publicLocationLabel`;
3. structured locality/admin/country are fallback only when they add information;
4. never render a second line that is effectively duplicate;
5. never expose exact/private meeting or handoff location.

Expected:

```text
Location
Trento
```

or:

```text
Location
Trento · Povo
```

---

# 21. Signed-out Scambio request CTA

When signed out, detail currently renders no request controls.

Show a clear primary CTA:

```text
Request this resource
```

Tap:

```text
→ /auth?returnTo=/resources/:listingId
```

After sign-in/profile readiness, return to the same listing.

Do not create a request before authentication.

---

# 22. Signed-in request states remain canonical

Preserve:

```text
no active request
→ Request

pending
→ status + Withdraw + View

accepted/open
→ Accepted + View

historical closed accepted
→ may request again
```

Make this visually prominent enough that the detail does not look like a static mock.

Owner never sees self-request CTA.

---

# 23. Explain where exchange terms happen

Do not show Give/Lend agreement controls before the request is accepted.

Add concise helper copy near request CTA/status, e.g.:

```text
After the owner accepts your request, you can chat and agree whether the item is given or lent and what is exchanged.
```

Keep actual lifecycle:

```text
Request
→ owner accepts
→ Resource conversation
→ Agreement card
→ propose/counter-propose Give/Lend terms
→ handoff/return
```

Do not duplicate Agreement controls on public listing detail.

---

# 24. Accessibility/localization

Cover:

- selected/unselected skill tags;
- removable tags;
- bounded selector focus order;
- search semantics;
- selection count;
- relative age semantics;
- card metadata reading order;
- Location dedup;
- signed-out Request CTA;
- high text scale;
- no color-only state.

No hard-coded production English.

---

# 25. Tests — reusable selector/Profile

Cover:

```text
compact closed state
selected tags
bounded open selector
category headings
search filtering
add/remove
clear
disabled
large text
no CheckboxListTile UI
```

Profile:

```text
existing IDs initialize
tap option selects
tap selected tag removes
Save submits exact set
no network call per selection
```

---

# 26. Tests — Browse skill filter

Cover:

```text
open does not autofocus text input
search
stage selection
Clear
Apply
selected summary
```

---

# 27. Tests — Proposal query DB

Cover:

```text
null/blank
title
summary
description
case-insensitive
literal % / _
length validation
query + locality
query + skills
query pagination
anonymous public access
requested projection parity
cross-identity denial
```

---

# 28. Tests — debouncing

Proposal and Scambio:

```text
rapid typing → only final debounced load
clear → reset
submit → immediate flush
dispose → no delayed call
old response ignored
```

Scambio also covers mode/locality behavior.

---

# 29. Tests — Scambio card/detail

Card:

- relative age top-right;
- mode secondary;
- interest bottom-left;
- location bottom-right;
- narrow/long text;
- age thresholds.

Detail:

- no `Trento` + `Trento, IT` duplication;
- `Location` label;
- relative age;
- signed-out Request CTA;
- exact Auth returnTo;
- signed-in request state;
- owner no self-request;
- flow helper;
- owner Edit/Loan Schedule preserved.

---

# 30. DB validation

Because this slice changes Proposal RPCs:

```text
npm run db:reset
npm run db:lint
npm run db:advisors
npm run db:test
npm run db:types:check
```

Run focused Proposal/participation-browse verifiers.

The current stack has inherited DB lint/test failures discovered during QA. Clearly distinguish:

```text
new QA-02 regression
vs inherited existing failure
```

Do not repair unrelated old DB issues in this PR merely to make the global suite green.

---

# 31. App validation

Run:

```text
npm run check:mobile
flutter build apk --debug
npm run check:web
npm run check:site
git diff --check
```

Attempt hosted Validation once; report account/billing non-execution honestly.

---

# 32. Manual Android QA

Verify:

1. Profile Skills compact on load.
2. Add/remove multiple skill tags.
3. Save/reopen retains exact selection.
4. Proposal search updates automatically.
5. Rapid query changes do not show stale results.
6. Skills selector does not auto-open keyboard.
7. Scambio query/locality no longer need Search button.
8. Scambio card layout matches intended metadata positions.
9. Resource detail shows one location.
10. Signed out: Request CTA visible.
11. CTA → Auth → return to same Resource.
12. Signed in: request lifecycle still works.

---

# Profile photo boundary

Do **not** implement actual photo upload in QA-02.

The current Profile schema has no avatar/photo field and no Storage/visibility contract.

A real implementation needs a separate decision about:

```text
who can view it
bucket/object access
replace/delete cleanup
public profile delivery
```

Do not fake a local-only photo upload.

---

# Location-map boundary

Do not implement the discussed city autocomplete/map/radius/device-location feature here.

That requires separate provider/API/cost/privacy/radius design.

---

# Non-goals

Do not implement:

- profile photo storage/upload;
- map/radius/geocoding;
- semantic/AI Proposal search;
- global skill taxonomy redesign;
- Resource agreement changes;
- demo seed changes;
- QA-01 navigation changes.

---

# Acceptance criteria

- [ ] based on completed QA-01;
- [ ] prompt archived unchanged;
- [ ] reusable tag multi-select exists;
- [ ] Profile Skills compact/no checkbox list;
- [ ] selected tags removable;
- [ ] Proposal filter uses same interaction language;
- [ ] Proposal Browse has backend-backed free-text query;
- [ ] requested Proposal section follows query;
- [ ] Proposal search debounced;
- [ ] Scambio Search button removed;
- [ ] Scambio filters update automatically;
- [ ] card top-right is relative age;
- [ ] interest bottom-left;
- [ ] location bottom-right;
- [ ] mode remains visible secondarily;
- [ ] Scambio detail hierarchy improved;
- [ ] duplicate location fixed;
- [ ] signed-out Resource Request CTA exists;
- [ ] CTA preserves exact returnTo;
- [ ] Agreement controls remain post-acceptance;
- [ ] accessibility/localization complete;
- [ ] DB types/tests updated for query RPC;
- [ ] focused/mobile tests pass;
- [ ] debug APK passes;
- [ ] photo upload explicitly deferred;
- [ ] map/radius explicitly deferred;
- [ ] no PR merged.

# Completion report

Return:

1. stack/base status;
2. QA-02 branch/base/PR;
3. changed files;
4. reusable selector design;
5. FancyMultiSelect concepts adopted;
6. Profile skill UX;
7. Proposal skill filter UX;
8. Proposal query migration;
9. query semantics;
10. requested-section parity;
11. Proposal debounce;
12. Scambio debounce;
13. Scambio card layout;
14. relative-time formatter;
15. Scambio detail hierarchy;
16. location dedup;
17. signed-out Request CTA;
18. Auth returnTo;
19. exchange-flow helper;
20. owner regression;
21. accessibility/localization;
22. selector/search/card/detail tests;
23. DB validation;
24. mobile/web/site validation;
25. Android QA;
26. inherited blockers;
27. photo deferred boundary;
28. map deferred boundary;
29. commit/PR reference.

Do not merge any PR.
