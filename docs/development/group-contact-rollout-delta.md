# Batch D review and distribution delta

**Provisional; no founder approval, production migration or distribution claimed.**
The concrete D00 [review table](group-contact-contract.md#explicit-review-gate) remains
the release gate. The following changes need policy/privacy/store review before
shipping; they do not silently replace the existing legal terms.

## New audiences and processing

Group contact deliberately shares a human's name, represented group, purpose,
title and note with current eligible destination managers. Only the submitter and
the accepting representative enter bilateral history. Other managers see minimal
resolved metadata; neither group membership nor Project authority is granted.
Representatives can Block and report received contact content.

The D/M revision also proposes named personal contact from canonical Group People.
The selected origin Group and optional introduction are shared only with the
named recipient. Acceptance creates an explicitly consented episode for that
pair and Group; managers have no triage or conversation oversight. The synthetic
candidate stops sending/notices when either loses their last qualifying origin
relationship and retains pre-end history read-only. Rejoin, Close or Leave does
not silently revive consent. This personal lifetime/history choice is separately
pending in the [revision ledger](group-contact-parallel-handoff.md).

Coordination shares a fresh note and initiator identity with the two original
representatives and invited groups' eligible managers. Claimants explicitly share
their own person/group seat with the originals. Complete identity disclosure to
claimants requires both originals' exact audience confirmation; every additional
person must then confirm that same version. This staged disclosure and the
conservative restriction on targeting groups already managed by an original
person require explicit founder approval together with D00's fresh-room policy.
Earlier private history/source context is never inherited.

Current live grant episodes govern history/preview/read tokens. Revocation and
own leave end access; regrant does not restore it. Lifecycle suspension permits
read-only history for still-valid admissions. Close is terminal and requires
current admission; a former participant retains safe own leave/report/recovery.
Changes in these expectations need accurate user-facing explanations and review
of current privacy/terms and Android/iOS data disclosures before distribution.

## Record and erasure inventory

| Record owner                                              | New durable fields                                                                                                 | Access/retention boundary                                                      |
| --------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------ |
| `private.group_contact_requests`                          | Actor/group/grant provenance, purpose, note, public Project reference, finite resolution/expiry                    | Current triage and exact valid admission; former own metadata only             |
| `private.group_contact_conversations/admissions/messages` | Immutable human/group message provenance, exact grant episode, leave/close and fresh coordination origin           | Current role-bound admission; participant-scoped read boundaries               |
| `private.group_contact_receipts`                          | Actor/action, exact intent hash, metadata outcome                                                                  | Own verified actor only; no note/body in receipt                               |
| `private.group_contact_seen_requests`                     | Own known request receipt                                                                                          | Supports protected reporting after loss; grants no body access                 |
| `private.group_coordination_proposals/seats/seen`         | Private source ID, fresh note, historical named seats/grant episodes, versioned confirmations, known-note receipts | Canonical bounded projection; source link only after independent authorization |
| Existing `private.moderation_cases/reports/events`        | Immutable typed D request/message/coordination targets and narrow case context                                     | Existing manual staff case workflow; no ordinary staff history access          |
| Existing private audit and read-state owners              | Metadata-only D action/consent/exit audit, unread/frontier/token data                                              | Existing private security/audit boundaries; no public metadata source IDs      |
| `private.member_contact_pairs/requests/episodes/messages` | Named pair/origin, contextual names, optional note, consent boundaries and immutable human messages | Pair-only accepted pre-end history; no manager oversight or automatic re-entry |
| `private.member_contact_receipts/seen_requests` | Exact actor/action/intent metadata and known-note evidence | Own verified identity; protected exact reporting after context ends |
| `private.member_contact_preferences/incoming/read_frontiers/read_snapshots` | Actor mute, incoming ordinals, rendered ACK frontier and short-lived proof token | Private actor-bound read state; mute and exit do not acknowledge |
| `private.contact_activity_notifications/progress/events` | Minimal typed request targets, recipient, read state, source outbox identity and bounded delivery cursor | Current actionable authorization rechecked before page/count/read; no private note or roster |
| `private.group_contact_preferences` | Own actor/conversation mute | Independent message-alert eligibility; no new history or unread permission |

New D actor IDs remain raw UUID provenance rather than new restrictive Auth/profile
foreign keys. Reads and post-lock commands verify live Auth/profile state; deleted
identity labels become neutral. D does not invent a deletion delay or mutate
existing moderation/account foreign keys. It provides live-access invalidation
and protected known-content reporting, including invitation reporting after seat
loss. The current repository's manual Plan 10 account deletion/retention workflow
still owns erasure/anonymization execution and lawful retention.

The founder must settle whether, when and how private messages, invitations,
retired seats, read metadata, command receipts and safety/audit evidence are erased
or anonymized. No expiry predicate is deletion; no operational retention or legal
compliance approval is inferred from a migration or passing test. Review also
needs to confirm age/identity expectations, prohibited contact conduct, moderation
escalation and appeals under the existing product policy decisions.

## Release boundary

Review the concrete staged UI, D00 decisions and final native/schema evidence.
Keep every stage and the cumulative integration PR draft until the required
approval reference and qualification are present. Client flags cannot activate or
approve this policy. No hosted database, real users, email/contact delivery,
provider billing, signing, Play/iOS application or production resource was used
to authorize the source implementation. Production/app-store rollout is a
separate account-owner action after this source review gate.
