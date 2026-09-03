# PLANETS 04A — One-Time Proposals and Discovery

**Roadmap area:** PLANETS 04 — Proposals / activity discovery  
**Task type:** First scoped portion of plan 04  
**Repository:** `lillo24/planets.community`  
**Required base when this prompt was written:** `main` at `bcbf371150e23693288f77885637f9ed095beffc`

## Objective

Implement the first real PLANETS community-activity domain around **one-time proposals**.

A proposal is a one-time local activity/project with a specific start/end time and place, for example:

- paint a mural together;
- build or repair something as a group;
- organize a one-off community event;
- hold a specific workshop or collaborative session.

After this task:

- anyone can browse published proposals without signing in;
- proposals appear as clickable cards in a list;
- cards show compact information including date/time, rough public location, useful/required skills, and time-derived status;
- a card opens a proposal detail page/screen;
- authenticated users with complete profiles can create drafts, edit them, publish them, and cancel eligible published proposals;
- proposals use the canonical skill catalog already implemented in 03C;
- exact meeting information is stored separately from the public rough location;
- exact meeting information may be public or restricted to future accepted participants;
- restricted proposal details display a message such as **"Exact location available after joining."** instead of leaking the location;
- after a proposal ends, it remains in normal discovery for **24 hours** with a green **Just Finished** status;
- after that 24-hour window it disappears from normal proposal discovery but remains canonical historical data;
- completed historical proposals are suitable future sources for Community templates, but no template-copying system is implemented yet;
- public web discovery is read-only;
- recurring weekly/monthly activities remain a separate future feature.

Do not implement plan 05 participation in this task.

## Repository evidence and architecture to preserve

Inspect current `main` before changing anything. If `main` moved after the SHA above, use the latest merged repository and report material differences.

At minimum read:

1. root `AGENTS.md`;
2. `docs/architecture/core-stack.md`;
3. `docs/architecture/system-design.md`;
4. `docs/development/database.md`;
5. `docs/development/getting-started.md`;
6. `docs/development/codex-tooling.md`;
7. `docs/implementation/roadmap.md`;
8. `implementation_plan_sections_suggestions.md`;
9. all current Supabase migrations/tests;
10. the implemented 03C profile/skill/visibility model;
11. generated database types;
12. current Flutter router, Auth/profile readiness, common states and localization;
13. current Next.js public routes, Supabase server/browser boundaries, shadcn setup and tests;
14. `.github/workflows/validation.yml`.

Important current facts:

- PostgreSQL is canonical product state.
- RLS and narrow named operations enforce authorization.
- Anonymous/public access must be deliberately sanitized rather than exposing private rows and relying on UI hiding.
- PostGIS is already installed outside `public`.
- `skill_categories`, `skills`, and `profile_skills` are implemented and are the canonical controlled skill taxonomy.
- The architecture already says proposal requirements should reuse that taxonomy.
- Broad public location and exact operational meeting information must be separate.
- Mobile remains public-first.
- The public website may support discovery without reproducing all app functionality.
- `private.audit_events` and `private.outbox_events` already exist for later trusted domain/operational events.

Do not create a competing taxonomy, backend, or authorization system.

## External context

No external document or account is required to implement this task.

The founder decisions needed for 04A are recorded below and are authoritative for this task. The Google product-design document is background only and must not block implementation.

No map/geocoding provider, hosted deployment, production credentials, or provider dashboard work is required.

## Decisions already made

### One-time proposals vs recurring activities

This task implements **one-time proposals only**.

Recurring activities such as:

> Philosophy discussion every Wednesday

or:

> Monthly neighborhood gardening meetup

are a separate product type and will likely appear in a separate list.

Do not implement recurrence rules, occurrences, skipped dates, rescheduling of individual occurrences, or recurring-activity UI in 04A.

Record recurring activities as a future roadmap portion rather than forcing one-time and recurring scheduling into the same first schema.

### Proposal cards and detail

Normal discovery is a list of clickable proposal cards.

A compact card should expose approximately:

- title;
- short summary;
- date/time;
- rough public location;
- relevant required/useful skills;
- time-derived status badge.

Do not put exact addresses/meeting instructions on the card even when the exact meeting location is public. Exact meeting information belongs in proposal details.

Do not add participant counts/status yet because participation is plan 05.

### Time lifecycle

Persist only business lifecycle state that needs an explicit command.

Use a small stored lifecycle such as:

```text
draft
published
cancelled
```

