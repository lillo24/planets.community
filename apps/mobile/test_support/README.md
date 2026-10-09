# Disposable mobile GUI rehearsal

`map_discovery_fixture.dart` supplies MAP05 public DTOs and bounded synthetic
center/tile gateways. `map05_app_fixture.dart` connects actual List/Map/detail
widgets to those fakes. `integration_test/map_discovery_smoke_test.dart` owns the
Android journey and rejects any network attempt; `test_driver/map05_driver.dart`
exports screenshots to an explicitly selected host directory. Production imports
none of these harnesses. See [MAP05](../../../docs/development/map05-interactive-discovery.md).

`map02_rehearsal.dart` is a debug-only, explicitly opted-in
(`MAP02_REHEARSAL=true`) harness for the real Proposal/Tavolo/Resource editors.
All domain/location gateways are deterministic fakes with a reserved `.invalid`
URL. `map02_native_smoke.dart` takes a verified task-owned VM URI and capture
directory and exercises EN/IT typing, explicit selection, independent Project
slots and ordinary draft saves. It proves presentation, not live Geoapify,
database writes or iOS. Use an isolated emulator and preserve other ADB sessions.
See the [MAP02 runbook](../../../docs/development/map02-location-selector.md).

`ui_next04_native_smoke.dart` exercises the disabled map/manual-entry foundation
on the explicitly opted-in UI02 fake-gateway harness built from the UI04 checkout.
Pass the verified owned emulator VM URI and capture directory. It makes no live
provider call and is not autocomplete/map-provider readiness evidence.

`pi05_driver.dart` enables the Flutter SDK driver extension before using the
normal `bootstrapApplication` boundary. It requires a debug build, explicit
`PI05_LOCAL_REHEARSAL=true`, `APP_ENV=local` and the PI05 backend at port 58921
on loopback or the Android emulator's host alias. It creates no session or
membership and replaces no production repository. Production uses `lib/main.dart`.
Its `ext.planets.pi05.openInvitation` debug service extension accepts only the
configured Proposal/Tavolo case name and opens the normal internal route using
the ignored compile-time fixture. It does not accept the invitation or transfer
authentication. Use `--mobile-config` on the opted-in browser fixture to generate
the private local configuration, and never log/export that file or its tokens.

The [PI05 record](../../../docs/implementation/pi05-integration-qa-and-demo-data.md)
owns setup, actual GUI observations and the manual journey procedure. Driver
actions against an internally opened route do not prove HTTPS OS dispatch or
signed-domain association.

## UI-NEXT-01 native presentation rehearsal

`ui_next01_rehearsal.dart` runs the actual PlanetsApp/widgets with deterministic
Auth, Profile, Messages, Notifications and Proposal/participation gateways.
It rejects profile/release or a missing `UI_NEXT01_REHEARSAL=true` opt-in. Its
reserved `.invalid` URL has no live backend; numeric OTP `123456` and profile
Save are fixture operations. It proves native presentation/keyboard/Back/hot
reload behavior, not live email delivery, authorization or database writes.
Production continues to use `lib/main.dart` and the normal repositories.

Use only an explicitly selected disposable emulator: this harness uses the
normal debug application identifier. For example, from `apps/mobile`:

```text
flutter run -d emulator-5580 -t test_support/ui_next01_rehearsal.dart --dart-define=UI_NEXT01_REHEARSAL=true
```

A read-only temporary emulator session (`-read-only -no-snapshot
-no-snapshot-save`) preserves the saved AVD. Never replace an app on the founder's
phone or an owned active device for this rehearsal. Explore stays public; Log in
can be cancelled with the toolbar or Android Back. Messages login leads to its
incomplete-profile context; setup Back returns there, while fixture Save completes
readiness and returns to Messages. Native iOS needs an iOS-capable host/device.

## UI-NEXT-02 native presentation rehearsal

`ui_next02_rehearsal.dart` uses a ready synthetic identity and deterministic
Project/Tavolo/Resource inventories. Opt in only with a debug build and
`UI_NEXT02_REHEARSAL=true`, targeting an explicitly selected temporary emulator.
The driver extension is absent from the production entry point. Its bounded
`populated`/`empty` handler changes only fake gateway records and reloads the
normal owner controllers; no backend write or real session is available.

From `apps/mobile`, launch `flutter run -d emulator-5580 -t
test_support/ui_next02_rehearsal.dart --dart-define=UI_NEXT02_REHEARSAL=true`.
Use the VM URI printed by that owned run, then `dart run
test_support/ui_next02_native_smoke.dart <owned-vm-uri> <capture-directory>`.
The smoke validates its fixture handler before any UI action, repeats family
switches, opens contextual and unrestricted drafts, then observes a genuinely
empty inventory. Captures are presentation evidence, not canonical backend QA.

UI-NEXT-03 reuses the opted-in UI02 fake-gateway harness built from its own
checkout. `dart run test_support/ui_next03_native_smoke.dart <owned-vm-uri>
<capture-directory>` exercises chooser, scratch capacity/skills, footer,
overwrite cancellation and explicit draft save. This driver confirms the bounded
fixture handler before UI actions and never targets the founder's phone.

## MAP03 native rehearsal

map03_rehearsal.dart requires an opted-in debug build and uses real cards/shared
panels with deterministic preview/image/Maps gateways. map03_native_smoke.dart
takes an owned VM URI and capture directory and checks distinct card taps,
three details, EN/IT and zero disabled image calls. Production uses lib/main.dart.
See [MAP03](../../../docs/development/map03-location-previews.md).
