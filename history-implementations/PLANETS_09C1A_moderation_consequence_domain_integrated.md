# PLANETS 09C1A — Moderation Consequence Domain (Integrated Baseline)

## Objective

Implement the first moderation-consequence domain slice on top of the corrected integration candidate.

This task adds three **manual, moderator-applied, reversible** consequence types:

1. `safety_notice`
2. `interaction_restriction`
3. `content_hide`

No report count, corroboration result, counterstatement, blocking history, threshold, score, AI system, trigger, or worker may automatically create a consequence.

This is a backend/domain slice. Do not implement suspension, final admin/mobile consequence UX, or appeals in this PR.

---

## Exact base

Repository:

`lillo24/planets.community`

Required base:

- PR #120 — STACK-INTEGRATION-02
- branch: `codex/stack-integration-main-candidate`
- exact SHA: `f5958e00e9b1abb02b079f5489b769502fb3c88b`

Suggested branch:

`codex/09c1a-moderation-consequence-domain`

Open a **draft stacked PR** against:

`codex/stack-integration-main-candidate`

Do not target stale `main`.

Do not modify PR #120 itself for this new feature.

Do not merge or deploy.

If the integration candidate has moved materially from the exact SHA above, inspect the new commits first and stop if moderation, auth, participation, Resource, delegated-manager, capacity, workspace, or media behavior changed.

---

## Current validated baseline

The corrected integrated head already contains:

- 09A reporting/manual review;
- Project corroboration;
- Scambio-Dona counterstatements;
- 09B directional user blocking;
- Creator + active Co-creator + active Co-organizer Project manager convergence;
- delegated-manager request review/acceptance;
- Project capacity/fullness;
- Project group chat;
- Project shared workspace;
- profile-photo trust gates;
- Project/Tavolo/Resource covers;
- Resource requests/agreements/chat/loan-return flows;
- Resource matching/saved searches/notifications;
- Settings and English/Italian localization.

Local baseline at exact base SHA:

- 102 pgTAP files / 3,213 assertions passed;
- `npm run check:db` passed;
- demo reset/verify/seed/verify passed;
- Mobile analysis + 1,062 tests passed;
- Android debug APK passed;
- Web 130 app tests + 24 tooling tests passed;
- Site 53 tests passed;
- format and `git diff --check` passed.

Hosted GitHub Actions currently cannot allocate a runner due the known billing/spending-limit issue.

Treat any new deterministic local regression as owned by 09C1A unless proven otherwise.

---

# 1. Manual consequences only

Only an active moderation `moderator` or `admin` may apply or revoke consequences.

Every mutation must recheck current staff authorization.

Do not infer consequences from:

- report count;
- category;
- repeated reports;
- corroboration Agree/Disagree/Unsure;
- counterstatement presence/absence;
- blocking history;
- reputation/score;
- automated risk threshold.

Case evidence informs humans. Humans decide consequences.

---

# 2. Required reasons

Every **apply** and every **revoke** requires:

## User-facing reason

Required bounded trimmed plain text intended for the affected user.

Recommended max: 2,000 chars unless an established repository convention strongly suggests another bound.

## Private internal note

Required bounded staff-only explanation.

Reuse/link the existing moderation case-note model atomically if clean.

## Sensitive-body rule

Neither body may appear in:

- generic audit metadata;
- outbox payload;
- notification source payload;
- Realtime;
- logs;
- Sentry;
- analytics.

Audit/outbox remain identifier-only.

---

# 3. Durable consequence model

Create private append-preserved moderation-consequence state.

A suitable model should represent:

- stable consequence ID;
- originating case ID;
- type;
- canonical affected profile;
- optional Project target;
- optional Resource listing target;
- applied timestamp;
- revoked timestamp / active state;
- append-preserved apply/revoke actions;
- user-facing reasons;
- linked internal notes;
- staff actors.

Requirements:

- at most one active consequence of one type per canonical target;
- reapply after revoke creates a new episode;
- no destructive delete;
- historical closed episodes cannot be reopened;
- stable ID suitable for future 09C3 appeals;
- restrictive FKs;
- private schema preferred;
- RLS defense in depth;
- no direct table access for anon/authenticated/service-role convenience APIs.

Do not put moderation consequence state into:

- `public.profiles`;
- Proposal lifecycle;
- Tavolo lifecycle;
- Resource listing lifecycle;
- user block episodes.

---

# 4. Case-state rule

Consequence apply is allowed only when the moderation case is:

- `under_review`, or
- `completed`.

Applying from `received` must fail.

Applying/revoking a consequence does **not** automatically transition the moderation case.

Evidence review state and consequence state are independent.

---

# 5. Safety notice

Type:

`Safety notice`

Canonical target:

`moderation_cases.subject_profile_id`

Client must not supply an arbitrary target profile.

## Effect

An active safety notice:

- changes no public visibility;
- changes no Project/Resource authorization;
- changes no chat/membership/delegate state;
- changes no account access;
- changes no profile-photo access by itself.

It is canonical state for later 09C2 contextual warning UX.

## Confidentiality

It is not:

- a public badge;
- a public “Risky” label;
- a reputation score;
- a public profile field;
- a generic moderation-history lookup.

Add a private reusable active predicate.

Do not expose raw reason/evidence to ordinary counterparties.

09C2 will later define narrow contextual warning projections.

---

# 6. Interaction restriction

Type:

`interaction_restriction`

Canonical target:

`moderation_cases.subject_profile_id`

## Allowed while restricted

A restricted profile may continue to:

- authenticate normally;
- browse public content;
- manage own profile/settings;
- create/manage/publish own content under ordinary rules;
- act as Creator, Co-creator, or Co-organizer under existing authority;
- review incoming Project requests;
- accept/reject eligible incoming Project requests;
- manage capacity, Needs, workspace, delegates according to existing role;
- remain an existing Project member;
- use existing Project group chat;
- access meeting details if ordinarily authorized;
- access shared workspace if ordinarily authorized;
- use commitments/contribution flows;
- continue accepted Resource agreement/chat/terms/milestones/loan-return coordination;
- report content/users;
- answer moderation evidence requests;
- manage ordinary user blocks.

This is **not suspension**.

## Forbidden while restricted

Only:

- creating a new outbound Project join request;
- creating a new outbound Scambio-Dona Resource request.

Do not expand it into:

- publishing ban;
- organizer ban;
- manager ban;
- chat ban;
- membership removal;
- accepted Resource termination;
- public profile hiding.

---

# 7. Pending outbound requests on restriction apply

When `interaction_restriction` becomes active, close the restricted profile's current pending outbound requests.

## Project

Every pending Project join request with:

`requester_profile_id = restricted_profile`

becomes:

`withdrawn`

using canonical requester-withdrawal semantics/events/history.

This applies regardless of Project management composition.

## Resource

Every pending Resource listing request with:

`requester_profile_id = restricted_profile`

becomes:

`withdrawn`

using canonical requester-withdrawal semantics/events/history.

Do not create a `restricted` status.

Do not rewrite terminal requests.

Do not unwind accepted membership/agreement.

---

# 8. Restriction concurrency

Restriction must serialize against:

- `request_to_join_project`;
- Creator compatibility acceptance;
- Creator triaged acceptance;
- delegated-manager compatibility acceptance;
- delegated-manager triaged acceptance;
- `request_resource_listing`;
- `accept_resource_listing_request`.

## Required serial outcomes

### Restriction wins first

No new Project/Resource request or acceptance crosses the barrier.

### Request wins first

The later restriction withdraws the pending request.

### Acceptance wins first

The accepted membership/agreement remains.

The later restriction does not unwind it.

---

# 9. Lock hierarchy

Add one profile-level moderation interaction lock, or equivalent proven serialization primitive.

Conceptually:

`private.lock_profile_new_interactions(profile_id)`

A reasonable global order is:

## Project

1. requester/profile moderation-interaction lock;
2. existing 09B requester ↔ every current-manager pair locks in deterministic order;
3. concrete/shared Project lock;
4. manager-set/block/restriction/hide revalidation;
5. request/accept/capacity/membership mutation.

## Resource

1. requester/profile moderation-interaction lock;
2. requester ↔ owner user-block pair lock;
3. Resource listing/request/agreement lock;
4. restriction/hide revalidation;
5. mutation.

An equivalent order is acceptable if repository inspection proves it safer.

Do not ship a simple non-serialized `exists(restriction)` pre-check.

---

# 10. Integrated Project manager baseline

The manager model is already implemented and must be treated as current truth:

