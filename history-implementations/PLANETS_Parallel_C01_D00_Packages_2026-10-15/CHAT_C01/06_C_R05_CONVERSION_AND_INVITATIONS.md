# C-R05 — Reviewed publication, durable conversion and opt-in Project invitations

## Objective

Replace C04's ordinary disconnected Project-creation shortcut with a real, recoverable Group-Idea-to-Project transition. Preserve Option A and the existing publisher/participation contracts. Depends on C-R00–R04 and merged GRP03C.

## Proposal, review and actual authorship

An eligible Idea Creator can propose a Project using a reviewed title/summary. All current Group managers can inspect/review the proposal; Co-organizer endorsement is not publication permission. Current Group Creator/Co-creator may deliberately take responsibility as the actual human Project Creator and use the existing private draft editor. Do not impersonate the original Idea creator or transfer private draft ownership because a reviewer clicked Approve.

Show **Request publication**, **Review**, and actual **Publish** according to roles. Existing direct group-attributed Project creation remains available to publishers. Ordinary members are not forced to create a fake public Project simply to plan privately.

Keep the source Idea active while a proposal/private draft is pending. Opening an editor, saving a draft, selecting a Group or endorsing a proposal does not freeze the source, publish anything, create invitations or enroll anyone. Preserve meaningful-draft save/exit and accepted-but-lost creation recovery.

## Canonical conversion and race safety

Persist a private, stable source/proposal/Project association. One Idea must not create two published Projects because two managers race or a response is lost. Decide the lightest safe representation from the repository; no prescribed universal entity/table rewrite. A bound private draft remains owned by its real author. Do not resolve a abandoned draft or publisher role loss by silently granting a new manager its private draft; report/handle the canonical conflict through an explicit recoverable state.

Before successful first publication, recheck the actual publisher, Group identity/state, source room, source conversion state, draft/revision, current Group attribution and canonical publication requirements. Use the existing transactional publication boundary with safe lock ordering; freeze conversion at the committed room sequence. A partial failure must not publish personally, freeze an unpublished source forever or let an old retry bind to a different Project.

On successful publication: make the source planning phase read-only, record the immutable conversion boundary/Project association, and create a durable invitation projection intent for the eligible original planners. Outbox fanout may be bounded and resumable, but its source audience/action must be stable; do not invent a public snapshot of all room members. No live C message is copied into `project_chat_messages`.

Public creation with undecided logistics uses existing Idea/Defined behavior. No new fake date/place, automatic promotion to Defined or public “Discussion” type. Preserve templates, location privacy, capacity and first-accepted-participant Project chat activation.

## Option A: invite every eligible planner; enroll nobody automatically

Eligible current room participants (including its active ordinary creator), not every Group member/manager and not former-only members, receive a contextual Project invitation once. Skip duplicate invitations for already accepted participants or identities that are no longer eligible. Source replay or projector retry must not flood notifications.

An invitation opens the normal Project detail/join flow and requires a deliberate action. For this revision prefer the existing ordinary Project Join route, preserving organizer review, profile/photo, capacity and blocking; the invitation is an invitation to participate, not a new preapproved admission token. Do not switch to direct-admission semantics incidentally. A separately explicit canonical special-link flow may be reused only with its established meaning clearly shown, not by silently encoding a bypass.

No membership inserts, capacity reservations, participant stats, delegate roles or contribution commitments occur from conversion, a notification, a preview or login restoration. Ignored/declined invitation means no Project membership. If capacity fills or a block/role rule changes, Join fails honestly through canonical state. A prior room admission does not override it.

A person who leaves the Group before acting may still have ordinary public Project access, but cannot recover private Group context from the old invitation. Do not put room ID/title/message/link/member snapshots into public URLs or generic alert payloads. Public Project invites never invite people into the Group.

## Interface and traceability

Provide the review queue/entry for eligible managers, source status, genuine author/publisher attribution and transition result. Keep C-R06 source/Project view contracts narrow and independently authorized. Update existing C04 helpers rather than keeping competing disconnected creation actions for the same intended operation.

## Verification

Alice/Bea/Carlo/Diana scenario from R00; member/Co-organizer publication denial; two publishers racing; lost draft or publish reply; duplicate projector delivery; source archive/suppression; changed Group/author; pending vs published states; all planners receive at most one invitation and **zero automatic memberships**; approval/capacity/block rules on explicit Join; cancelled/full public Project; private Project draft exclusion from public Group feed; no source IDs in public readers. Include replay through old publisher APIs so a legacy path cannot bypass conversion integrity. Stage code/types/tests/docs remain in the C cumulative lane.
