# Application navigation

- `app_router.dart` owns canonical routes, authentication redirects and branch
  replacement on account changes.
- `/help` and its contact/bug/person children are public root routes, with no
  readiness gate or new navigation branch. Help reuses the typed `/intro` replay
  API; it does not modify Auth, native invitation or editor-departure guards.
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

## UI-NEXT-02 drafts and discovery roots

Browse explicitly starts at `/proposals`. Its authenticated `/drafts` sibling
accepts contextual OR types through `?types=project,table,donate,exchange`;
empty selection means all types. Public Project/Tavolo family roots use
NoTransitionPage so controls survive a family switch without a slide/fade.
Detail/editor Material pages and the single native/draft guard are retained.
The hub belongs to the visible Browse slot. Root Back uses canonical route
matches (including imperative pushes), since a departing Material page may leave
the branch Navigator's `canPop` stale during a replacement.

UI-NEXT-03 separates the protected creation chooser (`/proposals/create`) from
the guarded scratch editor (`/proposals/create/scratch`). Owner edits/recovery
remain direct. A typed in-memory `DraftEditorOrigin.hub` allows successful Project
saves to pop to the retained hub; no external return URL is accepted.
