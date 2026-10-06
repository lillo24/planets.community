# MSG02 — Unread badges and activity alerts

## Scope and base

Selected plan: `PLANETS_MSG02_unread_badges_and_chat_alert_separation.md`.
Isolated branch: `codex/msg02-unread-badges`, based on merged MSG01
`eb70fe249978585f754fa9175d337d7ef8b99e17` (PR #153). UX-NAV01 remains
in its existing router owners. This change applies no hosted migration or
deployment and leaves the denied residual MSG01 directory untouched.

## Implemented contract

- Messages/Home count complete authorized conversations with incoming unread
  human messages. Rows count incoming messages; Groups has its complete scope
  count. Zero is hidden, numeric caps retain exact EN/IT accessibility labels,
  and the Browse-labelled slot carries no message badge.
- Pair legacy/new human sources, Project groups (Proposal/Tavolo), and
  request-scoped Resource chats share body-free metadata. Source kind/UUID and
  conversation kind/UUID are independent composite identities. Requests,
  membership/system/coordination events and own sends are excluded.
- One private account topic invalidates canonical totals/lists, with coalescing,
  stale-response rejection and reconnect/foreground recovery. Signals contain
  only the addressed profile identifier. Same-account acknowledgements notify
  other sessions; old-actor callbacks cannot populate the next account.
- Newest feeds issue own server snapshot tokens. Only successfully rendered,
  foreground, unobscured latest content acknowledges them. Lists, previews,
  hidden branches, background, older scroll, group info and failed history loads
  do not. Failed acknowledgements preserve exact retry boundaries; canonical
  refresh follows success/conflict. Older/duplicate tokens cannot regress or
  consume later arrivals. Read-only is independent of read.
- Source locks establish one baseline at cutover without altering original
  messages or inventing notification/read timestamps. Pre-cutover history has
  no incoming receipts. Post-cutover receipts persist before first updated-app
  use. Group first access and access gaps never acquire retrospective receipts;
  eligible unread remains when canonical history still permits it.
- Ordinary Project/Resource message events are intentionally suppressed/receipted
  by the in-app projector. Historical rows remain intact and are excluded before
  inbox paging, bell counts and activity mark-all. Exact own historical APIs
  remain idempotent and never read chat. Request, membership, exchange and
  matching activity remains, as do shared push resolution/jobs/preferences.
  Mobile removes only the obsolete Chat in-app control; hidden push and stored
  legacy flags remain unchanged.

See [ADR 0008](../architecture/decisions/0008-message-unread-and-activity-alerts.md)
for serialization, eligibility and rollout. The per-conversation metadata row
lock is acquired after existing domain locks and held through commit. Readers
never lock/create that row, including an empty chat's zero boundary. Counts
authorize once per conversation and apply the canonical group history cutoff
to indexed metadata without fetching bodies.

## Validation record

Owned disposable stack: `planets-msg02-qa`, API/DB/Mailpit ports
`64421/64422/64424`. Temporary project/port configuration is excluded from the
commit. No founder/shared stack is reset or stopped. Fixtures are synthetic;
credentials, OTPs and message bodies are omitted from evidence logs.

The focused authenticated verifier proves all three kinds, retained legacy
writers, UUID collisions, complete totals beyond page one, preference/projector
independence, first admission/re-entry, read-only/reactivation, own-only RPCs and
direct-grant denial. Two live sessions for the same account receive read hints;
a warm revoked delegate socket receives no later group/pair invalidation.

The commit race holds a canonical Tavolo legacy send open, queues a supported
legacy send through another Proposal witness in the same pair, and fetches and
acknowledges while both messages are absent. Both commits remain unread through
duplicate earlier acknowledgements. The populated upgrade includes all four
sources and mixed historical read/unread alerts. A pre-cutover writer is baseline;
a second writer queued through migration remains unread. Original records and
references are compared before/after; historical exact reads remain independent.

Local validation:

- `check:db` ran through populated predecessor/MSG02 upgrades, fresh replay,
  lint/advisors, all 110 pgTAP files (3,441 assertions), auth/privacy, capacity,
  invitation, notification/push, pair and unread, workspace and group gates.
  It initially stopped on an outdated ordinary-alert assertion. After correcting
  that assertion, the remaining standard gates ran in order; the Resource test
  helper was corrected to parse inbox rows. Every remaining Resource, contribution,
  moderation/blocking, demo and `db:types:check` gate passed. No earlier unchanged
  suite was rerun merely to hide that recovery.
- `check:mobile`: localization, full formatting, static analysis with no issues,
  1,320 passing tests and two existing skips. Nine focused unread tests cover
  strict payloads, stale responses, bursts, account changes during read, hidden
  branch/failed-load/background/obscured/older-scroll guards, exact failure retry,
  zero/capped counts and compact large text.
- `check:web`: tooling, 263 passing web tests and one existing skip, lint,
  typecheck and production build. Generated types also passed a final web
  typecheck. `check:site`: 34 client and 19 waitlist tests, lint/typecheck/build
  and deploy dry run. Web/Dart formatting and complete diff checks passed.
- The metadata-only summary plan used 27 chats and over 5,000 synthetic human
  rows, rolled back after EXPLAIN: about 65 ms locally, with authorization once
  per conversation. This is an observed local measurement, not a service SLA.
- Demo stability was extended to acknowledge a real own snapshot before rerun
  and compare source identities, incoming receipts and read frontiers. Repeated
  seed/verify and explicit episode restoration preserved that state.

Android debug APK built successfully with demo tools disabled against the owned
backend. Task-owned Android 37.1 emulator, port 5562, booted at 720×1280/360 dpi
(320 dp width); signed-out Home/navigation and the email sign-in screen rendered.
The initial larger emulator stalled under memory pressure. The smaller retry
booted, but ADB became unresponsive during synthetic login. Consequently native
badge/row counts, read-through/arrival/older-scroll and account-switch smoke are
**unverified**. The real authenticated API verifier uses two sessions plus all
three kinds, and widget tests cover those visibility/identity contracts. There
is no second physical-device, iOS, launcher badge or provider-delivery claim and
no new founder QA gate. Only task-owned emulator/compiler processes were stopped.

## Compatibility and operations

Apply the forward backend migration before releasing the updated mobile client.
Older clients retain existing request/feed and activity API contracts but gain
no unread badges or read acknowledgements from migration alone. Their newly
incoming unread remains until an updated client acknowledges it. No launcher
badge, externally visible read receipt, new push provider or pair push is added.
Snapshot tokens expire after seven days; reopening a chat fetches a fresh
boundary. Existing stored preference flags are neither repurposed nor reset.

The task workflow requires all published-head CI checks and clean mergeability
before automatic merge; code merge does not authorize external deployment.
