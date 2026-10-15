# PLANETS — TUT07: Guided tutorial transitions, demonstrated taps, and caption polish

## Objective

Make the existing interactive onboarding tour feel like a **guided demonstration of real navigation**, not a slideshow whose underlying pages change abruptly when the user presses **Avanti / Next**.

The user should see *which control would be activated*, *how the app moves to the next screen*, *what the new screen looks like before it moves*, and *why the tour is focusing on a particular item*. Refine the bottom explanation area with a subtle, faded/translucent background that makes descriptions look intentional and legible.

**Scope:** One mobile-only UX PR. No product/backend/schema changes. Start from latest merged `main` **when this prompt is executed**, not from the repository state at prompt-writing time. Include any small UI/tutorial PRs merged in the meantime.

## Current implementation — inspect and preserve

Relevant implementation areas verified in the repository:

- `apps/mobile/lib/app/startup/tutorial_screen.dart`: 12-step production tour; `_move`, `_surfaceGroup`, `_content`, `_locate`, `_scrollTo`, `_selectProject`, `_primeProjects`; spotlight, lifecycle and cancellation.
- `apps/mobile/lib/app/startup/tutorial_motion.dart`: entering/unobscured/fading/ready phases, 600 ms page hold, 380 ms reveal, 180 ms same-surface focus, distance-based detail scroll.
- `apps/mobile/lib/app/startup/tutorial_presentation.dart`: copy lookup, spotlight painter, labelled offline examples.
- `apps/mobile/lib/app/startup/startup_flow.dart`: `productionTutorial`, version `interactive-2`, completion/replay policy.
- `apps/mobile/lib/app/foundation_screen.dart`: real Home Projects and Scambio–Dona controls with keys `browse-proposals-button`, `browse-resources-button`.
- `apps/mobile/lib/features/proposals/presentation/public_proposals_screen.dart`: visible Project cards, Requested/ordinary sections, pagination and participation detail.
- `apps/mobile/lib/l10n/app_it.arb`, `app_en.arb` and generated localization.
- `apps/mobile/test/app/startup/interactive_tutorial_test.dart`, tutorial integration targets, `docs/development/evidence/tut04`–`tut06`.

The tour already has real read-only app widgets, spotlight targets, early public data reads, cover prefetch for the first few Projects, a guided detail scroll, fictional clearly labelled chat examples, and a bundled tutorial cover fallback.

**Do not regress TUT05's flicker fix.** Resetting spotlight alpha to zero on a same-surface step formerly produced a dark/light color inversion. Preserve independent page opacity and focus movement, including during caption reflow.

Verify all current paths and behavior before coding; this is guidance rather than a frozen source specification.

## UX storyboard / expected behavior

### A. Home → Projects → Project detail (highest priority)

The current tour sequence is:

`Introduction → Home / Projects → Projects card → detail / participation → Create → Drafts → fictional Project group chat → Messages Requests → Messages Private/Groups → Home Scambio–Dona → resource listing / Create / Drafts → farewell`.

Keep this general order and manually paced text.

1. **Introduction → Home:** use a subtle entrance. Introduction contains no Projects button, so do not fake a click there.
2. **Home / Projects → Projects browse:** when the user presses **Avanti**, visibly demonstrate activating the highlighted real Projects/Esplora Home card:
   - A short press/ripple/scale or small touch-ring cue, roughly 180–260 ms, obvious but restrained.
   - Then a coherent forward directional slide/fade, roughly 250–350 ms, into the Projects list. No hard instant swap or whole-screen color inversion.
   - This is **tutorial-only visual feedback**, not dispatching the real card `onTap` or routing the actual app.
