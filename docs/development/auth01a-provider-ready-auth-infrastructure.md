# AUTH01A — Provider-ready authentication infrastructure

**Status: Google/Apple sign-in infrastructure is prepared; external configuration
and real provider integrations are not implemented or enabled. Email OTP remains
the only user-facing sign-in method.**

## Implemented in AUTH01A

The mobile [auth feature README](../../apps/mobile/lib/features/auth/README.md)
maps the extension points:

- `domain/provider_auth.dart`: app-owned Google/Apple identifiers and sealed
  success, cancellation, and safe failure results.
- `data/provider_auth_adapter.dart`: `ProviderAuthAdapter` and its Riverpod
  injection point. The default adapter reports both providers unavailable and
  returns an explicit safe failure for direct sign-in calls. It has no backend
  dependency or startup initialization. Availability must mean configured and
  supported on the current platform; the command checks it before calling sign-in.
- `application/auth_command_controller.dart`: `signInWithProvider` accepts
  adapter results. `_completeSignIn` is the single owner of profile-anchor
  creation, readiness resolution, safe setup failure, and temporary OTP cleanup
  for OTP, provider success, and profile retry. Session restoration stays with
  `AuthSessionController`; profile persistence stays with `ProfileAnchorGateway`.

The future data-layer adapter acquires native credentials, then exchanges them
with Supabase. Its success identity must be the established Supabase session's
identity; a vendor account ID or native token alone is not authentication success
for PLANETS. Credentials and SDK objects never enter application/presentation
code. The actual native credential and exchange implementations remain future
provider work; no token shape or vendor error codes are prescribed here.

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
network request, or changed OTP QA procedure is required. Normal UI stays OTP-only.

## Intentionally not implemented

- Google/Apple SDKs, real native adapters, OAuth credentials, secrets, dashboard
  setup, or provider enablement in Supabase.
- Final Android/iOS identifiers, Apple capabilities, signing changes, or release
  configuration. The current bootstrap IDs remain
  `community.planets.bootstrap.planets_mobile` (Android) and
  `community.planets.bootstrap.planetsMobile` (iOS); **verify/finalize permanent
  IDs before creating final OAuth credentials**.
- Real device/provider QA, manual account-linking UI or policy, production
  deployment, or database migrations. `supabase/config.toml` stays unchanged:
  Apple is disabled and no Google provider is enabled.

## AUTH01B — Google activation checklist

1. Verify/finalize the Android application ID and iOS bundle ID before final
   credentials; confirm target platforms and signing identities.
2. Select a provider SDK compatible with the then-resolved Flutter/dependency
   versions. Account owners must create the required Google OAuth clients and
   register signing fingerprints where required.
3. Configure the relevant Supabase Google settings through the supported
   local/managed/self-hosted configuration, keeping secrets outside Git.
4. Implement native credential acquisition and Supabase exchange behind
   `ProviderAuthAdapter`; return the canonical identity and map dismissal and
   failures to the app-owned results. Reuse the existing completion command.
5. Replace the default injection only when configuration/platform checks prove
   availability. Add a localized Google button only on available surfaces.
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
suite are required before merge. Real Google/Apple integration QA belongs to
AUTH01B/01C and is intentionally deferred.

AUTH01A local validation on 2026-10-06 against the initial `6713302` base used
Flutter 3.47.2 / Dart 3.13.2:
dependency restore and localization generation, full `flutter analyze`,
auth-scoped `dart analyze lib/features/auth`, formatting of all 452 Dart files,
109 focused Auth/Profile/Settings tests, and the full mobile suite (1,266 passed,
two existing skips) all passed. The two changed docs passed Prettier, and the
reviewed diff passed `git diff --check` with no provider configuration,
dependency, secret, or platform identifier changes.
