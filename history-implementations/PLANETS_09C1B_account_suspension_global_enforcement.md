# PLANETS 09C1B — Account Suspension Domain + Global Enforcement

## Task type

Security-sensitive moderation/account-access implementation on top of the completed 09C1A manual consequence domain.

This task implements **reversible account suspension** as a distinct moderation consequence plus the minimum authenticated-app gate required by the already-approved product semantics.

It is not the general 09C2 consequence UX project.

## 1. Objective

Implement a manual, reversible **account suspension** consequence.

While suspension is active:

- the user may authenticate;
- PLANETS must identify that account as suspended before granting ordinary signed-in app access;
- the suspended user is routed to a dedicated suspension-status screen;
- they can read only the safe status/reason for their own active suspension plus perform narrow account/session cleanup such as sign out;
- ordinary authenticated/private product reads and mutations are denied;
- Project/Resource chat send and private history access are denied to the suspended identity;
- manager/creator/delegate actions are denied to the suspended identity;
- existing memberships, delegated roles, messages, content, agreements, requests, audit history and capacity records are preserved, not deleted or rewritten;
- other users continue to see historical messages/content according to ordinary rules;
- suspension itself does not automatically hide public Projects/Tavoli/Resource listings;
- suspension itself does not automatically revoke delegated authority or membership;
- revocation restores account-gated access subject to any other still-active consequences, blocks, lifecycle rules, roles and permissions.

No evidence count, report category, corroboration result, AI score, threshold, trigger or background worker may automatically suspend an account.

## 2. Exact Git base

Repository:

`lillo24/planets.community`

Required base:

- PR #123 — `09C1A: manual moderation consequence domain`
- branch: `codex/09c1a-moderation-consequence-domain`
- exact final PR head:
  `010471320779ffb5edaa7546b12cdc8f14809d2d`
- PR #123 is draft and unmerged.

Suggested branch:

`codex/09c1b-account-suspension`

Open a **draft stacked PR** against:

`codex/09c1a-moderation-consequence-domain`

Do not target stale `main`.

Do not merge either PR.

If PR #123 has moved from the exact SHA above, inspect the new commits first and stop if they materially affect consequence schema, account/auth/session handling, moderation roles, routing, Realtime, chat, notifications, or identity helpers.

## 3. Current validated baseline

PR #123 final-head automated validation is green.

Verified:

- 108 pgTAP files;
- 3,415 database assertions;
- 36 moderation-consequence race scenarios;
- full `check:db`;
- real-auth consequence verifier;
- consequence concurrency verifier;
- demo reset/verify/seed/verify;
- Mobile analysis + 1,077 tests;
- Web 142 app tests + 24 tooling tests;
- Site 53 tests;
- final-head GitHub Actions run `37025643669` passed:
  - Change classification;
  - Mobile;
  - Web;
  - Site;
  - Database.

Treat deterministic regressions from this baseline as owned by 09C1B unless proven otherwise.

## 4. Current 09C1A consequence model

09C1A already provides private durable consequence episodes/actions with:

- `safety_notice`;
- `interaction_restriction`;
- `content_hide`;
- required user-facing reason;
- required private case note;
- append-preserved apply/revoke history;
- current moderator/admin staff authorization;
- own safe consequence history;
- identifier-only audit/outbox events;
- evidence/consequence independence;
- concurrency-safe Project/Resource request barriers.

09C1B should extend this model rather than inventing a parallel suspension table unless repository evidence shows an unavoidable reason.

Preferred consequence type:

`account_suspension`

## 5. Suspension is admin-only

Account suspension is a stronger intervention than 09C1A consequences.

Only an active moderation staff member with role:

`admin`

may:

- apply account suspension;
- revoke account suspension.

An ordinary `moderator` may continue to use 09C1A consequences but cannot suspend/unsuspend accounts.

Implement a narrow canonical admin authorization helper rather than relying on UI.

Requirements:

- recheck active role at mutation time;
- fail closed;
- no JWT-only trust;
- deactivated admin cannot perform the next operation.

Do not broaden admin-only enforcement to 09C1A consequence types.

## 6. Self-suspension guard

An admin must not suspend their own current profile.

Reject:

`staff_actor_profile_id = suspension_subject_profile_id`

Another active admin should make the decision.

Do not permit self-suspension through the public RPC.

## 7. Suspension target

Suspension is profile-scoped.

Derive the target from:

`moderation_cases.subject_profile_id`

Do not accept an arbitrary target profile from the client.

Suspension may be based on any moderation case that has the canonical subject profile, provided:

- the case is `under_review` or `completed`;
- an admin consciously selects `account_suspension`.

Do not require a separate profile-only report.

## 8. Apply/revoke reasons

Reuse the 09C1A consequence action rules.

Every suspension apply and revoke requires:

### User-facing reason
- required;
- trimmed;
- nonblank;
- bounded by the existing consequence reason bound;
- stored only in private consequence action history and safe own suspension status.

### Private internal note
- required;
- bounded by existing case-note rules;
- staff-only.

Neither body may enter:

- generic audit metadata;
- outbox payload;
- Realtime;
- logs;
- analytics;
- Sentry.

Use identifier-only events.

## 9. Consequence coexistence

Suspension coexists with:

- safety notice;
- interaction restriction;
- content hide;
- user blocks.

Do not automatically revoke or merge any existing consequence when suspension is applied.

Examples:

- user has interaction restriction, then is suspended → both remain active;
- suspension revoked while interaction restriction remains → account access returns, but new outbound Project/Resource requests remain restricted;
- content hide remains active after account unsuspension;
- user blocks remain unchanged.

Do not encode suspension as a user block.

## 10. Suspension history

Preserve the 09C1A episode semantics:

- one active suspension episode per profile;
- duplicate active apply returns safe conflict;
- revoke closes the active episode;
- historical episode is immutable;
- later re-suspension creates a new episode;
- no destructive delete;
- stable consequence ID remains suitable for future appeals.

## 11. Pending outbound requests on suspension

Applying suspension must withdraw the subject's current pending outbound requests, using the already-proven 09C1A canonical helper/semantics.

### Project
Pending Project join requests where the suspended profile is requester:

`pending → withdrawn`

### Resource
Pending Resource listing requests where the suspended profile is requester:

`pending → withdrawn`

Do not rewrite terminal requests or accepted relationships.

Do not invent a `suspended` request state.

## 12. Acceptance of a suspended requester

A suspended profile must not become a **new** accepted participant/counterparty from a pending outbound request.

Therefore all current acceptance boundaries must reject a suspended requester:

### Project
- Creator compatibility acceptance;
- Creator triaged acceptance;
- Co-creator acceptance;
- Co-organizer acceptance;
- all compatibility overloads.

### Resource
- Resource listing request acceptance.

This must serialize with suspension apply using the canonical profile interaction lock or equivalent.

If acceptance wins before suspension:

- existing accepted membership/agreement remains stored;
- suspension then blocks the suspended identity's access/actions but does not unwind acceptance.

If suspension wins first:

- pending outbound request is withdrawn;
- no later acceptance may cross.

## 13. Existing relationships are preserved in storage

Suspension is an access/action barrier, not destructive cleanup.

Do not automatically:

- remove Project membership;
- remove/deactivate delegate/Co-creator/Co-organizer role;
- rewrite membership intervals;
- alter capacity occupancy;
- cancel Proposal/Tavolo;
- close Resource listing;
- terminate Resource agreement;
- cancel loan/return schedule;
- delete chats/messages;
- delete notifications;
- delete profile/photo/cover media;
- clear workspace;
- remove commitments/contributions;
- delete reports/evidence.

Historical records remain available to **other authorized non-suspended users** according to existing rules.

## 14. Delegated authority during suspension

Keep delegated Project authority records intact.

A suspended:

- Creator;
- Co-creator;
- Co-organizer

