# PLANETS QA-01 — Navigation, Public Profile, and Android Back Fixes

**Task type:** Mobile QA bug-fix slice  
**Repository:** `lillo24/planets.community`

## Base

Base on the current top implemented mobile branch:

```text
PR #84 — 04C4D2 Mobile Loan Schedule + Availability UX
branch: codex/04c4d2-mobile-loan-schedule
head: 07cee1a0aa344c4224ad30e0ec58c8c8ff31577e
```

Before implementation: fetch `origin/main`, verify PR #84 still points to the expected head or reconcile newer stack movement, preserve unrelated work, branch from the final #84 head, and do not merge any PR.

Preferred branch:

```text
codex/qa01-navigation-public-profile-back
```

Open a draft PR against `codex/04c4d2-mobile-loan-schedule`.

Archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_QA01_navigation_public_profile_back.md
```

No database migration is expected.

---

# Manual-QA bugs to fix

1. Signed out on Home: tapping the Notifications bell sends the user directly into the same email-OTP flow as the Messages/mail action.
2. Browse → Profile while signed out redirects to `Sign in with email`.
3. Opening Scambio-Dona from Home makes `/resources` occupy the Home branch, so tapping Home later returns to Scambio rather than the actual Home screen.
4. Android system Back/back-swipe from nested pages can exit the app instead of returning to the previous page.
5. Bottom navigation order should be:

```text
Profile | Home | Browse
```

with Home in the middle.

Inspect at minimum:

```text
apps/mobile/lib/app/router/app_router.dart
apps/mobile/lib/app/router/app_navigation_shell.dart
apps/mobile/lib/app/foundation_screen.dart
apps/mobile/lib/features/notifications/presentation/home_notification_button.dart
apps/mobile/lib/features/profile/presentation/profile_screen.dart
apps/mobile/test/app/router/navigation_shell_test.dart
```

Preserve the useful `StatefulShellRoute.indexedStack` architecture.

---

# 1. New shell order and route ownership

Reorder the enum/branches to:

```text
AppBranch.profile
AppBranch.home
AppBranch.browse
```

Route ownership:

## Profile

```text
/profile
/profile/edit
```

## Home

```text
/
messages routes
notifications routes
```

## Browse

```text
/proposals...
/tavoli...
/resources...
```

Move Resource listing discovery/owner/listing-detail routes from Home to Browse, including current routes such as:

```text
/resources
/resources/mine
/resources/create
/resources/:listingId
/resources/:listingId/edit
/resources/:listingId/loan-schedule
```

Do **not** move Resource request/chat routes out of Messages.

---

# 2. Home must always mean Home

The canonical Home root is `/`.

Opening Scambio from the Home card must:

```text
Home → /resources
→ select Browse branch
```

and must not mutate the retained Home stack.

Then:

```text
tap Home
→ /
```

not `/resources`.

If already in Home branch on a nested Home-owned route such as `/messages` or `/notifications`, tapping Home should reset that branch to `/` using the current `go_router` API (`goBranch(..., initialLocation: true)` or equivalent).

Do not make re-tapping Browse/Profile destroy retained state unnecessarily.

---

# 3. Bottom navigation order

Render:

```text
Profile | Home | Browse
```

with icons:

```text
Profile → person
Home → home
Browse → explore
```

No fourth destination.

Update keys/tests deliberately.

---

# 4. Signed-out Profile is public

Change guards so:

```text
/profile
```

is public/signed-out accessible.

Keep:

```text
/profile/edit
```

protected.

Signed-out tab switching to Profile must never auto-open `/auth`.

---

# 5. Signed-out Profile fac-simile

When signed out, `ProfileScreen` should show a clearly labelled static example rather than a blank page.

Suggested structure:

```text
Example profile / Fac-simile

[generic avatar placeholder]
Your name

Short example bio

Skills
[Gardening] [Photography] [Repairs]

Community activity — example
Projects joined 4
Projects created 1
Example community badge
```

Requirements:

- clearly localized `Example profile` / fac-simile label;
- generic avatar only;
- no fake backend identity/UUID/network load;
- example stats/badges must be visibly illustrative, not claimed as implemented real account data;
- explicit CTA:
  ```text
  Sign in / Create your profile
  ```
  routing to Auth with `returnTo=/profile`.

Authenticated real Profile behavior remains unchanged.

---

# 6. Signed-out Notifications bell

Keep the bell visible, but signed out it must not silently navigate to `/notifications` and trigger Auth.

Instead:

1. bell tap stays on Home;
2. show localized Snackbar/equivalent:
   ```text
   Sign in to see your notifications.
   ```
3. provide explicit `Sign in`;
4. only that action navigates to `/auth?returnTo=/notifications`.

No unread badge signed out.

Signed-in bell behavior remains unchanged.

---

# 7. Android Back navigation rule

Audit navigation calls using this semantic rule:

```text
drill-down within current branch → push/history
branch/root switch → go/goBranch/canonical replacement
```

Representative drill-downs to inspect:

```text
Proposal list → detail
Tavolo list → detail
Scambio list → detail
loan schedule → request
Messages requests → request detail
Messages chats → chat detail
```

Do not mechanically replace every `go`.

Auth redirects, bottom-nav switching, and canonical post-save routes should remain replacement navigation where appropriate.

---

# 8. Root Back behavior

Expected system Back:

```text
nested detail/editor → previous screen in same branch

