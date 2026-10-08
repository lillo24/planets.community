# Google Play visual assets

This folder owns the Italian PLANETS store artwork, original Android captures,
and deterministic export/validation. It does not change the app or release setup.

- `artwork/` contains editable SVGs referencing the unchanged founder logo and
  existing licensed demo photos. Colors and Segoe UI typography follow
  `apps/site/src/styles.css`. Segoe UI is the website's installed Windows fallback;
  exports must be made on Windows with that font installed.
- `captures/it-IT/` retains original Android PNGs and sanitized provenance.
- `prepare-demo-clock.mjs` adjusts only the two existing synthetic activity
  schedules through authenticated creator RPCs. It rejects any project ID/API
  other than the owned disposable capture stack and preserves other content,
  skills and capacity. Its fixed dates reproduce this October 2026 session;
  a future live recapture needs explicitly chosen future dates.
- `render-artwork.mjs` renders only artwork, with an installed Chrome and
  Playwright. It checks that every referenced image decodes. `PLAYWRIGHT_MODULE`
  optionally selects an existing Playwright package directory;
  `PLAYWRIGHT_BROWSER` optionally selects another installed Playwright channel.
- `export.py` requires Pillow, embeds sRGB, exports Play formats, builds the
  contact sheet and upload ZIP, and verifies the manifest and original app pixels.
- `it-IT/` is the upload pack, including alt text and upload mapping. The ZIP is a
  reproducible local export and is excluded from Git; its contact sheet is also
  excluded from the ZIP's upload inventory.

## Reproduce artwork and exports

Use an existing Playwright/Chrome installation and a Python environment with
Pillow. The Codex desktop bundled runtime supplies both packages; use
`load_workspace_dependencies` to find its current paths. Do not add app runtime
dependencies to export artwork.

```powershell
# Only if Playwright is outside this checkout's Node resolution:
$env:PLAYWRIGHT_MODULE = '<existing Playwright package directory>'
node docs/play-store-assets/render-artwork.mjs
<python-with-Pillow> docs/play-store-assets/export.py
<python-with-Pillow> docs/play-store-assets/export.py --verify
```

The default export fails if any required real capture is missing. `--partial`
explicitly produces an INCOMPLETE ZIP and contact-sheet missing-capture markers;
those markers are never exported as phone screenshots. All PNGs are decoded and
checked for dimensions, bit depth, color mode/alpha, sRGB, byte limits, hashes,
Italian alt-text length and inventory. Phone RGB pixels must equal the original
capture exactly. The exporter never stretches, crops, retouches or invents app UI.

## Reproduce Android captures

Use the app source commit in `captures/it-IT/provenance.json`. Start from an
isolated checkout, inspect `supabase/config.toml` and local tools, and select a
**new disposable** project ID with free ports. For this task the selected ID was
`planets-play-assets01`; API/DB/Studio/Mailpit ports were
54621/54622/54623/54624, with all other configured local ports similarly isolated.
These temporary local changes are not part of the committed asset change.
Never reset a retained demo environment or share a stack with mutation verifiers.

```powershell
npm ci
npm run restore:mobile
npm run db:start
$env:MAILPIT_URL = 'http://127.0.0.1:54624'
npm run demo:seed:local
# Capture-specific coherent daytime schedules, after the baseline demo verifier:
node docs/play-store-assets/prepare-demo-clock.mjs
npm run mobile:config:local -- --host 10.0.2.2
cd apps/mobile
flutter build apk --release --target-platform android-x64 --dart-define-from-file=config/local.json --dart-define=ENABLE_DEMO_TOOLS=false
```

Use an owned Android 15 / API 35 x86_64 emulator at 1080 × 1920 and 320 dpi
(540 × 960 dp), light system theme, portrait, font scale 1.0. Install the resulting
APK only on that emulator. Select Italiano through Settings → Language, dismiss
the first-install tutorial through its normal Skip action, and sign in through
the normal local email OTP flow as a synthetic demo persona. Keep OTP/session
details out of scripts, logs, images and commits. Use Android SystemUI demo mode
for 09:41 and supported status-bar disable flags to hide system/notification icons:

```powershell
adb -s <owned-emulator> shell settings put global sysui_demo_allowed 1
adb -s <owned-emulator> shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm 0941
adb -s <owned-emulator> shell cmd statusbar send-disable-flag system-icons notification-icons
```

Restore flags with `send-disable-flag none` when ending the owned device session.
The displayed clock and all app/navigation pixels remain native Android output.

Sign in as the synthetic Sara persona. Search public projects for `Coloriamo`
to select the original mural fixture, then `aggiustiamo` for the original Repair
Café. Scroll its real detail page until purpose and participation are visible.
Open Scambio e Dona from Home, and the mural Project chat from Messages → Groups.
Inspect loading, covers, language,
keyboard and visible private fields before each capture. Capture with ADB:

```powershell
adb -s <owned-emulator> shell screencap -p /sdcard/play-assets.png
adb -s <owned-emulator> pull /sdcard/play-assets.png docs/play-store-assets/captures/it-IT/<filename>.png
```

Record the APK SHA-256, exact source commit, device/settings, capture time and raw
SHA-256 in provenance before export. Never use a web screenshot or tutorial
illustration as an Android capture. The demo covers are stock activity/object
photos, not photographs of named demo participants; original photographers,
license and checksums are in `scripts/demo-assets/assets.json` and its README.

## Primary guidance checked

Google's [preview asset guidance](https://support.google.com/googleplay/android-developer/answer/9866151),
[icon specifications](https://developer.android.com/distribute/google-play/resources/icon-design-specifications)
and [metadata policy](https://support.google.com/googleplay/android-developer/answer/9898842)
were checked on 8 October 2026. The requested sizes remain compatible: square
512 px 32-bit sRGB icon, opaque 1024 × 500 feature graphic, and four opaque
1080 × 1920 portrait captures (five supplied). The graphics contain no store badges, rankings,
awards, download calls to action, prices or map promises.

The asset PR is separate from Play submission and release approval. See the
pack README for the actual capture status and release-version compatibility.

## Validation record — 8 October 2026

- Native Flutter release APK build passed from the recorded main source.
- Baseline deterministic demo verification passed on the owned fresh stack;
  creator RPC schedule updates passed, including an idempotent rerun.
  The fixture guard rejected the canonical retained project after local
  capture configuration was restored.
- Both JavaScript files passed `node --check`; the Python exporter passed
  `py_compile`; Markdown, JavaScript and capture JSON passed Prettier.
- All seven PNGs passed dimensions, 8-bit color type, sRGB, decoding, byte limits,
  opacity, alt-text length, inventory and SHA-256 checks. All five phone images
  passed exact RGB pixel equality with the original native captures.
- Every image was inspected at full size and on the contact sheet. Complete
  export and independent verification passed; repeated export produced an
  identical ZIP, and ZIP integrity passed. A missing mandatory capture failed
  strict export as expected during preparation.
- No application, migration, shared tooling or CI configuration changed.
  Unrelated database/mobile/web suites are excluded by the task's scoped policy.
  Local backend/device state and build artifacts are excluded from this pack.