Exact names may vary if repository inspection reveals a better convention.

Do **not** persist drift-prone `upcoming`, `happening`, `just_finished`, or `completed` booleans/states.

For a non-cancelled published proposal derive presentation status from canonical timestamps:

```text
now < starts_at                         -> upcoming
starts_at <= now < ends_at              -> happening
ends_at <= now < ends_at + 24 hours     -> just_finished
now >= ends_at + 24 hours               -> completed/historical
```

`Just Finished` is a presentation/discovery status derived from time, not a background transition.

Use a green status treatment in the functional UI.

Normal discovery includes:

- upcoming;
- happening;
- just_finished.

It excludes:

- drafts;
- cancelled proposals;
- completed proposals older than the 24-hour window.

Completed proposals remain stored and can still be retrieved through appropriate historical/owner boundaries. Do not delete or copy them merely because the normal discovery window ended.

No Cron/background job is needed to "finish" proposals.

### Start/end time

A publishable proposal requires:

- `starts_at`;
- `ends_at`;
- `ends_at > starts_at`.

Use canonical timezone-aware timestamps.

Store enough timezone information to render the intended event-local clock time reliably; prefer an IANA time-zone identifier if needed by the implementation.

Drafts may be incomplete. Publishing must validate required scheduling data centrally.

### Location

Every publishable proposal has two distinct location concepts.

#### Public rough location

Always visible in cards and public details.

Examples:

```text
Trento · Povo
Trento · Centro storico
Parco delle Albere area
```

Store structured/map-ready information rather than only one opaque string.

A reasonable first representation includes:

- country code;
- locality/municipality;
- optional administrative area/neighborhood;
- public display label;
- optional approximate PostGIS point.

The approximate point may remain null because 04A has no geocoder/map picker.

Do not invent a geocoding provider.

#### Exact meeting location

Operational location/instructions needed to attend, for example:

```text
Piazza Duomo, by the fountain
Via X 10, entrance through the courtyard
```

Store it separately from rough location.

The creator chooses:

```text
public
participants
```

(or equally clear internal values).

If exact location visibility is `public`, proposal details may expose it.

If visibility is `participants`, anonymous/ordinary public proposal detail must not receive the exact value. It should receive only enough information to render:

> Exact location available after joining.

Plan 05 will define what "accepted participant" means and add the authorized read path.

For now the proposal creator must still be able to read/edit their own exact location.

Do not create fake membership just to test restricted location access.

### Historical proposals and Community templates

A historical completed proposal is **not itself a template**.

Keep the historical proposal as immutable canonical event history.

Later Community/template work can copy approved reusable fields from a completed proposal into a separate template/new proposal.

04A should preserve stable source proposal IDs and enough clean historical data for this future workflow, but must not implement:

- a `Community templates` browsing area;
- template publication/moderation;
- automatic template creation;
- copying participant/history data into templates.

### Skills

Reuse the existing controlled `skills` catalog.

A proposal can mark selected skills as:

```text
required
useful
```

Use one normalized proposal-to-skill relationship with a constrained importance/requirement type.

Do not add another competence taxonomy.

Do not add proficiency levels.

## Data model and security requirements

Codex should choose exact names after inspecting current conventions, but the behavior should map cleanly to the following responsibilities.

### Proposal record

Store at least:

- proposal ID;
- creator profile ID;
- stored lifecycle state;
- title;
- short summary;
- full description;
- start/end timestamps;
- event timezone if needed;
- rough structured public location;
- optional approximate PostGIS point;
- created/updated/published/cancelled timestamps as justified.

Use sensible constraints.

Suggested validation boundaries:

- title: required for publication, concise;
- summary: required for publication, card-sized;
- description: required for publication, bounded;
- start/end: required for publication and ordered;
- public location: required for publication.

Do not force incomplete drafts to satisfy publication-only requirements if that would make useful drafting impossible.

### Exact meeting record

Keep exact meeting information physically distinct from broad location data.

A separate proposal meeting/location record is preferred over storing both values in one field.

It must:

- belong one-to-one to the proposal for now;
- hold exact text/instructions;
- hold exact-location visibility;
- optionally leave room for an exact point later;
- be owner-readable/editable;
- not be directly anonymously enumerable.

Publishing requires exact meeting information and a valid visibility value.

### Proposal skill requirements

Use normalized relationships to the current `skills` catalog.

Enforce uniqueness per `(proposal, skill)`.

Normal users cannot mutate the canonical skill catalog.

