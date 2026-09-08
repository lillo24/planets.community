# Recurring activities (Tavoli)

This feature owns the Flutter experience for Tavoli, the recurring-activity
domain introduced by 04B1. It is deliberately separate from one-time
Proposals and does not define the shared participation state machine, chat,
notifications, resources, or occurrence-level editing. The sibling
`participation/` feature adds Tavolo request/member actions by project ID/kind.

## Source map

- `domain/recurring_activity_models.dart` owns strict public, owner, schedule,
  occurrence, lifecycle, editor-input, validation, and UI-state models.
- `data/recurring_activity_gateway.dart` is the only Supabase boundary. It
  calls the canonical 04B1 public and expected-identity owner RPCs and rejects
  malformed payloads during parsing.
- `application/recurring_activity_controllers.dart` owns discovery snapshots,
  detail/owner loading, lifecycle commands, editor chains, request revisions,
  and account-switch invalidation.
- `presentation/` owns the separate Tavoli list/detail, constrained editor,
  My Tavoli lifecycle surface, and narrow recurring widgets.

## Discovery and routes

Tavoli share the existing Browse bottom-navigation branch with Proposals, but
the `/proposals` and `/tavoli` lists stay separate and use a route-backed
switcher. Tavoli own `/tavoli`, `/tavoli/:id`, `/tavoli/mine`,
`/tavoli/create`, and `/tavoli/:id/edit`. Static children are declared before
the ID route. Public list/detail work signed out; owner routes use existing Auth
`returnTo` and complete-profile guards.

Tavolo detail delegates its location/action area to the shared participation
feature. Anonymous, pending, and historical participants retain the restricted
location explanation; creator/current-member operational text comes only from
the protected 05A RPC and is not copied into Tavolo public models.

The first page, explicit refresh, or locality change captures one UTC reference
time. Every page in that session reuses it with the returned
`(next_starts_at, recurring_activity_id)` cursor. Request revisions discard
late pages from an older snapshot or filter. State is in memory only and is not
reset merely by viewing Proposals.

The reviewed public list RPC exposes its next occurrence but not the recurrence
definition. The gateway therefore enriches each bounded page through the
sanitized public-detail RPC with the same reference time and discards every
detail field except the schedule. Card models cannot contain exact meeting
text and never query owner APIs.

## Editing, time, and privacy

The editor supports one weekly weekday or one monthly day 1–28, one local
start time, duration, IANA event zone, and effective date. The shared
`core/time/event_time.dart` helper formats and converts named-zone wall clocks,
including the database-compatible `UTC` alias; device-local `toLocal()` is not
used. Invalid zones disable date/time picker actions and remain recoverable.

Draft content may be incomplete. An entirely absent schedule is sent as absent,
not synthesized. Active schedule-definition changes require a future effective
date so prior meetings retain history. When the open schedule is already
future-effective, owner `current_schedule` and `schedule_history` identify it as
pending; the editor keeps that same effective date so a correction updates the
pending version instead of adding another version.

Public cards contain only rough location. Public detail renders exact meeting
text only when the sanitized RPC returns it; participant-restricted detail uses
an explanatory message. Owner flows may render their own protected detail.

Every owner mutation carries the identity for which its form/list was loaded.
Owner providers clear and increment their revision on identity changes, and
every post-`await` continuation rechecks revision and identity. The router also
rebuilds its stateful shell on account changes, discarding retained private
forms and stacks.
