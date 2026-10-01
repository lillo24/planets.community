# PLANETS 04C4C3C2 — Mobile Handoff / Return / Timeline / Overdue

**Roadmap area:** 04C4C3 — Mobile Scambio Request / Agreement / Conversation Experience  
**Task type:** Flutter/mobile milestone + timeline integration over 04C4B/C3C1  
**Repository:** `lillo24/planets.community`

## Required stack

Base this plan on:

```text
PR #80 — 04C4C3C1 Mobile Scambio Agreement Negotiation
branch: codex/04c4c3c1-mobile-scambio-negotiation
head:   bc12243ff0be5bf585505731d32184ec670a8654
```

PR #80 includes the C3C1-F1 forward migration that makes
`list_resource_exchange_agreement_terms.is_current/is_pending`
strict non-null booleans.

Before implementation:

1. fetch current `origin/main`;
2. verify PR #80 still points to the expected head or reconcile newer stack movement;
3. preserve unrelated work;
4. branch from PR #80 head;
5. do not merge any PR.

Preferred branch:

```text
codex/04c4c3c2-mobile-handoff-timeline-overdue
```

Open against:

```text
codex/04c4c3c1-mobile-scambio-negotiation
```

Archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_04C4C3C2_mobile_handoff_return_timeline_overdue.md
```

---

# Objective

Complete the mobile Scambio agreement experience after negotiation.

Add:

```text
agreed terms
→ physical handoff statements
→ receipt confirmations
→ return statements for lend legs
→ return-receipt confirmations
→ automatic agreement completion
```

and the durable structured history:

```text
agreement created
terms proposed / superseded / accepted / rejected / withdrawn
resource provided / received / returned / return received
agreement cancelled / completed
```

Also surface derived overdue lending state.

Do not add adjudication, damage, liability, rating, or moderation logic.

---

# 1. No database migration expected

Use existing canonical RPCs:

```text
get_resource_exchange_agreement
list_resource_exchange_agreement_terms
list_resource_exchange_agreement_events
record_resource_exchange_milestone
```

Do not alter SQL unless an actual repository-contract bug is discovered.

---

# 2. Extend the agreement gateway

Add:

```text
listEvents(
  expectedProfileId,
  agreementId
)

recordMilestone(
  expectedProfileId,
  agreementId,
  expectedTermsId,
  legKind,
  eventKind
)
```

Exact RPC:

```text
record_resource_exchange_milestone(
  p_expected_profile_id,
  p_agreement_id,
  p_expected_terms_id,
  p_leg_kind,
  p_event_kind
)
```

No direct table access.

---

# 3. Timeline event kinds

Model all canonical event kinds:

```text
agreementCreated

termsProposed
termsSuperseded
termsAccepted
termsRejected
termsWithdrawn

resourceProvided
resourceReceived
resourceReturned
resourceReturnReceived

agreementCancelled
agreementCompleted
```

Unknown event kind fails safely.

---

# 4. Timeline leg kinds

Model:

```text
ownerResource
requesterResource
```

Agreement-level events have:

```text
legKind = null
```

Milestone events require a non-null leg.

Reject malformed combinations locally.

---

# 5. Event model

Add:

```text
ResourceExchangeEvent {
  eventId
  kind
  termsId?
  legKind?
  actorProfileId
  actorDisplayName
  createdAt
}
```

Validate IDs, actor display name, timestamp, and kind/terms/leg shape.

Preserve backend chronological order.

---

# 6. Event-shape validation

Require:

## Agreement created

```text
termsId = null
legKind = null
```

## Terms proposed/superseded/accepted/rejected/withdrawn

```text
termsId != null
legKind = null
```

## Resource milestones

```text
termsId != null
legKind != null
```

## Agreement cancelled

```text
termsId = null
legKind = null
```

## Agreement completed

```text
termsId != null
legKind = null
```

Malformed event payload makes the timeline unavailable rather than partially trusted.

---

# 7. Extend canonical agreement snapshot

C3C1 currently loads:

```text
agreement
terms
```

Extend the snapshot with:

```text
events
```

Conceptually:

```text
ResourceExchangeSnapshot {
  agreement
  terms
  events

  currentTerms
  pendingTerms
}
```

---

# 8. Cross-read reconciliation

The three RPCs are separate reads.

After fetching agreement + terms + events, reconcile them.

If an obvious race is detected, retry the **read snapshot once**.

Examples:

- completed agreement but no completion event yet;
- current terms pointer missing from loaded terms;
- milestone references unknown terms.

If still inconsistent, keep the last good snapshot and show a refresh warning.

Do not loop.

---

# 9. Timeline-to-terms relationship

Every event with:

```text
termsId != null
```

must resolve to a loaded immutable terms version.

Fail safely after bounded reconciliation if it does not.

---

# 10. Historical proposal outcomes

C3C2 may now label old terms versions because the timeline exists.

For each proposal:

```text
terms_proposed
→ terms_superseded
or terms_accepted
or terms_rejected
or terms_withdrawn
```

A previously accepted current version may remain current while a later replacement is rejected/withdrawn.

Do not infer outcome only from version number.

---

# 11. Proposal-history model

Create a derived presentation model such as:

```text
ResourceExchangeTermsHistoryItem {
  terms
  outcome
  proposedEvent
  terminalEvent?
}
```

Possible outcomes:

```text
pending
accepted
rejected
withdrawn
superseded
historicalAccepted
```

Use exact timeline evidence.

---

# 12. Milestone domain

Model:

```text
enum ResourceExchangeLegKind {
  ownerResource
  requesterResource
}

