# PLANETS 04B1 — Tavoli / Recurring Activity Domain Foundation

**Roadmap area:** PLANETS 04B — Recurring Activities  
**Task type:** First scoped portion of 04B  
**Repository:** `lillo24/planets.community`  
**Required base when this prompt was written:** merged `main` at `38341f8e8f2febe09cb5ba05efdf6d448a3d3836`

## Objective

Implement the canonical backend/domain foundation for **Tavoli**, PLANETS' recurring local activities.

A Tavolo is conceptually different from a one-time proposal/project:

- a one-time proposal is an activity/project with one concrete start/end occurrence;
- a Tavolo is an ongoing recurring meeting/group, for example a philosophy discussion every Wednesday or a monthly cultural meetup;
- the recurring activity remains active across meetings until its organizer pauses or ends it.

This task intentionally implements **domain + database + API contracts only**.

Do **not** build the Tavoli mobile/web user interface in 04B1. A later **04B2 — Tavoli Mobile/Web Experience** will integrate the recurring domain into Browse and add list/detail/create/edit UI.

The purpose of the split is to review recurrence, time-zone, history, privacy, and authorization rules independently before clients depend on them.

---

## Repository state and required inspection

Work from the latest merged `main`. The SHA above is only the known merge base when this prompt was written.

Before changing anything, inspect at minimum:

1. root `AGENTS.md`;
2. `docs/architecture/core-stack.md`;
3. `docs/architecture/system-design.md`;
4. `docs/architecture/product-decisions.md`;
5. `docs/development/database.md`;
6. `docs/development/codex-tooling.md`;
7. `docs/implementation/roadmap.md`;
8. the complete 04A proposal migration and tests;
9. the existing controlled skill/profile schema;
10. generated database types;
11. proposal local integration harness;
12. `.github/workflows/validation.yml`.

Important current facts:

- PR #10 / 04A has been merged.
- One-time proposals already have a deliberately separate schema and must remain one-time.
- Do not refactor `proposals` into a polymorphic mega-table just to add recurrence.
- PostgreSQL remains canonical product state.
- RLS and narrow named operations enforce authorization.
- Public access uses deliberately sanitized boundaries.
- Exact meeting information is physically separated from rough public location.
- PostGIS is already available.
- Profiles remain human application identities tied 1:1 to `auth.users`.
- `docs/architecture/product-decisions.md` supersedes the old fixed-three-person chat assumption:
  - project chat is automatic;
  - chat is not gated by a hard-coded threshold of 3;
  - project completion does not delete chat history.
- No participation/chat implementation exists yet.

Use the existing Supabase/Postgres skills/guidance, but repository contracts and tests remain authoritative.

---

# Product decisions for Tavoli

## User-facing concept

The future UI may call these recurring activities **Tavoli**.

Database/domain naming should remain clear in English. Prefer names such as:

```text
recurring_activities
recurring_activity_schedules
recurring_activity_meeting_details
```

Exact names are Codex-owned.

Avoid a database entity literally named `table` because it is ambiguous in SQL and documentation.

## One recurring series, many meetings

A Tavolo is one persistent recurring activity definition.

Example:

```text
Philosophy Table
Every Wednesday at 19:00
Europe/Rome
Duration: 90 minutes
Trento · Povo
```

The Tavolo persists while individual meetings pass.

Do not create a separate user-facing activity record that must be manually recreated every week.

## Initial recurrence support

04B1 deliberately supports a small, predictable recurrence model.

Supported:

### Weekly

- once per week;
- exactly one weekday;
- one local start time;
- one duration.

Example:

```text
Every Wednesday at 19:00 for 90 minutes
```

### Monthly

- once per month;
- one calendar day between **1 and 28**;
- one local start time;
- one duration.

Example:

```text
Every month on day 12 at 18:30 for 120 minutes
```

Restricting the initial monthly day to 1–28 avoids undefined/implicit behavior for February and shorter months.

Do not implement in 04B1:

