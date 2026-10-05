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
subscriptions. Router guards hide ordinary UI while any bootstrap is pending.
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
- `data/auth_gateway.dart` adapts Supabase Auth and the existing `profiles`
  table without leaking SDK objects into application or presentation code.
- `application/auth_session_controller.dart` restores and observes sessions,
  then distinguishes a missing anchor, an incomplete display name, and a
  completed profile.
- `application/auth_command_controller.dart` owns explicit request, verify,
  resend, profile-retry, and sign-out commands.
- `application/return_destination.dart` sanitizes optional in-app return paths.
- `presentation/` contains the request, verification, and root status UI.

The resend countdown is a user-interface convenience only. Supabase Auth owns
the real abuse-prevention and verification limits.

Email OTP requests have a PLANETS-owned 15-second application timeout. The
resolved Supabase Auth API does not expose per-request cancellation, so leaving
or timing out invalidates the local flow and ignores any later completion; it
does not claim to stop an already-started provider request.

Auth owns readiness, not profile editing. Skeletal anchors continue to the
Profile feature, while missing anchors retain the focused creation retry.

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
profile confirmation. Home still displays genuine current command failures,
including failed sign-out; there is no ready-session blanket error suppression.
The status timeout, database rules and suspension allowlist are unchanged.
See `docs/development/authqa01-otp-bootstrap-and-home-status.md` for the separate
disposition of #142's normal-Home observation and native evidence.
