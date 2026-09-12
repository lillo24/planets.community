# PLANETS 06C2A — Push Delivery Attempt and Worker-Protocol Foundation

**Roadmap area:** PLANETS 06 — Notification Backbone / Push Delivery  
**Task type:** Provider-independent trusted-worker protocol before Firebase integration  
**Repository:** `lillo24/planets.community`  
**Required implementation base:** latest merged `main`  
**Known merged 06C1 base when this prompt was written:** `f7b88ee61c2471fcb4bff04e968403886dff1e27`

## Objective

Implement the remaining **provider-independent delivery mechanics** between recipient-level push jobs and a future real provider adapter.

06C1 already owns:

- private app-installation registration;
- private FCM token storage;
- independent `push.v1` semantic job projection;
- recipient-level push jobs;
- push/in-app preference independence.

06C2A should now add a secure, crash-safe service-worker protocol that can:

1. expand one recipient-level push job into the recipient's active app installations;
2. claim per-installation delivery work with leases;
3. expose the current provider token only to a trusted service-role worker;
4. record generic provider outcomes without storing raw tokens;
5. retry transient failures safely;
6. invalidate a stale provider token without accidentally disabling a newer rotated token;
7. mark jobs complete once all snapshotted targets are terminal;
8. handle recipients with no active installations;
9. retain delivery-attempt history for later operational/admin analysis.

No Firebase SDK, FCM HTTP request, APNs setup, Edge Function, provider credential, or mobile push code should be added yet.

Split the remaining provider-specific plan into:

- **06C2A — Push Delivery Attempt and Worker-Protocol Foundation** — this task;
- **06C2B — Firebase Mobile Registration and FCM Adapter** — later, external-provider context required.

Do not merge the implementation PR.

Archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_06C2A_push_delivery_attempt_worker_protocol.md
```

---

# External context

**06C2A requires no Firebase project, config file, APNs setup, or provider secret.**

Use synthetic provider tokens and simulated generic provider outcomes in tests.

06C2B will require external context:

- Firebase Android/iOS app configuration;
- APNs/Firebase iOS setup;
- FCM HTTP v1 server credentials;
- push permission timing;
- final safe-preview policy.

Do not guess any of those in 06C2A.

---

# Repository state and required inspection

Work from latest merged `main`.

Inspect at minimum:

1. root `AGENTS.md`;
2. 06A notification migration/tests;
3. merged 06C1 migration/tests/integration;
4. `private.push_installations`;
5. `private.push_delivery_jobs`;
6. `process_push_outbox_batch`;
7. `register_own_push_installation`;
8. `unregister_own_push_installation`;
9. local trusted push helper scripts;
10. generated DB types;
11. database/security documentation;
12. roadmap;
13. CI.

Important current facts:

- PR #19 / 06B is merged; native QA remains deferred by founder for a later consolidated pass.
- PR #20 / 06C1 is merged at:

```text
f7b88ee61c2471fcb4bff04e968403886dff1e27
```

- Exact 06C1 PR head CI was green across Database/Mobile/Web before merge.
- `push.v1` creates **recipient-level** semantic jobs independently from `notifications.v1`.
- Push jobs do not contain provider tokens.
- Active provider tokens live only in `private.push_installations`.
- Same installation can transfer account ownership.
- Token rotation/reuse leaves one active token assignment.
- `in_app=false, push=true` is explicitly supported.
- 06C1 deliberately does **not** create per-device provider attempts.
- There is still no Firebase package and no `supabase/functions` directory.
- Production direction is now **self-hosted Supabase**, with production infrastructure provisioning deferred until after the main feature/UI work.
- Managed Supabase may still be used for development, staging, testing, or migration rehearsal.
- 06C2A must remain compatible with the repository's local/self-hosted Supabase direction and must not introduce managed-cloud-only assumptions.
- Do not change those facts in 06C2A.

---

# Architecture

The intended pipeline after this task is:

```text
domain outbox event
      ↓
push.v1
      ↓
recipient-level push_delivery_job
      ↓
