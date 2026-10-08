# Supabase database

MODINT01's draft integration reconciles main's participant invitations/People
with the inherited moderation and global suspension stack. The forward
participant-visibility migration reuses canonical public visibility, so hidden
Projects reveal neither title nor ID through bearer preview. It preserves
authorized private management and narrow own-action receipt recovery. The
combined RPC inventory and integration commands are documented in
`docs/development/database.md`; founder copy/policy review remains open.

09C1B adds admin-only, reversible `account_suspension` in the canonical private
consequence history. Ordinary private RPCs/direct RLS/Storage access are gated,
but public content and stored relationships remain. Own expected-identity status
is the only account-data exception. See the database guide and system design for
the lock hierarchy, cached-Realtime mitigation and deferred push/appeal scope.
The suspension real-auth, race and RPC-audit commands are part of `check:db`.

This folder owns the reproducible local PLANETS database and its security validation.

- `config.toml` configures the local stack and fail-closed Data API defaults.
- `migrations/` is the canonical, timestamp-ordered SQL schema history.
- `tests/` contains native pgTAP invariants and transactional security probes.
- `functions/` contains purpose-limited external service adapters. MAP01's
  `location-search` stays disabled with no key. Canonical private budgets/receipts,
  parent geography and versioned location RPCs are migration-owned; see the
  [data/exposure contract and runbook](../docs/development/map01-geoapify-location.md).
- MSG02 stores body-free source identities, send-time incoming eligibility and
  private read frontiers in `private.message_*`. Complete totals authorize once
  per conversation and apply the canonical group history cutoff to metadata.
  Newest feeds issue own snapshot tokens; notification activity and push remain
  independent. See [ADR 0008](../docs/architecture/decisions/0008-message-unread-and-activity-alerts.md).
  `npm run messages:unread:upgrade:verify:local` requires an explicitly disposable
  stack (`CI=true` or `PLANETS_DISPOSABLE_QA=1`), resets to populated MSG01, then
  proves atomic cutover. `npm run messages:unread:verify:local` covers real
  authenticated writers, commit races, private warm sockets and bounded summaries.
- PI01's private reusable participant-link generations/secrets and admission
  receipts use the same membership/chat/capacity domain as ordinary approval.
  The API, scoped photo exception and retry/re-entry protocol are documented in
  [`pi01-participant-invitations.md`](../docs/implementation/pi01-participant-invitations.md).
- `seed.sql` runs after migrations during reset and currently contains no data; the system-managed starter skill catalog is migration-owned reference data.

09C1A adds private, manual and reversible moderation-consequence episodes and
actions: safety notices, outbound interaction restrictions, and Project/Resource
content hides. Expected-identity staff commands require user-facing reasons plus
private notes; only affected users and current staff receive their respective
bounded projections. Restriction withdraws pending outbound attempts, while hide
freezes acceptance without changing pending status or owner lifecycle. Existing
accepted relationships remain operational. Public discovery, cover-object access,
contextual photos and new matching delivery reuse canonical hide predicates.
The six identifier-only consequence outbox events are intentionally unconsumed
until 09C2. Tests 108–111 and the two `moderation:consequences:*:local` verifier
commands own this slice; see `docs/development/database.md` for contracts and locks.

09C2B2 adds only `get_own_interaction_restriction_status(expected_profile_id)`:
an authenticated, active-account, own-identity boolean using the canonical private
predicate. It returns no metadata or reasons and is denied while suspended.
Migration `20261006081004` and test `113` cover grants/identity/current episodes,
including an active episode beyond the first history page. Existing consequence
and suspension real-auth verifiers and the signature-level RPC audit cover it;
no private grants, suspension exception or outbox change is introduced.

MODINT01's committed-main continuation composes the new participation-pair and
message-unread broadcasters with the existing suspended-recipient filter through
forward migration `20261006184900`. No history, unread receipt or active-peer chat
entitlement is changed. The inventory is now 238 signatures after MAP01; SQL `119` and
the expanded real-auth integration verifier cover the combined boundary. See
the current continuation evidence in the MODINT01 review packet.

