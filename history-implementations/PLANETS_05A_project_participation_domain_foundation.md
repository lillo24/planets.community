# PLANETS 05A — Project Participation Domain Foundation

**Roadmap area:** PLANETS 05 — Participation Lifecycle  
**Task type:** Backend/domain foundation before mobile participation UI  
**Repository:** `lillo24/planets.community`  
**Required implementation base:** latest merged `main`  
**Known `main` when this prompt was written:** `4fdfdaed188581e3c430f2c5403013a80d6cd3f7`

## Objective

Implement the canonical backend/domain foundation for **project participation** across both existing PLANETS activity models:

- one-time Projects (`proposals`);
- recurring Projects / Tavoli (`recurring_activities`).

This task must establish one shared participation model without merging the two concrete activity schemas.

After 05A:

- every existing and future one-time Proposal or Tavolo has a thin canonical **project identity** usable by cross-cutting domains;
- authenticated complete-profile users can request to join an eligible project;
- project creators can accept or reject pending requests;
- requesters can withdraw pending requests;
- accepted participants can leave;
- project creators can remove accepted participants;
- participation history remains canonical rather than being rewritten/deleted;
- duplicate/racing transitions are safe;
- requester/owner privacy is enforced by RLS and narrow RPCs;
- accepted participants can read participant-restricted operational meeting information through one shared backend boundary;
- one-time and recurring projects use the same participation contracts;
- audit/outbox events exist for Plan 06 notifications and later Plan 07 chat triggering;
- no chat is created yet;
- no material-resource contribution model is invented yet;
- no mobile/web participation UI is added yet.

This is **05A only**. A later **05B — Mobile Project Participation Experience** will add Join/request/review/member UI.

---

# Product decisions from the 08/09 meeting

Treat these as product direction for this implementation.

## Progetti is the umbrella product concept

User-facing PLANETS treats one-time activities and Tavoli as kinds of **Progetti**.

The existing concrete backend models remain separate because their scheduling and lifecycle semantics are genuinely different.

Do **not** refactor:

```text
proposals
recurring_activities
```

into one polymorphic content mega-table.

Instead, introduce only the minimum shared project identity needed by participation and future cross-project features.

## Participation and resources are separate concepts

A person may both:

- participate in a project;
- bring a requested resource/help contribution.

These are related but not the same state.

The 08/09 direction says future join requests may include which requested resources the person can bring, and that information should accompany the participation request.

However 04C / the broader Resources + Scambio-Dona domain is not implemented yet.

Therefore 05A must:

- give join requests stable canonical IDs that future resource-offer rows can reference;
- keep participation membership independent from resource ownership/contribution;
- **not** add free-form pseudo-resource fields merely to anticipate 04C;
- **not** block participation on a future resource model.

An optional human join-request message is allowed and expected; it is not a resource schema.

## Post-project contribution confirmation is future work

The meeting also establishes the direction that, after project completion, the creator should eventually confirm **who actually did what**.

That future verification may feed:

- participation statistics;
- badges;
- contribution history;
- resource/help attribution.

05A must preserve enough participation history to support this later, but must **not** invent a contribution-verification taxonomy or UI in this PR.

Record this explicitly as later participation/profile work rather than treating simple acceptance as final proof of contribution.

## Online / in-person is accepted future project behavior

Projects may be **Online** or **In Presence**.

The current concrete activity schemas still mostly model physical rough/exact location.

05A participation must therefore be location-agnostic:

- do not encode physical locality into membership;
- do not make participation validity depend on physical coordinates;
- use the existing protected operational-meeting boundary generically;
- leave project attendance-mode/schema/UI alignment to a focused later plan.

Do not broaden this PR into the online/in-person migration.

## Capacity / “Pieno” remains unresolved

The meeting mentions a future **Full / no places available** state.

No canonical capacity field or rule exists yet.

Do not invent:

