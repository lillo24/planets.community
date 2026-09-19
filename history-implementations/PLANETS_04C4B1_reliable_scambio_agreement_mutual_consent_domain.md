# PLANETS 04C4B1 — Reliable Scambio Agreement + Mutual Consent Domain

**Roadmap area:** 04C4B — Reliable Scambio Agreement + Fulfillment  
**Task type:** Backend/domain foundation  
**Repository:** `lillo24/planets.community`

## Required stack

Base this plan on the current top of the open implementation stack:

```text
PR #71 — 04C4A Scambio-Dona Resource Request Domain Foundation
branch: codex/04c4a-resource-request-domain
head:   29a242e7cdf2b8319c73565351124ad79cd7a1e9
```

PR #71 is itself stacked on PR #70 and the current open 04C3/05C stack.

Before implementation:

1. fetch current `origin/main`;
2. verify PR #71 still points to the expected head or reconcile any newer stack movement;
3. preserve unrelated current work;
4. branch from the final PR #71 head;
5. do not merge any existing PR.

Preferred branch:

```text
codex/04c4b1-reliable-scambio-agreement
```

Open the new PR with base:

```text
codex/04c4a-resource-request-domain
```

Archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_04C4B1_reliable_scambio_agreement_mutual_consent_domain.md
```

No external document is required by Codex.

Do not merge any PR.

---

# Objective

Build the structured, durable agreement layer for **accepted Scambio requests**.

04C4A established:

```text
listing
→ private interest request
→ owner accepts
```

but intentionally defined:

```text
accepted != reservation
accepted != handoff
accepted != completed exchange
```

04C4B1 answers the next question:

> What exactly did the two people agree to exchange or lend?

The core reliability rule is:

```text
an agreement version becomes agreed
ONLY when both parties have accepted exactly the same immutable version
```

This provides durable factual history without relying only on free-form chat.

---

# 1. Scambio first; Dona remains outside this agreement domain

04C4B1 supports only requests whose listing currently belongs to the Scambio path:

```text
resource_listings.listing_mode = 'exchange'
```

Do not redesign current `donate` / `exchange` listing modes here.

Do not create structured agreement anchors for accepted `donate` requests.

Future listing policy/UI may evolve toward concepts such as:

```text
Dona, or if possible Scambia
Solo Scambio
Presta / lending policy
```

but Scambio reliability is the current priority.

---

# 2. Agreement versus fulfillment

Keep these concepts separate:

```text
REQUEST
"I am interested."

AGREEMENT
"We both agreed to these exact terms."

