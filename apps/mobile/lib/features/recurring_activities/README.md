# Recurring activities (Tavoli)

Draft Tavoli remain editable without a profile photo. Publishing performs a
local trust preflight, while `publish_recurring_activity` authoritatively
requires a current canonical photo only for the draft-to-published transition;
`public` and `interactions` both qualify. Public detail loads the organizer
avatar through the separate Project-context boundary, with a safe placeholder
on missing legacy data or delivery failure.

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
  requester-only Requested enrichment, detail/owner loading, lifecycle commands,
  editor chains, cover-before-publish reconciliation, request revisions, and
  account-switch invalidation.
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

For a ready authenticated identity, the first page also loads one bounded
own-pending Tavolo projection using that same reference time and locality. Its
sanitized rows include schedule metadata directly, avoiding detail-per-request
enrichment. Requested cards render first and are visually deduplicated from raw
public pages without changing their cursor or `hasMore`; signed-out sessions do
not call the personalized RPC. Account, filter, and participation revisions
clear or refresh the private projection independently of public-feed errors.

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

Drafts may also omit registration capacity, while publication requires
1–100,000 spots. The editor persists the default-off choice for whether the
Creator and active organizers use spots. Public cards and detail render
ordinary-participant usage, organizer breakdown, unique people involved, Full,
or the legacy “Registration capacity not set” state. The Creator and current
Co-creators can change both settings on active/paused Tavoli but never to a
combination below current derived usage; a legacy active/paused Tavolo must
receive capacity on its next structural save. Ended Tavoli retain the settings
as read-only history. Capacity applies to the membership pool, not each
occurrence.

Public cards contain only rough location. Public detail renders exact meeting
text only when the sanitized RPC returns it; participant-restricted detail uses
an explanatory message. Owner flows may render their own protected detail.

Every owner mutation carries the identity for which its form/list was loaded.
Owner providers clear and increment their revision on identity changes, and
every post-`await` continuation rechecks revision and identity. The router also
rebuilds its stateful shell on account changes, discarding retained private
forms and stacks.

When centrally gated demo tools are enabled, only the Tavolo create form offers
a synthetic, publishable weekly preset. It mutates local form state without
saving; Tavolo edit screens never expose the action.

The sibling `cover_media/` feature supplies Tavolo's optional 16:9 editor,
normalizer, canonical Project-cover reconciliation, and path-keyed display.
Selection and removal remain local until Save/Publish. A new Tavolo draft is
created before upload, and publication runs only after cover reconciliation;
partial cover failure retains the same draft for retry. Cards and details use
the cover path already present in canonical Tavolo reads, never metadata RPCs.

09B2 composes the separate blocking feature on Tavolo organizer detail without
filtering the public Tavolo or changing current Project membership/chat access.

The same exact-record editor serves the immutable Creator and current
Co-creators for non-draft Tavoli. Active and paused Tavoli use **Save changes**;
the editor also owns the canonical pause, resume, and end transitions and
refetches that Tavolo after each mutation. Ended Tavoli are read-only.
Co-organizers receive no structural editor or lifecycle controls, and another
Creator's draft remains unavailable to a Co-creator. Draft creation and
publication stay original-Creator-only.

Ending is a retained-history lifecycle transition, not deletion. Editing,
pausing, resuming, and ending do not alter participation or delegated
authority. Successful mutations refresh owned, delegated, and affected public
state. A backend authority denial invalidates cached management/delegated state
and removes the editor controls; account revisions continue to discard late
responses.
