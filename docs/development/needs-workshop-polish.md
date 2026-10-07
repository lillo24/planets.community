# Needs checklist and Workshop spacing polish

Presentation-only scope, initially inspected from main `85cb75f` and reconciled
with main `23b88fc` before final validation. Canonical requirement
coverage, claims, manual reversal, authorization, attention/realtime, template
filtering/copying and the creation chooser remain owned by their existing modules.

Covered requirements appear before every uncovered requirement, grouped by kind
within each partition. Both coverage sources use a readable neutral surface,
muted text, check icon and localized Covered status. Importance remains visible.
Creator/delegate undo is available only on manually covered rows, with the
tooltip/semantic tooltip **Mark as needed / Segna come necessario**. Successful
actions reload canonical coverage; reversal does not imply uncovered if another
source still covers the need. Ordinary participants have no undo control.

The checklist has no Needed now/Needed again heading or separate manual section.
Existing attention callouts and historical feed copy outside the checklist are
unchanged. All-covered copy is **All needs are covered. / Tutti i bisogni sono
coperti.** Active actions stack below labels on narrow or enlarged-text layouts.

Public Projects browse removes only the inline template CTA. Workshop remains in
the AppBar and in the template/scratch creation chooser; the create FAB remains.

## Focused search/input spacing audit

Inspected every SkillFilter and TagMultiSelect caller, their shared selector sheet,
and adjacent decorated inputs in discovery and related editors. No filter logic,
debounce, selections or backend calls changed.

| Layout                                                                   | Existing separation / outcome                                                                                                                                      |
| ------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Template Workshop query to SkillFilter                                   | Missing gap; added `AppSpacing.medium`.                                                                                                                            |
| Public Projects query/locality to SkillFilter                            | Explicit `AppSpacing.medium` gaps; retained.                                                                                                                       |
| Profile edit bio to TagMultiSelect                                       | `AppSpacing.large`, description and `AppSpacing.medium`; retained.                                                                                                 |
| Project editor location controls to ProposalSkillsControl/TagMultiSelect | `AppSpacing.large`, competence heading and `AppSpacing.small`; retained.                                                                                           |
| Shared TagMultiSelect search/options sheet, used by all four callers     | Search/count/options gaps retained. Audit found footer action overflow at 320px/2x text; `OverflowBar` now stacks Clear/Apply or Done with small gaps when needed. |
| Scambio/Dona query and locality                                          | Small disclosure gap plus locality counter space; no multi-select; retained.                                                                                       |
| Tavoli locality discovery filter                                         | Single decorated input, no adjacent selector; retained.                                                                                                            |
| Saved resource search editor query/locality                              | TextField counter space separates decorated inputs; no multi-select; retained.                                                                                     |
| Resource listing editor fields                                           | Small top padding plus counter space per field; no adjacent selector; retained.                                                                                    |
| Project resource need title/details editor                               | TextFormField counter space; no multi-select; retained.                                                                                                            |
| Project resource match location/mode dropdowns                           | Explicit `AppSpacing.medium`; retained.                                                                                                                            |

## Validation scope

The nine focused test files passed all 119 tests after reconciliation with main.

Focused tests cover mixed coverage ordering, neutral completion presentation,
contribution actions, canonical reopening, creator/delegate and participant
permissions, EN/IT all-covered copy, AppBar/FAB/chooser navigation and measured
Workshop/Project browse separation. Needs and Workshop exercise 320px/2x text in
EN/IT and light/dark themes. The audited Project editor selector also exercises
320px/2x text with measured gaps, including the shared search sheet. Profile edit
measures its input/selector gap at 360px/2x text.
Existing controller, chat attention and creation tests protect the unchanged
domain contracts. Full mobile gate: `npm run check:mobile` (localization,
formatting, analysis and all Flutter tests). These are automated widget checks;
they do not constitute physical-device or screen-reader QA.

The audit found a pre-existing Profile-edit AppBar action Row overflow of 33px
at 320px/2x text (`profile_edit_screen.dart`); its bio/competence controls are
correctly separated. That unrelated AppBar issue remains outside this focused
spacing change. The same Profile spacing test passes at 360px/2x text. The
diagnostic check at 320px failed; it is not claimed as passing device/layout QA.

## Exact changed files

All paths are repository-relative. Generated localization files are ignored and
regenerated by the standard mobile gate.

- `apps/mobile/lib/core/widgets/README.md`
- `apps/mobile/lib/core/widgets/tag_multi_select.dart`
- `apps/mobile/lib/features/project_chat/README.md`
- `apps/mobile/lib/features/project_chat/presentation/project_needs_sheet.dart`
- `apps/mobile/lib/features/proposals/README.md`
- `apps/mobile/lib/features/proposals/presentation/public_proposals_screen.dart`
- `apps/mobile/lib/features/template_workshop/README.md`
- `apps/mobile/lib/features/template_workshop/presentation/template_workshop_screens.dart`
- `apps/mobile/lib/l10n/app_en.arb`
- `apps/mobile/lib/l10n/app_it.arb`
- `apps/mobile/test/core/widgets/tag_multi_select_test.dart`
- `apps/mobile/test/features/profile/presentation/profile_flow_test.dart`
- `apps/mobile/test/features/project_chat/presentation/project_chat_flow_test.dart`
- `apps/mobile/test/features/project_chat/presentation/project_needs_sheet_test.dart`
- `apps/mobile/test/features/proposals/presentation/project_creation_ux_test.dart`
- `apps/mobile/test/features/proposals/presentation/skill_filter_test.dart`
- `apps/mobile/test/features/template_workshop/presentation/template_workshop_test.dart`
- `docs/development/needs-workshop-polish.md`
