# Automatic editor suggestions (SIM02)

Implemented for draft founder review on exact SIM01 head
`8effe582704324e2da159392629db95be08a66f3`. Branch
`codex/sim02-automatic-editor-suggestions` targets
`codex/sim01-similar-active-proposal-matching`. The predecessor stack remains
unmerged; this feature has no database migration or deployment.

## Responsibility and request boundary

The unpublished one-time Proposal editor observes its raw title, selected
controlled skill **IDs**, rough country/locality and controller-bound draft ID.
Blank create routes, reopened owned drafts and independent template copies share
this behavior. Published editing keeps its existing manual-save behavior.

- `domain/similar_proposal.dart` owns effective query identity and the narrow
  public preview DTO, separate from full Proposal/count/participation objects.
- `data/similar_proposal_gateway.dart` owns the authenticated bounded RPC and
  strict parsing of all 16 SIM01 response fields, nullable cover and known enums.
  Malformed payloads and RPC/network errors become explicit failures, never `[]`.
- `application/similar_proposal_controller.dart` owns the 350 ms debounce,
  request/input generations, session-local dismissal and actor/readiness checks.
- `presentation/similar_proposal_suggestions.dart` owns the quiet IT/EN entry
  and user-opened settled preview sheet. `proposal_editor_screen.dart` observes
  form/lifecycle state and hands a selected opaque ID to ordinary navigation.

Only SIM01's seven arguments leave the form: current expected actor, raw title
(at most 100 PostgreSQL characters, including whitespace), deduplicated sorted
skill IDs (maximum 50 before deduplication), valid two-letter country, rough
locality (at most 120 raw characters), current bound exclusion ID and limit 5.
Invalid/blank optional geography is omitted without changing the form. An
overlong title is skipped without truncation; required skill-bound failures
remain explicit. The first acknowledged save changes exclusion from null to the
canonical bound draft, including on the original create route. Template/source
IDs never substitute for that destination.

Description, summary, exact meeting text, coordinates, dates, covers and resource
needs never enter matching. Query/form content is held only in session memory;
it does not enter URLs, persistent stores, analytics or diagnostic messages.
Skill importance and unrelated edits do not change query identity.

The [SIM01 contract](similar-active-proposals.md) remains authoritative for
lexical admission and ordering. Title overlap is required; shared tags and
rough locality refine ranking. There is no stemming, translation, synonym/AI
matching or percentage confidence. Flutter preserves the returned order and
never constructs invented headcounts or participation relationships.

## Activity, dismissal and presentation

State is keyed by actor plus the editor's independent UUID. Effective input
changes hide old results immediately; late responses cannot update a new idea,
account or editor. Identical active queries do not repeat on rebuild. Auth or
readiness loss clears state and invalidates selections; releasing/remounting a
form starts a fresh epoch even before provider auto-disposal completes.

Offstage tabs, another route, app backgrounding, saving/publication and departure
pause scheduled requests and reject in-flight responses. Actual inactivity
invalidates preview selections. A visible suggestion sheet retains its settled
preview without polling. Closing it, returning from detail or explicitly
reopening/retrying performs one debounced lookup from current form state.
Backgrounding invalidates and closes an open sheet; resuming refreshes.

Dismissal pauses matching until **Show suggestions** is chosen. It survives
input changes, a first-save binding and same-session route return, and remains
isolated from other editors/accounts. Opening/closing the sheet alone never
saves a draft or shows saved feedback.

Current matches render a compact inline **A similar activity may already
exist** entry near the title. Loading is quiet text; failure has a localized
Retry action; settled empty results leave no panel. Results never open a modal
automatically, announce repeated live-region changes, block saving/publication
or alter the idea. The sheet scrolls within a safe-area bounded height and shows
at most five public previews, named-zone schedule, rough location and optional
canonical authorized cover/placeholder. Full and unknown registration capacity
are truthful labels. Narrow reasons describe title/shared tags or same locality.
There is no join action, total-match claim or pagination.

## Modal handoff and draft recovery

The sheet returns only the selected ID. The editor awaits the actual modal
route's [`completed` future](https://api.flutter.dev/flutter/widgets/TransitionRoute/completed.html)
(overlay removed), then the restored frame, and checks
mounted/foreground state, actor/input generation, selection membership and the
real `DraftDepartureCoordinator.activeOwner`. Only then does it push ordinary
`/proposals/<id>` once. Rapid candidate taps coalesce into one choice.