- immutable original Creator;
- active `co_creator`;
- active `co_organizer`;
- revoked delegates excluded.

Do not regress to Creator-only assumptions.

Both Creator-named and manager-named acceptance APIs remain in the repository.

Every acceptance path must check the **requester's** interaction restriction.

A restricted manager may still accept an unrestricted requester.

Do not block manager authority just because that manager is interaction-restricted.

---

# 11. Capacity/fullness integration

Do not duplicate capacity logic.

Acceptance must continue composing with the existing canonical rules:

- requester moderation restriction;
- all-current-manager 09B block barrier;
- manager authorization;
- content-hide barrier;
- contribution triage;
- lifecycle;
- request/membership state;
- capacity/fullness;
- membership insertion/chat activation.

A moderation failure must not:

- consume a spot;
- seed commitments;
- write acceptance decisions;
- create membership;
- activate chat.

A capacity failure must not mutate moderation consequence state.

---

# 12. Content hide

Type:

`content_hide`

Allowed canonical case targets:

- `project`;
- `resource_listing`.

Derive target from the moderation case.

Do not let the client supply an unrelated content ID.

Do not apply `content_hide` to:

- profile;
- Project chat message;
- Resource request;
- Resource chat message

in 09C1A.

---

# 13. Content hide is orthogonal to business lifecycle

Do not add moderation states to:

## Proposal
- `draft`
- `published`
- `cancelled`

## Tavolo
- `draft`
- `published`
- `paused`
- `ended`

## Resource listing
- `draft`
- `published`
- `closed`

Examples:

- hidden published Proposal stays `published`;
- hidden Tavolo may be paused/resumed/ended by authorized structural actor;
- hidden Resource listing may be edited/closed;
- unhide never reopens cancelled/ended/closed content.

Only staff revoke clears the moderation hide.

---

# 14. Hidden Project — public behavior

While a Project content hide is active, suppress the Project from ordinary public exposure.

Audit all integrated public projections, including at minimum:

- Proposal list/search;
- Proposal exact public detail;
- Tavolo public list;
- Tavolo occurrence list;
- Tavolo exact public detail, including paused/ended historical detail;
- public Project capacity aggregate lookup;
- public Project Resource/Need projections;
- public Project cover metadata/object authorization;
- public contextual organizer-photo reads tied to the Project;
- public web/mobile derivatives.

Do not return moderation metadata publicly.

To ordinary public callers, the content is simply unavailable/absent according to existing public-read conventions.

---

# 15. Hidden Project — participation behavior

While hidden:

- new Project join request is denied;
- pending request cannot be accepted by Creator/Co-creator/Co-organizer.

## Pending requests

Do **not** automatically resolve them.

They remain `pending`.

Requester may still withdraw.

Current manager may still reject.

Acceptance becomes possible again only after unhide and only if all other current rules pass.

## Accepted members

Preserve:

- membership;
- chat/history/send entitlement;
- protected meeting access;
- shared workspace;
- commitments;
- Needs/resource coordination;
- contribution history;
- capacity occupancy.

Content hide is not suspension.

---

# 16. Hidden Project — manager behavior

Preserve current authority model.

Original Creator and active delegates retain existing management permissions.

Do not elevate Co-organizer structural authority.

A hidden Project may still undergo ordinary authorized lifecycle/management actions, including where currently allowed:

- edit;
- cancel Proposal;
- pause/resume/end Tavolo;
- manage delegates;
- manage workspace;
- reject pending applicants;
- manage capacity.

None of these clears the moderation hide.

---

# 17. Hidden Resource listing — public behavior

While a Resource listing hide is active, suppress:

- public listing discovery;
- public exact detail;
- public matching/saved-search candidate projection;
- new-listing match projection;
- public cover metadata/object authorization;
- public contextual owner-photo reads tied to the listing;
- other public derivatives based on published-listing visibility.

Do not expose moderation reason publicly.

Historical generated events/notifications remain historical.

Do not create new match delivery from a listing while hidden.

---

# 18. Hidden Resource listing — request behavior

While hidden:

- no new Resource request;
- no pending Resource request acceptance.

Existing pending requests remain pending.

Requester may withdraw.

Owner may reject.

Do not auto-withdraw/reject merely because the listing became hidden.

## Accepted coordination

Preserve:

- accepted request;
- agreement;
- terms;
- milestones/handoff;
- loan-return workflow;
- Resource chat/history/send while ordinarily open.

---

# 19. Cover-media leakage

The integrated candidate now has Project/Tavolo and Resource covers.

A hidden content object must not remain publicly retrievable solely because someone knows the cover path.

Audit:

- public cover metadata helpers;
- Storage/object authorization;
- card/detail backend contracts.

Requirements:

- public cover delivery denied while hidden;
- owner/authorized manager cover-management access preserved where ordinary rules allow;
- do not delete cover bytes;
- unhide may make the same cover public again if lifecycle is otherwise public.

Do not substitute media deletion for moderation hiding.

---

# 20. Contextual profile-photo leakage

A hidden Project/listing must not continue acting as a **public context** granting organizer/owner contextual photo access.

This does not change:

- truly public profile photos;
- owner self-access;
- independent existing interaction relationships that separately authorize an `interactions` photo.

Remove only the hidden content's public-context authorization.

---

# 21. Affected user for content hide

## Project

Affected user is the immutable original Creator.

Co-creators/Co-organizers do not become moderation-owner identities.

## Resource listing

Affected user is the listing owner.

This matters for own-status reads and later 09C2 notifications.

---

# 22. Staff apply operation

Implement a narrow expected-identity-bound mutation conceptually equivalent to:

`apply_moderation_consequence(...)`

Inputs may include:

- expected staff profile;
- case ID;
- consequence type;
- user-facing reason;
- private internal note;
- retry/idempotency key if useful.

Target must be derived server-side.

Transaction should:

1. require current staff;
2. lock case;
3. validate state/type/target;
4. normalize reason/note;
5. acquire relevant serialization boundary;
6. prevent duplicate active consequence;
7. create/link private case note;
8. create consequence episode/action;
9. perform side effects:
   - safety notice: none;
   - interaction restriction: withdraw pending outbound requests;
   - content hide: activate barrier only;
10. write identifier-only audit;
11. write identifier-only 09C2 source outbox event;
12. commit atomically.

No partial consequence should survive failure.

---

# 23. Staff revoke operation

Implement a narrow mutation conceptually equivalent to:

`revoke_moderation_consequence(...)`

Inputs:

- expected staff profile;
- consequence ID;
- user-facing revocation reason;
- private internal note;
- optional retry key.

Requirements:

- active consequence required;
- append note + revoke action;
- close episode;
- identifier-only audit/outbox;
- no case transition;
- no resurrection of old requests;
- no membership recreation;
- no lifecycle rewrite;
- no block removal.

For restriction:

revocation only restores future eligibility subject to all other rules.

For hide:

revocation removes only the moderation barrier.

---

# 24. Active uniqueness and repeated cases

At most one active consequence of the same type for the same target.

A second case attempting the same active consequence must not silently create another episode.

Exact command retry may be idempotent if a retry key/pattern is implemented.

Otherwise return a safe conflict.

After revocation, a later case may create a new episode.

Do not automatically merge evidence across cases.

---

# 25. Central private predicates

Provide canonical private helpers equivalent to:

- profile has active safety notice;
- profile has active interaction restriction;
- Project has active content hide;
- Resource listing has active content hide.

Reuse these across public/domain boundaries.

Do not scatter ad-hoc moderation queries through many RPCs.

---

# 26. Own consequence reads

Add expected-identity-bound reads for the affected user.

Return only safe user-facing state:

- consequence ID;
- type;
- active/revoked state;
- apply timestamp;
- apply user-facing reason;
- revoke timestamp if any;
- revocation user-facing reason if any;
- safe owned content kind/reference/title where appropriate.

Do not expose:

- internal staff note;
- report body;
- corroboration details;
- counterstatement;
- reporter identity;
- audit metadata.

For profile consequences:

only the subject may read.

For Project content hide:

only immutable original Creator may read the raw user-facing consequence reason through the generic own-status API.

For Resource hide:

only listing owner may read.

Do not give Co-creators/Co-organizers the Creator's raw moderation reason through this generic API.

---

# 27. Outbox contract for 09C2

Affected users will later be explicitly notified when PLANETS:

- applies safety notice;
- revokes safety notice;
- applies interaction restriction;
- revokes interaction restriction;
- hides content;
- unhides content.