- every N weeks/months;
- multiple weekdays;
- nth weekday of month;
- last day of month;
- arbitrary RRULE input;
- annual recurrence;
- per-occurrence exceptions;
- skipped dates;
- one-off rescheduling;
- multiple meetings per week.

These can be added only through a later explicit recurrence expansion.

## Time zones

Recurrence must be defined in **local wall-clock time + IANA time zone**, not by repeatedly adding fixed UTC durations.

Example:

```text
Europe/Rome · Wednesday 19:00
```

must continue to mean 19:00 local time across DST transitions.

Store enough canonical information to regenerate intended local occurrences.

Do not use a fixed `+ 7 days` UTC algorithm for weekly recurrence.

Validate IANA time-zone identifiers centrally at publication/update boundaries.

---

# Lifecycle

Persist only explicit business state.

Use a small lifecycle equivalent to:

```text
draft
published
paused
ended
```

Exact enum/text representation is Codex-owned.

Semantics:

### Draft

- private to creator;
- may be incomplete;
- editable;
- not discoverable.

### Published

- active recurring series;
- publicly discoverable through sanitized API;
- has a valid recurrence schedule;
- has a next occurrence.

### Paused

- temporary organizer-controlled stop;
- not included in normal public discovery;
- retains its identity, content, schedule history, and owner data;
- may later be resumed.

A paused activity should not silently generate future "active" meeting expectations.

### Ended

- explicit terminal organizer action;
- leaves normal discovery permanently;
- remains canonical historical data;
- cannot be resumed in 04B1.

Do not delete a recurring activity merely because meetings have passed.

Do not derive the series lifecycle from clock time: recurrence is open-ended until paused/ended.

No Cron job is required to "complete" a Tavolo.

---

# Recurrence schedule history

A recurring series must not rewrite its past schedule when the organizer changes future meeting time.

Use a schedule-history model rather than one mutable recurrence row that destroys history.

A reasonable design is versioned schedule records containing concepts such as:

- recurring activity ID;
- recurrence type (`weekly` / `monthly`);
- weekday OR day-of-month;
- local start time;
- duration;
- IANA time zone;
- effective local date/time boundary;
- creation/supersession timestamps.

Exact schema is Codex-owned.

Important invariant:

> A future schedule change creates/supersedes schedule configuration for future meetings without pretending that past meetings used the new schedule.

04B1 does **not** need a full per-occurrence event table.

Occurrences may be derived from schedule versions for bounded reads.

If repository/database constraints make a clean versioned schedule materially more complex than expected, stop and report rather than collapsing history into one mutable row.

---

# Occurrence derivation

Provide one canonical backend implementation for deriving finite occurrence windows.

The API must never produce an unbounded infinite series.

Support bounded operations such as:

```text
next occurrence
next N occurrences
occurrences in [from, until)
```

with hard maximums.

The exact helper signatures are Codex-owned.

Derived occurrence data should include at least:

- stable recurring activity ID;
- schedule-version identity if useful;
- local date/time representation or enough values to reconstruct it;
- `starts_at` UTC instant;
- `ends_at` UTC instant;
- event time zone.

For 04B1, individual derived occurrences do **not** need globally persisted UUID rows.

Do not pretend derived occurrences are independently editable entities.

## DST acceptance rule

For a weekly Tavolo at:

```text
Europe/Rome · Wednesday 19:00
```

occurrences before and after daylight-saving transitions must both render as 19:00 Europe/Rome even though their UTC offsets differ.

Add explicit automated coverage.

---

# Tavolo content model

Store enough canonical fields for 04B2 to build list/detail/create/edit later.

At minimum:

- ID;
- creator profile ID;
- lifecycle;
- title;
- short summary;
- full description;
- optional short theme/topic label;
- rough structured public location;
- optional approximate PostGIS point;
- created/updated/published/paused/ended timestamps as justified.

The optional topic/theme is simple descriptive text, not a new taxonomy.

Do not invent a Tavoli topic catalog in this plan.

Do not force the proposal `skills` taxonomy onto Tavoli. A philosophy discussion topic is not necessarily a "skill".

Skills/competences may be added to Tavoli later only if product requirements justify it.

