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
