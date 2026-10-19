# PLANETS ACTSPLIT01 — Activities Split Mode (Sandbox)

## Objective and scope

Implement one reversible Flutter UI experiment, enabled through Settings > Sandbox > **Activities Split Mode**. When enabled, separate collaborative **Projects / Progetti** from **Activities / Attività**. Put existing **Tavoli culturali** under Activities and make **Sports / Sport** a prominent activity category.

This is an integrated navigation experiment, not an isolated mock-screen viewer. The existing Projects and Tavoli remain real, functional product surfaces. New external activity listings are explicitly labelled, read-only local examples for evaluating the UI.

Deliver this as one focused implementation PR. APIs, AI-assisted search/scraping, ingestion, and real manual submissions are a later, separate plan. Do not implement those services here.

## Current evidence and execution base

Repository: `lillo24/planets.community`. Inspected on 2026-10-19 against `main` at `5c3d50b48c16b0f6fc4879b11c8621a8086f78e8` (PR #268). **Start from the latest `main` at execution time**, not this historical commit. Reconcile subsequent UI/tutorial changes rather than reverting them.

Verified implementation:

- `apps/mobile/lib/features/settings/presentation/settings_screen.dart` has a Sandbox section containing the saved bottom-right Messages/Browse choice. Sandbox is not debug-only; the startup reset separately is.
- `apps/mobile/lib/features/settings/README.md` describes local, account-independent navigation persistence, bootstrap restoration, and visible restore/save failures. The previous standalone Messages preview was removed; do not recreate it.
- `apps/mobile/lib/features/settings/application/navigation_preference_controller.dart` publishes changes only after a successful local write and rejects overlapping writes.
- `apps/mobile/lib/app/foundation_screen.dart` currently has a combined Projects/Tavoli entry leading to `/proposals`, plus Scambio-Dona.
- `apps/mobile/lib/app/router/browse_activity_switcher.dart` is the route-backed Proposals/Tavoli selector.
- `apps/mobile/lib/app/router/app_router.dart` and the app README describe stable Profile/Home/Browse branches; Messages uses Home. The configurable bottom-right shortcut must remain independent of this experiment.
- `apps/mobile/lib/features/proposals/presentation/public_proposals_screen.dart` and `apps/mobile/lib/features/recurring_activities/presentation/public_recurring_activities_screen.dart` use existing public controllers, user-scroll pagination, scoped map entry points, and canonical detail routes. The Tavoli list also exposes requested items and existing management/draft actions.

Read `AGENTS.md`, relevant nested instructions, `implementation_plan_sections_suggestions.md`, and current code before editing. The paths above were inspected; other areas to inspect include bootstrap, the navigation shell, geographic discovery, tutorial adapters, localization catalogs, and affected tests.

## Product decisions and external context

**Requested now:** test Projects versus Activities, place Tavoli culturali under Activities, support Sports filtering, and expose the switch in Sandbox.

**Conservative experiment defaults:** off by default; saved on this installation; separate Home entries; no new bottom-navigation slot; native Tavoli kept separate from external previews at the data/action boundary.

**Future direction, not implementation:** a Trento activity directory populated through permitted feeds/APIs, AI-assisted discovery/extraction, and organizer submissions. “All sports in Trento” is an eventual coverage goal, not a claim this prototype may make. It includes recurring sessions and courses, not only events happening today.

No external document, uploaded archive, live website, account, credential, or API is required. Relevant discussion is captured here. The Google Doc “Planets Community Design” was consulted as broader context, not evidence of implementation. RadarTN is optional inspiration for scannable local listings; neither its actual ingestion method nor its reuse rights is established by this plan. Codex does not need the `.mht` upload. If a genuinely required external dependency emerges, stop that dependent work and report what is missing rather than guessing.

## 1. Sandbox preference

Add a switch under the existing Sandbox heading:

- English: **Activities Split Mode**.
- Italian: **Modalità Progetti / Attività**.
- Short localized explanation: separates Projects and Activities and includes example activity listings; changes this device only.

Keep the current Messages/Browse setting and its storage key untouched. Use the established typed local-store/controller pattern with a separate preference, default **OFF** for a missing or invalid value. Restore before first app presentation to avoid a wrong-layout flash. A read failure falls back to OFF with a recoverable Settings error; a failed save leaves the prior choice active and shows retryable feedback. Reject overlapping saves.

Persist across restarts and sign-out, without account/backend synchronization. Public Settings remains usable signed out. Do not hide the experiment behind a new debug-only flag; explicit opt-in is its gate.

Switching OFF restores the normal navigation, wording, and discovery surface. It must not delete domain records, change the Messages/Browse preference, reset onboarding, lose drafts, or mutate an account.

## 2. Navigation while ON

Home should present three clear entries using the existing visual system:

1. **Progetti** — things people organize/build together; opens the current Projects discovery.
2. **Attività** — things to take part in, including Tavoli culturali, sports, and other local activities; opens the new Activities landing.
3. **Scambio-Dona** — unchanged.

Replace the top-level Projects/Tavoli browse choice with **Progetti / Attività** only while this mode is enabled. Tavoli is now a destination within Activities, not a peer of Projects. Retain a clear native **Tavoli culturali** label; do not globally replace every occurrence of Tavolo with Attività.

Keep the current three branch identities and configurable bottom-right behavior. Prefer an additive Activities route in the existing Browse branch. Do not rebuild the entire router or discard protected navigation/form state merely because the setting changes. Use current routing conventions rather than inventing a new navigation framework.

Existing `/proposals`, `/tavoli`, their IDs, invitation links, join flows, management routes, drafts, templates, Groups access, and Scambio-Dona routes must keep working. A native Tavolo detail remains its real detail, with its current authorization and actions. Do not migrate, clone, or auto-reclassify any Proposal based on its title/category.

When OFF, direct entry/restoration to an experiment-only route must resolve safely to normal discovery, without leaking examples or entering a redirect loop. Existing native detail/editor routes stay valid in either mode. Preserve Android/system Back, retained browse state, and auth `returnTo` handling.

## 3. Activities discovery and Sports

Build a usable mobile Activities landing, not an empty “coming soon” page:

- Prominent category choices: **Tutte / All**, **Sport / Sports**, **Cultura / Culture**. Keep this initial taxonomy small and view-local.
- A clearly labelled **Tavoli culturali** section/entry under All and Culture opens the current live Tavoli list, presented as part of Activities. Preserve its pagination, requested rows, create/manage access, and native actions. A bounded preview of native cards is optional; fetching every Tavolo to build this landing is not.
- Local external-style example cards appear under the relevant categories. Sports must show sports examples and exclude the cultural listings/Tavoli entry. All restores the broader examples and native entry.
- Provide a compact search for the example catalogue and a Sports discipline selector, derived from the fixture taxonomy. Scope the search label to examples so it does not imply full-text search over native Tavoli. A search over examples must not silently hide native results or report a globally exhaustive count.
- Use **Trento** as the example catalogue's visible city, not a new global location preference or permission request. Do not overwrite existing Projects/Tavoli locality filters. Do not add a decorative location selector that has no working behavior.

The sectioned native-Tavoli-plus-example-catalogue structure is intentional: do not fabricate one globally sorted or fully counted feed from a partial native page and a complete local fixture list. Keep native loading/error/empty states independent of the examples. A backend failure must not be concealed by showing fixtures as real results.

For examples, support both **single events** and **recurring sessions/courses**. Show the schedule type correctly; an ongoing course without a next-session date must not be presented as “today.” A full calendar, recurrence engine, Today/Weekend filter, and map for the new catalogue are out of scope.

Do not remove existing native Projects/Tavoli map access. Keep any map entry explicitly scoped to its existing native list; never imply that a Tavoli-only map includes the external examples or preserves a Sports filter it cannot represent. Do not enable provider traffic or broaden public location precision.

## 4. Example content, cards, and details

Use a small deterministic catalogue with enough variety to test scanning and scrolling: approximately 10–14 entries, mostly sports, plus a few cultural activities. Example disciplines may include climbing, acrobatics, running, volleyball, swimming, martial arts, dance, and yoga. These are fictional UI fixtures, not verified opportunities at real providers.

Represent the useful shape: stable local identity, title, category/discipline, activity format, city, short description, schedule or “schedule to confirm,” optional example cost/level, optional local cover, and explicit preview origin. Keep category, format, and native-versus-example identity separate. Do not reuse competence IDs as a sports taxonomy or place examples in Proposal/Tavolo models.

Cards should be compact and scannable: title, sport/category, date or recurrence, city/area, and an understated but legible **Esempio / Example** badge. Include a short catalogue-level example notice and repeat the distinction in details. Never claim complete city coverage, verified availability, actual admissions, official partnerships, or a working data feed.

Tapping a sample card opens a read-only detail screen/sheet with the same provenance and relevant schedule information. Do not send sample IDs to real RPCs, create real memberships, chats, requests, notifications, shares, reports, bookings, or analytics ingestion. No fixture “Join,” message-organizer, or fake successful submission action. Do not collect personal data through a pretend form.

Use generic fictional organizer names or omit them. No real phone numbers, fabricated official URLs, scraped descriptions, or externally fetched stock images. Reuse appropriate existing local assets/icons and honest missing-cover treatment. Fixtures must not depend on third-party network access and must remain behind the mode gate, not in the shared database or normal provider caches.

## 5. Implementation and visual constraints

Reuse Flutter, Riverpod, local preferences, localization, theme tokens, and existing route/list/card conventions. Keep the new presentation/fixture ownership narrow and testable; do not build a speculative ingestion framework, source adapter registry, or production event schema.

Local search/filter state should survive a sample-detail round trip. Ordinary native pagination must stay bounded and user-driven. Avoid new eager reads from unrelated features. Preserve identity-scoped cleanup for real data.

Localize all new UI in Italian and English, including accessibility and error copy. Support narrow screens and large text without a cramped chip/header stack. Keep readable contrast, touch targets, and reduced-motion behavior. Use existing page-app-bar conventions; do not reintroduce unnecessary title Back arrows or change the welcome animation.

Inspect tutorial use of shared Home/list components. Keep the default tutorial unchanged. When the stored experiment is ON, ensure replay still has valid targets and descriptions, using the current isolated tutorial pattern if appropriate; never overwrite the user's saved mode to run the tutorial. Do not redesign the tutorial in this plan.

## 6. Tests, evidence, and acceptance

Add focused tests covering:

- preference missing/invalid/read failure, successful restoration, failed save, repeated saves, restart, sign-out, and independence from Messages/Browse;
- OFF baseline and ON Home/browse layout, public access, existing Tavoli URLs, additive-route fallback when OFF, Back/retention, and guarded join/editor continuations;
- All/Sports/Culture, discipline plus text filtering, empty/reset state, sample detail round trip, and unambiguous recurring/unknown schedules;
- no fixture RPC/membership/chat/submission writes, no third-party fixture fetches, no example content in OFF mode, and native errors not masked by sample results;
- unchanged native pagination and relevant Projects/Tavoli/Resources/Groups/tutorial regressions;
- Italian/English, narrow screens, large text, and accessible selected states.

Run formatting, analysis, and change-scoped tests using current repository commands. Shared routing/bootstrap changes require their broader affected suites, not only new widget tests. Do not run unrelated database integration suites merely because this is a UI task.

Capture and inspect actual rendered UI: Sandbox OFF/ON, Home ON, Activities All, Sports results, one sample detail, native Tavoli under Activities, and restored OFF. Exercise both bottom-right choices. Use an emulator when available; report precisely what was and was not checked. For an available authorized physical Android device, target **`48091FDAS0041A`** explicitly (for example `adb -s 48091FDAS0041A ...`). Do not claim physical Android or iOS QA from widget tests.

Acceptance: one saved opt-in setting changes the real navigation, Sports is visibly populated and filterable, Tavoli remains fully functional under Activities, sample and real actions cannot be confused, and disabling the setting returns to the original experience without data changes.

## Delivery and boundaries

Update the relevant Settings/app feature documentation and add a concise experiment note with activation, behavior, fixture limits, test evidence, and rollback (turn OFF). State explicitly that no migration, ingestion service, production source integration, or real submission workflow was added.

Follow current `AGENTS.md`: isolated task branch/worktree, focused PR into latest `main`, required checks, normal merge/cleanup rules. The direct-main authorization for publishing this plan file is **not** authorization for direct-main implementation commits. Do not deploy a backend, publish to stores, change billing, add external services, or touch unrelated plans.

Resolve small presentation/code choices consistently and report them. Stop and surface a concrete blocker if proceeding would require a schema/security change, destructive operation, recurring cost, or missing required external context. Do not turn safe local UI choices into unnecessary approval gates.

Completion report: PR/merge commit; implemented behavior and activation path; example-versus-native boundaries; exact checks and rendered-screen evidence; assumptions/limitations; physical-device/iOS QA status; any blocker before a future ingestion plan. Distinguish code completion from app-store deployment.
