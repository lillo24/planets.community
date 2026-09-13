# ADR 0006: MLS end-to-end encryption for Project group chat

- **Status:** Proposed
- **Date:** 2026-09-13
- **Owners:** PLANETS architecture / Project chat
- **Scope:** Plan 07B2A architecture and non-production Flutter prototype

## Context

Merged Plan 07B1 provides one canonical chat anchor per Project after first
acceptance and derives current/historical entitlement from Project ownership and
canonical membership intervals. It deliberately stores no messages or encryption
material. Plan 07B2 needs a cryptographic model before any production message
schema, transport, Realtime publication, or UI can be designed.

The 07B2A prototype uses RFC 9420 MLS through the maintained OpenMLS Rust
implementation and the reviewed Dart package `openmls` `3.1.0`. It exercises the
actual native library; it does not mock cryptography or implement primitives.

Every item below is explicitly labelled:

- **Validated:** demonstrated by repository evidence, dependency inspection, or
  the executable prototype.
- **Recommended:** the architecture direction for 07B2B, subject to its named
  gates and any founder-owned decision.
- **Unresolved:** requires later evidence, product input, or production design.

## Decision record

### 1. Threat model — validated and unresolved

**Validated:** Supabase and its operators must be treated as an untrusted Delivery
Service for message contents and group secrets. Network observers, unrelated
profiles, late joiners, removed clients, and a compromised delivery database must
not obtain plaintext solely from stored protocol/application artifacts. TLS,
authenticated backend access, RLS, device security, and metadata minimization are
still required.

**Unresolved:** 07B2B must formalize device-compromise, malicious authorized
member, rollback, traffic-analysis, backup, notification-extension, and admin
incident assumptions. E2EE cannot prevent an authorized client from copying or
reporting plaintext.

### 2. E2EE requirement — validated

**Validated:** Message bodies are encrypted and decrypted only by authorized MLS
clients. The server has no group secret, client private signer, local database key,
or arbitrary plaintext preview capability. No production plaintext message table
or server-decryption path is acceptable.

### 3. MLS instead of custom cryptography — recommended

**Recommended:** Use RFC 9420 MLS for asynchronous changing-membership group E2EE,
forward secrecy, post-compromise security, and epoch rotation. Do not implement a
PLANETS-specific group-key protocol. The prototype validates the standards path;
production still needs protocol review and operational hardening.

### 4. Evaluated Flutter wrapper — validated and recommended

**Validated:** `openmls` `3.1.0` compiles with PLANETS Flutter/Dart and exposes the
needed OpenMLS operations: BasicCredential, group creation, KeyPackage, Add,
Welcome, application messages, Remove, GroupInfo, encrypted persistence, and
engine reopen. It uses `openmls_frb` `2.2.0`, upstream OpenMLS `0.9.0`, and Flutter
Rust Bridge `2.13.0`.

**Recommended:** Keep the exact reviewed pin for this prototype. Any 07B2B upgrade
requires a fresh changelog, API, transitive dependency, binary-provenance,
advisory, and interoperability review.

### 5. Package provenance and security — validated and unresolved

**Validated:** Source, MIT license, release history, Cargo lockfile, security
policy, tests/fuzzing, advisory notes, SHA-256 fail-closed build hook, release
checksums, Sigstore/GitHub attestations, and third-party notices are public. Native
release `openmls_frb-2.2.0` includes Android and iOS artifacts. The prototype uses
only IANA-registered suite `0x0001`; it explicitly suppresses the wrapper's
experimental post-quantum capability defaults.

**Unresolved:** pub.dev reports an unverified uploader and limited adoption. The
wrapper and its prebuilt native supply chain have no PLANETS-commissioned audit.
Before production, verify publisher/maintainer continuity, verify release
attestations in CI or build audited binaries reproducibly from a pinned source,
review current RustSec/security advisories, and bundle the package's full
`THIRD_PARTY_NOTICES.txt` in app license UI.

### 6. Device/client identity — validated and recommended

**Validated:** MLS membership is client-oriented. The prototype gives each client
a locally generated opaque installation UUID and independent signing identity.
No hardware ID, advertising ID, push token, or email enters the credential.

**Recommended:** Use one generic local app-installation UUID as the identifier for
both future push registration and MLS client metadata. Keep FCM/APNs tokens,
notification permission, MLS signers, database keys, and group state strictly
separate; E2EE must work when push is denied or unavailable.