3. After **meaningful Projects list content** is painted, hold it still for **about one second** before guiding the user's eye with a **smooth ease-out scroll** toward a visually interesting real Project card.
   - Preferred target: the **third displayed Project if it has a usable cover**; otherwise the **first displayed cover-bearing Project in the already loaded results**. If none have covers, use the third real card when possible, else the first; if there are no usable real cards, retain the labelled bundled illustration fallback.
   - Respect the **actual on-screen order**, including *visible* Requested items, existing filters and pagination. Do not mutate public ordering, silently fetch extra pages, or manufacture backend records.
   - If the cover URL/path is present but the bytes fail, apply a deterministic fallback without waiting indefinitely.
   - Scroll only enough to position the chosen card comfortably in the viewport (around upper-middle with surrounding context), not below the fixed Create control. If it is already visible or the list cannot scroll, skip unnecessary movement.
   - Only focus/highlight the chosen card **after** guided movement settles. The spotlight should not remain over the wrong location while scrolling.
   - Coordinate the one-second stillness with the existing content hold/scrim fade; do not stack blind delays or repeat the sequence on ordinary rebuilds.
4. The Project selected in browse must be the **same real Project** in the following detail view. Revisit `_primeProjects`/`_selectProject`, which currently prioritize the first visible result for both warmup and selection. Freeze one selected identity for the run so provider refreshes do not change the demonstration. Keep prefetch bounded and authorized.
5. **Project card → detail:** when the user presses **Avanti**, show a brief activation cue on the chosen card, then animate into the real detail. Let the cover/title appear before the existing guided scroll toward Join, Full or other truthful participation status. Keep smooth distance-related pacing even with a long description; do not imply a Full/closed Project can be joined.

The one-second dwell and auto-scroll should run only on the relevant Projects list entry after data or an honest fallback becomes ready—not after image updates, rotation, reflow or same-page focus changes.

### B. Apply the visual language to other steps

Distinguish these cases:

- **Navigating to a different surface:** use a restrained directional slide/fade. Show a pressed-control cue **only if that actual visible control plausibly opens the next surface** (e.g. Home → Projects, card → detail, Home → Scambio–Dona). Reverse direction for Previous or return from detail.
- **Focusing another control on the same surface:** move/pulse the existing spotlight smoothly, preserving overlay opacity. Examples: Project Create → Drafts; Messages Requests → Private/Groups selector. **Do not fake clicks on Create/Drafts** if the tutorial is not opening the editor/drafts pages.
- **Illustrative scope change:** the Messages Private → Groups preview may use a quiet selector/content crossfade; preserve visible Example labels, isolated fake messages and real private-data boundaries.
- **Switching contexts without a demonstrated button**, such as fictional group chat → Messages → Home: use page movement and concise existing localized copy; do not invent an app control or suggest the fictional chat belongs to the selected live project.
- **Farewell:** preserve the approved hero/starfield motion and explicit Finish/Skip; avoid decorative navigation gimmicks.

Use a consistent set of short durations/easings. Update step progress and the bottom explanation in sync with the relevant screen transition, avoiding an instruction that describes the next screen while the old screen still fills the preview. **No automatic tutorial-step advancement.** Next remains the user-controlled step trigger.

### C. Bottom explanatory text polish

Treat the guide text under the live preview as a quiet floating caption:

- Add a **soft translucent/faded surface treatment** (e.g. gentle transparent-to-surface gradient plus mildly tinted rounded panel). It should separate the explanation from the app preview without a heavy opaque rectangle or expensive blur.
- Improve spacing and visual hierarchy between slogan/title and explanatory paragraph. Long Create/skills-versus-resources paragraphs need comfortable line breaks, line height and scannability.
- Keep primary copy distinct and readable; any muted secondary text must retain good accessible contrast. **Do not interpret “faded” as making text hard to read.**
- Respect light/dark themes, `ColorScheme`, 320dp phones, landscape, 200% text scaling and longer Italian copy. Retain a bounded scrollable caption pane; keep progress, Skip, Previous and Next visible or safely reachable.
- Avoid dependencies or new art assets unless justified. If tiny Italian/English wording refinements help explain an animation, localize both rather than rewriting the whole tutorial.

## Behavioral and technical invariants

