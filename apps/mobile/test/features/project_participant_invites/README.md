# Participant invitation validation

- `participant_gateway_test.dart` checks strict payloads and exact HTTP RPC
  parameters using a loopback server and the real Supabase adapter.
- `participant_controllers_test.dart` covers action lifetime/recovery/re-entry,
  canonical manager reads, ambiguous/stale mutations and account/Project changes.
- `participant_flow_test.dart` exercises the actual reactive app router and
  English/Italian widgets, sharing defaults, overlays, request/OTP/profile returns,
  photo separation and independent chat failures.
  Its PI04 cases also inject cold default-route/warm platform messages, including
  duplicates during OTP/profile, different Projects, stale actions, ordinary
  detail intent, authority previews and unsafe absolute URLs.
- `participant_refresh_test.dart` verifies affected cached controller refreshes,
  protected meeting clearing and chat signals.
- `participant_local_backend_test.dart` is opt-in disposable Supabase HTTP smoke;
  `../../support/local_participant_invitation_fixture.mjs` supplies its synthetic
  fixture. See the [PI02 record](../../../../../docs/implementation/pi02-mobile-participant-invitations.md).
- `participant_web_rediscovery_test.dart` is an opt-in PI04 adapter/backend check
  for the same synthetic browser account after explicit Join and original-link
  revocation. Normal tests skip it; it refuses non-PI04 API origins. The
  [PI04 record](../../../../../docs/implementation/pi04-native-links-and-public-host-readiness.md)
  owns fixture capture, commands and browser/native evidence limits.