Profile root → Home

Browse roots:
  /proposals
  /tavoli
  /resources
→ Home

Home root /
→ allow Android to exit/background normally
```

Generalize the current `PopScope`, which recognizes only some Browse roots.

Do not trap Back at Home.

---

# 9. Direct/deep-link branch selection

Direct:

```text
/resources
/resources/:id
```

must select Browse.

Direct:

```text
/messages...
/notifications...
```

remain Home-owned.

Moving Resource discovery must not change protected Resource management guards or Messages routes.

---

# 10. Auth/readiness regression

Preserve sanitized `returnTo` behavior for:

```text
Messages
Notifications
Resource management
Participation
Project resource management
Profile edit
```

Public Resource list/detail remain signed-out accessible.

Protected `/resources/mine`, create/edit/schedule ownership behavior remains protected.

---

# 11. Documentation

Update `apps/mobile/lib/app/README.md` and any directly relevant navigation docs to state:

```text
Profile | Home | Browse
```

and Resource discovery belongs to Browse.

Do not rewrite unrelated architecture docs.

---

# 12. Automated tests

Add/update tests for:

### Shell order

```text
index 0 Profile
index 1 Home
index 2 Browse
```

### Core Scambio regression

```text
Home → Scambio
→ /resources
→ Browse selected

tap Home
→ /
→ Home selected

tap Browse
→ retained /resources
```

### Signed-out Profile

```text
Profile tab
→ no Auth redirect
→ fac-simile visible
→ explicit Sign in CTA
```

### Signed-out bell

```text
bell tap
→ stays Home
→ explanatory UI
→ no Auth yet

explicit Sign in
→ /auth with returnTo=/notifications
```

### Back

Representative routes:

```text
/proposals/:id → /proposals
/resources/:id → /resources
/messages/chats/:id → /messages
/profile root → /
/resources root → /
```

Home root must remain poppable by the system.

---

# 13. Physical Android QA

Verify on a real Android phone:

1. launch at Home;
2. Home → Scambio selects Browse;
3. Home button returns actual Home;
4. Browse returns retained Scambio;
5. Scambio detail system-back → Scambio list;
6. Proposal detail system-back → Proposal list;
7. signed-out Profile → fac-simile, no OTP;
8. signed-out bell → explanation, no OTP;
9. explicit bell Sign in → OTP;
10. Home-root Back exits/backgrounds normally.

---

# 14. Validation

Run:

```text
npm run check:mobile
flutter build apk --debug
npm run check:web
npm run check:site
git diff --check
```

No DB migration expected.

Attempt hosted Validation once. If GitHub billing/spending limits prevent allocation, report `not executed due external infrastructure` and do not loop reruns.

---

# Non-goals

Do not implement here:

- profile photo upload;
- map/radius location;
- search redesign;
- skill-selector redesign;
- Scambio card/detail polish;
- Proposal text-search backend;
- demo seed integration;
- new bottom-nav destination;
- DB changes.

---

# Acceptance criteria

- [ ] based on PR #84;
- [ ] prompt archived unchanged;
- [ ] bottom nav is Profile | Home | Browse;
- [ ] Resource discovery belongs to Browse;
- [ ] Home remains actual Home after Scambio;
- [ ] Home destination resets nested Home route to `/`;
- [ ] signed-out Profile is public;
- [ ] fac-simile clearly labelled and static;
- [ ] signed-out bell does not directly open OTP;
- [ ] explicit bell Sign in preserves Notifications returnTo;
- [ ] drill-down navigation preserves Back history;
- [ ] Profile/Browse root Back returns Home;
- [ ] Home root Back may exit normally;
- [ ] `/resources` selects Browse;
- [ ] Messages/Notifications remain Home-owned;
- [ ] Auth guards remain correct;
- [ ] router/widget tests pass;
- [ ] physical Android QA performed;
- [ ] no DB change;
- [ ] no PR merged.

# Completion report

Return:

1. stack/base status;
2. QA-01 branch/base/PR;
3. changed files;
4. AppBranch/order change;
5. route ownership change;
6. Scambio branch fix;
7. Home reset behavior;
8. signed-out Profile;
9. fac-simile design;
10. signed-out Notifications behavior;
11. explicit Auth returnTo;
12. drill-down navigation audit;
13. root Back behavior;
14. direct-link branch behavior;
15. Auth regression;
16. router/profile/notification tests;
17. Android manual QA;
18. local validation;
19. hosted Validation;
20. warnings/blockers;
21. commit/PR reference.

Do not merge any PR.