enum ResourceExchangeMilestoneKind {
  resourceProvided
  resourceReceived
  resourceReturned
  resourceReturnReceived
}
```

Use exact backend wire values.

---

# 13. Owner-leg requirements

Owner leg always exists.

Provider:

```text
listing owner
```

Recipient:

```text
requester
```

Give:

```text
owner → resourceProvided
requester → resourceReceived
```

Lend:

```text
owner → resourceProvided
requester → resourceReceived
requester → resourceReturned
owner → resourceReturnReceived
```

---

# 14. Requester-leg requirements

If requester transfer kind is `none`, no requester leg exists.

Give:

```text
requester → resourceProvided
owner → resourceReceived
```

Lend:

```text
requester → resourceProvided
owner → resourceReceived
owner → resourceReturned
requester → resourceReturnReceived
```

---

# 15. Natural milestone ordering in UI

The backend authorizes actor + leg + event kind and deduplicates.

The UI should expose only a sensible next action:

```text
resourceReceived
→ only after resourceProvided

resourceReturned
→ only after resourceReceived

resourceReturnReceived
→ only after resourceReturned
```

Do not imply the client sequence is stronger than backend truth.

---

# 16. Derived leg-progress model

Create a helper:

```text
ResourceExchangeLegProgress {
  transferKind
  providedEvent?
  receivedEvent?
  returnedEvent?
  returnReceivedEvent?

  isComplete
  nextActionForViewer?
}
```

Give complete:

```text
provided + received
```

Lend complete:

```text
provided + received + returned + returnReceived
```

Requester-none leg is absent.

---

# 17. Action derivation inputs

Derive available actions from:

```text
viewer profile ID
ownerProfileId
requesterProfileId
current terms
existing milestone events
agreement lifecycle
pendingTermsId
```

Never derive from display names.

---

# 18. Owner-leg action matrix

Viewer = owner:

```text
no provided
→ Mark as handed over

lend + returned exists + returnReceived missing
→ Confirm returned to you
```

Viewer = requester:

```text
provided exists + received missing
→ Confirm received

lend + received exists + returned missing
→ Mark as returned
```

No invalid opposite-side actions.

---

# 19. Requester-leg action matrix

If requester leg exists:

Viewer = requester:

```text
no provided
→ Mark as handed over

lend + returned exists + returnReceived missing
→ Confirm returned to you
```

Viewer = owner:

```text
provided exists + received missing
→ Confirm received

