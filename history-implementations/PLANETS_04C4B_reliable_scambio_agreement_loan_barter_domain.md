# PLANETS 04C4B — Reliable Scambio Agreement + Loan/Barter Domain

**Roadmap area:** 04C4 — Scambio-Dona Requests, Agreements and Matching  
**Task type:** Backend/domain foundation  
**Repository:** `lillo24/planets.community`

## Required stack

Base this plan on the current top of the open stack:

```text
PR #71 — 04C4A Scambio-Dona Resource Request Domain Foundation
branch: codex/04c4a-resource-request-domain
head:   29a242e7cdf2b8319c73565351124ad79cd7a1e9
```

Its base PR #70 and the lower 04C3/05C stack remain open/unmerged.

Before implementation:

1. fetch current `origin/main`;
2. verify PR #71 still points to the expected head or reconcile any newer stacked head;
3. preserve unrelated changes;
4. branch from the final PR #71 head;
5. do not merge any PR.

Preferred branch:

```text
codex/04c4b-reliable-scambio-agreement-domain
```

Open the new PR with base:

```text
codex/04c4a-resource-request-domain
```

Archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_04C4B_reliable_scambio_agreement_loan_barter_domain.md
```

No external document is required by Codex.

---

# Objective

Add the canonical private agreement/history domain that sits **after** an accepted Scambio-Dona request.

04C4A established:

```text
listing
→ request
→ pending
→ accepted/rejected/withdrawn/listing_closed
```

04C4B establishes:

```text
accepted request
→ agreement anchor
→ proposed structured terms
→ counterparty accepts
→ handoff / receipt
→ if lending: return / return receipt
→ completed
```

The main product goal is to make Scambio reliable enough that users can later see a factual structured record of:

- what was agreed;
- what each side was giving or lending;
- the loan period when applicable;
- who marked handoff/receipt/return milestones;
- when those statements happened.

This history supports trust and future moderation.

It is **not** an automatic legal judgment, guarantee, insurance policy, or proof of liability.

---

# 1. Agreement model: two legs

Do not create separate transaction types for every combination.

Model one agreement as up to two resource-transfer legs.

## Owner/listing leg — required

The owner is providing the resource represented by the original listing.

Transfer kind:

```text
give
lend
```

## Requester/counterpart leg — optional

The requester may provide something in return.

Transfer kind:

```text
none
give
lend
```

This supports:

```text
give ↔ none
lend ↔ none
give ↔ give
give ↔ lend
lend ↔ give
lend ↔ lend
```

Examples:

```text
owner gives desk
requester gives bookshelf

owner gives cabinet
requester lends drill for 10 days

owner lends garden tiller
requester gives leftover timber

owner lends ladder
requester lends pressure washer
```

No money/payment fields.

---

# 2. Dona remains secondary

Do not redesign `resource_listings.listing_mode`.

Keep current:

```text
donate
exchange
```

as discovery-intent compatibility fields.

Agreement terms are the reliable truth of what is actually being arranged.

Do not enforce rigid semantics such as:

```text
listing_mode = donate → requester leg must be none
listing_mode = exchange → requester leg must be non-none
```

because the future listing policy is intentionally still being refined.

Future UX may distinguish:

```text
"Dona, or if possible Scambia"
"Solo Scambio"
```

without rewriting historical agreements.

---

# 3. Agreement anchor

Add a canonical private table equivalent to:

```text
public.resource_exchange_agreements
```

Conceptual fields:

```text
id uuid primary key
request_id uuid unique not null

lifecycle_state text not null
current_terms_id uuid nullable
pending_terms_id uuid nullable
current_terms_accepted_at timestamptz nullable

