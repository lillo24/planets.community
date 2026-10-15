# Group Idea publication and retained planning

C-R05/R06 implements the founder-approved Option A from the 15 October C
package. An eligible Idea Creator requests publication with a title and summary.
Current Group managers review it; only its current Creator or Co-creator can
take responsibility as the actual Project author. Co-organizer endorsement does
not confer publication authority.

`private.group_discussion_conversions` holds one durable proposal and bound
Project per source. `request_group_discussion_publication` and
`review_group_discussion_publication` compare versions and retain exact command
receipts. The original Idea Creator can revise an unbound proposal. Deliberately
choosing `create_group_discussion_project_draft` creates a meaningful sparse
private draft with the reviewed title/summary and the actual publisher as human
author. The ordinary editor collects description and undecided logistics.
Its existing Europe/Rome draft timezone default is retained; no date/place is
invented. Opening the panel or reviewing a proposal creates nothing.

Concurrent publishers serialize on Group then room. Only one author owns the
bound draft; other reviewers see the proposal and a bound-draft conflict without
receiving its private ID. Lost delivery recovers that same draft from its receipt
or the author's authorized source projection. Role loss does not transfer a
private draft. The explicit conflict explains that its original author must
continue it; restoration of the publisher's role permits continuation. There is
no automatic abandoned-draft takeover or binding reset.

The `zzz_proposals_freeze_discussion_publication` trigger follows GRP03C's
publication guard on every source insertion/transition, including legacy
publishers. Lock order is source, Project, Group, room. It rechecks real author,
attributed Group, available source, source kind and conversion state. Any denial
rolls back publication, existing outbox/template side effects and source freeze.
The conversion marker receives its own committed room ordinal after all previous
messages/links. Source sends and normal admission then stop through C core's
`frozen_at` checks. A person who exited immediately before the marker does not
receive the later association through the retained-history projection.

Successful publication records one constant-size invitation event/intent. The
source freezes under its lock; immutable acceptance and terminal exit times
identify its exact original explicit planners. Each invitation-list read
materializes at most 50 outstanding intents for that actor, using deterministic
source/recipient identities and immutable publication-time ordering. This bounds
delivery without a Group-sized publication write or event fanout. Eligibility
excludes the actual publisher, already accepted participants, removed identities
and blocked publisher/recipient pairs. Oversight-only managers and former-only
readers are not enrolled in this audience. These are
invitations to the ordinary Project detail and Join request flow. `opened` means
only opening the invitation; neither that command nor publication writes a
Project membership, capacity reservation, delegate role or commitment. A decline
is idempotent and leaves independently authorized planning history available.
Notifications use C's targeted private event mechanism; the invitation list
contains only public Project ID/title/summary, status and cursor. It can remain
usable after Group exit without revealing private source context.

## Independent history and links

No planning message is copied, reparented or inserted into Project chat.
`get_project_discussion_origin` returns a source route only after both canonical
Project-history and planning-frontier checks. Project-only viewers receive null.
`get_group_discussion_conversion` discloses canonical Project chat identity only
when it exists and the actor independently has its history entitlement. A source
planner who has not joined receives only public Project/join context.

The implemented UI uses the package's permitted **linked read-only planning
view** fallback. A “Published as Project” panel opens ordinary Project detail or
the separately authorized Project conversation. The latter offers a freshly
authorized “Planning history” return. This is a visible continuity limitation:
the two domains are not presented as a single mixed timeline. Each existing
reader retains its own pagination, reports, unread/ACK and access revocation.
The private resolver never fetches an unauthorized room on the client's behalf.

Group/Idea links stay in their original stores. An independently entitled source
reader who is also a Project manager may select one exact link and confirm the
Project workspace audience. `share_discussion_link_to_project` locks Project
then Group/room, checks current source access plus item version, and uses the
canonical Project Add receipt. Its private receipt binds source, version and
destination so a lost reply cannot duplicate or redirect the copy. External
service permissions are unchanged. Current-link collection access is not granted
by former planning-history retention.

## Verification

`node scripts/verify-local-group-discussion-conversion.mjs` uses genuine fictional
local Auth/OTP subjects on the explicitly selected loopback stack. It exercises
member and Co-organizer publication denial, two competing publishers, recovery,
old publisher APIs, attribution changes, archive, freeze, source-only audiences,
exact zero membership/message counts and invitation replay. It never resets the
stack or prints sessions. pgTAP `145_group_discussion_conversion.test.sql` checks
grants, private records, immutable receipts and the common publication trigger.
Flutter `discussion_conversion_test.dart` replaces C04's disconnected-handoff
tests because that shortcut is intentionally replaced by the reviewed workflow.

These files specify runnable checks; actual integration/native results belong
in the cumulative C evidence report. Production/self-hosted application,
real-user sends, hosted configuration and deployment remain separate actions.
