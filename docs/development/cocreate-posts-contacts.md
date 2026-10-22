# Co-creation posts and accepted contacts (B01)

This is experimental source on the cumulative RUNALL branch. Its current
qualification state is in [the ledger](cocreate-progress.md); source presence
does not establish a passed migration or live-backend journey.

## Responsibility and contracts

The additive B01 migration owns private topics, posts, interest episodes,
accepted post-scoped bilateral contacts, immutable human messages and command
receipts, read frontiers, typed report evidence and scoped post suppression.
Every table has RLS and no API table grants. Topics start empty; only an owner
can curate/activate them. No real people or production catalogue seed is added.

Public, bounded reads are `list_cocreate_posts` and `get_cocreate_post`.
Both require the server gate. Lists accept literal case-insensitive text,
case-insensitive exact locality and optional controlled topic ID, ordered by
immutable `(created_at DESC, id DESC)`. Cursor timestamp/ID must be supplied
together; page size is 1–50, default 25. Expiry, suppression, author account
availability and topic activation apply before pagination. Only post ID,
title/body, broad locality, topic and creation/expiry timestamps are public.
Unknown/unavailable exact detail returns null; a disabled domain raises 42501.

Private owner reads use `list_own_cocreate_posts`; interest reads use
`list_own_cocreate_interests`, restricted to requester or exact post author.
No public identity, response-count, private-note or contact projection is added.

`mutate_cocreate_post` accepts expected actor, immutable command UUID, operation,
post ID/version and a closed content object (title/body/locality/topic ID).
Operations are create/edit/publish/close/renew. Drafts may be incomplete;
publication requires all public text. Text bounds are 120/1000/100 characters.
Post version conflicts use PT409. Closing deliberately resolves outstanding
pending interest as declined and removes discovery; accepted contacts remain.
Renewal is deliberate and never automatically reopens a closed contact.

`mutate_cocreate_interest` accepts request/accept/decline/withdraw.
Only the author can accept/decline; only the requester can withdraw. A pending
request opens no conversation. Acceptance creates/reuses exactly one
post/requester contact and grants no native or co-creation membership.
Request notes are private, plain text, at most 500 characters. Accept/withdraw
serialize on the post then request; one terminal transition wins. Post closure,
expiry, account restrictions and symmetric blocks are rechecked.

`mutate_cocreate_contact` accepts send/close. The two counterparties alone
may read messages; both must have currently available identities and no active
pair block. Post suppression denies current contact reads/sends; ordinary post
closure does not. Closing contact stops both parties sending and retains the
authorized historical transcript. Own close/withdraw require exact identity but
remain safe with server activation OFF or incomplete profile; no private read
is granted by those paths.

## Retry, limits and read authorization

Actor command serialization precedes immutable receipt lookup. The original
hash covers operation, source, version and complete supplied intent. Exact
delivery returns the original result; changed intent raises 22023. Receipts are
results of past commands, never proof of current state or fresh permission.
Clients must reread canonical state before showing current availability.

Canonical block-pair locking precedes post/contact locking, matching block
activation. The block hook composes every predecessor domain and resolves only
pair-connected pending interest; unblocking does not revive it. No broad
existing block, Project, Group or Resource contract is replaced.

Settings extend A01 with configurable draft limit 20 (1–100), message limit
30/minute (1–120), plus open-post limit 5, request cooldown 300 seconds and
30-day discovery expiry. Payload/page limits are enforced at the server.
Publication expiry uses the clock after lock waits. Discovery expiry is not
retention or deletion. All new actor provenance is raw UUID, without new
Auth/Profile erasure-blocking foreign keys.

`get_cocreate_contact_page` returns exact viewer/contact identity, closed state,
human messages and an HMAC-bound newest-page read receipt. Earlier pages cannot
ACK. `acknowledge_cocreate_contact` reauthorizes, validates the receipt against
viewer/contact/sequence and monotonically advances the frontier. Outgoing
messages do not count unread. No system recruitment or invitation is fabricated
as a human message. The API introduces no retained socket grant.

