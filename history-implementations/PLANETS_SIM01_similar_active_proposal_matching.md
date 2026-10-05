# PLANETS — SIM01: Similar active Proposal matching backend

Date: 5 October 2026  
Repository: `lillo24/planets.community`  
Task: add a bounded, read-only backend lookup of meaningfully related upcoming public one-time Proposals for a creation idea.

## Outcome and authorized workflow

An unpublished Proposal editor will later be able to send a title, controlled skill IDs and optional rough geography and receive a small ranked set of active Projects that may already cover a similar idea. This task establishes and verifies that backend contract. SIM02 will implement the automatic editor suggestions and their safe navigation.

Implement SIM01 in one isolated branch/worktree, validate, commit, push and open a **draft stacked PR**. Keep it **unmerged** for founder review of matching examples, false positives, locality/Full ordering and the narrow response, together with predecessor review. Do not deploy or alter shared databases. This explicitly overrides AGENTS.md's default-main/automatic-merge workflow.

The approved dependency base is:

- [TW04 PR #137](https://github.com/lillo24/planets.community/pull/137);
- branch: `codex/tw04-mobile-template-workshop`;
- exact base/head: `2905d8a95227a151edb8c8b712b1fbb424f9f459`;
- suggested new branch: `codex/sim01-similar-active-proposal-matching`;
- PR target: `codex/tw04-mobile-template-workshop`.

Verify the predecessor remote/head and ancestry before branching. Preserve its retained clean checkout. TW01 #127, TW02 #129, TW03 #132, DRAFT01 #135 and TW04 #137 remain draft/unmerged in the inspected stack. This prompt deliberately authorizes that stack as the base; do not stop merely because the general roadmap normally waits for merged dependencies.

Main was inspected at `fcd2236dc620f7b768d4aec01fc5f07ee9b61d76`, including participant-link plans #128/#131/#134/#138. Do not import main's link/auth/browser changes or the separate moderation/admin-hosting stack incidentally. Later integration must preserve both tracks. If predecessors have since merged, use then-current main only after verifying all required contracts survived and record the actual base/target. If an incompatible predecessor revision appears, identify the exact problem rather than inventing another base.

Read repository AGENTS.md, applicable nested instructions, architecture, roadmap and relevant current code. This prompt carries the product rules directly; the Google Doc/prior chat is optional background, not a required dependency. Routine algorithm/schema/test choices within these bounds are authorized.

## Scope and settled product rules

- **Proposals only.** No Tavolo matching, Scambio-Dona search, participants/skills recruitment or Workshop search redesign.
- Match upcoming, publicly viewable, published one-time Proposals. Exclude draft/cancelled sources and Happening, Just Finished and Completed activities.
- Completed templates and similar-active-Project suggestions are separate surfaces. A past template/source is never an active join opportunity.
- Input v1 is **title + optional selected controlled skills**, optionally refined by rough country/locality. Description enrichment is deferred.
- Useful title matching must work without selected skills. One generic shared skill or same locality alone must not generate a candidate.
- Prefer meaningfully related nearby activities with capacity. Full activities may appear secondarily and must be distinguishable.
- Similarity means “may be related,” not “duplicate proved.” Matching never blocks saving/publication or automatically joins an activity.
- Existing profile/photo, blocking, manager authority, join requests, capacity and chat rules remain canonical. A match grants no interaction authority.
- No embeddings, external AI/search provider, whole-database client download, popularity ranking, persisted user-query history or background matching worker.
- The broad realistic demo world remains TW05. Create narrow deterministic synthetic fixtures for SIM01 tests only.

The conservative v1 default is lexical title evidence for admission, with skills strengthening plausible matches and rough locality refining order. No skill-only recommendation is required in this task. This prioritizes avoiding unrelated suggestions without inventing a new taxonomy of “specific skills.” Document limits such as synonyms and cross-language equivalence honestly.

## Verified current contracts

TW04 provides mobile completed-template catalog/detail/report/apply, token-bound resource paging and exact request recovery. DRAFT01 owns guarded editor departure and bound draft sessions. SIM01 must preserve their RPCs, receipts, routes and existing tests; it does not reuse template tokens as match identities.

#137's final-head Validation run 37292688376 passed Change classification/Mobile and logged **1,221 tests**. Database/Web/Site were skipped by scoped classification. Android compilation, a real Android/local-backend Workshop smoke and TW01/TW02/TW03/DRAFT01 local verifiers were reported and their runnable procedure/code inspected. iOS/native physical gesture/accessibility QA remains separate. These are predecessor evidence, not tests already run for SIM01.

Important existing implementation:

- `list_public_proposals`, most recently replaced by `20260928064452_cover_media_domain_foundation.sql`, uses a literal title/summary/description substring filter and ascending start/ID cursor. It also admits Happening/Just Finished discovery. It is not a semantic matcher or an upcoming-only lookup.
- `private.derive_proposal_status(starts_at, ends_at, reference_time)` is canonical. At exact start an event is Happening, not Upcoming; Completed is end + 24 hours.
- `private.is_project_publicly_viewable` is the shared public parent boundary. On this base it admits published one-time sources independently of their time-derived status. Matching must add its own upcoming-only restriction without weakening that helper.
- `private.project_registration_capacity_snapshot` computes organizer-aware capacity usage, unique social headcount, nullable capacity, remaining spots and Full. Use it rather than raw membership counts.
- `list_public_project_capacity_statuses` returns exact aggregate counts. The social-proof reveal threshold lives in Flutter `project_capacity_presentation.dart`; it is a **presentation policy**, not existing server-side count redaction.
- `private.project_resource_match_or_query` and `evaluate_project_resource_listing_match` already illustrate parameterized lexical PostgreSQL matching with bounded reads. Their Italian-only resource semantics are not automatically appropriate for Proposal idea matching.
- Current own participation reads and the expected-identity helpers already exist. Matching is a lookup, not a photo-gated participation command.

Inspect the actual helper definitions, final RPC signatures, indexes and tests before choosing the implementation. Do not copy a superseded migration's public payload or infer source visibility from the presence of a cover.

## New lookup contract

Add one narrowly scoped public-schema RPC with authenticated EXECUTE, backed by canonical server-side eligibility/matching. Choose a name consistent with existing conventions, for example `list_similar_active_proposals`. Add a new migration; do not rewrite applied migrations or replace ordinary discovery.

Use an expected current actor ID and the existing canonical identity gate. It should operate before a draft has been created or a publish-ready form exists. Do not require a saved Proposal ID, profile photo or participation-ready publish fields for this read. Preserve existing mobile readiness/setup rules for the later caller.

Conservative input contract:

| Input | Bound and meaning |
| --- | --- |
| Expected actor ID | Required current authenticated identity; caller-supplied IDs are never authority. |
| Idea title | Required non-null text argument; accept empty/whitespace/intermediate input safely up to the Proposal title limit of 100 characters. Insufficient useful evidence returns no matches. Reject null/oversized input explicitly rather than silently truncating. |
| Skill IDs | Optional/null/empty allowed; at most 50 controlled non-null UUIDs. Reject unknown IDs/null entries; normalize duplicates deterministically without adding weight. |
| Country code | Optional; normalize supplied two-letter code using ordinary domain rules. Invalid supplied code is an input error. |
| Locality | Optional trimmed rough locality, at most 120 characters; no exact address or coordinates. |
| Excluded Proposal ID | Optional opaque ID for the current edited destination; filter it out without turning existence/ownership into a probing read. Null works for a new unsaved form. |
| Result limit | Default 5, hard range 1–10. No full-catalog response or total-count promise. |

Do not accept exact meeting data, user description, selected cover, workspace/chat content or another user's private context. A missing country/locality does not disable a useful title lookup. The frontend may omit unfinished invalid geography later; the backend must not silently reinterpret invalid supplied fields as valid defaults.

Use an authenticated-only API for this editor lookup rather than expanding anonymous/private-input surfaces. Revoke implicit PUBLIC/anon/raw helper permissions; explicitly grant only the required execution. Keep security-definer search paths empty and schema-qualify references. Preserve service-role restrictions and raw-table RLS; do not give clients a private-schema escape.

Invalid input/auth must fail clearly; a valid low-signal/no-match request returns an empty list. SQL errors/timeouts are errors, not empty successful results. Do not store submitted titles/skills in a query-history table, notifications, outbox, URLs or telemetry. Avoid logging raw private idea text in verifier failure diagnostics.

## Matching and relevance

Use a small explainable lexical strategy inside PostgreSQL. Choose/document exact normalization, admissibility thresholds and ranking after inspecting existing SQL and testing the examples below.

- Normalize case, surrounding/repeated whitespace and punctuation safely. Deduplicate title lexemes and selected skills.
- Treat user text as literal input, never SQL/regex/tsquery syntax. Parameters containing apostrophes, percent signs, underscores, operators or Unicode must remain safe.
- Support useful Italian and English lexical examples. Do not apply an Italian-only stemmer blindly to every input or claim automatic translation/synonym understanding.
- A changed word order or extra local/detail words should not require the entire entered title to be a substring of the candidate title.
- Give candidate title evidence primary weight. Candidate public summary may provide weaker corroboration if useful; no full private draft or description enrichment is needed.
- Stopwords and generic activity words must not alone create confident matches. A normalized generic exact phrase is not automatically sufficient evidence.
- A title consisting only of punctuation/common words, or only locality plus generic activity words, returns no useful candidates even when a skill/locality coincides.
- Shared controlled skills improve an already plausible title match. Missing/different skills must not erase a strong topic match; shared generic skills cannot admit an unrelated topic.
- Use bounded, documented matching inputs. Repeated words, repeated skill IDs or longer title padding must not inflate a match.
- If accents/stemming have limits, test and document them. Do not add a provider or substantial dependency to eliminate every linguistic false negative.
- Do not label a heuristic score as a percentage probability, confidence of duplication or quality/popularity.

Return compact reason enums/fields suitable for SIM02 localization, such as title evidence, shared selected-skill IDs and a rough-location relation. Keep them derived from authorized candidate content plus the submitted input. Do not echo the user's raw title, invent snippets from private content, or expose arbitrary internal ranking expressions.

For a fixed input and database snapshot, result order must be deterministic. Rank meaningful relevance ahead of weak coincidence; prefer available nearby candidates over comparable Full/farther candidates. Define a documented total order ending with start instant and Proposal UUID. Capacity is a secondary preference, not proof of relevance. Do not rank by social popularity or hidden participant counts.

The lookup is a fresh bounded top-N result for SIM02, not an infinite-scroll catalog. No pagination is required for v1. Return no misleading total match count; rerun on changed input. If pagination is introduced because the actual implementation needs it, carry every ordering key, bind it to the same input and test it; do not invent an unstable score-only cursor.

## Authoritative candidate eligibility

Evaluate against one finite server-side reference instant per call/statement. Do not expose a client-controllable reference clock that could retrieve future/past eligibility.

Each candidate must satisfy all of:

1. canonical shared Project kind `one_time`, linked correctly to its Proposal;
2. current published lifecycle and the existing public-viewability boundary;
3. finite valid schedule and canonical `upcoming` status at the call's reference instant;
4. meaningful lexical admission under this matcher;
5. not the supplied edited/excluded Proposal ID.

Add explicit upcoming constraints rather than copying discovery's “end later than now - 24h” predicate. Drafts, cancellations, Tavoli, Happening, Just Finished, Completed and all non-public records must fail even if their text/skills match perfectly. Template identity/removal is not the candidate domain: removing only a template does not hide an independently public upcoming source or an independent derivative draft.

Use canonical capacity snapshot data after meaningful eligibility/admission. Never derive Full from Creator + raw memberships or treat pending requests as occupied places. Organizers count according to the source's setting; organizer/participant overlap remains unique.

Nullable legacy capacity is **unknown**, not Full and not proven available. If rankable, clearly distinguish it from known available/Full. Do not fabricate a capacity recommendation or threshold.

Do not redefine public discovery through blocking. On this base public Project viewability and new-interaction authorization differ. A public match may still be blocked from a new join request by canonical manager/block/capacity checks. Return no inbound block flags, block identities or reasons, and do not invent a new block-based hiding/ranking rule. Tests must preserve this distinction.

The current edited source is excluded; other own/participated/pending Projects can remain relevant. Preserve their normal requester state through existing authorized reads or a minimal actor-only projection, without presenting them as a new join opportunity. No private request/message/member lists belong in this matching response.

## Narrow response and privacy

Return only what the later compact suggestion previews need. Prefer a dedicated match model rather than a full owner/public detail object followed by client filtering.

| Data | Contract |
| --- | --- |
| Candidate identity/title/summary | Canonical public Proposal ID and public preview text. |
| Schedule/status | Public future instants/timezone and canonical Upcoming status. No old-event join claims. |
| Rough geography | Public country/locality/public area label needed for context; no exact meeting text/coordinates, even when the source has such fields. |
| Controlled skills/reasons | Existing public skill descriptors/importance if useful, bounded shared-skill reasons and stable reason enums. |
| Cover | Optional current authorized source cover path through its parent policy. No media copies, signed-url bypass or profile-photo context. |
| Availability | Minimal `available` / `full` / `capacity_unknown` or equivalent, derived canonically. It describes capacity, not permission to join. |
| Current user's relationship | Existing own participation reads can supply it in SIM02; if returned here, only the authenticated actor's minimal state with canonical checks. No other person's state, request text or counts. |

Avoid exact membership/organizer/social/occupancy/remaining counts in this **new** endpoint. They are unnecessary for ranking presentation and could introduce an alternate visible low-count badge. This is a narrow new payload decision, not a claim that the existing capacity RPC redacts those values.

SIM02 can open ordinary detail and reuse the existing public capacity presentation there. Do not change that threshold policy, aggregate RPC, manager exact counts or normal capacity validation to accommodate this match model.

Never include private Bozza, full own-draft content, exact meeting data, participant identities/photos, chat/request messages, workspace links, contributions, template application receipts, reports/staff notes or a public graph of who reused templates. No contextual Creator-profile lookup is required for a compact matching preview.

## Performance and migration discipline

Use existing PostgreSQL primitives and appropriate index-compatible candidate narrowing. Inspect data/index patterns before adding narrowly justified indexes or a small private helper. Keep helpers client-inaccessible. No durable match counter/cache, recommendation table or scheduled reindex worker is expected.

Input/output limits alone do not bound query work. Avoid fetching an entire catalog into Flutter or scoring every historical/irrelevant row before eligibility. Inspect `EXPLAIN (ANALYZE, BUFFERS)` on a reproducible local synthetic population, including weak/common input and many past/cancelled records; record plan evidence and practical limits.

Do not pre-limit to the earliest/latest handful of all Projects before relevance, which can miss the best match entirely. If a candidate budget is necessary, apply meaningful indexed eligibility/text narrowing first and document any recall limit. Do not promise exhaustive similarity.

No real production data or shared database is authorized for query-plan tests. Keep synthetic scale fixtures disposable/reproducible and local. Do not add the full TW05 demo scenarios to production seed files.

Add migrations rather than rewriting predecessors. Regenerate public TypeScript database types through the repository generator; never hand-edit generated RPC signatures. Preserve existing discovery, template/report/application/editor commands and their tests.

## Acceptance evidence

Use pgTAP plus real local authenticated API checks, with clear positive/negative examples and structural grant audits. Include at least:

1. Expected actor required; anonymous/non-current actor rejected. Read works for a legitimate ready identity without a saved draft, publish-ready fields or profile photo.
2. Empty/null policy, whitespace, punctuation/stopword/generic-only titles, maximum/oversized title/locality, null/unknown/repeated skills, invalid country and invalid limits behave as documented. Weak valid input never becomes an unfiltered catalog query.
3. “Repair Café di quartiere” → “Repair Café del sabato” matches without requiring a full-title substring; useful title-only input works. Selected repair skills strengthen appropriate matches.
4. “Murale comunitario” → a future mural Proposal and “Aiuola condivisa” → relevant future gardening activity provide realistic positives; extra location/detail wording and reordered terms behave as documented.
5. Same-locality unrelated dinner/concert is not suggested solely by location. A woodworking bookcase sharing a broad skill with gardening is not admitted without topic evidence.
6. A shared generic/common token or one broad skill cannot produce unrelated matches. Repeated words/skills do not inflate score. Useful English lexical examples and Unicode/apostrophes/operators are safe.
7. Strong same-topic activity with different/missing selected skills can still match. No-description matching is supported; no external request/service occurs.
8. Relevant available local, Full local, same-topic farther activity and legacy-null-capacity cases have documented deterministic order/availability. Repeated identical snapshots and ties resolve by the final stable keys.
9. Upcoming includes just-before-start; exact start and every later status are excluded. Draft, cancelled, non-public and Tavolo records are absent; passing an excluded ID suppresses it without private existence disclosure.
10. Organizer toggle On/Off, active delegates, participant/organizer overlap, left/removed membership and pending requests use canonical capacity behavior. Near-full/Full changes are reflected on fresh lookup.
11. An unrelated user's pending request/membership, names/photos and exact meeting/workspace/report data cannot enter the response. Assert the actual payload allow-list, not only UI visibility.
12. Actor's own/participated/pending candidates remain compatible with ordinary authorized requester state. A blocked new join still fails through existing canonical commands; the lookup does not disclose inbound blocks or make a new membership.
13. Authorized/missing cover path preserves the source policy; no new media ownership/copy or baseline access is introduced.
14. Lookup is read-only: repeated calls produce no drafts/templates/reports/requests/notifications/outbox/query-history rows and do not change source content or template provenance.
15. A bounded top-5/top-10 result does not omit a strongest relevant candidate merely because it falls beyond ordinary discovery's first page. Query-plan fixture verifies indexed/narrowed behavior and records limits.

Use canonical authenticated creation/publication/participation APIs for meaningful fixtures. Controlled local timestamp aging or local-only staff setup is allowed only for synthetic lifecycle/negative cases, documented and isolated. Do not edit actual user/source history. Preserve existing fixtures and keep verifiers safe for repeat runs.

Use deterministic assertions on ranking/reasons/authorization; do not rely on brittle wall-clock performance thresholds or exact planner costs. If a failing predecessor test appears, diagnose and report it; do not weaken its assertion to get a green run.

## Validation and hosted execution

Run the repository's affected-area checks:

- isolated loopback migration replay/reset, schema lint, security advisors and complete pgTAP suite;
- new real authenticated matching verifier, existing Proposal/TW01 and participation-aware Browse verifiers;
- capacity/blocking/media verification relevant to the consumed helpers, plus TW02/TW03/DRAFT01 contract checks when affected by integration;
- generated database types and committed drift check;
- tooling tests/formatting and affected Web checks for generated types; other areas according to actual dependency/classification.

Expose the new authenticated verifier through a clear repository command and **wire its actual execution into the Database validation job**, preserving current TW02, TW03 and DRAFT01 API steps. Put it in the manual complete database gate too. Merely adding a script or documenting local results is not hosted coverage.

Inspect current change classification before modifying workflow/root scripts. Shared tooling/workflow changes can legitimately trigger Mobile/Web/Site as well as Database. Run what is affected; do not weaken required statuses, claim skipped jobs ran or broaden unrelated CI to conceal missing verification.

No mobile suggestion widget/editor integration is required here. Android/iOS compilation and native gesture QA need not be invented for a backend-only change; distinguish checks selected by hosted shared-file changes from product/platform QA still deferred to SIM02/TW05.

Inspect final diff, rerun checks justified by final edits and verify hosted results at the final PR head. Do not rerun passed costly suites merely to increase totals. A failed/blocked check must remain explicit.

## Documentation and completion

- Archive this exact prompt verbatim under `history-implementations`.
- Add/update the closest backend/read-contract documentation, Supabase map, verifier map and `docs/development/template-workshop.md` or a linked similarity document.
- Record exact input bounds, admission/ranking examples, linguistic limits, future-only eligibility, response allow-list, capacity-versus-join distinction, no query persistence and reproducible plan evidence.
- Update the roadmap: SIM01 implemented on its draft branch; SIM02 and TW05 remain deferred. TW04 and predecessors are not thereby merged.
- Give SIM02 a precise consumable RPC/example response and error contract, including what the client should do with sparse input, excluded current destination, stale input responses and relationship/Full state.
- Commit only intended files, push and open the required **draft PR targeting the selected TW04 branch**. Keep it unmerged and the clean checkout retained for review.
- Report exact base/head/branch/target/PR, commands/checks actually run, assertion counts, final-head CI, skipped areas, plan evidence and concrete limitations.
- Founder review focuses on false positives/negatives, title-only versus skill refinement, locality/Full ordering and narrow match reasons. Do not stop for routine threshold implementation choices that these examples/tests can resolve.
- Later stack/main integration must reconcile current participant links/auth returns/browser joining/native routes (#128/#131/#134/#138) and any then-merged moderation visibility changes. Do not merge those branches as part of SIM01.

Complete the authorized backend implementation and reviewable draft PR. Leave automatic editor suggestions, safe candidate navigation and the realistic final demo world to their dedicated plans.
