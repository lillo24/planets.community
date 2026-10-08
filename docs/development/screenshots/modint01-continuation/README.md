# MODINT01 continuation evidence

Actual synthetic local-app captures, not previews or physical-device evidence.
The [review packet](../../modint01-moderation-auth-integration-review.md) owns
case-level results, failed attempts, CI and remaining checks. No OTP, bearer URL,
privileged key or private-note body is included. Staff screenshots with private
notes in frame were withheld and retained outside Git, not redacted into false
proof of completed controls.

## Current October 8 evidence

The final runtime/test source is `cf5469ab32912299b4e382e8ef582e99cbf99b51`,
reconciled with committed main `e7971d6611a1bd750c0c51b797234f5cf19c9dec`.
All captures use ordinary app entry and real OTP/canonical backend authorization.
The owned Android API 35 AVD is not a physical device. Every published frame was
visually inspected; images were not redrawn, cropped or edited into a pass.

### Native: 26 actual captures

The 20 complete OTP campaign captures in `native-oct8/` come from passed run
`otp-device-oct8-layout-final.log` at `4db8f0212bd58e27e33307156195cd11e6db57c3`.
Production Mobile, unit tests and OTP/helper source are byte-identical through
final tested source `cf5469a`; subsequent changes affect only the request harness
and harness map. Its matching APK/config was freshly compiled/prepared, not reused
from an October 6–7 partial attempt.

- `authqa01-normal-home-{en,it}.png`: actual ready Home.
- `modint01-safety-{active,removed}-{en,it}.png`,
  `modint01-interaction_restriction-{active,removed}-{en,it}.png`,
  `modint01-content_hide-{active,removed}-{en,it}.png`: actual own type/history
  states and verbatim synthetic reasons; long cards use real scroll framing.
- `modint01-suspension-{en,it}.png` and
  `modint01-suspension-removed-{en,it}.png`: actual suspension/access status and
  ended suspension history following canonical revocation/status refresh.
- `modint01-personal-pair-en.png`: actual pair after canonical send/feed/history
  checks. The visible live-updates-unavailable banner remains a limitation;
  this image is not proof of healthy socket delivery or a Realtime root-cause fix.
- `modint01-template-private-copy-en.png`: photo-free canonical private copy in
  the actual Edit proposal screen.

Four final request images (`09c2b2-project-{en,it}.png`,
`09c2b2-resource-{en,it}.png`) come from passed matching run
`request-device-oct8-hit-test.log` at **`cf5469a`**. They frame the real independent
own-status explanation and retained draft/modal; the complete campaign also
verifies notices/Back, revoke/one deliberate retry, block/account isolation and
both suspension routes. Controls outside the scrolled frame are not missing
tests or synthetic overlays.

Two `modint01-back-resumed-suspension-{en,it}.png` files come from the separate
passed `resume-device-oct8.log` at `9f3c0d1a803a3cd0692a9dc67c81457eac844547`.
Actual root Back exited the Activity to the launcher; an ordinary cold launch,
without data clearing/session injection, rechecked the persisted suspended actor,
denied `/messages` and signed out. Auth/suspension/router production behavior is
unchanged afterward. The stronger resume assertion added at `4db8f02` was not
rerun as a separate cold-resume campaign; these are not relabelled exact-final
captures. Failed/overflow attempts and their partial images are retained privately.

### Browser: two settled captures, five withheld frames

`browser-oct8/suspended-account.jpg` and `ordinary-private-denied.jpg` are actual
settled October 8 browser views on the reconciled Web/backend source, unchanged
through `cf5469a`. They show Web's canonical suspended setup denial and ordinary
staff-route denial, respectively, not Mobile's suspension screen.

Actual moderator/admin apply/revoke, participant OTP/profile/Join/token-free
confirmation/read-only recovery/public fallback and hidden/unknown/elapsed/revoked
preview actions passed with canonical readback and current DOM assertions.
Five participant/preview capture frames remained compositor-stale or loading;
they are withheld outside Git, not published as fresh screenshot proof. Private
staff-note frames are also withheld. The seven October 6 browser captures below
remain explicitly historical. OS app association, configured store downloads,
physical-device/iOS/accessibility and founder presentation approval are not claimed.

## Historical normal browser, October 6

Production Next runtime built from `b928e77f02e74109a2fd7ceaeb5ded54c5ff942c`;
Web/production backend trees are identical at tested source
`c4f5c6ad7bc10d946dfad0a108f63574f5a48f47`. Normal OTP/profile/Join controls use
the owned backend on 54611 and Mailpit 54614, not an injected browser session.
Captures exclude browser chrome/bearer links.

- `browser-participant-joined.jpg`: token-free participation confirmation,
  explicit read-only refresh and configured public fallback. No OS association
  or store-download pass is claimed.
- `browser-suspended-account.jpg`: Web's denied account setup for a valid
  suspended session. It is not the Mobile suspension screen.
- `browser-ordinary-private-denied.jpg`: ordinary account's private staff route
  is Page unavailable.
- `browser-hidden-preview.jpg`, `browser-elapsed-preview.jpg`,
  `browser-revoked-preview.jpg`, `browser-unknown-preview.jpg`: generic unavailable
  invitation states. Hidden rendered DOM separately excludes title/Project ID;
  elapsed means the canonical one-time Project end-time boundary, not token TTL.

## Historical partial native replay, October 6

All 16 files in `native/` were captured by failed device attempt 6 from
`59299bc7ff0ae2ee0c81b4cc5424c609ab8f0abf`, using that attempt's matching fresh
defines/APK on the owned API 35 AVD. Production Mobile/backend trees are identical
at corrected tested source `c4f5c6a`; that source additionally corrects C's
Settings exit→Home entry. The failure after C's setup is not concealed.

- `authqa01-normal-home-{en,it}.png`: actual ready Home.
- `modint01-safety-{active,removed}-{en,it}.png`,
  `modint01-interaction_restriction-{active,removed}-{en,it}.png`,
  `modint01-content_hide-{active,removed}-{en,it}.png`: actual own type/history
  cards, synthetic reasons shown verbatim; longer cards retain scroll framing.
- `modint01-personal-pair-en.png`: actual pair screen after canonical send/feed
  assertion. Its visible live-updates-unavailable banner is not a healthy socket
  delivery claim or resolution of the historical Realtime issue.
- `modint01-template-private-copy-en.png`: photo-free canonical private copy
  opened in the normal editor.

At that historical publication, missing: full corrected OTP and request driver passes, EN/IT active/removed
suspension and both Project/Resource request-form explanation captures. The fresh
October 7 compiled OTP APK is unused; it supplies no additional screenshot pass.
Founder wording/presentation review, accessibility and physical-device/iOS checks
remain separate. The October 8 campaigns above now supply the complete native
passes and required states; no file in this historical set is relabelled.
