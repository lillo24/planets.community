# Staging hosting tools

`worker-staging.mjs` validates the canonical public staging configuration and
runs the isolated build, local preview, dry-run or deploy. It refuses generated
configuration that attaches routes or enables request Observability.

`probe-worker-staging.mjs` checks anonymous HTTP behavior only on the named
staging Worker or its loopback preview. Its fixed malformed invitation paths
contain no real capability; it does not test OTP or admit participants.

See the [LINK-HOST-01 runbook](../../../docs/development/link-host01-cloudflare-invitations.md)
for commands, resource evidence and the separate live-routing approval gate.
