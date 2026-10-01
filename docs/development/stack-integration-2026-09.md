# September 2026 stack integration

This record describes the `STACK-INTEGRATION-02` candidate assembled for founder
review. It is not evidence that the candidate has been merged to `main`.

## Snapshot and scope

- Starting `main`: `06e983bb230a7a48514095fe407250ad6d38c148`
- Candidate branch: `codex/stack-integration-main-candidate`
- Included descendant tips, in integration order:
  1. PR #115, Resource/Profile/Media/Demo —
     `32fd20e87ddf0c0395dcf9f06e3c4b1c9f745eef`
  2. PR #118, Moderation/Blocking —
     `da280adc9531a70fc8d6e5a181dcb7a035bd1665`
  3. PR #119, Delegates/Co-creators/Capacity —
     `9e056df0eaa997e8cbec4deee1ce6c8a3b225c63`
  4. PR #117, Shared Project workspace —
     `aec97fb752cfe872691016936bdb33b912471307`
  5. PR #103, Italian localization and Settings —
     `267560e9f97023104d498867e7aa2ffe64bec987`
- Explicitly excluded: PR #28, MLS E2EE architecture prototype,
  `01646cc6d5c0635c2a4f74e9ea39c08c5ee5365a`, because it remains deferred
  research/prototype work.

All other open PRs in the verified snapshot were ancestors of one of the five
included tips. No open PR was classified as unknown or superseded. Existing PRs,
branches, and their targets were left unchanged.

## Reconciliation work

The conflicts were resolved as a cumulative product rather than choosing one
branch wholesale:

- Mobile navigation retains Resource, Settings/language, blocking, delegates,
  Co-creator management, workspace, notifications, messages, and existing
  profile/auth return-intent routes.
- Participation and Project reads retain blocking/moderation, capacity/fullness,
  profile/cover trust, contribution, delegate, and Co-creator behavior.
- Project chat retains mixed human/system history, Realtime, Needs attention and
  tools placement, workspace access, report/block actions, former-member
  read-only behavior, and identity protection.
- Package manifests contain the dependencies required by all included stacks.
  No MLS/OpenMLS dependency is present.
- Generated database types were regenerated from the cumulative schema rather
  than manually merged.
- English and Italian catalogs contain the same 1,230 message keys, with matching
  placeholder structures. High-risk participation, Resource, safety, delegate,
  capacity, and workspace copy was reviewed after catalog reconciliation.
- Architecture, database, and roadmap documentation now distinguish behavior on
  `main`, behavior only in this candidate, deferred work, and work not started.

No incompatible founder-owned product semantics were found during integration.

## Database ordering and tests

The final inventory has 55 unique migration timestamps and 104 unique pgTAP
numeric prefixes. Parallel-branch test collisions were resolved as follows:

- Resource matching and saved-search suites: `058`–`065` to `083`–`090`.
- Delegate and Co-creator suites: `063`–`069` to `091`–`097`.
- Capacity suites: `070`–`071` to `098`–`099`.
- Workspace suites: `070`–`071` to `100`–`101`.
- Cover suites: `074`–`075` to `102`–`103`.
- Manager-blocking convergence coverage was added as `104`–`105`.
- Founder-QA mobile stabilization coverage was added as `106`–`107`.

Migration replay found and fixed two cumulative production-schema regressions:

- `20260928064452_cover_media_domain_foundation.sql` now preserves the `p_query`
  search argument in Proposal list functions.
- `20260928075820_project_cocreator_domain_authority.sql` now preserves cover
  fields in owner Proposal and Tavolo reads.

Historical and parallel-branch tests were adapted to the cumulative schema:

- the Resource listing structure suite now recognizes the later accepted request
  table instead of asserting that it is absent;
- access suites seed the profile-photo and capacity prerequisites introduced by
  later accepted features;
- cover structure assertions use the cumulative Proposal signatures;
- Project resource, contribution-selection, membership-commitment, resurfacing,
  and actual-contribution fixtures use complete, relative meeting windows;
- portable JSON key counting replaces unavailable `jsonb_object_length` calls;
- verifier-owned data is isolated from prior runs, notification projectors drain
  every pending batch, and saved-search rollout events are acknowledged before
  verifier-owned assertions;
- the Project resource-needs race verifier wraps Supabase thenables so the
  cancellation operation executes exactly once;
- repeated local OTP requests respect the configured resend interval.

The cumulative database lint is clean; no warning suppression was added.

## Founder-review manager-blocking correction

Founder review found one cumulative production bug at exact pre-fix candidate
head `3d822dc8318a58766c90ef196a50dafaa54c06df`: Project blocking had been
integrated before delegated-manager authority and therefore still enforced
Creator-only Project interaction checks; manager-specific acceptance and
pending-request closure bypassed the intended current-manager block barrier.

The unmerged cumulative blocking migration now owns one deterministic manager
set (immutable Creator plus active Co-creators and Co-organizers, excluding
revoked delegates). Request creation and both Creator/delegated-manager
acceptance boundaries snapshot that set, acquire all requester/manager advisory
pair locks in global canonical order, lock the Project, and revalidate manager
membership and block state before mutation. Blocking cleanup reuses the same
manager predicate, so manager-side blocks reject pending requests and
requester-side blocks withdraw them without rewriting terminal history.

