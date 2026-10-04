# Source-linked Template Workshop (TW01/TW02/TW03)

TW01, TW02 and TW03 are implemented on isolated draft branches, pending founder
review. This document owns the source-linked domain, reporting/removal contract
and atomic independent-draft creation contract. TW02 extends the shared mobile report form and
existing admin case detail; Workshop screens and production data remain
deferred. The supplied plan is retained unchanged in
[`history-implementations`](../../history-implementations/PLANETS_TW01_source_linked_template_domain.md).

## Identity, publication and baseline

`private.proposal_templates` has one UUID identity per once-published one-time
`proposals.id`, a unique `source_proposal_id`, immutable
`original_creator_profile_id` and `linked_at` (the source publication instant).
It is not a Project and owns no participation, delegates, chat or occupancy.
There is no independent template authoring/submission/withdrawal API.

The source lifecycle trigger creates the identity synchronously in the first
successful draft-to-published transaction. Its BEFORE UPDATE capture retains
the actual last persisted draft's title, summary, description and ordered
`skill_id`/`importance` selections in `private.proposal_template_baselines`.
Draft saves create no template. Failed publication rolls back both new records;
publication retries produce no extra baseline, identity, audit or outbox event.
Cover-before-publication, profile-photo and capacity safeguards are unchanged.
The baseline has no cover/media, needs, logistics, workspace or owner response.

The migration backfills identities for existing published sources, including
future events and retained cancelled publications, using source publication
time and `ON CONFLICT DO NOTHING`. It creates no draft baseline or publication
event. Trusted inserts that are already published also receive only an
identity. A missing baseline means no genuine saved draft was retained.
Baseline update/delete and identity reassignment are rejected. Restrictive
source/profile foreign keys preserve the existing account-retention boundary;
this adds no account-deletion workflow or public retention claim.

| Actor                                                                                          | Baseline access                                                |
| ---------------------------------------------------------------------------------------------- | -------------------------------------------------------------- |
| Immutable original Creator with matching current/expected identity                             | Own retained baseline; zero rows for a legacy missing baseline |
| Anonymous                                                                                      | No EXECUTE grant                                               |
| Other authenticated profile, including participant, current/revoked Co-creator or Co-organizer | `42501`; no contextual permission                              |
| Moderator/admin acting as another profile                                                      | No staff exception                                             |
| `service_role`                                                                                 | No RPC/table/helper grant                                      |

`get_own_proposal_template_baseline(p_expected_creator_profile_id, p_template_id)`
uses the current canonical expected-identity gate. Private cancelled/removed
history remains available only to its original Creator. No public comparison
endpoint or general staff-access path exists. Suspension is not canonical on
the TW01 base; later approved global restrictions must compose with this gate.

## Canonical visibility

`private.is_proposal_template_publicly_usable(template_id, reference_time)` is
shared by catalog, exact detail and blueprints. Application uses it
again within its own transaction. It requires:

- a once-published source whose shared kind is `one_time` and lifecycle is
  currently `published`;
- canonical `derive_proposal_status(...) = 'completed'`, exactly at end + 24
  elapsed hours, with a finite reference instant;
- the current `private.is_project_publicly_viewable(source_id)` boundary;
- `proposal_templates.removed_at IS NULL`.

There is no persisted completion flag, timer or scheduled job. Time passage
alone exposes a qualifying source. Completed is elapsed time, not proof of
attendance, success or a verified outcome. Source edit eligibility still ends
at start; cancellation eligibility still ends at event end.

`removed_at` is the private canonical TW02 seam. No client can write/reset it
or bypass the predicate with an exact ID. TW01 exposes no owner/staff removal
command. Reporting currently changes no source visibility on this base; PRs
#123/#125 were not imported. TW02 must compose any approved source restriction
with this predicate rather than invent client enforcement.

## Copied content, consistency and version

