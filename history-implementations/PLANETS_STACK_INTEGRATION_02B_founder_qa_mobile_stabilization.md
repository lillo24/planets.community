# PLANETS STACK-INTEGRATION-02B — Founder QA Mobile Stabilization

**Repository:** `lillo24/planets.community`  
**Existing PR:** #120 — `STACK-INTEGRATION-02: consolidate current PLANETS product stacks`  
**Patch in place from exact head:** `f5958e00e9b1abb02b079f5489b769502fb3c88b`  
**Branch:** `codex/stack-integration-main-candidate`  
**Target remains:** `main`  
**Do NOT open another PR. Do NOT merge #120.**

Archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_STACK_INTEGRATION_02B_founder_qa_mobile_stabilization.md
```

## Objective

Patch PR #120 in place for three founder-QA issues:

1. fix the Riverpod/Realtime crash when leaving a private participation-request chat;
2. fix Profile → Review Requests back navigation;
3. add WhatsApp-style counterparty avatars to private chats using the existing profile-photo cache/batch infrastructure.

Then rerun the full integration-candidate validation.

## Exact starting state

Verify before editing:

```text
PR #120
base: main @ 06e983bb230a7a48514095fe407250ad6d38c148
head: f5958e00e9b1abb02b079f5489b769502fb3c88b
draft: true
mergeable: true
```

The prior founder correction from `3d822dc...` to `f5958e00...` fixed blocking/manager/capacity convergence and must remain intact.

If the head moved, stop and report the new head.

Work only on `codex/stack-integration-main-candidate`; do not create PR #121.

---

# A. Realtime / Riverpod lifecycle crash

## Observed real crash

Founder physical-device QA produced:

```text
Tried to modify a provider while the widget tree was building.

ProjectRequestChatController._replace
ProjectRequestChatController.stopSignals
_ProjectRequestChatScreenState.dispose
StatefulElement.unmount
```

A second late path occurred while Realtime unsubscribe emitted status:

```text
ProjectRequestChatController._replace
ProjectRequestChatController._handleStatus
RealtimeChannel.unsubscribe
ProjectRequestChatController._closeSubscription
ProjectRequestChatController.stopSignals
_ProjectRequestChatScreenState.dispose
```

Relevant current files:

```text
apps/mobile/lib/features/project_request_chat/presentation/project_request_chat_screen.dart
apps/mobile/lib/features/project_request_chat/application/project_request_chat_controller.dart
apps/mobile/lib/features/project_request_chat/data/project_request_chat_gateway.dart
```

The screen currently calls `stopSignals()` in `dispose()`. `stopSignals()` can update provider state and closing the channel can invoke an `onStatus(disconnected)` callback that also updates state.

## Required invariant

Widget unmount may:

```text
disable signals
cancel timers
detach/close subscriptions
release widget resources
```

but must not synchronously publish provider state during Flutter finalize/unmount.

Once signals are disabled, late callbacks from the closed subscription must be ignored.

Prefer a clear lifecycle distinction, e.g. a teardown-only detach path or an option that closes without state publication. Do not paper this over with arbitrary delayed `Future(...)` state mutations.

Closing/detaching must be idempotent.

## Audit analogous controllers

Inspect the same pattern in:

```text
ProjectChatListController
ProjectChatDetailController
MessageChatsController
ResourceChatController
```

Current integrated code has `stopSignals()` methods that can close subscriptions and sometimes clear `hasConnectionIssue`; some status callbacks lack teardown guards.

Fix analogous unsafe dispose paths consistently, but do not redesign the full Realtime architecture.

Expected behavior:

```text
Back / swipe / route change
→ subscriptions close
→ old disconnected callback may arrive
→ callback is ignored
→ no Riverpod state mutation during unmount
```

## Tests

Add focused teardown tests:

- private request chat with active subscription;
- pop/unmount;
- close emits disconnected;
- no provider-mutation exception;
- no late state change;
- repeated close safe;
- analogous tests only for other controllers that required fixes.

---

# B. Review Requests back-stack

## Current cause

Current route hierarchy:

```text
/profile
  └── reports
       └── review-requests
