# Source-linked Template Workshop (TW01)

Implemented on the TW01 branch, pending founder review of the draft PR. This
document owns the backend contract for TW02 removal/reporting and TW03 copying.
The implementation adds no mobile/web Workshop surface, application RPC or
production data. The supplied plan is retained unchanged in
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
shared by catalog, exact detail and blueprints. Future application must use it
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

TW03 must revalidate eligibility and the requested token and copy the complete
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