- maximum participants;
- waitlists;
- automatic fullness;
- role quotas.

05A implements participation without a capacity limit.

---

# Repository state and required inspection

Work from latest merged `main`; the SHA above may be behind the prompt archive commit.

Before implementation, preserve this exact prompt unchanged at:

```text
history-implementations/PLANETS_05A_project_participation_domain_foundation.md
```

If the prompt is supplied as a file, copy its exact bytes/content rather than rewriting or summarizing it.

Before changing anything, inspect at minimum:

1. root `AGENTS.md`;
2. `docs/architecture/product-decisions.md`;
3. `docs/architecture/system-design.md`;
4. `docs/architecture/core-stack.md`;
5. `docs/development/database.md`;
6. `docs/development/codex-tooling.md`;
7. `docs/implementation/roadmap.md`;
8. 01B identity/audit/outbox migration and tests;
9. 03C profiles/skills/visibility migration and tests;
10. 04A one-time proposal migration, tests, public/owner RPCs, and integration harness;
11. 04B1 recurring-activity migration, tests, public/owner RPCs, and integration harness;
12. current generated database types;
13. current CI validation workflow;
14. merged 04B2 mobile/web client code only as context for future consumers.

Important current facts:

- Plans 00–04B2B are merged and green.
- PR #13 web Tavoli discovery merged at `ccee48f68699702efeaeda160db1f27115a4d5df`.
- PR #14 roadmap status merged at `4fdfdaed188581e3c430f2c5403013a80d6cd3f7`.
- 04B2A and 04B2B manual QA are recorded passed.
- Profiles remain human application identities tied 1:1 to `auth.users`.
- One-time proposals use expected-identity-bound owner mutations.
- Tavoli use the same stale-account protection pattern.
- Exact operational meeting information is physically separated from public rough location in both domains.
- Public participant-restricted exact meeting values are absent from public payloads.
- Audit/outbox are transaction-local canonical primitives, not notification delivery.
- Chat creation is automatic in the future, has no fixed-three-person gate, and project completion does not delete chat history.
- Exact chat-creation event remains Plan 05/07 work.

Use the Supabase/Postgres skills, but repository contracts/tests remain authoritative.

---

# 1. Thin common project identity

Participation, chat, resources, stats, and badges should not each invent a separate polymorphic target convention.

Introduce a minimal common registry, preferably something equivalent to:

```text
projects
```

or another clear name.

It is an **identity/relationship anchor**, not a replacement content table.

## Required semantics

Each row represents exactly one concrete existing activity:

```text
one_time
recurring
```

A strong design is to keep the shared project UUID equal to the concrete activity UUID.

That means:

```text
project.id == proposal.id
```

or:

```text
project.id == recurring_activity.id
```

This preserves current URLs/client IDs while allowing cross-cutting tables to reference one stable `project_id`.

Exact schema is Codex-owned.

## Registry fields

Keep it narrow.

At minimum it may contain:

- project ID;
- project kind;
- creator profile ID;
- created timestamp if useful.

Do not copy:

- title;
- description;
- schedule;
- skills;
- lifecycle;
- rough location;
- exact location.

Those remain owned by their concrete domain tables.

If storing `creator_profile_id` in the registry materially simplifies secure participation operations, enforce synchronization centrally and document which record is canonical.

## Backfill

Backfill all existing:

- `proposals`;
- `recurring_activities`.

Detect and fail migration if the same UUID somehow exists in both concrete tables.

Do not silently pick one type.

## Future inserts

Every future trusted insert of a Proposal or Tavolo must create its project identity atomically.

Prefer a narrow database-level mechanism that also protects non-client trusted inserts/tests, rather than relying only on Flutter.

Possible implementation:

- source-table insert triggers;
- or revised canonical create functions plus a hard invariant proving no source row can exist without a project identity.

Exact implementation is Codex-owned.

The result must survive:

- migration replay from zero;
- test fixture insertion;
- future server-side creation.

## Deletion/history

No ordinary user-facing project deletion exists.

A source project with participation history must not be deletable in a way that silently orphans participation.

Use restrictive relationships or equivalent fail-closed behavior.

Account deletion remains Plan 10 work.

## Access

The project registry is not a new public directory.

Do not grant anon/authenticated direct enumeration merely because its fields look harmless.

Use it behind named operations/RLS helpers.

---

# 2. Join request model

Add a canonical project join-request model.

A request is an **attempt to become a participant**, not the membership itself.

At minimum preserve:

- stable request ID;
- project ID;
- requester profile ID;
- status/state;
- optional requester message;
- created timestamp;
- decision/terminal timestamp;
- decision actor where justified.

## Request states

Use a small explicit state model equivalent to:

```text
pending
accepted
rejected
withdrawn
```

Exact enum/text representation is Codex-owned.

Do not store “removed” or “left” on the request; those belong to membership history after acceptance.

## Optional message

Allow an optional short participation message from requester to project creator.

This is private participation data.

It may explain:

- why they want to join;
- how they think they can help in human terms.

Do not treat it as a structured resource contribution.

Bound/trim it centrally.

Do not expose it publicly or to unrelated participants.

## Request eligibility

A requester must:

- be authenticated;
- have a complete profile;
- not be the project creator;
- not already have a pending request;
- not already be a current accepted member;
- target an existing eligible project.

### One-time project eligibility

A request may be created only while the one-time proposal is:

- published;
- not cancelled;
- not already ended.

Use canonical proposal timestamps/state; do not duplicate a separate participation lifecycle flag.

Whether requesting during the Happening interval remains acceptable for now until end time. Do not close participation merely at start unless existing accepted product docs explicitly require it.

### Recurring/Tavolo eligibility

A request may be created only while the Tavolo is:

```text
published
```

Paused/ended Tavoli do not accept new requests.

Existing memberships survive a pause.

## Re-request behavior

Preserve history as separate attempts.

Allow a new request only when there is:

- no pending request;
- no current membership.

A previously rejected or withdrawn request does not need to be deleted.

A participant who voluntarily left may request again while the project remains eligible.

A previous terminal request or ended membership does not need to be deleted.

For 05A, allow a fresh request after withdrawal, rejection, voluntary leave, or creator removal whenever the project is still eligible and there is no pending request/current membership. Permanent project-level exclusion belongs to later blocking/moderation rules; do not reinterpret ordinary removal as a permanent ban.

Implement this with canonical history, not a client-only flag.

---

# 3. Membership model

Acceptance creates canonical membership/history.

The creator is the organizer/owner by project ownership and does not need a duplicate membership row merely to count as organizer.

05A only needs one accepted participant role.

Do not invent:

- moderator;
- co-organizer;
- volunteer lead;
- resource owner;
- observer.

Future explicit roles can extend the model.

## Membership fields

Preserve enough history for:

- current authorization;
- project stats;
- future contribution verification;
- moderation/audit.

Likely concepts:

- membership ID;
- project ID;
- participant profile ID;
- originating accepted join-request ID;
- joined/accepted timestamp;
- left timestamp;
- removed timestamp;
- removal actor/reason code if justified.

Exact schema is Codex-owned.

## Current membership

A membership is current when:

- it was accepted;
- it has not been voluntarily left;
- it has not been removed.

Project completion/ending does **not** delete or rewrite it.

This is deliberate historical membership.

A one-time project becoming Completed by clock time does not require a cron job to mutate all memberships.

A Tavolo becoming paused does not end memberships.

A Tavolo becoming ended keeps membership history canonical.

## Uniqueness

At most one current membership per:

```text
project + profile
```

Race two acceptance attempts safely.

Do not allow duplicate current membership rows.

Historical past membership attempts may coexist if a person leaves and later rejoins.

---

