# Send this package to your existing D00 Codex chat

**Task:** Finish the Group-contact lane and add the requested Group-scoped member-to-member contact work, in parallel with the C01 chat. Follow `00_SHARED_EXECUTION_CONTRACT.md` and the eight stage prompts below. The D00 chat is the implementation owner for the complete lane, not merely a document author.

## Scope and base

Reinspect and reuse cumulative D #254 (`codex/d-integration`, last inspected `db17cd2d5eae0b502243c885e08cbe33b3472c04`) and D00–D03 ancestry. Existing code already implements representative requests, bilateral chats, multi-group consent, typed Messages/safety integration and some native QA. Reconcile current main and repair remaining work; do not rebuild D or cherry-pick only the first stage because this chat is called D00.

The **C01 chat** revises Group General/Ideas, room invitations/history, folders, links and Idea-to-Project conversion. It may merge before or after you. Your member-contact work uses already-merged Group People/roles and **does not wait for C to merge**. Do not import C's unfinished branch. If C lands, integrate its shared changes and test the combined result. The first complete, approved and validated lane may merge first; no third integration chat is required.

## Requested behavior already established

- Group Creator, Co-creator and Co-organizer may represent their Group for purposeful inter-group contact. Ordinary Group membership does not grant representation. Co-organizer contact permission is not GRP03C publishing permission.
- Inter-group communication is between authorized humans with their Group context, not automatic membership in both Groups or a public generic direct messenger.
- People in a Group may request a private conversation with another current Group person without a Project/join-request prerequisite. Recipient acceptance is explicit. This is **personal member contact**, a separate domain from acting on behalf of an organization.
- A compact profile/person sheet and understandable contextual action menu are wanted. Where relevant, participation uses the existing join mechanism, proposing collaboration uses representative contact, requesting a personal conversation uses the shared-Group consent flow, and inviting to an Idea uses C's room operation. Do not conflate their permissions because they share an icon.
- Group membership gives access to the Group's private People list under its existing rules, not a new public user directory or public disclosure of affiliations/photos.
- Invitations/requests must be clear, deliberate, recipient-visible and reportable. Selecting a person, opening a screen or completing login never sends/accepts one automatically.
- No arbitrary global user-created group chats. Multi-group coordination remains a purpose-bound, invited representative feature.
- Personal accounts remain the actors; no Group passwords, fabricated sender identities, public person ratings, new mandatory personal data or paid messaging provider.

These choices do **not** grant Group managers oversight of private member-to-member conversations. The C rule “managers can always see Ideas” applies to Group planning rooms, not all communication between Group members.

## Precise remaining approval boundary

The old D00 contract explicitly marked several choices provisional. The current instructions authorize parallel work and source merging when ready; they do not silently settle all those privacy choices. Inspect actual later user decisions already in this Codex chat/repository before reporting a gap.

Still unresolved in the supplied conversation: whether pending representative notes go to all target managers or a named representative; whether accepted chats are only the first acceptor or shared across managers; historical access after role loss/regrant/replacement; exact multi-group audience disclosure/history; and continued personal messaging/history after leaving a shared Group. Individual-to-Group proposals outside shared membership were discussed tentatively, not universally approved.

D-R00 and D-M00 provide concrete review choices and bounded provisional test directions. **Do not relabel an assistant recommendation, this package's example, existing draft code or green CI as user approval.** Finish synthetic implementation/verification for unresolved scopes, but leave those source changes isolated and unmerged until the necessary decision exists. Continue independently mergeable, approved work rather than stopping both chats. Report a narrow missing decision instead of a generic “manual approval required” banner.

This is not a fresh request to ask all 16 C questions. C's supplied General/Ideas and conversion rules are settled and belong to the other chat.

## Context from the parallel C lane that you must preserve

C will add automatic pinned General; configurable member Idea creation; Group-visible/invite-only Ideas with manager oversight; full earlier room history after entry and bounded former history; structured Idea invitations/notices; Group folders with Projects plus General & Ideas; separate hide/mute; Group/room links; and conversion to public Project with opt-in invitations and separately protected planning/Project history.

Do not apply C's full-history or manager-oversight predicates to member or representative chats. Do not merge its private planning messages into a contact room or give new representatives Project membership. C's member picker may call your consent-based member action once it exists; your person sheet may call C's invite-to-Idea action once C exists. Keep these as shallow integrations over each domain's canonical operations, not mutual build-time dependencies on unmerged code.

## Sequence and delivery

D-R00 decisions/current delta; D-R01 existing representative contact; D-M00 member-contact policy; D-M01 member backend; D-M02 contextual People/UI; D-R02 multi-group coordination qualification; D-R03 Messages/notifications/C integration; D-R04 final validation and source merge.

Read D-R00 and D-M00 before changing persistence. Approved independent tasks can proceed out of order where their actual dependencies permit. A policy-blocked M/D feature may remain an isolated draft while a complete approved subset merges, but must be listed as not delivered. Do not claim the whole package merged if that is not true.
