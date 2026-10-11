# AUTH01A — Provider-ready authentication infrastructure

**Status: AUTH01A's shared infrastructure is implemented. AUTH01B1 adds the
configuration-gated Google Android code path; external provider activation and
real-device QA remain separate. Empty/missing Google config keeps OTP-only UI.
Apple and Google on iOS remain unavailable.** See the
[Google Android code/activation runbook](auth01b-google-android.md).

## Implemented in AUTH01A

The mobile [auth feature README](../../apps/mobile/lib/features/auth/README.md)
maps the extension points:

- `domain/provider_auth.dart`: app-owned Google/Apple identifiers and sealed
  success, cancellation, and safe failure results.
- `data/provider_auth_adapter.dart`: `ProviderAuthAdapter` and its Riverpod
  injection point. AUTH01B1 now selects the real Android Google adapter only
  with a validated public Web client ID; otherwise both providers are unavailable.
  Availability performs no SDK initialization or network work. The command checks
  it before sign-in; native initialization remains lazy on an explicit tap.
- `application/auth_command_controller.dart`: `signInWithProvider` accepts
  adapter results. `_completeSignIn` is the single owner of profile-anchor
  creation, readiness resolution, safe setup failure, and temporary OTP cleanup
  for OTP, provider success, and profile retry. Session restoration stays with
  `AuthSessionController`; profile persistence stays with `ProfileAnchorGateway`.

The data-layer adapter acquires native credentials, then exchanges them
with Supabase. Its success identity must be the established Supabase session's
identity; a vendor account ID or native token alone is not authentication success
for PLANETS. Credentials and SDK objects never enter application/presentation
code. AUTH01B1 implements Google's current 7.x ID-token and identity-scope
authorization APIs followed by Supabase exchange; Apple remains future work.

Provider cancellation preserves any pending OTP flow and cooldown without an
error banner. Failures use existing `AuthFailureKind` values; anchor/readiness
failure keeps the authenticated identity in safe profile setup for retry.
Revision/disposal checks prevent late command completion from changing a newer
flow, including profile retry and sign-out. This does not cancel an external
operation or undo a canonical session established by it. Future real adapters
must validate native dismissal/session-event races during integration QA.
Sign-out continues through the canonical `AuthGateway`, with no provider logout.

Tests inject `FakeProviderAuthAdapter` through `providerAuthAdapterProvider` and
reuse the existing fake auth/profile gateways. No provider account, credentials,
network request, or changed OTP QA procedure is required. Without Google config,
normal UI stays OTP-only; AUTH01B1 tests also cover the conditional Google action.

## Intentionally not implemented

- External Google/Apple OAuth credentials, secrets, dashboard setup, or hosted
  provider enablement. Google Android SDK/adapter code is now implemented.
- Google iOS and Apple adapters/capabilities. Android's permanent application ID
  is **`community.planets.app`**, with the existing upload-key/Play App Signing
  workflow. AUTH01B1 changes neither. iOS still uses bootstrap
  `community.planets.bootstrap.planetsMobile`; finalize it in separate iOS work.
- Real device/provider QA, manual account-linking UI or policy, production
  deployment, or database migrations. `supabase/config.toml` stays unchanged:
  Apple is disabled and no Google provider is enabled.

## AUTH01B — Google activation checklist

1. For Android, use permanent `community.planets.app` and the **Play App Signing
   app-signing certificate SHA-1** for Play-installed builds. The upload-key
   certificate alone is insufficient. iOS remains separate and deferred.
2. AUTH01B1 pins `google_sign_in 7.2.0` with the resolved Android implementation
   and Supabase versions recorded in its runbook. Account owners must create the
   required Google OAuth clients and register signing fingerprints.
3. Configure the relevant Supabase Google settings through the supported
   local/managed/self-hosted configuration, keeping secrets outside Git.
4. AUTH01B1 implements native credential acquisition and Supabase exchange behind
   `ProviderAuthAdapter`, returning the canonical identity and mapping dismissal
   and failures to app-owned results through the existing completion command.
5. AUTH01B1 gates the adapter and localized Google button by Android platform and
   validated `GOOGLE_WEB_CLIENT_ID`; empty/omitted values keep login dormant.
6. Validate new users, existing OTP users, incomplete/missing profiles, retry,
   cancellation and late session events, sign-out/sign-in, and Android/iOS as
   applicable. Validate account composition separately; do not silently invent
   account-linking policy.
7. Document actual external setup locations and nonsecret configuration;
   record device/provider evidence without committing credentials.

## AUTH01C — Apple activation checklist

1. Verify/finalize the iOS bundle/App ID before account-owner provisioning.
2. Configure Apple Developer Sign in with Apple capability and the relevant
   Team/Service/Key settings required by the selected native/Supabase flow.
3. Configure Supabase Apple settings using external secrets; never commit
   Apple private keys or generated secrets. Preserve self-host portability.
4. Implement native acquisition and Supabase exchange behind the adapter,
   including nonce/security handling required by the then-current SDK/flow.
5. Map dismissal/failures into the existing results and expose a localized
   Apple button only on supported, genuinely configured surfaces.
6. Test new users, existing account behavior, Hide My Email and account-linking
   edge cases, profile completion/retry, cancellation/late session events, and
   sign-out/sign-in on real supported devices. Resolve any consequential
   linking policy with the founder before implementing it.
7. Record external setup locations, secret handling, and real-device QA.

## Validation

Use the repository's mobile validation (`npm run check:mobile`) after dependency
restore. Focused auth, Profile, and Settings tests exercise the shared completion
path and existing account exits. Formatting/static analysis and the full mobile
suite are required before merge. AUTH01B1 also requires an Android compile for the
plugin. Real Google/Apple integration QA belongs to external activation and is
intentionally deferred until account-owner configuration exists.

AUTH01A local validation on 2026-10-06 against the initial `6713302` base used
Flutter 3.47.2 / Dart 3.13.2:
dependency restore and localization generation, full `flutter analyze`,
auth-scoped `dart analyze lib/features/auth`, formatting of all 452 Dart files,
109 focused Auth/Profile/Settings tests, and the full mobile suite (1,266 passed,
two existing skips) all passed. The two changed docs passed Prettier, and the
reviewed diff passed `git diff --check` with no provider configuration,
dependency, secret, or platform identifier changes.
