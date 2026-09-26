# Application composition

This folder owns application startup presentation and navigation, not backend rules.

- `planets_app.dart` composes Riverpod, themes, localization and `MaterialApp.router`.
- `router/app_router.dart` owns routes, Auth/readiness redirects and the identity-scoped routing configuration.
- `router/app_navigation_shell.dart` owns the single Material 3 navigation bar and branch ordering.
- `foundation_screen.dart` is Home; its Progetti entry uses the shell's Browse
  branch switch and its Scambio-Dona entry opens the Browse-owned resource routes.
- `startup_failure_app.dart` is the safe fallback when bootstrap cannot launch the application.

## Navigation contract

`StatefulShellRoute.indexedStack` (go_router 18) gives each destination its own Navigator:

| Index / destination | Routes |
| --- | --- |
| 0 / Profile | `/profile`, nested `/profile/edit` with an optional sanitized post-setup `returnTo` |
| 1 / Home | `/`, `/messages`, nested `/messages/requests/:requestId`, `/messages/chats/:chatId`, `/messages/chats/:chatId/info`, `/notifications`, and nested `/notifications/preferences` |
| 2 / Browse | `/proposals` and `/tavoli`, each with nested `mine`, `create`, `:id`, `:id/edit`, protected `:id/resources`, `:id/join`, and `:id/participants`; public `/resources` and `/resources/:listingId`; protected `/resources/mine`, `/resources/create`, `/resources/:listingId/edit`, and `/resources/:listingId/loan-schedule` |

Static Browse children precede each dynamic activity-ID route. A route-backed
Proposals/Tavoli switcher changes the public list within Browse without adding a
fourth bottom destination. Each list's Riverpod state survives switching. Direct entry creates
the matching nested stack and selects its owning destination. Drill-down actions
use `push`, so nested AppBar and system Back return to the previous screen.
Branch switches use `goBranch`, restoring Profile/Browse route, scroll, and
unsaved form state. Home always resets to `/`, including when re-tapped from a
Home-owned Messages or Notifications route. Browse list-family switches use
`go` to build canonical nested stacks, including when a guard redirects
Create/My activity routes into a different branch.

`/auth` and `/auth/verify` live outside the shell and have no bottom navigation.
Home and Browse list/detail, including Scambio-Dona list/detail, remain public.
Signed-out Profile shows a static, clearly labelled example without loading
account data; its explicit call to action opens Auth with `/profile` as the
sanitized `returnTo`. Profile edit and management access remain protected.
Incomplete profiles can use Home/Browse freely; Profile opens completion when the profile
anchor exists, and management redirects to `/profile/edit`. Scambio-Dona
management preserves the exact destination through both OTP and profile setup. Participation Join,
creator-review, Project resource management, Messages request/chat/group-info, and Notifications routes preserve their exact internal destination
through OTP and profile completion. Missing-anchor retry and email-OTP behavior
are unchanged. Saving a valid profile returns to the preserved participation or
Messages/Notifications route when present, otherwise to Profile.
For guarded Proposal/Tavolo Join setup, Profile edit keeps separate destinations:
Save resumes the exact sanitized Join route, while the visible Back action and
system Back return to the corresponding public Project detail. Other Profile
edit flows conservatively cancel to Profile.

## Retention and identity

Tab retention is in-memory only, scoped to the same authenticated identity. On
sign-in, sign-out or account change, the routing configuration creates fresh
shell/branch keys and reparses the current URL through the same guards. This
discards every retained branch (including inactive private forms) without losing
an in-flight Auth return destination. A same-identity token refresh does not reset
the shell. No form data is persisted to disk for this behavior.

Profile, proposal, Tavoli owner, Project-resource owner, Scambio-Dona owner/editor, participation, Messages, and Notifications controllers also clear cached state and increment a
request revision on identity changes. Every async continuation checks that its
revision is still current before publishing state or starting another operation.
Thus A -> signed out -> A also rejects old work. Profile readiness cannot be
restored by an old save. Existing rendered-identity checks and expected-ID RPC
parameters remain in force; database authorization is unchanged.

Participation protected-meeting data is an additional private state boundary:
it is loaded only for the creator/current member and cleared when identity or
current membership changes. It is never added to public activity models.

Messages request and Project-chat state are independent identity-bound
boundaries. Home exposes their shared two-tab entry point through an AppBar
action without changing the three-destination navigation bar. The
request-specific route is the client resolution target for 06A's semantic
`participation_request` notification target. Chat and group-info routes are
protected by the same Auth/profile guards and are reconstructed on identity
changes, which discards private history, composer, meeting state, and retained
navigation.

Notifications is a second authenticated Home AppBar surface. Its bell omits the
badge while signed out, at zero, or after an unread-count failure; a ready
identity receives an accessible count capped visually at `99+`. The inbox and
preferences routes retain exact OTP/profile-setup `returnTo` values. A signed-out
bell tap stays on Home and offers an explicit Sign in Snackbar action before Auth
opens with `/notifications` as its return destination. Known
semantic targets cross to the existing Messages or Browse routes with canonical
`go` navigation, while unknown targets never guess a destination.

Router/widget regressions live in `test/app/router/navigation_shell_test.dart`.
Native Android/iOS navigation, keyboard and hot-reload QA remains a separate,
manual pre-merge gate; automated widget tests are not a substitute.
