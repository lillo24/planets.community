# PLANETS 04B2 — Tavoli Mobile/Web Experience

**Roadmap area:** PLANETS 04B — Tavoli / Recurring Activities  
**Task type:** Second and final scoped portion of 04B  
**Repository:** `lillo24/planets.community`  
**Required base:** latest merged `main`  
**Known `main` before this prompt is archived:** `dba2f2ab288050ae2d900625e89f10d5a247c03c`

## Objective

Expose the already-implemented Tavoli recurring-activity domain through functional mobile and public-web experiences.

A **Tavolo** is an ongoing recurring meeting/group, separate from a one-time Proposal. Examples:

- a philosophy discussion every Wednesday;
- a monthly cultural meetup;
- a recurring neighborhood group.

After this task:

- Browse clearly separates **Proposals** and **Tavoli** into two distinct lists;
- both lists remain under the existing mobile **Browse** bottom-navigation destination;
- anyone can browse active Tavoli and open details without signing in;
- authenticated users with complete profiles can create drafts, edit, publish, pause, resume, end, and review their own Tavoli;
- weekly and monthly schedule forms use the canonical 04B1 rules;
- mobile and web render recurrence in the Tavolo’s local timezone;
- public list pagination preserves one explicit reference-time snapshot across all pages;
- exact-location privacy remains identical to the canonical backend contract;
- the website receives read-only `/tavoli` and `/tavoli/[id]` discovery;
- no participation, chat, notifications, material resources, occurrence exceptions, or recurrence expansion is introduced.

This is functional product UI, not final visual design.

---

## Inspect before changing anything

Work from the latest merged `main`, including merged PR #11 and the post-merge roadmap correction.

At minimum read:

1. root `AGENTS.md`;
2. `docs/development/codex-tooling.md`;
3. `docs/architecture/core-stack.md`;
4. `docs/architecture/system-design.md`;
5. `docs/architecture/product-decisions.md`;
6. `docs/development/database.md`;
7. `docs/implementation/roadmap.md`;
8. `apps/mobile/README.md`;
9. the complete current mobile router and `AppNavigationShell`;
10. the complete mobile Proposals feature, tests, timezone helpers, filters, editor, and owner-management patterns;
11. the complete 04B1 migration, pgTAP tests, integration harness, and generated database types;
12. current Next.js public proposal routes/components/models/server boundary and route tests;
13. `apps/web/AGENTS.md` and version-matched bundled Next.js documentation;
14. `.github/workflows/validation.yml`.

Important current facts:

- `StatefulShellRoute.indexedStack` already owns the stable mobile bottom navigation:
  - Profile;
  - Browse;
  - Home.
- `/proposals` and its detail/management routes already belong to the Browse branch.
- session identity changes rebuild retained shell stacks and invalidate owner-specific state.
- one-time Proposal navigation, filters, editor, privacy, and lifecycle are implemented and must not regress.
- 04B1 is merged and canonical.
- Tavoli are physically separate from one-time Proposals.
- 04B1 intentionally added no Tavoli client routes or screens.
- public Tavoli list pagination requires one explicit `p_reference_time` snapshot.
- public Tavoli discovery supports locality filtering, not skill filtering.
- Tavoli do not use the Proposal skill taxonomy.
- current Tavoli recurrence is weekly or monthly only.
- no database migration should be needed for 04B2.

Do not edit the merged 04B1 migration. If a genuine backend defect blocks correct UI, stop and report it. Any necessary database correction must be a new additive migration and must not be hidden inside client work.

---

# Codex skills and framework guidance

Reuse the already-installed project tooling:

- Dart/Flutter plugin;
- Supabase guidance;
- Supabase/Postgres best-practices skill;
- Vercel React best-practices skill;
- shadcn skill;
- bundled version-matched Next.js docs.

Do not reinstall redundant skills.

Do not install:

- a new navigation framework;
- a recurrence/RRULE library;
- a new state-management library;
- the full Vercel plugin;
- a generic UI framework for Flutter.

Repository behavior and this plan remain authoritative.

---

# User-facing Browse structure

## Distinct lists, one Browse destination

Proposals and Tavoli must remain conceptually and visually distinct.

Do not merge them into one mixed chronological feed.

Mobile Browse should provide a compact, obvious selector between:

