# Workshop demo and cumulative rehearsal (TW05)

TW05 extends DEMO-B on exact SIM02 head
`08b8c4422de92d8a3f0392c920acc0766a02eaca`, branch
`codex/tw05-workshop-demo-and-cumulative-qa`, targeting
`codex/sim02-automatic-editor-suggestions`. The Template stack stays unmerged
for founder review. Main was inspected at
`cbfbf0ae6de9eb73906361c5980b113ec6bc2046`; its PI05 additions were not imported.
This is synthetic local content, with no deployment or production history.

## Inventory and relationships

The original nine Proposal/Tavolo/Scambio scenarios and three personas retain
their titles, media, request/chat history and lifecycle purpose. In particular,
**Concerto acustico nel cortile** ends about two hours ago and remains Just Finished.

| Core Completed source                                           | Creator               | Open needs                               | Cover                     |
| --------------------------------------------------------------- | --------------------- | ---------------------------------------- | ------------------------- |
| Repair Café: una mattina per aggiustare piccoli oggetti         | PLANETS — demo locale | Attrezzi manuali; Tavoli da lavoro       | Existing repair tools     |
| Murale di quartiere: prepariamo e dipingiamo insieme            | Giulia                | Teli di protezione; Pennelli e rulli     | Existing mural            |
| Aiuola condivisa: piantiamo e curiamo uno spazio comune         | PLANETS — demo locale | Attrezzi da aiuola; Annaffiatoi          | Existing planting scene   |
| Concerto acustico di quartiere: suoniamo e prepariamo lo spazio | Sara                  | Sedie pieghevoli; Audio essenziale       | Existing acoustic concert |
| Pulizia del sentiero: raccogliamo e separiamo i rifiuti         | Giulia                | Guanti da lavoro; Sacchi per raccolta    | Honest placeholder        |
| Scambio di libri: portane uno e scopri nuove letture            | PLANETS — demo locale | Tavoli espositivi; Cartelli leggibili    | Existing reading scene    |
| Libreria di comunità: costruiamo un piccolo punto di scambio    | Marco                 | Legno e ferramenta; Utensili manuali     | Existing makers scene     |
| Cena di quartiere: prepariamo e condividiamo una tavolata       | Sara                  | Tavoli pieghevoli; Materiale per servire | Honest placeholder        |

Each has a three-hour duration, a realistic capacity and two existing controlled
skills with Required/Useful importance. Repair also has one **closed** need,
deliberately excluded from reuse. Instructions require future organizers to check
permissions, safety and suitable arrangements; they claim no verified outcome.

Ten additional Giulia-owned sources belong to the same finite registry:
`activeMural`, `activeFlowerbed`, `fullRepair`, `broadRepair`, `unrelated`,
`happening`, `draft`, `cancelled`, `removed`, `transition`. The original upcoming
Repair Café provides the comparable available match. Full is ordinary capacity
1 with the Creator counted. Rovereto supplies truthful broader locality. Same
skill/locality with unrelated title never admits a match. There is no invented
unknown-capacity publication: SIM01's real legacy-state verifier covers that seam.

`removed` has ordinary accepted participation, a private meeting marker, a
workspace link and group-chat message before clock aging. Giulia self-reports;
Sara submits an ordinary report. Reports leave it usable until the synthetic
reviewer explicitly reviews/removes it with a stable request and protected safe
reason. Core eight entries remain available. The source and its genuine saved
Bozza survive; only Giulia can read that baseline, including after removal.
Other users, participants and staff receive denial. Allowed reusable free text
is not automatically anonymized.

Marco owns four stable accepted copies: `removed-copy` (renamed and saved),
`capacity-copy`, `optout-copy`, `version-A-copy`. The bounded transition check
adds `version-B-copy`. They have fresh open need IDs and reset logistics,
timezone, cover and organizer counting; no inherited members, invitations,
delegates, workspace, chat, commitments or contributions. Receipts retain the
original acceptance after owner edits and removal. Copies are recovered by
receipt destination, never by their editable title.