created_at timestamptz not null
cancelled_at timestamptz nullable
cancelled_by_profile_id uuid nullable
completed_at timestamptz nullable
```

Supported lifecycle states:

```text
negotiating
agreed
in_progress
completed
cancelled
```

One agreement per accepted request.

---

# 4. Agreement creation happens on request acceptance

Evolve the latest canonical:

```text
accept_resource_listing_request(...)
```

through a new forward migration.

When:

```text
pending → accepted
```

the same transaction must create exactly one agreement anchor:

```text
lifecycle_state = negotiating
```

Do not wait for the mobile client to create it later.

Benefits:

- every accepted request has a reliable coordination anchor;
- accepted coordination can later be cancelled even before terms are proposed;
- future request-specific chat can reference the agreement immediately.

Backfill an agreement anchor for any already-existing `accepted` request that lacks one.

No duplicate anchors.

---

# 5. Request coordination closure

04C4A correctly left accepted requests as active coordination.

04C4B must now distinguish:

```text
accepted + coordination still open
accepted + coordination finished/cancelled
```

Add request fields equivalent to:

```text
coordination_closed_at timestamptz nullable
coordination_closed_by_profile_id uuid nullable
```

Do not change the 04C4A request status away from:

```text
accepted
```

when the later agreement finishes.

The request decision history remains:

```text
accepted
```

while the agreement owns later coordination lifecycle.

---

# 6. Active-request uniqueness after 04C4B

Replace the 04C4A active partial uniqueness so a requester/listing blocks another request only while:

```text
status = pending
OR
(
  status = accepted
  AND coordination_closed_at IS NULL
)
```

After agreement:

```text
completed
or
cancelled
```

the coordination closes and that same requester may later create a new request for the still-published listing.

This is essential for repeat/sequential lending.

Preserve historical request episodes.

---

# 7. Public active-interest count after 04C4B

Update public list/detail active count.

Count:

```text
pending
+
accepted with coordination_closed_at IS NULL
```

Do not count:

```text
rejected
withdrawn
listing_closed
accepted + completed agreement
accepted + cancelled agreement
```

No requester identity leakage.

---

# 8. Immutable terms versions

Add a private table equivalent to:

```text
public.resource_exchange_agreement_terms
```

Each row is one immutable proposed terms version.

Conceptual fields:

```text
id uuid primary key
agreement_id uuid not null
version_number integer not null
proposed_by_profile_id uuid not null

listing_title_snapshot text not null
listing_description_snapshot text not null

owner_transfer_kind text not null
owner_lend_starts_at timestamptz nullable
owner_lend_ends_at timestamptz nullable

requester_transfer_kind text not null
requester_resource_description text nullable
requester_lend_starts_at timestamptz nullable
requester_lend_ends_at timestamptz nullable

private_note text nullable