FULFILLMENT
"The items were actually handed over / returned / completed."
```

04C4B1 implements **agreement only**.

Do not implement actual:

- handoff;
- delivery;
- return;
- completion;
- damage;
- non-return;
- moderation.

Those belong to 04C4B2 and later moderation.

---

# 3. Supported exchange shapes

Each agreement has two independent sides.

## Listing-owner side

The resource from the original listing can be:

```text
give
lend
```

## Requester side

The resource offered in return can independently be:

```text
give
lend
```

Therefore B1 must represent all four combinations:

```text
give ↔ give
give ↔ lend
lend ↔ give
lend ↔ lend
```

Example:

```text
Owner gives cabinet permanently
Requester lends drill from 3 Oct through 12 Oct
```

---

# 4. No money/payment semantics

Do not add:

- money;
- price;
- deposit;
- payment;
- escrow;
- monetary compensation.

This is resource exchange/lending.

Payments remain outside current PLANETS scope.

---

# 5. Canonical agreement anchor

Add a fail-closed table equivalent to:

```text
public.resource_exchange_agreements
```

Conceptual fields:

```text
id uuid primary key
request_id uuid not null unique
status text not null
current_version_id uuid nullable
agreed_version_id uuid nullable
created_at timestamptz not null
agreed_at timestamptz nullable
cancelled_at timestamptz nullable
cancelled_by_profile_id uuid nullable
```

Supported status:

```text
negotiating
agreed
cancelled
```

One agreement per accepted Scambio request episode.

---

# 6. Agreement anchor creation

Evolve the latest canonical:

```text
accept_resource_listing_request(...)
```

through a new forward migration.

For:

```text
listing_mode = exchange
```

the acceptance transaction must atomically:

1. transition request `pending → accepted`;
2. create exactly one agreement anchor with:
   ```text
   status = negotiating
   ```
3. emit existing request-accepted event;
4. optionally emit a narrow identifier-only agreement-created event if useful.

For current accepted Scambio requests created before B1:

```text
backfill one negotiating agreement anchor per accepted request
```

No agreement version exists until someone proposes terms.

Accepted Dona requests receive no B1 agreement.

---

# 7. Agreement request invariant

An agreement is valid only when:

```text
request.status = accepted
listing.listing_mode = exchange
agreement.request_id = request.id
```

Enforce as strongly as practical through restrictive FKs/triggers/private validation.

Do not allow an agreement to attach to:

- pending request;
- rejected request;
- withdrawn request;
- listing_closed request;
- Dona listing.

---

# 8. Immutable agreement versions

Add a table equivalent to:

```text
public.resource_exchange_agreement_versions
```

Conceptual fields:

```text
id uuid primary key
agreement_id uuid not null
version_number integer not null
proposed_by_profile_id uuid not null

listing_title_snapshot text not null
listing_description_snapshot text not null

listing_transfer_kind text not null
listing_loan_start_on date nullable
listing_loan_due_on date nullable

counterpart_title text not null
counterpart_description text nullable
counterpart_transfer_kind text not null
counterpart_loan_start_on date nullable
counterpart_loan_due_on date nullable

notes text nullable

created_at timestamptz not null
```

Unique:

```text
(agreement_id, version_number)
```

Version rows are immutable after insertion.

---

# 9. Why versioning is required

Do not update agreement terms in place.

Example history:

```text
v1 owner proposes:
cabinet give ↔ drill lend 10 days

v2 requester proposes:
cabinet give ↔ drill lend 7 days

v3 owner proposes:
cabinet give ↔ drill lend 8 days

both accept v3
```

PLANETS should retain v1/v2/v3.

Only v3 becomes the agreed version.

This is part of the reliability/trust goal.

---

# 10. Listing-side snapshot

The listing itself is still editable while published.

Agreement history must not be rewritten if the owner later edits the listing.

When a version is proposed, copy server-side from the canonical listing:

```text
listing.title
listing.description
```

into:

```text
listing_title_snapshot
listing_description_snapshot
```

Do not trust the client to supply these snapshots.

Do not snapshot rough location unless a later requirement genuinely needs it.

---

# 11. Requester counterpart terms

For B1, the requester-side offered resource does **not** need to be another Scambio-Dona listing.

Require:

```text
counterpart_title
counterpart_transfer_kind
```

Optional:

```text
counterpart_description
```

This supports quick barter without forcing the requester to publish a second listing.

A future slice may optionally link the offered side to one of the requester's listings.

Do not add that reference now.

---

# 12. Transfer kind

Exactly:

```text
give
lend
```

Do not reuse:

```text
donate
exchange
```

for agreement-side transfer behavior.

Those listing modes are discovery policy.

Agreement transfer kind answers:

```text
does the receiver keep this resource,
or must it be returned?
```

---

# 13. Loan date semantics

When a side is:

```text
lend
```

require:

```text
loan_start_on
loan_due_on
```

with:

```text
loan_due_on >= loan_start_on
```

Interpretation:

```text
loan_start_on
= planned day possession begins

loan_due_on
= planned latest return day
```

Use date-level semantics in B1.

Do not add times/timezones yet.

When transfer kind is:

```text
give
```

both loan date fields must be null.

Apply independently to listing side and counterpart side.

---

# 14. Text bounds

Use bounded plain text.

Suggested limits consistent with existing listing fields:

```text
counterpart_title:
2..120

