# PLAY-ASSETS01 — Google Play visual assets

## Task

Create an upload-ready Italian Google Play visual asset pack for PLANETS Community. Do the work, capture the running Android app, inspect the results, and deliver the files with a preview. This is an asset-production task, not a proposal for how someone else could do it.

Repository: `lillo24/planets.community`.

The product covers both local initiatives/events/collaborative projects and physical-object barter/donation through Scambio e Dona. Give both sides clear visibility. Use “persone della tua città” where appropriate, rather than “vicinato”.

Read `AGENTS.md`, relevant nested instructions, `docs/development/codex-tooling.md`, and the existing brand/mobile/demo tooling before working. Follow the repository's isolated worktree and PR workflow. Preserve other tasks, uncommitted work, retained demo data, and existing emulator processes.

## Source and build

- Use latest `main` for this draft pack unless the current release task explicitly pins another source commit. Record the exact commit used for every app capture.
- An older testing AAB was prepared in PR #149 on `codex/ct01-play-closed-test`. Do not assume that artifact represents current `main`, update that release branch incidentally, or silently label these assets as matching it.
- Final screenshots must represent the version actually distributed. If the existing release artifact differs, report that the AAB must be rebuilt from the captured source or the screenshots must be recaptured from its source before upload. This does not block preparing and reviewing the draft pack.
- Run the real Flutter Android app on an emulator/device you can access. A web/mobile-sized browser render is not a substitute for an Android capture.
- Set the app to Italian using its supported locale setting. Use its normal theme and release-like presentation. Remove demo controls/markers through the existing supported configuration, such as `ENABLE_DEMO_TOOLS=false`, rather than editing them out of screenshots.
- Inspect the current npm/Flutter commands and configuration before invoking them. The documented local commands include `npm run db:start`, `npm run mobile:config:local -- --host 10.0.2.2`, and `npm run dev:mobile:clean`; verify they still apply to this checkout and device.
- Use existing deterministic synthetic demo fixtures in an owned disposable local environment. Create any needed coherent demo activity/listing/chat records through supported flows or existing fixture tooling. Do not reset a retained database, modify shared/staging/production data, or use real users' private information for this task.
- Keep actual config, credentials, OTPs, session tokens, signing files, and device/account state out of outputs and commits.

## Deliverables

Create a clearly named `play-store-assets/it-IT/` pack in the repository's existing asset/export convention, or an appropriate dedicated location if none exists. Preserve editable artwork and a small reproducible export process where practical.

| File | Required format |
| --- | --- |
| `app-icon.png` | 512 × 512, 32-bit RGBA PNG, sRGB, at most 1,024 KB |
| `feature-graphic.png` | 1024 × 500, opaque RGB PNG, at most 15 MB |
| `phone/01-iniziative.png` | 1080 × 1920, opaque RGB PNG, at most 8 MB |
| `phone/02-dettagli-attivita.png` | Same phone format |
| `phone/03-scambio-dona.png` | Same phone format |
| `phone/04-chat.png` | Same phone format |
| `preview.jpg` | A readable contact sheet of the icon, feature graphic and final screenshots; not a Play upload asset |
| `asset-manifest.json` | Dimensions, file sizes, formats, SHA-256 hashes, Italian alt text, capture source commit and provenance |
| `README.md` | Brief upload mapping, reproduction commands and any actual limitations |

Deliver an easy-to-find ZIP containing the upload-ready assets and manifest/readme. Keep editable sources and automation outside the upload-only images if that makes the pack clearer.

### App icon

- Reuse the founder-supplied PLANETS logo. A known source is `apps/mobile/assets/brand/planets-logo.png`; inspect the site brand directory and launcher assets for higher-resolution originals before exporting.
- Preserve the existing logo and identity. Inspect its dimensions and alpha/background rather than assuming it already satisfies Play requirements.
- Compose it legibly on a full-square canvas using the existing brand palette and sensible padding. Do not bake in rounded corners or an outer drop shadow; Play supplies those.
- Avoid a visibly blurry enlargement. If no source is adequate, deliver the best faithful draft and state the precise source limitation; do not invent a replacement logo.

