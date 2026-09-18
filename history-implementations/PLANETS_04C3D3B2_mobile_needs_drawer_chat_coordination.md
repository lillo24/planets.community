# PLANETS 04C3D3B2 — Mobile Needs Drawer + Chat Coordination

**Roadmap area:** 04C3D3B — Group Needs Coordination + Chat Resurfacing  
**Task type:** Flutter/mobile integration over 04C3D3A + 04C3D3B1  
**Repository:** `lillo24/planets.community`

## Required stack

Continue the current open stack:

```text
main
  fe3cd28cec066ff262da049f15f58dd53b3fa6aa

PR #45 — 04C3A Project Resource Needs
  2b2aaabfbf872431b4a60a26dba5440f4b22560f

PR #52 — 04C3B1 Join-Request Contribution Selection Domain
  410b50423f9b75126349d8d29d7767499fe73146

PR #60 — 04C3B2 Mobile Contribution Selection + Messages
  058e8b03c8905048cff2e8e78f80b3488686fbf0

PR #61 — 04C3C1 Current Commitment Domain
  4fe08a9704150babcb8de7e307f6441923768cbc

PR #62 — 04C3C2 Mobile Current Commitment Management
  682986d2bb573725fb955b297190f0091e20c0f1

PR #63 — 04C3D1 Join-Acceptance Contribution Triage Domain
  e4b6d3a2da4dace419ae1474a0e2365eb7aaebcd

PR #64 — 04C3D2 Mobile Join-Acceptance Contribution Triage
  aad4e238186315d57a1d33be30b7515221c17b61

PR #65 — 04C3D3A Live Project Requirement Coverage Domain
  f92d10aa5ad4f6f386ff07a222afbcc97db49e98

PR #66 — 04C3D3B1 Structured Group Need Resurfacing + Attention Domain
  codex/04c3d3b1-group-need-resurfacing-domain
  aed90e536cdbdc3ad6bb78dcfb55e76d2bfd860f
```

All remain intentionally open/unmerged because the schema-heavy lower stack still needs executable Database validation.

Before implementation:

1. fetch current `origin/main`;
2. if `main` advanced, rebase the stack in dependency order;
3. preserve unrelated SITE/CI/tooling work;
4. do not merge any existing PR;
5. branch this plan from the final PR #66 head;
6. open the new PR with base:
   `codex/04c3d3b1-group-need-resurfacing-domain`.

Preferred branch:

```text
codex/04c3d3b2-mobile-needs-chat-coordination
```

Archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_04C3D3B2_mobile_needs_drawer_chat_coordination.md
```

No external document is required by Codex.

Do not merge any PR.

---

# Objective

Complete the mobile live-needs coordination experience inside Project chat.

For current Project creators/members, the chat should provide:

```text
chat history

[ Needs button ] [ message field................ ] [ send ]
      ↑
opens upward bottom sheet / drawer

Needs now
- Paint                 [ I can bring it ]
- Carpentry             [ I can help ]
- Wooden boards         [ I can bring it ]

creator additionally:
- each uncovered item   [ Found outside app ]

creator compact section:
Found outside the app
- Ladder                [ Needed again ]
```

When a previously covered requirement resurfaces:

```text
structured chat item:
"Paint is needed again."

Needs button:
- persistent attention callout
- brief shake on new unseen resurfacing
- current uncovered count
```

Opening the Needs drawer acknowledges resurfaced-needs attention **only after canonical current Needs content has successfully loaded and is visible**.

This slice is mobile-only. Consume PR #65/#66 contracts as-is.

---

# 1. Existing backend contracts

Use only these canonical RPCs:

```text
D3A:
list_project_live_requirement_coverage
claim_project_requirement
set_project_requirement_manual_coverage

D3B1:
list_own_project_chat_feed
get_own_project_requirement_attention
acknowledge_project_requirement_attention

