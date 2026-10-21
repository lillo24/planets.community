# PLANETS MOCK02 — Mock Mode and safe environment/session switching

Prepared: 21 October 2026. Repository: `lillo24/planets.community`.
Read all three MOCK prompts. This stage depends on MOCK01's verified branch and concrete broker/environment contract; it does not require an early MOCK01 merge.

## Objective

Add **Settings → Sandbox → Mock Mode: Yes/No**, default No, in the closed-testing release build. No uses the normal backend and normal personal account. Yes uses only the separate mock environment and one selected fictional persona through the existing domain gateways.

This is not a card filter, demo screenshot mode, debug-only switch or collection of fake gateway successes. Both environments run real PLANETS behavior. Keep the normal app's styling: no new card tags/ribbons, global watermark or permanent banner. The Sandbox switch and conditional Help account entry communicate the choice. Existing functional labels are unchanged.

## Starting implementation and boundaries

The inspected base was `b3fccd795b805d50ac0e47815418f01a51dc54c1`; use the latest cumulative source instead of rolling back.

Inspect at least:

- `apps/mobile/lib/core/backend/supabase_backend.dart`, `core/config/app_config.dart` and `bootstrap/bootstrap.dart`.
- Auth gateways, command/session controllers, restoration, provider adapters and profile-anchor readiness under `features/auth/`.
- Settings stores/controllers and `presentation/settings_screen.dart`.
- Help routes/screen, router/startup/departure coordinator, native-link handling and retained branch keys.
- Media/Storage, maps/provider clients, Messages/C/D/M unread and subscriptions, pending-command journals, analytics/monitoring and release builders.
- `apps/mobile/tool/staging_distribution.dart`, staging config examples and `tool/build_map_live_staging.dart`.

Current Supabase initialization is a singleton exposed by a provider, while many downstream owners assume one environment. Inventory every source of endpoint/client/session state, including direct singleton access, captured gateways and cached URL factories. A provider override alone is not proof that all requests changed destination.

## 1. Separate product availability from current mode

Keep `ENABLE_DEMO_TOOLS=false` in distributable builds. It controls old form presets and the DEMO shell, not the requested feature. Introduce a separately named closed-test capability and strictly validated public configuration for the normal origin, distinct mock origin/publishable key and trusted broker. Names are an implementation choice; document them and update the exact allowed-key validators/tests.

The new capability must work in signed release builds used by all enrolled closed testers, not only `kDebugMode` or a developer account. Production/ordinary builds must not expose or activate mock login routes, even with stale local preferences, deep links or manipulated UI state. The broker's tester authorization remains mandatory; an APK flag is not proof of Play enrollment.

An unavailable or incomplete mock setup must be visibly unavailable, never silently backed by the real database or by in-memory examples. Reject equal normal/mock origins, unknown broker destinations and secrets accidentally supplied as publishable credentials. Preserve signing/package/version checks and map-build defines without enabling unrelated features.

## 2. One explicit switching coordinator

Implement one domain-owned coordinator for entering/exiting Mock Mode and switching personas. Distinguish the **normal tester/control identity** from the **active data identity/environment**. In normal mode they coincide; in mock mode the UI sees the fictional persona, while the retained normal session is used only for its own Auth maintenance and explicit mock-entitlement checks.

Use separate backend clients with separate session persistence namespaces. Preserve the existing normal session instead of logging it out merely to enter mock. Never copy normal bearer/refresh tokens to the mock data client or mock tokens to the normal client. The only normal-token transmission outside normal Auth is the fixed trusted broker authorization path established in MOCK01, not arbitrary mock RPC/Storage/provider traffic.

Session storage needs a reviewed confidential device-storage boundary. Do not put tokens, OTPs or passwords into an ordinary SharedPreferences mode flag or registry; use suitable existing SDK/platform-secure storage, or add a narrowly justified maintained solution. Normal, mock and operator sessions must not overwrite or race-refresh one another. Keep one refresh owner per session. API semantics must match the pinned Dart SDK, including refresh-token rotation.

The effective scope must include environment identity and a monotone transition/identity generation, not just user UUID. Tests must deliberately use equal UUIDs in two isolated environments. All private caches/controllers/commands/read frontiers must still remain separate.

### Enter Mock Mode

1. Handle the active editor through the existing Save/Discard/Stay coordinator before switching. An unresolved product write must be reconciled or explicitly retained in its original environment; never silently discard it or retry it against the other backend.
2. Require the normal tester login and MOCK01 entitlement. Guests may initiate the toggle and finish ordinary login, but cancellation leaves normal mode unchanged. Do not send OTP or submit another pending action just because a preference was restored.
3. For the first entry, invoke the shared persona-selection route/interface that MOCK03 completes. Cancellation leaves the toggle No. A previously chosen persona may be reused only after current registry/entitlement validation and the user's explicit enable action.
4. Prepare the candidate mock session on a non-active client. Validate target project, broker result, actual Auth UUID, registry key and canonical profile readiness. Do not call normal profile completion with a mock identity or present a locally fabricated profile as authentication.
5. While transitioning, fence interactions and late responses. Commit the mode/data scope only when the candidate is usable. Then clear previous account/environment-dependent UI and navigate to Home. The selected persona owns the resulting Profile, Messages, groups and permissions.

### Leave Mock Mode

Stop mock subscriptions/polling/read acknowledgements, clear its protected presentation state and leave only the intentionally scoped stored session metadata needed by the contract. Reconcile the retained normal session through the existing restoration behavior, then return to Home as the normal account; if it expired, show normal sign-in. No obsolete mock success message may appear on that screen.

