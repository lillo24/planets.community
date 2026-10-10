# IDEA01A: public Ideas and forward planning

The integration against main #203 (LOCATION02) adds
`20261010173000_idea_location_privacy_integration.sql`: the strict legacy detail
still excludes Ideas, and both detail versions expose only a deliberately public
verified place label, never arrival directions. LOCATION02's scoped receipt,
visibility and protected directions contracts are retained. No stored data is
rewritten. IDEA01B skips map preview reads for Ideas and uses the updated editor.

## Scope and integration gate

This backend foundation is based on main
`9a48568e6212ef014d874a237afadda02b3112e6` (LOCATION01 and its staging handoff).
Migration `20261010112941_public_idea_definition_phase.sql` adds the canonical
domain and opt-in API. It is delivered as a **draft PR for domain/security/API
review**. IDEA01B starts only from the approved exact predecessor or its merged
commit. No staging/hosted migration, synthetic hosted write, provider activation,
public-client deployment or Play release is included. The chat checklist remains
a later independent plan.

## Stored phase and lifecycle

`proposals.definition_phase` is server owned, `idea | defined`, independent of
`draft | published | cancelled`. A constant `defined` default classifies existing
rows without rewriting their content or dates. Private drafts remain private;
their stored default phase does not imply publication. Only deliberate Idea
publication changes draft/defined to published/idea. Only explicit promotion
changes published/idea to published/defined. There is no reverse transition RPC.

A published Idea's optional dates are tentative: `derived_status=null`, even
when its dates are in the past. Operational freezes/completion apply only after
promotion. Cancellation still closes collaboration/discovery; a cancelled Idea
retains phase `idea` and has lifecycle `cancelled`, not Completed. A Defined
Project keeps the existing time-derived upcoming/happening/just-finished/completed
contract, including start–end intervals spanning multiple days.

## Authoring, capacity and promotion

Use the existing `create_proposal_draft` and `update_own_proposal` RPCs. Select the
current explicit overload with `p_registration_capacity` (nullable) and
`p_count_organizers_toward_capacity` (boolean); do not mix that overload with the
older `p_people_capacity` argument. Title and short explanation use the existing
normalization and bounds. Deliberate Idea publication requires a readable title
(2–100 characters) and explanation (10–240 characters), each containing at least
one alphanumeric character. The 10-character minimum is a documented validation
choice for the plan's meaningful explanation. Description, date pair, timezone,
country/city/region/label, skills, exact instructions and capacity can be absent.
Any supplied fields retain canonical bounds. Tentative timestamps must be finite
and ordered if both exist; a supplied timezone must be recognized by PostgreSQL's
IANA catalog. No city, date, capacity, timezone or coordinates are fabricated.

`publish_proposal_idea(p_expected_creator_profile_id, p_proposal_id) -> uuid`
is authenticated, original-Creator-only, complete-profile/current-photo gated,
and idempotent while already published as Idea. Ordinary `publish_proposal`
continues to publish complete Defined drafts and rejects an Idea (`55000`);
saving/editing never implicitly publishes or promotes.

Null capacity means **undecided**, using the existing nullable canonical capacity
branch. It admits participants without a finite cap; it is not zero or a hidden
default. A finite capacity continues to use the ordinary participant/organizer
accounting option, floor and locks. Configuring capacity below current usage or
overbooking a finite cap fails. An Idea can explicitly clear capacity; Defined,
Tavoli and Scambio rules are unchanged. Read canonical capacity snapshots using
`list_public_project_capacity_statuses` and show undecided when null.

`get_proposal_promotion_requirements(p_expected_profile_id,p_proposal_id) -> jsonb`
is an advisory authenticated Creator/current Co-creator preview:

```json
{
  "proposal_id": "<same-project-id>",
  "definition_phase": "idea",
  "missing_fields": ["description", "registration_capacity"],
  "can_promote": false
}
```

Possible missing keys are `title`, `summary`, `description`, `starts_at`,
`ends_at`, `event_timezone`, `country_code`, `locality`, `public_location_label`,
`registration_capacity`, `creator_profile`, `creator_photo`, `organizer_photo`.
Do not display raw backend keys: IDEA01B owns localized labels. Starts must be
finite and strictly future **at promotion**, ends finite and later than starts,
with valid timezone, public city/country/label, content and finite capacity at
least current usage. Exact venue/instructions and skills remain optional, as in
LOCATION01. Original Creator trust/photo and the acting organizer's current
profile/photo are checked; Co-organizers and revoked Co-creators cannot promote.