existing:
list_own_project_group_chats
send_project_chat_message
```

Realtime on the existing private per-profile topic carries:

```text
project.chat_message_sent
project.requirement_needed_again
project.requirement_covered
```

No direct table access.

---

# 2. No database migration

D3B2 should not modify SQL.

If the intended mobile experience cannot be implemented using the contracts above, stop and report the actual backend gap before modifying database code.

Do not silently patch PR #65/#66 from this branch.

---

# 3. Migrate chat detail from message-only history to mixed feed

Current mobile detail reads:

```text
list_own_project_chat_messages
```

and stores:

```text
List<ProjectChatMessage>
```

Migrate Project chat detail to:

```text
list_own_project_chat_feed
```

with a strict discriminated mobile model.

The old backend message-only RPC remains available for compatibility/tests outside this slice, but production Project chat detail should use the mixed feed.

---

# 4. Feed mobile model

Prefer a sealed/discriminated model equivalent to:

```text
ProjectChatFeedItem
├─ ProjectChatHumanMessage
└─ ProjectChatRequirementNeededAgain
```

## Human

Fields equivalent to:

```text
itemId
chatId
createdAt
senderProfileId
senderDisplayName
body
```

## System resurfacing

Fields equivalent to:

```text
itemId
chatId
createdAt
requirementKind
requirementId
requirementLabel
```

Do not create a fake sender.

Unknown `item_kind` or inconsistent nullable shape fails safely.

---

# 5. Mixed feed cursor

Replace detail pagination cursor with the exact B1 keyset shape:

```text
createdAt
itemKind
itemId
```

Preserve backend ordering exactly.

Backend newest-first tie order is:

```text
message before system event
```

when timestamps are equal.

The Flutter UI may continue storing/rendering items oldest-first, but merge and pagination logic must preserve the exact canonical order without duplicate/lost rows.

Add equal-timestamp tests.

---

# 6. Sending human messages

`send_project_chat_message` still returns a normal human message.

After send:

```text
wrap the returned message as a human feed item
merge into canonical feed state
```

Do not call the mixed feed solely to fabricate the just-sent message unless existing reconciliation conventions make that safer.

The next Realtime/refresh remains authoritative.

---

# 7. Structured system-event rendering

Render:

```text
system_requirement_needed_again
```

as a centered group/system card, not a left/right message bubble.

Conceptual copy:

```text
Paint is needed again.
```

Include a small appropriate icon and timestamp.

No sender.

No actor name.

No technical IDs.

The event remains visible historically even if the requirement is later covered or removed.

Former members may see historical events according to backend history authorization.

---

# 8. Preserve human bubble behavior

Human message rendering remains unchanged in semantics:

```text
mine → right
others → left
sender label
body
time
```

Do not regress:

- send;
- pagination;
- reconnect reconciliation;
- read-only former-member history;
- existing accessibility.

---

# 9. Realtime signal model

Evolve the mobile Project-chat Realtime parser into a strict discriminated signal model:

```text
messageSent
requirementNeededAgain
requirementCovered
```

All use the same existing private chat topic.

Strictly validate identifier-only payloads.

A malformed new signal must fail safely without exposing private data.

---

# 10. Realtime behavior

## `project.chat_message_sent`

```text
refresh/reconcile mixed feed
refresh chat list according to existing behavior
```

## `project.requirement_needed_again`

```text
refresh/reconcile mixed feed
refresh live requirement coverage
refresh attention state
refresh chat list/activity
```

## `project.requirement_covered`

```text
refresh live requirement coverage
refresh attention state
```

No durable feed item is expected for covered.

Coalesce rapid signals using existing refresh/debounce patterns rather than starting unbounded concurrent requests.

---

# 11. App resume

On resume for the open current-entitlement chat:

```text
refresh mixed feed
refresh coverage
refresh attention
```

This is required because Realtime is a hint, not durable synchronization.

Former/read-only members only need historical feed reconciliation; they have no current Needs state.

---

# 12. Focused live-needs mobile domain

Add strict models equivalent to:

```text
ProjectLiveRequirementKind {
  skill
  resource
}

