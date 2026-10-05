# Public website associations

`association-responses.ts` owns fail-closed Android Digital Asset Links and Apple
AASA payloads for the two `src/app/.well-known/` route handlers. It validates public
identity/fingerprint settings, emits direct JSON/cache contracts, and bounds
Apple's paths to participant, authority and public Project details.

`association-responses.test.ts` checks configured/disabled identity cases,
fingerprint normalization, response headers and effective ordered Apple glob
matching. Android's path boundary belongs to the mobile manifest; Flutter then
validates exact URL shapes. The exact well-known routes bypass session Proxy
refresh. See the [link guide](../../../../../docs/development/project-invite-links.md)
and [PI04 record](../../../../../docs/implementation/pi04-native-links-and-public-host-readiness.md)
for configuration, unavoidable wildcard limits and external verification.
