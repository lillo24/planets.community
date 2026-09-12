# PLANETS 06C1 — Push Installation and Delivery-Job Foundation

**Roadmap area:** PLANETS 06 — Notification Backbone  
**Task type:** Provider-independent backend foundation before Firebase/mobile push integration  
**Repository:** `lillo24/planets.community`  
**Required implementation base:** latest merged `main`  
**Known merged 06B base when this prompt was written:** `c459b185a0a7f8ae78bd8587301fcc3460a851d3`

## Objective

Implement the provider-independent backend foundation for mobile push notifications without introducing Firebase SDKs, FCM credentials, APNs configuration, or real network delivery yet.

Split the previous 06C into:

- **06C1 — Push Installation and Delivery-Job Foundation** — this task;
- **06C2 — Firebase Mobile Registration and FCM Delivery Worker** — future external-provider task.

After 06C1:

- authenticated profiles can securely register/update/unregister one app installation through narrow RPCs;
- raw provider tokens remain private and are never returned to ordinary clients;
- account switching and token rotation cannot leave the same installation/token actively assigned to multiple profiles;
- push projection consumes the same canonical domain outbox independently from the in-app notification projector;
- `push_enabled` is evaluated independently from `in_app_enabled`;
- `in_app_enabled = false` and `push_enabled = true` can still create a future push delivery job;
- push-disabled source events are successfully receipted for the push consumer without creating jobs;
- one canonical recipient-level push job is created per supported source event;
- push jobs contain only safe semantic identifiers/context, never request messages/exact meeting data/raw outbox payloads/device tokens;
- notification and push consumers can independently receipt the same source event;
- historical pre-06C1 participation events are not unexpectedly queued for future push;
- no actual FCM request is sent yet;
- no Firebase package or Edge Function is introduced yet;
- no push permission UI or push preference UI is introduced yet.

Do not merge the implementation PR.

Before implementation, archive this exact prompt unchanged at:

```text
history-implementations/PLANETS_06C1_push_installation_delivery_job_foundation.md
```

---

# External context

**06C1 requires no external Firebase/provider account, config file, or secret.**

Everything in this plan must be runnable locally and in CI using synthetic provider tokens.

The later **06C2** will require external context that is not currently in the repository:

- Firebase project(s) for PLANETS environments;
- Android Firebase app configuration;
- iOS Firebase app configuration;
- APNs/Firebase iOS push setup;
- trusted FCM HTTP v1 credentials/service account or equivalent provider authorization stored as server-side secrets.

06C1 must not guess or fabricate any of those.

If implementation discovers provider-specific information is somehow required for this backend foundation, stop and report rather than embedding assumptions.

---

# Repository state and required inspection

Work from latest merged `main`.

Inspect at minimum:

1. root `AGENTS.md`;
2. `docs/architecture/core-stack.md`;
3. `docs/architecture/system-design.md`;
4. `docs/architecture/product-decisions.md`;
5. `docs/development/database.md`;
6. `docs/implementation/roadmap.md`;
7. 01B outbox primitives;
8. merged 05A participation event production;
9. merged 06A notification domain/projector/consumer receipts;
10. merged 06B notification mobile feature/docs;
11. current generated database types;
12. current local Supabase helper scripts;
13. CI workflow;
14. mobile `pubspec.yaml` only to confirm that Firebase is not yet installed.

Important current facts:

- 06A is merged.
- 06B is merged in PR #19 at `c459b185a0a7f8ae78bd8587301fcc3460a851d3`.
- 06B native QA is **deferred by the founder for a later consolidated QA pass**; do not mark it passed.
- 07A Messages is merged.
- No Firebase Flutter packages currently exist.
- No `supabase/functions` implementation currently exists.
- `private.outbox_consumer_receipts` already provides independent consumer acknowledgement.
- `notifications.v1` is the current in-app notification consumer.
- Current supported participation source events are:
  - `project.join_requested`;
  - `project.join_request_withdrawn`;
  - `project.join_request_accepted`;
  - `project.join_request_rejected`;
  - `project.participant_left`;
  - `project.participant_removed`.
- 06A semantically maps those events to recipient/kind/destination state.
- In-app projection may suppress creation when `in_app_enabled = false`.
- `push_enabled` already exists in the canonical category preference model.
- Push must therefore **not** depend on a `public.notifications` row existing.

