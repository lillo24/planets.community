# PLANETS MOCK01 — Isolated mock backend and fictional test world

Prepared: 21 October 2026. Repository: `lillo24/planets.community`.
Inspected source: `b3fccd795b805d50ac0e47815418f01a51dc54c1` on `main`.
This is an implementation prompt, not a report that provisioning has happened.

## Read and execute the three-plan package

Read this file, `02_MOCK02_Safe_Mode_And_Session_Switching.md` and `03_MOCK03_Persona_Login_And_Final_Integration.md` before coding. Implement **MOCK01 → MOCK02 → MOCK03**, sequentially, then merge one cumulative integration PR. Do not stop between ordinary completed stages to request another instruction.

Use one isolated branch/worktree per stage, or the execution environment's equivalent managed isolation. MOCK01 starts from fresh `origin/main`; MOCK02 starts from MOCK01's verified head; MOCK03 starts from MOCK02. Push draft stage PRs targeting their predecessors, with the first targeting main. No stage merges independently. Reconcile fresh main, run the final gates in MOCK03, then merge the cumulative PR through the normal repository workflow. Do not push implementation code directly to main. The direct commits that archived these prompts authorize documentation only.

Read root/nested `AGENTS.md`, `docs/development/codex-tooling.md`, `implementation_plan_sections_suggestions.md`, architecture, affected feature maps and actual pinned dependencies. Preserve later main changes and other agents' branches, services, databases and devices. Use focused checks between stages and one complete final-source gate; do not repeatedly run full native/database campaigns after each small edit.

## Product outcome and accepted direction

Closed testers can use **Settings → Sandbox → Mock Mode: Yes/No**, initially No. No means the normal app and its existing users; Yes means a separate fictional community using the real PLANETS domain logic, not merely filtered cards or fake successful buttons. No additional mock ribbons, card tags, permanent banners or forced DEMO watermark are requested. Existing functional labels remain.

When active, Help (`?`) gains **Mock Accounts**. The tester selects a fictional persona, taps **Log in**, and returns to Home with that persona's actual mock-backend session, without manual logout, email or OTP entry. Names and fictional email addresses may be shown/copied there, but automatic switching is the primary path. Turning Mock Mode off returns to the tester's normal account, if its session remains valid.

Use one shared fictional community for this first version, rather than per-tester database copies. Different testers can therefore observe one another's test changes. Explain that once in the account-selection screen; do not add labels to every card. Testers do not receive database administrator or global staff credentials. Ordinary Group/Project organizer roles are legitimate fixture roles.

## Verified starting point

- `apps/mobile/lib/core/backend/supabase_backend.dart` initializes one Supabase singleton from compile-time configuration and exposes it through `supabaseClientProvider`; dynamic environment selection is new work.
- `apps/mobile/lib/features/auth/README.md` describes real OTP/provider session restoration, profile readiness and identity-revision fences. Do not replace that with a client-only signed-in flag. The inspected versions are supabase_flutter 2.17.2 / GoTrue 2.27.2; verify lockfiles at execution.
- `apps/mobile/tool/staging_distribution.dart` requires staging and `ENABLE_DEMO_TOOLS=false`. Keep that old-demo safeguard. Mock Mode gets a separate closed-test capability, not an indiscriminate enablement of old demo tools.
- Settings already owns Sandbox and installation preferences; Help owns `/help`. Activities Split Mode is independent and must remain intact.
- `docs/development/demo-data.md`, `scripts/lib/demo-world.mjs`, `scripts/demo-assets/` and the existing local seed/verify commands contain reusable fictional personas and scenarios. **Those commands deliberately reject hosted targets. Do not remove that protection.**
- C and D/M are merged, including Group General/Ideas, room invitations, conversion, representative contacts and Group-scoped member conversations. Use their current approved contracts, not the superseded provisional C00 invitation/history model.
- The normal hosted test project is `planets-staging`, ref `cllpvruvrrvxczjitlqd`. It is a protected non-mock target, even though it is called staging. A previous inspection found a schema gap there; recheck before making any release claim. These plans do not authorize deploying its pending migrations.

## Scope of MOCK01

