# Validation workflow

`external-activities.yml` is a separate daily 04:20 UTC/dispatch Node runner,
skipped unless `ACTIVITIES_IMPORT_ENABLED=true`. No PR/fork trigger receives
its server-only credentials. Target-scoped concurrency and a ten-minute cap
bound the one daily job after activation. The shipped municipal connector is
still blocked on reuse clarification; a variable or secret cannot bypass it.
No schedule is activated by this implementation. See the
[ACTAPI01 setup and disable steps](../../docs/development/actapi01-infrastructure.md).
Validation runs only synthetic tooling/pgTAP and the disposable local HTTP
verifier. Shared workflow/package changes select all four existing areas;
required checks, complete manual validation and main-push behavior are unchanged.

`mock-hosted.yml` is an explicitly selected `qa-mock-hosted` same-repository
label/manual operation for the disabled `planets-mock` environment. It runs the
reviewed seed and read-only verifier with a private five-minute CLI database
login and mock-only server credential, bound to the exact source SHA. It never
receives a management token or normal staging credential. It cannot enroll or
activate; artifacts contain counts/provenance only. Remove the temporary
`PLANETS_MOCK_OPERATOR` secret after each operation. This occasional job is
bounded to ten minutes and does not change required Validation checks/triggers.

`mock-native.yml` is an explicit `qa-mock-native` same-repository label gate
(remove/reapply after executable source changes), or manual dispatch after merge.
It uses the exact PR head, two independently keyed disposable Supabase stacks,
the reviewed broker runtime and a CI-owned Android emulator. A release-mode APK
uses a temporary fixture signing key through the existing signing guard. It is
never upload-ready and neither that key nor the APK is exported. The journey
uses ordinary OTP, three personas, canonical interaction, a forced process
restart and full logout. No test Auth gateway is injected. Narrow loopback
proxies record request families/operations without headers, tokens or payloads.
The job is bounded to 50 minutes, runs only on explicit request and supplements
required Validation without changing required-status/path classification.
Only synthetic PNGs, hashes, safe outcomes and artifact-scan metadata are retained
for seven days. This is local/CI proof, never hosted deployment or Play readiness.
The fixture is Android x64, stops its compiler daemon before the emulator, and
explicitly opts into the native integration plugin excluded by Flutter release
defaults. That Gradle opt-in requires the exact test target and GitHub-owned
Linux environment and never bypasses release-signing checks.

`mock-qualification.yml` is an opt-in isolated-backend gate. Apply
`qa-mock-backend` to a same-repository draft/integration PR (remove/reapply after
source changes) or dispatch manually after merge. It creates two owned disposable
loopback stacks with independent private signing keys, exercises standard Auth,
canonical fixture RPCs/Storage, same-persona sessions and tester offboarding, then
stops only those stacks. CLI status/secrets are captured privately and never
uploaded. It uses no hosted credentials and does not replace required Validation.
The bounded 25-minute job runs only at the requested stack checkpoints; it is
not an ordinary push trigger. Native qualification is reported separately.

`contact-native.yml` is an opt-in Android review, separate from required Validation
checks. Adding `qa-contact-native` to a same-repository PR runs its exact head;
remove/reapply the label after a source change. It does not run on ordinary pushes
or synchronizations. Manual dispatch is available once the workflow is on main.
Its standard GitHub-hosted Linux runner owns a disposable local Supabase stack,
synthetic OTP accounts and one private headless Android emulator. Both APKs are
built before booting the emulator, then both complete screenshot drivers must exit
zero. The 50-minute cap bounds this occasional integration cost. No hosted backend,
signing or store secrets are used. Artifacts retain only fictional UI PNGs, compact
metadata and scrubbed diagnostics for seven days; private defines/APKs/raw logs
are excluded. Checkpoint names must be unique: the collector requires a one-to-one
PNG/name/byte-count match so a repeated name cannot silently overwrite evidence.
Review the artifact head and actual images before claiming native
qualification. The workflow does not replace any existing required check.

The C/D integration runs `contact:discussions:upgrade:verify:local` first after
startup, before the older upgrade gates and ordinary fresh replay. Every older
gate resets its own predecessor; failing the new rehearsal early avoids redundant
replays without removing any check. It validates the two actual independently populated
histories, not a merged timestamp cutoff. Database checkout retains history so
the verifier can read the immutable predecessor inventories. The Database timeout
is now 40 minutes
for those serialized local resets and genuine fixtures; trigger frequency,
classification and required checks are unchanged. See
[combined qualification](../../docs/development/contact-discussion-integration.md).

