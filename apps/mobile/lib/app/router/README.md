# Application navigation

- `app_router.dart` owns canonical routes, authentication redirects and branch
  replacement on account changes.
- Its `_NativeRoutingConfig` composes native validation/deduplication with the
  single draft coordinator. Ordinary routes retain `onEnter` while an editor
  owns departure; startup without an owner keeps synchronous Auth restoration.
  New external arrivals prepare that same editor once, and committed callbacks
  deliver draft feedback and cancel external auth continuation together. Blocked
  or superseded transitions run neither callback. Duplicate current links keep
  the existing OTP/profile form and continuation. Actor changes invalidate replay.
- `native_project_links.dart` owns the public HTTPS URI allowlist and safe
  canonical destination normalization; it never performs admission.
- Static `/proposals/workshop` and `/proposals/workshop/:templateId` routes precede
  Proposal-ID matching, retain the ready-session management boundary and use
  explicit Flutter Material pages. Workshop pushes share the existing outgoing
  guard, with no manual double preparation or new navigation branch. Accepted
  destinations push ordinary `/proposals/:id/edit`; URLs contain opaque IDs only.
- `app_navigation_shell.dart` owns the stable Profile/Home/Browse branches and
  root Back. Its visible right tab follows main's device-local Messages/Browse
  preference and the actual active destination; editor departures still use
  the single draft coordinator.
- `draft_departure_coordinator.dart` prepares the active Proposal editor before
  router transitions/pops and delivers confirmed destination feedback through
  the application's ScaffoldMessenger.

The editor registers its identity-bound preparation callback; navigation does
not own Proposal fields or persistence. See the
[draft-departure contract](../../../../../docs/development/proposal-draft-departure.md)
for raw input, retry/cover outcomes, retained sessions and forced-auth behavior.

SIM02 suggestion selection first removes the modal overlay and restores the
editor as the active departure owner, then performs one ordinary detail push.
The existing guard alone prepares the draft; sheet cancellation never prepares
it. See [automatic suggestion handoff](../../../../../docs/development/automatic-editor-suggestions.md).
