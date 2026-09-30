# PLANETS 04C4E1 — Explainable Project Resource Matching Domain

**Roadmap area:** 04C4E — Project Resource Matching  
**Task type:** Backend/domain matching foundation  
**Repository:** `lillo24/planets.community`

## Required stack

Base this plan on:

```text
PR #84 — 04C4D2 Mobile Loan Schedule + Availability UX
branch: codex/04c4d2-mobile-loan-schedule
head:   07cee1a0aa344c4224ad30e0ec58c8c8ff31577e
```

PR #84 is stacked on draft PR #83. PR #83 still has unexecuted database reset/lint/advisors/pgTAP/type-drift/OTP gates. Do not merge any dependency.

Before implementation:

1. fetch current `origin/main`;
2. verify PR #84 still points to the expected head or reconcile any newer stacked head;
3. preserve unrelated work;
4. branch from the final PR #84 head;
5. do not merge any PR.

Preferred branch:

```text
codex/04c4e1-project-resource-matching-domain
```

Open the new PR with base:

```text
codex/04c4d2-mobile-loan-schedule
```

Archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_04C4E1_explainable_project_resource_matching_domain.md
```

No external document is required by Codex.

---

# Product direction now fixed

The first Project↔Scambio-Dona matcher must be deterministic, explainable, text/keyword based, coarse-geography aware, and mode-filterable.

It must **not** use:

```text
opaque AI score
embedding/vector similarity
global resource taxonomy
private loan schedule dates
another user's reservation details
```

Saved searches remain separate 04C4F work.

---

# Objective

Match one canonical open `project_resource_need` against published Scambio-Dona listings.

Example:

```text
Project need:
"Trapano a percussione"

Published listings:
"Trapano Bosch"                  → lexical match
"Trapano a percussione 18V"      → stronger phrase/title match
"Scala in alluminio"             → no match
```

The API must explain why each candidate matched through discrete reasons rather than a hidden numeric confidence score.

---

# 1. Split 04C4E

Refine the roadmap:

```text
04C4E — Project Resource Matching (parent)

04C4E1 — Explainable Project Resource Matching Domain
  this plan

04C4E2 — Mobile Project Resource Matching UX
  later
```

04C4F remains Saved Searches + Matching Notifications.

Do not implement mobile UI or notifications in E1.

---

# 2. Creator-facing first version

The first matching RPC is authenticated and available to the canonical Project creator.

The creator owns/manages the Project resource need and decides whether/how to acquire a matched listing.

Do not create a public matching endpoint in E1.

A later participant-facing surface may reuse the engine.

---

# 3. Source need eligibility

The source must be a canonical `public.project_resource_needs` row owned by the creator's Project.

Require:

```text
need.state = open
```

Closed needs do not match.

---

# 4. Project lifecycle eligibility

Matching may be useful while planning before publication.

Allow:

## One-time Proposal

```text
draft
published while statement_timestamp() < ends_at
```

Reject cancelled or time-completed Proposal state.

## Tavolo / recurring activity

Allow:

```text
draft
published
paused
```

Reject ended.

Do not silently match terminal historical Projects.

---

# 5. Candidate listing eligibility

Only:

```text
resource_listings.lifecycle_state = published
```

may be returned.

Exclude draft and closed listings.

---

# 6. No persisted match rows

Do not create match tables, match-score rows, or notification rows.

Matching is derived at read time from:

```text
open need text
Project rough location
published listing text/location/mode
```

---

# 7. Text matching principle

Use PostgreSQL full-text/lexical matching with an explicit language configuration appropriate to the current Italian-first product, preferably built-in `italian`.

Do not introduce pg_trgm thresholds, vectors, embeddings, or external AI/search APIs.

Unknown/model-name terms should still behave as ordinary lexemes where PostgreSQL supports them.

---

# 8. Text match tiers

Return exactly one strongest `text_match_kind`:

```text
title_phrase
need_title_in_listing_title
need_title_in_listing_description
need_details_in_listing_title
need_details_in_listing_description
```

Order strongest → weakest as listed.

A listing qualifies only if at least one tier matches.

No numeric similarity score.

---

# 9. Title phrase

Strongest tier when normalized need title appears as a contiguous case-insensitive phrase in listing title.

Normalize surrounding/repeated whitespace consistently.

Do not require full-title equality.

---

# 10. Need-title keyword matching

Build a safe OR-style text-search query from meaningful lexemes of `need.title` using PostgreSQL tokenization/stemming, not raw user text inserted into tsquery syntax.

Then:

```text
listing title matches
→ need_title_in_listing_title