---

# Location privacy

Reuse the accepted **rough vs exact** privacy model conceptually without coupling the tables.

## Rough public location

A publishable Tavolo has public rough location suitable for discovery, for example:

```text
Trento · Povo
Centro storico
Parco delle Albere area
```

Keep structured/map-ready fields consistent with 04A where useful:

- country code;
- locality;
- optional administrative area/neighborhood;
- public display label;
- optional approximate PostGIS point.

No geocoder or map provider.

## Exact meeting location

Exact operational meeting details remain physically separate from public rough location.

Support:

```text
public
participants
```

as in one-time proposals.

If `public`, sanitized detail may expose exact meeting text.

If `participants`, public/anonymous detail returns no protected exact value and only a machine-readable restricted indicator.

Plan 05 will define accepted participants and the participant-authorized read path.

The creator retains private owner access.

Do not create fake membership in 04B1.

---

# Canonical operations

Use narrow backend operations, following 03C/04A expected-identity protection.

Likely responsibilities:

```text
create_recurring_activity_draft
update_own_recurring_activity
publish_recurring_activity
pause_recurring_activity
resume_recurring_activity
end_recurring_activity
list_public_recurring_activities
get_public_recurring_activity
list_own_recurring_activities
get_own_recurring_activity
```

Exact names/signatures are Codex-owned.

All owner mutations must:

- authenticate with `auth.uid()`;
- bind the rendered/expected creator profile ID;
- reject stale account-switch forms before mutation;
- require ownership;
- use fixed/empty `search_path` for security-definer functions;
- have explicit narrow execute grants;
- update related records atomically;
- fail closed;
- never use service-role credentials in clients.

## Create/update

Complete profiles can create Tavolo drafts.

Incomplete profiles cannot create/publish.

Drafts may be incomplete.

Owner updates to title/summary/description/current location are allowed in draft, published, or paused states.

Schedule changes after publication must preserve prior schedule history as described above.

Ended activities are immutable except for future moderation/admin operations outside this plan.

## Publish

Publishing from draft requires:

- complete profile;
- complete content;
- valid recurrence;
- recognized IANA time zone;
- valid duration;
- valid rough location;
- exact meeting information and visibility.

Record `published_at`.

Publishing must not create notification delivery.

## Pause/resume

Pause:

- works only from published;
- removes the Tavolo from normal discovery;
- records explicit state/timestamp.

Resume:

- works only from paused;
- validates that the current/future schedule can generate a future occurrence;
- returns to normal discovery.

Pause/resume must be idempotency-safe or explicitly reject invalid repeats consistently.

## End

End:

- works from published or paused;
- terminal;
- removes from normal discovery;
- retains history;
- cannot be resumed in 04B1.

No delete-as-end behavior.

---

# Public discovery API

04B1 provides backend contracts only.

## List

Public/anon-safe list returns only active published Tavoli.

Return fields suitable for a future compact card:

- ID;
- title;
- summary;
- topic/theme if present;
- rough public location;
- next occurrence start/end;
- event time zone.

Do not expose:

- exact restricted location;
- owner-only lifecycle timestamps;
- schedule-internal history;
- private profile fields.

Order primarily by next occurrence with deterministic tie-breaker.

Support pagination or another bounded deterministic page contract appropriate for dynamically derived next-occurrence ordering.

Support at least a broad locality filter.

Do not add search infrastructure or recommendation ranking.

## Detail

Exact-ID public detail may return:

- published active Tavoli;
- paused Tavoli;
- ended historical Tavoli.

It should expose:

- content;
- lifecycle presentation state;
- rough location;
- current schedule summary;
- bounded next occurrences for active published activities;
- exact meeting text only when configured public;
- restricted-location indicator otherwise;
- sanitized creator display identity where allowed.

A paused/ended Tavolo has no public "next active occurrence".

Direct exact-ID detail must not become an enumerable directory.

---

# Owner API

Owner reads must expose enough information for 04B2 to build management UI later:

- drafts;
- published;
- paused;
- ended;
- current content/location;
- current schedule;
- schedule history necessary for safe editing;
- exact meeting information.

Owners must never read another user's private drafts or restricted meeting records.

---

# Audit/outbox

Use current primitives where appropriate.

Publication, pause, resume, end, and material schedule changes may write minimal transaction-local audit/outbox events.

Payloads should contain identifiers/state metadata only.

Do not put:

- exact meeting text;
- descriptions;
- message content;
- unnecessary user data

into audit/outbox payloads.

Do not implement notification delivery.

---

# No mobile/web feature UI in 04B1

This PR must not add Tavoli routes/screens/forms/cards.

Allowed client-facing changes:

- regenerated database types;
- test fixtures/integration harness code;
- documentation/API-contract notes required by generated types.

Do not partially expose unfinished Tavoli UI in the navigation shell.

04B2 will own:

- Browse UI distinction between one-time Proposals and Tavoli;
- Tavoli list/cards/detail;
- create/edit/manage Tavoli;
- mobile functional UI;
- read-only web discovery.

---

# Documentation reconciliation required in this PR

The merged PR #10 left some documentation intentionally/stalely marked `In progress`.

Update the canonical docs so they reflect the real merged state.

At minimum:

## Roadmap

- 04A → **Implemented**;
- record merge completion;
- split 04B into:
  - **04B1 — Tavoli / Recurring Activity Domain Foundation** — In progress;
  - **04B2 — Tavoli Mobile/Web Experience** — Not started;
- parent 04 remains In progress until recurring work is complete.

Also record a future explicit **Material Resources** work item so the team does not lose the already-identified domain gap around requested/donated/loaned material resources.

Do not implement material resources in 04B1.

Do not yet make a speculative material-resource plan a hard dependency of Plan 05 unless existing accepted product documentation already requires that exact ordering.

## Chat decision

Reconcile `system-design.md` and `roadmap.md` with `product-decisions.md`:

Remove/replace the old assumption that proposal chat is created only after a fixed threshold such as 3 people.

Canonical direction:

- chat creation will be automatic;
- no manual Create Chat action;
- no fixed threshold of 3 controls chat availability;
- ending a project does not delete chat/messages;
- exact participation event and post-membership access remain Plan 05/07 decisions.

No chat code in this PR.

---

# Testing

## pgTAP / database

Cover at least:

- tables/types/constraints/indexes;
- RLS owner isolation;
- anon direct-table denial;
- stale expected creator rejection;
- complete-profile create/publish requirement;
- draft publication validation;
- weekly recurrence derivation;
- monthly recurrence derivation;
- monthly 1–28 invariant;
- DST/local-wall-clock preservation using at least `Europe/Rome`;
- occurrence bounding/max limits;
- schedule version/history preservation;
- invalid overlapping/effective schedule states;
- pause lifecycle;
- resume lifecycle;
- end terminal behavior;
- published list inclusion;
- paused/ended list exclusion;
- public exact-ID paused/ended behavior;
- rough location exposure;
- public exact location exposure only when configured public;
- participant-restricted exact location never returned publicly;
- creator private access;
- generated-type drift;
- function grants/search-path security.

## Real local integration

Add a focused two-user + anon harness proving:

1. user A creates a recurring draft;
2. user B cannot read/mutate A's private draft;
3. A publishes a weekly Tavolo;
4. anon list sees rough location and a next occurrence;
5. restricted exact meeting details are absent publicly;
6. public exact-location configuration is exposed only through the intended detail boundary;
7. pausing removes it from normal list;
8. paused exact-ID detail remains sanitized;
9. resuming returns it to discovery;
10. a future schedule change preserves old schedule history;
11. ending removes it permanently from normal list;
12. stale account identity cannot mutate another user's Tavolo.

No real-time waits are acceptable. Use deterministic timestamps/reference windows in tests.

---

# Non-goals

Do not implement:

- Tavoli mobile UI;
- Tavoli web UI;
- participation/join requests;
- membership;
- participant-authorized location reads;
- chat;
- notifications;
- resources/material contributions;
- recurring occurrence attendance;
- occurrence-level cancellation/rescheduling;
- maps/geocoding;
- media;
- donations/payments;
- legal-entity accounts;
- association delegation;
- AI matching;
- free-form recurrence/RRULE;
- recurrence intervals other than once weekly/monthly;
- final visual design.

---

# Acceptance criteria

04B1 is ready for review when:

- [ ] based on latest merged `main`;
- [ ] 04A documentation is marked Implemented;
- [ ] 04B is split into 04B1/04B2 in roadmap;
- [ ] future material-resources gap is recorded without implementation;
- [ ] old fixed-three-person chat wording is removed from canonical docs;
- [ ] recurring activities are physically separate from one-time proposals;
- [ ] lifecycle supports draft/published/paused/ended;
- [ ] published Tavoli are open-ended until paused/ended;
- [ ] weekly recurrence works in local wall-clock time;
- [ ] monthly recurrence supports one day 1–28;
- [ ] IANA time-zone behavior is validated centrally;
- [ ] DST tests prove local meeting time remains stable;
- [ ] schedule changes preserve history rather than rewriting past recurrence;
- [ ] occurrence generation is bounded;
- [ ] rough/exact location separation matches accepted privacy direction;
- [ ] restricted exact location is absent from public payloads;
- [ ] stale/cross-account mutation is rejected centrally;
- [ ] public list/detail and owner APIs are implemented;
- [ ] no Tavoli UI is exposed yet;
- [ ] pgTAP + real local integration + migration replay + lint + generated types pass;
- [ ] existing Mobile/Web/04A tests remain green.

---

# Autonomy and stop conditions

Codex may decide ordinary implementation details such as:

- exact table/function/type names;
- schedule-version schema representation;
- indexes;
- pagination shape;
- bounded occurrence helper signatures;
- text limits;
- whether recurrence helpers live in `private`;
- audit/outbox event names.

Stop and report before:

- refactoring one-time `proposals` into a polymorphic activity table;
- using fixed UTC `+7 days` recurrence that breaks DST wall-clock behavior;
- allowing unbounded occurrence generation;
- discarding schedule history on future schedule edits;
- inventing participation/membership;
- implementing Tavoli UI;
- implementing material resources;
- forcing proposal skills onto Tavoli;
- introducing a recurrence library/provider outside PostgreSQL without strong repository evidence;
- weakening exact-location privacy;
- weakening expected-identity ownership checks;
- inventing organization/legal-entity identity;
- merging the PR.

---

# Deliverables

Produce:

1. recurring activity schema;
2. versioned recurrence schedule model;
3. exact-meeting privacy model;
4. recurrence/DST helper functions;
5. canonical create/update/publish/pause/resume/end operations;
6. sanitized public list/detail API;
7. private owner list/detail API;
8. pgTAP security/recurrence/lifecycle tests;
9. two-user + anon local integration harness;
10. regenerated DB types;
11. system-design/chat decision reconciliation;
12. roadmap 04A/04B1/04B2/material-resources cleanup;
13. focused PR, preferably `codex/04b1-recurring-activity-domain`;
14. structured completion report.

Do not merge the PR.

---

# Completion report

Return:

1. **Summary**
2. **Branch/base/PR**
3. **Changed files**
4. **Recurring activity schema**
5. **Lifecycle**
6. **Weekly recurrence**
7. **Monthly recurrence**
8. **Time-zone/DST model**
9. **Schedule history/versioning**
10. **Occurrence derivation/bounds**
11. **Rough/exact location privacy**
12. **Canonical mutation operations**
13. **Public API**
14. **Owner API**
15. **Security/RLS**
16. **Audit/outbox behavior**
17. **pgTAP tests**
18. **Real integration evidence**
19. **Generated types / drift**
20. **Existing 04A regression validation**
21. **Documentation reconciliation**
22. **04B2 handoff**
23. **Material-resources roadmap note**
24. **Warnings/blockers for Plan 05**
25. **Commit/PR reference**

Do not report Tavoli UI, participation, chat, or material resources as implemented.