Implement the mock environment's reproducible schema/data setup, non-destructive seed and verifier, persona registry, tester entitlement and a narrow server-side persona-session broker. Establish and test their concrete interfaces here so MOCK02 can use real sessions; MOCK03 owns the complete account-picker UI and cumulative verification.

### 1. Strict environment separation

Use a **different Supabase project**, with independent Auth, database, Storage, Realtime and secrets. Do not use an `is_mock` column/filter across the normal database, clone real users/content, share signing/admin secrets, or repurpose an existing staging project.

The mock target runs the same reviewed product migrations/domain contracts as the selected app source. Keep fictional fixtures and mock-control provisioning separately and explicitly invoked, so ordinary production/staging migration application cannot seed mock identities or activate an impersonation endpoint. Follow current schema conventions; no broad product-RPC rewrite is required.

Build setup/seed/verify commands with a dry-run inventory and guards that require the exact recorded mock project ID, an operator-created mock environment marker and the expected schema fingerprint. Deny `cllpvruvrrvxczjitlqd`, every configured normal/production origin, unknown targets and accidental equal normal/mock origins. A permissive `--force` or name containing “test” is not proof. Check the target again before mutations and record sanitized outcome evidence.

Do not reset a hosted database. Re-running the seed preserves stable fixture IDs and deliberate tester edits, fills demonstrably missing fixture records, and reports unexpected drift. No periodic or startup reseeding. A destructive shared-world reset is not part of this package; document recovery rather than quietly deleting everyone else's test progress.

### 2. Functional fictional community

Reuse the existing Giulia, Marco, Sara, Dario and Elena personas where useful, plus only the additional ordinary personas needed to exercise multiple Group roles. Maintain an operator-controlled mapping from stable persona key to exact mock Auth UUID, fictional email and display metadata. No wildcard email-domain check qualifies an arbitrary account as a persona. Exclude the local demo staff/reviewer identity from the tester selector.

Create ready profiles and appropriate synthetic avatars through the canonical paths; preserve a photo-free invitation case. Reuse licensed bundled covers. Seed a small coherent world including:

- Two registered Groups with distinguishable Creator/Co-creator/Co-organizer/member/unjoined roles; General and Ideas with current approved visibility/consent rules.
- An Idea being planned, a published Project, a Tavolo and a meaningful completed/history case, with finite future dates anchored once per fixture generation.
- Pending and accepted participation, private conversations, mock messages/unread state, named links and representative/member contact cases that respect actual consent.
- Donation/exchange examples and reusable templates without fabricating real civic activity or payment.

Use ordinary authenticated mock-persona RPCs for domain actions, permissions, admission, chat and Storage. Auth administration may provision synthetic users, but do not bypass RLS or insert fake membership/notification success merely to make the UI look populated. Trusted fixture maintenance must be narrow, mock-only, traceable and never suppress production triggers. Do not port historical local-only trigger-disabling repairs into a hosted seeder.

Verification reads canonical results without repairing them: exact personas, role separation, visible public objects, private denials, eligible invitations, real persisted messages, usable media and stable repeat-seed behavior. Fixtures must not depend on hardcoded counts of unrelated real data.

### 3. Tester access and narrow session broker

Closed-build visibility is UX, not server authorization. Make this available to **all enrolled closed testers**, not only the founder, while authenticating each operator independently of the shared persona.

Use the tester's ordinary verified normal-staging identity as the control identity. Maintain a private, operator-managed mock-access roster keyed by trusted issuer and user ID; support safe bulk enrollment of the complete approved tester cohort. Do not assume their Google Play account email equals their PLANETS OTP email. If a roster or mapping is missing, identify that concrete enrollment dependency; never invent testers or automatically authorize every public signup.

The broker may live in the mock project. It must verify the normal token against a fixed configured normal Auth issuer and check current tester enrollment before catalog access or persona issuance. Do not trust decoded claims alone, user-editable metadata, a client flag, a submitted root-user ID, the APK's publishable key, or possession of a mock persona session. No normal service/admin credential is needed merely to validate a normal user token. Keep the small entitlement/control data separate from public fictional profiles.

Accept only a registered **persona key**, never arbitrary user ID/email, password, role, destination URL or project ref. Resolve and recheck the existing exact mock Auth user server-side. Issue a standard, least-privileged mock Auth session using supported pinned-version APIs; for example a server-only admin-generated one-time login followed by a normal verification exchange. An alternative server-held random credential is acceptable only if it never reaches the client. Do not construct custom privileged JWTs or weaken real OTP.

