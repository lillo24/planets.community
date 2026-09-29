# PLANETS 09B2 — Mobile User Blocking UX

## Objective

Implement the ordinary-user mobile experience for the canonical 09B1 blocking domain.

After this plan, a signed-in PLANETS user should be able to:

- Block another user from relevant person/context surfaces.
- Unblock someone they themselves currently block.
- Review and manage their active outbound blocks from Profile.
- Understand the important consequences before confirming a block.
- Immediately see block-driven state changes reflected in the current mobile UI.
- Receive safe, non-direction-revealing feedback when a new Project/Scambio interaction is unavailable because of the symmetric backend barrier.

09B2 must consume and preserve the 09B1 semantics rather than reproducing blocking rules in Flutter.

Blocking remains a user-controlled relationship action, not a moderation sanction.

---

# Required Git base and stacking

Repository:

`lillo24/planets.community`

Implement this as a new isolated branch/worktree based on the exact reviewed head of PR #116:

- PR #116: `PLANETS 09B1: User blocking domain enforcement`
- branch: `codex/09b1-user-blocking-domain`
- exact dependency commit: `6f4a786f06e5df73453a7c2199719846756e3eb5`

Prefer branch name:

`codex/09b2-mobile-blocking-ux`

Open a focused stacked PR against:

`codex/09b1-user-blocking-domain`

Do not target stale `main`.

Do not merge automatically. Leave the PR open for founder review and stacked integration.

If the dependency branch moved away from the exact SHA above, inspect and report the material difference before changing bases.

Do not import the separate Settings/localization or 07C2 co-creator stacks.

---

# Current repository evidence

Verified on PR #116 head:

## Canonical backend already implemented

09B1 already owns:

- private, history-preserving directional block episodes;
- at most one active directional block per pair direction;
- `block_user`;
- `unblock_user`;
- `list_own_blocked_profiles`;
- one canonical symmetric pair barrier when either direction is active;
- sorted-profile transaction advisory locking before Project/Resource locks;
- race-safe enforcement on new Project requests and Project acceptance;
- race-safe enforcement on new Resource requests and Resource acceptance;
- canonical pending-request closure;
- interaction-only profile-photo denial;
- no block-specific notification/outbox/Realtime disclosure;
- no effect on moderation evidence.

09B2 must not redesign those rules.

## Mobile surfaces already exposing relevant identities

The exact base currently exposes users in places including:

- Proposal detail — organizer identity and existing Report action;
- Tavolo detail — organizer identity and existing Report action;
- Scambio-Dona listing detail — listing owner identity and existing Report action;
- Creator Project participation — pending applicants and current/historical members;
- Project chat — individual human messages with sender profile IDs and Report action;
- Resource request detail — owner/requester identities and request actions;
- Resource chat — one canonical counterparty identity plus message Report actions;
- Profile — existing `My reports` and `Review requests` entries.

There is no general mobile public-profile directory/screen that 09B2 needs to invent.

## Existing blocking read limitation

`list_own_blocked_profiles` is intentionally outbound-only and paginated.

That is appropriate for the management list, but is not sufficient for accurately rendering one visible target as **Block** versus **Unblock** without potentially enumerating every page of the user's outbound blocks.

09B2 should add one narrow exact outbound-only block-status read as described below.

---

# Product semantics to preserve exactly

## Directional action, symmetric new-interaction barrier

If A blocks B:

- A owns that block action and may later unblock it;
- B is not told A blocked them;
- neither person can start a new direct Project/Scambio interaction while either directional block remains active.

09B2 may know only the current user's own outbound block state.

It must never expose whether the target blocks the current user.

## Public visibility remains unchanged

Blocking does not hide:

- public profiles/fields;
- public photos;
- public Proposals;
- public Tavoli;
- public Scambio-Dona listings;
- public historical content.

Do not visually remove or filter those items merely because the current user blocked their creator/owner.

## Existing Project membership/group chat remains

Blocking does not automatically:

- remove a member;
- leave a Project;
- hide Project group-chat messages;
- remove group-chat send/read access;
- remove protected meeting access for current accepted members.

Users who block each other can therefore still share a Project and still see one another in its group chat.

The UI must not imply otherwise.

## Existing accepted Scambio-Dona coordination remains

