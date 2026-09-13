# Project chat

This feature boundary is reserved for the mobile Project group-chat experience.
Plan 07B1 already owns the canonical backend chat anchor and authorization. Plan
07B2A adds only an isolated MLS cryptography prototype under `crypto/`; it is not
wired into startup, routing, Supabase, Realtime, notifications, or UI.

Production encrypted transport and the mobile experience remain Plan 07B2B.
See [ADR 0006](../../../../../docs/architecture/decisions/0006-project-chat-mls-e2ee.md)
for the validated results, recommendations, unresolved decisions, and production
gates.

## Dependency assessment

The prototype pins `openmls` `3.1.0`, published on 2026-09-08, rather than
accepting an unreviewed future version. The package is an MIT-licensed,
source-available Dart wrapper maintained at
[`djx-y-z/openmls_dart`](https://github.com/djx-y-z/openmls_dart). It binds
`openmls_frb` `2.2.0` to upstream OpenMLS `0.9.0` and Flutter Rust Bridge
`2.13.0`.

The review found:

- active releases and public source, tests, changelog, security policy, Rust
  lockfile, fuzz targets, and advisory triage;
- prebuilt native archives for Android arm64/armv7/x64 and iOS device/simulator;
- a build hook that downloads from the wrapper's GitHub release, verifies the
  archive against a release SHA-256 manifest, and fails closed unless the
  developer explicitly sets `OPENMLS_ALLOW_UNVERIFIED_DOWNLOAD=1`;
- GitHub/Sigstore artifact attestations are published for independent provenance
  verification, but the build hook verifies checksums rather than attestations;
- SQLCipher-encrypted native MLS state, exclusive single-engine database locking,
  owner-only database creation, explicit engine close, and key zeroization
  defenses described by the package;
- Android API 24+, iOS 13+, and Flutter 3.38+ requirements. PLANETS currently
  resolves Android API 24 from Flutter 3.47.2 and declares iOS 15, so no platform
  minimum changed;
- the package is uploaded by an unverified pub.dev uploader, has limited adoption,
  downloads native binaries controlled by the wrapper repository, and has not
  received a PLANETS-commissioned independent audit. Those are production review
  gates, not hidden assumptions;
- ten experimental post-quantum suites are advertised by wrapper defaults. The
  prototype explicitly advertises only RFC 9420 suite `0x0001` and does not
  validate those experimental suites;
- the package ships `THIRD_PARTY_NOTICES.txt` for its statically linked Rust
  dependency graph, but Flutter does not surface those notices automatically.
  07B2B must bundle/display the reviewed notices before distributing a build that
  contains the native library.

This evidence is sufficient for the architecture prototype. It is not approval
to ship the wrapper without the 07B2B gates in ADR 0006.

## Local-state contract

Each crypto client uses a different SQLCipher database file and 32-byte random
storage key. The database path must be scoped by environment, profile UUID, and
generic installation UUID. The key and serialized MLS signing identity must be
encrypted through Android Keystore or iOS Keychain integration; neither belongs
in preferences, logs, analytics, the database server, or push configuration.

Account change or logout must close the current engine, release sensitive
in-memory material, and open only the next profile's client state. Push permission
is irrelevant to MLS. The generic installation UUID may identify both subsystems,
but push tokens and all cryptographic keys remain independent.

Uninstall, app-data loss, Keychain loss, or loss of the only usable group-state
client can make local history unrecoverable. 07B2A intentionally implements no
cloud key backup.

## Validation

Run the focused real-crypto scenario from `apps/mobile`:

```text
flutter test test/features/project_chat/crypto/planets_mls_prototype_test.dart
```

The test uses no cryptographic mocks. It creates separate persistent clients for
creator C, participant A, participant B, and A's fresh rejoin client; proves
KeyPackage/Welcome joins, encrypted message exchange, no pre-join history,
post-removal exclusion, rejoin-gap exclusion, close/reopen continuity, encrypted
database bytes, and independent client files.
