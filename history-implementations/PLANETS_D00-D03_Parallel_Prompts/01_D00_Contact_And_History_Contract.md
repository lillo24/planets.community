# D00 — Resolve the contact, recipient and history contract

Read the coordinator. This is a bounded contract/review milestone, not permission to invent founder approval. Start from fresh main on the D-owned checkout. Do not change live behavior in this stage.

## Goal

Produce one compact actor/access matrix, state diagram and three worked examples covering: an initial contact request; a representative losing their role; adding a third group. Make the downstream D01–D03 implementation unambiguous and independent of C.

Use the real group role helpers, exact-self context, public attribution, profile audiences, existing pair/Project/Resource chat rules, Messages discriminators, unread receipts, reporting and block lock order. State the actual functions and extension points discovered. Do not equate published Project authorship with current group representation.

## Explicit decisions required

| Decision | Alternatives to distinguish | Why it matters |
| --- | --- | --- |
| Who may initiate? | Group representative only; or individual-to-group idea proposals too | User suggested the latter as an option, not a settled unrestricted contact right. |
| Which groups? | All eligible registered informal/formal groups; or an explicitly supported subset | The existing model does not provide legal-representative verification. Do not invent an "official organization" check. |
| Who receives? | Shared manager inbox; or a named representative already visible in the current context | A public group page cannot reveal the private People list to populate a picker. |
| Who reads the request and accepted chat? | Pending managerial triage versus exact accepted participant set | Permission to review a group request need not include the resulting conversation. |
| Replacement/role loss/history | No automatic inheritance; bounded prior history for former people; or explicitly shared organizational history | These are different disclosure/retention policies, not equivalent UI choices. |
| Multi-group expansion | New linked conversation; or in-place expansion with explicit audience consent and history boundary | Accepting on behalf of one group cannot expose another group's earlier private discussion by default. |
| Blocking and lifecycle | New-interaction barrier plus defined existing-chat effects | Group archive/suppression, orphaned Creator, changed managers and mixed blocking need explicit treatment. |

Also define close/leave/reopen semantics, repeated declined requests, finite spam limits/cooldowns, request expiry or deliberate no-expiry, correction/deletion handling and safe own-action recovery. Reuse applicable existing limits where their semantics fit; do not invent a legal retention policy or a trust score.

## Proposed baseline for the review-only implementation

The following is a **recommendation**, not a previously approved decision. Use it for a coherent provisional local stack only if no later explicit decision supersedes it. Record any departure and rationale in D00 before downstream code diverges.

1. **Group-to-group first.** The sender chooses one currently eligible represented group. Include the existing eligible registered-group types without new legal verification. Individual-to-group proposals remain deferred, with no visible dead button; preserve an extension boundary rather than an exposed unauthorised endpoint.
2. **Address the destination group, not its private roster.** A bounded inbox lets current authorized target managers review pending requests. The sender is told who can read the submitted note. A source manager's Submit is consent to a purpose-bound conversation with the target group's accepting representative, not to chat with all target members.
3. **One explicit acceptance.** The first eligible target manager to accept becomes the initial other participant. Acceptance is atomic; concurrent accept attempts resolve to one canonical result. Only the submitting person and accepting person enter the thread. Other managers do not automatically receive chat content, previews or unread counts. Define the minimal resolved request metadata still visible for duplicate-triage prevention; do not leak messages through it.
4. **Personal authorship plus fixed represented-group context.** Every message records the actual human and the group represented at send time. A later role/name change never rewrites provenance or portrays a current legal affiliation. A person managing both groups cannot create a self-contact conversation or accept their own request.
5. **No inherited history.** Replacement managers are not automatic thread members. Revoked/stepped-down representation invalidates live reads/sends for that role-bound D access; regrant does not silently restore it. Retain database records according to existing policy, with metadata-only own recovery and an appropriate safety-report path. The exact former-read policy remains a review item; this provisional rule must not change the existing Project/Resource history contracts.
6. **Explicit fresh multi-group room.** For D03's provisional implementation, collect consent to the exact new participant/group set and create a linked coordination conversation with a fresh history. Original conversations stay unchanged; no history, draft, links or participants are copied automatically. This sacrifices a seamless in-place conversion to avoid invisible audience expansion.

For pending manager-inbox reads, resolve how a newly appointed manager gains visibility and what happens when a newly involved manager is blocked. For accepted chats, define sending/reading on role loss, group archive/suppression or orphaned accountable identity. Reuse neutral errors and existing lock conventions; do not infer a block direction in copy. For the proposed baseline, suspend new D communication when its approved role/group eligibility fails, without deleting history or altering independent membership. Record how eligibility restoration differs from role revocation/regrant.

Choose and document an implementable finite spam-control policy for the provisional model: pending duplicates, actor/group quotas, rejected-repeat cooldown and message size/rate bounds. Make them centrally bounded and testable. The approved contract must state the final values and exceptions before activation, not hide them in SQL literals.

## Contact entry and purpose contract

For an ordinary Project/Tavolo context, "Ask to participate" means the existing join flow; it does not create D messages. For a group context, use the existing group-join flow. Clearly distinguish "request to join this activity" from "propose an idea to this group."

A compact profile sheet may show a messaging/contact action only when its current context identifies a real eligible group and a canonical action is available. Do not assume every Project manager represents its attributed group, or reveal unrelated affiliations just because a profile was clicked.

Prototype purpose choices are "Propose an idea" and "Propose collaboration", directed to the group. A short title, bounded private note and optional reference to the already-public Project/Idea supply context. A reference is not permission to read private Project details, and the private proposal is not a publicly published PLANETS Idea.

No generic "other" purpose that becomes unrestricted DMs. Keep wording concise in EN/IT. A label plus icon/menu is preferable to an unexplained message icon. Do not add a paid classification or automated proposal-analysis system.

## Required outputs

Create a domain decision record containing: fixed versus provisional choices; exact audiences for every projection; command/state transitions; link between group authority and thread admission; former/new member history; lifecycle/block effects; rate/duplicate policy; integration owners; narrow test examples. Include a small review table with only unresolved decisions and a recommended answer for each.

Make approval status machine-obvious to the next stage (for example a simple Markdown field and explicit approval reference); no new approvals service or fake signature is needed. This is provenance, not a security runtime feature.

If approval exists, cite it precisely and proceed under that contract. Otherwise push D00 draft, continue only under the coordinator's provisional local-only permission, and carry the unresolved review gate to the final PR. Never silently mark the contract "accepted" because the user asked for the D batch.
