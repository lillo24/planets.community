# PLANETS 06B — Mobile In-App Notifications and Preferences

**Roadmap area:** PLANETS 06 — Notification Backbone  
**Task type:** Flutter client over the merged 06A notification domain  
**Repository:** `lillo24/planets.community`  
**Required implementation base:** latest merged `main`  
**Known merged 07A base when this prompt was written:** `08e3d29e8bb72f498d6f1453fdcdf190f16c7e7e`

## Objective

Implement the functional mobile **Notifications** experience over the canonical 06A backend.

07A now exists specifically so participation-request notification alerts have their real destination:

```text
participation_request + request_id
    ↓
/messages/requests/:requestId
```

After 06B:

- authenticated users can open `/notifications`;
- Home exposes a notification bell with unread-count badge;
- notification inbox uses the 06A keyset-paginated read API;
- tapping a request notification opens the corresponding structured 07A Messages request item;
- participant-left notifications can open the creator Participation overview;
- participant-removed notifications can open the relevant Project/Tavolo detail;
- unread count is identity-bound and refreshed at useful lifecycle points;
- users can mark one or all notifications read;
- users have a minimal in-app participation-notification preference;
- changing the visible in-app preference preserves the backend push value, because push controls belong to 06C;
- future/unknown notification data fails safely rather than crashing the inbox or navigating to a guessed route;
- no service-role credentials/projector execution, FCM, push permission, device token, web notification UI, group chat, or new notification backend model is introduced.

This is **06B only**.

**06C — Device Registration and FCM Push Delivery** remains later.

Do not merge the implementation PR.

Before implementation, archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_06B_mobile_in_app_notifications_preferences.md
```

---

# Repository state and required inspection

Work from latest merged `main`.

At minimum inspect:

1. root `AGENTS.md`;
2. `docs/architecture/product-decisions.md`;
3. `docs/architecture/system-design.md`;
4. `docs/development/database.md`;
5. `docs/implementation/roadmap.md`;
6. merged 06A migration/tests/integration;
7. generated database types;
8. merged 07A Messages feature and README;
9. `messages_routes.dart`;
10. merged 05B Participation feature/routes/controllers;
11. Proposal/Tavolo detail route helpers/patterns;
12. `app_router.dart`;
13. `app_navigation_shell.dart`;
14. `foundation_screen.dart`;
15. Auth/profile-readiness/returnTo behavior;
16. app lifecycle/state patterns already used in Flutter;
17. localization and mobile tests;
18. CI workflow.

Important facts:

- PR #17 / 06A merged at `6c3168b17845b2b2567ef42864c3e0f73eb6db97`.
- PR #18 / 07A merged at `08e3d29e8bb72f498d6f1453fdcdf190f16c7e7e`.
- PR #18 post-merge Mobile/Web/Database CI passed.
- The persistent mobile bottom navigation remains **Profile / Browse / Home**.
- `/messages` and `/messages/requests/:requestId` belong to the Home branch.
- `participationRequestMessageRoute(requestId)` is the canonical current mobile helper for request alerts.
- Notifications are alerts; Messages is the persistent actionable request surface.
- Participation is the secondary organizer overview/member-management surface.
- No project group chat exists yet.
- 06A allows nullable generic project context for future standalone domains; every current participation notification still has the context required by its current kind.
- 06A's projector is service-role-only.
- **Flutter must never invoke `process_notification_outbox_batch` or contain service-role credentials.**
- Until 06C provides trusted runtime processing/delivery infrastructure, 06B only displays notifications that have already been projected by trusted backend/test tooling.

---

# Canonical 06A API surface

Inspect the merged generated types and migration rather than assuming this summary is exact.

The client-facing operations are equivalent to:

```text
list_own_notifications(
  p_expected_profile_id,
  p_limit?,
  p_cursor_created_at?,
  p_cursor_id?
)

get_own_unread_notification_count(
  p_expected_profile_id
)

mark_notification_read(
  p_expected_profile_id,
  p_notification_id
)

mark_all_notifications_read(
  p_expected_profile_id
)

list_own_notification_preferences(
  p_expected_profile_id
)

set_own_notification_preference(
  p_expected_profile_id,
  p_category_slug,
  p_in_app_enabled,
  p_push_enabled
)
```

Current inbox rows contain semantic fields equivalent to:

```text
notification_id
category_slug
notification_kind
created_at
read_at

