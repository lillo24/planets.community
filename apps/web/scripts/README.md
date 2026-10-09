# Staging hosting tools

`worker-staging.mjs` validates the canonical public staging configuration and
runs the isolated build, local preview, dry-run or deploy. It refuses generated
configuration that attaches routes or enables request Observability.

`probe-worker-staging.mjs` checks anonymous HTTP behavior only on the named
staging Worker or its loopback preview. Its fixed malformed invitation paths
contain no real capability; it does not test OTP or admit participants.

`profile-worker-local.mjs` deliberately restarts production workerd isolates,
profiles fully consumed fixed requests and records non-idle sampling estimates.
`profile-worker-hosted.mjs` measures quiet fixed-class windows on the existing
isolated deployment; `read-worker-cpu.mjs` reads its version-scoped adaptive CPU
aggregates. `worker-cpu-lib.mjs` owns input bounds, response checks, profile
accounting and sanitized source attribution. Its tests prevent redirect/input
escape and confusion between idle and sampled active time. Diagnostic maps and
profiles stay in ignored output, and the deploy runner rejects mapped assets.

See the [CPU diagnosis](../../../docs/development/link-host02-cpu-diagnosis.md)
for reproduction, method limitations, before/after evidence and the rejected
preload trial. Profiling does not exercise real signup/Join or certify Free.

See the [LINK-HOST-01 runbook](../../../docs/development/link-host01-cloudflare-invitations.md)
for commands, resource evidence and the separate live-routing approval gate.
