# 0009 — One Private conversation per pair of people

- **Status:** Accepted
- **Date:** 2026-10-24

## Context

[A1](../../../history-implementations/PLANETS_A1_unified_private_conversations_codex.md)
approves one visible personal conversation across participation, Scambio-Dona,
accepted Group member contact and accepted Find People contacts. Separate source
records remain legitimate. This supersedes ADR 0007's cross-domain presentation
exclusion and ADR 0008's source-level Private badge identity for the new client.

## Decision

Derive the unordered identity from the two immutable profile UUIDs. A versioned
server projection groups all currently authorized personal sources before
pagination. It provides one mixed chronological feed without moving, copying,
rewriting or deleting source messages. Original source kind/UUID, authors,
timestamps, ordinals, moderation identities and installed RPCs remain intact.

Each query rechecks each source's own history predicate, including member
episodes and the Find People server/account/policy gates. The aggregate also
requires currently available, complete, nonanonymous Auth identities. A pair
identity grants no new consent. Group discussions, Project groups, organizational
representatives and multiparty coordination remain outside Private aggregation.

The composer selects an exact current context. A participation request is an
explicit send witness, including when several Projects share a participation
pair. One immutable command records actor, peer, source, episode and submitted
body; the original domain writer owns final locks and permission checks. A race
cannot select another Project, Resource, episode or post. Exact delivery retries
return the original source result after current source authorization.

The new account badge counts distinct authorized peers with incoming unread
human messages; row counts sum those human messages. Group counts and every
installed source summary remain unchanged. A newest-page token binds private
source high-water marks in the same SQL snapshot. ACK names only messages that
actually rendered in the unobscured foreground. It advances a source's existing
monotonic frontier only through a prefix with no unrendered incoming gap.
Backscroll alone, lists, previews and sheets do not ACK. Original source read
APIs remain valid. Own-account hints contain only the recipient UUID.

## Consequences and rollout

The source tables retain consent, retention and evidence ownership. Only bounded
private send receipts and expiring read snapshots are new durable metadata;
neither introduces an Auth/Profile erasure-blocking foreign key. Read-only history
and current send entitlement remain separate. Exact-source deep links authorize
that source before opening the same person thread, preserving source focus.

Deploy the additive backend before a compatible mobile client. A missing A1 RPC
is an explicit failure; the client cannot reconstruct guessed pairs from older
paginated lists. Existing installed clients keep their versioned domain contracts.
Source merge does not authorize hosted SQL, experiment activation, deployment or
store upload. Unknown privileged hosted effects remain held under the existing
release policy. See the [implementation contract](../../development/private-pair-conversations.md).