There are 18 new source Proposals, in addition to the original nine scenarios.
The baseline public Workshop includes the eight core sources plus the dedicated
transition source. “Eight templates” is the core inventory, not a database total.

## Target, mutation and recovery boundary

Use an explicitly disposable local Supabase project. Back up config bytes
outside Git, select a unique `project_id` and free API/database/Mailpit/inspector
ports, and set `MAILPIT_URL` to that stack. Commands derive credentials from
project-scoped CLI status and reject non-loopback API/database/Mailpit URLs.
`demo:reset:local` validates the target **before** invoking the destructive reset.
It resets the entire selected disposable database; ordinary seed never resets.

```text
npm ci
npm run db:start
npm run demo:reset:local
npm run demo:verify:local
npm run demo:workshop:check:local
```

`demo:seed:local` is an explicit mutating reconciliation. It creates each source
through DRAFT01's ordinary idempotent creation/recovery API, sets owned immutable
cover paths and needs, publishes through profile/photo/capacity gates, performs
one authorized Upcoming edit and ages only the exact synthetic source. The
original persisted description remains in Bozza. Canonical receipt identities
bind actor + fixed purpose; accepted intents are never reused for a new intent.
No raw media/domain rows are inserted. Only the exact local reviewer gets a
fixture staff role. No public seed endpoint or app-start hook exists.

Completed clocks stay unchanged on seed reruns. Upcoming/Happening and the
original three Proposal examples refresh relative times. Completed starts at
now minus 72 elapsed hours, ends three hours later, comfortably beyond end +24h.
These are UTC instants formatted by the ordinary Europe/Rome UI, including DST.
There is no completion flag or 24-hour sleep.

The original historical concert can temporarily use its known initial fixture
clock only to recover a missing canonical cover from a legacy/interrupted run.
Unchanged historical fixtures never reopen. Upcoming edits on the original
Tavoli compare their separate schedule rows, so unchanged seeds emit no extra
update/audit/outbox events.

The canonical notification worker is scoped to the exact demo Project/listing
inventory by transaction row locks on other outbox rows; its existing
`FOR UPDATE SKIP LOCKED` selection performs the ordinary projection. Other
queues/receipts remain byte-equivalent, and invalid **demo** events still fail.
No worker authorization, event, receipt or production filtering rule changes.

The cumulative producers exposed an independent notification-worker defect:
after `blocking:verify:local`, a global `process_notification_outbox_batch`
can fail with `55000` on `project.join_request_rejected` authored by a delegated
manager. The legacy rejection resolver in
`20260912174300_push_installation_delivery_job_foundation.sql` expects the
Creator as actor, while the blocking concurrency verifier legitimately exercises
delegated rejection. Reproduce on a fresh disposable stack with the current
domain gate through blocking, then invoke the global service worker; event and
actor UUIDs vary by reset. This branch leaves that queue/history intact and
scopes only demo projection through the existing worker's row-lock contract.
It does not claim to fix general delegated-rejection delivery. Resolve that
separate domain seam at the later integration checkpoint with a forward migration.

`demo:verify:local` authenticates already-created identities and reads/asserts
product state. It never creates a profile, updates content, publishes, projects
notifications, sends chat, copies or removes a template. Local OTP/session writes
are authentication state. A shared advisory lock refuses concurrent mutation;
seed and transition commands take the same exclusive lock. The bounded runner
coordinates its entire sequence, including snapshots, under that lock.

`demo:workshop:check:local` never resets. On an initial installation it checks
missing-world failure without repair, seeds the original nine, interrupts after
a real committed copy before acknowledgement, proves failed verification changed
no product table and resumes the original receipt. It then checks seed → verify
→ unchanged seed → verify. The dedicated transition temporarily changes only
that fixture's clock to Upcoming, makes a canonical edit, restores its Completed
clock and verifies stale first-use failure, refresh/reconfirmation, independent
A/B copies and accepted exact replay after removal. This is **test clock
manipulation**, not an app capability or a public revision archive. Another
unchanged seed must retain all those identities and history.

