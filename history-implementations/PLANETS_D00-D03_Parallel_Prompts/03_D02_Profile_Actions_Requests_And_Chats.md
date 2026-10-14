# D02 — Contextual profile actions, request inbox and accepted chats

Read D00/D01 and the coordinator. Start from verified D01. Do not import Batch A or require C group folders.

## User experience

A user reaches a group or a Project associated with a group, opens a compact context sheet, chooses a meaningful action, explicitly submits a proposal, and can track the result. The receiving group sees a private request; an authorized representative explicitly accepts; only then does the accepted conversation become available.

For the provisional group-to-group model, the composer identifies both the sending person and selected represented group, and tells them which target audience can read the note. A person with several represented groups selects one deliberately from a bounded eligible list; an ordinary member cannot select that group's identity.

## Entry points without A conflicts

Reuse a real existing profile/context sheet if one exists and its readers are appropriate. The repository check did not establish a public profile-preview owner by filename; inspect instead of assuming one. Add a focused contextual bottom sheet if needed, using existing theme and authorized profile/photo projections. Do not change the personal profile setup/editor.

Provide actions from the group page and an appropriate group-attributed Project detail/context sheet. When someone taps an organizer/person, do not assume that individual has current group authority from Project role or historical attribution alone. A generic public personal profile does not acquire a D message action. Do not fetch an unauthorized group People list, private phone/email or unrelated affiliations to enrich the sheet.

Use a labelled contact action and context-specific purpose menu, not an unexplained icon or many disabled choices. Suggested copy can include:

| English | Italian | Meaning |
| --- | --- | --- |
| Contact group | Contatta il gruppo | Opens the available purposeful actions, not a free-form DM. |
| Propose an idea | Proponi un'idea | Sends a private proposal, not public Idea publication. |
| Propose collaboration | Proponi una collaborazione | Requests a group-to-group conversation. |
| Ask to participate | Chiedi di partecipare | Existing Project/group join flow, selected by actual context. |

Only offer actions genuinely supported by D00. No generic "Other" bypass. Do not show individual-to-group proposals when still deferred. No popup that demands creating a group before the user understands why the action is ineligible; preserve existing group creation as a separate discoverable route.

## Request composer and receipt recovery

Keep the form small: purpose, current source/target group, short title/note and optional authorized public context reference. Display the recipient/readership explanation before Submit. Use existing required-profile and policy gates; do not introduce a photo prerequisite, extra identity fields or legal verification unless D00 explicitly resolves a demonstrated requirement.

Signing in, completing setup or returning from policy review preserves a sanitized intended destination but never submits or accepts. Integrate via existing continuation hooks without rewriting A01's owner; D continuations must be recognized as protected so the optional group-onboarding offer does not intercept them when A lands.

Freeze the actor, source/target and exact intent while a command is ambiguous. Preserve input through recoverable errors; distinguish pending delivery/reconciliation from confirmed sent. Do not show a success snackbar before canonical confirmation or create a new action key on a blind retry. Identity change invalidates late completions and private form content. Use existing safe local recovery patterns; no raw note/token logging or unapproved persistent private-note store.

Cancel before confirmed send changes nothing. Once sent, Withdraw is a separate canonical action; closing the UI is not withdrawal. Conflict/role-loss copy is neutral and actionable; never identify who blocked whom.

## Requests and conversations within Messages

Extend the existing central typed request and conversation owners rather than maintaining a separate inconsistent inbox or a global new-chat control. D00 records the chosen scope. A sensible prototype is D contact requests in Requests and accepted representative conversations in Groups with an explicit collaboration label and neutral group imagery. Do not pretend they are ordinary Project chats or use a person's avatar where the Groups contract excludes it.

Lists, exact details and badges use D01's versioned canonical projections. Preserve independently paged Private/Groups/Requests windows, refresh epochs, loaded rows, composite keys, scroll anchoring and retry behavior. No loading all groups/chats/messages to calculate counts or to decide a button. Old-client behavior stays compatible.

Receiver request details show purpose, submitting person/represented group, bounded note and authorized public context. Accept/Decline are only for current authorized recipients; sending side gets Withdraw while allowed. Simultaneous resolution reloads canonical state; another manager's acceptance is not permission to open their conversation.

Accepted chat uses a lightweight dedicated D screen or a shared presentation composition with D's own gateway and access state. Include actual human sender and represented-group context, audience/member information permitted by D00, explicit close/leave controls and Report/Block where appropriate. No Checklist, Project Needs, workspace editor, permanent-group rooms or meeting-location reads merely because existing Project chat has them.

Reuse `ConversationHistoryList`/newest-viewport principles when compatible: lazy history, one older page per deliberate gesture, viewport-preserving prepends and accessible Load more/Retry. Only an actual foreground, unobscured, rendered newest boundary acknowledges read state. Entering a request, a profile sheet, chat info or an older page does not read an unseen message.

## Safety, accessibility and states

Handle no eligible source group, empty inbox, pending/resolved/withdrawn/unavailable request, read/send failure, offline reconciliation, missing profile photo, deleted identity and revoked conversation access separately. Empty content is not an error fallback. A disabled send does not remove Report, safe exit or permitted own history.

Use native lightweight widgets and current icons; no raster art or new animation system. EN/IT strings, meaningful button semantics, keyboard insets, Back/cancel, focus restoration and ~320dp/2x text must work. Keep long group names and sender labels readable. Do not add public profile fields to fill space.

Clear private content and dispose subscriptions on identity/authorization changes. Test while a composer, permission sheet or external-reference confirmation is open. Canonical public link navigation never transports private message text in a URL.

## Validation

Unit/widget tests cover strict new typed kinds, intent preservation, multiple eligible source groups, exact request recovery, receiver races, account changes, denial versus empty, pagination, unread boundaries, profile/photo privacy and unavailable actions.

Run bounded real local-backend Android journeys with three synthetic accounts and two groups: submit, recipient-manager triage, explicit accept, chat send/read, another manager denied chat, role loss, block/report and unchanged Project join. Add keyboard, Back, long Italian labels and large-text renders; inspect the screenshots. Repeat a protected contact continuation through setup when A is integrated, without modifying A's implementation to force the test.

Run focused Mobile/group/Messages/router/safety tests and appropriate Web/type checks. Record new routes, projection versions, state ownership, visual evidence and limits. Push D02 draft and continue to D03.
