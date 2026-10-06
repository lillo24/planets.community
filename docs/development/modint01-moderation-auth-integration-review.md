# MODINT01 moderation/Auth integration review

Status: **draft integration in validation; not merged or deployed**. Founder
moderation copy/presentation and unresolved policy review remain mandatory.
No predecessor PR is closed, retargeted, marked ready, or merged by this task.

## Exact inputs and provenance

- Pinned committed main: `188544f1eacd20a710399721fcede17f64d57aa9`.
- Selected cumulative #148 head: `24d8f7fd21eeacb41055a16a2f3198b8148c9580`.
- Merge base: `11155618e0aa7bf0de62ae178f79d4c0c50ac644`.
- Branch: `codex/modint01-moderation-auth-integration`; target: `main`.
- Tested integration SHA / published SHA / draft PR: pending final validation
  and publication. No predecessor result is claimed as integrated-head evidence.

Main was fetched and pinned once at task start. It had advanced beyond the
prompt's `67133025b4dc8a90a3d303e70d69df6ee6faf84c`: #150 added compact browse
filters/proposal covers, #151 added unavailable-by-default provider-neutral Auth
infrastructure, and #152 added Scambio browse filters/card metadata. All three
committed changes are retained. This is a real two-parent merge, not squashing,
copying patches, or rebuilding the selected stack on an older main.

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

`moderation:integration:verify:local` verifies all 15 new private signatures over
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

| Check                                                                   | Current result                                  |
| ----------------------------------------------------------------------- | ----------------------------------------------- |
| Immutable `npm ci`, Flutter package restore and localization            | Passed                                          |
| Canonical focused Auth/OTP (77 tests)                                   | Passed after demonstrated Sign out repair       |
| Auth command tests including 10 new provider regressions (54 tests)     | Passed                                          |
| Focused combined real-Auth verifier                                     | Passed after demonstrated hidden-preview repair |
| Focused combined concurrency verifier / 210-RPC audit                   | Passed                                          |
| Full Mobile, Web/tooling, Site and Database suites                      | In progress / not yet claimed                   |
| Android compilation, final normal-main emulator flows, admin browser QA | Pending                                         |
| Hosted final-source CI / published-head tree equivalence                | Pending                                         |
| Physical Android/iOS, native accessibility, hardware keyboard           | Not run                                         |

A type-generation attempt overlapped an in-progress reset and correctly failed
because participation RPCs were not present yet. It was rerun successfully after
complete replay, without changing the generator or inventing empty types.
New test authoring also exposed a misspelled safe-failure enum and an incorrect
one-request expectation: replacement bootstraps intentionally inherit idempotent
anchor creation, not a promise of sharing one SDK call. These were corrected in
the new tests only; inherited assertions/timeouts remain unchanged.

## Dependency and operational boundaries

Current `npm audit` reports **11 findings: 1 moderate, 9 high, 1 critical**;
`--omit=dev` reports 9 (1 moderate, 7 high, 1 critical). These are current findings,
not a claim that #133's historical count still holds. The critical `proxy-addr`
path is Express → MCP SDK → shadcn tooling; production graph inclusion alone
does not establish that PLANETS exposes that Express server or its trust-proxy
configuration. `source-map-js` also has a new high advisory. Exact path/exposure
review remains in progress. No `npm audit fix`, major downgrade, or opportunistic
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

- Review exact current EN/IT moderation wording and synthetic screenshots
  (combined-head native evidence pending), especially notices, own request
  explanations, suspension and private-history apply/revoke labels.
- Approve reason presentation and distinctions between current/ended consequences
  without inferring staff identity, counterparty restrictions or evidence.
- Separately decide moderation/appeals/escalation, prohibited content, minimum
  age, retention/deletion and response expectations. This PR decides none of them.
- Remaining 09C2B notification UX, provider activation, hosting and the final
  consolidated UI/UX/accessibility/device review remain separate plans.

Cleanup/config restoration and final source/publication evidence will be recorded
before handoff. Draft-worktree retention is intentional for founder review.