counterpart_description:
nullable, 1..1000

notes:
nullable, 1..2000
```

Trim surrounding whitespace.

Blank optional values normalize to null.

Do not allow markup/HTML.

---

# 15. Version acceptances

Add a fail-closed immutable table equivalent to:

```text
public.resource_exchange_agreement_version_acceptances
```

Conceptual fields:

```text
version_id uuid
profile_id uuid
accepted_at timestamptz
```

Primary key:

```text
(version_id, profile_id)
```

Only the two parties may ever have acceptance rows:

```text
listing owner
request requester
```

---

# 16. Proposer implicitly accepts their proposal

When either party proposes a new version:

```text
insert immutable version
insert acceptance row for proposer
set agreement.current_version_id = new version
```

The other party must explicitly accept.

Do not require proposer to press Accept on their own proposal again.

---

# 17. Agreement becomes agreed only on mutual same-version consent

After acceptance insertion, if the **current version** has acceptance rows from both:

```text
owner
requester
```

atomically set:

```text
agreement.status = agreed
agreement.agreed_version_id = current_version_id
agreement.agreed_at = canonical server time
```

No other version can count.

Accepting v1 and v2 separately is not agreement.

---

# 18. Proposal RPC

Add a mutation equivalent to:

```text
propose_resource_exchange_agreement_terms(
  p_expected_profile_id uuid,
  p_agreement_id uuid,
  p_expected_current_version_id uuid,

  p_listing_transfer_kind text,
  p_listing_loan_start_on date,
  p_listing_loan_due_on date,

  p_counterpart_title text,
  p_counterpart_description text,
  p_counterpart_transfer_kind text,
  p_counterpart_loan_start_on date,
  p_counterpart_loan_due_on date,

  p_notes text
)
returns uuid
```

For the first proposal:

```text
p_expected_current_version_id = null
```

All non-nullability/default decisions should be explicit and safe.

---

# 19. Proposal CAS

The expected current version is required optimistic concurrency.

After canonical locks:

```text
if agreement.current_version_id
   is distinct from p_expected_current_version_id