created_at timestamptz not null
```

Unique:

```text
(agreement_id, version_number)
```

Terms content is immutable after insert.

Agreement pointers decide which terms are pending/current.

---

# 9. Listing snapshot

Every proposed terms version snapshots the current listing:

```text
title
description
```

The caller does **not** supply those snapshots.

The database reads them from the listing while creating the version.

This ensures the eventual accepted agreement preserves what resource description the parties agreed around even if the public listing is edited later.

Do not snapshot:

- public rough location;
- profile fields;
- private chat;
- future exact handoff location.

---

# 10. Owner transfer validation

Supported:

```text
give
lend
```

## `give`

Require:

```text
owner_lend_starts_at = null
owner_lend_ends_at = null
```

## `lend`

Require both:

```text
owner_lend_starts_at
owner_lend_ends_at
```

and:

```text
owner_lend_ends_at > owner_lend_starts_at
```

No open-ended loan in this foundation.

A reliable loan must have an agreed expected period.

---

# 11. Requester transfer validation

Supported:

```text
none
give
lend
```

## `none`

Require:

```text
requester_resource_description = null
requester_lend_starts_at = null
requester_lend_ends_at = null
```

## `give`

Require:

```text
requester_resource_description
```

bounded plain text.

Loan timestamps null.

## `lend`

Require:

```text
requester_resource_description
requester_lend_starts_at
requester_lend_ends_at
```

and end > start.

Initial description limit:

```text
2..500 chars
```

Do not create a global resource taxonomy here.

Do not require the requester to create another public listing.

---

# 12. Private agreement note

Allow an optional private terms note:

```text
max 1000 chars
trim
blank → null
```

Use for relevant agreement context not captured by structured fields.

Do not place:

- phone;
- email;
- exact location;

into dedicated structured fields in this slice.

Users may later coordinate those privately in the request conversation.

Never expose this note publicly or in identifier-only events.

---

# 13. Both parties may propose/counter-propose

Add an RPC equivalent to:

```text
propose_resource_exchange_terms(
  p_expected_profile_id uuid,
  p_agreement_id uuid,

  p_expected_current_terms_id uuid,
  p_expected_pending_terms_id uuid,

  p_owner_transfer_kind text,
  p_owner_lend_starts_at timestamptz,
  p_owner_lend_ends_at timestamptz,

  p_requester_transfer_kind text,
  p_requester_resource_description text,
  p_requester_lend_starts_at timestamptz,
  p_requester_lend_ends_at timestamptz,

  p_private_note text
)
returns uuid
```

Exact signature may vary slightly if repository conventions justify it.

Authorize only:

```text
listing owner
request requester
```

Use expected current/pending pointers as CAS.

On stale pointer:

```text
PT409
```

No automatic retry.

---

# 14. Counter-proposal semantics

A newly proposed terms version becomes:

```text
pending_terms_id
```

If another pending proposal already existed and expected CAS matched:

- preserve old immutable version;
- emit structured `terms_superseded` history;
- point pending to the new version.

The new proposer may be either party.

This is a counter-proposal.

Do not mutate the old terms row.

---

# 15. Pending terms acceptance

Add:

```text
accept_resource_exchange_terms(
  p_expected_profile_id uuid,
  p_agreement_id uuid,
  p_expected_pending_terms_id uuid
)
```

Only the **other party** may accept the pending version.

The proposer cannot accept their own proposal.

On success:

```text
current_terms_id = pending_terms_id
pending_terms_id = null
current_terms_accepted_at = now
lifecycle_state = agreed
```

The accepted terms version remains immutable.

Emit structured timeline/outbox identifiers only.

---

# 16. Pending terms rejection

Add:

```text
reject_resource_exchange_terms(...)
```

Only the non-proposer counterparty.

Require exact pending pointer.

On success:

```text
pending_terms_id = null
```

Keep prior current terms if one already existed.

If no current terms exists:

```text
lifecycle remains negotiating
```

Preserve rejected version as immutable history.

---

# 17. Pending terms withdrawal

Add:

```text
withdraw_resource_exchange_terms(...)
```

Only the pending terms proposer.

Clear pending pointer.

Preserve immutable version/history.

---

# 18. Terms may change before handoff

Before any resource milestone has been recorded:

```text
current accepted terms may later be replaced
by another mutually accepted terms version
```

This supports ordinary negotiation before exchange begins.

Do not rewrite the previous accepted terms row.

History remains visible.

---

# 19. Terms freeze when handoff begins

Once any handoff/receipt/return milestone exists:

```text
no new terms proposal
no pending terms acceptance
```

The current accepted terms are frozen.

This is necessary so later history cannot rewrite what users had already started performing.

Loan extensions/amendments **after handoff** are explicitly deferred to a future structured amendment flow.

Do not silently allow changing the due date after handoff.

---

# 20. Structured append-only agreement timeline

Add an immutable private table equivalent to:

```text
public.resource_exchange_agreement_events
```

Conceptual fields:

```text
id uuid primary key
agreement_id uuid not null
terms_id uuid nullable
event_kind text not null
leg_kind text nullable
actor_profile_id uuid not null
created_at timestamptz not null
```

No arbitrary event body.

No public access.

---

# 21. Agreement-level event kinds

Support structured events equivalent to:

```text
agreement_created
terms_proposed
terms_superseded
terms_accepted
terms_rejected
terms_withdrawn
agreement_cancelled
agreement_completed
```

For these:

```text
leg_kind = null
```

`terms_id` is present where relevant.

---

# 22. Resource milestone event kinds

Use generic milestone kinds:

```text
resource_provided
resource_received
resource_returned
resource_return_received
```

with:

```text
leg_kind = owner_resource
or
leg_kind = requester_resource
```

Every milestone is a statement made by one party at a timestamp.

The timeline records:

```text
who said it
what milestone they stated
which resource leg
when
```

It does not claim that PLANETS independently verified the physical event.

---

# 23. Milestone authorization — owner resource leg

Provider:

```text
listing owner
```

Recipient:

```text
requester
```

Allowed:

## Give or lend

Owner:

```text
resource_provided
```

Requester:

```text
resource_received
```

## Lend only

Requester:

```text
resource_returned
```

Owner:

```text
resource_return_received
```

Reject invalid actor/milestone combinations.

---

# 24. Milestone authorization — requester resource leg

This leg exists only if:

```text
requester_transfer_kind != none
```

Provider:

```text
requester
```

Recipient:

```text
listing owner
```

Allowed:

## Give or lend

Requester:

```text
resource_provided
```

Owner:

```text
resource_received
```

## Lend only

Owner:

```text
resource_returned
```

Requester:

```text
resource_return_received
```

Reject any milestone for `none`.

---

# 25. One milestone of each required kind

Use a hard uniqueness invariant equivalent to:

```text
(agreement_id, terms_id, leg_kind, event_kind)
```

for milestone events.

Duplicate calls should be safe/idempotent where practical:

```text
same canonical milestone already recorded
→ return existing success
```

Do not create duplicate history.

---

# 26. Milestone RPC

A single hardened RPC is acceptable:

```text
record_resource_exchange_milestone(
  p_expected_profile_id uuid,
  p_agreement_id uuid,
  p_expected_terms_id uuid,
  p_leg_kind text,
  p_event_kind text
)
returns uuid
```

if strict authorization/shape validation is centralized.

Separate narrow RPCs are also acceptable if clearer.

The expected terms ID must equal:

```text
current_terms_id
```

Otherwise:

```text
PT409
```

---

# 27. Starting handoff

Before the first milestone:

Require:

```text
current_terms_id is not null
pending_terms_id is null
lifecycle_state = agreed
```

The first valid milestone changes:

```text
agreed → in_progress
```

After that:

```text
terms frozen
```

---

# 28. Automatic completion rule

Do not require a separate arbitrary “Complete” button.

An agreement becomes `completed` automatically when all required milestones for current terms exist.

## Give leg complete

Requires:

```text
resource_provided
resource_received
```

## Lend leg complete

Requires:

```text
resource_provided
resource_received
resource_returned
resource_return_received
```

## Agreement complete

Every existing leg is complete.

Then atomically:

```text
lifecycle_state = completed
completed_at = now
request.coordination_closed_at = now
request.coordination_closed_by_profile_id = actor completing final milestone
```

Emit:

```text
agreement_completed
```

and identifier-only outbox/audit event.

---

# 29. Agreement cancellation

Add:

```text
cancel_resource_exchange_agreement(
  p_expected_profile_id uuid,
  p_agreement_id uuid
)
```

Either owner or requester may cancel while:

```text
negotiating
or
agreed
```

but only if **no resource milestone has occurred**.

On cancellation:

```text
lifecycle_state = cancelled
cancelled_at = now
cancelled_by_profile_id = actor
pending_terms_id = null

