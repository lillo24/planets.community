# Project participation

This feature owns the Flutter participation experience shared by one-time
Projects (`proposals`) and recurring Projects / Tavoli
(`recurring_activities`). The concrete discovery and content models stay in
their existing features; participation uses only a project ID plus the narrow
`one_time` / `recurring` kind adapter.

## Source map

- `domain/participation_models.dart` defines strict project kinds, request and
  membership states, private read models, and project-specific state
  derivation.
- `domain/membership_commitment_models.dart` defines the strict skill/resource
  commitment, addable-option, and merged editor-item shapes.
- `data/participation_gateway.dart` is the 05A Supabase boundary. It calls the
  canonical participation RPCs and strictly parses their narrow payloads. It
  never reads participation tables directly.
- `data/membership_commitment_gateway.dart` is the focused RPC-only 04C3C1
  commitment boundary. It owns current/final reads, addable-option reads, and
  six-argument compare-and-swap replacement parameters.
- `application/participation_controllers.dart` owns identity-bound own
  participation, requester/member commands, creator review, protected meeting
  data, request revisions, and safe failure mapping.
- `application/contribution_options_controller.dart` independently loads the
  current Proposal skill requirements plus open Project resource needs, or
  resource needs alone for Tavoli, and clears them on identity changes.
- `application/membership_commitment_controller.dart` owns membership-keyed,
  identity-bound commitment reads, editor snapshots, independent option
  failure/retry, 50/50 limits, and compare-and-swap conflict recovery.
- `presentation/participation_routes.dart` maps the shared feature onto the
  concrete Proposal and Tavolo routes.
- `presentation/project_participation_section.dart` supplies the shared detail
  location/action area.
- `presentation/join_request_screen.dart` owns typed multi-select contribution
  chips, stale-option recovery, the optional private 500-character request
  message, and the single canonical submit flow.
- `presentation/creator_participation_screen.dart` owns creator request/history
  review and current/historical membership management.
- `presentation/membership_commitment_sheet.dart` is the shared participant and
  creator commitment editor/read-only sheet, including retained stale options
  and accessible live recovery messages.

## Canonical lifecycle and privacy

All mutations carry the expected profile ID for which the screen was rendered.
After every asynchronous boundary, controllers recheck their request revision
and current Auth identity. Signing out or changing accounts clears own request,
membership, creator-review, command, and protected-meeting state. The router
also rebuilds its retained shell so unsent messages and private review screens
cannot cross identities.

The mobile client presents, but does not reproduce, the 05A state machine:

- a requester may send one optional trimmed message, withdraw a pending
  request, and retry after withdrawal or rejection;
- a current accepted participant may leave;
- ordinary leave or creator removal remains historical and does not create a
  permanent client-side ban;
- a creator may accept/reject pending requests and remove current members;
- creators are organizers through ownership and are filtered from membership
  rows.

04C3D1 tightens acceptance: the current two-argument client call can accept only
zero-selection requests. Requests with selected contributions require the
future 04C3D2 creator UI to classify every item as needed, already found, or
extra and submit the explicit triaged overload. Until that stacked layer lands,
selected requests remain reviewable/rejectable but their Accept action fails
closed at the backend.

Request creation sends canonical Proposal-skill and Project-resource-need ID
arrays through the evolved atomic RPC. Proposal options come only from its
public detail; Tavoli intentionally expose no competence options because they
have no canonical skill-requirement relation. A legitimate zero-option Project
keeps the message-only flow. Initial option failure disables submission without
discarding the message. Backend stale-option rejection reloads the canonical
options, intersects selected IDs, preserves the message, and displays only safe
localized copy.

The join form mirrors the backend's independent maximums of 50 selected
Proposal skills and 50 selected Project resource needs. At a group limit,
selected chips remain enabled for deselection while additional unselected chips
remain unavailable until space is freed; the two groups do not consume one
another's allowance.

Own requests and memberships are loaded once per identity and resolved by
project in memory, avoiding per-card RPCs. Public detail remains usable if this
private overview fails.

