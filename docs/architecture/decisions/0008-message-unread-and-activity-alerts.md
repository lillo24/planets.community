# 0008 — Private message unread state and activity alerts

- **Status:** Accepted
- **Date:** 2026-10-06

## Decision

Human messages alone contribute to unread. The account badge counts distinct
authorized conversations; rows count incoming messages. Participation pairs,
Project groups, and request-scoped Resource chats retain their existing identities
and authorization. Requests and system events remain independent activity.

Original messages stay untouched. Private metadata identifies each source by
kind and UUID and assigns a per-conversation ordinal under a row lock acquired
after the existing interaction/Project/request locks. Every supported writer
uses the same insert trigger. The lock is held until commit: an invisible delayed
transaction cannot later commit behind a visible snapshot frontier. Readers and
acknowledgements never lock/create stream rows or acquire domain locks. Even an
empty conversation can issue a zero boundary without waiting for an invisible
writer; the first later commit acquires ordinal one.

Incoming recipient eligibility is recorded at send time. Group first admission
and re-entry do not create receipts for historical backscroll or the interval
without entitlement. Existing eligible unread may remain when still readable.
Current canonical history authorization also filters every count and read.
Losing send permission alone does not clear readable unread.

The migration locks all human-message sources while establishing a one-time
metadata baseline and installing triggers. Existing history has no unread
receipts; this baseline asserts no actual read. Later sign-ins, reads, restarts,
and demo reruns never move it. A rollback rolls metadata and receipts back too.

Newest history pages return a private, identity-bound snapshot token alongside
the feed in one database snapshot. Acknowledgements advance only through that
token's ordinal, monotonically and idempotently, after successful rendering and
reaching the latest content in the foreground, unobscured conversation. Tokens
are own-state only, expire after seven days, and never appear to counterparties.
Older pages and previews issue no read boundary. Failed acknowledgement retains
the token for explicit retry; clients refresh canonical totals after success.

One private account topic carries only the recipient profile identifier. Sends,
acknowledgements, and access changes invalidate authoritative summaries; signals
are never counter deltas. Account changes dispose the subscription and reject
late work. Resume/reconnect and burst coalescing recover missed hints. Recipient
selection occurs at send time, protecting warm revoked sockets independently of
join-time topic authorization.
Membership/delegate invalidations target only the affected actor and Creator,
so admission work does not grow quadratically with existing group size.

Ordinary Project and Resource message events retain source/audit and shared push
resolution. The in-app projector consumes them as suppressed outcomes. Old message
notification rows remain intact but are excluded before inbox pagination, bell
counts, and mark-all. Exact historical notification reads remain own-only and
never acknowledge chats. Stored in-app and hidden push preferences are preserved;
the obsolete Chat in-app setting is removed from mobile.

## Rollout

Apply the forward backend migration before deploying the updated client. Older
clients retain request-scoped feeds and activity APIs but acquire no message
badges or read acknowledgements. Consequently new unread persists until an
updated client reaches and acknowledges it. No hosted migration or deployment is
authorized by this implementation.
