# UIAUDIT01 native review tools

This folder owns the one-time native review in
`history-implementations/PLANETS_UIAUDIT01_pixel9pro_screenshot_review.md`.
It does not change product widgets, introduce a reporting service, activate a
hosted experiment, or authorize the proposed UI changes.

- `local-world.mjs` creates **two new** disposable Supabase projects in a fresh
  OS-temp directory, with independent signing/API keys, the canonical migration
  inventory and original ten Mock personas. It runs the existing read-only seed
  verifier and serves the actual persona broker on IPv4 loopback. HTTP and
  WebSocket product traffic reaches the real local Mock stack.
- `scenarios.mjs` adds a few genuine RPC interactions between those same fixed
  personas: reversed participation, a separate Resource conversation, accepted
  Find People contact and pending interest. It refuses other paths/ports and
  verifies the same-pair invariant without rewriting original fixtures.
- `owned-world.mjs` shares the OS-temp, disposable opt-in, loopback port, CLI
  manifest and database-generation checks used by additive helpers.
- `evidence.mjs` prepares ordinary fictional report/evidence relationships;
  `diagnostics.mjs` reads Iris's own report projection without staff access.
- `continuations.mjs` adds 22 Resource conversations for native pagination,
  one Project resource need and one saved search. `agreement.mjs` proposes terms
  for the original additive Resource request; acceptance uses the real app UI.
- `relationships.mjs` creates private participant/organizer invitations, an Idea
  invitation and a pending three-Group coordination proposal. `links.mjs` adds
  Idea-link and Group-authority previews. `invitation-diagnostics.mjs` reads the
  ordinary preview/admission context. Capability receipts stay private.
- `gate.mjs <owned-temp-directory> true|false` changes only the documented local
  experiment singleton after the same ownership checks; restore `true` after
  fresh gate-OFF reads and identity-only exit checks.
- `host.py` receives bounded integration commands/results over loopback and
  records **unresized Android PNGs** from the explicitly selected task emulator.
  It supports Dart's chunked POST transport. It never marks images reviewed.
- `session.py` executes an explicit JSON list of commands/checkpoints. A missing
  target or native timeout fails rather than being treated as captured coverage.
  UTF-8 stdout is explicit for Windows scenario text.
- `inventory.py` inventories balanced `GoRoute` declarations, expands both
  current dynamic Group route maps, and lists modal/pushed-page call sites.
  This is a starting inventory; it does not establish reachability or coverage.
- `report.py` validates the manually reconciled `review.json`, hashes and review
  status, then derives portrait PDF pages, detail crops, notes, one pending vote
  per finding and the allowlisted source ZIP. It never edits original PNGs.

The native counterpart is
`apps/mobile/integration_test/ui_audit_test.dart`. It uses the ordinary product
bootstrap, router, confidential session storage and real account selector.
There are no injected Auth snapshots or fake product gateways. Direct router
continuations review real authorized pages but do not prove every navigation
affordance. The harness waits through complete realm replacement before reading
the new scope. Android supplies the actual IME and system bars.

## Explicit local run

Inspect available memory, processes, AVDs, container ownership and free ports
first. Reserve task-owned `emulator-5580` and ports 58320–58329, 59320–59329,
59421 and 58420; never reset an existing stack. The recorded Windows run selects
the existing `planets-cocreate-qa-root` Podman connection and matching named pipe
only for new projects. It never stops another task's containers or engine.

With the locked Node dependencies installed and a compatible local engine:

```powershell
$env:PLANETS_DISPOSABLE_QA='1'
$env:CONTAINER_CONNECTION='planets-cocreate-qa-root'
$env:DOCKER_HOST='npipe:////./pipe/podman-planets-cocreate-qa'
node scripts/ui-audit/local-world.mjs
```

The command prints its **owned temp directory**, never credentials. Its private
stack configuration, CLI logs and `private-defines.json` stay outside the repo
and archive. Run helpers once on that fresh world in this order: `scenarios`,
`evidence`, `continuations`, `relationships`, `agreement`, `links` (each receives
the owned temp directory). Diagnostics are read-only. Native interactions then
extend that world, so a fresh rerun has different object IDs and timestamps.
Do not replay additive scenarios on a retained shared dataset.

Create a fresh output directory through `host.py --root <new-output-directory>`.
Only an intentional process restart of the same run uses `--resume`; existing
capture metadata then preserves letters and avoids overwriting originals.
The host requires Python's standard library. PDF generation additionally used
ReportLab 4.4.9, Pillow 12.3.0 and pypdf 6.10.0 from the desktop's bundled Python;
PDF rendering for visual QA used pypdfium2 5.14.0. No runtime dependency was added
to the app. The generator uses installed Arial on Windows or DejaVu Sans on Linux.

Create a **new** SDK `pixel_9_pro` AVD with the installed compatible image. Check
its actual `wm size`, `wm density`, font scale, insets and navigation mode; panel
pixels do not establish logical dp. The recorded API 36 image/profile yielded
1280 × 2856 px, density 480, 426.7 × 952 dp, 1.0 font scale and gesture mode 2.
Set Italian through Android app locales or the app's real language UI, system
dark mode and the required time zone. Keep hardware keyboard disabled.
Emulator 37.2.12 raised the requested RAM limit to **4096 MiB**; record actual
`/proc/meminfo` and leave sufficient host/container memory. Local timeouts and
cold-boot System UI ANR do not establish shipped performance defects.

Build from `apps/mobile`, using only the generated **client-safe** defines:

```text
flutter build apk --profile --no-pub --target-platform android-x64 -t integration_test/ui_audit_test.dart --dart-define-from-file=<owned-temp>/private-defines.json
```

Reverse 58321, 59421 and 58420 to the owned emulator, install that APK there and
launch its ordinary activity. The explicit integration target runs its local
bridge; no driver serializes PNGs into JSON. Capture with `session.py` or the
host's `--command` / `--capture` arguments. Give a meaningful title, state and
role, confirm the actual persona/realm, and record blocked scenarios explicitly.
Inspect every original in an image viewer before setting `visuallyReviewed`.
The ordinary normal-account journey uses the real local Mailpit OTP, explicit
policy acceptance and profile setup. Keep the actual OTP and mail payloads out
of captures and exports. No support/deletion email needs to be sent.

The router's `routeInformationProvider` can retain a parent URI after a pushed
page opens. Reconcile the visible top page and navigation/source into an
`effectiveRoute`, preserving the reported parent separately. Wait for actual
settled UI and dismiss visible session prompts before counting the underlying
screen; a successful tap command alone is not proof that an overlay was absent.
Offscreen lazy-list targets must first be brought into the built viewport.
An unkeyed field finder can include fields beneath a dialog; confirm the modal's
field index or use its key. Android sheets can appear between Flutter's status
snapshot and ADB's capture, so the visible original takes precedence.
Google OAuth was unconfigured in this run: both sign-in entries use the real
email/OTP form. A Google provider handoff is not part of the captured evidence.

The final run manifest records source/APK hashes, each harness build, backend
inventory, actual settings and limitations. Keep original and derived paths
separate. PDF proposals and screenshot notes derive from the same findings;
repeat observations link to one existing ID. Render and visually inspect the
PDF, including dense pages at phone width, before delivering both files.

After export, stop only the projects listed in this run's private manifest,
remove its reverse rules/emulator, and delete its temporary credentials/logs.
The required PDF/ZIP live outside the task worktree so checkout cleanup does not
remove the delivered review. No recurring CI job was added for this audit.
