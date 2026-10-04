# Project delegate invite links

This document primarily describes authority invitations. PI01 defines the distinct
participant capability at `/join/project/<token>`; its reusable-token,
no-photo direct admission and action/re-entry contracts are documented in
[`pi01-participant-invitations.md`](../implementation/pi01-participant-invitations.md).
PI02 implements mobile sharing/onboarding; [PI03](../implementation/pi03-browser-participant-invitations.md)
implements browser preview, explicit Join, receipt recovery, and token-free
`/joined/proposals/<id>` / `/joined/tavoli/<id>` confirmation/app handoff.
`/invite/project/` stays authority-only. Ordinary public sharing uses
`https://planets.community/proposals/<id>?intent=join` or the corresponding
`/tavoli/<id>?intent=join` and retains normal app request approval. Browser
confirmation opens those public paths without intent/token. Optional validated
Android/iOS downloads use `NEXT_PUBLIC_PLANETS_ANDROID_DOWNLOAD_URL` and
`NEXT_PUBLIC_PLANETS_IOS_DOWNLOAD_URL`; absent settings advertise no release.
PI04 must extend verified association and public-host routing to `/join/project/*`,
`/proposals/*`, and `/tavoli/*` while preserving `/invite/project/*`. Current
claims below remain authority-only; internal Flutter/browser routes do not prove
OS delivery. Host access-log/privacy verification is also PI04.

PLANETS uses one canonical bearer URL for Project Co-organizer and Co-creator
invitations:

```text
https://planets.community/invite/project/<43-character-token>
```

The route is a complete browser flow and, when production associations are
deployed, an Android App Link / iOS Universal Link. Opening, previewing, or
crawling it never accepts an invitation. Acceptance is an explicit
authenticated action backed by the canonical database RPC.

## User and navigation flow

The mobile UI lets a Creator or active Co-creator open Project detail → Manage
project → Project team. Co-organizer is the default invitation role. Selecting
Co-creator requires an extra confirmation that explains its structural powers
and the one-time bearer-link risk. The actor may then copy the role-labelled
URL or open the native share sheet. The raw token is returned once and exists
only in the immediate result surface. Pending invitation history contains the
requested role, dates, and issuer, never the token; a lost link must be revoked
and replaced.

The same Project team surface shows active delegated actors with their exact
role, delegation date, and grantor. Structural actors may promote, demote, or
revoke another delegated actor. Demoting or revoking a Co-creator warns that
their pending authority invitations are invalidated. These actions do not
change an independent participation membership. A delegated actor's own row
does not expose the generic role mutation or revocation actions; self-
resignation remains a separate deferred product decision.

Mobile handles `/invite/project/:token` as a public route. It previews first,
then uses `/auth?returnTo=...` or `/profile/edit?returnTo=...` when required.
The web fallback uses the same sequence with `/auth` and `/profile`. Both
surfaces require an explicit Accept and then navigate to the Proposal or Tavolo
detail. Return destinations remain subject to the existing internal-path
sanitizer; external and encoded-open-redirect values are rejected.

Project detail resolves the signed-in profile's exact
creator/co_creator/co_organizer/none role before rendering private actions. All
three manager roles receive operational Manage project and protected meeting
access. Creator and Co-creator are structurally authorized in the backend;
Co-organizer is not. My Proposals and My Tavoli keep owned and delegated
Projects separate, and delegated cards retain the caller's exact role.
Co-creator Project authoring and lifecycle controls are intentionally outside
this role-management surface and remain assigned to the next dedicated UX
change.

## Browser privacy controls

The Next.js invite route is dynamic and non-indexable. Its response applies:

```text
Cache-Control: private, no-store, max-age=0
Referrer-Policy: no-referrer
X-Robots-Tag: noindex, nofollow, noarchive
```

Static metadata is generic and contains no token or invite-specific text. GET
and server rendering call only the side-effect-free preview; the accept RPC is
reachable only from the pressed client action. Application code does not put
the token into logs, analytics, structured data, error copy, or persistence.

## Production association configuration

The repository intentionally retains bootstrap Android/iOS identifiers and has
no production signing identity. The `/.well-known` handlers therefore fail
closed with `404` and `Cache-Control: no-store` until all corresponding values
are valid. Values containing `.bootstrap.` are rejected.