destination_kind

project_id?
project_kind?
project_title?

request_id?

actor_profile_id?
actor_display_name?
```

Do not call the service-only projector from Flutter.

---

# 1. Flutter notification feature

Add a focused feature, preferably:

```text
apps/mobile/lib/features/notifications/
```

using the established structure:

```text
domain/
data/
application/
presentation/
README.md
```

Define narrow client models equivalent to:

```text
AppNotification
NotificationKind
NotificationDestinationKind
NotificationPreference
NotificationsPage
NotificationCursor
```

Current known kinds:

```text
participation_request_received
participation_request_withdrawn
participation_request_accepted
participation_request_rejected
participant_left
participant_removed
```

Current destinations:

```text
participation_request
project_participation
project_detail
```

Do not create models for device tokens or delivery attempts.

## Forward-safe parsing

Do not let one future server-added category/kind/destination crash the complete inbox of an older app.

Prefer an explicit unknown/fallback representation for unrecognized category, notification kind, or destination.

Requirements:

- known current items remain strictly validated;
- unknown items render generic safe copy;
- unknown/unsupported destination is non-navigable;
- no guessed route;
- no raw wire value shown to users;
- malformed IDs/timestamps still fail safely;
- current known participation kinds require the context their canonical semantics need.

---

# 2. Supabase gateway

One mobile gateway owns the 06A authenticated notification APIs.

No direct table reads. No service role.

Do not access:

```text
notifications
profile_notification_preferences
private.outbox_events
private.outbox_consumer_receipts
```

directly.

Gateway responsibilities:

- list page;
- unread count;
- mark one read;
- mark all read;
- list effective preferences;
- set one preference;
- safe/strict parsing.

Expected identity comes from the rendered Auth identity and is passed on every call.

Map backend errors to app-owned safe failures.

---

# 3. Routing

Add Home-branch routes:

```text
/notifications
/notifications/preferences
```

Keep existing Messages routes unchanged.

Do not add a fourth bottom-navigation item.

## Auth/readiness

Notifications/preferences require a ready authenticated profile.

Signed-out access → OTP Auth with exact safe `returnTo`.

Incomplete profile → existing setup flow while preserving the destination.

Identity changes must discard retained private notification screens/state.

Use a narrow `isNotificationsPath` helper or equivalent rather than brittle repeated string logic.

---

# 4. Home notification entry

The current Home app bar already exposes Messages.

Add a notification bell action alongside it, conceptually:

```text
[bell badge] [messages]
```

Exact order/styling is Codex-owned.

## Unread badge

When authenticated and unread count > 0:

- show Material badge/label;
- cap display sensibly, e.g. `99+`;
- accessibility semantics describe the unread count.

At zero, show the ordinary bell without a misleading badge.

If unread-count loading fails:

- keep the bell usable;
- omit the badge rather than breaking Home.

Do not fetch unread state while signed out.

No final app/navigation redesign in 06B.

---

# 5. Notification inbox

Implement `/notifications`.

App bar:

- title;
- **Mark all as read** when meaningful;
- Settings/preferences action.

Support:

- initial loading;
- empty;
- safe error/retry;
- pull-to-refresh;
- keyset load-more;
- stable ordering;
- no duplicate items.

Use exact 06A cursor semantics:

```text
created_at
notification_id
```

No offset pagination.

Refreshing starts from first page.

---

# 6. Notification presentation copy

Flutter owns localized copy.

For known kinds, use concise semantic wording equivalent to:

```text
Mario requested to join “Community Garden”
Mario withdrew the request to join “Community Garden”
Your request to join “Community Garden” was accepted
Your request to join “Community Garden” was rejected
Mario left “Community Garden”
You were removed from “Community Garden”
```

Targets:

- first four → structured Messages request item;
- participant-left → creator Participation overview;
- participant-removed → Project/Tavolo detail.

If actor/project title is missing:

- use generic localized copy;
- never render `null`, UUIDs, or raw backend values;
- only navigate when the required semantic IDs remain valid.

---

# 7. Read/unread behavior

Unread items should be subtly but accessibly distinct; do not rely only on color.

No deletion or swipe-to-delete.

## Tap

Tapping a known notification should:

1. mark it read if unread;
2. update unread count/local inbox state;
3. navigate to its semantic target.

Read persistence should not become a hard blocker for valid navigation on a transient backend failure.

Codex may use an optimistic or awaited approach, but:

- stale identity must never navigate;
- failure must reconcile safely;
- no duplicate mutation taps.

---

# 8. Semantic destination resolver

Implement one pure/narrow resolver.

## `participation_request`

Requires `request_id`.

Reuse merged 07A:

```text
participationRequestMessageRoute(requestId)
```

→ `/messages/requests/:requestId`

Do **not** route request alerts to the Participation screen.

## `project_participation`

Requires `project_id + project_kind`.

Map to existing 05B organizer route:

```text
/proposals/:id/participants
/tavoli/:id/participants
```

Reuse current helpers/adapters where possible.

## `project_detail`

Requires `project_id + project_kind`.

Map to:

```text
/proposals/:id
/tavoli/:id
```

## Unknown/non-project future destinations

Return no route unless the app explicitly understands the semantic target.

Future standalone non-project notifications must not crash the app.

Never derive navigation from notification copy.

---

# 9. Mark all read

Expose a secondary **Mark all as read** action.

Call `mark_all_notifications_read`.

After success:

- current represented rows become read locally;
- refresh authoritative unread count.

If newer rows arrived concurrently, authoritative count may remain nonzero.

Repeated action is idempotent.

---

# 10. Unread refresh strategy

06B does not use Realtime or frequent polling.

Refresh unread count:

- when ready identity becomes available;
- when Home/Notifications becomes active where practical;
- after mark one;
- after mark all;
- after pull-to-refresh;
- on app resume if a narrow existing lifecycle integration supports it cleanly.

No timers/background service.

This should be compatible with future 06C trusted projection/push.

---

# 11. Preferences UI

Implement:

```text
/notifications/preferences
```

Use the canonical list/set preference RPCs.

## Expose only meaningful controls now

Show:

```text
Participation alerts
  In-app notifications [on/off]
