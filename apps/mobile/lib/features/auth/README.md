# Authentication feature

This folder owns the mobile email-OTP sign-in flow and the application boundary
around Supabase Auth. Supabase remains the source of truth for sessions; the
feature never persists a parallel signed-in flag, email address, or OTP value.

- `domain/auth_models.dart` defines app-owned identity, session, pending-flow,
  and safe failure models.
- `domain/provider_auth.dart` defines Google/Apple identifiers and provider
  success, cancellation, and safe failure results without SDK objects.
- `data/auth_gateway.dart` adapts Supabase Auth and the existing `profiles`
  table without leaking SDK objects into application or presentation code.
- `data/provider_auth_adapter.dart` owns the injectable future native-provider
  boundary and the default adapter that makes both providers unavailable.
- `application/auth_session_controller.dart` restores and observes sessions,
  then distinguishes a missing anchor, an incomplete display name, and a
  completed profile.
- `application/auth_command_controller.dart` owns explicit request, verify,
  resend, provider, profile-retry, and sign-out commands. Its `_completeSignIn`
  routine owns shared profile-anchor/readiness completion.
- `application/return_destination.dart` sanitizes optional in-app return paths.
- `presentation/` contains the request, verification, and root status UI.
- `presentation/account_sign_out_action.dart` is the shared destructive
  Profile/Settings action using the existing command busy/error state.

The signed-in Profile ends with Sign out after its ordinary actions. Public
Settings offers the same exit for all authenticated phases, including profile
setup. Home's fast Sign out shortcut appears only with the existing demo-tools
gate; normal account management lives in Profile and Settings.

The resend countdown is a user-interface convenience only. Supabase Auth owns
the real abuse-prevention and verification limits.

Email OTP requests have a PLANETS-owned 15-second application timeout. The
resolved Supabase Auth API does not expose per-request cancellation, so leaving
or timing out invalidates the local flow and ignores any later completion; it
does not claim to stop an already-started provider request.

Auth owns readiness, not profile editing. Skeletal anchors continue to the
Profile feature, while missing anchors retain the focused creation retry.

## Social sign-in readiness

AUTH01A prepared provider-neutral infrastructure. **Google and Apple are not
configured or active and are intentionally unavailable by default.** Email OTP
remains the only user-facing sign-in path. No provider SDK, credentials, or
additional setup is installed or required for current development and tests;
the auth screen exposes no provider buttons.

Future AUTH01B/01C work should replace `providerAuthAdapterProvider` with a real
`ProviderAuthAdapter`. The adapter owns native credential acquisition followed
by Supabase credential exchange; it must return `ProviderAuthSuccess` only for
the established Supabase session's `AuthIdentity`. Native tokens, nonce handling,
vendor IDs, and SDK exceptions stay behind that data-layer boundary. Availability
must reflect real configuration and platform support, before any button appears.

`AuthCommandController.signInWithProvider` consumes those app-owned results and
reuses the same anchor creation, readiness, safe profile failure, and temporary
flow cleanup as OTP and profile retry. Cancellation returns false without an
error and preserves any pending OTP flow/cooldown; failure returns false with a
safe `AuthFailureKind`. Unavailable attempts report `serviceUnavailable` and
never call the adapter's sign-in method. Success means PLANETS completion
finished, including the existing profile-setup-required state when applicable.

Flow revisions and disposal checks ignore late command completions after the
flow is abandoned or replaced, including profile retry and sign-out. They do
not cancel native/provider/network operations or roll back a canonical session
already established externally. Sign-out still uses only `AuthGateway.signOut`.

Permanent Android/iOS identifiers, external provider configuration, real
adapters, account-linking validation, and device QA remain deferred. See the
[AUTH01A status and activation checklists](../../../../../docs/development/auth01a-provider-ready-auth-infrastructure.md)
before starting Google or Apple activation.
