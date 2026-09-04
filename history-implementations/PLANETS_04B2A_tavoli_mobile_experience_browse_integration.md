# PLANETS 04B2A — Tavoli Mobile Experience and Browse Integration

**Roadmap area:** PLANETS 04B2 — Tavoli Mobile/Web Experience  
**Task type:** Mobile portion of 04B2  
**Repository:** `lillo24/planets.community`  
**Required implementation base:** latest merged `main`  
**Reviewed main before this prompt was archived:** `dba2f2ab288050ae2d900625e89f10d5a247c03c`

## Objective

Build the functional Flutter experience for **Tavoli**, using the canonical recurring-activity backend merged in 04B1.

A Tavolo is an open-ended recurring local meeting/group, distinct from a one-time Proposal. Examples:

- a philosophy discussion every Wednesday;
- a monthly cultural meetup;
- a recurring neighborhood coordination meeting.

After this task:

- the existing **Browse** bottom-navigation branch clearly offers two separate lists: **Proposals** and **Tavoli**;
- published Tavoli can be browsed without signing in;
- Tavoli cards show their next meeting and rough public location;
- a card opens a public detail screen with schedule, upcoming meetings, description, organizer, and correct exact-location privacy;
- authenticated users with complete profiles can create Tavolo drafts, edit them, publish them, pause/resume them, and end them;
- owners have a minimal **My Tavoli** management surface;
- weekly/monthly scheduling and future schedule changes use the reviewed 04B1 contracts;
- pagination preserves one explicit reference-time snapshot across all pages;
- the existing Profile / Browse / Home navigation shell remains stable;
- no Tavoli web UI, participation, chat, notifications, material resources, or recurrence expansion is introduced.

Do not implement 04B2B web discovery in this task.

---

## Why 04B2 is split

04B2 contains two independently reviewable client surfaces:

- **04B2A — Tavoli Mobile Experience and Browse Integration** — this task;
- **04B2B — Public Web Tavoli Discovery** — later task.

Mobile includes public discovery, navigation integration, authoring, owner management, lifecycle commands, time-zone UX, and native QA. The web surface is read-only and can be implemented after the mobile contract is reviewed.

Update the roadmap to record this split. Do not leave 04B2 as one ambiguous active task.

---

## Inspect before changing anything

Work from the latest `main`. This prompt could not be pre-archived through the connected GitHub write action, so the implementation branch must first preserve this exact file at:

```text
history-implementations/PLANETS_04B2A_tavoli_mobile_experience_browse_integration.md
```

Do not rewrite or summarize it when archiving. The SHA above may be behind any intervening `main` work.

At minimum inspect:

1. root `AGENTS.md`;
2. `docs/development/codex-tooling.md`;
3. `docs/architecture/core-stack.md`;
4. `docs/architecture/system-design.md`;
5. `docs/architecture/product-decisions.md`;
6. `docs/development/database.md`;
7. `docs/implementation/roadmap.md`;
8. the 04B1 migration, pgTAP tests, integration harness, and generated database types;
9. `apps/mobile/README.md`;
10. `apps/mobile/lib/app/router/app_router.dart`;
11. `apps/mobile/lib/app/router/app_navigation_shell.dart`;
12. the complete one-time Proposals Flutter feature and its tests;
13. current Auth/profile readiness and account-switch invalidation behavior;
14. current localization/time-zone helpers;
15. `.github/workflows/validation.yml`.

Important current facts:

- 04B1 is merged and reviewed.
- `recurring_activities`, versioned schedules, protected meeting details, lifecycle operations, sanitized public APIs, and owner APIs already exist.
- The public list API requires a non-null `p_reference_time`; the same snapshot must be reused across cursor pages.
- Future schedule versions can be corrected in place before their effective date.
- One-time Proposals and Tavoli are physically separate domains.
- The mobile app already uses one `StatefulShellRoute.indexedStack` with **Profile / Browse / Home** branches.
- The Browse branch currently owns the Proposal routes.
- Identity changes rebuild the shell configuration and clear retained owner-specific state.
- Proposal UI already demonstrates the expected feature-first/Riverpod/gateway/controller/presentation structure, safe errors, locality filtering, exact-location privacy, and native schedule formatting.

Do not redesign these foundations.

---

## Skills and framework guidance

Reuse the already installed persistent project guidance:

- Dart/Flutter plugin;
- official Supabase skill;
- Supabase/Postgres best-practices skill.

Use the repository-pinned versions, including Flutter Riverpod 3.4.2, `go_router` 18.0.0, Supabase Flutter 2.17.2, and `timezone` 0.11.1.

Read version-matched `go_router` documentation before changing the stateful shell.

Do not install another navigation, recurrence, state-management, or design-system package.

Repository behavior and this plan remain authoritative over generic skill examples.

---

# Product and navigation decisions

## Tavoli remain inside Browse

Do **not** add a fourth bottom-navigation destination.

The persistent bottom bar remains:

```text
Profile · Browse · Home
```

Inside Browse, expose two separate route-backed list choices:

```text
Proposals · Tavoli
```

Use a compact Material 3 segmented/tab-like switcher or another equally clear control. The lists remain separate; do not mix one-time Proposal cards and recurring Tavolo cards in one feed.

The control should appear consistently on the public Proposal and Tavoli list roots, ideally through one narrow reusable Browse component rather than duplicated labels/logic.

Suggested public Tavoli routes:

```text
/tavoli
/tavoli/:id
```

Suggested owner routes:

```text
/tavoli/mine
/tavoli/create
/tavoli/:id/edit
```

An additional owner-detail route is acceptable if needed, for example:

```text
/tavoli/mine/:id
```

Exact nesting is Codex-owned.

Requirements:

- all Tavoli routes select the existing Browse bottom-nav branch;
- static routes such as `mine` and `create` must not be captured as dynamic IDs;
- Auth routes remain outside the shell;
- Home and both public Browse lists remain usable signed out;
- signed-out owner routes preserve safe `returnTo` behavior;
- incomplete profiles are redirected to `/profile/edit` for create/manage operations;
- the outer shell must not be replaced, nested redundantly, or destabilized merely to add the Proposals/Tavoli switcher.

Prefer adding Tavoli route ownership to the existing Browse branch. Introduce a nested shell only if version-matched `go_router` behavior proves it is materially safer; explain and test any such decision.

## List-state behavior

Switching:

```text
Proposals -> Tavoli -> Proposals
```

should preserve already-applied Proposal filters/results where the current Riverpod lifetime allows it, and likewise preserve the Tavoli list state. Do not refetch/reset each list merely because the user viewed the other activity type.

A deliberate pull-to-refresh resets that list and chooses a new snapshot.

Do not persist discovery state to durable storage.

---

# Mobile feature boundary

Add a restrained feature area, likely:

```text
apps/mobile/lib/features/recurring_activities/
```

or an equally clear English domain name.

The UI may say **Tavoli**; code/database naming should stay unambiguous and consistent with 04B1.

Use the established feature structure:

```text
domain/
data/
application/
presentation/
README.md
```

Expected responsibilities:

- domain models for public cards/details, owner records, schedules, occurrences, lifecycle, and editor input;
- a Supabase gateway that calls only canonical 04B1 RPCs;
- Riverpod controllers for public list/detail, own list/detail, editor, and owner commands;
- presentation screens/widgets;
- strict payload parsing and safe failure mapping.

Do not import one-time Proposal models merely because some fields look similar.

Small shared formatting/location widgets are acceptable when genuinely domain-neutral. Avoid a broad activity abstraction or polymorphic client hierarchy.

---

# Public Tavoli list

Accessible signed out.

## Data contract

Use:

```text
list_public_recurring_activities
```

according to the generated types.

The controller must:

1. capture one UTC reference-time snapshot when beginning a reset/first page;
2. send that exact value as `p_reference_time`;
3. retain it with the list state;
4. reuse it for every `load more` request in that pagination session;
5. use the returned `(next_starts_at, recurring_activity_id)` cursor;
6. choose a new snapshot only on explicit reset/refresh/filter change;
7. reject late responses from an older revision/filter/snapshot.

Do not call `DateTime.now()` separately for page 2.

Do not give the gateway a hidden moving default.

## Filters

Implement the backend-supported first filter only:

- locality.

Do not add topic search, recommendation ranking, skill filtering, map radius, or client-side filtering over partial pages.

Locality changes start a fresh snapshot/pagination session.

## Card content

A Tavolo card should show compactly:

- title;
- summary;
- optional topic;
- rough public location;
- recurrence summary, e.g. `Every Wednesday at 19:00` or `Monthly on day 12 at 18:30`;
- **Next meeting** start/end rendered in the event's named time zone.

Do not show exact meeting information on cards, even if public.

Do not show Proposal-only concepts such as:

- Just Finished;
- Required/Useful skills;
- participant count;
- a one-time start/end lifecycle badge.

Include safe loading, empty, retry, refresh, and load-more states.

---

# Public Tavolo detail

Accessible signed out for exact IDs returned by the sanitized API.

Use:

```text
get_public_recurring_activity
```

Render at least:

- title;
- summary;
- optional topic;
- full description;
- lifecycle presentation state (`Active`, `Paused`, `Ended` or equivalent localized copy);
- current recurrence summary;
- event time zone;
- duration;
- rough public location;
- a bounded list of upcoming meetings for active published Tavoli, preferably 3–5;
- sanitized creator display name when returned;
- exact meeting information only when returned by the public API.

Privacy behavior:

- public exact location → render exact meeting text in detail only;
- participant-restricted location → render localized text equivalent to **“Exact location available after joining.”**;
- never infer or request owner details to enrich the public screen.

Paused/ended exact-ID details remain viewable but have no active next-occurrence list.

Do not add a Join button or imply that joining already works.

Use named event-zone formatting, not device-local `toLocal()` behavior.

Reuse/extract the existing narrow time-zone helper safely rather than duplicating a second inconsistent implementation. Preserve the repository's explicit `UTC` compatibility handling if the Flutter time-zone package still needs it.

---

# Create and edit Tavoli

Authenticated complete-profile users can create and edit Tavoli through the canonical owner RPCs.

## Form fields

Provide a functional, non-polished form for:

- title;
- short summary;
- description;
- optional topic;
- country code;
- locality;
- optional administrative area/neighborhood;
- rough public location label;
- exact meeting text;
- exact location visibility: `Public` or `Participants`;
- recurrence type: `Weekly` or `Monthly`;
- weekly weekday OR monthly day 1–28;
- local start time;
- duration;
- event time zone;
- effective/start date.

No map picker or coordinates UI.

Do not add skills to Tavoli.

## Recurrence controls

Use constrained controls rather than asking users to type recurrence syntax.

### Weekly

- one weekday selector;
- one local time;
- one duration.

### Monthly

- one calendar day selector constrained to 1–28;
- one local time;
- one duration.

No RRULE field, multiple weekdays, intervals, exceptions, or occurrence editing.

## Time zone

Time-zone correctness is central.

- default a new form to the best available recognized local IANA zone where current app infrastructure supports it;
- provide a safe fallback such as `UTC` rather than guessing an offset;
- validate before date/time conversion or picker use;
- invalid input must not crash rebuilds;
- rendered/picked wall-clock values must use the selected event zone;
- do not silently reinterpret an already-selected local schedule through the device zone.

Use current proposal time-zone QA lessons and tests.

Do not add a provider-backed time-zone lookup service.

## Draft behavior

A draft may remain incomplete.

Support **Save draft** separately from **Publish**.

Save-draft validation should:

- validate any values supplied;
- not require every publishable field;
- preserve intentionally empty draft fields;
- never invent a recurrence schedule when all schedule values are absent.

After creating a draft, future saves must update that same ID instead of creating duplicates.

## Publish behavior

Publishing uses the existing canonical RPC and central database validation.

The client should provide clear, safe field-level/pre-submit guidance, but must not duplicate database authorization as the source of truth.

After publication:

- refresh public/owner Tavoli state;
- navigate to a stable owner or detail destination;
- do not create chat, membership, or notifications.

A debug-only **Fill sample data** action patterned after the Proposal editor is desirable for native QA. It must:

- use synthetic values;
- never exist in release builds;
- never persist until Save draft/Publish is explicitly chosen.

---

# Editing active schedules safely

04B1 preserves schedule history. The mobile editor must not hide that behavior behind destructive-looking edits.

## Content/location-only edit

If recurrence values are unchanged, sending the existing schedule/effective date must not create a new schedule version.

## Future schedule change

When changing recurrence for a published or paused Tavolo whose open schedule is already effective:

- require a future **Apply schedule change from** date;
- explain briefly that past meetings keep their prior schedule;
- do not present this as rewriting all history.

