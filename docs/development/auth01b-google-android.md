# AUTH01B1 — Google sign-in on Android

**Code integration only. Google login is not live until the account owner configures
Google Auth Platform and the staging Supabase Google provider, supplies the public
Web client ID to a new build, and completes real-device QA.** Empty configuration
keeps the existing email OTP flow. This change does not activate hosted services,
change signing or package identity, bump the app version, or upload to Play.

## Code and configuration contract

`GOOGLE_WEB_CLIENT_ID` is an optional compile-time string in `AppConfig` and the
ignored `apps/mobile/config/staging.json`. Omission or `""` disables Google login.
A nonempty value must have the shape
`123456789-example.apps.googleusercontent.com`; surrounding whitespace is rejected.
This is shape validation, not proof of provider setup. The Web ID is public client
configuration, never a client secret. Runtime and distribution preflight share
the validator; arbitrary extra staging keys and nonstring values remain rejected.
The five existing staging keys are still required by distribution preflight.

`providerAuthAdapterProvider` exposes Google only on native Android with valid
configuration. Apple, iOS, desktop and web remain unavailable. Availability never
initializes the SDK or contacts a service. AUTH01B3 makes `/auth` a method chooser
when Google is available, with a bundled official multicolor G and Google Sans
Medium in the localized bordered button. Its email action opens `/auth/email`
without sending a code. Without Google, `/auth` retains direct OTP entry.
Verification Back returns to `/auth/email`; all three routes share existing
session, policy, profile, startup and native-link guards and sanitized `returnTo`.
See [asset provenance and license](../../apps/mobile/assets/brand/google/README.md).
The Google action delegates to `AuthCommandController.signInWithProvider`; Supabase UUID, profile-anchor
creation/readiness, policy/startup routing and protected `returnTo` use the shared
completion path. No separate Google profile or signed-in flag is created.

The SDK is initialized lazily on an explicit tap, exactly once per process with
`serverClientId: GOOGLE_WEB_CLIENT_ID`. Failed initialization is retained because
repeating initialization is unsupported; after correcting build/provider setup,
restart the app. Authentication/exchange failures and cancellations can be retried
without reinitialization. No lightweight startup authentication, browser OAuth
fallback, Firebase login, `google-services.json`, or Google Gradle plugin is used.

## Resolved native token path