### 7. Profile-to-device mapping — recommended

**Recommended:** Model one PLANETS profile as zero or more registered crypto
clients, each represented by a separate MLS leaf. Backend participation and
current-send authorization remain profile-based. An Auth-bound registration maps
public client material to exactly one current profile and environment.

### 8. Local secret storage — validated and recommended

**Validated:** Native wrapper state is a per-client SQLCipher database encrypted
with a caller-supplied 32-byte key. The test proves close/reopen continuity, wrong
client isolation, lack of SQLite/plaintext canaries, and separate database files.
The serialized signing identity remains caller-owned and is not made recoverable
by the MLS database alone.

**Recommended:** Store the database under app-private storage scoped by
environment/profile/installation. Wrap or store its random key and the serialized
signer through Android Keystore and iOS Keychain integration. Close and discard
in-memory state on account switch, explicit logout, screen-lock policy, or client
revocation. Never put secrets in shared preferences, logs, analytics, push data,
or Supabase.

### 9. Supabase Delivery Service role — recommended

**Recommended:** Supabase may authenticate profiles, authorize rows, serialize
state transitions, retain opaque protocol/application artifacts, paginate them,
and notify clients. It must not be cryptographic authority. Likely artifacts are
public client credentials/KeyPackages, GroupInfo, client-targeted Welcome blobs,
Proposal/Commit messages, encrypted application messages, and limited order/epoch
metadata. 07B2A intentionally defines no production schema.

### 10. Bootstrap — recommended and unresolved

**Recommended:** The 07B1 chat anchor may predate the MLS group. The first currently
entitled crypto client should acquire a short, backend-serialized initialization
lease, create the MLS group, and publish authenticated public bootstrap state.
Other entitled clients publish KeyPackages and receive Welcome artifacts.

**Unresolved:** 07B2B must specify lease ownership/expiry, idempotency, group-ID
binding to the chat anchor, collision recovery, orphan cleanup, and how a second
entitled client recovers when the initializer disappears before publication.

### 11. Join — validated and recommended

**Validated:** A client publishes a KeyPackage, a current member produces an Add
Commit and Welcome, existing clients process the Commit, and the new client joins
from Welcome. The test proves the new client decrypts messages from the joined
epoch onward but not an earlier application message.

**Recommended:** Server acceptance grants backend current entitlement immediately,
but decrypt/send readiness remains pending until at least one authorized client is
added cryptographically. The backend must Auth-bind the KeyPackage owner and reject
expired, replayed, revoked, or cross-environment material.

### 12. Leave and removal — validated and recommended

**Validated:** A Remove Commit advances the epoch; the removed client becomes
inactive and cannot decrypt later messages, while remaining clients can.

**Recommended:** Server-side current/send entitlement ends atomically with the
canonical 07B1 membership transition. A pending MLS rotation never restores
backend authorization. Orchestration must remove every registered MLS leaf for the
profile and record retryable convergence until authorized clients process the
commit.

### 13. Rejoin — validated and recommended

**Validated:** The same profile can rejoin as a fresh crypto client with a new
installation UUID, signer, KeyPackage, Add Commit, and Welcome. It decrypts new
post-rejoin messages but cannot decrypt the removed-interval message.

**Recommended:** Rejoin creates fresh/current cryptographic membership and never
reuses an ended device leaf or transfers old epoch secrets through the server.

### 14. Multi-device behavior — recommended and unresolved

**Recommended:** Each authorized device is a separate MLS leaf. Adding a device is
an explicit cryptographic Add; lost-device removal removes that leaf; profile
leave/removal removes all of its leaves. Logout closes and detaches local state but
does not silently claim the device was removed from the group. A creator's new
device has persistent server organizer entitlement but still needs an explicit
Add/recovery path; the server never owns a creator key.

**Unresolved:** Device approval UX, cross-device trust, maximum device count,
stale/offline device policy, logout versus revocation semantics, and creator
recovery when no usable member device remains belong to 07B2B/product review.

### 15. No pre-first-join history — validated and recommended

**Validated:** The prototype demonstrates the natural MLS boundary: joining at a
later epoch does not confer an earlier epoch's application-message secrets. The
same property preserves the gap across removal and rejoin.

**Recommended pending founder confirmation:** A participant sees Project chat
messages only for intervals in which one of their authorized crypto clients was an
MLS member. A first-time joiner gets no earlier application-message history. Do
not add historical-key escrow or server decryption to change this result.

