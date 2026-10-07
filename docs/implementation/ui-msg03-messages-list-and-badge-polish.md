# UI-MSG03 Messages list and badge polish

Implemented from `PLANETS_UI-MSG03_messages_list_and_badge_polish.md` in the
isolated `codex/ui-msg03-messages-polish` worktree. Initial base:
`9cd024cc38c02b0333a32f8abe71fdc9681df548`. Reconciled PR #157's Explore
spacing through main `7054abc2af46770b33b39719588ab337e343bc7d`. PR #156 then
merged while the initial PR CI ran. Integrated its main merge
`37fa469ded1415d66058b144fe1ff4d4ed269d5f` normally, preserving startup/Auth,
the ready-identity Messages root, protected descendants and navigation behavior.
Only the appended EN/IT localization keys conflicted; both sets are retained.
Its branch/worktree is not copied or modified.

PR #158 subsequently merged during CI. Integrated main
`2164a2df5505cd687df1ccad567b04d8b31dc017` without conflicts, preserving its
draft-exit routing, actor-owned collections and stable loading behavior.
Against this main, the shell change remains only the selected Messages badge
variant; its router and Drafts feature code are unchanged.

## Presentation

All conversation rows use shared identity/preview content and a right-hand
column with time above incoming unread human-message count. Private pairs and
Resources use counterparty names/photos; groups retain their Project/Tavolo
title without person avatars. Role/kind/read-only/pending chips, permanent
Project/listing context and Updated prefixes are removed from these rows.
Routes and detail context remain canonical. Incoming counterparty previews
omit the repeated name; historical third-party replies retain their actual
author, and outgoing previews use localized You/Tu.

Local calendar-day timestamps are `HH:mm` today, abbreviated localized weekday
for earlier days less than seven calendar days old, and compact localized date
including year otherwise. EN/IT tests cover the boundaries. Text can ellipsize
at constrained widths while accessibility retains its full content.

Private/Groups display canonical complete scope unread-conversation totals
inside their labels on the right. Zero is absent; unavailable/stale state is
explicit. The bottom Messages badge remains the complete canonical total and
uses inverse theme colors when selected, in light/dark and unavailable states.
Browse remains unbadged. Row counts remain incoming human-message counts.
No client arithmetic, acknowledgement or alert behavior changes.

Read-only pair detail retains the canonical absent composer and a quiet bottom
explanation that a new pending request makes messaging available again.
Group/Resource detail explanations are unchanged.

## Photo stability

Ordinary Messages refresh forces canonical photo-metadata revalidation. The
visible-photo controller previously replaced a ready entry with an empty
loading entry, causing a placeholder flash even when its immutable version
was unchanged. Single/batch loading entries now retain the same viewer's
authorized bytes during revalidation/download. Unchanged versions reuse the
same bytes; successful replacements switch bytes. Canonical absence,
metadata/download failure, explicit invalidation and viewer changes clear;
revision guards discard late responses. Private bytes remain in memory only.

## Additive backend compatibility

V3 route context selects the newest request by creation time/UUID, while pair
activity includes resolutions of every associated request. An older request
can resolve after a newer request and human message. V3 therefore cannot
identify the correct latest status from its context fields alone.

Forward migration `20261007085751_messages_list_activity_preview.sql` adds only
`list_own_scoped_conversation_items_v4`, delegating paging, authorization, route
context, bodies and unread to unchanged v3 and adding two nullable fields:

- `latest_request_activity_status`: newest creation/resolution across the pair,
  when newer than its human preview; otherwise null. Strict supported statuses.
- `latest_group_system_event_label`: the newest visible requirement event label,
  when newer than the human preview; otherwise null. It applies the existing
  current/former membership visibility predicate before choosing an event.

Human activity wins exact timestamp ties. Resource fields are null. No table,
send entitlement, message body copy, private recipient data or released v3
shape changes. Apply this migration before releasing the v4 mobile client.
Generated database types are regenerated, not edited by hand.

## Validation

Focused coverage includes row content/placement, scope positioning/zero/stale,
selected light/dark badge contrast, 320px at 2x text, localized times/statuses,
request status independent of route context, group system preview, strict v4
parsing, composer entitlement and account-isolated photo refresh.

`supabase/tests/119_message_list_activity_preview.test.sql` passed 18 assertions
for request/human precedence, exact additive shape, v3 compatibility,
authorization and cursor order. Test 044 additionally checks system-only group
preview using the latest authorized event without pair context.

`PLANETS_DISPOSABLE_QA=1 node scripts/verify-local-message-list-preview-upgrade.mjs`
passed on a separate loopback QA stack: five populated actors, ten scope pages;
v3 function definition, payload fields, order and unread stayed identical across
actual forward migration; v4 was strictly additive. The selected stack used
`MAILPIT_URL=http://127.0.0.1:64524` and temporary project/port isolation; repository
configuration is restored before commit. This resets only designated disposable
local history and performs no hosted migration.

Completed local validation:

- Final `npm run check:mobile` after PR #158 reconciliation at main `2164a2d`:
  localization, format and analysis passed; 1,529 tests passed and two existing
  tests skipped. This includes the final legacy sender-attribution refinement
  and merged startup/navigation/draft regressions. The preceding PR #156
  reconciliation passed 1,510 tests. Focused Messages suite: 58 tests passed
  before reconciliation.
- Final focused photo controller/avatar suite: 17 tests passed.
- `npm run check:db`: both established populated upgrades, fresh migration
  replay, schema lint, advisors, 119 pgTAP files / 3,637 assertions, authenticated
  integration verifiers, combined demo recovery and generated type drift passed.
  Final deterministic test 119 rerun: 18 assertions passed. This ran on main
  `7054abc`; PR #156 changes only mobile code and leaves all DB/Web source intact.
- `npm run check:web`: 40 tooling tests and 283 web tests passed, one existing
  web test skipped; lint, type checking and production build passed.
- `npm run format:check:web` and `git diff --check` passed.

Change-scoped hosted CI is required on the final PR head before merge. Its exact
head, outcomes and merge commit are recorded in the PR completion evidence.

## Native boundary

Widget/controller tests establish the refresh and layout behavior. An Android
debug APK built with `flutter build apk --debug --dart-define-from-file=config/local.json`
against the disposable local configuration. No physical Android/iOS session,
iOS build or native screen-reader inspection is claimed. There is no new
founder/manual-device merge gate for this task and no deployment.