```text
Proposals | Tavoli
```

A route-aware Material 3 segmented control, tabs, or an equally clear restrained pattern is acceptable.

Required behavior:

- existing `/proposals` remains the one-time Proposal list;
- add a stable public Tavoli list route, preferably `/tavoli`;
- both route families belong to the existing **Browse** shell branch;
- the Browse item in the bottom navigation remains selected for both;
- do not create a fourth bottom-navigation destination;
- do not rename/break existing Proposal URLs;
- direct entry to `/tavoli` or `/tavoli/:id` selects Browse correctly;
- switching between the two lists does not reset authentication or corrupt retained owner forms;
- Proposal filters, pagination, and navigation keep working.

Prefer a small shared `BrowseTypeSwitcher`/equivalent used by both public list roots rather than duplicating navigation logic.

Exact route integration is Codex-owned. Follow the installed `go_router` version. Do not rewrite the stable shell unless current code proves that is necessary.

## Mobile route family

A reasonable route family is:

```text
/tavoli
/tavoli/:id
/tavoli/mine
/tavoli/create
/tavoli/:id/edit
```

Keep static paths such as `mine` and `create` safe from `:id` matching.

Auth screens stay outside the bottom-navigation shell.

Home and both Browse lists remain public-first.

---

# Tavoli terminology and presentation

Use **Tavoli** as the product term in visible UI, with concise explanatory copy such as “recurring activities” where needed.

All Flutter-visible text must use generated localization.

Do not expose internal table/function names to users.

## Card

An active public Tavolo card should show only compact useful information supported by the list API:

- title;
- short summary;
- optional topic;
- rough public location;
- next meeting date/time;
- event timezone where useful.

The list API does not currently return recurrence type. Do not add a database migration solely to place “Weekly” or “Monthly” on cards.

The fact that the item appears in the Tavoli list already communicates that it recurs.

Do not show exact meeting details on cards, even when public.

Do not show participant counts before plan 05.

## Public detail

A public Tavolo detail should show:

- title;
- summary;
- full description;
- optional topic;
- sanitized creator display name if returned;
- lifecycle presentation status;
- recurrence summary;
- duration;
- event timezone;
- rough location;
- exact meeting text only when returned as public;
- otherwise the localized restricted message:
  - **“Exact location available after joining.”**
- a bounded list of upcoming meetings for active published Tavoli.

For paused Tavoli:

- show a clear Paused state;
- do not show an active next-meeting claim;
- explain that meetings are temporarily paused without inventing a resume date.

For ended Tavoli:

- show a clear Ended/Historical state;
- do not show active upcoming meetings.

Drafts are never public.

Do not add a functional Join button in 04B2.

---

# Public Tavoli pagination snapshot

This is a correctness requirement, not an implementation detail.

The 04B1 public list is ordered by a **derived next occurrence** and requires:

```text
p_reference_time
p_cursor_next_starts_at
p_cursor_id
```

## Mobile

On a fresh/reset list load:

1. capture one UTC reference time from an injectable clock;
2. call the first list page with that snapshot;
3. retain the same snapshot in list state;
4. reuse it for every Load More cursor request.

Create a new snapshot only when starting a new result set, such as:

- manual refresh;
- retry after replacing the list;
- changing locality;
- explicitly resetting filters.

Switching tabs and returning to an existing retained list should not silently change the snapshot.

## Web

The first `/tavoli` request should establish one server-side UTC snapshot.

Encode that snapshot together with the last row’s:

- `next_starts_at`;
- Tavolo ID

inside the next-page cursor, or preserve it through an equally opaque and validated URL contract.

Every later page must reuse the same snapshot.

Do not default later pages to a new `Date.now()` value.

Strictly validate cursor shape and timestamp/UUID values. Invalid cursors should fail safely or restart the first page consistently without exposing backend errors.

Locality should remain composable with the cursor.

---

# Mobile feature architecture

Add a restrained feature boundary, likely:

```text
apps/mobile/lib/features/tavoli/
```

User-facing feature naming may be Tavoli; internal domain classes should remain clear, such as `RecurringActivity`.

Use the existing feature structure:

- `domain/`;
- `data/`;
- `application/`;
- `presentation/`;
- focused README.

