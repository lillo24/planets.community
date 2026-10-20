# C-R00: approved General / Ideas revision

Authority: the founder-supplied [complete C package](../../history-implementations/PLANETS_Parallel_C01_D00_Packages_2026-10-15/PLANETS_Chat_C01_Full_Package_2026-10-15.md), version PARALLEL-CD-2026-10-15-v1. This contract supersedes the provisional C00 audience/history matrix. The older C evidence remains evidence for its exact historical source, not this revision.

Implementation and local qualification are recorded on cumulative PR #257. Starting source is C `e8c5c8c`; main `5c3d50b4` is incorporated at `a7092c99`, main `224bcab6` at `0bcf6e23`, ACTSPLIT01 main `32f37791` at `d298f059`, and the later map-plan-only main `9fc89268` at `93a98558`. D #254 remains unmerged and is not incorporated; the lane handoff records the inspected peer interfaces. The final published-head checks, merge event and closeout on that PR record the operational completion gate; no earlier CI run substitutes for it. No hosted operation is authorized.

## Decision ledger

| Class                             | Decision                                                                                                                                                                                                    |
| --------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| User decision                     | One automatic durable General per eligible published Group; explicit Idea Join; Group-visible or invitation-only plus current managers; full earlier history on admission; bounded pre-exit history.        |
| User decision                     | Creator and current managers manage Ideas; ordinary members can create when the setting allows; only Group Creator/Co-creator publish Group Projects.                                                       |
| User decision                     | Conversion Option A: explicit ordinary Project joining, never automatic enrollment; planning freezes at publication and retains independent authorization.                                                  |
| Existing implemented contract     | Independent Group membership/delegation; real human Project authorship; GRP03C publication, Idea/Defined lifecycle, Project participation/photo/capacity/block rules; private named HTTPS links.            |
| Reversible implementation default | Creation setting starts managers-only; approximately seven days means seven complete days against server activity; General is never quiet-hidden.                                                           |
| Reversible implementation choice  | General's durable room owns the Group-wide named-link collection; Ideas keep their own collections. Shared presentation does not merge their audiences.                                                     |
| Reversible implementation choice  | General's contextual workspace introduction is dismissible once per account on this installation; missing means visible. Its permanent workspace entry remains; no backend sync or private content storage. |
| Implementation choice             | Disclosed current manager entry permits read/send/manage within the Idea. Actual planner admission remains a separate deliberate action and determines planner-targeted conversion invitations.             |
| Outside C authority               | D personal/representative audiences; production hosting; legal retention periods; account suspension in the separate unmerged policy stack.                                                                 |

## Access matrix

All private operations require the live canonical identity and applicable Group lifecycle/accountability checks. Suppression/archive/unpublication are distinct from per-person hiding. No erased identity regains access through an old token. Staff alone receive only exact reported evidence, never room access.

| Actor                                       | Discovery / history                                                                                      | Current collections / sending                                          | Room administration                                                                               | Project publication             |
| ------------------------------------------- | -------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- | ------------------------------- |
| Current Group person, General               | Automatic General/full history                                                                           | Current links; send                                                    | Current managers only                                                                             | Independent GRP03C              |
| Current Group person, unjoined visible Idea | Title, purpose, creator; no messages                                                                     | No current links, roster or send                                       | None unless manager/eligible creator                                                              | None from discovery             |
| Targeted invitee / valid capability holder  | Minimal acceptance context, current Group eligibility required                                           | No pre-accept history/send                                             | No fresh restricted-room grants                                                                   | None                            |
| Current admitted planner                    | Full history including before admission                                                                  | Current links/roster; send while active                                | Eligible Idea creator or manager; ordinary visible-Idea participant may suggest a targeted invite | None from room admission        |
| Current Group manager                       | Disclosed discovery/read/manage every Idea                                                               | Current links/send while active; actual participation remains separate | Yes, without structural Group editor powers for Co-organizers                                     | Creator/Co-creator only         |
| Former planner                              | Only known room snapshot and messages through committed exit sequence                                    | No later title/activity/roster/current links/send/alerts               | None from provenance                                                                              | Independent Project rights only |
| Former manager                              | No perpetual room directory; retain only an actually entered/read frontier or independent room admission | Revoked authority cannot manage                                        | None from former role                                                                             | Independent current rights only |
| Project-only participant                    | Canonical Project history; no private origin metadata                                                    | Project rights only                                                    | No source right                                                                                   | Canonical Project role only     |