cannot exercise manager/structural/operational actions while suspended.

Other non-suspended current managers continue under ordinary rules.

When suspension is revoked:

- the role becomes usable again if it is still active;
- a delegate revoked while the user was suspended remains revoked;
- no authority is recreated.

Do not encode suspension as delegate revocation.

## 15. Public content during suspension

Suspension does **not** automatically hide public content.

Do not silently apply `content_hide`.

Projects/Tavoli/Resource listings owned or managed by a suspended profile remain public if their lifecycle and moderation visibility otherwise make them public.

Reason:

- content hiding is already an independent explicit 09C1A consequence;
- co-managers may still operate a Project;
- account punishment should not silently mutate content policy.

If staff wants public content hidden, they must apply `content_hide` separately.

## 16. Incoming interactions to suspended-owned content

Do not automatically resolve or reject incoming pending requests merely because an owner/manager is suspended.

### Projects

If a Project has at least one non-suspended current manager, those managers may continue to review/reject/accept eligible non-suspended requesters.

A suspended current manager cannot act.

If every current manager is suspended, the Project may remain public unless separately hidden, but no suspended manager can act.

Do not invent automatic Project closure.

### Resource listings

A suspended owner cannot accept/reject/manage while suspended.

Existing incoming pending requests remain pending unless ordinary lifecycle/consequence behavior resolves them.

Do not automatically close the listing.

`account_suspension` and `content_hide` remain orthogonal.

## 17. Public information remains public

Suspension is an account-access control, not an attempt to make public data secret from a person.

A suspended person may view genuinely public PLANETS information after signing out or through the public website, like any anonymous visitor.

Do not promise otherwise.

Backend suspension enforcement must focus on:

- authenticated/private data;
- account-owned state;
- private operational reads;
- mutations;
- private Realtime;
- manager/member/counterparty functionality.

The mobile app should route a currently authenticated suspended account away from ordinary public browsing, but this is a product gate, not a confidentiality guarantee over public data.

## 18. Canonical suspension predicate

Add a private reusable predicate conceptually equivalent to:

`private.profile_has_active_account_suspension(profile_id)`

Also add a fail-closed assertion conceptually equivalent to:

`private.assert_profile_account_active(profile_id)`

Use a stable suspension-specific SQLSTATE/error contract such as `PT403` with safe generic wording.

Do not include the suspension reason in generic RPC errors.

The reason is available only through the dedicated own suspension status API.

## 19. Dedicated suspension-status RPC

Create a narrow expected-identity-bound RPC that remains callable **while suspended**.

Conceptually:

`public.get_own_account_suspension_status(expected_profile_id)`

Return only safe fields:

- `is_suspended`;
- active consequence ID if any;
- applied timestamp;
- user-facing apply reason.

Do not return:

- staff identity;
- internal note;
- report/category;
- reporter/corroborator;
- evidence;
- other consequences;
- audit metadata.

This RPC must validate `auth.uid()` and expected identity but intentionally bypass the general not-suspended assertion.

Anonymous/unrelated access denied.

## 20. Allowed operations while suspended

Use an explicit **small allowlist**.

At minimum permit:

1. `get_own_account_suspension_status`
2. authentication-provider sign out / local session clearing

If sign-out requires unregistering the current push installation, either allow the exact own-device cleanup or make sign-out robust when unregister fails.

Do not allow broad notification/profile/settings APIs for convenience.

Future appeal APIs may be added later.

## 21. Global authenticated/private enforcement

Suspension must deny ordinary authenticated/private RPCs across the product.

Audit the current public authenticated RPC inventory and central identity helpers.

Known identity-helper families include at least:

- `private.require_expected_identity`
- `private.require_participation_identity`
- `private.require_complete_participation_profile`
- Project manager/structural helpers built on participation identity
- `private.require_resource_listing_request_identity`
- `private.require_notification_identity`
- `private.require_push_identity`
- `private.require_moderation_identity`
- blocking identity helpers
- profile-photo identity helpers
- saved-search / Resource helpers where separate
- chat-specific complete-profile helpers