```

Profile directly navigates to `/profile/reports/review-requests`, so GoRouter correctly places My Reports beneath Review Requests.

Founder observed:

```text
Profile
→ Review Requests
→ Back
→ My Reports
→ Back
→ Profile
```

Expected:

```text
Profile
→ Review Requests
→ Back
→ Profile
```

## Required hierarchy

Make these siblings:

```text
/profile
├── reports
└── review-requests
```

Canonical route should be approximately:

```text
/profile/review-requests
/profile/review-requests/corroboration/:requestId
/profile/review-requests/counterstatement/:requestId
```

Update:

```text
ModerationRoutes
app_router.dart
ProfileScreen
tests
any internal/deep-link references
```

Use navigation semantics deliberately so entering Review Requests from Profile produces exactly one child page above Profile.

Prefer a narrow redirect from the old `/profile/reports/review-requests...` paths to the new canonical paths if cleanly possible.

Required tests:

```text
Profile → My Reports → Back = Profile
Profile → Review Requests → Back = Profile
Review Requests → Corroboration → Back = Review Requests
Review Requests → Counterstatement → Back = Review Requests
old Review Requests URL → canonical destination without My Reports in pop stack
```

---

# C. Private-chat profile photos

## Product behavior

For one-to-one/private chats, show the other person's avatar on the left like a conventional messaging app.

### Chats → Private

Add a leading avatar to:

```text
Project participation-request private-chat row
Scambio-Dona private Resource-chat row
```

Do NOT add a person avatar to Project group-chat rows.

### Project participation-request chat detail

Show the counterparty avatar beside the counterparty name in the AppBar or a compact header.

The Resource private-chat detail already has `_CounterpartyHeader` with `VisibleProfilePhotoAvatar`; keep that and do not duplicate it.

---

## Reuse existing photo infrastructure

Do not invent another image downloader/cache.

Existing:

```text
VisibleProfilePhotoController
visibleProfilePhotoProvider
VisibleProfilePhotoAvatar
```

already:

- batch-loads metadata for up to 50 targets;
- keeps authorized bytes in memory;
- skips repeat loads for ready entries;
- reuses bytes when `versionKey` is unchanged;
- clears private cached state on account change;
- ignores stale async results using identity/target revisions.

Use it.

### Traffic behavior

Private list rendering should be:

```text
load chat page
→ collect unique counterparty IDs
→ one visible-photo batch metadata request
→ download only authorized photos not already cached
→ cards render immediately with placeholders
```

Pagination should only add missing targets.

Photo failure/denial must never make the Messages list fail.

Do not add persistent disk caching in this task. Persistent caching of interaction-only private photos needs a separate authorization/expiry design.

---

## Resource chat list contract

`ProjectRequestMessageChatItem` already has:

```text
counterpartyProfileId
counterpartyDisplayName
```

`ResourceMessageChatItem` currently does not.

Do NOT fetch each Resource chat summary per visible row.

Extend the canonical private chat projection:

```text
list_own_scoped_message_chat_items(...)
```

with Resource-only discriminated fields such as:

```text
resource_counterparty_profile_id
resource_counterparty_display_name
```

For Resource rows derive the opposite party from:

```text
listing.owner_profile_id
request.requester_profile_id
current_profile_id
```

and ensure it is never the viewer.

Other discriminators return null for those Resource-only fields.

Update:

```text
RPC return shape
generated DB types
MessageChatsPayloadParser exact key set
ResourceMessageChatItem
fakes/tests
```

Do not change scope/order/pagination/activity semantics.

---

## Project request photo authorization must follow current managers

The original profile-photo interaction policy predates delegated managers and was Creator-centric.

The current product allows:

```text
Creator
active Co-creator
active Co-organizer
```

to manage pending applicants/private request chats.

Therefore a pending requester's `interactions` photo must be visible to any **current Project manager**, not only the immutable Creator.

A revoked delegate must stop qualifying.

For a current accepted participant, current managers may continue viewing the participant's interactions photo under the current-interaction rule.

### Requester viewing Creator

The requester should be able to see the canonical Creator photo in the private request chat through a privacy-safe current Project/request context.

Do not globally expose all manager photos to participants.

### Historical privacy

Rejected/withdrawn/former relationships must not gain permanent interaction-only photo visibility merely because chat history remains.

If no current/public authorization remains, show the placeholder.

### Migration guidance

Because `private.profile_is_project_manager(...)` exists only after later delegate migrations, use a new late corrective migration on #120 rather than introducing bad early-migration ordering.

Centralize the current Project photo-interaction predicate and preserve exact canonical Storage-path authorization.

---

## Resource photo authorization

Do not redesign it unnecessarily.

Current Scambio-Dona interaction photo access is already bidirectional while accepted coordination is open.

Reuse it.

When coordination closes and an interaction-only photo becomes unauthorized, list/detail should fall back to placeholder.

---

## Private-list photo orchestration

Add one non-blocking private-list photo orchestration path.

Requirements:

- never mutate photo provider synchronously in widget `build`;
- schedule load outside build;
- dedupe profile IDs;
- respect max batch 50;
- pagination loads only new IDs;
- account switch remains safe;
- group scope does not fetch person photos.

Avatar semantics should identify the counterparty by display name without inventing image descriptions.

---

# D. Connectivity observation — do not turn it into product code

During founder QA:

```text
Lost connection to device.
```

was followed by another `npm run dev:mobile`.

The physical Android config uses:

```text
http://127.0.0.1:54321
```

which depends on:

```text
adb reverse tcp:54321 tcp:54321
```

The captured second launch did not re-establish the reverse tunnel.

Therefore the later widespread `Something went wrong` screens are currently classified as likely local ADB reverse loss, not a proven app regression.

Do not add global retry/error suppression or change Supabase configuration to compensate.

Only report a product connectivity bug if it reproduces with the local backend demonstrably reachable from the phone.

A concise getting-started note about rerunning `adb reverse` after a physical-device reconnect is acceptable if not already documented.

---

# E. Required tests

## Database

If profile-photo auth / unified-chat contract changes, add globally unique pgTAP suites after current `105`.

Cover:

- Creator sees pending requester interactions photo;
- Co-creator sees it;
- Co-organizer sees it;
- revoked delegate denied;
- current manager sees current participant interactions photo;
- requester sees intended Creator photo in request-chat context;
- rejected/withdrawn historical relation does not create persistent interaction visibility;
- stale/guessed Storage object remains denied;
- Resource private row returns correct counterparty ID/name for both sides;
- viewer is never returned as counterparty;
- non-Resource discriminator fields are null;
- chat scopes/order/pagination unchanged.

## Flutter

Cover:

### Lifecycle
- ProjectRequestChat teardown with active Realtime;
- disconnect callback on unsubscribe;
- no provider mutation during unmount;
- no late state update;
- analogous controllers fixed by audit.

### Navigation
- Profile → Review Requests → Back;
- detail → Review Requests;
- old route redirect.

### Private chat list
- Project-request leading avatar;
- Resource leading avatar;
- placeholder;
- non-blocking async fill;
- batch target IDs;
- group rows unchanged;
- existing card navigation/status/preview unaffected.

### Project-request chat detail
- requester sees Creator avatar/placeholder;
- Creator sees requester;
- Co-creator/Co-organizer sees requester where authorized;
- revoked manager cannot retain unauthorized image;
- banner/actions/composer unchanged.

### Resource detail
- existing counterparty avatar still works;
- no duplicate avatar/header;
- blocking action remains.

### Cache
- ordinary rebuild does not redownload ready photo;
- unchanged version reuses bytes;
- changed version downloads new bytes;
- account switch clears private entries;
- stale download ignored.

---

# F. Documentation / PR #120 update

Update:

```text
docs/development/stack-integration-2026-09.md
```

with a founder-QA stabilization section covering:

- Realtime dispose root cause/fix;
- moderation route hierarchy fix;
- private-chat avatar + batching/cache behavior;
- any new cumulative DB contract;
- ADB reverse classification.

Update relevant feature docs.

Patch PR #120 body with the new final head and a concise correction summary.

Keep PR #120 draft and unmerged.

Do not open another PR.

---

# G. Full validation again

Run affected tests first, then the entire integration candidate.

## Database

```text
npm run db:reset
npm run db:lint
npm run db:advisors
npm run db:test
npm run db:types:check
npm run check:db
```

## Demo

```text
npm run demo:reset:local
npm run demo:verify:local
npm run demo:seed:local
npm run demo:verify:local
```

## Mobile

```text
npm run check:mobile
flutter build apk --debug
```

## Web/site

```text
npm run check:web
npm run check:site
```

## Hygiene

```text
npm run format:check
git diff --check
```

Also verify:

- English/Italian localization parity;
- unique migration timestamps;
- unique pgTAP prefixes;
- MLS/OpenMLS remains absent.

Allow one normal final-head hosted CI attempt. If GitHub again blocks before runner assignment due the known billing/spending-limit issue, document once and do not rerun.

---

# Acceptance criteria

- [ ] Started from exact `f5958e00e9b1abb02b079f5489b769502fb3c88b`.
- [ ] PR #120 patched in place; no new PR.
- [ ] `main` untouched.
- [ ] No Riverpod provider mutation occurs during private chat unmount.
- [ ] Late Realtime close/status callbacks are ignored after detach.
- [ ] Analogous unsafe teardown paths fixed where present.
- [ ] Review Requests is sibling to My Reports under Profile.
- [ ] Back/swipe from Review Requests entered from Profile returns directly to Profile.
- [ ] Review detail Back returns to Review Requests.
- [ ] Private Project-request chat list shows counterparty avatar/placeholder.
- [ ] Private Resource chat list shows counterparty avatar/placeholder.
- [ ] Group chat rows do not get a person avatar.
- [ ] Project-request chat detail shows counterparty avatar.
- [ ] Existing Resource detail avatar remains intact.
- [ ] Private-list photo metadata is batched, not N+1.
- [ ] Existing version-aware in-memory byte cache is reused.
- [ ] No persistent disk cache added.
- [ ] Current Co-creator/Co-organizer requester-photo authorization works.
- [ ] Revoked/historical relationships fail closed appropriately.
- [ ] Resource counterparty identity comes from the canonical unified chat projection.
- [ ] Photo absence/denial cannot break Messages.
- [ ] Prior blocking/capacity correction remains intact.
- [ ] Full DB validation green.
- [ ] Demo idempotency green.
- [ ] Full mobile validation green.
- [ ] Android debug APK builds.
- [ ] Web/site green.
- [ ] Format/diff green.
- [ ] Integration record and #120 body updated.
- [ ] #120 remains draft/unmerged.

# Completion report

Return:

1. exact starting head;
2. final head;
3. confirmation #120 patched in place;
4. Realtime lifecycle root cause/fix;
5. analogous teardown paths audited/fixed;
6. final Review Requests route/back behavior;
7. private-chat list avatar behavior;
8. Project-request detail avatar behavior;
9. Resource detail regression result;
10. unified Resource counterparty contract change;
11. profile-photo authorization change for Creator/Co-creator/Co-organizer;
12. batch/cache behavior and confirmation no disk cache;
13. focused test results;
14. pgTAP files/assertion count;
15. `check:db`;
16. demo idempotency;
17. mobile test count + APK;
18. web/site;
19. format/localization/audits;
20. hosted CI;
21. confirmation:
    - `main` unchanged,
    - no new PR,
    - #120 draft/unmerged,
    - previous blocking/capacity fix retained,
    - ADB reverse issue was not hidden with product-code hacks absent a reachable-backend reproduction.