The pinned versions are `google_sign_in 7.2.0`, its locked Android implementation
`google_sign_in_android 7.2.17`, `supabase_flutter 2.17.2` and `gotrue 2.27.2`.
The already resolved `google_sign_in_platform_interface 3.1.0` is declared as a
dev dependency for SDK platform fakes. Follow the
[official 7.x APIs](https://pub.dev/packages/google_sign_in/versions/7.2.0), not the
older constructor/`signIn()`/`authentication.accessToken` examples still present in
some Supabase documentation.

1. `GoogleSignIn.instance.initialize(serverClientId: ...)`, memoized process-wide.
2. Explicit `authenticate(scopeHint: identityScopes)` yields a native account;
   `account.authentication.idToken` must be nonempty.
3. `account.authorizationClient.authorizationForScopes(identityScopes)` obtains
   already granted authorization, or `authorizeScopes(identityScopes)` prompts
   within the explicit sign-in operation. Its `accessToken` must be nonempty.
   Scopes are only `openid`, `https://www.googleapis.com/auth/userinfo.email` and
   `https://www.googleapis.com/auth/userinfo.profile`. No People/Contacts API,
   server auth code, offline access, or extra product-data permission is requested.
4. The existing Supabase client calls `auth.signInWithIdToken` with
   `OAuthProvider.google`, `idToken` and `accessToken`. Success requires a real,
   unexpired Supabase session and its nonempty canonical user ID; a vendor ID or
   user-only response is never success. Supabase owns ordinary session persistence
   and refresh. PLANETS adds no Google-token/account storage or logging; native
   credentials remain local to the data-layer call.

Explicit SDK cancellation returns quiet cancellation. Structured SDK
configuration/UI errors become safe service-unavailable failures. Supabase
retryable fetch failures/timeouts use the existing connection message; unknown
SDK errors, including interruption without a reliable network classification,
use the generic retry message. Raw descriptions/tokens never reach the UI.
Normal sign-out still calls only Supabase; it does not disconnect or revoke Google.

Android Credential Manager can report a configuration error as `canceled` after
account selection; the plugin cannot distinguish it from dismissal. Persistent
quiet returns during device QA require checking package, certificate SHA and Web
ID. See the [official Android integration guidance](https://pub.dev/packages/google_sign_in_android/versions/7.2.17).
Flow revisions ignore abandoned command completions but cannot undo a canonical
session already established by Supabase; test native dismissal/late session events.

## Account-owner activation steps

1. In Google Auth Platform, select the intended project and configure Branding,
   Audience/test users and the basic identity scopes above. Complete applicable
   brand/audience verification before broader use. Review the bundled localized
   button against the
   [current branding requirements](https://developers.google.com/identity/branding-guidelines)
   before public activation; code/UI validation does not verify account state.
2. Create an **Android OAuth client** for the permanent package
   **`community.planets.app`**. For Play-installed builds register the **Play App
   Signing app-signing certificate SHA-1**, obtained from Play Console's app
   integrity/signing page. The upload-key SHA-1 alone does not identify the
   Play-distributed APK. Additional certificates need their own appropriate
   Android client registration. Debug SHA-1 is optional and only needed when
   explicitly testing a locally installed debug build. Never change the package
   or signing configuration to resolve OAuth errors.
3. Create a **Web application OAuth client** in the same project. Its public
   client ID is Android's `serverClientId`. Configure the authorized callback URI
   shown by the staging Supabase Google provider, normally
   `https://<staging-project-ref>.supabase.co/auth/v1/callback`. Follow
   [Supabase's provider setup](https://supabase.com/docs/guides/auth/social-login/auth-google)
   for any enabled web origins; this native path itself has no browser callback.
4. In staging Supabase Authentication > Providers > Google, enable the provider,
   register the appropriate OAuth client IDs/audiences and Web client secret as
   required by the provider settings. Use the same Web client ID as the app, with
   the Web ID first if the provider accepts a list. Keep the secret solely in
   Google/Supabase external configuration, never in mobile config or Git. Do not
   enable iOS nonce exceptions for this Android path. The eventual self-hosted
   equivalent is Supabase Auth's Google provider configuration; provisioning it
   remains a separate phase.
5. In ignored `apps/mobile/config/staging.json`, add only
   `"GOOGLE_WEB_CLIENT_ID": "<actual public Web client ID>"`. Keep the required
   staging backend/publishable key, `ENABLE_DEMO_TOOLS: "false"` and Sentry rules
   from the [closed-test runbook](play-closed-test.md). The committed example
   intentionally has `"GOOGLE_WEB_CLIENT_ID": ""`. Never add a client secret.
6. In a separately authorized activation/release task, choose the next Play
   version code, build a new staging AAB with the existing upload key, verify it
   and upload to the intended closed-test track. Existing installed binaries do
   not receive new compile-time config. This code PR's debug compile is not an
   uploaded or signed release candidate.

No real IDs, secrets, certificate values, dashboard changes or provider setup
were needed to implement and validate this code. Do not enable production as a
side effect of staging QA.

## Validation and activation QA

Automated coverage uses synthetic native SDK and Supabase HTTP fakes: lazy
initialization, 7.x authorization fallback and scopes, token absence, safe SDK/
exchange failures, retry and cancellation; config/preflight safety; conditional
UI, busy state, protected return; and the existing shared OTP/profile/readiness/
stale-completion/sign-out tests. Run `npm run check:mobile` and an Android compile
such as `flutter build apk --debug` from `apps/mobile`. Run Flutter tests and the
Android build serially. No real account or provider success is inferred from
these checks.

Before enabling login for testers, record device/build/certificate/backend and
test all of the following on the actual Play-installed closed-test build:

- New Google user: canonical Auth UUID, one profile anchor, policy/onboarding and
  missing/incomplete/ready profile flow, including retry after anchor failure.
- Existing **same-email OTP user**: verify Supabase resolves the intended existing
  UUID/profile/history; automatic account composition remains unverified until
  this actual project/account test passes. Do not introduce manual linking,
  unlinking, deletion, merging or conflict resolution to force the result.
- Protected and invitation `returnTo`, cancellation at account selection and
  consent, safe failures, duplicate taps, no-network recovery, abandonment and
  late session events; email OTP still works without Google config.
- Sign-out then explicit Google sign-in again, session restoration, app restart,
  account changes, and both English/Italian accessibility and branding.

Escalate ambiguous identity collisions or destructive linking outcomes. iOS
Google, Apple activation, signing/bundle-ID changes and production release remain
deferred. Code readiness is separate from account-owner/provider/device evidence.