Do not copy the Proposal feature wholesale.

Extract a shared component/helper only when it is genuinely common, for example:

- safe rough/exact location presentation;
- named-timezone formatting;
- tiny activity-type switcher.

Do not create a polymorphic “everything activity” abstraction.

---

# Mobile public list

Implement a signed-out-accessible Tavoli list.

Required states:

- initial loading;
- pull-to-refresh;
- empty;
- safe retryable failure;
- loaded;
- loading more;
- non-destructive load-more failure.

Support:

- locality filter;
- deterministic pagination with retained snapshot;
- clickable Tavolo cards;
- link/action to **My Tavoli**;
- create action for complete authenticated profiles.

Do not add a skill filter.

Do not add free-text topic search without backend support.

The current Proposal skill multi-select and Proposal list must remain unchanged.

---

# Mobile public detail

Load through `get_public_recurring_activity`.

Use an injectable reference time for deterministic tests.

Render at most a small bounded set of upcoming meetings, preferably the backend default/limit of 5.

Date/time display must:

- use the Tavolo’s `event_timezone`;
- use existing timezone infrastructure where possible;
- preserve local wall-clock meaning;
- never accidentally render only in the device timezone;
- handle `UTC` consistently with current Proposal behavior;
- fail safely on malformed payloads.

The detail route must support signed-out access.

Back navigation returns to the Tavoli list when reached from it.

The Browse bottom bar remains visible because Tavoli belong to that shell branch.

---

# Mobile owner management

## My Tavoli

Provide an identity-bound owner surface using the canonical owner RPCs.

Show own Tavoli across:

- draft;
- published;
- paused;
- ended.

Cards/rows should show enough to distinguish:

- lifecycle;
- title or safe “Untitled draft” fallback;
- current/pending schedule summary where present;
- rough location where present.

Actions:

### Draft

- edit;
- publish when valid.

### Published

- edit;
- pause;
- end.

### Paused

- edit;
- resume;
- end.

### Ended

- read-only historical view;
- no resume;
- no edit.

Use a confirmation dialog for terminal End.

Do not implement delete.

Do not implement duplicate/template creation.

After commands, refresh affected public/detail/owner state without leaking stale rows between accounts.

## Identity and async race safety

Follow the current Proposal and Profile patterns.

Every owner call must use the identity for which the screen/form was rendered.

Required:

- stale form after account switch cannot mutate the new account;
- late async reads from a previous account cannot repopulate owner state;
- session change clears identity-bound Tavoli controllers/forms;
- retained shell stacks never expose the previous account’s private Tavoli;
- database expected-identity checks remain the final authority.

---

# Mobile Tavolo editor

Support create and edit.

## Fields

Functional form:

- title;
- short summary;
- full description;
- optional topic;
- recurrence type:
  - weekly;
  - monthly;
- weekly weekday, when weekly;
- monthly day 1–28, when monthly;
- local meeting start time;
- duration, 15–1440 minutes;
- IANA event timezone;
- schedule effective-from local date;
- country code;
- locality;
- optional administrative area;
- public rough-location label;
- exact meeting text;
- exact-location visibility:
  - public;
  - participants.

No map picker.

No skills.

No occurrence exceptions.

No multiple weekdays.

## Draft behavior

Drafts may be incomplete.

Provide distinct actions:

- Save draft;
- Publish.

Draft-save validation should validate supplied values but must not require publication-complete content.

Publishing must show clear client validation while still relying on the canonical RPC.

The form should preserve entered data on safe errors.

A debug-only Fill Sample Data action is acceptable if it follows the Proposal precedent and is absent from release builds.

## Weekly/monthly controls

Weekly:

- one weekday only;
- local meeting time;
- duration;
- timezone;
- effective date.

Monthly:

- one numeric/calendar day from 1 through 28;
- local meeting time;
- duration;
- timezone;
- effective date.

Do not expose arbitrary RRULE text.

## Timezone safety

Reuse or carefully generalize the Proposal timezone utilities.

Do not repeat earlier Proposal editor defects.

Required:

- invalid/in-progress timezone text never crashes render;
- date/time controls do not reinterpret stored values through the device timezone;
- schedule labels use the selected event timezone;
- changing timezone does not silently alter an already stored intended schedule without an explicit user action;
- `UTC` works;
- client validates recognized zones where existing infrastructure permits;
- backend remains canonical.

