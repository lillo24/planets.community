# Send this package to your existing C01 Codex chat

**Task:** Revise and finish the complete Group Ideas / General / conversion implementation, in parallel with D00/contact work. Follow `00_SHARED_EXECUTION_CONTRACT.md` and C-R00 through C-R07 below. Do not stop after writing a plan; perform the authorized implementation, verification and final source merge when its gates are satisfied.

## Why this is a revision, not a new chat platform

The existing C cumulative PR #257 already contains rooms, invitations, admission-bound messages, folder UI, private links, reporting and an ordinary Project-creation entry. Reuse that source and its preservation tests. Its provisional rules deliberately denied General, ordinary-member creation, manager-wide access, earlier history and former-member history. The founder has now chosen different C rules; revise SQL, readers, notifications, UI and tests together.

Your peer's **D00 chat** handles consent-based personal member messaging and Group-representative contact. It can proceed against the already-merged Group People/roles without waiting for C. You may merge first. If it has merged before you finish, integrate it and validate both. Do not merge its unfinished branch or overwrite its contact audiences.

## Approved requested behavior — preserve all of it

1. Every eligible published Group has exactly one automatic, durable **General / Generale** conversation. It is clear, emphasized and pinned first in **General & Ideas**. Group-wide workspace/external WhatsApp or Telegram links should be easy to discover, including a brief first-visit hint and authorized Project-detail entry where relevant.
2. Group Settings chooses who creates Ideas: managers only or any current member. Starting an Idea is proposing/planning, not publishing. Explain this with clear labels/help. Group creation offers **Idea/discussion** and **Project**, without implying that ordinary members can publish for the Group.
3. Idea Creator chooses **Group-visible** or **invitation-only + Group managers**. All current Group managers can discover, enter, read and manage every Idea. Disclose that oversight before creation/joining; do not label invite-only as private from managers. Other Group members see eligible summaries and choose whether to join.
4. Invitations require explicit acceptance; they appear as structured invitations in Messages/Requests and as notifications. Creation notifies current people eligible to discover the Idea. Managers receive the appropriate creation notice; private Ideas are not broadcast to all members.
5. Discussion Creators and Group managers manage their Ideas. Other admitted members do not thereby gain editing/deletion or publication authority. Outsiders must become Group members before entering a Group Idea.
6. Admitted newcomers see the Idea's full earlier history. Leaving/removal preserves only permitted pre-exit history, read-only: no new messages, current protected collections, live member changes or further message notifications. Group managers' oversight and actual room membership are distinct; role loss must not become a permanent global history grant.
7. Messages uses one lightweight Group folder containing **Projects** and **General & Ideas**. Project conversations appear only for users entitled to them. Group membership alone never opens Project chat.
8. Group-wide and Idea-specific link collections both exist. Discussion Creator/current managers manage Idea links; Group managers manage Group-wide links. Keep the existing lightweight icons, explicit external launch and private Project links. Never auto-join an external chat.
9. Per-Idea mute is independent of unread and visibility. About seven days of inactivity soft-hides stale Ideas, not archives/deletes/mutes them. New activity resurfaces automatically hidden Ideas. Members may manually hide **unjoined** visible Ideas; **Show hidden** restores access. Hidden does not mean unsubscribed. General is never auto-hidden.
10. Discussion Creator can propose publication. Group managers can review. **Actual Group-attributed Project creation/publication stays with Group Creator or Co-creator**, consistent with the user's answer 12A and GRP03C; Co-organizers may review/endorse but gain no structural publisher power. Preserve real Project authorship.
11. Conversion should feel continuous and keep messages/links for their rightful audience. Use a durable private origin association and separate authorization for old Group planning history and canonical Project history. Do not reparent/copy private planning into ordinary Project messages. A new public Project participant receives no planning history merely by joining the Project.
12. **Conversion Option A:** after successful publication, invite eligible existing planners to the Project. Every person explicitly accepts/requests to join through canonical Project rules. No automatic enrollment, reserved capacity, new roles or resource commitments. Ignoring/declining leaves planning history available only under its existing authorization.
13. Public Projects may remain **In definition** with date/place undecided under the implemented Idea/Defined model. Do not rewrite that lifecycle or silently reverse Batch A's chosen ribbon. Private Group Idea and public planning phase should be understandable without introducing another public content kind.
14. Group People can be used to invite current members into an Idea. **Personal 1:1 contact requests belong to the parallel D00 package**, not a second C-owned implementation.

The founder selected Option A explicitly: “For conversion from Group Idea to public Project, I choose option A. Continue with the updated design and Codex implementation sequence.” Record this and the supplied answers as the revised C authority, not as approval of old D00.

## Bounded implementation defaults, not extra product features

- Initialize the new creation setting to managers-only for existing/new Groups until an authorized editor changes it; it is a discoverable reversible setting, not a ban on all-member creation.
- Keep the existing Group lifecycle/suppression/deletion safeguards unless this package explicitly changes them. Soft hiding is not Group archive/suppression. Do not reactivate a lost identity.
- Group-visible listing exposes a short title/purpose/creator context to authorized Group people, not all messages before Join. General has automatic access with Group membership; Ideas use deliberate Join/acceptance.
- Use **Idea** as the compact Group planning label and clarify it is visible inside the Group. Preserve existing public “Idea/In definition” semantics and surface differences through audience/context, not duplicate main navigation.
- Existing explicit room admissions remain separate from managerial oversight. Ending one overlapping Group role does not falsely remove another valid independent right, but must close the authority/history frontier that actually ended.
- On conversion, the planning source freezes and remains readable according to original/historical planning grants plus disclosed current manager oversight. New ordinary users do not gain old planning by entering through the Project route. No new source admissions are needed after conversion.
- No automatic transfer of workspace URLs to a wider Project audience. Preserve original scopes; a properly authorized manager can deliberately share selected links with review of the destination audience.

Document these defaults plainly. Escalate a real consequential contradiction rather than quietly implementing a broader audience. Do not re-ask already settled C choices.

## Sequence

C-R00 contract/delta → C-R01 General/settings/visibility → C-R02 history/invitations/alerts → C-R03 folder/hide/mute UI → C-R04 private links/external channels → C-R05 conversion/publication/invitations → C-R06 continuous history → C-R07 final integration and merge.

You may validate/refactor within the lane as needed. Keep final source coherent and end-to-end usable; do not merge a backend stage independently merely to unblock its own UI. A separate integration chat is not required.