lend + received exists + returned missing
→ Mark as returned
```

Match backend actor authorization exactly.

---

# 20. Agreement lifecycle gate

Milestone actions only when:

```text
lifecycle = agreed
or lifecycle = inProgress
```

and:

```text
currentTerms != null
pendingTerms == null
```

No milestone controls in:

```text
negotiating
completed
cancelled
```

---

# 21. First milestone transition

The first valid milestone causes:

```text
agreed → in_progress
```

in backend.

After success reload canonically.

Do not locally set lifecycle.

---

# 22. Automatic completion

There is no manual Complete button.

Backend completes when every required milestone exists.

After final milestone:

```text
agreement → completed
coordination closes
Resource chat → read-only
```

Reflect only after canonical reload.

---

# 23. Milestone confirmations

Every physical milestone requires a concise confirmation dialog/sheet.

Examples:

```text
Confirm that you handed over this resource?
Confirm that you received this resource?
Confirm that you returned this resource?
Confirm that the resource was returned to you?
```

Explain that PLANETS records the statement in agreement history.

Avoid legal wording such as “certify” or “prove”.

---

# 24. Milestone mutation

One call to:

```text
record_resource_exchange_milestone
```

with:

```text
expectedProfileId
agreementId
expected currentTermsId
legKind
eventKind
```

After success:

1. reload agreement;
2. reload terms;
3. reload events;
4. refresh Resource chat;
5. refresh unified Chats;
6. refresh Requests if completion closed coordination.

---

# 25. Idempotency

Backend returns the existing event ID if the same milestone already exists.

Client still reloads canonically.

Do not locally append duplicate timeline rows.

---

# 26. PT409 recovery

On milestone `PT409`:

```text
no retry
reload canonical snapshot
refresh chat/list
show latest state
```

Suggested copy:

```text
The agreement changed elsewhere. We loaded the latest handoff status.
```

Do not replay stale intent automatically.

---

# 27. 42501 recovery

Unexpected authorization failure:

- no retry;
- reload canonical snapshot;
- remove stale action;
- show safe permission/state copy.

UI action derivation should normally prevent this.

---

# 28. Agreement History UI

Add a detailed history sheet/screen reachable from Agreement card.

Chronological list.

Render all event kinds.

Do not insert these events as human chat messages.

---

# 29. Timeline copy — agreement events

Examples:

```text
Agreement created
Terms proposed by Anna
Previous proposal superseded by Marco
Terms accepted by Marco
Proposal rejected by Anna
Proposal withdrawn by Marco
Coordination cancelled by Anna
Exchange completed
```

Use canonical actor display name.

Viewer-relative “You” is acceptable.

---

# 30. Timeline copy — physical milestones

Owner leg uses listing snapshot title.

Examples:

```text
Marco marked “Bosch drill” as handed over.
Anna confirmed receiving “Bosch drill”.
Anna marked “Bosch drill” as returned.
Marco confirmed “Bosch drill” was returned.
```

Requester leg uses:

```text
requesterResourceDescription
```

from that event's terms version.

---

# 31. Historical terms drill-down

Terms events can open the immutable terms version they reference.

Always render stored snapshot content.

---

# 32. Current agreement progress UI

Enhance Agreement card/detail with per-leg progress.

Example:

```text
Bosch drill — Loan
✓ Handed over
✓ Received
○ Returned
○ Return confirmed