```

Do **not** expose inactive placeholder categories yet:

- Chat;
- Resources;
- Matching;
- Project activity.

Do not expose Push before 06C.

Do not expose Email.

## Preserve hidden push value

The backend setter takes both in-app and push booleans.

When changing the visible in-app toggle:

1. load the effective backend preference;
2. retain current `push_enabled`;
3. send it unchanged;
4. change only `in_app_enabled`.

Do not hard-code `push_enabled = true` or false.

Parse future/other categories safely but do not mutate them.

---

# 12. Preference semantics

When Participation in-app is disabled, 06A suppresses future in-app notification-row creation while recording successful processing.

The UI may explain simply:

- setting affects future in-app participation alerts;
- existing notification history remains.

Do not claim anything about push before 06C.

Do not delete existing notifications when disabled.

---

# 13. Projector/security boundary

06B must never call:

```text
process_notification_outbox_batch
```

Do not:

- bundle service-role key;
- expose DB/admin credentials;
- add authenticated projector wrapper;
- read raw outbox events;
- project notifications client-side.

Local/native QA must generate/project fixtures through trusted local tooling outside Flutter.

---

# 14. Native QA fixture/tooling

Inspect existing:

```text
scripts/verify-local-notifications.mjs
```

If its generated local accounts/state are convenient for device QA, document how to use them rather than duplicating tooling.

If not, a narrow local-only helper such as:

```text
scripts/prepare-local-notification-qa.mjs
```

is acceptable.

It must:

- derive local service credentials from local Supabase status only;
- prepare deterministic local notification data;
- invoke the trusted projector outside Flutter;
- print only safe QA instructions;
- never print OTP/tokens/private request text/exact meeting data.

No QA seeding button in the app.

---

# 15. Account-switch/race safety

Inbox, unread count, and preferences are private identity-bound state.

On sign-out/account switch:

- clear inbox;
- clear unread count;
- clear preferences;
- discard pending page/action responses.

After async work check controller revision, identity, and target.

Cover:

- page 2 for A finishing under B;
- unread count A finishing under B;
- mark-read finishing after switch;
- preference mutation finishing after switch;
- notification tap interrupted by identity change.

No A data may render under B.

---

# 16. Error/privacy behavior

Never render:

- raw PostgREST/SQL messages;
- email;
- source outbox IDs;
- request message;
- exact meeting details;
- tokens.

Inbox failure must not break Home.

Unread failure must not block bell navigation.

Preference failure should restore/reload authoritative state.

Unknown kinds/destinations must remain safe.

---

# 17. Localization/accessibility

Localize:

- Notifications;
- no notifications;
- unread-count semantics;
- Mark all as read;
- notification settings;
- Participation alerts;
- In-app notifications;
- preference explanation;
- six current notification kinds;
- generic fallback;
- retry/load-more.

Long names/project titles must wrap.

Unread state must be understandable without color alone.

Bell badge needs accessible count semantics.

---

# 18. No database migration expected

Consume merged 06A as-is.

Do not change backend merely for client formatting or convenience.

If a concrete security/correctness blocker appears, stop and report before creating a forward migration.

---

# 19. Flutter tests

Add focused domain/controller/widget/router tests.

## Parsing

Cover:

- six current kinds;
- three destinations;
- nullable generic project context;
- required context for known participation kinds;
- unknown future kind/category safe fallback;
- unknown destination non-navigable;
- malformed timestamp/ID failure.

## Destination resolver

Cover exactly:

```text
participation_request -> /messages/requests/:requestId
project_participation + one_time -> /proposals/:id/participants
project_participation + recurring -> /tavoli/:id/participants
project_detail + one_time -> /proposals/:id
project_detail + recurring -> /tavoli/:id
```

Missing required target/unknown destination → no unsafe route.

## Router/auth

Cover:

- `/notifications` Home branch;
- `/notifications/preferences` Home branch;
- bottom nav unchanged;
- signed-out OTP returnTo;
- profile-setup return;
- account switch clearing private state.

## Home badge

Cover:

- signed out: no count fetch;
- zero unread;
- positive count;
- `99+` or chosen cap;
- count failure leaves bell usable.

## Inbox/read state

Cover:

- loading/empty/error/retry;
- known copy + generic fallback;
- read/unread presentation;
- keyset load more;
- refresh;
- mark one;
- mark all;
- no duplicate pages.

## Taps

Cover:

- request → 07A Messages item;
- participant-left → Participation;
- participant-removed → project detail;
- read state updates;
- stale identity cannot navigate.

## Preferences

Cover:

- only Participation in-app control visible;
- no Push;
- no fake future-category controls;
- mutation preserves loaded `push_enabled`;
- no hard-coded hidden push value;
- failure reload/revert;
- unknown future categories do not break UI.

---

# 20. Regression validation

Keep green:

- all 06A notification pgTAP/integration;
- 07A Messages integration;
- 05A/05B participation behavior;
- all earlier database integrations;
- generated type drift;
- Flutter localization/format/analyze/tests;
- Web tests/lint/typecheck/build;
- `git diff --check`.

No hosted provider required.

---

# 21. Documentation / roadmap

Add:

```text
apps/mobile/lib/features/notifications/README.md
```

Document:

- 06A RPC boundary;
- Notifications vs Messages;
- semantic navigation;
- unread refresh;
- currently exposed preference;
- hidden push preservation;
- service-only projector;
- 06C handoff.

Update mobile routing docs and roadmap.

Correct stale statuses:

```text
06A — Implemented
PR #17
6c3168b17845b2b2567ef42864c3e0f73eb6db97