Blocking does not terminate an already accepted Resource coordination episode.

Existing:

- agreement;
- loan/return workflow;
- terms/milestones;
- Resource chat

remain usable under their ordinary lifecycle rules.

This is important so blocking cannot strand an active exchange/loan.

## Pending requests close and do not return

Blocking immediately closes pending direct requests canonically:

- blocker-as-requester → withdrawn;
- blocker-as-creator/listing-owner → rejected.

Unblocking does not resurrect those requests.

## Private interaction photos disappear

`interactions` profile-photo access is revoked across the blocked pair while public photos remain available.

09B2 must invalidate relevant client caches after Block/Unblock so stale private photos do not remain rendered.

## Moderation remains independent

Blocking must not hide or disable:

- reports;
- own report status;
- group corroboration;
- Resource counterstatement;
- moderation Review Requests.

Do not add block checks to moderation UI/controllers.

---

# Small backend addition required by 09B2

Add a new **additive migration** with one narrow exact outbound-only read.

Do not edit the 09B1 migration.

Conceptually implement an expected-identity-bound operation such as:

`get_own_blocked_profile_status(expected_blocker_profile_id, target_profile_id)`

It should return either zero rows or one row containing only safe outbound information, for example:

- block episode ID;
- target profile ID;
- safe target display name;
- blocked timestamp.

Requirements:

- caller identity must match expected blocker;
- return a row only if the caller currently blocks that target;
- no row when caller does not block target;
- no reciprocal/inbound field;
- no indication that the target blocks the caller;
- no moderation/profile-private data;
- no broad table grants;
- locked `search_path` and deliberate EXECUTE grant consistent with repository conventions.

This RPC exists solely so mobile can truthfully choose **Block** or **Unblock** for a target without enumerating the paginated management list.

Do not add a generic symmetric `is_blocked_between` client RPC. That would reveal inbound state.

---

# Mobile feature architecture

Create a focused mobile blocking feature consistent with current feature-first organization, likely under:

`apps/mobile/lib/features/blocking/`

Let repository inspection choose exact filenames, but separate at least:

- domain models;
- Supabase gateway/RPC contract;
- application/controller state;
- presentation helpers/screens.

The mobile client must call only the canonical 09B1/09B2 RPCs.

Do not reproduce the symmetric barrier rules client-side.

---

# Identity-scoped state

Blocking state must be scoped to the authenticated profile.

Requirements:

- clear all block caches/state on sign-out/account switch;
- never reuse outbound state loaded for another account;
- only update local state after canonical block/unblock success;
- stale operations from a previous identity must not mutate the new identity's UI state;
- exact per-target status may be cached in memory for the current identity;
- management-list pagination must remain independently correct.

Follow the existing identity-safe controller patterns used elsewhere in the app.

---

# Blocked users management

Add a new authenticated Profile entry:

**Blocked users**

Recommended route:

`/profile/blocked-users`

Place it near existing safety/account entries such as `My reports` / `Review requests` on the exact base.

Do not depend on the separate Settings PR.

## Screen requirements

Use `list_own_blocked_profiles` with its canonical keyset pagination.

Each row should show:

- safe display name;
- blocked date/time if useful;
- **Unblock** action.

Provide:

- loading state;
- empty state;
- retry/error state;
- pagination/load-more where needed;
- pull-to-refresh if consistent with nearby app patterns.

Do not show:

- users who block the current user;
- reciprocal status;
- moderation history;
- email/private profile data.

Unblocking a row should remove it from the current list only after backend success.

---

# Contextual Block / Unblock actions

Add user blocking where PLANETS already shows a meaningful identifiable person.

Do not invent a new people directory.

At minimum cover the following surfaces.

## 1. Proposal detail organizer

For a ready authenticated viewer who is not the organizer:

- allow **Block organizer**;
- if the viewer currently blocks the organizer, show **Unblock organizer** instead.

Keep existing Report behavior.

Blocking must not hide the Proposal after success.

If the viewer is already a current participant, shared Project membership/chat remain available.

## 2. Tavolo detail organizer

Same rules as Proposal detail.

Do not hide the Tavolo after block.

## 3. Scambio-Dona listing owner

For a ready authenticated non-owner viewer:

- Block owner / Unblock owner.