request.coordination_closed_at = now
request.coordination_closed_by_profile_id = actor
```

Keep:

- accepted request history;
- current/old terms rows;
- event history.

After any milestone:

```text
cancellation is blocked
```

Problems after handoff belong to future dispute/moderation flows.

---

# 30. New request after completed/cancelled coordination

If listing remains `published`, after:

```text
completed
or
cancelled
```

the same requester may create a new request.

This supports:

- repeat borrowing;
- future sequential loan episodes;
- a new barter arrangement.

The old accepted request/agreement remains historical.

---

# 31. Listing closure behavior

Closing the listing:

- still closes only `pending` 04C4A requests to `listing_closed`;
- does **not** cancel accepted agreements;
- does **not** erase negotiating/agreed/in-progress agreements;
- does **not** prevent those accepted coordination episodes from completing.

An accepted agreement remains private history after listing closure.

---

# 32. Agreement privacy

Only:

```text
listing owner
requester
```

may read:

- agreement;
- all terms versions;
- event timeline.

No public terms.

No other authenticated-user access.

No public dates describing private loan arrangements.

Public listing still exposes only the active-interest count.

---

# 33. Agreement reads

Add narrow reads equivalent to:

```text
get_resource_exchange_agreement(
  p_expected_profile_id uuid,
  p_request_id uuid
)
```

Return:

```text
agreement_id
request_id
listing_id
owner_profile_id
requester_profile_id
lifecycle_state
current_terms_id
pending_terms_id
current_terms_accepted_at
created_at
cancelled_at
cancelled_by_profile_id
completed_at
```

No arbitrary JSON blob.

---

# 34. Terms-history read

Add:

```text
list_resource_exchange_agreement_terms(
  p_expected_profile_id uuid,
  p_agreement_id uuid
)
```

Return all immutable versions with:

- structured fields;
- proposer;
- version number;
- timestamps;
- enough pointer/status information to identify:
  - current;
  - pending;
  - historical/superseded/rejected/withdrawn via timeline.

Newest-first or version-order deterministic.

---

# 35. Timeline read

Add:

```text
list_resource_exchange_agreement_events(
  p_expected_profile_id uuid,
  p_agreement_id uuid
)
```

Return:

```text
event_id
event_kind
terms_id
leg_kind
actor_profile_id
actor_display_name
created_at
```

The display name is private counterpart context.

No extra profile data.

---

# 36. Derived loan overdue indicators

In the authorized agreement/current-terms read, expose derived booleans where practical:

```text
owner_lend_return_overdue
requester_lend_return_overdue
```

True only when:

- that leg is `lend`;
- current time is after agreed lend end;
- `resource_return_received` has not been recorded for that leg;
- agreement is not cancelled/completed.

This is derived current truth.

Do not emit an event merely because time passes.

Do not notify yet.

---

# 37. Agreement update events/outbox

Emit identifier-only outbox/audit events for meaningful transitions.

Recommended event types:

```text
resource_exchange.agreement_created
resource_exchange.terms_proposed
resource_exchange.terms_accepted
resource_exchange.terms_rejected
resource_exchange.terms_withdrawn
resource_exchange.agreement_cancelled
resource_exchange.milestone_recorded
resource_exchange.agreement_completed
```

A superseded pending proposal may use:

```text
resource_exchange.terms_superseded
```

Payload identifiers only, conceptually:

```text
agreement_id
request_id
listing_id
owner_profile_id
requester_profile_id
terms_id where relevant
agreement_event_id where relevant
actor_profile_id
```

Do not include:

- resource description;
- listing snapshot text;
- note;
- loan timestamps;
- exact handoff data;
- chat body.

---

# 38. Do not project notifications yet

No in-app notification rows.

No push jobs.

No Messages conversation in 04C4B.

04C4C will use these identifier-only transitions.

---

# 39. No exact handoff location

Do not add:

```text
address
coordinates
phone
email
```

to agreement terms.

Private exact coordination belongs to the accepted request conversation later.

This minimizes sensitive structured data.

---

# 40. No damage/liability adjudication

Do not implement:

- damage claim;
- monetary compensation;
- deposit;
- insurance;
- fault;
- legal liability;
- automatic user blocking;
- reputation penalty.

The structured agreement/history exists so later moderation can inspect factual records.

Plan 09/future Scambio dispute design owns consequences and contestation.

---

# 41. No post-handoff terms amendment yet

Once first milestone exists:

```text
terms locked
```

Do not build extensions/change-of-due-date in this plan.

Document future requirement:

```text
structured mutually accepted amendment
```

for cases such as:

```text
"Can I keep the drill three more days?"
```

That future flow must preserve the old due date and amendment history rather than rewriting the original terms.

---

# 42. Concurrency — request accept vs agreement creation

The updated request-accept transaction must guarantee:

```text
accepted request
⇔ exactly one agreement anchor
```

No window where accepted request commits without anchor.

Backfill existing accepted requests deterministically.

---

# 43. Concurrency — competing terms proposals

Use agreement locking + expected pointers.

Example:

```text
Owner sees current=A, pending=null
Requester sees current=A, pending=null

