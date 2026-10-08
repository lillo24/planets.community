# Authentication feature

This folder owns the mobile email-OTP sign-in flow and the application boundary
around Supabase Auth. Supabase remains the source of truth for sessions; the
feature never persists a parallel signed-in flag, email address, or OTP value.

09C1B checks own suspension status before every authenticated bootstrap, OTP
profile creation and successful profile-completion transition. AuthGateway owns
that safe bootstrap RPC; the result is not persisted. A status check has a
15-second timeout and fails closed into `accountCheckFailed`, never readiness or
profile setup. `checkingAccount`, `suspended` and error states use the dedicated
account-access screen, with localized plain-text reason, check-again and sign-out.
No staff/evidence/appeal fields are rendered or logged. The pure body has a widget
preview independent of Auth/Storage. PlanetsApp refreshes on foreground/resume;
Auth snapshot revisions reject late completion after sign-out/account switching.
Private controllers watch `accountAccessIdentityId`: ordinary refresh preserves
same-account caches, while suspension/status failure clears them and closes chat
subscriptions. Router guards hide ordinary UI during full bootstrap. An already
ready same-actor token refresh retains navigation while checking account status;
denial/failure still closes private UI, and the database denies access immediately.
Welcome alone owns unresolved signed-out restoration/retry, not account denial.
There is no existing centralized RPC-error interception; individual screens do
not gain ad-hoc suspension handlers. Backend denial is immediate at subsequent
authorization boundaries; mobile detects it on resume or explicit status refresh.

09C2B1's private-history controller requests that same Auth-owned status refresh
when its general history RPC denies with `PT403`. It does not construct a new
suspension UI/state, retry the denied RPC or widen the status allowlist. Unlike
ordinary same-account caches, private-history pages/reasons clear on every Auth
session/bootstrap revision as well as identity changes and disposal.

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
  routine requests shared profile-anchor/readiness completion from the canonical
  `AuthSessionController`, following its completed/failed/superseded outcome.
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

Flow revisions, the canonical sign-out/account-switch epoch, and disposal checks
ignore late command completions after the
flow is abandoned or replaced, including profile retry and sign-out. They do
not cancel native/provider/network operations or roll back a canonical session
already established externally. Sign-out still uses only `AuthGateway.signOut`.
Only a current successful explicit sign-out sets `AuthCommandState.didSignOut`.
Application routing consumes this completion to reopen Welcome; passive session
loss, failed sign-out and abandoned late completions cannot produce it.

Permanent Android/iOS identifiers, external provider configuration, real
adapters, account-linking validation, and device QA remain deferred. See the
[AUTH01A status and activation checklists](../../../../../docs/development/auth01a-provider-ready-auth-infrastructure.md)
before starting Google or Apple activation.

AUTHQA01 coordinates explicit OTP/profile-retry completion with SDK Auth events
inside `AuthSessionController`. Every event still starts a fresh account-status
check. A replacement for the same identity inherits in-flight anchor creation;
the command follows its typed completed/failed/superseded result rather than
turning supersession into a setup error. A different identity or sign-out rejects
the obsolete command; cancellation preserves any newer pending destination.
A sign-out/switch epoch rejects both success and failure from an older operation
even after the same account signs in again; an identity-ID match alone cannot
restore an abandoned flow. Provider disposal also invalidates pending commands.
`bootstrap` retains its existing boolean contract for ordinary restoration and
profile confirmation. Main's Home no longer owns an Auth card; current command
failures remain visible at the Auth/account-exit controls, including Settings'
failed sign-out. There is no ready-session blanket error suppression.
The status timeout, database rules and suspension allowlist are unchanged.
See `docs/development/authqa01-otp-bootstrap-and-home-status.md` for the separate
disposition of #142's normal-Home observation and native evidence.

Session restoration has an explicit `restorationFailed` phase. Snapshot or
subscription failures show recovery and cannot impersonate signed-out entry.
Retry rechecks the stored session without starting a new login. Existing ready
identity/readiness is retained while a fresh account-status check runs for a
same-actor `tokenRefreshed` event; expired
sessions and actor changes still invalidate navigation/private state. Other Auth
events continue to recheck readiness. This follows the resolved Supabase event
contract and its [stream-error guidance](https://supabase.com/docs/reference/dart/auth-onauthstatechange).
Auth cancellation preserves both public invitation previews and the contextual
Messages root; protected chat/detail continuations still require authentication.
