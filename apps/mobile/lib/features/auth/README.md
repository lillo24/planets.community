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
- `data/provider_auth_adapter.dart` owns the provider boundary, configuration-gated
  Android Google adapter and canonical Supabase ID-token exchange. The fallback
  makes both providers unavailable.
- `data/google_native_client.dart` owns process-wide lazy SDK initialization and
  Google 7.x ID/access token acquisition with identity scopes only.
- `application/auth_session_controller.dart` restores and observes sessions,
  then distinguishes a missing anchor, an incomplete display name, and a
  completed profile.
- `application/auth_command_controller.dart` owns explicit request, verify,
  resend, provider, profile-retry, and sign-out commands. Its `_completeSignIn`
  routine owns shared profile-anchor/readiness completion.
- `application/return_destination.dart` sanitizes optional in-app return paths.
- `application/auth_routes.dart` identifies the exact three Auth routes for
  shared redirect, startup and native-link guards.
- `presentation/sign_in_screen.dart` chooses methods only when Google is available;
  otherwise it reuses the direct email form.
- `presentation/google_sign_in_button.dart` owns the accessible localized Google
  action, using the bundled official G and Google Sans Medium. See the
  [asset provenance and license](../../../assets/brand/google/README.md).
- `presentation/request_code_screen.dart` owns explicit email requests;
  `verify_code_screen.dart` owns code entry and existing retry/resend behavior.
- `presentation/auth_status.dart` owns session restoration and readiness status.
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

`/auth` is method choice only when the adapter exposes Google. Its email action
opens `/auth/email` without calling Google or requesting a code. Without Google,
`/auth` retains the direct OTP form; `/auth/email` also supports direct entry.
Only explicit Send requests a code and opens `/auth/verify`. Verification Back
and Use a different email reset pending OTP/cooldown and return to `/auth/email`,
retaining the sanitized internal `returnTo` and any canonical session.
Email Back returns to method choice when Google is available; otherwise it
cancels to the existing safe public destination. Close always cancels there.
All three routes share session, policy, profile and startup guards. Protected
Project/participation, Messages and invitation continuations survive each step.
Duplicate native links retain the current form; committed different links
invalidate old requests, including before a pending OTP exists.

AUTH01A prepared provider-neutral infrastructure. AUTH01B1 implements Android
Google code with `google_sign_in 7.2.0`. **External Google activation remains
unverified; empty/omitted `GOOGLE_WEB_CLIENT_ID` retains OTP-only UI and no SDK
initialization.** Apple and non-Android platforms remain unavailable. The optional
ID is public, shape-validated compile-time configuration, never a client secret.
No credentials are required for development and fake-based tests.

The adapter owns native credential acquisition followed
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
Only a current successful explicit sign-out sets `AuthCommandState.didSignOut`.
Application routing consumes this completion to reopen Welcome; passive session
loss, failed sign-out and abandoned late completions cannot produce it.

Android's permanent ID is `community.planets.app`; package/signing settings stay
unchanged. External provider configuration, identity-composition validation and
device QA remain deferred. See the
[Google Android runbook](../../../../../docs/development/auth01b-google-android.md)
for the exact 7.x token path, initialization/error caveats and activation steps,
and [AUTH01A checklists](../../../../../docs/development/auth01a-provider-ready-auth-infrastructure.md)
for deferred iOS/Apple work.

Session restoration has an explicit `restorationFailed` phase. Snapshot or
subscription failures show recovery and cannot impersonate signed-out entry.
Retry rechecks the stored session without starting a new login. Existing ready
identity/readiness is retained for a same-actor `tokenRefreshed` event; expired
sessions and actor changes still invalidate navigation/private state. Other Auth
events continue to recheck readiness. This follows the resolved Supabase event
contract and its [stream-error guidance](https://supabase.com/docs/reference/dart/auth-onauthstatechange).
Auth cancellation preserves both public invitation previews and the contextual
Messages root; protected chat/detail continuations still require authentication.