Owner proposes B
Requester concurrently proposes C

one wins
loser → PT409
```

No silent proposal overwrite.

---

# 44. Concurrency — accept vs counter-propose

Example:

```text
pending=B

requester accepts B
owner concurrently proposes C
```

Serialize.

Valid outcomes:

```text
B accepted
or
C becomes pending
```

No accepting a proposal that was already superseded.

Expected pointers enforce this.

---

# 45. Concurrency — cancel vs first milestone

Exactly one wins.

If cancel wins:

```text
agreement cancelled
milestone rejected
```

If milestone wins:

```text
agreement in_progress
cancellation rejected
```

No cancelled agreement with handoff event.

---

# 46. Concurrency — final milestone completion

If two last-required confirmations race:

- unique event invariant prevents duplicates;
- agreement completion happens exactly once;
- coordination close happens exactly once;
- completion event/outbox occurs exactly once.

---

# 47. PT409 convention

Preserve DB-COMPAT-01.

Use:

```text
PT409
```

for explicit application concurrency/stale-pointer conflicts.

Never introduce custom `40001`.

---

# 48. RLS / grants

All new agreement/terms/event tables:

- RLS enabled;
- no direct client policies;
- revoke public/anon/authenticated/service table grants;
- access only through hardened RPCs;
- empty/fixed search paths;
- private helpers not client executable.

Terms/event rows are private to the two counterparties.

---

# 49. Structural pgTAP

Cover:

- agreement table;
- one agreement per request;
- lifecycle state constraint;
- terms table;
- version uniqueness;
- transfer-kind constraints;
- lend date invariants;
- requester-none shape;
- immutable terms;
- event table;
- structured event/leg constraints;
- milestone uniqueness;
- request coordination-close fields;
- updated active uniqueness;
- RLS/no policies/no direct grants;
- exact RPC signatures;
- current public active-count contract.

---

# 50. Behavioral pgTAP — agreement creation

Cover:

- accepting request creates agreement atomically;
- existing accepted request backfill;
- no agreement for rejected/withdrawn/listing_closed;
- agreement one-to-one;
- owner/requester authorized reads;
- unrelated denied;
- anonymous denied.

---

# 51. Behavioral pgTAP — terms shapes

Cover all combinations:

```text
give ↔ none
lend ↔ none
give ↔ give
give ↔ lend
lend ↔ give
lend ↔ lend
```

Validate:

- lend start/end required;
- lend end > start;
- give has no lend timestamps;
- requester none has no description/dates;
- requester give/lend requires description;
- private note trim/bounds;
- listing snapshot copied by server.

---

# 52. Behavioral pgTAP — negotiation

Cover:

- owner proposes;
- requester proposes;
- counterparty accepts;
- proposer cannot self-accept;
- counterparty rejects;
- proposer withdraws;
- counter-proposal supersedes old pending terms without deleting them;
- current accepted terms remain until replacement accepted;
- stale current/pending pointers → PT409;
- terms versions remain immutable.

---

# 53. Behavioral pgTAP — handoff

Cover give owner leg:

```text
owner provided
requester received
→ leg complete
```

Cover lend owner leg:

```text
owner provided
requester received
requester returned
owner return_received
→ leg complete
```

Mirror for requester leg.

Verify invalid actor/milestone combinations rejected.

Duplicate milestone no duplicate history.

---

# 54. Behavioral pgTAP — automatic completion

Cover:

- one-leg give agreement;
- one-leg lend agreement;
- two give legs;
- give + lend;
- lend + lend.

Agreement completes only after all required milestones.

Completion:

- timestamp set;
- request coordination closed;
- public active interest drops;
- one completion event.

---

# 55. Behavioral pgTAP — cancellation

Cover:

- cancel negotiating;
- cancel agreed before handoff;
- either party may cancel;
- request coordination closes;
- later new request same requester/listing permitted;
- cannot cancel after any milestone;
- old terms/events remain readable.

---

# 56. Behavioral pgTAP — listing closure

Cover accepted agreement with listing close during:

```text
negotiating
agreed
in_progress
```

Agreement remains usable.

Pending unrelated requests still become `listing_closed`.

Public listing disappears.

Private agreement remains readable/completable.

---

# 57. Behavioral pgTAP — overdue

For lend leg:

- before due → false;
- after due before return received → true;
- after return received → false;
- completed → false;
- cancelled → false.

No outbox event generated from passage of time alone.

---

# 58. Real OTP / concurrency verifier

Add a focused verifier covering at least:

1. owner publishes listing;
2. requester sends request;
3. owner accepts;
4. agreement anchor exists immediately;
5. owner proposes give↔give;
6. requester counter-proposes give↔lend;
7. owner accepts;
8. terms history preserves both versions;
9. verify private snapshot/note isolation;
10. record handoff milestones with both parties;
11. complete agreement automatically;
12. active-interest count falls after completion;
13. same requester can create another request;
14. second scenario: lend↔none with overdue derivation;
15. agreement cancellation before handoff;
16. cancellation blocked after milestone;
17. competing proposals PT409;
18. accept-vs-counterproposal race;
19. cancel-vs-first-milestone race;
20. final-milestone completion race;
21. listing close does not destroy accepted agreement;
22. unrelated/anonymous cannot read agreement;
23. events contain identifiers only.

Never log:

- auth tokens;
- OTP;
- private notes;
- requester resource description;
- listing snapshot description;
- loan timestamps in event dumps;
- chat/contact data.

---

# 59. Generated types

Update/regenerate database types for:

- agreement table;
- terms table;
- event table;
- request coordination-close fields;
- agreement RPCs;
- public listing/detail result shape if active count semantics stay same type.

If Docker remains unavailable:

- derive only compile-required changes carefully;
- document unverified drift;
- keep DB type-drift check as hard merge blocker.

---

# 60. Documentation / roadmap

Update 04C4B accurately.

Document:

```text
04C4A request decision
!=
04C4B agreement lifecycle
```

Document two-leg transfer model.

Document:

```text
accepted request
→ agreement anchor

