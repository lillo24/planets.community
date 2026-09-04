# PLANETS 04B2B — Public Web Tavoli Discovery

**Roadmap area:** PLANETS 04B2 — Tavoli Mobile/Web Experience  
**Task type:** Public web portion of 04B2  
**Repository:** `lillo24/planets.community`  
**Required implementation base:** latest merged `main`  
**Known `main` before this prompt archive:** `1d5871ced35bc56efa6758060434ec61d06f98dc`

## Objective

Complete the first Tavoli experience by adding **signed-out, read-only public web discovery** over the canonical 04B1 recurring-activity APIs.

After this task:

- `/tavoli` lists active published Tavoli;
- `/tavoli/[id]` shows sanitized public details for active, paused, or ended Tavoli;
- the public website clearly distinguishes **One-time Proposals** from **Tavoli** through route-backed links;
- the public home page exposes both discovery types without becoming a full web app;
- Tavoli list pagination captures one explicit reference-time snapshot and reuses it across all pages;
- cards show rough location and the next meeting, but never exact meeting information;
- detail pages show recurrence, duration, event time zone, bounded upcoming meetings, and correct exact-location privacy;
- participant-restricted locations display **“Exact location available after joining.”** without receiving/rendering the protected value;
- public exact locations remain detail-only;
- Server Components call only the sanitized public RPCs;
- 04B2A is documented as implemented while its independent native-QA backlog remains unclaimed;
- no web authoring, owner management, participation, chat, notifications, material resources, or database redesign is added.

When this PR is eventually merged, 04B2B, parent 04B2, and parent 04B can be marked implemented.

The core parent 04 can also be marked implemented because its defined main result is one-time Proposal plus recurring Tavoli discovery. `04C — Material Resources` remains a separately tracked future extension and does not silently block completion of the core activity-discovery parent.

Do not merge the PR from the implementation task.

---

## Inspect before changing anything

Work from the latest `main`; the known SHA above may be behind this prompt’s archive commit.

At minimum inspect:

1. root `AGENTS.md`;
2. `apps/web/AGENTS.md`;
3. `docs/development/codex-tooling.md`;
4. `docs/architecture/core-stack.md`;
5. `docs/architecture/system-design.md`;
6. `docs/development/database.md`;
7. `docs/implementation/roadmap.md`;
8. the complete 04B1 migration, tests, and generated types;
9. the merged 04B2A Flutter Tavoli feature and README;
10. `apps/web/README.md`;
11. the current public home page;
12. the full web Proposals feature:
    - public list/detail routes;
    - strict models/parsers;
    - server-only Supabase boundary;
    - cards/status/time formatting;
    - route/component/model tests;
13. current shared shadcn/state components;
14. the local web Auth integration pattern;
15. `.github/workflows/validation.yml`.

Important current facts:

- PR #12 / 04B2A is merged at `1d5871ced35bc56efa6758060434ec61d06f98dc`.
- Native Android/iOS QA for 04B2A was **not independently marked passed**. Do not rewrite history or claim otherwise.
- Tavoli are physically separate from one-time Proposals.
- The canonical public list RPC is `list_public_recurring_activities`.
- The list RPC requires non-null `p_reference_time`.
- Every cursor page must reuse the same reference-time snapshot.
- The list RPC deliberately returns compact card fields: title, summary, topic, rough location, next occurrence, and event time zone.
- Recurrence definition and bounded future occurrences are available from `get_public_recurring_activity`.
- Public list payloads contain no exact meeting information.
- Public detail returns exact meeting text only when visibility is `public`; otherwise it returns a restricted indicator and no protected value.
- Paused and ended Tavoli remain available by sanitized exact ID but are excluded from normal list discovery.
- The website currently provides signed-out Proposal discovery using Next.js Server Components.
- `/admin` must remain a real 404.

No external product document or provider account is required.

---

## Current framework and skill guidance

The repository currently uses:

- Next.js 16.3.4;
- React 19.2.8;
- Supabase JS 2.113.0;
- `@supabase/ssr` 0.12.5;
- shadcn/Base UI;
- Vitest/jsdom.

Before implementing routes, `params`, `searchParams`, Server Components, or caching behavior, read the version-matched documentation under:

```text
apps/web/node_modules/next/dist/docs/
```

In this Next.js generation, route `params` and page `searchParams` are asynchronous request data. Do not copy older synchronous examples.

Reuse the installed persistent guidance:

- official Supabase skill;
- Vercel React best-practices skill;
- shadcn skill.

Do not install:

- the full Vercel deployment plugin;
- another standalone Next.js pack;
- another data-fetching/state library;
- a recurrence package;
- a UI framework.

Repository contracts, tests, `AGENTS.md`, and this plan remain authoritative.

---

# Public route structure

Add:

```text
/tavoli
/tavoli/[id]
```

under the existing public App Router group.

Both routes:

- work signed out;
- remain Server Components by default;
- use the existing per-request Supabase server factory;
- call only public sanitized recurring-activity RPCs;
- require no browser Supabase client;
- require no authenticated owner state.

Do not add:

```text
/tavoli/create
/tavoli/mine
/tavoli/[id]/edit
```

on web.

Those are mobile-only for now.

Do not expose a plausible admin or organizer dashboard.

---

# Public activity discovery navigation

The web currently links primarily to one-time Proposals. Add a narrow route-backed discovery selector/navigation for:

```text
One-time Proposals
Tavoli
```

Use ordinary links, not client-owned tab state.

Preferred placement:

- near the heading on `/proposals`;
- near the heading on `/tavoli`.

A small shared component such as an activity-discovery switcher is acceptable if it remains narrow and accessible.

Requirements:

- active destination is visually and semantically clear;
- links remain usable without JavaScript;
- the Proposal and Tavoli lists remain separate;
- do not merge both domains into one feed;
- do not rename `/proposals`;
- do not create a complex site-wide navigation system in this task.

Update the public home page so users can reach both:

- Browse one-time Proposals;
- Browse Tavoli.

Keep the website informational/discovery-oriented. Do not reproduce the mobile bottom navigation.

---

# Web Tavoli feature boundary

Add a focused area, likely:

```text
apps/web/src/features/recurring-activities/
```

or an equally clear English name consistent with 04B1/04B2A.

Use “Tavoli” in user-facing copy where natural, while code names remain unambiguous.

Expected responsibilities:

- strict public summary/detail/occurrence/schedule models;
- parsing of sanitized RPC payloads;
- opaque cursor encoding/decoding;
- a server-only Supabase read boundary;
- public cards, recurrence formatting, lifecycle badges, and schedule formatting;
- focused tests;
- a short feature README.

Do not import Flutter code.

Do not force Tavoli into Proposal TypeScript models merely because some location fields overlap.

Small genuinely domain-neutral display helpers may be shared, but avoid a broad polymorphic `Activity` abstraction.

---

# Strict public models and fail-closed parsing

Define public web models for at least:

## List summary

- recurring activity ID;
- title;
- summary;
- optional topic;
- country code;
- locality;
- optional administrative area;
- public rough-location label;
- next meeting start;
- next meeting end;
- event time zone.

The list/card model must have **no exact meeting field**.

## Public detail

- recurring activity ID;
- sanitized creator display name;
- lifecycle: `published`, `paused`, or `ended`;
- title;
- summary;
- description;
- optional topic;
- structured rough location;
- recurrence type: `weekly` or `monthly`;
- ISO weekday or day-of-month;
- local start time;
- duration;
- event time zone;
- schedule effective date;
- bounded upcoming occurrence list;
- public exact meeting text or restricted-location state.

Reject impossible combinations, for example:

- unknown lifecycle;
- weekly schedule without weekday 1–7;
- weekly schedule with monthly day;
- monthly schedule without day 1–28;
- monthly schedule with weekday;
- invalid timestamps;
- non-positive/invalid duration;
- invalid occurrence arrays;
- invalid time-zone identifiers that would make `Intl.DateTimeFormat` throw;
- restricted detail that unexpectedly contains exact meeting text.

Privacy parsing must fail closed:

- when `exact_location_restricted` is true, the parsed model must never retain exact meeting text;
- if the backend unexpectedly sends both, reject the payload safely rather than rendering or logging it;
- when location is public, require the expected exact text before rendering the public-location section.