`private.proposal_template_reusable_content(source_id)` constructs an explicit
allow-list from the canonical source tables. It is owner-only and does not
authorize public access by itself. There is no synchronized content replica.
All three `update_own_proposal` overloads, Creator/Co-creator edits, skill
replacement, need create/update/close, cover set/change/clear and capacity edits
therefore affect the same identity immediately after commit. Closure excludes
a need; it says nothing about fulfillment. Draft-only saves remain private.

The projection adds no locks to source editing. Existing concrete Proposal
then shared Project then need/cover lock order remains owned by those domains;
blocking's sorted-profile locks remain before source locks. Publication holds
the source lock and adds only the new template/baseline records. Public reads
and all nested data helpers are STABLE and use one calling-statement MVCC
snapshot. Detail materializes its eligible content once, avoiding repeated
full-blueprint aggregation. There is no asynchronous worker or trigger recursion.

`private.proposal_template_content_version(payload)` produces an opaque
`tw01:<SHA-256>` of canonical JSONB. Arrays are ordered by immutable skill/need
UUID, and timestamps are excluded. Every copied field, controlled descriptor,
open need identity/text, capacity recommendation, duration and canonical cover
path participates. Identical content yields the same token, including after a
change and restoration. It is not chronological or an authorization token.
Operational logistics, occupancy, organizer-counting policy and live profile
name privacy do not participate.

TW03 revalidates eligibility and the requested token and copies the complete
allow-list in one database transaction/snapshot using existing source-domain
locks when a source mutation can overlap. Copied-content provenance is the
template/source identities and token. Attribution remains a separate live
privacy-sanitized read. A derived Project must be independent of later source
edits. TW01 stores no historical revisions or application count.

## Public RPCs and payload

| RPC                                                 | Contract                                                                                                                                                                                                                                      |
| --------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `list_public_proposal_templates`                    | Slim cards; 1–50 rows (default 20); descending immutable `(linked_at, template_id)` keyset; paired finite cursor; trimmed literal case-insensitive title/summary/description query, max 120 chars; OR skill filter, max 50 known non-null IDs |
| `get_public_proposal_template`                      | Zero-or-one eligible exact detail; copied fields, token and complete `resource_blueprint_count`                                                                                                                                               |
| `list_public_proposal_template_resource_blueprints` | Title/details and source need ID only; open needs; 1–50 rows (default 20), ascending need UUID cursor; requires detail's exact content token                                                                                                  |

Public reads are explicitly granted to `anon` and `authenticated`. Unknown,
cancelled, non-Completed and removed identities return zero rows, including
blueprints; no hidden counts/search metadata are exposed. Invalid input is
`22023`. An eligible blueprint read with a different version fails `PT409` and
requires refreshing detail and restarting pagination. Traverse from the null
need cursor until the detail's total is collected (or an empty terminal page),
checking that the collected count agrees; no default blueprint is silently
truncated. Source writes after canonical Completed remain prohibited.

Detail explicitly includes title/summary/description, controlled skill
IDs/descriptors and Required/Useful labels, registration-capacity recommendation,
duration in seconds (no old event instants), canonical source cover path,
template/source IDs, original Creator ID, live globally-public display name,
token and open-blueprint count. Cards omit description, duration, capacity,
blueprints and token. No language classification or rough/exact logistics is
invented. No participant name/photo, meeting data, workspace/Drive/video links,
join state, counts/badges, commitments, coverage, actual contributions, chat,
reports or staff evidence appears in the schema. Free text is not automatically
anonymized; TW02 owns reviewed unsafe-content reporting/removal.

Covers stay bound to the original source and its `cover-images` Storage policy.
No object ownership or bytes are copied. A template-specific read exposes no
cover after removal, but its independently public source can still authorize
that same image. Workshop returns no profile-photo metadata and does not alter
the existing source-context profile-photo authorization rules.

## Files and validation

- `20261003125831_source_linked_proposal_template_workshop.sql` owns identity,
  baseline, backfill, eligibility, projection, version and four RPCs.
- `110_proposal_template_workshop_structure.test.sql` audits RLS, grants, RPC
  signatures/hardening and retention; `111_..._access.test.sql` exercises domain
  and privacy behavior through canonical operations and synthetic fixtures.
