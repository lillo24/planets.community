# Public proposals

This feature owns the website's signed-out, read-only one-time proposal discovery.

- `proposal-models.ts` validates sanitized RPC payloads and opaque cursor parameters.
- `proposal-server.ts` is the Server Component data boundary for public list/detail RPCs and the controlled skill catalog.
- `proposal-components.tsx` renders shared cards, schedules and derived-status badges.

The website never reads proposal tables directly and never authors proposals. Cards contain only rough location. Detail renders exact meeting text only when the canonical public RPC returns it; otherwise it renders the restricted-location explanation.