else listing description matches
→ need_title_in_listing_description
```

One meaningful normalized need-title lexeme is sufficient.

Do not expose stemmed lexemes as user-facing copy.

---

# 11. Need-details fallback

If no stronger title tier matched, evaluate optional `need.details` against listing title then listing description using the same safe process.

Return:

```text
need_details_in_listing_title
need_details_in_listing_description
```

---

# 12. Empty/stopword-only query handling

If PostgreSQL normalization produces no meaningful searchable lexemes for a source field, that field contributes no keyword tier.

If neither title nor details can produce any text match and no title phrase matches:

```text
no candidate
```

Do not fall back to geography-only matching.

---

# 13. No opaque score

Do not return percentages, confidence, semantic score, or AI ranking.

Eligibility and ordering use the explicit discrete tiers only.

---

# 14. Location source

Use existing rough Project location fields according to project kind:

```text
country_code
locality
administrative_area
```

Do not use exact meeting location or protected meeting details.

---

# 15. Location match kinds

Return strongest applicable:

```text
same_locality
same_administrative_area
same_country
other_or_unknown
```

Comparisons are case-insensitive/trimmed; country codes compare canonically.

---

# 16. Explicit geography filter

RPC must take explicit scope:

```text
same_locality
same_administrative_area
same_country
anywhere
```

Do not infer scope silently.

Rules:

- `same_locality`: Project/listing locality must match.
- `same_administrative_area`: same country + same administrative area.
- `same_country`: same country.
- `anywhere`: no hard geography exclusion.

Still return `location_match_kind`.

---

# 17. Missing Project location

If selected scope requires missing Project geography, fail with a stable state/input error.

Do not silently broaden the search.

`anywhere` remains usable.

---

# 18. Listing mode filter

RPC accepts optional listing mode:

```text
null        → Dona + Scambia
donate
exchange
```

Do not infer mode from need text.

Do not add a `lend` listing mode.

---

# 19. Availability semantics

Do **not** inspect or expose private D1 loan reservations in Project match results.

Reasons:

- Project need has no canonical requested LEND period;
- listing does not declare Give-vs-Lend at discovery time;
- private periods belong to accepted agreements;
- exact availability is checked later when concrete LEND terms exist.

For E1:

```text
published listing
= discoverable matching candidate
```

not guaranteed loan availability.

---

# 20. Do not infer Proposal dates as loan dates

Proposal start/end does not define when a resource is needed.

Do not automatically compare Proposal event dates against loan reservations.

---

# 21. D1 reservation non-influence

Two otherwise-identical published listings have equal matching eligibility/rank even if one has an active private LEND reservation.

E1 must not leak or encode reserved/free/at-risk/overdue status.

---

# 22. Match ordering

Order deterministically by:

1. text-match strength;
2. location-match strength;
3. `published_at DESC`;
4. `listing_id DESC`.

Text order is the five tiers above.

Location order:

```text
same_locality
same_administrative_area
same_country
other_or_unknown
```

No score returned.

---

# 23. Pagination

Use complete keyset pagination.

Suggested cursor:

```text
p_cursor_text_match_kind
p_cursor_location_match_kind
p_cursor_published_at
p_cursor_listing_id
```

Require all cursor values null or all supplied.

Map enum strings to deterministic internal ranks.

Limit 1..50.

No offset pagination.

---

# 24. Matching RPC

Add creator-only RPC equivalent to:

```text
list_project_resource_need_listing_matches(
  p_expected_creator_profile_id uuid,
  p_resource_need_id uuid,
  p_listing_mode text default null,
  p_location_scope text,
  p_limit integer,
  p_cursor_text_match_kind text default null,
  p_cursor_location_match_kind text default null,
  p_cursor_published_at timestamptz default null,
  p_cursor_listing_id uuid default null
)
```

Exact signature may adapt to repository conventions.

Return public-safe fields:

```text
resource_need_id
listing_id
listing_mode
title
description
country_code
locality
administrative_area
public_location_label
published_at
active_request_count
text_match_kind
location_match_kind
```

---

# 25. Active-request count parity

If returning `active_request_count`, reuse the exact existing public definition.

Do not reimplement a divergent count.

---

# 26. Privacy

Do not return:

- owner email/phone;
- exact location;
- request messages;
- borrower identities;
- agreement IDs;
- reservation periods;
- chat bodies;
- private agreement terms.

Listing ID can route to existing public Resource detail.

---

# 27. Creator authorization

Verify:

```text
authenticated profile == expected creator
need belongs to Project
Project.creator_profile_id == current profile
```

Unrelated/anonymous fail closed.

---

# 28. Read-time lifecycle changes

If a need closes or listing closes, it disappears on the next match read.

No cleanup job.

No match rows exist to delete.

---

# 29. Listing content changes

Published listing text/location changes affect subsequent match reads.

Do not snapshot match text.

---

# 30. Reusable private evaluator

Factor one-need/one-listing matching into a private reusable helper/SQL abstraction returning conceptually:

```text
is_match
text_match_kind
location_match_kind
```

04C4F should reuse the same semantics.

No client execute grant.

---

# 31. Search indexes

Add appropriate published-listing full-text expression indexes using the same text-search configuration as the matcher.

Separate title/description indexes are acceptable.

Use existing/needed coarse-location indexes.

No external search service.

---

# 32. Explainability contract

E2 must be able to localize reasons such as:

```text
Title phrase matches
Title keywords match
Details keywords match
Same locality
Same area
Same country
Dona / Scambia
```

Return enums, not generated prose.

---

# 33. Exact phrase vs stemming tests

Distinguish:

```text
Need "trapano a percussione"
Listing "Trapano a percussione Bosch"
→ title_phrase

