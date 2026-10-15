# PLANETS UIPOLISH02 — Template Workshop feedback and skill localization

**ID:** UIPOLISH02
**Status:** Implementation prompt; not evidence of implementation.
**Order:** After UIPOLISH01; reuse its compact card labels. Separate PR because recovery state needs correctness tests, not only screenshots.

## Goal and screenshot observations

The Italian Template Workshop currently mixes English skills with translated importance (`Event organization · Utile`, `Facilitation · Necessaria`), has cramped card metadata, and displays a large persistent message saying an independent draft is ready followed by technical retry/lifetime instructions. Fix these without breaking duplicate-prevention or making uncertain creation look successful.

The separate `Le mie bozze` loading failure is OUT OF SCOPE. A prior creation receipt does not prove that the drafts list or current destination loads successfully. Do not hide that failure or claim this task fixes it.

## Verified implementation

Inspected main `9960df6dbef14bb0aace017c9ea033289b89e414` on 2026-10-15; inspect latest main before work.

- `apps/mobile/lib/features/template_workshop/presentation/template_workshop_screens.dart` renders every application attempt belonging to the current actor above the catalog. The title depends on `attempt.destinationId`, but the subtitle is always `workshopRecoveryLifetime`. The catalog row opens template detail rather than directly opening the existing draft.
- The same file's `_TemplateSkills` renders `skill.label` directly and localizes only the importance suffix. Default badges, summary, provenance and skills have little explicit vertical spacing.
- `apps/mobile/lib/features/template_workshop/application/template_controllers.dart`: `TemplateApplications` is deliberately app-scoped. `use`, `retry` and `_run` keep frozen request IDs/intents; confirmed receipts retain `destinationId`. Uncertain commands recover or replay the same request, preventing another copy. A confirmed destination retry returns its stored ID. These records survive routes intentionally.
- Controlled catalog slugs/English labels are seeded in `supabase/migrations/20260902192101_basic_profiles_skills_visibility.sql`. Inspect subsequent catalog changes too; do not edit historical migrations.
- Existing coverage includes `apps/mobile/test/features/template_workshop/presentation/template_workshop_test.dart` and `integration_test/template_workshop_smoke_test.dart`, including lost acknowledgements/recovery.

## 1. Localized skill display, not a taxonomy migration

Use a shared locale-aware display resolver keyed by stable known skill slug/ID. First check for a resolver added on latest main. Translate the existing controlled catalog, not user-written content; unknown/new labels must safely fall back to their canonical label. Do not change IDs, slugs, stored labels, importance, filter payloads or matching rules.

Examples for Italian display: `Event organization` -> `Organizzazione eventi`; `Facilitation` -> `Facilitazione`; `Woodworking` -> `Falegnameria`; `Basic repairs` -> `Piccole riparazioni`. Cover the known catalog rather than patching only four screenshot words. Use normal localization resources, not network translation or English-string matching. Keep EN output and unknown-skill fallback.

Use the resolver in Project/template card and detail labels, and in their shared skill-filter/selection displays so choosing and viewing a skill agree. Inspect impact on reused profile components; do not silently change a shared widget's behavior. On catalog cards reuse UIPOLISH01: one row of names and optional `...`, with no importance suffix. Full request/authoring/detail information remains available.

## 2. Separate creation outcome from technical recovery metadata

Design explicit presentation for these different outcomes:

- No attempt: no recovery/success notice.
- Applying: local busy feedback; no claim that a draft exists yet.
- Unknown outcome/lost acknowledgement: concise localized recovery notice and an explicit Retry action that resumes the SAME frozen request. Never start another creation to dismiss an error.
- Confirmed creation: a brief success acknowledgement such as `Bozza creata`, with a clearly labelled `Apri bozza` action targeting that exact draft. It must not remain a large global banner on every catalog visit after a successful editor handoff. A compact dismissible acknowledgement is acceptable. Do not show technical `while the app is running` instructions as normal product copy.
- Confirmed creation but editor navigation/read failure: preserve the destination and show a truthful reopening action/error. Do not create a duplicate or claim current access from an old receipt.
- Authoritative unavailable/forbidden destination: visible safe explanation, not perpetual `ready`; do not reinterpret transport failure as deletion.

Separate presentation dismissal/acknowledgement from recovery bookkeeping. Do not delete unresolved attempts, discard frozen request IDs, change idempotency semantics, automatically retry mutations on rebuild, or add persistent private storage. Completed receipts can remain internally for explicit reuse/reopening without advertising all of them above discovery.

Keep exact actor binding and stale asynchronous-result protection. Signed-out/account-switched users must not see or open another account's attempt/draft. Confirmed draft data is backend-owned; RAM-only recovery context is not a statement that saved drafts disappear after app restart.

Keep `Start another draft` explicitly separate from reopening/retrying an existing one. Preserve group attribution and the selected copy options. If deciding when creation was acknowledged requires new UI state, document it and test it; do not infer successful editor loading from `context.push` merely returning.

## 3. Workshop layout and copy

- Use a compact search field and the existing filter-button pattern; put the skill picker behind Filters, preserving active selections, query debounce, reset, re-entry and pagination. No extra search request merely because filters collapse.
- Replace the long normal introduction with concise equivalent copy, e.g. `Parti da un modello e crea il tuo progetto.` Source provenance remains available.
- Keep cover, title, short summary, a restrained official/community provenance row, then compact skill labels with explicit spacing. Do not stack nearly touching metadata lines. Keep official vs community origin unambiguous without repeating the organization name in several large elements.
- Preserve full titles/content in detail, canonical media/provenance, the existing card action and accessibility. Do not globally change shared cover crops or silently rewrite stored template descriptions.

## Tests and acceptance

Cover initial visit, successful application/editor handoff/back, repeated catalog visits, reopening same draft, dismissed success feedback, busy double taps, lost mutation acknowledgement, failed receipt lookup and exact replay, navigation/read failure, removed destination, account switches and stale results. Prove draft-creation call count does not increase from retries/dismissals/rebuilds and actual errors are not hidden.

Test EN/IT known/unknown skill labels and unchanged canonical IDs/importance/filter inputs. Visually validate catalog, recovery notice and detail at 320/360/412 logical pixels, 1x/2x text, light/dark themes, scrolling and keyboard open. No RenderFlex overflow, overlapping controls or giant persistent success panel.

Run affected existing controller/widget tests and current mobile checks. Capture before/after on a disposable emulator; do not report screenshots as live backend validation. If recovery authority or destination existence cannot be resolved safely, report that issue rather than weakening the contract.

## Delivery and safety

No schema/RPC changes, new translation service, draft deletion, hosted deployment, database reseeding or fixes to the independent Drafts load bug. No external documents or screenshot files are required; the observations above are sufficient. Never publish account names, avatars, messages or session details from the supplied screenshots. Follow the repository branch/PR/check workflow; update nearest docs and return tested commit, PR, results, remaining device QA and separate release status.