Do not include raw payloads in thrown/logged messages.

---

# Snapshot-safe cursor pagination

This is the most important web-specific correctness rule.

## First page

When no valid cursor exists:

1. normalize filters;
2. capture one server UTC timestamp;
3. call `list_public_recurring_activities` with that value as `p_reference_time`;
4. retain that snapshot in the next-page cursor.

Capture the time once. Do not call `new Date()` separately for related list operations.

## Following pages

The opaque cursor should carry enough validated state to reproduce the same pagination session, including at least:

```text
version
referenceTime
nextStartsAt
recurringActivityId
normalized locality or equivalent filter binding
```

Base64url JSON is acceptable, following the existing Proposal cursor pattern.

Validate:

- maximum encoded length;
- object shape/version;
- timestamps;
- UUID;
- filter consistency.

If a cursor is malformed or does not match the active normalized filter:

- ignore it;
- start a fresh first page with a new reference-time snapshot;
- do not expose a raw error.

Every “More Tavoli” link must preserve:

- locality;
- the opaque snapshot cursor.

Do not:

- default `p_reference_time` inside the gateway;
- use the current time again for page 2;
- use offset pagination;
- place exact/private data in the cursor;
- treat the cursor as authorization.

The cursor does not require cryptographic signing because it references public data only, but all fields must be validated before calling the RPC.

## Refresh/filter behavior

A new request without a cursor, including a submitted locality filter, creates a new snapshot.

A copied next-page URL may preserve its historical browsing snapshot. This is acceptable.

Make clock creation injectable/testable enough to avoid flaky tests.

---

# Tavoli list page

Implement `/tavoli` with a simple GET form and Server Component data loading.

## Filter

Support only the backend-supported first filter:

- locality.

Normalize and bound the value consistently with the database contract.

Submitting the form must drop the prior cursor and begin a fresh snapshot.

Do not add:

- topic search;
- skills;
- map radius;
- client-side filtering of partial pages;
- AI/recommendation ranking.

## Card

Each clickable card should contain:

- title;
- summary;
- optional topic;
- rough public location;
- **Next meeting** start/end rendered in the event’s named time zone;
- event time-zone label where useful.

Do not show:

- exact meeting information;
- owner-only fields;
- Proposal statuses such as Just Finished;
- Proposal Required/Useful skills;
- participant counts;
- Join controls.

The 04B1 list contract does not include the complete recurrence definition. Do **not** introduce N+1 detail RPC calls merely to show “Every Wednesday” on each web card, and do not add a database migration solely for this convenience.

The compact web card may show the next concrete meeting only. Full recurrence belongs on detail.

Use safe loading/error/empty states consistent with current Proposal pages.

Use deterministic page size, likely matching current web discovery unless repository evidence suggests otherwise.

---

# Tavolo detail page

Implement `/tavoli/[id]`.

Validate UUID shape before calling Supabase.

Behavior:

- invalid ID → real `notFound()`;
- valid unknown/non-public ID → real `notFound()`;
- operational/load failure → safe recoverable message without raw provider details.

Call `get_public_recurring_activity` with:

- the Tavolo ID;
- a bounded occurrence limit, preferably 5;
- one explicit reference time captured for that request.

Render:

- title;
- summary;
- optional topic;
- lifecycle badge:
  - Active;
  - Paused;
  - Ended;
- full description;
- recurrence summary;
- local start time;
- duration;
- IANA event time zone;
- rough public location;
- upcoming meeting list for active published Tavoli;
- sanitized organizer display name when present;
- exact-location section according to the public contract.

## Recurrence wording

Provide clear English wording, for example:

```text
Every Wednesday at 19:00
Every month on day 12 at 18:30
Duration: 90 minutes
Time zone: Europe/Rome
```

Use ISO weekday values correctly.

Do not derive recurrence by inspecting the upcoming occurrence list.

## Occurrence formatting

Format every instant using explicit `timeZone`, never the server/device default.

The same meeting must display its intended event-local time across DST.

Handle the database-compatible `UTC` identifier.

Do not mutate or reinterpret times in the browser.

## Lifecycle

Active/published:

- show bounded upcoming occurrences.

Paused/ended:

- show the historical public detail;
- do not show an active upcoming-occurrence list;
- explain the inactive state briefly if useful.

Do not imply that paused/ended Tavoli can be joined.

## Exact meeting location

Always show rough location.

If public:

- show exact meeting text on detail only.

If restricted:

- render **“Exact location available after joining.”**
- do not receive, retain, serialize into props, metadata, logs, or HTML the protected exact value.

Do not call owner APIs even when the visitor happens to be signed in.

---

# Server-only data boundary

Add server-only functions equivalent to:

```text
listPublicRecurringActivities
getPublicRecurringActivity
```

Use the generated database types and `createSupabaseServerClient()`.

Requirements:

- `import "server-only"`;
- pass exact named RPC arguments;
- no service-role client;
- no browser-client import;
- no direct reads from recurring tables;
- no owner RPCs;
- map all returned rows through strict parsers;
- throw sanitized/app-owned failures upward or allow routes to replace them with safe UI;
- never log raw error bodies.

Do not add Client Components just to fetch public data.

---

# Caching and time-sensitive rendering

Tavoli ordering and “next meeting” depend on the chosen snapshot.

Follow current Next.js 16 documentation and existing repository behavior.

Do not add long-lived static caching or `use cache` around time-sensitive Tavoli list/detail reads unless the cache key and freshness model explicitly include the reference time and are proven correct.

A straightforward dynamic Server Component implementation is preferred.

Do not add ISR, background revalidation, or a cache library in this task.

---

# Metadata and HTML privacy

Metadata is optional.

If adding route metadata:

- use only title, summary, topic, and rough public location;
- never include exact meeting text;
- never fetch owner/private RPCs for metadata;
- avoid duplicate detail RPCs solely for SEO unless current framework request memoization is deliberately implemented and tested.

Rendered HTML must not contain:

- participant-restricted exact location;
- raw Supabase errors;
- Auth/session tokens;
- private owner data;
- schedule-history internals.

---

# Tests

Add focused TypeScript/component/route tests.

## Models/parsers

Cover:

- valid public list summary;
- valid weekly detail;
- valid monthly detail;
- weekly weekday bounds;
- monthly day 1–28;
- lifecycle validation;
- occurrence-array parsing;
- invalid timestamp;
- invalid time zone;
- restricted location strips/rejects unexpected exact text;
- public exact-location consistency;
- malformed payload produces a safe failure without echoing payload content.

## Cursor

Cover:

- encode/decode round trip;
- reference time is preserved;
- next-occurrence cursor values are preserved;
- locality/filter binding is preserved;
- malformed/oversized cursor rejected;
- invalid timestamp/UUID rejected;
- cursor for a different locality ignored;
- page 2 reuses page 1 reference time exactly;
- filter submission creates a fresh snapshot;
- deterministic clock behavior.

## Components

Cover:

- card links to detail;
- card renders title/topic/rough location/next meeting;
- card type cannot/render does not contain exact meeting text;
- explicit event-zone formatting when process time zone differs;
- `UTC` formatting;
- weekly/monthly recurrence summaries;
- Active/Paused/Ended badges;
- restricted-location message;
- public exact-location detail;
- paused/ended detail has no upcoming list;
- accessible activity-type switcher state.

## Routes

Cover:

- signed-out `/tavoli` list;
- locality normalization;
- empty state;
- safe list error;
- next-page URL preserves locality + opaque snapshot cursor;
- `/tavoli/[id]` active detail;
- paused/ended detail;
- invalid UUID 404;
- missing Tavolo 404;
- operational detail failure renders safe text, not raw error;
- Proposal/Tavoli switcher appears on both list routes;
- public home links to both discovery types;
- `/admin` remains 404;
- no web Tavoli authoring routes are introduced.

Use mocked server boundaries for route/component tests. Do not make Vitest depend on live Supabase.

---

# Real local web integration

Add a deterministic, non-Playwright HTTP integration when it can be built cleanly from existing script patterns.

Preferred script:

```text
scripts/verify-local-web-tavoli.mjs
```

Run it against:

- local Supabase;
- locally generated web config;
- a production Next.js build/server.