fan-out snapshot
      ↓
per-installation push_delivery_target
      ↓
trusted worker claim (lease + claim ID)
      ↓
provider adapter sends
      ↓
record generic result
      ↓
attempt history / retry / terminal state
```

06C2B will implement only the final provider-facing portions:

```text
Firebase token acquisition in Flutter
FCM HTTP v1 send in trusted server runtime
provider-specific error classification
```

Do not collapse recipient jobs and installation attempts into one table.

---

# 1. Installation token generation/version

A provider send may fail after the installation token has already rotated.

If a stale send receives an `invalid_token` result, the backend must **not** disable the newly refreshed token.

Extend `private.push_installations` with a monotonic token-generation/version concept, equivalent to:

```text
token_version bigint
```

Requirements:

- positive while active;
- increments whenever the stored provider token changes;
- remains stable for idempotent re-registration with the same token;
- account ownership transfer with the same token does not needlessly increment unless implementation semantics justify it;
- reactivation with a new token advances the version;
- never exposed to ordinary clients unless a non-secret registration response genuinely needs it; prefer not.

The trusted worker claim may return the token version together with the raw token.

Result recording must use it to protect invalid-token cleanup.

Do not store raw historical tokens.

---

# 2. Delivery target snapshot

Add a private per-installation target table, equivalent to:

```text
private.push_delivery_targets
```

A target means:

> this recipient-level push job was assigned to this installation at fan-out time.

At minimum preserve:

```text
id
job_id
installation_id
platform
provider

status
available_at

attempt_count
created_at
updated_at
completed_at?

lease_owner?
lease_id?
lease_expires_at?
```

Exact schema is Codex-owned.

## Target uniqueness

One target per:

```text
job_id + installation_id
```

No duplicate fan-out.

## No token copy

Do not store `provider_token` on the target.

At claim time, resolve the installation's **current active token**.

## Snapshot semantics

Fan-out should snapshot the set of active installations once per recipient-level job.

A device registered after fan-out should not receive an old push event.

A device removed after fan-out may make its target terminal as no-longer-registered before provider send.

Document this explicitly.

---

# 3. Job lifecycle extension

Extend `private.push_delivery_jobs` with only the lifecycle data needed by the trusted worker protocol.

Concepts may include:

```text
fanout_at?
completed_at?
completion_reason?
```

Potential completion reasons:

```text
delivered_or_terminal
no_targets
```

Exact representation is Codex-owned.

Do not add provider-specific error state to the recipient-level job.

A job is complete when:

- fan-out found zero active targets; or
- every snapshotted target is terminal.

The job should not be re-fanned-out after completion.

---

# 4. Fan-out operation

Add a service-only operation equivalent to:

```text
prepare_push_delivery_jobs(p_limit)
```

or combine preparation safely into the claim function if simpler.

Responsibilities:

1. select recipient-level jobs not yet fanned out;
2. concurrency-safe locking;
3. snapshot all currently active installations for the recipient;
4. create one target per installation;
5. if zero installations:
   - mark job completed;
   - completion reason = no targets;
6. mark fan-out complete;
7. return aggregate safe counts.

Suggested results:

```text
jobs_prepared
targets_created
jobs_without_targets
```

Do not return tokens here.

Do not re-open `no_targets` jobs if a device registers later.

That push event is historical at that point.

---

# 5. Target statuses

Use a small provider-independent state model equivalent to:

```text
pending
delivered
invalid_token
permanent_failure
no_longer_registered
```

A transient failure should normally return the target to `pending` with a future `available_at`, while preserving attempt history.

Do not add provider-specific statuses such as FCM's raw error strings as state-machine values.

Terminal states:

- delivered;
- invalid_token;
- permanent_failure;
- no_longer_registered.

Non-terminal:

- pending.

A lease is operational metadata, not a separate user-visible status.

---

# 6. Trusted claim protocol

Add a service-only function equivalent to:

```text
claim_push_delivery_targets(
  p_worker_id text,
  p_limit integer,
  p_lease_seconds integer
)
```

Exact signature may use UUID worker IDs if cleaner.

Requirements:

- service-role only;
- pending targets with `available_at <= now()`;
- expired/no lease only;
- concurrency-safe `FOR UPDATE SKIP LOCKED`;
- bounded limit;
- bounded lease duration;
- creates fresh opaque `lease_id` / claim token for each claimed target;
- increments attempt counter at the correct semantic point;
- sets lease expiry;
- returns only what a trusted provider worker needs.

Returned trusted fields may include:

```text
target_id
job_id
lease_id

