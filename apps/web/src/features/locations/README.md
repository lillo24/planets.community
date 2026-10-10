# Public location credits

location-attribution.tsx renders fixed linked Geoapify/OSM credits on public
Proposal/Tavolo cards and SSR detail labels. It owns no coordinates, secrets,
client state or provider calls. Its test verifies DOM/SSR links.
Canonical public DTO parsing stays in the existing feature models.

`public-exact-maps-url.ts` validates an actor-free canonical one-time public-detail
projection and constructs a coordinate-only Maps URL. Proposal SSR calls it after
a fresh preview read; a private/cleared/different selection also removes the older
public label. Arrival directions never enter this helper. Tests cover malformed,
protected, mismatched and revoked destinations. No persistent exact cache exists.
See [LOCATION02](../../../../../docs/development/location02-inline-project-place.md).