07A — Implemented
PR #18
08e3d29e8bb72f498d6f1453fdcdf190f16c7e7e
```

Preserve actual native-QA evidence; do not invent it.

While this PR is open:

```text
06 parent — In progress
06B — In progress
06C — Not started

07 parent — In progress
07B — Not started
```

05C and 04C remain separately not started.

---

# 22. Manual native QA gate

Leave PR unmerged.

Android minimum; iOS where available.

Use trusted local tooling to prepare projected notifications.

Check:

1. signed-out Home bell → OTP → returns to Notifications;
2. Home still exposes Messages;
3. bottom nav unchanged;
4. unread badge absent at zero;
5. badge appears with fixture notifications;
6. incoming request notification renders correctly;
7. request tap opens exact 07A Messages request item;
8. accepted/rejected/withdrawn alerts open resolved request items;
9. participant-left opens creator Participation overview;
10. participant-removed opens Project/Tavolo detail;
11. tapping unread marks read;
12. badge decrements/reloads;
13. Mark all clears current unread state;
14. pull-to-refresh;
15. load-more if fixture allows;
16. long copy wraps;
17. missing context fails safely;
18. preferences shows Participation in-app only;
19. no Push toggle;
20. no fake Chat/Resources/Matching/Project activity controls;
21. disabling Participation leaves existing history;
22. trusted future event while disabled creates no new in-app notification;
23. re-enable and later trusted event appears;
24. account switch with inbox open;
25. account switch during preference mutation;
26. account switch during notification tap/read;
27. no raw private/request/location data;
28. no service-role/projector access in Flutter;
29. no group chat/push UI.

---

# Non-goals

Do not implement:

- service-side projector scheduling;
- device registration;
- FCM/APNs;
- push permission/preference UI;
- web notifications;
- notification deletion;
- notification Realtime/frequent polling;
- Messages redesign;
- project group chat;
- chat/resource/matching notification generation;
- 04C/05C;
- final navigation redesign.

---

# Acceptance criteria

06B is ready when:

- [ ] based on merged PR #18 main;
- [ ] exact prompt archived;
- [ ] `/notifications` and `/notifications/preferences` exist in Home branch;
- [ ] no fourth bottom tab;
- [ ] Home bell/unread badge works without breaking signed-out Home;
- [ ] inbox uses only 06A client RPCs;
- [ ] pagination uses created_at + notification_id;
- [ ] six known kinds have localized safe copy;
- [ ] unknown future kinds/destinations are safe;
- [ ] request alerts navigate to 07A Messages request route;
- [ ] participant-left navigates to Participation;
- [ ] participant-removed navigates to project detail;
- [ ] mark-one/mark-all work;
- [ ] unread count is identity-safe;
- [ ] only meaningful Participation in-app preference is exposed;
- [ ] no Push toggle before 06C;
- [ ] in-app mutation preserves backend push_enabled;
- [ ] disabling preference does not delete history;
- [ ] Flutter never calls service projector;
- [ ] no service-role secret in mobile;
- [ ] account switching clears notification state;
- [ ] Mobile/Web/Database CI green;
- [ ] native QA remains pre-merge;
- [ ] PR remains unmerged.

---

# Autonomy and stop conditions

Codex may decide exact Dart/provider names, badge styling, card layout, localized wording, optimistic vs awaited mark-read behavior, lifecycle refresh implementation, and local QA helper strategy.

Stop and report before:

- adding a fourth bottom-nav item;
- calling projector/service-role APIs from Flutter;
- exposing Push now;
- exposing inactive future category controls;
- routing participation_request to Participation instead of Messages;
- adding Realtime/polling infrastructure;
- adding FCM/device tokens;
- changing 06A schema without a real blocker;
- implementing group chat;
- merging the PR.

---

# Deliverables

Produce:

1. exact archived 06B prompt;
2. Flutter Notifications feature;
3. safe 06A gateway/models;
4. identity-bound inbox/unread/preferences controllers;
5. `/notifications`;
6. `/notifications/preferences`;
7. Home bell + unread badge;
8. localized six-kind presentation;
9. semantic destination resolver using 07A;
10. mark-one/mark-all;
11. Participation in-app preference preserving hidden push;
12. safe refresh strategy;
13. native-QA fixture instructions/helper if needed;
14. Flutter/router/widget tests;
15. docs/roadmap reconciliation;
16. focused PR, preferably `codex/06b-mobile-in-app-notifications`;
17. structured completion report.

Do not merge the PR.

---

# Completion report

Return:

1. **Summary**
2. **Branch/base/PR**
3. **Changed files**
4. **Notification Flutter architecture**
5. **06A gateway/models**
6. **Forward-safe parsing**
7. **Routes/Auth**
8. **Home bell/unread badge**
9. **Inbox/pagination**
10. **Notification copy**
11. **Read/unread behavior**
12. **Semantic destination resolver**
13. **07A Messages navigation**
14. **Participation/project navigation**
15. **Preferences UI**
16. **Hidden push preservation**
17. **Refresh/lifecycle behavior**
18. **Account-switch/race safety**
19. **Privacy/error handling**
20. **Localization/accessibility**
21. **Flutter tests**
22. **Backend regression validation**
23. **Native-QA preparation**
24. **06A/07A roadmap reconciliation**
25. **06C handoff**
26. **07B handoff**
27. **Manual native QA remaining**
28. **Warnings/blockers**
29. **Commit/PR reference**