MODINT01 forward migration `20261008145225` closes the MAP01 service-role actor
suspension gap under the canonical profile-before-item barrier. SQL `121` and
`verify-local-location-suspension.mjs` cover current actor access, existing
batches, public hide/private entitlement and persisted concurrent outcomes.
SIM01 adds authenticated-only `list_similar_active_proposals`, a private
immutable title normalizer and partial published-title GIN index. `115`/`116`
cover grants, input bounds, narrow payload, ranking and exact-start eligibility.
The [matching contract](../docs/development/similar-active-proposals.md) documents
lexical limits, capacity-versus-join semantics and rollback-only plan evidence.
`npm run proposal:similar:verify:local` runs the OTP/API seam in Database CI
and the complete manual gate. It does not change ordinary discovery or Workshop.

TW01 owns source-linked one-time Proposal templates in private identity/baseline
tables. Publication captures the original Creator's last saved draft atomically;
public Workshop RPCs project canonical content only after Completed through a
shared source-visibility/removal predicate. `110`/`111` test hardening and domain
behavior. The [Template Workshop guide](../docs/development/template-workshop.md)
maps the four RPCs, version and bounded blueprint contracts, live attribution,
Storage boundaries and local backfill/concurrency verifiers for TW02/TW03.

09B1 stores append-preserved directional block episodes in the private schema
and exposes only expected-identity Block/Unblock plus an outbound-only keyset
read. 09B2 adds `get_own_blocked_profile_status`, a zero-or-one exact-target
outbound read with the same identity check and no reciprocal/inbound field.
Either active direction creates one symmetric barrier for new Resource
request creation/acceptance. Project participation checks the requester against
the immutable Creator plus every active Co-creator and Co-organizer; revoked
delegates are excluded. Blocking by a current manager rejects the pending
request, while a requester blocking a current manager withdraws it. Accepted
Project membership/group chat/meeting/workspace access and accepted Resource
agreement/chat coordination remain ordinary domain state. Public discovery and
public photos are unchanged, while
interaction-only photo metadata and Storage delivery are revoked across the
pair. Moderation evidence ignores block state. A sorted-profile transaction
advisory lock is always taken before Project or Resource row locks. Project
request/accept paths acquire every current-manager pair lock deterministically,
then lock and revalidate the Project/manager set. Run
`npm run blocking:verify:local` after a clean reset to prove block-first,
request-first, acceptance-first, and final-capacity serial outcomes.

09A2A stores Project group-corroboration invitations and one-shot responses in
private append-only moderation evidence tables. Qualifying reports snapshot
the Project creator and accepted membership intervals in the report
transaction while excluding reporter/subject; later joins, departures, case
completion, and reopen never rewrite the cohort. Clients use expected-identity
RPCs only, invitees never receive peer evidence or counts, staff evidence is
read-only, and there is no notification/outbox or enforcement side effect.

09A2B extends that request discriminator with Resource counterstatements and a
separate append-only response table. Supported report targets with a canonical
Resource request context atomically create one request for the revalidated
reported counterparty; generic listing reports without that context do not.
Recipient RPCs expose reporter-anonymous accusation/context data and only the
recipient's final statement, while current staff get the assigned identity and
pending/submitted evidence. Exact retries are idempotent, conflicting retries
fail, completed cases suppress unanswered pending work, and reopen restores the
same request. Audit remains identifier-only and there is no Resource mutation,
notification, Realtime, outbox, or enforcement side effect. Run
`npm run moderation:counterstatement:verify:local` after a clean reset.

The 04C4D1 forward migration derives active listing-owner loan reservations
from accepted current LEND terms and agreement lifecycle. It rejects half-open
period overlaps under a listing-row lock, exposes only an owner schedule and
counterparty pending-availability boolean, and derives overdue/at-risk without
timers, extra ledger rows, or borrower-public calendar data. One listing is one
reservable unit; requester-side free-text LEND is outside this inventory.
The focused OTP command is `npm run resource:loan-reservations:verify:local`.

04C4E1 adds a read-only creator match RPC for one open Project need. It uses
Italian stemming with OR-combined safe lexemes and a whitespace-normalized
title phrase tier, then explicit rough-geography and Dona/Scambia filters.
`same_locality` requires locality; `same_administrative_area` requires country
plus administrative area; `same_country` requires country;
`anywhere` imposes no geography filter. Missing source geography required by
the chosen scope is an error, not a wider search. The response reuses the
existing public listing detail projection for its safe fields and active
request count. It has no match ledger or private D1 reservation access, so a
match is not a loan-availability promise. Run
`npm run project:resource-matching:verify:local` after local DB reset.

