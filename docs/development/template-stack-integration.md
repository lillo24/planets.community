# Template stack integration candidate (TW-STACK01)

This is a draft review candidate, not a main merge or deployment. Founder
review remains unapproved. The eight predecessor PRs and their checkouts remain
intact; the separate open moderation/admin/dependency stacks were not imported.

## Immutable inputs and integration owners

| Input                                                                                                                                                                                                                                                                                                                                                  | Verified commit                            |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------ |
| Main with merged PI01–PI05 ([#128](https://github.com/lillo24/planets.community/pull/128), [#131](https://github.com/lillo24/planets.community/pull/131), [#134](https://github.com/lillo24/planets.community/pull/134), [#138](https://github.com/lillo24/planets.community/pull/138), [#141](https://github.com/lillo24/planets.community/pull/141)) | `cbfbf0ae6de9eb73906361c5980b113ec6bc2046` |
| Cumulative TW05 [#145](https://github.com/lillo24/planets.community/pull/145)                                                                                                                                                                                                                                                                          | `63bfb83120af76af404055a9999d3298181f3c34` |
| Common ancestor                                                                                                                                                                                                                                                                                                                                        | `92d93ca5a455ab853df8bc34b66fd8d69f4fb341` |

The input comparison has six main-side and eleven Template-side commits. The
candidate starts from main and merges the exact cumulative Template head with
both parents; individual plans are not cherry-picked. Included Template PRs:
[TW01 #127](https://github.com/lillo24/planets.community/pull/127),
[TW02 #129](https://github.com/lillo24/planets.community/pull/129),
[TW03 #132](https://github.com/lillo24/planets.community/pull/132),
[DRAFT01 #135](https://github.com/lillo24/planets.community/pull/135),
[TW04 #137](https://github.com/lillo24/planets.community/pull/137),
[SIM01 #140](https://github.com/lillo24/planets.community/pull/140),
[SIM02 #143](https://github.com/lillo24/planets.community/pull/143), and TW05 #145.
Exact final head and hosted run belong in the integration PR, avoiding a
self-referential commit ID in this source record.

`app_router.dart` retains main's native wrapper and integrates the one existing
`DraftDepartureCoordinator`. Ordinary editor departures keep their guard;
startup without an editor keeps synchronous Auth restoration. External URI
validation/deduplication runs before editor preparation; allowed committed
callbacks compose feedback and external-auth cancellation. Blocked navigation,
competing replay and actor changes cannot deliver a false success. The tests
exercise go/replace/pushReplacement/pop, internal push, dirty incoming links,
failed save/Keep editing/retry, delayed competing navigation and actor switch,
alongside existing duplicate OTP/profile, invalid-link and modal-owner tests.

Both manifest histories survive (`flutter_driver` and `integration_test`);
lockfiles were regenerated with standard tooling. Public types were generated
from the combined database through main's canonical generator and participation
nullability correction. Public Proposal screens and EN/IT catalogs retain both
branches' behavior. No domain migration was rewritten, renamed or duplicated.

## Canonical contracts and upgrade proofs

The combined history retains publication identity, Completed at end +24 hours,
public eligibility, source structural locks, Creator-private Bozza, manual
report/staff removal, independent atomic copies and private exact retries.
Matching stays title/controlled-skill/rough-geography based with five narrow
previews; suggestions push ordinary detail after modal closure, without joining.
Direct invitations retain canonical capacity/blocking, immutable origins and
episodes, retained superseded requests/offers/chat, photo-free basic-profile
admission and separate ordinary photo gates. A new eight-assertion pgTAP test
copies a source with a real direct participant and current/revoked generations:
the new private draft inherits no links, origins, participants, requests or
admission receipts, and receives one accepted Template provenance receipt.

`npm run template:stack:upgrades:local` archives the exact two input commits,
starts sequential disposable projects on ports 55020–55029 (inspector 8113),
seeds each real predecessor, hashes every public/private base-table original
column and row, then applies missing interleaved migrations with pinned
Supabase CLI 2.118.0-beta.39 `migration up --local --include-all` twice. There is
no reset after the populated checkpoint and no history-row repair.

| Direction                                            | Preservation result                                                                                                                                                           |
| ---------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Populated main → integrated                          | All 72 original tables/columns/rows unchanged; once-published sources gain identities exactly once; no fabricated baselines, applications, removal actions or editor receipts |
| Populated TW05 → integrated                          | All 74 original tables/columns/rows unchanged; existing ordinary origins remain ordinary; no fabricated invitation generations/secrets/admissions                             |
| Explicit combined seed after each preservation check | Both worlds converge, verify and preserve all 77 current product tables on unchanged rerun                                                                                    |

Added nullable columns project to null on old rows: three Template-target case
columns in `private.moderation_cases`; invitation origin in
`public.project_memberships`; resolution reason and superseding membership in
`public.project_join_requests`. Snapshots compare old content fully rather than
claiming byte equivalence across changed schemas. Both populated directions,
including explicit seed/rerun, passed in **229.9 seconds** locally. Temporary
projects use short owned names to avoid CLI container-name truncation; cleanup
asserts no owned container remains and removes the dependency junction itself
before deleting its verified temporary directory. The manual hosted Database
gate runs this additional rehearsal; ordinary scoped validation is unchanged.

## Notification and combined demo seams

Main's existing delegated-actor migration resolves TW05's isolated-base `55000`
notification failure. After the real blocking/domain producers, the unrestricted
authorized worker projects **two delegated rejection events**, records canonical
manager attribution and remains idempotent on repeated drain. No offending event
is deleted, no receipt is fabricated and no non-demo row lock masks the worker.
The retained nine-assertion pgTAP regression covers both kinds, acceptance/removal,
push/in-app, revoked-delegate attribution, forged-actor denial and grants.

`demo:stack:check:local` runs invitation and Workshop phases under one lock and
session pool. Both genuinely committed response-loss checkpoints fail read-only
verification without repair and recover the original action/receipt. The full
combined seed is not repeated needlessly. Standalone `demo:check:local` and
`demo:workshop:check:local` remain usable. The finite scoped demo worker inventory
contains both extensions and preserves unrelated queues; it is separate from
the unrestricted regression above.

Inventory is seven synthetic personas, the original nine scenarios, PI05's four
activities and TW05's eighteen Proposal sources (eight core Completed entries
plus ten support sources). Dario/Elena remain photo-free; only the synthetic
reviewer has fixture staff authority. Dynamic snapshots currently cover all 77
public/private product tables. Exact relative-time original/PI05/active Workshop
fixtures alone exclude starts/ends/updated clocks; accepted destinations and
Completed source/copy history remain fully compared. One explicit legacy seed
seam creates the original concert's missing invitation before restoring its
Just Finished clock. Unchanged historical reruns never rewind it.

## Local integrated validation

Commands ran on the owned `planets-community-tw-stack01` stack: API 54921,
database 54922, Mailpit 54924, inspector 8112. Synthetic loopback identities only.
Node 24.13.0, Flutter 3.47.2 / Dart 3.13.2; no dependency timeout changes.

- Complete `npm run check:db` passed clean replay, lint/security advisors,
  **116 pgTAP files / 3,562 assertions**, all configured authenticated verifiers,
  unrestricted worker, both combined demo interruption/transition/stability
  phases and generated-type drift. SIM01/TW02/TW03/DRAFT01 reported
  **706/93/132/42** assertions. The copy-origin regression passed all **8**
  assertions both separately and in that full clean replay. The final combined
  demo gate took **22.7 seconds** (Workshop phase 14.6 seconds); earlier loaded
  and fresh rehearsals took 51.0 and 18.6 seconds respectively.
- Tooling: **34 tests** passed. Full mobile standard check: l10n, formatting,
  analysis clean, **1,348 passed / 2 skipped**. The new opt-in integration test
  is formatted/analyzed separately and does not add an ordinary-CI emulator job.
- Web: lint/types/build and **283 passed / 1 skipped** across 46 files,
  **132.40 seconds**, with the unchanged default timeout. Local production Next
  build/session OTP and public Tavoli lifecycle/location-privacy verifiers passed.
- Site/Worker: lint/types/build, **34 + 19 tests**, and deployment dry run passed.
- Android Workshop smoke passed against integrated sources/backend: compilation
  **157.4 seconds**, install **2.853 seconds**, real journey **67 seconds**.
  It preserves the prior form, recovers a committed copy, matches/fully closes
  suggestions, handles injected pre-commit save failure, enters ordinary Full
  detail, returns to the same draft and performs real self-report/staff removal.
  Response loss and save failure are explicit test transport injections, distinct
  from real canonical copy/read/save/report/removal evidence.
- `stack_invitation_smoke_test.dart` passed on a fresh combined world in
  **32 seconds** (25.7-second compile / 1.064-second install). Real normal
  Supabase initialization, OTP and automatic profile setup passed, including
  preserved entered values on duplicate platform links. Both photo-free direct
  admissions opened real entitled chat screens; Full and blocked admission
  failed canonically. Dirty incoming departure, explicit pre-commit save failure,
  Keep editing/retry, invalid-host safe route and same-draft return passed.
  The receiver is exercised through injected Flutter platform messages; this
  does not establish Android HTTPS association. Private reads use canonical
  gateways, retaining raw-table denial. Pending ordinary-request provenance and
  leave/removal/replay continuity are covered by the real API/demo gates.
- Complementary fresh narrow fixtures also passed: SIM02 in **44 seconds**
  (24.8-second compile / 0.780-second install), including ordinary photo gate,
  Full/cancelled after lookup and committed creation recovery; TW04 in
  **22 seconds** (25.1-second compile / 0.634-second install), including 51 need
  descriptions, self-report, lost-copy recovery and removed-source reopening.
  Neither test changed matching order or deleted populated-world candidates.
- The available Codex in-app browser rehearsal used the production Next build
  and PI05 loopback ingress on 3174–3176. Real OTP, initially missing basic
  profile, photo-free profile save, explicit Proposal and Tavolo Join, refreshed
  token-free confirmations and ordinary detail were exercised. Before Join:
  zero photos/memberships/receipts. Confirmation handoff is a normal Project ID;
  ordinary detail retains the usual request/photo/organizer-approval explanation.
  This is local HTTP/browser evidence, not Chrome or public OS association.
  After explicit manager revocation, refreshed confirmation still showed current
  participation; both canonical memberships/receipts remained, with zero photos.
  A fresh revoked preview showed Invitation unavailable and no admission action.

Final exact-head all-area hosted results and additional native rehearsal details
are recorded in the draft PR after execution. Historical TW05/PI05 results stay
attributable to their original commits and are not counted as integrated passes.

## Reproduction, cleanup and review gates

Preserve config and Gradle bytes outside Git; use a distinct `.twstack01qa`
Android application ID and only the owned API/Mailpit reverse rules. Native
defines/capabilities remain in OS temporary files or ignored local journals,
never in command output or Git. Stop the owned stack before restoring its
configuration. Remove token-bearing build artifacts with `flutter clean` and
this checkout's specific Gradle execution-history file; uninstall only the QA
package, preserve other packages/reverse rules/shared Gradle processes, and stop
only a task-created emulator. Retain the clean integration checkout for review.

Founder review remains open for historical public/reusable content, private
Bozza, self-report/staff-only removal, independent copy/retry, wording/presentation,
Full/unknown and lexical/locality limits, dismiss/reopen, save/discard/partial-image
navigation and synthetic PLANETS attribution. iOS compilation, physical-device
Back/swipe, TalkBack/VoiceOver/hardware keyboard and real public-host/signed-device
association remain separate gates. No hosting, signing, provider billing, shared
database migration, main/predecessor merge or store deployment is authorized here.