Independent current membership and delegation are checked separately. Ending one role closes that authority frontier, without falsely ending another valid admission right. A fresh accepted room action is needed after all supporting Group entitlement ends. Replayed receipts never rejoin. A manager's actual observed room frontier must be recorded without creating ordinary participation.

History visibility and unread baseline are separate: admitting an actor exposes prior history without marking old messages unread or emitting old alerts. Sends and exits serialize on committed room sequence, including equal timestamps. Only an actually rendered authorized newest-page token can advance ACK; hiding/muting/opening an invitation cannot.

## Invitations, alerts and preferences

Targeted room invitations are structured consent items in Messages/Requests plus activity notices; they are not human messages/unread. Opening, signing in and profile completion do not accept. Restricted-room capabilities are creator/manager-controlled, revocable and Group-scoped, not Group or Project enrollment tokens.

Creation notices target eligible current Group people for visible Ideas; restricted Ideas target current managers/creator and actual invitation targets only. Message alerts target current entitled subscribers subject to mute, never former relationships. Hidden rooms remain subscribed. Each delivery reauthorizes and deduplicates; no private payload goes to public projections or generic outbox data. Bounded projection avoids publication-time fanout.

Manual hide applies to unjoined discoverable Ideas until deliberate unhide/Join. Automatic quiet hiding uses last meaningful activity, falling back to creation, and new activity resurfaces it. Neither ends membership, archives, mutes nor marks read. General is pinned ahead of Ideas.

## Conversion and worked example

An eligible Idea creator requests publication; current managers review, but only an actual Group publisher deliberately creates/owns the private Project draft. Source remains active through proposal/draft saves. One stable private association and exact command recovery prevent duplicate Projects. Publication atomically rechecks publisher, Group, draft revision and source, freezes the source sequence, and records stable invitation intent. No planning message is copied/reparented and no workspace URL is automatically shared.

Alice is Group Creator. Bea, an ordinary member, starts an Idea after all-member creation is enabled. Carlo explicitly joins; Diana is outside the Group. Alice reviews and publishes as the actual Project author. Bea and Carlo receive one contextual invitation each. Bea declines and keeps only authorized frozen planning. Carlo explicitly requests/joins through canonical Project rules and may see both histories. Diana later joins the public Project and sees only Project history. Alice's replacement Group manager inherits disclosed source oversight, not Project membership or D contact history.

The implemented continuity fallback links a separately authorized, read-only planning view from canonical Project chat. Both histories retain their own pagination and ACK; there is no interleaved timeline. A planner awaiting/declining Project admission gets a truthful public Project CTA, no Project preview. Project-only users get no source route. Deliberate selected-link sharing requires both source disclosure and Project workspace authority, destination-audience confirmation and retry recovery.

Required race cases include same-time exit/send, removal/rejoin, manager-to-member change, hidden+muted delivery, revoked/rotated invite links, two publishers, lost draft/publication reply and changed Group attribution. Publication success creates zero memberships, capacity reservations or contribution commitments.

## Owner map and qualification checklist

Reuse `private.group_discussions`, admissions, invitations, immutable messages and receipts. Forward migrations revise effective permissions and version new strict client projections. Existing `group_discussion` report identities, Project/Resource chat readers and scoped Realtime hints remain distinct. Native owners stay under `features/group_discussions`; Project editors retain canonical draft/publication ownership.

- [x] General/settings/visibility and exact current/historical projections.
- [x] Explicit targeted/capability admission, bounded notices, hide/mute and report/ACK rules.
- [x] Folder/Requests/Group People/mobile link surfaces and EN/IT disclosure.
- [x] Recoverable publication, source freeze and opt-in Project invitations.
- [x] Independently authorized history via the disclosed linked-view continuity fallback and selected-link sharing.
- [x] Local fresh replay, populated main-to-C and old-C-to-revision preservation, replay idempotence, types/grants/advisors; the final published-head CI repeats its complete gate.
- [x] Affected local validation, independent revocation regressions and the complete final-runtime Android journey with inspected renders.

The adjacent lane handoff and qualification report record actual migration/API
names, source/Project permission matrix and executed evidence. Final full
classified CI, latest-main/peer recheck, source merge and C-only cleanup are
tracked by PR #257's durable checks, merge event and closeout, rather than a
self-referential commit in this pre-merge report. D is preserved if it actually
lands; a separate draft is not counted as included.
