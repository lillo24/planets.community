# Private registered Group discussions

This feature owns C's accepted-room audience. It is independent of Project,
Resource and representative conversations.

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

The backend is authoritative. See the provisional permissions contract and
reproduction notes in `docs/development/group-discussions.md`. Controllers do not
persist private room content or automatically execute a restored action.