Prefer centralizing the suspension assertion in the lowest safe reusable identity boundary.

Do not rely only on Flutter routing.

Backend private/account-gated operations must fail closed even if called directly.

## 22. Suspension and moderation staff APIs

A suspended profile cannot use moderator/admin product APIs.

Update staff authorization helpers so:

- suspended moderator cannot review cases;
- suspended admin cannot apply/revoke consequences;
- suspended staff cannot access staff-only moderation history/admin app.

Their staff-role row may remain active in storage.

After unsuspension, staff access resumes if the role remains active.

Do not delete staff role automatically.

## 23. Suspension and blocking APIs

A suspended user cannot:

- block;
- unblock;
- list blocked users

while suspended.

Existing block episodes remain unchanged.

Other users may still block/unblock the suspended profile under ordinary rules.

Unsuspension does not alter blocks.

## 24. Suspension and profile/media APIs

A suspended identity cannot:

- edit profile;
- upload/change/clear private profile photo;
- change interaction-photo audience;
- upload/change/clear Project/Tavolo/Resource covers through account-gated management operations.

Existing public media remains visible according to ordinary profile/content visibility and content-hide rules.

Do not delete objects.

## 25. Suspension and Project private reads

A suspended identity cannot use account-gated/private Project reads, including as applicable:

- manager participation queue;
- own join request history;
- current membership-private data;
- protected meeting details;
- group chat history/metadata;
- request chat;
- workspace;
- commitments;
- contribution management;
- Project resource/Needs management;
- delegate/team management;
- private capacity manager reads.

Other authorized non-suspended users retain normal access.

Records remain.

## 26. Suspension and Project mutations

A suspended identity cannot perform:

- create/edit/publish/cancel Proposal;
- create/edit/pause/resume/end Tavolo;
- Project join request;
- join request accept/reject/withdraw;
- leave/remove member;
- Project chat send;
- request-chat send;
- delegate invitation/create/accept/revoke/role change;
- capacity updates;
- workspace set/clear;
- Needs/resource mutations;
- commitment/contribution actions;
- any other Project mutation owned by their identity.

Do not miss Creator compatibility overloads or delegated-manager paths.

## 27. Suspension and Resource private reads/mutations

A suspended identity cannot:

- create/edit/close Resource listing;
- request listing;
- accept/reject/withdraw request;
- read private request details as an authenticated counterparty;
- read/send Resource chat;
- read/propose/accept/reject terms;
- update handoff/milestones;
- manage loan/return/cancel/complete agreement;
- manage saved Resource searches;
- use private owner/requester projections.

Existing data remains.

Other non-suspended counterparties retain their allowed history.

## 28. Suspension and notifications/push

A suspended identity cannot read or mutate ordinary notification inbox/preferences while suspended.

Do not delete existing notifications.

Do not implement full 09C2 suspension-notification delivery here.

Audit push-installation behavior.

If ordinary push delivery continues during suspension, document it. If a narrow safe suppression is straightforward and does not interfere with future suspension applied/revoked delivery, it may be added.

Do not put suspension reason into generic push/outbox payloads.

## 29. Suspension and moderation evidence

Unlike 09C1A restrictions, suspension is intentionally stronger.

While suspended, the account cannot use ordinary report/corroboration/counterstatement UI or APIs.

Do not delete evidence requests/responses.

Pending evidence remains stored.

After unsuspension, unanswered evidence may become available again if the case/lifecycle still permits it.

Staff retains evidence access.

## 30. Private Realtime

Audit authenticated/private Realtime boundaries, including:

- Project group chat;
- Project request chat;
- Resource request chat;
- relevant private notification/channel authorization.

Required:

- new subscription authorization denies active suspension;
- mobile suspension transition tears down existing private subscriptions/controllers;
- suspended user cannot send because canonical mutations deny.