---

# Architecture principle

Treat these as separate pipelines over one canonical domain event:

```text
private.outbox_events
        │
        ├── notifications.v1
        │      └── public.notifications
        │
        └── push.v1
               └── private push delivery job
```

The same event may be processed independently by both consumers.

Example:

```text
in_app_enabled = false
push_enabled   = true
```

Result:

```text
notifications.v1 -> receipt, no in-app notification row
push.v1          -> receipt + push delivery job
```

Do not derive push delivery from `public.notifications`.

This is a core requirement.

---

# 1. Shared semantic event resolution

Avoid duplicating the six participation-event recipient mappings in two large independent projector implementations.

Introduce/refactor a narrow private resolver equivalent to:

```text
private.resolve_participation_notification_event(outbox_event_id)
```

or another clear provider-neutral name.

It should resolve canonical semantic facts such as:

```text
category_slug
notification_kind

recipient_profile_id
actor_profile_id?

project_id?
project_kind?

request_id?
membership_id?

destination_kind
source_created_at
```

The resolver must validate source payload identifiers against canonical join request, membership, and shared project identity.

Do not trust arbitrary payload recipient/project/actor values.

## Refactor 06A safely

A forward migration may `CREATE OR REPLACE` the existing 06A projector so it uses the shared resolver.

The externally visible 06A function contract and behavior must remain unchanged.

All existing notification pgTAP/integration tests must remain green.

Do not edit the old 06A migration.

---

# 2. Private installation model

Add a private provider-registration table, naming Codex-owned, equivalent to:

```text
private.push_installations
```

This represents one PLANETS **app installation**, not a physical person/device identity.

## Installation identity

Use an opaque client-generated installation UUID:

```text
installation_id
```

Do not use Android ID, advertising ID, IMEI, serial number, hardware fingerprint, or email.

06C2 will persist a random installation UUID locally in the app.

## Fields

Keep the table narrow.

Likely concepts:

```text
installation_id
profile_id
platform              -- android | ios
provider              -- fcm
provider_token
created_at
updated_at
last_registered_at
disabled_at?
```

Exact shape is Codex-owned.

Provider token storage is private operational data.

## Token constraints

Use sensible bounded validation without trying to reverse-engineer FCM token syntax.

Require non-empty active tokens and a generous maximum length.

Do not expose token text in errors.

## Ownership / rotation invariants

- One `installation_id` has one current active profile.
- Registering the same installation under a new signed-in profile must transfer ownership atomically.
- One provider token must not remain actively assigned to multiple installations.
- Token refresh/reuse must fail safe and resolve to one active installation.

Test all of these explicitly.

---

# 3. Registration RPC

Add an authenticated operation equivalent to:

```text
register_own_push_installation(
  p_expected_profile_id,
  p_installation_id,
  p_platform,
  p_provider_token
)
```

Requirements:

- expected identity bound to `auth.uid()`;
- profile identity exists;
- valid installation UUID;
- platform currently limited to Android/iOS;
- provider server-owned/default FCM rather than arbitrary client input unless strongly justified;
- raw token stored only privately;
- idempotent same identity/install/token registration;
- token refresh updates safely;
- account-switch registration transfers installation ownership safely;
- same active token cannot remain assigned elsewhere;
- timestamps owned centrally;
- response exposes no provider token.

No Firebase dependency is needed to test this RPC; synthetic strings are sufficient.

---

# 4. Unregister RPC

Add an authenticated operation equivalent to:

```text
unregister_own_push_installation(
  p_expected_profile_id,
  p_installation_id
)
```

Requirements:

- expected identity bound;
- only current owning profile may unregister;
- safe/idempotent repeat according to chosen contract;
- unrelated profile cannot disable another user's registration;
- token becomes ineligible for delivery afterward.

Prefer privacy-minimizing behavior by clearing raw provider token when disabled if future delivery history does not require it.

06C2 will later call this around sign-out/account changes where practical.

---

# 5. No client token listing

Do not add an ordinary API that returns provider tokens.

The future Flutter client already knows its local current token and does not need the backend copy.

No client-facing token enumeration.

---

# 6. Push delivery jobs

