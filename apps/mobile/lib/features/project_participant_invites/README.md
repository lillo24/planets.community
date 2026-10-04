# Project participant invitations

This feature owns PI02 public sharing, reusable participant-link management and
explicit direct admission over the [PI01 RPC contract](../../../../../docs/implementation/pi01-participant-invitations.md).
Authority invitations remain in `project_delegates`; ordinary request and
membership rules remain in `participation` and the canonical database.

## Source map

- `domain/participant_invitation_models.dart` owns safe preview, receipt,
  generation metadata, secret and failure types. Secret/state `toString` values
  are redacted.
- `data/participant_invitation_gateway.dart` owns exact expected-account RPC
  parameters, strict payload parsing and canonical current chat reads.
- `application/participant_admission_controller.dart` owns account/token-scoped
  Join action UUIDs, unresolved receipt recovery and deliberate fresh re-entry.
- `application/participant_admission_refresh.dart` owns canonical participation
  reads and refresh of already-loaded public, People, request/history, meeting,
  Messages/request-chat and group-chat views. It never admits anyone.
- `application/participant_link_manager.dart` owns role revalidation, current
  generation retrieval, explicit mutations and metadata cursor pages. Uncertain
  mutation responses are followed by canonical reads, never automatic repetition.
- `presentation/participant_invitation_routes.dart` owns the participant and
  management paths and the narrow ordinary-share query marker.
- `presentation/project_share_action.dart` owns the public Share dialog. Each
  opening starts with ordinary sharing; selecting special sharing explicitly
  invokes get-or-create, without rotation.
- `presentation/participant_link_management_screen.dart` owns the single manager
  destination and the shared People/Manage/group-info entry button.
- `presentation/participant_invite_screen.dart` owns public preview, explicit
  Auth/profile/Join choices, receipt/current-state presentation and chat read retry.
- `presentation/share_link_buttons.dart` is the only intentional platform
  disclosure boundary. It rechecks context after preparation and preserves the
  existing Clipboard/SharePlus positioning adapter.
- `presentation/project_context_dialog.dart` removes account/route-bound overlays
  without popping a newly opened page.
- `presentation/ordinary_share_intent.dart` presents the existing participation
  actions above the public page. It mounts outside lazy scroll content and
  removes only its own sheet when navigating to the ordinary composer/Auth.
- `presentation/participant_invite_messages.dart` maps safe failures to English
  and Italian copy without displaying raw backend exceptions.

## URL and retry contracts

Ordinary HTTPS links are `/proposals/<id>?intent=join` and
`/tavoli/<id>?intent=join` on `planets.community`. Exactly one `intent=join`
enables the dismissible existing request intent; duplicate or other values do
not. Closing removes the marker and keeps public detail. Continuing uses the
existing `/join` composer, contribution choices, photo gate and approval flow.

Special HTTPS links are `/join/project/<43-character-token>`; authority links
remain `/invite/project/<token>`. The former is publicly previewable and never
automatically admits on route opening, Auth restoration or refresh. The exact
safe participant destination survives OTP and non-photo profile completion.
Cancelling Auth/profile returns to the preview; cancelling ordinary request Auth
returns to the public Project.

Pending attempts live in the root ProviderScope's **process memory**, outside a
widget lifetime. An explicit Join creates one UUID. The same account/token/action
tuple survives rebuilds, navigation and lost responses, including a newly
unavailable preview. Logout/account switch or process/ProviderScope disposal
destroys it. A new process offers Join, never a misleading Retry for a lost tuple.
Confirmed receipts refresh canonical own participation before choosing current
Project/chat access or ended-episode copy. Fresh re-entry requires a new explicit
click, a valid current preview and a successful read showing no current membership.

Manager copy/share revalidates role and retrieves current state; known forbidden
results discard secrets. Replacement and revocation require confirmation;
revocation passes the displayed generation ID. Preview availability is an
independent read: an unavailable link is labelled honestly, and a failed preview
does not prevent useful authorized revocation/history. There is no fixed expiry.

Sentry drops capability-bearing events and breadcrumbs, including encoded Auth
`returnTo` paths, RPC token fields and standalone opaque tokens. This filter lives
in `core/monitoring`; no analytics or token logging is added.

See the [PI02 record](../../../../../docs/implementation/pi02-mobile-participant-invitations.md)
for validation and the disposable backend/internal-route smoke procedure.