# 4. Canonical participation transitions

Use narrow named operations.

Likely responsibilities:

```text
request_to_join_project
withdraw_project_join_request
accept_project_join_request
reject_project_join_request
leave_project
remove_project_member
```

Exact names are Codex-owned.

Prefer `project` naming rather than `proposal` naming because the same operations cover one-time Projects and Tavoli.

All authenticated mutations must:

- bind `auth.uid()`;
- use expected rendered identity where stale-account risk exists;
- verify project ownership/request ownership/member ownership centrally;
- lock relevant rows for race-sensitive transitions;
- use explicit grants;
- use fixed/empty `search_path` for security-definer functions;
- fail closed;
- never rely on client-side authorization.

## Request

Requester creates one pending request atomically.

Write a minimal audit/outbox event.

Do not notify yet.

## Withdraw

Only requester can withdraw own pending request.

Repeated withdrawal may be idempotent or consistently reject already-terminal state; choose and test one behavior.

## Accept

Only project creator can accept a pending request.

Acceptance must atomically:

1. lock/validate request and project;
2. prove requester is still eligible;
3. set request accepted;
4. create exactly one current membership;
5. record minimal audit/outbox events.

No partial accepted-without-membership state.

Do not create chat in 05A.

Emit a stable domain/outbox event that Plan 07 can later consume/use as the candidate automatic-chat trigger without changing membership history.

## Reject

Only project creator can reject a pending request.

No membership is created.

## Leave

Only the current participant can leave own membership.

Creator ownership is separate and cannot “leave” via this operation.

A participant may leave only while the membership is current.

Preserve history.

## Remove

Only project creator can remove another current participant.

Record creator actor.

Removal ends that membership but does not become a permanent project-level ban.

Do not implement blocking/suspension.

---

# 5. Project lifecycle interactions

Centralize helper logic for determining project kind, creator, and join eligibility.

Do not copy complex lifecycle checks into every RPC independently if one private helper can safely resolve them.

## One-time Proposal

No new requests/acceptances at or after `ends_at`.

Cancelled proposals are closed.

Existing historical memberships remain.

## Tavolo

Published:

- requests/acceptance allowed.

Paused:

- no new request/acceptance;
- existing memberships remain;
- participants do not need to rejoin after resume.

Ended:

- no request/acceptance;
- historical memberships remain.

Do not alter Tavolo pause/resume/end code unless participation invariants genuinely require a small integration hook.

If such hooks are required, preserve existing 04B1 behavior and tests.

---

# 6. Participant-authorized operational meeting details

Plan 04 deliberately withheld participant-restricted exact meeting information.

05A should now add one canonical authenticated read boundary for project members.

Prefer one project-level operation that internally resolves concrete type, for example:

```text
get_project_participant_meeting_details
```

Exact name is Codex-owned.

## Authorized readers

Allow:

- project creator;
- current accepted participant.

Do not allow:

- pending requester;
- rejected requester;
- withdrawn requester;
- removed former participant;
- unrelated authenticated user;
- anonymous user.

A voluntarily-left former participant should not retain the participant-only operational location through this boundary.

Public-exact information remains available through existing public detail APIs independently.

## Returned data

Return only operational meeting information needed by an authorized participant.

For current schemas this may include:

- exact meeting text;
- exact point where appropriate;
- concrete project kind if useful.

Do not return:

- owner-only schedule history;
- request messages;
- private profile data;
- audit metadata.

Keep this boundary location/meeting-mode agnostic so future Online projects can reuse it for protected operational meeting instructions.

Do not weaken existing public APIs or table RLS.

---

# 7. Read APIs and privacy

Provide narrow reads needed for 05B.

## Requester

Can read own requests including own private message and status.

## Creator

Can read requests for own projects, including requester display identity sanitized according to the authenticated participation use case and the private request message.

Do not expose Auth email.