Pressure washer — Give
✓ Handed over
○ Received
```

No internal enum strings.

---

# 33. Who acts next

Where one next action is clear, show neutral guidance:

```text
Waiting for Anna to confirm receipt.
```

or:

```text
Your next step: confirm receipt.
```

This is derived presentation, not a persisted workflow state.

---

# 34. Overdue UI

Agreement read exposes:

```text
ownerLendReturnOverdue
requesterLendReturnOverdue
```

Surface them only for lend legs.

Copy:

```text
Return is overdue
Expected return: 23 Sep, 18:00
```

Do not say stolen, violation, late fee, breach, etc.

---

# 35. Overdue authority

Backend boolean is canonical.

Do not independently decide overdue from device clock.

Use terms timestamp only for display.

---

# 36. Overdue clearing

After a concurrent return event, Realtime refresh must canonically clear the warning when backend does.

No manual local clearing.

---

# 37. No overdue scheduled notifications

Do not schedule local timers or push reminders.

Future overdue notification behavior is separate scope.

---

# 38. Realtime reuse

Continue using the single Resource-chat private subscription.

`resource.exchange_changed` already fires for milestones and completion.

Shared ResourceExchange refresh now reloads:

```text
agreement
terms
events
```

No second channel.

---

# 39. Burst coalescing

Milestone + completion broadcasts may happen nearly together.

Coalesce to bounded canonical refresh.

Do not assume one signal maps one-to-one to final UI state.

---

# 40. Completion reconciliation

Final milestone transaction creates:

```text
milestone event
agreement_completed event
```

Use the bounded cross-read reconciliation so the UI never settles on mixed contradictory reads.

---

# 41. Cancellation history

C3C1 cancellation now appears in timeline.

Cancellation before accepted terms must still render correctly.

No milestone controls.

---

# 42. Completed history

Completed agreement shows:

- immutable current terms;
- full milestone history;
- completion event;
- read-only chat;
- no actions.

---

# 43. Negotiation history

Show historical proposals with:

```text
version number
proposer
timestamp
outcome
View terms
```

Current/pending C3C1 card behavior remains unchanged.

---

# 44. Trust wording

Allowed:

```text
PLANETS keeps a record of agreement actions and confirmations.
```

Do not claim legal proof, independent physical verification, or guaranteed dispute outcome.

---

# 45. Agreement controller extension

Extend C3C1 controller/snapshot instead of building a parallel agreement state machine unless separation clearly improves maintainability.

State should include:

```text
events
eventLoadFailure?
milestoneAction?
```

Only one agreement mutation at a time.

---

# 46. Milestone action state

Use typed action state containing:

```text
legKind
eventKind
```

Avoid a generic ambiguous `isUpdating`.

---

# 47. Stale timeline safety

If event refresh fails:

- keep human chat working;
- keep last known agreement visible;
- disable milestone actions until event history is current;
- show local retry warning.

Do not act on incomplete milestone history.

---

# 48. App resume

On active Resource chat resume:

```text
refresh agreement
terms
events
```

Overdue therefore refreshes on foreground.

No background polling.

---

# 49. Account switching

Clear:

- timeline;
- derived progress;
- in-flight milestone action;
- stale late responses.

No private history across accounts.

---

# 50. Terms-lock explanation

When in progress show:

```text
Handoff has started. Agreed terms are locked.
```

No Propose changes after first milestone.

---

# 51. Post-handoff amendments deferred

No loan extension/date change flow.

Future amendments must preserve original terms/history.

---

# 52. Exact handoff/contact remains chat-only

No structured address, phone, or email fields.

---

# 53. Tests — event parser/gateway

Cover every event kind and valid shape.

Exact RPC contracts:

```text
list_resource_exchange_agreement_events
record_resource_exchange_milestone
```

Exact leg/event wire values.

Malformed event shape fails safely.

---

# 54. Tests — historical outcomes

Cover:

```text
proposed → superseded
proposed → accepted
proposed → rejected
proposed → withdrawn
accepted current + rejected replacement
accepted current + withdrawn replacement
```

No invented outcomes.

---

# 55. Tests — leg progress

Cover all transfer topologies:

```text
give ↔ none
lend ↔ none
give ↔ give
give ↔ lend
lend ↔ give
lend ↔ lend
```

---

# 56. Tests — action matrix

For owner/requester viewers assert exact next action at:

- nothing recorded;
- provided;
- received;
- returned;
- return received.

No return controls for give.

No requester leg for none.

---

# 57. Tests — milestone controller

Cover:

- success;
- idempotent success;
- canonical reload;
- first milestone → in progress;
- final milestone → completed;
- pending terms disable actions;
- no duplicate local timeline rows.

---

# 58. Tests — PT409

```text
one mutation attempt
→ PT409
→ canonical reload
→ no retry
```

Stale action disappears after reload.

---

# 59. Tests — completion

Cover all completion topologies.

After final milestone:

- lifecycle completed;
- completion event visible;
- chat read-only;
- no mutation controls.

---

# 60. Tests — timeline

Cover:

- chronological order;
- actor names;
- owner-resource title;
- requester-resource description;
- historical terms drill-down;
- cancellation/completion;
- trust wording;
- long text / high text scale.

---

# 61. Tests — overdue

Cover:

- owner overdue;
- requester overdue;
- both overdue;
- false before due;
- false after return received;
- no give warning;
- backend boolean overrides device-time intuition.

---

# 62. Tests — Realtime burst

Simulate milestone + completion signals close together.

Verify coalesced canonical refresh and no duplicate timeline items.

---

# 63. Tests — failure isolation

Timeline failure:

- chat works;
- terms stay visible;
- milestones disabled;
- retry restores actions.

---

# 64. Localization/accessibility

Add localized copy for:

```text
Agreement history
Handoff progress
Handed over
Received
Returned
Return confirmed