Use supported Supabase clients and the existing local numeric-OTP/Mailpit pattern to create test identities/data. A small shared test helper extraction is acceptable if it reduces substantial duplication without becoming product code.

Prove at least:

1. signed-out `/tavoli` returns HTTP 200;
2. an active Tavolo appears with title, rough location, and next meeting;
3. participant-restricted exact text does not appear in list HTML;
4. restricted detail shows the explanatory message and not the protected value;
5. public exact text appears on detail but not list;
6. paused/ended Tavoli are absent from normal list;
7. paused/ended exact-ID pages remain sanitized and accessible;
8. invalid or unknown IDs retain 404 behavior;
9. no raw test email/token/session material is rendered.

Use synthetic unique strings and do not print protected values on success or failure.

Do not add Playwright solely for this smoke test.

If a reliable HTTP integration would require brittle framework internals, preserve the strong 04B1 API harness plus route tests and document the exact limitation. Do not reverse-engineer Supabase cookies because these pages are public.

---

# CI and validation

Keep all existing checks green.

Run:

- root formatting/checks;
- web tooling tests;
- all web Vitest tests;
- ESLint;
- Next route type generation / TypeScript;
- production build;
- existing HTTP smoke;
- Flutter formatting/analyze/tests;
- migration replay;
- database lint;
- all pgTAP tests;
- Auth/profile/proposal/recurring integrations;
- generated database type drift;
- `git diff --check`.

If added, run the Tavoli web HTTP integration in the Database job after local web configuration and production build, alongside the current web Auth integration.

No hosted deployment or provider account is required.

---

# Database boundary

No database migration is expected.

The reviewed 04B1 public APIs already provide the required web contracts.

A forward migration is permitted only if implementation reveals a concrete security or correctness blocker that cannot be solved at the web boundary.

Do not change the database merely to:

- add recurrence wording to list cards;
- avoid writing strict TypeScript parsers;
- simplify URL pagination;
- add web-specific fields.

Never edit the merged 04B1 migration.

If a genuine contract blocker appears, report it before broadening scope.

---

# Documentation and roadmap

Update:

- `apps/web/README.md`;
- a Tavoli web feature README;
- nearby architecture/system-design implementation status if stale;
- `docs/implementation/roadmap.md`.

While the PR is open:

- 04B1 → `Implemented`;
- 04B2A → `Implemented` in merged PR #12 (`1d5871ced35bc56efa6758060434ec61d06f98dc`);
- retain a note that 04B2A native Android/iOS QA was not independently marked passed;
- 04B2B → `In progress`;
- parent 04B2 → `In progress`;
- parent 04B → `In progress`;
- core parent 04 → `In progress`;
- 04C Material Resources → `Not started`;
- plan 05 remains independently available from implemented 04A.

After this PR merges:

- 04B2B → `Implemented`;
- 04B2 → `Implemented`;
- 04B → `Implemented`;
- core parent 04 → `Implemented`;
- 04C remains a separately tracked `Not started` extension;
- do not mark 04B2A native QA passed.

Do not turn manual QA status into implementation status ambiguity.

---

# Manual browser review gate

Leave the PR unmerged for final review.

Manually verify at least:

1. home links to both Proposals and Tavoli;
2. `/proposals` ↔ `/tavoli` switcher;
3. locality filtering;
4. More Tavoli pagination;
5. copied page-2 URL behaves consistently;
6. active Tavolo card/detail;
7. weekly recurrence wording;
8. monthly recurrence wording;
9. event-zone date/time formatting;
10. participant-restricted location;
11. public exact location appears only in detail;
12. paused/ended historical detail;
13. invalid/unknown detail 404;
14. narrow/mobile browser layout;
15. no raw error/private content in rendered page source.

This browser review does not retroactively satisfy 04B2A native QA.

---

# Non-goals

Do not implement:

- Tavoli web authoring;
- My Tavoli on web;
- owner RPCs on public web;
- authentication requirement for discovery;
- mixed Proposal/Tavolo feed;
- mobile changes except unavoidable documentation/test compatibility;
- participation or Join;
- participant-authorized exact-location reads;
- chat;
- notifications;
- material resources;
- recurrence expansion;
- occurrence editing/attendance;
- skills on Tavoli;
- map/geocoding;
- media;
- organization/legal-entity accounts;
- admin functionality;
- deployment;
- final visual design.

