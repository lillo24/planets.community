# PLANETS 07B2A — MLS E2EE Architecture and Flutter Crypto Prototype

**Roadmap area:** PLANETS 07 — Messages + Project Chat  
**Task type:** Security architecture validation + mergeable prototype/ADR  
**Repository:** `lillo24/planets.community`  
**Required base:** latest merged `main`  
**Known merged 07B1 base:** `bb26ef4a518484da6f67b3309d2cfd62e4d2b483`

## Objective

Resolve the highest-risk part of 07B2 **before production chat-message persistence is designed**:

> Can PLANETS implement its existing end-to-end-encryption requirement for Project group chat using standards-based MLS on Flutter/Android/iOS while keeping Supabase only as an untrusted delivery/state service?

Preferred direction to validate:

```text
RFC 9420 Messaging Layer Security (MLS)
        +
OpenMLS
        +
current Flutter/Dart OpenMLS bindings
```

Do **not** invent custom cryptography.

07B1 is already merged and owns:

- exactly one chat anchor per Project;
- first accepted join request activates it;
- creator/current/former-member entitlement;
- exact canonical membership intervals;
- leave/removal/rejoin behavior;
- no message storage.

07B2A validates the client-side cryptographic stack and writes the architecture decision that later production chat can safely build on.

This is a focused **architecture/prototype PR**, not production chat.

After 07B2A we should know:

- whether the current Flutter/OpenMLS package is acceptable;
- Android/iOS compatibility;
- how one PLANETS profile maps to one or more MLS clients/devices;
- how MLS state is persisted locally;
- how KeyPackages, Welcome messages, Commits, and encrypted application messages can be transported through Supabase without server decryption;
- how join/remove/rejoin maps onto MLS epochs;
- how multi-device support should work;
- what metadata the backend needs later;
- what the server still sees despite E2EE;
- whether MLS's natural **no pre-join history** behavior should become the final PLANETS rule;
- what 07B2B must implement.

Do not merge the PR.

Archive this exact prompt at:

```text
history-implementations/PLANETS_07B2A_mls_e2ee_architecture_flutter_crypto_prototype.md
```

---

# Why this plan exists

The repository explicitly records that 07B2 must resolve E2EE before storing message bodies.

E2EE changes:

- message schema;
- device identity;
- key lifecycle;
- membership changes;
- multi-device behavior;
- local persistence;
- push previews;
- moderation/reporting;
- recovery.

Do not create a premature:

```text
chat_messages(body text)
```

table.

---

# Standards direction

Use **MLS, RFC 9420** as the baseline.

Reasons:

- standardized asynchronous group E2EE;
- designed for changing group membership;
- forward secrecy;
- post-compromise security;
- epoch rotation;
- untrusted Delivery Service model;
- new members do not normally receive old application-message secrets.

Use maintained OpenMLS rather than implementing MLS ourselves.

At plan creation time a Flutter/Dart `openmls` wrapper exists and advertises Android/iOS support and encrypted local state.

**Codex must inspect the current package/repository/version at implementation time rather than blindly pinning a version from this prompt.**

---

# Stop condition: dependency quality

Before adding a dependency inspect:

- source repository;
- license;
- publisher/ownership;
- release history;
- OpenMLS version;
- native-binary provenance;
- checksum/supply-chain behavior;
- Android/iOS support;
- minimum OS/API;
- local-state encryption;
- production suitability;
- obvious security warnings/issues.

If the wrapper is abandoned, opaque, unsafe, or incompatible:

**stop and report.**

Do not substitute hand-written crypto.

A failed spike is a valid result.

---

# Required repository inspection

Inspect at minimum:

1. root/nested `AGENTS.md`;
2. `docs/architecture/product-decisions.md`;
3. `docs/architecture/system-design.md`;
4. `docs/implementation/roadmap.md`;
5. merged 07B1 migration/tests/docs;
6. Project chat anchor + authorization helpers;
7. canonical participation intervals;
8. mobile `pubspec.yaml`;
9. Android Gradle/effective min SDK;
10. iOS deployment target configuration;
11. current persistence conventions;
12. Auth/profile account-switch behavior;
13. CI/licensing conventions.

---

# 1. Keep production chat schema untouched

07B2A should **not** add production tables for:

- chat messages;
- ciphertext envelopes;
- KeyPackages;
- Welcome messages;
- MLS Commits;
- encryption keys.

Production DB migration is **not expected**.

Allowed:

- architecture decision record;
- isolated crypto prototype;
- dependency/build configuration needed for prototype;
- tests;
- documentation/roadmap updates.

