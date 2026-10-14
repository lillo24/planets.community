import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/features/project_workspace/data/project_workspace_pending_add_store.dart';
import 'package:planets_mobile/features/project_workspace/domain/project_workspace_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _request = '93a5a248-d3e9-4e77-a2a6-665efc143003';
const _nextRequest = '93a5a248-d3e9-4e77-a2a6-665efc143004';
const _key = 'project_workspace_pending_add_v1:actor-a:project-a';

WorkspaceLinkDraft _draft({
  String request = _request,
  String name = 'Budget',
  String actor = 'actor-a',
  bool submitted = true,
}) => WorkspaceLinkDraft(
  actorId: actor,
  projectId: 'project-a',
  requestId: request,
  name: name,
  input: 'https://docs.example.invalid/private-a',
  submitted: submitted,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('actual preference serialization restores the same submitted action after restart', () async {
    final store = SharedPreferencesWorkspacePendingAddStore();
    await store.write(_draft());
    final serialized = (await SharedPreferences.getInstance()).getString(_key)!;
    // Recreate the plugin's backing store and application adapter, not only a
    // controller object retaining a reference to its old draft.
    SharedPreferences.setMockInitialValues({_key: serialized});
    final restarted = SharedPreferencesWorkspacePendingAddStore();
    final restored = (await restarted.read('actor-a', 'project-a'))!;
    expect(restored.requestId, _request);
    expect(restored.name, 'Budget');
    expect(restored.input, 'https://docs.example.invalid/private-a');
    expect(restored.submitted, isTrue);
    expect(await restarted.read('actor-b', 'project-a'), isNull);
    expect(await restarted.read('actor-a', 'project-b'), isNull);
    await restarted.clear(restored);
    expect(await restarted.read('actor-a', 'project-a'), isNull);
    await restarted.clear(restored);
  });
  test(
    'cannot replace an unresolved action or clear a newer identity',
    () async {
      final store = SharedPreferencesWorkspacePendingAddStore();
      await store.write(_draft());
      await expectLater(
        store.write(_draft(request: _nextRequest)),
        throwsStateError,
      );
      await expectLater(
        store.write(_draft(name: 'Changed payload')),
        throwsStateError,
      );
      await expectLater(
        store.clear(_draft(request: _nextRequest)),
        throwsStateError,
      );
      expect((await store.read('actor-a', 'project-a'))!.requestId, _request);
      await store.clear(_draft());
      await store.write(_draft(request: _nextRequest));
      expect(
        (await store.read('actor-a', 'project-a'))!.requestId,
        _nextRequest,
      );
    },
  );
  test(
    'ordinary unsent drafts are not persisted as ambiguous commands',
    () async {
      final store = SharedPreferencesWorkspacePendingAddStore();
      await expectLater(
        store.write(_draft(submitted: false)),
        throwsStateError,
      );
      expect(await store.read('actor-a', 'project-a'), isNull);
    },
  );
  test('malformed, cross-account and unsupported recovery never become an empty success', () async {
    final valid = {
      'format': 1,
      'actor_id': 'actor-a',
      'project_id': 'project-a',
      'request_id': _request,
      'name': 'Budget',
      'input': 'https://docs.example.invalid/private-a',
    };
    for (final value in [
      'not JSON',
      jsonEncode([]),
      jsonEncode({...valid, 'format': 2}),
      jsonEncode({...valid, 'actor_id': 'actor-b'}),
      jsonEncode({...valid, 'project_id': 'project-b'}),
      jsonEncode({...valid, 'request_id': 'invalid'}),
      jsonEncode({...valid, 'input': 'http://example.invalid'}),
      jsonEncode({...valid, 'name': ' '}),
    ]) {
      SharedPreferences.setMockInitialValues({_key: value});
      final store = SharedPreferencesWorkspacePendingAddStore();
      await expectLater(
        store.read('actor-a', 'project-a'),
        throwsA(isA<Exception>()),
      );
    }
  });
  test(
    'queued rejection does not hide the error or prevent later reconciliation',
    () async {
      final store = SharedPreferencesWorkspacePendingAddStore();
      final first = store.write(_draft());
      final changed = store.write(_draft(request: _nextRequest));
      await first;
      await expectLater(changed, throwsStateError);
      await store.clear(_draft());
      expect(await store.read('actor-a', 'project-a'), isNull);
    },
  );
}