If current Supabase Realtime cannot immediately revoke an already-authorized websocket after server-side suspension:

- document the exact limitation;
- ensure mobile session transition closes subscriptions as soon as suspension is detected;
- ensure app foreground/status refresh detects suspension;
- stop and report if an intentionally non-cooperative suspended client can retain indefinite private live access with no feasible server-side mitigation.

Do not claim stronger revocation than the platform provides.

## 31. Mobile auth/session model

Add:

`AuthSessionPhase.suspended`

The state should carry only safe suspension status:

- identity;
- consequence ID;
- applied time;
- user-facing reason.

On authenticated auth snapshot:

1. validate identity;
2. fetch own suspension status before granting ordinary ready/profile-setup access;
3. active suspension → `suspended`;
4. otherwise continue current profile readiness flow.

## 32. Suspended route/screen

Add a dedicated route, e.g.:

`/account/suspended`

Minimum screen:

- clear account-suspended title;
- user-facing reason;
- applied date/time if useful;
- statement that ordinary account access is unavailable;
- **Check status again**;
- **Sign out**.

Do not show:

- staff notes;
- reporter;
- evidence;
- risk score;
- appeal button before 09C3.

Use current EN/IT localization architecture.

## 33. Router enforcement

While session phase is `suspended`:

- every ordinary app route redirects to suspension route;
- auth verification routes do not escape into normal app;
- invite/deep links go to suspension screen;
- Profile/Settings/Messages/Notifications/Project/Resource routes are inaccessible;
- suspension route itself does not redirect-loop.

After status refresh sees revocation:

- resume ordinary checking-profile → ready/profile-setup flow;
- reapply normal route authorization.

## 34. Mid-session suspension detection

Backend enforcement is canonical.

Mobile must detect suspension without requiring sign-out/sign-in.

At minimum:

- recheck suspension status when app resumes/returns foreground;
- provide manual Check status again;
- tear down private account-scoped controllers/Realtime on suspended transition;
- clear identity-scoped private in-memory caches where current architecture supports invalidation.

If there is a centralized way to react to the suspension SQLSTATE, use it to trigger session refresh.

Do not add fragile ad-hoc handlers to dozens of screens if a central session/access controller can own it.

## 35. Public browse nuance

While authenticated in the mobile app, suspension routing keeps the user on the suspension screen.

But:

- public website remains public;
- anonymous public APIs remain public;
- signing out exposes public content exactly as for any anonymous visitor.

Document this explicitly.

## 36. Suspension application locking

Applying suspension must serialize with new-interaction acceptance.

Reuse:

`private.lock_profile_new_interactions(profile_id)`

or its evolved canonical equivalent.

Apply should:

1. require active admin;
2. lock case;
3. derive subject;
4. reject self-suspension;
5. acquire profile interaction lock;
6. verify no active suspension;
7. append note/action/episode;
8. withdraw pending outbound Project/Resource requests;
9. record identifier-only audit/outbox;
10. commit.

Do not partially suspend if withdrawal fails.

## 37. Suspension revocation locking

Revoke should:

1. require active admin;
2. lock case/consequence;
3. acquire profile interaction lock;
4. append note + action;
5. close suspension episode;
6. identifier-only audit/outbox;
7. commit.

Do not resurrect requests, memberships, roles, blocks or other consequences.

## 38. Mutation shape

Either:

### A. extend existing consequence apply/revoke
with type-specific admin authorization for `account_suspension`;

or

### B. create suspension-specific admin RPCs

if materially safer.

Whichever is chosen:

- preserve 09C1A behavior for existing types;
- moderators cannot gain suspension ability;
- maintain one canonical consequence history.

## 39. Suspension-specific outbox

Use identifier-only source events consistent with 09C1A:

- `moderation.account_suspension_applied`
- `moderation.account_suspension_revoked`

or equivalent.

No reason/note body.

09C2 later projects user-facing delivery.

## 40. Existing content and other users

Suspension must not erase historical presence.

