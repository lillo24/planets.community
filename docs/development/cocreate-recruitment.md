# Structured recruitment (D01)

[COMM01/FILL01](cocreate-fill01.md) adds dated requests and explicit refilling on
this same domain. Legacy unscheduled cards retain this nine-field reader and
behavior. New scheduled cards carry an immutable meeting instant, use separate
attendance capacity, and queue bounded in-app General notifications. The mobile
manager now schedules dated requests; existing installed commands/readers stay
compatible. New clients use review v2/feed v3 for dated cards; installed readers
keep nine fields and a non-actionable placeholder for such requests, preserving
history/ACK while requiring an updated client to display time before Join.
External push/provider delivery is not activated.

The current numbered-group creator can deliberately post one active structured
card into that group's hub General. A card is an immutable room message plus a
separate private recruitment reference/lifecycle row; it never rewrites human
messages. Creation of both circular references uses deferred foreign keys in one
transaction. Direct table access is revoked and RLS enabled.

The experimental private defaults are a per-room 3,600-second cooldown (bounded
60–86,400) and seven-day expiry (bounded 1–30 days). Expiry is a live query state,
not retention or an automatic reposting job. Reopening a seat updates the existing
card's availability and posts nothing. Retraction names the exact recruitment ID
and remains an identity-only own cleanup when the gate is OFF. Legacy unscheduled
cards create no push or durable notification. Room message abuse limits still include structured
inserts; human unread explicitly excludes them.

`mutate_cocreate_recruitment` serializes post/retract with the actor and hub locks,
requires current creator/episode for posting, and binds immutable command intent.
`join_cocreate_recruitment` binds the card ID too, checks expiry/retraction under
the same hub lock, and calls C03's canonical join. It takes the same sorted
Auth/profile, actor, blocked-pair and hub locks before that call. Exact receipts
identify anchors, never substitute for fresh authority. Full, archived,
suppressed, expired or retracted sources cannot grant a new admission.

`get_cocreate_room_page_v2` renders distinct human/recruitment entries, adds only
admitted sender display names (unavailable accounts have no name), and retains
actor/room/episode/exit-sequence scope. Legacy human-only pages keep their exact
shape and issue a newest-human frontier; mixed pages use the actual visible
frontier. Both ACK through the existing HMAC/episode boundary. Contact payloads
remain human-only. An exact card review reader checks its source General and
history cap; a staff role alone grants neither reader.

Discovery resolves current public occupied/capacity and state instead of trusting
the immutable body. Suppressed/archived destinations reveal no current counts.
Metadata-only signals to current General members cover card state, seats,
capacity and lifecycle; child chat sends do not signal General through this
extension. A ten-second open-chat HTTP refresh also rechecks time-based expiry.
Scoped reports add only the exact card snapshot; unrelated human report shape,
staff rules and immutable evidence remain intact.

Mobile settings expose explicit posting/retraction. General shows a distinct
card and a review action; review discloses the child's history and requires an
explicit canonical join. An uncertain join retains its exact retry even after
the canonical card becomes full. No preview or source title enrolls anyone.

Reproduce on the owned disposable backend with
`npm run cocreate:recruitment:verify:local`. The verifier temporarily activates
only that local stack and restores OFF. It covers concurrent exact posting,
one active card, a genuine two-account last-seat race, stale/full/expired/
retracted sources, removal, reopening without repost, exact retry, human unread,
legacy pages, report snapshots and gate-OFF own retraction.
