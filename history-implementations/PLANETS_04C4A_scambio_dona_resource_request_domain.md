# PLANETS 04C4A — Scambio-Dona Resource Request Domain Foundation

**Roadmap area:** 04C4 — Scambio-Dona Requests, Agreements and Matching  
**Task type:** Backend/domain foundation  
**Repository:** `lillo24/planets.community`

## Required stack

Base this plan on the current top of the open implementation stack:

```text
PR #70 — DB-COMPAT-01 PostgREST-Safe Application Conflict SQLSTATEs
branch: codex/db-compat-postgrest-conflict-sqlstate
head:   88d0df0a95f67401e8c7502058fad6ce46059d0c
```

Relevant already-merged Scambio-Dona foundations:

```text
PR #32 — 04C1 Scambio-Dona Listing Domain Foundation
merge: 2aca5bdde7bf7ed7d747f14dcccbc3b5c4b75c42

PR #34 — 04C2 Scambio-Dona Mobile Discovery + Owner Experience
merge: 2da76de112a860210161d64de6bceab333159c26
```

The current open 04C3/05C stack underneath PR #70 remains intentionally unmerged.

Before implementation:

1. fetch current `origin/main`;
2. verify PR #70 still points to the expected head or reconcile any newer stacked head;
3. preserve all unrelated current work;
4. branch from the final PR #70 head;
5. do not merge any existing PR.

Preferred branch:

```text
codex/04c4a-resource-request-domain
```

Open the new PR with base:

```text
codex/db-compat-postgrest-conflict-sqlstate
```

Archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_04C4A_scambio_dona_resource_request_domain.md
```

No external document is required by Codex.

---

# Product context

04C1 intentionally implemented only discovery listings.

Current listing mode:

```text
donate
exchange
```

is still a **discovery-intent field**.

04C4 will progressively make Scambio reliable.

Accepted product direction now includes:

- Scambio is primarily barter/exchange;
- later it must also support temporary lending and mixed agreements such as:
  `I give you X, you lend me Y for 10 days`;
- tools used occasionally are a particularly important future loan use case;
- multiple people may ask for the same listing;
- an accepted request does **not** mean the item has already been handed over;
- accepted requests should later become resource-specific private conversations in Messages;
- structured agreement/handoff/return history will later provide factual records for trust/moderation;
- Project resource needs and personal saved searches will later feed matching.

However, **04C4A does not implement those agreement semantics yet**.

It establishes only the canonical request/interest layer that later Scambio/loan/handoff work can build on.

---

# 1. Dona scope stays secondary for now

Do not redesign the current `resource_listings.listing_mode` in 04C4A.

Keep:

```text
donate
exchange
```

unchanged for compatibility with merged 04C1/04C2.

Future product direction may evolve this toward policies such as:

```text
"Dona, or if possible Scambia"
"Solo Scambio"
```

and may make `lend` / `Presta` first-class in the agreement/listing domain.

That is **not** 04C4A.

The priority now is a reliable request lifecycle.

Requests may technically operate on both current published listing modes so the backend does not create a dead-end for existing Dona listings, but do not add new Dona-specific UX or assumptions.

---

# 2. Canonical request table

Add a private/fail-closed canonical table equivalent to:

```text
public.resource_listing_requests
```

Conceptual fields:

```text
id uuid primary key
listing_id uuid not null
requester_profile_id uuid not null
status text not null
request_message text nullable
created_at timestamptz not null
resolved_at timestamptz nullable
resolved_by_profile_id uuid nullable
```

Optional additional timestamp fields are acceptable only if current repository conventions clearly justify them.

Use restrictive foreign keys.

---

# 3. Request statuses

Exactly support this initial lifecycle:

```text
pending
accepted
rejected
withdrawn
listing_closed
```

Meaning:

## `pending`

Requester has expressed interest.

Owner has not resolved it.

## `accepted`

Owner is willing to continue coordination.

Important:

```text
accepted != reserved
accepted != handed over
accepted != exchange completed
accepted != loan started
accepted != item unavailable
```

Multiple accepted requests for the same listing are allowed.

## `rejected`

Owner rejected this request.

## `withdrawn`

Requester withdrew while pending.

## `listing_closed`

The listing was closed while this request was still pending.

This prevents dangling pending requests.

---

# 4. Accepted is intentionally not terminal business completion

`accepted` is terminal only for the **04C4A request decision**.

Later 04C4B+ will attach a separate agreement/handoff lifecycle.

Do not mutate `accepted` into:

```text
completed
returned
cancelled
reserved
```

inside 04C4A.

Do not close the listing automatically when one request is accepted.

---

# 5. Multiple people may request one listing

Allow:

```text
Listing A
├─ requester 1 pending
├─ requester 2 accepted
├─ requester 3 pending
└─ requester 4 accepted
```

This is required because:

- acceptance is only willingness to coordinate;
- future exchange negotiations may fail;
- future loan scheduling may support sequential borrowers.

Do not impose one accepted requester per listing.

---

# 6. Active request uniqueness per requester/listing

For one requester and listing, permit at most one **active** request:

```text
pending
or
accepted
```

at a time.

Historical terminal attempts:

```text
rejected
withdrawn
listing_closed
```

may coexist.

This keeps request history episode-based and leaves room for future repeated loan requests.

Prefer a partial unique index or equivalent hard database invariant.

Do not rely only on RPC checks.

---

# 7. Request message

Allow one optional private initial message.

Reuse the existing participation request message bound where practical:

```text
max 500 characters
```

Normalize:

- trim surrounding whitespace;
- blank → null;
- bounded plain text.

The message is visible only to:

```text
requester
listing owner
```

Never include it in public listing reads, public request counts, audit metadata, outbox payloads, or logs.

---

# 8. Request creation

Add an authenticated RPC equivalent to:

```text
request_resource_listing(
  p_expected_requester_profile_id uuid,
  p_listing_id uuid,
  p_message text default null
)
returns uuid
```

Requirements:

- expected identity bound to `auth.uid()`;
- requester has a complete profile if current Scambio-Dona conventions require display identity;
- listing exists;
- listing is `published`;
- requester is not the listing owner;
- no active request from same requester/listing;
- message valid.

Lock the listing before evaluating its current published state.

---

# 9. Request creation does not propose structured barter terms yet

04C4A request means:

```text
"I am interested in this resource."
```

The optional message may contain informal context.

Do not add fields yet for:

- counterpart listing;
- what requester offers;
- give vs lend;
- requested loan dates;
- duration;
- quantity;
- money;
- reservation;
- handoff place;
- return terms.

Those belong to the Scambio Agreement slice.

---

# 10. Requester withdrawal

Add:

```text
withdraw_resource_listing_request(
  p_expected_requester_profile_id uuid,
  p_request_id uuid
)
```

Only the requester may withdraw.

Only:

```text
pending
```

may become:

```text
withdrawn
```

Accepted-request cancellation will belong to the later agreement/coordination layer.

Do not guess that behavior here.

---

# 11. Owner accept

Add:

```text
accept_resource_listing_request(
  p_expected_owner_profile_id uuid,
  p_request_id uuid
)
```

Only canonical listing owner.

Only:

```text
pending → accepted
```

Acceptance:

- does not modify listing lifecycle;
- does not reject other pending requests;
- does not reserve item;
- does not reveal phone/email;
- does not create a generic DM;
- does not assert a completed handoff.

---

# 12. Owner reject

Add:

```text
reject_resource_listing_request(
  p_expected_owner_profile_id uuid,
  p_request_id uuid
)
```

Only:

```text
pending → rejected
```

No free-form rejection reason in 04C4A.

---

# 13. Listing closure integration

Evolve the latest canonical:

```text
close_resource_listing(...)
```

through a **new forward migration**, not by rewriting merged 04C1 history.

When owner closes a published listing:

1. lock listing canonically;
2. transition listing to `closed`;
3. atomically transition every still-`pending` request to:
   ```text
   listing_closed
   ```
4. preserve:
   ```text
   accepted
   rejected
   withdrawn
   ```
   histories unchanged.

The listing-close transaction must remain atomic.

Do not create or destroy accepted future agreements.

---

# 14. Request decision serialization

Preserve deterministic races.

## Owner accept vs requester withdraw

Both target the same pending request.

Exactly one terminal decision wins:

```text
accepted
or
withdrawn
```

The loser gets a stable lifecycle conflict.

## Owner reject vs requester withdraw

Exactly one wins.

## Request creation vs listing close

Valid serialization:

```text
request locks published listing first
→ request commits
→ close later marks it listing_closed

or

