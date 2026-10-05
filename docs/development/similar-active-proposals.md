# Similar upcoming Proposal lookup (SIM01)

SIM01 is implemented for draft review on exact TW04 head
`2905d8a95227a151edb8c8b712b1fbb424f9f459`, branch
`codex/sim01-similar-active-proposal-matching`, target
`codex/tw04-mobile-template-workshop`. Predecessors remain unmerged. SIM02 owns
automatic editor suggestions/navigation; TW05 owns the realistic demo world.

## API, authority and inputs

`public.list_similar_active_proposals` is an authenticated, read-only top-N
lookup. It uses `private.require_expected_identity`, requiring the current
actor without a saved draft, publish-ready form or profile photo. SIM02 must
retain existing app readiness/setup navigation. An incomplete profile does not
give this public-data read any additional interaction authority.

The new migration adds one RPC, a private pure immutable title helper and a
partial GIN expression index. Existing discovery/template/report/application/
editor/capacity/blocking/Storage contracts and raw-table RLS are unchanged.
EXECUTE is authenticated-only; PUBLIC, anon and service_role are revoked.
Clients cannot call the raw helper. The security-definer API has an empty search
path and schema-qualified references.

```ts
await supabase.rpc("list_similar_active_proposals", {
  p_expected_profile_id: currentActorId,
  p_title: "Repair Café di quartiere",
  p_skill_ids: selectedControlledSkillIds,
  p_country_code: "IT",
  p_locality: "Trento",
  p_excluded_proposal_id: currentBoundDraftId ?? null,
  p_limit: 5,
});
```

| Input             | Exact bound                                                                                                                                                                    |
| ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Expected actor    | Required current authenticated UUID. Null/mismatch/anonymous: `42501`.                                                                                                         |
| Title             | Required non-null text, at most 100 characters including whitespace. Empty/intermediate/weak valid input: `[]`. No truncation.                                                 |
| Skills            | Optional/null/empty; one-dimensional UUID list, at most 50 entries before deduplication. Unknown/null entries fail. Known duplicate IDs sort/deduplicate without extra weight. |
| Country           | Optional; supplied text must normalize by upper(trim) to `^[A-Z]{2}$`, the existing domain rule. Supplied blank/invalid fails.                                                 |
| Locality          | Optional rough text, at most 120 characters including whitespace. Trim/repeated whitespace/case normalize; whitespace-only means omitted. No address/coordinates.              |
| Excluded Proposal | Optional UUID used only in candidate comparison, with no existence/ownership probe.                                                                                            |
| Limit             | Default 5; supplied value must be non-null and 1–10. No pagination or total match count.                                                                                       |

Semantic invalid inputs fail `22023`, including when the title is otherwise
weak. Malformed UUID argument types may fail at the Data API cast boundary
(`22P02`). SQL/network/timeout errors remain explicit errors. The endpoint
persists/echoes no submitted idea, emits no audit/outbox/notification, and calls
no external provider. Do not put private editor input in URLs, telemetry or
failure diagnostics. Verifier failures report labels/codes without raw ideas.

## Admission and deterministic ranking

`private.proposal_idea_lexemes` lowercases, folds its listed common Latin vowel
accents plus ç/ñ, splits on non-alphanumeric punctuation, keeps distinct
alphabetic-containing words of at least four characters, removes its explicit
Italian/English stopword/generic activity/day vocabulary, and sorts the set.
User apostrophes, %, _, &, | and Unicode are literal input, never SQL, regex or
tsquery syntax. Words shorter than four characters are omitted.

Input locality terms are removed from idea topics. Candidate locality and
administrative-area terms are removed before admission, so a coincident city
alone cannot admit even without an input hint. At least one remaining topic
must occur in the candidate **title**. There is no skill-only, locality-only,
summary-only or description admission.

The total order is:

1. Distinct title overlap divided by the larger idea/candidate topic-set size,
   descending. Extra unmatched words cannot increase internal lexical rank.
2. Number of distinct shared selected skills, descending.
3. Known available, then capacity unknown, then Full.
4. Same rough locality, then same supplied country, then other/no refinement.
5. Start instant ascending, Proposal UUID ascending.