A project creator may need the requester’s display name even if public profile display-name visibility is private; this is a private participation workflow, not anonymous discovery.

If this requires a deliberate authenticated organizer projection, define it narrowly rather than weakening `get_public_profile`.

## Participant

Can read own current/historical membership state.

## Creator member list

Creator can read own project members and request history needed for review/admin UI.

Do not expose membership directories publicly in 05A.

## Other participants

Do not automatically receive the complete member list unless a concrete 05B requirement needs it.

Chat membership visibility can be handled in Plan 07.

---

# 8. Audit and outbox

Record minimal transaction-local events for:

- join requested;
- request withdrawn;
- request accepted;
- request rejected;
- participant left;
- participant removed.

Payloads should contain identifiers and state metadata only.

Do not include:

- private request message;
- exact meeting text;
- profile bio;
- email;
- skill lists;
- future resource contribution details.

Use stable event names suitable for Plan 06 and Plan 07.

No worker/queue/push/email delivery in 05A.

---

# 9. Stats and future contribution verification

Do not store denormalized profile counters in 05A.

Canonical request/membership history should support later derived values such as:

- projects joined;
- current memberships;
- participation history.

However the 08/09 product direction says final contribution credit should eventually involve creator confirmation of who actually did what.

Therefore:

- do not equate `accepted membership` with a future “verified contribution” badge;
- do not increment badge levels;
- do not implement donation priority;
- do not fabricate completion verification.

Update architecture/roadmap docs to preserve this distinction.

---

# 10. No participation UI in 05A

This PR is database/domain only.

Do not add:

- Join buttons;
- request forms;
- owner review screens;
- participant lists;
- mobile routing;
- web participation;
- chat UI.

Allowed client changes:

- regenerated database types;
- compile fixes if generated function types affect existing code;
- test fixtures;
- documentation.

05B will consume these contracts.

---

# 11. Product/roadmap reconciliation

Update canonical documentation so future plans do not revert to pre-08/09 assumptions.

## Product decisions

Add accepted direction that:

- Progetti is the user-facing umbrella for one-time Projects and Tavoli;
- concrete one-time and recurring backend models remain separate;
- participation is a shared project-level domain;
- resources/contributions are separate from membership but may attach to join requests later;
- post-project creator confirmation of actual contribution is future work;
- Online/In-Presence is an accepted project direction but not implemented by 05A;
- project capacity/fullness remains unresolved.

Do not state unresolved meeting notes as final.

## Roadmap

Split Plan 05:

### 05A — Project Participation Domain Foundation

This task.

### 05B — Mobile Project Participation Experience

Future:

- Join/request message;
- requester status/withdraw;
- creator review;
- member state;
- leave/remove;
- participant operational meeting-info display.

### 05C — Verified Project Contribution / Completion Review

Record as future/not started, with semantics still dependent on contribution/resource decisions.

Do not implement 05C.

Broaden the existing 04C note so it does not lose the 08/09 **Scambio-Dona** direction:

- project resource needs/contributions;
- donation listings;
- exchange listings;
- saved searches/notifications later;
- future matching between listings and project needs.

Do not implement 04C here.

Also record future project-presentation work for:

- Tavoli as a Progetti type/filter in final information architecture;
- Online/In-Presence project mode.

Do not redesign current navigation in 05A.

---

# 12. Database tests

Add comprehensive pgTAP coverage.

At minimum:

## Shared project identity

- registry exists and is private/fail-closed;
- every seeded/existing proposal has exactly one one-time project identity;
- every seeded/existing Tavolo has exactly one recurring identity;
- future trusted Proposal insert creates/has identity;
- future trusted Tavolo insert creates/has identity;
- cross-kind UUID collision fails;
- project identity cannot be anonymously enumerated;
- source deletion cannot orphan participation history.

## Request security

