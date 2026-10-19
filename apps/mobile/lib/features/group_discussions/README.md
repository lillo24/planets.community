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
- `presentation/discussion_links_screen.dart`, `discussion_link_editor.dart` and
  `discussion_link_open.dart` own explicit collection entry, individual versioned
  edits and destination confirmation before the fresh authorized launch.
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
- `discussion_folders.dart` keeps invitation-result navigation on the persistent
  Requests owner, so a realtime removal of the accepted invitation cannot drop
  the successful chat continuation; account changes still cancel it.
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
