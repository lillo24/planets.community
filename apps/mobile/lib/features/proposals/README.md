# Proposals feature

This feature owns one-time proposal discovery and authenticated owner management.

- `domain/` defines proposal, lifecycle, status, skill and time-zone models.
- `data/` calls only the canonical Supabase proposal RPCs and reads the existing controlled skill catalog.
- `application/` coordinates pagination, detail loading and race-safe owner commands. Every owner mutation carries the identity for which the screen was rendered.
- `presentation/` contains public list/detail screens and complete-profile create/edit/my-proposals screens.

The public client never reads proposal tables directly. Rough location is available on public cards; exact meeting text is rendered only when the sanitized detail RPC returns it. Recurring activities, participation, maps and media remain outside this feature.