installation_id
platform
provider
provider_token
token_version

notification_kind
destination_kind
project_id?
project_kind?
request_id?
membership_id?
actor_profile_id?
recipient_profile_id
```

Raw provider token is allowed **only** in this service-role result.

It must never appear in public client APIs/generated ordinary app types/logs.

---

# 7. Inactive installation at claim time

A target may have been created while the installation was active but claimed after:

- unregister;
- account transfer;
- token removal;
- installation ownership no longer matches the job recipient.

The claim protocol must not return a stale/ineligible token.

Preferred behavior:

- atomically mark target `no_longer_registered`;
- clear lease;
- do not return it to the worker;
- reevaluate job completion;
- continue claiming other eligible targets.

Do not deliver to an installation whose current owner is no longer the job recipient.

This is especially important after account switching.

---

# 8. Attempt history

Add a private append-oriented table equivalent to:

```text
private.push_delivery_attempts
```

At minimum preserve safe operational facts:

```text
id
target_id
attempt_number
lease_id
started_at
finished_at?
outcome?
provider_message_id?
provider_error_code?
retry_available_at?
```

No raw token.

No raw provider response body.

No request message/exact location.

## Attempt creation

An attempt row should be created as part of target claim, or otherwise atomically before provider send.

This makes crashed/incomplete worker activity observable.

## Provider metadata

Permit bounded sanitized identifiers such as:

- provider message ID;
- provider error code.

Do not allow arbitrary large error/body text.

06C2B will map actual FCM results into these generic fields.

---

# 9. Record result operation

Add a service-only operation equivalent to:

```text
record_push_delivery_result(
  p_target_id,
  p_lease_id,
  p_token_version,
  p_outcome,
  p_provider_message_id?,
  p_provider_error_code?,
  p_retry_after_seconds?
)
```

Exact signature is Codex-owned.

Allowed generic outcomes:

```text
delivered
invalid_token
transient_failure
permanent_failure
```

## Lease safety

Result is accepted only if:

- target is currently leased;
- `lease_id` matches;
- lease has not been superseded by a later claim.

A stale worker must not overwrite a newer attempt.

Whether an expired but not yet re-claimed lease can submit a result is Codex-owned; choose one deterministic policy and test it.

## Delivered

- attempt terminal delivered;
- target delivered;
- clear lease;
- reevaluate job completion.

## Permanent failure

- attempt terminal;
- target permanent_failure;
- clear lease;
- reevaluate job completion.

## Invalid token

- attempt terminal;
- target invalid_token;
- clear lease;
- disable/clear installation token **only when**:
  - installation is still active;
  - its current token_version equals the claimed token_version;
  - installation still corresponds to that target/recipient.

If the token rotated after claim, do not disable the new token.

Reevaluate job completion.

## Transient failure

- attempt records transient failure;
- target returns to pending;
- clear lease;
- schedule future `available_at`;
- no job completion yet.

Require bounded positive retry delay.

Do not invent provider-specific exponential backoff in SQL.

06C2B may choose the delay based on provider response and attempt count.

---

# 10. Crash / lease recovery

A worker can crash after claim.

Expired leases must make non-terminal targets claimable again.

The new claim receives a new `lease_id` and creates a new attempt row.

An old worker response using the previous lease ID must fail safely.

Do not require a cleanup cron just to make leases recoverable.

The claim query itself should recognize expired leases.

---

# 11. Job completion

After every target terminal transition, recompute or safely determine whether all targets are terminal.

When all are terminal:

```text
push_delivery_jobs.completed_at = now()
```

and completion reason should reflect ordinary terminal completion.

The job remains historical.

Do not delete targets/attempts.

Do not mark the original outbox event differently; `push.v1` already represents semantic projection success.

Provider delivery outcome is downstream operational state.

---

# 12. No automatic source-job retry

Do not recreate or mutate `push.v1` source receipts based on delivery failure.

Distinguish:

```text
source event projected successfully
```

from:

```text
provider delivery succeeded
```

Once `push.v1` created the recipient job and receipt, provider retries occur entirely inside the delivery job/target/attempt layer.

This separation is essential.

---

# 13. Service grants and secret boundary

All preparation/claim/result functions are service-role-only.

Ordinary authenticated users:

- cannot inspect push jobs;
- cannot inspect targets;
- cannot inspect attempts;
- cannot claim work;
- cannot record delivery;
- cannot read provider tokens.

`register_own_push_installation` and `unregister_own_push_installation` remain the only push-installation client mutations.

No service role in Flutter/web.

No Edge Function yet.

When 06C2B later introduces the trusted provider adapter, it may use a **repository-owned Supabase Edge Function or equivalent trusted worker** as long as it runs against the supported local/self-hosted Supabase environment. Do not make Supabase Cloud deployment, dashboard-only configuration, or a managed control plane a product invariant.

---

# 14. Local fake worker

Add a local trusted integration helper capable of simulating provider outcomes without network access.

Prefer:

```text
scripts/verify-local-push-delivery-protocol.mjs
```

Optionally add a simple operator helper if useful, but do not build a fake production worker.

The integration should use synthetic provider tokens internally and never print them.

---

# 15. Database tests

Add comprehensive pgTAP coverage.

At minimum:

## Token version

- same-token idempotent registration keeps stable version;
- token rotation increments version;
- reactivation/new token advances appropriately;
- ordinary client cannot read version/raw token from private table.

## Fan-out

- one target per active installation;
- multiple installations produce multiple targets;
- zero installations completes job as no_targets;
- repeated/concurrent preparation does not duplicate targets;
- later device registration does not reopen a completed/fanned-out job.

## Account transfer

- target belonging to recipient A becomes no_longer_registered if installation transfers to B before claim;
- no token returned to worker for wrong current owner.

## Claim

- service only;
- lease IDs unique/fresh;
- concurrency prevents double claim;
- token returned only through trusted claim function;
- attempt row created;
- claim increments attempt number correctly.

## Result

- delivered terminal;
- permanent failure terminal;
- transient failure requeues with future availability;
- invalid token disables matching current token;
- stale token version does not disable rotated token;
- wrong/stale lease rejected;
- old lease cannot overwrite later attempt.

## Crash recovery

- expired lease can be reclaimed;
- fresh lease differs;
- previous lease result rejected.

## Job completion

- not complete while any target pending;
- completes when all targets terminal;
- no-target completion;
- attempts/history retained.

## Privacy/grants

- no client table access;
- no raw token in target/job/attempt;
- bounded provider metadata only;
- client cannot execute worker functions.

---

# 16. Real local integration scenarios

Using local Supabase and synthetic tokens, prove:

1. recipient has two active installations;
2. supported participation event creates one recipient job via existing `push.v1`;
3. prepare creates two targets;
4. worker A claims target 1;
5. worker B cannot claim same leased target;
6. target 1 records delivered;
7. target 2 claims and records transient failure;
8. target 2 becomes pending with future availability;
9. trusted test advances/reaches retry eligibility;
10. target 2 is reclaimed with a different lease;
11. stale first lease result fails;
12. current retry records delivered;
13. job completes;
14. attempt history contains all tries without token material;
15. separate case: claim token version N, rotate installation to N+1, then record invalid_token for old attempt;
16. new token remains active;
17. separate case: transfer installation to another account before claim;
18. target becomes no_longer_registered and is never returned with token;
19. zero-installation recipient job completes no_targets;
20. existing 06A/06C1 behavior remains intact.

Do not print provider tokens, OTPs, request messages, exact location, or service credentials.

---

# 17. No Firebase / network work

Do not add:

- Firebase packages;
- Firebase config files;
- FCM HTTP calls;
- APNs setup;
- Edge Functions;
- OAuth/service-account code;
- OS permission UI;
- background message handlers;
- provider-specific error parsing.

06C2B owns those.

---

# 18. No mobile user-facing change

06C2A is backend/trusted-worker protocol only.

Do not alter notification inbox UI, push preference UI, Home badge, Messages, or bottom navigation.

Generated types may change only for public RPCs if required; ideally worker RPCs remain service-only and do not expand ordinary app API surface unnecessarily.

---

# 19. Requested-project Browse note

Preserve the previously recorded deferred UX requirement:

> Pending-request Projects/Tavoli should later be surfaced ahead of ordinary discovery items where practical and visually distinguished (for example `Requested` badge/special border).

Do not implement it here.

Do not remove or weaken the existing product/roadmap note.

---

# 20. Roadmap reconciliation

Mark:

```text
06C1 — Implemented
PR #20
f7b88ee61c2471fcb4bff04e968403886dff1e27
```

Keep 06B QA status:

```text
native QA deferred by founder for later consolidated pass
```

Restructure:

```text
06C — Push Delivery (parent) — In progress