Other users may continue to see, according to existing authorization:

- old Project chat messages;
- old Resource chat messages;
- memberships/history;
- agreement history;
- public profile/content;
- shared group history.

Do not publicly badge suspension.

## 41. Authenticated-RPC audit

Because suspension is global, build an inspectable inventory of authenticated public RPCs.

Classify each relevant operation as:

- `DENY_WHILE_SUSPENDED`
- `ALLOW_WHILE_SUSPENDED`
- `PUBLIC/ANONYMOUS_DATA`
- `SERVICE/WORKER_ONLY`

The allowlist should be intentionally small.

Use this inventory to drive tests/docs.

If practical, add a repository audit test/tool that detects newly added authenticated RPCs bypassing the account-active gate.

## 42. Database tests

Add globally unique pgTAP suites after current max `111` (verify inventory first).

Cover at least:

### Consequence model
- account suspension is profile consequence only;
- one active suspension/profile;
- reapply after revoke creates new episode;
- reason/note privacy.

### Staff role
- admin apply succeeds;
- moderator apply denied;
- ordinary user denied;
- admin revoke succeeds;
- moderator revoke denied;
- inactive admin denied;
- self-suspension denied.

### Status RPC
- subject reads own status/reason;
- unrelated/anonymous denied;
- no staff note/evidence exposure;
- non-suspended profile gets safe inactive result.

### Pending/new interactions
- pending outbound Project/Resource requests withdrawn;
- new Project/Resource request denied;
- Creator/Co-creator/Co-organizer acceptance of suspended requester denied;
- Resource acceptance denied;
- accepted-before-suspension relationships remain stored.

### Project access
- suspended Creator/Co-creator/Co-organizer cannot manage;
- suspended participant cannot read protected meeting/workspace/chat/private data;
- non-suspended co-manager/member retains ordinary access;
- membership/delegate rows preserved;
- occupancy preserved.

### Resource access
- suspended owner/requester cannot use private Resource operations;
- non-suspended counterparty retains ordinary allowed history;
- agreements/listings remain.

### Moderation/staff
- suspended staff cannot use moderation admin APIs;
- staff-role row preserved;
- access resumes after unsuspension if role still active.

### Other account domains
- suspended user cannot manage blocks;
- cannot edit private profile/media;
- cannot read ordinary notifications/preferences;
- dedicated suspension status remains callable.

### Public data
- suspension does not create content hide;
- owner lifecycle unchanged;
- public content remains anonymously accessible where already public.

## 43. Real-auth verifier

Use actual authenticated identities for:

- admin;
- moderator;
- suspended ordinary user;
- Creator;
- Co-creator;
- Co-organizer;
- participant;
- Resource owner/requester;
- unrelated user.

Verify:

- suspension bootstrap/status;
- private RPC denial;
- preservation for other users;
- own reason privacy;
- unsuspension recovery.

Do not print tokens/sensitive reasons.

## 44. Concurrency verifier

Add real transaction races for:

1. suspension vs Project request;
2. suspension vs Creator acceptance;
3. suspension vs delegated-manager acceptance;
4. suspension vs Resource request;
5. suspension vs Resource acceptance;
6. suspension vs representative Project chat send;
7. suspension vs representative Resource chat send.

Required:

### suspension wins
no new mutation crosses.

### mutation wins
the committed historical relation/message remains; later suspension does not delete it.

For chat:

- committed-before-suspension message remains;
- send after suspension boundary fails.

Assert real final DB state; do not rely only on sleeps.

## 45. Realtime verification

Test:

- new private chat subscription authorization denied while suspended;
- client/private subscription teardown on transition;
- unsuspension permits reauthorization if relationship remains.

Document any unavoidable existing-socket limitation honestly.

## 46. Mobile tests

Add unit/widget/router tests for:

- auth bootstrap → suspended;
- suspended route redirect;
- no redirect loop;
- safe reason rendering;
- sign out;
- Check status again while still suspended;
- revoke detected → resumes normal profile readiness;
- account switch clears suspended state;
- app resume refresh;
- deep link/invite redirects to suspension screen;
- private controllers/subscriptions invalidate on suspended transition.

## 47. Localization

Add EN/IT strings with placeholder parity.

At minimum:

- account suspended title;
- body;
- reason label;
- check status again;
- sign out;
- retry/error state.

No raw hard-coded English.

## 48. Web/admin scope

Do not build final admin suspension controls in 09C1B.

09C2 owns final staff consequence UI.

But:

- backend contracts/types must compile;
- suspended staff profile cannot use staff APIs;
- inspect whether the dynamic web app has signed-in user functionality that could bypass suspension and document/fix if needed.

## 49. 09C2 boundary

Defer:

- admin consequence forms/buttons;
- general consequence-history screen;
- contextual safety-warning UX;
- content-hidden banners;
- interaction-restriction CTA UX;
- final moderation notifications/push/email copy.

The minimal suspension screen belongs here because it is required for safe session gating.

## 50. 09C3 boundary

No appeals yet.

Do not add appeal submission, deadlines, messages or review.

Keep stable suspension consequence IDs future-compatible.

## 51. Plan 10 boundary

Do not define final retention/deletion/anonymization for suspension history.

## 52. Documentation

Update:

- `docs/architecture/system-design.md`
- `docs/development/database.md`
- `docs/implementation/roadmap.md`
- `supabase/README.md`
- moderation README(s)
- auth/router docs if present
- Realtime/chat docs if authorization changes.

Document:

- suspension admin-only;
- public content not automatically hidden;
- membership/delegate/agreement history preserved;
- private/account-gated operations denied;
- own suspension status is the deliberate exception;
- anonymous public data remains public;
- any Realtime limitation;
- 09C2/09C3 deferred.

Archive exact prompt as:

`history-implementations/PLANETS_09C1B_account_suspension_global_enforcement.md`

## 53. Roadmap

Update Plan 09:

- 09C1A implemented/in review;
- 09C1B suspension/global enforcement implemented/in review after completion;
- 09C2 not started;
- 09C3 deferred;
- 09D not started.

Parent Plan 09 remains in progress.

## 54. Validation

Return to full green baseline.

### Database

```text
npm run db:reset
npm run db:lint
npm run db:advisors
npm run db:test
npm run db:types
npm run db:types:check
npm run check:db
```

Report final pgTAP files/assertions.

### Existing verifiers

Run all affected verifiers, especially:

- moderation consequences;
- reporting/corroboration/counterstatement;
- blocking;
- Project participation;
- delegated managers;
- capacity;
- Project chat/request chat;
- workspace;
- Project Needs/resources;
- Resource request/agreement/chat/loan;
- notifications/push;
- profile photo/cover media;
- saved searches/matching.

### New verifiers

Run:

- suspension real-auth verifier;
- suspension concurrency verifier;
- authenticated-RPC coverage/audit tool if added;
- Realtime suspension verifier if separate.

### Demo

```text
npm run demo:reset:local
npm run demo:verify:local
npm run demo:seed:local
npm run demo:verify:local
```

### Mobile

```text
npm run check:mobile
flutter build apk --debug
```

### Web

```text
npm run check:web
```

### Site

```text
npm run check:site
```

### Hygiene

```text
npm run format:check
git diff --check
```

Do not claim success while a deterministic repository-owned failure remains.

## 55. Hosted CI

Make one normal final-head hosted attempt.

PR #123 final-head CI is green, so a 09C1B hosted failure should be investigated rather than assumed to be infrastructure.

If GitHub itself fails before runner allocation, document exactly.

Do not repeatedly rerun unchanged infrastructure failures.

## 56. Acceptance criteria

