# D01 — Purpose-bound requests and representative conversations: backend

Read the coordinator and D00 record. Start from D00's verified head. When D00 is provisional, all work and fixtures remain on the review-only stack; no main/shared-environment activation.

## Outcome

Canonical, private request/accept/decline/withdraw behavior and accepted representative text conversations, with retry safety, bounded reads, precise role/access rules and usable safety integration. D does not grant group membership, Project participation or publishing powers.

## Implement in three internal milestones

**D01a — Request domain:** schema, constraints, allowed purposes, expected actor, source/target-group context, private triage reads, command receipts, rate/duplicate controls, exact state transitions and concurrency tests.

**D01b — Accepted conversations:** explicit participant/representation access, role/history lifecycle, message send and bounded history, safe identity projection, close/leave rules, reporting and cross-account denial tests. Use D00's actual accepted/provisional recipient model rather than a different convenient model.

**D01c — Shared integration:** typed/versioned inbox/conversation projections, canonical unread state, safe invalidation/notification routing, current safety/deletion coverage and populated upgrade verification. Validate each layer before treating the next as supported.

These are reviewable commits or child stages within D01, not three independently activated products. Do not require C01, A04 or another unmerged branch.

## Likely implementation areas

Inspect effective group identity/role/block helpers, the new group-attribution feature, migration conventions and real-auth verifiers. Existing feature owners include `messages`, `project_chat`, `project_request_chat`, `resource_chat`, `group_membership`, reporting/blocking and notification projection. Generated Web database types are another consumer even when no new public website screen is built.

Choose focused D tables/RPCs that follow repository patterns. Do not add D members to Project membership, route D through a fake Project ID, or reuse a requester/Creator pair row that gives the wrong participants access. Reuse message presentation/receipt/invalidator primitives only after checking their assumptions. A cross-domain global chat refactor is not part of D.

## Requests and commands

Derive the authenticated personal actor on the server and match the caller's expected actor. Verify source representation and destination eligibility from canonical current records, not profile fields, user-editable claims or a posted role string. Enforce D00's group-type and accountable-identity rules.

Store request purpose, explicit actor/group context and only the bounded content needed for recipient review. Referenced Projects must be currently authorized public context; never copy protected location, draft text or private membership into a request preview. Validate supplied IDs, names and content lengths with existing Unicode/normalization conventions.

Create, accept, decline, withdraw, close and leave must have explicit allowed source states and predictable conflicts. A read/preview does not create a request or conversation. Duplicate requests and new deliberate attempts follow D00's contract rather than a permanent blanket unique pair that prevents legitimate future collaboration.

Use stable actor/action idempotency across transport failures. Freeze operation, target, purpose and submitted intent. Exact replay recovers the original result; changed intent is a conflict, not a second operation. A receipt does not authorize current private reads or reaccept a revoked/ended relationship. Close/withdraw/reject recovery may reveal only the caller's authorized original outcome after access loss.

Acceptance rechecks both endpoints/groups and all relevant role, block, lifecycle and pending-state conditions **after lock waits**. Reuse the established group/block lock order and define sorted multi-group locking without acquiring new block-pair locks after group locks. Revoke/step-down/block and accept/send must serialize meaningfully; UI refresh is insufficient. Exactly one conversation and participant set results from simultaneous acceptance and lost-response retries.

## Conversation access and history

Use the approved explicit admission set plus live role/group eligibility, not "any current manager of a participating group." Bind delegate-based access to the canonical grant/episode where needed so revoke-and-regrant cannot resurrect an old permission unnoticed. Changing between the two still-authorized delegate roles need not manufacture removal; encode D00's precise rule against current domain helpers.

Every protected path uses the same audience: message history, row preview, exact-item read, unread counts, read acknowledgement, search, sender metadata, realtime delivery, report evidence and private media metadata. New replacement managers cannot receive old previews or old unread just because the chat body endpoint denies them.

Keep immutable human/group-at-send provenance without blocking account deletion. Render deleted or inaccessible identities neutrally under current retention rules. No public profile/photo grants result from conversation access; explicitly scoped name projection is different from opening an entire profile.

History is keyset paged with a deterministic timestamp/sequence plus ID boundary. Preserve before/after admission frontiers chosen in D00, including equal timestamps and sends racing with admission/removal. No forward activity hint for a person entitled only to an older slice. Do not remove existing Project/Resource former-history rights while adding D's policy.