If a production migration seems necessary, stop and justify it first.

---

# 2. Device/client identity

MLS is client-oriented.

Design/prototype:

```text
PLANETS profile
  ├── crypto client/device A
  └── crypto client/device B
```

Each client has independent MLS state.

Do not use hardware/ad IDs or email.

Prefer an opaque locally generated installation/client UUID.

## Relationship to push installation ID

06C1 already defines an opaque client-generated push installation UUID, though 06C2B has not implemented Flutter persistence yet.

Evaluate whether PLANETS should have one generic app-installation UUID reused as an identifier by both:

- push registration;
- MLS client metadata;

while keeping push tokens and cryptographic keys totally separate.

Recommended direction:

```text
one generic local installation UUID
independent subsystem credentials/state
```

E2EE must not depend on notification permission or FCM.

Document the decision.

---

# 3. Credential binding

PLANETS Auth tells the backend which profile owns a crypto client.

MLS cryptographic clients must be bound safely to that profile.

Requirements:

- backend remains authoritative for profile ownership of published crypto-client material;
- private signing/key material remains client-side;
- no email in MLS credentials;
- account switching must not reuse another profile's crypto identity;
- avoid inventing PKI/X.509 unless truly necessary.

A BasicCredential-style identity may be enough if registration is Auth-bound; verify against the actual wrapper/API.

---

# 4. Local encrypted MLS state

Prototype persistent state and prove:

- client/group creation;
- engine/process close;
- reload;
- continued decrypt/send works;
- state is not stored plaintext;
- multiple logical clients do not overwrite one another.

Document:

- where MLS state lives;
- what encrypts it;
- how the storage-encryption key should be held on Android/iOS;
- behavior on uninstall/app-data loss;
- what is intentionally unrecoverable.

Do not implement cloud key backup.

---

# 5. Executable crypto scenario

Create a real automated prototype with logical clients:

```text
creator C
participant A
participant B
```

Prove:

1. C creates MLS group;
2. A creates/publishes KeyPackage;
3. C adds A;
4. A processes Welcome;
5. C sends encrypted application message;
6. A decrypts it;
7. B cannot decrypt before joining;
8. B is added later;
9. B can decrypt new messages;
10. B cannot decrypt the old pre-join message;
11. A is removed;
12. A cannot decrypt subsequent messages;
13. remaining members can;
14. A rejoins using fresh/current crypto material;
15. A decrypts new post-rejoin messages;
16. A cannot decrypt the removed-gap message;
17. persistence/reload works during the flow.

Do not replace crypto behavior with mocks.

---

# 6. Pre-first-join history recommendation

The unresolved product question is whether a newly accepted participant should see earlier chat messages.

MLS naturally gives:

```text
join at epoch N
→ decrypt epoch N onward
→ no old application-message history
```

This also matches the approved rule that former participants must not see messages sent outside their membership intervals.

Therefore the recommended production rule is:

> A participant sees Project group-chat messages only from periods in which their crypto client/profile was an authorized member. A newly accepted participant does not receive pre-first-join history.

Do **not** implement server-side historical-key escrow to bypass this.

Record this as **validated/recommended pending founder confirmation**, not falsely as already founder-approved.

---

# 7. Creator and new devices

07B1 gives the creator persistent server-side organizer entitlement.

That does **not** mean the server owns the creator's chat key.

A newly installed creator device is a new MLS client and needs an explicit add/recovery path.

Document this.

Do not copy secrets through plaintext backend storage.

---

# 8. Multi-device model

Do not assume:

```text
1 profile = 1 device
```

Recommended model to evaluate:

```text
each authorized device/client = separate MLS leaf
```

while participation authorization stays profile-based.

Document:

- adding another device;
- lost-device removal;
- logout;
- profile leave/removal;
- creator with multiple devices;
- removing all MLS clients for a profile when that profile loses current entitlement.

Full multi-device UX is not required here.

---

# 9. Supabase as untrusted Delivery Service

Design Supabase as transport/state coordination, not cryptographic authority.

Likely future opaque artifacts:

```text
public client credential / KeyPackage
GroupInfo
Welcome blobs targeted to crypto clients
MLS Proposal/Commit protocol data
encrypted application ciphertext
epoch/order metadata
```

Server must not need:

- plaintext message body;
- group secret;
- client private key;
- local MLS DB encryption key.

Do not finalize the production schema yet.

---

# 10. Membership orchestration

07B1 changes membership authoritatively in PostgreSQL.

MLS membership must then be reflected cryptographically.

