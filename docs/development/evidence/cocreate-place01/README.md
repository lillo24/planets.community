# PLACE01 qualification

Scope: [implementation plan](../../../../history-implementations/PLANETS_COCREATE_PLACE01_reusable_places_groups_meetings.md)
and [canonical contract / reproduction](../../cocreate-place01.md). All people,
communities, fields and provider data here are fictional fixtures in an owned
disposable local backend. No hosted data or phone installation was changed.

## Source-backed regressions

- [SQL projection/command tests](../../../../supabase/tests/165_cocreate_places.test.sql):
  61 assertions cover server-issued selections, exact deduplication versus nearby
  points, private addresses, usual/occurrence independence, two groups sharing a
  venue, manager/CAS/actor/episode authority, immutable retries, full chat and
  membership-limit eligibility, bounded keysets, no ACK, cancellation, retraction,
  past meetings, archival, suppression and disabled-provider scheduling.
- [Real Auth/HTTP](../../../../scripts/lib/cocreate-places-verifier.mjs):
  135 assertions through real OTP/Auth, client/service REST, SDK-authenticated
  function transport and the actual location handler/normalizer. Seven synthetic
  provider responses, zero live requests. Resolve/reuse add zero requests; disabled,
  forged and stale scopes never reach the provider. A real last-seat race admits
  one participant. Place/group/meeting receipt retry, private-address exclusion,
  separate usual/occurrence Places, cancellation and no transcript ACK are checked.
- [Mobile tests](../../../../apps/mobile/test/features/co_creation/co_creation_places_test.dart):
  32 tests cover locationless Valorant-style communities, two-group Place detail,
  mixed full/available and already-attending/neutral states, ordinary usual and
  different occurrence Places, discovery control, existing-UUID reuse, real
  semantics activation, disabled search, expired-selection review, exact manager
  and pre-command General search scopes, old/new frozen command recovery, and
  late actor/policy/realm/background responses. EN/IT, 320/360dp, 2× text and
  light/dark layouts are exercised.
- [Location adapter tests](../../../../scripts/lib/location-search.test.mjs)
  add exact co-creation purpose/episode checks while preserving zero-traffic
  disabled behavior and the existing provider/normalization/meter tests.

## Validation actually run

- Clean canonical migrations and seed replay with RADAR01 main `04c63e5f`: passed.
- Affected location/provider/numbered/recruitment/meeting/calendar/RADAR/Place SQL:
  **9 files / 826 assertions**, including 61 Place assertions.
- Real authenticated HTTP: **112 COMM01 + 98 CAL01 + 135 PLACE01 assertions**;
  no live provider.
- Co-Creation/router/location/native and external geographic discovery:
  **847 Flutter tests passed**. The 32 Place tests also passed with actual render capture.
- Root tooling: **356 passed**. Mobile analysis: no issues. Changed-file formatting,
  Dart formatting, whitespace, SQL lint/security advisors, regenerated database types
  and web typecheck passed. The full web formatting command also reports six untouched
  baseline files; checking their `0ea1df30` contents reproduces every warning.
- [Populated upgrade](populated-upgrade.json): **202 installed tables, 567 public
  functions and eight warmed readers** preserved, including old calendar cursor,
  OIDs/ACLs/signatures/defaults/results, closed nine/eleven-field cards and FIX01
  six-field review. Old schedule/Join exact receipts and null-Place behavior remain
  valid. Only the existing service reservation body intentionally expands its
  scope; its installed OID/ACL/signature stay intact. All rehearsal changes roll back.

Required GitHub checks and their exact source commit are reported with the PR.
The release-guard unit test uses an isolated reviewed fixture, with positive and
actual altered-byte/version/unapproved-Mock negative cases. It no longer assumes
that every source implementation is already deployed/approved. The real release
policy file and validator remain unchanged.

## Actual Flutter renders

These are synthetic Flutter widget renders, not live backend/device screenshots.
The group examples isolate the actual group-control components; other frames use
the actual Place/editor/meeting screens. All seven were visually inspected:

- [Usual group Place and different meeting Place](group-usual-meeting.png).
- [Occurrence review](meeting-place.png).
- [Locationless group](locationless-group.png).
- [Two groups with available/full sessions](place-detail-mixed.png).
- [Explicit manager publication toggle](usual-discovery-toggle.png).
- [Italian dark 320dp/2× detail](place-it-dark-2x.png), with scrolling below the viewport.
- [Italian dark 320dp/2× manager controls](usual-it-dark-2x.png), scrolled to the toggle.

Reproduce from `apps/mobile`:

```text
flutter test --no-pub --concurrency=2 --dart-define=UI_POLISH_CAPTURE_DIR=../../build/place01/renders test/features/co_creation/co_creation_places_test.dart
```

Physical Android/iOS and TalkBack/VoiceOver were not run. Real venue quality and
live provider traffic were not tested.

## Delivery boundaries

[Recorded Edge source approval](edge-source-approval.json) identifies the changed
`location-search/handler.mjs` as outside the recorded release approval. This is a
local comparison, not a remote deployment inventory. The existing reviewed
deployment/source-approval workflow remains necessary before using that new
search scope in a released app; the task performs no Edge deployment.

Hosted migration eligibility/application is separately decided by the current
independent staging policy; source validation/merge does not waive a hold. No
manual hosted apply, hosted experiment/provider/budget activation, Mock seeding,
app installation, store publication or combined-map implementation occurs here.
