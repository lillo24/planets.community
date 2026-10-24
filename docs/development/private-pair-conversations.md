# A1 Private person conversations

Authority: [the approved handoff](../../history-implementations/PLANETS_A1_unified_private_conversations_codex.md)
and [ADR 0009](../architecture/decisions/0009-universal-private-pair-conversations.md).
This is one backend/mobile change. It does not include DE1 or UIAUDIT02.

## Source ownership

| Source                            | Read authority                                                                                                          | Exact send context                                                                                                       | Management / evidence                                                                         |
| --------------------------------- | ----------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------- |
| Project/Tavolo participation pair | Immutable endpoints through the existing pair predicate; retained legacy authors and request associations survive       | Selected canonical request, through the retained request-scoped writer and its manager-interaction/Project/request locks | Original Requests details, triage, source message UUIDs and audit                             |
| Scambio-Dona                      | Existing accepted request/listing endpoints; completed/cancelled history remains readable                               | Exact Resource chat, through the existing agreement lock and writer; its accepted-coordination block exception remains   | Original Resource request/agreement workflow; `resource_chat_message` report UUID             |
| Personal member contact           | Existing pair/episode message-readable predicates, including frozen ended history                                       | Exact pair and current consent episode; original Group/identity/block locks and command owner                            | Existing member info, close/leave/mute; `member_contact_message` UUID and source chat context |
| Accepted Find People contact      | Current server gate, actor eligibility and policy, available endpoints, unsuppressed post and symmetric block predicate | Exact accepted post contact; original command, rate limit and contact lock                                               | Existing contact management/own-close routes; `cocreate_contact_message` UUID                 |

Current account availability reuses the canonical Auth/profile availability
predicate, which has no experiment or policy gate of its own. A banned, deleted,
anonymous or incomplete endpoint is not projected. The Find People gate and policy
are additionally applied only to its sources. Account/policy hints scrub warm
projections before reread. Historical member contact remains visible exactly when
the original member history reader permits it; A1 does not invent a new lifetime
policy or resurrect an episode after re-entry.

There is no generic DM, new public contact action, global transcript or competing
send authority. Project group chat, registered-Group discussions/Ideas,
representative group contacts, community rooms and multiparty coordination retain
their owners and Groups scope.

## Versioned backend contract

Migration `20261024105936_a1_unified_private_conversations.sql` adds:

- `list_own_private_pairs_v1`: one authorized other profile before keyset paging
  by `(activity_at DESC, peer_profile_id DESC)`, default 20, maximum 50. The stable
  `pair_key` is the sorted UUID tuple, never a name. Activity includes authorized
  source transitions. A context update has its own preview discriminator rather
  than masquerading as human text. Latest human attribution retains actual authors.
- `get_own_private_pair_page_v1`: at most 50 original human messages/context
  cards per page, ordered by `(created_at DESC, item_kind COLLATE C DESC, item_id
DESC)`. All cursor fields are required together. Each indexed source is bounded
  before the merge. The client displays 30 and uses one lookahead item. Original
  request/contact creation cards display current authorized status; detailed
  action history remains under the domain owner.
- `list_own_private_pair_contexts_v1`: independently bounded context pagination
  by `(kind COLLATE C, id)`, with an optional writable-only filter. A focused
  exact-source resolution also returns its own context even beyond the initial
  context page. No request notes or private contact details enter the list.
- `resolve_own_private_pair_v1`: authorizes an exact typed source before returning
  the peer and source focus. Missing/denied sources fail identically. A manager
  without endpoint permission can still use the exact original Requests details;
  another valid source is never substituted.
- `get_own_private_pair_unread_v1`: distinct unread peers plus unchanged Groups
  totals. Existing source summaries and acknowledgements are untouched.
- `send_own_private_pair_message_v1`: immutable actor/command/peer/context/episode/
  submitted-body receipt. It invokes the original domain writer, preserving
  original message IDs, source-specific rates, outbox and audit. Participation
  sends use the explicitly selected request's retained writer; they cannot choose
  a different pending Project after closure. Original body bounds remain 4,000
  characters, or 2,000 for Find People.
