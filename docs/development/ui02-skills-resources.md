# UI02: centralized Project skills and materials

Base: UI01 merged at `6f558233f45d4a669148aa3f9c208aa22253569e`.
Plans: `PLANETS_UI02_manage_skills_resources.md` and UI01 predecessor.

Manage Project's Organization group orders Checklist, Manage skills & resources,
Shared workspace for one-time Projects. Creator and Co-creator structural actors
can enter. Tavoli expose only the existing Creator resources destination.
Co-organizers, participants and anonymous actors gain no new actions.

The combined screen reuses the canonical taxonomy/Required–Useful selector and
original materials/history/add/edit/close/matching presentation and controllers.
Co-creators receive public open needs and an ownership explanation. Materials
failure does not disable skills. Foreground refresh rechecks roles and preserves
unsaved skills; explicit reload asks before discarding. Navigation uses the
existing departure coordinator's keep/discard/save guard. Failed saves retain
edits; an acknowledged save with failed reread blocks duplicate submission until
verification. Identity replacement clears state and ignores late completions.

Create and draft editing retain skills and the after-save resource link.
Published structurally editable Defined and Idea forms omit duplicate editors.
Read-only forms retain their disabled content display. Ideas remain editable
without official logistics. Existing resource lifecycle semantics are unchanged.

## Canonical API and security review

Migration `20261012104716_proposal_skills_management.sql` adds only
`update_proposal_skills(expected_actor, proposal, expected_skills, skill_ids,
skill_importances) → proposal UUID`. There are no new tables or privileges.
The JSON object maps skill UUID strings to `required`/`useful`, including `{}`
for an empty collection. Both replacement arrays must be non-null, matching,
unique, catalog-backed and valid. Empty arrays deliberately clear skills.

The security-definer function has an empty search path, qualified references,
explicit authenticated-only execute, expected-identity validation and canonical
Creator/Co-creator authority. Drafts stay original-Creator-only. Missing/denied
Projects return `42501`; started/terminal records `55000`; stale skill collection
`40001`; malformed replacement `22023`. UI must handle these as failures.
Concrete Proposal `FOR UPDATE` precedes Project registry `FOR UPDATE`, matching
activity-before-registry ownership and serializing revocation/structural writes.
Lifecycle uses wall-clock time after waiting. No shared-lock upgrade is used.
Only skill rows and Proposal updated time change. Existing `proposal.updated`
audit/outbox events preserve downstream matching/notification processing.

The existing 16-argument `update_own_proposal` core contract adds one explicit
opt-in: **both skill arrays NULL preserve the locked current skill collection**.
One NULL remains invalid; empty arrays retain their original clear behavior.
Capacity overloads delegate to that core unchanged. The published Flutter form
uses NULL/NULL, so an older open details form cannot revert a skills save that
commits first. Draft/full clients still replace skills explicitly.
Old clients explicitly sending skill arrays retain their original semantics;
this is not a general compare-and-swap upgrade for old full-content editors.

Review checks: identity before lookup, authorization/lifecycle under activity
locks, no direct client writes/service-role grant, original resource ownership,
original detail/capacity/private meeting validation, narrow audit payload, both
save orders, expected-collection conflicts and revocation during lock waits.
Hosted schema activation remains a separate owner action; deploy this migration before using
the updated client against any shared environment.

## Validation and evidence

- `npm run check:mobile`: formatting, analyzer and full Flutter suite.
- `npm run check:web`: generated type consumers, tests, lint, production build.
- `node --check scripts/verify-local-proposal-skills.mjs`.
- Disposable CI: canonical migration replay, db lint/advisors, pgTAP including
  `135_proposal_skills_management.test.sql`, `proposal:verify:local` (real queued
  writes and JWT gates), generated type parity and existing domain regressions.
- `proposal_skills_controller_test.dart`: actor/project isolation, authorization,
  failures, stale collection, foreground/role changes and post-ack reread failure.
- `proposal_skills_gateway_test.dart`: exact narrow payload and explicit NULL/NULL.
- `proposal_needs_screen_test.dart`: both managers, public-only Co-creator materials,
  importance persistence, departure outcomes, failure isolation, Idea/read-only,
  EN/IT, themes, 320/800dp, 1x/2x text. Existing materials/matching and draft suites
  remain regression coverage.
- Project hub and editor tests cover row order/role/kind and creation/draft versus
  published selector ownership, plus published details preserving server skills.

Local database execution was unavailable: Docker Desktop fails at its inference
socket initialization. No Docker data reset or hosted database action was used.
CI's isolated database results are separate from local validation.
Physical Android/iOS, manual TalkBack/voice, live authenticated hosted-provider
QA and hosted migration activation were not performed.

See [rendered evidence](evidence/ui02/README.md) for real Flutter frames and the
reproduction commands. A task-owned synthetic Chrome harness supplies compile
and hot-reload smoke evidence; it makes no hosted product/provider requests.

## Changed files

The PR diff is the authoritative complete manifest. Ownership is limited to
Proposal gateway/controller/editor/new skills screen, resource screen composition
and route helper, Manage Project/router/EN–IT copy, test fakes and focused tests,
the additive migration/pgTAP/local verifier, generated database types and these
nearest source maps/evidence. Integration-smoke gateway overrides only forward
the new optional preserve-skills argument; their behavior is unchanged.