Configure the deployed web application with:

```text
PLANETS_ANDROID_APP_LINK_PACKAGE_ID=<final Android application ID>
PLANETS_ANDROID_APP_LINK_SHA256_CERT_FINGERPRINTS=<SHA-256 fingerprint[,fingerprint...]>
PLANETS_IOS_TEAM_ID=<10-character Apple Team ID>
PLANETS_IOS_BUNDLE_ID=<final iOS bundle ID>
```

Android fingerprints use uppercase colon-separated byte pairs. Include every
certificate that can sign an installed production-like build, including the
store/distribution certificate where applicable. These are public association
identifiers, not signing material; never commit private keys or credentials.

The mobile project already limits Android handling to HTTPS host
`planets.community` and path prefix `/invite/project/` with `autoVerify`. iOS
already declares `applinks:planets.community` in `Runner.entitlements`; a real
signed provisioning profile must enable Associated Domains. Digital Asset
Links binds the production Android identity while the Android manifest limits
the claimed path to `/invite/project/`. The Apple association document binds
the production iOS identity and limits its paths to `/invite/project/*`.

`share_plus` 13 requires Flutter 3.41+, Dart 3.11+, iOS 13+, Android Gradle
Plugin 8.12.1+, and Gradle 8.13+. This repository currently uses Flutter 3.47,
Dart 3.13, iOS 15, AGP 9.1, and Gradle 9.3.

## Deployment and device verification

After deploying real association values, verify that both endpoints return
HTTP 200 directly, without redirects, and with JSON content:

```text
curl -i https://planets.community/.well-known/assetlinks.json
curl -i https://planets.community/.well-known/apple-app-site-association
```

On an Android device with the production-like signed app installed:

```text
adb shell pm verify-app-links --re-verify <final-package-id>
adb shell pm get-app-links <final-package-id>
adb shell am start -a android.intent.action.VIEW -c android.intent.category.BROWSABLE -d "https://planets.community/invite/project/<test-token>"
```

Confirm the domain is verified, the installed app opens the exact invite, and
the same style of URL falls back to the browser after uninstalling the app.

For iOS, install a build signed with the final Team/bundle identity and an
Associated Domains provisioning profile. Open the invite from Messages, Notes,
or another app; confirm it opens PLANETS, then confirm Safari fallback with the
app absent. Recheck the AASA response above when diagnosing. Apple's CDN and
device cache can delay association changes, so immediate propagation is not a
reliable test result. A macOS/Xcode build and real-device verification remain
required before claiming Universal Links are production-verified.

## Manual invite QA

- As the Creator and as a Co-creator, create each role of invite, copy it, and
  invoke the system share sheet (WhatsApp is an ordinary share target). Confirm
  Co-organizer is the default and Co-creator requires the high-privilege/bearer
  confirmation.
- Fetch or preview the URL and confirm the invitation remains pending.
- On mobile and web, confirm signed-out Auth and incomplete-profile completion
  return to the same invite before explicit acceptance.
- Accept each role as the recipient, confirm the Project team shows the exact
  role and provenance, and confirm the recipient can rediscover the Project
  with a truthful role badge.
- Promote and demote another delegated actor, then revoke them. Confirm the
  role updates after every authoritative reload, Co-creator pending invitations
  are invalidated when warned, and the current delegated actor's own row has no
  generic self-mutation actions.
- Confirm Co-organizer cards expose no structural edit/lifecycle controls and that
  an independent participant membership remains separate.
- Revoke a pending invite while its preview is open and confirm Accept fails
  safely. Repeat for expiry, a competing accepter, an owner opening their own
  invite, an already-active delegate, and a lost-response same-user retry.
- Remove an active delegate and confirm Project detail and an already-open
  Manage project screen lose manager-only access after reload while any
  participation membership remains unchanged. If the current structural actor
  loses authority during a mutation, confirm Project team reloads and removes
  its privileged controls.
- Switch accounts with an invite or management screen open and confirm no
  previous-account token, role, or protected location remains.
- Exercise both cold-start and already-running app links, malformed tokens,
  Projects without a group chat, and browser fallback while associations are
  absent or intentionally disabled.
