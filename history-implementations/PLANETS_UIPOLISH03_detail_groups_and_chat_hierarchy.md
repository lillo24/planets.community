# PLANETS UIPOLISH03 — Clear detail sections, compact group filters and chat agreement UI

**ID:** UIPOLISH03
**Status:** Implementation prompt; not implemented.
**Order:** After UIPOLISH01 and UIPOLISH02. Reuse their schedule/skill components and translations; no parallel conflicting edits to the same widgets.

## Goal

Polish the founder's supplied Project detail, Groups directory and Scambio/Dona chat screens. Improve hierarchy, spacing, concise application-owned copy and purposeful icons, not decoration on every sentence. Preserve behavior and authorization. The separate Drafts loading error must remain a visible error and is not part of this task.

## Verified entry points

Inspected main `9960df6dbef14bb0aace017c9ea033289b89e414` on 2026-10-15; re-check latest main and repository instructions.

- `apps/mobile/lib/features/proposals/presentation/public_proposals_screen.dart`: long skills heading and explanatory paragraph, raw schedule block (superseded by UIPOLISH01), complete Project text and manager actions.
- `apps/mobile/lib/features/project_resource_needs/presentation/project_resource_needs_section.dart`: renders resource-title chips, then repeats each title before its description. This is a shared public section with loading/retry and optional-heading/empty behavior.
- `apps/mobile/lib/features/groups/presentation/group_directory_screen.dart`: permanent search, kind, volunteering, exact territory and Reset controls above results; already supports pull-to-refresh. Empty copy does not distinguish active-filter state. Shared public/own contexts must remain separate.
- `apps/mobile/lib/features/resource_chat/presentation/resource_chat_screen.dart`: counterparty header and agreement section sit above an Expanded history viewport, then the composer. Large fixed top content needs keyboard/small-height testing.
- `apps/mobile/lib/features/resource_exchange/presentation/resource_exchange_widgets.dart`: `ResourceExchangeAgreementSection` chooses status and primary action from canonical negotiation/lifecycle state; history and cancellation currently share its main button Wrap. A tonal button is not proof of disabled state. Preserve these actual state rules.

## A. Project details

- Use short section headings with one meaningful bundled icon each: Schedule/calendar, Skills/people or skills, Materials/inventory. Suggested Italian headings: `Programma`, `Competenze`, `Materiali e strumenti`.
- Use UIPOLISH01's schedule surface and UIPOLISH02's skill localization. Keep full skill names and Required/Useful distinctions available in details; only card previews omit priority. Present importance as restrained groups/sub-labels rather than a wall of explanatory prose.
- Remove repetitive tutorial-like app-owned paragraphs (the mixer, paintbrush and paint examples) from normal reading flow. Preserve the skills-versus-materials distinction through headings and a short secondary hint or accessible info disclosure. Do not change global localization strings used in authoring without auditing their callers.
- Render each material/resource once as a coherent item: icon, title, optional description directly below. Do not show a chip and repeat the same title in a second unrelated paragraph. Keep every actual user-authored detail; no silent truncation or summary rewrite. Long content may use an explicit accessible expansion only if full content remains reachable.
- Manager actions should be local to their section with a short labelled `Gestisci`/equivalent action. Preserve exact role checks and existing navigation; a Co-creator must not gain creator-only resource powers through visual consolidation.
- Add intentional vertical spacing and restrained surfaces. Do not shrink text to fit, move essential participation actions out of reach or change public/protected location boundaries. Preserve source text, safety instructions, links, loading/error/retry states and tutorial focus anchors.

## B. Groups directory

- Default view: a compact search field and Filters control, then results. Secondary filters (kind, volunteering and territory) are initially collapsed. Use existing shared filter patterns where suitable.
- Show active-filter indication and make reset relevant to actual active values; retain selections when collapsed. Preserve search/territory debounce, exact matching, validation, sorting, request counts, paging and public/own access rules.
- Replace the technical territory placeholder with a short label plus explanation within expanded filters. Do not imply fuzzy, radius or nearby matching: existing exact matching must remain explicit when needed.
- Give Create group a clear primary action and My groups secondary treatment, responsive to long translations. Avoid crowding a third refresh icon beside them when pull-to-refresh already exists, but retain an accessible non-gesture refresh path where needed.
- On a successful empty result, distinguish no visible groups (unfiltered), no matching groups (active filters, with Clear filters) and no own groups. Loading and request failures must never be converted to a cheerful empty state. Do not infer that no groups exist globally from an authorized empty page.
- Use a modest group icon and short guidance for genuine empty states. Do not fabricate demo groups or change group visibility to fill space.

## C. Scambio/Dona chat

- Make the agreement area a compact full-width summary that leaves room for messages and the keyboard. Show current status and one canonical primary action. Secondary History and cancellation can be in an accessible overflow/details surface; preserve their discoverability, exact actions and confirmations.
- The default no-terms state should not dominate the chat with a large three-button box. Pending terms requiring the viewer's review, exchange errors, refresh/timeline warnings, milestone requirements and terminal/read-only states must remain obvious; do not hide actionable warnings inside a collapsed panel.
- Preserve both parties' real negotiation rights. Do not infer button availability from screenshot color, disable a valid action as cosmetic cleanup, or enable an action forbidden by canonical state.
- Tighten the counterparty header: avatar and name primary, role secondary; block/report controls remain safely accessible and bound to the same person. Do not expose additional profile data or introduce private messaging access.
- Use a compact genuine-empty-chat state with a small conversation icon and concise guidance. No fake messages, onboarding examples or artificial unread values in a live chat.
- Preserve composer draft text across expansion/refresh, sending and errors; history scroll/paging, read acknowledgements, subscriptions and account invalidation. Keep the composer usable with keyboard open, landscape, long names and 2x text. Do not solve overflow with a fixed height, hidden error text or an unscrollable nested Column.
- Do not change the app's bottom navigation, shared chat domains, agreement lifecycle, cancellation semantics, blocking rules or unread-count behavior in this polish task.

## Validation and scope discipline

The screenshots establish cramped spacing and excessive prose, but do not prove every suspected overlap is a layout collision. Reproduce actual overflow with constraints and runtime checks; distinguish normal offscreen scrolling from clipping/overlap.

Test EN/IT, light/dark, 320/360/412 logical pixels, 1x/2x text, long titles/labels/content, keyboard open, landscape and scroll extremes. Capture before/after for each touched screen using synthetic identities/data only, and inspect for heading/metadata/button collisions.

Cover: Project owner/non-owner/Co-creator and material load failure; empty/default/filtered/loading/error Groups and existing paging; both chat roles, no terms, own/other pending terms, agreed/in-progress/completed/cancelled, failures, read-only, long history and typing during a refresh. Keep existing tests for routes, permissions, material completeness, message read boundaries and canonical agreement actions.

Run change-scoped Flutter suites and mobile checks. If the work grows into chat lifecycle changes or a navigation redesign, stop that portion and report the required separate decision rather than forcing it into this task. Otherwise presentation-level refactoring is permitted within the existing boundaries.

No database/migration/provider/deployment changes, draft-load bug fix or blanket rewrite of application copy. No external screenshot/document is required; this prompt contains the observations and design direction. The user's original screenshots contain personal UI data and are not authorized for publication. Use only task-owned emulator resources; optional approved physical checks select `48091FDAS0041A` and must not clear the founder's session. Deliver through AGENTS.md branch/PR/check workflow, update nearest docs, and report exact tests, captures, unresolved defects, PR and release status.
