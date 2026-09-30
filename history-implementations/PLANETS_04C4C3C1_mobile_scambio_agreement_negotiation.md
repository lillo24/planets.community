# PLANETS 04C4C3C1 — Mobile Scambio Agreement Negotiation

**Roadmap area:** 04C4C3 — Mobile Scambio Request / Agreement / Conversation Experience  
**Task type:** Flutter/mobile agreement-negotiation integration over 04C4B/C3B  
**Repository:** `lillo24/planets.community`

## Required stack

Base this plan on:

```text
PR #79 — 04C4C3B Mobile Resource Conversation + Unified Chats
branch: codex/04c4c3b-mobile-resource-conversation
head:   1f1b6988166f95be54c486b8781a6520f79f1fc1
```

Before implementation:
1. fetch current `origin/main`;
2. confirm PR #79 still points to the expected head or reconcile newer stack movement;
3. preserve unrelated work;
4. branch from PR #79 head;
5. do not merge any PR.

Preferred branch:

```text
codex/04c4c3c1-mobile-scambio-negotiation
```

Open against:

```text
codex/04c4c3b-mobile-resource-conversation
```

Archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_04C4C3C1_mobile_scambio_agreement_negotiation.md
```

---

# Objective

Expose the reliable Scambio agreement **negotiation** domain inside the Resource conversation.

This slice covers:

```text
accepted Resource request
→ Resource conversation
→ Agreement
→ propose / counter-propose
→ other party accepts or rejects
→ mutually agreed terms
```

Also support:

```text
proposer withdraws pending proposal
either party cancels coordination before handoff
```

Do not implement physical handoff/receipt/return milestones or the full structured timeline yet.

---

# 1. Scope split

```text
04C4C3C1 — Mobile Scambio Agreement Negotiation
  this plan

04C4C3C2 — Mobile Handoff / Return / Timeline / Overdue
  later

04C4C3D — Mobile Resources Notification UX
  separate
```

---

# 2. No database migration

Use the existing RPCs exactly:

```text
get_resource_exchange_agreement
list_resource_exchange_agreement_terms

propose_resource_exchange_terms
accept_resource_exchange_terms
reject_resource_exchange_terms
withdraw_resource_exchange_terms

cancel_resource_exchange_agreement
```

No SQL changes.

---

# 3. Agreement domain

Create a focused typed domain, preferably under:

```text
features/resource_exchange/
```

Model:

```text
ResourceExchangeAgreement {
  agreementId
  requestId
  listingId
  ownerProfileId
  requesterProfileId

  lifecycle
  currentTermsId?
  pendingTermsId?
  currentTermsAcceptedAt?

  createdAt
  cancelledAt?
  cancelledByProfileId?
  completedAt?

  ownerLendReturnOverdue
  requesterLendReturnOverdue
}
```

Parse overdue flags now but defer their UI to C3C2.

Lifecycle:

```text
negotiating
agreed
inProgress
completed
cancelled
```

---

# 4. Lifecycle interpretation

## negotiating

No current accepted terms.

Negotiation controls available.

## agreed

Current accepted terms exist, handoff not started.

Negotiation/replacement/cancellation controls available.

## inProgress

Handoff started.

Terms frozen and read-only.

## completed

Read-only.

## cancelled

Read-only.

Do not infer lifecycle from chat writability alone.

---

# 5. Terms model

Create strict types for:

```text
owner transfer:
  give
  lend

requester transfer:
  none
  give
  lend
```

Immutable terms model:

```text
ResourceExchangeTerms {
  termsId
  versionNumber
  proposedByProfileId

  listingTitleSnapshot
  listingDescriptionSnapshot

  ownerTransferKind
  ownerLendStartsAt?
  ownerLendEndsAt?

  requesterTransferKind
  requesterResourceDescription?
  requesterLendStartsAt?
  requesterLendEndsAt?

  privateNote?

  createdAt
  isCurrent
  isPending
}
```

---

# 6. Agreement parsing

Parse the exact result of:

```text
get_resource_exchange_agreement(
  expectedProfileId,
  requestId
)
```

Validate:

- UUIDs;
- lifecycle;
- current/pending pointers;
- timestamps;
- overdue booleans.

Enforce locally:

```text
negotiating
→ currentTermsId == null

agreed / inProgress / completed
→ currentTermsId != null

