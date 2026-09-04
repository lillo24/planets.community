# Application composition

This folder owns application startup presentation and navigation, not backend rules.

- `planets_app.dart` composes Riverpod, themes, localization and `MaterialApp.router`.
- `router/app_router.dart` owns routes, Auth/readiness redirects and the identity-scoped routing configuration.
- `router/app_navigation_shell.dart` owns the single Material 3 navigation bar and branch ordering.
- `foundation_screen.dart` is Home; its Browse CTA uses the shell's branch switch.
- `startup_failure_app.dart` is the safe fallback when bootstrap cannot launch the application.

## Navigation contract

`StatefulShellRoute.indexedStack` (go_router 18) gives each destination its own Navigator:

| Index / destination | Routes |
| --- | --- |
| 0 / Profile | `/profile`, nested `/profile/edit` |
| 1 / Browse | `/proposals` and `/tavoli`, each with nested `mine`, `create`, `:id`, and `:id/edit` |
| 2 / Home | `/` |

Static Browse children precede each dynamic activity-ID route. A route-backed
Proposals/Tavoli switcher changes the public list within Browse without adding a
fourth bottom destination. Each list's Riverpod state survives switching. Direct entry creates
the matching nested stack and selects its owning destination. Nested AppBar and
system Back pop within that stack. Branch switches use `goBranch`, restoring its
last route, scroll and unsaved form state; re-tapping the active destination is a
no-op. Browse root actions use `go` to build canonical nested stacks, including
when a guard redirects Create/My activity routes into a different branch.

`/auth` and `/auth/verify` live outside the shell and have no bottom navigation.
Home and Browse list/detail remain public. Signed-out Profile/management access
uses the existing Auth flow with a sanitized internal `returnTo`. Incomplete
profiles can use Home/Browse freely; Profile opens completion when the profile
anchor exists, and management redirects to `/profile/edit`. Missing-anchor retry
and email-OTP behavior are unchanged. Saving a valid profile returns to Profile.

## Retention and identity

Tab retention is in-memory only, scoped to the same authenticated identity. On
sign-in, sign-out or account change, the routing configuration creates fresh
shell/branch keys and reparses the current URL through the same guards. This
discards every retained branch (including inactive private forms) without losing
an in-flight Auth return destination. A same-identity token refresh does not reset
the shell. No form data is persisted to disk for this behavior.

Profile, proposal, and Tavoli owner controllers also clear cached state and increment a
request revision on identity changes. Every async continuation checks that its
revision is still current before publishing state or starting another operation.
Thus A -> signed out -> A also rejects old work. Profile readiness cannot be
restored by an old save. Existing rendered-identity checks and expected-ID RPC
parameters remain in force; database authorization is unchanged.

Router/widget regressions live in `test/app/router/navigation_shell_test.dart`.
Native Android/iOS navigation, keyboard and hot-reload QA remains a separate,
manual pre-merge gate; automated widget tests are not a substitute.