→ PT409
```

No stale proposal overwrite.

Do not auto-merge terms.

Do not use custom `40001`.

---

# 20. Who may propose

Only:

```text
listing owner
request requester
```

Both may propose terms.

This allows actual negotiation rather than making only one side edit.

---

# 21. Agreement status allowed for proposals

In B1, new term proposals are allowed only while:

```text
agreement.status = negotiating
```

Once:

```text
agreed
```

the agreed version is frozen.

Do not implement post-agreement amendment yet.

If terms need changing after agreement in the B1-only world, the parties can cancel and later start a new request/agreement episode.

A future amendment model may be added before production if needed.

---

# 22. Accept-version RPC

Add:

```text
accept_resource_exchange_agreement_version(
  p_expected_profile_id uuid,
  p_agreement_id uuid,
  p_version_id uuid
)
returns uuid
```

Requirements:

- caller is owner/requester;
- agreement `negotiating`;
- version belongs to agreement;
- version is exactly `current_version_id`;
- acceptance insertion idempotent for an already-accepted current version;
- after insert/no-op, check mutual consent;
- if both accept, transition agreement to `agreed`.

Attempting to accept an older superseded version:

```text
PT409
```

---

# 23. Proposing a new version supersedes pending consent, not history

If v1 is current and one/both partial acceptances exist, then one party successfully proposes v2:

```text
current_version_id = v2
```

Existing v1 and v1 acceptance rows remain immutable history.

They simply no longer count toward current mutual agreement.

Do not delete them.

---

# 24. Cancel agreement

Add:

```text
cancel_resource_exchange_agreement(
  p_expected_profile_id uuid,
  p_agreement_id uuid
)
returns uuid
```

Either owner/requester may cancel while:

```text
negotiating
or
agreed
```

B1 has no fulfillment state yet, so both are cancellable.

Set:

```text
status = cancelled
cancelled_at
cancelled_by_profile_id
```

Do not delete versions/acceptances.

Do not change the historical request status from `accepted`.

---

# 25. Cancelled agreement and active-interest semantics

Once an accepted Scambio request's agreement is:

```text
cancelled
```

that request is no longer current active interest.

Update the 04C4A active-interest definition for exchange listings:

```text
pending request
OR
accepted request whose agreement is absent or not cancelled
```

After B1 backfill, accepted exchange requests should normally have an agreement.

For Dona listings, preserve existing accepted-request active behavior until Dona policy is designed.

---

# 26. Allow later re-request after cancelled Scambio agreement

04C4A currently has a partial unique index on:

```text
pending + accepted
```

which would permanently block the same requester after a cancelled agreement.

Evolve this safely.

Recommended strategy:

1. replace the cross-lifecycle active unique index with a hard unique guard for:
   ```text
   pending
   ```
2. keep request creation serialized through the listing row;
3. inside canonical request creation, reject if:
   - same requester/listing has pending request;
   - same requester/listing has accepted Dona request;
   - same requester/listing has accepted Scambio request whose agreement is not cancelled;
4. permit a new request after a previous Scambio agreement is cancelled.

Because direct table access remains fail-closed and creation is RPC-only, the listing lock provides canonical cross-table serialization.

Document this evolution clearly.

---

# 27. Request creation / agreement cancellation race

Serialize through listing → request/agreement lock order.

After cancellation commits:

```text
same requester may create a new request episode
```

Before cancellation commits:

```text
new request receives PT409
```

No duplicate active episode.

---

# 28. Listing closure does not cancel agreements

Preserve 04C4A:

```text
closing listing
→ pending requests become listing_closed
→ accepted requests remain accepted
```

B1 extension:

```text
existing negotiating/agreed Scambio agreements remain intact
```

Reason:

An owner may close public discovery after enough accepted contacts while continuing already-agreed exchanges.

Do not cancel agreements merely because discovery closes.

---

# 29. Agreement reads

Add a narrow authorized current read equivalent to:

```text
get_resource_exchange_agreement(
  p_expected_profile_id uuid,
  p_agreement_id uuid
)
```

Authorize only:

```text
listing owner
request requester
```

Return:

```text
agreement_id
request_id
listing_id
status
current_version_id
agreed_version_id
created_at
agreed_at
cancelled_at
cancelled_by_profile_id

current version structured terms if present
owner_has_accepted_current
requester_has_accepted_current
```

Do not expose to unrelated users.

---

# 30. Agreement history read

Add:

```text
list_resource_exchange_agreement_versions(
  p_expected_profile_id uuid,
  p_agreement_id uuid
)
```

Return immutable version chronology with:

```text
version_id
version_number
proposed_by_profile_id

listing title/description snapshot
listing transfer kind + loan dates

counterpart title/description
counterpart transfer kind + loan dates

notes
created_at