## Pending schedule correction

If the open schedule version starts in the future:

- prefill its existing future effective date;
- allow its recurrence/time/duration/time zone to be corrected at that same date;
- do not create a third redundant version;
- make it clear that this is a pending change.

Use `schedule_history` and `current_schedule` from the owner API to distinguish effective and pending versions correctly.

Do not expose raw JSON to presentation code.

A simple notice such as:

```text
Pending schedule change from 12 October
```

is enough. Do not build a complex history timeline.

If current 04B1 owner data cannot distinguish a pending schedule safely, stop and report the concrete contract gap rather than guessing from device time.

---

# My Tavoli and lifecycle management

Provide a minimal authenticated **My Tavoli** surface so drafts and lifecycle actions are reachable.

Show own:

- drafts;
- published/active Tavoli;
- paused Tavoli;
- ended Tavoli.

Each item should expose only valid actions.

## Draft

- edit;
- publish when complete.

## Published

- view;
- edit content/location;
- schedule a future recurrence change;
- pause;
- end.

## Paused

- view;
- edit;
- correct/schedule future recurrence;
- resume;
- end.

## Ended

- owner-readable historical content;
- no edit/resume;
- clear terminal/read-only state.

Use confirmation for terminal **End** and preferably for Pause if the action could surprise users.

Do not implement deletion.

Do not fake attendance or per-occurrence management.

Owner views may display participant-restricted exact meeting information because they use owner APIs. Public screens must remain sanitized.

---

# Authentication, readiness, and account-switch safety

Extend existing router classification carefully so Tavoli owner routes behave like Proposal owner routes.

Required:

- signed-out create/edit/mine routes redirect to numeric email OTP with safe internal return;
- authenticated incomplete profiles redirect to `/profile/edit`;
- signed-out `/tavoli` and `/tavoli/:id` remain public;
- account/session identity changes invalidate Tavoli owner state/forms;
- late owner loads/mutations cannot render or mutate under a different account;
- every mutation carries the expected creator profile ID for which the form was loaded;
- after every `await`, controller revision/identity checks prevent stale continuations;
- an old create-then-publish chain cannot publish under a newly authenticated account.

Do not weaken the router's current shell rebuild/account-change behavior.

Do not retain owner detail or exact meeting data in a global cross-account cache.

---

# Error handling and privacy

Use safe app-owned error categories/copy.

Do not render or log:

- raw PostgREST/Supabase messages;
- session tokens/cookies;
- full email addresses;
- participant-restricted exact meeting text in public errors/telemetry;
- raw owner RPC JSON.

Expected validation/lifecycle mistakes should be recoverable UI errors rather than noisy monitoring events.

If unexpected exceptions are reported through existing monitoring, preserve current no-PII defaults.

---

# Database-change boundary

04B1 is already merged and reviewed. **No database migration is expected in 04B2A.**

Use the existing generated RPC contracts.

A database change is allowed only if implementing the real client exposes a concrete security/correctness blocker that cannot be solved cleanly in the client. In that case:

1. stop normal scope expansion;
2. report the exact contract deficiency;
3. add only a focused forward migration plus pgTAP/integration evidence if the correction is clearly required;
4. never edit the merged 04B1 migration.

Do not redesign recurrence or owner/public APIs for convenience.

---

# Tests

Add focused Flutter unit/widget/router tests.

## Routing and Browse integration

Cover:

- `/tavoli` selects the existing Browse bottom-nav destination;
- `/tavoli/:id`, `/tavoli/mine`, `/tavoli/create`, and edit/owner routes remain in Browse;
- no fourth bottom-nav item appears;
- Proposals and Tavoli are two separate list choices;
- switching between lists routes correctly;
- Proposal list state is not unnecessarily reset by visiting Tavoli;
- public Tavoli routes work signed out;
- owner routes preserve Auth `returnTo` and profile-completion redirects;
- static route names cannot be parsed as Tavolo IDs;
- account switch clears private Tavoli stacks/state.

## Public list/controller

Cover:

- first page captures one explicit reference-time snapshot;
- load-more reuses exactly the same snapshot;
- refresh/filter change creates a new snapshot;
- late page from an old snapshot/filter is discarded;
- keyset cursor uses next occurrence + activity ID;
- locality filtering;
- loading/empty/error/load-more;
- no exact meeting field exists in card models/widgets;
- weekly/monthly card summaries;
- event-zone next-meeting formatting.

