import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_session_controller.dart';

/// In-memory unsent text survives Back within one identity session only.
/// Identity/phase changes discard all drafts; nothing is persisted to disk.
class MemberContactDrafts extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() {
    ref.watch(authSessionProvider.select((s) => (s.identity?.id, s.phase)));
    return const {};
  }

  void save(String slot, String value) => state = {...state, slot: value};
  void clear(String slot) => state = {...state}..remove(slot);
}

final memberContactDraftsProvider =
    NotifierProvider<MemberContactDrafts, Map<String, String>>(
      MemberContactDrafts.new,
    );