06C1 — Push Installation and Delivery-Job Foundation — Implemented

06C2 — Provider Delivery Integration (parent) — In progress
06C2A — Push Delivery Attempt and Worker-Protocol Foundation — In progress
06C2B — Firebase Mobile Registration and FCM Adapter — Not started
```

06C2B still requires founder/external provider context.

The eventual production Supabase runtime is intended to be **self-hosted**. 06C2B must therefore keep its trusted worker source in the repository, use environment/runtime-injected secrets, and avoid hard-coded managed Supabase project identity. Provisioning the production VPS/Docker/TLS/DNS/backups/monitoring/scheduler is explicitly outside 06C2B and remains deferred to the later infrastructure phase.

Do not mark 06 parent complete.

---

# 21. 06C2B handoff

After 06C2A, actual provider implementation should be narrow.

06C2B will:

## Flutter

- add then-current official Firebase Core/Messaging packages;
- configure Android/iOS Firebase apps;
- persist random installation UUID;
- obtain/request notification permission at agreed timing;
- get FCM token and subscribe to token refresh;
- call existing register/unregister RPCs;
- handle account switching;
- handle notification-open navigation using existing semantic destinations;
- finally expose push preference UI.

## Trusted server adapter

- introduce a **repository-owned Supabase Edge Function / trusted worker compatible with local and self-hosted Supabase**;
- keep the canonical job/target/attempt state database-backed and portable;
- do not require the Supabase Cloud dashboard, a managed scheduler, project-ref-specific APIs, or `*.supabase.co` endpoints as product invariants;
- define/document required secret/environment-variable names in the repository, but inject real FCM credentials only through the trusted runtime; never ship them to Flutter;
- keep production worker/scheduler deployment configuration deferred to the later self-hosting infrastructure phase;
- call the 06C2A claim function;
- send the FCM HTTP v1 request;
- classify the FCM result into:
  - delivered;
  - invalid_token;
  - transient_failure;
  - permanent_failure;
- call the 06C2A record-result RPC;
- choose retry delay;
- never persist/log raw provider token unnecessarily;
- prove the delivery component can run locally against the repository's Supabase development stack without managed-cloud-only APIs.

06C2A should leave this adapter mechanically straightforward.

---

# Non-goals

Do not implement:

- Firebase/FCM network adapter;
- Edge Function;
- provider credentials;
- mobile Firebase token lifecycle;
- OS push permission;
- push settings UI;
- project chat;
- resource/matching/chat notification kinds;
- requested-project Browse UI;
- 04C/05C;
- final navigation redesign;
- production self-hosted Supabase provisioning, VPS/Docker setup, TLS/DNS, backups, production monitoring, or production database migration.

---

# Acceptance criteria

06C2A is ready when:

- [ ] based on merged PR #20 main;
- [ ] exact prompt archived;
- [ ] 06C1 marked implemented;
- [ ] token version protects rotation races;
- [ ] recipient job fan-out snapshots active installations once;
- [ ] zero-target job completes safely;
- [ ] per-installation targets contain no raw token;
- [ ] service-only claim returns current token + version;
- [ ] claim leases prevent double delivery;
- [ ] attempts are append-oriented and token-free;
- [ ] delivered/permanent/invalid/no-longer-registered terminal behavior works;
- [ ] transient failure requeues;
- [ ] expired lease is reclaimable;
- [ ] stale lease cannot record over newer claim;
- [ ] invalid old token result cannot disable rotated token;
- [ ] account transfer prevents delivery to wrong profile installation;
- [ ] job completes only after all targets terminal;
- [ ] provider delivery failure never rewrites `push.v1` source receipt;
- [ ] no Firebase/Edge Function/mobile UI added;
- [ ] pgTAP/integration coverage passes;
- [ ] existing Mobile/Web/Database CI stays green;
- [ ] deferred Browse note preserved;
- [ ] roadmap records 06C2A/06C2B split;
- [ ] 06C2B handoff is explicitly compatible with local/self-hosted Supabase and does not require managed-cloud-only APIs/control-plane features;
- [ ] no hard-coded managed Supabase endpoint/project identity is introduced;
- [ ] production self-hosting infrastructure remains out of scope;
- [ ] PR remains unmerged.

---

# Autonomy and stop conditions

Codex may decide:

- exact job/target/attempt lifecycle column names;
- whether target claim and fan-out are separate or one safe operation;
- worker-ID type;
- lease duration bounds;
- generic provider metadata limits;
- token-version initialization/increment details;
- exact no-target completion label.

Stop and report before:

- adding Firebase packages/config;
- creating Edge Functions in 06C2A;
- introducing a managed-Supabase-only scheduler/secret/control-plane dependency;
- hard-coding `*.supabase.co`, project refs, or production cloud resource identifiers;
- expanding this task into production self-hosting infrastructure;
- making network requests;
- storing raw tokens in attempts/targets/jobs;
- letting authenticated clients call worker functions;
- disabling a newer token because of an old invalid-token result;
- implementing Browse highlighting;
- implementing group chat;
- merging the PR.

---

# Deliverables

Produce:

1. exact archived 06C2A prompt;
2. token-generation/version extension;
3. delivery-target schema;
4. delivery-attempt history schema;
5. recipient-job fan-out lifecycle;
6. service-only preparation/claim protocol;
7. crash-safe leases/claim IDs;
8. result-recording protocol;
9. transient retry behavior;
10. invalid-token rotation-safe cleanup;
11. job completion/no-target logic;
12. pgTAP security/state/race tests;
13. real local fake-worker integration;
14. generated types/drift validation;
15. architecture/database/roadmap docs;
16. explicit 06C2B provider handoff;
17. focused PR, preferably `codex/06c2a-push-delivery-worker-protocol`;
18. structured completion report.

Do not merge the PR.

---

# Completion report

Return:

1. **Summary**
2. **Branch/base/PR**
3. **Changed files**
4. **06C1 status reconciliation**
5. **Token version design**
6. **Job lifecycle extension**
7. **Delivery target model**
8. **Attempt history model**
9. **Fan-out semantics**
10. **Zero-target behavior**
11. **Claim/lease protocol**
12. **Trusted token exposure boundary**
13. **Delivered result**
14. **Transient retry**
15. **Permanent failure**
16. **Invalid-token cleanup**
17. **Rotation-race protection**
18. **Account-transfer protection**
19. **Crash recovery**
20. **Job completion**
21. **Security/grants/privacy**
22. **pgTAP tests**
23. **Real local fake-worker integration**
24. **Generated types/drift**
25. **Regression validation**
26. **Deferred Browse note preservation**
27. **06C2B external context**
28. **06C2B handoff**
29. **Warnings/blockers**
30. **Commit/PR reference**