Keep existing Report behavior.

Do not hide the listing after block.

If accepted coordination already exists, it remains usable.

## 4. Creator participation: applicant/member

Add a person action for:

- pending applicants;
- current members;
- historical left/removed members where the identity remains legitimately visible.

For a pending applicant:

- blocking them canonically rejects the pending request through 09B1;
- after success, refresh the participation projection so the request no longer appears as pending.

For a current member:

- blocking does **not** remove the member;
- confirmation must make this explicit.

For historical members:

- blocking remains allowed;
- no historical membership record changes.

Do not combine **Block** with the existing **Remove member** action. They are distinct actions with distinct consequences.

## 5. Resource request detail

Expose Block/Unblock for the other owner/requester counterparty.

If the Resource request is pending:

- blocking may withdraw/reject it according to 09B1;
- refresh the request after success.

If accepted/open:

- clearly preserve the accepted agreement/chat workflow.

## 6. Resource chat counterparty

Expose Block/Unblock from the existing counterparty header/card or a nearby overflow action.

Blocking must not close the current Resource chat while ordinary accepted coordination remains open.

After block, purge any cached interaction-only counterparty photo and reload safe state.

## 7. Project chat message sender

For another user's human message, keep Report and add a way to Block/Unblock that sender.

Prefer a compact overflow/action menu rather than adding multiple competing icons to every message bubble if that better fits the current UI.

The action must use the canonical sender profile ID from the message.

Important copy:

Blocking this person does **not** hide their messages in this shared Project chat and does not remove either person from the Project.

Do not implement pairwise message censorship.

---

# Report and Block remain distinct

Do not automatically:

- report when blocking;
- block when reporting;
- suggest that blocking creates moderator review;
- suggest that reporting creates a block.

Existing Report actions remain usable even after Block.

Where both actions are adjacent, a shared overflow/safety menu is acceptable if it keeps the distinction clear.

---

# Block confirmation

Blocking can irreversibly close pending requests even though Block itself is reversible.

Therefore always confirm before calling `block_user`.

Use concise copy equivalent to:

**Block [name]?**

> You won't be able to start new direct Project or Scambio-Dona interactions with each other while either block remains active.
>
> Any pending direct requests between you may be closed and will not come back if you later unblock.
>
> Public content can still be visible. If you already share a Project, you may still see each other and each other's group messages. Existing accepted Scambio-Dona coordination remains available so it can be completed.
>
> PLANETS will not notify this person that you blocked them.

Adapt wording to a generic `this user` when a safe name is unavailable.

Do not claim that the current user knows whether the other person has also blocked them.

Context-specific copy may emphasize the visible consequence:

- pending Project request → request will close;
- current Project member → membership remains;
- accepted Resource coordination → current exchange/loan/chat remains.

But the underlying semantics must remain identical.

---

# Unblock confirmation

Confirm before Unblock.

Use meaning equivalent to:

**Unblock [name]?**

> You may be able to start new interactions again if all other PLANETS rules allow it. Previous withdrawn/rejected requests and ended relationships will not be restored.
>
> PLANETS will not notify this person that you unblocked them.

Do not claim interaction will definitely succeed after unblock because an independent inbound block may still exist and must remain private.

---

# Safe handling of inbound blocks

This is a critical privacy requirement.

The mobile client can know only:

- `I block this person`;
- or `I do not currently block this person`.

It must not know:

- `this person blocks me`;
- `a symmetric block exists`.

Therefore:

## When own outbound block is active

For new direct interaction CTAs where the target is known, it is acceptable to show a local explanation such as:

> You blocked this user. Unblock them before starting a new interaction.

Provide a path to Unblock where natural.

## When own outbound block is not active

If backend request/accept returns the 09B1 generic `PT409` / interaction-unavailable result, show only generic copy such as:

> This interaction isn't available right now.

Do not say or imply:

- they blocked you;
- one of you blocked the other;
- this is a block conflict.

Other domain conflicts may also use generic unavailable behavior.

---

# Interaction CTA integration

Use outbound status to improve UX where a visible target is the exact direct counterparty.

Examples:

## Proposal/Tavolo join

If the current user themselves blocks the organizer:

- do not submit a doomed join request;
- disable/replace the Join action with an outbound-block-aware explanation and Unblock path.