owner_accepted_at
requester_accepted_at
is_current
is_agreed
```

Authorized only to the two parties.

This is the durable factual agreement history.

---

# 31. Request reads should expose agreement anchor/status

Evolve the private 04C4A requester/owner/request-by-ID reads to include narrow agreement linkage for Scambio requests:

```text
agreement_id nullable
agreement_status nullable
agreed_version_id nullable
```

Do not expose agreement terms inside general request list rows.

Future Messages/mobile can navigate from request → agreement.

---

# 32. Events

Emit identifier-only audit/outbox events for real changes.

Suggested:

```text
resource_exchange.agreement_created
resource_exchange.terms_proposed
resource_exchange.version_accepted
resource_exchange.agreed
resource_exchange.cancelled
```

Payload only identifiers such as:

```text
agreement_id
request_id
listing_id
version_id
owner_profile_id
requester_profile_id
actor_profile_id
```

Do not include:

- listing title;
- counterpart title;
- descriptions;
- notes;
- loan dates.

---

# 33. No notifications yet

Do not project notifications/push in B1.

Future 04C4C can consume outbox events for:

```text
new terms proposedversion accepted / agreement reached
agreement cancelled
```

using existing notification infrastructure.

---

# 34. No chat yet

Do not create the accepted-request private conversation in B1.

04C4C owns Messages/chat integration.

B1 provides:

- stable request ID;
- stable agreement ID;
- immutable current/history reads;
- identifier-only events.

---

# 35. No handoff/return yet

Do not add states such as:

```text
handed_over
in_progress
returned
completed
damaged
not_returned
```

Those belong to **04C4B2 — Exchange Fulfillment / Handoff + Return Ledger**.

Agreement `agreed` means only:

> both parties accepted the exact structured terms.

---

# 36. Future B2 anchor

04C4B2 should later attach fulfillment to:

```text
agreement.agreed_version_id
```

not merely the listing or request.

This ensures actual fulfillment refers to the exact mutually accepted terms.

Design B1 so this is straightforward.

---

# 37. Future queue compatibility

Loan dates in agreed versions will later feed:

```text
04C4D — Loan Availability / Queue
```

B1 does **not** reject overlapping loans between separate accepted requests.

Queue/calendar conflict rules are not yet designed.

Do not prematurely reserve dates.

---

# 38. Trust/reassurance boundary

Technical docs may state:

```text
PLANETS persists request decisions, immutable agreement versions, and both parties'
acceptance of the agreed version so the agreed terms can be reviewed later.
```

Do not claim:

- legal proof;
- guaranteed reimbursement;
- automatic liability;
- automatic bans for damage.

Moderation/report consequences remain Plan 09/future resource-specific reporting.

---

# 39. RLS / grants

Agreement, version, acceptance tables:

- RLS enabled;
- no direct client policies;
- no direct anon/authenticated/service table grants;
- hardened RPC reads/mutations only;
- fixed/empty search paths;
- private helpers not client-executable.

No public agreement read.

---

# 40. Lock ordering

Use a deterministic order compatible with 04C4A:

```text
resource listing
→ resource request
→ agreement
→ agreement version as needed
```

For proposal/accept/cancel.

Do not reverse request/listing locking introduced by 04C4A.

All agreement mutations for one request should serialize through the listing/request anchor.

---

# 41. PT409 convention

Preserve DB-COMPAT-01.

Use:

```text
PT409
```

for application-level conflicts such as:

- stale expected current version;
- accepting superseded version;
- negotiation already cancelled/agreed when mutation requires negotiating;
- duplicate active re-request before cancellation.

Do not use custom `40001`.

---

# 42. Structural pgTAP

Cover at minimum:

- agreement table;
- version table;
- acceptance table;
- statuses;
- request unique anchor;
- immutable version protection;
- immutable acceptance protection;
- transfer-kind constraints;
- loan date consistency;
- version numbering uniqueness;
- agreement current/agreed version references;
- RLS/no policies/direct grants;
- propose/accept/cancel/read/history signatures.

---

# 43. Behavioral pgTAP — anchor/backfill

Cover:

- accepting pending exchange request creates negotiating agreement atomically;
- accepting donate request does not create agreement;
- existing accepted exchange request backfills one negotiating anchor;
- no duplicate agreement per request;
- non-accepted request cannot gain agreement.

---

# 44. Behavioral pgTAP — exchange combinations

Cover successful version creation for:

```text
give ↔ give
give ↔ lend
lend ↔ give
lend ↔ lend
```

Validate dates independently for both sides.

Reject:

- lend without dates;
- due before start;
- give with loan dates;
- invalid transfer kind;
- blank counterpart title;
- overlong text.

---

# 45. Behavioral pgTAP — mutual consent

Cover:

1. owner proposes v1 → owner acceptance exists;
2. requester has not accepted → agreement negotiating;
3. requester accepts v1 → agreement agreed to v1.

And inverse:

1. requester proposes v1;
2. owner accepts;
3. agreement agreed.

No agreement with only one party acceptance.

---

# 46. Behavioral pgTAP — superseding version

Cover:

```text
owner proposes v1
requester proposes v2 using expected v1
```

Then:

- v1 remains history;
- v1 owner acceptance remains;
- current = v2;
- requester acceptance exists for v2;
- owner must accept v2;
- v1 acceptance cannot make v2 agreed.

---

# 47. CAS tests

Cover stale proposal:

```text
device A loads v1
device B loads v1

