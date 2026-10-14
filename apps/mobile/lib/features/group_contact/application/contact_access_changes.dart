import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_session_controller.dart';

/// Identifier-only own-account authorization invalidation. Contains no content.
class ContactAccessChanges extends Notifier<(String?, int)> {
  @override
  (String?, int) build() =>
      (ref.watch(authSessionProvider.select((s) => s.identity?.id)), 0);
  void changed(String actor) {
    if (ref.read(authSessionProvider).identity?.id == actor) {
      state = (actor, state.$2 + 1);
    }
  }
}

final contactAccessChangesProvider =
    NotifierProvider<ContactAccessChanges, (String?, int)>(
      ContactAccessChanges.new,
    );
