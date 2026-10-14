import 'dart:io';

import 'package:planets_mobile/features/project_workspace/application/project_workspace_launcher.dart';
import 'package:planets_mobile/features/project_workspace/data/project_workspace_gateway.dart';
import 'package:planets_mobile/features/project_workspace/data/project_workspace_pending_add_store.dart';
import 'package:planets_mobile/features/project_workspace/domain/project_workspace_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeProjectWorkspaceGateway implements ProjectWorkspaceGateway {
  final links = <ProjectWorkspace>[];
  final _receipts =
      <String, ({String id, String name, ProjectWorkspaceUrl url})>{};
  ProjectWorkspace? get workspace => links.firstOrNull;
  set workspace(ProjectWorkspace? value) {
    links.clear();
    if (value != null) links.add(value);
  }

  Object? readError, pageError, receiptError, itemError, mutationError;
  Future<void>? readDelay, mutationDelay;
  bool canManage = true, loseNextAddReply = false;
  void Function()? onSaved;
  var _sequence = 0;
  final calls = <String>[];
  final requestIds = <String?>[];
  List<String> journal = [];

  @override
  Future<ProjectWorkspacePage> listLinks({
    required String expectedProfileId,
    required String projectId,
    ProjectWorkspaceCursor? cursor,
    int limit = 10,
  }) async {
    calls.add('get:$expectedProfileId:$projectId');
    if (readDelay case final delay?) await delay;
    if (readError ?? pageError case final error?) throw error;
    final rows =
        links
            .where(
              (row) =>
                  row.projectId == projectId &&
                  (cursor == null ||
                      row.createdAt.isBefore(cursor.createdAt) ||
                      (row.createdAt == cursor.createdAt &&
                          row.id.compareTo(cursor.id) < 0)),
            )
            .toList()
          ..sort((a, b) {
            final time = b.createdAt.compareTo(a.createdAt);
            return time == 0 ? b.id.compareTo(a.id) : time;
          });
    final items = rows.take(limit).toList(growable: false);
    return ProjectWorkspacePage(
      items: List.unmodifiable(items),
      canManage: canManage,
      nextCursor: rows.length > limit
          ? ProjectWorkspaceCursor(
              createdAt: items.last.createdAt,
              id: items.last.id,
            )
          : null,
    );
  }

  @override
  Future<ProjectWorkspace?> getLink({
    required String expectedProfileId,
    required String projectId,
    required String linkId,
  }) async {
    calls.add('item:$expectedProfileId:$projectId:$linkId');
    if (readDelay case final delay?) await delay;
    if (readError ?? itemError case final error?) throw error;
    return links
        .where((row) => row.id == linkId && row.projectId == projectId)
        .firstOrNull;
  }

  @override
  Future<WorkspaceAddReceipt> readAddReceipt({
    required String expectedManagerProfileId,
    required String projectId,
    required String requestId,
  }) async {
    calls.add('receipt:$expectedManagerProfileId:$projectId:$requestId');
    if (readError ?? receiptError case final error?) throw error;
    if (!canManage) {
      throw const PostgrestException(message: 'forbidden', code: '42501');
    }
    final row = _receipts['$expectedManagerProfileId/$projectId/$requestId'];
    if (row == null) return const WorkspaceAddReceipt(accepted: false);
    return WorkspaceAddReceipt(
      accepted: true,
      linkId: row.id,
      name: row.name,
      url: row.url,
      item: links
          .where((item) => item.id == row.id && item.projectId == projectId)
          .firstOrNull,
    );
  }

  @override
  Future<String> saveLink({
    required String expectedManagerProfileId,
    required String projectId,
    required String name,
    required ProjectWorkspaceUrl url,
    String? linkId,
    String? requestId,
    int? expectedVersion,
  }) async {
    calls.add('set:$expectedManagerProfileId:$projectId:${url.value}');
    requestIds.add(requestId);
    journal.add('send:$requestId');
    if (mutationDelay case final delay?) await delay;
    if (mutationError case final error?) throw error;
    if (!canManage) {
      throw const PostgrestException(message: 'forbidden', code: '42501');
    }
    final receiptKey = '$expectedManagerProfileId/$projectId/$requestId';
    if (linkId == null) {
      if (requestId == null) {
        throw const PostgrestException(
          message: 'command required',
          code: '22023',
        );
      }
      final previous = _receipts[receiptKey];
      if (previous != null) {
        if (previous.name != name || previous.url.value != url.value) {
          throw const PostgrestException(
            message: 'content changed',
            code: '40001',
          );
        }
        return previous.id;
      }
    }
    final index = linkId == null
        ? -1
        : links.indexWhere(
            (row) => row.id == linkId && row.projectId == projectId,
          );
    if (linkId != null && index < 0) {
      throw const PostgrestException(message: 'removed', code: 'P0002');
    }
    if (index >= 0 && expectedVersion != links[index].version) {
      throw const PostgrestException(message: 'changed', code: '40001');
    }
    String id;
    if (linkId != null) {
      id = linkId;
    } else {
      do {
        id = 'link-${++_sequence}';
      } while (links.any((row) => row.id == id));
    }
    final entry = ProjectWorkspace(
      id: id,
      name: name,
      projectId: projectId,
      url: url,
      createdAt: index < 0
          ? DateTime.utc(2030).add(Duration(microseconds: _sequence))
          : links[index].createdAt,
      updatedAt: DateTime.utc(2030).add(Duration(microseconds: _sequence)),
      version: index < 0 ? 1 : links[index].version + 1,
    );
    if (index < 0) {
      links.add(entry);
      _receipts[receiptKey] = (id: id, name: name, url: url);
    } else {
      links[index] = entry;
    }
    onSaved?.call();
    if (linkId == null && loseNextAddReply) {
      loseNextAddReply = false;
      throw const SocketException('Synthetic reply loss after acceptance.');
    }
    return id;
  }

  @override
  Future<void> removeLink({
    required String expectedManagerProfileId,
    required String projectId,
    required String linkId,
    required int expectedVersion,
  }) async {
    calls.add('clear:$expectedManagerProfileId:$projectId:$linkId');
    if (mutationDelay case final delay?) await delay;
    if (mutationError case final error?) throw error;
    if (!canManage) {
      throw const PostgrestException(message: 'forbidden', code: '42501');
    }
    final index = links.indexWhere(
      (row) => row.id == linkId && row.projectId == projectId,
    );
    if (index < 0) {
      throw const PostgrestException(message: 'removed', code: 'P0002');
    }
    if (links[index].version != expectedVersion) {
      throw const PostgrestException(message: 'changed', code: '40001');
    }
    links.removeAt(index);
  }
}

