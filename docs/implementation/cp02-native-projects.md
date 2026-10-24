# CP02 — Native Projects in the Community presentation

Dependency: merged CP01, PR #328 (`545c9e11`). Re-inspected the native browse,
creation choice, scratch editor, Workshop handoff and numbered-group source-draft
flow before editing.

Find activities on new-mode Home now opens `/proposals`, including its existing
search, filters, map, public details and Create Project action. Complete-profile
people can also start ordinary native creation from a Community hub or a current
writable General/numbered room. The existing actor-bound
`GroupProjectCreationReturn` marker returns an acknowledged native save to that
exact source route. Scratch and Workshop already propagate this marker. Back
retains the original pushed navigation. The destination rechecks current access.

This marker conveys navigation only. No group ID, location, membership, chat,
organizer permission or Community ownership is copied. Native Project/Idea,
publication/photo/participation gates and standard-mode navigation are unchanged.
The manager-only numbered-group source-draft operation remains independent.
Native discovery still works when the experimental server gate is OFF.

Validation: IT/EN Home at 320dp and 1x/2x, Community/General creation markers and
return, original source-draft recovery, native creation/editor/Idea/Workshop and
participation suites; formatting, static analysis and required Mobile CI.
Rollback: revert CP02; no schema, data, flag or hosted rollback is required.
