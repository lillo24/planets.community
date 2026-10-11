# PLANETS — Official Starter Templates (OST01)

## Objective
Make a small, useful set of **official default templates** available in the shared PLANETS backend and in the existing mobile Template Workshop. Users should recognize them through a localized **Default / Predefinito** badge and the author/profile display name **Planets Community Official**. They should be immediately available, even when no real community project has yet reached Completed.

Do not populate the Closed-testing database with the full mock universe. This task is the permanent starter catalog, not a general demo-data deployment.

## Confirmed context (reinspect current `main` before coding)
- Repository: `lillo24/planets.community`. Follow `AGENTS.md` and current architecture, migrations, tests, and newer merged changes.
- Existing Template Workshop reads `public.list_public_proposal_templates`, template detail/blueprints, and applies templates through `create_proposal_draft_from_template` with an idempotent receipt. Existing community templates are automatically tied to completed one-time Proposals.
- Existing local fixture seeder (`scripts/lib/demo-workshop.mjs` and `docs/development/demo-data.md`) creates **eight core completed demo templates**, including several samples owned by `PLANETS — demo locale`. The local seeder intentionally rejects remote targets; do not circumvent this guard or run it against staging.
- As checked on 2026-10-11, the connected Supabase staging project was `cllpvruvrrvxczjitlqd` (`planets-staging`), with 3 Proposals, 2 private linked template identities, but 0 public Workshop results. These are diagnostic facts, not authorization to modify staging; inspect the current target/state again.
- `supabase/seed.sql` contains no product data; normal migrations create the controlled skill catalog, not default templates.

## Product behavior
1. Show official starter templates side by side with ordinary community templates in existing Workshop search, detail and application flows. Use a compact badge **Predefinito** (IT) / **Default** (EN) on cards and where appropriate on detail pages. Do not badge unrelated community-authored templates.
2. Attribute official templates to **Planets Community Official** with a clearly designated, non-human organization identity. Do not impersonate a real user, assign a staff member's personal account, or claim an example activity really happened. Official badge/profile designation must be **server-controlled**, not self-asserted by ordinary accounts editing a display name. If rendering an organization as a profile would require a verified synthetic auth account, use a secure, documented administrative provisioning flow instead of forging auth records in SQL.
3. Starter items are reusable *examples* rather than joinable historical activities. Do not display fake attendance, participation stats, messages, or past successful event claims. Existing regular Proposal lifecycle, moderation, privacy, account deletion and historical data must remain truthful.
4. Begin with **eight** polished, Italian-first starter templates if suitable. Review the existing eight demo Workshop scenarios and adapt useful titles/descriptions, skill selections, resource needs and reusable cover assets rather than rewriting content without reason. Keep examples realistic and safe (permissions for murals/public-space work, no unsafe repairs, etc.). Each should help a first-time user start a meaningful local community activity. Ensure image provenance/licensing and Storage access are appropriate; if remote asset setup is needed, provide a verifiable upload/provisioning step and fallback, without inventing accessible URLs.
5. Applying any starter template produces an independent, editable private draft through the existing semantics, with no inherited historical timestamps, meeting location, participants, chat, reporting state or previous project's identity. Keep retry/idempotency, capacity and skill/resource blueprints consistent with the existing application contract.

## Domain design — implement the smallest robust solution
- Investigate how best to represent **curated official templates** as a first-class subtype in the canonical database. The current `private.proposal_templates` identities are source-linked to a real Proposal and the public usability predicate requires Completed; a *badge alone* cannot make independent starter entries visible. Do **not** forge completed Proposal histories or bypass the status predicate globally.
- Prefer a minimal server-owned `official`/`default` discriminator and explicit curated starter content/identity (or another comparably small solution) that can be safely unified into the Workshop RPCs and the draft-application path. Do not build a general template-authoring platform or a large separate marketplace.
- Maintain backward compatibility with existing community template API consumers, pagination/order, search and skill filters, version tokens, creation receipts and removal/reporting rules. Extend response fields safely to identify official items. Ensure server-side attribution and permissions are authoritative; ordinary users must not be able to turn their content into an official template.
- Define a narrow, auditable approach for editing, retiring and reviewing official template content. Public clients must not gain administrative write access. Explicitly handle what happens to previously accepted draft-application receipts if a starter template later changes or is retired.
- Preserve RLS, least-privilege grants, correct media permissions and privacy invariants. Avoid leaking private draft or moderation data through new RPCs.

## Provisioning and environments
- Introduce a **repeatable, reviewed and narrowly scoped** provisioning operation for only the curated official starter set, safe against duplicate runs and able to preserve any independent user-created data. Use stable identifiers/keys, deterministic content versioning, and clear drift semantics; do not reset or truncate the existing staging database.
- Local development and automated tests should bootstrap and verify the starter set from a clean migration replay. For shared staging, provide an explicit dry run/inventory/diff, a safe apply command or deployable additive migration, and a post-apply readback that confirms the eight items are visible via the actual public RPC. If official content or media requires an external staging-only action, list exact steps and prerequisites.
- **Do not deploy, seed, or mutate shared staging/production in this implementation without separate explicit permission.** Prepare everything so it can be deployed on approval. Do not use `demo:seed:local`, any reset command, or synthetic test personas on staging. Do not perform Play Store upload/submission as part of this task.
- Verify backward compatibility with the Closed-testing client currently installed. If it cannot display official entries at all without a new AAB, state that explicitly and include mobile changes plus a release note. A new badge necessarily requires a new client build; avoid making the whole list dependent on a client upgrade if a compatible response is possible.

## Tests and acceptance
- Add database/RPC tests for 8 visible official entries and correct metadata, filters, page cursors, private content boundaries, malicious attempts to set official status, updates/removals, version-token drift, cross-user draft application and retry recovery.
- Add Flutter widget/integration tests proving badge and attribution, plus template → editable draft including skills/needs/covers and handling unavailable/error states. Test IT and EN strings and small layouts.
- Confirm ordinary community templates still become visible only after genuine completion, and their behavior and moderation remain unchanged.
- Confirm local demo seeding still functions separately and does not duplicate official catalog entries.
- Run the repository's relevant database, mobile and backend checks and report what could not be run.

## Delivery
1. Implement on a feature branch from up-to-date `main` (taking newer merged UI/Tutorial work into account), and open a PR. Avoid merging unless established project workflow explicitly permits it.
2. Summarize files/approach, exact starter entries, tests, migration compatibility, and whether a new mobile build is required.
3. Provide precise **manual staging activation commands** and validation/readback, identifying all required environment credentials and asset uploads, plus rollback/retirement path. Keep the existing 3 staging Proposals and the tester account intact.
4. Surface any nontrivial constraint that makes the chosen identity or schema design misleading or unsafe instead of silently faking genuine completed community activity.