There is no manual call to prepare followed by guarded navigation. The existing
[DRAFT01 coordinator](proposal-draft-departure.md) owns persistence and feedback:
dirty valid content saves before detail; acknowledged/unchanged content produces
no false newly-saved toast; invalid input or save failure retains the form and
keep-editing/retry/discard choices; partial images retain the same draft and
image-warning outcome. Lost acknowledgements reconcile the existing creation
intent. Binding during an already accepted departure does not cancel that push
or cause another save. Competing navigation uses the existing coordinator.

Back restores the same session, raw form and bound draft. Ordinary detail
reloads current visibility/capacity and existing participation state. A stale
preview can become Full/unavailable; it grants no join, manager or protected
location authority. Existing member/pending/creator/block/profile/photo rules
remain owned by their established detail/participation modules.

## Validation and review

Focused tests cover exact payloads and parsing, debounce and response races,
actor/session/readiness/disposal, dismissal and first-save exclusion, route/
background suspension, real modal-owner restoration, save/Back/retry/discard/
partial feedback, double taps/competing transitions and independent template
copies. Existing DRAFT01, Workshop and ordinary participation tests remain in
the full mobile suite. The opt-in Android smoke and reproducible fixture steps
are in [integration-test navigation](../../apps/mobile/integration_test/README.md).

Local validation on 5 October 2026 used Flutter 3.47.2/Dart 3.13.2, Node 24.13.0
and the repository-pinned Supabase CLI 2.118.0-beta.39:

| Check                                                                                                                                  | Observed result                                                                                                                               |
| -------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| `npm run check:mobile`                                                                                                                 | Passed generated localizations, formatting of 440 Dart files, static analysis with no issues, and all 1,274 mobile tests (53 new SIM02 tests) |
| `dart format --output=none --set-exit-if-changed apps/mobile/integration_test`                                                         | Passed both native smoke sources                                                                                                              |
| `node --check apps/mobile/integration_test/prepare_similar_proposal_smoke.mjs` and scoped Prettier                                     | Passed fixture syntax and new/edited feature documents; unrelated roadmap formatting retained                                                 |
| `npm run proposal:similar:verify:local`                                                                                                | Passed 650 authenticated matching assertions, including scale/query-plan checks                                                               |
| `npm run moderation:verify:local`                                                                                                      | Passed reporting/staff review and 93 TW02 assertions                                                                                          |
| `npm run template:apply:verify:local`                                                                                                  | Passed 132 TW03 assertions                                                                                                                    |
| `npm run draft:editor:verify:local`                                                                                                    | Passed 42 DRAFT01 assertions                                                                                                                  |
| `flutter build apk --debug`                                                                                                            | Passed Android debug compilation; final native smoke also compiled the current sources                                                        |
| `flutter test integration_test/similar_proposal_smoke_test.dart -d emulator-5554 --dart-define-from-file=<OS-temp>/sim02-defines.json` | Passed the complete real-RPC native journey, including tab suspension, current capacity/visibility and retry request-UUID reuse               |

The local stack was `planets-community-sim02`, API/DB/Mailpit ports
54701/54702/54704. It was stopped with its explicit project ID and `--no-backup`;
task containers/data volumes are absent. Exact original Supabase/Gradle bytes
were restored. The `.sim02qa` package is confirmed absent (explicit uninstall
found it already absent); only TCP 54701's reverse rule was removed. Temporary
session defines, local status-key logs and native build caches were deleted.
The clean isolated checkout is retained for draft review; predecessor checkouts
and other emulator reverse rules were preserved.

The final diff affects mobile and documentation only. Hosted final-head results
belong in the draft PR's validation record; the existing classifier selects
Mobile and skips Database/Web/Site. No CI trigger or backend contract changed.
The exact supplied prompt is archived in
`history-implementations/PLANETS_SIM02_automatic_editor_suggestions.md` with
SHA-256 `919DDB6840CBFAFA08541FFE52C61EE1263DACCC396ABF06AC4C45631D44BC95`.

Founder review covers IT/EN wording and placement, preview usefulness,
Full/unknown labels, dismissal/reopening, modal choice, save/discard/partial
feedback and preservation on return. Android emulator smoke does not establish
iOS compilation, physical-device swipe/interactive Back or native accessibility;
those remain explicit device QA. The later integration checkpoint must preserve
main's #128/#131/#134/#138 participant-link/auth/browser/native work and any then-
merged moderation visibility changes. TW05's eight-template demo/cumulative
integration remains deferred.