- `scripts/verify-local-proposal-template-workshop.mjs` owns HTTP/Storage and
  overlapping-transaction tests. `npm run proposal:verify:local` includes it,
  so the hosted Database job exercises it without new unrelated CI triggers.
- `scripts/verify-local-proposal-template-backfill.mjs` rehearses a real local
  pre-TW01 upgrade and repeats the actual migration's backfill statement.
- `apps/web/src/types/database.generated.ts` contains generated public RPC
  contracts; private internals are excluded from that API schema.

Normal clean validation: `npm run db:reset`, `npm run db:lint`,
`npm run db:advisors`, `npm run db:test`, `npm run proposal:verify:local`,
relevant existing source/media/need/capacity/delegate verifiers, and
`npm run db:types`. Run the hosted scoped Validation at final head.
`npm run check:db` retains the complete manual database gate.

For an **isolated disposable local stack only**, upgrade rehearsal is:

```powershell
npx supabase db reset --local --version 20261002103310
node scripts/verify-local-proposal-template-backfill.mjs --before
npx supabase migration up --local
node scripts/verify-local-proposal-template-backfill.mjs --after
npm run db:reset
```

Direct `node` commands require the repository's `node_modules/.bin` on PATH so
the project-scoped status helper can resolve `supabase`. For parallel stacks,
use an uncommitted distinct project ID/ports in `config.toml`, and set
`MAILPIT_URL` to that stack's mailbox port. Restore the tracked configuration
before committing. Never use these fixture/reset commands against shared data.

## TW01 validation record

Base: `92d93ca5a455ab853df8bc34b66fd8d69f4fb341` (`origin/main` verified
before branching). Branch: `codex/tw01-source-linked-template-domain`.
The founder review scope is historical public Proposal content, the reusable
allow-list and the retained private Bozza capture/access contract. Keep the PR
draft and unmerged; TW02/TW03 must consume the reviewed contract.

Local checks on the completed implementation:

| Exact command                                                                                                                                                                                                                                                            | Result                                                                                        |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------- |
| `npx supabase db reset --local --version 20261002103310`, `node scripts/verify-local-proposal-template-backfill.mjs --before`, `npx supabase migration up --local`, `node scripts/verify-local-proposal-template-backfill.mjs --after`                                   | Real pre-TW01 upgrade and idempotent backfill passed                                          |
| `npm run db:reset`                                                                                                                                                                                                                                                       | Clean migration/seed replay passed in the isolated `planets-community-tw01` stack             |
| `npm run db:lint`                                                                                                                                                                                                                                                        | Passed; no schema errors                                                                      |
| `npm run db:advisors`                                                                                                                                                                                                                                                    | Passed; no security findings                                                                  |
| `npm run db:test`                                                                                                                                                                                                                                                        | Passed; 108 files, 3,403 assertions, including 91 new Workshop assertions                     |
| `npm run proposal:verify:local`                                                                                                                                                                                                                                          | Existing Proposal HTTP checks and new TW01 snapshot/publication/clock/Storage verifier passed |
| `npm run cover:verify:local`, `npm run profile:photo:viewer:verify:local`                                                                                                                                                                                                | Canonical media/source-trust regressions passed                                               |
| `npm run project:resource-needs:verify:local`, `npm run project:capacity:verify:local`, `npm run project:people:verify:local`, `npm run project:delegates:verify:local`                                                                                                  | Source resource/lifecycle, capacity/role races and delegate regressions passed                |
| `npm run participation:verify:local`, `npm run participation:browse:verify:local`, `npm run project:workspace:verify:local`                                                                                                                                              | Participation/privacy/operational regressions passed                                          |
| `npm run project:contribution-selections:verify:local`, `npm run project:membership-commitments:verify:local`, `npm run project:requirement-coverage:verify:local`, `npm run project:need-resurfacing:verify:local`, `npm run project:actual-contributions:verify:local` | Canonical requirement, selection, commitment and attribution regressions passed               |
| `npm run db:types`, `npm run typecheck --workspace @planets/web`                                                                                                                                                                                                         | Generated four public RPC contracts; web route/type checks passed                             |
| `npm run test:tooling`                                                                                                                                                                                                                                                   | Passed; 24 tests                                                                              |
| `npm run format:check:web`, `git diff --check`                                                                                                                                                                                                                           | Passed                                                                                        |