## Moderation

`submit_cocreate_report` adds genuine post, interest and contact-message target
types to the canonical queue. The existing generic report signature is retained.
Targets/subjects are resolved from authorized source rows; immutable evidence
is private to the canonical case, never generic audit/outbox metadata.
Reporting a known accepted message remains possible after blocking/closure.
Erased identities do not become fabricated report subjects.

Current staff can fetch a case's exact immutable evidence and its source post's
current version/suppression flag through `get_moderation_case_cocreate`.
Those two bounded current fields make versioned moderation actionable without
granting a live transcript or contact browsing.
`moderate_cocreate_post` requires an existing co-creation case, current staff,
immutable command identity and post version to suppress/restore that source.
No second staff role or unscoped private-room oversight is added.

B02 must extend strict mobile report/request/message discriminators alongside
its live journeys. Existing released RPC signatures and audiences remain intact.

## Local verification

Use only the owned machine documented in
[the experimental contract](cocreate-experimental-contract.md).
Set process-only CONTAINER_CONNECTION and DOCKER_HOST there. If the official
ECR downloads stall, `SUPABASE_INTERNAL_IMAGE_REGISTRY=ghcr.io` selects the
official mirror with unchanged pinned service versions; it does not upgrade
dependencies or affect a hosted project.

Run migrations/pgTAP first on the clean disposable stack. The two new pgTAP
files cover gate grants/account checks and posts/consent/contact boundaries.
Then from repository root:

```text
npm exec -- node scripts/verify-local-cocreate-posts.mjs
```

That verifier requires the programme-owned local engine or an explicit
`PLANETS_DISPOSABLE_QA=1` opt-in, and always requires loopback endpoints.
The opt-in permits the existing disposable CI runner and other deliberately
owned local test stacks; this task uses only its named machine. It uses genuine OTP sessions for fictional
`@planets.invalid` identities, temporarily enables the gate, exercises uncertain
retries, concurrent duplicate acceptance/send, crossed accept/withdraw, private
projections, unread ACK, scoped staff evidence, expiry/closure, blocks and safe
exit, and restores activation OFF even on failure. It never resets a database,
touches provider configuration or prints session secrets. Fixtures remain
synthetic local data until the next explicitly authorized disposable reset.

Fresh replay, populated upgrade, complete negative/race coverage and generated
public types must pass before B01 is marked verified. B02 and the final Q00
journey must not mistake these API tests for completed live mobile UI.

## B02 mobile projection and recovery

Migration `20261022080000_cocreate_mobile_projections.sql` adds a bounded active
topic catalogue, versioned own interest/contact readers with the source title,
complete unread composition, and actor-only private invalidation. Installed B01
read shapes and native Messages readers are preserved. Native plus co-creation
conversation counts come from `get_own_message_unread_summary_with_cocreate`;
two incoming messages in one contact count as one unread conversation.

`list_own_cocreate_contact_exits` and `list_own_cocreate_interest_exits` require
only the matching authenticated identity. They expose own open anchors and
creation timestamps (plus the request's source ID), never bodies/notes or titles.
They support exact protected close/withdraw routes while the experiment is OFF
or policies need acceptance. They cannot grant read/send/new contact access.

The `cocreate:profile:<actor UUID>` channel carries only `profile_id` with event
`cocreate.changed`. Its SELECT policy accepts only that authenticated actor's
exact topic. Clients have no send/helper grants. Post/request/contact changes,
blocks, suppression, ban/deletion and configuration changes invalidate affected
actors; broadcasts occur transactionally and contain no private domain content.
No new push delivery or external notification provider is activated.

The existing Auth-trigger assertion now has exact allow-listed AFTER UPDATE
(`banned_until`, `deleted_at` only) and AFTER DELETE metadata hooks. It still
rejects all INSERT/BEFORE hooks and checks the new functions contain no
INSERT/UPDATE/DELETE statement. The hooks do not create profiles, change Auth,
erase records or establish a new retention policy. Unrelated actors emit no
co-creation signal. This is the reason for the narrow existing-test update.
