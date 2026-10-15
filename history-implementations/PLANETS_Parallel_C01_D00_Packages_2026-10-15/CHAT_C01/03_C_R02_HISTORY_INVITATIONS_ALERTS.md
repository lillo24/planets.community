# C-R02 — Full-history admission, pre-exit history, invitations and alerts

## Objective

Replace the provisional since-admission/no-former-content contract with the approved C history model. Complete both targeted and Group-scoped link invitations plus durable notices. Depends on C-R01.

## History and authorization

- An explicit Idea Join/accepted invitation grants all earlier **room** messages while current room and Group eligibility holds. General follows automatic Group access. Do not make pre-Join previews fetch complete messages and hide them on the client.
- On leave/removal/end of the actual supporting entitlement, capture a stable highest committed room sequence under the same ordering discipline as sends. Former access is read-only through its authorized cutoff, not current room data filtered using a mutable clock. Equal timestamps must be safe.
- Keep current-admission visibility and the **unread baseline** distinct. Granting old history to a newcomer does not mark every old message newly unread or deliver old alerts. Read ACK is monotone and bound to the newest actually rendered authorized snapshot, not the server's newest unobserved message.
- A former reader may open only previously entitled rooms and the appropriate historical projection. No new room title changes, current roster, edited link collection, previews, latest activity or notifications leak through historical access. An erased/suspended/disallowed identity does not bypass canonical restrictions using an old token.
- Managers' current all-room oversight ends on role loss. A valid independent room membership may remain. A previously admitted manager may retain its own bounded history; do not infer a perpetual directory for a former manager who never entered a room. Preserve safe exit and known-content report operations without requiring unrelated profile/policy completion.
- Rejoin is a fresh action. Invitation-only room membership does not resurrect from an old Group episode or replayed command. Once validly readmitted, full history is permitted under the approved disclosure. Converted origins use the frozen rules from R05/R06 rather than accepting new source participants.

## Invitations and member actions

Support target-bound invitations to current Group people and explicitly shared revocable/renewable Idea invitation links. The link grants **room** entry only to a current eligible Group person, not Group membership, Project membership, publication or manager rights. Reuse actual repository capability patterns, validate hosts/paths, never put secrets in logs/analytics, and test replay/revocation.

Invitations appear in Messages/Requests and the appropriate activity notification with clear title/purpose, sender/context and Accept/Decline. Opening, login restoration or profile completion never accepts them. Only explicit Accept or valid self-Join creates admission. Freeze actor, token/invitation, command key and intended action during uncertain delivery. Receipt replay returns the original outcome without reviving a left episode.

Room Creator/managers have the canonical invitation controls. The user also asked for a Group member to select another member and send an Idea invitation. Implement this without unrestricted membership management: in Group-visible Ideas, a current admitted member may send a targeted suggestion/invitation to another eligible Group person, which still requires recipient action; for invite-only Ideas preserve creator/manager control of access capabilities. Do not allow an ordinary invitee to issue fresh restricted-room admission grants. If existing approved invite delegation says otherwise, follow that explicit decision and document it. Treat any request to broaden restricted-room delegation as consequential rather than guessing.

Use bounded Group People selectors; never bulk download all members or reveal rosters outside the Group. A room invitation is **not** a personal 1:1 conversation. D owns the latter; expose a narrow C action contract for D's person sheet to reuse when C is present.

## Notices, preferences and hiding support

New Group-visible Ideas notify eligible current Group people/managers with allowed summary context. New invite-only Ideas notify current managers/creator and actual targets only; later link possession is not evidence of a recipient list. A target must remain eligible at delivery and acceptance.

Reuse bounded canonical outbox/projection infrastructure or implement a narrowly scoped equivalent consistent with it. Avoid unbounded writes in one publication transaction and client loops issuing messages to every member. Make projection retries/deduplication and subscriber changes testable. A queued notice cannot disclose private context after access loss; stale notification taps reauthorize.

Per-user mute, manual hide and automatic quiet-state classification are independent. Persist only the minimum validated own preferences under current authorization; prefer existing preference patterns. Muting suppresses ordinary message alerts, not membership consent or essential safety actions; preserve canonical unread. A hidden room is still eligible for its approved notices. Ended room/Group relationships stop new delivery. Provider-neutral delivery code may be completed without claiming real FCM/APNs activation.

## Validation

Use independent real local Auth actors for invitation/Join/send/leave/removal/manager-role races; equal-time frontiers; back-history visibility vs fresh unread; stale A→B→A state; old capability/command replay; Group leave and fresh rejoin; invite-only metadata leaks; expired/rotated links; Block and report evidence; already queued notices after revocation; projection retry once-only effects. Demonstrate more than one page of every new list. Keep old clients' contracts compatible.

Include tests for General with no messages, the first member, manager-only Group, and the absence of imagined recipients for an unshared link. Record focused results and next-stage UI contract; no standalone main merge.