The internal ratio is never returned as probability, duplicate confidence,
quality or popularity. Skills strengthen plausible matches; missing/different
skills do not erase admission. Repeated terms/IDs and generic padding do not
add weight. Relevance precedes capacity/locality; comparable available farther
matches precede Full nearby. Founder review may refine this documented choice.

| Idea / candidate                                                    | Behavior                                                    |
| ------------------------------------------------------------------- | ----------------------------------------------------------- |
| Repair Café di quartiere / Repair Café del sabato                   | Topic `repair` matches without skills/full-title substring. |
| Murale comunitario / Murale comunitario in another locality         | Topic match, refined by capacity/location.                  |
| Aiuola condivisa / Aiuola condivisa                                 | Title-only match; controlled skills can strengthen it.      |
| Aiuola condivisa / Costruire una libreria with the same broad skill | Not admitted. Same-city dinner/concert also fails.          |
| Community garden / Community garden at the weekend                  | Useful English title-only match.                            |
| Progetto comunitario a Trento / same generic title/locality         | No remaining topic, no suggestion.                          |
| Laboratorio comunitario / Workshop condiviso                        | Generic activity language alone is insufficient.            |
| gardening / garden; riparazione / repair                            | No implicit stemming, translation or synonyms.              |

This means “may be related.” Single topics can yield false positives; plurals,
synonyms, short words, mixed language and unlisted generic/geographic words can
cause false negatives/positives. Accent folding is a small fixed map, not
universal transliteration. Changing this immutable index helper requires a
forward migration rebuilding its expression index. No new taxonomy/provider
or language detector is introduced.

## Eligibility and narrow response

One finite server statement timestamp owns the call. Candidates require a
correctly linked `one_time` Project, published Proposal, canonical shared
public viewability, finite valid schedule and canonical `upcoming`.
`starts_at > reference_time` admits just-before-start, excludes exact start and
every later lifecycle-derived status. Drafts/cancelled/Tavoli/non-public records
never qualify. No caller reference clock exists.

Capacity uses `private.project_registration_capacity_snapshot` only after
meaningful admission. Organizer toggle, active delegates, organizer/member
overlap, ended memberships and pending requests retain canonical behavior.
Legacy null is `capacity_unknown`, neither Full nor proven available.

The exact response allow-list is illustrated here:

```json
{
  "proposal_id": "<public Proposal UUID>",
  "cover_object_path": null,
  "title": "Repair Café del sabato",
  "summary": "Public preview text",
  "starts_at": "2098-03-01T10:00:00+00:00",
  "ends_at": "2098-03-01T12:00:00+00:00",
  "event_timezone": "Europe/Rome",
  "country_code": "IT",
  "locality": "Trento",
  "administrative_area": "TN",
  "public_location_label": "Rough public area",
  "derived_status": "upcoming",
  "availability": "available",
  "title_evidence": "title_topic",
  "shared_skill_ids": [],
  "location_relation": "same_locality"
}
```

Title reason is `title_topic` or `multiple_title_terms`. Location is
`same_locality`, `same_country`, `other` or `not_provided`. Locality compares
normalized labels and, if supplied, country. Without country it remains
ambiguous rough-label evidence, not verified distance. Geography is a preference,
not a hard filter. Shared IDs only refer to submitted controlled skills.

Cover is current canonical source metadata through existing `cover-images`
parent authorization; no copy/privileged delivery/contextual photo lookup.
Missing cover stays null. Omitted fields include exact meeting/coordinates,
description, Creator/member identities/photos, request text/state, workspace,
contributions, template baseline/application/receipt, moderation/staff notes
and every exact membership/organizer/occupancy/remaining count. Existing public
capacity aggregates and Flutter's social-proof threshold are unchanged.

A match grants no permission to join. Blocking leaves public candidates visible;
canonical new-interaction commands retain manager/block/profile/photo/capacity
gates. Own/participated/pending candidates remain relevant, with SIM02 reusing
ordinary authorized relationship reads and ordinary detail/capacity presentation.
Template removal does not hide an otherwise public upcoming source; the verifier
proves this using synthetic controlled aging and canonical audited removal.

## Query work, verification and CI

