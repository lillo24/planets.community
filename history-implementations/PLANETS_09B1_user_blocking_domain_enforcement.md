# PLANETS 09B1 — User Blocking Domain + Cross-Domain Enforcement

## Objective

Implement the canonical backend/domain foundation for **user-controlled blocking** across PLANETS.

A block is directional as a user action — **A blocks B** — but creates a **symmetric barrier for starting new direct interactions between A and B**.

After 09B1:

- a user can block another user;
- a user can unblock someone they previously blocked;
- a user can list only the people **they themselves** currently block;
- the blocked person is not notified that they were blocked and cannot query who blocked them;
- public content remains discoverable;
- new Project join interactions and new Scambio-Dona requests between the pair are prevented;
- already-pending direct requests between the pair are closed immediately and canonically;
- existing accepted Project memberships/group-chat access remain intact;
- existing accepted Scambio-Dona coordination remains usable until its existing agreement/coordination episode ends;
- private `interactions` profile-photo access between the pair is revoked;
- public profile/photo/content visibility remains unchanged;
- unblock restores only future eligibility and does not resurrect prior requests;
- moderation reports/corroboration/counterstatements remain accessible and unaffected by blocking;
- blocking races safely with request creation/acceptance so a new relationship cannot slip through after the block wins serialization.

This is the **backend/security slice** of 09B.

Do **not** implement the full ordinary-user blocking UI in this PR. A later 09B2 will add contextual Block/Unblock actions, blocked-user management, client cache invalidation, confirmations, and user-facing handling of interaction failures.

---

# Required Git base and stacking

Repository:

`lillo24/planets.community`

Implement this as a new isolated branch/worktree based on the exact reviewed head of PR #114:

- PR #114: `PLANETS 09A2B: Scambio-Dona counterstatement`
- branch: `codex/09a2b-scambio-counterstatement`
- exact dependency commit:
  `d85b0122485c7ca09d6cb5f80104ed872d90d17c`

Prefer branch name:

`codex/09b1-user-blocking-domain`

Open a focused stacked PR against:

`codex/09a2b-scambio-counterstatement`

Do not target stale `main`.

Do not merge this PR automatically. Leave it open for founder review and stacked integration.

If the dependency branch no longer points at the exact SHA above, inspect and report the material difference rather than silently choosing another base.

---

# Current repository evidence

Verified on PR #114 head before writing this plan.

## Plan 09 status

`docs/implementation/roadmap.md` marks Plan 09 as in progress through 09A2B.

The next explicit boundary is:

- **09B — User blocking**

09C remains moderation consequences/restrictions/suspension, 09D remains minimum age, and Plan 10 remains retention/deletion/anonymization.

## Project participation

The current backend uses canonical expected-identity RPCs including:

- `request_to_join_project`
- `withdraw_project_join_request`
- both overloads of `accept_project_join_request`
- `reject_project_join_request`
- `leave_project`
- `remove_project_member`

`project_join_requests` preserve pending/accepted/rejected/withdrawn history.

`project_memberships` preserve current and ended membership history.

Current Project group-chat entitlement derives from ownership/current membership, with historical visibility retained according to membership intervals.

Blocking/moderation overrides were explicitly deferred to Plan 09.

## Scambio-Dona

The current backend includes:

- `request_resource_listing`
- `withdraw_resource_listing_request`
- `accept_resource_listing_request`
- `reject_resource_listing_request`
- accepted `resource_exchange_agreements`
- `resource_request_chats`
- immutable Resource chat history and existing agreement/coordination operations.

A Resource request may be:

- `pending`
- `accepted`
- `rejected`
- `withdrawn`
- `listing_closed`

Accepted requests own an agreement/chat coordination episode. Multiple accepted requesters may exist for one listing.

## Profile photos

The current profile-photo design distinguishes:

- `public` photos;
- `interactions` photos.

Relationship-based access currently includes Project organizer↔applicant/member rules and Scambio-Dona owner/requester rules.

Public photos are intentionally public.

09B1 must insert blocking into the **private interaction authorization layer**, not turn public photos or public content private.

## Moderation evidence

09A1/09A2A/09A2B implement reports, staff review, group corroboration, and Resource counterstatements.

Blocking must not remove, hide, close, or alter those evidence flows.

---

# External context

No external document is required.

All founder decisions required for 09B1 are recorded below.

Do not require the external Google Doc.

---

