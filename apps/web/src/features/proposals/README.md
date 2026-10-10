# Public proposals

This feature owns sanitized public one-time Project discovery and detail.
The website never reads proposal tables directly or authors proposals. Cards
contain only rough public location. Detail renders exact meeting text only when
the canonical public RPC returns it; otherwise it explains restricted access.

- `proposal-models.ts` validates the v2 Idea/Defined discriminator and public
  allowlist, and encodes publication/reference-time cursors. Defined logistics
  remain mandatory; absent Idea logistics are deliberate domain values.
- `proposal-server.ts` calls canonical v2 RPCs with phase, keyword, city and skill
  filters. Missing pagination anchors and backend failures remain errors.
- `proposal-components.tsx` renders cards, phase/status badges and truthful
  schedule/place text; tentative dates do not become operational event status.
- Matching tests cover parsing, privacy, cursor forwarding and presentation.

The public routes compose these modules with existing app handoff behavior.
`project-participant-invites/participant-project-gateway.ts` also uses the v2
sanitized public detail, independently of protected invitation acceptance.
See [IDEA01B rollout and compatibility](../../../../../docs/development/idea01b-public-idea-experience.md).