completed
→ completedAt != null

cancelled
→ cancelledAt != null
```

A cancelled agreement may still have current terms.

Malformed payloads fail safely.

---

# 7. Terms parsing

Parse:

```text
list_resource_exchange_agreement_terms
```

Validate:

- positive unique version numbers;
- owner kind;
- requester kind;
- lend timestamps only for lend;
- lend end > lend start;
- requester description only when required;
- requester description 2..500;
- note <=1000;
- non-empty listing snapshots;
- strict `is_current` / `is_pending`.

---

# 8. Pointer reconciliation

After loading agreement + terms:

```text
currentTermsId
pendingTermsId
```

must match exact rows.

Require:

```text
currentTermsId != null
→ exactly one matching row with isCurrent=true

pendingTermsId != null
→ exactly one matching row with isPending=true
```

At most one current and one pending row.

Frozen lifecycle must not have a pending proposal.

Fail closed on inconsistencies.

---

# 9. Historical terms boundary

C3C1 loads all immutable versions but prominently renders only:

```text
current terms
pending terms
```

Do not label older versions as:

```text
rejected
withdrawn
superseded
```

because those meanings require the event timeline.

C3C2 will interpret historical versions with structured events.

---

# 10. Agreement gateway

Add RPC-only methods equivalent to:

```text
getAgreement(...)
listTerms(...)

proposeTerms(...)
acceptPendingTerms(...)
rejectPendingTerms(...)
withdrawPendingTerms(...)

cancelAgreement(...)
```

No direct table access.

---

# 11. Exact proposal payload

`propose_resource_exchange_terms` requires:

```text
p_expected_profile_id
p_agreement_id
p_expected_current_terms_id
p_expected_pending_terms_id

p_owner_transfer_kind
p_owner_lend_starts_at
p_owner_lend_ends_at

p_requester_transfer_kind
p_requester_resource_description
p_requester_lend_starts_at
p_requester_lend_ends_at

p_private_note
```

Use the loaded current/pending pointers as CAS expected values.

Do not update expected pointers while the user edits the draft.

---

# 12. Draft model

Use a separate mutable draft:

```text
ResourceExchangeTermsDraft {
  ownerTransferKind?
  ownerLendStartsAt?
  ownerLendEndsAt?

  requesterTransferKind?
  requesterResourceDescription
  requesterLendStartsAt?
  requesterLendEndsAt?

  privateNote
}
```

For a brand-new proposal require explicit choice of both:

```text
owner: Give / Lend
requester: Nothing / Give / Lend
```

Do not silently default the owner resource to Give.

---

# 13. Draft baseline

Editor initialization:

```text
pending exists
→ clone pending terms

no pending, current exists
→ clone current terms

no terms
→ start empty
```

No canonical mutation until submit.

---

# 14. Two-leg editor

## Listing owner's resource

Choice:

```text
Give permanently
Lend temporarily
```

For Lend:

```text
start date/time
end date/time
```

## Requester's side

Choice:

```text
Nothing in return
Give something
Lend something
```

For Give/Lend require:

```text
What are you offering?
```

2..500 chars.

For Lend require start/end date-time.

---

# 15. Date/time semantics

Use local date-time pickers.

Display in local timezone.

Send offset-aware/UTC values through the RPC boundary.

Validate:

```text
end > start
```

Do not invent additional loan-duration rules.

---

# 16. Private note

Optional:

```text
max 1000 chars
```

Label it as private between counterparties.

Do not use it as chat preview or notification copy.

No structured phone/address fields.

---

# 17. Client validation

Mirror backend shape:

```text
owner give
→ no lend dates

owner lend
→ both dates, increasing

requester none
→ no description/dates

requester give
→ 2..500 description, no dates

requester lend
→ 2..500 description, both dates, increasing

note
→ <=1000
```

---

# 18. Agreement controller

Use identity- and agreement/request-bound state:

```text
phase
expectedProfileId
requestId
agreementId

agreement
terms
currentTerms
pendingTerms

