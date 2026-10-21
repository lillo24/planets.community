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
- Native/build source: `71f3b8dc866a49e079b56e321ca3bb83d1d298bb`, incorporating
  main `0d8348357c111e7933e6006e860e6236dd98a47d`, including Scambio categories,
  combined participation totals and compact calendars. Subsequent report-only
  commits may reuse evidence only after comparing the runtime objects.

Actual cumulative CI conclusions belong to the [PR checks](https://github.com/lillo24/planets.community/pull/278/checks).
The [release native gate](https://github.com/lillo24/planets.community/actions/runs/39655688024)
retains its own source SHA, result, unique PNG names/hashes and network metadata.
Neither a workflow link nor a prior passing stage implies a successful result.
The final task delivery report records the actual conclusions and inspected PNGs.

## Executed evidence and boundaries

- Corrected broker/target unit suite: **12 passed** at the native/build source.
- Integrated mock/startup/router/calendar suite: **267 passed**; analysis clean.
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

Full Validation run `39651912223` passed Mobile (3,902 tests, two skips), Web
and Site, but failed Database's exact notification projector count assertion
(`2/1/0`, expected `1/1/0`). The removed disposable stack cannot explain that
historical discrepancy. No production SQL repair or relaxed assertion was
invented. The verifier now retains bounded receipt identifiers/types on a
recurrence. Its exact original assertion remains part of cumulative validation.

## Hosted public mock

Current observations and fingerprints are in [mock-hosted-status.json](mock-hosted-status.json).
The dedicated project is `pnolarmzxmmjtguligfc`; normal staging
`cllpvruvrrvxczjitlqd` was inspected read-only and not migrated or reseeded.

The hosted mock has 123 canonical migrations, five ordinary fictional accounts,
five profiles and 55 preserved fixture receipts. The real session-pooler seed
and read-only verifier passed **42 checks** at `4f9bc326`,
[run 39651945003](https://github.com/lillo24/planets.community/actions/runs/39651945003).
The unchanged broker runtime is deployed as version 3. Actual public requests
passed **92 access/Auth/RPC/Storage/recovery/isolation checks**; Giulia and Sara
exchanged two persisted Project chat messages through canonical RPCs (**11 checks**).
Both server and database issuance shutdown were exercised; mock refresh was
revoked, the world preserved, and public issuance re-enabled after verification.
Existing bearer tokens retain up to one hour of lifetime after shutdown.

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

An ordinary upload-key-signed AAB was built from `71f3b8dc`: **0.1.9+13**,
`community.planets.app`, target SDK 36, non-debuggable. Play Console's all-bundle
history showed 12 as the highest uploaded version code when checked; this does
not reserve 13 against later uploads.

Bundletool validation passed. All 440 payload entries match the existing upload
certificate. Scanning all 443 entries found no privileged credentials or embedded
session JWTs; actual normal/mock endpoints are present and CI loopback endpoints
and the integration target are absent. Config/artifact/certificate hashes are
recorded in the hosted status and external task evidence. The feature is an
explicit closed-test capability; ordinary/production defaults remain off.

No Play upload/publication occurred. Normal staging was freshly observed with
97 migrations and a 26-migration source gap; the exact list/timestamp is in the
status file. Hosted native/external real-account OTP and physical-device QA
remain separate release limitations. A valid signed build does not resolve them.
