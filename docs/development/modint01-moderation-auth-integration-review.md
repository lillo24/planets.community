# MODINT01 moderation/Auth integration review

Status: **draft integration; required live QA incomplete; not merged or deployed**. Founder
moderation copy/presentation and unresolved policy review remain mandatory.
No predecessor PR is closed, retargeted, marked ready, or merged by this task.

## Exact inputs and provenance

- Pinned committed main: `188544f1eacd20a710399721fcede17f64d57aa9`.
- Selected cumulative #148 head: `24d8f7fd21eeacb41055a16a2f3198b8148c9580`.
- Merge base: `11155618e0aa7bf0de62ae178f79d4c0c50ac644`.
- Branch: `codex/modint01-moderation-auth-integration`; target: `main`.
- Final tested source: `7b68f95e2b858f139d14356b937b70850058213e`
  (corrected native harness; **all four hosted areas passed**). All four also
  passed on `4195fb811e1212bdade0eafca8594efed0e07ed1`. The first tested head was
  `297610670c19e087f8512e4b8eb9335ac229269f`.
- Draft [PR #154](https://github.com/lillo24/planets.community/pull/154) is open;
  the final documentation/screenshots publication SHA will be recorded separately.
  No predecessor result is claimed as integrated-head evidence.

Main was fetched and pinned once at task start. It had advanced beyond the
prompt's `67133025b4dc8a90a3d303e70d69df6ee6faf84c`: #150 added compact browse
filters/proposal covers, #151 added unavailable-by-default provider-neutral Auth
infrastructure, and #152 added Scambio browse filters/card metadata. All three
committed changes are retained. This is a real two-parent merge, not squashing,
copying patches, or rebuilding the selected stack on an older main.

After pinning and validation, target main advanced through #153 to
`eb70fe249978585f754fa9175d337d7ef8b99e17` (durable participation pair
conversations). That later source is neither imported nor claimed tested here.
Main subsequently advanced to `795c4ef0fa1398357bd19e8d366d2b50f784f964`,
merging #146 after #153. Neither later history is imported into this branch or
claimed validated by its runs. The exclusion below refers to the pinned inputs,
not this later target main. GitHub reports #154 `CONFLICTING` / `DIRTY`, so no
PR-triggered run was created.
One manual full Validation run
[#37488548670](https://github.com/lillo24/planets.community/actions/runs/37488548670)
checks out the task branch at `2976106`, not a synthetic merge with unselected
#153. Its checkout and manual classification (`mobile/web/site/database=true`)
were verified in the job log. Mobile, Web and Site passed; Database failed at
demo discovery as documented below. One new full run
[#37490895594](https://github.com/lillo24/planets.community/actions/runs/37490895594)
validates the demonstrated repair on `4195fb8`; it is not an unexplained rerun
of the failed source. All four jobs passed; its actual checkout at `4195fb8`
and `mobile/web/site/database=true` classification are verified in the retained
job log. Final corrected native harness source `7b68f95` has a separate full run
[#37499110548](https://github.com/lillo24/planets.community/actions/runs/37499110548);
all four jobs passed. Its actual checkout at `7b68f95` and manual classification
(`mobile/web/site/database=true`) are verified in the retained classification log.
No required area skipped. This is branch-source validation, not validation of a
synthetic merge into the later target main.
Reconciliation with later main is a separate required follow-up before readiness;
this task preserves the once-pinned input and keeps the PR draft.

Every adjacent ancestry check below passed. #146 head
`e0d71724537c83b328a85b21437c51a12aac21c1` is not an ancestor of either input.
No Template Workshop history or other unmerged plan is selected.

| Source PR   | Selected head                              | Behavior retained / combined validation owner                                                                                |
| ----------- | ------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------- |
| #148        | `24d8f7fd21eeacb41055a16a2f3198b8148c9580` | Own verified request explanations; retained drafts/notices/back; Mobile and native QA                                        |
| #144        | `291257dda7783347d8867f3fc6c6287a281e8fcd` | Canonical OTP/bootstrap outcomes and account-switch epoch; Auth convergence tests                                            |
| #142        | `420efa00bcd00d0c0f632444946d640a0aab2a88` | Private own consequence history and draft EN/IT copy; Mobile/native review                                                   |
| #139        | `9a9476e3b74d9783ad74d4184baae74367020c62` | Controlled database-race campaigns and honest incident disposition                                                           |
| #136        | `b8ab159b5bcb643b477cdaa60b0484b7ad0d0e8f` | Membership race/end-state diagnostics; database/tooling verification                                                         |
| #133        | `2ae80181ee9ed9cb52012d7b0ad73897330a2c49` | Dependency remediation and admin QA; pinned lockfile, Web suites/browser                                                     |
| #130        | `99e95f90d0105cc3049fa9b76965f328104d8e4b` | Next patch and Cloudflare compatibility assessment; no hosting selection/deployment                                          |
| #126        | `f6ce0f6c4d2f6d4ba673e29bedca9262275ff6b7` | Manual staff consequence controls; Web/backend authorization                                                                 |
| #125        | `c0548a25d39ddc77a92bc02514c83a01f731e9ae` | Global account suspension, private gates, filtered Realtime and Mobile access screen                                         |
| #123        | `010471320779ffb5edaa7546b12cdc8f14809d2d` | Reversible manual consequence domain, hide/restriction boundaries and canonical locks                                        |
| Pinned main | `188544f1eacd20a710399721fcede17f64d57aa9` | PI01–PI05 links, unified People/role offers, recorded actors/demo recovery, account exits/navigation and provider-ready seam |

## Reconciliations and demonstrated integration repairs

Sixteen text conflicts were reconciled without dropping either input's tests.
Settings retains navigation preferences, canonical Sign out and own notices.
The router retains main's empty-native-URI guard and unavailable-link route,
plus global suspension routing and private-shell invalidation on denied access.
Both Flutter driver and integration-test dev dependencies remain. The root
Database command retains main's People/invitation/demo checks and every inherited
moderation/suspension verifier. Generated types are regenerated from the combined
database using main's membership-origin/result-nullability postprocessor.

The clean merge introduced a double command-revision increment in Sign out.
Main's inherited `maps an invalid backend code and signs out explicitly` test
failed with a retained pending OTP. Removing the second increment keeps one
revision owning both invalidation and completion. The focused 77-test Auth/OTP
run passed afterward. Ten new provider-seam tests also exercise stale success,
cancellation, failure and exceptions after A → signed out → A, and following an
overlapping canonical profile bootstrap. All 54 Auth command tests now pass.
Google and Apple remain unavailable; no SDK, credentials or buttons are enabled.

Main's newer participant-link controllers originally listened only to account
identity, so cached sharing secrets survived suspension/status failure. Two new
regressions failed on retained `ParticipantLink` state before repair. Admission,
manager, refresh and asynchronous share/chat/overlay boundaries now also use the
existing canonical `accountAccessIdentityId`. Denial clears private action tuples
and late results; ordinary successful same-account refresh preserves uncertain
receipt recovery. Three controller regressions and two sharing-overlay widget
regressions pass, including no late Clipboard disclosure. Main's restoration
test now enters the actual delayed canonical bootstrap instead of calling the
removed test-only `markCheckingProfile`; its no-auto-admission assertion remains.
The clean merge's duplicate `signOutError` fixture field and unused test import
were removed. Mobile analysis is clean after these reconciliations.

The merged PI01 public preview initially leaked a hidden Project's title and ID
to an anonymous caller. A real-Auth integration regression failed on that exact
result before repair. Forward migration
`20261006121826_participant_invitation_moderation_visibility.sql` adds canonical
public visibility to the existing invitation lifecycle predicate. It does not
rewrite published migration history, alter grants, change accepted relationships
or weaken the expected-account gate. The focused integration verifier passes
after replay. pgTAP also covers both proposal and Tavolo preview boundaries.

## Authorization and serialization audit

The first full Database attempt stopped at lint: main's later 07C4 role-offer
wrapper redeclared the dispatcher `STABLE` after 09C1A had made its matching
branch locking/`VOLATILE`. Forward migration
`20261006125354_notification_matching_moderation_volatility.sql` propagates
volatility through that wrapper without copying/replacing its routing or main's
recorded-actor resolver. A focused structure regression preserves both wrapped
and matching volatility and the existing private grant boundary. Full replay,
lint and behavioral verification must pass after this repair.

The complete replayed inventory contains **210 public signatures**: 187 deny
while suspended, 19 deliberately public/anonymous-data functions, one own-status
exception, and three service/worker-only functions. Compared with the selected
stack's 194, all 16 additions are explicitly reviewed: 15 private signatures
reach canonical account gates; participant preview retains its deliberate public
contract but must hide hidden content. The heuristic signature/call-chain audit
passes; it is not presented as proof of runtime authorization by itself.

`moderation:integration:verify:local` verifies all 15 new private signatures and
six creator/manager acceptance and delegate-invitation compatibility overloads over
real HTTP using session JWTs obtained before suspension. Safe own status retains
only ID/time/reason/status fields. Admin revoke restores access on those same
clients. Fresh participant admission denies restrictions, blocks with a current
Co-creator, and hidden content without creating membership/receipt/joined-event
side effects. Existing membership/chat remains valid under a content hide.
Direct origin stays nullable/truthful; no request or commitment is fabricated.
Expected-identity action replay is read-only during restriction and after leave
and token revocation; it never restores entitlement or capacity.

`moderation:integration:concurrency:verify:local` passes six observed
apply/admission winner orders and two restriction/hide revoke/admission waits.
Each wait is attributed to the exact first backend, not a pending JS promise or
unrelated lock. Suspension's early gate denies while revoke is uncommitted;
explicit post-commit retry succeeds. No artificial lock wait is claimed for
that early denial. Main's capacity/invitation and inherited broader race suites
remain required, independently of these focused combined checks.

## Validation disposition

Runtime: Node 24.21.0, Flutter 3.47.2 / Dart 3.13.2, pinned Supabase CLI
2.118.0-beta.39. No tool/dependency upgrade. Backend project
`planets-community-modint01-qa` is isolated on ports 54610–54619 with inspector
8123; shared main and other draft stacks are not reset or stopped.

| Check                                                               | Current result                                                        |
| ------------------------------------------------------------------- | --------------------------------------------------------------------- |
| Immutable `npm ci`, Flutter package restore and localization        | Passed                                                                |
| Canonical focused Auth/OTP (77 tests)                               | Passed after demonstrated Sign out repair                             |
| Auth command tests including 10 new provider regressions (54 tests) | Passed                                                                |
| Focused combined real-Auth verifier                                 | Passed after demonstrated hidden-preview repair                       |
| Focused combined concurrency verifier / 210-RPC audit               | Passed                                                                |
| Full Mobile format/analyze/tests                                    | Passed; 1,439 tests, two gated local smokes skipped                   |
| Full Web/tooling tests, lint, typecheck, build                      | Passed; 434 Web tests, one gated skip; 53 tooling tests               |
| Site tests/lint/typecheck/build/deployment dry-run                  | Passed; 19 tests; no deployment                                       |
| Complete `npm run check:db`                                         | Passed; 116 pgTAP files / 3,641 assertions, all verifiers, type drift |
| Combined normal-entrypoint Android debug compilation                | Passed; inherited Kotlin/native-access warnings                       |
| Real normal-UI browser moderator safety apply/revoke                | Passed; synthetic screenshot below                                    |
| Final combined emulator smoke / required native screenshots         | Failed/incomplete; partial observations are not a suite pass          |
| Remaining normal-browser admin/ordinary/participant click-through   | Not verified; browser connection times out                            |
| Real authenticated Web HTTP/SSR authorization campaign              | Passed on controlled configured recovery; earlier failures retained   |
| Hosted final-source CI                                              | Passed on `7b68f95`; Mobile/Web/Site/Database all executed            |
| Published-head source equivalence                                   | Docs/screenshots only; exact-head proof in PR evidence comment        |
| Physical Android/iOS, native accessibility, hardware keyboard       | Not run                                                               |

A type-generation attempt overlapped an in-progress reset and correctly failed
because participation RPCs were not present yet. It was rerun successfully after
complete replay, without changing the generator or inventing empty types.
New test authoring also exposed a misspelled safe-failure enum and an incorrect
one-request expectation: replacement bootstraps intentionally inherit idempotent
anchor creation, not a promise of sharing one SDK call. These were corrected in
the new tests only; inherited assertions/timeouts remain unchanged.

The second Database attempt passed replay/lint/advisors but stopped on new
pgTAP fixture authoring: expected `results_eq` queries used `VALUES` rather than
`SELECT` (interpreted as prepared-statement names), then a direct paused-Tavolo
fixture update violated the lifecycle timestamp constraint. The fixture now uses
canonical `pause_recurring_activity`; no constraint or assertion was weakened.
Both new pgTAP files pass their 15 assertions. The complete gate is rerun after
those concrete corrections, with both earlier failure logs retained locally.

The first hosted run passed Mobile/Web/Site and the Database migration, lint,
security, 210-RPC audit, integration/race and real Web OTP/Tavoli steps, then
failed `demo:check:local`: expected demo Proposals were missing from discovery.
Local `check:db` had run demo verification before the moderation campaigns;
hosted CI runs it afterward. The failure was reproduced with non-mutating
`demo:verify:local` on the now-populated backend. Its public Trento discovery
contained 112 records over six canonical pages; only one demo Proposal was on
page one, with the remaining expected demo records on page four. This was the
verifier's first-page assumption, not missing canonical demo data.

`4195fb8` changes only demo read verification and its documentation/tests:
Proposal, Tavolo and Resource discovery traverse their existing canonical
timestamp/ID cursors. Page size, locality filters, cover/ID/history assertions,
seed behavior and non-repairing verification remain unchanged. Errors, malformed
or repeated pages fail explicitly. Eight new pagination/error regressions pass;
all 53 tooling tests pass. Real demo seed/verify/rerun and departed-episode
recovery/idempotency pass after the moderation campaigns without removing any
of their fixtures. The first hosted failure log is retained, not relabelled green.

The real Web OTP/SSR smoke passed. The additional Tavoli Web attempt failed
before assertions while reading the isolated Mailpit service (54614):
`TypeError: fetch failed`, `UND_ERR_SOCKET`, remote side closed. The larger
authenticated hosting campaign passed repeated interleaved moderator/admin
HTML/Flight reads and private cache headers, then stopped fetching the admin
case Flight response. Neither partial attempt is reported as a campaign pass.
Logs are retained; no assertion or timeout was weakened. At the time, host free
memory was below 1 GB, but memory pressure is a hypothesis, not a proven cause.

Real browser UI obtained a fresh synthetic moderator OTP, applied a safety
notice through separate user-reason/private-note fields, then revoked it and
observed persisted removed history and the success status. Moderator suspension
controls were absent. Remaining admin/ordinary/participant browser UI paths are
not yet verified. Subsequent browser operations timed out while recovering the
connection; no unknown action result or inaccessible page is treated as success.

The owned read-only emulator booted but its API 37.1 image forced 4096 MB RAM
despite `-memory 1536`, leaving only 18 MB free on the host. It was stopped before
app launch. The installed emulator 36.6.11 enforces this API-37 minimum according
to the [official release notes](https://developer.android.com/studio/releases/emulator#36.6.11).
At that attempt only API 37.1 was installed, so selecting a smaller phone did
not remove that minimum. Native compilation is not native-flow or screenshot evidence. Shared
devices/services and other tasks' processes are not stopped to create capacity.

After memory recovered, the precompiled smoke launched on API 37.1: normal OTP
converged to ready Home without the old setup error, with EN/IT Home captures.
The new harness then timed out after tapping the already-selected navigation
radio option. Current `RadioGroup` deliberately emits no change for that tap;
the harness now changes to the other choice and back to its saved choice.
Production navigation and the 30-second assertion timeout are unchanged. The
first failure log is retained. Rebuilding under renewed memory pressure required
stopping the owned emulator; compilation succeeded, but that driver's launch
correctly failed with no device. This is not a native-flow pass.

To separate compilation from execution, a task-owned `PLANETS_MODINT01_API35`
small-phone AVD uses the official API 35 Google APIs x86_64 image, revision 9,
extension level 13, with 1536 MB RAM on the same owned port 5560. Only that system
image was added to the SDK; emulator 36.6.11, Flutter, Gradle, dependencies and
the user AVD are unchanged. The completed APK is reused without recompilation.

The API 35 replay passed both real navigation changes and photo-free direct
admission, then failed the new harness's direct membership-table read (`42501`).
That table deliberately grants no ordinary client SELECT. The harness now uses
the existing `list_own_project_memberships` RPC with its exact expected-actor
argument and preserves the same one-membership/null-request-origin assertions.
No table grant, database guard or production API is altered. The driver also
reported a transient missing ADB device during cleanup; a bounded later read
found the owned device connected again. That transport cause is not claimed
resolved. The failed log remains retained. A fresh actor/Project preparation
prevents the prior successful admission from masquerading as a fresh join in
the corrected replay. Its build uses a verified command-local 2 GB Gradle heap
cap; repository/global Gradle settings remain unchanged.

The corrected APK compiled successfully (243.5 seconds). Its next driver failed
before tests began: VM-service `getVersion` reported `Service connection disposed`.
A bounded Android fatal-error log read was empty; that does not prove a cause.
One controlled run using Flutter's documented `--no-dds` development-proxy option
then reported `adb shell am force-stop failed: Process timed out` and was cancelled.
No debug assertion or timeout was changed, no test result was fabricated, and
DDS is not claimed to be the diagnosed cause or a successful workaround.

The unresponsive task-owned headless emulator could not initially be stopped
because the tool policy blocked the stop call. After explicit user authorization,
only its two reverified process IDs were terminated; other devices/tasks were
left alone. When host memory recovered above 5 GB, one fresh owned API 35 launch
used a 2 GB guest. Free host memory again fell below 1 GB before readiness, so
that launch was stopped without running another smoke. No global ADB restart,
user AVD edit, unknown process termination or further retry-until-green occurred.
Final formatting and analysis of both native harnesses pass, and the corrected
APK builds, but the complete native smoke remains **incomplete**.

The controlled Web recovery used the same source/build and disposable fixtures,
after the stuck emulator was stopped and memory recovered. One startup command
omitted the repository CLI directory from PATH and failed before the campaign;
the configured command then **passed the entire real-auth HTTP/SSR campaign**:
OTP/chunked Proxy refresh, interleaved HTML/Flight isolation, private note/evidence
denial, forged moderator/admin-self suspension rejection, stale-role and suspended
staff reauthorization, and independent sign-out. The original Mailpit/Flight
failures remain recorded; no assertion/time limit changed. This is real HTTP/SSR
evidence, not a substitute for normal-browser click-through. A subsequent browser
connection attempt still timed out after memory recovery, without a verifiable
page/action result; memory is not claimed as its proven cause.

Required remaining live QA: finish the OTP/profile/account-exits/notices smoke;
run both restricted request forms with notices/Back/draft retention and revoke/retry;
finish account switching, suspension during access, denied shortcuts/Back/deep
links and post-revoke status refresh; finish invitation membership/chat continuity.
Capture actual combined-source EN/IT suspension, notice-type active/removed and
Project/Resource explanation screenshots. Finish browser admin apply/revoke,
ordinary denial and participant join/token-free confirmation/handoff/hidden preview.
The earlier partial normal OTP/Home, both navigation changes and photo-free
admission observations do not discharge these remaining checks.

![Synthetic moderator safety notice revoked through normal browser UI](screenshots/modint01/browser-moderator-revoked.jpg)

This screenshot contains synthetic user-facing reasons only; no private note
body, bearer token, OTP, session cookie or privileged credential is published.

## Dependency and operational boundaries

Current `npm audit` reports **11 findings: 1 moderate, 9 high, 1 critical**;
`--omit=dev` reports 9 (1 moderate, 7 high, 1 critical). These are current findings,
not a claim that #133's historical count still holds. The critical `proxy-addr`
path is Express → MCP SDK → shadcn tooling; production graph inclusion alone
does not establish that PLANETS exposes that Express server or its trust-proxy
configuration. Repo-wide runtime-source searches find no Express/trust-proxy or
direct `source-map-js` import. `source-map-js` 1.2.1 reaches the graph through
Tailwind/PostCSS, CSS tooling and Next's PostCSS; the advisory concerns parsing
attacker-controlled indexed maps. These paths are build/tooling exposure evidence,
not a proof of unreachability or a security waiver. shadcn remains a declared Web
dependency and its CSS is imported, so it is not reclassified merely to hide audit
counts. All advisories remain open for a separately scoped remediation decision.
No `npm audit fix`, major downgrade, or opportunistic
upgrade is performed. Primary advisories:
[proxy-addr](https://github.com/advisories/GHSA-jqcg-44mw-7w3h),
[braces](https://github.com/advisories/GHSA-vfj7-8cjw-p6xm),
[source-map-js](https://github.com/advisories/GHSA-68fv-2mgg-jv7q).

Historical database/Realtime incidents remain unexplained; fresh green runs do
not retroactively explain them. AUTHQA01's specific OTP/setup/Home race was
fixed, rather than still being an unresolved old symptom. Cloudflare free-tier
CPU suitability and deployment choice remain unproven; the inherited Next/Node
recommendation is not deployment authorization. No provider activation, public
host, signing, app-store or production account operation is performed.

## Founder review still required

The [exact current EN/IT copy extract](modint01-moderation-copy.md) is generated
from the merged source, with no copy rewrite or founder approval inferred.
The synthetic browser screenshot above is actual combined-source evidence.
Required representative native moderation screenshots remain missing; neither
earlier Home captures nor inherited screenshots are relabelled as those results.

| Topic                                           | What this draft delivers                                                                | Founder review / separate decision                         |
| ----------------------------------------------- | --------------------------------------------------------------------------------------- | ---------------------------------------------------------- |
| Own notices, suspension and request explanation | Current copy, verbatim own reasons, active/removed presentation, canonical denial/retry | Review wording and presentation of implemented behavior    |
| Counterparty warnings or moderation badges      | None                                                                                    | Separate disclosure/privacy policy and implementation plan |
| Owner contextual moderation UI                  | Existing staff-only controls; no new counterparty inference                             | Decide any ordinary owner context separately               |
| Notification channels and disclosure            | No moderation event recipient projection or delivery                                    | Separate category/channel/recipient/copy decision          |
| Appeals and escalation                          | No invented appeal route, deadlines or promise                                          | Separate founder policy before implementation              |
| Minimum age / identity                          | No age or identity rule introduced                                                      | Separate policy and any legal review                       |

- Review exact current EN/IT moderation wording and synthetic screenshots
  (combined-head native evidence pending), especially notices, own request
  explanations, suspension and private-history apply/revoke labels.
- Approve reason presentation and distinctions between current/ended consequences
  without inferring staff identity, counterparty restrictions or evidence.
- Separately decide moderation/appeals/escalation, prohibited content, minimum
  age, retention/deletion and response expectations. This PR decides none of them.
- Remaining 09C2B notification UX, provider activation, hosting and the final
  consolidated UI/UX/accessibility/device review remain separate plans.

## Cleanup, publication and resuming live QA

The owned Next server, drivers, emulator and verified idle build daemon are
stopped. `npm run db:stop` reported the exact task project with `backup=true`;
its database/Storage/Edge volumes remain retained, and no task containers run.
Temporary `supabase/config.toml` is restored byte-for-byte to its original backup.
Generated Mobile config, Web env, Android local properties, Supabase CLI/fixture
state and the failed Flutter driver log were moved to the private task backup,
not published or destroyed. The owned AVD registration is backed up there;
its disposable AVD data and official SDK image cache are retained for resumption.
Other checkouts/backends/devices are not reset or stopped. Main is clean at the
observed later head; draft-worktree retention is intentional for review/fix-up.

Private local evidence/fixture backup (contains local-only tokens; do not upload):
`C:/Users/leona/AppData/Local/Temp/planets-modint01-backup-15b02459aa944e078ca7164a00d61a3f`.
The final exact tested/published SHAs and source-tree equivalence are also recorded
in the PR evidence comment, since a commit cannot contain its own resulting SHA.
There is no unrun published-head CI claim and no CI availability waiver.

To resume, use this same isolated branch and backend/project/ports, with enough
host capacity and a working browser-control connection. Recreate temporary
task-scoped configuration from the retained backup; preserve the committed config.
Start only this backend with its retained volumes, restore/register only the owned
AVD, and prepare **fresh** actors/Projects using each `--modint01` preparer.
Recompile each matching driver target/config before reusing an APK. See the
[native harness map](../../apps/mobile/integration_test/README.md) for commands.
Finish the remaining live-QA list above before claiming plan acceptance. Neither
green hosted CI nor founder copy review waives the missing real-flow/screenshots.
Reconciliation with later main also requires explicit follow-up and new combined
validation; no merge/readiness or deployment is authorized here.