Add a private canonical recipient-level push-job table, equivalent to:

```text
private.push_delivery_jobs
```

A job means:

> one semantic source event is eligible for push delivery to one recipient.

It is **not** one provider request and not one per-device attempt.

06C2 will fan a recipient-level job out to active installations.

## Job state

Store safe semantic data equivalent to:

```text
id
source_outbox_event_id
recipient_profile_id
category_slug
notification_kind

actor_profile_id?
project_id?
request_id?
membership_id?
destination_kind

created_at
available_at
```

Provider token must not be copied into jobs.

Raw outbox payload must not be copied into jobs.

Generic `project_id` should remain nullable for future standalone Resources/Matching alerts, while the current participation kinds retain their required reference shapes.

Do not implement future resource/chat/matching kinds now.

## Uniqueness

Enforce one canonical job per source event + recipient + semantic kind, or an equally strong invariant.

---

# 7. Push outbox consumer

Add a service-only projector equivalent to:

```text
process_push_outbox_batch(limit)
```

Use a stable consumer key equivalent to:

```text
push.v1
```

Requirements:

1. only supported six participation source types;
2. only `available_at <= now()`;
3. skip existing `push.v1` receipts;
4. concurrency-safe locking (`FOR UPDATE SKIP LOCKED` or equivalent);
5. resolve through the shared semantic resolver;
6. read effective `push_enabled`;
7. push enabled -> create exactly one recipient-level push job;
8. push disabled -> create no job;
9. record `push.v1` receipt in both cases;
10. return aggregate safe counts only.

Suggested counts:

```text
processed_count
jobs_created
jobs_suppressed
```

No network request.

Do not inspect active installations during source-event projection.

The semantic push job may exist even if there are currently zero active device installations; 06C2 owns `no_targets` delivery handling.

---

# 8. Historical source events

Do not create jobs for pre-06C1 historical participation events.

At migration time, backfill `push.v1` receipts for already-existing supported source events.

This prevents enabling push later from suddenly sending old participation alerts.

Do not touch receipts for other consumers.

---

# 9. Push preference semantics

Push projection uses only:

```text
push_enabled
```

It must not be gated by `in_app_enabled`.

Explicitly test:

```text
in_app=true,  push=true
in_app=true,  push=false
in_app=false, push=true
in_app=false, push=false
```

06C1 determines only whether a push job exists according to `push_enabled`.

Existing 06A in-app behavior remains unchanged.

Preference changes are not retroactive.

---

# 10. Installation vs job separation

Do not create one job per device during source-event projection.

06C2 should later do:

```text
claim recipient-level job
    ↓
resolve active installations
    ↓
attempt provider delivery per installation
```

This cleanly supports multiple devices, token rotation, retries, and invalid-token cleanup without changing source-event semantics.

---

# 11. No Edge Function / Firebase yet

Do not create `supabase/functions` in 06C1 merely as a placeholder.

Do not add:

```text
firebase_core
firebase_messaging
google-services.json
GoogleService-Info.plist
Firebase options
push permission UI
installation UUID persistence
token-refresh listener
```

Those belong to 06C2 together with real provider behavior/security.

Allowed mobile changes: generated types only if normal generation changes them; no UI.

---

# 12. Privacy and secrets

Never expose/log:

- provider token;
- service role/secret key;
- Firebase service-account JSON;
- request message;
- exact meeting/location;
- email;
- OTP/session tokens;
- raw outbox JSON.

Push jobs must contain semantic identifiers only.

If registration changes are audited, token text must never appear in audit metadata.

---

# 13. Security / grants

Installation and push-job tables remain private.

No direct `anon`/`authenticated` access.

Authenticated users receive only registration/unregistration RPC execution.

Push projector is service-only.

All security-definer functions:

- fixed/empty search path;
- fully qualified objects;
- explicit grants;
- fail-closed identity/role checks.

No mobile/web service-role credentials.

Index relevant active-installation, active-token, recipient-job, source-job, and receipt paths.

---

# 14. Database tests

Add comprehensive pgTAP coverage.

At minimum:

## Installation/privacy

- private installation table exists;
- no Data API grants;
- provider token absent from public generated row types/APIs;
- Android/iOS validation;
- installation uniqueness;
- active token uniqueness.