## Editing published/paused schedules

Content/location edits can be saved while preserving the unchanged schedule.

A material schedule change after publication must expose an **effective-from future local date**.

The form must understand schedule history well enough to distinguish:

- the currently effective schedule;
- a pending future schedule version.

If a pending future version exists:

- load that pending schedule as the editable future configuration;
- show its effective date clearly;
- saving a correction with the same effective date updates that pending version through the 04B1 contract;
- do not create redundant schedule versions.

If no pending version exists:

- start from the current effective schedule;
- when schedule fields change, require a future effective date;
- content-only edits must not accidentally create a future schedule version.

Do not allow UI edits to historical effective versions.

A compact read-only schedule history summary is optional. Correct behavior is mandatory.

## Lifecycle actions

Publishing:

- draft only;
- complete profile;
- all required content/schedule/location;
- future occurrence exists.

Pausing:

- published only.

Resuming:

- paused only;
- valid future occurrence.

Ending:

- published or paused;
- terminal.

Repeated commands should handle canonical idempotent results safely.

---

# Web read-only Tavoli discovery

Add a separate feature boundary, likely:

```text
apps/web/src/features/tavoli/
```

Add public App Router routes:

```text
/tavoli
/tavoli/[id]
```

Use the existing Proposal website patterns:

- typed runtime validation of sanitized RPC output;
- server-only Supabase data boundary;
- Server Components for initial data;
- safe errors;
- shadcn foundation components;
- no direct table reads.

## Web list

Show:

- heading/explanation;
- obvious sibling navigation between One-time Proposals and Tavoli;
- locality filter;
- active Tavoli cards;
- next meeting;
- rough location;
- opaque snapshot-preserving pagination.

Do not add web Tavoli authoring.

Do not add a combined mixed feed.

## Web detail

Show the same public information as mobile:

- recurrence;
- bounded upcoming meetings;
- timezone;
- lifecycle;
- rough location;
- public exact location or restricted explanation;
- sanitized creator display name.

Paused/ended exact-ID detail remains available and must not claim an upcoming active meeting.

Return a real not-found state for missing/draft rows.

`/admin` remains a real 404.

Do not expose protected exact values in rendered HTML, metadata, structured data, errors, or client props.

---

# Parsing and domain validation

Both clients must validate RPC payload shape rather than trusting JSON blindly.

In particular validate:

- lifecycle values;
- UUIDs;
- recurrence type;
- weekday/day-of-month shape;
- local time;
- duration;
- timezone;
- `next_occurrences` JSON array;
- schedule-history JSON for owner editing;
- exact-location restriction flag;
- pagination cursor fields.

Malformed data must become a safe recoverable error, not an exception dump.

Do not log exact restricted meeting content, Auth tokens, emails, cookies, or raw Supabase errors.

---

# Automated tests

## Mobile domain/data/application

Cover at least:

- list RPC mapping;
- explicit snapshot required;
- snapshot retained across page 1/page 2;
- new snapshot on refresh/filter reset;
- locality + cursor composition;
- malformed payload rejection;
- recurrence summary formatting;
- named-timezone next-meeting formatting;
- weekly/monthly owner schedule parsing;
- active vs pending schedule derivation;
- pending future correction uses the same effective date;
- content-only edit preserves schedule;
- stale expected identity rejection;
- late-account async result suppression;
- lifecycle command state changes.

## Mobile widgets/router

Cover at least:

- Browse selector shows distinct Proposals/Tavoli lists;
- `/proposals` and `/tavoli` both select Browse;
- direct Tavolo detail selects Browse;
- Proposal routes still work;
- signed-out Tavoli browse/detail;
- locality filter;
- list card to detail and back;
- rough/public/restricted location presentation;
- next five occurrences;
- paused and ended detail;
- incomplete profile create/manage redirect;
- complete user creates incomplete draft;
- weekly form;
- monthly 1–28 form;
- invalid timezone safe rendering;
- Save draft;
- Publish;
- My Tavoli lifecycle actions;
- pending schedule correction;
- terminal End confirmation;
- account switch clears owner UI/forms;
- bottom-navigation branch state remains coherent.

## Web

Cover at least:

- runtime model validation;
- `/tavoli` signed-out rendering;
- locality filtering;
- snapshot embedded in next cursor;
- page 2 reuses page-1 snapshot;
- invalid cursor handling;
- Tavolo card;
- published detail;
- restricted exact location never rendered;
- public exact location detail-only;
- bounded upcoming meetings;
- paused/ended detail without active next meetings;
- missing/draft detail not found;
- navigation between `/proposals` and `/tavoli`;
- `/admin` remains 404;
- production build.

---

# Real local integration

The backend recurring harness already proves recurrence, lifecycle, ownership, and privacy.

Add a focused **built-Next.js Tavoli HTTP integration** without Playwright if it can be done cleanly.

Expected evidence:

1. establish deterministic recurring test records through supported Auth/RPC APIs;
2. build/start the production Next.js server against local Supabase;
3. request `/tavoli`;
4. confirm rough location and public list content render;
5. follow/request a Tavolo detail;
6. confirm participant-restricted exact text is absent from the entire HTML;
7. confirm restricted explanation is present;
8. confirm a public exact location appears on detail but never on list;
9. confirm paused/ended detail does not render an active next-meeting claim;
10. confirm pagination preserves the same snapshot.

Reuse/refactor existing local test helpers where useful, but do not create a brittle dependency on console output or reverse-engineered cookies.

Do not add browser UI automation solely for this plan.

If a clean HTTP harness is blocked by current fixture isolation, keep the existing real 04B1 API integration plus strong route/server tests and document the exact limitation. Do not fake integration success.

---

# Database and CI expectations

No schema change is expected.

The Database job must still pass:

- migration replay;
- schema lint;
- 429+ pgTAP assertions;
- Auth/profile/proposal/Tavoli integration harnesses;
- generated-type drift.

If no backend contract changes, generated DB types should remain unchanged.

Mobile CI must include all Tavoli tests, localization, formatting, analysis, and the full existing suite.

Web CI must include Tavoli tests, lint, route generation/typecheck, and production build.

Run `git diff --check`.

Leave the pull request unmerged for review and native/browser QA.

---

# Documentation and roadmap

Update:

- mobile routing/feature documentation;
- new mobile Tavoli README;
- new web Tavoli README;
- system-design ownership/status only where needed;
- database guide only if client usage clarifies an existing contract;
- roadmap.

While the PR is open:

- 04B1 → `Implemented`;
- 04B2 → `In progress`;
- 04B parent → `In progress`;
- 04 parent → `In progress`;
- 04C → `Not started`;
- 05 → `Not started`.

After merge:

- 04B2 → `Implemented`;
- 04B parent → `Implemented`;
- parent 04 remains `In progress` while 04C Material Resources remains outstanding under the current roadmap;
- do not report 04C, participation, or chat as implemented.

---

# Explicit non-goals

Do not implement:

- join requests;
- accepted participation;
- participant-authorized exact-location reads;
- participant counts;
- automatic chat;
- messages;
- notifications;
- recurrence exceptions;
- skipped/rescheduled single meetings;
- attendance per occurrence;
- multiple weekdays;
- arbitrary intervals;
- RRULE input;
- skills for Tavoli;
- Material Resources;
- maps/geocoding;
- media;
- donations/payments;
- legal entities;
- web Tavoli authoring;
- final design;
- realtime subscriptions.

---

# Acceptance criteria

04B2 is ready for final review when:

- [ ] based on latest merged `main`;
- [ ] existing bottom-navigation shell remains stable;
- [ ] Proposals and Tavoli are two distinct Browse lists;
- [ ] `/proposals` remains compatible;
- [ ] `/tavoli` and `/tavoli/:id` are public mobile routes in Browse;
- [ ] signed-out users can browse Tavoli;
- [ ] list uses one retained reference-time snapshot across pages;
- [ ] refresh/filter reset creates a new snapshot;
- [ ] cards show next meeting and rough location only;
- [ ] details show recurrence and bounded upcoming meetings;
- [ ] paused/ended details claim no active next meeting;
- [ ] restricted exact location never reaches public UI payload/rendering;
- [ ] complete authenticated users can create/save/publish/manage Tavoli;
- [ ] drafts may remain incomplete;
- [ ] weekly and monthly 1–28 forms match 04B1;
- [ ] timezone rendering uses event timezone, not device timezone;
- [ ] invalid timezone input cannot crash;
- [ ] published schedule changes require future effective dates;
- [ ] pending future schedule can be corrected in place;
- [ ] content-only edits do not create schedule history;
- [ ] stale-account forms cannot mutate another identity;
- [ ] owner state clears on session change;
- [ ] `/tavoli` and `/tavoli/[id]` exist on web;
- [ ] web pagination preserves the snapshot;
- [ ] web remains read-only;
- [ ] Proposal mobile/web behavior does not regress;
- [ ] `/admin` remains 404;
- [ ] no database migration is introduced without a reported blocker;
- [ ] Mobile/Web/Database CI are fully green;
- [ ] PR remains unmerged for QA.