Admin `generateLink` can provision identities in some flows: validate registry/account existence first and verify the resulting session's user matches the approved fixture. No real mail is sent. Never export service-role keys, signing secrets, reusable persona passwords, admin tokens or generated OTPs into the app, Git, screenshots or logs. Return only the minimum session bootstrap required over TLS with no-store responses. Use independent request-scoped Auth clients so concurrent requests cannot overwrite a shared server session.

A mock-hosted broker receiving a normal project's token may need explicit issuer verification instead of that mock project's default gateway JWT check. Inspect the actual deployment semantics: any per-function exception must be restricted to this broker and replaced by tested in-handler authentication **before every action**. Do not disable authentication on other functions.

Bound catalog size, input length, issue rate, concurrent operations and audit retention. Bind each switch to root tester, persona and request identity; changed payload reuse conflicts. Test two testers requesting the same persona concurrently. Define safe lost-response recovery without changing the intended persona or revoking another tester's session. Session issuance is not a product mutation, so do not claim exactly-once Auth issuance unless proved.

Record which issued mock sessions belong to which tester for offboarding. Revoking tester access blocks future issuance and revokes that tester's issued refresh sessions, not all sessions for the shared persona. Document and test the remaining access-token lifetime or a stricter server-side session check; client sign-out does not instantly invalidate every issued bearer token. Do not require a paid session-control feature without approval.

### 4. No side effects on actual users

Disable real SMTP delivery, push delivery, outbound webhooks and external analytics in mock configuration; in-app mock notices/unread still exercise the real code. Route reports only to the mock database. Use safe fixture links and synthetic media, never private Google documents. No paid map/provider activation or reuse of normal private provider secrets. Missing optional basemap service must remain an honest unavailable-map state while fixture discovery works.

## Provisioning authorization and external inputs

The accepted direction includes a separately hosted mock environment. During execution, inventory available projects/organizations, actual free capacity and current cost before provisioning. This package permits creation/configuration/seeding of **one dedicated zero-additional-cost mock project** when ownership and target identity are confirmed. Never upgrade a plan, create paid branches, increase quotas or delete/pause another project to obtain a free slot. Any nonzero charge needs explicit approval.

Required outside inputs are account access, a verified mock target, the actual approved tester identities, server secret/configuration storage and eventually signing material for a release candidate. The Google Doc and old downloads are not required. If required access/capacity is unavailable, stop the affected hosted step, complete independent local implementation with two isolated test realms, and record the exact blocker. Do not claim “ready for closed testers” from local results. Do not modify normal staging, production or Google Play under this package.

## Tests and handoff

Run target-guard negative tests, schema replay and a populated mock upgrade, non-destructive repeat seed, canonical fixture verification, broker no-auth/wrong-issuer/non-tester/revoked-tester/arbitrary-persona cases, concurrent persona issuance, secret redaction and normal-backend token rejection. Use a separate disposable project for destructive QA, not the shared mock community.

Prove ordinary mock Auth sessions exercise RPC/RLS/Storage rather than service-role app traffic. Seeded staff must not be selectable. Every publicly reachable control endpoint must fail closed before privilege use.

Document actual project refs without secrets, migration/config fingerprints, fixture generation and inventory, trusted issuers, enrollment/offboarding commands, broker request/response/recovery contract, operational limits and pending hosted work. Add a small ADR for the two-environment/control-identity boundary. Push the MOCK01 draft PR and continue to MOCK02.

## Reference sources

Repository sources above were read at the inspected SHA. Refresh them before editing. Official documentation reviewed 21 October 2026:

- https://supabase.com/docs/reference/javascript/auth-admin-generatelink
- https://supabase.com/docs/reference/javascript/auth-getuser
- https://supabase.com/docs/guides/functions/auth
- https://supabase.com/docs/guides/auth/sessions

Check lockfile-compatible behavior and the CLI's actual help; these pages are not permission to upgrade dependencies. The changelog Markdown fetch was unsupported by the authoring browser; check relevant version changes during implementation. Test current behavior instead of assuming an API returns an authenticated session or immediately revokes old JWTs.