close wins first
→ new request rejects because listing is closed
```

No dangling pending request.

---

# 15. Stable domain conflict

Use the compatibility convention established by DB-COMPAT-01.

Application-level request races/conflicts should use:

```text
PT409
```

where HTTP Conflict semantics are appropriate.

Do **not** introduce custom `40001`.

Reserve `40001` for genuine PostgreSQL serialization failures.

Lifecycle-invalid non-race states may continue using repository-standard `55000`/`22023` where appropriate.

---

# 16. Public active-interest count

The product should later be able to show:

```text
"4 people interested"
```

without exposing who they are.

Define current **active interest** as requests with status:

```text
pending
accepted
```

Expose only a derived integer count.

No requester IDs/names/messages publicly.

---

# 17. Extend public listing reads safely

Evolve the current sanitized public Scambio-Dona list/detail contract so published rows include:

```text
active_request_count
```

Count:

```text
pending + accepted
```

for that listing.

This count does not mean:

- reservations;
- queue position;
- item assigned;
- successful handoff.

Document it as active interest/request count.

Existing mobile code may ignore the added field until 04C4 mobile work.

Do not expose counts for non-public closed/draft listings through public APIs.

---

# 18. Owner private request read

Add an owner-only read equivalent to:

```text
list_resource_listing_requests(
  p_expected_owner_profile_id uuid,
  p_listing_id uuid
)
```

Return:

```text
request_id
requester_profile_id
requester_display_name
status
request_message
created_at
resolved_at
resolved_by_profile_id
```

Order newest first with deterministic ID tie-break.

Owner can read history even after listing closes.

---

# 19. Requester private history read

Add:

```text
list_own_resource_listing_requests(
  p_expected_requester_profile_id uuid
)
```

Return enough structured context for future Messages/mobile rendering:

```text
request_id
listing_id
listing_mode
listing_title
listing_lifecycle
owner_profile_id
owner_display_name when existing visibility rules permit private counterpart display
status
request_message
created_at
resolved_at
```

For private owner/requester coordination, it is acceptable to return the counterpart's display name even if public profile visibility is restricted, if that matches existing private participation patterns.

Do not expose unrelated profile fields.

Order newest first.

---

# 20. Narrow request-by-ID read

Add a focused authorized read if useful for future structured Messages:

```text
get_resource_listing_request(
  p_expected_profile_id uuid,
  p_request_id uuid
)
```

Authorize only:

```text
requester
or
listing owner
```

Return one canonical request/detail row.

This is recommended because 04C4C will need request-specific navigation and later private conversation activation.

Keep it narrow.

---

# 21. Identifier-only events

Emit identifier-only audit/outbox events for real transitions:

```text
resource_listing.request_created
resource_listing.request_accepted
resource_listing.request_rejected
resource_listing.request_withdrawn
resource_listing.request_closed
```

Payload conceptually:

```text
request_id
listing_id
owner_profile_id
requester_profile_id
actor_profile_id
```

Do not include:

- listing title;
- request message;
- display names;
- rough location;
- future agreement terms.

For `request_closed`, actor may be listing owner because it occurs inside owner listing closure.

---

# 22. No notification projection yet

Do not implement notification rows/push in 04C4A.

The identifier-only outbox events are the stable future source.

Later 04C4C may project:

```text
new request → owner alert
accepted/rejected/listing-closed → requester alert
```

using the existing notification backbone.

---

# 23. No Messages item yet

Do not add Flutter or Messages structured rendering in 04C4A.

Later 04C4C will own:

- Request button;
- owner request inbox/actions;
- requester status;
- active request count UI;
- structured Messages item;
- accepted request-specific conversation.

04C4A must provide sufficient canonical reads/events so 04C4C does not require direct table access.

---

# 24. No private conversation yet

Accepted resource requests should later activate a private owner↔requester conversation tied to:

```text
request_id
listing_id
```

but do not implement it here.

Do not reuse Project group-chat membership concepts for a two-person resource request without a focused design.

---

# 25. Future trust/agreement history compatibility

The request row is the immutable anchor for later reliable Scambio history.

Future 04C4B should be able to attach:

```text
agreement
counterpart offer
give/lend terms
period/duration
handoff
return/completion
conversation
```

to the accepted request without rewriting request history.

Do not store agreement terms directly on the request row now.

---

# 26. Future loan queue compatibility

Do not implement queue positions or date reservations.

But avoid schema assumptions that force:

```text
one accepted request per listing
```

Future loan scheduling may have:

```text
accepted request A → 3–6 Oct
accepted request B → 8–10 Oct
```

The request foundation must permit this.

---

# 27. Dona policy compatibility

Do not migrate current `listing_mode`.

Future listing-policy work may replace/refine it into concepts such as:

```text
exchange_only
donation_allowed
lend_allowed
```

or another better model.

04C4A requests should reference only:

```text
listing_id
```

and therefore remain valid if listing policy evolves.

Do not copy `listing_mode` into the request table as canonical agreement truth.

Reads may return the listing's current mode for display.

---

# 28. RLS / grants

Request table:

- RLS enabled;
- no direct client policies;
- no direct anon/authenticated/service table grants;
- hardened RPC access only;
- fixed/empty search paths;
- private helpers not executable by client roles.

Anonymous users:

```text
may see public active_request_count
may not enumerate request rows
```

---

# 29. Structural pgTAP

Cover at minimum:

- request table exists;
- status constraint exactly includes the five statuses;
- listing/requester FKs;
- resolution actor FK;
- timestamp constraints;
- active partial uniqueness;
- private message length/trim invariant where enforced;
- RLS;
- no direct policies/table grants;
- request/create/withdraw/accept/reject RPC signatures;
- owner/requester read signatures;
- public listing/detail output includes active count;
- latest close-listing function remains hardened.

---

# 30. Behavioral pgTAP — request creation

Cover:

- published exchange listing request succeeds;
- published donate listing request succeeds;
- owner cannot request own listing;
- anonymous denied;
- incomplete profile behavior follows chosen identity helper;
- draft denied;
- closed denied;
- optional message normalized;
- >500 message rejected;
- duplicate active request rejected with stable conflict;
- historical terminal attempt permits later new active attempt.

---

# 31. Behavioral pgTAP — transitions

Cover:

```text
pending → accepted
pending → rejected
pending → withdrawn
pending → listing_closed
```

Reject invalid transitions:

```text
accepted → withdraw
accepted → reject
rejected → accept
withdrawn → accept
listing_closed → accept
```

No mutation side effects on invalid transition.

---

# 32. Behavioral pgTAP — multiple requesters

Cover:

- multiple users request same listing;
- owner accepts more than one;
- public active count reflects pending+accepted;
- rejected/withdrawn/listing_closed no longer count active;
- request identities/messages remain private.

---

# 33. Behavioral pgTAP — listing close

Cover:

- close with zero requests;
- close with pending requests → all become listing_closed;
- accepted request remains accepted;
- rejected/withdrawn unchanged;
- public listing disappears as before;
- owner/requester history remains readable;
- request-close events are identifier-only.

---

# 34. Concurrency tests

Add deterministic tests for:

## Accept vs withdraw

One winner.

No double resolution.

## Reject vs withdraw

One winner.

## New request vs listing close

No committed pending request survives a close serialization.

## Two simultaneous duplicate requests by same requester/listing

Exactly one active request.

Use database constraints plus canonical locking.

---

# 35. Real OTP integration

Add a focused verifier covering at least:

1. owner publishes listing;
2. four different authenticated users request it;
3. public count becomes 4;
4. owner reads request history;
5. requester sees own history;
6. owner accepts two requests;
7. rejects one;
8. fourth withdraws;
9. active count reflects accepted requests only;
10. requester cannot read another request;
11. anonymous cannot enumerate private request rows;
12. listing close preserves accepted history;
13. pending close transition if a fresh fifth requester is added before closure;
14. accept-vs-withdraw race;
15. duplicate active request race;
16. events contain identifiers only and never request text.

Do not log:

- OTPs;
- tokens;
- request messages;
- private emails;
- protected profile data.

Wire into `check:db` / Database CI according to repository conventions.

---

# 36. Generated types

Regenerate/update public types for:

- request table if included in generated schema;
- request mutation/read RPCs;
- public list/detail active-count fields.

If Docker remains unavailable:

- derive only compile-required changes carefully;
- document them as unverified;
- retain `db:types:check` as a hard pre-merge gate.

---

# 37. Documentation / roadmap split

Refine 04C4 into:

```text
04C4 — Scambio-Dona Requests, Agreements and Matching (parent)

