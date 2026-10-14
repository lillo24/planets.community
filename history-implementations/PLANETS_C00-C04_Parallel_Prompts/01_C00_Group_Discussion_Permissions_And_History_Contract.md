# C00 — Group discussions: permissions, membership and history decision contract

Read the Batch C coordinator. This is an **authorization/product gate**, not permission to silently set all details.

## Objective

Describe exactly whose data a permanent-Group discussion belongs to, who may see/join/send/rename/manage, how invitations and historical message access work, and what happens across role loss, membership leave/rejoin, suppression/archive, group owner deletion and account erasure.

Produce one small actor/room/state matrix and one end-to-end example. Inspect implemented GRP03A/B's separate membership episodes and manager authority, GRP03C attribution, actual Project chat history frontier and current deletion/reporting rules. Preserve the distinction between a persistent Group and every Project attributed to it.

## Fixed requirements

A registered Group owns discussions. Personal Auth accounts are immutable senders. Group membership must not silently enroll a person in every Project or expose every discussion. No global public/group chat browse, unprompted direct contact, automatic public publication or general-purpose personal new-chat picker.

A lightweight Messages folder organizes conversations by Group. The chat need not be an independently registered Group; it is an internal named planning space. Membership and role rights are checked on every protected durable read/write, not only when a WebSocket subscribes.

A human with canonical **group Project-publishing** authority may create a linked Project through normal GRP03C drafting. Group Co-organizer's operational role does not automatically supply that right.

## Provisional restrictive contract for isolated implementation only

This is a **recommendation, not approved founder policy**:

1. Only eligible published, nonsuppressed Groups have active discussions. A Group manager (Creator, Co-creator, Co-organizer) can create a room and invite currently entitled Group participants/managers. An invited person must explicitly accept before content/history is disclosed; room creation does not notify the entire group roster. Do not auto-create or auto-join a Group-wide General room in v1.
2. Room creator is admitted explicitly at creation. Members who leave or are removed from the Group lose current room access; authority-only managers remain eligible while their role is current. Manager step-down/revocation removes the corresponding role-derived ability without blanket user suspension.
3. Each admission binds a concrete current Group membership/authority episode. A later rejoin or renewed manager role is a *new* episode and does not resurrect old room entitlement. A new invitation and acceptance are required. Revoke a pending room invite when its target relationship is no longer current.
4. For a newly admitted person, older room messages are **not** exposed by default. A history frontier begins at accepted admission; old participants may retain their earlier history only while continuously and currently entitled. On removal/leave, deny all private room content, including earlier history, previews and unread counts. Do not retain an offline former-member reader without separate approval.
5. Room participants may send text while both current Group and room eligibility hold. Room creator/managers can rename/archive and manage invitations (exact delegate rights to be checked against canonical roles); ordinary participants cannot promote themselves or invite unrelated accounts. Archived rooms are read-only for currently entitled members; suppressed/unavailable Group access fails closed except explicit staff evidence access.
6. No automatic invitation to a room merely by joining a Group. No member-count/popularity public signal, room discoverability or public People roster. Any future all-member room is a separate explicit decision with its own history rule.
7. Current privacy policy and erasure/retention semantics apply; do not invent a fixed retention period, synthetic transfer of ownership or destructive cascade. Report rights require their own evidence capability.

## Decisions that must be recorded

Compare the proposed model to alternatives: all-member General room, automatic admission, members creating rooms, history for later joiners, former member limited read-only history, managers inheriting prior rooms, archived/suppressed behavior and ownership transfer. Note tradeoffs, feasibility within current backend and exact approvals already visible.

Record: actor-role table (guest, pending, current member, each manager, room member, former member, new member/rejoined, blocked, staff/report authority); operations (list, create, invite, accept, leave, send, rename, archive, read history, unread, report); message frontier and revoked-entitlement behavior; and room lifecycle.

If approval is absent, label C00 PROVISIONAL. Implementing C01–C04 in an isolated draft with synthetic actors is permitted but **final C merge is blocked** until the founder explicitly accepts or modifies this contract. Do not claim approval based on this prompt, inferred friendliness of the design or green tests.

If an already approved Group discussion policy exists on latest main, cite it and reconcile rather than generating another incompatible one.

## Deliverable

A short decision memo and tables under docs/development/, a clear pending-approval checklist, and first C draft PR. No live feature/public schema activation from C00 alone.
