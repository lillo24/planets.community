# COCREATE-COMM01/FILL01 — communities, meetings and mock data

Status: implementation complete; final integrated qualification in progress,
2026-10-23. New isolated branch
`codex/cocreate-fill01` builds on RUNALL `a0e810d0` and preserves VIS01
`512192ec` through an explicit merge. Latest merged main `d735bb88` is integrated,
preserving ACTAPI01 and merged ACTMET01. Other branches/worktrees are untouched.
Keep [draft PR #297](https://github.com/lillo24/planets.community/pull/297), based
on `codex/cocreate-runall`, unmerged as requested.

## Requested behavior and working contract

- A topic's General chat can publish a meeting request with a date/time and
  meeting occupancy, including creator-only requests. Joining reserves one
  meeting place and enters the same persistent numbered chat atomically.
- Chat membership persists across meetings. Each new meeting starts with its
  creator attending; other members explicitly confirm attendance. Declining a
  meeting frees its place without leaving the chat. Existing chat exit/removal,
  block, moderation, policy, identity and immutable retry controls still apply.
- Meeting time is a UTC instant, entered/displayed in the device's local zone
  with its offset. Changing time requires cancelling and publishing a new
  meeting; old cards retain their original time. No exact address is introduced.
- Meeting capacity remains 2–50 including the creator. Scheduling explicitly
  converts a numbered room to a persistent chat with the existing maximum of
  50 members; meeting places and chat membership counts are distinct. No one
  loses chat access when a meeting fills, passes or is declined.
- General members receive durable in-app filling notifications with the meeting
  time. Respect current membership episode, mute, blocking, account eligibility
  and notification preferences; no author self-notification. Provider delivery
  must use existing controls and cannot claim configured credentials.
- Mock is an independent data realm. Activities and Find People are mutually
  exclusive presentations, with separate synthetic login persona catalogs.
  Mock fixtures exercise the same canonical RPCs as ordinary data.
- Requested mock topics: Videogames → Valorant/Minecraft; Board games → Lupus
  in Fabula/Catan; Concerts → Rock/Techno; Sports → Running; Travel → China;
  Art → Cooking/Sewing 🧵/Drawing. These are test examples, not a production
  taxonomy decision.
- After the flow is complete, add only a Home Crazy Ideas button beside Find
  People. Do not connect Projects or create Crazy Ideas mock data.

## COMM01 and selected dependencies

The user supplied the complete COMM01 prompt in this chat and explicitly combined
it with FILL01. Its required category → topic/local hub → General/numbered rooms
hierarchy, three-person activation and deliberate Join are part of this task.
The later instruction to combine related unfinished work explicitly authorizes
integrating VIS01. Its source is preserved on this branch; #287 and #292 and their
worktrees remain untouched. The focused dependent draft targets
`codex/cocreate-runall`, while the combined source also contains VIS01. Do not
merge it. ACTMET01 subsequently merged into main as `4a568037`; only that merged
source is included. Its activity-only vocabulary, Mock exclusion and denied
analytics/provider gate remain unchanged. The Activities/Sports queue added by
`d735bb88` is a planning document, not another implementation executed here.

### Canonical community contract

- Seven server-curated categories have stable slugs, EN/IT names, icons and
  ordering. Existing topic/hub/room/episode IDs remain intact. Every existing
  topic deliberately defaults to Other; no inferred production taxonomy.
- A new proposal contains bounded name (2–80), broad locality (1–100) and optional
  explanation (0–500). Normalize case and repeated whitespace for identity.
  A private normalized registry and catalog advisory lock coordinate proposals
  and activation, including matching legacy hubs. Pre-existing ambiguous hubs
  are preserved, never destructively merged. An unavailable/suppressed matching
  hub cannot be bypassed by proposing a duplicate.
- Proposer plus two other distinct current eligible interests activates one hub
  and its existing canonical INSERT trigger creates one General. No numbered
  group, membership or chat grant is created by support. Interested rows provide
  persistent actor-private ready-to-join invitations in Your interests.
- Configurable defaults in private.cocreate_settings: activation threshold 3
  (3–10); 3 proposals/rolling day (1–20); 50 current pending interests (1–200);
  pending lifetime 30 days (1–90). Withdraw/cancel only while pending. Expiry,
  suppression, disabled category, unavailable proposer, policy, block and account
  eligibility are checked canonically. Later interest loss never destroys an
  activated hub. Category disability also denies new hub admission via old IDs.
- Public pages contain aggregates, never proposer/supporter identities. Own
  interests bind Auth to the expected actor. No public count grants transcript
  access. Moderation reuses immutable exact report evidence, current staff,
  case scope, version checks, command receipts and identifier-only audit. Staff
  proposal suppression/rejection does not suppress an already activated hub.
- Flat hub readers and the legacy nine-field recruitment projection retain their
  shape. New categorized readers and scheduled card fields are additive. Public
  TypeScript types use the established generator.

Scheduled cards use `get_own_cocreate_recruitment_v2`,
`get_cocreate_recruitment_v2` and `get_cocreate_room_page_v3`. The old installed
readers keep their function identity, grants, episode/history limits, exact ACK
frontier and closed nine-field nested card. For a dated request, that legacy card
is non-actionable (`unavailable`, null counts) rather than allowing an old client
to join without seeing the meeting time. Unscheduled cards are unchanged. New
readers expose the eleven-field card with the time and meeting places; strict
parsers are retained. Existing internal report snapshots preserve the full exact
dated evidence. Apply the backend migration before distributing the new client;
there is no fallback to a dateless admission or Demo data.

### Meeting and notice contract

- Only the current numbered-group creator schedules/reposts/cancels. A General
  member may create a new persistent numbered chat and publish its first meeting
  atomically. Ordinary existing group creation remains available independently.
- One future non-cancelled meeting per chat; 2–50 meeting places include the
  creator. Only the creator is initially attending each new occurrence. Existing
  chat members can confirm attendance without a recruitment card. Nonmembers
  use card Join, which atomically obtains the canonical C03 chat episode and
  meeting place under the same hub lock. Exit/removal ends that episode's RSVP.
- Meeting time is immutable, finite, future and within 366 days on first write.
  Exact accepted retries recover their original receipt, even after time passes.
  Local input and rendered time carry an offset; a daylight-saving gap is rejected.
- Scheduling discloses the persistent chat's existing 50-member maximum;
  meeting limits are independent. Legacy clients cannot subsequently lower that
  ceiling and create a hidden second attendance limit. Existing unscheduled
  rooms retain their configured capacity and behavior.
- Manual refilling keeps the meeting/time and creates another immutable General
  card, retracting the prior card. Existing 3,600-second cooldown applies. Cards
  expire at the earlier of meeting start and the existing seven-day lifetime.
  Full/past/cancelled meetings do not delete or archive the chat. Existing creator
  departure/orphan archival rules remain in force.
- A new scheduled card queues one identifier-only outbox event. The existing
  service-only notification projector expands at most 25 recipient episodes per
  page with a durable cursor and one shared worker budget. It preserves legacy
  atomic receipt claims, resolver, OID and ACL. No unbounded synchronous notice
  fanout or automatic reposting.
- In-app filling notices include the exact meeting instant, topic, group number
  and current meeting occupancy. Only General episodes existing at posting may
  receive them. Revalidate exact active episode, mute, preference, policy, block,
  account, suppression, card and meeting lifecycle at projection and every read.
  No self-notice or notice restored by rejoining a different episode. Existing
  notification inbox/count/read composition stays canonical; actor-only Realtime
  invalidates the bell/inbox without broadcasting dates, counts or room IDs.
- This implements durable in-app notifications using the existing service
  projector. It does not configure Firebase/APNs, external push delivery or a
  hosted worker schedule. Existing provider and approval controls still apply.

### Mock and presentation contract

- Mock stays an independent realm. Settings serialize selections: persist the
  other presentation OFF before enabling Activities or Find people. If storage
  fails, show failure; do not enable both optimistically. Legacy installations
  with both old flags saved retain Find people precedence until a new selection.
- Help's account picker filters the ten broker personas by dataset: existing
  Giulia/Marco/Sara/Dario/Elena for Activities; Luca/Maya/Nora/Teo/Iris for Find
  people. Legacy catalog rows without a dataset mean Activities. Selecting a
  presentation does not silently impersonate another account: choose the desired
  profile through the existing login/departure/session-fencing flow.
- The guarded mock operator creates requested topics through ordinary proposal,
  three-account support, explicit General join, schedule and card-join RPCs. It
  supplies 4/7 Valorant, full Lupus, persistent messages, a newcomer and pending
  interest scenarios. Fixture receipts preserve tester edits across repeat seed.
  Mock controls remain outside canonical normal migrations. No hosted setup was
  run by this task; the owner must approve/apply the schema and mock control/seed
  update before this data exists on the hosted mock.

## Progress and next action

- Crazy Ideas is a disabled, accessible Home button beside Find people in the
  same presentation, with localized coming-later copy. It has no destination,
  Project connection, write action or fixture data. Existing native Home entries
  remain available.

- Inspected local/unpushed state before changes: RUNALL has only its preserved
  untracked `.local/`; VIS01 is clean/pushed; primary main has preserved
  untracked `.vis01/`. Fetched origin safely; main remains `217ce73e`.
- Created managed worktree `cocreate-fill01`, branch `codex/cocreate-fill01`.
  Integrated the existing tested VIS01 source without conflicts.
- Read current architecture, tooling, recruitment, room membership, notification
  composition and mock control code. Existing recruitment has no meeting time
  or durable notification, and mock personas currently serve one shared catalog.
- Implemented additive meeting/attendance/card RPCs, canonical atomic admission,
  bounded in-app notice fanout, categories, normalized proposals/support and scoped
  moderation. UI and mock work is in progress, not yet fully qualified.
- Initial checks: 85 genuine OTP assertions passed; new pgTAP passed 286; populated
  upgrade from selected RUNALL a0e810d0 passed 216 assertions and preserved 187
  original native/co-creation table snapshots plus six critical function
  OID/ACL/result contracts. Exact manifest is retained in task-owned .local.
- Full fresh replay and all 170 pgTAP files passed 8,234 assertions after repairing
  the worker composition and removing a duplicate General insertion (the existing
  hub trigger already creates it). No predecessor assertion was weakened.
- Final additional persistent-chat capacity assertion passes with all 287 scoped
  assertions. Genuine Auth verification now passes 90, including explicit RSVP
  and exact retry from a retained chat member for the next occurrence. Standard
  public type generation completed (112 additive lines). Backend source is
  locally qualified; final aggregate checks and owner CI gates remain pending.
- Mobile initial regression: 298 passed / one new cross-preference fixture lacked
  its second store. Added the missing fake store; that test passes. New flow
  matrix passes 19 tests, including 320dp EN/IT, light/dark, 1x/2x, deliberate Join,
  exact lost-reply retry and account-input clearing. New parser/mode/notice tests
  passed except a widget lazy-scroll issue repaired in the 19-test rerun. A full
  final aggregate, captures, analysis, build and actual mock replay remain pending.
- Next: finish RSVP/manager/mock/admin negative tests and final qualification;
  inspect rendered evidence; commit each qualified stage, then add only the Crazy
  Ideas Home button and complete the final cumulative draft PR/checkpoint.
- No hosted migrations, deployment, provider activation, approval bypass or
  automatic merge is authorized/performed. RUNALL owner migration review remains
  an inherited CI gate, to be refreshed for the exact cumulative head.

## Access, privacy and rollback

| Surface                              | Authority and exposed data                                                                                                                                  |
| ------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Categories/communities/proposals     | Deliberately public bounded summaries only while the server experiment is ON; eligible, unsuppressed entries and aggregate interest counts.                 |
| Propose/support/schedule/admit       | Auth-bound expected actor, current policy/profile/account eligibility, server gate, block/moderation checks and immutable command receipt.                  |
| Your interests/ready invitations     | Actor-private durable rows; supporting never grants a transcript or membership.                                                                             |
| General/numbered chat and attendance | Existing exact room/episode authority; meeting Join uses canonical atomic chat admission and separate place reservation.                                    |
| Filling inbox/read/count             | Current eligible General episode, notice/card/meeting lifecycle, mute and preferences rechecked on every read; no supporter roster or private message text. |
| Proposal moderation                  | Current staff plus exact report case, immutable evidence and current CAS version; no unrelated transcript access.                                           |
| Private tables/functions             | RLS and explicit revocations; API roles cannot write tables directly or invoke internal functions.                                                          |

Actor provenance uses the predecessor's private raw UUID convention, adding no
Auth/Profile deletion-blocking foreign keys. Permanent identity erasure ends the
existing chat episodes, so their attendance stops counting; deleted/banned
supporters stop contributing, and an unavailable proposer cannot activate or
publish pending text. Existing scoped report retention/identity restrictions
remain in force. Expiry is an availability rule, not a new deletion or indefinite
retention promise; production retention policy remains owner work. Free-text
preview warns against phone numbers, exact private addresses and sensitive data.

Rollback is the existing private server switch OFF; the independent device
switch only changes presentation. Neither switch deletes chats, resets history
or enrolls people. Auth-only established exits remain available. Do not roll back
by deleting/recreating existing hubs or editing applied migrations.

## Reproduction and qualified checkpoints

Use an identified disposable loopback Supabase stack with `MAILPIT_URL` pointing
to its own mailbox; never run reset/fixtures against a hosted/shared database.
The backend commands used here were `npm run db:reset`, `npm run db:test`,
`npm run db:lint`, `npm run db:advisors`,
`npm run cocreate:communities:verify:local`,
`npm run cocreate:programme:verify:local`, `npm run db:types` and
`npm run db:types:check`. The populated upgrade uses
`PLANETS_COCREATE_UPGRADE_BASE=a0e810d0678cfd17b0124eb103e68974e932474b`
with `npm run cocreate:upgrade:verify:local`; the script only accepts its two
documented immutable bases and still requires its owned-project guard.

For the recorded Windows owned engine, process-only environment selected
`CONTAINER_CONNECTION=planets-cocreate-qa-root` and
`DOCKER_HOST=npipe:////./pipe/podman-planets-cocreate-qa`.
`PLANETS_DISPOSABLE_QA=1` and
`PLANETS_UPGRADE_QA_PROJECT=planets-cocreate-fill01-qa` explicitly permitted the
upgrade. The journaled task config used project `planets-cocreate-fill01-qa`, API
54821, database 54322 and mailbox 54324. That overlay is now restored; recreating
QA requires a new verified owned setup, not running these resets on the default
project. No private signing/API keys are recorded in source or evidence.

- Final strengthened backend tests: **299 pgTAP** and **104 genuine Auth**
  assertions pass, including normalized concurrent proposals from different
  accounts, withdrawal versus activation, existing-hub reuse, scoped staff CAS,
  and more than one bounded notification-recipient page. Clean aggregate remains
  **170 files / 8,234 assertions** before these twelve additional assertions.
- Populated selected-base upgrade: **216 pass**, 137 immutable migrations,
  **187 table snapshots / six warmed function OID/ACL/result contracts**
  preserved. The integrated predecessor OTP/socket programme passes **139**.
- `node scripts/mock/qualify-local.mjs` with `PLANETS_DISPOSABLE_QA=1` passes
  **382 checks / ten personas / zero normal-realm calls**, real notification
  worker rollback/concurrency, populated mock-control replay and repeat seed.
  Source schema digest: `838382e1803838ee880ea19ea18a3dd5876fcb1a317bac0bbf7cb8a76c4e2478`.
  The script owns two new stacks with unique private signing/API keys and cleans
  up only those stacks. Mock target/broker/people fixture unit tests pass **14**.
- Complete Web: `npm run test --workspace @planets/web -- --pool=forks` passes
  **405 / two existing skips**; lint, typecheck, production build and static
  invitation check pass. Default-thread aggregate was stopped after stalling;
  the fork pool ran identical coverage. Existing build-size/Vite future-config
  warnings are retained. Root `npm run test:tooling` passes **181**.
- Mobile community/meeting/Home renders pass **36 targeted tests** with EN/IT,
  320dp, light/dark and 1x/2x text. Captures under `evidence/cocreate-fill01`
  are actual contract-fixture renders, not live-device screenshots. Italian
  category headings now give large text its own line. Final retry extensions,
  full aggregate/analysis/debug APK and latest-main reconciliation are in progress.
- `adb devices -l` finds no attached device. Physical Android/accessibility and
  iOS qualification are unrun. No emulator belonging to another task was booted.
  QA activation is OFF, the owned project is stopped with backup, root config
  restored byte-for-byte (`2e67b7a5cda9ffc671c31b4461c1c8b896cc75c3bf727f6e406ee573eefbd8f6`),
  both new mock stacks cleaned up, and the owned QA VM stopped. Recovery state
  and private diagnostics remain untracked in `.local`.

### Latest-main reconciliation and final visual repair

`f5a25f25` integrates actual main `d735bb88` on this existing branch. Its only
conflict was adjacent external-detail imports; both the D03 people action and
ACTMET01 sharing controls are retained. No migration, analytics gate, provider
setting or other branch was changed by the reconciliation.

The active-category widget journey checks localized category → Valorant →
General disclosure/admission → independent `2/3` room → deliberate room admission
and chat. Locality remains a filter and no preview reads a transcript. Both EN
and IT journeys pass at 320dp/2x. Its first test expectation incorrectly assumed
legacy direct room Join also navigated; the established separate Open chat step
was restored in the test, preserving product behavior. Large-text capture
inspection then found cramped availability copy; count and label now have full
width with occupancy still aligned right. The final entire Co-Creation suite
passes **139**, including that repair and both new journeys.

Final format covers **947 files / zero changes** and analysis is clean. The
complete serial mobile run is still active on the integrated source, followed
by the debug APK. The small visual repair is independently requalified by all
139 Co-Creation tests after the full run had already passed this area; no test
or assertion is disabled. Twenty-four focused PNGs are retained in
`evidence/cocreate-fill01`; extra predecessor/Demo renders are preserved only in
task-owned `.local` diagnostics.

Mobile commands run from `apps/mobile`:

```text
flutter gen-l10n
dart format --output=none --set-exit-if-changed lib test test_support
flutter analyze --no-pub
flutter test --no-pub --concurrency=1 --reporter expanded
flutter test --no-pub --concurrency=1 --reporter expanded --dart-define=UI_POLISH_CAPTURE_DIR=../../docs/development/evidence/cocreate-fill01 test/features/co_creation
flutter build apk --debug --no-pub
```

The capture invocation actually used the absolute worktree output path with the
same directory. Mock unit command from root:
`node --test scripts/mock/*.test.mjs supabase/functions/mock-personas/*.test.mjs`.
Web/root commands and their qualified results are recorded above. Final GitHub
CI remains dependent on the existing exact-head owner migration review; no
owner approval is posted or fabricated by this task.