# Product decisions already made

## 1. Directional action, symmetric interaction barrier

If profile A blocks profile B:

- the durable block action belongs to A;
- A can see/manage that outbound block;
- B cannot query that A blocked them;
- both A and B are prevented from creating a **new direct interaction** with the other while either directional block is active.

Therefore the canonical backend needs a symmetric predicate conceptually equivalent to:

> `has_active_block_between(A, B)`

even though the stored relationship is directional.

If both users block each other, both directional block episodes may coexist.

Unblocking A→B does not remove B→A.

## 2. No explicit block notification

Blocking/unblocking must not create:

- a `You were blocked` notification;
- push/email;
- Realtime signal identifying the block;
- public/profile block marker;
- inbound-block list/API.

Ordinary request transitions caused by the block may continue to create whatever existing request-resolution audit/outbox/notification behavior is canonically required, **provided no payload/reason says that the transition happened because of a block**.

A blocked user may sometimes infer what happened from ordinary product behavior. The product must not explicitly disclose block direction.

## 3. Public content remains visible

Blocking is an **interaction barrier**, not a visibility filter.

Do not filter or hide because of blocking:

- public profiles/fields;
- public profile photos;
- public Proposals;
- public Tavoli;
- public Scambio-Dona listings;
- public discovery/search;
- public historical content.

Do not remove an organizer's public content from the blocker feed and do not remove the blocker's public content from the other person's feed.

09B2 may present outbound-block-specific UI when the blocker knows they blocked someone, but the canonical public data remains unchanged.

## 4. New Project interactions are blocked symmetrically

While either A→B or B→A is active:

- B cannot submit a new join request to a Project organized by A;
- A cannot submit a new join request to a Project organized by B;
- a pending request between the pair must not be accepted into a new membership after the block wins serialization.

On the exact PR #114 base, the immutable Project creator is the canonical organizer identity available in this stack.

### Co-creator/delegate convergence

A separate open stack adds co-creators/managers.

Do **not** import or merge that stack into 09B1.

However, centralize blocking checks so that when the stacks converge, Project organizer-side eligibility can be extended to **active co-creators/managers** without redesigning the block model.

Record this as an explicit convergence requirement.

Once that stack is integrated, a block involving any active organizer with applicant authority should prevent a new join interaction with that Project according to the same product rule.

## 5. Pending Project requests terminate immediately

When a block becomes active, close every current pending Project join request that directly connects the pair through creator/requester roles.

For each affected request:

- if the **blocker is the requester**, resolve it using canonical **withdrawn** semantics;
- if the **blocker is the Project creator**, resolve it using canonical **rejected** semantics.

If the pair happen to have pending requests in both directions across different Projects, apply the appropriate role-specific terminal transition to each.

Preserve request history.

Do not add a new `blocked` request status.

Do not rewrite old terminal requests.

## 6. Existing Project membership remains

Blocking must **not** automatically:

- remove a current member;
- make them leave;
- rewrite membership intervals;
- delete membership history;
- delete/close the Project group chat;
- remove current group-chat send/read entitlement that derives from current membership;
- remove historical group-chat access;
- remove protected meeting access that derives from current accepted membership;
- prevent a third-party organizer from having both blocked users in the same group.

The users may therefore still encounter each other in a shared group. This is intentional.

If the member later leaves/is removed, they cannot create a new direct join relationship with the blocked organizer until the relevant block barrier is gone.

## 7. Project group chat remains group-scoped

Do not use pairwise blocking to censor messages inside an existing shared Project chat.

If both blocked users currently belong to the same Project according to ordinary authorization:

- both retain ordinary group-chat history;
- both retain current send/read entitlement;
- Realtime entitlement remains membership/ownership-derived;
- group information remains available.

Do not silently hide one user's messages from the other.

That would create inconsistent group history and is outside the agreed MVP semantics.

## 8. New Scambio-Dona requests are blocked symmetrically

While either directional block between listing owner and requester is active:

- neither person may create a new `resource_listing_request` involving the other;
- a pending request must not be accepted after the block wins serialization.

Public listing discovery remains unchanged.

## 9. Pending Scambio-Dona requests terminate immediately

When a block becomes active, close every **pending** Resource request between the pair.

For each affected request:

- if the blocker is the requester → use canonical **withdrawn** semantics;
- if the blocker is the listing owner → use canonical **rejected** semantics.

Preserve request history.

