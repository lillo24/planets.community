# A02 — Render Idea and Popular ribbon variants (original visual review plan)

**Status at archive:** Executed as part of Batch A; inspect PR #239/#243 and recorded screenshots for the real result. This document is not a request to reintroduce a Popular algorithm.

## Goal

Use actual Flutter Proposal cards and the current app theme to compare:

- Variant A: two diagonally oriented image ribbons, Idea and synthetic Popular, on opposite corners.
- Variant B: approximately 30-degree Idea ribbon at the top-right, with a compact, quieter popularity marker elsewhere.

Idea versus Project remains a single discovery/creation experience. The existing Requested participation marker currently occupies the upper-right cover region; all three states must have an intentional visual hierarchy rather than overlapping.

## Comparison

Render baseline and both variants for Idea-only, Idea plus Requested, Idea plus synthetic Popular, all three, defined Project plus Requested, missing/broken cover, long titles and normal content. Capture the actual mobile widget at representative 320/360 logical-pixel widths, EN/IT, light/dark and approximately 2× text scaling. Respect existing 3:2 cover layout, card touch target, accessibility labels and lifecycle semantics.

Synthetic Popular and New labels exist **only in fixtures**; they do not create production fields, fetches, rankings, scores or fake data on real cards. The “Popular” metric has not been defined in this design discussion.

## Original delegated choice

The coding agent may make the reversible presentation choice after viewing rendered evidence. Variant B is the conservative tie-breaker unless A visibly fits better; the winner is recorded with screenshot evidence and a narrow-screen/large-font fallback before A03 proceeds. A successful widget test alone is not proof that overlapping elements look good.

## Non-goals

No separate Idea browse category, change to planning phase/confirmation, public popularity metric, new photos, heavy graphic assets or unrelated tutorial redesign. Keep Requested readable and honest.

See original A02 stacked PR #239 and the final Batch A integration #243 for actual results; current code is authoritative.