### Feature graphic

- Design a polished, readable graphic using the app/site's actual colors, typography, orbit motifs and existing artwork. Keep important content toward the center and away from crop zones.
- Convey initiatives/events and exchanging/donating objects together. Suggested concise Italian copy: “Iniziative, eventi e scambi nella tua città”. Adjust line breaks and wording if necessary for readability.
- Keep the composition simple. Avoid a giant duplicate app icon, excessive fine detail, phone hardware mockups, store badges, unsupported promises, rankings, awards, prices or download calls to action.
- Use exact typography and faithful brand artwork. If generated imagery is useful and supported, limit it to decorative artwork; never generate fake app screens or redesign the logo.

### Phone screenshots

Capture these four distinct, useful screens from the actual app:

1. Discovery of initiatives/events, with attractive, coherent synthetic activities and loaded covers.
2. A real activity detail view showing its purpose and the normal participation flow.
3. Scambio e Dona, clearly showing physical objects offered for barter/donation with loaded covers.
4. A normal project or resource conversation with a short, realistic synthetic exchange showing coordination.

You may add one or two useful extra screenshots, such as Tavoli or a Scambio detail, if they show a distinct core experience. Keep the total between four and eight.

- Prioritize real UI, especially in the first three screenshots. Plain clean captures are acceptable and preferable to a rushed decorative layout.
- Use a native 1080 × 1920 emulator viewport if feasible. If a store layout is needed to preserve a taller real capture, fit the capture proportionally on a 1080 × 1920 canvas without stretching, cutting core UI, or making text unreadable.
- Optional Italian headings may occupy at most 20% of the image. Examples: “Trova iniziative nella tua città”, “Partecipa e realizza idee insieme”, “Scambia o dona oggetti”, “Organizzati nelle chat”. Do not rewrite app labels or composite invented UI into the capture.
- Ensure there are no loading/error states, broken images, keyboards obscuring content, debug overlays, exposed emails, exact private addresses or genuine private conversations.
- Clean the system status bar through supported emulator/device controls where available. Keep the app itself intact; do not conceal a product defect with image editing.
- Do not advertise map functionality or any other disabled/unimplemented feature merely because it appears in a plan or recent commit.
- Keep raw capture provenance separate from final exports, with source commit and device/render settings recorded.

## Validation and completion

Consult Google's current primary guidance and reconcile any changed requirements:

- https://support.google.com/googleplay/android-developer/answer/9866151
- https://developer.android.com/distribute/google-play/resources/icon-design-specifications
- https://support.google.com/googleplay/android-developer/answer/9898842

Check actual exported dimensions, PNG color mode/alpha, file sizes, aspect ratios and successful decoding. Inspect every image at full size and thumbnail size; verify legibility, faithful branding, Italian text and balanced coverage of activities and barter/donation. Iterate on visible defects before delivering.

Use change-scoped checks for any tooling or code you add. Do not run unrelated full database/mobile/web suites for an image-only change. Keep any app bug fixes required for capture separate and report them rather than broadening this task silently.

Follow the repository PR workflow for intended assets and tooling. Opening or merging that source PR does not authorize Play uploads, release publication or production deployment. Do not upload to Play Console, publish a release, change policies/age settings, or start the closed-testing rollout in this task.

If an emulator/auth/backend limitation blocks screenshots, finish the icon, feature graphic and export tooling, then report the exact blocker and missing captures. Never replace unavailable captures with fabricated screens or claim the full pack is complete.

Final response: give clickable absolute local links to the ZIP and preview, show the preview, identify the source commit/device, summarize the format checks, and state any release-version mismatch or remaining blocker. Avoid requiring me to perform steps Codex can safely complete itself.
