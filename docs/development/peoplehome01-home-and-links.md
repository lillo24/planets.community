# PEOPLEHOME01 — Home intentions and General link review

This mobile-only change started from Co-Creation integration PR #297,
`7faba51c7b35e1fc3f287e9ebb54e101d3e60adf`, and was reconciled to
`816bd3f22f61268bf514a37d60ae81c2821e9ab5` before final CI. The intervening
integration commits change only documentation; runtime source and SQL are identical.
Its dependent PR targets
`codex/cocreate-fill01` and stays unmerged for owner review. It adds no migration,
activation, release, legal bundle version, provider dependency or account sanction.
The predecessor's exact-source SQL review and release protections remain separate.

## Home

Settings → Sandbox → Co-Creation Mode still defaults OFF. When ON, Home contains
exactly three cards in order: Find your people, Find activities, Propose an idea.
Only Find your people opens the existing `/people` entry and its first-entry
planetary introduction. The other cards visibly say Coming soon / In arrivo,
expose disabled button semantics, and have no tap handler, Auth handoff or product
call. They replace Crazy Ideas and the separate Projects/Scambio-Dona cards in
this presentation. Existing native routes, baseline/Activities Split Home,
tutorial override, saved settings, mode precedence and Mock realm selection keep
their existing contracts. The obsolete Crazy Ideas strings remain available.
At 1.5x text and above in a viewport narrower than 400dp, only these experimental
cards move their icon/chevron above the copy to retain readable line widths.

## Local link warning

`domain/general_message_links.dart` owns a pure educational heuristic for ordinary
human drafts in Co-Creation topic-community **General** only. It recognizes HTTP,
HTTPS, www, and bare ASCII/punycode hosts using two-letter country suffixes or a
small explicit set of common generic suffixes. Prose/Markdown, case and Unicode
whitespace/punctuation are supported; standalone emails, times and decimal
numbers are excluded. It is deliberately not a complete URL/TLD validator or spam
classifier. Existing composer/server limits bound drafts to 2,000 characters;
host labels have bounded lengths. There is no URL fetch, AI classification,
link-analysis log, telemetry, stored detection result, auto-report or sanction.

`co_creation_general_screen.dart` shows a scrollable IT/EN dialog on explicit new
link sends. Edit, Back and barrier dismissal leave the draft unsent and editable.
Send anyway permits only the exact reviewed draft under the same actor, hub,
room, episode and current live eligibility. Draft changes (even changed back),
scope updates, identity/readiness/policy changes, disconnects, backgrounding,
failed authority reads and observed closure revoke confirmation. Unchanged
successful polling does not revoke it; an authority read still pending at Continue
requires another explicit review. Server authorization remains authoritative.

`people_widgets.dart` offers an optional `PeopleCommand.beforeSend` only before
acquiring a new immutable attempt. After the await it rechecks actor, command
slot/RPC/intent and attempt-store identity. Duplicate actions cannot allocate two
commands. An uncertain delivery or acknowledged completion Retry skips the review
and recovers the original frozen UUID/text or receipt. It never automatically
resends. Existing command callers without this optional review retain their path.

Numbered crew chats, registered Groups' discussions, Projects, Tavoli, Resources,
private chats, recruitment cards, notifications and imported content receive no
new warning. The per-message Report action and `spam` category still use the
existing source-bound manual moderation case. A relevant link is permitted.

## Policy boundary

The warning explains relevant sharing, the prohibition of spam/repeated unrelated
promotion, reporting and human review. It claims no implemented account ban.
Existing Community Rule C1 already covers spam; Terms A8 describes enforcement
tools that remain incomplete. Their content and acceptance versions are unchanged.

**Proposed for 09C, not implemented or activated:** indefinite account suspension
after a manual finding of harmful off-topic spam. This still requires owner review
of proportionality, staff permissions/reasons, notice/appeal and corresponding
Terms/Rules before it can be promised or enforced. PEOPLEHOME01 neither resolves
that policy nor manipulates Auth bans or silent restrictions.

## Reproduction and review

From `apps/mobile`:

```text
flutter pub get
flutter gen-l10n
dart format --output=none --set-exit-if-changed lib test test_support
flutter analyze
flutter test
flutter build apk --debug
```

Focused regressions live in `test/features/co_creation/`: detector table tests,
General warning/Cancel/Continue/Back/stale-context/retry/report tests, the revised
Home matrix and actual Home → first-intro → browse/replay test. Standard app,
router, tutorial, Mock-mode and native feature tests exercise retained boundaries.

For optional synthetic renders, run the two focused widget files with
`--dart-define=UI_POLISH_CAPTURE_DIR=../../build/peoplehome01/renders` and
`--plain-name="Co-Creation Home"` or `--plain-name="link warning"`, respectively.
The tests cover EN/IT, light/dark, 320dp, 1x/2x Home text and 2x dialog text.
These are Flutter fixture renders, not physical Android/iOS or owner approval.
Physical phone/TalkBack/VoiceOver and iOS QA remain a separate manual check.

Local qualification on 2026-10-23:

- `flutter gen-l10n`, full Dart formatting check (950 files), and `flutter analyze` passed.
- `flutter test --no-pub test/features/co_creation test/app test/features/settings test/features/mock_mode test/features/moderation test/l10n --reporter expanded`: **575 passed** on the final implementation. This is the affected regression set, not a claim of the entire mobile suite.
- The focused detector/send set passed **56 tests**, including ordinary no-link sends, numbered links, draft/account/policy/scope invalidation, duplicate actions, uncertain delivery, acknowledged completion and genuine Spam reporting.
- `flutter build apk --debug` passed. Existing plugin Kotlin migration warnings remain informational; no dependency versions changed.
- The Home (8 cases) and dialog (4 cases, start/end scroll) matrices passed. Representative EN light / IT dark fixture PNGs are in [the evidence folder](evidence/peoplehome01/), including 1x/2x Home and the warning's beginning/end. Native device and screen-reader approval is not inferred from these renders.
- Documentation formatting and `git diff --check` passed. Database, Web and Site were not run locally because their code/contracts are unchanged. The dependent PR's standard Validation remains the CI record.

Owner review must assess the three intentions, disabled affordances and IT/EN
warning copy. The predecessor's SQL approval is still required before integration
can merge. No deployment, hosted write, legal activation or store submission was
performed.
