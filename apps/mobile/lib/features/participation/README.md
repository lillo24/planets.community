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
- `domain/actual_contribution_models.dart` defines strict skill/resource/effort
  attribution, source, option, and editor-item shapes without a fake effort ID.
- `domain/join_acceptance_triage_models.dart` defines composite-keyed offered
  skill/resource items and the explicit needed/already-found/extra decisions.
- `data/participation_gateway.dart` is the 05A Supabase boundary. It calls the
  canonical participation RPCs and strictly parses their narrow payloads. It
  never reads participation tables directly.
- `data/membership_commitment_gateway.dart` is the focused RPC-only 04C3C1
  commitment boundary. It owns current/final reads, addable-option reads, and
  six-argument compare-and-swap replacement parameters.
- `data/actual_contribution_gateway.dart` is the RPC-only 05C1 mobile boundary
  for factual reads, manager options, and exact eight-argument CAS replacement.
- `data/join_acceptance_triage_gateway.dart` is the RPC-only 04C3D2 boundary
  for action-local selection reads and the explicit eight-argument acceptance
  overload; it deterministically sorts all six disposition arrays.
- `application/participation_controllers.dart` owns identity-bound own
  participation, requester/member commands, manager review, protected meeting
  data, request revisions, and safe failure mapping.
- `application/contribution_options_controller.dart` independently loads the
  current Proposal skill requirements plus open Project resource needs, or
  resource needs alone for Tavoli, and clears them on identity changes.
- `application/membership_commitment_controller.dart` owns membership-keyed,
  identity-bound commitment reads, editor snapshots, independent option
  failure/retry, 50/50 limits, and compare-and-swap conflict recovery.
- `application/actual_contribution_controller.dart` owns membership-keyed,
  identity-bound actual-contribution reads, separate expected/desired sets,
  effort state, independent options failure, limits, and canonical reloads.
- `application/join_acceptance_triage_controller.dart` owns request-keyed,
  identity-bound triage loading, mandatory classification, exact partition
  construction, race-safe mutation state, and account-switch clearing.
- `presentation/participation_routes.dart` maps the shared feature onto the
  concrete Proposal and Tavolo routes.
- `presentation/project_participation_section.dart` supplies the shared detail
  location/action area.
- `presentation/join_request_screen.dart` owns typed multi-select contribution
  chips, stale-option recovery, the optional private 500-character request
  message, and the single canonical submit flow.
- `presentation/creator_participation_screen.dart` owns manager request/history
  review and current/historical membership management. Its filename is retained
  as a compatibility detail; owner and active delegate enter it through the
  shared Manage project hub.
- `presentation/join_acceptance_triage_sheet.dart` is the single manager
  acceptance surface shared by Manage participation and Messages request
  detail, including accessible validation, one-shot guidance, and
  reduced-motion-safe shake feedback.
- `presentation/membership_commitment_sheet.dart` is the shared participant and
  manager commitment editor/read-only sheet, including retained stale options
  and accessible live recovery messages.
- `presentation/actual_contribution_sheet.dart` is the shared participant
  read-only and manager-editable factual attribution sheet with a dedicated
  effort control and accessible lifecycle/race recovery messages.

## Canonical lifecycle and privacy

All mutations carry the expected profile ID for which the screen was rendered.
After every asynchronous boundary, controllers recheck their request revision
and current Auth identity. Signing out or changing accounts clears own request,
membership, manager-review, command, and protected-meeting state. The router
also rebuilds its retained shell so unsent messages and private review screens
cannot cross identities.

The mobile client presents, but does not reproduce, the 05A state machine:

- a requester may send one optional trimmed message, withdraw a pending
  request, and retry after withdrawal or rejection;
- a current accepted participant may leave;
- ordinary leave or manager removal remains historical and does not create a
  permanent client-side ban;
- a current Project manager may accept/reject pending requests and remove other
  current members, but must leave their own independent membership through the
  ordinary participant action;
- creators are organizers through ownership, while an active delegate may also
  independently be a requester or participant. Manager review keeps a real
  self-membership row visible but omits its manager Remove action.

Ownership, delegation, and participation are separate relationships. Leaving
participation does not revoke delegation, and revoking delegation does not end
or remove participation. Project detail therefore composes Manage project with
the delegate's ordinary request/current-membership actions after both canonical
reads resolve; owners remain management-only because owners cannot participate.

