# PLANETS — A01–A04 stacked implementation handoff (archive)

Prepared in the 13 October 2026 PLANETS design discussion. **Archived on 14 October 2026 after implementation.** This is a reconstructed in-repository record of the earlier external Markdown handoff, **not a byte-for-byte copy** of that download. Do not send it to Codex as a fresh implementation request without checking current main.

## Original request and authorization

Implement A01, A02, A03 and A04 as one sequential Codex stack. Keep stage branches/PRs isolated and draft, then validate the cumulative source and merge once into main; do not require a founder response between ordinary coding stages. The reversible A02 ribbon choice was delegated to Codex after actual rendered comparison. No hosted database migration, production deployment, Play upload or billing action was authorized.

The original dependency order:

1. A01 — optional group creation after confirmed personal account setup.
2. A02 — render and compare Idea/Popular badge/ribbon arrangements in real Flutter widgets.
3. A03 — implement selected Idea/Project card presentation without altering lifecycle.
4. A04 — reconcile pre-existing WORKSPACE02 / PR #216 named-link work into the stack, ensure bounded reads and recovery.
5. Final full-source mobile/web/database/native validation, one integration PR, then merge and clean task-owned worktrees.

## Actual implementation outcome known at archival time

- Group attribution and membership were already separately implemented on main via GRP03B/GRP03C. Group registration remains personal-first, not a second Auth identity.
- Batch A integrated through [PR #243](https://github.com/lillo24/planets.community/pull/243), merged into main on 13 October 2026 at merge commit 7ab87008806e4c653acd75ada0722783d5246b0f.
- A01's [PR #238](https://github.com/lillo24/planets.community/pull/238) is marked merged. A02 [#239](https://github.com/lillo24/planets.community/pull/239), A03 [#240](https://github.com/lillo24/planets.community/pull/240) and A04 [#242](https://github.com/lillo24/planets.community/pull/242) were closed as stacked work incorporated through the cumulative integration.
- Original named-link [PR #216](https://github.com/lillo24/planets.community/pull/216) is merged. Later additive WORKSPACE02 hardening is documented at docs/development/workspace02-named-links.md.
- The repository's present code, migrations and tests — not this retrospective note — remain the source of truth.

## Scope boundaries

No new group chat, group-to-group messaging, public user ratings, popularity algorithm, new personal data, group legal verification, Project authority inheritance or generic direct messaging belonged to Batch A. Synthetic Popular/New ribbons were for visual comparison only. Keep old-client workspace-link RPC compatibility and private link scopes.

The operational instructions below reflect the original requested behavior. They are historical references for why implemented decisions were made. Do not rerun migrations, overwrite A PR branches or reimplement work already merged. A separate C-series archive documents the upcoming group planning discussions.

## Environment

Stack: Flutter mobile, Supabase/PostgreSQL, Next.js Web as required by current repository architecture. Original physical test target: 48091FDAS0041A. Local disposable test stacks only for destructive checks; actual hosted rollout remains separately authorized. Read repository AGENTS.md, implementation_plan_sections_suggestions.md and codex-tooling.md for current conventions.
