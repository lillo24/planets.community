# D-M01 — Canonical Group-member conversation requests and private chat

## Objective

Implement D-M00's resolved member-contact state machine, reusing the repository's narrow messaging/receipt/read infrastructure where it genuinely matches. Do not broaden representative or Project request permissions. Runtime source remains review-only for any unresolved D-M00 history/lifetime rule.

## Request and consent

Authenticate the expected real actor, verify the selected Group and both people's canonical eligibility, and enforce Block/rate/deduplication rules server-side. Only the named target may accept/decline. Targeted request previews disclose only the approved sender/shared Group/context/note and no unrelated roster or hidden profile/photo fields. Own withdraw and known-request reporting remain usable through their safe contracts.

Request creation must not create a Project, Group membership, delegate role, Idea admission, empty public profile or free-form conversation with unsolicited messages. Accept atomically creates/reuses only the approved member-pair conversation/admission episode and the receipt. Return current and historical state separately.

Handle simultaneous reversed requests, duplicate Accept, lost response, expired/withdrawn/declined request, Group leave/role loss during lock waits and account deletion. Freeze command identity and exact intent; never create two conversations by allocating a new key after uncertainty. Avoid new actors or membership state in JWT/user-editable metadata.

## Message and lifetime rules

Keep member contact a separate typed conversation kind or equivalently isolated canonical authorization owner. Reuse pure transport/feed UI primitives where possible; do not copy grant semantics from D. Enforce the chosen current/retained-history predicate across list/preview/body/latest activity/people/unread/ACK/subscriptions/exact message reads. An original request's UUID is not permanent authority.

Each message is immutable human-authored text under the repository's current messaging contract. Apply bounded history with a deterministic tie-breaker/sequence, genuine incoming-human unread and foreground snapshot ACK. Back-history access on re-entry, Close and loss of Group context follows the approved M00 rule. Do not choose between active-after-exit and read-only-after-exit merely to get tests green.

## Delivery and safety

Provide actionable member-contact requests in the canonical Requests surface and a clear activity notification using existing delivery facilities. New human messages follow approved notification/mute behavior without adding copies to the activity inbox contrary to the existing message-alert separation. Hidden/collapsed UI is not unsubscribe or read. Former/ineligible recipients receive no notices beyond the approved lifetime contract; queued delivery rechecks eligibility.

Private realtime emits minimal recipient-authorized invalidations, not message content to a shared Group channel. Group managers cannot subscribe to members' personal conversation bodies. Account/role/membership changes clear private caches and invalidate old request/read tokens. Late A→B→A results do not restore prior state.

Block/Report must exist before release. Preserve exact case-bound evidence and known-content reporting after the user's read grant ends, without rereading all chat contents. Do not assume an unmerged suspension/retention subsystem exists; integrate canonical merged controls and document remaining independent rollout work.

## Compatibility, migration and evidence

Forward migration with least-privilege explicit grants/RLS and no new public roster APIs. Preserve existing Group, C, representative, Project/Resource and request records. Stable IDs, raw provenance and no new account-deletion blockers unless deliberately approved. Regenerate types, add bounded real-Auth/SQL tests and populated upgrade fixtures. Test a member who is also a manager so personal/representative scopes cannot be confused.

Acceptance corpus: two legitimate current Group people, outsider, pending Group applicant, former person, co-manager, staff, blocked pair, two shared Groups, role/membership changes, duplicate/reversed request and accept, several pages, old client, received-note report and lost response. Include explicit **manager cannot read another member's 1:1 chat** checks even while that manager may read all C Ideas.

No paid provider, encrypted-message architecture rewrite, external file access, real-user messages or hosted operations.