### 16. Metadata visible to the server — recommended

**Recommended:** A future opaque envelope will likely contain an event/message
UUID, `chat_id`, sender crypto-client ID, server receipt time, protocol/application
kind, MLS epoch, and opaque MLS bytes. The server also observes participant/device
relationships, timing, sizes, ordering, IP/session information, and access
patterns. Project title and 07B1 authorization remain server-known.

MLS authenticates protocol content and any supplied AAD; server pagination IDs,
receipt timestamps, and routing fields are transport metadata unless deliberately
bound as AAD. Clients must deduplicate stable event IDs, reject protocol replays
through MLS state, fetch gaps before advancing, and never trust server ordering as
cryptographic truth. Final fields depend on the 07B2B protocol representation.

### 17. Push previews — recommended

**Recommended:** Because the server cannot decrypt arbitrary message text, default
push copy should be generic server-known text such as “New message in <project
title>”. Rich plaintext previews would require a separately reviewed client-side
notification-extension design and must not introduce server decryption. Existing
push code is unchanged.

### 18. Moderation and reporting — recommended and unresolved

**Recommended:** Preserve E2EE. Plan 09 can use user-driven reporting in which an
authorized client deliberately submits selected decrypted evidence plus bounded
context and cryptographic/transport references.

**Unresolved:** Evidence scope, authenticity checks, reporter consent, subject
notice, retention, deletion, administrator access, abuse handling, and legal policy
remain Plan 09/founder decisions. No proactive server content inspection is
claimed.

### 19. Recovery and key loss — unresolved

**Unresolved:** New phone, lost phone, reinstall, local database/key loss, sole
usable state loss, and account deletion need explicit product rules. Later options
include no history recovery, device-to-device transfer, or opt-in encrypted backup
protected by a recovery key the server cannot read. 07B2A implements none. Loss of
all usable group state may require a clearly visible new MLS group/continuity break,
not a success-shaped silent reset.

### 20. Exact 07B2B production work — recommended

**Recommended:** 07B2B should implement, in focused reviewable slices:

1. the finalized threat model, wrapper/provenance gate, notice bundling, and
   production ciphersuite/capability policy;
2. secure installation UUID, signer, and SQLCipher-key lifecycle for Android/iOS,
   including account switching and app lifecycle;
3. Auth-bound crypto-client registration, KeyPackage lifecycle, and device
   revocation;
4. chat bootstrap lease and deterministic chat-anchor/MLS-group binding;
5. serialized membership-change orchestration, commit authorization, pending
   convergence, retries, stale-client resync, and lost-state failure behavior;
6. opaque Welcome/Commit/GroupInfo/application transport with least-privilege RLS,
   pagination, deduplication, ordering, expiry, and Realtime notification;
7. encrypted mobile chat/group-info UX, send recovery, meeting-link access, generic
   push behavior, and test coverage;
8. founder confirmation of no pre-first-join history and explicit recovery policy;
9. moderation-reporting groundwork without weakening E2EE.

No part of 07B2B may treat Realtime as MLS consensus. A practical orchestration
starting point is one current authorized committer lease per chat, one durable
pending membership intent tied to the canonical membership transition, and one
monotonic accepted protocol sequence. Concurrent commits must be serialized or
rebased; stale clients fetch missing artifacts, process them in order, and publish
fresh KeyPackages or use reviewed external-commit/GroupInfo recovery only when
backend authorization independently permits it.

## Consequences

- Production message schema remains intentionally absent after 07B2A.
- The demonstrated no-history boundary aligns cryptographic epochs with 07B1's
  half-open membership intervals, but founder confirmation is still required.
- Backend authorization remains immediate and authoritative even while MLS clients
  converge asynchronously.
- Availability and recovery become explicit client/device concerns; E2EE prevents
  the server from silently reconstructing lost secrets.
- Package provenance, audit maturity, native-notice distribution, and secure mobile
  key storage remain real production gates.

## Alternatives considered

- **Plaintext server chat:** rejected because it violates the product E2EE
  requirement.
- **Custom group cryptography:** rejected because it creates avoidable protocol and
  implementation risk.
- **Server historical-key escrow:** rejected because it defeats the validated
  membership-interval secrecy model.
- **One MLS leaf per profile:** rejected as the default because it hides independent
  device state and makes safe device addition/removal ambiguous.
- **Realtime as membership consensus:** rejected; it is only change notification
  and transport.