Sending must be identity/intent-bound and duplicate-safe on lost responses. Only canonical committed human messages affect human unread. A client-generated UUID alone is not authorization or evidence a send committed. Do not count invitations, acceptance cards, management events or the sender's own messages as incoming human unread.

## Shared Messages compatibility

The inspected `MessageChatItemKind` and v5 parser reject unknown kinds. Preserve existing deployed RPC signatures, row shapes, ordering and totals semantics. Add a versioned D-capable projection/contract for new clients rather than injecting a new kind into old exact-shape responses.

Old clients must neither crash on new types nor show unreachable D-only unread badges. New-client complete-scope totals and pages must agree. Inspect versioning for request inboxes, chat lists, unread summaries, feed envelopes, read tokens, notifications and exact routing together, not just the list endpoint. Avoid a partial rollout where a newer unread response references a chat an older client cannot render.

Use explicit D request/conversation variants and composite identities; do not conflate identical UUIDs across domains. Scope placement is recorded in D00/D02. Canonical database unioning/grouping occurs before pagination. No client concatenation of unrelated first pages as a complete sorted inbox.

Unread/read receipts reuse the durable MSG02 principles: acknowledge only an authorized rendered newest boundary; no arithmetical badge adjustment, request-count substitution or "mark all notifications read" that reads chats. Bound subscriptions to active/loaded scopes and clear identity-bound state on A→B→A changes.

## Realtime, notifications and privacy

Use private account/recipient-scoped identifier-only invalidations as hints to reload authorized durable state. A notification delivery retry must re-evaluate its audience and cannot expose bodies or new activity to revoked people through a still-connected socket. Do not rely on join-time channel RLS for instantaneous revocation. Cover account, role and membership changes plus reconnect/resume explicitly.

Request alerts and human-message unread are separate. Implement in-app discoverability, exact routes and applicable existing preferences without a new external provider. Browser/push/email delivery is out of scope unless an already-implemented compatible path can be reused without disclosing new content or broadening subscriptions. Never emit a notification kind that installed handlers cannot safely process.

RLS/grants must enforce the actual domain audience, including direct table/API attempts. If existing architecture requires SECURITY DEFINER RPCs, preserve explicit identity checks, safe search path and execute grants; do not copy a permissive helper to make tests pass. No service-role key in mobile; no new API based only on authenticated role.

Provide a report action for abusive initial requests as well as accepted messages. Extend existing private moderation evidence minimally, avoiding automatic sanctions, group retaliation or wide staff inbox access. Reporting/blocking and safe exit remain usable when sending is disabled. Existing private reports, counterstatements and reporter-anonymity rules cannot be silently relaxed.

## Required evidence

Test real local Auth/PostgREST actors, pgTAP grants/RLS and observed multi-transaction races, not only service-role fixtures or Dart mocks:

- Creator/Co-creator/Co-organizer versus ordinary/pending/former/unrelated/guest/erased identities; no inherited Project or group rights.
- Hidden/draft/archived/suppressed/orphaned groups and changing authority sets; no public roster leak.
- Concurrent accept/decline/withdraw, same-person manager on both groups, exact retry and changed-intent replay.
- Committed create/accept/send with lost response; no duplicate request/thread/message/alert/receipt.
- Role revoke/step-down, block, closure and deletion racing with send/read/accept; cached role/JWT alone cannot authorize.
- Pending-inbox readers versus accepted-chat participants, including new managers and former managers.
- Every private projection denied correctly: body, preview, latest timestamp, unread, acknowledgement, media metadata, old-token replay and realtime hints.
- Stable pages with tied timestamps, extra pages, response limits and no fan-out; counts computed from the full authorized scope.
- Existing client contracts unchanged; all existing Project/Resource/private-pair flows remain valid after migrations.
- Initial-request and message reports arrive with correct limited evidence and no unrelated conversation access.

Run empty replay and a populated current-main upgrade on the disposable D stack. Record introduced migrations/contracts, command/error map, access matrix, actual tests and remaining D00 decisions. Wire focused verifiers into normal path-classified checks without broad CI redesign. Push draft D01 and continue to D02.
