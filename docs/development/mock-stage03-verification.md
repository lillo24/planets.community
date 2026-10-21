# MOCK01–MOCK03 cumulative verification record

The founder's open-access correction supersedes human enrollment in the archived
prompts. Guests use the same fixed fictional personas as other test-app users.
No normal login, human roster or shared APK credential is required.

## Sources and evidence ownership

- MOCK01 draft #276: `51974ce38e973655a54a52338fb763482dd09853`.
- MOCK02 draft #277: `6720c6c453c8ee77f502a59e8cb69dc578c7fbff`.
- Cumulative integration: [PR #278](https://github.com/lillo24/planets.community/pull/278).
  Both draft stage heads are ancestors; they are not separate feature merges.
- Public guest/capability correction: `bc87af25d01baab1bfd486047148d679df56b6a6`.
- Integrated app/AAB source: `541be6fb459ffbf658da0822505aa9a705d4dfe1`, incorporating
  main `82ace622331b97ca39dca5876e2dbb12ae92045b`, including profile/person previews,
  avatar variants, My activities, Scambio categories, participation totals and calendars.
  Report-only commits may reuse evidence only after comparing runtime objects.

Actual cumulative CI conclusions belong to the [PR checks](https://github.com/lillo24/planets.community/pull/278/checks).
The native gate linked from those checks retains its own harness source SHA,
result, unique PNG names/hashes and network metadata. A later harness-only repair
does not relabel the earlier app/build source.
Neither a workflow link nor a prior passing stage implies a successful result.
The final task delivery report records the actual conclusions and inspected PNGs.

## Executed evidence and boundaries

- Corrected broker/target unit suite: **12 passed** at `e4627c8f`.
- Mock/startup/router/calendar suite at `71f3b8dc`: **267 passed**; analysis clean.
  These overlap earlier 250/226-test runs and must not be added together.
- Public backend source `bc87af25`: **173 genuine checks**, 11 unit tests;
  [run 39644834402](https://github.com/lillo24/planets.community/actions/runs/39644834402).
- The subsequent native fixture runs at `ce5a519e` and `4f9bc326` each completed
  **174 backend checks**, including privileged Auth-role rejection. Their native
  journeys failed; their backend successes do not convert those runs into passes.
- The native runner uses two independently keyed disposable Supabase stacks,
  standard Auth/OTP, canonical RPC/RLS/Storage and the production coordinator.
  It covers guest entry/cancellation, persona switching, cross-person messages,
  restart, guest No, retained normal-account restoration, explicit logout and
  expired previous normal Auth. The ordinary release candidate uses `lib/main.dart`.
- Component or emulator evidence does not prove hosted native end-to-end,
  physical Android, iOS, TalkBack or actual Play installation. Device
  `48091FDAS0041A` was not used or modified.

Earlier native failures included release-plugin compilation, manifest lint and
text-driver synchronization. Flutter's unregistered automation keyboard sends
client ID -1; release mode ignores it. The current integration fixture registers
the test input driver and asserts field contents before product actions. It
changes no Auth, message-validation or domain gateway behavior and supplies no
physical IME evidence.

Run `39655688024` reached all five personas, persisted cross-person messages,
restart, guest No, normal-account restoration and logout, retaining 34 PNGs. It
failed in the final revocation fixture and is not a native pass. That fixture now
uses real Auth session revocation while preserving its account/profile/policy
records; deleting an account is not session expiry. Bounded bridge-action
diagnostics are retained on failure. App Auth/domain code is unchanged by this
harness repair. The repaired fixture passed at `01975102`,
[run 39659331380](https://github.com/lillo24/planets.community/actions/runs/39659331380):
35 unique PNGs with verified hashes, all five personas, process restart, genuine
session revocation and zero forbidden normal product calls. This earlier pass
does not qualify the later My activities changes. The integrated runtime's
native gate at `1e685d73` also passed 35 PNGs and 174 backend checks,
[run 39666757829](https://github.com/lillo24/planets.community/actions/runs/39666757829).
Main subsequently added PROF01/IMG01; that changed runtime is separately qualified
by [run 39673018086](https://github.com/lillo24/planets.community/actions/runs/39673018086).
Its actual conclusion/artifacts, representative inspected images and runtime
object comparison are recorded in the final task delivery evidence.

Full Validation run `39651912223` passed Mobile (3,902 tests, two skips), Web
and Site, but failed Database's exact notification projector count assertion
(`2/1/0`, expected `1/1/0`). The failure repeated with one event receipt:
two workers processed the same event. The new additive canonical migration
`20261021193500_notification_projection_atomic_claim.sql` claims the unique
consumer receipt before projection, in the same transaction. A conflicting
claim skips projection; a projection exception rolls back the claim and writes.
It preserves the worker OID, signature, grants, resolver and batch bounds.
The exact original concurrency assertion remains. A new real-worker injected
failure test proves zero leaked receipts/notifications and one successful retry.
[Backend run 39663952594](https://github.com/lillo24/planets.community/actions/runs/39663952594)
passed 12 units, 174 two-realm checks and the worker concurrency/rollback/retry
regression. This migration was applied only to the dedicated hosted mock.

Before PROF01/IMG01, [full Validation 39668157016](https://github.com/lillo24/planets.community/actions/runs/39668157016)
passed all four areas at `5f7181a3`: Mobile 3,936 passed/two skips, Web 401
passed/two skips plus 118 tooling tests, Site 41 client and 19 waitlist tests,
and all required Database upgrade/domain/Realtime/type checks. The new profile
integration requires its own final-head run; these counts are historical and
are not relabelled as the later source.

## Hosted public mock

Current observations and fingerprints are in [mock-hosted-status.json](mock-hosted-status.json).
The dedicated project is `pnolarmzxmmjtguligfc`; normal staging
`cllpvruvrrvxczjitlqd` was inspected read-only and not migrated or reseeded.

The hosted mock has 125 canonical migrations, five ordinary fictional accounts,
five profiles and 55 preserved fixture receipts. The real session-pooler verifier
passed **42 checks** at `541be6fb`, without reseeding or upgrading controls,
[run 39672734857](https://github.com/lillo24/planets.community/actions/runs/39672734857).
The preceding seed-and-verify attempt failed during verification with no
actionable Auth code; its result is retained as a failure, not relabelled.
The new verify-only operator avoids redundant seeding/session preparation and
exports bounded Auth failure codes for future diagnosis.
The unchanged broker bundle is deployed and active; its digest is recorded in the status. Actual public requests
passed **92 access/Auth/RPC/Storage/recovery/isolation checks** again after the
125-migration upgrade; Giulia and Sara
exchanged two persisted Project chat messages through canonical RPCs (**11 checks**).
Both server and database issuance shutdown were exercised; mock refresh was
revoked, the world preserved, and public issuance re-enabled after verification.
Existing bearer tokens retain up to one hour of lifetime after shutdown.
An actual private hosted Realtime subscription, broadcast and authorized chat
read passed **10 checks** with one additional persisted fictional message. The
first subscription attempt returned `CHANNEL_ERROR` before sending; a fresh
attempt passed with unchanged backend configuration. This does not qualify
native Realtime: the loopback native fixture showed its unavailable-state banner.
The profile/avatar migration preserved existing photos. The actual versioned
own-photo API and exact legacy metadata/fallback passed **36 hosted checks**;
no avatar backfill or shared-world reset was performed.

This is hosted API/world evidence, not a hosted native-app journey. The
[operations runbook](mock-environment.md) owns provisioning, bounds, maintenance
and shutdown commands. Legacy enrollment controls and obsolete normal-Auth
broker secrets are retired. External email/SMS/provider login and takeover,
push workers and external analytics remain disabled for this mock capability.

Local pooler TCP connections timed out during PostgreSQL SSL negotiation before
authentication. The network-capable CI operator succeeded using a five-minute
CLI login and explicit `SET SESSION ROLE postgres` on every pooled session.
No permanent password was rotated. Its temporary GitHub secret was removed.
Private operator/build inputs are stored outside Git with restricted Windows ACLs.

## Release artifact

An ordinary upload-key-signed AAB was rebuilt from `541be6fb`: **0.1.9+13**,
`community.planets.app`, target SDK 36, non-debuggable. Play Console's all-bundle
history showed 12 as the highest uploaded version code when checked; this does
not reserve 13 against later uploads.

Bundletool validation passed. All 440 payload entries match the existing upload
certificate. Scanning all 443 entries found no privileged credentials or embedded
session JWTs; actual normal/mock endpoints are present and CI loopback endpoints
and the integration target are absent. Config/artifact/certificate hashes are
recorded in the hosted status and external task evidence. The feature is an
explicit closed-test capability; ordinary/production defaults remain off. It uses
the reviewed private staging config, disables external monitoring and demo tools,
and supplies no MAP-LIVE activation flags (the existing map defaults stay off).

No Play upload/publication occurred. Normal staging was freshly observed with
97 migrations and a 28-migration source gap; the exact list/timestamp is in the
status file. Hosted native/external real-account OTP and physical-device QA
remain separate release limitations. A valid signed build does not resolve them.
