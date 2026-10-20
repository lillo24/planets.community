import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One General-workspace introduction per account on this installation.
///
/// This local boolean contains no Group, room, link or participation state.
/// A missing key means the introduction has not been dismissed; storage errors
/// propagate.
abstract interface class DiscussionHintStore {
  Future<bool> dismissed(String actor);
  Future<void> dismiss(String actor);
}

class SharedPreferencesDiscussionHintStore implements DiscussionHintStore {
  SharedPreferencesDiscussionHintStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();
  final SharedPreferencesAsync _preferences;
  String _key(String actor) {
    if (actor.isEmpty) throw ArgumentError.value(actor, 'actor');
    return 'planets.discussions.generalWorkspaceHint.$actor';
  }

  @override
  Future<bool> dismissed(String actor) async =>
      await _preferences.getBool(_key(actor)) ?? false;

  @override
  Future<void> dismiss(String actor) => _preferences.setBool(_key(actor), true);
}

final discussionHintStoreProvider = Provider<DiscussionHintStore>(
  (ref) => SharedPreferencesDiscussionHintStore(),
);
