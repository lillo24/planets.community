# RELEASE01 live assessment — 21 October 2026

Source: `62781c91323836807dad7ac4c014adac253c71e2`, freshly fetched reviewed
`origin/main`. This is the observation baseline, not a claim about future main.
RESOURCE-UX01 #279 and RESOURCE-CAT01 #282 are merged. Unmerged person previews,
APPVER01 and mock branches are excluded.

## Backend

The connected management API identifies `planets-staging`,
`cllpvruvrrvxczjitlqd`, ACTIVE_HEALTHY, PostgreSQL 17.11.0.003 in eu-west-1.
Read-only history inventory finds **97 applied / 123 canonical / 26 pending**:
CAT01 `20261021155653` and 25 historical Group/contact migrations between
`20261014072939` and `20261020144145`. The existing MAP-COST01 migration
`20261020150706` is already applied, so a timestamp-only catch-up is unsafe.

The [machine-readable manifest](migration-manifest.json) records every pending
filename, canonical SHA-256, ordering prerequisite, domain, affected tables/routines,
data/security effects, current-client requirement and approval status. It also
records each applied file SHA-256, executed-statement SHA-256 and SQL fingerprint.
All 97 applied names/versions/token fingerprints match; no remote-only or duplicate
version was found. This is token equivalence, not byte equality after CLI splitting.
[Raw statement-array hashes](migration-manifest.json) remain independently recorded
as `remote_sha256`, separately from each `canonical_sha256`.

[Read-only checks](backend-checks.json) find **36 current mobile RPCs missing**,
including all 11 category V2 endpoints, Messages v7/unread and Group-discussion/
notification/report successors. Storage bucket privacy/MIME/limits and exposed-table
RLS checks pass. Category mutation/read grants cannot pass while CAT01 is absent.
MAP-COST01 enabled/license/retention and bounded provider/TTL/editor gates pass.
No provider request or counter reservation was made.

An additional read-only count inventory covers 126 tables across product schemas
and selected Auth/Storage metadata (355 rows total), without retrieving user field values.
This establishes that staging is populated; it is not a recovery backup or a
claim that synthetic predecessor fixtures reproduce every hosted row.

The deployed map-provider v5 bundle is
`afbba54efcce958ac5416d5e0eb9a9874827da7a931886d8d3181e917fc8b7b3`;
location-search v5 is `c85211f868e39caab986cb6f6b164d5233a749038692ea49deac68b151535f66`;
location-preview v4 is `7cf99298e81fc3cfd070065fa97946441731f7f5ac3759ee9c57264e8f3bf83f`.
Their own entrypoints/adapters match main. Map/search's shared provider also
matches. Preview's older bundled shared provider has the earlier state-only
administrative label normalization, retaining the same response shape; main adds
county+state. It is recorded separately, not represented as byte-identical.
This task deploys no function; policy pins observed bundle identities and current
source hashes, so future code or hosted changes require release review.

Member-contact policy 3 is explicitly approved in the current review heading and
decision ledger. No additional privacy policy or retention period is approved by
RELEASE01. Hosted application of those 25 files still requires scope approval.
Recovery/restore evidence for this run is not established. Earlier staging waivers
do not carry forward. **No hosted migration, SQL write, Auth change, seed/reset,
Edge deployment, provider activation or backup occurred in this task.**

## Play, credentials and device

Read-only Console inspection verifies app `community.planets.app`, one closed
track **Alpha** (`alpha`), track Console ID `4700334745904524501`:
[current closed track](https://play.google.com/console/u/1/developers/8649245788563869268/app/4974645333747478583/tracks/4700334745904524501).
It is Active, serves **12 (0.1.8)**, states “Available to selected testers”, and
retains one country/region. All app bundles lists 11 historical versions, highest
code **12**, uploaded 21 October. Publishing overview reports no unpublished changes.
This verifies the existing release, not a new RELEASE01 delivery or a reserved code.

The Console's downloaded **upload** certificate SHA-256 is
`f9362ed9f6f7be7c59a6eacfd8aae99426af98935ff1197f65e8207cc0fd22c0`.
The original local upload keystore's certificate matches. The separate Play App
Signing/distribution certificate is not substituted. No key was generated/reset.
Ignored owner-held signing/config files exist; their values/passwords were not
printed or committed. A Play Publisher service-account credential is not available.

GitHub API confirms admin permission on this public repository but currently lists
**no environments, Actions secrets or variables**. Connected Supabase access can
inspect staging; its OAuth credential is not an Actions deployment token and was
not extracted. Local staging DB credentials exist but were not sent to GitHub.
Supabase native GitHub integration ownership remains an owner verification step.
No account/environment/security setting or store release was changed.

ADB lists no connected device. Play-device OTP, category/listing/saved-search,
map, Group/Messages and account-switch smoke are **unrun**. Docker did not answer
the bounded local readiness attempt, so the populated rehearsal is assigned to
the fresh disposable CI runner; no local stack was reset.

No AAB was built or offered for download: required hosted APIs are missing. No
Play edit/upload/submission, tester change, Recovery prompt or minimum-version
raise occurred. The release workflow remains disabled through absent enable vars
and unset bootstrap approvals. The next deployment step is owner review of the
26-file manifest plus recovery decision and protected-environment provisioning;
the [runbook](../../release01-staging-play.md) supplies exact fields and commands.
