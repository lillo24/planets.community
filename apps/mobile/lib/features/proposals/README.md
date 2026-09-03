# Proposals feature

This feature owns one-time proposal discovery and authenticated owner management.

- `domain/` defines proposal, lifecycle, status, skill and time-zone models.
- `data/` calls only the canonical Supabase proposal RPCs and reads the existing controlled skill catalog.
- `application/` coordinates pagination, detail loading and race-safe owner commands. Every owner mutation carries the identity for which the screen was rendered.
- `presentation/` contains public list/detail screens and complete-profile create/edit/my-proposals screens.

`presentation/skill_filter.dart` owns the compact, searchable Skills popover:
categorized checkboxes stage a selection, Apply sends the entire ID set once,
and Clear all stages an empty selection. Dismissing without Apply discards the
pending selection. Reopening starts from the applied IDs. Search does not focus
or open a keyboard until explicitly tapped. The public list displays at most
two skill badges plus `+N more`; locality composes with the skills using the
existing backend OR semantics. The reference `general_modular_components` Fancy
Multi Select was inspected for its controlled selection/badge/search pattern;
this is a native Flutter MenuAnchor implementation, without React/CSS reuse.

Browse owns list, detail, mine and editor routes inside the app's stateful shell.
Switching tabs preserves the list scroll/filters and an unsaved editor. Identity
changes discard the shell's retained stacks and clear owner controllers. Revision
checks after each await reject late loads/mutations and prevent an old draft
creation from proceeding to publish in a later session. Every owner RPC still
receives the form's expected identity; no database rule changes are made here.

The public client never reads proposal tables directly. Rough location is available on public cards; exact meeting text is rendered only when the sanitized detail RPC returns it. Recurring activities, participation, maps and media remain outside this feature.

Public details are self-contained: they show the localized start/end schedule in the event's named timezone and the same Required/Useful skill labels as cards. The editor stores UTC instants, initializes both pickers from event-zone wall time, and keeps those instants unchanged while timezone text is invalid. Invalid timezone input displays a validation message and cannot open a picker; correcting the timezone refreshes the schedule without silently changing the instants.

The time helpers explicitly support the existing `UTC` default as an alias for `Etc/UTC`, because the bundled timezone dataset excludes that legacy alias.