Do not globally sign out a shared persona: that would disrupt other testers. Use documented current-session/local scope where revocation is needed, and test its actual server effect. Explicit **Sign out of PLANETS** must clear the retained normal/control session and local mock access, return to Welcome with Mock Mode off, and not leave a hidden logged-in normal account behind. Switching persona or turning mock off is not full logout.

## 3. State, errors and restart behavior

Treat mode changes as transactional UI/session changes, not an eagerly persisted boolean followed by best-effort login. Keep the last valid scope or an isolated recovery screen until a transition resolves. Failures must not show Mock Mode Yes while sending normal requests, or No while still rendering a mock account. Never automatically fall back to real content after mock/network failure.

Persist the user's selected mode only after success, with no credentials in that preference. Fresh installs and unknown/corrupt mode values default No. A restored Yes must validate the remembered normal tester, mock environment/fixture generation and mock session before showing data; if that fails, show Retry/Return to normal rather than rendering another account's cached content. A different normal account cannot inherit the previous operator's entitlement or remembered persona session. Keep device-wide language/navigation/Activities Split settings independent.

Serialize switch actions. A→B→A mode/persona changes, cancelled sheets, overlapping refreshes, sign-out during issuance, app background/restore and delayed readiness responses must not adopt an old completion. Retire an unused candidate session safely; do not let an ignored Future leave the wrong session installed in the active SDK client.

Network operations already committed remotely cannot be undone by a UI toggle. Keep in-flight requests bound to their original environment and report recovery honestly. Do not replay product commands, deep links or read acknowledgements under the new persona.

## 4. Whole-app isolation inventory

Implement and test the following boundary across every current feature, not only discovery:

- Profiles, avatars/covers, Groups/People, Ideas, Projects/Tavoli, maps' domain records, templates, Scambio, Messages/Requests, links, reports, Block, notifications and owner-management destinations all use the active realm.
- Dispose old domain providers, Realtime channels, subscriptions, pending debouncers and image/provider scopes. Clear previous private titles, previews, cached destinations and unread state on authoritative denial. Preserve unrelated installation preferences and drafts only in their proper original scope.
- Scope pending-action journals by environment, actor and operation. Never adopt real request UUIDs, invitation secrets or private file URLs in mock. Add versioned migration/cleanup of old unscoped preferences where genuinely necessary, not a device-wide wipe.
- In Mock Mode, suspend ordinary normal-realm product refresh/polling and read ACKs. Root Auth refresh/entitlement checks are the narrow documented exception. Do not register a real push installation for the shared persona or consume normal notices as mock unread. Mock external analytics/push/mail stay disabled; no fake success is reported for provider delivery.
- A normal public/deep link or notification opened while mock is active must not silently switch realms or resolve the same UUID in the wrong realm. Require an explicit return to normal for a known normal link. Mock sharing must be unambiguously mock-scoped using supported routing; otherwise clearly disable unsupported external sharing instead of generating normal URLs for mock IDs.
- Do not launch real Google-provider sign-in, delete the retained real account, or send a real support/account-deletion email while impersonating a persona. Intercept unsupported externally consequential actions with clear mock-only behavior. Ordinary mock product reports stay functional in the mock backend.
- Activities Split examples and tutorial fixtures are not a substitute for missing mock records. Existing baseline tutorial replay may remain local, but real Tavoli and other native data paths must respect the active environment. Do not remove unrelated existing provenance labels just to change Mock Mode styling.

## 5. Tests and acceptance

Create focused tests with **two independently configured local backends**, distinct credentials/Storage and intentionally overlapping fixture IDs. No real user content is needed. Use transport spies in unit tests plus genuine Auth/RPC journeys for the integration boundary.

Required cases: initial No; enable/cancel/login denial; successful Yes; restoration; stale preference; mock downtime; leaving to valid/expired normal login; full logout; persona change; double tap; server success/client timeout; switch during profile loading/message send/link-open; A→B→A; account replacement; old Realtime hints; denied cached picker; unsaved editor and unknown command outcome; normal deep link while mock; mock credentials rejected by normal backend; no normal product call while mock except approved control requests.

Verify every visible native data family resolves only its realm, all existing user-facing permission rules still apply, and no privileged key lands in artifacts/config/logs. Run relevant Settings/bootstrap/Auth/router/profile/media/Messages/C/D/M tests, localization, formatting and analysis. Keep full final mobile/web/database and native checks for MOCK03 unless a stage needs them to investigate a failure. Use real EN/IT fonts, narrow screens and enlarged text.

Intermediate MOCK02 may use a minimal real-session selection adapter and synthetic local entitlement inputs; do not publish it as the finished account picker. Record the actual interface consumed by MOCK03. No production fake gateway must remain as a success fallback.

## Delivery and execution boundary

Update feature maps and the environment/session ADR; list every audited endpoint, persistence and side-effect owner. Document state transitions, active-vs-control identities, denied/restored states and pending external setup. Push a draft MOCK02 PR based on MOCK01 and continue to MOCK03. Do not deploy the normal staging migration gap, upload an AAB or merge this stage independently.

MOCK01 governs cost/target authorization and tester enrollment. Missing hosted inputs are concrete setup blockers, not grounds to weaken authentication or replace the mock environment with real data. Local implementation may proceed; final reporting must distinguish code qualification from hosted readiness.

Official reference for pinned-version verification:
https://supabase.com/docs/reference/dart/auth-setsession
https://supabase.com/docs/reference/dart/auth-signout
https://supabase.com/docs/guides/auth/sessions