04C4F1 adds private, Project-independent saved definitions of the current
Resource browse query, Dona/Scambia mode, and locality filters. The RPC-only
table normalizes those exact filters, rejects the all-empty definition, maps
per-profile semantic duplicate creates/updates to `PT409`, and lists by the
complete descending update-time/UUID keyset. The private field predicate mirrors
the existing public browse behavior without lifecycle input: F2 will run the
saved filters through public browse, while F3 separately owns published-listing
events and all notification decisions. F1 stores no match results and emits no
events. Run `npm run resource:saved-searches:verify:local` after local DB reset.

Proposal discovery accepts one optional trimmed query on both the sanitized
public page and the authenticated pending-request projection. It is capped at
120 characters and uses case-insensitive literal substring matching across
title, summary, and description; `%` and `_` are ordinary characters. Existing
locality, skill, eligibility, identity, and keyset-pagination rules remain in
force. The focused commands are `npm run proposal:verify:local` and
`npm run participation:browse:verify:local`.

Accepted Scambio-Dona requests now atomically create both the existing exchange-agreement anchor and a distinct resource-request chat. The owner/requester retain immutable human history permanently, while sending follows the open coordination episode and serializes on the agreement lock. Private per-profile Realtime emits identifier-only message and agreement-refresh hints; completion/cancellation makes the chat read-only, listing closure does not disable open accepted coordination, and later request episodes receive separate chats. Unified Requests/Chats projections combine this domain with the existing Project feeds through complete discriminator-aware keysets. Supported Resource request, chat, and agreement events project into strict body-free `resources` notifications and provider-neutral push jobs; pre-projection Resource history is acknowledged without backfill. `npm run resource:chat:verify:local` covers the conversation domain, and `npm run resource:messages-notifications:verify:local` covers the cross-domain and alert projection.

The migrations establish database infrastructure, identity/audit/outbox primitives, profiles, Proposal/Tavolo discovery, standalone Scambio-Dona resource listings, private request episodes, and immutable two-leg exchange agreements, Project-owned plain-text resource needs, private join-request contribution selections, immutable three-way acceptance decisions, accepted-membership commitment sets, one-time Project actual-contribution attribution, shared participation, the canonical notification domain, Project-chat message-time notification/push fan-out, and the private provider-independent push installation/delivery protocol. Project needs attach to the shared Project identity; join-request attempts may reference their open IDs and current Proposal skill requirements without becoming Scambio-Dona listings. Selection, acceptance-decision, and commitment tables are fail-closed: request creation is atomic, selected-request acceptance requires exact `needed`/`already_found`/`extra` triage, and only needed plus extra seed the separate membership-episode desired set. Commitment replacement retains ended history without rewriting acceptance history, validates only new IDs against current Proposal/open-need options, serializes with membership and option changes, and emits no notification. After an ended published one-time Proposal, actual attribution derives automatically from the commitments of a membership active at the exact end instant; creator corrections are stored only as sparse overrides plus an independent effort marker, use full-set compare-and-swap replacement, and never derive from live coverage history. The focused real-OTP verifier is `npm run project:actual-contributions:verify:local`, and the full database gate includes it before generated-type drift validation. Resource listings expose sanitized rough-location public RPCs and only a derived pending-plus-coordination-open-accepted interest count. Their request rows remain RPC-only; acceptance creates one agreement anchor whose immutable current/pending terms use a required owner give/lend leg and optional requester none/give/lend leg. Actor-authorized append-only milestones freeze terms at handoff, automatically complete fully confirmed give/lend legs, and retain accepted coordination after listing closure. Completion or pre-handoff cancellation closes request coordination and permits a later episode without rewriting history. Agreement terms, dates, notes, and counterparties remain private; audit/outbox transitions contain identifiers only and project no notifications or conversations. These flows are covered by `npm run resource:listings:requests:verify:local` and `npm run resource:agreements:verify:local`; `donate`/`exchange` remain compatibility discovery intents rather than rigid agreement semantics. The push protocol owns recipient jobs, one-time installation targets, expiring leases, safe append-only attempts, retries, and terminal aggregation without provider network calls. Its token-returning worker routines remain in the unexposed `private` schema and are available only to a direct-database `service_role`; that role has no table privileges. Tests prove security properties from a clean replay, including owner isolation, sanitized public reads, Scambio-Dona request/agreement lifecycle and concurrency, Project-need, request-selection, acceptance-triage, membership-commitment and actual-attribution lifecycle/concurrency, recipient-only notification APIs, private provider-token handling, channel-independent multi-recipient projection, worker concurrency/recovery, sender exclusion, membership-time targeting, and per-consumer outbox idempotency. Contributor commands and the checklist for future objects live in the [database development guide](../docs/development/database.md).

