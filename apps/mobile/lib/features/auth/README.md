# Authentication feature

This folder owns the mobile email-OTP sign-in flow and the application boundary
around Supabase Auth. Supabase remains the source of truth for sessions; the
feature never persists a parallel signed-in flag, email address, or OTP value.

- `domain/auth_models.dart` defines app-owned identity, session, pending-flow,
  and safe failure models.
- `data/auth_gateway.dart` adapts Supabase Auth and the existing `profiles`
  table without leaking SDK objects into application or presentation code.
- `application/auth_session_controller.dart` restores and observes sessions,
  then checks whether the signed-in user has a profile anchor.
- `application/auth_command_controller.dart` owns explicit request, verify,
  resend, profile-retry, and sign-out commands.
- `application/return_destination.dart` sanitizes optional in-app return paths.
- `presentation/` contains the request, verification, and root status UI.

The resend countdown is a user-interface convenience only. Supabase Auth owns
the real abuse-prevention and verification limits.