---

# Manual QA gate

Before merge, manually verify Android and, when available, iOS:

1. bottom nav remains Profile / Browse / Home;
2. Browse switches clearly between Proposals and Tavoli;
3. switching lists does not break Proposal filter state;
4. signed-out Tavoli list/detail;
5. locality filter and Load More;
6. restricted vs public exact location;
7. weekly draft creation;
8. monthly draft creation;
9. save/reopen/edit draft;
10. publish and public discovery;
11. pause removes from normal list;
12. resume returns it;
13. future schedule change;
14. correction of an already-pending future schedule;
15. End is terminal and historical;
16. invalid timezone cannot crash;
17. event-local times remain consistent;
18. account switch does not show/mutate the old account’s Tavoli;
19. hot reload while in list/detail/editor/management;
20. no new Proposal navigation regression.

Manual browser review:

- `/tavoli`;
- locality/filter/pagination;
- public and restricted detail;
- paused/ended detail;
- sibling navigation with Proposals;
- responsive layout;
- no protected exact text in page source.

---

# Autonomy and stop conditions

Codex may decide:

- exact Flutter class/file names;
- exact Material 3 list switcher;
- exact owner screen decomposition;
- exact form widgets;
- exact recurrence-summary copy;
- exact opaque web cursor encoding;
- exact safe runtime validation library usage consistent with current repo;
- exact local HTTP-integration script organization.

Stop and report before:

- changing the 04B1 recurrence/lifecycle model;
- editing the merged 04B1 migration;
- adding a new DB migration for cosmetic client convenience;
- merging Proposals and Tavoli into one schema/feed;
- changing bottom-navigation destinations;
- exposing restricted exact location;
- inventing participation to unlock location;
- adding recurrence exceptions/RRULE;
- adding skills to Tavoli;
- adding chat/notifications/material resources;
- implementing web authoring;
- merging the PR.

---

# Deliverables

Produce:

1. mobile Tavoli feature boundary;
2. route integration under Browse;
3. Proposals/Tavoli list selector;
4. public Tavoli list/cards/detail;
5. snapshot-safe pagination;
6. My Tavoli owner management;
7. Tavolo create/edit form;
8. lifecycle actions;
9. safe current/pending schedule editing;
10. read-only web Tavoli list/detail;
11. focused mobile/web tests;
12. built-web HTTP integration where cleanly supported;
13. documentation/roadmap updates;
14. focused PR, preferably `codex/04b2-tavoli-mobile-web-experience`;
15. structured completion report.

Do not merge the PR.

---

# Completion report

Return:

1. **Summary**
2. **Branch/base/PR**
3. **Changed files**
4. **Skills/framework guidance used**
5. **Browse separation and routes**
6. **Mobile public Tavoli list**
7. **Snapshot pagination**
8. **Mobile Tavolo detail**
9. **My Tavoli management**
10. **Create/edit form**
11. **Timezone behavior**
12. **Current/pending schedule editing**
13. **Lifecycle actions**
14. **Location privacy**
15. **Identity/race safeguards**
16. **Web list/detail**
17. **Web cursor/snapshot contract**
18. **Tests**
19. **Real HTTP integration evidence**
20. **Validation/CI**
21. **Manual QA remaining**
22. **Documentation/roadmap**
23. **Deferred 04C/05/07 work**
24. **Warnings/blockers**
25. **Commit/PR reference**

Do not report participation, chat, Material Resources, recurrence exceptions, or final visual design as implemented.