## Public detail

Cover:

- active detail and bounded upcoming occurrences;
- paused/ended detail without active occurrences;
- public exact meeting text;
- participant-restricted explanation;
- sanitized creator visibility;
- device zone differing from event zone;
- `UTC` compatibility;
- malformed payload fails safely.

## Editor

Cover:

- incomplete profile cannot enter authoring;
- incomplete draft save;
- weekly controls;
- monthly day 1–28 controls;
- invalid time zone cannot crash or open conversion-dependent pickers;
- save draft does not publish;
- create then subsequent save updates same ID;
- publish command;
- content-only edit creates no apparent schedule change in client request;
- future schedule-change effective date;
- pending future schedule correction at the same effective date;
- restored owner draft/current schedule;
- debug sample action absent in release-mode test configuration where practical;
- safe validation/errors.

## Lifecycle/owner

Cover:

- My Tavoli shows all lifecycle groups/states;
- valid actions by state;
- pause and resume;
- terminal end confirmation;
- ended item is read-only;
- participant-restricted exact data appears only in owner flow;
- stale identity/account switch prevents late create/update/publish/pause/resume/end continuation.

Use gateway test doubles for widget/controller tests. Do not make Flutter unit tests depend on live Supabase.

---

# Existing integration and CI

Keep all existing validation green:

- Flutter localization generation;
- Dart formatting;
- Flutter analyze;
- all existing and new Flutter tests;
- Web tests/lint/typecheck/production build;
- database migration replay/lint;
- all pgTAP tests;
- Auth/profile/proposal/recurring local integration harnesses;
- generated database type drift;
- `git diff --check`.

The existing recurring harness remains the real backend evidence. Do not duplicate it in Flutter tests.

No hosted provider account is required.

---

# Documentation and roadmap

Add a feature README documenting:

- Tavoli mobile feature boundaries;
- public vs owner RPC use;
- explicit list snapshot invariant;
- Proposals/Tavoli Browse separation;
- route ownership;
- recurrence editor limits;
- future schedule/pending correction behavior;
- exact-location privacy;
- account-switch invalidation.

Update mobile application/navigation documentation only where the Browse branch changes.

Update the roadmap:

- 04B1 → `Implemented`;
- 04B2 parent → `In progress`;
- add **04B2A — Tavoli Mobile Experience and Browse Integration** → `In progress`;
- add **04B2B — Public Web Tavoli Discovery** → `Not started`;
- 04B parent and parent 04 remain `In progress`;
- 04C Material Resources remains `Not started`;
- plan 05 remains independently available from implemented 04A.

After this PR eventually merges, 04B2A may be marked Implemented, but 04B/04 remain in progress until 04B2B is merged.

---

# Manual native QA gate

Leave the PR unmerged for Android/iOS interaction review.

Manual checklist:

1. bottom nav remains Profile / Browse / Home;
2. Browse clearly switches between separate Proposals and Tavoli lists;
3. switching lists does not wipe Proposal filters unexpectedly;
4. signed-out Tavoli list/detail;
5. locality filter + multiple pages;
6. refresh resets the pagination snapshot cleanly;
7. weekly and monthly card wording;
8. event time shown correctly when device zone differs;
9. public vs participant-restricted exact location;
10. sign in/profile-completion return to Tavoli authoring;
11. create and reopen incomplete draft;
12. publish a weekly Tavolo;
13. publish a monthly Tavolo with day 1–28;
14. edit content without changing schedule;
15. schedule a future change and verify the pending notice;
16. correct the pending schedule at the same effective date;
17. pause → absent from public list;
18. resume → present again;
19. end → absent and owner read-only;
20. account switch while an editor/command is open;
21. Android/system back through Tavoli detail/editor/My Tavoli;
22. hot reload within both Browse lists and an editor.

Do not mark native QA passed without interaction evidence.

---

# Non-goals

Do not implement:

- web Tavoli routes/components;
- mixed Proposal/Tavolo feed;
- fourth bottom-nav destination;
- participation/join requests;
- participant-authorized exact-location retrieval;
- chat;
- notifications;
- material resources;
- proposal changes unrelated to Browse switching;
- recurrence intervals;
- multiple weekdays;
- occurrence exceptions/cancellation/rescheduling;
- attendance;
- skills on Tavoli;
- map/geocoding;
- media;
- donations/payments;
- legal-entity accounts;
- final visual design.