Need plural/stem variant
Listing stem-compatible title
→ title keyword tier

Keyword only in description
→ description tier
```

No fuzzy similarity threshold.

---

# 34. No synonym assumption

Do not assume:

```text
trapano = drill
scala = ladder
```

without shared lexical content.

No hard-coded synonym dictionary.

Future taxonomy/semantic work may improve recall.

---

# 35. Mode behavior

Cover:

```text
null → both
donate → only donate
exchange → only exchange
invalid → 22023
```

---

# 36. Geography behavior

Cover all four scopes.

A narrower explicit filter excludes outside candidates even if text match is stronger.

No silent widening.

No geocoding/distance calculation.

---

# 37. Tavolo parity

Matching must work for both one-time Projects and recurring Tavoli with their canonical rough locations.

Do not make Proposal-only assumptions.

---

# 38. Draft creator matching

Because E1 is creator-only, an open need on a nonterminal draft Project may match without being publicly visible.

Do not route through public-needs authorization.

---

# 39. No match notifications/audit flooding

Do not emit match-found outbox events, notifications, push, or Realtime.

Do not write one audit event per returned match.

04C4F owns subscriptions/notifications.

---

# 40. Structural pgTAP

Cover:

- forward migration;
- private matcher helper;
- FTS indexes;
- creator RPC signature;
- fixed search paths;
- private-helper grant denial;
- authenticated RPC grant;
- no persisted match table;
- no vector/embedding dependency.

---

# 41. Behavioral pgTAP — authorization/lifecycle

Cover:

- creator own open need;
- unrelated denied;
- anonymous denied;
- closed need;
- terminal Project;
- draft eligible;
- active published eligible;
- paused Tavolo eligible;
- ended Tavolo rejected.

---

# 42. Behavioral pgTAP — text tiers

Cover all five text tiers and strongest-tier precedence.

Verify no lexical match excludes candidate.

---

# 43. Behavioral pgTAP — FTS safety

Cover punctuation, repeated whitespace, apostrophes, stopword-heavy text, tsquery-looking characters, and model-number tokens.

Raw user text must not become unsafe tsquery syntax.

---

# 44. Behavioral pgTAP — geography/mode

Cover all geography scopes, location-match kinds, missing-required-location behavior, case-insensitive matching, and all mode filters.

---

# 45. Behavioral pgTAP — ranking/pagination

Seed all text/location tiers.

Verify exact ordering:

```text
text tier
→ location tier
→ published_at
→ listing ID
```

Create ties and verify no pagination duplicates/skips.

---

# 46. Behavioral pgTAP — privacy/reservation independence

Verify result excludes private fields.

Create equivalent matching listings where one has active private LEND reservation.

Both must remain matching candidates with same text/location tier.

---

# 47. Active-request-count parity test

Compare returned count against existing public Resource listing RPC.

---

# 48. Real OTP verifier

Add focused verifier covering:

1. creator and unrelated user;
2. Proposal and Tavolo;
3. open needs;
4. listings across text tiers;
5. geography scopes;
6. mode filters;
7. deterministic ranking;
8. pagination;
9. creator authorization;
10. closed need;
11. listing closure;
12. active private loan non-influence;
13. no private fields.

Never log OTP/token/private agreement/reservation/request/chat content.

---

# 49. Generated types

Regenerate/update types for new public RPC.

Because D1 DB gates are still blocked, do not claim drift passed without a fully replayed current stack.

If local Supabase remains unavailable:
- update only compile-required checked contracts carefully;
- report DB/type checks unexecuted;
- retain them as hard pre-merge gates.

---

# 50. Documentation / roadmap

Update:

```text
04C4D1 — PR #83, DB gates blocked
04C4D2 — PR #84

