# C01 — Private internal Group discussions: canonical backend

Read C coordinator and C00 decision record. Start from verified C00 stack head. Use the accepted C00 contract; if provisional, isolate all development/fixtures on a **review-only draft stack**, with no main/shared activation.

## Outcome

Persistent Group owners/managers can create bounded, private named discussion rooms following the precise C00 rights. Invited entitled members can explicitly accept and exchange text, read only their authorized history, and leave. Current Group People, Project participants, managers and private room membership are separate relationships.

## Suggested domain boundaries

Inspect current migrations, GRP03A/B roles/episodes/commands, group status/archive/suppression and lock order; Project chat and participation-pair message transport; account deletion, block/report, canonical unread and Realtime patterns. New schema must have its own Group/room/member/admission/message identities rather than masquerading as a Project or a Resource chat.

Make canonical RPCs for:
- Create a named room with explicit Creator admission and frozen actor/Group/request identity.
- List my Group rooms and exact room context in bounded pages.
- Invite/accept/decline/withdraw/leave and manager removal, if authorized by C00, with immutable admission episodes/frontiers.
- Send text, paginate readable messages backwards using stable (created_at,message_id) or repo-established compound cursor, and archive/rename under live approved authority.
- Canonical room summary/unread/read acknowledgement only when current entitlement permits it.
- Bounded, actor-scoped report/evidence integration and safe identifier-only invalidation signals.

This is not permission to build an extensive Slack-like permission/membership engine. Prefer the smallest entities/commands consistent with accepted behavior.

## Durable authorization and privacy

Bind the expected personal actor to verified Auth, live group state, canonical current Group role/membership and current room invitation/admission. Check post-lock eligibility on every send, invite, management command and sensitive reread. Deny guessed room IDs exactly as unrelated IDs. Room association does not grant Group structural editing, Group project publishing, public profile access or Project chat entitlement.

Room access may be narrower than Group People. Accepting group membership or Project participation never equals room invitation acceptance. Retained historic admission may be audited, but current access and unread must not be inferred from prior episodes. On Group leave/removal/manager revocation, deny room list, messages, unread, read acknowledgement, preview and private Realtime content even if old sockets survive. Make relationship episode binding explicit to prevent rejoin restoring stale access. Current account deletion/suppression handling must remain authoritative.

Persist immutable human message authorship and group/room provenance without making protected data cascade-block account erasure. Follow existing moderation and blocking semantics; if blocked pairs make group send ineligible, reuse canonical checks rather than inventing a new block policy. Staff need explicit report evidence, not generic room browsing.

Message text is untrusted; bound size/Unicode requirements follow existing chat conventions. Room title, invites and commands have bounded validation. No raw body, links, room names/People or invitation secrets in public group projection, generic audit/outbox events or logs. Server grants/RLS/definer search_path must be audited. Do not reveal blocked direction through error detail.

## Writes, concurrency and pagination

Stable actor/Group/room/action UUIDs freeze deliberate intent. Lost server response, duplicate tap and exact retry resolve one action and one message, not two rooms/sends/invites; changed intent with reused key conflicts. Do not claim a success state before canonical reconciliation. No action receipt is a current access grant.

Handle invite acceptance racing role loss/group leave, concurrent remove/send and archive/send by canonical lock order. For history, prove join-time frontier at equality boundaries and protect older messages according to C00. Read APIs are server-cursor-paged, stable under equal timestamps and message deletion; no client all-history preload. Notifications/Realtimes are hints that trigger durable refresh, not authorization.

## Integration with existing Messages

Do not change the existing private Project-request/Resource/Project chat semantics. The inspected MessageChatItemKind supports only project_chat/resource_chat/project_request_chat. Add a scoped Group-discussion kind and canonical unread support *without breaking installed v3/v4/v5 projections*. A separate bounded Group-discussion inbox API is acceptable until coordinated cumulative integration; do not append a new kind to an old client RPC result that strict readers cannot parse.

Batch D simultaneously owns representative conversations. Inspect its live head/PR before modifying shared inbox schemas, unread controllers, notification projection or generated types. A clean textual rebase does not guarantee unread reconciliation. Additive versioning or separate domain endpoints are safer than mutually incompatible replacement of the same function.

## Validation

- Fresh migrations and populated predecessor-to-current upgrade on an isolated disposable local stack.
- pgTAP / genuine local Auth actors covering current vs pending/former/manager/invited/rejoined, foreign group ID and source/member/room revocation.
- Join-frontier exact timestamp, lost responses, duplicate sends, stale conflicting edits/removal and lock waits.
- Server-bounded room/history listing, stable cursor ties, unknown room denial and unread/read ACK only for visibly rendered newest history.
- No body or sensitive metadata in broadcasts, public/group/Project projections, template, audit or generic search.
- Report evidence and account erasure/deletion compatibility. Separate actual checks from intended behavior.

Document new domain and migration contract. Push a C01 draft PR based on C00; do not merge into main until C00 is approved and the final C gate passes.