The partial GIN indexes published normalized titles; the existing published
start/ID B-tree remains available for future narrowing. Indexed title overlap
and eligibility filter before admitted rows materialize and receive relevance,
skill/capacity snapshots and top-N ordering. There is no unrelated earliest/
latest page cutoff, catalog download, durable cache/counter or worker.

Input/output bounds do not guarantee constant work: all meaningful upcoming
topic matches may be scored. A common topic in a very large active catalog can
cost more. No hidden recall budget or exhaustive semantic-similarity promise.

After clean isolated-loopback reset and pgTAP, run:

```text
npm run proposal:similar:verify:local
```

The verifier refuses non-loopback API/DB/mailbox URLs and uses synthetic
`.invalid` OTP actors plus canonical profile, publication, participation,
authority, cover and moderation commands. Narrow trusted SQL only sets
synthetic legacy/lifecycle/reviewer cases and repeat-run cleanup. It never
changes actual history. A photo-free reader with no draft succeeds. Repeated
reads compare domain totals and source/template digests to prove no side effects.

`scripts/fixtures/sim01-query-plan.sql` creates 1,121 canonical upcoming sources
(61 clockwork-topic, 60 garden-topic, 1,000 unrelated), plus 6,000 historical and
4,000 cancelled synthetic negatives. Scale rows and publication effects roll
back in one transaction. ANALYZE supplies local estimates; planner statistics
may need subsequent maintenance after rollback, so this is a disposable stack.

The verifier extracts the actual deployed candidate SELECT from
`pg_get_functiondef`, binds variables and runs EXPLAIN (ANALYZE, BUFFERS,
FORMAT JSON), without forcing indexes/disabling sequential scans. It reports
indexes, admitted rows, buffers and observed time, checks indexed title/future
narrowing before scoring, and proves a strongest later match survives beyond
ordinary discovery's first page. Weak input also exercises the API early return.
The default top-five and requested top-ten share the same total order and keep
that strongest later candidate first. An actual ordinary discovery page of 20
does not contain it.

One local replay observed the following plans on that synthetic population:

| Input        | Admitted rows | Shared hit blocks | Execution time |
| ------------ | ------------: | ----------------: | -------------: |
| `clockwork`  |            61 |             1,434 |      10.259 ms |
| `garden`     |            61 |             1,185 |       8.305 ms |
| Empty topics |             0 |                 0 |       0.072 ms |

All three planned the partial title GIN index; the nonempty queries also used
the Project and cover indexes. The future predicate removes old
rows before capacity/ranking. Timings vary with the disposable stack and are
evidence, not pass/fail thresholds or production latency guarantees. Final
verifier counts and hosted evidence are recorded in the PR.

There is no arbitrary earliest-page or candidate-budget truncation. Work grows
with the indexed topic hit set and meaningfully admitted upcoming candidates;
a very common useful word can still require ranking many future rows. Result
limits do not cap that work. V1 makes no exhaustive semantic-recall promise.

`115`/`116` pgTAP cover grants, allow-list, normalizer, inputs, ordering and
exact-start eligibility. The authenticated verifier runs explicitly in hosted
Database validation and complete manual `check:db`, preserving TW02/TW03/DRAFT01.
Root command/workflow changes select all four areas under the existing
classifier; trigger boundaries and required checks are unchanged.

## SIM02 and later integration

The [SIM02 mobile implementation](automatic-editor-suggestions.md) now consumes
this exact contract on the approved draft base; it remains unmerged for review.

SIM02 should debounce input, pass the currently bound destination as exclusion,
capture actor/input generations and ignore old responses after input/route/
account changes. Empty valid input may be skipped or sent for `[]`; validation
failures stay explicit. Omit unfinished invalid optional geography rather than
silently substitute valid defaults. Revalidate availability; absent matches
are not proof of ordinary source deletion.

Suggestions never block save/publication, join automatically or replace forms.
Candidate navigation uses ordinary detail and DRAFT01's departure guard once.
Completed Workshop reuse keeps separate identities/tokens/recovery.

Founder review covers false positives/negatives, title-only versus skill
refinement, locality/Full ordering and narrow reasons. Later integration must
preserve #128/#131/#134/#138 participant links/auth returns/browser joining/native
routes and any then-merged moderation visibility changes. No such branches,
shared database change, deployment or merge is part of SIM01.