Do not invent a `blocked` Resource-request status.

Do not rewrite already-terminal requests.

## 10. Accepted Scambio-Dona coordination remains usable

If a Resource request was already accepted before the block wins serialization, do **not** automatically change:

- accepted request status;
- agreement lifecycle;
- terms;
- milestones/statements;
- reservation/loan state;
- Resource chat access/history/send while the accepted coordination remains ordinarily open;
- listing lifecycle.

This is especially important for exchanges/lending where users may need to complete handoff/return coordination safely.

Blocking prevents **future interaction episodes**; it does not strand an already accepted obligation.

When that accepted coordination later completes/cancels/closes under its ordinary rules, the active block prevents a fresh Resource request between the pair until unblocked.

## 11. Private interaction-photo access is revoked

If either active directional block exists between viewer and subject:

- do not grant an `interactions` profile photo through Project relationship;
- do not grant an `interactions` profile photo through Scambio-Dona relationship;
- contextual organizer/owner photo reads that rely on interaction authorization must respect the same block barrier.

Preserve:

- photo owner access to their own photo;
- genuinely `public` photo access.

Do not make public photos disappear because of blocking.

This rule applies even when an accepted membership or accepted Scambio coordination otherwise continues.

The accepted operational relationship may remain usable while private interaction-photo visibility is revoked.

09B2 will own client-side cache invalidation/refresh around block/unblock. 09B1 must guarantee that **future canonical authorization/fetches** deny interaction-only photo delivery.

## 12. Existing history is preserved

Blocking must not delete or rewrite historical Project requests, Project memberships, Project chat messages, Resource requests, Resource agreements/terms/events, Resource chat messages, reports, corroboration, counterstatements, notifications, or audit history.

Block data itself should also preserve enough history to audit block/unblock episodes without exposing it to the blocked party.

Prefer a block-episode model with an active interval rather than destructive deletion if consistent with repository patterns.

## 13. Unblock restores future eligibility only

Unblocking A→B:

- ends only A's active directional block toward B;
- does not affect an independent B→A block;
- does not resurrect withdrawn/rejected Project requests;
- does not resurrect withdrawn/rejected Resource requests;
- does not recreate prior memberships;
- does not reopen completed/cancelled agreements;
- does not create any interaction automatically.

If no active directional block remains between the pair, they may start a new interaction later if all ordinary domain rules also permit it.

## 14. Moderation evidence ignores user blocking

Blocking must not prevent or remove:

- filing a valid report;
- reading one's own report status;
- assigned group corroboration;
- assigned Resource counterstatement;
- submitting corroboration/counterstatement evidence;
- moderator/admin case access.

A user cannot use Block to escape an assigned moderation evidence request.

Do not add block checks to 09A evidence RPCs.

---

# Scope

## A. Canonical block data

Add a private durable block relationship/episode model.

A recommended shape is conceptually:

- block episode ID;
- blocker profile ID;
- blocked profile ID;
- `blocked_at`;
- nullable `unblocked_at`.

Requirements:

- no self-block;
- at most one active directional block for `(blocker, blocked)`;
- an unblock ends the current episode rather than erasing history;
- a later re-block may create a new episode;
- restrictive foreign keys consistent with current profile/audit retention;
- private schema preferred;
- RLS as defense in depth;
- no direct `anon`, `authenticated`, or broad `service_role` table access;
- indexes supporting active directional lookup and symmetric pair lookup.

Do not create a public user relationship graph.

Do not expose inbound blocks.

## B. Canonical block helpers

Create narrow private helpers for:

### Directional active block

Conceptually: Does A currently block B?

### Symmetric active barrier

Conceptually: Does either A block B or B block A?

Security-sensitive business operations should reuse this one canonical symmetric predicate rather than duplicating queries.

If pair-level transaction serialization is needed, centralize it as well.

## C. Block operation

Implement a canonical expected-identity-bound operation, conceptually `block_user`.

Inputs should minimally identify expected blocker profile and target profile.

Requirements:

- authenticated complete profile;
- anti-account-switch expected identity;
- target is a valid other PLANETS profile;
- reject self-block;
- active retry is idempotent;
- no requirement that the target currently shares an interaction;
- no target notification;
- create identifier-only audit history;
- no block body/reason field in 09B1.

### Transactional side effects

The block transition must atomically or deterministically establish the block barrier and close every current **pending direct request** between the pair.