ProjectLiveRequirement {
  kind
  id
  label
  importance?
  isCovered
  viewerIsCovering
  isManuallyCovered
}
```

Unknown backend kinds fail safely.

Do not expose provider identity because D3A does not provide it.

---

# 13. Needs coordination controller

Add a focused identity-bound controller keyed by Project ID or equivalent.

Conceptual state:

```text
ProjectNeedsState {
  expectedProfileId
  projectId
  viewerRole

  coveragePhase
  requirements

  attentionPhase
  attention

  actionTarget
  actionKind
  failure
}
```

Keep it separate from human chat composer state.

The chat screen coordinates the two controllers.

---

# 14. Initial loading on current-entitlement chat

When chat detail resolves a creator/current-member summary:

```text
load coverage
load attention
```

Do this for the open chat only.

Do not load coverage/attention for every row in the Messages/chat list.

No N+1 across group conversations.

For former members:

```text
do not call current coverage/attention RPCs
```

because backend correctly denies them.

---

# 15. Needs button placement

Place the Needs control immediately beside the bottom composer.

Preferred layout:

```text
[ Needs ] [ message field................ ] [ Send ]
```

The exact icon may follow Material conventions (`checklist`, `inventory`, `volunteer_activism`, etc.).

Keep touch target accessible.

Do not add a new route or bottom-navigation destination.

For former/read-only chat:

```text
no Needs control
```

because live coordination entitlement has ended.

---

# 16. Current-needed count

The button may show a numeric badge for:

```text
requirements.where(isCovered == false).length
```

This count is current truth, not an unread count.

Behavior:

```text
0 uncovered
→ no numeric badge

