# Registered-group Project attribution (GRP03C)

The human Creator can deliberately publish a new Idea, Defined Project or
Tavolo for one registered group. Personal publication remains the default.
Current group Creators and Co-creators can represent an eligible published,
nonsuppressed group with a live accountable identity. Membership is independent.
Co-organizers, members and moderation staff gain no representation grant.

This is publication provenance. It changes no Project Creator, delegate,
participation, capacity, chat, notification or location rule. It is no legal or
identity verification. Group territory is never a meeting-location prefill.
Official starter organization provenance remains a separate catalog concept.

## Private write contract

`public.projects` remains a private identity anchor despite its schema name.
Its nullable `attributed_group_id`, monotone `attribution_version`, assignment
actor/time and first-publication actor/time hold the association. Raw UUID
provenance has no new account/group deletion blocker or history cascade.
Existing published Projects are backfilled as permanently personal, using their
original publication instant. No content, lifecycle or authority is rewritten.

Authenticated `get_own_project_group` is real-Creator-only. `set_project_group`
takes expected actor, Project, revision, nullable group and request UUID. New or
changed group choices require current representation; clearing a draft remains
available after role loss. Ordinary content saves do not reauthorize an unchanged
group choice. Published association and first-publication ordering are immutable.

`create_group_editor_proposal_draft`,
`create_group_editor_recurring_activity_draft` and
`create_group_proposal_draft_from_template` add atomic initial binding at the
existing idempotent seams. Legacy signatures and recovery commands remain.
Wrappers use the same actor/key advisory namespace as their legacy seam. Their
private append-only receipt binds the complete typed creation intent and group.
Exact retries recover the accepted destination; changing accepted intent fails.
A legacy request already accepted without this intent cannot be rebound by the
wrapper. Neither community nor official template reuse inherits source grouping.

Mobile keeps creation actor/key/content/group immutable while delivery is
uncertain. The confirmed ID is bound before subsequent association, cover or
reread awaits. Later edits update that same ID. A definitive group authorization
rejection before atomic creation has no receipt; only the structured
`group_representation_unavailable` post-lock denial permits a new intent. Generic
identity/permission failures retain the original key. Template previews share
the explicit personal/group choice and freeze it while an application is pending.
The rejected choice can be cleared before a new personal attempt. Transport/unknown outcomes retain their
request. Association writes keep their own key/revision/intent until exact retry
and fresh private reread resolve them. A changed current selection requires an
explicit Reload group choice; no receipt is a current representation grant.

Content, association, cover and location receipts are separate stages after
creation. An association/publication failure does not acknowledge the form as
saved or silently publish personally. Content may already be retained; the
editor says so, keeps its bound ID and permits reconciliation. A group denial
is distinct from losing Project structural authority. Opening Create or choosing
a group alone creates nothing; group selection alone is not meaningful content
for scratch draft departure. Template creation remains an explicit action.

## First-publication serialization

`publish_project_with_group` compares the confirmed group/revision under source
and Project locks before invoking the ordinary Idea/Defined/Tavolo publisher.
All legacy publishers and direct source transitions additionally share AFTER
source guards. Triggers run after source registration on trusted inserts and
freeze once; later edits, promotion, pause/resume/end or cancellation retain
publication provenance. Failed validation rolls back source/template/outbox work.
Already-published source edits return before acquiring new attribution locks;
only the first publication performs the group/identity/photo decision.

Lock order is source, Project anchor, group, sorted Auth identities, then
profiles (and the human publication photo). All group content, archive,
suppression and role commands hold the same group row. Eligibility, actor and
accountability are read again after waits. Identity and photo locks serialize
deletion/incompleteness with publication. This structural operation acquires no
new social block-pair or relationship lock and grants no Project authority.

## Public projections and clients

`get_public_project_groups` accepts at most 50 UUIDs and returns only public
Project associations. Eligible groups expose Project/group UUID, current name,
kind and state. An unavailable group returns exactly Project UUID and neutral
state: no hidden group UUID/name or private draft selection. Restore brings the
current badge back on a fresh read. Public Project access remains its own rule.

`list_public_group_projects` requires a currently public group and a bounded
1–50 page with paired publication-time/UUID cursor. The partial anchor index
orders immutable first publication then UUID. Rows contain only public Project
ID, kind/definition phase/lifecycle, title, summary and publication cursor. It
uses canonical source public-detail eligibility, including public Ideas and
public Tavolo terminal states. It has no planning, meeting, participant,
manager, history or inferred count fields. An unavailable group fails explicitly.

Flutter concrete gateways batch badges once per public page. Existing recurring
schedule enrichment does not add per-card attribution reads. Draft hydration
loads the private binding only for the Creator draft. Group profiles show a
bounded public Project/Tavolo feed and eligible representatives can enter the
existing scratch/template chooser with deliberate preselection. All ordinary
departure, cover/location, similar-Project, template, policy and photo flows stay.

Web public cards/details and invitation/share/confirmation cards use the same
public projection. The existing public group landing gains the bounded feed.
Web authoring, group administration, directory parity and the static site are
outside this feature. Read failures remain failures with explicit retry; stale
group/page responses cannot replace a newly selected group's state.

## Verification and rollout

`group:projects:verify:local` uses fictional genuine local Auth/OTP sessions and
PostgREST, including independently held transactions with observed lock waits.
`group:projects:upgrade:verify:local` requires CI or `PLANETS_DISPOSABLE_QA=1`,
resets only its explicitly selected disposable stack, populates predecessor
Project/group/template/chat histories and compares every predecessor column.
Both run in `check:db` and the existing Database CI job. pgTAP checks the private
boundary, grants, fixed definer paths, immutable receipts, triggers and bounds.
Feature unit/widget tests cover command recovery and narrow EN/IT layouts.

For the opt-in Android journey, run
`apps/mobile/integration_test/prepare_group_projects_smoke.mjs <OS-temp-defines.json>`
from the selected disposable stack with `PLANETS_DISPOSABLE_QA=1` and its
`MAILPIT_URL`. Keep the resulting local sessions outside Git/logs. Reverse that
stack's API port on the selected emulator, then from `apps/mobile` run:

```powershell
flutter drive -d <owned-emulator> --driver=test_driver/groups_screenshots.dart --target=integration_test/group_projects_smoke_test.dart --dart-define-from-file=<OS-temp-defines.json>
```

Use a fresh fixture per complete run. The test uses genuine OTP subjects and
canonical policy/photo records through a fixture-only Auth/policy adapter; it
deliberately drops one accepted scratch creation reply. It checks the template
chooser, no empty draft on opening Create, retained selection, first publication,
public feed/navigation and a separately approved Project membership with no
group membership or role. It does not test gallery/crop UI or email entry on the
emulator. Screenshots are written to `apps/mobile/build/groups-screenshots`.

For the anonymous browser journey, build/start Next against the same loopback
stack, set `GRP03C_WEB_URL` and `PLANETS_PLAYWRIGHT_PATH` to an installed Playwright
runtime, and run
`node apps/web/test-support/group-project-browser-journey.mjs <defines.json> <artifacts>`.
It reads only public group/Project data and checks 390px/320px navigation,
ordinary share, signed-out confirmation, runtime errors and horizontal overflow.
It performs no admissions or other product writes. The shared badge/feed use
ordinary public links so the static invitation bundle imports no Next runtime.

Recorded screenshots and validation qualifications live in
[GRP03C evidence](evidence/grp03c/README.md).

Shared/hosted migration application, native host/domain activation, physical
Android, TalkBack, iOS and store/provider work are separate from code merge.
No hosted deployment or real organization data is created by this change.