#### Projects
- blocker=requester → withdraw;
- blocker=creator → reject.

#### Scambio-Dona
- blocker=requester → withdraw;
- blocker=listing owner → reject.

Use the existing canonical transition semantics/events as much as practical.

Do not silently invent a second request-state implementation.

If internal reusable transition helpers are needed to avoid duplicating request logic, refactor conservatively and prove no behavior regression.

No accepted membership/agreement is terminated.

## D. Unblock operation

Implement a canonical expected-identity-bound operation, conceptually `unblock_user`.

Requirements:

- only the blocker may end their own directional block;
- expected identity protection;
- idempotent already-unblocked behavior where reasonable;
- end the active block episode;
- identifier-only audit event;
- no target notification;
- no request/member/agreement resurrection.

## E. Outbound blocked-user reads

Add a narrow expected-identity-bound read for the current user's active outbound blocks.

Return only safe fields such as target profile ID, safe display identity, and blocked timestamp.

Use bounded/keyset pagination if appropriate.

Do not return:

- who blocks the caller;
- whether the target also blocks the caller;
- target email;
- moderation history;
- target private profile fields.

Optionally add an exact outbound relationship read if useful for 09B2, but it must reveal only `I currently block this target`, not `this target blocks me`.

---

# Cross-domain enforcement

## 1. Project request creation

Update every canonical backend path that can create a new Project join request.

At minimum:

`request_to_join_project`

Before a new pending interaction becomes canonical, ensure no symmetric active block exists between requester and current organizer identity on this base (Project creator).

Do not change public Project reads.

Use a generic interaction-unavailable error that does not reveal block direction.

If the requester themselves has an outbound block, 09B2 may later pre-explain that locally, but the backend contract must remain safe for the inbound-block case.

## 2. Project acceptance

Update **both current overloads** of `accept_project_join_request` or their shared canonical helper so a pending request cannot become a new membership if an active pair block exists when acceptance wins serialization.

Do not add a block check that tears down already-existing membership.

### Race requirement

Correctly handle Block vs Request creation and Block vs Accept.

Required final semantics:

- if request/accept wins canonical serialization before the block, the resulting already-accepted membership may remain and the block applies only to future interactions;
- if block wins first, no new pending/accepted relationship may be created afterward.

Do not leave a race where a request/accept checks “not blocked”, the block commits and sees no row yet, then the request/accept creates the relationship despite the active block.

Use a deterministic pair/domain lock strategy consistent with existing repository lock ordering.

A canonical sorted-profile advisory/row lock may be appropriate, but inspect existing locks before deciding.

Document the chosen ordering.

## 3. Resource request creation

Update `request_resource_listing` to reject new owner/requester direct interaction while a symmetric active block exists.

Do not filter the listing from public discovery.

Use non-direction-revealing failure behavior.

## 4. Resource request acceptance

Update `accept_resource_listing_request` or its canonical shared helper so a pending request cannot become accepted if an active block exists when acceptance wins serialization.

Preserve already-accepted agreements and chats.

Handle Block vs Accept race deterministically under a documented lock order.

## 5. Do not block accepted Resource coordination operations

Do not add block checks to already-accepted coordination merely because the profiles are blocked.

In particular, do not disable ordinary authorized:

- agreement reads;
- term proposal/accept/reject/withdraw;
- structured milestones/statements;
- cancellation/completion;
- Resource chat reads/history;
- Resource chat send while ordinary coordination is open;
- private Resource Realtime authorization already granted by the accepted episode.

Their existing lifecycle rules continue to decide access.

## 6. Profile-photo authorization

Find the central canonical photo-viewer authorization used by `get_profile_photo_for_viewer`, batch viewer reads, Project contextual creator-photo reads, Resource-listing contextual owner-photo reads, and Storage object authorization.

Integrate the symmetric block barrier centrally.

Rules:

### Owner
Own canonical photo remains accessible.

### Public photo
Still accessible under existing public rules even if users are blocked.

### Interactions photo
A blocked pair must not qualify through interaction relationships.

Do not duplicate block checks only in Flutter or only in one photo RPC.

The Storage authorization boundary must agree with metadata/read authorization.

---

# Pending-request transition behavior

## Project

Do not create a new `blocked` state.

Use existing `withdrawn` / `rejected` semantics with ordinary canonical timestamps/history.

The block itself should not appear as a user-visible resolution reason.

If current event/outbox projection expects standard request transition events, preserve those contracts.

