# Product Decisions

**Status:** Accepted product decisions that supersede older tentative wording until the owning implementation plans fold them into canonical domain documentation.

## Project group chat

Current product direction:

- A proposal/project group chat is created automatically by the system. There is no user-facing manual **Create chat** action.
- The **first accepted join request** activates the chat transactionally. The creator plus that first accepted participant is sufficient; there is no fixed three-person threshold.
- There is exactly one canonical chat per Project. Later acceptances and rejoins reuse it.
- The immutable Project creator has persistent organizer entitlement without a participant-membership row. A current accepted participant has current/send entitlement.
- Voluntary leave or creator removal ends an ordinary participant's current entitlement immediately but retains each exact accepted membership interval for historical authorization. Rejoin creates another interval, and the gap is not membership time.
- Project completion, Tavolo pause/end, or every participant leaving does **not** delete the chat anchor or its future authorized history.
- Blocking, suspension, moderation, and content-action overrides remain Plan 09.
- The product's existing end-to-end-encryption requirement applies to Project chat. Plan 07B1 therefore stores no plaintext, ciphertext, keys, or message placeholders.

This decision supersedes the older tentative `chat after at least three people` wording in `docs/architecture/system-design.md` and the threshold-gated chat wording in `docs/implementation/roadmap.md`. Future implementation plans must use this decision unless it is explicitly revised.

### 07B2A architecture validation (not founder-approved product policy)

The real 07B2A OpenMLS prototype validates RFC 9420 MLS as the recommended E2EE
architecture and demonstrates that a client joining at a later epoch cannot
decrypt earlier application messages. It also demonstrates that removal followed
by a fresh rejoin does not expose messages from the removed interval.

Therefore the architecture recommendation is that a participant sees Project
chat messages only from periods in which an authorized crypto client/profile was
an MLS member, with no pre-first-join history and no server historical-key escrow.
Founder confirmation is still required before this becomes accepted product
policy or production message-read behavior. Package production-readiness,
multi-device recovery, and key-loss UX also remain unresolved implementation
gates; they are not founder decisions inferred by the prototype.

## Projects and participation

Current product direction from the 08/09 founder discussion:

- **Progetti** is the user-facing umbrella concept for both one-time Projects and recurring Tavoli. Their concrete backend models remain separate because their lifecycle and scheduling rules differ.
- Participation is one shared project-level domain across both concrete types. A join request is an attempt; creator acceptance creates canonical membership history. Creators remain organizers through ownership rather than duplicate membership rows.
- Participation and resources/contributions are related but separate. Future resource offers may attach to a stable join-request ID, but membership does not imply resource ownership or delivery.
- Accepted membership is not proof of contribution. A future 05C flow should let the creator confirm who actually contributed after completion before contribution credit, badges, or resource attribution are derived.
- Online and In-Presence project modes are accepted future direction. Current project schemas remain physical-location oriented; the participation model stays location agnostic until a focused project-presentation/schema plan implements the mode.
- Capacity and **Pieno** behavior remain unresolved. There is no maximum-participant rule, waitlist, automatic fullness, or role quota yet.

Ordinary withdrawal, voluntary leave, and creator removal are not permanent bans. A person may submit a fresh request while the project is eligible and they have no pending request or current membership. Blocking and moderation remain later work.

## Messages, participation requests, and notification alerts

Current product direction from the 08/09 founder discussion and follow-up clarification:

- A join request appears as a persistent structured actionable item in the authenticated mobile Messages surface, backed by canonical `project_join_requests` state rather than copied into a free-form chat message.
- The structured request item may display its private requester message to the authorized creator. Accept/Reject actions must continue to call the canonical participation transitions and render the resulting request state.
- A participation notification is only an alert and entry point. Request-specific notifications retain `request_id` and use a semantic `participation_request` target; the mobile client resolves it to `/messages/requests/:requestId` without storing a Flutter route in PostgreSQL.
- The existing Participation screen remains the organizer's secondary overview for all request history and member management. It is not the primary arrival surface for new requests.
- Project group chat is separate from pre-acceptance request items. Plan 07A implements only the Messages request surface; 07B1 owns the accepted lifecycle/authorization foundation, while 07B2 owns message persistence, Realtime, and mobile chat after its encryption and pre-join-history decisions.

## Pending requests in Browse

For a signed-in user, a Project or Tavolo with that user's pending join request is surfaced ahead of ordinary mobile discovery results and visually distinguished with a **Requested** badge and theme outline. This applies only to currently pending requests whose project remains publicly discoverable under the active filters, not historical accepted, rejected, or withdrawn attempts. Exact ranking relative to projects the user owns or already participates in remains later UX work, signed-out/public ordering is unchanged, and the public web is not personalized. The treatment is a convenience/status signal rather than a second participation state machine; Messages remains the canonical request history and action surface. Plan 05D implements this accepted direction in merged PR #24.