The revised C lane adds `group:ideas:upgrade:verify:local` before the final fresh
reset and `group:ideas:verify:local` / `group:conversion:verify:local` after the
existing discussion/link checks. The extra populated reset is required because
the approved revision changes old C history and General access while preserving
stored identities. The real-Auth checks cover these new authorization paths and
atomic conversion/opt-in membership. All three also run in `check:db`; they add
no job, provider call or trigger. Shared workflow edits still select all areas.

C01 adds `group:discussions:upgrade:verify:local` before clean replay and
`group:discussions:verify:local` after Group Project verification. The populated
check reuses bounded fictional producers, preserves every original public/private
column and row, and checks repeated additive application. The HTTP check observes
actual Group-lock waits and tests private admission/history/read/report rules.
Both also run in `check:db`. This authorization-sensitive upgrade adds one local
predecessor reset/fixture pass; area classification, required-status aggregation,
the existing area-selection and main-push behavior remain unchanged. The later
C/D integration timeout adjustment is explained above.

`validation.yml` classifies the complete PR diff using
`scripts/classify-validation-paths.mjs` and runs affected Database, Web, Site and
Mobile jobs. Workflow/root-tooling changes select every area. Manual dispatch
selects the complete suite. There is no duplicate main-push validation trigger.

The Database job replays a disposable local stack and runs lint/advisors/pgTAP.

GRP03A adds `group:membership:upgrade:verify:local` before fresh replay and
`group:membership:verify:local` after GRP01. The populated check reuses existing
group/Project verifiers as bounded fixture producers and verifies the blocking
hook survives warmed calls; the HTTP check observes independent lock waits.
Both run in `check:db`. These backend authorization/upgrade checks are required
for group changes; no extra platform jobs or trigger boundaries are introduced.

The Database job also runs
named authenticated verifiers, then checks generated types. TW03 adds explicit
`moderation:verify:local` (including TW02) and `template:apply:verify:local`
steps. TW02's historical run #37188652377 omitted the moderation command;
its 93 API checks were local only. Verify coverage from final-head step logs,
not a passing job name. Trigger boundaries and required-check behavior remain
unchanged. The full manual database command is `npm run check:db`.

GROUPCOVER01 adds the existing `cover:verify:local` command explicitly after
profile verification. It was previously present only in local `check:db`.
The bounded synthetic Auth/Storage fixture now verifies immutable uploads,
current cover replacement/removal, public lifecycle denial and v4/v5 chat-list
projection through real HTTP. This short verifier runs with every Database job
because the projection and Storage authorization share canonical database rules;
it uses small fixed images and cleans up its Storage objects. Trigger boundaries
and required checks stay unchanged; workflow edits select the complete suite.

MSG02 adds `messages:unread:upgrade:verify:local` after the populated pair
upgrade and before fresh replay, plus `messages:unread:verify:local` after
structured Messages. These bounded checks prove baseline preservation,
commit-order/read races, private invalidation and ordinary-alert suppression
while retaining supported push. They run in `check:db` too. Keep them before
the final pair producer/global-worker sequence; consumer fixtures isolate
their own batches by acknowledging pre-existing events. The combined demo
snapshot now includes a genuine own read and all unread metadata.

DRAFT01 adds `draft:editor:verify:local` for authenticated ordinary creation,
private retry/recovery, rollback and TW03 draft reopening after removal. It is
an explicit Database step after the existing TW02/TW03 verifiers; the scoped
classifier and complete manual suite remain unchanged.

GRP03C adds `group:projects:upgrade:verify:local` before the clean reset and
`group:projects:verify:local` after other domain consumers, immediately before
type generation, in both Database CI and `check:db`. It retains public garden
fixtures, which must not alter earlier SIM01 search-corpus assertions.
The upgrade populates predecessor histories and compares their original columns;
the HTTP verifier checks group-attributed first publication and observed lock
waits. Both are also part of `check:db`. Existing area classification, required
checks and main-push behavior remain unchanged; this shared workflow/package
change selects all four areas for its own PR.

SIM01 adds an explicit `proposal:similar:verify:local` Database step after the
Proposal/TW01 verifier. It covers authenticated bounded matching, canonical
capacity/blocking/media seams and rollback-only synthetic query plans. It also
runs in `check:db`. Adding this shared command/workflow selects all four areas
for this PR under the existing classifier; trigger boundaries stay unchanged.

