# Batch A02 card composition decision

Codex selects **Variant B** under the bounded visual delegation in the batch
handoff. This is a reversible presentation decision, not a previous founder
approval or an activation of popularity. A03 implements only the real Idea state.

## Composition

- At ordinary sizes, Idea uses an approximately 30-degree upper-right ribbon.
  Its theme pair is `primaryContainer` / `onPrimaryContainer`.
- Requested keeps its existing icon, wording, semantics and card border. On an
  Idea card it occupies the upper left. Defined cards keep the upper right.
- If an Idea cover is under 300 logical pixels wide with Requested (200 without
  Requested), or the effective 14px label exceeds 18px, use horizontal essential
  labels: Requested first, then Idea. Preserve text scaling and the 3:2 cover.
- The preview's optional Popular slot is a quiet lower-right horizontal label.
  It never displaces Requested. **No production Popular/New input is added.**
- Remove the adjacent Idea chip on the ribbon card only. Keep defined lifecycle
  chips, undecided metadata, controlled skills, capacity and existing navigation.

Variant A's two equally prominent diagonals compete for attention and require
Requested to move to the lower left when Popular is present. Variant B separates
essential state from optional emphasis and gives Requested a stable position.
The no-cover and failed-cover renders retain the honest existing image fallback.
Both variants use the horizontal fallback at enlarged text; neither shrinks text.

## Reproduction and evidence

The comparison starts at A01 `9faf41e1c64d37360424345cc69b754b6826114c`.
Its exact source is the A02 changeset containing this record. Source hashes,
image hashes/dimensions and the committed A02 head are retained in the external
evidence manifest at:

`C:\Users\leona\.planets\releases\batch-a-20261013\a02-renders\manifest.json`

From `apps/mobile`:

```powershell
flutter test test/features/proposals/presentation/card_comparison_test.dart --no-pub --dart-define=UI_POLISH_CAPTURE_DIR=C:/Users/leona/.planets/releases/batch-a-20261013/a02-renders
flutter analyze test_support/proposal_card_comparison.dart test/features/proposals/presentation/card_comparison_test.dart --no-pub
```

The bounded matrix covers seven cases, three compositions, EN/IT, light/dark,
320/360px viewports and 1x/2x text: 336 layout/semantics/tap tests, plus seven
curated captures. Discovery's actual 16px padding is retained. Fonts are loaded
through the existing `RenderedEvidence` harness. Each capture presents baseline,
opposite ribbons and quiet secondary label from left to right.

Curated PNGs in that directory:

| File                                  | Purpose                                 |
| ------------------------------------- | --------------------------------------- |
| `a02-idea-en-light-360-1x.png`        | Idea alone and normal cover             |
| `a02-all-it-light-360-1x.png`         | Both diagonals versus B's priority rule |
| `a02-all-it-light-320-1x.png`         | Narrow Requested fallback               |
| `a02-all-it-dark-320-2x.png`          | Enlarged Italian essential states       |
| `a02-defined-it-light-360-1x.png`     | Defined lifecycle and Requested         |
| `a02-no-cover-en-light-320-2x.png`    | Honest fallback and long title          |
| `a02-failed-cover-en-dark-360-1x.png` | Failed cover and dark contrast          |

These are inspected Flutter widget renders, not Android/device screenshots.
The cover is the repository's licensed `assets/tutorial/garden-tools.webp`;
provenance remains in its README and `scripts/demo-assets/assets.json`.
Synthetic Popular exists only in `test_support/proposal_card_comparison.dart`.
The wrapper mirrors the current card using its real cover, Requested, location,
schedule, lifecycle and capacity owners; the baseline uses `ProposalCard` itself.

The baseline and both candidates show pre-existing skill-chip text fading at 2x.
It is unrelated to ribbon overlap; A03's production validation must account for
readable controlled-skill labels at that scale. Screen-reader/device behavior
and the actual native journey remain separate final-batch checks.