The one existing participation deletion assertion now checks `23503` without
requiring the old cleanup-trigger message: the retained-template FK can reject
the same deletion earlier, preserving the no-orphaning invariant. No existing
authorization/behavior assertion was removed. An existing photo timestamp
constraint test failed once locally and passed unchanged on rerun. A cumulative
test attempt after partial HTTP fixtures was discarded in favor of clean replay;
the successful database suite ran before the integration fixtures.

The local Node runtime was 24.13.0; hosted Validation uses the repository's
24.20.0 configuration. No dependency versions or CI trigger boundaries changed.
The standalone full `check:db` wrapper, unrelated local mobile/site suites,
device QA and production checks were not run. Final-head hosted results belong
to the PR's Validation checks, and skipped jobs must be identified as skipped.
No shared migration/reset, deployment, production backfill, provider/account
change or real demo-world regeneration was performed.

## TW02 reporting and private review

`proposal_template` is a dedicated report target, with a restrictive typed
`moderation_cases.target_proposal_template_id` foreign key. The server derives
immutable `template_source_proposal_id`, original Creator subject and
`template_report_content_version` from the eligible target. Source provenance
is separate from `project_context_id` and every Resource incident context;
caller-supplied context is rejected. No content excerpt or revision archive is
retained. The content token does not imply chronological history.

New reports use `private.is_proposal_template_publicly_usable` after taking
source/template locks. Published one-time + canonical Completed + source
visibility + no removal remain the single eligibility rule. An unavailable
or unknown target creates no case, report, evidence request, notification or
outbox event. Reporting is manual review, with no automatic consequence.

Only template reports permit the reporter to be the original Creator subject.
Every older self-report restriction remains. Authentication, complete profile,
category vocabulary and trimmed 10–4000-character explanation validation remain
canonical. Reporter/submission advisory locks serialize duplicate delivery.
Exact template retries recover the accepted receipt before checking current
availability, including after removal. Reusing a template key for a changed
target, kind, category, normalized explanation or context fails with `22023`.
Older report kinds retain their existing retry contract. Own-report history
still contains only that reporter's safe report/status projection; template
summaries say “Proposal template” without revealing a newly hidden source.

`get_moderation_case_template` requires the current moderator/admin role and
expected authenticated identity. It intentionally remains available after
removal or loss of source public availability. It returns template/source/
original-Creator IDs, report/current tokens and equality comparison, availability,
removal state, current published title/summary/description/skill descriptors,
capacity recommendation, duration and source-authorized cover path. It neither
reads Bozza nor grants staff any baseline, member/chat/logistics/workspace access.
`list_moderation_case_template_blueprints` separately pages open resource needs
(1–50, ascending need UUID) against the reviewed token; stale pages fail `PT409`.
The admin shows 20 needs per page with explicit continuation/version handling.

A cover is delivered only through ordinary source Storage authorization using
a 60-second signed URL. Hidden or denied source media shows “Source cover
unavailable”; there is no staff Storage override. Template removal does not
change lawful cover access through the source Proposal. Public template reads
return no rows and no cover path after removal, including blueprint calls with
an old otherwise-valid token.

## TW02 explicit removal and retention

`remove_moderation_case_template` rechecks the expected current staff actor,
binds case/template server-side and requires a UUID request, exact reviewed
content token and trimmed 10–4000-character protected reason. Forged pairs and
non-template cases fail. A changed current token fails `PT409`; staff must refresh
and review again. Case receipt/note/completion/reopen never enforce removal or
restoration. There is no Creator withdrawal, restoration or appeals command.