Snapshots hash all 74 current public/private product tables, including full
audit, outbox, notification, baseline, need, receipt, report and removal rows.
Only `starts_at`, `ends_at`, `updated_at` on the finite original/active clock-refresh
Proposal inventory are excluded. Core Completed/transition/copy timestamps and
all other product rows remain included. `auth` session/email state is outside
product snapshots. No capabilities or credentials are persisted in snapshots.

Accepted application destinations are excluded from source title reconciliation,
demo outbox scope and clock exclusions. A Creator can rename their independent
copy to an original demo title without that copy being adopted/retimed as the
source. The bounded check creates one Giulia-owned self-copy with the original
Repair Café title and proves repeat seeding preserves it alongside the original
source. Its full timestamps/history remain part of the product snapshot.

Interactive content edits, cancellation/removal, extra needs or missing baseline
state are explicit drift. Verification names the fixture; seed does not restore
removed templates, undo owner copy edits or erase append-only receipts. A missing
phase can resume safely; an intentional destructive rehearsal requires an
explicit reset of this disposable stack. Unreceipted or duplicate known-source
titles are refused. Stop the isolated stack before restoring original config.

## Personas and native reproduction

Use Giulia (`demo-alice@planets.invalid`) to inspect her Bozza/self-report;
Marco (`demo-bob@planets.invalid`) to inspect accepted independent copies;
Sara (`demo-carla@planets.invalid`) for participation/ordinary reports.
`demo-planets@planets.invalid` owns only three synthetic starter sources and is
displayed as **PLANETS — demo locale**. `demo-reviewer@planets.invalid` is a
synthetic local moderator. Both new avatars are abstract geometric fixtures.
The original personas' roles/media are unchanged.

Enter a persona email in ordinary app sign-in, obtain the latest six-digit code
from the selected local Mailpit UI and paste it without logging/sharing it.
Generate mobile local config and launch with the stack's reachable/reversed API:

```text
npm run mobile:config:local
npm run dev:mobile
```

DEMO-A prefill never submits. Force-killing the app has no guaranteed persistence
for an unsaved form. Workshop is available from the Proposal creation form;
automatic suggestions appear after a usable title near the title field. Copies
also appear in their owner's ordinary draft list.

The opt-in combined native test uses the real router/screens and backend against
this inventory. Prepare temporary defines **outside Git**, add only the selected
ADB reverse rule and use a distinct QA Android application ID on a shared emulator:

```text
node apps/mobile/integration_test/prepare_workshop_demo_smoke.mjs <OS-temp>/tw05-defines.json
flutter test integration_test/workshop_demo_smoke_test.dart -d <emulator> --dart-define-from-file=<OS-temp>/tw05-defines.json
```

Run Flutter from `apps/mobile`. The journey preserves a prior edited create form,
self-reports the dedicated transition template, drops one genuinely committed
application response, recovers that same copy, dismisses matching without saving,
injects one explicit pre-commit save failure, retries before ordinary Full detail,
returns to the same draft and removes the template through authenticated staff
review. The accepted destination remains editable/recoverable. The core eight
are intact; the deliberate transition-template removal breaks baseline verification
until an explicit disposable reset. These two injected transport failures are
distinct from backend evidence. Existing Workshop/SIM02 native smokes and DRAFT01
widget/API tests cover complementary paging/photo/creation-loss/invalid/discard/
partial-image seams; they are not substitutes for physical-device QA.

After native QA delete temporary defines and token-bearing build caches with
`flutter clean`, plus this checkout's specific Gradle execution-history file.
Remove only the task QA package/reverse rule; preserve shared Gradle/emulator
processes and other projects' files. Keep the clean worktree for founder review.