Successful own-participation reloads are also the narrow application signal
consumed by Proposal and Tavolo Browse controllers after request/withdraw
commands. Each Browse feature refreshes its own requester-only pending-card
projection; participation state does not import or mutate presentation models.
Successful acceptance, leave, and removal also emit the adjacent Project-chat
refresh signal. Chat controllers then re-read canonical entitlement and never
predict membership or chat visibility from a client command result.

Protected operational meeting information is fetched only for the current
creator or a current accepted participant. It is held only in the
identity-bound project controller, cleared on sign-out/account change/leave,
and never copied into public Proposal or Tavolo models, logs, or monitoring
context.

Current membership commitments are resolved by membership episode rather than
Project alone. Group info uses the current episode for a current/rejoined
participant and the latest ended episode for a former participant. Creator
member cards carry the canonical membership ID and load commitment data only
after their action is tapped, avoiding per-row fan-out. Ended memberships call
only the current/final commitment read; current memberships keep that read
useful even when addable options fail or the backend reports that editing is no
longer operational.

The editor keeps the loaded current skill/resource IDs as an immutable expected
snapshot while desired selections change. Only a successfully loaded current
options snapshot can classify an absent commitment as no longer requested; an
authoritative empty snapshot may therefore classify every current commitment,
while historical reads, loading, transient option failure, and lifecycle
read-only recovery do not infer stale status. Proven stale commitments remain
selected and can be removed or toggled back on before Save. SQLSTATE `40001`,
`22023`, and `55000` reload canonical state without automatically retrying or
merging the write. Request-attempt selections displayed in Messages remain
immutable history and are not replaced by this membership state.

## Routes

Participation stays in the Browse branch:

```text
/proposals/:id/join
/proposals/:id/participants
/tavoli/:id/join
/tavoli/:id/participants
```

These routes require authentication and a complete profile. Email OTP keeps
the exact safe internal `returnTo`; incomplete profile setup carries the same
destination in `/profile/edit?returnTo=...` and resumes it after a successful
save. The persistent bottom navigation remains Profile / Browse / Home.

Notification delivery, standalone Scambio-Dona, capacity/fullness,
participation roles, invitations, central participation history, delegated or
co-organizer commitment management, contribution verification, badges, maps,
and final unified Progetti discovery remain deferred.

## Deferred native QA notes

Comprehensive Android/iOS validation remains part of the consolidated Plan 12
pass and is not a merge gate for 05D. Useful checks for that later pass are:
request and withdraw from both detail types, return to Browse and confirm the
Requested section updates; change locality/skill filters and confirm stale
requested cards disappear; switch accounts and confirm no prior-account badge
survives; open each requested card and confirm normal detail navigation and
screen-reader announcement of “Requested to join.”

04C3B2 chip touch targets, small-screen wrapping, keyboard/message interaction,
selected-state screen-reader output, and stale-option recovery remain in the
consolidated Plan 12 native pass.

04C3C2 also defers these checks to the consolidated Plan 12 pass on physical
Android and iOS devices:

- open group info as a current, rejoined, and former participant and verify the
  correct membership episode, zero state, inline chips, edit visibility, and
  read-only copy;
- open current and historical creator member actions and verify commitment data
  loads only for the tapped row while remove-member behavior remains unchanged;
- toggle an option that is no longer requested off and back on, save a real
  removal, and confirm it disappears after canonical reload;
- exercise 50-skill and 50-resource boundaries independently, clear all, and
  confirm a no-op Save stays disabled;
- create participant/creator concurrent edits and stale-option/lifecycle races,
  then verify reload messages, reset selections, and final read-only recovery;
- switch accounts or sign out during reads and saves and verify no prior-account
  commitment state or late response appears;
- verify chip wrapping, scroll/keyboard behavior, touch targets, selected and
  unavailable semantics, focus order, and live-region announcements with
  VoiceOver and TalkBack.
