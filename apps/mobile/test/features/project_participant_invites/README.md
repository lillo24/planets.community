# Participant invitation validation

- `participant_gateway_test.dart` checks strict payloads and exact HTTP RPC
  parameters using a loopback server and the real Supabase adapter.
- `participant_controllers_test.dart` covers action lifetime/recovery/re-entry,
  canonical manager reads, ambiguous/stale mutations and account/Project changes.
- `participant_flow_test.dart` exercises the actual reactive app router and
  English/Italian widgets, sharing defaults, overlays, request/OTP/profile returns,
  photo separation and independent chat failures.
- `participant_refresh_test.dart` verifies affected cached controller refreshes,
  protected meeting clearing and chat signals.
- `participant_local_backend_test.dart` is opt-in disposable Supabase HTTP smoke;
  `../../support/local_participant_invitation_fixture.mjs` supplies its synthetic
  fixture. See the [PI02 record](../../../../../docs/implementation/pi02-mobile-participant-invitations.md).