If they do not outbound-block the organizer:

- keep normal Join behavior;
- an inbound block remains invisible and may result in generic unavailable error from backend.

## Scambio-Dona request

Same pattern for listing owner.

Do not add a client-side symmetric-block check.

## Creator/owner acceptance

Normally a block created by the current creator/owner will already have canonically closed the pending request, so the pending item should disappear after refresh.

Still map any concurrent `PT409` from acceptance to safe generic unavailable copy and refresh canonical state.

---

# Cache invalidation and refresh

After successful Block/Unblock, update the current UI immediately and safely.

## Block-state cache

- update exact outbound target state;
- update/remove management-list entry as appropriate.

## Profile-photo cache

After **Block**:

- purge any cached interaction-only photo bytes/metadata for the target;
- invalidate contextual organizer/owner photo state where relevant;
- reload only through canonical backend reads if the surface remains visible.

This must prevent a private `interactions` photo from remaining visible merely because Flutter cached it before the block.

After **Unblock**:

- invalidate stale target photo state;
- do not assume the photo becomes visible;
- let normal canonical relationship/audience authorization determine whether reload returns a photo.

## Domain projections

Refresh the currently affected state after Block because 09B1 may have closed pending requests:

- Project participation/request projections;
- Resource request/history/detail projections;
- Messages request projection if currently relevant;
- public detail own-pending/request state;
- related photo state.

Do not globally reload the entire app when a focused invalidation is enough.

---

# Existing accepted coordination UI

## Project

Do not make an existing shared Project look blocked/removed.

If both users remain current members:

- Project still opens;
- group chat still works;
- messages remain visible;
- meeting details remain available according to membership.

The only UI change should be that future direct interactions are blocked and private interaction-only photo may disappear.

## Scambio-Dona

For an already accepted/open Resource agreement:

- request/agreement detail remains accessible;
- Resource chat remains accessible and sendable under ordinary lifecycle rules;
- loan/return coordination remains available.

A Block action here should warn that current coordination continues.

Do not display a fake `blocked/read-only` state on accepted Resource chat.

---

# Blocking feature failures

Add localized failure handling for Block/Unblock operations.

Examples:

- block/unblock network/backend failure → `Couldn't update blocked users. Try again.`
- target unavailable → safe generic unavailable state;
- stale account → fail without mutating current identity state.

Do not surface raw Postgres/Supabase messages directly when they would expose internal details.

---

# Localization

The exact 09B2 base is not the separate Italian-localization stack.

Add the required English ARB strings to the current canonical catalog on this branch and run localization generation.

Do not import the localization stack merely for 09B2.

Record that new blocking strings must be reconciled/translated when the localization stack converges.

If the exact base already contains additional locale catalogs by implementation time, update all repository-required catalogs according to current l10n rules rather than leaving generated catalogs inconsistent.

---

# Data/privacy constraints

Do not expose inbound block state in:

- Flutter models;
- RPC return types;
- logs;
- analytics;
- Sentry;
- error messages;
- UI semantics/accessibility text.

Do not log target identities or block relationship details unnecessarily.

Do not create block notifications, push, or Realtime events.

Do not add blocking to moderation evidence authorization.

---

# Explicit non-goals

## Backend semantics

Do not change 09B1 decisions about:

- symmetric barrier;
- request closure;
- existing membership preservation;
- accepted Resource coordination preservation;
- public visibility;
- interaction-photo authorization;
- concurrency locks.

The only expected backend addition is the narrow exact **outbound-only** status read needed for UI truthfulness, plus tests/generated types/docs for it.

## Co-creators/delegates

Do not import 07C2 or implement manager blocking convergence here.

Keep the documented 09B1 convergence requirement.

## 09C

Do not implement:

- staff restrictions;
- content hide/unhide;
- Risky warning;
- suspension/ban;
- strikes;
- escalation/appeals.

## 09D

No age/minor policy.

## Plan 10

No final block-history retention/deletion/anonymization policy.

Also exclude:

- hiding public content from blocked users;
- pairwise Project-chat message filtering;
- direct messages;
- follower/friend graph;
- block reason text;
- automatic report-on-block;
- blocking analytics.

---

# Edge cases

Cover at least:

