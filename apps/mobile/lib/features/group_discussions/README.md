# Group General and Ideas

When a Group/source creation flow visits Workshop, its typed private return
destination composes with Workshop's canonical editor-read observer. A successful
navigation alone never acknowledges that read or grants source/Project access.

This feature owns the revised C General / Ideas audience. It is independent of Project,
Resource and representative conversations.

`presentation/discussion_group_conversations.dart` supplies the folder header and
authorized placement of Project chats to the existing Messages stable list. It
preserves that list's drag pagination and scroll anchors. Mapping refreshes keep
already resolved rows with an explicit loading/error state; identity changes,
authorization denial and malformed responses clear that mapping. The canonical
list's expected actor binds every lookup, including A→B→A transitions. Collapsed
folders still fetch no room history, people or links.

- `domain/discussion_models.dart` strictly parses bounded C projections,
  committed-sequence history, actor/room/admission snapshots and metadata receipts.
- `data/discussion_gateway.dart` owns C RPCs, cursor validation and the single
  account-scoped private invalidation subscription.
- `application/discussion_controllers.dart` owns lazy loaded-window pagination,
  account/readiness epochs, admission changes and frozen command recovery.
- `presentation/discussion_folders.dart` owns one-level Messages folders and
  explicit invitation consent; collapsed folders never load room history or ACK.
- `presentation/discussion_group_screen.dart` owns deliberate creation and the
  narrow Auth-only own leave/decline screens.
- `presentation/discussion_chat_screen.dart` owns plain text chat, anchored older
  paging, read-viewport ACK, reporting and explicit version-conflict review.
- `presentation/discussion_people_screen.dart` owns admitted People, bounded
  current Group People invitation selection, withdrawal and removal.
- `presentation/discussion_widgets.dart` contains pure theme/localization widgets
  and a 320px / large-text preview; it imports no native transport.
- `presentation/discussion_routes.dart` defines C destinations and the exact
  own-exit readiness exception. `discussion_feedback.dart` localizes safe errors.
- `domain/discussion_links.dart`, `data/discussion_links_gateway.dart` and
  `application/discussion_links_controller.dart` own strict episode-bound link
  pages, exact rereads and the private loaded window.
- `application/discussion_share_controller.dart` retains one reviewed selected-link
  share UUID and immutable intent in memory across route remounts. The Links screen
  blocks Close while a share is pending or its reply is uncertain; Retry reuses
  that request, and only a definitive failure can be cancelled. Account/readiness
  changes and canonical source denial clear it. A malformed receipt remains
  uncertain. Nothing is persisted or shared automatically.
- `presentation/discussion_links_screen.dart`, `discussion_link_editor.dart` and
  `discussion_link_open.dart` own explicit collection entry, individual versioned
  edits and destination confirmation before the fresh authorized launch.
- `presentation/discussion_share_link.dart` confirms the wider Project audience
  and rechecks the current account, source episode/link version and destination
  rights while the dialog is open. Losing any scope removes the private link text
  and confirmation action. Canonical sharing validates both domains again.
- `presentation/discussion_link_widgets.dart` provides the pure named-link
  heading and a narrow large-text preview without importing native transport.
- `application/discussion_project_handoff.dart` and
  `presentation/discussion_project_start.dart` check current source entry before
  opening the ordinary Group-attributed Project chooser. Its private navigation
  result returns to the retained room without granting Project access.

The backend is authoritative. See the revised permissions contract and
reproduction notes in `docs/development/group-discussions.md`. Controllers do not
persist private room content or automatically execute a restored action.

## Revised mobile boundaries

V2 room readers separate discoverable summaries, explicit admissions, General,
manager oversight and former history. Discovery never fetches messages. Former
history is read-only and its snapshots cannot acknowledge current unread.

Group settings default to managers. Authorized structural editors may select all
current members. Creation explains planning, public publication, manager
oversight, full earlier history and independent Project participation.

The Group folder loads General/Ideas and entitled Project conversations on
expansion. Project authorization is filtered before the bounded query limit.
Project-only folders never load Group Ideas. Canonical outside cards use a
bounded authorized mapping to avoid duplicate conversations. Converted folder
rows explicitly label retained read-only planning, keeping them distinct from
independently entitled live Project conversations.

- `discussion_room_actions.dart` owns deliberate Join and independent mute/hide.
  The server classifies quiet Ideas after about seven days. Hiding changes no
  unread or subscription; Show hidden includes the ordinary list.
- `discussion_notices.dart` exposes authorized Group activity in Notifications.
  Structured invitation acceptance belongs to Requests. A tap never accepts.
- `discussion_folders.dart` captures the router and originating route before
  invitation acceptance/recovery. Realtime may replace the entire Requests
  subtree before the reply; the live actor-bound command still opens its room.
  Account changes, disposed commands and navigation away cancel that continuation.
- `discussion_models.dart` validates legacy history envelopes and the v2
  effective `access_id` alias; v2 aliases must agree before any history is used.
- `discussion_invitation_link.dart` owns revocable 30-day room capabilities.
  Only exact HTTPS planets.community native paths are accepted. Tokens stay in
  memory and are copied only by deliberate action.
- `discussion_projects_gateway.dart` owns bounded canonical Project folder
  queries. `discussion_group_conversations.dart` owns deduplication and the
  independently authorized Group workspace entry on Project detail.

General's link collection is the Group-wide workspace. Idea and Project
collections remain separate. Current authorized readers see complete current
links; former message history grants no current collection. Exact authorization
still precedes external launch. WhatsApp/Telegram use local icons, with no
provider fetches or automatic joining.

D integration hook: Group People may link to an Idea's People picker through
`discussionPeopleRoute(roomId)` and reuse canonical invitation/acceptance.
No personal-chat button appears until D owns that action.

`discussion_general_hint.dart` keeps General's workspace entry permanent and
shows a dismissible contextual introduction. `discussion_hint_store.dart` saves
one boolean per account on this installation under
`planets.discussions.generalWorkspaceHint.<profile-id>`; missing means visible.
It stores no Group/room/link data, has no backend or cross-device sync, and
does not change consent or external permissions. Dismissal takes effect only
after a successful local write. Restore/save errors remain visible with retry;
late results are ignored after account changes.

Discussion headers opt into `pageAppBar(preserveTitleSize: true)`: narrow
windows put actions below a bounded, normally sized title; unrelated headers
retain their defaults. General is localized by its reserved kind. General's
intro and expanded Idea purpose/disclosure/actions scroll within 40% of the body,
and delivery feedback/editor within
60% of the remaining content area. Both use independent scrollers; the history
controller, positive transcript viewport and read-ACK boundary remain intact.

General supports mute without Hide, Leave or Idea conversion. Idea creator
provenance uses the canonical creator identity in discovery/context; an authorized
People row adds the readable name and a distinct Idea creator label alongside its
Group role. No profile-name lookup or extra authority is inferred from that ID.
An already resolved room without roster rights renders unavailable rather than
loading indefinitely and clears any previously loaded roster.
