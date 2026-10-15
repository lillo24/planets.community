# C-R00 — Approved C contract, current-code delta and cross-lane interface map

## Objective and dependency

Translate the approved behavior in `00_START_HERE_C01.md` into one precise acceptance contract and a bounded code/migration delta against the **actual current** C cumulative implementation. Follow the shared contract. This stage is not a request for another open-ended product workshop.

## Inspect

Current main, #257 and its successors; `group-discussion-permissions.md`, `group-discussions.md`, `group-discussions-integration.md` on C; current Group roles/People, GRP03C publication, Project chat/history, workspace and notification owners; read-only D branch interface/evidence summaries. Preserve any current UI-polish implementation rather than overwriting it from old C snapshots.

## Deliver the implementation contract

1. Label approved C decisions, inherited main behavior, reversible defaults and remaining consequential conflicts separately. Replace old statements such as “no General,” “manager must be invited,” “history only since admission,” and “former users lose all history.” Keep historical reports as historical evidence.
2. Define current and former access for: Group Creator/Co-creator/Co-organizer, ordinary member, Discussion Creator, invited nonmember of the room, admitted planner, Project-only participant, former planner, blocked users, erased accounts and staff. Separate metadata discovery, message history, live roster, mutable links, sending, room administration, notifications and Project publication.
3. Model the Group People union and true room membership separately. Preserve independent membership/delegation. Manager oversight is not automatic normal participation or a grant to read private member/representative chats. Specify how an oversight reader's actual history frontier is recorded, without granting every former manager every unknown room forever.
4. Define one durable General per Group; two Idea visibility modes; setting changes; targeted/link invitations; explicit Join; full earlier history; end-of-entitlement sequence boundaries; fresh rejoin; private source freeze after conversion. Keep Group suppression/lifecycle overrides distinguishable from user hiding.
5. Specify notifications by recipient predicate: new Group-visible Idea, new invite-only Idea, targeted invitation, new message, conversion proposal/result and Project invitation. Include mute/hide/exit and retry deduplication. Define whether each is a structured request, activity notification or human unread; it cannot be all three by accident.
6. Specify conversion as **private proposal/review → actual publisher's private Project draft → successful public publication → frozen planning origin + opt-in Project invitations**. Use one source-to-Project association with recovery; retain Project author and normal chat activation. A draft/save alone causes no membership or invitation.
7. Map the two-history view and link audiences: original planners, former planners, new public Project participants, Group managers without Project entitlement and Project managers without Group entitlement. No backdoor through exact-message reads, old RPCs, preview/unread, report context or private origin IDs.
8. Publish lane-specific interface notes: actual endpoints, signature evolution, domain kinds, shared files/migrations, expected pending peer interfaces and required tests. These are discoverable from your pushed PR, not manual founder relays.

## Required worked example

Alice is Group Creator; Bea is an ordinary member who creates an Idea after the setting permits it; Carlo joins that Idea; Diana is outside the Group. Alice reviews/publishes; Bea and Carlo receive Project invitations. Bea declines; Carlo explicitly joins; Diana later joins the public Project. Bea retains only authorized frozen planning history, Carlo may see both segments, Diana sees Project history only, and Alice's future replacement as Group manager inherits only the disclosed Group oversight—not automatic Project authority or private D chats.

Add equal-time exit/send, removal/rejoin, manager-only-to-member role change, hidden/muted-room and invite-link misuse cases.

## Acceptance and handoff

Commit the revised contract and concrete migration/reader/test checklist. No runtime work is required in this documentation stage. Proceed to implementation using it; a genuine unresolved C conflict stops only its dependent mutation/audience, not the whole lane or the peer. Do not merge R00 alone as “Batch C complete.”