A proposes v2
B proposes v3 expected=v1
→ B PT409
```

No v3 inserted.

No event side effects.

---

# 48. Accept-current race

If one user tries to accept v1 while the other simultaneously proposes v2:

Valid serialization:

```text
accept first:
  v1 may become agreed
  proposal-v2 then rejected because agreement is agreed

proposal first:
  current becomes v2
  accept-v1 PT409
```

Never agree a superseded version.

---

# 49. Cancellation tests

Cover:

- either party cancels negotiating agreement;
- either party cancels agreed agreement in B1;
- cancellation preserves all versions/acceptances;
- later term proposal/accept rejected;
- public active count drops for cancelled Scambio agreement;
- same requester may create a new request episode afterward.

---

# 50. Listing-close regression

Cover:

- closing listing does not cancel negotiating agreement;
- does not cancel agreed agreement;
- accepted request remains accepted;
- pending unrelated requests still become listing_closed as in A.

---

# 51. Active interest/count regression

For exchange:

Count:

```text
pending
accepted + negotiating agreement
accepted + agreed agreement
```

Do not count:

```text
accepted + cancelled agreement
```

For current Dona:

preserve existing 04C4A pending+accepted behavior.

Test requester re-request after cancelled exchange agreement.

---

# 52. Real OTP integration

Add a focused verifier covering:

1. owner publishes exchange listing;
2. requester sends request;
3. owner accepts → agreement anchor exists;
4. owner proposes give↔lend terms;
5. requester reads exact version/snapshots;
6. requester proposes revised version;
7. old version remains history;
8. owner accepts revised version;
9. agreement becomes agreed;
10. unrelated user cannot read;
11. listing edit after proposal does not mutate version snapshot;
12. cancel agreed agreement;
13. public active-interest count updates;
14. requester creates a new request episode after cancellation;
15. stale-version PT409 race;
16. accept-current vs new-proposal race;
17. identifier-only events contain no term data;
18. accepted Dona request creates no B1 agreement.

Never log:

- OTPs;
- tokens;
- term descriptions;
- notes;
- emails.

---

# 53. Generated types

Update/regenerate public types for:

- agreement relations if generated;
- propose/accept/cancel RPCs;
- agreement/history reads;
- evolved private request read return shapes;
- evolved public active count only if signatures changed.

If DB unavailable:

- carefully derive compile-required deltas;
- mark unverified;
- retain `db:types:check` as hard pre-merge gate.

---

# 54. Documentation / roadmap split

Refine:

```text
04C4B — Reliable Scambio Agreement + Fulfillment (parent)

04C4B1 — Reliable Scambio Agreement + Mutual Consent Domain
  this plan
  immutable versions
  give/lend on both sides
  loan date terms
  same-version bilateral consent
  cancellation/history

04C4B2 — Exchange Fulfillment / Handoff + Return Ledger
  not started
  actual handoff
  possession/start
  return
  permanent transfer completion
  cancellation after fulfillment begins
  completion
  factual incident hooks without implementing moderation