>0
→ show bounded count
```

Use a reasonable `99+`-style presentation if necessary.

Do not infer count from historical system events.

---

# 17. Resurfacing attention cue

Separate:

```text
current uncovered count
```

from:

```text
unseen resurfaced-needs attention
```

When:

```text
attention.hasUnseenResurfacedNeed == true
```

show an additional clear cue around the Needs control.

Preferred behavior:

1. a small anchored callout/pill such as:
   ```text
   Needed again
   ```
   that remains visible while attention remains true;
2. a brief one-shot shake/pulse when attention transitions `false → true`
   during the current app/session;
3. semantic live-region announcement.

Do not rely on animation/color alone.

Respect reduced-motion settings.

---

# 18. Attention persistence

Do not store local persistence for the cue.

The backend attention receipt is the source of truth across app restarts.

On load/resume:

```text
get_own_project_requirement_attention
```

restores the correct cue.

If the requirement was already re-covered:

```text
backend attention false
→ cue absent
```

even though the historical system card remains.

---

# 19. Open Needs drawer

Tap the Needs control:

```text
showModalBottomSheet / upward drawer
```

Use:

- `isScrollControlled`;
- safe area;
- scrollable content;
- drag affordance if consistent with existing UI.

The user described a drawer growing upward from the chat control; a Material modal bottom sheet satisfies that interaction.

---

# 20. Drawer primary section — Needed now

Show **only currently uncovered requirements** in the primary section:

```text
Needed now
```

Group:

```text
Competences / Knowledge
Resources / Materials
```

Proposal skill importance (`required` / `useful`) may be shown compactly if it improves clarity.

Tavolo naturally has resources only.

Do not show stale historical requirements.

---

# 21. Current participant actions

For:

```text
viewerRole = currentMember
```

each uncovered requirement gets an action equivalent to:

```text
I can help
I can bring it
```

Skills:

```text
I can help
```

Resources:

```text
I can bring it
```

Both call:

```text
claim_project_requirement
```

The backend may reuse an existing Extra commitment or create a new commitment.

Do not locally fabricate commitment state.

---

# 22. Creator actions on uncovered requirements

For:

```text
viewerRole = creator
```

do not expose participant Claim.

Creator gets:

```text
Found outside app
```

on uncovered requirements.

This calls:

```text
set_project_requirement_manual_coverage(..., true)
```

Creator ownership is not a participant membership.

---

# 23. Creator manual-coverage management section

To avoid trapping organizer mistakes, creators also get a compact secondary section:

```text
Found outside the app
```

Include only:

```text
requirement.isManuallyCovered == true
```

Do **not** include every participant-covered requirement.

Each manual item gets:

```text
Needed again
```

which calls:

```text
set_project_requirement_manual_coverage(..., false)
```

If participant coverage also exists, clearing manual coverage correctly leaves it covered; after canonical reload it should not appear in `Needed now`.

If it was the last source, backend emits a real needed-again transition and it appears in system history.

---

# 24. Empty states

Examples:

## Participant

No uncovered needs:

```text
Everything currently needed is covered.
```

## Creator

No uncovered + no manual external coverage:

```text
Everything currently needed is covered.
```

If creator has manual items, keep their compact management section visible even when the primary list is empty.

---

# 25. Claim race — SQLSTATE 40001

Two participants may tap Claim at nearly the same time.

If backend returns:

```text
40001
```

interpret as:

```text
someone else covered it first
```

Do not show a scary error.

Reload coverage.

Show brief localized guidance:

```text
Someone else just covered this need.
```

The item should disappear from Needed now.

Do not retry automatically.

---

# 26. Stale/invalid requirement — `22023`

If claim/manual mutation returns `22023`:

```text
requirement changed
or
commitment 50-limit prevented claim
```

The backend intentionally does not expose a finer stable distinction.

Reload canonical coverage.

Show safe general guidance, e.g.:

```text
This need changed and couldn't be updated. Review the latest list.
```

Do not show raw PostgREST text.

Do not silently mutate a subset.

---

# 27. Lifecycle/authorization failures

Map:

```text
42501 → forbidden / membership entitlement changed
55000 → live coordination no longer available
P0002 → unavailable/not found
other  → unavailable
```

If user becomes former member while drawer is open:

```text
close/disable live actions
refresh chat detail
retain historically authorized feed
```

Do not leave current Needs data visible to an account that no longer has entitlement.

---

# 28. After a successful participant claim

Reload canonical:

```text
coverage
attention
```

Then:

```text
claimed item disappears from Needed now
```

If drawer stays open, keep it open unless repository UX conventions strongly prefer closing.

Also trigger relevant local refresh signals so:

- group info commitment state will be fresh when next opened;
- chat list/detail can reconcile;
- another Realtime covered signal remains only a redundant hint.

Do not manually append commitment chips anywhere.

---

# 29. After creator Found outside app

Reload canonical coverage + attention.

The item:

```text
disappears from Needed now
appears in Found outside the app
```

No system chat card is created for covered.

---

# 30. After creator Needed again

Call manual coverage false.

Then reload:

```text
coverage
attention
mixed feed
```

If it was the last source:

```text
item appears in Needed now
new structured "X is needed again" card appears in chat
```

Because the drawer is already open, the creator has already seen the newly resurfaced need once the refreshed canonical list is visible.

Use the acknowledgement behavior below rather than leaving a pointless self-generated attention cue.

---

# 31. Drawer-open acknowledgement boundary

Opening the chat screen alone does not acknowledge anything.

When the Needs drawer opens:

1. load/refresh canonical coverage;
2. load/refresh attention;
3. render current Needs content;
4. only after successful current content is available/visible:
   - if `latestUnseenEventId != null`,
   - acknowledge exactly through that event ID;
5. reload attention state.

If coverage loading fails:

```text
do not acknowledge
```

because the user did not successfully see the current Needs list.

---

# 32. New resurfacing while drawer is already open

If `project.requirement_needed_again` arrives while the drawer is open:

1. refresh mixed feed;
2. refresh coverage;
3. refresh attention;
4. show the new uncovered requirement;
5. after the refreshed canonical drawer content is actually rendered/available,
   acknowledge through the latest event that was loaded.

This satisfies:

```text
drawer is already being viewed
→ newly visible current need counts as seen
```

while preserving the backend explicit-frontier race safety.

Do not acknowledge an event before its canonical requirement state is visible.

---

# 33. Concurrent event race

Example:

```text
drawer loaded attention through A
B arrives before acknowledgement request completes
client sends acknowledge(A)
```

Do not replace A with “latest now” locally.

Send exactly:

```text
A
```

Backend keeps B unseen.

Then Realtime/attention refresh reveals B and, because drawer remains open, the UI may subsequently acknowledge B only after B's canonical list refresh is shown.

---

# 34. System event cards do not themselves acknowledge

Scrolling past or viewing:

```text
"Paint is needed again"
```

inside chat history does **not** acknowledge the Needs attention.

Only opening/viewing the current Needs drawer does.

The historical card explains what happened; the drawer is the canonical coordination state.

---

# 35. Migrate detail state names away from `messages`

Avoid leaving misleading state such as:

```text
List<ProjectChatMessage> messages
```

when system items are present.

Prefer:

```text
feedItems
```

or equivalent.

Likewise update helper names:

```text
mergeFeedItems
validateFeedChat
feed cursor
```

Keep code terminology aligned with backend mixed-feed semantics.

---

# 36. Realtime parser/gateway

Update the existing gateway subscription without creating another Supabase channel.

Register callbacks for all three event names on the same private topic.

Model signals strictly.

Conceptually:

```text
ProjectChatSignal
  kind
  chatId
  createdAt
  messageId?
  systemEventId?
  requirementKind?
  requirementId?