`promote_proposal_idea(p_expected_profile_id,p_proposal_id) -> uuid` revalidates
under the concrete Proposal then shared Project row locks, including current
authority after locking. It changes only phase: ID, original `published_at`,
memberships, chat/messages, invitation generations/receipts, commitments and
template identity/baseline remain. Concurrent edits, capacity/admissions,
invitations, role revocation and cancellation use the same canonical lock owners.
A successful retry on an already Defined Project returns its ID without another
audit/outbox event. A cancelled Project cannot promote. Missing requirements fail
atomically with `PT422` and JSON details `{"missing_fields":[...]}`; identity/role
failures use `42501`, lifecycle conflicts `55000`, malformed fields/filters
`22023`. Existing admission conflicts still use `PT409`.

## Versioned read contract for IDEA01B

Every new RPC has explicit EXECUTE grants and an empty definer search path.
No client table-write grant or RLS policy is broadened.

| RPC                                                                                                       | Access and result                                                                                                              |
| --------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| `get_public_proposal_v2(p_proposal_id)`                                                                   | Anonymous/authenticated, published-only, zero/one row; existing safe detail allowlist plus `definition_phase`.                 |
| `list_public_proposals_v2(...)`                                                                           | Anonymous/authenticated, bounded publication-keyset list below.                                                                |
| `get_own_proposal_v2(p_expected_creator_profile_id,p_proposal_id)`                                        | Creator/current Co-creator detail, including protected edit fields; only original Creator may read a private draft.            |
| `list_own_proposals_v2(p_expected_creator_profile_id)`                                                    | Original Creator's own drafts/published/cancelled rows, existing ordering.                                                     |
| `list_own_pending_requested_proposals_v2(p_expected_requester_profile_id,p_locality,p_skill_ids,p_query)` | Current actor's pending requests only, existing request-created ordering and maximum 200; Ideas bypass the event end filter.   |
| `list_own_delegated_projects_v2(p_expected_profile_id)`                                                   | Current delegates only, existing safe fields; published Ideas use `project_status=in_definition`, cancelled remains cancelled. |

The v2 public/own/requested Proposal rows discriminate on `definition_phase`.
Dates, timezone, city/country/region/label and derived status are nullable; public
Idea description may also be absent. Cover and public creator name retain their
existing nullable/visibility rules. Private draft text and publication/cancellation
timestamps may be absent. `skills` remains the existing JSON array. The repository
type generator corrects pg-meta's missing RETURNS TABLE nullability for these
opt-in readers; legacy event types are unchanged. Flutter must validate the same
contract explicitly when IDEA01B opts in.

Public List arguments (all optional):

| Argument                               | Contract                                                                                                                     |
| -------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `p_limit`                              | Default 20, integer 1–50.                                                                                                    |
| `p_cursor_published_at`, `p_cursor_id` | Both absent for first page, otherwise both supplied from the last returned row.                                              |
| `p_reference_time`                     | Default server statement time; finite and not future. Forward the first row's returned `reference_time` on subsequent pages. |
| `p_definition_phase`                   | Null for All, or exactly `idea` / `defined`.                                                                                 |
| `p_locality`                           | Trimmed case-insensitive equality, maximum 120 characters; absent city matches only an unfiltered List.                      |
| `p_skill_ids`                          | At most 100 non-null UUIDs, existing OR matching; empty means no skill filter.                                               |
| `p_query`                              | Trimmed case-insensitive literal substring of title/summary/description, maximum 120 characters.                             |

Return fields add `definition_phase`, immutable `published_at` and echoed
`reference_time` to the existing public List projection. Order is
`(published_at,id) DESC`, independent of tentative/changed schedules. Cursor UUID
and timestamp must identify a once-published published/cancelled row no newer than
the reference; malformed/forged anchors fail. A cancelled anchor remains usable.
New publications after the reference are excluded. Promotion does not reorder.
Authorization, lifecycle, phase/keyword/city/skill filters and the old Defined
24-hour end cutoff are **live**, not a durable database snapshot: rows that stop
matching may disappear between pages. Reset pagination on filter changes. An
empty first page needs no continuation. Requested-first is a separate authorized
section; deduplicate its IDs against the general List as existing clients do.