## Registration

- expected identity required;
- cross-account expected identity fails;
- same registration idempotent;
- token refresh works;
- old token no longer active;
- same installation safely transfers to another signed-in profile;
- previous profile no longer owns active registration;
- unrelated profile cannot unregister.

## Unregister

- owner can unregister;
- repeat follows chosen safe contract;
- token no longer active;
- unrelated user denied;
- no token returned.

## Push jobs/projector

- private job schema;
- semantic shape constraints;
- current six mappings correct;
- future nullable project shape preserved;
- source/recipient/kind uniqueness;
- push enabled creates one job;
- push disabled creates none but receipts;
- unsupported event untouched;
- retry/concurrency no duplicates.

## Channel independence

Prove specifically:

```text
in_app=false, push=true
```

creates a push job.

Prove:

```text
in_app=true, push=false
```

does not.

Existing in-app notification behavior remains green.

## Multi-consumer

Same event may independently have:

```text
notifications.v1
push.v1
future consumer
```

receipts.

---

# 15. Real local integration

Add:

```text
scripts/verify-local-push-foundation.mjs
```

using synthetic provider tokens.

Prove:

1. B registers installation X/token T1;
2. repeat is idempotent;
3. B rotates X to T2;
4. T1 is no longer active;
5. C registers X and ownership transfers safely;
6. B cannot unregister C's X;
7. C unregisters X;
8. register active target again;
9. create supported participation event;
10. recipient has `in_app=false`, `push=true`;
11. in-app channel can be suppressed independently;
12. push projector creates one job;
13. job contains no raw token/request message/exact meeting/raw source payload;
14. retry creates no duplicate;
15. push disabled on later event suppresses job but receipts;
16. `notifications.v1` and `push.v1` coexist;
17. unsupported source event receives no push receipt.

Do not print synthetic token values.

---

# 16. Local trusted projector helper

If useful add:

```text
npm run push:project:local
```

The helper may invoke the service-only push projector using local Supabase status credentials.

It must print aggregate counts only and never be called by Flutter.

---

# 17. Existing validation

Keep green:

- migration replay;
- DB lint;
- all pgTAP;
- Auth/profile/Proposal/Tavolo integrations;
- participation integration;
- notification integration;
- Messages integration;
- new push-foundation integration;
- generated type drift;
- Flutter localization/format/analyze/tests;
- Web tests/lint/typecheck/build;
- `git diff --check`.

No Firebase account required.

---

# 18. Deferred product note — requested projects in Browse

Record this accepted future UX direction in product/roadmap documentation only:

> When an authenticated user has a **pending join request** for a Project/Tavolo, discovery should surface that item ahead of ordinary results where practical and visually distinguish it (for example with a `Requested` badge and/or special border), so pending state is visible without opening detail.

Constraints:

- applies to pending requests, not merely historical rejected/withdrawn requests;
- exact ranking relative to owned/current-participation projects remains later UX work;
- signed-out/public ordering should not be changed here;
- do not implement list enrichment or extra RPC calls in 06C1.

---

# 19. Roadmap reconciliation

Mark:

```text
06B — Implemented
PR #19
c459b185a0a7f8ae78bd8587301fcc3460a851d3
```

Record:

```text
06B native QA — deferred by founder for later consolidated QA; not passed/failed
```

Split:

```text
06C — Push Delivery (parent) — In progress
06C1 — Push Installation and Delivery-Job Foundation — In progress
06C2 — Firebase Mobile Registration and FCM Delivery Worker — Not started
```

Keep:

```text
07A — Implemented
07B — Not started
04C — Not started
05C — Not started
```

Do not mark 06C parent complete after 06C1.

---

# 20. 06C2 external-context handoff

Document that 06C2 requires:

- Firebase Android/iOS app configuration;
- APNs/Firebase iOS setup;
- real push permission timing decision;
- safe push-preview policy;
- server-side FCM HTTP v1 credentials stored as secrets.

06C2 will own:

## Flutter

- current official Firebase Messaging integration;
- random installation UUID persistence;
- OS notification permission;
- FCM `getToken()` and token-refresh lifecycle;
- register/unregister RPC calls;
- sign-in/account-switch handling;
- foreground/background/opened-notification behavior;
- push preference UI.

