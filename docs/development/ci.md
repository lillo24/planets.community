# Continuous integration

The `Validation` GitHub Actions workflow always starts for pull requests, then
uses one short `Change classification` job to map changed paths to four independent
validation areas. Expensive jobs use job-level conditions instead of workflow
path filters, so skipped area checks are still reported to GitHub and do not
leave required checks pending.

## Validation areas

MSG01 adds a populated predecessor migration rehearsal before Database's clean
reset, plus its pair/privacy/race/Realtime verifier after the notification
consumer fixtures and blocking producer, immediately before the unrestricted
notification regression. Consumer fixtures acknowledge older events to isolate
batch totals; this order preserves MSG01's real delegated rejection for actual
canonical projection and attribution checks.
Both run only in the existing Database job. The full local `check:db` follows the
same order. The upgrade rehearsal requires `PLANETS_DISPOSABLE_QA=1` outside CI
and resets its selected local stack; verify ownership, project ID, ports and
`MAILPIT_URL` first. Required-check/path classification is unchanged. This PR's
root scripts/workflow edits use the existing conservative classification; no
gate is weakened and no unrelated recurring trigger is added.

| Check      | Authoritative validation                                                                                                   | Runs for                                                                                                                                                                                 |
| ---------- | -------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Mobile`   | Flutter localization generation, Dart formatting, analysis, and tests                                                      | Non-documentation changes under `apps/mobile`, the mobile local-config generator, shared local Supabase helpers, and cross-cutting changes                                               |
| `Web`      | `npm run check:web`                                                                                                        | Non-documentation changes under `apps/web`, generated database types, web/type generators, shared Node tooling, shared Node dependency/configuration changes, and cross-cutting changes  |
| `Site`     | `npm run check:site`                                                                                                       | Non-documentation changes under `apps/site`, shared Node dependency/configuration changes, and cross-cutting changes                                                                     |
| `Database` | The existing local Supabase reset, lint, advisors, pgTAP, integration, Next.js-against-Supabase, and generated-type checks | Changes under `supabase`, database/integration scripts, generated database types, shared local Supabase helpers, shared Node dependency/configuration changes, and cross-cutting changes |

The classifier unions these areas when a pull request changes more than one.
The Database job also runs `project:people:verify:local` for consent/leave and
capacity races and `project:participant-invites:verify:local` for direct admission,
rotation/block/lifecycle and stale-retry races in both capacity modes. These run
sequentially after clean pgTAP validation because their synthetic fixtures persist.
They add no unrelated job trigger or duplicate post-merge run;
root script/workflow edits still follow the conservative four-area policy.
Database CI and `check:db` finish mutation validation with `demo:check:local`:
clean partial-run recovery, non-repairing verification, unchanged seed stability,
explicit lifecycle/photo/stale-receipt checks and fresh restoration. Demo seeding
runs after clean pgTAP and previous verifiers so it cannot contaminate their
empty-database assumptions. Capabilities and OTPs stay out of output/artifacts.
Mobile formatting includes `test_support`, whose explicitly opted-in debug driver
is separate from the production entry point. PI05 browser helpers still select
Web through their source path; shared script/workflow changes select all areas.
`apps/web/src/types/database.generated.ts` deliberately runs both Web and
Database because it is generated from the migrated public schema and consumed
by the Next.js application.

Root `package.json`, GitHub workflow/configuration files, the classifier itself,
and unknown source or tooling paths run all four areas. The root lockfile and
Node version run Web, Site, and Database; `.prettierignore` runs Web and Site.
This conservative fallback means a new category cannot silently bypass
validation before its dependency boundary is documented and tested.

Changes confined to `docs/**`, `history-implementations/**`, or Markdown/MDX
files run only `Change classification`; the four expensive checks appear as
skipped.
Application assets, migrations, and other non-Markdown files still run their
owning area even when they are not executable source code.

## Full validation

The workflow does not run again on a push to `main`. PLANETS merges through
pull requests, where the relevant merge result has already been validated; the
former post-merge run repeated the same expensive suite. To run every area for
release confidence, integration debugging, or a tooling change, use **Actions →
Validation → Run workflow**, or run:

```text
gh workflow run validation.yml --ref main
```

A manual dispatch always enables Mobile, Web, Site, and Database and uses the
same job definitions as pull-request validation.

## Required checks

The repository had no applicable ruleset or `main` branch protection when this
workflow was introduced. To enforce the documented pull-request workflow,
configure a branch ruleset that requires a pull request and these five GitHub
Actions checks:

- `Change classification`
- `Mobile`
- `Web`
- `Site`
- `Database`

Requiring `Change classification` is important: it prevents a classifier
failure from being hidden by dependent area jobs that GitHub marks as skipped.
The workflow itself must remain unfiltered at the pull-request trigger;
job-level skipped checks report success, while a whole workflow omitted by path
filtering can remain pending. If a merge queue is enabled later, add and test
the `merge_group` trigger before making these checks queue requirements.

The existing concurrency group is retained, so a newer commit to the same pull
request cancels its obsolete validation run.

09C1A adds two Database-job integrations for real authenticated consequence
commands/Storage access and 36 database-lock winner-order races across every
Creator/delegated acceptance overload plus the existing final-spot capacity
rule. Both also run in local `check:db`. This adds validation only inside the
already-scoped Database job, without another workflow or hosted rerun trigger.

09C1B adds the ten-identity account-suspension integration (including private
Storage and cached Realtime sockets), 24 suspension/interaction/admin races,
and the reviewed RPC/Broadcast inventory audit to that same Database job.
All three also run in local `check:db`; no new workflow or trigger is added.

DBRACE-02 adds `project:membership-commitments:verify:local` after contribution
selection in that same Database job. Project-scoped CLI status supplies API/DB
endpoints; the standard disposable backend exposes Mailpit on loopback 54324.
The default one iteration checks all four leave/removal-versus-replacement
orders with actual PostgreSQL lock observation, plus the verifier's other flows.
The 40-case diagnostic campaign remains opt-in. Loopback guards, finite deadlines,
failure propagation and `always()` backend cleanup are unchanged. The existing
25-minute budget is retained unless measured execution requires otherwise.
Verifier paths already select Database; shared `scripts/lib` helpers also select
Web and Mobile. Workflow edits select all four areas, providing a full checkpoint
without another trigger or duplicate database aggregate.
Measured runtime and failure dispositions belong to the
[DBRACE-02 report](dbrace02-controlled-validation-and-failure-disposition.md).
