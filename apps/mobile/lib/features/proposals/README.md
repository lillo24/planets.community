# Proposals feature

This feature owns one-time proposal discovery and authenticated owner management.

- `domain/` defines proposal, lifecycle, status, skill and time-zone models.
- `data/` calls only the canonical Supabase proposal RPCs and reads the existing controlled skill catalog.
- `application/` coordinates pagination, detail loading and race-safe owner commands. Every owner mutation carries the identity for which the screen was rendered.
- `presentation/` contains public list/detail screens and complete-profile create/edit/my-proposals screens.

The public client never reads proposal tables directly. Rough location is available on public cards; exact meeting text is rendered only when the sanitized detail RPC returns it. Recurring activities, participation, maps and media remain outside this feature.

Public details are self-contained: they show the localized start/end schedule in the event's named timezone and the same Required/Useful skill labels as cards. The editor stores UTC instants, initializes both pickers from event-zone wall time, and keeps those instants unchanged while timezone text is invalid. Invalid timezone input displays a validation message and cannot open a picker; correcting the timezone refreshes the schedule without silently changing the instants.

The time helpers explicitly support the existing `UTC` default as an alias for `Etc/UTC`, because the bundled timezone dataset excludes that legacy alias.