- current user blocks target from Proposal detail;
- current user unblocks target from Proposal detail;
- Tavolo organizer action;
- Resource listing owner action;
- Project pending applicant blocked → request refreshes as no longer pending;
- current Project member blocked → member remains visible/current;
- historical member blocked → history unchanged;
- Resource pending request blocked → request terminalizes and UI refreshes;
- accepted Resource counterparty blocked → agreement/chat remains usable;
- Project chat message sender blocked → message remains visible;
- Resource chat counterparty blocked → chat remains usable;
- public content remains visible after block;
- public photo remains visible;
- cached interaction-only photo disappears after block;
- unblock does not assume private photo access is restored;
- target blocks caller but caller does not block target → UI must not reveal inbound block;
- caller has outbound block and target independently also blocks caller → Unblock caller's direction only; future interaction may still fail generically;
- account switch while block confirmation is open;
- account switch during block/unblock request;
- duplicate button tap;
- block backend failure;
- unblock backend failure;
- block list pagination;
- block list refresh after contextual block;
- unblock from management list updates contextual cache;
- moderation Review Requests still work after block;
- report action remains available after block.

---

# Testing

## Database

If the exact outbound status RPC is added, add focused pgTAP coverage proving:

- caller sees own active outbound block;
- caller sees no row when they do not block target;
- reciprocal/inbound block is not revealed;
- unrelated user cannot inspect another user's block;
- self/identity protections remain sound;
- direct private-table access remains denied;
- function grants/search path follow repository security rules.

Run existing 09B1 suites unchanged to prove no semantic regression.

## Flutter gateway/domain/application

Test:

- exact outbound status parsing;
- block/unblock calls;
- identity-scoped caching;
- account-switch clearing;
- duplicate action protection;
- list pagination;
- safe failure mapping;
- generic interaction-unavailable mapping without block-direction language.

## Flutter presentation

Test:

- Profile `Blocked users` entry and route;
- loading/error/empty/list/pagination states;
- Unblock from management list;
- Block/Unblock on Proposal organizer;
- Tavolo organizer;
- Resource listing owner;
- creator participation applicant/member;
- Resource request counterparty;
- Resource chat counterparty;
- Project chat sender;
- confirmation copy for block/unblock;
- outbound-block-aware Join/Request behavior;
- inbound-block-safe generic failure behavior;
- current Project membership/chat remains usable;
- accepted Resource chat remains usable;
- photo cache invalidation;
- Report remains available;
- accessibility semantics do not reveal inbound state.

Use focused widget/controller tests rather than relying only on snapshots.

---

# Validation commands

Run and report exact results for at least:

- `npm run db:reset`
- `npm run db:lint`
- `npm run db:advisors`
- focused 09B1/09B2 database tests
- full `npm run db:test`
- `npm run blocking:verify:local`
- `npm run db:types:check`
- `npm run check:mobile`
- `flutter build apk --debug`
- focused affected Project/Resource/profile-photo verifiers where client/backend contract changed
- `npm run check:web` because a new DB RPC changes the checked-in generated TypeScript contract
- `git diff --check`

Run Site checks only if shared/root changes affect Site.

Never claim a check passed when it was not run.

## Current baseline

PR #116 reports:

- focused blocking pgTAP: 76 assertions green;
- full DB suite: 81 files / 2,768 assertions green;
- affected Project/Resource/photo/moderation verifiers green;
- block concurrency verifier green;
- Web tooling/application/lint/typecheck/build green;
- hosted CI unable to allocate a runner because of billing/spending-limit state.

Treat new failures against this baseline as 09B2-owned unless proven otherwise.

## Hosted CI

Make the normal single final-head attempt.

If GitHub again refuses to allocate the runner for the same billing/spending-limit reason:

- document the infrastructure failure;
- do not repeatedly rerun it.

---

# Documentation

Update the closest sources of truth, including as appropriate:

- `docs/architecture/system-design.md`
- `docs/development/database.md`
- `docs/implementation/roadmap.md`
- `apps/mobile/README.md`
- blocking feature README;
- affected Project/Resource/photo feature READMEs;
- `supabase/README.md` if the exact outbound status RPC is added.

Document:

- where users can Block/Unblock;
- blocked-user management;
- outbound-only UI knowledge;
- safe inbound-block failure behavior;
- confirmation consequences;
- photo cache invalidation;
- existing Project and accepted Resource coordination remaining visible/usable;
- no public content filtering;
- localization-stack convergence note.

Archive this exact implementation prompt under the normal `history-implementations` convention.

Roadmap should mark:

- **09B1 — User Blocking Domain + Enforcement** as implemented/in current open stack;
- **09B2 — Mobile Blocking UX** as implemented/in review after this PR.

Parent Plan 09 remains in progress because 09C and 09D remain outstanding.

---

# Acceptance criteria

- [ ] Based exactly on PR #116 head `6f4a786f06e5df73453a7c2199719846756e3eb5`.
- [ ] One narrow exact outbound-only block-status RPC exists.
- [ ] No mobile/backend field reveals inbound/reciprocal block state.
- [ ] Profile exposes a Blocked users management screen.
- [ ] Management list paginates safely and Unblock works.
- [ ] Proposal organizer supports Block/Unblock.
- [ ] Tavolo organizer supports Block/Unblock.
- [ ] Resource listing owner supports Block/Unblock.
- [ ] Project participation applicant/member supports Block/Unblock without confusing Block with Remove.
- [ ] Resource request counterparty supports Block/Unblock.
- [ ] Resource chat counterparty supports Block/Unblock while accepted coordination remains usable.
- [ ] Project chat message sender supports Block/Unblock while group messages remain visible.
- [ ] Block always requires confirmation explaining pending-request closure, public visibility, shared-group behavior, accepted Resource continuity, and no notification.
- [ ] Unblock confirmation states prior relationships are not restored and does not promise future interaction success.
- [ ] Current outbound block can explain/disable new Join/Resource Request locally.
- [ ] Inbound-only block produces only generic `interaction unavailable` UX.
- [ ] No UI reveals or infers inbound block direction.
- [ ] Public content is not filtered after block.
- [ ] Public photos remain visible.
- [ ] Cached interaction-only photos are purged after block.
- [ ] Existing Project membership/chat remains usable.
- [ ] Existing accepted Resource agreement/chat remains usable.
- [ ] Relevant pending request/detail/inbox state refreshes after Block.
- [ ] Report/corroboration/counterstatement UI remains independent.
- [ ] Identity/account-switch isolation is tested.
- [ ] Mobile tests + debug APK pass.
- [ ] Database/generated contract tests pass.
- [ ] Focused stacked PR is opened against the 09B1 branch and left unmerged.

---

# Autonomy and stop conditions

Codex may choose:

- exact Flutter feature filenames;
- whether contextual actions use buttons, overflow menus, or reusable action sheets;
- exact state-provider/controller composition;
- how to perform focused cache invalidation;
- exact concise wording preserving the semantics above.

Do not stop for ordinary UI composition decisions.

Stop and report before:

- exposing inbound block state;
- filtering public content because of block;
- hiding shared Project chat messages between blocked users;
- making Block remove a Project member;
- making Block terminate accepted Resource coordination;
- adding block notification/push/Realtime disclosure;
- changing 09B1 concurrency semantics;
- importing the co-creator stack;
- adding 09C moderation consequences;
- adding minimum-age behavior;
- inventing final retention/deletion policy.

If implementation reveals that accurate outbound Block/Unblock state requires broader backend disclosure than the narrow outbound-only exact read above, stop and report rather than weakening privacy.

---

# Completion report

Return:

1. **Summary**
2. **Git** — branch, final SHA, PR number/link, exact base branch/SHA
3. **Backend addition** — exact outbound-only status RPC and privacy proof
4. **Mobile architecture** — blocking gateway/controller/state ownership
5. **Management UX** — Blocked users screen
6. **Contextual actions** — surfaces where Block/Unblock exists
7. **Confirmation copy/behavior**
8. **Inbound-block privacy UX**
9. **Project effects in UI**
10. **Scambio-Dona effects in UI**
11. **Photo/cache invalidation**
12. **Account-switch safety**
13. **Validation** — exact commands/results
14. **Environment limitations**
15. **Deferred work** — 07C2 convergence, 09C, 09D, Plan 10
16. **Stop-worthy findings**

Do not merge or deploy production resources.
