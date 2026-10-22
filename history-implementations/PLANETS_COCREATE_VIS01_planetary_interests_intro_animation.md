# PLANETS COCREATE-VIS01 — Animated “Trova persone” interests introduction

**Type:** Focused visual/UX prototype and Codex implementation handoff. This is **not** authorization to implement a new social domain or broaden the Co-Creation programme.

## Objective

Make the *Trova persone* idea immediately understandable through a short, attractive, native Flutter animation inspired by PLANETS' orbit identity. A few small planets orbit a central composition; each represents an interest area, and short example-interest labels bloom or burst outward from that planet. The message is: people can find one another through shared interests and form communities.

Prototype this as a **contextual introduction inside Trova persone** (first ordinary entry, replayable), not as a new compulsory step in the app-wide startup tutorial. This placement is a reversible UX choice for the prototype, not a final decision about onboarding across the app.

## Current repository evidence and integration boundary

Checked on 2026-10-22:

- Repository: `lillo24/planets.community`, `main` at `f938e017a02ffa554994c7c212f0fb47cc627b55` when inspected. Recheck current refs before editing.
- `history-implementations/PLANETS_COCREATE00_trova_persone_roadmap_and_mock.md` defines people-seeking posts, topic **Comunità / Hubs** and distinct numbered groups; it originally planned a sandbox-only A00.
- `history-implementations/PLANETS_COCREATE_RUNALL_autonomous_implementation.md` supersedes that A00-only restriction for the **separate**, continuing Co-Creation programme.
- **PR #287** (`codex/cocreate-runall`, draft/open at inspection) contains A00 UI and a developing B/C backend. Its `apps/mobile/lib/features/co_creation/presentation/co_creation_demo_screens.dart` has the `/people` demo browse, and `apps/mobile/lib/app/router/app_router.dart` currently maps `/people` to that UI. The route and screen may change as that programme progresses; inspect the *current* implementation before integration.
- `apps/mobile/lib/core/widgets/planets_hero.dart`, `planets_starfield.dart` and their README establish native PLANETS circular orbit/star motion, brand asset, dark/light colors, reduced-motion, route visibility and lifecycle conventions. The startup tutorial already has its own separately versioned `/intro` guided flow (`apps/mobile/lib/app/startup/`); **preserve it**.
- The Co-Creation sandbox preference is device-local and OFF by default (`planets.sandbox.coCreation`); it must remain independent of any real backend experiment gate.

**Parallel-work rule:** Do not edit, reset or take over another Codex agent's running worktree or active `codex/cocreate-runall` branch. If PR #287 remains unmerged, work from a stable current Co-Creation head in an **isolated dependent branch/worktree**, open a focused PR targeting the integration branch, and clearly state the dependency. Rebase as needed when that branch advances. If the Co-Creation UI has merged into `main`, use the normal separate-branch → PR workflow against `main`. Avoid disrupting the autonomous programme; do **not** merge PR #287 or deploy anything as part of VIS01.

**External context:** None required. This prompt contains the complete visual concept. No Google Doc, asset export, account, API key, illustration service, paid animation service or private device is required.

## Visual direction

- A compact, inviting PLANETS-like miniature solar system: **three softly colored planets** orbit in a composed scene, with faint orbit paths and modest star/space accents. Fit the established brand palette and current light/dark themes rather than imposing unrelated neon visuals or an unrelated 3D art style.
- Each planet represents an **interest area**, with brief labels that appear near it (small outward displacement + fade/scale; soft, readable, not an explosion of particles). Example sequence:
  - **Giochi da tavolo / Board games** → **Fuso**, **Lupus in Fabula**.
  - **Concerti / Concerts** → **The Strokes**, **Måneskin**.
  - **Videogiochi / Video games** → **Valorant**.
- These are **illustrative interests only**. Do not create topic records, infer available groups or chats, imply that these artists/games are official PLANETS partners, or suggest that an existing community already contains people. Text only; no copyrighted logos, cover art or external imagery. No sports category in this initial example.
- Prefer a finite, smooth presentation of roughly **5–7 seconds**, culminating in a readable settled state. Stagger planet/label arrivals rather than animating everything at once. A calm orbit may continue subtly while visible only if it adds clarity and remains efficient. Avoid a perpetual attention-grabbing loop in the browsing screen.
- Short localized copy above/below the animation should connect interests to finding people (e.g. “Ogni passione può avvicinare persone” / “Shared interests bring people together”). Keep the illustration/example nature clear in Sandbox/Demo mode. Use existing localization structure for Italian and English; preserve proper-noun spelling.
- The animation must remain visually legible at small widths and large text scales: dynamically simplify/decrease decorative elements instead of clipping labels, placing them under buttons or causing horizontal overflow.