One transaction sets only `proposal_templates.removed_at`, inserts the protected
append-only `proposal_template_removal_actions` record and writes one generic
`moderation.template_removed` audit. The protected record owns actor, case,
template/source IDs, identity-scoped request, reviewed token, reason, effective
reference and time. The audit contains identifiers only, including the protected
reason-record reference, never the reason/explanation/published text/Bozza body.
The staff case view integrates the effective action as a typed separate timeline;
the existing strict case-event vocabulary is unchanged.

Exact accepted retries return the same receipt without another action/audit.
Incompatible inputs fail `22023`; current staff authorization is rechecked even
for retries and after waiting. Concurrent different staff/cases serialize to
one effective action. Later accepted requests receive `already_removed` and a
protected receipt referring to the original effective actor/time/action; their
reasons remain private, and they create no second consequence/audit. A partial
unique index also enforces one effective removal. Failure at any write rolls
back removal, reason and action together. An operator-written removal with no
matching effective record fails loudly if later passed to the staff command.

Template identity, original-Creator baseline and moderation evidence are retained
with restrictive foreign keys and no raw API-role privileges (including client
`service_role`). No physical deletion/cascade occurs. Source Proposal, source
participation/chat/cover, other templates and independent drafts/Projects stay
independent. Retention here follows existing protected moderation record rules;
this plan adds no legal retention period or account deletion policy.

## TW03 locking seam

Report/removal lock the source `public.proposals` row, then the
`private.proposal_templates` row; removal subsequently locks its case. Identity-
scoped request advisory locks precede those rows and have separate namespaces.
Existing source text/skill/capacity/need/cover commands already acquire the source
row before their dependent records. Review reads are stable statement snapshots.

TW03 must acquire source then template, recheck the same eligibility predicate
and current content token after any wait, and hold both locks through the atomic
independent-draft copy. Removal that wins first closes new use; a copy that wins
first creates an independent draft before removal proceeds. Never lock a case
before the source/template or use a token as authorization. No copy/apply RPC is
implemented by TW02.

## TW02 validation and integration

