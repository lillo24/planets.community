import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../auth/application/auth_session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../groups/domain/group_models.dart';
import '../data/discussion_conversion_gateway.dart';
import '../domain/discussion_models.dart';

/// One reviewed share keeps its request identity until its outcome is known.
class DiscussionShareAttempt {
  DiscussionShareAttempt(this.actor, Map<String, dynamic> intent)
    : intent = Map.unmodifiable(intent),
      key = const Uuid().v4();
  final String actor, key;
  final Map<String, dynamic> intent;
  bool busy = false, cancelled = false;
  Object? error;
  String? receipt;
  bool get uncertain =>
      receipt == null &&
      error != null &&
      (error is FormatException ||
          error is TypeError ||
          discussionFailure(error!) == DiscussionFailure.unavailable);
}

/// Retains share recovery across route disposal without persisting private data.
///
/// Account/readiness changes and a canonical source denial clear the attempts.
class DiscussionShareCommands extends ChangeNotifier {
  DiscussionShareCommands(this.gateway, this.authorized);
  final DiscussionConversionGateway gateway;
  final bool Function(String) authorized;
  final attempts = <String, DiscussionShareAttempt>{};
  bool disposed = false;
  int epoch = 0;

  Future<String?> run(
    String slot,
    String actor,
    Map<String, dynamic> intent,
  ) async {
    if (disposed || !authorized(actor)) {
      return null;
    }
    final prior = attempts[slot];
    if (prior != null &&
        (prior.actor != actor || !mapEquals(prior.intent, intent))) {
      throw StateError('An unresolved link share cannot change intent.');
    }
    final attempt = prior ?? DiscussionShareAttempt(actor, intent);
    attempts[slot] = attempt;
    if (attempt.busy) {
      return null;
    }
    final captured = epoch;
    attempt.busy = true;
    attempt.error = null;
    notifyListeners();
    try {
      final result =
          attempt.receipt ??
          groupUuid(
            await gateway.rpc('share_discussion_link_to_project', {
              'p_expected_profile_id': actor,
              'p_client_request_id': attempt.key,
              ...attempt.intent,
            }),
          );
      if (disposed ||
          attempt.cancelled ||
          captured != epoch ||
          !authorized(actor)) {
        return null;
      }
      attempt.receipt = result;
      return result;
    } catch (error) {
      if (!disposed &&
          !attempt.cancelled &&
          captured == epoch &&
          authorized(actor)) {
        attempt.error = error;
      }
      return null;
    } finally {
      if (!disposed && !attempt.cancelled && captured == epoch) {
        attempt.busy = false;
        notifyListeners();
      }
    }
  }

  void forget(String slot) {
    if (attempts[slot]?.busy == true || attempts[slot]?.uncertain == true) {
      return;
    }
    attempts.remove(slot);
    if (!disposed) {
      notifyListeners();
    }
  }

  void clearRoom(String room) {
    final slots = attempts.entries
        .where((e) => e.value.intent['p_room_id'] == room)
        .map((e) => e.key)
        .toList();
    for (final slot in slots) {
      attempts.remove(slot)!.cancelled = true;
    }
    if (!disposed) {
      notifyListeners();
    }
  }

  void clear() {
    epoch++;
    attempts.clear();
    if (!disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    disposed = true;
    clear();
    super.dispose();
  }
}

final discussionShareCommandsProvider = Provider<DiscussionShareCommands>((
  ref,
) {
  final commands = DiscussionShareCommands(
    DiscussionConversionGateway(
      (name, parameters) =>
          ref.read(discussionConversionGatewayProvider).rpc(name, parameters),
    ),
    (actor) =>
        ref.read(authSessionProvider).phase == AuthSessionPhase.ready &&
        ref.read(authSessionProvider).identity?.id == actor,
  );
  ref.listen(
    authSessionProvider.select((s) => (s.identity?.id, s.phase)),
    (_, _) => commands.clear(),
  );
  ref.onDispose(commands.dispose);
  return commands;
});