09C1A should emit dedicated identifier-only source events.

Payload may contain only identifiers needed for later projection, such as:

- consequence ID;
- consequence action/event ID;
- affected profile ID;
- target kind/ID.

Do not include reason text.

Do not implement final notification projection/push/email copy yet.

Document these events as intentionally unconsumed until 09C2.

---

# 28. Safety-notice contextual API is deferred

Do not create a general public safety-notice API.

09C2 will later decide exact contextual warning surfaces.

09C1A needs only:

- canonical state;
- private active predicate;
- staff history;
- own affected-user history.

Do not expose raw reason/evidence to future counterparties.

---

# 29. Independence from 09B user blocking

User blocking and moderation consequences are independent.

New Project participation must require all applicable rules:

- requester not interaction-restricted;
- no requester ↔ current-manager user block;
- Project not moderation-hidden;
- lifecycle/joinability;
- photo trust;
- capacity/fullness;
- request/membership rules.

New Resource request must require:

- requester not interaction-restricted;
- no requester ↔ owner user block;
- listing not hidden;
- lifecycle;
- photo trust;
- Resource rules.

Unblock does not revoke moderation restriction.

Restriction revoke does not remove a block.

Do not represent moderation consequences as user blocks.

---

# 30. Independence from moderation evidence

Reports/corroboration/counterstatements remain usable regardless of consequence state.

A warned/restricted/hidden-content owner can still:

- submit valid reports;
- read own report status;
- answer assigned corroboration;
- answer assigned counterstatement.

Staff retains evidence access.

Do not add consequence checks to evidence APIs.

---

# 31. Shared workspace

Interaction restriction and content hide do not revoke an already-authorized workspace relationship.

Preserve existing rule:

- Creator / active delegated managers manage;
- current participant reads;
- former participant without manager authority cannot read.

Hidden Project workspace remains private and operational for ordinary authorized current users.

Do not expose it through public hidden-content reads.

---

# 32. Required concurrency verifier

Add a real concurrent verifier.

## Interaction restriction races

Prove both winner orders for:

1. restriction vs Project Request;
2. restriction vs Creator acceptance;
3. restriction vs delegated-manager acceptance;
4. restriction vs Resource Request;
5. restriction vs Resource Accept.

## Content hide races

Prove both winner orders for:

1. hide vs Project Request;
2. hide vs Creator acceptance;
3. hide vs delegated-manager acceptance;
4. hide vs Resource Request;
5. hide vs Resource Accept.

Required final outcomes:

### restriction wins
no new pending/accepted interaction crosses.

### request wins
restriction later withdraws the pending request.

### accept wins
accepted relationship remains.

### hide wins
no request/accept crosses.

### request wins before hide
pending request remains pending; acceptance freezes.

### accept wins before hide
accepted relationship remains.

Also preserve a capacity final-spot regression scenario.

Do not rely only on sleeps. Assert final DB state.

---

# 33. pgTAP coverage

Use globally unique test numbers after the current integrated maximum (`105`) after verifying inventory.

Cover at minimum:

## Schema/security

- private consequence tables;
- RLS/grants;
- type/target constraints;
- append-preserved history;
- active uniqueness;
- reason/note bounds;
- security-definer/search-path hygiene;
- body-free audit/outbox.

## Staff

- moderator apply/revoke;
- admin apply/revoke;
- ordinary user denied;
- revoked staff denied;
- `received` case denied;
- `under_review`/`completed` allowed;
- case state unchanged.

## Safety notice

- apply/revoke/reapply;
- active predicate;
- no public profile exposure;
- no auth effect.

## Interaction restriction

- Project pending requests withdrawn;
- Resource pending requests withdrawn;
- no terminal rewrite;
- new Project request denied;
- new Resource request denied;
- Creator acceptance denied for restricted requester;
- Co-creator acceptance denied;
- Co-organizer acceptance denied;
- restricted manager still accepts eligible incoming requester;
- existing member/chat/meeting/workspace preserved;
- accepted Resource coordination preserved;
- revoke does not resurrect prior requests;
- future request works only if all other rules permit.

## Project content hide

- Proposal public list/detail suppressed;
- Tavolo public list/occurrence/detail suppressed;
- public capacity/resource/cover/context helpers suppressed;
- owner/authorized manager private operations preserved;
- new request denied;
- pending request remains pending;
- withdraw/reject allowed;
- Creator/manager accept denied;
- accepted member access preserved;
- unhide restores only moderation barrier subject to lifecycle.