07C1A now creates a permanent private requester/organizer chat anchor inside each
request transaction. The optional join note remains structured request data;
later human messages are a separate immutable feed, writable only while that
exact request is pending and read-only after accept/reject/withdraw. Acceptance
may expose the separate Project group chat, but does not merge the two histories.
This feature continues to own request creation and resolution; 07C1B owns the
mobile request-conversation presentation and live refresh.

04C3D2 routes both manager Accept entry points through one action-local triage
sheet. The sheet reads only the tapped request, requires an explicit needed,
already-found, or extra decision for every offered item, and always calls the
D1 eight-argument overload. Zero-offer requests use the same contract with six
empty arrays. No production mobile two-argument acceptance helper remains.
Reject and requester Withdraw retain their existing direct paths.

Incomplete submission never calls the backend. Every undecided composite item
gets an error border, semantic error, and one short validation-pulse shake; the
first incomplete attempt also opens one accessible guidance tooltip for that
sheet lifetime. `22023` keeps decisions visible for review because current
Project needs changed. `55000` makes the request terminal, while `42501` and an
account switch clear private triage data. Successful acceptance closes the
sheet, emits the Project-chat refresh hint, and makes each caller reload its
canonical participation or Messages projections rather than predicting member
or commitment state.

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
Project manager or a current accepted participant. It is held only in the
identity-bound project controller, cleared on sign-out/account change/leave,
and never copied into public Proposal or Tavolo models, logs, or monitoring
context.

Current membership commitments are resolved by membership episode rather than
Project alone. Group info uses the current episode for a current/rejoined
participant and the latest ended episode for a former participant. Manager
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
selected and can be removed or toggled back on before Save. SQLSTATE `PT409`,
`22023`, and `55000` reload canonical state without automatically retrying or
merging the write. Request-attempt selections displayed in Messages remain
immutable history and are not replaced by this membership state.

Actual contributions are shown only for one-time Projects. A participant opens
them from Project chat → Group info and receives one read-only action or a
newest-first episode list when they rejoined; opening one episode performs only
that membership read. A manager opens the same sheet from Manage participation
on the exact current or historical member card. Member lists and episode lists
never fan out attribution reads.

The actual-contribution editor sends the loaded effective skill/resource/effort
set as an immutable expected CAS snapshot and the visible draft as desired
truth. Options are unioned by kind plus ID so equal UUID text across kinds does
not collide. Skill and resource maximums remain independently 50; effort does
not consume either allowance. SQLSTATE `PT409` and `22023` reload both factual
state and options, discard the stale draft, announce the recovery, and never
resubmit automatically. `55000` becomes localized lifecycle-unavailable copy,
while identity changes clear state and reject late responses.

## Routes

Participation and Project management stay in the Browse branch:

```text
/proposals/:id/join
/proposals/:id/participants
/proposals/:id/manage
/tavoli/:id/join
/tavoli/:id/participants
/tavoli/:id/manage
```

These routes require authentication and a complete profile. Email OTP keeps
the exact safe internal `returnTo`; incomplete profile setup carries the same
destination in `/profile/edit?returnTo=...` and resumes it after a successful
save. The persistent bottom navigation remains Profile / Browse / Home.

Notification delivery, standalone Scambio-Dona, capacity/fullness,
central participation history, contribution verification, badges, maps,
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

04C3D2 also defers these physical-device checks to Plan 12:

- verify bottom-sheet sizing, long labels, and three-option wrapping on narrow
  Android and iOS screens;
- verify the validation shake is subtle, non-looping, and absent when reduced
  motion is enabled while the border and semantic error remain;
- verify tooltip positioning plus TalkBack/VoiceOver item, disposition, error,
  keyboard, and focus order behavior;
- exercise both creator Accept entry points, a zero-offer request, Project-needs
  change rejection, and an account switch while the sheet is open.

05C2 also defers these physical-device checks to Plan 12:

- verify actual-contribution sheet sizing, long labels, 50-option scrolling,
  text scaling, keyboard/focus order, and TalkBack/VoiceOver semantics;
- exercise participant single- and multiple-episode paths plus creator current
  and historical membership editing without per-row preload;
- verify the pre-end informational state, CAS conflict/options recovery, and an
  account switch while the sheet is open.