- Never dispatch tutorial press cues to real buttons. No Create/Join/Request/Chat actions, login, profile changes or private data queries; fictional content remains clearly labelled and inert.
- Preserve public read contracts, existing safety/privacy barriers, normal app navigation and image-provider access rules. Do not persist tour IDs/selection/results.
- Preserve first-run/Skip/Finish/Help replay/Back/Previous behavior. **Do not change `interactive-2` or re-onboard users who already finished** solely for a visual improvement.
- All new transitions, dwell timers, guided scroll and tap cues must be **interruptible** and generation-bound. Skip, Previous, Back, account replacement, app pause/resume, resize, reduced-motion toggle and disposal must not leave an old animation or delayed navigation running. Rapid taps must not stack callbacks, duplicate live surfaces or trigger stale target movement.
- On reduced-motion/`disableAnimations`, show the correct target immediately without simulated finger, directional slide or animated scroll, retaining a clear explanation.
- Preserve keyboard/screen-reader semantics and focus; decorative click cues are not actionable buttons. Guard 320dp layouts, large text, rotation/landscape and caption reflow.
- Handle empty/offline/error public lists, late images, failed covers, 1–2 cards, Requested-first results, full/closed/Idea Projects, short/long descriptions and detail reflow.
- Avoid the **TUT05 alpha-reset flicker**, including same-page movement and interrupted animations.
- Prefer a small, auditable extension of existing tutorial motion/state logic. Avoid unrelated refactors, backend changes, hosted data operations, new APIs, migrations or rendering two subscribing live screens simultaneously.

## Suggested execution

Inspect latest files/tests, then choose maintainable internals: perhaps a tutorial-only press cue anchored to measured control bounds, a short directional content transition, and a cancellable post-paint sequence for **ready → stillness → list scroll → target spotlight**.

Explicitly consider lazy list construction, cover load failures and target positioning. Favor measured positions and data-derived identity over assumptions about card index. The existing project-detail scrolling and controller lifecycle guards are starting points.

One PR is appropriate: this is a connected motion/selection/caption/test change within one mobile tutorial.

## Acceptance tests and QA

1. Home → Projects → card → detail: verify correct visual press target, real-page transition, **~1 second after content readiness before automatic browse scroll**, ease-out movement, correct selected card, and same project ID in detail.
2. Candidate selection: third with cover; third without cover; first cover; none with cover; one/two projects; cover fetch error; Requested-first visible order; loading timeout; empty/offline fallback.
3. Same-surface Create → Drafts and Messages Requests → scope, including frame-by-frame opacity: no mask-alpha reset, black/white inversion or wrong target.
4. Interrupted transitions: rapid Next/Previous, Back/Skip during cue/hold/scroll, backgrounding, resize/reflow, account replacement and disposal; no stale callbacks, unwanted scrolling or real data mutation.
5. Reduced motion, IT/EN, light/dark, 320dp, large text (2x), landscape, accessible labels, keyboard navigation and caption scrolling.
6. Run focused Flutter tutorial tests and `npm run check:mobile` (or the current equivalent). Capture **representative successive frames/video or a timed screenshot series** on a task-owned isolated Android emulator: Home press → Projects slide → page hold → easing scroll → focus; card → detail; same-surface movement; caption light/dark. Inspect for flicker, scroll overshoot and caption clipping.
7. Report completed and skipped QA precisely. Do not reset hosted/shared databases, change Play release artifacts or overwrite the founder's installed app.

## Delivery

- Use latest `main` and create one scoped branch/PR, following current repository conventions. Do not merge, deploy or publish without explicit direction.
- In the report, describe the before/after UX, motion timing, project choice policy, affected components, tests and evidence, and outstanding limitations.
- If a requested effect would require brittle gesture synthesis or unsafe navigation, choose the closest simpler **visual-only** cue and explain the tradeoff.
- **Codex requires no documents outside the GitHub repository** for this implementation. The relevant behavior and test scaffolding are there; private attachments and the wider Design Doc are not prerequisites.