- [ ] Exact base is PR #123 head `010471320779ffb5edaa7546b12cdc8f14809d2d`.
- [ ] Draft stacked PR targets `codex/09c1a-moderation-consequence-domain`.
- [ ] `account_suspension` uses canonical consequence history.
- [ ] Suspension apply/revoke is admin-only.
- [ ] Moderator cannot suspend/unsuspend.
- [ ] Admin cannot self-suspend.
- [ ] Apply/revoke require user reason + private note.
- [ ] Sensitive bodies remain absent from generic audit/outbox/logs.
- [ ] Dedicated own suspension status RPC works while suspended.
- [ ] No broad ordinary account API is intentionally allowlisted.
- [ ] Suspension withdraws pending outbound Project/Resource requests.
- [ ] Suspended requester cannot be newly accepted.
- [ ] Existing accepted membership/agreement is preserved.
- [ ] Membership/delegate/capacity/history records are preserved.
- [ ] Suspended Creator/Co-creator/Co-organizer cannot exercise authority.
- [ ] Non-suspended co-managers continue normally.
- [ ] Suspension does not automatically content-hide public content.
- [ ] Suspension does not revoke blocks or other consequences.
- [ ] Ordinary private Project/Resource/chat access is denied to suspended identity.
- [ ] Suspended staff cannot use moderation staff APIs.
- [ ] Suspended user cannot manage blocking/profile/media/notifications.
- [ ] Public anonymous content remains public.
- [ ] New private Realtime authorization denies suspended identity.
- [ ] Mobile has explicit suspended session phase.
- [ ] Mobile routes suspended identity only to suspension status screen.
- [ ] Screen shows only safe reason/status + check again + sign out.
- [ ] App resume rechecks suspension.
- [ ] Unsuspension restores ordinary bootstrap/access subject to other rules.
- [ ] EN/IT localization parity maintained.
- [ ] Concurrency tests prove valid serial outcomes.
- [ ] Full local DB/demo/mobile/APK/web/site validation passes.
- [ ] Hosted CI final head is attempted and accurately reported.
- [ ] PR remains draft/unmerged.
- [ ] No production deployment.
- [ ] No appeals implementation.
- [ ] No retention-policy invention.

## 57. Stop conditions

Stop and report before:

- making suspension moderator-accessible without explicit founder change;
- allowing admin self-suspension;
- deleting memberships/delegates/messages/content/agreements as suspension behavior;
- automatically hiding all suspended user's public content;
- encoding suspension as user block;
- exposing suspension as public reputation/badge;
- allowing ordinary private RPC access while suspended;
- putting reason text in generic audit/outbox;
- weakening 09C1A privacy;
- implementing appeals;
- inventing retention rules;
- claiming anonymous public data is hidden from a suspended person;
- shipping a Realtime design with a known indefinite private-live-access bypass and no reported mitigation;
- creating router escape from suspension into normal authenticated UI;
- regressing blocking, delegated manager, capacity, workspace or existing moderation behavior.

Ordinary implementation/naming/refactoring choices may be resolved autonomously.

## 58. Completion report

Return:

1. Summary
2. Git — branch, final SHA, PR link/number, exact base
3. Suspension consequence schema/history
4. Admin-only authorization + self-suspension guard
5. Apply/revoke contract and reason privacy
6. Suspension status RPC
7. Authenticated RPC enforcement architecture/inventory
8. Project access/mutation behavior
9. Creator/Co-creator/Co-organizer behavior
10. Resource access/mutation behavior
11. Chat/history behavior
12. Realtime behavior and limitations
13. Notifications/push behavior
14. Public-content behavior
15. Pending request withdrawal/acceptance behavior
16. Existing relationship/data preservation
17. Mobile suspended session/router/screen
18. App-resume/account-switch handling
19. Localization
20. Concurrency/lock hierarchy and race results
21. Staff/moderation behavior
22. Interaction with 09C1A consequences and 09B blocks
23. Validation commands/results + final test counts
24. Demo idempotency
25. Hosted CI result
26. Deferred 09C2 / 09C3 / 09D / Plan 10
27. Stop-worthy findings

Do not merge or deploy production resources.