```

or use sealed signal variants.

Do not force unrelated fields into fake placeholder strings.

---

# 37. Needs gateway

Add a narrow RPC-only gateway, preferably in a focused Project-needs/chat-coordination boundary.

Required calls:

```text
listCoverage(expectedProfileId, projectId)

claimRequirement(
  expectedParticipantProfileId,
  projectId,
  kind,
  id
)

setManualCoverage(
  expectedCreatorProfileId,
  projectId,
  kind,
  id,
  isCovered
)

getAttention(expectedProfileId, projectId)

acknowledgeAttention(
  expectedProfileId,
  projectId,
  throughSystemEventId
)
```

No direct tables.

---

# 38. Coverage/attention loading independence

A failure to load Needs coordination must not make human chat unusable.

The chat feed, composer, and historical reading remain independently useful.

If Needs loading fails:

```text
Needs button remains available with safe retry/error behavior
human chat continues
```

Do not collapse the entire ProjectChatScreen into an error state.

---

# 39. Mixed-feed failure independence

Conversely, if live Needs state loads but the mixed feed refresh fails:

```text
preserve current feed
show existing local chat error/retry
Needs drawer remains usable if its canonical data is available
```

Keep failure domains localized where practical.

---

# 40. Localization

Add production copy through l10n.

At minimum concepts equivalent to:

```text
Needs
Needed now
Everything currently needed is covered.
Competences / Knowledge
Resources / Materials
Required
Useful

I can help
I can bring it
Found outside app
Found outside the app
Needed again

{name} is needed again.

Someone else just covered this need.
This need changed. Review the latest list.
Unable to load current needs.
Unable to update this need.
Live Project coordination is no longer available.
Try again.

Needed again
New Project need
```

Do not hard-code production strings.

---

# 41. Accessibility

Needs control:

- proper tooltip/label;
- numeric count semantics;
- unseen-attention semantics separate from count;
- accessible touch target.

Drawer:

- headings marked appropriately;
- each requirement label associated with its action;
- action progress exposed;
- errors use live regions;
- long labels wrap.

System event:

- one coherent semantics phrase;
- no fake sender.

Attention:

- persistent visual cue;
- semantic live announcement;
- shake is optional decoration, never sole signal;
- reduced-motion safe.

---

# 42. Attention shake/pulse implementation

Do not loop animation.

Trigger one short pulse when:

```text
previous hasUnseenResurfacedNeed = false
next     hasUnseenResurfacedNeed = true
```

If attention loads as already true when reopening the app:

- persistent callout/badge is enough;
- a single initial pulse is acceptable but not required.

Do not shake repeatedly on every rebuild.

---

# 43. Chat-bottom layout constraints

The existing composer allows up to 5 text lines.

Integrate Needs without causing:

- horizontal overflow;
- tiny message field;
- send-button displacement;
- keyboard/viewInsets regression.

At narrow widths/text scaling, a compact icon button with tooltip is preferred over a permanently wide text button.

The persistent attention callout may sit just above/anchored to the Needs control.

---

# 44. Feed system-card visual treatment

Use a neutral system-event treatment distinct from normal message cards.

Conceptual:

```text
──────────
⚠ Paint is needed again.
   18 Sep, 14:22
