# APPVER01: update support before date-only Projects

The founder requested this separate SCHED01 prerequisite on 21 October 2026,
preferring required updates over hiding Projects. This code prepares the gate;
it does not activate a minimum, distribute a release, retire legacy APIs or
permit date-only records. No real rollout is authorized.

## Implementation and release fit

The mobile feature README maps the domain, platform adapter, controller and
startup gate. Public Supabase Edge metadata comes from one validated operational
environment value. No product schema/migration, service key, tracking or provider
is added. PostgreSQL/RLS remain authoritative; an app-reported version must never
grant data access.

Android uses pinned `in_app_update` 5.0.0 for Google's native Immediate Update
consent/download/install UI; pinned `package_info_plus` 10.2.1 reads native release
metadata. Current Flutter/Dart/Android tooling satisfies their requirements.
Package-info retains its already-resolved 10.2.1 version as a direct dependency;
the native update bridge is the only new runtime package.
Cancellation/unavailability/errors retain a blocking retry/store fallback
for a confirmed obsolete version; unavailable policy transport instead permits
unverified offline entry.
Native success must recheck the installed release. No flexible/custom installer,
signing, application ID, release numbering or distribution automation is changed.
See [Google's flow](https://developer.android.com/guide/playcore/in-app-updates/kotlin-java)
and the [pinned bridge](https://pub.dev/packages/in_app_update/versions/5.0.0).

iOS separately uses “Aggiornamento necessario” / “Update required” and a verified
numeric App Store link. Repository bundle `community.planets.bootstrap.planetsMobile`
has no verified numeric listing ID here: its example floor remains inactive.
Confirm the final bundle/listing before activation; TestFlight is not equivalent
to public App Store availability. No guessed name/bundle search is used.
[Apple's link guidance](https://developer.apple.com/library/archive/qa/qa1633/_index.html).

Checks default off locally and on in staging/production; explicit local/staging
QA bypass is allowed, production bypass is rejected. Unreachable policy transport
permits unverified offline entry without resetting navigation or forms. Malformed
policy and invalid native metadata remain blocking failures with Retry. Unverified
foreground clients recheck every 45 seconds and on resume; confirmed obsolete
versions retain required-update enforcement. No last-allowed disk cache pretends
to authorize an unknown version. Deploy the endpoint before enabled client releases.

## Safest rollout order (owner actions, not executed)

1. Review APPVER01 independently; preserve current exact-time schemas, readers,
   admission and installed releases. The compact SCHED01 calendar is independent.
2. Deploy `client-compatibility` with the explicit inactive `0.0.0`/`0` example
   after confirming release package/bundle IDs. Verify anonymous success,
   no-store and invalid-policy 503 before distributing any enabled-gate client.
3. Use the existing signed Play/App Store release process with a new valid build
   number. Test Immediate Update interruption/resume/cancellation on real Play
   installations, fallback, iOS store return, and endpoint failures. Sideloaded
   debug APKs cannot prove ownership, track eligibility or real update completion.
4. Verify the replacement is reachable for every affected track, region, account
   and supported device before raising a floor. Staged rollout availability is
   insufficient. Confirm the numeric iOS listing separately. Keep floors inactive
   until these checks succeed.
5. For old published Android builds, an authorized owner may use Play Console →
   App bundle explorer → Recovery tools → Prompt users to update. It reaches
   installations without new update code, but is dismissible and reappears after
   cold restart. Google requires a newer compatible version on all affected
   tracks, Play App Signing and AAB publication; review current restrictions and
   targeting. [Google's recovery instructions](https://support.google.com/googleplay/android-developer/answer/13812041?hl=en).
   No Console campaign/Publishing API request is sent here.
6. Raise per-platform minima only after replacement availability and rollback
   review. This enforces update-capable clients; pre-gate binaries do not acquire
   the check remotely. Recovery adoption metrics do not prove all old clients
   upgraded.
7. Then implement/review SCHED01's additive date-only model and explicit backend
   compatibility cutover. Keep date-only create/convert disabled until incapable
   readers cannot receive incompatible rows. Test missing/old capability, every
   legacy public/owner/web/share reader, drafts, memberships and races. Do not
   fake timestamps, omit individual Projects, trust spoofable app headers, or
   treat a dismissed recovery prompt as enforcement. If old clients cannot show
   a useful explicit upgrade refusal, review that bridge/retirement experience
   before activation.

APPVER01 is necessary for future mandatory upgrades but cannot retrofit installed
binaries. While cutover remains open, the safe backend safeguard is the current
prohibition on date-only publication: this batch enables no date-only schema or
write path and silently breaks no existing client contract.

Later SCHED01 must use the approved admission cutoff: midnight after the final
event-local calendar day. Public clock values remain unconfirmed until both exact
endpoints are valid; the cutoff is not an invented event time or completion claim.

## Validation and external QA

Pure Node policy tests and Flutter domain/controller/gateway tests cover numeric
ordering, iOS build reset, exact app/store matching, native cancellation/resume,
offline/malformed policy, duplicate checks and retry, and native success without
a changed binary. EN/IT light/dark 320dp/2x widgets prove blocked Back/store launch
and no domain-app mounting before admission. Bootstrap/config tests preserve the
local workflow and reject production bypass.

Optional capture uses `APPVER_CAPTURE_DIR` and `APPVER_FONT_DIR` (Flutter's
`bin/cache/artifacts/material_fonts`) on the gate widget test. Images show Flutter
fallback/iOS UI, not Google's native UI. Real Play-track and iOS build/runtime
validation remain external QA. No device credential, store upload, floor change,
recovery prompt, hosted deployment or production operation is performed.