class FakeWorkspacePendingAddStore implements ProjectWorkspacePendingAddStore {
  final values = <String, WorkspaceLinkDraft>{};
  Object? readError, writeError, clearError;
  Future<void>? delay;
  Future<void>? writeDelay;
  void Function()? onWrite;
  List<String> journal = [];
  @override
  Future<WorkspaceLinkDraft?> read(String actorId, String projectId) async {
    if (delay case final pending?) await pending;
    if (readError case final error?) throw error;
    return values['$actorId/$projectId'];
  }

  @override
  Future<void> write(WorkspaceLinkDraft draft) async {
    onWrite?.call();
    if (writeDelay case final pending?) await pending;
    if (writeError case final error?) throw error;
    final key = '${draft.actorId}/${draft.projectId}',
        old = values['${draft.actorId}/${draft.projectId}'];
    if (old != null &&
        (old.requestId != draft.requestId ||
            old.name != draft.name ||
            old.input != draft.input)) {
      throw StateError('Reconcile previous Add.');
    }
    values[key] = draft;
    journal.add('persist:${draft.requestId}');
  }

  @override
  Future<void> clear(WorkspaceLinkDraft draft) async {
    if (clearError case final error?) throw error;
    final key = '${draft.actorId}/${draft.projectId}';
    if (!values.containsKey(key)) return;
    if (values[key]?.requestId != draft.requestId) {
      throw StateError('A newer Add owns recovery.');
    }
    values.remove(key);
  }
}

class FakeProjectWorkspaceLauncher implements ProjectWorkspaceLauncher {
  bool result = true;
  ProjectWorkspaceUrl? opened;
  int calls = 0;
  @override
  Future<bool> open(ProjectWorkspaceUrl url) async {
    calls++;
    opened = url;
    return result;
  }
}

ProjectWorkspace projectWorkspaceFixture({
  String id = 'link-1',
  String name = 'Workspace',
  String projectId = 'proposal-1',
  String url = 'https://drive.google.com/drive/folders/private-token',
  int version = 1,
  DateTime? createdAt,
}) => ProjectWorkspace(
  id: id,
  name: name,
  projectId: projectId,
  url: ProjectWorkspaceUrl.parse(url),
  updatedAt: DateTime.utc(2030),
  createdAt: createdAt ?? DateTime.utc(2030),
  version: version,
);