### Direct table access

Be conservative.

Public discovery should use narrow sanitized database functions/views, not direct anonymous reads of all proposal columns.

Exact restricted meeting information must never be returned by the public discovery API.

Owner editing may use RLS-authorized tables where simple, but multi-record save/publish/cancel transitions should use named canonical operations.

## Canonical operations

Use narrow backend operations rather than reproducing proposal workflow independently in Flutter and Next.js.

Likely operations include equivalents of:

```text
create_proposal_draft
update_own_proposal
publish_proposal
cancel_proposal
```

Exact names/signatures are Codex-owned.

All mutation operations must:

- authenticate through `auth.uid()`;
- bind any expected creator/profile ID where a stale cross-account form could otherwise mutate the newly authenticated user, following the 03C expected-profile pattern;
- verify ownership;
- enforce allowed stored-state transitions;
- validate publication requirements centrally;
- update all related proposal/skill/location rows atomically where appropriate;
- fail closed;
- use fixed/empty `search_path` for security-definer functions;
- have narrow execute grants;
- not use service-role client credentials.

### Draft creation/editing

A complete authenticated profile can create a one-time proposal draft.

Incomplete/skeletal profiles cannot create/publish proposals; direct users toward profile completion.

The owner can edit an own draft.

The owner can also edit an own **published upcoming** proposal until its start time.

Once `starts_at` has arrived, freeze ordinary content/time/location edits so historical event facts do not silently change while/after the activity is taking place.

Do not add collaborative editing.

### Publish

Publishing:

- works only for the owner;
- requires a complete profile;
- works from draft only;
- validates all required content, time, location, exact-location visibility, and proposal skills;
- records `published_at`;
- becomes publicly discoverable immediately if it is not already past an invalid time boundary;
- is idempotent only if the repeated command can safely return the already-published result without creating duplicate side effects.

Reject publishing an event whose end time is already in the past.

### Cancel

The owner may cancel an own published proposal while its end time has not passed.

Cancellation is explicit and terminal in 04A.

Cancelled proposals leave normal discovery immediately.

Do not implement restore/re-publish.

Do not delete the proposal row.

Participation-side consequences are deferred to plan 05.

### Outbox/audit

If consistent with the current generic primitives, publication/cancellation may record minimal transaction-local events such as proposal ID and actor ID.

Never place exact location, full description, or other unnecessary user content into audit/outbox payloads.

Do not implement notification delivery.

## Public discovery API

Provide public/anonymous-safe list and exact-ID detail boundaries.

### List

The list API should:

- return only published, non-cancelled proposals inside the normal discovery window;
- include derived status;
- include only rough public location;
- include required/useful controlled skill descriptors;
- support pagination;
- have deterministic ordering;
- not expose exact meeting details;
- not expose owner-only timestamps/internal flags.

Useful first filters:

- locality/municipality or equivalent broad location value;
- selected skill IDs.

Do not build AI/recommendation ranking.

A simple deterministic filter/order is preferable.

### Detail

Public exact-ID detail can return published historical proposals as well as currently discoverable ones.

Return:

- title/summary/description;
- schedule;
- derived status;
- rough public location;
- required/useful skills;
- sanitized creator summary if useful;
- exact meeting information only when exact visibility is public;
- otherwise an explicit machine-readable restricted-location indicator.

Do not expose private profile fields through proposal creator data.

Do not make the detail function a proposal directory/query escape hatch.

## Mobile scope

Add a focused proposal feature using existing Flutter conventions/Riverpod/go_router.

Functional routes may include equivalents of:

```text
/proposals
/proposals/:id
/proposals/mine
/proposals/create
/proposals/:id/edit
```

Exact route names are flexible.

### Public proposal list

Accessible signed out.

Render clickable cards with:

- title;
- summary;
- date/time;
- rough location;
- skill chips/labels;
- derived badge: Upcoming / Happening / Just Finished.

`Just Finished` should be visually green.

Include normal loading, empty, retryable error and pagination behavior.

### Proposal detail

Accessible signed out for published proposals.

Show full proposal content.

Location behavior:

- always show rough location;
- if exact location is public, show it in details;
- if restricted, show localized text equivalent to **"Exact location available after joining."**

Do not add a fake Join button implementation.

If a future participation CTA placeholder would mislead users, omit it.

### Create/edit

Authenticated complete-profile users can create/edit proposal drafts.

Provide a functional form for:

- title;
- summary;
- description;
- start/end;
- rough location fields;
- exact meeting text;
- exact location visibility;
- grouped skill selection;
- Required vs Useful classification.

No map picker.

No media/photo picker.

Use localized copy.

Allow save-draft separately from publish where practical.

### My proposals

Provide a minimal owner surface so drafts are not orphaned.

Show own proposals including at least:

- draft;
- published current;
- cancelled;
- historical completed.

Allow appropriate edit/publish/cancel actions according to canonical backend rules.

No analytics/statistics UI.

## Web scope

The public Next.js website should gain **read-only discovery** only.

Implement public equivalents of:

```text
/proposals
/proposals/[id]
```

Use Server Components for data loading where appropriate.

The pages should:

- work signed out;
- use the same sanitized public backend boundary as mobile;
- render proposal cards/details;
- preserve the same rough/exact location privacy rule;
- show the Just Finished status;
- avoid exposing private data in HTML/metadata.

Do not implement web proposal creation/editing in 04A.

`/admin` remains a real 404.

## Recurring activities roadmap split

Update the roadmap to record the new product distinction.

Recommended structure:

- **04 — Activity discovery/domain parent**
- **04A — One-Time Proposals and Discovery** — active implementation
- **04B — Recurring Activities** — not started, separate future work

04B should cover weekly/monthly activities and recurring occurrences.

Do not make 04B a blocker for beginning plan 05 after 04A is merged. Update the dependency wording so plan 05 can build on implemented 04A one-time proposals.

Parent 04 may remain in progress while 04B is outstanding if the roadmap uses parent aggregation.

Do not implement 04B in this PR.

## Testing

### Database / pgTAP

Cover at least:

- schema constraints and indexes;
- owner-only draft/private access;
- cross-user mutation denial;
- stale expected-creator identity rejection before mutation;
- complete-profile requirement for create/publish;
- draft -> published transition;
- invalid transition rejection;
- publish validation;
- publish idempotency behavior;
- cancellation rules;
- cancelled proposals excluded from discovery;
- derived upcoming/happening/just-finished/completed boundaries;
- exactly 24-hour Just Finished window;
- completed proposals absent from normal list but retained;
- rough public location exposure;
- public exact location exposure only when configured public;
- restricted exact location never appears in anonymous list/detail payloads;
- owner can still read restricted exact location;
- proposal skill required/useful relationships;
- catalog mutation remains denied;
- anonymous direct private-table access remains denied;
- function grants and fixed search paths;
- generated-type drift.

Use relative timestamps in tests so behavior is deterministic.

### Flutter

Cover:

- signed-out proposal browse;
- card -> detail navigation;
- Upcoming/Happening/Just Finished rendering;
- green Just Finished presentation;
- restricted-location message;
- public exact location display;
- proposal filters/pagination state;
- incomplete profile cannot create;
- create draft;
- restore/edit draft;
- skill Required/Useful selection;
- publish;
- owner edit before start;
- edit rejected/disabled after start;
- cancel;
- stale account/profile switch cannot mutate another user's proposal;
- safe error rendering.

### Web

Cover:

- signed-out proposal list/detail;
- sanitized restricted location;
- public exact location;
- Just Finished rendering;
- pagination/filter parameters;
- no private values/raw database errors;
- `/admin` remains 404;
- production build.

### Real local integration

Add a narrow local API integration harness proving with at least two authenticated users plus anon that:

1. user A creates a draft;
2. user B cannot read/mutate A's private draft;
3. A publishes a valid proposal;
4. anon list/detail sees rough location and skills;
5. restricted exact location is absent from anon payloads;
6. a public exact-location proposal exposes it only in detail, not the card/list;
7. stale user-A expected identity cannot mutate user B after an account switch;
8. cancellation removes a proposal from normal discovery;
9. time-window queries classify/exclude historical data correctly where deterministic testing allows.

Do not require Playwright unless current repository evidence shows it is clearly worthwhile.

## Non-goals

Do not implement:

- recurring/weekly/monthly activities;
- participation/join requests/membership;
- participant counts;
- proposal chat;
- notifications/push/email;
- actual Community template records or template UI;
- automatic template generation;
- maps;
- map SDK;
- geocoding/reverse geocoding;
- continuous location tracking;
- proposal photos/media;
- donations/payments;
- association/APS accounts or badges;
- moderation/reporting;
- organizer-only profile/photo audiences;
- skill proficiency;
- free-form proposal skills;
- AI matching/ranking;
- public user directory;
- web proposal authoring;
- production deployment.

