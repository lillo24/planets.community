# Project-chat MLS prototype

This folder owns the isolated Plan 07B2A OpenMLS adapter. It contains no network,
backend, authorization, lifecycle observer, secure-storage integration, or UI.

- `planets_mls_prototype.dart` binds a PLANETS profile UUID plus generic
  installation UUID to an MLS BasicCredential, constrains advertised capabilities
  to RFC 9420 suite `0x0001`, and exposes only the lifecycle operations exercised
  by the prototype.
- The mirrored test folder owns the real creator/A/B add, message, remove, rejoin,
  gap, persistence, encrypted-at-rest, and client-isolation scenario.

The caller supplies a separate database path and 32-byte key per crypto client.
That explicit boundary prevents this prototype from pretending that production
Keychain/Keystore, account switching, or server orchestration already exists.
