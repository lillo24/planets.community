# A03 — Apply selected unified Idea/Project cards (original implementation plan)

**Status at archive:** Incorporated into final Batch A integration PR #243; do not rerun it blindly.

## Goal

Apply A02's evidence-backed card design in Flutter to indicate **Idea** as a planning phase of a Project, not a different content type. A user browses and creates Ideas/defined Projects in the existing flows; the backend retains its meaningful planning phase, confirmation and promotion rules.

## Work scope

Read the A02 decision record, actual Proposal card widget, shared requested badge, cover/fallback component and proposal lifecycle tests. Use the canonical Idea state for the diagonal image label. Preserve Requested and defined lifecycle/status labels, including an intentional non-overlapping placement for simultaneous statuses. Remove only truly redundant adjacent Idea visual text; do not delete a shared status component used by other surfaces.

Respect cover loading/cache, title wrapping, metadata, current capacity/social-proof visibility, project and Tavolo navigation, tutorial example cards and audience-appropriate semantics. If any label does not fit at large text, provide a readable accessible fallback rather than hiding the essential state.

## Security/product invariants

No change to Project publication, private draft audience, Idea confirmation, membership or manager rights, photo gates, location visibility, interaction rules, saved filters or cover storage. No dynamic per-card lookup for an Idea badge. No production Popular label based on synthetic data; future popularity scoring requires its own explicit decision.

## Validation

Widget/golden review of actual production card for all state combinations, rendered English/Italian narrow screens/light/dark/text scale, semantic announcements, request and capacity parity, cover fallback and no accidental network calls. Run affected Flutter, tutorial and any touched Web checks; preserve honest test coverage.

See the actual integrated implementation in PR #243 and current Proposal card source for the final layout.
