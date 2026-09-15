# Continuous integration

The `Validation` GitHub Actions workflow always starts for pull requests, then
uses one short `Change classification` job to map changed paths to four independent
validation areas. Expensive jobs use job-level conditions instead of workflow
path filters, so skipped area checks are still reported to GitHub and do not
leave required checks pending.

## Validation areas

| Check      | Authoritative validation                                                                                                   | Runs for                                                                                                                                                                                 |
| ---------- | -------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Mobile`   | Flutter localization generation, Dart formatting, analysis, and tests                                                      | Non-documentation changes under `apps/mobile`, the mobile local-config generator, shared local Supabase helpers, and cross-cutting changes                                               |
| `Web`      | `npm run check:web`                                                                                                        | Non-documentation changes under `apps/web`, generated database types, web/type generators, shared Node tooling, shared Node dependency/configuration changes, and cross-cutting changes  |
| `Site`     | `npm run check:site`                                                                                                       | Non-documentation changes under `apps/site`, shared Node dependency/configuration changes, and cross-cutting changes                                                                     |
| `Database` | The existing local Supabase reset, lint, advisors, pgTAP, integration, Next.js-against-Supabase, and generated-type checks | Changes under `supabase`, database/integration scripts, generated database types, shared local Supabase helpers, shared Node dependency/configuration changes, and cross-cutting changes |

The classifier unions these areas when a pull request changes more than one.
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
