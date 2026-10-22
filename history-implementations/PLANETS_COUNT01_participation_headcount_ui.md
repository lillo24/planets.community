# PLANETS COUNT01 — Clear public participation totals and manager breakdown

**Implementation prompt for Codex.** Start from latest `main` of `lillo24/planets.community`; read relevant `AGENTS.md`, the Project Capacity docs and `history-implementations/PLANETS_05E2_public_social_proof_count_reveal.md`. Keep this a **small Flutter localization/presentation PR** with no change to admission, capacity calculation or database counts. Do not merge or deploy automatically.

## Desired presentation

Under **Partecipazione** and on Project/Tavolo cards, once public exact counts are eligible to be shown, use a concise fraction such as **`5/12 persone`**, with clear styling. Do not expose the public label **`Fino a X partecipanti · +1 organizzatori`** or other awkward middle-dot/plus-organizer strings. A public viewer should see **one combined number of people** rather than organizer arithmetic. The numerator represents *unique people currently involved*, including the creator and active organizers, exactly once. The denominator must represent the **same population**: a truthful maximum number of people, **including organizers**. `5/12` is an example, not a hardcoded constant.

Preserve the existing server distinction between registration capacity and whether organizers consume registration slots. If `registrationCapacity = 11`, organizers **do not** count toward those slots, and there is **1** organizer, public total maximum is **12**; if organizers **do** consume a limit of 12, public total maximum remains **12**. Therefore derive the public denominator from canonical data: `registrationCapacity + (countOrganizersTowardCapacity ? 0 : organizerCount)` when capacity is finite. The numerator is `socialPeopleCount`. Never mix ordinary participant count with the combined denominator, double-count a co-organizer, or modify actual admission enforcement.

Keep **organizer breakdown visible only in the manager/organizer view**, where separate fields or a quiet two-line summary can explain `Partecipanti: 4/11` and `Organizzatori: 1`. Avoid the previous public `+1 organizzatori` and the confusing dot separator. Use correct Italian singular/plural and matching English copy. Public no-capacity cases must not invent `/N`; full-capacity states remain accurate.

## Current code evidence and existing privacy rule

- `apps/mobile/lib/features/participation/domain/project_capacity.dart`: `socialPeopleCount = ordinaryParticipantCount + organizerCount`, `capacityUsedCount` depends on the organizer-capacity toggle.
- `apps/mobile/lib/features/participation/presentation/project_capacity_label.dart`: currently assembles `· +{organizers}` even for public viewers and `projectSocialPeopleInvolved` text.
- `apps/mobile/lib/features/participation/presentation/project_capacity_presentation.dart`: public low counts stay concealed until the agreed social-proof threshold is met, except when Full; managers have exact counts.
- `ProjectCapacityLabel` is reused in Project/Tavolo cards and `project_participation_section.dart`; existing tests in `test/features/participation/presentation/project_capacity_label_test.dart` explicitly assert the old copy.

**Do not silently remove the public low-count reveal threshold.** Before it is reached, show a truthful compact *capacity-only* label, based on combined people capacity if finite, **without the current count**; when reached or Full, show `X/Y`. If the viewer is the authorized manager, the exact count and organizer breakdown remain available at all times. Do not expose a hidden `X` through labels, accessibility semantics, tooltips or tests.

## Acceptance and validation

- Public labels never show organizer `+N` arithmetic, separate organizer counts or the middle-dot formula. Where eligible, `5/12` is derived from canonical counts with numerator/denominator measuring the same thing.
- Test toggle on/off, 1 or multiple organizers, low-count concealed vs threshold crossed vs Full, capacity unset, 0 ordinary participants, large capacity, mixed roles, singular/plural and overflow accessibility.
- Manager/organizer views still show exact operational occupancy and organizer breakdown, without contradicting actual remaining registration slots. Ensure card/detail/Tavolo labels use the same helper.
- Update l10n IT/EN and widget tests; run focused capacity presentation/widget tests, localization parity and relevant mobile checks. Report PR, touched files, exact tests/result, and any discovered invariant mismatch. No database migration or capacity semantics change is expected.

**External context:** None required. Preserve the accepted 05E2 reveal policy unless the founder separately requests a policy change.
