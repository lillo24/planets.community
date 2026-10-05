# Application navigation

- `app_router.dart` owns canonical routes, authentication redirects and branch
  replacement on account changes.
- Static `/proposals/workshop` and `/proposals/workshop/:templateId` routes precede
  Proposal-ID matching, retain the ready-session management boundary and use
  explicit Flutter Material pages. Workshop pushes share the existing outgoing
  guard, with no manual double preparation or new navigation branch. Accepted
  destinations push ordinary `/proposals/:id/edit`; URLs contain opaque IDs only.
- `app_navigation_shell.dart` owns Profile/Home/Browse tab selection and root Back.
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