## Resource content hide

- public list/detail suppressed;
- new matching projection suppressed;
- public cover/context photo suppressed;
- new request denied;
- pending remains pending;
- owner reject/requester withdraw works;
- accept denied;
- accepted agreement/chat/loan preserved;
- owner edit/close does not clear hide;
- unhide after close does not republish.

## Privacy

- subject reads own profile consequence;
- Project Creator reads own hide reason;
- Resource owner reads own hide reason;
- Co-creator cannot read Creator's raw reason through generic own-status API;
- unrelated user denied;
- sensitive text absent from audit/outbox.

---

# 34. Real-auth verifier matrix

Use real authenticated users for:

- moderator;
- admin;
- subject;
- Project Creator;
- Co-creator;
- Co-organizer;
- requester/member;
- Resource owner;
- Resource requester;
- unrelated user.

Do not print:

- Auth tokens;
- report bodies;
- internal notes;
- user-facing moderation reason unless necessary;
- exact private locations;
- chat bodies.

---

# 35. Migration discipline

Use new additive migration(s) on top of the integrated candidate.

Do not edit historical integrated migrations for this new feature unless a replay bug makes it unavoidable and explicitly justified.

When replacing existing functions, preserve all cumulative signatures and behavior, including:

- Proposal search query arguments;
- cover fields;
- delegated-manager overloads;
- blocking manager convergence;
- capacity/fullness;
- profile-photo trust;
- matching/resource behavior.

Audit migration replay order so no later definition restores old semantics.

---

# 36. Generated types

Run:

```text
npm run db:types
npm run db:types:check
```

Commit generated output.

Do not hand-edit generated types as source of truth.

---

# 37. Documentation

Update:

- `docs/architecture/system-design.md`
- `docs/development/database.md`
- `docs/implementation/roadmap.md`
- `supabase/README.md`
- relevant moderation/admin docs.

Roadmap split:

- **09C1A — Safety Notice, Interaction Restriction + Content Hide Domain**
- **09C1B — Account Suspension Domain + Global Enforcement**
- **09C2 — Consequence Admin/Mobile UX + Notifications**
- **09C3 — Appeals** (deferred pending founder policy)
- **09D — Minimum Age**

Parent Plan 09 remains in progress.

Archive this exact prompt under:

`history-implementations/PLANETS_09C1A_moderation_consequence_domain_integrated.md`

---

# 38. Non-goals

Do not implement:

## 09C1B
- suspension;
- global auth restriction;
- suspended session state;
- chat suspension;
- suspension-status screen.

## 09C2
- admin consequence controls;
- mobile consequence screens;
- contextual safety warning UI;
- hidden-content banners;
- interaction-restriction CTA UI;
- notification projection/copy/push.

## 09C3
- appeals.

## 09D
- minimum age.

## Plan 10
- final retention/deletion/anonymization.

Also exclude:

- automatic moderation score;
- public reputation;
- AI punishment;
- member removal due restriction;
- accepted Resource termination;
- delegate revocation due consequence;
- unrelated refactors.

---

# 39. Validation

Return the integrated repository to full green standards.

## Database

```text
npm run db:reset
npm run db:lint
npm run db:advisors
npm run db:test
npm run db:types:check
npm run check:db
```

Report final pgTAP file/assertion counts.

## Existing affected verifiers

Run relevant verifiers for:

- moderation reporting;
- corroboration;
- counterstatement;
- blocking concurrency;
- Project participation;
- delegated managers/Co-creators;
- capacity/fullness;
- Project chat;
- Project workspace;
- Project Needs/resources;
- profile photo;
- cover media;
- Resource listing/request/agreement/chat;
- Resource matching/saved-search/notifications.

## New verifiers

Run:

- moderation consequence real-auth verifier;
- moderation consequence concurrency verifier.

## Demo

```text
npm run demo:reset:local
npm run demo:verify:local
npm run demo:seed:local
npm run demo:verify:local
```

## Web

```text
npm run check:web
```

## Mobile

Run:

```text
npm run check:mobile
```

Build debug APK if mobile/shared production code changed or repository gate requires it.

## Site

