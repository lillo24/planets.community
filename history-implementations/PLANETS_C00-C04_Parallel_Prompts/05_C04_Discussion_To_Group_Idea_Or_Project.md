# C04 — Create an Idea/Project from a Group discussion

Read C coordinator, C00 authority contract, C01–C03 and current GRP03C code. Start from the verified C03 head; no early main merge.

## Objective

An eligible user planning inside an internal Group discussion can press “Create Project” (or “Turn into Idea/Project”), open a **reviewable ordinary proposal draft**, and deliberately save/publish it with explicit registered-Group attribution. The planning room survives, remains private, and can link to the resulting Project as a convenience. The action is not a destructive chat conversion or publication of its transcript.

## Canonical permission boundary

GRP03C currently allows **Group Creator and Co-creator** to select group attribution and publish a new Idea/Defined Project/Tavolo, subject to their personal identity/photo and the existing Project publisher rules. Do not silently give Co-organizers this power: previous discussion allowed Co-organizers to communicate for the Group, which is independent from structural Project publishing. If Group Co-organizers should initiate a suggestion for review, that requires a separate explicit approval flow, not a bypass.

Only show enabled Group-attributed creation to a current authorized human with existing canonical editor/publishing rights. Membership in the planning room alone does not grant group publication. After a role or Group lifecycle change, deny unauthorized final creation even if an old draft UI remains open.

## Draft and linking flow

1. From a currently authorized room, choose Create Idea/Project. Open the existing scratch/template chooser/editor with Group attribution deliberately preselected through merged GRP03C APIs; record source room context only in private state.
2. Suggested title/summary may be prefixed from **explicitly supplied fields/user-selected text**, not an automatic transcript scrape or paid AI summary. The person reviews and edits. Simply opening the flow or choosing a Group must not create an empty Project.
3. Existing Editor creates the canonical Project and person-owned receipt; Idea remains the planning-phase Project, using regular publish/confirm/promote behavior and the existing privacy/photo gates. No parallel “Group idea” entity or bespoke Project chat is created.
4. After a confirmed canonical Project ID, save a narrow authorized room→Project association (if useful for navigation) through an independent idempotent stage. It may be recorded as soon as an attributable draft exists, but never expose draft identity to unauthorized room members. Public Project details use only GRP03C's public approved projection after publication.
5. If Project creation succeeds but association fails, keep the confirmed Project ID and recover the link stage with the same action/intent. Do not create a duplicate Project or falsely report failure of the Project itself. A link may be created later without sacrificing existing content. Leave room untouched on cancel or partial failure.
6. **Do not auto-copy any room messages, attachments, room member list or private link collection.** If the user explicitly chooses one or more room workspace links to copy, show the Project audience and destinations for review and confirmation; apply Project workspace server rights independently. A member without Project rights cannot exploit linking to disclose the room.
7. Do not enroll room or Group members in the Project, invite them automatically, or move their existing chats. Normal Project invitations/requests establish Project participation. The Project's group chat remains its own private space with separate current eligibility.

## Visibility and navigation

Inside the private room, entitled viewers may see a safe public Project link after publication if their existing Project public-detail access allows it. Unpublished drafts are available **only through canonical Creator/private draft rules**, not via group-room association. If the Group becomes archived/suppressed or a member leaves, no room association leaks private source text/IDs. A published Project may retain its existing group attribution even if the source room is archived; this does not grant former room members ongoing Project management.

Provide loading, result/retry and cancelled states with honest partial-success messaging. Return to the originating room without losing its scroll/history or accidentally completing a different pending invitation. EN/IT and narrow screen/large text must remain usable.

## Concurrency and validation

Use GRP03C's actor/project creation idempotency receipt and publication locks; any separate association is versioned, actor-checked and idempotent. Check role/Group/room eligibility at action time and after waits, and don't let a cached Group choice falsely authorize publication. Handle loss of room rights or creator account between room open, draft creation, link stage and later publish.

Test authorized Creator/Co-creator, Co-organizer denied, ordinary member denied, inactive/suppressed group, draft vs published, dropped creation reply, dropped association reply, change of room while pending, account switch, explicit link-copy privacy and no copied messages/members by default. Preserve standalone personal/Group Project creation and template application. Real local Auth/RPC and Flutter native review are required at final gate.

## Deliverables

An explicit user flow, affected domain code and tests, safe room→Project link contract where chosen, precise partial-success recovery, privacy/authority coverage and documentation. Push C04 draft PR; stop before final main merge pending C00 approval and final integration checks.