PI05 corrects the shared participation notification resolver to use the
canonical `resolved_by_profile_id` or `removed_by_profile_id` for manager
decisions/removals, including delayed projection after delegate revocation.
Payload attribution must still match canonical history; recipients and grants
are unchanged. Test 111 covers both Project kinds, in-app/push projection,
idempotency and forged attribution. The explicit `demo:check:local` integration
sequence runs after clean tests and other verifiers; see the
[demo guide](../docs/development/demo-data.md).

The 07C2A migration introduced shared-Project Co-organizers without creating
participant memberships or changing immutable original-Creator attribution.
Its Creator-issued 256-bit bearer invitations expire after exactly seven days,
retain only SHA-256 digests, serialize first-winner acceptance, and support
same-accepter retry. Active Co-organizers use the existing operational manager
boundaries. Run `npm run project:delegates:verify:local` for the real-OTP race,
secrecy, lifecycle, and revocation evidence.

The 07C2B read migration adds two expected-identity-bound projections without
expanding data visibility. `get_own_project_management_role` reports only
`creator`/`co_creator`/`co_organizer`/`none` for the current profile and one
exact Project.
`list_own_delegated_projects` returns the current profile's active non-draft
Proposal/Tavolo navigation cards in one call. Neither read exposes invite
tokens, delegate lists, participant data, draft owner content, or exact
location. Focused pgTAP coverage lives in tests 065 and 066.

The 07C2C migration evolves the same delegate tables rather than adding a
second authority source. Existing relationships and pending links backfill as
Co-organizer; invitations record the actual issuer, relationships record the
actual grantor and initial/current role, and `project_delegate_role_changes`
retains promotions/demotions. Creator/Co-creator structural RPCs list, invite,
revoke, promote, and demote. Co-creators may edit already-published Proposals
and published/paused Tavoli and use their existing non-destructive lifecycle
transitions under the same validation rules as the Creator. Draft creation and
publication remain original-Creator-only. Tests 068 and 069 cover the role
model, provenance, stale issuer authority, lifecycle access, and participation
independence.

TW02 extends private moderation cases with a typed Proposal-template foreign
key and separate immutable source/content-token provenance. The forward migration
adds protected append-only removal receipts/reasons and three staff-only RPCs:
current published context, bounded resource pages and explicit template removal.
The template-only self-report exception never activates existing Project or
Resource evidence invitations. Existing review-state actions remain separate.
Tests `112` and the authenticated `verify-local-template-moderation.mjs` cover
privacy, concurrency and atomicity; the latter is included in
`moderation:verify:local`. `verify-local-template-moderation-upgrade.mjs` checks
legacy evidence before/after actual forward migration. The
[Workshop contract](../docs/development/template-workshop.md) documents the
source/template/case lock order for TW03 and the unchanged baseline/media rules.

TW03's forward `20261004145334_template_to_draft_creation.sql` owns two
hardened authenticated RPCs and append-only applicant-private acceptance receipts.
It composes ordinary draft/need creation from one eligible locked source payload.
Test `113` audits security; `scripts/verify-local-template-application.mjs` proves
copy/reset, exact recovery, rollback and removal concurrency; its `...-upgrade.mjs`
companion checks populated TW02 history through actual forward migration.
The Workshop guide owns complete inputs/receipts/errors and local commands.

DRAFT01 adds forward migration `20261004200147_idempotent_editor_draft_creation.sql`,
private append-only creation receipts and two actor-bound editor RPCs. Existing
ordinary create overloads remain available. `114` audits raw grants/RLS and RPC
hardening; `npm run draft:editor:verify:local` verifies the authenticated contract
and removed-template draft independence. See the
[draft departure guide](../docs/development/proposal-draft-departure.md).