- `acknowledge_own_private_pair_v1`: a newest token and 1–200 original message keys
  per call. Tokens expire after seven days and are reused for unchanged bounds.
  Every supplied key is reauthorized against its own source and snapshot bound.
  Only the rendered contiguous incoming prefix advances an original frontier.
  An offscreen earlier unread message prevents a later message from swallowing
  it. This conservative rule can leave a visible later message unread until its
  earlier unread gap is rendered. Backscroll can record rendered keys in RAM;
  acknowledgement waits until the latest unobscured foreground boundary.

Private helpers have no client/service grants. Both new metadata tables have RLS,
no raw API grants and no account foreign keys. Source message tables, source
ordinals, domain reader/writer bodies, installed function OIDs/ACLs, notifications
and evidence identities are not rewritten. The existing reviewed account/profile
metadata hook gains exactly one call to A1's identifier-only invalidation helper;
its contact/room behavior and Auth trigger definitions remain intact. The
populated proof verifies that exact extension and every other original body.
New native sender hints address the sender's own other devices;
incoming hints retain their existing owner. There are no additional alerts or
body broadcasts.

## Mobile ownership and lifecycle

`messages/domain/private_pair_models.dart` validates the new complete payloads,
namespaced original message keys, order and immutable send intent.
`messages/data/private_pair_gateway.dart` owns only A1 RPC transport and consumes
the existing shared own-account subscriptions. The pinned Realtime SDK evicts
duplicate topic subscriptions, so A1 never opens competing channels.

`private_pairs_list.dart` owns the independently paged Private list, authorized
batched photos and explicit complete loading/empty/failure states.
`private_pair_screen.dart` owns the mixed lazy timeline, context cards, one
composer, source selection and retained exact retry. The original source routes
resolve into it. Requests and member info remain in their original owners;
Resource agreement progression and Find People management have management-only
routes with no second transcript, composer or read acknowledgement. Resource
management also links to its exact original request details.
Identity-only Find People contact close recovery remains in Requests alongside
interest withdrawal when the experiment is OFF or policy is stale. It exposes no
peer, post title, transcript or unread count and retains its exact own-exit route.

One writable context is selected transparently. Multiple contexts require a
choice, except for an authorized exact-source entry. Lost selection cannot switch
an existing draft silently. Ambiguous network replies keep the immutable command
and raw draft. Explicit transaction rejection keeps the draft and requires fresh
context selection. Account/realm replacement clears private state and pending
intent. Ordinary read/send failures do not clear user-entered text. The page's
`has_resource_coordination` flag preserves the existing accepted-Resource block
confirmation even when that context is outside the first context page.

Foreground refresh retains the loaded history window and reading position. An
authorization scrub removes protected widgets immediately, then restores only a
layout origin and scroll anchor after authorized content is fetched again. These
identities contain no message content and reset on account/realm replacement.

Only actual viewport-intersecting human widgets at a settled latest boundary are
recorded as rendered. Initial zero-origin layout is excluded. Shared
`MessageReadViewport` retains foreground/latest/route/sheet checks and exact
failed-token retry. Lists, context cards, older scrolling and covered routes cannot
read other source transcripts. Missed hints are reconciled on reconnect/resume and
with a 20-second foreground authoritative refresh. Private state stays in RAM.

## Qualification and rollout

Use the [owned A1 tools](../../scripts/a1/README.md). The populated rehearsal
compares every original Auth/Storage/public/private row and column plus installed
function bodies, OIDs and ACLs, then runs the actual local CLI forward migration
and no-op retry. pgTAP runs against a separately fresh replay; populated public
fixtures are not an appropriate empty-catalog test baseline. Real OTP/HTTP checks
cover all four source domains, two People posts, actor/delegate/gate/account
denials, exact retry, source-specific ACK and an observed closure/send lock race.

Required Validation and the existing independent populated migration policy still
govern source merge. Unknown privileged hosted effects require their existing
hosted review/contract; A1 does not post an owner approval or weaken that policy.
Apply the compatible backend before deploying this client. Missing A1 RPCs fail
explicitly; no client-side reconstruction from old pages is provided. No hosted
write, experiment activation, provider setup, store submission or installed-build
rollout is implied by a source merge or local/native verification.