04C4A — Resource Request Domain Foundation
  this plan
  interest request lifecycle
  multiple requests/acceptances
  active-interest count
  private request history

04C4B — Reliable Scambio Agreement + Loan/Barter Domain
  structured counterpart offer
  give vs lend
  mixed barter/loan
  period/duration
  persisted agreement terms
  handoff/completion/return history

04C4C — Mobile Requests + Messages
  Request UI
  owner Accept/Reject
  requester Withdraw/status
  “N interested”
  structured Messages request
  accepted request-specific private conversation

04C4D — Loan Availability / Queue
  sequential loan periods
  conflicts
  queue/calendar behavior
  popular/occasional-use tool UX

04C4E — Project Resource Matching
  Project resource needs ↔ Scambio-Dona listings
  initial text/location/availability explainable matching

04C4F — Saved Searches + Matching Notifications
  eBay-style personal saved searches
  current filters first
  future taxonomy/radius/category refinements
```

Future, not a blocker:

```text
global resource taxonomy/tags
Dona UI/policy refinement
social "what we did together" profile history
```

---

# 38. Technical compatibility convention

Preserve DB-COMPAT-01:

```text
PT409 = explicit application conflict
40001 = genuine PostgreSQL serialization failure
```

Do not reintroduce custom `40001` domain conflicts.

---

# 39. Validation policy

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

If GitHub runner startup is unavailable due the known billing/spending-limit issue:

```text
not executed due external infrastructure
```

Do not rerun pointlessly.

Because 04C4A is schema-heavy, do not merge until:

- clean migration replay;
- DB lint/advisors;
- pgTAP;
- real OTP/integration;
- generated-type drift

execute green.

---

# Non-goals

Do not implement:

- listing-mode redesign;
- `Presta`/lend listing UI;
- structured barter counterpart offer;
- loan dates/duration;
- reservation;
- handoff;
- return tracking;
- agreement completion;
- damage/non-return reports;
- moderation/suspension;
- contact disclosure;
- private resource-request chat;
- Messages UI;
- request notifications;
- Project matching;
- saved searches;
- resource taxonomy;
- media;
- payments.

---

# Acceptance criteria

Ready for review when:

- [ ] stack current and 04C4A based on PR #70;
- [ ] exact prompt archived;
- [ ] current listing modes remain unchanged;
- [ ] canonical resource request table exists;
- [ ] statuses are pending/accepted/rejected/withdrawn/listing_closed;
- [ ] accepted does not close/reserve listing;
- [ ] multiple accepted requests per listing are allowed;
- [ ] only one active request per requester/listing;
- [ ] historical terminal attempts remain possible;
- [ ] optional private request message is bounded;
- [ ] requester can create/withdraw pending request;
- [ ] owner can accept/reject pending request;
- [ ] listing closure atomically closes pending requests;
- [ ] accepted requests survive listing closure as history;
- [ ] public active_request_count derives from pending+accepted only;
- [ ] no public requester identity/message leakage;
- [ ] owner/requester private history reads exist;
- [ ] request-specific authorized read exists or an equivalent narrow contract supports 04C4C;
- [ ] identifier-only events exist;
- [ ] PT409 used for explicit races/conflicts where appropriate;
- [ ] RLS/grants fail closed;
- [ ] pgTAP/concurrency/real OTP tests added;
- [ ] generated types updated where executable;
- [ ] roadmap split through 04C4F;
- [ ] no agreement/loan/chat/matching UI added;
- [ ] no PR merged.

---

# Completion report

Return:

1. **Stack/base status**
2. **04C4A branch/base/PR**
3. **Changed files**
4. **Request schema**
5. **Request statuses**
6. **Active-request uniqueness**
7. **Request message handling**
8. **Request creation**
9. **Requester withdrawal**
10. **Owner accept**
11. **Owner reject**
12. **Multiple accepted requests**
13. **Listing-close integration**
14. **Public active-interest count**
15. **Owner request read**
16. **Requester history read**
17. **Request-by-ID read**
18. **Events/privacy**
19. **PT409 conflict behavior**
20. **Accept-vs-withdraw concurrency**
21. **Reject-vs-withdraw concurrency**
22. **Request-vs-close concurrency**
23. **Duplicate-request concurrency**
24. **RLS/grants**
25. **pgTAP**
26. **Real OTP integration**
27. **Generated types/drift**
28. **Local regression validation**
29. **Hosted Validation executed/not-executed**
30. **04C4B handoff**
31. **04C4C handoff**
32. **04C4D/E/F handoff**
33. **Dona policy future handoff**
34. **Warnings/blockers**
35. **Commit/PR reference**

Do not merge any PR.