## Trusted worker

- Supabase Edge Function/worker;
- server-side secrets only;
- claim push jobs;
- resolve active installations;
- per-installation attempts;
- FCM HTTP v1 OAuth/send;
- retries/backoff/idempotency;
- invalid-token cleanup;
- safe previews/data payloads;
- `no_targets`;
- environment safeguards.

Do not implement these in 06C1.

---

# Non-goals

Do not implement:

- Firebase Flutter SDK;
- FCM/APNs network delivery;
- Firebase config files;
- Edge Functions;
- provider credentials;
- push permission/preference UI;
- foreground/background push handling;
- delivery attempts/provider errors;
- group chat;
- chat/resource/matching notification kinds;
- requested-project Browse highlighting itself;
- 04C/05C;
- final navigation redesign.

---

# Acceptance criteria

06C1 is ready when:

- [ ] based on merged PR #19 main;
- [ ] exact prompt archived;
- [ ] no Firebase/provider account needed;
- [ ] shared semantic resolver prevents mapping drift;
- [ ] 06A notification behavior remains unchanged;
- [ ] private installation model exists;
- [ ] raw provider token never appears in ordinary public API/types;
- [ ] register/unregister are expected-identity-bound;
- [ ] same installation transfers safely on account switch;
- [ ] token rotation leaves one active assignment;
- [ ] unrelated profile cannot unregister another active installation;
- [ ] recipient-level private push-job model exists;
- [ ] jobs contain no token/private content/raw source JSON;
- [ ] `push.v1` is independent from `notifications.v1`;
- [ ] push projector service-only/concurrency-safe/idempotent;
- [ ] push-disabled event is receipted without job;
- [ ] `in_app=false, push=true` still creates push job;
- [ ] old supported events are not queued;
- [ ] no Firebase/Edge Function/mobile push code;
- [ ] pgTAP/integration coverage passes;
- [ ] existing CI green;
- [ ] requested-project Browse note preserved;
- [ ] roadmap records 06C1/06C2 and deferred 06B native QA;
- [ ] PR remains unmerged.

---

# Autonomy and stop conditions

Codex may decide exact private table names, registration return type, unregister retention strategy, token max length, shared resolver signature, push-job indexes, and local helper naming.

Stop and report before:

- adding Firebase packages/config;
- creating Edge Functions;
- storing provider secrets in repo;
- exposing provider tokens;
- deriving push jobs from `public.notifications`;
- gating push on `in_app_enabled`;
- implementing per-device provider attempts;
- implementing requested-project Browse UI;
- implementing group chat;
- merging the PR.

---

# Deliverables

Produce:

1. exact archived 06C1 prompt;
2. shared semantic participation-event resolver;
3. refactored 06A projector without behavior drift;
4. private installation schema;
5. register/unregister RPCs;
6. private recipient-level push-job schema;
7. `push.v1` projector;
8. historical rollout receipts;
9. pgTAP security/channel-independence tests;
10. real local push-foundation integration;
11. optional safe local push-projector helper;
12. generated DB types;
13. architecture/database/roadmap docs;
14. deferred requested-project Browse UX note;
15. explicit 06C2 external-context handoff;
16. focused PR, preferably `codex/06c1-push-installation-delivery-foundation`;
17. structured completion report.

Do not merge the PR.

---

# Completion report

Return:

1. **Summary**
2. **Branch/base/PR**
3. **Changed files**
4. **Shared semantic resolver**
5. **06A projector regression**
6. **Installation schema**
7. **Registration RPC**
8. **Token rotation**
9. **Account-switch installation transfer**
10. **Unregister behavior**
11. **Provider-token privacy**
12. **Push job schema**
13. **Push event mapping**
14. **push.v1 consumer receipts**
15. **Push preference semantics**
16. **In-app/push independence**
17. **Historical rollout**
18. **Concurrency/idempotency**
19. **Security/grants**
20. **pgTAP tests**
21. **Real local integration**
22. **Generated types/drift**
23. **Regression validation**
24. **06B roadmap/deferred-QA reconciliation**
25. **Requested-project Browse note**
26. **06C2 external context required**
27. **06C2 handoff**
28. **Warnings/blockers**
29. **Commit/PR reference**