- complete profile required;
- creator cannot request own project;
- unrelated user cannot read private requests;
- one pending request maximum per user/project;
- current member cannot request again;
- one-time published-before-end request allowed;
- cancelled/ended one-time request denied;
- published Tavolo request allowed;
- paused/ended Tavolo request denied;
- private message trimmed/bounded;
- withdrawn/rejected history preserved.

## Decisions

- only creator can accept/reject;
- accept is atomic with membership creation;
- duplicate/racing accept cannot duplicate membership;
- reject creates no membership;
- stale expected identity fails where applicable;
- terminal request transitions cannot be rewritten illegally.

## Membership

- current membership uniqueness;
- member can leave self;
- unrelated user cannot leave another user;
- creator can remove;
- unrelated user cannot remove;
- removal preserves history;
- voluntary leave can later permit a fresh request;
- creator removal preserves history and still permits a later fresh request while eligible;
- pause does not destroy Tavolo membership;
- project completion/end does not delete history.

## Meeting information

- creator can read participant-protected meeting information;
- current accepted member can read;
- pending/rejected/withdrawn cannot read;
- left/removed former participant cannot read;
- anon/unrelated authenticated cannot read;
- no public RLS/API is weakened.

## Audit/outbox

- one expected event per successful state transition;
- idempotent repetitions do not duplicate events where designed idempotent;
- private request messages/exact meeting details never appear in payloads;
- private tables remain unexposed.

## Grants/security

- all security-definer functions fixed/empty search path;
- execute grants are explicit;
- direct client writes denied;
- generated type drift covered.

---

# 13. Real local integration harness

Add a focused multi-user + anon script, preferably:

```text
scripts/verify-local-participation.mjs
```

Use at least:

- creator A;
- requester B;
- unrelated user C;
- anonymous client.

Exercise both project types.

Prove:

1. existing Proposal/Tavolo project identities resolve;
2. B requests one-time Proposal with private message;
3. C cannot read the request/message;
4. creator reads and accepts;
5. membership appears exactly once;
6. B can read participant-restricted operational meeting info;
7. B leaves;
8. B loses restricted meeting access;
9. B may request again while one-time project remains eligible;
10. creator rejects a request path;
11. B requests published Tavolo;
12. creator accepts;
13. pausing Tavolo blocks new requests but preserves B membership;
14. resuming preserves membership;
15. creator removes B;
16. B loses protected meeting access;
17. B can make a fresh request after creator removal while the Tavolo is again published/eligible;
18. ending Tavolo preserves participation history;
19. stale account identity cannot mutate another account’s request/membership;
20. public anonymous Proposal/Tavolo discovery behavior remains unchanged.

Use deterministic future timestamps.

Do not log:

- OTP codes;
- access tokens;
- private request messages;
- exact protected meeting data.

---

# 14. Existing validation

Keep all current behavior green:

- migration replay from zero;
- DB lint;
- all existing pgTAP tests;
- auth integration;
- profile visibility integration;
- one-time proposal integration;
- recurring activity integration;
- public web Tavoli integration;
- web tests/lint/typecheck/build;
- Flutter localization/format/analyze/tests;
- generated DB types + zero drift;
- `git diff --check`.

No hosted database/provider is required.

---

# Non-goals

Do not implement:

- mobile participation UI;
- web participation UI;
- chat creation/messages;
- push/email notifications;
- capacity/full/waitlist;
- co-organizer/project roles;
- invitations;
- public membership directory;
- resource offers/contributions;
- Scambio-Dona marketplace;
- saved resource searches;
- contribution verification after completion;
- badges/privileges;
- online/in-person project migration;
- project discovery redesign;
- Tavoli/Proposal schema merge;
- maps/media/payments;
- moderation/blocking;
- legal-entity participation.

---

# Acceptance criteria

05A is ready for review when:

