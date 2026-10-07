# Application composition

This folder owns application startup presentation and navigation, not backend rules.

- `planets_app.dart` composes Riverpod, themes, localization and `MaterialApp.router`.
- `router/app_router.dart` owns routes, Auth/readiness redirects and the identity-scoped routing configuration.
- `router/native_project_links.dart` validates absolute public HTTPS deliveries before the router converts them to internal destinations.
- `router/app_navigation_shell.dart` maps the single Material 3 navigation bar to stable branches and routes.
- `foundation_screen.dart` is Home; its Projects and Cultural Tables entry uses
  the shell's Browse branch switch, its Scambio-Dona entry opens the Browse-owned resource routes,
  and its AppBar opens public Settings.
  Its shared PLANETS hero sits behind opaque functional cards; decorative height
  shrinks for short screens/large text, while cards retain natural height and
  remain scrollable. Home never replays Welcome's entrance; its shared circular
  planet rotations and logo float continue at the informative website's speeds
  while visible, pausing offscreen/backgrounded and respecting reduced motion.
- `startup_failure_app.dart` is the safe fallback when bootstrap cannot launch the application.

## Navigation contract

`StatefulShellRoute.indexedStack` (go_router 18) keeps three stable branch Navigators:

| Index / destination | Routes |
| --- | --- |
| 0 / Profile | `/profile`; nested edit, blocked-users, own reports, and moderation review requests |
| 1 / Home | `/`; Messages request/chat/group-info, Notifications/preferences, and their protected detail routes |
| 2 / Browse | `/proposals`, `/tavoli`, and `/resources`; public detail plus protected owner/editor, saved-search, loan-schedule, Project resources/matches, participation, delegate, invite, and management routes |

The Home branch also owns public `/settings`, `/settings/language`, and
`/settings/navigation`.
Settings conditionally links ready signed-in profiles to the existing protected
notification preferences and profile editor routes; it is never itself an Auth
destination.

The visible bar is Profile / Home / Messages by default. Settings can replace
the bottom-right shortcut with Browse through a device-local preference.
While a Messages route or any Browse branch route is active, that right slot
shows and selects the actual destination even when the saved shortcut differs.
On Profile, Home, Settings, and Notifications, it shows the saved choice.
Messages remains on the Home branch; changing the preference does not rebuild
or reorder the route tree. An inactive Messages shortcut opens canonical
`/messages`, whose public contextual state offers Auth/profile completion when
needed. Its private descendants retain their guards. Re-tapping active
Messages or Browse preserves its nested route. Browse's shortcut restores its
retained branch state; public discovery also remains reachable from Home.

Static Browse children precede each dynamic activity-ID route. A route-backed
Proposals/Tavoli switcher changes the public list within Browse without adding a
fourth bottom destination. Each list's Riverpod state survives switching. Direct entry creates
the matching nested stack and selects its corresponding visible slot. Drill-down actions
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
management and personal saved searches preserve the exact destination through both OTP and profile setup. Participation Join,
creator-review, Project resource management/matching, Messages request/chat/group-info, and Notifications routes preserve their exact internal destination
through OTP and profile completion. Missing-anchor retry and email-OTP behavior
are unchanged. Saving a valid profile returns to the preserved participation or
Messages/Notifications route when present, otherwise to Profile.
For guarded Proposal/Tavolo Join setup, Profile edit keeps separate destinations:
Save resumes the exact sanitized Join route, while the visible Back action and
system Back return to the corresponding public Project detail. Other Profile
edit flows cancel to a safe public ancestor/Home; ordinary ready editing returns
to Profile. Both invitation families retain their exact public preview.

PI02 adds public `/join/project/:token` outside the shell, distinct from the
authority `/invite/project/:token` route. Participant Auth/profile returns and
cancellation preserve the exact sanitized preview destination; returning never
admits automatically. Ordinary sharing uses public `/proposals|tavoli/:id` with
exactly one `intent=join` marker. Its page-level dismissible sheet uses existing
participation actions and retains detail when closed; continuing enters the
existing protected `/join` composer. Ordinary-request Auth cancellation returns
to public detail. The single protected `participant-links` child of either public
Project family is shared by People, Manage and current manager group info.
Overlay guards observe GoRouter's active delegate state, including pushed routes,
rather than the browser URL provider, which can retain an underlying page URL.
See the [participant feature](../features/project_participant_invites/README.md)
for process-memory UUID recovery and deliberately separate re-entry.

PI04 handles native absolute URLs through this same GoRouter boundary. Only the
canonical host's exact participant/authority token and public UUID detail paths
are allowed; unsafe origins/encoded separators/descendants show a generic error.
Detail queries are preserved. Duplicate platform delivery retains the active
Project or exact OTP/profile continuation and typed form; a different valid link
cancels the old OTP attempt after navigation commits. Platform-message tests
exercise cold default routes and warm delivery without an internal `go` shortcut.
The routing configuration exposes GoRouter 18's entry guard only while its
existing provider holds an external URL. Internal navigation keeps the existing
synchronous parse and loading states; no second platform listener is registered.
During cold native parsing, restored Auth does not reparse GoRouter's initial
empty URI. Initial guards read the latest session; there are no retained private
stacks to discard before the first route exists.
See the [PI04 record](../../../../docs/implementation/pi04-native-links-and-public-host-readiness.md)
for OS globs, merged-manifest checks and the limits of native runtime evidence.

## Retention and identity

Tab retention is in-memory only, scoped to the same authenticated identity. On
sign-in, sign-out or account change, the routing configuration creates fresh
shell/branch keys and reparses the current URL through the same guards. This
discards every retained branch (including inactive private forms) without losing
an in-flight Auth return destination. A same-identity token refresh does not reset
the shell. No form data is persisted to disk for this behavior.

Profile, proposal, Tavoli owner, Project-resource owner/matching, Scambio-Dona owner/editor, participation, Messages, and Notifications controllers also clear cached state and increment a
request revision on identity changes. Every async continuation checks that its
revision is still current before publishing state or starting another operation.
Thus A -> signed out -> A also rejects old work. Profile readiness cannot be
restored by an old save. Existing rendered-identity checks and expected-ID RPC
parameters remain in force; database authorization is unchanged.

Participation protected-meeting data is an additional private state boundary:
it is loaded only for the creator/current member and cleared when identity or
current membership changes. It is never added to public activity models.

Messages request and Project-chat state are independent identity-bound
boundaries. Their shared two-tab entry is reachable through the configurable
bottom-right shortcut or a labelled Settings row when Browse occupies that slot. The
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

`startup/` owns ordinary signed-out Welcome and the dormant installation tutorial;
see its [entry and preference contract](startup/README.md). Home keeps public
discovery, Notifications and Settings without the Auth testing card or envelope.
When Browse occupies the third slot, Settings offers a labelled Messages row.
Only `/messages` is public/contextual; all private descendants remain guarded.

Profile editing uses an explicit Flutter `MaterialPage` so iOS has its native
edge detector with the resolved go_router 18 app adapter. Its PopScope permits
native popping only when the actual preceding route is the stable cancel
destination. Canonical incomplete setup cancels to a safe public origin/Home,
not the incomplete Profile below it. Save always resumes the stored authorized
destination, independently of Cancel, through the optional tutorial boundary.

Router/widget regressions live in `test/app/router/navigation_shell_test.dart`
and `test/app/startup/`.
Native Android/iOS navigation, keyboard and hot-reload QA remains a separate,
manual pre-merge gate; automated widget tests are not a substitute.
