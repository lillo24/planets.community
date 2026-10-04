# PI03 — Browser joining and app handoff

Implemented over merged PI01/PI02 at `166a6d43a03d0fc3330e97e3be1388cc7eec65ac`.
The PR/task report records final head, hosted scoped CI and merge SHAs. This
change adds no migration, dependency, production deployment or native claim.

## Routes and admission boundaries

| URL                                              | Browser behavior                                                                                                                                                                                                                                    |
| ------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/proposals/<id>` / `/tavoli/<id>`               | Public detail plus app/download CTA. Exactly one `intent=join` adds dismissible intent; duplicate/other markers do not. Dismiss returns to the public detail. Public ended/paused copy remains truthful. No browser request/admission is submitted. |
| `/join/project/<token>`                          | Minimal typed preview, explicit OTP/basic-profile continuation, explicit photo-free Join. Public viewing, SSR, prefetch, auth restoration and profile save perform no admission.                                                                    |
| `/joined/proposals/<id>` / `/joined/tavoli/<id>` | Token-free confirmation. Every GET and browser mount rechecks current own membership/Creator context. Logout/account changes clear personal state; failed reads offer read retry.                                                                   |
| `/invite/project/<token>`                        | Existing authority invitation; its admission policies and normal onboarding cancellation defaults remain unchanged.                                                                                                                                 |

Preview uses only `available/project_id/project_kind/project_title`. Unavailable
requires null context; malformed/service responses are recoverable errors.
Acceptance calls PI01's expected-account/token/action UUID RPC, never direct
membership/request/contribution writes. The verified account is checked before
mutation and publication, while cross-tab Auth events invalidate state promptly.
Only explicit Join generates an action UUID. Double clicks are suppressed.

The controller retains unresolved tuples outside component lifetimes in browser
tab/process memory, including navigation/remount and revoked/failed preview.
**Check previous join** explicitly retries the same tuple. Reload/restart loses
the UUID; the new process cannot claim recovery. A fresh click after reset is
fresh intent, with canonical current-membership checks preventing duplicate
admission. No token/action is saved to local/session storage or sent to a store.

Original joined/already-joined/Creator receipts are parsed strictly; ended
left/removed episodes never imply present membership. Canonical own episode
reads can discover a newer current episode. Creator needs no invented membership.
A recorded result with failed follow-up read stays recorded; **Retry status
check** only reads. **Join Project again** is separate deliberate fresh intent,
offered only after valid preview and successful no-current/non-Creator reads.
Backend eligibility and capacity remain authoritative. `PT409` distinguishes
the exact full message from generic unavailability; identity/profile/input,
transport and malformed responses have separate safe copy.

Auth/profile preserve the exact sanitized return and offer participant-specific
cancellation back to preview (including a nested profile continuation). Normal
Home and authority defaults remain. No photo is required by the participant
browser journey; ordinary mobile request/publication gates remain unchanged.
PI01 withdraws pending requests with `direct_participant_invitation`, preserves
messages/offers/chat history and creates zero automatic commitments.

## Handoff and configuration

**Open PLANETS** after confirmation is exactly
`https://planets.community/proposals/<id>` or
`https://planets.community/tavoli/<id>`, without intent/token/email/session/OTP
or action UUID. Same-account app sign-in rediscovers membership through the
canonical backend. Links remain non-mutating after revocation/closure; there
is no automatic redirect/install, success timer or deferred-install attribution.

Optional build-time public settings:

- `NEXT_PUBLIC_PLANETS_ANDROID_DOWNLOAD_URL`
- `NEXT_PUBLIC_PLANETS_IOS_DOWNLOAD_URL`

Use real HTTPS listings/downloads without credentials or fragments. Missing
settings show honest unavailable download copy and retain browser fallback.
Malformed settings fail with the key name, never the supplied value. HTTP is
permitted only for loopback hosts with explicit `NEXT_PUBLIC_APP_ENV=local`.
The link origin remains fixed to PI02's `https://planets.community`.

## Privacy and operational limits

Participant/confirmation routes are dynamic (`force-dynamic`, `revalidate=0`)
with generic metadata. Headers apply `private, no-store`, `no-referrer` and
`noindex, nofollow, noarchive` to participant, confirmation, authority, auth and
profile responses. Protecting all auth/profile responses also protects encoded
participant returns. Existing SSR Proxy request/response cookie updates and
Supabase cache-header propagation remain intact.

Sentry client/server filters drop secret-bearing events/breadcrumbs: direct or
encoded participant/authority paths, token-shaped strings, RPC token keys and
serialized/original exceptions. Ordinary public and token-free URLs remain
observable, and safe categorized failures remain useful. Provider access logs,
analytics outside this application, OS HTTPS delivery and signing are PI04.
PI04 must cover `/join/project/*`, preserved `/invite/project/*`, **and both
`/proposals/*` and `/tavoli/*`** for ordinary sharing/token-free handoff. Existing
Android/Apple claims cover authority paths only. PI05 owns broader integration
and demo scenarios; no store listing or verified native association is claimed.

## Validation and reproduction

Local validation passed: `npm run check:web` (28 shared tooling tests, 255 web
tests, one opt-in test skipped, ESLint, Next type generation/TypeScript and
production build), `npm run format:check:web`, scoped implementation-document
formatting, and `git diff --check`. The skipped integration test passed separately
against disposable Supabase with the production Next server and gateway.
Three subsequent focused onboarding-continuation tests also passed; the final
hosted Web suite includes all 258 web tests plus the explicitly skipped local
integration test.
Browser OTP entry/navigation and installed-device/store delivery were not
executed; the manual procedure below records those limits honestly.

Run `npm run check:web`, formatting and `git diff --check`. Parser, gateway,
controller, UI, route, auth/profile and telemetry tests cover read-only opening,
identity races, same-tuple recovery, full-reset lifetime, ended/Creator receipts,
fresh re-entry, independent read retry, safe returns and handoff configuration.

The [opt-in verifier](../../apps/web/test-support/README.md) uses a production
Next server against an isolated local Supabase stack. It checks actual preview,
encoded auth/profile and token-free confirmation HTTP headers; photo-free
Proposal/Tavolo admission through the production gateway; pending request and
offer/message preservation with zero commitments; same-action replay after
revocation; current membership after leave and fresh re-entry. Its standard
suite skip avoids unrelated Database CI work; run it explicitly after a local
production build. No existing browser end-to-end runner is configured here.

Manual full-browser procedure (separate from automated HTTP/component checks):

1. Open both public kinds signed out with single/duplicate intent; dismiss and
   verify detail survives without sign-in. Check paused/ended and 404/privacy.
2. Open a mobile-created synthetic special link. View public detail without
   joining; return, cancel OTP/profile setup and verify exact preview return.
3. Sign in as new/existing photo-free users, finish a basic profile, return to
   preview, and explicitly Join. Confirm token-free navigation and same-account
   app/download/browser choices. Cancel or reload during OTP; no auto-Join.
4. Lose a join response, navigate away/back, revoke the link as organizer and
   explicitly check previous Join. Confirm same episode; full reload must never
   claim old UUID recovery. Switch account/log out in a second tab mid-request.
5. Leave/remove, reload confirmation, retry failed reads, recover an ended
   receipt alongside a newer current episode, and deliberately Join again only
   through a valid link. Missing downloads must preserve admitted membership.

Browser interaction and installed-device/store delivery must be reported only
when actually executed; HTTP and component tests do not prove those journeys.