- [ ] based on latest merged `main`;
- [ ] exact prompt archived under `history-implementations/`;
- [ ] one thin common project identity covers both Proposal and Tavolo without merging content schemas;
- [ ] all existing/future source rows are guaranteed a project identity;
- [ ] participation tables reference the common project identity;
- [ ] join requests support pending/accepted/rejected/withdrawn history;
- [ ] optional private request message is bounded and never public;
- [ ] complete profile is required to request;
- [ ] project creator cannot request own project;
- [ ] join eligibility correctly resolves one-time vs recurring lifecycle;
- [ ] creator accept/reject is canonical and race-safe;
- [ ] acceptance atomically creates exactly one current membership;
- [ ] member leave and creator removal preserve history;
- [ ] voluntary leave can later re-request while eligible;
- [ ] creator removal preserves history and does not become an implicit permanent ban;
- [ ] no participant capacity/fullness is invented;
- [ ] current accepted participant can read restricted operational meeting details;
- [ ] pending/left/removed/unrelated users cannot;
- [ ] existing public exact-location privacy remains unchanged;
- [ ] audit/outbox payloads contain no private messages/location;
- [ ] no chat is created;
- [ ] no resource pseudo-schema is added;
- [ ] pgTAP coverage passes;
- [ ] real multi-user integration passes for both project kinds;
- [ ] existing Mobile/Web/Database CI remains green;
- [ ] roadmap records 05A/05B/05C and 08/09 future product directions;
- [ ] PR remains unmerged for review.

---

# Autonomy and stop conditions

Codex may decide ordinary implementation details such as:

- exact registry/table names;
- enum vs checked text;
- UUID generation details;
- trigger vs canonical-function mechanism for project registry synchronization;
- request/membership IDs;
- private helper decomposition;
- index strategy;
- whether terminal timestamps use one or separate columns;
- exact audit/outbox event names.

Stop and report before:

- merging Proposal and Tavolo content into one table;
- using an unenforced raw `target_type + target_id` pair when a safe project identity can provide referential integrity;
- weakening source RLS;
- exposing request messages publicly;
- inventing resource fields;
- adding participant capacity;
- implementing online/in-person;
- deciding final chat trigger;
- creating chat;
- adding participation UI;
- merging the PR.

---

# Deliverables

Produce:

1. exact archived implementation prompt;
2. thin common project identity/registry;
3. backfill and source-insert synchronization;
4. project join-request schema;
5. project membership/history schema;
6. canonical request/withdraw/accept/reject/leave/remove operations;
7. project-kind/lifecycle resolution helpers;
8. participant-authorized operational meeting-info read;
9. requester/creator/member private read APIs;
10. minimal audit/outbox events;
11. pgTAP security/state/race/privacy tests;
12. multi-user Proposal + Tavolo integration harness;
13. regenerated DB types;
14. product-decision/system-design/roadmap reconciliation;
15. focused PR, preferably `codex/05a-project-participation-domain`;
16. structured completion report.

Do not merge the PR.

---

# Completion report

Return:

1. **Summary**
2. **Branch/base/PR**
3. **Changed files**
4. **Shared project identity design**
5. **Backfill/invariants**
6. **Join-request model**
7. **Membership/history model**
8. **One-time project eligibility**
9. **Recurring/Tavolo eligibility**
10. **Request/withdraw operations**
11. **Accept/reject operations**
12. **Leave/remove operations**
13. **Re-request/removal history behavior**
14. **Participant operational meeting access**
15. **RLS/grants/security-definer hardening**
16. **Audit/outbox**
17. **pgTAP tests**
18. **Real multi-user integration**
19. **Generated types/drift**
20. **Existing regression validation**
21. **08/09 product-decision reconciliation**
22. **05B handoff**
23. **05C contribution-verification handoff**
24. **04C Resources + Scambio-Dona roadmap note**
25. **Warnings/blockers for Plan 07 chat**
26. **Commit/PR reference**

Do not report mobile participation UI, chat, resources, contribution verification, capacity, online/in-person, or badges as implemented.