Focused pgTAP files `104` and `105` cover manager-set structure, privileges,
both request block directions for every manager role, revoked-manager behavior,
pending cleanup, all compatibility/triage acceptance paths, capacity, privacy,
and preservation of accepted membership/chat/meeting/workspace access. The
real-transaction blocking verifier now covers delegated-manager block/request
and block/accept races in both winner orders plus concurrent final-spot
capacity. No mobile production code or public RPC signature changed.

## Client and demo fixture repairs

Local verifiers and demo data now provide the photo/capacity prerequisites added
by the cumulative schema. Two stale mobile test fixtures were updated for the
current profile skill picker and the delegate route's required app configuration.
These are test/fixture repairs and do not add product behavior.

## Founder-QA mobile stabilization

Founder QA exposed three integration-only issues without changing the selected
architecture. Private chat controllers now detach Realtime signals through an
idempotent teardown-only path: subscriptions/maps are detached before close,
synchronous or late close callbacks are ignored, timers are cancelled, and
Riverpod state is not synchronously mutated during widget disposal. The same
unsafe pattern was corrected in Project chat, participation-request chat,
Resource chat, and unified chat-list controllers.

Profile now owns My Reports and Review Requests as sibling routes. Evidence
details remain nested below Review Requests, and legacy `/profile/reports/
review-requests...` URLs redirect to the canonical sibling path so Back returns
to the list and then Profile.

Private Project-request and Resource rows show the opposite party through the
existing bounded visible-profile-photo batch/cache. Project-request detail adds
the same compact counterpart identity; Resource detail keeps its existing
single header. The canonical scoped chat projection now returns Resource-only
counterparty ID/name fields, while other discriminators remain null and all
scope/order/activity/keyset behavior is preserved. Photo metadata failures are
non-blocking, cached bytes remain identity-bound memory only, and no disk cache
was introduced.

Project interaction-photo authorization now follows current managers: the
Creator and active Co-creators/Co-organizers can see pending requester/current
participant photos, while those requesters/participants can see only the
immutable Creator. Revoked, rejected, withdrawn, left, and removed history
fails closed. Exact canonical Storage-object authorization uses the same
predicate.

The later founder report of widespread local request failures followed a lost
physical-device connection and a relaunch without re-establishing the Android
reverse tunnel. This remains classified as local ADB connectivity, not a proven
product retry regression. Getting-started guidance now says to rerun
`adb reverse tcp:54321 tcp:54321` after reconnecting the device; no global retry,
error suppression, or Supabase endpoint workaround was added.

## Final hosted-CI stabilization

Hosted Validation run `36835008884` exposed two final integration issues. The
delegate role-change widget test relied on `ensureVisible`, which could leave its
keyed action just below the hosted 800x600 hit-test boundary. The test now owns
and restores that viewport, scrolls each exact promote/demote/revoke control into
view, pumps after scrolling, asserts that the control is hittable, and verifies
each confirmation dialog before exercising the real mutations. No production
mobile UI changed.

The same hosted run also showed that an exception while establishing moderation
staff identity could be converted by the page-level operational fallback into an
HTTP 200 unavailable screen. `requireModerationStaff` now collapses client,
claims, staff-access RPC, and malformed-role failures into the same denied result;
failures after moderator/admin authorization has been proven still throw into the
staff-only unavailable UI. Because `admin/loading.tsx` begins streaming before an
async page can call `notFound()`, the canonical staff check now also runs in the
parent admin route-group layout. Its request-scoped React cache is reused by the
queue/detail reads, preserving one authorization decision and a real HTTP 404
before the loading boundary for both `/admin` and `/admin/cases/<uuid>`.

The unchanged local web-auth flow, strengthened to cover both admin paths for
signed-out and ordinary authenticated users, passes. The final local candidate
also passes 1,072 mobile tests, 142 web tests, 53 site tests, all 104 pgTAP files
and 3,236 assertions, every database verifier, and the standard builds and
hygiene checks. The single final-head hosted result is recorded on draft PR #120,
where the generated job status can be updated without changing the validated
commit.

## Validation

Completed locally on the final working tree, including the founder-review
manager-blocking correction and founder-QA mobile stabilization:

- Database reset, lint, advisors, type generation/check, domain verifiers, and
  `npm run check:db`: passed.
- pgTAP: 104 files and 3,236 assertions passed.
- Demo sequence `reset -> verify -> seed -> verify`: passed; the second verify
  confirms idempotent cumulative demo behavior.
- Mobile: localization generation, formatting, static analysis, and 1,072 tests
  passed.
- Android: debug APK built successfully at
  `apps/mobile/build/app/outputs/flutter-apk/app-debug.apk`.
- Dynamic web app: lint, type checking, production build, 33 test files and 130
  tests passed; repository tooling's 24 tests also passed.
- Static site: lint, type checking, production build, deploy dry-run, and 53 tests
  passed (34 client and 19 waitlist tests).
- Formatting, whitespace, test-number, migration-timestamp, localization-parity,
  deferred-dependency, and pgTAP-portability audits passed.

## Remaining warnings and review status

There are no known repository-owned deterministic failures. Non-blocking toolchain
warnings remain: Node deprecation/listener warnings in local database helpers, an
available Supabase CLI update, dependency-update notices, npm audit findings from
the resolved dependency tree, and Gradle/Flutter notices about future Kotlin and
native-access behavior. They did not fail validation and were not expanded into
unrelated dependency work.

Hosted CI status is recorded on the draft integration PR after its single normal
final-head attempt. The PR must remain draft and must not be merged until founder
review.