Do not include block identifiers/reasons in user-facing notification payloads.

## Resource

Likewise preserve existing `withdrawn` / `rejected` semantics.

Do not alter accepted/open coordination.

---

# Concurrency and lock discipline

This is a core acceptance requirement, not an optimization.

Before editing:

1. inspect existing Project request/create/accept lock order;
2. inspect Resource request/create/accept lock order;
3. choose one pair-level serialization primitive or equivalent approach that can be acquired consistently in Block + relevant new-interaction transitions;
4. avoid cycles with existing project/listing/request/agreement locks;
5. process multiple affected pending requests in deterministic order.

Document the resulting lock hierarchy.

The solution must prove races, not merely rely on ordinary transaction isolation timing.

At minimum test Block against new Project request, Project acceptance, new Resource request, and Resource acceptance.

If a clean race harness is more appropriate than pgTAP alone, add a focused local verifier.

---

# Security/privacy requirements

## Blocker

Can create/end own directional block and list own active outbound blocks.

## Blocked profile

Cannot query the inbound block, discover blocker through a block API, or receive a block-specific notification.

## Ordinary unrelated user

Cannot enumerate block relationships.

## Anonymous

No block data access.

## Moderator/Admin

Blocking is user-controlled, not a moderation sanction.

Do not add routine moderator read/control of user blocks in 09B1 unless an existing security/abuse requirement makes a narrowly justified audit view necessary.

09C moderator restrictions are separate.

---

# Public/private exposure rules

Blocking must not appear in public profile payloads, public Proposal/Tavolo payloads, public Resource listing payloads, public search/filtering, analytics, Sentry, push/email payloads, or generic Realtime topics.

`private.audit_events` may store identifier-only block/unblock actions.

Avoid putting display names or other profile content into audit metadata.

---

# Explicit non-goals

## 09B2 — Mobile blocking UX

Do not implement the full UI yet:

- contextual Block menu;
- confirmation dialog;
- warning about shared Projects/active Scambio;
- blocked-user management screen;
- Unblock button;
- outbound-block-specific disabled CTA/copy;
- photo-cache invalidation;
- broad mobile state refresh polish.

A minimal test-only/client contract update is acceptable if generated types require it, but ordinary UI belongs in 09B2.

## 09C

Do not implement moderation hide/unhide, account restrictions, staff Project/Scambio restrictions, Risky warnings, suspension/bans, strikes, or escalation/appeals.

## 09D

No age policy/enforcement.

## Plan 10

No final deletion/anonymization/retention policy for block history.

Also exclude:

- public content hiding;
- pairwise group-chat message filtering;
- direct-message system;
- social follow/friend graph;
- user-provided block reason;
- auto-report on block;
- auto-block on report;
- moderation score.

---

# Co-creator/delegate stack compatibility

The exact 09B1 base does **not** include the separate 07C2 co-creator/delegate stack.

Do not import it.

Implement Project blocking against the canonical creator on this branch.

However:

- centralize the Project applicant↔organizer barrier so manager identities can be composed later;
- document the required convergence;
- do not bake “creator is forever the only organizer for blocking” into a generic block primitive.

When the stacks converge, active co-creators/managers with applicant-management authority must count as organizer-side identities for **new Project interaction blocking** and pending-request handling, while immutable creator ownership/history remains unchanged.

If Codex discovers that 09B1 cannot be cleanly extended later without a material redesign, stop and report the architecture issue instead of silently coupling to the absent branch.

---

# Failure behavior

Do not reveal inbound block direction.

For new-interaction operations blocked by the symmetric barrier, use a stable generic domain error such as interaction/request unavailable.

It should not say:

- “This user blocked you.”
- “The organizer blocked you.”

If the caller is the blocker, 09B2 can separately know its own outbound block and show clearer local UX.

Backend errors remain safe for either direction.

---

# Edge cases

Cover at least:

- self-block rejected;
- block already active retry;
- unblock active block;
- unblock already inactive;
- A blocks B and B independently blocks A;
- A unblocks B while B→A remains;
- re-block after prior unblock preserves history;
- pair has no prior interaction;
- public content remains readable after block;
- public photo remains visible;
- interactions photo becomes inaccessible;
- blocker is Project requester with pending request → withdrawn;
- blocker is Project creator with pending request → rejected;
- pair has pending Project requests in both directions on different Projects;
- pair currently shares Project membership → membership unchanged;
- current Project group chat remains usable;
- former Project membership/history unchanged;
- blocker is Resource requester with pending request → withdrawn;
- blocker is Resource owner with pending request → rejected;
- accepted Resource request/agreement remains unchanged;
- accepted Resource chat remains usable while normally open;
- block after accepted loan does not interrupt return workflow;
- new Resource request after accepted episode later closes is denied while blocked;
- unblock does not resurrect old requests;
- unblock allows fresh interaction only if ordinary eligibility also permits it;
- block vs Project request race;
- block vs Project accept race;
- block vs Resource request race;
- block vs Resource accept race;
- report/corroboration/counterstatement remains usable across block;
- blocked user cannot enumerate inbound block;
- no block-specific notification/outbox exposure.

---

# Testing and validation

## Database / pgTAP

Add focused structure/access tests for:

- private block episodes;
- directional uniqueness;
- no self-block;
- active interval constraints;
- no direct API-role table access;
- security-definer/search-path/grant hygiene;
- block/unblock expected identity;
- outbound-only read privacy;
- symmetric helper behavior;
- double-direction blocks;
- unblock one direction only;
- history preservation.

Add domain tests proving:

### Project
- new request denied while either direction active;
- pending requester-blocks-creator → withdrawn;
- pending creator-blocks-requester → rejected;
- acceptance denied when block wins;
- existing membership unaffected;
- group chat unaffected;
- meeting access unaffected for current accepted participant.

### Scambio-Dona
- new request denied while either direction active;
- pending requester-blocks-owner → withdrawn;
- pending owner-blocks-requester → rejected;
- acceptance denied when block wins;
- accepted agreement unchanged;
- Resource chat/terms/milestones remain ordinarily authorized;
- later new request denied while blocked.

### Photos
- public photo still resolves;
- owner photo access unchanged;
- interaction-only photo denied across blocked pair;
- Project and Resource relationship paths both respect block;
- Storage authorization matches metadata authorization.

### Moderation
- own report status unaffected;
- assigned group corroboration unaffected;
- assigned counterstatement unaffected;
- staff review unaffected.

### Privacy
- no inbound-block list/read;
- public discovery payloads contain no block state;
- identifier-only audit;
- no block-specific outbox/notification event unless strictly required internally and body/direction-safe.

## Concurrency verifier

Add a focused local verifier capable of proving transactional races.

At minimum exercise concurrent:

1. block vs `request_to_join_project`;
2. block vs `accept_project_join_request`;
3. block vs `request_resource_listing`;
4. block vs `accept_resource_listing_request`.

For each race, assert the final canonical state is one of only the valid serial outcomes:

### If interaction wins first
- it may become accepted/current;
- subsequent block remains active;
- existing accepted relationship is preserved.

### If block wins first
- no new pending/accepted relationship survives.

Never allow active block plus a newly-created pending request created after it, or active block plus acceptance that crossed the barrier after block serialization.

Do not print sensitive identities/tokens/messages.

## Regression validation

Run existing affected Project, Resource, photo, chat, and moderation suites/verifiers.

---

# Required commands

Run and report exact results for at least:

- `npm run db:reset`
- `npm run db:lint`
- `npm run db:advisors`
- new focused 09B1 pgTAP suites
- `npm run db:test`
- new block concurrency/local verifier
- affected participation verifier(s)
- affected Resource request/agreement/chat verifier(s)
- profile-photo viewer verifier
- moderation/corroboration/counterstatement verifiers
- `npm run db:types:check`
- `npm run check:web` if generated/shared web contracts are affected
- `npm run check:mobile` if generated/shared mobile code is affected
- `git diff --check`

Run `flutter build apk --debug` only if mobile production code is changed in this backend slice or repository validation policy makes it relevant.

Run Site checks only if root/shared changes can affect Site.

Never claim a command passed if it was not run.

### Current baseline

PR #114 reports:

- full DB suite green: 79 files / 2,692 assertions;
- Web 113 tests + lint/typecheck/build green after one transient Google Fonts retry;
- Mobile 777 tests green;
- Site gate green;
- hosted Actions unavailable due billing/spending-limit runner allocation.

Treat a new DB regression from this green baseline as owned by 09B1 unless proven otherwise.

Do not dismiss failures as inherited without evidence.

### Hosted CI

Make the normal single final-head hosted workflow attempt.