## Compatibility, privacy and dependent domain

Legacy `get_public_proposal`, `list_public_proposals`, `get_own_proposal`,
`list_own_proposals`, `list_own_pending_requested_proposals` and
`list_own_delegated_projects` exclude Idea rows, retaining their exact result
shapes, grants, schedule ordering/cursors and Defined behavior. An installed old
build's Idea deep link therefore gets its existing zero-row unavailable state,
never a null event payload. IDEA01B must switch public web detail/share fallback
and new app readers together. Until that UI exists, an Idea is API-discoverable
only; this backend slice is not an end-user release. Generic participation,
messages and invitations do not serialize mandatory event schedules and keep
their existing authorized contracts.

Ideas are List-discoverable without geography. Existing v1 radius/bounds Map and
SIM01 event matching deliberately exclude **all Ideas**, even with tentative
future dates/verified public geometry; promotion enables their normal Defined
behavior. No new Map API or provider activation is introduced. IDEA01B can retain
List-only Ideas; any later Idea Map opt-in must preserve public verified geometry,
precision/credits and privacy. Never derive a marker/distance from private exact
coordinates or an absent city.

Exact text/coordinates remain in the protected meeting row. The LOCATION01 public
text opt-in and content-aware restricted flag are preserved. Nullable meeting
content is a successful absence for authorized participants, not access granted
to unrelated users. Photo/trust, moderation/blocking, leave/removal, chat history
cutoffs and retry receipts remain canonical.

Phase-aware locks/predicates keep joining, manager links/delegates, chat, cover
editing, location editing, resource needs/matches, commitments and live coverage
open while an Idea is published, independent of tentative dates. Actual
contributions/completion readers and reusable templates reject Ideas. Current
notification workers do not implement calendar reminders or consume publication
as a confirmed event reminder; this slice adds no reminder worker. Existing
collaboration notifications remain tied to real actions. Publication emits one
`proposal.published` audit/outbox event (Idea payload includes phase); promotion
emits one `proposal.promoted` event with IDs/phase, no private logistics.

TW01's first-publication trigger is deliberately retained: Idea publication
creates **one private template identity** and captures the last genuinely saved
pre-publication text/skills baseline. That baseline has no operational date/city
requirements and can contain null optional text. Promotion does not replace it.
This preserves original editing lineage; current reusable content is still
derived from the live source only after explicit promotion and genuine Defined
completion, with existing moderation/source visibility gates.

## Reproduction and review evidence

Use only an explicitly disposable checkout/stack. `npm run check:db` resets its
selected stack, including populated predecessor upgrade rehearsals. This task
uses temporary, uncommitted project `planets-idea01a-qa`, API 59321, DB 59322,
Mailpit 59324, `PLANETS_DISPOSABLE_QA=1` and
`MAILPIT_URL=http://127.0.0.1:59324`. Normal repository config stays unchanged.

- `126_public_idea_domain.test.sql`: 69 transactional assertions for draft/public
  phase, nullable minimum publication, trust/identity, legacy readers, normal
  join/chat, optional invalid fields, capacity, promotion/history and templates.
- `127_public_idea_discovery.test.sql`: 21 assertions for tied publication
  pagination, locality/skills/literal search, bounds/forged cursors, promotion,
  cancelled cursor anchors, new-publication cutoff and Map/SIM01 compatibility.
- `verify-local-public-ideas.mjs`, composed by `proposal:verify:local`: real
  Mailpit OTP/JWT synthetic clients, normal request/admission/chat, privacy,
  each missing promotion field, Co-creator versus Co-organizer/revoked authority,
  current Creator photo, parallel promotion/invite, capacity and cancellation
  races, receipt recovery and former-member write/meeting denials.
- Type-correction tooling tests preserve legacy strict results and fail on drift.

The PR records completed full database/web/CI results separately from these
focused checks. This evidence is API/local automation, not rendered mobile/web,
physical-phone or hosted proof. Review the cross-layer status/eligibility changes,
10-character explanation minimum, publication-based All ordering, all-Ideas
Map exclusion and first-publication template baseline before approving IDEA01B.

Deployment order after review is controlled migration first, then compatible
versioned web/app UI; enable Idea publication in clients only after their own
integration validation. This plan authorizes none of those external actions.