Base is exact TW01 head `342af7603f8f34b987d11073147cd5549d4b012c`.
Branch `codex/tw02-template-reporting-removal` is a draft stacked on
`codex/tw01-source-linked-template-domain` (#127), without importing the separate
moderation stack. After TW01 merges, rebase/retarget while preserving a TW02-only
diff. Founder review covers self-report exception, staff-only published access,
protected attribution/reason retention and template-only enforcement; TW01's
historical content/allow-list/private baseline review remains unresolved.

The supplied TW02 prompt is archived verbatim in
`history-implementations/PLANETS_TW02_template_reporting_and_removal.md`.
`112_template_moderation_structure.test.sql` checks the private schema/grants.
`node scripts/verify-local-template-moderation.mjs` exercises real authenticated
API reports/removals, concurrent deliveries/actions, stale content, protected
review, media boundaries and injected audit rollback. It runs through
`npm run moderation:verify:local`. The 93 reported TW02 API checks ran locally
at #129. Historical hosted run #37188652377 did **not** invoke that command;
its passing Database job did not cover those API checks. TW03 adds explicit
Database steps for this command and the new application verifier.

The upgrade rehearsal uses a distinct local stack:

```text
npx supabase db reset --local --version 20261003125831
node scripts/verify-local-template-moderation-upgrade.mjs --before
npx supabase migration up --local
node scripts/verify-local-template-moderation-upgrade.mjs --after
npm run db:reset
```

The verifier checkpoints synthetic legacy report/case/note/event records in the
OS temporary directory, verifies exact preservation and no fabricated removals,
then deletes the checkpoint. Both new verifiers reject non-loopback targets.
Standalone Node invocations require the repository `node_modules/.bin` on PATH;
set `MAILPIT_URL` for an isolated non-default mailbox port. Port/project overrides
are local and uncommitted; no shared migrations/resets/deployments are authorized.

### TW02 local validation record

All checks used the isolated `planets-community-tw02` Docker stack with local
API/database/Mailpit ports 54421/54422/54424. Overrides are excluded from Git.

| Exact command                                                                                                                                                                                                                            | Result                                                                                                                                                                                               |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `npm run db:reset`                                                                                                                                                                                                                       | Clean forward migration/seed replay passed                                                                                                                                                           |
| `npm run db:lint`, `npm run db:advisors`                                                                                                                                                                                                 | No schema errors or security findings                                                                                                                                                                |
| `npm run db:test`                                                                                                                                                                                                                        | 109 files, 3,417 assertions passed                                                                                                                                                                   |
| `npx supabase db reset --local --version 20261003125831`, `node scripts/verify-local-template-moderation-upgrade.mjs --before`, `npx supabase migration up --local`, `node scripts/verify-local-template-moderation-upgrade.mjs --after` | Actual TW01→TW02 upgrade preserved legacy case/report/note/events and fabricated no removal records                                                                                                  |
| `npx supabase db reset --local --version 20261002103310`, `node scripts/verify-local-proposal-template-backfill.mjs --before`, `npx supabase migration up --local`, `node scripts/verify-local-proposal-template-backfill.mjs --after`   | TW01 actual backfill and idempotency passed with TW02 applied                                                                                                                                        |
| `npm run moderation:verify:local`                                                                                                                                                                                                        | Existing moderation verifier and 93 TW02 authenticated API assertions passed, including queued content change/revocation, exact retries, different-case/staff concurrency and audit failure rollback |
| `npm run moderation:corroboration:verify:local`, `npm run moderation:counterstatement:verify:local`                                                                                                                                      | Existing private evidence workflows passed                                                                                                                                                           |
| `npm run proposal:verify:local`                                                                                                                                                                                                          | Existing Proposal regressions and embedded TW01 Workshop verifier passed                                                                                                                             |
| `npm run cover:verify:local`                                                                                                                                                                                                             | Existing canonical Storage/cover regression passed                                                                                                                                                   |
| `npm run check:web`                                                                                                                                                                                                                      | 24 tooling tests, 35 web files / 160 tests, lint, typecheck and production build passed                                                                                                              |
| `npm run format:check:web`                                                                                                                                                                                                               | Passed; supplied prompt excluded from formatting                                                                                                                                                     |
| `npm run check:mobile`                                                                                                                                                                                                                   | Localization generation, format check, Flutter analysis and 1,144 tests passed                                                                                                                       |
| `npm run db:types`                                                                                                                                                                                                                       | Regenerated the three new RPC contracts; committed type drift is checked before push and by hosted CI                                                                                                |

The first cumulative SQL run hit an existing join-request timestamp constraint
when Docker's clock moved backwards after restarting. The unchanged affected
file passed its focused rerun; the subsequent clean cumulative replay passed.
No existing database test or product timestamp behavior was altered. Initial
new test fixture/parser/DOM cleanup and React ref-render lint issues were repaired
before the passing checks above.

No Android/iOS platform build was run: the mobile change is a typed shared
report target, localized form copy and tests, with no plugin/platform/build
configuration change. Hosted Database/Web/Mobile validation is required at the
final PR head; the unchanged static Site is outside this change's scope.
No merge, shared environment migration/reset, deployment or sanctions-stack
import occurred.

## TW03 atomic template application

`create_proposal_draft_from_template` is authenticated-only. Inputs:
`p_expected_creator_profile_id uuid`, `p_template_id uuid`, `p_content_version
text` (exact preview), `p_client_request_id uuid`, `p_prefill_capacity boolean
DEFAULT true`. Explicit false leaves capacity unset; null is invalid. No content,
source Creator/need IDs, destination ID or publication input is accepted.

Its one-row receipt contains `request_id`, `proposal_id`, `template_id`,
`source_proposal_id`, `accepted_content_version`, `prefill_capacity`,
`capacity_recommendation` (accepted source value even when opted out),
`duration_seconds`, `accepted_at`, and `outcome` (`created` or `recovered`).
Duration is finite positive numeric seconds, including fractions (`7200.001`),
never generated dates. The corrected TW02 staff parser preserves that domain;
capacity and blueprint counts remain integer-validated.

| Destination state                                                     | Behavior                                                                                        |
| --------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| Title/summary/description                                             | Exact canonical published text through ordinary validation, never Bozza                         |
| Controlled skills                                                     | IDs and Required/Useful importance; live catalog semantics                                      |
| Needs                                                                 | All open blueprints, including >50, with fresh IDs and ordinary creation events; closed omitted |
| Capacity                                                              | Accepted recommendation by default; false or legacy null leaves it unset                        |
| Organizer counting/headcount                                          | Off; normal Creator social headcount one, registration-slot usage zero                          |
| Duration                                                              | Accepted recommendation in receipt, no schedule                                                 |
| Dates/timezone/country/locality/admin/rough/public location           | Unset                                                                                           |
| Exact meeting text/coordinates                                        | Unset, ordinary `participants` privacy default                                                  |
| Cover                                                                 | No inherited row/object; preview remains source-authorized                                      |
| People/memberships/requests/roles/offers/invitations                  | Applicant sole Creator; none inherited                                                          |
| Chat/workspace/attendance/operational history                         | None inherited                                                                                  |
| Listings/selections/commitments/coverage/actual contributions         | None inherited                                                                                  |
| Publication/cancellation/templates/baselines/reports/removal evidence | Fresh unpublished draft; none copied                                                            |

Ordinary `create_proposal_draft` initializes the Project anchor and validates
text/skills. Each `create_project_resource_need` preserves validation and its
identifier-only `project.resource_need_created` audit/outbox pair. No publication,
participant, matching or source-member notification is sent. Any write failure
rolls back the entire action. The private receipt records acceptance; there is
no additional application audit duplicating it.

### Private acceptance and retries

`private.proposal_template_applications` is append-only, keyed by applicant plus
request UUID, with a unique destination Proposal. It retains immutable IDs,
token, choice, recommendations and time, never source content/names/photos,
staff reasons or a revision archive. RLS has no policies; all API roles including
service role lack raw privileges. Restrictive references follow existing
retention conventions, without cascading source-to-derived deletion.

The canonical expected-identity gate runs before recovery and after waits. This
exact base has no suspension/private-access restriction beyond that gate; the
separate moderation stack is excluded. Later integrated restrictions must compose
before recovery. Blocking does not override this base's public source discovery
or ordinary draft creation. First creation additionally requires a complete
profile; exact accepted recovery does not require current completeness/photo or
source availability.

Same actor/key/template/token/choice returns the same acceptance without writes,
including after removal/source changes/cancellation or owner edits/publication.
Different accepted intent under the key is `22023`. Another actor using that UUID
has a separate scope. A fresh UUID may create another draft. Ambiguous delivery
must retry exact inputs/key; a stale preview requires refresh and deliberate
confirmation, not guessed copied content.

`get_own_proposal_template_application(p_expected_creator_profile_id,
p_client_request_id)` returns zero-or-one receipt (same fields except outcome).
Unknown keys are a legitimate empty result. Only the applying Creator can read
it: no source-Creator/staff exception or public graph/count. Existing
`get_own_proposal` and owner-need reads expose current edited content. This base
has no client discard/delete command; restrictive receipt FKs prohibit hard
deletion. The create RPC defensively returns `P0002` if an accepted destination
is unavailable, never recreating it.

| Error   | Meaning                                                                                             |
| ------- | --------------------------------------------------------------------------------------------------- |
| `42501` | Absent/wrong identity, unauthorized read, unknown/currently ineligible template                     |
| `55000` | Incomplete profile for first creation; ordinary draft gate                                          |
| `22023` | Missing/invalid bounded inputs, incompatible accepted key reuse, ordinary copied-content validation |
| `PT409` | Otherwise eligible content differs from preview; refresh and confirm                                |
| `P0002` | Accepted destination unavailable; no replacement/resurrection                                       |

Photo-free draft creation is allowed. Publication retains ordinary content,
schedule, capacity and applicant-photo gates. Own first publication creates a
new template and that Creator's genuine saved Bozza through TW01. Retry never
reopens or resets published content/lifecycle.

### Locks and one payload

Request advisory namespace `template.apply:<actor>:<request>` is distinct from
moderation/domain locks. Exact accepted recovery precedes source eligibility.
First use resolves source server-side, locks **source Proposal → template**,
matching removal's **source Proposal → template → case**, and holds both through
commit/rollback. After waiting it rechecks identity/profile and canonical
availability with `clock_timestamp()`, then captures and hashes one complete
reusable JSONB payload. Every destination write comes from that captured value,
not UI pages or later partial projections.

Copy-first commit leaves an independent draft, then removal closes new use.
Removal-first commit rejects queued first creation without writes. A source
blocker's changed content produces `PT409`; changed profile/availability is
rechecked. Token limitations remain TW01's: descriptors, source need IDs and
cover participate even though copied drafts retain skill IDs/fresh needs and
omit covers; equal restored content hashes identically. It is neither revision
chronology nor authorization; capacity choice does not alter its formula.

### Files, upgrade and validation

`20261004145334_template_to_draft_creation.sql` owns the table/two RPCs; no
historical applications are backfilled. `113_template_application_structure`
audits grants/RLS/hardening/retention. `scripts/verify-local-template-application.mjs`
(`npm run template:apply:verify:local`) runs real OTP/API, controlled overlapping
transactions and need/receipt/outbox failure injection. Barriers observe
`pg_blocking_pids`; sleeps are only polling intervals. A local nontransactional
sequence proves two needs existed before the third failed and all rolled back.

Real upgrade rehearsal, only on an isolated disposable loopback stack:

```text
supabase db reset --local --version 20261003191351
npm run moderation:verify:local
node scripts/verify-local-template-application-upgrade.mjs --before
supabase migration up --local
node scripts/verify-local-template-application-upgrade.mjs --after
npm run db:reset
```

The populated TW02 fixture includes ordinary drafts, baselines, reports and
attributed removals. Canonical row counts/SHA-256 digests for all **72** existing
public/private tables survived unchanged, with zero fabricated applications.
Checkpoints stay in OS temporary storage. Standalone Node commands require
`node_modules/.bin` on PATH; guards enforce loopback API/database/mailbox URLs
and synthetic `.invalid` identities.

TW03 adds explicit Database CI steps for `moderation:verify:local` (TW02's 93
API assertions) and `template:apply:verify:local`. Historical #129 run
#37188652377 did not execute the former; its 93 API results were local.
The unchanged classifier runs Web/Mobile/Site too for workflow/root-package
changes. Final-head hosted execution/counts belong to the TW03 PR logs.

Selected base: `b778445550e49c08395e67c8852d649ead333821` (#129); draft target
`codex/tw02-template-reporting-removal`. Founder review covers atomic copying,
private provenance, retries and removal concurrency. Predecessor integration
and later main/#128 integration remain pending: read then-current canonical
invite admission/retry/capacity/membership-origin rules and verify no inherited
source invitations. DRAFT01/TW04/SIM01/SIM02/TW05 and native-device QA are deferred.
No merge/shared migration/reset/deployment occurred. The supplied TW03 prompt
is archived byte-for-byte in `history-implementations`.

TW03 local validation record: clean replay/lint/security advisors passed;
pgTAP passed **110 files / 3,428 assertions**. TW01 Proposal/Workshop, TW02
moderation (**93**), resource-needs, capacity, cover, corroboration and
counterstatement verifiers passed. TW03's final assertion count is printed by
its command and recorded in the PR. `check:web` passed **24 tooling + 162 web
tests**, lint/types/build; `check:mobile` passed **1,144 tests**, localization,
format and analysis; `check:site` passed **34 UI + 19 worker tests**, lint/types,
build and deployment dry run. Generated types, formatting and diff checks are
required before push. The all-in-one `check:db` wrapper and native device builds
were not run; individual affected commands and hosted validation are the evidence.