Mark as handed over
Confirm received
Mark as returned
Confirm return

Waiting for {name}
Your next step

Return is overdue
Expected return {date}

These entries record participant confirmations in PLANETS.
```

Use semantic progress labels and live-region mutation errors.

---

# 65. Documentation / roadmap

Update:

```text
04C4C3C1 — PR #80
04C4C3C2 — this PR
04C4C3D — Resources notification UX
```

Document that milestones are user-confirmed statements, completion is automatic, overdue is derived and non-punitive, and amendments remain future scope.

---

# 66. Validation

Run at minimum:

```text
npm run check:mobile
flutter build apk --debug
npm run check:web
npm run check:site
git diff --check
```

Run focused Resource-exchange/chat tests.

No DB migration expected.

If local Supabase is available, run the existing focused milestone agreement verifier/pgTAP as a regression check, without expanding DB scope.

Attempt hosted Validation once.

If GitHub again cannot allocate a runner due billing/spending-limit restriction:

```text
not executed due external infrastructure
```

Do not rerun pointlessly.

---

# Non-goals

Do not implement:

- SQL/database redesign;
- Resource notification copy/routes/preferences;
- overdue scheduled notifications;
- post-handoff amendment;
- loan extension;
- dispute/damage reporting;
- liability/fault decisions;
- ratings/reputation;
- automatic moderation/blocking;
- payments/deposits;
- exact handoff location/contact;
- loan queue/calendar;
- Dona redesign;
- Project matching;
- saved searches;
- Groups/invites/WhatsApp.

---

# Acceptance criteria

- [ ] based on PR #80 F1 final head;
- [ ] exact prompt archived;
- [ ] no unnecessary DB migration;
- [ ] strict event/timeline models;
- [ ] event-list RPC integrated;
- [ ] milestone RPC integrated;
- [ ] agreement snapshot includes events;
- [ ] bounded cross-read reconciliation;
- [ ] historical terms outcomes use timeline evidence only;
- [ ] leg progress derived correctly;
- [ ] actor-specific actions mirror backend rules;
- [ ] give legs never show return controls;
- [ ] no requester leg for none;
- [ ] milestone confirmation records one canonical statement;
- [ ] PT409 never auto-retries;
- [ ] first milestone freezes terms/in-progress;
- [ ] final milestone completes automatically;
- [ ] completed/cancelled history readable;
- [ ] timeline renders negotiation, milestones, close events;
- [ ] historical terms open from timeline;
- [ ] overdue uses backend booleans;
- [ ] no legal-proof/fault wording;
- [ ] existing Resource Realtime channel reused;
- [ ] burst exchange signals coalesced;
- [ ] milestone controls disabled if event history stale;
- [ ] account switch clears private history/state;
- [ ] localization/accessibility complete;
- [ ] focused/mobile tests pass;
- [ ] debug APK passes;
- [ ] no C3D scope creep;
- [ ] no PR merged.

---

# Completion report

Return:

1. Stack/base status
2. 04C4C3C2 branch/base/PR
3. Changed files
4. Event/timeline domain models
5. Event-shape validation
6. Agreement gateway extensions
7. Canonical snapshot extension
8. Cross-read reconciliation
9. Historical terms outcome derivation
10. Leg-progress model
11. Owner-leg action matrix
12. Requester-leg action matrix
13. Milestone RPC behavior
14. Milestone confirmations
15. Idempotency behavior
16. PT409 recovery
17. First-milestone in-progress transition
18. Automatic completion
19. Agreement History UI
20. Negotiation-history rendering
21. Milestone timeline rendering
22. Historical terms drill-down
23. Progress UI
24. Who-acts-next guidance
25. Overdue presentation
26. Trust/legal wording
27. Realtime refresh/coalescing
28. Completion reconciliation
29. App-resume behavior
30. Account-switch safety
31. Failure isolation
32. Localization/accessibility
33. Gateway/parser tests
34. Progress/action-matrix tests
35. Milestone/controller tests
36. Timeline/overdue tests
37. Local regression validation
38. Hosted Validation executed/not-executed
39. 04C4C3D handoff
40. Future amendment/dispute handoff
41. Warnings/blockers
42. Commit/PR reference

Do not merge any PR.