```

04C4C remains the later mobile/Messages experience.

---

# 55. B2 handoff

B2 should consume:

```text
agreement.status = agreed
agreement.agreed_version_id
```

and create fulfillment history against that exact version.

Do not make B2 reinterpret negotiation history.

---

# 56. Validation policy

Run available non-DB checks:

```text
npm run check:web
npm run check:site
npm run check:mobile
node --check <new verifier>
git diff --check
```

Run SQL parse checks without Docker where available.

Attempt hosted Validation once.

If runner startup remains unavailable due billing/spending limits:

```text
not executed due external infrastructure
```

Do not rerun pointlessly.

Because B1 is schema-heavy, do not merge until:

- clean migration replay;
- DB lint/advisors;
- pgTAP;
- real OTP/integration;
- generated-type drift

execute green.

---

# Non-goals

Do not implement:

- Dona policy redesign;
- listing UI changes;
- mobile negotiation UI;
- Messages/private conversation;
- notifications;
- actual handoff;
- return/completion;
- loan queue/date reservation;
- damage/non-return reporting;
- moderation;
- money/payment;
- deposits;
- counterpart-listing linkage;
- global taxonomy;
- Project matching;
- saved searches.

---

# Acceptance criteria

Ready for review when:

- [ ] stack current and B1 based on PR #71;
- [ ] exact prompt archived;
- [ ] accepted exchange request atomically owns one agreement anchor;
- [ ] accepted Dona request does not create B1 agreement;
- [ ] existing accepted exchange requests backfilled;
- [ ] agreement statuses negotiating/agreed/cancelled;
- [ ] immutable version history exists;
- [ ] listing title/description snapshot server-owned;
- [ ] both sides independently support give/lend;
- [ ] lending requires valid start/due dates;
- [ ] counterpart title/description stored privately;
- [ ] proposer implicitly accepts their version;
- [ ] both parties must accept same current version;
- [ ] stale proposals use PT409;
- [ ] superseded versions cannot be agreed;
- [ ] agreement terms freeze once agreed in B1;
- [ ] either party can cancel B1 agreement;
- [ ] cancelled exchange agreement stops counting active interest;
- [ ] requester can re-request after cancellation;
- [ ] listing closure does not cancel accepted agreements;
- [ ] current/history authorized reads exist;
- [ ] request reads expose narrow agreement linkage;
- [ ] events are identifier-only;
- [ ] no public term leakage;
- [ ] RLS/grants fail closed;
- [ ] concurrency/pgTAP/real OTP coverage added;
- [ ] roadmap split B1/B2;
- [ ] no fulfillment/mobile/chat/matching work added;
- [ ] no PR merged.

---

# Completion report

Return:

1. **Stack/base status**
2. **04C4B1 branch/base/PR**
3. **Changed files**
4. **Agreement-anchor schema**
5. **Agreement statuses**
6. **Acceptance/backfill integration**
7. **Version schema**
8. **Listing snapshot behavior**
9. **Counterpart-term schema**
10. **Give/lend semantics**
11. **Loan-date validation**
12. **Acceptance schema**
13. **Proposer implicit acceptance**
14. **Mutual same-version consent**
15. **Proposal CAS/PT409**
16. **Superseding-version behavior**
17. **Agreement cancellation**
18. **Re-request after cancellation**
19. **Active-interest-count evolution**
20. **Listing-close regression**
21. **Agreement current read**
22. **Agreement history read**
23. **Request-read agreement linkage**
24. **Events/privacy**
25. **Lock ordering**
26. **Proposal-vs-proposal concurrency**
27. **Accept-vs-proposal concurrency**
28. **Cancellation concurrency**
29. **RLS/grants**
30. **pgTAP**
31. **Real OTP integration**
32. **Generated types/drift**
33. **Local regression validation**
34. **Hosted Validation executed/not-executed**
35. **04C4B2 handoff**
36. **04C4C handoff**
37. **Warnings/blockers**
38. **Commit/PR reference**

Do not merge any PR.