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
- `data/participation_gateway.dart` is the only Supabase boundary. It calls the
  canonical 05A RPCs and strictly parses their narrow payloads. It never reads
  participation tables directly.
- `application/participation_controllers.dart` owns identity-bound own
  participation, requester/member commands, creator review, protected meeting
  data, request revisions, and safe failure mapping.
- `presentation/participation_routes.dart` maps the shared feature onto the
  concrete Proposal and Tavolo routes.
- `presentation/project_participation_section.dart` supplies the shared detail
  location/action area.
- `presentation/join_request_screen.dart` owns the optional private 500-character
  request message and canonical submit flow.
- `presentation/creator_participation_screen.dart` owns creator request/history
  review and current/historical membership management.

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

Own requests and memberships are loaded once per identity and resolved by
project in memory, avoiding per-card RPCs. Public detail remains usable if this
private overview fails.

Successful own-participation reloads are also the narrow application signal
consumed by Proposal and Tavolo Browse controllers after request/withdraw
commands. Each Browse feature refreshes its own requester-only pending-card
projection; participation state does not import or mutate presentation models.

Protected operational meeting information is fetched only for the current
creator or a current accepted participant. It is held only in the
identity-bound project controller, cleared on sign-out/account change/leave,
and never copied into public Proposal or Tavolo models, logs, or monitoring
context.

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

Chat, notification delivery, resources/Scambio-Dona, capacity/fullness,
participation roles, invitations, central participation history, contribution
verification, badges, maps, and final unified Progetti discovery remain
deferred.

## Deferred native QA notes

Comprehensive Android/iOS validation remains part of the consolidated Plan 12
pass and is not a merge gate for 05D. Useful checks for that later pass are:
request and withdraw from both detail types, return to Browse and confirm the
Requested section updates; change locality/skill filters and confirm stale
requested cards disappear; switch accounts and confirm no prior-account badge
survives; open each requested card and confirm normal detail navigation and
screen-reader announcement of “Requested to join.”