──────────
```

Do not overemphasize it as an error.

This is coordination information, not moderation/safety.

---

# 45. Current-vs-history distinction

A system card may say:

```text
Paint is needed again.
```

while Paint has since been covered.

That is correct historical chronology.

The drawer is the source of truth for:

```text
what is needed NOW
```

Do not mutate or hide historical system cards when state changes.

---

# 46. Creator/manual section is current state, not history

`Found outside the app` inside the drawer reflects:

```text
isManuallyCovered == true
```

today.

It does not display historical `already_found` acceptance decisions.

Do not conflate the two.

---

# 47. Tavolo behavior

Tavolo live coverage has resource requirements only.

Drawer:

```text
no fake skill group
resources only
```

Participant Claim and creator manual-found actions work the same.

Tavolo final-contribution attribution remains deferred.

---

# 48. Former-member behavior

Former members:

```text
can see historically authorized human/system feed
cannot see Needs button
cannot load current coverage
cannot load attention
cannot Claim
```

Do not show current uncovered requirements to former members.

---

# 49. Creator behavior

Creator:

```text
has current chat entitlement
can view current Needs
cannot participant-Claim
can Found outside app
can undo manual coverage
```

Do not create a fake creator membership.

---

# 50. Current participant behavior

Current member:

```text
has current chat entitlement
can view current Needs
can Claim uncovered requirement
cannot manage manual external coverage
```

Authorization still belongs to backend.

---

# 51. Tests — feed parser/gateway

Cover:

- human feed row;
- system row;
- strict nullable-field discrimination;
- unknown item kind;
- unknown system kind;
- skill/resource requirement kinds;
- mixed feed RPC params;
- three-part cursor;
- deterministic cursor kind values;
- send receipt wrapped as human feed item;
- old message-only RPC no longer used by production detail flow.

---

# 52. Tests — feed controller

Cover:

- initial mixed feed;
- human-only;
- system-only;
- mixed ordering;
- equal timestamp;
- older pagination across kinds;
- no duplicate/lost merge;
- send merge;
- refresh/reconnect;
- former history frontier behavior as represented by backend fixtures;
- account switch/late response safety.

---

# 53. Tests — Realtime

Cover parser/subscription for:

```text
messageSent
requirementNeededAgain
requirementCovered
```

Verify:

- message signal refreshes feed;
- needed-again refreshes feed + needs + attention;
- covered refreshes needs + attention but does not expect a feed row;
- malformed signal fails safely;
- no second Realtime channel created.

---

# 54. Tests — Needs controller

Cover:

## Load

- creator coverage + attention;
- current participant coverage + attention;
- former path does not call RPC;
- transient coverage failure;
- transient attention failure;
- account switch clears private state.

## Filtering

- uncovered items in Needed now;
- covered participant items absent;
- creator manual items in manual section;
- participant sees no manual-management action;
- Tavolo no skills.

## Participant claim

- success;
- existing Extra handled transparently;
- `40001` reload + “someone else” guidance;
- `22023` safe reload;
- lifecycle/authorization failures.

## Creator manual

- set true;
- set false;
- participant coverage remaining after set false;
- last-source set false causes item to reappear after reload.

---

# 55. Tests — acknowledgement

Cover:

1. opening chat alone does not acknowledge;
2. drawer opens + successful coverage display → acknowledge through loaded event;
3. coverage load failure → no acknowledge;
4. attention false → no acknowledge mutation;
5. acknowledgement failure leaves attention visible/retryable;
6. event B after loaded event A is not sent accidentally in A's acknowledgement;
7. B then appears after refresh;
8. B is acknowledged only after updated drawer content becomes visible;
9. re-cover-before-drawer means attention false/no ack needed.

---

# 56. Tests — ProjectChatScreen / drawer

Cover:

- Needs button appears for creator/current member;
- absent for former member;
- numeric uncovered count;
- no count when zero;
- persistent attention callout;
- one-shot attention pulse state;
- reduced motion;
- opens bottom sheet upward;
- groups skill/resource;
- empty state;
- participant Claim labels;
- creator Found outside action;
- creator manual section + Needed again action;
- localized failure/retry;
- action progress;
- long label wrapping;
- keyboard/viewInsets-safe composer.

---

# 57. Tests — system cards

Cover:

- requirement-needed-again card appears inline chronologically;
- no sender;
- canonical label;
- timestamp;
- semantics;
- later re-cover does not remove the historical card;
- human messages remain unchanged.

---

# 58. Native QA deferred to Plan 12

Add checklist items:

- Needs control beside composer at narrow widths;
- keyboard open/closed;
- 1–5 line composer;
- drawer drag/scroll behavior;
- long skill/resource labels;
- 50-item drawer performance;
- numeric badge;
- persistent attention callout;
- shake/pulse subtlety;
- reduced-motion;
- TalkBack/VoiceOver for button/count/attention;
- system-event card reading;
- claim race on two devices;
- creator manual found/undo;
- Realtime resurfacing while drawer closed;
- Realtime resurfacing while drawer open;
- account switch while drawer open;
- leave/remove while drawer open;
- app restart with unseen attention.

Do not claim physical-device QA passed.

---

# 59. Documentation / roadmap

Update accurately:

```text
04C3D3A  PR #65 open/unmerged
04C3D3B1 PR #66 open/unmerged
04C3D3B2 this stacked mobile PR
```

Document:

```text
chat mixed feed
Needs control
current-uncovered drawer
participant Claim
creator manual Found/Needed
acknowledge-on-successful-drawer-view
```

Do not mark these slices Implemented until merged.

---

# 60. Validation

Run at minimum:

```text
npm run check:mobile
flutter build apk --debug
npm run check:web
npm run check:site
git diff --check
```

Run formatting and focused tests.

No D3B2 DB migration is expected, but the inherited backend stack still cannot merge until its Database gate executes green.

Attempt hosted Validation once.

If runner startup is rejected because of the known billing/spending issue:

```text
not executed due external infrastructure
```

Do not rerun pointlessly.

---

# Non-goals

Do not implement:

- database/schema changes;
- global notification-center resurfacing alerts;
- push delivery for resurfaced needs;
- provider/member names for who covers an item;
- public coverage hints;
- delegates/co-organizers;
- final contribution attribution;
- Substantial Effort / Energy;
- Tavolo skill requirements;
- negative/no-show reporting;
- public reviews/ratings;
- Scambio-Dona matching.

---

# Acceptance criteria

Ready for review when:

- [ ] stack current and D3B2 based on PR #66;
- [ ] exact prompt archived;
- [ ] no DB migration added;
- [ ] chat detail uses mixed feed RPC;
- [ ] human/system feed items modeled distinctly;
- [ ] mixed cursor matches backend exactly;
- [ ] system needed-again cards render without fake sender;
- [ ] normal human send/history behavior preserved;
- [ ] one existing private Realtime topic handles all three signal kinds;
- [ ] current creator/member loads coverage + attention;
- [ ] former member performs no live-needs RPCs;
- [ ] Needs button sits beside composer;
- [ ] current uncovered count derives from live coverage;
- [ ] unseen resurfacing cue is distinct from count;
- [ ] persistent attention callout shown from backend truth;
- [ ] brief one-shot reduced-motion-safe pulse/shake;
- [ ] drawer opens upward;
- [ ] primary drawer lists only current uncovered needs;
- [ ] participant can Claim;
- [ ] creator can Found outside app;
- [ ] creator can undo only manual/external coverage in compact section;
- [ ] participant-covered items do not clutter manual section;
- [ ] `40001` claim race reloads safely;
- [ ] `22023` stale/limit failure reloads safely;
- [ ] successful mutations reload canonical coverage;
- [ ] opening chat does not acknowledge;
- [ ] successful visible drawer load acknowledges explicit frontier;
- [ ] failed drawer load does not acknowledge;
- [ ] concurrent later event is not swallowed;
- [ ] new event while drawer open is acknowledged only after refreshed content is visible;
- [ ] historical system cards remain after re-cover;
- [ ] localization/accessibility complete;
- [ ] comprehensive Flutter tests pass;
- [ ] debug APK passes;
- [ ] native QA remains deferred;
- [ ] no PR merged.

---

# Completion report

Return:

1. **Stack/base status**
2. **04C3D3B2 branch/base/PR**
3. **Changed files**
4. **Mixed-feed mobile model**
5. **Mixed-feed gateway/cursor**
6. **Human send regression**
7. **System-event rendering**
8. **Realtime signal model**
9. **Realtime refresh behavior**
10. **Needs domain/controller**
11. **Initial current-entitlement loading**
12. **Needs button placement**
13. **Current-needed count**
14. **Persistent resurfacing attention**
15. **Shake/pulse behavior**
16. **Drawer interaction**
17. **Participant claim UI**
18. **Creator Found-outside-app UI**
19. **Creator manual-coverage undo section**
20. **40001 claim-race recovery**
21. **22023 stale/limit recovery**
22. **Lifecycle/authorization recovery**
23. **Drawer acknowledgement boundary**
24. **Concurrent acknowledgement behavior**
25. **New event while drawer open**
26. **Former-member behavior**
27. **Tavolo behavior**
28. **Localization/accessibility**
29. **Gateway/controller/widget tests**
30. **Local regression validation**
31. **Hosted Validation executed/not-executed**
32. **Deferred native QA**
33. **05C handoff**
34. **Warnings/blockers**
35. **Commit/PR reference**

Do not merge any PR.
