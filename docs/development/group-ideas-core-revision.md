# Group Ideas core revision

Authority: the approved `PARALLEL-CD-2026-10-15-v1` package supersedes the
provisional C00 access policy. This file describes the new core migration and
its API boundary; the cumulative C handoff owns qualification and merge status.

`20261015094229_group_ideas_general_and_history.sql` extends the original rooms,
admissions, invitations, messages and receipts. No planning message is copied
into a Project, and no Group right grants Project or D contact access.

## Durable records and authorization

- Each eligible published Group gets one reserved `general` room, enforced by a
  partial unique index and duplicate-safe publication trigger/backfill. Its
  title cannot turn it into an Idea; archive/conversion are prohibited.
- `community_groups.idea_creation_policy` defaults to `managers`. Creator and
  eligible Co-creator structural editors can choose `members`. Its separate
  optimistic version does not conflict with ordinary Group content edits.
- Ideas have `group` or `invitation` visibility, a 1–120 character title and
  0–500 character trimmed purpose. Ordinary Group people can discover only
  Group-visible context before explicit Join. Current managers can inspect all
  Ideas. Discussion Creators manage while currently admitted and Group eligible.
- Explicit admissions remain distinct from `group_discussion_views`, which
  records opened General/manager oversight scopes. Changing one Group role
  does not end an independent participation grant. Ending all supporting Group
  rights closes explicit admissions; role loss separately closes oversight.
- Current admitted people receive full earlier messages. Admission `frontier`
  is now the unread baseline, not a visibility cutoff. Read ACK remains a signed
  exact rendered-message frontier, monotone and unable to consume later messages.
- An ended admission captures `end_sequence` and title/purpose/Group-name
  snapshots while holding the canonical Group then room locks. A former
  oversight reader retains only the highest sequence actually fetched. Unknown
  rooms are never materialized as permanent grants for former managers.
- Existing already-ended C admissions cannot reconstruct an exact committed
  cutoff from timestamps. Their upgrade cutoff is conservatively zero. Their
  IDs and records remain intact; fresh deliberate readmission grants full
  history. This is a migration limitation, not an invented historical boundary.
- Former reads return frozen metadata and messages through the permitted
  sequence. They cannot read current rosters, edited links, previews or live
  unread/notifications. Group suppression and missing accountable identity
  continue to deny content. Erased actors cannot recover access from a token.
- Conversion sets the existing room's `frozen_at` under the same locks. Sends,
  admissions, link invitations and room edits then fail explicitly. Current
  admitted planners and disclosed current manager oversight retain their
  independently authorized planning history; Project membership never grants it.

## Invites, activity and preferences

Target invitations remain explicit Requests with Accept/Decline. Creators and
managers issue restricted-room invitations; admitted people may suggest a
Group-visible Idea to other current Group people. A target must still be
eligible and pass the existing blocking barrier when accepting.

Invitation links use opaque 256-bit tokens, stored as hashes, valid for 30 days.
They are renewable/revocable with optimistic link versions. Possession supplies
only preview context to current Group people; explicit acceptance creates a
fresh admission. It never joins the Group/Project or grants management. A replay
returns its original receipt without resurrecting an ended admission. Tokens
belong in the validated `/messages/discussions/invite/<token>` continuation,
never analytics/logs. Opening or restoring that route never accepts it.

`group_discussion_events` is a narrow durable activity outbox with identifier
payloads. `list_own_group_discussion_notices` projects bounded activity pages,
checking both current authorization and creation-time Group/source eligibility.
There is no synchronous per-Group recipient fanout. Restricted creation reaches
current eligible managers, targeted invitation reaches its target, and a shared
link invents no recipient. Notice reads are distinct from human-message unread.
These APIs do not claim FCM/APNs delivery or an activated external provider.

Own `muted` and `hidden` preferences are independent of unread. Hide is allowed
only for an unjoined eligible Idea and never hides General. Quiet classification
uses server `last_activity_at` at seven days, falling back to creation time for
an empty room. New messages resurface automatically hidden Ideas; manually
hidden rows remain available through Show hidden. Neither operation archives,
deletes, joins or acknowledges anything.

## Client interface

Legacy summary kinds and envelopes remain unchanged. Revised clients use:

- `list_my_discussion_groups_v2`, `list_group_discussions_v2`,
  `get_group_discussion_v2`, `get_group_discussion_message_page_v2` and
  `acknowledge_group_discussion_read_v2`.
- `create_group_discussion_v2`, `update_group_discussion_v2`,
  `join_group_discussion`, `get_group_discussion_settings`,
  `set_group_discussion_settings`, `set_group_discussion_preferences`.
- `create_group_discussion_invitation_link`,
  `revoke_group_discussion_invitation_link`,
  `preview_group_discussion_invitation_link`,
  `accept_group_discussion_invitation_link`.
- `list_own_group_discussion_notices`, `mark_group_discussion_notice_read`.

Existing send/invite/respond/withdraw/remove/leave names route through the revised
canonical dispatcher. Mutations keep `{room_id,object_id,version,sequence}`;
link rotation also returns `invitation_link_version`, `token`, `expires_at`.
Every command freezes actor, request UUID and full intent. Receipt recovery is
metadata evidence, never a renewed right.

V2 summaries distinguish `joined`, `general`, `oversight`, `former` and
`discoverable`; `admission_id` is only explicit participation, while `access_id`
binds the effective current/historical message scope. Former pages have no ACK
token. Private link helpers use `require_group_discussion_access` and
`group_discussion_can_manage`; `group_discussion_history_frontier` also serves
conversion origin reads and exact historical reports.

All lists use bounded stable cursors (default 25, maximum 50; messages default
30). General sorts before Ideas. A cursor identifying General transitions into
all Idea rows; an Idea cursor uses descending creation time/UUID. `p_hidden=true`
includes shown and hidden rows. Group-level Project folder composition is owned
by the subsequent workspace/integration migration.

Realtime emits a content-free `group_id` on private
`group-discussions:group:<group UUID>` to eligible current Group people.
The existing account channel handles own/direct-target/exit invalidations.
Clients subscribe for loaded Group scopes, reauthorize on hints/resume and clear
private content on identity or access loss. Hints confer no durable authorization.

## Verification

`supabase/tests/143_group_ideas_revision.test.sql` checks isolation, grants,
constraints and trigger boundaries. `node scripts/verify-local-group-ideas.mjs`
uses independent real local OTP actors for General, settings, full-history Join,
snapshot ACK, visibility, management, oversight loss, target/link consent,
revocation/replay, exact equal-time exit, hide/mute, bounded paging and freeze.
It never resets a database and requires loopback endpoints. Existing C Auth
assertions now expect full admitted history and reportability under the approved
policy; unrelated legacy projection, retry, block and revocation checks remain.

Run against the task-owned C local stack using its CLI environment and
`MAILPIT_URL`. The cumulative evidence report records actual execution results;
syntax checks alone are not database or Auth verification.

`node scripts/verify-local-group-ideas-upgrade.mjs` additionally resets only an
explicitly disposable local stack (`CI=true` or `PLANETS_DISPOSABLE_QA=1`) to the
last migration before this revision. It creates fictional old C state through
the original canonical endpoints, including immutable messages, a named link,
current and ended admissions, accepted invitations and command receipts. After
applying the remaining migrations twice, it checks every original column/row
against its pre-upgrade value, one General, stable admission IDs and full current
history without duplicated messages. This is separate from the original
main-to-C preservation verifier.