## UX behavior

1. While the Co-Creation sandbox mode is enabled, the **first ordinary entry to Trova persone** can open this lightweight intro before its browse content. Use an installation-local, testable “intro seen” preference consistent with current settings/startup conventions; do **not** collect or store user interests or send analytics. Do not change existing first-run tutorial completion/version state. Avoid showing this when landing on a deeper `/people/...` destination or resuming a protected flow.
2. Show **“Esplora / Explore”** and **“Salta / Skip”** controls from the first frame. Either should immediately open the actual Trova persone browse (Demo now, live later) without waiting for animation to finish. Finishing animation itself must not automatically navigate. Back exits/returns safely through existing route semantics; no trapping.
3. Provide an unobtrusive **“Rivedi introduzione / Replay intro”** entry from the Trova persone screen (e.g. info action), so the demo can be reviewed repeatedly even after the local preference marks it seen. Replaying must not mark user actions as published/joined or disturb current browse state/filters if returning to it.
4. Turning Co-Creation mode OFF must preserve current baseline routes and not leave a dangling intro route; a future OFF→ON should honor the previously seen state unless explicitly replayed. Keep the existing bottom navigation, Activities Split preference and canonical product actions unchanged.
5. When `MediaQuery.disableAnimations`, system reduce-motion or equivalent applies, show a **static, fully understandable composition** with category/interest labels and usable actions; no ticking controller. Animation must pause/dispose correctly when backgrounded, navigated away from or covered. Do not let the tutorial continue consuming GPU/CPU when hidden.
6. Decorative planet motion is not required to be interactive; ensure one concise accessible description of the concept and real semantics for actionable controls. Use the established PLANETS page controls/focus semantics and localization. Do not announce rapidly changing labels to screen readers.

## Engineering guidance and non-goals

- Implement as **native Flutter presentation code** close to the Co-Creation feature. Inspect `PlanetsHero`/`PlanetsOrbitMotion` and reuse shared styling/motion techniques where sensible, without forcing the full Home/Welcome hero geometry onto this smaller scene. A small `CustomPainter` or composed widgets with finite controllers are both acceptable; choose the simpler maintainable approach.
- No video/GIF download, webview, Lottie/Rive dependency, new paid service, network request or new asset pipeline unless repository evidence demonstrates a compelling existing reuse path. Offline-first and deterministic/testable animation are preferred.
- Keep the tutorial **out of canonical Posts/Hubs/Groups data, chat, backend, analytics, moderation and user identity**. Do not alter Co-Creation post/domain implementations or unrelated startup screens. No Supabase migration, API changes, new data records, false membership or notifications.
- This is a **UI exploration**, not approval of the final taxonomy, community creation policy, participant discovery algorithm or persistence model. Distinguish the broad interest areas shown in the animation from persisted topic hubs and numbered small groups.
- If the ongoing Co-Creation branch has reworked `/people`, integrate against its current single owner of entry/navigation rather than reverting it to the old Demo widget. Do not accidentally gate legitimate current members' Messages or exit operations behind the visual intro.

## Acceptance and tests

- The visual sequence clearly communicates **3 interest planets → example labels → shared interests → Trova persone**, using the supplied examples without showing made-up active community data.
- First normal entry, subsequent entry, explicit replay, Skip/Explore mid-animation, Back, toggle OFF mid-view and returning from replay work without stuck routes, duplicate overlays or lost browse state.
- Demonstrate widget tests with controlled fake time for initial/staggered/final frames; ensure no post-disposal ticker exceptions, no hidden looping and deterministic animation under test. Cover reduced-motion and background/route visibility where existing harnesses allow.
- Check Italian/English, light/dark, narrow ~320dp layout, larger text, touch targets and accessibility semantics. Inspect at least representative rendered frames (initial, labels in flight, settled/static), include screenshots or a brief preview recording when existing repo harnesses support them. Report explicitly anything not inspected on a physical phone.
- Run relevant Flutter analyzer, formatter, scoped tests and a practical mobile build. Preserve existing Co-Creation and startup tutorial tests. Record exact commands and results; no fabricated pass claims.
- Document the new contextual intro/replay behavior and local storage key near the Co-Creation feature's README. Include how to access it through Sandbox and how to reset/replay for QA.

## Deliverable

One focused implementation PR (dependent on the Co-Creation integration PR if necessary) with a functional, replayable visual prototype and tests, **not a general tutorial redesign**. No automatic merge, production enablement, store publishing or hosted migrations. Finish with the PR/commit links, visual evidence, exact tests, remaining caveats and a short explanation of how to try it in the app.