Run the full Site gate because public visibility behavior changes:

```text
npm run check:site
```

## Hygiene

```text
npm run format:check
git diff --check
```

Do not claim success while a deterministic repository-owned failure remains.

---

# 40. Hosted CI

Make one normal final-head hosted attempt.

If GitHub again refuses runner assignment due the known billing/spending-limit issue:

- record the run;
- do not repeatedly rerun unchanged infrastructure;
- do not claim CI passed.

---

# 41. Acceptance criteria

- [ ] Exact base SHA is `f5958e00e9b1abb02b079f5489b769502fb3c88b`.
- [ ] Draft PR targets `codex/stack-integration-main-candidate`.
- [ ] Only active moderator/admin applies/revokes.
- [ ] No automated consequence path exists.
- [ ] Apply and revoke require user-facing reason + private note.
- [ ] Sensitive text stays out of audit/outbox/logging.
- [ ] Consequence history is durable/reversible/future-appeal-compatible.
- [ ] Safety notice is not public reputation and has no authorization effect.
- [ ] Interaction restriction blocks only subject's new outbound Project/Resource requests.
- [ ] Applying restriction withdraws subject's pending outbound Project/Resource requests.
- [ ] Restricted Creator/Co-creator/Co-organizer retains ordinary manager authority.
- [ ] All Creator/delegated-manager acceptance paths reject restricted requester.
- [ ] Existing Project membership/chat/meeting/workspace/capacity state remains.
- [ ] Existing accepted Resource coordination remains.
- [ ] Content hide is orthogonal to owner lifecycle.
- [ ] Hidden Project/Resource disappears from public discovery/detail.
- [ ] Hidden public capacity/resource/cover/context reads do not leak it.
- [ ] Hidden Resource produces no new public matching projection.
- [ ] New requests and pending acceptance are denied while hidden.
- [ ] Existing pending requests remain pending.
- [ ] Withdraw/reject remain available.
- [ ] Existing accepted relationships stay operational.
- [ ] Owner/authorized manager private operations remain available.
- [ ] Unhide only removes moderation barrier.
- [ ] Own user-facing consequence history is narrowly readable.
- [ ] Co-creators do not gain Creator's raw moderation reason via generic own-status read.
- [ ] Identifier-only 09C2 outbox source events exist.
- [ ] 09B blocking remains independent and correct.
- [ ] Delegated manager convergence remains correct.
- [ ] Capacity/fullness remains canonical.
- [ ] Moderation evidence remains independent.
- [ ] Suspension is not partially implemented.
- [ ] Full local validation passes or failures are precisely explained.
- [ ] PR remains draft/unmerged.
- [ ] No production deployment.

---

# 42. Stop conditions

Stop and report before:

- applying consequences automatically from evidence;
- exposing public reputation/risk labels;
- storing moderation hide in owner lifecycle;
- removing existing membership under interaction restriction;
- disabling existing chat/meeting/workspace under interaction restriction;
- terminating accepted Resource coordination;
- preventing a restricted manager from reviewing/accepting eligible incoming requests;
- client-only hiding without backend enforcement;
- leaving hidden covers/public context reads accessible;
- exposing raw moderation reason to ordinary counterparties;
- implementing suspension;
- implementing appeals;
- inventing retention policy;
- shipping race-prone enforcement;
- regressing all-current-manager blocking;
- regressing capacity/fullness.

---

# 43. Completion report

Return:

1. Summary
2. Git — branch, final SHA, PR link/number, exact base
3. Consequence model
4. Apply/revoke contract
5. Reason/note privacy
6. Safety notice behavior
7. Interaction restriction behavior
8. Creator/Co-creator/Co-organizer acceptance integration
9. Pending-request withdrawal behavior
10. Content hide — Proposal
11. Content hide — Tavolo
12. Content hide — Resource
13. Public cover/photo/matching leakage controls
14. Existing relationship preservation
15. Concurrency / lock hierarchy
16. Own consequence reads
17. 09C2 outbox contract
18. Blocking / delegated authority / capacity independence
19. Audit/privacy
20. Validation commands/results and final test counts
21. Demo idempotency
22. Hosted CI/environment limitations
23. Deferred 09C1B / 09C2 / 09C3 / 09D / Plan 10
24. Stop-worthy findings

Do not merge or deploy production resources.

