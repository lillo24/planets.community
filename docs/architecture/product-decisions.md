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
- A Project chat is a durable coordination log. The creator and every current accepted participant can read its full existing message history, including messages sent before that participant first joined.
- After leave/removal, a former participant retains messages through the end of their latest membership but cannot read newer messages or send. Rejoin restores the full accumulated history, including the gap; a later end advances the retained-history frontier.
- Project chat uses ordinary authenticated, server-authorized plain-text messaging for the MVP. HTTPS/TLS protects transport and database/API authorization restricts access, but the PLANETS backend remains technically capable of reading stored message bodies. This is not end-to-end encryption.
- MLS/E2EE was technically prototyped in unmerged PR #28 and is deferred as an optional future privacy enhancement. The prototype is research, not an implementation dependency or current MVP requirement; future E2EE may introduce a versioned message format.
- Blocking, suspension, moderation, and content-action overrides remain Plan 09.

This decision supersedes the older tentative `chat after at least three people` wording in `docs/architecture/system-design.md` and the threshold-gated chat wording in `docs/implementation/roadmap.md`. Future implementation plans must use this decision unless it is explicitly revised.

## Projects and participation

Current product direction from the 08/09 founder discussion:

- **Progetti** is the user-facing umbrella concept for both one-time Projects and recurring Tavoli. Their concrete backend models remain separate because their lifecycle and scheduling rules differ.
- Participation is one shared project-level domain across both concrete types. A join request is an attempt; creator acceptance creates canonical membership history. Creators remain organizers through ownership rather than duplicate membership rows.
- Participation and resources/contributions are related but separate. Projects define stable resource-need IDs independently of join requests and membership. A join-request attempt may retain selected canonical Proposal-skill IDs and Project resource-need IDs, but membership does not imply resource ownership, delivery, or an ongoing commitment.
- Accepted membership is not proof of contribution. A future 05C flow should let the creator confirm who actually contributed after completion before contribution credit, badges, or resource attribution are derived.
- Online and In-Presence project modes are accepted future direction. Current project schemas remain physical-location oriented; the participation model stays location agnostic until a focused project-presentation/schema plan implements the mode.
- Capacity and **Pieno** behavior remain unresolved. There is no maximum-participant rule, waitlist, automatic fullness, or role quota yet.

Ordinary withdrawal, voluntary leave, and creator removal are not permanent bans. A person may submit a fresh request while the project is eligible and they have no pending request or current membership. Blocking and moderation remain later work.

## Project resource needs

Current 04C3A product boundary:

- Proposal and Tavolo share Project-owned resource needs through `public.projects`; needs are not participants, join requests, memberships, contribution offers, or Scambio-Dona listings.
- Each need has a stable UUID, a creator-defined trimmed title, optional plain-text details, and exactly `open` or terminal `closed` state.
- `open`/`closed` says only whether the Project is still asking. Closure does not mean fulfilled, supplied, delivered, verified, or credited.
- Public reads expose open needs only while the concrete Project is currently joinable. Creators retain open/closed history after the Project becomes historical.
- There is no taxonomy, type, quantity, unit, condition, price, priority, contributor attribution, join-request linkage, Scambio-Dona linkage, free-form unsolicited offer, or notification projection.
- 04C3B1 lets join requesters select canonical Project competence IDs and open resource-need IDs; the optional participation-request message remains the only free-text request content. Proposal `required` and `useful` skills are eligible, while Tavoli remain resource-only until a separate canonical Tavolo skill-requirement domain exists.
- These selections are immutable request-attempt history. Withdrawal, rejection, acceptance, later Proposal-skill removal, resource renaming, and resource closure do not rewrite them. A repeated request starts independently.
- Mutable post-acceptance availability/commitments and creator verification are separate future concepts; neither may repurpose request-selection history.

## Scambio-Dona listings

Current 04C1 product boundary:

- Standalone Scambio-Dona listings use exactly `donate` and `exchange` as public discovery intents.
- `exchange` does **not** define lending, barter, ownership transfer, return, payment, reservation, contact, or handoff mechanics. Those remain founder-owned decisions for a later request/handoff plan.
- Owners manage a small `draft` → `published` → terminal `closed` lifecycle. Closing means only that a listing is no longer publicly available; it is not proof of a successful donation or exchange.
- Public listing data contains plain-text title/description and rough `country_code`, `locality`, optional `administrative_area`, and `public_location_label` only. Exact location and contact data are absent.
- Public detail follows the existing profile display-name visibility decision; publishing a listing does not make a private display name public.
- Resource taxonomy, quantities, prices, condition grades, media, Project linkage, requests/handoffs, saved searches, matching, and resource notifications remain deferred.

## Messages, participation requests, and notification alerts

Current product direction from the 08/09 founder discussion and follow-up clarification:

- A join request appears as a persistent structured actionable item in the authenticated mobile Messages surface, backed by canonical `project_join_requests` state rather than copied into a free-form chat message.
- The structured request item may display its private requester message to the authorized creator. Accept/Reject actions must continue to call the canonical participation transitions and render the resulting request state.
- A participation notification is only an alert and entry point. Request-specific notifications retain `request_id` and use a semantic `participation_request` target; the mobile client resolves it to `/messages/requests/:requestId` without storing a Flutter route in PostgreSQL.
- The existing Participation screen remains the organizer's secondary overview for all request history and member management. It is not the primary arrival surface for new requests.
- Project group chat is separate from pre-acceptance request items. Plan 07A implements only the Messages request surface; 07B1 owns the accepted lifecycle/authorization foundation, while 07B2 owns message persistence, Realtime, and mobile chat after its encryption and pre-join-history decisions.

## Pending requests in Browse

For a signed-in user, a Project or Tavolo with that user's pending join request is surfaced ahead of ordinary mobile discovery results and visually distinguished with a **Requested** badge and theme outline. This applies only to currently pending requests whose project remains publicly discoverable under the active filters, not historical accepted, rejected, or withdrawn attempts. Exact ranking relative to projects the user owns or already participates in remains later UX work, signed-out/public ordering is unchanged, and the public web is not personalized. The treatment is a convenience/status signal rather than a second participation state machine; Messages remains the canonical request history and action surface. Plan 05D implements this accepted direction in merged PR #24.
