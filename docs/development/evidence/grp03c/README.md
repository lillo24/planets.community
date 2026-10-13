# GRP03C local validation and rendered evidence

These are fictional local fixtures, with genuine local email-OTP subjects,
canonical policy records and tiny uploaded/committed profile photos. No hosted
environment, real organization or physical phone is involved.

## Evidence folders

- `android-normal/`: 15 captures from the successful complete Android journey,
  API 35 read-only AVD on owned emulator 5584, 1080×2400 at density 420
  (about 411dp), system font scale 1.0. Includes contextual creation, deliberate
  template choice, retained template/scratch drafts, an accepted creation reply
  deliberately lost then recovered, EN/IT public attribution and group feed,
  separate Project request and approved Project member.
- `android-320-text2/`: all 15 captures from the successful complete rerun at
  320×960, density 160 and system font scale 2.0, EN/IT. The owned read-only AVD
  used host graphics with Flutter `--enable-software-rendering --no-enable-impeller`
  after the QEMU failures described below. This proves the rendered layout and
  real local journey with that renderer, not production GPU/device behavior.
- `browser/`: eight anonymous browser captures at 390px and 320px. The real local
  Next build reads the same canonical backend. `journey.json` records public
  fixture IDs and assertions. The journey checks feed-to-detail-to-group links,
  ordinary share, signed-out confirmation and return navigation, with no runtime
  errors or horizontal overflow. No capability, session or address bar appears.

The Android scenario checks that opening Create, choosing a group and opening an
empty Tavolo create no empty source. Template and scratch creation retain the
same group and revision; the private template draft never appears in the public
feed. After a separate Project request and canonical organizer approval, the
requester is a Project member and remains without group membership or authority.
Gallery/crop and email-entry UI are not part of this prepared-session journey.

## Local checks completed

| Check                                                        | Result                                                                              |
| ------------------------------------------------------------ | ----------------------------------------------------------------------------------- |
| Clean SQL replay and pgTAP                                   | 139 files, 5,053 assertions passed                                                  |
| GRP03C genuine Auth/PostgREST verifier                       | 88 assertions passed before the two later publication-retry assertions              |
| Populated GRP03C upgrade rehearsal                           | 121 preservation assertions passed, including the final-source rehearsal            |
| Generated API types                                          | Regenerated from this disposable stack; exact committed-source parity               |
| `check:mobile`                                               | 2,694 passed, two existing skips on the final source, including the loading-row fix |
| Final attribution unit/widgets                               | 10 passed, including the strict-payload assertion and late account response         |
| Final `flutter analyze --no-pub`                             | No issues                                                                           |
| Dart formatting                                              | 675 files checked, no changes                                                       |
| Tooling                                                      | 98 passed                                                                           |
| Web suite                                                    | 377 passed, two existing skips; local `--pool=forks`                                |
| Web lint/types/Next production build/static invitation build | Passed; lint rerun clean after the request-generation comment                       |
| Site tests/lint/types/build/deploy dry run                   | Passed; 41 UI plus 19 Worker tests                                                  |
| Anonymous browser journey                                    | Passed at both widths                                                               |
| Normal Android journey                                       | Passed, one complete product scenario                                               |

The final join contribution-flow suite also passed all seven cases, including
two EN/IT delayed-network loading-state regressions at 320dp/2x text.
The complete large-text Android journey passed after the loading-row fix; every
copied large-text PNG was checked to be 320×960, including both joining captures.
The production app entry point was then launched with public-only local settings
on that owned emulator. Dart tooling connected to this worktree, hot reload
succeeded (three libraries), and the runtime-error check returned no errors.

The broad Prettier check reports seven unchanged baseline files:
`scripts/verify-local-proposal-skills.mjs`, the `hero05`, `navperf01` and `tut04`
evidence READMEs, `map-live01-android-activation.md`,
`msgrefresh01-stable-refresh.md` and `navigation-headers.md`. They are outside this
change. Changed text files receive a separate scoped format check.

Earlier runs are not presented as passes: the initial web suite had an unrelated
admin timeout (its seven-test rerun passed); later Windows thread-worker runs
stalled and were interrupted before the complete fork-worker suite passed.
Initial database gate attempts encountered a transient invitation verifier,
the intentionally exact Project-column assertion (updated for the six additive
columns), and a capacity-race loser-code assertion. The invitation rerun and
six capacity diagnostic repetitions passed without weakening those tests. The
new tied-pagination fixture initially used the wrong PostgreSQL array encoding;
it was corrected before its passing Auth/PostgREST rerun.

A later full local gate stopped in SQL test 026 on the existing chat
`created_at >= activated_at` constraint (the two wall-clock values differed by
133ms in the wrong order). Its unchanged isolated rerun passed all 42 assertions;
the complete gate was restarted after the emulator and mobile suite stopped.
This is recorded separately from the earlier complete 5,053-assertion SQL pass.

The first PR Database run caught an ordering interaction: GRP03C's retained
public garden fixtures added legitimate matches to SIM01's exact-corpus test.
The attribution verifier moved after other consumers, immediately before type
generation in CI and `check:db`; no matching assertion or product search rule
changed. Its official catalog fixture now uses a bounded Repair Café query so
the check also remains independent of preceding catalog population.

Android harness attempts initially waited for an offscreen lazy template control
and then expected public-detail navigation where the established editor returns
to My Projects. Both test assumptions were corrected. Two large-text attempts
subsequently lost the emulator: Windows recorded QEMU access violations
`0xc0000005`, including with emulator audio disabled. Those interrupted runs are
not complete journeys or final screenshot evidence.

Switching emulator graphics and using Flutter's software renderer kept the
emulator alive and exposed a real 138px overflow in the existing Project request
loading row. Both EN/IT delayed-network widget regressions reproduced it before
the label received a bounded `Expanded`; all seven contribution-flow tests then
passed. The complete large-text journey then passed with the same assertions.

## Separate rollout and unrun checks

Physical Android `48091FDAS0041A`, TalkBack/Voice, iOS, physical native-link
association, hosted migration/API activation and authenticated hosted browser
confirmation remain unrun. Screenshots do not prove these. Public group
suppression/restore, authorization races, recurring lifecycle and template
independence have automated database/HTTP evidence, not a separate staff browser
or physical-device walkthrough.

Apply the three GRP03C migrations in order only during a separately authorized
rollout, following all predecessors. Verify grants/type parity and public,
Creator, representative, stale draft, suppression/restore and paired-cursor feed
smokes before distributing dependent clients. Code merge performs no deployment,
DNS/native host activation, signing, store upload or provider change.