---

# Acceptance criteria

04B2A is ready for final review when:

- [ ] it is based on latest merged `main`;
- [ ] 04B1 contracts are consumed without unnecessary schema redesign;
- [ ] Profile / Browse / Home shell remains stable;
- [ ] Tavoli do not become a fourth bottom-nav destination;
- [ ] Browse exposes separate Proposals and Tavoli lists;
- [ ] all Tavoli routes select Browse correctly;
- [ ] signed-out users can browse list/detail;
- [ ] cards show rough location and next meeting, never exact location;
- [ ] list pagination captures and reuses one explicit reference-time snapshot;
- [ ] refresh/filter reset creates a new snapshot;
- [ ] public detail respects exact-location privacy;
- [ ] active detail shows bounded upcoming occurrences;
- [ ] paused/ended detail shows no active next occurrences;
- [ ] complete-profile users can create/save/edit/publish;
- [ ] weekly and monthly 1–28 controls match 04B1;
- [ ] time-zone UI preserves local wall-clock intent;
- [ ] future schedule changes preserve history semantics;
- [ ] pending future schedules can be corrected at the same effective date;
- [ ] My Tavoli supports draft/published/paused/ended states;
- [ ] pause/resume/end use only valid canonical operations;
- [ ] ended Tavoli are read-only;
- [ ] stale/account-switched forms cannot continue commands;
- [ ] no Join/chat/notification/resource behavior is faked;
- [ ] Flutter, Web, Database, integrations, and type-drift checks pass;
- [ ] roadmap records 04B2A/04B2B split;
- [ ] PR remains unmerged for native QA.

---

# Autonomy and stop conditions

Codex may decide ordinary implementation details such as:

- exact Dart class/file names;
- whether the Proposals/Tavoli selector uses `SegmentedButton`, tabs, or another compact Material control;
- precise Riverpod provider decomposition;
- exact card spacing/copy;
- route nesting inside the existing Browse branch;
- owner-detail screen decomposition;
- constrained duration input UX;
- how to summarize schedule history into an effective/pending model.

Stop and report before:

- changing outer bottom-navigation destinations;
- mixing Proposals and Tavoli into one feed;
- adding a new navigation/state package;
- changing recurrence schema merely for UI convenience;
- guessing schedule effective/pending state incorrectly;
- exposing owner/restricted location through public screens;
- adding participation or chat;
- adding occurrence-level mutation;
- implementing the web slice;
- merging the PR.

---

# Deliverables

Produce:

1. Tavoli Flutter feature boundary;
2. strict public/owner domain models and Supabase gateway;
3. snapshot-safe public list controller;
4. public Tavoli cards/list/detail;
5. Browse Proposals/Tavoli switcher;
6. Tavoli routes inside the existing Browse branch;
7. create/edit draft and publish flow;
8. future/pending schedule-edit UX;
9. My Tavoli lifecycle management;
10. account-switch/race-safe controllers;
11. localized copy;
12. focused Flutter/router/widget tests;
13. exact prompt archive under `history-implementations/`;
14. documentation and roadmap split;
15. focused PR, preferably `codex/04b2a-tavoli-mobile-experience`;
16. structured completion report.

Do not merge the PR.

---

# Completion report

Return:

1. **Summary**
2. **Branch/base/PR**
3. **Changed files**
4. **Feature architecture**
5. **Browse integration and routes**
6. **Public list and snapshot pagination**
7. **Cards and recurrence summaries**
8. **Public detail and exact-location privacy**
9. **Create/edit/draft flow**
10. **Weekly/monthly schedule UX**
11. **Time-zone handling**
12. **Future/pending schedule changes**
13. **My Tavoli lifecycle management**
14. **Auth/profile readiness**
15. **Account-switch/race safety**
16. **Tests**
17. **Existing recurring integration evidence**
18. **Validation/CI**
19. **Documentation/roadmap**
20. **Manual native QA remaining**
21. **04B2B handoff**
22. **Deferred work**
23. **Warnings/blockers**
24. **Commit/PR reference**

Do not report web Tavoli discovery, participation, chat, material resources, or parent plan 04 as implemented.