TW-STACK01 runs the explicit `blocking:verify:local` producer prerequisite,
then `notification:global:verify:local` after domain producers to
exercise the unrestricted worker, followed by `demo:stack:check:local` before
generated types. The latter composes PI05 and TW05 under one lock/session pool;
both committed-response-loss proofs survive without seeding the complete world
twice. Standalone demo commands remain available.

Manual dispatch additionally runs `template:stack:upgrades:local`, testing both
populated exact predecessor histories on sequential isolated stacks. Database
checkout fetches full history for those immutable inputs. This adds 229.9 seconds
locally and remains inside the unchanged 25-minute job limit. Ordinary path
classification, required-check behavior and main-push triggers are unchanged.
Native smoke remains opt-in. See the [integration record](../../docs/development/template-stack-integration.md).

The first integrated hosted run exposed the missing blocking prerequisite in
the hosted sequence (the complete local gate already included it): no delegated
rejection events existed for the new unrestricted regression. The workflow now
calls the existing real producer before that check; it does not manufacture
events or weaken the assertion. Its short concurrency check is necessary to
reproduce the TW05 defect on CI.

GRP01 adds a populated upgrade rehearsal before clean replay and a focused
group HTTP verifier after pgTAP. The rehearsal resets only the CI local stack,
seeds existing fictional domains/reports and compares all old rows/columns after
additive application; it is needed to cover the reporting constraint/function
extension. The HTTP check covers concurrent retries, directory privacy and staff
suppression. Both run in full `check:db`; the existing 25-minute budget, path
classification, required-status aggregation and manual complete suite remain.
Changes to shared package/workflow configuration select all four areas for this
PR. No recurring deployment or hosted database job is introduced.

# MAP01 location validation

IMG01 runs the existing `profile:photo:viewer:verify:local` command after pgTAP
in Database CI, matching the full `check:db` gate. It verifies real local
Auth/Storage small/full permissions, Project/Tavolo/Resource context isolation,
Block, immutable replacement/removal and legacy RPC behavior. SQL-only tests
cannot verify Storage HTTP operation scope. This bounded fixture check makes no
external provider requests; trigger classification and required checks stay
unchanged. The shared workflow edit selects every area for its own PR.

C03 adds the room-owned named-link Auth verifier after discussion checks in the
same database job and full `check:db`. It runs against the disposable local stack
with fictional OTP actors and makes no external provider requests. The existing
classification, required-status aggregation and manual complete-suite entry stay
in place; shared package/workflow edits select all affected areas.

Database validation includes the authenticated location receipt/concurrency
verifier after pgTAP. It injects synthetic provider-shaped geocoding data and
makes no Geoapify requests. Tooling/Web validation exercises the same Edge
adapter's pure modules with fake HTTP/Auth/metering dependencies. The workflow
addition preserves required status aggregation and existing path boundaries.
Batch D adds one populated upgrade check before fresh replay and one bounded
real-Auth verifier alongside group membership. The existing path classifier and
required statuses remain unchanged. Requests/chat/unread compatibility and safety
changes share the Database gate; schema changes also regenerate Web contracts.

# RELEASE01 and STAGING-AUTO01 staged delivery

`staging-release.yml` is separate from Validation and stays disabled unless
`STAGING_RELEASE_ENABLED=true`. The existing always-present **Change
classification** job in Validation now blocks unreviewed risky migration PRs
and performs the populated semantic rehearsal for migration/release/baseline,
workflow and dependency changes (and full manual Validation). Unrelated PRs skip
that expensive step without leaving a required status pending. No duplicate PR
rehearsal runs in the release workflow. SQL history edits/deletions fail closed.

After one-time protected recovery/credential/environment setup, main pushes run
exact-source complete Validation, populated rehearsal and serialized staging SQL
only. Routine nullable-column candidates need real catalog/data preservation;
other SQL needs owner proof bound to the pre-merge head/hash/predecessor. The
writer independently rechecks that proof, so merging a failed gate cannot erase
it. Fresh main, history parity, TLS, advisory lock and backend checks remain.

Android/Play jobs require explicit manual `build`/`publish` dispatch, regardless
of `STAGING_AUTO_PUBLISH`. Keep that variable false and the separate publication
reviewer. No live variables, secrets or environment rules change by code merge.
The [runbook](../../docs/development/release01-staging-play.md) owns classification,
one-time activation, real encrypted DB **and Storage-object** recovery, bounded
two-file reconciliation and incident steps. Current external blockers and the
123/126 read-only observation are in the existing release status.
