# Contact activity notices and mute

This is the D-R03 synthetic review implementation. The audience and lifetime
rules remain subject to the decision ledger in
[group-contact-parallel-handoff.md](group-contact-parallel-handoff.md).
It does not authorize a hosted migration or real-user rollout.

## Ownership and contracts

`20261015095248_group_contact_activity_and_preferences.sql` owns private activity
projections and representative conversation preferences. Member request eligibility
belongs to `private.member_contact_notice_allowed`, in the member domain. Existing
Project, Resource and Matching projection logic remains in its original worker.

A pending representative request, coordination audience version or named member
request emits one durable outbox event. The installed notification worker expands
at most 25 candidates per contact event page, with a durable UUID cursor. An event
receives its `notifications.v1` completion receipt only after its last page. The
public worker's `processed_count` is work pages for contacts and source events for
legacy kinds; a worker must continue until it receives zero. Its total event/page
budget is still `p_limit` (1–100). At limits above one, at most half is reserved for
contacts, leaving room for legacy events. Limit one services contacts first.

`20261015110945_contact_activity_canonical_projector.sql` restores the established
public projector's original function identity and composes the contact budget
inside it. The legacy resolver loops, event families, receipt locks, Matching
conflict semantics and message/activity separation keep their canonical owner.
No parallel legacy-worker function remains. The populated member upgrade verifier
checks the warmed worker OID as well as existing data and Block identity.

Contact rows have a unique source-event/recipient identity. Projection retries
cannot duplicate rows. Projection respects the existing Participation in-app
preference; it does not enable a new category or provider channel. Coordination
versions supersede earlier notices. Accepted, expired, denied or inaccessible
requests are removed by authorization filtering before paging/counting, including
already-projected rows. The tables are private with RLS and no client table grants.
Raw actor UUID provenance does not create an additional Auth-deletion foreign key.

The additive `list_own_notifications_with_contacts` and
`get_own_unread_notification_count_with_contacts` endpoints compose legacy notices
with current authorized contact notices. Legacy readers never receive new kinds.
The corresponding `mark_contact_or_legacy_notification_read` and
`mark_all_notifications_with_contacts_read` commands reauthorize contact targets.
Each contact payload contains only its kind, own notice ID, typed target ID,
creation/read time and category: no note, roster, source chat, token or actor name.
Mobile opens the canonical typed request route; that route reauthorizes again.

Contact access hints clear cached contact rows and stale load/mutation epochs
before rereading, even offline. Legacy rows can remain while the contact refresh
fails explicitly. Ordinary message refresh hints only revalidate the inbox; they
do not revoke a valid identity or cancel an activity read mutation. Account changes
clear the entire actor-bound state.

## Mute and message separation

Representative mute is per actor/conversation, defaults to false, and uses the
existing exact-intent receipt/recovery protocol. It changes only message-alert
eligibility. It does not acknowledge messages, alter unread totals, hide history,
unsubscribe realtime, or suppress actionable pending invitations. The info screen
loads the preference independently and never renders an assumed value after a
failed read. Member mute has the same separation in its owning domain.

`private.group_contact_message_notice_allowed` and the member-domain equivalent
combine current sending eligibility with mute. They are the required delivery-time
gate for a configured future message-alert worker. Ordinary messages do not create
activity-inbox copies. This source change does **not** configure external OS push;
neither a stored preference nor emulator evidence proves provider delivery.

## Verification

`contact_notifications_test.dart` covers minimal typed routes and malformed or
leaking payload rejection. `notifications_controllers_test.dart` covers offline
invalidation and delayed mutation rollback. `contact_screens_test.dart` covers
info/mute without ACK and exact-intent retry. Database tests separately qualify
bounded fanout, duplicate projection, preferences, superseded access and private
grants. Final executed commands and limitations belong in the D handoff evidence.
