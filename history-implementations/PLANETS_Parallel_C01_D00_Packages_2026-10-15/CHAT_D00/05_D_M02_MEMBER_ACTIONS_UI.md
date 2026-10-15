# D-M02 — Compact People/profile actions, personal request inbox and chat UI

## Objective

Make the approved member-contact and existing representative workflows discoverable without an unrestricted “message anyone” button. Reuse current Group People, sanitized profile/photo and Messages components. Depends on D-M01 for functional member contact; can prototype while its precise contract is reviewed.

## Contextual action sheet

Tapping a person in an authorized Group context opens a compact sheet, not necessarily a new full-screen profile. Use visible action text plus an accessible icon/menu. Show only actions justified by the actor, target and real context:

- **Request conversation:** current shared-Group person, M00/M01 consent flow.
- **Invite to an Idea:** the C-owned room invitation action, with eligible room/picker checks; it is not a personal chat or a Project join. Do not implement a second invitation domain. If C has not landed, omit this optional action until the later integrator can compose it; no dead controls or cross-branch imports.
- **Propose collaboration / idea to Group:** approved representative D flow, showing which Group the actor represents and the actual recipient audience. A member-only personal request must not expose Group-wide manager triage.
- **Ask to participate:** only where there is a specific relevant Project/Group join destination, through its normal canonical consent/review/capacity rules.
- Existing view/report/block actions retain their current scopes and privacy.

Do not automatically expose private Group affiliations from a public Project profile sheet. A public Project publisher need not currently represent the attributed Group; reread authorization before showing a contact-as-representative action. No generic “Etc.” catchall that opens unintended contact types.

## Requests and conversations

Show sender/context, bounded introductory note, current status and explicit Accept/Decline/Withdraw. Requests remain actionable invitations, not fabricated human messages. Opening the sheet/composer, selecting a recipient, signing in or completing a profile never submits. Preserve unsent text and cancel destinations within the current actor's session, reject stale actions after switch/leave, and surface unknown delivery/recovery honestly.

After valid acceptance, member 1:1 chats belong in the existing **Private** conversation organization (unless an already-approved current layout provides an equivalent), with discreet shared-Group context—not inside C's manager-visible General/Ideas area. Representative chats identify both human and represented Group; do not label a personal chat as official Group speech. Every view consumes the correct domain's private gateway.

Implement unread, foreground ACK, notification destinations, mute where approved, read-only/closed/unavailable states and paged history. Preview/title/identity photos must use existing authorized projections. A disclosure label is not permission to fetch a hidden photo or roster.

## Native and UI evidence

Actual EN/IT narrow/large-text sheets, long names and notes, keyboard/focus/Back, request cancel/retry, two accounts, target acceptance, blocked/unavailable state, switching Group context and the resolved leave/history behavior. Show an ordinary Group member can use member contact but cannot send as a Group or publish a Project. Show a Group manager can inspect C Ideas but not others' member chats.

Use the repository's actual widgets and a completed real-backend Android journey before final merge; mocks/prototypes do not certify consent. Keep missing C-specific action integration as an explicit peer handoff, not a dependency that stalls the entire D lane. The later merger must compose it when both are present.
