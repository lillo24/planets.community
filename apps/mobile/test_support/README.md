# Disposable mobile GUI rehearsal

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
