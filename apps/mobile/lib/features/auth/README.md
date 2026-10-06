# Authentication feature

This folder owns the mobile email-OTP sign-in flow and the application boundary
around Supabase Auth. Supabase remains the source of truth for sessions; the
feature never persists a parallel signed-in flag, email address, or OTP value.

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
