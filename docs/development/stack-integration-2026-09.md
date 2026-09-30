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

The final inventory has 54 unique migration timestamps and 100 unique pgTAP
numeric prefixes. Parallel-branch test collisions were resolved as follows:

- Resource matching and saved-search suites: `058`–`065` to `083`–`090`.
- Delegate and Co-creator suites: `063`–`069` to `091`–`097`.
- Capacity suites: `070`–`071` to `098`–`099`.
- Workspace suites: `070`–`071` to `100`–`101`.
- Cover suites: `074`–`075` to `102`–`103`.

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

## Client and demo fixture repairs

Local verifiers and demo data now provide the photo/capacity prerequisites added
by the cumulative schema. Two stale mobile test fixtures were updated for the
current profile skill picker and the delegate route's required app configuration.
These are test/fixture repairs and do not add product behavior.

## Validation

Completed locally on the final working tree before the stabilization commit:

- Database reset, lint, advisors, type generation/check, domain verifiers, and
  `npm run check:db`: passed.
- pgTAP: 100 files and 3,171 assertions passed.
- Demo sequence `reset -> verify -> seed -> verify`: passed; the second verify
  confirms idempotent cumulative demo behavior.
- Mobile: localization generation, formatting, static analysis, and 1,062 tests
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