If GitHub again refuses runner allocation for the same billing/spending-limit reason, document it and do not repeatedly rerun it.

---

# Documentation

Update the closest sources of truth, likely:

- `docs/architecture/system-design.md`
- `docs/development/database.md`
- `docs/implementation/roadmap.md`
- `supabase/README.md`
- affected feature READMEs if contracts change.

Document:

- directional block / symmetric barrier;
- public visibility unchanged;
- pending request terminalization;
- existing membership preservation;
- existing accepted Resource coordination preservation;
- Project group chat unchanged;
- interaction-only photo revocation;
- outbound-only block visibility;
- unblock semantics;
- concurrency/lock order;
- 07C2 co-creator convergence requirement;
- moderation evidence independence.

Archive this exact prompt under the normal `history-implementations` convention.

Update roadmap to split 09B if appropriate:

- **09B1 — User Blocking Domain + Enforcement**
- **09B2 — Mobile Blocking UX**

Parent 09 remains in progress.

---

# Acceptance criteria

- [ ] Based exactly on PR #114 head `d85b0122485c7ca09d6cb5f80104ed872d90d17c`.
- [ ] Directional block episodes are durable and history-preserving.
- [ ] Self-block is impossible.
- [ ] Symmetric pair barrier is canonical and reused.
- [ ] Blocked user cannot query inbound block.
- [ ] No block-specific user notification exists.
- [ ] Public profiles/content/listings remain visible.
- [ ] Public photos remain visible.
- [ ] Interaction-only private photo delivery is denied across blocked pair.
- [ ] New Project requests are denied while either direction is active.
- [ ] Pending Project request is withdrawn when blocker=requester.
- [ ] Pending Project request is rejected when blocker=creator.
- [ ] Project acceptance cannot cross a block that wins serialization.
- [ ] Existing Project memberships remain untouched.
- [ ] Existing Project group-chat and meeting access remain ordinary membership-derived.
- [ ] New Scambio-Dona requests are denied while either direction is active.
- [ ] Pending Resource request is withdrawn when blocker=requester.
- [ ] Pending Resource request is rejected when blocker=owner.
- [ ] Resource acceptance cannot cross a block that wins serialization.
- [ ] Existing accepted agreement/chat/loan coordination remains usable.
- [ ] Unblock never resurrects prior requests/interactions.
- [ ] Moderation evidence flows ignore block state.
- [ ] Race tests prove only valid serial outcomes.
- [ ] No new enforcement/moderation-sanction semantics are introduced.
- [ ] Generated contracts/docs are updated.
- [ ] Focused stacked PR is opened against the 09A2B branch and intentionally left unmerged.

---

# Autonomy and stop conditions

Codex may choose table/function/helper names, precise private representation, pagination shape, pair serialization primitive, safe internal refactoring needed to reuse request transition logic, and exact generic interaction-unavailable error code/copy.

Do not stop for ordinary naming/layout decisions.

Stop and report before:

- automatically removing an existing Project member;
- changing group-chat membership/message visibility because of pair block;
- terminating an accepted Resource agreement/loan/chat;
- hiding public content because of block;
- exposing inbound block direction;
- adding a block-specific notification to the target;
- weakening moderation evidence access because of block;
- importing the separate co-creator stack;
- defining staff moderation restrictions as user blocks;
- implementing 09C consequences;
- implementing age policy;
- inventing final block-history deletion/retention policy;
- using a race-prone design that cannot deterministically serialize Block vs Request/Accept.

If ordinary implementation reveals a serious lock-order conflict with existing Project or Resource transitions, stop and report the exact cycle/alternatives rather than shipping a best-effort race.

---

# Completion report

Return:

1. **Summary**
2. **Git** — branch, final commit SHA, PR number/link, exact base branch/SHA
3. **Block model** — episode/history representation and symmetric predicate
4. **Privacy** — outbound/inbound visibility rules
5. **Project effects** — pending/new/existing membership/chat behavior
6. **Scambio-Dona effects** — pending/new/accepted coordination behavior
7. **Photo effects** — public vs interactions access
8. **Concurrency** — exact lock/serialization model and race results
9. **Moderation independence**
10. **Co-creator convergence note**
11. **Audit/notification behavior**
12. **Validation** — exact commands/results
13. **Inherited/environment limitations**
14. **Deferred 09B2 UX**
15. **Stop-worthy findings**

Do not merge or deploy production resources.

