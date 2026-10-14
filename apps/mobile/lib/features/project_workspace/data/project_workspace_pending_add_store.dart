import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/project_workspace_models.dart';

abstract interface class ProjectWorkspacePendingAddStore {
  Future<WorkspaceLinkDraft?> read(String actorId, String projectId);
  Future<void> write(WorkspaceLinkDraft draft);
  Future<void> clear(WorkspaceLinkDraft draft);
}

/// App-private recovery intent, scoped to actor and Project. Only frozen,
/// submitted Adds persist; ordinary unsent drafts remain in run memory.
class SharedPreferencesWorkspacePendingAddStore
    implements ProjectWorkspacePendingAddStore {
  Future<void> _tail = Future<void>.value();

  // Serialize reads/writes/removal across stale callbacks. The caller receives
  // the original error; the queue itself can continue after a reported failure.
  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  String _key(String actor, String project) =>
      'project_workspace_pending_add_v1:$actor:$project';

  WorkspaceLinkDraft _parse(String value, String actor, String project) {
    final data = jsonDecode(value);
    if (data is! Map ||
        data['format'] != 1 ||
        data['actor_id'] != actor ||
        data['project_id'] != project ||
        data['request_id'] is! String ||
        data['name'] is! String ||
        data['input'] is! String) {
      throw const FormatException(
        'Workspace Add recovery intent was malformed.',
      );
    }
    final request = data['request_id'] as String,
        name = data['name'] as String,
        input = data['input'] as String;
    if (!RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ).hasMatch(request) ||
        validateProjectWorkspaceName(name) != name ||
        ProjectWorkspaceUrl.parse(input).value != input) {
      throw const FormatException(
        'Workspace Add recovery payload was malformed.',
      );
    }
    return WorkspaceLinkDraft(
      actorId: actor,
      projectId: project,
      requestId: request,
      name: name,
      input: input,
      submitted: true,
    );
  }

  @override
  Future<WorkspaceLinkDraft?> read(String actorId, String projectId) =>
      _enqueue(() async {
        final preferences = await SharedPreferences.getInstance();
        final value = preferences.getString(_key(actorId, projectId));
        return value == null ? null : _parse(value, actorId, projectId);
      });

  @override
  Future<void> write(WorkspaceLinkDraft draft) => _enqueue(() async {
    if (!draft.submitted || draft.linkId != null || draft.requestId == null) {
      throw StateError('Only a frozen workspace Add can be retained.');
    }
    final value = jsonEncode({
      'format': 1,
      'actor_id': draft.actorId,
      'project_id': draft.projectId,
      'request_id': draft.requestId,
      'name': draft.name,
      'input': draft.input,
    });
    _parse(value, draft.actorId, draft.projectId);
    final preferences = await SharedPreferences.getInstance();
    final previous = preferences.getString(
      _key(draft.actorId, draft.projectId),
    );
    if (previous != null) {
      final pending = _parse(previous, draft.actorId, draft.projectId);
      if (pending.requestId != draft.requestId ||
          pending.name != draft.name ||
          pending.input != draft.input) {
        throw StateError(
          'Reconcile the previous workspace Add for ${draft.projectId}.',
        );
      }
    }
    if (!await preferences.setString(
      _key(draft.actorId, draft.projectId),
      value,
    )) {
      throw StateError(
        'Workspace Add recovery could not be retained for ${draft.projectId}.',
      );
    }
  });

  @override
  Future<void> clear(WorkspaceLinkDraft draft) => _enqueue(() async {
    final preferences = await SharedPreferences.getInstance();
    final key = _key(draft.actorId, draft.projectId),
        value = preferences.getString(_key(draft.actorId, draft.projectId));
    if (value == null) return;
    final current = _parse(value, draft.actorId, draft.projectId);
    if (current.requestId != draft.requestId) {
      throw StateError(
        'A newer workspace Add owns recovery for ${draft.projectId}.',
      );
    }
    if (!await preferences.remove(key)) {
      throw StateError(
        'Workspace Add recovery could not be cleared for ${draft.projectId}.',
      );
    }
  });
}

final projectWorkspacePendingAddStoreProvider =
    Provider<ProjectWorkspacePendingAddStore>(
      (ref) => SharedPreferencesWorkspacePendingAddStore(),
    );
