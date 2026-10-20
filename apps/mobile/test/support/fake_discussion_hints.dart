import 'package:planets_mobile/features/group_discussions/data/discussion_hint_store.dart';

class FakeDiscussionHintStore implements DiscussionHintStore {
  final saved = <String, bool>{};
  final writes = <String>[];
  bool failRead = false, failWrite = false;
  @override
  Future<bool> dismissed(String actor) async {
    if (failRead) throw StateError('Synthetic local read failure');
    return saved[actor] ?? false;
  }

  @override
  Future<void> dismiss(String actor) async {
    writes.add(actor);
    if (failWrite) throw StateError('Synthetic local write failure');
    saved[actor] = true;
  }
}
