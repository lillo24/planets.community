# MSG01 — Participation pair conversations

Implemented on 6 October 2026. The starting checkout was
`67133025b4dc8a90a3d303e70d69df6ee6faf84c`; latest-main integration included
`188544f1eacd20a710399721fcede17f64d57aa9`, including UX-NAV01 and the subsequent
browse/auth changes. [ADR 0007](../architecture/decisions/0007-participation-pair-conversations.md)
records the accepted responsibility and privacy boundaries.

## Behavior and compatibility

One immutable unordered requester/Project Creator pair owns the conversation.
Canonical request episodes associate atomically and remain distinct structured
messages at their original creation positions. The server groups conversations
before pagination and supplies canonical pending totals, bounded pending pages,
complete mixed-feed cursors, and exact request-context lookup. New human messages
have no invented request foreign key. Resource and group chats remain separate.

The forward migration projects retained legacy source records without copies,
rewrites, deletion, or reassigned authors. Its deterministic anchor uses the
earliest request and original chat ID. Missing legacy anchors fail the migration
explicitly. Ordinary delegates lose personal history, previews, sends, and
Realtime access through both new and retained APIs; scoped request notes,
offers, management actions, and explicit staff evidence authority remain usable.
Already-connected legacy delegate sockets receive no post-upgrade personal hints.

Existing request URLs resolve endpoint viewers to the pair with the referenced
request in context. Authorized non-endpoint managers reach request details.
Retained RPCs expose only endpoint-authorized original request-scoped history;
old clients need an upgrade to read new pair messages and the full conversation.

## Automated evidence

- `npm run check:db`: passed on the task-owned disposable `planets-msg01-qa`
  stack (API 64321, database 64322, mailbox 64324), with
  `PLANETS_DISPOSABLE_QA=1`. The populated predecessor upgrade preserves six
  pending/resolved/repeated/directly-superseded episodes, original records and
  references, actual legacy delegate authors, and cached-socket privacy.
  All 109 pgTAP files / 3,414 assertions passed. Real authenticated integration
  operations cover concurrent/opposite-direction pairs, endpoint/delegate
  access, send/resolution/block/invitation races, tied source kinds, 97-item
  paging, 35 pending requests, old-context targeting, and live refresh.
- `npm run demo:check:local`: passed inside the full database suite, including
  committed interruption recovery, unchanged reseeding, retained PI05 history,
  and canonical identity stability. A separate clean reset, seed, and
  non-repairing verification prepared the native presentation dataset.
- `npm run check:web`: passed (30 tooling tests, 263 web tests; one expected
  PI03 smoke skip), including lint, type checking, and production build.
  A build using the owned backend's generated local configuration then passed
  `auth:web:verify:local` and `tavoli:web:verify:local`.
- `npm run check:mobile`: passed after latest-main integration (1,311 tests,
  two expected skips, no analyzer issues). Focused coverage includes precise
  acceptance triage, one/many/zero banners, delegate URL fallback, account
  switches, read-only reactivation, 65-message reconnect/conflict catch-up,
  outlines/alignment, small-screen large-text layout, IT/EN plurals, and strict
  Realtime transport parsing. Web/mobile formatting and database type drift
  checks passed. The final SQL rollback fixture independently passed 28 checks.

The native run exposed the pinned Dart Realtime binary envelope's transport
`meta` field. Parsing now validates its delivery ID/optional replay flag alongside
the identifier-only application payload; personal fields remain rejected.
Temporary diagnostics were removed before rebuilding and final validation.

## Actual native observations

Used a newly created task-owned Android 37.1 emulator at 360 × 780 logical pixels,
the normal debug app entry point with demo tools disabled, the clean owned
backend, and normal email-code sign-in as Giulia. Switched to Italian through
Settings. Marco's mural and monthly makers Tavolo were seeded through canonical
RPCs, preserving the established resolved invitation history.

Giulia saw one Marco Private row and two pending requests. Accept on the exact
Tavolo opened the shared contribution-triage sheet; completing it reduced the
banner to one. Rejecting the remaining mural request removed the banner and
composer and showed read-only history. A second authenticated Marco API client
then created a fresh legitimate mural request: the still-open native conversation
reactivated without manual refresh, kept its pair ID/history, and restored the
composer. A message from that second client also appeared live. The fresh request
and second-client send used canonical API operations, not a second native device.

Screenshots: [one pair](evidence/msg01/01-one-private-pair.png),
[two pending](evidence/msg01/02-two-pending.png),
[shared triage](evidence/msg01/03-shared-acceptance-triage.png),
[one pending](evidence/msg01/04-one-pending.png),
[read-only](evidence/msg01/05-read-only.png),
[live reactivation](evidence/msg01/06-live-reactivated.png), and
[structured request bubble](evidence/msg01/07-structured-request-bubble.png).

No physical-device/iOS, provider/signing/store, public-host, production/shared
migration, or release-prerequisite claim follows from this emulator smoke.
The separately isolated PI03 production HTTP smoke was not run. CI and merge
evidence are recorded on the linked MSG01 PR. The task-owned QA services and
emulator were stopped after the native smoke; the isolated worktree/branch are
removed after verified merge. Other retained stacks remain untouched.

MSG02 unread badges and removal of ordinary chat-message alerts from Notifications
remain unimplemented by this task.