## Documentation

Update the nearest repository sources of truth with:

- one-time proposal schema;
- stored vs derived lifecycle;
- 24-hour Just Finished behavior;
- historical proposal retention/template-source distinction;
- rough vs exact location model;
- exact-location privacy rule;
- proposal skill requirements reusing the 03C taxonomy;
- proposal public API boundaries;
- Flutter/web ownership;
- recurring-activity deferral/split.

Update the roadmap as described above.

While PR is open, mark 04A `In progress`.

After merge, 04A can be `Implemented`; recurring 04B remains not started.

Do not claim recurring activities or parent activity work complete if the roadmap parent includes 04B.

## Acceptance criteria

04A is ready for final review when:

- [ ] based on current merged `main`;
- [ ] one-time proposals have canonical draft/published/cancelled state;
- [ ] Upcoming/Happening/Just Finished/Completed are time-derived;
- [ ] Just Finished lasts exactly 24 hours after `ends_at`;
- [ ] normal discovery excludes older completed/cancelled proposals;
- [ ] historical completed proposals remain stored;
- [ ] no background completion job is required;
- [ ] proposal cards are public and contain only rough location;
- [ ] exact location is physically separate from rough location;
- [ ] exact visibility supports public vs future participants;
- [ ] restricted exact location is absent from anonymous API payloads;
- [ ] public proposal detail explains restricted location without leaking it;
- [ ] existing canonical skill catalog is reused with required/useful semantics;
- [ ] complete profiles can create/save/publish;
- [ ] incomplete profiles cannot create/publish;
- [ ] owner can manage own drafts/current proposals only;
- [ ] cross-user and stale-session mutation is rejected centrally;
- [ ] Flutter supports browse/detail/create/edit/my-proposals;
- [ ] web supports read-only public list/detail;
- [ ] no participation behavior is faked;
- [ ] no map/geocoder/media/template system is pulled forward;
- [ ] pgTAP, Flutter, web, integration, formatting, linting, analysis, production build, migration replay and type-drift checks pass;
- [ ] roadmap records recurring activities separately.

## Autonomy and stop conditions

Codex may decide ordinary implementation details such as:

- exact table/function/class/file names;
- UUID strategy consistent with the repo;
- pagination implementation;
- exact form/widget decomposition;
- exact bounded text lengths within reasonable product limits;
- whether public proposal reads are secure functions or another equally narrow sanitized API;
- exact PostGIS column representation using the already-installed extension;
- exact derived-status helper implementation.

Stop and report before:

- weakening the rough/exact location separation;
- exposing restricted exact location to anon/non-participants;
- adding a map/geocoding provider;
- inventing participation membership to unlock exact location;
- adding recurrence to the one-time proposal schema;
- creating a second skill taxonomy;
- making completed proposals into mutable templates;
- adding notification delivery;
- changing plan-05 participation semantics;
- implementing donation/payment;
- merging the PR.

## Deliverables

Produce:

1. one-time proposal database model/migration;
2. exact-meeting-location privacy model;
3. proposal required/useful skill relations;
4. canonical create/update/publish/cancel operations;
5. sanitized public list/detail API;
6. owner read/manage API;
7. pgTAP/RLS/lifecycle tests;
8. regenerated DB types;
9. Flutter proposal list/cards/detail;
10. Flutter create/edit/my-proposals;
11. read-only web proposal list/detail;
12. real local proposal privacy/lifecycle integration evidence;
13. documentation and roadmap split;
14. focused PR, preferably `codex/04a-one-time-proposals-discovery`;
15. completion report.

Do not merge the PR.

## Completion report

Return:

1. **Summary**
2. **Branch/base/PR**
3. **Changed areas/files**
4. **Proposal database model**
5. **Stored lifecycle**
6. **Derived temporal statuses**
7. **Just Finished behavior**
8. **Rough location model**
9. **Exact meeting location and privacy**
10. **Skill requirements**
11. **Canonical mutation operations**
12. **Public discovery API**
13. **Owner proposal management**
14. **Mobile proposal flow**
15. **Web discovery**
16. **Security/RLS**
17. **Tests**
18. **Real integration evidence**
19. **Validation/CI**
20. **Manual QA remaining**
21. **Recurring activities deferral / roadmap**
22. **Historical/template groundwork**
23. **Warnings/blockers for plan 05**
24. **Commit/PR reference**

Do not report 04B recurring activities as implemented.
