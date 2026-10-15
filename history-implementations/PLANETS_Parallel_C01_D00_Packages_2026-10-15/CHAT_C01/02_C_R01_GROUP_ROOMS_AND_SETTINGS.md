# C-R01 — General, configurable Idea creation and room visibility

## Objective

Extend existing C room/Group structures with exactly one General and the approved creation/discovery/manager authority. Depends on C-R00 and existing main Group roles; not on D.

## Required behavior

**General:** Create idempotently at first eligible Group publication and backfill eligible existing published Groups safely. Enforce uniqueness in the backend. Restore/retry/opening Messages cannot create duplicates. Current Group People automatically have General access; an ordinary Group invitation preview reveals no history. General's reserved kind/pin cannot be forged through a display name, converted into a public Project or renamed into a normal Idea. Preserve real actor provenance; no fake participant or human welcome message is required.

**Setting:** Authorized Group structural editors control managers-only versus all-current-members Idea creation. Default managers-only, prominently editable. Preserve Creator-only draft and Co-creator published-editor limitations. Co-organizers qualify as managers for starting Ideas but are not newly granted broad Group settings/publication rights. Recheck the setting after lock waits. A later setting change does not delete member-created Ideas or strip their creators' approved room management.

**Idea content:** Retain stable room/creator IDs, versioned title and short purpose/description. Use the actual validated limits or document bounded new limits; no rich editor, media store or catalog expansion. Separate visibility from archive, mute, hide and conversion state.

**Group-visible:** Current Group people can discover allowed title/description/context and deliberately Join. This is not automatic room subscription or access to messages before Join. Outsiders and pending Group requesters do not gain it.

**Invitation-only + managers:** Ordinary room discovery excludes it. Target invitation or a valid scoped capability supplies only enough context to decide whether to accept; current Group membership is still required. Current managers always discover, inspect and administer it. Display this explicitly before creation and entry. Do not publish the manager/member roster to build a picker.

**Room authority:** Discussion Creator and current Group managers may manage within current eligibility; provenance alone never grants permanent privilege after leaving. Managers can oversee without a room invitation and can enter deliberately without automatic Project membership. Keep explicit room participation separate from oversight and Group role grants. Preserve valid overlapping rights without retaining a revoked grant.

No source grants another lane's private contact access. Reporting and public Group suppression remain canonical. No unrequested co-manager Project publishing rights.

## Technical and migration requirements

Inspect C's existing `private.group_discussions` and related admissions/receipt functions. Reuse/extend, not a second room backend. Follow the final data model chosen from repository evidence. Add forward migrations by default, keep current main/applied history immutable, and prove duplicate-safe General backfill and preserved old C records. Read effective functions after inherited C and peer migrations. Every read/write/list path enforces the same current eligibility; client-only tabs are not security.

## Tests and deliverables

Fresh and populated replay; multiple publish/restore/create retries; two concurrent publishers; initial draft/unpublished/suppressed Group; managers-only/all-members toggles; ordinary member creates/denied; creation after role/setting loss; creator vs manager management; unrelated/anonymous denial; no invite-only discovery/count leak; manager promotion/revocation with and without independent membership. Include an already-ended/erased actor and no double General/unread records.

Deliver code, canonical types, SQL/Auth tests and nearest docs. Run focused tests now, save full cross-lane qualification for C-R07. Stage PR remains part of the C lane, not an independent main merge.