04C4E — Project Resource Matching
04C4E1 — Explainable Matching Domain
  this PR
04C4E2 — Mobile Matching UX
  next
```

Document limitations:

```text
creator-facing
lexical, not semantic
no synonyms/global taxonomy
no opaque score
coarse public geography
explicit filters
private loan reservations not used
```

---

# 51. 04C4E2 handoff

E2 should consume:

```text
list_project_resource_need_listing_matches
```

plus existing Project resource-needs UI and public Resource-detail route.

Likely UX:

```text
Project need
→ Find matching resources
→ geography + Dona/Scambia filters
→ explainable ranked listing cards
→ open existing Resource detail
```

Do not implement E2 here.

---

# 52. 04C4F handoff

04C4F may reuse the private matcher for saved searches/matching notifications.

E1 does not create saved searches or alerts.

---

# 53. Validation

Run repository equivalents of:

```text
npm run db:reset
npm run db:lint
npm run db:advisors
npm run db:test
npm run db:types:check

node --check <matching verifier>
npm run check:web
npm run check:site
npm run check:mobile
git diff --check
```

Attempt focused OTP integration.

Attempt hosted Validation once.

If GitHub cannot allocate a runner due the known billing/spending-limit restriction:

```text
not executed due external infrastructure
```

Do not rerun pointlessly.

This DB-heavy PR must not merge until current-stack replay, lint/advisors, pgTAP, OTP integration, and generated-type drift all execute green.

---

# Non-goals

Do not implement:

- Flutter matching UI;
- public matching;
- participant matching;
- saved searches;
- match notifications;
- push;
- vectors/embeddings;
- pg_trgm threshold;
- synonym dictionary;
- global taxonomy;
- external search service;
- exact distance/geocoding;
- private loan-calendar matching;
- loan-date exposure;
- desired-loan-period metadata;
- Dona redesign;
- Groups/invites/WhatsApp.

---

# Acceptance criteria

- [ ] based on PR #84;
- [ ] exact prompt archived;
- [ ] forward migration only;
- [ ] creator-only matching RPC;
- [ ] no persisted match rows;
- [ ] only open eligible needs match;
- [ ] nonterminal lifecycle rules enforced;
- [ ] only published listings returned;
- [ ] deterministic text tiers;
- [ ] title phrase strongest;
- [ ] title tiers before details tiers;
- [ ] safe PostgreSQL FTS;
- [ ] no raw tsquery injection;
- [ ] no numeric match confidence;
- [ ] explicit mode filter;
- [ ] explicit geography scope;
- [ ] stable location-match enum;
- [ ] no silent geography widening;
- [ ] deterministic ordering;
- [ ] complete keyset cursor;
- [ ] public-safe fields only;
- [ ] active-request count parity;
- [ ] private D1 reservation state does not affect matches;
- [ ] no reservation dates/identities returned;
- [ ] Proposal/Tavolo parity;
- [ ] no synonyms/taxonomy invented;
- [ ] reusable private matcher for F;
- [ ] pgTAP/ranking/pagination/privacy coverage;
- [ ] OTP integration;
- [ ] generated types updated where executable;
- [ ] inherited DB blocker reported honestly;
- [ ] no E2/F scope creep;
- [ ] no PR merged.

---

# Completion report

Return:

1. Stack/base status
2. 04C4E1 branch/base/PR
3. Changed files
4. Creator-facing authorization
5. Need eligibility
6. Project lifecycle eligibility
7. Listing eligibility
8. No-persisted-match decision
9. Text-search implementation
10. Text-match tiers
11. Title-phrase behavior
12. Title-keyword behavior
13. Details fallback
14. Stopword/empty-query handling
15. No-score guarantee
16. Project-location resolution
17. Location-match kinds
18. Geography filters
19. Missing-location behavior
20. Mode filter
21. Availability/privacy semantics
22. D1 reservation non-influence
23. Match ordering
24. Pagination cursor
25. Result shape
26. Active-request-count parity
27. Private matcher reuse
28. Search indexes
29. Proposal/Tavolo parity
30. Structural pgTAP
31. Authorization/lifecycle pgTAP
32. Text-tier pgTAP
33. FTS-safety pgTAP
34. Geography/mode pgTAP
35. Ranking/pagination pgTAP
36. Privacy/reservation-independence pgTAP
37. Real OTP integration
38. Generated types/drift
39. Local regression validation
40. Hosted Validation executed/not-executed
41. Inherited D1 DB-gate status
42. 04C4E2 handoff
43. 04C4F handoff
44. Warnings/blockers
45. Commit/PR reference

Do not merge any PR.