draft?
action
failure
```

Actions:

```text
proposing
accepting
rejecting
withdrawingProposal
cancellingAgreement
```

Account switch clears all private state and invalidates late responses.

---

# 19. Initial load

Resource chat summary already supplies:

```text
requestId
agreementId
owner/requester IDs
```

When the Resource chat is ready:

1. load agreement by request ID;
2. verify agreement ID matches chat summary;
3. verify request/listing/counterparty IDs where available;
4. load terms;
5. reconcile pointers;
6. render agreement card.

Agreement loading must not depend on there being chat messages.

---

# 20. Realtime reuse

C3B already owns the Resource private Realtime subscription.

Do not create a second subscription.

Add a lightweight shared refresh revision/provider, e.g.:

```text
resourceExchangeRefreshProvider
```

When `ResourceChatDetailController` receives:

```text
ResourceExchangeChangedSignal
```

it keeps its existing chat reconciliation and also notifies the agreement refresh provider.

The agreement controller listens and reloads:

```text
agreement
terms
```

Coalesce bursts.

---

# 21. Agreement card in Resource chat

Place a compact persistent card under the counterparty header.

Examples:

```text
Agreement
No terms agreed yet.
[ Set terms ]
```

```text
Agreement
Your proposal is waiting for the other person.
[ Review ]
```

```text
Agreement
New proposal to review.
[ Review proposal ]
```

```text
Agreement
Terms agreed.
Give ↔ Lend
[ View terms ]
```

```text
Agreement
Exchange in progress.
[ View terms ]
```

C3C2 will add milestone actions later.

---

# 22. Current-terms summary

Render:

```text
Listing owner:
Give permanently
or
Lend · date/time range