Document a concrete production model.

## Bootstrap

The DB chat anchor may exist before an MLS group does.

Evaluate:

```text
chat anchor activated
→ first entitled crypto client acquires initialization lease
→ creates MLS group
→ uploads public protocol state
→ other entitled clients join via KeyPackages/Welcome
```

Use a better OpenMLS-supported flow if evidence supports it.

## Accepted participant

After server membership acceptance:

- authorization is current;
- their crypto clients still need MLS Add/Commit/Welcome before decrypt/send.

## Leave/remove

When server membership ends:

- server-side send/current entitlement ends immediately;
- MLS group must advance to an epoch excluding that profile's crypto clients;
- backend must never allow the removed profile to send merely because crypto rotation is pending.

Do not let cryptographic lag restore backend authorization.

---

# 11. Offline/liveness design

Document:

- who may generate membership Commits;
- how pending membership changes are represented;
- how concurrent committers are serialized;
- stale-client resync;
- what happens if the only usable group-state device is lost;
- whether external commits / published GroupInfo help;
- which recovery cases remain open.

Do not write “Realtime handles it.”

Realtime is transport, not MLS consensus.

---

# 12. Realtime compatibility

No production Realtime needed now.

Document later model:

```text
opaque encrypted/protocol row inserted
→ Realtime notifies authorized clients
→ client fetches/processes MLS bytes
```

Backend authorization/RLS remains required even though content is encrypted.

Do not broadly expose private tables because ciphertext is opaque.

---

# 13. Ordering/replay metadata

Document recommended future envelope metadata, e.g.:

```text
event/message UUID
chat_id
sender crypto-client ID
server created_at
protocol/application type
MLS epoch
opaque MLS bytes
```

Clarify:

- cryptographically authenticated metadata;
- server transport metadata;
- pagination;
- duplicate/replay handling.

Do not force a schema if the actual wrapper needs another representation.

---

# 14. Push-preview implication

With real E2EE, the server cannot derive arbitrary plaintext push previews.

Record recommended future default:

```text
New message in <project title>
```

or similarly generic server-known copy.

Do not add server decryption for rich previews.

Do not change current push code.

---

# 15. Moderation implication

E2EE prevents proactive server inspection of message bodies.

Plan 09 may need user-driven reporting where the client submits selected decrypted evidence/context.

Document the consequence only.

Do not weaken E2EE for moderation convenience.

---

# 16. Recovery implications

Document unresolved future behavior for:

- new phone;
- lost phone;
- reinstall;
- local crypto DB loss;
- account deletion.

Possible later options:

- no history recovery;
- explicit encrypted backup/recovery key;
- device-to-device transfer.

Do not implement key backup now.

---

# 17. Build/platform validation

If the wrapper passes quality review, add it only inside the prototype boundary.

Validate:

- `flutter pub get`;
- format;
- analyze;
- tests;
- Android build/compile;
- iOS build if repo/CI environment supports it.

Compare package platform minimums with PLANETS effective targets.

Do **not** silently raise Android/iOS minimum versions.

If an increase is required: stop and report exact impact.

---

# 18. Prototype placement

Keep prototype isolated, e.g.:

```text
apps/mobile/lib/features/project_chat/crypto/
apps/mobile/test/features/project_chat/crypto/
```

or a similarly clean test-only boundary.

Do not add:

- chat screens;
- routes;
- hidden production debug UI.

---

# 19. No production crypto backend yet

Do not add production:

- crypto-device registration;
- KeyPackage directory;
- Welcome queue;
- Commit/protocol event store;
- ciphertext message table;
- Realtime publication.

Those belong to 07B2B after this architecture is validated.

---

# 20. ADR

Create a durable architecture decision document covering:

1. threat model;
2. E2EE requirement;
3. why MLS, not custom crypto;
4. chosen/evaluated wrapper;
5. package provenance/security;
6. device/client identity;
7. profile-device mapping;
8. local secret storage;
9. server Delivery Service role;
10. bootstrap;
11. join;
12. leave/remove;
13. rejoin;
14. multi-device;
15. no-prejoin-history recommendation;
16. metadata visible to server;
17. push preview limitation;
18. moderation/reporting;
19. recovery/key-loss;
20. exact 07B2B production work.

Label each point:

- validated;
- recommended;
- unresolved.

---

# 21. Roadmap reconciliation

Mark merged 07B1:

```text
07B1 — Implemented
PR #26
bb26ef4a518484da6f67b3309d2cfd62e4d2b483
```

Split 07B2:

```text
07B2 — Project Chat Messaging + E2EE (parent) — In progress

07B2A — MLS E2EE Architecture and Flutter Crypto Prototype — In progress
07B2B — Encrypted Chat Transport, Realtime and Mobile Experience — Not started
```

If the proposed OpenMLS route fails, leave 07B2B blocked and document why.

Keep:

```text
06C2B — not started / external Firebase context required
04C — not started
05C — not started
```

---

# 22. Product-decision documentation

Do not falsely label unapproved details as founder-approved.

Keep approved:

- first-accept activation;
- one chat per Project;
- creator/current/former entitlement;
- membership intervals.

Record as validated/recommended:

- MLS if prototype succeeds;
- no-pre-first-join history, pending founder confirmation.

---

# Validation

Run affected normal validation:

- Flutter dependency resolution;
- format/analyze;
- existing Flutter tests;
- real MLS crypto tests;
- Android build;
- iOS build where available;
- Web/SITE regressions;
- DB CI unchanged/green if run;
- `git diff --check`.

No external provider/account required.

---

# Non-goals

Do not implement:

- production message schema;
- plaintext chat;
- production ciphertext transport;
- crypto backend directory/queues;
- Supabase Realtime chat;
- chat UI/composer/group info;
- meeting-link UI;
- chat unread counts;
- chat notifications;
- Firebase;
- attachments;
- reactions/edit/delete;
- moderation;
- key backup;
- production infrastructure.

---

# Acceptance criteria

07B2A is ready when:

- [ ] based on merged PR #26 main;
- [ ] exact prompt archived;
- [ ] 07B1 roadmap corrected;
- [ ] 07B2 split into 07B2A/07B2B;
- [ ] no production chat-message table;
- [ ] no custom crypto invented;
- [ ] dependency/provenance review completed;
- [ ] real Flutter/OpenMLS code compiles on supported target(s);
- [ ] group create works;
- [ ] member Add/Welcome works;
- [ ] encrypted message roundtrip works;
- [ ] late joiner cannot decrypt pre-join message;
- [ ] removed member cannot decrypt post-removal message;
- [ ] rejoin works;
- [ ] removed-gap history remains unavailable;
- [ ] persistent/reloaded MLS state works;
- [ ] multi-device architecture documented;
- [ ] Supabase Delivery Service model documented;
- [ ] membership orchestration/liveness documented;
- [ ] server metadata/push/moderation/recovery implications documented;
- [ ] no platform minimum silently raised;
- [ ] affected CI green;
- [ ] PR remains unmerged.

---

# Stop conditions

Stop and report before:

- implementing custom crypto;
- accepting an unsafe/unmaintained wrapper;
- silently raising platform minimums;
- adding production message/key/ciphertext tables;
- storing plaintext;
- storing MLS private keys server-side;
- building chat UI;
- claiming pre-join history is founder-approved without confirmation;
- merging the PR.

---

# Deliverables

1. archived exact prompt;
2. dependency/security assessment;
3. isolated Flutter/OpenMLS prototype;
4. persistence/restart proof;
5. add/remove/rejoin scenario;
6. late-join/no-history proof;
7. Android/iOS compatibility assessment;
8. E2EE/MLS ADR;
9. device identity recommendation;
10. backend Delivery Service/schema outline;
11. orchestration/liveness design;
12. push/moderation/recovery implications;
13. roadmap reconciliation;
14. focused PR, preferably `codex/07b2a-mls-e2ee-prototype`;
15. structured completion report.

Do not merge the PR.

---

# Completion report

Return:

1. **Summary**
2. **Branch/base/PR**
3. **Changed files**
4. **07B1 roadmap reconciliation**
5. **Dependency/package assessment**
6. **OpenMLS version/binding**
7. **Platform compatibility**
8. **Device/client identity**
9. **Credential binding**
10. **Local encrypted state**
11. **Group creation**
12. **Member Add/Welcome**
13. **Application-message crypto**
14. **Late-join result**
15. **Removal result**
16. **Rejoin/gap result**
17. **Persistence/restart**
18. **Multi-device design**
19. **Server Delivery Service model**
20. **Bootstrap orchestration**
21. **Membership-change orchestration**
22. **Offline/liveness risks**
23. **Realtime compatibility**
24. **Server-visible metadata**
25. **Push-preview implication**
26. **Moderation implication**
27. **Recovery/key-loss questions**
28. **ADR/docs**
29. **07B2B handoff**
30. **Validation**
31. **Warnings/blockers**
32. **Commit/PR reference**