---

# Acceptance criteria

04B2B is ready for final review when:

- [ ] based on latest merged `main`;
- [ ] exact prompt is archived under `history-implementations/`;
- [ ] `/tavoli` works signed out;
- [ ] `/tavoli/[id]` works for sanitized public active/paused/ended detail;
- [ ] home links to both public activity types;
- [ ] Proposal and Tavoli list routes share a clear route-backed discovery switcher;
- [ ] lists remain separate;
- [ ] list uses only the sanitized public RPC;
- [ ] detail uses only the sanitized public detail RPC;
- [ ] no owner/direct-table access is introduced;
- [ ] cards contain rough location and next meeting but no exact location;
- [ ] no N+1 detail enrichment is added solely for card recurrence wording;
- [ ] first page captures one explicit reference-time snapshot;
- [ ] cursor preserves and reuses that snapshot across pages;
- [ ] cursor is bound to normalized filters;
- [ ] invalid cursor safely restarts pagination;
- [ ] active detail shows recurrence and bounded upcoming meetings;
- [ ] paused/ended detail shows no active upcoming list;
- [ ] all date/time formatting uses explicit event time zone;
- [ ] weekly/monthly recurrence wording is correct;
- [ ] restricted exact location is absent from models/HTML and replaced with explanatory copy;
- [ ] public exact location is detail-only;
- [ ] errors and malformed payloads fail safely;
- [ ] no authoring/Join/chat/resources are faked;
- [ ] web unit/component/route tests pass;
- [ ] real local HTTP integration is added if cleanly supportable;
- [ ] Mobile/Web/Database CI remains green;
- [ ] 04B2A is documented implemented without falsely claiming native QA;
- [ ] PR remains unmerged.

---

# Autonomy and stop conditions

Codex may decide:

- exact TypeScript file names;
- exact compact switcher styling;
- page size;
- cursor version/property names;
- narrow formatter/component structure;
- whether static list metadata is worthwhile;
- exact HTTP integration helper decomposition.

Stop and report before:

- adding web Tavoli mutations;
- adding a database migration for display convenience;
- using owner RPCs in public routes;
- mixing Tavoli and Proposals in one feed;
- exposing restricted exact meeting data;
- dropping the stable reference-time snapshot;
- adding client-side state/data libraries;
- adding participation/chat/resources;
- merging the PR.

---

# Deliverables

Produce:

1. exact archived implementation prompt;
2. strict Tavoli public web models/parsers;
3. snapshot-aware cursor utilities;
4. server-only public Tavoli gateway;
5. `/tavoli` list/filter/pagination;
6. `/tavoli/[id]` public detail;
7. cards, lifecycle badges, recurrence and occurrence formatting;
8. shared Proposal/Tavoli web discovery switcher;
9. public-home discovery links;
10. focused model/component/route tests;
11. deterministic HTTP integration if cleanly supportable;
12. documentation and roadmap correction;
13. focused PR, preferably `codex/04b2b-public-web-tavoli-discovery`;
14. structured completion report.

Do not merge the PR.

---

# Completion report

Return:

1. **Summary**
2. **Branch/base/PR**
3. **Changed files**
4. **Web feature architecture**
5. **Public routes**
6. **Proposal/Tavoli discovery navigation**
7. **Strict payload models**
8. **Snapshot cursor contract**
9. **List/filter/pagination**
10. **Cards**
11. **Detail/lifecycle**
12. **Recurrence and time-zone formatting**
13. **Exact-location privacy**
14. **Server-only Supabase boundary**
15. **Caching/rendering decisions**
16. **Tests**
17. **Real HTTP integration evidence**
18. **Validation/CI**
19. **Documentation/roadmap**
20. **04B2A native-QA status preservation**
21. **Manual browser review remaining**
22. **Deferred work**
23. **Warnings/blockers for plan 05**
24. **Commit/PR reference**

Do not report web authoring, participation, chat, material resources, 04B2A native QA, or deployment as implemented.