Requester:
Nothing in return
or
Give · resource description
or
Lend · resource description · date/time range
```

Use user-facing labels, not internal leg identifiers.

---

# 23. Pending proposal

Show:

```text
Proposed by You
```

or:

```text
Proposed by <counterparty>
```

Use chat identities; never display raw UUIDs.

Show full pending terms before action buttons.

---

# 24. Pending proposal — proposer actions

If viewer proposed the pending terms:

```text
Edit / Counter-propose
Withdraw proposal
```

No Accept/Reject.

Editing creates a new immutable terms version; it does not UPDATE the old version.

---

# 25. Pending proposal — counterparty actions

If the other person proposed:

```text
Accept
Reject
Counter-propose
```

No Withdraw.

Counter-propose uses one `propose_resource_exchange_terms` call that supersedes the pending version atomically.

---

# 26. No pending proposal

If lifecycle is:

```text
negotiating
agreed
```

allow:

```text
Propose terms
```

or:

```text
Propose changes
```

Do not allow proposal controls in:

```text
inProgress
completed
cancelled
```

---

# 27. Accept terms

Call exact pending pointer.

After success:

1. reload agreement;
2. reload terms;
3. refresh Resource chat summary;
4. refresh unified Chats.

Do not locally promote pending terms without canonical reload.

---

# 28. Reject terms

Only non-proposer.

After success reload canonically.

If previous current terms existed they remain current.

Use copy like:

```text
Proposal rejected
```

not:

```text
Exchange cancelled
```

---

# 29. Withdraw proposal

Only proposer.

Call exact pending pointer.

Reload canonically.

Prior current terms remain current if they existed.

---

# 30. Proposal / counterproposal success

After successful propose:

1. reload agreement;
2. reload terms;
3. refresh Resource chat;
4. refresh unified Chats;
5. dismiss/reset editor only after canonical success.

Do not fabricate a system chat message.

---

# 31. PT409 recovery

For propose/accept/reject/withdraw:

```text
PT409
→ no retry
→ preserve unsaved draft where relevant
→ reload agreement
→ reload terms
→ refresh Resource chat/list
```

Show:

```text
The agreement changed elsewhere. We loaded the latest terms.
Review them before trying again.
```

Never auto-apply stale intent to a newer proposal.

---

# 32. Other failures

Map safely:

```text
22023 → invalid input / validation
42501 → forbidden / identity changed
P0002 → not found
PT409 → stale/race
other → unavailable
```

Do not expose backend diagnostics.

---

# 33. Agreement cancellation

Include pre-handoff cancellation.

Show:

```text
Cancel coordination
```

only for:

```text
negotiating
agreed
```

Do not show for:

```text
inProgress
completed
cancelled
```

---

# 34. Cancellation confirmation

Require confirmation.

Explain:

```text
This ends the current coordination.
The conversation and agreement history will remain visible.
```

No deletion language.

---

# 35. Cancel success

Call:

```text
cancel_resource_exchange_agreement
```

Then reload:

```text
agreement
terms
Resource chat summary
unified Chats
Resource request/unified Requests where practical
```

The chat composer should disappear from canonical chat state.

---

# 36. Cancel PT409

If handoff began elsewhere or coordination already closed:

```text
no retry
reload everything canonically
```

Show:

```text
This agreement changed and can no longer be cancelled here.
```

---

# 37. Frozen state

For:

```text
inProgress
completed
cancelled
```

terms are read-only.

If a pending pointer appears in a frozen lifecycle, treat state as malformed/unavailable.

---

# 38. In-progress boundary

Show:

```text
Exchange in progress
The agreed terms are now locked.
```

No fake completion or milestone controls.

C3C2 owns them.

---

# 39. Completed / cancelled presentation

Completed:

```text
Exchange completed
```

Cancelled:

```text
Coordination cancelled
```

Show immutable current terms if present.

Do not confuse cancelled with completed.

---

# 40. Terms editor UX

Use a scrollable bottom sheet or full-screen editor.

Prefer:
- clear two-leg sections;
- explicit segmented/radio choices;
- conditional date/resource fields;
- inline validation;
- one Propose/Save action.

---

# 41. Counterparty labels

Make roles explicit:

```text
Listing owner provides
Requester provides
```

Known names may be added, but names alone must not encode direction.

Either party may be editing.

---

# 42. Listing snapshots

When rendering existing terms, use:

```text
listingTitleSnapshot
listingDescriptionSnapshot
```

Do not replace them with current public listing text.

For a brand-new draft, current listing/chat title may be used as context; the server owns the eventual snapshot.

---

# 43. Private note display

Show only inside agreement/terms UI.

Never in:
- Chats preview;
- Requests preview;
- notification copy.

---

# 44. Date formatting/accessibility

Render lend date ranges in local timezone with date + time.

For multi-day ranges show both dates.

Semantics should explicitly identify loan start/end.

---

# 45. Chat integration

Primary entry remains:

```text
Resource conversation → Agreement
```

No new top-level agreement destination is needed.

---

# 46. Failure isolation

Human chat must keep working if agreement load fails.

Agreement area gets its own:

```text
loading
error
retry
```

Do not replace the whole chat screen with an agreement error.

---

# 47. Realtime refresh failure

If `resource.exchange_changed` arrives and agreement reload fails transiently:

- keep last known terms visible;
- show local warning/retry;
- keep chat functioning.

---

# 48. App resume

When Resource chat resumes:

```text
refresh agreement + terms
```

alongside C3B chat refresh behavior.

No polling loop.

---

# 49. Tests — parser/gateway

Cover:
- all lifecycles;
- pointer shapes;
- cancelled with/without current terms;
- completed timestamps;
- overdue booleans parsed only;
- all transfer combinations;
- lend-date validation;
- description/note bounds;
- current/pending flags;
- exact RPC names/params.

---

# 50. Tests — pointer reconciliation

Cover:
- no current/no pending;
- current only;
- pending only;
- current + pending;
- missing pointed row;
- duplicate current/pending;
- mismatched IDs;
- frozen lifecycle with pending pointer.

---

# 51. Tests — draft validation

Cover all six valid combinations:

```text
give ↔ none
lend ↔ none
give ↔ give
give ↔ lend
lend ↔ give
lend ↔ lend
```

and invalid date/description/note shapes.

---

# 52. Tests — controller

Cover:
- load;
- current/pending;
- draft baseline;
- propose;
- counter-propose;
- accept;
- reject;
- withdraw;
- cancel;
- canonical reloads;
- identity switch;
- late responses;
- agreement failure independent from chat.

---

# 53. Tests — action matrix

Pending by viewer:

```text
Edit/Counter-propose
Withdraw
```

Pending by other:

```text
Accept
Reject
Counter-propose
```

No pending:

```text
Propose terms / Propose changes
```

Frozen lifecycle:

```text
no mutation controls
```

---

# 54. Tests — PT409

For all negotiation/cancel mutations:

```text
one attempt
→ PT409
→ canonical reload
→ no automatic retry
```

Preserve draft where relevant.

---

# 55. Tests — cancellation

Cover:
- negotiating cancel;
- agreed cancel;
- confirmation;
- success makes chat read-only;
- PT409 after handoff begins;
- no cancel in closed states.

---

# 56. Tests — agreement card

Cover:
- no terms;
- pending self;
- pending counterparty;
- current terms;
- current + pending replacement;
- in progress;
- completed;
- cancelled;
- local agreement failure;
- long text / high text scale.

---

# 57. Tests — shared Realtime refresh

Simulate `ResourceExchangeChangedSignal` and verify:
- no second Realtime subscription;
- agreement reload;
- existing chat refresh still happens;
- burst signals coalesced;
- account switch blocks stale reload.

---

# 58. Documentation / roadmap

Update:

```text
04C4C3A — PR #78
04C4C3B — PR #79
04C4C3C1 — this PR
04C4C3C2 — handoff/return/timeline/overdue
04C4C3D — Resources notification UX
```

Document:
- immutable versioned terms;
- counterproposal creates new version;
- handoff freezes terms;
- C3C1 does not label older historical terms without event timeline.

---

# 59. Validation

Run at minimum:

```text
npm run check:mobile
flutter build apk --debug
npm run check:web
npm run check:site
git diff --check
```

Run focused Flutter tests and formatting.

No DB migration is expected.

Attempt hosted Validation once.

If GitHub cannot allocate a runner because of the known billing/spending-limit state:

```text
not executed due external infrastructure
```

Do not rerun pointlessly.

---

# Non-goals

Do not implement:
- SQL/database changes;
- milestone controls;
- resource-provided/received/returned actions;
- full agreement timeline;
- historical proposal status labels;
- overdue UI;
- completion UX;
- Resource notification copy/routes/preferences;
- post-handoff amendments;
- disputes/moderation;
- payment/deposit;
- loan queue/calendar;
- Dona redesign;
- Project matching;
- saved searches;
- Groups/invites/WhatsApp.

---

# Acceptance criteria

- [ ] based on PR #79;
- [ ] exact prompt archived;
- [ ] no DB migration;
- [ ] strict agreement/terms models;
- [ ] agreement/terms gateway;
- [ ] fail-closed pointer reconciliation;
- [ ] agreement card inside Resource chat;
- [ ] chat remains usable on agreement failure;
- [ ] new proposal requires explicit transfer choices;
- [ ] two-leg editor mirrors backend give/lend rules;
- [ ] local date/time lend ranges validated;
- [ ] proposal/counterproposal sends exact current/pending CAS pointers;
- [ ] proposer can counter/withdraw;
- [ ] counterparty can accept/reject/counter;
- [ ] in-progress/completed/cancelled is read-only;
- [ ] no invented historical status labels;
- [ ] PT409 canonical reload with no retry;
- [ ] proposal draft preserved on conflict;
- [ ] cancel confirmation and canonical refresh;
- [ ] only one Resource Realtime subscription;
- [ ] exchange-change refreshes agreement through shared signal;
- [ ] account switching clears private state;
- [ ] localization/accessibility complete;
- [ ] focused/mobile tests pass;
- [ ] debug APK passes;
- [ ] no C3C2/C3D scope creep;
- [ ] no PR merged.

---

# Completion report

Return:
1. Stack/base status
2. 04C4C3C1 branch/base/PR
3. Changed files
4. Agreement domain models
5. Terms domain models
6. Agreement lifecycle parsing
7. Terms parsing
8. Pointer reconciliation
9. Agreement gateway
10. Proposal RPC payload
11. Terms draft model
12. Draft baseline behavior
13. Two-leg editor
14. Give/lend date handling
15. Private note handling
16. Agreement controller
17. Agreement card
18. Current terms presentation
19. Pending proposal presentation
20. Proposer action matrix
21. Counterparty action matrix
22. Proposal/counterproposal behavior
23. Accept behavior
24. Reject behavior
25. Withdraw-proposal behavior
26. PT409 recovery
27. Agreement cancellation
28. Cancellation conflict recovery
29. Frozen/in-progress behavior
30. Completed/cancelled presentation
31. Shared Realtime refresh integration
32. App-resume behavior
33. Chat/agreement failure isolation
34. Localization/accessibility
35. Gateway/controller/widget tests
36. Local regression validation
37. Hosted Validation executed/not-executed
38. 04C4C3C2 handoff
39. 04C4C3D handoff
40. Warnings/blockers
41. Commit/PR reference

Do not merge any PR.