## CI and later main integration

The bounded demo command runs in `check:db` and hosted Database after ordinary
pgTAP/domain verifiers and before generated-type drift. Native/upgrade rehearsal
stays opt-in. TW05 explicitly requests one final all-area hosted Validation;
ordinary path classification is unchanged. Historical predecessor runs do not
count as TW05 evidence.

Later reconciliation must preserve main PI05's photo-free Dario/Elena, four
admission cases, private capability journal, invitation generation/receipt/history
helper and `demo:check:local`. Compose both bounded checks around the one world,
registry, auth/media helpers and coordination lock; avoid duplicate CI seeding or
a second reset. Preserve then-merged native/auth/browser links and moderation
restrictions. PI05 is inspected context, not tested code on this branch.

Founder review still owns realistic content, synthetic PLANETS attribution,
public/private boundaries, preview usefulness and copy/removal behavior.
iOS compilation, physical Android/iOS interactive Back/swipe and accessibility
remain unrun on this Windows emulator environment. Reproduce on supported devices
with IT/EN, large text, keyboard open, long titles/covers, Full/unknown states,
modal focus, screen reader traversal, canceled save and partial-image feedback.

## TW05 validation record

Local results on the isolated `planets-community-tw05` stack (API 54821,
database 54822, Mailpit 54824), based on SIM02
`08b8c4422de92d8a3f0392c920acc0766a02eaca`:

- Complete `npm run check:db`: clean migration replay, lint/security advisors,
  **113 pgTAP files / 3,481 tests**, every configured domain/API verifier and
  generated-type drift passed. SIM01 reported **706 assertions**, TW02 **93**,
  TW03 **132**, DRAFT01 **42**. The new bounded command passed after those producers
  in **74.6 seconds**, including the original-nine upgrade, a genuinely committed
  interrupted application, non-repairing failure, unrelated sentinel, lock
  refusal, full 74-table stable snapshots, stale first-use reconfirmation,
  accepted replay after removal and independent A/B copies. An earlier post-gate
  rehearsal took 32.0 seconds; runtime varies with local load.
  A later clean-reset rehearsal with the Creator's renamed-copy collision
  regression passed in **80.1 seconds**. That copy retains its independent ID,
  private state, fresh needs and full snapshot timestamps across repeated seeds.
- TW01 backfill rehearsal from migration `20261002103310` passed before/after:
  Completed-only eligibility, no fabricated baselines/events and idempotency.
  TW03 populated upgrade from `20261003191351` passed: **72 predecessor product
  tables** remained byte-equivalent and zero historical applications appeared.
  Full migrations were replayed afterward before final demo/native QA.
- Tooling: **28 tests** passed. Mobile standard check: generated localization,
  **440 Dart files** formatted without changes, analysis clean, **1,274 tests**
  passed. The additional native test separately passed analysis and formatting.
- Site/Worker standard gate passed: **34 Site + 19 Worker tests**, lint, types,
  build and Worker deployment dry run. Web lint/types/build passed. All **162 Web
  tests in 35 files** passed with a 30-second local timeout (220.16 seconds);
  the unchanged default 5-second timeout failed on slow route imports in this
  Windows checkout. No test/configuration timeout was changed for that local run.
- Android debug compilation passed (242.6 seconds). The combined real-app/native
  journey passed on `emulator-5554` with the `.tw05qa` package: **one test / 83
  seconds**, plus 64.2 seconds compilation and 8.5 seconds installation. IT/EN
  Workshop screenshots at 1.3 text scale were inspected: long title, cover,
  search and skill controls were readable without visible clipping in the
  captured area. Full was rendered/asserted after scrolling its actual candidate
  into view. Optional app-cache screenshots must be pulled while the test is
  running; the Flutter runner uninstalls the QA package on success.
  Complementary TW04/SIM02 native results and final-head hosted Validation are
  recorded in the draft PR after execution; predecessor runs are not counted as
  this task's checks.
