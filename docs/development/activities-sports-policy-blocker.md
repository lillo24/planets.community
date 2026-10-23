# Activities/Sports source-merge policy blocker

Current trusted base: `52e301bb665748065e23171d2a4d6ffc92bdefe1`, merged
[STAGING-AUTO03 #306](https://github.com/lillo24/planets.community/pull/306).
Feature integration remains on [#298](https://github.com/lillo24/planets.community/pull/298).

The new executable source gate classifies
`20261023093757_external_activity_multi_source.sql` as **blocked-unsafe**:
`Destructive or role/system DDL`. Its canonical Git SHA-256 is
`0fec4437bf512a14c6218c3f7e7bc3b810c5414dcc44d8d2c2db72010b742fd6`.
The triggering statement at line 2 is:

```sql
drop index private.external_activity_one_enabled_source;
```

This deliberately removes the predecessor's one-enabled-source exclusivity for
ACTSRC02. It deletes no catalogue rows and does not widen raw table grants;
independent source rights/publication, private RLS, V1 compatibility, atomic
leases, source identity and capacity/failure tests remain in place. Nonetheless,
the standing policy treats every top-level `DROP` as source-blocking. Successful
local data/authorization tests cannot override that executable decision.

The other additions are `review-required-for-hosted`, which alone permits source
merge while holding hosted application:

- 002: new direct client projection grants need an established independent contract.
- 007: existing-table/geographic effects need an established independent contract.
- 010: its index belongs to an existing private table, outside the isolated-new-table class.

STAGING-AUTO03 intentionally replaces owner fingerprint comments as an
authorization path. The earlier exact owner-account proof on source `274b5233`
is retained as historical technical review; another comment cannot unblock the
new gate. The source PR must not install its own policy exception, edit the
trusted validator or rewrite already published migration history.

The next action is a **separate, independently validated policy contract** for
this specific reviewed index change, with the original index definition,
unchanged RLS/grants and prior rows, compatible released readers, real independent
authorization/identity/concurrency checks and negative controls for unrelated
index/privilege changes. Hosted eligibility for the other functions/effects must
remain held until their own contracts qualify. No broad DROP exception or
head-comment bypass is appropriate.

Reproduce the source decision without hosted access:

```sh
node --input-type=module -e "import {readMigrations} from './scripts/release/migrations.mjs'; import {migrationCandidate} from './scripts/release/eligibility.mjs'; console.log(migrationCandidate(readMigrations(process.cwd()).find(m=>m.version==='20261023093757')));"
```

The integration preserves every trusted policy/dependency file from current
main. The two convenience npm aliases were removed to keep `package.json`
unchanged; their entry points remain `node scripts/operate-external-activities.mjs`
and `node scripts/verify-local-trento-facilities.mjs`. The ingestion workflow
already invokes the Node entry point directly. The cumulative feature branch,
all tested earlier commits and published SQL bytes are retained.

See [progress and qualification](activities-sports-progress.md) for the 146-file
clean replay, 8,452 assertions, actual-main preservation, mobile/Android and real
116-record municipal evidence. Physical phone review, signing inputs, ODH
coverage and cleanup are independent limits; they are not this source gate's
cause. No manual hosted migration, source/scheduler activation or deployment is
performed to work around it.
