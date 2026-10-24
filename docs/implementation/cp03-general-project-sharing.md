# CP03 — Public Projects shared in Community General

Dependency: merged CP02, PR #331 (`5dfe4e61`). The current General send operation
already serializes episode authorization, throttling, immutable intent receipts,
read tokens and moderation. A share therefore uses an ordinary human message
containing exactly `https://planets.community/proposals/<uuid>`. No schema,
message version, privileged operation or second association directory is added.
Older clients retain a usable public link. No title or other snapshot is stored.

General's Share Project action reuses native public discovery in a narrow picker
mode. Native create, map/family switching and owner actions are absent in that
mode; native discovery remains unchanged elsewhere. Choosing does not send.
Unsent prose must be sent or cleared first. Selection and each new share send
re-read the canonical public-detail operation and remain bound to the original
actor, live General episode and review generation. The selected first-party
share skips the ordinary arbitrary-link education dialog. Typed/pasted URLs,
prose, invitation URLs and unrelated domains retain ordinary link review.
Existing frozen delivery/completion retries retain their original intent.

The receiver resolves only the current public title, never an owner/private
read, cached message-time content, exact location, roster or invitation. Ordinary
General refreshes rebuild public previews; explicit open revalidates again
before opening native detail, which owns its own participation authorization.
Missing/cancelled/hidden content is unavailable; failed reads show a retry and
discard the prior title. Account/episode changes and stale asynchronous results
cannot retain a previous preview. Numbered-room rendering remains unchanged.

A cancellation after send validation can leave an identifier-only link, with
an unavailable preview. There is no cross-domain transaction or claimed
association/enrollment: existing room writes and public-detail reads each keep
their canonical authorization. A shared URL grants no membership, DM, creator
authority or Community ownership.

Validation covers strict first-party parsing, picker/send/open, unavailable and
failed public reads, cancellation and identity/revision races, immutable retry,
ordinary link review, General authorization/read/unread/pagination/moderation,
native discovery and IT/EN narrow-screen rendering. Required Mobile CI passes
before merge. CP05 adds genuine cross-persona integration and native captures.
Rollback: revert CP03; retained human links remain backward compatible.