completed/cancelled agreement
→ closes active coordination episode
→ request status remains accepted historically
```

Document terms freeze at first milestone.

Document future structured post-handoff amendment requirement.

No product Google Doc edits from Codex.

---

# 61. 04C4C handoff

04C4C mobile/Messages should be able to rely on:

```text
04C4A request RPCs
get_resource_exchange_agreement
list_resource_exchange_agreement_terms
list_resource_exchange_agreement_events
propose_resource_exchange_terms
accept_resource_exchange_terms
reject_resource_exchange_terms
withdraw_resource_exchange_terms
cancel_resource_exchange_agreement
record_resource_exchange_milestone
```

Future UI:

```text
Messages request item
→ accepted
→ private request conversation
→ agreement card
→ propose/counter-propose
→ accept
→ milestone controls
```

Do not implement UI here.

---

# 62. 04C4D queue handoff

04C4D can later use **accepted/current lend terms periods** to detect scheduling conflicts.

Do not add reservation/queue tables now.

Do not enforce one lend at a time globally yet.

04C4D owns:

- listing-level availability windows;
- sequential borrowers;
- calendar conflict rules;
- queue order;
- waitlist presentation.

---

# 63. Validation policy

Run all available non-DB checks:

```text
npm run check:web
npm run check:site
npm run check:mobile
node --check <new verifier>
git diff --check
```

Run SQL grammar parsing.

Attempt hosted Validation exactly once.

If GitHub cannot allocate a runner due the known billing/spending-limit issue:

```text
not executed due external infrastructure
```

Do not rerun pointlessly.

Because 04C4B is schema-heavy, do not merge until:

- clean migration replay;
- DB lint/advisors;
- pgTAP;
- real OTP/integration;
- generated-type drift

all execute green.

---

# Non-goals

Do not implement:

- Flutter/mobile agreement UI;
- request-specific chat;
- notifications/push;
- listing policy redesign;
- Dona UX refinement;
- `lend` listing-mode field;
- loan queue/calendar;
- availability windows;
- post-handoff loan extensions/amendments;
- damage/non-return dispute;
- moderation action;
- reputation/rating;
- payment/deposit;
- exact handoff address/contact;
- Project matching;
- saved searches;
- resource taxonomy;
- media.

---

# Acceptance criteria

Ready for review when:

- [ ] based on PR #71;
- [ ] exact prompt archived;
- [ ] request acceptance atomically creates one agreement anchor;
- [ ] existing accepted requests backfilled;
- [ ] request coordination-close fields added;
- [ ] active uniqueness/count exclude completed/cancelled coordination;
- [ ] agreement uses two-leg model;
- [ ] owner leg give/lend;
- [ ] requester leg none/give/lend;
- [ ] lend legs require structured start/end;
- [ ] terms versions immutable;
- [ ] listing title/description snapshotted server-side;
- [ ] either party can propose;
- [ ] only counterparty can accept/reject;
- [ ] proposer can withdraw;
- [ ] counter-proposals preserve history;
- [ ] CAS uses expected current/pending pointers;
- [ ] stale conflicts use PT409;
- [ ] first milestone freezes terms;
- [ ] structured append-only timeline exists;
- [ ] provider/recipient milestone authorization exact;
- [ ] give/lend completion requirements exact;
- [ ] final milestone auto-completes agreement;
- [ ] completion closes request coordination;
- [ ] cancellation allowed only before handoff;
- [ ] cancellation closes request coordination;
- [ ] listing closure does not cancel accepted agreements;
- [ ] private agreement/terms/timeline reads exist;
- [ ] overdue lending indicators derived without timer event;
- [ ] identifier-only outbox/audit events;
- [ ] no public terms/privacy leakage;
- [ ] no custom 40001;
- [ ] pgTAP/concurrency/real OTP tests added;
- [ ] generated types updated where executable;
- [ ] no mobile/chat/queue/moderation scope creep;
- [ ] no PR merged.

---

# Completion report

Return:

1. **Stack/base status**
2. **04C4B branch/base/PR**
3. **Changed files**
4. **Agreement anchor schema**
5. **Request-accept agreement creation**
6. **Accepted-request backfill**
7. **Request coordination-close model**
8. **Active uniqueness/count changes**
9. **Two-leg model**
10. **Owner give/lend validation**
11. **Requester none/give/lend validation**
12. **Listing snapshot behavior**
13. **Terms version schema**
14. **Terms immutability**
15. **Proposal/CAS behavior**
16. **Counter-proposal behavior**
17. **Terms accept/reject/withdraw**
18. **Terms freeze at handoff**
19. **Agreement event/timeline schema**
20. **Owner-leg milestone authorization**
21. **Requester-leg milestone authorization**
22. **Milestone idempotency**
23. **Automatic completion**
24. **Agreement cancellation**
25. **Repeat-request behavior**
26. **Listing-close behavior**
27. **Agreement/terms/timeline reads**
28. **Overdue derivation**
29. **Events/privacy**
30. **PT409 behavior**
31. **Concurrency tests**
32. **pgTAP**
33. **Real OTP integration**
34. **Generated types/drift**
35. **Local regression validation**
36. **Hosted Validation executed/not-executed**
37. **04C4C handoff**
38. **04C4D handoff**
39. **Future amendment/dispute handoff**
40. **Warnings/blockers**
41. **Commit/PR reference**

Do not merge any PR.
